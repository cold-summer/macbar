#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build"
xcrun clang -fobjc-arc -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=14.0 \
  -framework Cocoa -framework ApplicationServices \
  "$ROOT/tests/settings-ui.m" "$ROOT/MBPolicy.m" -o "$ROOT/build/settings-ui-tests"
"$ROOT/build/settings-ui-tests" "$ROOT"
