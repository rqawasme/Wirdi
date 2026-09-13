import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/player/tasbih_counter.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/screens/tasbih_screen.dart';
import 'package:wirdi/theme/theme.dart';

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
}
