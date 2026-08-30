/// The kind of content a collection item points at.
///
/// This is the only polymorphic type that crosses the repository boundary.
/// The `item_type` strings stored in both databases (`'dhikr'`, `'ayah'`,
/// `'surah'`) are translated to and from this enum inside the data layer and
/// never escape it.
enum ContentType { dhikr, ayah, surah }

/// A reference into `content.db`: a kind plus the id of a row of that kind.
///
/// For [ContentType.ayah] the id is `surah_number * 1000 + ayah_number`; for
/// [ContentType.surah] it is the surah number; for [ContentType.dhikr] it is
/// the id the content pipeline assigns.
final class ContentRef {
  const ContentRef(this.type, this.id);

  const ContentRef.dhikr(this.id) : type = ContentType.dhikr;

  const ContentRef.surah(this.id) : type = ContentType.surah;

  /// The ayah with the given id (`surah * 1000 + ayah`).
  const ContentRef.ayah(this.id) : type = ContentType.ayah;

  /// The ayah at [surah]:[ayah], applying the id rule.
  ContentRef.ayahAt(int surah, int ayah)
    : type = ContentType.ayah,
      id = surah * 1000 + ayah;

  final ContentType type;
  final int id;

  /// `dhikr:1001`, `ayah:2255`, `surah:112`.
  ///
  /// This is what `progress.step_ref` stores. The mapping is an explicit
  /// switch rather than [Enum.name] so that renaming a Dart enum value cannot
  /// silently change what is already persisted.
  String get canonical => switch (type) {
    ContentType.dhikr => 'dhikr:$id',
    ContentType.ayah => 'ayah:$id',
    ContentType.surah => 'surah:$id',
  };

  /// Parses [s] in [canonical] form. Throws [FormatException] on anything else.
  static ContentRef parse(String s) {
    final ContentRef? parsed = tryParse(s);
    if (parsed == null) {
      throw FormatException('not a content ref: expected "<type>:<id>"', s);
    }
    return parsed;
  }

  static ContentRef? tryParse(String s) {
    final int colon = s.indexOf(':');
    if (colon < 0) return null;
    final int? id = int.tryParse(s.substring(colon + 1));
    if (id == null) return null;
    final ContentType? type = switch (s.substring(0, colon)) {
      'dhikr' => ContentType.dhikr,
      'ayah' => ContentType.ayah,
      'surah' => ContentType.surah,
      _ => null,
    };
    return type == null ? null : ContentRef(type, id);
  }

  @override
  bool operator ==(Object other) =>
      other is ContentRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => canonical;
}
