# Wirdi
Daily islamic habits. Reminders. Counters. Dhikr etc based on famous litanies

## What this is

Wirdi is a Flutter app for daily Islamic practice: wird collections, dhikr
collections and Quran surahs, with counters and reminders.

This repository holds the **content pipeline** — the Python that turns source
data into the SQLite database the app bundles — and the Flutter app that reads
it: the data layer, the theme, the reading experience, the wird player and its
counter, making and editing your own collections and your own adhkar, and the
tracker the streaks are shown on.

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

The collections authored and built in are the **wird of Imam al-Nawawi**; the
**morning** and **evening adhkar**, summarised from the works of Shaykh Abd
al-Aziz al-Tarefe; **al-Wird al-Latif** of Imam al-Haddad, morning and evening;
**Hizb al-Bahr** of Imam Abu al-Hasan al-Shadhili; **Dala'il al-Khayrat** of
Imam Muhammad al-Jazuli, a part for each day of the week and its closing
supplication; the **Wazifa ash-Shadhiliyya**, built around the Salat
al-Mashishiyya of Sayyidi Abd al-Salam ibn Mashish; **Wird as-Sakran** of Imam
Abu Bakr al-Sakran al-Saqqaf; **Hizb al-Nasr**, the Litany of Victory — two
different litanies of that name, one by Imam al-Haddad and one by Imam
al-Shadhili, which is why those two carry their author in the name; **Dua
al-Nasiri**, the Prayer of the Oppressed, of Imam Muhammad ibn Nasir al-Dar'i;
and the two daily **Ratibs**, of Imam al-Haddad and of Habib Umar al-Attas.
That list is deliberately not counted here: another one is two more files in
`content/sources/` — one of adhkar, one of collection items — so
`sources/collections/` is the listing that stays true.
Each morning/evening pair shares one file of dhikr text — most of what is said
in the morning is said again in the evening, and the wordings that differ
(`asbahna` against `amsayna`, and their pairs) sit beside each other rather than
being duplicated.

**A dhikr is authored once and reused.** Wirds overlap heavily: the same
istiʿadha, the same `hasbiya Llah`, the same salawat closing half the litanies.
Every one of those is one row with one id that each collection points at, with
a per-item `count` where they disagree on repetitions — dhikr 2011 turns up in
collection after collection, said once in the morning and evening adhkar and
three times everywhere else. Counting the same dhikr as two unrelated things,
and letting two copies of a translation drift apart, is what that avoids.
`verify_content.py` fails the build if a second copy is ever authored; it
compares consonantal skeletons, so a copy that merely spells `Allah` differently
or moves a comma does not slip past.

The collections' Quranic portions are **not** transcribed either: al-Fatiha,
al-Ikhlas, al-Falaq, al-Nas, Ayat al-Kursi, the last two verses of al-Baqarah,
the passages al-Wird al-Latif draws from al-Muminun, al-Rum, al-Hashr and
al-Saffat, and the passages Hizb al-Bahr draws from Maryam, Ya Sin, Ta Ha,
al-Rahman, Ghafir, al-Buruj and al-Araf are `surah` and `ayah` items resolved
out of the imported mushaf, so that text exists in exactly one place in the
database.

Some litanies quote a verse only **in part** — the tails of 2:137, 12:64, 9:129,
18:10, 3:173, 33:69, 3:45, 21:87, 4:45 and 2:285, the openings of 28:85 and
6:79, the middle of 40:44, 33:11-12 opened on `fa-qadi` in place of the verse's
own `hunalika`, and 61:13-14 opened on `nasrun` and stopped at `nahnu ansaru
Llah`.
Reciting the whole verse instead would not be the litany, so those are adhkar
rather than `ayah` items;
their text is nonetheless **sliced out of `sources/quran/ayahs.json`** by word
index rather than typed, so every Quranic character in the database still comes
from the imported mushaf, and each carries a `notes` naming the verse it is
drawn from. Where two litanies want the same slice they share the one row: the
tail of 9:129 is dhikr 3013, authored for the morning and evening adhkar and
pointed at by both halves of al-Wird al-Latif and by Hizb al-Bahr rather than
sliced a second time.

