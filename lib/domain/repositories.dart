import 'collection.dart';
import 'collection_id.dart';
import 'commitment.dart';
import 'content.dart';
import 'item_ref.dart';
import 'progress.dart';

/// Read access to the bundled content database.
///
/// Everything here is immutable content shipped with the app.
abstract class ContentRepository {
  /// All 114 surahs, in mushaf order.
  Future<List<Surah>> surahs();

  Future<Surah> surah(int number);

  Future<List<Ayah>> ayahsForSurah(int surahNumber);

  Future<Ayah> ayah(int surahNumber, int ayahNumber);

  /// Ayahs [from]..[to] of [surahNumber], inclusive.
  ///
  /// The bounds are clamped to the surah's real length, so asking for
  /// `ayahRange(2, 280, 300)` returns 280..286 rather than failing. An
  /// inverted range is a caller bug and throws [ArgumentError].
  Future<List<Ayah>> ayahRange(int surahNumber, int from, int to);

  Future<List<Ayah>> ayahsForJuz(int juz);

  Future<Dhikr> dhikr(int id);

  /// Every dhikr in this content build, by id — 496 rows in the current one.
  ///
  /// The whole table, deliberately. The dhikr picker matches Arabic
  /// diacritic-insensitively and `adhkar` carries no normalised column to match
  /// against, so the search runs in Dart over rows read once. See
  /// `ArabicText.simplify` for why the folding cannot live in SQL.
  Future<List<Dhikr>> adhkar();

  /// What this content build is and where it came from.
  ///
  /// Needed to credit the Quran text and the translation without hard-coding
  /// either: a credit that lives in Dart drifts from the database the moment
  /// the pipeline changes edition.
  Future<ContentMetadata> metadata();
}

/// Collections, built-in and user-made, behind one interface.
///
/// This is the only place the two databases are combined; the seam stays here.
abstract class CollectionRepository {
  /// Built-ins from content.db and user collections from user.db, merged.
  Future<List<CollectionSummary>> all();

  Future<ResolvedCollection> resolve(CollectionId id);

  Future<UserCollectionId> create(String name, {String? description});

  /// Sets the name and the description together.
  ///
  /// A required nullable [description] rather than an optional one: null means
  /// "no description", where an optional parameter would be ambiguous about
  /// whether it meant that or "leave whatever is there alone".
  ///
  /// One statement rather than two, so a rename cannot land while the
  /// description it was written alongside does not.
  Future<void> updateDetails(
    UserCollectionId id, {
    required String name,
    required String? description,
  });

  /// [note] is a rubric shown with the item, mirroring what the content
  /// pipeline authors for built-ins. It is here so that copying a built-in
  /// wird into a user collection keeps its per-item notes.
  ///
  /// [ref] may name a dhikr the user wrote as readily as a row of
  /// `content.db`; a collection makes no distinction between them.
  Future<void> addItem(
    UserCollectionId id,
    ItemRef ref, {
    int? count,
    String? note,
  });

  Future<void> removeItem(UserCollectionId id, String itemId);

  Future<void> reorder(UserCollectionId id, List<String> itemIdsInOrder);

  /// Groups [itemIds] into a repeat block recited [repetitions] times over.
  ///
  /// [itemIds] must be a contiguous run by position, and none of them may
  /// already belong to a group — a repeat group that is not a contiguous run
  /// has no coherent playback order. Throws [ArgumentError] otherwise.
  Future<void> setRepeatGroup(
    UserCollectionId id,
    List<String> itemIds,
    int repetitions,
  );

  /// Ungroups the items of [repeatGroup]. A no-op if no items carry it.
  Future<void> clearRepeatGroup(UserCollectionId id, int repeatGroup);

  /// Soft delete: sets `deleted_at`. The row and its items stay, and [all]
  /// filters it out.
  ///
  /// Progress for the collection is cleared — in-flight state for a deleted
  /// collection is meaningless. Completions are kept: they are historical
  /// record, streaks run across all of them regardless of collection, and
  /// deleting them would retroactively break a streak the user earned.
  Future<void> delete(UserCollectionId id);
}

/// The adhkar the user wrote themselves.
///
/// A separate interface from [CollectionRepository] because these are content,
/// not structure: what a collection *says*, rather than the order it says it
/// in. [ContentRepository] is the same thing for the adhkar the app ships
/// with, and the two are deliberately not merged — one is read-only and
/// replaced wholesale on an app update, the other is written by the person
/// using it and migrated forever.
abstract class UserDhikrRepository {
  /// Newest first. A dhikr somebody wrote has no arrangement, and the one they
  /// are looking for is overwhelmingly the one they just made.
  Future<List<Dhikr>> all();

  Future<UserDhikrRef> create(DhikrDraft draft);

  /// Writes every field of [draft] at once.
  ///
  /// The change is shared, because a collection item names a dhikr rather than
  /// holding a copy of it: fixing a typo fixes it in every collection that
  /// says this dhikr, and lowering [DhikrDraft.defaultCount] lowers it for
  /// every item that carries no count override of its own. That is what makes
  /// it worth writing a dhikr down once.
  ///
  /// Throws [DhikrNotFoundException] if it is gone or soft-deleted.
  Future<void> update(UserDhikrRef ref, DhikrDraft draft);

