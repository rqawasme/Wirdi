import 'content_ref.dart';

/// One unit of playback: an item to recite, once.
///
/// Where [CollectionEntry] is the structure of a collection — the shape you
/// display and edit, with [RepeatBlock]s intact — this is the flattening of it
/// for the counter. A three-item block repeated seven times is one
/// [RepeatBlock] and twenty-one [PlaybackStep]s.
final class PlaybackStep {
  const PlaybackStep({
    required this.index,
    required this.ref,
    required this.count,
    required this.entryId,
    required this.repetition,
    required this.repetitionsTotal,
  });

  /// Index of this step in [ResolvedCollection.steps].
  final int index;

  final ContentRef ref;

  /// How many times this item is recited within this step.
  final int count;

  /// The structural entry this step came from, so the player can highlight the
  /// right row without knowing anything about block structure.
  final String entryId;

  /// 1-based pass through the enclosing [RepeatBlock]; 1 when there is none.
  final int repetition;

  /// How many passes the enclosing block makes; 1 when there is none.
  /// Together with [repetition] this is "round 2 of 7".
  final int repetitionsTotal;

  bool get isInRepeatBlock => repetitionsTotal > 1;

  @override
  String toString() =>
      'PlaybackStep($index ${ref.canonical} x$count '
      'round $repetition/$repetitionsTotal)';
}
