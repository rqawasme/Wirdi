import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/update_client.dart';
import 'package:wirdi/domain/app_release.dart';

/// [UpdateClient] against hand-written GitHub payloads.
///
/// The network and the installer are the constructor's injectable seams, so
/// everything here runs the real parsing, the real asset picking and the real
/// comparison with nothing under it. No mocking package: the repository has
/// none, and a function is enough.
void main() {
  /// A `/releases/latest` body, shaped like the real one.
  String releaseJson({
    required String tag,
    List<Map<String, Object?>> assets = const <Map<String, Object?>>[],
  }) {
    return jsonEncode(<String, Object?>{
      'tag_name': tag,
      'name': tag,
      'draft': false,
      'prerelease': false,
      'assets': assets,
    });
  }

  Map<String, Object?> asset(String name, {int size = 60902131}) {
    return <String, Object?>{
      'name': name,
      'size': size,
      'browser_download_url':
          'https://github.com/rqawasme/Wirdi/releases/download/v0.3.0/$name',
    };
  }

  UpdateClient clientReturning(String? body, {String installed = '0.2.0'}) {
    return UpdateClient(
      readBody: (Uri url) async => body,
      installedVersion: installed,
    );
  }

  group('finding a release', () {
    test('it offers a newer version with an APK on it', () async {
      final UpdateClient client = clientReturning(
        releaseJson(
          tag: 'v0.3.0',
          assets: <Map<String, Object?>>[asset('wirdi-0.3.0.apk')],
        ),
      );

      final AppRelease? release = await client.latestRelease();
      expect(release, isNotNull);
      expect(release!.version, const AppVersion(0, 3, 0));
      expect(release.apkBytes, 60902131);
      expect(release.apkUrl.host, 'github.com');
    });

    test('the version already installed is not an update', () async {
      final UpdateClient client = clientReturning(
        releaseJson(
          tag: 'v0.2.0',
          assets: <Map<String, Object?>>[asset('wirdi-0.2.0.apk')],
        ),
      );
      expect(await client.latestRelease(), isNull);
    });

    test('an older release is not offered', () async {
      final UpdateClient client = clientReturning(
        releaseJson(
          tag: 'v0.1.0',
          assets: <Map<String, Object?>>[asset('wirdi-0.1.0.apk')],
        ),
      );
      expect(await client.latestRelease(), isNull);
    });

    // The asset name is not a contract. The v0.1.0 release of this app carries
    // `app-release.apk`, because the workflow that renames it to
    // `wirdi-<version>.apk` was written after that release was cut. Matching an
    // exact name would mean the updater could not update off any build
    // predating the workflow.
    test('any .apk asset will do, whatever it is called', () async {
      final UpdateClient client = clientReturning(
        releaseJson(
          tag: 'v0.3.0',
          assets: <Map<String, Object?>>[asset('app-release.apk')],
        ),
      );
      final AppRelease? release = await client.latestRelease();
      expect(release, isNotNull);
      expect(release!.apkUrl.path, endsWith('app-release.apk'));
    });

    // The iOS artifact is published alongside the Android one, so a release
    // whose Android job failed carries only the .ipa. Offering an update that
    // cannot be downloaded is worse than offering none.
    test('a release with no APK on it is not offered', () async {
      final UpdateClient client = clientReturning(
        releaseJson(
          tag: 'v0.3.0',
          assets: <Map<String, Object?>>[asset('wirdi-0.3.0-unsigned.ipa')],
        ),
      );
      expect(await client.latestRelease(), isNull);
    });

    test('it picks the APK out of a release carrying both', () async {
      final UpdateClient client = clientReturning(
        releaseJson(
          tag: 'v0.3.0',
          assets: <Map<String, Object?>>[
            asset('wirdi-0.3.0-unsigned.ipa'),
            asset('wirdi-0.3.0.apk'),
          ],
        ),
      );
      final AppRelease? release = await client.latestRelease();
      expect(release, isNotNull);
      expect(release!.apkUrl.path, endsWith('.apk'));
    });

    test(
      'a missing size reads as unknown rather than as an empty file',
      () async {
        final UpdateClient client = clientReturning(
          jsonEncode(<String, Object?>{
            'tag_name': 'v0.3.0',
            'assets': <Map<String, Object?>>[
              <String, Object?>{
                'name': 'wirdi-0.3.0.apk',
                'browser_download_url':
                    'https://github.com/rqawasme/Wirdi/releases/download/v0.3.0/wirdi-0.3.0.apk',
              },
            ],
          }),
        );
        final AppRelease? release = await client.latestRelease();
        expect(release, isNotNull);
        expect(release!.apkBytes, 0);
      },
    );
  });

  group('nothing to offer', () {
    // 404 is the ordinary answer for a repository whose only release is a
    // prerelease, since /releases/latest skips those — which is the state this
    // repository was actually in when this was written.
    test('no body at all is simply no update', () async {
      expect(await clientReturning(null).latestRelease(), isNull);
    });

    test('a tag that is not a version is ignored', () async {
      final UpdateClient client = clientReturning(releaseJson(tag: 'nightly'));
      expect(await client.latestRelease(), isNull);
    });

    test('a response that is not the expected shape is ignored', () async {
      for (final String body in <String>[
        'not json at all',
        '[]',
        '{}',
        '{"tag_name": 3}',
        '{"tag_name": "v0.3.0"}',
        '{"tag_name": "v0.3.0", "assets": "none"}',
        '{"tag_name": "v0.3.0", "assets": [null]}',
      ]) {
        expect(
          await clientReturning(body).latestRelease(),
          isNull,
          reason: 'accepted $body',
        );
      }
    });

    // The normal condition of this app is offline. A check that could not
    // happen is not news, and must never reach the user as an error.
    test('a network failure is swallowed, not thrown', () async {
      final UpdateClient client = UpdateClient(
        readBody: (Uri url) async =>
            throw const SocketException('no route to host'),
      );
      expect(await client.latestRelease(), isNull);
    });
  });

  group('downloading', () {
    late Directory cache;

    setUp(() => cache = Directory.systemTemp.createTempSync('wirdi_update'));
    tearDown(() => cache.deleteSync(recursive: true));

    // Not const: Uri.parse is not a const constructor.
    final AppRelease release = AppRelease(
      version: const AppVersion(0, 3, 0),
      apkUrl: Uri.parse(
        'https://github.com/rqawasme/Wirdi/releases/download/v0.3.0/wirdi-0.3.0.apk',
      ),
      apkBytes: 4,
    );

    test(
      'it writes into the directory the FileProvider is scoped to',
      () async {
        File? installed;
        final UpdateClient client = UpdateClient(
          downloadTo: (Uri url, File into, DownloadProgress onProgress) async {
            await into.writeAsBytes(<int>[1, 2, 3, 4]);
            onProgress(4, 4);
          },
          install: (File apk) async {
            installed = apk;
            return InstallOutcome.started;
          },
          cacheDirectory: () async => cache,
        );

        final InstallOutcome outcome = await client.downloadAndInstall(
          release,
          onProgress: (int received, int total) {},
        );

        expect(outcome, InstallOutcome.started);
        expect(installed, isNotNull);
        // `updates/` under the cache, which is all res/xml/file_paths.xml
        // permits the FileProvider to share.
        expect(installed!.path, contains('/updates/'));
        expect(installed!.readAsBytesSync(), <int>[1, 2, 3, 4]);
      },
    );

    test('a half-finished previous download is cleared first', () async {
      final Directory updates = Directory('${cache.path}/updates')
        ..createSync(recursive: true);
      final File stale = File('${updates.path}/wirdi-0.3.0.apk')
        ..writeAsBytesSync(<int>[9, 9, 9, 9, 9, 9, 9, 9]);

      final UpdateClient client = UpdateClient(
        downloadTo: (Uri url, File into, DownloadProgress onProgress) async {
          await into.writeAsBytes(<int>[1, 2, 3, 4]);
        },
        install: (File apk) async => InstallOutcome.started,
        cacheDirectory: () async => cache,
      );

      await client.downloadAndInstall(
        release,
        onProgress: (int received, int total) {},
      );
      expect(stale.readAsBytesSync(), <int>[1, 2, 3, 4]);
    });

    test('progress is reported through to the caller', () async {
      final List<int> seen = <int>[];
      final UpdateClient client = UpdateClient(
        downloadTo: (Uri url, File into, DownloadProgress onProgress) async {
          await into.writeAsBytes(<int>[1, 2, 3, 4]);
          onProgress(2, 4);
          onProgress(4, 4);
        },
        install: (File apk) async => InstallOutcome.started,
        cacheDirectory: () async => cache,
      );

      await client.downloadAndInstall(
        release,
        onProgress: (int received, int total) => seen.add(received),
      );
      expect(seen, <int>[2, 4]);
    });

    test('it reports back that permission is needed', () async {
      final UpdateClient client = UpdateClient(
        downloadTo: (Uri url, File into, DownloadProgress onProgress) async {
          await into.writeAsBytes(<int>[1]);
        },
        install: (File apk) async => InstallOutcome.permissionRequired,
        cacheDirectory: () async => cache,
      );

      expect(
        await client.downloadAndInstall(
          release,
          onProgress: (int received, int total) {},
        ),
        InstallOutcome.permissionRequired,
      );
    });
  });
}
