import 'package:flutter/material.dart';

import '../collections/streak_calendar.dart';
import '../providers/streak.dart';
import '../theme/theme.dart';

/// The streak: a count of consecutive days, and this month's completed days.
///
/// ## What this deliberately is not
///
/// The standard streak component is built to be lost. It escalates — a flame
/// that grows, a tier that unlocks, a warning at the end of a day — because
/// loss aversion is what makes the number keep somebody opening the app. That
/// is a defensible thing to do to a language learner. It is not a defensible
/// thing to do to somebody's relationship with their own devotional practice,
/// which is between them and God and does not need an app applying pressure to
/// it.
///
/// So: the count is a number in the same type as everything else, and it does
/// not change appearance as it grows. A completed day is one mark, and it is
/// the same mark on day 2 as on day 200. Nothing warns, nothing congratulates,
/// nothing counts down the hours left in the day, and a zero says zero rather
/// than saying anything about the person reading it. There are no
/// notifications in the app at all.
///
/// The whole panel comes off in Settings. See [WirdiSettings.showStreak].
class StreakPanel extends StatelessWidget {
  const StreakPanel({super.key, required this.view});

  /// The side of one calendar cell. A day is a mark, not a button.
  static const double cellSize = WirdiMetrics.space6 + WirdiMetrics.space2;

  final StreakView view;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);
    final Color quiet = theme.colorScheme.onSurfaceVariant;

    return Semantics(
      container: true,
      label:
          '$_streakLabel. '
          '${l10n.formatMonthYear(view.month.firstDay)}, '
          '${view.completed.length} of ${view.month.length} days completed.',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            WirdiMetrics.space4,
            WirdiMetrics.space4,
            WirdiMetrics.space4,
            WirdiMetrics.space5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  // The same size as a collection's name. A streak is not more
                  // important than the wird it is counting.
                  Expanded(
                    child: Text(
                      _streakLabel,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    l10n.formatMonthYear(view.month.firstDay),
                    style: theme.textTheme.bodySmall?.copyWith(color: quiet),
                  ),
                ],
              ),
              const SizedBox(height: WirdiMetrics.space4),
              _WeekdayHeader(month: view.month, narrow: l10n.narrowWeekdays),
              for (final List<String?> week in view.month.weeks)
                Row(
                  children: <Widget>[
                    for (final String? day in week)
                      Expanded(
                        child: _Day(
                          day: day,
                          completed: view.isCompleted(day),
                          isToday: day == view.today,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Plain, and the same sentence whatever the number.
  ///
  /// Zero is stated rather than commented on: a streak that has ended is a
  /// fact about days, and the app has no business having a view about it.
  String get _streakLabel => switch (view.streak) {
    0 => 'No days in a row',
    1 => '1 day in a row',
    final int n => '$n days in a row',
  };
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.month, required this.narrow});

  final MonthGrid month;

  /// [MaterialLocalizations.narrowWeekdays], which is indexed from Sunday.
  final List<String> narrow;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        for (final int weekday in month.weekdays)
          Expanded(
            child: SizedBox(
              height: StreakPanel.cellSize,
              child: Center(
                child: Text(
                  // DateTime weekday constants run Monday..Sunday as 1..7;
                  // narrowWeekdays runs Sunday..Saturday as 0..6.
                  narrow[weekday % DateTime.daysPerWeek],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One day.
///
/// Completed is a filled square in [ColorScheme.primary] — the same squared
/// 4dp plate the surah number and the counter use, not a circle and not a
/// badge. Today is a hairline outline, which says where you are without
/// saying anything about what you have or have not done in it yet.
class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    required this.completed,
    required this.isToday,
  });

  final String? day;
  final bool completed;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final int? number = MonthGrid.dayOf(day);
    if (number == null) return const SizedBox(height: StreakPanel.cellSize);

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SizedBox(
      height: StreakPanel.cellSize,
      child: Center(
        child: Container(
          width: StreakPanel.cellSize,
          height: StreakPanel.cellSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: completed ? scheme.primary : null,
            borderRadius: WirdiMetrics.chip,
            border: isToday && !completed
                ? Border.all(
                    color: scheme.outline,
                    width: WirdiMetrics.hairline,
                  )
                : null,
          ),
          child: Text(
            '$number',
            style: theme.textTheme.labelMedium?.copyWith(
              color: completed ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
