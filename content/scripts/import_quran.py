#!/usr/bin/env python3
"""Normalise QUL Quran exports into the JSON that build_content.py consumes.

QUL (https://qul.tarteel.ai/) has no public read API for bulk data: every
resource is a file you download from its resource page, as SQLite or JSON. So
this script does not fetch anything. You download the files once, drop them in
content/sources/quran/downloads/, and this script reads them.

See content/sources/quran/README.md for exactly which resources to download.

What it produces, in --out (content/sources/quran/ by default):

    surahs.json          114 surahs with names, revelation place and ayah count
    ayahs.json           6236 ayahs with Uthmani text, simplified text,
                         translation, transliteration, juz, hizb, page, sajdah
    ENCODING_REPORT.md   Unicode codepoint inventory of the Uthmani text

Files are identified by their contents, not their names, so you can leave QUL's
own filenames alone. Pass an explicit --script/--translation/... path when the
guess is wrong or ambiguous.

Usage:
    python3 content/scripts/import_quran.py --check
    python3 content/scripts/import_quran.py
    python3 content/scripts/import_quran.py --script downloads/uthmani.db
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sqlite3
import sys
import unicodedata
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

# content/scripts/import_quran.py -> content/
CONTENT_DIR = Path(__file__).resolve().parent.parent
QURAN_DIR = CONTENT_DIR / "sources" / "quran"
DOWNLOADS_DIR = QURAN_DIR / "downloads"

TOTAL_SURAHS = 114
TOTAL_AYAHS = 6236

# Surah 9 (At-Tawbah) is the only surah not preceded by the basmala.
# Deliberately not taken from QUL's `bismillah_pre`, which is also false for
# surah 1 because there the basmala is ayah 1 rather than a heading.
NO_BISMILLAH_SURAH = 9

# QUL's translation exports carry footnote references as <sup> / <a> elements
# whose *content* is the marker number. Dropping only the tags would weld that
# number onto the sentence ("...mercy.1"), so drop the whole element first.
FOOTNOTE_ELEMENT_RE = re.compile(r"<(sup|a)\b[^>]*>.*?</\1>", re.IGNORECASE | re.DOTALL)
HTML_TAG_RE = re.compile(r"<[^>]+>")
WHITESPACE_RE = re.compile(r"\s+")
VERSE_KEY_RE = re.compile(r"^(\d{1,3}):(\d{1,3})$")


# --------------------------------------------------------------------------
# text_simple
# --------------------------------------------------------------------------

# Marks removed by simplify_arabic().
#
# The project originally specified U+064B-U+0652, U+0653-U+0656, U+0670 and
# U+06D6-U+06ED. Measured against the real QPC Hafs text those leave two vowel
# signs behind - U+0657 ARABIC INVERTED DAMMA (2,901 occurrences) and U+065E
# ARABIC FATHA WITH TWO DOTS (1,807) - because the specified range stops at
# U+0656 while the Arabic combining marks run to U+065F. The first range below
# is therefore widened to U+064B-U+065F, a superset of the original two.
#
# Reviewed and kept, 2026-08-30. Changing any of this silently changes what
# text_simple matches, so treat it as a content migration, not a tweak.
DIACRITIC_RANGES: tuple[tuple[int, int], ...] = (
    (0x064B, 0x065F),  # tanween, harakat, shadda, sukun, and the Quranic
                       # vowel signs through U+065F (widened from U+0656)
    (0x0670, 0x0670),  # superscript (dagger) alef
    (0x06D6, 0x06ED),  # Quranic annotation signs, small high/low letters,
                       # rub-el-hizb and sajdah marks, end-of-ayah U+06DD
)

# Also removed: characters that change nothing about which word is written.
DECORATIVE_CODEPOINTS: frozenset[int] = frozenset(
    {0x0640}                       # tatweel / kashida - pure elongation
    | set(range(0x0660, 0x066A))   # Arabic-Indic digits, see the docstring
)

# Letter normalisations applied after the marks are removed.
LETTER_NORMALISATION: dict[int, int] = {
    0x0622: 0x0627,  # alef with madda above  -> alef
    0x0623: 0x0627,  # alef with hamza above  -> alef
    0x0625: 0x0627,  # alef with hamza below  -> alef
    0x0671: 0x0627,  # alef wasla             -> alef   (added, see docstring)
    0x0649: 0x064A,  # alef maksura           -> yeh
}

_STRIP_SET = frozenset(
    cp for low, high in DIACRITIC_RANGES for cp in range(low, high + 1)
) | DECORATIVE_CODEPOINTS


def simplify_arabic(text: str) -> str:
    """Return a diacritic-free, letter-normalised form of Arabic text.

    This produces the `text_simple` column. Search is not a v1 feature, but the
    column is nearly free to compute at build time and having it means search
    can be added later without a content migration.

    The transformation, in order:

    1. Remove every character in these ranges:
         U+064B-U+065F  tanween, harakat, shadda, sukun, and the remaining
                        Quranic vowel signs. Widened from the originally
                        specified U+064B-U+0652 plus U+0653-U+0656, which stop
                        one short of U+0657 ARABIC INVERTED DAMMA and U+065E
                        ARABIC FATHA WITH TWO DOTS; both occur thousands of
                        times in QPC Hafs text and would otherwise survive into
                        text_simple and break search.
         U+0670         superscript (dagger) alef
         U+06D6-U+06ED  Quranic annotation signs, small high and low letters
                        (including U+06E1, the QPC sukun substitute), the
                        rub-el-hizb mark U+06DE, the sajdah mark U+06E9, and the
                        end-of-ayah symbol U+06DD
    2. Remove U+0640 tatweel, which only stretches a joining stroke, and the
       Arabic-Indic digits U+0660-U+0669. The digits are removed because QUL's
       ayah text ends with the ayah number written in them; leaving them in
       would mean a search for a word could match an ayah number instead. No
       Arabic-Indic digit occurs anywhere else in the text.
    3. Normalise alef variants to bare alef U+0627:
         U+0622 (madda), U+0623 (hamza above), U+0625 (hamza below), and
         U+0671 (alef wasla). Alef wasla occurs 13,483 times in QPC Hafs text;
         without it a search for a word spelled with a plain alef silently
         fails to match.
    4. Normalise alef maksura U+0649 to yeh U+064A.
    5. Collapse every run of whitespace to a single space and trim the ends.
       This also folds the U+00A0 no-break space that QUL places before the
       trailing ayah number, so a stray newline or double space in a source file
       cannot make two otherwise identical strings compare unequal.

    Nothing else is touched. In particular hamza on the line (U+0621), waw and
    yeh carrying hamza (U+0624, U+0626) and teh marbuta (U+0629) are left
    exactly as they are: removing them changes which word is written, not
    merely how it is vocalised.

    The function is deliberately not idempotent-by-accident: running it on its
    own output is a no-op, because every character it produces is outside the
    stripped ranges and outside the normalisation map.
    """
    out = []
    for char in text:
        cp = ord(char)
        if cp in _STRIP_SET:
            continue
        out.append(chr(LETTER_NORMALISATION.get(cp, cp)))
    return WHITESPACE_RE.sub(" ", "".join(out)).strip()


# --------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------


def die(message: str, *details: str) -> "NoReturn":  # type: ignore[valid-type]
    sys.stderr.write(f"\nerror: {message}\n")
    for line in details:
        sys.stderr.write(f"       {line}\n")
    sys.stderr.write("\n")
    raise SystemExit(1)


def clean_text(value: Any, strip_html: bool) -> str:
    """Trim a text field, optionally removing QUL's inline footnote markup."""
    if value is None:
        return ""
    text = str(value)
    if strip_html and "<" in text:
        text = FOOTNOTE_ELEMENT_RE.sub("", text)
        text = HTML_TAG_RE.sub("", text)
        text = html.unescape(text)
    return WHITESPACE_RE.sub(" ", text).strip()


