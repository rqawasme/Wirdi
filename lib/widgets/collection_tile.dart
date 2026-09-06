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
    this.onTap,
  });

  /// The most segments the stripe is cut into. Past this the segments are
  /// thinner than the rhythm reads at, and the stripe stops being countable
  /// and starts being a bar.
  static const int maxSegments = 12;

  final String name;

  /// Set in Naskh at chrome size, right-aligned in its own line box. Optional:
  /// a user's own collection has no Arabic name, and the line box is kept
  /// either way so tiles with and without one line up across a row.
  final String? nameArabic;

  /// Repetitions in the whole collection.
  final int totalCount;

  /// Repetitions done today.
  final int doneCount;

  final bool completedToday;

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
                        _ArabicLine(
                          name: nameArabic,
                          style: type.arabicChrome.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: WirdiMetrics.space2),
                        // Takes what height is left and clips: the tile does
                        // not grow for a long name, and a name too long for
                        // the square is cut rather than pushing the meta line
                        // off the bottom of it.
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
  String get _semanticLabel {
    final String items = '$totalCount ${totalCount == 1 ? 'item' : 'items'}';
    if (completedToday) return '$name, $items, done today';
    if (doneCount > 0) return '$name, $doneCount of $totalCount done today';
    return '$name, $items, not started today';
  }
}

/// The Arabic name, in a line box that is there whether or not there is a name
/// to put in it.
///
/// Fixed height, so a collection without an Arabic name and one with a long
/// one produce the same tile: the English names of two tiles in a row start at
/// the same distance from the top, which is the alignment the grid is read by.
class _ArabicLine extends StatelessWidget {
  const _ArabicLine({required this.name, required this.style});

  final String? name;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final String? name = this.name;
    // Scaled through the OS text scaler rather than multiplied by a factor:
    // the platform scale is not necessarily linear, and asking the scaler for
    // this size is the only way to get the height the text will actually take.
    final double height =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;

    return SizedBox(
      height: height,
      child: name == null
          ? null
          : Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                name,
                style: style,
                locale: const Locale('ar'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
    );
  }
}

/// What the tile says about today, in one quiet line.
///
/// Not started, it is the count of what is in there. Part-way, it is how far
/// through. Done, it is a check and two words — and the check is an inline
/// glyph in the sentence rather than a badge, so a large accessibility text
/// scale wraps the line instead of overflowing the tile.
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

    final String text = doneCount > 0
        ? '$doneCount of $totalCount'
        : '$totalCount ${totalCount == 1 ? 'item' : 'items'}';

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
