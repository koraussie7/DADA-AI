#!/usr/bin/env bash
# ============================================================================
# Hermes Agent + hermes-desktop on macOS (MacBook)
#
# NOTE: hermes-desktop does NOT ship a signed macOS .dmg (only Windows + Fedora
# are officially released). This script builds the .app from source via
# electron-builder. The resulting bundle will be unsigned; first launch
# requires right-click → Open to bypass Gatekeeper, or:
#   xattr -dr com.apple.quarantine /Applications/Hermes\ Desktop.app
#
# MacBook is `role: client` in the mesh — it is NOT in the LB upstream pool,
# but it does need the per-node tokens + mesh-LB token to talk to backends.
# If MESH_REPO_URL is set, we clone the mesh repo and read tokens from
# profiles.yaml. Otherwise you pass them inline.
# ============================================================================
set -euo pipefail

: "${HERMES_NODE_NAME:=$(scutil --get LocalHostName 2>/dev/null || hostname -s)}"
: "${HERMES_MESH_DIR:=$HOME/.hermes/mesh}"
: "${HERMES_DATA_DIR:=$HOME/.hermes}"
: "${HERMES_PORT:=8642}"
: "${ALLROUTER_BASE_URL:=https://api.privseai.com/v1}"
: "${ALLROUTER_API_KEY:?Set ALLROUTER_API_KEY in env or .env file}"
: "${MESH_REPO_URL:=}"
: "${MESH_LB_TOKEN:=}"                              # shared token for LB-routed traffic

log() { printf '\033[1;34m[hermes-mac]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[hermes-mac]\033[0m %s\n' "$*" >&2; }

# ---------- 1. Pre-flight: brew + node + bun --------------------------------
if ! command -v brew >/dev/null 2>&1; then
  err "Homebrew not found. Install from https://brew.sh first."
  exit 1
fi
for pkg in node git bun; do
  if ! command -v "$pkg" >/dev/null 2>&1; then
    log "Installing $pkg via brew..."
    brew install "$pkg"
  fi
done

# ---------- 2. Hermes Agent CLI --------------------------------------------
if ! command -v hermes >/dev/null 2>&1; then
  log "Installing Hermes Agent CLI..."
  curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/install.sh | bash
fi

# ---------- 3. Clone + build hermes-desktop from source ---------------------
DESKTOP_DIR="$HOME/code/hermes-desktop"
mkdir -p "$(dirname "$DESKTOP_DIR")"
if [[ ! -d "$DESKTOP_DIR" ]]; then
  log "Cloning hermes-desktop..."
  git clone --depth=1 https://github.com/koraussie7/hermes-desktop.git "$DESKTOP_DIR"
fi
cd "$DESKTOP_DIR"
log "Installing deps + building .app..."
npm ci
npm run build:mac   # produces dist/mac-arm64/Hermes Desktop.app

APP_PATH="$(ls -d dist/mac-*/Hermes\ Desktop.app | head -1)"
if [[ -z "$APP_PATH" ]]; then
  err "Build did not produce .app bundle. Check npm output."
  exit 1
fi

log "Installing to /Applications..."
rm -rf "/Applications/Hermes Desktop.app"
cp -R "$APP_PATH" "/Applications/"
xattr -dr com.apple.quarantine "/Applications/Hermes Desktop.app" 2>/dev/null || true

# ---------- 3.5. daedalOS desktop (Docker) ---------------------------------
# Self-hosted browser-side desktop (https://dustinbrett.com/) embedded by the
# Desktop tab. Image: ~2-3 GB (Playwright + Chromium). Browser-side state via
# BrowserFS + IndexedDB — no volume. Pull is best-effort; container start
# happens unconditionally so a transient pull failure recovers on next run.
DAEDAL_IMAGE="${DAEDAL_IMAGE:-dustinbrett/daedalos:latest}"
DAEDAL_PORT="${DAEDAL_PORT:-3030}"
if command -v docker >/dev/null 2>&1; then
  log "Pulling daedalOS ($DAEDAL_IMAGE)..."
  docker pull --platform linux/amd64 "$DAEDAL_IMAGE" || log "  (pull failed; will retry on next installer run)"
  if ! docker ps -a --format '{{.Names}}' | grep -qx daedalos; then
    log "Launching daedalOS on :$DAEDAL_PORT..."
    docker run -d --platform linux/amd64 --name daedalos \
      --restart unless-stopped -p "${DAEDAL_PORT}:3000" "$DAEDAL_IMAGE"
  else
    log "daedalos container exists; starting if stopped"
    docker start daedalos 2>/dev/null || true
  fi
