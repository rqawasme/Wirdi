import 'package:uuid/uuid.dart';

import '../../domain/collection_id.dart';
import '../../domain/date_key.dart';
import '../../domain/progress.dart';
import '../../domain/repositories.dart';
import '../mappers.dart';
// `reading_position` makes drift generate a table class called
// `ReadingPosition`, which collides with the domain model of that name.
// The row class is `ReadingPositionRow`; the table class is not needed here.
import '../user_database.dart' hide ReadingPosition;

/// [UserRepository] over `user.db`.
///
/// Everything here is keyed by [CollectionId.canonical], so a built-in and a
/// user collection share one progress table and one completions table without
/// a discriminator column.
class DriftUserRepository implements UserRepository {
  DriftUserRepository(this._db, {Uuid? uuid, DateTime Function()? clock})
    : _uuid = uuid ?? const Uuid(),
      _now = clock ?? DateTime.now;

  final UserDatabase _db;
  final Uuid _uuid;

  /// Injected so that "today" and "the streak so far" are testable without
  /// waiting for midnight.
  final DateTime Function() _now;

  /// A date_key far below any real one, for an open lower bound.
  static const String _minDateKey = '0000-00-00';

  /// And far above. date_key is YYYY-MM-DD, so string order is date order.
  static const String _maxDateKey = '9999-99-99';

  /// How far back [currentStreak] is willing to count. Twenty years of daily
  /// practice is a generous ceiling and keeps the walk bounded.
  static const int _maxStreakDays = 366 * 20;

  @override
  Future<WirdProgress?> progress(CollectionId id) async {
    final ProgressRow? row = await _db
        .progressFor(ref: id.canonical)
        .getSingleOrNull();
    return row == null ? null : progressFromRow(row, id);
  }

  @override
  Future<void> saveProgress(WirdProgress progress) async {
    await _db.upsertProgress(
      ref: progress.collectionId.canonical,
      itemIndex: progress.itemIndex,
      currentCount: progress.currentCount,
      updatedAt: toEpochMs(progress.updatedAt),
    );
  }

  @override
  Future<void> clearProgress(CollectionId id) async {
    await _db.deleteProgress(ref: id.canonical);
  }

  @override
  Future<void> logCompletion(CollectionId id, DateTime at) async {
    // The unique index on (collection_ref, date_key) makes a second completion
    // on the same local day a no-op, keeping the earlier completed_at.
    await _db.logCompletion(
      id: _uuid.v4(),
      ref: id.canonical,
      dateKey: dateKey(at),
      completedAt: toEpochMs(at),
    );
  }

  @override
  Future<bool> isCompletedToday(CollectionId id) {
    return _db
        .completionExists(ref: id.canonical, dateKey: dateKey(_now()))
        .getSingle();
  }

  @override
  Future<List<String>> completionDates({DateTime? from, DateTime? to}) {
    return _db
        .completionDatesBetween(
          from: from == null ? _minDateKey : dateKey(from),
          to: to == null ? _maxDateKey : dateKey(to),
        )
        .get();
  }

  @override
  Future<int> currentStreak() async {
    final List<String> days = await _db.completionDatesDescending().get();
    if (days.isEmpty) return 0;

    final Set<String> completed = days.toSet();
    final DateTime now = _now();

    // Today not being done yet does not break a streak — the day is not over.
    int offset = completed.contains(dateKey(now)) ? 0 : 1;

    int streak = 0;
    while (offset <= _maxStreakDays &&
        completed.contains(dateKeyDaysBefore(now, offset))) {
      streak++;
      offset++;
    }
    return streak;
  }

  @override
  Future<ReadingPosition?> lastPosition() async {
    final ReadingPositionRow? row = await _db
        .currentReadingPosition()
        .getSingleOrNull();
    return row == null ? null : readingPositionFromRow(row);
  }

  @override
  Future<void> saveLastPosition(ReadingPosition position) async {
    await _db.upsertReadingPosition(
      surahNumber: position.surahNumber,
      ayahNumber: position.ayahNumber,
      updatedAt: toEpochMs(position.updatedAt),
    );
  }

  @override
  Future<String?> setting(String key) {
    return _db.settingValue(key: key).getSingleOrNull();
  }

  @override
  Future<void> setSetting(String key, String value) async {
    await _db.upsertSetting(
      key: key,
      value: value,
      updatedAt: toEpochMs(_now()),
    );
  }
}
