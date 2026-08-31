import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/collections.dart';
import '../routes.dart';
import '../theme/theme.dart';
import '../widgets/failure_screen.dart';
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

class _CollectionList extends StatelessWidget {
  const _CollectionList({required this.listings});

  final List<CollectionListing> listings;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      // Only reachable if content.db shipped without any built-ins, which the
      // content build would have to have gone wrong for.
      return const _Empty();
    }
    return ListView.builder(
      itemCount: listings.length,
      itemBuilder: (BuildContext context, int index) =>
          _CollectionRow(listing: listings[index]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WirdiMetrics.space6),
        child: Text(
          'No collections yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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

    return Semantics(
      container: true,
      button: true,
      label: '${listing.name}, $items, $state',
      child: InkWell(
        onTap: () => _open(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WirdiMetrics.space4,
            vertical: WirdiMetrics.space4,
          ),
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(listing.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: WirdiMetrics.space2),
                      _Meta(listing: listing, items: items, colour: quiet),
                    ],
                  ),
                ),
                if (nameArabic != null) ...<Widget>[
                  const SizedBox(width: WirdiMetrics.space4),
                  Flexible(
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
        ),
      ),
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
    if (context.mounted) ref.invalidate(collectionListingsProvider);
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

    return Row(
      children: <Widget>[
        Text(items, style: style),
        if (listing.completedToday) ...<Widget>[
          Text(' · ', style: style),
          Icon(Icons.check, size: WirdiMetrics.space4, color: colour),
          const SizedBox(width: WirdiMetrics.space1),
          Text('Done today', style: style),
        ] else if (listing.inProgress) ...<Widget>[
          Text(' · Part-way through', style: style),
        ],
      ],
    );
  }
}
