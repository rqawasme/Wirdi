#!/usr/bin/env python3
"""Check a built content.db for the invariants the Flutter app relies on.

Every check is independent and all of them run, so one failure does not hide
the rest. Results print as a pass/fail table and the process exits non-zero if
anything failed.

Usage:
    python3 content/scripts/verify_content.py
    python3 content/scripts/verify_content.py --db /tmp/content.db
    python3 content/scripts/verify_content.py --verbose
"""

from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path

# content/scripts/verify_content.py -> content/
CONTENT_DIR = Path(__file__).resolve().parent.parent
DEFAULT_DB = CONTENT_DIR / "build" / "content.db"

EXPECTED_SURAHS = 114
EXPECTED_AYAHS = 6236
NO_BISMILLAH_SURAH = 9

ITEM_TYPES = ("dhikr", "ayah", "surah")
COLLECTION_TYPES = ("wird", "dhikr_set", "surah_set")

# collection_items.item_type -> (table, id column)
ITEM_TARGETS = {
    "dhikr": ("adhkar", "id"),
    "ayah": ("ayahs", "id"),
    "surah": ("surahs", "number"),
}

MAX_DETAIL_LINES = 10


class Check:
    """One named invariant and whatever went wrong with it."""

    def __init__(self, name: str) -> None:
        self.name = name
        self.failures: list[str] = []

    def fail(self, detail: str) -> None:
        self.failures.append(detail)

    @property
    def passed(self) -> bool:
        return not self.failures


class Verifier:
    def __init__(self, conn: sqlite3.Connection) -> None:
        self.conn = conn
        self.checks: list[Check] = []

    def check(self, name: str) -> Check:
        check = Check(name)
        self.checks.append(check)
        return check

    def q(self, sql: str, params: tuple = ()) -> list[sqlite3.Row]:
        return self.conn.execute(sql, params).fetchall()

    def scalar(self, sql: str, params: tuple = ()):
        return self.conn.execute(sql, params).fetchone()[0]

    # -- individual checks ------------------------------------------------

    def surah_count(self) -> None:
        check = self.check(f"{EXPECTED_SURAHS} surahs")
        found = self.scalar("SELECT COUNT(*) FROM surahs")
        if found != EXPECTED_SURAHS:
            check.fail(f"found {found} surahs, expected {EXPECTED_SURAHS}")

    def ayah_count(self) -> None:
        check = self.check(f"{EXPECTED_AYAHS:,} ayahs")
        found = self.scalar("SELECT COUNT(*) FROM ayahs")
        if found != EXPECTED_AYAHS:
            check.fail(f"found {found:,} ayahs, expected {EXPECTED_AYAHS:,}")

    def per_surah_ayah_counts(self) -> None:
        check = self.check("per-surah ayah counts match surahs.ayah_count")
        rows = self.q(
            """
            SELECT s.number, s.ayah_count, COUNT(a.id) AS actual
            FROM surahs s
            LEFT JOIN ayahs a ON a.surah_number = s.number
            GROUP BY s.number, s.ayah_count
            HAVING actual != s.ayah_count
            ORDER BY s.number
            """
        )
        for row in rows:
            check.fail(
                f"surah {row['number']}: ayah_count says {row['ayah_count']}, "
                f"found {row['actual']} ayah rows"
            )

    def ayah_text_present(self) -> None:
        check = self.check("no null or empty ayah text, simple text or translation")
        for column in ("text_uthmani", "text_simple", "translation"):
            rows = self.q(
                f"SELECT id FROM ayahs WHERE {column} IS NULL OR TRIM({column}) = '' "
                "ORDER BY id"
            )
            if rows:
                ids = ", ".join(str(r["id"]) for r in rows[:5])
                more = f" (+{len(rows) - 5} more)" if len(rows) > 5 else ""
                check.fail(f"{len(rows)} ayah(s) have empty {column}: {ids}{more}")

    def ayah_ids(self) -> None:
        check = self.check("every ayahs.id equals surah_number * 1000 + ayah_number")
        rows = self.q(
            "SELECT id, surah_number, ayah_number FROM ayahs "
            "WHERE id != surah_number * 1000 + ayah_number ORDER BY id"
        )
        for row in rows:
            check.fail(
                f"ayah {row['surah_number']}:{row['ayah_number']} has id {row['id']}, "
                f"expected {row['surah_number'] * 1000 + row['ayah_number']}"
            )

    def bismillah(self) -> None:
        check = self.check(f"only surah {NO_BISMILLAH_SURAH} has has_bismillah = 0")
        rows = self.q(
            "SELECT number, has_bismillah FROM surahs "
            "WHERE (number = ? AND has_bismillah != 0) "
            "   OR (number != ? AND has_bismillah != 1) ORDER BY number",
            (NO_BISMILLAH_SURAH, NO_BISMILLAH_SURAH),
        )
        for row in rows:
            expected = 0 if row["number"] == NO_BISMILLAH_SURAH else 1
            check.fail(
                f"surah {row['number']}: has_bismillah is {row['has_bismillah']}, "
                f"expected {expected}"
            )

    def item_references(self) -> None:
        check = self.check("every collection_items.item_id resolves")
        for item_type, (table, column) in ITEM_TARGETS.items():
            rows = self.q(
                f"""
                SELECT ci.id, ci.collection_id, ci.position, ci.item_id
                FROM collection_items ci
                LEFT JOIN {table} t ON t.{column} = ci.item_id
                WHERE ci.item_type = ? AND t.{column} IS NULL
                ORDER BY ci.id
                """,
                (item_type,),
            )
            for row in rows:
                check.fail(
                    f"collection {row['collection_id']} position {row['position']}: "
                    f"{item_type} {row['item_id']} is not in {table}"
                )

    def unique_positions(self) -> None:
        check = self.check("no duplicate (collection_id, position) pairs")
        rows = self.q(
            "SELECT collection_id, position, COUNT(*) AS n FROM collection_items "
            "GROUP BY collection_id, position HAVING n > 1 "
            "ORDER BY collection_id, position"
        )
        for row in rows:
            check.fail(
                f"collection {row['collection_id']} has {row['n']} items at "
                f"position {row['position']}"
            )

    def repeat_groups(self) -> None:
        check = self.check("every repeat_group has a repeat_group_count")
        rows = self.q(
            "SELECT id, collection_id, position FROM collection_items "
            "WHERE repeat_group IS NOT NULL AND repeat_group_count IS NULL "
            "ORDER BY id"
        )
        for row in rows:
            check.fail(
                f"collection {row['collection_id']} position {row['position']}: "
                f"repeat_group set but repeat_group_count is null"
            )

    def adhkar_sources(self) -> None:
        check = self.check("every adhkar.source_id resolves against sources")
        rows = self.q(
            "SELECT a.id, a.source_id FROM adhkar a "
            "LEFT JOIN sources s ON s.id = a.source_id "
            "WHERE a.source_id IS NOT NULL AND s.id IS NULL ORDER BY a.id"
        )
        for row in rows:
            check.fail(f"dhikr {row['id']} references missing source_id {row['source_id']}")

    def legal_enums(self) -> None:
        check = self.check("every item_type and collection type is legal")
        placeholders = ", ".join("?" for _ in ITEM_TYPES)
        rows = self.q(
            f"SELECT id, collection_id, position, item_type FROM collection_items "
            f"WHERE item_type NOT IN ({placeholders}) ORDER BY id",
            ITEM_TYPES,
        )
        for row in rows:
            check.fail(
                f"collection {row['collection_id']} position {row['position']}: "
                f"item_type {row['item_type']!r} is not one of {list(ITEM_TYPES)}"
            )
        placeholders = ", ".join("?" for _ in COLLECTION_TYPES)
        rows = self.q(
            f"SELECT id, type FROM collections WHERE type NOT IN ({placeholders}) "
            "ORDER BY id",
            COLLECTION_TYPES,
        )
        for row in rows:
            check.fail(
                f"collection {row['id']}: type {row['type']!r} is not one of "
                f"{list(COLLECTION_TYPES)}"
            )

    def meta_keys(self) -> None:
        check = self.check("meta carries the required keys")
        required = (
            "schema_version",
            "content_version",
            "built_at",
            "quran_source",
            "translation_edition",
        )
        present = {row["key"]: row["value"] for row in self.q("SELECT key, value FROM meta")}
        for key in required:
            if key not in present:
                check.fail(f"meta is missing {key!r}")
            elif not str(present[key]).strip():
                check.fail(f"meta[{key!r}] is empty")

    def no_autoincrement(self) -> None:
        check = self.check("no AUTOINCREMENT primary keys")
        rows = self.q(
            "SELECT name, sql FROM sqlite_master WHERE type = 'table' AND sql IS NOT NULL"
        )
        for row in rows:
            if "AUTOINCREMENT" in row["sql"].upper():
                check.fail(f"table {row['name']} declares AUTOINCREMENT")

    def run_all(self) -> None:
        self.surah_count()
        self.ayah_count()
        self.per_surah_ayah_counts()
        self.ayah_text_present()
        self.ayah_ids()
        self.bismillah()
        self.item_references()
        self.unique_positions()
        self.repeat_groups()
        self.adhkar_sources()
        self.legal_enums()
        self.meta_keys()
        self.no_autoincrement()


