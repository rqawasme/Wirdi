import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collection_editing.dart';
import '../domain/collection_id.dart';
import '../domain/commitment.dart';
import '../providers/collections.dart';
import '../providers/editing.dart';
import '../providers/home.dart';
import '../providers/refresh.dart';
import '../routes.dart';
import '../theme/theme.dart';
import '../widgets/banded_row.dart';
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
        // The user's own first. What somebody made is what they are looking
        // for; the built-ins are the shelf they took it off.
        // "New collection" is the app bar's, not this label's: AppShell shows
        // it whenever this tab is open, and a second + here was one too many.
        const _GroupLabel('Your Collections'),
        if (mine.isEmpty) const _NoneOfYourOwn() else ..._rows(mine),
        const _GroupLabel('Noble Collections'),
        ..._rows(builtin),
        // After the shelf, not above it: what somebody opens this tab for is a
        // collection, and their own adhkar are the ingredients rather than the
        // dish. A row in the list rather than a second icon in the app bar —
        // the bar's one collections-only action is already "New collection",
        // and this is not a thing anybody does twice in a morning.
        const _YourAdhkarRow(),
      ],
    );
  }

  /// Rows on alternating grounds, as the pickers draw theirs. A hairline
  /// between them was the first answer and the list still ran together: every
  /// row is a name, a line of detail and four icons, and one looks much like
  /// the next. Banded from zero within each group, so "Your Collections" and
  /// "Noble Collections" both start on the plain surface under their label.
  List<Widget> _rows(List<CollectionListing> group) => <Widget>[
    for (int i = 0; i < group.length; i++)
      BandedRow(index: i, child: _Row(listing: group[i])),
  ];
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final WirdiTypography type = Theme.of(
      context,
    ).extension<WirdiTypography>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.space4,
        WirdiMetrics.space5,
        WirdiMetrics.space4,
        WirdiMetrics.space2,
      ),
      // The section header Home uses over its own groups, not a caption: in a
      // list this long the two headings are what the eye finds its way by.
      child: Text(label, style: type.sectionHeader),
    );
  }
}

/// One collection, and what can be done to it: look inside it, recite it,
/// commit it, or reach the rest through the overflow menu.
///
/// The row's body carries no `onTap` of its own — separate buttons covering
/// "look inside", "recite", "commit" and "everything else" made a fifth,
/// implicit one (the row itself) a false economy: it would duplicate one of
/// them without looking like a button at all, and there is no longer an obvious
/// candidate for which.
class _Row extends ConsumerWidget {
  const _Row({required this.listing});

  final CollectionListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<CollectionId, Commitment> committed =
        ref.watch(commitmentsProvider).value ??
        const <CollectionId, Commitment>{};
    final Commitment? commitment = committed[listing.id];

    return CollectionRow(
      listing: listing,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ContentsButton(listing: listing),
          _PlayButton(listing: listing),
          _CommitButton(listing: listing, commitment: commitment),
          _RowMenu(listing: listing, commitment: commitment),
        ],
      ),
    );
  }
}

/// Opens the collection's contents: what is in it, in the order it is recited.
///
/// This used to be the player, which meant the only way to find out what a wird
/// contained was to start reciting it. Looking and reciting are now two
/// buttons, and this is the one people reach for when they do not yet know
/// which collection they want.
///
/// `Icons.list_alt_outlined` rather than `Icons.format_list_bulleted`, which is
/// the Collections tab's own glyph and would read as "you are here" instead of
/// "look inside this"; and not `Icons.menu_book_outlined`, which is the mushaf.
class _ContentsButton extends ConsumerWidget {
  const _ContentsButton({required this.listing});

  final CollectionListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'See what is in it',
      icon: const Icon(Icons.list_alt_outlined),
      onPressed: () => _open(context, ref),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    await Navigator.pushNamed(
      context,
      Routes.collectionContents,
      arguments: CollectionContentsArguments(collectionId: listing.id),
    );
    // The contents screen recites nothing itself, but the player is one row
    // away in the list behind it and a return here can have a finished wird
    // behind it too. Refreshing costs a handful of indexed reads.
    if (context.mounted) {
      ref.invalidate(collectionListingsProvider);
      ref.invalidate(homeViewProvider);
    }
  }
}

/// Opens the collection in the player — the single most common thing to do
/// with a row, so it keeps its own button rather than becoming a menu entry.
class _PlayButton extends ConsumerWidget {
  const _PlayButton({required this.listing});

  final CollectionListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'Recite',
      icon: const Icon(Icons.play_arrow_outlined),
      onPressed: () => _open(context, ref),
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

/// Commits the collection to the day, or changes when an already-committed
/// one falls — the same sheet either way, since "commit" and "change when"
/// are the same question asked at different times.
///
/// The icon mirrors the Home tab's own (`Icons.home_outlined` /
/// `Icons.home`) and the overflow menu's language ("Remove from home"): this
/// button is asking whether the collection has a place in the day.
class _CommitButton extends ConsumerWidget {
  const _CommitButton({required this.listing, required this.commitment});

  final CollectionListing listing;
  final Commitment? commitment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool committed = commitment != null;
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: committed ? 'Change when committed' : 'Commit to my practice',
      icon: Icon(committed ? Icons.home : Icons.home_outlined),
      onPressed: () => _commit(context, ref),
    );
  }

  Future<void> _commit(BuildContext context, WidgetRef ref) async {
    final Commitment? current = commitment;
    final CommitmentChoice? choice = await showCommitmentSheet(
      context,
      name: listing.name,
      current: current == null
          ? null
          : CommitmentChoice(section: current.section, days: current.days),
    );
    if (choice == null || !context.mounted) return;
    await ref
        .read(homeCommitmentsProvider)
        .commit(listing.id, choice.section, days: choice.days);
  }
}

/// The way through to the adhkar the user wrote.
///
/// Counts nothing. A number here would be read as a count of collections,
/// which is what every other row in this list carries, and the screen behind
/// it says how many there are the moment it opens.
class _YourAdhkarRow extends StatelessWidget {
  const _YourAdhkarRow();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: WirdiMetrics.space5),
      child: ListTile(
        leading: const Icon(Icons.edit_note_outlined),
        title: const Text('Your adhkar'),
        subtitle: const Text('Adhkar you wrote, to put in your collections'),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: () => Navigator.pushNamed(context, Routes.adhkar),
      ),
    );
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

enum _RowAction { uncommit, edit, duplicate, delete }

/// What can be done to a collection beyond opening or committing it, both of
/// which have their own buttons now: removing it from the day, editing it,
/// copying it, deleting it.
///
/// A built-in only ever offers a copy you can edit — it has no edit or
/// delete of its own, and no uncommit either while nobody has committed it.
class _RowMenu extends ConsumerWidget {
  const _RowMenu({required this.listing, required this.commitment});

  final CollectionListing listing;
  final Commitment? commitment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CollectionId id = listing.id;

    return PopupMenuButton<_RowAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'More',
      onSelected: (_RowAction action) => switch (action) {
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
        if (commitment != null)
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
  // Before the await: see [refreshAfterUserWrite] on why not `ref` after it.
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  try {
    await edit();
    // Creating, copying or deleting a collection. Deleting one also changes
    // the count on every dhikr of the user's own it held.
    refreshAfterUserWrite(container);
  } on CollectionEditingError catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error.message)));
  }
}
