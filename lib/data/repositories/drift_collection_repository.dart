import 'package:uuid/uuid.dart';

import '../../domain/collection.dart';
import '../../domain/collection_id.dart';
import '../../domain/content_ref.dart';
import '../../domain/errors.dart';
import '../../domain/repositories.dart';
import '../collection_resolver.dart';
import '../content_database.dart';
import '../item_type_codec.dart';
import '../mappers.dart';
import '../user_database.dart';

/// [CollectionRepository] over both databases.
///
/// This is the only class that holds both. Built-in collections and their
/// items come from `content.db`; user collections and their items from
/// `user.db`; and both resolve their content through the same
/// [CollectionResolver] against `content.db`. There is no ATTACH and no
/// cross-database SQL — the join happens in Dart, here.
class DriftCollectionRepository implements CollectionRepository {
  DriftCollectionRepository({
    required ContentDatabase content,
    required UserDatabase user,
    Uuid? uuid,
    DateTime Function()? clock,
  }) : _content = content,
       _user = user,
       _uuid = uuid ?? const Uuid(),
       _now = clock ?? DateTime.now,
       _resolver = CollectionResolver(content);

  final ContentDatabase _content;
  final UserDatabase _user;
  final Uuid _uuid;
  final DateTime Function() _now;
  final CollectionResolver _resolver;

  @override
  Future<List<CollectionSummary>> all() async {
    final List<CollectionRow> builtins = await _content.allCollections().get();
    // activeUserCollections filters deleted_at IS NULL: soft-deleted
    // collections never appear in a list.
    final List<UserCollectionRow> mine = await _user
        .activeUserCollections()
        .get();

    // Built-ins first, in the order the content pipeline assigns, then the
    // user's own. The two sort_order spaces are unrelated, so interleaving
    // them would order by an accident of numbering.
    return <CollectionSummary>[
      ...builtins.map(builtinSummaryFromRow),
      ...mine.map(userSummaryFromRow),
    ];
  }

  @override
  Future<ResolvedCollection> resolve(CollectionId id) async {
    switch (id) {
      case BuiltinCollectionId():
        return _resolveBuiltin(id);
      case UserCollectionId():
        return _resolveUser(id);
    }
  }

  Future<ResolvedCollection> _resolveBuiltin(BuiltinCollectionId id) async {
    final CollectionRow? row = await _content
        .collectionById(id: id.value)
        .getSingleOrNull();
    if (row == null) throw CollectionNotFoundException(id);

    final List<CollectionItemRow> items = await _content
        .itemsForCollection(collection: id.value)
        .get();
    return _resolver.resolve(
      builtinSummaryFromRow(row),
      items.map(_builtinItem).toList(growable: false),
    );
  }

  Future<ResolvedCollection> _resolveUser(UserCollectionId id) async {
    final UserCollectionRow? row = await _user
        .activeUserCollection(id: id.uuid)
        .getSingleOrNull();
    if (row == null) throw CollectionNotFoundException(id);

    final List<UserCollectionItemRow> items = await _user
        .itemsForUserCollection(collection: id.uuid)
        .get();
    return _resolver.resolve(
      userSummaryFromRow(row),
      items.map(_userItem).toList(growable: false),
    );
  }

  @override
  Future<UserCollectionId> create(String name, {String? description}) async {
    final String id = _uuid.v4();
    final int now = toEpochMs(_now());
    final int sortOrder = await _user.nextUserCollectionSortOrder().getSingle();
    await _user.insertUserCollection(
      id: id,
      name: name,
      description: description,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
    return UserCollectionId(id);
  }

  @override
  Future<void> rename(UserCollectionId id, String name) async {
    final int changed = await _user.renameUserCollection(
      name: name,
      updatedAt: toEpochMs(_now()),
      id: id.uuid,
    );
    if (changed == 0) throw CollectionNotFoundException(id);
  }

  @override
  Future<void> addItem(
    UserCollectionId id,
    ContentRef ref, {
    int? count,
  }) async {
    await _requireLiveCollection(id);
    await _user.transaction(() async {
      final int position = await _user
          .nextItemPosition(collection: id.uuid)
          .getSingle();
      await _user.insertUserCollectionItem(
        id: _uuid.v4(),
        collection: id.uuid,
        itemType: ref.type.sqlName,
        itemId: ref.id,
        position: position,
        countOverride: count,
        repeatGroup: null,
        repeatGroupCount: null,
        updatedAt: toEpochMs(_now()),
      );
    });
  }

  @override
  Future<void> removeItem(UserCollectionId id, String itemId) async {
    await _user.deleteUserCollectionItem(id: itemId, collection: id.uuid);
  }

  @override
  Future<void> reorder(UserCollectionId id, List<String> itemIdsInOrder) async {
    final int now = toEpochMs(_now());
    await _user.transaction(() async {
      for (int i = 0; i < itemIdsInOrder.length; i++) {
        await _user.setItemPosition(
          position: i + 1,
          updatedAt: now,
          id: itemIdsInOrder[i],
          collection: id.uuid,
        );
      }
    });
  }

  @override
  Future<void> delete(UserCollectionId id) async {
    // Soft: the row and its items stay, `all()` stops showing it.
    final int changed = await _user.softDeleteUserCollection(
      deletedAt: toEpochMs(_now()),
      id: id.uuid,
    );
    if (changed == 0) throw CollectionNotFoundException(id);
  }

  Future<void> _requireLiveCollection(UserCollectionId id) async {
    final UserCollectionRow? row = await _user
        .activeUserCollection(id: id.uuid)
        .getSingleOrNull();
    if (row == null) throw CollectionNotFoundException(id);
  }

  static ResolvableItem _builtinItem(CollectionItemRow row) => ResolvableItem(
    entryId: row.id.toString(),
    itemType: contentTypeFromSql(row.itemType),
    itemId: row.itemId,
    position: row.position,
    countOverride: row.countOverride,
    repeatGroup: row.repeatGroup,
    repeatGroupCount: row.repeatGroupCount,
    note: row.note,
  );

  static ResolvableItem _userItem(UserCollectionItemRow row) => ResolvableItem(
    entryId: row.id,
    itemType: contentTypeFromSql(row.itemType),
    itemId: row.itemId,
    position: row.position,
    countOverride: row.countOverride,
    repeatGroup: row.repeatGroup,
    repeatGroupCount: row.repeatGroupCount,
    // user_collection_items has no note column; notes are a built-in rubric.
  );
}