def parse_verse_key(key: str) -> tuple[int, int] | None:
    match = VERSE_KEY_RE.match(str(key).strip())
    if not match:
        return None
    return int(match.group(1)), int(match.group(2))


def ayah_id(surah: int, ayah: int) -> int:
    """The one and only ayah id rule. Computed, never autoincrement."""
    return surah * 1000 + ayah


# QUL's ayah-level Arabic text ends with the ayah number written in
# Arabic-Indic digits, preceded by a no-break space, e.g. "… ٢٥٥".
TRAILING_AYAH_NUMBER_RE = re.compile(r"[\s ]*[٠-٩]+\s*$")


def strip_trailing_ayah_number(text: str) -> str:
    return TRAILING_AYAH_NUMBER_RE.sub("", text).strip()


# --------------------------------------------------------------------------
# reading downloaded files
# --------------------------------------------------------------------------


def sqlite_tables(path: Path) -> set[str]:
    try:
        with sqlite3.connect(f"file:{path}?mode=ro", uri=True) as conn:
            rows = conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()
        return {row[0] for row in rows}
    except sqlite3.Error:
        return set()


def sqlite_schema(path: Path) -> dict[str, list[str]]:
    """Return {table: [column, ...]} for a SQLite file, or {} if unreadable."""
    try:
        with sqlite3.connect(f"file:{path}?mode=ro", uri=True) as conn:
            tables = [
                row[0]
                for row in conn.execute(
                    "SELECT name FROM sqlite_master WHERE type='table'"
                )
            ]
            return {
                table: [row[1] for row in conn.execute(f'PRAGMA table_info("{table}")')]
                for table in tables
            }
    except sqlite3.Error:
        return {}


def sqlite_rows(path: Path, table: str) -> list[dict[str, Any]]:
    with sqlite3.connect(f"file:{path}?mode=ro", uri=True) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(f'SELECT * FROM "{table}"').fetchall()
    return [dict(row) for row in rows]


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        die(f"could not read {path}: {exc}")


