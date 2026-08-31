import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/playback_step.dart';
import '../domain/progress.dart';
import '../domain/repositories.dart';
import 'player_haptics.dart';

/// The counter, as a plain object.
///
/// Everything the wird player does to its position lives here and nothing here
/// knows what a widget is, so the whole of it — counting, undo across step
/// boundaries, resume, completion, when a write happens — is testable without
/// pumping a frame. The screen is a [ListenableBuilder] over this.
///
/// Position is [stepIndex] plus [currentCount] over
/// [ResolvedCollection.steps], which is exactly what [WirdProgress] stores.
/// Playback never looks at [ResolvedCollection.entries] except to fetch the
/// text for the step it is on, so a repeat block is nothing special here: it
/// arrived pre-flattened, with its round numbers already on the step.
///
/// ## Writes
///
/// Counting is a burst of taps and none of them individually matters; what
/// matters is that the position on disk is never far behind the thumb. So a
/// count change starts a [saveDebounce] timer if one is not already running —
/// a rate limiter rather than a trailing debounce, so a long tasbih run is
/// written through every half second instead of writing nothing until the user
/// stops. A step change, which is the position people actually resume from,
/// is written immediately.
///
/// Every write goes through one chain, so they land in the order they were
/// made. That ordering is load-bearing at the end of a wird: a progress write
/// queued half a second ago must not land *after* the row has been cleared and
/// resurrect a finished session.
class WirdPlayer extends ChangeNotifier {
  WirdPlayer({
    required this.collection,
    required UserRepository user,
    required PlayerHaptics haptics,
    WirdProgress? resumeFrom,
    this.saveDebounce = defaultSaveDebounce,
    DateTime Function()? clock,
  }) : _user = user,
       _haptics = haptics,
       _now = clock ?? DateTime.now,
       _stepIndex = 0,
       _currentCount = 0 {
    if (resumeFrom != null && collection.resumableFrom(resumeFrom) != null) {
      _stepIndex = resumeFrom.stepIndex;
      // Clamped rather than trusted: the count is a plain integer in a row
      // this app is not the only future writer of, and a count past the
      // target would leave the stripe over-full and the step uncompletable.
      _currentCount = resumeFrom.currentCount.clamp(
        0,
        collection.steps[_stepIndex].count,
      );
    }
  }

  /// Opens a collection for playback, resuming if there is anything to resume.
  ///
  /// The resume decision is [ResolvedCollection.resumableFrom]'s, not this
  /// class's: a stored index outlives the content it pointed at, and resuming
  /// at the wrong dhikr is worse than losing a partial session. A row that
  /// does not survive that check is deleted here rather than left to fail the
  /// same way tomorrow.
  ///
  /// There is no resume-or-restart prompt. This is a daily habit, and a
  /// question in front of it every morning is a tax on the habit; "start over"
  /// is a quiet action in the player's app bar for the days it is wanted.
  static Future<WirdPlayer> open({
    required CollectionId id,
    required CollectionRepository collections,
    required UserRepository user,
    required PlayerHaptics haptics,
    Duration saveDebounce = defaultSaveDebounce,
    DateTime Function()? clock,
  }) async {
    final ResolvedCollection collection = await collections.resolve(id);
    final WirdProgress? stored = await user.progress(id);
    final WirdProgress? resume = collection.resumableFrom(stored);
    if (stored != null && resume == null) await user.clearProgress(id);

    return WirdPlayer(
      collection: collection,
      user: user,
      haptics: haptics,
      resumeFrom: resume,
      saveDebounce: saveDebounce,
      clock: clock,
    );
  }

  /// Roughly half a second. Short enough that a crash costs a tap or two,
  /// long enough that a fast thumb is not writing to SQLite on every one.
  static const Duration defaultSaveDebounce = Duration(milliseconds: 500);

  /// The most segments the progress stripe is cut into.
  ///
  /// Thirty-three because that is the length of a tasbih and the largest count
  /// where one segment per repetition still reads as a segment. Past it the
  /// stripe fills proportionally instead — a hundred repetitions light a
  /// segment roughly every third tap.
  static const int maxStripeSegments = 33;

