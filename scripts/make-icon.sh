#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/build/MacBar.icns}"
mkdir -p "$ROOT/build" "$(dirname "$OUTPUT")"
STAGING="$(mktemp -d "$ROOT/build/.icon-XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
SOURCE="$STAGING/AppIcon.png"
sips -s format png "$ROOT/assets/AppIcon.svg" --out "$SOURCE" >/dev/null
ICONSET="$STAGING/MacBar.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  retina_size=$((size * 2))
  sips -z "$retina_size" "$retina_size" "$SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$OUTPUT"
