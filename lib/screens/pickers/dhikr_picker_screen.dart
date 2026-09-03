import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collections/picked_item.dart';
import '../../domain/collection.dart';
import '../../domain/content.dart';
import '../../domain/content_ref.dart';
import '../../providers/editing.dart';
import '../../theme/theme.dart';
import '../../widgets/collection_dialogs.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/failure_screen.dart';
import 'picker_scaffold.dart';

/// Pick a dhikr, by browsing the built-in collection it belongs to.
///
/// There is no tagging and no search in this content build, so a flat list of
/// every dhikr would be several hundred rows of Arabic with nothing to sort or
/// filter them by — unusable, and unusable in a way no amount of styling
/// fixes. The collections are the structure that already exists: somebody
/// looking for the morning tasbih knows which wird it is from, and that is the
/// question this screen asks instead.
///
/// Pops with a one-item `List<PickedItem>`.
class DhikrPickerScreen extends ConsumerWidget {
  const DhikrPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CollectionSummary>> builtins = ref.watch(
      builtinCollectionsProvider,
    );

    return PickerScaffold(
      title: 'Add a dhikr',
      body: switch (builtins) {
        AsyncError(:final Object error, :final StackTrace stackTrace) =>
          FailureScreen(
            title: 'Could not read the collections',
            error: error,
            stackTrace: stackTrace,
          ),
        AsyncData(:final List<CollectionSummary> value) when value.isEmpty =>
          const EmptyState(
            title: 'No collections to browse',
            body:
                'Adhkar are picked out of the collections they come from, '
                'and this content build has none.',
          ),
        AsyncData(:final List<CollectionSummary> value) => ListView.builder(
          itemCount: value.length,
          itemBuilder: (BuildContext context, int index) =>
              _SourceRow(summary: value[index]),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.summary});

  /// The most of a row the Arabic name may take before it starts wrapping.
  /// The same share the collections list gives it, for the same reason.
  static const double _arabicShare = 0.45;

  final CollectionSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final String? nameArabic = summary.nameArabic;
    final String? author = summary.author;

    return Semantics(
      container: true,
      button: true,
      label: author == null ? summary.name : '${summary.name}, $author',
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WirdiMetrics.space4,
            vertical: WirdiMetrics.space4,
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) =>
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              summary.name,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (nameArabic != null) ...<Widget>[
                            const SizedBox(width: WirdiMetrics.space4),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * _arabicShare,
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
                if (author != null) ...<Widget>[
                  const SizedBox(height: WirdiMetrics.space2),
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
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final List<PickedItem>? picked = await Navigator.push<List<PickedItem>>(
      context,
      MaterialPageRoute<List<PickedItem>>(
        builder: (BuildContext context) => _DhikrListScreen(summary: summary),
      ),
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;
    Navigator.pop(context, picked);
  }
}

/// Every dhikr in one collection, repeat blocks flattened.
///
/// A block is how that collection recites them; it says nothing about the
/// dhikr itself, and somebody looking for the words does not want the
/// structure of the wird they came from in the way.
class _DhikrListScreen extends ConsumerWidget {
  const _DhikrListScreen({required this.summary});

  final CollectionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ResolvedCollection> resolved = ref.watch(
      resolvedCollectionProvider(summary.id),
    );

    return PickerScaffold(
      title: summary.name,
      body: switch (resolved) {
        AsyncError(:final Object error, :final StackTrace stackTrace) =>
          FailureScreen(
            title: 'Could not open ${summary.name}',
            error: error,
            stackTrace: stackTrace,
          ),
        AsyncData(:final ResolvedCollection value) => _list(context, value),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _list(BuildContext context, ResolvedCollection collection) {
    final List<DhikrItem> adhkar = <DhikrItem>[
      for (final CollectionEntry entry in collection.entries)
        ...switch (entry) {
          DhikrItem() => <DhikrItem>[entry],
          CollectionItemEntry() => const <DhikrItem>[],
          RepeatBlock(entries: final List<CollectionItemEntry> members) =>
            members.whereType<DhikrItem>(),
        },
    ];

    if (adhkar.isEmpty) {
      return EmptyState(
        title: 'No adhkar here',
        body: '${summary.name} is made of Quran, not of adhkar.',
      );
    }

    return ListView.builder(
      itemCount: adhkar.length,
      itemBuilder: (BuildContext context, int index) =>
          _DhikrRow(item: adhkar[index]),
    );
  }
}

class _DhikrRow extends StatelessWidget {
  const _DhikrRow({required this.item});

  final DhikrItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final Dhikr dhikr = item.dhikr;

    return Semantics(
      container: true,
      button: true,
      label: 'Dhikr, ${dhikr.translation}',
      child: InkWell(
        onTap: () => _pick(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WirdiMetrics.space4,
            vertical: WirdiMetrics.space3,
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    dhikr.textArabic,
                    style: type.arabicTitle,
                    locale: const Locale('ar'),
                    // A row, not a reading. The whole text is on the step the
                    // player shows; here it is only enough to recognise.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: WirdiMetrics.space2),
                Text(
                  dhikr.translation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final Dhikr dhikr = item.dhikr;
    final ItemOptions? options = await showItemOptions(
      context,
      title: 'Add this dhikr',
      subtitle: dhikr.translation,
      // What the dhikr says it is said, unless this collection said otherwise
      // — which is the number somebody browsing this list has in front of them.
      naturalCount: dhikr.defaultCount,
    );
    if (options == null || !context.mounted) return;
    Navigator.pop(context, <PickedItem>[
      PickedItem(
        ref: ContentRef.dhikr(dhikr.id),
        count: options.count,
        note: options.note,
      ),
    ]);
  }
}
