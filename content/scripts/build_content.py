#!/usr/bin/env python3
"""Build content/build/content.db from the source JSON. Always from scratch.

The database is rebuilt from source regularly, so every id in it is either
computed by a fixed rule or written by hand in the source JSON. There is no
AUTOINCREMENT anywhere: if ids shifted between builds, a user's saved
collections would silently start pointing at different content.

    ayahs.id             surah_number * 1000 + ayah_number
    adhkar.id            explicit, from content/sources/adhkar/*.json
    collections.id       explicit, from content/sources/collections/*.json
    sources.id           explicit, from content/sources/sources.json
    collection_items.id  collection_id * 1000 + position

The build aborts on a duplicate id, an unresolved reference, or anything
validate_json.py rejects.

Usage:
    python3 content/scripts/build_content.py
    python3 content/scripts/build_content.py --require-quran
    python3 content/scripts/build_content.py --out /tmp/content.db
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCHEMA_VERSION = "1"

# content/scripts/build_content.py -> content/
CONTENT_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = CONTENT_DIR.parent
SOURCES_DIR = CONTENT_DIR / "sources"
QURAN_DIR = SOURCES_DIR / "quran"
BUILD_DIR = CONTENT_DIR / "build"
DEFAULT_DB = BUILD_DIR / "content.db"
VALIDATOR = Path(__file__).resolve().parent / "validate_json.py"

MISSING = "MISSING - run import_quran.py"

ITEM_TYPES = ("dhikr", "ayah", "surah")
COLLECTION_TYPES = ("wird", "dhikr_set", "surah_set")

# Positions within a collection are 1..MAX_POSITION, because
# collection_items.id is collection_id * 1000 + position.
MAX_POSITION = 999

# Every table whose rows make up "the content", in a fixed order, each with the
# deterministic ordering used for the checksum. `meta` is excluded because it
# carries built_at, which changes on every build by design.
CHECKSUM_TABLES: tuple[tuple[str, str], ...] = (
    ("surahs", "number"),
    ("ayahs", "id"),
    ("adhkar", "id"),
    ("sources", "id"),
    ("collections", "id"),
    ("collection_items", "id"),
)

ALL_TABLES = tuple(name for name, _ in CHECKSUM_TABLES) + ("meta",)

SCHEMA_SQL = """
-- No AUTOINCREMENT anywhere. Every id is supplied explicitly by the build.

CREATE TABLE surahs (
    number              INTEGER PRIMARY KEY NOT NULL,
    name_arabic         TEXT    NOT NULL,
    name_transliterated TEXT    NOT NULL,
    name_english        TEXT    NOT NULL,
    revelation_place    TEXT    NOT NULL,
    ayah_count          INTEGER NOT NULL,
    has_bismillah       INTEGER NOT NULL,
    order_revealed      INTEGER
);

CREATE TABLE ayahs (
    id              INTEGER PRIMARY KEY NOT NULL,
    surah_number    INTEGER NOT NULL,
    ayah_number     INTEGER NOT NULL,
    text_uthmani    TEXT    NOT NULL,
    text_simple     TEXT    NOT NULL,
    translation     TEXT    NOT NULL,
    transliteration TEXT,
    juz             INTEGER NOT NULL,
    hizb            INTEGER NOT NULL,
    page            INTEGER,
    sajdah          INTEGER NOT NULL
);

CREATE UNIQUE INDEX idx_ayahs_surah_ayah ON ayahs (surah_number, ayah_number);
CREATE INDEX idx_ayahs_juz  ON ayahs (juz);
CREATE INDEX idx_ayahs_hizb ON ayahs (hizb);

CREATE TABLE adhkar (
    id              INTEGER PRIMARY KEY NOT NULL,
    text_arabic     TEXT    NOT NULL,
    translation     TEXT    NOT NULL,
    transliteration TEXT,
    default_count   INTEGER NOT NULL,
    source_id       INTEGER,
    benefits        TEXT,
    notes           TEXT
);

