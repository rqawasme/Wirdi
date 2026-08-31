#!/usr/bin/env python3
"""Check that every character in content.db has a glyph in the font that renders it.

A font missing a codepoint does not fail loudly. It draws an empty box, or — on
a device with a fallback chain — quietly borrows the glyph from some other face
mid-word, which looks almost right and is harder to notice. Either way nobody
finds out until it is on a screen.

This is the check that finds out first. Run it against a built database:

    python3 tool/check_font_coverage.py                     # content/build/content.db
    python3 tool/check_font_coverage.py --db path/to.db

The cmap parser here is hand-rolled rather than fontTools, for the same reason
tool/check_schema_parity.py parses SQL by hand: this runs in CI, and one file of
standard library is cheaper to trust than a dependency.
"""

from __future__ import annotations

import argparse
import sqlite3
import struct
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "assets" / "fonts"


@dataclass(frozen=True)
class Face:
    """A bundled font, and what it is asked to render."""

    family: str
    filename: str
    renders: str

    #: Whether a missing glyph fails this check. A face the app no longer sets
    #: any text in is still worth reporting on, but it cannot break the build.
    required: bool = True

    #: Codepoints known to be absent, with the reason. A gap listed here is a
    #: decision on record; a gap not listed here is a surprise, and surprises
    #: are what this script exists to catch.
    accepted_gaps: dict[int, str] = field(default_factory=dict)

    @property
    def path(self) -> Path:
        return FONTS / self.filename


#: What renders what. Keep this in step with lib/theme/typography.dart.
FACES = [
    Face(
        family="Noto Naskh Arabic",
        filename="NotoNaskhArabic-Regular.ttf",
        renders="arabic",
    ),
    Face(
        family="Amiri Quran",
        filename="AmiriQuran-Regular.ttf",
        renders="arabic",
        # Bundled for comparison in the dev screen, and not used for any text
        # the app ships. It has no glyph for U+065E, which this text uses
        # heavily — which is why it is not the Quran face.
        required=False,
    ),
    Face(
        family="Inter",
        filename="Inter-Regular.ttf",
        renders="latin",
        accepted_gaps={
            0xFDFA: (
                "the sallallahu-alayhi-wasallam ligature, which the translation "
                "carries inline. A Latin text face has no business owning it; "
                "it is rendered from the Arabic face instead — see "
                "WirdiTypography.translation"
            ),
        },
    ),
]


def read_cmap(path: Path) -> set[int]:
    """Every Unicode codepoint the font maps to a glyph."""
    data = path.read_bytes()

    tag, num_tables = struct.unpack_from(">4sH", data, 0)
    if tag == b"ttcf":  # font collection: take the first font
        offset = struct.unpack_from(">I", data, 12)[0]
        num_tables = struct.unpack_from(">H", data, offset + 4)[0]
        record_start = offset + 12
    else:
        record_start = 12

    cmap_offset = None
    for i in range(num_tables):
        entry = record_start + i * 16
        name, _checksum, table_offset, _length = struct.unpack_from(">4sIII", data, entry)
        if name == b"cmap":
            cmap_offset = table_offset
            break
    if cmap_offset is None:
        raise ValueError(f"{path.name}: no cmap table")

    num_subtables = struct.unpack_from(">H", data, cmap_offset + 2)[0]
    # Prefer a full-repertoire subtable; fall back to the BMP one.
    preference = [(3, 10), (0, 4), (0, 6), (3, 1), (0, 3)]
    best: tuple[int, int] | None = None
    subtables: dict[tuple[int, int], int] = {}
    for i in range(num_subtables):
        entry = cmap_offset + 4 + i * 8
        platform, encoding, sub_offset = struct.unpack_from(">HHI", data, entry)
        subtables[(platform, encoding)] = cmap_offset + sub_offset
    for key in preference:
        if key in subtables:
            best = subtables[key]
            break
    if best is None and subtables:
        best = next(iter(subtables.values()))
    if best is None:
        raise ValueError(f"{path.name}: cmap has no subtables")

    return _read_subtable(data, best, path.name)


