import '../domain/collection.dart';
import '../domain/content.dart';
import '../domain/content_ref.dart';
import 'content_database.dart';
import 'mappers.dart';

/// One row of a collection's item list, from either database, in the shape
/// resolution needs.
///
/// Built-in items come from `collection_items` and user items from
/// `user_collection_items`; normalising to this makes both go through exactly
/// the same resolution.
final class ResolvableItem {
  const ResolvableItem({
    required this.entryId,
    required this.itemType,
    required this.itemId,
    required this.position,
    this.countOverride,
    this.repeatGroup,
    this.repeatGroupCount,
    this.note,
  });

  /// `collection_items.id` stringified, or a `user_collection_items` UUID.
  final String entryId;

  /// The raw `item_type` value; null when it is not one this app knows.
  final ContentType? itemType;

  final int itemId;
  final int position;
  final int? countOverride;
  final int? repeatGroup;
  final int? repeatGroupCount;
  final String? note;
}

/// Turns a collection's item rows into ordered [CollectionEntry]s.
///
/// The same algorithm serves built-in and user collections:
///
///   1. take the items, ordered by position
///   2. partition them by item type
///   3. run three batched queries against content.db, one per type, then a
///      fourth for the sources the fetched adhkar cite
///   4. stitch the results back together in Dart, preserving position order
///
/// There is deliberately no polymorphic join. Four `WHERE id IN (…)` reads and
/// a stitch is both faster and far easier to read than a union of three left
/// joins, and it keeps the query shape independent of what a collection
/// happens to contain.
class CollectionResolver {
  const CollectionResolver(this._content);

  final ContentDatabase _content;

  Future<ResolvedCollection> resolve(
    CollectionSummary collection,
    List<ResolvableItem> items,
  ) async {
    // position is authoritative; never rely on row order.
    final List<ResolvableItem> ordered = List<ResolvableItem>.of(items)
      ..sort(
        (ResolvableItem a, ResolvableItem b) =>
            a.position.compareTo(b.position),
      );

    final _Batches batches = await _fetch(ordered);

    final List<CollectionEntry> entries = <CollectionEntry>[];
    final List<ContentRef> unresolved = <ContentRef>[];

    // A repeat block is a maximal run of adjacent items sharing a repeat_group.
    // The content build guarantees built-in groups are contiguous; user rows
    // get the same reading rather than a separate trusting one.
    List<CollectionItemEntry>? blockEntries;
    int? blockGroup;
    int blockCount = 1;

    void closeBlock() {
      if (blockEntries != null && blockEntries!.isNotEmpty) {
        entries.add(
          RepeatBlock(
            group: blockGroup!,
            repeatCount: blockCount,
            entries: List<CollectionItemEntry>.unmodifiable(blockEntries!),
          ),
        );
      }
      blockEntries = null;
      blockGroup = null;
      blockCount = 1;
    }

    for (final ResolvableItem item in ordered) {
      final CollectionItemEntry? entry = _entryFor(item, batches);
      if (entry == null) {
        if (item.itemType != null) {
          unresolved.add(ContentRef(item.itemType!, item.itemId));
        }
        continue;
      }

      final int? group = item.repeatGroup;
      if (group == null) {
        closeBlock();
        entries.add(entry);
        continue;
      }

      if (blockGroup != group) {
        closeBlock();
        blockGroup = group;
        // A group with no count set repeats once, which is to say not at all.
        blockCount = item.repeatGroupCount ?? 1;
        blockEntries = <CollectionItemEntry>[];
      }
      blockEntries!.add(entry);
    }
    closeBlock();

    return ResolvedCollection(
      collection: collection,
      entries: List<CollectionEntry>.unmodifiable(entries),
      unresolved: List<ContentRef>.unmodifiable(unresolved),
    );
  }

  Future<_Batches> _fetch(List<ResolvableItem> items) async {
    final Set<int> dhikrIds = <int>{};
    final Set<int> ayahIds = <int>{};
    final Set<int> surahNumbers = <int>{};

    for (final ResolvableItem item in items) {
      switch (item.itemType) {
        case ContentType.dhikr:
          dhikrIds.add(item.itemId);
        case ContentType.ayah:
          ayahIds.add(item.itemId);
        case ContentType.surah:
          surahNumbers.add(item.itemId);
        case null:
          break;
      }
    }

    final List<DhikrRow> adhkar = dhikrIds.isEmpty
        ? const <DhikrRow>[]
        : await _content.adhkarByIds(ids: dhikrIds.toList()).get();
    final List<AyahRow> ayahs = ayahIds.isEmpty
        ? const <AyahRow>[]
        : await _content.ayahsByIds(ids: ayahIds.toList()).get();
    final List<SurahRow> surahs = surahNumbers.isEmpty
        ? const <SurahRow>[]
        : await _content.surahsByNumbers(numbers: surahNumbers.toList()).get();

    // The fourth batch, and the only one that depends on an earlier one: the
    // references cited by the adhkar just fetched. Sourcing is a trust
    // feature, so it rides along rather than waiting on a second call.
    final Set<int> sourceIds = <int>{
      for (final DhikrRow row in adhkar)
        if (row.sourceId != null) row.sourceId!,
    };
    final List<SourceRow> sources = sourceIds.isEmpty
        ? const <SourceRow>[]
        : await _content.sourcesByIds(ids: sourceIds.toList()).get();

    return _Batches(
      adhkar: <int, Dhikr>{
        for (final DhikrRow row in adhkar) row.id: dhikrFromRow(row),
      },
      ayahs: <int, Ayah>{
        for (final AyahRow row in ayahs) row.id: ayahFromRow(row),
      },
      surahs: <int, Surah>{
        for (final SurahRow row in surahs) row.number: surahFromRow(row),
      },
      sources: <int, Source>{
        for (final SourceRow row in sources) row.id: sourceFromRow(row),
      },
    );
  }

  CollectionItemEntry? _entryFor(ResolvableItem item, _Batches batches) {
    switch (item.itemType) {
      case ContentType.dhikr:
        final Dhikr? dhikr = batches.adhkar[item.itemId];
        if (dhikr == null) return null;
        return DhikrItem(
          entryId: item.entryId,
          position: item.position,
          // count_override wins; a dhikr's own default_count is the fallback.
          count: item.countOverride ?? dhikr.defaultCount,
          note: item.note,
          dhikr: dhikr,
          source: dhikr.sourceId == null
              ? null
              : batches.sources[dhikr.sourceId],
        );
      case ContentType.ayah:
        final Ayah? ayah = batches.ayahs[item.itemId];
        if (ayah == null) return null;
        return AyahItem(
          entryId: item.entryId,
          position: item.position,
          count: item.countOverride ?? 1,
          note: item.note,
          ayah: ayah,
        );
      case ContentType.surah:
        // Metadata only. The caller expands ayahs when it needs them.
        final Surah? surah = batches.surahs[item.itemId];
        if (surah == null) return null;
        return SurahItem(
          entryId: item.entryId,
          position: item.position,
          count: item.countOverride ?? 1,
          note: item.note,
          surah: surah,
        );
      case null:
        return null;
    }
  }
}

class _Batches {
  const _Batches({
    required this.adhkar,
    required this.ayahs,
    required this.surahs,
    required this.sources,
  });

  final Map<int, Dhikr> adhkar;
  final Map<int, Ayah> ayahs;
  final Map<int, Surah> surahs;
  final Map<int, Source> sources;
}
