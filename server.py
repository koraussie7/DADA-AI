import base64
import uuid
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import uvicorn
import os
import sqlite3
import httpx
import logging
import google.generativeai as genai
from typing import Dict, Optional
from pydantic import BaseModel

load_dotenv()

LOCALAI_URL = os.getenv("LOCALAI_URL", "http://localhost:8081")
MINIMA_URL = os.getenv("MINIMA_URL", "https://localhost:9005")
LOG_LEVEL = os.getenv("LOG_LEVEL", "info").upper()

logging.basicConfig(level=getattr(logging, LOG_LEVEL, logging.INFO),
                    format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("dada")

# ── Leaderboard DB ──────────────────────────────────────────────────────────
LEADERBOARD_DB = os.getenv("LEADERBOARD_DB", "leaderboard.db")

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
    where = ""
    if period == "weekly":
        where = "AND recorded_at >= datetime('now', '-7 days')"
    elif period == "monthly":
        where = "AND recorded_at >= datetime('now', '-30 days')"
    elif period == "creators":
        where = "AND display_name LIKE '%[Creator]%'"

    conn = sqlite3.connect(LEADERBOARD_DB)
    rows = conn.execute(
        f"SELECT user_id, display_name, SUM(points) as total FROM user_points "
        f"WHERE 1=1 {where} GROUP BY user_id ORDER BY total DESC LIMIT ?",
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

app = FastAPI(title="DADA-AI Server", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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
async def ai_chat(request: dict):
    if not request.get("messages"):
        return {"error": "messages is required"}
    model_name = request.get("model", "gemma-2-2b-it")

    # Gemini models (vision-capable)
    if model_name.startswith("gemini") and GEMINI_API_KEY:
        try:
            msgs = request["messages"]
            last = msgs[-1]
            content = last.get("content", last.get("text", ""))
            images = last.get("images", [])

            vision_model = "gemini-2.5-flash" if images else model_name
            gemini_model = genai.GenerativeModel(vision_model)
            if images:
                parts = [content] if content else []
                for b64 in images:
                    raw = base64.b64decode(b64)
                    mime = _detect_mime(b64)
                    parts.append({"mime_type": mime, "data": raw})
                resp = gemini_model.generate_content(parts)
            else:
                # Build chat history
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
    body = {
        "model": model_name,
        "messages": request["messages"],
        "stream": request.get("stream", False),
        "max_tokens": request.get("max_tokens", 2048),
        "temperature": request.get("temperature", 0.7),
    }
    try:
        async with httpx.AsyncClient(timeout=120) as c:
            resp = await c.post(f"{LOCALAI_URL}/v1/chat/completions", json=body)
        if resp.status_code != 200:
            log.warning(f"AI backend returned {resp.status_code}: {resp.text[:200]}")
        return resp.json()
    except httpx.TimeoutException:
        log.error("AI backend timeout")
        return {"error": "AI backend timeout"}
    except Exception as e:
        log.error(f"AI backend error: {e}")
        return {"error": str(e)}

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
async def blockchain_reward(req: RewardRequest):
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
        return {"error": "Loops API URL not configured", "data": []}
    headers = {"Authorization": f"Bearer {LOOPS_TOKEN}"} if LOOPS_TOKEN else {}
    try:
        async with httpx.AsyncClient(timeout=10) as c:
            r = await c.get(f"{LOOPS_API_URL}/web/feed", headers=headers)
            return r.json()
    except Exception as e:
        return {"error": str(e), "data": []}

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
async def loops_upload(data: dict):
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

# ── WebSocket ────────────────────────────────────────────────────────────────

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await websocket.accept()
    active_connections[client_id] = websocket
    log.info(f"WebSocket connected: {client_id}")
    try:
        while True:
            data = await websocket.receive_text()
            log.debug(f"WS msg from {client_id}: {data[:100]}")
            await websocket.send_text(f"[DADA-AI] {data}")
    except WebSocketDisconnect:
        active_connections.pop(client_id, None)
        log.info(f"WebSocket disconnected: {client_id}")

if __name__ == "__main__":
    port = int(os.getenv("SERVER_PORT", 8000))
    log.info(f"Starting DADA-AI server on port {port}, AI backend: {LOCALAI_URL}")
    uvicorn.run("server:app", host="0.0.0.0", port=port, log_level=LOG_LEVEL.lower())
