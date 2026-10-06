import 'dart:async';

import 'package:flutter/foundation.dart';

import '../collections/dhikr_editing.dart' show maxDhikrCount;
import '../domain/repositories.dart';
import 'player_haptics.dart';

/// The tasbih tab's counter, as a plain object.
///
/// The same shape as `WirdPlayer` and a fraction of the size, for the same
/// reason: counting, undo, reset, the goal and when a write happens are all
/// testable by calling methods, and the screen is a `ListenableBuilder` over
/// this. Nothing here knows what a widget is.
///
/// ## What it counts
///
/// Taps. Not repetitions of anything in particular — there is no dhikr behind
/// this number. The count runs until somebody resets it, which is a hand-held
/// tasbih's whole model and still this one's.
///
/// ## The goal
///
/// Optional, and a marker rather than an ending. With a goal of 33 the tap
/// that lands on 33 knocks twice instead of clicking, and so does the tap that
/// lands on 66, and on 99: every multiple, the way the marker bead on a string
/// of beads comes round under the thumb each time. Nothing stops there. The
/// count carries on past the goal exactly as it ran up to it, and a reset
/// takes the count to zero and leaves the goal where it is, ready for the next
/// round.
///
/// Only a tap lands on the goal. Undoing back onto a multiple is not reaching
/// it, and setting a goal at or below the count that is already there is not
/// reaching it either — both are the number being moved, not counted.
///
/// ## Writes
///
/// The count is persisted under [settingKey] and the goal under [goalKey], so
/// closing the app is not a reset — the counter says it runs until you reset
/// it, and a process that went away in the night is not the user resetting it.
///
/// A tap starts a [saveDebounce] timer if one is not already running, which is
/// a rate limiter rather than a trailing debounce: a long run is written
/// through every half second instead of writing nothing until the thumb stops.
/// A reset is written immediately, because it is the one change somebody would
/// be upset to see come back, and so is a new goal, which is chosen once rather
/// than in bursts.
///
/// Every write goes through one chain, so they land in the order they were
/// made — a tap queued half a second ago must not land after a reset and
/// resurrect the count it cleared.
class TasbihCounter extends ChangeNotifier {
  TasbihCounter({
    required UserRepository user,
    required PlayerHaptics haptics,
    int initialCount = 0,
    int? initialGoal,
    this.saveDebounce = defaultSaveDebounce,
  }) : _user = user,
       _haptics = haptics,
       // Clamped rather than trusted: it is a plain integer in a row this app
       // is not the only future writer of, and a negative count would render
       // as a minus sign nothing on the screen could get rid of.
       _count = initialCount < 0 ? 0 : initialCount,
       // Dropped rather than clamped: a goal nothing could have set is not
       // one somebody chose, and the nearest one that could be set is not one
       // they chose either.
       _goal = isValidGoal(initialGoal) ? initialGoal : null;

  /// Reads the stored count and goal and opens a counter on them.
  static Future<TasbihCounter> open({
    required UserRepository user,
    required PlayerHaptics haptics,
    Duration saveDebounce = defaultSaveDebounce,
  }) async {
    final String? count = await user.setting(settingKey);
    final String? goal = await user.setting(goalKey);
    return TasbihCounter(
      user: user,
      haptics: haptics,
      // A key that has never been written and a key that cannot be parsed
      // behave the same way: the counter starts at nothing, with no goal.
      initialCount: int.tryParse(count ?? '') ?? 0,
      initialGoal: int.tryParse(goal ?? ''),
      saveDebounce: saveDebounce,
    );
  }

  /// Where the count lives in `user.db`'s `settings` table.
  ///
  /// Owned here rather than by `SettingKeys` because nothing else reads it:
  /// it is not part of `WirdiSettings`, and putting it there would rebuild
  /// every widget watching the settings on every tap of a counter.
  static const String settingKey = 'tasbih.count';

  /// Where the goal lives, beside the count and for the same reason.
  ///
  /// No goal is stored as an empty value: the repository has no delete, and
  /// an empty value reads back the way a key never written does.
  static const String goalKey = 'tasbih.goal';

  /// The largest goal there is: the largest count a dhikr can have, and held
  /// the same way. The goal sheet's field takes the shared
  /// `countInputFormatters`, so it cannot hold a goal this would refuse.
  static const int maxGoal = maxDhikrCount;

  /// Whether [goal] is one the goal sheet could have set.
  static bool isValidGoal(int? goal) =>
      goal != null && goal >= 1 && goal <= maxGoal;

  /// Roughly half a second, as in the player. Short enough that a crash costs
  /// a tap or two, long enough that a fast thumb is not writing to SQLite on
  /// every one.
  static const Duration defaultSaveDebounce = Duration(milliseconds: 500);

  final UserRepository _user;
  final PlayerHaptics _haptics;

  /// How long a burst of counting can go unwritten. See the class comment.
  final Duration saveDebounce;

  int _count;
  int? _goal;
  int _goalArrivals = 0;
  Timer? _saveTimer;
  bool _pendingSave = false;
  Future<void> _writes = Future<void>.value();

  int get count => _count;

  /// Nothing to take back at zero, and nothing to reset either.
  bool get isEmpty => _count == 0;

