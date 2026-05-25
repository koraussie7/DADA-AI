"""
Supervisor Agent — 중앙 오케스트레이터
======================================
- 사용자 메시지를 분석해 적합한 Domain Agent로 라우팅
- 복합 요청은 멀티 에이전트 체인 구성 (예: 호텔→음식)
- 작업지시 반영, 토큰 사용량 기록
"""

from __future__ import annotations
import json
import logging
from typing import Optional

from app.agents.base import BaseAgent
from app.agents.models import (
    AgentRequest, AgentResponse, AgentDomain, IntentClassification,
)
from app.agents.registry import get_registry

logger = logging.getLogger("dada.agent.supervisor")

# Domain agent keywords for routing
DOMAIN_KEYWORDS = {
    AgentDomain.HOTEL: ["호텔", "숙소", "예약", "투숙", "호텔리어", "숙박", "방", "객실",
                        "hotel", "booking", "room", "stay", "accommodation"],
    AgentDomain.FOOD: ["음식", "배달", "맛집", "식당", "주문", "메뉴", "요리", "먹을",
                       "food", "delivery", "restaurant", "order", "eat", "menu"],
    AgentDomain.WALLET: ["지갑", "잔액", "송금", "스왑", "암호화폐", "코인", "토큰",
                         "wallet", "balance", "send", "swap", "crypto", "coin"],
    AgentDomain.TAXI: ["택시", "차량", "운전", "픽업", "이동", "taxi", "ride", "pickup"],
    AgentDomain.MASSAGE: ["마사지", "안마", "스파", "massage", "spa"],
    AgentDomain.SUPPORT: ["문의", "도움", "환불", "불만", "help", "support", "refund"],
}

ROUTING_SYSTEM_PROMPT = """You are the DADA-AI Supervisor — a smart request router.
Analyze the user message and classify it into ONE of these domains:
- hotel: Hotel booking, reverse auction, room requests
- food: Food delivery, restaurant recommendations
- wallet: Crypto wallet, balance, send, swap
- taxi: Taxi booking, ride hailing
- massage: Massage/spa booking
- payment: Payment, points, subscriptions
- support: Customer support, help, refund
- unknown: Anything else

Respond in JSON only:
{
  "domain": "hotel|food|wallet|taxi|massage|payment|support|unknown",
  "sub_intent": "brief sub-category e.g. booking, balance inquiry",
  "confidence": 0.0-1.0,
  "entities": {"location": "", "date": "", "amount": ""},
  "reasoning": "why this classification",
  "agents": ["list of agents needed in order"]
}

For complex requests that span multiple domains, list them in agents[] in execution order.
Only use the agents listed above."""


class SupervisorAgent(BaseAgent):
    """Routes incoming requests to the right domain agent."""

    def __init__(self):
        super().__init__(
            agent_id="supervisor",
            domain=AgentDomain.UNKNOWN,
            description="전체 오케스트레이션 담당. 사용자 요청 분류 및 라우팅."
        )

    async def _process(self, req: AgentRequest, context: dict,
                       instructions: str) -> AgentResponse:
        # 1. Classify intent using LLM
        inst_context = ""
        if instructions:
            inst_context = f"\n\n[Supervisor Instructions]\n{instructions}"

        extras = ""
        if context.get("profile", {}).get("context"):
            user_ctx = context["profile"]["context"]
            extras = f"\n\nUser context: {json.dumps(user_ctx, ensure_ascii=False)}"

        if context.get("blackboard"):
            recent = context["blackboard"][:3]
            extras += f"\n\nRecent activity: {json.dumps(recent, ensure_ascii=False)}"

        classification = self._llm_call_json(
            ROUTING_SYSTEM_PROMPT,
            f"User message: {req.message}\nLanguage: {req.language}{inst_context}{extras}",
            temperature=0.2,
        )

        intent = IntentClassification(**{
            "domain": classification.get("domain", "unknown"),
            "sub_intent": classification.get("sub_intent", ""),
            "confidence": classification.get("confidence", 0.0),
            "entities": classification.get("entities", {}),
            "reasoning": classification.get("reasoning", ""),
            "agents": classification.get("agents", []),
        })

        # Save to blackboard for traceability
        self.save_to_blackboard(
            f"supervisor:intent:{req.user_id}:{req.session_id or 'anon'}",
            intent.model_dump(),
            user_id=req.user_id,
            ttl=86400,  # 24h
        )

        # 2. Build response with routing info
        domain_str = intent.domain.value
        domain_label = {
            "hotel": "호텔", "food": "음식", "wallet": "지갑",
            "taxi": "택시", "massage": "마사지", "payment": "결제",
            "support": "고객지원", "unknown": "일반",
        }.get(domain_str, domain_str)

        if intent.domain == AgentDomain.UNKNOWN or intent.confidence < 0.3:
            return AgentResponse(
                domain=self.domain,
                reply=(
                    f"🤖 **DADA-AI Assistant**\n\n"
                    f"죄송합니다. 요청을 정확히 이해하지 못했어요.\n"
                    f"- 호텔 예약, 음식 배달, 지갑, 택시, 마사지 등\n"
                    f"- 위 서비스 중 하나를 말씀해주세요!\n\n"
                    f"*(분류: {domain_label}, 신뢰도: {intent.confidence:.0%})*"
                ),
                confidence=intent.confidence,
                action_required=False,
            )

        # 3. Route — store the classification in session for next agent
        extra_notes = ""
        if intent.agents and len(intent.agents) > 1:
            extra_notes = (
                f"\n\nℹ️ 이 요청은 여러 단계로 처리됩니다:\n"
                + "\n".join(f"  {i+1}. {a}" for i, a in enumerate(intent.agents))
            )

        return AgentResponse(
            domain=intent.domain,
            reply=(
                f"🤖 **DADA-AI Assistant**\n\n"
                f"📋 **분류**: {domain_label}\n"
                f"🔍 **세부**: {intent.sub_intent}\n"
                f"📊 **신뢰도**: {intent.confidence:.0%}\n"
                f"{'  🏷️ ' + json.dumps(intent.entities, ensure_ascii=False) if intent.entities else ''}"
                f"{extra_notes}\n\n"
                f"담당 에이전트로 연결합니다... 🔄"
            ),
            action_required=True,
            action_type="route",
            action_data={
                "domain": intent.domain.value,
                "sub_intent": intent.sub_intent,
                "entities": intent.entities,
                "agents": intent.agents or [intent.domain.value],
                "reasoning": intent.reasoning,
            },
            confidence=intent.confidence,
        )


# Singleton
supervisor_agent = SupervisorAgent()
