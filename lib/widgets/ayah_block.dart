import 'package:flutter/material.dart';

import '../domain/content.dart';
import '../quran/uthmani_text.dart';
import '../theme/theme.dart';
import 'translation_text.dart';

/// One verse: Arabic, its number, and the translation beneath.
///
/// The same widget the reading view scrolls and the settings screen previews,
/// so a size change is judged against what it will actually look like.
///
/// Quran text is set in [ColorScheme.onSurface] cedar ink rather than
/// `tertiary` gold — decided in phase 3 by looking at both on a device. It is
/// left to the ambient text colour rather than set explicitly, which is what
/// makes the absence of gold here deliberate and visible.
class AyahBlock extends StatelessWidget {
  const AyahBlock({
    super.key,
    required this.ayah,
    required this.surahName,
    this.showTranslation = true,
  });

  final Ayah ayah;

  /// For the semantics label. A screen reader announcing "ayah 5" without
  /// saying which surah has told the listener almost nothing.
  final String surahName;

  final bool showTranslation;

  /// Arabic content is marked with this so the engine picks Arabic shaping and
  /// digit conventions, and so a screen reader switches voice rather than
  /// spelling the text out in the UI language.
  static const Locale arabic = Locale('ar');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;

    final String verse = UthmaniText.withoutAyahNumber(ayah.textUthmani);

    return Semantics(
      container: true,
      label: 'Surah $surahName, ayah ${ayah.ayahNumber}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: WirdiMetrics.verseBlockSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Genuinely right-to-left rather than right-aligned: the shaper
            // needs the paragraph direction to order runs, place the verse
            // marker at the end of the line and break lines correctly.
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                // The marker is part of the text run, so it sits at the end of
                // the last line and wraps with it, the way a mushaf sets it —
                // rather than being a widget bolted onto the side.
                UthmaniText.verseWithMarker(ayah.textUthmani, ayah.ayahNumber),
                style: type.quranVerse,
                locale: arabic,
                // Without the ornament, which has nothing to say out loud.
                semanticsLabel: verse,
              ),
            ),
            if (ayah.sajdah) ...<Widget>[
              const SizedBox(height: WirdiMetrics.space2),
              const _SajdahMarker(),
            ],
            if (showTranslation) ...<Widget>[
              const SizedBox(height: WirdiMetrics.space3),
              TranslationText(ayah.translation, style: type.translation),
            ],
          ],
        ),
      ),
    );
  }
}

/// The place-of-sajdah mark, on the fifteen ayahs that carry one.
///
/// U+06E9 in the Arabic face rather than a Material icon: it is the mark the
/// mushaf uses, both bundled faces have it, and an icon would be a translation
/// of a symbol that needs none.
class _SajdahMarker extends StatelessWidget {
  const _SajdahMarker();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final Color colour = theme.colorScheme.onSurfaceVariant;

    return Semantics(
      container: true,
      label: 'Place of prostration',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              UthmaniText.placeOfSajdah,
              style: type.arabicChrome.copyWith(color: colour),
              locale: AyahBlock.arabic,
            ),
            const SizedBox(width: WirdiMetrics.space2),
            Text(
              'Sajdah',
              style: theme.textTheme.bodySmall?.copyWith(color: colour),
            ),
          ],
        ),
      ),
    );
  }
}

/// The basmala, set as a heading rather than a numbered verse.
///
/// Used for the 112 surahs that open with it but do not carry it as ayah 1 —
/// which is every surah except Al-Fatiha, where it *is* ayah 1, and At-Tawbah,
/// which has none. See `SurahReading.bismillah`.
class BismillahHeading extends StatelessWidget {
  const BismillahHeading({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: WirdiMetrics.verseBlockSpacing),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          text,
          style: type.quranVerse,
          locale: AyahBlock.arabic,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
