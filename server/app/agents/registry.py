"""
DADA-AI Agent Registry — 중앙 에이전트 관리자
==============================================
- Agent 등록/조회/토글 (on/off)
- 작업지시 (Work Instructions) 저장 및 전달
- 에이전트 상태 모니터링 (last_active, health)

사용법:
    from app.agents.registry import agent_registry
    agent_registry.toggle("hotel", enabled=True)
    agent_registry.set_instruction("wallet", "오전에만 동작")
    status = agent_registry.dashboard()
"""

from __future__ import annotations
import os
import json
import time
import logging
import sqlite3
import threading
from datetime import datetime, timezone
from typing import Optional, Any

from app.agents.memory import get_memory

logger = logging.getLogger("dada.agent_registry")

REGISTRY_DB = os.getenv("AGENT_REGISTRY_DB", "/root/DADA-AI/agent_registry.db")


class _AgentRegistry:
    """
    Thread-safe singleton that manages all agents.

    Each agent has:
      - agent_id:  unique name (e.g. "supervisor", "hotel", "food", "wallet")
      - enabled:   bool — on/off toggle
      - instructions: str — current work instructions
      - last_active: float (epoch) — last time agent handled a request
      - total_handled: int — total requests handled
      - errors: int — total errors
      - healthy: bool — health status
    """

    def __init__(self, db_path: str = REGISTRY_DB):
        self._db_path = db_path
        self._lock = threading.Lock()
        self._cache: dict[str, dict] = {}  # agent_id -> cached status
        self._init_db()
        self._load_cache()

    # ── Database ────────────────────────────────────────────────────

    def _get_conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self._db_path, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        return conn

    def _init_db(self):
        with self._lock:
            conn = self._get_conn()
            conn.executescript("""
                CREATE TABLE IF NOT EXISTS agents (
                    agent_id TEXT PRIMARY KEY,
                    enabled INTEGER NOT NULL DEFAULT 1,
                    instructions TEXT NOT NULL DEFAULT '',
                    last_active REAL NOT NULL DEFAULT 0,
                    total_handled INTEGER NOT NULL DEFAULT 0,
                    errors INTEGER NOT NULL DEFAULT 0,
                    healthy INTEGER NOT NULL DEFAULT 1,
                    created_at TEXT NOT NULL DEFAULT (datetime('now')),
                    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
                );

                CREATE TABLE IF NOT EXISTS agent_instructions_log (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    agent_id TEXT NOT NULL,
                    instruction TEXT NOT NULL,
                    issued_by TEXT NOT NULL DEFAULT 'system',
                    created_at TEXT NOT NULL DEFAULT (datetime('now'))
                );

                CREATE TABLE IF NOT EXISTS token_usage (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    agent_id TEXT NOT NULL,
                    date TEXT NOT NULL,
                    prompt_tokens INTEGER NOT NULL DEFAULT 0,
                    completion_tokens INTEGER NOT NULL DEFAULT 0,
                    total_tokens INTEGER NOT NULL DEFAULT 0,
                    call_count INTEGER NOT NULL DEFAULT 1,
                    model TEXT NOT NULL DEFAULT '',
                    created_at TEXT NOT NULL DEFAULT (datetime('now'))
                );
                CREATE INDEX IF NOT EXISTS idx_tu_agent ON token_usage(agent_id);
                CREATE INDEX IF NOT EXISTS idx_tu_date ON token_usage(date);
                CREATE UNIQUE INDEX IF NOT EXISTS idx_tu_agent_date
                    ON token_usage(agent_id, date, model);
            """)
            conn.commit()
            conn.close()

    def _load_cache(self):
        conn = self._get_conn()
        rows = conn.execute("SELECT * FROM agents").fetchall()
        for r in rows:
            self._cache[r["agent_id"]] = dict(r)
        conn.close()

    # ── Register / Seed ────────────────────────────────────────────

    def register(self, agent_id: str, enabled: bool = True,
                 instructions: str = "", description: str = ""):
        """Register an agent (idempotent)."""
        with self._lock:
            conn = self._get_conn()
            conn.execute("""
                INSERT INTO agents (agent_id, enabled, instructions)
                VALUES (?, ?, ?)
                ON CONFLICT(agent_id) DO NOTHING
            """, (agent_id, int(enabled), instructions))
            conn.commit()
            # Refresh cache
            row = conn.execute("SELECT * FROM agents WHERE agent_id=?", (agent_id,)).fetchone()
            if row:
                self._cache[agent_id] = dict(row)
            conn.close()

    def seed_default_agents(self):
        """Register all built-in agents if not already registered."""
        defaults = [
            ("supervisor", True, "전체 오케스트레이션 담당. 사용자 요청 분류 및 라우팅."),
            ("hotel", True, "호텔 역경매 예약/입찰/매칭 처리"),
            ("food", True, "음식 배달 주문/메뉴 추천"),
            ("wallet", True, "암호화폐 지갑 조회/전송/스왑"),
            ("taxi", False, "택시 호출 및 경로 최적화"),
            ("massage", False, "마사지 예약 및 서비스 매칭"),
            ("supplier", False, "공급자 관리 및 정산"),
            ("payment", False, "결제 및 포인트 관리"),
            ("support", False, "고객 지원 자동 응대"),
        ]
        for agent_id, enabled, desc in defaults:
            self.register(agent_id, enabled, desc)
        # Store descriptions in blackboard for agent reference
        memory = get_memory()
        for agent_id, _, desc in defaults:
            memory.write(
                f"agent:desc:{agent_id}",
                desc,
                domain="system",
                ttl_seconds=None  # permanent
            )

    # ── Toggle On/Off ──────────────────────────────────────────────

    def toggle(self, agent_id: str, enabled: Optional[bool] = None) -> bool:
        """
        Toggle agent on/off. If `enabled` is None, flip current state.
        Returns the new state.
        """
        with self._lock:
            conn = self._get_conn()
            row = conn.execute("SELECT enabled FROM agents WHERE agent_id=?",
                               (agent_id,)).fetchone()
            if not row:
                conn.close()
                raise ValueError(f"Unknown agent: {agent_id}")

            new_state = not bool(row["enabled"]) if enabled is None else enabled
            conn.execute("""
                UPDATE agents SET enabled=?, updated_at=datetime('now')
                WHERE agent_id=?
            """, (int(new_state), agent_id))
            conn.commit()
            conn.close()

            # Update cache
            if agent_id in self._cache:
                self._cache[agent_id]["enabled"] = int(new_state)
                self._cache[agent_id]["updated_at"] = datetime.now(timezone.utc).isoformat()

            # Log to blackboard so agents can read it
            get_memory().write(
                f"agent:status:{agent_id}",
                {"enabled": new_state, "toggled_at": datetime.now(timezone.utc).isoformat()},
                domain="system", ttl_seconds=None
            )

            logger.info(f"Agent '{agent_id}' toggled → {'ON' if new_state else 'OFF'}")
            return new_state

    def is_enabled(self, agent_id: str) -> bool:
        """Quick check if an agent is enabled."""
        cached = self._cache.get(agent_id)
        if cached:
            return bool(cached["enabled"])
        return False

    # ── Work Instructions ──────────────────────────────────────────

    def set_instruction(self, agent_id: str, instruction: str,
                        issued_by: str = "admin") -> dict:
        """
        Set work instructions for an agent.
        Instructions are stored in both the registry and the shared Blackboard.
        """
        with self._lock:
            conn = self._get_conn()
            conn.execute("""
                UPDATE agents SET instructions=?, updated_at=datetime('now')
                WHERE agent_id=?
            """, (instruction, agent_id))

            conn.execute("""
                INSERT INTO agent_instructions_log (agent_id, instruction, issued_by)
                VALUES (?, ?, ?)
            """, (agent_id, instruction, issued_by))
            conn.commit()
            conn.close()

            # Update cache
            if agent_id in self._cache:
                self._cache[agent_id]["instructions"] = instruction

            # Write to Blackboard so agents pick it up immediately
            get_memory().write(
                f"agent:instruction:{agent_id}",
                {
                    "instruction": instruction,
                    "issued_by": issued_by,
                    "issued_at": datetime.now(timezone.utc).isoformat(),
                },
                domain="system",
                ttl_seconds=None  # permanent until overwritten
            )

            logger.info(f"Instruction set for '{agent_id}': {instruction[:60]}...")
            return {"agent_id": agent_id, "instruction": instruction, "issued_by": issued_by}

    def get_instruction(self, agent_id: str) -> str:
        """Get current instructions for an agent."""
        cached = self._cache.get(agent_id)
        if cached:
            return cached.get("instructions", "")
        return ""

    def get_instruction_history(self, agent_id: str, limit: int = 20) -> list[dict]:
        """Get instruction change history."""
        conn = self._get_conn()
        rows = conn.execute("""
            SELECT * FROM agent_instructions_log
            WHERE agent_id=? ORDER BY created_at DESC LIMIT ?
        """, (agent_id, limit)).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    # ── Activity Tracking ──────────────────────────────────────────

    def record_activity(self, agent_id: str, success: bool = True):
        """Record that an agent handled a request."""
        with self._lock:
            conn = self._get_conn()
            now = time.time()
            if success:
                conn.execute("""
                    UPDATE agents SET last_active=?, total_handled=total_handled+1,
                        healthy=1, updated_at=datetime('now')
                    WHERE agent_id=?
                """, (now, agent_id))
            else:
                conn.execute("""
                    UPDATE agents SET last_active=?, errors=errors+1,
                        updated_at=datetime('now')
                    WHERE agent_id=?
                """, (now, agent_id))
            conn.commit()
            conn.close()

            # Update cache
            if agent_id in self._cache:
                self._cache[agent_id]["last_active"] = now
                if success:
                    self._cache[agent_id]["total_handled"] += 1
                    self._cache[agent_id]["healthy"] = 1
                else:
                    self._cache[agent_id]["errors"] += 1

    # ── Token Usage Tracking ───────────────────────────────────────

    def record_token_usage(self, agent_id: str, prompt_tokens: int,
                           completion_tokens: int, model: str = ""):
        """
        Record token usage for an agent, aggregated daily.
        Call this after every LLM completion.
        """
        date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        total = prompt_tokens + completion_tokens
        with self._lock:
            conn = self._get_conn()
            conn.execute("""
                INSERT INTO token_usage (agent_id, date, prompt_tokens, completion_tokens,
                                         total_tokens, call_count, model)
                VALUES (?, ?, ?, ?, ?, 1, ?)
                ON CONFLICT(agent_id, date, model) DO UPDATE SET
                    prompt_tokens = prompt_tokens + excluded.prompt_tokens,
                    completion_tokens = completion_tokens + excluded.completion_tokens,
                    total_tokens = total_tokens + excluded.total_tokens,
                    call_count = call_count + 1
            """, (agent_id, date_str, prompt_tokens, completion_tokens, total, model))
            conn.commit()
            conn.close()

    # ── Dashboard ──────────────────────────────────────────────────

    def dashboard(self) -> dict:
        """
        Full dashboard view:
          - All agents with status, instructions, stats
          - Memory stats (blackboard entries count)
          - Overall system health
        """
        conn = self._get_conn()
        rows = conn.execute("SELECT * FROM agents ORDER BY agent_id").fetchall()
        agents = []
        online_count = 0
        for r in rows:
            d = dict(r)
            d["enabled"] = bool(d["enabled"])
            d["healthy"] = bool(d["healthy"])
            d["last_active_ago"] = self._time_ago(d["last_active"])

            # Inject description from blackboard
            desc_data = get_memory().read(f"agent:desc:{d['agent_id']}")
            d["description"] = desc_data or ""

            # Inject current instruction from blackboard (live version)
            instr_data = get_memory().read(f"agent:instruction:{d['agent_id']}")
            d["current_instruction"] = (instr_data or {}).get("instruction", d["instructions"])

            if d["enabled"]:
                online_count += 1
            agents.append(d)

        # Blackboard stats
        bb_all = get_memory().search(limit=100)
        bb_count = len(bb_all)
        bb_domains = {}
        for entry in bb_all:
            dom = entry.get("domain", "unknown")
            bb_domains[dom] = bb_domains.get(dom, 0) + 1

        # Token usage stats (today)
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        token_rows = conn.execute("""
            SELECT agent_id, model,
                   SUM(prompt_tokens) as prompt_tokens,
                   SUM(completion_tokens) as completion_tokens,
                   SUM(total_tokens) as total_tokens,
                   SUM(call_count) as call_count
            FROM token_usage
            WHERE date=?
            GROUP BY agent_id, model
            ORDER BY total_tokens DESC
        """, (today,)).fetchall()

        token_stats = []
        grand_total = 0
        grand_calls = 0
        for tr in token_rows:
            d = dict(tr)
            token_stats.append(d)
            grand_total += d["total_tokens"]
            grand_calls += d["call_count"]

        # All-time token summary per agent
        alltime_rows = conn.execute("""
            SELECT agent_id,
                   SUM(total_tokens) as total_tokens,
                   SUM(call_count) as call_count
            FROM token_usage
            GROUP BY agent_id
            ORDER BY total_tokens DESC
        """).fetchall()
        alltime_tokens = [dict(r) for r in alltime_rows]

        conn.close()

        return {
            "status": "healthy" if online_count > 0 else "degraded",
            "total_agents": len(agents),
            "online_agents": online_count,
            "agents": agents,
            "token_usage": {
                "today": {
                    "total_tokens": grand_total,
                    "total_api_calls": grand_calls,
                    "per_agent": token_stats,
                },
                "all_time": alltime_tokens,
                "estimated_cost_usd": round(grand_total * 0.000005, 4),  # ~$5/M tokens
            },
            "blackboard": {
                "total_entries": bb_count,
                "by_domain": bb_domains,
            },
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

    def agent_detail(self, agent_id: str) -> Optional[dict]:
        """Detailed view of a single agent."""
        conn = self._get_conn()
        row = conn.execute("SELECT * FROM agents WHERE agent_id=?", (agent_id,)).fetchone()
        conn.close()
        if not row:
            return None
        d = dict(row)
        d["enabled"] = bool(d["enabled"])
        d["healthy"] = bool(d["healthy"])
        d["last_active_ago"] = self._time_ago(d["last_active"])
        d["instruction_history"] = self.get_instruction_history(agent_id, limit=10)

        bb_entries = get_memory().search(domain=agent_id, limit=20)
        d["recent_blackboard_entries"] = len(bb_entries)

        return d

    @staticmethod
    def _time_ago(epoch: float) -> str:
        if epoch <= 0:
            return "never"
        diff = time.time() - epoch
        if diff < 60:
            return f"{int(diff)}s ago"
        elif diff < 3600:
            return f"{int(diff/60)}m ago"
        elif diff < 86400:
            return f"{int(diff/3600)}h ago"
        else:
            return f"{int(diff/86400)}d ago"


# ── Singleton ────────────────────────────────────────────────────────
_registry_instance: Optional[_AgentRegistry] = None

def get_registry() -> _AgentRegistry:
    global _registry_instance
    if _registry_instance is None:
        _registry_instance = _AgentRegistry()
        _registry_instance.seed_default_agents()
    return _registry_instance


# Convenience reference
agent_registry = get_registry()