def classify(path: Path) -> str | None:
    """Work out what a downloaded file is by looking inside it.

    Returns one of: surahs, script, translation, transliteration, juz, hizb,
    sajdah, mushaf_layout - or None when the file is not recognised.
    """
    suffix = path.suffix.lower()
    if suffix in (".db", ".sqlite", ".sqlite3"):
        schema = sqlite_schema(path)
        tables = set(schema)
        if not tables:
            return None
        if "chapters" in tables:
            return "surahs"
        if "juz" in tables:
            return "juz"
        if "hizbs" in tables:
            return "hizb"
        if "sajdah" in tables or "sajda" in tables:
            return "sajdah"
        if "transliterations" in tables:
            return "transliteration"
        if "translations" in tables or "translation" in tables:
            # QUL exports some transliterations through its translation
            # exporter, so the table name alone is not conclusive.
            return "transliteration" if "translit" in path.stem.lower() else "translation"
        if "pages" in tables and "info" in tables:
            return "mushaf_layout"
        if "verses" in tables:
            return "script"
        if "words" in tables:
            # Word-by-word script export: one row per word, not per ayah.
            return "word_script"
        return None

    if suffix != ".json":
        return None

    data = read_json(path)
    if not isinstance(data, dict) or not data:
        return None

    sample_key = next(iter(data))
    sample_value = data[sample_key]

    if isinstance(sample_value, dict):
        if "name_arabic" in sample_value or "verses_count" in sample_value and "id" in sample_value:
            return "surahs"
        if "verse_mapping" in sample_value or "first_verse_key" in sample_value:
            # juz has 30 entries, hizb 60. Anything else is a sibling
            # division (rub, manzil, ruku) that this pipeline does not use.
            if len(data) == 30:
                return "juz"
            if len(data) == 60:
                return "hizb"
            return None
        if "sajdah_number" in sample_value or "sajdah_type" in sample_value:
            return "sajdah"
        if "text" in sample_value:
            return "script"
        if "t" in sample_value:
            return "translation"
        return None

    if isinstance(sample_value, str) and parse_verse_key(sample_key):
        # {"1:1": "In the name of..."} - translation and transliteration
        # exports are byte-for-byte the same shape, so we cannot tell them
        # apart. Caller must disambiguate with an explicit flag.
        return "verse_text_json"

    return None


def discover(downloads: Path) -> tuple[dict[str, list[Path]], list[Path]]:
    """Classify every file in the downloads directory."""
    found: dict[str, list[Path]] = {}
    unknown: list[Path] = []
    if not downloads.is_dir():
        return found, unknown
    for path in sorted(downloads.rglob("*")):
        if not path.is_file() or path.name.startswith("."):
            continue
        if path.suffix.lower() not in (".db", ".sqlite", ".sqlite3", ".json"):
            continue
        kind = classify(path)
        if kind is None:
            unknown.append(path)
        else:
            found.setdefault(kind, []).append(path)
    return found, unknown


def pick(
    role: str, found: dict[str, list[Path]], override: Path | None, required: bool
) -> Path | None:
    """Choose the file to use for a role, complaining clearly when unsure."""
    if override is not None:
        if not override.exists():
            die(f"--{role.replace('_', '-')} file not found: {override}")
        return override
    candidates = found.get(role, [])
    if len(candidates) == 1:
        return candidates[0]
    if len(candidates) > 1:
        die(
            f"found {len(candidates)} candidate files for '{role}'",
            *[f"- {c}" for c in candidates],
            f"pass --{role.replace('_', '-')} <file> to choose one",
        )
    if required:
        die(
            f"no '{role}' file found in the downloads directory",
            "see content/sources/quran/README.md for what to download from QUL",
        )
    return None


# --------------------------------------------------------------------------
# per-resource loaders
# --------------------------------------------------------------------------


def load_surahs(path: Path) -> dict[int, dict[str, Any]]:
    """Load QUL surah (chapter) metadata from SQLite or JSON."""
    if path.suffix.lower() == ".json":
        raw = read_json(path)
        rows = list(raw.values()) if isinstance(raw, dict) else list(raw)
    else:
        rows = sqlite_rows(path, "chapters")

    surahs: dict[int, dict[str, Any]] = {}
    for row in rows:
        number = row.get("id") or row.get("chapter_id") or row.get("surah_number")
        if number is None:
            continue
        number = int(number)
        name_simple = (row.get("name_simple") or "").strip()
        name_complex = (row.get("name") or row.get("name_complex") or "").strip()
        surahs[number] = {
            "number": number,
            "name_arabic": (row.get("name_arabic") or "").strip(),
            "name_transliterated": name_complex or name_simple,
            "name_english": name_simple or name_complex,
            "revelation_place": (row.get("revelation_place") or "").strip().lower(),
            "ayah_count": int(row.get("verses_count") or 0),
            "has_bismillah": 0 if number == NO_BISMILLAH_SURAH else 1,
            "order_revealed": (
                int(row["revelation_order"])
                if row.get("revelation_order") not in (None, "")
                else None
            ),
        }
    return surahs


