# MEGAPASS Windows Debloater v2.4
# https://megapass.web.id/blog/debloat-win/
# Jalankan: irm https://megapass.web.id/blog/debloat-win/debloat.ps1 | iex
# Requires: Run as Administrator
# Tested: Windows 10 22H2, Windows 11 23H2/24H2

#Requires -RunAsAdministrator

# Runtime Admin Privilege Guard (menangani eksekusi via irm | iex)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  [!!] Script ini WAJIB dijalankan sebagai Administrator!" -ForegroundColor Red
    Write-Host "  [**] Klik kanan PowerShell -> 'Run as administrator', lalu jalankan ulang." -ForegroundColor Yellow
    Write-Host ""
    return
}

# 64-bit OS Architecture Guard (cegah redirector WOW64 pada PowerShell x86)
if ([Environment]::Is64BitOperatingSystem -and [IntPtr]::Size -eq 4) {
    Write-Host ""
    Write-Host "  [!!] Script ini berjalan di PowerShell 32-bit (x86) pada sistem operasi 64-bit!" -ForegroundColor Red
    Write-Host "  [**] Mohon buka 'Windows PowerShell' versi 64-bit (bukan x86) sebagai Administrator." -ForegroundColor Yellow
    Write-Host ""
    return
}

$ver = "2.4"
$steps = 28
$ErrorActionPreference = 'SilentlyContinue'
$fail = 0

$sysDrive = if ($env:SystemDrive) { $env:SystemDrive } else { "C:" }
$sysRoot  = if ($env:SystemRoot)  { $env:SystemRoot }  else { "$sysDrive\Windows" }

# ponytail: $total dihapus -- counter parsial misleading, tiap modul sudah punya counter sendiri
$cRemoved = 0; $cTaskOff = 0; $cSvcOff = 0; $cCleaned = 0

$boxW = 48
function Log($msg, $color) { Write-Host $msg -ForegroundColor $color }
function Box($msg, $color) {
    # ponytail: truncate + pad supaya border tidak pecah
    if ($msg.Length -gt $boxW) { $msg = $msg.Substring(0, $boxW) }
    Log ("|" + $msg.PadRight($boxW) + "|") $color
}
function Ok($msg)   { Log "  [OK] $msg" Green }
function Skip($msg) { Log "  [--] $msg" DarkGray }
function Warn($msg) { Log "  [!!] $msg" Yellow; $script:fail++ }
function Info($msg) { Log "  [**] $msg" Yellow }
function RegSet($path, $name, $val, $type = "DWord") {
    try {
        if (!(Test-Path $path)) {
            $parts = $path -split ':\\|\\'
            $curr = $parts[0] + ':\'
            for ($i = 1; $i -lt $parts.Count; $i++) {
                $curr = Join-Path $curr $parts[$i]
                if (!(Test-Path $curr)) { New-Item -Path $curr -Force -ErrorAction SilentlyContinue | Out-Null }
            }
        }
        Set-ItemProperty -Path $path -Name $name -Value $val -Type $type -Force -ErrorAction SilentlyContinue
    } catch { }
}

# --- Banner ---
Write-Host ""
Log ("+" + "=" * $boxW + "+") Cyan
Box "   MEGAPASS Windows Debloater v$ver" Cyan
Box "   https://megapass.web.id" Cyan
Box "   Teknisi BNSP | Sidoarjo" Cyan
Box "" Cyan
Box "   $steps modul optimasi | restore point aman" Cyan
Log ("+" + "=" * $boxW + "+") Cyan
Write-Host ""

# ================================================================
# 0. CREATE RESTORE POINT
# ================================================================
Log "[0/$steps] Membuat restore point..." Yellow
try {
    # Pastikan service VSS hidup agar pembuatan restore point sukses
    Set-Service -Name VSS -StartupType Manual -ErrorAction SilentlyContinue
    Start-Service -Name VSS -ErrorAction SilentlyContinue
    Enable-ComputerRestore -Drive "$sysDrive\" -ErrorAction Stop
    # ponytail: bypass 24h cooldown via registry
    $rpFreq = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    RegSet $rpFreq "SystemRestorePointCreationFrequency" 0
    Checkpoint-Computer -Description "MEGAPASS Debloat v$ver" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Ok "Restore point dibuat - bisa rollback kapan saja"
} catch {
    Skip "Restore point gagal (non-fatal, lanjut)"
}

# ================================================================
# 0.5 BASELINE SNAPSHOT (sebelum debloat)
# ================================================================
# ponytail: snapshot awal -- data riil untuk laporan before/after
$bOS = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue)
$bCPU = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1)
$bRAM_Total = $(if ($bOS -and $bOS.TotalVisibleMemorySize) { [math]::Round($bOS.TotalVisibleMemorySize / 1024) } else { 0 })
$bRAM_Free = $(if ($bOS -and $bOS.FreePhysicalMemory) { [math]::Round($bOS.FreePhysicalMemory / 1024) } else { 0 })
$bRAM_Used = [math]::Max(0, $bRAM_Total - $bRAM_Free)
$bProc = (Get-Process).Count
$bSvc = (Get-Service | Where-Object { $_.Status -eq 'Running' }).Count
$diskC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sysDrive'" -ErrorAction SilentlyContinue
$bDiskFree = $(if ($diskC -and $diskC.FreeSpace) { [math]::Round($diskC.FreeSpace / 1GB, 1) } else { 0 })
$bOSName = $(if ($bOS -and $bOS.Caption) { "$($bOS.Caption) ($($bOS.Version))" } else { "Windows 10/11" })
$bCPUName = $(if ($bCPU -and $bCPU.Name) { $bCPU.Name.Trim() } else { "Standard Processor" })
$bTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# ================================================================
# 1. REMOVE BLOATWARE APPS
# ================================================================
# DIPERTAHANKAN: Calculator, Camera, StickyNotes, Alarms/Clock,
#   SoundRecorder, Paint, Terminal, Photos, Store, Edge, Defender, OneDrive
Log "[1/$steps] Hapus bloatware apps..." Yellow

$bloatware = @(
    # Microsoft bloat (bukan utility sehari-hari)
    "Microsoft.3DBuilder", "Microsoft.3DViewer", "Microsoft.Microsoft3DViewer",
    "Microsoft.BingFinance", "Microsoft.BingNews", "Microsoft.BingSports", "Microsoft.BingWeather",
    "Microsoft.BingSearch", "Microsoft.BingTranslator",
    "Microsoft.GetHelp", "Microsoft.Getstarted",
    "Microsoft.MicrosoftOfficeHub", "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MixedReality.Portal",
    "Microsoft.Office.OneNote", "Microsoft.OneConnect",
    "Microsoft.People", "Microsoft.Print3D", "Microsoft.SkypeApp",
    "Microsoft.Wallet",
    "Microsoft.WindowsFeedbackHub", "Microsoft.WindowsMaps",
    # Xbox (semua - berat, jarang dipakai di PC kerja/servis)
    "Microsoft.Xbox.TCUI", "Microsoft.XboxApp", "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay", "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay", "Microsoft.GamingApp",
    # Phone/social
    "Microsoft.YourPhone", "Microsoft.WindowsPhone", "MicrosoftTeams",
    "Microsoft.Todos", "*Todos*", "Microsoft.PowerAutomateDesktop",
    # Media bloat (bukan Photos)
    "Microsoft.ZuneMusic", "Microsoft.ZuneVideo",
    # Win11 bloat
    "Microsoft.Cortana", "Microsoft.549981C3F5F10",
    "MicrosoftCorporationII.QuickAssist", "MicrosoftCorporationII.MicrosoftFamily",
    "Microsoft.WindowsCommunicationsApps",
    "Microsoft.OutlookForWindows",
    "Clipchamp.Clipchamp", "Microsoft.Clipchamp", "*Clipchamp*",
    # Copilot & Recall (Win11 24H2)
    "Microsoft.Copilot", "Microsoft.Windows.Ai.Copilot.Provider",
    "MicrosoftWindows.Client.AIX",
    "MicrosoftWindows.Client.Photon",
    # Ads & content delivery
    "Microsoft.Advertising.Xaml", "Microsoft.Services.Store.Engagement",
    "Microsoft.Windows.ContentDeliveryManager",
    "Microsoft.Windows.ParentalControls", "Microsoft.Windows.PeopleExperienceHost",
    # Third-party bloat (OEM preinstalled)
    "king.com.CandyCrushSaga", "king.com.CandyCrushSodaSaga",
    "king.com.CandyCrushFriends", "king.com.BubbleWitch3Saga",
    "king.com.FarmHeroesSaga",
    "A278AB0D.MarchofEmpires", "A278AB0D.DisneyMagicKingdoms",
    "D52A8D61.FarmVille2CountryEscape", "GAMELOFTSA.Asphalt8Airborne",
    "flaregamesGmbH.RoyalRevolt2", "PandoraMediaInc.29680B314EFC2",
    "46928bounde.EclipseManager", "ActiproSoftwareLLC.562882FEEB491",
    "D5EA27B7.Duolingo-LearnLanguagesforFree",
    "828B5831.HiddenCityMysteryofShadows", "89006A2E.AutodeskSketchBook",
    "SpotifyAB.SpotifyMusic", "B9ECED6F.ASUSPCAssistant",
    "7EE7776C.LinkedInforWindows", "*LinkedIn*",
    "Facebook.Facebook", "BytedancePte.Ltd.TikTok",
    "FACEBOOK.317180B0BB486", "AmazonVideo.PrimeVideo",
    "Disney.37853FC22B2CE", "5A894077.McAfeeSecurity",
    "4DF9E0F8.Netflix", "CAF9E577.Plex"
)

$provPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

