#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT/Info.plist")"
# Distributable packages are always ad-hoc signed; no private signing identity
# or machine-specific debug bundle is embedded in a public release.
MACBAR_ARCHS='arm64 x86_64' MACBAR_SIGN_IDENTITY=- "$ROOT/scripts/build.sh"
mkdir -p "$ROOT/dist"
WORK="$(mktemp -d "$ROOT/build/.package-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
ZIP_STAGING="$WORK/zip"
PKG_STAGING="$WORK/pkg"
mkdir -p "$ZIP_STAGING" "$PKG_STAGING"
ditto "$ROOT/build/MacBar.app" "$ZIP_STAGING/MacBar.app"
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$ROOT/README.md" "$ROOT/README.en.md" "$ROOT/CHANGELOG.md" \
  "$ROOT/CONTRIBUTING.md" "$ROOT/CODE_OF_CONDUCT.md" "$ROOT/SECURITY.md" "$ZIP_STAGING/"
ditto "$ROOT/docs" "$ZIP_STAGING/docs"
ditto "$ROOT/assets" "$ZIP_STAGING/assets"
ARCHIVE="MacBar-$VERSION-universal.zip"
PKG="MacBar-$VERSION-universal.pkg"
ditto -c -k --norsrc --noextattr --noacl "$ZIP_STAGING" "$ROOT/dist/$ARCHIVE"
ditto "$ROOT/build/MacBar.app" "$PKG_STAGING/MacBar.app"
pkgbuild --quiet --root "$PKG_STAGING" \
  --identifier "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$ROOT/Info.plist")" \
  --version "$VERSION" --install-location /Applications --ownership recommended \
  "$ROOT/dist/$PKG"
(
  cd "$ROOT/dist"
  LC_ALL=C shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
  LC_ALL=C shasum -a 256 "$PKG" > "$PKG.sha256"
)
echo "$ROOT/dist/$ARCHIVE"
echo "$ROOT/dist/$ARCHIVE.sha256"
echo "$ROOT/dist/$PKG"
echo "$ROOT/dist/$PKG.sha256"
