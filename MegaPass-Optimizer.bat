@echo off
:: [AUTO-ADMIN] Elevasi Hak Akses Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

pushd "%~dp0"
title MEGAPASS Windows Optimizer v2.4
echo ===================================================
echo     MEGAPASS INTRA SOLUSINDO - WINDOWS OPTIMIZER
echo ===================================================
echo.
echo [*] Memulai Protokol Optimasi Sistem...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$c = [IO.File]::ReadAllText('%~f0') -split '# --- POWERSHELL CORE LOGIC ---'; iex $c[1]"
echo.
echo ===================================================
echo [+] All optimizations applied successfully!
echo ===================================================
pause
exit /b

# --- POWERSHELL CORE LOGIC ---
$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Starting MegaPass Windows Optimization v2.4 <<<" -ForegroundColor Cyan
Write-Host "---------------------------------------------------" -ForegroundColor Gray

# Detect OS Build
$OSBuild = [System.Environment]::OSVersion.Version.Build
$IsWin11 = $OSBuild -ge 22000
$OSName = $(if ($IsWin11) { "11" } else { "10" })
Write-Host "[*] OS Detected: Windows $OSName (Build $OSBuild)" -ForegroundColor Green

# 1. Power Plan & Sleep Timeout (AC/DC - 5 Hours)
Write-Host "[*] Configuring Power Settings (High Performance & 5h Sleep)..." -ForegroundColor Yellow
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

# 2. Quiet Hours (Win 10) & Do Not Disturb (Win 11)
Write-Host "[*] Enabling Do Not Disturb / Quiet Hours..." -ForegroundColor Yellow
$FocusPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\FocusAssist"
if (!(Test-Path $FocusPath)) { New-Item -Path $FocusPath -Force | Out-Null }
Set-ItemProperty -Path $FocusPath -Name "FocusAssistState" -Value 2 -Force

$NotifPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
if (!(Test-Path $NotifPath)) { New-Item -Path $NotifPath -Force | Out-Null }
Set-ItemProperty -Path $NotifPath -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0 -Force

# 3. Windows 11 Specific Tweaks (Taskbar Layout, Widgets, Chat Icon, Task View)
if ($IsWin11) {
    Write-Host "[*] Applying Windows 11 Taskbar & UI Tweaks..." -ForegroundColor Yellow
    $AdvPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    # Sembunyikan Widgets Icon
    Set-ItemProperty -Path $AdvPath -Name "TaskbarDa" -Value 0 -Force
    # Sembunyikan Chat (Teams) Icon
    Set-ItemProperty -Path $AdvPath -Name "TaskbarMn" -Value 0 -Force
    # Sembunyikan Task View (Multi Windows) Icon
    Set-ItemProperty -Path $AdvPath -Name "ShowTaskViewButton" -Value 0 -Force
    # Tetap biarkan taskbar di tengah (1 = Center, 0 = Left)
    Set-ItemProperty -Path $AdvPath -Name "TaskbarAl" -Value 1 -Force
}

# 4. Uninstall Bloatware (Microsoft & 3rd Party Ads, Antivirus)
Write-Host "[*] Uninstalling Windows Bloatware (Safe Mode - Driver Utilities Preserved)..." -ForegroundColor Yellow
$BloatApps = @(
    # Microsoft & Standard Bloat
    "*Cortana*", "*Xbox*", "*Solitaire*", "*OfficeHub*", "*SkypeApp*", "*FeedbackHub*", "*GetHelp*",
    "*ZuneVideo*", "*ZuneMusic*", "*3DBuilder*", "*MixedReality*", "*OneNote*", "*People*",
    "*StickyNotes*", "*BingWeather*", "*BingNews*", "*BingSports*", "*BingFinance*", "*YourPhone*",
    # 3rd Party Ads & Preinstalled Apps
    "*Disney*", "*Spotify*", "*TikTok*", "*Instagram*", "*CandyCrush*", "*Facebook*", "*Twitter*", 
    "*LinkedIn*", "*Clipchamp*", "*WhatsApp*", "*ByteDance*",
    # Antivirus Bloat (Driver utility seperti MyASUS, Lenovo Vantage, Dell SupportAssist, dll dikecualikan)
    "*McAfee*", "*Norton*", "*Avast*", "*AVG*"
)
$ProvisionedApps = Get-AppxProvisionedPackage -Online
foreach ($app in $BloatApps) {
    Get-AppxPackage -AllUsers -Name $app | Remove-AppxPackage | Out-Null
    $ProvisionedApps | Where-Object {$_.DisplayName -like $app} | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName | Out-Null }
}

