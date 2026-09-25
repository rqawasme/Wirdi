import '../domain/item_ref.dart';

/// Translates between [ItemRef] and the columns that store one:
/// `item_type`, `item_id` and `user_item_id`, in `collection_items` and
/// `user_collection_items`.
///
/// This is the only place those strings and that column convention exist. They
/// do not escape the data layer.

/// The `item_type` of a dhikr the user wrote.
///
/// `collection_items` in `content.db` never holds this — a built-in collection
/// cannot name a row of somebody's `user.db` — but the constant lives here
/// beside the other three rather than in the one query that writes it.
const String userDhikrSqlName = 'user_dhikr';

extension ItemTypeSql on ContentType {
  String get sqlName => switch (this) {
    ContentType.dhikr => 'dhikr',
    ContentType.ayah => 'ayah',
    ContentType.surah => 'surah',
  };
}

/// Returns null for a value neither database should contain, which lets
/// resolution drop the row instead of throwing on one bad item.
ContentType? contentTypeFromSql(String value) => switch (value) {
  'dhikr' => ContentType.dhikr,
  'ayah' => ContentType.ayah,
  'surah' => ContentType.surah,
  _ => null,
};

/// The three columns an item row stores [ref] in.
///
/// `item_id` is 0 for a user dhikr: the column is NOT NULL and no content row
/// is being named, and 0 is not a valid id in any of the three content spaces.
/// See the note on `user_item_id` in `user.drift`.
({String itemType, int itemId, String? userItemId}) itemColumnsFor(
  ItemRef ref,
) => switch (ref) {
  ContentRef(:final ContentType type, :final int id) => (
    itemType: type.sqlName,
    itemId: id,
    userItemId: null,
  ),
  UserDhikrRef(:final String uuid) => (
    itemType: userDhikrSqlName,
    itemId: 0,
    userItemId: uuid,
  ),
};

/// The [ItemRef] those three columns name, or null for a row neither database
/// should hold.
///
/// Null rather than a throw, for the same reason [contentTypeFromSql] returns
/// one: a single unreadable row drops out of its collection, and the rest of
/// it still opens. A `'user_dhikr'` row whose `user_item_id` is missing or
/// malformed is exactly such a row.
ItemRef? itemRefFromSql(String itemType, int itemId, String? userItemId) {
  if (itemType == userDhikrSqlName) {
    if (userItemId == null || !UserDhikrRef.isWellFormed(userItemId)) {
      return null;
    }
    return UserDhikrRef(userItemId);
  }
  final ContentType? type = contentTypeFromSql(itemType);
  return type == null ? null : ContentRef(type, itemId);
}
