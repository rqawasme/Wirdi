/// Renders the phone screenshots for the Google Play listing.
///
/// Not a test, and not run by `flutter test` — that only picks up
/// `*_test.dart`. Run it by name, with the real content database built:
///
/// ```bash
/// python3 content/scripts/build_content.py
/// tool/sync_content_asset.sh
/// flutter test test/render_store_screenshots.dart   # -> assets/store/*.png
/// ```
///
/// Each image is a post: a headline, one line under it, and the real app on a
/// phone below them. The screens are the app itself, pumped with the real
/// fonts and the real content database the way `render_samples.dart` pumps
/// them, over a user database seeded here with a few weeks of somebody
/// keeping their adhkar — so what a post shows is what the app draws, not a
/// mock-up of it. The posts are composed in Flutter too, in the app's own
/// palette and type, so the whole set comes from one command and nothing but
/// the SDK.
///
/// They are 1080 × 1920: 9:16, which is what Play wants for a screenshot to be
/// eligible for its featured placements, and saved as 24-bit PNG with no alpha
/// channel, which is what Play accepts. They are dated: the home screen and
/// the tracker read today's date, so a rerun on another day gives other days.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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
import 'package:wirdi/widgets/bottom_nav.dart';
import 'package:wirdi/wirdi_app.dart';

/// Where the posts go. Committed: they are uploaded to Play Console by hand,
/// like the icon and the feature graphic beside them in `assets/icon/`.
const String outputDirectory = 'assets/store';

/// The phone the app is drawn on, in logical pixels.
///
/// A width most Android phones are within a few dp of, and a height a little
/// short of a current phone's, so that the whole screen — bar to bar — fits
/// under the headline at a size that can still be read in Play's carousel.
const Size screenSize = Size(400, 780);

/// What the status bar takes off the top of [screenSize], which the app pads
/// its app bars by and [_StatusBar] is drawn into.
const double statusBarHeight = 24;

/// Pixels per logical pixel of the screen as it lands in the post.
///
/// The screen is rasterised at exactly the size it is drawn at — 720 × 1404 —
/// so the post copies it pixel for pixel rather than resampling it.
const double screenScale = 1.8;

/// The post, in pixels. Drawn at a device pixel ratio of one, so every length
/// in [_Post] is a pixel.
const Size postSize = Size(1080, 1920);

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

/// A fixed run of frames rather than settling — see `render_samples.dart`: a
/// progress indicator never settles.
Future<void> settle(WidgetTester tester) async {
  for (int frame = 0; frame < 32; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Rasterises whatever is under [shotKey] at [pixelRatio].
Future<ui.Image> capture(WidgetTester tester, double pixelRatio) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(shotKey));
  // toImage never completes on the fake async zone.
  return (await tester.binding.runAsync<ui.Image>(
    () => boundary.toImage(pixelRatio: pixelRatio),
  ))!;
}

WirdiData? _shared;

/// The app, with a status bar over the top of it.
///
/// [dark] is the theme the app is in, which the status bar's icons follow the
/// way a phone's do over a light or a dark app bar.
class _Phone extends StatelessWidget {
  const _Phone({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) => Stack(
    textDirection: TextDirection.ltr,
    children: <Widget>[
      ProviderScope(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(_shared!)],
        child: const WirdiApp(),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: statusBarHeight,
        child: _StatusBar(dark: dark),
      ),
    ],
  );
}

/// The time, a camera hole and two icons: enough of a status bar to say
/// "phone" without saying anything else.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = dark
        ? WirdiColorSchemes.dark
        : WirdiColorSchemes.light;
    final Color ink = scheme.onSurface;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '5:48',
                  style: TextStyle(
                    fontFamily: WirdiFonts.latin,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: ink,
                  ),
                ),
                const Spacer(),
                Icon(Icons.signal_cellular_alt, size: 15, color: ink),
                const SizedBox(width: 4),
                Icon(Icons.battery_full, size: 15, color: ink),
              ],
            ),
            Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                color: Color(0xFF0E0B09),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One post: what it says, and the screen it says it about.
class _Post extends StatelessWidget {
  const _Post({
    required this.screen,
    required this.headline,
    required this.line,
    this.dark = false,
  });

  final ui.Image screen;
  final String headline;
  final String line;
  final bool dark;

  static const double margin = 88;
  static const double stripeHeight = 14;
  static const double stripeSegment = 36;
  static const double bezel = 14;
  static const double outerRadius = 64;
  static const double bottomMargin = 56;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = dark
        ? WirdiColorSchemes.dark
        : WirdiColorSchemes.light;
    final double screenWidth = screenSize.width * screenScale;
    final double screenHeight = screenSize.height * screenScale;
    final double phoneWidth = screenWidth + 2 * bezel;
    final double phoneHeight = screenHeight + 2 * bezel;

