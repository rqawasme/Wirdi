import '../domain/collection.dart';
import '../domain/content.dart';
import '../domain/item_ref.dart';

/// What an item is called, and what kind of thing it is under that.
///
/// A dhikr has neither: `adhkar` has no title column, and the nearest things to
/// one — the transliteration, the translation — are already on the screen
/// underneath, where they are being read from. So it is named by its kind and
/// the second line goes, rather than printing the dhikr twice.
///
/// One rule in one place. The player's step header and the contents screen's
/// item sheet both ask this question, and an app that answers it two ways is an
/// app where the same ayah is called two things depending on how you reached it.
///
/// [surahName] resolves a surah number to its transliterated name. It is passed
/// in rather than looked up here because the surah list is a provider and this
/// is not a widget — and because the caller already has it: both callers watch
/// `surahsProvider` for other reasons.
///
/// A null [item] is an entry whose content row was not found, which a user
/// collection can end up holding after a content update removes a dhikr.
(String, String?) itemHeading(
  CollectionItemEntry? item, {
  required String Function(int surahNumber) surahName,
}) => switch (item) {
  SurahItem(:final Surah surah) => (
    surah.nameTransliterated,
    'Surah ${surah.number} · ${surah.ayahCount} ayahs',
  ),
  AyahItem(:final Ayah ayah) => (
    '${surahName(ayah.surahNumber)} ${ayah.surahNumber}:${ayah.ayahNumber}',
    'Single ayah',
  ),
  // "Yours" and not "Custom dhikr": the second names a category the app
  // invented, and the first answers the question somebody looking at two
  // similar adhkar is actually asking.
  DhikrItem(dhikr: Dhikr(ref: UserDhikrRef())) => ('Dhikr', 'Yours'),
  DhikrItem() => ('Dhikr', null),
  null => ('Unavailable', null),
};
