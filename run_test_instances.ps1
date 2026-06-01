# Helper script to launch 2 instances of the project side-by-side to test multiplayer locally.

$godotPath = "godot"
$projectPath = "C:\Users\marvi\Projekte\mtg"

Write-Host "Starting Instance 1 (Host/Player 1)..." -ForegroundColor Green
Start-Process -FilePath $godotPath -ArgumentList "--path", "`"$projectPath`""

# Start-Sleep -Seconds 1
# Write-Host "Starting Instance 2 (Client/Player 2)..." -ForegroundColor Cyan
# Start-Process -FilePath $godotPath -ArgumentList "--path", "`"$projectPath`""

# Start-Sleep -Seconds 1
# Write-Host "Starting Instance 3 (Client/Player 3)..." -ForegroundColor Cyan
# Start-Process -FilePath $godotPath -ArgumentList "--path", "`"$projectPath`""

# Start-Sleep -Seconds 1
# Write-Host "Starting Instance 4 (Client/Player 4)..." -ForegroundColor Cyan
# Start-Process -FilePath $godotPath -ArgumentList "--path", "`"$projectPath`""
