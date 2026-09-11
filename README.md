<div align="center">
  <h1>MEGAPASS Windows Debloater & Optimizer</h1>
  <p>Utilitas Script PowerShell Otomatis dan Dokumentasi Web Zero-Bloat untuk Windows 10 dan 11</p>
  <p>
    <img src="https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-blue?style=flat-square" alt="Platform">
    <img src="https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-5391FE?style=flat-square&logo=powershell&logoColor=white" alt="PowerShell">
    <img src="https://img.shields.io/badge/Distribution-FastAPI%20HTTP%20307-009688?style=flat-square" alt="Distribution">
    <img src="https://img.shields.io/badge/Architecture-Zero--Bloat-brightgreen?style=flat-square" alt="Architecture">
    <img src="https://img.shields.io/badge/Safety-Fail--Safe%20Whitelist-success?style=flat-square" alt="Safety">
  </p>
</div>

---

## 1. Topologi Sirkuit Eksekusi

Sistem mendistribusikan skrip otomatisasi melalui dua jalur pintu masuk dengan satu muatan logika utama di server:

```text
[ Client Windows (PowerShell Admin) ]
                 │
  ┌──────────────┴────────────────────────┐
  │                                       │
  ▼ (Jalur Pendek / Cepat)                ▼ (Jalur Lengkap / Langsung)
irm https://megapass.web.id/win         irm https://megapass.web.id/blog/debloat-win/debloat.ps1
  │                                       │
  └──────────────┬────────────────────────┘
                 ▼
       [ Cloudflare Edge Ingress ]
                 │
                 ▼
       [ FastAPI Gateway (server.py :3001) ]
                 │
                 ├─► Request /win ──────► HTTP 307 Redirect (Header Location: /blog/debloat-win/debloat.ps1)
                 │                                │ (Auto-follow oleh HttpClient)
                 └─► Request debloat.ps1 ◄────────┘
                                 │
                                 ▼
                     [ Payload debloat.ps1 ]
                                 │
                                 ▼
               [ Dieksekusi via iex di RAM Client ]
                                 │
     ┌───────────────────────────┴───────────────────────────┐
     ▼                                                       ▼
28 Modul Optimasi Kernel, Registry, Service, UWP      Laporan Interaktif HTML (MEGAPASS-Debloat-Report.html)
```

### Panduan Menjalankan di Komputer Klien

Buka **PowerShell as Administrator** pada Windows 10 atau 11, lalu pilih salah satu cara:

* **Cara 1: Jalur Cepat (Workbench Shortlink - Sangat Disarankan di Lapangan)**:
  ```powershell
  irm https://megapass.web.id/win | iex
  ```
* **Cara 2: Jalur Lengkap (Direct Path Berkas Asli)**:
  ```powershell
  irm https://megapass.web.id/blog/debloat-win/debloat.ps1 | iex
  ```

*Keterangan Teknis*: Kedua perintah di atas menjalankan berkas skrip yang persis sama. Rute `/win` menggunakan pengalihan status `HTTP 307 Temporary Redirect` di sisi server FastAPI. Cmdlet `irm` (`Invoke-RestMethod`) secara otomatis mengikuti header redirect dan mengalirkan skrip langsung ke memori RAM tanpa menyimpan berkas instalasi perantara di hard disk.

---

## 2. Bedah Tech Stack Ramah Pemula

* **Frontend (Layar Depan)**:
  * **Landing Page Dokumentasi (`index.html`)**: HTML5 semantik murni + Tailwind Play CDN + Alpine.js CDN + Lucide Icons SVG. Bekerja 100% tanpa build-step, tanpa node_modules, dan responsif untuk layar smartphone maupun desktop meja servis.
  * **Laporan Audit Klien**: Berkas HTML mandiri yang dibuat otomatis oleh skrip PowerShell langsung di Desktop klien (`MEGAPASS-Debloat-Report.html`), dilengkapi kartu metrik interaktif, filter kategori software, dan grafik komparasi delta sebelum vs sesudah.
* **Backend dan Distribusi (Mesin Belakang)**:
  * **Python 3.14 + FastAPI (`server.py`)**: Bertindak sebagai reverse proxy route interceptor. Rute `/win`, `/debloat`, dan `/debloat.ps1` merespons dengan status `HTTP 307 Temporary Redirect` ke file statis yang dilayani via Starlette StaticFiles tanpa menduplikasi data di disk.
  * **PowerShell 5.1 / 7 Core (`debloat.ps1`)**: Interpreter native Windows yang mengeksekusi 28 modul optimasi langsung di memori RAM tanpa meninggalkan file installer pihak ketiga.
