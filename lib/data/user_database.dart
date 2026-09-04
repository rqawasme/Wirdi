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
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(commitments);
        await m.createIndex(idxCommitmentsSection);
      }
      if (from < 3) {
        await m.addColumn(commitments, commitments.days);
        await customStatement(
          "UPDATE commitments SET section = 'today' WHERE section = 'daily'",
        );
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
