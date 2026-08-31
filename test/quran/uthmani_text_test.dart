import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:wirdi/quran/uthmani_text.dart';

void main() {
  group('withoutAyahNumber', () {
    test('strips a one-digit number and its space', () {
      expect(UthmaniText.withoutAyahNumber('م ١'), 'م');
    });

    test('strips a three-digit number', () {
      expect(UthmaniText.withoutAyahNumber('م ٢٥٥'), 'م');
    });

    test('strips a no-break space separator too', () {
      expect(UthmaniText.withoutAyahNumber('م ١'), 'م');
    });

    test('leaves text with no trailing number alone', () {
      expect(UthmaniText.withoutAyahNumber('من'), 'من');
    });

    test('does not trim a trailing space when there was no number', () {
      expect(UthmaniText.withoutAyahNumber('م '), 'م ');
    });

    test('handles the empty string', () {
      expect(UthmaniText.withoutAyahNumber(''), '');
    });
  });

  group('arabicIndicDigits', () {
    test('single digits', () {
      expect(UthmaniText.arabicIndicDigits(0), '٠');
      expect(UthmaniText.arabicIndicDigits(7), '٧');
    });

    test('multiple digits, most significant first', () {
      expect(UthmaniText.arabicIndicDigits(255), '٢٥٥');
      expect(UthmaniText.arabicIndicDigits(286), '٢٨٦');
    });
  });

  test('ayahMarker puts the number after the ornament', () {
    expect(UthmaniText.ayahMarker(255), '۝٢٥٥');
  });

  test('verseWithMarker replaces the baked number with a marker', () {
    expect(UthmaniText.verseWithMarker('م ١', 1), 'م\u00A0۝١');
  });

  test('verseWithMarker binds the marker with a no-break space', () {
    // So a full last line cannot leave the marker orphaned on the next one.
    final String verse = UthmaniText.verseWithMarker('م ١', 1);
    expect(verse, contains('\u00A0'));
    expect(verse, isNot(contains(' ۝')));
  });

  // The whole point of withoutAyahNumber being a total function rather than a
  // best effort. If a content rebuild ever changes the shape, this fails.
  group(
    'against the real content',
    () {
      test('every ayah ends with a space and Arabic-Indic digits', () {
        final sqlite3.Database db = sqlite3.sqlite3.open(
          'content/build/content.db',
          mode: sqlite3.OpenMode.readOnly,
        );
        addTearDown(db.close);

        final sqlite3.ResultSet rows = db.select(
          'SELECT surah_number, ayah_number, text_uthmani FROM ayahs',
        );
        expect(rows, hasLength(6236));

        for (final sqlite3.Row row in rows) {
          final int ayahNumber = row['ayah_number'] as int;
          final String text = row['text_uthmani'] as String;
          final String stripped = UthmaniText.withoutAyahNumber(text);
          final String where = '${row['surah_number']}:$ayahNumber';

          expect(
            stripped.length,
            lessThan(text.length),
            reason: '$where: nothing was stripped, so the shape changed',
          );
          expect(
            text.substring(stripped.length).trim(),
            UthmaniText.arabicIndicDigits(ayahNumber),
            reason: '$where: what was stripped was not this ayah\'s number',
          );
        }
      });
    },
    skip: File('content/build/content.db').existsSync()
        ? false
        : 'no content/build/content.db — run content/scripts/build_content.py',
  );
}
