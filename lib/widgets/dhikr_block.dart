import 'package:flutter/material.dart';

import '../domain/content.dart';
import '../theme/theme.dart';
import 'ayah_block.dart';
import 'translation_text.dart';

/// One dhikr: the Arabic, its transliteration, and the translation beneath.
///
/// The counterpart to [AyahBlock], and deliberately not the same widget. A
/// dhikr has no verse marker and no sajdah mark, it carries a transliteration
/// where an ayah does not, and it is set two thirds of a step smaller —
/// [WirdiTypography.dhikr] rather than [WirdiTypography.quranVerse]. Sharing
/// one widget between them would mean a pile of flags to say which of those
/// applied.
class DhikrBlock extends StatelessWidget {
  const DhikrBlock({
    super.key,
    required this.dhikr,
    this.showTranslation = true,
  });

  final Dhikr dhikr;

  final bool showTranslation;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final String? transliteration = dhikr.transliteration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Genuinely right-to-left rather than right-aligned: the shaper needs
        // the paragraph direction to order runs and break lines correctly.
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            dhikr.textArabic,
            style: type.dhikr,
            locale: AyahBlock.arabic,
          ),
        ),
        if (transliteration != null && transliteration.isNotEmpty) ...<Widget>[
          const SizedBox(height: WirdiMetrics.space3),
          Text(
            transliteration,
            style: type.dhikrCaption.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (showTranslation) ...<Widget>[
          const SizedBox(height: WirdiMetrics.space3),
          TranslationText(dhikr.translation, style: type.translation),
        ],
      ],
    );
  }
}
