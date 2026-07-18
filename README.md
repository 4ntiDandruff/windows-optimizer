# 🚀 MegaPass Windows Optimizer v2.4

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

### 🧹 Pembersihan Bloatware
- **Microsoft bloatware**: Cortana, Xbox, Solitaire, OfficeHub, SkypeApp, FeedbackHub, GetHelp, ZuneVideo, ZuneMusic, 3DBuilder, MixedReality, OneNote, People, StickyNotes, BingWeather, BingNews, BingSports, BingFinance, YourPhone
- **Iklan 3rd party**: Disney, Spotify, TikTok, Instagram, CandyCrush, Facebook, Twitter, LinkedIn, Clipchamp, WhatsApp, ByteDance
- **Trial antivirus**: McAfee, Norton, Avast, AVG
- ⚠️ **Utility vendor TIDAK dihapus**: MyASUS, Lenovo Vantage, Dell SupportAssist, HP Support Assistant (berguna untuk update driver resmi)

### 🎨 Visual Performance
- Mengubah visual effects ke **Adjust for Best Performance**
- Mematikan animasi window, taskbar, listview shadow
- Registry tweak: `UserPreferencesMask`, `MinAnimate`, `TaskbarAnimations`

### 🛡️ Disable Windows Defender
- Menonaktifkan real-time protection via cmdlet `Set-MpPreference`
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

---

## 📦 Cara Pakai

1. **Download** atau clone repository ini
2. **Salin** file `MegaPass-Optimizer.bat` ke flashdisk / PC target
3. **Klik kanan** → **Run as Administrator** (atau double-click, UAC otomatis muncul)
4. **Tunggu** proses optimasi selesai
5. **Selesai** — PC siap digunakan customer

```
git clone https://github.com/4ntiDandruff/windows-optimizer.git
```

---

## 🏗️ Arsitektur Script

Script menggunakan teknik **Hybrid Batch + PowerShell** dalam satu file `.bat`:

```
┌─────────────────────────────────────┐
│  BATCH LAUNCHER (Baris 1-23)        │
│  - Deteksi hak akses Administrator  │
│  - Auto-elevasi UAC                 │
│  - Memanggil PowerShell via -split  │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  POWERSHELL ENGINE (Baris 25-177)   │
│  - Auto-detect Windows 10 / 11     │
│  - 11 modul optimasi               │
│  - Registry tweaks                  │
│  - Cache cleanup                    │
│  - Explorer safe relaunch           │
└─────────────────────────────────────┘
```

### 🔑 Teknologi Kunci
- **Dynamic Script Splitter**: Menggunakan `-split` berbasis string penanda, bukan nomor baris statis
- **DISM Single-Query**: Query provisioned packages sekali di luar loop untuk performa optimal
- **PS 5.1 Compatible**: Semua syntax kompatibel dengan PowerShell bawaan Windows

---

## 📋 Changelog

### v2.4 (Juli 2025)
- ✅ Single hybrid `.bat` file (gak perlu file tambahan)
- ✅ Modern UAC elevation (tanpa file `.vbs` sementara)
- ✅ Dynamic script splitter (kebal perubahan jumlah baris)
- ✅ Auto-detect Windows 10 / 11
- ✅ DISM query optimization (1x fetch, bukan 34x loop)
- ✅ PS 5.1 compatible syntax
- ✅ Safe explorer relaunch
- ✅ Zero NBSP, CRLF clean

---

## 👨‍💻 Author

**MEGAPASS Intra Solusindo**
Servis HP & Laptop Sidoarjo

---

## 📄 Lisensi

Bebas digunakan untuk keperluan internal servis dan maintenance workstation.
