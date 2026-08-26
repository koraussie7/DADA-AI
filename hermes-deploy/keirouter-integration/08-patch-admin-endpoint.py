#!/usr/bin/env python3
"""Patch smart-router/app.py to add /admin/mark-failing, /admin/clear-failing,
and /admin/failing endpoints.

Purpose: testing the keirouter fallback without having to spam 100 parallel
requests to prime circuit breakers. Operators / tests can directly mark a
model as failing with a custom TTL.

Auth: if config has an `admin_token` field, requests must include matching
X-Admin-Token header. Without admin_token set, endpoints are open
(consistent with other smart-router endpoints on this internal node).

Run on node110 as: sudo python3 08-patch-admin-endpoint.py
"""
import re
import sys

APP = "/opt/smart-router/app.py"
with open(APP, "r") as f:
    src = f.read()

# ─────────────────────────────────────────────────────────────────────────
# 1. Ensure `import time` exists
# ─────────────────────────────────────────────────────────────────────────
if not re.search(r"^import time$", src, flags=re.MULTILINE):
    # Insert after the last top-level import line
    m = list(re.finditer(r"^(?:from .* import .*|import .*)$", src, flags=re.MULTILINE))[-1]
    src = src[:m.end()] + "\nimport time" + src[m.end():]
    print("  + added `import time`")


# ─────────────────────────────────────────────────────────────────────────
# 2. Idempotency guard
# ─────────────────────────────────────────────────────────────────────────
ANCHOR = "@app.get(\"/admin/failing\")"
if ANCHOR in src:
    print("OK /admin/failing already present — patch is idempotent, skipping")
    sys.exit(0)


# ─────────────────────────────────────────────────────────────────────────
# 3. Insert three admin endpoints right before `if __name__ == "__main__":`
# ─────────────────────────────────────────────────────────────────────────
ADMIN_BLOCK = '''@app.post("/admin/mark-failing")
async def mark_failing(request: Request):
    """Mark a model as failing for `ttl_seconds` (default 300).

    Body: {"model": "<name>", "reason": "<opt>", "ttl_seconds": <int>}
    Auth: if config['admin_token'] is set, requires matching X-Admin-Token header.
    """
    body = await request.json()
    model = body.get("model")
    if not model:
        return JSONResponse(status_code=400, content={"error": "model required"})
    expected = config.get("admin_token")
    if expected:
        token = request.headers.get("x-admin-token", "")
        if token != expected:
            return JSONResponse(status_code=403, content={"error": "invalid admin token"})
    ttl = int(body.get("ttl_seconds") or 300)
    # Reuse SmartRouter.mark_failure() for default TTL; otherwise direct dict write.
    if body.get("ttl_seconds") is None:
        smart_router.mark_failure(model)
        until_ts = smart_router.failure_until.get(model, time.time() + ttl)
    else:
        smart_router.failure_until[model] = time.time() + ttl
        until_ts = smart_router.failure_until[model]
    return {
        "status": "marked",
        "model": model,
        "reason": body.get("reason", ""),
        "ttl_seconds": ttl,
        "until": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(until_ts)),
    }


@app.post("/admin/clear-failing")
async def clear_failing(request: Request):
    """Remove a model from the failing-set."""
    model = (await request.json()).get("model")
    if not model:
        return JSONResponse(status_code=400, content={"error": "model required"})
    expected = config.get("admin_token")
    if expected:
        token = request.headers.get("x-admin-token", "")
        if token != expected:
            return JSONResponse(status_code=403, content={"error": "invalid admin token"})
    smart_router.clear_failure(model)
    return {"status": "cleared", "model": model}


@app.get("/admin/failing")
async def list_failing():
    """Return all models currently in cooldown with TTL remaining (seconds)."""
    now = time.time()
    out = []
    for m, until in list(smart_router.failure_until.items()):
        remaining = until - now
        if remaining <= 0:
            smart_router.failure_until.pop(m, None)
            continue
        out.append({"model": m, "remaining_seconds": int(remaining)})
    return {"failing": sorted(out, key=lambda x: x["model"])}


'''

OLD_ANCHOR = 'if __name__ == "__main__":\n    import uvicorn'
if OLD_ANCHOR not in src:
    print("ERROR: `if __name__ == \"__main__\":` anchor not found in app.py", file=sys.stderr)
    sys.exit(1)

src = src.replace(OLD_ANCHOR, ADMIN_BLOCK + OLD_ANCHOR, 1)

with open(APP, "w") as f:
    f.write(src)

print("OK app.py patched: /admin/mark-failing + /admin/clear-failing + /admin/failing")