  final ResolvedCollection collection;
  final UserRepository _user;
  final PlayerHaptics _haptics;
  final DateTime Function() _now;

  /// How long a burst of counting can go unwritten. See the class comment.
  final Duration saveDebounce;

  int _stepIndex;
  int _currentCount;
  bool _finished = false;

  Timer? _saveTimer;
  bool _pendingSave = false;
  Future<void> _writes = Future<void>.value();

  /// The structural entry each step came from, so the screen can show the
  /// dhikr's text, its note and its source without walking the entry tree on
  /// every frame.
  late final Map<String, CollectionItemEntry> _itemsByEntryId = _indexEntries(
    collection,
  );

  CollectionId get id => collection.id;

  List<PlaybackStep> get steps => collection.steps;

  /// A collection with nothing playable in it — no items, or a user collection
  /// whose every item now points at content that is gone.
  bool get isEmpty => steps.isEmpty;

  int get stepIndex => _stepIndex;

  /// Repetitions completed of the current step.
  int get currentCount => _currentCount;

  /// The last step's count has been reached. The wird is done, the completion
  /// has been logged and the progress row cleared; the screen is holding the
  /// quiet mark before it leaves.
  bool get finished => _finished;

  /// The step being counted. Only valid when [isEmpty] is false.
  PlaybackStep get step => steps[_stepIndex];

  /// What is left of the current step.
  int get remaining => math.max(0, step.count - _currentCount);

  /// How full the stripe is, 0 to 1.
  double get stepProgress {
    if (isEmpty) return 0;
    if (step.count <= 0) return 1;
    return (_currentCount / step.count).clamp(0.0, 1.0);
  }

  /// How many segments the stripe is cut into for this step.
  int get stripeSegments =>
      isEmpty ? 1 : math.max(1, math.min(step.count, maxStripeSegments));

  /// The content behind the current step: the dhikr, the ayah or the surah,
  /// with its count, note and hydrated source.
  CollectionItemEntry? get currentItem => itemFor(step);

  CollectionItemEntry? itemFor(PlaybackStep step) =>
      _itemsByEntryId[step.entryId];

  bool get canUndo =>
      !isEmpty && !_finished && (_currentCount > 0 || _stepIndex > 0);

  bool get canSkipForward =>
      !isEmpty && !_finished && _stepIndex < steps.length - 1;

  bool get canSkipBackward => !isEmpty && !_finished && _stepIndex > 0;

  /// Every write made so far, in order. Awaiting it waits for the ones already
  /// queued, not for the debounce timer — [flush] is what forces that.
  @visibleForTesting
  Future<void> get writes => _writes;

  /// Whether a count change is sitting behind the debounce timer.
  @visibleForTesting
  bool get hasPendingSave => _pendingSave;

  // -- Counting --------------------------------------------------------------

  /// One repetition of the current step.
  ///
  /// The tap that finishes a step advances to the next one on its own: asking
  /// for a separate "next" tap at the end of every step means thirty-four taps
  /// for a tasbih of thirty-three, and the extra one is always a surprise.
  void increment() {
    if (isEmpty || _finished) return;

    final int next = _currentCount + 1;
    if (next < step.count) {
      _currentCount = next;
      _haptics.tick();
      _scheduleSave();
      notifyListeners();
      return;
    }

    // The step is done on this tap. Only the heavier effect fires, not both:
    // two haptics on one tap read as one muddy buzz rather than as an ending.
    _haptics.stepComplete();
    if (_stepIndex == steps.length - 1) {
      _finish();
      return;
    }
    _stepIndex++;
    _currentCount = 0;
    _saveNow();
    notifyListeners();
  }

  /// Takes one repetition back, across the step boundary if need be.
  ///
  /// People lose count during dhikr, and a counter that only goes up makes
  /// them start the step again. At zero this steps back to the previous step
  /// at its *final* count — the state the advancing tap moved off — so undo
  /// undoes that tap rather than throwing away the step it completed.
  void decrement() {
    if (isEmpty || _finished) return;

    if (_currentCount > 0) {
      _currentCount--;
      _haptics.tick();
      _scheduleSave();
    } else if (_stepIndex > 0) {
      _stepIndex--;
      _currentCount = step.count;
      _haptics.tick();
      _saveNow();
    } else {
      // First step, nothing counted: there is nothing behind this.
      return;
    }
    notifyListeners();
  }

