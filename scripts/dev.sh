#!/usr/bin/env bash
# Run a command in the Ubuntu amd64 dev container (default: a shell).
#   ./scripts/dev.sh ./scripts/setup.sh
#   ./scripts/dev.sh ./scripts/deploy.sh --dev
#   ./scripts/dev.sh node tools/devserver.mjs
# The repo is mounted at /work. The "samsucks-home" volume keeps the Tizen
# tools, certificates and installer download across runs. Port 8790 is
# published so the TV can reach tools/devserver.mjs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE=samsucks-dev

docker build -q --platform linux/amd64 -t "$IMAGE" "$ROOT" >/dev/null

# The container sees only its own network, so pass this computer's LAN IP.
case "$(uname -s)" in
  Darwin) HOST_IP=$(ipconfig getifaddr "$(route -n get default | awk '/interface:/ { print $2 }')" || true) ;;
  *) HOST_IP=$(ip -4 route get 1.1.1.1 | sed -n 's/.* src \([0-9.]*\).*/\1/p') ;;
esac

TTY=(); [ -t 0 ] && TTY=(-it)
# ${TTY[@]+...}: macOS bash 3.2 treats an empty array as unset under set -u.
exec docker run --rm ${TTY[@]+"${TTY[@]}"} --platform linux/amd64 \
  -v "$ROOT:/work" -v samsucks-home:/home/dev \
  -p 8790:8790 -e HOST_IP="$HOST_IP" \
  "$IMAGE" "${@:-bash}"