Words that merely lead into a passage stay adhkar too, for the same reason in
reverse. Wird as-Sakran says `ahata bina min` and then recites al-Fatiha whole;
the lead-in is dhikr 18002 and the Fatiha is a `surah` item, so the recitation
keeps its order without a second copy of the surah.

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
| Contents | Quran, adhkar, sources, built-in collections | user collections, adhkar the user wrote, commitments, progress, completions, settings |
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
    repositories/           the four repository implementations
    database_files.dart     path_provider and the asset copy — the platform seam
  domain/                   hand-written models and the repository interfaces
```

Schemas are `.drift` files rather than Dart table classes: the collection
resolution queries read better as SQL, and keeping the canonical definition in
SQL means `lib/data/schema/content.drift` can be diffed against what the Python
pipeline actually produces. `tool/check_schema_parity.py` is that diff.

Drift's generated row types stop at the repository boundary. `lib/domain/`
imports no drift.

A collection item points at one of two things, and which one is the kind of its
`ItemRef`: a `ContentRef` names a row of `content.db` by the integer id the
build assigned it, and a `UserDhikrRef` names a dhikr the user wrote, which
lives in
`user_adhkar` in `user.db` and so is keyed by a UUID like everything else there.
That is the same split `CollectionId` already makes between a built-in and a
user collection, and for the same reason: one type flows through the UI, and
which kind it is tells a repository which database to ask.

`ContentRef` is a subtype of `ItemRef` rather than something wrapped by one,
which is why adding the second kind was a small change: every picker and dialog
that constructs a `ContentRef` is untouched, and only the code that *switches*
on a ref had to learn there are now two. `progress.step_ref` stores the
canonical form of either, and the three content forms are byte-for-byte what
they were, so no saved progress was invalidated.

Resolution reads `user_adhkar` in `DriftCollectionRepository` and hands the rows
to `CollectionResolver` as a prepared map. The resolver holds `content.db` and
only `content.db`; the repository is the one class that holds both, and that
seam is the whole reason there is no ATTACH anywhere.

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
  player/                 the counters' state and their haptics — no widgets
  collections/            editing and calendar logic, with no widgets in it
  widgets/                the pieces the screens share
  providers/              riverpod: the databases, the repositories, settings
  quran/                  text transformations on the Uthmani text
  theme/                  colour, shape, motion, type
  dev/                    throwaway — deleted before release
```

### The app shell and the home screen

Four destinations — Home, Collections, Tasbih, Tracker — and four is the ceiling.
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
because the app has no notifications.

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

### The tasbih tab

A free counter, and nothing else. One enormous tap target, the running count in
72dp numerals over it, and undo and reset in a bar underneath — no dhikr behind
the number, no target in front of it, and no history kept of what it reached.

**It counts until somebody resets it.** Not until the end of a step, not until
midnight, and not until the app is closed: `TasbihCounter` persists the number
under `tasbih.count` in `user.db`'s settings table, so a tab switch and a cold
start both come back to the count that was left. Writes are rate-limited to one
every half second while counting — the player's rule, for the player's reason —
and a reset is written immediately, because it is the change that would be worst
to lose.

**It is deliberately not the wird player.** The player counts *something*, a
step at a time, and finishes; this counts taps, and does not. What it borrows is
the shape — `lib/player/tasbih_counter.dart` is a `ChangeNotifier` with no
widget in it, and the screen is a `ListenableBuilder` over it — and the two
rules the counting path lives by: nothing animates, and feedback is the haptic,
through the same `PlayerHaptics` and the same settings switch.

**Reset asks first.** It sits a thumb's width from a target being tapped at
speed, and what it throws away is however long somebody has been counting. Undo
does not ask: it takes back one tap, which is what a mis-tap costs.

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

**Nothing on the counting path animates.** Not the count, not the stripe, not
the band. At
thirty-three repetitions a counter that eases into position is a counter running behind the
thumb, and the lag is the whole experience. The end of a wird is the one thing
here that is not on that path — see **finishing** below. Feedback is haptic instead: a
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

