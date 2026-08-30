import 'collection_id.dart';
import 'content_ref.dart';

/// A row that must exist in `content.db` was not there.
///
/// The content build verifies every reference it writes, so this means the
/// caller asked for something that does not exist — an out-of-range surah, an
/// unknown dhikr id.
class ContentNotFoundException implements Exception {
  const ContentNotFoundException(this.ref);

  final ContentRef ref;

  @override
  String toString() => 'no such ${ref.type.name} in content.db: ${ref.id}';
}

/// The requested collection does not exist, or was soft-deleted.
class CollectionNotFoundException implements Exception {
  const CollectionNotFoundException(this.id);

  final CollectionId id;

  @override
  String toString() => 'no such collection: ${id.canonical}';
}
