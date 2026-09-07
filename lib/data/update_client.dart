import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../app_version.dart';
import '../domain/app_release.dart';

/// Whether this build carries the self-updater at all.
///
/// The updater is for sideloaded builds — it is how a developer updates a
/// phone without plugging it into a computer. A Play Store build must not
/// carry it: `REQUEST_INSTALL_PACKAGES` gets an app rejected unless installing
/// packages is a core advertised feature.
///
/// Defaults to on, because the release workflow builds a plain
/// `flutter build apk --release` and that APK is the one being sideloaded.
/// A Play build turns it off with `--dart-define=WIRDI_SELF_UPDATE=false`.
///
/// **This is half of the switch.** It removes the Dart — the check, the
/// download, the banner — but a `--dart-define` cannot reach
/// `AndroidManifest.xml`, so the permission and the `FileProvider` are still
/// declared. Preparing a Play build means turning this off *and* removing
/// those three blocks from the manifest. `docs/RELEASING.md` says so too, in
/// the place somebody preparing that build would be reading.
const bool selfUpdateEnabled = bool.fromEnvironment(
  'WIRDI_SELF_UPDATE',
  defaultValue: true,
);

/// What happened when an install was asked for.
enum InstallOutcome {
  /// Android's package installer is now on screen. Whether the user goes
  /// through with it is not something the app gets told.
  started,

  /// "Install unknown apps" is not granted for Wirdi, so the system settings
  /// page for that switch was opened instead. This is not a failure and not an
  /// error — it is the one-time round trip Android requires — so the caller
  /// says so plainly and lets the user come back and tap again.
  permissionRequired,
}

/// Everything the update feature touches outside of Dart: the network, the
/// filesystem, and the Android package installer.
///
/// One class, the way `WirdiDatabaseFiles` is one class, and for the same
/// reason — it is the platform seam. Every piece of contact is a constructor
/// parameter with a real default, so a test can exercise the real parsing,
/// the real comparison and the real banner logic with no network under it and
/// no device.
///
/// It is also what makes this feature removable. When a Play build is real,
/// what has to come out is this file, its provider, its widget and three
/// blocks of manifest — not a thread pulled through the whole app.
final class UpdateClient {
  UpdateClient({
    Future<String?> Function(Uri url)? readBody,
    Future<void> Function(Uri url, File into, DownloadProgress onProgress)?
    downloadTo,
    Future<InstallOutcome> Function(File apk)? install,
    Future<Directory> Function()? cacheDirectory,
    String installedVersion = appVersion,
  }) : _readBody = readBody ?? _httpGet,
       _downloadTo = downloadTo ?? _httpDownload,
       _install = install ?? _androidInstall,
       _cacheDirectory = cacheDirectory ?? getTemporaryDirectory,
       _installedVersion = installedVersion;

  final Future<String?> Function(Uri url) _readBody;
  final Future<void> Function(Uri url, File into, DownloadProgress onProgress)
  _downloadTo;
  final Future<InstallOutcome> Function(File apk) _install;
  final Future<Directory> Function() _cacheDirectory;
  final String _installedVersion;

  /// The repository releases are published from.
  ///
  /// `/releases/latest` and not `/releases`: that endpoint skips drafts and
  /// prereleases, which is what makes a prerelease a safe thing to publish by
  /// hand without every phone offering it.
  static final Uri latestReleaseUrl = Uri.https(
    'api.github.com',
    '/repos/rqawasme/Wirdi/releases/latest',
  );

  /// The newest release worth offering, or null if there is not one.
  ///
  /// **Never throws.** Null covers every uninteresting case together — the
  /// radio is off, GitHub answered 404 or rate-limited us, no newer version
  /// exists, the release has no APK on it, the tag is not a version, the
  /// response was not the shape expected. None of those is news: from the
  /// user's side they all mean the same thing, which is that no banner
  /// appears. A failed update check is not a failure worth reporting in an app
  /// whose normal condition is offline.
  Future<AppRelease?> latestRelease() async {
    try {
      return await _latestRelease();
    } on Object {
      return null;
    }
  }

  Future<AppRelease?> _latestRelease() async {
    final AppVersion? installed = AppVersion.parse(_installedVersion);
    // Unparseable means the app's own const is malformed, which
    // test/app_version_test.dart exists to prevent. Offering an update on the
    // strength of a version we cannot read is the wrong way to fail.
    if (installed == null) return null;

    final String? body = await _readBody(latestReleaseUrl);
    if (body == null) return null;

    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) return null;

    final Object? tag = decoded['tag_name'];
    if (tag is! String) return null;

    final AppVersion? released = AppVersion.parse(tag);
    if (released == null) return null;
    if (!released.isNewerThan(installed)) return null;

    final Object? assets = decoded['assets'];
    if (assets is! List<Object?>) return null;

