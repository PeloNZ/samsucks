#!/usr/bin/env bash
# One-time setup: installs Samsung's command-line tools, finds your TV, creates a
# signing certificate and writes .env. Safe to run again; finished steps are skipped.
#   ./scripts/setup.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV="$ROOT/.env"
TIZEN_VERSION="$(cat "$ROOT/scripts/tizen-version")"

# Tool output goes to build/setup.log, not the terminal. Each run starts a new log.
LOG="$ROOT/build/setup.log"
mkdir -p "$ROOT/build"
: >"$LOG"
log() { printf '%s %s\n' "$(date +%T)" "$*" >>"$LOG"; }
# BASH_COMMAND is the source text, so variables such as the cert password stay unexpanded.
trap 'rc=$?; log "FAILED (exit $rc) at line $LINENO: $BASH_COMMAND"; printf "\n  \033[31m✗ Failed at scripts/setup.sh:%s (exit %s). Log: %s\033[0m\n\n" "$LINENO" "$rc" "$LOG" >&2' ERR
# Runs a command with its output in the log. Do not pass secrets: the arguments are logged.
run() {
  log "+ $*"
  local rc=0
  "$@" >>"$LOG" 2>&1 || rc=$?
  log "exit $rc"
  return "$rc"
}

bold() {
  printf '\n\033[1m%s\033[0m\n' "$*"
  log "== $*"
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

get_env() { [ -f "$ENV" ] && sed -n "s/^$1=//p" "$ENV" | tail -1 || true; }
set_env() {
  if grep -q "^$1=" "$ENV"; then
    KEY="$1" VAL="$2" perl -pi -e 's/^\Q$ENV{KEY}\E=.*/$ENV{KEY}=$ENV{VAL}/' "$ENV"
  else printf '%s=%s\n' "$1" "$2" >>"$ENV"; fi
}

# --- 1. Tizen command-line tools ----------------------------------------------
bold "1/4  Samsung Tizen tools"
[ -f "$ENV" ] || cp "$ROOT/.env.example" "$ENV"
TIZEN_STUDIO="$(get_env TIZEN_STUDIO)"
TIZEN_STUDIO="${TIZEN_STUDIO/\$HOME/$HOME}"
TIZEN_STUDIO="${TIZEN_STUDIO:-$HOME/tizen-sdk}"
TIZEN="$TIZEN_STUDIO/tools/ide/bin/tizen"
SDB="$TIZEN_STUDIO/tools/sdb"
PM="$TIZEN_STUDIO/package-manager/package-manager-cli.bin"
log "host: $(uname -sm), macOS $(sw_vers -productVersion 2>/dev/null || echo n/a)"
log "TIZEN_STUDIO=$TIZEN_STUDIO"
for f in "$TIZEN" "$SDB" "$PM" "$TIZEN_STUDIO/jdk" "$HOME/.package-manager/jdk/Contents/Home/bin/java"; do
  log "$([ -e "$f" ] && echo exists || echo missing): $f"
done
[ -f "$TIZEN_STUDIO/sdk.info" ] && log "sdk.info: $(tr '\n' ' ' <"$TIZEN_STUDIO/sdk.info")"

# Prints its own progress and failure messages; `||` keeps the ERR trap from adding a second one.
export LOG
"$ROOT/scripts/install-tizen.sh" "$TIZEN_STUDIO" "$TIZEN_VERSION" || exit 1
TIZEN_DATA=$(sed -n 's/^TIZEN_SDK_DATA_PATH=//p' "$TIZEN_STUDIO/sdk.info")
log "TIZEN_DATA=$TIZEN_DATA"

# --- 2. Find the TV -------------------------------------------------------------
bold "2/4  Finding your TV"
if [ -n "${HOST_IP:-}" ]; then
  MY_IP="$HOST_IP" # set by scripts/dev.sh: in a container, the host's LAN IP
elif [ "$(uname -s)" = Darwin ]; then
  IFACE=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')
  MY_IP=$(ipconfig getifaddr "${IFACE:-en0}" 2>/dev/null || true)
else
  MY_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p')
fi
[ -n "$MY_IP" ] || fail "Couldn't work out this computer's IP address. Are you on Wi-Fi or Ethernet?"
ok "this computer is $MY_IP"

tv_info() { curl -s -m 2 "http://$1:8001/api/v2/" 2>/dev/null || true; }
field() { sed -n "s/.*\"$1\" *: *\"\([^\"]*\)\".*/\1/p" <<<"$2" | head -1; }

TV_IP="$(get_env TV_IP)"
INFO=""
[ -n "$TV_IP" ] && INFO=$(tv_info "$TV_IP")
if [ -z "$INFO" ]; then
  echo "  Scanning ${MY_IP%.*}.0/24 for Samsung TVs (make sure the TV is on)…"
  FOUND=()
  TMP="$(mktemp -d)"
  for i in $(seq 1 254); do
    (
      r=$(tv_info "${MY_IP%.*}.$i")
      grep -q '"type" *: *"Samsung SmartTV"' <<<"$r" && echo "$r" >"$TMP/${MY_IP%.*}.$i"
    ) &
  done
  wait
  for f in "$TMP"/*; do [ -e "$f" ] && FOUND+=("$(basename "$f")"); done
  [ ${#FOUND[@]} -gt 0 ] || {
    rm -rf "$TMP"
    fail "No Samsung TV found on your network. Is it on, and on the same network as this computer?"
  }
  if [ ${#FOUND[@]} -eq 1 ]; then
    TV_IP="${FOUND[0]}"
  else
    echo "  Found ${#FOUND[@]} TVs:"
    for n in "${!FOUND[@]}"; do echo "    $((n + 1))) ${FOUND[$n]}  $(field name "$(cat "$TMP/${FOUND[$n]}")")"; done
    read -rp "  Which one? [1] " PICK
    TV_IP="${FOUND[$((${PICK:-1} - 1))]}"
  fi
  INFO=$(cat "$TMP/$TV_IP")
  rm -rf "$TMP"
fi
TV_NAME=$(field name "$INFO")
TV_MODEL=$(field modelName "$INFO")
ok "$TV_NAME ($TV_MODEL) at $TV_IP"
set_env TV_IP "$TV_IP"
set_env TV_MODEL "$TV_MODEL"

DEV_MODE=$(field developerMode "$INFO")
DEV_IP=$(field developerIP "$INFO")
if [ "$DEV_MODE" != 1 ] || [ "$DEV_IP" != "$MY_IP" ]; then
  if [ "$DEV_MODE" = 1 ]; then
    echo "  Developer Mode is on, but it points at $DEV_IP instead of this computer."
  else echo "  Developer Mode is off."; fi
  cat <<EOF

  On the TV:
    1. Press Home and open Apps.
    2. On the Apps screen, type 1 2 3 4 5 on the remote.
       (No number keys? Press the 123 button for the on-screen keypad.
        Nothing happened? Try again a little faster.)
    3. Turn Developer mode On, and enter this computer's IP: $MY_IP
    4. Choose OK, then restart the TV: hold the Power button until it turns off and back on.

  Then run ./scripts/setup.sh again.
EOF
  exit 1
fi
ok "Developer Mode is on and points at this computer"

# --- 3. Signing certificate -----------------------------------------------------
bold "3/4  Signing certificate"
PROFILE="$(get_env TIZEN_SIGN_PROFILE)"
PROFILE="${PROFILE:-samsucks}"
set_env TIZEN_SIGN_PROFILE "$PROFILE"
# shellcheck source=scripts/signing.sh
source "$ROOT/scripts/signing.sh"
signing_note() { ok "$*"; }
SIGNING_LOG="$LOG"
P12="$TIZEN_DATA/keystore/author/$PROFILE.p12"
if signing_profile_exists "$PROFILE"; then
  ok "profile '$PROFILE' already exists"
  PW="$(get_env TIZEN_CERT_PASSWORD)"
else
  PW="$(get_env TIZEN_CERT_PASSWORD)"
  # The CLI treats a stored password that decodes as base64 as encrypted, and
  # signing then stops at an "Author password:" prompt. The "-" in the "ss-"
  # prefix is not a base64 character. od reads exactly 12 bytes, so no SIGPIPE.
  case "$PW" in ss-*) ;; *) PW="ss-$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')" ;; esac
  set_env TIZEN_CERT_PASSWORD "$PW"
  "$TIZEN" certificate -a "$PROFILE" -p "$PW" -f "$PROFILE" >>"$LOG" 2>&1
fi
ensure_signing_profile "$PROFILE" "$P12" "$PW"

# --- 4. Connect -------------------------------------------------------------------
bold "4/4  Connecting to the TV"
"$SDB" connect "$TV_IP:26101" >>"$LOG" 2>&1 || true
"$SDB" devices | grep -q "^$TV_IP:26101" || fail "The TV didn't accept the connection. Restart the TV and run this again."
ok "connected"

printf '\n\033[1mAll set.\033[0m Install SamSUCKS on your TV with:\n\n    ./scripts/deploy.sh\n\n'
