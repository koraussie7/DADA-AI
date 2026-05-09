<#
╔══════════════════════════════════════════════════════════════════╗
║           Liberty Reach - Windows All-in-One Installer          ║
║                                                                 ║
║  This script installs everything needed to build and run        ║
║  Liberty Reach on Windows:                                      ║
║    • Rust + cargo   • Flutter SDK   • flutter_rust_bridge       ║
║    • Docker Desktop  • Gemma AI model  • Project setup          ║
╚══════════════════════════════════════════════════════════════════╝
#>

#requires -version 5.1

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$LIBERTY_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
$FLUTTER_APP = Join-Path $LIBERTY_ROOT "flutter_app"
$LOG_FILE = Join-Path $LIBERTY_ROOT "install.log"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMsg = "[$timestamp] $Message"
    Write-Host $logMsg -ForegroundColor $Color
    Add-Content -Path $LOG_FILE -Value $logMsg -ErrorAction SilentlyContinue
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "╔══ $Title ══╗" -ForegroundColor Yellow
    Write-Host ""
}

function Wait-ProcessWithProgress {
    param([string]$Name, [scriptblock]$ScriptBlock)
    Write-Log "Installing $Name..." -Color Cyan
    $job = Start-Job -ScriptBlock $ScriptBlock
    $spinner = @('|', '/', '-', '\')
    $i = 0
    while ($job.State -eq 'Running') {
        Write-Host "`r  $($spinner[$i % 4]) Installing $Name..." -NoNewline
        Start-Sleep -Milliseconds 300
        $i++
    }
    Write-Host "`r  Done!" -ForegroundColor Green
    Receive-Job $job -Wait | Out-Null
}

# ═══════════════════════════════════════════════════════════════════
# MAIN SCRIPT
# ═══════════════════════════════════════════════════════════════════

Clear-Host
Write-Host @"

██╗     ██╗██████╗ ███████╗██████╗ ████████╗██╗   ██╗
██║     ██║██╔══██╗██╔════╝██╔══██╗╚══██╔══╝╚██╗ ██╔╝
██║     ██║██████╔╝█████╗  ██████╔╝   ██║    ╚████╔╝
██║     ██║██╔══██╗██╔══╝  ██╔══██╗   ██║     ╚██╔╝
███████╗██║██████╔╝███████╗██║  ██║   ██║      ██║
╚══════╝╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝   ╚═╝      ╚═╝

"@ -ForegroundColor Yellow
Write-Host "  AI-Powered P2P Messenger  |  Windows Installer" -ForegroundColor White
Write-Host "  Version 0.1.0" -ForegroundColor Gray
Write-Host ""

# ══════════════ ADMIN CHECK ══════════════

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Log "This installer needs Administrator privileges." -Color Yellow
    Write-Log "Restarting as Administrator..." -Color Cyan
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Write-Log "Administrator privileges confirmed" -Color Green
Write-Host ""

# ══════════════ PREREQUISITE CHECKS ══════════════

Write-Section "Step 1: Checking Prerequisites"

$needsRust = $false
$needsFlutter = $false
$needsDocker = $false

# Check Rust
$rustVersion = (& rustc --version 2>&1) -join ''
if ($LASTEXITCODE -eq 0) {
    Write-Log "✓ Rust found: $rustVersion" -Color Green
} else {
    Write-Log "✗ Rust not found. Will install." -Color Yellow
    $needsRust = $true
}

# Check Flutter
$flutterVersion = (& flutter --version 2>&1) -join ''
if ($LASTEXITCODE -eq 0) {
    Write-Log "✓ Flutter found" -Color Green
} else {
    Write-Log "✗ Flutter not found. Will install." -Color Yellow
    $needsFlutter = $true
}

# Check Docker
$dockerVersion = (& docker --version 2>&1) -join ''
if ($LASTEXITCODE -eq 0) {
    Write-Log "✓ Docker found: $dockerVersion" -Color Green
} else {
    Write-Log "~ Docker not found (optional, for LocalAI)" -Color Gray
    $needsDocker = $true
}

# Check flutter_rust_bridge_codegen
$hasFrbCodegen = (& flutter_rust_bridge_codegen --version 2>&1) -join ''
if ($LASTEXITCODE -eq 0) {
    Write-Log "✓ flutter_rust_bridge_codegen found" -Color Green
}

Write-Host ""

# ══════════════ INSTALL RUST ══════════════

if ($needsRust) {
    Write-Section "Step 2: Installing Rust"

    $rustupUrl = "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe"
    $rustupPath = "$env:TEMP\rustup-init.exe"

    Write-Log "Downloading rustup-init.exe..." -Color Cyan
    Invoke-WebRequest -Uri $rustupUrl -OutFile $rustupPath -UseBasicParsing

    Write-Log "Installing Rust (this may take a few minutes)..." -Color Cyan
    Start-Process -FilePath $rustupPath -ArgumentList "-y --default-toolchain stable --profile default" -Wait -NoNewWindow

    # Refresh PATH
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

    $rustVersion = (& rustc --version 2>&1) -join ''
    if ($LASTEXITCODE -eq 0) {
        Write-Log "✓ Rust installed: $rustVersion" -Color Green
    } else {
        Write-Log "✗ Rust installation failed!" -Color Red
        exit 1
    }
    Remove-Item $rustupPath -Force -ErrorAction SilentlyContinue
}

# ══════════════ INSTALL FLUTTER ══════════════

if ($needsFlutter) {
    Write-Section "Step 3: Installing Flutter SDK"

    $flutterZip = "$env:TEMP\flutter.zip"
    $flutterDir = "C:\flutter"

    Write-Log "Downloading Flutter SDK (3.x stable)..." -Color Cyan
    Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.0-stable.zip" -OutFile $flutterZip -UseBasicParsing

    Write-Log "Extracting to C:\flutter..." -Color Cyan
    if (Test-Path $flutterDir) { Remove-Item $flutterDir -Recurse -Force }
    Expand-Archive -Path $flutterZip -DestinationPath "C:\" -Force

    # Add to PATH
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*C:\flutter\bin*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;C:\flutter\bin", "User")
    }
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($machinePath -notlike "*C:\flutter\bin*") {
        [Environment]::SetEnvironmentVariable("Path", "$machinePath;C:\flutter\bin", "Machine")
    }

    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

    Remove-Item $flutterZip -Force -ErrorAction SilentlyContinue

    Write-Log "Running flutter doctor..." -Color Cyan
    & flutter doctor --android-licenses 2>$null
    $flutterResult = (& flutter --version 2>&1) -join ''
    if ($LASTEXITCODE -eq 0) {
        Write-Log "✓ Flutter installed successfully" -Color Green
    } else {
        Write-Log "✗ Flutter installation may have issues. Run 'flutter doctor' manually." -Color Yellow
    }
}

