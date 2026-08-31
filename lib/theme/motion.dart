import 'package:flutter/foundation.dart' show lerpDuration;
import 'package:flutter/material.dart';

/// How long things take.
///
/// Carried as a [ThemeExtension] so that a widget asks the theme rather than
/// hard-coding a duration, and so that one day turning the whole app's motion
/// off is a single override.
///
/// There is one curve, [easing], and it is exposed as a constant rather than a
/// field: the brief allows standard easing and nothing else, so a per-theme
/// curve would only ever be a way to get an overshoot in by the back door.
@immutable
final class WirdiMotion extends ThemeExtension<WirdiMotion> {
  const WirdiMotion({
    required this.counter,
    required this.standard,
    required this.sheet,
    required this.completion,
  });

  /// The durations the app ships with.
  const WirdiMotion.standardTiming()
    : counter = Duration.zero,
      standard = const Duration(milliseconds: 150),
      sheet = const Duration(milliseconds: 200),
      completion = const Duration(milliseconds: 500);

  /// Incrementing a counter. Zero, and not by oversight: a tasbih counter that
  /// animates is a counter that lags behind the thumb, and at thirty-three
  /// repetitions the lag is the whole experience.
  final Duration counter;

  /// The default for everything that moves at all.
  final Duration standard;

  /// A bottom sheet arriving or leaving.
  final Duration sheet;

  /// Finishing a wird. The one moment allowed to take its time.
  final Duration completion;

  /// Material's standard easing. No overshoot, no bounce, nothing elastic.
  static const Curve easing = Easing.standard;

  /// For something entering the screen.
  static const Curve easingDecelerate = Easing.standardDecelerate;

  /// For something leaving it.
  static const Curve easingAccelerate = Easing.standardAccelerate;

  @override
  WirdiMotion copyWith({
    Duration? counter,
    Duration? standard,
    Duration? sheet,
    Duration? completion,
  }) {
    return WirdiMotion(
      counter: counter ?? this.counter,
      standard: standard ?? this.standard,
      sheet: sheet ?? this.sheet,
      completion: completion ?? this.completion,
    );
  }

  @override
  WirdiMotion lerp(covariant WirdiMotion? other, double t) {
    if (other == null) return this;
    return WirdiMotion(
      counter: lerpDuration(counter, other.counter, t),
      standard: lerpDuration(standard, other.standard, t),
      sheet: lerpDuration(sheet, other.sheet, t),
      completion: lerpDuration(completion, other.completion, t),
    );
  }
}
