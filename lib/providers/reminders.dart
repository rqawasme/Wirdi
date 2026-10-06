import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/commitment.dart';
import '../domain/repositories.dart';
import '../reminders/reminder_plan.dart';
import '../reminders/reminder_scheduler.dart';
import 'collections.dart';
import 'data_providers.dart';
import 'home.dart';
import 'settings.dart';
import 'streak.dart';
import 'tracker.dart';

/// The phone's notifications, or nothing.
///
/// Nothing by default, so that no widget test needs a platform channel; `main`
/// overrides this with the real one once the plugin is up.
final Provider<ReminderScheduler> reminderSchedulerProvider =
    Provider<ReminderScheduler>(
      (Ref ref) => const NoReminderScheduler(),
      name: 'reminderScheduler',
    );

/// Lays every reminder out and hands them to the phone — and again whenever
/// anything they are made from changes.
///
/// Watched for what it depends on rather than called from each place that can
/// change one of those things, for the reason [homeViewProvider] watches the
/// collection list: an invalidation per call site is the pattern that does
/// not scale. So a commitment made or moved, a collection renamed or deleted,
/// a wird finished, and the switch in Settings all reach the phone without any
/// of them knowing reminders exist. The shell keeps this alive and invalidates
/// it when the app comes back to the front, which is what picks up a new day
/// and a new time zone.
///
/// The value is the plan that was handed over, for a test to read.
final FutureProvider<List<PlannedReminder>> reminderSyncProvider =
    FutureProvider<List<PlannedReminder>>((Ref ref) async {
      final ReminderScheduler scheduler = ref.watch(reminderSchedulerProvider);
      final UserRepository user = ref.watch(userRepositoryProvider);
      final DateTime now = ref.watch(clockProvider)();

      // Every dependency is watched before the first await, so a run that is
      // superseded part way through never touches its ref again.
      final Future<bool> enabled = ref.watch(
        settingsProvider.selectAsync((WirdiSettings s) => s.remindersEnabled),
      );
      final Future<Map<CollectionId, Commitment>> commitments = ref.watch(
        commitmentsProvider.future,
      );
      // For the names, and for which collections still exist. A rename or a
      // delete invalidates this list, so watching it is what puts the new
      // name on the next reminder or takes the reminder away.
      final Future<List<CollectionListing>> listings = ref.watch(
        collectionListingsProvider.future,
      );
      // Finishing a wird on the Home tab bumps this rather than refreshing the
      // collection list, and a wird finished today is not reminded of today.
      ref.watch(completionsRevisionProvider);

      final bool on = await enabled;
      final Map<CollectionId, Commitment> committed = await commitments;
      final List<CollectionListing> listed = await listings;

      List<PlannedReminder> plan = const <PlannedReminder>[];
      if (on) {
        final Iterable<Commitment> reminded = committed.values.where(
          (Commitment c) => c.reminder != null,
        );
        final Set<CollectionId> completedToday = <CollectionId>{
          for (final Commitment c in reminded)
            if (await user.isCompletedToday(c.collectionId)) c.collectionId,
        };
        plan = planReminders(
          commitments: reminded,
          collections: <CollectionId, CollectionSummary>{
            for (final CollectionListing l in listed) l.summary.id: l.summary,
          },
          completedToday: completedToday,
          now: now,
        );
      }

      // Something changed while the plan was being made, and a newer run is
      // already on its way with the newer answer. Handing this one over too
      // could land it after that one and put the stale plan back.
      if (!ref.mounted) return plan;
      await scheduler.replaceAll(plan);
      return plan;
    }, name: 'reminderSync');