# ══════════════ DOCKER (OPTIONAL) ══════════════

if ($needsDocker) {
    Write-Section "Step 4: Docker Desktop (Optional)"

    Write-Log "Docker Desktop is recommended for running LocalAI." -Color Yellow
    Write-Log "You can install it manually from: https://www.docker.com/products/docker-desktop/" -Color Yellow
    Write-Host ""
    Write-Host "  [Y] Install Docker Desktop now (recommended)" -ForegroundColor Green
    Write-Host "  [N] Skip (I'll install LocalAI another way)" -ForegroundColor Gray
    $installDocker = Read-Host "  Install Docker Desktop? (Y/n)"
    Write-Host ""

    if ($installDocker -ne "n" -and $installDocker -ne "N") {
        Write-Log "Downloading Docker Desktop..." -Color Cyan
        $dockerInstaller = "$env:TEMP\DockerDesktop.exe"
        Invoke-WebRequest -Uri "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe" -OutFile $dockerInstaller -UseBasicParsing

        Write-Log "Installing Docker Desktop (system restart may be required)..." -Color Cyan
        Start-Process -FilePath $dockerInstaller -ArgumentList "install --accept-license --quiet" -Wait -NoNewWindow

        Remove-Item $dockerInstaller -Force -ErrorAction SilentlyContinue
        Write-Log "✓ Docker Desktop installed. You may need to restart your computer." -Color Green
    } else {
        Write-Log "Skipping Docker installation." -Color Gray
    }
}

# ══════════════ CHROOT / VS BUILD TOOLS CHECK ══════════════

Write-Section "Step 5: Checking Windows Build Tools"

