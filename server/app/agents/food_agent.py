"""
Food Agent — 음식 배달 & 맛집 추천 전문
===========================================
- 음식 주문/메뉴 추천
- Blackboard에서 호텔 예약 정보 참조 (호텔 위치 기반 추천)
- 사용자 선호도 학습
"""

from __future__ import annotations
import json
import logging

from app.agents.base import BaseAgent
from app.agents.models import AgentRequest, AgentResponse, AgentDomain
from app.agents.notifications import get_notifications

logger = logging.getLogger("dada.agent.food")

FOOD_SYSTEM_PROMPT = """You are a Food Delivery & Restaurant Specialist for DADA-AI.

Capabilities:
1. Restaurant recommendations based on location, cuisine, price
2. Menu suggestions based on user preferences
3. If user has an active hotel booking, suggest restaurants near that hotel
4. Always respond in Korean unless the user messages in English

Be friendly and conversational. Ask clarifying questions if needed.
If you find the user has a hotel booking, mention you checked their location
to offer better suggestions — that shows the memory feature!"""


class FoodAgent(BaseAgent):
    """Food delivery domain specialist."""

    def __init__(self):
        super().__init__(
            agent_id="food",
            domain=AgentDomain.FOOD,
            description="음식 배달 주문/메뉴 추천"
        )

    async def _process(self, req: AgentRequest, context: dict,
                       instructions: str) -> AgentResponse:
        # ── Cross-agent memory: check if user has a hotel booking ──
        hotel_booking = self.read_from_blackboard(
            f"hotel:booking:{req.user_id}"
        )
        user_ctx = context.get("profile", {}).get("context", {})
        active_hotel = hotel_booking or user_ctx.get("active_hotel_request")

        # Session handoff from Supervisor
        handoff = context.get("session", {}).get("_handoff_data", {})
        entities = handoff.get("entities", {})

        # Build context
        context_blurb = ""
        if active_hotel:
            loc = active_hotel.get("location", "")
            context_blurb = (
                f"\n\n[Shared Memory] User has an active hotel booking in "
                f"'{loc}'. Recommend restaurants near this area!"
            )
        if entities:
            context_blurb += (
                f"\n\nPre-extracted from Supervisor: "
                f"{json.dumps(entities, ensure_ascii=False)}"
            )
        if instructions:
            context_blurb += f"\n\n[WORK INSTRUCTION] {instructions}"

        # User preference context
        prefs = context.get("profile", {}).get("preferences", {})
        food_prefs = prefs.get("food", {})
        if food_prefs:
            context_blurb += (
                f"\n\nUser food preferences: "
                f"{json.dumps(food_prefs, ensure_ascii=False)}"
            )

        reply = self._llm_call(
            FOOD_SYSTEM_PROMPT,
            f"User message: {req.message}\n"
            f"User language: {req.language}"
            f"{context_blurb}",
            temperature=0.6,
            max_tokens=500,
        )

        # Extract preferences for memory
        pref_data = self._llm_call_json(
            "Extract food preferences from this conversation. "
            'Respond with JSON: {"cuisine": "", "liked_items": [], '
            '"location": "", "has_order_request": false}',
            f"User: {req.message}\nAgent: {reply}",
            temperature=0.1,
        )

        # Save learned preferences
        if pref_data.get("cuisine") or pref_data.get("liked_items"):
            self.memory.update_context(
                user_id=req.user_id,
                session_id=req.session_id,
                profile_updates={
                    "preferences": {
                        "food": {
                            "cuisine": pref_data.get("cuisine", ""),
                            "liked_items": pref_data.get("liked_items", []),
                        }
                    }
                },
                action_log={
                    "from_agent": "food",
                    "action": "recommendation",
                    "summary": f"Food query: {pref_data.get('cuisine', '?')} "
                               f"in {pref_data.get('location', '?')}",
                },
            )

        # ── Create notification if order request ─────────────────
        if pref_data.get("has_order_request"):
            try:
                get_notifications().notify_food(
                    user_id=req.user_id,
                    status="order_placed",
                )
            except Exception as e:
                logger.debug(f"Food notification failed: {e}")

        return AgentResponse(
            domain=self.domain,
            reply=reply,
            action_required=False,
            action_data={
                "preferences": pref_data,
                "referenced_hotel_booking": bool(active_hotel),
            },
            confidence=0.85,
        )


food_agent = FoodAgent()
