import 'package:flutter/material.dart';

import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/commitment.dart';
import '../providers/collections.dart';
import '../theme/theme.dart';
import 'collection_row.dart';
import 'weekday_name.dart';

/// A work recited in parts, as one row: its name, today's part, and the week.
///
/// Dala'il al-Khayrat is eleven collections, and as eleven rows it was most of
/// the list — the same name over and over, differing by a weekday in brackets
/// or the name of a supplication. As one row the name is said once, and the
/// parts are what they actually are to somebody reciting them: days of the
/// week, with today's marked out.
///
/// The header opens today's part, which is the one somebody tapping the name
/// on a Tuesday means. Each day opens its own part. A part said on no set day
/// — the opening and closing supplications and those like them — is a line of
/// its own, since it is not a day and drawing it as one would say it was. It
/// sits where it is said: above the week when it comes before the daily parts,
/// below it when it comes after.
///
/// Today is filled brick, the one place in the list a row is told apart by
/// colour: the week strip is a calendar, and a calendar that does not say
/// where you are in it is a list of seven words.
class CollectionSeriesRow extends StatelessWidget {
  const CollectionSeriesRow({
    super.key,
    required this.series,
    required this.parts,
    required this.today,
    required this.commitments,
    required this.onOpen,
  });

  /// The height of one day: a tap target. The width is a seventh of the row,
  /// and seven of them and their gaps fit the narrowest phone.
  static const double dayHeight = 44;

  final CollectionSeries series;

  /// Every part, in list order.
  final List<CollectionListing> parts;

  /// The local date, for which part is today's.
  final DateTime today;

  /// Every commitment by collection; a part absent from it is not on Home.
  final Map<CollectionId, Commitment> commitments;

  final ValueChanged<CollectionId> onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final Color quiet = theme.colorScheme.onSurfaceVariant;

    final Map<int, CollectionListing> byDay = <int, CollectionListing>{
      for (final CollectionListing part in parts)
        if (part.summary.series?.weekday case final int day) day: part,
    };
    // Before the week or after it, by where the content build sorts it
    // against the first daily part. With no daily parts at all, everything is
    // after the header, which is the only place left.
    final int? weekStarts = byDay.isEmpty
        ? null
        : byDay.values
              .map((CollectionListing p) => p.summary.sortOrder)
              .reduce((int a, int b) => a < b ? a : b);
    final List<CollectionListing> before = <CollectionListing>[
      for (final CollectionListing part in parts)
        if (part.summary.series?.weekday == null &&
            weekStarts != null &&
            part.summary.sortOrder < weekStarts)
          part,
    ];
    final List<CollectionListing> after = <CollectionListing>[
      for (final CollectionListing part in parts)
        if (part.summary.series?.weekday == null && !before.contains(part))
          part,
    ];
    final CollectionListing? todays = byDay[today.weekday];
    final CollectionListing first = todays ?? parts.first;
    final bool onHome = parts.any(
      (CollectionListing p) => commitments.containsKey(p.id),
    );

    final String summary = todays == null
        ? '${parts.length} parts'
        : "Today's part: ${weekdayName(context, today.weekday)}";

