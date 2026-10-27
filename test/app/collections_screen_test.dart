import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/content_database.dart' show CollectionsCompanion;
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/collections.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/screens/collection_contents_screen.dart';
import 'package:wirdi/screens/collections_screen.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/collection_row.dart';
import 'package:wirdi/widgets/collection_series_row.dart';

import '../support/fixtures.dart';

/// The collections list: what a row says, and where it goes.
void main() {
  late TestDatabases dbs;
  late WirdiData data;

  const CollectionId mixed = BuiltinCollectionId(mixedCollectionId);

  setUp(() async {
    dbs = await TestDatabases.open();
    data = WirdiData(content: dbs.content, user: dbs.user);
  });

  tearDown(() => dbs.close());

  Future<void> settle(WidgetTester tester) async {
    for (int frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpList(
    WidgetTester tester, {
    bool withRouter = false,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
        child: MaterialApp(
          theme: WirdiTheme.light(),
          // The body on its own for what a row says, and the whole shell for
          // where a row goes. CollectionsScreen has no Scaffold of its own any
          // more — the app bar and the navigation bar belong to AppShell — so
          // the bare pump supplies one.
          home: withRouter ? null : const Scaffold(body: CollectionsScreen()),
          onGenerateRoute: withRouter ? WirdiRouter.onGenerateRoute : null,
          initialRoute: withRouter ? Routes.shell : null,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
        ),
      ),
    );
    await settle(tester);
    if (withRouter) {
      // The shell opens on Home. The collections list is a tab away.
      await tester.tap(find.text('Collections'));
      await settle(tester);
    }
  }

  testWidgets('lists the built-ins with their item counts', (
    WidgetTester tester,
  ) async {
    await pumpList(tester);

    expect(find.text('PLACEHOLDER collection 1 english'), findsOneWidget);
    expect(find.text('PLACEHOLDER collection 2 english'), findsOneWidget);
    // Items as the collection is written: four loose items, one repeat block
    // and a trailing dhikr. The block's nine playback steps are the player's
    // business, not the list's.
    expect(find.text('6 items'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets('says nothing about a collection that has not been started', (
    WidgetTester tester,
  ) async {
    await pumpList(tester);

    expect(find.textContaining('Done today'), findsNothing);
    expect(find.textContaining('Part-way'), findsNothing);
  });

  testWidgets('marks a collection completed today, quietly', (
    WidgetTester tester,
  ) async {
    await dbs.userRepository().logCompletion(mixed, DateTime.now());

    await pumpList(tester);

    // The mark is part of the meta line rather than a component of its own,
    // so this is the same paragraph as the item count.
    expect(find.textContaining('Done today'), findsOneWidget);
    // A small check in the same colour as the item count beside it, and no
    // other mark: a daily habit finished is the expected outcome.
    final Icon check = tester.widget<Icon>(find.byIcon(Icons.check));
    expect(check.color, WirdiTheme.light().colorScheme.onSurfaceVariant);
  });

  testWidgets('shows a collection that is part-way through', (
    WidgetTester tester,
  ) async {
    final ResolvedCollection resolved = await dbs
        .collectionRepository()
        .resolve(mixed);
    await dbs.userRepository().saveProgress(
      WirdProgress.atStep(
        collectionId: mixed,
        step: resolved.steps[3],
        currentCount: 0,
      ),
    );

    await pumpList(tester);

    expect(find.textContaining('Part-way through'), findsOneWidget);
  });

  testWidgets('a position at the very beginning is not progress', (
    WidgetTester tester,
  ) async {
    final ResolvedCollection resolved = await dbs
        .collectionRepository()
        .resolve(mixed);
    await dbs.userRepository().saveProgress(
      WirdProgress.atStep(
        collectionId: mixed,
        step: resolved.steps.first,
        currentCount: 0,
      ),
    );

    await pumpList(tester);

    // Nobody has done anything yet, and a row that says otherwise is a lie the
    // user cannot clear.
    expect(find.textContaining('Part-way through'), findsNothing);
  });

  testWidgets('a stale saved position does not show as progress', (
    WidgetTester tester,
  ) async {
    await dbs.userRepository().saveProgress(
      WirdProgress(
        collectionId: mixed,
        stepIndex: 8,
        // Not what sits at index 8 any more.
        stepRef: const ContentRef.dhikr(9999),
        currentCount: 2,
      ),
    );

    await pumpList(tester);

    // Validated through the same resumableFrom check the player makes, so the
    // list cannot promise a resume the player will then discard.
    expect(find.textContaining('Part-way through'), findsNothing);
  });

  testWidgets('a row opens the collection page, not the player', (
    WidgetTester tester,
  ) async {
    await pumpList(tester, withRouter: true);
    await tester.tap(find.text('PLACEHOLDER collection 1 english'));
    await settle(tester);

    // The actions the row used to carry, with their names on them.
    expect(find.widgetWithText(FilledButton, 'Recite'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Add to Home'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Make a copy'), findsOneWidget);
    // And the contents, not the player: no step counter, and the whole
    // collection on one screen rather than one item of it.
    expect(find.text('1 of 14'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Repeated 3 times'),
      200,
      // The page's own list: the shell's are still mounted under the route.
      scrollable: find
          .descendant(
            of: find.byType(CollectionContentsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('PLACEHOLDER dhikr 1001 arabic'), findsOneWidget);
  });

  testWidgets('a row has no buttons of its own', (WidgetTester tester) async {
    await pumpList(tester);

    final Finder row = find.ancestor(
      of: find.text('PLACEHOLDER collection 1 english'),
      matching: find.byType(CollectionRow),
    );
    // Four icons on every row was the complaint this answers. A menu button
    // is an IconButton underneath, so this covers the overflow too.
    expect(
      find.descendant(of: row, matching: find.byType(IconButton)),
      findsNothing,
    );
  });

  testWidgets('a row is one button a screen reader can press', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpList(tester);

    expect(
      tester.getSemantics(find.byType(CollectionRow).first),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        label: 'PLACEHOLDER collection 1 english, 6 items, not started today',
      ),
    );
    semantics.dispose();
  });

  testWidgets('the description is left to the collection page', (
    WidgetTester tester,
  ) async {
    await pumpList(tester);

    // Two lines of it on every row is what made the list a wall of text.
    expect(find.text('PLACEHOLDER collection 1 description'), findsNothing);
  });

  testWidgets('a collection on Home says so in words', (
    WidgetTester tester,
  ) async {
    await dbs.userRepository().commit(mixed, DailySection.morning);

    await pumpList(tester);

    // It was a filled house against an outlined one, which nobody could read.
    expect(find.textContaining('On Home · Morning'), findsOneWidget);
  });

  testWidgets('a commitment to some days names them', (
    WidgetTester tester,
  ) async {
    await dbs.userRepository().commit(
      mixed,
      DailySection.evening,
      days: Weekdays.of(<int>[DateTime.friday]),
    );

    await pumpList(tester);

    expect(find.textContaining('On Home · Evening · Fridays'), findsOneWidget);
  });

  group('the two shelves', () {
    testWidgets('opens on the Library before anything of the user\'s own', (
      WidgetTester tester,
    ) async {
      await pumpList(tester);

      final SegmentedButton<CollectionShelf> shelves = tester.widget(
        find.byType(SegmentedButton<CollectionShelf>),
      );
      expect(shelves.selected, <CollectionShelf>{CollectionShelf.library});
      expect(find.text('PLACEHOLDER collection 1 english'), findsOneWidget);
    });

    testWidgets('and on Yours once there is something', (
      WidgetTester tester,
    ) async {
      await dbs.collectionRepository().create('Mine');

      await pumpList(tester);

      expect(find.text('Mine'), findsOneWidget);
      // The built-ins are a tap away rather than under the user's own.
      expect(find.text('PLACEHOLDER collection 1 english'), findsNothing);
    });

    testWidgets('Yours holds the user\'s collections and adhkar', (
      WidgetTester tester,
    ) async {
      await pumpList(tester);
      await tester.tap(find.text('Yours'));
      await settle(tester);

      expect(find.text('Nothing of your own yet'), findsOneWidget);
      expect(find.text('None written yet'), findsOneWidget);
      expect(find.text('Write a dhikr'), findsOneWidget);
      expect(find.text('PLACEHOLDER collection 1 english'), findsNothing);
    });

    testWidgets('a new collection is offered at the foot of the user\'s own', (
      WidgetTester tester,
    ) async {
      await dbs.collectionRepository().create('Mine');

      await pumpList(tester);

      expect(find.widgetWithText(TextButton, 'New collection'), findsOneWidget);
    });
  });

  group('searching the library', () {
    testWidgets('narrows the list to what matches', (
      WidgetTester tester,
    ) async {
      await pumpList(tester);
      await tester.enterText(find.byType(TextField), 'collection 2');
      await settle(tester);

      expect(find.text('PLACEHOLDER collection 2 english'), findsOneWidget);
      expect(find.text('PLACEHOLDER collection 1 english'), findsNothing);
    });

    testWidgets('and says so when nothing does', (WidgetTester tester) async {
      await pumpList(tester);
      await tester.enterText(find.byType(TextField), 'nothing like it');
      await settle(tester);

      expect(
        find.text('Nothing in the library matches “nothing like it”.'),
        findsOneWidget,
      );
    });
  });

  group('a series', () {
    /// Three parts of one work: two said on set days and one on none.
    Future<void> seedSeries() async {
      Future<void> part(int id, int sortOrder, String name, int? weekday) => dbs
          .content
          .into(dbs.content.collections)
          .insert(
            CollectionsCompanion.insert(
              id: Value<int>(id),
              nameArabic: 'PLACEHOLDER part $id arabic',
              nameEnglish: name,
              type: 'wird',
              sortOrder: sortOrder,
              seriesNameEnglish: const Value<String>('PLACEHOLDER series'),
              seriesNameArabic: const Value<String>(
                'PLACEHOLDER series arabic',
              ),
              seriesWeekday: Value<int?>(weekday),
            ),
          );
      await part(31, 15, 'PLACEHOLDER series — Monday part', DateTime.monday);
      await part(32, 16, 'PLACEHOLDER series — Friday part', DateTime.friday);
      await part(33, 17, 'PLACEHOLDER series — Closing', null);
    }

    testWidgets('is one row, with its parts on it', (
      WidgetTester tester,
    ) async {
      await seedSeries();
      await pumpList(tester);

      expect(find.byType(CollectionSeriesRow), findsOneWidget);
      expect(find.text('PLACEHOLDER series'), findsOneWidget);
      // The parts are days, not rows of their own.
      expect(find.text('PLACEHOLDER series — Monday part'), findsNothing);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      // A part on no set day is a line under the week, named without the
      // series' name in front of it.
      expect(find.textContaining('Closing'), findsOneWidget);
    });

    testWidgets('a day opens its own part', (WidgetTester tester) async {
      await seedSeries();
      await pumpList(tester, withRouter: true);
      await tester.tap(find.text('Fri'));
      await settle(tester);

      expect(
        find.widgetWithText(AppBar, 'PLACEHOLDER series — Friday part'),
        findsOneWidget,
      );
    });

    testWidgets('a search for a part finds the series', (
      WidgetTester tester,
    ) async {
      await seedSeries();
      await pumpList(tester);
      await tester.enterText(find.byType(TextField), 'friday');
      await settle(tester);

      expect(find.text('PLACEHOLDER series'), findsOneWidget);
      expect(find.text('PLACEHOLDER collection 1 english'), findsNothing);
    });
  });

  group('the shapes a row has to survive', () {
    testWidgets('a row keeps its names and its meta line at the largest text '
        'scale', (WidgetTester tester) async {
      await dbs.userRepository().commit(mixed, DailySection.morning);
      await pumpList(tester, textScaler: const TextScaler.linear(2));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('PLACEHOLDER collection 1 english'),
        200,
        // The list's, and not the search field's own.
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);

      final Finder row = find.ancestor(
        of: find.text('PLACEHOLDER collection 1 english'),
        matching: find.byType(CollectionRow),
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('items')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('On Home')),
        findsOneWidget,
      );
    });
  });
}
