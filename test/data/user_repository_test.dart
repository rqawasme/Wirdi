import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/domain.dart';

import '../support/fixtures.dart';

void main() {
  late TestDatabases dbs;
  late UserRepository user;

  /// The repository's idea of "now", movable from a test.
  late DateTime now;

  const CollectionId builtin = BuiltinCollectionId(mixedCollectionId);
  final CollectionId mine = UserCollectionId(testUuid(1));

  setUp(() async {
    dbs = await TestDatabases.open();
    now = DateTime(2026, 3, 14, 9);
    user = dbs.userRepository(clock: () => now);
  });

  tearDown(() => dbs.close());

  group('progress', () {
    test('is null before anything is saved', () async {
      expect(await user.progress(builtin), isNull);
    });

    test('saves and resumes for a built-in collection', () async {
      await user.saveProgress(
        WirdProgress(
          collectionId: builtin,
          itemIndex: 3,
          currentCount: 17,
          updatedAt: now,
        ),
      );

      final WirdProgress? resumed = await user.progress(builtin);
      expect(resumed, isNotNull);
      expect(resumed!.collectionId, builtin);
      expect(resumed.itemIndex, 3);
      expect(resumed.currentCount, 17);
      expect(resumed.updatedAt, now);
    });

    test('saves and resumes for a user collection', () async {
      await user.saveProgress(
        WirdProgress(
          collectionId: mine,
          itemIndex: 1,
          currentCount: 4,
          updatedAt: now,
        ),
      );

      final WirdProgress? resumed = await user.progress(mine);
      expect(resumed!.collectionId, mine);
      expect(resumed.itemIndex, 1);
      expect(resumed.currentCount, 4);
    });

    test('the two kinds do not collide', () async {
      await user.saveProgress(
        WirdProgress(
          collectionId: builtin,
          itemIndex: 3,
          currentCount: 17,
          updatedAt: now,
        ),
      );
      await user.saveProgress(
        WirdProgress(
          collectionId: mine,
          itemIndex: 1,
          currentCount: 4,
          updatedAt: now,
        ),
      );

      expect((await user.progress(builtin))!.itemIndex, 3);
      expect((await user.progress(mine))!.itemIndex, 1);
    });

    test('saving again overwrites', () async {
      await user.saveProgress(
        WirdProgress(
          collectionId: builtin,
          itemIndex: 0,
          currentCount: 1,
          updatedAt: now,
        ),
      );
      await user.saveProgress(
        WirdProgress(
          collectionId: builtin,
          itemIndex: 2,
          currentCount: 9,
          updatedAt: now,
        ),
      );

      expect((await user.progress(builtin))!.currentCount, 9);
    });

    test('clearProgress removes it', () async {
      await user.saveProgress(
        WirdProgress(
          collectionId: builtin,
          itemIndex: 2,
          currentCount: 9,
          updatedAt: now,
        ),
      );
      await user.clearProgress(builtin);
      expect(await user.progress(builtin), isNull);
    });
  });

  group('completions', () {
    test('two on the same local day count once', () async {
      await user.logCompletion(builtin, DateTime(2026, 3, 14, 7, 30));
      await user.logCompletion(builtin, DateTime(2026, 3, 14, 21, 5));

      expect(await user.completionDates(), <String>['2026-03-14']);
      expect(await user.currentStreak(), 1);
    });

    test('completionDates spans collections and is de-duplicated', () async {
      await user.logCompletion(builtin, DateTime(2026, 3, 12, 8));
      await user.logCompletion(mine, DateTime(2026, 3, 12, 20));
      await user.logCompletion(mine, DateTime(2026, 3, 13, 8));

      expect(await user.completionDates(), <String>[
        '2026-03-12',
        '2026-03-13',
      ]);
    });

    test('completionDates honours inclusive bounds', () async {
      for (int day = 10; day <= 14; day++) {
        await user.logCompletion(builtin, DateTime(2026, 3, day, 8));
      }

      expect(
        await user.completionDates(
          from: DateTime(2026, 3, 11),
          to: DateTime(2026, 3, 13),
        ),
        <String>['2026-03-11', '2026-03-12', '2026-03-13'],
      );
      expect(await user.completionDates(from: DateTime(2026, 3, 13)), <String>[
        '2026-03-13',
        '2026-03-14',
      ]);
      expect(await user.completionDates(to: DateTime(2026, 3, 11)), <String>[
        '2026-03-10',
        '2026-03-11',
      ]);
    });
  });

  group('isCompletedToday', () {
    test('follows the local day, not the elapsed time', () async {
      now = DateTime(2026, 3, 14, 23, 59);
      await user.logCompletion(builtin, now);
      expect(await user.isCompletedToday(builtin), isTrue);

      // Two minutes later, but a different local day.
      now = DateTime(2026, 3, 15, 0, 1);
      expect(await user.isCompletedToday(builtin), isFalse);

      // And the record of yesterday is still there.
      expect(await user.completionDates(), <String>['2026-03-14']);
    });

    test('is per collection', () async {
      await user.logCompletion(builtin, now);
      expect(await user.isCompletedToday(builtin), isTrue);
      expect(await user.isCompletedToday(mine), isFalse);
    });
  });

  group('currentStreak', () {
    Future<void> complete(int day) =>
        user.logCompletion(builtin, DateTime(2026, 3, day, 8));

    test('is zero with no completions', () async {
      expect(await user.currentStreak(), 0);
    });

    test('counts consecutive days up to today', () async {
      await complete(12);
      await complete(13);
      await complete(14);
      expect(await user.currentStreak(), 3);
    });

    test('a gap breaks it', () async {
      await complete(10);
      await complete(11);
      // 12 missing
      await complete(13);
      await complete(14);
      expect(await user.currentStreak(), 2);
    });

    test('today being empty does not break it yet', () async {
      await complete(12);
      await complete(13);
      // Nothing today; the day is not over.
      expect(await user.currentStreak(), 2);
    });

    test('but a missed yesterday does', () async {
      await complete(11);
      await complete(12);
      // Neither yesterday nor today.
      expect(await user.currentStreak(), 0);
    });

    test('counts days, not collections', () async {
      await user.logCompletion(builtin, DateTime(2026, 3, 13, 8));
      await user.logCompletion(mine, DateTime(2026, 3, 14, 8));
      expect(await user.currentStreak(), 2);
    });

    test('spans a month boundary', () async {
      now = DateTime(2026, 3, 2, 9);
      await user.logCompletion(builtin, DateTime(2026, 2, 28, 8));
      await user.logCompletion(builtin, DateTime(2026, 3, 1, 8));
      await user.logCompletion(builtin, DateTime(2026, 3, 2, 8));
      expect(await user.currentStreak(), 3);
    });
  });

  group('reading position', () {
    test('is null before anything is saved', () async {
      expect(await user.lastPosition(), isNull);
    });

    test('round-trips, and stays a single row', () async {
      await user.saveLastPosition(
        ReadingPosition(surahNumber: 2, ayahNumber: 255, updatedAt: now),
      );
      await user.saveLastPosition(
        ReadingPosition(surahNumber: 18, ayahNumber: 10, updatedAt: now),
      );

      final ReadingPosition? position = await user.lastPosition();
      expect(position!.surahNumber, 18);
      expect(position.ayahNumber, 10);
      expect(position.updatedAt, now);

      final int rows = await dbs.user
          .customSelect('SELECT COUNT(*) AS c FROM reading_position')
          .map((QueryRow row) => row.read<int>('c'))
          .getSingle();
      expect(rows, 1);
    });
  });

  group('settings', () {
    test('an unset key is null', () async {
      expect(await user.setting('theme'), isNull);
    });

    test('set and read back, last write wins', () async {
      await user.setSetting('theme', 'dark');
      expect(await user.setting('theme'), 'dark');

      await user.setSetting('theme', 'light');
      expect(await user.setting('theme'), 'light');
    });

    test('keys are independent', () async {
      await user.setSetting('theme', 'dark');
      await user.setSetting('arabic_font_scale', '1.4');
      expect(await user.setting('theme'), 'dark');
      expect(await user.setting('arabic_font_scale'), '1.4');
    });
  });
}
