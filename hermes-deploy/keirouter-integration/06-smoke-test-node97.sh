#!/bin/bash
# End-to-end smoke test for keirouter-fallback integration on node97.
# Same as 06-smoke-test.sh but port 14001 (smart-router) and a longer LiteLLM model
# list covering the slow + fast pools configured in /opt/smart-router/config.json.
# Reads KEIROUTER_KEY from /etc/hermes/keirouter.env.
set -uo pipefail

SR=http://127.0.0.1:14001
KR=http://127.0.0.1:20180
ENV_FILE=/etc/hermes/keirouter.env

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found. Run 01-save-keirouter-key.sh first." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"
KR_KEY="$KEIROUTER_KEY"

pass=0
fail=0

mark_failing() {
  local m="$1"
  curl -s -X POST $SR/admin/mark-failing \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"ttl_seconds\":600,\"reason\":\"smoke-test\"}" >/dev/null
}
clear_failing() {
  local m="$1"
  curl -s -X POST $SR/admin/clear-failing \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\"}" >/dev/null
}
clear_all_failing() {
  # node97 smart-router config.json has these models
  local models=(
    openrouter-nemotron-3-super tokenrouter-nemotron-3-super
    groq-gpt-oss-120b groq-qwen3.6-27b
    big-pickle deepseek-v4-pro kimi-k2.6 glm-5.1 minimax-m2.5
    keirouter:chain:fast-fallback keirouter:chain:coding-heavy
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
extract_field() {
  python3 -c "import sys,json; d=json.loads(sys.argv[1]); $2" "$1" 2>/dev/null
}

clear_all_failing

echo "=== A: smart-router healthy ==="
H=$(curl -s $SR/health)
assert "smart-router reports healthy" '[[ "$H" == *healthy* ]]' "got=$H"
echo

echo "=== B: keirouter chain:fast-fallback responds ==="
RB=$(curl -s -X POST $KR/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KR_KEY" \
  -d '{"model":"chain:fast-fallback","messages":[{"role":"user","content":"2+2?"}]}')
MODEL_B=$(extract_field "$RB" "print(d.get('model','?'))")
CHOICE_B=$(extract_field "$RB" "print(bool(d.get('choices')))")
assert "keirouter returns 200 with choices" '[[ "$CHOICE_B" == "True" ]]' "raw=$RB"
echo "  -> model=$MODEL_B"
echo

echo "=== C: keirouter chain:coding-heavy responds ==="
RC=$(curl -s -X POST $KR/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KR_KEY" \
  -d '{"model":"chain:coding-heavy","messages":[{"role":"user","content":"refactor async Python. one sentence."}]}')
MODEL_C=$(extract_field "$RC" "print(d.get('model','?'))")
CHOICE_C=$(extract_field "$RC" "print(bool(d.get('choices')))")
assert "coding-heavy returns 200 with choices" '[[ "$CHOICE_C" == "True" ]]' "raw=$RC"
echo "  -> model=$MODEL_C"
echo

echo "=== D: smart-router baseline picks a LiteLLM model ==="
RD=$(curl -s -X POST $SR/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"hi"}]}')
MODEL_D=$(extract_field "$RD" "print(d.get('model','?'))")
TRIED_D=$(extract_field "$RD" "print(','.join(d.get('routing_info',{}).get('tried',[])))")
CHOICE_D=$(extract_field "$RD" "print(bool(d.get('choices')))")
assert "baseline returns 200" '[[ "$CHOICE_D" == "True" ]]' "raw=$RD"
assert "baseline top-level model NOT keirouter" '[[ "$MODEL_D" != keirouter* && "$MODEL_D" != tokenrouter-gpt-5.4-mini ]]' "got=$MODEL_D"
echo "  -> model=$MODEL_D tried=$TRIED_D"
echo

echo "=== E: all LiteLLM models failing -> keirouter takes over ==="
echo "  marking fast + slow LiteLLM models failing via /admin/mark-failing..."
for m in openrouter-nemotron-3-super tokenrouter-nemotron-3-super \
         groq-gpt-oss-120b groq-qwen3.6-27b \
         big-pickle deepseek-v4-pro kimi-k2.6 glm-5.1 minimax-m2.5; do
  mark_failing "$m"
done
FAIL_CT=$(curl -s $SR/admin/failing | python3 -c "import sys,json; print(len(json.load(sys.stdin)['failing']))")
echo "  -> failure set size = $FAIL_CT"
RE=$(curl -s -X POST $SR/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"ping during keirouter fallback"}]}')
TOP_E=$(extract_field "$RE" "print(d.get('model','?'))")
TRIED_E=$(extract_field "$RE" "print(','.join(d.get('routing_info',{}).get('tried',[])))")
CHOICE_E=$(extract_field "$RE" "print(bool(d.get('choices')))")
echo "  -> top-level model=$TOP_E tried=$TRIED_E"
assert "post-exhaustion request still returns 200" '[[ "$CHOICE_E" == "True" ]]' "raw=$RE"
assert "tried list includes keirouter:chain:fast-fallback" '[[ "$TRIED_E" == *keirouter:chain:fast-fallback* ]]' "tried=$TRIED_E"
assert "top-level model is the keirouter upstream" '[[ "$TOP_E" == *tokenrouter-gpt-5.4-mini* ]]' "got=$TOP_E"
echo

