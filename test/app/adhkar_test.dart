import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/screens/adhkar_screen.dart';
import 'package:wirdi/screens/collection_edit_screen.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/empty_state.dart';

import '../support/fixtures.dart';

/// Writing adhkar of your own, and putting them in a collection.
///
/// The Arabic typed in here is placeholder text describing which row it is. No
/// dhikr text is invented anywhere in these tests.
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

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
        child: MaterialApp(
          theme: WirdiTheme.light(),
          onGenerateRoute: WirdiRouter.onGenerateRoute,
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  /// Fills the form's Arabic field and saves. The first field on the screen is
  /// the Arabic one, which is the one thing a dhikr cannot be written without.
  Future<void> writeDhikr(
    WidgetTester tester,
    String words, {
    int? count,
  }) async {
    await tester.enterText(find.byType(TextField).first, words);
    if (count != null) {
      await tester.enterText(
        find.widgetWithText(TextField, 'Times said'),
        '$count',
      );
    }
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await settle(tester);
  }

  group('the screen', () {
    testWidgets('says so when nothing has been written, and offers the form', (
      WidgetTester tester,
    ) async {
      await pump(tester, const AdhkarScreen());

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Nothing of your own yet'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Write a dhikr'));
      await settle(tester);
      expect(find.text('Write a dhikr'), findsWidgets);

      await writeDhikr(tester, 'PLACEHOLDER mine arabic');

      // Back on the list, with the dhikr on it and nothing holding it yet.
      expect(find.byType(EmptyState), findsNothing);
      expect(find.text('PLACEHOLDER mine arabic'), findsOneWidget);
      expect(find.text('In none of your collections'), findsOneWidget);
    });

    testWidgets('shows what a dhikr says and how often', (
      WidgetTester tester,
    ) async {
      await insertUserDhikr(
        dbs.user,
        id: testUuid(1),
        translation: 'PLACEHOLDER mine translation',
        defaultCount: 33,
      );
      await pump(tester, const AdhkarScreen());

      expect(
        find.text('PLACEHOLDER user dhikr ${testUuid(1)} arabic'),
        findsOneWidget,
      );
      expect(find.text('PLACEHOLDER mine translation'), findsOneWidget);
      expect(find.text('×33'), findsOneWidget);
    });

    testWidgets('an edit is shared by the collection that says it', (
      WidgetTester tester,
    ) async {
      final UserDhikrRef ref = await insertUserDhikr(
        dbs.user,
        id: testUuid(1),
        defaultCount: 3,
      );
      final UserCollectionId id = await data.collectionRepository.create(
        'Morning',
      );
      await data.collectionRepository.addItem(id, ref);

      await pump(tester, const AdhkarScreen());
      expect(find.text('In one collection'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Edit'));
      await settle(tester);
      // The form warns that an edit is not local to one collection.
      expect(
        find.text('Changes apply everywhere this dhikr is used.'),
        findsOneWidget,
      );

      await writeDhikr(tester, 'PLACEHOLDER edited arabic', count: 7);

      final ResolvedCollection resolved = await data.collectionRepository
          .resolve(id);
      final DhikrItem item = resolved.entries.single as DhikrItem;
      expect(item.dhikr.textArabic, 'PLACEHOLDER edited arabic');
      expect(item.count, 7);
    });

    testWidgets('deleting one names the collections it would leave', (
      WidgetTester tester,
    ) async {
      final UserDhikrRef ref = await insertUserDhikr(dbs.user, id: testUuid(1));
      final UserCollectionId id = await data.collectionRepository.create(
        'Morning',
      );
      await data.collectionRepository.addItem(id, ref);
      await data.collectionRepository.addItem(id, const ContentRef.dhikr(1001));

      await pump(tester, const AdhkarScreen());
      await tester.tap(find.byTooltip('Delete'));
      await settle(tester);

      expect(find.textContaining('Morning'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);

      // Gone from the list, and out of the collection, which is left with the
      // one item it had beside it and no hole where this one was.
      expect(find.byType(EmptyState), findsOneWidget);
      final ResolvedCollection resolved = await data.collectionRepository
          .resolve(id);
      expect(resolved.unresolved, isEmpty);
      expect(resolved.entries.single.position, 1);
    });

    testWidgets('backing out of the confirmation keeps it', (
      WidgetTester tester,
    ) async {
      await insertUserDhikr(dbs.user, id: testUuid(1));
      await pump(tester, const AdhkarScreen());

      await tester.tap(find.byTooltip('Delete'));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Keep it'));
      await settle(tester);

      expect(find.byType(EmptyState), findsNothing);
      expect(await data.userDhikrRepository.all(), hasLength(1));
    });
  });

  group('the form', () {
    testWidgets('will not save until there are words to save', (
      WidgetTester tester,
    ) async {
      await pump(tester, const AdhkarScreen());
      await tester.tap(find.widgetWithText(FilledButton, 'Write a dhikr'));
      await settle(tester);

      final Finder save = find.widgetWithText(TextButton, 'Save');
      expect(tester.widget<TextButton>(save).onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'PLACEHOLDER');
      await settle(tester);
      expect(tester.widget<TextButton>(save).onPressed, isNotNull);
    });

    testWidgets('refuses a paste that went wrong, in a sentence', (
      WidgetTester tester,
    ) async {
      await pump(tester, const AdhkarScreen());
      await tester.tap(find.widgetWithText(FilledButton, 'Write a dhikr'));
      await settle(tester);

      await writeDhikr(tester, 'ا' * 4001);

      expect(
        find.textContaining('longer than one dhikr can be'),
        findsOneWidget,
      );
      // Still on the form, with what was typed still in it.
      expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
      expect(await data.userDhikrRepository.all(), isEmpty);
    });

    testWidgets('an untranslated dhikr is saved, and listed by its Arabic', (
      WidgetTester tester,
    ) async {
      await pump(tester, const AdhkarScreen());
      await tester.tap(find.widgetWithText(FilledButton, 'Write a dhikr'));
      await settle(tester);
      await writeDhikr(tester, 'PLACEHOLDER untranslated arabic');

      expect(find.text('PLACEHOLDER untranslated arabic'), findsOneWidget);
      expect((await data.userDhikrRepository.all()).single.translation, isNull);
    });
  });

  group('adding one to a collection', () {
    late UserCollectionId collection;

    setUp(() async {
      collection = await data.collectionRepository.create('Mine');
    });

    /// Opens the editor's add sheet and takes the fifth door.
    Future<void> openYourAdhkar(WidgetTester tester) async {
      await pump(tester, CollectionEditScreen(collectionId: collection));
      await tester.tap(find.byTooltip('Add an item'));
      await settle(tester);
      await tester.tap(find.text('Your adhkar'));
      await settle(tester);
    }

    testWidgets('the sheet offers them, after the three content pickers', (
      WidgetTester tester,
    ) async {
      await pump(tester, CollectionEditScreen(collectionId: collection));
      await tester.tap(find.byTooltip('Add an item'));
      await settle(tester);

      for (final String tile in <String>[
        'Surah',
        'Ayah',
        'From collection',
        'Dhikr',
        'Your adhkar',
      ]) {
        expect(find.text(tile), findsOneWidget, reason: '$tile is missing');
      }
    });

    testWidgets('one written on the spot lands in the collection', (
      WidgetTester tester,
    ) async {
      await openYourAdhkar(tester);

      // Nothing written yet, so the picker is the way to the form rather than
      // a dead end.
      expect(find.byType(EmptyState), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Write a dhikr'));
      await settle(tester);
      await writeDhikr(tester, 'PLACEHOLDER on the spot arabic', count: 5);

      // Straight in, with no second question about the count: it was just
      // typed into the form.
      final ResolvedCollection resolved = await data.collectionRepository
          .resolve(collection);
      final DhikrItem item = resolved.entries.single as DhikrItem;
      expect(item.dhikr.textArabic, 'PLACEHOLDER on the spot arabic');
      expect(item.count, 5);
      expect(item.dhikr.ref, isA<UserDhikrRef>());

      // And it is on the editor's list, not behind a reload.
      expect(find.text('PLACEHOLDER on the spot arabic'), findsOneWidget);
    });

    testWidgets('one written earlier is added at the count you choose', (
      WidgetTester tester,
    ) async {
      await insertUserDhikr(dbs.user, id: testUuid(1), defaultCount: 3);
      await openYourAdhkar(tester);

      await tester.tap(
        find.text('PLACEHOLDER user dhikr ${testUuid(1)} arabic'),
      );
      await settle(tester);

      // The same count-and-note question the content pickers ask.
      await tester.enterText(find.widgetWithText(TextField, 'Count'), '100');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await settle(tester);

      final ResolvedCollection resolved = await data.collectionRepository
          .resolve(collection);
      expect((resolved.entries.single as DhikrItem).count, 100);
    });

    testWidgets('it can be recited: the player counts it like any other', (
      WidgetTester tester,
    ) async {
      final UserDhikrRef ref = await insertUserDhikr(
        dbs.user,
        id: testUuid(1),
        defaultCount: 3,
      );
      await data.collectionRepository.addItem(collection, ref);

      final ResolvedCollection resolved = await data.collectionRepository
          .resolve(collection);
      expect(resolved.steps, hasLength(1));
      expect(resolved.steps.single.count, 3);
      expect(resolved.steps.single.ref, ref);
      // The ref a step stores is the one progress is checked against, so it
      // has to survive the round trip through its string form.
      expect(ItemRef.parse(resolved.steps.single.ref.canonical), ref);
    });
  });
}