CREATE TABLE sources (
    id         INTEGER PRIMARY KEY NOT NULL,
    collection TEXT NOT NULL,
    reference  TEXT NOT NULL,
    grading    TEXT,
    full_text  TEXT
);

CREATE TABLE collections (
    id           INTEGER PRIMARY KEY NOT NULL,
    name_arabic  TEXT    NOT NULL,
    name_english TEXT    NOT NULL,
    description  TEXT,
    author       TEXT,
    type         TEXT    NOT NULL,
    sort_order   INTEGER NOT NULL
);

CREATE TABLE collection_items (
    id                 INTEGER PRIMARY KEY NOT NULL,
    collection_id      INTEGER NOT NULL,
    item_type          TEXT    NOT NULL,
    item_id            INTEGER NOT NULL,
    position           INTEGER NOT NULL,
    count_override     INTEGER,
    repeat_group       INTEGER,
    repeat_group_count INTEGER,
    note               TEXT
);

CREATE INDEX idx_collection_items_position ON collection_items (collection_id, position);

CREATE TABLE meta (
    key   TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL
);
"""


class BuildError(Exception):
    """A content problem that must stop the build."""


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


# --------------------------------------------------------------------------
# loading
# --------------------------------------------------------------------------


def run_validator(sources_dir: Path) -> None:
    """Abort the build unless validate_json.py passes."""
    print("build_content: running validate_json.py")
    result = subprocess.run(
        [sys.executable, str(VALIDATOR), "--sources-dir", str(sources_dir), "--quiet"]
    )
    if result.returncode != 0:
        raise BuildError("validation failed; fix the errors above and rebuild")


def load_quran(quran_dir: Path, require: bool) -> tuple[list, list, dict[str, str]]:
    """Load the generated Quran JSON. Returns (surahs, ayahs, meta)."""
    surahs_path = quran_dir / "surahs.json"
    ayahs_path = quran_dir / "ayahs.json"
    missing = [p for p in (surahs_path, ayahs_path) if not p.exists()]

    if missing:
        message = (
            "no Quran source data found ("
            + ", ".join(rel(p) for p in missing)
            + ")"
        )
        if require:
            raise BuildError(
                message
                + "\n       run: python3 content/scripts/import_quran.py"
                + "\n       see content/sources/quran/README.md for the downloads it needs"
            )
        print(
            f"\nwarning: {message}.\n"
            "         Building without surahs or ayahs. Any collection item that\n"
            "         references an ayah or a surah will not resolve, and\n"
            "         verify_content.py will fail until you run import_quran.py.\n"
        )
        return [], [], {"quran_source": MISSING, "translation_edition": MISSING}

    surah_doc = read_json(surahs_path)
    ayah_doc = read_json(ayahs_path)
    meta = ayah_doc.get("meta", {})
    return (
        surah_doc.get("surahs", []),
        ayah_doc.get("ayahs", []),
        {
            "quran_source": meta.get("quran_source") or MISSING,
            "translation_edition": meta.get("translation_edition") or MISSING,
        },
    )


def load_adhkar(sources_dir: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    seen: dict[int, Path] = {}
    for path in sorted((sources_dir / "adhkar").glob("*.json")):
        for dhikr in read_json(path).get("adhkar", []):
            dhikr_id = dhikr["id"]
            if dhikr_id in seen:
                raise BuildError(
                    f"duplicate dhikr id {dhikr_id} in {rel(path)}, "
                    f"already defined in {rel(seen[dhikr_id])}"
                )
            seen[dhikr_id] = path
            rows.append({**dhikr, "_file": path})
    return rows


def load_sources(sources_dir: Path) -> list[dict[str, Any]]:
    path = sources_dir / "sources.json"
    if not path.exists():
        return []
    rows: list[dict[str, Any]] = []
    seen: set[int] = set()
    for source in read_json(path).get("sources", []):
        if source["id"] in seen:
            raise BuildError(f"duplicate source id {source['id']} in {rel(path)}")
        seen.add(source["id"])
        rows.append(source)
    return rows


def parse_ayah_ref(ref: str) -> tuple[int, int, int]:
    """Parse "2:255" or "2:285-286" into (surah, first_ayah, last_ayah)."""
    surah_part, _, ayah_part = ref.partition(":")
    surah = int(surah_part)
    if "-" in ayah_part:
        first_part, _, last_part = ayah_part.partition("-")
        first, last = int(first_part), int(last_part)
    else:
        first = last = int(ayah_part)
    return surah, first, last


def load_collections(
    sources_dir: Path,
    dhikr_ids: set[int],
    surah_ayah_counts: dict[int, int],
    have_quran: bool,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Read collection files and flatten their inline items into rows."""
    collections: list[dict[str, Any]] = []
    items: list[dict[str, Any]] = []
    seen: dict[int, Path] = {}

    for path in sorted((sources_dir / "collections").glob("*.json")):
        doc = read_json(path)
        collection_id = doc["id"]
        if collection_id in seen:
            raise BuildError(
                f"duplicate collection id {collection_id} in {rel(path)}, "
                f"already defined in {rel(seen[collection_id])}"
            )
        seen[collection_id] = path

        if doc["type"] not in COLLECTION_TYPES:
            raise BuildError(
                f"{rel(path)}: type {doc['type']!r} is not one of {list(COLLECTION_TYPES)}"
            )

        collections.append(
            {
                "id": collection_id,
                "name_arabic": doc["name_arabic"],
                "name_english": doc["name_english"],
                "description": doc.get("description"),
                "author": doc.get("author"),
                "type": doc["type"],
                "sort_order": doc["sort_order"],
            }
        )

        position = 0
        for index, item in enumerate(doc["items"]):
            where = f"{rel(path)} $.items[{index}]"
            resolved = resolve_item(
                item, where, dhikr_ids, surah_ayah_counts, have_quran, sources_dir
            )
            for item_type, item_id in resolved:
                position += 1
                if position > MAX_POSITION:
                    raise BuildError(
                        f"{rel(path)}: collection {collection_id} has more than "
                        f"{MAX_POSITION} items; collection_items.id is "
                        f"collection_id * 1000 + position, so it cannot address them"
                    )
                items.append(
                    {
                        "id": collection_id * 1000 + position,
                        "collection_id": collection_id,
                        "item_type": item_type,
                        "item_id": item_id,
                        "position": position,
                        "count_override": item.get("count"),
                        "repeat_group": item.get("repeat_group"),
                        "repeat_group_count": item.get("repeat_group_count"),
                        "note": item.get("note"),
                        "_where": where,
                    }
                )

        check_repeat_groups(
            [i for i in items if i["collection_id"] == collection_id], rel(path)
        )

    return collections, items


