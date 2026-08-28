#!/usr/bin/env bash
# agentfm Tier 1 installer — node110 backend
#
# Installs:
#   - /usr/local/bin/agentfm              (binary, fetched from api.agentfm.net/install.sh)
#   - /etc/agentfm/swarm.key              (0600 root; PSK from `agentfm -mode genkey`)
#   - /etc/systemd/system/agentfm-relay.service
#   - /etc/systemd/system/agentfm-api.service
#
# Tier 1 = relay + api gateway ONLY (no worker, no Podman). The api gateway
# listens on 127.0.0.1:8080 with keyless auth; smart-router calls it from the
# same host via config's agentfm_url. With no worker registered, /v1/chat/
# completions deterministically returns 404 model_not_found, which the smoke
# test uses as the "tier reached" signal.
#
# Idempotent: re-running skips already-installed steps.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Must run as root (uses install -o root)" >&2
  exit 1
fi

# ---------------------------------------------------------------- 1. binary
if ! command -v agentfm >/dev/null 2>&1; then
  echo "[1/5] fetching agentfm binary via hosted installer"
  # Hosted installer redirects to GitHub release 307. INSTALL_DIR defaults to
  # /usr/local/bin (writable when running as root).
  curl -fsSL https://api.agentfm.net/install.sh | bash
else
  echo "[1/5] agentfm already installed: $(command -v agentfm)"
fi

# Verify binary actually runs.
agentfm -h >/dev/null 2>&1 || {
  echo "agentfm binary present but not runnable" >&2
  exit 1
}

# ----------------------------------------------------- 2. private swarm PSK
install -d -m 0700 -o root -g root /etc/agentfm
if [[ ! -s /etc/agentfm/swarm.key ]]; then
  echo "[2/5] generating private swarm PSK"
  # `agentfm -mode genkey` writes the key to ./swarm.key in cwd and prints
  # status messages to stdout/stderr — so we cannot capture stdout into the
  # destination. Use an isolated tmp dir, then move the file.
  tmp_gen="$(mktemp -d)"
  ( cd "$tmp_gen" && /usr/local/bin/agentfm -mode genkey >/dev/null 2>&1 )
  install -m 0600 -o root -g root "$tmp_gen/swarm.key" /etc/agentfm/swarm.key
  rm -rf "$tmp_gen"
else
  echo "[2/5] /etc/agentfm/swarm.key already present"
fi
# Always re-enforce mode/owner (idempotent guard against installer drift).
chmod 0600 /etc/agentfm/swarm.key
chown root:root /etc/agentfm/swarm.key

# --------------------------------------------------- 3. systemd unit: relay
cat > /etc/systemd/system/agentfm-relay.service <<'UNIT_EOF'
[Unit]
Description=agentfm private relay (libp2p)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
# -port 4001 is the libp2p listen port; distinct from the OpenAI gateway (:8080).
# Tier 1 does not set -bootstrap: the relay dials the public lighthouse
# (78.47.21.107:4001) by default. The shared -swarmkey isolates our mesh from
# the public swarm — peer dials succeed only for peers presenting the same PSK.
ExecStart=/usr/local/bin/agentfm \
  -mode relay \
  -port 4001 \
  -swarmkey /etc/agentfm/swarm.key \
  -log-format json \
  -log-level info
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT_EOF

# --------------------------------------------- 4. systemd unit: api gateway
cat > /etc/systemd/system/agentfm-api.service <<'UNIT_EOF'
[Unit]
Description=agentfm OpenAI-compatible API gateway (loopback, keyless)
After=agentfm-relay.service
Wants=agentfm-relay.service

[Service]
Type=simple
# Loopback bind + no AGENTFM_API_KEYS → keyless auth (only reachable from the
# same host). Smart-router calls us via config['agentfm_url']. The api gateway
# shares the relay's libp2p stack via the PSK, so they discover each other
# automatically on the same host.
ExecStart=/usr/local/bin/agentfm \
  -mode api \
  -apiport 8080 \
  -api-bind 127.0.0.1 \
  -swarmkey /etc/agentfm/swarm.key \
  -log-format json \
  -log-level info
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT_EOF

# ------------------------------------------------------ 5. activate + health
echo "[3/5] reloading systemd"
systemctl daemon-reload

echo "[4/5] enabling + starting agentfm services"
systemctl enable --now agentfm-relay agentfm-api

# Give the api a moment to bind.
sleep 2

echo "[5/5] health check"
if ! curl -fsS http://127.0.0.1:8080/health; then
  echo "agentfm-api health failed; recent logs:" >&2
  journalctl -u agentfm-api -n 50 --no-pager >&2 || true
  exit 1
fi
echo

# Status snapshot for the operator.
echo "--- service status ---"
systemctl --no-pager --full status agentfm-relay agentfm-api | grep -E "Active:|Main PID:" || true
echo "--- /v1/models (Tier 1 expects empty list) ---"
curl -fsS http://127.0.0.1:8080/v1/models || true
echo
echo "agentfm install OK"
