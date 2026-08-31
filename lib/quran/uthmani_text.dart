/// Text transformations on the Uthmani text as `content.db` stores it.
///
/// Pure string work, kept out of the widgets so it can be tested without a
/// rendering stack and so the assumptions it makes are written down in one
/// place rather than inferred from a `substring` call in a build method.
abstract final class UthmaniText {
  /// U+06DD ARABIC END OF AYAH. The digits that follow it are drawn inside it.
  static const String endOfAyah = '۝';

  /// U+06E9 ARABIC PLACE OF SAJDAH.
  static const String placeOfSajdah = '۩';

  static const int _arabicIndicZero = 0x0660;
  static const int _arabicIndicNine = 0x0669;

  /// [text] without the ayah number QUL bakes onto the end of it.
  ///
  /// Every one of the 6,236 ayahs in `content.db` ends with a space and then
  /// the ayah number in Arabic-Indic digits — checked across the whole corpus,
  /// not assumed — so this is a total function rather than a best effort.
  /// `content/README.md` describes the separator as a no-break space; it is
  /// actually U+0020, and this accepts either.
  ///
  /// The app renders its own marker through [ayahMarker], so leaving the baked
  /// number in place would number every verse twice. The alternative is
  /// re-importing with `--strip-ayah-numbers`, which needs the QUL downloads;
  /// doing it here costs one pass over a string that is about to be laid out
  /// anyway.
  static String withoutAyahNumber(String text) {
    int end = text.length;
    while (end > 0 && _isArabicIndicDigit(text.codeUnitAt(end - 1))) {
      end--;
    }
    // Nothing stripped: not the shape this expects, so leave it alone rather
    // than trim a real trailing character.
    if (end == text.length) return text;
    while (end > 0 && _isSpace(text.codeUnitAt(end - 1))) {
      end--;
    }
    return text.substring(0, end);
  }

  /// [number] in Arabic-Indic digits.
  static String arabicIndicDigits(int number) {
    if (number < 0) return '-${arabicIndicDigits(-number)}';
    if (number == 0) return String.fromCharCode(_arabicIndicZero);
    final List<int> digits = <int>[];
    for (int n = number; n > 0; n ~/= 10) {
      digits.insert(0, _arabicIndicZero + n % 10);
    }
    return String.fromCharCodes(digits);
  }

  /// The end-of-ayah marker for [number]: the ornament with the number inside.
  ///
  /// Both bundled Arabic faces enclose the digits properly, up to three of
  /// them — measured, because this is the sort of thing fonts get wrong, and
  /// `test/quran/ayah_marker_test.dart` keeps it measured. If a font ever
  /// stops enclosing them, that test fails rather than the mushaf quietly
  /// growing a number outside its ornament.
  static String ayahMarker(int number) =>
      '$endOfAyah${arabicIndicDigits(number)}';

  /// An ayah's text with its own marker at the end, as a mushaf sets it.
  ///
  /// Joined with a no-break space so the marker cannot be orphaned onto a line
  /// of its own when the verse happens to fill the last line — it wraps with
  /// the word it belongs to instead.
  static String verseWithMarker(String text, int ayahNumber) =>
      '${withoutAyahNumber(text)}\u00A0${ayahMarker(ayahNumber)}';

  static bool _isArabicIndicDigit(int unit) =>
      unit >= _arabicIndicZero && unit <= _arabicIndicNine;

  /// U+0020 or the no-break space `content/README.md` describes.
  static bool _isSpace(int unit) => unit == 0x20 || unit == 0xA0;
}