  /// How many collection items name each dhikr, in one read. Adhkar nothing
  /// names are absent rather than present with a zero.
  ///
  /// Items and not collections: a collection that says the same dhikr twice
  /// holds two items, which is what deleting it will remove.
  Future<Map<UserDhikrRef, int>> usage();

  /// The live collections that hold [ref], in list order. What the sentence in
  /// front of a deletion is built from.
  Future<List<CollectionSummary>> usedBy(UserDhikrRef ref);

  /// Soft-deletes the dhikr and takes it out of every collection that held it,
  /// in one transaction.
  ///
  /// The dhikr row stays, tombstoned, as a deleted collection's does. Its
  /// items do not: an item is a position in a list, and a tombstoned one would
  /// leave a hole that `setRepeatGroup`'s contiguity check trips over. Each
  /// collection it was taken out of is renumbered to close the gap, exactly as
  /// removing one item by hand does.
  ///
  /// Progress is left alone. A wird half done through a step that has just
  /// been removed comes back through `ResolvedCollection.resumableFrom`, which
  /// compares the ref it was written against and discards a row that no longer
  /// matches — which is the correct answer here and needs no help.
  ///
  /// Throws [DhikrNotFoundException] if it is already gone.
  Future<void> delete(UserDhikrRef ref);
}

/// Everything the user accumulates: progress, completions, reading position
/// and settings.
abstract class UserRepository {
  /// The stored progress, as written, or null when there is none for today.
  ///
  /// Progress belongs to the local day it was made on: a wird left half done
  /// last night is not half done this morning, it is not done. An
  /// implementation returns null for a row it did not write today, so the
  /// home screen's tiles and the player agree about where the day starts.
  ///
  /// Validate what comes back through `ResolvedCollection.resumableFrom`
  /// before resuming from it — a bare index outlives the content it pointed
  /// at.
  Future<WirdProgress?> progress(CollectionId id);

  Future<void> saveProgress(WirdProgress progress);

  Future<void> clearProgress(CollectionId id);

  /// Records that [id] was completed on the local day of [at]. A second
  /// completion on the same local day is a no-op.
  Future<void> logCompletion(CollectionId id, DateTime at);

  Future<bool> isCompletedToday(CollectionId id);

  /// Distinct `YYYY-MM-DD` local days on which anything was completed,
  /// ascending. [from] and [to] are inclusive.
  ///
  /// Spans every collection, including ones since deleted: their completions
  /// are kept deliberately, so a `collection_ref` here may not resolve.
  Future<List<String>> completionDates({DateTime? from, DateTime? to});

  /// The local days [id] itself was completed on, ascending. [from] and [to]
  /// are inclusive, and either may be omitted for an open bound.
  ///
  /// Unlike [completionDates], which spans everything: this is one
  /// collection's own history, which is what a home card's week strip and the
  /// tracker's per-collection scope are drawn from.
  ///
  /// The bounds used to be required, on the argument that every caller wanted
  /// a window and an open-ended read would scan the table. The tracker is the
  /// caller that wants the whole thing: its streak, its twelve weeks, its
  /// weekday tallies and its all-time count are four questions about the same
  /// history, and reading it once and answering them in Dart is cheaper than
  /// four windowed reads — which is what `currentStreakFor` was already doing
  /// through the unwindowed query underneath this one. The table is one row
  /// per collection per day and the index covers it.
  Future<List<String>> completionDatesFor(
    CollectionId id, {
    DateTime? from,
    DateTime? to,
  });

  /// The collections that have ever been completed, whether or not they are
  /// still committed — or still exist.
  ///
  /// What the tracker's scope picker is built from: a collection with a
  /// history is worth being able to look at even after its commitment was
  /// taken off. Ids here may no longer resolve, since completions outlive the
  /// collection they belong to, so callers intersect against the collection
  /// list rather than trusting this to name only live rows.
  Future<Set<CollectionId>> completedCollections();

  /// Consecutive days up to today on which anything was completed.
  ///
  /// A day with no completion yet does not break the streak until it is over,
  /// so this counts back from yesterday when today is still empty.
  Future<int> currentStreak();

  /// The same count for [id] alone: consecutive days up to today on which
  /// this collection in particular was completed.
  ///
  /// The app-wide streak answers "have I kept at it"; this answers "have I
  /// kept at *this*", which is the only one a card about one collection can
  /// honestly ask. Same rule about today: a day still in progress does not
  /// break a run.
  Future<int> currentStreakFor(CollectionId id);

  /// What the user has committed to doing, in the order they committed it.
  ///
  /// Spans both databases, like progress and completions do. A commitment
  /// whose collection has since been deleted is still a row here; callers
  /// resolve against the collection list and drop what no longer exists.
  Future<List<Commitment>> commitments();

  /// Commits [id] to [section] on [days], or moves it if it is committed
  /// already.
  ///
  /// Moving keeps the commitment's place in the order: it is the same
  /// commitment on a different day or in a different part of the day, and it
  /// should not jump to the end of the grid for having been moved.
  Future<void> commit(
    CollectionId id,
    DailySection section, {
    Weekdays days = Weekdays.everyDay,
  });

  /// Takes [id] off the home screen. The collection itself is untouched, as
  /// is anything it has completed. A no-op if it was not committed.
  Future<void> uncommit(CollectionId id);

  Future<ReadingPosition?> lastPosition();

  Future<void> saveLastPosition(ReadingPosition position);

  Future<String?> setting(String key);

  Future<void> setSetting(String key, String value);
}
