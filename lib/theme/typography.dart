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
  /// Noto Naskh Arabic. Everything the app sets in Arabic.
  ///
  /// It is the Quran face as well as the dhikr face. It reads better than
  /// Amiri Quran at this size, and it is the only one of the two that covers
  /// the text: see [amiriQuran].
  notoNaskh(WirdiFonts.naskh, 1.15),

  /// Amiri Quran. Bundled for comparison in the dev screen, and set by nothing
  /// the app ships.
  ///
  /// It has no glyph for U+065E ARABIC FATHA WITH TWO DOTS, which the Uthmani
  /// text uses 1,807 times across 1,241 ayahs — a fifth of the mushaf. A
  /// device would fall back to some system Arabic face for that one mark,
  /// mid-word, which looks almost right. `tool/check_font_coverage.py` is what
  /// keeps that from going unnoticed again.
  amiriQuran(WirdiFonts.quran, 1.27);

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

  /// The wird player's remaining-count readout. Chrome, and the largest thing
  /// on that screen by a distance: it is what the eye returns to between
  /// repetitions without reading.
  static const double counterSize = 44;

  static const double sectionHeaderSize = 17;
  static const double navLabelSize = 14;
  static const double captionSize = 12;

  /// The name on a home-screen tile.
  ///
  /// The same 15 as [translationSize] and emphatically not the same style:
  /// this is chrome, so it is fixed here and the translation multiplier does
  /// not reach it. A tile is a fixed square, and a user who has turned reading
  /// text up to read the Quran has not asked for the names of their
  /// collections to stop fitting in it.
  static const double tileNameSize = 15;

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

  /// Tighter than [chromeLineHeight] because a tile name is the one piece of
  /// chrome that routinely runs to three lines, in a box that cannot grow: the
  /// leading that gives a single-line label air costs a wrapped name a line.
  static const double tileNameLineHeight = 1.35;

  /// The range a stored multiplier is held to.
  ///
  /// Wide enough for every size control the app offers, narrow enough that a
  /// corrupted settings row cannot render the app unusable.
  static const double minScale = 0.7;
  static const double maxScale = 1.8;

  static double _clamp(double scale) => scale.clamp(minScale, maxScale);

  // -- Arabic ----------------------------------------------------------------

  /// A Quran verse.
  ///
  /// Quran and dhikr are set in the same face and separated by size alone,
  /// which is why [dhikrSizeRatio] carries the distinction.
  TextStyle get quranVerse => quranVerseIn(ArabicFace.notoNaskh);

  /// A Quran verse in an explicitly chosen face.
  ///
  /// The size is held constant across faces by [ArabicFace.opticalMultiplier],
  /// so this is a fair comparison rather than a size test.
  TextStyle quranVerseIn(ArabicFace face) =>
      _arabic(face: face, nominalSize: quranVerseSize * _clamp(arabicScale));

  /// A dhikr.
  TextStyle get dhikr => dhikrIn(ArabicFace.notoNaskh);

  TextStyle dhikrIn(ArabicFace face) => _arabic(
    face: face,
    nominalSize: quranVerseSize * _clamp(arabicScale) * dhikrSizeRatio,
  );

  /// An Arabic name given prominence — the surah name in a list row, where it
  /// is the thing being scanned for rather than a label beside something else.
  ///
  /// Chrome, so outside the user multipliers: the surah list's layout should
  /// not reflow because the reading size changed.
  TextStyle get arabicTitle => _arabic(
    face: ArabicFace.notoNaskh,
    nominalSize: sectionHeaderSize,
    weight: FontWeight.w700,
    lineHeight: chromeLineHeight,
  );

  /// Arabic UI chrome beside something else — a label, a collection's Arabic
  /// title, the sajdah mark.
  ///
  /// Bold, and outside the user multipliers: it is chrome, and it follows the
  /// OS text scale like the rest of the chrome does.
  TextStyle get arabicChrome => _arabic(
    face: ArabicFace.notoNaskh,
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
      fontFamilyFallback: _arabicFallback,
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

  /// The remaining count in the wird player.
  ///
  /// Tabular figures, which is the whole reason this is not just a large
  /// [sectionHeader]. Inter's proportional `1` is narrower than its `7`, so a
  /// count changing on every tap would shift sideways as it went — the exact
  /// movement the zero-animation rule on the counter exists to prevent, and
  /// far more visible at 44px than anywhere else in the app.
  TextStyle get counter => _latin(
    size: counterSize,
    weight: FontWeight.w500,
    lineHeight: 1.1,
  ).copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]);

  TextStyle get sectionHeader => _latin(
    size: sectionHeaderSize,
    weight: FontWeight.w500,
    lineHeight: chromeLineHeight,
  );

  /// The name on a home-screen tile: the one thing on it that is read rather
  /// than glanced at, so it carries the weight and the others stay quiet.
  TextStyle get tileName => _latin(
    size: tileNameSize,
    weight: FontWeight.w500,
    lineHeight: tileNameLineHeight,
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
      fontFamilyFallback: _latinFallback,
      fontSize: size,
      fontWeight: weight,
      height: lineHeight,
    );
  }

  /// The Saheeh International translation carries U+FDFA — the
  /// sallallahu-alayhi-wasallam ligature — inline, 36 times, in the middle of
  /// English sentences. Inter has no glyph for it, and a Latin text face has no
  /// business owning one.
  ///
  /// Without this the platform picks the substitute itself, so the mark comes
  /// out of a different face on iOS than on Android and out of nothing at all
  /// where the fallback chain is thin. Naming the fallback means it comes from
  /// a font that ships in the bundle, and looks the same everywhere.
  ///
  /// `tool/check_font_coverage.py` records this as an accepted gap; adding a
  /// Latin codepoint Inter lacks will fail there rather than here.
  static const List<String> _latinFallback = <String>[WirdiFonts.naskh];

  /// The same trick in the other direction, for one character: **U+2026**, the
  /// ellipsis.
  ///
  /// Neither Noto Naskh Arabic nor Amiri Quran has a glyph for it, and an
  /// Arabic name set on one line in a fixed-width tile is truncated with one.
  /// Without this the mark comes out as an empty box where there is no
  /// fallback chain, and out of whatever the platform picks where there is —
  /// the same silent substitution `tool/check_font_coverage.py` exists to
  /// catch, arriving through the ellipsis rather than through the text.
  ///
  /// Inter supplies nothing else here: it has no Arabic coverage at all, so a
  /// genuinely missing Arabic mark still renders as the box it should, and
  /// this cannot mask a gap in the Arabic faces.
  static const List<String> _arabicFallback = <String>[WirdiFonts.latin];

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
