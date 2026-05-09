use libp2p::{
    core::upgrade,
    gossipsub, identity, kad,
    mdns, noise, swarm, tcp, quic, yamux,
    Multiaddr, PeerId,
};
use libp2p::gossipsub::MessageAuthenticity;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;

pub const CHAT_TOPIC: &str = "liberty/chat";

#[derive(swarm::NetworkBehaviour)]
pub struct P2PBehaviour {
    pub gossipsub: gossipsub::Behaviour,
    pub kademlia: kad::Behaviour<kad::store::MemoryStore>,
    pub mdns: mdns::tokio::Behaviour,
}

pub struct P2PSwarm {
    swarm: swarm::Swarm<P2PBehaviour>,
    local_peer_id: PeerId,
}

impl P2PSwarm {
    pub async fn new(
        identity_name: Arc<String>,
        port: u16,
        bootstrap: Option<&str>,
    ) -> anyhow::Result<Self> {
        let local_key = identity::Keypair::generate_ed25519();
        let local_peer_id = PeerId::from(local_key.public());

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
