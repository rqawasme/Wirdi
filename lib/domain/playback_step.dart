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
    this.unitCount = 1,
  });

  /// Index of this step in [ResolvedCollection.steps].
  final int index;

  final ContentRef ref;

  /// How many times this item is recited within this step.
  final int count;

  /// How many units one repetition of this step is made of.
  ///
  /// A step is a sequence of units, repeated [count] times, and a tap consumes
  /// one unit. For a dhikr or a single ayah the unit is the whole item, so this
  /// is 1 and a tap is a repetition. For a surah the unit is one ayah, so
  /// Al-Ikhlas x3 is four ayahs over three rounds: twelve taps, with the verses
  /// shown one at a time.
  ///
  /// The cursor over these lives in the player, not in the step list: a surah
  /// is one [PlaybackStep] however many ayahs it has, because `steps.length`
  /// is what the stripe is cut by and what "3 of 12" counts.
  final int unitCount;

  /// The structural entry this step came from, so the player can highlight the
  /// right row without knowing anything about block structure.
  final String entryId;

  /// 1-based pass through the enclosing [RepeatBlock]; 1 when there is none.
  final int repetition;

  /// How many passes the enclosing block makes; 1 when there is none.
  /// Together with [repetition] this is "round 2 of 7".
  final int repetitionsTotal;

  bool get isInRepeatBlock => repetitionsTotal > 1;

  /// More than one unit to a repetition, so advancing moves through the item
  /// before it counts a repetition of it.
  bool get isMultiUnit => unitCount > 1;

  @override
  String toString() =>
      'PlaybackStep($index ${ref.canonical} x$count '
      'of $unitCount unit(s) round $repetition/$repetitionsTotal)';
}
