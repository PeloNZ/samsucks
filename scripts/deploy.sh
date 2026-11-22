#!/usr/bin/env bash
# Build, sign, install and launch the app on the TV configured in .env.
#   ./scripts/deploy.sh               release build
#   ./scripts/deploy.sh --dev         dev build: perf overlay, logs + remote control via tools/devserver.mjs
#   ./scripts/deploy.sh --build-only  just produce build/app (no TV needed)
#   ./scripts/deploy.sh --package-only  build and sign build/samsucks.wgt (no TV needed)
#   ./scripts/deploy.sh --no-run      install but don't launch
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$ROOT/.env" ] || {
  echo "No .env yet. Run ./scripts/setup.sh first." >&2
  exit 1
}
set -a
source "$ROOT/.env"
set +a

DEV=0
RUN=1
INSTALL=1
PACKAGE_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --dev) DEV=1 ;;
    --no-run) RUN=0 ;;
    --build-only) INSTALL=0 ;;
    --package-only) PACKAGE_ONLY=1 ;;
  esac
done

# --- build ---------------------------------------------------------------------
if [ "$DEV" = 1 ]; then "$ROOT/scripts/build.sh" --dev; else "$ROOT/scripts/build.sh"; fi
OUT="$ROOT/build/app"
[ "$INSTALL" = 1 ] || exit 0

# --- package, sign, install, launch -------------------------------------------
TIZEN_STUDIO="${TIZEN_STUDIO:-$HOME/tizen-sdk}"
SDB="$TIZEN_STUDIO/tools/sdb"
TIZEN="$TIZEN_STUDIO/tools/ide/bin/tizen"
TARGET="$TV_IP:${TV_SDB_PORT:-26101}"
APP_ID=$(sed -n 's/.*tizen:application id="\([^"]*\)".*/\1/p' "$ROOT/app/config.xml")

rm -f "$ROOT"/build/*.wgt
"$TIZEN" package -t wgt -s "${TIZEN_SIGN_PROFILE:-samsucks}" -o "$ROOT/build" -- "$OUT" >/dev/null
# The package is named after the app ("SamSUCKS - Better Plex.wgt"); the installer chokes on spaces.
WGT="$ROOT/build/samsucks.wgt"
mv "$(ls "$ROOT"/build/*.wgt | head -1)" "$WGT"
if [ "$PACKAGE_ONLY" = 1 ]; then
  echo "packaged $WGT"
  exit 0
fi

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
