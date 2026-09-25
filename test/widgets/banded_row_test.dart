import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/screens/collections_screen.dart';
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

  List<int> bandColours(WidgetTester tester) => tester
      .widgetList<Material>(
        find.descendant(
          of: find.byType(BandedRow),
          matching: find.byType(Material),
        ),
      )
      // Compared as packed 8-bit rather than as Color objects: a blended colour
      // carries floating-point channels, and comparing it to a const Color
      // fails on the last decimal place while looking identical on screen.
      .map((Material m) => m.color!.toARGB32())
      .toList();

  /// How far a colour is from grey.
  ///
  /// The discriminator between a brick wash and a rung of the limestone ladder,
  /// and not the obvious one: the ladder is itself warm — the palette steps it
  /// by about -5 red, -7 green, -11 blue per rung — so "the blue channel falls
  /// further than the red" is true of both and separates nothing. What the wash
  /// actually does is pull the band further from grey than any neutral rung
  /// goes.
  int chroma(int argb) {
    final int r = (argb >> 16) & 0xFF;
    final int g = (argb >> 8) & 0xFF;
    final int b = argb & 0xFF;
    return <int>[r, g, b].reduce((int a, int b) => a > b ? a : b) -
        <int>[r, g, b].reduce((int a, int b) => a < b ? a : b);
  }

  testWidgets('odd rows carry a wash of brick, in light', (
    WidgetTester tester,
  ) async {
    await pumpBands(tester, dark: false);

    final List<int> colours = bandColours(tester);
    // Pinned rather than recomputed: asserting WirdiColorSchemes.band() here
    // would be the implementation restating itself. This is the decision.
    expect(colours, <int>[
      WirdiColorSchemes.light.surface.toARGB32(),
      0xFFF4E8DD,
    ]);
    // The step has to be visible at all — faint, deliberately, but not absent.
    expect(colours.first, isNot(colours.last));

    // And it is brick, not another rung of the neutral ladder. This is the
    // assertion that fails if the band is quietly put back on
    // surfaceContainerLow; the pin above would only say something changed.
    expect(
      chroma(colours.last),
      greaterThan(
        chroma(WirdiColorSchemes.light.surfaceContainerLow.toARGB32()),
      ),
    );
  });

  testWidgets('and in dark, which is designed on its own terms', (
    WidgetTester tester,
  ) async {
    await pumpBands(tester, dark: true);

    final List<int> colours = bandColours(tester);
    // Half the tint of the light band: dark is keeping the weight the neutral
    // rung already had and only picking up the warmth.
    expect(colours, <int>[
      WirdiColorSchemes.dark.surface.toARGB32(),
      0xFF201712,
    ]);
    expect(colours.first, isNot(colours.last));
    expect(
      chroma(colours.last),
      greaterThan(
        chroma(WirdiColorSchemes.dark.surfaceContainerLow.toARGB32()),
      ),
    );
  });

  test('the band is the surface carried toward brick, by the tint', () {
    // What "a wash of brick" means arithmetically, in both themes: every
    // channel moves from the surface toward primary by the same fraction, and
    // that fraction is the tint. A neutral rung cannot satisfy this — the
    // ladder's steps are not proportional to the distance to brick.
    for (final (ColorScheme scheme, double tint) in <(ColorScheme, double)>[
      (WirdiColorSchemes.light, WirdiColorSchemes.lightBandTint),
      (WirdiColorSchemes.dark, WirdiColorSchemes.darkBandTint),
    ]) {
      final int band = WirdiColorSchemes.band(scheme).toARGB32();
      final int surface = scheme.surface.toARGB32();
      final int primary = scheme.primary.toARGB32();

      for (final int shift in <int>[16, 8, 0]) {
        final int s = (surface >> shift) & 0xFF;
        final int p = (primary >> shift) & 0xFF;
        final int b = (band >> shift) & 0xFF;
        expect(
          (b - (s + (p - s) * tint)).abs(),
          lessThanOrEqualTo(1),
          reason: 'channel at bit $shift is not $tint of the way to brick',
        );
      }
    }
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

    testWidgets('the collections list bands', (WidgetTester tester) async {
      // A body without a Scaffold of its own; AppShell supplies one in the app.
      await pump(tester, const Scaffold(body: CollectionsScreen()));
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
