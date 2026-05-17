"""DADA Point charge API — Stripe checkout initiation."""
import os
import uuid
import logging
from datetime import datetime

import stripe
from fastapi import APIRouter, HTTPException

from app.models.point_charge import PointChargeRequest, PointCharge, ChargeStatus

log = logging.getLogger("dada.point_charge")

stripe.api_key = os.getenv("STRIPE_SECRET_KEY", "")
STRIPE_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET", "")
BASE_URL = os.getenv("BASE_URL", "https://privseai.com")

router = APIRouter(prefix="/point", tags=["DADA Point"])

# ── DB helper ──────────────────────────────────────────────────
POINT_CHARGE_DB = os.getenv("POINT_CHARGE_DB", "/root/DADA-AI/point_charges.db")


def _init_db():
    import sqlite3
    os.makedirs(os.path.dirname(POINT_CHARGE_DB) or ".", exist_ok=True)
    conn = sqlite3.connect(POINT_CHARGE_DB)
    conn.execute("""CREATE TABLE IF NOT EXISTS point_charges (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        payment_method TEXT DEFAULT 'stripe',
        stripe_session_id TEXT,
        status TEXT DEFAULT 'pending',
        requested_at TEXT NOT NULL,
        approved_at TEXT,
        admin_id TEXT,
        reason TEXT
    )""")
    conn.commit()
    conn.close()


_init_db()


def _save_charge(charge: PointCharge):
    import sqlite3
    conn = sqlite3.connect(POINT_CHARGE_DB)
    conn.execute(
        "INSERT OR REPLACE INTO point_charges "
        "(id, user_id, amount, payment_method, stripe_session_id, status, requested_at, approved_at, admin_id, reason) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (charge.id, charge.user_id, charge.amount, charge.payment_method,
         charge.stripe_session_id, charge.status.value,
         charge.requested_at.isoformat(), charge.approved_at.isoformat() if charge.approved_at else None,
         charge.admin_id, charge.reason),
    )
    conn.commit()
    conn.close()


def get_pending_charges() -> list[dict]:
    """Return all pending point charges for admin review."""
    import sqlite3
    conn = sqlite3.connect(POINT_CHARGE_DB)
    rows = conn.execute(
        "SELECT id, user_id, amount, payment_method, stripe_session_id, status, requested_at, approved_at, admin_id, reason "
        "FROM point_charges WHERE status = 'pending' ORDER BY requested_at DESC"
    ).fetchall()
    conn.close()
    return [
        {
            "id": r[0],
            "user_id": r[1],
            "amount": r[2],
            "payment_method": r[3],
            "stripe_session_id": r[4],
            "status": r[5],
            "requested_at": r[6],
            "approved_at": r[7],
            "admin_id": r[8],
            "reason": r[9],
        }
        for r in rows
    ]


def get_charge_by_id(charge_id: str) -> dict | None:
    """Look up a single charge record."""
    import sqlite3
    conn = sqlite3.connect(POINT_CHARGE_DB)
    r = conn.execute(
        "SELECT id, user_id, amount, payment_method, stripe_session_id, status, requested_at, approved_at, admin_id, reason "
        "FROM point_charges WHERE id = ?", (charge_id,)
    ).fetchone()
    conn.close()
    if not r:
        return None
    return {
        "id": r[0], "user_id": r[1], "amount": r[2], "payment_method": r[3],
        "stripe_session_id": r[4], "status": r[5], "requested_at": r[6],
        "approved_at": r[7], "admin_id": r[8], "reason": r[9],
    }


def update_charge_status(charge_id: str, status: str, admin_id: str | None = None, reason: str | None = None):
    """Update charge status (approve/reject)."""
    import sqlite3
    conn = sqlite3.connect(POINT_CHARGE_DB)
    conn.execute(
        "UPDATE point_charges SET status = ?, approved_at = ?, admin_id = ?, reason = ? WHERE id = ?",
        (status, datetime.utcnow().isoformat(), admin_id, reason, charge_id),
    )
    conn.commit()
    conn.close()


def give_dada_point(user_id: str, amount: int):
    """Add DADA Points to the user's balance in the leaderboard DB."""
    import sqlite3
    from app.routers.platform_routes import LEADERBOARD_DB, record_points
    record_points(user_id, f"User_{user_id[:8] if user_id else '0'}", amount, "point_charge")


# ── Endpoints ──────────────────────────────────────────────────

@router.post("/charge")
async def charge_dada_point(req: PointChargeRequest, user_id: str | None = None):
    """Create a Stripe checkout session for DADA Point charging."""
    if not stripe.api_key or stripe.api_key.startswith("sk_test_dummy"):
        raise HTTPException(503, "Stripe not configured — set STRIPE_SECRET_KEY")

    if req.amount < 100:
        raise HTTPException(400, "Minimum charge is 100 DADA Points")
    if req.amount > 1000000:
        raise HTTPException(400, "Maximum charge is 1,000,000 DADA Points")

    uid = user_id or "anonymous"
    charge_id = str(uuid.uuid4())

    # Price: 1 DADA Point = 100 KRW (or local equivalent)
    unit_amount_krw = req.amount * 100

    try:
        session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            line_items=[{
                "price_data": {
                    "currency": "krw",
                    "product_data": {
                        "name": f"DADA Point {req.amount:,}개 충전",
                        "description": "DADA-AI 플랫폼 내 포인트",
                    },
                    "unit_amount": unit_amount_krw,
                },
                "quantity": 1,
            }],
            mode="payment",
            success_url=f"{BASE_URL}/point/success?session_id={{CHECKOUT_SESSION_ID}}",
            cancel_url=f"{BASE_URL}/point/cancel",
            metadata={
                "charge_id": charge_id,
                "user_id": uid,
                "point_amount": str(req.amount),
                "type": "point_charge",
            },
        )
    except stripe.error.StripeError as e:
        log.error(f"Stripe error: {e}")
        raise HTTPException(502, f"Stripe error: {e.user_message or str(e)}")

    # Save the pending charge
    charge = PointCharge(
        id=charge_id,
        user_id=uid,
        amount=req.amount,
        payment_method=req.payment_method,
        stripe_session_id=session.id,
        status=ChargeStatus.PENDING,
        requested_at=datetime.utcnow(),
    )
    _save_charge(charge)

    return {
        "status": "success",
        "checkout_url": session.url,
        "session_id": session.id,
        "charge_id": charge_id,
    }


@router.get("/charge/{charge_id}")
async def get_charge_status(charge_id: str):
    """Check the status of a charge request."""
    charge = get_charge_by_id(charge_id)
    if not charge:
        raise HTTPException(404, "Charge not found")
    return {"charge": charge}
