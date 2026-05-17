"""Stripe webhook handler for DADA Point charge completion."""
import json
import os
import logging

import stripe
from fastapi import APIRouter, Request, HTTPException

log = logging.getLogger("dada.stripe_webhook")

router = APIRouter(prefix="/webhook", tags=["Webhook"])


@router.post("/stripe")
async def stripe_webhook(request: Request):
    """Handle Stripe webhook events (checkout.session.completed)."""
    stripe.api_key = os.getenv("STRIPE_SECRET_KEY", "")
    endpoint_secret = os.getenv("STRIPE_WEBHOOK_SECRET", "")

    if not endpoint_secret:
        log.warning("STRIPE_WEBHOOK_SECRET not set — webhook validation disabled")
        payload = await request.body()
        event = stripe.Event.construct_from(json.loads(payload), stripe.api_key)
    else:
        payload = await request.body()
        sig_header = request.headers.get("stripe-signature")
        if not sig_header:
            raise HTTPException(400, "Missing stripe-signature header")
        try:
            event = stripe.Webhook.construct_event(payload, sig_header, endpoint_secret)
        except (ValueError, stripe.error.SignatureVerificationError) as e:
            raise HTTPException(400, f"Invalid signature: {e}")

    # ── Handle checkout.session.completed ────────────────────────
    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        metadata = session.get("metadata", {})

        if metadata.get("type") == "point_charge":
            charge_id = metadata.get("charge_id")
            user_id = metadata.get("user_id")
            point_amount = int(metadata.get("point_amount", 0))

            if not charge_id or not user_id or not point_amount:
                log.error(f"Incomplete metadata in webhook: {metadata}")
                return {"status": "error", "message": "Incomplete metadata"}

            # Stripe payment confirmed — charge is pending admin approval
            from app.routers.point_charge import update_charge_status
            update_charge_status(charge_id, "pending")

            log.info(f"✅ Stripe payment completed: {user_id} → {point_amount} DADA Point (pending admin approval)")
            return {"status": "pending_approval", "charge_id": charge_id}

    # ── Handle payment_intent.succeeded (backup) ─────────────────
    elif event["type"] == "payment_intent.succeeded":
        log.info("Payment intent succeeded (no action needed)")

    return {"status": "received"}