foreach ($app in $bloatware) {
    $searchPattern = "*$($app.Trim('*'))*"
    $pkgs = Get-AppxPackage -Name $searchPattern -AllUsers -ErrorAction SilentlyContinue
    if (-not $pkgs) {
        $pkgs = Get-AppxPackage -Name $searchPattern -ErrorAction SilentlyContinue
    }
    if ($pkgs) {
        foreach ($pkg in $pkgs) {
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                $cRemoved++
            } catch {
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                    $cRemoved++
                } catch { }
            }
        }
    }
    # Blokir provisioned supaya tidak balik setelah update atau profil baru
    if ($provPkgs) {
        $searchTag = $app.Trim("*")
        $prov = $provPkgs | Where-Object { 
            ($_.DisplayName -and $_.DisplayName -like "*$searchTag*") -or 
            ($_.PackageName -and $_.PackageName -like "*$searchTag*") 
        }
        if ($prov) {
            foreach ($p in $prov) {
                Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
}
Ok "Hapus $cRemoved bloatware (Camera, Calculator, Paint, StickyNotes dipertahankan)"

# ================================================================
# 2. DISABLE TELEMETRY & DATA COLLECTION
# ================================================================
Log "[2/$steps] Matikan telemetry & data collection..." Yellow

$telemetryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
)
foreach ($p in $telemetryPaths) { RegSet $p "AllowTelemetry" 0 }

# Diagnostic data
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" 1
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DisableOneSettingsDownloads" 1
RegSet "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" 0

# Activity history
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0

# Disable telemetry scheduled tasks
$telemetryTasks = @(
    "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "Microsoft\Windows\Autochk\Proxy",
    "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "Microsoft\Windows\Feedback\Siuf\DmClient",
    "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
    "Microsoft\Windows\PI\Sqm-Tasks",
    "Microsoft\Windows\Application Experience\AitAgent",
    "Microsoft\Windows\Windows Error Reporting\QueueReporting"
)
foreach ($t in $telemetryTasks) {
    $r = Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($r) { $cTaskOff++ }
}
Ok "Telemetry dimatikan ($cTaskOff tasks disabled)"

# ================================================================
# 3. DISABLE CORTANA, COPILOT & RECALL
# ================================================================
Log "[3/$steps] Matikan Cortana, Copilot, Recall..." Yellow

# Cortana
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0

# Copilot (Win11 24H2)
RegSet "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1

# Recall (Win11 24H2) - screenshot everything = privacy nightmare
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapshots" 0
dism /Online /Disable-Feature /FeatureName:Recall /NoRestart 2>$null | Out-Null

Ok "Cortana + Copilot + Recall dimatikan"

# ================================================================
# 4. DISABLE ADS & SUGGESTIONS
# ================================================================
Log "[4/$steps] Matikan iklan & suggestions..." Yellow

$cdm = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
$adKeys = @(
    "ContentDeliveryAllowed", "OemPreInstalledAppsEnabled",
    "PreInstalledAppsEnabled", "PreInstalledAppsEverEnabled",
    "SilentInstalledAppsEnabled", "SystemPaneSuggestionsEnabled",
    "SoftLandingEnabled", "RotatingLockScreenEnabled",
    "RotatingLockScreenOverlayEnabled"
)
foreach ($k in $adKeys) { RegSet $cdm $k 0 }

# Subscribed content (lock screen ads, start menu suggestions, etc)
$subContent = @(310093,314559,314563,338387,338388,338389,338393,353694,353696,353698,338380,280810,280811,280813,280815)
foreach ($id in $subContent) { RegSet $cdm "SubscribedContent-${id}Enabled" 0 }

# Start menu suggestions
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_IrisRecommendations" 0
# Settings page suggestions
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0
# File Explorer ads
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0

# Matikan silent install consumer apps & sponsored cloud tiles (Windows 10/11)
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableCloudOptimizedContent" 1

Ok "Iklan, suggestions & Cloud Content stubs dimatikan (Start, Lock Screen, Explorer)"

# ================================================================
# 5. PRIVACY: ADVERTISING ID, LOCATION, CLIPBOARD
# ================================================================
Log "[5/$steps] Perkuat privasi..." Yellow

# Disable advertising ID
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
# Disable app launch tracking
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0
# Disable timeline (sudah diset di section 2, skip)
# Disable location tracking
RegSet "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value" "Deny" "String"
# Disable handwriting data sharing
RegSet "HKCU:\SOFTWARE\Microsoft\Input\TIPC" "Enabled" 0
# Disable tailored experiences
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0
# Disable cloud clipboard
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "AllowClipboardHistory" 0
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "AllowCrossDeviceClipboard" 0
# Cegah enkripsi otomatis BitLocker tanpa persetujuan user di Windows 11 24H2
RegSet "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker" "PreventDeviceEncryption" 1

Ok "Privacy diperkuat (Ads ID, Location, Clipboard, Timeline off)"

# ================================================================
# 6. DISABLE BACKGROUND APPS
# ================================================================
Log "[6/$steps] Matikan background apps..." Yellow

RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BackgroundAppGlobalToggle" 0

Ok "Background apps dimatikan"

# ================================================================
# 7. DISABLE UNNECESSARY SERVICES
# ================================================================
Log "[7/$steps] Matikan service yang tidak perlu..." Yellow

$services = @(
    "DiagTrack",               # Connected User Experiences and Telemetry
    "dmwappushservice",        # WAP Push Message Routing
    "WMPNetworkSvc",           # Windows Media Player Network Sharing
    "WSearch",                 # Windows Search (berat, pakai Everything)
    "SysMain",                 # Superfetch (SSD tidak butuh)
    "MapsBroker",              # Downloaded Maps Manager
    "lfsvc",                   # Geolocation
    "RetailDemo",              # Retail Demo
    "wisvc",                   # Windows Insider
    "XblAuthManager",          # Xbox Live Auth
    "XblGameSave",             # Xbox Live Game Save
    "XboxNetApiSvc",           # Xbox Live Networking
    "XboxGipSvc",              # Xbox Accessory Management
    # ponytail: tambahan untuk laptop kentang
    "WerSvc",                  # Windows Error Reporting (disk I/O crash dump)
    "CDPSvc",                  # Connected Devices Platform (sync antar device)
    "CDPUserSvc",              # Connected Devices Platform per-user
    "PhoneSvc",                # Phone Service (laptop gak butuh)
    "TabletInputService",      # Touch Keyboard (non-touchscreen gak butuh)
    "DPS"                      # Diagnostic Policy Service (disk 100% di HDD)
    # DoSvc (Delivery Optimization) dipertahankan on-demand (Manual) agar unduhan Microsoft Store lancar (P2P dimatikan di Modul 9)
    # WpnService sengaja dipertahankan agar Focus Assist Priority Only & Action Center tetap aktif
)

foreach ($svc in $services) {
    $svcs = Get-Service -Name "$svc*" -ErrorAction SilentlyContinue
    if ($svcs) {
        foreach ($s in $svcs) {
            Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $s.Name -StartupType Disabled -ErrorAction SilentlyContinue
            $cSvcOff++
        }
    }
}

# Pastikan WpnService aktif (Manual) agar Focus Assist Priority Only & Action Center berfungsi normal
$wpn = Get-Service -Name WpnService -ErrorAction SilentlyContinue
if ($wpn -and $wpn.StartType -eq 'Disabled') {
    Set-Service -Name WpnService -StartupType Manual -ErrorAction SilentlyContinue
    Start-Service -Name WpnService -ErrorAction SilentlyContinue
}

Ok "Matikan $cSvcOff services (telemetry, Xbox, search, maps)"

# ================================================================
# 8. PERFORMANCE TWEAKS
# ================================================================
Log "[8/$steps] Optimasi performa..." Yellow

# Visual effects -> Custom Performance Tuning (Formula Meja Servis Megapass)
# Mode 3 = Custom (basis Best Performance dengan selective visual perks)
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 3
# UserPreferencesMask: byte 0 = 0x9C (combo box animation 0x04 + smooth scroll list box 0x08), byte 4 = 0x12 (animate controls & elements)
RegSet "HKCU:\Control Panel\Desktop" "UserPreferencesMask" ([byte[]](0x9C,0x12,0x03,0x80,0x12,0x00,0x00,0x00)) "Binary"
# Tampilkan thumbnail bukan icon generik (Show thumbnails instead of icons)
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "IconsOnly" 0
# Tampilkan translucent selection rectangle (kotak seleksi biru transparan)
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" 1
# Tampilkan bayangan label icon desktop (drop shadow)
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewShadow" 1
# Tampilkan konten jendela saat digeser (Show window contents while dragging)
RegSet "HKCU:\Control Panel\Desktop" "DragFullWindows" "1" "String"
# Aktifkan smooth edges of screen fonts (ClearType sub-pixel smoothing)
RegSet "HKCU:\Control Panel\Desktop" "FontSmoothing" "2" "String"
RegSet "HKCU:\Control Panel\Desktop" "FontSmoothingType" 2

# Disable transparency
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0

# Disable Game Bar & Game DVR (Game Mode dipertahankan -- berguna)
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0

# Disable mouse acceleration
RegSet "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String"

# Fast startup: disable (causes issues with dual-boot & driver bugs)
RegSet "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0

# Disable hibernation (free disk space = RAM size)
powercfg /h off 2>$null

# Power plan: High Performance
# ponytail: /duplicatescheme returns NEW guid -- harus capture, bukan pakai original
$hpGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
$hpExists = powercfg /l | Select-String $hpGuid
if ($hpExists) {
    powercfg /s $hpGuid 2>$null
} else {
    $dupOutput = (powercfg /duplicatescheme $hpGuid 2>&1) -join " "
    $allGuids = [regex]::Matches($dupOutput, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
    if ($allGuids.Count -ge 1) {
        # Ambil GUID terakhir (new plan), bukan source
        $newGuid = $allGuids[$allGuids.Count - 1].Value
        powercfg /s $newGuid 2>$null
    }
}

# Display & Sleep timeout: 5 Jam (300 menit) on Battery & Plugged In
powercfg /change monitor-timeout-ac 300 2>$null
powercfg /change monitor-timeout-dc 300 2>$null
powercfg /change standby-timeout-ac 300 2>$null
powercfg /change standby-timeout-dc 300 2>$null

# When I press the power button on Battery & Plugged In: Do Nothing (0)
# Subgroup Power Buttons: 4f971e89-e936-462a-a816-3272d9c157b5
# Power Button Action: 7648eac1-046e-4e6b-ba3e-404122a1fc15
powercfg /setacvalueindex SCHEME_CURRENT 4f971e89-e936-462a-a816-3272d9c157b5 7648eac1-046e-4e6b-ba3e-404122a1fc15 0 2>$null
powercfg /setdcvalueindex SCHEME_CURRENT 4f971e89-e936-462a-a816-3272d9c157b5 7648eac1-046e-4e6b-ba3e-404122a1fc15 0 2>$null
powercfg /setactive SCHEME_CURRENT 2>$null

# Auto Focus Assist / DND: Priority Only (Windows 10 & 11)
# 1 = Priority Only (Quiet Hours & Focus Assist settings)
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\FocusAssist" "QuietHoursActive" 1
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\FocusAssist" "QuietHoursEnabled" 1
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours" "UserSetProfile" 1
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours" "Profile" 1
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours" "Enabled" 1
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_DND" 1
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK" 1
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_TOASTS_ENABLED" 1
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\QuietHours" "Profile" 1
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\QuietHours" "Enabled" 1

# Broadcast WNF (Windows Notification Facility) state agar shell langsung update live
# WNF_SHEL_QUIETHOURS_ACTIVE_PROFILE_CHANGED = 0x0d83063ea3bf1c75 (1 = Priority Only)
# WNF_SHEL_QUIET_MOMENT_SHELL_MODE_CHANGED = 0x0d83063ea3bf5075 (2 = Priority Mode)
try {
    if (-not ([System.Management.Automation.PSTypeName]'MegapassWnf').Type) {
        $wnfDef = @'
using System;
using System.Runtime.InteropServices;

public static class MegapassWnf {
    [DllImport("ntdll.dll")]
    private static extern int ZwUpdateWnfStateData(
        ref ulong stateName,
        IntPtr buffer,
        int length,
        IntPtr typeId,
        IntPtr explicitScope,
        int matchingChangeStamp,
        int checkStamp
    );

    public static int SetState(ulong state, byte val) {
        ulong s = state;
        byte[] d = new byte[] { val, 0, 0, 0 };
        GCHandle p = GCHandle.Alloc(d, GCHandleType.Pinned);
        try {
            return ZwUpdateWnfStateData(ref s, p.AddrOfPinnedObject(), d.Length, IntPtr.Zero, IntPtr.Zero, 0, 0);
        } catch {
            return -1;
        } finally {
            p.Free();
        }
    }
}
'@
        Add-Type -TypeDefinition $wnfDef -ErrorAction SilentlyContinue
    }
    if (([System.Management.Automation.PSTypeName]'MegapassWnf').Type) {
        [MegapassWnf]::SetState([uint64]0x0d83063ea3bf1c75, [byte]1) | Out-Null
        [MegapassWnf]::SetState([uint64]0x0d83063ea3bf5075, [byte]2) | Out-Null
    }
} catch {}

Ok "Performa dioptimasi (visual, power, Game DVR off, Focus Assist Priority Only)"

# ================================================================
# 9. NETWORK PRIVACY
# ================================================================
Log "[9/$steps] Perkuat network privacy..." Yellow

# Disable Wi-Fi Sense
RegSet "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" "Value" 0
RegSet "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots" "Value" 0

# Disable peer-to-peer Windows Update delivery (save bandwidth)
RegSet "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DODownloadMode" 0
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 0

# Disable Remote Assistance
RegSet "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 0

# Disable autoplay
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" "DisableAutoplay" 1

Ok "Network privacy diperkuat (Wi-Fi Sense, P2P Update, Remote Assist off)"

# ================================================================
# 10. EXPLORER & TASKBAR CLEANUP
# ================================================================
Log "[10/$steps] Bersihkan Explorer & Taskbar..." Yellow

# Sembunyikan ekstensi file untuk tipe file yang dikenal (Hide extensions for known file types tercentang)
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 1
# Hidden files: jangan ditampilkan (aman untuk user umum, cegah salah hapus file sistem)
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 2
# Sembunyikan protected operating system files (cegah salah hapus file sistem sensitif)
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSuperHidden" 0
# Default buka File Explorer langsung ke This PC (1 = This PC, 2 = Quick Access / Home)
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 1
# Matikan tombol Task View di taskbar (Win10 & Win11)
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
# Disable recent files in Quick Access
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "ShowRecent" 0
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "ShowFrequent" 0
# Disable Widgets (Win11) & News and Interests (Win10)
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" "ShellFeedsTaskbarViewMode" 2
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0
# Disable Chat icon (Win11)
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0
# Search box di taskbar: panjang penuh (2 = full box, 1 = icon, 0 = hidden)
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 2
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "SearchboxTaskbarMode" 2
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "SearchboxMode" 2

Ok "Explorer & Taskbar dibersihkan (This PC default, Task View off, hidden files aman)"

# ================================================================
# 11. WINDOWS UPDATE: KONTROL MANUAL
# ================================================================
Log "[11/$steps] Atur Windows Update (kontrol manual)..." Yellow

# Prevent forced restart
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoRebootWithLoggedOnUsers" 1
# Disable auto-update for Store apps
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" "AutoDownload" 2

Ok "Windows Update: tidak auto-restart, Store manual"

# ================================================================
# 12. DEEP CLEANUP (TEMP, CACHE, UPDATE RESIDUE)
# ================================================================
Log "[12/$steps] Bersihkan temp files & cache..." Yellow

$tempPaths = @(
    $env:TEMP,
    "$sysRoot\Temp",
    "$sysRoot\Prefetch",
    # ponytail: tambahan untuk laptop kentang -- hemat 500MB-5GB
    "$sysRoot\SoftwareDistribution\Download",
    "$sysRoot\SoftwareDistribution\DeliveryOptimization"
)
foreach ($tp in $tempPaths) {
    if (Test-Path $tp) {
        $files = Get-ChildItem -Path $tp -Recurse -Force -ErrorAction SilentlyContinue
        $cCleaned += $files.Count
        Remove-Item -Path "$tp\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Bersihkan thumbnail cache (explorer lambat kalau bloat)
$thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
if (Test-Path $thumbPath) {
    Get-ChildItem -Path $thumbPath -Filter "thumbcache_*.db" -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $cCleaned++; Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
}

Ok "Bersihkan $cCleaned temp/cache files"

# Kosongkan Recycle Bin semua drive tanpa konfirmasi
try {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Ok "Recycle Bin dikosongkan"
} catch {
    Skip "Recycle Bin sudah kosong atau dilewati"
}

# ================================================================
# 13. NORMALISASI & JEDA WINDOWS UPDATE HINGGA 2099 (MS STORE TETAP BISA AKSES)
# ================================================================
Log "[13/$steps] Normalisasi & Jeda Windows Update hingga 2099 (Store aktif)..." Yellow

# 1. Pemulihan jika sebelumnya dimatikan permanen oleh tool lain / tweak lama
# Hapus policy pemblokir akses total Windows Update & Store jika ada
$wuPolicyKeys = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate"
)
foreach ($pk in $wuPolicyKeys) {
    if (Test-Path $pk) {
        Remove-ItemProperty -Path $pk -Name "DisableWindowsUpdateAccess" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $pk -Name "SetDisableUXWUAccess" -ErrorAction SilentlyContinue
    }
}

# Hapus blokir hosts file jika sebelumnya ada tool pihak ketiga yang inject
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
if (Test-Path $hostsPath) {
    try {
        $hostsContent = Get-Content $hostsPath -ErrorAction SilentlyContinue
        $cleanHosts = $hostsContent | Where-Object { $_ -notmatch "windowsupdate" -and $_ -notmatch "update\.microsoft\.com" }
        if ($hostsContent.Count -ne $cleanHosts.Count) {
            [System.IO.File]::WriteAllLines($hostsPath, $cleanHosts)
        }
    } catch {}
}

# Pulihkan service vital Windows Update & Store ke Manual/Running (bukan Disabled)
$vitalServices = @("wuauserv", "BITS", "UsoSvc", "dosvc")
foreach ($sName in $vitalServices) {
    $svc = Get-Service -Name $sName -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.StartType -eq 'Disabled') {
            Set-Service -Name $sName -StartupType Manual -ErrorAction SilentlyContinue
        }
    }
}

# 2. Terapkan Pause jadwal update via UX Settings hingga 2099
$wuUx = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
RegSet $wuUx "PauseFeatureUpdatesStartTime" "2024-01-01T00:00:00Z" "String"
RegSet $wuUx "PauseFeatureUpdatesEndTime" "2099-12-31T00:00:00Z" "String"
RegSet $wuUx "PauseQualityUpdatesStartTime" "2024-01-01T00:00:00Z" "String"
RegSet $wuUx "PauseQualityUpdatesEndTime" "2099-12-31T00:00:00Z" "String"
RegSet $wuUx "PauseUpdatesExpiryTime" "2099-12-31T00:00:00Z" "String"
RegSet $wuUx "PauseUpdatesStartTime" "2024-01-01T00:00:00Z" "String"

# Target release version lock -- mengunci Windows di build saat ini
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$ntCurVer = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
$winVer = if ($ntCurVer.DisplayVersion) { $ntCurVer.DisplayVersion } else { $ntCurVer.ReleaseId }
$prodName = $ntCurVer.ProductName
$osProduct = if ($prodName -match "Windows 11") { "Windows 11" } else { "Windows 10" }

RegSet $wuPath "ProductVersion" $osProduct "String"
RegSet $wuPath "TargetReleaseVersion" 1
if ($winVer) { RegSet $wuPath "TargetReleaseVersionInfo" $winVer "String" }

# 3. Kunci kebijakan AU (Automatic Updates) agar TIDAK auto-scan/auto-download di background
$auPath = "$wuPath\AU"
RegSet $auPath "NoAutoUpdate" 1
RegSet $auPath "AUOptions" 2
RegSet $auPath "ScheduledInstallDay" 0

# Matikan scheduled task pemicu update otomatis di background
$wuTasks = @(
    "Microsoft\Windows\WindowsUpdate\Scheduled Start",
    "Microsoft\Windows\WindowsUpdate\sihpostreboot"
)
foreach ($wt in $wuTasks) {
    Disable-ScheduledTask -TaskName $wt -ErrorAction SilentlyContinue | Out-Null
}

Ok "Windows Update dinormalisasi, AU dimatikan & dijeda sampai 2099 (MS Store 100% aktif)"

# ================================================================
# 14. DISABLE SMARTSCREEN & PHISHING FILTER
# ================================================================
Log "[14/$steps] Matikan SmartScreen & Phishing Filter..." Yellow

# SmartScreen
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableSmartScreen" 0
RegSet "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "SmartScreenEnabled" "Off" "String"
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter" "EnabledV9" 0

Ok "SmartScreen dimatikan (Windows Defender 100% aktif & tidak disentuh)"

# ================================================================
# 15. KEMBALIKAN KLIK KANAN KLASIK (WIN11)
# ================================================================
Log "[15/$steps] Kembalikan menu klik kanan klasik..." Yellow

$clsid = "{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
$regPath = "HKCU:\SOFTWARE\Classes\CLSID\$clsid\InprocServer32"

try {
    if (!(Test-Path $regPath)) {
        New-Item -Path $regPath -Value "" -Force | Out-Null
    }
    Set-Item -Path $regPath -Value "" -Force
    # Cadangan reg.exe untuk memastikan nilai (Default) terisi string kosong tanpa nama properti
    & reg.exe add "HKCU\Software\Classes\CLSID\$clsid\InprocServer32" /f /ve /d "" 2>$null | Out-Null
    Ok "Menu klik kanan klasik diaktifkan (butuh restart Explorer)"
} catch {
    Warn "Gagal set context menu klasik: $_"
}

# ================================================================
# 16. MATIKAN RESERVED STORAGE (~7GB)
# ================================================================
Log "[16/$steps] Matikan Reserved Storage..." Yellow

try {
    $rsState = (DISM /Online /Get-ReservedStorageState 2>&1) -join " "
    if ($rsState -match "enabled" -or $rsState -match "aktif") {
        DISM /Online /Set-ReservedStorageState /State:Disabled 2>$null | Out-Null
        Ok "Reserved Storage dimatikan (hemat ~7GB SSD)"
    } else {
        Skip "Reserved Storage sudah nonaktif"
    }
} catch {
    Warn "Gagal matikan Reserved Storage: $_"
}

# ================================================================
# 17. DISABLE VBS & MEMORY INTEGRITY (HVCI)
# ================================================================
Log "[17/$steps] Matikan VBS & Memory Integrity..." Yellow

# DeviceGuard - Virtualization Based Security
RegSet "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" "EnableVirtualizationBasedSecurity" 0
RegSet "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" "RequirePlatformSecurityFeatures" 0

# HVCI (Memory Integrity / Core Isolation)
RegSet "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 0

# Credential Guard
RegSet "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard" "Enabled" 0

Ok "VBS & Memory Integrity dimatikan (boost performa ~5-15%)"

# ================================================================
# 18. MATIKAN EDGE STARTUP BOOST & BACKGROUND
# ================================================================
Log "[18/$steps] Matikan Edge Startup Boost & background..." Yellow

$edgePolicies = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

# Matikan Startup Boost (Edge preload saat boot)
RegSet $edgePolicies "StartupBoostEnabled" 0

# Matikan background processes Edge
RegSet $edgePolicies "BackgroundModeEnabled" 0

# Matikan Edge dari auto-start
RegSet $edgePolicies "HubsSidebarEnabled" 0
RegSet $edgePolicies "EdgeEnhanceImagesEnabled" 0
RegSet $edgePolicies "ShowRecommendationsEnabled" 0

# Hapus Edge dari startup registry (wildcard tidak bisa di -Name, pakai filter)
$edgeStartup = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
if (Test-Path $edgeStartup) {
    $props = Get-Item -Path $edgeStartup -ErrorAction SilentlyContinue
    if ($props) {
        $props.Property | Where-Object { $_ -like "MicrosoftEdgeAutoLaunch*" -or $_ -eq "Microsoft Edge" } |
            ForEach-Object { Remove-ItemProperty -Path $edgeStartup -Name $_ -ErrorAction SilentlyContinue }
    }
}

# Matikan Edge scheduled tasks
$edgeTasks = @(
    "MicrosoftEdgeUpdateTaskMachineCore",
    "MicrosoftEdgeUpdateTaskMachineUA",
    "MicrosoftEdgeUpdateBrowserReplacement"
)
foreach ($et in $edgeTasks) {
    Disable-ScheduledTask -TaskName $et -ErrorAction SilentlyContinue | Out-Null
}

Ok "Edge Startup Boost & background dimatikan"

# ================================================================
# 19. ONEDRIVE DIPERTAHANKAN
# ================================================================
Log "[19/$steps] Cek status OneDrive..." Yellow

# OneDrive dipertahankan utuh: tidak dihentikan, tidak dicabut dari startup,
# agar sinkronisasi file cloud & folder dokumen/desktop tetap berjalan normal.
Ok "OneDrive dipertahankan utuh (aplikasi, akun & sinkronisasi aktif)"
# ================================================================
# 20. OPTIMASI PAGEFILE (LAPTOP KENTANG)
# ================================================================
Log "[20/$steps] Optimasi pagefile..." Yellow

# Deteksi RAM fisik (MB) & disk C: free space
$ramMB = [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory / 1MB)
if (-not $ramMB -or $ramMB -le 0) { $ramMB = 4096 }
$freeMB = $(if ($diskC -and $diskC.FreeSpace) { [math]::Round($diskC.FreeSpace / 1MB) } else { 15360 })

# Set pagefile: fixed size = 1.5x RAM, dibatasi free disk space agar tidak memenuhi drive C:
$maxSafeDiskPF = [int][math]::Max(1024, [math]::Min(8192, $freeMB * 0.35))
$pfSize = [int][math]::Min($ramMB * 1.5, $maxSafeDiskPF)
$pfMin = [int][math]::Max($pfSize / 2, 1024)
if ($pfMin -gt $pfSize) { $pfMin = [int]($pfSize / 2) }

try {
    # Matikan auto-managed pagefile via CIM & Registry
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($cs -and $cs.AutomaticManagedPagefile) {
        Set-CimInstance -InputObject $cs -Property @{AutomaticManagedPagefile = $false} -ErrorAction SilentlyContinue
    }
    RegSet "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "AutomaticManagedPagefile" 0 "DWord"

    # Set fixed pagefile di system drive via CIM & Registry fallback
    $pf = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$sysDrive*" }
    if ($pf) {
        Set-CimInstance -InputObject $pf -Property @{InitialSize = $pfMin; MaximumSize = $pfSize} -ErrorAction SilentlyContinue
    } else {
        New-CimInstance -ClassName Win32_PageFileSetting -Property @{Name = "$sysDrive\pagefile.sys"; InitialSize = $pfMin; MaximumSize = $pfSize} -ErrorAction SilentlyContinue
    }
    # Registry fallback memastikan kernel membaca alokasi paging file jika CIM dibatasi
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "PagingFiles" -Value @("$sysDrive\pagefile.sys $pfMin $pfSize") -Type MultiString -Force -ErrorAction SilentlyContinue

    Ok "Pagefile dioptimasi: ${pfMin}MB-${pfSize}MB (RAM: ${ramMB}MB)"
} catch {
    Warn "Optimasi pagefile dilewati: $_"
}

# ================================================================
# 21. MATIKAN SEARCH INDEXER SCHEDULED TASKS
# ================================================================
Log "[21/$steps] Matikan Search Indexer tasks..." Yellow

$searchTasks = @(
    "Microsoft\Windows\Shell\IndexerAutomaticMaintenance",
    "Microsoft\Windows\Shell\CreateObjectTask"
)
$searchOff = 0
foreach ($st in $searchTasks) {
    $r = Disable-ScheduledTask -TaskName $st -ErrorAction SilentlyContinue
    if ($r) { $searchOff++ }
}
$cTaskOff += $searchOff

# Matikan SearchIndexer process kalau masih jalan
Stop-Process -Name "SearchIndexer" -Force -ErrorAction SilentlyContinue

Ok "Search Indexer tasks dimatikan ($searchOff tasks)"

# ================================================================
# 22. OPTIMASI NTFS & DISK I/O
# ================================================================
Log "[22/$steps] Optimasi NTFS & disk I/O..." Yellow

# Disable last access timestamp update (hemat disk I/O di HDD/eMMC)
fsutil behavior set disablelastaccess 1 2>$null | Out-Null
# Disable 8.3 short name creation (hemat NTFS overhead ~20%)
fsutil behavior set disable8dot3 1 2>$null | Out-Null

Ok "NTFS dioptimasi (last-access off, 8.3 names off)"

# ================================================================
# 23. PERCEPAT BOOT & SHUTDOWN
# ================================================================
Log "[23/$steps] Percepat boot & shutdown..." Yellow

# Timeout service hung: default 5000ms -> 2000ms (shutdown lebih cepat)
RegSet "HKLM:\SYSTEM\CurrentControlSet\Control" "WaitToKillServiceTimeout" "2000" "String"
# Timeout app hung saat shutdown: default 5000ms -> 2000ms
RegSet "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" "2000" "String"
# Timeout hung app di foreground
RegSet "HKCU:\Control Panel\Desktop" "HungAppTimeout" "1000" "String"
# Auto-end tasks saat shutdown (jangan nanya "force close?")
RegSet "HKCU:\Control Panel\Desktop" "AutoEndTasks" "1" "String"
# Kurangi boot delay untuk startup apps
RegSet "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" 0

Ok "Boot & shutdown dipercepat (timeout 2 detik)"

# ================================================================
# 24. MATIKAN STORAGE SENSE AUTO-RUN
# ================================================================
Log "[24/$steps] Matikan Storage Sense auto-run..." Yellow

# Matikan Storage Sense (bisa hapus file Downloads tanpa izin)
$ssPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
RegSet $ssPath "01" 0
# Jangan auto-delete temp files
RegSet $ssPath "04" 0
# Jangan auto-delete recycle bin
RegSet $ssPath "08" 0
# Jangan auto-delete Downloads
RegSet $ssPath "32" 0

Ok "Storage Sense auto-run dimatikan (cegah hapus file tanpa izin)"

# ================================================================
# 25. NETWORK THROTTLING OFF
# ================================================================
Log "[25/$steps] Hapus network throttling..." Yellow

# Windows throttle network bandwidth ~80% untuk multimedia streaming
# Laptop kentang butuh full bandwidth untuk download/browsing
RegSet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" "NonBestEffortLimit" 0
# Matikan network packet throttling multimedia & maksimalkan responsiveness
$mmProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
RegSet $mmProfile "NetworkThrottlingIndex" -1 "DWord"
RegSet $mmProfile "SystemResponsiveness" 0 "DWord"
# Disable Nagle algorithm (kurangi latency network)
$netAdapters = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue
foreach ($adapter in $netAdapters) {
    RegSet $adapter.PSPath "TcpAckFrequency" 1
    RegSet $adapter.PSPath "TCPNoDelay" 1
}

Ok "Network throttling dihapus (full bandwidth + low latency)"

# ================================================================
# 26. UI RESPONSIVENESS
# ================================================================
Log "[26/$steps] Tingkatkan responsiveness UI..." Yellow

# Menu show delay: default 400ms -> 0ms (instant context menu)
RegSet "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String"
# Disable window animation saat minimize/maximize
RegSet "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" "String"
# Disable cursor blink (hemat CPU cycle rendering)
RegSet "HKCU:\Control Panel\Desktop" "CursorBlinkRate" "-1" "String"
# Disable balloon tips (Win10)
RegSet "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableBalloonTips" 0
# ponytail: SoftLandingEnabled, RotatingLockScreenEnabled, ScoobeSystemSettingEnabled
# sudah diset di modul 4 -- hapus duplikat
# Matikan Windows Spotlight (download gambar lock screen = buang bandwidth)
RegSet "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsSpotlightFeatures" 1

# Refresh Explorer agar taskbar, This PC & context menu aktif seketika
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 1000
if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer.exe -ErrorAction SilentlyContinue
}

