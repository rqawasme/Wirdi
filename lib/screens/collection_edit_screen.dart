import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collection_editing.dart';
import '../collections/picked_item.dart';
import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/content.dart';
import '../providers/collections.dart';
import '../providers/editing.dart';
import '../routes.dart';
import '../theme/theme.dart';
import '../widgets/collection_dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/failure_screen.dart';
import '../widgets/plate.dart';
import '../widgets/voussoir_stripe.dart';

/// Editing one of the user's own collections: what is in it, and in what
/// order.
///
/// The list is of *entries*, not items. A [RepeatBlock] is one row and one
/// draggable unit, which is what keeps a group contiguous through a reorder:
/// `CollectionRepository.reorder` wants a full permutation and validates only
/// that it is one, so a list that could drag an item out of the middle of a
/// block would be a list that could quietly split it — see
/// [checkRepeatGroupsIntact].
class CollectionEditScreen extends ConsumerStatefulWidget {
  const CollectionEditScreen({super.key, required this.collectionId});

  final UserCollectionId collectionId;

  @override
  ConsumerState<CollectionEditScreen> createState() =>
      _CollectionEditScreenState();
}

class _CollectionEditScreenState extends ConsumerState<CollectionEditScreen> {
  /// Entry ids picked out for grouping. Empty unless [_selecting].
  final Set<String> _selection = <String>{};

  bool _selecting = false;

  /// A write is in flight. Two of them racing would both read the same order
  /// and one would win by accident.
  bool _busy = false;

  UserCollectionId get _id => widget.collectionId;

  void _refresh() {
    ref.invalidate(resolvedCollectionProvider(_id));
    // The list behind this screen counts items and reads progress, and both
    // just changed.
    ref.invalidate(collectionListingsProvider);
  }

