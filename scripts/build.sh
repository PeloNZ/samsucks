#!/usr/bin/env bash
# Build the app bundle. Needs only the repo and esbuild: no TV, Tizen CLI or env file.
#   ./scripts/build.sh                release build → build/app
#   ./scripts/build.sh --dev          dev build: perf overlay, logs + remote control via tools/devserver.mjs
#   ./scripts/build.sh --out DIR      write the build to DIR instead of build/app
# With --dev, the repo's env file supplies DEV_HOST, DEV_SKIP_LOGIN and PLEX_SERVER_URL when present.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/app"
DEV=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dev) DEV=1 ;;
    --out)
      [ $# -ge 2 ] || {
        echo "--out needs a directory" >&2
        exit 1
      }
      OUT="$2"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

ENV_FILE="$ROOT/.env"
if [ "$DEV" = 1 ] && [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

command -v esbuild >/dev/null || {
  echo "esbuild not found. Run this in the dev container: ./scripts/dev.sh ./scripts/build.sh" >&2
  exit 1
}
rm -rf "$OUT" && mkdir -p "$(dirname "$OUT")"
cp -R "$ROOT/app" "$OUT"
VERSION=$(sed -n 's/.*widget.* version="\([^"]*\)".*/\1/p' "$ROOT/app/config.xml")
if [ "$DEV" = 1 ]; then
  PLEX_URL=""
  [ "${DEV_SKIP_LOGIN:-0}" = 1 ] && PLEX_URL="${PLEX_SERVER_URL:-}"
  cat >"$OUT/js/config.js" <<EOT
export const DEV = true;
export const DEV_HOST = '${DEV_HOST:-}';
export const DEV_PLEX_URL = '$PLEX_URL';
export const VERSION = '$VERSION';
EOT
else
  sed -i.bak "s/^export const VERSION = .*/export const VERSION = '$VERSION';/" "$OUT/js/config.js" && rm "$OUT/js/config.js.bak"
fi
# Tizen 4.0 TVs run Chromium 56, which has no ES modules: bundle to one classic
# script and lower newer syntax. In a release build, js/dev stays in the bundle
# but never runs, because app.js imports it only when DEV is true.
esbuild "$OUT/js/main.js" --bundle --format=iife --target=chrome56 --log-level=warning --outfile="$OUT/bundle.js"
rm -rf "$OUT/js" && mkdir "$OUT/js" && mv "$OUT/bundle.js" "$OUT/js/main.js"
sed -i.bak 's| type="module"||' "$OUT/index.html" && rm "$OUT/index.html.bak"
echo "built $([ "$DEV" = 1 ] && echo dev || echo release) $VERSION → $OUT"
