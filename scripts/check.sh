#!/usr/bin/env bash
# Static checks and unit tests. Run in the dev container: ./scripts/dev.sh ./scripts/check.sh
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

step "Build output: release bundle has no dev code, dev bundle has it"
build_output_check() {
  local tmp rc=0 version
  tmp=$(mktemp -d)
  version=$(sed -n 's/.*widget.* version="\([^"]*\)".*/\1/p' app/config.xml)
  ./scripts/build.sh --out "$tmp/release" >/dev/null || rc=1
  DEV_HOST='' DEV_SKIP_LOGIN='' PLEX_SERVER_URL='' ./scripts/build.sh --dev --out "$tmp/dev" >/dev/null || rc=1
  [ "$rc" = 0 ] || {
    rm -rf "$tmp"
    return 1
  }
  grep -q startDevRemote "$tmp/release/js/main.js" && {
    echo "release bundle contains startDevRemote"
    rc=1
  }
  grep -qF -e /cmd -e /log "$tmp/release/js/main.js" && {
    echo "release bundle contains a devserver path (/cmd or /log)"
    rc=1
  }
  grep -qF "$version" "$tmp/release/js/main.js" || {
    echo "release bundle lacks version $version"
    rc=1
  }
  grep -q startDevRemote "$tmp/dev/js/main.js" || {
    echo "dev bundle lacks startDevRemote"
    rc=1
  }
  rm -rf "$tmp"
  return "$rc"
}
check build_output_check

step "shellcheck (warnings and errors)"
check shellcheck -S warning "${SHELL_FILES[@]}"

step "shfmt: shell format"
if [ "$FIX" = 1 ]; then check shfmt -i 2 -ci -w "${SHELL_FILES[@]}"; else check shfmt -i 2 -ci -d "${SHELL_FILES[@]}"; fi

step "Unit tests: node --test"
check node --test --test-reporter=dot 'test/**/*.test.mjs'

[ "$STATUS" = 0 ] && printf '\nAll checks passed.\n' || printf '\nSome checks failed.\n'
exit "$STATUS"
