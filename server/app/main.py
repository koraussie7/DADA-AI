import os
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi import WebSocket

app = FastAPI(title="DADA-AI Hermes Server")

connections: dict[str, WebSocket] = {}
hotel_connections: dict[str, WebSocket] = {}
food_connections: dict[str, WebSocket] = {}
supplier_connections: dict[str, WebSocket] = {}

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from app.routers.code_assist import router as code_assist_router
app.include_router(code_assist_router)

from app.routers.opencode_bridge import router as bridge_router
app.include_router(bridge_router)

from app.routers.ai_chat import router as ai_chat_router
app.include_router(ai_chat_router)

from app.routers.platform_routes import router as platform_router
app.include_router(platform_router)

from app.routers.point_charge import router as point_charge_router
app.include_router(point_charge_router)

from app.routers.stripe_webhook import router as stripe_webhook_router
app.include_router(stripe_webhook_router)

from app.routers.admin_point import router as admin_point_router
app.include_router(admin_point_router)

from app.routers.payment import router as payment_router
app.include_router(payment_router)

from app.routers.hotel_booking import router as hotel_booking_router
app.include_router(hotel_booking_router)
from app.routers.legacy_routes import router as legacy_router
app.include_router(legacy_router)

from app.routers.food_delivery import router as food_delivery_router
app.include_router(food_delivery_router)

from app.routers.location import router as location_router
app.include_router(location_router)

from app.routers.taxi_booking import router as taxi_booking_router
app.include_router(taxi_booking_router)

from app.routers.massage_booking import router as massage_booking_router
app.include_router(massage_booking_router)

from app.routers.supplier_dashboard import router as supplier_router
app.include_router(supplier_router)

# ── Vultisig Wallet ─────────────────────────────────────────────────────────
from app.routers.wallet_routes import router as wallet_router
app.include_router(wallet_router)

@app.get("/")
async def root():
    return {"status": "DADA-AI Hermes Server Running", "hermes": "ready"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

from app.routers.hyperspace import router as hyperspace_router
app.include_router(hyperspace_router)

from app.routers.isek import router as isek_router
app.include_router(isek_router)

# ── Agent Dashboard ────────────────────────────────────────────
from app.routers.agent_dashboard import router as agent_dashboard_router
app.include_router(agent_dashboard_router)

# ── Agent Notifications ─────────────────────────────────────────
from app.routers.notification_routes import router as notification_router
app.include_router(notification_router)

# ── Server Terminal ────────────────────────────────────────────
from app.routers.terminal_routes import router as terminal_router
app.include_router(terminal_router)

# ── OpenClaude CLI Bridge ────────────────────────────────────────
from app.routers.openclaude_bridge import router as openclaude_bridge_router
app.include_router(openclaude_bridge_router)

# ── DADAPOINT Reward ───────────────────────────────────────────────
from app.routers.reward_routes import router as reward_router
app.include_router(reward_router)

# ── Auth ───────────────────────────────────────────────────────────────
from app.auth.auth_routes import router as auth_router
app.include_router(auth_router)

from app.marqo_service import init_marqo

@app.on_event("startup")
async def startup():
    await init_marqo()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    import json as json_mod
    await websocket.accept()
    client_id = str(id(websocket))
    connections[client_id] = websocket
    try:
        while True:
            data = await websocket.receive_text()
            msg = json_mod.loads(data)
            msg_type = msg.get("type", "")
            if msg_type == "register":
                if "client_id" in msg:
                    old_id = client_id
                    client_id = msg["client_id"]
                    connections[client_id] = connections.pop(old_id)
                await websocket.send_text(json_mod.dumps({"type": "registered", "client_id": client_id}))
            elif msg_type == "hotel_register":
                hotel_connections[client_id] = websocket
                await websocket.send_text(json_mod.dumps({"type": "hotel_registered", "client_id": client_id}))
            elif msg_type == "supplier_register":
                supplier_connections[client_id] = websocket
                await websocket.send_text(json_mod.dumps({"type": "supplier_registered", "client_id": client_id}))
            elif msg_type == "message":
                target = msg.get("to")
                if target and target in connections:
                    await connections[target].send_text(json_mod.dumps(msg))
    except Exception:
        pass
    finally:
        connections.pop(client_id, None)
        hotel_connections.pop(client_id, None)
        supplier_connections.pop(client_id, None)
