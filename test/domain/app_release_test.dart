import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/app_release.dart';

/// The version comparison, which is the part of the update feature that decides
/// whether anything happens at all.
void main() {
  group('parsing', () {
    test('it reads three numbers', () {
      final AppVersion? version = AppVersion.parse('1.2.3');
      expect(version, isNotNull);
      expect(version!.major, 1);
      expect(version.minor, 2);
      expect(version.patch, 3);
    });

    test('it takes the v off a release tag', () {
      expect(AppVersion.parse('v0.2.0'), const AppVersion(0, 2, 0));
      expect(AppVersion.parse('V0.2.0'), const AppVersion(0, 2, 0));
    });

    test('it drops a build number, the way the release workflow does', () {
      expect(AppVersion.parse('0.3.0+9'), const AppVersion(0, 3, 0));
      expect(AppVersion.parse('v0.3.0+41'), const AppVersion(0, 3, 0));
    });

    test('it tolerates surrounding space', () {
      expect(AppVersion.parse('  0.2.0 '), const AppVersion(0, 2, 0));
    });

    // Everything that is not a version is null rather than an exception. All of
    // this arrives from outside the app — a tag somebody typed into GitHub —
    // and the caller reads null as "no update", which is the safe direction to
    // fail in.
    test('anything that is not three numbers is null', () {
      for (final String raw in <String>[
        '',
        '0.2',
        '0.2.0.1',
        'beta',
        '0.2.x',
        '0.2.0-beta',
        'v',
        '..',
        '-1.0.0',
      ]) {
        expect(AppVersion.parse(raw), isNull, reason: 'parsed "$raw"');
      }
    });
  });

  group('comparison', () {
    test('it orders by major, then minor, then patch', () {
      expect(
        const AppVersion(1, 0, 0).isNewerThan(const AppVersion(0, 9, 9)),
        isTrue,
      );
      expect(
        const AppVersion(0, 3, 0).isNewerThan(const AppVersion(0, 2, 9)),
        isTrue,
      );
      expect(
        const AppVersion(0, 2, 1).isNewerThan(const AppVersion(0, 2, 0)),
        isTrue,
      );
    });

    // The one a string comparison gets backwards, and the reason this is a
    // class with a test rather than an inline `>`. '0.10.0'.compareTo('0.9.0')
    // is negative, so a lexical check would decide ten is older than nine and
    // stop offering updates at exactly the point a project starts having them.
    test('ten is newer than nine, which a string compare gets wrong', () {
      expect(
        const AppVersion(0, 10, 0).isNewerThan(const AppVersion(0, 9, 0)),
        isTrue,
      );
      expect('0.10.0'.compareTo('0.9.0'), isNegative);
    });

    test('the same version is not an update', () {
      expect(
        const AppVersion(0, 2, 0).isNewerThan(const AppVersion(0, 2, 0)),
        isFalse,
      );
    });

    // A phone running a build ahead of the latest release — a local build, or
    // a release that was deleted — is left alone rather than offered a
    // downgrade it could not install anyway.
    test('an older release is not offered', () {
      expect(
        const AppVersion(0, 1, 0).isNewerThan(const AppVersion(0, 2, 0)),
        isFalse,
      );
    });

    test('equal versions are equal, and hash alike', () {
      expect(const AppVersion(1, 2, 3), const AppVersion(1, 2, 3));
      expect(
        const AppVersion(1, 2, 3).hashCode,
        const AppVersion(1, 2, 3).hashCode,
      );
      expect(const AppVersion(1, 2, 3), isNot(const AppVersion(1, 2, 4)));
    });

    test('it reads back as it was written', () {
      expect(const AppVersion(0, 2, 0).toString(), '0.2.0');
    });
  });
}
