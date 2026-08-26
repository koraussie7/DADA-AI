#!/usr/bin/env python3
"""Patch smart-router/router_logic.py so the admin /admin/mark-failing
endpoint actually affects the candidate chain.

Two related bugs in the existing code:

1. `select_model()` clears `failure_until` when the entire pool is in
   cooldown. This wipes out admin marks and reverts the chain to a
   random pick from the full pool. Admin testing becomes impossible.

2. `candidate_models()` defines `_live(pool)` but never calls it —
   `primary_pool_live` and `secondary_pool_live` are just shuffled
   copies of the full pool. Failing models stay in the chain and waste
   a request per model before keirouter fallback fires.

Fix:
- select_model: do NOT clear failure_until. If live_pool is empty,
  fall through and let candidate_models build the keirouter chain.
  Pick the first pool member as primary so the chain has a head.
- candidate_models: actually USE _live() to filter failing models
  from primary/secondary pools before shuffling.

Run on node110 as: sudo python3 09-patch-failing-filter.py
"""
import sys

PATH = "/opt/smart-router/router_logic.py"
with open(PATH, "r") as f:
    src = f.read()

# ─────────────────────────────────────────────────────────────────────────
# 1. select_model — drop the failure_until.clear()
# ─────────────────────────────────────────────────────────────────────────
OLD_SELECT = '''        live_pool = [m for m in pool if not self._is_failing(m)]
        if not live_pool:
            self.failure_until.clear()
            live_pool = pool
'''
NEW_SELECT = '''        live_pool = [m for m in pool if not self._is_failing(m)]
        if not live_pool:
            # All pool models marked failing (typically by admin mark-failing).
            # Do NOT clear — that would defeat the whole point of /admin/mark-failing
            # and prevent the keirouter fallback tier from ever firing.
            # Fall back to the first pool member so candidate_models still has
            # a primary to anchor the chain.
            live_pool = pool[:1]
'''

if OLD_SELECT not in src:
    print("ERROR: select_model anchor not found", file=sys.stderr)
    sys.exit(1)
src = src.replace(OLD_SELECT, NEW_SELECT, 1)


# ─────────────────────────────────────────────────────────────────────────
# 2. candidate_models — make _live() actually filter and use it
# ─────────────────────────────────────────────────────────────────────────
OLD_CAND = '''        def _live(pool):
            live = [m for m in pool if not self._is_failing(m)]
            return live or pool

        primary_pool_live = list(primary_pool)
        random.shuffle(primary_pool_live)
        secondary_pool_live = list(secondary_pool)
        random.shuffle(secondary_pool_live)
'''
NEW_CAND = '''        def _live(pool):
            # Return ONLY models not currently in cooldown. The previous
            # `return live or pool` fallback undid admin /admin/mark-failing
            # marks by re-inserting the failing models into the chain.
            return [m for m in pool if not self._is_failing(m)]

        primary_pool_live = _live(list(primary_pool))
        random.shuffle(primary_pool_live)
        secondary_pool_live = _live(list(secondary_pool))
        random.shuffle(secondary_pool_live)
'''

if OLD_CAND not in src:
    print("ERROR: candidate_models anchor not found", file=sys.stderr)
    sys.exit(1)
src = src.replace(OLD_CAND, NEW_CAND, 1)


with open(PATH, "w") as f:
    f.write(src)

print("OK router_logic.py patched: select_model no longer clears admin marks; candidate_models filters failing")