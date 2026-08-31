import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/domain.dart';

import '../support/fixtures.dart';

/// Saving and resuming across the two repositories, the way a player would:
/// read the stored progress, then validate it against the collection as it is
/// now.
void main() {
  late TestDatabases dbs;
  late CollectionRepository collections;
  late UserRepository user;
  late DateTime now;

  setUp(() async {
    dbs = await TestDatabases.open();
    now = DateTime(2026, 3, 14, 9);
    collections = dbs.collectionRepository(clock: () => now);
    user = dbs.userRepository(clock: () => now);
  });

  tearDown(() => dbs.close());

  /// What a player does on open: load, then validate before trusting.
  Future<WirdProgress?> resume(CollectionId id) async {
    final ResolvedCollection resolved = await collections.resolve(id);
    return resolved.resumableFrom(await user.progress(id));
  }

  test('a built-in collection resumes mid repeat block', () async {
    const CollectionId id = BuiltinCollectionId(mixedCollectionId);
    final ResolvedCollection resolved = await collections.resolve(id);

    // 4 loose entries before the block, then 3 surahs x 3 rounds, then one
    // more: 4 + 9 + 1 = 14 steps from 6 entries.
    expect(resolved.entries, hasLength(6));
    expect(resolved.steps, hasLength(14));

    // Steps 0..3 are the loose items, 4..12 the block pass by pass, 13 the
    // trailing dhikr. Step 8 is the second surah of the second round.
    expect(
      resolved.steps.sublist(4, 13).map((PlaybackStep s) => s.ref.id).toList(),
      <int>[112, 113, 114, 112, 113, 114, 112, 113, 114],
    );
    final PlaybackStep step = resolved.steps[8];
    expect(step.ref, const ContentRef.surah(113));
    expect(step.repetition, 2);
    expect(step.repetitionsTotal, 3);

    await user.saveProgress(
      WirdProgress.atStep(
        collectionId: id,
        step: step,
        currentCount: 1,
        updatedAt: now,
      ),
    );

    final WirdProgress? resumed = await resume(id);
    expect(resumed, isNotNull);
    expect(resumed!.stepIndex, 8);
    expect(resumed.stepRef, const ContentRef.surah(113));
    expect(resolved.steps[resumed.stepIndex].repetition, 2);
  });

  test('a user collection resumes the same way', () async {
    final UserCollectionId id = await collections.create('Mine');
    await collections.addItem(id, const ContentRef.dhikr(1001));
    await collections.addItem(id, const ContentRef.dhikr(1002));

    final ResolvedCollection resolved = await collections.resolve(id);
    await user.saveProgress(
      WirdProgress.atStep(
        collectionId: id,
        step: resolved.steps[1],
        currentCount: 12,
        updatedAt: now,
      ),
    );

    final WirdProgress? resumed = await resume(id);
    expect(resumed!.stepIndex, 1);
    expect(resumed.stepRef, const ContentRef.dhikr(1002));
    expect(resumed.currentCount, 12);
  });

  test('reordering underneath saved progress resets it', () async {
    final UserCollectionId id = await collections.create('Mine');
    await collections.addItem(id, const ContentRef.dhikr(1001));
    await collections.addItem(id, const ContentRef.dhikr(1002));
    await collections.addItem(id, const ContentRef.dhikr(1003));

    final ResolvedCollection before = await collections.resolve(id);
    await user.saveProgress(
      WirdProgress.atStep(
        collectionId: id,
        step: before.steps[2],
        currentCount: 2,
        updatedAt: now,
      ),
    );
    expect((await resume(id))!.stepIndex, 2);

    // Move the last item to the front. Step 2 now holds something else.
    final List<String> ids = before.entries
        .cast<CollectionItemEntry>()
        .map((CollectionItemEntry e) => e.entryId)
        .toList();
    await collections.reorder(id, <String>[ids[2], ids[0], ids[1]]);

    expect(
      await resume(id),
      isNull,
      reason: 'a stale index must not resume at the wrong dhikr',
    );
    // The row is still there; it is the validation that refuses it.
    expect(await user.progress(id), isNotNull);
  });

  test(
    'removing an item shrinks the collection past the saved index',
    () async {
      final UserCollectionId id = await collections.create('Mine');
      await collections.addItem(id, const ContentRef.dhikr(1001));
      await collections.addItem(id, const ContentRef.dhikr(1002));

      final ResolvedCollection before = await collections.resolve(id);
      await user.saveProgress(
        WirdProgress.atStep(
          collectionId: id,
          step: before.steps[1],
          currentCount: 4,
          updatedAt: now,
        ),
      );

      await collections.removeItem(
        id,
        (before.entries.last as CollectionItemEntry).entryId,
      );

      expect(await resume(id), isNull);
    },
  );

  test('grouping items underneath saved progress resets it', () async {
    final UserCollectionId id = await collections.create('Mine');
    await collections.addItem(id, const ContentRef.surah(112));
    await collections.addItem(id, const ContentRef.surah(113));
    await collections.addItem(id, const ContentRef.dhikr(1001));

    final ResolvedCollection before = await collections.resolve(id);
    // The dhikr, at step 2.
    await user.saveProgress(
      WirdProgress.atStep(
        collectionId: id,
        step: before.steps[2],
        currentCount: 1,
        updatedAt: now,
      ),
    );
    expect((await resume(id))!.stepRef, const ContentRef.dhikr(1001));

    final List<String> surahIds = before.entries
        .cast<CollectionItemEntry>()
        .where((CollectionItemEntry e) => e.ref.type == ContentType.surah)
        .map((CollectionItemEntry e) => e.entryId)
        .toList();
    await collections.setRepeatGroup(id, surahIds, 3);

    // Step 2 is now the first surah of the second round, not the dhikr.
    final ResolvedCollection after = await collections.resolve(id);
    expect(after.steps[2].ref, const ContentRef.surah(112));
    expect(await resume(id), isNull);
  });

  test('unchanged content resumes across a reopen', () async {
    const CollectionId id = BuiltinCollectionId(simpleCollectionId);
    final ResolvedCollection resolved = await collections.resolve(id);
    await user.saveProgress(
      WirdProgress.atStep(
        collectionId: id,
        step: resolved.steps.single,
        currentCount: 5,
        updatedAt: now,
      ),
    );

    // A day later, nothing changed.
    now = DateTime(2026, 3, 15, 9);
    final WirdProgress? resumed = await resume(id);
    expect(resumed!.currentCount, 5);
    expect(resumed.stepRef, const ContentRef.dhikr(1004));
  });
}
