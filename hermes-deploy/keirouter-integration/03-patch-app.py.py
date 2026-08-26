#!/usr/bin/env python3
"""Patch smart-router/app.py to add keirouter chain fallback.

Adds:
- /etc/hermes/keirouter.env loader into config (before app starts)
- _post_to_upstream() helper that routes keirouter:chain:* names to keirouter
  and others to allrouter.
- _run_tool_loop() now uses _post_to_upstream() so tool-call follow-ups stay
  on the same upstream.

Run on node110 as: sudo python3 03-patch-app.py
"""
import os
import re
import sys

APP = "/opt/smart-router/app.py"
with open(APP, "r") as f:
    src = f.read()

# ---- 1. Inject keirouter ENV loader at top of file (after imports) ----
ENV_LOADER = '''

# ─────────────────────────────────────────────────────────────────────
# keirouter ENV loader — reads /etc/hermes/keirouter.env (mode 0600)
# so the API key never lives in config.json or env dumps.
# ─────────────────────────────────────────────────────────────────────
_KROUTER_ENV = "/etc/hermes/keirouter.env"
if os.path.isfile(_KROUTER_ENV):
    try:
        with open(_KROUTER_ENV) as _f:
            for _line in _f:
                _line = _line.strip()
                if not _line or _line.startswith("#"):
                    continue
                if "=" in _line:
                    _k, _v = _line.split("=", 1)
                    os.environ.setdefault(_k.strip(), _v.strip())
    except Exception as _e:
        print(f"[smart-router] WARN: failed to load {{_KROUTER_ENV}}: {{_e}}", file=sys.stderr)
'''

if "_KROUTER_ENV" not in src:
    # Insert right after the last top-level import line
    m = re.search(r"^(?:from .* import .*|import .*)$", src, flags=re.MULTILINE)
    if not m:
        print("ERROR: no top-level imports found in app.py", file=sys.stderr)
        sys.exit(1)
    insert_at = m.end()
    src = src[:insert_at] + ENV_LOADER + "\n\n" + src[insert_at:]


# ---- 2. Replace existing _post_once / candidate loop body ----
OLD_BODY = '''    async def _post_once(client, mdl, bdy):
        return await client.post(
            f"{config['allrouter_url']}/v1/chat/completions",
            json=bdy,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {config['allrouter_key']}"
            },
        )

    async def _run_tool_loop(client, result, bdy, mdl):
        choices = result.get("choices", [])
        if not choices:
            return result
        msg = choices[0].get("message", {})
        tool_calls = msg.get("tool_calls", [])
        if not tool_calls:
            return result
        for tc in tool_calls:
            func = tc.get("function", {})
            func_name = func.get("name", "")
            func_args = json.loads(func.get("arguments", "{}"))
            if func_name in TOOL_EXECUTORS:
                tool_result = await TOOL_EXECUTORS[func_name](func_args)
                messages.append({"role": "assistant", "content": None, "tool_calls": [tc]})
                messages.append({"role": "tool", "tool_call_id": tc.get("id", ""), "content": json.dumps(tool_result)})
        bdy["messages"] = messages
        bdy["model"] = mdl
        r2 = await _post_once(client, mdl, bdy)
        return r2.json()

    async with httpx.AsyncClient(timeout=120.0) as client:
        for mdl in candidates:
            body["model"] = mdl
            tried.append(mdl)
            try:
                response = await _post_once(client, mdl, body)
                # Retryable HTTP statuses -> mark failing and try next
                if response.status_code in (408, 409, 429, 500, 502, 503, 504):
                    smart_router.mark_failure(mdl)
                    continue
                result = response.json()
                # Provider-side error payload (LiteLLM returns 200 with error inside)
                if "error" in result and not result.get("choices"):
                    err = result.get("error") or {}
                    errmsg = (err.get("message") or "").lower()
                    if any(k in errmsg for k in ("rate limit", "quota", "cooldown", "tpm rate", "rpm rate", "429")):
                        smart_router.mark_failure(mdl)
                        continue
                    # Non-retryable error: return to caller
                    result["routing_info"] = {**routing_info_data, "tried": tried}
                    return result
                smart_router.clear_failure(mdl)
                result = await _run_tool_loop(client, result, body, mdl)
                result["routing_info"] = {**routing_info_data, "tried": tried}
                return result
            except (httpx.TimeoutException, httpx.ConnectError, httpx.RemoteProtocolError):
                smart_router.mark_failure(mdl)
                continue
            except Exception:
                smart_router.mark_failure(mdl)
                continue

        # All candidates failed
        return JSONResponse(
            status_code=503,
            content={
                "error": {
                    "message": f"All candidates failed: {tried}",
                    "type": "all_candidates_exhausted",
                    "tried": tried,
                }
            },
        )
'''