**Finishing** logs the completion, clears the progress row, and lands on a
**finished step**. It is a step like the others and that is the whole of its
design: the same header, the same content area as the tap target, the same band
naming the gesture, the same controls underneath. What changes is what each of
them says. The header reads `Wird complete` over `12 steps · 87 repetitions`,
the band swaps the numeral for a check and reads `done` / `Tap anywhere above
to close`, and the content area carries three lines, centred and in the largest
type the app sets outside the mushaf: `الْحَمْدُ لِلَّهِ`, then `Consistency is
the key. May it be accepted, Ameen.`, then this collection's run of days in the
home tile's own words (`A day begun.`, `4 days and counting.`). Centred and
large because there is nothing to read here — every other step is a column of
text with a number beside it, and this one is the words and nothing else. There
is no button, because no other step has one and the end of a wird is a poor
place to teach a new gesture.

What keeps that from being a celebration is the same argument the home tile
makes: nothing escalates — the first two lines read the same at three hundred
days as at three — nothing is negative, and the mark itself is the app's own material, the
stripe above gone solid because the wird filled it. No confetti, no sound, and
nothing that is not the app's own material moving.

**The finished step arrives, and it leaves by coming apart.** The two pieces of
motion in the app, both of them here, and both spent out of the same
`WirdiMotion.completion` beat the screen already held still for:

*Arriving* is three fades, opacity and nothing else. `الحمد لله` with `Wird
complete` over it, then the sentence under it half a beat later, then the tally
and the run of days half a beat after that — each one a beat long, so the whole
reveal is two (`WirdiMotion.completionReveal`). Nothing slides, nothing scales
and nothing is mounted late: every line holds its place in the layout from the
first frame, so the screen is composed the moment it is reached and only the ink
arrives.

*Leaving* takes the screen apart. On the closing tap the whole route — app bar,
stripe, step, band and controls — comes down in courses of 48 by 16 laid in a
running bond, from the top to the bottom. Each brick turns from whatever the
screen was showing there into a voussoir, brick and stone alternating exactly as
`VoussoirStripe` alternates, with a hairline of ground for mortar, and then
fades out to the bare surface. Every brick lags its course by a little, off a
hash rather than a `Random` so it falls at the same moment on every frame the
painter runs, which makes the front ragged rather than a wipe. It is painted
over the route rather than clipped out of it — a clip needs a path of every
brick still standing on every frame, this needs two rectangles per brick and
only for the ones in flight — and the route pops on the last brick, not on the
tap. `flutter test test/render_samples.dart` shoots both of them frame by frame,
as `05c-reveal-*.png` and `05d-dismantle-*.png`.

Neither reaches the counting path. At rest the dismantle painter does not exist
and the reveal sits at zero, and a reciter who has turned animations off in the
OS — or a theme whose completion beat is zero — gets the finished step whole on
the frame it is reached, and an immediate close.

The run of days is read back **after** the completion is written, on the same
ordered chain, so the number includes the wird just finished; until that read
lands the line is simply absent rather than guessed at. The screen no longer
leaves on its own — it waits for the tap, and goes back to whichever of Home or
the collections list opened it. The beat the screen used to hold still for is
now the reveal, and it is still a guard: the finished step takes no tap until
all three lines have landed, because a tasbih is counted faster than a screen
changes and the tap after the last one is already on its way down.

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

**Opening a collection shows what is in it.** `CollectionContentsScreen` lists
its entries in recitation order, with its description and its author above them
and each repeat block drawn as the group it is. Tapping a row opens that item in
full — the Arabic, the transliteration, the translation, the collection's own
note on it, and the reference it cites — in a sheet, capped at most of the
screen's height and scrolled inside that cap.

The row's button used to open the player instead, which meant the only way to
find out what a wird contained was to start reciting it, and backing out of one
leaves a progress row behind. Looking and reciting are two buttons now, and the
player kept its own.

A `SurahItem` resolves to surah metadata only — Al-Baqarah alone is 286 verses
and a list has no use for the text — so the sheet is where that expansion
finally happens, through `surahReadingProvider`. It builds them lazily and sits
inside a bounded height, which are two halves of one requirement: a column of
286 `AyahBlock`s would lay every one of them out before the sheet appeared, and
an unbounded list inside a sheet has no height to build against at all.

