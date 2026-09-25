import 'item_ref.dart';

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

/// One dhikr: authored by the content pipeline, or written by the user.
///
/// One class for both, the way `CollectionSummary` is one class for a built-in
/// collection and a user-made one. What differs between them is which database
/// the row came out of — which is what [ref] says — and which of the fields
/// below are filled: [sourceId] and [benefits] are the content build's, and
/// [reference] is the user's.
///
/// Everything that draws a dhikr draws it through this, so a dhikr somebody
/// wrote is recited, listed and read exactly like one that shipped with the
/// app. That is the point.
final class Dhikr {
  const Dhikr({
    required this.ref,
    required this.textArabic,
    required this.defaultCount,
    this.translation,
    this.transliteration,
    this.sourceId,
    this.reference,
    this.benefits,
    this.notes,
  });

  /// Which row this is, and so which database it lives in: a [ContentRef] for
  /// an authored dhikr, a [UserDhikrRef] for one the user wrote.
  ///
  /// This replaced an `int id`, which could only ever name a row in
  /// `content.db`.
  final ItemRef ref;

  final String textArabic;

  /// Null only for a dhikr the user wrote and left untranslated.
  ///
  /// `adhkar.translation` in `content.db` is NOT NULL, so an authored dhikr
  /// always has one. Somebody writing down the dua they say after Fajr already
  /// knows what it means, and refusing to save it until they have typed a
  /// translation is asking them to do the content build's job — so the column
  /// in `user_adhkar` is nullable, and every widget that draws this line
  /// leaves it out rather than inventing one.
  final String? translation;

  final String? transliteration;

  /// How many times this dhikr is said unless a collection item overrides it.
  final int defaultCount;

  /// References `sources.id` in `content.db`. Authored adhkar only.
  final int? sourceId;

  /// Where the user says they found this one: free text, and theirs.
  ///
  /// Deliberately not a [Source]. A source row carries a grading, which is a
  /// claim the content pipeline stands behind; this is a note somebody made
  /// about their own copy, and the app must not dress the second as the first.
  final String? reference;

  final String? benefits;
  final String? notes;

  @override
  String toString() => 'Dhikr(${ref.canonical})';
}

/// The fields of a dhikr the user is writing, without an id.
///
/// What the form hands to [UserDhikrRepository.create] and to its `update`,
/// and the reason those two take the same argument: the same form asks the same
/// questions whether the dhikr exists yet or not, and an update writes every
/// field at once for the same reason `updateUserCollectionDetails` does — a
/// half-applied answer is worse than a refused one.
///
/// Nullable fields are cleared by a null. Emptying a field is how a field is
/// taken off, and the form hands back null for an empty one.
final class DhikrDraft {
  const DhikrDraft({
    required this.textArabic,
    this.translation,
    this.transliteration,
    this.defaultCount = 1,
    this.reference,
    this.notes,
  });

  /// The one field that is required. A dhikr with no words is not a dhikr; a
  /// dhikr with no translation is one somebody knows the meaning of.
  final String textArabic;

  final String? translation;
  final String? transliteration;

  /// How many times it is said unless an item overrides it. 1 by default:
  /// whatever number somebody had in mind, they are about to type it.
  final int defaultCount;

  final String? reference;
  final String? notes;

  @override
  String toString() => 'DhikrDraft(${textArabic.length} chars x$defaultCount)';
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
