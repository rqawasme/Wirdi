/// The arithmetic behind the Tracker tab: what a day was, how long a run is,
/// and how the weeks and the weekdays behind it add up.
///
/// Pure Dart, like `date_key.dart` and `streak_calendar.dart`. Nothing here
/// touches Flutter, a repository or a clock — `now` is passed in — so the part
/// of the tracker most worth testing is the part a test can reach without a
/// device.
///
/// ## Why any of this exists
///
/// `completions` records the days something was done. `commitments.days`
/// records the days it was meant to be done. Until this file, nothing put the
/// two together, and the cost was visible: `UserRepository.currentStreakFor`
/// counts consecutive *calendar* days, so a collection committed to Fridays
/// alone can never show a run longer than one. It is not that the user keeps
/// breaking it. It is that the question was wrong.
///
/// So the unit of a run here is a **due day**, not a day. Saturday is not a
/// miss for a Friday wird; it is not an anything.
library;

import 'commitment.dart';
import 'date_key.dart';

/// How far back a run is walked before giving up.
///
/// Twenty years of daily practice is a generous ceiling, and it bounds the
/// walk in [dueStreak] and in `DriftUserRepository._streakThrough`, which
/// share it deliberately: two caps that could drift apart would be two answers
/// to the same question.
///
/// It counts **days walked**, not days counted. Under a Friday-only mask the
/// walk passes seven days for every one it counts, so a cap on the count would
/// mean something different depending on the mask.
const int maxStreakDays = 366 * 20;

/// How many weeks the tracker's chart looks back over.
///
/// Fixed rather than fitted to the screen: a chart whose x-range moves with
/// the width of the phone cannot be compared against itself.
const int trackerWeeks = 12;

/// What one day was, for the scope being shown.
enum DayState {
  /// Done. Whether or not it was due — see [DueDays.stateOf].
  completed,

  /// Due, over, and not done.
  ///
  /// Nothing draws this. It is here because the denominators need to know the
  /// difference between a day that was missed and a day that never came round,
  /// and because a name is better than a bool nobody can read.
  missed,

  /// Never came round: an off day for this commitment, or no commitment at all.
  notDue,

  /// Today, or later. Nothing to say about it yet.
  future,

  /// Before this scope began — see [DueDays.start].
  ///
  /// Distinct from [notDue] on purpose. Folding the two together would put
  /// days that predate the collection into the denominator of "x of y days it
  /// came round", and that fraction would then be a lie.
  beforeStart,
}

/// Which days count for a scope, and from when.
///
/// One object rather than three functions taking the same four arguments: the
/// run, the weeks and the weekdays all have to agree about what "due" means,
/// and three separate implementations of that rule is three chances for them
/// to disagree.
final class DueDays {
  DueDays({
    required this.completed,
    required this.days,
    required this.start,
    required this.today,
  }) : firstCompleted = completed.isEmpty
           ? null
           : completed.reduce(
               (String a, String b) => a.compareTo(b) <= 0 ? a : b,
             );

  /// The `YYYY-MM-DD` days something was completed on, over all of history.
  final Set<String> completed;

  /// The weekdays this comes round on, or null for a scope that has no due
  /// rule at all.
  ///
  /// Null and [Weekdays.everyDay] are **not** the same thing, and passing the
  /// latter as a stand-in for the former is the mistake this nullability
  /// exists to prevent. "Everything" — and a collection with no commitment —
  /// has nothing it was supposed to do, so it cannot miss; a collection
  /// committed to every day can. With null, [missed] is unreachable and
  /// [dueStreak] falls back to counting calendar days, which is exactly what
  /// `currentStreakFor` already does.
  final Weekdays? days;

  /// The first day anything was due. Days before it are [DayState.beforeStart].
  ///
  /// Null for a scope with no beginning worth naming.
  final String? start;

  /// The device's local day, from the one clock.
  final String today;

  /// The earliest day in [completed], or null when there are none.
  final String? firstCompleted;

  /// Whether [key] falls on a weekday this comes round on.
  ///
  /// Only the mask. It says nothing about whether the day is over, whether it
  /// predates [start], or whether it was done.
  bool fallsOnDueWeekday(String key) => days?.contains(weekdayOf(key)) ?? false;

  /// Whether [key] is a day this scope was due on **and which is over**.
  ///
  /// This is the denominator everywhere: the weeks, the weekday bars, the
  /// sentence under the count. Today is deliberately excluded even when it is
  /// a due day — it still has hours left in it, and counting it as owed would
  /// have every figure on the screen dip at midnight and recover by evening.
  /// A completion logged today still counts in the numerator, so today can
  /// only ever help.
  bool countedAsDue(String key) {
    if (key.compareTo(today) >= 0) return false;
    final String? start = this.start;
    if (start != null && key.compareTo(start) < 0) return false;
    return fallsOnDueWeekday(key);
  }

