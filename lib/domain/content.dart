/// Where a surah was revealed. Stored in `content.db` as the strings
/// `'makkah'` and `'madinah'`.
enum RevelationPlace { makkah, madinah }

/// One of the 114 surahs.
final class Surah {
  const Surah({
    required this.number,
    required this.nameArabic,
    required this.nameTransliterated,
    required this.nameEnglish,
    required this.revelationPlace,
    required this.ayahCount,
    required this.hasBismillah,
    this.orderRevealed,
  });

  final int number;
  final String nameArabic;
  final String nameTransliterated;
  final String nameEnglish;
  final RevelationPlace revelationPlace;

  /// How many ayahs this surah has. Al-Baqarah is 286.
  final int ayahCount;

  /// False only for At-Tawbah.
  final bool hasBismillah;

  final int? orderRevealed;

  @override
  String toString() => 'Surah($number $nameTransliterated)';
}

/// One ayah, with its text, translation and division metadata.
final class Ayah {
  const Ayah({
    required this.id,
    required this.surahNumber,
    required this.ayahNumber,
    required this.textUthmani,
    required this.textSimple,
    required this.translation,
    required this.juz,
    required this.hizb,
    required this.sajdah,
    this.transliteration,
    this.page,
  });

  /// `surahNumber * 1000 + ayahNumber`, always.
  final int id;

  final int surahNumber;
  final int ayahNumber;
  final String textUthmani;

  /// [textUthmani] with diacritics stripped and alef variants normalised.
  /// Built for search matching, which is not a v1 feature.
  final String textSimple;

  final String translation;
  final String? transliteration;
  final int juz;
  final int hizb;

  /// Mushaf page. Null throughout the current content build.
  final int? page;

  final bool sajdah;

  @override
  String toString() => 'Ayah($surahNumber:$ayahNumber)';
}

/// One dhikr.
final class Dhikr {
  const Dhikr({
    required this.id,
    required this.textArabic,
    required this.translation,
    required this.defaultCount,
    this.transliteration,
    this.sourceId,
    this.benefits,
    this.notes,
  });

  final int id;
  final String textArabic;
  final String translation;
  final String? transliteration;

  /// How many times this dhikr is said unless a collection item overrides it.
  final int defaultCount;

  /// References `sources.id` in `content.db`.
  final int? sourceId;

  final String? benefits;
  final String? notes;

  @override
  String toString() => 'Dhikr($id)';
}
