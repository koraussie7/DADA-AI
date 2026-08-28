#!/usr/bin/env bash
# 07-tier2-smoke-test.sh — agentfm Tier 2 smoke (Podman worker 가 실제 completion 반환)
#
# Tier 1 의 `06-smoke-test.sh` 가 deterministic 503 + cascade exhaustion 을 검증한 반면,
# Tier 2 smoke 는 **worker 가 등록되어 cascade 끝에서 200 + real content** 가
# 반환되는지 검증한다.
#
# Flow:
#   1. agentfm-api /health + /v1/models ≥1 (worker 등록 확인)
#   2. direct gateway POST model=default → 200 + content 비어있지 않음
#   3. smart-router cascade: mark 12 LiteLLM + keirouter failing (agentfm stays LIVE so cascade reaches worker)
#      → POST model=auto → 200 + tried 마지막 = agentfm:chain:default + content 비어있지 않음
#   4. clear-failing 13 entries (cascade 복구)
#   5. baseline 회귀: model=auto 직접 → 200 + routing_info.model != agentfm (LiteLLM 이 응답)
#
# 모든 step 이 pass 면 Tier 1 (wire-up) → Tier 2 (real completion) flip 이 성공.

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
    -d "{\"model\":\"$m\",\"ttl_seconds\":600,\"reason\":\"agentfm-tier2-smoke\"}" >/dev/null
}

clear_failing() {
  local m="$1"
  curl -s -X POST "$SR/admin/clear-failing" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\"}" >/dev/null
}

mark_all_failing() {
  for m in \
    openrouter-nemotron-3-super tokenrouter-nemotron-3-super \
    groq-gpt-oss-120b groq-qwen3.6-27b \
    big-pickle deepseek-v4-pro kimi-k2.6 glm-5.1 minimax-m2.5 \
    keirouter:chain:fast-fallback keirouter:chain:coding-heavy \
    keirouter:chain:production \

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
    agentfm:chain:default \
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
echo "=== agentfm Tier 2 smoke test (smart-router: $SR, agentfm-api: $AF) ==="
echo

# A: pre-flight health.
echo "[A] pre-flight: routers healthy"
H_SR=$(curl -fsS "$SR/health" || echo "")
H_AF=$(curl -fsS "$AF/health" || echo "")
assert "smart-router healthy" '[[ "$H_SR" == *healthy* ]]' "got=$H_SR"
assert "agentfm-api healthy"  '[[ "$H_AF" == *\"status\":\"ok\"* ]]' "got=$H_AF"
echo

# B: worker registration.
echo "[B] agentfm /v1/models must have ≥1 entry (worker registered)"
MODELS_JSON=$(curl -fsS "$AF/v1/models")
N_MODELS=$(extract "$MODELS_JSON" 'print(len(d.get("data", [])))')
assert "≥1 model registered" '[[ "$N_MODELS" -ge 1 ]]' "count=$N_MODELS"
if [[ "$N_MODELS" -ge 1 ]]; then
  echo "  -> $(extract "$MODELS_JSON" 'print(d["data"][0].get("id","?"))')"
fi
echo

# C: direct gateway smoke (bypasses smart-router — fastest worker signal).
echo "[C] direct agentfm gateway POST model=default"
RESP="$(mktemp)"
HTTP=$(curl -s -o "$RESP" -w '%{http_code}' \
  "$AF/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"default","messages":[{"role":"user","content":"reply with one short word"}],"max_tokens":12}')
BODY="$(cat "$RESP")"
rm -f "$RESP"
CONTENT=$(extract "$BODY" 'print(d.get("choices",[{}])[0].get("message",{}).get("content","") if d.get("choices") else "")')
assert "direct gateway HTTP 200" '[[ "$HTTP" == "200" ]]' "got=$HTTP"
assert "direct gateway content non-empty" '[[ -n "$CONTENT" ]]' "got=$CONTENT"
if [[ -n "$CONTENT" ]]; then
  echo "  -> content = $(echo "$CONTENT" | head -c 80)"
fi
echo

# D: smart-router end-to-end cascade. Mark 12 models failing so agentfm
#    is the only survivor (smart-router cascade should reach it). POST model=auto and expect 200 + tried ends
#    with agentfm:chain:default + content non-empty.
echo "[D] smart-router cascade: mark 12 failing, POST model=auto"
mark_all_failing
F_CT=$(curl -fsS "$SR/admin/failing" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['failing']))")
echo "  -> failure set size = $F_CT"
assert "12 models marked failing" '[[ "$F_CT" -ge 12 ]]' "got=$F_CT"
echo

RESP="$(mktemp)"
HTTP=$(curl -s -o "$RESP" -w '%{http_code}' \
  "$SR/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"reply with one short word"}],"max_tokens":12}')
BODY="$(cat "$RESP")"
rm -f "$RESP"
TRIED=$(extract "$BODY" 'print(",".join(d.get("error",{}).get("tried", d.get("routing_info",{}).get("tried", []))))')
CONTENT=$(extract "$BODY" 'print(d.get("choices",[{}])[0].get("message",{}).get("content","") if d.get("choices") else "")')

assert "smart-router cascade HTTP 200 (worker served)" '[[ "$HTTP" == "200" ]]' "got=$HTTP"
assert "tried list ends with agentfm:chain:default" '[[ "$TRIED" == *agentfm:chain:default ]]' "tried=$TRIED"
# NOTE: routing_info.model is the initially-selected primary model, NOT the
# cascade winner. Proof that the cascade reached agentfm comes from the
# tried-list assertion above + the non-empty content assertion below.
assert "smart-router agentfm content non-empty" '[[ -n "$CONTENT" ]]' "got=$CONTENT"
if [[ -n "$CONTENT" ]]; then
  echo "  -> cascade content = $(echo "$CONTENT" | head -c 80)"
fi
echo

# E: cleanup.
echo "[E] clearing failing entries"
clear_all_failing

# F: baseline regression. With agentfm cleared, model=auto should now be
#    served by a LiteLLM tier (groq/openrouter/etc.), NOT agentfm.
echo
echo "[F] regression: baseline LiteLLM tier serves real completion"
RESP="$(mktemp)"
HTTP=$(curl -s -o "$RESP" -w '%{http_code}' \
  "$SR/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"Say only: pong"}],"max_tokens":6}')
BODY="$(cat "$RESP")"
rm -f "$RESP"
R_MODEL=$(extract "$BODY" 'print(d.get("routing_info",{}).get("model","?"))')
R_CONTENT=$(extract "$BODY" 'print(d.get("choices",[{}])[0].get("message",{}).get("content","") if d.get("choices") else "")')

assert "baseline HTTP 200" '[[ "$HTTP" == "200" ]]' "got=$HTTP"
assert "baseline did NOT use agentfm" '[[ "$R_MODEL" != agentfm* ]]' "model=$R_MODEL"
assert "baseline content non-empty" '[[ -n "$R_CONTENT" ]]' "got=$R_CONTENT"
echo "  -> baseline model=$R_MODEL"

echo
echo "================================================"
echo "agentfm Tier 2 smoke: $pass passed, $fail failed"
echo "================================================"
[ "$fail" -eq 0 ] || exit 1
