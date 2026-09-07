import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:wirdi/data/database_files.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';

/// The startup path, run for real.
///
/// This is the one sequence the rest of the suite deliberately avoids: load
/// `assets/content.db` out of the bundle, write it into application support,
/// open it read-only, check the SQLite in use and check the schema version.
/// Until this phase nothing ever executed it, and every part of it can only
/// fail on a first launch — a missing asset, a truncated copy, a database the
/// pipeline stopped building the way this code reads it.
///
/// It runs against the real asset, so it skips when the asset has not been
/// built. Build it with:
///
/// ```
/// python3 content/scripts/build_content.py
/// tool/sync_content_asset.sh
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late Directory documents;
  late WirdiDatabaseFiles files;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('wirdi_support_');
    documents = await Directory.systemTemp.createTemp('wirdi_documents_');
    files = WirdiDatabaseFiles(
      supportDirectory: () async => support,
      documentsDirectory: () async => documents,
    );
  });

  tearDown(() async {
    await support.delete(recursive: true);
    await documents.delete(recursive: true);
  });

  Future<bool> assetIsBundled() async {
    try {
      await rootBundle.load(const WirdiDatabaseFiles().contentAsset);
      return true;
    } on FlutterError {
      return false;
    }
  }

  test('copies the bundled content.db and opens both databases', () async {
    if (!await assetIsBundled()) {
      markTestSkipped('assets/content.db not built — see the file comment');
      return;
    }

    final WirdiData data = await WirdiData.open(files: files);
    addTearDown(data.close);

    final File copied = File(p.join(support.path, 'content.db'));
    expect(copied.existsSync(), isTrue, reason: 'the copy must land on disk');
    expect(
      await copied.length(),
      (await rootBundle.load(files.contentAsset)).lengthInBytes,
      reason: 'a short copy is a truncated database',
    );

    // The whole point of the copy: real content, readable through the
    // repositories.
    expect(await data.contentRepository.surahs(), hasLength(114));
    final Ayah ayah = await data.contentRepository.ayah(1, 1);
    expect(ayah.textUthmani, isNotEmpty);
    expect(ayah.translation, isNotEmpty);

    // The other half of a working first launch: user.db is writable, and it
    // lands in the documents directory rather than alongside the content copy,
    // because platform backup is the only thing standing between a user and
    // losing their collections with their phone.
    //
    // Written to first: drift opens lazily, so the file does not exist until
    // something actually runs against it.
    await data.userRepository.setSetting('startup_test', 'ok');
    expect(await data.userRepository.setting('startup_test'), 'ok');
    expect(File(p.join(documents.path, 'user.db')).existsSync(), isTrue);
    expect(File(p.join(support.path, 'user.db')).existsSync(), isFalse);
  });

  test('a second launch reuses the copy instead of rewriting it', () async {
    if (!await assetIsBundled()) {
      markTestSkipped('assets/content.db not built — see the file comment');
      return;
    }

    final File first = await files.ensureContentDatabase();
    final DateTime writtenAt = first.statSync().modified;

    final File second = await files.ensureContentDatabase();

    expect(second.path, first.path);
    expect(
      second.statSync().modified,
      writtenAt,
      reason: 'an unchanged asset must not be copied again on every launch',
    );
  });

  test('a stale copy is replaced when the content changes', () async {
    if (!await assetIsBundled()) {
      markTestSkipped('assets/content.db not built — see the file comment');
      return;
    }

    final File target = File(p.join(support.path, 'content.db'));
    await target.writeAsBytes(<int>[1, 2, 3], flush: true);

    final File refreshed = await files.ensureContentDatabase();

    expect(
      await refreshed.length(),
      (await rootBundle.load(files.contentAsset)).lengthInBytes,
    );
  });

  test('a copy made by an older install, which left no stamp, is '
      'replaced', () async {
    if (!await assetIsBundled()) {
      markTestSkipped('assets/content.db not built — see the file comment');
      return;
    }

    // What upgrading from a release before the stamp existed looks like: the
    // copy is there and is perfectly valid, and nothing beside it says which
    // content it holds.
    await files.ensureContentDatabase();
    final File stamp = File(p.join(support.path, 'content.stamp'));
    await stamp.delete();
    final File target = File(p.join(support.path, 'content.db'));
    await files.ensureContentDatabase();

    expect(
      stamp.existsSync(),
      isTrue,
      reason: 'the refreshed copy must leave a stamp for the next launch',
    );
    expect(await stamp.readAsString(), files.contentStamp);
    expect(
      await target.length(),
      (await rootBundle.load(files.contentAsset)).lengthInBytes,
    );
  });

  test('new content of the same size still replaces the copy', () async {
    if (!await assetIsBundled()) {
      markTestSkipped('assets/content.db not built — see the file comment');
      return;
    }

    // The regression this check exists for. Comparing byte lengths, which is
    // what it used to do, this is indistinguishable from an up-to-date copy:
    // SQLite allocates in 4 KB pages, so correcting a translation or merging a
    // dhikr onto another id leaves a file of exactly the same length, and the
    // release would land with the user still reading the old content.
    await files.ensureContentDatabase();
    final File target = File(p.join(support.path, 'content.db'));
    final int sizeBefore = await target.length();

    // The same files, told that the update they ship carries different
    // content — the asset itself cannot be swapped inside a test.
    final WirdiDatabaseFiles updated = WirdiDatabaseFiles(
      supportDirectory: () async => support,
      documentsDirectory: () async => documents,
      contentStamp: '9.9.9 ${'0' * 64}',
    );

    await updated.ensureContentDatabase();

    expect(
      await target.length(),
      sizeBefore,
      reason: 'the asset is the same size, which is the whole point',
    );
    expect(
      await File(p.join(support.path, 'content.stamp')).readAsString(),
      updated.contentStamp,
      reason: 'the copy was not refreshed for content of an identical size',
    );
  });

  test('the stamp is written after the database, never before', () async {
    if (!await assetIsBundled()) {
      markTestSkipped('assets/content.db not built — see the file comment');
      return;
    }

    // A stamp left over from a previous copy must not vouch for a database
    // that was only half written before the process died.
    final File stamp = File(p.join(support.path, 'content.stamp'));
    await stamp.parent.create(recursive: true);
    await stamp.writeAsString(files.contentStamp, flush: true);

    // No content.db beside it: the stamp alone must not be taken as proof.
    final File copied = await files.ensureContentDatabase();

    expect(
      await copied.length(),
      (await rootBundle.load(files.contentAsset)).lengthInBytes,
    );
  });
}
