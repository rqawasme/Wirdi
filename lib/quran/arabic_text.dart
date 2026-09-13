/// Folding Arabic text so that two spellings of the same word compare equal.
///
/// The counterpart to `UthmaniText`, which is about *presenting* Arabic. This
/// is about comparing it, and the two have no code in common.
abstract final class ArabicText {
  /// Marks stripped by [simplify].
  ///
  /// Each range is `(low, high)` inclusive:
  ///
  ///   * `U+064B-U+065F` — tanween, harakat, shadda, sukun, and the Quranic
  ///     vowel signs through `U+065F`. Widened from the originally specified
  ///     `U+064B-U+0656`, which stops one short of `U+0657` ARABIC INVERTED
  ///     DAMMA and `U+065E` ARABIC FATHA WITH TWO DOTS — both occur thousands
  ///     of times in QPC Hafs text.
  ///   * `U+0670` — superscript (dagger) alef.
  ///   * `U+06D6-U+06ED` — Quranic annotation signs, small high and low
  ///     letters, the rub-el-hizb and sajdah marks, and the end-of-ayah symbol.
  static const List<(int, int)> diacriticRanges = <(int, int)>[
    (0x064B, 0x065F),
    (0x0670, 0x0670),
    (0x06D6, 0x06ED),
  ];

  /// Also stripped: characters that change nothing about which word is written.
  ///
  /// `U+0640` tatweel only stretches a joining stroke. The Arabic-Indic digits
  /// `U+0660-U+0669` go because the imported ayah text ends with the ayah
  /// number written in them, and leaving them in would let a search for a word
  /// match an ayah number instead.
  static const List<(int, int)> decorativeRanges = <(int, int)>[
    (0x0640, 0x0640),
    (0x0660, 0x0669),
  ];

  /// Letter foldings applied once the marks are gone.
  ///
  /// The four alef variants fold to bare alef, and alef maksura to yeh. Nothing
  /// else is touched — in particular hamza on the line (`U+0621`), waw and yeh
  /// carrying hamza (`U+0624`, `U+0626`) and teh marbuta (`U+0629`) are left
  /// exactly as they are. Removing those would change which word is written,
  /// not merely how it is vocalised.
  static const Map<int, int> letterFolding = <int, int>{
    0x0622: 0x0627, // alef with madda above -> alef
    0x0623: 0x0627, // alef with hamza above -> alef
    0x0625: 0x0627, // alef with hamza below -> alef
    0x0671: 0x0627, // alef wasla            -> alef
    0x0649: 0x064A, // alef maksura          -> yeh
  };

  static final RegExp _whitespace = RegExp(r'\s+');

  /// [text] with its diacritics stripped, its alef variants folded and its
  /// whitespace collapsed.
  ///
  /// This is `simplify_arabic` from `content/scripts/import_quran.py`, in Dart.
  /// That function builds the `ayahs.text_simple` column at content-build time;
  /// the `adhkar` table has no equivalent column and cannot be given one —
  /// `tool/check_schema_parity.py` requires `content.drift` to mirror the
  /// build script's `CREATE TABLE`s verbatim — so searching adhkar means
  /// folding them here instead.
  ///
  /// **The two must stay character-for-character identical.** A search that
  /// folds differently from the column it will one day be matched against is a
  /// search that disagrees with itself, and the Python file says in as many
  /// words that changing the ranges is a content migration rather than a tweak.
  /// Nothing checks the two automatically; this comment and the one over there
  /// are the whole mechanism.
  ///
  /// **Latin text passes through unchanged**, apart from its whitespace. That
  /// is load-bearing rather than incidental — see `searchAdhkar`, which folds
  /// one query both ways and relies on neither fold reaching the other script.
  ///
  /// Running this on its own output is a no-op: every character it produces is
  /// outside the stripped ranges and outside [letterFolding].
  static String simplify(String text) {
    final StringBuffer out = StringBuffer();
    for (final int rune in text.runes) {
      if (_isStripped(rune)) continue;
      out.writeCharCode(letterFolding[rune] ?? rune);
    }
    // Also folds the no-break space the Quran import leaves before a trailing
    // ayah number, so a stray one cannot make two identical strings compare
    // unequal.
    return out.toString().replaceAll(_whitespace, ' ').trim();
  }

  static bool _isStripped(int rune) {
    for (final (int low, int high) in diacriticRanges) {
      if (rune >= low && rune <= high) return true;
    }
    for (final (int low, int high) in decorativeRanges) {
      if (rune >= low && rune <= high) return true;
    }
    return false;
  }
}
