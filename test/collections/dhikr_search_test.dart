import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/collections/dhikr_search.dart';
import 'package:wirdi/domain/content.dart';

/// Matching adhkar by their Arabic or their translation.
///
/// The Arabic here is assembled from code points and spells nothing — these are
/// letters chosen to exercise the fold, not a dhikr. The translations are
/// ordinary English words for the same reason.
void main() {
  String of(List<int> codePoints) => String.fromCharCodes(codePoints);

  const int alef = 0x0627;
  const int beh = 0x0628;
  const int teh = 0x062A;
  const int fatha = 0x064E;
  const int shadda = 0x0651;
  const int alefHamza = 0x0623;

  /// The same letters, once carrying marks and once bare.
  final String vocalised = of(<int>[alefHamza, fatha, beh, shadda, teh]);
  final String bare = of(<int>[alef, beh, teh]);

  Dhikr dhikr(int id, {required String textArabic, required String english}) =>
      Dhikr(
        id: id,
        textArabic: textArabic,
        translation: english,
        defaultCount: 1,
      );

  late List<SearchableDhikr> all;

  setUp(() {
    all = <SearchableDhikr>[
      SearchableDhikr.of(
        dhikr(1, textArabic: vocalised, english: 'Praise in the Morning'),
      ),
      SearchableDhikr.of(
        dhikr(2, textArabic: of(<int>[beh, teh]), english: 'Peace at evening'),
      ),
      SearchableDhikr.of(
        dhikr(3, textArabic: of(<int>[teh, alef]), english: 'Forgiveness'),
      ),
    ];
  });

  List<int> ids(List<Dhikr> matches) => <int>[
    for (final Dhikr d in matches) d.id,
  ];

  group('the query is folded both ways', () {
    test('a bare query finds a row whose text carries the marks', () {
      // The point of the whole exercise: nobody types the harakat, and the
      // text carries all of them.
      expect(ids(searchAdhkar(all, bare)), <int>[1]);
    });

    test('a vocalised query finds the same row', () {
      expect(ids(searchAdhkar(all, vocalised)), <int>[1]);
    });

    test('an English query matches the translation, whatever its case', () {
      expect(ids(searchAdhkar(all, 'morning')), <int>[1]);
      expect(ids(searchAdhkar(all, 'MORNING')), <int>[1]);
    });

    test('a partial word matches', () {
      expect(ids(searchAdhkar(all, 'even')), <int>[2]);
    });
  });

  group('the two scripts do not reach each other', () {
    test('an Arabic query never matches a translation', () {
      // No script detection anywhere in searchAdhkar: it relies on the Arabic
      // fold leaving Latin alone and toLowerCase leaving Arabic alone.
      expect(ids(searchAdhkar(all, bare)), isNot(contains(3)));
    });

    test('an English query never matches the Arabic', () {
      expect(searchAdhkar(all, 'zzz'), isEmpty);
    });
  });

  group('edges', () {
    test('an empty query is every dhikr, in the order given', () {
      expect(ids(searchAdhkar(all, '')), <int>[1, 2, 3]);
    });

    test('a query of only whitespace is an empty query', () {
      expect(ids(searchAdhkar(all, '   ')), <int>[1, 2, 3]);
    });

    test('no match is no rows', () {
      expect(searchAdhkar(all, 'nothing here'), isEmpty);
    });

    test('a query of nothing but marks does not match everything', () {
      // It folds away to the empty string, and `contains('')` is true of every
      // string — so without the guard this would hand back the whole list and
      // look like a search that ignored what was typed.
      expect(searchAdhkar(all, of(<int>[fatha, shadda])), isEmpty);
    });

    test('searching an empty library is empty rather than an error', () {
      expect(searchAdhkar(<SearchableDhikr>[], 'anything'), isEmpty);
    });
  });
}
