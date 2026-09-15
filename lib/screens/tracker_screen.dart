import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is the type of a ProviderScope override; flutter_riverpod
// exports it from misc.dart rather than its main library.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../domain/tracker_stats.dart';
import '../providers/settings.dart';
import '../providers/streak.dart';
import '../providers/tracker.dart';
import '../theme/theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/failure_screen.dart';
import '../widgets/streak_panel.dart';
import '../widgets/tracker_chart.dart';
import '../widgets/tracker_scope_picker.dart';
import '../widgets/weekday_bars.dart';
import '../widgets/weekday_name.dart';

/// How the habit is going.
///
/// Four things, in the order the question is usually asked: how long the run
/// is, which days of this month it covered, what the last three months look
/// like as a shape, and which days of the week are where it slips. A picker at
/// the top switches all four between the app as a whole and one collection.
///
/// ## Everything, and one collection
///
/// "Everything" asks whether the habit is going at all: a day counts if
/// anything was completed on it. It has no due rule, so it cannot miss — the
/// app was never owed a day.
///
/// A collection is reckoned against the days it actually comes round on. That
/// is the whole reason this screen exists in more than its old form: the
/// app-wide streak answers "have I kept at it", a calendar-day streak on one
/// collection answers a question nobody asked, and a wird committed to Fridays
/// could never show a run longer than one under it. Here a Saturday is not a
/// miss for a Friday wird; it is not an anything.
///
/// ## The voice
///
/// This screen encourages, and it does not gamify. The difference is the whole
/// design: nothing on it escalates as a number grows, nothing has a tier or a
/// best, nothing warns, nothing is marked in red, and a missed day is not
/// marked at all. What is left is allowed to sound like it is on the reader's
/// side, because habit-building is what they opened the tab for. See
/// `StreakPanel`, which argues the case at length, and
/// `test/app/tracker_voice_test.dart`, which holds the line.
class TrackerScreen extends ConsumerWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool show = ref.watch(settingsProvider).value?.showTracker ?? false;
    if (!show) {
      return const EmptyState(
        title: 'The tracker is off',
        body: 'Turn "Show tracker" back on in Settings to see it here.',
      );
    }

    // The one place the reader's first weekday is resolved, and it is resolved
    // once for the whole tab. `firstWeekdayProvider` defaults to Monday, and a
    // calendar reading it in one subtree while the chart reads the default in
    // another is a pair of sections that quietly disagree about where a week
    // begins.
    //
    // `firstDayOfWeekIndex` is 0-based from Sunday; DateTime weekday constants
    // run Monday 1 .. Sunday 7.
    final int index = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    return ProviderScope(
      overrides: <Override>[
        firstWeekdayProvider.overrideWithValue(
          index == 0 ? DateTime.sunday : index,
        ),
      ],
      child: const _Tracker(),
    );
  }
}

