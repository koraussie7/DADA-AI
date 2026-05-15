import base64
import json
import uuid
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from dotenv import load_dotenv
import uvicorn
import os
import sys
import sqlite3
import httpx
import logging
import google.generativeai as genai
from typing import Dict, Optional
from pydantic import BaseModel
from fastapi import Request

load_dotenv()

LOCALAI_URL = os.getenv("LOCALAI_URL", "http://localhost:11434")
MINIMA_URL = os.getenv("MINIMA_URL", "https://localhost:9005")
LOG_LEVEL = os.getenv("LOG_LEVEL", "info").upper()

logging.basicConfig(level=getattr(logging, LOG_LEVEL, logging.INFO),
                    format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("dada")

# ── Leaderboard DB ──────────────────────────────────────────────────────────
LEADERBOARD_DB = os.getenv("LEADERBOARD_DB", "leaderboard.db")

_http_client = None
def get_http_client():
    global _http_client
    if _http_client is None:
        _http_client = httpx.AsyncClient(timeout=120)
    return _http_client

def init_leaderboard_db():
    conn = sqlite3.connect(LEADERBOARD_DB)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS user_points (
            user_id TEXT NOT NULL,
            display_name TEXT NOT NULL DEFAULT '',
            points INTEGER NOT NULL DEFAULT 0,
            recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_up_id ON user_points(user_id)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_up_at ON user_points(recorded_at)")
    conn.commit()
    conn.close()
    log.info(f"Leaderboard DB initialized: {LEADERBOARD_DB}")

def record_points(user_id: str, display_name: str, points: int):
    conn = sqlite3.connect(LEADERBOARD_DB)
    conn.execute(
        "INSERT INTO user_points (user_id, display_name, points) VALUES (?, ?, ?)",
        (user_id, display_name, points),
    )
    conn.commit()
    conn.close()

def get_leaderboard(period: str, limit: int = 50) -> list:
    days = {"weekly": 7, "monthly": 30}.get(period)
    conn = sqlite3.connect(LEADERBOARD_DB)
    if days:
        rows = conn.execute(
            "SELECT user_id, display_name, SUM(points) as total FROM user_points "
            "WHERE recorded_at >= datetime('now', ? || ' days') "
            "GROUP BY user_id ORDER BY total DESC LIMIT ?",
            (f"-{days}", limit)
        ).fetchall()
    elif period == "creators":
        rows = conn.execute(
            "SELECT user_id, display_name, SUM(points) as total FROM user_points "
            "WHERE display_name LIKE ? "
            "GROUP BY user_id ORDER BY total DESC LIMIT ?",
            ('%[Creator]%', limit)
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT user_id, display_name, SUM(points) as total FROM user_points "
            "GROUP BY user_id ORDER BY total DESC LIMIT ?",
            (limit,)
        ).fetchall()
    conn.close()

    result = []
    for i, (uid, name, pts) in enumerate(rows):
        pts = pts or 0
        badge = "Newbie"
        if pts >= 1000: badge = "Active"
        if pts >= 5000: badge = "Star"
        if pts >= 20000: badge = "Legend"
        result.append({
            "rank": i + 1,
            "user_id": uid,
            "display_name": name or uid,
            "points": pts,
            "badge": badge,
        })
    return result

init_leaderboard_db()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    log.info("Gemini AI configured")

CEREBRAS_API_KEY = os.getenv("CEREBRAS_API_KEY")
if not CEREBRAS_API_KEY:
    log.warning("CEREBRAS_API_KEY not set - Hermes agent will fail")
CEREBRAS_MODEL = os.getenv("CEREBRAS_MODEL", "llama3.1-8b")
CEREBRAS_API_URL = "https://api.cerebras.ai/v1/chat/completions"

HERMES_AGENT_PROMPT = """You are Hermes, an autonomous AI agent with tool-use capabilities.

You have access to the following tools and capabilities:
- You can reason step-by-step about complex problems
- You can generate structured JSON output for function calls
- You can analyze code, data, and text

When responding:
1. Think step-by-step before answering
2. If the user asks for structured data, respond in JSON
3. Be concise but thorough
4. You can use the following internal tools by responding with a JSON block:
   {
     "tool": "analyze",
     "input": "what to analyze"
   }
   {
     "tool": "code",
     "language": "python",
     "code": "print('hello')"
   }

Your knowledge cutoff is current. You are powered by Cerebras hardware acceleration."""

# ── Rate Limiting ────────────────────────────────────────────────────────────
try:
    from slowapi import Limiter, _rate_limit_exceeded_handler
    from slowapi.util import get_remote_address
    from slowapi.errors import RateLimitExceeded
    limiter = Limiter(key_func=get_remote_address, default_limits=["30/minute"])
    _HAS_SLOWAPI = True
except ImportError:
    _HAS_SLOWAPI = False
    limiter = None

app = FastAPI(title="DADA-AI Server", version="0.1.0")

if _HAS_SLOWAPI and limiter:
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

API_KEY = os.getenv("API_KEY", "")

def verify_api_key(request: Request) -> bool:
    if not API_KEY:
        return True
    return request.headers.get("X-API-Key", "") == API_KEY

allowed_origins = os.getenv(
    "CORS_ORIGINS",
    "https://privseai.com,https://muhantube.com,https://app.privseai.com"
).split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-API-Key"],
)

active_connections: Dict[str, WebSocket] = {}

@app.get("/")
async def root():
    return {"status": "running", "service": "DADA-AI Server"}

@app.get("/health")
async def health():
    localai_ok = False
    try:
        async with httpx.AsyncClient(timeout=5) as c:
            r = await c.get(f"{LOCALAI_URL}/v1/models")
            localai_ok = r.status_code == 200
    except Exception:
        pass
    gemini_ok = GEMINI_API_KEY is not None
    return {
        "status": "healthy" if (localai_ok or gemini_ok) else "degraded",
        "localai": "up" if localai_ok else "down",
        "gemini": "configured" if gemini_ok else "not configured",
    }

@app.get("/ai/models")
async def ai_models():
    models = []
    try:
        async with httpx.AsyncClient(timeout=5) as c:
            resp = await c.get(f"{LOCALAI_URL}/v1/models")
        if resp.status_code == 200:
            models = resp.json().get("data", [])
    except Exception:
        pass
    if GEMINI_API_KEY:
        models.append({"id": "gemini-2.5-flash", "object": "model", "provider": "google"})
        models.append({"id": "gemini-2.5-pro", "object": "model", "provider": "google"})
        models.append({"id": "gemini-2.0-flash", "object": "model", "provider": "google"})
        models.append({"id": "gemini-flash-latest", "object": "model", "provider": "google"})
    models.append({"id": CEREBRAS_MODEL, "object": "model", "provider": "cerebras"})
    models.append({"id": "hermes-agent", "object": "model", "provider": "cerebras"})
    models.append({"id": "qwen-3-235b-a22b-instruct-2507", "object": "model", "provider": "cerebras"})
    models.append({"id": "gpt-oss-120b", "object": "model", "provider": "cerebras"})
    return {"data": models, "object": "list"}

def _detect_mime(b64: str) -> str:
    header = b64[:30]
    if header.startswith("/9j"):
        return "image/jpeg"
    if header.startswith("iVBOR"):
        return "image/png"
    if header.startswith("R0lGOD"):
        return "image/gif"
    if header.startswith("UklGR"):
        return "image/webp"
    return "image/png"

@app.post("/ai/chat")
async def ai_chat(request: Request):
    body = await request.json()
    if not body.get("messages"):
        return {"error": "messages is required"}
    model_name = body.get("model", "gemma3:4b")

    # Always route to Gemini for vision requests regardless of user-selected model
    msgs = body["messages"]
    last = msgs[-1]
    content_raw = last.get("content", last.get("text", ""))

    # Parse OpenAI multimodal format (content as list with image_url parts)
    images = last.get("images", [])
    if isinstance(content_raw, list):
        text_parts = []
        for part in content_raw:
            if part.get("type") == "text":
                text_parts.append(part.get("text", ""))
            elif part.get("type") == "image_url":
                url = part.get("image_url", {}).get("url", "")
                if url.startswith("data:image"):
                    b64 = url.split(",")[1] if "," in url else url
                    images.append(b64)
        if not images:
            images = last.get("images", [])
        content_raw = " ".join(text_parts) if text_parts else content_raw
    last["content"] = content_raw
    last["images"] = images

    if images and GEMINI_API_KEY:
        try:
            content = last.get("content", last.get("text", ""))
            vision_model = "gemini-2.5-flash"
            gemini_model = genai.GenerativeModel(vision_model)
            parts = [content] if content else []
            for b64 in images:
                raw = base64.b64decode(b64)
                mime = _detect_mime(b64)
                parts.append({"mime_type": mime, "data": raw})
            resp = gemini_model.generate_content(parts)
            return {
                "choices": [{
                    "message": {"role": "assistant", "content": resp.text},
                    "index": 0
                }],
                "model": vision_model,
                "object": "chat.completion"
            }
        except Exception as e:
            log.error(f"Gemini vision error: {e}")
            return {"error": str(e)}

    # Text-only Gemini models
    if model_name.startswith("gemini") and GEMINI_API_KEY:
        try:
            content = last.get("content", last.get("text", ""))
            gemini_model = genai.GenerativeModel(model_name)
            history = []
            for m in msgs[:-1]:
                role = "user" if m.get("role") in ("user", "system") else "model"
                history.append({"role": role, "parts": [m.get("content", m.get("text", ""))]})
            chat = gemini_model.start_chat(history=history)
            resp = chat.send_message(content)

            return {
                "choices": [{
                    "message": {"role": "assistant", "content": resp.text},
                    "index": 0
                }],
                "model": model_name,
                "object": "chat.completion"
            }
        except Exception as e:
            log.error(f"Gemini error: {e}")
            return {"error": str(e)}

    # LocalAI models
    local_body = {
        "model": model_name,
        "messages": body["messages"],
        "stream": body.get("stream", False),
        "max_tokens": body.get("max_tokens", 2048),
        "temperature": body.get("temperature", 0.7),
    }
    try:
        c = get_http_client()
        resp = await c.post(f"{LOCALAI_URL}/v1/chat/completions", json=local_body)
        if resp.status_code != 200:
            log.warning(f"AI backend returned {resp.status_code}: {resp.text[:200]}")
        return resp.json()
    except httpx.TimeoutException:
        log.error("AI backend timeout")
        return {"error": "AI backend timeout"}
    except Exception as e:
        log.error(f"AI backend error: {e}")
        return {"error": str(e)}

# ── Hermes Agent (Cerebras-powered) ──────────────────────────────────────────

@app.post("/opencode/chat")
async def opencode_chat(request: dict):
    if not request.get("messages"):
        return {"error": "messages is required"}
    try:
        msgs = request["messages"]
        system_prompt = request.get("system", HERMES_AGENT_PROMPT)
        temperature = request.get("temperature", 0.7)
        max_tokens = request.get("max_tokens", 4096)
        stream = request.get("stream", False)

        body = {
            "model": request.get("model", CEREBRAS_MODEL),
            "messages": [{"role": "system", "content": system_prompt}] + msgs,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": stream,
        }
        headers = {
            "Authorization": f"Bearer {CEREBRAS_API_KEY}",
            "Content-Type": "application/json",
        }
        c = get_http_client()
        resp = await c.post(CEREBRAS_API_URL, json=body, headers=headers)

        if resp.status_code != 200:
            log.error(f"Cerebras error {resp.status_code}: {resp.text[:300]}")
            return {"error": f"Cerebras API error: {resp.status_code}", "detail": resp.text[:500]}

        return resp.json()
    except Exception as e:
        log.error(f"Hermes agent error: {e}")
        return {"error": str(e)}

# ── OpenCode AI Coding Agent ────────────────────────────────────────────────

OPENCODE_API_KEY = os.getenv("OPENCODE_API_KEY")
if not OPENCODE_API_KEY:
    log.warning("OPENCODE_API_KEY not set - OpenCode agent will fail")
OPENCODE_API_URL = os.getenv("OPENCODE_API_URL", "https://opencode.ai/zen/v1/chat/completions")
OPENCODE_MODEL = os.getenv("OPENCODE_MODEL", "claude-sonnet-4")
OPENCODE_AGENT_PROMPT = os.getenv("OPENCODE_AGENT_PROMPT", (
    "You are an expert coding assistant integrated into Liberty Reach messenger. "
    "Help users with code generation, debugging, refactoring, and architecture questions. "
    "Provide clear, concise code examples. "
    "When appropriate, explain tradeoffs and suggest best practices."
))

@app.post("/opencode/zen")
async def opencode_zen(request: dict):
    if not OPENCODE_API_KEY:
        return {"error": "OpenCode API key not configured on server"}
    if not request.get("messages"):
        return {"error": "messages is required"}
    try:
        msgs = request["messages"]
        system_prompt = request.get("system", OPENCODE_AGENT_PROMPT)
        temperature = request.get("temperature", 0.7)
        max_tokens = request.get("max_tokens", 4096)
        model = request.get("model", OPENCODE_MODEL)

        body = {
            "model": model,
            "messages": [{"role": "system", "content": system_prompt}] + msgs,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }
        headers = {
            "Authorization": f"Bearer {OPENCODE_API_KEY}",
            "Content-Type": "application/json",
        }
        c = get_http_client()
        resp = await c.post(OPENCODE_API_URL, json=body, headers=headers)

        if resp.status_code != 200:
            log.error(f"OpenCode error {resp.status_code}: {resp.text[:300]}")
            return {"error": f"OpenCode API error: {resp.status_code}", "detail": resp.text[:500]}

        data = resp.json()
        reply = data["choices"][0]["message"]["content"]
        return {"reply": reply, "model": model, "provider": "opencode"}
    except Exception as e:
        log.error(f"OpenCode error: {e}")
        return {"error": str(e)}

# ── Hybrid Code Assist (Hermes + OpenCode + Ollama) ─────────────────────────

MULTI_AGENT_ORCHESTRATOR_PROMPT = """You are the DADA-AI project's Multi-Agent collaboration Orchestrator.
You collaborate with two agents: Hermes (design/review) and OpenClaw (execution).

## Role Division (must follow)

**Hermes (your main role)**
- Overall strategy and architecture design
- Work priority decisions
- Code review and quality management
- Next step instructions

**OpenClaw (execution agent)**
- File creation, modification, testing, Git operations per Hermes instructions
- Command execution (cargo, flutter, git, docker, etc.)
- Detailed error reporting

## Collaboration Routine (all work must follow this order)

1. **Hermes Analysis**
   - Identify all outstanding tasks
   - Prioritize (urgency + importance)
   - Establish concrete work plan

2. **OpenClaw Execution**
   - Execute according to Hermes' plan
   - File create/edit, command execution, testing
   - Report progress in real time

3. **Hermes Review**
   - Review OpenClaw's work
   - Flag issues or approve
   - Give next task instructions

## Current Outstanding Tasks (keep up to date)
- Git rebase conflict resolution and push complete
- FastAPI server running with proper logging
- /ai/code-assist endpoint complete
- Puter Hermes Terminal app complete and integrated
- Flutter Chat Screen Agent Chip UI + Auto-routing applied
- Rust Multi-Agent Orchestrator enhancement
- OpenClaw Skill registration and testing
- Server monitoring + Telegram report system
- Liberty Reach P2P + Puter integration

## Response Format (must follow)

### 🔷 Hermes Analysis
(current situation analysis + priorities)

### 🛠️ OpenClaw Execution Plan
(specific commands and task list for this round)

### 📋 Next Steps
(what to do next)

### ✅ Status
(current progress)

Follow this routine strictly to complete the DADA-AI project quickly and systematically.
All responses from now on must follow the above format."""

CODECODE_AGENT_PROMPTS = {
    "orchestrate": MULTI_AGENT_ORCHESTRATOR_PROMPT,
    "code": (
        "You are Hermes, an elite coding assistant integrated into Liberty Reach messenger. "
        "Write clean, production-ready code. Explain your reasoning briefly. "
        "Provide complete, runnable code examples."
    ),
    "debug": (
        "You are Hermes Debugger. Find the root cause of bugs and errors. "
        "Explain why the issue occurs, then provide the fix with a brief explanation."
    ),
    "architect": (
        "You are Hermes System Architect. Design scalable, maintainable system architectures. "
        "Include component relationships, data flow, and technology choices with rationale."
    ),
    "execute": (
        "You are OpenClaw, the DADA-AI project's Executor Agent. "
        "Your job is to create files, run commands, execute tests, and manage git/docker operations. "
        "Always report errors immediately. Follow Hermes and OpenCode instructions precisely."
    ),
}

CODE_KEYWORDS = [
    "code", "function", "bug", "error", "implement", "refactor",
    "architecture", "debug", "컴파일", "에러", "코드", "함수",
]

ARCHITECT_KEYWORDS = [
    "architecture", "설계", "구조", "system design", "아키텍처",
    "diagram", "flow", "data flow",
]

DEBUG_KEYWORDS = [
    "debug", "버그", "bug", "error", "에러", "fix", "수정",
    "failed", "fail", "crash",
]

EXECUTE_KEYWORDS = [
    "execute", "create", "build", "deploy", "test", "git", "docker",
    "실행", "만들어", "테스트", "배포",
]

def _detect_intent(text: str) -> str:
    lower = text.lower()
    if any(w in lower for w in DEBUG_KEYWORDS):
        return "debug"
    if any(w in lower for w in ARCHITECT_KEYWORDS):
        return "architect"
    if any(w in lower for w in CODE_KEYWORDS):
        return "code"
    return "normal"

async def _call_opencode(messages: list, system_prompt: str, model: str = None) -> dict:
    body = {
        "model": model or OPENCODE_MODEL,
        "messages": [{"role": "system", "content": system_prompt}] + messages,
        "temperature": 0.65,
        "max_tokens": 4096,
    }
    headers = {
        "Authorization": f"Bearer {OPENCODE_API_KEY}",
        "Content-Type": "application/json",
    }
    c = get_http_client()
    resp = await c.post(OPENCODE_API_URL, json=body, headers=headers)
    if resp.status_code != 200:
        return {"error": f"OpenCode error: {resp.status_code}", "detail": resp.text[:500]}
    data = resp.json()
    reply = data["choices"][0]["message"]["content"]
    return {"reply": reply, "model": body["model"], "provider": "opencode"}

async def _verify_with_local(prompt: str, code: str) -> str:
    """Verify generated code with Ollama (local). Falls through on timeout/failure."""
    verify_prompt = (
        f"Review this code briefly. If you see any bugs or security issues, "
        f"note them. Otherwise just say 'OK'.\n\n"
        f"Task: {prompt}\n\nCode:\n{code}"
    )
    try:
        c = get_http_client()
        resp = await c.post(
            f"{LOCALAI_URL}/v1/chat/completions",
            json={
                "model": "qwen2.5-coder:7b",
                "messages": [{"role": "user", "content": verify_prompt}],
                "temperature": 0.3,
                "max_tokens": 1024,
            },
            timeout=httpx.Timeout(8.0),
        )
        if resp.status_code == 200:
            data = resp.json()
            review = data["choices"][0]["message"]["content"]
            if review.strip() != "OK":
                code = f"{code}\n\n---\n*Local review: {review}*"
    except Exception:
        pass  # Local verification is best-effort
    return code

@app.post("/ai/code-assist")
async def code_assist(request: dict):
    if not request.get("messages"):
        return {"error": "messages is required"}
    try:
        messages = request["messages"]
        mode = request.get("mode", "auto")
        user_text = messages[-1].get("content", "")

        # Client-supplied system prompt overrides the default
        client_system = request.get("system")

        # Step 1: Auto-detect intent
        if mode == "auto":
            mode = _detect_intent(user_text)

        # Step 2: Route
        if mode in ("orchestrate", "code", "debug", "architect", "execute"):
            system_prompt = client_system or CODECODE_AGENT_PROMPTS.get(mode, CODECODE_AGENT_PROMPTS["code"])

            if not OPENCODE_API_KEY:
                local_body = {
                    "model": "qwen2.5-coder:7b",
                    "messages": [{"role": "system", "content": system_prompt}] + messages,
                    "temperature": 0.65,
                    "max_tokens": 4096,
                }
                c = get_http_client()
                resp = await c.post(f"{LOCALAI_URL}/v1/chat/completions", json=local_body)
                reply = resp.json()["choices"][0]["message"]["content"] if resp.status_code == 200 else f"(local error: {resp.status_code})"
            else:
                result = await _call_opencode(messages, system_prompt)
                if "error" in result:
                    return result
                reply = result["reply"]
                if mode == "code":
                    reply = await _verify_with_local(user_text, reply)
            return {"reply": reply, "mode": mode, "provider": "opencode", "agent": mode}
        else:
            local_body = {
                "model": request.get("model", "gemma3:4b"),
                "messages": messages,
                "temperature": request.get("temperature", 0.7),
                "max_tokens": request.get("max_tokens", 2048),
            }
            c = get_http_client()
            resp = await c.post(f"{LOCALAI_URL}/v1/chat/completions", json=local_body)
            data = resp.json()
            reply = data["choices"][0]["message"]["content"]
            return {"reply": reply, "mode": "normal", "provider": "local"}
    except Exception as e:
        log.error(f"Code assist error: {e}")
        return {"error": str(e)}

# ── Multi-Agent Orchestrator ──────────────────────────────────────────────────

ORCHESTRATOR_SYSTEM_PROMPT = """You are the DADA-AI Orchestrator.
You collaborate with two agents: Hermes (design/review) and OpenClaw (execution).

## Role Division (must follow)

**Hermes (your main role)**
- Overall strategy and architecture design
- Work priority decisions
- Code review and quality management
- Next step instructions

**OpenClaw (execution agent)**
- File creation, modification, testing, Git operations per Hermes instructions
- Command execution (cargo, flutter, git, docker, etc.)
- Detailed error reporting

## Collaboration Routine (all work must follow this order)

1. **Hermes Analysis**
   - Identify all outstanding tasks
   - Prioritize (urgency + importance)
   - Establish concrete work plan

2. **OpenClaw Execution**
   - Execute according to Hermes' plan
   - File create/edit, command execution, testing
   - Report progress in real time

3. **Hermes Review**
   - Review OpenClaw's work
   - Flag issues or approve
   - Give next task instructions

## Response Format (must follow)

### 🔷 Hermes Analysis
(current situation analysis + priorities)

### 🛠️ OpenClaw Execution Plan
(specific commands and task list for this round)

### 📋 Next Steps
(what to do next)

### ✅ Status
(current progress)"""

@app.post("/ai/orchestrate")
async def ai_orchestrate(request: dict):
    if not request.get("messages"):
        return {"error": "messages is required"}
    try:
        messages = request["messages"]
        user_text = messages[-1].get("content", "")
        system_prompt = request.get("system") or ORCHESTRATOR_SYSTEM_PROMPT

        if not OPENCODE_API_KEY:
            local_body = {
                "model": "qwen2.5-coder:7b",
                "messages": [{"role": "system", "content": system_prompt}] + messages,
                "temperature": 0.65,
                "max_tokens": 8192,
            }
            c = get_http_client()
            resp = await c.post(f"{LOCALAI_URL}/v1/chat/completions", json=local_body)
            raw = resp.json()["choices"][0]["message"]["content"] if resp.status_code == 200 else f"(local error: {resp.status_code})"
        else:
            result = await _call_opencode(messages, system_prompt)
            if "error" in result:
                return result
            raw = result["reply"]

        sections = {"plan": "", "code": "", "commands": "", "review": ""}
        current = None
        for line in raw.split("\n"):
            ll = line.strip()
            if "hermes plan" in ll.lower() or "1. hermes" in ll.lower():
                current = "plan"
            elif "opencode code" in ll.lower() or "2. opencode" in ll.lower():
                current = "code"
            elif "openclaw" in ll.lower() or "3. openclaw" in ll.lower():
                current = "commands"
            elif "hermes review" in ll.lower() or "4. hermes" in ll.lower():
                current = "review"
            elif current:
                sections[current] += line + "\n"

        return {
            "plan": sections["plan"].strip(),
            "code": sections["code"].strip(),
            "commands": sections["commands"].strip(),
            "review": sections["review"].strip(),
            "raw": raw,
            "model": OPENCODE_MODEL,
            "provider": "opencode",
        }
    except Exception as e:
        log.error(f"Orchestrator error: {e}")
        return {"error": str(e)}

# ── Preference Model ────────────────────────────────────────────────────────

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "preference_model"))
try:
    from train_preference_model import predict_preference
    PREFERENCE_MODEL_AVAILABLE = True
