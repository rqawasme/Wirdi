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
    expect(versionOf(file), 3);

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
    expect(versionOf(file), 3);
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
}
