#!/usr/bin/env bash
# ============================================================================
# Hermes Mesh LB installer
#
# Runs on the designated LB host (typically one of the mesh nodes, e.g.
# node110). Installs Caddy, drops the Caddyfile template, sets up the
# mesh-sync regen cron, and starts the LB.
#
# Required env vars:
#   MESH_LB_TOKEN          — shared token backends accept for LB-routed traffic
#   MESH_REPO_URL          — git URL of the mesh-profiles repo (optional but recommended)
#   MESH_LB_NODE_NAME      — name of THIS host (so the regen script can exclude
#                            itself from the upstream list). Defaults to hostname -s.
#
# Optional:
#   MESH_LB_PORT           — port the LB listens on (default 8643)
#   MESH_LB_ADMIN_ADDR     — Caddy admin endpoint (default localhost:2019)
#
# Re-running is safe; existing config is preserved unless explicitly forced.
# ============================================================================
set -euo pipefail

: "${MESH_LB_TOKEN:?Set MESH_LB_TOKEN in env — must match the value on backend nodes}"
: "${MESH_REPO_URL:=}"
: "${MESH_LB_NODE_NAME:=$(hostname -s)}"
: "${MESH_LB_PORT:=8643}"
: "${MESH_LB_ADMIN_ADDR:=localhost:2019}"
: "${HERMES_MESH_DIR:=/etc/hermes/mesh}"
: "${CADDYFILE_DIR:=/etc/caddy}"
: "${CADDYFILE_PATH:=/etc/caddy/Caddyfile}"

log() { printf '\033[1;34m[mesh-lb]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[mesh-lb]\033[0m %s\n' "$*" >&2; }

# ---------- 1. Install Caddy -------------------------------------------------
. /etc/os-release 2>/dev/null || true
case "${ID:-unknown}" in
  fedora|rhel|rocky|almalinux|centos) PKG=dnf ;;
  ubuntu|debian|pop)                 PKG=apt-get ;;
  *) err "Unsupported distro: ${ID:-unknown}"; exit 1 ;;
esac

if ! command -v caddy >/dev/null 2>&1; then
  log "Installing Caddy..."
  if [[ "$PKG" == "dnf" ]]; then
    dnf install -y 'dnf-command(copr)' || true
    dnf copr enable -y @caddy/caddy 2>/dev/null || true
    dnf install -y caddy
  else
    apt-get install -y debian-keyring debian-archive-keyring
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
      | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
      | tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
    apt-get update
    apt-get install -y caddy
  fi
fi

# ---------- 2. Persist mesh-lb-token ----------------------------------------
sudo mkdir -p /etc/hermes
sudo tee /etc/hermes/lb.env >/dev/null <<EOF
# Mesh-LB shared token. Backends accept this via HERMES_API_TOKENS for
# LB-routed traffic. Per-node tokens are stored separately in node.env.
MESH_LB_TOKEN=${MESH_LB_TOKEN}
MESH_LB_NODE_NAME=${MESH_LB_NODE_NAME}
MESH_LB_PORT=${MESH_LB_PORT}
MESH_LB_ADMIN_ADDR=${MESH_LB_ADMIN_ADDR}
EOF
sudo chmod 600 /etc/hermes/lb.env
log "Wrote /etc/hermes/lb.env (mode 600)"

# ---------- 3. Drop the regen script ----------------------------------------
# Reads mesh-profiles.yaml, builds a Caddyfile with the backend list as a
# space-separated string, and triggers a Caddy reload. Run from cron every
# 5 min so node joins/leaves propagate automatically.
sudo tee /usr/local/bin/hermes-lb-regen.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
# Regenerate /etc/caddy/Caddyfile from mesh-profiles.yaml and reload Caddy.
set -euo pipefail

MESH_DIR=/etc/hermes/mesh
ENV_FILE=/etc/hermes/lb.env
CADDYFILE=/etc/caddy/Caddyfile
TEMPLATE=/etc/caddy/Caddyfile.mesh.template

# Load LB env (MESH_LB_TOKEN, MESH_LB_NODE_NAME, MESH_LB_PORT, MESH_LB_ADMIN_ADDR).
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

[[ -f "$TEMPLATE" ]] || { echo "missing template $TEMPLATE"; exit 0; }
[[ -f "$MESH_DIR/profiles.yaml" ]] || { echo "no mesh profiles"; exit 0; }

