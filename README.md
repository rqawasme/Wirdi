# Wirdi
Daily islamic habits. Reminders. Counters. Dhikr etc based on famous litanies

## What this is

Wirdi is a Flutter app for daily Islamic practice: wird collections, dhikr
collections and Quran surahs, with counters and reminders.

This repository holds the **content pipeline** — the Python that turns source
data into the SQLite database the app bundles — and the Flutter app that reads
it: the data layer, the theme, and (for now) a single throwaway screen for
checking how Arabic renders on a real device. None of the real features are
built yet.

## The content pipeline

`content/` builds `content/build/content.db` from two kinds of input:

- **Hand-authored JSON** — adhkar, collections and hadith references, written and
  maintained by hand under `content/sources/`, validated against JSON Schema.
- **Quran data** — Uthmani text, the Saheeh International translation, transliteration and
  the juz/hizb/sajdah metadata, imported from [QUL](https://qul.tarteel.ai/) and
  normalised by `import_quran.py`.

The normalised Quran JSON — `content/sources/quran/{surahs,ayahs}.json` — is
committed, so a fresh clone builds the real database with nothing to fetch first.
Only the raw QUL exports it was generated from are left out, and only because they
are bulky and needed just to regenerate. See
[`content/sources/quran/README.md`](content/sources/quran/README.md) for that.

Every id in the database is either computed by a fixed rule or written by hand in
the source files. Nothing autoincrements. The database is rebuilt from source
regularly, and users' saved collections point at these ids, so an id that shifted
between builds would silently repoint saved content at something else.

## Running it

```bash
pip install -r content/requirements.txt

python3 content/scripts/validate_json.py    # JSON Schema check of the authored files
python3 content/scripts/build_content.py    # -> content/build/content.db
python3 content/scripts/verify_content.py   # invariant checks, non-zero exit on failure
```

`build_content.py` runs the validator itself and aborts if it fails. The database
is always built from scratch, never incrementally.

`import_quran.py` is not part of a normal build. It regenerates the committed
Quran JSON from QUL exports, and is only needed when refreshing that data.

[`content/README.md`](content/README.md) documents the authoring formats, with a
worked example.

## The data layer

Two SQLite databases, kept separate. They are never joined in SQL; there is no
`ATTACH`.

|  | `content.db` | `user.db` |
|---|---|---|
| Access | read-only | read-write |
| Location | bundled asset, copied to app support on first run | app **documents** directory |
| Contents | Quran, adhkar, sources, built-in collections | user collections, progress, completions, settings |
| Updates | replaced wholesale on app update | migrated, never replaced |

`user.db` is in the documents directory specifically so iOS iCloud backup and
Android Auto Backup pick it up. That is the entire backup strategy: there is no
sync and no server.

```
lib/
  data/
    schema/content.drift    content.db, mirroring the pipeline's SQL
    schema/user.drift       user.db
    content_database.dart   read-only open, schema_version assertion
    user_database.dart
    collection_resolver.dart
    repositories/           the three repository implementations
    database_files.dart     path_provider and the asset copy — the platform seam
  domain/                   hand-written models and the repository interfaces
```

Schemas are `.drift` files rather than Dart table classes: the collection
resolution queries read better as SQL, and keeping the canonical definition in
SQL means `lib/data/schema/content.drift` can be diffed against what the Python
pipeline actually produces. `tool/check_schema_parity.py` is that diff.

Drift's generated row types stop at the repository boundary. `lib/domain/`
imports no drift.

A resolved collection has two views of the same data: `entries` is structural,
with `RepeatBlock`s intact, for display and editing; `steps` is that flattened
for playback, so a three-item block repeated seven times is one entry and
twenty-one steps. Progress indexes `steps` and stores the `ContentRef` it
pointed at, so a reorder or a content update cannot silently resume at the
wrong dhikr — resume through `ResolvedCollection.resumableFrom`, never by
indexing `steps` directly.

SQLite itself comes from `package:sqlite3` 3.x, which downloads a precompiled
library for the target at build time and packages it as a code asset. That
replaces `sqlite3_flutter_libs`, which is end-of-life. `assertSupportedSqlite`
runs at startup and fails if the version in use is old enough to suggest the
platform library is being used instead.

### Running it

```bash
flutter pub get
flutter test
flutter analyze

# after editing either .drift file or a @DriftDatabase class
dart run build_runner build
```

Generated `*.g.dart` files are committed, so a fresh clone can run the tests
without generating first.

Tests run against in-memory databases seeded with structural placeholder text.
They never read the bundled asset. To build and bundle the real one:

```bash
python3 content/scripts/build_content.py   # -> content/build/content.db
tool/sync_content_asset.sh                 # -> assets/content.db (gitignored)
```

## The app

```
lib/
  main.dart               opens both databases, then runs the app
  wirdi_app.dart          MaterialApp, both themes, the settings-driven type scale
  providers/              riverpod: the databases, the repositories, settings
  theme/                  colour, shape, motion, type
  widgets/                the voussoir stripe, the failure screen
  dev/                    throwaway — deleted before release
```

### Running it on a device

```bash
python3 content/scripts/build_content.py   # -> content/build/content.db
tool/sync_content_asset.sh                 # -> assets/content.db (gitignored)

flutter pub get
flutter run                                # iOS or Android; there is no web or desktop target
```

`assets/content.db` is a build artifact and is not committed, but `pubspec.yaml`
names it explicitly. A build without it fails with `unable to locate asset`
rather than producing an app with no content in it.

### The theme

Both themes are written out by hand in `lib/theme/color_schemes.dart`. Neither
is seeded: `ColorScheme.fromSeed` derives every role from one hue, which drags
the limestone surfaces toward brick and throws away the point of the palette.

Depth is tonal — `surface`, `surfaceContainer`, `surfaceContainerHigh` — plus
hairline outlines. Elevation is zero everywhere and `shadowColor` is
transparent in both themes, so nothing casts a shadow even if something later
takes an elevation. Buttons are squared at 8dp, overriding Material's stadium
default.

`tertiary` is gold and is reserved for Quran text. Nothing in
`lib/theme/wirdi_theme.dart` maps it onto a component. Gold appearing anywhere
in the UI means a widget reached for the wrong role — that is the signal, and
it is deliberate that Material components rarely pick `tertiary` on their own.

### Type

Arabic and Latin have two parallel definitions in `lib/theme/typography.dart`;
a single `TextTheme` cannot express both. Three families are bundled as local
assets and none are fetched at runtime — the app works with the radio off, and
Quran text rendered in a substituted font is not the same text.

| | Face | Nominal | Line height |
|---|---|---:|---:|
| Quran verse | Amiri Quran | 24 | 2.0 |
| Dhikr | Noto Naskh Arabic | 20 | 2.0 |
| Translation | Inter | 15 | 1.6 |
| Dhikr caption | Inter | 13 | 1.5 |
| Section header | Inter | 17 | 1.4 |
| Nav and labels | Inter | 14 | 1.4 |
| Caption and meta | Inter | 12 | 1.4 |

Every size there is *nominal*. Arabic faces render at nominal x
`ArabicFace.opticalMultiplier`, because a font's letterforms fill as much of its
em as its designer decided they should, and Amiri Quran — which reserves room
for vocalisation Inter never has to house — fills much less of it. The factor is
per face, and it is derived rather than guessed; see the comment on
`ArabicFace`.

The 2.0 Arabic line height is required, not stylistic: voweled text collides
below it.

Two user multipliers, persisted through `UserRepository` settings, scale the
reading text and nothing else. `arabicScale` drives the Quran verse and the
dhikr with it; `translationScale` drives the translation and the dhikr caption.
Chrome follows the OS accessibility text scale alone. Multipliers are stored,
never pixel sizes — a stored pixel size freezes a choice against a type scale
that will move.

### The dev screen

`lib/dev/` is a rendering harness and is deleted before release. It puts the
known-hard Uthmani cases — elongation, imala, ishmam, the saad-seen variants,
waqf marks in sequence, the sajdah mark — on screen at any size, in either
Arabic face, in gold or in cedar ink, read out of the real database rather than
from literals. It exists to answer two questions that a spec cannot.
