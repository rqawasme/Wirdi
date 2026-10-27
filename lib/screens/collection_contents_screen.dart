import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/commitment.dart';
import '../domain/item_ref.dart';
import '../domain/playback_step.dart';
import '../providers/collections.dart';
import '../providers/editing.dart';
import '../providers/home.dart';
import '../theme/theme.dart';
import '../widgets/collection_dialogs.dart';
import '../widgets/collection_row.dart';
import '../widgets/empty_state.dart';
import '../widgets/failure_screen.dart';
import '../widgets/item_sheet.dart';
import '../widgets/plate.dart';
import '../widgets/voussoir_stripe.dart';
import 'collection_actions.dart';
import 'collection_edit_screen.dart' show EntryLine;

/// A collection's own page: what it is, what can be done with it, and what is
/// in it, in the order it is recited.
///
/// The first thing a row in the collections list opens, and now the only
/// thing. The row used to carry four icon buttons — contents, recite, commit
/// and a menu — and nobody could say which was which without long-pressing for
/// a tooltip. They are here instead, as buttons with their names on them:
/// Recite, Add to Home, and Make a copy for a built-in or Edit for one of the
/// user's own.
///
/// A [CollectionId] and not a [UserCollectionId]: a built-in cannot be edited,
/// but it can certainly be read, and reading one is the commonest reason to
/// come here at all.
class CollectionContentsScreen extends ConsumerWidget {
  const CollectionContentsScreen({super.key, required this.collectionId});

  final CollectionId collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ResolvedCollection> resolved = ref.watch(
      resolvedCollectionProvider(collectionId),
    );

    return switch (resolved) {
      AsyncError(:final Object error, :final StackTrace stackTrace) =>
        FailureScreen(
          title: 'Could not open this collection',
          error: error,
          stackTrace: stackTrace,
        ),
      AsyncData(:final ResolvedCollection value) => _scaffold(
        context,
        ref,
        value,
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }

  Widget _scaffold(
    BuildContext context,
    WidgetRef ref,
    ResolvedCollection collection,
  ) {
    final CollectionSummary summary = collection.collection;
    final List<CollectionEntry> entries = collection.entries;
    final PlaybackStep? resume = ref
        .watch(resumeStepProvider(collectionId))
        .value;
    final Commitment? commitment = ref
        .watch(commitmentsProvider)
        .value?[collectionId];
    final bool completedToday =
        ref
            .watch(collectionListingsProvider)
            .value
            ?.any(
              (CollectionListing l) => l.id == collectionId && l.completedToday,
            ) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: Text(summary.name),
        actions: <Widget>[
          if (collectionId case final UserCollectionId id)
            _PageMenu(id: id, name: summary.name),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(VoussoirStripe.ruleHeight),
          child: VoussoirStripe.rule(),
        ),
      ),
      body: ListView(
        // Plus the system's own inset, so the last entry clears Android's
        // navigation bar — see [WirdiMetrics.withSystemBottom].
        padding: WirdiMetrics.withSystemBottom(
          context,
          const EdgeInsets.only(bottom: WirdiMetrics.space6),
        ),
        children: <Widget>[
          _Header(
            summary: summary,
            items: entries.length,
            completedToday: completedToday,
          ),
          _Actions(
            id: collectionId,
            summary: summary,
            entries: entries,
            resume: resume,
            commitment: commitment,
          ),
          if (entries.isEmpty)
            _empty(summary)
          else ...<Widget>[
            const _ContentsLabel(),
            for (int i = 0; i < entries.length; i++) ...<Widget>[
              if (i > 0) const _Hairline(),
              _EntryRow(entry: entries[i], upNext: resume?.entryId),
            ],
          ],
          _Unresolved(refs: collection.unresolved),
        ],
      ),
    );
  }

  Widget _empty(CollectionSummary summary) {
    // A built-in is never empty in practice and has no editor to send anybody
    // to; a collection of the user's own is empty exactly until they fill it.
    return Padding(
      padding: const EdgeInsets.only(top: WirdiMetrics.space4),
      child: EmptyState(
        title: 'Nothing in this collection yet',
        body: summary.isBuiltin
            ? 'This collection came with nothing in it.'
            : 'Edit it to add a surah, an ayah or a dhikr.',
      ),
    );
  }
}

