# Flavenz Kernel untuk Xiaomi POCO F6 (Peridot)

<div align="center">

[![Kernel Version](https://img.shields.io/badge/Kernel-6.1.138-blue.svg)](https://kernel.org)
[![Android](https://img.shields.io/badge/Android-14%2F15%2F16-green.svg)](https://android.com)
[![Device](https://img.shields.io/badge/Device-Xiaomi%20POCO%20F6%20%2F%20Redmi%20Turbo%203-orange.svg)](https://www.gsmarena.com/xiaomi_poco_f6-12940.php)
[![KSUNext](https://img.shields.io/badge/KSUNext-v3.3.0-purple.svg)](https://github.com/KernelSU/KernelSU)
[![SUSFS](https://img.shields.io/badge/SUSFS-v2.1.0-red.svg)](https://github.com/simonpunk/susfs4ksu)
[![License](https://img.shields.io/badge/License-GPLv2-yellow.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/ZxAlif-ID/Flavenz-Kernel-Peridot?include_prereleases&logo=github)](https://github.com/ZxAlif-ID/Flavenz-Kernel-Peridot/releases/latest)

*Kernel GKI kustom bersih berkinerja tinggi — dibangun untuk stabilitas gaming maksimal, KernelSU Next, penyembunyian root SUSFS, dan dukungan container Droidspaces native.*

**🌐 Bahasa / Language: [Bahasa Indonesia](README.id.md) | [English](README.md)**

</div>

---

## 🌟 Ikhtisar

**Flavenz Kernel** adalah kernel kustom untuk **Xiaomi POCO F6 / Redmi Turbo 3** (`peridot`) dengan chipset Qualcomm Snapdragon 8s Gen 3 (SM8635).

Dibangun dari satu pipeline GitHub Actions dalam satu flavor:

| Flavor | Base | Deskripsi |
|---|---|---|
| **ack-full** | ACK `android14-6.1-lts` @ `0c3d559bcd85` + defconfig dari `Mohithash/kernel_xiaomi_sm8635` | Android Common Kernel murni |

> Flavor lama **guidix-full** (base GuidixX 16.2) **dihapus 2026-09-13**: bootloop
> on-device (lihat `logs/recovery_20260913.log`). Yang boot-verified = `ack-full`.

Berbeda dengan kernel yang diberi patch eksperimental (BORE, ADIOS, scheduler tak perlu), Flavenz Kernel tetap bersih. Prioritasnya throughput gaming murni, efisiensi termal, stabilitas, dan kemampuan container/root tanpa mengorbankan keandalan stock.

---

## 🔥 Fitur Utama

- **Base GKI 6.1**: `6.1.138-android14-11` — kompatibel stock, GKI murni.
- **KernelSU Next (v3.3.0)**: solusi root terintegrasi (branch `pershoot/dev-susfs` — hook SUSFS built-in) via init_boot (mode GKI).
- **SUSFS (v2.1.0)**: penyembunyian root & mount point lanjutan — kompatibel aplikasi banking dan integrity check.
- **Dukungan Droidspaces native**: containerization penuh (`CONFIG_PID_NS`, `CONFIG_IPC_NS`, `CONFIG_SYSVIPC` + patch relokasi kABI untuk GKI 6.1) untuk environment gaming terisolasi.
- **Zero Bloat**: tanpa scheduler pihak ketiga / patch tak stabil yang memicu reboot acak atau thermal throttling.
- **ThinLTO + KALLSYMS**: kompilasi Clang teroptimasi untuk performa sustain.
- **Timestamp build sinkron ROM**: `uname -a` mengikuti tanggal build ROM (input `rom_build_date`) — Duck Detector tidak lagi menandai "build time drift".

---

## 📁 Struktur Repositori

```tree
Flavenz-Kernel-Peridot/
├── .github/
│   ├── ISSUE_TEMPLATE/              # Template bug report + feature request
│   └── workflows/
│       ├── build-droidspaces.yml    # Build kernel ACK, single flavor (workflow_dispatch)
│       └── compare-kernel-zips.yml  # Perbandingan zip one-shot (template vs release vs upstream)
├── anykernel/                        # AnyKernel3 di-vendor (anykernel.sh digenerate per-flavor saat packaging)
├── docs/
│   ├── kernel-context.md             # Dokumentasi teknis & log error (Bahasa Indonesia, kanon)
│   ├── kernel-context.en.md          # Terjemahan Inggris (wajib sinkron)
│   ├── benchmark/
│   │   └── benchmark-ack.md          # Data benchmark AnTuTu ack-full (EN + ID)
│   └── index.html                    # Laman GitHub Pages (laporan benchmark live)
├── media/
│   └── ack-build-kernel/             # Laporan HTML benchmark + screenshot
├── CITATION.cff / CODE_OF_CONDUCT.md / CONTRIBUTING.md / SECURITY.md
├── CHANGELOG.md / LICENSE / README.md / README.id.md
```

> Source kernel dan toolchain build **tidak disimpan** di repo ini — semuanya diunduh workflow saat build (source kernel per flavor, Neutron Clang, KernelSU Next, SUSFS). AnyKernel3 di-vendor di `anykernel/`.

---

## 📊 Benchmark

Hasil nyata build **ack-full** (di-flash langsung dari zip release, terverifikasi stabil):

| AnTuTu V12.0.1 | Tanpa cooler | Dengan cooler | Δ |
|---|---:|---:|---:|
| **Total** | 1,644,070 | **1,813,737** | **+10,3%** |
| CPU | 471,867 | 545,611 | +15,6% |
| GPU (Adreno 735) | 446,626 | 446,506 | −0,0% |
| Memory | 353,002 | 400,412 | +13,4% |
| UX | 372,575 | 421,208 | +13,1% |

Suhu puncak: 40,3°C → 33,8°C dengan cooler aktif (−6,5°C). Rincian penuh, data termal/baterai, dan laporan HTML live: **[docs/benchmark/benchmark-ack.md](docs/benchmark/benchmark-ack.md)** — versi interaktif: [media/ack-build-kernel/Antutu-Ack.html](media/ack-build-kernel/Antutu-Ack.html) (atau [laman GitHub Pages](https://zxalif-id.github.io/Flavenz-Kernel-Peridot/)).

---

## 📦 Unduhan

### GitHub Releases (disarankan — satu zip flashable, tanpa nesting)

Setiap build sukses otomatis menerbitkan **GitHub Release** (`Flavenz-YYYYMMDD`) berisi:

- `Peridot-Kernel-ACK-…-YYYYMMDD.zip` (ack-full) — zip flashable mentah
- `SHA256SUMS.txt` — checksum untuk verifikasi integritas sebelum flash

1. Buka **Releases**.
2. Unduh **satu** zip untuk flavor pilihan — langsung bisa di-flash, tanpa ekstrak tambahan.
3. (Opsional) Verifikasi: `sha256sum -c SHA256SUMS.txt`.

### Artifact Actions (alternatif)

Zip juga di-upload sebagai artifact run (**Actions** → run hijau terbaru → Artifacts). Catatan: artifact GitHub selalu dibungkus zip luar (`<artifact>.zip` → ekstrak → zip flashable di dalam), jadi lebih baik lewat Releases.

### Penamaan Zip

- `Peridot-Kernel-ACK-KSUNext-v3.3.0-SUSFS-v2.1.0-droidspaces-YYYYMMDD.zip`

---

## ⚙️ Cara Flash

1. Unduh zip `Peridot-Kernel-*.zip` untuk flavor pilihan.
2. Reboot ke custom recovery (TWRP, OrangeFox, atau NEBULA recovery).
3. (Disarankan) Backup partisi **boot** dan **init_boot** terlebih dulu.
4. Flash zip.
5. Wipe Dalvik/Cache (opsional).
6. Reboot ke System.

> Rilis `Flavenz-20260910` (ack-full) sudah diuji: di-flash langsung dari asset release → boot stabil, Duck Detector bersih, benchmark AnTuTu terdokumentasi (lihat [Benchmark](#-benchmark)).

---

## 🛠️ Pipeline Build

Workflow GitHub Actions otomatis penuh (`.github/workflows/build-droidspaces.yml`):

- Trigger manual via **workflow_dispatch** (Actions → Run workflow).
- Matrix **1 job**: `ack-full` (flavor lama `guidix-full` dihapus 2026-09-13 — bootloop on-device).
- Langkah: free disk space → install dependencies → setup Neutron Clang (+ antman patch glibc) → clone source kernel per flavor → apply config Droidspaces + ThinLTO → apply patch kABI SYSVIPC → setup KernelSU Next v3.3.0 → setup SUSFS v2.1.0 → build (`Image`, `Image.gz`, `dtbs`) dengan **timestamp build sinkron ROM** (input `rom_build_date` — menjaga `uname -a` selaras tanggal build ROM agar integrity checker seperti Duck Detector tidak menandai drift) → package zip AnyKernel3 (folder `anykernel/` vendor + `anykernel.sh` generate) → upload artifact.
- **Job release**: setelah job matrix sukses, job `release` menerbitkan zip flashable mentah + `SHA256SUMS.txt` ke GitHub Releases (tag `Flavenz-YYYYMMDD`) lengkap dengan catatan rilis — tanpa zip-dalam-zip.

Lihat `docs/kernel-context.md` (atau [terjemahan Inggris](docs/kernel-context.en.md)) untuk rincian teknis penuh dan log error-fix.

---

## 🌐 Dokumentasi

| Dokumen | Bahasa | Isi |
|---|---|---|
| [README.md](README.md) | English | Ikhtisar, unduhan, flash, pipeline build |
| [docs/kernel-context.md](docs/kernel-context.md) | Bahasa Indonesia (kanon) | Riset device/kernel, config, log error-fix |
| [docs/kernel-context.en.md](docs/kernel-context.en.md) | English | Terjemahan file tersebut |
| [docs/benchmark/benchmark-ack.md](docs/benchmark/benchmark-ack.md) | EN + ID | Benchmark AnTuTu ack-full (data + metode) |
| [CHANGELOG.md](CHANGELOG.md) | English | Perubahan penting per rilis |
| [CONTRIBUTING.md](CONTRIBUTING.md) | EN + ID | Cara melaporkan bug & berkontribusi |
| [SECURITY.md](SECURITY.md) | EN + ID | Kebijakan pelaporan kerentanan |

---

## ⚠️ Disclaimer

> [!IMPORTANT]
> **Ini proyek pribadi, non-komersial.** Disediakan **APA ADANYA**, **tanpa jaminan** dalam bentuk apa pun, tersurat maupun tersirat.
>
> - **Kamu bertanggung jawab penuh atas apa pun yang kamu lakukan dengan kernel ini.** Kesalahan, error, kerusakan, kehilangan data, atau **kerusakan device/sistem** (bootloop, hard brick, insiden keamanan, dll.) adalah **risiko dan tanggung jawab kamu sepenuhnya**.
> - **Keamanan tidak dijamin.** Kernel tidak diaudit formal maupun diverifikasi aman. Flash sesuai pertimbangan sendiri.
> - Selalu backup penuh (boot, init_boot, dan data) sebelum mem-flash apa pun.
> - Dengan mengunduh dan mem-flash artifact/rilis dari repositori ini, kamu mengakui dan menerima tanggung jawab penuh atas hasilnya.

---

## 🤝 Kredit & Ucapan Terima Kasih

- **Google**: Android Common Kernel (ACK)
- **Qualcomm**: source platform SM8635
- **Mohithash**: defconfig kernel peridot
- **KernelSU Next Team**: implementasi KSUNext
- **simonpunk**: framework penyembunyian root SUSFS
- **ravindu644 / Droidspaces**: arsitektur namespace container & patch kABI
- **Flavenz / ZxAlif-ID**: maintenance, tuning, dan packaging

---

## 📄 Lisensi

Didistribusikan di bawah **GNU General Public License v2.0** — lihat [LICENSE](LICENSE).
Source kernel milik proyek upstream masing-masing (Google ACK, Qualcomm CodeLinaro, Xiaomi MiCode, KernelSU Next, SUSFS).

## ⚖️ Terverifikasi Di

| Item | Nilai |
|---|---|
| Perangkat | POCO F6 / Redmi Turbo 3 (`peridot`) |
| ROM | Port HyperOS 3 (Android 16), tanggal build 2026-07-01 |
| Kernel | `6.1.138-android14-11` GKI, Neutron Clang 30062026, ThinLTO |
| Terverifikasi | Release [Flavenz-20260910](https://github.com/ZxAlif-ID/Flavenz-Kernel-Peridot/releases/tag/Flavenz-20260910) `ack-full`: di-flash dari asset release, boot stabil, AnTuTu V12.0.1 (lihat [Benchmark](#-benchmark)) |
