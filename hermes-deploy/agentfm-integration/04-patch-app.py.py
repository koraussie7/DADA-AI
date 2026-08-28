#!/usr/bin/env python3
"""
04-patch-app.py.py — add agentfm branch to _post_once() in smart-router/app.py.

The production app.py's _post_once() already handles keirouter:chain:*
prefixes inline (no big replace-the-whole-function needed like the original
keirouter integration). We splice a parallel agentfm:chain:* branch immediately
after the keirouter branch, matching its shape exactly:

  - Strip the `agentfm:chain:` prefix to get the bare chain name.
  - Forward that as the `model` field to the agentfm OpenAI gateway.
  - Include `Authorization: Bearer <key>` only when `agentfm_key` is set
    (Tier 1 runs keyless loopback — omitting the header keeps requests clean).

The agentfm gateway has no `tools` / function-calling support, so we do NOT
add the tools / tool_choice rewrites here — we forward the body as-is and let
the gateway ignore those fields (or 400 on them in Tier 2+ when MCP is wired).

Outer-loop compatibility:
  - `_post_once` returns the raw httpx.Response.
  - Outer loop marks failure for status in (408, 409, 429, 500-504).
  - 404 falls through to `response.json()` parsing; agentfm's payload
    `{"error": {"message": "model_not_found"}}` contains "notfound" →
    mark_failure + continue (matches existing retryable-error string match).
  - 5xx / connection errors also mark_failure.

Anchor: the production _post_once keirouter block (use the whole block so
collisions with unrelated `keirouter_url` mentions are avoided).
"""
import argparse
import shutil
import sys
import time
from pathlib import Path

OLD = """        if mdl.startswith("keirouter:chain:"):
            chain_name = mdl[len("keirouter:chain:"):]
            return await client.post(
                f"{config['keirouter_url']}/v1/chat/completions",
                json={**bdy, "model": f"chain:{chain_name}"},
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {config.get('keirouter_key','')}"
                },
            )
"""

NEW = """        if mdl.startswith("keirouter:chain:"):
            chain_name = mdl[len("keirouter:chain:"):]
            return await client.post(
                f"{config['keirouter_url']}/v1/chat/completions",
                json={**bdy, "model": f"chain:{chain_name}"},
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {config.get('keirouter_key','')}"
                },
            )
        # Tier 6: agentfm OpenAI-compatible gateway (loopback, keyless for
        # Tier 1). Mirrors the keirouter block above; strips the
        # "agentfm:chain:" prefix and forwards the bare chain name as the
        # `model` field. The agentfm gateway uses `model` as a routing key
        # only (peer-id -> agent-name -> engine); with no worker registered
        # in Tier 1, it deterministically returns 404 model_not_found, whose
        # body contains "notfound" -> smart-router's outer loop calls
        # mark_failure(mdl) and continues to the next candidate (none, so
        # 503 all_candidates_exhausted is returned to the caller).
        if mdl.startswith("agentfm:chain:"):
            bare = mdl[len("agentfm:chain:"):]
            headers = {"Content-Type": "application/json"}
            af_key = config.get("agentfm_key") or ""
            if af_key:
                headers["Authorization"] = f"Bearer {af_key}"
            return await client.post(
                f"{config['agentfm_url']}/v1/chat/completions",
                json={**bdy, "model": bare},
                headers=headers,
            )
"""


def patch(path: Path) -> None:
    src = path.read_text()
    if OLD not in src:
        sys.stderr.write(
            f"FATAL: anchor not found in {path}\n"
            "expected exact match of:\n---\n" + OLD + "---\n"
            "The source has likely drifted from the keirouter-integration "
            "deploy. Re-read /opt/smart-router/app.py around _post_once() "
            "and update the anchor.\n"
        )
        sys.exit(1)
    if "agentfm:chain:" in src:
        print(f"OK   {path}: agentfm branch already present, skipping")
        return
    backup = path.with_suffix(path.suffix + f".pre-agentfm.{int(time.time())}")
    shutil.copy2(path, backup)
    print(f"BACK {path}: snapshot -> {backup}")
    path.write_text(src.replace(OLD, NEW, 1))
    print(f"OK   {path}: agentfm branch appended after keirouter branch")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("path", type=Path, help="/opt/smart-router/app.py")
    ap.add_argument(
        "--target",
        metavar="USER@HOST",
        help="optional: scp the file to a remote host, patch in place, scp back",
    )
    args = ap.parse_args()

    if args.target:
        import subprocess

        remote = args.target
        remote_path = str(args.path)
        local_copy = Path("/tmp") / args.path.name
        subprocess.run(
            ["scp", f"{remote}:{remote_path}", str(local_copy)], check=True
        )
        patch(local_copy)
        subprocess.run(
            ["scp", str(local_copy), f"{remote}:{remote_path}"], check=True
        )
    else:
        patch(args.path)


if __name__ == "__main__":
    main()
