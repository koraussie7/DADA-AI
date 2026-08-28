#!/usr/bin/env bash
# 09-tier3-smoke-test.sh — agentfm Tier 3 smoke (multi-agent swarm: default + coder)
#
# Tier 2 는 smart-router 의 agentfm tier 가 항상 `default` chain 으로 끝나는 것을 검증.
# Tier 3 는 동일 swarm 에 두 개의 worker (default/qwen2.5:0.5b + coder/qwen2.5:1.5b) 가
# 공존하고, complexity-based routing 이 각각 다른 chain 으로 라우팅하는지 검증.
#
# Complexity heuristic (router_logic.py):
#   - len(text) > 200 chars  → "complex"
#   - complex_keywords match → "complex"
#   - else                   → "simple"
#
# Config (applied to /opt/smart-router/config.json on node110):
#   agentfm_chain_simple:  "default"   ← Tier 2 그대로
#   agentfm_chain_complex: "coder"     ← Tier 3 wiring
#
# Flow:
#   1. /v1/models has 2 entries (default + coder 둘 다 AVAILABLE)
#   2. direct gateway POST model=default → 200 + content (Tier 2 regression)
#   3. direct gateway POST model=coder → 200 + content (Tier 3 new)
#   4. mark 12 primary tiers failing + agentfm:chain:default failing
#      POST long prompt (complex) → 200 + tried 마지막 = agentfm:chain:coder + content
#      (다른 worker 만 살았을 때 complexity routing 이 coder 를 골라야 함을 검증)
#   5. clear-failing 13 entries → regression: short auto prompt →
#      200 + tried 마지막 = agentfm:chain:default + content
#   6. clear-failing ALL → baseline 회귀: auto short → 200 + routing_info.model != agentfm

set -uo pipefail

SR="${SMART_ROUTER_URL:-http://127.0.0.1:4001}"
AF="http://127.0.0.1:8080"

pass=0
fail=0

# --------------------------------------------------------------- helpers
mark_failing() {
  local m="$1"
  curl -s -X POST "$SR/admin/mark-failing" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"ttl_seconds\":600,\"reason\":\"agentfm-tier3-smoke\"}" >/dev/null
}

clear_failing() {
  local m="$1"
  curl -s -X POST "$SR/admin/clear-failing" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\"}" >/dev/null
}

mark_primary_failing() {
  # 12 LiteLLM + keirouter primaries. agentfm:* 는 건드리지 않음.
  for m in \
    openrouter-nemotron-3-super tokenrouter-nemotron-3-super \
    groq-gpt-oss-120b groq-qwen3.6-27b \
    big-pickle deepseek-v4-pro kimi-k2.6 glm-5.1 minimax-m2.5 \
    keirouter:chain:fast-fallback keirouter:chain:coding-heavy \
    keirouter:chain:production
  do
    mark_failing "$m"
  done
}

