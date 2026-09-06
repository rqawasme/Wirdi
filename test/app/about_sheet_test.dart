import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/app_version.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/screens/settings_screen.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/about_sheet.dart';

import '../support/fixtures.dart';

/// About: the button at the bottom of Settings, and the sheet it opens.
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

  Future<void> openSheet(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('About Wirdi'), 200);
    await settle(tester);
    await tester.tap(find.text('About Wirdi'));
    await settle(tester);
  }

  testWidgets('the button is the last thing on the settings screen', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);
    await tester.scrollUntilVisible(find.text('About Wirdi'), 200);
    await settle(tester);

    // Below the settings rather than among them: reading the credits changes
    // nothing, so it is not a setting.
    expect(
      tester.getTopLeft(find.text('About Wirdi')).dy,
      greaterThan(tester.getTopLeft(find.text('Theme')).dy),
    );
  });

  testWidgets('it opens the sheet rather than pushing a screen', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);
    await openSheet(tester);

    expect(find.byType(AboutContent), findsOneWidget);
    // Still on Settings underneath: a sheet dismisses back to where the reader
    // was, and does not join the back stack.
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('it credits the developer alongside the versions', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);
    await openSheet(tester);

    expect(find.text('Developed by'), findsOneWidget);
    expect(find.text('Safi Solutions'), findsOneWidget);
    expect(find.text(appVersion), findsOneWidget);
  });

  testWidgets('the sources and the font licences came with it', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);
    await openSheet(tester);

    // Scoped to the sheet: Settings is still mounted underneath, and its
    // translation slider is labelled "Translation" too.
    Finder inSheet(String text) => find.descendant(
      of: find.byType(AboutContent),
      matching: find.text(text),
    );

    expect(inSheet('Quran text'), findsOneWidget);
    expect(inSheet('Translation'), findsOneWidget);

    // The licence requires that they travel with the fonts, so all three are
    // still here rather than being summarised away by the move. They are at
    // the bottom of a sheet that does not show its whole length at once.
    final Finder list = find
        .descendant(
          of: find.byType(AboutContent),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final String family in AboutContent.fontLicences.keys) {
      await tester.scrollUntilVisible(inSheet(family), 200, scrollable: list);
      await settle(tester);
      expect(inSheet(family), findsOneWidget);
    }
    expect(inSheet('Fonts'), findsOneWidget);
  });

  testWidgets('it dismisses back to Settings', (WidgetTester tester) async {
    await pumpSettings(tester);
    await openSheet(tester);

    Navigator.of(tester.element(find.byType(AboutContent))).pop();
    await settle(tester);

    expect(find.byType(AboutContent), findsNothing);
    expect(find.text('About Wirdi'), findsOneWidget);
  });
}
