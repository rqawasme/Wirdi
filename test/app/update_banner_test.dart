import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/update_client.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/app_release.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/providers/settings.dart';
import 'package:wirdi/providers/updates.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/screens/home_screen.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/update_banner.dart';

import '../support/fixtures.dart';

/// The update banner: when it appears, when it does not, and what tapping it
/// sets off.
///
/// The one assertion worth reading twice is that the setting being off means
/// the client is never asked anything. "Off, the app makes no network calls at
/// all" is a claim printed under a switch on the settings screen, and this is
/// what holds it true.
void main() {
  late TestDatabases dbs;
  late WirdiData data;

  final DateTime now = DateTime(2026, 9, 2, 9);

  setUp(() async {
    dbs = await TestDatabases.open();
    data = WirdiData(content: dbs.content, user: dbs.user, clock: () => now);
  });

  tearDown(() => dbs.close());

  Future<void> settle(WidgetTester tester) async {
    for (int frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Taps the banner and lets the work it starts actually finish.
  ///
  /// [WidgetTester.runAsync] rather than a tap and a pump: the download path
  /// creates a directory and writes a file, and `testWidgets` runs its body in
  /// a fake-async zone where real `dart:io` futures never complete no matter
  /// how many frames are pumped. Without this the state stays at nought bytes
  /// received forever, which is a test artefact and not a bug in the banner.
  Future<void> tapBanner(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Version 99.0.0 is available'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
  }

  /// A release newer than whatever this app is, so the test does not have to be
  /// edited every time the version is bumped.
  final AppRelease newer = AppRelease(
    version: const AppVersion(99, 0, 0),
    apkUrl: Uri.parse(
      'https://github.com/rqawasme/Wirdi/releases/download/v99.0.0/wirdi-99.0.0.apk',
    ),
    apkBytes: 60 * 1024 * 1024,
  );

  /// Records what the app asked the outside world to do.
  final List<String> calls = <String>[];

  setUp(calls.clear);

  UpdateClient fakeClient({
    AppRelease? release,
    InstallOutcome outcome = InstallOutcome.started,
  }) {
    return UpdateClient(
      readBody: (Uri url) async {
        calls.add('check');
        if (release == null) return null;
        return '{"tag_name": "v${release.version}", "assets": '
            '[{"name": "wirdi-${release.version}.apk", "size": '
            '${release.apkBytes}, "browser_download_url": "${release.apkUrl}"}]}';
      },
      downloadTo: (Uri url, File into, DownloadProgress onProgress) async {
        calls.add('download');
        await into.writeAsBytes(<int>[1]);
      },
      install: (File apk) async {
        calls.add('install');
        return outcome;
      },
      cacheDirectory: () async =>
          Directory.systemTemp.createTempSync('wirdi_banner'),
    );
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    required bool supported,
    required bool settingOn,
    UpdateClient? client,
  }) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    if (settingOn) {
      await data.userRepository.setSetting(SettingKeys.checkForUpdates, 'true');
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          wirdiDataProvider.overrideWithValue(data),
          selfUpdateSupportedProvider.overrideWithValue(supported),
          if (client != null) updateClientProvider.overrideWithValue(client),
        ],
        child: MaterialApp(
          theme: WirdiTheme.light(),
          home: const Scaffold(body: HomeScreen()),
          onGenerateRoute: WirdiRouter.onGenerateRoute,
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('with the setting off it never asks, and shows nothing', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      supported: true,
      settingOn: false,
      client: fakeClient(release: newer),
    );

    expect(find.byType(UpdateBanner), findsOneWidget);
    // The widget is in the tree but renders nothing, and — the part that
    // matters — the client was never asked.
    expect(find.textContaining('is available'), findsNothing);
    expect(calls, isEmpty);
  });

  testWidgets('on a platform that cannot self-update it never asks', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      supported: false,
      settingOn: true,
      client: fakeClient(release: newer),
    );

    expect(find.textContaining('is available'), findsNothing);
    expect(calls, isEmpty);
  });

  testWidgets('with nothing newer released it shows nothing', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      supported: true,
      settingOn: true,
      client: fakeClient(),
    );

    expect(calls, <String>['check']);
    expect(find.textContaining('is available'), findsNothing);
  });

  testWidgets('a newer release is offered, with its size', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      supported: true,
      settingOn: true,
      client: fakeClient(release: newer),
    );

    expect(find.text('Version 99.0.0 is available'), findsOneWidget);
    expect(find.text('Download and install'), findsOneWidget);
    // The size is stated before anything is downloaded: sixty megabytes over
    // mobile data should be a choice rather than a surprise.
    expect(find.textContaining('60.0 MB'), findsOneWidget);
  });

  testWidgets('tapping it downloads and hands off to the installer', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      supported: true,
      settingOn: true,
      client: fakeClient(release: newer),
    );

    await tapBanner(tester);

    expect(calls, <String>['check', 'download', 'install']);
  });

  testWidgets(
    'being unable to install is explained, not reported as an error',
    (WidgetTester tester) async {
      await pumpHome(
        tester,
        supported: true,
        settingOn: true,
        client: fakeClient(
          release: newer,
          outcome: InstallOutcome.permissionRequired,
        ),
      );

      await tapBanner(tester);

      expect(
        find.textContaining('Allow Wirdi to install apps'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    },
  );

  testWidgets('a failed download leaves the home screen standing', (
    WidgetTester tester,
  ) async {
    final UpdateClient failing = UpdateClient(
      readBody: (Uri url) async =>
          '{"tag_name": "v99.0.0", "assets": [{"name": "wirdi-99.0.0.apk", '
          '"size": 1, "browser_download_url": "https://example.invalid/a.apk"}]}',
      downloadTo: (Uri url, File into, DownloadProgress onProgress) async =>
          throw const SocketException('cut off'),
      install: (File apk) async => InstallOutcome.started,
      cacheDirectory: () async =>
          Directory.systemTemp.createTempSync('wirdi_banner'),
    );

    await pumpHome(tester, supported: true, settingOn: true, client: failing);
    await tapBanner(tester);

    // No error screen, no exception surfaced to the framework: the banner says
    // what happened and offers the tap again.
    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.textContaining('Could not reach GitHub'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
