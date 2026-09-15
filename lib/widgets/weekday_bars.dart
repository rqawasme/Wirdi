import 'package:flutter/material.dart';

import '../domain/tracker_stats.dart';
import '../theme/theme.dart';

/// Which days of the week hold, and which are where it slips.
///
/// The most actionable thing on the tracker, and the reason it is here: a
/// streak says whether the habit is going, and this says *where* it is going
/// wrong. "Sundays are the gap" is something a person can do something about.
/// A number counting days is not.
///
/// Composed widgets rather than a [CustomPainter], unlike the chart beside it:
/// seven labelled columns get their text layout and their locale weekday names
/// for free as widgets, and stay the same shape as the calendar's cells and
/// the home tile's week strip. The chart is a painter because a polyline is
/// genuinely awkward to compose; this is not.
class WeekdayBars extends StatelessWidget {
  const WeekdayBars({
    super.key,
    required this.tallies,
    required this.firstWeekday,
    required this.caption,
  });

  /// The track a bar grows in.
  static const double trackHeight =
      WirdiMetrics.space6 * 2 + WirdiMetrics.space4;

  /// What a weekday that came round but was never kept still shows, so that a
  /// zero is a zero rather than a column that went missing.
  static const double emptyStub = 2;

  /// Indexed `DateTime.monday - 1` .. `DateTime.sunday - 1`, as
  /// [weekdayTallies] returns them.
  final List<WeekdayTally> tallies;

  /// The [DateTime] weekday constant the reader's week starts on. The columns
  /// are ordered from it, so they line up with the calendar's header.
  final int firstWeekday;

  final String caption;

  /// The weekdays across the row, starting at [firstWeekday].
  List<int> get _weekdays => <int>[
    for (int i = 0; i < DateTime.daysPerWeek; i++)
      (firstWeekday - 1 + i) % DateTime.daysPerWeek + 1,
  ];

  /// The height of each bar, 0..1.
  ///
  /// The share of that weekday that was kept, wherever the scope has days it
  /// owes. Normalising against the largest tally instead would make a
  /// Friday-only wird show one full bar and six empty ones and tell the reader
  /// nothing they did not already know.
  ///
  /// Where nothing is owed — "Everything", and a collection with no commitment
  /// — there is no rate to take, so the bars fall back to the busiest day.
  /// That is the only reading available, and the caption says which one is
  /// being shown.
  double _factor(WeekdayTally tally) {
    final double? rate = tally.rate;
    if (rate != null) return rate;
    final int busiest = tallies
        .map((WeekdayTally t) => t.done)
        .fold(0, (int a, int b) => a > b ? a : b);
    return busiest == 0 ? 0 : tally.done / busiest;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);

    return Semantics(
      container: true,
      label: _semanticLabel(l10n),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WirdiMetrics.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: trackHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (final (int i, int weekday)
                        in _weekdays.indexed) ...<Widget>[
                      if (i > 0) const SizedBox(width: WirdiMetrics.space1),
                      Expanded(
                        child: _Bar(
                          factor: _factor(tallies[weekday - 1]),
                          // A weekday the mask does not cover keeps its track
                          // and its label and grows no bar. Hiding the column
                          // would break the seven-column rhythm the header
                          // below is read against.
                          cameRound:
                              tallies[weekday - 1].due > 0 ||
                              tallies[weekday - 1].done > 0,
                          filled: scheme.primary,
                          track: scheme.surfaceContainerHigh,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: WirdiMetrics.space2),
              Row(
                children: <Widget>[
                  for (final (int i, int weekday)
                      in _weekdays.indexed) ...<Widget>[
                    if (i > 0) const SizedBox(width: WirdiMetrics.space1),
                    Expanded(
                      child: Center(
                        child: Text(
                          // DateTime weekday constants run Monday..Sunday as
                          // 1..7; narrowWeekdays runs Sunday..Saturday as 0..6.
                          l10n.narrowWeekdays[weekday % DateTime.daysPerWeek],
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: WirdiMetrics.space2),
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A list, not a verdict. Same rule as the chart's label: name the numbers
  /// and let the reader draw the conclusion.
  String _semanticLabel(MaterialLocalizations l10n) {
    final List<String> parts = <String>[
      for (final int weekday in _weekdays)
        if (tallies[weekday - 1] case final WeekdayTally t)
          t.due > 0
              ? '${l10n.narrowWeekdays[weekday % DateTime.daysPerWeek]} '
                    '${t.done} of ${t.due}'
              : '${l10n.narrowWeekdays[weekday % DateTime.daysPerWeek]} '
                    '${t.done}',
    ];
    return 'By weekday. ${parts.join(', ')}.';
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.factor,
    required this.cameRound,
    required this.filled,
    required this.track,
  });

  final double factor;
  final bool cameRound;
  final Color filled;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // The filled-against-unfilled pairing the voussoir stripe uses, so the
        // two read as the same language rather than as two chart styles.
        DecoratedBox(
          decoration: BoxDecoration(
            color: track,
            borderRadius: WirdiMetrics.chip,
          ),
        ),
        if (cameRound)
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: factor.clamp(0, 1),
              alignment: Alignment.bottomCenter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: filled,
                  borderRadius: WirdiMetrics.chip,
                ),
              ),
            ),
          ),
        if (cameRound && factor <= 0)
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: WeekdayBars.emptyStub,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: filled,
                  borderRadius: WirdiMetrics.chip,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
