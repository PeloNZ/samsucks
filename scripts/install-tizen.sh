#!/usr/bin/env bash
# Installs Samsung's Tizen command-line tools and the TV extension packages.
# Shared by setup.sh and CI. Does nothing when both are already installed.
#   ./scripts/install-tizen.sh <install-dir> <tizen-version>
# Tool output goes to $LOG (default build/install-tizen.log). The installer download
# stays in build/downloads/, so a failed install does not download again.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ $# -eq 2 ] || {
  echo "Usage: $0 <install-dir> <tizen-version>" >&2
  exit 2
}
TIZEN_STUDIO="$1"
TIZEN_VERSION="$2"

if [ -z "${LOG:-}" ]; then
  LOG="$ROOT/build/install-tizen.log"
  mkdir -p "$ROOT/build"
  : >"$LOG"
fi
log() { printf '%s %s\n' "$(date +%T)" "$*" >>"$LOG"; }
# Runs a command with its output in the log. Do not pass secrets: the arguments are logged.
run() {
  log "+ $*"
  local rc=0
  "$@" >>"$LOG" 2>&1 || rc=$?
  log "exit $rc"
  return "$rc"
}
ok() {
  printf '  \033[32m✓\033[0m %s\n' "$*"
  log "ok: $*"
}
fail() {
  log "FAIL: $*"
  printf '\n  \033[31m✗ %s\033[0m\n  Log: %s\n\n' "$*" "$LOG" >&2
  exit 1
}

case "$(uname -s)" in
  Darwin) INSTALLER="web-cli_Tizen_Studio_${TIZEN_VERSION}_macos-64.bin" ;;
  Linux) INSTALLER="web-cli_Tizen_Studio_${TIZEN_VERSION}_ubuntu-64.bin" ;;
  *) fail "Only macOS and Linux are supported (on Windows, use WSL)." ;;
esac
TIZEN="$TIZEN_STUDIO/tools/ide/bin/tizen"
PM="$TIZEN_STUDIO/package-manager/package-manager-cli.bin"

if [ -x "$TIZEN" ]; then
  ok "already installed in $TIZEN_STUDIO"
else
  # The installer refuses an existing folder (and still exits 0).
  [ ! -e "$TIZEN_STUDIO" ] || fail "$TIZEN_STUDIO exists but has no tizen CLI (a failed install?). Move it aside, then run this again."
  # Kept across runs, so a failed install does not download again.
  DL="$ROOT/build/downloads/$INSTALLER"
  if [ -f "$DL" ]; then
    ok "using downloaded $INSTALLER"
  else
    echo "  Downloading $INSTALLER (~270 MB)…"
    mkdir -p "$(dirname "$DL")"
    curl -fL -C - --progress-bar -o "$DL.part" "https://download.tizen.org/sdk/Installer/tizen-studio_${TIZEN_VERSION}/$INSTALLER"
    mv "$DL.part" "$DL"
  fi
  chmod +x "$DL"
  # On Apple Silicon, macOS kills the arm64e slice of the installer's bundled
  # unzip; under Rosetta it runs the x86_64 slice instead.
  if [ "$(uname -sm)" = "Darwin arm64" ]; then
    run arch -x86_64 "$DL" --accept-license "$TIZEN_STUDIO"
  else run "$DL" --accept-license "$TIZEN_STUDIO"; fi
  log "tools/: $(ls "$TIZEN_STUDIO/tools" 2>&1 | tr '\n' ' ')"
  # The installer exits 0 even when it fails.
  [ -x "$TIZEN" ] || fail "The Tizen installer failed: $TIZEN is missing."
  ok "installed in $TIZEN_STUDIO"
fi

PACKAGES="cert-add-on TV-SAMSUNG-Public-WebAppDevelopment TV-SAMSUNG-Extension-Tools Certificate-Manager"
PKGS=$("$PM" show-pkgs 2>&1 || true)
log "show-pkgs: $PKGS"
INSTALLED=$(awk '$1 == "i" { print $2 }' <<<"$PKGS")
MISSING=""
for p in $PACKAGES; do echo "$INSTALLED" | grep -qx "$p" || MISSING="$MISSING $p"; done
if [ -n "$MISSING" ]; then
  echo "  Installing Samsung TV extensions (a few minutes)…"
  run "$PM" install --accept-license $MISSING
fi
ok "Samsung TV extensions"
