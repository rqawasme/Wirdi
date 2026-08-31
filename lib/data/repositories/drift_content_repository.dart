import '../../domain/content.dart';
import '../../domain/content_ref.dart';
import '../../domain/errors.dart';
import '../../domain/repositories.dart';
import '../content_database.dart';
import '../mappers.dart';

/// [ContentRepository] over the bundled, read-only `content.db`.
class DriftContentRepository implements ContentRepository {
  const DriftContentRepository(this._db);

  final ContentDatabase _db;

  @override
  Future<List<Surah>> surahs() async {
    final List<SurahRow> rows = await _db.allSurahs().get();
    return rows.map(surahFromRow).toList(growable: false);
  }

  @override
  Future<Surah> surah(int number) async {
    final SurahRow? row = await _db
        .surahByNumber(number: number)
        .getSingleOrNull();
    if (row == null) {
      throw ContentNotFoundException(ContentRef.surah(number));
    }
    return surahFromRow(row);
  }

  @override
  Future<List<Ayah>> ayahsForSurah(int surahNumber) async {
    final List<AyahRow> rows = await _db
        .ayahsForSurah(surah: surahNumber)
        .get();
    return rows.map(ayahFromRow).toList(growable: false);
  }

  @override
  Future<Ayah> ayah(int surahNumber, int ayahNumber) async {
    // ayahs.id is surah_number * 1000 + ayah_number, always, so the primary
    // key lookup is enough — no need to go through the composite index.
    final int id = surahNumber * 1000 + ayahNumber;
    final AyahRow? row = await _db.ayahById(id: id).getSingleOrNull();
    if (row == null) {
      throw ContentNotFoundException(ContentRef.ayah(id));
    }
    return ayahFromRow(row);
  }

  @override
  Future<List<Ayah>> ayahRange(int surahNumber, int from, int to) async {
    if (from > to) {
      throw ArgumentError.value(
        from,
        'from',
        'ayah range runs backwards: $from > $to',
      );
    }
    // Clamp rather than fail: a caller asking for 280..300 of a 286-ayah surah
    // wants the 7 that exist, and the surah's length is the authority on how
    // many that is.
    final Surah surahMeta = await surah(surahNumber);
    final int first = from < 1 ? 1 : from;
    final int last = to > surahMeta.ayahCount ? surahMeta.ayahCount : to;
    if (first > last) return const <Ayah>[];

    final List<AyahRow> rows = await _db
        .ayahsInRange(surah: surahNumber, first: first, last: last)
        .get();
    return rows.map(ayahFromRow).toList(growable: false);
  }

  @override
  Future<List<Ayah>> ayahsForJuz(int juz) async {
    final List<AyahRow> rows = await _db.ayahsForJuz(juz: juz).get();
    return rows.map(ayahFromRow).toList(growable: false);
  }

  @override
  Future<ContentMetadata> metadata() async {
    // Six rows; one round trip each would be six statements for a screen shown
    // once, so they are read together and looked up in Dart.
    final List<MetaRow> rows = await _db.allMeta().get();
    final Map<String, String> meta = <String, String>{
      for (final MetaRow row in rows) row.key: row.value,
    };
    return ContentMetadata(
      contentVersion: meta['content_version'] ?? 'unknown',
      // The schema version is asserted at open, so by the time anything reads
      // this it is known good; the fallback is only for a hand-made database.
      schemaVersion: int.tryParse(meta['schema_version'] ?? '') ?? 0,
      quranSource: meta['quran_source'] ?? 'unknown',
      translationEdition: meta['translation_edition'] ?? 'unknown',
      contentChecksum: meta['content_checksum'] ?? '',
      builtAt: DateTime.tryParse(meta['built_at'] ?? '')?.toLocal(),
    );
  }

  @override
  Future<Dhikr> dhikr(int id) async {
    final DhikrRow? row = await _db.dhikrById(id: id).getSingleOrNull();
    if (row == null) {
      throw ContentNotFoundException(ContentRef.dhikr(id));
    }
    return dhikrFromRow(row);
  }
}
