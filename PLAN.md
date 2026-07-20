# PLAN.md - Spesifikasi Teknis & Panduan Rebuild MegaPass Windows Optimizer v3.0

Dokumen ini dirancang sebagai panduan instruksi (context anchor) bagi LLM berspesifikasi tinggi (seperti Claude 3.5 Sonnet / Claude 3 Opus) untuk memprogram ulang `MegaPass-Optimizer.bat` dari nol secara sempurna tanpa bug sintaks atau logika.

---

## 🎯 Tujuan Utama
Membuat satu file script hybrid (`.bat` yang mengeksekusi `.ps1` secara internal) berkinerja tinggi, tanpa dependensi eksternal, berjalan 100% offline, meminta hak akses administrator secara otomatis saat dibuka, dan kebal terhadap error path spasial (spasi, tanda kutip satu/apostrof, tanda dollar, dll).

---

## ⚠️ Kendala Kritis & Solusi (Wajib Diikuti)
Masalah terbesar pada versi sebelumnya adalah **sintaks pembungkus (hybrid launcher)** yang pecah ketika dijalankan dari direktori yang jalurnya mengandung spasi atau tanda kutip satu (misalnya: `C:\Users\King's Sulaiman\Downloads`).

### Solusi Arsitektur Launcher:
Untuk menghindari parsing string literal yang rentan rusak di CMD/PowerShell, gunakan metode di bawah ini:

1. **Simpan Path ke Env Var:**
   Di level Batch (CMD), simpan path absolut `%~f0` ke environment variable:
   ```cmd
   set "SCRIPT_PATH=%~f0"
   ```
2. **UAC Elevation via Argument Array:**
   Picu elevasi UAC menggunakan argumen terpisah di PowerShell `Start-Process` agar spasi dibungkus otomatis oleh API Windows secara aman:
   ```cmd
   powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $env:SCRIPT_PATH -Verb RunAs"
   ```
3. **PowerShell Extraction via LiteralPath & Raw:**
   Di level CMD elevated, panggil PowerShell kembali untuk mengekstrak dan menjalankan bagian PowerShell-nya menggunakan penanda pemisah:
   ```cmd
   powershell -NoProfile -ExecutionPolicy Bypass -Command "$c = (Get-Content -LiteralPath $env:SCRIPT_PATH -Raw) -split '# --- POWERSHELL ---'; iex $c[1]"
   ```

---

## 📋 Spesifikasi 12 Modul Optimasi (Pure PowerShell)

### 1. Deteksi OS & Kompatibilitas
- Deteksi Windows 10 vs 11 menggunakan build version: `$IsWin11 = [System.Environment]::OSVersion.Version.Build -ge 22000`
- Semua sintaks harus kompatibel dengan **PowerShell 5.1** bawaan (tidak menggunakan operator PS7+ seperti ternary `$x = a ? b : c` atau null-coalescing `??`).

### 2. Skema Daya & Sleep Timeout
- Mengaktifkan skema *High Performance* (GUID: `8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c`). Jika GUID hilang, buat duplikatnya terlebih dahulu: `powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c`.
- Setel timeout layar dan standby (sleep) ke 300 menit (5 jam) untuk AC & DC.

### 3. Focus Assist (Quiet Mode)
- Setel Focus Assist ke status "Alarms Only" (value: 2) via registry: `HKCU:\Software\Microsoft\Windows\CurrentVersion\FocusAssist` -> `FocusAssistState`.
- Matikan notifikasi toast secara global: `HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings` -> `NOC_GLOBAL_SETTING_TOASTS_ENABLED = 0`.

### 4. Windows 11 UI Layout
- Khusus Windows 11, sembunyikan Widgets (`TaskbarDa = 0`), Chat (`TaskbarMn = 0`), dan Task View (`ShowTaskViewButton = 0`).
- Layout alignment Taskbar harus diatur **tetap di tengah (Center)** (`TaskbarAl = 1`).