except Exception as e:
    log.warning(f"Preference model not available: {e}")
    PREFERENCE_MODEL_AVAILABLE = False

@app.post("/ai/preference/predict")
async def preference_predict(request: dict):
    if not PREFERENCE_MODEL_AVAILABLE:
        return {"error": "Preference model not trained yet"}
    prompt = request.get("prompt", "")
    response_a = request.get("response_a", "")
    response_b = request.get("response_b", "")
    if not all([prompt, response_a, response_b]):
        return {"error": "prompt, response_a, response_b are required"}
    result = predict_preference(prompt, response_a, response_b)
    return {"result": result[0], "score": result[1]}

@app.post("/ai/preference/train")
async def preference_train():
    try:
        from train_preference_model import train_preference_model
        train_preference_model()
        return {"status": "training completed"}
    except Exception as e:
        return {"error": str(e)}

@app.post("/ai/preference/feedback")
async def preference_feedback(request: dict):
    prompt = request.get("prompt", "")
    response_a = request.get("response_a", "")
    response_b = request.get("response_b", "")
    preferred = request.get("preferred", "")
    user_id = request.get("user_id", "anonymous")
    if not all([prompt, response_a, response_b, preferred]):
        return {"error": "All fields required"}
    csv_path = os.path.join(os.path.dirname(__file__), "preference_model", "user_preferences.csv")
    import csv
    from datetime import datetime
    with open(csv_path, "a", newline="") as f:
        w = csv.writer(f)
        w.writerow([user_id, prompt, response_a, response_b, preferred, datetime.utcnow().isoformat()])
    return {"status": "feedback saved"}