/// The collection's own preamble: its Arabic name, who it is by, what it is
/// for, and how much is in it.
///
/// Scrolls with the list rather than pinning above it. It is the collection's
/// description, not chrome, and prose that stays on screen while you scroll
/// past forty items is prose in the way.
///
/// Unclipped. The collections list no longer shows a description at all, so
/// this is the one place to read it, and the reason the page shows it whole.
/// The English name is the app bar's, and is not said twice.
class _Header extends StatelessWidget {
  const _Header({
    required this.summary,
    required this.items,
    required this.completedToday,
  });

  final CollectionSummary summary;
  final int items;
  final bool completedToday;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final Color quiet = theme.colorScheme.onSurfaceVariant;
    final String? nameArabic = summary.nameArabic;
    final String? description = summary.description;
    final String? author = summary.author;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.space4,
        WirdiMetrics.space4,
        WirdiMetrics.space4,
        WirdiMetrics.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (nameArabic != null && nameArabic.isNotEmpty) ...<Widget>[
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                nameArabic,
                style: type.arabicTitle,
                locale: const Locale('ar'),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(height: WirdiMetrics.space2),
          ],
          // Attribution belongs on a collection's own page. It is rendered in
          // one other place in the app — the rows of the by-collection picker
          // — and nowhere a reader would look for it.
          if (author != null && author.isNotEmpty) ...<Widget>[
            Text(
              author,
              style: theme.textTheme.bodySmall?.copyWith(color: quiet),
            ),
            const SizedBox(height: WirdiMetrics.space2),
          ],
          if (description != null && description.isNotEmpty) ...<Widget>[
            Text(description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: WirdiMetrics.space2),
          ],
          CollectionMeta(
            items: itemCountLabel(items),
            completedToday: completedToday,
            // The Resume button below says so, in more words.
            inProgress: false,
          ),
        ],
      ),
    );
  }
}

/// What can be done with the collection, each with its name on it.
///
/// Recite first and widest, because it is what the page is mostly opened for.
/// Under it, whether the collection is on Home — as a sentence when it is, and
/// as a button when it is not — and the one change that applies to it: a copy
/// of a built-in, or the editor for one of the user's own.
class _Actions extends ConsumerWidget {
  const _Actions({
    required this.id,
    required this.summary,
    required this.entries,
    required this.resume,
    required this.commitment,
  });

