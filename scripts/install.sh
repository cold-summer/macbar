#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST_DIR="${MACBAR_INSTALL_DIR:-$HOME/Applications}"
DEST="$DEST_DIR/MacBar.app"
"$ROOT/scripts/test.sh"
"$ROOT/scripts/build.sh"
# Keep one installed identity and a recoverable, non-launchable backup.
mkdir -p "$ROOT/backups" "$DEST_DIR"
if [ -d "$DEST" ]; then
  ditto -c -k --keepParent "$DEST" "$ROOT/backups/MacBar-$(date +%Y%m%d-%H%M%S).zip"
fi
while IFS= read -r pid; do
  [ -z "$pid" ] && continue
  executable="$(ps -p "$pid" -o comm=)"
  if [ "$executable" = "$DEST/Contents/MacOS/MacBar" ]; then kill -TERM "$pid"; fi
done < <(pgrep -x MacBar || true)
for attempt in {1..20}; do
  if ! pgrep -x MacBar >/dev/null; then break; fi
  sleep 0.1
done
if pgrep -x MacBar >/dev/null; then echo 'MacBar is still running; installation stopped.' >&2; exit 1; fi
STAGING="$DEST_DIR/.MacBar-install-$$"
ditto "$ROOT/build/MacBar.app" "$STAGING"
codesign --verify --strict "$STAGING"
python3 - "$STAGING" "$DEST" <<'PY'
import sys, os, shutil
src, dst=sys.argv[1:]; previous=dst+'.previous'
if os.path.exists(previous): shutil.rmtree(previous)
if os.path.exists(dst): os.rename(dst, previous)
try: os.rename(src,dst)
except BaseException:
    if os.path.exists(previous): os.rename(previous,dst)
    raise
if os.path.exists(previous): shutil.rmtree(previous)
PY
codesign --verify --strict "$DEST"
# Refresh the bundle registration so Finder and Spotlight can pick up a newly
# supplied application icon without restarting Finder or clearing global caches.
touch "$DEST"
REGISTER='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
if [ -x "$REGISTER" ]; then "$REGISTER" -f "$DEST" >/dev/null 2>&1 || true; fi
echo "Installed: $DEST"