def resolve_item(
    item: dict[str, Any],
    where: str,
    dhikr_ids: set[int],
    surah_ayah_counts: dict[int, int],
    have_quran: bool,
    sources_dir: Path,
) -> list[tuple[str, int]]:
    """Turn one authored item into (item_type, item_id) pairs.

    An ayah range expands to one pair per ayah; everything else is a single
    pair. References are checked here so the error names the file and path.
    """
    if "dhikr" in item:
        dhikr_id = item["dhikr"]
        if dhikr_id not in dhikr_ids:
            raise BuildError(
                f"{where}: dhikr {dhikr_id} does not exist in "
                f"{rel(sources_dir / 'adhkar')}/"
            )
        return [("dhikr", dhikr_id)]

    if "surah" in item:
        number = item["surah"]
        if have_quran and number not in surah_ayah_counts:
            raise BuildError(f"{where}: surah {number} does not exist")
        return [("surah", number)]

    if "ayah" in item:
        ref = item["ayah"]
        surah, first, last = parse_ayah_ref(ref)
        if first > last:
            raise BuildError(
                f"{where}: ayah range {ref!r} runs backwards ({first} > {last})"
            )
        if have_quran:
            count = surah_ayah_counts.get(surah)
            if count is None:
                raise BuildError(f"{where}: surah {surah} does not exist (from {ref!r})")
            if last > count:
                raise BuildError(
                    f"{where}: {ref!r} is out of range; surah {surah} has {count} ayahs"
                )
        return [("ayah", surah * 1000 + ayah) for ayah in range(first, last + 1)]

    raise BuildError(f"{where}: item has none of dhikr / ayah / surah")


