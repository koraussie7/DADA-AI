# Hermes Mesh Deployment

Self-hosted Hermes Agent + hermes-desktop installed on:
- **3 Linux servers** (IPs starting with 110, 91, 97 — replace placeholders)
- **1 MacBook** (you)

Architecture:

```
                       MESH_LB_TOKEN (shared)
   MacBook  ─────────────────────────────────────►  LB (Caddy on node110:8643)
   direct:                                             │
   MESH_TOKEN_NODE110                                  ▼
   MESH_TOKEN_NODE91                          round-robin + health-check
   MESH_TOKEN_NODE97                                │  │  │
                                                     ▼  ▼  ▼
                                              node110 node91 node97
                                              :8642  :8642  :8642
                                              (each accepts per-node
                                               token + MESH_LB_TOKEN)
```

All four nodes run their own Hermes API backend on `:8642`. They share
config via a git-tracked `mesh-profiles.yaml` (pull every 5 min via cron
/ launchd). All LLM traffic routes through **allrouter**
(`https://api.privseai.com/v1`) with the Stainless fingerprint bypass
headers so 403s are avoided.

The MacBook's `hermes-agent` also talks to the node110 mesh-LB at
`/llm/v1`, which Caddy strips down to `:4001` (smart-router) → keirouter
fallback. See `lb/Caddyfile` handle `/llm/*`. The MacBook-side Desktop
tab embeds daedalOS — see [`daedal/README.md`](daedal/README.md).

## Files

| File | Purpose |
|---|---|
| `install.sh` | Linux installer (Fedora/RHEL family + Ubuntu). Generates per-node API token; drops HERMES_DAEDAL_URL + SMART_ROUTER_* env (informational; consumed by MacBook). |
| `install-macos.sh` | macOS installer (builds .app from source — no signed .dmg exists upstream; also pulls daedalOS for the Desktop tab and wires hermes-agent → smart-router → keirouter fallback via mesh-LB /llm). Reads node tokens from mesh config. |
| `mesh-profiles.yaml` | Shared node config + LB section; lives in a git repo, all nodes pull |
| `allrouter-patch.py` | Verify allrouter Stainless bypass + per-node/LB token wiring |
| `lb/Caddyfile` | Caddy LB config (auto-rendered from `mesh-profiles.yaml`) |
| `lb/install-lb.sh` | Linux installer for the designated LB host (typically one of the 3 nodes) |
| `lb/regen-caddyfile.sh` | Re-renders Caddyfile from `mesh-profiles.yaml` on the LB host (cron 5min) |
| `daedal/launch-daedal.sh` | Idempotent launcher for the daedalOS Docker container (Desktop tab) |
| `daedal/README.md` | Runbook for the daedalOS embed |

## One-time setup per server (backend node)

```bash
# Required:
export ALLROUTER_API_KEY='sk-...your-key...'

# Optional but recommended:
export MESH_REPO_URL='git@github.com:yourorg/hermes-mesh.git'
export MESH_LB_TOKEN='<shared-token-for-LB-traffic>'

bash install.sh
```

The installer:
1. Installs Hermes Agent CLI (NousResearch)
2. Clones + builds hermes-desktop (Electron) → installs system package
3. Writes `/etc/hermes/allrouter.env` with Stainless-bypass headers (mode 0600)
4. **Generates a per-node API token** at `/etc/hermes/node.token` (mode 0600)
5. Writes `/etc/hermes/node.env` with `HERMES_API_TOKEN` + `HERMES_API_TOKENS`
   (per-node + mesh-LB tokens, comma-separated)
6. Sets up systemd unit `hermes-api.service` on `:8642`
7. Adds cron job `/etc/cron.d/hermes-mesh-sync` for profile sync

The per-node token is unique to that host. Use it for direct admin
access; the mesh-LB token is shared and accepted on all backends for
LB-routed traffic.

## One-time setup on the LB host (typically one of the 3 nodes)

```bash
# On node110 (or whichever node is `lb.node` in mesh-profiles.yaml):
export MESH_LB_TOKEN='<same-shared-token-as-on-backends>'
export MESH_REPO_URL='git@github.com:yourorg/hermes-mesh.git'

bash lb/install-lb.sh
```

The LB installer:
1. Installs Caddy (Fedora COPR or Debian apt repo)
2. Writes `/etc/hermes/lb.env` with `MESH_LB_TOKEN` (mode 0600)
3. Drops the Caddyfile template at `/etc/caddy/Caddyfile.mesh.template`
4. Drops the regen script `/usr/local/bin/hermes-lb-regen.sh`
5. Renders the initial Caddyfile from `mesh-profiles.yaml`
6. Sets up cron `*/5 * * * *` to regenerate + reload Caddy on mesh changes
7. Starts Caddy on `:8643` (configurable via `MESH_LB_PORT`)

