param(
    [string]$Server = "muhantube.com",
    [string]$User = "root",
    [string]$Port = "80"
)

Write-Host "=== Liberty Reach Web Chat Deploy ===" -ForegroundColor Yellow
Write-Host ""

# 1. Upload files to server
Write-Host "[1/3] Uploading files to $Server ..." -ForegroundColor Cyan
scp -r "web_chat.html" "server.py" "${User}@${Server}:/root/liberty-web/"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Upload failed. Create the directory first:" -ForegroundColor Red
    Write-Host "  ssh ${User}@${Server} 'mkdir -p /root/liberty-web'" -ForegroundColor Gray
    exit 1
}
Write-Host "  OK" -ForegroundColor Green

# 2. Start server (in background via screen)
Write-Host "[2/3] Starting server on port $Port ..." -ForegroundColor Cyan
ssh "${User}@${Server}" "cd /root/liberty-web && screen -dmS liberty python3 server.py $Port"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to start. Trying without screen..." -ForegroundColor Yellow
    ssh "${User}@${Server}" "cd /root/liberty-web && nohup python3 server.py $Port > liberty.log 2>&1 &"
}
Write-Host "  OK" -ForegroundColor Green

# 3. Check status
Write-Host "[3/3] Verifying server is running..." -ForegroundColor Cyan
Start-Sleep -Seconds 2
$res = Invoke-WebRequest -Uri "http://${Server}:${Port}/healthz" -UseBasicParsing -ErrorAction SilentlyContinue
if ($res -and $res.StatusCode -eq 200) {
    Write-Host "  SERVER IS LIVE at http://${Server}:${Port}!" -ForegroundColor Green
} else {
    Write-Host "  Check manually: ssh ${User}@${Server} 'tail /root/liberty-web/liberty.log'" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Open in browser: http://${Server}:${Port}" -ForegroundColor Green
Write-Host "Stop server: ssh ${User}@${Server} 'pkill -f server.py'" -ForegroundColor Gray
