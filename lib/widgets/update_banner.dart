import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_version.dart';
import '../domain/app_release.dart';
import '../providers/updates.dart';
import '../theme/theme.dart';

/// A newer release exists, and a way to install it.
///
/// Built from the app's card recipe — flat [Material], `surfaceContainer`, a
/// hairline of `outlineVariant` — because this is a notice, not an alert.
/// `primary` reaches exactly one thing, the line that is the action. No gold:
/// `tertiary` is deliberately unclaimed, and a version number is not the place
/// to claim it. No badge and no dot anywhere, for the same reason the nav bar
/// carries none.
///
/// There is no dismiss. A notice that can be waved away is one the app then has
/// to remember having been waved away, per version, forever. This one goes when
/// the update is installed, and until then it is one card at the top of a list
/// that scrolls.
///
/// It renders nothing at all unless the check has come back with something —
/// which is the usual case, since the check is off unless it was turned on.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` with a fallback rather than a switch over the AsyncValue: a
    // check still in flight, or one that failed, must leave the home screen
    // exactly as it would otherwise have been. Nothing here is worth a spinner
    // and nothing here is worth an error.
    final AppRelease? release = ref.watch(latestReleaseProvider).value;
    if (release == null) return const SizedBox.shrink();

    final UpdateDownload download = ref.watch(updateDownloadProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final bool running = download is UpdateRunning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.space4,
        WirdiMetrics.space3,
        WirdiMetrics.space4,
        0,
      ),
      child: Material(
        color: scheme.surfaceContainer,
        elevation: WirdiMetrics.elevation,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: WirdiMetrics.card,
          side: BorderSide(
            color: scheme.outlineVariant,
            width: WirdiMetrics.hairline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Not tappable mid-download. Tapping again would do nothing anyway —
          // the controller ignores it — and an unresponsive tap target reads as
          // a broken one.
          onTap: running
              ? null
              : () => unawaited(
                  ref.read(updateDownloadProvider.notifier).start(release),
                ),
          child: Padding(
            padding: const EdgeInsets.all(WirdiMetrics.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Version ${release.version} is available',
                  style: type.sectionHeader.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: WirdiMetrics.space1),
                Text(
                  _body(release, download),
                  style: type.caption.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: WirdiMetrics.space2),
                if (download case final UpdateRunning progress)
                  LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: WirdiMetrics.unit / 2,
                    backgroundColor: scheme.outlineVariant,
                    color: scheme.primary,
                  )
                else
                  Text(switch (download) {
                    UpdateFailed() => 'Try again',
                    UpdateNeedsPermission() => 'Try again',
                    _ => 'Download and install',
                  }, style: type.caption.copyWith(color: scheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The quiet line under the version.
  ///
  /// Says the size before anything is downloaded, because a download this big
  /// over mobile data should be a choice rather than a surprise.
  static String _body(AppRelease release, UpdateDownload download) {
    return switch (download) {
      UpdateFailed(:final String message) => message,
      UpdateNeedsPermission() =>
        'Allow Wirdi to install apps in Settings, then tap again.',
      UpdateRunning(:final int received, :final int total) when total > 0 =>
        '${_megabytes(received)} of ${_megabytes(total)}',
      UpdateRunning(:final int received) => _megabytes(received),
      UpdateIdle() when release.apkBytes > 0 =>
        'You have $appVersion. The download is ${_megabytes(release.apkBytes)}.',
      UpdateIdle() => 'You have $appVersion.',
    };
  }

  static String _megabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
