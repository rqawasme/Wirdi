import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/content_ref.dart';
import '../domain/repositories.dart';

/// A refusal phrased for the person who caused it.
///
/// [CollectionRepository] guards its own invariants with [ArgumentError], which
/// is the right thing for a programming error and the wrong thing to put in
/// front of somebody who has just dragged a row. Everything in this file that
/// can refuse, refuses with one of these, and the editor screen shows
/// [message] verbatim.
class CollectionEditingError implements Exception {
  const CollectionEditingError(this.message);

  /// A whole sentence, in the app's voice. Shown as-is.
  final String message;

  @override
  String toString() => message;
}

/// Every item id in [entries], repeat blocks expanded in place, in order.
///
/// This is the shape `CollectionRepository.reorder` wants: the complete
/// permutation, not a delta.
List<String> itemIdsInOrder(List<CollectionEntry> entries) {
  final List<String> ids = <String>[];
  for (final CollectionEntry entry in entries) {
    switch (entry) {
      case CollectionItemEntry(:final String entryId):
        ids.add(entryId);
      case RepeatBlock(entries: final List<CollectionItemEntry> members):
        // In their own order. A block's internal order is not something the
        // list can reorder, because the list draws the block as one row.
        for (final CollectionItemEntry member in members) {
          ids.add(member.entryId);
        }
    }
  }
  return ids;
}

/// [entries] with the entry at [oldIndex] moved to [newIndex], flattened.
///
/// Both indexes are into [entries] as it stands, and [newIndex] is where the
/// moved entry ends up — the convention `ReorderableListView.onReorderItem`
/// hands back, having already taken off the off-by-one its deprecated
/// predecessor left to the caller.
///
/// Operating on entries rather than items is what keeps repeat blocks whole. A
/// block is one draggable row and one contiguous run of ids here, so a drag
/// cannot produce an order that splits one — see [checkRepeatGroupsIntact],
/// which asserts exactly that.
List<String> reorderedItemIds(
  List<CollectionEntry> entries,
  int oldIndex,
  int newIndex,
) {
  if (oldIndex < 0 || oldIndex >= entries.length) {
    throw ArgumentError.value(oldIndex, 'oldIndex', 'is not an entry');
  }
  if (newIndex < 0 || newIndex >= entries.length) {
    throw ArgumentError.value(newIndex, 'newIndex', 'is off the end');
  }

  final List<CollectionEntry> moved = List<CollectionEntry>.of(entries);
  moved.insert(newIndex, moved.removeAt(oldIndex));

  final List<String> order = itemIdsInOrder(moved);
  // Belt and braces: the caller is about to hand this to a repository that
  // will not check it, and a split group is silent corruption rather than an
  // error — see the note on reorder in the repository.
  checkRepeatGroupsIntact(entries, order);
  return order;
}

/// Throws [CollectionEditingError] if [order] leaves a repeat block's items
/// anywhere but in one unbroken run.
///
/// `CollectionRepository.reorder` validates that the list is a full
/// permutation and nothing else, so this is the only thing standing between a
/// drag and a repeat group scattered through the collection. A scattered group
/// does not fail on read: the resolver forms maximal runs, so the block would
/// quietly come back as two blocks with the same number.
void checkRepeatGroupsIntact(
  List<CollectionEntry> entries,
  List<String> order,
) {
  final Map<String, int> blockOf = <String, int>{};
  for (final CollectionEntry entry in entries) {
    if (entry case RepeatBlock(
      :final int group,
      entries: final List<CollectionItemEntry> members,
    )) {
      for (final CollectionItemEntry member in members) {
        blockOf[member.entryId] = group;
      }
    }
  }
  if (blockOf.isEmpty) return;

  final Set<int> closed = <int>{};
  int? open;
  for (final String id in order) {
    final int? group = blockOf[id];
    if (group == open) continue;
    if (open != null) closed.add(open);
    if (group != null && closed.contains(group)) {
      throw const CollectionEditingError(
        'A repeat block is recited as one run, so it moves as one. '
        'This change would split it apart.',
      );
    }
    open = group;
  }
}

