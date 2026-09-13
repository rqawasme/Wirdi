import 'package:flutter/material.dart';

import '../domain/content.dart';
import '../theme/theme.dart';

/// One dhikr in a list of them: the Arabic, and the translation under it.
///
/// A row, not a reading. Both halves are capped at two lines and ellipsised —
/// here it is only enough to recognise, and the whole text is on the step the
/// player shows and in the sheet the contents screen opens.
///
/// Shared by both dhikr pickers — the flat searchable list and the one that
/// browses by the wird a dhikr comes from — the way `SurahRow` is shared by the
/// surah picker and the mushaf list. Two lists offering the same choice should
/// not draw it two ways.
class DhikrRow extends StatelessWidget {
  const DhikrRow({super.key, required this.dhikr, required this.onTap});

  final Dhikr dhikr;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;

    return Semantics(
      container: true,
      button: true,
      label: 'Dhikr, ${dhikr.translation}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WirdiMetrics.space4,
            vertical: WirdiMetrics.space3,
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    dhikr.textArabic,
                    style: type.arabicTitle,
                    locale: const Locale('ar'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: WirdiMetrics.space2),
                Text(
                  dhikr.translation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
