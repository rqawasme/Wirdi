import '../domain/content.dart';
import 'collection_editing.dart';

/// The longest a dhikr's Arabic or its translation may be.
///
/// Not a limit anybody writing a dua will meet: the longest single dhikr in the
/// content build is well under it, and the Ratib's longest is shorter still.
/// What it catches is a paste that went wrong — a whole surah, or a page of a
/// book, dropped into the field by accident — which would otherwise become one
/// step of a wird that cannot be recited and cannot be edited back down,
/// `CollectionRepository` having no way yet to change an item after it is in.
const int maxDhikrTextLength = 4000;

/// Why [draft] cannot be saved, or null if it can.
///
/// A sentence in the app's voice, like [repeatGroupRefusal]: the screen shows
/// it verbatim. Ask this before writing, and [cleanDraft] after — the two are
/// a pair, and the refusals below are phrased about the cleaned form.
String? dhikrRefusal(DhikrDraft draft) {
  final DhikrDraft clean = cleanDraft(draft);

  if (clean.textArabic.isEmpty) {
    return 'A dhikr needs its words. Type the Arabic first.';
  }
  if (clean.textArabic.length > maxDhikrTextLength) {
    return 'That is longer than one dhikr can be. Split it into the parts '
        'you say one after another, and add them in order.';
  }
  if ((clean.translation?.length ?? 0) > maxDhikrTextLength) {
    return 'That translation is longer than a dhikr can carry.';
  }
  if (clean.defaultCount < 1) {
    return 'A dhikr is said at least once.';
  }
  return null;
}

/// [draft] with every field trimmed and every emptied one nulled.
///
/// Emptying a field is how a field is taken off, which is the same rule the
/// collection form follows for a description. The count is left as it is:
/// zero is refused rather than corrected, because a zero somebody typed is a
/// number they meant something by, and guessing which is worse than asking.
DhikrDraft cleanDraft(DhikrDraft draft) => DhikrDraft(
  textArabic: draft.textArabic.trim(),
  translation: _clean(draft.translation),
  transliteration: _clean(draft.transliteration),
  defaultCount: draft.defaultCount,
  reference: _clean(draft.reference),
  notes: _clean(draft.notes),
);

String? _clean(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// The sentence a deletion asks for confirmation with.
///
/// Names the collections rather than counting them, up to [namedAtMost] of
/// them: "in Morning and My wird" is a fact somebody can act on, where "in 2
/// collections" makes them go and find out which. Beyond that it counts the
/// rest, because a list of nine names in an alert is not read either.
///
/// [names] is in list order, and empty for a dhikr nothing holds.
String deleteDhikrPrompt(List<String> names, {int namedAtMost = 3}) {
  if (names.isEmpty) {
    return 'This dhikr is in none of your collections. Deleting it cannot be '
        'undone.';
  }

  final String where;
  if (names.length <= namedAtMost) {
    where = _joined(names);
  } else {
    final int rest = names.length - namedAtMost;
    where =
        '${_joined(names.take(namedAtMost).toList())} '
        'and $rest other${rest == 1 ? '' : 's'}';
  }

  return 'This dhikr is in $where. Deleting it takes it out of '
      '${names.length == 1 ? 'that collection' : 'those collections'} too, and '
      'cannot be undone.';
}

/// `a`, `a and b`, `a, b and c` — the app's voice, not a comma-joined list.
String _joined(List<String> names) {
  if (names.length == 1) return names.single;
  if (names.length == 2) return '${names.first} and ${names.last}';
  final String head = names.sublist(0, names.length - 1).join(', ');
  return '$head and ${names.last}';
}
