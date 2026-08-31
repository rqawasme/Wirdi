import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/content_database.dart';
// `reading_position` makes drift generate a table class called
// ReadingPosition, which collides with the domain model of that name.
import 'package:wirdi/data/user_database.dart' hide ReadingPosition;
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/progress.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/providers/reading.dart';
import 'package:wirdi/screens/reading_screen.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/ayah_block.dart';

/// The reading view, against the real Quran.
///
/// Fixtures would not do here: the three bismillah cases are a property of the
/// actual database — 113 surahs carry one, At-Tawbah does not, and Al-Fatiha
/// carries it as a numbered verse — and a fixture asserting that would only be
/// asserting what the fixture was written to say.
void main() {
  final File contentFile = File('content/build/content.db');

  group(
    'reading view',
    () => _tests(contentFile),
    skip: contentFile.existsSync()
        ? false
        : 'no ${contentFile.path} — run content/scripts/build_content.py',
  );
}

void _tests(File contentFile) {
  late WirdiData data;

  setUp(() {
    data = WirdiData(
      content: ContentDatabase.openReadOnly(contentFile),
      user: UserDatabase.memory(),
    );
  });

  tearDown(() => data.close());

  Future<void> pumpSurah(
    WidgetTester tester,
    int surahNumber, {
    int? initialAyahNumber,
  }) async {
    // Tall, so that a short surah is entirely on screen and counting the blocks
    // means something. ListView.builder only builds what it needs to.
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
        child: MaterialApp(
          // The real theme: AyahBlock reads the typography extension and
          // asserts it is there, because a reading view without a type scale is
          // a bug rather than something to degrade gracefully around.
          theme: WirdiTheme.light(),
          home: ReadingScreen(
            surahNumber: surahNumber,
            initialAyahNumber: initialAyahNumber,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ayah count', () {
    testWidgets('Al-Ikhlas renders its four verses', (
      WidgetTester tester,
    ) async {
      await pumpSurah(tester, 112);
      expect(find.byType(AyahBlock), findsNWidgets(4));
    });

    testWidgets('An-Nas renders its six verses', (WidgetTester tester) async {
      await pumpSurah(tester, 114);
      expect(find.byType(AyahBlock), findsNWidgets(6));
    });

    testWidgets('Al-Baqarah offers all 286 without building them', (
      WidgetTester tester,
    ) async {
      await pumpSurah(tester, 2);

      final ListView list = tester.widget<ListView>(find.byType(ListView));
      // 286 verses and no bismillah heading item, because Al-Baqarah's basmala
      // is a heading and is counted separately below.
      expect(
        list.semanticChildCount,
        287,
        reason: '286 verses plus the bismillah heading',
      );
      // Virtualised: the whole surah is in memory, the widgets are not.
      expect(tester.widgetList(find.byType(AyahBlock)).length, lessThan(286));
    });
  });

  group('bismillah', () {
    testWidgets('Al-Fatiha has no heading — its basmala is verse 1', (
      WidgetTester tester,
    ) async {
      await pumpSurah(tester, 1);

      expect(find.byType(BismillahHeading), findsNothing);
      expect(
        find.byType(AyahBlock),
        findsNWidgets(7),
        reason: 'all seven verses, the basmala among them',
      );
    });

    testWidgets('At-Tawbah has no heading — it has no basmala at all', (
      WidgetTester tester,
    ) async {
      await pumpSurah(tester, 9);
      expect(find.byType(BismillahHeading), findsNothing);
    });

    testWidgets('a normal surah has one heading above its first verse', (
      WidgetTester tester,
    ) async {
      await pumpSurah(tester, 112);
      expect(find.byType(BismillahHeading), findsOneWidget);
    });

    testWidgets('the heading carries no verse number', (
      WidgetTester tester,
    ) async {
      await pumpSurah(tester, 112);

      final BismillahHeading heading = tester.widget<BismillahHeading>(
        find.byType(BismillahHeading),
      );
      // U+06DD and Arabic-Indic digits are both absent: it is a heading, not a
      // numbered verse.
      expect(heading.text, isNot(contains('۝')));
      expect(heading.text, isNot(matches(RegExp('[٠-٩]'))));
    });

    test('the provider decides per surah, from the database', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
      );
      addTearDown(container.dispose);

      Future<SurahReading> read(int surah) =>
          container.read(surahReadingProvider(surah).future);

      expect((await read(1)).bismillah, isNull, reason: 'Al-Fatiha: verse 1');
      expect((await read(9)).bismillah, isNull, reason: 'At-Tawbah: none');
      expect((await read(2)).bismillah, isNotNull);
      expect((await read(114)).bismillah, isNotNull);

      // Every surah but those two gets a heading, and they all get the same one.
      final Set<String?> headings = <String?>{};
      for (int surah = 1; surah <= 114; surah++) {
        headings.add((await read(surah)).bismillah);
      }
      expect(
        headings,
        hasLength(2),
        reason: 'one basmala string, plus null for Al-Fatiha and At-Tawbah',
      );
    });
  });

  group('reading position', () {
    testWidgets('scrolling saves the topmost verse, debounced', (
      WidgetTester tester,
    ) async {
      await pumpSurah(tester, 2);
      expect(await data.userRepository.lastPosition(), isNull);

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();

      // Nothing yet: the write is debounced, and a scroll produces a position
      // on every frame.
      expect(
        await data.userRepository.lastPosition(),
        isNull,
        reason: 'the write should not have happened yet',
      );

      await tester.pump(ReadingPositionRecorder.debounce);
      await tester.pumpAndSettle();

      final ReadingPosition? saved = await data.userRepository.lastPosition();
      expect(saved, isNotNull);
      expect(saved!.surahNumber, 2);
      expect(
        saved.ayahNumber,
        greaterThan(1),
        reason: 'scrolled down, so the top verse is no longer the first',
      );
    });

    testWidgets('opening at a verse scrolls to it', (
      WidgetTester tester,
    ) async {
      await pumpSurah(tester, 2, initialAyahNumber: 100);
      await tester.pumpAndSettle();

      // Verse 100 is built and verse 1 is not, which is what "scrolled to it"
      // means for a virtualised list.
      final Iterable<AyahBlock> blocks = tester.widgetList<AyahBlock>(
        find.byType(AyahBlock),
      );
      final List<int> numbers = blocks
          .map((AyahBlock b) => b.ayah.ayahNumber)
          .toList();

      expect(numbers, contains(100));
      expect(
        numbers,
        isNot(contains(1)),
        reason: 'still at the top, so the jump did not happen',
      );
      expect(
        numbers.first,
        closeTo(100, 3),
        reason: 'verse 100 should be at or near the top of the viewport',
      );
    });

    testWidgets('leaving the surah flushes a pending position', (
      WidgetTester tester,
    ) async {
      await pumpSurah(tester, 2);
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pump();

      // Tear the screen down before the debounce fires.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(
        await data.userRepository.lastPosition(),
        isNotNull,
        reason: 'closing a surah is exactly when the position must be durable',
      );
    });
  });
}