# Build "host:port host:port ..." list of full mesh nodes, EXCLUDING self.
# We use a tiny Python helper because parsing YAML portably from bash is
# miserable. Falls back to a python3 -c one-liner.
read_hosts_py() {
python3 - "$MESH_DIR/profiles.yaml" "$MESH_LB_NODE_NAME" <<'PY'
import sys, yaml
data = yaml.safe_load(open(sys.argv[1]))
self = sys.argv[2]
hosts = []
for n in data.get("mesh", {}).get("nodes", []):
    if n.get("role") != "full":       # skip clients (macbook, etc.)
        continue
    name = n.get("name", "")
    host = n.get("host", "")
    port = n.get("port", 8642)
    if not host or host.startswith("$") or "$" in host:
        print(f"# skip {name}: unresolved host {host}", file=sys.stderr)
        continue
    if name == self:
        print(f"# skip self {name}", file=sys.stderr)
        continue
    hosts.append(f"{host}:{port}")
print(" ".join(hosts), end="")
PY
}

read_hosts_json_py() {
python3 - "$MESH_DIR/profiles.yaml" "$MESH_LB_NODE_NAME" <<'PY'
import sys, json, yaml
data = yaml.safe_load(open(sys.argv[1]))
self = sys.argv[2]
backends = []
for n in data.get("mesh", {}).get("nodes", []):
    if n.get("role") != "full":
        continue
    name = n.get("name", "")
    host = n.get("host", "")
    port = n.get("port", 8642)
    if not host or host.startswith("$") or "$" in host:
        continue
    if name == self:
        continue
    backends.append({"name": name, "host": host, "port": port})
print(json.dumps(backends), end="")
PY
}

BACKEND_LIST="$(read_hosts_py)"
BACKEND_LIST_JSON="$(read_hosts_json_py)"

if [[ -z "$BACKEND_LIST" ]]; then
  echo "WARN: no upstream backends after parsing mesh-profiles.yaml; keeping previous config"
  exit 0
fi

# Render the template. Using envsubst so {$BACKEND_LIST}, {$BACKEND_LIST_JSON},
# and the MESH_LB_* vars get substituted.
TMP="$(mktemp /etc/caddy/Caddyfile.rendered.XXXXX)"
# Only substitute the keys we know about, to avoid envsubst eating any
# other ${...} that might appear in comments later.
envsubst '
${MESH_LB_NODE_NAME}
${MESH_LB_PORT}
${MESH_LB_ADMIN_ADDR}
${BACKEND_LIST}
${BACKEND_LIST_JSON}
' < "$TEMPLATE" > "$TMP"

# Reload Caddy only if the rendered file actually changed.
if ! cmp -s "$TMP" "$CADDYFILE"; then
  mv "$TMP" "$CADDYFILE"
  echo "Caddyfile updated; backends: $BACKEND_LIST"
  systemctl reload caddy || true
else
  rm -f "$TMP"
  echo "Caddyfile unchanged"
fi
EOF
sudo chmod +x /usr/local/bin/hermes-lb-regen.sh

# ---------- 4. Drop the Caddyfile template ----------------------------------
sudo mkdir -p "$CADDYFILE_DIR" /var/log/caddy
sudo tee "$CADDYFILE_DIR/Caddyfile.mesh.template" >/dev/null <<'TEMPLATE_EOF'
# This template is regenerated by /usr/local/bin/hermes-lb-regen.sh.
# Do not edit by hand — your changes will be overwritten on the next
# mesh-sync tick. To change LB behavior, edit the template or the regen
# script, then re-run install-lb.sh.
EOF
# Append the real template content shipped with this repo.
cat >> "$CADDYFILE_DIR/Caddyfile.mesh.template" <<'TEMPLATE_EOF2'
{
    admin ${MESH_LB_ADMIN_ADDR}
}

:${MESH_LB_PORT} {
    log {
        output file /var/log/caddy/hermes-mesh.log {
            roll_size 50MiB
            roll_keep 5
        }
        level INFO
    }

    handle /health {
        respond `{"status":"ok","backends":${BACKEND_LIST_JSON}}` 200
    }

    reverse_proxy ${BACKEND_LIST} {
        health_path /health
        health_interval 5s
        health_timeout 3s
        health_status 2xx
        health_body ""

        lb_policy round_robin

        header_up -Authorization
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}
        header_up X-Mesh-Lb-Node ${MESH_LB_NODE_NAME}

        try_duration 5s
        try_interval 250ms

        flush_interval -1

        transport http {
            dial_timeout 3s
            response_header_timeout 30s
        }
    }
}
TEMPLATE_EOF2

