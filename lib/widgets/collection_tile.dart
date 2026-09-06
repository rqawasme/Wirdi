import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'voussoir_stripe.dart';

/// One committed collection on the home screen, as a square tile.
///
/// The row form (`CollectionRow`) is still what the collections list uses;
/// this is the daily-commitment form, where the thing that matters is how far
/// through today's wird you are rather than what the collection contains.
///
/// Square on purpose. The tile is a fixed shape, so a two-word name and a
/// six-word one make the same object: a long name wraps and then clips rather
/// than growing the tile and breaking the row it sits in.
///
/// Progress is the voussoir stripe, flush along the bottom edge and clipped by
/// the card's own radius. One segment per repetition up to twelve, so a wird of
/// a hundred still reads as a stripe rather than as a grey smear, and quantised
/// down by the stripe itself — ninety-six percent of the way through must not
/// look finished.
///
/// Finished for the day, the tile steps *down*: the background goes one tonal
/// step to [ColorScheme.surfaceContainerHigh], the name goes to quiet ink, the
/// meta line becomes a check and "Done today", and the stripe is not drawn at
/// all. A completed tile is the quietest object in its section rather than the
/// loudest — a full band of brick across the strongest colour in the palette
/// would make the expected outcome the most emphatic thing on the screen, and
/// finishing a daily wird is expected. No badge, no colour change, no
/// strike-through, no celebration.
class CollectionTile extends StatelessWidget {
  const CollectionTile({
    super.key,
    required this.name,
    this.nameArabic,
    required this.totalCount,
    this.doneCount = 0,
    this.completedToday = false,
    this.week = const <bool>[],
    this.streak = 0,
    this.onTap,
  });

  /// Width over height, and the same for every tile on the screen.
  ///
  /// A fixed ratio rather than a fixed height, so a two-word name and a
  /// six-word one make the same object. Square, because the card holds a name,
  /// a line about the run of days, a week of marks and a count — four short
  /// things and not a page, and at this width they come to almost exactly a
  /// square's height with two lines left for the name.
  ///
  /// An earlier draft ran to 3:4 to fit two lines of the wird's opening text.
  /// When the opening text came off the card the height went with it: a card
  /// with air in it is a card with nothing in it, whatever is drawn behind the
  /// air.
  static const double aspectRatio = 1;

  /// The most segments the stripe is cut into. Past this the segments are
  /// thinner than the rhythm reads at, and the stripe stops being countable
  /// and starts being a bar.
  static const int maxSegments = 12;

  final String name;

  /// Set in Naskh at chrome size, right-aligned on its own line. Optional:
  /// a user's own collection has no Arabic name, and the line is then not
  /// drawn at all — an empty line box held open for an absent name is a gap
  /// the tile has no explanation for, and reads as something missing rather
  /// than as alignment.
  final String? nameArabic;

  /// Repetitions in the whole collection.
  final int totalCount;

  /// Repetitions done today.
  final int doneCount;

  final bool completedToday;

  /// The last seven days, oldest first: true on a day this was completed.
  /// Empty to draw no strip at all.
  final List<bool> week;

  /// Consecutive days up to today on which *this* collection was completed.
  /// Zero when today is the first day, or when the run was broken.
  final int streak;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final String? nameArabic = this.nameArabic;

    final Color ink = completedToday
        ? scheme.onSurfaceVariant
        : scheme.onSurface;

