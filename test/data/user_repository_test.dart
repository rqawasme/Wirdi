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
          stepIndex: 3,
          stepRef: const ContentRef.dhikr(1001),
          currentCount: 17,
          updatedAt: now,
        ),
      );

      final WirdProgress? resumed = await user.progress(builtin);
      expect(resumed, isNotNull);
      expect(resumed!.collectionId, builtin);
      expect(resumed.stepIndex, 3);
      expect(resumed.stepRef, const ContentRef.dhikr(1001));
      expect(resumed.currentCount, 17);
      expect(resumed.updatedAt, now);
    });

    test('saves and resumes for a user collection', () async {
      await user.saveProgress(
        WirdProgress(
          collectionId: mine,
          stepIndex: 1,
          stepRef: const ContentRef.surah(112),
          currentCount: 4,
          updatedAt: now,
        ),
      );

      final WirdProgress? resumed = await user.progress(mine);
      expect(resumed!.collectionId, mine);
      expect(resumed.stepIndex, 1);
      expect(resumed.stepRef, const ContentRef.surah(112));
      expect(resumed.currentCount, 4);
    });

    test('the two kinds do not collide', () async {
      await user.saveProgress(
        WirdProgress(
          collectionId: builtin,
          stepIndex: 3,
          stepRef: const ContentRef.dhikr(1001),
          currentCount: 17,
          updatedAt: now,
        ),
      );
      await user.saveProgress(
        WirdProgress(
          collectionId: mine,
          stepIndex: 1,
          stepRef: const ContentRef.surah(112),
          currentCount: 4,
          updatedAt: now,
        ),
      );

      expect((await user.progress(builtin))!.stepIndex, 3);
      expect((await user.progress(mine))!.stepIndex, 1);
    });

    test('saving again overwrites', () async {
      await user.saveProgress(
        WirdProgress(
          collectionId: builtin,
          stepIndex: 0,
          stepRef: const ContentRef.dhikr(1001),
          currentCount: 1,
          updatedAt: now,
        ),
      );
      await user.saveProgress(
        WirdProgress(
          collectionId: builtin,
          stepIndex: 2,
          stepRef: const ContentRef.ayah(2255),
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
          stepIndex: 2,
          stepRef: const ContentRef.ayah(2255),
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

  group('commitments', () {
    test('nothing is committed to begin with', () async {
      expect(await user.commitments(), isEmpty);
    });

    test('a built-in and a user collection commit the same way', () async {
      await user.commit(builtin, DailySection.morning);
      await user.commit(mine, DailySection.evening);

      final List<Commitment> committed = await user.commitments();
      expect(committed, hasLength(2));
      expect(committed.map((Commitment c) => c.collectionId), <CollectionId>[
        builtin,
        mine,
      ]);
      expect(committed.first.section, DailySection.morning);
      expect(committed.last.section, DailySection.evening);
    });

    test('the order is the order they were committed in', () async {
      final CollectionId second = UserCollectionId(testUuid(2));
      await user.commit(mine, DailySection.today);
      await user.commit(builtin, DailySection.today);
      await user.commit(second, DailySection.today);

      expect(
        (await user.commitments()).map((Commitment c) => c.collectionId),
        <CollectionId>[mine, builtin, second],
      );
    });

    test('committing again moves it and keeps its place', () async {
      await user.commit(mine, DailySection.morning);
      await user.commit(builtin, DailySection.morning);

      // Moving the first one to the evening must not send it to the end of
      // the grid: it is the same commitment, in a different part of the day.
      await user.commit(mine, DailySection.evening);

      final List<Commitment> committed = await user.commitments();
      expect(committed, hasLength(2));
      expect(committed.first.collectionId, mine);
      expect(committed.first.section, DailySection.evening);
      expect(committed.last.collectionId, builtin);
    });

    test('uncommitting takes it off, and leaves the rest alone', () async {
      await user.commit(mine, DailySection.today);
      await user.commit(builtin, DailySection.today);

      await user.uncommit(mine);

      expect(
        (await user.commitments()).map((Commitment c) => c.collectionId),
        <CollectionId>[builtin],
      );
    });

    test('uncommitting something never committed is a no-op', () async {
      await user.uncommit(mine);
      expect(await user.commitments(), isEmpty);
    });

    test('a row written by something else is dropped, not thrown on', () async {
      await user.commit(mine, DailySection.today);
      await dbs.user.customStatement(
        "INSERT INTO commitments (collection_ref, section, sort_order, "
        "created_at, updated_at) VALUES ('x:nonsense', 'daily', 2, 0, 0), "
        "('b:99', 'afternoon', 3, 0, 0)",
      );

      // The unparseable id and the unknown section both fall out; the real
      // commitment is still there.
      expect(
        (await user.commitments()).map((Commitment c) => c.collectionId),
        <CollectionId>[mine],
      );
    });
  });

  group('commitment days', () {
    test('a commitment is every day unless it says otherwise', () async {
      await user.commit(mine, DailySection.today);

      final Commitment committed = (await user.commitments()).single;
      expect(committed.days, Weekdays.everyDay);
      expect(committed.days.isEveryDay, isTrue);
      for (
        int weekday = DateTime.monday;
        weekday <= DateTime.sunday;
        weekday++
      ) {
        expect(committed.days.contains(weekday), isTrue);
      }
    });

    test('days are stored and read back', () async {
      // Al-Kahf on a Friday: the case this exists for.
      await user.commit(
        mine,
        DailySection.today,
        days: Weekdays.of(<int>[DateTime.friday]),
      );

      final Commitment committed = (await user.commitments()).single;
      expect(committed.days.weekdays, <int>[DateTime.friday]);
      expect(committed.days.isEveryDay, isFalse);
      expect(committed.fallsOn(DateTime(2026, 9, 4)), isTrue); // a Friday
      expect(committed.fallsOn(DateTime(2026, 9, 5)), isFalse); // a Saturday
    });

    test('changing the days keeps the commitment in its place', () async {
      await user.commit(mine, DailySection.today);
      await user.commit(builtin, DailySection.today);

      await user.commit(
        mine,
        DailySection.today,
        days: Weekdays.of(<int>[DateTime.monday, DateTime.thursday]),
      );

      final List<Commitment> committed = await user.commitments();
      expect(committed.first.collectionId, mine);
      expect(committed.first.days.weekdays, <int>[
        DateTime.monday,
        DateTime.thursday,
      ]);
      expect(committed.last.collectionId, builtin);
    });
  });
}
