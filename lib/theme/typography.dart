import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The bundled families, by the names `pubspec.yaml` registers them under.
///
/// Local assets, never `google_fonts`: the app has to work with the radio off,
/// and Quran text rendered in whatever the platform substitutes is not the same
/// text.
abstract final class WirdiFonts {
  /// Quran text only.
  static const String quran = 'Amiri Quran';

  /// Dhikr and Arabic UI chrome. Weights 400 and 700.
  static const String naskh = 'Noto Naskh Arabic';

  /// Everything Latin. Weights 400 and 500.
  static const String latin = 'Inter';
}

/// An Arabic face, with the optical correction it needs to sit at the same
/// apparent size as Inter.
///
/// ## Where the numbers come from
///
/// A font's nominal size is its em, and how much of that em the letters
/// actually fill is a decision each designer makes differently. Amiri Quran
/// reserves an enormous amount of its em for vocalisation, so its letterforms
/// are small inside it; Inter, a text face with no marks to house, fills more
/// of it. Setting both at 24 gives you Arabic that looks like fine print.
///
/// Measured off the shipped files, per em:
///
/// | | heh (ه) | alef (ا) |
/// |---|---:|---:|
/// | Amiri Quran | 0.355 | 0.696 |
/// | Noto Naskh Arabic | 0.451 | 0.671 |
/// | Inter | 0.546 (x-height) | 0.728 (cap height) |
///
/// Heh is the closed loop that sits on the baseline — the Arabic answer to
/// Latin x-height, and what governs apparent size in a block of text. Alef is
/// the vertical stroke, which reads as an ascender.
///
/// Those two give two different answers. Matching heh to x-height wants
/// 0.546/0.355 = 1.54 for Amiri; matching alef to cap height wants
/// 0.728/0.696 = 1.05. Neither alone is right: the first towers the alefs over
/// the Latin caps, the second leaves the body as small as it started. The
/// factors below are the geometric mean of the two, which is the standard way
/// to split that difference, and which lands where the eye does:
///
///   * Amiri Quran: sqrt(1.05 x 1.54) = 1.27
///   * Noto Naskh Arabic: sqrt(1.08 x 1.21) = 1.15
///
/// They differ because the faces differ, and they have to differ for the app's
/// font-override comparison to be worth anything: swapping Amiri for Noto at
/// one shared multiplier compares two faces at two different optical sizes, and
/// the bigger one always wins. Carrying the factor on the face keeps apparent
/// size fixed while the face changes, which is the only way to see which one
/// actually reads better.
///
/// Tune them. They are the one number in this file that is a judgement call.
enum ArabicFace {
  /// Amiri Quran. Uthmani orthography and Quranic mark positioning.
  quran(WirdiFonts.quran, 1.27),

  /// Noto Naskh Arabic. Dhikr, Arabic chrome, and the comparison face for
  /// Quran text.
  naskh(WirdiFonts.naskh, 1.15);

  const ArabicFace(this.family, this.opticalMultiplier);

  /// The `pubspec.yaml` family name.
  final String family;

  /// Multiplies the nominal size to reach the rendered one. See the enum
  /// comment for how it was arrived at.
  final double opticalMultiplier;
}

