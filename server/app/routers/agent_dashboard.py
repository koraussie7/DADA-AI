"""
DADA-AI Agent Dashboard API
=============================
에이전트 통합 관제 대시보드

Endpoints:
  GET  /agents/dashboard       — 전체 대시보드 (상태 + 토큰사용량)
  GET  /agents/{agent_id}      — 개별 에이전트 상세
  POST /agents/{agent_id}/toggle          — ON/OFF 토글
  POST /agents/{agent_id}/instructions    — 작업지시 설정
  GET  /agents/{agent_id}/instructions    — 작업지시 이력
  POST /agents/chat            — Supervisor 라우팅 + Domain Agent 실행
"""

from __future__ import annotations
import logging
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.agents.registry import get_registry
from app.agents.models import AgentRequest as AgentRequestModel
from app.agents.supervisor import supervisor_agent
from app.agents.hotel_agent import hotel_agent
from app.agents.food_agent import food_agent
from app.agents.wallet_agent import wallet_agent

logger = logging.getLogger("dada.dashboard")
router = APIRouter(prefix="/agents", tags=["Agent Dashboard"])

# ── Domain Agent Map ────────────────────────────────────────────────
DOMAIN_AGENTS = {
    "hotel": hotel_agent,
    "food": food_agent,
    "wallet": wallet_agent,
}


# ── Request/Response Models ─────────────────────────────────────────
class InstructionRequest(BaseModel):
    instruction: str = Field(..., description="Work instruction text")
    issued_by: str = "admin"


class ChatRequest(BaseModel):
    user_id: str = Field(..., description="User identifier")
    message: str = Field(..., description="User's message")
    session_id: Optional[str] = None
    language: str = "ko"
    skip_supervisor: bool = False
    direct_domain: Optional[str] = None


class ChatResponse(BaseModel):
    reply: str
    domain: str
    supervisor_result: Optional[dict] = None
    agent_result: Optional[dict] = None
    token_usage: dict = Field(default_factory=dict)
    error: Optional[str] = None


# ── Endpoints ────────────────────────────────────────────────────────

@router.get("/dashboard")
async def dashboard():
    """Full agent dashboard with status, tokens, and memory stats."""
    reg = get_registry()
    return reg.dashboard()


@router.get("/{agent_id}")
async def agent_detail(agent_id: str):
    """Detailed view of a single agent."""
    reg = get_registry()
    detail = reg.agent_detail(agent_id)
    if not detail:
        raise HTTPException(status_code=404, detail=f"Unknown agent: {agent_id}")
    return detail


@router.post("/{agent_id}/toggle")
async def toggle_agent(agent_id: str, enabled: Optional[bool] = None):
    """
    Toggle agent ON/OFF.
    If `enabled` is omitted, flips current state.
    """
    reg = get_registry()
    try:
        new_state = reg.toggle(agent_id, enabled)
        return {
            "agent_id": agent_id,
            "enabled": new_state,
            "status": "ON" if new_state else "OFF",
            "message": f"Agent '{agent_id}' turned {'ON' if new_state else 'OFF'}",
        }
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/{agent_id}/instructions")
async def set_instructions(agent_id: str, req: InstructionRequest):
    """Set work instructions for an agent."""
    reg = get_registry()
    try:
        result = reg.set_instruction(
            agent_id=agent_id,
            instruction=req.instruction,
            issued_by=req.issued_by,
        )
        return {
            **result,
            "message": f"Instruction set for '{agent_id}'",
        }
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/{agent_id}/instructions")
async def get_instructions(agent_id: str, limit: int = 20):
    """Get instruction history for an agent."""
    reg = get_registry()
    hist = reg.get_instruction_history(agent_id, limit=limit)
    current = reg.get_instruction(agent_id)
    return {
        "agent_id": agent_id,
        "current_instruction": current,
        "history": hist,
    }


