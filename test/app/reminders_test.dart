import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/collections.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/providers/home.dart';
import 'package:wirdi/providers/reminders.dart';
import 'package:wirdi/providers/settings.dart';
import 'package:wirdi/providers/streak.dart';
import 'package:wirdi/providers/tracker.dart';
import 'package:wirdi/reminders/reminder_plan.dart';
import 'package:wirdi/reminders/reminder_scheduler.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/theme/theme.dart';

import '../support/fixtures.dart';

/// Reminders, from the switch on the commit sheet to what is handed to the
/// phone.
///
/// The phone is a fake: it records what it was asked to schedule and answers
/// the permission question however the test says. Everything above it is the
/// real thing over the in-memory databases.
void main() {
  late TestDatabases dbs;
  late WirdiData data;
  late FakeReminders reminders;

  const CollectionId mixed = BuiltinCollectionId(mixedCollectionId);
  const String mixedName = 'PLACEHOLDER collection $mixedCollectionId english';

  /// A Friday, early: every suggested reminder time is still ahead today.
  final DateTime now = DateTime(2026, 9, 4, 5);

  setUp(() async {
    dbs = await TestDatabases.open();
    data = WirdiData(content: dbs.content, user: dbs.user, clock: () => now);
    reminders = FakeReminders();
  });

  tearDown(() async {
    await reminders.close();
    await dbs.close();
  });

  List<Override> overrides() => <Override>[
    wirdiDataProvider.overrideWithValue(data),
    clockProvider.overrideWithValue(() => now),
    reminderSchedulerProvider.overrideWithValue(reminders),
  ];

  group('the commit sheet', () {
    Future<void> settle(WidgetTester tester) async {
      for (int frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            theme: WirdiTheme.light(),
            onGenerateRoute: WirdiRouter.onGenerateRoute,
            initialRoute: Routes.shell,
          ),
        ),
      );
      await settle(tester);
    }

    /// Opens the commit sheet for the first collection in the list, which is
    /// the mixed built-in.
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('Collections'));
      await settle(tester);
      await tester.tap(find.byTooltip('Commit to my practice').first);
      await settle(tester);
    }

    Future<Commitment> committed() async =>
        (await dbs.userRepository(clock: () => now).commitments()).single;

    testWidgets('a reminder starts off', (WidgetTester tester) async {
      await pumpApp(tester);
      await openSheet(tester);

      expect(find.text('No reminder'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(remindSwitch).value, isFalse);

      await tester.tap(find.text('Commit'));
      await settle(tester);

      expect((await committed()).reminder, isNull);
      // Nothing asked of the phone for a feature nobody touched.
      expect(reminders.permissionRequests, 0);
    });

    testWidgets('turning it on asks the phone, then asks for the time', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await openSheet(tester);

      await tester.tap(find.text('Remind me'));
      await settle(tester);

      expect(reminders.permissionRequests, 1);
      // The time picker, starting from a plausible hour for Today.
      expect(find.text('Remind me at'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await settle(tester);

      expect(find.text('On the days above'), findsOneWidget);
      expect(find.text('9:00 AM'), findsOneWidget);

      await tester.tap(find.text('Commit'));
      await settle(tester);

      expect((await committed()).reminder, const ReminderTime(9, 0));
      // And it reached the phone without the sheet saying anything to it.
      expect(reminders.scheduled.first.collectionId, mixed);
      expect(reminders.scheduled.first.title, 'Time for $mixedName');
      expect(reminders.scheduled.first.at, DateTime(2026, 9, 4, 9));
    });

    testWidgets('cancelling the time picker leaves it off', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await openSheet(tester);

      await tester.tap(find.text('Remind me'));
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      expect(tester.widget<SwitchListTile>(remindSwitch).value, isFalse);
      expect(find.text('No reminder'), findsOneWidget);
    });

    testWidgets('a refusal leaves it off and says where to change it', (
      WidgetTester tester,
    ) async {
      reminders.allowed = false;
      await pumpApp(tester);
      await openSheet(tester);

      await tester.tap(find.text('Remind me'));
      await settle(tester);

      // No time picker for a reminder the phone will not show.
      expect(find.text('Remind me at'), findsNothing);
      expect(tester.widget<SwitchListTile>(remindSwitch).value, isFalse);
      expect(
        find.text("Notifications are off for Wirdi in your phone's settings."),
        findsOneWidget,
      );

      await tester.tap(find.text('Open settings'));
      await settle(tester);
      expect(reminders.settingsOpened, 1);

      await tester.tap(find.text('Commit'));
      await settle(tester);
      expect((await committed()).reminder, isNull);
    });

    testWidgets('a reminder already set is shown, and can be turned off', (
      WidgetTester tester,
    ) async {
      await dbs
          .userRepository(clock: () => now)
          .commit(
            mixed,
            DailySection.morning,
            reminder: const ReminderTime(6, 15),
          );
      await pumpApp(tester);
      await tester.tap(find.text('Collections'));
      await settle(tester);
      await tester.tap(find.byTooltip('Change when committed').first);
      await settle(tester);

      expect(find.text('6:15 AM'), findsOneWidget);

      await tester.tap(find.text('Remind me'));
      await settle(tester);
      // Turning it off asks nothing of anyone.
      expect(reminders.permissionRequests, 0);
      expect(find.text('6:15 AM'), findsNothing);

      await tester.tap(find.text('Save'));
      await settle(tester);
      expect((await committed()).reminder, isNull);
      expect(reminders.scheduled, isEmpty);
    });

    testWidgets('the sheet says so when reminders are off in Settings', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.setSetting(SettingKeys.remindersEnabled, 'false');
      await user.commit(
        mixed,
        DailySection.morning,
        reminder: const ReminderTime(6, 15),
      );
      await pumpApp(tester);
      await tester.tap(find.text('Collections'));
      await settle(tester);
      await tester.tap(find.byTooltip('Change when committed').first);
      await settle(tester);

      expect(
        find.text(
          'Reminders are off in Settings, so this one will not sound until '
          'they are on again.',
        ),
        findsOneWidget,
      );
      // And nothing is scheduled while they are.
      expect(reminders.scheduled, isEmpty);
    });

    testWidgets('the Settings switch silences them all', (
      WidgetTester tester,
    ) async {
      await dbs
          .userRepository(clock: () => now)
          .commit(
            mixed,
            DailySection.morning,
            reminder: const ReminderTime(6, 15),
          );
      await pumpApp(tester);
      expect(reminders.scheduled, isNotEmpty);

      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      await tester.tap(find.text('Reminders'));
      await settle(tester);

      expect(reminders.scheduled, isEmpty);
      expect(
        await dbs
            .userRepository(clock: () => now)
            .setting(SettingKeys.remindersEnabled),
        'false',
      );
      // The time itself is kept, for when they are turned back on.
      expect((await committed()).reminder, const ReminderTime(6, 15));
    });

    testWidgets('a tapped reminder goes Home, closing what was open', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Collections'));
      await settle(tester);
      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      expect(find.text('Show tracker'), findsOneWidget);

      reminders.tap();
      await settle(tester);

      expect(find.text('Show tracker'), findsNothing);
      // The Home tab's own title.
      expect(find.text('Wird'), findsOneWidget);
    });
  });

  group('the sync', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: overrides());
      // Kept alive the way the shell keeps it, so that a change to anything
      // it watches runs it again.
      container.listen(reminderSyncProvider, (_, _) {});
    });

    tearDown(() => container.dispose());

    Future<List<PlannedReminder>> synced() =>
        container.read(reminderSyncProvider.future);

    test('a commitment with a reminder is handed to the phone', () async {
      await container
          .read(userRepositoryProvider)
          .commit(
            mixed,
            DailySection.morning,
            reminder: const ReminderTime(6, 30),
          );
      container.invalidate(commitmentsProvider);

      final List<PlannedReminder> plan = await synced();
      expect(plan, hasLength(reminderHorizonDays));
      expect(plan.first.at, DateTime(2026, 9, 4, 6, 30));
      expect(reminders.scheduled, plan);
    });

    test('a wird finished today is not reminded of today', () async {
      final UserRepository user = container.read(userRepositoryProvider);
      await user.commit(
        mixed,
        DailySection.morning,
        reminder: const ReminderTime(6, 30),
      );
      container.invalidate(commitmentsProvider);
      expect((await synced()).first.at, DateTime(2026, 9, 4, 6, 30));

      await user.logCompletion(mixed, now);
      // What the Home tab does on the way back from the player.
      container.read(completionsRevisionProvider.notifier).bump();

      expect((await synced()).first.at, DateTime(2026, 9, 5, 6, 30));
      expect(reminders.scheduled.first.at, DateTime(2026, 9, 5, 6, 30));
    });

    test('a deleted collection takes its reminders with it', () async {
      final UserCollectionId mine = await container
          .read(collectionRepositoryProvider)
          .create('Mine');
      await container
          .read(userRepositoryProvider)
          .commit(mine, DailySection.today, reminder: const ReminderTime(9, 0));
      container.invalidate(commitmentsProvider);
      container.invalidate(collectionListingsProvider);
      expect((await synced()).first.title, 'Time for Mine');

      await container.read(collectionRepositoryProvider).delete(mine);
      container.invalidate(collectionListingsProvider);

      expect(await synced(), isEmpty);
      expect(reminders.scheduled, isEmpty);
    });

    test('turning reminders off hands the phone nothing', () async {
      await container
          .read(userRepositoryProvider)
          .commit(
            mixed,
            DailySection.morning,
            reminder: const ReminderTime(6, 30),
          );
      container.invalidate(commitmentsProvider);
      expect(await synced(), isNotEmpty);

      await container
          .read(settingsProvider.notifier)
          .setRemindersEnabled(false);

      expect(await synced(), isEmpty);
      expect(reminders.scheduled, isEmpty);
    });
  });
}

/// The [SwitchListTile] on the commit sheet.
final Finder remindSwitch = find.widgetWithText(SwitchListTile, 'Remind me');

/// A phone that says yes or no as told, and remembers what it was handed.
final class FakeReminders implements ReminderScheduler {
  bool allowed = true;

  int permissionRequests = 0;

  int settingsOpened = 0;

  /// The last plan handed over. Every sync replaces the whole thing, so the
  /// last one is what the phone would be holding.
  List<PlannedReminder> scheduled = const <PlannedReminder>[];

  final StreamController<void> _taps = StreamController<void>.broadcast();

  void tap() => _taps.add(null);

  Future<void> close() => _taps.close();

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allowed;
  }

  @override
  Future<void> openSystemSettings() async => settingsOpened++;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async =>
      scheduled = reminders;

  @override
  Stream<void> get taps => _taps.stream;
}
