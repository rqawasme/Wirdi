import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/tracker_stats.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/weekday_bars.dart';

/// The weekday bars, and mostly: that they are actually drawn.
///
/// This file exists because they were not. `DecoratedBox` has no size of its
/// own — it takes its child's — so under a loose constraint and with no child
/// it collapses to nothing. Every bar was laid out that way, so the tab drew
/// seven empty tracks while every number behind them was correct. Nothing in
/// the widget tree was missing and nothing threw; the only way to see it was
/// to look at a picture of the screen.
void main() {
  final ThemeData theme = WirdiTheme.light();
  final Color filled = theme.colorScheme.primary;

  Future<void> pump(
    WidgetTester tester,
    List<WeekdayTally> tallies, {
    int firstWeekday = DateTime.monday,
  }) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: WeekdayBars(
            tallies: tallies,
            firstWeekday: firstWeekday,
            caption: 'Days practised, by weekday',
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The heights of the brick-filled boxes, left to right.
  List<double> barHeights(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(
        find.byWidgetPredicate(
          (Widget w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == filled,
        ),
      )
      .map((DecoratedBox box) => tester.getSize(find.byWidget(box)).height)
      .toList();

  List<double> barWidths(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(
        find.byWidgetPredicate(
          (Widget w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == filled,
        ),
      )
      .map((DecoratedBox box) => tester.getSize(find.byWidget(box)).width)
      .toList();

  List<WeekdayTally> tallies(List<(int, int)> doneOverDue) => <WeekdayTally>[
    for (final (int done, int due) in doneOverDue)
      WeekdayTally(done: done, due: due),
  ];

  testWidgets('draws a bar with a size, which is the whole point', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      tallies(<(int, int)>[
        (4, 4),
        (2, 4),
        (0, 4),
        (4, 4),
        (4, 4),
        (1, 4),
        (3, 4),
      ]),
    );

    // All seven came round, so all seven are drawn — six as a share of the
    // track, and the day that was never kept as the stub.
    expect(barHeights(tester), <double>[
      64,
      32,
      WeekdayBars.emptyStub,
      64,
      64,
      16,
      48,
    ]);
    for (final double width in barWidths(tester)) {
      expect(width, greaterThan(0), reason: 'a bar with no width is not a bar');
    }
  });

  testWidgets('is as tall as the share kept, not the busiest day', (
    WidgetTester tester,
  ) async {
    // Under a sparse mask the busiest day is often the only day, and
    // normalising against it would draw one full bar and say nothing.
    await pump(
      tester,
      tallies(<(int, int)>[
        (4, 4),
        (2, 4),
        (1, 4),
        (0, 0),
        (0, 0),
        (0, 0),
        (0, 0),
      ]),
    );

    final List<double> heights = barHeights(tester);
    // Monday kept every time, Tuesday half, Wednesday a quarter.
    expect(heights, hasLength(3));
    expect(heights[1] / heights[0], closeTo(0.5, 0.01));
    expect(heights[2] / heights[0], closeTo(0.25, 0.01));
  });

  testWidgets('a day that came round and was never kept keeps a stub', (
    WidgetTester tester,
  ) async {
    // A zero reads as a zero. A column that vanished reads as a bug.
    await pump(
      tester,
      tallies(<(int, int)>[
        (4, 4),
        (0, 4),
        (0, 0),
        (0, 0),
        (0, 0),
        (0, 0),
        (0, 0),
      ]),
    );

    final List<double> heights = barHeights(tester);
    expect(heights, hasLength(2));
    expect(heights[1], WeekdayBars.emptyStub);
  });

  testWidgets('a day that never came round draws no bar at all', (
    WidgetTester tester,
  ) async {
    // Its track and its label stay, so the seven-column rhythm the header is
    // read against does not break.
    await pump(
      tester,
      tallies(<(int, int)>[
        (0, 0),
        (0, 0),
        (0, 0),
        (0, 0),
        (8, 8),
        (0, 0),
        (0, 0),
      ]),
    );

    expect(barHeights(tester), hasLength(1));
    expect(
      find.byType(Text),
      findsNWidgets(8),
      reason: 'seven labels plus the caption',
    );
  });

  testWidgets('with no due rule, falls back to the busiest day', (
    WidgetTester tester,
  ) async {
    // "Everything" is never owed a day, so there is no rate to take and the
    // only available reading is one day against another.
    await pump(
      tester,
      tallies(<(int, int)>[
        (10, 0),
        (5, 0),
        (0, 0),
        (0, 0),
        (0, 0),
        (0, 0),
        (0, 0),
      ]),
    );

    final List<double> heights = barHeights(tester);
    expect(heights, hasLength(2));
    expect(heights[1] / heights[0], closeTo(0.5, 0.01));
  });

  testWidgets('orders the columns from the reader\'s own first weekday', (
    WidgetTester tester,
  ) async {
    // The app ships no localisations, so this is the same table the widget
    // reads through `MaterialLocalizations.of`.
    const MaterialLocalizations l10n = DefaultMaterialLocalizations();

    await pump(
      tester,
      tallies(<(int, int)>[
        (4, 4),
        (0, 0),
        (0, 0),
        (0, 0),
        (0, 0),
        (0, 0),
        (0, 0),
      ]),
      firstWeekday: DateTime.sunday,
    );

    // Sunday first, so Monday's bar is the second column rather than the
    // first — the same order the calendar's header runs in.
    final List<String> labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((Text t) => t.data ?? '')
        .take(DateTime.daysPerWeek)
        .toList();
    expect(labels.first, l10n.narrowWeekdays[0]);
  });
}
