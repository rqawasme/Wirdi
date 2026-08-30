import '../domain/content_ref.dart';

/// Translates between [ContentType] and the `item_type` strings stored in
/// `collection_items.item_type` and `user_collection_items.item_type`.
///
/// This is the only place those strings exist. They do not escape the data
/// layer.
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
