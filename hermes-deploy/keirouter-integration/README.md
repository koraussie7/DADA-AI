# keirouter × smart-router — Unstoppable Fallback Node Integration

## Goal

smart-router (FastAPI :4001 on node110, :14001 on node97) exhausted every LiteLLM candidate →
fall back to keirouter chain:* (:20180) before returning 503.
keirouter adds 15 pre-configured providers including OAuth (Kiro /
kilocode / kimi-coding) that allrouter cannot reach.

## Architecture

```
L5  Hermes Mesh-LB          node110 / node91 / node97
L4  smart-router            FastAPI :4001 (node110) / :14001 (node97)  ← adds keirouter:chain:* to candidate tail
L3a allrouter / LiteLLM     :4003          (current — 243 aliases + groq-* fallbacks)
L3b keirouter               :20180         (NEW tier — chain:fast-fallback / coding-heavy)
L2  Providers               Groq, OpenRouter, NVIDIA, TokenRouter, Kiro, Kimi, ...
L1  OAuth providers         keirouter-only (Kiro, kilocode, kimi-coding)
```

## Dispatch rule

smart-router's `_post_once()` (app.py) routes by model-name prefix:

```python
if mdl.startswith("keirouter:chain:"):
    chain_name = mdl[len("keirouter:chain:"):]
    return await client.post(f"{config['keirouter_url']}/v1/chat/completions",
                             json={**bdy, "model": f"chain:{chain_name}"},
                             headers={"Authorization": f"Bearer {config['keirouter_key']}",
                                      "Content-Type": "application/json"})
return await client.post(f"{config['allrouter_url']}/v1/chat/completions", ...)
```

`keirouter:chain:fast-fallback` and `keirouter:chain:coding-heavy` are
appended to `candidate_models()` (router_logic.py) as the final fallback
tier after the LiteLLM fast/slow pools are exhausted.

## Admin endpoints

Three new endpoints on smart-router (`app.py`) let operators (and the
smoke test) mark models as failing without spamming parallel requests.

| Method | Path | Body / Query | Auth |
|--------|------|--------------|------|
| `POST` | `/admin/mark-failing` | `{"model": "...", "ttl_seconds": 300, "reason": "..."}` | optional `X-Admin-Token` if `config.admin_token` set |
| `POST` | `/admin/clear-failing` | `{"model": "..."}` | same |
| `GET`  | `/admin/failing` | — | open |

Mark-failing writes directly to `smart_router.failure_until[model]`,
which `select_model()` and `candidate_models()` consult to filter the
chain. The TTL defaults to 300s (5 min), matching the internal
`failure_ttl_seconds` default. `GET /admin/failing` returns the
remaining TTL per model and lazily pops expired entries.

`08-patch-admin-endpoint.py` is idempotent — re-running it prints
`OK /admin/failing already present` and exits 0.

## Why the existing `_is_failing()` machinery needed two fixes

`router_logic.py` already had `_is_failing()` and `failure_until`, but
two latent bugs prevented admin marks from affecting the chain:

1. `select_model()` cleared `failure_until` whenever the entire pool
   was in cooldown, wiping admin marks on the next request.
2. `candidate_models()` defined a `_live()` helper but never called
   it — `primary_pool_live` and `secondary_pool_live` were just
   shuffled copies of the full pool, so failing models stayed in the
   chain and wasted a round-trip per model before the keirouter tier
   fired.
3. `_live()` itself returned `live or pool`, so when every model was
   failing it still returned the full pool — silently undoing any
   filtering.

`09-patch-failing-filter.py` fixes all three:
- `select_model` now uses `pool[:1]` (the first pool member) as a
  head when live_pool is empty, instead of clearing admin marks.
- `candidate_models` now calls `_live()` on both pools before
  shuffling, dropping failing models from the chain.
- `_live()` returns only the filtered list, with no fallback.

## Files

