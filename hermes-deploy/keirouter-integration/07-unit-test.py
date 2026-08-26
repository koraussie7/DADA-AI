"""
Direct unit test of _post_once() from /opt/smart-router/app.py.
Strategy: extract the function, dedent it, write to a temp .py
file at module level, then import it. We inject the live config
dict as a module-level global so the function's free variable
'config' resolves correctly.

Uses urllib.request (stdlib) to avoid httpx/trio/attrs
inspect-shadowing bug on node110.
"""
import json as _json_mod
import sys, importlib.util, textwrap, asyncio, urllib.request, urllib.error

SRC_PATH = "/opt/smart-router/app.py"
CONFIG_PATH = "/opt/smart-router/config.json"
MOD_PATH = "/tmp/_post_once_extracted.py"

src = open(SRC_PATH).read()
start = src.find("    async def _post_once")
print(f"DEBUG start idx={start}")

end = -1
i = start
while True:
    j = src.find("\n        )\n", i)
    if j == -1:
        break
    cand_end = j + len("\n        )")
    after = src[cand_end:cand_end+20]
    if after.startswith("\n    async def") or after.startswith("\n    for ") or after.startswith("\n    if ") or after.startswith("\n    #") or after.startswith("\n    return") or after.startswith("\n\n"):
        end = cand_end
        break
    i = cand_end
print(f"DEBUG end idx={end}")
fn_src = src[start:end]
fn_src = textwrap.dedent(fn_src)

injected = (
    "import json as _json_for_config\n"
    "config = _json_for_config.load(open(%r))\n" % CONFIG_PATH
)
with open(MOD_PATH, "w") as f:
    f.write(injected + fn_src + "\n")

spec = importlib.util.spec_from_file_location("_post_once_extracted", MOD_PATH)
mod = importlib.util.module_from_spec(spec)
sys.modules["_post_once_extracted"] = mod
spec.loader.exec_module(mod)
post_once = mod._post_once
print(f"DEBUG imported _post_once: {post_once}")
print(f"DEBUG keirouter_url={mod.config.get('keirouter_url')}")
print(f"DEBUG allrouter_url={mod.config.get('allrouter_url')}")

class FakeClient:
    """Async context manager + .post(url, body=, headers=) using urllib.

    NOTE: parameter is named 'body' (not 'json') so it doesn't shadow
    the json module when calling json.dumps inside.
    """
    def __init__(self, timeout=30.0):
        self.timeout = timeout
    async def __aenter__(self):
        return self
    async def __aexit__(self, *a):
        return False
    async def post(self, url, json=None, headers=None):
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self._post_sync, url, json, headers)
    def _post_sync(self, url, body, headers):
        data = _json_mod.dumps(body).encode()
        req = urllib.request.Request(url, data=data, method="POST",
                                     headers=headers or {})
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                return FakeResponse(resp.status, resp.read())
        except urllib.error.HTTPError as e:
            return FakeResponse(e.code, e.read())

class FakeResponse:
    def __init__(self, status_code, body_bytes):
        self.status_code = status_code
        self._body = body_bytes
    def json(self):
        return _json_mod.loads(self._body)
    @property
    def text(self):
        return self._body.decode(errors="replace")

async def main():
    print()
    print("=== keirouter branch: keirouter:chain:fast-fallback ===")
    async with FakeClient(timeout=30.0) as client:
        r = await post_once(
            client,
            "keirouter:chain:fast-fallback",
            {"model": "keirouter:chain:fast-fallback",
             "messages": [{"role": "user", "content": "reply with pong"}],
             "stream": False},
        )
    print(f"status={r.status_code}")
    try:
        body = r.json()
        print(f"  model={body.get('model')}")
        content = body.get("choices", [{}])[0].get("message", {}).get("content", "")
        print(f"  content={repr(content[:80])}")
        ok1 = r.status_code == 200 and content.strip()
    except Exception as e:
        print(f"  parse error: {e}")
        print(f"  body[:200]={r.text[:200]}")
        ok1 = False

    print()
    print("=== allrouter branch: groq-qwen3.6-27b ===")
    async with FakeClient(timeout=30.0) as client:
        r = await post_once(
            client,
            "groq-qwen3.6-27b",
            {"model": "groq-qwen3.6-27b",
             "messages": [{"role": "user", "content": "reply with pong"}],
             "stream": False},
        )
    print(f"status={r.status_code}")
    try:
        body = r.json()
        print(f"  model={body.get('model')}")
        ok2 = r.status_code == 200
    except Exception as e:
        print(f"  parse error: {e}")
        print(f"  body[:200]={r.text[:200]}")
        ok2 = False

    print()
    print(f"PASS keirouter branch: {ok1}")
    print(f"PASS allrouter branch: {ok2}")
    sys.exit(0 if (ok1 and ok2) else 1)

asyncio.run(main())