def _read_subtable(data: bytes, offset: int, name: str) -> set[int]:
    fmt = struct.unpack_from(">H", data, offset)[0]
    covered: set[int] = set()

    if fmt == 4:
        seg_x2 = struct.unpack_from(">H", data, offset + 6)[0]
        segs = seg_x2 // 2
        ends = offset + 14
        starts = ends + seg_x2 + 2
        deltas = starts + seg_x2
        ranges = deltas + seg_x2
        for i in range(segs):
            end = struct.unpack_from(">H", data, ends + i * 2)[0]
            start = struct.unpack_from(">H", data, starts + i * 2)[0]
            delta = struct.unpack_from(">h", data, deltas + i * 2)[0]
            range_offset = struct.unpack_from(">H", data, ranges + i * 2)[0]
            if start == 0xFFFF:
                continue
            for cp in range(start, end + 1):
                if range_offset == 0:
                    glyph = (cp + delta) & 0xFFFF
                else:
                    at = ranges + i * 2 + range_offset + (cp - start) * 2
                    if at + 2 > len(data):
                        continue
                    glyph = struct.unpack_from(">H", data, at)[0]
                    if glyph:
                        glyph = (glyph + delta) & 0xFFFF
                if glyph:
                    covered.add(cp)

    elif fmt == 12:
        num_groups = struct.unpack_from(">I", data, offset + 12)[0]
        for i in range(num_groups):
            start, end, start_glyph = struct.unpack_from(
                ">III", data, offset + 16 + i * 12
            )
            if start_glyph:
                covered.update(range(start, end + 1))

    elif fmt == 6:
        first, count = struct.unpack_from(">HH", data, offset + 6)
        for i in range(count):
            glyph = struct.unpack_from(">H", data, offset + 10 + i * 2)[0]
            if glyph:
                covered.add(first + i)

    else:
        raise ValueError(f"{name}: unsupported cmap format {fmt}")

    return covered


#: The sentinel the content pipeline uses for text not yet authored. It is
#: Latin prose sitting in Arabic columns, so it would otherwise report the
#: em dash as an Arabic codepoint no Arabic face covers. See content/README.md
#: on why unwritten content is a fixed string rather than an empty one.
PLACEHOLDER = "PLACEHOLDER"


def codepoints(db: sqlite3.Connection) -> dict[str, dict[int, int]]:
    """Every codepoint in content.db, split by the script it is set in."""
    #: column -> which face family renders it
    columns = [
        ("SELECT text_uthmani FROM ayahs", "arabic"),
        ("SELECT text_simple FROM ayahs", "arabic"),
        ("SELECT name_arabic FROM surahs", "arabic"),
        ("SELECT text_arabic FROM adhkar", "arabic"),
        ("SELECT name_arabic FROM collections", "arabic"),
        ("SELECT translation FROM ayahs", "latin"),
        ("SELECT transliteration FROM ayahs", "latin"),
        ("SELECT translation FROM adhkar", "latin"),
        ("SELECT transliteration FROM adhkar", "latin"),
        ("SELECT name_transliterated FROM surahs", "latin"),
        ("SELECT name_english FROM surahs", "latin"),
    ]
    found: dict[str, dict[int, int]] = {"arabic": {}, "latin": {}}
    for query, script in columns:
        for (value,) in db.execute(query):
            if not value or value.startswith(PLACEHOLDER):
                continue
            counts = found[script]
            for ch in value:
                cp = ord(ch)
                # ASCII is not in question for any face here.
                if cp < 0x80:
                    continue
                counts[cp] = counts.get(cp, 0) + 1
    return found


def name_of(cp: int) -> str:
    try:
        return unicodedata.name(chr(cp))
    except ValueError:
        return "<unnamed>"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--db",
        type=Path,
        default=ROOT / "content" / "build" / "content.db",
        help="the built content database (default: content/build/content.db)",
    )
    args = parser.parse_args()

    if not args.db.exists():
        print(
            f"no {args.db} — run: python3 content/scripts/build_content.py",
            file=sys.stderr,
        )
        return 1

    db = sqlite3.connect(args.db)
    try:
        by_script = codepoints(db)
    finally:
        db.close()

    failed = False
    for face in FACES:
        if not face.path.exists():
            print(f"missing font: {face.path}", file=sys.stderr)
            failed = True
            continue

        covered = read_cmap(face.path)
        wanted = by_script[face.renders]
        gaps = {cp: n for cp, n in wanted.items() if cp not in covered}

        unexpected = {cp: n for cp, n in gaps.items() if cp not in face.accepted_gaps}
        accepted = {cp: n for cp, n in gaps.items() if cp in face.accepted_gaps}

        label = face.family if face.required else f"{face.family} (not required)"
        if not gaps:
            print(f"  OK: {label} covers all {len(wanted)} {face.renders} codepoints")
        else:
            print(f"  {label}: {len(gaps)} of {len(wanted)} {face.renders} codepoints missing")

        for cp, count in sorted(accepted.items(), key=lambda kv: -kv[1]):
            print(f"      accepted  U+{cp:04X} {name_of(cp)} ({count:,}x)")
            print(f"                {face.accepted_gaps[cp]}")
        for cp, count in sorted(unexpected.items(), key=lambda kv: -kv[1]):
            print(f"      MISSING   U+{cp:04X} {name_of(cp)} ({count:,}x)")

        # An accepted gap on a face nothing renders with is doubly fine; an
        # unexpected gap on a required face is a rendering bug already shipped.
        if unexpected and face.required:
            failed = True

    if failed:
        print(
            "\nfont coverage check failed: a codepoint above has no glyph in a font "
            "the app renders it with.\nEither the face is wrong for this text, or the "
            "gap is a decision — record it in FACES.accepted_gaps with the reason.",
            file=sys.stderr,
        )
        return 1

    print("\nfont coverage ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
