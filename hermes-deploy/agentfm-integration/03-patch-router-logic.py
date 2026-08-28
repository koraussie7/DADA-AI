#!/usr/bin/env python3
"""
03-patch-router-logic.py — add agentfm tier to candidate_models().

Mirrors the keirouter append block: same chain-name pattern (complexity-aware
fallback to simple), same `_is_failing` circuit breaker, same append-if-not-in
de-duplication. The only addition is the `agentfm_enabled` config gate so
operators can disable the tier without uninstalling the binary.

Anchor: the production router_logic.py already contains the keirouter block
ending in `chain.append(kr_virtual)`. We splice the agentfm block immediately
after — keeping the agentfm tier as the FINAL fallback (positioned after
keirouter in the candidate chain).

Run on node110 (or with --target user@host):
    python3 03-patch-router-logic.py /opt/smart-router/router_logic.py
    python3 03-patch-router-logic.py --target root@110 /opt/smart-router/router_logic.py
"""
import argparse
import shutil
import sys
import time
from pathlib import Path

OLD = """        if kr_virtual not in chain and not self._is_failing(kr_virtual):
            chain.append(kr_virtual)
"""

NEW = """        if kr_virtual not in chain and not self._is_failing(kr_virtual):
            chain.append(kr_virtual)

        # ---------------------------------------------------------------
        # agentfm chain fallback (Tier 6, final). agentfm-core's OpenAI
        # gateway listens at config['agentfm_url']; the `model` field is
        # the bare chain name (peer-id → agent-name → engine lookup). With
        # no worker registered in Tier 1, the gateway deterministically
        # returns 404 model_not_found, which smart-router's outer loop
        # treats as a tier-reached signal via mark_failure(mdl).
        # ---------------------------------------------------------------
        if self.config.get("agentfm_enabled"):
            if complexity == "complex":
                chain_name = (
                    self.config.get("agentfm_chain_complex")
                    or self.config.get("agentfm_chain_simple")
                    or "default"
                )
            else:
                chain_name = self.config.get("agentfm_chain_simple") or "default"
            af_virtual = f"agentfm:chain:{chain_name}"
            if af_virtual not in chain and not self._is_failing(af_virtual):
                chain.append(af_virtual)
"""


def patch(path: Path) -> None:
    src = path.read_text()
    if OLD not in src:
        sys.stderr.write(
            f"FATAL: anchor not found in {path}\n"
            "expected exact match of:\n---\n" + OLD + "---\n"
            "The source has likely drifted from the keirouter-integration "
            "deploy. Re-read /opt/smart-router/router_logic.py around "
            "candidate_models() and update the anchor.\n"
        )
        sys.exit(1)
    if "agentfm:chain:" in src:
        print(f"OK   {path}: agentfm tier already present, skipping")
        return
    backup = path.with_suffix(path.suffix + f".pre-agentfm.{int(time.time())}")
    shutil.copy2(path, backup)
    print(f"BACK {path}: snapshot -> {backup}")
    path.write_text(src.replace(OLD, NEW, 1))
    print(f"OK   {path}: agentfm tier appended after keirouter block")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("path", type=Path, help="/opt/smart-router/router_logic.py")
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
