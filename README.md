# Flavenz Kernel for Xiaomi POCO F6 (Peridot)

<div align="center">

[![Kernel Version](https://img.shields.io/badge/Kernel-6.1.138-blue.svg)](https://kernel.org)
[![Android](https://img.shields.io/badge/Android-14%2F15%2F16-green.svg)](https://android.com)
[![Device](https://img.shields.io/badge/Device-Xiaomi%20POCO%20F6%20%2F%20Redmi%20Turbo%203-orange.svg)](https://www.gsmarena.com/xiaomi_poco_f6-12940.php)
[![KSUNext](https://img.shields.io/badge/KSUNext-v3.3.0-purple.svg)](https://github.com/KernelSU/KernelSU)
[![SUSFS](https://img.shields.io/badge/SUSFS-v2.1.0-red.svg)](https://github.com/simonpunk/susfs4ksu)
[![License](https://img.shields.io/badge/License-GPLv2-yellow.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/ZxAlif-ID/Flavenz-Kernel-Peridot?include_prereleases&logo=github)](https://github.com/ZxAlif-ID/Flavenz-Kernel-Peridot/releases/latest)

*High-Performance, Clean GKI Custom Kernel engineered for Maximum Gaming Stability, KernelSU Next, SUSFS Root Concealment, and Native Droidspaces Container Support.*

**🌐 Language / Bahasa: [English](README.md) | [Bahasa Indonesia](README.id.md)**

</div>

---

## 🌟 Overview

**Flavenz Kernel** is a custom kernel for the **Xiaomi POCO F6 / Redmi Turbo 3** (`peridot`), powered by the Qualcomm Snapdragon 8s Gen 3 (SM8635) chipset.

It is built from a single GitHub Actions pipeline in one flavor:

| Flavor | Base | Description |
|---|---|---|
| **ack-full** | ACK `android14-6.1-lts` @ `0c3d559bcd85` + defconfigs from `Mohithash/kernel_xiaomi_sm8635` branch `17` | Pure Android Common Kernel |

> The former **guidix-full** flavor (GuidixX 16.2 base) was **removed on 2026-09-13**: it
> bootlooped on-device (see `logs/recovery_20260913.log`). The `ack-full` flavor is the
> boot-verified one.

Unlike kernels bloated with experimental, unstable patches (BORE, ADIOS, or unnecessary CPU schedulers), Flavenz Kernel stays clean. It prioritizes pure gaming throughput, thermal efficiency, rock-solid stability, and advanced container/root capabilities without compromising stock reliability.

---

## 🔥 Key Features

- **GKI 6.1 Base**: `6.1.138-android14-11` — stock-compatible, pure GKI.
- **KernelSU Next (v3.3.0)**: Integrated root solution (pershoot `dev-susfs` branch — SUSFS hooks built-in) via init_boot (GKI mode).
- **SUSFS (v2.1.0)**: Advanced root hiding and mount point concealment, ensuring seamless banking and integrity app compatibility.
- **Native Droidspaces Support**: Full containerization enablement (`CONFIG_PID_NS`, `CONFIG_IPC_NS`, `CONFIG_SYSVIPC` with kABI relocation patch for GKI 6.1) for running isolated gaming environments.
- **Zero Bloat Policy**: Free from unnecessary third-party schedulers or unstable patches that cause random reboots or thermal throttling.
- **ThinLTO + KALLSYMS**: Optimized compilation with Clang for sustained performance.

---

## 📁 Repository Structure

```tree
Flavenz-Kernel-Peridot/
├── .github/
│   ├── ISSUE_TEMPLATE/              # Bug report + feature request templates
│   └── workflows/
│       ├── build-droidspaces.yml    # Build kernel ACK, single flavor (workflow_dispatch)
│       └── compare-kernel-zips.yml  # One-shot zip comparison (template vs release vs upstream)
├── anykernel/                        # Vendored AnyKernel3 tree (workflow regenerates anykernel.sh per-flavor at package time)
├── docs/
│   ├── kernel-context.md             # Technical documentation & error log (Bahasa Indonesia, canonical)
│   ├── kernel-context.en.md          # English translation (keep both in sync)
│   ├── benchmark/
│   │   └── benchmark-ack.md          # ack-full AnTuTu benchmark data (EN + ID)
│   └── index.html                    # GitHub Pages landing (live benchmark report)
├── media/
│   └── ack-build-kernel/             # Benchmark HTML report + screenshots
├── CITATION.cff / CODE_OF_CONDUCT.md / CONTRIBUTING.md / SECURITY.md
├── CHANGELOG.md / LICENSE / README.md / README.id.md
```

> Kernel sources and build toolchains are **not** stored in this repo — they are fetched by the workflow at build time (kernel sources per flavor, Neutron Clang, KernelSU Next, SUSFS). AnyKernel3 is vendored in `anykernel/`.

---

## 📊 Benchmarks

Real-world results of the **ack-full** build (flashed directly from the release zip, verified stable):

| AnTuTu V12.0.1 | No cooler | Active cooler | Δ |
|---|---:|---:|---:|
| **Total** | 1,644,070 | **1,813,737** | **+10.3%** |
| CPU | 471,867 | 545,611 | +15.6% |
| GPU (Adreno 735) | 446,626 | 446,506 | −0.0% |
| Memory | 353,002 | 400,412 | +13.4% |
| UX | 372,575 | 421,208 | +13.1% |

Peak temperature: 40.3°C → 33.8°C with an active cooler (−6.5°C). Full breakdown,
thermal/battery data and the live HTML report: **[docs/benchmark/benchmark-ack.md](docs/benchmark/benchmark-ack.md)**
— interactive version: [media/ack-build-kernel/Antutu-Ack.html](media/ack-build-kernel/Antutu-Ack.html)
(or the [GitHub Pages page](https://zxalif-id.github.io/Flavenz-Kernel-Peridot/)).

---

## 📦 Downloads

### GitHub Releases (recommended — single flashable zip, no nesting)

Every successful build automatically publishes a **GitHub Release** (`Flavenz-YYYYMMDD`) containing:

- `Peridot-Kernel-ACK-…-YYYYMMDD.zip` (ack-full) — raw flashable zip
- `SHA256SUMS.txt` — checksums to verify integrity before flashing

1. Go to **Releases**.
2. Download **one** zip for the flavor you want — it is directly flashable, no extra extraction needed.
3. (Optional) Verify: `sha256sum -c SHA256SUMS.txt`.

### Actions artifacts (alternative)

Zips are also uploaded as run artifacts (**Actions** → latest green run → Artifacts). Note: downloading an artifact from GitHub always wraps it in an extra outer zip (`<artifact>.zip` → extract → flashable zip inside), so prefer the Releases route.

### Zip Naming

- `Peridot-Kernel-ACK-KSUNext-v3.3.0-SUSFS-v2.1.0-droidspaces-YYYYMMDD.zip`

---

## ⚙️ Flashing Instructions

1. Download the `Peridot-Kernel-*.zip` artifact for your flavor.
2. Reboot your device into a custom recovery (TWRP, OrangeFox, or NEBULA recovery).
3. (Recommended) Take a backup of your current **boot** and **init_boot** partitions.
4. Flash the zip file.
5. Wipe Dalvik/Cache (optional).
6. Reboot to System.

---

## ⚙️ Build Pipeline

This repository includes a fully automated GitHub Actions workflow (`.github/workflows/build-droidspaces.yml`):

- Triggered manually via **workflow_dispatch** (Actions → Run workflow).
- Matrix of **1 job**: `ack-full` (the former `guidix-full` flavor was removed on 2026-09-13 — bootloop on-device).
- Steps: free disk space → install dependencies → setup Neutron Clang (with antman glibc patch) → clone kernel source per flavor → apply Droidspaces + ThinLTO configs → apply SYSVIPC kABI patch → setup KernelSU Next v3.3.0 → setup SUSFS v2.1.0 → build (`Image`, `Image.gz`, `dtbs`) with a **ROM-synced build timestamp** (`rom_build_date` input — keeps `uname -a` aligned with the ROM's build date so integrity checkers like Duck Detector report no drift) → package AnyKernel3 ZIP (vendored `anykernel/` tree + generated `anykernel.sh`) → upload artifact.
- **Release job**: after the matrix job succeeds, a `release` job publishes the raw flashable zip + `SHA256SUMS.txt` to GitHub Releases (tag `Flavenz-YYYYMMDD`) with full release notes — no zip-in-zip.

See `docs/kernel-context.md` (or its [English translation](docs/kernel-context.en.md)) for the full technical breakdown and the error-fix log.

---

## 🌐 Documentation

| Document | Language | Content |
|---|---|---|
| [README.id.md](README.id.md) | Bahasa Indonesia | Overview, downloads, flashing, build pipeline |
| [docs/kernel-context.md](docs/kernel-context.md) | Bahasa Indonesia (canonical) | Device/kernel research, configs, error-fix log |
| [docs/kernel-context.en.md](docs/kernel-context.en.md) | English | Translation of the above |
| [docs/benchmark/benchmark-ack.md](docs/benchmark/benchmark-ack.md) | EN + ID | ack-full AnTuTu benchmark (data + method) |
| [CHANGELOG.md](CHANGELOG.md) | English | Notable changes per release |
| [CONTRIBUTING.md](CONTRIBUTING.md) | EN + ID | How to report bugs & contribute |
| [SECURITY.md](SECURITY.md) | EN + ID | Vulnerability reporting policy |

---

## ⚠️ Disclaimer

> [!IMPORTANT]
> **This is a personal, non-commercial project.** It is provided **AS-IS**, with **no warranty of any kind**, express or implied.
>
> - **You are fully responsible for anything you do with these kernels.** Any mistakes, errors, malfunctions, data loss, or **damage to your device/system** (bootloop, hard brick, security incident, etc.) are **entirely at your own risk and responsibility**.
> - **Security cannot be guaranteed.** The kernels have not been formally audited or verified as secure. Flash at your own discretion.
> - Always take a full backup (boot, init_boot, and your data) before flashing anything.
> - By downloading and flashing any of the artifacts or releases from this repository, you acknowledge and accept full responsibility for the outcome.

---

## 🤝 Credits & Acknowledgments

- **Google**: Android Common Kernel (ACK)
- **Qualcomm**: SM8635 platform sources
- **Mohithash**: peridot defconfig
- **KernelSU Next Team**: KSUNext implementation
- **simonpunk**: SUSFS root concealment framework
- **ravindu644 / Droidspaces**: Container namespace architecture & kABI patches
- **Flavenz / ZxAlif-ID**: Maintenance, tuning, and packaging

---

## 📄 License

Distributed under the **GNU General Public License v2.0** — see [LICENSE](LICENSE).
Kernel sources belong to their respective upstream projects (Google ACK,
Qualcomm CodeLinaro, Xiaomi MiCode, KernelSU Next, SUSFS).

## ⚖️ Verified on

| Item | Value |
|---|---|
| Device | POCO F6 / Redmi Turbo 3 (`peridot`) |
| ROM | HyperOS 3 port (Android 16), build date 2026-07-01 |
| Kernel | `6.1.138-android14-11` GKI, Neutron Clang 30062026, ThinLTO |
| Verified | Release [Flavenz-20260910](https://github.com/ZxAlif-ID/Flavenz-Kernel-Peridot/releases/tag/Flavenz-20260910) `ack-full`: flashed from release asset, boot stable, AnTuTu V12.0.1 (see [Benchmarks](#-benchmarks)) |