def load_script(path: Path) -> tuple[dict[str, str], dict[str, int]]:
    """Load Uthmani ayah text, and page numbers when the export carries them."""
    text_by_key: dict[str, str] = {}
    page_by_key: dict[str, int] = {}

    if path.suffix.lower() != ".json" and "words" in sqlite_schema(path):
        # Word-by-word export: rebuild each ayah by joining its words in order.
        # This is verbatim source text reassembled, never reconstructed text.
        by_key: dict[str, list[tuple[int, str]]] = {}
        for row in sqlite_rows(path, "words"):
            surah = row.get("surah") or row.get("surah_number")
            ayah = row.get("ayah") or row.get("ayah_number")
            if surah is None or ayah is None:
                location = str(row.get("location") or "")
                parts = location.split(":")
                if len(parts) < 2:
                    continue
                surah, ayah = int(parts[0]), int(parts[1])
            position = row.get("word") or row.get("position") or row.get("id") or 0
            text = row.get("text")
            if text:
                by_key.setdefault(f"{int(surah)}:{int(ayah)}", []).append(
                    (int(position), str(text))
                )
        for key, words in by_key.items():
            words.sort(key=lambda pair: pair[0])
            text_by_key[key] = WHITESPACE_RE.sub(
                " ", " ".join(word for _, word in words)
            ).strip()
        return text_by_key, page_by_key

    if path.suffix.lower() == ".json":
        raw = read_json(path)
        rows = []
        for key, value in raw.items():
            if isinstance(value, dict):
                row = dict(value)
                row.setdefault("verse_key", key)
                rows.append(row)
    else:
        rows = sqlite_rows(path, "verses")

    for row in rows:
        key = row.get("verse_key")
        if not key:
            surah = row.get("surah") or row.get("surah_number")
            ayah = row.get("ayah") or row.get("ayah_number")
            if surah is None or ayah is None:
                continue
            key = f"{int(surah)}:{int(ayah)}"
        key = str(key).strip()
        text = row.get("text")
        if text is None:
            # QUL names the column after the script when several coexist.
            for column, value in row.items():
                if column.startswith("text") and value:
                    text = value
                    break
        if text:
            text_by_key[key] = WHITESPACE_RE.sub(" ", str(text)).strip()
        page = row.get("page_number") or row.get("page")
        if page not in (None, ""):
            page_by_key[key] = int(page)

    return text_by_key, page_by_key


def load_verse_text(path: Path, table_names: Iterable[str], strip_html: bool) -> dict[str, str]:
    """Load a verse_key -> text mapping (translation or transliteration)."""
    if path.suffix.lower() == ".json":
        raw = read_json(path)
        out: dict[str, str] = {}
        for key, value in raw.items():
            if isinstance(value, str):
                text = value
            elif isinstance(value, dict):
                text = value.get("t") or value.get("text") or ""
                if isinstance(text, list):
                    # chunked export: [{"t": "..."}, {"f": 1}, ...]
                    text = " ".join(
                        chunk.get("t", "")
                        for chunk in text
                        if isinstance(chunk, dict) and chunk.get("t")
                    )
            else:
                continue
            cleaned = clean_text(text, strip_html)
            if cleaned:
                out[str(key).strip()] = cleaned
        return out

    tables = sqlite_tables(path)
    table = next((name for name in table_names if name in tables), None)
    if table is None:
        die(
            f"{path} has no expected table",
            f"looked for: {', '.join(table_names)}",
            f"found: {', '.join(sorted(tables)) or '(none)'}",
        )

    out = {}
    for row in sqlite_rows(path, table):
        key = row.get("ayah_key") or row.get("verse_key")
        if not key:
            surah = row.get("sura") or row.get("surah_number") or row.get("surah")
            ayah = row.get("ayah") or row.get("ayah_number")
            if surah is None or ayah is None:
                continue
            key = f"{int(surah)}:{int(ayah)}"
        cleaned = clean_text(row.get("text"), strip_html)
        if cleaned:
            out[str(key).strip()] = cleaned
    return out


def _range_pairs(mapping: Any) -> Iterable[tuple[int, int, int]]:
    """Yield (surah, first_ayah, last_ayah) from a QUL verse_mapping value.

    QUL writes verse_mapping in more than one shape depending on the division,
    so accept all of them:
        {"2": "1-141"}                    range string
        {"2": {"range": "1-141", ...}}    range object
        {"2": [1, 2, 3]}                  explicit ayah list
    """
    if not isinstance(mapping, dict):
        return
    for surah_key, value in mapping.items():
        try:
            surah = int(surah_key)
        except (TypeError, ValueError):
            continue
        if isinstance(value, dict):
            value = value.get("range")
        if isinstance(value, list):
            numbers = [int(v) for v in value if str(v).isdigit()]
            if numbers:
                yield surah, min(numbers), max(numbers)
            continue
        if value in (None, ""):
            continue
        text = str(value).strip()
        if "-" in text:
            first, _, last = text.partition("-")
        else:
            first = last = text
        try:
            yield surah, int(first), int(last)
        except ValueError:
            continue


