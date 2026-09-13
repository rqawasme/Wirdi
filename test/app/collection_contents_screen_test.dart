import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/collections/picked_item.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/providers/editing.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/screens/collection_contents_screen.dart';
import 'package:wirdi/theme/theme.dart';

import '../support/fixtures.dart';

/// The contents screen: what a collection holds, and what one item says.
void main() {
  late TestDatabases dbs;
  late WirdiData data;

  const CollectionId mixed = BuiltinCollectionId(mixedCollectionId);
  const CollectionId simple = BuiltinCollectionId(simpleCollectionId);

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

  Future<void> pumpContents(WidgetTester tester, CollectionId id) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
        child: MaterialApp(
          theme: WirdiTheme.light(),
          onGenerateRoute: WirdiRouter.onGenerateRoute,
          home: CollectionContentsScreen(collectionId: id),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('lists every entry, in the order it is recited', (
    WidgetTester tester,
  ) async {
    await pumpContents(tester, mixed);

    expect(find.text('PLACEHOLDER dhikr 1001 arabic'), findsOneWidget);
    expect(find.text('Ayah 2:255'), findsOneWidget);
    expect(find.text('PLACEHOLDER surah 112 transliterated'), findsOneWidget);
  });

  testWidgets('a repeat block is drawn as one group, not three loose rows', (
    WidgetTester tester,
  ) async {
    await pumpContents(tester, mixed);

    expect(find.text('Repeated 3 times'), findsOneWidget);
  });

  testWidgets('the count is shown where an item is said more than once', (
    WidgetTester tester,
  ) async {
    await pumpContents(tester, mixed);

    // dhikr 1002 carries a count_override of 100 over its default_count of 33.
    expect(find.text('×100'), findsOneWidget);
  });

  testWidgets('the description is shown, and nothing when there is none', (
    WidgetTester tester,
  ) async {
    await pumpContents(tester, mixed);
    expect(find.text('PLACEHOLDER collection 1 description'), findsOneWidget);

    await pumpContents(tester, simple);
    expect(find.text('PLACEHOLDER collection 2 description'), findsNothing);
    // The author still is: attribution belongs on a collection's own page.
    expect(find.text('PLACEHOLDER collection 2 author'), findsOneWidget);
  });

  /// Scoped to the sheet, because the row that opened it is still behind it
  /// showing the same text. What the sheet adds is the whole of the item, not
  /// the two clipped lines the row had room for.
  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet), matching: finder);

  group('the item sheet', () {
    testWidgets('a dhikr opens with its Arabic and its translation', (
      WidgetTester tester,
    ) async {
      await pumpContents(tester, mixed);

      await tester.tap(find.text('PLACEHOLDER dhikr 1001 arabic').first);
      await settle(tester);

      expect(inSheet(find.text('Dhikr')), findsOneWidget);
      expect(
        inSheet(find.text('PLACEHOLDER dhikr 1001 arabic')),
        findsOneWidget,
      );
      expect(
        inSheet(find.text('PLACEHOLDER dhikr 1001 translation')),
        findsOneWidget,
      );
    });

    testWidgets('an ayah opens named by its surah', (
      WidgetTester tester,
    ) async {
      await pumpContents(tester, mixed);

      await tester.tap(find.text('Ayah 2:255'));
      await settle(tester);

      expect(
        inSheet(find.text('PLACEHOLDER surah 2 transliterated 2:255')),
        findsOneWidget,
      );
      expect(inSheet(find.text('Single ayah')), findsOneWidget);
    });

    testWidgets('a surah opens with its verses, expanded on the way in', (
      WidgetTester tester,
    ) async {
      await pumpContents(tester, mixed);

      await tester.tap(find.text('PLACEHOLDER surah 112 transliterated'));
      await settle(tester);

      // A SurahItem resolves to metadata only — this is where the expansion
      // the domain defers actually happens.
      expect(inSheet(find.text('Surah 112 · 4 ayahs')), findsOneWidget);
      expect(
        inSheet(find.textContaining('PLACEHOLDER ayah 112:1')),
        findsWidgets,
      );
    });

    testWidgets('an item note rides along with the item', (
      WidgetTester tester,
    ) async {
      await pumpContents(tester, mixed);

      // Dhikr 1003 is the one the fixture gives a note.
      await tester.tap(find.text('PLACEHOLDER dhikr 1003 arabic').first);
      await settle(tester);

      expect(inSheet(find.text('PLACEHOLDER item note')), findsOneWidget);
    });
  });

  testWidgets('an empty collection of the user\'s own says so', (
    WidgetTester tester,
  ) async {
    final UserCollectionId empty = await data.collectionRepository.create(
      'Nothing in it',
    );
    await pumpContents(tester, empty);

    expect(find.text('Nothing in this collection yet'), findsOneWidget);
  });

  testWidgets('an item whose content is gone is counted, not hidden', (
    WidgetTester tester,
  ) async {
    final UserCollectionId id = await data.collectionRepository.create('Mine');
    await data.collectionRepository.addItem(id, const ContentRef.dhikr(1001));
    // A dhikr a content update removed: the row stays, the content is gone.
    await data.collectionRepository.addItem(id, const ContentRef.dhikr(9999));
    await pumpContents(tester, id);

    expect(
      find.textContaining('no longer in the content library'),
      findsOneWidget,
    );
  });

  testWidgets('it opens a collection of the user\'s own as readily as a '
      'built-in', (WidgetTester tester) async {
    final UserCollectionId id = await data.collectionRepository.create('Mine');
    await CollectionEditor(
      collections: data.collectionRepository,
      content: data.contentRepository,
    ).addItems(id, <PickedItem>[const PickedItem(ref: ContentRef.dhikr(1004))]);
    await pumpContents(tester, id);

    expect(find.text('PLACEHOLDER dhikr 1004 arabic'), findsOneWidget);
  });
}
