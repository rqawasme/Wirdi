import 'package:flutter/material.dart';

/// The Córdoba voussoir motif: a band of alternating wedges, the way the
/// arches of the Mezquita alternate brick and stone.
///
/// Used functionally rather than as ornament. In [VoussoirStripe.rule] it is a
/// section divider; in [VoussoirStripe.progress] it is the progress bar, and
/// the same motif carries both so that progress reads as the rule filling in
/// rather than as a different component arriving.
///
/// Segments are a fixed [segmentWidth] and butt against each other with no
/// gaps — voussoirs are wedges in an arch, not dashes. The count therefore
/// falls out of the available width, and the last segment is clipped where the
/// width does not divide evenly, which keeps the rhythm exact all the way
/// across instead of leaving a ragged end.
class VoussoirStripe extends StatelessWidget {
  /// A plain rule, alternating [ColorScheme.primary] and
  /// [ColorScheme.surfaceContainerHigh] along its whole length.
  const VoussoirStripe.rule({super.key, this.height = ruleHeight})
    : value = null;

  /// A progress indicator. Segments up to [value] are
  /// [ColorScheme.primary]; the rest are [ColorScheme.surfaceContainerHigh].
  ///
  /// [value] is a fraction from 0 to 1. It is quantised down to whole
  /// segments, so the stripe reads as full only when it is genuinely full.
  ///
  /// **Nothing animates.** The fill is painted where it is, on the frame it
  /// changes. This is the counter's indicator, and a counter that eases into
  /// position is a counter that is lying about where it is.
  const VoussoirStripe.progress({
    super.key,
    required double this.value,
    this.height = progressHeight,
  });

  /// Three base spacing units.
  static const double segmentWidth = 12;

  static const double ruleHeight = 4;
  static const double progressHeight = 6;

  /// Null in rule mode. 0..1 in progress mode.
  final double? value;

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
  });

  final Color filled;
  final Color unfilled;
  final double? value;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final int segments = (size.width / VoussoirStripe.segmentWidth).ceil();
    // Quantised down, not rounded: 96% of the way through should not look
    // finished.
    final int? litSegments = value == null
        ? null
        : (value!.clamp(0.0, 1.0) * segments).floor();

    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < segments; i++) {
      final double left = i * VoussoirStripe.segmentWidth;
      // The last segment is clipped by the stripe's own width rather than
      // overhanging it.
      final double right = (left + VoussoirStripe.segmentWidth).clamp(
        0.0,
        size.width,
      );
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
        oldDelegate.value != value;
  }
}
