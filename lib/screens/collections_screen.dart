import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collection_editing.dart';
import '../domain/collection_id.dart';
import '../providers/collections.dart';
import '../providers/editing.dart';
import '../providers/settings.dart';
import '../providers/streak.dart';
import '../routes.dart';
import '../theme/theme.dart';
import '../widgets/collection_dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/failure_screen.dart';
import '../widgets/streak_panel.dart';
import '../widgets/voussoir_stripe.dart';

/// The wirds: built-ins first, then the user's own.
///
/// The app opens here. A wird is what somebody came to do; the mushaf is one
/// tap away in the app bar, which is the right way round for an app whose
/// centre is the counter.
class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CollectionListing>> listings = ref.watch(
      collectionListingsProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wird'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New collection',
            onPressed: () => newCollection(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Quran',
            onPressed: () => Navigator.pushNamed(context, Routes.surahList),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, Routes.settings),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () => Navigator.pushNamed(context, Routes.about),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(VoussoirStripe.ruleHeight),
          child: VoussoirStripe.rule(),
        ),
      ),
      body: switch (listings) {
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
      },
    );
  }
}

/// The streak, the rows, and whatever the list has to say when it is short of
/// them.
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

    final bool hasOwn = listings.any(
      (CollectionListing l) => !l.summary.isBuiltin,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: WirdiMetrics.space6),
      children: <Widget>[
        const _Streak(),
        for (final CollectionListing listing in listings)
          _CollectionRow(listing: listing),
        if (!hasOwn) const _NoneOfYourOwn(),
      ],
    );
  }
}

/// The streak, if it is wanted.
///
/// Hidden entirely when the setting is off — not greyed, not collapsed to a
/// number. And absent while the settings load rather than appearing and then
/// vanishing, which would show it to exactly the person who asked not to see
/// it.
class _Streak extends ConsumerWidget {
  const _Streak();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool show = ref.watch(settingsProvider).value?.showStreak ?? false;
    if (!show) return const SizedBox.shrink();

    final AsyncValue<StreakView> view = ref.watch(streakViewProvider);
    final StreakView? value = view.value;
    // A streak that cannot be read is not worth a failure screen: the wirds
    // are underneath it and they are what the screen is for.
    if (value == null) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        StreakPanel(view: value),
        const VoussoirStripe.rule(),
      ],
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

/// One collection.
///
/// The completed-today mark is deliberately quiet — a small check in
/// [ColorScheme.onSurfaceVariant], on the same line as the item count and in
/// the same colour as it. Finishing a daily wird is the expected outcome, not
/// an achievement, and a row that congratulates you every evening stops meaning
/// anything by the third day.
class _CollectionRow extends ConsumerWidget {
  const _CollectionRow({required this.listing});

  /// The most of a row the Arabic name may take before it starts wrapping.
  static const double _arabicShare = 0.45;

  final CollectionListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final Color quiet = theme.colorScheme.onSurfaceVariant;
    final String? nameArabic = listing.summary.nameArabic;

    final String items =
        '${listing.itemCount} ${listing.itemCount == 1 ? 'item' : 'items'}';
    final String state = listing.completedToday
        ? 'done today'
        : listing.inProgress
        ? 'part-way through'
        : 'not started today';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Semantics(
            container: true,
            button: true,
            label: '${listing.name}, $items, $state',
            child: InkWell(
              onTap: () => _open(context, ref),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  WirdiMetrics.space4,
                  WirdiMetrics.space4,
                  0,
                  WirdiMetrics.space4,
                ),
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      LayoutBuilder(
                        builder:
                            (
                              BuildContext context,
                              BoxConstraints constraints,
                            ) => Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    listing.name,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                if (nameArabic != null) ...<Widget>[
                                  const SizedBox(width: WirdiMetrics.space4),
                                  // Capped rather than given a flex share: an
                                  // Arabic name that needs a third of the row
                                  // should not take half of it and wrap the
                                  // English name that would otherwise have
                                  // fitted.
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          constraints.maxWidth * _arabicShare,
                                    ),
                                    child: Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: Text(
                                        nameArabic,
                                        style: type.arabicTitle,
                                        locale: const Locale('ar'),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                      ),
                      const SizedBox(height: WirdiMetrics.space2),
                      // On its own line under both names, so it has the width
                      // to say what it has to say however long the collection
                      // is called.
                      _Meta(listing: listing, items: items, colour: quiet),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Outside the row's own semantics rather than inside it: a menu that
        // opens the only way to copy a built-in should not be something a
        // screen reader has to find inside a button.
        _RowMenu(listing: listing),
      ],
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    await Navigator.pushNamed(
      context,
      Routes.player,
      arguments: PlayerArguments(collectionId: listing.id),
    );
    // The player is where completions and progress happen, so the row that
    // launched it is stale the moment it comes back.
    if (context.mounted) {
      ref.invalidate(collectionListingsProvider);
      ref.invalidate(streakViewProvider);
    }
  }
}

enum _RowAction { edit, duplicate, delete }

/// What can be done to a collection without opening it.
///
/// A built-in offers one thing: a copy you can edit. That is the path this
/// phase is built around — somebody wants al-Haddad's wird with two more
/// adhkar in it, or the morning adhkar at different counts — and it is here
/// rather than behind the player because it is a thing you do to a collection,
/// not a thing you do while reciting one.
class _RowMenu extends ConsumerWidget {
  const _RowMenu({required this.listing});

  final CollectionListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CollectionId id = listing.id;

    return PopupMenuButton<_RowAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'More',
      onSelected: (_RowAction action) => switch (action) {
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
  } on CollectionEditingError catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error.message)));
  }
}

/// The item count, and what state the collection is in today.
class _Meta extends StatelessWidget {
  const _Meta({
    required this.listing,
    required this.items,
    required this.colour,
  });

  final CollectionListing listing;
  final String items;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colour);

    // One paragraph rather than a row of boxes: the check is an inline glyph
    // in the sentence, so a long name or a large accessibility text scale
    // wraps the line instead of overflowing it.
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: items),
          if (listing.completedToday) ...<InlineSpan>[
            const TextSpan(text: ' · '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                Icons.check,
                size: WirdiMetrics.space4,
                color: colour,
              ),
            ),
            const TextSpan(text: ' Done today'),
          ] else if (listing.inProgress)
            const TextSpan(text: ' · Part-way through'),
        ],
      ),
      style: style,
    );
  }
}
