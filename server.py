from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import uvicorn
import os
import httpx
from typing import Dict

LOCALAI_URL = os.getenv("LOCALAI_URL", "http://185.55.243.225:8081")

load_dotenv()

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
    return {"status": "running", "message": "DADA-AI Server is online"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

@app.get("/ai/models")
async def ai_models():
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{LOCALAI_URL}/v1/models")
        return resp.json()

@app.post("/ai/chat")
async def ai_chat(request: dict):
    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(f"{LOCALAI_URL}/v1/chat/completions", json=request)
        return resp.json()

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await websocket.accept()
    active_connections[client_id] = websocket
    try:
        while True:
            data = await websocket.receive_text()
            await websocket.send_text(f"[DADA-AI] {data}")
    except WebSocketDisconnect:
        active_connections.pop(client_id, None)

if __name__ == "__main__":
    port = int(os.getenv("SERVER_PORT", 8000))
    uvicorn.run("server:app", host="0.0.0.0", port=port)