The translation is always shown in that sheet, whatever the show-translation
setting says. That setting is about the surface you recite from — somebody
reciting from memory wants the page uninterrupted — and this sheet exists to
work out *which item this is*. Hiding half the answer would defeat the screen.

**Two ways to make one.** From scratch — a name, an optional description, and an
empty collection to fill. Or by copying an existing one, which is the path this
is actually built around: somebody wants al-Haddad's wird with two more adhkar
in it, or the morning adhkar at different counts. `duplicateCollection` walks
the source's entries, appends each item with its count override and note, then
puts the repeat blocks back over the runs they occupied.

**The description is shown, and it can be changed.** It was write-only for two
phases: the form asked for one when a collection was made, the column carried
it in both databases, and no widget ever read it back. It is now a line on the
collections row — capped at two lines, so a long one cannot push the row's
actual state off the bottom at a large text scale — and the whole thing,
unclipped, above the contents screen's list. Names say what a collection is,
the description says what it is for, and the meta line says what state it is in
today, which is the order they sit in.

It is deliberately absent from the row's screen-reader label. A blurb read out
on each of fourteen rows turns a scan down the list into a recital; the
contents screen reads it in full, which is where somebody who wanted it went.

`rename` became `CollectionRepository.updateDetails`, one statement writing both
columns. The form asks both questions at once, and a rename that lands while the
description it was written alongside does not is worse than a refusal. Emptying
the field clears it, which is the only way there is to take one off.

**Four buttons made the row change shape.** The names, the description and the
meta line each take the row's full width now, and the buttons share the bottom
line with the meta rather than standing to the right of the lot. At three
buttons standing beside it was fine; at four, a hundred and sixty points of
button took enough off a four-hundred-point row to wrap "Wird of Imam al-Nawawi"
onto three lines. The meta line is short and the space to its right was empty.
The row is no taller for the move, and the names stop paying for the actions.

`addItem` does not return the id of the row it wrote and `setRepeatGroup` is
addressed by item id, so the copy is resolved once after the items are in and
the groups are formed against the ids that come back in position order.

A resolved item's `count` has the fallbacks already applied — a dhikr's
`default_count`, or 1 — so copying it back verbatim would write an override onto
every row and freeze today's defaults into the copy. `countOverrideOf` writes
one only where the source's count differs from its natural one.

**Four pickers**, behind one add action. A whole surah, through the same
`SurahRow` the mushaf list uses. One ayah or a contiguous range, added one item
per ayah through `ContentRepository.ayahRange` so an over-long range comes back
clamped rather than adding items that resolve to nothing. And two ways to a
dhikr, because there are two ways of knowing which one you want.

**The flat list searches; the other one browses.** "Dhikr" is every dhikr in the
content build — 825 rows — with a search field over it. That list used to be
the thing this section argued against: without tagging it had nothing to sort or
filter it by, and several hundred rows of Arabic in a row is unusable in a way
no amount of styling fixes. The search field is the thing it was missing, and
the argument does not survive it.

"From collection" is the old picker, kept rather than replaced, because the two
answer different questions. A search wants a word you can remember; somebody
reaching for the morning tasbih often cannot remember one, and what they know
instead is which wird it came out of.

Matching is diacritic-insensitive on the Arabic side. Nobody types the harakat
and the text carries all of them, so a search that required them would find
nothing every time and look broken rather than strict. `ArabicText.simplify` is
`simplify_arabic` from `content/scripts/import_quran.py` written out in Dart —
the same function that builds `ayahs.text_simple`, which `adhkar` has no
equivalent of and cannot be given one, since `tool/check_schema_parity.py`
requires `content.drift` to mirror the build script's tables verbatim. The two
are a matched pair: a search that folds differently from the column it will one
day be matched against is a search that disagrees with itself. They are checked
against each other in `real_content_db_test.dart`, which folds every ayah of the
real build in Dart and expects the string the Python already wrote.

The query is matched against both forms with no script detection, which is not
an omission: the Arabic fold leaves Latin alone and `toLowerCase` leaves Arabic
alone, so an Arabic query cannot reach a translation and an English one cannot
reach the Arabic. Two cheap comparisons beat guessing which script somebody is
typing in — a guess that fails on the first transliterated word. Nothing is
debounced, because there is nothing to coalesce: the rows are folded once when
the picker opens and the filter is a `contains` over strings already in memory.

