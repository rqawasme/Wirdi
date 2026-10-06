import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What the release manifest claims, held to it.
///
/// Wirdi declares two permissions, both for reminders, and its Google Play
/// Data safety answers — no data collected, none shared, no network access —
/// rest on that being all. A permission added here would make those answers
/// false without anything else in the build noticing, so this is the check
/// that does.
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

  test('the release manifest declares what reminders need and no more', () {
    // Read with the comments stripped, because the manifest explains in a
    // comment what each one is for.
    final String declared = XmlWellFormedness.withoutComments(manifest);
    expect(
      declaredPermissions(declared),
      <String>{
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
      },
      reason:
          'Wirdi asks for the two permissions reminders need and nothing '
          'else, and its Play Data safety declaration says so. Adding one '
          'means revisiting that declaration and docs/PRIVACY.md first.',
    );
    // Every tag accounted for: a `<uses-permission` the pattern could not
    // read a name out of would otherwise slip past the set above.
    expect(
      '<uses-permission'.allMatches(declared).length,
      declaredPermissions(declared).length,
    );
  });

  test('the release manifest still cannot reach the network', () {
    expect(
      declaredPermissions(XmlWellFormedness.withoutComments(manifest)),
      isNot(contains('android.permission.INTERNET')),
      reason:
          'Reminders are local notifications. Nothing in Wirdi needs the '
          'network, and docs/PRIVACY.md promises it has none.',
    );
  });

  test('the receivers that deliver reminders are declared', () {
    // flutter_local_notifications declares neither itself. Without the first
    // a reminder's time comes and nothing shows; without the second every
    // reminder is lost when the phone restarts.
    final String declared = XmlWellFormedness.withoutComments(manifest);
    expect(declared, contains('ScheduledNotificationReceiver"'));
    expect(declared, contains('ScheduledNotificationBootReceiver"'));
    expect(declared, contains('android.intent.action.BOOT_COMPLETED'));
  });

  test('the reminder icon exists and the shrinker is told to keep it', () {
    // Named only from Dart, so the release resource shrinker cannot see it is
    // used, and a stripped icon is a reminder that fails to show.
    const String res = 'android/app/src/main/res';
    for (final String density in <String>[
      'mdpi',
      'hdpi',
      'xhdpi',
      'xxhdpi',
      'xxxhdpi',
    ]) {
      expect(
        File('$res/drawable-$density/ic_notification.png').existsSync(),
        isTrue,
        reason: 'run tool/render_app_icons.py',
      );
    }
    expect(
      File('$res/raw/keep.xml').readAsStringSync(),
      contains('@drawable/ic_notification'),
    );
  });

  test('permissions are read out of the tags that declare them', () {
    expect(
      declaredPermissions(
        '<manifest>'
        '<uses-permission android:name="a.B"/>'
        '<uses-permission-sdk-23 android:name="c.D" />'
        '<uses-permission\n    android:name="e.F"></uses-permission>'
        '</manifest>',
      ),
      <String>{'a.B', 'c.D', 'e.F'},
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

/// The `android:name` of every `<uses-permission>` and
/// `<uses-permission-sdk-23>` in [manifest].
Set<String> declaredPermissions(String manifest) => <String>{
  for (final RegExpMatch match in RegExp(
    r'<uses-permission(?:-sdk-23)?\s[^>]*?android:name="([^"]+)"',
  ).allMatches(manifest))
    match.group(1)!,
};

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
