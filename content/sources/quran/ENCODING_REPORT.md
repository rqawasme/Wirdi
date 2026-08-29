# Uthmani text encoding report

**Not generated yet.**

This file is written by `content/scripts/import_quran.py` and is overwritten on
every import. It is committed (unlike the rest of this directory) because it
records a property of the source data that determines a rendering decision in the
Flutter app, and that is worth keeping in version control.

It cannot be generated in this environment: the QUL host is unreachable from the
build sandbox, and no Quran data may be invented to stand in for it. Download the
files described in `README.md` and run:

```bash
python3 content/scripts/import_quran.py
```

Then commit the regenerated report.

## What it will tell you

The report contains no Quranic text — only Unicode codepoints, their official
Unicode names, their general categories and how often each occurs.

The question it answers is whether the Uthmani text is standard Unicode Arabic or
a font-specific glyph encoding, because that decides whether **Amiri Quran** can
render it:

- **No Private Use Area codepoints** → standard Unicode Arabic. Amiri Quran
  renders it directly.
- **Codepoints in U+E000–U+F8FF (or the supplementary PUA planes)** → a
  font-specific glyph encoding. It renders only with the matching QUL font, and
  Amiri Quran will show tofu. QUL's `code_v1` / `code_v2` scripts are of this kind;
  its plain Uthmani / QPC Hafs script is not.
- **Arabic Presentation Forms (U+FB50–U+FDFF, U+FE70–U+FEFF)** → standard Unicode,
  but with shaping baked into the codepoints rather than done by the text engine.
  Renderable, though worth knowing about.

The report states which of these applies in a one-line conclusion at the top, then
breaks the codepoints down by Unicode block and lists every one with its count.
