#!/usr/bin/env python3
"""Validate the hand-authored content JSON against the schemas in content/schemas/.

Two phases run in order:

  1. Schema validation - every file in content/sources/adhkar/ and
     content/sources/collections/, plus content/sources/sources.json, is checked
     against its JSON Schema. Malformed JSON is reported with the line, the
     column and the offending source line.

  2. Cross-file id checks - dhikr ids, collection ids and source ids must each
     be unique across all files. These ids are author-assigned and permanent,
     so a collision is a content bug, not a build detail.

Referential checks (does this collection item point at a dhikr that exists?)
belong to build_content.py, which has the Quran data loaded and can resolve
ayah and surah references too.

Exit code is 0 when everything passes and 1 when anything fails.

Usage:
    python3 content/scripts/validate_json.py
    python3 content/scripts/validate_json.py --quiet
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Iterator

try:
    from jsonschema import Draft202012Validator
    from jsonschema.exceptions import ValidationError
except ImportError:  # pragma: no cover - dependency guard
    sys.stderr.write(
        "error: the 'jsonschema' package is required.\n"
        "       Install it with: pip install -r content/requirements.txt\n"
    )
    raise SystemExit(2)

# content/scripts/validate_json.py -> content/
CONTENT_DIR = Path(__file__).resolve().parent.parent
SCHEMAS_DIR = CONTENT_DIR / "schemas"
SOURCES_DIR = CONTENT_DIR / "sources"


class Failure:
    """One human-readable validation failure."""

    def __init__(self, path: Path, location: str, message: str, hint: str = "") -> None:
        self.path = path
        self.location = location
        self.message = message
        self.hint = hint

    def render(self, root: Path) -> str:
        try:
            name = self.path.relative_to(root)
        except ValueError:
            name = self.path
        lines = [f"  {name}", f"    at {self.location}", f"    {self.message}"]
        if self.hint:
            lines.append(f"    hint: {self.hint}")
        return "\n".join(lines)


def json_pointer(error: ValidationError) -> str:
    """Render a validation error's location as a readable JSON path."""
    out = "$"
    for part in error.absolute_path:
        if isinstance(part, int):
            out += f"[{part}]"
        else:
            out += f".{part}"
    return out


def summarise(value: Any, limit: int = 60) -> str:
    """Render an offending value compactly for an error message."""
    try:
        text = json.dumps(value, ensure_ascii=False)
    except (TypeError, ValueError):
        text = repr(value)
    if len(text) > limit:
        text = text[: limit - 1] + "…"
    return text


def describe_expectation(error: ValidationError) -> str:
    """Turn a schema keyword failure into 'expected X, found Y' English."""
    keyword = error.validator
    schema = error.schema if isinstance(error.schema, dict) else {}
    found = summarise(error.instance)

    if keyword == "type":
        expected = error.validator_value
        if isinstance(expected, list):
            expected = " or ".join(expected)
        return f"expected type {expected}, found {found}"
    if keyword == "enum":
        allowed = ", ".join(summarise(v) for v in error.validator_value)
        return f"expected one of [{allowed}], found {found}"
    if keyword == "required":
        return error.message
    if keyword == "additionalProperties":
        known = ", ".join(sorted(schema.get("properties", {})))
        return f"{error.message} (known properties: {known})"
    if keyword == "pattern":
        return f"expected a string matching {error.validator_value!r}, found {found}"
    if keyword == "minimum":
        return f"expected a value >= {error.validator_value}, found {found}"
    if keyword == "maximum":
        return f"expected a value <= {error.validator_value}, found {found}"
    if keyword == "minLength":
        return f"expected a non-empty string of at least {error.validator_value} character(s), found {found}"
    if keyword == "minItems":
        return f"expected at least {error.validator_value} item(s), found {len(error.instance)}"
    if keyword == "oneOf":
        return describe_one_of(error)
    return error.message


def describe_one_of(error: ValidationError) -> str:
    """Explain a oneOf failure in terms of the keys involved.

    Our item schemas use oneOf purely to say "exactly one of dhikr / ayah /
    surah". The stock jsonschema message for that ("is not valid under any of
    the given schemas") tells an author nothing, so spell it out.
    """
    branches = error.validator_value
    keys: list[str] = []
    for branch in branches:
        required = branch.get("required") if isinstance(branch, dict) else None
        if isinstance(branch, dict) and set(branch) == {"required"} and len(required) == 1:
            keys.append(required[0])
        else:
            keys = []
            break

    if keys:
        options = ", ".join(keys)
        if isinstance(error.instance, dict):
            present = [k for k in keys if k in error.instance]
            if not present:
                return f"expected exactly one of [{options}], found none of them"
            if len(present) > 1:
                return (
                    f"expected exactly one of [{options}], "
                    f"found {len(present)} of them: {', '.join(present)}"
                )
        return f"expected exactly one of [{options}]"
    return error.message


def schema_hint(error: ValidationError) -> str:
    """Surface the schema's own description, which documents the format."""
    schema = error.schema if isinstance(error.schema, dict) else {}
    description = schema.get("description", "")
    if description and error.validator not in ("required", "additionalProperties"):
        return description
    if error.validator == "required":
        # Point at the description of the property that is missing.
        missing = error.message.split("'")
        if len(missing) > 1:
            prop = schema.get("properties", {}).get(missing[1], {})
            if isinstance(prop, dict):
                return prop.get("description", "")
    return ""


