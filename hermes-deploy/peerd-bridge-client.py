#!/usr/bin/env python3
"""Phase 2.5 — Python client for the Hermes Desktop ↔ peerd HTTP bridge.

Hermes Desktop exposes a localhost-only HTTP endpoint so hermes-agent can
drive peerd without going through the renderer iframe:

    POST /peerd-bridge/invoke
        Authorization: Bearer <token>
        { "type": "<peerd route>", "payload": <any>, "timeoutMs"?: <int> }
      → 200 { "ok": true,  "data": <peerd response> }
        4xx/5xx { "ok": false, "error": "..." }

Usage:

    from peerd_bridge_client import PeerdBridgeClient

    client = PeerdBridgeClient.from_userdata()   # reads token from disk
    tabs = client.invoke("tab/list")             # short route, 30s
    client.invoke("vault/unlock", {"password": "..."})   # long route, 300s
    client.close()

Stdlib-only (urllib). No `requests` / `aiohttp` dependency.
"""

from __future__ import annotations

import json
import os
import socket
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Mapping, Optional

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
DEFAULT_TIMEOUT_S = 30.0

# Mirror the renderer's LONG_ROUTES set (see relay.js). Any route listed
# here gets the long timeout by default unless the caller overrides `timeout`.
LONG_ROUTES = frozenset({"vault/unlock", "vault/init", "webvm/launch", "tab/drive"})
LONG_TIMEOUT_S = 300.0


class PeerdBridgeError(RuntimeError):
    """A non-ok response from the bridge, or a transport-level failure."""


class PeerdBridgeClient:
    """Thin blocking client around the Hermes Desktop peerd-bridge HTTP server.

    Construct one per process and reuse it. The client is thread-safe enough
    for sequential calls; concurrent callers should hold their own instance.
    """

    def __init__(
        self,
        base_url: Optional[str] = None,
        token: Optional[str] = None,
        *,
        default_timeout: float = DEFAULT_TIMEOUT_S,
    ) -> None:
        if base_url is None:
            host = os.environ.get("HERMES_PEERD_BRIDGE_HOST", DEFAULT_HOST)
            port = int(os.environ.get("HERMES_PEERD_BRIDGE_PORT", DEFAULT_PORT))
            base_url = f"http://{host}:{port}"
        if token is None:
            token = os.environ.get("HERMES_PEERD_BRIDGE_TOKEN", "")
        if not token:
            raise PeerdBridgeError(
                "no bridge token; pass token= or set HERMES_PEERD_BRIDGE_TOKEN"
            )
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.default_timeout = float(default_timeout)
        self._closed = False

    # ----- factories ----------------------------------------------------

    @classmethod
    def from_userdata(
        cls, *, user_data_dir: Optional[Path] = None, base_url: Optional[str] = None
    ) -> "PeerdBridgeClient":
        """Read the persisted token from <userData>/peerd-bridge.token.

        Honours HERMES_USER_DATA_DIR / HERMES_PEERD_BRIDGE_TOKEN_PATH env
        overrides so tests / packaged installs can redirect it.
        """
        if user_data_dir is None:
            env = os.environ.get("HERMES_USER_DATA_DIR")
            user_data_dir = Path(env) if env else default_user_data_dir()
        override = os.environ.get("HERMES_PEERD_BRIDGE_TOKEN_PATH")
        token_path = Path(override) if override else user_data_dir / "peerd-bridge.token"
        if not token_path.exists():
            raise PeerdBridgeError(
                f"peerd-bridge token not found at {token_path}; "
                "is Hermes Desktop running with the bridge enabled?"
            )
        # mode-check best-effort: warn (don't fail) if the token is too permissive
        try:
            mode = token_path.stat().st_mode & 0o777
            if mode & 0o044:
                sys.stderr.write(
                    f"[peerd-bridge] WARNING: {token_path} is world-readable "
                    f"(mode={oct(mode)}); bridge token should be 0600\n"
                )
        except OSError:
            pass
        token = token_path.read_text("utf-8").strip()
        return cls(base_url=base_url, token=token)

    # ----- public API ---------------------------------------------------

    def invoke(
        self,
        type_: str,
        payload: Any = None,
        *,
        timeout: Optional[float] = None,
    ) -> Any:
        """Send a peerd request through the bridge.

        Args:
            type_: peerd route (e.g. "tab/list", "vault/unlock").
            payload: optional JSON-serializable body forwarded to peerd.
            timeout: request timeout in seconds. Defaults to 30s for short
                routes and 300s for routes in ``LONG_ROUTES``.

        Returns:
            The ``data`` field of the JSON response.

        Raises:
            PeerdBridgeError: on non-2xx HTTP, transport failures, or if the
                response shape is unexpected.
        """
        if self._closed:
            raise PeerdBridgeError("client is closed")

        body: dict[str, Any] = {"type": type_}
        if payload is not None:
            body["payload"] = payload
        if timeout is None:
            timeout = LONG_TIMEOUT_S if type_ in LONG_ROUTES else self.default_timeout
        # Server expects integer milliseconds; coerce here so callers can
        # speak in seconds (more pythonic) without losing precision.
        body["timeoutMs"] = max(1, int(timeout * 1000))

        data = json.dumps(body, ensure_ascii=False, allow_nan=False).encode("utf-8")
        req = urllib.request.Request(
            f"{self.base_url}/peerd-bridge/invoke",
            data=data,
            method="POST",
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json; charset=utf-8",
                "Accept": "application/json",
            },
        )

        # urllib's `timeout` covers connect+read; we don't need a separate
        # deadline because the server enforces the per-route timeoutMs.
        try:
            with urllib.request.urlopen(req, timeout=timeout + 5) as resp:
                raw = resp.read()
        except urllib.error.HTTPError as err:
            # The server returns 4xx/5xx with {ok:false, error:"..."} — try
            # to surface that body verbatim instead of just the HTTP reason.
            message = _extract_error_body(err) or err.reason or "HTTP error"
            raise PeerdBridgeError(f"{err.code} {message}") from err
        except urllib.error.URLError as err:
            reason = err.reason
            if isinstance(reason, socket.timeout):
                raise PeerdBridgeError(
                    f"timeout after {timeout:.1f}s contacting {self.base_url}"
                ) from err
            raise PeerdBridgeError(
                f"cannot reach peerd-bridge at {self.base_url}: {reason}"
            ) from err
        except (socket.timeout, TimeoutError) as err:
            raise PeerdBridgeError(
                f"timeout after {timeout:.1f}s contacting {self.base_url}"
            ) from err
        except OSError as err:
            raise PeerdBridgeError(
                f"transport error contacting {self.base_url}: {err}"
            ) from err

        try:
            parsed = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as err:
            raise PeerdBridgeError(f"invalid JSON response: {err}") from err

        if not isinstance(parsed, Mapping):
            raise PeerdBridgeError(f"unexpected response shape: {parsed!r}")
        if not parsed.get("ok"):
            err_msg = parsed.get("error") or "unknown bridge error"
            raise PeerdBridgeError(str(err_msg))
        return parsed.get("data")

    def close(self) -> None:
        """No-op for now (no persistent connection). Reserved for symmetry."""
        self._closed = True

    # ----- context manager ----------------------------------------------

    def __enter__(self) -> "PeerdBridgeClient":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def __repr__(self) -> str:
        return f"PeerdBridgeClient(base_url={self.base_url!r})"


