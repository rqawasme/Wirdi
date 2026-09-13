import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/quran/arabic_text.dart';

/// Folding Arabic for comparison.
///
/// Every input here is assembled from code points rather than typed, and spells
/// nothing. These are letters chosen because they exercise a branch of the
/// fold, and no Quranic or dhikr text appears anywhere in this file.
///
/// The fold is `simplify_arabic` from `content/scripts/import_quran.py`, which
/// builds `ayahs.text_simple`. The two are a matched pair and nothing checks
/// them automatically, so these cases are written against the ranges that file
/// names rather than against whatever the Dart happens to do.
void main() {
  String of(List<int> codePoints) => String.fromCharCodes(codePoints);

  const int alef = 0x0627;
  const int beh = 0x0628;
  const int yeh = 0x064A;

  group('stripping marks', () {
    test('drops the whole U+064B-U+065F run of vowel signs', () {
      for (int mark = 0x064B; mark <= 0x065F; mark++) {
        expect(
          ArabicText.simplify(of(<int>[alef, mark, beh])),
          of(<int>[alef, beh]),
          reason: 'U+${mark.toRadixString(16)} survived the fold',
        );
      }
    });

    test('drops the dagger alef U+0670', () {
      expect(
        ArabicText.simplify(of(<int>[alef, 0x0670, beh])),
        of(<int>[alef, beh]),
      );
    });

    test('drops the whole U+06D6-U+06ED run of annotation signs', () {
      for (int mark = 0x06D6; mark <= 0x06ED; mark++) {
        expect(
          ArabicText.simplify(of(<int>[alef, mark, beh])),
          of(<int>[alef, beh]),
          reason: 'U+${mark.toRadixString(16)} survived the fold',
        );
      }
    });

    test('drops tatweel, which only stretches a joining stroke', () {
      expect(
        ArabicText.simplify(of(<int>[alef, 0x0640, 0x0640, beh])),
        of(<int>[alef, beh]),
      );
    });

    test('drops Arabic-Indic digits, which are ayah numbers', () {
      for (int digit = 0x0660; digit <= 0x0669; digit++) {
        expect(
          ArabicText.simplify(of(<int>[alef, digit, beh])),
          of(<int>[alef, beh]),
        );
      }
    });
  });

  group('folding letters', () {
    test('every alef variant folds to bare alef', () {
      for (final int variant in <int>[0x0622, 0x0623, 0x0625, 0x0671]) {
        expect(
          ArabicText.simplify(of(<int>[variant, beh])),
          of(<int>[alef, beh]),
          reason: 'U+${variant.toRadixString(16)} did not fold to alef',
        );
      }
    });

    test('alef maksura folds to yeh', () {
      expect(ArabicText.simplify(of(<int>[beh, 0x0649])), of(<int>[beh, yeh]));
    });

    test('letters that change which word is written are left alone', () {
      // Hamza on the line, waw and yeh carrying hamza, and teh marbuta.
      for (final int kept in <int>[0x0621, 0x0624, 0x0626, 0x0629]) {
        expect(
          ArabicText.simplify(of(<int>[beh, kept])),
          of(<int>[beh, kept]),
          reason: 'U+${kept.toRadixString(16)} was folded away',
        );
      }
    });
  });

  group('whitespace', () {
    test('runs collapse to one space and the ends are trimmed', () {
      expect(ArabicText.simplify('  one   two \n three  '), 'one two three');
    });

    test('the no-break space folds like any other', () {
      expect(ArabicText.simplify('one two'), 'one two');
    });
  });

  group('what the search leans on', () {
    test('Latin passes through untouched', () {
      // Load-bearing: searchAdhkar folds one query both ways and relies on the
      // Arabic fold never reaching a translation.
      const String latin = 'Praise be to God, the Lord of all worlds.';
      expect(ArabicText.simplify(latin), latin);
    });

    test('case is not folded — that is the other half of the pair', () {
      expect(ArabicText.simplify('Morning'), 'Morning');
    });

    test('folding its own output changes nothing', () {
      final String once = ArabicText.simplify(
        of(<int>[0x0623, 0x064E, beh, 0x0640, 0x0651, 0x0649]),
      );
      expect(ArabicText.simplify(once), once);
    });

    test('a string of nothing but marks folds away entirely', () {
      expect(ArabicText.simplify(of(<int>[0x064E, 0x0651, 0x0670])), '');
    });
  });
}
