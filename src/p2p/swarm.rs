use libp2p::{
    gossipsub, identity, kad,
    mdns, noise, swarm, tcp, yamux,
    Multiaddr, PeerId, Transport, SwarmBuilder,
};
use libp2p::gossipsub::MessageAuthenticity;
use libp2p::swarm::{NetworkBehaviour, SwarmEvent};
use futures::StreamExt;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;

use crate::ai::localai::LocalAIClient;
use crate::storage::sqlite::SqliteStorage;

pub const CHAT_TOPIC: &str = "liberty/chat";
pub const KEY_DIR: &str = ".liberty/keys";

/// Load or generate a persistent Ed25519 keypair.
/// Stores the key as a hex-encoded 32-byte secret in a file
/// derived from `identity_name`, so the Peer ID survives restarts.
fn load_or_create_keypair(identity_name: &str) -> anyhow::Result<identity::Keypair> {
    let key_path = get_key_path(identity_name);
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

    // Generate new key
    let keypair = identity::Keypair::generate_ed25519();
    let secret = keypair.secret();
    let secret_bytes = secret.as_ref();
    if secret_bytes.len() == 32 {
        let _ = std::fs::write(&key_path, secret_bytes);
        println!("[P2P] Generated new identity key at {:?}", key_path);
    }
    Ok(keypair)
}

fn get_key_path(identity_name: &str) -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    // Sanitize identity name for filesystem use
    let safe_name: String = identity_name.chars()
        .map(|c| if c.is_alphanumeric() || c == '-' || c == '_' { c } else { '_' })
        .collect();
    PathBuf::from(&home).join(KEY_DIR).join(format!("{}.key", safe_name))
}

pub enum AppEvent {
    SendMessage {
        content: String,
        peer_id: Option<PeerId>,
    },
    Shutdown,
}

pub struct ChatMessage {
    pub id: String,
    pub sender: String,
    pub content: String,
    pub is_ai: bool,
    pub timestamp: String,
}

pub struct P2PSwarm {
    swarm: swarm::Swarm<P2PBehaviour>,
    local_peer_id: PeerId,
}

#[derive(NetworkBehaviour)]
pub struct P2PBehaviour {
    pub gossipsub: gossipsub::Behaviour,
    pub kademlia: kad::Behaviour<kad::store::MemoryStore>,
    pub mdns: mdns::tokio::Behaviour,
}

impl P2PSwarm {
    pub async fn new(
        identity_name: Arc<String>,
        port: u16,
        bootstrap: Option<&str>,
    ) -> anyhow::Result<Self> {
        let local_key = load_or_create_keypair(&identity_name)?;
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
        ).map_err(|e| anyhow::anyhow!("Gossipsub: {}", e))?;

        let kademlia_store = kad::store::MemoryStore::new(local_peer_id);
        let kademlia_behaviour = kad::Behaviour::new(
            local_peer_id,
            kademlia_store,
        );

        let mdns_behaviour = mdns::tokio::Behaviour::new(
            mdns::Config::default(),
            local_peer_id,
        )?;

        let behaviour = P2PBehaviour {
            gossipsub: gossipsub_behaviour,
            kademlia: kademlia_behaviour,
            mdns: mdns_behaviour,
        };

        let mut swarm = SwarmBuilder::with_existing_identity(local_key)
            .with_tokio()
            .with_other_transport(|key| {
                let noise_config = noise::Config::new(key)?;
                let yamux_config = yamux::Config::default();
                Ok(tcp::tokio::Transport::default()
                    .upgrade(libp2p::core::upgrade::Version::V1)
                    .authenticate(noise_config)
                    .multiplex(yamux_config)
                    .boxed())
            })?
            .with_behaviour(|_| behaviour)?
            .build();

        swarm.listen_on(format!("/ip4/0.0.0.0/tcp/{}", port).parse()?)?;

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
}