echo "=== F: /admin/failing list reflects marks; /admin/clear-failing restores ==="
F_BEFORE=$(curl -s $SR/admin/failing | python3 -c "import sys,json; print(len(json.load(sys.stdin)['failing']))")
clear_failing "groq-gpt-oss-120b"
clear_failing "big-pickle"
F_AFTER=$(curl -s $SR/admin/failing | python3 -c "import sys,json; print(len(json.load(sys.stdin)['failing']))")
assert "list-failing count decreased after clear-failing" '[[ "$F_AFTER" -lt "$F_BEFORE" ]]' "before=$F_BEFORE after=$F_AFTER"
clear_all_failing
RF=$(curl -s -X POST $SR/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"hi after restore"}]}')
TOP_F=$(extract_field "$RF" "print(d.get('model','?'))")
CHOICE_F=$(extract_field "$RF" "print(bool(d.get('choices')))")
assert "after clear-failing baseline uses LiteLLM" '[[ "$CHOICE_F" == "True" && "$TOP_F" != *tokenrouter-gpt-5.4-mini* ]]' "model=$TOP_F"
echo

echo "=== G: keirouter down -> 503 with tried list when LiteLLM also exhausted ==="
for m in openrouter-nemotron-3-super tokenrouter-nemotron-3-super \
         groq-gpt-oss-120b groq-qwen3.6-27b \
         big-pickle deepseek-v4-pro kimi-k2.6 glm-5.1 minimax-m2.5; do
  mark_failing "$m"
done
docker stop keirouter-keirouter-1 >/dev/null 2>&1
sleep 3
RG=$(curl -s -o /tmp/rg.body -w "%{http_code}" -X POST $SR/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"hi"}]}')
echo "  -> http=$RG"
assert "503 when both LiteLLM and keirouter unreachable" '[[ "$RG" == "503" ]]' "got=$RG"
TRIED_G=$(extract_field "$(cat /tmp/rg.body)" "print(','.join(d.get('error',{}).get('tried',[])))")
assert "tried list contains keirouter:chain:fast-fallback" '[[ "$TRIED_G" == *keirouter:chain:fast-fallback* ]]' "tried=$TRIED_G"
docker start keirouter-keirouter-1 >/dev/null 2>&1
sleep 5
clear_all_failing
echo

echo "================================================"
echo "smoke test result: $pass passed, $fail failed"
echo "================================================"
[ "$fail" -eq 0 ] || exit 1