    return Semantics(
      container: true,
      button: true,
      label: _semanticLabel,
      child: ExcludeSemantics(
        child: Material(
          // Flat, and stated rather than inherited: elevation 0, no shadow,
          // no surface tint. Depth in this app is the tonal step and the
          // hairline, and nothing else.
          color: completedToday
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainer,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: WirdiMetrics.card,
            side: BorderSide(
              color: scheme.outlineVariant,
              width: WirdiMetrics.hairline,
            ),
          ),
          // So the stripe's square ends are cut by the card's corners.
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(WirdiMetrics.space3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (nameArabic != null) ...<Widget>[
                          _ArabicLine(
                            name: nameArabic,
                            style: type.arabicChrome.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: WirdiMetrics.space2),
                        ],
                        // Takes what height is left and clips: the card
                        // does not grow for a long name, and a name too
                        // long for it is cut rather than pushing the lines
                        // below off the bottom of it.
                        Expanded(
                          child: ClipRect(
                            child: Align(
                              alignment: AlignmentDirectional.topStart,
                              heightFactor: 1,
                              child: Text(
                                name,
                                style: type.tileName.copyWith(color: ink),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: WirdiMetrics.space2),
                        _Encouragement(
                          streak: streak,
                          completedToday: completedToday,
                          style: type.caption.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (week.isNotEmpty) ...<Widget>[
                          const SizedBox(height: WirdiMetrics.space2),
                          _WeekStrip(
                            days: week,
                            // No brick on a finished card, anywhere. It
                            // drops its stripe for the same reason: an
                            // earlier draft made the expected outcome the
                            // loudest thing in the section.
                            done: completedToday
                                ? scheme.onSurfaceVariant
                                : scheme.primary,
                            notDone: scheme.outline,
                          ),
                        ],
                        const SizedBox(height: WirdiMetrics.space2),
                        _Meta(
                          totalCount: totalCount,
                          doneCount: doneCount,
                          completedToday: completedToday,
                          colour: scheme.onSurfaceVariant,
                          style: type.caption,
                        ),
                      ],
                    ),
                  ),
                ),
                if (!completedToday)
                  VoussoirStripe.progress(value: _value, segments: _segments),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int get _segments => totalCount <= 0
      ? 1
      : (totalCount < maxSegments ? totalCount : maxSegments);

  double get _value =>
      totalCount <= 0 ? 0 : (doneCount / totalCount).clamp(0.0, 1.0);

  /// Read aloud as a sentence, because the tile is a paragraph of quiet facts
  /// and reading it out field by field is not how it is meant to land.
  ///
  /// The opening words are not in it. They are Arabic scripture inside an
  /// English sentence, and a screen reader set to English says them as
  /// mojibake or says nothing; the card is still fully identified by its name.
  /// The arch is not in it either — it is a watermark, and it says nothing.
  String get _semanticLabel {
    final String items = '$totalCount ${totalCount == 1 ? 'item' : 'items'}';
    final String today = completedToday
        ? '$name, $items, done today'
        : doneCount > 0
        ? '$name, $doneCount of $totalCount done today'
        : '$name, $items, not started today';
    if (week.isEmpty) return today;
    return '$today. $_weekLabel';
  }

  /// The strip, as a count rather than seven read-out days. "Four of the last
  /// seven days" is what the row is for; which four is not something anybody
  /// listens through seven words to learn.
  String get _weekLabel {
    final int done = week.where((bool day) => day).length;
    if (done == 0) return 'None of the last ${week.length} days';
    return '$done of the last ${week.length} days';
  }
}

/// The Arabic name, right-aligned on its own line above the English one.
///
/// The line is sized by the text it holds, and is only built when there is a
/// name to put in it.
class _ArabicLine extends StatelessWidget {
  const _ArabicLine({required this.name, required this.style});

  final String name;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        name,
        style: style,
        locale: const Locale('ar'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // Right, not [TextAlign.end]: end inside this right-to-left box is
        // the *left* edge, which is where an earlier draft put the name.
        textAlign: TextAlign.right,
      ),
    );
  }
}

/// The last seven days of this collection, as seven marks.
///
/// A day is the same mark the tracker's calendar uses — a filled square in
/// [ColorScheme.primary] at the 4dp plate radius, not a circle and not a badge
/// — shrunk to the size a card can hold. A day that was not done is the same
/// square in [ColorScheme.outline] rather than an absence, so the row reads as
/// seven days of which some are done, not as a variable number of dots.
/// `outline` and not the fainter `outlineVariant`, because that role is the
/// same colour as a finished card's own ground in dark, and a mark that
/// vanishes reads as a missing day rather than as an unfinished one.
///
/// Today is not marked out from the six behind it. A calendar of thirty-one
/// cells has to say where you are; a row of seven says it by ending, and
/// pointing at today's empty square is the app leaning on somebody about a
/// day they are still in.
///
/// It states what happened and stops. There is no number, no "best", nothing
/// that gets louder as the row fills, and a row of seven blanks says seven
/// blanks — the app's position on streaks is in `StreakPanel`, and a card is
/// not the place to start hedging it.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.days,
    required this.done,
    required this.notDone,
  });

  /// The side of one mark. Three base units, and not two: at 8dp the 4dp
  /// plate radius is half the side, which is a circle, and this app does not
  /// have circles in it. Seven of these and their gaps come to 108dp, inside
  /// the narrowest card the grid makes.
  static const double markSize = WirdiMetrics.space3;

  /// Oldest first, today last.
  final List<bool> days;

  final Color done;
  final Color notDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final (int i, bool day) in days.indexed) ...<Widget>[
          if (i > 0) const SizedBox(width: WirdiMetrics.space1),
          Container(
            width: markSize,
            height: markSize,
            decoration: BoxDecoration(
              color: day ? done : notDone,
              borderRadius: WirdiMetrics.chip,
            ),
          ),
        ],
      ],
    );
  }
}