    return Padding(
      padding: const EdgeInsets.only(bottom: WirdiMetrics.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            container: true,
            button: true,
            excludeSemantics: true,
            label: <String>[
              series.name,
              if (todays != null)
                "today's part, ${itemCountLabel(todays.itemCount)}"
              else
                '${parts.length} parts',
              if (todays?.completedToday ?? false) 'done today',
              if (onHome) 'On Home',
            ].join(', '),
            // The node's own tap, since excluding what is under it excludes
            // the InkWell's — see [CollectionRow].
            onTap: () => onOpen(first.id),
            child: InkWell(
              onTap: () => onOpen(first.id),
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
                                (
                                  BuildContext context,
                                  BoxConstraints constraints,
                                ) => Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        series.name,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ),
                                    const SizedBox(width: WirdiMetrics.space4),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            constraints.maxWidth *
                                            CollectionRow.arabicShare,
                                      ),
                                      child: Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: Text(
                                          series.nameArabic,
                                          style: type.arabicTitle,
                                          locale: const Locale('ar'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                          ),
                          const SizedBox(height: WirdiMetrics.space1),
                          CollectionMeta(
                            items: todays == null
                                ? summary
                                : '$summary · '
                                      '${itemCountLabel(todays.itemCount)}',
                            completedToday: todays?.completedToday ?? false,
                            inProgress: todays?.inProgress ?? false,
                            home: onHome ? 'On Home' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: WirdiMetrics.space2),
                    Icon(Icons.chevron_right, color: quiet),
                  ],
                ),
              ),
            ),
          ),
          for (final CollectionListing part in before)
            _UndatedPart(series: series, part: part, onOpen: onOpen),
          if (before.isNotEmpty) const SizedBox(height: WirdiMetrics.space2),
          if (byDay.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: WirdiMetrics.space4,
              ),
              child: Row(
                children: <Widget>[
                  for (
                    int day = DateTime.monday;
                    day <= DateTime.sunday;
                    day++
                  ) ...<Widget>[
                    if (day > DateTime.monday)
                      const SizedBox(width: WirdiMetrics.space1),
                    Expanded(
                      child: _Day(
                        weekday: day,
                        part: byDay[day],
                        isToday: day == today.weekday,
                        onOpen: onOpen,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          for (final CollectionListing part in after)
            _UndatedPart(series: series, part: part, onOpen: onOpen),
        ],
      ),
    );
  }
}

/// One day of the week strip: the part said on it, or an empty square when
/// the series has none for that day.
class _Day extends StatelessWidget {
  const _Day({
    required this.weekday,
    required this.part,
    required this.isToday,
    required this.onOpen,
  });

  final int weekday;
  final CollectionListing? part;
  final bool isToday;
  final ValueChanged<CollectionId> onOpen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final CollectionListing? part = this.part;
    final String day = weekdayName(context, weekday);
    // Three letters, which is what a week strip says in English and all this
    // app says anything in. The full name is what a screen reader hears.
    final String short = day.length > 3 ? day.substring(0, 3) : day;
    final Color ink = isToday ? scheme.onPrimary : scheme.onSurface;

    final Widget face = Container(
      height: CollectionSeriesRow.dayHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday ? scheme.primary : null,
        borderRadius: WirdiMetrics.chip,
        border: Border.all(
          color: isToday ? scheme.primary : scheme.outline,
          width: WirdiMetrics.hairline,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            short,
            maxLines: 1,
            style: text.labelMedium?.copyWith(
              color: part == null ? scheme.onSurfaceVariant : ink,
            ),
          ),
          if (part != null && part.completedToday)
            Icon(Icons.check, size: WirdiMetrics.space3, color: ink),
        ],
      ),
    );

    if (part == null) return ExcludeSemantics(child: face);

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: <String>[
        part.name,
        if (isToday) 'today',
        itemCountLabel(part.itemCount),
        if (part.completedToday) 'done today',
      ].join(', '),
      onTap: () => onOpen(part.id),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: WirdiMetrics.chip,
          onTap: () => onOpen(part.id),
          child: face,
        ),
      ),
    );
  }
}

/// A part said on no set day, as a line under the week.
class _UndatedPart extends StatelessWidget {
  const _UndatedPart({
    required this.series,
    required this.part,
    required this.onOpen,
  });

  final CollectionSeries series;
  final CollectionListing part;
  final ValueChanged<CollectionId> onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = partName(series, part.name);

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: '${part.name}, ${itemCountLabel(part.itemCount)}',
      onTap: () => onOpen(part.id),
      child: InkWell(
        onTap: () => onOpen(part.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              WirdiMetrics.space4,
              WirdiMetrics.space2,
              WirdiMetrics.space2,
              0,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: ' · ${itemCountLabel(part.itemCount)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [name] without the series' name in front of it: "Closing Supplication" out
/// of "Dala'il al-Khayrat — Closing Supplication". The whole name when it does
/// not start with the series', which is still true, only longer.
String partName(CollectionSeries series, String name) {
  if (!name.startsWith(series.name)) return name;
  final String rest = name
      .substring(series.name.length)
      .replaceFirst(RegExp(r'^[\s—–:-]+'), '');
  return rest.isEmpty ? name : rest;
}