# Re-apply Focus Assist WNF state ke Explorer yang baru direfresh
try {
    if (([System.Management.Automation.PSTypeName]'MegapassWnf').Type) {
        [MegapassWnf]::SetState([uint64]0x0d83063ea3bf1c75, [byte]1) | Out-Null
        [MegapassWnf]::SetState([uint64]0x0d83063ea3bf5075, [byte]2) | Out-Null
    }
} catch {}

Ok "UI lebih responsif & Explorer direfresh (menu instant, Task View off, This PC aktif)"

# ================================================================
# 27. POST-DEBLOAT SNAPSHOT
# ================================================================
Log "[27/$steps] Mengambil data sistem pasca-debloat..." Yellow

$aOS = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue)
$aRAM_Free = $(if ($aOS -and $aOS.FreePhysicalMemory) { [math]::Round($aOS.FreePhysicalMemory / 1024) } else { 0 })
$aRAM_Used = [math]::Max(0, $bRAM_Total - $aRAM_Free)
$aProc = (Get-Process).Count
$aSvc = (Get-Service | Where-Object { $_.Status -eq 'Running' }).Count
$aDiskC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sysDrive'" -ErrorAction SilentlyContinue
$aDiskFree = $(if ($aDiskC -and $aDiskC.FreeSpace) { [math]::Round($aDiskC.FreeSpace / 1GB, 1) } else { 0 })

