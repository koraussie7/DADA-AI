use chrono::{DateTime, Utc};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};

use crate::ranking::ranking_service::UserPoints;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct StoredMessage {
    pub id: i64,
    pub sender: String,
    pub content: String,
    pub is_ai: bool,
    pub timestamp: String,
}

pub struct SqliteStorage {
    conn: Connection,
}

impl SqliteStorage {
    pub fn new(path: &str) -> anyhow::Result<Self> {
        let conn = Connection::open(path)?;
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sender TEXT NOT NULL,
                content TEXT NOT NULL,
                is_ai INTEGER NOT NULL DEFAULT 0,
                timestamp TEXT NOT NULL DEFAULT (datetime('now'))
            );
            CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp);
            CREATE TABLE IF NOT EXISTS peer_cache (
                peer_id TEXT PRIMARY KEY,
                last_seen TEXT NOT NULL DEFAULT (datetime('now')),
                alias TEXT
            );
            CREATE TABLE IF NOT EXISTS user_points (
                user_id TEXT NOT NULL,
                display_name TEXT NOT NULL DEFAULT '',
                points INTEGER NOT NULL DEFAULT 0,
                recorded_at TEXT NOT NULL DEFAULT (datetime('now')),
                PRIMARY KEY (user_id, recorded_at)
            );
            CREATE INDEX IF NOT EXISTS idx_user_points_id ON user_points(user_id);
            CREATE INDEX IF NOT EXISTS idx_user_points_at ON user_points(recorded_at);",
        )?;
        Ok(Self { conn })
    }

    pub fn save_message(&self, sender: &str, content: &str, is_ai: bool) -> anyhow::Result<i64> {
        self.conn.execute(
            "INSERT INTO messages (sender, content, is_ai) VALUES (?1, ?2, ?3)",
            params![sender, content, is_ai as i32],
        )?;
        Ok(self.conn.last_insert_rowid())
    }

    pub fn record_points(
        &self,
        user_id: &str,
        display_name: &str,
        points: u64,
    ) -> anyhow::Result<()> {
        self.conn.execute(
            "INSERT INTO user_points (user_id, display_name, points) VALUES (?1, ?2, ?3)",
            params![user_id, display_name, points as i64],
        )?;
        Ok(())
    }

    pub fn get_leaderboard(
        &self,
        period: &str,
        limit: u32,
    ) -> anyhow::Result<Vec<(String, String, u64)>> {
        let where_clause = match period {
            "weekly" => "AND recorded_at >= datetime('now', '-7 days')",
            "monthly" => "AND recorded_at >= datetime('now', '-30 days')",
            "creators" => "AND display_name LIKE '%[Creator]%'",
            _ => "", // "all"
        };
        let query = format!(
            "SELECT user_id, display_name, SUM(points) as total
             FROM user_points
             WHERE 1=1 {}
             GROUP BY user_id
             ORDER BY total DESC
             LIMIT ?1",
            where_clause
        );
        let mut stmt = self.conn.prepare(&query)?;
        let entries = stmt
            .query_map(params![limit as i64], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, i64>(2)? as u64,
                ))
            })?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(entries)
    }

    pub fn get_user_points(&self, user_id: &str) -> anyhow::Result<UserPoints> {
        let total: i64 = self.conn.query_row(
            "SELECT COALESCE(SUM(points), 0) FROM user_points WHERE user_id = ?1",
            params![user_id],
            |row| row.get(0),
        )?;
        let monthly: i64 = self.conn.query_row(
            "SELECT COALESCE(SUM(points), 0) FROM user_points WHERE user_id = ?1 AND recorded_at >= datetime('now', '-30 days')",
            params![user_id],
            |row| row.get(0),
        )?;
        let weekly: i64 = self.conn.query_row(
            "SELECT COALESCE(SUM(points), 0) FROM user_points WHERE user_id = ?1 AND recorded_at >= datetime('now', '-7 days')",
            params![user_id],
            |row| row.get(0),
        )?;
        let name: String = self
            .conn
            .query_row(
                "SELECT display_name FROM user_points WHERE user_id = ?1 ORDER BY recorded_at DESC LIMIT 1",
                params![user_id],
                |row| row.get(0),
            )
            .unwrap_or_default();
        Ok(UserPoints {
            user_id: user_id.to_string(),
            display_name: name,
            total_points: total as u64,
            monthly_points: monthly as u64,
            weekly_points: weekly as u64,
            last_activity: Utc::now(),
        })
    }

    pub fn get_recent_messages(&self, limit: i64) -> anyhow::Result<Vec<StoredMessage>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, sender, content, is_ai, timestamp FROM messages ORDER BY timestamp DESC LIMIT ?1",
        )?;
        let messages = stmt
            .query_map(params![limit], |row| {
                Ok(StoredMessage {
                    id: row.get(0)?,
                    sender: row.get(1)?,
                    content: row.get(2)?,
                    is_ai: row.get::<_, i32>(3)? != 0,
                    timestamp: row.get(4)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(messages)
    }
}
