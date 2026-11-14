#!/usr/bin/env bash
# Run a command in the Ubuntu amd64 dev container (default: a shell). See compose.yaml.
#   ./scripts/dev.sh ./scripts/setup.sh
#   ./scripts/dev.sh ./scripts/deploy.sh --dev
#   ./scripts/dev.sh ./scripts/check.sh
# The first run also starts the devserver service on port 8790.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# The container sees only its own network, so pass this computer's LAN IP.
case "$(uname -s)" in
  Darwin) HOST_IP=$(ipconfig getifaddr "$(route -n get default | awk '/interface:/ { print $2 }')" || true) ;;
  *) HOST_IP=$(ip -4 route get 1.1.1.1 | sed -n 's/.* src \([0-9.]*\).*/\1/p') ;;
esac
export HOST_IP

COMPOSE=(docker compose -f "$ROOT/compose.yaml")
"${COMPOSE[@]}" build -q
TTY=()
[ -t 0 ] || TTY=(-T)
# ${TTY[@]+...}: macOS bash 3.2 treats an empty array as unset under set -u.
exec "${COMPOSE[@]}" run --rm ${TTY[@]+"${TTY[@]}"} dev "$@"