    for (final Object? asset in assets) {
      if (asset is! Map<String, Object?>) continue;

      final Object? name = asset['name'];
      final Object? url = asset['browser_download_url'];
      if (name is! String || url is! String) continue;
      if (!name.endsWith('.apk')) continue;

      final Uri? parsed = Uri.tryParse(url);
      if (parsed == null) continue;

      final Object? size = asset['size'];
      return AppRelease(
        version: released,
        apkUrl: parsed,
        apkBytes: size is int && size > 0 ? size : 0,
      );
    }

    // A release with no APK on it. The iOS artifact is published alongside the
    // Android one, so a release whose Android job failed carries only the
    // .ipa — real, and not something to offer.
    return null;
  }

  /// Downloads [release]'s APK and hands it to Android's package installer.
  ///
  /// The file goes in the app's own cache directory, which is what the
  /// `FileProvider` in `AndroidManifest.xml` is scoped to. Anywhere else and
  /// the installer gets a `content://` URI it is not permitted to read.
  Future<InstallOutcome> downloadAndInstall(
    AppRelease release, {
    required DownloadProgress onProgress,
  }) async {
    final Directory cache = await _cacheDirectory();
    final Directory updates = Directory('${cache.path}/$downloadDirectoryName');
    await updates.create(recursive: true);

    final File apk = File('${updates.path}/wirdi-${release.version}.apk');
    // A previous attempt that died mid-download would otherwise be appended to
    // or, worse, handed to the installer half-written.
    if (apk.existsSync()) await apk.delete();

    await _downloadTo(release.apkUrl, apk, onProgress);
    return _install(apk);
  }

  // --- the real implementations ------------------------------------------

  static Future<String?> _httpGet(Uri url) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final HttpClientRequest request = await client.getUrl(url);
      // GitHub rejects an API request that does not identify itself, and asks
      // that the name be the application's rather than the HTTP library's.
      request.headers
        ..set(HttpHeaders.userAgentHeader, 'Wirdi/$appVersion')
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set('X-GitHub-Api-Version', '2022-11-28');

      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 20),
      );

      if (response.statusCode != HttpStatus.ok) {
        // Drained rather than left open: an undrained response holds its
        // socket until the client is closed.
        await response.drain<void>();

        // 404 is the ordinary answer for a repository whose only release is a
        // prerelease, because /releases/latest skips drafts and prereleases —
        // which is exactly the state this repository was in when this was
        // written. 403 is the unauthenticated rate limit, sixty an hour per
        // address. Neither is a fault: both mean there is nothing to offer.
        return null;
      }
      // Awaited rather than returned: the finally below closes the client, and
      // an unawaited future would be closed out from under.
      return await response.transform(utf8.decoder).join();
    } finally {
      // Not force: an in-flight response would be cut off. Without this the
      // pool holds the connection open for its idle timeout.
      client.close();
    }
  }

  static Future<void> _httpDownload(
    Uri url,
    File into,
    DownloadProgress onProgress,
  ) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, 'Wirdi/$appVersion');

      // GitHub answers an asset URL with a 302 to objects.githubusercontent.com.
      // HttpClient follows it by default, which is the whole reason this uses
      // browser_download_url rather than the API's asset endpoint — the latter
      // needs an Accept header that must survive the hop.
      final HttpClientResponse response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException(
          'Download answered ${response.statusCode}',
          uri: url,
        );
      }

      // -1 when the server does not say. Reported as 0 so the caller shows an
      // indeterminate bar rather than dividing by a negative.
      final int total = response.contentLength > 0 ? response.contentLength : 0;
      int received = 0;

      final IOSink sink = into.openWrite();
      try {
        await for (final List<int> chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  /// The channel [MainActivity] listens on.
  ///
  /// Public so that test/app/update_manifest_test.dart can hold this string and
  /// the one in MainActivity.kt to each other. Nothing else checks them: Kotlin
  /// is outside `flutter analyze`, and a mismatch here is a
  /// MissingPluginException on a phone rather than anything a build would say.
  static const String installerChannel = 'app.wirdi/installer';

  /// The FileProvider authority declared in AndroidManifest.xml, as
  /// `${applicationId}.updates`.
  static const String fileProviderSuffix = '.updates';

  /// The cache subdirectory the FileProvider is scoped to share.
  static const String downloadDirectoryName = 'updates';

  static const MethodChannel _channel = MethodChannel(installerChannel);

  static Future<InstallOutcome> _androidInstall(File apk) async {
    final bool permitted =
        await _channel.invokeMethod<bool>('canInstall') ?? false;

    if (!permitted) {
      await _channel.invokeMethod<void>('requestInstallPermission');
      return InstallOutcome.permissionRequired;
    }

    await _channel.invokeMethod<void>('install', <String, Object?>{
      'path': apk.path,
    });
    return InstallOutcome.started;
  }
}

/// Bytes received so far, and the total when the server reported one — 0 when
/// it did not.
typedef DownloadProgress = void Function(int received, int total);
