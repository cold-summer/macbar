#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT/Info.plist")"
# Distributable packages are always ad-hoc signed; no private signing identity
# or machine-specific debug bundle is embedded in a public release.
MACBAR_ARCHS='arm64 x86_64' MACBAR_SIGN_IDENTITY=- "$ROOT/scripts/build.sh"
mkdir -p "$ROOT/dist"
STAGING="$(mktemp -d "$ROOT/build/.package-XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto "$ROOT/build/MacBar.app" "$STAGING/MacBar.app"
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$ROOT/README.md" "$ROOT/README.en.md" "$ROOT/CHANGELOG.md" \
  "$ROOT/CONTRIBUTING.md" "$ROOT/CODE_OF_CONDUCT.md" "$ROOT/SECURITY.md" "$STAGING/"
ditto "$ROOT/docs" "$STAGING/docs"
ditto "$ROOT/assets" "$STAGING/assets"
ARCHIVE="MacBar-$VERSION-universal.zip"
ditto -c -k --norsrc --noextattr --noacl "$STAGING" "$ROOT/dist/$ARCHIVE"
(
  cd "$ROOT/dist"
  LC_ALL=C shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
)
echo "$ROOT/dist/$ARCHIVE"
echo "$ROOT/dist/$ARCHIVE.sha256"