  final CollectionId id;
  final CollectionSummary summary;
  final List<CollectionEntry> entries;
  final PlaybackStep? resume;
  final Commitment? commitment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final CollectionId id = this.id;
    final Commitment? commitment = this.commitment;
    final PlaybackStep? resume = this.resume;
    final int? resumeAt = resume == null
        ? null
        : _entryNumber(entries, resume.entryId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.space4,
        WirdiMetrics.space2,
        WirdiMetrics.space4,
        WirdiMetrics.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FilledButton.icon(
            // Nothing to recite in an empty collection, and a player opened on
            // nothing is a screen with nothing to say.
            onPressed: entries.isEmpty
                ? null
                : () => reciteCollection(context, ref, id),
            icon: const Icon(Icons.play_arrow),
            label: Text(
              resumeAt == null
                  ? 'Recite'
                  : 'Resume at item $resumeAt of ${entries.length}',
            ),
          ),
          if (commitment != null) ...<Widget>[
            const SizedBox(height: WirdiMetrics.space2),
            _OnHome(
              commitment: commitment,
              onChange: () => commitCollection(
                context,
                ref,
                id: id,
                name: summary.name,
                current: commitment,
              ),
              onRemove: () => ref.read(homeCommitmentsProvider).uncommit(id),
            ),
          ],
          const SizedBox(height: WirdiMetrics.space2),
          Row(
            children: <Widget>[
              if (commitment == null) ...<Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => commitCollection(
                      context,
                      ref,
                      id: id,
                      name: summary.name,
                    ),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Add to Home'),
                  ),
                ),
                const SizedBox(width: WirdiMetrics.space2),
              ],
              Expanded(
                child: switch (id) {
                  UserCollectionId() => OutlinedButton.icon(
                    onPressed: () => editCollection(context, id),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  BuiltinCollectionId() => OutlinedButton.icon(
                    onPressed: () => duplicateCollectionFlow(
                      context,
                      ref,
                      source: id,
                      name: summary.name,
                    ),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Make a copy'),
                  ),
                },
              ),
            ],
          ),
          if (summary.isBuiltin) ...<Widget>[
            const SizedBox(height: WirdiMetrics.space2),
            // Said once, here, because it is the question a built-in with no
            // Edit button raises: why not, and what to do instead.
            Text(
              'Built-in collections stay as they were written. Make a copy to '
              'add to it or take things out.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Which item, counted the way the list counts them, holds [entryId]: a
  /// repeat block is one item however many are inside it.
  static int? _entryNumber(List<CollectionEntry> entries, String entryId) {
    for (int i = 0; i < entries.length; i++) {
      final bool here = switch (entries[i]) {
        final CollectionItemEntry item => item.entryId == entryId,
        final RepeatBlock block => block.entries.any(
          (CollectionItemEntry item) => item.entryId == entryId,
        ),
      };
      if (here) return i + 1;
    }
    return null;
  }
}

/// Where on Home the collection is, and the two ways to change that.
///
/// A plate of brick's own container colour, because this is the one fact on
/// the page the user set rather than the app — and the same fact the list row
/// says in brick. Change and Remove sit on the plate, under what they change,
/// rather than as two more buttons in the row beneath it.
class _OnHome extends StatelessWidget {
  const _OnHome({
    required this.commitment,
    required this.onChange,
    required this.onRemove,
  });

  final Commitment commitment;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final ReminderTime? reminder = commitment.reminder;
    final String when = <String>[
      describeDays(commitment.days),
      if (reminder != null)
        'Reminder at ${formatReminderTime(context, reminder)}.',
    ].join(' ');
    // Not brick: brick on its own container is too faint to read in the dark
    // theme.
    final ButtonStyle onPlate = TextButton.styleFrom(
      foregroundColor: scheme.onPrimaryContainer,
    );

    return Material(
      color: scheme.primaryContainer,
      borderRadius: WirdiMetrics.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          WirdiMetrics.space3,
          WirdiMetrics.space3,
          WirdiMetrics.space2,
          WirdiMetrics.space1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.home, color: scheme.onPrimaryContainer),
                const SizedBox(width: WirdiMetrics.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        commitment.section == DailySection.today
                            ? 'On your Home'
                            : 'On your Home · ${commitment.section.label}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        when,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // An overflow bar, so a large text scale stacks the two rather
            // than squeezing either.
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  style: onPlate,
                  onPressed: onRemove,
                  child: const Text('Remove from Home'),
                ),
                TextButton(
                  style: onPlate,
                  onPressed: onChange,
                  child: const Text('Change'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _PageAction { duplicate, delete }

/// What a collection of the user's own can have done to it beyond the buttons
/// on the page: a copy, and deleting it.
///
/// Behind a menu because neither is common, and deleting is the one action on
/// the page that cannot be taken back.
class _PageMenu extends ConsumerWidget {
  const _PageMenu({required this.id, required this.name});

  final UserCollectionId id;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_PageAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'More',
      onSelected: (_PageAction action) async {
        switch (action) {
          case _PageAction.duplicate:
            await duplicateCollectionFlow(context, ref, source: id, name: name);
          case _PageAction.delete:
            final bool deleted = await deleteCollection(
              context,
              ref,
              id: id,
              name: name,
            );
            // The page is about something that is not there any more.
            if (deleted && context.mounted) Navigator.pop(context);
        }
      },
      itemBuilder: (BuildContext context) =>
          const <PopupMenuEntry<_PageAction>>[
            PopupMenuItem<_PageAction>(
              value: _PageAction.duplicate,
              child: Text('Make a copy'),
            ),
            PopupMenuItem<_PageAction>(
              value: _PageAction.delete,
              child: Text('Delete'),
            ),
          ],
    );
  }
}

/// The heading over the items, and the rule under it.
class _ContentsLabel extends StatelessWidget {
  const _ContentsLabel();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WirdiMetrics.space4,
            WirdiMetrics.space2,
            WirdiMetrics.space4,
            WirdiMetrics.space2,
          ),
          child: Semantics(
            header: true,
            child: Text(
              'In the order it is recited',
              style: type.caption.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const _Hairline(),
      ],
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

/// One top-level entry: a single item, or a whole repeat block.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.upNext});

  final CollectionEntry entry;

  /// The entry the player would resume at, or null.
  final String? upNext;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      final CollectionItemEntry item => _ItemRow(
        item: item,
        upNext: item.entryId == upNext,
      ),
      final RepeatBlock block => _BlockRow(block: block, upNext: upNext),
    };
  }
}

