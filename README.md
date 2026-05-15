# DADA-AI

**AI-Powered P2P Messenger · Decentralized Live Commerce Platform**

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Rust](https://img.shields.io/badge/Rust-000000?logo=rust&logoColor=white)](https://www.rust-lang.org)
[![Minima](https://img.shields.io/badge/Minima-Blockchain-00FFAA)](https://minima.com)

---

**DADA-AI** is a next-generation intelligent messenger and decentralized live commerce platform built on the **Liberty Reach P2P network**.

Unlike traditional messengers, it features a **Multi-Agent AI** system that learns your emotions, memories, and preferences — all while keeping your data private through peer-to-peer architecture and Minima blockchain.

## ✨ Key Features

- **Multi-Agent AI** — Hermes (Empathy), OpenMythos (Deep Reasoning), OpenClaw (Action) collaborate in real-time
- **P2P Messaging** — Fully decentralized chat powered by libp2p
- **📸 Snap & Sell** — Take a photo, AI analyzes it, and it's instantly listed on the P2P Market with location-based propagation
- **🎬 Loops** — Record videos, AI auto-edits, and P2P distributes to nearby peers
- **🎙️ Voice AI** — Cheetah STT + multi-language TTS with emotion-aware responses
- **💰 DADA Points** — Minima blockchain-based contribution rewards
- **🛡️ Privacy First** — On-device by default, zero central server dependency
- **✨ Glass Agent UI** — Immersive glassmorphism design

## 🛠 Tech Stack

| Area       | Technology                             |
|------------|----------------------------------------|
| Frontend   | Flutter 3.24 (Mobile + Web WASM)       |
| Backend    | FastAPI + Python                       |
| Core       | Rust (libp2p, Crypto, AI)              |
| AI Engine  | Gemini + Ollama (Local)                |
| Orchestration | Hermes Agent + OpenClaw            |
| P2P        | Liberty Reach (libp2p + Gossipsub)    |
| Blockchain | Minima (Tx-PoW + Coloring)            |
| Web Server | Caddy                                  |
| CDN        | Cloudflare                              |
| Deployment | Docker                                  |

## 🚀 Quick Start

```bash
# Clone
git clone https://github.com/koraussie7/DADA-AI.git
cd DADA-AI

# API Server
cd server
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Flutter App (Mobile)
cd ../flutter_app
flutter pub get
flutter run

# Flutter Web (WASM)
flutter build web --wasm
```

Or with Docker:
```bash
docker-compose up -d
```

## 📁 Project Structure

```
DADA-AI/
├── flutter_app/      # Flutter UI (Mobile + Web)
├── rust_core/        # Rust Core (P2P, Crypto, AI)
├── server/           # FastAPI + Agent API
├── puter-apps/       # Puter WebOS apps
├── docs/             # Architecture, Roadmap
└── docker/           # Docker configuration
```

## 🗺 Roadmap

- [x] Flutter Web WASM + Caddy deployment
- [x] Multi-Agent Orchestrator (Hermes + OpenClaw)
- [x] AI-powered product analysis (Market)
- [ ] Location-based P2P propagation
- [ ] Puter WebOS integration
- [ ] Golem + Hyperspace distributed computing
- [ ] DADA Coin economic model
- [ ] Real-time voice/video calls

## 🤝 Contributing

Pull requests are welcome! Feel free to contribute or collaborate with our agents.

## 📄 License

Apache License 2.0

---

*Decentralized. Intelligent. Yours.*  
**Made with ❤️ by the DADA-AI Team**
