#!/usr/bin/env python3
"""Check lib/data/schema/content.drift against a real content.db.

The Dart data layer keeps its copy of the content schema as SQL rather than as
drift table classes precisely so it can be diffed against what the Python
pipeline actually produces. This is that diff.

It compares the set of tables, and for each table the column names, declared
types, NOT NULL flags and primary key membership. Formatting, index definitions
and the `AS RowClass` suffixes drift needs are ignored.

Usage:
    python3 tool/check_schema_parity.py
    python3 tool/check_schema_parity.py --db /tmp/content.db
"""

from __future__ import annotations

import argparse
import re
import sqlite3
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DB = REPO_ROOT / "content" / "build" / "content.db"
DRIFT_FILE = REPO_ROOT / "lib" / "data" / "schema" / "content.drift"

# `CREATE TABLE x (...) AS RowClass` — drift's row-class suffix is not SQL.
AS_ROW_CLASS = re.compile(r"\)\s*AS\s+\w+\s*$", re.IGNORECASE)
LINE_COMMENT = re.compile(r"--[^\n]*")


def columns(conn: sqlite3.Connection, table: str) -> list[tuple]:
    return [
        (row[1], row[2].upper(), row[3], row[5])  # name, type, notnull, pk
        for row in conn.execute(f"PRAGMA table_info({table})")
    ]


def tables(conn: sqlite3.Connection) -> list[str]:
    return sorted(
        row[0]
        for row in conn.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%'"
        )
    )


def load_drift_schema() -> sqlite3.Connection:
    """Execute the CREATE statements from content.drift into a scratch db."""
    text = LINE_COMMENT.sub("", DRIFT_FILE.read_text(encoding="utf-8"))
    # The named queries in the same file are `name: SELECT ...;` statements,
    # which sqlite cannot execute. Keep only the CREATEs.
    statements = [
        AS_ROW_CLASS.sub(")", s.strip())
        for s in text.split(";")
        if s.strip().upper().startswith("CREATE")
    ]
    conn = sqlite3.connect(":memory:")
    conn.executescript(";\n".join(statements) + ";")
    return conn


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    args = parser.parse_args(argv)

    if not args.db.exists():
        sys.stderr.write(
            f"no {args.db} — run: python3 content/scripts/build_content.py\n"
        )
        return 1

    built = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True)
    declared = load_drift_schema()

    problems: list[str] = []

    built_tables = tables(built)
    declared_tables = tables(declared)
    for name in sorted(set(built_tables) ^ set(declared_tables)):
        where = "content.db" if name in built_tables else "content.drift"
        problems.append(f"table {name!r} is only in {where}")

    for name in sorted(set(built_tables) & set(declared_tables)):
        want = columns(built, name)
        got = columns(declared, name)
        if want != got:
            problems.append(f"table {name!r} differs:")
            for column in sorted({c[0] for c in want} | {c[0] for c in got}):
                a = next((c for c in want if c[0] == column), None)
                b = next((c for c in got if c[0] == column), None)
                if a != b:
                    problems.append(f"    {column}: content.db {a} != content.drift {b}")

    built.close()
    declared.close()

    if problems:
        sys.stderr.write("\ncontent.drift does not match the built database:\n\n")
        for problem in problems:
            sys.stderr.write(f"  {problem}\n")
        sys.stderr.write(
            "\nlib/data/schema/content.drift must mirror SCHEMA_SQL in "
            "content/scripts/build_content.py.\n\n"
        )
        return 1

    print(
        f"schema parity ok: {len(declared_tables)} tables match between "
        f"content.drift and {args.db.name}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