/// The type scale, in two parallel definitions.
///
/// Arabic and Latin cannot share a [TextTheme]. They disagree on every axis
/// that matters: the face, the line height, the size that reads as equivalent,
/// and — through [ArabicFace.opticalMultiplier] — the relationship between the
/// number in the type scale and the number handed to the rasteriser. A single
/// scale can express one of those or the other, not both.
///
/// ## Nominal versus rendered size
///
/// Every size named here is *nominal*: the number in the design, and the number
/// a size control shows. For Arabic the rendered size is nominal x
/// [ArabicFace.opticalMultiplier]; for Latin the two are the same. Tuning the
/// optical factor therefore changes what you see without moving the type scale
/// underneath it.
///
/// ## Two user multipliers
///
/// [arabicScale] and [translationScale] are independent, and both are stored as
/// multipliers rather than pixel sizes — a stored pixel size freezes a user's
/// choice against a type scale that will move.
///
///   * [arabicScale] drives the Quran verse, and the dhikr at
///     [dhikrSizeRatio] of it.
///   * [translationScale] drives the translation, and the dhikr caption at
///     [dhikrCaptionRatio] of it.
///
/// Neither touches UI chrome. Section headers, nav, labels and captions are
/// fixed here and follow the OS accessibility text scale alone, which Flutter
/// applies on top of everything. Reading text gets both, which is the point:
/// somebody who has turned the system scale up still wants the Quran larger
/// again relative to the chrome around it.
@immutable
final class WirdiTypography extends ThemeExtension<WirdiTypography> {
  const WirdiTypography({this.arabicScale = 1, this.translationScale = 1});

  /// The user's Arabic size multiplier. 1.0 is [quranVerseSize].
  final double arabicScale;

  /// The user's translation size multiplier. 1.0 is [translationSize].
  final double translationScale;

  // -- Nominal sizes ---------------------------------------------------------

  static const double quranVerseSize = 24;

  /// The dhikr size, as a fraction of the Quran verse size. 24 x 0.83 = 20.
  ///
  /// A ratio rather than its own size so that one Arabic control moves both,
  /// and the relationship between recited Quran and recited dhikr holds
  /// wherever the user puts it.
  static const double dhikrSizeRatio = 0.83;

  static const double translationSize = 15;

  /// The dhikr caption size, as a fraction of the translation size.
  /// 15 x 0.87 = 13.
  static const double dhikrCaptionRatio = 0.87;

  static const double sectionHeaderSize = 17;
  static const double navLabelSize = 14;
  static const double captionSize = 12;

  // -- Line heights ----------------------------------------------------------

  /// Required, not stylistic. Voweled Arabic collides below this.
  ///
  /// Measured on the shipped files: ordinary harakat reach +1.17 em above the
  /// baseline in Amiri Quran and the deepest descenders fall to -0.51 em, so
  /// a fully voweled line occupies about 1.68 em of ink. At 2.0 that leaves
  /// roughly 0.3 em of clearance. Noto Naskh Arabic is looser still, at about
  /// 1.30 em of ink.
  ///
  /// The exception is the rare high annotation marks — U+0615 small high tah
  /// reaches +1.77 em in Amiri Quran — which overrun a 2.0 line. Raising the
  /// whole scale to clear them would cost every other line a third of its
  /// density, so they are left to overrun.
  static const double arabicLineHeight = 2;

  static const double translationLineHeight = 1.6;
  static const double dhikrCaptionLineHeight = 1.5;
  static const double chromeLineHeight = 1.4;

  /// The range a stored multiplier is held to.
  ///
  /// Wide enough for every size control the app offers, narrow enough that a
  /// corrupted settings row cannot render the app unusable.
  static const double minScale = 0.7;
  static const double maxScale = 1.8;

  static double _clamp(double scale) => scale.clamp(minScale, maxScale);

  // -- Arabic ----------------------------------------------------------------

  /// A Quran verse in [ArabicFace.quran].
  TextStyle get quranVerse => quranVerseIn(ArabicFace.quran);

  /// A Quran verse in an explicitly chosen face.
  ///
  /// The size is held constant across faces by [ArabicFace.opticalMultiplier],
  /// so this is a fair comparison rather than a size test.
  TextStyle quranVerseIn(ArabicFace face) =>
      _arabic(face: face, nominalSize: quranVerseSize * _clamp(arabicScale));

  /// A dhikr, in Noto Naskh Arabic.
  TextStyle get dhikr => dhikrIn(ArabicFace.naskh);

  TextStyle dhikrIn(ArabicFace face) => _arabic(
    face: face,
    nominalSize: quranVerseSize * _clamp(arabicScale) * dhikrSizeRatio,
  );

