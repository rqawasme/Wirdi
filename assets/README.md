# Bundled assets

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
