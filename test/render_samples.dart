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

import 'dart:async';
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
import 'package:wirdi/routes.dart';
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

/// Pumps a fixed run of frames rather than settling.
///
/// `pumpAndSettle` waits for the tree to stop scheduling frames, and a
/// [CircularProgressIndicator] never stops — so on any screen that shows one
/// while its data loads, settling hangs until the ten-minute timeout. Half a
/// second of frames covers a route transition and a local database read.
Future<void> settle(WidgetTester tester) async {
  for (int frame = 0; frame < 32; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

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

  /// Pumps the whole app and shoots each screen.
  testWidgets('renders every screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const RepaintBoundary(key: shotKey, child: _Wrapped()),
    );
    await settle(tester);
    await shoot(tester, '01-surah-list');

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(WirdiApp)),
    );
    final SettingsController settings = container.read(
      settingsProvider.notifier,
    );

    Future<void> openSurah(int number, String name) async {
      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      // Not awaited: pushNamed completes when the route is *popped*, so
      // awaiting it here would wait for the pop two lines down.
      unawaited(
        navigator.pushNamed<void>(
          Routes.reading,
          arguments: ReadingArguments(surahNumber: number),
        ),
      );
      await settle(tester);
      await shoot(tester, name);
      navigator.pop();
      await settle(tester);
    }

    // Al-Fatiha: the basmala is verse 1, numbered like any other.
    await openSurah(1, '02-reading-al-fatiha');
    // Al-Baqarah: the basmala is a heading, and the surah is the long one.
    await openSurah(2, '03-reading-al-baqarah');
    // At-Tawbah: no basmala at all.
    await openSurah(9, '04-reading-at-tawbah');
    // A sajdah mark.
    await openSurah(32, '05-reading-as-sajdah');

    // The reading view at the largest Arabic size the slider offers.
    await settings.setArabicScale(40 / WirdiTypography.quranVerseSize);
    await settle(tester);
    await openSurah(2, '06-reading-arabic-40');
    await settings.setArabicScale(1);

    // Arabic alone.
    await settings.setShowTranslation(false);
    await settle(tester);
    await openSurah(2, '07-reading-no-translation');
    await settings.setShowTranslation(true);

    // Dark.
    await settings.setThemeMode(ThemeMode.dark);
    await settle(tester);
    await openSurah(2, '08-reading-dark');
    await settings.setThemeMode(ThemeMode.light);
    await settle(tester);

    Future<void> openRoute(String route, String name) async {
      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      unawaited(navigator.pushNamed<void>(route));
      await settle(tester);
      await shoot(tester, name);
      navigator.pop();
      await settle(tester);
    }

    await openRoute(Routes.settings, '09-settings');
    await openRoute(Routes.about, '10-about');
    await openRoute(Routes.dev, '11-dev-screen');
  });
}
