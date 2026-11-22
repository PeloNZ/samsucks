#!/usr/bin/env bash
# Build the app bundle. Needs only the repo and esbuild: no TV, Tizen CLI or env file.
#   ./scripts/build.sh                release build → build/app
#   ./scripts/build.sh --dev          dev build: perf overlay, logs + remote control via tools/devserver.mjs
#   ./scripts/build.sh --out DIR      write the build to DIR instead of build/app
# With --dev, the repo's env file supplies DEV_HOST, DEV_SKIP_LOGIN and PLEX_SERVER_URL when present.
# A value the caller already set wins over the env file.
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
  # shellcheck source=scripts/load-env.sh
  source "$ROOT/scripts/load-env.sh"
  load_env "$ENV_FILE"
fi

command -v esbuild >/dev/null || {
  echo "esbuild not found. Run this in the dev container: ./scripts/dev.sh ./scripts/build.sh" >&2
  exit 1
}
rm -rf "$OUT" && mkdir -p "$(dirname "$OUT")"
cp -R "$ROOT/app" "$OUT"
VERSION=$(sed -n 's/.*widget.* version="\([^"]*\)".*/\1/p' "$ROOT/app/config.xml")
# Code reads four free globals. esbuild replaces them, so a release bundle holds no dev branches
# and no js/dev/ code.
if [ "$DEV" = 1 ]; then
  DEV_VALUE=true
  HOST_VALUE="${DEV_HOST:-}"
  PLEX_URL=""
  [ "${DEV_SKIP_LOGIN:-0}" = 1 ] && PLEX_URL="${PLEX_SERVER_URL:-}"
else
  DEV_VALUE=false
  HOST_VALUE=""
  PLEX_URL=""
fi
# Tizen 4.0 TVs run Chromium 56, which has no ES modules: bundle to one classic
# script and lower newer syntax.
esbuild "$OUT/js/main.js" --bundle --format=iife --target=chrome56 --minify-syntax --log-level=warning --outfile="$OUT/bundle.js" \
  --define:__DEV__="$DEV_VALUE" \
  --define:__DEV_HOST__="\"$HOST_VALUE\"" \
  --define:__DEV_PLEX_URL__="\"$PLEX_URL\"" \
  --define:__VERSION__="\"$VERSION\""
rm -rf "$OUT/js" && mkdir "$OUT/js" && mv "$OUT/bundle.js" "$OUT/js/main.js"
sed -i.bak 's| type="module"||' "$OUT/index.html" && rm "$OUT/index.html.bak"
echo "built $([ "$DEV" = 1 ] && echo dev || echo release) $VERSION → $OUT"