NEW_BODY = '''    async def _post_once(client, mdl, bdy):
        """Route a request to either allrouter (LiteLLM) or keirouter.

        mdl prefix `keirouter:chain:<name>` ⇒ POST to keirouter with
        model = `chain:<name>`. Anything else ⇒ allrouter as before.
        """
        if mdl.startswith("keirouter:chain:"):
            chain_name = mdl.split(":", 2)[2]
            kr_url = config.get("keirouter_url") or os.environ.get("KEIROUTER_URL", "http://127.0.0.1:20180")
            kr_key = config.get("keirouter_key") or os.environ.get("KEIROUTER_KEY", "")
            kr_body = {**bdy, "model": f"chain:{chain_name}"}
            return await client.post(
                f"{kr_url}/v1/chat/completions",
                json=kr_body,
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {kr_key}",
                },
            )
        return await client.post(
            f"{config['allrouter_url']}/v1/chat/completions",
            json=bdy,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {config['allrouter_key']}"
            },
        )

    async def _run_tool_loop(client, result, bdy, mdl):
        choices = result.get("choices", [])
        if not choices:
            return result
        msg = choices[0].get("message", {})
        tool_calls = msg.get("tool_calls", [])
        if not tool_calls:
            return result
        for tc in tool_calls:
            func = tc.get("function", {})
            func_name = func.get("name", "")
            func_args = json.loads(func.get("arguments", "{}"))
            if func_name in TOOL_EXECUTORS:
                tool_result = await TOOL_EXECUTORS[func_name](func_args)
                messages.append({"role": "assistant", "content": None, "tool_calls": [tc]})
                messages.append({"role": "tool", "tool_call_id": tc.get("id", ""), "content": json.dumps(tool_result)})
        bdy["messages"] = messages
        bdy["model"] = mdl
        r2 = await _post_once(client, mdl, bdy)
        return r2.json()

    async with httpx.AsyncClient(timeout=120.0) as client:
        for mdl in candidates:
            body["model"] = mdl
            tried.append(mdl)
            try:
                response = await _post_once(client, mdl, body)
                # Retryable HTTP statuses -> mark failing and try next
                if response.status_code in (408, 409, 429, 500, 502, 503, 504):
                    smart_router.mark_failure(mdl)
                    continue
                result = response.json()
                # Provider-side error payload (LiteLLM returns 200 with error inside)
                if "error" in result and not result.get("choices"):
                    err = result.get("error") or {}
                    errmsg = (err.get("message") or "").lower()
                    if any(k in errmsg for k in ("rate limit", "quota", "cooldown", "tpm rate", "rpm rate", "429")):
                        smart_router.mark_failure(mdl)
                        continue
                    # Non-retryable error: return to caller
                    result["routing_info"] = {**routing_info_data, "tried": tried}
                    return result
                smart_router.clear_failure(mdl)
                result = await _run_tool_loop(client, result, body, mdl)
                result["routing_info"] = {**routing_info_data, "tried": tried}
                return result
            except (httpx.TimeoutException, httpx.ConnectError, httpx.RemoteProtocolError):
                smart_router.mark_failure(mdl)
                continue
            except Exception:
                smart_router.mark_failure(mdl)
                continue

        # All candidates failed (including keirouter fallback)
        return JSONResponse(
            status_code=503,
            content={
                "error": {
                    "message": f"All candidates failed (incl. keirouter fallback): {tried}",
                    "type": "all_candidates_exhausted",
                    "tried": tried,
                }
            },
        )
'''

if OLD_BODY not in src:
    print("ERROR: anchor not found in app.py — was the previous patch applied?", file=sys.stderr)
    sys.exit(1)

src = src.replace(OLD_BODY, NEW_BODY, 1)

with open(APP, "w") as f:
    f.write(src)

print("OK app.py patched: keirouter chain routing wired into _post_once")