# ----- helpers ---------------------------------------------------------

def _extract_error_body(err: urllib.error.HTTPError) -> Optional[str]:
    try:
        raw = err.read()
        if not raw:
            return None
        parsed = json.loads(raw.decode("utf-8"))
        if isinstance(parsed, Mapping):
            return parsed.get("error") or json.dumps(parsed)
        return str(parsed)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return None


def default_user_data_dir() -> Path:
    """Best-effort platform default matching Electron's app.getPath('userData')."""
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "Hermes Desktop"
    if sys.platform == "win32":
        appdata = os.environ.get("APPDATA")
        if appdata:
            return Path(appdata) / "Hermes Desktop"
        return Path.home() / "AppData" / "Roaming" / "Hermes Desktop"
    # linux + others
    xdg = os.environ.get("XDG_CONFIG_HOME")
    base = Path(xdg) if xdg else Path.home() / ".config"
    return base / "Hermes Desktop"


# ----- CLI -----------------------------------------------------------

def _main(argv: list[str]) -> int:
    import argparse

    parser = argparse.ArgumentParser(
        description="Probe the Hermes Desktop peerd-bridge.",
    )
    parser.add_argument("type", help="peerd route, e.g. tab/list")
    parser.add_argument(
        "--payload", "-p", default="{}", help="JSON payload (string or @file)"
    )
    parser.add_argument("--host", default=os.environ.get("HERMES_PEERD_BRIDGE_HOST", DEFAULT_HOST))
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("HERMES_PEERD_BRIDGE_PORT", DEFAULT_PORT)),
    )
    parser.add_argument(
        "--token",
        default=os.environ.get("HERMES_PEERD_BRIDGE_TOKEN"),
        help="bearer token (default: $HERMES_PEERD_BRIDGE_TOKEN or $HERMES_USER_DATA_DIR/peerd-bridge.token)",
    )
    parser.add_argument("--timeout", type=float, default=None)
    args = parser.parse_args(argv)

    token = args.token
    if not token:
        try:
            client = PeerdBridgeClient.from_userdata(
                base_url=f"http://{args.host}:{args.port}"
            )
        except PeerdBridgeError as err:
            print(f"error: {err}", file=sys.stderr)
            return 2
    else:
        client = PeerdBridgeClient(
            base_url=f"http://{args.host}:{args.port}",
            token=token,
        )

    payload_text = args.payload
    if payload_text.startswith("@"):
        payload_text = Path(payload_text[1:]).read_text("utf-8")
    try:
        payload = json.loads(payload_text) if payload_text.strip() else None
    except json.JSONDecodeError as err:
        print(f"error: invalid JSON payload: {err}", file=sys.stderr)
        return 2

    started = time.monotonic()
    try:
        result = client.invoke(args.type, payload, timeout=args.timeout)
    except PeerdBridgeError as err:
        print(f"error: {err}", file=sys.stderr)
        return 1
    elapsed = time.monotonic() - started
    print(json.dumps({"elapsed_s": round(elapsed, 3), "data": result}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
