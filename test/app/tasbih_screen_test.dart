import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/player/tasbih_counter.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/screens/tasbih_screen.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/voussoir_stripe.dart';

import '../support/fixtures.dart';

/// The tasbih tab: what a tap does to the number, and what it takes to get the
/// number back to zero.
void main() {
  late TestDatabases dbs;
  late WirdiData data;

  setUp(() async {
    dbs = await TestDatabases.open();
    data = WirdiData(content: dbs.content, user: dbs.user);
  });

  tearDown(() => dbs.close());

  Future<void> pumpTasbih(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
        child: MaterialApp(
          theme: WirdiTheme.light(),
          home: const Scaffold(body: TasbihScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// One tap on the counting area, which is everything above the controls.
  Future<void> count(WidgetTester tester) async {
    await tester.tap(find.text('Tap anywhere to count'));
    await tester.pump();
  }

  Finder button(String label) =>
      find.widgetWithText(OutlinedButton, label).first;

  bool enabled(WidgetTester tester, String label) =>
      tester.widget<OutlinedButton>(button(label)).onPressed != null;

  /// Opens the goal sheet from the bar, whatever the button says right now.
  Future<void> openGoalSheet(WidgetTester tester) async {
    await tester.tap(find.widgetWithIcon(OutlinedButton, Icons.flag_outlined));
    await tester.pumpAndSettle();
  }

  Future<void> chooseGoal(WidgetTester tester, String option) async {
    await openGoalSheet(tester);
    await tester.tap(find.widgetWithText(ListTile, option));
    await tester.pumpAndSettle();
  }

  /// Whether [text] is there to be read: on the screen, and not in a line
  /// that is held open but left unpainted.
  bool readable(String text) {
    final Finder found = find.text(text);
    if (found.evaluate().isEmpty) return false;
    return find
        .ancestor(of: found, matching: find.byType(Visibility))
        .evaluate()
        .every((Element element) => (element.widget as Visibility).visible);
  }

  /// The goal's stripe. The only one on this screen: the rule under the app
  /// bar belongs to the shell, which is not pumped here.
  VoussoirStripe stripe(WidgetTester tester) =>
      tester.widget<VoussoirStripe>(find.byType(VoussoirStripe));

  testWidgets('a tap anywhere counts, and the count keeps going', (
    WidgetTester tester,
  ) async {
    await pumpTasbih(tester);
    expect(find.text('0'), findsOneWidget);

    for (int tap = 0; tap < 40; tap++) {
      await count(tester);
    }

    // Past thirty-three without stopping: there is no target on this screen.
    expect(find.text('40'), findsOneWidget);
  });

  testWidgets('undo takes one back, and both controls are dead at zero', (
    WidgetTester tester,
  ) async {
    await pumpTasbih(tester);
    expect(enabled(tester, 'Undo'), isFalse);
    expect(enabled(tester, 'Reset'), isFalse);

    await count(tester);
    await count(tester);
    expect(enabled(tester, 'Undo'), isTrue);
    expect(enabled(tester, 'Reset'), isTrue);

    await tester.tap(button('Undo'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('reset asks first, and cancelling keeps the count', (
    WidgetTester tester,
  ) async {
    await pumpTasbih(tester);
    await count(tester);
    await count(tester);
    await count(tester);

    await tester.tap(button('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Reset the count?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    await tester.tap(button('Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('the count is where the tab left it', (
    WidgetTester tester,
  ) async {
    // What a restart looks like from here: the stored count is read back, so
    // closing the app is not a reset.
    await data.userRepository.setSetting(TasbihCounter.settingKey, '12');
    await pumpTasbih(tester);

    expect(find.text('12'), findsOneWidget);
    await count(tester);
    expect(find.text('13'), findsOneWidget);
  });

  group('the goal', () {
    testWidgets('is chosen from the sheet, and the stripe counts toward it', (
      WidgetTester tester,
    ) async {
      await pumpTasbih(tester);
      // No goal is the bare counter: no stripe and no caption.
      expect(find.byType(VoussoirStripe), findsNothing);
      expect(find.text('Goal'), findsOneWidget);

      await chooseGoal(tester, '33');
      expect(find.text('Goal 33'), findsOneWidget);
      expect(find.text('of 33'), findsOneWidget);
      // The rounds plate is there from the start, at nothing.
      expect(find.text('×0'), findsOneWidget);
      expect(stripe(tester).lit, 0);
      expect(stripe(tester).segments, 33);

      await count(tester);
      await count(tester);
      expect(stripe(tester).lit, 2);
      expect(find.text('of 33'), findsOneWidget);
    });

    testWidgets('fills a round, counts it, and starts the next at one', (
      WidgetTester tester,
    ) async {
      await data.userRepository.setSetting(TasbihCounter.goalKey, '3');
      await pumpTasbih(tester);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('×0'), findsOneWidget);

      for (int tap = 0; tap < 3; tap++) {
        await count(tester);
      }
      await tester.pumpAndSettle();
      // Full on the goal itself, and the round counted on that same tap.
      expect(find.text('3'), findsOneWidget);
      expect(stripe(tester).lit, 3);
      expect(find.text('×1'), findsOneWidget);
      // The number above is still the total, so the total is not said twice.
      expect(readable('Total 3'), isFalse);

      // The next tap starts the next round, and the total comes in under it.
      await count(tester);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(stripe(tester).lit, 1);
      expect(find.text('×1'), findsOneWidget);
      expect(readable('Total 4'), isTrue);

      await count(tester);
      await count(tester);
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
      expect(readable('Total 6'), isTrue);
    });

    testWidgets(
      'ten rounds of a hundred are a thousand, and go on from there',
      (WidgetTester tester) async {
        await data.userRepository.setSetting(TasbihCounter.settingKey, '999');
        await data.userRepository.setSetting(TasbihCounter.goalKey, '100');
        await pumpTasbih(tester);
        expect(find.text('99'), findsOneWidget);
        expect(find.text('×9'), findsOneWidget);
        expect(readable('Total 999'), isTrue);

        await count(tester);
        await tester.pumpAndSettle();
        expect(find.text('100'), findsOneWidget);
        expect(find.text('×10'), findsOneWidget);
        expect(readable('Total 1000'), isTrue);

        await count(tester);
        await tester.pumpAndSettle();
        expect(find.text('1'), findsOneWidget);
        expect(find.text('×10'), findsOneWidget);
        expect(readable('Total 1001'), isTrue);
      },
    );

    testWidgets('is announced with the round, the rounds and the total', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await data.userRepository.setSetting(TasbihCounter.goalKey, '2');
      await pumpTasbih(tester);

      String announced() =>
          tester.getSemantics(find.bySemanticsLabel('Count')).value;

      expect(announced(), '0 of 2');
      await count(tester);
      await count(tester);
      await tester.pumpAndSettle();
      expect(announced(), '2 of 2, goal reached once');
      await count(tester);
      await count(tester);
      await tester.pumpAndSettle();
      expect(announced(), '2 of 2, goal reached 2 times, total 4');
      await count(tester);
      await tester.pumpAndSettle();
      expect(announced(), '1 of 2, goal reached 2 times, total 5');

      semantics.dispose();
    });

    testWidgets('swells once on the tap that reaches it, and not between', (
      WidgetTester tester,
    ) async {
      // From one rather than zero: the first tap of all enables undo and
      // reset, and Material animates a button coming on.
      await data.userRepository.setSetting(TasbihCounter.settingKey, '1');
      await data.userRepository.setSetting(TasbihCounter.goalKey, '3');
      await pumpTasbih(tester);

      await count(tester);
      expect(tester.hasRunningAnimations, isFalse);

      await count(tester);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();

      // The tap after the goal is an ordinary tap again.
      await count(tester);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('does not move at all with animations turned off', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      // From one, for the reason the test above gives.
      await data.userRepository.setSetting(TasbihCounter.settingKey, '1');
      await data.userRepository.setSetting(TasbihCounter.goalKey, '2');
      await pumpTasbih(tester);

      await count(tester);

      // Reached and counted, on the frame of the tap, with nothing in motion.
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('×1'), findsOneWidget);
      expect(find.text('×0'), findsNothing);
      // The second knock is still on its way.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('survives a reset', (WidgetTester tester) async {
      await data.userRepository.setSetting(TasbihCounter.settingKey, '5');
      await data.userRepository.setSetting(TasbihCounter.goalKey, '3');
      await pumpTasbih(tester);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('×1'), findsOneWidget);

      await tester.tap(button('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
      expect(find.text('of 3'), findsOneWidget);
      expect(find.text('×0'), findsOneWidget);
      expect(readable('Total 5'), isFalse);
      expect(find.text('Goal 3'), findsOneWidget);
    });

    testWidgets('can be taken away again, and the number is the count', (
      WidgetTester tester,
    ) async {
      await data.userRepository.setSetting(TasbihCounter.settingKey, '40');
      await data.userRepository.setSetting(TasbihCounter.goalKey, '33');
      await pumpTasbih(tester);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('of 33'), findsOneWidget);

      await chooseGoal(tester, 'No goal');

      // Nothing was lost: the rounds were only ever a way of reading it.
      expect(find.text('40'), findsOneWidget);
      expect(find.text('of 33'), findsNothing);
      expect(find.text('×1'), findsNothing);
      expect(find.textContaining('Total'), findsNothing);
      expect(find.byType(VoussoirStripe), findsNothing);
      expect(find.text('Goal'), findsOneWidget);
    });

    testWidgets('can be one of your own', (WidgetTester tester) async {
      await pumpTasbih(tester);
      await openGoalSheet(tester);

      FilledButton set() =>
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Set'));

      // Nothing to set until there is a number to set it to.
      expect(set().onPressed, isNull);
      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();
      expect(set().onPressed, isNull, reason: 'a goal of nothing is no goal');

      await tester.enterText(find.byType(TextField), '250');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Set'));
      await tester.pumpAndSettle();
      expect(find.text('of 250'), findsOneWidget);
      expect(find.text('Goal 250'), findsOneWidget);

      // Opened again, the field holds it, ready to be changed from there.
      await openGoalSheet(tester);
      expect(find.widgetWithText(TextField, '250'), findsOneWidget);
    });
  });
}
