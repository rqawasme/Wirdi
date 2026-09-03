import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/collections/streak_calendar.dart';

/// The month grid the streak panel paints.
void main() {
  List<String?> cells(MonthGrid grid) => <String?>[
    for (final List<String?> week in grid.weeks) ...week,
  ];

  List<String> days(MonthGrid grid) =>
      cells(grid).whereType<String>().toList(growable: false);

  group('a month', () {
    test('holds exactly its own days, and none from either side', () {
      final MonthGrid february = MonthGrid.of(DateTime(2026, 2, 14));

      expect(february.year, 2026);
      expect(february.month, 2);
      expect(february.length, 28);
      expect(days(february).length, 28);
      expect(days(february).first, '2026-02-01');
      expect(days(february).last, '2026-02-28');

      // The corners are empty, not borrowed. A grid that showed 31 January in
      // the same colour as 1 February would invite the reader to count a
      // streak across a boundary the grid is not showing.
      expect(days(february), isNot(contains('2026-01-31')));
      expect(days(february), isNot(contains('2026-03-01')));
    });

    test('is padded to whole weeks, from the weekday it starts on', () {
      // 1 February 2026 is a Sunday.
      final MonthGrid fromMonday = MonthGrid.of(DateTime(2026, 2, 14));
      expect(
        fromMonday.weeks.every((List<String?> w) => w.length == 7),
        isTrue,
      );
      // Six blanks before it, so the month runs into a fifth week.
      expect(fromMonday.weeks.length, 5);
      expect(fromMonday.weeks.first.take(6), everyElement(isNull));
      expect(fromMonday.weeks.first.last, '2026-02-01');

      final MonthGrid fromSunday = MonthGrid.of(
        DateTime(2026, 2, 14),
        firstWeekday: DateTime.sunday,
      );
      // Starting the week on Sunday, February 2026 is four exact weeks.
      expect(fromSunday.weeks.length, 4);
      expect(fromSunday.weeks.first.first, '2026-02-01');
      expect(cells(fromSunday), everyElement(isNotNull));
    });

    test('ends where the month ends, across a year boundary', () {
      final MonthGrid december = MonthGrid.of(DateTime(2026, 12, 25));

      expect(december.length, 31);
      expect(days(december).last, '2026-12-31');
      expect(days(december), isNot(contains('2027-01-01')));
      expect(december.lastDay, DateTime(2026, 12, 31));
    });

    test('counts a leap February as twenty-nine', () {
      expect(MonthGrid.of(DateTime(2028, 2, 3)).length, 29);
      expect(days(MonthGrid.of(DateTime(2028, 2, 3))).last, '2028-02-29');

      expect(MonthGrid.of(DateTime(2026, 2, 3)).length, 28);
    });

    test('bounds the completions query to the month it shows', () {
      final MonthGrid september = MonthGrid.of(DateTime(2026, 9, 3));
      expect(september.firstDay, DateTime(2026, 9));
      expect(september.lastDay, DateTime(2026, 9, 30));
    });
  });

  group('the header', () {
    test('runs seven weekdays from the one the week starts on', () {
      expect(MonthGrid.of(DateTime(2026, 9)).weekdays, <int>[
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
        DateTime.sunday,
      ]);
      expect(
        MonthGrid.of(DateTime(2026, 9), firstWeekday: DateTime.sunday).weekdays,
        <int>[
          DateTime.sunday,
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
        ],
      );
    });

    test('refuses a first weekday that is not one', () {
      expect(
        () => MonthGrid.of(DateTime(2026, 9), firstWeekday: 0),
        throwsArgumentError,
      );
      expect(
        () => MonthGrid.of(DateTime(2026, 9), firstWeekday: 8),
        throwsArgumentError,
      );
    });
  });

  test('a cell reads back the day of the month it holds', () {
    expect(MonthGrid.dayOf('2026-09-03'), 3);
    expect(MonthGrid.dayOf('2026-09-30'), 30);
    expect(MonthGrid.dayOf(null), isNull);
  });
}
