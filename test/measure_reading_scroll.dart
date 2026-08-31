/// Measures what makes the reading view fast or slow.
///
///   flutter test test/measure_reading_scroll.dart
///
/// Not a test, and not run by `flutter test` — that only picks up
/// `*_test.dart`. Timing assertions belong nowhere near CI, and these numbers
/// come from a debug build on a host CPU with the software rasteriser, so they
/// are **not** device numbers. What they are good for is the shape of the
/// problem: which of the two costs dominates, and how that scales with the
/// Arabic size.
///
/// The spec's worry is text layout, not the list. So this measures text layout
/// directly — one verse, at each end of the size slider — and separately counts
/// how many verses a fling has to lay out per frame. Multiply the two and you
/// have the per-frame text cost, which is the number that decides whether it
/// janks.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:wirdi/data/content_database.dart';
import 'package:wirdi/data/user_database.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/providers/settings.dart';
import 'package:wirdi/screens/reading_screen.dart';
import 'package:wirdi/quran/uthmani_text.dart';
import 'package:wirdi/theme/theme.dart';

Future<void> loadFont(String family, String path) async {
  final FontLoader loader = FontLoader(family);
  loader.addFont(
    File(path).readAsBytes().then(
      (List<int> bytes) => ByteData.view(Uint8List.fromList(bytes).buffer),
    ),
  );
  await loader.load();
}

/// Median, which is what to quote when a few samples are the OS scheduling.
double median(List<double> values) {
  values.sort();
  return values[values.length ~/ 2];
}

void main() {
  const double columnWidth = 400 - 2 * WirdiMetrics.readingColumnPadding;
  late List<({int ayah, String text})> baqarah;

  setUpAll(() async {
    await loadFont(
      WirdiFonts.naskh,
      'assets/fonts/NotoNaskhArabic-Regular.ttf',
    );
    await loadFont(WirdiFonts.latin, 'assets/fonts/Inter-Regular.ttf');

    final sqlite3.Database db = sqlite3.sqlite3.open(
      'content/build/content.db',
      mode: sqlite3.OpenMode.readOnly,
    );
    baqarah = db
        .select(
          'SELECT ayah_number, text_uthmani FROM ayahs '
          'WHERE surah_number = 2 ORDER BY ayah_number',
        )
        .map(
          (sqlite3.Row r) => (
            ayah: r['ayah_number'] as int,
            text: r['text_uthmani'] as String,
          ),
        )
        .toList();
    db.close();
  });

  test('Arabic layout cost per verse, across the size slider', () {
    // The longest verse in Al-Baqarah is the worst case for one layout.
    final ({int ayah, String text}) longest = baqarah.reduce(
      (({int ayah, String text}) a, ({int ayah, String text}) b) =>
          a.text.length >= b.text.length ? a : b,
    );
    // ignore: avoid_print
    print(
      'Al-Baqarah: ${baqarah.length} verses, longest is 2:${longest.ayah} '
      'at ${longest.text.length} characters\n',
    );

    for (final double nominal in <double>[24, 32, 40]) {
      final WirdiTypography type = WirdiTypography(
        arabicScale: nominal / WirdiTypography.quranVerseSize,
      );

      double layout(String text, int ayahNumber, TextStyle style) {
        final Stopwatch watch = Stopwatch()..start();
        final TextPainter painter = TextPainter(
          text: TextSpan(
            text: UthmaniText.verseWithMarker(text, ayahNumber),
            style: style,
          ),
          textDirection: TextDirection.rtl,
          locale: const Locale('ar'),
        )..layout(maxWidth: columnWidth);
        final double ms = watch.elapsedMicroseconds / 1000;
        painter.dispose();
        return ms;
      }

      final TextStyle style = type.quranVerse;
      // Warm the shaper's caches; the first layout of a face pays for the face.
      layout(longest.text, longest.ayah, style);

      final List<double> worst = <double>[
        for (int i = 0; i < 20; i++) layout(longest.text, longest.ayah, style),
      ];
      final List<double> typical = <double>[
        for (final ({int ayah, String text}) v in baqarah.take(120))
          layout(v.text, v.ayah, style),
      ];

      // ignore: avoid_print
      print(
        'Arabic $nominal px nominal (${style.fontSize!.toStringAsFixed(1)} px '
        'rendered)\n'
        '    longest verse   ${median(worst).toStringAsFixed(2)} ms\n'
        '    median verse    ${median(typical).toStringAsFixed(2)} ms\n'
        '    total, 120      ${typical.reduce((double a, double b) => a + b).toStringAsFixed(0)} ms',
      );
    }
  });

  testWidgets('flinging the real reading screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final WirdiData data = WirdiData(
      content: ContentDatabase.openReadOnly(File('content/build/content.db')),
      user: UserDatabase.memory(),
    );
    addTearDown(data.close);

    for (final double nominal in <double>[24, 40]) {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
      );
      addTearDown(container.dispose);
      await container
          .read(settingsProvider.notifier)
          .setArabicScale(nominal / WirdiTypography.quranVerseSize);
      final WirdiTypography type = WirdiTypography(
        arabicScale: nominal / WirdiTypography.quranVerseSize,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: WirdiTheme.light(typography: type),
            home: const ReadingScreen(surahNumber: 2),
          ),
        ),
      );
      // Let the surah arrive without settling on the progress indicator.
      for (int frame = 0; frame < 16; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // A hard fling, then the frames it takes to come to rest. This is the
      // shipping widget, so the per-frame cost includes laying out the Arabic,
      // the translation, and the sliver walk that finds the topmost verse for
      // the resume position.
      await tester.fling(find.byType(ListView), const Offset(0, -3000), 4000);
      const int frames = 90;
      final List<double> perFrame = <double>[];
      final Stopwatch watch = Stopwatch();
      for (int frame = 0; frame < frames; frame++) {
        watch
          ..reset()
          ..start();
        await tester.pump(const Duration(milliseconds: 16));
        perFrame.add(watch.elapsedMicroseconds / 1000);
      }

      perFrame.sort();
      // ignore: avoid_print
      print(
        '\nReadingScreen, Al-Baqarah, Arabic $nominal px nominal '
        '(${type.quranVerse.fontSize!.toStringAsFixed(1)} px rendered)\n'
        '    median frame   ${median(List<double>.of(perFrame)).toStringAsFixed(2)} ms\n'
        '    95th frame     ${perFrame[(frames * 0.95).floor()].toStringAsFixed(2)} ms\n'
        '    worst frame    ${perFrame.last.toStringAsFixed(2)} ms\n'
        '    (debug build, host CPU, software rasteriser — not device numbers)',
      );
    }
  });
}
