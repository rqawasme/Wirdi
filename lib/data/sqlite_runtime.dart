import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The SQLite build the app is actually running against.
///
/// `package:sqlite3` 3.x supplies its own SQLite on every platform: the build
/// hook downloads a precompiled library for the target and packages it as a
/// code asset, which is the job `sqlite3_flutter_libs` used to do before it
/// was retired. The platform's own SQLite is used only if the build opts in
/// explicitly with `source: system` in `hook_user_defines`, which this app
/// does not do.
sqlite3.Version get sqliteVersion => sqlite3.sqlite3.version;

/// The oldest SQLite this app will run against, as sqlite's own version
/// number format: `major * 1000000 + minor * 1000 + patch`.
///
/// This floor is not about needing a specific feature. It is a tripwire for
/// the bundling above silently failing and the app falling through to the
/// platform's SQLite — which matters on Android, where the system library
/// trails by years and varies by device. It sits well above any system SQLite
/// likely to be encountered there and well below the version the package
/// currently bundles, so it has room to stay put across upgrades.
const int minimumSqliteVersionNumber = 3049000; // 3.49.0

/// Thrown at startup when the SQLite in use is older than this app supports.
class UnsupportedSqliteVersion implements Exception {
  const UnsupportedSqliteVersion(this.actual);

  final sqlite3.Version actual;

  @override
  String toString() =>
      'SQLite ${actual.libVersion} (${actual.versionNumber}) is older than the '
      'minimum this app supports ($minimumSqliteVersionNumber). '
      'package:sqlite3 should be bundling its own build; a version this old '
      'suggests the platform library is being used instead.';
}

/// Fails loudly when the SQLite in use is not the bundled one.
///
/// Called from `WirdiData.open` so the failure lands at startup with a clear
/// message, rather than as an obscure syntax error from a statement the old
/// library does not understand.
void assertSupportedSqlite() {
  final sqlite3.Version version = sqliteVersion;
  if (version.versionNumber < minimumSqliteVersionNumber) {
    throw UnsupportedSqliteVersion(version);
  }
}
