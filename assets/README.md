# Bundled assets

## Fonts

`fonts/` holds the three families, committed, with their OFL licences beside
them:

| File | Family | For |
|---|---|---|
| `AmiriQuran-Regular.ttf` | Amiri Quran | Quran text only |
| `NotoNaskhArabic-{Regular,Bold}.ttf` | Noto Naskh Arabic | dhikr, Arabic chrome |
| `Inter-{Regular,Medium}.ttf` | Inter | all Latin |

They are bundled rather than fetched. `google_fonts` downloads at first use and
caches, which means an app that is silently different on its first run and
wrong with no network — and Quran text rendered in whatever the platform
substitutes is not the same text.

`pubspec.yaml` registers them under the family names in
`lib/theme/typography.dart`. Changing one means changing both.

## content.db

`content.db` belongs here, and is **not committed**. It is a build artifact:
several megabytes, reproducible from `content/sources/` at any time, and stale the
moment the sources change.

Build it and copy it in:

```bash
python3 content/scripts/build_content.py
tool/sync_content_asset.sh
```

`WirdiDatabaseFiles.ensureContentDatabase` reads it from the bundle at startup
and copies it into the application support directory. Tests never touch it;
they open in-memory databases instead.