### 5. Disable Taskbar Auto-Hide
- Atur properti `TaskbarAutoHideDesktop = 0` di registry Advanced.
- Ubah bit binary registry `StuckRects3` di key `Settings` (Clear bit 0 pada byte ke-9 / index 8) agar taskbar tidak hilang otomatis.

### 6. Safe Bloatware Uninstall dengan Live Progress
- Definisikan list bloatware UWP apps & 3rd party ads (Xbox, Cortana, Disney, TikTok, Spotify, McAfee, Norton, dkk).
- **PENTING:** Jangan hapus utility vendor resmi laptop (MyASUS, Lenovo Vantage, Dell SupportAssist, HP Support Assistant).
- **Optimasi DISM:** Jalankan `Get-AppxProvisionedPackage -Online` satu kali saja di awal loop (cache di memori) untuk menghindari lag 1 menit.
- Tampilkan visual log per aplikasi yang sedang dihapus (`Write-Host "  [-] Processing: ... "`) agar console interaktif dan tidak terkesan "bengong".

### 7. Performance Visual Tweaks
- Setel Visual Effects ke "Adjust for Best Performance" (`VisualFXSetting = 2`).
- Setel binary `UserPreferencesMask` menggunakan cast array byte yang valid di PS 5.1: `[byte[]]$mask = @(144,20,7,128,16,0,0,0)`.
- Matikan animasi window (`MinAnimate = 0`) dan taskbar animations (`TaskbarAnimations = 0`).

### 8. Disable Windows Defender
- Matikan real-time, behavior, IOAV, signature update on startup, archive, intrusion, dan script scanning via cmdlet `Set-MpPreference`.
- Kunci melalui registry Policies di `Windows Defender` dan `Real-Time Protection` (`DisableAntiSpyware = 1`, `DisableRealtimeMonitoring = 1`).

### 9. Pause Windows Updates
- Menunda update otomatis jangka panjang dengan mengunci nilai registry `PauseUpdatesExpiryTime` ke `2099-12-31T23:59:59Z`.

### 10. Folder Options Settings
- Setel File Explorer agar otomatis terbuka ke halaman "This PC" (`LaunchTo = 1`).
- Matikan tracking files/folders di Quick Access (`ShowRecent = 0`, `ShowFrequent = 0`).
- Munculkan icon shortcut "This PC" di desktop via registry HideDesktopIcons.

### 11. Sterilisasi System Cache & Temp
- Bersihkan winget cache dan DNS cache.
- Stop service `wuauserv` menggunakan command line `cmd.exe /c "net stop wuauserv /y"` (dengan timeout) untuk membersihkan folder `SoftwareDistribution\Download`. Jalankan kembali service setelahnya.
- Hapus folder temp user (`$env:TEMP`), temp system, dan prefetch.
- **PENTING:** Jangan hapus folder data profiling browser (Chrome, Edge, Firefox, Brave, Opera) agar data login customer tidak ter-logout.
- Kosongkan Recycle Bin secara paksa (`Clear-RecycleBin -Confirm:$false`).

### 12. Explorer Relaunch & Bags Reset
- Hentikan proses `explorer.exe` secara paksa (`Stop-Process -Name explorer -Force`).
- Hapus registry folder view layout cache (`Bags` & `BagMRU`) untuk mereset visual folder.
- Jalankan kembali `explorer.exe` secara normal (`Start-Process "explorer.exe"`).

---

## 🚦 Kriteria Kepatuhan & Kualitas (Checklist Pengujian)
Sebelum script disebarkan, pastikan kode memenuhi kriteria berikut:
1. **0 Byte NBSP:** File tidak boleh mengandung karakter Non-Breaking Space (`0xA0`) ilegal di indentasinya.
2. **Line Endings CRLF:** File wajib menggunakan format baris Windows (`\r\n`).
3. **PowerShell 5.1 Compatible:** Tidak boleh ada runtime crash akibat pemanggilan syntax modern PS7+.
4. **Pause di Akhir CMD:** Pastikan Batch diakhiri dengan `pause` dan tidak melakukan *auto-close* sepihak sebelum teknisi selesai membaca log sukses.