/// Why [selection] cannot be made into a repeat block, or null if it can.
///
/// Mirrors what `CollectionRepository.setRepeatGroup` refuses — items already
/// grouped, a run that is not contiguous by position, fewer than one
/// repetition — and says it in a sentence. The repository's own
/// [ArgumentError]s stay where they are, as the backstop for a caller that did
/// not ask first.
String? repeatGroupRefusal({
  required List<CollectionEntry> entries,
  required Set<String> selection,
  required int repetitions,
}) {
  if (repetitions < 1) {
    return 'A repeat block is recited at least once.';
  }
  if (selection.isEmpty) {
    return 'Choose the items to repeat first.';
  }

  final List<int> positions = <int>[];
  final Set<String> seen = <String>{};
  for (final CollectionEntry entry in entries) {
    switch (entry) {
      case CollectionItemEntry(:final String entryId, :final int position):
        if (selection.contains(entryId)) {
          seen.add(entryId);
          positions.add(position);
        }
      case RepeatBlock(entries: final List<CollectionItemEntry> members):
        for (final CollectionItemEntry member in members) {
          if (selection.contains(member.entryId)) {
            return 'Those items are already in a repeat block. '
                'Ungroup it before making a new one.';
          }
        }
    }
  }

  if (seen.length != selection.length) {
    return 'Some of those items are no longer in this collection.';
  }

  positions.sort();
  for (int i = 1; i < positions.length; i++) {
    if (positions[i] != positions[i - 1] + 1) {
      return 'A repeat block has to be one unbroken run. '
          'Choose items that sit next to each other.';
    }
  }
  return null;
}

/// The `count_override` [entry] carries, or null where its count is the
/// natural one.
///
/// A resolved entry's `count` has already had the fallbacks applied — a
/// dhikr's `default_count`, or 1 for an ayah or a surah — so copying it back
/// verbatim would write an override onto every item, freezing today's default
/// into the copy. Only a count that differs from the fallback was an override.
int? countOverrideOf(CollectionItemEntry entry) {
  final int natural = switch (entry) {
    DhikrItem(:final dhikr) => dhikr.defaultCount,
    AyahItem() || SurahItem() => 1,
  };
  return entry.count == natural ? null : entry.count;
}

/// Copies [source] into a new user collection called [name].
///
/// Composition, not new data-layer work: [CollectionRepository.create] makes
/// the row, [CollectionRepository.addItem] appends each item in order with its
/// count override and note, and [CollectionRepository.setRepeatGroup] puts the
/// blocks back over the runs they occupied.
///
/// The one indirection is that `addItem` does not hand back the id of the row
/// it wrote, and `setRepeatGroup` is addressed by item id. So every item goes
/// in first, the copy is resolved once, and the ids come back in position
/// order — which is the order they went in, because `addItem` appends.
///
/// Items [source] could not resolve are not copied. They are rows whose
/// content is gone; carrying the reference across would make a second
/// collection that cannot open it either.
Future<UserCollectionId> duplicateCollection({
  required CollectionRepository collections,
  required ResolvedCollection source,
  required String name,
  String? description,
}) async {
  final UserCollectionId id = await collections.create(
    name,
    description: description,
  );

  // Flattened to items, remembering which run each block occupied so the
  // groups can be re-formed against the new ids.
  final List<CollectionItemEntry> items = <CollectionItemEntry>[];
  final List<({int start, int length, int repetitions})> blocks =
      <({int start, int length, int repetitions})>[];

  for (final CollectionEntry entry in source.entries) {
    switch (entry) {
      case CollectionItemEntry():
        items.add(entry);
      case RepeatBlock(
        :final int repeatCount,
        entries: final List<CollectionItemEntry> members,
      ):
        blocks.add((
          start: items.length,
          length: members.length,
          repetitions: repeatCount,
        ));
        items.addAll(members);
    }
  }

  for (final CollectionItemEntry item in items) {
    final ContentRef ref = item.ref;
    await collections.addItem(
      id,
      ref,
      count: countOverrideOf(item),
      note: item.note,
    );
  }

  if (blocks.isEmpty) return id;

  final ResolvedCollection copy = await collections.resolve(id);
  // Nothing is grouped yet, so every entry is a single item and the ids come
  // back in the order they were added.
  final List<String> ids = itemIdsInOrder(copy.entries);
  for (final ({int start, int length, int repetitions}) block in blocks) {
    await collections.setRepeatGroup(
      id,
      ids.sublist(block.start, block.start + block.length),
      block.repetitions,
    );
  }
  return id;
}

/// A name for a copy of [name], in the app's voice.
String copyOf(String name) => 'Copy of $name';
