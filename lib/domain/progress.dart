import 'collection_id.dart';

/// Where the user is in a collection.
///
/// One row per collection, overwritten as they go. [itemIndex] indexes
/// `ResolvedCollection.entries`.
final class WirdProgress {
  WirdProgress({
    required this.collectionId,
    required this.itemIndex,
    required this.currentCount,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final CollectionId collectionId;

  /// Index into the resolved entry list.
  final int itemIndex;

  /// Repetitions completed of the entry at [itemIndex].
  final int currentCount;

  final DateTime updatedAt;

  WirdProgress copyWith({int? itemIndex, int? currentCount, DateTime? updatedAt}) {
    return WirdProgress(
      collectionId: collectionId,
      itemIndex: itemIndex ?? this.itemIndex,
      currentCount: currentCount ?? this.currentCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'WirdProgress(${collectionId.canonical} item $itemIndex, count $currentCount)';
}

/// Where the user last was in the mushaf. A single row by construction.
final class ReadingPosition {
  ReadingPosition({
    required this.surahNumber,
    required this.ayahNumber,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final int surahNumber;
  final int ayahNumber;
  final DateTime updatedAt;

  @override
  String toString() => 'ReadingPosition($surahNumber:$ayahNumber)';
}