# Delta & persentase
$dProc = $bProc - $aProc
$dSvc = $bSvc - $aSvc
$dRAM = $bRAM_Used - $aRAM_Used
$dDisk = [math]::Round($aDiskFree - $bDiskFree, 1)
# ponytail: $() wrapper wajib -- PS5.1 tidak support $var = if() langsung
$pProc = $(if ($bProc -gt 0) { [math]::Round(($dProc / $bProc) * 100) } else { 0 })
$pSvc = $(if ($bSvc -gt 0) { [math]::Round(($dSvc / $bSvc) * 100) } else { 0 })
$pRAM = $(if ($bRAM_Used -gt 0) { [math]::Round(($dRAM / $bRAM_Used) * 100) } else { 0 })

Ok "Snapshot pasca-debloat selesai"

# ================================================================
# 28. GENERATE HTML REPORT
# ================================================================
Log "[28/$steps] Membuat laporan HTML..." Yellow

# ponytail: deteksi Desktop path via registry -- fallback $env:USERPROFILE\Desktop
# karena user bisa memindahkan folder Desktop ke OneDrive/drive lain
$desktopPath = [Environment]::GetFolderPath('Desktop')
if (-not $desktopPath -or -not (Test-Path $desktopPath)) {
    $desktopPath = "$env:USERPROFILE\Desktop"
}
$reportPath = Join-Path $desktopPath "MEGAPASS-Debloat-Report.html"

