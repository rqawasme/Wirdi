import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/player/player_haptics.dart';
import 'package:wirdi/player/tasbih_counter.dart';

import '../support/fixtures.dart';

/// The tasbih counter, without a widget in sight.
///
/// What is worth checking here is not that a number goes up. It is that the
/// number survives the app going away, that a burst of taps is not a burst of
/// writes, and that a settings row somebody else wrote cannot leave the screen
/// showing a count no gesture could produce.
void main() {
  late TestDatabases dbs;
  late UserRepository user;
  late RecordedTasbihHaptics haptics;
  final List<TasbihCounter> opened = <TasbihCounter>[];

  setUp(() async {
    dbs = await TestDatabases.open();
    user = dbs.userRepository();
    haptics = RecordedTasbihHaptics();
  });

  tearDown(() async {
    for (final TasbihCounter counter in opened) {
      // Drained before the database goes: a write still in flight when the
      // connection closes fails, and that failure is the test's doing. In the
      // app the database outlives every counter.
      await counter.flush();
      counter.dispose();
    }
    opened.clear();
    await dbs.close();
  });

  TasbihCounter counterOn({
    int initialCount = 0,
    Duration saveDebounce = TasbihCounter.defaultSaveDebounce,
  }) {
    final TasbihCounter counter = TasbihCounter(
      user: user,
      haptics: haptics.haptics,
      initialCount: initialCount,
      saveDebounce: saveDebounce,
    );
    opened.add(counter);
    return counter;
  }

  Future<String?> stored() => user.setting(TasbihCounter.settingKey);

  test('counts a tap at a time, with no ceiling to reach', () async {
    final TasbihCounter counter = counterOn();
    expect(counter.count, 0);
    expect(counter.isEmpty, isTrue);

    for (int tap = 0; tap < 100; tap++) {
      counter.increment();
    }

    // Past thirty-three and past a hundred: nothing here completes, and the
    // count is not a wird's.
    expect(counter.count, 100);
    expect(counter.isEmpty, isFalse);
  });

  test('undo takes one tap back, and stops at zero', () async {
    final TasbihCounter counter = counterOn(initialCount: 2);

    counter.decrement();
    expect(counter.count, 1);
    counter.decrement();
    expect(counter.count, 0);

    // The button is disabled here, but the method has to hold the floor on its
    // own: a negative count would render as a minus sign nothing could clear.
    counter.decrement();
    expect(counter.count, 0);
  });

  test('reset goes to zero and is written straight away', () async {
    final TasbihCounter counter = counterOn(initialCount: 33);

    counter.reset();
    expect(counter.count, 0);
    expect(counter.hasPendingSave, isFalse);

    await counter.writes;
    expect(await stored(), '0');
  });

  test('a burst of taps is not a write per tap', () async {
    final TasbihCounter counter = counterOn();

    for (int tap = 0; tap < 10; tap++) {
      counter.increment();
    }

    // Nothing has reached the database yet: the rate limiter is holding it.
    expect(counter.hasPendingSave, isTrue);
    expect(await stored(), isNull);

    await counter.flush();
    expect(await stored(), '10');
  });

  test('a long run is written through rather than held to the end', () async {
    final TasbihCounter counter = counterOn(
      saveDebounce: const Duration(milliseconds: 10),
    );

    counter.increment();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    counter.increment();
    await counter.writes;

    // Written without a flush, and while the counting is still going: the
    // timer is a rate limiter, not a trailing debounce.
    expect(await stored(), '1');
  });

  test('the count survives being closed and opened again', () async {
    final TasbihCounter first = counterOn();
    for (int tap = 0; tap < 7; tap++) {
      first.increment();
    }
    await first.flush();

    final TasbihCounter second = await TasbihCounter.open(
      user: user,
      haptics: haptics.haptics,
    );
    opened.add(second);

    // Closing the app is not a reset. Only the button is.
    expect(second.count, 7);
  });

  test('a stored value no gesture could produce starts at zero', () async {
    for (final String raw in <String>['', 'thirty-three', '-5', '9.5']) {
      await user.setSetting(TasbihCounter.settingKey, raw);
      final TasbihCounter counter = await TasbihCounter.open(
        user: user,
        haptics: haptics.haptics,
      );
      opened.add(counter);
      expect(counter.count, 0, reason: 'stored "$raw"');
    }
  });

  test('a tap clicks and a reset knocks', () async {
    final TasbihCounter counter = counterOn();

    counter.increment();
    counter.increment();
    counter.decrement();
    expect(haptics.selections, 3);
    expect(haptics.impacts, 0);

    // The heavier effect, and only it: reset is the one thing on this screen
    // that has to be distinguishable from a tap without looking.
    counter.reset();
    expect(haptics.selections, 3);
    expect(haptics.impacts, 1);

    // Nothing to reset, nothing to feel.
    counter.reset();
    counter.decrement();
    expect(haptics.impacts, 1);
    expect(haptics.selections, 3);
  });
}

/// [PlayerHaptics] with the two effects counted instead of sent, and a clock
/// that steps a second on each read — so the throttle never swallows an effect
/// a test meant to count.
class RecordedTasbihHaptics {
  RecordedTasbihHaptics() {
    haptics = PlayerHaptics(
      selection: () => selections++,
      impact: () => impacts++,
      clock: () => DateTime(2026).add(Duration(seconds: _reads++)),
    );
  }

  late final PlayerHaptics haptics;
  int selections = 0;
  int impacts = 0;
  int _reads = 0;
}
