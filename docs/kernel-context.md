# Kernel Build Context — Peridot (POCO F6)

## Device Info
- **Device**: Xiaomi POCO F6 / Redmi Turbo 3 (codename: peridot)
- **Chipset**: Snapdragon 8s Gen 3 (SM8635)
- **ROM**: Port dari Redmi Turbo 3 / nezha vendor, HyperOS 3
- **Android**: 16 (API 36)
- **Fingerprint**: `Redmi/peridot/peridot:14/UKQ1.240624.001/OS3.0.310.0.WNPCNXM`

## Stock Kernel Info
- **Kernel string**: `6.1.138-android14-11-g0c3d559bcd85-ab14529422`
- **Commit prefix**: `0c3d559bcd85`
- **Toolchain stock**: AOSP clang 17.0.2 r487747c + PGO + BOLT + LTO
- **Build date**: Wed Dec 3 02:05:30 UTC 2025
- **Type**: GKI kernel 6.1
- **Scheduler**: schedutil + sugov (standar GKI, tidak ada WALT)
- **Tidak ada tweak Xiaomi** di kernel — murni GKI standar
- **Performa stock bagus** semata-mata karena PGO+BOLT+LTO saat compile, bukan tweak kernel

## Tujuan Build
- Kernel mendekati stock + Droidspaces untuk gaming
- **Tidak pakai** Theettam kernel (BORE, ADIOS, BBRv3 dll = tweak performa yang tidak diinginkan)
- Root: KernelSU Next v3.3.0
- Prioritas: gaming performance + Droidspaces container

## Riset Kernel Base
Berdasarkan riset mendalam + konfirmasi Gemini AI + dokumentasi Android resmi:

### Hierarki kernel peridot:
1. **ACK murni** = tidak bisa boot di peridot tanpa device tree/CLO — tidak practical
2. **GuidixX 16.2** = ACK + CLO Qualcomm = lebih dekat ke stock, proven boot di peridot ← **KANDIDAT TERBAIK**
3. **MiCode peridot-u-oss** = source resmi Xiaomi (paling akurat) tapi butuh Bazel + multi-repo sync (tidak practical di GitHub Actions)
4. **Peridot-Development/kernel_xiaomi_peridot** = pure mirror MiCode, branch `peridot-u-oss`, last update July 2026

### Repo penting yang ditemukan:
- `MiCode/Xiaomi_Kernel_OpenSource` branch `peridot-u-oss` — source resmi Xiaomi
- `Peridot-Development/kernel_xiaomi_peridot` branch `peridot-u-oss` — mirror MiCode aktif
- `GuidixX/kernel_xiaomi_sm8635` branch `16.2` — ACK + CLO, proven
- `Mohithash/kernel_xiaomi_sm8635` branch `17` — ACK + CLO + BORE/ADIOS (ada tweak)

### Kenapa tidak bisa pakai stock kernel + Droidspaces:
Droidspaces butuh namespace configs yang TIDAK ada di stock kernel Xiaomi. Harus build kernel baru — tidak ada jalan pintas.

## Droidspaces Check Result
```
[✗] PID namespace        → CONFIG_PID_NS=y perlu ditambah
[✗] IPC namespace        → CONFIG_IPC_NS=y perlu ditambah
[✗] devtmpfs support     → optional
[✗] User namespace       → optional, untuk Docker
```
Semua yang lain sudah PASS (Network NS, Bridge, Veth, OverlayFS, dll).

## Config yang perlu ditambah (Droidspaces)
```
CONFIG_SYSVIPC=y        ← wajib + kABI relocation patch
CONFIG_PID_NS=y         ← wajib
CONFIG_IPC_NS=y         ← wajib
CONFIG_POSIX_MQUEUE=y   ← wajib
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_TMPFS_XATTR=y
```

## Config yang JANGAN diaktifkan
- `CONFIG_CGROUP_DEVICE`, `CONFIG_CGROUP_PIDS`, `CONFIG_BRIDGE_NETFILTER`, `CONFIG_NF_TABLES`
- Alasan: terbukti bootloop di peridot (dari catatan Mohithash)

