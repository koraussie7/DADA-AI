"""Agent shared models and configuration."""

from __future__ import annotations
from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum


class AgentDomain(str, Enum):
    """DADA-AI business domains."""
    HOTEL = "hotel"
    FOOD = "food"
    WALLET = "wallet"
    TAXI = "taxi"
    MASSAGE = "massage"
    SUPPLIER = "supplier"
    PAYMENT = "payment"
    SUPPORT = "support"
    UNKNOWN = "unknown"


class AgentRequest(BaseModel):
    """Incoming request to an agent."""
    user_id: str = Field(..., description="User identifier")
    message: str = Field(..., description="User message / query")
    session_id: Optional[str] = None
    language: str = "ko"
    metadata: dict = Field(default_factory=dict)


class AgentResponse(BaseModel):
    """Structured response from any agent."""
    domain: AgentDomain
    reply: str = ""
    action_required: bool = False
    action_type: Optional[str] = None
    action_data: dict = Field(default_factory=dict)
    confidence: float = 0.0
    requires_human: bool = False
    error: Optional[str] = None


class IntentClassification(BaseModel):
    """Supervisor's classification result."""
    domain: AgentDomain
    sub_intent: str = ""
    confidence: float = 0.0
    entities: dict = Field(default_factory=dict)
    reasoning: str = ""
    agents: list[str] = Field(
        default_factory=list,
        description="Ordered list of agents to invoke for complex requests"
    )


# ── Hotel Domain ─────────────────────────────────────────────────────
class HotelSearchParams(BaseModel):
    location: str = ""
    check_in: str = ""
    check_out: str = ""
    guests: int = 1
    max_budget: Optional[int] = None
    requirements: list[str] = Field(default_factory=list)


# ── Food Domain ──────────────────────────────────────────────────────
class FoodSearchParams(BaseModel):
    query: str = ""
    location: str = ""
    cuisine: Optional[str] = None
    max_price: Optional[int] = None


# ── Wallet Domain ────────────────────────────────────────────────────
class WalletAction(str, Enum):
    BALANCE = "balance"
    PORTFOLIO = "portfolio"
    SEND = "send"
    SWAP = "swap"
    ADDRESS = "address"
    HISTORY = "history"
