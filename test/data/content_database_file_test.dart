import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:wirdi/data/content_database.dart';
import 'package:wirdi/data/repositories/drift_content_repository.dart';
import 'package:wirdi/domain/domain.dart';

import '../support/fixtures.dart';

/// The bundled `content.db` arrives already built, by a Python script that
/// knows nothing about drift's `user_version` pragma. These tests pin the
/// consequence: opening it must not migrate it, must not write to it, and must
/// still run the schema-version check.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wirdi_content_');
    file = File(p.join(dir.path, 'content.db'));

    // Build a stand-in for the pipeline's output: the schema, some rows, and
    // user_version left at 0 the way a database sqlite3 created by hand has
    // it.
    final ContentDatabase seed = ContentDatabase(NativeDatabase(file));
    await seedContent(seed);
    await seed.close();

    final sqlite3.Database raw = sqlite3.sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 0');
    raw.close();
  });

  tearDown(() => dir.delete(recursive: true));

  int userVersion() {
    final sqlite3.Database raw = sqlite3.sqlite3.open(
      file.path,
      mode: sqlite3.OpenMode.readOnly,
    );
    final int version =
        raw.select('PRAGMA user_version').first.values.first! as int;
    raw.close();
    return version;
  }

  test('opens a pipeline-built file and reads it', () async {
    final ContentDatabase db = ContentDatabase.openReadOnly(file);
    addTearDown(db.close);

    final ContentRepository content = DriftContentRepository(db);
    expect(await content.surahs(), hasLength(5));
    expect((await content.dhikr(1002)).defaultCount, 33);
  });

  test(
    'leaves the file untouched — no migration, no user_version write',
    () async {
      final int before = userVersion();
      final int lengthBefore = await file.length();

      final ContentDatabase db = ContentDatabase.openReadOnly(file);
      await db.allSurahs().get();
      await db.close();

      expect(before, 0);
      expect(userVersion(), 0, reason: 'drift must not stamp user_version');
      expect(await file.length(), lengthBefore);
    },
  );

  test('is read-only at the sqlite level', () async {
    final ContentDatabase db = ContentDatabase.openReadOnly(file);
    addTearDown(db.close);

    expect(
      () => db.customStatement('DELETE FROM surahs'),
      throwsA(isA<sqlite3.SqliteException>()),
    );
  });

  test('the schema version check runs against the file', () async {
    final ContentDatabase ok = ContentDatabase.openReadOnly(file);
    await ok.assertSchemaVersion();
    await ok.close();

    final sqlite3.Database raw = sqlite3.sqlite3.open(file.path);
    raw.execute("UPDATE meta SET value = '99' WHERE key = 'schema_version'");
    raw.close();

    final ContentDatabase stale = ContentDatabase.openReadOnly(file);
    addTearDown(stale.close);
    // beforeOpen runs the check, so even the first query fails.
    expect(
      () => stale.allSurahs().get(),
      throwsA(isA<ContentSchemaVersionMismatch>()),
    );
  });
}
