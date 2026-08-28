#!/usr/bin/env python3
"""
05-redaction-patch.py — fix secret-key leakage in /config endpoint.

Production app.py currently redacts only `allrouter_key`:
    safe = {k: v for k, v in config.items() if k != "allrouter_key"}

That leaks two secrets that were added later:
  - `keirouter_key`   (added in keirouter-integration PR; production now ships it)
  - `agentfm_key`     (added by this PR — would leak immediately)

Fix: replace the inline `if k != "allrouter_key"` with a module-level
SECRET_KEYS set referenced from /config. Simple, single-anchor patch.
"""
import argparse
import shutil
import sys
import time
from pathlib import Path

OLD = """@app.get("/config")
async def get_config():
    safe = {k: v for k, v in config.items() if k != "allrouter_key"}
    return safe
"""

NEW = """@app.get("/config")
async def get_config():
    safe = {k: v for k, v in config.items() if k not in _SECRET_KEYS}
    return safe


# Keys whose values MUST NOT be exposed via the unauthenticated /config
# endpoint. All other config is non-sensitive routing metadata.
_SECRET_KEYS = frozenset({"allrouter_key", "keirouter_key", "agentfm_key"})
"""


def patch(path: Path) -> None:
    src = path.read_text()
    if OLD not in src:
        sys.stderr.write(
            f"FATAL: anchor not found in {path}\n"
            "expected exact match of:\n---\n" + OLD + "---\n"
            "The /config endpoint may have drifted; inspect it manually and\n"
            "update the anchor.\n"
        )
        sys.exit(1)
    if "_SECRET_KEYS" in src:
        print(f"OK   {path}: redaction already uses SECRET_KEYS, skipping")
        return
    backup = path.with_suffix(path.suffix + f".pre-agentfm.{int(time.time())}")
    shutil.copy2(path, backup)
    print(f"BACK {path}: snapshot -> {backup}")
    # Insert the SECRET_KEYS set BEFORE the @app.get("/config") block by
    # replacing OLD with NEW (NEW includes both the new endpoint body and
    # the set definition).
    path.write_text(src.replace(OLD, NEW, 1))
    print(f"OK   {path}: /config now redacts allrouter_key + keirouter_key + agentfm_key")


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
