# PLAN.md - Spesifikasi Teknis & Panduan Rebuild MegaPass Windows Optimizer v3.0 (GUI Edition)

Dokumen ini adalah cetak biru (blueprint) bagi LLM tingkat tinggi (seperti Claude 3.5 Sonnet / Claude 3 Opus) untuk membangun ulang aplikasi optimasi Windows **MegaPass-Optimizer.bat** dari nol menggunakan antarmuka grafis (**GUI WPF**) interaktif yang menyerupai konsep *Chris Titus Tech Windows Utility (WinUtil)*.

---

## 🎯 Tujuan Utama
Membuat satu file script hybrid (`.bat` pengeksekusi `.ps1` secara internal) berkinerja tinggi, **zero-dependency**, berjalan **100% offline**, dengan antarmuka grafis **WPF (Windows Presentation Foundation)** yang interaktif untuk memudahkan teknisi memilih fitur optimasi sesuai kebutuhan laptop/PC customer.

---

## 🏗️ Desain Antarmuka GUI (WPF XAML)
Aplikasi harus memuat GUI berbasis XML/XAML yang terpasang di memori Windows Presentation Framework. Library WPF dimuat di awal PowerShell menggunakan:
```powershell
[System.Reflection.Assembly]::LoadWithPartialName("PresentationFramework") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("PresentationCore") | Out-Null
```

### 📋 Struktur Komponen GUI:
1. **Windows Container:** Jendela utama (ukuran default 600x650 piksel) dengan tema gelap (*Dark Mode Theme*) agar terlihat modern dan profesional.
2. **Title Header:** Label teks besar berbunyi `"MEGAPASS Intra Solusindo - Maintenance Utility v3.0"`.
3. **Panel Group / Container:**
   - Kumpulan Checkbox untuk optimasi sistem dalam satu panel layout.
4. **Log Console Output (RichTextBox / TextBox):** Jendela log read-only di bagian bawah aplikasi untuk menampilkan output proses optimasi secara real-time.
5. **Action Button:** Tombol utama berlabel **`[ JALANKAN OPTIMASI ]`** yang akan memicu proses eksekusi di latar belakang berdasarkan opsi yang dicentang.

---

## ⚙️ Fitur & Modul Interaktif (PowerShell Core Logic)

### Tab 1: System Tweaks (Centang Pilihan)
*   **[ ] Power Settings (AC/DC - 5 Hours):** Mengatur timeout layar & sleep ke 5 jam dan mengaktifkan skema *High Performance* (GUID: `8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c`).
*   **[ ] Disable Taskbar Auto-Hide:** Mengamankan registry `StuckRects3` dan registry Advanced agar taskbar tidak hilang otomatis.
*   **[ ] Visual Best Performance:** Mematikan animasi window, taskbar animations, bayangan listview, dan menulis registry `UserPreferencesMask` standar.
*   **[ ] Disable Windows Defender:** Mematikan security protection via registry policies dan cmdlet `Set-MpPreference`.
*   **[ ] Pause Windows Updates:** Menunda pembaruan otomatis Windows Update hingga tanggal **31 Desember 2099**.
*   **[ ] File Explorer & Desktop Tweaks:** Mengubah startup File Explorer langsung ke halaman "This PC", mematikan recent/frequent files history di Quick Access, dan memunculkan icon shortcut "This PC" di desktop.
*   **[ ] Purge Temporary & Update Cache:** Mematikan service `wuauserv` secara aman, menghapus folder cache `SoftwareDistribution\Download`, membersihkan folder temp user, temp system, prefetch, dns cache, winget cache, dan Recycle Bin (dengan pengecualian data profile browser agar login tidak ter-logout).
*   **[ ] Reset Folder Views & Restart Explorer:** Menghentikan proses `explorer.exe`, menghapus registry `Bags` & `BagMRU` untuk mereset layout folder, lalu menyalakan kembali explorer.
*   **[ ] Disable Bing Search in Start Menu:** Mematikan fitur saran web Bing di Start Menu via registry Explorer (`DisableSearchBoxSuggestions = 1`) untuk mempercepat pencarian file lokal.
*   **[ ] Disable Telemetry & Diagnostics:** Menonaktifkan service pengumpul data `DiagTrack` dan `dmwappushservice` untuk menghemat penggunaan RAM dan CPU.
*   **[ ] Uninstall Microsoft OneDrive:** Menghentikan proses `OneDrive.exe` dan meng-uninstall client OneDrive secara bersih dari sistem (mencegah notifikasi storage full).
*   **[ ] Restore Classic Context Menu (Win 11):** Mengembalikan menu klik kanan klasik ala Windows 10 pada Windows 11 via registry CLSID `{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}` (menghindari menu "Show more options").
*   **[ ] Disable Hibernation:** Mematikan fitur hibernasi (`powercfg -h off`) untuk menghapus file `hiberfil.sys` secara instan guna membebaskan ruang kosong SSD sebesar beberapa Gigabyte.
*   **[ ] Auto-Sync Time & Zone:** Menyetel zona waktu default ke SE Asia Standard Time (WIB / Bangkok, Hanoi, Jakarta) dan mengaktifkan sinkronisasi waktu otomatis (Windows Time Service) untuk mencegah error koneksi browser.
*   **[ ] Disable Ads & Suggestions:** Mematikan saran aplikasi iklan (promosi 3rd party) dan tips yang muncul di menu Start dan halaman Settings via registry `ContentDeliveryManager`.