class CreateAgentRequest(BaseModel):
    agent_id: str = Field(..., description="Unique agent name")
    description: str = ""
    enabled: bool = True


@router.post("/create")
async def create_agent(req: CreateAgentRequest):
    """Register a new sub-agent."""
    reg = get_registry()
    try:
        reg.register(
            agent_id=req.agent_id,
            enabled=req.enabled,
            description=req.description,
        )
        return {
            "status": "ok",
            "agent_id": req.agent_id,
            "enabled": req.enabled,
            "message": f"Agent '{req.agent_id}' created",
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/chat", response_model=ChatResponse)
async def agent_chat(req: ChatRequest):
    """
    Main chat endpoint: Supervisor routes → Domain Agent processes.

    1. Supervisor classifies the intent
    2. Routes to the appropriate domain agent
    3. Domain agent processes with full memory context
    4. Returns combined response
    """
    # Build agent request
    agent_req = AgentRequestModel(
        user_id=req.user_id,
        message=req.message,
        session_id=req.session_id,
        language=req.language,
    )

    supervisor_result = None
    agent_result = None
    token_info = {}

    try:
        # Step 1: Supervisor (skip if direct_domain is specified)
        if req.direct_domain and req.direct_domain in DOMAIN_AGENTS:
            target_domain = req.direct_domain
            target_agent = DOMAIN_AGENTS[target_domain]
            supervisor_result = {
                "domain": target_domain,
                "reasoning": f"Direct routing to {target_domain}",
                "confidence": 1.0,
                "agents": [target_domain],
            }
        else:
            sv_response = await supervisor_agent.handle(agent_req)
            supervisor_result = {
                "domain": sv_response.domain.value,
                "reply": sv_response.reply,
                "confidence": sv_response.confidence,
                "reasoning": sv_response.action_data.get("reasoning", ""),
                "agents": sv_response.action_data.get("agents", [sv_response.domain.value]),
            }
            target_domain = sv_response.action_data.get("domain", "") or sv_response.domain.value

        # Step 2: Route to domain agent
        if not target_domain or target_domain == "unknown":
            return ChatResponse(
                reply=supervisor_result.get("reply", "요청을 이해하지 못했습니다."),
                domain="unknown",
                supervisor_result=supervisor_result,
                error="Could not classify request domain",
            )

        domain_agent = DOMAIN_AGENTS.get(target_domain)
        if not domain_agent:
            return ChatResponse(
                reply=f"'{target_domain}' 에이전트는 아직 구현되지 않았습니다. "
                      f"지원: hotel, food, wallet",
                domain=target_domain,
                supervisor_result=supervisor_result,
                error=f"Agent '{target_domain}' not implemented",
            )

        # Check if agent is enabled
        reg = get_registry()
        if not reg.is_enabled(target_domain):
            return ChatResponse(
                reply=f"죄송합니다. '{target_domain}' 에이전트가 현재 비활성화되어 있습니다. "
                      f"관리자에게 문의해주세요.",
                domain=target_domain,
                supervisor_result=supervisor_result,
                error=f"Agent '{target_domain}' disabled",
            )

        # Step 3: Domain agent handles the request
        agent_response = await domain_agent.handle(agent_req)
        agent_result = {
            "domain": agent_response.domain.value,
            "reply": agent_response.reply,
            "confidence": agent_response.confidence,
            "action_required": agent_response.action_required,
            "action_type": agent_response.action_type,
        }

        # Step 4: Build final reply
        final_reply = agent_response.reply

        return ChatResponse(
            reply=final_reply,
            domain=target_domain,
            supervisor_result=supervisor_result,
            agent_result=agent_result,
            error=agent_response.error,
        )

    except Exception as e:
        logger.error(f"Agent chat error: {e}", exc_info=True)
        return ChatResponse(
            reply=f"처리 중 오류가 발생했습니다: {str(e)}",
            domain="error",
            error=str(e),
        )
