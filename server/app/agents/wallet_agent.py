"""
Wallet Agent — 암호화폐 지갑 관리 전문
=========================================
- 잔액 조회, 포트폴리오, 전송, 스왑
- DADA-AI Matrix Bot의 Wallet 기능과 연동
- 거래 내역 분석 및 추천
"""

from __future__ import annotations
import json
import logging

from app.agents.base import BaseAgent
from app.agents.models import AgentRequest, AgentResponse, AgentDomain, WalletAction

logger = logging.getLogger("dada.agent.wallet")

WALLET_SYSTEM_PROMPT = """You are a Crypto Wallet Specialist for DADA-AI.

Capabilities:
1. Wallet balance inquiry (by chain or all)
2. Portfolio overview
3. Send tokens to an address
4. Swap between tokens
5. View wallet addresses
6. Transaction history review

Supported chains: ETH, BTC, SOL, AVAX, BNB, MATIC, ATOM, OSMO
Always respond in Korean unless the user messages in English.

For actual wallet operations (send, swap), note them in action_data
so the system can execute them through the Vultisig API.

Be security-conscious. Never share private keys.
Remind users to double-check addresses before sending."""


# Wallet action keywords
ACTION_KEYWORDS = {
    WalletAction.BALANCE: ["잔액", "balance", "잔고"],
    WalletAction.PORTFOLIO: ["포트폴리오", "portfolio", "자산"],
    WalletAction.SEND: ["보내", "전송", "send", "transfer"],
    WalletAction.SWAP: ["스왑", "교환", "swap", "exchange"],
    WalletAction.ADDRESS: ["주소", "address", "받을"],
    WalletAction.HISTORY: ["내역", "거래", "history", "transaction"],
}


class WalletAgent(BaseAgent):
    """Wallet & crypto domain specialist."""

    def __init__(self):
        super().__init__(
            agent_id="wallet",
            domain=AgentDomain.WALLET,
            description="암호화폐 지갑 조회/전송/스왑"
        )

    def _detect_action(self, message: str) -> WalletAction:
        msg_lower = message.lower()
        for action, keywords in ACTION_KEYWORDS.items():
            if any(kw in msg_lower for kw in keywords):
                return action
        return WalletAction.BALANCE

    async def _process(self, req: AgentRequest, context: dict,
                       instructions: str) -> AgentResponse:
        # Detect action type
        action = self._detect_action(req.message)
        handoff = context.get("session", {}).get("_handoff_data", {})
        entities = handoff.get("entities", {})

        context_blurb = f"\n\nDetected wallet action: {action.value}"
        if entities:
            context_blurb += (
                f"\n\nPre-extracted from Supervisor: "
                f"{json.dumps(entities, ensure_ascii=False)}"
            )
        if instructions:
            context_blurb += f"\n\n[WORK INSTRUCTION] {instructions}"

        # Check if user has hotel booking (cross-agent context)
        hotel_booking = self.read_from_blackboard(
            f"hotel:booking:{req.user_id}"
        )
        if hotel_booking:
            context_blurb += (
                f"\n\n[Shared Memory] User has a hotel booking: "
                f"{json.dumps(hotel_booking, ensure_ascii=False)}. "
                f"User might need travel funds — suggest checking sufficient balance."
            )

        reply = self._llm_call(
            WALLET_SYSTEM_PROMPT,
            f"User message: {req.message}\n"
            f"User language: {req.language}"
            f"{context_blurb}",
            temperature=0.4,
            max_tokens=500,
        )

        # Parse action details for potential execution
        action_detail = self._llm_call_json(
            "Extract wallet action details. "
            'Respond with JSON: {"chain": "", "amount": null, '
            '"to_address": "", "from_token": "", "to_token": "", '
            '"requires_execution": false}',
            f"User: {req.message}",
            temperature=0.1,
        )

        needs_execution = action_detail.get("requires_execution", False)

        # Log to memory
        self.memory.update_context(
            user_id=req.user_id,
            session_id=req.session_id,
            session_data={f"last_wallet_action": action.value},
            action_log={
                "from_agent": "wallet",
                "action": action.value,
                "summary": f"Wallet {action.value}: {req.message[:80]}",
            },
        )

        return AgentResponse(
            domain=self.domain,
            reply=reply,
            action_required=needs_execution,
            action_type=action.value if needs_execution else "info",
            action_data={
                "wallet_action": action.value,
                "chain": action_detail.get("chain", ""),
                "amount": action_detail.get("amount"),
                "to_address": action_detail.get("to_address"),
                "requires_execution": needs_execution,
            },
            confidence=0.9 if not needs_execution else 0.7,
        )


wallet_agent = WalletAgent()
