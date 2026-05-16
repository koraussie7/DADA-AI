from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(prefix="/ai", tags=["AI"])

class CodeAssistRequest(BaseModel):
    prompt: str
    mode: str = "code"
    use_verification: bool = True

@router.post("/code-assist")
async def code_assist(request: CodeAssistRequest):
    return {
        "result": f"Hermes가 응답합니다.\n\n요청: {request.prompt[:150]}...",
        "source": "hermes",
        "model": "claude-sonnet-4"
    }
