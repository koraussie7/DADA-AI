"""
Hotel Agent — 호텔 역경매 예약 전문
=====================================
- 호텔 예약 요청 접수 및 분석
- 입찰(bid) 분석 및 최적 매칭 제안
- 사용자 선호도 기반 호텔 추천
- Blackboard에 예약 정보 공유 (Food/Wallet에서 참조 가능)
"""

from __future__ import annotations
import json
import logging
from typing import Optional
from datetime import datetime

from app.agents.base import BaseAgent
from app.agents.models import (
    AgentRequest, AgentResponse, AgentDomain, HotelSearchParams,
)
from app.agents.notifications import get_notifications

logger = logging.getLogger("dada.agent.hotel")

HOTEL_SYSTEM_PROMPT = """You are a Hotel Booking Specialist for DADA-AI.
You handle reverse-auction hotel bookings.

Capabilities:
1. Parse hotel search requests → extract location, dates, guests, budget
2. Analyze hotel bids and recommend the best option
3. Generate personalized hotel recommendations
4. Always respond in Korean unless the user messages in English

Be helpful, precise, and concise.
If the user hasn't specified check-in/out dates, ask for them.
If you need data from the DADA-AI hotel system, note it in action_data.
"""


class HotelAgent(BaseAgent):
    """Hotel domain specialist — reverse auction booking."""

    def __init__(self):
        super().__init__(
            agent_id="hotel",
            domain=AgentDomain.HOTEL,
            description="호텔 역경매 예약/입찰/매칭 처리"
        )

    async def _process(self, req: AgentRequest, context: dict,
                       instructions: str) -> AgentResponse:
        # Detect if this is a follow-up from Supervisor
        handoff = context.get("session", {}).get("_handoff_data", {})
        entities = handoff.get("entities", {})
        sub_intent = handoff.get("sub_intent", "")

        # Check if user has active context from memory
        user_ctx = context.get("profile", {}).get("context", {})
        current_booking = user_ctx.get("active_hotel_request")

        # Build enriched prompt
        context_blurb = ""
        if current_booking:
            context_blurb = (
                f"\n\nUser has an active hotel request: "
                f"{json.dumps(current_booking, ensure_ascii=False)}"
            )
        if entities:
            context_blurb += (
                f"\n\nPre-extracted entities from Supervisor: "
                f"{json.dumps(entities, ensure_ascii=False)}"
            )
        if sub_intent:
            context_blurb += f"\n\nClassified sub-intent: {sub_intent}"
        if instructions:
            context_blurb += f"\n\n[WORK INSTRUCTION] {instructions}"

        # Call LLM to handle the request
        reply = self._llm_call(
            HOTEL_SYSTEM_PROMPT,
            f"User message: {req.message}\n"
            f"User language: {req.language}"
            f"{context_blurb}",
            temperature=0.5,
            max_tokens=500,
        )

        # Extract structured data from LLM response via a second call
        # (for action tracking and memory)
        params_data = self._llm_call_json(
            "Extract hotel search parameters from the conversation. "
            "Respond ONLY with JSON matching: "
            '{"location": "", "check_in": "", "check_out": "", '
            '"guests": 1, "max_budget": null, "has_enough_info": false}',
            f"User: {req.message}\nAgent: {reply}",
            temperature=0.1,
        )

        has_enough = params_data.get("has_enough_info", False)

        # Save to blackboard (cross-agent memory)
        if has_enough:
            booking_info = {
                "location": params_data.get("location", ""),
                "check_in": params_data.get("check_in", ""),
                "check_out": params_data.get("check_out", ""),
                "guests": params_data.get("guests", 1),
                "max_budget": params_data.get("max_budget"),
                "timestamp": datetime.utcnow().isoformat(),
            }
            self.save_to_blackboard(
                f"hotel:booking:{req.user_id}",
                booking_info,
                user_id=req.user_id,
                ttl=86400 * 7,  # 7 days
            )

            # ── Create notification ────────────────────────────
            try:
                noti = get_notifications()
                noti.notify_hotel_booking(
                    user_id=req.user_id,
                    location=params_data.get("location", ""),
                    status="requested",
                )
            except Exception as e:
                logger.debug(f"Hotel notification failed: {e}")

            # Update user profile context
            self.memory.update_context(
                user_id=req.user_id,
                session_id=req.session_id,
                profile_updates={
                    "context": {"active_hotel_request": booking_info}
                },
                action_log={
                    "from_agent": "hotel",
                    "action": "booking_request",
                    "summary": f"Hotel request: {params_data.get('location', '?')} "
                               f"{params_data.get('check_in', '?')} → {params_data.get('check_out', '?')}",
                },
            )

        return AgentResponse(
            domain=self.domain,
            reply=reply,
            action_required=False,
            action_type="booking" if has_enough else "info",
            action_data={
                "params": params_data,
                "has_enough_info": has_enough,
            },
            confidence=0.85 if has_enough else 0.5,
        )


hotel_agent = HotelAgent()
