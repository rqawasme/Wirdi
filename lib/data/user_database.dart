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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
