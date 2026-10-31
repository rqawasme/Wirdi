import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/playback_step.dart';
import '../domain/progress.dart';
import '../domain/repositories.dart';
import 'data_providers.dart';
import 'editing.dart';

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

/// The two halves of the Collections tab.
///
/// Two, because there are two kinds of thing in it: what the app ships, which
/// can be read, recited and copied, and what the user made, which can also be
/// changed. They were three stacked lists once — the user's collections, the
/// user's adhkar, and the built-ins — and a scroll down one list to find which
/// of the three you were in.
enum CollectionShelf {
  library('Library'),
  yours('Yours');

  const CollectionShelf(this.label);

  final String label;
}

/// Which shelf the Collections tab is showing, or null while nobody has
/// chosen one.
///
/// Null is not Library. Until a shelf has been picked the screen decides from
/// what there is — Yours, once the user has made something of their own, since
/// what somebody made is what they come back for — and a provider cannot see
/// that without reading the list itself.
///
/// A provider rather than the screen's own state so that the flows which make
/// a collection can turn the tab to Yours on their way out: a copy made from
/// the Library is not on the Library shelf, and coming back from the editor to
/// a list that does not show it reads as the copy having gone nowhere.
final class CollectionShelfController extends Notifier<CollectionShelf?> {
  @override
  CollectionShelf? build() => null;

  void select(CollectionShelf shelf) => state = shelf;
}

final NotifierProvider<CollectionShelfController, CollectionShelf?>
collectionShelfProvider =
    NotifierProvider<CollectionShelfController, CollectionShelf?>(
      CollectionShelfController.new,
      name: 'collectionShelf',
    );

/// The step the player would pick [CollectionId] up at, or null when it would
/// start from the top.
///
/// The same rule [collectionListingsProvider] applies for "Part-way through":
/// validated through [ResolvedCollection.resumableFrom], and a position at the
/// very beginning is not progress. The collection page uses it to say Resume
/// rather than Recite, and to mark the item it would resume at.
///
/// Auto-disposed, so a page opened again reads the progress again: a wird can
/// be recited from Home between two visits, and a page that still offered to
/// resume a wird finished since would be offering a place that is gone.
final FutureProviderFamily<PlaybackStep?, CollectionId> resumeStepProvider =
    FutureProvider.autoDispose.family<PlaybackStep?, CollectionId>((
      Ref ref,
      CollectionId id,
    ) async {
      final ResolvedCollection resolved = await ref.watch(
        resolvedCollectionProvider(id).future,
      );
      final WirdProgress? progress = resolved.resumableFrom(
        await ref.watch(userRepositoryProvider).progress(id),
      );
      if (progress == null) return null;
      if (progress.stepIndex == 0 && progress.currentCount == 0) return null;
      return resolved.steps[progress.stepIndex];
    }, name: 'resumeStep');
