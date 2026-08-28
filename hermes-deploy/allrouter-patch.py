#!/usr/bin/env python3
"""
allrouter-patch.py — verify and probe hermes-agent's HTTP client config.

Two layers to validate:

1. Allrouter (LLM upstream):
   - Reads /etc/hermes/allrouter.env (or ~/.hermes/allrouter.env on macOS)
   - Checks ALLROUTER_BASE_URL, ALLROUTER_API_KEY, HERMES_LLM_USER_AGENT,
     and the Stainless override headers in HERMES_LLM_DEFAULT_HEADERS.

2. Per-node + mesh-LB API tokens:
   - Reads /etc/hermes/node.env (or ~/.hermes/node.env on macOS)
   - Checks HERMES_API_TOKEN exists and HERMES_API_TOKENS contains it
   - If MESH_LB_TOKEN is set in /etc/hermes/lb.env (or ~/.hermes/lb.env),
     confirms the LB token is also in HERMES_API_TOKENS

Usage:
    python3 allrouter-patch.py --check       # validate all config
    python3 allrouter-patch.py --apply       # probe api.privseai.com/v1/models
    python3 allrouter-patch.py --tokens      # only check tokens
"""
from __future__ import annotations
import argparse
import os
import subprocess
import sys
from pathlib import Path

ENV_PATHS_LINUX = {
    "allrouter": Path("/etc/hermes/allrouter.env"),
    "node":      Path("/etc/hermes/node.env"),
    "lb":        Path("/etc/hermes/lb.env"),
}
ENV_PATHS_MAC = {
    "allrouter": Path.home() / ".hermes" / "allrouter.env",
    "node":      Path.home() / ".hermes" / "node.env",
    "lb":        Path.home() / ".hermes" / "lb.env",
}


def env_paths() -> dict[str, Path]:
    if Path("/etc/hermes").exists():
        return ENV_PATHS_LINUX
    return ENV_PATHS_MAC