  // -- Moving between steps --------------------------------------------------

  /// The next step, counted or not.
  ///
  /// Skipping does not count the step it leaves: the wird is finished by
  /// reciting it, so a step you skipped past stays at zero and skipping off
  /// the end of the last step does nothing at all. Completion is something you
  /// count your way to.
  void skipForward() {
    if (!canSkipForward) return;
    _stepIndex++;
    _currentCount = 0;
    _haptics.tick();
    _saveNow();
    notifyListeners();
  }

  /// The previous step, at zero.
  ///
  /// Deliberately not "restart this step if you are part-way in": that is a
  /// media player's convention, and here it would quietly throw away a count
  /// somebody was half way through. Undo is the control for that.
  void skipBackward() {
    if (!canSkipBackward) return;
    _stepIndex--;
    _currentCount = 0;
    _haptics.tick();
    _saveNow();
    notifyListeners();
  }

  /// Back to the first step, and forget the saved position.
  ///
  /// The row goes rather than being rewritten as step 0 count 0: a position
  /// nobody has reached yet is not progress, and leaving one behind would show
  /// the collection as part-way through a session that has not started.
  void startOver() {
    _cancelPendingSave();
    _stepIndex = 0;
    _currentCount = 0;
    _finished = false;
    _enqueue(() => _user.clearProgress(id));
    notifyListeners();
  }

  // -- Persistence -----------------------------------------------------------

  /// Writes the position now, and waits for every write queued before it.
  ///
  /// Called when the app goes to the background and when the player closes —
  /// the two moments where the next thing that happens might be the process
  /// going away.
  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_pendingSave) {
      _pendingSave = false;
      _enqueue(_writeProgress);
    }
    return _writes;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_pendingSave) {
      _pendingSave = false;
      // Started and not awaited: dispose cannot be async. It is one upsert
      // against a local database that outlives this object, so it lands.
      _enqueue(_writeProgress);
    }
    super.dispose();
  }

  void _finish() {
    // Before the writes below, or a count queued half a second ago lands after
    // the row is cleared and the wird is part-way through again tomorrow.
    _cancelPendingSave();
    _finished = true;
    // Not zero: the stripe holds solid for the completion beat, and a counter
    // that resets before the screen leaves reads as a step it never finished.
    _currentCount = step.count;
    _enqueue(() => _user.logCompletion(id, _now()));
    _enqueue(() => _user.clearProgress(id));
    notifyListeners();
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
    _enqueue(_writeProgress);
  }

  void _saveNow() {
    _cancelPendingSave();
    _enqueue(_writeProgress);
  }

  void _cancelPendingSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _pendingSave = false;
  }

  /// Reads the position at write time rather than at schedule time, which is
  /// what makes coalescing correct: the last position is the one that matters.
  Future<void> _writeProgress() {
    if (isEmpty || _finished) return Future<void>.value();
    return _user.saveProgress(
      WirdProgress.atStep(
        collectionId: id,
        step: step,
        currentCount: _currentCount,
        updatedAt: _now(),
      ),
    );
  }

  void _enqueue(Future<void> Function() write) {
    _writes = _writes.then((_) => write()).catchError((
      Object error,
      StackTrace stack,
    ) {
      // A failed write costs the resume position, not the session. Report
      // it and keep the chain alive, or one failure silently stops every
      // write after it.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'wirdi',
          context: ErrorDescription('writing wird progress'),
        ),
      );
    });
  }

  static Map<String, CollectionItemEntry> _indexEntries(
    ResolvedCollection collection,
  ) {
    final Map<String, CollectionItemEntry> byId =
        <String, CollectionItemEntry>{};
    void add(CollectionItemEntry item) => byId[item.entryId] = item;

    for (final CollectionEntry entry in collection.entries) {
      switch (entry) {
        case CollectionItemEntry():
          add(entry);
        case RepeatBlock(:final List<CollectionItemEntry> entries):
          entries.forEach(add);
      }
    }
    return byId;
  }
}
