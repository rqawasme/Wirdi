import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/repositories.dart';
import 'player_haptics.dart';

/// The tasbih tab's counter, as a plain object.
///
/// The same shape as `WirdPlayer` and a fraction of the size, for the same
/// reason: counting, undo, reset and when a write happens are all testable by
/// calling methods, and the screen is a `ListenableBuilder` over this. Nothing
/// here knows what a widget is.
///
/// ## What it counts
///
/// Taps. Not repetitions of anything in particular — there is no dhikr behind
/// this number and no target in front of it. The count runs until somebody
/// resets it, which is the whole model, and it is deliberately the whole
/// model: a free counter is what a hand-held tasbih is, and every feature that
/// would make it more than that (a target, a name, a history) is a product
/// decision this screen does not have to make in order to be useful.
///
/// ## Writes
///
/// The count is persisted under [settingKey], so closing the app is not a
/// reset — the counter says it runs until you reset it, and a process that
/// went away in the night is not the user resetting it.
///
/// A tap starts a [saveDebounce] timer if one is not already running, which is
/// a rate limiter rather than a trailing debounce: a long run is written
/// through every half second instead of writing nothing until the thumb stops.
/// A reset is written immediately, because it is the one change somebody would
/// be upset to see come back.
///
/// Every write goes through one chain, so they land in the order they were
/// made — a tap queued half a second ago must not land after a reset and
/// resurrect the count it cleared.
class TasbihCounter extends ChangeNotifier {
  TasbihCounter({
    required UserRepository user,
    required PlayerHaptics haptics,
    int initialCount = 0,
    this.saveDebounce = defaultSaveDebounce,
  }) : _user = user,
       _haptics = haptics,
       // Clamped rather than trusted: it is a plain integer in a row this app
       // is not the only future writer of, and a negative count would render
       // as a minus sign nothing on the screen could get rid of.
       _count = initialCount < 0 ? 0 : initialCount;

  /// Reads the stored count and opens a counter on it.
  static Future<TasbihCounter> open({
    required UserRepository user,
    required PlayerHaptics haptics,
    Duration saveDebounce = defaultSaveDebounce,
  }) async {
    final String? stored = await user.setting(settingKey);
    return TasbihCounter(
      user: user,
      haptics: haptics,
      // A key that has never been written and a key that cannot be parsed
      // behave the same way: the counter starts at nothing.
      initialCount: int.tryParse(stored ?? '') ?? 0,
      saveDebounce: saveDebounce,
    );
  }

  /// Where the count lives in `user.db`'s `settings` table.
  ///
  /// Owned here rather than by `SettingKeys` because nothing else reads it:
  /// it is not part of `WirdiSettings`, and putting it there would rebuild
  /// every widget watching the settings on every tap of a counter.
  static const String settingKey = 'tasbih.count';

  /// Roughly half a second, as in the player. Short enough that a crash costs
  /// a tap or two, long enough that a fast thumb is not writing to SQLite on
  /// every one.
  static const Duration defaultSaveDebounce = Duration(milliseconds: 500);

  final UserRepository _user;
  final PlayerHaptics _haptics;

  /// How long a burst of counting can go unwritten. See the class comment.
  final Duration saveDebounce;

  int _count;
  Timer? _saveTimer;
  bool _pendingSave = false;
  Future<void> _writes = Future<void>.value();

  int get count => _count;

  /// Nothing to take back at zero, and nothing to reset either.
  bool get isEmpty => _count == 0;

  /// Every write made so far, in order. Awaiting it waits for the ones already
  /// queued, not for the debounce timer — [flush] is what forces that.
  @visibleForTesting
  Future<void> get writes => _writes;

  /// Whether a count change is sitting behind the debounce timer.
  @visibleForTesting
  bool get hasPendingSave => _pendingSave;

  /// One tap.
  void increment() {
    _count++;
    _haptics.tick();
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

  /// Back to zero.
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