def load_env(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    if not path.exists():
        return env
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        k, _, v = line.partition("=")
        env[k.strip()] = v.strip().strip("'").strip('"')
    return env


def check_allrouter() -> list[str]:
    paths = env_paths()
    path = paths["allrouter"]
    if not path.exists():
        return [f"✗ no allrouter.env at {path}"]
    env = load_env(path)
    issues: list[str] = []
    base = env.get("ALLROUTER_BASE_URL", "")
    if "privseai.com" not in base:
        issues.append(f"ALLROUTER_BASE_URL unexpected: {base!r}")
    key = env.get("ALLROUTER_API_KEY", "")
    if not key or key == "replace-me":
        issues.append("ALLROUTER_API_KEY missing or placeholder")
    ua = env.get("HERMES_LLM_USER_AGENT", "")
    if ua != "openai-node":
        issues.append(f"HERMES_LLM_USER_AGENT={ua!r} (expected 'openai-node')")
    headers = env.get("HERMES_LLM_DEFAULT_HEADERS", "")
    for required in ("User-Agent", "X-Stainless-Os", "X-Stainless-Arch"):
        if required not in headers:
            issues.append(f"Missing {required} in HERMES_LLM_DEFAULT_HEADERS")
    return issues


def check_tokens() -> list[str]:
    """Verify per-node token + optional mesh-LB token wiring."""
    paths = env_paths()
    issues: list[str] = []
    node_env = load_env(paths["node"])
    lb_env   = load_env(paths["lb"])

    node_token = node_env.get("HERMES_API_TOKEN", "")
    if not node_token or len(node_token) < 32:
        issues.append(f"HERMES_API_TOKEN missing or too short at {paths['node']}")
        return issues

    # Validate HERMES_API_TOKENS includes HERMES_API_TOKEN
    tokens_csv = node_env.get("HERMES_API_TOKENS", "")
    accepted = [t.strip() for t in tokens_csv.split(",") if t.strip()]
    if node_token not in accepted:
        issues.append(f"HERMES_API_TOKEN not found in HERMES_API_TOKENS={tokens_csv!r}")

    # If LB token is set, it must also be in HERMES_API_TOKENS
    lb_token = lb_env.get("MESH_LB_TOKEN", "") or os.environ.get("MESH_LB_TOKEN", "")
    if lb_token:
        if lb_token not in accepted:
            issues.append(
                f"MESH_LB_TOKEN (from {paths['lb']}) is set but NOT in "
                f"HERMES_API_TOKENS — LB-routed traffic will be rejected"
            )
    else:
        issues.append(
            f"ℹ MESH_LB_TOKEN not configured (set it in {paths['lb']} if "
            f"this node should accept LB-routed traffic)"
        )

    return issues


def apply() -> int:
    env_path = env_paths()["allrouter"]
    if not env_path.exists():
        print("✗ No allrouter.env found.")
        return 1
    env = load_env(env_path)
    base = env.get("ALLROUTER_BASE_URL", "").rstrip("/")
    key = env.get("ALLROUTER_API_KEY", "")
    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "User-Agent": env.get("HERMES_LLM_USER_AGENT", "openai-node"),
    }
    try:
        import httpx
    except ImportError:
        print("✗ httpx not installed; run: pip install httpx")
        return 1
    print(f"Probing {base}/models …")
    try:
        r = httpx.get(f"{base}/models", headers=headers, timeout=15)
    except Exception as e:
        print(f"✗ Network error: {e}")
        return 1
    print(f"  HTTP {r.status_code}")
    if r.status_code == 200:
        data = r.json()
        n = len(data.get("data", [])) if isinstance(data, dict) else "?"
        print(f"  ✓ Allrouter returned {n} models — bypass working")
        return 0
    if r.status_code == 403:
        print("  ✗ 403 — Stainless bypass failed. Check headers in allrouter.env.")
        return 1
    print(f"  ✗ Unexpected status: {r.text[:200]}")
    return 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check",  action="store_true", help="Validate allrouter + tokens")
    ap.add_argument("--apply",  action="store_true", help="Probe allrouter")
    ap.add_argument("--tokens", action="store_true", help="Only check tokens")
    args = ap.parse_args()
    if not any((args.check, args.apply, args.tokens)):
        args.check = True

    rc = 0
    if args.check or args.apply:
        issues = check_allrouter()
        if issues:
            print("✗ Allrouter config issues:")
            for i in issues: print(f"  {i}")
            rc = 1
        else:
            paths = env_paths()
            env = load_env(paths["allrouter"])
            print("✓ Allrouter config looks correct:")
            print(f"  env file:        {paths['allrouter']}")
            print(f"  base_url:        {env.get('ALLROUTER_BASE_URL')}")
            print(f"  api_key:         {env.get('ALLROUTER_API_KEY','')[:8]}…"
                  f"{env.get('ALLROUTER_API_KEY','')[-4:]}")

    if args.check or args.tokens:
        token_issues = check_tokens()
        if not token_issues or all(i.startswith("ℹ") for i in token_issues):
            print("✓ API token config looks correct:")
            paths = env_paths()
            node_env = load_env(paths["node"])
            n_tokens = len([t for t in node_env.get("HERMES_API_TOKENS","").split(",") if t.strip()])
            print(f"  node env:        {paths['node']}")
            print(f"  accepted tokens: {n_tokens}")
            lb = node_env.get("MESH_LB_TOKEN") or "set externally"
            print(f"  mesh-LB token:   {'configured' if lb and lb != 'set externally' else 'unset'}")
        real_issues = [i for i in token_issues if not i.startswith("ℹ")]
        for i in token_issues:
            print(f"  {i}")
        if real_issues:
            rc = 1

    if args.apply:
        rc = apply() or rc

    return rc


if __name__ == "__main__":
    sys.exit(main())
