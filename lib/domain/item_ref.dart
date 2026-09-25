/// The kind of content a collection item points at.
///
/// This is the only polymorphic type that crosses the repository boundary.
/// The `item_type` strings stored in both databases (`'dhikr'`, `'ayah'`,
/// `'surah'`) are translated to and from this enum inside the data layer and
/// never escape it.
///
/// There is no member here for a dhikr the user wrote. This enum says which
/// table of `content.db` a row is in, and that dhikr is not in any of them —
/// see [UserDhikrRef], and `item_type_codec.dart` for the `'user_dhikr'`
/// string that names it in SQL.
enum ContentType { dhikr, ayah, surah }

/// What one item of a collection points at.
///
/// Two kinds, split by which database holds the row it names. [ContentRef]
/// names a row in `content.db` — a dhikr, an ayah, a surah — by the integer id
/// the content build assigned it. [UserDhikrRef] names a dhikr the user wrote,
/// which lives in `user.db` and so is keyed by a UUID, like everything else
/// there.
///
/// The same shape as [CollectionId], for the same reason: one type flows
/// through the UI, and which kind it is is what tells a repository which
/// database to ask. Nothing downstream of the repository has to know which it
/// is holding.
///
/// [canonical] is a persisted format — it is what `progress.step_ref` stores —
/// so the strings below are not free to change.
sealed class ItemRef {
  const ItemRef();

  /// `dhikr:1001`, `ayah:2255`, `surah:112`, `user_dhikr:<uuid>`.
  String get canonical;

  /// Parses [s] in [canonical] form. Throws [FormatException] on anything else.
  static ItemRef parse(String s) {
    final ItemRef? parsed = tryParse(s);
    if (parsed == null) {
      throw FormatException(
        'not an item ref: expected "<type>:<id>" or "user_dhikr:<uuid>"',
        s,
      );
    }
    return parsed;
  }

  /// Like [parse], but returns null instead of throwing.
  ///
  /// The `user_dhikr:` form is tried first and [ContentRef.tryParse] second,
  /// which is not only an ordering: a UUID never parses as an integer, so a
  /// user dhikr ref could not be mistaken for a content one even if the order
  /// were reversed. It is written this way round so that adding a third form
  /// later is adding a branch here rather than loosening one there.
  static ItemRef? tryParse(String s) {
    if (s.startsWith(UserDhikrRef.prefix)) {
      final String uuid = s.substring(UserDhikrRef.prefix.length);
      return UserDhikrRef.isWellFormed(uuid) ? UserDhikrRef(uuid) : null;
    }
    return ContentRef.tryParse(s);
  }

  @override
  String toString() => canonical;
}

/// A reference into `content.db`: a kind plus the id of a row of that kind.
///
/// For [ContentType.ayah] the id is `surah_number * 1000 + ayah_number`; for
/// [ContentType.surah] it is the surah number; for [ContentType.dhikr] it is
/// the id the content pipeline assigns.
final class ContentRef extends ItemRef {
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
  @override
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
}

/// A dhikr the user wrote, in `user_adhkar`.
///
/// Keyed by a UUID rather than an integer because every id in `user.db` is,
/// and for the reason stated at the top of `user.drift`: an integer minted by
/// one device means something else on another, and a wird somebody sends to a
/// friend has to be able to bring the adhkar it names with it.
final class UserDhikrRef extends ItemRef {
  /// Lower-cases [uuid]: the canonical form is lower case, and two refs that
  /// differ only in case must not compare unequal.
  UserDhikrRef(String uuid) : uuid = uuid.toLowerCase();

  /// What [canonical] starts with. Underscored rather than hyphenated to match
  /// the `item_type` string it is stored beside.
  static const String prefix = 'user_dhikr:';

  final String uuid;

  /// Whether [value] has the shape of a UUID.
  ///
  /// The same check [UserCollectionId] makes, written out again rather than
  /// shared: a `uuid.dart` holding one regular expression is a file that has
  /// to be found before it can be reused, and the two would still have to be
  /// kept saying the same thing.
  static bool isWellFormed(String value) => _uuid.hasMatch(value);

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  String get canonical => '$prefix$uuid';

  @override
  bool operator ==(Object other) => other is UserDhikrRef && other.uuid == uuid;

  @override
  int get hashCode => Object.hash(UserDhikrRef, uuid);
}