## Patches yang diperlukan (GKI 6.1)
- **kABI patch wajib**: `001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch`
  - Lokasi: `ravindu644/Droidspaces-OSS` → `Documentation/resources/kernel-patches/GKI/below-kernel-6.12/`
  - Fungsi: relocate SYSVIPC ke ANDROID_KABI_RESERVE slots 6/7/8 agar vendor_dlkm tidak crash
- **SUSFS patches** (flavor full):
  - `susfs/kernel_patches/50_add_susfs_in_kernel-6.1.patch`
  - ~~`susfs/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch`~~ — **tidak perlu**, sudah built-in di pershoot/dev-susfs
  - Copy manual: `susfs/kernel_patches/fs/susfs.c` → `kernel/fs/` dan `susfs/kernel_patches/include/linux/susfs*.h` → `kernel/include/linux/`

## Repo Fork
- **Fork**: `https://github.com/ZxAlif-ID/Kernel_F6`
- **Branch aktif**: `17`
- **Workflow file**: `.github/workflows/build-droidspaces.yml` ✓ sudah di-commit

## Sumber kernel source (saat ini — ACK base)
- **Base**: ACK `android14-6.1-lts` commit `0c3d559bcd85`
- **Defconfig + config + Makefile.extrawarn**: dari `Mohithash/kernel_xiaomi_sm8635` branch `17`
  - `arch/arm64/configs/gki_defconfig`
  - `arch/arm64/configs/vendor/peridot_GKI.config`
  - `scripts/Makefile.extrawarn` ← fix Clang 23 warnings (tambah 1 baris manual untuk `uninitialized-const-pointer`)

## 3 Flavor
1. **stock** — ACK murni, zero patch
2. **droidspaces** — stock + Droidspaces configs + kABI patch
3. **full** — droidspaces + KernelSU Next v3.3.0 (pershoot/dev-susfs, SUSFS hooks built-in) + SUSFS gki-android14-6.1

## Output ZIP per Flavor
```
releases/
└── YYYYMMDD/
    ├── Peridot-Kernel-stock-YYYYMMDD.zip
    ├── Peridot-Kernel-droidspaces-YYYYMMDD.zip
    └── Peridot-Kernel-KSUNext-v3.3.0-SUSFS-v2.1.0-droidspaces-YYYYMMDD.zip
```
- `stock` / `droidspaces` → `Peridot-Kernel-{FLAVOR}-{DATE}.zip`
- `full` → `Peridot-Kernel-KSUNext-{KERNELSU_VERSION}-SUSFS-{SUSFS_VERSION}-droidspaces-{DATE}.zip`

## Toolchain
- **Neutron Clang 23** build `30062026`
  - URL: `https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/30062026/neutron-clang-30062026.tar.zst`
  - Perlu **antman** untuk patch glibc agar kompatibel dengan Ubuntu runner
  - antman commit: `0b32c45e3ad83a953b4bc3fd2feb4ad3cc87c1e8`

