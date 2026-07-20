@echo off
:: [AUTO-ADMIN] Elevasi Hak Akses Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList \"/c \"\"%~f0\"\"\" -Verb RunAs"
    exit /b
)

pushd "%~dp0"
title MEGAPASS Windows Optimizer v3.0
echo ===================================================
echo     MEGAPASS INTRA SOLUSINDO - WINDOWS OPTIMIZER
echo ===================================================
echo.
echo [*] Memulai Protokol Optimasi Sistem...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$c = (Get-Content -LiteralPath $args[0] -Raw) -split '# --- POWERSHELL ---'; iex $c[1]" "%~f0"
echo.
echo ===================================================
echo [+] All optimizations applied successfully!
echo ===================================================
pause
exit /b

# --- POWERSHELL ---
$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Starting MegaPass Windows Optimization v3.0 <<<" -ForegroundColor Cyan
Write-Host "---------------------------------------------------" -ForegroundColor Gray

# 1. Detect OS
$OSBuild = [System.Environment]::OSVersion.Version.Build
$IsWin11 = $OSBuild -ge 22000
if ($IsWin11) { $OSName = "11" } else { $OSName = "10" }
Write-Host "[*] OS Detected: Windows $OSName (Build $OSBuild)" -ForegroundColor Green

# 2. Power Settings (High Performance & 5h Sleep)
Write-Host "[*] Configuring Power Plan & Sleep Timeout..." -ForegroundColor Yellow
$hp_guid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
$plans = powercfg -list
if (!($plans -match $hp_guid)) {
    powercfg -duplicatescheme $hp_guid | Out-Null
}
powercfg -setactive $hp_guid
powercfg -change monitor-timeout-ac 300
powercfg -change monitor-timeout-dc 300
powercfg -change standby-timeout-ac 300
powercfg -change standby-timeout-dc 300

# 3. Focus Assist (Do Not Disturb)
Write-Host "[*] Configuring Focus Assist (Quiet Mode)..." -ForegroundColor Yellow
$FocusPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\FocusAssist"
if (!(Test-Path $FocusPath)) { New-Item -Path $FocusPath -Force | Out-Null }
Set-ItemProperty -Path $FocusPath -Name "FocusAssistState" -Value 2 -Force

$NotifPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
if (!(Test-Path $NotifPath)) { New-Item -Path $NotifPath -Force | Out-Null }
Set-ItemProperty -Path $NotifPath -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0 -Force

# 4. Windows 11 UI Layout
if ($IsWin11) {
    Write-Host "[*] Configuring Windows 11 Taskbar Icons..." -ForegroundColor Yellow
    $AdvPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $AdvPath -Name "TaskbarDa" -Value 0 -Force
    Set-ItemProperty -Path $AdvPath -Name "TaskbarMn" -Value 0 -Force
    Set-ItemProperty -Path $AdvPath -Name "ShowTaskViewButton" -Value 0 -Force
    Set-ItemProperty -Path $AdvPath -Name "TaskbarAl" -Value 1 -Force
}

# 5. Disable Taskbar Auto-Hide
Write-Host "[*] Disabling Taskbar Auto-Hide..." -ForegroundColor Yellow
$TaskbarPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
if (Test-Path $TaskbarPath) {
    $settings = Get-ItemProperty -Path $TaskbarPath -Name "Settings" -ErrorAction SilentlyContinue
    if ($settings) {
        $data = $settings.Settings
        if ($data[8] -band 1) {
            $data[8] = $data[8] -band 0xFE
            Set-ItemProperty -Path $TaskbarPath -Name "Settings" -Value $data -Force
        }
    }
}
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAutoHideDesktop" -Value 0 -Force

# 6. Safe Bloatware Uninstall with Live Progress
Write-Host "[*] Uninstalling Unwanted Bloatware..." -ForegroundColor Yellow
$BloatApps = @(
    "*Cortana*", "*Xbox*", "*Solitaire*", "*OfficeHub*", "*SkypeApp*", "*FeedbackHub*", "*GetHelp*",
    "*ZuneVideo*", "*ZuneMusic*", "*3DBuilder*", "*MixedReality*", "*OneNote*", "*People*",
    "*StickyNotes*", "*BingWeather*", "*BingNews*", "*BingSports*", "*BingFinance*", "*YourPhone*",
    "*Disney*", "*Spotify*", "*TikTok*", "*Instagram*", "*CandyCrush*", "*Facebook*", "*Twitter*", 
    "*LinkedIn*", "*Clipchamp*", "*WhatsApp*", "*ByteDance*",
    "*McAfee*", "*Norton*", "*Avast*", "*AVG*"
)
$ProvisionedApps = Get-AppxProvisionedPackage -Online
foreach ($app in $BloatApps) {
    $cleanAppName = $app.Replace("*", "")
    Write-Host "  [-] Processing: $cleanAppName" -ForegroundColor Gray
    Get-AppxPackage -AllUsers -Name $app | Remove-AppxPackage | Out-Null
    $ProvisionedApps | Where-Object {$_.DisplayName -like $app} | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName | Out-Null }
}

