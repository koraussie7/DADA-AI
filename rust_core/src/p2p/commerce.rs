use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

pub const COMMERCE_TOPIC: &str = "liberty/commerce";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommerceMessage {
    pub msg_type: CommerceMessageType,
    pub sender_peer_id: String,
    pub video_id: String,
    pub timestamp: i64,
    pub payload: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CommerceMessageType {
    LiveStreamStart,
    LiveStreamEnd,
    ProductTagged,
    Purchase,
    PriceUpdate,
    AiRecommendation,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Product {
    pub id: String,
    pub name: String,
    pub price: u64,
    pub image_url: String,
    pub badge: Option<String>,
    pub reward_points: u64,
}
