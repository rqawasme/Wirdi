import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/collections/collection_editing.dart';
import 'package:wirdi/collections/picked_item.dart';
import 'package:wirdi/data/user_database.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/editing.dart';

import '../support/fixtures.dart';

/// Everything phase 6 does to a collection, over the phase 2 repository
/// unchanged.
void main() {
  late TestDatabases dbs;
  late CollectionRepository collections;
  late UserRepository user;
  late CollectionEditor editor;

  const CollectionId mixed = BuiltinCollectionId(mixedCollectionId);

  setUp(() async {
    dbs = await TestDatabases.open();
    collections = dbs.collectionRepository();
    user = dbs.userRepository();
    editor = CollectionEditor(
      collections: collections,
      content: dbs.contentRepository(),
    );
  });

  tearDown(() => dbs.close());

  /// The `count_override` column as written, which is not what `resolve`
  /// returns: resolution has already applied the fallbacks.
  Future<List<int?>> rawOverrides(UserCollectionId id) async {
    final List<UserCollectionItemRow> rows = await dbs.user
        .itemsForUserCollection(collection: id.uuid)
        .get();
    return <int?>[
      for (final UserCollectionItemRow row in rows) row.countOverride,
    ];
  }

  Future<List<ContentRef>> refsOf(ResolvedCollection collection) async {
    return <ContentRef>[
      for (final CollectionEntry entry in collection.entries)
        ...switch (entry) {
          CollectionItemEntry(:final ContentRef ref) => <ContentRef>[ref],
          RepeatBlock(entries: final List<CollectionItemEntry> members) =>
            members.map((CollectionItemEntry e) => e.ref),
        },
    ];
  }

  group('creating', () {
    test('a new collection resolves as itself, empty', () async {
      final UserCollectionId id = await editor.create(
        '  Morning  ',
        description: '  After fajr  ',
      );

      final ResolvedCollection resolved = await collections.resolve(id);
      // Trimmed on the way in: a name with a trailing space sorts and reads
      // as a different name from the one somebody typed.
      expect(resolved.collection.name, 'Morning');
      expect(resolved.collection.description, 'After fajr');
      expect(resolved.entries, isEmpty);
      expect(resolved.steps, isEmpty);

      // And it is in the list the collections screen reads.
      final List<CollectionSummary> all = await collections.all();
      expect(all.map((CollectionSummary s) => s.id), contains(id));
    });

    test('a collection with no name is refused, readably', () async {
      expect(
        () => editor.create('   '),
        throwsA(
          isA<CollectionEditingError>().having(
            (CollectionEditingError e) => e.message,
            'message',
            'A collection needs a name.',
          ),
        ),
      );
    });
  });

  group('duplicating a built-in', () {
    test('preserves order, counts, notes and repeat groups', () async {
      final ResolvedCollection source = await collections.resolve(mixed);
      final UserCollectionId copy = await editor.duplicate(
        mixed,
        name: 'My Haddad',
      );
      final ResolvedCollection made = await collections.resolve(copy);

      // Order, item by item, blocks flattened.
      expect(await refsOf(made), await refsOf(source));

      // Structure: four loose items, one block of three, one trailing item.
      expect(made.entries.length, source.entries.length);
      expect(
        made.entries.map((CollectionEntry e) => e.runtimeType),
        source.entries.map((CollectionEntry e) => e.runtimeType),
      );

      // Counts as resolution reports them — the override on dhikr 1002, and
      // the defaults everywhere else.
      List<int> counts(ResolvedCollection c) => <int>[
        for (final CollectionEntry entry in c.entries)
          ...switch (entry) {
            CollectionItemEntry(:final int count) => <int>[count],
            RepeatBlock(entries: final List<CollectionItemEntry> members) =>
              members.map((CollectionItemEntry e) => e.count),
          },
      ];
      expect(counts(made), counts(source));

      // Notes, including the one the content pipeline authored on the last
      // item. `addItem` takes a note precisely so this survives.
      List<String?> notes(ResolvedCollection c) => <String?>[
        for (final CollectionEntry entry in c.entries)
          ...switch (entry) {
            CollectionItemEntry(:final String? note) => <String?>[note],
            RepeatBlock(entries: final List<CollectionItemEntry> members) =>
              members.map((CollectionItemEntry e) => e.note),
          },
      ];
      expect(notes(made), notes(source));
      expect(notes(made), contains('PLACEHOLDER item note'));

      // The repeat block, re-formed over the run it occupied.
      final RepeatBlock block = made.entries.whereType<RepeatBlock>().single;
      expect(block.entries.length, 3);
      expect(block.repeatCount, 3);
      expect(block.entries.map((CollectionItemEntry e) => e.ref), <ContentRef>[
        const ContentRef.surah(112),
        const ContentRef.surah(113),
        const ContentRef.surah(114),
      ]);

      // And the playback view agrees, which is the thing the player walks.
      expect(made.steps.length, source.steps.length);
    });

    test('writes an override only where the source had one', () async {
      final UserCollectionId copy = await editor.duplicate(
        mixed,
        name: 'My Haddad',
      );

      // Copying the resolved count back verbatim would write an override onto
      // every row, freezing today's default_count into the copy. Only dhikr
      // 1002 was actually overridden, at 100 over a default of 33.
      expect(await rawOverrides(copy), <int?>[
        null,
        100,
        null,
        null,
        null,
        null,
        null,
        null,
      ]);
    });

    test('a copy is editable where the built-in was not', () async {
      final UserCollectionId copy = await editor.duplicate(
        mixed,
        name: 'My Haddad',
      );
      await editor.addItems(copy, <PickedItem>[
        const PickedItem(ref: ContentRef.dhikr(1004), count: 7),
      ]);

      final ResolvedCollection made = await collections.resolve(copy);
      expect(made.entries.length, 7);
      final CollectionItemEntry added =
          made.entries.last as CollectionItemEntry;
      expect(added.ref, const ContentRef.dhikr(1004));
      expect(added.count, 7);
    });
  });

  group('adding items', () {
    test('an ayah range inserts consecutive items, in order', () async {
      final UserCollectionId id = await editor.create('Passages');
      await editor.addItems(id, await editor.ayahRange(1, 2, 5));

      final ResolvedCollection resolved = await collections.resolve(id);
      expect(await refsOf(resolved), <ContentRef>[
        ContentRef.ayahAt(1, 2),
        ContentRef.ayahAt(1, 3),
        ContentRef.ayahAt(1, 4),
        ContentRef.ayahAt(1, 5),
      ]);
      // Dense positions, in the order they were added: everything downstream
      // — the player's step list, a later grouping — reads position.
      expect(resolved.entries.map((CollectionEntry e) => e.position), <int>[
        1,
        2,
        3,
        4,
      ]);
    });

    test(
      'a range past the end of the surah is clamped, not invented',
      () async {
        final UserCollectionId id = await editor.create('Passages');
        // Al-Fatiha is 7 ayahs in the fixture.
        await editor.addItems(id, await editor.ayahRange(1, 5, 20));

        final ResolvedCollection resolved = await collections.resolve(id);
        expect(await refsOf(resolved), <ContentRef>[
          ContentRef.ayahAt(1, 5),
          ContentRef.ayahAt(1, 6),
          ContentRef.ayahAt(1, 7),
        ]);
      },
    );

    test('a range carries one count and note onto every ayah', () async {
      final UserCollectionId id = await editor.create('Passages');
      await editor.addItems(
        id,
        await editor.ayahRange(1, 1, 3, count: 3, note: 'Three times each'),
      );

      final ResolvedCollection resolved = await collections.resolve(id);
      for (final CollectionEntry entry in resolved.entries) {
        expect((entry as CollectionItemEntry).count, 3);
        expect(entry.note, 'Three times each');
      }
    });
  });

  group('count override', () {
    test('is what resolve returns, over the natural count', () async {
      final UserCollectionId id = await editor.create('Counted');
      // Dhikr 1002 says 33; this item says 100.
      await editor.addItems(id, <PickedItem>[
        const PickedItem(ref: ContentRef.dhikr(1002), count: 100),
        const PickedItem(ref: ContentRef.dhikr(1002)),
      ]);

      final ResolvedCollection resolved = await collections.resolve(id);
      final List<CollectionItemEntry> items = resolved.entries
          .cast<CollectionItemEntry>()
          .toList();
      expect(items[0].count, 100);
      // Left alone, so the dhikr's own default_count still governs — which is
      // the difference an override that is null preserves.
      expect(items[1].count, 33);
      expect(await rawOverrides(id), <int?>[100, null]);

      // And the player's flattened view carries it too.
      expect(resolved.steps.first.count, 100);
    });
  });

  group('reordering', () {
    late UserCollectionId id;

    setUp(() async {
      id = await editor.create('Order');
      await editor.addItems(id, <PickedItem>[
        const PickedItem(ref: ContentRef.dhikr(1001)),
        const PickedItem(ref: ContentRef.dhikr(1002)),
        const PickedItem(ref: ContentRef.dhikr(1003)),
        const PickedItem(ref: ContentRef.dhikr(1004)),
      ]);
    });

    test(
      'moving an entry produces a full permutation the repository takes',
      () async {
        final ResolvedCollection before = await collections.resolve(id);
        final List<String> all = itemIdsInOrder(before.entries);

        final List<String> order = reorderedItemIds(before.entries, 3, 0);

        // A full permutation is what reorder demands: every item exactly once.
        expect(order.length, all.length);
        expect(order.toSet(), all.toSet());
        expect(order.first, all[3]);
        expect(order.sublist(1), <String>[all[0], all[1], all[2]]);

        await editor.moveEntry(id, before.entries, 3, 0);
        final ResolvedCollection after = await collections.resolve(id);
        expect(await refsOf(after), <ContentRef>[
          const ContentRef.dhikr(1004),
          const ContentRef.dhikr(1001),
          const ContentRef.dhikr(1002),
          const ContentRef.dhikr(1003),
        ]);
        // Renumbered 1..N, densely.
        expect(after.entries.map((CollectionEntry e) => e.position), <int>[
          1,
          2,
          3,
          4,
        ]);
      },
    );

    test('a repeat block moves as one row, and stays contiguous', () async {
      final ResolvedCollection loose = await collections.resolve(id);
      final List<String> ids = itemIdsInOrder(loose.entries);
      await editor.group(id, loose.entries, <String>{ids[1], ids[2]}, 3);

      final ResolvedCollection grouped = await collections.resolve(id);
      // Three entries now: an item, the block, an item.
      expect(grouped.entries.length, 3);
      expect(grouped.entries[1], isA<RepeatBlock>());

      // Drag the block to the front. It is one entry, so this is one move.
      await editor.moveEntry(id, grouped.entries, 1, 0);

      final ResolvedCollection after = await collections.resolve(id);
      expect(after.entries.first, isA<RepeatBlock>());
      final RepeatBlock block = after.entries.first as RepeatBlock;
      expect(block.entries.map((CollectionItemEntry e) => e.ref), <ContentRef>[
        const ContentRef.dhikr(1002),
        const ContentRef.dhikr(1003),
      ]);
      expect(block.repeatCount, 3);
      // Contiguous by position, which is what makes it one block on read.
      expect(block.entries.map((CollectionItemEntry e) => e.position), <int>[
        1,
        2,
      ]);
    });

    test(
      'an order that would split a repeat group is refused, readably',
      () async {
        final ResolvedCollection loose = await collections.resolve(id);
        final List<String> ids = itemIdsInOrder(loose.entries);
        await editor.group(id, loose.entries, <String>{ids[1], ids[2]}, 3);

        final ResolvedCollection grouped = await collections.resolve(id);
        final List<String> members = itemIdsInOrder(<CollectionEntry>[
          grouped.entries[1],
        ]);
        final String loose1 =
            (grouped.entries[0] as CollectionItemEntry).entryId;
        final String loose2 =
            (grouped.entries[2] as CollectionItemEntry).entryId;

        // A full, valid permutation — which is all the repository checks — with
        // an item pushed between the block's two members.
        final List<String> split = <String>[
          members[0],
          loose1,
          members[1],
          loose2,
        ];

        expect(
          () => checkRepeatGroupsIntact(grouped.entries, split),
          throwsA(
            isA<CollectionEditingError>().having(
              (CollectionEditingError e) => e.message,
              'message',
              allOf(contains('recited as one run'), contains('split it apart')),
            ),
          ),
        );

        // And nothing changed: the guard runs before the write.
        final ResolvedCollection after = await collections.resolve(id);
        expect(after.entries[1], isA<RepeatBlock>());
        expect((after.entries[1] as RepeatBlock).entries.length, 2);
      },
    );
  });

  group('grouping', () {
    late UserCollectionId id;
    late List<String> ids;
    late List<CollectionEntry> entries;

    setUp(() async {
      id = await editor.create('Blocks');
      await editor.addItems(id, <PickedItem>[
        const PickedItem(ref: ContentRef.dhikr(1001)),
        const PickedItem(ref: ContentRef.dhikr(1002)),
        const PickedItem(ref: ContentRef.dhikr(1003)),
        const PickedItem(ref: ContentRef.dhikr(1004)),
      ]);
      entries = (await collections.resolve(id)).entries;
      ids = itemIdsInOrder(entries);
    });

    test('a non-contiguous selection is refused, readably', () async {
      expect(
        () => editor.group(id, entries, <String>{ids[0], ids[2]}, 3),
        throwsA(
          isA<CollectionEditingError>().having(
            (CollectionEditingError e) => e.message,
            'message',
            'A repeat block has to be one unbroken run. '
                'Choose items that sit next to each other.',
          ),
        ),
      );

      // Refused before the repository was asked, so nothing is grouped.
      final ResolvedCollection after = await collections.resolve(id);
      expect(after.entries.whereType<RepeatBlock>(), isEmpty);
    });

    test('fewer than one repetition is refused, readably', () async {
      expect(
        () => editor.group(id, entries, <String>{ids[0], ids[1]}, 0),
        throwsA(
          isA<CollectionEditingError>().having(
            (CollectionEditingError e) => e.message,
            'message',
            'A repeat block is recited at least once.',
          ),
        ),
      );
    });

    test('an item already in a block is refused, readably', () async {
      await editor.group(id, entries, <String>{ids[0], ids[1]}, 3);
      final List<CollectionEntry> grouped = (await collections.resolve(
        id,
      )).entries;

      expect(
        () => editor.group(id, grouped, <String>{ids[1], ids[2]}, 2),
        throwsA(
          isA<CollectionEditingError>().having(
            (CollectionEditingError e) => e.message,
            'message',
            'Those items are already in a repeat block. '
                'Ungroup it before making a new one.',
          ),
        ),
      );
    });

    test('ungrouping is the inverse', () async {
      await editor.group(id, entries, <String>{ids[0], ids[1]}, 3);
      final ResolvedCollection grouped = await collections.resolve(id);
      final RepeatBlock block = grouped.entries.whereType<RepeatBlock>().single;
      // Two items and two more, recited three times over: 2 x 3 + 2.
      expect(grouped.steps.length, 8);

      await editor.ungroup(id, block.group);

      final ResolvedCollection after = await collections.resolve(id);
      expect(after.entries.whereType<RepeatBlock>(), isEmpty);
      expect(after.entries.length, 4);
      expect(after.steps.length, 4);
    });

    test(
      'removing an item closes the gap it left, so grouping still works',
      () async {
        // removeItem does not renumber, and setRepeatGroup refuses a run that is
        // not contiguous *by position* — so without the renumbering the editor
        // does, these two would look adjacent in the list and refuse to group.
        await editor.removeItem(id, ids[1]);

        final ResolvedCollection after = await collections.resolve(id);
        expect(after.entries.map((CollectionEntry e) => e.position), <int>[
          1,
          2,
          3,
        ]);
        await editor.group(id, after.entries, <String>{ids[0], ids[2]}, 2);

        final ResolvedCollection grouped = await collections.resolve(id);
        expect(
          grouped.entries.whereType<RepeatBlock>().single.entries.length,
          2,
        );
      },
    );
  });

  group('deleting', () {
    test('takes the collection out of the list, clears progress and keeps '
        'completions', () async {
      final UserCollectionId id = await editor.create('Going');
      await editor.addItems(id, <PickedItem>[
        const PickedItem(ref: ContentRef.dhikr(1001)),
      ]);
      await user.saveProgress(
        WirdProgress(
          collectionId: id,
          stepIndex: 0,
          stepRef: const ContentRef.dhikr(1001),
          currentCount: 4,
        ),
      );
      await user.logCompletion(id, DateTime(2026, 3, 13, 8));

      expect(
        (await collections.all()).map((CollectionSummary s) => s.id),
        contains(id),
      );

      await editor.delete(id);

      // Gone from the list the collections screen reads.
      expect(
        (await collections.all()).map((CollectionSummary s) => s.id),
        isNot(contains(id)),
      );
      // In-flight state is meaningless for a collection that is gone.
      expect(await user.progress(id), isNull);
      // The days somebody actually spent on it are not: a streak runs across
      // every collection, deleted ones included.
      expect(await user.completionDates(), <String>['2026-03-13']);

      // Soft: resolving it by id still refuses, rather than returning a
      // half-deleted collection.
      expect(
        () => collections.resolve(id),
        throwsA(isA<CollectionNotFoundException>()),
      );
    });
  });
}
