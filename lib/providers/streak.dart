import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/streak_calendar.dart';
import '../domain/date_key.dart';
import '../domain/repositories.dart';
import 'data_providers.dart';

/// What "now" is, so a test can put the calendar in a month of its choosing.
///
/// The app reads the clock in exactly one place, and this is it.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now, name: 'clock');

/// Which day the calendar starts a week on, as a `DateTime` weekday constant.
///
/// Overridden from [MaterialLocalizations] where the panel is built, so the
/// grid starts where the reader's locale starts it. Defaulted rather than
/// required so that the pure provider stays usable without a [BuildContext].
final Provider<int> firstWeekdayProvider = Provider<int>(
  (Ref ref) => DateTime.monday,
  name: 'firstWeekday',
);

/// The streak count and the current month's completed days.
///
/// Deliberately two plain facts and nothing else. There is no tier here, no
/// "personal best", no "at risk", and nothing that gets louder as the number
/// grows — see the panel that renders it.
@immutable
final class StreakView {
  const StreakView({
    required this.streak,
    required this.month,
    required this.completed,
    required this.today,
  });

  /// Consecutive days up to today on which anything was completed. A day that
  /// is not over yet does not break it, which is the repository's rule.
  final int streak;

  final MonthGrid month;

  /// The `YYYY-MM-DD` keys inside [month] that were completed.
  final Set<String> completed;

  final String today;

  bool isCompleted(String? key) => key != null && completed.contains(key);
}

final FutureProvider<StreakView>
streakViewProvider = FutureProvider<StreakView>((Ref ref) async {
  final UserRepository user = ref.watch(userRepositoryProvider);
  final DateTime now = ref.watch(clockProvider)();
  final MonthGrid month = MonthGrid.of(
    now,
    firstWeekday: ref.watch(firstWeekdayProvider),
  );

  // Bounded to the month on screen: the whole history is not needed to paint
  // thirty-odd cells, and currentStreak already walks the days it needs.
  final List<String> days = await user.completionDates(
    from: month.firstDay,
    to: month.lastDay,
  );

  return StreakView(
    streak: await user.currentStreak(),
    month: month,
    completed: days.toSet(),
    today: dateKey(now),
  );
}, name: 'streakView');
