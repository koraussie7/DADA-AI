use futures::StreamExt;
use libp2p::{
    core::upgrade,
    gossipsub, identity, kad,
    mdns, noise, swarm, tcp, quic, yamux,
    Multiaddr, PeerId,
};
use libp2p::gossipsub::MessageAuthenticity;
use libp2p::swarm::{NetworkBehaviour, SwarmEvent};
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;

pub const CHAT_TOPIC: &str = "liberty/chat";
pub const KEY_DIR: &str = ".liberty/keys";

/// Load or generate a persistent Ed25519 keypair.
/// Stores the key as raw 32-byte secret in a file so Peer ID survives restarts.
fn load_or_create_keypair(identity_name: &str, storage_path: &str) -> anyhow::Result<identity::Keypair> {
    let key_path = get_key_path(identity_name, storage_path);
    if let Some(parent) = key_path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    // Try to load existing key
    if key_path.exists() {
        let bytes = std::fs::read(&key_path)?;
        if bytes.len() == 32 {
            let mut arr = [0u8; 32];
            arr.copy_from_slice(&bytes);
            return Ok(identity::Keypair::ed25519_from_bytes(arr)
                .map_err(|e| anyhow::anyhow!("Invalid saved key: {}", e))?);
        }
    }

    // Generate new key and save it
    let keypair = identity::Keypair::generate_ed25519();
    let secret_bytes = keypair.secret().as_ref();
    if secret_bytes.len() == 32 {
        if let Err(e) = std::fs::write(&key_path, secret_bytes) {
            eprintln!("[P2P] Failed to save identity key to {:?}: {}", key_path, e);
        } else {
            println!("[P2P] Generated new identity key at {:?}", key_path);
        }
    }
    Ok(keypair)
}

fn get_key_path(identity_name: &str, _storage_path: &str) -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    let safe_name: String = identity_name.chars()
        .map(|c| if c.is_alphanumeric() || c == '-' || c == '_' { c } else { '_' })
        .collect();
    PathBuf::from(home).join(KEY_DIR).join(format!("{}.key", safe_name))
}

/// Events that the application layer can send to the swarm
pub enum AppEvent {
    SendMessage {
        content: String,
    },
    Shutdown,
}

/// Represents a received P2P message (sent to Flutter via channel)
#[derive(Debug, Clone)]
pub struct ReceivedMessage {
    pub sender: String,
    pub content: String,
    pub timestamp: String,
    pub is_ai_command: bool,
}

#[derive(swarm::NetworkBehaviour)]
pub struct P2PBehaviour {
    pub gossipsub: gossipsub::Behaviour,
    pub kademlia: kad::Behaviour<kad::store::MemoryStore>,
    pub mdns: mdns::tokio::Behaviour,
}

pub struct P2PSwarm {
    pub(crate) swarm: swarm::Swarm<P2PBehaviour>,
    local_peer_id: PeerId,
}

impl P2PSwarm {
    pub async fn new(
        identity_name: Arc<String>,
        port: u16,
        bootstrap: Option<&str>,
        storage_path: &str,
    ) -> anyhow::Result<Self> {
        let local_key = load_or_create_keypair(&identity_name, storage_path)?;
        let local_peer_id = PeerId::from(local_key.public());
        println!("[P2P] Peer ID: {} (identity: {})", local_peer_id, identity_name);

        let gossipsub_config = gossipsub::ConfigBuilder::default()
            .heartbeat_interval(Duration::from_secs(1))
            .validation_mode(gossipsub::ValidationMode::Permissive)
            .message_id_fn(|message: &gossipsub::Message| {
                let mut hasher = blake3::Hasher::new();
                hasher.update(&message.data);
                gossipsub::MessageId::new(&hasher.finalize().as_bytes()[..20])
            })
            .build()
            .map_err(|e| anyhow::anyhow!("Gossipsub config: {}", e))?;

        let gossipsub_behaviour = gossipsub::Behaviour::new(
            MessageAuthenticity::Signed(local_key.clone()),
            gossipsub_config,
        )?;

        let kademlia_store = kad::store::MemoryStore::new(local_peer_id);
        let kademlia_behaviour = kad::Behaviour::new(local_peer_id, kademlia_store);

        let mdns_behaviour = mdns::tokio::Behaviour::new(
            mdns::Config::default(),
            local_peer_id,
        )?;

        let behaviour = P2PBehaviour {
            gossipsub: gossipsub_behaviour,
            kademlia: kademlia_behaviour,
            mdns: mdns_behaviour,
        };

        let mut swarm = swarm::SwarmBuilder::with_existing_identity(local_key)
            .with_tokio()
            .with_other_transport(|key| {
                let noise_config = noise::Config::new(key)?;
                let yamux_config = yamux::Config::default();
                Ok(tcp::tokio::Transport::default()
                    .upgrade(upgrade::Version::V1)
                    .authenticate(noise_config)
                    .multiplex(yamux_config)
                    .boxed())
            })?
            .with_behaviour(|_| behaviour)?
            .build();

        swarm.listen_on(format!("/ip4/0.0.0.0/tcp/{}", port).parse()?)?;
        swarm.listen_on(format!("/ip4/0.0.0.0/udp/{}/quic-v1", port).parse()?)?;

        let chat_topic = gossipsub::IdentTopic::new(CHAT_TOPIC);
        swarm.behaviour_mut().gossipsub.subscribe(&chat_topic)?;

        if let Some(bootstrap_addr) = bootstrap {
            let addr: Multiaddr = bootstrap_addr.parse()?;
            swarm.dial(addr)?;
        }

        Ok(Self { swarm, local_peer_id })
    }

