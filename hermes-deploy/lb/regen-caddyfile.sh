#!/usr/bin/env bash
# ============================================================================
# hermes-lb-regen.sh
#
# Regenerates /etc/caddy/Caddyfile from mesh-profiles.yaml and reloads
# Caddy. Cron entry: every 5 minutes.
#
# Reads /etc/hermes/lb.env for MESH_LB_TOKEN, MESH_LB_NODE_NAME,
# MESH_LB_PORT, MESH_LB_ADMIN_ADDR. Reads /etc/hermes/mesh/profiles.yaml
# for the upstream node list. Excludes the LB node itself from upstreams
# (it serves local traffic directly, not through the LB).
# ============================================================================
set -euo pipefail

MESH_DIR=/etc/hermes/mesh
ENV_FILE=/etc/hermes/lb.env
TEMPLATE=/etc/caddy/Caddyfile.mesh.template
CADDYFILE=/etc/caddy/Caddyfile

# Load LB env.
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [[ ! -f "$TEMPLATE" ]]; then
  echo "WARN: missing template $TEMPLATE — run install-lb.sh first"
  exit 0
fi
if [[ ! -f "$MESH_DIR/profiles.yaml" ]]; then
  echo "WARN: no mesh profiles at $MESH_DIR/profiles.yaml — keeping current config"
  exit 0
fi

# Parse profiles.yaml → space-separated "host:port" list of full nodes,
# excluding this LB node. Done in Python because portable YAML parsing
# from bash is a tar pit.
BACKEND_LIST="$(python3 - "$MESH_DIR/profiles.yaml" "$MESH_LB_NODE_NAME" <<'PY'
import sys, yaml
data = yaml.safe_load(open(sys.argv[1]))
self = sys.argv[2]
hosts = []
for n in data.get("mesh", {}).get("nodes", []):
    if n.get("role") != "full":
        continue
    name = n.get("name", "")
    host = n.get("host", "")
    port = n.get("port", 8642)
    if not host or "$" in host:
        print(f"# skip {name}: unresolved host {host}", file=sys.stderr)
        continue
    if name == self:
        print(f"# skip self {name}", file=sys.stderr)
        continue
    hosts.append(f"{host}:{port}")
print(" ".join(hosts), end="")
PY
)"

BACKEND_LIST_JSON="$(python3 - "$MESH_DIR/profiles.yaml" "$MESH_LB_NODE_NAME" <<'PY'
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
    if not host or "$" in host:
        continue
    if name == self:
        continue
    backends.append({"name": name, "host": host, "port": port})
print(json.dumps(backends), end="")
PY
)"

if [[ -z "$BACKEND_LIST" ]]; then
  echo "WARN: no upstream backends after parsing profiles.yaml; keeping current config"
  exit 0
fi

# Render template. Only substitute known keys.
TMP="$(mktemp /etc/caddy/Caddyfile.rendered.XXXXX)"
envsubst '
${MESH_LB_NODE_NAME}
${MESH_LB_PORT}
${MESH_LB_ADMIN_ADDR}
${BACKEND_LIST}
${BACKEND_LIST_JSON}
' < "$TEMPLATE" > "$TMP"

if ! cmp -s "$TMP" "$CADDYFILE"; then
  mv "$TMP" "$CADDYFILE"
  echo "Caddyfile updated; backends: $BACKEND_LIST"
  systemctl reload caddy 2>/dev/null || true
else
  rm -f "$TMP"
  echo "Caddyfile unchanged"
fi