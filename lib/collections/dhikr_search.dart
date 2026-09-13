import 'package:flutter/foundation.dart' show immutable;

import '../domain/content.dart';
import '../quran/arabic_text.dart';

/// A dhikr with the two forms searching it needs, folded once.
///
/// Folded when the list is read rather than on every keystroke: four hundred
/// and ninety-six rows through [ArabicText.simplify] costs nothing once, and
/// costs it six times over while somebody types "morn".
@immutable
final class SearchableDhikr {
  const SearchableDhikr({
    required this.dhikr,
    required this.arabic,
    required this.translation,
  });

  /// Folds [dhikr] into the form [searchAdhkar] matches against.
  factory SearchableDhikr.of(Dhikr dhikr) => SearchableDhikr(
    dhikr: dhikr,
    arabic: ArabicText.simplify(dhikr.textArabic),
    translation: dhikr.translation.toLowerCase(),
  );

  final Dhikr dhikr;

  /// [Dhikr.textArabic] through [ArabicText.simplify].
  final String arabic;

  /// [Dhikr.translation], lower-cased.
  final String translation;

  @override
  String toString() => 'SearchableDhikr(${dhikr.id})';
}

/// The adhkar of [all] that match [query], in the order [all] was given in.
///
/// The query is folded both ways and tried against both forms. There is no
/// script detection here and none is needed: [ArabicText.simplify] leaves Latin
/// alone and `toLowerCase` leaves Arabic alone, so an Arabic query cannot match
/// a translation and an English one cannot match the Arabic. Two cheap
/// comparisons are a better answer than guessing which script somebody is
/// typing in, which is a guess that fails on the first transliterated word.
///
/// The match is diacritic-insensitive on the Arabic side because nobody types
/// the harakat and the text carries all of them — a search that required them
/// would find nothing, every time, and look broken rather than strict.
///
/// An empty query is every dhikr. This screen is a browse as much as a search,
/// and a list that starts empty is a list that has to be earned before it says
/// anything.
List<Dhikr> searchAdhkar(List<SearchableDhikr> all, String query) {
  final String trimmed = query.trim();
  if (trimmed.isEmpty) {
    return <Dhikr>[for (final SearchableDhikr d in all) d.dhikr];
  }

  // A query of nothing but harakat folds away to nothing, and `contains('')`
  // is true of every string — so without this guard a stray diacritic would
  // hand back the whole list and look like a search that ignored it. No dhikr
  // is identified by a bare tanween; saying so is the honest answer.
  final String arabic = ArabicText.simplify(trimmed);
  final String latin = trimmed.toLowerCase();
  final bool matchArabic = arabic.isNotEmpty;

  return <Dhikr>[
    for (final SearchableDhikr d in all)
      if ((matchArabic && d.arabic.contains(arabic)) ||
          d.translation.contains(latin))
        d.dhikr,
  ];
}
