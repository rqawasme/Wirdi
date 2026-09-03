import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/collections/streak_calendar.dart';
import 'package:wirdi/providers/streak.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/streak_panel.dart';

/// The streak display: what it says, and everything it deliberately does not.
void main() {
  final ThemeData theme = WirdiTheme.light();
  final Color primary = theme.colorScheme.primary;

  StreakView view({
    required int streak,
    required DateTime month,
    Set<String> completed = const <String>{},
    String? today,
  }) {
    return StreakView(
      streak: streak,
      month: MonthGrid.of(month),
      completed: completed,
      today: today ?? '2026-02-14',
    );
  }

  Future<void> pump(WidgetTester tester, StreakView value) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(body: StreakPanel(view: value)),
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
      await pump(tester, view(streak: 12, month: DateTime(2026, 2)));
      expect(find.text('12 days in a row'), findsOneWidget);
    });

    testWidgets('says one day in the singular', (WidgetTester tester) async {
      await pump(tester, view(streak: 1, month: DateTime(2026, 2)));
      expect(find.text('1 day in a row'), findsOneWidget);
    });

    testWidgets('states a broken streak as a fact and stops there', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        view(
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

  group('the calendar', () {
    testWidgets('marks the month\'s completed days and nothing else', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        view(
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
        view(
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
        view(
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
      await pump(tester, view(streak: 0, month: DateTime(2026, 2)));

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
        view(
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
      view(
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
