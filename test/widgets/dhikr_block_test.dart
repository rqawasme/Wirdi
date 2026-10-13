import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/dhikr_block.dart';

/// The lines under a dhikr, and the two switches that take them away.
///
/// Built from a [Dhikr] in place rather than from the fixture database, whose
/// adhkar carry no transliteration — and, like the fixtures, the strings here
/// are labels saying which line they are, not dhikr text.
void main() {
  const Dhikr dhikr = Dhikr(
    ref: ContentRef.dhikr(1),
    textArabic: 'PLACEHOLDER arabic',
    transliteration: 'PLACEHOLDER transliteration',
    translation: 'PLACEHOLDER translation',
    defaultCount: 1,
  );

  Future<void> pumpBlock(
    WidgetTester tester, {
    Dhikr dhikr = dhikr,
    bool showTranslation = true,
    bool showTransliteration = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        // The real theme: the block reads the typography extension and asserts
        // it is there.
        theme: WirdiTheme.light(),
        home: Scaffold(
          body: DhikrBlock(
            dhikr: dhikr,
            showTranslation: showTranslation,
            showTransliteration: showTransliteration,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the Arabic, the transliteration and the translation', (
    WidgetTester tester,
  ) async {
    await pumpBlock(tester);

    expect(find.text('PLACEHOLDER arabic'), findsOneWidget);
    expect(find.text('PLACEHOLDER transliteration'), findsOneWidget);
    expect(find.textContaining('PLACEHOLDER translation'), findsOneWidget);
  });

  testWidgets('leaves the transliteration out when it is turned off', (
    WidgetTester tester,
  ) async {
    await pumpBlock(tester, showTransliteration: false);

    expect(find.text('PLACEHOLDER transliteration'), findsNothing);
    // The other switch, untouched: only what was asked for goes.
    expect(find.text('PLACEHOLDER arabic'), findsOneWidget);
    expect(find.textContaining('PLACEHOLDER translation'), findsOneWidget);
  });

  testWidgets('the two switches are independent of each other', (
    WidgetTester tester,
  ) async {
    await pumpBlock(tester, showTranslation: false);

    expect(find.text('PLACEHOLDER transliteration'), findsOneWidget);
    expect(find.textContaining('PLACEHOLDER translation'), findsNothing);
  });

  testWidgets('with both off, the Arabic is all there is', (
    WidgetTester tester,
  ) async {
    await pumpBlock(tester, showTranslation: false, showTransliteration: false);

    expect(find.byType(Text), findsOneWidget);
    expect(find.text('PLACEHOLDER arabic'), findsOneWidget);
  });
}
