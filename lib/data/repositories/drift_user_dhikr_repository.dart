import 'package:uuid/uuid.dart';

import '../../domain/collection.dart';
import '../../domain/content.dart';
import '../../domain/errors.dart';
import '../../domain/item_ref.dart';
import '../../domain/repositories.dart';
import '../mappers.dart';
import '../user_database.dart';

/// [UserDhikrRepository] over `user.db`.
///
/// Holds one database, unlike `DriftCollectionRepository`: a dhikr the user
/// wrote has nothing to do with `content.db`. It does write
/// `user_collection_items`, which is a table that repository otherwise owns —
/// see [delete], where taking a deleted dhikr out of the collections that held
/// it has to happen in the same transaction as the deletion, and both tables
/// are in this one database.
class DriftUserDhikrRepository implements UserDhikrRepository {
  DriftUserDhikrRepository(
    UserDatabase user, {
    Uuid? uuid,
    DateTime Function()? clock,
  }) : _user = user,
       _uuid = uuid ?? const Uuid(),
       _now = clock ?? DateTime.now;

  final UserDatabase _user;
  final Uuid _uuid;
  final DateTime Function() _now;

  @override
  Future<List<Dhikr>> all() async {
    final List<UserDhikrRow> rows = await _user.activeUserAdhkar().get();
    return rows.map(userDhikrFromRow).toList(growable: false);
  }

  @override
  Future<UserDhikrRef> create(DhikrDraft draft) async {
    final String id = _uuid.v4();
    final int now = toEpochMs(_now());
    await _user.insertUserDhikr(
      id: id,
      textArabic: draft.textArabic,
      translation: draft.translation,
      transliteration: draft.transliteration,
      defaultCount: draft.defaultCount,
      reference: draft.reference,
      notes: draft.notes,
      createdAt: now,
      updatedAt: now,
    );
    return UserDhikrRef(id);
  }

  @override
  Future<void> update(UserDhikrRef ref, DhikrDraft draft) async {
    final int changed = await _user.updateUserDhikr(
      textArabic: draft.textArabic,
      translation: draft.translation,
      transliteration: draft.transliteration,
      defaultCount: draft.defaultCount,
      reference: draft.reference,
      notes: draft.notes,
      updatedAt: toEpochMs(_now()),
      id: ref.uuid,
    );
    if (changed == 0) throw DhikrNotFoundException(ref);
  }

  @override
  Future<Map<UserDhikrRef, int>> usage() async {
    final List<UserDhikrUsageCountsResult> rows = await _user
        .userDhikrUsageCounts()
        .get();
    return <UserDhikrRef, int>{
      for (final UserDhikrUsageCountsResult row in rows)
        // `dhikr` is nullable in the generated result because the column is,
        // though the query filters the nulls out.
        if (row.dhikr case final String uuid) UserDhikrRef(uuid): row.uses,
    };
  }

  @override
  Future<List<CollectionSummary>> usedBy(UserDhikrRef ref) async {
    final List<UserCollectionRow> rows = await _user
        .collectionsUsingUserDhikr(dhikr: ref.uuid)
        .get();
    return rows.map(userSummaryFromRow).toList(growable: false);
  }

  @override
  Future<void> delete(UserDhikrRef ref) async {
    final int now = toEpochMs(_now());
    await _user.transaction(() async {
      // Which collections held it, read before the items go: afterwards there
      // is nothing left to join against.
      final List<UserCollectionRow> affected = await _user
          .collectionsUsingUserDhikr(dhikr: ref.uuid)
          .get();

      final int changed = await _user.softDeleteUserDhikr(
        deletedAt: now,
        id: ref.uuid,
      );
      if (changed == 0) throw DhikrNotFoundException(ref);

      await _user.deleteItemsForUserDhikr(dhikr: ref.uuid);

      // Closing the gaps is not tidiness: `setRepeatGroup` refuses a run that
      // is not contiguous *by position*, so a collection left carrying one has
      // items that look adjacent in the list and cannot be grouped. The same
      // reason `CollectionEditor.removeItem` renumbers after removing one item
      // by hand — done here rather than there because this deletion spans
      // collections and has to be one transaction.
      for (final UserCollectionRow collection in affected) {
        await _renumber(collection.id, now);
      }
    });
  }

  /// Rewrites `position` as 1..n over what is left of one collection.
  Future<void> _renumber(String collectionId, int now) async {
    final List<UserCollectionItemRow> remaining = await _user
        .itemsForUserCollection(collection: collectionId)
        .get();
    for (int i = 0; i < remaining.length; i++) {
      if (remaining[i].position == i + 1) continue;
      await _user.setItemPosition(
        position: i + 1,
        updatedAt: now,
        id: remaining[i].id,
        collection: collectionId,
      );
    }
  }
}
