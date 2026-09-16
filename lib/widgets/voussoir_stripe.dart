import 'package:flutter/material.dart';

/// The Córdoba voussoir motif: a band of alternating wedges, the way the
/// arches of the Mezquita alternate brick and stone.
///
/// Used functionally rather than as ornament. In [VoussoirStripe.rule] it is a
/// section divider; in [VoussoirStripe.progress] and [VoussoirStripe.counted]
/// it is the progress bar, and the same motif carries all three so that
/// progress reads as the rule filling in rather than as a different component
/// arriving.
///
/// Segments butt against each other with no gaps — voussoirs are wedges in an
/// arch, not dashes. By default they are a fixed [segmentWidth], so the count
/// falls out of the available width and the last one is clipped where the width
/// does not divide evenly, which keeps the rhythm exact all the way across
/// instead of leaving a ragged end. A progress stripe that is counting
/// something discrete instead names its own segment count and divides the width
/// between them — see [VoussoirStripe.progress].
class VoussoirStripe extends StatelessWidget {
  /// A plain rule, alternating [ColorScheme.primary] and
  /// [ColorScheme.surfaceContainerHigh] along its whole length.
  const VoussoirStripe.rule({super.key, this.height = ruleHeight})
    : value = null,
      segments = null,
      lit = null;

  /// A progress indicator. Segments up to [value] are
  /// [ColorScheme.primary]; the rest are [ColorScheme.surfaceContainerHigh].
  ///
  /// [value] is a fraction from 0 to 1. It is quantised down to whole
  /// segments, so the stripe reads as full only when it is genuinely full.
  ///
  /// [segments] fixes how many segments the width is divided into, for a
  /// stripe that is counting something. The wird player passes the step's
  /// repetition count, so a tasbih of thirty-three lights one segment per tap
  /// and a count of a hundred lights one roughly every third tap. Left null it
  /// falls back to [segmentWidth], which is what a stripe measuring something
  /// continuous wants.
  ///
  /// **Nothing animates.** The fill is painted where it is, on the frame it
  /// changes. This is the counter's indicator, and a counter that eases into
  /// position is a counter that is lying about where it is.
  const VoussoirStripe.progress({
    super.key,
    required double this.value,
    this.segments,
    this.height = progressHeight,
  }) : lit = null,
       assert(
         segments == null || segments > 0,
         'a stripe has segments or it '
         'has a segment width, and zero of them is neither',
       );

  /// A progress indicator for something counted, given as the count itself:
  /// [lit] segments of [of] are [ColorScheme.primary].
  ///
  /// The same picture [VoussoirStripe.progress] draws, without the trip
  /// through a fraction — which is not a detail. `lit / of * of` is not
  /// reliably `lit` in binary floating point (37 of 100 is one of the pairs it
  /// is not), so a stripe told its position as a fraction of a hundred stalls
  /// on three of those hundred counts. A counter must move on every count it
  /// is given, so a stripe that is counting something takes the count.
  const VoussoirStripe.counted({
    super.key,
    required int this.lit,
    required int of,
    this.height = progressHeight,
  }) : value = null,
       segments = of,
       assert(of > 0, 'a counted stripe has segments to count'),
       assert(lit >= 0 && lit <= of, 'lit is a position in 0..of');

  /// Three base spacing units.
  static const double segmentWidth = 12;

  static const double ruleHeight = 4;
  static const double progressHeight = 6;

  /// Null in rule mode and in counted mode. 0..1 in progress mode.
  final double? value;

  /// A fixed number of segments across the width, or null to cut them at
  /// [segmentWidth]. Never null in counted mode.
  final int? segments;

  /// How many segments are lit, in counted mode. Null in the other two.
  final int? lit;

  final double height;

  bool get _isRule => value == null && lit == null;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget stripe = SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _VoussoirPainter(
          filled: scheme.primary,
          unfilled: scheme.surfaceContainerHigh,
          value: value,
          segments: segments,
          lit: lit,
        ),
      ),
    );

    if (_isRule) {
      // A divider, and nothing a screen reader needs to stop on.
      return ExcludeSemantics(child: stripe);
    }
    return Semantics(
      container: true,
      value: lit == null ? '${(value! * 100).round()}%' : '$lit of $segments',
      child: stripe,
    );
  }
}

class _VoussoirPainter extends CustomPainter {
  const _VoussoirPainter({
    required this.filled,
    required this.unfilled,
    required this.value,
    this.segments,
    this.lit,
  });

  /// The slack in the quantisation below.
  ///
  /// `k / n * n` is not reliably `k` in binary floating point — at 51 steps it
  /// is 30.999999999999996 for the thirty-first — and a bare floor of that is
  /// a segment short exactly when a step has just been completed, which is the
  /// moment the stripe is being looked at. Small enough that it cannot light a
  /// segment that is genuinely part way through: it takes a value within a
  /// billionth of the boundary to round up, and a step of a thousand moves the
  /// value by a thousandth.
  static const double _boundarySlack = 1e-9;

  final Color filled;
  final Color unfilled;
  final double? value;
  final int? segments;
  final int? lit;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // A fixed count divides the width exactly; otherwise the count falls out
    // of the width at the fixed segment width and the last one is clipped.
    final int count =
        segments ?? (size.width / VoussoirStripe.segmentWidth).ceil();
    final double width = segments == null
        ? VoussoirStripe.segmentWidth
        : size.width / segments!;

    // Quantised down, not rounded: 96% of the way through should not look
    // finished. A counted stripe was given the number outright and needs no
    // quantising at all.
    final int? litSegments = switch ((lit, value)) {
      (final int lit, _) => lit,
      (_, final double value) =>
        (value.clamp(0.0, 1.0) * count + _boundarySlack).floor(),
      _ => null,
    };

    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final double left = i * width;
      // The last segment is clipped by the stripe's own width rather than
      // overhanging it.
      final double right = (left + width).clamp(0.0, size.width);
      if (right <= left) break;

      paint.color = switch (litSegments) {
        // Rule mode: alternate the whole way along.
        null => i.isEven ? filled : unfilled,
        final int lit => i < lit ? filled : unfilled,
      };
      canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_VoussoirPainter oldDelegate) {
    return oldDelegate.filled != filled ||
        oldDelegate.unfilled != unfilled ||
        oldDelegate.value != value ||
        oldDelegate.segments != segments ||
        oldDelegate.lit != lit;
  }
}
