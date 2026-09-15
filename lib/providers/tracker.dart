import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
// The type of `FutureProvider.family`. It lives in riverpod's `misc.dart`
// rather than its main export, and is named here so the provider below can
// carry a written-out type like every other provider in this directory.
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../collections/streak_calendar.dart';
import '../domain/collection_id.dart';
import '../domain/commitment.dart';
import '../domain/date_key.dart';
import '../domain/repositories.dart';
import '../domain/tracker_stats.dart';
import 'collections.dart';
import 'data_providers.dart';
import 'home.dart';
import 'streak.dart';

/// What the tracker is showing.
///
/// Two cases, and the sealed type is what makes the screen's switch exhaustive
/// rather than a nullable id everybody has to remember to check.
@immutable
sealed class TrackerScope {
  const TrackerScope();

  /// The collection this scope is about, or null for [EverythingScope].
  CollectionId? get id;
}

/// Every collection at once: the days the app was used at all.
@immutable
final class EverythingScope extends TrackerScope {
  const EverythingScope();

  @override
  CollectionId? get id => null;

  @override
  bool operator ==(Object other) => other is EverythingScope;

  @override
  int get hashCode => (EverythingScope).hashCode;

  @override
  String toString() => 'EverythingScope()';
}

/// One collection, reckoned against the days it comes round on.
@immutable
final class CollectionScope extends TrackerScope {
  const CollectionScope(this.collectionId);

  final CollectionId collectionId;

  @override
  CollectionId? get id => collectionId;

  @override
  bool operator ==(Object other) =>
      other is CollectionScope && other.collectionId == collectionId;

  @override
  int get hashCode => Object.hash(CollectionScope, collectionId);

  @override
  String toString() => 'CollectionScope(${collectionId.canonical})';
}

/// One entry of the scope picker.
@immutable
final class TrackerScopeOption {
  const TrackerScopeOption({
    required this.scope,
    required this.label,
    required this.days,
  });

  final TrackerScope scope;

  final String label;

  /// The days it comes round on, or null when it is not committed — and for
  /// "Everything", which is not a thing that can be owed.
  final Weekdays? days;
}

/// A scope's whole history, read once.
@immutable
final class TrackerHistory {
  const TrackerHistory({
    required this.scope,
    required this.due,
    required this.options,
  });

  final TrackerScope scope;

  final DueDays due;

  /// Everything the picker can offer, "Everything" first.
  final List<TrackerScopeOption> options;

  /// Whether there is anything to switch to. With one option the picker is a
  /// control that cannot do anything, so the screen does not draw it.
  bool get hasChoice => options.length > 1;
}

/// Which scope the tracker is showing. Global by default: the app-wide run is
/// the question most people open this tab with.
final class TrackerScopeController extends Notifier<TrackerScope> {
  @override
  TrackerScope build() => const EverythingScope();

  void select(TrackerScope scope) {
    if (scope == state) return;
    state = scope;
    // Back to this month. The month being browsed belongs to the scope that
    // was being read, and carrying it across means switching collections can
    // land the reader in a month that collection has nothing in.
    ref.read(browsedMonthProvider.notifier).reset();
  }
}

final NotifierProvider<TrackerScopeController, TrackerScope>
trackerScopeProvider = NotifierProvider<TrackerScopeController, TrackerScope>(
  TrackerScopeController.new,
  name: 'trackerScope',
);

/// The month the calendar is showing.
///
/// Always the first of a month, so that two [DateTime]s in the same month
/// compare equal and paging is idempotent.
final class BrowsedMonthController extends Notifier<DateTime> {
  @override
  DateTime build() => _thisMonth;

  DateTime get _thisMonth {
    final DateTime now = ref.read(clockProvider)();
    return DateTime(now.year, now.month);
  }

  void reset() => state = _thisMonth;

  /// Steps [months] forward, or back when negative.
  ///
  /// Clamped at this month on the forward side: there is nothing to see in a
  /// month that has not happened, and an empty grid of days to come reads as a
  /// list of things already failed. There is no clamp going back — the
  /// calendar simply empties out, which is the truth about a month before the
  /// app was installed.
  void step(int months) {
    final DateTime next = DateTime(state.year, state.month + months);
    final DateTime limit = _thisMonth;
    state = next.isAfter(limit) ? limit : next;
  }

  bool get canGoForward => state.isBefore(_thisMonth);
}

final NotifierProvider<BrowsedMonthController, DateTime> browsedMonthProvider =
    NotifierProvider<BrowsedMonthController, DateTime>(
      BrowsedMonthController.new,
      name: 'browsedMonth',
    );