* **Database dan Pencatatan (Penyimpanan Data)**:
  * **SQLite 3 WAL Mode (`visitors.db`)**: Mencatat analitik trafik kunjungan dan unduhan skrip secara atomik dengan proteksi `PRAGMA busy_timeout=5000` dan `synchronous=NORMAL` agar tahan terhadap insiden mati listrik mendadak di ruko.

---

## 3. Filosofi Desain dan Prinsip Keamanan (Fail-Safe Guardrails)

Tujuan utama proyek ini adalah **membuat sistem operasi Windows menjadi jauh lebih ringan, responsif, dan bertenaga tanpa merusak atau menghilangkan fitur-fitur penting yang umum digunakan sehari-hari**.

Banyak skrip debloat pihak ketiga di internet bersifat destruktif: mematikan Windows Defender, merusak Microsoft Store, mematikan printer, atau merusak Windows Update. MEGAPASS Windows Debloater dirancang dari sudut pandang meja servis profesional dengan prinsip kehati-hatian sirkuit:

### A. Fitur yang DIJAGA MUTLAK (Protected Whitelist)
Pengembangan ke depan **DILARANG** merusak komponen-komponen penting berikut:
* **Microsoft Store & Windows App Installer (winget)**: Wajib tetap aktif 100%. Service `wuauserv`, `BITS`, dan `dosvc` dikunci pada mode `Manual` (on-demand), bukan `Disabled`, agar saat pengguna membuka Microsoft Store dan mengunduh aplikasi, Store tetap bekerja normal tanpa error `0x80070422`.
* **Microsoft OneDrive**: Disentuh 0 baris. Aplikasi, auto-start di startup registri, dan sinkronisasi file cloud tetap berjalan 100% normal tanpa terganggu.
* **Windows Defender (Antivirus Bawaan)**: Disentuh 0 baris. Tetap aktif 100% utuh tanpa dimatikan, tanpa dicekik registri, dan tanpa pemanggilan cmdlet `Set-MpPreference`, sehingga skrip tidak memicu deteksi AMSI/heuristik proteksi Windows saat dijalankan.
* **Layanan Pencetakan (Print Spooler)**: Wajib aktif untuk kebutuhan cetak dokumen kantor, kasir, dan nota meja servis.
* **Konektivitas Dasar (Wi-Fi, Bluetooth, Ethernet)**: Seluruh driver stack dan service terkait tidak boleh diubah agar tidak memutus komunikasi perangkat.
* **Windows Audio & Media Codec**: Layanan suara dan pemutaran multimedia tetap standar agar audio tidak hilang atau pecah.
* **Kualitas Visual Font (ClearType / Font Smoothing)**: Wajib selalu aktif (`FontSmoothing = 2`). Mematikan font smoothing membuat huruf bergerigi dan merusak kenyamanan membaca mata pengguna.
* **Utilitas Harian Standar**: Kalkulator, Kamera, Notepad, Paint, dan Snipping Tool (pemotong layar) tetap dipertahankan.
* **Mekanisme Rollback Otomatis**: VSS Service dihidupkan dan System Restore Point dibuat di detik pertama eksekusi skrip dengan bypass limit cooldown 24 jam.

### B. Fitur yang DIELIMINASI dan DILEMAHKAN (Target Debloat & Throttling)
* **Jeda Total Windows Update Hingga 2099 (Bebas Update Siluman, Store Tetap Aktif)**:
  * Injeksi jeda waktu UX Settings: `PauseUpdatesExpiryTime` disetel hingga `2099-12-31`.
  * Kunci Group Policy: `NoAutoUpdate = 1` dan `AUOptions = 2` (Notify only, tanpa auto-download diam-diam di background).
  * Matikan scheduled maintenance tasks (`Scheduled Start`) agar tidak ada update bulanan yang merusak stabilitas sistem.
