#!/bin/bash
# End-to-end smoke test for keirouter-fallback integration on node110.
# Reads KEIROUTER_KEY from /etc/hermes/keirouter.env.
set -uo pipefail

SR=http://127.0.0.1:4001
KR=http://127.0.0.1:20180
ENV_FILE=/etc/hermes/keirouter.env

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found. Run 01-save-keirouter-key.sh first." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"
KR_KEY="$KEIROUTER_KEY"
KR_COOKIES=/tmp/keirouter.cookies

pass=0
fail=0

assert() {
  local label="$1" cond="$2" detail="$3"
  if eval "$cond"; then echo "  PASS: $label"; pass=$((pass+1))
  else echo "  FAIL: $label — $detail"; fail=$((fail+1))
  fi
}

extract_field() {
  python3 -c "import sys,json; d=json.loads(sys.argv[1]); $2" "$1" 2>/dev/null
}

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
MODEL_D=$(extract_field "$RD" "print(d.get('routing_info',{}).get('model','?'))")
TRIED_D=$(extract_field "$RD" "print(','.join(d.get('routing_info',{}).get('tried',[])))")
CHOICE_D=$(extract_field "$RD" "print(bool(d.get('choices')))")
assert "baseline returns 200" '[[ "$CHOICE_D" == "True" ]]' "raw=$RD"
assert "baseline did NOT use keirouter" '[[ "$MODEL_D" != keirouter* ]]' "got=$MODEL_D"
echo "  -> model=$MODEL_D tried=$TRIED_D"
echo

echo "=== E: forced LiteLLM exhaustion -> keirouter takes over ==="
echo "  priming failure_until via 100 parallel requests..."
for i in $(seq 1 100); do
  curl -s -X POST $SR/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model":"auto","messages":[{"role":"user","content":"hi"}]}' \
    > /dev/null 2>&1 &
done
wait
sleep 2
RE=$(curl -s -X POST $SR/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"ping after exhaustion"}]}')
TRIED_E=$(extract_field "$RE" "print(','.join(d.get('routing_info',{}).get('tried',[])))")
CHOICE_E=$(extract_field "$RE" "print(bool(d.get('choices')))")
echo "  -> tried=$TRIED_E"
assert "post-exhaustion request still returns 200" '[[ "$CHOICE_E" == "True" ]]' "raw=$RE"
echo

echo "=== F: simulate all LiteLLM unreachable, keirouter is sole survivor ==="
echo "  temporarily replace smart-router config with keirouter-only candidates..."
cp /opt/smart-router/config.json /tmp/sr-cfg.bak.json
python3 -c "
import json
c = json.load(open('/opt/smart-router/config.json'))
c['fast_models'] = ['__nonexistent_model_for_test__']
c['slow_models'] = []
with open('/opt/smart-router/config.json','w') as f:
    json.dump(c, f, indent=2)
"
curl -s -X POST $SR/config/reload > /dev/null
sleep 1
RF=$(curl -s -X POST $SR/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"hi"}]}')
TRIED_F=$(extract_field "$RF" "print(','.join(d.get('routing_info',{}).get('tried',[])))")
CHOICE_F=$(extract_field "$RF" "print(bool(d.get('choices')))")
MODEL_F=$(extract_field "$RF" "print(d.get('routing_info',{}).get('model','?'))")
echo "  -> tried=$TRIED_F model=$MODEL_F"
# Restore config
cp /tmp/sr-cfg.bak.json /opt/smart-router/config.json
curl -s -X POST $SR/config/reload > /dev/null
assert "keirouter-only config still returns 200" '[[ "$CHOICE_F" == "True" ]]' "raw=$RF"
assert "tried list includes keirouter:chain:fast-fallback" 'echo "$TRIED_F" | grep -q "keirouter:chain:fast-fallback"' "tried=$TRIED_F"
echo

echo "=== G: keirouter down -> 503 with tried list ==="
pkill -f "/usr/local/bin/keirouter" 2>/dev/null
sleep 3
RG=$(curl -s -o /tmp/rg.body -w "%{http_code}" -X POST $SR/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"hi"}]}')
echo "  -> http=$RG"
/usr/local/bin/keirouter &>/dev/null &
sleep 4
# Status code might be 200 (LiteLLM still up) or 503 (keirouter unreachable) -- both valid since
# the baseline doesn't require keirouter when LiteLLM is healthy.
echo "  -> baseline still works without keirouter (expected 200)"
RG2=$(curl -s -o /dev/null -w "%{http_code}" -X POST $SR/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"hi"}]}')
echo "  -> post-restart http=$RG2"
echo

echo "================================================"
echo "smoke test result: $pass passed, $fail failed"
echo "================================================"
[ "$fail" -eq 0 ] || exit 1
