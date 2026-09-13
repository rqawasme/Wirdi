import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/collections/item_labels.dart';
import 'package:wirdi/domain/domain.dart';

/// What an item is called, wherever it is being named.
///
/// This function exists because two screens ask the question — the player's
/// step header and the contents screen's item sheet — and an app that answers
/// it two ways is an app where the same ayah is called two things depending on
/// how you reached it. These are the cases both of them get.
void main() {
  String surahName(int number) => 'Al-Baqarah';

  const Surah surah = Surah(
    number: 112,
    nameArabic: 'x',
    nameTransliterated: "Al-'Ikhlas",
    nameEnglish: 'Sincerity',
    revelationPlace: RevelationPlace.makkah,
    ayahCount: 4,
    hasBismillah: true,
  );

  const Ayah ayah = Ayah(
    id: 2255,
    surahNumber: 2,
    ayahNumber: 255,
    textUthmani: 'x',
    textSimple: 'x',
    translation: 'x',
    juz: 3,
    hizb: 5,
    sajdah: false,
  );

  const Dhikr dhikr = Dhikr(
    id: 1001,
    textArabic: 'x',
    translation: 'x',
    defaultCount: 1,
  );

  CollectionItemEntry entry(CollectionItemEntry item) => item;

  test('a surah is named, and counted under its name', () {
    expect(
      itemHeading(
        entry(
          const SurahItem(entryId: 'a', position: 1, count: 1, surah: surah),
        ),
        surahName: surahName,
      ),
      ("Al-'Ikhlas", 'Surah 112 · 4 ayahs'),
    );
  });

  test('an ayah is named by its surah, then numbered', () {
    expect(
      itemHeading(
        entry(const AyahItem(entryId: 'a', position: 1, count: 1, ayah: ayah)),
        surahName: surahName,
      ),
      ('Al-Baqarah 2:255', 'Single ayah'),
    );
  });

  test('a dhikr is named by its kind, and gets no second line', () {
    // `adhkar` has no title column, and the nearest things to one — the
    // transliteration, the translation — are already on the screen underneath.
    // A second line here would be printing the dhikr twice.
    expect(
      itemHeading(
        entry(
          const DhikrItem(entryId: 'a', position: 1, count: 1, dhikr: dhikr),
        ),
        surahName: surahName,
      ),
      ('Dhikr', null),
    );
  });

  test('an item whose content is gone still has something to be called', () {
    // A user collection lands here when a content update drops a dhikr it was
    // using. The player shows this on a step it cannot recite, and the contents
    // screen counts it at the foot of the list.
    expect(itemHeading(null, surahName: surahName), ('Unavailable', null));
  });

  test('the surah name is asked for, not invented', () {
    // The lookup is passed in because the caller already has the surah list
    // loaded. This asserts the seam: whatever the caller answers is what gets
    // used, so the player and the sheet cannot disagree by resolving the name
    // two different ways.
    final List<int> asked = <int>[];
    itemHeading(
      entry(const AyahItem(entryId: 'a', position: 1, count: 1, ayah: ayah)),
      surahName: (int number) {
        asked.add(number);
        return 'Whatever the caller says';
      },
    );
    expect(asked, <int>[2]);
  });
}