    return SizedBox.fromSize(
      size: postSize,
      child: ColoredBox(
        color: scheme.surface,
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: stripeHeight,
              child: CustomPaint(
                painter: _Voussoirs(
                  brick: scheme.primary,
                  stone: scheme.surfaceContainerHigh,
                  segment: stripeSegment,
                ),
              ),
            ),
            Positioned(
              top: 96,
              left: margin,
              right: margin,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    headline,
                    style: TextStyle(
                      fontFamily: WirdiFonts.latin,
                      fontWeight: FontWeight.w500,
                      fontSize: 72,
                      height: 1.1,
                      letterSpacing: -1.5,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    line,
                    style: TextStyle(
                      fontFamily: WirdiFonts.latin,
                      fontWeight: FontWeight.w400,
                      fontSize: 34,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: (postSize.width - phoneWidth) / 2,
              top: postSize.height - bottomMargin - phoneHeight,
              width: phoneWidth,
              height: phoneHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF0B0907) : scheme.onSurface,
                  borderRadius: BorderRadius.circular(outerRadius),
                  border: dark
                      ? Border.all(color: scheme.surfaceBright, width: 2)
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(bezel),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(outerRadius - bezel),
                    child: RawImage(
                      image: screen,
                      width: screenWidth,
                      height: screenHeight,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app's rule: brick and stone wedges, butted, the way the arches of the
/// Mezquita alternate them — `VoussoirStripe`, at the post's scale.
class _Voussoirs extends CustomPainter {
  const _Voussoirs({
    required this.brick,
    required this.stone,
    required this.segment,
  });

  final Color brick;
  final Color stone;
  final double segment;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    int i = 0;
    for (double x = 0; x < size.width; x += segment, i++) {
      paint.color = i.isEven ? brick : stone;
      canvas.drawRect(Rect.fromLTWH(x, 0, segment, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_Voussoirs old) =>
      old.brick != brick || old.stone != stone || old.segment != segment;
}

/// What a post says about a screen.
final class _Caption {
  const _Caption(this.name, this.headline, this.line, {this.dark = false});

  final String name;
  final String headline;
  final String line;
  final bool dark;
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

  testWidgets('renders the store screenshots', (WidgetTester tester) async {
    // ---- Somebody's practice, a few weeks in. ----------------------------

    const CollectionId nawawi = BuiltinCollectionId(2);
    const CollectionId morning = BuiltinCollectionId(3);
    const CollectionId evening = BuiltinCollectionId(4);
    const CollectionId latif = BuiltinCollectionId(5);
    const CollectionId ratib = BuiltinCollectionId(21);

    final UserCollectionId mulk = await data.collectionRepository.create(
      'Surah al-Mulk',
    );
    await data.collectionRepository.addItem(mulk, const ContentRef.surah(67));
    final UserCollectionId kahf = await data.collectionRepository.create(
      'Surah al-Kahf',
      description: 'Read on Fridays.',
    );
    await data.collectionRepository.addItem(kahf, const ContentRef.surah(18));

    await data.userRepository.commit(nawawi, DailySection.today);
    await data.userRepository.commit(mulk, DailySection.today);
    await data.userRepository.commit(
      morning,
      DailySection.morning,
      reminder: const ReminderTime(5, 30),
    );
    await data.userRepository.commit(latif, DailySection.morning);
    await data.userRepository.commit(
      evening,
      DailySection.evening,
      reminder: const ReminderTime(17, 15),
    );
    await data.userRepository.commit(ratib, DailySection.evening);
    // On the screen one day in seven, which is the commit sheet's shot.
    await data.userRepository.commit(
      kahf,
      DailySection.today,
      days: Weekdays.of(<int>[DateTime.friday]),
      reminder: const ReminderTime(13, 0),
    );

    // Fourteen weeks of most days, so the tracker's twelve have a shape and
    // the tiles have runs to speak of: the morning adhkar nearly every day,
    // the evening a little less, the longer wirds less again, and one week
    // mostly missed two months back. The run of days the greeting counts
    // ends three weeks ago, on a day nothing was kept.
    final DateTime today = DateTime.now();
    for (int back = 1; back < 100; back++) {
      final DateTime day = today.subtract(Duration(days: back));
      final bool lapsed = back >= 52 && back < 58;
      final bool broken = back == 23;
      if (broken) continue;
      if (!lapsed || back == 54) {
        if (!const <int>{19, 37, 66, 80}.contains(back)) {
          await data.userRepository.logCompletion(morning, day);
        }
      }
      if (lapsed) continue;
      if (back % 5 != 2) await data.userRepository.logCompletion(evening, day);
      if (back % 7 != 5 && back < 60) {
        await data.userRepository.logCompletion(nawawi, day);
      }
      if (back % 3 != 0) await data.userRepository.logCompletion(latif, day);
      if (back % 6 == 0) await data.userRepository.logCompletion(ratib, day);
      if (back % 5 != 0 && back < 30) {
        await data.userRepository.logCompletion(mulk, day);
      }
      if (day.weekday == DateTime.friday) {
        await data.userRepository.logCompletion(kahf, day);
      }
    }

    // Today: the morning kept, the day's wird done, the evening under way.
    await data.userRepository.logCompletion(morning, today);
    await data.userRepository.logCompletion(latif, today);
    await data.userRepository.logCompletion(nawawi, today);
    final ResolvedCollection resolvedEvening = await data.collectionRepository
        .resolve(evening);
    await data.userRepository.saveProgress(
      WirdProgress.atStep(
        collectionId: evening,
        step: resolvedEvening.steps[2],
        currentCount: 64,
      ),
    );

    // ---- The screens. -----------------------------------------------------

    tester.view.physicalSize = screenSize * screenScale;
    tester.view.devicePixelRatio = screenScale;
    tester.view.padding = const FakeViewPadding(
      top: statusBarHeight * screenScale,
    );
    tester.view.viewPadding = const FakeViewPadding(
      top: statusBarHeight * screenScale,
    );
    addTearDown(tester.view.reset);

    final Map<String, ui.Image> screens = <String, ui.Image>{};
    Future<void> keep(String name) async {
      screens[name] = await capture(tester, screenScale);
    }

    Future<void> pumpPhone({required bool dark}) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: shotKey,
          child: _Phone(dark: dark),
        ),
      );
      await settle(tester);
    }

    await pumpPhone(dark: false);
    await keep('home');

    NavigatorState navigator() =>
        tester.state<NavigatorState>(find.byType(Navigator));

    Future<void> openPlayer(
      CollectionId id, {
      required int stepIndex,
      required int taps,
    }) async {
      final ResolvedCollection resolved = await data.collectionRepository
          .resolve(id);
      await data.userRepository.saveProgress(
        WirdProgress.atStep(
          collectionId: id,
          step: resolved.steps[stepIndex],
          currentCount: 0,
        ),
      );
      unawaited(
        navigator().pushNamed<void>(
          Routes.player,
          arguments: PlayerArguments(collectionId: id),
        ),
      );
      await settle(tester);
      for (int tap = 0; tap < taps; tap++) {
        await tester.tap(find.byType(SingleChildScrollView));
        await tester.pump(const Duration(milliseconds: 80));
      }
      await settle(tester);
    }

    Future<void> leavePlayer(CollectionId id, WirdProgress? restore) async {
      navigator().pop();
      await settle(tester);
      await data.userRepository.clearProgress(id);
      if (restore != null) await data.userRepository.saveProgress(restore);
    }

    // The morning adhkar's second dhikr, said ten times, six of them counted.
    await openPlayer(morning, stepIndex: 1, taps: 6);
    await keep('player');
    await leavePlayer(morning, null);

    await tester.tap(find.text(WirdiTab.collections.label));
    await settle(tester);
    await tester.tap(find.text('Library'));
    await settle(tester);
    await keep('library');

    // Al-Kahf's commitment, which is a single day and carries a reminder.
    await tester.tap(find.text('Yours'));
    await settle(tester);
    await tester.tap(find.text('Surah al-Kahf'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Change'));
    await settle(tester);
    await keep('commit');
    Navigator.of(tester.element(find.byType(SegmentedButton<int>))).pop();
    await settle(tester);
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    // The tasbih, two-thirds of the way round a goal of thirty-three: the
    // app's own icon.
    await tester.tap(find.text(WirdiTab.tasbih.label));
    await settle(tester);
    await tester.tap(find.widgetWithIcon(OutlinedButton, Icons.flag_outlined));
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, '33'));
    await settle(tester);
    for (int tap = 0; tap < 22; tap++) {
      await tester.tap(find.text('Tap anywhere to count'));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await settle(tester);
    await keep('tasbih');

    await tester.tap(find.text(WirdiTab.tracker.label));
    await settle(tester);
    await keep('tracker');

    await tester.tap(find.text(WirdiTab.home.label));
    await settle(tester);

    unawaited(
      navigator().pushNamed<void>(
        Routes.reading,
        arguments: const ReadingArguments(surahNumber: 1),
      ),
    );
    await settle(tester);
    await keep('quran');
    navigator().pop();
    await settle(tester);

    // Dark: the evening adhkar's "Allah is sufficient for me", seven times,
    // four counted.
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(WirdiApp)),
    );
    await container
        .read(settingsProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    await pumpPhone(dark: true);
    final WirdProgress? eveningProgress = await data.userRepository.progress(
      evening,
    );
    await openPlayer(evening, stepIndex: 13, taps: 4);
    await keep('dark');
    await leavePlayer(evening, eveningProgress);

    // ---- The posts. -------------------------------------------------------

    // Line breaks are placed by hand: the posts are a fixed size, so where a
    // line falls is known, and a break chosen is better than one that splits
    // "al-Khayrat" at its hyphen or starts a line on a dash.
    const List<_Caption> captions = <_Caption>[
      _Caption(
        'home',
        'Your daily wird,\nwaiting for you',
        'Commit to a collection, and it is on your\n'
            'home screen on the days it is due.',
      ),
      _Caption(
        'player',
        'Tap anywhere to count',
        'One dhikr at a time, in Arabic with\n'
            'transliteration and translation.',
      ),
      _Caption(
        'library',
        'The great litanies, built in',
        'al-Nawawi, al-Wird al-Latif, Hizb al-Bahr,\n'
            "Dala'il al-Khayrat and more — or make your own.",
      ),
      _Caption(
        'commit',
        'On the days you choose',
        'Every day, or al-Kahf on Fridays — with\n'
            'a reminder at the time you pick.',
      ),
      _Caption(
        'quran',
        'The Quran,\nverse by verse',
        'All 114 surahs in Uthmani script, with\n'
            'the Saheeh International translation.',
      ),
      _Caption(
        'tasbih',
        'A tasbih for\neverything else',
        'Set a goal, count the rounds, and come\n'
            'back to the count you left.',
      ),
      _Caption(
        'tracker',
        'See the days you kept',
        'Days in a row, a calendar and the weeks\n'
            'behind you — or turn it off.',
      ),
      _Caption(
        'dark',
        'Private by design',
        'No account, no ads, no internet.\n'
            'Nothing you do leaves your phone.',
        dark: true,
      ),
    ];

    tester.view.physicalSize = postSize;
    tester.view.devicePixelRatio = 1;
    tester.view.resetPadding();
    tester.view.resetViewPadding();

    for (int i = 0; i < captions.length; i++) {
      final _Caption caption = captions[i];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: shotKey,
            child: _Post(
              screen: screens[caption.name]!,
              headline: caption.headline,
              line: caption.line,
              dark: caption.dark,
            ),
          ),
        ),
      );
      await tester.pump();
      final ui.Image post = await capture(tester, 1);
      final String number = '${i + 1}'.padLeft(2, '0');
      await tester.binding.runAsync<void>(() async {
        final ByteData rgba = (await post.toByteData())!;
        final File out = File('$outputDirectory/$number-${caption.name}.png');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(
          encodeOpaquePng(rgba.buffer.asUint8List(), post.width, post.height),
          flush: true,
        );
      });
      post.dispose();
    }
    for (final ui.Image screen in screens.values) {
      screen.dispose();
    }
  });
}

/// A 24-bit PNG of [rgba], with the alpha channel dropped.
///
/// Play takes screenshots as JPEG or as PNG without alpha, and Flutter's own
/// encoder always writes the alpha channel. Every pixel here is opaque, so
/// dropping it loses nothing.
Uint8List encodeOpaquePng(Uint8List rgba, int width, int height) {
  final Uint8List raw = Uint8List(height * (1 + width * 3));
  int o = 0;
  for (int y = 0; y < height; y++) {
    raw[o++] = 0; // filter: none
    int i = y * width * 4;
    for (int x = 0; x < width; x++, i += 4) {
      raw[o++] = rgba[i];
      raw[o++] = rgba[i + 1];
      raw[o++] = rgba[i + 2];
    }
  }

  final BytesBuilder png = BytesBuilder(copy: false)
    ..add(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> body) {
    final Uint8List typed = Uint8List.fromList(<int>[
      ...type.codeUnits,
      ...body,
    ]);
    png
      ..add(_uint32(body.length))
      ..add(typed)
      ..add(_uint32(_crc32(typed)));
  }

  chunk('IHDR', <int>[
    ..._uint32(width),
    ..._uint32(height),
    8, // bit depth
    2, // colour type: truecolour, no alpha
    0, // compression
    0, // filter
    0, // interlace
  ]);
  chunk('IDAT', ZLibCodec(level: 9).encode(raw));
  chunk('IEND', const <int>[]);
  return png.takeBytes();
}

Uint8List _uint32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v);

final Uint32List _crcTable = Uint32List.fromList(<int>[
  for (int n = 0; n < 256; n++)
    () {
      int c = n;
      for (int k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
      }
      return c;
    }(),
]);

int _crc32(List<int> bytes) {
  int c = 0xFFFFFFFF;
  for (final int b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >>> 8);
  }
  return c ^ 0xFFFFFFFF;
}
