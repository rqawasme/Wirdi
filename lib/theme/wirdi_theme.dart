import 'package:flutter/material.dart';

import 'color_schemes.dart';
import 'metrics.dart';
import 'motion.dart';
import 'typography.dart';

/// Assembles the two [ThemeData]s.
///
/// Three rules run through every override below:
///
///   * **Elevation is zero everywhere and nothing casts a shadow.** Depth comes
///     from the surface ladder and hairline outlines. Material's defaults lift
///     cards, dialogs, sheets and app bars, so each is put back down by hand.
///   * **Buttons are squared.** Material 3 gives every button a stadium shape;
///     all four button themes override it to [WirdiMetrics.buttonRadius].
///   * **Gold stays on `tertiary`.** Nothing here maps `tertiary` onto a
///     component. If gold shows up in the UI, a component has reached for the
///     wrong role, and that is the signal, not a bug in this file.
abstract final class WirdiTheme {
  static ThemeData light({
    WirdiTypography typography = const WirdiTypography(),
  }) => _build(WirdiColorSchemes.light, typography);

  static ThemeData dark({
    WirdiTypography typography = const WirdiTypography(),
  }) => _build(WirdiColorSchemes.dark, typography);

  static ThemeData of(
    Brightness brightness, {
    WirdiTypography typography = const WirdiTypography(),
  }) => switch (brightness) {
    Brightness.light => light(typography: typography),
    Brightness.dark => dark(typography: typography),
  };

  static ThemeData _build(ColorScheme scheme, WirdiTypography typography) {
    final BorderSide hairline = BorderSide(
      color: scheme.outlineVariant,
      width: WirdiMetrics.hairline,
    );
    // Coloured here, not left to ThemeData.
    //
    // WirdiTypography deliberately sets no colours — a reading style that
    // carries one cannot be recoloured by its surroundings. ThemeData fills them
    // in for `textTheme`, but the component themes below are built from this
    // object directly, and a TextStyle handed to a component with a null colour
    // does not fall back to onSurface: `ui.TextStyle` defaults to **white**. So
    // a ListTile title came out cream on cream, which is invisible rather than
    // merely wrong. `test/theme/component_text_colour_test.dart` keeps it fixed.
    final TextTheme text = typography.materialTextTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      colorScheme: scheme,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      // Belt and braces against the elevation rule: even if something takes an
      // elevation, it has no colour to draw the shadow in.
      shadowColor: Colors.transparent,
      fontFamily: WirdiFonts.latin,
      textTheme: text,
      splashFactory: InkRipple.splashFactory,

      extensions: <ThemeExtension<dynamic>>[
        typography,
        const WirdiMotion.standardTiming(),
      ],

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: WirdiMetrics.elevation,
        // Material raises and tints the app bar once content scrolls under it.
        // Left alone this is the one place a shadow would still appear.
        scrolledUnderElevation: WirdiMetrics.elevation,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),

      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: WirdiMetrics.elevation,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: WirdiMetrics.card,
          side: hairline,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: WirdiMetrics.hairline,
        space: WirdiMetrics.hairline,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        modalBackgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: WirdiMetrics.elevation,
        modalElevation: WirdiMetrics.elevation,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(borderRadius: WirdiMetrics.sheet),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: WirdiMetrics.elevation,
        shape: const RoundedRectangleBorder(borderRadius: WirdiMetrics.dialog),
      ),

      // 4dp, and outlined rather than filled: a chip is a label, not a button.
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: WirdiMetrics.elevation,
        pressElevation: WirdiMetrics.elevation,
        labelStyle: text.labelLarge,
        side: hairline,
        shape: const RoundedRectangleBorder(borderRadius: WirdiMetrics.chip),
      ),

      filledButtonTheme: FilledButtonThemeData(style: _buttonStyle(text)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle(text)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonStyle(text)),
      textButtonTheme: TextButtonThemeData(style: _buttonStyle(text)),
      // Its default is a stadium too, and it is the shape most likely to be
      // reached for by a settings row.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: _buttonStyle(text).copyWith(
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: scheme.outline, width: WirdiMetrics.hairline),
          ),
        ),
      ),

      listTileTheme: ListTileThemeData(
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        iconColor: scheme.onSurfaceVariant,
        shape: const RoundedRectangleBorder(borderRadius: WirdiMetrics.card),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: WirdiMetrics.elevation,
        // Tonal, not brick and certainly not gold, and squared off like
        // everything else: the default indicator is a stadium pill.
        indicatorColor: scheme.surfaceContainerHigh,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: WirdiMetrics.card,
        ),
        labelTextStyle: WidgetStatePropertyAll<TextStyle?>(text.labelMedium),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.08),
        valueIndicatorColor: scheme.inverseSurface,
        valueIndicatorTextStyle: text.labelMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        elevation: WirdiMetrics.elevation,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: WirdiMetrics.card),
      ),
    );
  }

  /// One shape and one elevation for every button in the app.
  static ButtonStyle _buttonStyle(TextTheme text) {
    return ButtonStyle(
      elevation: const WidgetStatePropertyAll<double>(WirdiMetrics.elevation),
      shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: WirdiMetrics.button),
      ),
    );
  }
}