/// One item, and the way into its text.
///
/// Unlike the editor's row, which is the same [EntryLine] carrying a drag
/// handle, a remove button and sometimes a checkbox, this one is a button and
/// nothing else. Tapping it opens the item in full.
///
/// The item the player would resume at says so, under its line and with a
/// length of brick down its leading edge: the same mark the bottom bar puts
/// over the tab you are on, turned on its side.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, this.upNext = false});

  final CollectionItemEntry item;

  final bool upNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      container: true,
      button: true,
      label: upNext ? 'Open this item, up next' : 'Open this item',
      child: InkWell(
        onTap: () => showItemSheet(context, item: item),
        child: Container(
          decoration: upNext
              ? BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(
                      color: theme.colorScheme.primary,
                      width: VoussoirStripe.ruleHeight,
                    ),
                  ),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              WirdiMetrics.space4,
              WirdiMetrics.space3,
              WirdiMetrics.space2,
              WirdiMetrics.space3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      EntryLine(item: item),
                      if (upNext)
                        Text(
                          'Up next',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (item.count > 1) ...<Widget>[
                  const SizedBox(width: WirdiMetrics.space3),
                  Plate(label: '×${item.count}'),
                ],
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A repeat block: its items, and how many times over.
///
/// Drawn as one bordered group, the way the editor draws it — the block's
/// contiguity made visible. Its header is not a target; each item inside it is,
/// because the words of a dhikr do not change for being said three times.
///
/// A read-only sibling of the editor's block row rather than a shared widget
/// with the editing stripped out by flags: that version carries a drag handle,
/// a selection checkbox, per-item remove buttons and an Ungroup action, and
/// four booleans saying "not editing" would be harder to read than this.
class _BlockRow extends StatelessWidget {
  const _BlockRow({required this.block, required this.upNext});

  final RepeatBlock block;

  /// The entry the player would resume at, or null; it may be one of these.
  final String? upNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
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
                WirdiMetrics.space3,
                0,
              ),
              child: Text(
                'Repeated ${block.repeatCount} times',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final CollectionItemEntry item in block.entries)
              _ItemRow(item: item, upNext: item.entryId == upNext),
            const SizedBox(height: WirdiMetrics.space1),
          ],
        ),
      ),
    );
  }
}

/// Items whose row was not found, and were therefore dropped.
///
/// A user collection can end up here when a content update removes a dhikr it
/// had in it. This screen is the only place in the app that can say so — the
/// player skips them silently, because a counter is no place to explain a
/// content migration — so it says it plainly and quietly, as a fact about the
/// library rather than as anybody's mistake.
///
/// Split by kind, because only one of the two sentences is true of each. An
/// item naming a dhikr the user wrote is not something a content update did:
/// deleting such a dhikr takes its items with it, in the same transaction, so
/// this should be unreachable — and if a restored backup ever does produce one,
/// blaming the content library for it would be the app misinforming somebody
/// about their own data.
class _Unresolved extends StatelessWidget {
  const _Unresolved({required this.refs});

  final List<ItemRef> refs;

  @override
  Widget build(BuildContext context) {
    if (refs.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final int content = refs.whereType<ContentRef>().length;
    final int written = refs.length - content;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.space4,
        WirdiMetrics.space4,
        WirdiMetrics.space4,
        0,
      ),
      child: Text(
        <String>[
          if (content > 0)
            '${content == 1 ? 'One item is' : '$content items are'} no longer '
                'in the content library, and '
                '${content == 1 ? 'is' : 'are'} not recited.',
          if (written > 0)
            '${written == 1 ? 'One dhikr' : '$written adhkar'} you wrote '
                '${written == 1 ? 'is' : 'are'} no longer here, and '
                '${written == 1 ? 'is' : 'are'} not recited.',
        ].join(' '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