def load_json(path: Path) -> tuple[Any, Failure | None]:
    """Parse a JSON file, returning a readable failure instead of a traceback."""
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        return None, Failure(path, "$", f"could not read file: {exc}")
    try:
        return json.loads(raw), None
    except json.JSONDecodeError as exc:
        lines = raw.splitlines()
        excerpt = lines[exc.lineno - 1].strip() if 0 < exc.lineno <= len(lines) else ""
        hint = f"line {exc.lineno}: {excerpt}" if excerpt else ""
        return None, Failure(
            path,
            f"line {exc.lineno}, column {exc.colno}",
            f"invalid JSON: {exc.msg}",
            hint,
        )


def validate_file(path: Path, validator: Draft202012Validator) -> tuple[Any, list[Failure]]:
    """Validate one file, returning its parsed data and any failures."""
    data, failure = load_json(path)
    if failure is not None:
        return None, [failure]

    failures = []
    for error in sorted(validator.iter_errors(data), key=lambda e: list(e.absolute_path)):
        failures.append(
            Failure(path, json_pointer(error), describe_expectation(error), schema_hint(error))
        )
    return data, failures


def iter_source_files(sources_dir: Path) -> Iterator[tuple[Path, str]]:
    """Yield (file, schema name) for every hand-authored source file."""
    for path in sorted((sources_dir / "adhkar").glob("*.json")):
        yield path, "adhkar"
    for path in sorted((sources_dir / "collections").glob("*.json")):
        yield path, "collection"
    sources_json = sources_dir / "sources.json"
    if sources_json.exists():
        yield sources_json, "sources"


def check_unique_ids(
    parsed: dict[Path, Any], sources_dir: Path
) -> list[Failure]:
    """Author-assigned ids must be unique across every file of their kind."""
    failures: list[Failure] = []
    seen: dict[str, dict[int, Path]] = {"dhikr": {}, "collection": {}, "source": {}}

    def record(kind: str, item_id: Any, path: Path, location: str) -> None:
        if not isinstance(item_id, int):
            return  # schema validation already reported this
        first = seen[kind].get(item_id)
        if first is not None:
            try:
                first_name = first.relative_to(sources_dir.parent.parent)
            except ValueError:
                first_name = first
            failures.append(
                Failure(
                    path,
                    location,
                    f"duplicate {kind} id {item_id}, already used in {first_name}",
                    "ids are author-assigned and permanent; every one must be unique",
                )
            )
        else:
            seen[kind][item_id] = path

    for path, data in parsed.items():
        if not isinstance(data, dict):
            continue
        if path.parent.name == "adhkar":
            for index, dhikr in enumerate(data.get("adhkar") or []):
                if isinstance(dhikr, dict):
                    record("dhikr", dhikr.get("id"), path, f"$.adhkar[{index}].id")
        elif path.parent.name == "collections":
            record("collection", data.get("id"), path, "$.id")
        elif path.name == "sources.json":
            for index, source in enumerate(data.get("sources") or []):
                if isinstance(source, dict):
                    record("source", source.get("id"), path, f"$.sources[{index}].id")

    return failures


def load_validators(schemas_dir: Path) -> dict[str, Draft202012Validator]:
    validators = {}
    for name in ("adhkar", "collection", "sources"):
        schema_path = schemas_dir / f"{name}.schema.json"
        if not schema_path.exists():
            raise SystemExit(f"error: missing schema {schema_path}")
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        Draft202012Validator.check_schema(schema)
        validators[name] = Draft202012Validator(schema)
    return validators


def validate_all(
    sources_dir: Path = SOURCES_DIR,
    schemas_dir: Path = SCHEMAS_DIR,
    quiet: bool = False,
) -> int:
    """Run both phases. Returns the process exit code."""
    validators = load_validators(schemas_dir)
    repo_root = sources_dir.parent.parent

    files = list(iter_source_files(sources_dir))
    if not files:
        sys.stderr.write(f"error: no source JSON found under {sources_dir}\n")
        return 1

    failures: list[Failure] = []
    parsed: dict[Path, Any] = {}
    for path, schema_name in files:
        data, file_failures = validate_file(path, validators[schema_name])
        failures.extend(file_failures)
        if data is not None:
            parsed[path] = data

    failures.extend(check_unique_ids(parsed, sources_dir))

    if failures:
        sys.stderr.write(
            f"\nFAILED validation: {len(failures)} problem(s) in {len(files)} file(s)\n\n"
        )
        for failure in failures:
            sys.stderr.write(failure.render(repo_root) + "\n\n")
        return 1

    if not quiet:
        print(f"validate_json: OK - {len(files)} file(s) valid")
        for path, _ in files:
            try:
                name = path.relative_to(repo_root)
            except ValueError:
                name = path
            print(f"  {name}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument(
        "--sources-dir", type=Path, default=SOURCES_DIR, help="defaults to content/sources"
    )
    parser.add_argument(
        "--schemas-dir", type=Path, default=SCHEMAS_DIR, help="defaults to content/schemas"
    )
    parser.add_argument("--quiet", action="store_true", help="print nothing on success")
    args = parser.parse_args(argv)
    return validate_all(args.sources_dir, args.schemas_dir, args.quiet)


if __name__ == "__main__":
    raise SystemExit(main())
