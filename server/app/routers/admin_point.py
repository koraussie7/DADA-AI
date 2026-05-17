"""Admin approval API for DADA Point charge requests."""
import logging
from typing import Optional

from fastapi import APIRouter, HTTPException, Query

from app.models.point_charge import ChargeApproveRequest

log = logging.getLogger("dada.admin_point")

router = APIRouter(prefix="/admin/point", tags=["Admin"])


@router.get("/pending")
async def get_pending_charges():
    """관리자가 검토할 대기 중인 충전 요청 목록"""
    from app.routers.point_charge import get_pending_charges as _pending
    charges = _pending()
    return {"charges": charges, "total": len(charges)}


@router.post("/approve")
async def approve_charge(req: ChargeApproveRequest, admin_id: Optional[str] = Query(None)):
    """관리자 승인/거부 — 요청된 DADA Point를 실제로 지급하거나 거부합니다."""
    from app.routers.point_charge import (
        get_charge_by_id,
        update_charge_status,
        give_dada_point,
    )

    charge = get_charge_by_id(req.charge_id)
    if not charge:
        raise HTTPException(404, "충전 요청을 찾을 수 없습니다.")
    if charge["status"] != "pending":
        raise HTTPException(400, f"이미 처리된 요청입니다 (현재 상태: {charge['status']})")

    aid = admin_id or "admin"

    if req.action == "approve":
        # DADA Point 지급
        give_dada_point(charge["user_id"], charge["amount"])
        update_charge_status(req.charge_id, "approved", aid, req.reason)
        log.info(f"✅ 관리자 승인: {charge['user_id']} → {charge['amount']} DADA Point (admin={aid})")
        return {
            "status": "approved",
            "message": f"{charge['amount']} DADA Point 지급 완료",
            "charge_id": req.charge_id,
        }

    elif req.action == "reject":
        update_charge_status(req.charge_id, "rejected", aid, req.reason)
        log.info(f"❌ 관리자 거부: {charge['user_id']} → {charge['amount']} DADA Point (admin={aid})")
        return {
            "status": "rejected",
            "message": "충전 요청이 거부되었습니다.",
            "charge_id": req.charge_id,
        }

    else:
        raise HTTPException(400, "action은 'approve' 또는 'reject'여야 합니다.")


@router.get("/history")
async def get_charge_history(
    user_id: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=500),
):
    """모든 충전 내역 조회 (관리자 전용)."""
    import sqlite3
    from app.routers.point_charge import POINT_CHARGE_DB

    conn = sqlite3.connect(POINT_CHARGE_DB)
    if user_id:
        rows = conn.execute(
            "SELECT id, user_id, amount, payment_method, status, requested_at, approved_at, admin_id, reason "
            "FROM point_charges WHERE user_id = ? ORDER BY requested_at DESC LIMIT ?",
            (user_id, limit),
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT id, user_id, amount, payment_method, status, requested_at, approved_at, admin_id, reason "
            "FROM point_charges ORDER BY requested_at DESC LIMIT ?",
            (limit,),
        ).fetchall()
    conn.close()

    return {
        "history": [
            {
                "id": r[0], "user_id": r[1], "amount": r[2],
                "payment_method": r[3], "status": r[4],
                "requested_at": r[5], "approved_at": r[6],
                "admin_id": r[7], "reason": r[8],
            }
            for r in rows
        ]
    }
