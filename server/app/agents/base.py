"""
DADA-AI Base Agent — 모든 Domain Agent의 부모 클래스
===================================================
- Memory 통합 (Blackboard + Session + Profile)
- Registry 연동 (on/off 체크, 활동 기록)
- LLM 호출 (Cerebras gpt-oss-120b)
- 작업지시 자동 확인
"""

from __future__ import annotations
import os
import json
import time
import logging
from typing import Optional, Any
from openai import OpenAI

from app.agents.models import AgentRequest, AgentResponse, AgentDomain
from app.agents.memory import get_memory, AgentMemory
from app.agents.registry import get_registry

logger = logging.getLogger("dada.agent")

# Cerebras config
CEREBRAS_API_KEY = os.getenv("CEREBRAS_API_KEY") or os.getenv("OPENAI_API_KEY", "")
CEREBRAS_BASE_URL = os.getenv("CEREBRAS_BASE_URL", "https://api.cerebras.ai/v1")
DEFAULT_MODEL = os.getenv("AGENT_LLM_MODEL", "gpt-oss-120b")


class BaseAgent:
    """
    Base class for all DADA-AI domain agents.

    Provides:
      - LLM client (Cerebras)
      - Memory access (read/write context)
      - Registry integration (status check, activity logging)
      - Work instruction awareness
    """

    def __init__(self, agent_id: str, domain: AgentDomain,
                 description: str = ""):
        self.agent_id = agent_id
        self.domain = domain
        self.description = description
        self._llm_client: Optional[OpenAI] = None
        self._memory: Optional[AgentMemory] = None

    # ── Lazy Properties ────────────────────────────────────────────

    @property
    def llm(self) -> OpenAI:
        if self._llm_client is None:
            api_key = CEREBRAS_API_KEY
            if not api_key:
                logger.warning(f"[{self.agent_id}] No API key configured!")
            self._llm_client = OpenAI(
                api_key=api_key or "dummy",
                base_url=CEREBRAS_BASE_URL,
            )
        return self._llm_client

    @property
    def memory(self) -> AgentMemory:
        if self._memory is None:
            self._memory = get_memory()
        return self._memory

    # ── Lifecycle Checks ───────────────────────────────────────────

    def check_enabled(self) -> bool:
        """Is this agent currently enabled?"""
        reg = get_registry()
        return reg.is_enabled(self.agent_id)

    def get_instructions(self) -> str:
        """Read current work instructions from Blackboard."""
        instr_data = self.memory.read(f"agent:instruction:{self.agent_id}")
        if instr_data and isinstance(instr_data, dict):
            return instr_data.get("instruction", "")
        # Fallback to registry
        reg = get_registry()
        return reg.get_instruction(self.agent_id)

    # ── Core: Handle Request ───────────────────────────────────────

    async def handle(self, req: AgentRequest) -> AgentResponse:
        """
        Main entry point. Every domain agent implements this.
        Default flow:
          1. Check enabled
          2. Load context (memory)
          3. Check instructions
          4. Process via LLM
          5. Record activity + create notification
          6. Return response
        """
        start = time.time()

        # 1. Enabled check
        if not self.check_enabled():
            logger.info(f"[{self.agent_id}] Agent disabled, skipping")
            return AgentResponse(
                domain=self.domain,
                reply=f"죄송합니다. {self.agent_id} 에이전트가 현재 비활성화되어 있습니다.",
                requires_human=True,
                error="Agent disabled",
            )

        # 2. Load memory context
        ctx = self.memory.get_context(
            user_id=req.user_id,
            session_id=req.session_id,
        )

        # 3. Check instructions
        instructions = self.get_instructions()

        # 4. Process (overridden by subclasses)
        try:
            result = await self._process(req, ctx, instructions)
            elapsed = int((time.time() - start) * 1000)

            # 5. Record activity
            reg = get_registry()
            reg.record_activity(self.agent_id, success=True)

            # 6. Auto-create notification for every handled request
            if result.confidence >= 0.3 and not result.error:
                try:
                    from app.agents.notifications import get_notifications
                    noti_system = get_notifications()
                    noti_system.notify(
                        user_id=req.user_id,
                        title=f"🤖 {self.agent_id.title()} Agent",
                        body=result.reply[:120] + ("..." if len(result.reply) > 120 else ""),
                        agent_id=self.agent_id,
                        priority="normal",
                        action_type="agent_reply",
                        action_data={"domain": self.domain.value, "confidence": result.confidence},
                        is_popup=True,
                    )
                except Exception as e:
                    logger.debug(f"[{self.agent_id}] Auto-notification failed: {e}")

            # 7. Log to memory
            self.memory.update_context(
                user_id=req.user_id,
                session_id=req.session_id,
                session_data={f"last_{self.agent_id}_result": result.reply[:200]},
                action_log={
                    "from_agent": self.agent_id,
                    "action": "handle",
                    "summary": f"Handled in {elapsed}ms: {req.message[:80]}",
                }
            )

            result.confidence = min(result.confidence + 0.1, 1.0)  # confidence boost
            return result

        except Exception as e:
            elapsed = int((time.time() - start) * 1000)
            logger.error(f"[{self.agent_id}] Error: {e}", exc_info=True)
            reg = get_registry()
            reg.record_activity(self.agent_id, success=False)
            return AgentResponse(
                domain=self.domain,
                reply=f"처리 중 오류가 발생했습니다: {str(e)}",
                error=str(e),
                requires_human=True,
                confidence=0.0,
            )

    async def _process(self, req: AgentRequest, context: dict,
                       instructions: str) -> AgentResponse:
        """Override in subclasses — the actual agent logic."""
        raise NotImplementedError

    # ── LLM Helper ─────────────────────────────────────────────────

    def _llm_call(self, system_prompt: str, user_prompt: str,
                  temperature: float = 0.3, max_tokens: int = 1024,
                  json_mode: bool = False) -> str:
        """Simplified LLM call with error handling and token tracking."""
        kwargs = {
            "model": DEFAULT_MODEL,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "temperature": temperature,
            "max_tokens": max_tokens,
        }
        if json_mode:
            kwargs["response_format"] = {"type": "json_object"}

        try:
            resp = self.llm.chat.completions.create(**kwargs)
            content = resp.choices[0].message.content or ""

            # ── Auto-record token usage ────────────────────────────
            if resp.usage:
                try:
                    reg = get_registry()
                    reg.record_token_usage(
                        agent_id=self.agent_id,
                        prompt_tokens=resp.usage.prompt_tokens or 0,
                        completion_tokens=resp.usage.completion_tokens or 0,
                        model=resp.model or DEFAULT_MODEL,
                    )
                except Exception as e:
                    logger.debug(f"[{self.agent_id}] Token recording failed: {e}")

            return content
        except Exception as e:
            logger.error(f"[{self.agent_id}] LLM call failed: {e}")
            raise

    def _llm_call_json(self, system_prompt: str, user_prompt: str,
                       temperature: float = 0.3) -> dict:
        """LLM call with guaranteed JSON response."""
        raw = self._llm_call(system_prompt, user_prompt,
                             temperature=temperature, json_mode=True)
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            logger.warning(f"[{self.agent_id}] LLM returned invalid JSON, "
                           f"attempting to parse from text")
            # Fallback: try to find JSON in the response
            import re
            match = re.search(r'\{.*\}', raw, re.DOTALL)
            if match:
                return json.loads(match.group())
            return {"error": "parse_failed", "raw": raw[:200]}

    # ── Memory Convenience ─────────────────────────────────────────

    def save_to_blackboard(self, key: str, value: Any,
                           user_id: str = "", ttl: Optional[int] = 3600):
        """Save data to shared blackboard."""
        self.memory.write(
            key, value,
            domain=self.agent_id,
            user_id=user_id,
            ttl_seconds=ttl,
        )

    def read_from_blackboard(self, key: str) -> Optional[Any]:
        """Read from shared blackboard."""
        return self.memory.read(key)

    def search_blackboard(self, user_id: str = "",
                          limit: int = 20) -> list[dict]:
        """Search blackboard entries."""
        return self.memory.search(user_id=user_id, domain=self.agent_id, limit=limit)
