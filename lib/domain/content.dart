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

/// A hadith or book reference that a dhikr cites.
///
/// Hydrated onto [DhikrItem] during collection resolution rather than fetched
/// on demand: sourcing is a trust feature, and a reference the UI has to
/// remember to ask for is a reference that sometimes goes missing.
final class Source {
  const Source({
    required this.id,
    required this.collection,
    required this.reference,
    this.grading,
    this.fullText,
  });

  final int id;

  /// The hadith collection or book, e.g. a Sunan or a Musnad.
  final String collection;

  final String reference;
  final String? grading;
  final String? fullText;

  @override
  String toString() => 'Source($id $collection $reference)';
}

/// What the content build is, and where it came from.
///
/// Read out of `content.db`'s `meta` table rather than hard-coded in the app,
/// so an About screen crediting a source cannot drift from the source the
/// database was actually built from.
final class ContentMetadata {
  const ContentMetadata({
    required this.contentVersion,
    required this.schemaVersion,
    required this.quranSource,
    required this.translationEdition,
    required this.contentChecksum,
    this.builtAt,
  });

  /// `content/sources/VERSION`, stamped in at build time.
  final String contentVersion;

  final int schemaVersion;

  /// Where the Quran text and its metadata were imported from.
  final String quranSource;

  final String translationEdition;

  /// SHA-256 over the content rows. Same sources, same checksum.
  final String contentChecksum;

  /// Null if the stamp is missing or unparseable — it is provenance, not
  /// something the app should fail to start over.
  final DateTime? builtAt;

  @override
  String toString() => 'ContentMetadata($contentVersion, $quranSource)';
}
