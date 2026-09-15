import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/commitment.dart';
import 'package:wirdi/domain/date_key.dart';
import 'package:wirdi/domain/tracker_stats.dart';

/// The tracker's arithmetic, and the one thing it exists to get right: a run
/// is counted in days the collection came round on, not in days.
void main() {
  // A Tuesday, so that "today" is not itself a Friday in the tests that turn
  // on Fridays.
  final DateTime now = DateTime(2026, 9, 15, 10, 30);
  const String today = '2026-09-15';

  DueDays due({
    Set<String> completed = const <String>{},
    Weekdays? days,
    String? start,
  }) => DueDays(completed: completed, days: days, start: start, today: today);

  /// The `date_key`s of the [count] days up to and including [now].
  Set<String> lastDays(int count) => <String>{
    for (int i = 0; i < count; i++) dateKeyDaysBefore(now, i),
  };

  /// Every Friday in the [weeks] weeks before [now], most recent first.
  List<String> fridays(int weeks) {
    // 15 September 2026 is a Tuesday; the Friday before it is four days back.
    return <String>[
      for (int i = 0; i < weeks; i++)
        dateKeyDaysBefore(now, 4 + i * DateTime.daysPerWeek),
    ];
  }

  final Weekdays fridayOnly = Weekdays.of(<int>[DateTime.friday]);

  group('dueStreak', () {
    test('with no due rule, counts consecutive calendar days', () {
      // The reading `currentStreakFor` already gives, which is the one the
      // app keeps for a scope that was never committed to anything.
      expect(dueStreak(due(completed: lastDays(5)), now: now), 5);
    });

    test('with an every-day mask, agrees with the calendar-day count', () {
      final Set<String> completed = lastDays(5);
      expect(
        dueStreak(
          due(completed: completed, days: Weekdays.everyDay),
          now: now,
        ),
        dueStreak(due(completed: completed), now: now),
      );
    });

    test('today not being done does not break a run', () {
      // Yesterday and the day before, nothing yet today. The day is not over.
      final Set<String> completed = <String>{
        dateKeyDaysBefore(now, 1),
        dateKeyDaysBefore(now, 2),
      };
      expect(dueStreak(due(completed: completed), now: now), 2);
    });

    test('a missed day that was due ends the run', () {
      final Set<String> completed = <String>{
        dateKeyDaysBefore(now, 1),
        // Nothing two days ago.
        dateKeyDaysBefore(now, 3),
      };
      expect(dueStreak(due(completed: completed), now: now), 1);
    });

    test('counts Fridays for a Friday-only commitment', () {
      // The case the whole file exists for. Eight Fridays kept, and seven
      // Saturdays, Sundays and so on in between that were never owed.
      expect(
        dueStreak(
          due(completed: fridays(8).toSet(), days: fridayOnly),
          now: now,
        ),
        8,
      );
    });

    test('a Friday-only run is not broken by the days between', () {
      // The bug this replaces: _streakThrough walks calendar days, so this
      // same history could never read higher than one.
      final int calendarDays = dueStreak(
        due(completed: fridays(8).toSet()),
        now: now,
      );
      expect(calendarDays, 0, reason: 'no Friday is within a day of Tuesday');
      expect(
        dueStreak(
          due(completed: fridays(8).toSet(), days: fridayOnly),
          now: now,
        ),
        8,
      );
    });

    test('a missed Friday ends a Friday-only run', () {
      final List<String> kept = fridays(8)..removeAt(2);
      expect(
        dueStreak(
          due(completed: kept.toSet(), days: fridayOnly),
          now: now,
        ),
        2,
      );
    });

    test('an empty mask is zero without walking for it', () {
      // Not reachable from the picker, which refuses to leave a commitment
      // with no day selected. A stored zero still has to mean something.
      expect(
        dueStreak(
          due(completed: lastDays(30), days: const Weekdays.fromMask(0)),
          now: now,
        ),
        0,
      );
    });

    test('no history at all is zero', () {
      expect(dueStreak(due(), now: now), 0);
    });

    test('is bounded by days walked, not by days counted', () {
      // Under a sparse mask the walk passes seven days for every one it
      // counts, so a cap on the count would mean something different
      // depending on the mask. Two years of Fridays inside a two-year cap.
      expect(
        dueStreak(
          due(completed: fridays(104).toSet(), days: fridayOnly),
          now: now,
          maxDays: 366 * 2,
        ),
        104,
      );
    });
  });

  group('stateOf', () {
    test('a completion counts even on a day it was not due', () {
      // The player does not consult the mask, so a Friday wird recited on a
      // Tuesday is a real completion. Asking "was it due?" first would answer
      // notDue and lose it.
      final String tuesday = dateKeyDaysBefore(now, 7);
      expect(
        due(completed: <String>{tuesday}, days: fridayOnly).stateOf(tuesday),
        DayState.completed,
      );
    });

    test('a due day that was missed is missed', () {
      expect(due(days: fridayOnly).stateOf(fridays(1).single), DayState.missed);
    });

    test('a day the mask does not cover never came round', () {
      expect(
        due(days: fridayOnly).stateOf(dateKeyDaysBefore(now, 1)),
        DayState.notDue,
      );
    });

    test('with no due rule, nothing is ever missed', () {
      expect(due().stateOf(dateKeyDaysBefore(now, 1)), DayState.notDue);
    });

    test('today is future until it is done', () {
      expect(due(days: Weekdays.everyDay).stateOf(today), DayState.future);
      expect(
        due(completed: <String>{today}, days: Weekdays.everyDay).stateOf(today),
        DayState.completed,
      );
    });

    test('tomorrow is future', () {
      expect(
        due(days: Weekdays.everyDay).stateOf('2026-09-16'),
        DayState.future,
      );
    });

    test('a due day before the start is not a miss', () {
      // Days that predate the collection are not failures, and folding them
      // into notDue would put them in the denominator of "x of y days it came
      // round" instead.
      final DueDays d = due(days: fridayOnly, start: '2026-09-01');
      expect(d.stateOf('2026-08-28'), DayState.beforeStart);
      expect(d.stateOf('2026-09-04'), DayState.missed);
    });
  });

  group('countedAsDue', () {
    test('excludes today, which still has hours left in it', () {
      expect(due(days: Weekdays.everyDay).countedAsDue(today), isFalse);
      expect(
        due(days: Weekdays.everyDay).countedAsDue(dateKeyDaysBefore(now, 1)),
        isTrue,
      );
    });

    test('excludes days before the start', () {
      final DueDays d = due(days: Weekdays.everyDay, start: '2026-09-10');
      expect(d.countedAsDue('2026-09-09'), isFalse);
      expect(d.countedAsDue('2026-09-10'), isTrue);
    });

    test('is never true without a due rule', () {
      expect(due().countedAsDue(dateKeyDaysBefore(now, 1)), isFalse);
    });
  });

  group('weeklySeries', () {
    test('returns the asked-for number of weeks, oldest first', () {
      final List<WeekPoint> weeks = weeklySeries(
        due(completed: lastDays(90)),
        now: now,
        firstWeekday: DateTime.monday,
      );
      expect(weeks, hasLength(trackerWeeks));
      expect(
        weeks.map((WeekPoint w) => w.startKey).toList(),
        List<String>.of(weeks.map((WeekPoint w) => w.startKey))..sort(),
      );
    });

    test('does not include the week in progress', () {
      // Today is a Tuesday, so the current Monday-first week began on the
      // 14th. The most recent week the chart shows must end before it.
      final List<WeekPoint> weeks = weeklySeries(
        due(completed: lastDays(90)),
        now: now,
        firstWeekday: DateTime.monday,
      );
      expect(weeks.last.startKey, '2026-09-07');
      expect(weeks.last.done, DateTime.daysPerWeek);
    });

    test('buckets from the reader\'s own first weekday', () {
      final List<WeekPoint> monday = weeklySeries(
        due(completed: lastDays(90)),
        now: now,
        firstWeekday: DateTime.monday,
      );
      final List<WeekPoint> sunday = weeklySeries(
        due(completed: lastDays(90)),
        now: now,
        firstWeekday: DateTime.sunday,
      );
      expect(monday.last.startKey, '2026-09-07');
      expect(sunday.last.startKey, '2026-09-06');
    });

    test('every week is seven days, across a month and a year boundary', () {
      final List<WeekPoint> weeks = weeklySeries(
        due(completed: lastDays(400)),
        now: DateTime(2026, 1, 6, 9),
        firstWeekday: DateTime.monday,
      );
      // Every day completed, so a week that is not seven means the bucketing
      // dropped or double-counted a day somewhere across 31 December.
      for (final WeekPoint week in weeks) {
        expect(week.done, DateTime.daysPerWeek, reason: week.startKey);
      }
      expect(weeks.map((WeekPoint w) => w.startKey), contains('2025-12-29'));
    });

    test('weeks are contiguous and never repeat a start', () {
      final List<WeekPoint> weeks = weeklySeries(
        due(),
        // Late March, so the series walks back across a spring-forward in the
        // timezones that have one. Stepping from local midnight would land
        // twice on the same date.
        now: DateTime(2026, 3, 31, 9),
        firstWeekday: DateTime.monday,
      );
      final List<String> starts = weeks
          .map((WeekPoint w) => w.startKey)
          .toList();
      expect(starts.toSet(), hasLength(trackerWeeks));
      expect(starts, List<String>.of(starts)..sort());
    });

    test('a week that ended before the first completion has no data', () {
      // It really did have zero days in it. Plotting it as a zero would draw
      // a dip the reader never lived through.
      final List<WeekPoint> weeks = weeklySeries(
        due(completed: lastDays(14)),
        now: now,
        firstWeekday: DateTime.monday,
      );
      expect(weeks.first.hasData, isFalse);
      expect(weeks.last.hasData, isTrue);
      expect(weeks.where((WeekPoint w) => w.hasData), isNotEmpty);
    });

    test('counts due days against the mask, not against seven', () {
      final List<WeekPoint> weeks = weeklySeries(
        due(completed: fridays(20).toSet(), days: fridayOnly),
        now: now,
        firstWeekday: DateTime.monday,
      );
      // One Friday a week owed, and one kept.
      expect(weeks.last.due, 1);
      expect(weeks.last.done, 1);
    });

    test('a scope with no due rule owes nothing', () {
      final List<WeekPoint> weeks = weeklySeries(
        due(completed: lastDays(90)),
        now: now,
        firstWeekday: DateTime.monday,
      );
      expect(weeks.every((WeekPoint w) => w.due == 0), isTrue);
    });
  });

  group('weekdayTallies', () {
    test('is indexed Monday first, whatever the reader starts a week on', () {
      final List<WeekdayTally> tallies = weekdayTallies(
        due(completed: fridays(6).toSet(), days: fridayOnly),
        now: now,
      );
      expect(tallies, hasLength(DateTime.daysPerWeek));
      expect(tallies[DateTime.friday - 1].done, 6);
      expect(tallies[DateTime.monday - 1].done, 0);
    });

    test('a weekday outside the mask never came round', () {
      // Every Friday in the window, so the rate is a clean one rather than a
      // fraction of the Fridays the window happens to hold.
      final List<WeekdayTally> tallies = weekdayTallies(
        due(completed: fridays(trackerWeeks).toSet(), days: fridayOnly),
        now: now,
      );
      expect(tallies[DateTime.monday - 1].due, 0);
      expect(tallies[DateTime.monday - 1].rate, isNull);
      expect(tallies[DateTime.friday - 1].rate, 1);
    });

    test('counts every day the window covers, not only the ones kept', () {
      // Half the Fridays in the window, which is half the Fridays owed.
      final List<WeekdayTally> tallies = weekdayTallies(
        due(completed: fridays(trackerWeeks ~/ 2).toSet(), days: fridayOnly),
        now: now,
      );
      expect(tallies[DateTime.friday - 1].due, trackerWeeks);
      expect(tallies[DateTime.friday - 1].rate, 0.5);
    });

    test('a rate is the share kept, not the share of the busiest day', () {
      // Fridays kept, Mondays owed and missed. Normalising against the largest
      // tally would draw Friday full and say nothing; the rate says one day
      // was kept and the other was not.
      final Weekdays both = Weekdays.of(<int>[
        DateTime.monday,
        DateTime.friday,
      ]);
      final List<WeekdayTally> tallies = weekdayTallies(
        due(completed: fridays(trackerWeeks).toSet(), days: both),
        now: now,
      );
      expect(tallies[DateTime.friday - 1].rate, 1);
      expect(tallies[DateTime.monday - 1].rate, 0);
    });
  });

  group('TrackerTotals', () {
    test('counts every day and names the first', () {
      final TrackerTotals totals = TrackerTotals.of(
        due(completed: lastDays(3)),
      );
      expect(totals.days, 3);
      expect(totals.firstDay, dateKeyDaysBefore(now, 2));
      expect(totals.isEmpty, isFalse);
    });

    test('is empty with no history', () {
      expect(TrackerTotals.of(due()).isEmpty, isTrue);
      expect(TrackerTotals.of(due()).firstDay, isNull);
    });
  });

  group('earlierDayKey', () {
    test('takes the earlier of two days', () {
      expect(earlierDayKey('2026-09-01', '2026-03-04'), '2026-03-04');
      expect(earlierDayKey('2026-03-04', '2026-09-01'), '2026-03-04');
    });

    test('takes whichever one there is', () {
      // A collection committed this morning and not yet done has no
      // completion to anchor to; one practised for months before it was ever
      // committed has no commitment older than its history.
      expect(earlierDayKey(null, '2026-03-04'), '2026-03-04');
      expect(earlierDayKey('2026-03-04', null), '2026-03-04');
      expect(earlierDayKey(null, null), isNull);
    });
  });
}