### Khusus Windows 11 (Otomatis Aktif jika OS Win 11 Terdeteksi):
*   **[ ] Hide Widgets Icon** (Taskbar Widgets hidden)
*   **[ ] Hide Chat Icon** (Teams Chat hidden)
*   **[ ] Hide Task View Button** (Multi Windows button hidden)
*   *Catatan:* Layout Taskbar Alignment harus diatur **tetap di tengah (Center)** (`TaskbarAl = 1`).

---

## 🛠️ Detail Spesifikasi Teknis Backend PowerShell (15 Modul)

Jika checkbox diaktifkan, program harus menjalankan kode PowerShell backend berikut:

### 1. Power Settings
```powershell
$hp_guid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
$plans = powercfg -list
if (!($plans -match $hp_guid)) { powercfg -duplicatescheme $hp_guid | Out-Null }
powercfg -setactive $hp_guid
powercfg -change monitor-timeout-ac 300
powercfg -change monitor-timeout-dc 300
powercfg -change standby-timeout-ac 300
powercfg -change standby-timeout-dc 300
```

### 2. Disable Taskbar Auto-Hide
```powershell
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
```

### 3. Visual Best Performance
```powershell
$VisualEffectsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (!(Test-Path $VisualEffectsPath)) { New-Item -Path $VisualEffectsPath -Force | Out-Null }
Set-ItemProperty -Path $VisualEffectsPath -Name "VisualFXSetting" -Value 2 -Force
[byte[]]$mask = @(144,20,7,128,16,0,0,0)
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value $mask -Force
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Force
$ExplorerAdvPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $ExplorerAdvPath -Name "ListviewAlphaSelect" -Value 0 -Force
Set-ItemProperty -Path $ExplorerAdvPath -Name "ListviewShadow" -Value 0 -Force
Set-ItemProperty -Path $ExplorerAdvPath -Name "TaskbarAnimations" -Value 0 -Force
```

### 4. Disable Windows Defender
```powershell
Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true -DisableIOAVProtection $true -SignatureDisableUpdateOnStartupWithoutEngine $true -DisableArchiveScanning $true -DisableIntrusionPreventionSystem $true -DisableScriptScanning $true
$DefPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
if (!(Test-Path $DefPath)) { New-Item -Path $DefPath -Force | Out-Null }
Set-ItemProperty -Path $DefPath -Name "DisableAntiSpyware" -Value 1 -Force
$RealtimePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
if (!(Test-Path $RealtimePath)) { New-Item -Path $RealtimePath -Force | Out-Null }
Set-ItemProperty -Path $RealtimePath -Name "DisableRealtimeMonitoring" -Value 1 -Force
```

### 5. Pause Windows Updates s/d 2099
```powershell
$UpdatePath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
if (!(Test-Path $UpdatePath)) { New-Item -Path $UpdatePath -Force | Out-Null }
Set-ItemProperty -Path $UpdatePath -Name "PauseUpdatesExpiryTime" -Value "2099-12-31T23:59:59Z" -Force
Set-ItemProperty -Path $UpdatePath -Name "PauseFeatureUpdatesStartTime" -Value "2026-01-01T00:00:00Z" -Force
Set-ItemProperty -Path $UpdatePath -Name "PauseQualityUpdatesStartTime" -Value "2026-01-01T00:00:00Z" -Force
```

### 6. File Explorer & Desktop Tweaks
```powershell
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -Force
$ExplorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
Set-ItemProperty -Path $ExplorerPath -Name "ShowRecent" -Value 0 -Force
Set-ItemProperty -Path $ExplorerPath -Name "ShowFrequent" -Value 0 -Force
$DesktopIcons = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
if (!(Test-Path $DesktopIcons)) { New-Item -Path $DesktopIcons -Force | Out-Null }
Set-ItemProperty -Path $DesktopIcons -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -Force
```

### 7. Purge Temporary & Update Cache (Kecuali Data Login Browser)
```powershell
winget cache clean --accept-source-agreements | Out-Null
ipconfig /flushdns | Out-Null
cmd.exe /c "net stop wuauserv /y"
$DownloadPath = "$env:SystemRoot\SoftwareDistribution\Download"
if (Test-Path $DownloadPath) { Get-ChildItem $DownloadPath -Recurse -Force | Remove-Item -Recurse -Force }
cmd.exe /c "net start wuauserv"
$TempPaths = @("$env:TEMP", "$env:SystemRoot\Temp", "$env:SystemRoot\Prefetch")
foreach ($path in $TempPaths) {
    if (Test-Path $path) {
        Get-ChildItem $path -Recurse -Force | Where-Object { $_.FullName -notmatch "Browser|Chrome|Edge|Firefox|Opera|Brave|User Data" } | Remove-Item -Recurse -Force
    }
}
Clear-RecycleBin -Confirm:$false
```

