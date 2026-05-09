mod p2p;
mod ai;
mod crypto;
mod storage;

use clap::Parser;
use std::sync::Arc;
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

#[tokio::main]
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

    let ai_client = ai::localai::LocalAIClient::new(
        "http://localhost:8080".to_string()
    );

    let p2p_clone = p2p_handle.clone();
    let storage_clone = storage.clone();
    let ai_clone = ai_client.clone();
    let identity_clone = identity.clone();

    let network_task = tokio::spawn(async move {
        p2p::swarm::run_swarm(
            p2p_clone,
            msg_rx,
            storage_clone,
            ai_clone,
            identity_clone,
        ).await;
    });

    println!("[Liberty Reach] Node {} running on port {}", identity, cli.port);
    println!("[Liberty Reach] AI endpoint: http://localhost:8080");
    println!("[Liberty Reach] Type messages below (/help for commands):");

    let stdin = tokio::io::BufReader::new(tokio::io::stdin());
    let mut lines = stdin.lines();

    while let Ok(Some(line)) = lines.next_line().await {
        let line = line.trim().to_string();
        if line.is_empty() { continue; }

        if line == "/exit" || line == "/quit" {
            break;
        }

        if line.starts_with("/") {
            handle_command(&line, &p2p_handle, &msg_tx, &storage, &ai_client, &identity).await;
        } else {
            let _ = msg_tx.send(p2p::swarm::AppEvent::SendMessage {
                content: line.clone(),
                peer_id: None,
            });
        }
    }

    network_task.abort();
    Ok(())
}

async fn handle_command(
    line: &str,
    p2p_handle: &Arc<RwLock<p2p::swarm::P2PSwarm>>,
    msg_tx: &flume::Sender<p2p::swarm::AppEvent>,
    storage: &Arc<RwLock<storage::sqlite::SqliteStorage>>,
    ai_client: &ai::localai::LocalAIClient,
    identity: &Arc<String>,
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
            println!("  /peers        - List connected peers");
            println!("  /connect <addr> - Connect to a peer");
            println!("  /id           - Show local peer ID");
            println!("  /history      - Show message history");
            println!("  /exit         - Exit");
            println!();
            println!("AI Commands:");
            println!("  @gemma <msg>  - Ask Gemma AI");
            println!("  @ai <msg>     - Ask Gemma AI (alias)");
        }
        "/history" => {
            let db = storage.read().await;
            let messages = db.get_recent_messages(50).unwrap_or_default();
            println!("Recent messages ({}):", messages.len());
            for msg in messages {
                println!("  [{}] {}: {}", msg.timestamp, msg.sender, msg.content);
            }
        }
        _ => {
            println!("Unknown command: {}", parts[0]);
        }
    }
}
