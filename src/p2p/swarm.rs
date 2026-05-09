use libp2p::{
    core::upgrade,
    gossipsub, identity, kad,
    mdns, noise, swarm, tcp, quic, yamux,
    Multiaddr, PeerId, StreamProtocol, Transport,
};
use libp2p::gossipsub::MessageAuthenticity;
use libp2p::swarm::SwarmEvent;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;

use crate::ai::localai::LocalAIClient;
use crate::storage::sqlite::SqliteStorage;

pub const CHAT_TOPIC: &str = "liberty/chat";

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

#[derive(swarm::NetworkBehaviour)]
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
        let local_key = identity::Keypair::generate_ed25519();
        let local_peer_id = PeerId::from(local_key.public());

        let noise_config = noise::Config::new(&local_key)?;
        let yamux_config = yamux::Config::default();

        let tcp_transport = tcp::tokio::Transport::default()
            .upgrade(upgrade::Version::V1)
            .authenticate(noise_config)
            .multiplex(yamux_config)
            .boxed();

        let quic_transport = quic::tokio::Transport::new(quic::Config::new(&local_key)?)
            .boxed();

        let transport = tcp_transport.or(quic_transport).boxed();

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
            event = p2p_handle.write().await.swarm.next() => {
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
                            let _ = swarm.publish_message(&msg.to_string());
                        }

                        let _ = storage.write().await.save_message(
                            &identity,
                            &content,
                            false,
                        );
                    }
                    Ok(AppEvent::Shutdown) | Err(_) => break,
                }
            }
        }
    }
}

async fn handle_swarm_event(
    event: SwarmEvent<P2PBehaviourEvent>,
    p2p_handle: &Arc<RwLock<P2PSwarm>>,
    storage: &Arc<RwLock<SqliteStorage>>,
    ai_client: &LocalAIClient,
    identity: &Arc<String>,
) {
    match event {
        SwarmEvent::NewListenAddr { address, .. } => {
            println!("Listening on {}", address);
        }
        SwarmEvent::Behaviour(P2PBehaviourEvent::Gossipsub(
            gossipsub::Event::Message {
                propagation_source: _,
                message_id: _,
                message,
            },
        )) => {
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

                let _ = storage.write().await.save_message(sender, content, is_ai_command);

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

                            let _ = storage.write().await.save_message(
                                &format!("AI[{}]", identity),
                                &response,
                                true,
                            );

                            let mut swarm = p2p_handle.write().await;
                            let _ = swarm.publish_message(&reply.to_string());
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
        SwarmEvent::Behaviour(P2PBehaviourEvent::Mdns(
            mdns::Event::Discovered(list),
        )) => {
            for (peer_id, _addr) in list {
                let mut swarm = p2p_handle.write().await;
                let topic = gossipsub::IdentTopic::new(CHAT_TOPIC);
                let _ = swarm.swarm.behaviour_mut().gossipsub.subscribe(&topic);
                println!("Discovered peer: {}", peer_id);
            }
        }
        SwarmEvent::Behaviour(P2PBehaviourEvent::Mdns(
            mdns::Event::Expired(list),
        )) => {
            for (peer_id, _addr) in list {
                println!("Peer expired: {}", peer_id);
            }
        }
        _ => {}
    }
}

#[allow(unused_imports)]
use libp2p::swarm::derive::NetworkBehaviour;
