import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/content_ref.dart';
import '../providers/editing.dart';
import '../theme/theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/failure_screen.dart';
import '../widgets/item_sheet.dart';
import '../widgets/plate.dart';
import '../widgets/voussoir_stripe.dart';
import 'collection_edit_screen.dart' show EntryLine;

/// What is in a collection, in the order it is recited.
///
/// Read-only, and the first thing a row in the collections list opens. The
/// player used to be — which meant the only way to find out what a wird
/// contained was to start reciting it, and backing out of a wird to see what
/// was in it leaves a progress row behind. Opening is now looking; reciting is
/// still the button beside it in the list.
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
      AsyncData(:final ResolvedCollection value) => _scaffold(context, value),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }

  Widget _scaffold(BuildContext context, ResolvedCollection collection) {
    final CollectionSummary summary = collection.collection;
    final List<CollectionEntry> entries = collection.entries;

    return Scaffold(
      appBar: AppBar(
        title: Text(summary.name),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(VoussoirStripe.ruleHeight),
          child: VoussoirStripe.rule(),
        ),
      ),
      body: entries.isEmpty
          ? _empty(summary)
          : ListView(
              // Plus the system's own inset, so the last entry clears
              // Android's navigation bar — see
              // [WirdiMetrics.withSystemBottom].
              padding: WirdiMetrics.withSystemBottom(
                context,
                const EdgeInsets.only(bottom: WirdiMetrics.space6),
              ),
              children: <Widget>[
                _Header(summary: summary),
                for (int i = 0; i < entries.length; i++) ...<Widget>[
                  if (i > 0) const _Hairline(),
                  _EntryRow(entry: entries[i]),
                ],
                _Unresolved(refs: collection.unresolved),
              ],
            ),
    );
  }

  Widget _empty(CollectionSummary summary) {
    // A built-in is never empty in practice and has no editor to send anybody
    // to; a collection of the user's own is empty exactly until they fill it.
    return EmptyState(
      title: 'Nothing in this collection yet',
      body: summary.isBuiltin
          ? 'This collection came with nothing in it.'
          : 'Open it for editing to add a surah, an ayah or a dhikr.',
    );
  }
}

/// The collection's own preamble: what it is for, and who wrote it.
///
/// Scrolls with the list rather than pinning above it. It is the collection's
/// description, not chrome, and prose that stays on screen while you scroll
/// past forty items is prose in the way.
///
/// Unclipped, unlike the two lines the collections list gives it. This is the
/// one place there is room to read the whole thing, which is the reason the
/// screen shows it at all.
class _Header extends StatelessWidget {
  const _Header({required this.summary});

  final CollectionSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? description = summary.description;
    final String? author = summary.author;

    final bool hasDescription = description != null && description.isNotEmpty;
    final bool hasAuthor = author != null && author.isNotEmpty;
    if (!hasDescription && !hasAuthor) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WirdiMetrics.space4,
            WirdiMetrics.space4,
            WirdiMetrics.space4,
            WirdiMetrics.space4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (hasDescription)
                Text(description, style: theme.textTheme.bodyMedium),
              if (hasAuthor) ...<Widget>[
                if (hasDescription) const SizedBox(height: WirdiMetrics.space2),
                // Attribution belongs on a collection's own page. It is
                // rendered in one other place in the app — the rows of the
                // by-collection picker — and nowhere a reader would look for it.
                Text(
                  author,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
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
  const _EntryRow({required this.entry});

  final CollectionEntry entry;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      final CollectionItemEntry item => _ItemRow(item: item),
      final RepeatBlock block => _BlockRow(block: block),
    };
  }
}

/// One item, and the way into its text.
///
/// Unlike the editor's row, which is the same [EntryLine] carrying a drag
/// handle, a remove button and sometimes a checkbox, this one is a button and
/// nothing else. Tapping it opens the item in full.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final CollectionItemEntry item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      container: true,
      button: true,
      label: 'Open this item',
      child: InkWell(
        onTap: () => showItemSheet(context, item: item),
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
              Expanded(child: EntryLine(item: item)),
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
  const _BlockRow({required this.block});

  final RepeatBlock block;

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
              _ItemRow(item: item),
            const SizedBox(height: WirdiMetrics.space1),
          ],
        ),
      ),
    );
  }
}

/// Items whose content row was not found, and were therefore dropped.
///
/// A user collection can end up here when a content update removes a dhikr it
/// had in it. This screen is the only place in the app that can say so — the
/// player skips them silently, because a counter is no place to explain a
/// content migration — so it says it plainly and quietly, as a fact about the
/// library rather than as anybody's mistake.
class _Unresolved extends StatelessWidget {
  const _Unresolved({required this.refs});

  final List<ContentRef> refs;

  @override
  Widget build(BuildContext context) {
    if (refs.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final String count = refs.length == 1
        ? 'One item is'
        : '${refs.length} items are';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.space4,
        WirdiMetrics.space4,
        WirdiMetrics.space4,
        0,
      ),
      child: Text(
        '$count no longer in the content library, and '
        '${refs.length == 1 ? 'is' : 'are'} not recited.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