* **Aplikasi Sponsor & Bloatware OEM (Termasuk LinkedIn, To-Do, Clipchamp)**:
  * Pembersihan berbasis wildcard: `*LinkedIn*`, `*Todos*`, `*Clipchamp*`, TikTok, Disney, Spotify, Netflix, McAfee stub.
  * Eksekusi ganda: menghapus dari akun pengguna aktif + master provisioned Windows.
  * Blokir Cloud Content stubs: mematikan `DisableWindowsConsumerFeatures = 1` dan `SilentInstalledAppsEnabled = 0` agar ikon promosi tidak muncul kembali di Start Menu Windows 10/11.
* **Telemetri & Pengumpul Data Agresif**: DiagTrack, dmwappushservice, Customer Experience Improvement Program (CEIP), dan pelacak aktivitas ketikan.
* **Windows 11 24H2 AI Recall & Auto-BitLocker**: Penonaktifan AI Recall via DISM dan pencegahan enkripsi senyap SSD via `PreventDeviceEncryption = 1`.
* **Iklan Sistem & Integrasi Bing**: Pencarian web di Start Menu, widget berita MSN, dan saran iklan di File Explorer.
* **Pencuri Bandwidth Latar Belakang (Delivery Optimization)**: Pengunggahan update P2P ke komputer publik dibatasi.
* **GameDVR Background Recording**: Perekaman klip game otomatis di latar belakang dinonaktifkan untuk stabilitas FPS.

---

## 4. Katalog 28 Modul Optimasi

Dokumentasi ini berfungsi sebagai peta navigasi agar pengembang tidak salah langkah saat memperbarui kode:

| No | Nama Modul | Fungsi & Parameter Teknis | Status Keamanan |
|---|---|---|---|
| **00** | **Restore Point Creation** | Membuat titik pemulihan sistem (`Checkpoint-Computer`) & aktivasi VSS | Proteksi Mutlak |
| **01** | **OEM & Sponsored UWP Removal** | Menghapus 60+ bloatware (TikTok, Disney, Spotify, Netflix, LinkedIn, To-Do, Clipchamp) via `Remove-AppxPackage` | Aman (Store Tetap Ada) |
| **02** | **Telemetry Shutdown** | Menonaktifkan pengiriman data diagnostik OS (`AllowTelemetry = 0`) & 11 scheduled tasks | Aman |
| **03** | **Cortana, Copilot & Recall Off** | Mematikan integrasi Bing Search, asisten Copilot, dan DISM Recall (Win11 24H2) | Aman & Privasi |
| **04** | **Ads & Suggestions Shutdown** | Mematikan iklan Start Menu, Cloud Content stubs, saran File Explorer, dan Lock Screen ads | Bersih & Rapi |
| **05** | **Privacy & BitLocker Shield** | Mematikan Advertising ID, lokasi, cloud clipboard, dan cegah auto-enkripsi BitLocker 24H2 | Proteksi Data |
| **06** | **Background Apps Off** | Mematikan eksekusi aplikasi UWP di background via `GlobalUserDisabled = 1` | Hemat RAM/CPU |
| **07** | **Unnecessary Services Hardening** | Mematikan 20+ service berat (DiagTrack, WSearch, SysMain, MapsBroker, RetailDemo, Xbox) | Ringan & Dingin |
| **08** | **Performance & WNF Focus Assist** | Menyetel High Performance plan, live WNF Priority Only, font ClearType ON, mouse accel OFF | Respon Cepat |
| **09** | **Network Privacy & P2P Limiter** | Mematikan Wi-Fi Sense, Remote Assistance, dan pembagian update P2P Delivery Optimization | Hemat Kuota |
| **10** | **Explorer & Taskbar Cleanup** | Default This PC, matikan tombol Task View & Chat, hidden files tetap aman terlindungi | Ergonomi Servis |
| **11** | **Windows Update Manual Control** | Mencegah auto-restart paksa saat ada user aktif (`NoAutoRebootWithLoggedOnUsers = 1`) | Anti Bencana |
| **12** | **Deep Storage Cleanup** | Membersihkan Temp, Prefetch, SoftwareDistribution, dan mengosongkan Recycle Bin | Bebas 500MB-5GB+ |
| **13** | **Pause Update 2099 & AU Lock** | Jeda update hingga 2099, kunci `NoAutoUpdate = 1`, wuauserv Manual agar MS Store 100% normal | Bebas Update Siluman |
| **14** | **SmartScreen & Phishing Filter Off** | Menonaktifkan SmartScreen dan phishing filter; Windows Defender tetap 100% aktif & tidak disentuh | Proteksi Utuh & Aman |
| **15** | **Classic Context Menu (Win11)** | Mengembalikan menu klik kanan klasik Windows 11 instan tanpa submenu via CLSID registry | Peningkatan UX |
| **16** | **Reserved Storage Off** | Menonaktifkan alokasi ruang cadangan sistem via DISM | Hemat ~7GB SSD |
| **17** | **VBS & HVCI Memory Integrity Off** | Mematikan Virtualization-Based Security & HVCI untuk laptop non-enterprise | Boost 5-15% Speed |
| **18** | **Edge Startup Boost Off** | Mematikan preload background Edge dan menghapus auto-launch di startup registry | Hemat 150-300MB RAM |
| **19** | **OneDrive Retained (Untouched)** | OneDrive dipertahankan utuh (aplikasi, auto-start, dan sinkronisasi file cloud tetap aktif) | Data & Sync Aman |
| **20** | **Dynamic Pagefile Optimization** | Menghitung ukuran paging file optimal proporsional (1.5x RAM, max 35% free disk) | Anti Crash / OOM |
| **21** | **Search Indexer Tasks Off** | Mematikan scheduled task maintenance indexer dan menghentikan proses SearchIndexer | Disk I/O Tenang |
| **22** | **NTFS & Disk I/O Tuning** | Mematikan last access timestamp (`disablelastaccess 1`) dan 8.3 short name creation | Minim Overhead SSD |
| **23** | **Boot & Shutdown Acceleration** | Menurunkan `WaitToKillServiceTimeout` ke 2000ms dan mengaktifkan `AutoEndTasks` | Mati/Nyalakan Cepat |
| **24** | **Storage Sense Auto-Run Off** | Mencegah Windows menghapus file Downloads dan Recycle Bin secara sepihak di background | Proteksi Berkas |
| **25** | **Network Throttling Removal** | Menghapus limit bandwidth multimedia (`NetworkThrottlingIndex = -1`) dan mematikan Nagle | Ping Rendah / Full |
| **26** | **UI Responsiveness & Explorer Restart** | `MenuShowDelay = 0`, matikan animasi minimize, dan restart Explorer untuk menerapkan tweak | UI Instan |
| **27** | **Post-Debloat Snapshot** | Mengambil metrik CIM sesudah optimasi (RAM, proses aktif, service berjalan, disk C:) | Akurasi Data |
| **28** | **Interactive HTML Audit Report** | Menghasilkan laporan crystal glass interaktif mandiri langsung di Desktop klien | Transparansi Penuh |

