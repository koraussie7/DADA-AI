param(
    [string]$Server = "185.55.243.225",
    [string]$User = "root",
    [string]$FlutterDir = "/root/DADA-AI/flutter_app",
    [string]$WebDir = "/var/www/html",
    [string]$ServerPyPath = "/root/liberty-web/server.py",
    [string]$NginxConfPath = "/etc/nginx/sites-available/privseai"
)

Write-Host "=== DADA-AI Flutter Web + Server Deploy ===" -ForegroundColor Magenta

# 1. Upload Flutter source changes
Write-Host "[1/6] Uploading Flutter source..." -ForegroundColor Cyan
ssh "${User}@${Server}" "mkdir -p $FlutterDir/lib/core/design_system $FlutterDir/lib/screens $FlutterDir/lib/services $FlutterDir/web"
scp -r flutter_app/lib/* "${User}@${Server}:${FlutterDir}/lib/"
if (Test-Path flutter_app/web/index.html) {
    scp flutter_app/web/index.html "${User}@${Server}:${FlutterDir}/web/"
}

# 2. Build Flutter web on server
Write-Host "[2/6] Building Flutter web (server-side)..." -ForegroundColor Cyan
ssh "${User}@${Server}" "cd $FlutterDir && flutter build web --release"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed. Check Flutter SDK on server." -ForegroundColor Red
    exit 1
}

# 3. Copy build output to web dir
Write-Host "[3/6] Deploying to $WebDir ..." -ForegroundColor Cyan
ssh "${User}@${Server}" "cp -r $FlutterDir/build/web/* $WebDir/"

# 4. Upload & restart server.py
Write-Host "[4/6] Updating server.py..." -ForegroundColor Cyan
scp server.py "${User}@${Server}:${ServerPyPath}"
ssh "${User}@${Server}" "pkill -f 'python3 server.py' 2>/dev/null; cd /root/liberty-web && nohup python3 server.py > liberty.log 2>&1 &"

# 5. Upload nginx config & reload
Write-Host "[5/6] Updating nginx config..." -ForegroundColor Cyan
scp privseai_nginx "${User}@${Server}:${NginxConfPath}"
ssh "${User}@${Server}" "nginx -t && systemctl reload nginx"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Nginx config test failed!" -ForegroundColor Red
    exit 1
}
Write-Host "  nginx reloaded!" -ForegroundColor Green

# 6. Purge Cloudflare cache
Write-Host "[6/6] Purging Cloudflare cache..." -ForegroundColor Cyan
$cfToken = $env:CF_API_TOKEN
$zoneId = $env:CF_ZONE_ID
$cfHeaders = @{ "Authorization" = "Bearer $cfToken"; "Content-Type" = "application/json" }
$cfBody = '{"purge_everything":true}'
try {
    $r = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/purge_cache" `
        -Method POST -Headers $cfHeaders -Body $cfBody -ContentType "application/json"
    if ($r.success) { Write-Host "  Cloudflare cache purged!" -ForegroundColor Green }
    else { Write-Host "  Purge failed: $($r.errors)" -ForegroundColor Yellow }
} catch { Write-Host "  Purge error: $_" -ForegroundColor Yellow }

# Verify security headers
Write-Host "`nVerifying security headers..." -ForegroundColor Cyan
try {
    $resp = Invoke-WebRequest -Uri "https://privseai.com" -UseBasicParsing
    $h = $resp.Headers
    $checks = @(
        @{Name="X-Frame-Options"; Expected="DENY"},
        @{Name="X-Content-Type-Options"; Expected="nosniff"},
        @{Name="Strict-Transport-Security"; Expected="max-age=31536000"},
        @{Name="Referrer-Policy"; Expected="strict-origin-when-cross-origin"},
        @{Name="Content-Security-Policy"; Expected="default-src 'self'"}
    )
    foreach ($check in $checks) {
        $val = $h[$check.Name] -join ''
        if ($val -and $val -like "*$($check.Expected)*") {
            Write-Host "  ✓ $($check.Name)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($check.Name) — MISSING" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "  Header verification failed: $_" -ForegroundColor Yellow
}

Write-Host "`n=== Deploy complete! https://privseai.com ===" -ForegroundColor Green
