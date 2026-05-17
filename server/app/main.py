from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="DADA-AI Hermes Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Code Assist
from app.routers.code_assist import router as code_assist_router
app.include_router(code_assist_router)

from app.routers.opencode_bridge import router as bridge_router
app.include_router(bridge_router)

from app.routers.ai_chat import router as ai_chat_router
app.include_router(ai_chat_router)

from app.routers.platform_routes import router as platform_router
app.include_router(platform_router)

# DADA Point
from app.routers.point_charge import router as point_charge_router
app.include_router(point_charge_router)

from app.routers.stripe_webhook import router as stripe_webhook_router
app.include_router(stripe_webhook_router)

from app.routers.admin_point import router as admin_point_router
app.include_router(admin_point_router)

@app.get("/")
async def root():
    return {"status": "✅ DADA-AI Hermes Server Running", "hermes": "ready"}

@app.get("/health")
async def health():
    return {"status": "healthy"}