def render(checks: list[Check], verbose: bool) -> None:
    width = max(len(c.name) for c in checks)
    print()
    print(f"  {'CHECK'.ljust(width)}   RESULT")
    print(f"  {'-' * width}   ------")
    for check in checks:
        status = "PASS" if check.passed else "FAIL"
        suffix = "" if check.passed else f"  ({len(check.failures)} problem(s))"
        print(f"  {check.name.ljust(width)}   {status}{suffix}")

    failed = [c for c in checks if not c.passed]
    if failed:
        print("\n  Details:")
        for check in failed:
            print(f"\n  {check.name}")
            shown = check.failures if verbose else check.failures[:MAX_DETAIL_LINES]
            for detail in shown:
                print(f"    - {detail}")
            hidden = len(check.failures) - len(shown)
            if hidden > 0:
                print(f"    ... and {hidden} more (re-run with --verbose)")

    total = len(checks)
    passed = total - len(failed)
    print()
    if failed:
        print(f"  FAILED: {passed}/{total} checks passed, {len(failed)} failed\n")
    else:
        print(f"  OK: {passed}/{total} checks passed\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument(
        "--verbose", action="store_true", help="print every failing row, not just the first few"
    )
    args = parser.parse_args(argv)

    if not args.db.exists():
        sys.stderr.write(
            f"\nerror: {args.db} does not exist.\n"
            "       Build it first: python3 content/scripts/build_content.py\n\n"
        )
        return 1

    conn = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    try:
        verifier = Verifier(conn)
        try:
            verifier.run_all()
        except sqlite3.Error as exc:
            sys.stderr.write(f"\nerror: {args.db} is not a valid content database: {exc}\n\n")
            return 1
    finally:
        conn.close()

    print(f"verify_content: {args.db}")
    render(verifier.checks, args.verbose)
    return 0 if all(c.passed for c in verifier.checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