### 8. Reset Folder Views & Restart Explorer
```powershell
Stop-Process -Name explorer -Force
Start-Sleep -Seconds 2
Remove-Item -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags" -Recurse -Force
Remove-Item -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU" -Recurse -Force
Start-Process "explorer.exe"
```

### 9. Disable Bing Search in Start Menu
```powershell
$ExplorerPoliciesPath = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
if (!(Test-Path $ExplorerPoliciesPath)) { New-Item -Path $ExplorerPoliciesPath -Force | Out-Null }
Set-ItemProperty -Path $ExplorerPoliciesPath -Name "DisableSearchBoxSuggestions" -Value 1 -Force
```

### 10. Disable Telemetry & Diagnostics
```powershell
Set-Service -Name "DiagTrack" -StartupType Disabled
Set-Service -Name "dmwappushservice" -StartupType Disabled
Stop-Service -Name "DiagTrack" -Force
Stop-Service -Name "dmwappushservice" -Force
```

### 11. Uninstall Microsoft OneDrive
```powershell
Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
$OneDriveSetup = "$env:SystemRoot\System32\OneDriveSetup.exe"
if (Test-Path $OneDriveSetup) { Start-Process $OneDriveSetup -ArgumentList "/uninstall" -Wait }
```

### 12. Restore Classic Context Menu (Win 11)
```powershell
$CLSIDPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
if (!(Test-Path $CLSIDPath)) { New-Item -Path $CLSIDPath -Force | Out-Null }
Set-ItemProperty -Path $CLSIDPath -Name "(Default)" -Value "" -Force
```

### 13. Disable Hibernation (Bebaskan SSD Space)
```powershell
powercfg -h off
```

### 14. Auto-Sync Time & Zone
```powershell
tzutil /s "SE Asia Standard Time"
Set-Service -Name "W32Time" -StartupType Automatic
Start-Service -Name "W32Time"
w32tm /resync
```

### 15. Disable Ads & Tips Suggestions
```powershell
$ContentDelivery = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
Set-ItemProperty -Path $ContentDelivery -Name "SubscribedContent-338387Enabled" -Value 0 -Force
Set-ItemProperty -Path $ContentDelivery -Name "SubscribedContent-338388Enabled" -Value 0 -Force
```

### 16. Win 11 Specific Taskbar Icons & Center Layout
```powershell
if ($IsWin11) {
    $AdvPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $AdvPath -Name "TaskbarDa" -Value 0 -Force
    Set-ItemProperty -Path $AdvPath -Name "TaskbarMn" -Value 0 -Force
    Set-ItemProperty -Path $AdvPath -Name "ShowTaskViewButton" -Value 0 -Force
    Set-ItemProperty -Path $AdvPath -Name "TaskbarAl" -Value 1 -Force
}
```

---

## 🛡️ Launcher & Keamanan Path (Anti-Crash)
Sintaks pembungkus (hybrid launcher) pada baris CMD batch paling atas **wajib** menggunakan metode yang kebal terhadap spasi dan apostrof (`'`) pada nama direktori (misal folder user `King's Sulaiman`).

### Struktur Pembungkus Batch Launcher:
```cmd
@echo off
:: [AUTO-ADMIN] Elevasi Hak Akses Administrator
set "SCRIPT_PATH=%~f0"
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $env:SCRIPT_PATH -Verb RunAs"
    exit /b
)

pushd "%~dp0"
title MEGAPASS Windows Optimizer v3.0 (GUI)
echo ===================================================
echo     MEGAPASS INTRA SOLUSINDO - WINDOWS OPTIMIZER
echo ===================================================
echo.
echo [*] Membuka Antarmuka Grafis (GUI)...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$c = (Get-Content -LiteralPath $env:SCRIPT_PATH -Raw) -split '# --- POWERSHELL ---'; iex $c[1]"
exit /b
```

---

## 🚦 Aturan Eksekusi di Latar Belakang (Non-Blocking GUI)
1. **Event Handling:** Ketika tombol *Jalankan Optimasi* tenta, GUI tidak boleh membeku (*hang/non-responsive*).
2. **Output Stream:** Teks logger di dalam aplikasi harus diperbarui secara real-time menggunakan string binding atau method `AppendText()` di textbox layout WPF untuk setiap modul yang sedang berjalan.
3. **Kepatuhan Format:**
   - 0 Byte NBSP (`0xA0`)
   - Line endings CRLF murni (`\r\n`)
   - Kompatibilitas penuh dengan PowerShell 5.1 bawaan Windows 10 & 11
