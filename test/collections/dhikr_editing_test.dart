import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/collections/dhikr_editing.dart';
import 'package:wirdi/domain/content.dart';

/// What a dhikr somebody is writing has to be before it is written, and how a
/// deletion asks.
///
/// The Arabic here is a placeholder string and spells nothing: no dhikr text is
/// invented anywhere in these tests.
void main() {
  const String words = 'PLACEHOLDER dhikr arabic';

  group('what is refused', () {
    test('a dhikr with no words at all', () {
      expect(dhikrRefusal(const DhikrDraft(textArabic: '')), isNotNull);
    });

    test('a dhikr of nothing but whitespace', () {
      // The check is made against the cleaned draft, so spaces are not words.
      expect(dhikrRefusal(const DhikrDraft(textArabic: '   \n ')), isNotNull);
    });

    test('a paste that went wrong', () {
      final String tooLong = 'ا' * (maxDhikrTextLength + 1);
      expect(dhikrRefusal(DhikrDraft(textArabic: tooLong)), isNotNull);
      // And the boundary itself is fine: the limit catches an accident, and
      // nobody's dua is allowed to fail by one character.
      expect(
        dhikrRefusal(DhikrDraft(textArabic: 'ا' * maxDhikrTextLength)),
        isNull,
      );
    });

    test('a translation longer than a dhikr can carry', () {
      expect(
        dhikrRefusal(
          DhikrDraft(
            textArabic: words,
            translation: 'x' * (maxDhikrTextLength + 1),
          ),
        ),
        isNotNull,
      );
    });

    test('a count below one', () {
      expect(
        dhikrRefusal(const DhikrDraft(textArabic: words, defaultCount: 0)),
        isNotNull,
      );
    });

    test('a count past what six digits can hold', () {
      expect(
        dhikrRefusal(
          const DhikrDraft(textArabic: words, defaultCount: maxDhikrCount + 1),
        ),
        isNotNull,
      );
      // And the ceiling itself is fine: tens of thousands are a real practice,
      // and the limit sits well above them.
      expect(
        dhikrRefusal(
          const DhikrDraft(textArabic: words, defaultCount: maxDhikrCount),
        ),
        isNull,
      );
    });

    test('the words alone are enough', () {
      // No translation, no transliteration, no reference: somebody writing down
      // the dua they say after Fajr already knows what it means.
      expect(dhikrRefusal(const DhikrDraft(textArabic: words)), isNull);
    });
  });

  group('cleaning', () {
    test('trims the words and nulls every field left empty', () {
      final DhikrDraft clean = cleanDraft(
        const DhikrDraft(
          textArabic: '  $words  ',
          translation: '   ',
          transliteration: '',
          reference: ' \n',
          notes: '  ',
        ),
      );

      expect(clean.textArabic, words);
      expect(clean.translation, isNull);
      expect(clean.transliteration, isNull);
      expect(clean.reference, isNull);
      expect(clean.notes, isNull);
    });

    test('keeps what was written, trimmed', () {
      final DhikrDraft clean = cleanDraft(
        const DhikrDraft(
          textArabic: words,
          translation: '  a meaning  ',
          reference: ' Muslim 2137 ',
          defaultCount: 33,
        ),
      );

      expect(clean.translation, 'a meaning');
      expect(clean.reference, 'Muslim 2137');
      expect(clean.defaultCount, 33);
    });

    test('leaves a zero count alone rather than correcting it', () {
      // Refused by [dhikrRefusal] instead: a zero somebody typed means
      // something, and guessing which is worse than asking.
      expect(
        cleanDraft(
          const DhikrDraft(textArabic: words, defaultCount: 0),
        ).defaultCount,
        0,
      );
    });
  });

  group('the sentence a deletion asks with', () {
    test('names one collection', () {
      final String prompt = deleteDhikrPrompt(<String>['Morning']);
      expect(prompt, contains('Morning'));
      expect(prompt, contains('that collection'));
    });

    test('names two, joined by and', () {
      expect(
        deleteDhikrPrompt(<String>['Morning', 'My wird']),
        contains('Morning and My wird'),
      );
    });

    test('names three with a comma and an and', () {
      expect(
        deleteDhikrPrompt(<String>['Morning', 'Evening', 'Friday']),
        contains('Morning, Evening and Friday'),
      );
    });

    test('counts the rest past three, rather than listing nine names', () {
      final String prompt = deleteDhikrPrompt(<String>[
        'Morning',
        'Evening',
        'Friday',
        'Ratib',
        'Wazifa',
      ]);
      expect(prompt, contains('Morning, Evening and Friday and 2 others'));
      expect(prompt, isNot(contains('Ratib')));
      expect(prompt, isNot(contains('Wazifa')));
    });

    test('says so plainly when nothing holds it', () {
      final String prompt = deleteDhikrPrompt(const <String>[]);
      expect(prompt, contains('none of your collections'));
      expect(prompt, contains('cannot be undone'));
    });
  });
}
