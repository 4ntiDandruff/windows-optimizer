# PLAN.md - Cetak Biru MEGAPASS Windows Optimizer & Debloater

Dokumen ini berisi arsitektur rekayasa sirkuit dan roadmap pengembangan aplikasi **MEGAPASS Windows Optimizer** oleh Megapass Intra Solusindo, Sidoarjo.

---

## 🎯 Visi & Landasan Filosofis
Membuat sistem operasi Windows 10 dan Windows 11 bekerja dengan performa maksimal, latensi rendah, dan hemat sumber daya (RAM/CPU/Disk) melalui pendekatan **fail-safe meja servis**:
1. **Zero-Bloat & Zero-Dependency:** Berjalan mandiri langsung di memori RAM via `irm https://megapass.web.id/win | iex`.
2. **Protected Whitelist Mutlak:** Dilarang merusak Windows Defender, Microsoft Store, OneDrive, Print Spooler, Network Stack, Audio, dan font smoothing ClearType.
3. **Rollback Sekring:** Wajib membuat System Restore Point di detik pertama eksekusi sebelum modifikasi apapun diterapkan.

---

## 🗺️ Roadmap Pengembangan

### Fase 1: CLI Core Engine (v2.4 - SELESAI & AKTIF DI PRODUKSI)
- [x] Runtime Administrator Privilege Guard.
- [x] Pembuatan System Restore Point otomatis (VSS on, bypass 24h limit).
- [x] Pembersihan 60+ bloatware UWP sponsor/OEM ganda (akun aktif + master provisioned).
- [x] Normalisasi & jeda Windows Update hingga tahun 2099 tanpa merusak Microsoft Store (`wuauserv` mode Manual).
- [x] Proteksi Windows Defender 100% utuh (disentuh 0 baris, bebas blokir AMSI).
- [x] Microsoft OneDrive dipertahankan utuh (aplikasi, startup, dan sinkronisasi cloud aktif normal).
- [x] Penonaktifan 20+ service latar belakang yang tidak diperlukan.
- [x] Optimasi memori virtual (pagefile) proporsional 1.5x RAM fisik dibatasi 35% sisa ruang disk C:.
- [x] Akselerasi I/O disk NTFS (`disablelastaccess`, `disable8dot3`).
- [x] Pembebasan Reserved Storage (~7 GB) via DISM.
- [x] Penonaktifan VBS & Memory Integrity (HVCI) untuk dongkrak performa 5-15%.
- [x] Penonaktifan AI Recall via DISM dan pencegahan enkripsi senyap SSD BitLocker di Windows 11 24H2.
- [x] Network latency optimization (Nagle algorithm off, TCPNoDelay, NetworkThrottlingIndex off).
- [x] Generator laporan audit crystal glass interaktif mandiri langsung di Desktop klien.
- [x] Gateway distribusi pipa HTTP 307 FastAPI di `megapass.web.id/win`.

### Fase 2: Standalone Repository & Komunitas (v2.5 - SAAT INI)
- [x] Pemisahan ke repository publik GitHub `4ntiDandruff/windows-optimizer`.
- [x] Dokumentasi teknis terstandarisasi Universal Operator Directive (R8).
- [x] Lisensi MIT terbuka untuk komunitas teknisi hardware & sysadmin Indonesia.

### Fase 3: Interactive GUI Edition (v3.0 - MASA DEPAN)
- [ ] Implementasi antarmuka visual native berbasis WPF XAML / WinForms ringan tanpa runtime tambahan.
- [ ] Fitur checkbox modular: Teknisi dapat memilih paket optimasi tertentu (misal: Mode Gaming, Mode Kantor Kasir, Mode Servis Santai).
- [ ] Console output box real-time terintegrasi di dalam jendela aplikasi.
- [ ] Tombol **`[ KEMBALIKAN KE DEFAULT ]`** untuk memicu rollback otomatis via System Restore Point `rstrui`.
- [ ] Pembersih DriverStore usang (membersihkan cache installer driver VGA NVIDIA/AMD/Intel puluhan GB).

---

<div align="center">
  <p>Megapass Intra Solusindo • Sidoarjo, Indonesia</p>
</div>
