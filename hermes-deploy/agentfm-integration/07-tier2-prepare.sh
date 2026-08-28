#!/usr/bin/env bash
# 07-tier2-prepare.sh — Podman worker 등록 (agentfm Tier 2 의 실제 backend)
#
# Tier 1 의 404 model_not_found → Tier 2 의 200 + real completion 으로 뒤집기:
#   - Podman (rootless) 설치
#   - agentfm system user 생성 (rootless container owner)
#   - /etc/agentfm/swarm.key 를 agentfm group readable 로 (0640 root:agentfm)
#   - /opt/agentfm-worker/agentdir 스캐폴드 (alpine Containerfile + run.sh)
#   - podman build 를 agentfm user 로 (rootless storage)
#   - relay peer-id 추출 후 agentfm-worker.service 작성 + 활성화
#   - /v1/models 에 worker 가 등장할 때까지 polling
#
# Idempotent: re-running skips already-installed steps. Root 권한 필요.
#
# 호스트에 미리 설치되어 있어야 함:
#   - agentfm (Tier 1 install.sh)
#   - agentfm-relay.service active
#   - agentfm-api.service active
#   - ollama.service active (qwen2.5:0.5b pulled)

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Must run as root (uses install -o, podman build prep)" >&2
  exit 1
fi

log() { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf '\033[1;31mFATAL:\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 1. Podman
if ! command -v podman >/dev/null 2>&1; then
  log "[1/7] installing Podman + uidmap (rootless prerequisites)"
  # node110's /tmp is 0700 root:root (security lockdown); apt-key wants to drop
  # a config tmpfile there for legacy repo InRelease signatures. Redirect
  # TMPDIR to /var/tmp (1777) so apt-key can succeed (cosmetic — install
  # actually proceeds even with the warnings, but the noise obscures real errors).
  export TMPDIR=/var/tmp
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq podman uidmap >/dev/null
else
  log "[1/7] podman already installed: $(podman --version)"
fi

# Sanity: podman can run rootless at all
if ! podman info >/dev/null 2>&1; then
  die "podman info failed even as root; check kernel.unprivileged_userns_clone"
fi

# ---------------------------------------------------- 2. agentfm user (rootless)
if ! id agentfm >/dev/null 2>&1; then
  log "[2/7] creating agentfm user (rootless Podman owner)"
  useradd -r -d /var/lib/agentfm -s /usr/sbin/nologin agentfm
  install -d -m 0700 -o agentfm -g agentfm /var/lib/agentfm
else
  log "[2/7] agentfm user already present"
fi
install -d -m 0700 -o agentfm -g agentfm /var/lib/agentfm

# agentfm worker writes per-task container output capture files to
# /.agentfm_temp on the host filesystem (NOT inside the container). The
# directory must exist with agentfm:agentfm ownership or the worker
# fails its first task with `mkdir /.agentfm_temp: permission denied`.
install -d -m 0750 -o agentfm -g agentfm /.agentfm_temp
log "[2b/7] /.agentfm_temp created (agentfm:agentfm 0750)"

# subuid/subgid (rootless UID/GID mapping — required for podman rootless)
if ! grep -q '^agentfm:' /etc/subuid 2>/dev/null; then
  echo "agentfm:100000:65536" >> /etc/subuid
fi
if ! grep -q '^agentfm:' /etc/subgid 2>/dev/null; then
  echo "agentfm:100000:65536" >> /etc/subgid
fi

# ----------------------------------------------- 3. swarm.key group-read for agentfm
if [[ -s /etc/agentfm/swarm.key ]]; then
  log "[3/7] sharing /etc/agentfm/swarm.key with agentfm group (agentfm binary needs read)"
  chown root:agentfm /etc/agentfm/swarm.key
  chmod 0640 /etc/agentfm/swarm.key
  # The /etc/agentfm directory itself was created by install.sh as 0700
  # root:root, which blocks agentfm group traversal despite swarm.key
  # being 0640. Without this fix `runuser -u agentfm -- cat swarm.key`
  # fails with EACCES and the worker can't read its key.
  chown root:agentfm /etc/agentfm
  chmod 0750 /etc/agentfm
else
  die "/etc/agentfm/swarm.key missing — run install.sh (Tier 1) first"
fi

# ---------------------------------------------------- 4. agentdir 스캐폴드 (Containerfile + run.sh)
install -d -m 0750 -o agentfm -g agentfm /opt/agentfm-worker/agentdir

cat > /opt/agentfm-worker/agentdir/Containerfile <<'CFILE_EOF'
FROM docker.io/library/alpine:3.20
RUN apk add --no-cache curl python3 bash
COPY run.sh /run.sh
RUN chmod +x /run.sh
ENTRYPOINT ["/run.sh"]
CFILE_EOF

cat > /opt/agentfm-worker/agentdir/run.sh <<'RUN_EOF'
#!/bin/bash
# Minimal worker agent: forward prompt (passed as $1) to host Ollama at
# 127.0.0.1:11434 via /api/generate, emit response on stdout.
#
# CRITICAL: agentfm worker passes the prompt as argv $1, NOT stdin. A
# stdin-read loop exits immediately on EOF and returns empty content;
# $1 must be used directly. Model comes from $AGENTFM_MODEL env var.
set -uo pipefail
MODEL="${AGENTFM_MODEL:-qwen2.5:0.5b}"
PROMPT="${1:-}"
if [[ -z "$PROMPT" ]]; then
  echo "ERR: no prompt argument (agentfm worker passes prompt as \$1, not stdin)" >&2
  exit 1
fi
# JSON-escape the prompt via python3
prompt_json=$(printf '%s' "$PROMPT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
# Call Ollama's /api/generate (non-streaming) and emit .response on stdout
resp=$(curl -fsS -X POST "http://127.0.0.1:11434/api/generate" \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"$MODEL\",\"prompt\":$prompt_json,\"stream\":false,\"options\":{\"num_predict\":256}}" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin).get("response",""), end="")' 2>/dev/null)
printf '%s\n' "$resp"
RUN_EOF

chmod +x /opt/agentfm-worker/agentdir/run.sh
chown -R agentfm:agentfm /opt/agentfm-worker

# Ensure agentfm has its own XDG_RUNTIME_DIR. Without this podman errors:
#   "XDG_RUNTIME_DIR directory \"/run/user/0\" is not owned by the current user"
# (default fallback is root's /run/user/0, which agentfm doesn't own).
install -d -m 0700 -o agentfm -g agentfm /run/user/994
log "[3b/7] /run/user/994 owned by agentfm:agentfm (0700)"

# Enable systemd linger for agentfm so crun (default OCI runtime) can talk to
# systemd's dbus for cgroup setup. Without this, builds fail at the first
# RUN step with "sd-bus call: Permission denied". Empty file at
# /var/lib/systemd/linger/<user> = linger enabled (no-op if already present).
install -d -m 0755 /var/lib/systemd/linger 2>/dev/null || true
loginctl enable-linger agentfm 2>/dev/null || true
log "[3c/7] loginctl enable-linger agentfm (crun sd-bus access)"

# -------------------------------------------------- 5. podman build (agentfm user, rootless)
log "[4/7] building agentfm-ollama-bridge:latest (rootless, ~25 MB alpine + curl + python3)"
# Use runuser (not sudo) — sudo's env_reset strips HOME= override.
# CRITICAL: ssh-as-root carries cwd=/root into runuser; agentfm cannot chdir
# to /root (mode 0700/0750). podman errors with "cannot chdir to /root: Permission
# denied" then cascades to chown failures. Use bash -c with explicit cd + HOME
# + XDG_RUNTIME_DIR (env prefix syntax). HOME is needed for rootless storage
# paths; XDG_RUNTIME_DIR for per-user sockets/locks.
runuser -u agentfm -- bash -c \
  'cd /var/lib/agentfm && \
   HOME=/var/lib/agentfm XDG_RUNTIME_DIR=/run/user/994 \
   podman build --runtime=runc --cgroup-manager=cgroupfs \
     -t agentfm-ollama-bridge:latest /opt/agentfm-worker/agentdir' \
  || die "podman build failed; check /var/lib/agentfm/.local/share/containers logs"

# ----------------------------------- 6. relay peer-id 추출 → systemd unit + enable
log "[5/7] extracting agentfm-relay peer-id from journal"
RELAY_PID=$(journalctl -u agentfm-relay --no-pager -n 200 2>/dev/null \
  | grep -oE 'Peer ID: [A-Za-z0-9]+' \
  | head -1 | awk '{print $3}')
[[ -n "$RELAY_PID" ]] || die "cannot find agentfm-relay Peer ID; relay service not running?"

BOOTSTRAP="/ip4/127.0.0.1/tcp/4001/p2p/$RELAY_PID"
log "    bootstrap = $BOOTSTRAP"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ ! -s "$SCRIPT_DIR/08-tier2-worker.service" ]]; then
  die "08-tier2-worker.service not found alongside this script ($SCRIPT_DIR)"
