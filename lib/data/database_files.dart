import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
    this.userFileName = 'user.db',
    this.supportDirectory,
    this.documentsDirectory,
  });

  /// The bundled asset, produced by `content/scripts/build_content.py` and
  /// copied in by `tool/sync_content_asset.sh`.
  final String contentAsset;

  final String contentFileName;
  final String userFileName;

  /// Overrides `path_provider`'s application support directory. Tests only.
  final Future<Directory> Function()? supportDirectory;

  /// Overrides `path_provider`'s documents directory. Tests only.
  final Future<Directory> Function()? documentsDirectory;

  /// Copies the bundled `content.db` into the application support directory if
  /// it is not already there, or if the asset has changed size since the copy
  /// was made.
  ///
  /// Application support, not documents: this file is a rebuildable copy of a
  /// shipped asset. Backing it up would waste the user's iCloud quota, and it
  /// is replaced wholesale on every app update anyway.
  Future<File> ensureContentDatabase({bool force = false}) async {
    final Directory dir =
        await (supportDirectory ?? getApplicationSupportDirectory)();
    final File target = File(p.join(dir.path, contentFileName));

    final ByteData asset = await rootBundle.load(contentAsset);
    final int assetLength = asset.lengthInBytes;

    if (!force &&
        await target.exists() &&
        await target.length() == assetLength) {
      return target;
    }

    await target.parent.create(recursive: true);
    await target.writeAsBytes(
      asset.buffer.asUint8List(asset.offsetInBytes, assetLength),
      flush: true,
    );
    return target;
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