/// Bumped whenever a completion is logged.
///
/// Everything that reads completion history watches this, so a screen coming
/// back from the player refreshes by bumping one number rather than by
/// remembering to invalidate a list of providers that grows every time a
/// feature is added. That list is how a rename came to sit stale on the home
/// screen once already.
final class CompletionsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final NotifierProvider<CompletionsRevision, int> completionsRevisionProvider =
    NotifierProvider<CompletionsRevision, int>(
      CompletionsRevision.new,
      name: 'completionsRevision',
    );

/// A scope's whole completion history, and the picker's options.
///
/// **Unwindowed, deliberately**, where `streakViewProvider` bounds its read to
/// the month on screen. The difference is that this screen asks four questions
/// of the same history — the run, twelve weeks, seven weekdays, and an
/// all-time count — and reading it once to answer all four in Dart is cheaper
/// than four windowed reads. It also means paging the calendar costs no
/// database read at all: [trackerViewProvider] derives the grid from the set
/// that is already in memory.
///
/// Keyed on the scope so that switching to a collection and back does not
/// re-read what was just read.
final FutureProviderFamily<TrackerHistory, TrackerScope>
trackerHistoryProvider = FutureProvider.family<TrackerHistory, TrackerScope>((
  Ref ref,
  TrackerScope scope,
) async {
  final UserRepository user = ref.watch(userRepositoryProvider);

  // Watched for when they change rather than for what they hold. The
  // commitments carry the weekday mask this whole screen is reckoned
  // against, and the listings carry the names the picker shows and the
  // fact of a collection still existing — so a commit, an uncommit, a
  // rename and a delete all reach here without any of those call sites
  // having to know this provider exists.
  final Map<CollectionId, Commitment> commitments = await ref.watch(
    commitmentsProvider.future,
  );
  final List<CollectionListing> listings = await ref.watch(
    collectionListingsProvider.future,
  );
  ref.watch(completionsRevisionProvider);

  final Set<CollectionId> everCompleted = await user.completedCollections();

  final DateTime now = ref.watch(clockProvider)();

  final Set<String> completed = switch (scope) {
    EverythingScope() => (await user.completionDates()).toSet(),
    CollectionScope(:final CollectionId collectionId) =>
      (await user.completionDatesFor(collectionId)).toSet(),
  };

  final Commitment? commitment = switch (scope) {
    EverythingScope() => null,
    CollectionScope(:final CollectionId collectionId) =>
      commitments[collectionId],
  };

  final DueDays due = DueDays(
    completed: completed,
    // "Everything" has no due rule: the app was never owed a day, so it
    // cannot have missed one. A collection with no commitment is the same
    // — see the picker's second group.
    days: commitment?.days,
    start: commitment == null
        ? null
        : earlierDayKey(
            // `created_at` is stored as epoch milliseconds UTC, so this
            // re-derives a local day from a timestamp — which `date_key`
            // otherwise forbids, because a timezone move changes the
            // answer. It is allowed here because the value is cosmetic: it
            // decides only where a denominator starts, and being a day out
            // after a flight costs nothing anybody can see.
            dateKey(commitment.createdAt),
            completed.isEmpty ? null : completed.reduce(_earlier),
          ),
    today: dateKey(now),
  );

  return TrackerHistory(
    scope: scope,
    due: due,
    options: _options(listings, commitments, everCompleted),
  );
}, name: 'trackerHistory');

String _earlier(String a, String b) => a.compareTo(b) <= 0 ? a : b;

/// What the picker offers: everything, then what is committed, then what has
/// been done without being committed.
///
/// A collection that no longer exists is not here — its completions still feed
/// "Everything", because they are kept deliberately, but a scope with no name
/// to put on it is not worth offering. Nothing labels the second group as
/// uncommitted: that would be a nudge to commit, and this screen reports.
List<TrackerScopeOption> _options(
  List<CollectionListing> listings,
  Map<CollectionId, Commitment> commitments,
  Set<CollectionId> everCompleted,
) {
  final List<TrackerScopeOption> committed = <TrackerScopeOption>[];
  final List<TrackerScopeOption> rest = <TrackerScopeOption>[];

  for (final CollectionListing listing in listings) {
    final Commitment? commitment = commitments[listing.id];
    if (commitment != null) {
      committed.add(
        TrackerScopeOption(
          scope: CollectionScope(listing.id),
          label: listing.name,
          days: commitment.days,
        ),
      );
    } else if (everCompleted.contains(listing.id)) {
      // Done at some point, not committed now. Worth looking back at, and
      // reckoned with no due rule: nothing currently says which days it owes,
      // and inventing every-day would turn every day since into a miss.
      rest.add(
        TrackerScopeOption(
          scope: CollectionScope(listing.id),
          label: listing.name,
          days: null,
        ),
      );
    }
  }

  // Sorted by when they were committed, so the picker reads in the order the
  // home screen's tiles do.
  committed.sort((TrackerScopeOption a, TrackerScopeOption b) {
    final int? x = commitments[a.scope.id]?.sortOrder;
    final int? y = commitments[b.scope.id]?.sortOrder;
    return (x ?? 0).compareTo(y ?? 0);
  });

  return <TrackerScopeOption>[
    const TrackerScopeOption(
      scope: EverythingScope(),
      label: 'Everything',
      days: null,
    ),
    ...committed,
    ...rest,
  ];
}

