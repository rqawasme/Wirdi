import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/update_client.dart';

/// The strings the Dart and the Android halves of the updater have to agree on.
///
/// `analysis_options.yaml` excludes `android/**` and `dart format` covers only
/// `lib test tool`, so nothing on the Dart side reads these files. CI does build
/// a debug APK, which catches a manifest that will not merge and a resource that
/// is not there — but a channel name or a FileProvider authority that simply
/// disagrees between the two halves compiles perfectly and fails on a phone, as
/// a MissingPluginException or an IllegalArgumentException. That is the gap this
/// closes. Same idea as `test/app_version_test.dart`: a duplicated string is
/// safe only if something fails when the copies drift.
void main() {
  String read(String path) {
    final File file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing');
    return file.readAsStringSync();
  }

  late String manifest;
  late String activity;
  late String filePaths;

  setUp(() {
    manifest = read('android/app/src/main/AndroidManifest.xml');
    activity = read('android/app/src/main/kotlin/app/wirdi/MainActivity.kt');
    filePaths = read('android/app/src/main/res/xml/file_paths.xml');
  });

  test('the release manifest asks for what the updater needs', () {
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.REQUEST_INSTALL_PACKAGES'));
  });

  test('both halves name the same method channel', () {
    expect(activity, contains('"${UpdateClient.installerChannel}"'));
  });

  test('both halves name the same FileProvider authority', () {
    expect(
      manifest,
      contains(
        'android:authorities="\${applicationId}'
        '${UpdateClient.fileProviderSuffix}"',
      ),
    );
    expect(
      activity,
      contains('"\$packageName${UpdateClient.fileProviderSuffix}"'),
    );
  });

  test('the FileProvider shares the directory the download is written to', () {
    // getUriForFile throws IllegalArgumentException for a file outside the
    // declared paths, so this pair disagreeing means every install fails.
    expect(filePaths, contains('cache-path'));
    expect(
      filePaths,
      contains('path="${UpdateClient.downloadDirectoryName}/"'),
    );
  });

  test('the activity handles every method the client calls', () {
    for (final String method in <String>[
      'canInstall',
      'requestInstallPermission',
      'install',
    ]) {
      expect(activity, contains('"$method"'), reason: '$method is unhandled');
    }
  });

  // The check above is only worth having if it can fail, and this is the
  // failure it was written for: the first draft of the manifest comment said
  // `--dart-define` and XML forbids a double hyphen inside a comment, which
  // would have broken the Android build with nothing in `flutter test` to say
  // so.
  test('the well-formedness check rejects what it is meant to', () {
    expect(
      () => XmlWellFormedness.check('<a><!-- pass --dart-define --></a>'),
      throwsFormatException,
    );
    expect(() => XmlWellFormedness.check('<a><b></a>'), throwsFormatException);
    expect(() => XmlWellFormedness.check('<a></a></a>'), throwsFormatException);
    expect(
      () => XmlWellFormedness.check('<a><!-- unterminated'),
      throwsFormatException,
    );
    // And accepts an ordinary document, self-closing tags and all.
    expect(
      () => XmlWellFormedness.check(
        '<?xml version="1.0"?><a><b/><!-- fine --><c>x</c></a>',
      ),
      returnsNormally,
    );
  });

  // XML comments cannot contain a double hyphen, and the removal notes in this
  // manifest are exactly where somebody would reach for `--dart-define`. A
  // manifest that does not parse fails the Android build, which nothing else
  // in `flutter test` would catch.
  test('the manifest is well-formed XML', () {
    for (final String path in <String>[
      'android/app/src/main/AndroidManifest.xml',
      'android/app/src/main/res/xml/file_paths.xml',
    ]) {
      expect(
        () => XmlWellFormedness.check(read(path)),
        returnsNormally,
        reason: '$path is not well-formed',
      );
    }
  });
}

/// Enough of an XML check to catch the mistakes a hand-edited manifest makes.
///
/// There is no XML parser in the dependency set and this does not justify
/// adding one: unbalanced tags and `--` inside a comment are what actually goes
/// wrong here, and both are findable without a parser.
abstract final class XmlWellFormedness {
  static void check(String source) {
    int index = 0;
    int depth = 0;

    while (index < source.length) {
      final int open = source.indexOf('<', index);
      if (open == -1) break;

      if (source.startsWith('<!--', open)) {
        final int close = source.indexOf('-->', open + 4);
        if (close == -1) throw const FormatException('unterminated comment');
        final String body = source.substring(open + 4, close);
        if (body.contains('--')) {
          throw FormatException(
            'a double hyphen inside a comment: ${body.trim()}',
          );
        }
        index = close + 3;
        continue;
      }

      final int close = source.indexOf('>', open);
      if (close == -1) throw const FormatException('unterminated tag');
      final String tag = source.substring(open + 1, close);

      if (tag.startsWith('?') || tag.startsWith('!')) {
        index = close + 1;
        continue;
      }
      if (tag.startsWith('/')) {
        depth -= 1;
        if (depth < 0) throw const FormatException('a closing tag too many');
      } else if (!tag.endsWith('/')) {
        depth += 1;
      }
      index = close + 1;
    }

    if (depth != 0) throw FormatException('$depth tags left unclosed');
  }
}
