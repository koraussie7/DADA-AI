#!/usr/bin/env bash
# ============================================================================
# launch-daedal.sh
#
# Idempotent launcher for the daedalOS Docker container. Used by the Hermes
# Desktop "Desktop" tab (http://localhost:3030) and by install-macos.sh
# section 3.5. Image: dustinbrett/daedalos:latest (~2-3 GB, includes
# Playwright + Chromium). State is browser-side (BrowserFS + IndexedDB) —
# no volume is mounted, and stopping the container does not lose user data.
#
# Usage:
#   bash launch-daedal.sh           # pull + (create-or-start)
#   bash launch-daedal.sh --force   # remove existing container, then create
#   bash launch-daedal.sh --no-pull # skip docker pull
# ============================================================================
set -euo pipefail

DAEDAL_IMAGE="${DAEDAL_IMAGE:-dustinbrett/daedalos:latest}"
DAEDAL_PORT="${DAEDAL_PORT:-3030}"
DAEDAL_NAME="${DAEDAL_NAME:-daedalos}"
FORCE=0
DO_PULL=1

for a in "$@"; do
  case "$a" in
    --force) FORCE=1 ;;
    --no-pull) DO_PULL=0 ;;
    -h|--help)
      sed -n '4,16p' "$0"; exit 0 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not installed. Install Docker Desktop for Mac and retry." >&2
  exit 1
fi

if [[ "$DO_PULL" -eq 1 ]]; then
  echo "==> docker pull $DAEDAL_IMAGE"
  docker pull --platform linux/amd64 "$DAEDAL_IMAGE"
fi

EXISTS=$(docker ps -a --format '{{.Names}}' | grep -x "$DAEDAL_NAME" || true)
if [[ -n "$EXISTS" ]]; then
  if [[ "$FORCE" -eq 1 ]]; then
    echo "==> docker rm -f $DAEDAL_NAME (--force)"
    docker rm -f "$DAEDAL_NAME" >/dev/null
  else
    echo "==> container $DAEDAL_NAME exists; starting if stopped"
    docker start "$DAEDAL_NAME" 2>/dev/null || true
    echo "    up: $(docker inspect -f '{{.State.Running}}' "$DAEDAL_NAME" 2>/dev/null || echo unknown)"
    exit 0
  fi
fi

echo "==> docker run -d --name $DAEDAL_NAME -p $DAEDAL_PORT:3000 $DAEDAL_IMAGE"
docker run -d --platform linux/amd64 --name "$DAEDAL_NAME" \
  --restart unless-stopped -p "${DAEDAL_PORT}:3000" "$DAEDAL_IMAGE"

echo "==> waiting for http://127.0.0.1:${DAEDAL_PORT}/ ..."
for i in $(seq 1 30); do
  if curl -sf -o /dev/null --max-time 2 "http://127.0.0.1:${DAEDAL_PORT}/"; then
    echo "    ready after ${i}s"
    exit 0
  fi
  sleep 1
done

echo "WARN: container is up but not responding on :$DAEDAL_PORT after 30s." >&2
echo "      tail logs: docker logs $DAEDAL_NAME" >&2
exit 1