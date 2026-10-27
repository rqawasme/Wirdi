import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/providers/streak.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/collection_tile.dart';

import '../support/fixtures.dart';

/// Committing on the Collections tab, then going back to Home.
///
/// The two tabs are alive at once inside the shell's [IndexedStack], so Home is
/// not rebuilt by being returned to — it is only ever as fresh as the last
/// thing that invalidated it. Everything here is about that: a change made on
/// one tab has to reach the other without the user knowing which provider is
/// behind either.
void main() {
  late TestDatabases dbs;
  late WirdiData data;

  const CollectionId mixed = BuiltinCollectionId(mixedCollectionId);

  /// A Friday, so "today" and "Fridays only" are the same day.
  final DateTime now = DateTime(2026, 9, 4, 9);

  setUp(() async {
    dbs = await TestDatabases.open();
    data = WirdiData(content: dbs.content, user: dbs.user, clock: () => now);
  });

  tearDown(() => dbs.close());

  Future<void> settle(WidgetTester tester) async {
    for (int frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          wirdiDataProvider.overrideWithValue(data),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          theme: WirdiTheme.light(),
          onGenerateRoute: WirdiRouter.onGenerateRoute,
          initialRoute: Routes.shell,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await settle(tester);
  }

  /// Opens [name]'s page from the list and comes back to the list after
  /// [then] has run on it.
  Future<void> onPage(
    WidgetTester tester,
    String name,
    Future<void> Function() then,
  ) async {
    await tester.tap(find.text(name));
    await settle(tester);
    await then();
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
  }

  /// Commits [name] from its page, taking the sheet's defaults: Today, every
  /// day.
  Future<void> commitFromPage(WidgetTester tester, String name) =>
      onPage(tester, name, () async {
        await tester.tap(find.widgetWithText(OutlinedButton, 'Add to Home'));
        await settle(tester);
        await tester.tap(find.text('Commit'));
        await settle(tester);
      });

  const String builtin = 'PLACEHOLDER collection 1 english';

  testWidgets('a collection committed on Collections is on Home', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Nothing committed yet'), findsOneWidget);

    await openTab(tester, 'Collections');
    await commitFromPage(tester, builtin);
    await openTab(tester, 'Home');

    // The whole point of the tab: what was just committed is on it.
    expect(find.text('Nothing committed yet'), findsNothing);
    expect(find.byType(CollectionTile), findsOneWidget);
  });

  testWidgets('a commitment removed on Collections leaves Home', (
    WidgetTester tester,
  ) async {
    await dbs
        .userRepository(clock: () => now)
        .commit(mixed, DailySection.today);

    await pumpApp(tester);
    expect(find.byType(CollectionTile), findsOneWidget);

    await openTab(tester, 'Collections');
    await onPage(tester, builtin, () async {
      await tester.tap(find.widgetWithText(TextButton, 'Remove from Home'));
      await settle(tester);
    });
    await openTab(tester, 'Home');

    expect(find.byType(CollectionTile), findsNothing);
    expect(find.text('Nothing committed yet'), findsOneWidget);
  });

  testWidgets('changing when it falls reaches Home too', (
    WidgetTester tester,
  ) async {
    // Committed to a day that is not today, so it starts off the screen.
    await dbs
        .userRepository(clock: () => now)
        .commit(
          mixed,
          DailySection.today,
          days: Weekdays.of(<int>[DateTime.monday]),
        );

    await pumpApp(tester);
    expect(find.byType(CollectionTile), findsNothing);

    // Moved to Fridays, which is what today is.
    await openTab(tester, 'Collections');
    await onPage(tester, builtin, () async {
      await tester.tap(find.widgetWithText(TextButton, 'Change'));
      await settle(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is Text && widget.semanticsLabel == 'Monday',
        ),
      );
      await settle(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is Text && widget.semanticsLabel == 'Friday',
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
    });

    await openTab(tester, 'Home');
    expect(find.byType(CollectionTile), findsOneWidget);
  });

  testWidgets('a collection made on Collections and committed is on Home', (
    WidgetTester tester,
  ) async {
    // The path the bug was reported on: make one, then commit it.
    await pumpApp(tester);
    await openTab(tester, 'Collections');

    await tester.tap(find.byTooltip('New'));
    await settle(tester);
    // The menu's, and not the empty state's button of the same name.
    await tester.tap(find.text('New collection').last);
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Surah al-Kahf',
    );
    await settle(tester);
    await tester.tap(find.text('Create'));
    await settle(tester);

    // Creating lands in the editor; back out of it to the list, which has
    // turned to Yours, where the new collection is.
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    await commitFromPage(tester, 'Surah al-Kahf');
    await openTab(tester, 'Home');

    expect(find.text('Surah al-Kahf'), findsOneWidget);
  });

  group('editing a committed collection', () {
    /// Commits [name], made fresh, and returns to the collections list.
    Future<void> makeAndCommit(WidgetTester tester, String name) async {
      await tester.tap(find.byTooltip('New'));
      await settle(tester);
      // The menu's, and not the empty state's button of the same name.
      await tester.tap(find.text('New collection').last);
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Name'), name);
      await settle(tester);
      await tester.tap(find.text('Create'));
      await settle(tester);
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      await commitFromPage(tester, name);
    }

    testWidgets('renaming it renames the tile', (WidgetTester tester) async {
      await pumpApp(tester);
      await openTab(tester, 'Collections');
      await makeAndCommit(tester, 'Surah al-Kahf');

      await openTab(tester, 'Home');
      expect(find.text('Surah al-Kahf'), findsOneWidget);

      // Back to the list, through its page into the editor, rename.
      await openTab(tester, 'Collections');
      await tester.tap(find.text('Surah al-Kahf'));
      await settle(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
      await settle(tester);
      // The name lives in the editor's own overflow menu, alongside the
      // description the same form asks for.
      await tester.tap(find.byTooltip('More').last);
      await settle(tester);
      await tester.tap(find.text('Edit details'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Al-Kahf, Fridays');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      // Out of the editor, and out of the page.
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);

      await openTab(tester, 'Home');
      expect(find.text('Al-Kahf, Fridays'), findsOneWidget);
      expect(find.text('Surah al-Kahf'), findsNothing);
    });

    testWidgets('deleting it takes the tile off Home', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await openTab(tester, 'Collections');
      await makeAndCommit(tester, 'Surah al-Kahf');

      await openTab(tester, 'Home');
      expect(find.byType(CollectionTile), findsOneWidget);

      await openTab(tester, 'Collections');
      await tester.tap(find.text('Surah al-Kahf'));
      await settle(tester);
      await tester.tap(find.byTooltip('More'));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.tap(find.text('Delete').last);
      await settle(tester);
      // The page closes itself: what it was about is gone.
      expect(find.text('Surah al-Kahf'), findsNothing);

      await openTab(tester, 'Home');
      expect(find.byType(CollectionTile), findsNothing);
    });
  });
}