def load_division(
    path: Path, table: str, number_field: str, ayah_counts: dict[int, int], label: str
) -> dict[str, int]:
    """Map every ayah to its juz or hizb number."""
    if path.suffix.lower() == ".json":
        raw = read_json(path)
        rows = list(raw.values()) if isinstance(raw, dict) else list(raw)
    else:
        rows = sqlite_rows(path, table)

    result: dict[str, int] = {}
    for row in rows:
        number = row.get(number_field) or row.get("number") or row.get("id")
        if number is None:
            continue
        number = int(number)

        mapping = row.get("verse_mapping")
        if isinstance(mapping, str):
            try:
                mapping = json.loads(mapping)
            except json.JSONDecodeError:
                mapping = None

        pairs = list(_range_pairs(mapping))
        if not pairs:
            # Fall back to the first/last verse keys, which every division
            # export carries. Divisions are contiguous, so this is exact.
            first = parse_verse_key(row.get("first_verse_key") or "")
            last = parse_verse_key(row.get("last_verse_key") or "")
            if not first or not last:
                continue
            for surah in range(first[0], last[0] + 1):
                start = first[1] if surah == first[0] else 1
                end = last[1] if surah == last[0] else ayah_counts.get(surah, 0)
                if end:
                    pairs.append((surah, start, end))

        for surah, start, end in pairs:
            for ayah in range(start, end + 1):
                result[f"{surah}:{ayah}"] = number

    if not result:
        die(f"could not derive per-ayah {label} numbers from {path}")
    return result


def load_sajdah(path: Path) -> set[str]:
    if path.suffix.lower() == ".json":
        raw = read_json(path)
        rows = list(raw.values()) if isinstance(raw, dict) else list(raw)
    else:
        rows = sqlite_rows(path, "sajdah")
    keys = set()
    for row in rows:
        key = row.get("verse_key")
        if key:
            keys.add(str(key).strip())
    return keys


def load_pages(path: Path) -> dict[str, int]:
    """Load an explicit verse_key -> mushaf page mapping."""
    if path.suffix.lower() == ".json":
        raw = read_json(path)
        out: dict[str, int] = {}
        for key, value in raw.items():
            if isinstance(value, dict):
                value = value.get("page_number") or value.get("page")
            if value in (None, ""):
                continue
            out[str(key).strip()] = int(value)
        return out
    _, pages = load_script(path)
    return pages


def load_english_names(path: Path) -> dict[int, str]:
    raw = read_json(path)
    out: dict[int, str] = {}
    items = raw.items() if isinstance(raw, dict) else enumerate(raw, start=1)
    for key, value in items:
        try:
            number = int(key)
        except (TypeError, ValueError):
            continue
        if isinstance(value, dict):
            value = value.get("name_english") or value.get("translated_name") or ""
        if isinstance(value, str) and value.strip():
            out[number] = value.strip()
    return out


# --------------------------------------------------------------------------
# encoding report
# --------------------------------------------------------------------------

UNICODE_BLOCKS: tuple[tuple[int, int, str], ...] = (
    (0x0000, 0x007F, "Basic Latin"),
    (0x0080, 0x00FF, "Latin-1 Supplement"),
    (0x0600, 0x06FF, "Arabic"),
    (0x0750, 0x077F, "Arabic Supplement"),
    (0x0870, 0x089F, "Arabic Extended-B"),
    (0x08A0, 0x08FF, "Arabic Extended-A"),
    (0x2000, 0x206F, "General Punctuation"),
    (0xE000, 0xF8FF, "Private Use Area"),
    (0xFB50, 0xFDFF, "Arabic Presentation Forms-A"),
    (0xFE70, 0xFEFF, "Arabic Presentation Forms-B"),
    (0x10EC0, 0x10EFF, "Arabic Extended-C"),
    (0x1EE00, 0x1EEFF, "Arabic Mathematical Alphabetic Symbols"),
    (0xF0000, 0xFFFFD, "Supplementary Private Use Area-A"),
    (0x100000, 0x10FFFD, "Supplementary Private Use Area-B"),
)

PRIVATE_USE_BLOCKS = {
    "Private Use Area",
    "Supplementary Private Use Area-A",
    "Supplementary Private Use Area-B",
}


def block_of(cp: int) -> str:
    for low, high, name in UNICODE_BLOCKS:
        if low <= cp <= high:
            return name
    return "Other"


