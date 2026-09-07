# Wirdi
Daily islamic habits. Reminders. Counters. Dhikr etc based on famous litanies

## What this is

Wirdi is a Flutter app for daily Islamic practice: wird collections, dhikr
collections and Quran surahs, with counters and reminders.

This repository holds the **content pipeline** — the Python that turns source
data into the SQLite database the app bundles — and the Flutter app that reads
it: the data layer, the theme, the reading experience, and the wird player and
its counter. Making and editing your own collections, and streaks, are not
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

Six collections are authored and built in: the **wird of Imam al-Nawawi**; the
**morning** and **evening adhkar**, summarised from the works of Shaykh Abd
al-Aziz al-Tarefe; **al-Wird al-Latif** of Imam al-Haddad, morning and evening;
and **Hizb al-Bahr** of Imam Abu al-Hasan al-Shadhili. Each morning/evening pair
shares one file of dhikr text — most of what is said in the morning is said
again in the evening, and the wordings that differ (`asbahna` against
`amsayna`, and their pairs) sit beside each other rather than being duplicated.

**A dhikr is authored once and reused.** Wirds overlap heavily: the same
istiʿadha, the same `hasbiya Llah`, the same salawat closing half the litanies.
Every one of those is one row with one id that each collection points at, with
a per-item `count` where they disagree on repetitions — dhikr 2011 is recited
by six of the six collections, at one repetition in the morning and evening
adhkar and three everywhere else. Counting the same dhikr as two unrelated
things, and letting two copies of a translation drift apart, is what that
avoids. `verify_content.py` fails the build if a second copy is ever authored;
it compares consonantal skeletons, so a copy that merely spells `Allah`
differently or moves a comma does not slip past.

The collections' Quranic portions are **not** transcribed either: al-Ikhlas,
al-Falaq, al-Nas, the last two verses of al-Baqarah, the passages al-Wird
al-Latif draws from al-Muminun, al-Rum, al-Hashr and al-Saffat, and the passages
Hizb al-Bahr draws from Maryam, Ya Sin, Ta Ha, al-Rahman, Ghafir, al-Buruj and
al-Araf are `surah` and `ayah` items resolved out of the imported mushaf, so
that text exists in exactly one place in the database.

Hizb al-Bahr also quotes three passages only in part — the tail of 2:137, the
tail of 12:64, and 33:11-12 opened on `fa-qadi` in place of the verse's own
`hunalika`. Reciting the whole verse instead would not be the litany, so those
are adhkar rather than `ayah` items; their text is nonetheless **sliced out of
`sources/quran/ayahs.json`** rather than typed, so every Quranic character in
the database still comes from the imported mushaf, and each carries a `notes`
naming the verse it is drawn from. Its fourth partial quotation, the tail of
9:129, is dhikr 3013 — the morning and evening adhkar recite the same words, so
it is that one shared row rather than a fourth slice.

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
| Contents | Quran, adhkar, sources, built-in collections | user collections, commitments, progress, completions, settings |
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
  routes.dart             named routes; a plain Navigator, no routing package
  screens/                the four-tab shell and its tabs, wird player, surah
                          list, reading view, collection editor, settings
  screens/pickers/        surah, ayah and dhikr, each popped with its answer
  player/                 the counter's state and its haptics — no widgets
  collections/            editing and calendar logic, with no widgets in it
  widgets/                the pieces the screens share
  providers/              riverpod: the databases, the repositories, settings
  quran/                  text transformations on the Uthmani text
  theme/                  colour, shape, motion, type
  dev/                    throwaway — deleted before release
