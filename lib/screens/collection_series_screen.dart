import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/commitment.dart';
import '../providers/collections.dart';
import '../providers/home.dart';
import '../theme/theme.dart';
import '../widgets/banded_row.dart';
import '../widgets/collection_row.dart';
import '../widgets/collection_series_row.dart';
import '../widgets/empty_state.dart';
import '../widgets/failure_screen.dart';
import '../widgets/voussoir_stripe.dart';
import 'collection_actions.dart';

/// The parts of a work recited in parts, in the order they are said.
///
/// What the Library's one row for Dala'il al-Khayrat opens: the opening and
/// the intention, the seven daily parts, the closing and the completion, each
/// an ordinary row that opens that part's own page. Nothing here is about
/// today — no part is marked out for being Tuesday's — because this tab is
/// about what the app contains, and what today holds is Home's.
///
/// Read from the same listings the Library is, by the name the parts share,
/// rather than from a query of its own: the rows need the same counts and the
/// same state the Library's rows have, and the listings already hold them.
class CollectionSeriesScreen extends ConsumerWidget {
  const CollectionSeriesScreen({super.key, required this.name});

  /// The name every part's series carries.
  final String name;

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
      AsyncData(:final List<CollectionListing> value) => _scaffold(
        context,
        ref,
        <CollectionListing>[
          for (final CollectionListing l in value)
            if (l.summary.series?.name == name) l,
        ],
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }

  Widget _scaffold(
    BuildContext context,
    WidgetRef ref,
    List<CollectionListing> parts,
  ) {
    final Map<CollectionId, Commitment> commitments =
        ref.watch(commitmentsProvider).value ??
        const <CollectionId, Commitment>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(VoussoirStripe.ruleHeight),
          child: VoussoirStripe.rule(),
        ),
      ),
      // Only reachable if a content update took the series away while its
      // page was open.
      body: parts.isEmpty
          ? const EmptyState(title: 'Nothing in this series')
          : ListView(
              // Plus the system's own inset, so the last part clears
              // Android's navigation bar — see
              // [WirdiMetrics.withSystemBottom].
              padding: WirdiMetrics.withSystemBottom(
                context,
                const EdgeInsets.only(bottom: WirdiMetrics.space6),
              ),
              children: <Widget>[
                _Header(series: parts.first.summary.series!, parts: parts),
                for (int i = 0; i < parts.length; i++)
                  BandedRow(
                    index: i,
                    child: CollectionRow(
                      listing: parts[i],
                      title: partName(parts[i].summary.series!, parts[i].name),
                      commitment: commitments[parts[i].id],
                      onTap: () => openCollection(context, ref, parts[i].id),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// The series' Arabic name, who it is by, and how many parts.
///
/// The English name is the app bar's, and is not said twice — the same as a
/// collection's own page.
class _Header extends StatelessWidget {
  const _Header({required this.series, required this.parts});

  final CollectionSeries series;
  final List<CollectionListing> parts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final Color quiet = theme.colorScheme.onSurfaceVariant;
    // Named only when every part agrees: a series is one work, and a part by
    // somebody else would make a single attribution untrue.
    final Set<String?> authors = <String?>{
      for (final CollectionListing p in parts) p.summary.author,
    };
    final String? author = authors.length == 1 ? authors.single : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.space4,
        WirdiMetrics.space4,
        WirdiMetrics.space4,
        WirdiMetrics.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              series.nameArabic,
              style: type.arabicTitle,
              locale: const Locale('ar'),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: WirdiMetrics.space2),
          if (author != null && author.isNotEmpty) ...<Widget>[
            Text(
              author,
              style: theme.textTheme.bodySmall?.copyWith(color: quiet),
            ),
            const SizedBox(height: WirdiMetrics.space2),
          ],
          Text(
            '${parts.length} parts, in the order they are said',
            style: theme.textTheme.bodySmall?.copyWith(color: quiet),
          ),
        ],
      ),
    );
  }
}
