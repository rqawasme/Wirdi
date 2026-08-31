import 'dart:async';

import 'package:flutter/services.dart';

/// One haptic effect, fired and forgotten.
typedef HapticEffect = void Function();

/// The counter's haptics: a click on every tap, a heavier knock at the end of
/// a step.
///
/// Two things make this a class rather than two bare calls to
/// [HapticFeedback].
///
/// **Throttling.** Some Android devices buffer rapid vibration calls and play
/// them back late, so a fast thumb leaves the phone still buzzing after it has
/// stopped tapping. That is exactly the lag the zero-animation rule exists to
/// avoid, arriving through the other sense. Calls closer together than
/// [minInterval] are therefore **dropped, never queued**: a click that lands
/// after the tap it belongs to is worse than one that never lands at all.
///
/// **The setting.** [enabled] is the settings-screen switch, and it is
/// mutable: the switch can move while the player is open, and a haptics object
/// rebuilt underneath a running counter would lose the throttle window with
/// it.
///
/// [stepComplete] deliberately bypasses the throttle — it happens once a step
/// rather than once a tap, and it is the feedback that says the count is
/// finished, so it has to be felt. It does reset the window, so the click for
/// that same tap cannot arrive on top of it.
class PlayerHaptics {
  PlayerHaptics({
    this.enabled = true,
    this.minInterval = defaultMinInterval,
    HapticEffect? selection,
    HapticEffect? impact,
    DateTime Function()? clock,
  }) : _selection = selection ?? _systemSelection,
       _impact = impact ?? _systemImpact,
       _now = clock ?? DateTime.now;

  /// Roughly one click per 60ms. Above about sixteen taps a second a counter
  /// is no longer being counted on, and the device cannot render distinct
  /// clicks that fast anyway.
  static const Duration defaultMinInterval = Duration(milliseconds: 60);

  /// The haptics setting. Mutable: see the class comment.
  bool enabled;

  final Duration minInterval;
  final HapticEffect _selection;
  final HapticEffect _impact;
  final DateTime Function() _now;

  DateTime? _lastEffect;

  /// One increment. Dropped if it falls inside the throttle window.
  void tick() {
    if (!enabled) return;
    final DateTime now = _now();
    final DateTime? last = _lastEffect;
    if (last != null && now.difference(last) < minInterval) return;
    _lastEffect = now;
    _selection();
  }

  /// The tap that finishes a step. Always fires, and is a different effect —
  /// the point is that it is distinguishable by feel from an ordinary tap
  /// without looking at the screen.
  void stepComplete() {
    if (!enabled) return;
    _lastEffect = _now();
    _impact();
  }

  // Not awaited: a haptic is fire-and-forget, and the platform channel's
  // future says nothing about what the user felt.
  static void _systemSelection() => unawaited(HapticFeedback.selectionClick());

  static void _systemImpact() => unawaited(HapticFeedback.mediumImpact());
}
