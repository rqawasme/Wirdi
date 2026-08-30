# Bundled assets

`content.db` belongs here, and is **not committed**. It carries Quran text and a
translation, which are licensed works this repository does not redistribute —
the same reason `content/sources/quran/downloads/` is not committed.

Build it and copy it in:

```bash
python3 content/scripts/build_content.py
tool/sync_content_asset.sh
```

`WirdiDatabaseFiles.ensureContentDatabase` reads it from the bundle at startup
and copies it into the application support directory. Tests never touch it;
they open in-memory databases instead.
