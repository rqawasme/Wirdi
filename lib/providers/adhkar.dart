import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collection_editing.dart';
import '../collections/dhikr_editing.dart';
import '../domain/collection.dart';
import '../domain/content.dart';
import '../domain/item_ref.dart';
import '../domain/repositories.dart';
import 'data_providers.dart';

/// The adhkar the user wrote, newest first.
///
/// Auto-disposed: read when a screen that lists them opens, and dropped when
/// the last one closes. A plain `FutureProvider` is not — it is kept for the
/// whole session once read, and a list kept that long goes stale the first time
/// something changes it from a screen that did not think to say so. While a
/// screen is open, `refreshAfterUserWrite` is what keeps it current.
final FutureProvider<List<Dhikr>> userAdhkarProvider =
    FutureProvider.autoDispose<List<Dhikr>>(
      (Ref ref) => ref.watch(userDhikrRepositoryProvider).all(),
      name: 'userAdhkar',
    );

/// How many collection items name each dhikr the user wrote.
///
/// One read for the whole list rather than one per row: the list shows this on
/// every row, and asking per row is a statement per dhikr. Auto-disposed for
/// the reason [userAdhkarProvider] is — and more so, since this one changes
/// with every edit to a collection, not only with edits to the adhkar.
final FutureProvider<Map<UserDhikrRef, int>> userDhikrUsageProvider =
    FutureProvider.autoDispose<Map<UserDhikrRef, int>>(
      (Ref ref) => ref.watch(userDhikrRepositoryProvider).usage(),
      name: 'userDhikrUsage',
    );

/// Writing the adhkar the user wrote, over [UserDhikrRepository].
///
/// The counterpart to `CollectionEditor`, and the same division of labour: the
/// repository keeps the database honest, and this keeps the refusals in the
/// app's voice — see [dhikrRefusal] — and cleans what a form hands over before
/// any of it is written.
@immutable
final class UserDhikrEditor {
  const UserDhikrEditor(this._adhkar);

  final UserDhikrRepository _adhkar;

  /// Writes [draft] as a new dhikr and hands back what names it.
  ///
  /// Throws [CollectionEditingError] if [dhikrRefusal] has anything to say.
  Future<UserDhikrRef> create(DhikrDraft draft) {
    return _adhkar.create(_checked(draft));
  }

  Future<void> update(UserDhikrRef ref, DhikrDraft draft) {
    return _adhkar.update(ref, _checked(draft));
  }

  /// The collections a deletion would take this dhikr out of, in list order.
  ///
  /// Asked before the confirmation rather than after it, because it is what the
  /// confirmation has to say — see [deleteDhikrPrompt].
  Future<List<CollectionSummary>> usedBy(UserDhikrRef ref) =>
      _adhkar.usedBy(ref);

  Future<void> delete(UserDhikrRef ref) => _adhkar.delete(ref);

  static DhikrDraft _checked(DhikrDraft draft) {
    final String? refusal = dhikrRefusal(draft);
    if (refusal != null) throw CollectionEditingError(refusal);
    return cleanDraft(draft);
  }
}

final Provider<UserDhikrEditor> userDhikrEditorProvider =
    Provider<UserDhikrEditor>(
      (Ref ref) => UserDhikrEditor(ref.watch(userDhikrRepositoryProvider)),
      name: 'userDhikrEditor',
    );
