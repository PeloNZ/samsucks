#!/usr/bin/env bash
# Sign the built app into build/samsucks.wgt. Needs no TV. Run ./scripts/build.sh first.
#   ./scripts/package.sh
# Signs with the profile TIZEN_SIGN_PROFILE (default samsucks). When the profile is
# missing, it is made from TIZEN_AUTHOR_P12 (path to the author certificate) and
# TIZEN_CERT_PASSWORD. The repo's env file supplies these when present;
# a value the caller already set wins.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck source=scripts/load-env.sh
  source "$ROOT/scripts/load-env.sh"
  load_env "$ENV_FILE"
fi

TIZEN_STUDIO="${TIZEN_STUDIO:-$HOME/tizen-sdk}"
TIZEN="$TIZEN_STUDIO/tools/ide/bin/tizen"
PROFILE="${TIZEN_SIGN_PROFILE:-samsucks}"
APP="$ROOT/build/app"
WGT="$ROOT/build/samsucks.wgt"

[ -x "$TIZEN" ] || {
  echo "tizen CLI not found at $TIZEN. Run ./scripts/setup.sh, or set TIZEN_STUDIO." >&2
  exit 1
}
[ -d "$APP" ] || {
  echo "No build at $APP. Run ./scripts/build.sh first." >&2
  exit 1
}

# shellcheck source=scripts/signing.sh
source "$ROOT/scripts/signing.sh"
SIGNING_LOG="$ROOT/build/package.log"
: >"$SIGNING_LOG"
ensure_signing_profile "$PROFILE" "${TIZEN_AUTHOR_P12:-}" "${TIZEN_CERT_PASSWORD:-}"

rm -f "$ROOT"/build/*.wgt
# stdin is closed so a password prompt fails at once instead of waiting.
"$TIZEN" package -t wgt -s "$PROFILE" -o "$ROOT/build" -- "$APP" </dev/null >>"$SIGNING_LOG" 2>&1 || {
  tail -20 "$SIGNING_LOG" >&2
  echo "Signing failed. Log: $SIGNING_LOG" >&2
  exit 1
}
# The package is named after the app ("SamSUCKS - Better Plex.wgt"); the installer chokes on spaces.
mv "$(ls "$ROOT"/build/*.wgt | head -1)" "$WGT"
echo "packaged $WGT"