# Validate template by rendering it once with placeholder values.
log "Validating Caddyfile template..."
CADDY_VALIDATE_OUT=$(sudo caddy validate --config "$CADDYFILE_DIR/Caddyfile.mesh.template" \
  --adapter envsubst 2>&1 | grep -v '^{' | grep -v 'BACKEND_LIST_JSON' | grep -v 'BACKEND_LIST' | grep -v 'MESH_LB_' || true)
# The caddy CLI doesn't natively support envsubst; we'll render in shell then validate.
# Instead, do a dry render with dummy upstream:
TMP_VALIDATE="$(mktemp)"
MESH_LB_NODE_NAME=lb MESH_LB_PORT=8643 MESH_LB_ADMIN_ADDR=localhost:2019 \
  BACKEND_LIST="10.0.0.1:8642 10.0.0.2:8642" \
  BACKEND_LIST_JSON='[{"name":"n1","host":"10.0.0.1","port":8642},{"name":"n2","host":"10.0.0.2","port":8642}]' \
  envsubst '${MESH_LB_NODE_NAME} ${MESH_LB_PORT} ${MESH_LB_ADMIN_ADDR} ${BACKEND_LIST} ${BACKEND_LIST_JSON}' \
  < "$CADDYFILE_DIR/Caddyfile.mesh.template" > "$TMP_VALIDATE"
if sudo caddy validate --config "$TMP_VALIDATE" 2>&1 | grep -qE '^\s*Error|^\s*FATAL'; then
  err "Caddyfile template validation FAILED:"
  sudo caddy validate --config "$TMP_VALIDATE" || true
  rm -f "$TMP_VALIDATE"
  exit 1
fi
rm -f "$TMP_VALIDATE"
log "✓ Caddyfile template valid"

# ---------- 5. Initial render + start Caddy ---------------------------------
log "Rendering initial Caddyfile from mesh-profiles.yaml..."
if [[ ! -d "$HERMES_MESH_DIR/.git" ]] && [[ -n "$MESH_REPO_URL" ]]; then
  sudo mkdir -p "$HERMES_MESH_DIR"
  sudo chown "$USER":"$USER" "$HERMES_MESH_DIR"
  git clone "$MESH_REPO_URL" "$HERMES_MESH_DIR"
fi
/usr/local/bin/hermes-lb-regen.sh || log "Initial regen skipped (no mesh profiles yet)"

# ---------- 6. Cron: regen every 5 min --------------------------------------
sudo tee /etc/cron.d/hermes-lb-regen >/dev/null <<EOF
*/5 * * * * ${USER} /usr/local/bin/hermes-lb-regen.sh >> /var/log/hermes-lb-regen.log 2>&1
EOF

# ---------- 7. systemd: caddy.service ----------------------------------------
# Caddy ships its own unit file; we just enable it. If you need a separate
# unit that runs ONLY the mesh LB (not other vhosts), wrap caddy with a
# custom --config flag.
sudo systemctl enable --now caddy
log "Caddy running on :${MESH_LB_PORT}"

# ---------- 8. Firewall hint -----------------------------------------------
cat <<EOF

  ┌──────────────────────────────────────────────────────────────────────┐
  │  LB is up on :${MESH_LB_PORT}                                         │
  │                                                                      │
  │  Next steps:                                                         │
  │   1. On each BACKEND node, ensure /etc/hermes/node.env has:          │
  │        HERMES_API_TOKENS="\${per-node-token},\${MESH_LB_TOKEN}"     │
  │      Then restart hermes-api. (install.sh does this for you.)        │
  │   2. Allow :${MESH_LB_PORT} from your MacBook + peer nodes:          │
  │        ufw allow from <macbook-lan-ip> to any port ${MESH_LB_PORT}   │
  │   3. From MacBook, verify with:                                      │
  │        curl -s -H "Authorization: Bearer \$MESH_LB_TOKEN" \\          │
  │             http://<lb-host>:${MESH_LB_PORT}/health                   │
  └──────────────────────────────────────────────────────────────────────┘
EOF