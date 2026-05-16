param(
    [string]$Server = "185.55.243.225",
    [string]$User = "root",
    [string]$FlutterDir = "/root/DADA-AI/flutter_app",
    [string]$WebDir = "/var/www/privseai/build/web",
    [string]$ServerPyPath = "/root/liberty-web/server.py",
    [string]$CaddyConfPath = "/etc/caddy/Caddyfile",
    [string]$LocalFlutter = "flutter_app"
)

Write-Host "=== Deploy: Flutter Web + Server.py + Caddy ===" -ForegroundColor Magenta

# 1. Sync Flutter source (rsync style via scp)
Write-Host "[1/4] Syncing Flutter source..." -ForegroundColor Cyan
ssh "${User}@${Server}" "mkdir -p $FlutterDir/lib $FlutterDir/web"

# Upload lib/ recursively via tar pipe
ssh "${User}@${Server}" "mkdir -p $FlutterDir/lib"
Get-ChildItem -Path "$LocalFlutter/lib" -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring((Get-Item "$LocalFlutter/lib").FullName.Length + 1)
    $remoteDir = "$FlutterDir/lib/$([System.IO.Path]::GetDirectoryName($rel))".Replace('\', '/')
    scp "$($_.FullName)" "${User}@${Server}:$remoteDir/"
}

# Upload web/ assets
if (Test-Path "$LocalFlutter/web") {
    ssh "${User}@${Server}" "mkdir -p $FlutterDir/web"
    Get-ChildItem -Path "$LocalFlutter/web" -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring((Get-Item "$LocalFlutter/web").FullName.Length + 1)
        $remoteDir = "$FlutterDir/web/$([System.IO.Path]::GetDirectoryName($rel))".Replace('\', '/')
        scp "$($_.FullName)" "${User}@${Server}:$remoteDir/"
    }
}

# Upload pubspec.yaml
scp "$LocalFlutter/pubspec.yaml" "${User}@${Server}:$FlutterDir/pubspec.yaml"

# 2. Build Flutter web on server
Write-Host "[2/4] Building Flutter web (server)..." -ForegroundColor Cyan
ssh "${User}@${Server}" "cd $FlutterDir && flutter build web --release 2>&1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter build FAILED" -ForegroundColor Red
    exit 1
}
Write-Host "  Build OK" -ForegroundColor Green

# 3. Deploy build output + server.py + Caddyfile
Write-Host "[3/4] Deploying to $WebDir ..." -ForegroundColor Cyan
ssh "${User}@${Server}" @"
    # Copy Flutter web build
    mkdir -p $WebDir
    cp -r $FlutterDir/build/web/* $WebDir/
    # Restart server.py
    if [ -f $ServerPyPath ]; then
        pkill -f 'python3 server.py' 2>/dev/null
        sleep 1
        cd $(dirname $ServerPyPath)
        nohup python3 server.py > liberty.log 2>&1 &
        echo "  server.py restarted (PID: \$!)"
    fi
"@

# Upload and reload Caddy config if local Caddyfile exists
if (Test-Path "Caddyfile") {
    Write-Host "  Syncing Caddyfile..." -ForegroundColor Cyan
    scp Caddyfile "${User}@${Server}:${CaddyConfPath}"
    ssh "${User}@${Server}" "caddy validate --config $CaddyConfPath 2>&1 | tail -1"
    if ($LASTEXITCODE -eq 0) {
        ssh "${User}@${Server}" "systemctl reload caddy"
        Write-Host "  Caddy reloaded" -ForegroundColor Green
    } else {
        Write-Host "  Caddy config invalid — skipped reload" -ForegroundColor Yellow
    }
}

# 4. Purge Cloudflare cache
Write-Host "[4/4] Purging Cloudflare cache..." -ForegroundColor Cyan
$cfToken = $env:CF_API_TOKEN
$zoneId = $env:CF_ZONE_ID
$cfHeaders = @{ "Authorization" = "Bearer $cfToken"; "Content-Type" = "application/json" }
$cfBody = '{"purge_everything":true}'
try {
    $r = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/purge_cache" `
        -Method POST -Headers $cfHeaders -Body $cfBody -ContentType "application/json"
    if ($r.success) { Write-Host "  Cache purged!" -ForegroundColor Green }
    else { Write-Host "  Purge failed: $($r.errors)" -ForegroundColor Yellow }
} catch { Write-Host "  Purge error: $_" -ForegroundColor Yellow }

# Verify
Write-Host "`n=== Verifying ===" -ForegroundColor Cyan
try {
    $resp = Invoke-WebRequest -Uri "https://privseai.com" -UseBasicParsing -DisableKeepAlive -TimeoutSec 10
    Write-Host "  Status : $($resp.StatusCode)" -ForegroundColor Green
    Write-Host "  Server : $($resp.Headers.Server)" -ForegroundColor Green
    Write-Host "  HSTS   : $($resp.Headers.'Strict-Transport-Security')" -ForegroundColor Green
} catch {
    Write-Host "  Verify failed: $_" -ForegroundColor Yellow
}

Write-Host "`n=== Deploy complete! https://privseai.com ===" -ForegroundColor Green