**Rows in a picker sit on alternating courses of stone and clay.** The even
rows are `surface`; the odd ones are that same surface with a wash of brick
blended into it — eight percent in light, four in dark. Two lines of Arabic and
two of translation, four hundred times over, have no natural boundary between
one row and the next, and that is the whole problem it solves.

That went the other way first, and the reversal is the interesting part. The
band was a rung of the neutral ladder, `surfaceContainerLow`, on the argument
that brick is how this app draws *data* and should not be spent on saying "these
are different rows". It was a good argument made without looking at it: the
light rung is fourteen points out of two hundred and fifty-five, and on a device
the list still ran together. Dark, where the same rung reads fine, is tuned to
keep exactly the weight it had and only pick up the warmth.

What the argument got right still holds, and is the line the code has to keep
drawing. The week strip and the progress stripe use brick at **full** strength,
and in both of them something decides where the joints fall — the days in one,
the count in the other. This is a wash, decided by nothing but whether a row is
odd, sitting behind text rather than standing for anything. Brick and stone
alternating is the Mezquita's own pattern; at eight percent it is the rhythm of
it and not a second progress bar.

The arch watermark above is still the thing to measure it against: what killed
that was carrying nothing *and looking like it*. A ground a shade off the page
does not have that problem — the moment it does, it is too loud, and
`WirdiColorSchemes.lightBandTint` is the dial. The colour is derived from the
palette rather than written down, so it follows if brick or limestone ever move,
and it lives in `color_schemes.dart` because that file is the only place in
`lib/` that decides a colour at all.

`BandedRow` takes the row's index, so banding is a decision the *list* makes.
`SurahRow` is shared between the surah picker and the mushaf's reading list, and
only the picker gets it: a picker is a list you are scanning for one row out of
a hundred and fourteen, where the mushaf list is a table of contents you already
know your way down, and a banded ground under Quran headings is the ornament
again. A test asserts that asymmetry rather than leaving it to be tidied away.

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

**Missing from the repository.** There is still no way to change an item's
`count_override` or note after it has been added — no `updateItem`, and no
drift query behind one. So a count is set when the item is added, and changing
it means removing the item and adding it again. Doing that in the UI would mean
`removeItem` + `addItem` + `reorder`, which loses the item's repeat-group
membership and its id silently, so it is not done. Phase 7 wants
`CollectionRepository.updateItem(id, itemId, {count, note})`.

### Writing your own adhkar

**The app ships with adhkar; it does not have all of them.** Somebody's
grandfather's dua, the wording their teacher gave them, the thing they say after
Fajr — none of that is in `content.db` and none of it can be, because that
database is replaced wholesale on every app update. So a dhikr somebody writes
lives in `user.db`, in `user_adhkar`, beside the collections that name it.

**One `Dhikr` covers both**, the way one `CollectionSummary` covers a built-in
collection and a user-made one. What differs is which database the row came out
of — its `ItemRef` says — and which fields are filled: `sourceId` and `benefits`
are the content build's, `reference` is the user's. So a dhikr somebody wrote is
recited, listed and read by exactly the code that draws one that shipped: the
player maps a step to its entry by id and has no idea which kind it is holding.

`translation` became nullable for this, and every widget that drew that line
leaves it out rather than standing it empty. `adhkar.translation` in
`content.db` is still NOT NULL and stays that way — the pipeline can insist,
because it is authoring. Somebody writing down the dua they say knows what it
means,
and refusing to save it until they have typed a translation is asking them to do
the content build's job. A dhikr with no translation is found by its Arabic, and
read out by it too: `DhikrRow`'s screen-reader label falls back to the Arabic,
which leaves a reader with no Arabic voice exactly where a sighted reader is.

**"Your adhkar" hangs off the collections list**, at the bottom, under the
built-ins. Not a fifth tab — four is the ceiling — and not a second icon in the
app bar, whose one collections-only action is already "New collection". A dhikr
is edited and deleted from that screen and nowhere else: a collection *names*
its adhkar without owning them, and offering "delete this dhikr" from inside one
collection would be offering, from there, to change another.

