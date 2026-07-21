# PLAN.md - Cetak Biru MegaPass Windows Optimizer v3.0 (GUI Edition)

Dokumen ini berisi spesifikasi fungsional dan kebutuhan teknis untuk membangun kembali aplikasi **MegaPass-Optimizer.bat** menggunakan antarmuka grafis (GUI) interaktif. Dokumen ini dirancang sebagai panduan tingkat tinggi untuk LLM agar dapat mengimplementasikan solusi kode secara mandiri tanpa disetir oleh sintaks spesifik.

---

## 🎯 Tujuan Utama
Membuat satu file script hybrid (`.bat` pengeksekusi `.ps1` secara internal) berkinerja tinggi, **zero-dependency**, berjalan **100% offline**, dengan antarmuka grafis **WPF (Windows Presentation Foundation)** yang interaktif untuk memudahkan teknisi memilih fitur optimasi sesuai kebutuhan laptop/PC customer.

---

## 🏗️ Desain Antarmuka GUI (WPF XAML)
Aplikasi harus me-render GUI berbasis XAML gelap (Dark Mode) di memori menggunakan assembly `PresentationFramework` bawaan Windows:
1. **Windows Container:** Jendela utama (Dark Mode, ukuran proporsional).
2. **Title Header:** Judul utama aplikasi ("MEGAPASS Maintenance Utility v3.0").
3. **Panel Group:** Kumpulan checkbox pilihan optimasi dalam satu panel tata letak yang bersih.
4. **Log Console Box:** Kotak teks read-only di bagian bawah aplikasi untuk menampilkan log progress eksekusi secara real-time.
5. **Action Button:** Tombol eksekusi utama berlabel "[ JALANKAN OPTIMASI ]".

---

## ⚙️ Kebutuhan Fitur & Modul Optimasi (Sistem & UI)
Aplikasi harus menyediakan opsi penyesuaian berbasis angka (numbering) berikut kepada user untuk dieksekusi secara modular di latar belakang:

1. **Power Settings & Sleep Timeout:** Mengatur timeout layar & sleep menjadi 5 jam (AC/DC) dan mengaktifkan skema daya High Performance.
2. **Nonaktifkan Auto-Hide Taskbar:** Mengunci konfigurasi registry agar taskbar tidak hilang otomatis secara permanen.
3. **Visual Best Performance:** Mematikan animasi window, animasi taskbar, bayangan listview, dan menerapkan visual effect terbaik untuk performa.
4. **Nonaktifkan Windows Defender:** Mematikan fitur real-time monitoring, behavior monitoring, dan proteksi Defender via registry policies dan cmdlet.
5. **Pause Windows Updates:** Menunda pembaruan otomatis Windows Update jangka panjang hingga tanggal 31 Desember 2099.
6. **File Explorer & Desktop Tweaks:** Mengatur File Explorer agar default terbuka ke "This PC", mematikan history search/folder di Quick Access, dan memunculkan shortcut "This PC" di desktop.
7. **Pembersihan Cache & File Temp:** Mematikan service update sementara untuk membersihkan folder SoftwareDistribution\Download, menghapus folder temp user, temp system, prefetch, dns cache, winget cache, dan Recycle Bin secara aman *(pengecualian: folder data login/profile browser tidak boleh dihapus)*.
8. **Reset Layout Folder & Restart Explorer:** Merestart proses explorer dan menghapus cache registry Shell Bags/BagMRU untuk mereset tampilan tata letak folder ke default.
9. **Nonaktifkan Bing Search di Start Menu:** Mematikan saran pencarian web Bing di kolom pencarian menu Start.
10. **Nonaktifkan Telemetry & Diagnostics:** Mematikan service pengumpul data diagnostic data (`DiagTrack` & `dmwappushservice`) untuk menghemat RAM/CPU.
11. **Uninstall Microsoft OneDrive:** Menghentikan proses OneDrive dan melakukan uninstall client OneDrive secara bersih dari sistem.
12. **Tampilan Klik Kanan Klasik Windows 10 di Windows 11:** Memodifikasi registry CLSID untuk mengembalikan menu konteks klasik secara default (menghilangkan menu "Show more options").
13. **Nonaktifkan Hibernation:** Mematikan fitur hibernasi untuk menghapus file `hiberfil.sys` guna membebaskan ruang penyimpanan SSD C secara instan.
14. **Sinkronisasi Jam & Zona Waktu Otomatis:** Mengatur zona waktu default ke SE Asia Standard Time (WIB) dan mengaktifkan auto-sync waktu internet (Windows Time Service) untuk mencegah SSL browser error.
15. **Nonaktifkan Iklan & Saran Aplikasi:** Mematikan iklan saran aplikasi 3rd party dan tips yang muncul di menu Start dan halaman Settings.
16. **Konfigurasi Taskbar Khusus Windows 11:** Menyembunyikan icon Widgets, Chat, dan Task View, serta mengatur perataan taskbar agar tetap di tengah (Center).

---

## 🛡️ Persyaratan Launcher & Keamanan Path
1. **Kebal Karakter Khusus:** Launcher batch paling atas wajib menggunakan teknik yang kebal dari crash parsing jika nama folder/file mengandung spasi atau tanda kutip satu/apostrof (seperti `King's Sulaiman`).
2. **UAC Auto-Elevation:** Otomatis mendeteksi hak akses administrator saat diklik. Jika bukan admin, picu UAC prompt dengan meneruskan path file secara aman menggunakan format argument array (bukan string interpolation langsung yang rentan rusak).
3. **PowerShell Core Extraction:** Menggunakan dynamic splitter untuk memotong isi file batch dan memanggil bagian PowerShell menggunakan parameter path literal yang aman dari file-locking.

---

## 🚦 Aturan Eksekusi & Kualitas Kode
1. **Non-Blocking GUI:** Proses optimasi harus berjalan di thread latar belakang agar jendela GUI tidak hang/membeku saat tombol eksekusi ditekan.
2. **Real-Time Logger:** Setiap langkah modul yang berjalan wajib mengirimkan teks log progress-nya ke kotak teks console di GUI secara real-time.
3. **Kompatibilitas:** Seluruh kode PowerShell harus kompatibel penuh dengan PowerShell 5.1 bawaan Windows 10 & 11 (tidak menggunakan syntax PowerShell 7+).
4. **Kebersihan File:** File tidak boleh mengandung karakter Non-Breaking Space (NBSP) ilegal dan wajib berakhiran baris CRLF Windows murni.
