# Liberty Reach - Phase 0 Setup Script (Windows)
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  Liberty Reach - Phase 0 Setup" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

# Check prerequisites
$prereqs = @(
    @{Name="Rust"; Cmd="rustc --version"},
    @{Name="Flutter"; Cmd="flutter --version"},
    @{Name="Docker"; Cmd="docker --version"},
    @{Name="Docker Compose"; Cmd="docker compose version"}
)

foreach ($prereq in $prereqs) {
    $result = Invoke-Expression $prereq.Cmd 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] $($prereq.Name) found" -ForegroundColor Green
    } else {
        Write-Host "  [MISS] $($prereq.Name) not found - please install" -ForegroundColor Red
    }
}

Write-Host ""

# Step 1: Download Gemma-2-2B model
Write-Host "[Step 1] Downloading Gemma-2-2B model..." -ForegroundColor Cyan
$modelDir = "localai/models"
if (-not (Test-Path $modelDir)) {
    New-Item -ItemType Directory -Path $modelDir -Force
}

$modelUrl = "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf"
$modelPath = Join-Path $modelDir "gemma-2-2b-it-Q4_K_M.gguf"

if (-not (Test-Path $modelPath)) {
    Write-Host "  Downloading Gemma-2-2B (Q4_K_M) GGUF model..."
    Write-Host "  (This may take a while - ~1.5GB)"
    Invoke-WebRequest -Uri $modelUrl -OutFile $modelPath -UseBasicParsing
    Write-Host "  Download complete!" -ForegroundColor Green
} else {
    Write-Host "  Model already exists, skipping download" -ForegroundColor Green
}

Write-Host ""

# Step 2: Create data directories
Write-Host "[Step 2] Creating data directories..." -ForegroundColor Cyan
@("data/node-1", "data/node-2") | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force
        Write-Host "  Created $_"
    }
}

Write-Host ""

# Step 3: Build Rust backend
Write-Host "[Step 3] Building Rust backend..." -ForegroundColor Cyan
cargo build --release
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Rust build successful!" -ForegroundColor Green
} else {
    Write-Host "  Rust build failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 4: Run with Docker Compose
Write-Host "[Step 4] Starting services with Docker Compose..." -ForegroundColor Cyan
Write-Host "  Run: docker compose up -d"
Write-Host "  Or run locally:"
Write-Host "    Terminal 1: cargo run --release -- --identity node-1 --port 8000"
Write-Host "    Terminal 2: cargo run --release -- --identity node-2 --port 8001 --bootstrap /ip4/127.0.0.1/tcp/8000"

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  Setup complete!" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. flutter pub get (in flutter_app/)"
Write-Host "  2. Open flutter_app/ in your IDE"
Write-Host "  3. Run flutter run for the mobile app"
Write-Host "  4. Use @gemma <prompt> in chat to talk to AI"