| File | Purpose | Where it runs |
|------|---------|---------------|
| `01-save-keirouter-key.sh` | Atomically write keirouter API key to `/etc/hermes/keirouter.env` (mode 0600) | node110 |
| `02-new-config.json` | New `/opt/smart-router/config.json` with keirouter section | node110 |
| `03-patch-app.py.py` | Patches `app.py` `_post_once()` to dispatch `keirouter:chain:*` to keirouter | node110 |
| `04-patch-router-logic.py` | Patches `router_logic.py` `candidate_models()` to append keirouter virtual model as final candidate | node110 |
| `05-create-chains.sh` | Creates `coding-heavy` and `fast-fallback` chains via keirouter dashboard (login with password, then POST /api/chains with session cookie) | node110 |
| `06-smoke-test.sh` | End-to-end verification (7 scenarios A–G) — baseline / keirouter direct / chain / LiteLLM exhaustion via admin marks / admin round-trip / keirouter-down 503 | node110 |
| `06-smoke-test-node97.sh` | Same as above but with smart-router :14001 and `docker stop keirouter-keirouter-1` for the keirouter-down scenario | node97 |
| `07-unit-test.py` | Direct unit test of `_post_once()` — extracts the function from app.py, dedents it, writes to temp .py, imports it, calls both branches against real services | node110 |
| `08-patch-admin-endpoint.py` | Adds `/admin/mark-failing`, `/admin/clear-failing`, `/admin/failing` endpoints to `app.py` | node110 |
| `09-patch-failing-filter.py` | Patches `router_logic.py` so admin marks actually filter the candidate chain | node110 |

## Apply order (when node110 is reachable)

```bash
# SSH in
ssh 110

# 1. Save key securely
sudo bash hermes-deploy/keirouter-integration/01-save-keirouter-key.sh

# 2. Replace config (allrouter_key is preserved)
sudo cp /opt/smart-router/config.json /opt/smart-router/config.json.bak.$(date +%s)
sudo cp hermes-deploy/keirouter-integration/02-new-config.json /opt/smart-router/config.json

# 3. Apply code patches (idempotent — re-running prints "anchor not found" or "already present")
sudo python3 hermes-deploy/keirouter-integration/03-patch-app.py.py
sudo python3 hermes-deploy/keirouter-integration/04-patch-router-logic.py
sudo python3 hermes-deploy/keirouter-integration/08-patch-admin-endpoint.py
sudo python3 hermes-deploy/keirouter-integration/09-patch-failing-filter.py

# 4. Create new keirouter chains (uses password auth)
bash hermes-deploy/keirouter-integration/05-create-chains.sh

# 5. Restart smart-router
sudo systemctl restart smart-router
# OR, if launched as direct python (no systemd unit):
sudo pkill -9 -f "smart-router/app.py"
sudo nohup python3 -m uvicorn app:app --app-dir /opt/smart-router --host 0.0.0.0 --port 4001 > /tmp/smart-router.log 2>&1 & disown

# 6. Run smoke test
bash hermes-deploy/keirouter-integration/06-smoke-test.sh

# 7. Run unit test (proves _post_once() dispatches correctly)
sudo python3 hermes-deploy/keirouter-integration/07-unit-test.py
```

## What was applied on node110 (2026-08-26)

| Step | Outcome |
|------|---------|
| `01-save-keirouter-key.sh` | wrote `/etc/hermes/keirouter.env` (0600) |
| `02-new-config.json` | replaced `/opt/smart-router/config.json`; backup at `.bak.1787739502` |
| `03-patch-app.py.py` | added keirouter branch + expanded retry keyword list |
| `04-patch-router-logic.py` | appended `keirouter:chain:fast-fallback` / `coding-heavy` as final candidates |
| `05-create-chains.sh` | created `coding-heavy` (latency) and `fast-fallback` (priority) chains |
| `06-smoke-test.sh` | A–G all pass — 11/11 assertions; admin mark-falling drives E (was 100-parallel-request hack), G verifies 503 when both LiteLLM and keirouter are down |
| `07-unit-test.py` | PASS — keirouter branch returns `qwen3.8-max-pd` "pong"; allrouter branch returns `openai/gpt-oss-120b` |
| `08-patch-admin-endpoint.py` | adds `/admin/mark-failing`, `/admin/clear-failing`, `/admin/failing` to `app.py` |
| `09-patch-failing-filter.py` | fixes three bugs in `router_logic.py` so admin marks actually filter the chain |

## What was applied on node97 (2026-08-26)

