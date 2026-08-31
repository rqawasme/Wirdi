import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// A reading-size control that reads in pixels and stores a multiplier.
///
/// The user is choosing a size they can see, so the label is in pixels. What
/// gets persisted is [scale], because a stored pixel size freezes that choice
/// against a type scale that will move — a 24 chosen today would stop meaning
/// "the default" the moment the default changed.
///
/// [onChanged] is called on every frame of a drag with `commit: false` and once
/// on release with `commit: true`. Applying continuously is what makes the
/// preview useful; writing continuously would put a database write behind every
/// frame of a gesture the user has not finished making.
class TextSizeSlider extends StatelessWidget {
  const TextSizeSlider({
    super.key,
    required this.label,
    required this.nominalSize,
    required this.scale,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;

  /// The size a scale of 1.0 renders at.
  final double nominalSize;

  final double scale;
  final double min;
  final double max;
  final void Function(double scale, {required bool commit}) onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double pixels = (scale * nominalSize).clamp(min, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            // Chrome, so this label is at a fixed size: the sliders move the
            // reading text and nothing else, including their own labels.
            Text(label, style: theme.textTheme.labelLarge),
            const Spacer(),
            Text(
              '${pixels.round()} px',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Slider(
          value: pixels,
          min: min,
          max: max,
          divisions: (max - min).round(),
          label: '${pixels.round()} px',
          semanticFormatterCallback: (double value) =>
              '$label ${value.round()} pixels',
          onChanged: (double v) => onChanged(v / nominalSize, commit: false),
          onChangeEnd: (double v) => onChanged(v / nominalSize, commit: true),
        ),
      ],
    );
  }
}

/// A labelled segmented choice, squared off like every other button.
class SettingChoice<T> extends StatelessWidget {
  const SettingChoice({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final void Function(T) onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: WirdiMetrics.space2),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            segments: <ButtonSegment<T>>[
              for (final MapEntry<T, String> option in options.entries)
                ButtonSegment<T>(value: option.key, label: Text(option.value)),
            ],
            selected: <T>{value},
            onSelectionChanged: (Set<T> selection) =>
                onChanged(selection.first),
          ),
        ),
      ],
    );
  }
}
