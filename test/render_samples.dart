/// Renders every screen to PNGs, with the real fonts loaded.
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
import 'package:wirdi/domain/domain.dart';
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

/// Loads a font the build bundled, by its asset key.
Future<void> loadBundledFont(String family, String key) async {
  final FontLoader loader = FontLoader(family);
  loader.addFont(rootBundle.load(key));
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
    // Out of the built bundle rather than off disk: it comes from the SDK, not
    // from this repository, and `uses-material-design: true` is what puts it
    // there. Loading it here is also how a missing-glyph icon shows up in the
    // PNGs, which is where this was caught — a widget test finds an Icon by
    // its IconData whether or not a font can draw it.
    await loadBundledFont('MaterialIcons', 'fonts/MaterialIcons-Regular.otf');
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
    await shoot(tester, '01-collections');

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(WirdiApp)),
    );
    final SettingsController settings = container.read(
      settingsProvider.notifier,
    );

    NavigatorState navigator() =>
        tester.state<NavigatorState>(find.byType(Navigator));

    /// Pushes a route, shoots it, and comes back.
    ///
    /// Not awaited: pushNamed completes when the route is *popped*, so
    /// awaiting it here would wait for the pop two lines down.
    Future<void> openRoute(
      String route,
      String name, {
      Object? arguments,
      Future<void> Function()? before,
    }) async {
      final NavigatorState nav = navigator();
      unawaited(nav.pushNamed<void>(route, arguments: arguments));
      await settle(tester);
      if (before != null) await before();
      await shoot(tester, name);
      nav.pop();
      await settle(tester);
    }

    /// Opens the player where the wird was left off, so a shot can show a step
    /// other than the first without counting all the way to it.
    Future<void> openPlayer(
      CollectionId id,
      String name, {
      int stepIndex = 0,
      int taps = 0,
    }) async {
      final ResolvedCollection resolved = await data.collectionRepository
          .resolve(id);
      if (stepIndex > 0) {
        await data.userRepository.saveProgress(
          WirdProgress.atStep(
            collectionId: id,
            step: resolved.steps[stepIndex],
            currentCount: 0,
          ),
        );
      } else {
        await data.userRepository.clearProgress(id);
      }

      await openRoute(
        Routes.player,
        name,
        arguments: PlayerArguments(collectionId: id),
        before: () async {
          for (int tap = 0; tap < taps; tap++) {
            // Anywhere in the content area counts; the reference line above
            // the text is inside it and is always on screen.
            await tester.tap(find.byType(SingleChildScrollView));
            await tester.pump();
          }
        },
      );
      await data.userRepository.clearProgress(id);
    }

    // The wird the content build ships: 39 adhkar, three of them said three
    // times over.
    const CollectionId wird = BuiltinCollectionId(2);
    await openPlayer(wird, '02-player-dhikr');
    // A step said three times, part-way counted, so the stripe has something
    // to show.
    await openPlayer(wird, '03-player-counting', stepIndex: 10, taps: 1);

    // The same wird's other two kinds of step: an ayah said seven times, and a
    // surah said three times over.
    await openPlayer(wird, '04-player-ayah', stepIndex: 40, taps: 2);
    await openPlayer(wird, '05-player-surah', stepIndex: 23);

    await settings.setThemeMode(ThemeMode.dark);
    await settle(tester);
    await openPlayer(wird, '06-player-dark', stepIndex: 10, taps: 2);
    await settings.setThemeMode(ThemeMode.light);
    await settle(tester);

    // The mushaf, a tap from home.
    await openRoute(Routes.surahList, '07-surah-list');

    Future<void> openSurah(int number, String name) async {
      final NavigatorState nav = navigator();
      unawaited(
        nav.pushNamed<void>(
          Routes.reading,
          arguments: ReadingArguments(surahNumber: number),
        ),
      );
      await settle(tester);
      await shoot(tester, name);
      nav.pop();
      await settle(tester);
    }

    // Al-Fatiha: the basmala is verse 1, numbered like any other.
    await openSurah(1, '08-reading-al-fatiha');
    // Al-Baqarah: the basmala is a heading, and the surah is the long one.
    await openSurah(2, '09-reading-al-baqarah');
    // At-Tawbah: no basmala at all.
    await openSurah(9, '10-reading-at-tawbah');
    // A sajdah mark.
    await openSurah(32, '11-reading-as-sajdah');

    // The reading view at the largest Arabic size the slider offers.
    await settings.setArabicScale(40 / WirdiTypography.quranVerseSize);
    await settle(tester);
    await openSurah(2, '12-reading-arabic-40');
    await settings.setArabicScale(1);

    // Arabic alone.
    await settings.setShowTranslation(false);
    await settle(tester);
    await openSurah(2, '13-reading-no-translation');
    await settings.setShowTranslation(true);

    // Dark.
    await settings.setThemeMode(ThemeMode.dark);
    await settle(tester);
    await openSurah(2, '14-reading-dark');
    await settings.setThemeMode(ThemeMode.light);
    await settle(tester);

    await openRoute(Routes.settings, '15-settings');
    await openRoute(Routes.about, '16-about');
    await openRoute(Routes.dev, '17-dev-screen');
  });
}
