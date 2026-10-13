import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/providers/settings.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/screens/settings_screen.dart';
import 'package:wirdi/theme/theme.dart';

import '../support/fixtures.dart';

/// The switches on the settings screen, and what they leave behind in user.db.
void main() {
  late TestDatabases dbs;
  late WirdiData data;

  setUp(() async {
    dbs = await TestDatabases.open();
    data = WirdiData(content: dbs.content, user: dbs.user);
  });

  tearDown(() => dbs.close());

  Future<void> settle(WidgetTester tester) async {
    for (int frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
        child: MaterialApp(
          theme: WirdiTheme.light(),
          home: const SettingsScreen(),
          onGenerateRoute: WirdiRouter.onGenerateRoute,
        ),
      ),
    );
    await settle(tester);
  }

  SwitchListTile tile(WidgetTester tester, String title) =>
      tester.widget(find.widgetWithText(SwitchListTile, title));

  group('show transliteration', () {
    testWidgets('is on until it is turned off', (WidgetTester tester) async {
      await pumpSettings(tester);

      expect(tile(tester, 'Show transliteration').value, isTrue);
      expect(
        await data.userRepository.setting(SettingKeys.showTransliteration),
        isNull,
      );
    });

    testWidgets('is remembered once turned off', (WidgetTester tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Show transliteration'));
      await settle(tester);

      expect(tile(tester, 'Show transliteration').value, isFalse);
      expect(
        await data.userRepository.setting(SettingKeys.showTransliteration),
        'false',
      );
      // Persisted, so renaming it would silently turn it back on for everybody
      // who had turned it off.
      expect(SettingKeys.showTransliteration, 'text.show_transliteration');
      // Its own switch, not a second label on the translation's.
      expect(tile(tester, 'Show translation').value, isTrue);
    });

    testWidgets('comes back off on the next launch', (
      WidgetTester tester,
    ) async {
      await data.userRepository.setSetting(
        SettingKeys.showTransliteration,
        'false',
      );
      await pumpSettings(tester);

      expect(tile(tester, 'Show transliteration').value, isFalse);
    });
  });
}
