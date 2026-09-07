import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/update_client.dart';
import '../domain/app_release.dart';
import 'settings.dart';

/// Whether this build can update itself at all.
///
/// Two conditions, neither of which changes while the app runs: the updater was
/// compiled in, and this is Android. iOS cannot install an app over itself —
/// Apple does not permit it, and the `.ipa` this project builds is unsigned and
/// uninstallable besides — so on iOS there is no banner and no setting rather
/// than a switch that does nothing.
///
/// A provider rather than a bare getter because a compile-time constant cannot
/// be overridden, and a widget test needs to render the banner without being on
/// Android.
final Provider<bool> selfUpdateSupportedProvider = Provider<bool>(
  (Ref ref) =>
      selfUpdateEnabled && defaultTargetPlatform == TargetPlatform.android,
  name: 'selfUpdateSupported',
);

/// The one object that talks to GitHub and to the Android installer.
final Provider<UpdateClient> updateClientProvider = Provider<UpdateClient>(
  (Ref ref) => UpdateClient(),
  name: 'updateClient',
);

/// The release worth offering, or null when there is nothing to offer.
///
/// Null is every reason at once: the setting is off, this is iOS, this build has
/// no updater, GitHub could not be reached, or the newest release is the one
/// already installed. The banner has one question to ask and this answers it.
///
/// Two things here are load-bearing and easy to get wrong:
///
/// `settingsProvider.select` rather than watching the whole settings object.
/// [SettingsController] writes `state` on every uncommitted frame of a text-size
/// slider drag, so watching all of it would re-run this — and fire an HTTPS
/// request — sixty times a second at somebody resizing their Arabic.
///
/// [Ref.keepAlive], because the brief is one check per launch. Riverpod disposes
/// a provider nothing is watching, and the banner unmounts whenever the Home tab
/// is not the visible one, so without this a check would run again on every
/// return to the tab.
final FutureProvider<AppRelease?> latestReleaseProvider =
    FutureProvider<AppRelease?>((Ref ref) async {
      ref.keepAlive();

      if (!ref.watch(selfUpdateSupportedProvider)) return null;

      final bool enabled = ref.watch(
        settingsProvider.select(
          (AsyncValue<WirdiSettings> s) => s.value?.checkForUpdates ?? false,
        ),
      );
      if (!enabled) return null;

      return ref.watch(updateClientProvider).latestRelease();
    }, name: 'latestRelease');

/// What the download is doing.
///
/// Idle almost always, because almost always there is nothing to download.
sealed class UpdateDownload {
  const UpdateDownload();
}

/// Nothing in flight. The banner offers the update.
final class UpdateIdle extends UpdateDownload {
  const UpdateIdle();
}

final class UpdateRunning extends UpdateDownload {
  const UpdateRunning({required this.received, required this.total});

  final int received;

  /// Bytes expected, or 0 when the server did not say.
  final int total;

  /// Null when the total is unknown, so the bar can be indeterminate rather
  /// than draw a fraction that is a guess.
  double? get fraction => total > 0 ? received / total : null;
}

/// The download or the install did not happen. The banner offers a retry.
final class UpdateFailed extends UpdateDownload {
  const UpdateFailed(this.message);

  final String message;
}

/// Android will not let Wirdi install packages, and the user has been sent to
/// the settings page that grants it.
///
/// Its own state and not a [UpdateFailed], because nothing went wrong: this is
/// the one-time round trip Android requires, and the banner says so in those
/// terms rather than as an error.
final class UpdateNeedsPermission extends UpdateDownload {
  const UpdateNeedsPermission();
}

/// Runs the download and hands the result to the system installer.
final class UpdateDownloadController extends Notifier<UpdateDownload> {
  @override
  UpdateDownload build() => const UpdateIdle();

  /// Downloads [release] and starts its install.
  ///
  /// Permission is asked for here rather than at launch: sending somebody to a
  /// system settings page for a thing they have not asked for yet is worse
  /// than asking at the moment they tap.
  Future<void> start(AppRelease release) async {
    if (state is UpdateRunning) return;

    state = const UpdateRunning(received: 0, total: 0);
    try {
      final InstallOutcome outcome = await ref
          .read(updateClientProvider)
          .downloadAndInstall(
            release,
            onProgress: (int received, int total) {
              state = UpdateRunning(received: received, total: total);
            },
          );

      state = switch (outcome) {
        // The system installer is on top now. Back to idle, so that coming
        // back from an install the user cancelled shows the offer again rather
        // than a progress bar stopped at the end.
        InstallOutcome.started => const UpdateIdle(),
        InstallOutcome.permissionRequired => const UpdateNeedsPermission(),
      };
    } on SocketException {
      state = const UpdateFailed('Could not reach GitHub.');
    } on Object {
      state = const UpdateFailed('The download failed. Nothing was installed.');
    }
  }
}

final NotifierProvider<UpdateDownloadController, UpdateDownload>
updateDownloadProvider =
    NotifierProvider<UpdateDownloadController, UpdateDownload>(
      UpdateDownloadController.new,
      name: 'updateDownload',
    );
