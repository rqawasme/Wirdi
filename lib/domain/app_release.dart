/// A released version of the app, and the comparison that decides whether one
/// is worth offering.
///
/// Pure Dart on purpose, like the rest of `lib/domain/`: the comparison is the
/// part of the update feature most worth testing and least worth mocking, so it
/// lives where a test can reach it without a device, a network or a widget.
library;

/// A version of the app, as the three numbers `pubspec.yaml` carries.
///
/// The app's own version is [String] — `lib/app_version.dart` — and so is a
/// release tag. Comparing those two as strings is the bug this class exists to
/// prevent: `'0.10.0'.compareTo('0.9.0')` is negative, so a lexical comparison
/// decides that ten is older than nine and silently stops offering updates at
/// exactly the point a project starts having them.
final class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  /// Reads `0.2.0`, `v0.2.0`, or either with a `+build` suffix.
  ///
  /// Returns null rather than throwing for anything else. Everything parsed
  /// here comes from outside the app — a tag someone typed into GitHub, a
  /// release created by hand — so a tag that is not a version is an ordinary
  /// thing to meet, not an error worth crashing a launch over. The caller
  /// treats null as "no update", which is the safe direction to fail in: the
  /// worst case is a banner that does not appear.
  static AppVersion? parse(String raw) {
    String text = raw.trim();
    if (text.startsWith('v') || text.startsWith('V')) {
      text = text.substring(1);
    }
    // The build number is not part of a version's identity here, the same way
    // the release workflow strips it before tagging.
    text = text.split('+').first;

    final List<String> parts = text.split('.');
    if (parts.length != 3) return null;

    final int? major = int.tryParse(parts[0]);
    final int? minor = int.tryParse(parts[1]);
    final int? patch = int.tryParse(parts[2]);
    if (major == null || minor == null || patch == null) return null;
    if (major < 0 || minor < 0 || patch < 0) return null;

    return AppVersion(major, minor, patch);
  }

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  /// Whether this version is worth offering to somebody running [installed].
  ///
  /// Strictly newer. Equal is not an update, and older is not either: a phone
  /// running a build ahead of the latest release — a local build, or a release
  /// that was deleted — is left alone rather than being offered a downgrade it
  /// could not install anyway.
  bool isNewerThan(AppVersion installed) => compareTo(installed) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(AppVersion, major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// A release on GitHub, reduced to the two facts the app needs: which version
/// it is, and where its APK is.
///
/// A release with no APK attached does not become one of these. That is not
/// hypothetical — the iOS artifact is published alongside the Android one, and
/// a release whose Android job failed would carry only the `.ipa`. Offering an
/// update that cannot be downloaded is worse than offering none.
final class AppRelease {
  const AppRelease({
    required this.version,
    required this.apkUrl,
    required this.apkBytes,
  });

  final AppVersion version;

  /// The direct download URL for the APK asset.
  final Uri apkUrl;

  /// The asset's size, used to show progress against something.
  ///
  /// Zero when GitHub did not report one, which the progress display reads as
  /// "unknown" rather than as an empty file.
  final int apkBytes;

  @override
  String toString() => 'AppRelease($version, $apkUrl)';
}
