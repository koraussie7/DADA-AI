#!/bin/bash
# Save keirouter API key to /etc/hermes/keirouter.env (mode 0600, never commit)
# Run on node110
#
# Pass the key via env var: KROUTER_API_KEY="sk-..." sudo bash 01-save-keirouter-key.sh
# Or pipe it: echo "sk-..." | sudo bash 01-save-keirouter-key.sh
#
# The key is NEVER stored in this script or anywhere in git — it only
# lives in /etc/hermes/keirouter.env on the node, mode 0600.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: must run as root (use sudo)" >&2
  exit 1
fi

# Acquire from $KROUTER_API_KEY env var, or read from stdin
if [ -n "${KROUTER_API_KEY:-}" ]; then
  KROUTER_KEY="$KROUTER_API_KEY"
elif [ ! -t 0 ]; then
  KROUTER_KEY=$(cat)
else
  echo "ERROR: pass key as KROUTER_API_KEY env var or via stdin" >&2
  exit 1
fi

if [ -z "$KROUTER_KEY" ]; then
  echo "ERROR: empty key" >&2
  exit 1
fi

mkdir -p /etc/hermes
umask 077
cat > /etc/hermes/keirouter.env.tmp <<EOF
# keirouter API key for smart-router fallback integration
# Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)  -- NEVER COMMIT THIS FILE
KEIROUTER_URL=http://127.0.0.1:20180
KEIROUTER_KEY=${KROUTER_KEY}
EOF
chmod 0600 /etc/hermes/keirouter.env.tmp
chown root:root /etc/hermes/keirouter.env.tmp
mv -f /etc/hermes/keirouter.env.tmp /etc/hermes/keirouter.env

ls -l /etc/hermes/keirouter.env
echo "OK keirouter.env written with mode 0600"
