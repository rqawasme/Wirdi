import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/player/player_haptics.dart';

/// The throttle, which is the only logic in the haptics.
///
/// It matters because of what it is protecting against: some Android devices
/// buffer rapid vibration calls and play them back late, so a fast thumb
/// leaves the phone buzzing after it has stopped tapping. Dropped calls are
/// the point — a queued one arrives after the tap it belongs to, which is the
/// lag the whole counter is built to avoid, arriving through the other sense.
void main() {
  late DateTime now;
  late int selections;
  late int impacts;

  PlayerHaptics hapticsWith({bool enabled = true}) => PlayerHaptics(
    enabled: enabled,
    selection: () => selections++,
    impact: () => impacts++,
    clock: () => now,
  );

  setUp(() {
    now = DateTime(2026, 3, 14, 9);
    selections = 0;
    impacts = 0;
  });

  void advance(int milliseconds) =>
      now = now.add(Duration(milliseconds: milliseconds));

  test('the first tap always clicks', () {
    hapticsWith().tick();
    expect(selections, 1);
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
    expect(selections, 1);
  });

  test('a tap past the window clicks again', () {
    final PlayerHaptics haptics = hapticsWith();

    haptics.tick();
    advance(PlayerHaptics.defaultMinInterval.inMilliseconds);
    haptics.tick();

    expect(selections, 2);
  });

  test('counting at ten taps a second clicks on every tap', () {
    final PlayerHaptics haptics = hapticsWith();

    for (int tap = 0; tap < 10; tap++) {
      haptics.tick();
      advance(100);
    }

    // The throttle is above the speed anybody counts at, so ordinary counting
    // never loses a click to it.
    expect(selections, 10);
  });

  test('the end of a step always knocks, whatever the throttle says', () {
    final PlayerHaptics haptics = hapticsWith();

    haptics.tick();
    advance(1);
    haptics.stepComplete();

    expect(impacts, 1, reason: 'the one effect that must never be dropped');
  });

  test('the knock resets the window, so no click lands on top of it', () {
    final PlayerHaptics haptics = hapticsWith();

    haptics.stepComplete();
    advance(1);
    haptics.tick();

    expect(impacts, 1);
    expect(selections, 0);
  });

  test('off means silent', () {
    final PlayerHaptics haptics = hapticsWith(enabled: false);

    haptics.tick();
    advance(1000);
    haptics.stepComplete();

    expect(selections, 0);
    expect(impacts, 0);
  });

  test('the setting can move while the counter is open', () {
    final PlayerHaptics haptics = hapticsWith(enabled: false);

    haptics.tick();
    expect(selections, 0);

    haptics.enabled = true;
    advance(1000);
    haptics.tick();
    expect(selections, 1);
  });
}
