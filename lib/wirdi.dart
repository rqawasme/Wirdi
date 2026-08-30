/// Wirdi's data layer.
///
/// Two separate SQLite databases, never joined in SQL:
///
///   * `content.db` — read-only, bundled as an asset, replaced wholesale on
///     app update. Quran, adhkar, sources and built-in collections.
///   * `user.db` — read-write, in the documents directory so platform backup
///     picks it up, migrated and never replaced. The user's own collections,
///     progress, completions and settings.
///
/// User rows reference content by id; resolution happens in Dart. See
/// [CollectionRepository] for the seam where the two meet.
library;

export 'data/content_database.dart'
    show ContentDatabase, ContentSchemaVersionMismatch, expectedContentSchemaVersion;
export 'data/database_files.dart';
export 'data/user_database.dart' show UserDatabase;
export 'data/wirdi_data.dart';
export 'domain/domain.dart';
