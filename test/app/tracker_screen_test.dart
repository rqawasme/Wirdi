import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/providers/settings.dart';
import 'package:wirdi/providers/streak.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/bottom_nav.dart';
import 'package:wirdi/widgets/empty_state.dart';
import 'package:wirdi/widgets/streak_panel.dart';
import 'package:wirdi/widgets/tracker_chart.dart';
import 'package:wirdi/widgets/tracker_scope_picker.dart';
import 'package:wirdi/widgets/weekday_bars.dart';

import '../support/fixtures.dart';

/// The Tracker tab: switching what it is showing, and moving through months.
void main() {
  late TestDatabases dbs;
  late WirdiData data;

  const CollectionId mixed = BuiltinCollectionId(mixedCollectionId);
  const CollectionId simple = BuiltinCollectionId(simpleCollectionId);

  /// A Tuesday, so "today" is not itself the Friday the day-mask tests turn on.
  final DateTime now = DateTime(2026, 9, 15, 9);

  setUp(() async {
    dbs = await TestDatabases.open();
    data = WirdiData(content: dbs.content, user: dbs.user, clock: () => now);
  });

  tearDown(() => dbs.close());

  Future<void> settle(WidgetTester tester) async {
    for (int frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpTracker(WidgetTester tester) async {
    // Tall, because the tab is now a scrolling screen rather than one panel,
    // and a finder that has to scroll first is a finder that hides a layout
    // bug.
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          wirdiDataProvider.overrideWithValue(data),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          theme: WirdiTheme.light(),
          onGenerateRoute: WirdiRouter.onGenerateRoute,
          initialRoute: Routes.shell,
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text(WirdiTab.tracker.label));
    await settle(tester);
  }

  /// Completes [id] on the day [daysAgo] days before [now].
  Future<void> complete(CollectionId id, int daysAgo) {
    return dbs
        .userRepository(clock: () => now)
        .logCompletion(id, now.subtract(Duration(days: daysAgo)));
  }

  /// Every Friday for [weeks] weeks back. 15 September 2026 is a Tuesday, so
  /// the Friday before it is four days back.
  Future<void> completeFridays(CollectionId id, int weeks) async {
    for (int i = 0; i < weeks; i++) {
      await complete(id, 4 + i * DateTime.daysPerWeek);
    }
  }

  group('with nothing to show', () {
    testWidgets('says so once, rather than drawing three empty sections', (
      WidgetTester tester,
    ) async {
      await pumpTracker(tester);

      expect(find.text('Nothing tracked yet'), findsOneWidget);
      expect(find.byType(StreakPanel), findsNothing);
      expect(find.byType(TrackerChart), findsNothing);
      expect(find.byType(WeekdayBars), findsNothing);
    });

    testWidgets('offers no picker when there is nothing to switch to', (
      WidgetTester tester,
    ) async {
      // A control with one entry in it teaches the reader it is not worth
      // pressing.
      await pumpTracker(tester);
      expect(find.byType(TrackerScopePicker), findsNothing);
    });
  });

  group('everything', () {
    testWidgets('counts the days the app was used at all', (
      WidgetTester tester,
    ) async {
      await complete(mixed, 0);
      await complete(simple, 1);
      await complete(mixed, 2);

      await pumpTracker(tester);

      expect(find.text('3 days in a row'), findsOneWidget);
      expect(find.byType(TrackerChart), findsOneWidget);
      expect(find.byType(WeekdayBars), findsOneWidget);
    });

    testWidgets('two collections on one day are one day', (
      WidgetTester tester,
    ) async {
      await complete(mixed, 0);
      await complete(simple, 0);

      await pumpTracker(tester);

      expect(find.text('1 day in a row'), findsOneWidget);
    });

    testWidgets('states the whole history in the footer', (
      WidgetTester tester,
    ) async {
      await complete(mixed, 0);
      await complete(mixed, 5);

      await pumpTracker(tester);

      expect(find.textContaining('2 days since'), findsOneWidget);
    });
  });

  group('switching scope', () {
    /// Commits [mixed] to Fridays and completes it on the last [weeks] of them.
    Future<void> commitToFridays({required int weeks}) async {
      await dbs
          .userRepository(clock: () => now)
          .commit(
            mixed,
            DailySection.today,
            days: Weekdays.of(<int>[DateTime.friday]),
          );
      await completeFridays(mixed, weeks);
    }

    testWidgets('the picker offers everything and what is committed', (
      WidgetTester tester,
    ) async {
      await commitToFridays(weeks: 3);
      await pumpTracker(tester);

      expect(find.byType(TrackerScopePicker), findsOneWidget);
      // Global by default: the app-wide run is the question most people open
      // this tab with.
      expect(find.text('Everything'), findsOneWidget);

      await tester.tap(find.byType(TrackerScopePicker));
      await settle(tester);

      expect(find.text('PLACEHOLDER collection 1 english'), findsOneWidget);
    });

    testWidgets('a Friday-only wird counts Fridays, not days', (
      WidgetTester tester,
    ) async {
      // The whole reason the tab was rewritten. Under a calendar-day streak
      // this same history could never read higher than one, because no Friday
      // is within a day of a Tuesday.
      await commitToFridays(weeks: 8);
      await pumpTracker(tester);

      // Everything, which has no due rule, sees eight scattered days.
      expect(find.text('No days in a row'), findsOneWidget);

      await tester.tap(find.byType(TrackerScopePicker));
      await settle(tester);
      await tester.tap(find.text('PLACEHOLDER collection 1 english'));
      await settle(tester);

      expect(find.text('8 Fridays in a row'), findsOneWidget);
    });

    testWidgets('the calendar follows the scope', (WidgetTester tester) async {
      await complete(simple, 0);
      await commitToFridays(weeks: 1);
      await pumpTracker(tester);

      final Color primary = WirdiTheme.light().colorScheme.primary;
      Iterable<String> marked() => tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(StreakPanel),
              matching: find.byWidgetPredicate(
                (Widget w) =>
                    w is Container &&
                    w.decoration is BoxDecoration &&
                    (w.decoration! as BoxDecoration).color == primary,
              ),
            ),
          )
          .map((Container c) => ((c.child! as Text).data)!);

      // Everything: today and the Friday before it.
      expect(marked(), unorderedEquals(<String>['15', '11']));

      await tester.tap(find.byType(TrackerScopePicker));
      await settle(tester);
      await tester.tap(find.text('PLACEHOLDER collection 1 english'));
      await settle(tester);

      // That collection alone was only done on the Friday.
      expect(marked(), <String>['11']);
    });
  });

  group('paging months', () {
    testWidgets('goes back, and the days go with it', (
      WidgetTester tester,
    ) async {
      await complete(mixed, 0);
      // 20 August 2026, comfortably inside the month before.
      await complete(mixed, 26);

      await pumpTracker(tester);
      expect(find.text('September 2026'), findsOneWidget);

      await tester.tap(find.text('‹'));
      await settle(tester);

      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('31'), findsOneWidget, reason: 'August has 31 days');
    });

    testWidgets('will not go past this month', (WidgetTester tester) async {
      // Disabled rather than hidden. A grid of days that have not happened
      // would read as a list of things already failed.
      await complete(mixed, 0);
      await pumpTracker(tester);

      await tester.tap(find.text('›'));
      await settle(tester);

      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('comes forward again after going back', (
      WidgetTester tester,
    ) async {
      await complete(mixed, 0);
      await pumpTracker(tester);

      await tester.tap(find.text('‹'));
      await settle(tester);
      expect(find.text('August 2026'), findsOneWidget);

      await tester.tap(find.text('›'));
      await settle(tester);
      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('returns to this month when the scope changes', (
      WidgetTester tester,
    ) async {
      // The month being browsed belongs to the scope it was browsed in.
      // Carrying it across can land the reader in a month the collection they
      // just picked has nothing in.
      await dbs
          .userRepository(clock: () => now)
          .commit(mixed, DailySection.today);
      await complete(mixed, 0);

      await pumpTracker(tester);
      await tester.tap(find.text('‹'));
      await settle(tester);
      expect(find.text('August 2026'), findsOneWidget);

      await tester.tap(find.byType(TrackerScopePicker));
      await settle(tester);
      await tester.tap(find.text('PLACEHOLDER collection 1 english'));
      await settle(tester);

      expect(find.text('September 2026'), findsOneWidget);
    });
  });

  group('the setting', () {
    testWidgets('takes the whole tab away, not just the count', (
      WidgetTester tester,
    ) async {
      await complete(mixed, 0);
      await dbs.userRepository().setSetting(SettingKeys.showTracker, 'false');

      await pumpTracker(tester);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(StreakPanel), findsNothing);
      expect(find.byType(TrackerChart), findsNothing);
      expect(find.byType(WeekdayBars), findsNothing);
      expect(find.byType(TrackerScopePicker), findsNothing);
    });
  });
}