/// Everything the tracker screen draws, derived without touching the database.
@immutable
final class TrackerView {
  const TrackerView({
    required this.scope,
    required this.label,
    required this.days,
    required this.streak,
    required this.month,
    required this.states,
    required this.canGoForward,
    required this.weeks,
    required this.weekdays,
    required this.totals,
    required this.due,
    required this.options,
    required this.today,
    required this.lastSeven,
  });

  final TrackerScope scope;

  /// What the picker calls this scope.
  final String label;

  /// The days it comes round on, or null where there is no due rule.
  final Weekdays? days;

  final int streak;

  final MonthGrid month;

  /// Every day of [month], by key.
  final Map<String, DayState> states;

  final bool canGoForward;

  final List<WeekPoint> weeks;

  final List<WeekdayTally> weekdays;

  final TrackerTotals totals;

  final DueDays due;

  final List<TrackerScopeOption> options;

  /// The device's local day, so the calendar's "you are here" and the figures
  /// come from one clock.
  final String today;

  /// Days completed in the last seven, today included.
  ///
  /// The sentence under the count is drawn from this rather than from [weeks],
  /// which shows only weeks that are over: a reader looking at "the last seven
  /// days" means the seven days behind them, not the last calendar week.
  final int lastSeven;

  bool get hasChoice => options.length > 1;

  /// Nothing has ever been completed in this scope.
  bool get isEmpty => totals.isEmpty;

  /// Whether this scope is reckoned against particular days of the week.
  bool get hasDueRule => days != null;

  /// The single weekday this comes round on, or null when it is more than one.
  ///
  /// What lets the count say "8 Fridays in a row" instead of counting days
  /// that were never owed.
  int? get onlyWeekday {
    final Weekdays? days = this.days;
    if (days == null || days.weekdays.length != 1) return null;
    return days.weekdays.single;
  }
}

/// The screen's data, recomputed in memory whenever the month changes.
final Provider<AsyncValue<TrackerView>> trackerViewProvider =
    Provider<AsyncValue<TrackerView>>((Ref ref) {
      final TrackerScope scope = ref.watch(trackerScopeProvider);
      final AsyncValue<TrackerHistory> history = ref.watch(
        trackerHistoryProvider(scope),
      );
      final DateTime month = ref.watch(browsedMonthProvider);
      final int firstWeekday = ref.watch(firstWeekdayProvider);
      final DateTime now = ref.watch(clockProvider)();

      return history.whenData((TrackerHistory value) {
        final MonthGrid grid = MonthGrid.of(month, firstWeekday: firstWeekday);

        return TrackerView(
          scope: value.scope,
          label: value.options
              .firstWhere(
                (TrackerScopeOption o) => o.scope == value.scope,
                orElse: () => value.options.first,
              )
              .label,
          days: value.due.days,
          streak: dueStreak(value.due, now: now),
          month: grid,
          states: <String, DayState>{
            // `nonNulls` drops the padding cells: `MonthGrid` borrows no days
            // from the months either side, so the corners are empty and there
            // is nothing to state about them.
            for (final String day
                in grid.weeks.expand((List<String?> week) => week).nonNulls)
              day: value.due.stateOf(day),
          },
          canGoForward: ref.read(browsedMonthProvider.notifier).canGoForward,
          weeks: weeklySeries(value.due, now: now, firstWeekday: firstWeekday),
          weekdays: weekdayTallies(value.due, now: now),
          totals: TrackerTotals.of(value.due),
          due: value.due,
          options: value.options,
          today: value.due.today,
          lastSeven: <int>[
            for (int i = 0; i < DateTime.daysPerWeek; i++)
              if (value.due.completed.contains(dateKeyDaysBefore(now, i))) 1,
          ].length,
        );
      });
    }, name: 'trackerView');