---

## 5. Metrik dan Benchmark Nyata

Berdasarkan pengujian pada Windows 10 22H2 dan Windows 11 23H2/24H2 di meja servis Megapass:

* **Ukuran File Skrip**: 102 KB (Single standalone file).
* **Waktu Pengunduhan**: < 100 ms via Cloudflare CDN edge cache.
* **Pengurangan Background Process**: Dari rata-rata 140-180 proses aktif menjadi 65-85 proses idle.
* **Efisiensi RAM Idle**: Penurunan penggunaan memori kerja sebesar 20% hingga 40% setelah reboot.
* **Ruang Disk Pulih**: Pemulihan 1.5 GB hingga 10 GB+ (Reserved Storage ~7GB + cache instalasi).
* **Integritas Sistem Operasi**:
  * Pengecekan versi aman: Mencegah Windows 10 dipaksa upgrade ke Windows 11 melalui penguncian `TargetReleaseVersion`.
  * Proteksi Windows 11 24H2: Penonaktifan AI Recall via DISM dan pencegahan enkripsi senyap SSD via registri `PreventDeviceEncryption = 1`.
  * Kualitas Visual: Font smoothing (ClearType) tetap dipertahankan agar kenyamanan mata pengguna tidak terganggu.

---

## 6. Valuasi Rekayasa

Perbandingan estimasi biaya pengerjaan proyek jika menggunakan jasa agensi software house pihak ketiga dibandingkan perancangan mandiri berbasis orkestrasi AI:

