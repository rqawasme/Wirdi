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
    int? initialGoal,
    Duration saveDebounce = TasbihCounter.defaultSaveDebounce,
  }) {
    final TasbihCounter counter = TasbihCounter(
      user: user,
      haptics: haptics.haptics,
      initialCount: initialCount,
      initialGoal: initialGoal,
      saveDebounce: saveDebounce,
    );
    opened.add(counter);
    return counter;
  }

  Future<String?> stored() => user.setting(TasbihCounter.settingKey);

  Future<String?> storedGoal() => user.setting(TasbihCounter.goalKey);

  Future<TasbihCounter> reopened() async {
    final TasbihCounter counter = await TasbihCounter.open(
      user: user,
      haptics: haptics.haptics,
    );
    opened.add(counter);
    return counter;
  }

  test('counts a tap at a time, with no ceiling to reach', () async {
    final TasbihCounter counter = counterOn();
    expect(counter.count, 0);
    expect(counter.isEmpty, isTrue);

    for (int tap = 0; tap < 100; tap++) {
      counter.increment();
    }

    // Past thirty-three and past a hundred: with no goal nothing here
    // completes, nothing knocks, and the count is not a wird's.
    expect(counter.count, 100);
    expect(counter.isEmpty, isFalse);
    expect(counter.goal, isNull);
    expect(counter.goalsReached, 0);
    expect(counter.roundTaps, 0);
    expect(haptics.knocks, 0);
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
    expect(haptics.clicks, 3);
    expect(haptics.knocks, 0);

    // The heavier effect, and only it: reset has to be distinguishable from a
    // tap without looking.
    counter.reset();
    expect(haptics.clicks, 3);
    expect(haptics.knocks, 1);

    // Nothing to reset, nothing to feel.
    counter.reset();
    counter.decrement();
    expect(haptics.knocks, 1);
    expect(haptics.clicks, 3);
  });

  group('the goal', () {
    test('the tap on the goal knocks twice instead of clicking, and so does '
        'every multiple of it', () {
      final TasbihCounter counter = counterOn(initialGoal: 3);

      final List<int> rounds = <int>[];
      for (int tap = 0; tap < 9; tap++) {
        counter.increment();
        rounds.add(counter.roundTaps);
      }

      // On 3, 6 and 9: two knocks each, and no click on those three taps.
      expect(haptics.knocks, 6);
      expect(haptics.clicks, 6);
      expect(counter.goalArrivals, 3);
      expect(counter.goalsReached, 3);
      // The stripe fills on the goal's tap and starts again on the next one.
      expect(rounds, <int>[1, 2, 3, 1, 2, 3, 1, 2, 3]);
    });

    test('the count carries on past the goal', () {
      final TasbihCounter counter = counterOn(initialGoal: 33);

      for (int tap = 0; tap < 40; tap++) {
        counter.increment();
      }

      expect(counter.count, 40);
      expect(counter.goalsReached, 1);
      expect(counter.roundTaps, 7);
    });

    test(
      'undo is a click, and coming back up onto the goal reaches it again',
      () {
        final TasbihCounter counter = counterOn(initialGoal: 3);
        for (int tap = 0; tap < 3; tap++) {
          counter.increment();
        }
        expect(counter.goalArrivals, 1);
        expect(haptics.knocks, 2);

        counter.decrement();
        expect(counter.goalsReached, 0);
        expect(haptics.knocks, 2, reason: 'undo is never a knock');
        expect(haptics.clicks, 3);

        counter.increment();
        expect(counter.goalArrivals, 2);
        expect(haptics.knocks, 4);
      },
    );

    test('undoing back onto a multiple is not reaching it', () {
      final TasbihCounter counter = counterOn(initialCount: 4, initialGoal: 3);

      counter.decrement();

      expect(counter.count, 3);
      expect(counter.goalsReached, 1);
      expect(counter.roundTaps, 3, reason: 'the stripe is full on the goal');
      expect(counter.goalArrivals, 0);
      expect(haptics.knocks, 0);
    });

    test('a goal set at or below the count is reached, without a knock', () {
      final TasbihCounter counter = counterOn(initialCount: 40);

      counter.setGoal(33);

      expect(counter.goalsReached, 1);
      expect(counter.roundTaps, 7);
      expect(counter.goalArrivals, 0);
      expect(haptics.knocks, 0, reason: 'nothing was counted onto it');
    });

    test('reset takes the count to zero and leaves the goal', () {
      final TasbihCounter counter = counterOn(
        initialCount: 10,
        initialGoal: 33,
      );

      counter.reset();

      expect(counter.count, 0);
      expect(counter.goal, 33);
      expect(counter.roundTaps, 0);
      expect(counter.goalsReached, 0);
    });

    test('is written straight away, and survives being opened again', () async {
      final TasbihCounter counter = counterOn();

      counter.setGoal(33);
      // Not behind the rate limiter: a goal is chosen once, not in bursts.
      expect(counter.hasPendingSave, isFalse);
      await counter.writes;
      expect(await storedGoal(), '33');
      expect((await reopened()).goal, 33);

      counter.setGoal(null);
      await counter.writes;
      expect(await storedGoal(), '');
      expect((await reopened()).goal, isNull);
    });

    test('lands in order with the count it was set among', () async {
      final TasbihCounter counter = counterOn();

      counter.increment();
      counter.increment();
      counter.setGoal(5);
      counter.reset();
      counter.setGoal(7);
      await counter.flush();

      final TasbihCounter again = await reopened();
      expect(again.count, 0);
      expect(again.goal, 7);
    });

    test('a stored goal no sheet could set is no goal', () async {
      for (final String raw in <String>[
        '',
        'none',
        '0',
        '-3',
        '9.5',
        '${TasbihCounter.maxGoal + 1}',
      ]) {
        await user.setSetting(TasbihCounter.goalKey, raw);
        expect((await reopened()).goal, isNull, reason: 'stored "$raw"');
      }
    });

    test('a goal outside the range is refused, not stored', () async {
      final TasbihCounter counter = counterOn(initialGoal: 33);

      expect(() => counter.setGoal(0), throwsArgumentError);
      expect(
        () => counter.setGoal(TasbihCounter.maxGoal + 1),
        throwsArgumentError,
      );
      expect(counter.goal, 33);

      counter.setGoal(TasbihCounter.maxGoal);
      expect(counter.goal, TasbihCounter.maxGoal);
    });
  });
}

/// [PlayerHaptics] with the two effects counted instead of sent, a clock that
/// steps a second on each read — so the throttle never swallows an effect a
/// test meant to count — and the goal's second knock run at once rather than
/// after its gap, so a goal is always both of its knocks.
class RecordedTasbihHaptics {
  RecordedTasbihHaptics() {
    haptics = PlayerHaptics(
      click: () => clicks++,
      knock: () => knocks++,
      clock: () => DateTime(2026).add(Duration(seconds: _reads++)),
      schedule: (Duration delay, HapticEffect effect) => effect(),
    );
  }

  late final PlayerHaptics haptics;
  int clicks = 0;
  int knocks = 0;
  int _reads = 0;
}