  /// What [key] was.
  ///
  /// [DayState.completed] is tested first, and that order is load-bearing: the
  /// player does not consult the weekday mask, so a wird committed to Fridays
  /// can be — and is — recited on a Tuesday. Asking "was it due?" first would
  /// answer [DayState.notDue] and drop a real completion out of the weekday
  /// tallies without leaving a trace.
  DayState stateOf(String key) {
    if (completed.contains(key)) return DayState.completed;
    if (key.compareTo(today) >= 0) return DayState.future;

    final String? start = this.start;
    if (start != null && key.compareTo(start) < 0) return DayState.beforeStart;

    return fallsOnDueWeekday(key) ? DayState.missed : DayState.notDue;
  }

  /// Bounds are plain string comparisons throughout, because `date_key` is
  /// `YYYY-MM-DD` and lexicographic order is chronological order. The
  /// repository's own queries already bank on this.
  @override
  String toString() =>
      'DueDays(${completed.length} days, ${days ?? 'no rule'}, from $start)';
}

/// Consecutive **due** days up to today on which this scope was completed.
///
/// Three rules, and the first two are inherited from the calendar-day streak
/// this replaces:
///
/// - Today not being done does not break a run. The day is not over.
/// - A day with no completion, which was due, ends the run.
/// - A day it never came round on is passed over. It neither counts toward the
///   run nor breaks it — which is the whole point, and the reason a Friday
///   wird can finally show a run longer than one.
int dueStreak(
  DueDays due, {
  required DateTime now,
  int maxDays = maxStreakDays,
}) {
  final Weekdays? days = due.days;

  // A stored zero mask never comes round at all, so the answer is zero and
  // there is no reason to walk twenty years of days to find that out. It is
  // not reachable from the picker, which refuses to leave a commitment with no
  // day selected, but a stored value has to mean something.
  if (days != null && days.isEmpty) return 0;
  if (due.completed.isEmpty) return 0;

  int streak = 0;
  // Bounded by days walked. Under a sparse mask the walk covers seven days for
  // every one it counts, so this is the honest thing to cap.
  for (int offset = 0; offset <= maxDays; offset++) {
    final String key = dateKeyDaysBefore(now, offset);

    if (due.completed.contains(key)) {
      streak++;
      continue;
    }
    // Today, still in progress.
    if (offset == 0) continue;
    // Never came round. Not a gap in the run, just not part of it.
    if (days != null && !days.contains(weekdayOf(key))) continue;

    // A due day that was not done. The run ends here — and so does the walk,
    // whether or not this day predates [DueDays.start]: there is nothing
    // further back that could still be consecutive with today.
    break;
  }
  return streak;
}

/// One week of the tracker's chart.
final class WeekPoint {
  const WeekPoint({
    required this.startKey,
    required this.done,
    required this.due,
    required this.hasData,
  });

  /// The `YYYY-MM-DD` day the week starts on, in the reader's own first-day
  /// convention.
  final String startKey;

  /// Days completed in this week.
  final int done;

  /// Days it was due — zero for a scope with no due rule.
  final int due;

  /// Whether this week is worth plotting.
  ///
  /// False for a week that ended before the first completion ever recorded.
  /// Such a week really did have zero days in it, and plotting it as a zero
  /// would draw a dip the reader never lived through — the app inventing a
  /// failure out of not having existed yet.
  final bool hasData;

  @override
  String toString() => 'WeekPoint($startKey $done/$due)';
}