```

### The app shell and the home screen

Four destinations — Home, Collections, Dhikr, Tracker — and four is the ceiling.
A fifth would mean the information architecture is wrong rather than that the
bar needs another slot, which is why the mushaf is an app-bar action rather than
a tab.

**Home is what today contains; Collections is what the app contains.** Home
shows only the collections the user has *committed* to and that fall on today,
grouped under Today, Morning and Evening in that fixed order, as square tiles
two to a row. A section with nothing in it is not rendered at all — no header,
no placeholder — because a header over nothing is a promise the screen is not
keeping. Committing happens in the collections list's row menu, which is where a
collection is also copied, edited and deleted.

**A selected segment is brick, not a tonal step.** Depth in this app is tonal
and selection is not: a tonal step against a tonal surface is a difference you
have to hunt for, and on a row of seven days it is one you can get wrong without
noticing — which is exactly what happened, leaving a picker set to the opposite
of what its user meant. Brick already marks the selected tab in the navigation
bar, so the day picker and the theme control say it the same way.
`test/theme/selection_contrast_test.dart` pins it, because the failure it
prevents is one no behavioural test can see.

**A commitment carries the days it comes round on, and they are orthogonal to
the section.** The section says where in the day something sits; the days say
whether it is due at all. Every day is the default and what almost every
commitment is, so the day picker starts full and most people will never open
it — it is there for the Friday reading of al-Kahf, and for the collections
authored around a particular day of the week. A collection that does not fall on
today is not on the screen at all: not a greyed-out tile, not an empty section,
and not counted in the greeting's "one of four finished today". The days are a
seven-bit mask on the commitment row, because a commitment is one row and a set
of at most seven flags is not a relation worth joining.

**A commitment is a row in `user.db`.** `commitments` is keyed by
`collection_ref` like `progress` and `completions` are, so a built-in and a
user collection are committed the same way, and a collection is committed to one
part of the day or to none. Committing it somewhere else is a move, and it keeps
its place in the grid: tiles sit in the order they were committed and nothing
reorders itself as the day goes on.

**A tile counts repetitions, not entries.** A collection of one dhikr said a
hundred times reads `40/100` and its stripe advances as it is said; counted as
entries it would be `0/1` and the stripe would go from empty to full in a single
tap. The stripe is cut into `min(repetitions, 12)` segments and quantised down,
so ninety-six percent of the way through does not look finished. The count is
the fraction at rest too — `0/100`, not "100 items" — because a row of tiles is
read at a glance and a line that changes shape on the first tap cannot be.

**A tile is square, and every tile is the same shape.** It holds four short
things — a name, a line about the run of days, a week of marks and a count —
and at the width two of them take on a phone, those come to almost exactly a
square with two lines left over for the name. A name too long for that is
clipped rather than growing the card; nothing a name does can push the strip or
the count off the bottom of it.

Two things were tried on the card and taken off again. **The wird's opening
words** in Naskh under the name, which cost no query and made every tile
visibly different, read as a second name rather than as an opening and were
more confusing than blank space. **A voussoir arch watermark** behind the card,
in `outlineVariant` at 45% — drawn as straight-edged blocks so the app's shape
language survived it — was ornament that carried nothing, and looked it. The
card lost its height when the opening text went: a card with air in it is a
card with nothing in it, whatever is drawn behind the air.

**Seven marks say what the last week held, in brick and stone.** One per day, oldest first and today
last, filled in `primary` where this collection was completed and in `outline`
where it was not — the same squared 4dp plate the tracker's calendar uses, at
12dp. Brick and stone alternating across a row is the Mezquita's own pattern and
the reason the stripe looks the way it does; here the days decide where the
joints fall rather than a constant deciding it. It is this collection's own history, where
the streak on the greeting spans everything. Today is not marked out from the
six behind it: a calendar of thirty-one cells has to say where you are, a row of
seven says it by ending, and pointing at today's empty square is the app leaning
on somebody about a day they are still in. It costs one indexed query per tile
against `idx_completions_ref_date`.

**One line above the count speaks to the run of days, and it is the only place
in the app that does.** "A good day to begin.", "3 days. Keep going.", "2 days
and counting." — this collection's own run, encouraged rather than reported.
That is a deliberate reversal of the position the rest of the app takes, and
`StreakPanel` still takes: see the Streaks section, which argues that streak
pressure aimed at somebody's devotional life is not defensible. The reversal
was made knowingly, after the argument was put, and it keeps the two halves of
that argument that survive it. Nothing escalates — the line reads the same at
three hundred days as at three, so there is no tier to reach and none to fall
out of. And nothing is negative: a broken run is an invitation to start, never
a warning, a countdown, or a remark about the days that were missed. A test on
the home screen fails any text that leans.

**Finished, a tile fills its stripe and quiets everything else.** The
background steps one tonally to `surfaceContainerHigh`, the name goes to
`onSurfaceVariant`, the meta line becomes a check and "Done today", and the
line above the count stops saying "Done today" because the line below it
already does. The stripe goes solid brick — set from the completion and not
from the counts, since finishing clears the progress row.

That full band went back and forth. It was there, then it came off on the
argument that a finished wird is the expected outcome and should not be the
loudest thing on the screen, and it is back: a card that marks nothing at the
end of a wird ends on a shrug. What keeps it from being a celebration is that
the mark is the app's own material rather than a new one — the same stripe,
filled — so what changes at the end of a wird is how much of it is lit and
never what it is. No badge, no confetti, no strike-through, and the week's
marks stay brick too, because history does not change because today is over.

**The bar is built from `Row` and `InkWell`, not `NavigationBar`.** Material 3
marks the selected destination with a stadium-shaped pill behind its icon, and
this app drops the stadium everywhere. The selected tab is marked by a 4dp
length of brick across its top edge instead — the one place brick acts as a
plain bar rather than as the voussoir rhythm — plus `onSurface` ink and Inter
Medium. Icons stay chrome, never brick and never gold, and nothing swaps between
filled and outline to signal selection. No tab carries a badge, dot or count,
because the app has no notifications. That rule holds with the update notice
too: it is a card in the Home list, never a mark on a tab, and it exists only
for somebody who turned the update check on — see Updating.

**Each tab keeps its own scroll position.** The four bodies live in an
`IndexedStack`, and each gets its own `ScrollController` — a vertical `ListView`
with no controller attaches to the nearest `PrimaryScrollController`, so
otherwise all four would share the Scaffold's one and read each other's offsets.
Switching tabs swaps the body and its app bar instantly: no cross-fade, no
slide.

**Progress belongs to the day it was made on.** `UserRepository.progress`
returns null for a row it did not write today, so a wird left half done last
night is not half done this morning — it has not been started. That rule lives
in one place, which is what keeps a tile, the collections list and the player
from disagreeing about where the day begins.

The Dhikr tab is deliberately empty. Nothing in either database describes a
standalone single-dhikr counter yet — `content.db` has adhkar and it has
collections, and a dhikr on its own is neither — so the tab says so rather than
being filled by listing every dhikr in the database, which would be a product
decision made by whoever was nearest the keyboard.

### The wird player

The counter, and the screen the app is for. It opens from a tile on Home, or
from a row in the collections list.

**Its state is a plain object.** `lib/player/wird_player.dart` is a
`ChangeNotifier` and knows nothing about widgets, so counting, undo across a
step boundary, resume, skipping and completion are all tested by calling
methods rather than by pumping frames. The screen is a `ListenableBuilder` over
it, and a tap goes from the gesture straight to the object holding the count.

**Playback runs on `steps`, never `entries`.** A repeat block arrives already
flattened, with `repetition` and `repetitionsTotal` on each step, so the player
never has to know what a block is. Position is `stepIndex`, `currentCount` and
`unitIndex`, which is exactly what the `progress` row stores.

**A step is a sequence of units, repeated a number of times.** A tap consumes
one unit. For a dhikr or a single ayah a unit is the whole item — `unitCount` is
1 and a tap is a repetition, as it always was. For a surah a unit is one ayah,
so Al-Ikhlas x3 is four ayahs over three rounds: twelve taps, with the verses
shown one at a time. The kind of a step decides only what a unit is; it never
decides how you advance. A surah still flattens to **one** `PlaybackStep`
however many ayahs it has — the cursor is inside a step, not a new step, because
`steps.length` is what the stripe is cut by and what "3 of 12" counts, and
Al-Baqarah would otherwise turn a twelve-step wird into a three-hundred-step
one.

**Nothing animates.** Not the count, not the stripe, not the band. At
thirty-three repetitions a counter that eases into position is a counter running behind the
thumb, and the lag is the whole experience. Feedback is haptic instead: a
`selectionClick` on each tap, throttled to one per 60ms and **dropped** rather
than queued, because some Android devices buffer rapid vibration calls and play
them back late — which is the same lag arriving through the other sense. The
end of a step is a heavier impact, which always fires, and the tap that
finishes a step advances on its own rather than asking for another one.

**The stripe is the wird.** `VoussoirStripe.progress` is cut into
`min(stepCount, 33)` segments — one per step where a collection is short
enough, proportionally past that — and it fills with steps finished plus how
far into the current one, so a dhikr said a hundred times moves it as it is
counted rather than leaving it parked. The step's own indicator is the count
below it. One stripe measuring two things measures neither, and the thing worth
measuring across the top of the screen is how much of the wird is left.

**Every step is tap-to-count over the whole content area**, margins and empty
space included, because at speed the thumb lands wherever it lands. One
mechanic, whatever the step is: a surah is not a reading with a Done button any
more, it is a step whose unit is an ayah, and the tap that consumes its last
ayah completes the round exactly as the tap that reaches a dhikr's count
completes it. Undo, the skips and start over all live outside that area,
because the area is one large increment button.

**The band names the gesture.** An area that responds to a tap without ever
inviting one is a rule the reader has to be told about, and the 88dp band above
the controls is where they find it out: the remaining count in brick at 40, the
word `left`, and one line saying `Tap anywhere above to count` — or `to go to
the next ayah` where the step has ayahs to walk. It is `surfaceContainerHigh`
over a hairline, squared and flush to both edges, and it does not move, animate
or comment as the count runs down. The count it shows is **repetitions**: "3
left" of a surah is three readings of it, never twelve ayahs. The step header
above carries the other half — the name, the kind, the `x3` plate, and one
position line, smaller unit first: `Ayah 2 of 4 · round 4 of 7`.

**Resume is silent.** On open the stored position goes through
`ResolvedCollection.resumableFrom`; a position that survives is resumed without
asking, and one that does not is deleted. There is no resume-or-restart dialog:
this is a daily habit, and a question in front of it every morning is a tax on
the habit. Start over is in the app bar's overflow for the days it is wanted.

**Writes are coalesced.** A count change starts a 500ms timer if one is not
already running — a rate limiter rather than a trailing debounce, so a long
tasbih is written through every half second instead of writing nothing until
the user stops. A step change is written immediately, and so is going to the
background. Every write goes through one ordered chain, which is what keeps a
count queued half a second ago from landing after the completion cleared the
row.

**Finishing** logs the completion, clears the progress row, holds the solid
stripe for about half a second, and returns to the list. That hold is the one
deliberate beat in the app — no confetti, no sound — and with reduce-motion on
it is skipped.

### The reading view

Verse by verse, the whole surah loaded at once — Al-Baqarah is 286 rows, which
is not worth a paging system — with `ListView.builder` virtualising the widgets,
which is the part that costs anything.

**Ayah numbers.** QUL bakes each verse's number onto the end of its text as bare
Arabic-Indic digits. The app strips that and renders U+06DD, the end-of-ayah
ornament, with the number inside it. Both bundled faces enclose the digits
correctly up to three of them, which is measured rather than assumed —
`test/quran/ayah_marker_test.dart` fails if a font update breaks it.

**The bismillah** follows the database, not a rule:

| | Where the basmala is | What renders |
|---|---|---|
| Al-Fatiha | ayah 1 | a numbered verse, no heading |
| At-Tawbah | nowhere; `has_bismillah` is 0 | nothing |
| the other 112 | not in `ayahs` at all | a heading, text taken from 1:1 |

**Reading position** is stored as an ayah number, never a scroll offset: text
size is user-adjustable, so an offset points at a different verse the moment the
slider moves. It is written debounced while scrolling and flushed when the surah
closes.

### Making and editing a collection

Everything here is composition over the phase 2 `CollectionRepository`. Nothing
in the data layer changed, with one exception noted at the end.

**Two ways to make one.** From scratch — a name, an optional description, and an
empty collection to fill. Or by copying an existing one, which is the path this
is actually built around: somebody wants al-Haddad's wird with two more adhkar
in it, or the morning adhkar at different counts. `duplicateCollection` walks
the source's entries, appends each item with its count override and note, then
puts the repeat blocks back over the runs they occupied.

`addItem` does not return the id of the row it wrote and `setRepeatGroup` is
addressed by item id, so the copy is resolved once after the items are in and
the groups are formed against the ids that come back in position order.

A resolved item's `count` has the fallbacks already applied — a dhikr's
`default_count`, or 1 — so copying it back verbatim would write an override onto
every row and freeze today's defaults into the copy. `countOverrideOf` writes
one only where the source's count differs from its natural one.

**Three pickers**, behind one add action. A whole surah, through the same
`SurahRow` the mushaf list uses. One ayah or a contiguous range, added one item
per ayah through `ContentRepository.ayahRange` so an over-long range comes back
clamped rather than adding items that resolve to nothing. And a dhikr, browsed
by the built-in collection it comes from — there is no tagging and no search in
this content build, so the collections are the only structure a flat list of
several hundred adhkar could be sorted by.

**The reorder list is of entries, not items.** A `RepeatBlock` is one draggable
row and one contiguous run of ids. That is what keeps a group whole:
`CollectionRepository.reorder` validates that it was handed a full permutation
and *nothing else*, so a list that could drag an item out of the middle of a
block would be a list that could quietly split one — and a split group does not
fail on read, it comes back from the resolver as two blocks sharing a number.
`checkRepeatGroupsIntact` is the guard that stands there, and it runs before the
write.

**Refusals are sentences.** `setRepeatGroup` guards its invariants with
`ArgumentError`, which is right for a programming error and wrong to put in
front of somebody who has just dragged a row. `repeatGroupRefusal` asks the same
questions first and answers in the app's voice; the repository's own checks stay
where they are, as the backstop.

**Removing an item renumbers the rest.** Not tidiness: `setRepeatGroup` refuses
a run that is not contiguous *by position*, and `removeItem` leaves a gap, so a
collection carrying one has items that look adjacent in the list and cannot be
grouped.

**Missing from the repository.** There is no way to change an item's
`count_override` or note after it has been added — no `updateItem`, and no
drift query behind one. So a count is set when the item is added, and changing
it means removing the item and adding it again. Doing that in the UI would mean
`removeItem` + `addItem` + `reorder`, which loses the item's repeat-group
membership and its id silently, so it is not done. Phase 7 wants
`CollectionRepository.updateItem(id, itemId, {count, note})`.

### Streaks

A count of consecutive days, and a calendar of the current month with completed
days marked in `primary`.

Deliberately nothing else. The standard streak component is engineered to be
lost — a flame that grows, a tier that unlocks, a warning at the end of a day —
because loss aversion is what makes the number keep somebody opening the app.
That is defensible for a language learner. It is not defensible applied to
somebody's relationship with their own devotional practice.

So: the count is set in the same type as a collection's name and does not change
appearance as it grows; a completed day is the same mark on day 2 as on day 200;
a zero reads "No days in a row" and stops there; there is no notification of any
kind. `test/app/streak_panel_test.dart` asserts that a 365-day streak renders
identically to a 7-day one, and that no text on the panel matches the loss
vocabulary.

The calendar borrows no days from the months either side — a grid showing 31
January in the same colour as 1 February invites the reader to count across a
boundary it is not showing — so the corner cells are blank.

The whole panel comes off in Settings, defaulting on. It lives on the Tracker
tab; the greeting's third line says the same thing about the app-wide run, in
12dp quiet ink, and reads the same at 365 days as at 2.

**Home's cards are the exception, and they are an exception on purpose.** Each
one carries a line about that collection's own run which encourages rather than
reports — "3 days. Keep going." That contradicts the argument above, and it was
made anyway, knowingly: the case was put and the call was to encourage on the
card. What the argument still buys is the shape of the sentence. Nothing on a
card escalates, so there is no tier to reach and none to fall out of, and
nothing on a card is negative, so a broken run reads as an invitation to begin
rather than as a loss to be warned about. If the position is ever restored,
`_Encouragement` in `collection_tile.dart` is the whole of what has to go.

### Measuring it

```bash
flutter test test/render_samples.dart        # -> build/render/*.png, every screen
flutter test test/measure_reading_scroll.dart # text layout and fling frame times
```

Neither is run by `flutter test` — that only picks up `*_test.dart`. The first
exists for the class of problem that is obvious in a picture and invisible in a
widget test; it has already caught right-to-left text laid out in the wrong
place, a missing glyph, and a ListTile title painted white on limestone. The
second exists because "it feels smooth" is not a measurement.

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

`tertiary` is gold, and is currently claimed by nothing. It was reserved for
Quran text, which is now set in `onSurface` cedar ink. Nothing in
`lib/theme/wirdi_theme.dart` maps it onto a component, so gold appearing
anywhere in the UI still means a widget reached for the wrong role — that is the
signal, and it is deliberate that Material components rarely pick `tertiary` on
their own.

### Type

Arabic and Latin have two parallel definitions in `lib/theme/typography.dart`;
a single `TextTheme` cannot express both. Three families are bundled as local
assets and none are fetched at runtime — the app works with the radio off, and
Quran text rendered in a substituted font is not the same text.

| | Face | Nominal | Line height |
|---|---|---:|---:|
| Quran verse | Noto Naskh Arabic | 24 | 2.0 |
| Dhikr | Noto Naskh Arabic | 20 | 2.0 |
| Translation | Inter | 15 | 1.6 |
| Dhikr caption | Inter | 13 | 1.5 |
| Section header | Inter | 17 | 1.4 |
| Nav and labels | Inter | 14 | 1.4 |
| Caption and meta | Inter | 12 | 1.4 |

Every size there is *nominal*. Arabic faces render at nominal x
`ArabicFace.opticalMultiplier`, because a font's letterforms fill as much of its
em as its designer decided they should, and an Arabic face reserving room for
vocalisation fills much less of it than Inter does. The factor is per face, and
it is derived rather than guessed; see the comment on `ArabicFace`.

Quran and dhikr are set in the same face and separated by size alone. Amiri
Quran is still bundled, for the dev screen's comparison, but nothing the app
ships is set in it: it has no glyph for U+065E, which the Uthmani text uses
1,807 times across a fifth of the mushaf.

`tool/check_font_coverage.py` is what keeps that kind of gap from going
unnoticed. It reads every Arabic and Latin string out of the built database and
checks each codepoint against the cmap of the face that renders it, failing the
build on a gap that is not recorded as a decision. A missing glyph does not
raise anything by itself — it draws an empty box, or on a device quietly borrows
the glyph from some other face mid-word, which looks almost right.

```bash
python3 tool/check_font_coverage.py
```

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

`test/render_samples.dart` renders that screen to PNGs under `build/render/`
with the real fonts loaded. It is not run by `flutter test` — that only picks
up `*_test.dart` — and it is not a substitute for looking at a phone. It is for
the class of problem that is obvious in a picture and invisible in a widget
test:

```bash
flutter test test/render_samples.dart
```

## Versioning and releases

The version lives in `pubspec.yaml`, which is where Flutter reads it from for
both platforms: the Android `versionName` and the iOS
`CFBundleShortVersionString` are both wired to it through the generated build
config, so there is no third place to keep in step. `lib/app_version.dart` holds
a copy for the About sheet to display, and `test/app_version_test.dart` fails if
the copy ever drifts from the pubspec.

Bump both together:

```bash
tool/bump_version.sh 0.2.0
```

Pushing that to `main` is what cuts a release. `.github/workflows/release.yml`
notices the version changed, runs the test suite — by calling `ci.yml`, the same
workflow that runs on every pull request, rather than a copy of its steps that
would drift from it — and only then builds the Android APK and the iOS app,
publishes a release and tags it `v0.2.0`. The tag is created at the end, at the
tested commit, which is what stops a tag ever naming a commit whose tests did
not pass. A push that does not change the version builds nothing.

The build numbers behind those versions — the Android `versionCode`, the iOS
`CFBundleVersion` — come from the CI run number rather than from `pubspec.yaml`.
Stores reject a build number they have seen before, and a number that only ever
goes up is one less thing to remember at bump time.

The APK is signed with the Android debug keys until a release keystore is
configured through repository secrets, and the iOS build is unsigned, because
signing it needs an Apple Developer certificate this repository does not hold.
Both facts are stated on the release itself rather than left to be discovered.
[`docs/RELEASING.md`](docs/RELEASING.md) has the details and the setup.

## Updating

The app can notice that a newer version has been released and install it.
Turned on, it asks GitHub once a launch what the latest release is; if that is
newer than the running build, a notice appears at the top of Home, and tapping
it downloads that release's APK and hands it to Android's installer. It exists
so a phone can be updated from the phone rather than from a cable.

**Off by default, and the only thing in the app that opens a socket.** Left
alone Wirdi makes no network calls at all — the fonts and the content are
bundled, and nothing is fetched. The switch is in Settings, the About sheet says
what it does, and `test/app/update_banner_test.dart` asserts that with it off
the update client is never called even once. A claim printed under a switch is
worth a test.

**Android only.** iOS does not let an app install itself, so the notice and the
switch are not there rather than being there and inert.

Two things are worth knowing before the first use. Android refuses to upgrade an
app whose signing key changed, so a phone holding a debug-signed build — which
is what `flutter run` installs — needs one manual uninstall and reinstall before
self-updating works, and uninstalling takes `user.db` with it. And the
`REQUEST_INSTALL_PACKAGES` permission this needs must come out before the app is
submitted to Play.

CI compiles the Android app on every pull request — `flutter build apk --debug`
in a job beside the tests. `analysis_options.yaml` excludes `android/**` and
`dart format` covers only `lib test tool`, so without that job the Kotlin, the
manifest and the `FileProvider` would have nothing checking them until a release
was being cut. The release workflow skips it, having a real APK to build.

[`docs/SELF_UPDATE.md`](docs/SELF_UPDATE.md) covers both, how the pieces fit,
the on-device checks that no test can make, and the checklist for removing the
feature.
