#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/MacBar.app"
if [ "$(uname -s)" != Darwin ]; then
  echo 'MacBar requires macOS and Xcode Command Line Tools.' >&2; exit 1
fi
if [ -n "${MACBAR_SIGN_IDENTITY:-}" ]; then
  IDENTITY="$MACBAR_SIGN_IDENTITY"
elif security find-identity -v -p codesigning | /usr/bin/grep -Fq '"MacBar Local Codesign"'; then
  IDENTITY='MacBar Local Codesign'
else
  IDENTITY='-'
  echo 'Using ad-hoc signing. Set MACBAR_SIGN_IDENTITY to keep a stable signing identity across rebuilds.' >&2
fi
read -r -a ARCHS <<< "${MACBAR_ARCHS:-$(uname -m)}"
ARCH_FLAGS=()
for target_arch in "${ARCHS[@]}"; do
  case "$target_arch" in arm64|x86_64) ARCH_FLAGS+=(-arch "$target_arch");;
    *) echo "Unsupported architecture: $target_arch" >&2; exit 1;;
  esac
done
# A fresh staging bundle excludes stale debug symbols and previously built files.
mkdir -p "$ROOT/build"
STAGING="$(mktemp -d "$ROOT/build/.bundle-XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
mkdir -p "$STAGING/MacBar.app/Contents/MacOS" "$STAGING/MacBar.app/Contents/Resources"
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$STAGING/MacBar.app/Contents/Resources/"
"$ROOT/scripts/make-icon.sh" "$STAGING/MacBar.app/Contents/Resources/MacBar.icns"
cp "$ROOT/Info.plist" "$STAGING/MacBar.app/Contents/Info.plist"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=14.0 \
  -isysroot "$SDK" "${ARCH_FLAGS[@]}" -fdebug-prefix-map="$ROOT=." \
  -framework Cocoa -framework ApplicationServices "$ROOT/main.m" "$ROOT/MBPolicy.m" \
  -o "$STAGING/MacBar.app/Contents/MacOS/MacBar"
codesign --force --sign "$IDENTITY" "$STAGING/MacBar.app"
codesign --verify --strict "$STAGING/MacBar.app"
rm -rf "$OUT"
mv "$STAGING/MacBar.app" "$OUT"
echo "$OUT"
