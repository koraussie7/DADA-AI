use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};

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
            );",
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
