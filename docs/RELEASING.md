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

### Generating the keystore

Give it its own file rather than adding a key to a keystore you already use for
another app: the file is what gets handed to CI, so one app per keystore keeps
that blast radius small. `keytool` never overwrites an existing keystore — it
adds an alias to it and asks for that keystore's password — so the risk here is
not destroying anything, it is quietly ending up with the Wirdi key inside
somebody else's keystore.

```bash
mkdir -p ~/keystores
keytool -genkeypair -v -keystore ~/keystores/wirdi-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias wirdi-upload
```

In PowerShell, the same command with Windows paths:

```powershell
New-Item -ItemType Directory -Force -Path $HOME\keystores | Out-Null
keytool -genkeypair -v -keystore $HOME\keystores\wirdi-upload.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias wirdi-upload
```

`keytool` ships with the JDK; Android Studio bundles one under `jbr/bin` if it
is not on the PATH.

Modern JDKs create a **PKCS12** keystore, which has no separate key password —
keytool reuses the store password, and says so. `ANDROID_KEY_PASSWORD` and
`ANDROID_KEYSTORE_PASSWORD` are therefore the same value. Do not reach for
`-storetype JKS` to get two distinct passwords back: it brings a deprecated
format and a warning on every build, to no benefit.

Back the keystore up somewhere durable and off the repository. `android/*.jks`
is gitignored, so committing it by accident is already blocked; the file itself
is the part that cannot be regenerated.

### Encoding it for the secret

The secret holds the keystore base64-encoded on a single line, because the
workflow decodes it with `printf '%s' "$KEYSTORE_BASE64" | base64 -d`.

```bash
openssl base64 -A -in ~/keystores/wirdi-upload.jks -out ~/wirdi-keystore.b64
```

`openssl` rather than `base64`, because `-A` (no line wrapping) means the same
thing everywhere, while `base64`'s wrapping flag is `-w0` on GNU and `-b0` on
BSD. In PowerShell, nothing extra is needed:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\keystores\wirdi-upload.jks")) |
  Set-Content -NoNewline $HOME\wirdi-keystore.b64
```

Check the encoding round-trips before trusting it. This is what catches a
truncated or mangled file now, rather than as a puzzling Gradle error later:

```bash
base64 -d ~/wirdi-keystore.b64 | cmp - ~/keystores/wirdi-upload.jks && echo "round-trip OK"
```

### Setting the secrets

Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the contents of `wirdi-keystore.b64` |
| `ANDROID_KEYSTORE_PASSWORD` | the store password |
| `ANDROID_KEY_ALIAS` | the alias, `wirdi-upload` above |
| `ANDROID_KEY_PASSWORD` | the same as the store password, per PKCS12 |

With the GitHub CLI:

```bash
gh secret set ANDROID_KEYSTORE_BASE64 --repo rqawasme/Wirdi < ~/wirdi-keystore.b64
gh secret set ANDROID_KEY_ALIAS       --repo rqawasme/Wirdi --body wirdi-upload
gh secret set ANDROID_KEYSTORE_PASSWORD --repo rqawasme/Wirdi
gh secret set ANDROID_KEY_PASSWORD      --repo rqawasme/Wirdi
```

Pasting into the browser instead, from WSL, `cat ~/wirdi-keystore.b64 | clip.exe`
puts it on the Windows clipboard — easier than selecting a few thousand
characters out of a terminal. GitHub will not show a secret again after it is
saved, so compare the first and last characters against `head -c 40` and
`tail -c 40` of the file while you still can. A keystore encoded this way starts
`MII`.

Delete the `.b64` afterwards; it has no further use. Keep the `.jks`.

### How the build picks it up

The workflow decodes the keystore and writes `android/key.properties`;
`android/app/build.gradle.kts` reads it from there and falls back to the debug
keys when it is absent. Setting `ANDROID_KEYSTORE_BASE64` without the other
three fails the build rather than signing with something unintended.

A signed run logs `Release keystore configured.` in the Android job, and the
release notes read "Signed with the upload keystore." To check the artifact
itself, `apksigner verify --print-certs wirdi-<version>.apk` — a debug-signed
APK shows `CN=Android Debug`.

Secrets are not available to workflows triggered by pull requests from forks, so
signed builds happen for runs on `main` in this repository.

To sign locally, write `android/key.properties` yourself — it and `*.jks` are
gitignored:

```properties
storeFile=/absolute/path/to/wirdi-upload.jks
storePassword=...
keyAlias=wirdi-upload
keyPassword=...
```

`storeFile` must be an absolute path: Gradle resolves a relative one against
`android/app`, not against `key.properties`. A missing line here fails with a
message naming what is missing, rather than deep inside the signing task.

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
