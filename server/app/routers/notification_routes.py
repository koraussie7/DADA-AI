"""
Agent Notification API — 팝업레이어 알림 시스템
===============================================
에이전트가 생성한 알림을 Flutter 앱에 제공

Endpoints:
  GET  /notifications/{user_id}          — 알림 목록
  GET  /notifications/{user_id}/popup    — 팝업레이어 알림 (읽지 않은 것만)
  GET  /notifications/{user_id}/count    — 읽지 않은 알림 개수
  POST /notifications/{noti_id}/read     — 읽음 처리
  POST /notifications/{user_id}/read-all — 전체 읽음 처리
  POST /notifications/test               — 테스트 알림 생성
"""

from __future__ import annotations
import logging
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.agents.notifications import get_notifications, notify_user
from app.agents.registry import get_registry

logger = logging.getLogger("dada.notifications_api")
router = APIRouter(prefix="/notifications", tags=["Notifications"])


class TestNotiRequest(BaseModel):
    user_id: str
    agent_id: str = "system"
    title: str = "테스트 알림"
    body: str = "이것은 테스트 알림입니다."
    priority: str = "normal"
    is_popup: bool = True


@router.get("/{user_id}")
async def list_notifications(user_id: str, limit: int = 50,
                              offset: int = 0, include_read: bool = True):
    """Get notification list for a user."""
    noti = get_notifications()
    items = noti.get_notifications(user_id, limit=limit, offset=offset,
                                    include_read=include_read)
    unread = noti.get_unread_count(user_id)
    return {
        "user_id": user_id,
        "total": len(items),
        "unread_count": unread,
        "notifications": items,
    }


@router.get("/{user_id}/popup")
async def popup_notifications(user_id: str, limit: int = 20):
    """
    팝업레이어 알림 — 읽지 않은 팝업 알림만 반환.
    Flutter WebView가 이걸로 팝업레이어를 렌더링합니다.
    """
    noti = get_notifications()
    items = noti.get_popup_notifications(user_id, limit=limit)
    unread = noti.get_unread_count(user_id)

    # Build agent context for each notification
    enriched = []
    for item in items:
        agent_info = get_registry().agent_detail(item["agent_id"])
        enriched.append({
            **item,
            "agent_name": (agent_info or {}).get("agent_id", "system"),
            "agent_enabled": (agent_info or {}).get("enabled", True) if agent_info else True,
        })

    return {
        "user_id": user_id,
        "total": len(enriched),
        "unread_count": unread,
        "notifications": enriched,
    }


@router.get("/{user_id}/count")
async def unread_count(user_id: str):
    """Get unread notification count (for badge)."""
    noti = get_notifications()
    count = noti.get_unread_count(user_id)
    return {
        "user_id": user_id,
        "unread_count": count,
    }


@router.post("/{noti_id}/read")
async def mark_read(noti_id: int):
    """Mark a notification as read."""
    noti = get_notifications()
    if noti.mark_read(noti_id):
        return {"status": "ok", "notification_id": noti_id}
    raise HTTPException(status_code=404, detail="Notification not found")


@router.post("/{user_id}/read-all")
async def mark_all_read(user_id: str):
    """Mark all notifications as read."""
    noti = get_notifications()
    count = noti.mark_all_read(user_id)
    return {
        "user_id": user_id,
        "marked_read": count,
        "message": f"{count}개의 알림을 읽음 처리했습니다.",
    }


@router.delete("/{noti_id}")
async def delete_notification(noti_id: int):
    """Delete a notification."""
    noti = get_notifications()
    if noti.delete(noti_id):
        return {"status": "ok", "notification_id": noti_id}
    raise HTTPException(status_code=404, detail="Notification not found")


@router.post("/test")
async def create_test_notification(req: TestNotiRequest):
    """Create a test notification."""
    noti = notify_user(
        user_id=req.user_id,
        agent_id=req.agent_id,
        title=req.title,
        body=req.body,
        priority=req.priority,
        is_popup=req.is_popup,
    )
    return {
        "status": "created",
        "notification": noti,
    }
