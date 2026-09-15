import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What "now" is, so a test can put the calendar in a month of its choosing.
///
/// The app reads the clock in exactly one place, and this is it.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now, name: 'clock');

/// Which day the calendar starts a week on, as a `DateTime` weekday constant.
///
/// Overridden from [MaterialLocalizations] at the root of the tracker, so the
/// grid starts where the reader's locale starts it. Defaulted rather than
/// required so that the pure providers stay usable without a [BuildContext].
///
/// The override is deliberately in **one** place for the whole tab rather than
/// at each widget that needs it. The calendar, the weekly chart and the
/// weekday bars all bucket days by this, and two of them reading it from
/// different subtrees is how they would come to disagree about where a week
/// begins without anything looking wrong.
final Provider<int> firstWeekdayProvider = Provider<int>(
  (Ref ref) => DateTime.monday,
  name: 'firstWeekday',
);
