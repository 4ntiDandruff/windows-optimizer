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

### Khusus Windows 11 (Otomatis Aktif jika OS Win 11 Terdeteksi):
*   **[ ] Hide Widgets Icon** (Taskbar Widgets hidden)
*   **[ ] Hide Chat Icon** (Teams Chat hidden)
*   **[ ] Hide Task View Button** (Multi Windows button hidden)
*   *Catatan:* Layout Taskbar Alignment harus diatur **tetap di tengah (Center)** (`TaskbarAl = 1`).



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
1. **Event Handling:** Ketika tombol *Jalankan Optimasi* ditekan, GUI tidak boleh membeku (*hang/non-responsive*).
2. **Output Stream:** Teks logger di dalam aplikasi harus diperbarui secara real-time menggunakan string binding atau method `AppendText()` di textbox layout WPF untuk setiap modul yang sedang berjalan.
3. **Kepatuhan Format:**
   - 0 Byte NBSP (`0xA0`)
   - Line endings CRLF murni (`\r\n`)
   - Kompatibilitas penuh dengan PowerShell 5.1 bawaan Windows 10 & 11
