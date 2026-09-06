import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/theme/theme.dart';

/// A selected segment has to be obviously selected.
///
/// Depth in this app is tonal — surface, then surfaceContainer, then
/// surfaceContainerHigh — and that is right for depth and wrong for selection.
/// Material fills a selected segment with a tonal step, which against a tonal
/// surface is a difference you have to hunt for; on a row of seven days it is
/// one you can get wrong without noticing, and somebody did: a day picker set
/// to the opposite of what they meant, and a home screen that looked broken as
/// a result.
///
/// So selection is brick, the same colour that marks the selected tab in the
/// navigation bar. These pin that, because the failure it prevents is one no
/// behavioural test can see — every one of them passed while the control was
/// unreadable.
void main() {
  for (final ThemeData theme in <ThemeData>[
    WirdiTheme.light(),
    WirdiTheme.dark(),
  ]) {
    final ColorScheme scheme = theme.colorScheme;
    final ButtonStyle? style = theme.segmentedButtonTheme.style;

    Color? background(Set<WidgetState> states) =>
        style?.backgroundColor?.resolve(states);
    Color? foreground(Set<WidgetState> states) =>
        style?.foregroundColor?.resolve(states);

    group('${theme.brightness} segmented button', () {
      test('a selected segment is brick, and its label is legible on it', () {
        expect(background(<WidgetState>{WidgetState.selected}), scheme.primary);
        expect(
          foreground(<WidgetState>{WidgetState.selected}),
          scheme.onPrimary,
        );
      });

      test('an unselected segment is the plain surface', () {
        expect(background(<WidgetState>{}), scheme.surface);
        expect(foreground(<WidgetState>{}), scheme.onSurfaceVariant);
      });

      test('the two states are not a tonal step apart', () {
        // The bug this exists for: selected and unselected differing by one
        // tonal step, which reads as no difference at all.
        final Color? selected = background(<WidgetState>{WidgetState.selected});
        expect(selected, isNot(scheme.surface));
        expect(selected, isNot(scheme.surfaceContainer));
        expect(selected, isNot(scheme.surfaceContainerHigh));
        expect(selected, isNot(scheme.surfaceContainerHighest));
      });

      test('and selection is never gold', () {
        // The one colour claimed by nothing. A selected state reaching for it
        // would be the tripwire going off.
        expect(
          background(<WidgetState>{WidgetState.selected}),
          isNot(scheme.tertiary),
        );
      });
    });
  }
}
