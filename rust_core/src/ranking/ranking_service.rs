use crate::storage::sqlite::SqliteStorage;
use chrono::{DateTime, Utc};
use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Debug, Clone)]
#[flutter_rust_bridge::frb]
pub struct RankEntry {
    pub rank: u32,
    pub user_id: String,
    pub display_name: String,
    pub points: u64,
    pub badge: String,
}

#[derive(Debug, Clone)]
#[flutter_rust_bridge::frb]
pub struct UserPoints {
    pub user_id: String,
    pub display_name: String,
    pub total_points: u64,
    pub monthly_points: u64,
    pub weekly_points: u64,
    pub last_activity: DateTime<Utc>,
}

pub struct RankingService {
    storage: Arc<RwLock<SqliteStorage>>,
}

impl RankingService {
    pub fn new(storage: Arc<RwLock<SqliteStorage>>) -> Self {
        Self { storage }
    }

    pub async fn record_activity(
        &self,
        user_id: &str,
        display_name: &str,
        points: u64,
    ) -> Result<(), String> {
        let storage = self.storage.write().await;
        storage
            .record_points(user_id, display_name, points)
            .map_err(|e| format!("DB error: {}", e))
    }

    pub async fn get_leaderboard(&self, period: &str, limit: u32) -> Result<Vec<RankEntry>, String> {
        let storage = self.storage.read().await;
        let entries = storage
            .get_leaderboard(period, limit)
            .map_err(|e| format!("DB error: {}", e))?;

        let mut ranked: Vec<RankEntry> = entries
            .into_iter()
            .map(|(user_id, display_name, points)| RankEntry {
                rank: 0,
                user_id,
                display_name,
                points,
                badge: Self::get_badge(points),
            })
            .collect();

        ranked.sort_by(|a, b| b.points.cmp(&a.points));
        for (i, entry) in ranked.iter_mut().enumerate() {
            entry.rank = (i + 1) as u32;
        }

        Ok(ranked.into_iter().take(limit as usize).collect())
    }

    pub async fn get_my_rank(&self, user_id: &str) -> Result<(u32, u64), String> {
        let storage = self.storage.read().await;
        let all = storage
            .get_leaderboard("all", u32::MAX)
            .map_err(|e| format!("DB error: {}", e))?;

        let mut sorted = all.clone();
        sorted.sort_by(|a, b| b.2.cmp(&a.2));

        let pos = sorted.iter().position(|(id, _, _)| id == user_id);
        let points = all.iter().find(|(id, _, _)| id == user_id).map(|(_, _, p)| p).copied().unwrap_or(0);

        match pos {
            Some(idx) => Ok(((idx + 1) as u32, points)),
            None => Ok((0, points)),
        }
    }

    pub async fn get_user_points(&self, user_id: &str) -> Result<UserPoints, String> {
        let storage = self.storage.read().await;
        storage
            .get_user_points(user_id)
            .map_err(|e| format!("DB error: {}", e))
    }

    pub fn get_badge(points: u64) -> String {
        match points {
            0..=999 => "Newbie".to_string(),
            1000..=4999 => "Active".to_string(),
            5000..=19999 => "Star".to_string(),
            _ => "Legend".to_string(),
        }
    }
}
