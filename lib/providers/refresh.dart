import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adhkar.dart';
import 'collections.dart';
import 'editing.dart';

/// Everything a write to what the user owns can have made stale, refreshed in
/// one call.
///
/// Call it after any write to a user collection, its items, or the adhkar the
/// user wrote. One list, rather than each screen choosing which of these it
/// thinks its write touched: that is how, before this existed, deleting a dhikr
/// refreshed the adhkar list and the home screen and left every collection that
/// had been opened still showing it — the choosing was done three times, three
/// ways, and nobody's list had everything on it.
///
/// It is not cheap to be wrong about, because not all of these forget on their
/// own. `resolvedCollectionProvider` is a plain family, and a collection opened
/// once stays resolved for the rest of the session; the collection list is
/// watched by a tab that is never unmounted. Invalidating something nobody is
/// watching only marks it dirty — it is read again the next time something
/// asks — so refreshing all of it costs nothing until then.
///
/// The home view is not on the list because it does not need to be: it watches
/// the collection list, for exactly this reason, so it follows it.
///
/// Not for the player's writes. Progress and completions change what the home
/// screen and the list say about a collection, not what the collection holds,
/// and the screens that open the player refresh those two for that reason.
///
/// Takes the [ProviderContainer] rather than a `WidgetRef`, and callers take it
/// with `ProviderScope.containerOf` *before* they await the write. A write can
/// outlive the screen that started it — Save, then back, before the database
/// answers — and Riverpod refuses a disposed widget's ref outright. The write
/// would land and this would throw, leaving every cache it exists to clear
/// holding what the write just changed.
void refreshAfterUserWrite(ProviderContainer container) {
  container
    // The whole family: a write to one dhikr the user wrote changes every
    // collection that says it, and nothing here knows which those are.
    ..invalidate(resolvedCollectionProvider)
    ..invalidate(collectionListingsProvider)
    ..invalidate(userAdhkarProvider)
    ..invalidate(userDhikrUsageProvider);
}
