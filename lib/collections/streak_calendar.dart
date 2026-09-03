import '../domain/date_key.dart';

/// One calendar month, laid out as weeks of `YYYY-MM-DD` day keys.
///
/// Days from the months either side are not borrowed to fill the corners. A
/// grid that shows the 31st of last month in the same colour as the 1st of
/// this one invites the reader to count a streak across a boundary the grid is
/// not actually showing, so the padding cells are empty and stay empty.
///
/// Keys rather than [DateTime]s throughout: `completions.date_key` is a local
/// day written on the day it happened, and comparing it to a `DateTime` means
/// re-deriving a local date that a timezone move can change underneath. Two
/// strings either match or they do not.
final class MonthGrid {
  MonthGrid._({
    required this.year,
    required this.month,
    required this.firstWeekday,
    required this.weeks,
  });

  /// The month [day] falls in.
  ///
  /// [firstWeekday] is a `DateTime` weekday constant — [DateTime.monday]
  /// through [DateTime.sunday] — naming the column the week starts in. The
  /// panel takes it from [MaterialLocalizations] so the grid starts where the
  /// reader's locale starts it.
  factory MonthGrid.of(DateTime day, {int firstWeekday = DateTime.monday}) {
    if (firstWeekday < DateTime.monday || firstWeekday > DateTime.sunday) {
      throw ArgumentError.value(
        firstWeekday,
        'firstWeekday',
        'is not a DateTime weekday constant',
      );
    }
    final DateTime local = day.isUtc ? day.toLocal() : day;
    final int year = local.year;
    final int month = local.month;

    // Day zero of the next month is the last day of this one, which is the
    // whole leap-year rule and none of the arithmetic.
    final int length = DateTime(year, month + 1, 0).day;
    final int leading =
        (DateTime(year, month).weekday - firstWeekday + DateTime.daysPerWeek) %
        DateTime.daysPerWeek;

    final List<String?> cells = <String?>[
      ...List<String?>.filled(leading, null),
      for (int d = 1; d <= length; d++) dateKey(DateTime(year, month, d)),
    ];
    while (cells.length % DateTime.daysPerWeek != 0) {
      cells.add(null);
    }

    return MonthGrid._(
      year: year,
      month: month,
      firstWeekday: firstWeekday,
      weeks: List<List<String?>>.unmodifiable(<List<String?>>[
        for (int i = 0; i < cells.length; i += DateTime.daysPerWeek)
          List<String?>.unmodifiable(
            cells.sublist(i, i + DateTime.daysPerWeek),
          ),
      ]),
    );
  }

  final int year;
  final int month;
  final int firstWeekday;

  /// Rows of seven. A null cell is padding, not a day.
  final List<List<String?>> weeks;

  DateTime get firstDay => DateTime(year, month);

  DateTime get lastDay => DateTime(year, month + 1, 0);

  /// How many days the month has.
  int get length => lastDay.day;

  /// The weekday constants across the header, starting at [firstWeekday].
  List<int> get weekdays => <int>[
    for (int i = 0; i < DateTime.daysPerWeek; i++)
      (firstWeekday - 1 + i) % DateTime.daysPerWeek + 1,
  ];

  /// The day of the month a cell holds, or null for padding.
  static int? dayOf(String? key) =>
      key == null ? null : int.parse(key.substring(8));

  @override
  String toString() => 'MonthGrid($year-$month, ${weeks.length} weeks)';
}
