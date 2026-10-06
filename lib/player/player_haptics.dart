import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One haptic effect, fired and forgotten.
typedef HapticEffect = void Function();

/// Runs [effect] once [delay] has passed. A [Timer] in the app; a test passes
/// one it can drive.
typedef HapticScheduler = void Function(Duration delay, HapticEffect effect);

/// The counters' haptics: a click on every tap, a knock at the end of a step,
/// and two knocks at a tasbih goal.
///
/// Three things make this a class rather than bare calls to [HapticFeedback].
///
/// **Throttling.** Some Android devices buffer rapid vibration calls and play
/// them back late, so a fast thumb leaves the phone still buzzing after it has
/// stopped tapping. That is exactly the lag the counter's instant numeral
/// exists to avoid, arriving through the other sense. Calls closer together
/// than [minInterval] are therefore **dropped, never queued**: a click that
/// lands after the tap it belongs to is worse than one that never lands at all.
///
/// **The setting.** [enabled] is the settings-screen switch, and it is
/// mutable: the switch can move while a counter is open, and a haptics object
/// rebuilt underneath a running counter would lose the throttle window with
/// it.
///
/// **Which effect, on which platform.** Flutter's names for the effects are
/// iOS's, and Android does not rank them the same way. `selectionClick` is
/// Android's clock tick, the faintest effect it has, which many phones barely
/// play — it is what every tap used to send, and taps went unfelt.
/// `heavyImpact` is Android's context click, which most phones play *lighter*
/// than a key press. So a tap sends [HapticFeedback.lightImpact] (a virtual
/// key on Android, a light impact on iOS), and a knock sends the heaviest
/// effect each platform offers through the haptic API:
/// [HapticFeedback.vibrate] on Android, a long press's heavy click, and
/// [HapticFeedback.heavyImpact] on iOS, where `vibrate` is a long system buzz
/// rather than a knock. None of them needs a
/// permission — they are the view's haptic feedback, not the vibrator — so the
/// app stays the zero-permission app its Play listing says it is.
///
/// [stepComplete] and [goalReached] deliberately bypass the throttle — they
/// happen once a step or once a goal rather than once a tap, and each is the
/// feedback that says something has been reached, so it has to be felt. They
/// do restart the window, so the click for that same tap cannot arrive on top
/// of them.
class PlayerHaptics {
  PlayerHaptics({
    this.enabled = true,
    this.minInterval = defaultMinInterval,
    this.goalGap = defaultGoalGap,
    HapticEffect? click,
    HapticEffect? knock,
    DateTime Function()? clock,
    HapticScheduler? schedule,
  }) : _click = click ?? _systemClick,
       _knock = knock ?? _systemKnock,
       _now = clock ?? DateTime.now,
       _schedule = schedule ?? _timer;

  /// Roughly one click per 60ms. Above about sixteen taps a second a counter
  /// is no longer being counted on, and the device cannot render distinct
  /// clicks that fast anyway.
  static const Duration defaultMinInterval = Duration(milliseconds: 60);

  /// Between the two knocks of a goal. Close enough together to read as one
  /// event, far enough apart to be felt as two — which is what tells a goal
  /// from the end of a step, or from a reset, without looking.
  static const Duration defaultGoalGap = Duration(milliseconds: 120);

  /// The haptics setting. Mutable: see the class comment.
  bool enabled;

  final Duration minInterval;
  final Duration goalGap;
  final HapticEffect _click;
  final HapticEffect _knock;
  final DateTime Function() _now;
  final HapticScheduler _schedule;

  /// Nothing throttled fires before this. Null until the first effect.
  DateTime? _quietUntil;

  /// One tap. Dropped if it falls inside the throttle window.
  void tick() {
    if (!enabled) return;
    final DateTime now = _now();
    final DateTime? quietUntil = _quietUntil;
    if (quietUntil != null && now.isBefore(quietUntil)) return;
    _quietUntil = now.add(minInterval);
    _click();
  }

  /// The tap that finishes a step, and a reset. Always fires, and is a
  /// different effect — the point is that it is distinguishable by feel from
  /// an ordinary tap without looking at the screen.
  void stepComplete() {
    if (!enabled) return;
    _quietUntil = _now().add(minInterval);
    _knock();
  }

  /// The tap that lands on a tasbih goal, or on a multiple of one: two knocks,
  /// [goalGap] apart.
  ///
  /// The window is held open across both, so a fast thumb's next click does
  /// not land between them and blur the pair into a buzz. The tap itself still
  /// counts — only its click is dropped. The second knock checks the setting
  /// again, because the switch can move in the gap.
  void goalReached() {
    if (!enabled) return;
    _quietUntil = _now().add(goalGap + minInterval);
    _knock();
    _schedule(goalGap, () {
      if (enabled) _knock();
    });
  }

  // Not awaited: a haptic is fire-and-forget, and the platform channel's
  // future says nothing about what the user felt.
  static void _systemClick() => unawaited(HapticFeedback.lightImpact());

  static void _systemKnock() => unawaited(switch (defaultTargetPlatform) {
    TargetPlatform.android => HapticFeedback.vibrate(),
    _ => HapticFeedback.heavyImpact(),
  });

  static void _timer(Duration delay, HapticEffect effect) =>
      Timer(delay, effect);
}