else
  log "WARN: docker not installed; Desktop tab will be empty until daedalOS is started manually"
fi


# ---------- 3.6. peerd Chromium extension (Browser-in-Hermes) --------------
PEERD_HOME="${PEERD_HOME:-$HOME/.hermes}"
PEERD_REPO="${PEERD_REPO:-https://github.com/NotASithLord/peerd.git}"
PEERD_REF="${PEERD_REF:-}"  # pin a specific rev when validating; leave blank for HEAD
PEERD_LAUNCHER="${HERMES_DEPLOY_DIR:-$HOME/orca/workspaces/DADA-AI/ridley/hermes-deploy}/daedal/launch-peerd.sh"
log "Installing peerd browser extension (unpacked, ~3 MB)..."
if [[ -x "$PEERD_LAUNCHER" ]]; then
  if [[ -n "$PEERD_REF" ]]; then
    bash "$PEERD_LAUNCHER" --pin "$PEERD_REF" || log "  (peerd install failed; Peerd tab will be empty until fixed)"
  else
    bash "$PEERD_LAUNCHER" || log "  (peerd install failed; Peerd tab will be empty until fixed)"
  fi
  # Make PEERD_DIR available to the launchd plist (main process reads it).
  /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:PEERD_DIR string ${PEERD_HOME}/peerd/extension"     "$LAUNCHD_PLIST_PATH" 2>/dev/null ||   /usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:PEERD_DIR ${PEERD_HOME}/peerd/extension"     "$LAUNCHD_PLIST_PATH"
else
  log "WARN: launch-peerd.sh not found at $PEERD_LAUNCHER; Peerd tab will be empty"
fi
# ---------- 4. Allrouter env (Stainless bypass) -----------------------------
mkdir -p "$HOME/.hermes" "$HERMES_MESH_DIR"
cat > "$HOME/.hermes/allrouter.env" <<EOF
ALLROUTER_BASE_URL=${ALLROUTER_BASE_URL}
ALLROUTER_API_KEY=${ALLROUTER_API_KEY}
OPENAI_BASE_URL=${ALLROUTER_BASE_URL}
OPENAI_API_KEY=${ALLROUTER_API_KEY}
HERMES_LLM_USER_AGENT=openai-node
HERMES_LLM_DEFAULT_HEADERS='{"User-Agent":"openai-node","X-Stainless-Os":"Darwin","X-Stainless-Arch":"arm64","X-Stainless-Package-Version":"1.0.0","X-Stainless-Runtime":"node","X-Stainless-Runtime-Version":"20.0.0"}'
# Smart-router wire-up: hermes-agent -> node110 mesh-LB /llm -> smart-router :4001
# (keirouter-fallback aware; same path validated by 06-smoke-test.sh on node110).
OPENAI_BASE_URL=https://node110.privseai.com:8643/llm/v1
OPENAI_API_KEY=not-used
SMART_ROUTER_URL=https://node110.privseai.com:8643/llm
HERMES_DAEDAL_URL=http://localhost:3030
HERMES_LLM_TRAFFIC_VIA_SMART_ROUTER=true
EOF
chmod 600 "$HOME/.hermes/allrouter.env"

# ---------- 5. Per-node + mesh-LB tokens (client-side, MacBook) -------------
# MacBook stores ALL node tokens + mesh-LB token in ~/.hermes/tokens.env
# so the desktop app / CLI can pick the right one based on which backend
# it's talking to.
TOKENS_FILE="$HOME/.hermes/tokens.env"
if [[ -n "$MESH_REPO_URL" ]] && [[ ! -d "$HERMES_MESH_DIR/.git" ]]; then
  log "Cloning mesh profile repo for token discovery..."
  git clone "$MESH_REPO_URL" "$HERMES_MESH_DIR"
fi

# Read per-node tokens from profiles.yaml if present.
python3 - "$HERMES_MESH_DIR/profiles.yaml" "$TOKENS_FILE" "$MESH_LB_TOKEN" <<'PY' || true
import sys, os, yaml
profile_path, out_path, lb_token = sys.argv[1], sys.argv[2], sys.argv[3]
if not os.path.exists(profile_path):
    sys.exit(0)
