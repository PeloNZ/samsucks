# shellcheck shell=bash
# Shared signing profile code, sourced by setup.sh and package.sh. Not run on its own.
# Callers set TIZEN_STUDIO and TIZEN (path to the tizen CLI). Optional: SIGNING_LOG
# (a file for tool output) and a signing_note function (called with progress messages).

signing_note() { :; }

signing_profile_exists() { "$TIZEN" security-profiles list 2>/dev/null | grep -q "^$1 "; }

# ensure_signing_profile PROFILE P12 PASSWORD
# Adds PROFILE from the author certificate P12 when it is missing, then makes
# signing work without a keyring and without a password prompt.
ensure_signing_profile() {
  local profile="$1" p12="$2" pw="$3"
  local log="${SIGNING_LOG:-/dev/null}" data profiles
  data=$(sed -n 's/^TIZEN_SDK_DATA_PATH=//p' "$TIZEN_STUDIO/sdk.info")
  [ -n "$data" ] || {
    echo "Can't find TIZEN_SDK_DATA_PATH in $TIZEN_STUDIO/sdk.info." >&2
    return 1
  }

  if ! signing_profile_exists "$profile"; then
    if [ ! -f "$p12" ] || [ -z "$pw" ]; then
      echo "Signing profile '$profile' does not exist. Set TIZEN_AUTHOR_P12 (path to the author certificate) and TIZEN_CERT_PASSWORD to create it, or run ./scripts/setup.sh." >&2
      return 1
    fi
    "$TIZEN" security-profiles add -n "$profile" -a "$p12" -p "$pw" >>"$log" 2>&1 || {
      echo "Could not add signing profile '$profile'." >&2
      return 1
    }
    signing_note "created profile '$profile'"
  fi

  # Without a desktop keyring (a container, a headless server) the CLI writes
  # profiles.xml with a path to a .pwd file that never gets made, and signing fails
  # with "Invalid password". Replace each such path with the password itself. The
  # distributor password is Samsung's public default.
  profiles="$data/profile/profiles.xml"
  if [ -n "$pw" ] && PW="$pw" PROFILE="$profile" perl -0777 -ne 'exit(!/<profile name="\Q$ENV{PROFILE}\E">.*?\.pwd"/s)' "$profiles"; then
    PW="$pw" PROFILE="$profile" perl -pi -e '
      $cur = $1 if /<profile name="([^"]*)"/;
      if ($cur eq $ENV{PROFILE}) {
        s{(distributor="0"[^>]*password=")([^"]*\.pwd)"}{do { my ($k, $f) = ($1, $2); -f $f ? "$k$f\"" : "$k$ENV{PW}\"" }}e;
        s{(distributor="1"[^>]*password=")([^"]*\.pwd)"}{do { my ($k, $f) = ($1, $2); -f $f ? "$k$f\"" : "${k}tizenpkcs12passfordsigner\"" }}e;
      }
    ' "$profiles"
    signing_note "stored the signing passwords in the profile (no keyring)"
  fi
  "$TIZEN" cli-config "profiles.path=$profiles" >>"$log" 2>&1
}
