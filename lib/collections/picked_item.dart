import 'package:flutter/foundation.dart' show immutable;

import '../domain/content_ref.dart';

/// One item a picker is handing back, with the two optional things the user
/// can say about it on the way through.
///
/// A picker returns a list because one pick is not always one item: an ayah
/// range is a run of them, added in order, and the count and note the user
/// chose apply to each.
@immutable
final class PickedItem {
  const PickedItem({required this.ref, this.count, this.note});

  final ContentRef ref;

  /// A `count_override`, or null to leave the item at its natural count — a
  /// dhikr's `default_count`, or once for an ayah or a surah.
  final int? count;

  /// A rubric shown with the item, or null.
  final String? note;

  @override
  String toString() => 'PickedItem(${ref.canonical} x${count ?? '-'})';
}
