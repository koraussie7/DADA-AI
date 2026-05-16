# JiwuChat (Tauri2 + Vue3/Nuxt3) Migration Plan

## Overview
Migrate from Flutter to Tauri2 + Vue3/Nuxt3 frontend, keeping Liberty Reach Rust core via Tauri plugin.

## Architecture
```
JiwuChat (Vue3 + Tauri2)
  ├── src-tauri/          # Rust layer (Tauri plugin)
  │   ├── Cargo.toml      # libp2p, serde, reqwest, tauri deps
  │   ├── src/commands.rs # Tauri commands (commerce, p2p, wallet)
  │   └── src/lib.rs      # Plugin registration
  ├── src/                # Vue3/Nuxt3 frontend
  │   ├── pages/          # Chat, Loops, Reward, Commerce, Settings
  │   ├── components/     # Glass UI, Video Player, Commerce Cards
  │   └── composables/    # useP2P, useCommerce, useWallet
  └── nuxt.config.ts
```

## Migration Phases

### Phase 1: Scaffold Tauri2 + Nuxt3 (1 session)
```bash
npm create tauri-app@latest jiwuchat -- --template vue-ts
cd jiwuchat
npx nuxi init src/
```
- Copy Liberty Reach Rust core into `src-tauri/src/`
- Register P2P swarm, commerce, blockchain modules
- Create Tauri plugin bridge

### Phase 2: Port Design System (1 session)
- Convert `flutter_app/lib/core/design_system/` → Tailwind CSS config
- Dark violet tokens: 
  ```css
  :root {
    --primary: #7C3AED;
    --surface: #0D0D1A;
    --glass: rgba(30, 30, 58, 0.8);
  }
  ```
- Glass morphism: `backdrop-filter: blur(12px)` utility classes
- Recreate `GlassContainer` as Vue component

### Phase 3: Port Screens (2-3 sessions)
1. **Reward Dashboard** → `pages/reward.vue`
   - Gradient point card, Live Commerce hero, trending commerce feed
   - Mission grid (2x2), P2P status indicator
   - Use `useCommerce()` composable for Hermes agent calls
2. **Chat** → `pages/chat.vue`
   - Reuse existing UI patterns
   - AI bubble with glass morphism
3. **Loops** → `pages/loops.vue`
   - Video player with Video.js
   - Loops preview bar, upload flow
4. **Commerce** → `pages/commerce.vue`
   - Live streaming UI with WebRTC
   - Product tagging overlay
   - Purchase flow → Minima transaction

### Phase 4: Rust Tauri Commands (1 session)
```rust
// src-tauri/src/commands.rs
#[tauri::command]
async fn start_p2p_commerce(video_id: String, products: Vec<Product>) -> Result<String, String> {
    // 1. OpenMythos/LocalAI product analysis
    // 2. Hermes agent recommendation
    // 3. Gossipsub broadcast on "liberty/commerce" topic
}

#[tauri::command]
async fn connect_wallet() -> Result<WalletInfo, String> {
    // Minima wallet connection via Tauri
}

#[tauri::command]
async fn purchase_product(product_id: String, price: u64) -> Result<String, String> {
    // Minima DADA Point send transaction
}
```

### Phase 5: WebRTC + P2P Streaming (1 session)
- Integrate `simple-peer` or `mediasoup-client` in Vue
- WebRTC offer/answer exchanged via libp2p gossipsub
- Circuit relay for NAT traversal
- `Video.js` player with HLS/DASH fallback

### Phase 6: Deploy (1 session)
```bash
# Build Tauri app
cd jiwuchat
npm run build
# Binary output: src-tauri/target/release/jiwuchat.exe

# Or build web version
npm run generate
# Deploy to /var/www/html/
```

## Key Differences from Flutter
| Feature | Flutter | Tauri+Vue3 |
|---------|---------|------------|
| UI rendering | Skia canvas | System webview |
| Bundle size | ~15MB APK | ~5MB binary |
| Rust integration | flutter_rust_bridge | Direct Tauri plugin |
| Video streaming | video_player + chewie | Video.js + WebRTC |
| State management | Provider | Pinia |
| Routing | Navigator 2.0 | Vue Router |

## Recommended Order
1. Phase 1 → 2 → 4 → 3 → 5 → 6
2. Start with Reward Dashboard and Commerce (highest user impact)
3. Keep Flutter app running in parallel until Tauri parity achieved
