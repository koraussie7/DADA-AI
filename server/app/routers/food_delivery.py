"""Food Delivery (Bidding System) — inDriver-style P2P bidding."""

import os
import json
import uuid
import logging
from datetime import datetime, timedelta
from typing import Optional, List

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

logger = logging.getLogger("food_delivery")

router = APIRouter(tags=["food"])

# Persistence
FOOD_DB = os.getenv("FOOD_DB", "food_orders.json")


def _load_food_data() -> dict:
    if os.path.exists(FOOD_DB):
        try:
            with open(FOOD_DB) as f:
                return json.load(f)
        except Exception:
            pass
    return {"requests": {}, "bids": {}}


def _save_food_data(data: dict) -> None:
    with open(FOOD_DB, "w") as f:
        json.dump(data, f, indent=2, default=str)


# --- Models ---
class FoodItem(BaseModel):
    name: str
    quantity: int
    category: str


class FoodOrderRequestIn(BaseModel):
    items: List[FoodItem]
    delivery_address: str
    delivery_lat: float = 0.0
    delivery_lng: float = 0.0
    max_budget: float
    notes: Optional[str] = None


class FoodBidIn(BaseModel):
    restaurant_id: str
    restaurant_name: str
    price: float
    estimated_minutes: int
    message: str = ""
    rating: float = 0.0


# --- Endpoints ---
@router.post("/food/request")
async def create_food_request(req: FoodOrderRequestIn):
    """Create a new food delivery request (customer posts order for bidding)."""
    data = _load_food_data()
    request_id = f"fr_{uuid.uuid4().hex[:8]}"
    entry = {
        "id": request_id,
        "status": "bidding",
        "created_at": datetime.utcnow().isoformat(),
        "expires_at": (datetime.utcnow() + timedelta(minutes=5)).isoformat(),
        **req.model_dump(),
    }
    data["requests"][request_id] = entry
    _save_food_data(data)

    # Broadcast to food delivery peers via WebSocket
    from app.main import food_connections

    for ws in list(food_connections.values()):
        try:
            await ws.send_text(json.dumps({"type": "food_request", "request": entry}))
        except Exception:
            pass

    return {"request_id": request_id, "status": "bidding"}


@router.post("/food/bid/{request_id}")
async def submit_food_bid(request_id: str, bid: FoodBidIn):
    """Restaurant submits a bid on a food delivery request."""
    data = _load_food_data()
    if request_id not in data["requests"]:
        raise HTTPException(404, "Request not found")
    bid_id = f"fb_{uuid.uuid4().hex[:8]}"
    bid_entry = {
        **bid.model_dump(),
        "id": bid_id,
        "submitted_at": datetime.utcnow().isoformat(),
    }
    data["bids"].setdefault(request_id, []).append(bid_entry)
    _save_food_data(data)

    # Notify the requester if connected
    from app.main import connections

    req = data["requests"][request_id]
    peer_id = req.get("peer_id")
    if peer_id and peer_id in connections:
        try:
            await connections[peer_id].send_text(
                json.dumps({
                    "type": "food_bid",
                    "request_id": request_id,
                    "bid": bid_entry,
                })
            )
        except Exception:
            pass

    return {"status": "bid_submitted", "bid_id": bid_id}


@router.get("/food/bids/{request_id}")
async def get_food_bids(request_id: str):
    """List all bids for a given food delivery request."""
    data = _load_food_data()
    if request_id not in data["requests"]:
        raise HTTPException(404, "Request not found")
    return {
        "request_id": request_id,
        "bids": data["bids"].get(request_id, []),
        "request": data["requests"][request_id],
    }


@router.post("/food/select/{request_id}")
async def select_food_bid(request_id: str, body: dict):
    """Customer selects the winning bid for their food delivery request."""
    bid_id = body.get("bid_id") or body.get("restaurant_id")
    data = _load_food_data()
    if request_id not in data["requests"]:
        raise HTTPException(404, "Request not found")
    # Verify the bid exists — match by id or restaurant_id
    bids = data["bids"].get(request_id, [])
    matched = [b for b in bids if b.get("id") == bid_id or b.get("restaurant_id") == bid_id]
    if not matched:
        raise HTTPException(404, "Bid not found for this request")
    selected = matched[0]
    data["requests"][request_id]["status"] = "confirmed"
    data["requests"][request_id]["selected_bid"] = selected["id"]
    data["requests"][request_id]["selected_restaurant"] = selected["restaurant_name"]
    _save_food_data(data)
    return {"status": "confirmed", "request_id": request_id, "bid_id": selected["id"], "restaurant": selected["restaurant_name"]}
