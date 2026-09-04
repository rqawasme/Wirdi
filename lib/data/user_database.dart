import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'user_database.g.dart';

/// Read-write storage for everything the user makes: their collections,
/// progress, completions, reading position and settings.
///
/// This database is migrated, never replaced. It lives in the documents
/// directory so platform backup picks it up — see `WirdiDatabaseFiles`.
@DriftDatabase(include: {'schema/user.drift'})
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.e);

  factory UserDatabase.openFile(File file) =>
      UserDatabase(NativeDatabase(file));

  /// An empty in-memory user database. For tests.
  factory UserDatabase.memory() => UserDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    // 1 -> 2 adds `commitments`, the home screen's list of what the user has
    // committed to doing today. Nothing existing is touched: a database from
    // version 1 comes forward with every collection uncommitted, which is the
    // correct starting state — committing is a decision the user makes, and
    // guessing it from what they happen to own would fill their home screen
    // with things they never chose.
    // 2 -> 3 gives a commitment the days of the week it falls on, and renames
    // the untimed section from 'daily' to 'today'. Existing rows come forward
    // as every day, which is what they meant when there was no other option.
    //
    // The rename is a data migration and not only a label change, because the
    // section is stored as the string it reads as. A row left saying 'daily'
    // would parse as no section at all and its commitment would quietly stop
    // appearing, so it is rewritten here rather than tolerated as an alias
    // forever.
    // Two rules hold every step here, and both were learned the hard way.
    //
    // A step is written for the version it upgrades *from*, not as `from < n`.
    // A step that creates a table creates it from the current schema — `days`
    // and all — so a later step must not add a column that is already there.
    // `from == 2` is the only database with a `commitments` table and no
    // `days`.
    //
    // And every step is idempotent, because this does not run in a
    // transaction: a step that throws leaves `user_version` where it was and
    // everything before it applied, so the next launch runs the whole upgrade
    // again over a half-migrated database. `IF NOT EXISTS` on the indexes and
    // the column check below are what make that second run succeed instead of
    // failing the same way forever.
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(commitments);
        await m.createIndex(idxCommitmentsSection);
      }
      if (from == 2 && !await _hasColumn('commitments', 'days')) {
        await m.addColumn(commitments, commitments.days);
      }
      if (from < 3) {
        // Idempotent on its own: a second run matches nothing.
        await customStatement(
          "UPDATE commitments SET section = 'today' WHERE section = 'daily'",
        );
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Whether [table] already has [column].
  ///
  /// `ALTER TABLE ... ADD COLUMN` is the one migration step with no
  /// `IF NOT EXISTS` form, so asking first is the only way to make it safe to
  /// run twice.
  Future<bool> _hasColumn(String table, String column) async {
    final List<QueryRow> columns = await customSelect(
      'PRAGMA table_info($table)',
    ).get();
    return columns.any((QueryRow row) => row.read<String>('name') == column);
  }
}