/// The last [weeks] **completed** weeks, oldest first.
///
/// The week in progress is not among them. Plotted at its running total it
/// would read as a collapse every Monday and a recovery every Sunday, and the
/// two conventions for drawing it otherwise — a dashed segment, a hollow
/// marker — both say "unfinished", which is a half-step toward the countdown
/// this app does not do. Today is fully visible on the calendar above the
/// chart; it does not need saying twice.
///
/// [firstWeekday] is a [DateTime] weekday constant. Weeks bucket from it so
/// that the chart's columns and the calendar's rows begin on the same day.
List<WeekPoint> weeklySeries(
  DueDays due, {
  required DateTime now,
  required int firstWeekday,
  int weeks = trackerWeeks,
}) {
  final DateTime local = now.isUtc ? now.toLocal() : now;

  // How far into its own week today is. The same expression `MonthGrid` uses
  // for the blank cells before the 1st, so the two agree by construction
  // rather than by both being right.
  final int intoWeek =
      (local.weekday - firstWeekday + DateTime.daysPerWeek) %
      DateTime.daysPerWeek;

  final String? first = due.firstCompleted;

  return <WeekPoint>[
    for (int week = weeks; week >= 1; week--)
      () {
        // Week 1 is the most recent one that is over: it ends the day before
        // the current week began.
        final int startOffset = intoWeek + week * DateTime.daysPerWeek;
        final String lastKey = dateKeyDaysBefore(
          now,
          startOffset - (DateTime.daysPerWeek - 1),
        );

        int done = 0;
        int dueCount = 0;
        for (int i = 0; i < DateTime.daysPerWeek; i++) {
          // Every day is an offset from one `now`, stepped through
          // `dateKeyDaysBefore`. Parsing `startKey` and adding a day seven
          // times would land twice on the same date across a spring-forward.
          final String key = dateKeyDaysBefore(now, startOffset - i);
          if (due.completed.contains(key)) done++;
          if (due.countedAsDue(key)) dueCount++;
        }

        return WeekPoint(
          startKey: dateKeyDaysBefore(now, startOffset),
          done: done,
          due: dueCount,
          hasData: first != null && lastKey.compareTo(first) >= 0,
        );
      }(),
  ];
}

/// How one weekday has gone.
final class WeekdayTally {
  const WeekdayTally({required this.done, required this.due});

  final int done;

  /// Times this weekday came round. Zero for a scope with no due rule, and for
  /// a weekday outside the mask.
  final int due;

  /// The share of this weekday that was kept, or null when it never came round.
  ///
  /// The bars are drawn from this rather than from [done] against the largest
  /// tally, because under a sparse mask the largest tally is the only one
  /// there is: a Friday-only wird would show one full bar and six empty ones
  /// and have told the reader nothing.
  double? get rate => due == 0 ? null : done / due;

  @override
  String toString() => 'WeekdayTally($done/$due)';
}

/// Each weekday over the last [days] days, indexed `DateTime.monday - 1` to
/// `DateTime.sunday - 1`.
///
/// ISO order, not the reader's: this is storage, and the column order is a
/// question for the widget that draws it — the same split [Weekdays] makes.
///
/// The window matches the chart's, so the two sections describe the same
/// stretch of time. Today is included in [WeekdayTally.done] if it was
/// completed but never in [WeekdayTally.due], which is the same generous
/// direction [DueDays.countedAsDue] takes everywhere else.
List<WeekdayTally> weekdayTallies(
  DueDays due, {
  required DateTime now,
  int days = trackerWeeks * DateTime.daysPerWeek,
}) {
  final List<int> done = List<int>.filled(DateTime.daysPerWeek, 0);
  final List<int> dueCount = List<int>.filled(DateTime.daysPerWeek, 0);

  for (int offset = 0; offset < days; offset++) {
    final String key = dateKeyDaysBefore(now, offset);
    final int index = weekdayOf(key) - 1;
    if (due.completed.contains(key)) done[index]++;
    if (due.countedAsDue(key)) dueCount[index]++;
  }

  return <WeekdayTally>[
    for (int i = 0; i < DateTime.daysPerWeek; i++)
      WeekdayTally(done: done[i], due: dueCount[i]),
  ];
}

/// The whole history, in the two numbers worth stating.
///
/// A count and a date, and nothing derived from them that could go down — no
/// rate, no average, no best. A number that can fall is a number to be anxious
/// about, and the footer of this screen is the last place that belongs.
final class TrackerTotals {
  const TrackerTotals({required this.days, required this.firstDay});

  factory TrackerTotals.of(DueDays due) =>
      TrackerTotals(days: due.completed.length, firstDay: due.firstCompleted);

  /// Days on which this scope was completed, ever.
  final int days;

  /// The earliest of them, or null when there are none.
  final String? firstDay;

  bool get isEmpty => days == 0;

  @override
  String toString() => 'TrackerTotals($days days since $firstDay)';
}

/// The earlier of two day keys, either of which may be null.
///
/// The tracker's anchor. A collection's history starts at the earlier of when
/// it was committed and when it was first completed, and the reason is that
/// neither alone survives contact with how the app is used: `uncommit` deletes
/// the row outright, so re-committing mints a fresh `created_at` and would
/// throw away months of real practice, while a collection committed this
/// morning and not yet done has no completion to anchor to. The earlier of the
/// two is monotone and survives both.
String? earlierDayKey(String? a, String? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.compareTo(b) <= 0 ? a : b;
}
