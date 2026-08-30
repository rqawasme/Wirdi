import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/sqlite_runtime.dart';

/// `sqlite3_flutter_libs` existed to bundle a modern SQLite on Android, where
/// the system one is old and varies by device. `package:sqlite3` 3.x took over
/// that job, and this is the check that it is actually doing it.
void main() {
  test('runs against a bundled SQLite, not an old platform one', () {
    // ignore: avoid_print
    print('SQLite ${sqliteVersion.libVersion} (${sqliteVersion.sourceId})');

    expect(
      sqliteVersion.versionNumber,
      greaterThanOrEqualTo(minimumSqliteVersionNumber),
      reason:
          'a version below the floor means the build fell through to the '
          'platform SQLite instead of the bundled one',
    );
    assertSupportedSqlite();
  });

  test('the floor is a version number, in sqlite\'s own format', () {
    // major * 1000000 + minor * 1000 + patch
    expect(minimumSqliteVersionNumber ~/ 1000000, 3);
    expect(sqliteVersion.versionNumber ~/ 1000000, 3);
  });
}
