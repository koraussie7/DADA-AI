"""DADA Point charge models."""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from enum import Enum


class ChargeStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class PointChargeRequest(BaseModel):
    """Request body for initiating a point charge."""
    amount: int  # DADA Points to charge
    payment_method: str = "stripe"


class ChargeApproveRequest(BaseModel):
    """Request body for admin approval/rejection."""
    charge_id: str
    action: str  # "approve" or "reject"
    reason: Optional[str] = None


class PointCharge(BaseModel):
    """Represents a point charge record."""
    id: str
    user_id: str
    amount: int
    payment_method: str
    status: ChargeStatus = ChargeStatus.PENDING
    stripe_session_id: Optional[str] = None
    requested_at: datetime
    approved_at: Optional[datetime] = None
    admin_id: Optional[str] = None
    reason: Optional[str] = None
