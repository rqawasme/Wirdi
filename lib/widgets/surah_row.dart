import 'package:flutter/material.dart';

import '../domain/content.dart';
import '../theme/theme.dart';
import 'plate.dart';

/// One surah in a list of the 114.
///
/// Shared by the mushaf's surah list and by the two collection pickers that
/// start from a surah, so that picking a surah to add to a wird looks and
/// scans exactly like picking one to read. [onTap] is what differs between
/// them, and it is the only thing that does.
///
/// The Arabic name is given its own column on the trailing edge at
/// [WirdiTypography.arabicTitle] rather than being appended to the Latin line:
/// it is what the eye actually scans down the list for, and Arabic set at 2.0
/// line height inside a dense row has nowhere to put its marks.
class SurahRow extends StatelessWidget {
  const SurahRow({super.key, required this.surah, required this.onTap});

  final Surah surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final Color quiet = theme.colorScheme.onSurfaceVariant;

    final String place = switch (surah.revelationPlace) {
      RevelationPlace.makkah => 'Makkah',
      RevelationPlace.madinah => 'Madinah',
    };
    // Not `nameEnglish`: in this content build it is the transliteration with
    // its diacritics dropped for all 114 surahs, not a meaning, so printing it
    // under nameTransliterated says the same thing twice. English meanings —
    // "The Opening", "The Cow" — are not in content.db at all.
    final String meta =
        '$place · ${surah.ayahCount} '
        '${surah.ayahCount == 1 ? 'ayah' : 'ayahs'}';

    return Semantics(
      container: true,
      button: true,
      label:
          'Surah ${surah.number}, ${surah.nameTransliterated}, '
          'revealed in $place, ${surah.ayahCount} ayahs',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WirdiMetrics.space4,
            vertical: WirdiMetrics.space3,
          ),
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                NumberPlate(number: surah.number),
                const SizedBox(width: WirdiMetrics.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        surah.nameTransliterated,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: WirdiMetrics.space1),
                      Text(
                        meta,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: quiet,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: WirdiMetrics.space4),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    surah.nameArabic,
                    style: type.arabicTitle,
                    locale: const Locale('ar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
