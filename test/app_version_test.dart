import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/app_version.dart';

/// [appVersion] is a copy of the pubspec's version. This is the check that
/// keeps the copy honest.
void main() {
  test('appVersion matches pubspec.yaml', () {
    final List<String> lines = File('pubspec.yaml').readAsLinesSync();
    final String? line = lines
        .where((String l) => l.startsWith('version:'))
        .firstOrNull;

    expect(line, isNotNull, reason: 'pubspec.yaml has no version:');
    // `version: 0.1.0` or `version: 0.1.0+3` — the build number is not part of
    // what the About screen shows.
    final String pubspecVersion = line!
        .substring('version:'.length)
        .trim()
        .split('+')
        .first;

    expect(
      appVersion,
      pubspecVersion,
      reason:
          'lib/app_version.dart says $appVersion and pubspec.yaml says '
          '$pubspecVersion. Update lib/app_version.dart.',
    );
  });
}
