import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collection_editing.dart';
import '../domain/collection_id.dart';
import '../domain/commitment.dart';
import '../providers/collections.dart';
import '../providers/editing.dart';
import '../providers/home.dart';
import '../routes.dart';
import '../theme/theme.dart';
import '../widgets/collection_dialogs.dart';
import '../widgets/collection_row.dart';
import '../widgets/empty_state.dart';
import '../widgets/failure_screen.dart';

/// Every collection there is: the user's own first, then the built-ins.
///
/// This is the tab about what the app *contains* — where collections are made,
/// copied, edited, deleted, and committed to. Home is the tab about what today
/// contains, and it shows only what was committed here.
///
/// A body rather than a screen with its own [Scaffold]: the app bar and the
/// navigation bar belong to [AppShell], which swaps this body for another
/// without either of them moving.
class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CollectionListing>> listings = ref.watch(
      collectionListingsProvider,
    );

    return switch (listings) {
      AsyncError(:final Object error, :final StackTrace stackTrace) =>
        FailureScreen(
          title: 'Could not read the collections',
          error: error,
          stackTrace: stackTrace,
        ),
      AsyncData(:final List<CollectionListing> value) => _CollectionList(
        listings: value,
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// The two groups, and whatever the list has to say when it is short of rows.
class _CollectionList extends ConsumerWidget {
  const _CollectionList({required this.listings});

  final List<CollectionListing> listings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (listings.isEmpty) {
      // Only reachable if content.db shipped without any built-ins, which the
      // content build would have to have gone wrong for.
      return EmptyState(
        title: 'No collections',
        body: 'Nothing was found to recite. Make one of your own to start.',
        action: FilledButton(
          onPressed: () => newCollection(context, ref),
          child: const Text('New collection'),
        ),
      );
    }

    final List<CollectionListing> mine = <CollectionListing>[
      for (final CollectionListing l in listings)
        if (!l.summary.isBuiltin) l,
    ];
    final List<CollectionListing> builtin = <CollectionListing>[
      for (final CollectionListing l in listings)
        if (l.summary.isBuiltin) l,
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: WirdiMetrics.space6),
      children: <Widget>[
        // Yours first. What somebody made is what they are looking for; the
        // built-ins are the shelf they took it off.
        const _GroupLabel('Yours'),
        if (mine.isEmpty) const _NoneOfYourOwn() else ..._rows(mine),
        const _GroupLabel('Built-in'),
        ..._rows(builtin),
      ],
    );
  }

  /// Rows with a hairline between them — a division, not a bar, and none
  /// before the first or after the last: the group label is the boundary
  /// there.
  List<Widget> _rows(List<CollectionListing> group) {
    final List<Widget> rows = <Widget>[];
    for (final CollectionListing listing in group) {
      if (rows.isNotEmpty) rows.add(const _Hairline());
      rows.add(_Row(listing: listing));
    }
    return rows;
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.space4,
        WirdiMetrics.space5,
        WirdiMetrics.space4,
        WirdiMetrics.space2,
      ),
      child: Text(
        label,
        style: type.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: WirdiMetrics.hairline,
      thickness: WirdiMetrics.hairline,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

/// One collection, and the menu of what can be done to it.
class _Row extends ConsumerWidget {
  const _Row({required this.listing});

  final CollectionListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CollectionRow(
      listing: listing,
      onTap: () => _open(context, ref),
      trailing: _RowMenu(listing: listing),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    await Navigator.pushNamed(
      context,
      Routes.player,
      arguments: PlayerArguments(collectionId: listing.id),
    );
    // The player is where completions and progress happen, so the row that
    // launched it is stale the moment it comes back — and so is the home
    // screen behind this tab, if this collection is committed.
    if (context.mounted) {
      ref.invalidate(collectionListingsProvider);
      ref.invalidate(homeViewProvider);
    }
  }
}

/// What sits under the built-ins before the user has made anything.
class _NoneOfYourOwn extends ConsumerWidget {
  const _NoneOfYourOwn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: WirdiMetrics.space4),
      child: EmptyState(
        title: 'Nothing of your own yet',
        // The second sentence is the path that matters, and it is the one
        // people reach for: al-Haddad's wird with two more adhkar in it.
        body:
            'Start an empty collection, or copy a built-in one and change '
            'it to suit you.',
        action: FilledButton(
          onPressed: () => newCollection(context, ref),
          child: const Text('New collection'),
        ),
      ),
    );
  }
}

enum _RowAction { commit, uncommit, edit, duplicate, delete }

/// What can be done to a collection without opening it.
///
/// A built-in offers two things: a copy you can edit, and a place in your day.
/// Committing is here rather than on Home because Home shows the result of the
/// decision and this is where the decision is made — and because a built-in
/// can be committed to without being copied first, which is the common case.
class _RowMenu extends ConsumerWidget {
  const _RowMenu({required this.listing});

