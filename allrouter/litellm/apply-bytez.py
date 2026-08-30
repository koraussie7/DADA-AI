#!/usr/bin/env python3
"""Bytez fallback tier application script for AllRouter LiteLLM.

Adds Bytez as the LAST fallback tier for each routing alias group:
  - .env                 : BYTEZ_API_KEY=<key>
  - docker-compose.yml   : BYTEZ_API_KEY env on the allrouter-litellm service
  - config.yaml          : bytez/<model> entry appended to each alias group

Safe to re-run (idempotent). Backs up config.yaml before editing.

Usage:
  python3 apply-bytez.py --key <BYTEZ_API_KEY> [--dry-run] [--dir /opt/allrouter/litellm]

The Bytez model catalog API has been returning an empty catalog since ~2026-08-05
(see github.com/Bytez-com/docs issue #59). Adding the fallback now is harmless:
calls will error until Bytez restores the catalog, then work immediately.
"""

import argparse
import os
import shutil
import sys
from datetime import datetime

BYTEZ_MODEL = "meta-llama/Llama-3.2-3B-Instruct"  # 3B, chat, fits Free plan (<=7B)

# Alias groups that should get the bytez entry appended as last fallback.
# (model_name values observed via GET /v1/models on the running proxy.)
ALIAS_GROUPS = [
    "big-pickle",
    "deepseek-v4-pro",
    "deepseek-v4-flash",
    "kimi-k2.6",
    "kimi-k2.7-code",
    "kimi-k3",
    "minimax-m2.5",
    "minimax-m2.7",
    "minimax-m3",
    "glm-5.1",
    "qwen3.6-plus",
]


def ensure_env(base_dir, key, dry_run):
    env_path = os.path.join(base_dir, ".env")
    line = f"BYTEZ_API_KEY={key}"
    if not os.path.exists(env_path):
        print(f"[skip] {env_path} not found")
        return
    content = open(env_path, "r", encoding="utf-8").read()
    if "BYTEZ_API_KEY=" in content:
        print("[ok] .env already has BYTEZ_API_KEY")
        return
    if dry_run:
        print(f"[dry] would append `{line}` to {env_path}")
        return
    with open(env_path, "a", encoding="utf-8") as f:
        f.write("\n" + line + "\n")
    print(f"[add] {env_path} += {line}")


def ensure_compose(base_dir, dry_run):
    compose_path = os.path.join(base_dir, "docker-compose.yml")
    if not os.path.exists(compose_path):
        print(f"[skip] {compose_path} not found")
        return
    content = open(compose_path, "r", encoding="utf-8").read()
    if "BYTEZ_API_KEY" in content:
        print("[ok] docker-compose.yml already has BYTEZ_API_KEY")
        return
    # Insert into the litellm service environment block.
    marker = "allrouter-litellm"
    if marker not in content:
        print(f"[warn] service block `{marker}` not found in docker-compose.yml")
        return
    if dry_run:
        print(f"[dry] would add `BYTEZ_API_KEY: ${{BYTEZ_API_KEY}}` to {marker} service")
        return
    idx = content.index(marker)
    seg = content[idx:]
    env_idx = seg.find("environment:")
    if env_idx == -1:
        print("[warn] no environment: block found in litellm service")
        return
    rest = seg[env_idx + len("environment:"):]
    lines = rest.splitlines(keepends=True)
    indent = "      "
    for ln in lines:
        if ln.strip():
            indent = ln[: len(ln) - len(ln.lstrip())]
            break
    insertion = "\n" + indent + "- BYTEZ_API_KEY: ${BYTEZ_API_KEY}"
    abs_pos = idx + env_idx + len("environment:")
    new_content = content[:abs_pos] + insertion + content[abs_pos:]
    with open(compose_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("[add] docker-compose.yml litellm service += BYTEZ_API_KEY env")


def ensure_config(base_dir, dry_run):
    cfg_path = os.path.join(base_dir, "config.yaml")
    if not os.path.exists(cfg_path):
        print(f"[skip] {cfg_path} not found")
        return
    try:
        import yaml
    except ImportError:
        print("[warn] PyYAML not installed; skipping config.yaml edit "
              "(pip install pyyaml, then re-run)")
        return

    with open(cfg_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    model_list = data.get("model_list") or []
    entry_model = f"bytez/{BYTEZ_MODEL}"
    seen = set()
    for m in model_list:
        if isinstance(m, dict) and "model_name" in m:
            seen.add((m["model_name"], (m.get("litellm_params") or {}).get("model")))

    added = []
    for alias in ALIAS_GROUPS:
        if (alias, entry_model) in seen:
            print(f"[ok] {alias} already has {entry_model}")
            continue
        has_alias = any(
            isinstance(m, dict) and m.get("model_name") == alias for m in model_list
        )
        if not has_alias:
            print(f"[skip] alias `{alias}` not found in config.yaml model_list")
            continue
        entry = {
            "model_name": alias,
            "litellm_params": {
                "model": entry_model,
                "api_key": "os.environ/BYTEZ_API_KEY",
            },
        }
        model_list.append(entry)
        added.append(alias)

    if not added:
        print("[ok] config.yaml already up to date")
        return

    if dry_run:
        print(f"[dry] would append bytez/{BYTEZ_MODEL} to aliases: {', '.join(added)}")
        return

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = cfg_path + f".bak-bytez-{stamp}"
    shutil.copy2(cfg_path, backup)
    with open(cfg_path, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)
    print(f"[add] config.yaml += bytez/{BYTEZ_MODEL} for: {', '.join(added)}")
    print(f"[bak] {backup}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", required=True, help="BYTEZ_API_KEY")
    ap.add_argument("--dir", default="/opt/allrouter/litellm", help="litellm dir")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    ensure_env(args.dir, args.key, args.dry_run)
    ensure_compose(args.dir, args.dry_run)
    ensure_config(args.dir, args.dry_run)

    if not args.dry_run:
        print("\nNext: cd {dir} && docker compose up -d --force-recreate allrouter-litellm")
        print("Then: curl -s http://localhost:4001/v1/models | grep -i bytez")


if __name__ == "__main__":
    main()
