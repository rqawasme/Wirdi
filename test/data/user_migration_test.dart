import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:wirdi/data/repositories/drift_user_repository.dart';
import 'package:wirdi/data/user_database.dart';
import 'package:wirdi/domain/domain.dart';

/// `user.db` is migrated, never replaced, so every version the app has shipped
/// has to be able to reach the current one.
///
/// These run the real [UserDatabase.migration] over a database left at an
/// earlier version, rather than replaying the statements it is supposed to
/// issue. That distinction is the whole point: an earlier version of this file
/// checked the 2 -> 3 step by executing the two statements by hand and passed
/// while the app crashed on launch, because the bug was in which steps ran
/// together, not in what any one of them did.
///
/// The old shapes are made by taking the current schema back a version rather
/// than by keeping a copy of the old DDL, which would be one more thing to
/// maintain and would go stale silently.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wirdi_user_');
    file = File(p.join(dir.path, 'user.db'));

    // Created at the current version, then wound back per test.
    final UserDatabase seed = UserDatabase.openFile(file);
    await seed.customSelect('SELECT 1').get();
    await seed.close();
  });

  tearDown(() => dir.delete(recursive: true));

  /// Opens the file raw, applies [statements], and stamps [version].
  void windBackTo(int version, List<String> statements) {
    final sqlite3.Database db = sqlite3.sqlite3.open(file.path);
    for (final String statement in statements) {
      db.execute(statement);
    }
    db.execute('PRAGMA user_version = $version');
    db.close();
  }

  int versionOf(File file) {
    final sqlite3.Database db = sqlite3.sqlite3.open(file.path);
    final int version =
        db.select('PRAGMA user_version').first.values.first! as int;
    db.close();
    return version;
  }

  /// Opens the database, which is what makes drift run the migration.
  Future<List<Commitment>> migrateAndRead() async {
    final UserDatabase db = UserDatabase.openFile(file);
    final List<Commitment> commitments = await DriftUserRepository(
      db,
    ).commitments();
    await db.close();
    return commitments;
  }

  test('version 1 comes forward with an empty commitments table', () async {
    // Before this branch: no commitments at all.
    windBackTo(1, <String>['DROP TABLE commitments']);

    expect(await migrateAndRead(), isEmpty);
    expect(versionOf(file), 5);

    // And the table it created has the days column, so committing works.
    final UserDatabase db = UserDatabase.openFile(file);
    final DriftUserRepository user = DriftUserRepository(db);
    await user.commit(
      const BuiltinCollectionId(1),
      DailySection.today,
      days: Weekdays.of(<int>[DateTime.friday]),
    );
    expect((await user.commitments()).single.days.weekdays, <int>[
      DateTime.friday,
    ]);
    await db.close();
  });

  test('version 2 gains the days column and keeps its rows', () async {
    windBackTo(2, <String>[
      'ALTER TABLE commitments DROP COLUMN days',
      "INSERT INTO commitments (collection_ref, section, sort_order, "
          "created_at, updated_at) VALUES ('b:1', 'morning', 1, 0, 0)",
    ]);

    final Commitment migrated = (await migrateAndRead()).single;
    expect(migrated.collectionId, const BuiltinCollectionId(1));
    expect(migrated.section, DailySection.morning);
    // Every day is what a commitment meant when there was no other option.
    expect(migrated.days, Weekdays.everyDay);
    expect(versionOf(file), 5);
  });

  test('version 2 rewrites the section that was called daily', () async {
    windBackTo(2, <String>[
      'ALTER TABLE commitments DROP COLUMN days',
      "INSERT INTO commitments (collection_ref, section, sort_order, "
          "created_at, updated_at) VALUES ('b:1', 'daily', 1, 0, 0)",
    ]);

    // Left as 'daily' it would parse as no section and the commitment would
    // quietly stop appearing, which is why the rename is a data migration.
    expect((await migrateAndRead()).single.section, DailySection.today);
  });

  test('version 3 gains the unit cursor and keeps its progress', () async {
    windBackTo(3, <String>[
      'ALTER TABLE progress DROP COLUMN unit_index',
      "INSERT INTO progress (collection_ref, step_index, step_ref, "
          "current_count, updated_at) VALUES ('b:1', 4, 'surah:112', 2, "
          '${DateTime(2026, 3, 14, 9).millisecondsSinceEpoch})',
    ]);

    final UserDatabase db = UserDatabase.openFile(file);
    final WirdProgress? migrated = await DriftUserRepository(
      db,
      clock: () => DateTime(2026, 3, 14, 21),
    ).progress(const BuiltinCollectionId(1));
    await db.close();

    expect(migrated, isNotNull);
    expect(migrated!.currentCount, 2);
    // The start of the repetition, which is where a step whose unit is the
    // whole item always is — and where a surah left mid-reading resumes from
    // when it was written before the column existed.
    expect(migrated.unitIndex, 0);
    expect(versionOf(file), 5);
  });

  test('a database already at the current version is left alone', () async {
    final UserDatabase db = UserDatabase.openFile(file);
    await DriftUserRepository(db).commit(
      const BuiltinCollectionId(1),
      DailySection.evening,
      days: Weekdays.of(<int>[DateTime.monday]),
    );
    await db.close();

    final Commitment reopened = (await migrateAndRead()).single;
    expect(reopened.section, DailySection.evening);
    expect(reopened.days.weekdays, <int>[DateTime.monday]);
  });

  group('a run that failed part way through', () {
    // An upgrade does not run in a transaction, so a step that throws leaves
    // user_version where it was and everything before it applied. The next
    // launch runs the whole upgrade again over that half-migrated database,
    // and it has to succeed rather than fail the same way forever.

    test('version 1 that already created the table and its index', () async {
      // Exactly what the first broken release left behind: the table and the
      // index built by step one, and user_version still 1 because step two
      // threw on a duplicate column.
      windBackTo(1, <String>[]);

      expect(await migrateAndRead(), isEmpty);
      expect(versionOf(file), 5);
    });

    test('version 1 that created the table but not the index', () async {
      windBackTo(1, <String>['DROP INDEX idx_commitments_section']);

      expect(await migrateAndRead(), isEmpty);
      expect(versionOf(file), 5);
    });

    test('version 2 that already added the column', () async {
      windBackTo(2, <String>[
        "INSERT INTO commitments (collection_ref, section, days, sort_order, "
            "created_at, updated_at) VALUES ('b:1', 'daily', 127, 1, 0, 0)",
      ]);

      // The column is there; the rename had not happened yet.
      final Commitment migrated = (await migrateAndRead()).single;
      expect(migrated.section, DailySection.today);
      expect(migrated.days, Weekdays.everyDay);
      expect(versionOf(file), 5);
    });

    test('version 3 that already added the unit column', () async {
      // The column is there and user_version is still 3, which is what a step
      // that threw after adding it would leave behind.
      windBackTo(3, <String>[]);

      expect(await migrateAndRead(), isEmpty);
      expect(versionOf(file), 5);
    });

    test('the whole upgrade is safe to run twice', () async {
      windBackTo(1, <String>['DROP TABLE commitments']);
      expect(await migrateAndRead(), isEmpty);

      // Wound back again over the schema the first run produced.
      windBackTo(1, <String>[]);
      expect(await migrateAndRead(), isEmpty);
      expect(versionOf(file), 5);
    });
  });

  group('4 -> 5, the merged adhkar', () {
    /// A user collection holding one item that points at [dhikrId], with
    /// progress parked on that item.
    ///
    /// Clears what a previous call left behind, so a test can seed more than
    /// one id without colliding on the primary keys.
    void seedPointingAt(int dhikrId) {
      windBackTo(4, <String>[
        'DELETE FROM progress',
        'DELETE FROM user_collection_items',
        'DELETE FROM user_collections',
        'INSERT INTO user_collections (id, name, sort_order, created_at, '
            "updated_at) VALUES ('u1', 'Mine', 1, 0, 0)",
        'INSERT INTO user_collection_items (id, collection_id, item_type, '
            "item_id, position, updated_at) VALUES ('i1', 'u1', 'dhikr', "
            '$dhikrId, 1, 0)',
        'INSERT INTO progress (collection_ref, step_index, step_ref, '
            "current_count, unit_index, updated_at) VALUES ('u:u1', 0, "
            "'dhikr:$dhikrId', 2, 0, 0)",
      ]);
    }

    /// Opens the database, which is what runs the migration, then reads the
    /// column back off the file the way [versionOf] does.
    Future<Object?> migrated(String sql) async {
      final UserDatabase db = UserDatabase.openFile(file);
      await db.customSelect('SELECT 1').get();
      await db.close();

      final sqlite3.Database raw = sqlite3.sqlite3.open(file.path);
      final Object? value = raw.select(sql).single.values.first;
      raw.close();
      return value;
    }

    Future<Object?> migratedItemId() =>
        migrated('SELECT item_id FROM user_collection_items');

    Future<Object?> migratedStepRef() =>
        migrated('SELECT step_ref FROM progress');

    test('a saved item pointing at a retired dhikr follows it', () async {
      // 5003 was the second copy of 2011: the same bismi Llāhi lladhī lā
      // yaḍurru, authored once for al-Wird al-Latif and once for the wird of
      // Imam al-Nawawi. Left alone the item would resolve to nothing and
      // disappear from the user's collection.
      seedPointingAt(5003);

      expect(await migratedItemId(), 2011);
      expect(await migratedStepRef(), 'dhikr:2011');
      expect(versionOf(file), 5);
    });

    test('progress follows too, so a half-finished wird resumes', () async {
      // step_ref is compared against the step being resumed at. Left pointing
      // at the retired id it would no longer match, and the reciter would
      // silently lose their place.
      seedPointingAt(5011);

      expect(await migratedStepRef(), 'dhikr:3013');
    });

    test('every retired id has somewhere to go', () async {
      for (final int retired in <int>[3004, 5002, 5003, 5011, 5014, 5038]) {
        seedPointingAt(retired);
        expect(
          await migratedItemId(),
          isNot(retired),
          reason: 'dhikr $retired was left pointing at a row that is gone',
        );
      }
    });

    test('an item pointing at a surviving dhikr is left alone', () async {
      seedPointingAt(2011);

      expect(await migratedItemId(), 2011);
      expect(await migratedStepRef(), 'dhikr:2011');
    });

    test('the merge is safe to run twice', () async {
      seedPointingAt(5003);
      expect(await migratedItemId(), 2011);

      // A retired id never appears as a replacement, so a second pass over an
      // already-merged database matches nothing rather than chaining on.
      windBackTo(4, <String>[]);
      expect(await migratedItemId(), 2011);
      expect(versionOf(file), 5);
    });
  });
}
