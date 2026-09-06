#!/usr/bin/env bash
# Set the app version, in both of the places that have to agree.
#
#   tool/bump_version.sh 0.2.0
#
# pubspec.yaml is what Flutter reads for the Android versionName and the iOS
# CFBundleShortVersionString, and lib/app_version.dart is what the About sheet
# displays. test/app_version_test.dart fails when the two disagree, so a bump
# that edits only one of them turns CI red — and, because the release workflow
# runs the tests before it builds anything, blocks the release rather than
# shipping an app that misreports its own version.
#
# Pushing the result to main is what starts a release: .github/workflows/
# release.yml releases when this version changes and has not been tagged yet.
# The build number is not set here — CI supplies its own from the run number.
set -euo pipefail

version="${1:-}"

if [[ -z "$version" ]]; then
  echo "usage: tool/bump_version.sh <version>    e.g. tool/bump_version.sh 0.2.0" >&2
  exit 1
fi

# The release tag is v<version> and the pubspec's build number is appended with
# a `+`, so neither a leading "v" nor a build number belongs in the argument.
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "not a version: '$version' — expected MAJOR.MINOR.PATCH, without a leading 'v' or a '+build'" >&2
  exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pubspec="$root/pubspec.yaml"
dart="$root/lib/app_version.dart"

current="$(sed -n 's/^version:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "$pubspec" | head -n1)"
current="${current%%+*}"

if [[ "$current" == "$version" ]]; then
  echo "already at $version — nothing to do" >&2
  exit 1
fi

# Anchored to the start of the line so that nothing else in the pubspec that
# happens to contain a version is touched.
sed -i.bak "s/^version:.*/version: $version/" "$pubspec" && rm -f "$pubspec.bak"
sed -i.bak "s/^const String appVersion = .*/const String appVersion = '$version';/" "$dart" && rm -f "$dart.bak"

# sed reports success whether or not it matched anything, so the edits are read
# back rather than assumed.
for file in "$pubspec" "$dart"; do
  if ! grep -q "$version" "$file"; then
    echo "failed to write $version into $file — check its format by hand" >&2
    exit 1
  fi
done

echo "$current -> $version"
echo "  pubspec.yaml"
echo "  lib/app_version.dart"
echo
echo "commit both, then push to main to cut the release."