# ── Minima / DADA Point Reward Endpoints ────────────────────────────────────

class RewardRequest(BaseModel):
    user_address: str
    action: str  # "watch", "ai", "relay"
    action_id: str
    seconds: int

async def minima_cmd(cmd: str) -> dict:
    async with httpx.AsyncClient(timeout=15, verify=False) as c:
        r = await c.post(MINIMA_URL, content=cmd.encode(), headers={"Content-Type": "text/plain"})
        return r.json()

@app.get("/blockchain/health")
async def blockchain_health():
    try:
        data = await minima_cmd("status")
        ok = data.get("status") is True
    except Exception:
        ok = False
    return {"status": "healthy" if ok else "unreachable"}

@app.get("/blockchain/info")
async def blockchain_info():
    try:
        data = await minima_cmd("status")
        resp = data.get("response", {})
        return {
            "version": resp.get("version", ""),
            "uptime": resp.get("uptime", ""),
            "blocks": resp.get("length", 0),
            "minima": resp.get("minima", "0"),
            "coins": resp.get("coins", "0"),
            "address": resp.get("miniaddress", ""),
        }
    except Exception as e:
        return {"error": str(e)}

@app.get("/blockchain/address")
async def blockchain_address():
    try:
        data = await minima_cmd("newaddress")
        addr = data.get("response", {}).get("address", "unknown")
        return {"address": addr}
    except Exception as e:
        return {"error": str(e)}