  /// Runs an edit, turning a refusal into a sentence on a snack bar.
  ///
  /// [CollectionEditingError] carries a message written for the person who
  /// caused it. An [ArgumentError] out of the repository is the backstop
  /// behind those checks, so it means this screen asked for something it
  /// should have refused first — worth showing rather than swallowing, but not
  /// worth showing raw.
  /// Returns whether the edit landed, so a caller can decide what to do next
  /// — leaving selection mode on a successful group, and staying in it on a
  /// refusal that is easier to act on with the selection still made.
  Future<bool> _run(Future<void> Function() edit) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await edit();
      _refresh();
      return true;
    } on CollectionEditingError catch (error) {
      _say(error.message);
    } on ArgumentError catch (error) {
      _say(error.message?.toString() ?? 'That change could not be made.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------
  // Adding
  // ---------------------------------------------------------------------

  /// The three pickers, as a sheet rather than a menu: they are three equal
  /// choices and one of them is the answer, which is a sheet's shape.
  Future<void> _add() async {
    final String? route = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: const Text('Surah'),
              subtitle: const Text('A whole surah, read once'),
              onTap: () => Navigator.pop(context, Routes.pickSurah),
            ),
            ListTile(
              title: const Text('Ayah'),
              subtitle: const Text('One ayah, or a range of them'),
              onTap: () => Navigator.pop(context, Routes.pickAyah),
            ),
            ListTile(
              title: const Text('Dhikr'),
              subtitle: const Text('Browsed by the collection it comes from'),
              onTap: () => Navigator.pop(context, Routes.pickDhikr),
            ),
          ],
        ),
      ),
    );
    if (route == null || !mounted) return;

    final Object? result = await Navigator.pushNamed<Object?>(context, route);
    if (result is! List<PickedItem> || result.isEmpty || !mounted) return;

    await _run(() => ref.read(collectionEditorProvider).addItems(_id, result));
  }

  // ---------------------------------------------------------------------
  // Reordering, grouping, removing
  // ---------------------------------------------------------------------

  Future<bool> _move(
    List<CollectionEntry> entries,
    int oldIndex,
    int newIndex,
  ) {
    return _run(
      () => ref
          .read(collectionEditorProvider)
          .moveEntry(_id, entries, oldIndex, newIndex),
    );
  }

  Future<void> _remove(CollectionItemEntry item) async {
    await _run(
      () => ref.read(collectionEditorProvider).removeItem(_id, item.entryId),
    );
  }

  Future<void> _ungroup(RepeatBlock block) async {
    await _run(
      () => ref.read(collectionEditorProvider).ungroup(_id, block.group),
    );
  }

  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      _selection.clear();
    });
  }

  void _toggle(String entryId) {
    setState(() {
      if (!_selection.remove(entryId)) _selection.add(entryId);
    });
  }

  Future<void> _group(List<CollectionEntry> entries) async {
    final int? repetitions = await showRepetitionsDialog(context);
    if (repetitions == null || !mounted) return;

    final Set<String> selection = Set<String>.of(_selection);
    final bool grouped = await _run(
      () => ref
          .read(collectionEditorProvider)
          .group(_id, entries, selection, repetitions),
    );
    if (grouped && mounted) _toggleSelecting();
  }

  // ---------------------------------------------------------------------
  // The collection itself
  // ---------------------------------------------------------------------

  Future<void> _rename(CollectionSummary summary) async {
    final CollectionForm? form = await showCollectionForm(
      context,
      title: 'Rename',
      submitLabel: 'Save',
      initialName: summary.name,
      askForDescription: false,
    );
    if (form == null || !mounted) return;
    await _run(() => ref.read(collectionEditorProvider).rename(_id, form.name));
  }

  Future<void> _delete(CollectionSummary summary) async {
    final bool confirmed = await confirmDeleteCollection(
      context,
      name: summary.name,
    );
    if (!confirmed || !mounted) return;
    final bool deleted = await _run(
      () => ref.read(collectionEditorProvider).delete(_id),
    );
    // Staying on the editor for a collection that is no longer in the list
    // would leave a screen that cannot resolve what it is editing.
    if (deleted && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ResolvedCollection> resolved = ref.watch(
      resolvedCollectionProvider(_id),
    );

    return switch (resolved) {
      AsyncError(:final Object error, :final StackTrace stackTrace) =>
        FailureScreen(
          title: 'Could not open this collection',
          error: error,
          stackTrace: stackTrace,
        ),
      AsyncData(:final ResolvedCollection value) => _scaffold(context, value),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }

  Widget _scaffold(BuildContext context, ResolvedCollection collection) {
    final List<CollectionEntry> entries = collection.entries;

    return Scaffold(
      appBar: AppBar(
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Done selecting',
                onPressed: _toggleSelecting,
              )
            : null,
        title: Text(
          _selecting
              ? '${_selection.length} selected'
              : collection.collection.name,
        ),
        actions: _selecting
            ? <Widget>[
                TextButton(
                  onPressed: _selection.isEmpty ? null : () => _group(entries),
                  child: const Text('Repeat'),
                ),
              ]
            : <Widget>[
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add an item',
                  onPressed: _busy ? null : _add,
                ),
                PopupMenuButton<_Action>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'More',
                  onSelected: (_Action action) => switch (action) {
                    _Action.rename => _rename(collection.collection),
                    _Action.group => _toggleSelectingAsync(),
                    _Action.delete => _delete(collection.collection),
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<_Action>>[
                        const PopupMenuItem<_Action>(
                          value: _Action.rename,
                          child: Text('Rename'),
                        ),
                        PopupMenuItem<_Action>(
                          value: _Action.group,
                          enabled: entries
                              .whereType<CollectionItemEntry>()
                              .isNotEmpty,
                          child: const Text('Repeat some items'),
                        ),
                        const PopupMenuItem<_Action>(
                          value: _Action.delete,
                          child: Text('Delete collection'),
                        ),
                      ],
                ),
              ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(VoussoirStripe.ruleHeight),
          child: VoussoirStripe.rule(),
        ),
      ),
      body: entries.isEmpty
          ? EmptyState(
              title: 'Nothing in this collection yet',
              body:
                  'Add a surah, an ayah or a dhikr, and it will be recited '
                  'in the order you put it in.',
              action: FilledButton(
                onPressed: _busy ? null : _add,
                child: const Text('Add an item'),
              ),
            )
          : ReorderableListView.builder(
              // The handle is explicit: a long press anywhere on a row would
              // fight the tap that selects it, and a row that sometimes picks
              // itself up is a row nobody trusts.
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: WirdiMetrics.space6),
              itemCount: entries.length,
              // onReorderItem rather than the deprecated onReorder: it hands
              // back an index already adjusted for the row having been taken
              // out, which is the convention reorderedItemIds documents.
              onReorderItem: (int oldIndex, int newIndex) =>
                  unawaited(_move(entries, oldIndex, newIndex)),
              itemBuilder: (BuildContext context, int index) => _EntryRow(
                key: ValueKey<String>(_keyOf(entries[index])),
                entry: entries[index],
                index: index,
                selecting: _selecting,
                selection: _selection,
                onToggle: _toggle,
                onRemove: _remove,
                onUngroup: _ungroup,
              ),
            ),
    );
  }

  /// [PopupMenuButton.onSelected] wants something to await; selection mode is
  /// a `setState` and nothing more.
  Future<void> _toggleSelectingAsync() async => _toggleSelecting();

  static String _keyOf(CollectionEntry entry) => switch (entry) {
    CollectionItemEntry(:final String entryId) => entryId,
    RepeatBlock(:final int group) => 'block-$group',
  };
}

enum _Action { rename, group, delete }

