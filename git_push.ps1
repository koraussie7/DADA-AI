$ErrorActionPreference = "Stop"
$REPO_URL = "https://github.com/koraussie7/liberty-reach.git"
$REPO_NAME = "koraussie7/liberty-reach"

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  Liberty Reach -> GitHub Push" -ForegroundColor Yellow
Write-Host "  $REPO_NAME" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

# STEP 1: Install Git if needed
$gitPath = (Get-Command git -ErrorAction SilentlyContinue).Source

if (-not $gitPath) {
    Write-Host "[1] Git not found. Installing Git for Windows..." -ForegroundColor Cyan

    $gitInstaller = "$env:TEMP\Git-2.45.exe"
    Write-Host "  Downloading..." -ForegroundColor Gray
    Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/download/v2.45.0.windows.1/Git-2.45.0-64-bit.exe" -OutFile $gitInstaller -UseBasicParsing

    Write-Host "  Installing..." -ForegroundColor Gray
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS=`"icons,ext,reg,shell,assoc`"" -Wait -NoNewWindow

    Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue

    $env:Path = "${env:ProgramFiles}\Git\bin;${env:ProgramFiles(x86)}\Git\bin;$env:Path"

    $gitTest = (Get-Command git -ErrorAction SilentlyContinue).Source
    if ($gitTest) {
        Write-Host "  [OK] Git installed" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Install Git manually: https://git-scm.com/download/win" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[1] Git found: $gitPath" -ForegroundColor Green
}

# STEP 2: Init repo
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -Path $projectRoot

Write-Host "[2] Initializing git repository..." -ForegroundColor Cyan

if (Test-Path ".git") {
    Write-Host "  [OK] Already a git repo" -ForegroundColor Green
} else {
    git init
    Write-Host "  [OK] git init complete" -ForegroundColor Green
}

# STEP 3: Add + Commit
Write-Host "[3] Staging and committing files..." -ForegroundColor Cyan

git add -A
$filesStaged = git diff --cached --stat | Measure-Object -Line | Select-Object -ExpandProperty Lines
Write-Host "  [OK] $filesStaged files staged" -ForegroundColor Green

git commit -m "Liberty Reach v0.1.0 - AI-Powered P2P Messenger"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Commit created" -ForegroundColor Green
} else {
    git commit -m "Initial commit"
}

# STEP 4: Remote
Write-Host "[4] Setting up GitHub remote..." -ForegroundColor Cyan

git remote remove origin 2>$null
git remote add origin $REPO_URL
Write-Host "  [OK] Remote added: $REPO_URL" -ForegroundColor Green

# STEP 5: Push
Write-Host "[5] Pushing to GitHub..." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Need a GitHub token? Create one at:" -ForegroundColor Yellow
Write-Host "  https://github.com/settings/tokens" -ForegroundColor Yellow
Write-Host "  (Scope: repo, use token as password)" -ForegroundColor Yellow
Write-Host ""

git push -u origin main
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[SUCCESS] Pushed to GitHub!" -ForegroundColor Green
    Write-Host "https://github.com/koraussie7/liberty-reach" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "[FAIL] Push failed. Try:" -ForegroundColor Yellow
    Write-Host "  1. git remote set-url origin https://koraussie7@github.com/koraussie7/liberty-reach.git" -ForegroundColor Gray
    Write-Host "  2. git push -u origin main" -ForegroundColor Gray
    Write-Host "  3. (enter your Personal Access Token as password)" -ForegroundColor Gray
}

pause

