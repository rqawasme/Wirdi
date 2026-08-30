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
    String? note,
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
        // Repeat groups are set afterwards, over a run of items, by
        // setRepeatGroup: a single item cannot form one on its own.
        repeatGroup: null,
        repeatGroupCount: null,
        note: note,
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
      final List<UserCollectionItemRow> current = await _user
          .itemsForUserCollection(collection: id.uuid)
          .get();
      final Set<String> existing = <String>{
        for (final UserCollectionItemRow row in current) row.id,
      };

      // A partial or padded list would leave items sharing a position, and
      // position is the only ordering there is. Reject it rather than write an
      // order nobody asked for.
      if (itemIdsInOrder.length != existing.length ||
          itemIdsInOrder.toSet().length != itemIdsInOrder.length ||
          !existing.containsAll(itemIdsInOrder)) {
        throw ArgumentError.value(
          itemIdsInOrder,
          'itemIdsInOrder',
          'must list every item of ${id.canonical} exactly once '
              '(${existing.length} items)',
        );
      }

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
  Future<void> setRepeatGroup(
    UserCollectionId id,
    List<String> itemIds,
    int repetitions,
  ) async {
    if (repetitions < 1) {
      throw ArgumentError.value(
        repetitions,
        'repetitions',
        'a repeat group is recited at least once',
      );
    }
    if (itemIds.isEmpty) {
      throw ArgumentError.value(
        itemIds,
        'itemIds',
        'must name at least one item',
      );
    }
    if (itemIds.toSet().length != itemIds.length) {
      throw ArgumentError.value(itemIds, 'itemIds', 'lists an item twice');
    }

    final int now = toEpochMs(_now());
    await _user.transaction(() async {
      final List<UserCollectionItemRow> all = await _user
          .itemsForUserCollection(collection: id.uuid)
          .get();
      final Map<String, UserCollectionItemRow> byId =
          <String, UserCollectionItemRow>{
            for (final UserCollectionItemRow row in all) row.id: row,
          };

      final List<UserCollectionItemRow> members = <UserCollectionItemRow>[];
      for (final String itemId in itemIds) {
        final UserCollectionItemRow? row = byId[itemId];
        if (row == null) {
          throw ArgumentError.value(
            itemId,
            'itemIds',
            'is not an item of ${id.canonical}',
          );
        }
        if (row.repeatGroup != null) {
          throw ArgumentError.value(
            itemId,
            'itemIds',
            'is already in repeat group ${row.repeatGroup}; '
                'clear that group first',
          );
        }
        members.add(row);
      }

      // A repeat group that is not a contiguous run has no coherent playback
      // order: the items in between would have to be recited on some passes
      // and not others.
      final List<int> positions =
          members.map((UserCollectionItemRow r) => r.position).toList()..sort();
      for (int i = 1; i < positions.length; i++) {
        if (positions[i] != positions[i - 1] + 1) {
          throw ArgumentError.value(
            itemIds,
            'itemIds',
            'must be contiguous by position, but positions are $positions',
          );
        }
      }

      final int group = await _user
          .nextRepeatGroup(collection: id.uuid)
          .getSingle();
      for (final UserCollectionItemRow row in members) {
        await _user.setItemRepeatGroup(
          group: group,
          count: repetitions,
          updatedAt: now,
          id: row.id,
          collection: id.uuid,
        );
      }
    });
  }

  @override
  Future<void> clearRepeatGroup(UserCollectionId id, int repeatGroup) async {
    await _user.clearItemsRepeatGroup(
      updatedAt: toEpochMs(_now()),
      collection: id.uuid,
      group: repeatGroup,
    );
  }

  @override
  Future<void> delete(UserCollectionId id) async {
    await _user.transaction(() async {
      // Soft: the row and its items stay, `all()` stops showing it.
      final int changed = await _user.softDeleteUserCollection(
        deletedAt: toEpochMs(_now()),
        id: id.uuid,
      );
      if (changed == 0) throw CollectionNotFoundException(id);

      // In-flight state for a deleted collection is meaningless.
      await _user.deleteProgress(ref: id.canonical);

      // Completions are deliberately left alone. They are historical record,
      // streaks run across all of them regardless of collection, and deleting
      // them would retroactively break a streak the user earned.
    });
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
    note: row.note,
  );
}
