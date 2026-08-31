import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/content_database.dart';
import 'package:wirdi/domain/domain.dart';

import '../support/fixtures.dart';

void main() {
  late TestDatabases dbs;
  late ContentRepository content;

  setUp(() async {
    dbs = await TestDatabases.open();
    content = dbs.contentRepository();
  });

  tearDown(() => dbs.close());

  test('surahs come back in mushaf order', () async {
    final List<Surah> all = await content.surahs();
    expect(all.map((Surah s) => s.number).toList(), <int>[1, 2, 112, 113, 114]);
  });

  test('surah metadata maps across', () async {
    final Surah surah = await content.surah(2);
    expect(surah.ayahCount, 286);
    expect(surah.revelationPlace, RevelationPlace.madinah);
    expect(surah.hasBismillah, isTrue);
    expect(surah.orderRevealed, 2);
  });

  test('an unknown surah throws rather than returning null', () async {
    expect(() => content.surah(999), throwsA(isA<ContentNotFoundException>()));
  });

  test('ayah ids follow surah * 1000 + ayah', () async {
    final Ayah ayah = await content.ayah(2, 255);
    expect(ayah.id, 2255);
    expect(ayah.surahNumber, 2);
    expect(ayah.ayahNumber, 255);
    expect(ayah.sajdah, isFalse);
  });

  test('ayahsForSurah is ordered by ayah number', () async {
    final List<Ayah> ayahs = await content.ayahsForSurah(1);
    expect(ayahs.map((Ayah a) => a.ayahNumber).toList(), <int>[
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    ]);
  });

  test('ayahsForJuz spans surahs', () async {
    final List<Ayah> juz30 = await content.ayahsForJuz(30);
    expect(juz30.map((Ayah a) => a.id).toList(), <int>[
      112001,
      112002,
      112003,
      112004,
    ]);
  });

  test('a dhikr carries its default count', () async {
    final Dhikr dhikr = await content.dhikr(1002);
    expect(dhikr.defaultCount, 33);
    expect(dhikr.textArabic, contains('1002'));
  });

  group('ayahRange', () {
    test('returns the inclusive range', () async {
      final List<Ayah> ayahs = await content.ayahRange(1, 2, 4);
      expect(ayahs.map((Ayah a) => a.ayahNumber).toList(), <int>[2, 3, 4]);
    });

    test('an inverted range is a caller bug and throws', () async {
      expect(() => content.ayahRange(1, 5, 2), throwsA(isA<ArgumentError>()));
    });

    test('an upper bound past the end clamps to the surah length', () async {
      final List<Ayah> ayahs = await content.ayahRange(1, 5, 99);
      expect(ayahs.map((Ayah a) => a.ayahNumber).toList(), <int>[5, 6, 7]);
    });

    test('a lower bound below 1 clamps to 1', () async {
      final List<Ayah> ayahs = await content.ayahRange(1, -3, 2);
      expect(ayahs.map((Ayah a) => a.ayahNumber).toList(), <int>[1, 2]);
    });

    test('a range entirely past the end is empty, not an error', () async {
      expect(await content.ayahRange(1, 50, 60), isEmpty);
    });

    test('an unknown surah throws', () async {
      expect(
        () => content.ayahRange(999, 1, 2),
        throwsA(isA<ContentNotFoundException>()),
      );
    });
  });

  group('schema version', () {
    test('a matching meta.schema_version passes', () async {
      await dbs.content.assertSchemaVersion();
    });

    test('a mismatch fails loudly', () async {
      await dbs.content.customStatement(
        "UPDATE meta SET value = '99' WHERE key = 'schema_version'",
      );
      expect(
        () => dbs.content.assertSchemaVersion(),
        throwsA(
          isA<ContentSchemaVersionMismatch>()
              .having(
                (ContentSchemaVersionMismatch e) => e.actual,
                'actual',
                '99',
              )
              .having(
                (ContentSchemaVersionMismatch e) => e.expected,
                'expected',
                expectedContentSchemaVersion,
              ),
        ),
      );
    });

    test('a missing row fails too', () async {
      await dbs.content.customStatement(
        "DELETE FROM meta WHERE key = 'schema_version'",
      );
      expect(
        () => dbs.content.assertSchemaVersion(),
        throwsA(isA<ContentSchemaVersionMismatch>()),
      );
    });
  });
}
