# The self-updater

> **Before submitting this app to Google Play, remove this feature.** Play
> rejects an app declaring `REQUEST_INSTALL_PACKAGES` unless installing packages
> is a core advertised feature, and an app that downloads and installs its own
> updates is against the Device and Network Abuse policy besides. The checklist
> is at the bottom of this file.

When it is turned on, Wirdi asks GitHub once a launch whether a newer version
has been released. If one has, a notice appears at the top of the home screen;
tapping it downloads that release's APK and hands it to Android's package
installer. It exists so that a phone can be updated from the phone, without
being plugged into a computer.

**Android only.** iOS does not permit an app to install itself, and the `.ipa`
this project builds is unsigned and uninstallable anyway. On iOS there is no
notice and no switch in Settings, rather than a switch that does nothing.

**Off by default.** Wirdi otherwise makes no network calls at all, and that is a
property worth keeping true unless somebody asks for the exception.
`test/app/update_banner_test.dart` asserts that with the setting off the client
is never called even once — the claim printed under the switch is a claim a test
holds up.

## The one-time uninstall

Android refuses to upgrade an app whose signing certificate changed:
`INSTALL_FAILED_UPDATE_INCOMPATIBLE`, which the UI reports only as "App not
installed". Nothing works around it — not `adb install -r`, not anything.

A phone carrying a build from `flutter run`, or the `v0.1.0` release, holds a
**debug-signed** app. Releases are now signed with the upload keystore. So the
first properly signed release has to be installed by hand, once, after
uninstalling what is there.

**Uninstalling deletes `user.db`** — collections, progress, completions, streak
and settings — from the documents directory. There is no export in the app. So
do this while there is nothing in it worth keeping, or copy the database off the
device with `adb` first.

Every update after that one is a tap. And note the corollary: once the phone
holds an upload-key build, `flutter run` can no longer install over it either.
Development moves to a second device or an emulator.

## How it works

| Piece | Where |
| --- | --- |
| Version comparison | `lib/domain/app_release.dart` |
| Network, filesystem and installer | `lib/data/update_client.dart` |
| Providers and download state | `lib/providers/updates.dart` |
| The notice | `lib/widgets/update_banner.dart` |
| The Android half | `android/app/src/main/kotlin/app/wirdi/MainActivity.kt` |

`UpdateClient` is the platform seam, in the sense `WirdiDatabaseFiles` is one:
every piece of contact with the outside — the HTTPS request, the download, the
method channel — is a constructor parameter with a real default. That is what
lets the tests run the real parsing and the real banner with no network and no
device, and it is what keeps the removal below to a short list.

It reads `/repos/rqawasme/Wirdi/releases/latest`, which skips drafts and
prereleases — so a prerelease can be published by hand without every phone
offering it. **A 404 from that endpoint is the ordinary answer** for a
repository whose only release is a prerelease, and reads as "no update" rather
than as an error. So does a 403 (the unauthenticated rate limit, sixty an hour),
a socket that will not open, and a response in an unexpected shape. A failed
check is not news in an app whose normal condition is offline.

The download uses each asset's `browser_download_url`, which answers 302 to
`objects.githubusercontent.com`. `HttpClient` follows that automatically and
carries the `User-Agent` across the hop while dropping an `Authorization`
header — which is the behaviour wanted here, and the reason not to add a token:
the repository is public, and a token shipped inside an APK is a published
token.

Any `.apk` asset is accepted rather than an exact filename. The `v0.1.0` release
carries `app-release.apk`, because the workflow that renames it to
`wirdi-<version>.apk` was written afterwards; an exact-name match would mean the
updater could not update off any build predating that workflow.

### Installing

`REQUEST_INSTALL_PACKAGES` is not a runtime permission and has no dialog. From
API 26 it is a per-app appop: `canRequestPackageInstalls()` reports it, and
`ACTION_MANAGE_UNKNOWN_APP_SOURCES` opens the settings page that grants it. The
app does not wait for an answer — that screen returns `RESULT_CANCELED`
whatever the user did, and the process may be killed while it is in the
foreground — so the notice asks the user to come back and tap again.

The APK is written to `updates/` under the app's cache directory, which is
exactly what `res/xml/file_paths.xml` lets the `FileProvider` share.
`FileProvider.getUriForFile` throws for a file outside those paths, so the two
have to agree; `test/app/update_manifest_test.dart` is what keeps them, and the
channel name and the provider authority, honest across the Dart/Kotlin line that
neither `flutter analyze` nor `dart format` crosses.

## What is not covered by tests

The install intent, the settings round trip and `canRequestPackageInstalls()`
need a device. On a phone, check:

1. With the setting off, no notice appears even when a newer release exists.
2. Turning it on and relaunching shows the notice, naming the right version and
   its size.
3. Tapping it with "Install unknown apps" not yet granted opens the settings
   page, and the notice then says to tap again.
4. Granting it and tapping again downloads, and Android's installer appears.
5. Cancelling the install returns to a notice that still offers the update.
6. Completing it replaces the app, and the About sheet shows the new version.

## Removing it before a Play build

Turning the Dart off is only half of it — a `--dart-define` cannot reach a
manifest, and the manifest is what Play reads:

```bash
flutter build appbundle --release --dart-define=WIRDI_SELF_UPDATE=false
```

That removes the check, the download and the notice. The permission is still
declared. To take the feature out properly:

- Delete `lib/domain/app_release.dart`, `lib/data/update_client.dart`,
  `lib/providers/updates.dart` and `lib/widgets/update_banner.dart`.
- Delete `test/domain/app_release_test.dart`,
  `test/data/update_client_test.dart`, `test/app/update_banner_test.dart` and
  `test/app/update_manifest_test.dart`.
- Delete `android/app/src/main/res/xml/file_paths.xml`, and return
  `MainActivity.kt` to `class MainActivity : FlutterActivity()`.
- Remove the two `<uses-permission>` lines and the `<provider>` block from
  `android/app/src/main/AndroidManifest.xml`, and the `dependencies` block from
  `android/app/build.gradle.kts`.
- Remove `SettingKeys.checkForUpdates`, the `checkForUpdates` field, default,
  parse line, `copyWith` entry and setter from `lib/providers/settings.dart`,
  and the `SwitchListTile` from `lib/screens/settings_screen.dart`.
- Remove the `UpdateBanner` line and its import from
  `lib/screens/home_screen.dart`.
- Remove the Updates section from `lib/widgets/about_sheet.dart` and put the
  Fonts wording back to "Nothing is fetched at runtime."
- Remove the update section from `README.md`, and this file.

The rule that keeps that list short and true: **nothing outside those files may
import `dart:io`, `dart:convert` or `package:flutter/services.dart` for update
purposes.** All contact with the network and the platform lives in one class.
