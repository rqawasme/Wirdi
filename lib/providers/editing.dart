import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../collections/collection_editing.dart';
import '../collections/picked_item.dart';
import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/content.dart';
import '../domain/content_ref.dart';
import '../domain/repositories.dart';
import 'data_providers.dart';

/// One collection, resolved. Built-in or user-made — the editor watches it for
/// the collection being edited, and the dhikr picker for the built-in being
/// browsed.
final FutureProviderFamily<ResolvedCollection, CollectionId>
resolvedCollectionProvider =
    FutureProvider.family<ResolvedCollection, CollectionId>(
      (Ref ref, CollectionId id) =>
          ref.watch(collectionRepositoryProvider).resolve(id),
      name: 'resolvedCollection',
    );

/// The built-in collections, for the dhikr picker and the duplicate action.
final FutureProvider<List<CollectionSummary>> builtinCollectionsProvider =
    FutureProvider<List<CollectionSummary>>((Ref ref) async {
      final List<CollectionSummary> all = await ref
          .watch(collectionRepositoryProvider)
          .all();
      return all
          .where((CollectionSummary s) => s.isBuiltin)
          .toList(growable: false);
    }, name: 'builtinCollections');

/// The editing actions, over [CollectionRepository] and nothing else.
///
/// Every method here is composition: the repository gained nothing for this
/// phase. What this class adds is the two things a repository should not have
/// to care about — refusals phrased as sentences (see [CollectionEditingError])
/// and the bookkeeping that keeps the repository's own preconditions
/// satisfiable, which is to say keeping `position` dense.
@immutable
final class CollectionEditor {
  const CollectionEditor({
    required CollectionRepository collections,
    required ContentRepository content,
  }) : _collections = collections,
       _content = content;

  final CollectionRepository _collections;
  final ContentRepository _content;

  Future<UserCollectionId> create(String name, {String? description}) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const CollectionEditingError('A collection needs a name.');
    }
    return _collections.create(trimmed, description: _clean(description));
  }

  /// Copies [source] — a built-in, or another collection of the user's — into
  /// a new one they can edit.
  Future<UserCollectionId> duplicate(
    CollectionId source, {
    required String name,
    String? description,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const CollectionEditingError('A collection needs a name.');
    }
    final ResolvedCollection resolved = await _collections.resolve(source);
    return duplicateCollection(
      collections: _collections,
      source: resolved,
      name: trimmed,
      description: _clean(description) ?? resolved.collection.description,
    );
  }

  Future<void> rename(UserCollectionId id, String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const CollectionEditingError('A collection needs a name.');
    }
    return _collections.rename(id, trimmed);
  }

  Future<void> delete(UserCollectionId id) => _collections.delete(id);

  /// Appends [items] in the order given.
  ///
  /// `addItem` appends, so the order of the calls is the order of the items.
  /// An ayah range arrives here already expanded, one [PickedItem] per ayah.
  Future<void> addItems(UserCollectionId id, List<PickedItem> items) async {
    for (final PickedItem item in items) {
      await _collections.addItem(
        id,
        item.ref,
        count: item.count,
        note: item.note,
      );
    }
  }

  /// The ayahs of [surah] from [from] to [to] inclusive, as items.
  ///
  /// Goes through [ContentRepository.ayahRange] rather than counting the
  /// numbers out here, so a range that runs past the end of the surah is
  /// clamped to what exists instead of adding items that resolve to nothing.
  Future<List<PickedItem>> ayahRange(
    int surah,
    int from,
    int to, {
    int? count,
    String? note,
  }) async {
    final List<Ayah> ayahs = await _content.ayahRange(surah, from, to);
    return <PickedItem>[
      for (final Ayah ayah in ayahs)
        PickedItem(ref: ContentRef.ayah(ayah.id), count: count, note: note),
    ];
  }

  /// Removes one item, then closes the gap it left in `position`.
  ///
  /// The renumbering is not tidiness. `setRepeatGroup` refuses a run that is
  /// not contiguous *by position*, so a collection carrying gaps has items
  /// that look adjacent in the list and cannot be grouped.
  Future<void> removeItem(UserCollectionId id, String entryId) async {
    await _collections.removeItem(id, entryId);
    final ResolvedCollection after = await _collections.resolve(id);
    final List<String> order = itemIdsInOrder(after.entries);
    if (order.isNotEmpty) await _collections.reorder(id, order);
  }

  /// Moves the entry at [oldIndex] to [newIndex], blocks moving as units.
  Future<void> moveEntry(
    UserCollectionId id,
    List<CollectionEntry> entries,
    int oldIndex,
    int newIndex,
  ) {
    return _collections.reorder(
      id,
      reorderedItemIds(entries, oldIndex, newIndex),
    );
  }

  /// Groups [selection] into a block recited [repetitions] times.
  ///
  /// Asks [repeatGroupRefusal] first so that a refusal arrives as a sentence.
  /// The repository's own checks still run behind this and still throw — they
  /// are the backstop, not the message.
  Future<void> group(
    UserCollectionId id,
    List<CollectionEntry> entries,
    Set<String> selection,
    int repetitions,
  ) async {
    final String? refusal = repeatGroupRefusal(
      entries: entries,
      selection: selection,
      repetitions: repetitions,
    );
    if (refusal != null) throw CollectionEditingError(refusal);

    // In collection order, which is the order setRepeatGroup's contiguity
    // check reads them in.
    final List<String> ids = <String>[
      for (final CollectionEntry entry in entries)
        if (entry case CollectionItemEntry(:final String entryId))
          if (selection.contains(entryId)) entryId,
    ];
    await _collections.setRepeatGroup(id, ids, repetitions);
  }

  Future<void> ungroup(UserCollectionId id, int group) =>
      _collections.clearRepeatGroup(id, group);

  static String? _clean(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final Provider<CollectionEditor> collectionEditorProvider =
    Provider<CollectionEditor>(
      (Ref ref) => CollectionEditor(
        collections: ref.watch(collectionRepositoryProvider),
        content: ref.watch(contentRepositoryProvider),
      ),
      name: 'collectionEditor',
    );
