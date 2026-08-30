import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/collection_id.dart';

void main() {
  group('CollectionId round-trips through its canonical form', () {
    test('built-in', () {
      const BuiltinCollectionId id = BuiltinCollectionId(12);
      expect(id.canonical, 'b:12');

      final CollectionId parsed = CollectionId.parse(id.canonical);
      expect(parsed, isA<BuiltinCollectionId>());
      expect((parsed as BuiltinCollectionId).value, 12);
      expect(parsed, id);
      expect(parsed.canonical, id.canonical);
    });

    test('user', () {
      final UserCollectionId id = UserCollectionId(
        '550e8400-e29b-41d4-a716-446655440000',
      );
      expect(id.canonical, 'u:550e8400-e29b-41d4-a716-446655440000');

      final CollectionId parsed = CollectionId.parse(id.canonical);
      expect(parsed, isA<UserCollectionId>());
      expect(
        (parsed as UserCollectionId).uuid,
        '550e8400-e29b-41d4-a716-446655440000',
      );
      expect(parsed, id);
      expect(parsed.canonical, id.canonical);
    });

    test('the two kinds never compare equal', () {
      expect(
        const BuiltinCollectionId(1) ==
            UserCollectionId('550e8400-e29b-41d4-a716-446655440000'),
        isFalse,
      );
    });

    test('an upper-case uuid canonicalises to lower case', () {
      final CollectionId parsed = CollectionId.parse(
        'u:550E8400-E29B-41D4-A716-446655440000',
      );
      expect(parsed.canonical, 'u:550e8400-e29b-41d4-a716-446655440000');
      expect(parsed, UserCollectionId('550e8400-e29b-41d4-a716-446655440000'));
    });
  });

  group('CollectionId.parse rejects', () {
    for (final String bad in <String>[
      '',
      '12',
      'b:',
      'b:x',
      'b:+12',
      'b: 12',
      'x:12',
      'u:',
      'u:not-a-uuid',
      // A uuid missing a block.
      'u:550e8400-e29b-41d4-446655440000',
    ]) {
      test('"$bad"', () {
        expect(CollectionId.tryParse(bad), isNull);
        expect(() => CollectionId.parse(bad), throwsFormatException);
      });
    }
  });

  test('canonical form is what toString gives, for logs and refs', () {
    expect(const BuiltinCollectionId(7).toString(), 'b:7');
  });
}
