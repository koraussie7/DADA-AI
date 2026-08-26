#!/usr/bin/env python3
"""Patch smart-router/router_logic.py to append keirouter:chain:* as final fallback.

Run on node110 as: sudo python3 04-patch-router-logic.py
"""
import sys

PATH = "/opt/smart-router/router_logic.py"
with open(PATH, "r") as f:
    src = f.read()

OLD = '''    chain: List[str] = [primary]
        for m in primary_pool_live:
            if m != primary and m not in chain:
                chain.append(m)
        for m in secondary_pool_live:
            if m not in chain:
                chain.append(m)
        return chain
'''

NEW = '''    chain: List[str] = [primary]
        for m in primary_pool_live:
            if m != primary and m not in chain:
                chain.append(m)
        for m in secondary_pool_live:
            if m not in chain:
                chain.append(m)

        # ──────────────────────────────────────────────────────────────
        # keirouter chain fallback (final tier) — wraps the keirouter
        # virtual-model name with the same circuit breaker. When every
        # LiteLLM candidate is in cooldown, the keirouter chain still has
        # ~15 providers to attempt.
        # ──────────────────────────────────────────────────────────────
        if complexity == "complex":
            chain_name = self.config.get("keirouter_chain_complex") or self.config.get("keirouter_chain_simple") or "production"
        else:
            chain_name = self.config.get("keirouter_chain_simple") or "production"
        kr_virtual = f"keirouter:chain:{chain_name}"
        if kr_virtual not in chain and not self._is_failing(kr_virtual):
            chain.append(kr_virtual)

        return chain
'''

if OLD not in src:
    print("ERROR: anchor not found in router_logic.py", file=sys.stderr)
    sys.exit(1)

src = src.replace(OLD, NEW, 1)

with open(PATH, "w") as f:
    f.write(src)

print("OK router_logic.py patched: keirouter chain appended to candidate_models()")