## Error yang sudah difix
| Error | Fix |
|---|---|
| `ubuntu-22.04` deprecated | Ganti ke `ubuntu-24.04` |
| `upload-artifact@v4` usang | Update ke `@v7` (lalu dihapus di v1.9) |
| Tidak ada `actions/checkout` | Tambah `actions/checkout@v6` |
| Heredoc defconfig indent bug | Ganti ke `printf` |
| `inputs.flavor` salah konteks | Fix ke `github.event.inputs.flavor` |
| `Image.gz-dtb` format lama | Fix ke `Image` + `Image.gz` |
| Missing free disk space | Tambah step free disk |
| Cross-compile toolchain tidak ada | Tambah `gcc-aarch64-linux-gnu` via apt |
| `kernel` dir sudah ada saat clone | Tambah `rm -rf kernel` sebelum clone |
| `peridot_defconfig` tidak ada di GuidixX | Ganti sumber ke Mohithash, pakai `gki_defconfig` + `peridot_GKI.config` |
| `mkdir vendor` setelah `cp` | Fix urutan: `mkdir` dulu baru `cp` |
| ZyCromerZ 17.0.6 URL dead | Ganti ke 16.0.6-20260807 |
| `ld.lld not found` di ZyCromerZ | Ganti ke Neutron Clang 23 |
| Neutron tanpa antman glibc patch | Tambah antman `--patch=glibc` |
| `-Wdefault-const-init-*` error | Copy `Makefile.extrawarn` dari Mohithash |
| `-Wuninitialized-const-pointer` error | Append disable flag ke `Makefile.extrawarn` |
| Heredoc `<< 'EOF'` di dalam `run: \|` | Ganti ke `printf '%s\n'` per baris — YAML parser salah baca EOF terminator yang tidak ter-indent |
| `${FLAVOR}` tidak tersedia di step Push | Inject via `env: FLAVOR: ${{ github.event.inputs.flavor }}` di step Push |
| `git checkout/switch` gagal karena working dir kotor | Tambah `git clean -fdx` + `git reset --hard HEAD` sebelum switch branch |
| SUSFS patch error `No such file or directory` | Fix path explicit: copy `fs/susfs.c` + `include/linux/susfs*.h`, apply patch per file bukan glob `GKI/*.patch` |
| ZIP masuk ke root `releases/` branch | Fix: zip masuk ke subfolder `${RELEASEDATE}/` |
| ZIPNAME `full` flavor tidak informatif | Fix: `Peridot-Kernel-KSUNext-{VER}-SUSFS-{VER}-droidspaces-{DATE}.zip` |
| KSU-Next `next` branch tidak include SUSFS hooks | Ganti ke `pershoot/KernelSU-Next` branch `dev-susfs` — hooks built-in, `10_enable_susfs_for_ksu.patch` tidak diperlukan |
| `fatal: Remote branch theettam-2.7 not found` | Implementasi **Dynamic Branch Fallback Loop** (`17` → `main` → `theettam-2.8` → `theettam-2.7`) untuk kloning `peridot-defconfig` secara fleksibel |

## Status Saat Ini
- Workflow **v1.10** — terakhir diupdate 06 Sep 2026
- Tambah env var `SUSFS_VERSION: v2.1.0`
- Fix Setup SUSFS: explicit copy + apply `50_add_susfs_in_kernel-6.1.patch` only
- Fix KernelSU Next: ganti dari `KernelSU-Next/next` ke `pershoot/KernelSU-Next/dev-susfs` — SUSFS hooks built-in, proven via WildKernels r7-r12 (KSU v3.3.0 + SUSFS v2.1.0)
- Hapus apply `10_enable_susfs_for_ksu.patch` — tidak diperlukan di dev-susfs
- Fix ZIPNAME per flavor (full vs non-full)
- Fix Push to releases: subfolder `${RELEASEDATE}/` bukan flat `releases/`
- Hapus step `Upload AnyKernel3 zip` (artifact upload tidak diperlukan)
- Workflow kini menggunakan **Dynamic Branch Fallback** (`17` → `main` → `theettam-2.8` → `theettam-2.7`) saat cloning defconfig, sehingga tahan terhadap perubahan branch upstream atau penghapusan branch lama.

## Next Decision Point
Jika build ACK masih error atau hasil kurang memuaskan:
- **Opsi A**: Ganti base ke `GuidixX/kernel_xiaomi_sm8635` branch `16.2` — ACK + CLO Qualcomm, proven boot di peridot, lebih sedikit error kompilasi
- **Opsi B**: Tetap ACK + fix manual satu per satu

## Next Task (belum dikerjakan)
**Build semua 3 flavor sekaligus dalam 1 run, 1 job (sequential loop) — hemat GitHub Actions minutes.**

Struktur yang diinginkan:
```
releases/
└── YYYYMMDD/
    ├── Peridot-Kernel-stock-YYYYMMDD.zip
    ├── Peridot-Kernel-droidspaces-YYYYMMDD.zip
    └── Peridot-Kernel-KSUNext-v3.3.0-SUSFS-v2.1.0-droidspaces-YYYYMMDD.zip
```

Pendekatan: **loop sequential dalam 1 job** (bukan matrix — matrix pakai 3x runner = 3x quota minutes).

