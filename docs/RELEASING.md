# Releasing

The version in `pubspec.yaml` is the trigger. Push a change to it on `main` and
`.github/workflows/release.yml` runs the test suite, builds both platforms and
publishes a GitHub release with the APK and the iOS app attached. Nothing else
starts a release — there is no tag to push and no button to press.

## Cutting a release

```bash
tool/bump_version.sh 0.2.0
git commit -am "Release 0.2.0"
git push origin main
```

`bump_version.sh` writes the version to the two files that have to agree:
`pubspec.yaml`, which Flutter reads for the Android `versionName` and the iOS
`CFBundleShortVersionString`, and `lib/app_version.dart`, which the About sheet
displays. `test/app_version_test.dart` fails if they ever disagree, and the
release workflow runs the tests before it builds anything, so a half-finished
bump blocks the release instead of shipping an app that misreports its version.

## What the pipeline does

1. **detect** — reads `version:` at `HEAD` and compares it with `HEAD^`.
   Releases when it changed and `v<version>` is not already a tag. Anything else
   — an unchanged version, a version already released — stops here, quietly.
2. **test** — calls `.github/workflows/ci.yml`, the same workflow that runs on
   every pull request. Not a copy of it; the gate in front of a release is the
   suite you already trust.
3. **android** / **ios** — build in parallel, only once the tests are green.
4. **release** — creates the tag `v<version>` at the tested commit and publishes
   the release with both artifacts.

The tag is created at the end rather than being what starts the run, so a tag
can never name a commit whose tests did not pass.

### Build numbers

The Android `versionCode` and the iOS `CFBundleVersion` come from
`--build-number=${{ github.run_number }}`, not from `pubspec.yaml`. Stores reject
an upload whose build number they have seen before, and a number that only ever
goes up is one less thing to get right by hand. The version *name* people see is
still the one in `pubspec.yaml`.

## Android signing

Until the four secrets below are set, the APK is **signed with the Android debug
keys**: installable for testing, but Play rejects it and anyone can re-sign it.
The workflow logs a warning and the release notes say so on the release itself,
so an unsigned build is never published as if it were signed.

To sign properly, generate an upload keystore:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
```

Keep it somewhere safe and off the repository — losing it means you can never
update the app on Play under the same listing. Then set these repository secrets
(Settings → Secrets and variables → Actions):

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | the store password |
| `ANDROID_KEY_ALIAS` | the alias, `upload` above |
| `ANDROID_KEY_PASSWORD` | the key password |

The workflow decodes the keystore and writes `android/key.properties`;
`android/app/build.gradle.kts` picks it up from there and falls back to the debug
keys when it is absent. Setting `ANDROID_KEYSTORE_BASE64` without the other three
fails the build rather than signing with something unintended.

To sign locally, write `android/key.properties` yourself — it and `*.jks` are
gitignored:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

`storeFile` must be an absolute path: Gradle resolves a relative one against
`android/app`, not against `key.properties`.

## iOS signing

The attached `.ipa` is **unsigned**. Signing in CI needs an Apple Developer
certificate and a provisioning profile, which this repository does not hold, so
the build runs `flutter build ios --release --no-codesign` and the resulting
`Runner.app` is packaged into the `Payload/` layout that an `.ipa` is. It is
there to be archived and to be re-signed by tools that do that themselves; a
device will not install it as it stands.

To publish to TestFlight or the App Store, the release job needs an Apple
Developer account, the certificate and profile imported into the runner's
keychain, and an `ExportOptions.plist` — at which point `flutter build ipa`
replaces the packaging step above.
