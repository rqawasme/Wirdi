import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/providers/streak.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/screens/tracker_screen.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/bottom_nav.dart';
import 'package:wirdi/widgets/streak_panel.dart';

import '../support/fixtures.dart';

/// What the Tracker is allowed to say, and what it is not.
///
/// The README's position is against **gamification**, not against warmth. This
/// file is where that distinction is held, because it is exactly the kind of
/// thing that erodes one well-meant addition at a time: a flame here, a
/// personal best there, and a screen about somebody's devotional practice ends
/// up engineered around loss aversion the way a language app is.
///
/// So the tab may encourage — there is a positive assertion below that it
/// does, so a later reader can see that the silence is not the goal. What it
/// may not do is escalate, rank, warn, or mark a failure.
void main() {
  late TestDatabases dbs;
  late WirdiData data;

  const CollectionId mixed = BuiltinCollectionId(mixedCollectionId);
  final DateTime now = DateTime(2026, 9, 15, 9);
  final ThemeData theme = WirdiTheme.light();

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
          theme: theme,
          onGenerateRoute: WirdiRouter.onGenerateRoute,
          initialRoute: Routes.shell,
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text(WirdiTab.tracker.label));
    await settle(tester);
  }

  /// Completes something on each of the [days] days up to today.
  Future<void> completeRun(int days) async {
    final UserRepository user = dbs.userRepository(clock: () => now);
    for (int i = 0; i < days; i++) {
      await user.logCompletion(mixed, now.subtract(Duration(days: i)));
    }
  }

  /// Every string the tab puts on screen.
  ///
  /// Scoped to [TrackerScreen]: the shell keeps all four tabs alive at once in
  /// an IndexedStack, so an unscoped finder would be reading Home's copy too.
  List<String> words(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(TrackerScreen),
          matching: find.byType(Text),
        ),
      )
      .map((Text t) => t.data ?? '')
      .where((String s) => s.isNotEmpty)
      .toList();

  void expectNoMatch(WidgetTester tester, RegExp pattern, String because) {
    for (final String line in words(tester)) {
      expect(
        pattern.hasMatch(line),
        isFalse,
        reason: '$because — found in: "$line"',
      );
    }
  }

  testWidgets('encourages, which is the point of the exception', (
    WidgetTester tester,
  ) async {
    // The positive half, and it is here first on purpose. Everything below
    // says what the tab may not do; without this, a future change that made
    // the screen silent would pass every one of them and lose the thing the
    // tab was rewritten for.
    await completeRun(5);
    await pumpTracker(tester);

    expect(
      words(tester).any((String s) => s.contains('You have practised on')),
      isTrue,
      reason: 'the tab should say something warm about the run',
    );
  });

  testWidgets('invites a beginning where a run has ended', (
    WidgetTester tester,
  ) async {
    // Completed a while ago and not since. The count states the fact; the line
    // next to it opens rather than closes, and says nothing about what ended.
    await dbs
        .userRepository(clock: () => now)
        .logCompletion(mixed, now.subtract(const Duration(days: 10)));
    await pumpTracker(tester);

    expect(find.text('No days in a row'), findsOneWidget);
    expect(find.text('A good day to begin again.'), findsOneWidget);
  });

  testWidgets('does not escalate as the number grows', (
    WidgetTester tester,
  ) async {
    // A year of daily practice. The tab is the same tab it is at a week: the
    // same sections, in the same order, with the same marks in them.
    await completeRun(365);
    await pumpTracker(tester);

    final List<String> longRun = words(tester);
    expect(find.text('365 days in a row'), findsOneWidget);

    // Every day of September marked, and marked the same way — the panel's own
    // test pins the mark itself, this pins that the screen did not add to it.
    expect(
      tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(StreakPanel),
              matching: find.byWidgetPredicate(
                (Widget w) =>
                    w is Container &&
                    w.decoration is BoxDecoration &&
                    (w.decoration! as BoxDecoration).color ==
                        theme.colorScheme.primary,
              ),
            ),
          )
          .length,
      15,
      reason: 'the 1st to the 15th, and nothing extra for the year behind them',
    );

    // The same shape of sentence as a short run, differing only in its number.
    expect(
      longRun.map((String s) => s.replaceAll(RegExp(r'\d+'), '#')).toSet(),
      containsAll(<String>['# days in a row']),
    );
  });

  testWidgets('has no tier, badge, best or record', (
    WidgetTester tester,
  ) async {
    await completeRun(365);
    await pumpTracker(tester);

    expectNoMatch(
      tester,
      RegExp(
        r'\b(badge|tier|level|trophy|award|rank|medal|milestone|'
        r'personal best|your best|best ever|record|all[- ]time high|'
        r'unlock|achievement|congratulations|well done|amazing|'
        r'perfect week)\b',
        caseSensitive: false,
      ),
      'nothing here has a tier to reach, so nothing has one to fall out of',
    );
  });

  testWidgets('has no loss vocabulary', (WidgetTester tester) async {
    // The same list `streak_panel_test.dart` holds the panel to, applied to
    // the whole tab — including the lines that are allowed to be warm.
    await completeRun(3);
    await pumpTracker(tester);

    expectNoMatch(
      tester,
      RegExp(
        r"streak|don't|do not|at risk|lose|lost|broke|keep it up|"
        r'come back|again tomorrow|missed|failed|behind|'
        r'hours left|expires|ends in',
        caseSensitive: false,
      ),
      'a run that has ended is an invitation to begin, not a loss to be warned '
      'about',
    );
  });

  testWidgets('carries no icon of its own', (WidgetTester tester) async {
    // The month arrows are chevrons set in type for this reason: the app's
    // only ornament is the voussoir stripe, and an icon on this tab in
    // particular is one step from a flame on it.
    await completeRun(365);
    await pumpTracker(tester);

    expect(
      find.descendant(
        of: find.byType(TrackerScreen),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
  });

  testWidgets('marks no day as missed, and paints nothing in warning', (
    WidgetTester tester,
  ) async {
    // A wird committed to every day, done twice in the last fortnight. The
    // twelve days it was due and not done get no mark at all: which days were
    // owed is useful in the numbers and accusatory on a grid, where a row of
    // outlined failures laid out by date is a list of accusations.
    final UserRepository user = dbs.userRepository(clock: () => now);
    await user.commit(mixed, DailySection.today);
    await user.logCompletion(mixed, now);
    await user.logCompletion(mixed, now.subtract(const Duration(days: 13)));

    await pumpTracker(tester);

    final Set<Color> painted = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(TrackerScreen),
            matching: find.byWidgetPredicate(
              (Widget w) => w is Container && w.decoration is BoxDecoration,
            ),
          ),
        )
        .map((Container c) => (c.decoration! as BoxDecoration).color)
        .nonNulls
        .toSet();

    // Two marks on the calendar and no third: a completed day, and today.
    expect(painted, isNot(contains(theme.colorScheme.error)));
    expect(painted, isNot(contains(theme.colorScheme.errorContainer)));

    // Gold is the app's tripwire for a widget that reached for the wrong role.
    // Nothing in `wirdi_theme.dart` maps `tertiary` onto a component, so it
    // appearing here at all would mean a second series crept into the chart or
    // the bars.
    expect(painted, isNot(contains(theme.colorScheme.tertiary)));
  });

  testWidgets('says what it counts without ranking the collections', (
    WidgetTester tester,
  ) async {
    // The picker names collections; it does not order them by how well they
    // are going, and no row carries a figure. A list of your own practices
    // sorted best-first is a leaderboard with one player on it.
    final UserRepository user = dbs.userRepository(clock: () => now);
    await user.commit(mixed, DailySection.today);
    await user.commit(
      const BuiltinCollectionId(simpleCollectionId),
      DailySection.morning,
    );
    await user.logCompletion(mixed, now);

    await pumpTracker(tester);
    await tester.tap(find.text('Everything'));
    await settle(tester);

    // Each row is exactly a name — "Everything", or a collection called what
    // the collections list calls it — with no run, rate or count appended.
    final Set<String> names = <String>{
      'Everything',
      for (final CollectionSummary s in await data.collectionRepository.all())
        s.name,
    };
    final List<String> rows = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.byType(Text),
          ),
        )
        .map((Text t) => t.data ?? '')
        .toList();

    expect(rows, isNotEmpty);
    for (final String row in rows) {
      expect(
        names,
        contains(row),
        reason: 'a picker row is a name, not a score: "$row"',
      );
    }
  });
}
