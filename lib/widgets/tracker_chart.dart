import 'package:flutter/material.dart';

import '../domain/tracker_stats.dart';
import '../theme/theme.dart';

/// The weeks behind you, as a line.
///
/// One point per completed week, and the question it answers is the one a
/// calendar cannot: not "did I practise on the 14th" but "is this holding up".
/// Dips and rises over three months are a shape you can see and cannot count.
///
/// ## The rules it is drawn under
///
/// **The week in progress is not on it.** Plotted at its running total, a
/// Monday would read as a collapse and the following Sunday as a recovery,
/// every week, forever. The two usual ways out — a dashed last segment, a
/// hollow last marker — both say "unfinished", and "unfinished" a step from
/// "running out", which this app does not say. Today is on the calendar
/// directly above; it does not need saying twice.
///
/// **The y-axis is fixed, never fitted to the data.** Fitted, a week with one
/// day in it fills the frame, and the chart flatters. The top of the axis is
/// the number of days the scope was actually due, which for "Everything" is
/// seven.
///
/// **A week before the history starts is not a zero.** It is nothing, and it
/// is drawn as nothing: the line begins where the practice began. A zero there
/// would be the app drawing a failure out of not having been installed yet.
class TrackerChart extends StatelessWidget {
  const TrackerChart({
    super.key,
    required this.weeks,
    required this.maxPerWeek,
    required this.caption,
  });

  /// Tall enough for a shape to be legible, short enough that the calendar
  /// above and the weekdays below stay on the same screen.
  static const double chartHeight = WirdiMetrics.space6 * 4;

  /// Oldest first.
  final List<WeekPoint> weeks;

  /// The top of the axis: days owed in a week, or seven where nothing is owed.
  final int maxPerWeek;

  /// What the chart is of, and what its axis means. The range lives here
  /// rather than in y-labels, which would crowd a phone for a number that
  /// never changes.
  final String caption;

  /// Whether there is enough history for a line to mean anything.
  ///
  /// One point is not a trend, and an axis with a single dot on it looks
  /// broken rather than new.
  bool get _hasShape => weeks.where((WeekPoint w) => w.hasData).length >= 2;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle? quiet = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Semantics(
      container: true,
      label: _semanticLabel,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WirdiMetrics.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: chartHeight,
                child: _hasShape
                    ? CustomPaint(
                        painter: _ChartPainter(
                          weeks: weeks,
                          maxPerWeek: maxPerWeek,
                          line: scheme.primary,
                          rule: scheme.outline,
                        ),
                      )
                    // The same box, so that the section does not jump down the
                    // screen on the day a second week of history arrives.
                    : Center(
                        child: Text(
                          'A few weeks from now there will be a shape here.',
                          textAlign: TextAlign.center,
                          style: quiet,
                        ),
                      ),
              ),
              const SizedBox(height: WirdiMetrics.space2),
              Text(caption, style: quiet),
            ],
          ),
        ),
      ),
    );
  }

  /// A range and a count, and no word about the direction.
  ///
  /// "Improving", "down from last month", "your best week" are exactly the
  /// judgements the rest of this screen refuses to make, and a chart summary
  /// is where they get made by accident.
  String get _semanticLabel {
    final List<WeekPoint> drawn = weeks
        .where((WeekPoint w) => w.hasData)
        .toList();
    if (drawn.length < 2) {
      return 'Weekly practice. Not enough weeks yet to show.';
    }
    final Iterable<int> counts = drawn.map((WeekPoint w) => w.done);
    return 'Weekly practice over ${drawn.length} weeks. '
        'Between ${counts.reduce((int a, int b) => a < b ? a : b)} and '
        '${counts.reduce((int a, int b) => a > b ? a : b)} days a week.';
  }
}

/// Follows `_VoussoirPainter`'s contract: resolved colours in through the
/// constructor rather than a `Theme.of` inside `paint`, a real
/// [shouldRepaint], and nothing that animates.
class _ChartPainter extends CustomPainter {
  const _ChartPainter({
    required this.weeks,
    required this.maxPerWeek,
    required this.line,
    required this.rule,
  });

  /// The side of a week's marker. A small square, because the calendar's days
  /// are squares and this app has no circles in it.
  static const double markSize = 4;

  final List<WeekPoint> weeks;
  final int maxPerWeek;
  final Color line;
  final Color rule;

  @override
  void paint(Canvas canvas, Size size) {
    if (weeks.isEmpty || maxPerWeek <= 0) return;

    // Room for the marker at full height and at zero, so neither is clipped
    // by the edge of the box.
    final double inset = markSize;
    final double top = inset;
    final double bottom = size.height - inset;
    final double span = bottom - top;

    final Paint rulePaint = Paint()
      ..color = rule
      ..strokeWidth = WirdiMetrics.hairline;

    // Two gridlines: the floor and the ceiling. Intermediates would be a
    // reading aid for a precision this chart is not claiming.
    canvas.drawLine(Offset(0, top), Offset(size.width, top), rulePaint);
    canvas.drawLine(Offset(0, bottom), Offset(size.width, bottom), rulePaint);

    double x(int index) => weeks.length == 1
        ? size.width / 2
        : index * (size.width / (weeks.length - 1));

    double y(int done) =>
        bottom - (done.clamp(0, maxPerWeek) / maxPerWeek) * span;

    final Paint linePaint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      // Hairline is for rules and divisions. A line carrying the data is
      // content, and reads as content at 1.5.
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint markPaint = Paint()..color = line;

    // One path per unbroken run of weeks that have data, so that a gap before
    // the history starts is a gap rather than a segment drawn down to zero.
    Path? path;
    for (final (int i, WeekPoint week) in weeks.indexed) {
      if (!week.hasData) {
        if (path != null) {
          canvas.drawPath(path, linePaint);
          path = null;
        }
        continue;
      }

      final Offset point = Offset(x(i), y(week.done));
      if (path == null) {
        path = Path()..moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }

      canvas.drawRect(
        Rect.fromCenter(center: point, width: markSize, height: markSize),
        markPaint,
      );
    }
    if (path != null) canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_ChartPainter old) {
    if (old.maxPerWeek != maxPerWeek ||
        old.line != line ||
        old.rule != rule ||
        old.weeks.length != weeks.length) {
      return true;
    }
    for (final (int i, WeekPoint week) in weeks.indexed) {
      if (old.weeks[i].done != week.done ||
          old.weeks[i].hasData != week.hasData) {
        return true;
      }
    }
    return false;
  }
}