**An edit is shared, and the form says so.** A collection item names a dhikr
rather than holding a copy of it, so fixing a typo fixes it everywhere, and
lowering the count lowers it for every item carrying no override of its own.
That is the point of writing a dhikr down once, and it is also the thing
somebody would be most surprised by, so the form carries the sentence rather
than leaving it to be discovered.

**Deleting one takes it out of the collections that held it**, in one
transaction, renumbering each. The dhikr row is only tombstoned, as a deleted
collection's is; its items are not, because an item is a position in a list and
a tombstoned one would leave a gap — and `setRepeatGroup` refuses a run that is
not contiguous *by position*, so a collection carrying one has items that look
adjacent in the list and cannot be grouped. Progress needs no help: a row parked
on the step that just went is refused by `resumableFrom`, which compares the ref
it was written against.

The confirmation names the collections rather than counting them, up to three of
them: "in Morning and My wird" is a fact somebody can act on, where "in 2
collections" makes them go and find out which.

**The add sheet has a fifth door, and it is where one is written on the spot.**
"Your adhkar" opens the ones you wrote with "Write a dhikr" above them, so one
screen serves both adding the one from last week and writing the one you are
holding now. Written there, it goes straight in at the count just typed into the
form — asking for that count again one screen later would be the app forgetting
what it had been told. Picked from the list instead, it goes through the same
count-and-note question the content pickers ask, because that count was never
stated anywhere.

That asymmetry is not an oversight, and it leans on the gap above: there is no
`updateItem`, so a count not set when an item is added can never be set. The
straight-in path is only defensible because the count was set a screen earlier.

**The searchable dhikr picker still means "the content library"** and does not
list these. Two doors, two meanings — and somebody who wants theirs knows they
are theirs. It is one provider's worth of change if that ever feels wrong in the
hand.

**No search on your own adhkar.** The flat picker has one because it is the
whole content library; this is the handful somebody wrote, and a search field
over six rows is a control standing in front of the six.

**One new column, not a widened one.** `user_collection_items.item_id` is
`INTEGER NOT NULL`; naming a UUID through it would mean rebuilding the table,
and a table rebuild is the one migration step that cannot be made idempotent —
which every step in `user_database.dart`'s ladder has to be, because the upgrade
does not run in a transaction. So `user_item_id TEXT` was added beside it, and a
`'user_dhikr'` row carries `item_id` 0, which is not a valid id in any of the
three content spaces.

**What `tool/check_font_coverage.py` cannot cover.** It checks the text in
`content.db` against the bundled faces, and a dhikr somebody types is not in
there. Noto Naskh Arabic covers Arabic; a Farsi or Urdu letter (پ چ ژ گ) or an
emoji pasted into the field is on the platform's fallback chain, which means it
may draw differently on different devices. Nothing is broken by that and nothing
can be done about it from inside the app — but it is the one place in this
codebase where what is on screen is not something CI has seen.

### The Tracker

The fourth tab, and the screen that answers "how is this going". Four things,
in the order the question is usually asked: how long the run is, which days of
the month it covered, what the last twelve weeks look like as a shape, and
which days of the week are where it slips. A picker at the top switches all
four between the app as a whole and one collection.

**Everything, and one collection.** "Everything" asks whether the habit is
going at all — a day counts if anything was completed on it. It has no due
rule, so it cannot miss: the app was never owed a day. A collection is reckoned
against the days it actually comes round on, and that distinction is the reason
the tab was rewritten. `currentStreakFor` counts consecutive *calendar* days,
so a wird committed to Fridays could never show a run longer than one — not
because the reader kept breaking it, but because the question was wrong.
`lib/domain/tracker_stats.dart` counts in **due days** instead: Saturday is not
a miss for a Friday wird, it is not an anything. `DueDays` holds that rule in
one object and the run, the weeks and the weekday tallies are all built on it,
because three functions each deciding due-ness for themselves is three chances
for them to disagree.

The home tile counts the same way, so that a card and a tab cannot say
different things about the same wird on the same afternoon — it reads "3
Fridays. Keep going." where it used to read "Day one."