/// A word about the run of days, above the count.
///
/// **This is the one place in the app that encourages.** Everywhere else —
/// the greeting, the tracker, `StreakPanel`, which argues the case at length
/// — a streak is a number stated flatly and never commented on, because the
/// standard streak component is engineered around loss aversion and pointing
/// that at somebody's devotional life is a different thing from pointing it at
/// a language app. A card that says "keep it going" is a deliberate departure
/// from that, made knowingly and after the argument was put; if the position
/// is ever restored, this widget is the whole of what has to go.
///
/// Two rules it does keep, because they are what stops encouragement becoming
/// pressure. Nothing here escalates: the line reads the same at three hundred
/// days as at three, so there is no tier to reach and none to fall out of. And
/// nothing here is negative — a broken run is an invitation to start, never a
/// warning, a countdown, or a remark about the days that were missed.
class _Encouragement extends StatelessWidget {
  const _Encouragement({
    required this.streak,
    required this.completedToday,
    required this.style,
  });

  /// Consecutive days up to today, this collection's own.
  final int streak;

  final bool completedToday;

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(
      _line,
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// The four states a run can be in, and one sentence each.
  ///
  /// Done today is past tense and closes; not yet is present tense and opens.
  /// Neither says how many days are left in anything, because nothing here is
  /// running out.
  ///
  /// A finished card says "Done today" on the meta line below this one, so
  /// this one does not say it again: two lines saying the same three words is
  /// how a card starts reading as filler.
  ///
  /// Every one of them fits on one line of a card at the default text scale,
  /// which is not a coincidence — the card is sized for one, and a sentence
  /// that wraps to two costs the name a line of its own.
  String get _line {
    if (completedToday) {
      return switch (streak) {
        1 => 'A day begun.',
        _ => '$streak days and counting.',
      };
    }
    return switch (streak) {
      0 => 'A good day to begin.',
      1 => 'Day one. Keep going.',
      _ => '$streak days. Keep going.',
    };
  }
}

/// What the tile says about today, in one quiet line.
///
/// Until it is done, it is how far through today's repetitions the user is,
/// over how many there are — at zero as much as at forty, so the line does not
/// change shape the moment the first tap lands. Done, it is a check and two
/// words, and the check is an inline glyph in the sentence rather than a
/// badge, so a large accessibility text scale wraps the line instead of
/// overflowing the tile.
class _Meta extends StatelessWidget {
  const _Meta({
    required this.totalCount,
    required this.doneCount,
    required this.completedToday,
    required this.colour,
    required this.style,
  });

  final int totalCount;
  final int doneCount;
  final bool completedToday;
  final Color colour;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final TextStyle resolved = style.copyWith(color: colour);

    if (completedToday) {
      return Text.rich(
        TextSpan(
          children: <InlineSpan>[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                Icons.check,
                size: WirdiMetrics.space4,
                color: colour,
              ),
            ),
            const TextSpan(text: ' Done today'),
          ],
        ),
        style: resolved,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Always the fraction, including at zero. "140 items" and "41 of 140" are
    // two different sentences about the same tile, and reading a row of tiles
    // means reading the same shape in the same place on each of them.
    final String text = '$doneCount/$totalCount';

    // The minutes estimate the design shows is deliberately absent: nothing in
    // the content pipeline produces one, and the tile reads correctly without
    // it. Inventing a number here would be inventing the only invented number
    // on the screen.
    return Text(
      text,
      style: resolved,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