Logika yang perlu diimplementasi:
- Hapus input `flavor` (tidak perlu pilih manual lagi)
- Loop 3 flavor: `stock` → `droidspaces` → `full`
- Tiap iterasi: apply config yang relevan, build, package zip
- Kernel hanya di-compile 1x untuk `stock`, lalu patch incremental untuk `droidspaces` dan `full` — atau compile ulang per flavor (lebih clean tapi 3x compile)
- Semua zip dikumpulkan dulu, baru 1x push ke releases branch subfolder `YYYYMMDD/`

Keputusan yang masih perlu ditentukan:
- **1x compile vs 3x compile** — 1x compile lebih cepat tapi risky (config droidspaces harus di-apply sebelum compile, tidak bisa incremental setelah binary jadi). Realistisnya **3x compile** paling clean dan safe.
- Hapus `workflow_dispatch` input flavor atau tetap ada sebagai override?

## Workflow Saat Ini (build-droidspaces.yml v1.10)
```yaml
name: Build Kernel - Peridot (Droidspaces)

on:
  workflow_dispatch:
    inputs:
      flavor:
        description: "Build flavor (stock / droidspaces / full)"
        required: true
        default: droidspaces
        type: choice
        options:
          - stock
          - droidspaces
          - full

jobs:
  build:
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    env:
      ARCH: arm64
      KERNEL_COMMIT: 0c3d559bcd85
      KERNELSU_VERSION: v3.3.0
      SUSFS_VERSION: v2.1.0

    steps:
      - name: Free disk space
        run: |
          sudo rm -rf /usr/share/dotnet /usr/local/lib/android /opt/ghc \
            /opt/hostedtoolcache/CodeQL /usr/local/share/powershell \
            /usr/share/swift
          sudo docker image prune --all --force || true
          df -h

      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Install dependencies
        run: |
          sudo apt-get update -q
          sudo apt-get install -y --no-install-recommends \
            bc bison flex libssl-dev libelf-dev \
            python3 python3-pip cpio pahole \
            lz4 zstd libzstd-dev curl git zip \
            gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi \
            binutils-aarch64-linux-gnu

      - name: Setup Neutron Clang
        run: |
          set -euo pipefail
          rm -rf "$HOME/clang"; mkdir -p "$HOME/clang"; cd "$HOME/clang"
          curl -fsSLO "https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/30062026/neutron-clang-30062026.tar.zst"
          tar -I zstd -xf "neutron-clang-30062026.tar.zst" && rm -f "neutron-clang-30062026.tar.zst"
          curl -fsSLo antman "https://raw.githubusercontent.com/Neutron-Toolchains/antman/0b32c45e3ad83a953b4bc3fd2feb4ad3cc87c1e8/antman"
          chmod +x antman
          for i in 1 2 3 4; do
            ./antman --patch=glibc && break
            [ "$i" = 4 ] && { echo "::error::antman failed 4 times"; exit 1; }
            echo "antman attempt $i failed; retrying in $((i*20))s"; sleep $((i*20))
          done
          echo "$HOME/clang/bin" >> $GITHUB_PATH

      - name: Clone ACK kernel source
        run: |
          rm -rf kernel
          git clone --filter=blob:none --no-checkout \
            https://android.googlesource.com/kernel/common \
            kernel
          cd kernel
          git checkout $KERNEL_COMMIT

      - name: Get peridot defconfig
        run: |
          git clone --depth=1 -b 17 \
            https://github.com/Mohithash/kernel_xiaomi_sm8635 \
            peridot-defconfig
          mkdir -p kernel/arch/arm64/configs/vendor
          cp peridot-defconfig/arch/arm64/configs/gki_defconfig \
            kernel/arch/arm64/configs/gki_defconfig
          cp peridot-defconfig/arch/arm64/configs/vendor/peridot_GKI.config \
            kernel/arch/arm64/configs/vendor/peridot_GKI.config
          cp peridot-defconfig/scripts/Makefile.extrawarn \
            kernel/scripts/Makefile.extrawarn
          echo 'KBUILD_CFLAGS += $(call cc-disable-warning, uninitialized-const-pointer)' \
            >> kernel/scripts/Makefile.extrawarn
          rm -rf peridot-defconfig

      - name: Apply ThinLTO configs
        run: |
          printf '%s\n' \
            CONFIG_LTO=y \
            CONFIG_LTO_CLANG=y \
            CONFIG_LTO_CLANG_THIN=y \
            CONFIG_KALLSYMS=y \
            CONFIG_KALLSYMS_ALL=y \
            >> kernel/arch/arm64/configs/vendor/peridot_GKI.config

      - name: Apply Droidspaces configs
        if: ${{ github.event.inputs.flavor != 'stock' }}
        run: |
          printf '%s\n' \
            CONFIG_SYSVIPC=y \
            CONFIG_PID_NS=y \
            CONFIG_IPC_NS=y \
            CONFIG_POSIX_MQUEUE=y \
            CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y \
            CONFIG_TMPFS_POSIX_ACL=y \
            CONFIG_TMPFS_XATTR=y \
            >> kernel/arch/arm64/configs/vendor/peridot_GKI.config

      - name: Apply kABI SYSVIPC patch (GKI 6.1)
        if: ${{ github.event.inputs.flavor != 'stock' }}
        run: |
          wget -q "https://raw.githubusercontent.com/ravindu644/Droidspaces-OSS/main/Documentation/resources/kernel-patches/GKI/below-kernel-6.12/001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch" \
            -O sysvipc_kabi.patch
          cd kernel
          git apply ../sysvipc_kabi.patch
          cd ..
          rm sysvipc_kabi.patch

      - name: Setup KernelSU Next (pershoot/dev-susfs)
        if: ${{ github.event.inputs.flavor == 'full' }}
        run: |
          cd kernel
          curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/dev-susfs/kernel/setup.sh" \
            | bash -s $KERNELSU_VERSION

      - name: Setup SUSFS
        if: ${{ github.event.inputs.flavor == 'full' }}
        run: |
          git clone --depth=1 -b gki-android14-6.1 \
            https://gitlab.com/simonpunk/susfs4ksu \
            susfs
          cp susfs/kernel_patches/fs/susfs.c kernel/fs/
          cp susfs/kernel_patches/include/linux/susfs*.h kernel/include/linux/
          cd kernel
          git apply ../susfs/kernel_patches/50_add_susfs_in_kernel-6.1.patch \
            && echo "Applied: 50_add_susfs_in_kernel-6.1.patch" || echo "Skip: 50_add_susfs_in_kernel-6.1.patch"

      - name: Build kernel
        run: |
          export PATH="$HOME/clang/bin:$PATH"
          CLANG_BIN=$HOME/clang/bin

          MAKE_FLAGS=(
            -j$(nproc)
            O=out
            ARCH=arm64
            CC=clang
            CLANG_TRIPLE=aarch64-linux-gnu-
            CROSS_COMPILE=aarch64-linux-gnu-
            LD=$CLANG_BIN/ld.lld
            AR=$CLANG_BIN/llvm-ar
            NM=$CLANG_BIN/llvm-nm
            OBJCOPY=$CLANG_BIN/llvm-objcopy
            OBJDUMP=$CLANG_BIN/llvm-objdump
            STRIP=$CLANG_BIN/llvm-strip
            KCFLAGS="-Wno-default-const-init-var-unsafe -march=armv9.2-a+crypto+dotprod"
          )

          cd kernel
          make "${MAKE_FLAGS[@]}" gki_defconfig vendor/peridot_GKI.config
          make "${MAKE_FLAGS[@]}" Image Image.gz dtbs

      - name: Package AnyKernel3
        env:
          FLAVOR: ${{ github.event.inputs.flavor }}
        run: |
          DATE=$(date +%Y%m%d)
          if [ "${FLAVOR}" = "full" ]; then
            ZIPNAME="Peridot-Kernel-KSUNext-${KERNELSU_VERSION}-SUSFS-${SUSFS_VERSION}-droidspaces-${DATE}.zip"
          else
            ZIPNAME="Peridot-Kernel-${FLAVOR}-${DATE}.zip"
          fi
          echo "ZIPNAME=${ZIPNAME}" >> $GITHUB_ENV
          echo "ZIPPATH=${GITHUB_WORKSPACE}/${ZIPNAME}" >> $GITHUB_ENV
          echo "RELEASEDATE=${DATE}" >> $GITHUB_ENV

          rm -rf anykernel
          git clone --depth=1 https://github.com/osm0sis/AnyKernel3 anykernel
          cd anykernel

          rm -rf ramdisk patch modules README.md LICENSE

          printf '%s\n' \
            '# AnyKernel3 Ramdisk Mod Script' \
            '# osm0sis @ xda-developers' \
            '' \
            '## AnyKernel setup' \
            '# begin properties' \
            "properties() { '" \
            'kernel.string=Peridot Kernel (Droidspaces) by ZxAlif-ID' \
            'do.devicecheck=1' \
            'do.modules=0' \
            'do.systemless=1' \
            'do.cleanup=1' \
            'do.cleanuponabort=0' \
            'device.name1=peridot' \
            'device.name2=peridot_global' \
            'device.name3=' \
            'device.name4=' \
            'device.name5=' \
            'supported.versions=' \
            'supported.patchlevels=' \
            "'; } # end properties" \
            '' \
            '## AnyKernel install' \
            '# boot shell variables' \
            'block=/dev/block/by-name/boot;' \
            'is_slot_device=1;' \
            'ramdisk_compression=auto;' \
            'patch_vbmeta_flag=auto;' \
            '' \
            '# import functions/variables and setup patching (DO NOT REMOVE)' \
            '. tools/ak3-core.sh;' \
            '' \
            'split_boot;' \
            'flash_boot;' \
            > anykernel.sh

          cp ../kernel/out/arch/arm64/boot/Image ./Image
          zip -r9 "${GITHUB_WORKSPACE}/${ZIPNAME}" . -x "*.git*" "*.zip"

      - name: Push to releases branch
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          FLAVOR: ${{ github.event.inputs.flavor }}
        run: |
          git config --global user.email "actions@github.com"
          git config --global user.name "GitHub Actions"

          cp "${ZIPPATH}" /tmp/

          rm -rf anykernel kernel susfs peridot-defconfig
          git reset --hard HEAD
          git clean -fdx

          git fetch origin releases 2>/dev/null || true
          if git rev-parse --verify origin/releases > /dev/null 2>&1; then
            git checkout -B releases origin/releases
          else
            git switch --orphan releases
          fi

          mkdir -p "${RELEASEDATE}"
          cp /tmp/"${ZIPNAME}" "${RELEASEDATE}/"

          git add .
          git commit -m "kernel: ${FLAVOR} ${RELEASEDATE}" --allow-empty
          git push origin releases --force
```

