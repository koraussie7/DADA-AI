#!/usr/bin/env bash
# ============================================================================
# Hermes Agent + hermes-desktop installer (Linux: Fedora / Ubuntu / RHEL)
# Target: peer-to-peer mesh node (one of: 110.x.x.x, 91.x.x.x, 97.x.x.x)
#
# Idempotent. Re-running is safe; existing installs are updated.
# Requires: sudo, curl, git, node>=18 (for build), rpm/dpkg
#
# Per-node API keys: a unique HERMES_API_TOKEN is generated on first run
# and stored in /etc/hermes/node.env (mode 0600). If MESH_LB_TOKEN is
# provided, hermes-api will accept BOTH the per-node token AND the shared
# LB token via HERMES_API_TOKENS="<node>,<lb>". This lets the mesh LB
# forward requests without knowing per-node tokens, while admins can
# still hit any node directly with its unique token.
# ============================================================================
set -euo pipefail

# ---------- Config (edit before running, or export as env vars) ------------
: "${HERMES_NODE_NAME:=$(hostname -s)}"             # e.g. node110
: "${HERMES_MESH_DIR:=/etc/hermes/mesh}"            # shared profile directory
: "${HERMES_DATA_DIR:=$HOME/.hermes}"               # hermes-agent runtime state
: "${HERMES_PORT:=8642}"                            # hermes-agent API port
: "${ALLROUTER_BASE_URL:=https://api.privseai.com/v1}"
: "${ALLROUTER_API_KEY:?Set ALLROUTER_API_KEY in env or .env file}"
: "${MESH_REPO_URL:=}"                              # git URL for shared profiles (optional)
: "${MESH_LB_TOKEN:=}"                              # shared LB token (optional; pairs with lb/install-lb.sh)
: "${HERMES_NODE_TOKEN_FILE:=/etc/hermes/node.token}"

log() { printf '\033[1;34m[hermes-install]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[hermes-install]\033[0m %s\n' "$*" >&2; }

# ---------- 1. OS detection -------------------------------------------------
. /etc/os-release 2>/dev/null || true
case "${ID:-unknown}" in
  fedora|rhel|rocky|almalinux|centos) PKG=dnf ;;
  ubuntu|debian|pop)                 PKG=apt-get ;;
  *) err "Unsupported distro: ${ID:-unknown}. Edit this script for your pkg manager."; exit 1 ;;
esac
log "Detected package manager: $PKG"

# ---------- 2. Install Hermes Agent CLI -------------------------------------
if ! command -v hermes >/dev/null 2>&1; then
  log "Installing Hermes Agent CLI..."
  curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/install.sh | bash
else
  log "Hermes Agent already present: $(hermes --version 2>/dev/null || echo unknown)"
fi

# ---------- 3. Install hermes-desktop (Electron app) ------------------------
DESKTOP_DIR="$HOME/.local/share/hermes-desktop"
if [[ ! -d "$DESKTOP_DIR" ]]; then
  log "Cloning hermes-desktop source..."
  git clone --depth=1 https://github.com/koraussie7/hermes-desktop.git "$DESKTOP_DIR"
fi

if [[ "$PKG" == "dnf" ]]; then
  log "Building RPM via electron-builder..."
  (cd "$DESKTOP_DIR" && npm ci && npm run build:linux)
  sudo dnf install -y "$DESKTOP_DIR"/dist/hermes-desktop-*.rpm || \
    sudo dnf install -y --nogpgcheck "$DESKTOP_DIR"/dist/hermes-desktop-*.rpm
else
  log "Building .deb via electron-builder..."
  (cd "$DESKTOP_DIR" && npm ci && npm run build:linux)
  sudo apt-get install -y "$DESKTOP_DIR"/dist/hermes-desktop_*.deb
fi

# ---------- 4. Drop allrouter env file --------------------------------------
sudo mkdir -p /etc/hermes
sudo tee /etc/hermes/allrouter.env >/dev/null <<EOF
# Allrouter (LiteLLM reverse proxy in front of every provider).
# Stainless fingerprint bypass: hermes-agent uses OpenAI SDK; override the
# User-Agent header so the 403 from api.privseai.com is avoided.
ALLROUTER_BASE_URL=${ALLROUTER_BASE_URL}
ALLROUTER_API_KEY=${ALLROUTER_API_KEY}
OPENAI_BASE_URL=${ALLROUTER_BASE_URL}
OPENAI_API_KEY=${ALLROUTER_API_KEY}
HERMES_LLM_USER_AGENT=openai-node
HERMES_LLM_DEFAULT_HEADERS='{"User-Agent":"openai-node","X-Stainless-Os":"Linux","X-Stainless-Arch":"x64","X-Stainless-Package-Version":"1.0.0","X-Stainless-Runtime":"node","X-Stainless-Runtime-Version":"20.0.0"}'
# Hermes Desktop (daedalOS) + smart-router env (informational on Linux; consumed by MacBook)
HERMES_DAEDAL_URL=http://localhost:3030
SMART_ROUTER_URL=http://127.0.0.1:4001
SMART_ROUTER_FALLBACK_URL=http://127.0.0.1:14001
HERMES_LLM_TRAFFIC_VIA_SMART_ROUTER=true
EOF
sudo chmod 600 /etc/hermes/allrouter.env
log "Wrote /etc/hermes/allrouter.env (mode 600)"

