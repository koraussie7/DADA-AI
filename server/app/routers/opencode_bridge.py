from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import json
from .hermes_bridge_helper import call_hermes_for_review

router = APIRouter(prefix="/bridge", tags=["Bridge"])

active_connections = []

@router.websocket("/opencode")
async def opencode_bridge(websocket: WebSocket):
    await websocket.accept()
    active_connections.append(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            
            if message.get("from") == "opencode":
                hermes_response = await call_hermes_for_review(message.get("content", ""))
                await websocket.send_text(json.dumps({
                    "from": "hermes",
                    "result": hermes_response
                }))
    except WebSocketDisconnect:
        active_connections.remove(websocket)
    except Exception as e:
        print(f"WebSocket Error: {e}")
