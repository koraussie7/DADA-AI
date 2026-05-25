"""
OpenClaude Approval Bridge — 대시보드용 OpenClaude CLI 제어
===========================================================
대시보드에서 OpenClaude 세션에 직접 명령 + 승인(approval) 전송

Endpoints:
  POST /openclaude/exec     — OpenClaude CLI 실행 (--print 모드, non-interactive)
  POST /openclaude/session  — tmux 세션에서 OpenClaude 실행 (interactive, approval 가능)
  POST /openclaude/approve  — 특정 tmux 세션에 승인 명령 전송
  GET  /openclaude/sessions — 실행 중인 tmux/OpenClaude 세션 목록
"""

from __future__ import annotations
import os
import re
import subprocess
import logging
import shlex
import time
from typing import Optional

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

logger = logging.getLogger("dada.openclaude")

router = APIRouter(prefix="/openclaude", tags=["OpenClaude CLI"])

# ── Safe commands for openclaude execution ────────────────────────
SAFE_PERMISSION_MODES = {"auto", "acceptEdits", "bypassPermissions", "dontAsk"}
DEFAULT_TIMEOUT = 120  # 2 minutes default for LLM calls


class ExecRequest(BaseModel):
    prompt: str = Field(..., description="Prompt to send to OpenClaude")
    permission_mode: str = Field("auto", description=f"Permission mode: {', '.join(SAFE_PERMISSION_MODES)}")
    workdir: str = "/root"
    timeout: int = DEFAULT_TIMEOUT
    model: Optional[str] = None
    add_dirs: list[str] = []


class ExecResponse(BaseModel):
    exit_code: int
    stdout: str
    stderr: str
    command: str
    duration_ms: int
    truncated: bool = False


class SessionRequest(BaseModel):
    session_name: str = Field(..., description="Unique session name (e.g. 'review-pr-42')")
    prompt: Optional[str] = Field(None, description="Initial prompt to send")
    permission_mode: str = Field("auto", description="Permission mode")
    workdir: str = "/root"


class SessionApproveRequest(BaseModel):
    session_name: str = Field(..., description="tmux session name")
    command: str = Field("/approve", description="Command to send (e.g. /approve, /block, /reject)")


class SessionInfo(BaseModel):
    session_name: str
    running: bool
    created_at: Optional[str] = None
    last_output: Optional[str] = None
    permission_mode: str = ""


@router.post("/exec", response_model=ExecResponse)
async def openclaude_exec(req: ExecRequest):
    """
    Run OpenClaude in non-interactive (--print) mode with auto-approval.
    Suitable for simple prompts, code reviews, quick tasks.
    """
    import time as _time
    start = _time.time()

    # Validate permission mode
    mode = req.permission_mode
    if mode not in SAFE_PERMISSION_MODES:
        mode = "auto"

    # Build command
    cmd_parts = ["openclaude", f"--permission-mode={mode}", "--print"]

    if req.model:
        cmd_parts.append(f"--model={req.model}")

    for d in req.add_dirs:
        cmd_parts.extend(["--add-dir", d])

    cmd_parts.append(req.prompt)
    cmd_str = shlex.join(cmd_parts)

    try:
        oc_env = os.environ.copy()
        oc_env['OPENAI_API_KEY'] = 'sk-LYWTRexX6XOAXa8GZTdiXWgYfzcVO2GpguDl7WXUhgy4c6p4zcqs6YcPxiVTOXaV'
        oc_env['CODEX_API_KEY'] = 'sk-LYWTRexX6XOAXa8GZTdiXWgYfzcVO2GpguDl7WXUhgy4c6p4zcqs6YcPxiVTOXaV'
        oc_env['CLAUDE_CODE_USE_OPENAI'] = '1'
        oc_env['OPENAI_BASE_URL'] = 'https://opencode.ai/zen/go/v1'
        oc_env['OPENAI_MODEL'] = 'deepseek-v4-flash'
        result = subprocess.run(
            cmd_parts,
            capture_output=True,
            text=True,
            timeout=req.timeout,
            cwd=os.path.expanduser(req.workdir),
            env=oc_env,
        )
        duration = int((_time.time() - start) * 1000)
        stdout = result.stdout or ""
        stderr = result.stderr or ""

        # Truncate if too long
        truncated = False
        if len(stdout) > 10000:
            stdout = stdout[-10000:]
            truncated = True
        if len(stderr) > 5000:
            stderr = stderr[-5000:]

        return ExecResponse(
            exit_code=result.returncode,
            stdout=stdout,
            stderr=stderr,
            command=cmd_str[:200],
            duration_ms=duration,
            truncated=truncated,
        )
    except subprocess.TimeoutExpired:
        duration = int((_time.time() - start) * 1000)
        return ExecResponse(
            exit_code=-1,
            stdout="",
            stderr=f"Command timed out after {req.timeout}s",
            command=cmd_str[:200],
            duration_ms=duration,
        )
    except FileNotFoundError:
        raise HTTPException(status_code=400, detail="OpenClaude not found. Install: npm install -g openclaude")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/session", response_model=dict)
