/// The app's version, as shown on the About screen.
///
/// Duplicated from `pubspec.yaml`, because reading the pubspec at runtime needs
/// a package and passing it through `--dart-define` needs every build command to
/// remember to. `test/app_version_test.dart` reads the pubspec and fails if the
/// two ever disagree, which is what makes the duplication safe rather than a
/// thing that quietly goes stale.
const String appVersion = '0.1.0';
