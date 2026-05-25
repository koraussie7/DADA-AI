"""
DADA-AI Agent Notification System
=================================
- 에이전트가 생성한 알림을 관리
- 팝업레이어(Popup Layer)로 사용자에게 전달
- WebSocket 실시간 푸시 지원

사용 예:
    from agents.notifications import notify_user
    notify_user("user_123", "hotel", "새로운 호텔 입찰이 도착했습니다!")
"""

from __future__ import annotations
import os
import json
import time
import logging
import sqlite3
import threading
from datetime import datetime, timezone
from typing import Optional
from enum import Enum

logger = logging.getLogger("dada.notifications")

NOTI_DB = os.getenv("NOTIFICATION_DB", "/root/DADA-AI/notifications.db")


class NotiPriority(str, Enum):
    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"
    URGENT = "urgent"


class NotificationSystem:
    """
    Thread-safe notification manager.
    Each notification:
      - id:          unique
      - user_id:     target user
      - agent_id:    source agent (hotel, food, wallet, system)
      - title:       notification title
      - body:        notification body
      - priority:    low/normal/high/urgent
      - action_type: deep link or agent route
      - action_data: JSON payload for the action
      - is_read:     read/unread
      - is_popup:    show as popup layer (true) or badge only (false)
      - created_at:  timestamp
    """

    def __init__(self, db_path: str = NOTI_DB):
        self._db_path = db_path
        self._local = threading.local()
        self._init_db()
        # In-memory unread count cache
        self._unread_cache: dict[str, int] = {}
        self._cache_lock = threading.Lock()

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
            CREATE TABLE IF NOT EXISTS notifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                agent_id TEXT NOT NULL DEFAULT 'system',
                title TEXT NOT NULL,
                body TEXT NOT NULL DEFAULT '',
                priority TEXT NOT NULL DEFAULT 'normal',
                action_type TEXT NOT NULL DEFAULT '',
                action_data TEXT NOT NULL DEFAULT '{}',
                is_read INTEGER NOT NULL DEFAULT 0,
                is_popup INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
            CREATE INDEX IF NOT EXISTS idx_noti_user ON notifications(user_id);
            CREATE INDEX IF NOT EXISTS idx_noti_user_read ON notifications(user_id, is_read);
            CREATE INDEX IF NOT EXISTS idx_noti_created ON notifications(created_at DESC);
        """)
        conn.commit()

    # ── Create Notification ────────────────────────────────────────

    def notify(self, user_id: str, title: str, body: str = "",
               agent_id: str = "system", priority: str = "normal",
               action_type: str = "", action_data: Optional[dict] = None,
               is_popup: bool = True) -> dict:
        """
        Create a notification. Returns the notification dict.
        If is_popup=True, it will appear in the 팝업레이어 page.
        """
        conn = self._get_conn()
        action_json = json.dumps(action_data or {}, ensure_ascii=False)
        conn.execute("""
            INSERT INTO notifications
                (user_id, agent_id, title, body, priority,
                 action_type, action_data, is_popup)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (user_id, agent_id, title, body, priority,
              action_type, action_json, int(is_popup)))
        conn.commit()
        noti_id = conn.execute("SELECT last_insert_rowid()").fetchone()[0]

        # Invalidate cache
        with self._cache_lock:
            self._unread_cache.pop(user_id, None)

        logger.info(f"[NOTI] {agent_id} → {user_id}: {title}")

        return {
            "id": noti_id,
            "user_id": user_id,
            "agent_id": agent_id,
            "title": title,
            "body": body,
            "priority": priority,
            "action_type": action_type,
            "action_data": action_data or {},
            "is_read": False,
            "is_popup": is_popup,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }

    # ── Convenience: Agent notification shortcuts ──────────────────

    def notify_hotel_booking(self, user_id: str, location: str,
                             status: str = "requested"):
        titles = {
            "requested": "🏨 호텔 요청 등록 완료",
            "bid_received": "🏨 새 호텔 입찰 도착",
            "confirmed": "✅ 호텔 예약 확정",
        }
        bodies = {
            "requested": f"{location} 호텔 요청이 등록되었습니다. 24시간 내 입찰이 도착합니다.",
            "bid_received": f"{location} 호텔리어가 입찰을 보냈습니다! 확인해보세요.",
            "confirmed": f"{location} 호텔 예약이 확정되었습니다.",
        }
        return self.notify(
            user_id=user_id,
            title=titles.get(status, "🏨 호텔 알림"),
            body=bodies.get(status, ""),
            agent_id="hotel",
            action_type="hotel_bids",
            is_popup=True,
        )

    def notify_food(self, user_id: str, restaurant: str = "",
                    status: str = "order_placed"):
        titles = {
            "order_placed": "🍜 주문이 접수되었습니다",
            "preparing": "👨‍🍳 음식 준비중",
            "delivering": "🛵 배달 출발",
            "delivered": "✅ 배달 완료",
        }
        bodies = {
            "order_placed": f"{restaurant} 주문이 전송되었습니다." if restaurant else "주문이 접수되었습니다.",
            "preparing": "음식이 준비 중입니다. 곧 배달 출발 예정!",
            "delivering": "라이더가 출발했습니다! 도착 예정 시간을 확인하세요.",
            "delivered": "맛있게 드세요! 😊",
        }
        return self.notify(
            user_id=user_id,
            title=titles.get(status, "🍜 음식 알림"),
            body=bodies.get(status, ""),
            agent_id="food",
            action_type="food_tracking",
            is_popup=status in ("delivering", "delivered"),
        )

    def notify_wallet(self, user_id: str, action: str,
                      chain: str = "", amount: str = ""):
        titles = {
            "send": "💸 송금 완료",
            "receive": "📥 입금 완료",
            "swap": "🔄 스왑 완료",
            "balance_low": "⚠️ 잔액 부족 알림",
        }
        bodies = {
            "send": f"{amount} {chain} 송금이 완료되었습니다.",
            "receive": f"{amount} {chain} 입금되었습니다.",
            "swap": f"스왑이 완료되었습니다.",
            "balance_low": f"{chain} 잔액이 부족합니다. 충전해주세요.",
        }
        return self.notify(
            user_id=user_id,
            title=titles.get(action, "👛 지갑 알림"),
            body=bodies.get(action, ""),
            agent_id="wallet",
            priority="high" if action == "balance_low" else "normal",
            action_type=f"wallet_{action}",
            is_popup=action in ("receive", "balance_low"),
        )

    # ── Query ──────────────────────────────────────────────────────

    def get_notifications(self, user_id: str, limit: int = 50,
                          offset: int = 0, include_read: bool = True,
                          popup_only: bool = False) -> list[dict]:
        """Get notifications for a user."""
        conn = self._get_conn()
        conditions = ["user_id=?"]
        params = [user_id]
        if not include_read:
            conditions.append("is_read=0")
        if popup_only:
            conditions.append("is_popup=1")

        where = " AND ".join(conditions)
        rows = conn.execute(f"""
            SELECT * FROM notifications
            WHERE {where}
            ORDER BY created_at DESC
            LIMIT ? OFFSET ?
        """, (*params, limit, offset)).fetchall()
        return [dict(r) for r in rows]

    def get_unread_count(self, user_id: str) -> int:
        """Get unread notification count (cached)."""
        with self._cache_lock:
            if user_id in self._unread_cache:
                return self._unread_cache[user_id]

        conn = self._get_conn()
        row = conn.execute(
            "SELECT COUNT(*) as cnt FROM notifications WHERE user_id=? AND is_read=0",
            (user_id,)
        ).fetchone()
        count = row["cnt"] if row else 0
        with self._cache_lock:
            self._unread_cache[user_id] = count
        return count

    def get_popup_notifications(self, user_id: str,
                                 limit: int = 20) -> list[dict]:
        """Get active popup-layer notifications (unread + is_popup)."""
        return self.get_notifications(
            user_id, limit=limit, include_read=False, popup_only=True
        )

    def mark_read(self, noti_id: int) -> bool:
        """Mark a single notification as read."""
        conn = self._get_conn()
        row = conn.execute(
            "SELECT user_id FROM notifications WHERE id=?", (noti_id,)
        ).fetchone()
        if not row:
            return False
        conn.execute("UPDATE notifications SET is_read=1 WHERE id=?", (noti_id,))
        conn.commit()
        with self._cache_lock:
            self._unread_cache.pop(row["user_id"], None)
        return True

    def mark_all_read(self, user_id: str) -> int:
        """Mark all notifications as read. Returns count."""
        conn = self._get_conn()
        conn.execute(
            "UPDATE notifications SET is_read=1 WHERE user_id=? AND is_read=0",
            (user_id,)
        )
        conn.commit()
        count = conn.execute(
            "SELECT changes() as cnt"
        ).fetchone()["cnt"]
        with self._cache_lock:
            self._unread_cache[user_id] = 0
        return count

    def delete(self, noti_id: int) -> bool:
        """Delete a notification."""
        conn = self._get_conn()
        row = conn.execute(
            "SELECT user_id FROM notifications WHERE id=?", (noti_id,)
        ).fetchone()
        if not row:
            return False
        conn.execute("DELETE FROM notifications WHERE id=?", (noti_id,))
        conn.commit()
        with self._cache_lock:
            self._unread_cache.pop(row["user_id"], None)
        return True


# ── Singleton ────────────────────────────────────────────────────────
_noti_instance: Optional[NotificationSystem] = None

def get_notifications() -> NotificationSystem:
    global _noti_instance
    if _noti_instance is None:
        _noti_instance = NotificationSystem()
    return _noti_instance


# Convenience function
def notify_user(user_id: str, agent_id: str, title: str, body: str = "",
                priority: str = "normal", is_popup: bool = True) -> dict:
    return get_notifications().notify(
        user_id=user_id, title=title, body=body,
        agent_id=agent_id, priority=priority, is_popup=is_popup,
    )