  /// Arabic UI chrome — a surah name in a header, a collection's Arabic title.
  ///
  /// Bold, and outside the user multipliers: it is chrome, and it follows the
  /// OS text scale like the rest of the chrome does.
  TextStyle get arabicChrome => _arabic(
    face: ArabicFace.naskh,
    nominalSize: navLabelSize,
    weight: FontWeight.w700,
    lineHeight: chromeLineHeight,
  );

  TextStyle _arabic({
    required ArabicFace face,
    required double nominalSize,
    FontWeight weight = FontWeight.w400,
    double lineHeight = arabicLineHeight,
  }) {
    return TextStyle(
      fontFamily: face.family,
      fontSize: nominalSize * face.opticalMultiplier,
      fontWeight: weight,
      height: lineHeight,
      // Left at Flutter's default, proportional, deliberately. Amiri Quran's
      // own metrics ask for a 2.45 em line, so a 2.0 line is already tighter
      // than the font wants and the leading being distributed is negative.
      // Splitting that evenly would take it off the descenders, which are the
      // side with no room to give: proportional leaves the ascent, which has
      // slack, to absorb it.
      leadingDistribution: TextLeadingDistribution.proportional,
    );
  }

  // -- Latin -----------------------------------------------------------------

  /// The translation under a verse. Scaled by [translationScale].
  TextStyle get translation => _latin(
    size: translationSize * _clamp(translationScale),
    lineHeight: translationLineHeight,
  );

  /// Transliteration and the source line under a dhikr. Scaled with the
  /// translation, at [dhikrCaptionRatio] of it.
  TextStyle get dhikrCaption => _latin(
    size: translationSize * _clamp(translationScale) * dhikrCaptionRatio,
    lineHeight: dhikrCaptionLineHeight,
  );

  // -- Chrome ----------------------------------------------------------------
  //
  // Fixed. The two user multipliers do not reach any of these.

  TextStyle get sectionHeader => _latin(
    size: sectionHeaderSize,
    weight: FontWeight.w500,
    lineHeight: chromeLineHeight,
  );

  TextStyle get navLabel => _latin(
    size: navLabelSize,
    weight: FontWeight.w500,
    lineHeight: chromeLineHeight,
  );

  TextStyle get caption =>
      _latin(size: captionSize, lineHeight: chromeLineHeight);

  TextStyle _latin({
    required double size,
    FontWeight weight = FontWeight.w400,
    required double lineHeight,
  }) {
    return TextStyle(
      fontFamily: WirdiFonts.latin,
      fontSize: size,
      fontWeight: weight,
      height: lineHeight,
    );
  }

  /// The Material roles, filled from the Latin chrome styles.
  ///
  /// The body roles carry the translation *size* but not its multiplier: they
  /// are what a dialog, a list tile or a snack bar reaches for, and those are
  /// chrome. Reading text goes through [translation] directly.
  TextTheme get materialTextTheme {
    final TextStyle body = _latin(
      size: translationSize,
      lineHeight: translationLineHeight,
    );
    return TextTheme(
      titleLarge: sectionHeader,
      titleMedium: sectionHeader,
      titleSmall: navLabel,
      bodyLarge: body,
      bodyMedium: body,
      bodySmall: caption,
      labelLarge: navLabel,
      labelMedium: navLabel,
      labelSmall: caption,
    );
  }

  @override
  WirdiTypography copyWith({double? arabicScale, double? translationScale}) {
    return WirdiTypography(
      arabicScale: arabicScale ?? this.arabicScale,
      translationScale: translationScale ?? this.translationScale,
    );
  }

  /// Lerps the multipliers rather than the resolved styles, so an interpolated
  /// typography is always one this class could have produced.
  @override
  WirdiTypography lerp(covariant WirdiTypography? other, double t) {
    if (other == null) return this;
    return WirdiTypography(
      arabicScale: lerpDouble(arabicScale, other.arabicScale, t)!,
      translationScale: lerpDouble(
        translationScale,
        other.translationScale,
        t,
      )!,
    );
  }
}
