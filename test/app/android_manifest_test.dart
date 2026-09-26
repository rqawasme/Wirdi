import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What the release manifest claims, held to it.
///
/// Wirdi declares no permissions, and its Google Play Data safety answers —
/// no data collected, none shared, no network access — rest on that. A
/// permission added here would make those answers false without anything else
/// in the build noticing, so this is the check that does.
///
/// `analysis_options.yaml` excludes `android/**` and `dart format` covers only
/// `lib test tool`, so nothing on the Dart side reads this file otherwise. CI's
/// debug APK build catches a manifest the merger rejects, but not one that
/// merges fine and asks for something it should not.
void main() {
  const String manifestPath = 'android/app/src/main/AndroidManifest.xml';

  late String manifest;

  setUp(() {
    final File file = File(manifestPath);
    expect(file.existsSync(), isTrue, reason: '$manifestPath is missing');
    manifest = file.readAsStringSync();
  });

  test('the release manifest declares no permissions', () {
    // Matches `<uses-permission-sdk-23` too. Read with the comments stripped,
    // because the manifest explains in a comment why there are none.
    expect(
      XmlWellFormedness.withoutComments(manifest),
      isNot(contains('<uses-permission')),
      reason:
          'Wirdi is a zero-permission app, and its Play Data safety '
          'declaration says so. Adding a permission means revisiting that '
          'declaration and docs/PRIVACY.md first.',
    );
  });

  // XML comments cannot contain a double hyphen, and a manifest that does not
  // parse fails the Android build, which nothing else in `flutter test` would
  // catch.
  test('the manifest is well-formed XML', () {
    expect(
      () => XmlWellFormedness.check(manifest),
      returnsNormally,
      reason: '$manifestPath is not well-formed',
    );
  });

  // The checks above are only worth having if they can fail.
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

  test('a permission inside a comment is not a permission', () {
    const String commented =
        '<manifest><!-- <uses-permission android:name="x"/> --></manifest>';
    expect(
      XmlWellFormedness.withoutComments(commented),
      isNot(contains('<uses-permission')),
    );
    const String declared =
        '<manifest><uses-permission android:name="x"/></manifest>';
    expect(
      XmlWellFormedness.withoutComments(declared),
      contains('<uses-permission'),
    );
  });
}

/// Enough of an XML check to catch the mistakes a hand-edited manifest makes.
///
/// There is no XML parser in the dependency set and this does not justify
/// adding one: unbalanced tags and `--` inside a comment are what actually goes
/// wrong here, and both are findable without a parser.
abstract final class XmlWellFormedness {
  static final RegExp _comment = RegExp(r'<!--.*?-->', dotAll: true);

  /// [source] with every comment removed.
  static String withoutComments(String source) =>
      source.replaceAll(_comment, '');

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
