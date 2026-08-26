#!/bin/bash
# Create coding-heavy and fast-fallback chains in keirouter dashboard.
# Reuses existing "production" chain; adds 2 new chains with priority strategy.
#
# Run on node110.
#
# Reads KEIROUTER_KEY from /etc/hermes/keirouter.env (mode 0600). Run
# 01-save-keirouter-key.sh first if not present.

set -euo pipefail

KROUTER_URL="http://127.0.0.1:20180"
ENV_FILE=/etc/hermes/keirouter.env

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found. Run 01-save-keirouter-key.sh first." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"
if [ -z "${KEIROUTER_KEY:-}" ]; then
  echo "ERROR: KEIROUTER_KEY not in $ENV_FILE" >&2
  exit 1
fi
KROUTER_KEY="$KEIROUTER_KEY"

COOKIES=/tmp/keirouter.cookies

curl -sf -c "$COOKIES" -X POST "$KROUTER_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"password":"keirouter"}' > /dev/null

create_chain() {
  local name="$1"
  local json="$2"

  echo "==> creating chain: $name"
  resp=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -b "$COOKIES" \
    -X POST "$KROUTER_URL/api/chains" \
    -H "Content-Type: application/json" \
    -d "$json")
  body=$(echo "$resp" | sed '/HTTP_STATUS/d')
  status=$(echo "$resp" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
  echo "  status=$status body=$body"
  [ "$status" = "200" ] || [ "$status" = "201" ] || return 1
  echo
}

create_chain "coding-heavy" '{
  "name": "coding-heavy",
  "strategy": "latency",
  "fallback_provider": "custom-openai",
  "fallback_model": "claude-sonnet-4-5",
  "steps": [
    {"provider": "openrouter", "model": "anthropic/claude-sonnet-4"},
    {"provider": "nvidia", "model": "meta/llama-3.1-405b-instruct"},
    {"provider": "cerebras", "model": "qwen-2.5-coder-32b"},
    {"provider": "custom-openai-tokenrouter", "model": "qwen/qwen3-coder-free"},
    {"provider": "custom-openai", "model": "claude-sonnet-4-5"}
  ]
}'

create_chain "fast-fallback" '{
  "name": "fast-fallback",
  "strategy": "priority",
  "fallback_provider": "custom-openai",
  "fallback_model": "claude-sonnet-4-5",
  "steps": [
    {"provider": "groq", "model": "qwen/qwen3.6-27b"},
    {"provider": "cerebras", "model": "llama-3.3-70b"},
    {"provider": "custom-openai-tokenrouter", "model": "qwen/qwen3.8-max-free"},
    {"provider": "openrouter", "model": "meta/llama-3.1-8b-instruct:free"},
    {"provider": "custom-openai", "model": "claude-sonnet-4-5"}
  ]
}'

echo "==> listing all chains"
curl -sf -b "$COOKIES" "$KROUTER_URL/api/chains" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'  - {c[\"name\"]} ({c[\"strategy\"]}, {len(c[\"steps\"])} steps)') for c in d.get('chains',[])]"
