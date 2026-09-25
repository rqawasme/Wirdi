import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/repositories/drift_user_dhikr_repository.dart';
import 'package:wirdi/domain/domain.dart';

import '../support/fixtures.dart';

/// The adhkar the user writes: reading them, changing them, and what deleting
/// one does to the collections that held it.
///
/// The Arabic in here is placeholder text describing which row it is. No dhikr
/// text is invented anywhere in these fixtures.
void main() {
  late TestDatabases dbs;
  late DriftUserDhikrRepository adhkar;
  late CollectionRepository collections;

  setUp(() async {
    dbs = await TestDatabases.open();
    adhkar = DriftUserDhikrRepository(dbs.user);
    collections = dbs.collectionRepository();
  });

  tearDown(() => dbs.close());

  DhikrDraft draft(String label, {int count = 1, String? translation}) =>
      DhikrDraft(
        textArabic: 'PLACEHOLDER $label arabic',
        translation: translation,
        defaultCount: count,
      );

  group('writing one', () {
    test('comes back as a Dhikr that knows which row it is', () async {
      final UserDhikrRef ref = await adhkar.create(
        draft('first', count: 33, translation: 'PLACEHOLDER first translation'),
      );

      final Dhikr written = (await adhkar.all()).single;
      expect(written.ref, ref);
      expect(written.textArabic, 'PLACEHOLDER first arabic');
      expect(written.translation, 'PLACEHOLDER first translation');
      expect(written.defaultCount, 33);
      // The content build's fields are not the user's.
      expect(written.sourceId, isNull);
      expect(written.benefits, isNull);
    });

    test('keeps a null translation null rather than empty', () async {
      await adhkar.create(draft('untranslated'));
      expect((await adhkar.all()).single.translation, isNull);
    });

    test('lists newest first', () async {
      // One clock for both writes: the order must not depend on the two
      // landing in different milliseconds, so `id` breaks the tie and
      // `created_at DESC` decides where it can.
      final DateTime start = DateTime(2026, 3, 14, 9);
      final DriftUserDhikrRepository dated = DriftUserDhikrRepository(
        dbs.user,
        clock: () => start,
      );
      await dated.create(draft('older'));
      final DriftUserDhikrRepository later = DriftUserDhikrRepository(
        dbs.user,
        clock: () => start.add(const Duration(minutes: 1)),
      );
      await later.create(draft('newer'));

      expect(
        (await adhkar.all()).map((Dhikr d) => d.textArabic).toList(),
        <String>['PLACEHOLDER newer arabic', 'PLACEHOLDER older arabic'],
      );
    });
  });

  group('changing one', () {
    test('is shared by every collection that says it', () async {
      final UserDhikrRef ref = await adhkar.create(draft('first', count: 3));
      final UserCollectionId a = await collections.create('A');
      final UserCollectionId b = await collections.create('B');
      await collections.addItem(a, ref);
      await collections.addItem(b, ref);

      await adhkar.update(
        ref,
        draft('edited', count: 7, translation: 'PLACEHOLDER edited'),
      );

      for (final UserCollectionId id in <UserCollectionId>[a, b]) {
        final DhikrItem item =
            (await collections.resolve(id)).entries.single as DhikrItem;
        expect(item.dhikr.textArabic, 'PLACEHOLDER edited arabic');
        expect(item.dhikr.translation, 'PLACEHOLDER edited');
        // The item carries no override, so the new default is what it says.
        expect(item.count, 7);
      }
    });

    test('an item with its own count keeps it', () async {
      final UserDhikrRef ref = await adhkar.create(draft('first', count: 3));
      final UserCollectionId id = await collections.create('A');
      await collections.addItem(id, ref, count: 100);

      await adhkar.update(ref, draft('first', count: 7));

      final DhikrItem item =
          (await collections.resolve(id)).entries.single as DhikrItem;
      expect(item.count, 100);
      expect(item.dhikr.defaultCount, 7);
    });

    test('one that is gone refuses rather than writing nothing', () async {
      final UserDhikrRef ref = await adhkar.create(draft('first'));
      await adhkar.delete(ref);

      expect(
        () => adhkar.update(ref, draft('first')),
        throwsA(isA<DhikrNotFoundException>()),
      );
    });
  });

  group('what holds one', () {
    test('counts items, not collections', () async {
      final UserDhikrRef ref = await adhkar.create(draft('first'));
      final UserCollectionId id = await collections.create('A');
      // Said twice in the same collection: two items, one collection.
      await collections.addItem(id, ref);
      await collections.addItem(id, ref);

      expect(await adhkar.usage(), <UserDhikrRef, int>{ref: 2});
      expect(
        (await adhkar.usedBy(ref)).map((CollectionSummary c) => c.name),
        <String>['A'],
      );
    });

    test('a dhikr nothing holds is absent rather than zero', () async {
      await adhkar.create(draft('first'));
      expect(await adhkar.usage(), isEmpty);
    });

    test('a deleted collection does not count as holding one', () async {
      final UserDhikrRef ref = await adhkar.create(draft('first'));
      final UserCollectionId id = await collections.create('A');
      await collections.addItem(id, ref);
      await collections.delete(id);

      expect(await adhkar.usage(), isEmpty);
      expect(await adhkar.usedBy(ref), isEmpty);
    });
  });

  group('deleting one', () {
    test('takes it out of every collection that held it', () async {
      final UserDhikrRef ref = await adhkar.create(draft('mine'));
      final UserCollectionId a = await collections.create('A');
      final UserCollectionId b = await collections.create('B');
      await collections.addItem(a, ref);
      await collections.addItem(a, const ContentRef.dhikr(1001));
      await collections.addItem(b, ref);

      await adhkar.delete(ref);

      expect(await adhkar.all(), isEmpty);
      // What was beside it is untouched, and B is empty rather than holding a
      // row that resolves to nothing.
      final ResolvedCollection left = await collections.resolve(a);
      expect(left.unresolved, isEmpty);
      expect(
        (left.entries.single as DhikrItem).dhikr.ref,
        const ContentRef.dhikr(1001),
      );
      expect((await collections.resolve(b)).entries, isEmpty);
    });

    test('closes the gap it leaves in position', () async {
      // Not tidiness: setRepeatGroup refuses a run that is not contiguous by
      // position, so a collection left carrying a gap has items that look
      // adjacent and cannot be grouped.
      final UserDhikrRef ref = await adhkar.create(draft('mine'));
      final UserCollectionId id = await collections.create('A');
      await collections.addItem(id, const ContentRef.dhikr(1001));
      await collections.addItem(id, ref);
      await collections.addItem(id, const ContentRef.surah(112));
      await collections.addItem(id, const ContentRef.surah(113));

      await adhkar.delete(ref);

      final ResolvedCollection after = await collections.resolve(id);
      expect(
        after.entries.map((CollectionEntry e) => e.position).toList(),
        <int>[1, 2, 3],
      );

      // And the proof that it mattered: the two surahs are adjacent now, so
      // they can be grouped.
      final List<String> surahIds = after.entries
          .whereType<SurahItem>()
          .map((SurahItem e) => e.entryId)
          .toList();
      await collections.setRepeatGroup(id, surahIds, 3);
      expect(
        (await collections.resolve(id)).entries.last,
        isA<RepeatBlock>().having(
          (RepeatBlock b) => b.repeatCount,
          'repeatCount',
          3,
        ),
      );
    });

    test('leaves a repeat block it was part of standing', () async {
      final UserDhikrRef ref = await adhkar.create(draft('mine'));
      final UserCollectionId id = await collections.create('A');
      await collections.addItem(id, const ContentRef.dhikr(1001));
      await collections.addItem(id, ref);
      final ResolvedCollection before = await collections.resolve(id);
      await collections.setRepeatGroup(
        id,
        before.entries
            .whereType<CollectionItemEntry>()
            .map((CollectionItemEntry e) => e.entryId)
            .toList(),
        3,
      );

      await adhkar.delete(ref);

      final ResolvedCollection after = await collections.resolve(id);
      final RepeatBlock block = after.entries.single as RepeatBlock;
      expect(block.repeatCount, 3);
      expect(block.entries, hasLength(1));
      expect(after.steps, hasLength(3));
    });

    test('the dhikr row is tombstoned, not dropped', () async {
      final UserDhikrRef ref = await adhkar.create(draft('mine'));
      await adhkar.delete(ref);

      expect(await adhkar.all(), isEmpty);

      // The row itself is still there, as a deleted collection's is: `all()`
      // filters it, and nothing has thrown away what somebody wrote.
      final int count =
          (await dbs.user
                  .customSelect('SELECT COUNT(*) AS c FROM user_adhkar')
                  .getSingle())
              .read<int>('c');
      expect(count, 1);
    });

    test('one already deleted refuses', () async {
      final UserDhikrRef ref = await adhkar.create(draft('mine'));
      await adhkar.delete(ref);

      expect(() => adhkar.delete(ref), throwsA(isA<DhikrNotFoundException>()));
    });

    test('progress parked on the deleted step stops resuming', () async {
      final UserDhikrRef ref = await adhkar.create(draft('mine'));
      final UserCollectionId id = await collections.create('A');
      await collections.addItem(id, const ContentRef.dhikr(1001));
      await collections.addItem(id, ref);

      final UserRepository user = dbs.userRepository();
      final ResolvedCollection before = await collections.resolve(id);
      await user.saveProgress(
        WirdProgress.atStep(
          collectionId: id,
          step: before.steps.last,
          currentCount: 2,
        ),
      );

      await adhkar.delete(ref);

      // Nothing cleared the row: the ref it was written against no longer
      // matches what sits at that index, and resumableFrom is what refuses it.
      final ResolvedCollection after = await collections.resolve(id);
      expect(await user.progress(id), isNotNull);
      expect(after.resumableFrom(await user.progress(id)), isNull);
    });
  });

  group('resolution', () {
    test('a collection of both kinds resolves in order', () async {
      final UserDhikrRef mine = await adhkar.create(draft('mine', count: 5));
      final UserCollectionId id = await collections.create('A');
      await collections.addItem(id, const ContentRef.dhikr(1001));
      await collections.addItem(id, mine);
      await collections.addItem(id, const ContentRef.ayah(2255));

      final ResolvedCollection resolved = await collections.resolve(id);
      expect(
        resolved.entries
            .whereType<CollectionItemEntry>()
            .map((CollectionItemEntry e) => e.ref.canonical)
            .toList(),
        <String>['dhikr:1001', mine.canonical, 'ayah:2255'],
      );
      // And it plays: one step each, the middle one said five times.
      expect(resolved.steps.map((PlaybackStep s) => s.count).toList(), <int>[
        1,
        5,
        1,
      ]);
    });

    test('an item naming a dhikr that is gone is reported, not fatal', () async {
      // Unreachable through the app — deleting a dhikr takes its items with it
      // — so this is written by hand, which is what a database restored from a
      // backup mid-write could look like.
      final UserCollectionId id = await collections.create('A');
      await insertUserItem(
        dbs.user,
        id: 'i1',
        collectionId: id.uuid,
        position: 1,
        itemType: 'user_dhikr',
        itemId: 0,
        userItemId: testUuid(9),
      );
      await collections.addItem(id, const ContentRef.dhikr(1001));

      final ResolvedCollection resolved = await collections.resolve(id);
      expect(resolved.entries, hasLength(1));
      expect(resolved.unresolved, <ItemRef>[UserDhikrRef(testUuid(9))]);
    });

    test('a row whose uuid is malformed drops out on its own', () async {
      final UserCollectionId id = await collections.create('A');
      await insertUserItem(
        dbs.user,
        id: 'i1',
        collectionId: id.uuid,
        position: 1,
        itemType: 'user_dhikr',
        itemId: 0,
        userItemId: 'not-a-uuid',
      );

      final ResolvedCollection resolved = await collections.resolve(id);
      expect(resolved.entries, isEmpty);
      // Nothing to report it as: the columns name nothing this app can read,
      // so there is no ref to put in the list.
      expect(resolved.unresolved, isEmpty);
    });
  });
}
