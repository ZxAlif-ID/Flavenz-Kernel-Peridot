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

**Flavenz Kernel** is a meticulously crafted custom kernel for the **Xiaomi POCO F6 / Redmi Turbo 3** (`peridot`), powered by the Qualcomm Snapdragon 8s Gen 3 (SM8635) chipset. 

Unlike generic kernels bloated with experimental, unstable patches (such as BORE, ADIOS, or unnecessary CPU schedulers), Flavenz Kernel is built upon a solid **Android Common Kernel (ACK) 6.1** base. It prioritizes pure gaming throughput, thermal efficiency, rock-solid stability, and advanced container/root capabilities without compromising stock reliability.

---

## 🔥 Key Features

- **Base Architecture**: ACK `android14-6.1-lts` with Qualcomm CLO hardware integration.
- **KernelSU Next (v3.3.0)**: Integrated root solution providing robust module management and safe kernel-level access.
- **SUSFS (v2.1.0)**: Advanced root hiding and mount point concealment, ensuring seamless banking and integrity app compatibility.
- **Native Droidspaces Support**: Full containerization enablement (`CONFIG_PID_NS`, `CONFIG_IPC_NS`, `CONFIG_SYSVIPC` with proper kABI relocation patches) for running isolated environments.
- **Zero Bloat Policy**: Free from unnecessary third-party schedulers or unstable patches that cause random reboots or thermal throttling.
- **Optimized Compilation**: Built using optimized toolchain settings for supreme responsiveness and sustained gaming performance.

---

## 📁 Repository Structure

```tree
Flavenz-Kernel-Peridot/
├── .github/
│   └── workflows/
│       └── build-droidspaces.yml     # GitHub Actions automated build pipeline
├── anykernel/
│   └── anykernel.sh                  # AnyKernel3 flashing script and mount logic
├── docs/
│   └── kernel-context.md             # Comprehensive technical documentation & config notes
├── patches/
│   └── 001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch  # kABI relocation patch for SYSVIPC
└── Peridot-Kernel-KSUNext-v3.3.0-SUSFS-v2.1.0-droidspaces-*.zip  # Flashable release package
```

---

## 📦 Releases & Downloads

Pre-compiled, flashable AnyKernel3 ZIP packages are available directly in the **[GitHub Releases](https://github.com/ZxAlif-ID/Flavenz-Kernel-Peridot/releases)** tab on the right sidebar. 

### Available Flavors in Releases:
1. **Stock Flavor**: Pure ACK base with zero modifications.
2. **Droidspaces Flavor**: Stock + Droidspaces container configurations & kABI patches.
3. **Full Flavor (Recommended)**: Droidspaces + KernelSU Next v3.3.0 + SUSFS v2.1.0.

---

## ⚙️ Flashing Instructions

1. Download the latest `Peridot-Kernel-*.zip` from **Releases**.
2. Reboot your device into a custom recovery (TWRP, OrangeFox, or NEBULA recovery).
3. (Recommended) Take a backup of your current Boot and Init_boot partitions.
4. Flash the zip file (`Peridot-Kernel-KSUNext-v3.3.0-SUSFS-v2.1.0-droidspaces-*.zip`).
5. Wipe Dalvik/Cache (optional).
6. Reboot to System.

---

## 🛠️ Build Pipeline

This repository includes a fully automated GitHub Actions workflow (`.github/workflows/build-droidspaces.yml`) designed to compile the kernel variants cleanly in cloud environments.

---

## 🤝 Credits & Acknowledgments

- **Google**: Android Common Kernel (ACK)
- **Qualcomm**: SM8635 platform sources
- **KernelSU Next Team**: KSUNext implementation
- **simonpunk**: SUSFS root concealment framework
- **ravindu644 / Droidspaces**: Container namespace architecture & kABI patches
- **Flavenz / ZxAlif-ID**: Maintenance, tuning, and packaging