  final CollectionListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CollectionId id = listing.id;
    // Absent means not committed. While the read is in flight the menu offers
    // committing, which is the right guess for a collection nobody has
    // committed yet and is corrected the moment the map arrives.
    final Map<CollectionId, DailySection> committed =
        ref.watch(commitmentsProvider).value ??
        const <CollectionId, DailySection>{};
    final DailySection? section = committed[id];

    return PopupMenuButton<_RowAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'More',
      onSelected: (_RowAction action) => switch (action) {
        _RowAction.commit => _commit(context, ref, id, current: section),
        _RowAction.uncommit => ref.read(homeCommitmentsProvider).uncommit(id),
        _RowAction.edit => _edit(context, id),
        _RowAction.duplicate => duplicateCollectionFlow(
          context,
          ref,
          source: id,
          name: listing.name,
        ),
        _RowAction.delete => _delete(context, ref, id),
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_RowAction>>[
        PopupMenuItem<_RowAction>(
          value: _RowAction.commit,
          // Committed already, this moves it. The label says which it is
          // doing rather than leaving the user to find out.
          child: Text(
            section == null
                ? 'Commit to daily practice'
                : 'Move to another part of the day',
          ),
        ),
        if (section != null)
          const PopupMenuItem<_RowAction>(
            value: _RowAction.uncommit,
            child: Text('Remove from home'),
          ),
        if (id is UserCollectionId)
          const PopupMenuItem<_RowAction>(
            value: _RowAction.edit,
            child: Text('Edit'),
          ),
        const PopupMenuItem<_RowAction>(
          value: _RowAction.duplicate,
          child: Text('Make a copy I can edit'),
        ),
        if (id is UserCollectionId)
          const PopupMenuItem<_RowAction>(
            value: _RowAction.delete,
            child: Text('Delete'),
          ),
      ],
    );
  }

  Future<void> _commit(
    BuildContext context,
    WidgetRef ref,
    CollectionId id, {
    required DailySection? current,
  }) async {
    final DailySection? section = await showSectionPicker(
      context,
      name: listing.name,
      current: current,
    );
    if (section == null || !context.mounted) return;
    await ref.read(homeCommitmentsProvider).commit(id, section);
  }

  Future<void> _edit(BuildContext context, CollectionId id) async {
    if (id is! UserCollectionId) return;
    await Navigator.pushNamed(
      context,
      Routes.collectionEdit,
      arguments: CollectionEditArguments(collectionId: id),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CollectionId id,
  ) async {
    if (id is! UserCollectionId) return;
    final bool confirmed = await confirmDeleteCollection(
      context,
      name: listing.name,
    );
    if (!confirmed || !context.mounted) return;
    await runCollectionEdit(
      context,
      ref,
      () => ref.read(collectionEditorProvider).delete(id),
    );
    // A deleted collection cannot stay committed: the home screen drops a
    // commitment whose collection is gone, but the row should go with it
    // rather than waiting for the next read.
    await ref.read(homeCommitmentsProvider).uncommit(id);
  }
}

/// Makes an empty collection and opens it, because an empty collection is not
/// somewhere to be left standing.
Future<void> newCollection(BuildContext context, WidgetRef ref) async {
  final CollectionForm? form = await showCollectionForm(
    context,
    title: 'New collection',
    submitLabel: 'Create',
  );
  if (form == null || !context.mounted) return;

  UserCollectionId? created;
  await runCollectionEdit(context, ref, () async {
    created = await ref
        .read(collectionEditorProvider)
        .create(form.name, description: form.description);
  });

  final UserCollectionId? id = created;
  if (id == null || !context.mounted) return;
  await Navigator.pushNamed(
    context,
    Routes.collectionEdit,
    arguments: CollectionEditArguments(collectionId: id),
  );
}

/// Copies [source] into a collection of the user's own, and opens it.
///
/// The copy lands in the editor rather than in the list: somebody who asked
/// for a copy they can edit asked to edit it.
Future<void> duplicateCollectionFlow(
  BuildContext context,
  WidgetRef ref, {
  required CollectionId source,
  required String name,
}) async {
  final CollectionForm? form = await showCollectionForm(
    context,
    title: 'Make a copy',
    submitLabel: 'Copy',
    initialName: copyOf(name),
  );
  if (form == null || !context.mounted) return;

  UserCollectionId? created;
  await runCollectionEdit(context, ref, () async {
    created = await ref
        .read(collectionEditorProvider)
        .duplicate(source, name: form.name, description: form.description);
  });

  final UserCollectionId? id = created;
  if (id == null || !context.mounted) return;
  await Navigator.pushNamed(
    context,
    Routes.collectionEdit,
    arguments: CollectionEditArguments(collectionId: id),
  );
}

/// Runs an edit from the list, refreshing it and saying what went wrong.
Future<void> runCollectionEdit(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() edit,
) async {
  try {
    await edit();
    ref.invalidate(collectionListingsProvider);
    ref.invalidate(homeViewProvider);
  } on CollectionEditingError catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error.message)));
  }
}