async def create_session(req: SessionRequest):
    """
    Create a tmux session running OpenClaude interactively.
    You can then send approval commands via /openclaude/approve.
    """
    # Check if session already exists
    existing = _tmux_has_session(req.session_name)
    if existing:
        return {
            "status": "exists",
            "session_name": req.session_name,
            "message": f"Session '{req.session_name}' already running",
        }

    # Build openclaude command
    mode = req.permission_mode if req.permission_mode in SAFE_PERMISSION_MODES else "auto"

    # Create tmux session that runs openclaude
    shell_cmd = shlex.join([
        "openclaude",
        f"--permission-mode={mode}",
        req.prompt or "",
    ]).strip()

    tmux_cmd = [
        "tmux", "new-session", "-d", "-s", req.session_name,
        "-c", os.path.expanduser(req.workdir),
        "env",
        "OPENAI_API_KEY=sk-LYWTRexX6XOAXa8GZTdiXWgYfzcVO2GpguDl7WXUhgy4c6p4zcqs6YcPxiVTOXaV",
        "CODEX_API_KEY=sk-LYWTRexX6XOAXa8GZTdiXWgYfzcVO2GpguDl7WXUhgy4c6p4zcqs6YcPxiVTOXaV",
        "CLAUDE_CODE_USE_OPENAI=1",
        "OPENAI_BASE_URL=https://opencode.ai/zen/go/v1",
        "OPENAI_MODEL=deepseek-v4-flash",
        "bash", "-c", shell_cmd,
    ]

    try:
        result = subprocess.run(
            tmux_cmd,
            capture_output=True,
            text=True,
            timeout=10,
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=f"tmux error: {result.stderr}")

        # Wait a moment for openclaude to start
        time.sleep(1)

        return {
            "status": "created",
            "session_name": req.session_name,
            "permission_mode": mode,
            "message": f"OpenClaude session '{req.session_name}' started in tmux",
            "prompt": req.prompt or "(empty - type /approve first)",
        }

    except FileNotFoundError:
        raise HTTPException(status_code=400, detail="tmux not found. Install: apt install tmux")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/approve", response_model=dict)
async def send_approval(req: SessionApproveRequest):
    """
    Send approval command to a running OpenClaude tmux session.
    Standard commands: /approve, /block, /reject
    """
    if not _tmux_has_session(req.session_name):
        raise HTTPException(status_code=404, detail=f"Session '{req.session_name}' not found")

    # Send command to tmux session
    send_cmd = ["tmux", "send-keys", "-t", req.session_name, req.command, "Enter"]

    try:
        result = subprocess.run(
            send_cmd,
            capture_output=True,
            text=True,
            timeout=5,
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=f"tmux error: {result.stderr}")

        # Capture output after sending
        time.sleep(0.5)
        output = _tmux_capture_output(req.session_name)

        return {
            "status": "sent",
            "session_name": req.session_name,
            "command": req.command,
            "last_output": output,
            "message": f"Sent '{req.command}' to session '{req.session_name}'",
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/sessions", response_model=list[SessionInfo])
async def list_sessions():
    """List all running tmux sessions and check if they're OpenClaude."""
    sessions = _tmux_list_sessions()
    result = []

    for sname in sessions:
        output = _tmux_capture_output(sname)

        # Check if it's an openclaude session
        is_oc = False
        mode = ""
        if output:
            if "openclaude" in output.lower() or "OpenClaude" in output:
                is_oc = True
                if "permission" in output:
                    for m in SAFE_PERMISSION_MODES:
                        if m in output:
                            mode = m
                            break

        result.append(SessionInfo(
            session_name=sname,
            running=True,
            last_output=output[-2000:] if output else None,
            permission_mode=mode or "unknown",
        ))

    return result


@router.delete("/session/{session_name}")
async def kill_session(session_name: str):
    """Kill a tmux session."""
    if not _tmux_has_session(session_name):
        raise HTTPException(status_code=404, detail=f"Session '{session_name}' not found")

    try:
        subprocess.run(
            ["tmux", "kill-session", "-t", session_name],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return {
            "status": "killed",
            "session_name": session_name,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Helper: tmux interaction ──────────────────────────────────────

def _tmux_list_sessions() -> list[str]:
    """List all running tmux sessions."""
    try:
        result = subprocess.run(
            ["tmux", "list-sessions", "-F", "#{session_name}"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode != 0:
            return []
        return [s.strip() for s in result.stdout.strip().split("\n") if s.strip()]
    except FileNotFoundError:
        return []
    except Exception:
        return []


def _tmux_has_session(name: str) -> bool:
    """Check if a tmux session exists."""
    try:
        result = subprocess.run(
            ["tmux", "has-session", "-t", name],
            capture_output=True,
            timeout=5,
        )
        return result.returncode == 0
    except Exception:
        return False


def _tmux_capture_output(name: str, max_lines: int = 50) -> str:
    """Capture recent output from a tmux session."""
    try:
        result = subprocess.run(
            ["tmux", "capture-pane", "-t", name, "-p", "-S", f"-{max_lines}"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            return result.stdout
        return ""
    except Exception:
        return ""
