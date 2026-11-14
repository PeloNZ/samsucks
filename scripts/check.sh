#!/usr/bin/env bash
# Static checks. Run in the dev container: ./scripts/dev.sh ./scripts/check.sh
#   --fix   apply safe lint fixes and formatting instead of reporting them
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
FIX=0
[ "${1:-}" = --fix ] && FIX=1
STATUS=0
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }
check() { "$@" || STATUS=1; }

SHELL_FILES=(scripts/*.sh tools/*.sh)

step "Biome: JS, CSS, JSON lint and format"
if [ "$FIX" = 1 ]; then check biome check --write .; else check biome ci .; fi

step "esbuild: app/js lowers to Chromium 56 (Tizen 4.0)"
check esbuild app/js/main.js --bundle --format=iife --target=chrome56 --log-level=warning --outfile=/dev/null

step "shellcheck (warnings and errors)"
check shellcheck -S warning "${SHELL_FILES[@]}"

step "shfmt: shell format"
if [ "$FIX" = 1 ]; then check shfmt -i 2 -ci -w "${SHELL_FILES[@]}"; else check shfmt -i 2 -ci -d "${SHELL_FILES[@]}"; fi

[ "$STATUS" = 0 ] && printf '\nAll checks passed.\n' || printf '\nSome checks failed.\n'
exit "$STATUS"
