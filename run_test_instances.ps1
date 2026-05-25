# Helper script to launch 2 instances of the project side-by-side to test multiplayer locally.

$godotPath = "C:\Users\marvi\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe"
$projectPath = "c:\Users\marvi\Projekte\mtg"

if (-not (Test-Path $godotPath)) {
    Write-Error "Godot executable not found at: $godotPath"
    exit 1
}

Write-Host "Starting Instance 1 (Host/Player 1)..." -ForegroundColor Green
Start-Process -FilePath $godotPath -ArgumentList "--path", "`"$projectPath`""

# Small delay to ensure the first instance starts setting up
Start-Sleep -Seconds 1

Write-Host "Starting Instance 2 (Client/Player 2)..." -ForegroundColor Cyan
Start-Process -FilePath $godotPath -ArgumentList "--path", "`"$projectPath`""

Write-Host "Test instances running! Go to Instance 1, select a color, click 'HOST GAME'. Then go to Instance 2, select a different color, and click 'JOIN GAME'." -ForegroundColor Yellow
