import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/collections/streak_calendar.dart';
import 'package:wirdi/domain/tracker_stats.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/streak_panel.dart';

/// The streak display: what it says, and everything it deliberately does not.
void main() {
  final ThemeData theme = WirdiTheme.light();
  final Color primary = theme.colorScheme.primary;

  /// The panel as the tracker builds it, from a set of completed days.
  ///
  /// The panel takes day *states* now, because a scope reckoned against a
  /// weekday mask has to be able to tell a day that never came round from one
  /// that did. What it draws is unchanged, and deliberately: a day that was
  /// due and missed gets the same nothing as a day that was never due, so the
  /// grid never becomes a list of failures laid out by date.
  StreakPanel panel({
    required int streak,
    required DateTime month,
    Set<String> completed = const <String>{},
    String? today,
    String? unit,
    String? note,
    void Function(int months)? onStep,
    bool canGoForward = false,
  }) {
    final MonthGrid grid = MonthGrid.of(month);
    return StreakPanel(
      streak: streak,
      month: grid,
      states: <String, DayState>{
        for (final String day
            in grid.weeks.expand((List<String?> week) => week).nonNulls)
          day: completed.contains(day) ? DayState.completed : DayState.notDue,
      },
      today: today ?? '2026-02-14',
      streakUnit: unit,
      note: note,
      onStep: onStep,
      canGoForward: canGoForward,
    );
  }

  Future<void> pump(WidgetTester tester, StreakPanel value) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(body: value),
      ),
    );
    await tester.pump();
  }

  /// The day cells painted in `primary` — the mark a completed day gets, and
  /// the only colour in the panel that is not chrome.
  Iterable<String> markedDays(WidgetTester tester) {
    return tester
        .widgetList<Container>(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).color == primary,
          ),
        )
        .map((Container c) => ((c.child! as Text).data)!);
  }

  group('the count', () {
    testWidgets('is a plain number of days', (WidgetTester tester) async {
      await pump(tester, panel(streak: 12, month: DateTime(2026, 2)));
      expect(find.text('12 days in a row'), findsOneWidget);
    });

    testWidgets('says one day in the singular', (WidgetTester tester) async {
      await pump(tester, panel(streak: 1, month: DateTime(2026, 2)));
      expect(find.text('1 day in a row'), findsOneWidget);
    });

    testWidgets('states a broken streak as a fact and stops there', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        panel(
          streak: 0,
          month: DateTime(2026, 2),
          // Days were completed; the run up to today has simply ended.
          completed: const <String>{'2026-02-03', '2026-02-04'},
        ),
      );

      expect(find.text('No days in a row'), findsOneWidget);
      // Nothing about what that means, and nothing about what to do next.
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is Text &&
              widget.data != null &&
              RegExp(
                r"streak|don't|do not|risk|lose|lost|broke|keep it up|"
                r'come back|again tomorrow',
                caseSensitive: false,
              ).hasMatch(widget.data!),
        ),
        findsNothing,
      );
    });
  });

  group('the count in a unit other than days', () {
    testWidgets('counts the day it comes round on', (
      WidgetTester tester,
    ) async {
      // A wird committed to Fridays alone has a run measured in Fridays.
      // "8 days in a row" would be false about it — there were fifty-six.
      await pump(
        tester,
        panel(streak: 8, month: DateTime(2026, 2), unit: 'Friday'),
      );
      expect(find.text('8 Fridays in a row'), findsOneWidget);
    });

    testWidgets('is singular and plural in that unit too', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        panel(streak: 1, month: DateTime(2026, 2), unit: 'Friday'),
      );
      expect(find.text('1 Friday in a row'), findsOneWidget);

      await pump(
        tester,
        panel(streak: 0, month: DateTime(2026, 2), unit: 'Friday'),
      );
      expect(find.text('No Fridays in a row'), findsOneWidget);
    });
  });

  group('the note', () {
    testWidgets('is absent unless one is given', (WidgetTester tester) async {
      // What the panel was before, and what it stays wherever no line is
      // passed: a number, stated and not commented on.
      await pump(tester, panel(streak: 3, month: DateTime(2026, 2)));
      expect(find.byType(Text), findsWidgets);
      expect(find.textContaining('.'), findsNothing);
    });

    testWidgets('sits under the count without changing it', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        panel(
          streak: 3,
          month: DateTime(2026, 2),
          note: 'You have practised on 5 of the last seven days.',
        ),
      );
      expect(find.text('3 days in a row'), findsOneWidget);
      expect(
        find.text('You have practised on 5 of the last seven days.'),
        findsOneWidget,
      );
    });
  });

  group('paging', () {
    testWidgets('is absent unless the panel is given a way to page', (
      WidgetTester tester,
    ) async {
      await pump(tester, panel(streak: 1, month: DateTime(2026, 2)));
      expect(find.text('‹'), findsNothing);
      expect(find.text('›'), findsNothing);
    });

    testWidgets('steps back a month, and forward when there is one', (
      WidgetTester tester,
    ) async {
      final List<int> steps = <int>[];
      await pump(
        tester,
        panel(
          streak: 1,
          month: DateTime(2026, 2),
          onStep: steps.add,
          canGoForward: true,
        ),
      );

      await tester.tap(find.text('‹'));
      await tester.tap(find.text('›'));
      expect(steps, <int>[-1, 1]);
    });

    testWidgets('will not go forward past this month', (
      WidgetTester tester,
    ) async {
      // Disabled rather than hidden: a control that disappears leaves the
      // reader wondering what they did. And a grid of days that have not
      // happened yet would read as a list of things already failed.
      final List<int> steps = <int>[];
      await pump(
        tester,
        panel(streak: 1, month: DateTime(2026, 2), onStep: steps.add),
      );

      await tester.tap(find.text('›'));
      await tester.tap(find.text('‹'));
      expect(steps, <int>[-1]);
    });

    testWidgets('is set in type, so the panel still carries no icon', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        panel(
          streak: 365,
          month: DateTime(2026, 2),
          onStep: (int _) {},
          canGoForward: true,
        ),
      );
      expect(find.byType(Icon), findsNothing);
    });
  });

  group('the calendar', () {
    testWidgets('marks the month\'s completed days and nothing else', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        panel(
          streak: 2,
          month: DateTime(2026, 2),
          completed: const <String>{'2026-02-13', '2026-02-14'},
        ),
      );

      expect(markedDays(tester), unorderedEquals(<String>['13', '14']));
    });

    testWidgets('does not mark a day from the month before', (
      WidgetTester tester,
    ) async {
      // February 2026 starts on a Sunday, so a Monday-first grid opens with
      // six blank cells where 26–31 January would sit. A completion on the
      // 31st must not light one of them.
      await pump(
        tester,
        panel(
          streak: 2,
          month: DateTime(2026, 2),
          completed: const <String>{'2026-01-31', '2026-02-01'},
        ),
      );

      expect(markedDays(tester), <String>['1']);
      expect(find.text('31'), findsNothing);
    });

    testWidgets('does not mark a day from the month after', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        panel(
          streak: 1,
          month: DateTime(2026, 2),
          completed: const <String>{'2026-02-28', '2026-03-01'},
        ),
      );

      expect(markedDays(tester), <String>['28']);
    });

    testWidgets('shows every day of the month it is showing', (
      WidgetTester tester,
    ) async {
      await pump(tester, panel(streak: 0, month: DateTime(2026, 2)));

      for (int day = 1; day <= 28; day++) {
        expect(find.text('$day'), findsOneWidget, reason: 'day $day');
      }
      expect(find.text('29'), findsNothing);
    });

    testWidgets('crosses a year boundary without borrowing January', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        panel(
          streak: 3,
          month: DateTime(2026, 12),
          completed: const <String>{'2026-12-31', '2027-01-01'},
          today: '2026-12-31',
        ),
      );

      expect(find.text('31'), findsOneWidget);
      expect(markedDays(tester), <String>['31']);
    });
  });

  testWidgets('has no badge, tier or escalating mark', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      panel(
        streak: 365,
        month: DateTime(2026, 2),
        completed: <String>{
          for (int d = 1; d <= 28; d++)
            '2026-02-${d.toString().padLeft(2, '0')}',
        },
      ),
    );

    // A year of daily practice, and the panel looks exactly like a week of it:
    // the same mark on every day, and no icon anywhere.
    expect(find.text('365 days in a row'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(markedDays(tester).length, 28);
  });
}
