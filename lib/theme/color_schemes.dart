import 'package:flutter/material.dart';

/// The two palettes, written out literally.
///
/// Neither is seeded. [ColorScheme.fromSeed] derives every role from one hue,
/// which would drag the limestone surfaces toward brick and throw away the
/// point of the palette: warm stone, one clay accent, and gold held back for
/// Quran text.
///
/// Dark is designed on its own terms, not produced by inverting light. The one
/// place the two do meet is [ColorScheme.inverseSurface] and friends, where
/// each theme genuinely wants the other's colours.
///
/// ## Roles the design does not name
///
/// The brief fixes twelve roles. [ColorScheme] has thirty-odd, and every one of
/// them is painted by something eventually, so the rest are filled here rather
/// than left to a default that would reach for `primary`:
///
///   * **Surface ladder.** The brief gives three rungs — surface,
///     surfaceContainer, surfaceContainerHigh. Material wants eight. The
///     others continue the same step (about -5 red, -7 green, -11 blue per rung
///     in light; the reverse in dark) rather than introducing a new hue.
///   * **Secondary.** There is no second accent in this design: it is brick and
///     gold on stone, and gold is spoken for. So the secondary family is mapped
///     onto the neutral axis — anything reaching for it renders as quiet
///     chrome instead of inventing a third colour.
///   * **Tertiary container.** Kept recognisably gold. Gold appearing where it
///     was not intended is the tripwire that says a component picked the wrong
///     role, and that only works if the whole tertiary family looks like gold.
///   * **Shadow.** Transparent in both. Depth here is tonal, and a shadow
///     colour that cannot paint anything is a stronger guarantee than an
///     elevation of zero that someone later overrides.
///   * **Surface tint.** Also transparent. Material 3 tints elevated surfaces
///     toward `surfaceTint`, which defaults to `primary`; left alone, the first
///     component to take an elevation would go pink.
abstract final class WirdiColorSchemes {
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,

    // Brick.
    primary: Color(0xFF9E4630),
    onPrimary: Color(0xFFFBF6EC),
    primaryContainer: Color(0xFFF2DCD3),
    // The dark theme's brick container, which is the deepest brick in the
    // palette and the only one that carries on pale clay.
    onPrimaryContainer: Color(0xFF5C2717),

    // Neutral, standing in for a second accent this design does not have.
    secondary: Color(0xFF5F5040),
    onSecondary: Color(0xFFFBF6EC),
    secondaryContainer: Color(0xFFF0E6D4),
    onSecondaryContainer: Color(0xFF241C15),

    // Gold. Quran text only — see the class comment.
    tertiary: Color(0xFF8A6A2E),
    onTertiary: Color(0xFFFBF6EC),
    tertiaryContainer: Color(0xFFEFE2C4),
    onTertiaryContainer: Color(0xFF4A3813),

    error: Color(0xFFC0392B),
    onError: Color(0xFFFBF6EC),
    errorContainer: Color(0xFFF7DDD9),
    onErrorContainer: Color(0xFF6E1D14),

    // Limestone, palest to deepest.
    surface: Color(0xFFFBF6EC),
    onSurface: Color(0xFF241C15),
    surfaceDim: Color(0xFFE9DDC6),
    surfaceBright: Color(0xFFFDFAF3),
    surfaceContainerLowest: Color(0xFFFFFCF6),
    surfaceContainerLow: Color(0xFFF8F2E5),
    surfaceContainer: Color(0xFFF5EDDF),
    surfaceContainerHigh: Color(0xFFF0E6D4),
    surfaceContainerHighest: Color(0xFFEBDFC9),
    onSurfaceVariant: Color(0xFF5F5040),

    outline: Color(0xFFD8C9B2),
    outlineVariant: Color(0xFFEADFCC),

    // Depth is tonal; nothing casts a shadow.
    shadow: Color(0x00000000),
    surfaceTint: Color(0x00000000),
    // Warm, so a modal barrier reads as the room darkening rather than as a
    // grey sheet laid over it.
    scrim: Color(0xFF241C15),

    // Borrowed wholesale from the dark theme, which is what an inverse surface
    // is for.
    inverseSurface: Color(0xFF2A211A),
    onInverseSurface: Color(0xFFEFE5D6),
    inversePrimary: Color(0xFFC96A4E),
  );

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,

    // Brick, lifted and softened: the light theme's #9E4630 is too dense to
    // read as an accent against near-black.
    primary: Color(0xFFC96A4E),
    onPrimary: Color(0xFF2A1109),
    primaryContainer: Color(0xFF5C2717),
    onPrimaryContainer: Color(0xFFF2DCD3),

    secondary: Color(0xFFA5947F),
    onSecondary: Color(0xFF191410),
    secondaryContainer: Color(0xFF2A211A),
    onSecondaryContainer: Color(0xFFEFE5D6),

    tertiary: Color(0xFFCBA45C),
    onTertiary: Color(0xFF2A211A),
    tertiaryContainer: Color(0xFF4A3813),
    onTertiaryContainer: Color(0xFFEFE2C4),

    error: Color(0xFFF08076),
    onError: Color(0xFF2A1109),
    errorContainer: Color(0xFF6B211A),
    onErrorContainer: Color(0xFFF7DDD9),

    surface: Color(0xFF191410),
    onSurface: Color(0xFFEFE5D6),
    surfaceDim: Color(0xFF191410),
    surfaceBright: Color(0xFF3A2E24),
    surfaceContainerLowest: Color(0xFF100D0B),
    surfaceContainerLow: Color(0xFF1E1813),
    surfaceContainer: Color(0xFF221B15),
    surfaceContainerHigh: Color(0xFF2A211A),
    surfaceContainerHighest: Color(0xFF32271F),
    onSurfaceVariant: Color(0xFFA5947F),

    outline: Color(0xFF33281F),
    outlineVariant: Color(0xFF2A211A),

    shadow: Color(0x00000000),
    surfaceTint: Color(0x00000000),
    // Black rather than ink: there is no warm ground left to darken.
    scrim: Color(0xFF000000),

    inverseSurface: Color(0xFFF0E6D4),
    onInverseSurface: Color(0xFF241C15),
    inversePrimary: Color(0xFF9E4630),
  );
}
