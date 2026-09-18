#!/usr/bin/env bash
# Pull the latest Open WebUI image and (re)start the stack.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

usage() {
  echo "Usage: $0 [--no-pull] [--prune]"
  echo "  --no-pull  skip the image pull and use the local image"
  echo "  --prune    remove dangling images afterwards (frees the old image after an update)"
}

die() {
  echo "error: $*" >&2
  exit 1
}

pull=1
prune=0
for arg in "$@"; do
  case "$arg" in
    --no-pull) pull=0 ;;
    --prune) prune=1 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

command -v docker >/dev/null 2>&1 || die "docker is not installed"
docker compose version >/dev/null 2>&1 || die "docker compose plugin is not installed"
docker info >/dev/null 2>&1 || die "cannot reach the Docker daemon (is it running, and are you in the docker group?)"
docker compose config -q

if [ "$pull" -eq 1 ]; then
  echo ">> Pulling latest image"
  docker compose pull
fi

echo ">> Starting Open WebUI"
if ! docker compose up -d --remove-orphans --wait --wait-timeout 300; then
  echo "error: Open WebUI did not become healthy, last log lines:" >&2
  docker compose logs --tail 50 open-webui >&2
  exit 1
fi

if [ "$prune" -eq 1 ]; then
  echo ">> Removing dangling images"
  docker image prune -f
fi

port="$(docker compose port open-webui 8080 | head -n1 | sed 's/.*://')"
ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"

echo
docker compose ps
echo
echo "Open WebUI is ready:"
echo "  http://localhost:${port}"
if [ -n "$ip" ]; then
  echo "  http://${ip}:${port}"
fi
echo "Logs: docker compose logs -f open-webui"
