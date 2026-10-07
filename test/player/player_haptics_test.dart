import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/player/player_haptics.dart';

/// The throttle and the goal's two knocks, which are the only logic in the
/// haptics.
///
/// The throttle matters because of what it is protecting against: some
/// Android devices buffer rapid vibration calls and play them back late, so a
/// fast thumb leaves the phone buzzing after it has stopped tapping. Dropped
/// calls are the point — a queued one arrives after the tap it belongs to,
/// which is the lag the whole counter is built to avoid, arriving through the
/// other sense.
void main() {
  late DateTime now;
  late int clicks;
  late int knocks;
  late List<(Duration, HapticEffect)> scheduled;

  PlayerHaptics hapticsWith({bool enabled = true}) => PlayerHaptics(
    enabled: enabled,
    click: () => clicks++,
    knock: () => knocks++,
    clock: () => now,
    schedule: (Duration delay, HapticEffect effect) =>
        scheduled.add((delay, effect)),
  );

  setUp(() {
    now = DateTime(2026, 3, 14, 9);
    clicks = 0;
    knocks = 0;
    scheduled = <(Duration, HapticEffect)>[];
  });

  void advance(int milliseconds) =>
      now = now.add(Duration(milliseconds: milliseconds));

  /// Runs whatever the haptics asked to run later, as the timer would.
  void runScheduled() {
    final List<(Duration, HapticEffect)> due = scheduled.toList();
    scheduled.clear();
    for (final (Duration delay, HapticEffect effect) in due) {
      advance(delay.inMilliseconds);
      effect();
    }
  }

  test('the first tap always clicks', () {
    hapticsWith().tick();
    expect(clicks, 1);
  });

  test('taps inside the window are dropped, not queued', () {
    final PlayerHaptics haptics = hapticsWith();

    haptics.tick();
    for (int tap = 0; tap < 10; tap++) {
      advance(5);
      haptics.tick();
    }

    // Ten more taps over 50ms, one click. Not eleven clicks played back over
    // the next second.
    expect(clicks, 1);
  });

  test('a tap past the window clicks again', () {
    final PlayerHaptics haptics = hapticsWith();

    haptics.tick();
    advance(PlayerHaptics.defaultMinInterval.inMilliseconds);
    haptics.tick();

    expect(clicks, 2);
  });

  test('counting at ten taps a second clicks on every tap', () {
    final PlayerHaptics haptics = hapticsWith();

    for (int tap = 0; tap < 10; tap++) {
      haptics.tick();
      advance(100);
    }

    // The throttle is above the speed anybody counts at, so ordinary counting
    // never loses a click to it.
    expect(clicks, 10);
  });

  test('the end of a step always knocks, whatever the throttle says', () {
    final PlayerHaptics haptics = hapticsWith();

    haptics.tick();
    advance(1);
    haptics.stepComplete();

    expect(knocks, 1, reason: 'the one effect that must never be dropped');
  });

  test('the knock resets the window, so no click lands on top of it', () {
    final PlayerHaptics haptics = hapticsWith();

    haptics.stepComplete();
    advance(1);
    haptics.tick();

    expect(knocks, 1);
    expect(clicks, 0);
  });

  test('a goal knocks twice, the second a gap after the first', () {
    final PlayerHaptics haptics = hapticsWith();

    haptics.tick();
    advance(1);
    haptics.goalReached();

    // The first at once, and past the throttle like the end of a step.
    expect(knocks, 1);
    expect(scheduled, hasLength(1));
    expect(scheduled.single.$1, PlayerHaptics.defaultGoalGap);

    runScheduled();
    expect(knocks, 2);
    expect(clicks, 1, reason: 'the goal is the knocks, not a click as well');
  });

  test('no click lands between the two knocks, or on the second', () {
    final PlayerHaptics haptics = hapticsWith();

    haptics.goalReached();
    // A fast thumb's next taps, inside the gap and just after it.
    for (
      int elapsed = 0;
      elapsed <
          (PlayerHaptics.defaultGoalGap + PlayerHaptics.defaultMinInterval)
              .inMilliseconds;
      elapsed += 20
    ) {
      haptics.tick();
      advance(20);
    }
    expect(clicks, 0);

    // Once the window is past, counting clicks again.
    haptics.tick();
    expect(clicks, 1);
  });

  test('turning haptics off in the gap stops the second knock', () {
    final PlayerHaptics haptics = hapticsWith();

    haptics.goalReached();
    haptics.enabled = false;
    runScheduled();

    expect(knocks, 1);
  });

  test('off means silent', () {
    final PlayerHaptics haptics = hapticsWith(enabled: false);

    haptics.tick();
    advance(1000);
    haptics.stepComplete();
    advance(1000);
    haptics.goalReached();

    expect(clicks, 0);
    expect(knocks, 0);
    expect(scheduled, isEmpty, reason: 'nothing waiting to fire later either');
  });

  test('the setting can move while the counter is open', () {
    final PlayerHaptics haptics = hapticsWith(enabled: false);

    haptics.tick();
    expect(clicks, 0);

    haptics.enabled = true;
    advance(1000);
    haptics.tick();
    expect(clicks, 1);
  });
}
