#!/usr/bin/env bash
# 06-smoke-test.sh — Tier 1 wire-up smoke test for agentfm tier.
#
# Flow (post-Tier 2):
#   1. Mark 12 LiteLLM + keirouter tiers failing via /admin/mark-failing
#      so the outer loop is forced to attempt the agentfm tier last.
#   2. Send a single POST /v1/chat/completions with model=auto. The chain
#      cascades: primary -> primary_pool -> secondary_pool -> allrouter
#      -> keirouter -> agentfm.
#   3. Expect HTTP 200 with tried ending in agentfm:chain:default AND
#      non-empty content. The agentfm worker is registered and serves
#      real completions (Tier 2 enabled). The wire-up signal is the
#      tried-list (proves cascade walked through every earlier tier
#      before reaching agentfm).
#   4. Clear all failing entries so the operator is left with a clean
#      router state.
#
# Pre-Tier 2 this test expected HTTP 503 + cascade exhausted (worker
# missing → 404 model_not_found → 04b retryable match → mark_failure
# → cascade exhausted). With Tier 2 active the worker actually serves,
# so HTTP 200 is the correct outcome.
#
# Mirrors keirouter-integration/06-smoke-test.sh's mark-failing pattern;
# differs in the final expected status (404 vs 200) since agentfm tier
# has no worker registered in Tier 1.

set -uo pipefail

SR="${SMART_ROUTER_URL:-http://127.0.0.1:4001}"

pass=0
fail=0

# --------------------------------------------------------------- helpers
mark_failing() {
  local m="$1"
  curl -s -X POST "$SR/admin/mark-failing" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"ttl_seconds\":600,\"reason\":\"agentfm-smoke\"}" >/dev/null
}

clear_failing() {
  local m="$1"
  curl -s -X POST "$SR/admin/clear-failing" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\"}" >/dev/null
}

clear_all_failing() {
  # Every model name smart-router's candidate_models() can return, plus
  # the keirouter virtual names. Keep this in sync with
  # /opt/smart-router/config.json + candidate_models() logic.
  local models=(
    # fast_models + slow_models from config.json
    openrouter-nemotron-3-super tokenrouter-nemotron-3-super
    groq-gpt-oss-120b groq-qwen3.6-27b
    big-pickle deepseek-v4-pro kimi-k2.6 glm-5.1 minimax-m2.5
    # keirouter virtual names (must be marked too so cascade reaches agentfm)
    keirouter:chain:fast-fallback keirouter:chain:coding-heavy
    keirouter:chain:production
    # agentfm virtual names (in case rerun while still marked)
    agentfm:chain:default
    # generic catch-alls
    primary allrouter-direct allrouter-chain
  )
  for m in "${models[@]}"; do
    clear_failing "$m"
  done
}

assert() {
  local label="$1" cond="$2" detail="$3"
  if eval "$cond"; then echo "  PASS: $label"; pass=$((pass+1))
  else echo "  FAIL: $label -- $detail"; fail=$((fail+1))
  fi
}

extract() {
  python3 -c "import sys,json; d=json.loads(sys.argv[1]); $2" "$1" 2>/dev/null
}

# Always start clean.
clear_all_failing

# ---------------------------------------------------------------- main
echo "=== agentfm Tier 1 smoke test (smart-router: $SR) ==="
echo

# A: pre-flight health.
echo "[A] pre-flight: both routers healthy"
H_SR=$(curl -s "$SR/health")
H_AF=$(curl -s http://127.0.0.1:8080/health)
assert "smart-router healthy" '[[ "$H_SR" == *healthy* ]]' "got=$H_SR"
assert "agentfm-api healthy"  '[[ "$H_AF" == *\"status\":\"ok\"* ]]' "got=$H_AF"
echo

# B: mark every earlier tier failing.
echo "[B] marking LiteLLM + keirouter tiers failing (cascade will reach agentfm)"
for m in openrouter-nemotron-3-super tokenrouter-nemotron-3-super \
         groq-gpt-oss-120b groq-qwen3.6-27b \
         big-pickle deepseek-v4-pro kimi-k2.6 glm-5.1 minimax-m2.5 \
         keirouter:chain:fast-fallback keirouter:chain:coding-heavy \
         keirouter:chain:production; do
  mark_failing "$m"
done
# NOTE: agentfm:chain:default is intentionally NOT marked failing — the
# registered worker must remain live to serve this smoke. We want to
# prove the cascade reaches agentfm and the worker returns a real
# completion, not that the cascade is exhausted at agentfm.
F_CT=$(curl -s "$SR/admin/failing" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['failing']))")
echo "  -> failure set size = $F_CT"
echo

# C: send the smoke request — expect cascade to agentfm tier.
echo "[C] POST /v1/chat/completions model=auto"
RESP_FILE="$(mktemp)"
HTTP_CODE=$(curl -s -o "$RESP_FILE" -w '%{http_code}' \
  "$SR/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "auto",
    "messages": [{"role":"user","content":"ping (agentfm tier smoke)"}]
  }')
BODY="$(cat "$RESP_FILE")"
rm -f "$RESP_FILE"
echo "  -> http=$HTTP_CODE"

# D: assert the agentfm tier was actually reached.
echo
echo "[D] verifying agentfm tier was reached"
TRIED=$(extract "$BODY" "print(','.join(d.get('error',{}).get('tried', d.get('routing_info',{}).get('tried', []))))")
echo "  tried list: $TRIED"

# Extract content from 200 response (Tier 2 worker served).
CONTENT=$(extract "$BODY" "print(d.get('choices',[{}])[0].get('message',{}).get('content','') if d.get('choices') else '')")
if [[ -n "$CONTENT" ]]; then
  echo "  -> cascade content = $(echo "$CONTENT" | head -c 80)"
fi

assert "HTTP 200 (worker served the cascade)" \
       '[[ "$HTTP_CODE" == "200" ]]' \
       "got $HTTP_CODE; body=${BODY:0:300}"

assert "tried list contains agentfm:chain:default (tier reached)" \
       '[[ "$TRIED" == *agentfm:chain:default* ]]' \
       "tried=$TRIED"

assert "tried list ends with agentfm (cascade reached final tier)" \
       '[[ "$TRIED" == *agentfm:chain:default ]] || [[ "$TRIED" == *",agentfm:chain:default" ]]' \
       "tried=$TRIED"

assert "agentfm worker content non-empty" \
       '[[ -n "$CONTENT" ]]' \
       "content=$CONTENT"

# E: cleanup.
echo
echo "[E] clearing failing entries"
clear_all_failing

# F: verify baseline restored (LiteLLM tier serves a real completion).
echo
echo "[F] regression: baseline LiteLLM tier serves real completion"
RB=$(curl -s -X POST "$SR/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"hi after agentfm smoke"}]}')
R_CHOICE=$(extract "$RB" "print(bool(d.get('choices')))")
R_MODEL=$(extract "$RB" "print(d.get('routing_info',{}).get('model','?'))")
assert "baseline returns 200"  '[[ "$R_CHOICE" == "True" ]]' "raw=${RB:0:300}"
assert "baseline did NOT use agentfm" \
       '[[ "$R_MODEL" != agentfm* ]]' \
       "model=$R_MODEL"
echo "  -> baseline model=$R_MODEL"

echo
echo "================================================"
echo "agentfm Tier 1 smoke: $pass passed, $fail failed"
echo "================================================"
[ "$fail" -eq 0 ] || exit 1