## Referensi Penting
- Droidspaces config guide: `ravindu644/Droidspaces-OSS/blob/main/Documentation/Kernel-Configuration.md`
- KernelSU Next setup: `curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/dev-susfs/kernel/setup.sh" | bash -s v3.3.0` (pershoot/dev-susfs — SUSFS hooks built-in, proven via WildKernels r7-r12)
- SUSFS branch untuk kernel 6.1: `gki-android14-6.1` di `gitlab.com/simonpunk/susfs4ksu`
- Antman (Neutron glibc patcher): `github.com/Neutron-Toolchains/antman`
- MiCode peridot source: `github.com/MiCode/Xiaomi_Kernel_OpenSource` branch `peridot-u-oss`
- Mirror MiCode aktif: `github.com/Peridot-Development/kernel_xiaomi_peridot` branch `peridot-u-oss`
- GuidixX (ACK+CLO): `github.com/GuidixX/kernel_xiaomi_sm8635` branch `16.2`

## Catatan Lain
- ROM port, kernel harus bersih dari tweak
- Gaming adalah prioritas utama
- Device ban FF sampai 08 September 2026 (tidak related ke kernel)
- Flavor "full" include KernelSU via init_boot (GKI mode)
- Theettam tweaknya: BORE, ADIOS, BBRv3, MGLRU, TEO, HZ=300, CAKE, uclamp — semua dari Mohithash, bukan dari GuidixX
