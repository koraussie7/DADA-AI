# Liberty Reach - flutter_rust_bridge Setup Script (Windows)
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  Liberty Reach FRB Setup" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

# Step 1: Check prerequisites
Write-Host "[Step 1] Checking prerequisites..." -ForegroundColor Cyan
$hasRust = $null -ne (Get-Command rustc -ErrorAction SilentlyContinue)
$hasFlutter = $null -ne (Get-Command flutter -ErrorAction SilentlyContinue)

if (-not $hasRust) { Write-Host "  [MISS] Install Rust: https://rustup.rs" -ForegroundColor Red; exit 1 }
else { Write-Host "  [OK] Rust found" -ForegroundColor Green }

if (-not $hasFlutter) { Write-Host "  [MISS] Install Flutter: https://flutter.dev" -ForegroundColor Red; exit 1 }
else { Write-Host "  [OK] Flutter found" -ForegroundColor Green }

Write-Host ""

# Step 2: Install flutter_rust_bridge_codegen
Write-Host "[Step 2] Installing flutter_rust_bridge_codegen..." -ForegroundColor Cyan
cargo install flutter_rust_bridge_codegen
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] flutter_rust_bridge_codegen installed" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Installation failed" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Generate Dart bindings
Write-Host "[Step 3] Generating Dart bindings..." -ForegroundColor Cyan
flutter_rust_bridge_codegen generate
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Dart bindings generated in lib/src/rust/" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Codegen failed" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 4: Get Flutter dependencies
Write-Host "[Step 4] Getting Flutter dependencies..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Flutter dependencies installed" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] flutter pub get failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  Setup complete! Run: flutter run" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "The app now calls Rust backend for:"
Write-Host "  - P2P networking (libp2p + Gossipsub)"
Write-Host "  - AI inference (LocalAI + Gemma)"
Write-Host "  - Message storage (SQLite)"
Write-Host "  - E2EE (Noise Protocol)"
Write-Host ""
Write-Host "Required: Start LocalAI first:"
Write-Host "  docker run -p 8080:8080 localai/localai:latest"
