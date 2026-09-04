import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/commitment.dart';
import '../domain/playback_step.dart';
import '../domain/progress.dart';
import '../domain/repositories.dart';
import 'data_providers.dart';
import 'streak.dart';

/// One committed collection, as its tile on the home screen shows it.
///
/// The two counts are in **repetitions**, not entries. A collection of one
/// dhikr said a hundred times is a hundred, and the tile's stripe advances as
/// the user says it; counted as entries it would be one, and the stripe would
/// go from empty to full in a single tap. The word on the tile is still
/// "items" because that is what the count is of, from the reader's side: the
/// things they have to say.
@immutable
final class CommittedCollection {
  const CommittedCollection({
    required this.summary,
    required this.section,
    required this.days,
    required this.totalCount,
    required this.doneCount,
    required this.completedToday,
  });

  final CollectionSummary summary;

  final DailySection section;

  /// The days this comes round on. Every day for most of them; the tile says
  /// nothing about it either way, because a tile only ever shows today.
  final Weekdays days;

  /// Repetitions in the whole collection: every step's count, summed.
  final int totalCount;

  /// Repetitions done today. Zero once the day turns over — see
  /// [UserRepository.progress].
  final int doneCount;

  /// Finished today. The tile steps down tonally and drops its stripe; it does
  /// not celebrate.
  final bool completedToday;

  CollectionId get id => summary.id;

  String get name => summary.name;

  String? get nameArabic => summary.nameArabic;

  /// Part-way through, and not finished. A collection sitting at zero is not
  /// in progress — nobody has done anything yet.
  bool get inProgress => !completedToday && doneCount > 0;
}

/// The home screen: what was committed to, and the one line about the day.
@immutable
final class HomeView {
  const HomeView({
    required this.committed,
    required this.streak,
    required this.today,
  });

  /// Every commitment, in the order it was committed. Sections are cut out of
  /// this in [inSection]; the order inside one is the order here.
  final List<CommittedCollection> committed;

  /// Consecutive days up to today on which anything was completed.
  final int streak;

  /// The device's local day, so the greeting's date and the screen's idea of
  /// "today" come from the same clock.
  final DateTime today;

  /// The tiles of one section, in commit order. Empty when nothing is
  /// committed there — the section is then not rendered at all, rather than
  /// rendering a header over nothing.
  List<CommittedCollection> inSection(DailySection section) =>
      <CommittedCollection>[
        for (final CommittedCollection c in committed)
          if (c.section == section) c,
      ];

  /// Nothing committed anywhere. The greeting still shows; the sections are
  /// replaced by one empty state for the whole screen.
  bool get isEmpty => committed.isEmpty;

  int get finishedToday =>
      committed.where((CommittedCollection c) => c.completedToday).length;
}

/// The home screen's data: today's committed collections, resolved, plus the
/// streak.
///
/// Two things are filtered out before anything is resolved. A commitment whose
/// collection no longer exists is dropped rather than rendered as a gap —
/// `commitments` spans both databases and keeps rows for collections since
/// deleted, exactly as completions do. And a commitment that does not fall on
/// today's weekday is dropped too: the screen is what today contains, so a
/// Friday reading is not on it on a Tuesday, and not as a greyed-out tile
/// either.
final FutureProvider<HomeView> homeViewProvider = FutureProvider<HomeView>((
  Ref ref,
) async {
  final CollectionRepository collections = ref.watch(
    collectionRepositoryProvider,
  );
  final UserRepository user = ref.watch(userRepositoryProvider);

  final DateTime today = ref.watch(clockProvider)();
  final List<Commitment> commitments = await user.commitments();
  final Map<CollectionId, CollectionSummary> summaries =
      <CollectionId, CollectionSummary>{
        for (final CollectionSummary s in await collections.all()) s.id: s,
      };

  final List<CommittedCollection> committed = <CommittedCollection>[];
  for (final Commitment commitment in commitments) {
    if (!commitment.fallsOn(today)) continue;
    final CollectionSummary? summary = summaries[commitment.collectionId];
    if (summary == null) continue;

    final ResolvedCollection resolved = await collections.resolve(summary.id);
    // The same validation the player makes, so a tile cannot show progress
    // the player would then discard.
    final WirdProgress? progress = resolved.resumableFrom(
      await user.progress(summary.id),
    );

    committed.add(
      CommittedCollection(
        summary: summary,
        section: commitment.section,
        days: commitment.days,
        totalCount: _repetitions(resolved.steps),
        doneCount: _repetitionsDone(resolved.steps, progress),
        completedToday: await user.isCompletedToday(summary.id),
      ),
    );
  }

  return HomeView(
    committed: List<CommittedCollection>.unmodifiable(committed),
    streak: await user.currentStreak(),
    today: today,
  );
}, name: 'homeView');

/// Every commitment by collection, for the collections list's menu. Absent
/// means not committed.
///
/// Unfiltered, unlike [homeViewProvider]: the list is about what the app
/// contains, so a commitment for Fridays is still a commitment on a Tuesday
/// and the menu has to be able to say so.
final FutureProvider<Map<CollectionId, Commitment>> commitmentsProvider =
    FutureProvider<Map<CollectionId, Commitment>>((Ref ref) async {
      final List<Commitment> commitments = await ref
          .watch(userRepositoryProvider)
          .commitments();
      return <CollectionId, Commitment>{
        for (final Commitment c in commitments) c.collectionId: c,
      };
    }, name: 'commitments');

/// Committing and uncommitting, and the invalidation that follows.
///
/// A thin thing on purpose: unlike editing a collection, there is nothing here
/// that can be refused. Committing something twice is a move, uncommitting
/// something that was never committed is a no-op, and neither is a sentence
/// the user needs to read.
final Provider<HomeCommitments> homeCommitmentsProvider =
    Provider<HomeCommitments>(
      (Ref ref) => HomeCommitments(ref),
      name: 'homeCommitments',
    );

final class HomeCommitments {
  const HomeCommitments(this._ref);

  final Ref _ref;

  Future<void> commit(
    CollectionId id,
    DailySection section, {
    Weekdays days = Weekdays.everyDay,
  }) async {
    await _ref.read(userRepositoryProvider).commit(id, section, days: days);
    _invalidate();
  }

  Future<void> uncommit(CollectionId id) async {
    await _ref.read(userRepositoryProvider).uncommit(id);
    _invalidate();
  }

  void _invalidate() {
    _ref.invalidate(homeViewProvider);
    _ref.invalidate(commitmentsProvider);
  }
}

/// Every repetition in the collection: each step's own count, summed.
int _repetitions(List<PlaybackStep> steps) {
  int total = 0;
  for (final PlaybackStep step in steps) {
    total += step.count;
  }
  return total;
}

/// Repetitions behind [progress]: every step before the current one in full,
/// plus how far into the current one the user has counted.
int _repetitionsDone(List<PlaybackStep> steps, WirdProgress? progress) {
  if (progress == null) return 0;
  int done = 0;
  for (final PlaybackStep step in steps) {
    if (step.index >= progress.stepIndex) break;
    done += step.count;
  }
  return done + progress.currentCount;
}
