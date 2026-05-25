"""
DADA-AI Shared Agent Memory System
====================================
3-layer memory: Blackboard (cross-agent) + Session (in-memory) + Profile (persistent)

Usage:
    from app.agents.memory import AgentMemory
    memory = AgentMemory()
    await memory.write("hotel_booking", {"hotel": "Lotte"}, domain="hotel", user_id="user_123")
    ctx = await memory.get_context(user_id="user_123")
"""

from __future__ import annotations
import os
import json
import time
import logging
import sqlite3
import threading
from typing import Optional, Any
from datetime import datetime, timedelta
from collections import OrderedDict

logger = logging.getLogger("dada.agent_memory")

MEMORY_DB = os.getenv("AGENT_MEMORY_DB", "/root/DADA-AI/agent_memory.db")
SESSION_TTL = int(os.getenv("AGENT_SESSION_TTL", "3600"))  # 1 hour


# ── In-Memory Session Store ──────────────────────────────────────────
class SessionStore:
    """Thread-safe in-memory session cache with TTL eviction."""

    def __init__(self, ttl: int = SESSION_TTL):
        self._data: dict[str, dict] = {}
        self._ttl = ttl
        self._lock = threading.Lock()

    def get(self, session_id: str) -> Optional[dict]:
        with self._lock:
            entry = self._data.get(session_id)
            if not entry:
                return None
            if time.time() - entry.get("_ts", 0) > self._ttl:
                del self._data[session_id]
                return None
            entry["_ts"] = time.time()  # refresh on access
            return dict(entry)

    def set(self, session_id: str, data: dict):
        with self._lock:
            data["_ts"] = time.time()
            self._data[session_id] = data

    def update(self, session_id: str, data: dict):
        with self._lock:
            existing = self._data.get(session_id, {})
            existing.update(data)
            existing["_ts"] = time.time()
            self._data[session_id] = existing

    def delete(self, session_id: str):
        with self._lock:
            self._data.pop(session_id, None)

    def cleanup(self):
        """Remove expired sessions."""
        now = time.time()
        with self._lock:
            expired = [k for k, v in self._data.items()
                       if now - v.get("_ts", 0) > self._ttl]
            for k in expired:
                del self._data[k]


