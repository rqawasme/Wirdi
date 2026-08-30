import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

part 'content_database.g.dart';

/// The `meta.schema_version` this code was written against.
///
/// `content/scripts/build_content.py` stamps this into every database it
/// builds. If a build ever changes the content schema it bumps that constant,
/// and an app shipping an older data layer must fail loudly rather than
/// quietly returning wrong columns.
const String expectedContentSchemaVersion = '1';

/// Thrown when the bundled `content.db` was built by a different schema
/// version than this code expects.
class ContentSchemaVersionMismatch implements Exception {
  ContentSchemaVersionMismatch({required this.expected, required this.actual});

  final String expected;
  final String? actual;

  @override
  String toString() =>
      'content.db schema_version is ${actual ?? '<missing>'}, '
      'but this build of the app expects $expected. '
      'Rebuild the bundled asset with content/scripts/build_content.py.';
}

/// Read-only access to the bundled content database.
///
/// Every statement in `schema/content.drift` is a `SELECT`. The file version of
/// this database is opened read-only at the sqlite3 level and with drift's
/// migrations disabled, so drift never writes `user_version` either — the copy
/// in app support stays byte-identical to the shipped asset.
@DriftDatabase(include: {'schema/content.drift'})
class ContentDatabase extends _$ContentDatabase {
  ContentDatabase(super.e);

  /// Opens an existing `content.db` file read-only.
  ///
  /// The file must already exist and already carry its schema; see
  /// [ContentDatabase] on why no migration runs.
  factory ContentDatabase.openReadOnly(File file) {
    return ContentDatabase(
      NativeDatabase.opened(
        sqlite3.sqlite3.open(file.path, mode: sqlite3.OpenMode.readOnly),
        enableMigrations: false,
      ),
    );
  }

  /// An empty in-memory content database with the schema created. For tests.
  factory ContentDatabase.memory() =>
      ContentDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      // Only reached for in-memory databases in tests: a real content.db
      // arrives with its schema already built by the Python pipeline.
      await m.createAll();
    },
    beforeOpen: (OpeningDetails details) async {
      if (details.wasCreated) return;
      await assertSchemaVersion();
    },
  );

  /// Fails loudly when the database was built by a different pipeline version.
  Future<void> assertSchemaVersion() async {
    final String? version = await metaValue(key: 'schema_version')
        .getSingleOrNull();
    if (version != expectedContentSchemaVersion) {
      throw ContentSchemaVersionMismatch(
        expected: expectedContentSchemaVersion,
        actual: version,
      );
    }
  }
}
