#!/usr/bin/env bash
# Build, sign, install and launch the app on the TV configured in .env.
#   ./scripts/deploy.sh               release build
#   ./scripts/deploy.sh --dev         dev build: perf overlay, logs + remote control via tools/devserver.mjs
#   ./scripts/deploy.sh --build-only  just produce build/app (no TV needed)
#   ./scripts/deploy.sh --no-run      install but don't launch
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$ROOT/.env" ] || { echo "No .env yet. Run ./scripts/setup.sh first." >&2; exit 1; }
set -a; source "$ROOT/.env"; set +a

DEV=0; RUN=1; INSTALL=1
for arg in "$@"; do
  case "$arg" in
    --dev) DEV=1 ;;
    --no-run) RUN=0 ;;
    --build-only) INSTALL=0 ;;
  esac
done

# --- build: copy app/, then bundle the JS modules into one script ------------
command -v esbuild >/dev/null || { echo "esbuild not found. Run this in the dev container: ./scripts/dev.sh ./scripts/deploy.sh $*" >&2; exit 1; }
OUT="$ROOT/build/app"
rm -rf "$OUT" && mkdir -p "$ROOT/build"
cp -R "$ROOT/app" "$OUT"
VERSION=$(sed -n 's/.*widget.* version="\([^"]*\)".*/\1/p' "$ROOT/app/config.xml")
if [ "$DEV" = 1 ]; then
  PLEX_URL=""; [ "${DEV_SKIP_LOGIN:-0}" = 1 ] && PLEX_URL="${PLEX_SERVER_URL:-}"
  cat > "$OUT/js/config.js" <<EOF
export const DEV = true;
export const DEV_HOST = '${DEV_HOST:-}';
export const DEV_PLEX_URL = '$PLEX_URL';
export const VERSION = '$VERSION';
EOF
else
  sed -i.bak "s/^export const VERSION = .*/export const VERSION = '$VERSION';/" "$OUT/js/config.js" && rm "$OUT/js/config.js.bak"
fi
# Tizen 4.0 TVs run Chromium 56, which has no ES modules: bundle to one classic
# script and lower newer syntax. In a release build, js/dev stays in the bundle
# but never runs, because app.js imports it only when DEV is true.
esbuild "$OUT/js/main.js" --bundle --format=iife --target=chrome56 --log-level=warning --outfile="$OUT/bundle.js"
rm -rf "$OUT/js" && mkdir "$OUT/js" && mv "$OUT/bundle.js" "$OUT/js/main.js"
sed -i.bak 's| type="module"||' "$OUT/index.html" && rm "$OUT/index.html.bak"
echo "built $([ "$DEV" = 1 ] && echo dev || echo release) $VERSION → build/app"
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

"$SDB" connect "$TARGET" >/dev/null
DEVICE=$("$SDB" devices | awk -v t="$TARGET" '$1 == t { print $3 }')
[ -n "$DEVICE" ] || { echo "Can't reach the TV at $TARGET. Is it on, with Developer Mode pointing at this computer?" >&2; exit 1; }

"$TIZEN" install -n "$WGT" -t "$DEVICE" | grep -E 'install completed|Installed|error|fail' || true
if [ "$RUN" = 1 ]; then "$TIZEN" run -p "$APP_ID" -t "$DEVICE" | tail -1; fi
