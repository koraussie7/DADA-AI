
**The Intelligent P2P AI Messenger**

![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Rust](https://img.shields.io/badge/Rust-000000?logo=rust&logoColor=white)
![Minima](https://img.shields.io/badge/Minima-Blockchain-00FFAA)

---

## 🌟 Vision

**Liberty Reach** is a fully decentralized AI-powered messenger that understands you — not just your words, but your emotions, memories, and preferences.

It combines **Multi-Agent AI**, **real-time voice conversation**, **emotional intelligence**, and **P2P video economy** into one seamless experience — all while protecting your privacy.

---

## ✨ Key Features

- **Multi-Agent Voice System** — Hermes (Empathy), OpenMythos (Deep Reasoning), OpenClaw (Action) work together
- **Real-time Emotional Intelligence** — Understands your mood and adjusts responses accordingly
- **Loops Video Ecosystem** — Watch, earn DADA Points, and get AI insights
- **Cheetah STT + Multi-language TTS** — Natural voice conversation with agent-specific voices
- **Glass Agent UI** — Beautiful, modern, and immersive interface
- **Minima Blockchain Rewards** — Contribute and get rewarded with DADA Point
- **Privacy First** — Everything runs on-device by default

---

## 🛠 Tech Stack

- **Frontend**: Flutter 3.24
- **Backend**: Rust + flutter_rust_bridge
- **AI Engine**: LocalAI + Gemma-2-2B + OpenMythos + TFLite
- **Speech**: Picovoice Cheetah (STT) + flutter_tts (Multi-language)
- **P2P**: libp2p + Gossipsub
- **Blockchain**: Minima (Tx-PoW + Coloring)
- **Storage**: Isar + AES-256 Encryption
- **Deployment**: Docker + Nginx

---

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/koraussie7/liberty-reach.git
cd liberty-reach

# Run Flutter App
cd flutter_app
flutter pub get
flutter run

# Build Rust Core (in another terminal)
cd ../rust_core
cargo build --release
Run with Docker:
Bashdocker-compose up -d

📁 Project Structure
textliberty-reach/
├── flutter_app/          # Flutter UI (Glass Agent, Voice, Loops)
├── rust_core/            # Rust Backend (Orchestrator, libp2p, Minima, Reward)
├── models/               # TFLite, Cheetah, LocalAI models
├── docker/               # Docker Compose & Nginx
├── scripts/              # Build & Deployment scripts
├── assets/               # Icons, models, fonts
├── docs/                 # Architecture, Tokenomics, Roadmap
└── README.md

🛣 Roadmap

v0.5 (Current) — Multi-Agent Voice + Glass UI + Minima Reward
v0.7 — Real-time Emotion Profiling + Preference Model
v1.0 — Full Loops + AI Integration + DADA Point DEX Preparation


📄 License
Apache License 2.0

Built for a decentralized and emotionally intelligent future.
Made with ❤️ by the Liberty Reach Team
**AI가 살아 숨쉬는 P2P 메신저 + 개인화된 영상 생태계**

![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Rust](https://img.shields.io/badge/Rust-000000?logo=rust&logoColor=white)
![Minima](https://img.shields.io/badge/Minima-Blockchain-00FFAA)

---

## 🚀 프로젝트 소개

**Liberty Reach**는 **완전 탈중앙화**된 AI 메신저입니다.

기존 메신저와 달리, **사용자의 감정·기억·취향**을 학습하는 AI 에이전트들이 함께 대화하며,  
P2P 네트워크와 Minima 블록체인을 통해 **중앙 서버 없이도** 안전하고 보상받는 경험을 제공합니다.

### 핵심 특징

- **Multi-Agent AI**: Hermes(공감), OpenMythos(깊은 사고), OpenClaw(실행) 등 에이전트 협업
- **실시간 음성 대화**: Cheetah STT + 다국어 TTS + 감정 분석
- **Loops 영상 생태계**: 시청 보상 + AI 분석
- **DADA Point**: 기여도 기반 보상 시스템 (Minima Tx-PoW)
- **완전 온디바이스 우선**: 프라이버시 보호 + 오프라인 지원
- **Glass Agent UI**: 미래감 있는 Glassmorphism 디자인

---

## 🛠 기술 스택

**Frontend**: Flutter 3.24  
**Backend**: Rust + flutter_rust_bridge  
**AI**: LocalAI + Gemma-2-2B + OpenMythos + TFLite Emotion Model  
**STT**: Picovoice Cheetah (기본) + speech_to_text (fallback)  
**TTS**: flutter_tts (다국어 + Agent별 목소리)  
**P2P**: libp2p + Gossipsub  
**Blockchain**: Minima (Coloring + Tx-PoW)  
**Storage**: Isar (온디바이스) + AES-256 암호화  
**Deployment**: Docker + Nginx

---

## 📸 주요 기능

- **음성 중심 대화** — 길게 누르고 말하기만 하면 AI가 답변
- **Multi-Agent Voice Circle** — 여러 AI 에이전트가 동시에/순차적으로 대화
- **실시간 감정 분석** — 사용자의 감정을 이해하고 응답 스타일 조정
- **Loops** — 영상 시청 보상 + AI 분석
- **DADA Point** — 기여할수록 보상받는 경제 시스템

---

## 🚀 빠른 시작

```bash
# 1. Repo 클론
git clone https://github.com/koraussie7/liberty-reach.git
cd liberty-reach

# 2. Flutter 앱 실행
cd flutter_app
flutter pub get
flutter run

# 3. Rust 백엔드 빌드 (별도 터미널)
cd ../rust_core
cargo build --release
Docker 전체 실행
Bashdocker-compose up -d

📁 프로젝트 구조
textliberty-reach/
├── flutter_app/              # Flutter UI (Glass Agent, Voice, Loops)
├── rust_core/                # Rust Orchestrator, libp2p, Minima, Reward
├── models/                   # TFLite, Cheetah, LocalAI 모델
├── docker/                   # docker-compose, nginx
├── scripts/                  # 배포, 빌드 스크립트
├── assets/                   # 아이콘, 모델 파일
├── docs/                     # 아키텍처, Tokenomics
└── README.md

🛣 Roadmap

v0.5 (현재): Multi-Agent Voice + Glass UI + Minima Reward
v0.7: 실시간 감정 프로필링 + Preference Model
v1.0: Loops + AI 완전 연동 + DADA Point DEX 상장 준비


🤝 Contributing

Fork & Branch 생성
변경사항 commit
Pull Request

모든 기여를 환영합니다!
