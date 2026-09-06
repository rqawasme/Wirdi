import 'dart:io';

import 'content_database.dart';
import 'database_files.dart';
import 'repositories/drift_collection_repository.dart';
import 'repositories/drift_content_repository.dart';
import 'repositories/drift_user_repository.dart';
import 'sqlite_runtime.dart';
import 'user_database.dart';
import '../domain/repositories.dart';

/// The two databases and the three repositories over them, opened together.
///
/// Built by [open] at startup, or by [WirdiData.new] from databases a test has
/// already opened.
class WirdiData {
  /// [clock] is what the repositories mean by "now": which local day a
  /// completion lands on, and which day's progress is today's. It is threaded
  /// in rather than defaulted per repository so that everything below this
  /// point agrees about when it is — a test that moves the clock moves all of
  /// it, and cannot end up with a completion logged on one day being read back
  /// against another.
  WirdiData({
    required this.content,
    required this.user,
    DateTime Function()? clock,
  }) : contentRepository = DriftContentRepository(content),
       collectionRepository = DriftCollectionRepository(
         content: content,
         user: user,
         clock: clock,
       ),
       userRepository = DriftUserRepository(user, clock: clock);

  /// Copies the bundled content asset if needed, opens both databases and
  /// checks that `content.db` was built by the schema version this code
  /// expects.
  static Future<WirdiData> open({
    WirdiDatabaseFiles files = const WirdiDatabaseFiles(),
  }) async {
    // Before anything opens: confirm we are on the SQLite package:sqlite3
    // bundles, not an old platform one.
    assertSupportedSqlite();

    final File contentFile = await files.ensureContentDatabase();
    final ContentDatabase content = ContentDatabase.openReadOnly(contentFile);
    // Fail here, at startup, rather than on the first query that returns a
    // column this build does not know about.
    await content.assertSchemaVersion();

    final UserDatabase user = UserDatabase.openFile(await files.userDatabase());
    return WirdiData(content: content, user: user);
  }

  final ContentDatabase content;
  final UserDatabase user;

  final ContentRepository contentRepository;
  final CollectionRepository collectionRepository;
  final UserRepository userRepository;

  Future<void> close() async {
    await content.close();
    await user.close();
  }
}