$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsWhere) {
    $vsPath = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($vsPath) {
        Write-Log "✓ Visual Studio Build Tools found" -Color Green
    } else {
        Write-Log "~ Installing Visual Studio Build Tools (required for Rust)..." -Color Yellow
        $vsInstaller = "$env:TEMP\vs_buildtools.exe"
        Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vs_buildtools.exe" -OutFile $vsInstaller -UseBasicParsing
        Start-Process -FilePath $vsInstaller -ArgumentList "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended" -Wait -NoNewWindow
        Remove-Item $vsInstaller -Force -ErrorAction SilentlyContinue
        Write-Log "✓ Visual Studio Build Tools installed" -Color Green
    }
} else {
    Write-Log "Installing Visual Studio Build Tools (required for Rust)..." -Color Yellow
    $vsInstaller = "$env:TEMP\vs_buildtools.exe"
    try {
        Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vs_buildtools.exe" -OutFile $vsInstaller -UseBasicParsing
        Start-Process -FilePath $vsInstaller -ArgumentList "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended" -Wait -NoNewWindow
        Write-Log "✓ Visual Studio Build Tools installed" -Color Green
    } catch {
        Write-Log "✗ Failed to install VS Build Tools. Install manually: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022" -Color Red
    }
    Remove-Item $vsInstaller -Force -ErrorAction SilentlyContinue
}

# ═════════════️ INSTALL FRB CODGEN ═══════════════

Write-Section "Step 6: Installing flutter_rust_bridge_codegen"

Write-Log "Installing flutter_rust_bridge_codegen via cargo..." -Color Cyan
$frbJob = Start-Job -ScriptBlock {
    cargo install flutter_rust_bridge_codegen --locked
}
$spinner = @('|', '/', '-', '\')
$i = 0
while ($frbJob.State -eq 'Running') {
    Write-Host "`r  $($spinner[$i % 4]) Installing (this takes 5-10 minutes)..." -NoNewline
    Start-Sleep -Milliseconds 500
    $i++
}
Write-Host "`r  Done!" -ForegroundColor Green
Receive-Job $frbJob -Wait | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Log "✓ flutter_rust_bridge_codegen installed" -Color Green
} else {
    Write-Log "✗ Installation failed. Try manually: cargo install flutter_rust_bridge_codegen" -Color Red
}

# ══════════════ GENERATE FRB BINDINGS ══════════════

Write-Section "Step 7: Generating Dart-Rust Bindings"

Set-Location -Path $FLUTTER_APP

Write-Log "Running flutter_rust_bridge_codegen generate..." -Color Cyan
$genResult = & flutter_rust_bridge_codegen generate 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Log "✓ Dart bindings generated in lib/src/rust/" -Color Green
} else {
    Write-Log "✗ Codegen failed. Check rust/src/api/ for errors." -Color Red
    Write-Log "$genResult" -Color Gray
}

# ══════════════ DOWNLOAD GEMMA MODEL ══════════════

Write-Section "Step 8: Downloading Gemma-2-2B Model"

$modelDir = Join-Path $LIBERTY_ROOT "localai\models"
if (-not (Test-Path $modelDir)) {
    New-Item -ItemType Directory -Path $modelDir -Force | Out-Null
}

$modelPath = Join-Path $modelDir "gemma-2-2b-it-Q4_K_M.gguf"
if (-not (Test-Path $modelPath)) {
    Write-Log "Downloading Gemma-2-2B Q4_K_M (~1.5 GB)..." -Color Cyan
    Write-Log "This will take a while depending on your internet speed." -Color Yellow

    $modelUrl = "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf"

    try {
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFileAsync($modelUrl, $modelPath)
        $lastBytes = 0
        while ($wc.IsBusy) {
            if (Test-Path $modelPath) {
                $currentBytes = (Get-Item $modelPath).Length
                $mb = [math]::Round($currentBytes / 1MB, 1)
                $speed = [math]::Round(($currentBytes - $lastBytes) / 1MB, 1)
                Write-Host "`r  Downloaded: ${mb} MB (${speed} MB/s)" -NoNewline
                $lastBytes = $currentBytes
            }
            Start-Sleep -Seconds 2
        }
        Write-Host "`r  Downloaded: $([math]::Round((Get-Item $modelPath).Length/1MB, 1)) MB" -ForegroundColor Green
        Write-Log "✓ Model downloaded successfully" -Color Green
    } catch {
        Write-Log "✗ Download failed. You can manually download from:" -Color Red
        Write-Log "  $modelUrl" -Color Gray
        Write-Log "  Save to: $modelPath" -Color Gray
    }
} else {
    Write-Log "✓ Model already exists at $modelPath" -Color Green
}

# ═════════════️ BUILD RUST ════════════════

Write-Section "Step 9: Building Rust Backend"