data = yaml.safe_load(open(profile_path))
lines = ["# Mesh API tokens. mode 0600. Generated by install-macos.sh.", ""]
for n in data.get("mesh", {}).get("nodes", []):
    name = n.get("name", "")
    host = n.get("host", "")
    token = n.get("api_token", "")  # optional inline (gitignored profiles.local.yaml)
    if token:
        lines.append(f"# {name} ({host})")
        lines.append(f"MESH_TOKEN_{name.upper()}={token}")
        lines.append("")
if lb_token:
    lines.append("# Mesh LB shared token")
    lines.append(f"MESH_LB_TOKEN={lb_token}")
    lines.append("")
with open(out_path, "w") as f:
    f.write("\n".join(lines))
PY
chmod 600 "$TOKENS_FILE"
log "Wrote $TOKENS_FILE"

if [[ -n "$MESH_LB_TOKEN" ]]; then
  # MacBook Hermes desktop may also bind its own :8642 — accept the LB
  # token so the LB can call back if needed (rare).
  cat >> "$TOKENS_FILE" <<EOF
HERMES_API_TOKEN=
HERMES_API_TOKENS=${MESH_LB_TOKEN}
EOF
fi

ln -sf "$HOME/.hermes/allrouter.env" "$HERMES_DATA_DIR/.env"
ln -sf "$TOKENS_FILE" "$HERMES_DATA_DIR/tokens.env" 2>/dev/null || true

# ---------- 6. Mesh profile clone ------------------------------------------
if [[ -n "$MESH_REPO_URL" ]] && [[ ! -d "$HERMES_MESH_DIR/.git" ]]; then
  git clone "$MESH_REPO_URL" "$HERMES_MESH_DIR"
fi

# ---------- 7. launchd plist for Hermes API daemon --------------------------
PLIST_PATH="$HOME/Library/LaunchAgents/com.hermes.api.plist"
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.hermes.api</string>
  <key>ProgramArguments</key>
  <array>
    <string>$(command -v hermes)</string>
    <string>serve</string>
    <string>--host</string><string>0.0.0.0</string>
    <string>--port</string><string>${HERMES_PORT}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>ALLROUTER_BASE_URL</key><string>${ALLROUTER_BASE_URL}</string>
    <key>ALLROUTER_API_KEY</key><string>${ALLROUTER_API_KEY}</string>
    <key>HERMES_LLM_USER_AGENT</key><string>openai-node</string>
    <key>OPENAI_BASE_URL</key><string>https://node110.privseai.com:8643/llm/v1</string>
    <key>SMART_ROUTER_URL</key><string>https://node110.privseai.com:8643/llm</string>
    <key>HERMES_DAEDAL_URL</key><string>http://localhost:3030</string>
    <key>HERMES_LLM_TRAFFIC_VIA_SMART_ROUTER</key><string>true</string>
    <key>HERMES_NODE_NAME</key><string>${HERMES_NODE_NAME}</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/hermes-api.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/hermes-api.err.log</string>
</dict>
</plist>
EOF
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load -w "$PLIST_PATH"
log "launchd daemon loaded: $PLIST_PATH"

cat <<EOF

  ┌──────────────────────────────────────────────────────────────────────┐
  │  MacBook Hermes desktop installed.                                   │
  │                                                                      │
  │  Tokens file: $TOKENS_FILE (mode 600)                                 │
  │    MESH_TOKEN_NODE110=<token-for-direct-access>                      │
  │    MESH_TOKEN_NODE91=<token-for-direct-access>                       │
  │    MESH_TOKEN_NODE97=<token-for-direct-access>                       │
  │    MESH_LB_TOKEN=$(if [[ -n "$MESH_LB_TOKEN" ]]; then echo "set"; else echo "unset"; fi)                                                       │
  │                                                                      │
  │  Use the LB token for round-robin traffic:                            │
  │    curl -H "Authorization: Bearer \$MESH_LB_TOKEN" \\                │
  │         http://<lb-host>:8643/health                                  │
  │                                                                      │
  │  Use a per-node token for direct admin access:                        │
  │    curl -H "Authorization: Bearer \$MESH_TOKEN_NODE110" \\            │
  │         http://<node110-host>:8642/health                             │
  └──────────────────────────────────────────────────────────────────────┘
EOF
