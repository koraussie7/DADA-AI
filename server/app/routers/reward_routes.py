"""
reward_routes.py — DADA-Video-Universe DADAPOINT 보상 API
Minima RPC를 통해 조회수/좋아요 기반 DADAPOINT 토큰 지급
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import requests
import json
import hashlib
import time
from datetime import datetime

router = APIRouter()

# Minima RPC 설정 (로컬 Minima MDS)
MINIMA_MDS = "http://127.0.0.1:9003"
# 원격 Minima RPC (차단 시 로컬 사용)
MINIMA_RPC = "http://127.0.0.1:9003"
MINIMA_USER = "minima"
MINIMA_PASS = "privseairpc"
DADAPOINT_COIN = "0x16FAC6DF9F8F406973A2C0C9AAF66CACEC62E2C3C96BEB6CB85A6D5F8EC557C2"

# 보상 rate
REWARD_RATE = {
    "view": 0.001,    # 1000 views → 1 DADAPOINT
    "like": 0.1,      # 10 likes → 1 DADAPOINT
    "max_per_post": 100
}

class RewardRequest(BaseModel):
    to: str
    amount: float
    token: str = DADAPOINT_COIN
    memo: str = ""

class ClaimRequest(BaseModel):
    videoId: str
    to: str
    amount: float
    memo: str = ""

@router.post("/reward/send")
async def send_reward(req: RewardRequest):
    """DADAPOINT 보상 전송 (Hermes → Minima RPC)"""
    try:
        # MDS RPC로 Minima에 newcoin 명령
        payload = {
            "function": "newcoin",
            "tokenid": req.token,
            "amount": req.amount,
            "to": req.to,
            "memo": req.memo or "DADA Video Reward"
        }
        
        resp = requests.post(f"{MINIMA_MDS}/mds/cmd/", 
                           json=payload,
                           timeout=10)
        
        result = resp.json()
        return {"status": "ok", "tx": result, "amount": req.amount, "to": req.to}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/reward/claim")
async def claim_reward(req: ClaimRequest):
    """보상 청구 처리"""
    try:
        # MDS RPC로 보상 전송
        payload = {
            "function": "newcoin",
            "tokenid": DADAPOINT_COIN,
            "amount": req.amount,
            "to": req.to,
            "memo": req.memo or f"DADA Reward for {req.videoId}"
        }
        
        resp = requests.post(f"{MINIMA_MDS}/mds/cmd/", 
                           json=payload,
                           timeout=10)
        
        result = resp.json()
        
        return {
            "status": "ok",
            "tx": result,
            "amount": req.amount,
            "videoId": req.videoId,
            "to": req.to,
            "claimed_at": datetime.utcnow().isoformat()
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/reward/balance/{address}")
async def get_balance(address: str):
    """DADAPOINT 잔액 조회"""
    try:
        payload = {
            "function": "balance",
            "address": address,
            "tokenid": DADAPOINT_COIN
        }
        
        resp = requests.post(f"{MINIMA_MDS}/mds/cmd/", 
                           json=payload,
                           timeout=10)
        
        result = resp.json()
        return {"address": address, "balance": result}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