**It encourages, and it does not gamify.** The position this section used to
take was that the standard streak component is engineered to be lost — a flame
that grows, a tier that unlocks, a warning at the end of a day — because loss
aversion is what keeps somebody opening a language app, and that is not a thing
to point at somebody's relationship with their own devotional practice. That
argument stands. What it was overreaching to forbid was *warmth*: habit-building
is what the reader opened the tab for, and reporting at them in a flat voice is
not more respectful, only colder.

So the tab may say "You have practised on 5 of the last seven days", and says
"A good day to begin again" where a run has ended. What it may not do is
escalate, rank, warn, or mark a failure. Concretely, and pinned by
`test/app/tracker_voice_test.dart`:

- no tier, badge, best or record — nothing to reach, so nothing to fall out of
- the count is set in the same type as a collection's name and does not change
  appearance as it grows; a 365-day history renders exactly like a week's
- no loss vocabulary, no countdown, nothing "at risk"
- nothing red, and no icon anywhere on the tab — the month arrows are chevrons
  set in type, because an icon here is one step from a flame here
- still no notifications, of any kind, anywhere in the app

**A missed due day gets no mark.** There are two marks on the calendar and only
two: a filled square for a day completed, and a hairline outline for today. A
day that was due and not done looks exactly like a day that never came round.
Which days were owed is genuinely useful in the *numbers* — the run, the weekly
denominator, the weekday rate — and accusatory on the *grid*, where a row of
outlined failures laid out by date is a list of accusations and the reader
already knows. As a side effect this is also what keeps the anchor below from
mattering very much.

The calendar borrows no days from the months either side — a grid showing 31
January in the same colour as 1 February invites the reader to count across a
boundary it is not showing — so the corner cells are blank. It pages back
without limit and stops at this month going forward: a grid of days that have
not happened reads as a list of things already failed.

**The chart shows twelve weeks that are over.** The week in progress is not on
it. Plotted at its running total it would read as a collapse every Monday and a
recovery every Sunday, forever, and the two usual ways out — a dashed last
segment, a hollow last marker — both say "unfinished", which is a half-step
toward the countdown this app does not do. Today is on the calendar directly
above it.

Its y-axis is fixed at the days the scope was actually due, never fitted to the
data: fitted, a week with one day in it fills the frame, and the chart flatters.
A week that ended before the first completion is not drawn at all rather than
drawn at zero — that week really did have nothing in it, and a zero there would
be the app inventing a dip out of not having been installed yet.

There is no charting package, and no calendar package. The line is thirty lines
of `CustomPaint` following `_VoussoirPainter`'s contract — resolved colours in
through the constructor, a real `shouldRepaint`, nothing animated. The weekday
bars are composed widgets, because seven labelled columns get their text layout
and their locale weekday names for free that way and stay the same shape as the
calendar's cells. The bars normalise by **rate**, not by the largest tally:
under a sparse mask the largest tally is the only one there is, and a
Friday-only wird would show one full bar and six empty ones and have said
nothing.

**No schema change.** The whole history for a scope is read once —
`completionDatesDescending` was already reading all of it for the streak — and
every figure is derived from that one `Set<String>` in Dart, so paging a month
costs no query at all. `lib/providers/tracker.dart` says why it departs from
`streakViewProvider`'s windowed read. The one thing added to `user.drift` is a
`SELECT DISTINCT collection_ref` for the picker, which is a query and not a
migration.

**The anchor is `min(committed at, first completed)`.** `uncommit` deletes the
row outright, so re-committing mints a fresh `created_at` and anchoring to that
alone would drop months of real practice behind it; anchoring to the first
completion alone leaves a collection committed this morning with nothing to
anchor to. There is no history of `days`, so a mask changed in September reads
January through today's mask — unfixable without a `commitment_history` table,
and not worth one for this tab.

**The whole tab comes off in Settings**, defaulting on. The switch is called
"Show tracker" and takes everything with it, which is the honest reading of
what somebody turning it off is asking for. Its stored key is still
`streak.visible`: these strings are persisted, and renaming one silently resets
whatever the reader had chosen.