Set-Location -Path $LIBERTY_ROOT

Write-Log "Building Rust backend (cargo build --release)..." -Color Cyan
Write-Log "This may take a few minutes for the first build." -Color Yellow
$buildResult = & cargo build --release 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Log "✓ Rust backend built successfully" -Color Green
    $binary = Join-Path $LIBERTY_ROOT "target\release\liberty-reach.exe"
    if (Test-Path $binary) {
        Write-Log "  Binary: $binary" -Color Gray
    }
} else {
    Write-Log "✗ Build failed. Check the output above." -Color Red
}

# ══════════════ FLUTTER PUB GET ══════════════

Write-Section "Step 10: Installing Flutter Dependencies"

Set-Location -Path $FLUTTER_APP
Write-Log "Running flutter pub get..." -Color Cyan
$pubResult = & flutter pub get 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Log "✓ Flutter dependencies installed" -Color Green
} else {
    Write-Log "✗ flutter pub get failed. Check pubspec.yaml." -Color Red
}

# ══════════════ CREATE DESKTOP SHORTCUT ══════════════

Write-Section "Step 11: Creating Desktop Shortcuts"

$desktopPath = [Environment]::GetFolderPath("Desktop")

# Run script
$runScript = @"
@echo off
title Liberty Reach
cd /d "$LIBERTY_ROOT"
echo Starting Liberty Reach...
echo.
echo [1] Start LocalAI (Docker)
echo [2] Start Rust P2P Node
echo [3] Start Flutter App
echo [4] Start All
echo.
set /p choice="Select (1-4): "
if "!choice!"=="1" start "LocalAI" cmd /c "docker run -p 8080:8080 -v %CD%\localai\models:/models localai/localai:latest"
if "!choice!"=="2" start "Liberty Node" cmd /c "cargo run --release -- --identity my-node --port 8000"
if "!choice!"=="3" start "Flutter" cmd /c "cd flutter_app && flutter run -d windows"
if "!choice!"=="4" (
    start "LocalAI" cmd /c "docker run -p 8080:8080 -v %CD%\localai\models:/models localai/localai:latest"
    timeout /t 10
    start "Liberty Node" cmd /c "cargo run --release -- --identity my-node --port 8000"
    start "Flutter" cmd /c "cd flutter_app && flutter run -d windows"
)
pause
"@

$runBat = Join-Path $LIBERTY_ROOT "run.bat"
Set-Content -Path $runBat -Value $runScript -Encoding ASCII

Write-Log "✓ Created run.bat in project directory" -Color Green

# ═══════════════════════════════════════════════════════════════════
# COMPLETION
# ═══════════════════════════════════════════════════════════════════

Write-Section "Installation Complete!"

Write-Host @"

  ╔══════════════════════════════════════════════════════╗
  ║         Liberty Reach is ready to use!              ║
  ╚══════════════════════════════════════════════════════╝

"@ -ForegroundColor Yellow

Write-Host "  Project location:" -ForegroundColor White
Write-Host "    $LIBERTY_ROOT" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Quick Start:" -ForegroundColor White
Write-Host "    Double-click: run.bat  (menu-driven launcher)" -ForegroundColor Green
Write-Host ""
Write-Host "  Or manually:" -ForegroundColor White
Write-Host "    1. Start LocalAI:" -ForegroundColor Gray
Write-Host "       docker run -p 8080:8080 -v $LIBERTY_ROOT\localai\models:/models localai/localai:latest" -ForegroundColor Cyan
Write-Host ""
Write-Host "    2. Start P2P node:" -ForegroundColor Gray
Write-Host "       cargo run --release -- --identity my-node --port 8000" -ForegroundColor Cyan
Write-Host ""
Write-Host "    3. Start Flutter app:" -ForegroundColor Gray
Write-Host "       cd flutter_app && flutter run -d windows" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Chat commands:" -ForegroundColor White
Write-Host "    @gemma <질문>    Ask AI (requires LocalAI running)" -ForegroundColor Yellow
Write-Host "    /peers           List connected P2P peers" -ForegroundColor Yellow
Write-Host "    /connect <addr>  Connect to a peer" -ForegroundColor Yellow
Write-Host ""

# Log
Write-Log "Installation completed successfully!" -Color Green
Write-Log "Log saved to: $LOG_FILE" -Color Gray

# Open project folder
Start-Process explorer.exe -ArgumentList $LIBERTY_ROOT

Write-Host "  Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