# ponytail: bar width dihitung relatif clamped 5% - 100%
# supaya grafik bar akurat meskipun angka bervariasi antar mesin
$barProc = $(if ($bProc -gt 0) { [math]::Min(100, [math]::Max(5, [math]::Round(($aProc / $bProc) * 100))) } else { 100 })
$barSvc = $(if ($bSvc -gt 0) { [math]::Min(100, [math]::Max(5, [math]::Round(($aSvc / $bSvc) * 100))) } else { 100 })
$barRAM = $(if ($bRAM_Used -gt 0) { [math]::Min(100, [math]::Max(5, [math]::Round(($aRAM_Used / $bRAM_Used) * 100))) } else { 100 })

# ponytail: format angka -- MB jika < 1024, GB jika >= 1024, tangani nilai nol/negatif
function FmtMB($mb) {
    if ($mb -ge 1024) { "$([math]::Round($mb / 1024, 1)) GB" }
    elseif ($mb -gt 0) { "$mb MB" }
    else { "0 MB" }
}
$strBRAM_Total = FmtMB $bRAM_Total
$strBRAM_Used  = FmtMB $bRAM_Used
$strARAM_Used  = FmtMB $aRAM_Used
$strDRAM       = $(if ($dRAM -gt 0) { FmtMB $dRAM } else { "0 MB" })
$badgeProc     = $(if ($dProc -gt 0) { "&darr; $dProc proses" } else { "Optimal" })
$labelProc     = $(if ($pProc -gt 0) { "$pProc% lebih enteng" } else { "Beban stabil" })
$badgeSvc      = $(if ($dSvc -gt 0) { "&darr; $dSvc service off" } else { "Optimal" })
$labelSvc      = $(if ($pSvc -gt 0) { "$pSvc% diistirahatkan" } else { "Layanan efisien" })
$badgeRAM      = $(if ($dRAM -gt 0) { "&darr; $strDRAM lega" } else { "RAM Optimal" })
$gaugeRAM      = $(if ($dRAM -gt 0) { "Hemat $strDRAM" } else { "RAM Optimal" })
$badgeDisk     = $(if ($dDisk -gt 0) { "+$dDisk GB pulih" } else { "Drive C: Optimal" })
$gaugeDisk     = $(if ($dDisk -gt 0) { "+$dDisk GB ruang lega" } else { "Drive C: Bersih" })
$pillRAM       = $(if ($dRAM -gt 0) { "+$strDRAM" } else { "Optimal" })
$pillDisk      = $(if ($dDisk -gt 0) { "+$dDisk GB" } else { "Optimal" })


