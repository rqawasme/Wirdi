import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/user_database.dart' hide ReadingPosition;
import 'package:wirdi/domain/domain.dart';

import '../support/fixtures.dart';

/// Renders a resolved entry as a short string, so a whole collection can be
/// compared in one expectation and a failure reads as a diff of the recitation
/// order rather than of object identity.
String describe(CollectionEntry entry) => switch (entry) {
  DhikrItem(:final Dhikr dhikr, :final int count) =>
    'dhikr:${dhikr.id} x$count',
  AyahItem(:final Ayah ayah, :final int count) => 'ayah:${ayah.id} x$count',
  SurahItem(:final Surah surah, :final int count) =>
    'surah:${surah.number} x$count',
  RepeatBlock(
    :final int group,
    :final int repeatCount,
    :final List<CollectionItemEntry> entries,
  ) =>
    'repeat($group x$repeatCount)[${entries.map(describe).join(', ')}]',
};

List<String> describeAll(ResolvedCollection resolved) =>
    resolved.entries.map(describe).toList();

/// The fixture's built-in collection, as recitation order.
const List<String> mixedCollectionShape = <String>[
  'dhikr:1001 x1',
  'dhikr:1002 x100',
  'ayah:2255 x1',
  'ayah:2285 x1',
  'repeat(1 x3)[surah:112 x1, surah:113 x1, surah:114 x1]',
  'dhikr:1003 x3',
];