# ── SQLite Persistent Store ──────────────────────────────────────────
class SQLiteStore:
    """Thread-safe SQLite backend for Blackboard + Profiles."""

    def __init__(self, db_path: str = MEMORY_DB):
        self._db_path = db_path
        self._local = threading.local()
        self._init_db()

    def _get_conn(self) -> sqlite3.Connection:
        if not hasattr(self._local, "conn") or not self._local.conn:
            conn = sqlite3.connect(self._db_path, check_same_thread=False)
            conn.row_factory = sqlite3.Row
            conn.execute("PRAGMA journal_mode=WAL")
            conn.execute("PRAGMA synchronous=NORMAL")
            self._local.conn = conn
        return self._local.conn

    def _init_db(self):
        conn = self._get_conn()
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS blackboard (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                domain TEXT NOT NULL DEFAULT '',
                user_id TEXT NOT NULL DEFAULT '',
                session_id TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                expires_at TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_bb_user ON blackboard(user_id);
            CREATE INDEX IF NOT EXISTS idx_bb_domain ON blackboard(domain);
            CREATE INDEX IF NOT EXISTS idx_bb_expires ON blackboard(expires_at);

            CREATE TABLE IF NOT EXISTS user_profiles (
                user_id TEXT PRIMARY KEY,
                preferences TEXT NOT NULL DEFAULT '{}',
                recent_activity TEXT NOT NULL DEFAULT '[]',
                context TEXT NOT NULL DEFAULT '{}',
                language TEXT NOT NULL DEFAULT 'ko',
                updated_at TEXT NOT NULL DEFAULT (datetime('now'))
            );

            CREATE TABLE IF NOT EXISTS agent_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                session_id TEXT,
                from_agent TEXT NOT NULL,
                to_agent TEXT,
                action TEXT NOT NULL,
                summary TEXT,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
            CREATE INDEX IF NOT EXISTS idx_log_user ON agent_log(user_id);
            CREATE INDEX IF NOT EXISTS idx_log_time ON agent_log(created_at);
        """)
        conn.commit()

    # ── Blackboard Operations ──────────────────────────────────────

    def blackboard_write(self, key: str, value: Any, domain: str = "",
                         user_id: str = "", session_id: str = "",
                         ttl_seconds: Optional[int] = None):
        conn = self._get_conn()
        expires = None
        if ttl_seconds:
            expires = (datetime.utcnow() + timedelta(seconds=ttl_seconds)).isoformat()
        conn.execute("""
            INSERT INTO blackboard (key, value, domain, user_id, session_id, expires_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(key) DO UPDATE SET
                value=excluded.value,
                domain=excluded.domain,
                user_id=excluded.user_id,
                session_id=excluded.session_id,
                expires_at=excluded.expires_at,
                created_at=datetime('now')
        """, (key, json.dumps(value, ensure_ascii=False), domain, user_id, session_id, expires))
        conn.commit()

    def blackboard_read(self, key: str) -> Optional[Any]:
        conn = self._get_conn()
        row = conn.execute("""
            SELECT value, expires_at FROM blackboard WHERE key=?
        """, (key,)).fetchone()
        if not row:
            return None
        if row["expires_at"] and row["expires_at"] < datetime.utcnow().isoformat():
            conn.execute("DELETE FROM blackboard WHERE key=?", (key,))
            conn.commit()
            return None
        try:
            return json.loads(row["value"])
        except json.JSONDecodeError:
            return row["value"]

    def blackboard_search(self, user_id: str = "", domain: str = "",
                          limit: int = 20) -> list[dict]:
        conn = self._get_conn()
        conditions = []
        params = []
        if user_id:
            conditions.append("user_id=?")
            params.append(user_id)
        if domain:
            conditions.append("domain=?")
            params.append(domain)
        where = " AND ".join(conditions) if conditions else "1=1"
        rows = conn.execute(f"""
            SELECT key, value, domain, user_id, session_id, created_at
            FROM blackboard WHERE {where}
            AND (expires_at IS NULL OR expires_at >= datetime('now'))
            ORDER BY created_at DESC LIMIT ?
        """, (*params, limit)).fetchall()
        result = []
        for r in rows:
            try:
                val = json.loads(r["value"])
            except json.JSONDecodeError:
                val = r["value"]
            result.append({**dict(r), "value": val})
        return result

    def blackboard_delete(self, key: str):
        conn = self._get_conn()
        conn.execute("DELETE FROM blackboard WHERE key=?", (key,))
        conn.commit()

    # ── User Profile Operations ────────────────────────────────────

    def profile_get(self, user_id: str) -> Optional[dict]:
        conn = self._get_conn()
        row = conn.execute("SELECT * FROM user_profiles WHERE user_id=?", (user_id,)).fetchone()
        if not row:
            return None
        return {
            "user_id": row["user_id"],
            "preferences": json.loads(row["preferences"]),
            "recent_activity": json.loads(row["recent_activity"]),
            "context": json.loads(row["context"]),
            "language": row["language"],
            "updated_at": row["updated_at"],
        }

    def profile_upsert(self, user_id: str, preferences: Optional[dict] = None,
                       context: Optional[dict] = None, language: Optional[str] = None):
        conn = self._get_conn()
        existing = self.profile_get(user_id)
        if not existing:
            conn.execute("""
                INSERT INTO user_profiles (user_id, preferences, context, language)
                VALUES (?, ?, ?, ?)
            """, (
                user_id,
                json.dumps(preferences or {}, ensure_ascii=False),
                json.dumps(context or {}, ensure_ascii=False),
                language or "ko",
            ))
        else:
            updates = []
            params = []
            if preferences is not None:
                merged = {**existing["preferences"], **preferences}
                updates.append("preferences=?")
                params.append(json.dumps(merged, ensure_ascii=False))
            if context is not None:
                merged = {**existing["context"], **context}
                updates.append("context=?")
                params.append(json.dumps(merged, ensure_ascii=False))
            if language:
                updates.append("language=?")
                params.append(language)
            if updates:
                updates.append("updated_at=datetime('now')")
                params.append(user_id)
                conn.execute(f"UPDATE user_profiles SET {', '.join(updates)} WHERE user_id=?", params)
        conn.commit()

    def profile_log_activity(self, user_id: str, action: str, summary: str = ""):
        conn = self._get_conn()
        conn.execute("""
            INSERT INTO agent_log (user_id, from_agent, action, summary)
            VALUES (?, 'system', ?, ?)
        """, (user_id, action, summary))

        # Keep last 20 activities in profile
        prof = self.profile_get(user_id)
        if prof:
            activity = prof["recent_activity"]
            activity.append({
                "action": action,
                "summary": summary,
                "timestamp": datetime.utcnow().isoformat(),
            })
            conn.execute("""
                UPDATE user_profiles SET recent_activity=?, updated_at=datetime('now')
                WHERE user_id=?
            """, (json.dumps(activity[-20:], ensure_ascii=False), user_id))
            conn.commit()

    # ── Agent Log / Audit ──────────────────────────────────────────

    def log_agent_action(self, user_id: str, from_agent: str, action: str,
                         summary: str = "", session_id: str = "", to_agent: str = ""):
        conn = self._get_conn()
        conn.execute("""
            INSERT INTO agent_log (user_id, session_id, from_agent, to_agent, action, summary)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (user_id, session_id, from_agent, to_agent, action, summary))
        conn.commit()

    def get_recent_actions(self, user_id: str, limit: int = 10) -> list[dict]:
        conn = self._get_conn()
        rows = conn.execute("""
            SELECT * FROM agent_log WHERE user_id=? ORDER BY created_at DESC LIMIT ?
        """, (user_id, limit)).fetchall()
        return [dict(r) for r in rows]

    # ── Cleanup ────────────────────────────────────────────────────

    def cleanup_expired(self):
        conn = self._get_conn()
        conn.execute("DELETE FROM blackboard WHERE expires_at IS NOT NULL AND expires_at < datetime('now')")
        conn.commit()


# ── Main AgentMemory API ─────────────────────────────────────────────
class AgentMemory:
    """
    Unified memory API for all DADA-AI agents.

    Three memory tiers:
      - Blackboard:  cross-agent shared state (SQLite, TTL-based)
      - Session:     real-time conversation context (in-memory)
      - Profile:     persistent user data (SQLite)

    Auto-cleanup runs on write operations (25% chance).
    """

    def __init__(self):
        self._sqlite = SQLiteStore()
        self._session = SessionStore()
        self._cleanup_counter = 0

    def _maybe_cleanup(self):
        self._cleanup_counter += 1
        if self._cleanup_counter % 4 == 0:
            try:
                self._sqlite.cleanup_expired()
                self._session.cleanup()
            except Exception as e:
                logger.warning(f"Memory cleanup failed: {e}")

    # ── High-level Context API ─────────────────────────────────────

    def get_context(self, user_id: str, session_id: Optional[str] = None) -> dict:
        """
        Build full context for an agent request by merging all 3 layers.
        Session overrides Profile, Blackboard provides cross-agent data.
        """
        context = {
            "user_id": user_id,
            "session": {},
            "profile": {},
            "blackboard": [],
            "recent_actions": [],
        }

        # Layer 1: Profile (persistent)
        prof = self._sqlite.profile_get(user_id)
        if prof:
            context["profile"] = prof

        # Layer 2: Session (in-memory)
        if session_id:
            sess = self._session.get(session_id)
            if sess:
                context["session"] = sess

        # Layer 3: Blackboard (cross-agent)
        bb = self._sqlite.blackboard_search(user_id=user_id, limit=10)
        context["blackboard"] = bb

        # Recent agent actions
        context["recent_actions"] = self._sqlite.get_recent_actions(user_id, limit=5)

        return context

    def update_context(self, user_id: str, session_id: Optional[str] = None,
                       session_data: Optional[dict] = None,
                       profile_updates: Optional[dict] = None,
                       blackboard_writes: Optional[list[tuple]] = None,
                       action_log: Optional[dict] = None):
        """
        Atomic update across all memory layers.
        """
        self._maybe_cleanup()

        # Session
        if session_id and session_data:
            self._session.update(session_id, session_data)

        # Profile
        if profile_updates:
            self._sqlite.profile_upsert(user_id, **profile_updates)

        # Blackboard
        if blackboard_writes:
            for key, value, domain, ttl in blackboard_writes:
                self._sqlite.blackboard_write(
                    key, value, domain=domain, user_id=user_id,
                    session_id=session_id or "", ttl_seconds=ttl
                )

        # Action log
        if action_log:
            self._sqlite.log_agent_action(
                user_id=user_id,
                session_id=session_id or "",
                **action_log
            )

    # ── Transfer: pass context between agents ──────────────────────

    def transfer_context(self, user_id: str, from_agent: str, to_agent: str,
                         session_id: Optional[str] = None,
                         handoff_data: Optional[dict] = None):
        """
        When Supervisor hands off a request from Agent A to Agent B,
        this logs the transfer and injects handoff context into session.
        """
        self._sqlite.log_agent_action(
            user_id=user_id, session_id=session_id or "",
            from_agent=from_agent, to_agent=to_agent,
            action="transfer", summary=f"Handoff: {from_agent} → {to_agent}"
        )
        if session_id:
            self._session.update(session_id, {
                "_current_agent": to_agent,
                "_previous_agent": from_agent,
                "_handoff_data": handoff_data or {},
            })

    # ── Convenience: Blackboard shortcuts ──────────────────────────

    def write(self, key: str, value: Any, domain: str = "",
              user_id: str = "", session_id: str = "",
              ttl_seconds: Optional[int] = 3600):
        self._maybe_cleanup()
        self._sqlite.blackboard_write(key, value, domain, user_id, session_id, ttl_seconds)

    def read(self, key: str) -> Optional[Any]:
        return self._sqlite.blackboard_read(key)

    def search(self, user_id: str = "", domain: str = "", limit: int = 20) -> list[dict]:
        return self._sqlite.blackboard_search(user_id, domain, limit)


# ── Singleton ────────────────────────────────────────────────────────
_memory_instance: Optional[AgentMemory] = None

def get_memory() -> AgentMemory:
    global _memory_instance
    if _memory_instance is None:
        _memory_instance = AgentMemory()
    return _memory_instance
