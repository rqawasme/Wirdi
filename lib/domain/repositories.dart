import 'collection.dart';
import 'collection_id.dart';
import 'commitment.dart';
import 'content.dart';
import 'content_ref.dart';
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

  Future<void> rename(UserCollectionId id, String name);

  /// [note] is a rubric shown with the item, mirroring what the content
  /// pipeline authors for built-ins. It is here so that copying a built-in
  /// wird into a user collection keeps its per-item notes.
  Future<void> addItem(
    UserCollectionId id,
    ContentRef ref, {
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

  /// Consecutive days up to today on which anything was completed.
  ///
  /// A day with no completion yet does not break the streak until it is over,
  /// so this counts back from yesterday when today is still empty.
  Future<int> currentStreak();

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
