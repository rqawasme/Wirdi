/// Identifies a collection, whichever database it lives in.
///
/// Built-in collections live in `content.db` and are keyed by the integer id
/// the content pipeline assigns. User collections live in `user.db` and are
/// keyed by a UUID v4. Both flow through the same UI, and the id type is what
/// tells a repository which database to query — nothing downstream of the
/// repository has to know which kind it is holding.
///
/// The canonical string form (`b:12`, `u:550e8400-…`) is what
/// `progress.collection_ref` and `completions.collection_ref` store, so that
/// one table covers both kinds without a discriminator column.
sealed class CollectionId {
  const CollectionId();

  /// `b:<int>` for built-ins, `u:<uuid>` for user collections.
  String get canonical;

  /// Parses [s] in canonical form.
  ///
  /// Throws [FormatException] on anything else. Rows in `user.db` are written
  /// by this app, so a value that fails to parse means the database is corrupt
  /// or was written by something else — worth failing on rather than guessing.
  static CollectionId parse(String s) {
    final CollectionId? parsed = tryParse(s);
    if (parsed == null) {
      throw FormatException(
        'not a collection id: expected "b:<int>" or "u:<uuid>"',
        s,
      );
    }
    return parsed;
  }

  /// Like [parse], but returns null instead of throwing.
  static CollectionId? tryParse(String s) {
    if (s.length < 3 || s[1] != ':') return null;
    final String body = s.substring(2);
    switch (s[0]) {
      case 'b':
        final int? value = int.tryParse(body);
        if (value == null) return null;
        // int.tryParse accepts '+12' and ' 12'; canonical form has neither.
        if (value.toString() != body) return null;
        return BuiltinCollectionId(value);
      case 'u':
        if (!_uuid.hasMatch(body)) return null;
        return UserCollectionId(body);
      default:
        return null;
    }
  }

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  String toString() => canonical;
}

/// A collection shipped in `content.db`.
final class BuiltinCollectionId extends CollectionId {
  const BuiltinCollectionId(this.value);

  final int value;

  @override
  String get canonical => 'b:$value';

  @override
  bool operator ==(Object other) =>
      other is BuiltinCollectionId && other.value == value;

  @override
  int get hashCode => Object.hash(BuiltinCollectionId, value);
}

/// A collection the user made, stored in `user.db`.
final class UserCollectionId extends CollectionId {
  /// Lower-cases [uuid]: the canonical form is lower case, and two ids that
  /// differ only in case must not compare unequal.
  UserCollectionId(String uuid) : uuid = uuid.toLowerCase();

  final String uuid;

  @override
  String get canonical => 'u:$uuid';

  @override
  bool operator ==(Object other) =>
      other is UserCollectionId && other.uuid == uuid;

  @override
  int get hashCode => Object.hash(UserCollectionId, uuid);
}