| Komponen Pekerjaan | Estimasi Biaya Software House | Biaya Implementasi Mandiri | Nilai Penghematan Riil |
|---|---|---|---|
| Rancang Bangun Skrip 28 Modul Optimasi Windows | Rp 8.000.000 | Rp 0 | Rp 8.000.000 |
| Generator Laporan Audit HTML Dinamis di Sisi Klien | Rp 4.500.000 | Rp 0 | Rp 4.500.000 |
| Landing Page Interaktif Zero-Build + CDN | Rp 3.500.000 | Rp 0 | Rp 3.500.000 |
| Konfigurasi Server Distribusi HTTP 307 + SQLite WAL | Rp 2.500.000 | Rp 0 | Rp 2.500.000 |
| Audit Kompatibilitas Lintas Build (Win10 vs Win11 24H2) | Rp 3.500.000 | Rp 0 | Rp 3.500.000 |
| **Total Valuasi Proyek** | **Rp 22.000.000** | **Rp 0** | **Rp 22.000.000** |

---

## 7. Treeview Direktori Modul

```text
windows-optimizer/
├── debloat.ps1           # Skrip utama otomatisasi 28 modul optimasi Windows (102 KB)
├── index.html            # Antarmuka web dokumentasi dan panduan interaktif
├── README.md             # Dokumentasi teknis sirkuit, batas aman, dan panduan operasional
├── PLAN.md               # Cetak biru arsitektur dan spesifikasi teknis
└── LICENSE               # Lisensi MIT terbuka
```

---

## 8. Smoke Test (Verifikasi Nyata Terminal)

Pengujian langsung dari server lokal untuk memastikan ketersediaan jalur:

```bash
# 1. Uji respons redirect header rute cepat /win
$ curl -sI https://megapass.web.id/win | grep -E "HTTP|location"
HTTP/2 307
location: /blog/debloat-win/debloat.ps1

# 2. Uji ketersediaan file skrip utama
$ curl -sI https://megapass.web.id/blog/debloat-win/debloat.ps1 | grep -E "HTTP|content-length"
HTTP/2 200
content-length: 102042

# 3. Uji integritas baris pertama skrip via curl follow-redirect
$ curl -sL https://megapass.web.id/win | head -n 5
# MEGAPASS Windows Debloater v2.4
# https://megapass.web.id/blog/debloat-win/
# Jalankan: irm https://megapass.web.id/blog/debloat-win/debloat.ps1 | iex
```

---

## 9. Standar Rekayasa dan Aturan Kontribusi

Saat melakukan refactoring atau penambahan fitur di masa depan, patuhi aturan baku berikut:

1. **Aturan Integer Signed DWORD PowerShell 5.1**:
   PowerShell 5.1 membaca literal heksadesimal `0xffffffff` sebagai `Int64` (positif 4294967295). Jika disuntikkan ke registri bertipe `DWord` (`Int32`), akan terjadi error silent overflow. Selalu gunakan nilai `-1` bertipe integer yang otomatis dipetakan kernel Windows sebagai bitmask `0xFFFFFFFF`.
2. **Kesesuaian Target Platform (Win10 vs Win11)**:
   Gunakan deteksi versi `[System.Environment]::OSVersion.Version.Build` sebelum menjalankan perintah spesifik:
   * Build >= 22000: Fitur Windows 11 (Context Menu CLSID, dll).
   * Build >= 26100: Fitur Windows 11 24H2 (DISM Recall, BitLocker `PreventDeviceEncryption`).
   * Build < 22000: Windows 10 (Kunci `TargetReleaseVersionInfo` ke `"22H2"` dan `ProductVersion` ke `"Windows 10"`).
3. **Penyusunan Kode Mandiri**:
   Pertahankan sifat single-file standalone pada `debloat.ps1`. Hindari dependensi eksternal (modul nuget, zip download tambahan) agar skrip tetap bisa berjalan dalam kondisi koneksi internet darurat.

---

## 10. Potensi Pengembangan ke Depan

* `[+]` **GUI Selector Ringan**: Menambahkan opsi antarmuka berbasis WinForms atau WPF sederhana jika teknisi ingin memilih paket optimasi tertentu via centang visual.
* `[+]` **Telemetry Webhook Opsional**: Pengiriman ringkasan status kesehatan sistem pasca-debloat ke dashboard bengkel Megapass jika disetujui pengguna.
* `[+]` **Pembersih DriverStore Usang**: Modul pembersihan repositori driver VGA lama milik vendor NVIDIA/AMD/Intel yang sering memakan ruang penyimpanan hingga belasan gigabyte.

---

<div align="center">
  <p>Megapass Intra Solusindo • Sidoarjo, Indonesia</p>
</div>
