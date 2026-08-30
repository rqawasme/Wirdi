import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/content.dart';
import '../domain/progress.dart';
import 'content_database.dart';
// `reading_position` makes drift generate a table class called
// `ReadingPosition`, which collides with the domain model of that name.
// The row class is `ReadingPositionRow`; the table class is not needed here.
import 'user_database.dart' hide ReadingPosition;

/// Row-to-domain mapping. Drift's generated row types stop here: nothing
/// beyond this file passes a `*Row` outwards.

/// Timestamps are stored as epoch milliseconds, UTC.
int toEpochMs(DateTime value) => value.toUtc().millisecondsSinceEpoch;

/// Read back in local time, which is what everything above the data layer
/// displays and compares against.
DateTime fromEpochMs(int value) => DateTime.fromMillisecondsSinceEpoch(value);

Surah surahFromRow(SurahRow row) => Surah(
  number: row.number,
  nameArabic: row.nameArabic,
  nameTransliterated: row.nameTransliterated,
  nameEnglish: row.nameEnglish,
  revelationPlace: row.revelationPlace == 'makkah'
      ? RevelationPlace.makkah
      : RevelationPlace.madinah,
  ayahCount: row.ayahCount,
  hasBismillah: row.hasBismillah != 0,
  orderRevealed: row.orderRevealed,
);

Ayah ayahFromRow(AyahRow row) => Ayah(
  id: row.id,
  surahNumber: row.surahNumber,
  ayahNumber: row.ayahNumber,
  textUthmani: row.textUthmani,
  textSimple: row.textSimple,
  translation: row.translation,
  transliteration: row.transliteration,
  juz: row.juz,
  hizb: row.hizb,
  page: row.page,
  sajdah: row.sajdah != 0,
);

Dhikr dhikrFromRow(DhikrRow row) => Dhikr(
  id: row.id,
  textArabic: row.textArabic,
  translation: row.translation,
  transliteration: row.transliteration,
  defaultCount: row.defaultCount,
  sourceId: row.sourceId,
  benefits: row.benefits,
  notes: row.notes,
);

/// `collections.type` holds the authored strings; anything else is treated as
/// unknown rather than crashing a list.
CollectionType? collectionTypeFromSql(String value) => switch (value) {
  'wird' => CollectionType.wird,
  'dhikr_set' => CollectionType.dhikrSet,
  'surah_set' => CollectionType.surahSet,
  _ => null,
};

CollectionSummary builtinSummaryFromRow(CollectionRow row) => CollectionSummary(
  id: BuiltinCollectionId(row.id),
  name: row.nameEnglish,
  nameArabic: row.nameArabic,
  description: row.description,
  author: row.author,
  type: collectionTypeFromSql(row.type),
  sortOrder: row.sortOrder,
);

CollectionSummary userSummaryFromRow(UserCollectionRow row) => CollectionSummary(
  id: UserCollectionId(row.id),
  name: row.name,
  description: row.description,
  sortOrder: row.sortOrder,
);

WirdProgress progressFromRow(ProgressRow row, CollectionId id) => WirdProgress(
  collectionId: id,
  itemIndex: row.itemIndex,
  currentCount: row.currentCount,
  updatedAt: fromEpochMs(row.updatedAt),
);

ReadingPosition readingPositionFromRow(ReadingPositionRow row) =>
    ReadingPosition(
      surahNumber: row.surahNumber,
      ayahNumber: row.ayahNumber,
      updatedAt: fromEpochMs(row.updatedAt),
    );
