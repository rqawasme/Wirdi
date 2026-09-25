import '../domain/collection.dart';
import '../domain/content.dart';
import '../domain/item_ref.dart';
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
    required this.ref,
    required this.position,
    this.countOverride,
    this.repeatGroup,
    this.repeatGroupCount,
    this.note,
  });

  /// `collection_items.id` stringified, or a `user_collection_items` UUID.
  final String entryId;

  /// What this row points at; null when its columns name nothing this app
  /// knows — see `itemRefFromSql`.
  final ItemRef? ref;

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

  /// [userAdhkar] is the adhkar the user wrote that [items] name, by UUID,
  /// read from `user.db` by the caller and handed in here.
  ///
  /// Passed in rather than fetched: this class holds `content.db` and only
  /// `content.db`. `DriftCollectionRepository` is the one place that holds
  /// both databases, so it is the one place that can do that read — see the
  /// note at the top of it.
  Future<ResolvedCollection> resolve(
    CollectionSummary collection,
    List<ResolvableItem> items, {
    Map<String, Dhikr> userAdhkar = const <String, Dhikr>{},
  }) async {
    // position is authoritative; never rely on row order.
    final List<ResolvableItem> ordered = List<ResolvableItem>.of(items)
      ..sort(
        (ResolvableItem a, ResolvableItem b) =>
            a.position.compareTo(b.position),
      );

    final _Batches batches = await _fetch(ordered);

    final List<CollectionEntry> entries = <CollectionEntry>[];
    final List<ItemRef> unresolved = <ItemRef>[];
    final List<String> dropped = <String>[];

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
      final CollectionItemEntry? entry = _entryFor(item, batches, userAdhkar);
      if (entry == null) {
        final ItemRef? ref = item.ref;
        if (ref != null) unresolved.add(ref);
        // Every dropped row, named or not: see
        // [ResolvedCollection.droppedEntryIds] for why an edit needs them.
        dropped.add(item.entryId);
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
      unresolved: List<ItemRef>.unmodifiable(unresolved),
      droppedEntryIds: List<String>.unmodifiable(dropped),
    );
  }

  Future<_Batches> _fetch(List<ResolvableItem> items) async {
    final Set<int> dhikrIds = <int>{};
    final Set<int> ayahIds = <int>{};
    final Set<int> surahNumbers = <int>{};

    for (final ResolvableItem item in items) {
      // A user dhikr is already in hand: it came from user.db, which this
      // class does not hold, so there is nothing here to batch for it.
      if (item.ref case ContentRef(:final ContentType type, :final int id)) {
        switch (type) {
          case ContentType.dhikr:
            dhikrIds.add(id);
          case ContentType.ayah:
            ayahIds.add(id);
          case ContentType.surah:
            surahNumbers.add(id);
        }
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

  CollectionItemEntry? _entryFor(
    ResolvableItem item,
    _Batches batches,
    Map<String, Dhikr> userAdhkar,
  ) {
    switch (item.ref) {
      case ContentRef(type: ContentType.dhikr, :final int id):
        return _dhikrEntry(item, batches.adhkar[id], batches);
      case UserDhikrRef(:final String uuid):
        // The same entry a built-in dhikr makes, and deliberately so: what
        // differs is which database the row came out of, which the dhikr's own
        // ref already says. It cites no `sources` row — see [Dhikr.reference].
        return _dhikrEntry(item, userAdhkar[uuid], batches);
      case ContentRef(type: ContentType.ayah, :final int id):
        final Ayah? ayah = batches.ayahs[id];
        if (ayah == null) return null;
        return AyahItem(
          entryId: item.entryId,
          position: item.position,
          count: item.countOverride ?? 1,
          note: item.note,
          ayah: ayah,
        );
      case ContentRef(type: ContentType.surah, :final int id):
        // Metadata only. The caller expands ayahs when it needs them.
        final Surah? surah = batches.surahs[id];
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

  DhikrItem? _dhikrEntry(ResolvableItem item, Dhikr? dhikr, _Batches batches) {
    if (dhikr == null) return null;
    return DhikrItem(
      entryId: item.entryId,
      position: item.position,
      // count_override wins; a dhikr's own default_count is the fallback.
      count: item.countOverride ?? dhikr.defaultCount,
      note: item.note,
      dhikr: dhikr,
      source: dhikr.sourceId == null ? null : batches.sources[dhikr.sourceId],
    );
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
