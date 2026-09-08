# Flavenz Kernel for Xiaomi POCO F6 (Peridot)

<div align="center">

[![Kernel Version](https://img.shields.io/badge/Kernel-6.1.138-blue.svg)](https://kernel.org)
[![Android](https://img.shields.io/badge/Android-14%2F15%2F16-green.svg)](https://android.com)
[![Device](https://img.shields.io/badge/Device-Xiaomi%20POCO%20F6%20%2F%20Redmi%20Turbo%203-orange.svg)](https://www.gsmarena.com/xiaomi_poco_f6-12940.svg)
[![KSUNext](https://img.shields.io/badge/KSUNext-v3.3.0-purple.svg)](https://github.com/KernelSU/KernelSU)
[![SUSFS](https://img.shields.io/badge/SUSFS-v2.1.0-red.svg)](https://github.com/simonpunk/susfs4ksu)
[![License](https://img.shields.io/badge/License-GPLv2-yellow.svg)](LICENSE)

*High-Performance, Clean GKI Custom Kernel engineered for Maximum Gaming Stability, KernelSU Next, SUSFS Root Concealment, and Native Droidspaces Container Support.*

</div>

---

## 🌟 Overview

**Flavenz Kernel** is a custom kernel for the **Xiaomi POCO F6 / Redmi Turbo 3** (`peridot`), powered by the Qualcomm Snapdragon 8s Gen 3 (SM8635) chipset.

It is built in **two flavors** via a single GitHub Actions matrix pipeline:

| Flavor | Base | Description |
|---|---|---|
| **guidix-full** | `GuidixX/kernel_xiaomi_sm8635` branch `16.2` (ACK + Qualcomm CLO) | Closest to stock, proven to boot on peridot |
| **ack-full** | ACK `android14-6.1-lts` @ `0c3d559bcd85` + defconfigs from `Mohithash/kernel_xiaomi_sm8635` branch `17` | Pure Android Common Kernel |

Unlike kernels bloated with experimental, unstable patches (BORE, ADIOS, or unnecessary CPU schedulers), Flavenz Kernel stays clean. It prioritizes pure gaming throughput, thermal efficiency, rock-solid stability, and advanced container/root capabilities without compromising stock reliability.

---

## 🔥 Key Features

- **GKI 6.1 Base**: `6.1.138-android14-11` — stock-compatible, with Qualcomm CLO hardware integration on the Guidix flavor.
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
│   └── workflows/
│       └── build-droidspaces.yml     # Build matrix: guidix-full vs ack-full (workflow_dispatch)
├── docs/
│   └── kernel-context.md             # Technical documentation, research notes & error log
└── README.md
```

> Kernel sources, AnyKernel3 packaging files and build toolchains are **not** stored in this repo — everything is fetched by the workflow at build time (kernel sources, AnyKernel3 from the maintainer's fork `ZxAlif-ID/Kernel_F6`, Neutron Clang, KernelSU Next, SUSFS).

---

## 📦 Downloads

Flashable AnyKernel3 ZIP packages are produced by the GitHub Actions workflow on every run and are available as **artifacts of the run**:

1. Go to **Actions** → **Build Kernel - Peridot (Guidix vs ACK Matrix)**.
2. Open the latest run (green check).
3. Download the `Peridot-Kernel-*-KSUNext-v3.3.0-SUSFS-v2.1.0-droidspaces-*.zip` artifact for the flavor you want.

### Artifact Naming

- `Peridot-Kernel-Guidix-KSUNext-v3.3.0-SUSFS-v2.1.0-droidspaces-YYYYMMDD.zip`
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

## 🛠️ Build Pipeline

This repository includes a fully automated GitHub Actions workflow (`.github/workflows/build-droidspaces.yml`):

- Triggered manually via **workflow_dispatch** (Actions → Run workflow).
- Matrix of **2 parallel jobs**: `guidix-full` and `ack-full`.
- Steps: free disk space → install dependencies → setup Neutron Clang (with antman glibc patch) → clone kernel source per flavor → apply Droidspaces + ThinLTO configs → apply SYSVIPC kABI patch → setup KernelSU Next v3.3.0 → setup SUSFS v2.1.0 → build (`Image`, `Image.gz`, `dtbs`) → package AnyKernel3 ZIP → upload artifact.

See `docs/kernel-context.md` for the full technical breakdown and the error-fix log.

---

## 🤝 Credits & Acknowledgments

- **Google**: Android Common Kernel (ACK)
- **Qualcomm**: SM8635 platform sources
- **GuidixX / Mohithash**: peridot kernel sources & defconfigs
- **KernelSU Next Team**: KSUNext implementation
- **simonpunk**: SUSFS root concealment framework
- **ravindu644 / Droidspaces**: Container namespace architecture & kABI patches
- **Flavenz / ZxAlif-ID**: Maintenance, tuning, and packaging