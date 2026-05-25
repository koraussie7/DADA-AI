"""
Server Terminal API — 웹 대시보드용 서버 CLI
=============================================
⚠️ 관리자 전용 - 서버 명령어 실행 권한 필요
"""
from __future__ import annotations
import os
import subprocess
import logging
import shlex

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

logger = logging.getLogger("dada.terminal")

router = APIRouter(prefix="/terminal", tags=["Terminal"])

# ── Allowed base commands (whitelist) ─────────────────────────────
ALLOWED_COMMANDS = {
    "ls", "ps", "df", "du", "free", "uptime", "who", "date",
    "cat", "head", "tail", "echo", "grep", "find", "wc", "sort",
    "uname", "hostname", "ip", "ss", "netstat", "curl", "wget",
    "pip", "python3", "node", "npm", "git", "docker", "pm2",
    "systemctl", "journalctl", "caddy", "nginx",
    "top", "htop", "kill", "pkill",
    "mkdir", "cp", "mv", "rm", "chmod", "chown", "ln",
    "tar", "gzip", "gunzip", "zip", "unzip",
    "env", "set", "export", "source",
    "which", "whereis", "type", "id", "whoami",
    "cargo", "rustc", "make", "cmake",
    "sqlite3", "redis-cli",
    "hermes", "opencode", "claude", "openclaude", "openclaw",
}


class ExecRequest(BaseModel):
    command: str = Field(..., description="Shell command to execute")
    workdir: str = "/root"
    timeout: int = 30


class ExecResponse(BaseModel):
    exit_code: int
    stdout: str
    stderr: str
    command: str
    duration_ms: int


@router.post("/exec", response_model=ExecResponse)
async def execute_command(req: ExecRequest):
    """
    Execute a shell command and return output.
    Limited to whitelisted base commands for security.
    The full command is parsed and the base command must be in ALLOWED_COMMANDS.
    """
    import time
    start = time.time()

    # Security: parse the command to check the base
    try:
        parts = shlex.split(req.command)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"Command parse error: {e}")

    if not parts:
        raise HTTPException(status_code=400, detail="Empty command")

    base_cmd = os.path.basename(parts[0]) if '/' in parts[0] else parts[0]
    if base_cmd not in ALLOWED_COMMANDS:
        raise HTTPException(
            status_code=403,
            detail=f"Command '{base_cmd}' not allowed. Allowed: {', '.join(sorted(ALLOWED_COMMANDS)[:20])}..."
        )

    # Safety: prevent rm -rf /
    cmd_str = ' '.join(parts)
    if 'rm -rf /' in cmd_str or 'rm -rf /*' in cmd_str:
        raise HTTPException(status_code=403, detail="Recursive root deletion blocked")

    # Execute
    try:
        result = subprocess.run(
            parts,
            capture_output=True,
            text=True,
            timeout=req.timeout,
            cwd=os.path.expanduser(req.workdir) if req.workdir else None,
        )
        duration = int((time.time() - start) * 1000)
        return ExecResponse(
            exit_code=result.returncode,
            stdout=result.stdout[-10000:] if result.stdout else "",
            stderr=result.stderr[-5000:] if result.stderr else "",
            command=req.command,
            duration_ms=duration,
        )
    except subprocess.TimeoutExpired:
        duration = int((time.time() - start) * 1000)
        return ExecResponse(
            exit_code=-1,
            stdout="",
            stderr=f"Command timed out after {req.timeout}s",
            command=req.command,
            duration_ms=duration,
        )
    except FileNotFoundError as e:
        raise HTTPException(status_code=400, detail=f"Command not found: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/allowed")
async def list_allowed_commands():
    """Return the list of allowed base commands."""
    return {
        "allowed_commands": sorted(ALLOWED_COMMANDS),
        "count": len(ALLOWED_COMMANDS),
    }