# 7. Visual Effects (Adjust for Best Performance)
Write-Host "[*] Optimizing Visual Effects for Performance..." -ForegroundColor Yellow
$VisualEffectsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (!(Test-Path $VisualEffectsPath)) { New-Item -Path $VisualEffectsPath -Force | Out-Null }
Set-ItemProperty -Path $VisualEffectsPath -Name "VisualFXSetting" -Value 2 -Force
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]]@(144,20,7,128,16,0,0,0)) -Force
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Force
$ExplorerAdvPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $ExplorerAdvPath -Name "ListviewAlphaSelect" -Value 0 -Force
Set-ItemProperty -Path $ExplorerAdvPath -Name "ListviewShadow" -Value 0 -Force
Set-ItemProperty -Path $ExplorerAdvPath -Name "TaskbarAnimations" -Value 0 -Force

# 8. Disable Windows Defender
Write-Host "[*] Disabling Windows Defender..." -ForegroundColor Yellow
Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true -DisableIOAVProtection $true -SignatureDisableUpdateOnStartupWithoutEngine $true -DisableArchiveScanning $true -DisableIntrusionPreventionSystem $true -DisableScriptScanning $true

$DefPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
if (!(Test-Path $DefPath)) { New-Item -Path $DefPath -Force | Out-Null }
Set-ItemProperty -Path $DefPath -Name "DisableAntiSpyware" -Value 1 -Force

$RealtimePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
if (!(Test-Path $RealtimePath)) { New-Item -Path $RealtimePath -Force | Out-Null }
Set-ItemProperty -Path $RealtimePath -Name "DisableRealtimeMonitoring" -Value 1 -Force

# 9. Pause Windows Updates until 2099
Write-Host "[*] Pausing Windows Update Service..." -ForegroundColor Yellow
$UpdatePath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
if (!(Test-Path $UpdatePath)) { New-Item -Path $UpdatePath -Force | Out-Null }
Set-ItemProperty -Path $UpdatePath -Name "PauseUpdatesExpiryTime" -Value "2099-12-31T23:59:59Z" -Force
Set-ItemProperty -Path $UpdatePath -Name "PauseFeatureUpdatesStartTime" -Value "2026-01-01T00:00:00Z" -Force
Set-ItemProperty -Path $UpdatePath -Name "PauseQualityUpdatesStartTime" -Value "2026-01-01T00:00:00Z" -Force

# 10. Folder Options (Launch to This PC)
Write-Host "[*] Tweaking Folder Options & Desktop Icons..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -Force
$ExplorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
Set-ItemProperty -Path $ExplorerPath -Name "ShowRecent" -Value 0 -Force
Set-ItemProperty -Path $ExplorerPath -Name "ShowFrequent" -Value 0 -Force

# This PC Desktop Icon
$DesktopIcons = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
if (!(Test-Path $DesktopIcons)) { New-Item -Path $DesktopIcons -Force | Out-Null }
Set-ItemProperty -Path $DesktopIcons -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -Force

# 11. Cleanup Cache & Temp Files
Write-Host "[*] Purging Temporary Files & System Caches..." -ForegroundColor Yellow
winget cache clean --accept-source-agreements | Out-Null
ipconfig /flushdns | Out-Null

# Stop Update service safely
cmd.exe /c "net stop wuauserv /y"
$DownloadPath = "$env:SystemRoot\SoftwareDistribution\Download"
if (Test-Path $DownloadPath) {
    Get-ChildItem $DownloadPath -Recurse -Force | Remove-Item -Recurse -Force
}
cmd.exe /c "net start wuauserv"

# Clean temp directories (preserve browser cookies/data)
$TempPaths = @(
    "$env:TEMP",
    "$env:SystemRoot\Temp",
    "$env:SystemRoot\Prefetch"
)
foreach ($path in $TempPaths) {
    if (Test-Path $path) {
        Get-ChildItem $path -Recurse -Force | Where-Object { $_.FullName -notmatch "Browser|Chrome|Edge|Firefox|Opera|Brave|User Data" } | Remove-Item -Recurse -Force
    }
}
Clear-RecycleBin -Confirm:$false

# 12. Reset Shell Views & Restart Explorer
Write-Host "[*] Resetting Folder Views & Relaunching Explorer..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force
Start-Sleep -Seconds 2

# Remove view layout caches
Remove-Item -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags" -Recurse -Force
Remove-Item -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU" -Recurse -Force

Start-Process "explorer.exe"

Write-Host "---------------------------------------------------" -ForegroundColor Gray
Write-Host "[+] System optimization complete!" -ForegroundColor Green
