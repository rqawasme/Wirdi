import 'collection_id.dart';
import 'content_ref.dart';
import 'playback_step.dart';

/// Where the user is in a collection.
///
/// One row per collection, overwritten as they go. [stepIndex] indexes
/// `ResolvedCollection.steps` — the flattened playback list — rather than the
/// structural entries, so a position part-way through a repeat block is
/// expressible: "round 2 of 7, second item".
///
/// Resume through `ResolvedCollection.resumableFrom`, never by indexing
/// `steps` directly. [stepRef] exists so that a stale index cannot silently
/// resume at the wrong dhikr.
final class WirdProgress {
  WirdProgress({
    required this.collectionId,
    required this.stepIndex,
    required this.stepRef,
    required this.currentCount,
    this.unitIndex = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Builds progress for a step, taking [WirdProgress.stepRef] from the step
  /// itself so the two cannot disagree at the point of writing.
  WirdProgress.atStep({
    required this.collectionId,
    required PlaybackStep step,
    required this.currentCount,
    this.unitIndex = 0,
    DateTime? updatedAt,
  }) : stepIndex = step.index,
       stepRef = step.ref,
       updatedAt = updatedAt ?? DateTime.now();

  final CollectionId collectionId;

  /// Index into `ResolvedCollection.steps`.
  final int stepIndex;

  /// What `steps[stepIndex]` pointed at when this was written.
  ///
  /// Checked on resume: a mismatch means a content update or a reorder moved
  /// things underneath, and the progress is discarded rather than applied to
  /// whatever now sits at that index.
  final ContentRef stepRef;

  /// Repetitions completed of the step at [stepIndex].
  final int currentCount;

  /// How far into the current repetition, in units: the ayah of a surah being
  /// recited, and always 0 for a step whose unit is the whole item.
  ///
  /// Stored so that backgrounding half way through Al-Mulk comes back to the
  /// verse it was left on rather than to the top of the surah. Clamped against
  /// the step's `unitCount` on resume, exactly as [currentCount] is: it is a
  /// plain integer in a row this app is not the only possible writer of.
  final int unitIndex;

  final DateTime updatedAt;

  WirdProgress copyWith({
    int? stepIndex,
    ContentRef? stepRef,
    int? currentCount,
    int? unitIndex,
    DateTime? updatedAt,
  }) {
    return WirdProgress(
      collectionId: collectionId,
      stepIndex: stepIndex ?? this.stepIndex,
      stepRef: stepRef ?? this.stepRef,
      currentCount: currentCount ?? this.currentCount,
      unitIndex: unitIndex ?? this.unitIndex,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'WirdProgress(${collectionId.canonical} step $stepIndex '
      '${stepRef.canonical}, count $currentCount, unit $unitIndex)';
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