def build_encoding_report(
    counts: Counter[int], script_file: Path, ayah_count: int, numbered: int = 0
) -> tuple[str, str]:
    """Render ENCODING_REPORT.md. Returns (markdown, one-line conclusion).

    Only codepoints, counts and Unicode names are reported. No Quranic text,
    not even a word of it, appears in the report.
    """
    by_block: dict[str, Counter[int]] = {}
    for cp, count in counts.items():
        by_block.setdefault(block_of(cp), Counter())[cp] = count

    pua = {name: block for name, block in by_block.items() if name in PRIVATE_USE_BLOCKS}
    presentation = {
        name for name in by_block if name.startswith("Arabic Presentation Forms")
    }
    unlisted = by_block.get("Other")

    # What this report can say is which codepoints the text uses. What it
    # cannot say is whether a given font draws them: "standard Unicode" is a
    # statement about the encoding, not a promise that any particular face has
    # the glyphs. Amiri Quran is standard-Unicode-compatible and still has no
    # glyph for U+065E, which this text uses 1,807 times. So the conclusion
    # stops at the encoding and points at the check that does know.
    coverage_note = (
        "Whether a bundled font actually has a glyph for each codepoint below is a "
        "separate question, and not one this script can answer. "
        "`tool/check_font_coverage.py` answers it against the built database."
    )

    if pua:
        pua_total = sum(sum(block.values()) for block in pua.values())
        pua_distinct = sum(len(b) for b in pua.values())
        conclusion = (
            f"The Uthmani text is a **font-specific glyph encoding**: "
            f"{pua_distinct} distinct codepoint{'' if pua_distinct == 1 else 's'} "
            f"({pua_total:,} occurrences) fall in the Unicode Private Use Area, "
            f"so it renders only with the matching QUL font and with no general-purpose "
            f"Arabic face at all."
        )
    elif presentation:
        conclusion = (
            "The Uthmani text is standard Unicode but uses Arabic Presentation Forms "
            "(pre-shaped glyphs) rather than base Arabic letters, so shaping is baked "
            "into the text rather than done by the text engine.\n\n"
            + coverage_note
        )
    else:
        conclusion = (
            "The Uthmani text is **standard Unicode Arabic** with no Private Use Area "
            "codepoints and no pre-shaped presentation forms, so any Arabic face that "
            "covers these codepoints can render it and the text engine does the "
            "shaping.\n\n" + coverage_note
        )

    total_chars = sum(counts.values())
    lines = [
        "# Uthmani text encoding report",
        "",
        "Generated by `content/scripts/import_quran.py`. Do not edit by hand.",
        "",
        "This report lists only Unicode codepoints, their official names and how often",
        "each occurs. It contains no Quranic text.",
        "",
        "## Conclusion",
        "",
        conclusion,
        "",
        "## Summary",
        "",
        f"- Source file: `{script_file.name}`",
        f"- Ayahs scanned: {ayah_count:,}",
        f"- Total characters: {total_chars:,}",
        f"- Distinct codepoints: {len(counts):,}",
        f"- Private Use Area codepoints: {sum(len(b) for b in pua.values())}",
        "",
        "## Ayah numbering inside the text",
        "",
        (
            f"{numbered:,} of {ayah_count:,} ayahs end with the ayah number written in "
            "Arabic-Indic\ndigits (U+0660-U+0669), preceded by a no-break space, exactly as "
            "QUL ships\nthem. `text_uthmani` keeps them; run the import with "
            "`--strip-ayah-numbers` if the\napp should render its own numbering instead. "
            "`text_simple` never contains them."
            if numbered
            else "No ayah carries a trailing ayah number in its text."
        ),
        "",
        "## Codepoints by Unicode block",
        "",
        "| Block | Distinct codepoints | Occurrences |",
        "| --- | ---: | ---: |",
    ]
    for name in sorted(by_block, key=lambda n: -sum(by_block[n].values())):
        block = by_block[name]
        flag = " ⚠️ font-specific" if name in PRIVATE_USE_BLOCKS else ""
        lines.append(f"| {name}{flag} | {len(block):,} | {sum(block.values()):,} |")

    if unlisted:
        lines += [
            "",
            "> `Other` means a codepoint outside the blocks this report knows about.",
            "> Check these individually before trusting the conclusion above.",
        ]

    lines += [
        "",
        "## Every codepoint",
        "",
        "| Codepoint | Unicode name | Category | Block | Count |",
        "| --- | --- | --- | --- | ---: |",
    ]
    for cp in sorted(counts):
        try:
            name = unicodedata.name(chr(cp))
        except ValueError:
            name = "(unnamed - Private Use or unassigned)"
        category = unicodedata.category(chr(cp))
        lines.append(
            f"| U+{cp:04X} | {name} | {category} | {block_of(cp)} | {counts[cp]:,} |"
        )
    lines.append("")

    return "\n".join(lines), conclusion


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Normalise downloaded QUL Quran exports into content/sources/quran/.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="QUL has no bulk read API. Download the files first; see "
        "content/sources/quran/README.md.",
    )
    parser.add_argument("--downloads", type=Path, default=DOWNLOADS_DIR)
    parser.add_argument("--out", type=Path, default=QURAN_DIR)
    parser.add_argument("--script", type=Path, help="Uthmani script export")
    parser.add_argument("--translation", type=Path, help="translation export (Saheeh International)")
    parser.add_argument("--transliteration", type=Path, help="English transliteration export")
    parser.add_argument("--surahs", type=Path, help="surah/chapter metadata export")
    parser.add_argument("--juz", type=Path, help="juz metadata export")
    parser.add_argument("--hizb", type=Path, help="hizb metadata export")
    parser.add_argument("--sajdah", type=Path, help="sajdah metadata export")
    parser.add_argument("--pages", type=Path, help="verse_key -> mushaf page mapping")
    parser.add_argument(
        "--english-names",
        type=Path,
        help="JSON {surah number: English name}. Without it, name_english falls back "
        "to the plain transliteration and a warning is printed.",
    )
    parser.add_argument(
        "--translation-edition",
        default="Saheeh International",
        help="stamped into content.db meta",
    )
    parser.add_argument(
        "--strip-ayah-numbers",
        action="store_true",
        help="remove the trailing ayah number that QUL's ayah text ends with "
        "(a no-break space followed by the number in Arabic-Indic digits). Off by "
        "default, so text_uthmani stays byte-identical to the source.",
    )
    parser.add_argument(
        "--quran-source",
        default="QUL (qul.tarteel.ai)",
        help="stamped into content.db meta",
    )
    parser.add_argument(
        "--keep-html",
        action="store_true",
        help="keep QUL's inline footnote markup in translation text instead of stripping it",
    )
    parser.add_argument(
        "--allow-incomplete",
        action="store_true",
        help="warn instead of failing when ayahs are missing text or translation",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="report which downloaded files were recognised, then exit without writing",
    )
    args = parser.parse_args(argv)

    found, unknown = discover(args.downloads)

    if args.check:
        print(f"downloads directory: {args.downloads}")
        if not args.downloads.is_dir():
            print("  (does not exist yet)")
        print()
        for role in (
            "surahs",
            "script",
            "translation",
            "transliteration",
            "verse_text_json",
            "juz",
            "hizb",
            "sajdah",
            "pages",
            "word_script",
            "mushaf_layout",
        ):
            for path in found.get(role, []):
                print(f"  {role:<16} {path.relative_to(args.downloads)}")
        for path in unknown:
            print(f"  {'UNRECOGNISED':<16} {path.relative_to(args.downloads)}")
        if not found and not unknown:
            print("  (nothing found - see content/sources/quran/README.md)")

        # Show what an unrecognised file actually contains, so the next step is
        # obvious rather than a guessing game.
        for path in unknown:
            schema = sqlite_schema(path)
            print(f"\n  {path.name} was not recognised. It contains:")
            if not schema:
                print("    (not a readable SQLite database)")
            for table, columns in schema.items():
                print(f"    table {table!r}: {', '.join(columns)}")

        if found.get("word_script"):
            names = ", ".join(p.name for p in found["word_script"])
            print(
                f"\nnote: {names} is a word-by-word script export - one row per word,\n"
                "      not per ayah. It is not used unless you ask for it with\n"
                f"      --script {found['word_script'][0].name}, which rebuilds each ayah\n"
                "      by joining its words in order."
            )
        if found.get("verse_text_json"):
            print(
                "\nnote: plain {verse_key: string} JSON cannot be told apart as "
                "translation vs transliteration.\n"
                "      Pass --translation/--transliteration explicitly, or download "
                "the SQLite versions."
            )
        if found.get("mushaf_layout"):
            print(
                "\nnote: the mushaf layout export is indexed by word, not by ayah, so it "
                "cannot\n      supply per-ayah page numbers. `page` will be null unless you "
                "pass --pages."
            )
        return 0

    # -- surahs -----------------------------------------------------------
    surah_file = pick("surahs", found, args.surahs, required=True)
    surahs = load_surahs(surah_file)
    if len(surahs) != TOTAL_SURAHS:
        die(
            f"expected {TOTAL_SURAHS} surahs in {surah_file}, found {len(surahs)}",
            "this is probably the wrong resource - see content/sources/quran/README.md",
        )
    ayah_counts = {n: s["ayah_count"] for n, s in surahs.items()}

    if args.english_names:
        english = load_english_names(args.english_names)
        missing = [n for n in surahs if n not in english]
        if missing:
            die(
                f"--english-names is missing {len(missing)} surah(s)",
                f"first missing: {missing[:5]}",
            )
        for number, name in english.items():
            if number in surahs:
                surahs[number]["name_english"] = name
    else:
        print(
            "warning: no --english-names file given; surahs.name_english falls back to "
            "the\n         plain transliteration. Supply one to get real English names."
        )

    # -- ayah text --------------------------------------------------------
    script_file = pick("script", found, args.script, required=True)
    uthmani, page_from_script = load_script(script_file)

    numbered = sum(1 for text in uthmani.values() if TRAILING_AYAH_NUMBER_RE.search(text))
    if args.strip_ayah_numbers:
        uthmani = {key: strip_trailing_ayah_number(t) for key, t in uthmani.items()}
        if numbered:
            print(f"note: stripped the trailing ayah number from {numbered:,} ayah(s)")
    elif numbered:
        print(
            f"note: {numbered:,} of {len(uthmani):,} ayahs end with the ayah number in\n"
            "      Arabic-Indic digits, as QUL ships them. text_uthmani keeps them.\n"
            "      Pass --strip-ayah-numbers if the app should render its own numbering.\n"
            "      (text_simple never contains them either way.)"
        )

    translation_file = pick("translation", found, args.translation, required=True)
    translations = load_verse_text(
        translation_file, ("translations", "translation"), strip_html=not args.keep_html
    )

    transliteration_file = pick(
        "transliteration", found, args.transliteration, required=False
    )
    transliterations = (
        load_verse_text(
            transliteration_file, ("transliterations", "translations", "translation"),
            strip_html=not args.keep_html,
        )
        if transliteration_file
        else {}
    )

    for label, mapping, source in (
        ("script", uthmani, script_file),
        ("translation", translations, translation_file),
        ("transliteration", transliterations, transliteration_file),
    ):
        if source is None or not mapping:
            continue
        if len(mapping) != TOTAL_AYAHS:
            print(
                f"warning: {source.name} yielded {len(mapping):,} ayah keys, "
                f"expected {TOTAL_AYAHS:,}.\n"
                f"         Check that this is an ayah-level {label} export."
            )

    juz_file = pick("juz", found, args.juz, required=True)
    juz_map = load_division(juz_file, "juz", "juz_number", ayah_counts, "juz")

    hizb_file = pick("hizb", found, args.hizb, required=True)
    hizb_map = load_division(hizb_file, "hizbs", "hizb_number", ayah_counts, "hizb")

    sajdah_file = pick("sajdah", found, args.sajdah, required=False)
    sajdah_keys = load_sajdah(sajdah_file) if sajdah_file else set()

    pages_file = pick("pages", found, args.pages, required=False)
    page_map = load_pages(pages_file) if pages_file else dict(page_from_script)

    # -- assemble ---------------------------------------------------------
    ayahs: list[dict[str, Any]] = []
    problems: list[str] = []
    codepoints: Counter[int] = Counter()

    for number in range(1, TOTAL_SURAHS + 1):
        surah = surahs.get(number)
        if surah is None:
            die(f"surah {number} missing from {surah_file}")
        for ayah_number in range(1, surah["ayah_count"] + 1):
            key = f"{number}:{ayah_number}"
            text_uthmani = uthmani.get(key, "")
            translation = translations.get(key, "")
            if not text_uthmani:
                problems.append(f"{key}: no Uthmani text in {script_file.name}")
            if not translation:
                problems.append(f"{key}: no translation in {translation_file.name}")
            codepoints.update(ord(ch) for ch in text_uthmani)
            ayahs.append(
                {
                    "id": ayah_id(number, ayah_number),
                    "surah_number": number,
                    "ayah_number": ayah_number,
                    "text_uthmani": text_uthmani,
                    "text_simple": simplify_arabic(text_uthmani),
                    "translation": translation,
                    "transliteration": transliterations.get(key) or None,
                    "juz": juz_map.get(key),
                    "hizb": hizb_map.get(key),
                    "page": page_map.get(key),
                    "sajdah": 1 if key in sajdah_keys else 0,
                }
            )

    for label, mapping in (("juz", juz_map), ("hizb", hizb_map)):
        missing = [a["id"] for a in ayahs if a[label] is None]
        if missing:
            problems.append(
                f"{len(missing)} ayah(s) have no {label} number "
                f"(first: {missing[0]}) - check the {label} export"
            )

    if len(ayahs) != TOTAL_AYAHS:
        die(
            f"assembled {len(ayahs)} ayahs, expected {TOTAL_AYAHS}",
            "the surah ayah counts in the metadata export look wrong",
        )

    if problems:
        head = problems[:15]
        rest = len(problems) - len(head)
        if args.allow_incomplete:
            sys.stderr.write(f"\nwarning: {len(problems)} incomplete record(s):\n")
            for line in head:
                sys.stderr.write(f"         {line}\n")
            if rest > 0:
                sys.stderr.write(f"         ... and {rest} more\n")
            sys.stderr.write("\n")
        else:
            die(
                f"{len(problems)} incomplete record(s); the download is missing data",
                *head,
                *([f"... and {rest} more"] if rest > 0 else []),
                "re-run with --allow-incomplete to write the files anyway",
            )

    # -- write ------------------------------------------------------------
    args.out.mkdir(parents=True, exist_ok=True)
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    meta = {
        "generated_at": generated_at,
        "generated_by": "content/scripts/import_quran.py",
        "quran_source": f"{args.quran_source} - {script_file.name}",
        "translation_edition": args.translation_edition,
        "transliteration_edition": transliteration_file.name if transliteration_file else None,
        "source_files": {
            "surahs": surah_file.name,
            "script": script_file.name,
            "translation": translation_file.name,
            "transliteration": transliteration_file.name if transliteration_file else None,
            "juz": juz_file.name,
            "hizb": hizb_file.name,
            "sajdah": sajdah_file.name if sajdah_file else None,
            "pages": pages_file.name if pages_file else None,
        },
    }

    surahs_path = args.out / "surahs.json"
    ayahs_path = args.out / "ayahs.json"
    report_path = args.out / "ENCODING_REPORT.md"

    surahs_path.write_text(
        json.dumps(
            {"meta": meta, "surahs": [surahs[n] for n in sorted(surahs)]},
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    ayahs_path.write_text(
        json.dumps({"meta": meta, "ayahs": ayahs}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    report, conclusion = build_encoding_report(
        codepoints, script_file, len(ayahs), 0 if args.strip_ayah_numbers else numbered
    )
    report_path.write_text(report, encoding="utf-8")

    with_page = sum(1 for a in ayahs if a["page"] is not None)
    with_translit = sum(1 for a in ayahs if a["transliteration"])
    print(f"\nimport_quran: wrote {surahs_path}")
    print(f"              wrote {ayahs_path}")
    print(f"              wrote {report_path}")
    print()
    for label, value in (
        ("surahs", len(surahs)),
        ("ayahs", len(ayahs)),
        ("with transliteration", with_translit),
        ("with page number", with_page),
        ("sajdah ayahs", sum(a["sajdah"] for a in ayahs)),
        ("distinct codepoints", len(codepoints)),
    ):
        print(f"  {label:<22}{value:>7,}")
    print()
    print(f"  encoding: {re.sub(r'[*`]', '', conclusion)}")
    if not with_page:
        print(
            "\n  note: no mushaf page numbers were available, so `page` is null "
            "throughout.\n        That is allowed by the schema."
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
