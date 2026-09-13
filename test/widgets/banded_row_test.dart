import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/screens/pickers/surah_picker_screen.dart';
import 'package:wirdi/screens/surah_list_screen.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/banded_row.dart';

import '../support/fixtures.dart';

/// Banding a long list, and the one list that deliberately does not get it.
void main() {
  Future<void> pumpBands(WidgetTester tester, {required bool dark}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? WirdiTheme.dark() : WirdiTheme.light(),
        home: const Scaffold(
          body: Column(
            children: <Widget>[
              BandedRow(index: 0, child: SizedBox(height: 20)),
              BandedRow(index: 1, child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }

  List<Color?> bandColours(WidgetTester tester) => tester
      .widgetList<Material>(
        find.descendant(
          of: find.byType(BandedRow),
          matching: find.byType(Material),
        ),
      )
      .map((Material m) => m.color)
      .toList();

  testWidgets('consecutive rows are one tonal step apart, in light', (
    WidgetTester tester,
  ) async {
    await pumpBands(tester, dark: false);

    final List<Color?> colours = bandColours(tester);
    expect(colours, <Color>[
      WirdiColorSchemes.light.surface,
      WirdiColorSchemes.light.surfaceContainerLow,
    ]);
    // The guard that matters if the palette ever changes: the step has to be
    // visible at all. One rung, deliberately — but not zero rungs.
    expect(colours.first, isNot(colours.last));
  });

  testWidgets('and in dark, which is designed on its own terms', (
    WidgetTester tester,
  ) async {
    await pumpBands(tester, dark: true);

    final List<Color?> colours = bandColours(tester);
    expect(colours, <Color>[
      WirdiColorSchemes.dark.surface,
      WirdiColorSchemes.dark.surfaceContainerLow,
    ]);
    expect(colours.first, isNot(colours.last));
  });

  testWidgets('a Material and not a ColoredBox, so the ink still splashes', (
    WidgetTester tester,
  ) async {
    await pumpBands(tester, dark: false);

    // Every row in these lists is an InkWell, and a splash paints onto the
    // nearest enclosing Material. A ColoredBox here would swallow the ripple.
    expect(
      find.descendant(
        of: find.byType(BandedRow),
        matching: find.byType(Material),
      ),
      findsNWidgets(2),
    );
  });

  group('which lists get it', () {
    late TestDatabases dbs;
    late WirdiData data;

    setUp(() async {
      dbs = await TestDatabases.open();
      data = WirdiData(content: dbs.content, user: dbs.user);
    });

    tearDown(() => dbs.close());

    Future<void> pump(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
          child: MaterialApp(theme: WirdiTheme.light(), home: screen),
        ),
      );
      for (int frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('the surah picker bands', (WidgetTester tester) async {
      await pump(tester, const SurahPickerScreen());
      expect(find.byType(BandedRow), findsWidgets);
    });

    testWidgets('the mushaf list does not', (WidgetTester tester) async {
      // Both draw the same SurahRow, which is why the band is applied by the
      // list and not built into the row. A picker is a list you are scanning
      // for one row out of a hundred and fourteen; the mushaf list is a table
      // of contents, and a banded ground under Quran headings is ornament.
      await pump(tester, const SurahListScreen());
      expect(find.byType(BandedRow), findsNothing);
    });
  });
}