pub async fn run_swarm(
    p2p_handle: Arc<RwLock<P2PSwarm>>,
    msg_rx: flume::Receiver<AppEvent>,
    storage: Arc<RwLock<SqliteStorage>>,
    ai_client: LocalAIClient,
    identity: Arc<String>,
) {
    loop {
        tokio::select! {
            event = async {
                let mut guard = p2p_handle.write().await;
                guard.swarm.next().await
            } => {
                if let Some(swarm_event) = event {
                    handle_swarm_event(
                        swarm_event,
                        &p2p_handle,
                        &storage,
                        &ai_client,
                        &identity,
                    ).await;
                }
            }
            app_event = msg_rx.recv_async() => {
                match app_event {
                    Ok(AppEvent::SendMessage { content, peer_id: _ }) => {
                        let msg = serde_json::json!({
                            "type": "chat",
                            "sender": *identity,
                            "content": content,
                            "timestamp": chrono::Utc::now().to_rfc3339(),
                        });

                        {
                            let mut swarm = p2p_handle.write().await;
                            if let Err(e) = swarm.publish_message(&msg.to_string()) {
                                eprintln!("[P2P] Failed to publish message: {}", e);
                            }
                        }

                        if let Err(e) = storage.write().await.save_message(
                            &identity,
                            &content,
                            false,
                        ) {
                            eprintln!("[Storage] Failed to save message: {}", e);
                        }
                    }
                    Ok(AppEvent::Shutdown) | Err(_) => break,
                }
            }
        }
    }
}

async fn handle_swarm_event(
    event: SwarmEvent<<P2PBehaviour as NetworkBehaviour>::ToSwarm>,
    p2p_handle: &Arc<RwLock<P2PSwarm>>,
    storage: &Arc<RwLock<SqliteStorage>>,
    ai_client: &LocalAIClient,
    identity: &Arc<String>,
) {
    match event {
        SwarmEvent::NewListenAddr { address, .. } => {
            println!("Listening on {}", address);
        }
        SwarmEvent::Behaviour(P2PBehaviourEvent::Gossipsub(gossipsub::Event::Message {
            propagation_source: _,
            message_id: _,
            message,
        })) => {
            let msg_str = String::from_utf8_lossy(&message.data).to_string();
            if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&msg_str) {
                let sender = parsed["sender"].as_str().unwrap_or("unknown");
                let content = parsed["content"].as_str().unwrap_or("");
                let timestamp = parsed["timestamp"].as_str().unwrap_or("");

                if sender == identity.as_str() {
                    return;
                }

                let is_ai_command =
                    content.starts_with("@gemma ") || content.starts_with("@ai ");

                if let Err(e) = storage.write().await.save_message(sender, content, is_ai_command) {
                    eprintln!("[Storage] Failed to save incoming message: {}", e);
                }

                if is_ai_command {
                    let prompt = content
                        .strip_prefix("@gemma ")
                        .or_else(|| content.strip_prefix("@ai "))
                        .unwrap_or(content);

                    println!("[AI] {} asks: {}", sender, prompt);

                    match ai_client.generate(prompt).await {
                        Ok(response) => {
                            let reply = serde_json::json!({
                                "type": "chat",
                                "sender": format!("AI[{}]", identity),
                                "content": response,
                                "timestamp": chrono::Utc::now().to_rfc3339(),
                            });

                            if let Err(e) = storage.write().await.save_message(
                                &format!("AI[{}]", identity),
                                &response,
                                true,
                            ) {
                                eprintln!("[Storage] Failed to save AI response: {}", e);
                            }

                            let mut swarm = p2p_handle.write().await;
                            if let Err(e) = swarm.publish_message(&reply.to_string()) {
                                eprintln!("[P2P] Failed to publish AI reply: {}", e);
                            }
                        }
                        Err(e) => {
                            eprintln!("[AI Error] {}", e);
                        }
                    }
                } else {
                    let from_peer = if sender == identity.as_str() {
                        "Me"
                    } else {
                        sender
                    };
                    println!("[{}] {}: {}", timestamp, from_peer, content);
                }
            }
        }
        SwarmEvent::Behaviour(P2PBehaviourEvent::Mdns(mdns::Event::Discovered(list))) => {
            for (peer_id, _addr) in list {
                let mut swarm = p2p_handle.write().await;
                let topic = gossipsub::IdentTopic::new(CHAT_TOPIC);
                let _ = swarm.swarm.behaviour_mut().gossipsub.subscribe(&topic);
                println!("Discovered peer: {}", peer_id);
            }
        }
        SwarmEvent::Behaviour(P2PBehaviourEvent::Mdns(mdns::Event::Expired(list))) => {
            for (peer_id, _addr) in list {
                println!("Peer expired: {}", peer_id);
            }
        }
        _ => {}
    }
}
