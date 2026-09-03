import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// A short label on a squared plate — 4dp, the same radius as the counter,
/// outlined in a hairline and filled with the first rung of the surface
/// ladder.
///
/// Not a pill and not a badge. It is used for a number that belongs to a row
/// rather than to the reader: a surah number, an item's count.
class Plate extends StatelessWidget {
  const Plate({super.key, required this.label, this.square = false});

  /// The side of a square plate, and the minimum height of a wide one.
  static const double size = WirdiMetrics.space6 + WirdiMetrics.space2;

  final String label;

  /// Fixes the width to [size], for a plate holding one or two digits.
  final bool square;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: square ? size : null,
      height: size,
      alignment: Alignment.center,
      padding: square
          ? null
          : const EdgeInsets.symmetric(horizontal: WirdiMetrics.space2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: WirdiMetrics.chip,
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: WirdiMetrics.hairline,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A [Plate] holding a number, sized square.
class NumberPlate extends StatelessWidget {
  const NumberPlate({super.key, required this.number});

  static const double size = Plate.size;

  final int number;

  @override
  Widget build(BuildContext context) => Plate(label: '$number', square: true);
}