void main() {
  late TestDatabases dbs;
  late CollectionRepository collections;

  setUp(() async {
    dbs = await TestDatabases.open();
    collections = dbs.collectionRepository();
  });

  tearDown(() => dbs.close());

  group('resolving a built-in collection', () {
    test('mixes all three item types, in position order', () async {
      final ResolvedCollection resolved = await collections.resolve(
        const BuiltinCollectionId(mixedCollectionId),
      );

      expect(describeAll(resolved), mixedCollectionShape);
      // The fixture inserts its item rows out of order on purpose: position is
      // authoritative, row order is not.
      expect(
        resolved.entries.map((CollectionEntry e) => e.position).toList(),
        <int>[1, 2, 3, 4, 5, 8],
      );
      expect(
        resolved.entries.map((CollectionEntry e) => e.runtimeType).toList(),
        <Type>[
          DhikrItem,
          DhikrItem,
          AyahItem,
          AyahItem,
          RepeatBlock,
          DhikrItem,
        ],
      );
      expect(resolved.unresolved, isEmpty);
    });

    test('carries the collection summary', () async {
      final ResolvedCollection resolved = await collections.resolve(
        const BuiltinCollectionId(mixedCollectionId),
      );
      expect(resolved.collection.id, const BuiltinCollectionId(1));
      expect(resolved.collection.type, CollectionType.wird);
      expect(resolved.collection.nameArabic, isNotNull);
      expect(resolved.collection.isBuiltin, isTrue);
    });

    test('count_override wins over a dhikr default_count', () async {
      final ResolvedCollection resolved = await collections.resolve(
        const BuiltinCollectionId(mixedCollectionId),
      );
      final List<DhikrItem> adhkar = resolved.entries
          .whereType<DhikrItem>()
          .toList();

      final DhikrItem overridden = adhkar.firstWhere(
        (DhikrItem d) => d.dhikr.id == 1002,
      );
      expect(overridden.dhikr.defaultCount, 33);
      expect(overridden.count, 100);

      // And a dhikr with no override falls back to its own default.
      final DhikrItem defaulted = adhkar.firstWhere(
        (DhikrItem d) => d.dhikr.id == 1003,
      );
      expect(defaulted.count, defaulted.dhikr.defaultCount);
      expect(defaulted.count, 3);
    });

    test('a repeat_group collapses into one RepeatBlock', () async {
      final ResolvedCollection resolved = await collections.resolve(
        const BuiltinCollectionId(mixedCollectionId),
      );
      final List<RepeatBlock> blocks = resolved.entries
          .whereType<RepeatBlock>()
          .toList();

      expect(blocks, hasLength(1));
      final RepeatBlock block = blocks.single;
      expect(block.group, 1);
      expect(block.repeatCount, 3);
      expect(block.entries.map((CollectionItemEntry e) => e.ref), <ContentRef>[
        const ContentRef.surah(112),
        const ContentRef.surah(113),
        const ContentRef.surah(114),
      ]);
      // The block takes the position of its first member.
      expect(block.position, 5);
    });

    test('an authored note rides along with its item', () async {
      final ResolvedCollection resolved = await collections.resolve(
        const BuiltinCollectionId(mixedCollectionId),
      );
      final CollectionItemEntry last =
          resolved.entries.last as CollectionItemEntry;
      expect(last.note, 'PLACEHOLDER item note');
    });

    test('an unknown collection throws', () async {
      expect(
        () => collections.resolve(const BuiltinCollectionId(404)),
        throwsA(isA<CollectionNotFoundException>()),
      );
    });
  });

  group('a surah item', () {
    test('resolves to metadata only, without expanding its ayahs', () async {
      final String id = testUuid(1);
      await insertUserCollection(dbs.user, id: id, name: 'surah only');
      await insertUserItem(
        dbs.user,
        id: testUuid(11),
        collectionId: id,
        position: 1,
        itemType: 'surah',
        itemId: 2,
      );

      final ResolvedCollection resolved = await collections.resolve(
        UserCollectionId(id),
      );

      // Al-Baqarah is 286 ayahs. One entry, not 286.
      expect(resolved.entries, hasLength(1));
      final SurahItem item = resolved.entries.single as SurahItem;
      expect(item.surah.number, 2);
      expect(item.surah.ayahCount, 286);
      expect(item.count, 1);
      expect(item.ref, const ContentRef.surah(2));

      // The caller expands them when it wants them.
      expect(await dbs.contentRepository().ayahsForSurah(2), hasLength(3));
    });
  });

  group('a user collection', () {
    test('resolves identically to a built-in of the same shape', () async {
      final String id = testUuid(2);
      await insertUserCollection(dbs.user, id: id, name: 'mirror');
      // The same item list as the built-in fixture, row for row.
      await insertUserItem(
        dbs.user,
        id: testUuid(21),
        collectionId: id,
        position: 1,
        itemType: 'dhikr',
        itemId: 1001,
      );
      await insertUserItem(
        dbs.user,
        id: testUuid(22),
        collectionId: id,
        position: 2,
        itemType: 'dhikr',
        itemId: 1002,
        countOverride: 100,
      );
      await insertUserItem(
        dbs.user,
        id: testUuid(23),
        collectionId: id,
        position: 3,
        itemType: 'ayah',
        itemId: 2255,
      );
      await insertUserItem(
        dbs.user,
        id: testUuid(24),
        collectionId: id,
        position: 4,
        itemType: 'ayah',
        itemId: 2285,
      );
      await insertUserItem(
        dbs.user,
        id: testUuid(25),
        collectionId: id,
        position: 5,
        itemType: 'surah',
        itemId: 112,
        repeatGroup: 1,
        repeatGroupCount: 3,
      );
      await insertUserItem(
        dbs.user,
        id: testUuid(26),
        collectionId: id,
        position: 6,
        itemType: 'surah',
        itemId: 113,
        repeatGroup: 1,
        repeatGroupCount: 3,
      );
      await insertUserItem(
        dbs.user,
        id: testUuid(27),
        collectionId: id,
        position: 7,
        itemType: 'surah',
        itemId: 114,
        repeatGroup: 1,
        repeatGroupCount: 3,
      );
      await insertUserItem(
        dbs.user,
        id: testUuid(28),
        collectionId: id,
        position: 8,
        itemType: 'dhikr',
        itemId: 1003,
      );

      final ResolvedCollection mine = await collections.resolve(
        UserCollectionId(id),
      );
      final ResolvedCollection builtin = await collections.resolve(
        const BuiltinCollectionId(mixedCollectionId),
      );

      expect(describeAll(mine), mixedCollectionShape);
      expect(describeAll(mine), describeAll(builtin));
    });

    test(
      'drops an item whose content no longer exists, and reports it',
      () async {
        final String id = testUuid(3);
        await insertUserCollection(dbs.user, id: id, name: 'stale');
        await insertUserItem(
          dbs.user,
          id: testUuid(31),
          collectionId: id,
          position: 1,
          itemType: 'dhikr',
          itemId: 1001,
        );
        await insertUserItem(
          dbs.user,
          id: testUuid(32),
          collectionId: id,
          position: 2,
          itemType: 'dhikr',
          itemId: 999999,
        );

        final ResolvedCollection resolved = await collections.resolve(
          UserCollectionId(id),
        );

        expect(describeAll(resolved), <String>['dhikr:1001 x1']);
        expect(resolved.unresolved, <ContentRef>[
          const ContentRef.dhikr(999999),
        ]);
      },
    );
  });

  group('building a user collection through the repository', () {
    test('create, add items and resolve', () async {
      final UserCollectionId id = await collections.create(
        'Mine',
        description: 'a description',
      );

      await collections.addItem(id, const ContentRef.dhikr(1001));
      await collections.addItem(id, const ContentRef.dhikr(1002), count: 5);
      await collections.addItem(id, ContentRef.ayahAt(2, 255));
      await collections.addItem(id, const ContentRef.surah(112));

      final ResolvedCollection resolved = await collections.resolve(id);
      expect(describeAll(resolved), <String>[
        'dhikr:1001 x1',
        // count wins over default_count 33
        'dhikr:1002 x5',
        'ayah:2255 x1',
        'surah:112 x1',
      ]);
      expect(
        resolved.entries.map((CollectionEntry e) => e.position).toList(),
        <int>[1, 2, 3, 4],
      );
      expect(resolved.collection.name, 'Mine');
      expect(resolved.collection.description, 'a description');
      expect(resolved.collection.isBuiltin, isFalse);
    });

    test('rename', () async {
      final UserCollectionId id = await collections.create('Before');
      await collections.rename(id, 'After');
      final ResolvedCollection resolved = await collections.resolve(id);
      expect(resolved.collection.name, 'After');
    });

    test('removeItem drops just that item', () async {
      final UserCollectionId id = await collections.create('Mine');
      await collections.addItem(id, const ContentRef.dhikr(1001));
      await collections.addItem(id, const ContentRef.dhikr(1002));

      final ResolvedCollection before = await collections.resolve(id);
      final String toRemove =
          (before.entries.first as CollectionItemEntry).entryId;
      await collections.removeItem(id, toRemove);

      expect(describeAll(await collections.resolve(id)), <String>[
        'dhikr:1002 x33',
      ]);
    });

    test('reorder re-resolves in the new order', () async {
      final UserCollectionId id = await collections.create('Mine');
      await collections.addItem(id, const ContentRef.dhikr(1001));
      await collections.addItem(id, const ContentRef.dhikr(1002));
      await collections.addItem(id, const ContentRef.surah(113));

      final ResolvedCollection before = await collections.resolve(id);
      expect(describeAll(before), <String>[
        'dhikr:1001 x1',
        'dhikr:1002 x33',
        'surah:113 x1',
      ]);

      final List<String> ids = before.entries
          .cast<CollectionItemEntry>()
          .map((CollectionItemEntry e) => e.entryId)
          .toList();
      await collections.reorder(id, <String>[ids[2], ids[0], ids[1]]);

      final ResolvedCollection after = await collections.resolve(id);
      expect(describeAll(after), <String>[
        'surah:113 x1',
        'dhikr:1001 x1',
        'dhikr:1002 x33',
      ]);
      expect(
        after.entries.map((CollectionEntry e) => e.position).toList(),
        <int>[1, 2, 3],
      );
    });

    test('adding to a deleted collection throws', () async {
      final UserCollectionId id = await collections.create('Mine');
      await collections.delete(id);
      expect(
        () => collections.addItem(id, const ContentRef.dhikr(1001)),
        throwsA(isA<CollectionNotFoundException>()),
      );
    });
  });

  group('all()', () {
    test('merges built-ins and user collections', () async {
      final UserCollectionId mine = await collections.create('Mine');

      final List<CollectionSummary> all = await collections.all();
      expect(
        all.map((CollectionSummary c) => c.id.canonical).toList(),
        <String>['b:1', 'b:2', mine.canonical],
      );
      expect(all.first.name, 'PLACEHOLDER collection 1 english');
      expect(all.last.name, 'Mine');
    });

    test('excludes soft-deleted collections', () async {
      final UserCollectionId kept = await collections.create('Kept');
      final UserCollectionId gone = await collections.create('Gone');

      await collections.delete(gone);

      final List<CollectionSummary> all = await collections.all();
      final List<String> ids = all
          .map((CollectionSummary c) => c.id.canonical)
          .toList();
      expect(ids, contains(kept.canonical));
      expect(ids, isNot(contains(gone.canonical)));

      // Soft, not hard: the row and its items are still there.
      final List<UserCollectionRow> rows = await dbs.user
          .select(dbs.user.userCollections)
          .get();
      expect(rows, hasLength(2));
      expect(
        rows.firstWhere((UserCollectionRow r) => r.id == gone.uuid).deletedAt,
        isNotNull,
      );
    });

    test('a soft-deleted collection no longer resolves', () async {
      final UserCollectionId id = await collections.create('Gone');
      await collections.delete(id);
      expect(
        () => collections.resolve(id),
        throwsA(isA<CollectionNotFoundException>()),
      );
    });
  });
}
