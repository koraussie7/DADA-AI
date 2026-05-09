use crate::p2p::swarm::P2PSwarm;
use crate::ai::localai::LocalAIClient;
use crate::storage::sqlite::SqliteStorage;
use std::sync::Arc;
use tokio::sync::RwLock;

static INSTANCE: once_cell::sync::Lazy<Arc<RwLock<LibertyCore>>> =
    once_cell::sync::Lazy::new(|| {
        Arc::new(RwLock::new(LibertyCore::new()))
    });

pub struct LibertyCore {
    pub swarm: Option<Arc<RwLock<P2PSwarm>>>,
    pub ai: Option<LocalAIClient>,
    pub storage: Option<Arc<RwLock<SqliteStorage>>>,
    pub peer_name: String,
    pub is_initialized: bool,
}

impl LibertyCore {
    fn new() -> Self {
        Self {
            swarm: None,
            ai: None,
            storage: None,
            peer_name: String::new(),
            is_initialized: false,
        }
    }
}

/// Initialize the Liberty Reach core.
/// Must be called once before any other function.
#[flutter_rust_bridge::frb]
pub async fn init(peer_name: String, localai_url: String, storage_path: String) -> String {
    let mut core = INSTANCE.write().await;

    let storage = match SqliteStorage::new(&storage_path) {
        Ok(s) => Arc::new(RwLock::new(s)),
        Err(e) => return format!("Storage error: {}", e),
    };

    let ai = LocalAIClient::new(localai_url);

    let swarm = match P2PSwarm::new(
        Arc::new(peer_name.clone()),
        8000,
        None,
    ).await {
        Ok(s) => Arc::new(RwLock::new(s)),
        Err(e) => return format!("P2P error: {}", e),
    };

    core.swarm = Some(swarm);
    core.ai = Some(ai);
    core.storage = Some(storage);
    core.peer_name = peer_name.clone();
    core.is_initialized = true;

    format!("Liberty Reach initialized as {}", peer_name)
}

/// Get the local Peer ID
#[flutter_rust_bridge::frb]
pub async fn get_peer_id() -> String {
    let core = INSTANCE.read().await;
    match &core.swarm {
        Some(swarm) => swarm.read().await.local_peer_id().to_string(),
        None => "not initialized".to_string(),
    }
}

/// Get a list of connected peers
#[flutter_rust_bridge::frb]
pub async fn get_connected_peers() -> Vec<String> {
    let core = INSTANCE.read().await;
    match &core.swarm {
        Some(swarm) => {
            let peers = swarm.read().await.get_connected_peers();
            peers.iter().map(|p| p.to_string()).collect()
        }
        None => vec![],
    }
}

/// Send a chat message to the P2P network
#[flutter_rust_bridge::frb]
pub async fn send_message(content: String) -> String {
    let core = INSTANCE.read().await;
    if !core.is_initialized {
        return "not initialized".to_string();
    }

    let peer_name = core.peer_name.clone();
    let msg = serde_json::json!({
        "type": "chat",
        "sender": peer_name,
        "content": content,
        "timestamp": chrono::Utc::now().to_rfc3339(),
    });

    if let Some(swarm) = &core.swarm {
        let mut s = swarm.write().await;
        match s.publish_message(&msg.to_string()) {
            Ok(_) => {
                if let Some(storage) = &core.storage {
                    let _ = storage.write().await.save_message(&peer_name, &content, false);
                }
                content
            }
            Err(e) => format!("send error: {}", e),
        }
    } else {
        "swarm not available".to_string()
    }
}

/// Ask the AI (Gemma via LocalAI)
#[flutter_rust_bridge::frb]
pub async fn ask_ai(prompt: String) -> String {
    let core = INSTANCE.read().await;
    match &core.ai {
        Some(ai) => match ai.generate(&prompt).await {
            Ok(response) => {
                if let Some(storage) = &core.storage {
                    let _ = storage.write().await.save_message("AI", &response, true);
                }
                response
            }
            Err(e) => format!("AI error: {}", e),
        },
        None => "AI not initialized".to_string(),
    }
}

/// Connect to a peer by multiaddr
#[flutter_rust_bridge::frb]
pub async fn connect_to_peer(address: String) -> String {
    let core = INSTANCE.read().await;
    match &core.swarm {
        Some(swarm) => {
            let mut s = swarm.write().await;
            match s.dial(&address).await {
                Ok(_) => format!("connecting to {}", address),
                Err(e) => format!("connect error: {}", e),
            }
        }
        None => "not initialized".to_string(),
    }
}

/// Check if AI server is healthy
#[flutter_rust_bridge::frb]
pub async fn check_ai_health() -> bool {
    let core = INSTANCE.read().await;
    match &core.ai {
        Some(ai) => ai.health().await,
        None => false,
    }
}

/// Get recent messages from local storage
#[flutter_rust_bridge::frb]
pub async fn get_message_history(limit: i64) -> Vec<MessageEntry> {
    let core = INSTANCE.read().await;
    match &core.storage {
        Some(storage) => {
            let db = storage.read().await;
            match db.get_recent_messages(limit) {
                Ok(msgs) => msgs.into_iter().map(|m| MessageEntry {
                    id: m.id,
                    sender: m.sender,
                    content: m.content,
                    is_ai: m.is_ai,
                    timestamp: m.timestamp,
                }).collect(),
                Err(_) => vec![],
            }
        }
        None => vec![],
    }
}

/// Flutter-accessible message entry
#[flutter_rust_bridge::frb]
pub struct MessageEntry {
    pub id: i64,
    pub sender: String,
    pub content: String,
    pub is_ai: bool,
    pub timestamp: String,
}