  /// The goal, or null for a counter with none — which is the counter this
  /// tab always was.
  int? get goal => _goal;

  /// How many times the count has gone past the goal: 0 short of it, 1 from
  /// the goal up to just short of twice it, and so on.
  int get goalsReached {
    final int? goal = _goal;
    return goal == null ? 0 : _count ~/ goal;
  }

  /// How far into the current round the count is, from 0 to [goal], for the
  /// stripe. Zero with no goal.
  ///
  /// Exactly on a multiple it is the whole round, not none of it: the tap that
  /// lands on 33 fills the stripe, and the tap after it starts the next one.
  /// A stripe that emptied on the very tap that reached the goal would say the
  /// opposite of what the knock just said.
  int get roundTaps {
    final int? goal = _goal;
    if (goal == null) return 0;
    final int into = _count % goal;
    return into == 0 && _count > 0 ? goal : into;
  }

  /// How many taps, since this counter was opened, have landed on the goal or
  /// a multiple of it. The screen marks the moment each time this moves; it
  /// does not move for anything but a tap.
  int get goalArrivals => _goalArrivals;

  /// Every write made so far, in order. Awaiting it waits for the ones already
  /// queued, not for the debounce timer — [flush] is what forces that.
  @visibleForTesting
  Future<void> get writes => _writes;

  /// Whether a count change is sitting behind the debounce timer.
  @visibleForTesting
  bool get hasPendingSave => _pendingSave;

  /// One tap.
  ///
  /// On the goal, or a multiple of it, the goal's two knocks fire instead of
  /// the click. Not both: two effects on one tap read as one muddy buzz rather
  /// than as an arrival, which is the player's rule for the end of a step.
  void increment() {
    _count++;
    final int? goal = _goal;
    if (goal != null && _count % goal == 0) {
      _goalArrivals++;
      _haptics.goalReached();
    } else {
      _haptics.tick();
    }
    _scheduleSave();
    notifyListeners();
  }

  /// Takes one tap back.
  ///
  /// People lose count, and on a screen that is one enormous tap target they
  /// also double-tap by accident. Without this the only repair for a count of
  /// thirty-four is starting the thirty-three again.
  void decrement() {
    if (_count == 0) return;
    _count--;
    _haptics.tick();
    _scheduleSave();
    notifyListeners();
  }

  /// Back to zero. The goal stays.
  ///
  /// Written immediately rather than behind the rate limiter: this is the
  /// change that would be worst to lose, and it happens once rather than in
  /// bursts.
  void reset() {
    if (_count == 0) return;
    _count = 0;
    _haptics.stepComplete();
    _saveNow();
    notifyListeners();
  }

  /// Sets the goal, or clears it with null.
  ///
  /// No haptic, even when the count already stands at or past the new goal:
  /// nothing was counted, so nothing was reached. The screen shows it as
  /// reached all the same, because it is.
  void setGoal(int? goal) {
    if (goal != null && !isValidGoal(goal)) {
      throw ArgumentError.value(goal, 'goal', 'must be from 1 to $maxGoal');
    }
    if (goal == _goal) return;
    _goal = goal;
    _enqueue(_writeGoal);
    notifyListeners();
  }

  /// Forces a pending count to disk and waits for every write. Called when the
  /// app is backgrounded, which is the moment before the process might not
  /// come back.
  Future<void> flush() {
    _cancelTimer();
    if (_pendingSave) {
      _pendingSave = false;
      _enqueue(_writeCount);
    }
    return _writes;
  }

  @override
  void dispose() {
    _cancelTimer();
    if (_pendingSave) {
      _pendingSave = false;
      // Started and not awaited: dispose cannot be async. It is one upsert
      // against a local database that outlives this object, so it lands.
      _enqueue(_writeCount);
    }
    super.dispose();
  }

  void _scheduleSave() {
    _pendingSave = true;
    // Not reset on each tap: this is a rate limiter, so continuous counting is
    // written through every saveDebounce rather than never.
    _saveTimer ??= Timer(saveDebounce, _onSaveTimer);
  }

  void _onSaveTimer() {
    _saveTimer = null;
    if (!_pendingSave) return;
    _pendingSave = false;
    _enqueue(_writeCount);
  }

  void _saveNow() {
    _cancelTimer();
    _pendingSave = false;
    _enqueue(_writeCount);
  }

  void _cancelTimer() {
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  /// Reads the count at write time rather than at schedule time, which is what
  /// makes coalescing correct: the last count is the one that matters.
  Future<void> _writeCount() => _user.setSetting(settingKey, '$_count');

  /// The same, for the goal: two changes in quick succession write the second
  /// twice rather than the first once and the second once, which lands in the
  /// same place.
  Future<void> _writeGoal() => _user.setSetting(goalKey, '${_goal ?? ''}');

  void _enqueue(Future<void> Function() write) {
    _writes = _writes.then((_) => write()).catchError((
      Object error,
      StackTrace stack,
    ) {
      // A failed write costs the count across a restart, not the session on
      // screen. Report it and keep the chain alive, or one failure silently
      // stops every write after it.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'wirdi',
          context: ErrorDescription('writing the tasbih count'),
        ),
      );
    });
  }
}
