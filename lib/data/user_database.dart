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
  int get schemaVersion => 2;

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
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(commitments);
        await m.createIndex(idxCommitmentsSection);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
