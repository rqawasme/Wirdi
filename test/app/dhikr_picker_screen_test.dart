import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/collections/picked_item.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/screens/pickers/dhikr_picker_screen.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/dhikr_row.dart';

import '../support/fixtures.dart';

/// The flat dhikr picker: every dhikr there is, and the search over it.
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

  /// What the picker popped with, or null while it is still open.
  List<PickedItem>? picked;

  Future<void> pumpPicker(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
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
                        builder: (BuildContext _) => const DhikrPickerScreen(),
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

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await settle(tester);
  }

  testWidgets('opens on every dhikr there is', (WidgetTester tester) async {
    await pumpPicker(tester);

    // An empty query is every dhikr: this screen is a browse as much as a
    // search, and a list that starts empty has to be earned before it says
    // anything.
    expect(find.byType(DhikrRow), findsNWidgets(5));
  });

  testWidgets('a translation fragment narrows it', (WidgetTester tester) async {
    await pumpPicker(tester);
    await search(tester, '1004');

    expect(find.byType(DhikrRow), findsOneWidget);
    expect(find.text('PLACEHOLDER dhikr 1004 arabic'), findsOneWidget);
  });

  testWidgets('the match ignores case', (WidgetTester tester) async {
    await pumpPicker(tester);
    await search(tester, 'PLACEHOLDER');
    expect(find.byType(DhikrRow), findsNWidgets(5));

    await search(tester, 'placeholder');
    expect(find.byType(DhikrRow), findsNWidgets(5));
  });

  testWidgets('bare Arabic letters find text that carries the marks', (
    WidgetTester tester,
  ) async {
    await pumpPicker(tester);

    // Dhikr 1005 is the one row with real Arabic letters in it, vocalised.
    // Nobody types the harakat, so the bare letters have to be enough.
    await search(tester, String.fromCharCodes(<int>[0x0627, 0x0628, 0x064A]));

    expect(find.byType(DhikrRow), findsOneWidget);
    expect(find.text(foldableArabic), findsOneWidget);
  });

  testWidgets('clearing the search brings the list back', (
    WidgetTester tester,
  ) async {
    await pumpPicker(tester);
    await search(tester, '1004');
    expect(find.byType(DhikrRow), findsOneWidget);

    await tester.tap(find.byTooltip('Clear the search'));
    await settle(tester);

    expect(find.byType(DhikrRow), findsNWidgets(5));
  });

  testWidgets('no match says so rather than showing an empty list', (
    WidgetTester tester,
  ) async {
    await pumpPicker(tester);
    await search(tester, 'nothing by that name');

    expect(find.byType(DhikrRow), findsNothing);
    expect(find.text('Nothing matches that'), findsOneWidget);
  });

  testWidgets('picking pops with the dhikr at its own default count', (
    WidgetTester tester,
  ) async {
    await pumpPicker(tester);
    await search(tester, '1004');
    await tester.tap(find.byType(DhikrRow));
    await settle(tester);

    // Its own default_count is the hint, so leaving the field alone writes no
    // override at all.
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(picked, hasLength(1));
    expect(picked!.single.ref, const ContentRef.dhikr(1004));
    expect(picked!.single.count, isNull);
  });
}