**Home's cards encourage too, and that is no longer the exception it was.**
Each one carries a line about that collection's own run — "3 days. Keep going."
Nothing on a card escalates, so there is no tier to reach and none to fall out
of, and nothing on a card is negative, so a broken run reads as an invitation to
begin rather than as a loss to be warned about. Those are the two rules, and
they are now the rules on the tracker as well.

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

`sync_content_asset.sh` also writes `lib/data/content_stamp.dart`, which *is*
committed — it is a Dart source file `lib/data/database_files.dart` imports, and
a fresh clone would not compile without it. It holds the content version and the
checksum of the database in the bundle, and it is how the app decides, on the
first launch after an update, whether to replace the copy it made in application
support.

That used to be a comparison of the copy's byte length against the asset's,
which was wrong in the direction that hurts. SQLite allocates in 4 KB pages, so
a corrected translation, an added note, or a dhikr merged onto another id all
leave a file of exactly the same size: the copy would be kept and the release
would land with the user still reading the previous one's content, silently.
Comparing the stamp instead catches any change to the content, and skips
reading the 4.6 MB asset entirely when there is nothing to do — so it is also
the faster path. CI fails if the committed stamp is stale.

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
| Player count | Inter | 40 | 1.1 |
| Tasbih count | Inter | 72 | 1.1 |
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

`lib/dev/` is a rendering harness, and exists only in a debug build: its route
is registered `when kDebugMode` in `lib/routes.dart` and its one entry point is
behind the same constant, so a release build compiles it out. It puts the
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
tool/bump_version.sh 1.0.1
```

Pushing that to `main` is what cuts a release. `.github/workflows/release.yml`
notices the version changed, runs the test suite — by calling `ci.yml`, the same
workflow that runs on every pull request, rather than a copy of its steps that
would drift from it — and only then builds the Android App Bundle and the iOS
app, publishes a GitHub release and tags it `v1.0.1`. The tag is created at the
end, at the tested commit, which is what stops a tag ever naming a commit whose
tests did not pass. A push that does not change the version builds nothing.

Android ships through **Google Play**. The last job uploads the bundle to Play's
internal testing track; promoting it to closed testing or production is done by
hand in Play Console, once the build has been on a phone. The bundle is signed
with Play's upload key, and Play re-signs what it delivers with the app signing
key it holds. Nothing installable is attached to the GitHub release — the `.aab`
there is the archive of what went to Play, not a way around it.

The build numbers behind those versions — the Android `versionCode`, the iOS
`CFBundleVersion` — come from the CI run number rather than from `pubspec.yaml`.
Play rejects a build number it has seen before, and a number that only ever goes
up is one less thing to remember at bump time.

The iOS build is unsigned, because signing it needs an Apple Developer
certificate this repository does not hold. That is stated on the release itself
rather than left to be discovered. [`docs/RELEASING.md`](docs/RELEASING.md) has
the details: the keystore, the Play credentials, the first upload that has to be
made by hand, and the testing Play requires before production.

CI compiles the Android app on every pull request — `flutter build apk --debug`
in a job beside the tests. `analysis_options.yaml` excludes `android/**` and
`dart format` covers only `lib test tool`, so without that job the Kotlin and
the manifest would have nothing checking them until a release was being cut.
The release workflow skips it, having a real bundle to build.

## Updating

Through Google Play, and nothing else. Play keeps the app up to date on its own;
there is no in-app check, no notice and no prompt.

**Wirdi has no network access at all.** The release manifest declares no
permissions — not `INTERNET`, not anything — and the fonts and the content are
bundled, so nothing is fetched and nothing about anybody goes anywhere. That is
what the Play Data safety declaration and [`docs/PRIVACY.md`](docs/PRIVACY.md)
say, and `test/app/android_manifest_test.dart` fails if a permission is added,
so the claim cannot quietly stop being true.

Builds up to 0.8.2 were published as APKs on GitHub releases and carried an
opt-in self-updater that downloaded and installed the next one. It came out
before the move to Play, which rejects `REQUEST_INSTALL_PACKAGES` in an app
whose purpose is not installing packages. A phone still holding one of those
builds has it signed with a different key from the one Play delivers with, so
Android will not upgrade it in place: uninstall it once — which deletes
`user.db` with it — and install from Play.
