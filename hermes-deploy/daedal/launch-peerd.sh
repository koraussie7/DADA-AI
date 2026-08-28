#!/usr/bin/env bash
# Idempotent installer for the peerd Chrome MV3 extension that
# Hermes Desktop loads as a sidecar at runtime.
#
# Layout (after this script):
#   ~/.hermes/peerd/                   (git clone, working tree)
#   ~/.hermes/peerd/extension/         (the actual MV3 extension)
#   ~/.hermes/peerd/.hermes-deploy-tag (last successful run marker)
#
# Usage:
#   launch-peerd.sh             # clone if missing, else pull --ff-only
#   launch-peerd.sh --force     # remove existing clone first
#   launch-peerd.sh --pin <ref> # clone / checkout specific ref (branch/tag/sha)
set -euo pipefail

PEERD_HOME="${HERMES_HOME:-$HOME/.hermes}"
PEERD_DIR="${PEERD_HOME}/peerd"
PEERD_REPO="${PEERD_REPO:-https://github.com/NotASithLord/peerd.git}"
PEERD_REF=""   # populated by --pin

force=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) force=1; shift ;;
    --pin)   PEERD_REF="${2:-}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 64 ;;
  esac
done

log() { printf '[peerd] %s\n' "$*"; }
err() { printf '[peerd][error] %s\n' "$*" >&2; }

if ! command -v git >/dev/null 2>&1; then
  err "git not found in PATH"; exit 69
fi

if [[ -d "$PEERD_DIR/.git" ]]; then
  if [[ "$force" == "1" ]]; then
    log "removing existing clone (--force): $PEERD_DIR"
    rm -rf "$PEERD_DIR"
  fi
fi

if [[ ! -d "$PEERD_DIR/.git" ]]; then
  mkdir -p "$PEERD_HOME"
  log "cloning $PEERD_REPO -> $PEERD_DIR"
  if ! git clone --depth=1 "$PEERD_REPO" "$PEERD_DIR"; then
    err "clone failed (network or repo moved?)"; exit 1
  fi
  if [[ -n "$PEERD_REF" ]]; then
    log "fetching ref $PEERD_REF"
    git -C "$PEERD_DIR" fetch --depth=1 origin "$PEERD_REF"
    git -C "$PEERD_DIR" checkout FETCH_HEAD
  fi
else
  log "existing clone detected; pulling --ff-only"
  if ! git -C "$PEERD_DIR" pull --ff-only --depth=1 2>/dev/null; then
    # Fallback: maybe the ref changed upstream; try a fetch+reset
    log "ff-only pull failed; attempting fetch+reset to origin/HEAD"
    git -C "$PEERD_DIR" fetch --depth=1 origin HEAD || true
    git -C "$PEERD_DIR" reset --hard origin/HEAD || {
      err "pull failed and reset failed; run with --force to reclone"
      exit 1
    }
  fi
fi

# Sanity: extension dir must exist with manifest.json
if [[ ! -f "$PEERD_DIR/extension/manifest.json" ]]; then
  err "extension/manifest.json missing under $PEERD_DIR — peerd layout changed?"
  err "  open an issue; Path A integration is gated on this path."
  exit 1
fi

# Marker (atomic write)
local_rev="$(git -C "$PEERD_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
printf '%s\n' "$local_rev" > "$PEERD_DIR/.hermes-deploy-tag"
log "peerd ready at $PEERD_DIR (rev: ${local_rev:0:12})"
log "extension manifest: $PEERD_DIR/extension/manifest.json"
