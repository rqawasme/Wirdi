import 'package:flutter/material.dart';

import '../collections/streak_calendar.dart';
import '../domain/tracker_stats.dart';
import '../theme/theme.dart';

/// The streak: a count of consecutive days, and a month's days marked.
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
/// the same mark on day 2 as on day 200. Nothing warns, nothing counts down
/// the hours left in the day, and a zero says zero rather than saying anything
/// about the person reading it. There are no notifications in the app at all.
///
/// The tracker around this panel does encourage, in a line of its own — the
/// position argued at length in the README is against *gamification*, not
/// against warmth, and the distinction is what every rule above is. Nothing
/// here escalates and nothing here is negative; that is what makes the
/// encouragement outside it safe.
///
/// **A missed day gets no mark.** There are two marks and only two: a filled
/// square for a day completed, and a hairline outline for today. A day that
/// was due and not done looks exactly like a day that never came round,
/// because a grid of outlined failures laid out by date is a list of
/// accusations, and the reader already knows. Which days were owed is useful
/// in the *numbers* — the run, the weekly denominator, the weekday rate — and
/// that is where it stays.
///
/// The whole panel comes off in Settings. See [WirdiSettings.showTracker].
class StreakPanel extends StatelessWidget {
  const StreakPanel({
    super.key,
    required this.streak,
    required this.month,
    required this.states,
    required this.today,
    this.streakUnit,
    this.note,
    this.onStep,
    this.canGoForward = false,
  });

  /// The side of one calendar cell. A day is a mark, not a button.
  static const double cellSize = WirdiMetrics.space6 + WirdiMetrics.space2;

  /// The tap target on a paging chevron. Bigger than the glyph, as every
  /// touchable thing in this app is.
  static const double stepSize = WirdiMetrics.space6 * 2;

  /// Consecutive days — or consecutive due days — up to today.
  final int streak;

  final MonthGrid month;

  /// What each day of [month] was, by `YYYY-MM-DD` key. A day missing from
  /// here is a padding cell.
  final Map<String, DayState> states;

  final String today;

  /// The singular noun the count is in, when it is not "day".
  ///
  /// A collection committed to Fridays alone has a run measured in Fridays,
  /// and saying "8 days in a row" about it would be false — there were
  /// fifty-six. Null means days, which is almost every case.
  final String? streakUnit;

  /// One warm sentence under the count.
  ///
  /// The count itself stays flat, because a number that changes character as
  /// it grows is a number engineered to be lost. This line is where the app is
  /// allowed to sound like it is on the reader's side — the position is
  /// against gamification, not against warmth. What it may not do is escalate
  /// or warn: it reads the same at three hundred days as at three, and a run
  /// that has ended is an invitation to begin rather than a loss to be told
  /// about. Null leaves the panel silent, which is what it was before.
  final String? note;

  /// Steps the calendar by a number of months, negative for back. Null leaves
  /// the panel without paging, which is how the home-adjacent uses want it.
  final void Function(int months)? onStep;

  /// Whether there is a month ahead worth going to. There never is beyond this
  /// one: a grid of days that have not happened yet reads as a list of things
  /// already failed.
  final bool canGoForward;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);
    final Color quiet = theme.colorScheme.onSurfaceVariant;
    final void Function(int months)? onStep = this.onStep;

    final int completedDays = states.values
        .where((DayState state) => state == DayState.completed)
        .length;

    return Semantics(
      container: true,
      label:
          '$_streakLabel. '
          '${note == null ? '' : '$note '}'
          '${l10n.formatMonthYear(month.firstDay)}, '
          '$completedDays of ${month.length} days completed.',
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
            // The arrows stay outside the ExcludeSemantics below: they are the
            // one thing on this panel a screen reader has to be able to reach.
            ExcludeSemantics(
              child: Row(
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
                    l10n.formatMonthYear(month.firstDay),
                    style: theme.textTheme.bodySmall?.copyWith(color: quiet),
                  ),
                ],
              ),
            ),
            if (note case final String note) ...<Widget>[
              const SizedBox(height: WirdiMetrics.space2),
              ExcludeSemantics(
                child: Text(
                  note,
                  style: theme.textTheme.bodyMedium?.copyWith(color: quiet),
                ),
              ),
            ],
            if (onStep != null)
              _Paging(
                onStep: onStep,
                canGoForward: canGoForward,
                colour: quiet,
              ),
            const SizedBox(height: WirdiMetrics.space4),
            ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _WeekdayHeader(month: month, narrow: l10n.narrowWeekdays),
                  for (final List<String?> week in month.weeks)
                    Row(
                      children: <Widget>[
                        for (final String? day in week)
                          Expanded(
                            child: _Day(
                              day: day,
                              completed:
                                  day != null &&
                                  states[day] == DayState.completed,
                              isToday: day == today,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Plain, and the same sentence whatever the number.
  ///
  /// Zero is stated rather than commented on: a streak that has ended is a
  /// fact about days, and this panel has no business having a view about it.
  /// The line next to it does, which is a different widget and a decision made
  /// on its own terms.
  String get _streakLabel {
    final String one = streakUnit ?? 'day';
    final String many = '${one}s';
    return switch (streak) {
      0 => 'No $many in a row',
      1 => '1 $one in a row',
      final int n => '$n $many in a row',
    };
  }
}

/// Back and forward a month.
///
/// Chevrons set in type rather than [Icon]s. Partly because this app's only
/// ornament is the voussoir stripe and an icon would be the second; mostly
/// because a glyph in the text style sits on the same baseline grid as
/// everything else on the panel, where an icon has its own box and its own
/// optical centre to argue with.
class _Paging extends StatelessWidget {
  const _Paging({
    required this.onStep,
    required this.canGoForward,
    required this.colour,
  });

  final void Function(int months) onStep;
  final bool canGoForward;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _Step(
          glyph: '‹',
          label: 'Previous month',
          colour: colour,
          // There is no floor. A month before the app was installed simply has
          // nothing in it, which is the truth and reads as one.
          onTap: () => onStep(-1),
        ),
        _Step(
          glyph: '›',
          label: 'Next month',
          colour: colour,
          // Disabled rather than hidden at this month: a control that
          // disappears leaves the reader wondering what they did.
          onTap: canGoForward ? () => onStep(1) : null,
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.glyph,
    required this.label,
    required this.colour,
    required this.onTap,
  });

  final String glyph;
  final String label;
  final Color colour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: WirdiMetrics.chip,
        child: SizedBox(
          width: StreakPanel.stepSize,
          height: StreakPanel.stepSize,
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                glyph,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: enabled ? colour : theme.colorScheme.outline,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