| Step | Outcome |
|------|---------|
| smart-router port | **14001** (not 4001 — port 4001 on node97 is `ipfs`) |
| keirouter networking | host networking (port 20180 is the host port; container name `keirouter-keirouter-1`) |
| keirouter data | fresh initdb — admin password reset to `DADA-Admin-2026` and stored at `/etc/hermes/keirouter-admin.env` (mode 0600, owner root) |
| Allrouter routing | added custom-openai account `node110-allrouter` (id `514baf5c-...-cf95ae24329c`) pointing at `http://185.55.240.110:4003/v1` |
| `/etc/hermes/keirouter.env` | written on host (not in container) so smart-router can read it on startup |
| `02-new-config.json` patches | `port`→`14001`, `keirouter_url`→`http://127.0.0.1:20180`, `keirouter_key` placeholder |
| chain creation | `coding-heavy` (id `41363313-...-a682f8400cb1`, latency strategy) and `fast-fallback` (id `e30baa2a-...-99d685dca44d`, priority) — both with **bare** model names |
| `06-smoke-test-node97.sh` | 12/12 assertions pass — all 11 base scenarios + extra "top-level model" check |

### node97 vs node110 ports

```text
node110:                     node97:
  smart-router :4001           smart-router :14001  (4001 = ipfs)
  keirouter    :20180          keirouter    :20180  (host network; same)
  allrouter    :4003 (local)   allrouter    :4003   (remote, on 185.55.240.110)
```

### Bare model names (node97 gotcha)

keirouter's custom-openai provider passes the **raw** `model` field as
the upstream model name. If you put `custom-openai/big-pickle` in
`steps[].model`, keirouter will pass the literal string
`custom-openai/big-pickle` to allrouter, which rejects it as
`Invalid model name`. Use bare names only:

```json
{"steps":[{"provider":"custom-openai","model":"big-pickle"}]}
                                   ^^^^^^^^^^^^^^^^^^ no "custom-openai/" prefix
```

This is opposite to some keirouter docs that recommend the prefixed
form. The kanban check is: the chain responds with `choices[]` and a
recognizable `model` field — if you see `400 model_unavailable`, drop
the prefix.

### Apply order (node97 — fast path)

```bash
# SSH in (config alias: server97)
ssh server97

# 1. Save keirouter admin + API keys
sudo bash hermes-deploy/keirouter-integration/01-save-keirouter-key.sh

# 2. Replace config (smart-router on node97 uses port 14001)
sudo cp /opt/smart-router/config.json /opt/smart-router/config.json.bak.$(date +%s)
sudo cp hermes-deploy/keirouter-integration/02-new-config.json /opt/smart-router/config.json

# 3. Apply code patches (smart-router's app.py on node97 must already exist,
#    patches are anchored on existing functions / lines and are idempotent)
sudo python3 hermes-deploy/keirouter-integration/03-patch-app.py.py
sudo python3 hermes-deploy/keirouter-integration/04-patch-router-logic.py
sudo python3 hermes-deploy/keirouter-integration/08-patch-admin-endpoint.py
sudo python3 hermes-deploy/keirouter-integration/09-patch-failing-filter.py

# 4. Create keirouter chains (uses password auth at dashboard)
bash hermes-deploy/keirouter-integration/05-create-chains.sh

# 5. Restart smart-router (node97 systemd unit is `smart-router` and uses --port 14001)
sudo systemctl restart smart-router

# 6. Run smoke test (node97-specific — port 14001, container name keirouter-keirouter-1)
sudo bash hermes-deploy/keirouter-integration/06-smoke-test-node97.sh
```

If smart-router on node97 is launched via `nohup uvicorn` (not systemd),
target the port explicitly:

```bash
sudo pkill -9 -f "smart-router/app.py"
sudo nohup python3 -m uvicorn app:app --app-dir /opt/smart-router \
  --host 0.0.0.0 --port 14001 > /tmp/smart-router.log 2>&1 & disown
```

## Retry keyword expansion

`smart-router/app.py` retry-keyword set was expanded from
`(rate limit, quota, cooldown, tpm/rpm rate, 429)`
to also include `(notfound, no endpoints, model not found, unknown model)`
so that when allrouter/LiteLLM returns its signature `NotFoundError: No
endpoints available` for an exhausted model, smart-router actually
moves on to the next candidate instead of looping on the same one.

## Security

- `/etc/hermes/keirouter.env` mode 0600, owner root, NEVER committed.
- `keirouter_key` field in `02-new-config.json` is a placeholder
  (`<load from /etc/hermes/keirouter.env>`) — smart-router's `app.py`
  loader reads the real key from the env file at startup.
- If the env file is missing, `_post_once()` falls back to
  `config.get("keirouter_key")` which is empty, and the request
  fails with a clear 401 from keirouter.
