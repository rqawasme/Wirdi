import 'package:flutter/material.dart';

/// The Córdoba voussoir motif: a band of alternating wedges, the way the
/// arches of the Mezquita alternate brick and stone.
///
/// Used functionally rather than as ornament. In [VoussoirStripe.rule] it is a
/// section divider; in [VoussoirStripe.progress] it is the progress bar, and
/// the same motif carries both so that progress reads as the rule filling in
/// rather than as a different component arriving.
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
      segments = null;

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
  }) : assert(
         segments == null || segments > 0,
         'a stripe has segments or it '
         'has a segment width, and zero of them is neither',
       );

  /// Three base spacing units.
  static const double segmentWidth = 12;

  static const double ruleHeight = 4;
  static const double progressHeight = 6;

  /// Null in rule mode. 0..1 in progress mode.
  final double? value;

  /// A fixed number of segments across the width, or null to cut them at
  /// [segmentWidth]. Progress mode only.
  final int? segments;

  final double height;

  bool get _isRule => value == null;

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
        ),
      ),
    );

    if (_isRule) {
      // A divider, and nothing a screen reader needs to stop on.
      return ExcludeSemantics(child: stripe);
    }
    return Semantics(
      container: true,
      value: '${(value! * 100).round()}%',
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
  });

  final Color filled;
  final Color unfilled;
  final double? value;
  final int? segments;

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
    // finished.
    final int? litSegments = value == null
        ? null
        : (value!.clamp(0.0, 1.0) * count).floor();

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
        oldDelegate.segments != segments;
  }
}
