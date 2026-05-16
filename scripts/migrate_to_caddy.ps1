param(
    [string]$Server = "185.55.243.225",
    [string]$User = "root"
)

Write-Host "=== Nginx → Caddy Migration ===" -ForegroundColor Magenta

# 1. Upload Caddyfile
Write-Host "[1/5] Uploading Caddyfile..." -ForegroundColor Cyan
scp ../Caddyfile "${User}@${Server}:/etc/caddy/Caddyfile"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Upload failed. Ensure /etc/caddy/ exists." -ForegroundColor Red
    exit 1
}

# 2. Install Caddy if not present
Write-Host "[2/5] Installing Caddy..." -ForegroundColor Cyan
ssh "${User}@${Server}" @'
if ! command -v caddy &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt" | tee /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -qq && apt-get install -y -qq caddy
fi
'@

# 3. Disable Nginx, enable Caddy
Write-Host "[3/5] Switching from Nginx to Caddy..." -ForegroundColor Cyan
ssh "${User}@${Server}" @'
systemctl stop nginx
systemctl disable nginx
systemctl enable caddy
'@

# 4. Start Caddy
Write-Host "[4/5] Starting Caddy..." -ForegroundColor Cyan
ssh "${User}@${Server}" @'
mkdir -p /var/log/caddy
caddy validate --config /etc/caddy/Caddyfile
if [ $? -eq 0 ]; then
    systemctl restart caddy
    echo "Caddy started successfully"
else
    echo "Caddy config validation FAILED"
    exit 1
fi
'@
if ($LASTEXITCODE -ne 0) {
    Write-Host "Caddy validation failed! Rolling back..." -ForegroundColor Red
    ssh "${User}@${Server}" "systemctl enable --now nginx"
    exit 1
}

# 5. Verify
Write-Host "[5/5] Verifying..." -ForegroundColor Cyan
Start-Sleep -Seconds 3
ssh "${User}@${Server}" "systemctl status caddy --no-pager | head -10"
try {
    $resp = Invoke-WebRequest -Uri "https://privseai.com" -UseBasicParsing -DisableKeepAlive
    Write-Host "  Status: $($resp.StatusCode)" -ForegroundColor Green
    Write-Host "  Server: $($resp.Headers.Server)" -ForegroundColor Green
    Write-Host "  HSTS: $($resp.Headers.'Strict-Transport-Security')" -ForegroundColor Green
} catch {
    Write-Host "  Verification request failed: $_" -ForegroundColor Yellow
}

Write-Host "=== Migration complete! ===" -ForegroundColor Green
Write-Host "Nginx is stopped/disabled. Caddy manages privseai.com + muhantube.com"
Write-Host "Rollback: systemctl enable --now nginx && systemctl stop caddy && systemctl disable caddy"
