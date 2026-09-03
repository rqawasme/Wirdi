import 'collection_id.dart';

/// Which part of the day a collection is committed to.
///
/// Three, and the order they are declared in is the order the home screen
/// renders them: daily first because it is not tied to a time, then the two
/// that are, in the order they come round. The sections are not time-aware —
/// Morning does not move to the top at dawn — because a fixed order is a
/// screen you can learn the shape of, and one that rearranges itself is a
/// screen you have to re-read every time you open it.
enum DailySection {
  daily('Daily'),
  morning('Morning'),
  evening('Evening');

  const DailySection(this.label);

  /// The section header, and the wording of the choice offered when
  /// committing. Sentence case like every other label in the app.
  final String label;
}

/// A collection the user has committed to doing, and when.
///
/// A collection with no commitment is not on the home screen. It is still in
/// the collections list and still openable — committing is about what the day
/// is meant to contain, not about what exists.
final class Commitment {
  Commitment({
    required this.collectionId,
    required this.section,
    required this.sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final CollectionId collectionId;

  final DailySection section;

  /// Position among the commitments, as committed. Tiles sit in the order the
  /// user committed them and nothing reorders itself as the day goes on — a
  /// finished tile stays exactly where it was.
  final int sortOrder;

  final DateTime createdAt;

  final DateTime updatedAt;

  @override
  String toString() =>
      'Commitment(${collectionId.canonical} ${section.name} @$sortOrder)';
}
