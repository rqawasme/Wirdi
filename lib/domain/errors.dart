import 'collection_id.dart';
import 'item_ref.dart';

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

/// The dhikr the user wrote does not exist, or was soft-deleted.
///
/// Its own exception rather than [ContentNotFoundException], which is about
/// `content.db` and means the caller asked for a row the content build never
/// wrote. This one means a row somebody else on this device deleted while a
/// screen still had it on it, which is an ordinary race and not a bug.
class DhikrNotFoundException implements Exception {
  const DhikrNotFoundException(this.ref);

  final UserDhikrRef ref;

  @override
  String toString() => 'no such dhikr of your own: ${ref.canonical}';
}

/// The requested collection does not exist, or was soft-deleted.
class CollectionNotFoundException implements Exception {
  const CollectionNotFoundException(this.id);

  final CollectionId id;

  @override
  String toString() => 'no such collection: ${id.canonical}';
}
