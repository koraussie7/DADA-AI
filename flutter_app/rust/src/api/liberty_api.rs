use crate::p2p::swarm::{P2PSwarm, ReceivedMessage, self as p2p_swarm};
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
    /// Channel to send outgoing P2P messages
    pub msg_tx: Option<flume::Sender<p2p_swarm::AppEvent>>,
    /// Channel to receive incoming P2P messages (from network)
    pub msg_rx: Option<flume::Receiver<ReceivedMessage>>,
}

impl LibertyCore {
    fn new() -> Self {
        Self {
            swarm: None,
            ai: None,
            storage: None,
            peer_name: String::new(),
            is_initialized: false,
            msg_tx: None,
            msg_rx: None,
        }
    }
}

/// Initialize the Liberty Reach core.
/// Must be called once before any other function.
/// Spawns the P2P event loop in the background.
#[flutter_rust_bridge::frb]
pub async fn init(peer_name: String, localai_url: String, storage_path: String) -> String {
    let mut core = INSTANCE.write().await;

    // Prevent double initialization
    if core.is_initialized {
        return format!("Already initialized as {}", core.peer_name);
    }

    let storage = match SqliteStorage::new(&storage_path) {
        Ok(s) => Arc::new(RwLock::new(s)),
        Err(e) => return format!("Storage error: {}", e),
    };

    let ai = LocalAIClient::new(localai_url);

    let identity = Arc::new(peer_name.clone());

    let swarm = match P2PSwarm::new(
        identity.clone(),
        8000,
        None,
        &storage_path,
    ).await {
        Ok(s) => Arc::new(RwLock::new(s)),
        Err(e) => return format!("P2P error: {}", e),
    };

    // Create channels for the event loop
    let (msg_tx, msg_rx) = flume::unbounded::<p2p_swarm::AppEvent>();
    let (incoming_tx, incoming_rx) = flume::unbounded::<ReceivedMessage>();

    // Spawn the P2P event loop in the background
    let event_loop_handle = swarm.clone();
    let event_loop_identity = identity.clone();
    tokio::spawn(async move {
        p2p_swarm::run_swarm(
            event_loop_handle,
            msg_rx,
            incoming_tx,
            event_loop_identity,
        ).await;
    });

    core.swarm = Some(swarm);
    core.ai = Some(ai);
    core.storage = Some(storage);
    core.peer_name = peer_name.clone();
    core.is_initialized = true;
    core.msg_tx = Some(msg_tx);
    core.msg_rx = Some(incoming_rx);

    format!("Liberty Reach initialized as {}", peer_name)
}

/// Get the next received P2P message, if any (non-blocking).
/// Flutter can poll this to check for new messages.
#[flutter_rust_bridge::frb]
pub async fn poll_incoming_message() -> Option<ReceivedMessage> {
    let core = INSTANCE.read().await;
    match &core.msg_rx {
        Some(rx) => rx.try_recv().ok(),
        None => None,
    }
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
/// Uses the channel to avoid lock contention with the event loop
#[flutter_rust_bridge::frb]
pub async fn send_message(content: String) -> String {
    let core = INSTANCE.read().await;
    if !core.is_initialized {
        return "not initialized".to_string();
    }

    // Send via channel (event loop handles the actual publish)
    if let Some(tx) = &core.msg_tx {
        let peer_name = core.peer_name.clone();
        match tx.send(p2p_swarm::AppEvent::SendMessage {
            content: content.clone(),
        }) {
            Ok(_) => {
                // Also save to local storage
                if let Some(storage) = &core.storage {
                    if let Err(e) = storage.write().await.save_message(&peer_name, &content, false) {
                        eprintln!("[Storage] Save error: {}", e);
                    }
                }
                content
            }
            Err(e) => format!("send error: {}", e),
        }
    } else {
        "swarm not available".to_string()
    }
}

/// Ask the AI with text (Gemma via LocalAI)
#[flutter_rust_bridge::frb]
pub async fn ask_ai(prompt: String) -> String {
    let core = INSTANCE.read().await;
    match &core.ai {
        Some(ai) => match ai.generate(&prompt).await {
            Ok(response) => {
                if let Some(storage) = &core.storage {
                    if let Err(e) = storage.write().await.save_message("AI", &response, true) {
                        eprintln!("[Storage] Save AI msg error: {}", e);
                    }
                }
                response
            }
            Err(e) => format!("AI error: {}", e),
        },
        None => "AI not initialized".to_string(),
    }
}

/// Ask the AI with text + images (LLaVA multimodal)
#[flutter_rust_bridge::frb]
pub async fn ask_ai_multimodal(prompt: String, images_base64: Vec<String>) -> String {
    let core = INSTANCE.read().await;
    match &core.ai {
        Some(ai) => match ai.generate_multimodal(&prompt, images_base64).await {
            Ok(response) => {
                if let Some(storage) = &core.storage {
                    if let Err(e) = storage.write().await.save_message("AI", &response, true) {
                        eprintln!("[Storage] Save multimodal error: {}", e);
                    }
                }
                response
            }
            Err(e) => format!("Multimodal AI error: {}", e),
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
