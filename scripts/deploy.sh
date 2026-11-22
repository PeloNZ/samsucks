#!/usr/bin/env bash
# Build, sign, install and launch the app on the TV configured in .env.
#   ./scripts/deploy.sh               release build
#   ./scripts/deploy.sh --dev         dev build: perf overlay, logs + remote control via tools/devserver.mjs
#   ./scripts/deploy.sh --no-run      install but don't launch
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$ROOT/.env" ] || {
  echo "No .env yet. Run ./scripts/setup.sh first." >&2
  exit 1
}
# shellcheck source=scripts/load-env.sh
source "$ROOT/scripts/load-env.sh"
load_env "$ROOT/.env"

DEV=0
RUN=1
for arg in "$@"; do
  case "$arg" in
    --dev) DEV=1 ;;
    --no-run) RUN=0 ;;
    *)
      echo "Unknown option: $arg. To only build or package, run scripts/build.sh or scripts/package.sh." >&2
      exit 1
      ;;
  esac
done

# --- build, package ------------------------------------------------------------
if [ "$DEV" = 1 ]; then "$ROOT/scripts/build.sh" --dev; else "$ROOT/scripts/build.sh"; fi
"$ROOT/scripts/package.sh"

# --- install, launch -------------------------------------------------------------
TIZEN_STUDIO="${TIZEN_STUDIO:-$HOME/tizen-sdk}"
SDB="$TIZEN_STUDIO/tools/sdb"
TIZEN="$TIZEN_STUDIO/tools/ide/bin/tizen"
TARGET="$TV_IP:${TV_SDB_PORT:-26101}"
APP_ID=$(sed -n 's/.*tizen:application id="\([^"]*\)".*/\1/p' "$ROOT/app/config.xml")
WGT="$ROOT/build/samsucks.wgt"

"$SDB" connect "$TARGET" >/dev/null
# A freshly started sdb server (each dev container starts one) can list no
# devices for a moment after connect.
DEVICE=""
for _ in 1 2 3 4 5; do
  DEVICE=$("$SDB" devices | awk -v t="$TARGET" '$1 == t { print $3 }')
  [ -n "$DEVICE" ] && break
  sleep 1
done
[ -n "$DEVICE" ] || {
  echo "Can't reach the TV at $TARGET. Is it on, with Developer Mode pointing at this computer?" >&2
  exit 1
}

"$TIZEN" install -n "$WGT" -t "$DEVICE" | grep -E 'install completed|Installed|error|fail' || true
if [ "$RUN" = 1 ]; then "$TIZEN" run -p "$APP_ID" -t "$DEVICE" | tail -1; fi