clear_all_failing() {
  for m in \
    openrouter-nemotron-3-super tokenrouter-nemotron-3-super \
    groq-gpt-oss-120b groq-qwen3.6-27b \
    big-pickle deepseek-v4-pro kimi-k2.6 glm-5.1 minimax-m2.5 \
    keirouter:chain:fast-fallback keirouter:chain:coding-heavy \
    keirouter:chain:production \
    agentfm:chain:default agentfm:chain:coder \
    primary allrouter-direct allrouter-chain
  do
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
echo "=== agentfm Tier 3 smoke test (multi-agent swarm: default + coder) ==="
echo "smart-router: $SR"
echo "agentfm-api:  $AF"
echo

# A: pre-flight health.
echo "[A] pre-flight: routers healthy"
H_SR=$(curl -fsS "$SR/health" || echo "")
H_AF=$(curl -fsS "$AF/health" || echo "")
assert "smart-router healthy" '[[ "$H_SR" == *healthy* ]]' "got=$H_SR"
assert "agentfm-api healthy"  '[[ "$H_AF" == *\"status\":\"ok\"* ]]' "got=$H_AF"
echo

# B: /v1/models has 2 entries (default + coder 둘 다 등록).
echo "[B] /v1/models must have both 'default' and 'coder' workers"
MODELS_JSON=$(curl -fsS "$AF/v1/models")
N_MODELS=$(extract "$MODELS_JSON" 'print(len(d.get("data", [])))')
assert "≥2 models registered" '[[ "$N_MODELS" -ge 2 ]]' "count=$N_MODELS"
HAS_DEFAULT=$(extract "$MODELS_JSON" 'print("yes" if any(e.get("agentfm_name")=="default" for e in d.get("data",[])) else "no")')
HAS_CODER=$(extract "$MODELS_JSON" 'print("yes" if any(e.get("agentfm_name")=="coder" for e in d.get("data",[])) else "no")')
assert "/v1/models has 'default' worker" '[[ "$HAS_DEFAULT" == "yes" ]]' "got=$HAS_DEFAULT"
assert "/v1/models has 'coder' worker"   '[[ "$HAS_CODER" == "yes" ]]'   "got=$HAS_CODER"
if [[ "$N_MODELS" -ge 2 ]]; then
  for entry in $(extract "$MODELS_JSON" 'import json; print(" ".join(f"{e.get(\"agentfm_name\")}|{e.get(\"agentfm_engine\")}|{e.get(\"agentfm_status\")}" for e in d["data"]))'); do
    echo "  -> worker $entry"
  done
fi
echo

# C: direct gateway: model=default (Tier 2 regression).
echo "[C] direct agentfm gateway POST model=default"
RESP="$(mktemp)"
HTTP=$(curl -s -o "$RESP" -w '%{http_code}' \
  "$AF/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"default","messages":[{"role":"user","content":"reply with one short word"}],"max_tokens":12}')
BODY="$(cat "$RESP")"; rm -f "$RESP"
CONTENT=$(extract "$BODY" 'print(d.get("choices",[{}])[0].get("message",{}).get("content","") if d.get("choices") else "")')
assert "direct gateway model=default HTTP 200"  '[[ "$HTTP" == "200" ]]' "got=$HTTP"
assert "direct gateway model=default content"   '[[ -n "$CONTENT" ]]' "got=$CONTENT"
echo

# D: direct gateway: model=coder (Tier 3 new).
echo "[D] direct agentfm gateway POST model=coder"
RESP="$(mktemp)"
HTTP=$(curl -s -o "$RESP" -w '%{http_code}' \
  "$AF/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"coder","messages":[{"role":"user","content":"reply with one short word"}],"max_tokens":12}')
BODY="$(cat "$RESP")"; rm -f "$RESP"
CONTENT=$(extract "$BODY" 'print(d.get("choices",[{}])[0].get("message",{}).get("content","") if d.get("choices") else "")')
assert "direct gateway model=coder HTTP 200" '[[ "$HTTP" == "200" ]]' "got=$HTTP"
assert "direct gateway model=coder content"  '[[ -n "$CONTENT" ]]' "got=$CONTENT"
echo

# E: complexity routing — mark primaries + agentfm:chain:default failing,
#    POST long prompt (complex) → tried 마지막 = agentfm:chain:coder.
#    의미: default 만 죽었을 때 complexity 가 coder 로 라우팅.
echo "[E] cascade complex → agentfm:chain:coder (Tier 3 routing)"
mark_primary_failing
mark_failing agentfm:chain:default
F_CT=$(curl -fsS "$SR/admin/failing" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['failing']))")
echo "  -> failure set size = $F_CT (expected ≥13: 12 primary + agentfm:chain:default)"
assert "13 models marked failing" '[[ "$F_CT" -ge 13 ]]' "got=$F_CT"

# Long prompt: 250+ chars to push complexity over threshold (> 200).
LONG_PROMPT="Please analyze the following multi-faceted distributed systems architecture trade-off: we operate a tier-based cascade router with five layers including primary LiteLLM, secondary fallbacks, and an agentfm-based multi-agent swarm. Each tier offers different latency-versus-quality profiles. The complexity routing heuristic uses prompt length and keyword matching to decide which worker should handle a request. Describe how the coder agent would differ from the default agent in handling a complex request."

RESP="$(mktemp)"
HTTP=$(curl -s -o "$RESP" -w '%{http_code}' \
  "$SR/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "import json; print(json.dumps({'model':'auto','messages':[{'role':'user','content':'''$LONG_PROMPT'''}],'max_tokens':48}))")")
BODY="$(cat "$RESP")"; rm -f "$RESP"
TRIED=$(extract "$BODY" 'print(",".join(d.get("error",{}).get("tried", d.get("routing_info",{}).get("tried", []))))')
CONTENT=$(extract "$BODY" 'print(d.get("choices",[{}])[0].get("message",{}).get("content","") if d.get("choices") else "")')

assert "complex cascade HTTP 200" '[[ "$HTTP" == "200" ]]' "got=$HTTP"
assert "complex tried ends with agentfm:chain:coder" '[[ "$TRIED" == *agentfm:chain:coder ]]' "tried=$TRIED"
assert "complex coder content non-empty" '[[ -n "$CONTENT" ]]' "got=$CONTENT"
if [[ -n "$CONTENT" ]]; then
  echo "  -> coder content = $(echo "$CONTENT" | head -c 120)"
fi
echo

# F: cleanup + simple routing — primaries still failing, default 살림,
#    POST short prompt (simple) → tried 마지막 = agentfm:chain:default.
echo "[F] cascade simple → agentfm:chain:default (Tier 2 regression)"
clear_failing agentfm:chain:default

RESP="$(mktemp)"
HTTP=$(curl -s -o "$RESP" -w '%{http_code}' \
  "$SR/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"reply with one short word"}],"max_tokens":12}')
BODY="$(cat "$RESP")"; rm -f "$RESP"
TRIED=$(extract "$BODY" 'print(",".join(d.get("error",{}).get("tried", d.get("routing_info",{}).get("tried", []))))')
CONTENT=$(extract "$BODY" 'print(d.get("choices",[{}])[0].get("message",{}).get("content","") if d.get("choices") else "")')

assert "simple cascade HTTP 200" '[[ "$HTTP" == "200" ]]' "got=$HTTP"
assert "simple tried ends with agentfm:chain:default" '[[ "$TRIED" == *agentfm:chain:default ]]' "tried=$TRIED"
assert "simple default content non-empty" '[[ -n "$CONTENT" ]]' "got=$CONTENT"
if [[ -n "$CONTENT" ]]; then
  echo "  -> default content = $(echo "$CONTENT" | head -c 120)"
fi
echo

# G: full cleanup + baseline regression.
echo "[G] clearing all failing"
clear_all_failing
echo

echo "[H] regression: baseline LiteLLM tier serves real completion"
RESP="$(mktemp)"
# max_tokens=24 — small open-source fast models (qwen3.6-27b, nemotron-3-super)
# need >6 tokens to clear their "The user wants me to say..." preamble and
# reach an answer; otherwise finish_reason=length with empty-ish content.
HTTP=$(curl -s -o "$RESP" -w '%{http_code}' \
  "$SR/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"Say only: pong"}],"max_tokens":24}')
BODY="$(cat "$RESP")"; rm -f "$RESP"
R_MODEL=$(extract "$BODY" 'print(d.get("routing_info",{}).get("model","?"))')
R_CONTENT=$(extract "$BODY" 'print(d.get("choices",[{}])[0].get("message",{}).get("content","") if d.get("choices") else "")')

assert "baseline HTTP 200" '[[ "$HTTP" == "200" ]]' "got=$HTTP"
assert "baseline did NOT use agentfm" '[[ "$R_MODEL" != agentfm* ]]' "model=$R_MODEL"
assert "baseline content non-empty" '[[ -n "$R_CONTENT" ]]' "got=$R_CONTENT"
echo "  -> baseline model=$R_MODEL"

echo
echo "================================================"
echo "agentfm Tier 3 smoke: $pass passed, $fail failed"
echo "================================================"
[ "$fail" -eq 0 ] || exit 1
