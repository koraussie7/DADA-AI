#!/usr/bin/env python3
"""
04b-patch-retryable-errors.py — broaden retryable-error substring matching
to also scan the full error JSON (so the agentfm gateway's
`{"error":{"code":"model_not_found"}}` payload is treated as retryable).

Production app.py outer loop currently does:
    errmsg = (err.get("message") or "").lower()
    if any(k in errmsg for k in (...)):

That misses agentfm because agentfm puts the canonical error code
("model_not_found", "mesh_overloaded") in a separate `code` field while
its human-readable `message` reads "model 'X' not available on this mesh
..." — none of the existing retryable substrings match the message.

Two changes:
  1. Search the full JSON of the error object (covers both `message` and
     `code` fields and any future field agentfm might add).
  2. Add `model_not_found` and `mesh_overloaded` to the retryable set.

Idempotent: detects prior application and exits clean.
"""
import argparse
import shutil
import sys
import time
from pathlib import Path

OLD = """                    if any(k in errmsg for k in (
                        "rate limit", "quota", "cooldown", "tpm rate", "rpm rate", "429",
                        # model-not-found / no-endpoints: fallback to keirouter chain
                        "notfound", "no endpoints", "model not found", "unknown model",
                    )):"""

NEW = """                    # Search the full error JSON (not just the `message` field)
                    # so agentfm-gateway-style `{"code":"model_not_found"}` payloads
                    # — whose message reads "model 'X' not available on this mesh" —
                    # are also treated as retryable (mark_failure + try next tier).
                    errblob = json.dumps(err).lower() if err else ""
                    if any(k in errblob for k in (
                        "rate limit", "quota", "cooldown", "tpm rate", "rpm rate", "429",
                        # model-not-found / no-endpoints: fallback to next tier
                        "notfound", "no endpoints", "model not found", "unknown model",
                        # agentfm-gateway canonical codes (in `code` field)
                        "model_not_found", "mesh_overloaded",
                    )):"""


def patch(path: Path) -> None:
    src = path.read_text()
    if OLD not in src:
        sys.stderr.write(
            f"FATAL: anchor not found in {path}\n"
            "expected exact match of:\n---\n" + OLD + "---\n"
            "The retryable-error block may have drifted; inspect the outer\n"
            "loop in /opt/smart-router/app.py around `_post_once` calls.\n"
        )
        sys.exit(1)
    if "model_not_found" in src and "mesh_overloaded" in src:
        print(f"OK   {path}: agentfm retryable codes already present, skipping")
        return
    backup = path.with_suffix(path.suffix + f".pre-agentfm-retryable.{int(time.time())}")
    shutil.copy2(path, backup)
    print(f"BACK {path}: snapshot -> {backup}")
    path.write_text(src.replace(OLD, NEW, 1))
    print(f"OK   {path}: retryable error matching now scans full error JSON + agentfm codes")


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
