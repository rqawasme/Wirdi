import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/ayah_block.dart';

/// The lines under a verse, and the two switches that take them away.
///
/// Built from an [Ayah] in place rather than from the fixture database, whose
/// verses carry no transliteration — and the strings are labels saying which
/// line they are, not Quran text.
void main() {
  const Ayah ayah = Ayah(
    id: 1001,
    surahNumber: 1,
    ayahNumber: 1,
    textUthmani: 'PLACEHOLDER uthmani',
    textSimple: 'PLACEHOLDER simple',
    transliteration: 'PLACEHOLDER transliteration',
    translation: 'PLACEHOLDER translation',
    juz: 1,
    hizb: 1,
    sajdah: false,
  );

  Future<void> pumpBlock(
    WidgetTester tester, {
    Ayah ayah = ayah,
    bool showTranslation = true,
    bool showTransliteration = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        // The real theme: the block reads the typography extension and asserts
        // it is there.
        theme: WirdiTheme.light(),
        home: Scaffold(
          body: AyahBlock(
            ayah: ayah,
            surahName: 'PLACEHOLDER surah',
            showTranslation: showTranslation,
            showTransliteration: showTransliteration,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the transliteration between the Arabic and the meaning', (
    WidgetTester tester,
  ) async {
    await pumpBlock(tester);

    final Finder arabic = find.textContaining('PLACEHOLDER uthmani');
    final Finder transliteration = find.text('PLACEHOLDER transliteration');
    final Finder translation = find.textContaining('PLACEHOLDER translation');
    expect(transliteration, findsOneWidget);

    // The order the dhikr uses, so the two read the same way down the page.
    expect(
      tester.getTopLeft(transliteration).dy,
      greaterThan(tester.getTopLeft(arabic).dy),
    );
    expect(
      tester.getTopLeft(translation).dy,
      greaterThan(tester.getTopLeft(transliteration).dy),
    );
  });

  testWidgets('leaves the transliteration out when it is turned off', (
    WidgetTester tester,
  ) async {
    await pumpBlock(tester, showTransliteration: false);

    expect(find.text('PLACEHOLDER transliteration'), findsNothing);
    expect(find.textContaining('PLACEHOLDER translation'), findsOneWidget);
  });

  testWidgets('the two switches are independent of each other', (
    WidgetTester tester,
  ) async {
    await pumpBlock(tester, showTranslation: false);

    expect(find.text('PLACEHOLDER transliteration'), findsOneWidget);
    expect(find.textContaining('PLACEHOLDER translation'), findsNothing);
  });

  testWidgets('a verse without one has no empty line standing for it', (
    WidgetTester tester,
  ) async {
    const Ayah bare = Ayah(
      id: 1001,
      surahNumber: 1,
      ayahNumber: 1,
      textUthmani: 'PLACEHOLDER uthmani',
      textSimple: 'PLACEHOLDER simple',
      translation: 'PLACEHOLDER translation',
      juz: 1,
      hizb: 1,
      sajdah: false,
    );
    await pumpBlock(tester, ayah: bare, showTranslation: false);

    // The Arabic and nothing else.
    expect(find.byType(Text), findsOneWidget);
  });
}
