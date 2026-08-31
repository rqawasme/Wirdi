# Worked examples of the authoring formats

The files here are a complete, valid set of authored content — one collection,
its adhkar, and the references they cite — exercising every feature of the
format: a count override, an ayah range, a whole surah, a repeat group, per-item
notes, and every optional field.

They are **not part of the build.** `build_content.py` reads `content/sources/`
only, so nothing here reaches `content.db` or the app. That is the point: their
text is the `PLACEHOLDER — to be filled by Rashid` sentinel, and a placeholder
collection sitting in the app's collection list next to a real wird is worse
than no example at all.

Being outside the build does not make them free to rot. CI validates them
against the same schemas as real content, and then *builds* them into a
throwaway database, so a change to the format that breaks the documented example
fails there rather than being discovered by the next person to copy it:

```bash
python3 content/scripts/validate_json.py --sources-dir content/examples

python3 content/scripts/build_content.py \
    --sources-dir content/examples \
    --quran-dir content/sources/quran \
    --out /tmp/example-content.db \
    --require-quran
```

The second command is the one that checks what schema validation cannot: that
every `dhikr` id resolves, every `source_id` resolves, every ayah reference is
within its surah's real length, and every repeat group is contiguous and
agrees on its count.

[`content/README.md`](../README.md) walks through these files field by field.

## Ids

`example.json` reserves collection id 1 and dhikr ids 1001-1003. Nothing stops
real content from using them now that the examples are out of the build, but
keeping them reserved means an example can be copied and built alongside real
content without colliding. Real content starts at 2 and 2001.

## sources.json

`sources.json` lives here rather than in `content/sources/` because the two
references in it are placeholders that only the example dhikr cite. No real
hadith or book reference has been authored yet. When one is,
`content/sources/sources.json` is where it goes — `build_content.py` treats a
missing file as no sources rather than an error, so the location can simply
appear when it is needed.