@app.get("/blockchain/balance")
async def blockchain_balance():
    try:
        data = await minima_cmd("balance")
        resp = data.get("response", {})
        # Testnet returns a list, mainnet returns dict with "tokens" key
        if isinstance(resp, list):
            tokens = resp
            addr = ""
            coins = "0"
        else:
            tokens = resp.get("tokens", []) if resp else []
            addr = resp.get("address", "") if resp else ""
            coins = resp.get("coins", "0") if resp else "0"
        dada = next(
            (t for t in tokens
             if (isinstance(t.get("token"), dict) and t["token"].get("name") == "DADAPOINT")
             or t.get("token") == "DADAPOINT"),
            None,
        )
        return {
            "address": addr,
            "coins": coins,
            "dada_point_balance": int(dada.get("confirmed", dada.get("amount", 0))) if dada else 0,
        }
    except Exception as e:
        return {"error": str(e)}

@app.post("/blockchain/reward")
async def blockchain_reward(req: RewardRequest, request: Request):
    if not verify_api_key(request):
        return {"error": "Invalid or missing API key"}
    points = max(1, req.seconds // {"watch": 15, "ai": 30, "relay": 60}.get(req.action, 60))
    token = "DADAPOINT"
    cmd = f"send {req.user_address} {points} {token}"
    try:
        data = await minima_cmd(cmd)
        if data.get("status"):
            tx_id = data.get("response", {}).get("txpow", {}).get("txpowid", "unknown")
            # Record to leaderboard
            record_points(req.user_address, f"User_{req.user_address[:8]}", points)
            return {
                "success": True,
                "points_earned": points,
                "tx_id": tx_id,
                "action": req.action,
            }
        return {"success": False, "error": data.get("error", "Minima send failed")}
    except Exception as e:
        return {"success": False, "error": str(e)}

# ── /minima/ alias endpoints (same as /blockchain/) ──────────────────

@app.get("/minima/health")
async def minima_health():
    return await blockchain_health()

@app.get("/minima/info")
async def minima_info():
    return await blockchain_info()

@app.get("/minima/address")
async def minima_address():
    return await blockchain_address()

@app.get("/minima/balance")
async def minima_balance():
    return await blockchain_balance()

@app.post("/minima/reward")
async def minima_reward(req: RewardRequest):
    return await blockchain_reward(req)

# ── Leaderboard / Ranking Endpoints ─────────────────────────────────────────

@app.get("/leaderboard/stats")
async def leaderboard_stats():
    onchain = {"dada_point_balance": 0, "address": ""}
    try:
        data = await minima_cmd("balance")
        resp = data.get("response", {})
        if isinstance(resp, list):
            tokens = resp
        else:
            tokens = resp.get("tokens", [])
        ada = next(
            (t for t in tokens if (isinstance(t.get("token"), dict) and t["token"].get("name") == "Minima") or t.get("token") == "Minima"),
            None,
        )
        dada = next(
            (t for t in tokens
             if (isinstance(t.get("token"), dict) and t["token"].get("name") == "DADAPOINT")
             or t.get("token") == "DADAPOINT"),
            None,
        )
        onchain = {
            "dada_point_balance": int(dada.get("confirmed", 0)) if dada else 0,
            "minima_balance": ada.get("confirmed", "0") if ada else "0",
            "address": resp.get("address", "") if not isinstance(resp, list) else "",
        }
    except Exception as e:
        onchain["error"] = str(e)

    conn = sqlite3.connect(LEADERBOARD_DB)
    total_users = conn.execute("SELECT COUNT(DISTINCT user_id) FROM user_points").fetchone()[0] or 0
    total_points = conn.execute("SELECT COALESCE(SUM(points), 0) FROM user_points").fetchone()[0] or 0
    total_txs = conn.execute("SELECT COUNT(*) FROM user_points").fetchone()[0] or 0
    conn.close()

    return {
        "onchain": onchain,
        "offchain": {
            "total_users": total_users,
            "total_points_distributed": total_points,
            "total_transactions": total_txs,
        },
        "dada_supply": 1000000,
        "remaining": max(0, 1000000 - total_points),
    }

@app.get("/leaderboard/my-rank")
async def leaderboard_my_rank(user_id: str):
    all_entries = get_leaderboard("all", 10000)
    rank = next((e["rank"] for e in all_entries if e["user_id"] == user_id), None)
    points = next((e["points"] for e in all_entries if e["user_id"] == user_id), 0)
    onchain = {"dada_point_balance": 0, "address": "", "coins": "0"}
    try:
        data = await minima_cmd("balance")
        resp = data.get("response", {})
        if isinstance(resp, list):
            tokens = resp
        else:
            tokens = resp.get("tokens", [])
        dada = next(
            (t for t in tokens
             if (isinstance(t.get("token"), dict) and t["token"].get("name") == "DADAPOINT")
             or t.get("token") == "DADAPOINT"),
            None,
        )
        onchain = {
            "dada_point_balance": int(dada.get("confirmed", 0)) if dada else 0,
            "address": resp.get("address", "") if not isinstance(resp, list) else "",
            "coins": resp.get("coins", "0") if not isinstance(resp, list) else "0",
        }
    except Exception:
        pass
    return {"rank": rank, "points": points, "user_id": user_id, "onchain": onchain}

@app.get("/leaderboard/{period}")
async def leaderboard(period: str, limit: int = 50):
    valid = {"all", "weekly", "monthly", "creators"}
    if period not in valid:
        return {"error": f"Invalid period. Use one of: {valid}"}
    return {"data": get_leaderboard(period, limit), "period": period}

# ── Loops Proxy ──────────────────────────────────────────────────────────────
LOOPS_API_URL = os.getenv("LOOPS_API_URL", "http://185.55.240.110:8080/api")
LOOPS_TOKEN = os.getenv("LOOPS_TOKEN", "")
UPLOAD_DIR = os.getenv("UPLOAD_DIR", "/root/liberty-web/uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.get("/loops/feed")
async def loops_feed():
    if not LOOPS_API_URL:
        return _local_loops_feed()
    headers = {"Authorization": f"Bearer {LOOPS_TOKEN}"} if LOOPS_TOKEN else {}
    try:
        async with httpx.AsyncClient(timeout=10) as c:
            r = await c.get(f"{LOOPS_API_URL}/web/feed", headers=headers)
            if r.status_code == 200:
                return r.json()
    except Exception as e:
        log.warning(f"Loops remote feed failed, using local: {e}")
    return _local_loops_feed()

def _local_loops_feed():
    """Fallback: serve videos from local youtube_shorts directory."""
    videos = []
    try:
        files = sorted(os.listdir(HOME_VIDEOS_DIR), key=lambda f: os.path.getmtime(os.path.join(HOME_VIDEOS_DIR, f)), reverse=True)
        for fname in files:
            entry = _build_loops_entry(fname)
            if entry:
                videos.append(entry)
    except Exception as e:
        log.warning(f"Local loops feed error: {e}")
        return {"error": str(e), "data": []}
    return {"data": videos}

@app.get("/loops/video/{video_id}")
async def loops_video(video_id: str):
    if not LOOPS_API_URL:
        return {"error": "Loops API URL not configured"}
    headers = {"Authorization": f"Bearer {LOOPS_TOKEN}"} if LOOPS_TOKEN else {}
    try:
        async with httpx.AsyncClient(timeout=10) as c:
            r = await c.get(f"{LOOPS_API_URL}/v1/video/{video_id}", headers=headers)
            return r.json()
    except Exception as e:
        return {"error": str(e)}

@app.post("/loops/upload")
async def loops_upload(data: dict, request: Request):
    if not verify_api_key(request):
        return {"error": "Invalid or missing API key"}
    b64 = data.get("video", "")
    caption = data.get("caption", "")
    if not b64:
        return {"error": "No video data"}
    try:
        raw = base64.b64decode(b64)
        name = f"{uuid.uuid4().hex}.mp4"
        path = os.path.join(UPLOAD_DIR, name)
        with open(path, "wb") as f:
            f.write(raw)

        reward_points = 10
        loops_url = None
        if LOOPS_TOKEN:
            try:
                async with httpx.AsyncClient(timeout=30) as c:
                    r = await c.post(
                        f"{LOOPS_API_URL}/v1/studio/upload",
                        data={"caption": caption},
                        files={"video": (name, raw, "video/mp4")},
                        headers={"Authorization": f"Bearer {LOOPS_TOKEN}"},
                    )
                    if r.status_code == 200:
                        loops_url = r.json().get("url")
                        reward_points = 50
            except Exception as e:
                log.warning(f"Loops platform upload failed: {e}")

        url = f"/uploads/{name}"
        log.info(f"Video uploaded: {name} ({len(raw)} bytes) reward={reward_points}")
        return {
            "url": url, "name": name, "size": len(raw),
            "loops_url": loops_url, "reward_points": reward_points,
        }
    except Exception as e:
        return {"error": str(e)}

# ── Home Feed (Couple Challenge Videos) ─────────────────────────────────────
HOME_VIDEOS_DIR = os.getenv("HOME_VIDEOS_DIR", "/root/youtube_shorts")
HOME_THUMBS_DIR = HOME_VIDEOS_DIR  # thumbnails live alongside videos
HOME_H264_DIR = os.path.join(HOME_VIDEOS_DIR, "h264")  # H264 transcoded versions
PUBLIC_HOST = os.getenv("PUBLIC_HOST", "https://privseai.com")

def _resolve_video(fname: str) -> str:
    """Return path to best available video file (prefer H264)."""
    h264_path = os.path.join(HOME_H264_DIR, fname)
    if os.path.isfile(h264_path):
        return h264_path
    return os.path.join(HOME_VIDEOS_DIR, fname)

def _resolve_thumb(thumb_name: str) -> str | None:
    """Return path to thumbnail (prefer H264 thumbs)."""
    h264_thumb = os.path.join(HOME_H264_DIR, thumb_name)
    if os.path.isfile(h264_thumb):
        return h264_thumb
    orig_thumb = os.path.join(HOME_THUMBS_DIR, thumb_name)
    return orig_thumb if os.path.isfile(orig_thumb) else None

def _build_loops_entry(fname: str, public_host: str = PUBLIC_HOST) -> dict | None:
    """Convert an mp4 filename to a loops-compatible video entry."""
    if not fname.endswith(".mp4"):
        return None
    video_id = fname[:-4]
    thumb_name = f"{video_id}.jpg"
    thumb_path = _resolve_thumb(thumb_name)
    return {
        "id": video_id,
        "title": f"커플 챌린지 #{video_id[:8]}",
        "description": "🔥 한국 핫 쇼츠 🔥 #shorts #korea #trending",
        "video_url": f"{public_host}/home/video/{fname}",
        "thumbnail_url": f"{public_host}/home/thumb/{thumb_name}" if thumb_path else None,
        "view_count": 0,
        "reward_points": 15,
        "creator": "DADA-AI",
    }

@app.get("/home/feed")
async def home_feed():
    """Return list of videos for the home screen couple challenge section."""
    videos = []
    try:
        files = sorted(os.listdir(HOME_VIDEOS_DIR), key=lambda f: os.path.getmtime(os.path.join(HOME_VIDEOS_DIR, f)), reverse=True)
        for fname in files:
            entry = _build_loops_entry(fname)
            if entry:
                # home feed doesn't need creator/reward, keep it slim
                videos.append({
                    "id": entry["id"],
                    "title": entry["title"],
                    "video_url": entry["video_url"],
                    "thumbnail_url": entry["thumbnail_url"],
                    "view_count": entry["view_count"],
                })
    except Exception as e:
        log.warning(f"Home feed error: {e}")
        return {"error": str(e), "data": []}
    return {"data": videos}

@app.get("/home/video/{filename:path}")
async def home_video(filename: str):
    """Stream video files for the home feed (prefer H264 if available)."""
    file_path = _resolve_video(filename)
    if not os.path.isfile(file_path) or not filename.endswith(".mp4"):
        return Response(status_code=404, content="Video not found")
    headers = {"Content-Disposition": f'inline; filename="{filename}"'}
    return FileResponse(file_path, media_type="video/mp4", headers=headers)

@app.get("/home/thumb/{filename:path}")
async def home_thumb(filename: str):
    """Serve thumbnail images for home feed videos."""
    file_path = _resolve_thumb(filename)
    if not file_path or not filename.endswith(".jpg"):
        return Response(status_code=404, content="Thumbnail not found")
    return FileResponse(file_path, media_type="image/jpeg")

@app.get("/couple")
async def couple_page():
    """Serve the couple challenge web page."""
    html_path = os.path.join(os.path.dirname(__file__), "static", "home.html")
    return FileResponse(html_path, media_type="text/html")

# ── WebSocket ────────────────────────────────────────────────────────────────

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await websocket.accept()
    active_connections[client_id] = websocket
    log.info(f"WebSocket connected: {client_id}")

    # Broadcast join to all other peers
    join_msg = json.dumps({"type": "peer_joined", "peer_id": client_id})
    for cid, ws in active_connections.items():
        if cid != client_id:
            try:
                await ws.send_text(join_msg)
            except Exception:
                pass

    try:
        while True:
            data = await websocket.receive_text()
            log.debug(f"WS msg from {client_id}: {data[:100]}")

            try:
                msg = json.loads(data)
                msg_type = msg.get("type", "message")

                if msg_type == "ping":
                    await websocket.send_text(json.dumps({"type": "pong"}))

                elif msg_type == "chat":
                    target = msg.get("target", "*")
                    sender = msg.get("sender", client_id)
                    content = msg.get("content", "")
                    timestamp = msg.get("timestamp", "")

                    if target == "*":
                        # Broadcast to all peers
                        broadcast = json.dumps({
                            "type": "chat", "sender": sender,
                            "content": content, "timestamp": timestamp
                        })
                        for cid, ws in active_connections.items():
                            if cid != client_id:
                                try:
                                    await ws.send_text(broadcast)
                                except Exception:
                                    pass
                    elif target in active_connections:
                        # Send to specific peer
                        target_msg = json.dumps({
                            "type": "chat", "sender": sender,
                            "content": content, "timestamp": timestamp
                        })
                        try:
                            await active_connections[target].send_text(target_msg)
                        except Exception:
                            pass
                    # Also echo back to sender for confirmation
                    await websocket.send_text(json.dumps({
                        "type": "ack", "sender": sender,
                        "content": content, "timestamp": timestamp
                    }))

                elif msg_type == "join":
                    # Re-broadcast peer info
                    for cid, ws in active_connections.items():
                        if cid != client_id:
                            try:
                                await ws.send_text(json.dumps({
                                    "type": "peer_joined", "peer_id": client_id
                                }))
                            except Exception:
                                pass

            except json.JSONDecodeError:
                await websocket.send_text(f"[DADA-AI] {data}")

    except WebSocketDisconnect:
        active_connections.pop(client_id, None)
        log.info(f"WebSocket disconnected: {client_id}")
        # Broadcast leave
        leave_msg = json.dumps({"type": "peer_left", "peer_id": client_id})
        for cid, ws in active_connections.items():
            try:
                await ws.send_text(leave_msg)
            except Exception:
                pass

# ── Commerce Endpoints ────────────────────────────────────────────────────────

COMMERCE_PRODUCTS = [
    {"id": "1", "name": "Wireless Earbuds Pro", "price": 45000, "image_url": "", "badge": "HOT", "reward_points": 300},
    {"id": "2", "name": "Smart Watch Ultra", "price": 89000, "image_url": "", "badge": "NEW", "reward_points": 500},
    {"id": "3", "name": "AI Speaker Mini", "price": 32000, "image_url": "", "badge": "50% OFF", "reward_points": 200},
    {"id": "4", "name": "LED Desk Lamp", "price": 15000, "image_url": "", "reward_points": 100},
    {"id": "5", "name": "Mechanical Keyboard", "price": 55000, "image_url": "", "badge": "BEST", "reward_points": 400},
    {"id": "6", "name": "USB-C Hub 7-in-1", "price": 22000, "image_url": "", "badge": "SALE", "reward_points": 150},
    {"id": "7", "name": "Noise Cancelling Headphones", "price": 78000, "image_url": "", "badge": "PREMIUM", "reward_points": 600},
    {"id": "8", "name": "Portable SSD 1TB", "price": 95000, "image_url": "", "reward_points": 700},
]

@ app.post("/commerce/analyze")
async def commerce_analyze(request: dict):
    video_id = request.get("video_id", "unknown")
    products = request.get("products", [])
    try:
        prompt = (
            f"You are Hermes AI Commerce Agent. Analyze these products for video {video_id}:\n"
            + "\n".join(f"- {p.get('name', 'Unknown')} at {p.get('price', 0)} DADA" for p in products)
            + "\n\nProvide: 1) Product appeal analysis 2) Recommended pricing strategy 3) Cross-sell suggestions"
        )
        body = {
            "model": CEREBRAS_MODEL,
            "messages": [{"role": "system", "content": HERMES_AGENT_PROMPT}, {"role": "user", "content": prompt}],
            "temperature": 0.7, "max_tokens": 1024,
        }
        headers = {"Authorization": f"Bearer {CEREBRAS_API_KEY}", "Content-Type": "application/json"}
        c = get_http_client()
        resp = await c.post(CEREBRAS_API_URL, json=body, headers=headers)
        analysis = resp.json().get("choices", [{}])[0].get("message", {}).get("content", "") if resp.status_code == 200 else ""
        return {"video_id": video_id, "products": products, "hermes_analysis": analysis}
    except Exception as e:
        log.error(f"Commerce analyze error: {e}")
        return {"video_id": video_id, "products": products, "hermes_analysis": "", "error": str(e)}

@ app.get("/commerce/trending")
async def commerce_trending():
    return COMMERCE_PRODUCTS

@ app.post("/commerce/hermes-analyze")
async def commerce_hermes_analyze(request: dict):
    video_id = request.get("video_id", "")
    if not video_id:
        return {"error": "video_id required"}
    try:
        prompt = f"Analyze video {video_id} for commerce potential. Suggest product categories, pricing, and target audience."
        body = {
            "model": CEREBRAS_MODEL,
            "messages": [{"role": "system", "content": HERMES_AGENT_PROMPT}, {"role": "user", "content": prompt}],
            "temperature": 0.7, "max_tokens": 512,
        }
        headers = {"Authorization": f"Bearer {CEREBRAS_API_KEY}", "Content-Type": "application/json"}
        c = get_http_client()
        resp = await c.post(CEREBRAS_API_URL, json=body, headers=headers)
        analysis = resp.json().get("choices", [{}])[0].get("message", {}).get("content", "") if resp.status_code == 200 else ""
        return {"video_id": video_id, "analysis": analysis}
    except Exception as e:
        return {"video_id": video_id, "analysis": "", "error": str(e)}

if __name__ == "__main__":
    port = int(os.getenv("SERVER_PORT", 8000))
    log.info(f"Starting DADA-AI server on port {port}, AI backend: {LOCALAI_URL}")
    uvicorn.run("server:app", host="0.0.0.0", port=port, log_level=LOG_LEVEL.lower())