- `/admin/mark-failing` and `/admin/clear-failing` accept an
  `X-Admin-Token` header; if `config.admin_token` is unset (current
  state on node110) the endpoints are open — consistent with other
  internal smart-router endpoints. Set `admin_token` in
  `/opt/smart-router/config.json` to enforce auth.

## Rollback

```bash
sudo systemctl stop smart-router    # OR: sudo pkill -9 -f "smart-router/app.py"
sudo cp /opt/smart-router/config.json.bak.<ts> /opt/smart-router/config.json
sudo git -C /opt/smart-router checkout app.py router_logic.py  # if tracked
sudo systemctl start smart-router
```

## Memory

Integration pattern is locked in PLUR engrams:
- `keirouter-fallback-architecture` — the layered design
- `keirouter-bootstrap-procedure` — dashboard auth (password only — no username field) + API key creation
- `smart-router-admin-failing-bugs` — the three `_is_failing` / `_live` / `select_model` bugs that admin mark-failing exposed

## Migrated agents on node110 (2026-08-27)

Every live LLM-using agent on node110 now routes through smart-router
on `:4001`. Pre-migration each agent pointed at a different dedicated
endpoint (`cliproxy:8643`, `openclaw-gateway:18790`, raw LiteLLM, etc.).
After migration they all converge on the same Tier 1 (smart-router)
endpoint with the keirouter chain as a transparent fallback tier.

| Agent / pid | Endpoint (was) | Endpoint (now) | Config file | Backup |
|-------------|----------------|----------------|-------------|--------|
| `hermes-agent` (pid 3481657, uvicorn :8001) | standalone provider call | `http://127.0.0.1:4001/v1` | `/root/dada-hermes-agent/server/.env` | `.bak-1787772164` |
| `superdadaya-bot` (pid 3481655, hermes bot process) | shares hermes-agent env | `http://127.0.0.1:4001/v1` | (same `.env`) | (same) |
| `tradingagent-backend` (pid 3481659, :8000) | `CLIPROXY_BASE_URL=http://127.0.0.1:8643/v1` | `CLIPROXY_BASE_URL=http://127.0.0.1:4001/v1` | `/root/TradingAgent-VN/.env` | `.bak-1787772251` |
| `uae-telegram-bot` (pid 1439061) | `OPENCODE_URL=http://localhost:8643` | `OPENCODE_URL=http://127.0.0.1:4001/v1` (Tier 3 opencode) | `/root/dada-super-agent/apps/telegram-bot/.env` | `.bak-1787772251` |
| `uae` server (pid 1439113, :1818) | 9router/omniroute subprocesses | unchanged — relies on Hermes Tier 1 (also migrated) + opencode Tier 3 (also migrated) | (no top-level .env exists) | n/a |

### Verification (live, 2026-08-27)

| Tier | Endpoint | HTTP | Routed model | Notes |
|------|----------|------|--------------|-------|
| Hermes :8001/ai/chat | `groq-qwen3.6-27b` → 200 | ✓ | Hermes itself sits behind smart-router :4001, so an `/ai/chat` call lands on groq-qwen3.6-27b |
| Smart-router :4001/v1 | `tokenrouter-nemotron-3-super` (DeepInfra) | ✓ | Returns `Pong!`. This is what all 4 migrated agents now hit. |
| omniroute :20128 | 401 — needs its own provider auth | n/a | Independent router. uae-bot falls past it to Tier 3 in production. |
| keirouter :20180/v1 chain:fast-fallback | (long-tail, parallel provider) | ✓ | Previously verified 11/11 via `06-smoke-test.sh` scenario E (admin mark-failing drives the chain). |

### Why migration was safe

- smart-router's `_post_once()` already preserves every model name
  (e.g. `deepseek-v4-pro`, `big-pickle`) — agents keep their existing
  business-logic model strings, only the base URL changes.
- smart-router transparently chains LiteLLM and `keirouter:chain:*`
  virtual models, so keirouter's 15 OAuth-bearing providers
  (kilocode, Kiro, kimi-coding) become available to every agent that
  previously only saw the 7 LiteLLM candidates.
- Endpoint security: smart-router listens on `127.0.0.1:4001` (loopback
  only — same trust boundary as the prior `127.0.0.1:8643` cliproxy).
- All four .env files backed up with `.bak-<unix-ts>` suffix before
  edit; rollback = restore the backup and `pm2 restart <name>`.
