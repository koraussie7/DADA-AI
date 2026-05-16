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

# WebSocket Bridge
from app.routers.opencode_bridge import router as bridge_router
app.include_router(bridge_router)

@app.get("/")
async def root():
    return {"status": "✅ DADA-AI Hermes Server Running", "hermes": "ready"}

@app.get("/health")
async def health():
    return {"status": "healthy"}
