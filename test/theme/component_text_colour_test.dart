import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/theme/theme.dart';

/// A [TextStyle] with a null colour does not inherit onSurface — `ui.TextStyle`
/// defaults to white. Material components that do not supply a foreground
/// colour of their own therefore paint any such style white, which on a
/// limestone surface is invisible rather than merely wrong.
///
/// Every text style the theme hands to a component must name its colour.
void main() {
  for (final ThemeData theme in <ThemeData>[
    WirdiTheme.light(),
    WirdiTheme.dark(),
  ]) {
    group('${theme.brightness}', () {
      test('the text theme names a colour for every role it defines', () {
        final Map<String, TextStyle?> roles = <String, TextStyle?>{
          'titleLarge': theme.textTheme.titleLarge,
          'titleMedium': theme.textTheme.titleMedium,
          'titleSmall': theme.textTheme.titleSmall,
          'bodyLarge': theme.textTheme.bodyLarge,
          'bodyMedium': theme.textTheme.bodyMedium,
          'bodySmall': theme.textTheme.bodySmall,
          'labelLarge': theme.textTheme.labelLarge,
          'labelMedium': theme.textTheme.labelMedium,
          'labelSmall': theme.textTheme.labelSmall,
        };
        roles.forEach((String name, TextStyle? style) {
          expect(style?.color, isNotNull, reason: '$name has no colour');
        });
      });

      test('component themes name a colour for every text style', () {
        final Map<String, TextStyle?> styles = <String, TextStyle?>{
          'appBarTheme.titleTextStyle': theme.appBarTheme.titleTextStyle,
          'listTileTheme.titleTextStyle': theme.listTileTheme.titleTextStyle,
          'listTileTheme.subtitleTextStyle':
              theme.listTileTheme.subtitleTextStyle,
          'chipTheme.labelStyle': theme.chipTheme.labelStyle,
          'snackBarTheme.contentTextStyle':
              theme.snackBarTheme.contentTextStyle,
          'sliderTheme.valueIndicatorTextStyle':
              theme.sliderTheme.valueIndicatorTextStyle,
        };
        styles.forEach((String name, TextStyle? style) {
          if (style == null) return;
          expect(style.color, isNotNull, reason: '$name has no colour');
        });

        final TextStyle? navLabel = theme.navigationBarTheme.labelTextStyle
            ?.resolve(<WidgetState>{});
        expect(
          navLabel?.color,
          isNotNull,
          reason: 'navigationBarTheme.labelTextStyle has no colour',
        );
      });

      test('a ListTile title is not the surface it sits on', () {
        // The specific failure this class of bug produced.
        expect(
          theme.listTileTheme.titleTextStyle?.color,
          isNot(theme.colorScheme.surface),
        );
        expect(
          theme.listTileTheme.titleTextStyle?.color,
          theme.colorScheme.onSurface,
        );
      });
    });
  }
}
