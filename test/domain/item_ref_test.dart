import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/item_ref.dart';

/// What a collection item points at, and the string form that is persisted.
///
/// `progress.step_ref` stores [ItemRef.canonical], so these are not only about
/// a Dart type: the forms below are already written into databases on people's
/// phones, and one that stops parsing is somebody losing their place in a wird
/// half way through.
void main() {
  const String uuid = '2f1c8a90-3b4d-4e5f-8a91-0c2d3e4f5a6b';

  group('the content forms are unchanged', () {
    test('round-trip through canonical and back', () {
      const List<ContentRef> refs = <ContentRef>[
        ContentRef.dhikr(1001),
        ContentRef.ayah(2255),
        ContentRef.surah(112),
      ];
      for (final ContentRef ref in refs) {
        expect(ItemRef.parse(ref.canonical), ref);
        expect(ContentRef.parse(ref.canonical), ref);
      }
    });

    test('the strings are the ones already stored', () {
      // Written out rather than derived: a test that builds the expectation
      // the same way the code does would pass through a rename of the format.
      expect(const ContentRef.dhikr(1001).canonical, 'dhikr:1001');
      expect(const ContentRef.ayah(2255).canonical, 'ayah:2255');
      expect(const ContentRef.surah(112).canonical, 'surah:112');
      expect(ItemRef.parse('dhikr:1001'), const ContentRef.dhikr(1001));
    });

    test('a content ref is an item ref', () {
      // Which is the whole reason every picker that builds one is untouched.
      const ItemRef ref = ContentRef.dhikr(1001);
      expect(ref, isA<ContentRef>());
    });
  });

  group('a dhikr the user wrote', () {
    test('round-trips through its canonical form', () {
      final UserDhikrRef ref = UserDhikrRef(uuid);
      expect(ref.canonical, 'user_dhikr:$uuid');
      expect(ItemRef.parse(ref.canonical), ref);
    });

    test('compares equal whatever case it was written in', () {
      expect(UserDhikrRef(uuid.toUpperCase()), UserDhikrRef(uuid));
      expect(
        UserDhikrRef(uuid.toUpperCase()).hashCode,
        UserDhikrRef(uuid).hashCode,
      );
      expect(UserDhikrRef(uuid.toUpperCase()).canonical, 'user_dhikr:$uuid');
    });

    test('is not equal to a content ref, or to another uuid', () {
      expect(UserDhikrRef(uuid), isNot(const ContentRef.dhikr(1001)));
      expect(
        UserDhikrRef(uuid),
        isNot(UserDhikrRef('2f1c8a90-3b4d-4e5f-8a91-0c2d3e4f5a6c')),
      );
    });

    test('a content ref parser does not accept one', () {
      // The two forms cannot be confused for each other in either direction: a
      // UUID never parses as an integer id.
      expect(ContentRef.tryParse('user_dhikr:$uuid'), isNull);
    });
  });

  group('what does not parse', () {
    test('a body that is not a uuid', () {
      for (final String body in <String>[
        '',
        'nope',
        '1001',
        uuid.substring(1),
      ]) {
        expect(
          ItemRef.tryParse('user_dhikr:$body'),
          isNull,
          reason: 'user_dhikr:$body should not parse',
        );
      }
    });

    test('an unknown kind, and a string with no colon at all', () {
      expect(ItemRef.tryParse('hadith:12'), isNull);
      expect(ItemRef.tryParse('dhikr'), isNull);
      expect(ItemRef.tryParse('1001'), isNull);
      expect(ItemRef.tryParse(''), isNull);
    });

    test('parse throws where tryParse returns null', () {
      expect(() => ItemRef.parse('hadith:12'), throwsFormatException);
      expect(() => ItemRef.parse('user_dhikr:nope'), throwsFormatException);
    });
  });
}
