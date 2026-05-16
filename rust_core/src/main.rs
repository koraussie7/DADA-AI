mod p2p;
mod ai;
mod crypto;
mod storage;
mod blockchain;
mod reward;

use clap::Parser;
use std::sync::Arc;
use tokio::io::AsyncBufReadExt;
use tokio::sync::RwLock;

#[derive(Parser)]
#[command(name = "Liberty Reach")]
#[command(about = "AI-Powered P2P Messenger")]
struct Cli {
    #[arg(short, long, default_value = "liberty-reach-id")]
    identity: String,

    #[arg(short, long, default_value = "8000")]
    port: u16,

    #[arg(long)]
    bootstrap: Option<String>,

    #[arg(long, default_value = "sqlite")]
    storage: String,
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let cli = Cli::parse();
    let identity = Arc::new(cli.identity.clone());
    let db_path = format!("{}.db", identity);

    let storage = Arc::new(RwLock::new(
        storage::sqlite::SqliteStorage::new(&db_path)?
    ));

    let (msg_tx, msg_rx) = flume::unbounded();

    let swarm = p2p::swarm::P2PSwarm::new(
        identity.clone(),
        cli.port,
        cli.bootstrap.as_deref(),
    ).await?;

    let p2p_handle = Arc::new(RwLock::new(swarm));

    let ai_client = ai::localai::LocalAIClient::new();

    let minima_url = std::env::var("MINIMA_URL").unwrap_or_else(|_| "http://localhost:8080".to_string());
    let minima = blockchain::minima_service::MinimaService::new(&minima_url);
    let reward_service = Arc::new(reward::reward_service::RewardService::new(minima));

    let p2p_clone = p2p_handle.clone();
    let storage_clone = storage.clone();
    let ai_clone = ai_client.clone();
    let identity_clone = identity.clone();
    let reward_clone = reward_service.clone();

    let network = p2p::swarm::run_swarm(
        p2p_clone,
        msg_rx,
        storage_clone,
        ai_clone,
        identity_clone,
    );

    let stdin_loop = async {
        let stdin = tokio::io::BufReader::new(tokio::io::stdin());
        let mut lines = stdin.lines();

        while let Ok(Some(line)) = lines.next_line().await {
            let line = line.trim().to_string();
            if line.is_empty() { continue; }

            if line == "/exit" || line == "/quit" {
                let _ = msg_tx.send(p2p::swarm::AppEvent::Shutdown);
                break;
            }

            if line.starts_with("/") {
                handle_command(&line, &p2p_handle, &msg_tx, &storage, &ai_client, &identity, &reward_clone).await;
            } else {
                let _ = msg_tx.send(p2p::swarm::AppEvent::SendMessage {
                    content: line.clone(),
                    peer_id: None,
                });
            }
        }
    };

    println!("[Liberty Reach] Node {} running on port {}", identity, cli.port);
    println!("[Liberty Reach] AI endpoint: http://localhost:8080");
    println!("[Liberty Reach] Minima: {}", minima_url);
    println!("[Liberty Reach] Type messages below (/help for commands):");

    tokio::join!(network, stdin_loop);
    Ok(())
}

async fn handle_command(
    line: &str,
    p2p_handle: &Arc<RwLock<p2p::swarm::P2PSwarm>>,
    msg_tx: &flume::Sender<p2p::swarm::AppEvent>,
    storage: &Arc<RwLock<storage::sqlite::SqliteStorage>>,
    ai_client: &ai::localai::LocalAIClient,
    identity: &Arc<String>,
    reward_service: &Arc<reward::reward_service::RewardService>,
) {
    let parts: Vec<&str> = line.split_whitespace().collect();
    match parts[0] {
        "/peers" => {
            let swarm = p2p_handle.read().await;
            let peers = swarm.get_connected_peers();
            println!("Connected peers ({}):", peers.len());
            for (i, peer) in peers.iter().enumerate() {
                println!("  {}. {}", i + 1, peer);
            }
        }
        "/connect" => {
            if parts.len() < 2 {
                println!("Usage: /connect <multiaddr>");
                return;
            }
            let addr = parts[1..].join(" ");
            let mut swarm = p2p_handle.write().await;
            match swarm.dial(&addr).await {
                Ok(_) => println!("Connecting to {}...", addr),
                Err(e) => println!("Failed to connect: {}", e),
            }
        }
        "/id" => {
            let swarm = p2p_handle.read().await;
            println!("Peer ID: {}", swarm.local_peer_id());
        }
        "/help" => {
            println!("Commands:");
            println!("  /peers           - List connected peers");
            println!("  /connect <addr>  - Connect to a peer");
            println!("  /id              - Show local peer ID");
            println!("  /history         - Show message history");
            println!("  /exit            - Exit");
            println!();
            println!("AI Commands:");
            println!("  @gemma <msg>     - Ask Gemma AI");
            println!("  @ai <msg>        - Ask Gemma AI (alias)");
            println!();
            println!("Minima / Reward Commands:");
            println!("  /minima          - Show Minima node info");
            println!("  /balance         - Show DADA Point balance");
            println!("  /reward <addr> <secs> - Test reward (watch)");
        }
        "/history" => {
            let db = storage.read().await;
            let messages = db.get_recent_messages(50).unwrap_or_default();
            println!("Recent messages ({}):", messages.len());
            for msg in messages {
                println!("  [{}] {}: {}", msg.timestamp, msg.sender, msg.content);
            }
        }
        "/minima" => {
            if reward_service.health().await {
                match reward_service.get_minima_address().await {
                    Ok(addr) => println!("Minima address: {}", addr),
                    Err(e) => println!("Minima address error: {}", e),
                }
            } else {
                println!("Minima node not reachable at MINIMA_URL");
            }
        }
        "/balance" => {
            match reward_service.get_dada_balance().await {
                Ok(bal) => println!("DADA Point balance: {}", bal),
                Err(e) => println!("Balance error: {}", e),
            }
        }
        "/reward" => {
            if parts.len() < 3 {
                println!("Usage: /reward <user_address> <seconds>");
                return;
            }
            let user_addr = parts[1].to_string();
            let seconds: u32 = parts[2].parse().unwrap_or(15);
            match reward_service
                .issue_reward(
                    &user_addr,
                    &reward::reward_service::ActionType::WatchVideo,
                    seconds,
                    "cli-test",
                )
                .await
            {
                Ok(result) => println!(
                    "Reward: +{} DADA (tx: {})",
                    result.points_earned, result.tx_id
                ),
                Err(e) => println!("Reward error: {}", e),
            }
        }
        _ => {
            println!("Unknown command: {}", parts[0]);
        }
    }
}
