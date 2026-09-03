import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/collections/collection_editing.dart';
import 'package:wirdi/collections/picked_item.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/providers/editing.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/screens/collection_edit_screen.dart';
import 'package:wirdi/theme/theme.dart';

import '../support/fixtures.dart';

/// The editor: what it shows, what it refuses, and how it says so.
void main() {
  late TestDatabases dbs;
  late WirdiData data;
  late CollectionEditor editor;
  late UserCollectionId id;

  setUp(() async {
    dbs = await TestDatabases.open();
    data = WirdiData(content: dbs.content, user: dbs.user);
    editor = CollectionEditor(
      collections: data.collectionRepository,
      content: data.contentRepository,
    );
    id = await editor.create('Mine');
  });

  tearDown(() => dbs.close());

  Future<void> settle(WidgetTester tester) async {
    for (int frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
        child: MaterialApp(
          theme: WirdiTheme.light(),
          onGenerateRoute: WirdiRouter.onGenerateRoute,
          home: CollectionEditScreen(collectionId: id),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> seedFourAdhkar() => editor.addItems(id, <PickedItem>[
    const PickedItem(ref: ContentRef.dhikr(1001)),
    const PickedItem(ref: ContentRef.dhikr(1002)),
    const PickedItem(ref: ContentRef.dhikr(1003)),
    const PickedItem(ref: ContentRef.dhikr(1004)),
  ]);

  Future<ResolvedCollection> resolve() => data.collectionRepository.resolve(id);

  testWidgets('an empty collection says so, with the stripe and a way out', (
    WidgetTester tester,
  ) async {
    await pumpEditor(tester);

    expect(find.text('Nothing in this collection yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add an item'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows each item, its count and its note', (
    WidgetTester tester,
  ) async {
    await editor.addItems(id, <PickedItem>[
      const PickedItem(
        ref: ContentRef.dhikr(1002),
        count: 100,
        note: 'PLACEHOLDER a note',
      ),
      const PickedItem(ref: ContentRef.ayah(2255)),
      const PickedItem(ref: ContentRef.surah(112)),
    ]);

    await pumpEditor(tester);

    expect(find.text('PLACEHOLDER dhikr 1002 arabic'), findsOneWidget);
    expect(find.text('×100'), findsOneWidget);
    expect(find.text('PLACEHOLDER a note'), findsOneWidget);
    expect(find.text('Ayah 2:255'), findsOneWidget);
    expect(find.text('PLACEHOLDER surah 112 transliterated'), findsOneWidget);
  });

  testWidgets('adds a surah through the picker, with a count', (
    WidgetTester tester,
  ) async {
    await pumpEditor(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Add an item'));
    await settle(tester);
    await tester.tap(find.text('Surah'));
    await settle(tester);

    expect(find.text('Add a surah'), findsOneWidget);
    await tester.tap(find.text('PLACEHOLDER surah 112 transliterated'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Count'), '3');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    final ResolvedCollection resolved = await resolve();
    final CollectionItemEntry item =
        resolved.entries.single as CollectionItemEntry;
    expect(item.ref, const ContentRef.surah(112));
    expect(item.count, 3);
    expect(find.text('×3'), findsOneWidget);
  });

  testWidgets('adds a range of ayahs, one item per ayah, in order', (
    WidgetTester tester,
  ) async {
    await pumpEditor(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Add an item'));
    await settle(tester);
    await tester.tap(find.text('Ayah'));
    await settle(tester);
    await tester.tap(find.text('PLACEHOLDER surah 1 transliterated'));
    await settle(tester);

    await tester.tap(find.text('A range of ayahs'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'From ayah'), '2');
    await tester.enterText(find.widgetWithText(TextField, 'To ayah'), '5');
    await settle(tester);

    expect(find.textContaining('Adds 4 ayahs'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);
    // The range screen has an Add of its own behind the dialog.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Add'),
      ),
    );
    await settle(tester);

    final ResolvedCollection resolved = await resolve();
    expect(
      resolved.entries.map(
        (CollectionEntry e) => (e as CollectionItemEntry).ref,
      ),
      <ContentRef>[
        ContentRef.ayahAt(1, 2),
        ContentRef.ayahAt(1, 3),
        ContentRef.ayahAt(1, 4),
        ContentRef.ayahAt(1, 5),
      ],
    );
  });

  testWidgets('adds a dhikr by browsing the collection it comes from', (
    WidgetTester tester,
  ) async {
    await pumpEditor(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Add an item'));
    await settle(tester);
    await tester.tap(find.text('Dhikr'));
    await settle(tester);

    // The built-ins, as the way in. There is no tagging and no search in this
    // content build, so a flat list of every dhikr would have nothing to sort
    // it by.
    expect(find.text('Add a dhikr'), findsOneWidget);
    expect(find.text('PLACEHOLDER collection 1 english'), findsOneWidget);
    await tester.tap(find.text('PLACEHOLDER collection 2 english'));
    await settle(tester);

    // Only the adhkar, with the collection's Quran items left out.
    expect(find.text('PLACEHOLDER dhikr 1004 arabic'), findsOneWidget);
    await tester.tap(find.text('PLACEHOLDER dhikr 1004 arabic'));
    await settle(tester);

    // Its own default_count is the hint, so leaving the field alone writes no
    // override at all.
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    final ResolvedCollection resolved = await resolve();
    final CollectionItemEntry item =
        resolved.entries.single as CollectionItemEntry;
    expect(item.ref, const ContentRef.dhikr(1004));
    expect(item.count, 7);
  });

  testWidgets('a repeat block\'s adhkar are offered flattened', (
    WidgetTester tester,
  ) async {
    await pumpEditor(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Add an item'));
    await settle(tester);
    await tester.tap(find.text('Dhikr'));
    await settle(tester);
    await tester.tap(find.text('PLACEHOLDER collection 1 english'));
    await settle(tester);

    // Four adhkar in that collection, and its surahs and ayahs are not adhkar.
    expect(find.text('PLACEHOLDER dhikr 1001 arabic'), findsOneWidget);
    expect(find.text('PLACEHOLDER dhikr 1002 arabic'), findsOneWidget);
    expect(find.text('PLACEHOLDER dhikr 1003 arabic'), findsOneWidget);
    expect(find.text('Repeated 3 times'), findsNothing);
    expect(find.text('Ayah 2:255'), findsNothing);
  });

  group('grouping', () {
    testWidgets('a contiguous run becomes one block', (
      WidgetTester tester,
    ) async {
      await seedFourAdhkar();
      await pumpEditor(tester);

      await tester.tap(find.byTooltip('More'));
      await settle(tester);
      await tester.tap(find.text('Repeat some items'));
      await settle(tester);

      await tester.tap(find.text('PLACEHOLDER dhikr 1002 arabic'));
      await tester.tap(find.text('PLACEHOLDER dhikr 1003 arabic'));
      await settle(tester);
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Repeat'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Times'), '7');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Repeat'));
      await settle(tester);

      expect(find.text('Repeated 7 times'), findsOneWidget);
      final ResolvedCollection resolved = await resolve();
      final RepeatBlock block = resolved.entries
          .whereType<RepeatBlock>()
          .single;
      expect(block.repeatCount, 7);
      expect(block.entries.length, 2);
      // Two loose items and two recited seven times over.
      expect(resolved.steps.length, 16);

      // Selection mode ends once the block is made.
      expect(find.text('2 selected'), findsNothing);
    });

    testWidgets('a non-contiguous selection is refused, in a sentence', (
      WidgetTester tester,
    ) async {
      await seedFourAdhkar();
      await pumpEditor(tester);

      await tester.tap(find.byTooltip('More'));
      await settle(tester);
      await tester.tap(find.text('Repeat some items'));
      await settle(tester);

      // First and third: adjacent on screen, not adjacent in the collection.
      await tester.tap(find.text('PLACEHOLDER dhikr 1001 arabic'));
      await tester.tap(find.text('PLACEHOLDER dhikr 1003 arabic'));
      await settle(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Repeat'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Repeat'));
      await settle(tester);

      // A sentence, not an ArgumentError. The repository's own refusal reads
      // "must be contiguous by position, but positions are [1, 3]".
      expect(
        find.text(
          'A repeat block has to be one unbroken run. '
          'Choose items that sit next to each other.',
        ),
        findsOneWidget,
      );
      expect((await resolve()).entries.whereType<RepeatBlock>(), isEmpty);

      // And the selection is still made, so it can be corrected rather than
      // started again.
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('a block ungroups back into its items', (
      WidgetTester tester,
    ) async {
      await seedFourAdhkar();
      final ResolvedCollection loose = await resolve();
      final List<String> ids = itemIdsInOrder(loose.entries);
      await editor.group(id, loose.entries, <String>{ids[1], ids[2]}, 3);

      await pumpEditor(tester);
      expect(find.text('Repeated 3 times'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Ungroup'));
      await settle(tester);

      expect(find.text('Repeated 3 times'), findsNothing);
      final ResolvedCollection after = await resolve();
      expect(after.entries.whereType<RepeatBlock>(), isEmpty);
      expect(after.entries.length, 4);
    });
  });

  testWidgets('removing an item takes it out and closes the gap', (
    WidgetTester tester,
  ) async {
    await seedFourAdhkar();
    await pumpEditor(tester);

    await tester.tap(find.byTooltip('Remove').at(1));
    await settle(tester);

    final ResolvedCollection after = await resolve();
    expect(after.entries.length, 3);
    expect(after.entries.map((CollectionEntry e) => e.position), <int>[
      1,
      2,
      3,
    ]);
    expect(find.text('PLACEHOLDER dhikr 1002 arabic'), findsNothing);
  });

  testWidgets('deleting asks first, and says what it keeps', (
    WidgetTester tester,
  ) async {
    await seedFourAdhkar();
    await pumpEditor(tester);

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Delete collection'));
    await settle(tester);

    expect(find.text('Delete Mine?'), findsOneWidget);
    expect(find.textContaining('days you completed are kept'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);

    expect(
      (await data.collectionRepository.all()).map(
        (CollectionSummary s) => s.id,
      ),
      isNot(contains(id)),
    );
  });

  testWidgets('renaming keeps the collection and its items', (
    WidgetTester tester,
  ) async {
    await seedFourAdhkar();
    await pumpEditor(tester);

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Rename'));
    await settle(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'After maghrib',
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    expect(find.text('After maghrib'), findsOneWidget);
    expect((await resolve()).entries.length, 4);
  });
}
