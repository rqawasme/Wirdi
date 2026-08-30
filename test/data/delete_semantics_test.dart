import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/domain.dart';

import '../support/fixtures.dart';

/// Deleting a user collection splits by kind of data: in-flight progress goes,
/// historical completions stay.
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

  test('delete clears progress and preserves completions', () async {
    final UserCollectionId id = await collections.create('Mine');
    await collections.addItem(id, const ContentRef.dhikr(1001));

    await user.saveProgress(
      WirdProgress(
        collectionId: id,
        stepIndex: 0,
        stepRef: const ContentRef.dhikr(1001),
        currentCount: 7,
        updatedAt: now,
      ),
    );
    await user.logCompletion(id, DateTime(2026, 3, 13, 8));
    await user.logCompletion(id, DateTime(2026, 3, 14, 8));

    expect(await user.progress(id), isNotNull);

    await collections.delete(id);

    // In-flight state for a deleted collection is meaningless.
    expect(await user.progress(id), isNull);

    // The record of having done it is not.
    expect(await user.completionDates(), <String>['2026-03-13', '2026-03-14']);
    expect(await user.isCompletedToday(id), isTrue);
  });

  test(
    'currentStreak still counts a deleted collection\'s completions',
    () async {
      final UserCollectionId gone = await collections.create('Gone');
      await user.logCompletion(gone, DateTime(2026, 3, 12, 8));
      await user.logCompletion(gone, DateTime(2026, 3, 13, 8));
      await user.logCompletion(gone, DateTime(2026, 3, 14, 8));

      expect(await user.currentStreak(), 3);

      await collections.delete(gone);

      // Deleting the collection must not retroactively break the streak.
      expect(await user.currentStreak(), 3);
      expect(await user.completionDates(), hasLength(3));
    },
  );

  test('an orphaned completion_ref is expected, and still parses', () async {
    final UserCollectionId gone = await collections.create('Gone');
    await user.logCompletion(gone, now);
    await collections.delete(gone);

    // The collection no longer resolves...
    expect(
      () => collections.resolve(gone),
      throwsA(isA<CollectionNotFoundException>()),
    );
    // ...but its completion is still there, under a ref that no longer
    // resolves. Anything grouping completions by collection must tolerate
    // this rather than assume the ref resolves.
    expect(await user.isCompletedToday(gone), isTrue);
  });

  test('deleting one collection leaves another\'s progress alone', () async {
    final UserCollectionId kept = await collections.create('Kept');
    final UserCollectionId gone = await collections.create('Gone');
    for (final UserCollectionId id in <UserCollectionId>[kept, gone]) {
      await collections.addItem(id, const ContentRef.dhikr(1001));
      await user.saveProgress(
        WirdProgress(
          collectionId: id,
          stepIndex: 0,
          stepRef: const ContentRef.dhikr(1001),
          currentCount: 3,
          updatedAt: now,
        ),
      );
    }

    await collections.delete(gone);

    expect(await user.progress(gone), isNull);
    expect((await user.progress(kept))!.currentCount, 3);
  });
}
