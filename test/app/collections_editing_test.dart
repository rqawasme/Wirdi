import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/providers/settings.dart';
import 'package:wirdi/providers/streak.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/empty_state.dart';
import 'package:wirdi/widgets/streak_panel.dart';

import '../support/fixtures.dart';

/// The collections screen once it has a streak on it and collections to make.
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

  Future<void> pumpApp(WidgetTester tester, {DateTime? now}) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          wirdiDataProvider.overrideWithValue(data),
          if (now != null) clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          theme: WirdiTheme.light(),
          onGenerateRoute: WirdiRouter.onGenerateRoute,
          initialRoute: Routes.collections,
        ),
      ),
    );
    await settle(tester);
  }

  group('the streak', () {
    testWidgets('is on the list by default', (WidgetTester tester) async {
      await pumpApp(tester);

      expect(find.byType(StreakPanel), findsOneWidget);
      expect(find.text('No days in a row'), findsOneWidget);
    });

    testWidgets('counts the days and marks them', (WidgetTester tester) async {
      final DateTime now = DateTime.now();
      final UserRepository user = dbs.userRepository();
      await user.logCompletion(
        const BuiltinCollectionId(mixedCollectionId),
        now,
      );
      await user.logCompletion(
        const BuiltinCollectionId(simpleCollectionId),
        now.subtract(const Duration(days: 1)),
      );

      await pumpApp(tester);

      // Two days, counted back from today. A second collection completed on
      // the same day is still one day.
      expect(find.text('2 days in a row'), findsOneWidget);
    });

    testWidgets('is gone entirely when the setting is off', (
      WidgetTester tester,
    ) async {
      await dbs.userRepository().setSetting(SettingKeys.showStreak, 'false');

      await pumpApp(tester);

      // Not greyed out, not collapsed to a number: absent.
      expect(find.byType(StreakPanel), findsNothing);
      expect(find.textContaining('in a row'), findsNothing);
      // And the wirds it sat above are still there.
      expect(find.text('PLACEHOLDER collection 1 english'), findsOneWidget);
    });

    testWidgets('is turned off from Settings', (WidgetTester tester) async {
      await pumpApp(tester);
      expect(find.byType(StreakPanel), findsOneWidget);

      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      await tester.tap(find.text('Show streak'));
      await settle(tester);

      expect(
        await dbs.userRepository().setting(SettingKeys.showStreak),
        'false',
      );

      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.byType(StreakPanel), findsNothing);
    });
  });

  group('empty states', () {
    testWidgets('the list says so when nothing is the user\'s own', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('Nothing of your own yet'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      // The stripe, not an illustration.
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('and stops saying so once there is one', (
      WidgetTester tester,
    ) async {
      await dbs.collectionRepository().create('Mine');

      await pumpApp(tester);

      expect(find.text('Mine'), findsOneWidget);
      expect(find.text('Nothing of your own yet'), findsNothing);
    });
  });

  group('making a collection', () {
    testWidgets('from scratch, then landing in its editor', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('New collection'));
      await settle(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'After fajr',
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settle(tester);

      // The editor, on the collection just made, which is empty.
      expect(find.text('After fajr'), findsOneWidget);
      expect(find.text('Nothing in this collection yet'), findsOneWidget);

      final List<CollectionSummary> all = await dbs
          .collectionRepository()
          .all();
      expect(all.map((CollectionSummary s) => s.name), contains('After fajr'));
    });

    testWidgets('by copying a built-in, which is the path that matters', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('More').first);
      await settle(tester);
      await tester.tap(find.text('Make a copy I can edit'));
      await settle(tester);

      // Prefilled, so the common case is one confirmation.
      expect(
        find.widgetWithText(
          TextField,
          'Copy of PLACEHOLDER collection 1 english',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Copy'));
      await settle(tester);

      // Straight into the editor: somebody who asked for a copy they can edit
      // asked to edit it.
      expect(
        find.text('Copy of PLACEHOLDER collection 1 english'),
        findsOneWidget,
      );
      expect(find.text('Repeated 3 times'), findsOneWidget);

      final List<CollectionSummary> all = await dbs
          .collectionRepository()
          .all();
      final CollectionSummary made = all.lastWhere(
        (CollectionSummary s) => !s.isBuiltin,
      );
      final ResolvedCollection resolved = await dbs
          .collectionRepository()
          .resolve(made.id);
      expect(resolved.entries.length, 6);
      expect(resolved.steps.length, 14);
    });
  });
}
