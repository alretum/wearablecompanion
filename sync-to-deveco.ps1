# Sync files from wearablecompanion to DevEcoStudioProjects\wearablecompanion
$source = "C:\Users\taker\wearablecompanion"
$dest = "C:\Users\taker\DevEcoStudioProjects\wearablecompanion"

Write-Host "Syncing files to DevEco Studio project..." -ForegroundColor Cyan

$files = @(
    "entry\src\main\ets\services\DemoManager.ets",
    "entry\src\main\ets\services\AudioPlayer.ets",
    "entry\src\main\ets\services\MonitoringService.ets",
    "entry\src\main\ets\algorithms\MotionAnalyzer.ets",
    "entry\src\main\ets\algorithms\TremorDetector.ets",
    "entry\src\main\ets\pages\Index.ets",
    "entry\src\main\ets\config\AppConfig.ets"
)

$copied = 0
$failed = 0

foreach ($file in $files) {
    $sourcePath = Join-Path $source $file
    $destPath = Join-Path $dest $file
    
    try {
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        Write-Host "  [OK] Copied: $file" -ForegroundColor Green
        $copied++
    }
    catch {
        Write-Host "  [FAIL] Failed: $file - $_" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "Summary: $copied files copied, $failed failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
Write-Host ""
Write-Host "Ready to build in DevEco Studio!" -ForegroundColor Cyan