fi

log "[6/7] writing + enabling agentfm-worker.service"
install -d -m 0755 /etc/systemd/system
sed "s|__BOOTSTRAP__|$BOOTSTRAP|" "$SCRIPT_DIR/08-tier2-worker.service" \
  > /etc/systemd/system/agentfm-worker.service
chmod 0644 /etc/systemd/system/agentfm-worker.service
systemctl daemon-reload
systemctl enable --now agentfm-worker

# Make sure ollama is enabled persistently (idempotent)
if systemctl list-unit-files ollama.service >/dev/null 2>&1; then
  systemctl enable ollama >/dev/null 2>&1 || true
fi

# ----------------------------------- 7. wait for worker registration in /v1/models
log "[7/7] polling http://127.0.0.1:8080/v1/models for worker registration"
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  count=$(curl -fsS http://127.0.0.1:8080/v1/models 2>/dev/null \
    | python3 -c 'import sys,json; print(len(json.load(sys.stdin).get("data", [])))' 2>/dev/null \
    || echo 0)
  if [[ "$count" -gt 0 ]]; then
    log "OK: agentfm worker registered (models count=$count) after ${i}x2s"
    log "--- service status ---"
    systemctl --no-pager --full status agentfm-worker | grep -E "Active:|Main PID:" || true
    log "--- /v1/models ---"
    curl -fsS http://127.0.0.1:8080/v1/models | python3 -m json.tool || true
    echo
    echo "agentfm Tier 2 prepare OK"
    exit 0
  fi
  sleep 2
done

die "worker did not register in 30s. Recent logs:
$(journalctl -u agentfm-worker -n 80 --no-pager 2>&1 || true)"