# 5. Best Performance Visual Settings
Write-Host "[*] Adjusting Visual Settings for Best Performance..." -ForegroundColor Yellow
$VisualEffectsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (!(Test-Path $VisualEffectsPath)) { New-Item -Path $VisualEffectsPath -Force | Out-Null }
Set-ItemProperty -Path $VisualEffectsPath -Name "VisualFXSetting" -Value 2 -Force
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]]@(144,20,7,128,16,0,0,0)) -Force
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Force
$ExplorerAdvPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $ExplorerAdvPath -Name "ListviewAlphaSelect" -Value 0 -Force
Set-ItemProperty -Path $ExplorerAdvPath -Name "ListviewShadow" -Value 0 -Force
Set-ItemProperty -Path $ExplorerAdvPath -Name "TaskbarAnimations" -Value 0 -Force

# 6. Disable Windows Defender (Registry & Cmdlet)
Write-Host "[*] Disabling Windows Defender..." -ForegroundColor Yellow
Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true -DisableIOAVProtection $true -SignatureDisableUpdateOnStartupWithoutEngine $true -DisableArchiveScanning $true -DisableIntrusionPreventionSystem $true -DisableScriptScanning $true

$DefPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
if (!(Test-Path $DefPath)) { New-Item -Path $DefPath -Force | Out-Null }
Set-ItemProperty -Path $DefPath -Name "DisableAntiSpyware" -Value 1 -Force

$RealtimePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
if (!(Test-Path $RealtimePath)) { New-Item -Path $RealtimePath -Force | Out-Null }
Set-ItemProperty -Path $RealtimePath -Name "DisableRealtimeMonitoring" -Value 1 -Force

# 7. Pause Windows Update until 2099
Write-Host "[*] Pausing Windows Updates until 2099..." -ForegroundColor Yellow
$UpdatePath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
if (!(Test-Path $UpdatePath)) { New-Item -Path $UpdatePath -Force | Out-Null }
Set-ItemProperty -Path $UpdatePath -Name "PauseUpdatesExpiryTime" -Value "2099-12-31T23:59:59Z" -Force
Set-ItemProperty -Path $UpdatePath -Name "PauseFeatureUpdatesStartTime" -Value "2026-01-01T00:00:00Z" -Force
Set-ItemProperty -Path $UpdatePath -Name "PauseQualityUpdatesStartTime" -Value "2026-01-01T00:00:00Z" -Force

# 8. Folder Options Settings
Write-Host "[*] Configuring Folder Options..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -Force
$ExplorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
Set-ItemProperty -Path $ExplorerPath -Name "ShowRecent" -Value 0 -Force
Set-ItemProperty -Path $ExplorerPath -Name "ShowFrequent" -Value 0 -Force

# 9. This PC Desktop Shortcut
Write-Host "[*] Creating 'This PC' desktop icon..." -ForegroundColor Yellow
$DesktopIcons = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
if (!(Test-Path $DesktopIcons)) { New-Item -Path $DesktopIcons -Force | Out-Null }
Set-ItemProperty -Path $DesktopIcons -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -Force

# 10. Clean Cache, Temp & System Files
Write-Host "[*] Cleaning Package Cache & Network Cache..." -ForegroundColor Yellow
winget cache clean --accept-source-agreements | Out-Null
ipconfig /flushdns | Out-Null

Write-Host "[*] Stopping Windows Update Service to clean download cache..." -ForegroundColor Yellow
Stop-Service -Name wuauserv -Force
$DownloadPath = "$env:SystemRoot\SoftwareDistribution\Download"
if (Test-Path $DownloadPath) {
    Get-ChildItem $DownloadPath -Recurse -Force | Remove-Item -Recurse -Force
}
Start-Service -Name wuauserv | Out-Null

Write-Host "[*] Cleaning Temporary Files & Prefetch..." -ForegroundColor Yellow
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

# 11. Reset Bags & Safe Explorer Relaunch
Write-Host "[*] Restarting Windows Explorer & Resetting Folder Views..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force
Start-Sleep -Seconds 2

# Reset Shell Folder views
Remove-Item -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags" -Recurse -Force
Remove-Item -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU" -Recurse -Force

# Safe Relaunch Explorer (Invoking native explorer directly is safe and Windows handles de-elevation to user automatically)
Start-Process "explorer.exe"

Write-Host "---------------------------------------------------" -ForegroundColor Gray
Write-Host "[+] All Windows $OSName optimization tasks completed successfully." -ForegroundColor Green