The Caddy LB:
- **Round-robin** across healthy backend nodes (`lb_policy round_robin`)
- **Active health checks** on `/health` every 5s; 3 misses → remove from pool
- **Strips client Authorization** before forwarding — backends validate
  against their own `HERMES_API_TOKENS` (per-node + mesh-LB)
- **Caddyfile auto-regenerates** when `mesh-profiles.yaml` changes via git
  pull — adding/removing a node propagates within ~5 minutes, no manual
  reload needed

## One-time setup on MacBook (client)

```bash
# Required:
export ALLROUTER_API_KEY='sk-...your-key...'

# Required so the MacBook can authenticate to each backend:
export MESH_TOKEN_NODE110='<per-node-token-from-node110>'
export MESH_TOKEN_NODE91='<per-node-token-from-node91>'
export MESH_TOKEN_NODE97='<per-node-token-from-node97>'

# Optional — only needed if you talk to the LB:
export MESH_LB_TOKEN='<shared-token>'

export MESH_REPO_URL='git@github.com:yourorg/hermes-mesh.git'

bash install-macos.sh
```

The macOS installer:
1. Installs Hermes Agent CLI
2. **Builds** `Hermes Desktop.app` from source (no signed .dmg upstream)
3. Writes `~/.hermes/allrouter.env` (Stainless bypass)
4. **Reads per-node tokens from `mesh-profiles.yaml`** and writes
   `~/.hermes/tokens.env` with `MESH_TOKEN_NODE110`, etc.
5. Loads `~/Library/LaunchAgents/com.hermes.api.plist` so :8642 boots at login

## Mesh sync

Profiles live in a git repo (the one in `MESH_REPO_URL`). To push a config
change to all nodes:

```bash
cd $HERMES_MESH_DIR   # /etc/hermes/mesh on Linux, ~/.hermes/mesh on mac
$EDITOR profiles.yaml
git commit -am "rotate LLM to claude-opus-5"
git push
```

Other nodes pull within 5 minutes and reload hermes-api. The LB host
additionally regenerates its Caddyfile on every pull, so adding or
removing a backend node propagates without manual intervention.

## Verifying allrouter + tokens

After install on any node:

```bash
python3 allrouter-patch.py --check    # validate allrouter + per-node tokens
python3 allrouter-patch.py --apply    # probe api.privseai.com/v1/models
python3 allrouter-patch.py --tokens   # only check the token wiring
```

Expected: `✓ Allrouter config looks correct` + `✓ API token config looks correct`.

## Verifying the LB

From the LB host:
```bash
systemctl status caddy
curl -s http://localhost:8643/health
# {"status":"ok","backends":[{"name":"node91","host":"91.x.x.x","port":8642},...]}
```

From the MacBook:
```bash
curl -s -H "Authorization: Bearer $MESH_LB_TOKEN" http://node110:8643/health
```

Direct backend probe (per-node token):
```bash
curl -s -H "Authorization: Bearer $MESH_TOKEN_NODE91" http://91.x.x.x:8642/health
```

## Security notes

- **Allrouter API key** is stored in `/etc/hermes/allrouter.env` (mode 0600)
  and `~/.hermes/allrouter.env` on macOS. Never commit these.
- **Per-node API tokens** live in `/etc/hermes/node.token` (mode 0600) on
  each server. Never commit. The MacBook keeps its copy of all three in
  `~/.hermes/tokens.env` (mode 0600).
- **Mesh-LB token** is shared between the LB host and all backends. It
  grants LB-routed access only — not admin. Rotate by updating
  `/etc/hermes/lb.env` on the LB host and `/etc/hermes/node.env` on each
  backend (so the new token ends up in their `HERMES_API_TOKENS`).
- The Stainless bypass works because the OpenAI SDK sends a
  fingerprintable User-Agent by default; we override to `openai-node`
  which allrouter accepts.
- hermes-desktop is unsigned on macOS — first launch needs right-click → Open
  or `xattr -dr com.apple.quarantine`.
- hermes-desktop on Linux is also unsigned (`--nogpgcheck` may be needed).
- All nodes bind Hermes API on `0.0.0.0:8642` and the LB on `:8643` — restrict
  with firewall (ufw / nftables / macOS Application Firewall) to your mesh
  IPs only. Never expose `:8642` to the public internet; expose the LB
  (`:8643`) instead so you keep the auth wall in front.
- The LB strips `Authorization` before forwarding — clients cannot smuggle
  a per-node token through the LB to escalate access on a different
  backend. Use direct addresses + per-node tokens for admin.