def check_repeat_groups(items: list[dict[str, Any]], filename: str) -> None:
    """A repeat group must be contiguous and agree on its repetition count."""
    groups: dict[int, list[dict[str, Any]]] = {}
    for item in items:
        group = item.get("repeat_group")
        if group is not None:
            groups.setdefault(group, []).append(item)

    for group, members in groups.items():
        counts = {m["repeat_group_count"] for m in members}
        if len(counts) > 1:
            raise BuildError(
                f"{filename}: repeat_group {group} has conflicting "
                f"repeat_group_count values {sorted(counts)}; every item in a "
                f"group must agree"
            )
        positions = sorted(m["position"] for m in members)
        if positions != list(range(positions[0], positions[0] + len(positions))):
            raise BuildError(
                f"{filename}: repeat_group {group} is not contiguous "
                f"(positions {positions}); a repeat group must be a single block"
            )


# --------------------------------------------------------------------------
# writing
# --------------------------------------------------------------------------


def insert(conn: sqlite3.Connection, table: str, columns: list[str], rows: list[dict]) -> None:
    if not rows:
        return
    placeholders = ", ".join("?" for _ in columns)
    sql = f"INSERT INTO {table} ({', '.join(columns)}) VALUES ({placeholders})"
    try:
        conn.executemany(sql, [[row.get(col) for col in columns] for row in rows])
    except sqlite3.IntegrityError as exc:
        raise BuildError(f"{table}: {exc}") from exc


def content_checksum(conn: sqlite3.Connection) -> str:
    """SHA-256 over the content rows in a fixed table and row order.

    `meta` is excluded because built_at changes every build. Two builds of the
    same source therefore produce the same checksum, and a changed checksum
    means the content genuinely changed.
    """
    digest = hashlib.sha256()
    conn.row_factory = sqlite3.Row
    for table, order_by in CHECKSUM_TABLES:
        digest.update(f"\n#{table}\n".encode("utf-8"))
        for row in conn.execute(f"SELECT * FROM {table} ORDER BY {order_by}"):
            digest.update(
                json.dumps(
                    dict(row), sort_keys=True, ensure_ascii=False, separators=(",", ":")
                ).encode("utf-8")
            )
            digest.update(b"\n")
    conn.row_factory = None
    return digest.hexdigest()


