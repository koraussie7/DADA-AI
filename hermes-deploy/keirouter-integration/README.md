# keirouter × smart-router — Unstoppable Fallback Node Integration

## Goal

smart-router (FastAPI :4001) exhausted every LiteLLM candidate →
fall back to keirouter chain:* (:20180) before returning 503.
keirouter adds 15 pre-configured providers including OAuth (Kiro /
kilocode / kimi-coding) that allrouter cannot reach.

## Architecture

```
L5  Hermes Mesh-LB          node110 / node91 / node97
L4  smart-router            FastAPI :4001  ← adds keirouter:chain:* to candidate tail
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
