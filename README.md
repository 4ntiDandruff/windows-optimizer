# 🚀 MegaPass Windows Optimizer v3.0.5

> Tool optimasi Windows 10 & 11 sekali klik untuk PC/laptop baru beli atau habis install ulang.
> Dibuat oleh **MEGAPASS Intra Solusindo** — Servis HP & Laptop Sidoarjo.

---

## 🎯 Tujuan

Mempercepat proses setup workstation customer dengan menghapus bloatware, mematikan fitur yang tidak perlu, dan mengoptimalkan performa sistem secara otomatis dalam satu kali klik.

---

## ✅ Fitur Lengkap

### ⚡ Power & Sleep
- Mengubah power plan ke **High Performance** (otomatis dibuat jika tidak tersedia)
- Timeout layar mati & sleep diset ke **5 jam** (colok listrik & baterai)

### 🔕 Do Not Disturb
- Mengaktifkan **Quiet Hours** (Windows 10) / **Focus Assist** (Windows 11)
- Mematikan semua toast notification global

### 🖥️ Windows 11 UI
- Menyembunyikan icon **Widgets** dari Taskbar
- Menyembunyikan icon **Chat (Teams)** dari Taskbar
- Menyembunyikan tombol **Task View (Multi Windows)** dari Taskbar
- Posisi Taskbar **tetap di tengah** (Center)

### 📌 Taskbar Behavior
- **Nonaktifkan auto-hide Taskbar** (taskbar selalu terlihat, tidak hilang otomatis)
- Registry tweak: `StuckRects3` binary data + `TaskbarAutoHideDesktop`

### 🧹 Pembersihan Bloatware
- **Microsoft bloatware**: Cortana, Xbox, Solitaire, OfficeHub, SkypeApp, FeedbackHub, GetHelp, ZuneVideo, ZuneMusic, 3DBuilder, MixedReality, OneNote, People, StickyNotes, BingWeather, BingNews, BingSports, BingFinance, YourPhone
- **Iklan 3rd party**: Disney, Spotify, TikTok, Instagram, CandyCrush, Facebook, Twitter, LinkedIn, Clipchamp, WhatsApp, ByteDance
- **Trial antivirus**: McAfee, Norton, Avast, AVG
- ⚠️ **Utility vendor TIDAK dihapus**: MyASUS, Lenovo Vantage, Dell SupportAssist, HP Support Assistant (berguna untuk update driver resmi)
- 📊 **Live Progress**: Menampilkan nama aplikasi yang sedang dihapus ke layar secara real-time.

### 🎨 Visual Performance
- Mengubah visual effects ke **Adjust for Best Performance**
- Mematikan animasi window, taskbar, listview shadow
- Registry tweak: `UserPreferencesMask`, `MinAnimate`, `TaskbarAnimations`

### 🛡️ Disable Windows Defender
- Web protection & real-time protection dimatikan via cmdlet `Set-MpPreference`
- Hard lock via registry Policies (`DisableAntiSpyware`, `DisableRealtimeMonitoring`)

### ⏸️ Pause Windows Update
- Menunda pembaruan otomatis hingga **31 Desember 2099**

### 📁 Folder Options
- File Explorer default terbuka ke **This PC**
- Mematikan tracking **recent files** dan **frequently used folders** di Quick Access
- Reset tampilan folder ke **default view**

### 🖱️ This PC Desktop Shortcut
- Memunculkan icon **This PC** di desktop via registry GUID

### 🗑️ Pembersihan Cache & Temp
- Membersihkan **winget cache** dan **DNS cache**
- Menghapus sisa file **Windows Update download cache**
- Membersihkan folder **temp user**, **temp system**, dan **prefetch**
- Mengosongkan **Recycle Bin**
- ✅ **Data browser aman** — folder Chrome, Edge, Firefox, Brave, Opera dikecualikan dari pembersihan

### 🔄 Explorer Auto-Restart
- Menghentikan `explorer.exe` untuk melepas lock registry Bags/BagMRU
- Mereset tampilan folder views
- Menjalankan kembali `explorer.exe` secara otomatis

---

## 💻 Kompatibilitas

| Item | Detail |
|------|--------|
| 🪟 OS | Windows 10 & Windows 11 |
| ⚙️ PowerShell | 5.1 (bawaan Windows) |
| 🌐 Internet | **Tidak diperlukan** (100% offline) |
| 🔐 Hak Akses | Administrator (otomatis diminta saat dijalankan) |
| 📄 Format File | CRLF (Windows native) |
| 👤 Username | ✅ **Kompatibel dengan username yang mengandung apostrophe, spasi & karakter khusus** |

---

## 📦 Cara Pakai

1. **Download** atau clone repository ini
2. **Salin** file `MegaPass-Optimizer.bat` ke flashdisk / PC target
3. **Klik kanan** → **Run as Administrator** (atau double-click, UAC otomatis muncul)
4. **Tunggu** proses optimasi selesai
5. **Selesai** — PC siap digunakan customer

```bash
git clone https://github.com/4ntiDandruff/windows-optimizer.git
```

---

## 🏗️ Arsitektur Script

Script menggunakan teknik **Hybrid Batch + PowerShell** dalam satu file `.bat`:

```
┌─────────────────────────────────────┐
│  BATCH LAUNCHER (Baris 1-23)        │
│  - Deteksi hak akses Administrator  │
│  - Auto-elevasi UAC (escaped path)  │
│  - Memanggil PowerShell via -split  │
│  - Path passing via $env:SCRIPT_PATH│
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  POWERSHELL ENGINE (Baris 25+)      │
│  - Auto-detect Windows 10 / 11     │
│  - 12 modul optimasi               │
│  - Registry tweaks                  │
│  - Cache cleanup                    │
│  - Explorer safe relaunch           │
└─────────────────────────────────────┘
```

---

## 🐛 Changelog

### v3.0.5 (Juli 2026)
- 👑 **BULLETPROOF UAC PATH ESCAPING**: Menggunakan kombinasi escape backtick PowerShell (`` `"` ``) dan double quotes CMD untuk meloloskan `$env:SCRIPT_PATH` saat UAC elevation. Mencegah kegagalan start proses elevated jika folder instalasi mengandung karakter spasi atau apostrof (`'`).
- ⚡ **COMPATIBLE ARRAY CASTING**: Mengubah penulisan cast binary array `UserPreferencesMask` menggunakan syntax yang dijamin didukung oleh seluruh edisi PowerShell 5.1.
- 🧹 Bersih dari byte non-breaking space (NBSP) ilegal dan berakhiran CRLF murni.

---

## 👨‍💻 Author

**MEGAPASS Intra Solusindo**  
Servis HP & Laptop Sidoarjo

---

## 📄 Lisensi

Bebas digunakan untuk keperluan internal servis dan maintenance workstation.