# ---------- 5. Per-node API token + mesh-LB token ---------------------------
# Per-node token: unique to THIS host. Admins use it for direct access.
# Mesh-LB token (if provided): shared with the LB host. Backends accept it
#   via HERMES_API_TOKENS so the LB can forward traffic without knowing
#   the per-node token of each backend.
sudo mkdir -p /etc/hermes
if [[ ! -f "$HERMES_NODE_TOKEN_FILE" ]]; then
  log "Generating per-node API token for ${HERMES_NODE_NAME}..."
  openssl rand -hex 32 | sudo tee "$HERMES_NODE_TOKEN_FILE" >/dev/null
  sudo chmod 600 "$HERMES_NODE_TOKEN_FILE"
else
  log "Per-node API token already exists ($(sudo wc -c < "$HERMES_NODE_TOKEN_FILE") bytes)"
fi
PER_NODE_TOKEN="$(sudo cat "$HERMES_NODE_TOKEN_FILE")"

# Build HERMES_API_TOKENS = per-node + (optional) mesh-lb.
if [[ -n "$MESH_LB_TOKEN" ]]; then
  HERMES_API_TOKENS="${PER_NODE_TOKEN},${MESH_LB_TOKEN}"
  log "Backend will accept BOTH per-node token AND mesh-LB token"
else
  HERMES_API_TOKENS="${PER_NODE_TOKEN}"
  log "Backend will accept per-node token only (no mesh-LB)"
fi

sudo tee /etc/hermes/node.env >/dev/null <<EOF
# Per-node auth for hermes-api. Read by the systemd unit below.
# HERMES_API_TOKENS is a comma-separated list of accepted bearer tokens;
# any match authenticates the request. hermes-agent exposes both
# HERMES_API_TOKEN (single) and HERMES_API_TOKENS (multi) env vars.
HERMES_NODE_NAME=${HERMES_NODE_NAME}
HERMES_API_TOKEN=${PER_NODE_TOKEN}
HERMES_API_TOKENS=${HERMES_API_TOKENS}
HERMES_PORT=${HERMES_PORT}
EOF
sudo chmod 600 /etc/hermes/node.env
log "Wrote /etc/hermes/node.env (mode 600)"

# ---------- 6. Shared mesh profile directory --------------------------------
sudo mkdir -p "$HERMES_MESH_DIR"
sudo chown "$USER":"$USER" "$HERMES_MESH_DIR"
if [[ -n "$MESH_REPO_URL" ]]; then
  if [[ ! -d "$HERMES_MESH_DIR/.git" ]]; then
    log "Cloning mesh profile repo..."
    git clone "$MESH_REPO_URL" "$HERMES_MESH_DIR"
  else
    log "Pulling latest mesh profiles..."
    (cd "$HERMES_MESH_DIR" && git pull --ff-only)
  fi
fi

# ---------- 7. Symlink config into hermes-agent's expected location --------
mkdir -p "$HERMES_DATA_DIR"
ln -sf /etc/hermes/allrouter.env "$HERMES_DATA_DIR/.env"
ln -sf "$HERMES_MESH_DIR/profiles.yaml" "$HERMES_DATA_DIR/profiles.yaml" 2>/dev/null || true

# ---------- 8. systemd unit for Hermes API backend --------------------------
sudo tee /etc/systemd/system/hermes-api.service >/dev/null <<EOF
[Unit]
Description=Hermes Agent API (peer-to-peer mesh node: ${HERMES_NODE_NAME})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${USER}
# Order matters: allrouter (LLM creds) loads first, then node.env overrides
# HERMES_API_TOKEN/HERMES_API_TOKENS with the per-node + mesh-LB tokens.
EnvironmentFile=/etc/hermes/allrouter.env
EnvironmentFile=/etc/hermes/node.env
ExecStart=$(command -v hermes) serve --host 0.0.0.0 --port ${HERMES_PORT}
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now hermes-api
log "Hermes API running on :${HERMES_PORT} (node: ${HERMES_NODE_NAME})"

# ---------- 9. Mesh sync cron (pull profiles every 5 min) -------------------
sudo tee /etc/cron.d/hermes-mesh-sync >/dev/null <<EOF
*/5 * * * * ${USER} /usr/local/bin/hermes-mesh-sync.sh >> /var/log/hermes-mesh-sync.log 2>&1
EOF

sudo tee /usr/local/bin/hermes-mesh-sync.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
MESH_DIR=/etc/hermes/mesh
[[ -d "$MESH_DIR/.git" ]] || exit 0
cd "$MESH_DIR"
git fetch --quiet
if ! git diff --quiet HEAD..@{u} 2>/dev/null; then
  git merge --ff-only @{u} || true
  systemctl reload hermes-api 2>/dev/null || true
fi
EOF
sudo chmod +x /usr/local/bin/hermes-mesh-sync.sh

cat <<EOF

  ┌──────────────────────────────────────────────────────────────────────┐
  │  Hermes node '${HERMES_NODE_NAME}' is up on :${HERMES_PORT}            │
  │                                                                      │
  │  Per-node token: $(sudo cut -c1-8 "$HERMES_NODE_TOKEN_FILE")…         │
  │  Full token at:  ${HERMES_NODE_TOKEN_FILE}  (mode 600)                │
  │                                                                      │
  │  Test locally:                                                       │
  │    curl -H "Authorization: Bearer \$(sudo cat ${HERMES_NODE_TOKEN_FILE})" \\
  │         http://localhost:${HERMES_PORT}/health                         │
  │                                                                      │
  │  Mesh-LB token: $(if [[ -n "$MESH_LB_TOKEN" ]]; then echo "configured"; else echo "not set"; fi)              │
  │  (LB-routed traffic uses a SHARED token set on the LB host too.)      │
  └──────────────────────────────────────────────────────────────────────┘
EOF