/// One row: a single item, or a whole repeat block.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    super.key,
    required this.entry,
    required this.index,
    required this.selecting,
    required this.selection,
    required this.onToggle,
    required this.onRemove,
    required this.onUngroup,
  });

  final CollectionEntry entry;
  final int index;
  final bool selecting;
  final Set<String> selection;
  final void Function(String entryId) onToggle;
  final Future<void> Function(CollectionItemEntry item) onRemove;
  final Future<void> Function(RepeatBlock block) onUngroup;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      final CollectionItemEntry item => _ItemRow(
        item: item,
        handle: _Handle(index: index, enabled: !selecting),
        selecting: selecting,
        selected: selection.contains(item.entryId),
        onToggle: () => onToggle(item.entryId),
        onRemove: () => onRemove(item),
      ),
      final RepeatBlock block => _BlockRow(
        block: block,
        handle: _Handle(index: index, enabled: !selecting),
        selecting: selecting,
        onUngroup: () => onUngroup(block),
        onRemove: onRemove,
      ),
    };
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.index, required this.enabled});

  final int index;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Icon icon = Icon(
      Icons.drag_handle,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    if (!enabled) return Opacity(opacity: 0, child: icon);
    return ReorderableDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.all(WirdiMetrics.space2),
        child: Semantics(label: 'Reorder', child: icon),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.handle,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onRemove,
  });

  final CollectionItemEntry item;
  final Widget handle;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: selected ? theme.colorScheme.surfaceContainer : null,
      child: InkWell(
        onTap: selecting ? onToggle : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WirdiMetrics.space3,
            vertical: WirdiMetrics.space3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (selecting)
                Checkbox(value: selected, onChanged: (bool? _) => onToggle()),
              Expanded(child: EntryLine(item: item)),
              if (item.count > 1) ...<Widget>[
                const SizedBox(width: WirdiMetrics.space3),
                Plate(label: '×${item.count}'),
              ],
              if (!selecting)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove',
                  onPressed: onRemove,
                ),
              handle,
            ],
          ),
        ),
      ),
    );
  }
}

/// A repeat block: its items, and how many times over.
///
/// Drawn as one bordered group with one handle. That is not decoration — it is
/// the block's contiguity made visible, and the reason a drag cannot break it.
class _BlockRow extends StatelessWidget {
  const _BlockRow({
    required this.block,
    required this.handle,
    required this.selecting,
    required this.onUngroup,
    required this.onRemove,
  });

  final RepeatBlock block;
  final Widget handle;
  final bool selecting;
  final VoidCallback onUngroup;
  final Future<void> Function(CollectionItemEntry item) onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          WirdiMetrics.space3,
          WirdiMetrics.space2,
          WirdiMetrics.space3,
          WirdiMetrics.space2,
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline,
              width: WirdiMetrics.hairline,
            ),
            borderRadius: WirdiMetrics.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  WirdiMetrics.space3,
                  WirdiMetrics.space2,
                  WirdiMetrics.space1,
                  0,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Repeated ${block.repeatCount} times',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (!selecting)
                      TextButton(
                        onPressed: onUngroup,
                        child: const Text('Ungroup'),
                      ),
                    handle,
                  ],
                ),
              ),
              for (final CollectionItemEntry item in block.entries)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    WirdiMetrics.space3,
                    WirdiMetrics.space2,
                    WirdiMetrics.space2,
                    WirdiMetrics.space2,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: EntryLine(item: item)),
                      if (item.count > 1) ...<Widget>[
                        const SizedBox(width: WirdiMetrics.space3),
                        Plate(label: '×${item.count}'),
                      ],
                      if (!selecting)
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Remove',
                          onPressed: () => onRemove(item),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: WirdiMetrics.space1),
            ],
          ),
        ),
      ),
    );
  }
}

/// What an item is, in two lines: what it says, and what it is.
class EntryLine extends StatelessWidget {
  const EntryLine({super.key, required this.item});

  final CollectionItemEntry item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final Color quiet = theme.colorScheme.onSurfaceVariant;
    final String? note = item.note;

    final (String title, String subtitle, bool arabic) = switch (item) {
      DhikrItem(:final Dhikr dhikr) => (
        dhikr.textArabic,
        dhikr.translation,
        true,
      ),
      AyahItem(:final Ayah ayah) => (
        'Ayah ${ayah.surahNumber}:${ayah.ayahNumber}',
        ayah.translation,
        false,
      ),
      SurahItem(:final Surah surah) => (
        surah.nameTransliterated,
        'Surah ${surah.number} · ${surah.ayahCount} '
            '${surah.ayahCount == 1 ? 'ayah' : 'ayahs'}',
        false,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (arabic)
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              title,
              style: type.arabicTitle,
              locale: const Locale('ar'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: WirdiMetrics.space1),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(color: quiet),
        ),
        if (note != null && note.isNotEmpty) ...<Widget>[
          const SizedBox(height: WirdiMetrics.space1),
          Text(note, style: theme.textTheme.bodySmall?.copyWith(color: quiet)),
        ],
      ],
    );
  }
}
