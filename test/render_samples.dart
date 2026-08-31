/// Renders the dev screen to PNGs, with the real fonts loaded.
///
/// Not a test, and not run by `flutter test` — that only picks up
/// `*_test.dart`. Run it by name when there is no device to hand:
///
/// ```bash
/// flutter test test/render_samples.dart   # -> build/render/*.png
/// ```
///
/// It is not a substitute for looking at a phone. What it is good for is the
/// class of problem that is obvious in a picture and invisible in a widget
/// test: text laid out in the wrong place, a line height that collides, a
/// missing glyph. Both of those have already turned up here — right-to-left
/// text parked against the left margin, and Amiri Quran's tofu where the
/// Uthmani text uses U+065E.
///
/// The fallback caveat matters when reading the output: nothing is loaded here
/// but the three bundled families, so a character none of them has renders as
/// an empty box. On a real device Skia would fall back to a system Arabic face
/// for it instead, which is harder to spot and no more correct.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/content_database.dart';
import 'package:wirdi/data/user_database.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/providers/settings.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/wirdi_app.dart';

/// Where the PNGs go. Under build/, which is gitignored.
const String outputDirectory = 'build/render';

Future<void> loadFont(String family, List<String> paths) async {
  final FontLoader loader = FontLoader(family);
  for (final String path in paths) {
    loader.addFont(
      File(path).readAsBytes().then(
        (List<int> b) => ByteData.view(Uint8List.fromList(b).buffer),
      ),
    );
  }
  await loader.load();
}

const Key shotKey = Key('shot');

Future<void> shoot(WidgetTester tester, String name) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(shotKey));
  // Both the rasterisation and the encode have to happen inside runAsync;
  // toByteData never completes on the fake async zone.
  await tester.binding.runAsync<void>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData png = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!;
    final File out = File('$outputDirectory/$name.png');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(png.buffer.asUint8List(), flush: true);
    image.dispose();
  });
}

WirdiData? _shared;

class _Wrapped extends StatelessWidget {
  const _Wrapped();

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: <Override>[wirdiDataProvider.overrideWithValue(_shared!)],
    child: const WirdiApp(),
  );
}

void main() {
  late WirdiData data;

  setUpAll(() async {
    await loadFont('Amiri Quran', <String>[
      'assets/fonts/AmiriQuran-Regular.ttf',
    ]);
    await loadFont('Noto Naskh Arabic', <String>[
      'assets/fonts/NotoNaskhArabic-Regular.ttf',
      'assets/fonts/NotoNaskhArabic-Bold.ttf',
    ]);
    await loadFont('Inter', <String>[
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Medium.ttf',
    ]);
  });

  setUp(() {
    data = WirdiData(
      content: ContentDatabase.openReadOnly(File('content/build/content.db')),
      user: UserDatabase.memory(),
    );
    _shared = data;
  });
  tearDown(() => data.close());

  testWidgets('renders the dev screen in every mode', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const RepaintBoundary(key: shotKey, child: _Wrapped()),
    );
    await tester.pumpAndSettle();
    await shoot(tester, 'light');

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(WirdiApp)),
    );
    final SettingsController settings = container.read(
      settingsProvider.notifier,
    );

    await settings.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    await shoot(tester, 'dark');

    await settings.setThemeMode(ThemeMode.light);
    await settings.setQuranInGold(false);
    await tester.pumpAndSettle();
    await shoot(tester, 'cedar');

    await settings.setQuranInGold(true);
    await settings.setArabicFace(ArabicFace.quran);
    await tester.pumpAndSettle();

    // Scroll to a dense one and look at it in both faces.
    await tester.scrollUntilVisible(
      find.text('2:255'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await shoot(tester, 'kursi_amiri');

    await settings.setArabicFace(ArabicFace.naskh);
    await tester.pumpAndSettle();
    await shoot(tester, 'kursi_naskh');

    await settings.setArabicFace(ArabicFace.quran);
    await settings.setDimBrackets(false);
    await tester.pumpAndSettle();
    await shoot(tester, 'kursi_plain');
  });
}
