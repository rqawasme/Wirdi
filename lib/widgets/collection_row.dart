import 'package:flutter/material.dart';

import '../domain/commitment.dart';
import '../providers/collections.dart';
import '../theme/theme.dart';
import 'weekday_name.dart';

/// One collection, as a row in the collections list.
///
/// Its opposite number is `CollectionTile`, the square form on the home
/// screen: a tile is for doing today's wird and says how far through it you
/// are, a row is for finding a collection and says what state it is in.
/// Neither substitutes for the other.
///
/// **One tap target, and it opens the collection.** The row used to carry four
/// icon buttons — look inside, recite, commit, and a menu for the rest — and
/// they were the complaint: four glyphs on every row of a long list, each to
/// be learned, with nothing to say which was which but a tooltip nobody on a
/// phone ever sees. The collection page now has those actions as buttons with
/// their names on them, so the row only has to get somebody there.
///
/// **What it says** is the names, how many items, and today's state — done,
/// part-way, or nothing at all — plus whether the collection is on Home and
/// when. That last used to be the difference between a filled house and an
/// outlined one; it is words now, in brick, because it is the one thing on the
/// row the user decided rather than the app.
///
/// The description is not on the row. It was capped at two lines and it was
/// what made every row a paragraph; it is on the collection page in full,
/// which is where somebody who wanted it went.
///
/// The completed-today mark stays quiet — a small check in
/// [ColorScheme.onSurfaceVariant], on the same line as the item count and in
/// the same colour as it. Finishing a daily wird is the expected outcome, not
/// an achievement, and a row that congratulates you every evening stops
/// meaning anything by the third day.
class CollectionRow extends StatelessWidget {
  const CollectionRow({
    super.key,
    required this.listing,
    required this.onTap,
    this.commitment,
    this.title,
  });

  /// The most of a row the Arabic name may take before it starts wrapping.
  static const double arabicShare = 0.45;

  final CollectionListing listing;

  final VoidCallback onTap;

  /// Null when the collection is not on Home.
  final Commitment? commitment;

  /// What the row calls the collection, when not its whole name: on a series'
  /// page, "Part 1 (Monday)" says what "Dala'il al-Khayrat — Part 1 (Monday)"
  /// does under a heading that already says Dala'il al-Khayrat. A screen
  /// reader still hears the whole name.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final Commitment? commitment = this.commitment;
    final String? home = commitment == null
        ? null
        : onHomeLabel(context, commitment);

    final String items = itemCountLabel(listing.itemCount);
    final String state = listing.completedToday
        ? 'done today'
        : listing.inProgress
        ? 'part-way through'
        : 'not started today';

    return CollectionRowFrame(
      name: title ?? listing.name,
      nameArabic: listing.summary.nameArabic,
      // The name, the count and today's state, and Home when it is. Not the
      // Arabic name, which a screen reader set to English reads as noise, and
      // not the button's job, which the semantics already say.
      semanticLabel: <String>[listing.name, items, state, ?home].join(', '),
      onTap: onTap,
      meta: CollectionMeta(
        items: items,
        completedToday: listing.completedToday,
        inProgress: listing.inProgress,
        home: home,
      ),
    );
  }
}

/// The shape every row in the collections list shares: the names on one line,
/// a line of meta under them, and a chevron — one button, which opens
/// something.
///
/// Its own widget so that a row which is not one collection — a series of
/// them — is the same shape as the rows around it rather than a lookalike that
/// drifts.
class CollectionRowFrame extends StatelessWidget {
  const CollectionRowFrame({
    super.key,
    required this.name,
    required this.meta,
    required this.semanticLabel,
    required this.onTap,
    this.nameArabic,
  });

  final String name;
  final String? nameArabic;
  final Widget meta;

  /// The whole of what a screen reader hears: the row is one node, labelled
  /// in a sentence, rather than its texts read one by one.
  final String semanticLabel;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final Color quiet = theme.colorScheme.onSurfaceVariant;
    final String? nameArabic = this.nameArabic;

    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      // The tap is the node's own: excluding what is under it excludes the
      // InkWell's action too, and a button a screen reader cannot press is a
      // label.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            WirdiMetrics.space4,
            WirdiMetrics.space3,
            WirdiMetrics.space2,
            WirdiMetrics.space3,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) =>
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                  if (nameArabic != null) ...<Widget>[
                                    const SizedBox(width: WirdiMetrics.space4),
                                    // Capped rather than given a flex share:
                                    // an Arabic name that needs a third of the
                                    // row should not take half of it and wrap
                                    // the English name that would otherwise
                                    // have fitted.
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            constraints.maxWidth *
                                            CollectionRow.arabicShare,
                                      ),
                                      child: Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: Text(
                                          nameArabic,
                                          style: type.arabicTitle,
                                          locale: const Locale('ar'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                    ),
                    const SizedBox(height: WirdiMetrics.space1),
                    meta,
                  ],
                ),
              ),
              const SizedBox(width: WirdiMetrics.space2),
              Icon(Icons.chevron_right, color: quiet),
            ],
          ),
        ),
      ),
    );
  }
}

/// "1 item", "16 items".
String itemCountLabel(int count) => '$count ${count == 1 ? 'item' : 'items'}';

/// Where a commitment puts a collection, as the row and the collection page
/// say it: "On Home · Morning", "On Home · Evening · Fridays".
///
/// The Today section says nothing after "On Home": a collection in it is not
/// tied to a time, and "On Home · Today" reads as if it were only today.
String onHomeLabel(BuildContext context, Commitment commitment) {
  final Weekdays days = commitment.days;
  final List<int> weekdays = days.weekdays;
  return <String>[
    'On Home',
    if (commitment.section != DailySection.today) commitment.section.label,
    if (!days.isEveryDay && weekdays.length == 1)
      '${weekdayName(context, weekdays.single)}s'
    else if (!days.isEveryDay)
      '${weekdays.length} days a week',
  ].join(' · ');
}

/// The line under a collection's name: its item count, and what state it is
/// in today.
///
/// One paragraph rather than a row of boxes: the check and the house are
/// inline glyphs in the sentence, so a long label or a large accessibility
/// text scale wraps the line instead of overflowing it.
class CollectionMeta extends StatelessWidget {
  const CollectionMeta({
    super.key,
    required this.items,
    required this.completedToday,
    required this.inProgress,
    this.home,
  });

  final String items;
  final bool completedToday;
  final bool inProgress;

  /// [onHomeLabel], or null when the collection is not on Home.
  final String? home;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color quiet = theme.colorScheme.onSurfaceVariant;
    final Color brick = theme.colorScheme.primary;
    final TextStyle? style = theme.textTheme.bodySmall?.copyWith(color: quiet);
    final String? home = this.home;

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: items),
          if (completedToday) ...<InlineSpan>[
            const TextSpan(text: ' · '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(Icons.check, size: WirdiMetrics.space4, color: quiet),
            ),
            const TextSpan(text: ' Done today'),
          ] else if (inProgress)
            const TextSpan(text: ' · Part-way through'),
          if (home != null) ...<InlineSpan>[
            const TextSpan(text: '   '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(Icons.home, size: WirdiMetrics.space4, color: brick),
            ),
            TextSpan(
              text: ' $home',
              style: TextStyle(color: brick, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
      style: style,
    );
  }
}
