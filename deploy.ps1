param(
    [string]$Server = "185.55.243.225",
    [string]$User = "root",
    [string]$Port = "8000"
)

Write-Host "=== Liberty Reach Server Deploy ===" -ForegroundColor Yellow
Write-Host ""

# 1. Upload server.py
Write-Host "[1/3] Uploading server.py to $Server ..." -ForegroundColor Cyan
scp "server.py" "${User}@${Server}:/root/liberty-web/"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Upload failed." -ForegroundColor Red
    exit 1
}
Write-Host "  OK" -ForegroundColor Green

# 2. Restart server
Write-Host "[2/3] Restarting server..." -ForegroundColor Cyan
ssh "${User}@${Server}" "pkill -f 'python3 server.py' 2>/dev/null; cd /root/liberty-web && nohup python3 server.py > liberty.log 2>&1 &"
Write-Host "  OK" -ForegroundColor Green

# 3. Check status
Write-Host "[3/3] Verifying server is running..." -ForegroundColor Cyan
Start-Sleep -Seconds 2
try {
    $res = Invoke-WebRequest -Uri "https://privseai.com/health" -UseBasicParsing -ErrorAction SilentlyContinue
    if ($res.StatusCode -eq 200) {
        Write-Host "  SERVER IS LIVE!" -ForegroundColor Green
    }
} catch {
    Write-Host "  Check manually: ssh ${User}@${Server} 'tail /root/liberty-web/liberty.log'" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
