#!/usr/bin/env bash
# Sourced by build.sh, package.sh and deploy.sh. It only defines load_env.
# load_env <file> exports the variables in the env file. A variable the caller already set
# (even to an empty value) keeps the caller's value; the file fills only unset variables.
load_env() {
  local file="$1" name
  local -a kept=()
  while IFS= read -r name; do
    [ -n "${!name+x}" ] && kept+=("$name=${!name}")
  done < <(sed -n 's/^[[:space:]]*\(export[[:space:]][[:space:]]*\)\{0,1\}\([A-Za-z_][A-Za-z0-9_]*\)=.*/\2/p' "$file")
  set -a
  # shellcheck source=/dev/null
  source "$file"
  set +a
  # ${kept[@]+...} keeps an empty array safe under set -u on bash 3.2.
  local pair
  for pair in ${kept[@]+"${kept[@]}"}; do export "${pair?}"; done
}
