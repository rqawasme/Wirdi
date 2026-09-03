import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/progress.dart';
import '../domain/repositories.dart';
import 'data_providers.dart';

/// A collection as the list shows it: the summary, plus the three things a row
/// says about it that the summary does not carry.
@immutable
final class CollectionListing {
  const CollectionListing({
    required this.summary,
    required this.itemCount,
    required this.stepCount,
    required this.completedToday,
    required this.inProgress,
  });

  final CollectionSummary summary;

  /// Items as the collection is written: a repeat block counts once, because
  /// that is how many things are in the collection. [stepCount] is the other
  /// number — the same block counted out pass by pass — and it is the one the
  /// player works through.
  final int itemCount;

  final int stepCount;

  /// Completed on the device's local day. A quiet mark on the row, not a
  /// celebration: this is a daily habit, and finishing it is the expected
  /// outcome rather than an achievement.
  final bool completedToday;

  /// There is a saved position part-way through, validated against the
  /// collection as it is now.
  ///
  /// A row sitting at the very beginning does not count: nobody has done
  /// anything yet, and showing it as part-way through would be a lie the user
  /// cannot clear.
  final bool inProgress;

  CollectionId get id => summary.id;

  String get name => summary.name;
}

/// Every collection, built-ins first, with its list state resolved.
///
/// Each collection is resolved to count its items and to validate its stored
/// progress — the same [ResolvedCollection.resumableFrom] check the player
/// makes, so the list cannot promise a resume the player will then discard.
/// Resolution is four indexed reads against a local database and a collection
/// list is a handful of rows, so this is a page load, not a scroll cost: a
/// surah item resolves to its metadata and never expands its ayahs.
final FutureProvider<List<CollectionListing>> collectionListingsProvider =
    FutureProvider<List<CollectionListing>>((Ref ref) async {
      final CollectionRepository collections = ref.watch(
        collectionRepositoryProvider,
      );
      final UserRepository user = ref.watch(userRepositoryProvider);

      // Built-ins first, then the user's own — the order all() already returns
      // them in, and not something to re-sort here.
      final List<CollectionSummary> summaries = await collections.all();

      final List<CollectionListing> listings = <CollectionListing>[];
      for (final CollectionSummary summary in summaries) {
        final ResolvedCollection resolved = await collections.resolve(
          summary.id,
        );
        final WirdProgress? progress = resolved.resumableFrom(
          await user.progress(summary.id),
        );
        listings.add(
          CollectionListing(
            summary: summary,
            itemCount: resolved.entries.length,
            stepCount: resolved.steps.length,
            completedToday: await user.isCompletedToday(summary.id),
            inProgress:
                progress != null &&
                (progress.stepIndex > 0 || progress.currentCount > 0),
          ),
        );
      }
      return listings;
    }, name: 'collectionListings');