    pub fn local_peer_id(&self) -> PeerId {
        self.local_peer_id
    }

    pub fn get_connected_peers(&self) -> Vec<PeerId> {
        self.swarm.connected_peers().cloned().collect()
    }

    pub fn publish_message(&mut self, message: &str) -> anyhow::Result<()> {
        let topic = gossipsub::IdentTopic::new(CHAT_TOPIC);
        self.swarm.behaviour_mut().gossipsub.publish(
            topic,
            message.as_bytes(),
        )?;
        Ok(())
    }

    pub async fn dial(&mut self, addr: &str) -> anyhow::Result<()> {
        let multiaddr: Multiaddr = addr.parse()?;
        self.swarm.dial(multiaddr)?;
        Ok(())
    }

    pub fn swarm(&mut self) -> &mut swarm::Swarm<P2PBehaviour> {
        &mut self.swarm
    }
}

/// Runs the P2P event loop in the background.
/// Processes incoming swarm events (messages, peer discovery)
/// and outgoing messages from the application.
///
/// Call this with `tokio::spawn` after creating the swarm.
pub async fn run_swarm(
    p2p_handle: Arc<RwLock<P2PSwarm>>,
    msg_rx: flume::Receiver<AppEvent>,
    msg_tx: flume::Sender<ReceivedMessage>,
    identity: Arc<String>,
) {
    println!("[P2P] Event loop started");

    loop {
        tokio::select! {
            // Process incoming swarm events (messages from network)
            event = async {
                let mut guard = p2p_handle.write().await;
                guard.swarm.next().await
            } => {
                if let Some(swarm_event) = event {
                    handle_swarm_event(swarm_event, &p2p_handle, &msg_tx, &identity).await;
                }
            }
            // Process outgoing messages from the application
            app_event = msg_rx.recv_async() => {
                match app_event {
                    Ok(AppEvent::SendMessage { content }) => {
                        let msg = serde_json::json!({
                            "type": "chat",
                            "sender": *identity,
                            "content": content,
                            "timestamp": chrono::Utc::now().to_rfc3339(),
                        });
                        let mut swarm = p2p_handle.write().await;
                        if let Err(e) = swarm.publish_message(&msg.to_string()) {
                            eprintln!("[P2P] Publish error: {}", e);
                        }
                    }
                    Ok(AppEvent::Shutdown) | Err(_) => {
                        println!("[P2P] Event loop shutting down");
                        break;
                    }
                }
            }
        }
    }
}

async fn handle_swarm_event(
    event: SwarmEvent<<P2PBehaviour as NetworkBehaviour>::ToSwarm>,
    p2p_handle: &Arc<RwLock<P2PSwarm>>,
    msg_tx: &flume::Sender<ReceivedMessage>,
    identity: &Arc<String>,
) {
    match event {
        SwarmEvent::NewListenAddr { address, .. } => {
            println!("[P2P] Listening on {}", address);
        }
        SwarmEvent::Behaviour(P2PBehaviourEvent::Gossipsub(gossipsub::Event::Message {
            propagation_source: _,
            message_id: _,
            message,
        })) => {
            let msg_str = String::from_utf8_lossy(&message.data).to_string();
            if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&msg_str) {
                let sender = parsed["sender"].as_str().unwrap_or("unknown").to_string();
                let content = parsed["content"].as_str().unwrap_or("").to_string();
                let timestamp = parsed["timestamp"].as_str().unwrap_or("").to_string();

                // Skip own messages
                if sender == identity.as_str() {
                    return;
                }

                let is_ai_command =
                    content.starts_with("@gemma ") || content.starts_with("@ai ");

                println!("[P2P] Msg from {}: {}", sender, if content.len() > 50 { format!("{}...", &content[..50]) } else { content.clone() });

                // Forward to Flutter via channel
                if let Err(e) = msg_tx.send(ReceivedMessage {
                    sender,
                    content,
                    timestamp,
                    is_ai_command,
                }) {
                    eprintln!("[P2P] Failed to forward incoming message to Flutter: {}", e);
                }
            }
        }
        SwarmEvent::Behaviour(P2PBehaviourEvent::Mdns(mdns::Event::Discovered(list))) => {
            for (peer_id, _addr) in list {
                println!("[P2P] mDNS discovered: {}", peer_id);
                // Re-subscribe to topic for newly discovered peers
                let mut swarm = p2p_handle.write().await;
                let topic = gossipsub::IdentTopic::new(CHAT_TOPIC);
                if let Err(e) = swarm.swarm.behaviour_mut().gossipsub.subscribe(&topic) {
                    eprintln!("[P2P] Failed to re-subscribe topic after mDNS discovery: {}", e);
                }
            }
        }
        SwarmEvent::Behaviour(P2PBehaviourEvent::Mdns(mdns::Event::Expired(list))) => {
            for (peer_id, _addr) in list {
                println!("[P2P] mDNS expired: {}", peer_id);
            }
        }
        SwarmEvent::Behaviour(P2PBehaviourEvent::Kademlia(kad_event)) => {
            // Log Kademlia events at debug level
            match kad_event {
                kad::Event::RoutingUpdated { peer, .. } => {
                    tracing::debug!("Kademlia routing updated: {}", peer);
                }
                _ => {}
            }
        }
        _ => {}
    }
}
