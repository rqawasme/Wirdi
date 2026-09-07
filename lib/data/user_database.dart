import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'user_database.g.dart';

/// Read-write storage for everything the user makes: their collections,
/// progress, completions, reading position and settings.
///
/// This database is migrated, never replaced. It lives in the documents
/// directory so platform backup picks it up — see `WirdiDatabaseFiles`.
@DriftDatabase(include: {'schema/user.drift'})
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.e);

  factory UserDatabase.openFile(File file) =>
      UserDatabase(NativeDatabase(file));

  /// An empty in-memory user database. For tests.
  factory UserDatabase.memory() => UserDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    // 1 -> 2 adds `commitments`, the home screen's list of what the user has
    // committed to doing today. Nothing existing is touched: a database from
    // version 1 comes forward with every collection uncommitted, which is the
    // correct starting state — committing is a decision the user makes, and
    // guessing it from what they happen to own would fill their home screen
    // with things they never chose.
    // 2 -> 3 gives a commitment the days of the week it falls on, and renames
    // the untimed section from 'daily' to 'today'. Existing rows come forward
    // as every day, which is what they meant when there was no other option.
    //
    // The rename is a data migration and not only a label change, because the
    // section is stored as the string it reads as. A row left saying 'daily'
    // would parse as no section at all and its commitment would quietly stop
    // appearing, so it is rewritten here rather than tolerated as an alias
    // forever.
    // 3 -> 4 gives progress a unit cursor: which ayah of a surah step the
    // reciter is on, so backgrounding half way through Al-Mulk resumes at the
    // verse it was left on. Existing rows come forward at 0, the start of the
    // repetition, which is where every step with a single unit always is.
    // 4 -> 5 follows a content change rather than a schema one. Six adhkar in
    // content.db were second copies of a dhikr that already had an id — the
    // same istiʿādha and ḥasbiya Llāh authored once per wird — and collapsing
    // them onto one id each is what lets a dhikr recited in two wirds be one
    // thing rather than two. The copies are gone as of this version, so a
    // user collection still pointing at one would resolve to nothing and the
    // item would quietly vanish from their collection. This repoints those
    // rows at the id that survived. See [_retiredAdhkar].
    //
    // Two rules hold every step here, and both were learned the hard way.
    //
    // A step is written for the version it upgrades *from*, not as `from < n`.
    // A step that creates a table creates it from the current schema — `days`
    // and all — so a later step must not add a column that is already there.
    // `from == 2` is the only database with a `commitments` table and no
    // `days`.
    //
    // And every step is idempotent, because this does not run in a
    // transaction: a step that throws leaves `user_version` where it was and
    // everything before it applied, so the next launch runs the whole upgrade
    // again over a half-migrated database. `IF NOT EXISTS` on the indexes and
    // the column check below are what make that second run succeed instead of
    // failing the same way forever.
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(commitments);
        await m.createIndex(idxCommitmentsSection);
      }
      if (from == 2 && !await _hasColumn('commitments', 'days')) {
        await m.addColumn(commitments, commitments.days);
      }
      if (from < 3) {
        // Idempotent on its own: a second run matches nothing.
        await customStatement(
          "UPDATE commitments SET section = 'today' WHERE section = 'daily'",
        );
      }
      if (from < 4 && !await _hasColumn('progress', 'unit_index')) {
        await m.addColumn(progress, progress.unitIndex);
      }
      if (from < 5) {
        await _mergeRetiredAdhkar();
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Adhkar that content.db no longer has, and the id that replaced each.
  ///
  /// Every one of these was a duplicate: the same words authored a second time
  /// under a second id because two wirds each carried their own copy. The
  /// survivor is the lowest id of the group, which is the oldest and so the
  /// one a user collection is likeliest to be pointing at already.
  ///
  /// `content/scripts/verify_content.py` fails the build if a duplicate is
  /// ever authored again, so this map is a record of one clean-up rather than
  /// something expected to grow.
  static const Map<int, int> _retiredAdhkar = <int, int>{
    3004: 2011,
    5002: 3016,
    5003: 2011,
    5011: 3013,
    5014: 3001,
    5038: 3011,
  };

  /// Repoints saved rows at the surviving id of each merged dhikr.
  ///
  /// Idempotent, as every step in the ladder has to be: a retired id appears
  /// on the left of [_retiredAdhkar] and never on the right, so a second run
  /// matches nothing.
  ///
  /// `progress.step_ref` is rewritten alongside the collection items because
  /// a resume compares it against the step it is about to resume at: left
  /// alone it would no longer match, and the reciter would silently lose their
  /// place in a wird they were half way through.
  Future<void> _mergeRetiredAdhkar() async {
    // The item_type guard is not decoration. ayahs.id is
    // surah_number * 1000 + ayah_number, so every retired dhikr id here is
    // also a perfectly valid ayah id — 3004 is 3:4 — and an update without it
    // would repoint ayah items at whatever verse the replacement id names.
    const String repointItem =
        'UPDATE user_collection_items SET item_id = ? '
        "WHERE item_type = 'dhikr' AND item_id = ?";
    const String repointProgress =
        'UPDATE progress SET step_ref = ? WHERE step_ref = ?';

    for (final MapEntry<int, int> entry in _retiredAdhkar.entries) {
      await customStatement(repointItem, <Object>[entry.value, entry.key]);
      await customStatement(repointProgress, <Object>[
        'dhikr:${entry.value}',
        'dhikr:${entry.key}',
      ]);
    }
  }

  /// Whether [table] already has [column].
  ///
  /// `ALTER TABLE ... ADD COLUMN` is the one migration step with no
  /// `IF NOT EXISTS` form, so asking first is the only way to make it safe to
  /// run twice.
  Future<bool> _hasColumn(String table, String column) async {
    final List<QueryRow> columns = await customSelect(
      'PRAGMA table_info($table)',
    ).get();
    return columns.any((QueryRow row) => row.read<String>('name') == column);
  }
}
