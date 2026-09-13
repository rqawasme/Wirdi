import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/collections/picked_item.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/screens/pickers/from_collection_picker_screen.dart';
import 'package:wirdi/widgets/banded_row.dart';
import 'package:wirdi/widgets/dhikr_row.dart';
import 'package:wirdi/theme/theme.dart';

import '../support/fixtures.dart';

/// Picking a dhikr by browsing the wird it came out of.
///
/// The other way in is the flat searchable list. This one is for somebody who
/// knows which wird they want and not which words.
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

  List<PickedItem>? picked;

  Future<void> pumpPicker(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    picked = null;

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
        child: MaterialApp(
          theme: WirdiTheme.light(),
          onGenerateRoute: WirdiRouter.onGenerateRoute,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    picked = await Navigator.push<List<PickedItem>>(
                      context,
                      MaterialPageRoute<List<PickedItem>>(
                        builder: (BuildContext _) =>
                            const FromCollectionPickerScreen(),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await settle(tester);
  }

  testWidgets('it is titled as the sheet labels it', (
    WidgetTester tester,
  ) async {
    await pumpPicker(tester);

    // The screen and the option that opens it say the same thing. "Add a
    // dhikr" is the other picker now.
    expect(find.text('From collection'), findsOneWidget);
    expect(find.text('Add a dhikr'), findsNothing);
  });

  testWidgets('the built-ins are the way in, and they are banded', (
    WidgetTester tester,
  ) async {
    await pumpPicker(tester);

    expect(find.text('PLACEHOLDER collection 1 english'), findsOneWidget);
    expect(find.text('PLACEHOLDER collection 2 english'), findsOneWidget);
    expect(find.byType(BandedRow), findsNWidgets(2));
  });

  testWidgets('it draws the same row the flat picker does', (
    WidgetTester tester,
  ) async {
    await pumpPicker(tester);
    await tester.tap(find.text('PLACEHOLDER collection 1 english'));
    await settle(tester);

    // Shared rather than copied: two lists offering the same choice should not
    // draw it two ways.
    expect(find.byType(DhikrRow), findsWidgets);
    expect(find.byType(BandedRow), findsWidgets);
  });

  testWidgets('a collection made of Quran says so rather than showing nothing', (
    WidgetTester tester,
  ) async {
    // A surah set is a legitimate built-in — the content build ships them —
    // and browsing one for adhkar finds none. Neither fixture collection is
    // one, so this seeds a third rather than leaving the state unexercised.
    await dbs.content.customStatement(
      'INSERT INTO collections '
      '(id, name_arabic, name_english, description, author, type, sort_order) '
      "VALUES (3, 'x', 'PLACEHOLDER surah set english', NULL, NULL, "
      "'surah_set', 30)",
    );
    await dbs.content.customStatement(
      'INSERT INTO collection_items '
      '(id, collection_id, item_type, item_id, position) '
      "VALUES (900, 3, 'surah', 112, 1)",
    );

    await pumpPicker(tester);
    await tester.tap(find.text('PLACEHOLDER surah set english'));
    await settle(tester);

    expect(find.text('No adhkar here'), findsOneWidget);
    expect(
      find.textContaining('is made of Quran, not of adhkar'),
      findsOneWidget,
    );
    expect(find.byType(DhikrRow), findsNothing);
  });

  testWidgets('picking pops with the dhikr at its own default count', (
    WidgetTester tester,
  ) async {
    await pumpPicker(tester);
    await tester.tap(find.text('PLACEHOLDER collection 2 english'));
    await settle(tester);

    await tester.tap(find.text('PLACEHOLDER dhikr 1004 arabic'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    // Popped all the way out, through both steps of the picker.
    expect(picked, hasLength(1));
    expect(picked!.single.ref, const ContentRef.dhikr(1004));
    expect(picked!.single.count, isNull);
  });
}