def build(args: argparse.Namespace) -> int:
    sources_dir: Path = args.sources_dir
    run_validator(sources_dir)

    surahs, ayahs, quran_meta = load_quran(args.quran_dir, args.require_quran)
    surah_ayah_counts = {s["number"]: s["ayah_count"] for s in surahs}
    have_quran = bool(surahs and ayahs)

    source_rows = load_sources(sources_dir)
    source_ids = {s["id"] for s in source_rows}

    adhkar_rows = load_adhkar(sources_dir)
    for dhikr in adhkar_rows:
        source_id = dhikr.get("source_id")
        if source_id is not None and source_id not in source_ids:
            raise BuildError(
                f"{rel(dhikr['_file'])}: dhikr {dhikr['id']} references "
                f"source_id {source_id}, which is not in "
                f"{rel(sources_dir / 'sources.json')}"
            )
    dhikr_ids = {d["id"] for d in adhkar_rows}

    collection_rows, item_rows = load_collections(
        sources_dir, dhikr_ids, surah_ayah_counts, have_quran
    )

    seen_ayah_ids: set[int] = set()
    for ayah in ayahs:
        expected = ayah["surah_number"] * 1000 + ayah["ayah_number"]
        if ayah["id"] != expected:
            raise BuildError(
                f"ayah {ayah['surah_number']}:{ayah['ayah_number']} has id "
                f"{ayah['id']}, expected {expected}"
            )
        if ayah["id"] in seen_ayah_ids:
            raise BuildError(f"duplicate ayah id {ayah['id']}")
        seen_ayah_ids.add(ayah["id"])

    # -- write from scratch, never incrementally ---------------------------
    db_path: Path = args.out
    db_path.parent.mkdir(parents=True, exist_ok=True)
    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(db_path)
    try:
        conn.executescript(SCHEMA_SQL)

        insert(conn, "surahs", [
            "number", "name_arabic", "name_transliterated", "name_english",
            "revelation_place", "ayah_count", "has_bismillah", "order_revealed",
        ], surahs)

        insert(conn, "ayahs", [
            "id", "surah_number", "ayah_number", "text_uthmani", "text_simple",
            "translation", "transliteration", "juz", "hizb", "page", "sajdah",
        ], ayahs)

        insert(conn, "adhkar", [
            "id", "text_arabic", "translation", "transliteration",
            "default_count", "source_id", "benefits", "notes",
        ], adhkar_rows)

        insert(conn, "sources", [
            "id", "collection", "reference", "grading", "full_text",
        ], source_rows)

        insert(conn, "collections", [
            "id", "name_arabic", "name_english", "description", "author",
            "type", "sort_order",
        ], collection_rows)

        insert(conn, "collection_items", [
            "id", "collection_id", "item_type", "item_id", "position",
            "count_override", "repeat_group", "repeat_group_count", "note",
        ], item_rows)

        checksum = content_checksum(conn)
        meta_rows = {
            "schema_version": SCHEMA_VERSION,
            "content_version": args.content_version,
            "built_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "quran_source": quran_meta["quran_source"],
            "translation_edition": quran_meta["translation_edition"],
            "content_checksum": checksum,
        }
        conn.executemany(
            "INSERT INTO meta (key, value) VALUES (?, ?)", sorted(meta_rows.items())
        )
        conn.commit()

        counts = {
            table: conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            for table in ALL_TABLES
        }
    finally:
        conn.close()

    print(f"\nbuild_content: wrote {rel(db_path)}\n")
    width = max(len(t) for t in ALL_TABLES)
    for table in ALL_TABLES:
        print(f"  {table:<{width}}  {counts[table]:>7,}")
    print()
    for key in sorted(meta_rows):
        if key != "content_checksum":
            print(f"  {key:<20} {meta_rows[key]}")
    print(f"\n  content checksum     {checksum}")
    print("  (unchanged checksum = unchanged content; built_at is excluded)\n")

    if not have_quran:
        print(
            "  Quran tables are empty. Run import_quran.py, then rebuild.\n"
        )
    return 0


def default_content_version() -> str:
    version_file = SOURCES_DIR / "VERSION"
    if version_file.exists():
        text = version_file.read_text(encoding="utf-8").strip()
        if text:
            return text
    return "0.0.0"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--sources-dir", type=Path, default=SOURCES_DIR)
    parser.add_argument("--quran-dir", type=Path, default=QURAN_DIR)
    parser.add_argument("--out", type=Path, default=DEFAULT_DB)
    parser.add_argument(
        "--content-version",
        default=default_content_version(),
        help="defaults to the contents of content/sources/VERSION",
    )
    parser.add_argument(
        "--require-quran",
        action="store_true",
        help="fail instead of warning when the Quran source JSON is missing",
    )
    args = parser.parse_args(argv)

    try:
        return build(args)
    except BuildError as exc:
        sys.stderr.write(f"\nbuild failed: {exc}\n\n")
        return 1
    except (KeyError, TypeError, ValueError) as exc:
        sys.stderr.write(f"\nbuild failed: malformed source data: {exc}\n\n")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
