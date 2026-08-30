import 'collection_id.dart';
import 'content.dart';
import 'content_ref.dart';
import 'playback_step.dart';
import 'progress.dart';

/// The kind of a built-in collection, as authored in the content pipeline.
/// User collections do not have one.
enum CollectionType { wird, dhikrSet, surahSet }

/// A collection in a list, without its items resolved.
///
/// Built-ins carry the extra fields `content.db` holds for them; a user
/// collection leaves those null.
final class CollectionSummary {
  const CollectionSummary({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.nameArabic,
    this.description,
    this.author,
    this.type,
  });

  final CollectionId id;

  /// `collections.name_english` for a built-in, `user_collections.name` for a
  /// user collection.
  final String name;

  /// Built-ins only.
  final String? nameArabic;

  final String? description;

  /// Built-ins only.
  final String? author;

  /// Built-ins only.
  final CollectionType? type;

  final int sortOrder;

  bool get isBuiltin => id is BuiltinCollectionId;

  @override
  String toString() => 'CollectionSummary(${id.canonical} $name)';
}

/// One entry in a resolved collection, in recitation order.
///
/// Either a single item ([CollectionItemEntry] and its three subtypes) or a
/// [RepeatBlock] of consecutive items recited together a number of times.
sealed class CollectionEntry {
  const CollectionEntry();

  /// The `position` of this entry within its collection; for a [RepeatBlock],
  /// the position of its first member. Position is authoritative — resolution
  /// never relies on database row order.
  int get position;
}

/// An entry backed by exactly one row of a collection's item list.
sealed class CollectionItemEntry extends CollectionEntry {
  const CollectionItemEntry({
    required this.entryId,
    required this.position,
    required this.count,
    this.note,
  });

  /// Identifies the row this entry came from: the UUID of a
  /// `user_collection_items` row, or the stringified `collection_items.id` of
  /// a built-in one. This is the value
  /// `CollectionRepository.removeItem` and `CollectionRepository.reorder`
  /// take.
  final String entryId;

  @override
  final int position;

  /// How many times this item is recited: `count_override`, else a dhikr's
  /// `default_count`, else 1.
  final int count;

  /// A rubric authored alongside a built-in item. Always null for user
  /// collections, which have no note column.
  final String? note;

  /// What this entry points at in `content.db`.
  ContentRef get ref;
}

final class DhikrItem extends CollectionItemEntry {
  const DhikrItem({
    required super.entryId,
    required super.position,
    required super.count,
    required this.dhikr,
    this.source,
    super.note,
  });

  final Dhikr dhikr;

  /// The reference `dhikr.sourceId` points at, hydrated during resolution.
  /// Null when the dhikr cites none.
  final Source? source;

  @override
  ContentRef get ref => ContentRef.dhikr(dhikr.id);

  @override
  String toString() => 'DhikrItem(${dhikr.id} x$count @$position)';
}

final class AyahItem extends CollectionItemEntry {
  const AyahItem({
    required super.entryId,
    required super.position,
    required super.count,
    required this.ayah,
    super.note,
  });

  final Ayah ayah;

  @override
  ContentRef get ref => ContentRef.ayah(ayah.id);

  @override
  String toString() =>
      'AyahItem(${ayah.surahNumber}:${ayah.ayahNumber} x$count @$position)';
}

/// A whole-surah item.
///
/// It resolves to surah metadata only. Ayahs are expanded lazily by the
/// caller, through `ContentRepository.ayahsForSurah` — Al-Baqarah alone is 286
/// of them, and a collection list has no use for the text.
final class SurahItem extends CollectionItemEntry {
  const SurahItem({
    required super.entryId,
    required super.position,
    required super.count,
    required this.surah,
    super.note,
  });

  final Surah surah;

  @override
  ContentRef get ref => ContentRef.surah(surah.number);

  @override
  String toString() => 'SurahItem(${surah.number} x$count @$position)';
}

/// A run of consecutive items recited as a block, [repeatCount] times over.
///
/// Built from the items that share a `repeat_group`.
final class RepeatBlock extends CollectionEntry {
  const RepeatBlock({
    required this.group,
    required this.repeatCount,
    required this.entries,
  });

  /// The `repeat_group` value these items shared.
  final int group;

  /// The `repeat_group_count` they agreed on.
  final int repeatCount;

  final List<CollectionItemEntry> entries;

  @override
  int get position => entries.first.position;

  @override
  String toString() =>
      'RepeatBlock($group x$repeatCount, ${entries.length} items)';
}

/// A collection with its items resolved against `content.db`.
///
/// Two views of the same data: [entries] is structural, for display and
/// editing; [steps] is flat, for playback.
final class ResolvedCollection {
  ResolvedCollection({
    required this.collection,
    required this.entries,
    this.unresolved = const <ContentRef>[],
  }) : steps = _flatten(entries);

  final CollectionSummary collection;

  /// Ordered by `position`, with [RepeatBlock]s intact.
  final List<CollectionEntry> entries;

  /// [entries] flattened for playback, repeat blocks expanded pass by pass.
  final List<PlaybackStep> steps;

  /// Items whose content row was not found and were therefore dropped.
  ///
  /// Always empty for built-ins, whose references the content build verifies.
  /// A user collection can end up here when a content update removes a dhikr
  /// the user had added; one stale row should not make the whole collection
  /// unopenable.
  final List<ContentRef> unresolved;

  CollectionId get id => collection.id;

  /// The progress to resume from, or null to start at the beginning.
  ///
  /// Returns null when [progress] points outside [steps], or when the step it
  /// points at no longer holds the content it did when the progress was
  /// written. A content update or a reorder both invalidate a bare index, and
  /// silently resuming at the wrong dhikr is worse than losing a partial
  /// session.
  WirdProgress? resumableFrom(WirdProgress? progress) {
    if (progress == null) return null;
    if (progress.stepIndex < 0 || progress.stepIndex >= steps.length) {
      return null;
    }
    if (steps[progress.stepIndex].ref != progress.stepRef) return null;
    return progress;
  }

  static List<PlaybackStep> _flatten(List<CollectionEntry> entries) {
    final List<PlaybackStep> steps = <PlaybackStep>[];

    void add(CollectionItemEntry item, int repetition, int total) {
      steps.add(
        PlaybackStep(
          index: steps.length,
          ref: item.ref,
          count: item.count,
          entryId: item.entryId,
          repetition: repetition,
          repetitionsTotal: total,
        ),
      );
    }

    for (final CollectionEntry entry in entries) {
      switch (entry) {
        case CollectionItemEntry():
          add(entry, 1, 1);
        case RepeatBlock(
          :final int repeatCount,
          :final List<CollectionItemEntry> entries,
        ):
          // Pass by pass, not item by item: the block is recited whole each
          // time round.
          for (int pass = 1; pass <= repeatCount; pass++) {
            for (final CollectionItemEntry item in entries) {
              add(item, pass, repeatCount);
            }
          }
      }
    }

    return List<PlaybackStep>.unmodifiable(steps);
  }

  @override
  String toString() =>
      'ResolvedCollection(${collection.id.canonical}, '
      '${entries.length} entries, ${steps.length} steps)';
}
