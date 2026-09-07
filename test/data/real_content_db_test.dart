import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/content_database.dart';
import 'package:wirdi/data/content_stamp.dart';
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

  test('bundledContentStamp describes the content that was built', () async {
    final ContentRepository repo = DriftContentRepository(content);
    final ContentMetadata meta = await repo.metadata();

    // `tool/sync_content_asset.sh` writes lib/data/content_stamp.dart when it
    // copies the database into the asset bundle, and the app trusts it to
    // decide whether an update brought new content. Left stale it would decide
    // wrongly and silently: the copy in application support would be kept, and
    // the release would land with the user still reading the old content.
    expect(
      bundledContentStamp,
      '${meta.contentVersion} ${meta.contentChecksum}',
      reason:
          'lib/data/content_stamp.dart is stale — '
          'run tool/sync_content_asset.sh',
    );
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

  test('the six authored collections are the ones that ship', () async {
    final CollectionRepository repo = DriftCollectionRepository(
      content: content,
      user: user,
    );

    // By id and by name: an id is what a user's commitment points at, and a
    // name is what they look for. Renumbering one silently repoints saved
    // commitments at different content, which is the whole reason ids here are
    // authored rather than generated.
    expect(<String>[
      for (final CollectionSummary s in await repo.all()) s.id.canonical,
    ], containsAll(<String>['b:2', 'b:3', 'b:4', 'b:5', 'b:6', 'b:7']));
    expect(
      <String>[for (final CollectionSummary s in await repo.all()) s.name],
      containsAll(<String>[
        'Wird of Imam al-Nawawi',
        'Morning adhkar',
        'Evening adhkar',
        'al-Wird al-Latif (morning)',
        'al-Wird al-Latif (evening)',
        'Hizb al-Bahr',
      ]),
    );
  });

  test('the adhkar collections reference the Quran rather than repeat it', () {
    return Future<void>(() async {
      final CollectionRepository repo = DriftCollectionRepository(
        content: content,
        user: user,
      );

      for (final int id in <int>[3, 4]) {
        final ResolvedCollection resolved = await repo.resolve(
          BuiltinCollectionId(id),
        );
        final Set<ContentType> kinds = <ContentType>{
          for (final CollectionEntry entry in resolved.entries)
            if (entry is CollectionItemEntry) entry.ref.type,
        };

        // Al-Ikhlas, al-Falaq and al-Nas are surah items in both; the evening
        // adds the last two verses of al-Baqarah. Transcribing any of that a
        // second time is what these assert against.
        expect(
          kinds,
          contains(ContentType.surah),
          reason: 'collection $id lost its surah items',
        );
        expect(kinds, contains(ContentType.dhikr));
      }

      // The evening ends on 2:285-286, which the authored range expands to two
      // ayah items at build time.
      final ResolvedCollection evening = await repo.resolve(
        const BuiltinCollectionId(4),
      );
      expect(
        <int>[
          for (final CollectionEntry entry in evening.entries)
            if (entry is AyahItem) entry.ref.id,
        ],
        <int>[2285, 2286],
      );
    });
  });

  test('every dhikr of the adhkar collections cites a source', () async {
    final CollectionRepository repo = DriftCollectionRepository(
      content: content,
      user: user,
    );

    for (final int id in <int>[3, 4]) {
      final ResolvedCollection resolved = await repo.resolve(
        BuiltinCollectionId(id),
      );
      for (final CollectionEntry entry in resolved.entries) {
        if (entry is! DhikrItem) continue;
        // Sourcing is copy: a reference you have to go looking for is a
        // reference nobody reads, so every one of these carries its own.
        expect(
          entry.source,
          isNotNull,
          reason: 'dhikr ${entry.dhikr.id} in collection $id has no source',
        );
      }
    }
  });
}
