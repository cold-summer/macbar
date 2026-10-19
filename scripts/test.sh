#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build"
clang -fobjc-arc -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=14.0 \
 -framework Cocoa -framework ApplicationServices "$ROOT/tests/regression.m" "$ROOT/MBPolicy.m" -o "$ROOT/build/regression"
"$ROOT/build/regression"
