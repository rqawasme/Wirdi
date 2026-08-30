import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/content_database.dart';
import 'package:wirdi/data/repositories/drift_collection_repository.dart';
import 'package:wirdi/data/repositories/drift_content_repository.dart';
import 'package:wirdi/data/user_database.dart';
import 'package:wirdi/domain/domain.dart';

/// Runs the data layer against the database the Python pipeline actually
/// builds, when there is one.
///
/// `content/build/content.db` is gitignored — it carries licensed Quran text —
/// so this file skips itself when the database has not been built. Build it
/// with `python3 content/scripts/build_content.py` and these run.
///
/// Everything else in the suite uses fixtures. This is the one place that
/// checks the fixtures are not lying about the shape of the real thing.
void main() {
  final File file = File('content/build/content.db');

  group(
    'against the database the pipeline builds',
    () => _tests(file),
    skip: file.existsSync()
        ? false
        : 'no ${file.path} — run content/scripts/build_content.py',
  );
}

void _tests(File file) {
  late ContentDatabase content;
  late UserDatabase user;

  setUp(() async {
    content = ContentDatabase.openReadOnly(file);
    user = UserDatabase.memory();
  });

  tearDown(() async {
    await content.close();
    await user.close();
  });

  test('meta.schema_version is the one this code expects', () async {
    await content.assertSchemaVersion();
  });

  test('the Quran is all there, and ids follow the rule', () async {
    final ContentRepository repo = DriftContentRepository(content);

    expect(await repo.surahs(), hasLength(114));
    expect((await repo.surah(2)).ayahCount, 286);
    expect((await repo.surah(9)).hasBismillah, isFalse);

    final List<Ayah> baqarah = await repo.ayahsForSurah(2);
    expect(baqarah, hasLength(286));
    for (final Ayah ayah in baqarah) {
      expect(ayah.id, ayah.surahNumber * 1000 + ayah.ayahNumber);
    }

    expect(await repo.ayahRange(2, 285, 999), hasLength(2));
  });

  test('every built-in collection resolves', () async {
    final CollectionRepository repo = DriftCollectionRepository(
      content: content,
      user: user,
    );

    final List<CollectionSummary> all = await repo.all();
    expect(all, isNotEmpty);

    for (final CollectionSummary summary in all) {
      final ResolvedCollection resolved = await repo.resolve(summary.id);
      expect(
        resolved.unresolved,
        isEmpty,
        reason: '${summary.id.canonical} has items pointing at nothing',
      );
      expect(resolved.entries, isNotEmpty);

      // Positions come back ascending, and a repeat block never nests.
      int previous = 0;
      for (final CollectionEntry entry in resolved.entries) {
        expect(entry.position, greaterThan(previous));
        previous = entry is RepeatBlock
            ? entry.entries.last.position
            : entry.position;
      }
    }
  });
}