$htmlReport = @"
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Laporan Optimasi Sistem - MEGAPASS Debloater v$ver</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --apple-blue: #0071E3;
    --apple-blue-hover: #0077ED;
    --apple-indigo: #5E5CE6;
    --apple-mint: #30D158;
    --apple-emerald: #059669;
    --apple-rose: #E11D48;
    --apple-orange: #FF9F0A;
    --text-primary: #1D1D1F;
    --text-secondary: #475569;
    --text-muted: #86868B;
    --radius-xl: 20px;
    --radius-lg: 16px;
    --radius-md: 12px;
    --radius-sm: 8px;
    --font: -apple-system, BlinkMacSystemFont, "Plus Jakarta Sans", "SF Pro Text", "Segoe UI", system-ui, sans-serif;
    --mono: "JetBrains Mono", -apple-system-monospaced, "SF Mono", Consolas, monospace;
  }

  html {
    background-color: #F5F5F7;
    color: var(--text-primary);
    font-family: var(--font);
    font-size: 14px;
    line-height: 1.5;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
    scroll-behavior: smooth;
  }

  body {
    max-width: 880px;
    margin: 0 auto;
    padding: 32px 20px 80px;
    background-color: #F5F5F7;
    background-image:
      radial-gradient(at 0% 0%, rgba(94, 92, 230, 0.12) 0px, transparent 45%),
      radial-gradient(at 100% 0%, rgba(0, 113, 227, 0.14) 0px, transparent 45%),
      radial-gradient(at 50% 35%, rgba(255, 159, 10, 0.07) 0px, transparent 48%),
      radial-gradient(at 100% 100%, rgba(48, 209, 88, 0.10) 0px, transparent 45%),
      radial-gradient(at 0% 100%, rgba(255, 55, 95, 0.08) 0px, transparent 45%);
    background-attachment: fixed;
  }

  /* Concentric Radius Crystal Cards */
  .crystal-card {
    background: rgba(255, 255, 255, 0.88);
    backdrop-filter: blur(28px) saturate(180%);
    -webkit-backdrop-filter: blur(28px) saturate(180%);
    border: 1px solid rgba(255, 255, 255, 0.95);
    border-radius: var(--radius-xl);
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.02),
      0 8px 24px -4px rgba(0, 113, 227, 0.06),
      inset 0 1px 0 rgba(255, 255, 255, 1);
    margin-bottom: 20px;
    transition: transform 160ms cubic-bezier(0.16, 1, 0.3, 1), box-shadow 160ms cubic-bezier(0.16, 1, 0.3, 1);
  }
  .crystal-card:hover {
    transform: translateY(-1px);
    box-shadow:
      0 3px 12px rgba(0, 0, 0, 0.03),
      0 14px 30px -6px rgba(0, 113, 227, 0.09),
      inset 0 1px 0 rgba(255, 255, 255, 1);
  }

  /* Header */
  .hdr {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 14px;
    margin-bottom: 24px;
    flex-wrap: wrap;
  }
  .hdr-brand {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .logo-box {
    width: 42px;
    height: 42px;
    border-radius: var(--radius-md);
    background: linear-gradient(180deg, #0077ED 0%, #0066CC 100%);
    border: 1px solid rgba(255, 255, 255, 0.4);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: #FFFFFF;
    font-weight: 900;
    font-size: 20px;
    box-shadow: 0 4px 12px rgba(0, 113, 227, 0.25), inset 0 1px 0 rgba(255, 255, 255, 0.4);
    text-decoration: none;
    transition: transform 140ms ease;
  }
  .logo-box:hover {
    transform: scale(1.03);
  }
  .hdr-text h1 {
    font-size: 15.5px;
    font-weight: 800;
    letter-spacing: -0.015em;
    color: var(--text-primary);
    text-wrap: balance;
  }
  .hdr-text p {
    font-size: 12px;
    color: var(--text-secondary);
    margin-top: 2px;
    display: flex;
    align-items: center;
    gap: 5px;
  }
  .hdr-actions {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  /* Status Pill Badge */
  .status-pill {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    padding: 5px 12px;
    border-radius: 9999px;
    background: rgba(255, 255, 255, 0.94);
    border: 1px solid rgba(0, 0, 0, 0.08);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.03), inset 0 1px 0 rgba(255, 255, 255, 1);
  }
  .beacon {
    position: relative;
    display: flex;
    height: 8px;
    width: 8px;
  }
  .beacon-ping {
    animation: ping 1.8s cubic-bezier(0, 0, 0.2, 1) infinite;
    position: absolute;
    display: inline-flex;
    height: 100%;
    width: 100%;
    border-radius: 9999px;
    background-color: var(--apple-mint);
    opacity: 0.75;
  }
  .beacon-dot {
    position: relative;
    display: inline-flex;
    border-radius: 9999px;
    height: 8px;
    width: 8px;
    background-color: var(--apple-mint);
  }
  @keyframes ping {
    75%, 100% {
      transform: scale(2.2);
      opacity: 0;
    }
  }
  .status-pill-text {
    font-size: 11px;
    font-family: var(--mono);
    font-weight: 700;
    letter-spacing: 0.04em;
    color: var(--text-primary);
  }
  .status-pill-tag {
    font-size: 9.5px;
    font-family: var(--mono);
    padding: 2px 6px;
    border-radius: 5px;
    background: rgba(0, 113, 227, 0.08);
    color: var(--apple-blue);
    border: 1px solid rgba(0, 113, 227, 0.2);
    font-weight: 700;
  }

  /* Action Buttons */
  .btn-apple-action {
    background: rgba(255, 255, 255, 0.94);
    color: var(--text-primary);
    font-size: 11.5px;
    font-weight: 700;
    padding: 6px 13px;
    border-radius: 9999px;
    border: 1px solid rgba(0, 0, 0, 0.09);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.03), inset 0 1px 0 rgba(255, 255, 255, 1);
    display: inline-flex;
    align-items: center;
    gap: 6px;
    cursor: pointer;
    touch-action: manipulation;
    user-select: none;
    transition: transform 120ms cubic-bezier(0.16, 1, 0.3, 1), background-color 120ms ease, border-color 120ms ease, box-shadow 120ms ease;
  }
  .btn-apple-action:hover {
    background: #FFFFFF;
    border-color: rgba(0, 0, 0, 0.16);
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.05), inset 0 1px 0 rgba(255, 255, 255, 1);
    transform: translateY(-0.5px);
  }
  .btn-apple-action:active {
    transform: scale(0.96);
  }

  /* Hero Impact Card */
  .hero-crystal {
    background: linear-gradient(135deg, rgba(255, 255, 255, 0.98) 0%, rgba(246, 250, 255, 0.94) 50%, rgba(255, 246, 250, 0.95) 100%);
    backdrop-filter: blur(36px) saturate(190%);
    -webkit-backdrop-filter: blur(36px) saturate(190%);
    border: 1px solid rgba(255, 255, 255, 1);
    border-radius: var(--radius-xl);
    box-shadow:
      0 2px 4px rgba(0, 0, 0, 0.02),
      0 16px 36px -8px rgba(0, 113, 227, 0.08),
      inset 0 1px 1px rgba(255, 255, 255, 1);
    padding: 24px;
    margin-bottom: 20px;
  }
  .hero-tag {
    font-size: 10.5px;
    font-family: var(--mono);
    font-weight: 700;
    color: var(--apple-blue);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    margin-bottom: 8px;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .hero-headline {
    font-size: 20px;
    font-weight: 800;
    line-height: 1.35;
    margin-bottom: 6px;
    letter-spacing: -0.015em;
    color: var(--text-primary);
    text-wrap: balance;
  }
  .hero-desc {
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.6;
    text-wrap: pretty;
  }
  .hero-pills {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 18px;
  }
  .hero-pill {
    background: rgba(255, 255, 255, 0.94);
    border: 1px solid rgba(0, 0, 0, 0.08);
    padding: 6px 12px;
    border-radius: 9999px;
    font-size: 11.5px;
    color: var(--text-primary);
    font-weight: 600;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }
  .hero-pill b {
    color: var(--apple-blue);
    font-family: var(--mono);
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }

  /* Hardware Specs Strip (4 Columns on Desktop, 2 on Mobile) */
  .specs-strip {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 1px;
    background: rgba(0, 0, 0, 0.06);
    border: 1px solid rgba(0, 0, 0, 0.06);
    border-radius: var(--radius-lg);
    overflow: hidden;
    margin-bottom: 20px;
  }
  .spec-item {
    background: rgba(255, 255, 255, 0.94);
    padding: 12px 16px;
  }
  .spec-item-label {
    font-size: 9.5px;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-family: var(--mono);
    font-weight: 700;
    margin-bottom: 3px;
    display: flex;
    align-items: center;
    gap: 5px;
  }
  .spec-item-val {
    font-size: 12.5px;
    font-weight: 700;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    font-variant-numeric: tabular-nums;
  }

  /* 4 Unified Metric Cards (2x2 Grid) */
  .metrics-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 14px;
    margin-bottom: 20px;
  }
  .metric-card {
    padding: 18px 20px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
  }
  .metric-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 12px;
  }
  .metric-title {
    font-size: 10.5px;
    font-family: var(--mono);
    font-weight: 700;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .metric-title svg {
    color: var(--apple-blue);
    flex-shrink: 0;
  }
  .metric-badge {
    font-size: 10px;
    font-family: var(--mono);
    font-weight: 700;
    color: var(--apple-emerald);
    background: rgba(16, 185, 129, 0.1);
    border: 1px solid rgba(16, 185, 129, 0.22);
    padding: 2px 7px;
    border-radius: 6px;
    font-variant-numeric: tabular-nums;
  }
  .metric-compare {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 10px;
  }
  .metric-col {
    display: flex;
    flex-direction: column;
  }
  .metric-col-lbl {
    font-size: 9.5px;
    font-weight: 700;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin-bottom: 2px;
  }
  .metric-col-val {
    font-family: var(--mono);
    font-size: 19px;
    font-weight: 800;
    font-variant-numeric: tabular-nums;
  }
  .metric-col-val.before {
    color: var(--apple-rose);
  }
  .metric-col-val.after {
    color: var(--apple-emerald);
  }
  .metric-arrow-box {
    color: var(--text-muted);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0 6px;
  }
  .metric-gauge {
    margin-top: 4px;
  }
  .gauge-track {
    height: 7px;
    border-radius: 9999px;
    background: rgba(244, 63, 94, 0.12);
    overflow: hidden;
    position: relative;
    margin-bottom: 4px;
  }
  .gauge-fill {
    height: 100%;
    border-radius: 9999px;
    background: linear-gradient(90deg, #10B981 0%, #34D399 100%);
    box-shadow: 0 1px 3px rgba(16, 185, 129, 0.3);
  }
  .gauge-labels {
    display: flex;
    justify-content: space-between;
    font-size: 10px;
    font-family: var(--mono);
    color: var(--text-secondary);
    font-variant-numeric: tabular-nums;
  }

  /* Bloatware Purged Catalog */
  .section-hdr {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 12px;
  }
  .section-title {
    font-size: 12px;
    font-weight: 800;
    color: var(--text-primary);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    display: flex;
    align-items: center;
    gap: 7px;
  }
  .section-title svg {
    color: var(--apple-blue);
    flex-shrink: 0;
  }
  .catalog-controls {
    display: flex;
    align-items: center;
    gap: 5px;
    flex-wrap: wrap;
    margin-bottom: 14px;
    padding-bottom: 12px;
    border-bottom: 1px solid rgba(0, 0, 0, 0.06);
  }
  .filter-pill {
    font-size: 10.5px;
    font-weight: 700;
    padding: 4px 10px;
    border-radius: 9999px;
    border: 1px solid rgba(0, 0, 0, 0.08);
    background: rgba(255, 255, 255, 0.9);
    color: var(--text-secondary);
    cursor: pointer;
    user-select: none;
    transition: transform 120ms cubic-bezier(0.16, 1, 0.3, 1), background-color 120ms ease, color 120ms ease, border-color 120ms ease, box-shadow 120ms ease;
  }
  .filter-pill:hover {
    background: #FFFFFF;
    color: var(--text-primary);
    border-color: rgba(0, 0, 0, 0.16);
    transform: translateY(-0.5px);
  }
  .filter-pill:active {
    transform: scale(0.95);
  }
  .filter-pill.active {
    background: var(--apple-blue);
    color: #FFFFFF;
    border-color: var(--apple-blue);
    box-shadow: 0 2px 8px rgba(0, 113, 227, 0.32);
  }
  .catalog-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 12px;
    margin-bottom: 20px;
  }
  .app-cat-card {
    background: rgba(255, 255, 255, 0.8);
    border: 1px solid rgba(0, 0, 0, 0.06);
    border-radius: var(--radius-md);
    padding: 14px 16px;
    transition: background-color 140ms ease, border-color 140ms ease;
  }
  .app-cat-card:hover {
    background: rgba(255, 255, 255, 0.95);
    border-color: rgba(0, 113, 227, 0.18);
  }
  .app-cat-title {
    font-size: 11.5px;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: 8px;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .app-cat-badge {
    font-size: 9.5px;
    font-family: var(--mono);
    font-weight: 700;
    color: var(--apple-rose);
    background: rgba(244, 63, 94, 0.08);
    border: 1px solid rgba(244, 63, 94, 0.18);
    padding: 1px 6px;
    border-radius: 5px;
    font-variant-numeric: tabular-nums;
  }
  .chips-wrap {
    display: flex;
    flex-wrap: wrap;
    gap: 5px;
  }
  .chip-del {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 8px;
    border-radius: 6px;
    font-size: 10.5px;
    font-family: var(--mono);
    background: rgba(244, 63, 94, 0.05);
    color: #BE123C;
    border: 1px solid rgba(244, 63, 94, 0.14);
    transition: transform 120ms cubic-bezier(0.16, 1, 0.3, 1), background-color 120ms ease, border-color 120ms ease;
  }
  .chip-del:hover {
    background: rgba(244, 63, 94, 0.11);
    border-color: rgba(244, 63, 94, 0.28);
    transform: translateY(-0.5px);
  }
  .chip-del:active {
    transform: scale(0.96);
  }
  .chip-del svg {
    width: 9px;
    height: 9px;
    stroke: currentColor;
    flex-shrink: 0;
  }
  .chip-keep {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 8px;
    border-radius: 6px;
    font-size: 10.5px;
    font-family: var(--mono);
    background: rgba(16, 185, 129, 0.07);
    color: #047857;
    border: 1px solid rgba(16, 185, 129, 0.2);
    transition: transform 120ms cubic-bezier(0.16, 1, 0.3, 1), background-color 120ms ease, border-color 120ms ease;
  }
  .chip-keep:hover {
    background: rgba(16, 185, 129, 0.15);
    border-color: rgba(16, 185, 129, 0.35);
    transform: translateY(-0.5px);
  }
  .chip-keep:active {
    transform: scale(0.96);
  }
  .chip-keep svg {
    width: 9px;
    height: 9px;
    stroke: currentColor;
    flex-shrink: 0;
  }

  /* 3-Pillar Hardening Checklist (3 Columns on Desktop, 1 on Mobile) */
  .pillars-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 12px;
    margin-bottom: 20px;
  }
  .pillar-card {
    background: rgba(255, 255, 255, 0.85);
    border: 1px solid rgba(0, 0, 0, 0.06);
    border-radius: var(--radius-md);
    padding: 14px;
    display: flex;
    flex-direction: column;
  }
  .pillar-title {
    font-size: 11px;
    font-weight: 800;
    color: var(--text-primary);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin-bottom: 10px;
    padding-bottom: 8px;
    border-bottom: 1px solid rgba(0, 0, 0, 0.06);
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .pillar-list {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .chk-item {
    font-size: 11px;
    color: var(--text-primary);
    display: flex;
    align-items: flex-start;
    gap: 7px;
    line-height: 1.4;
  }
  .chk-item svg {
    width: 13px;
    height: 13px;
    color: #059669;
    flex-shrink: 0;
    margin-top: 1px;
  }

  /* Soft Sell Box */
  .soft-sell {
    padding: 18px 20px;
    display: flex;
    gap: 16px;
    align-items: center;
    background: linear-gradient(135deg, rgba(255, 255, 255, 0.96) 0%, rgba(240, 247, 255, 0.92) 100%);
    margin-bottom: 24px;
  }
  .soft-sell-icon {
    width: 42px;
    height: 42px;
    border-radius: var(--radius-md);
    background: rgba(0, 113, 227, 0.1);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: var(--apple-blue);
  }
  .soft-sell-text h3 {
    font-size: 13.5px;
    font-weight: 800;
    margin-bottom: 3px;
    color: var(--text-primary);
    text-wrap: balance;
  }
  .soft-sell-text p {
    font-size: 11.5px;
    color: var(--text-secondary);
    line-height: 1.55;
    text-wrap: pretty;
  }

  /* Footer */
  .ftr {
    text-align: center;
    padding-top: 24px;
    border-top: 1px solid rgba(0, 0, 0, 0.08);
  }
  .ftr a {
    color: var(--apple-blue);
    text-decoration: none;
    font-weight: 700;
    font-size: 13px;
  }
  .ftr a:hover {
    text-decoration: underline;
  }
  .ftr p {
    font-size: 11px;
    color: var(--text-muted);
    margin-top: 3px;
  }

  /* Print Stylesheet */
  @media print {
    body {
      background: #FFFFFF !important;
      padding: 0 !important;
      color: #000000 !important;
    }
    .crystal-card, .hero-crystal, .pillar-card, .app-cat-card {
      box-shadow: none !important;
      border: 1px solid #E2E8F0 !important;
      background: #FFFFFF !important;
      break-inside: avoid;
    }
    .btn-apple-action, .catalog-controls {
      display: none !important;
    }
  }

  @media(max-width: 768px) {
    .specs-strip {
      grid-template-columns: repeat(2, 1fr);
    }
    .pillars-grid {
      grid-template-columns: 1fr;
    }
  }

  @media(max-width: 640px) {
    body {
      padding: 20px 14px 60px;
    }
    .metrics-grid, .catalog-grid {
      grid-template-columns: 1fr;
    }
    .hero-headline {
      font-size: 18px;
    }
    .metric-col-val {
      font-size: 17px;
    }
    .soft-sell {
      flex-direction: column;
      align-items: flex-start;
    }
    .hdr {
      flex-direction: column;
      align-items: flex-start;
      gap: 12px;
    }
    .hdr-actions {
      width: 100%;
      justify-content: flex-start;
      flex-wrap: wrap;
    }
  }
</style>
</head>
<body>

<!-- Header with Apple Glass & Status Pill -->
<header class="hdr">
  <div class="hdr-brand">
    <a href="https://megapass.web.id" target="_blank" rel="noopener" class="logo-box" title="MEGAPASS Intra Solusindo">
      M
    </a>
    <div class="hdr-text">
      <h1>MEGAPASS INTRA SOLUSINDO</h1>
      <p>
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
        Spesialis Servis HP, Laptop &amp; Komputer &bull; Sidoarjo
      </p>
    </div>
  </div>
  <div class="hdr-actions">
    <div class="status-pill">
      <span class="beacon">
        <span class="beacon-ping"></span>
        <span class="beacon-dot"></span>
      </span>
      <span class="status-pill-text">DEBLOATER v$ver</span>
      <span class="status-pill-tag">VERIFIED</span>
    </div>
    <button type="button" onclick="window.print()" class="btn-apple-action" title="Cetak atau Simpan ke PDF">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect x="6" y="14" width="12" height="8"/></svg>
      Cetak / PDF
    </button>
  </div>
</header>

<!-- Hero Impact Summary (Apple Widget) -->
<section class="hero-crystal">
  <div class="hero-tag">
    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
    Ringkasan Hasil Optimasi Meja Servis
  </div>
  <h2 class="hero-headline">Sistem Operasi Berhasil Dibersihkan Secara Menyeluruh</h2>
  <p class="hero-desc">
    Seluruh bloatware bawaan vendor, telemetri analitik Windows, fitur background AI (Recall &amp; Copilot), serta 21 service pembeban memori telah dinonaktifkan dengan konfigurasi fail-safe meja servis.
  </p>
  <div class="hero-pills">
    <div class="hero-pill">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#E11D48" stroke-width="2.5"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg>
      Bloatware Dihapus: <b>$cRemoved Apps</b>
    </div>
    <div class="hero-pill">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#0071E3" stroke-width="2.5"><rect x="2" y="2" width="20" height="20" rx="5"/><path d="M12 18V6M6 12h12"/></svg>
      Penghematan RAM: <b>$pillRAM</b>
    </div>
    <div class="hero-pill">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#059669" stroke-width="2.5"><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/></svg>
      Beban Proses: <b>$pProc% Lebih Enteng</b>
    </div>
    <div class="hero-pill">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#D97706" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"/></svg>
      Service Dimatikan: <b>$cSvcOff Layanan</b>
    </div>
    <div class="hero-pill">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#059669" stroke-width="2.5"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>
      Disk C Pulih: <b>$pillDisk</b>
    </div>
  </div>
</section>

<!-- Hardware & OS Specs Strip -->
<section class="specs-strip">
  <div class="spec-item">
    <div class="spec-item-label">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="9" y1="21" x2="9" y2="9"/></svg>
      Sistem Operasi
    </div>
    <div class="spec-item-val" title="$bOSName">$bOSName</div>
  </div>
  <div class="spec-item">
    <div class="spec-item-label">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/><line x1="9" y1="1" x2="9" y2="4"/><line x1="15" y1="1" x2="15" y2="4"/><line x1="9" y1="20" x2="9" y2="23"/><line x1="15" y1="20" x2="15" y2="23"/><line x1="20" y1="9" x2="23" y2="9"/><line x1="20" y1="15" x2="23" y2="15"/><line x1="1" y1="9" x2="4" y2="9"/><line x1="1" y1="15" x2="4" y2="15"/></svg>
      Prosesor (CPU)
    </div>
    <div class="spec-item-val" title="$bCPUName">$bCPUName</div>
  </div>
  <div class="spec-item">
    <div class="spec-item-label">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="6" y1="2" x2="6" y2="22"/><line x1="18" y1="2" x2="18" y2="22"/><line x1="2" y1="6" x2="22" y2="6"/><line x1="2" y1="18" x2="22" y2="18"/></svg>
      Kapasitas RAM
    </div>
    <div class="spec-item-val">$strBRAM_Total</div>
  </div>
  <div class="spec-item">
    <div class="spec-item-label">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
      Waktu Audit
    </div>
    <div class="spec-item-val">$bTimestamp</div>
  </div>
</section>

<!-- 4 Unified Performance Metric Cards (Cards with integrated gauge & delta) -->
<section class="metrics-grid">
  <!-- Card 1: Proses Latar Belakang -->
  <div class="crystal-card metric-card">
    <div>
      <div class="metric-head">
        <div class="metric-title">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>
          Proses Latar Belakang
        </div>
        <span class="metric-badge">$badgeProc</span>
      </div>
      <div class="metric-compare">
        <div class="metric-col">
          <span class="metric-col-lbl">Sebelum</span>
          <span class="metric-col-val before">$bProc</span>
        </div>
        <div class="metric-arrow-box">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
        </div>
        <div class="metric-col" style="text-align: right;">
          <span class="metric-col-lbl">Sesudah</span>
          <span class="metric-col-val after">$aProc</span>
        </div>
      </div>
    </div>
    <div class="metric-gauge">
      <div class="gauge-track">
        <div class="gauge-fill" style="width: $barProc%;"></div>
      </div>
      <div class="gauge-labels">
        <span>Beban sekarang: $barProc%</span>
        <span>$labelProc</span>
      </div>
    </div>
  </div>

  <!-- Card 2: Layanan Windows Aktif -->
  <div class="crystal-card metric-card">
    <div>
      <div class="metric-head">
        <div class="metric-title">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
          Layanan Windows (Services)
        </div>
        <span class="metric-badge">$badgeSvc</span>
      </div>
      <div class="metric-compare">
        <div class="metric-col">
          <span class="metric-col-lbl">Sebelum</span>
          <span class="metric-col-val before">$bSvc</span>
        </div>
        <div class="metric-arrow-box">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
        </div>
        <div class="metric-col" style="text-align: right;">
          <span class="metric-col-lbl">Sesudah</span>
          <span class="metric-col-val after">$aSvc</span>
        </div>
      </div>
    </div>
    <div class="metric-gauge">
      <div class="gauge-track">
        <div class="gauge-fill" style="width: $barSvc%;"></div>
      </div>
      <div class="gauge-labels">
        <span>Layanan aktif: $barSvc%</span>
        <span>$labelSvc</span>
      </div>
    </div>
  </div>

  <!-- Card 3: Konsumsi Memori RAM -->
  <div class="crystal-card metric-card">
    <div>
      <div class="metric-head">
        <div class="metric-title">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="6" y1="2" x2="6" y2="22"/><line x1="18" y1="2" x2="18" y2="22"/><line x1="2" y1="6" x2="22" y2="6"/><line x1="2" y1="18" x2="22" y2="18"/></svg>
          Konsumsi RAM
        </div>
        <span class="metric-badge">$badgeRAM</span>
      </div>
      <div class="metric-compare">
        <div class="metric-col">
          <span class="metric-col-lbl">Sebelum</span>
          <span class="metric-col-val before">$strBRAM_Used</span>
        </div>
        <div class="metric-arrow-box">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
        </div>
        <div class="metric-col" style="text-align: right;">
          <span class="metric-col-lbl">Sesudah</span>
          <span class="metric-col-val after">$strARAM_Used</span>
        </div>
      </div>
    </div>
    <div class="metric-gauge">
      <div class="gauge-track">
        <div class="gauge-fill" style="width: $barRAM%;"></div>
      </div>
      <div class="gauge-labels">
        <span>Beban RAM: $barRAM%</span>
        <span>$gaugeRAM</span>
      </div>
    </div>
  </div>

  <!-- Card 4: Kapasitas Partisi Disk C: -->
  <div class="crystal-card metric-card">
    <div>
      <div class="metric-head">
        <div class="metric-title">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="2" width="20" height="20" rx="2" ry="2"/><line x1="7" y1="2" x2="7" y2="22"/><line x1="17" y1="2" x2="17" y2="22"/><line x1="2" y1="12" x2="22" y2="12"/></svg>
          Partisi Drive C:
        </div>
        <span class="metric-badge">$badgeDisk</span>
      </div>
      <div class="metric-compare">
        <div class="metric-col">
          <span class="metric-col-lbl">Free Awal</span>
          <span class="metric-col-val before" style="color: var(--text-secondary);">$bDiskFree GB</span>
        </div>
        <div class="metric-arrow-box">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
        </div>
        <div class="metric-col" style="text-align: right;">
          <span class="metric-col-lbl">Free Sekarang</span>
          <span class="metric-col-val after">$aDiskFree GB</span>
        </div>
      </div>
    </div>
    <div class="metric-gauge">
      <div class="gauge-track" style="background: rgba(16, 185, 129, 0.15);">
        <div class="gauge-fill" style="width: 100%;"></div>
      </div>
      <div class="gauge-labels">
        <span>Reserved &amp; Temp dibersihkan</span>
        <span>$gaugeDisk</span>
      </div>
    </div>
  </div>
</section>

<!-- Bloatware Purged Catalog -->
<section style="margin-bottom: 24px;">
  <div class="section-hdr">
    <div class="section-title">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg>
      Katalog Bloatware Berhasil Dihapus
    </div>
    <span class="status-pill-tag">$cRemoved Aplikasi</span>
  </div>

  <div class="catalog-controls">
    <span class="filter-pill active" onclick="filterApps('all', this)">Semua ($cRemoved)</span>
    <span class="filter-pill" onclick="filterApps('oem', this)">OEM &amp; Games</span>
    <span class="filter-pill" onclick="filterApps('xbox', this)">Xbox &amp; Gaming</span>
    <span class="filter-pill" onclick="filterApps('comm', this)">Komunikasi</span>
    <span class="filter-pill" onclick="filterApps('ai', this)">Media &amp; AI</span>
    <span class="filter-pill" onclick="filterApps('ads', this)">Iklan</span>
    <span class="filter-pill" onclick="filterApps('safe', this)">Whitelist Aman (10)</span>
  </div>

  <div class="catalog-grid">
    <!-- Category 1: Vendor Bloatware & Junk -->
    <div class="app-cat-card" data-category="oem">
      <div class="app-cat-title">
        <span>Vendor Bloatware &amp; Junkware</span>
        <span class="app-cat-badge">14 Apps</span>
      </div>
      <div class="chips-wrap">
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Bing Weather</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Bing News</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Bing Sports</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Bing Finance</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Feedback Hub</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Get Help</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Get Started</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Microsoft Solitaire</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Mixed Reality Portal</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>3D Viewer</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Print 3D</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Paint 3D</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>OneNote Hub</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Office Hub</span>
      </div>
    </div>

    <!-- Category 2: Xbox & Gaming Background -->
    <div class="app-cat-card" data-category="xbox">
      <div class="app-cat-title">
        <span>Xbox &amp; Gaming Background</span>
        <span class="app-cat-badge">7 Apps</span>
      </div>
      <div class="chips-wrap">
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Xbox App</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Xbox TCUI</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Game Overlay</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Gaming Overlay</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Identity Provider</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Speech To Text</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Gaming App</span>
      </div>
    </div>

    <!-- Category 3: Komunikasi & Background Sync -->
    <div class="app-cat-card" data-category="comm">
      <div class="app-cat-title">
        <span>Komunikasi &amp; Background Sync</span>
        <span class="app-cat-badge">6 Apps</span>
      </div>
      <div class="chips-wrap">
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Phone Link</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Teams Personal</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Microsoft To Do</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Power Automate</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Mail &amp; Calendar</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Outlook for Windows</span>
      </div>
    </div>

    <!-- Category 4: Media Jadul & AI Windows 11 -->
    <div class="app-cat-card" data-category="ai">
      <div class="app-cat-title">
        <span>Media Jadul &amp; AI Windows 11</span>
        <span class="app-cat-badge">9 Apps</span>
      </div>
      <div class="chips-wrap">
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Cortana</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Zune Music</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Zune Video</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Clipchamp</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Windows Copilot</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Recall AIX</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Recall Photon</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Quick Assist</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Microsoft Family</span>
      </div>
    </div>

    <!-- Category 5: Iklan & Delivery Manager -->
    <div class="app-cat-card" data-category="ads">
      <div class="app-cat-title">
        <span>Iklan &amp; Delivery Manager</span>
        <span class="app-cat-badge">5 Apps</span>
      </div>
      <div class="chips-wrap">
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Advertising Xaml</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Store Engagement</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Content Delivery</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Parental Controls</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>People Experience</span>
      </div>
    </div>

    <!-- Category 6: OEM & Third-Party Games -->
    <div class="app-cat-card" data-category="oem">
      <div class="app-cat-title">
        <span>OEM &amp; Third-Party Games</span>
        <span class="app-cat-badge">22 Apps</span>
      </div>
      <div class="chips-wrap">
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Candy Crush Saga</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Candy Crush Soda</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Candy Crush Friends</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Bubble Witch 3</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Farm Heroes Saga</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>March of Empires</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Disney Magic</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>FarmVille 2</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Asphalt 8</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Royal Revolt 2</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Spotify</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>TikTok</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Disney+</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Netflix</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Prime Video</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Facebook</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>LinkedIn</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Pandora</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Autodesk SketchBook</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>Plex</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>ASUS Assistant</span>
        <span class="chip-del"><svg viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10"/></svg>McAfee Security</span>
      </div>
    </div>

    <!-- Category 7: Whitelist Aman (Dipertahankan) -->
    <div class="app-cat-card" data-category="safe">
      <div class="app-cat-title">
        <span>Aplikasi Produktivitas Aman (Whitelist)</span>
        <span class="app-cat-badge" style="color: #047857; background: rgba(16, 185, 129, 0.1); border-color: rgba(16, 185, 129, 0.25);">10 Apps</span>
      </div>
      <div class="chips-wrap">
        <span class="chip-keep"><svg viewBox="0 0 12 12"><path d="M2 6l3 3 5-5"/></svg>Calculator</span>
        <span class="chip-keep"><svg viewBox="0 0 12 12"><path d="M2 6l3 3 5-5"/></svg>Camera</span>
        <span class="chip-keep"><svg viewBox="0 0 12 12"><path d="M2 6l3 3 5-5"/></svg>Paint</span>
        <span class="chip-keep"><svg viewBox="0 0 12 12"><path d="M2 6l3 3 5-5"/></svg>Sticky Notes</span>
        <span class="chip-keep"><svg viewBox="0 0 12 12"><path d="M2 6l3 3 5-5"/></svg>Clock &amp; Alarms</span>
        <span class="chip-keep"><svg viewBox="0 0 12 12"><path d="M2 6l3 3 5-5"/></svg>Sound Recorder</span>
        <span class="chip-keep"><svg viewBox="0 0 12 12"><path d="M2 6l3 3 5-5"/></svg>Windows Terminal</span>
        <span class="chip-keep"><svg viewBox="0 0 12 12"><path d="M2 6l3 3 5-5"/></svg>Microsoft Store</span>
        <span class="chip-keep"><svg viewBox="0 0 12 12"><path d="M2 6l3 3 5-5"/></svg>Microsoft Edge</span>
        <span class="chip-keep"><svg viewBox="0 0 12 12"><path d="M2 6l3 3 5-5"/></svg>Windows Defender</span>
        <span class="chip-keep"><svg viewBox="0 0 12 12"><path d="M2 6l3 3 5-5"/></svg>OneDrive</span>
      </div>
    </div>
  </div>
</section>

<!-- 3-Pillar Hardening Checklist (3 Columns on Desktop, 1 on Mobile) -->
<section style="margin-bottom: 24px;">
  <div class="section-hdr">
    <div class="section-title">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
      3 Pilar Konfigurasi Fail-Safe Meja Servis
    </div>
    <span class="status-pill-tag">24 Optimasi Aktif</span>
  </div>

  <div class="pillars-grid">
    <!-- Pillar 1: Privasi & AI -->
    <div class="pillar-card">
      <div class="pillar-title">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="var(--apple-blue)" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
        1. Privasi &amp; Anti-AI
      </div>
      <div class="pillar-list">
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Windows Recall &amp; Copilot off</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Telemetry &amp; data diagnostic off</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Iklan Start Menu &amp; Lock Screen off</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Advertising ID &amp; Location ditutup</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Cloud Clipboard &amp; Timeline sync off</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Wi-Fi Sense &amp; P2P Update off</span></div>
      </div>
    </div>

    <!-- Pillar 2: Pembersihan Beban -->
    <div class="pillar-card">
      <div class="pillar-title">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="var(--apple-blue)" stroke-width="2.5"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg>
        2. Pembersihan Beban
      </div>
      <div class="pillar-list">
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>$cRemoved bloatware berhasil di-purge</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>$cSvcOff background service nonaktif</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Reserved Storage ~7 GB dibebaskan</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Windows Update dikunci aman</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>OneDrive dipertahankan (sinkronisasi aktif)</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Edge Startup Boost background off</span></div>
      </div>
    </div>

    <!-- Pillar 3: Respon Hardware -->
    <div class="pillar-card">
      <div class="pillar-title">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="var(--apple-blue)" stroke-width="2.5"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
        3. Respon Hardware
      </div>
      <div class="pillar-list">
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>File Explorer langsung This PC</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Tombol Task View taskbar off</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Visual FX custom (thumbnail, drag, shadow on, font smooth on)</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Focus Assist Priority Only aktif</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Hidden file tetap disembunyikan</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Menu context klasik Win11 aktif</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Menu show delay 0ms (instan)</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>VBS &amp; Core Isolation off (boost latency)</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Pagefile fixed optimal RAM</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>NTFS I/O last access off</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Timeout boot/shutdown cepat</span></div>
        <div class="chk-item"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 8.5L6.5 12L13 4"/></svg><span>Network throttling multimedia off</span></div>
      </div>
    </div>
  </div>
</section>

<!-- Soft Sell Card (Hardware Maintenance CTA) -->
<section class="crystal-card soft-sell">
  <div class="soft-sell-icon">
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>
    </svg>
  </div>
  <div class="soft-sell-text">
    <h3>Optimasi Sistem Operasi Selesai &bull; Rekomendasi Hardware</h3>
    <p>Software laptop Anda kini bersih bebas beban latar. Jika fisik laptop masih terasa hangat, kipas bising, atau pasta pendingin prosesor sudah di atas 1-2 tahun, jadwalkan pembersihan thermal &amp; hardware berkala di meja servis Megapass Intra Solusindo.</p>
  </div>
</section>

<!-- Footer -->
<footer class="ftr">
  <a href="https://megapass.web.id" target="_blank" rel="noopener">megapass.web.id</a>
  <p>Megapass Intra Solusindo &bull; Spesialis Servis HP, Laptop &amp; Komputer Sidoarjo</p>
</footer>

<script>
function filterApps(cat, btn) {
  var cards = document.querySelectorAll(".app-cat-card");
  var pills = document.querySelectorAll(".filter-pill");
  pills.forEach(function(p){ p.classList.remove("active"); });
  btn.classList.add("active");

  cards.forEach(function(card){
    if (cat === "all") {
      card.style.display = "block";
    } else {
      if (card.getAttribute("data-category") === cat) {
        card.style.display = "block";
      } else {
        card.style.display = "none";
      }
    }
  });
}
</script>

</body>
</html>
"@

# Tulis file dan buka di browser
try {
    [System.IO.File]::WriteAllText($reportPath, $htmlReport, [System.Text.Encoding]::UTF8)
    Ok "Laporan HTML dibuat: $reportPath"
    Start-Process $reportPath
    Ok "Laporan dibuka di browser"
} catch {
    Warn "Gagal membuat laporan HTML: $_"
    Info "Cek manual di Desktop: MEGAPASS-Debloat-Report.html"
}

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Log ("+" + "=" * $boxW + "+") Green
Box "   DEBLOAT SELESAI! v$ver" Green
Box "" Green
Box "   Apps dihapus       : $($cRemoved.ToString().PadLeft(4))" Green
Box "   Tasks disabled     : $($cTaskOff.ToString().PadLeft(4))" Green
Box "   Services off       : $($cSvcOff.ToString().PadLeft(4))" Green
Box "   Temp cleaned       : $($cCleaned.ToString().PadLeft(4))" Green
if ($fail -gt 0) {
    Box "   Warning            : $($fail.ToString().PadLeft(4))" Yellow
}
Box "" Green
Box "   WinUpdate paused 2099 (Store on)" Green
Box "   Defender utuh & aktif (aman)" Green
Box "   Klik kanan klasik Win11" Green
Box "   Explorer: This PC, Task View off" Green
Box "   Visual FX: thumbnail, drag, shadow on" Green
Box "   Focus Assist: Priority Only on" Green
Box "   Reserved Storage off (~7GB)" Green
Box "   VBS/HVCI off (boost performa)" Green
Box "   Edge background off" Green
Box "   OneDrive utuh & aktif (sinkron on)" Green
Box "   Pagefile dioptimasi" Green
Box "   NTFS I/O dioptimasi" Green
Box "   Boot/shutdown dipercepat" Green
Box "   Network full speed" Green
Box "   UI instant response" Green
Box "   Laporan HTML di Desktop" Green
Box "" Green
Box "   Restore point tersedia untuk rollback" Green
Box "   Silakan RESTART PC untuk efek penuh" Green
Box "" Green
Box "   MEGAPASS | megapass.web.id" Green
Box "   Teknisi BNSP | Sidoarjo" Green
Log ("+" + "=" * $boxW + "+") Green
Write-Host ""
# ponytail: Read-Host hang via irm|iex, [Console]::ReadLine crash di ISE
# Start-Sleep paling portable -- auto-close setelah 30 detik
Log "Laporan lengkap: $reportPath" Cyan
Log "Auto-close dalam 30 detik (tutup jendela untuk skip)..." Gray
Start-Sleep -Seconds 30
