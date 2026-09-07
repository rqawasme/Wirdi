import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'content_stamp.dart';

/// Where the two databases live on disk, and how `content.db` gets there.
///
/// The platform seam: the only part of the data layer that touches
/// `path_provider` or the asset bundle. The rest of the suite opens in-memory
/// databases and never comes here.
///
/// [supportDirectory] and [documentsDirectory] exist so that this path can be
/// exercised at all. Left null they are `path_provider`'s, which is what the
/// app uses; given temporary directories, a test can run the real asset load
/// and the real copy without a device under it.
class WirdiDatabaseFiles {
  const WirdiDatabaseFiles({
    this.contentAsset = 'assets/content.db',
    this.contentFileName = 'content.db',
    this.contentStampFileName = 'content.stamp',
    this.contentStamp = bundledContentStamp,
    this.userFileName = 'user.db',
    this.supportDirectory,
    this.documentsDirectory,
  });

  /// The bundled asset, produced by `content/scripts/build_content.py` and
  /// copied in by `tool/sync_content_asset.sh`.
  final String contentAsset;

  final String contentFileName;

  /// Sits beside the copy and records the [contentStamp] it was made from.
  final String contentStampFileName;

  /// What identifies the content in [contentAsset]: its content version and
  /// the checksum over its rows, generated into `content_stamp.dart` by
  /// `tool/sync_content_asset.sh`. Overridden by tests to stand in for an app
  /// update carrying different content.
  final String contentStamp;

  final String userFileName;

  /// Overrides `path_provider`'s application support directory. Tests only.
  final Future<Directory> Function()? supportDirectory;

  /// Overrides `path_provider`'s documents directory. Tests only.
  final Future<Directory> Function()? documentsDirectory;

  /// Copies the bundled `content.db` into the application support directory if
  /// it is not already there, or if the update that has just been installed
  /// brought different content with it.
  ///
  /// Application support, not documents: this file is a rebuildable copy of a
  /// shipped asset. Backing it up would waste the user's iCloud quota, and it
  /// is replaced wholesale whenever the content changes anyway.
  ///
  /// ## Why a stamp rather than the file's size
  ///
  /// This compared the copy's byte length against the asset's, which is wrong
  /// in the direction that hurts: SQLite allocates in 4 KB pages, so a
  /// corrected translation, an added note, or a dhikr merged onto another id
  /// all leave a file of exactly the same length. The copy would be kept, and
  /// the app would go on serving the previous release's content with nothing
  /// to show that it had.
  ///
  /// [contentStamp] identifies the content itself, so any change to it takes.
  /// Reading it costs a few bytes off disk rather than the 4.6 MB the length
  /// check had to pull out of the asset bundle on every single launch, so the
  /// fix is also the faster path.
  Future<File> ensureContentDatabase({bool force = false}) async {
    final Directory dir =
        await (supportDirectory ?? getApplicationSupportDirectory)();
    final File target = File(p.join(dir.path, contentFileName));
    final File stamp = File(p.join(dir.path, contentStampFileName));

    if (!force && await target.exists() && await _stamped(stamp)) {
      return target;
    }

    await target.parent.create(recursive: true);

    // Order matters, and it is: clear the stamp, write the database, write the
    // stamp. Killed at any point in between, the next launch finds a stamp
    // that is missing or does not match and copies again, rather than trusting
    // a half-written database because the stamp beside it still said the old
    // content was there.
    if (await stamp.exists()) {
      await stamp.delete();
    }

    final ByteData asset = await rootBundle.load(contentAsset);
    await target.writeAsBytes(
      asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      flush: true,
    );
    await stamp.writeAsString(contentStamp, flush: true);
    return target;
  }

  /// Whether [stamp] records that the copy beside it was made from
  /// [contentStamp].
  ///
  /// A missing stamp is a mismatch, which is what carries an install made
  /// before the stamp existed over to a copy that has one.
  Future<bool> _stamped(File stamp) async {
    if (!await stamp.exists()) {
      return false;
    }
    try {
      return (await stamp.readAsString()).trim() == contentStamp;
    } on FileSystemException {
      return false;
    }
  }

  /// `user.db` lives in the documents directory specifically, so that iOS
  /// iCloud backup and Android Auto Backup pick it up. That is the entire
  /// backup strategy: there is no sync and no server, so a database the
  /// platform does not back up is a database the user loses with their phone.
  Future<File> userDatabase() async {
    final Directory dir =
        await (documentsDirectory ?? getApplicationDocumentsDirectory)();
    return File(p.join(dir.path, userFileName));
  }
}
