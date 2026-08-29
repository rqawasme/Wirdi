# Wirdi
Daily islamic habits. Reminders. Counters. Dhikr etc based on famous litanies

## What this is

Wirdi is a Flutter app for daily Islamic practice: wird collections, dhikr
collections and Quran surahs, with counters and reminders.

This repository currently holds the **content pipeline** — the Python that turns
source data into the SQLite database the app bundles. No Flutter or Dart code yet.

## The content pipeline

`content/` builds `content/build/content.db` from two kinds of input:

- **Hand-authored JSON** — adhkar, collections and hadith references, written and
  maintained by hand under `content/sources/`, validated against JSON Schema.
- **Quran data** — Uthmani text, The Clear Quran translation, transliteration and
  the juz/hizb/sajdah metadata, downloaded from
  [QUL](https://qul.tarteel.ai/) and normalised by an import script.

The Quran source data is **not committed**. The Clear Quran translation is used
with the translator's permission, and that permission does not cover
redistributing it here, so each person who builds the database downloads it
themselves. See [`content/sources/quran/README.md`](content/sources/quran/README.md).

Every id in the database is either computed by a fixed rule or written by hand in
the source files. Nothing autoincrements. The database is rebuilt from source
regularly, and users' saved collections point at these ids, so an id that shifted
between builds would silently repoint saved content at something else.

## Running it

```bash
pip install -r content/requirements.txt

python3 content/scripts/import_quran.py     # downloaded QUL files -> normalised JSON
python3 content/scripts/validate_json.py    # JSON Schema check of the authored files
python3 content/scripts/build_content.py    # -> content/build/content.db
python3 content/scripts/verify_content.py   # invariant checks, non-zero exit on failure
```

`build_content.py` runs the validator itself and aborts if it fails. The database
is always built from scratch, never incrementally.

You can build and inspect the database before downloading any Quran data — the
Quran tables will be empty and `verify_content.py` will fail until you import.

[`content/README.md`](content/README.md) documents the authoring formats, with a
worked example.