class _Tracker extends ConsumerWidget {
  const _Tracker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(trackerViewProvider)) {
      AsyncError(:final Object error, :final StackTrace stackTrace) =>
        FailureScreen(
          title: 'Could not read your history',
          error: error,
          stackTrace: stackTrace,
        ),
      AsyncData(:final TrackerView value) => _Body(view: value),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.view});

  final TrackerView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.only(bottom: WirdiMetrics.space6),
      children: <Widget>[
        // Nothing to switch to means nothing to switch with. A control that
        // cannot do anything teaches the reader it is not worth pressing.
        if (view.hasChoice)
          TrackerScopePicker(
            label: view.label,
            options: view.options,
            selected: view.scope,
            onSelect: (TrackerScope scope) =>
                ref.read(trackerScopeProvider.notifier).select(scope),
          ),
        if (view.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: WirdiMetrics.space6),
            child: EmptyState(
              title: 'Nothing tracked yet',
              // One empty state for the whole screen, rather than an empty
              // grid over a flat line over seven empty bars: three of them
              // read as three things broken.
              body: view.scope is EverythingScope
                  ? 'Finish a collection and the days will start showing up '
                        'here.'
                  : 'Finish this one and the days will start showing up here.',
            ),
          )
        else ...<Widget>[
          StreakPanel(
            streak: view.streak,
            streakUnit: _streakUnit(context, view),
            note: _note(view),
            month: view.month,
            states: view.states,
            today: view.today,
            onStep: (int months) =>
                ref.read(browsedMonthProvider.notifier).step(months),
            canGoForward: view.canGoForward,
          ),
          _SectionHeader(_chartTitle),
          TrackerChart(
            weeks: view.weeks,
            maxPerWeek: _maxPerWeek,
            caption: _chartCaption,
          ),
          const SizedBox(height: WirdiMetrics.space5),
          _SectionHeader('Your week'),
          WeekdayBars(
            tallies: view.weekdays,
            firstWeekday: ref.watch(firstWeekdayProvider),
            caption: _barsCaption(context),
          ),
          const SizedBox(height: WirdiMetrics.space5),
          _Footer(view: view),
        ],
      ],
    );
  }

  /// The top of the chart's axis: days owed in a week, or seven where nothing
  /// is owed. Never fitted to the data — see [TrackerChart].
  int get _maxPerWeek => view.days?.weekdays.length ?? DateTime.daysPerWeek;

  String get _chartTitle => 'The last $trackerWeeks weeks';

  String get _chartCaption {
    final int max = _maxPerWeek;
    if (view.hasDueRule) {
      return max == 1
          ? 'Weeks it came round, and whether you were there'
          : 'Days kept each week, out of $max';
    }
    return 'Days practised each week, out of $max';
  }

  String _barsCaption(BuildContext context) {
    final String strongest = _strongestDay(context);
    if (view.hasDueRule) {
      return strongest.isEmpty
          ? 'The share of each day you have kept'
          : 'The share of each day you have kept. $strongest';
    }
    return strongest.isEmpty
        ? 'Days practised, by weekday'
        : 'Days practised, by weekday. $strongest';
  }

  /// The weekday that holds up best, named.
  ///
  /// The one genuinely actionable line on the screen: a run tells you the
  /// habit is going, this tells you where it is going wrong. It names the
  /// strongest rather than the weakest deliberately — the same fact, said as
  /// something the reader is doing rather than something they are failing.
  ///
  /// Empty when there is no winner worth naming: nothing done at all, or every
  /// day the same, where singling one out would be noise dressed as insight.
  String _strongestDay(BuildContext context) {
    final List<WeekdayTally> tallies = view.weekdays;
    double score(WeekdayTally t) => t.rate ?? t.done.toDouble();

    double best = -1;
    int bestIndex = -1;
    int ties = 0;
    for (final (int i, WeekdayTally tally) in tallies.indexed) {
      final double value = score(tally);
      if (value > best) {
        best = value;
        bestIndex = i;
        ties = 1;
      } else if (value == best) {
        ties++;
      }
    }
    if (bestIndex < 0 || best <= 0 || ties > 1) return '';

    final String name = weekdayName(context, bestIndex + 1);
    return 'You are strongest on ${name}s.';
  }

  /// The noun the run is counted in.
  ///
  /// A collection that comes round on one day of the week has a run measured
  /// in that day — eight Fridays, not eight days, because there were
  /// fifty-six and fifty-five of them were never owed.
  String? _streakUnit(BuildContext context, TrackerView view) {
    final int? only = view.onlyWeekday;
    return only == null ? null : weekdayName(context, only);
  }

  String _note(TrackerView view) {
    if (view.streak == 0) {
      // A run that has ended is stated by the count above. This is the half
      // that opens rather than closes, and it never mentions what ended.
      return 'A good day to begin again.';
    }

    // The most recent four weeks that are over, which is a different fact from
    // the run above rather than the same one said twice.
    final List<WeekPoint> recent = view.weeks
        .where((WeekPoint w) => w.hasData)
        .toList();
    final List<WeekPoint> window = recent.length <= 4
        ? recent
        : recent.sublist(recent.length - 4);

    if (view.hasDueRule) {
      final int done = window.fold(0, (int a, WeekPoint w) => a + w.done);
      final int owed = window.fold(0, (int a, WeekPoint w) => a + w.due);
      if (owed > 0) {
        return done == owed
            ? 'Every time it has come round lately, you have been there.'
            : 'You have kept $done of the last $owed times it came round.';
      }
    }

    return view.lastSeven == DateTime.daysPerWeek
        ? 'Every one of the last seven days.'
        : 'You have practised on ${view.lastSeven} of the last seven days.';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final WirdiTypography type = Theme.of(
      context,
    ).extension<WirdiTypography>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.space4,
        WirdiMetrics.space4,
        WirdiMetrics.space4,
        WirdiMetrics.space3,
      ),
      child: Text(title, style: type.sectionHeader),
    );
  }
}

/// The whole history, in one quiet line.
///
/// A count and a date, and nothing derived from them that could fall. An
/// average or a rate here would be a number to be anxious about, at the bottom
/// of a screen whose whole argument is that there is nothing to be anxious
/// about.
class _Footer extends StatelessWidget {
  const _Footer({required this.view});

  final TrackerView view;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final String? first = view.totals.firstDay;
    final int days = view.totals.days;
    final String count = days == 1 ? '1 day' : '$days days';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WirdiMetrics.space4),
      child: Text(
        first == null
            ? count
            : '$count since '
                  '${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(first))}',
        style: type.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
