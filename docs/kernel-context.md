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
2. **GuidixX 16.2** = ACK + CLO Qualcomm = lebih dekat ke stock, proven boot di peridot ← dipakai untuk flavor **guidix-full**
3. **MiCode peridot-u-oss** = source resmi Xiaomi (paling akurat) tapi butuh Bazel + multi-repo sync (tidak practical di GitHub Actions)
4. **Peridot-Development/kernel_xiaomi_peridot** = pure mirror MiCode, branch `peridot-u-oss`, last update July 2026

### Repo penting yang ditemukan:
- `MiCode/Xiaomi_Kernel_OpenSource` branch `peridot-u-oss` — source resmi Xiaomi
- `Peridot-Development/kernel_xiaomi_peridot` branch `peridot-u-oss` — mirror MiCode aktif
- `GuidixX/kernel_xiaomi_sm8635` branch `16.2` — ACK + CLO, proven → base flavor **guidix-full**
- `Mohithash/kernel_xiaomi_sm8635` branch `17` — ACK + CLO + BORE/ADIOS (ada tweak); dipakai hanya sebagai **sumber defconfig + anykernel**, bukan sebagai base
- `ZxAlif-ID/Kernel_F6` — **fork pribadi** dari `Mohithash/kernel_xiaomi_sm8635`, branch `main`; dipakai sebagai sumber **AnyKernel3** di workflow

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

## Config yang ditambahkan (Droidspaces + build)
Diappend ke `gki_defconfig` (atau `vendor/peridot_GKI.config` jika ada) oleh step "Apply Droidspaces & Container Configs":
```
CONFIG_SYSVIPC=y        ← wajib + kABI relocation patch
CONFIG_PID_NS=y         ← wajib
CONFIG_IPC_NS=y         ← wajib
CONFIG_USER_NS=y
CONFIG_NET_NS=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_POSIX_MQUEUE=y   ← wajib
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_TMPFS_XATTR=y
CONFIG_LTO=y / CONFIG_LTO_CLANG=y / CONFIG_LTO_CLANG_THIN=y
CONFIG_KALLSYMS=y / CONFIG_KALLSYMS_ALL=y
```

## Config yang JANGAN diaktifkan
- `CONFIG_CGROUP_DEVICE`, `CONFIG_CGROUP_PIDS`, `CONFIG_BRIDGE_NETFILTER`, `CONFIG_NF_TABLES`
- Alasan: terbukti bootloop di peridot (dari catatan Mohithash)

## Patches yang diperlukan (GKI 6.1)
- **kABI patch wajib**: `001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch`
  - Lokasi: `ravindu644/Droidspaces-OSS` → `Documentation/resources/kernel-patches/GKI/below-kernel-6.12/`
  - Fungsi: relocate SYSVIPC ke ANDROID_KABI_RESERVE slots 6/7/8 agar vendor_dlkm tidak crash
- **SUSFS patches** (kedua flavor):
  - `susfs/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch` (branch `gki-android14-6.1`)
  - Copy manual: `susfs/kernel_patches/fs/susfs.c` → `kernel/fs/` dan `susfs/kernel_patches/include/linux/susfs*.h` → `kernel/include/linux/`
  - `10_enable_susfs_for_ksu.patch` — **tidak perlu**, sudah built-in di pershoot/dev-susfs

## Alur Workflow Saat Ini (build-droidspaces.yml)
- **Trigger**: `workflow_dispatch` (manual, Actions → Run workflow)
- **Matrix 2 job paralel** (`fail-fast: false`):
  1. **guidix-full** — clone `GuidixX/kernel_xiaomi_sm8635` branch `16.2`
  2. **ack-full** — clone ACK `kernel/common` @ `0c3d559bcd85` + defconfig dari `Mohithash/kernel_xiaomi_sm8635` (dynamic branch fallback: `17` → `main` → `theettam-2.8` → `theettam-2.7`)
- Step umum: free disk space → install deps (bc, bison, flex, libssl, cpio, pahole, lz4, zstd, gcc-aarch64-linux-gnu, dll) → setup Neutron Clang 30062026 + antman glibc patch → apply Droidspaces & container configs → apply kABI SYSVIPC patch → setup KernelSU Next v3.3.0 (pershoot/dev-susfs) → setup SUSFS v2.1.0 → build (`gki_defconfig` [+ `vendor/peridot_GKI.config`], `Image Image.gz dtbs`) → **Package AnyKernel3** → upload artifact
- **Tidak ada** step push ke branch `releases` — output berupa **artifact** dari run (download di halaman Actions run)
- Deterministic build: `KBUILD_BUILD_USER/HOST/TIMESTAMP` di-pin

### Package AnyKernel3 — sumber AK3
- AnyKernel3 **tidak di-clone sama sekali saat build** — clone dari repo mana pun (`osm0sis/AnyKernel3`, fork sendiri) terbukti mati diam-diam `exit code 3` di runner (lihat error log)
- **Sekarang di-vendor ke repo** (`0af93dc`): folder `anykernel/` di root repo ini (sumber awal: `ZxAlif-ID/Kernel_F6@main`, sudah di-rewrite ke Flavenz). Workflow tinggal memakainya saat packaging
- `anykernel.sh` digenerate sendiri oleh workflow via `printf` (branding Flavenz, `do.devicecheck=1`, `device.name1=peridot`, header peridot proven: `block=/dev/block/by-name/boot`, `is_slot_device=1`, `split_boot; flash_boot;`, pakai `dump_boot`/`write_boot` + `ui_print`, `ramdisk_compression=auto`)
- Isi zip: `anykernel.sh`, `Image` (+ `Image.gz`), `META-INF/` (update-binary, updater-script), `tools/` (ak3-core.sh, magiskboot, busybox, dll)
- Verifikasi: run 34256171472 — kedua job hijau, 2 artifact @ 17.2 MB

## Output ZIP (artifact per flavor)
```
Peridot-Kernel-Guidix-KSUNext-v3.3.0-SUSFS-v2.1.0-droidspaces-YYYYMMDD.zip   (guidix-full)
Peridot-Kernel-ACK-KSUNext-v3.3.0-SUSFS-v2.1.0-droidspaces-YYYYMMDD.zip       (ack-full)
```

## Toolchain
- **Neutron Clang 23** build `30062026`
  - URL: `https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/30062026/neutron-clang-30062026.tar.zst`
  - Perlu **antman** untuk patch glibc agar kompatibel dengan Ubuntu runner
  - antman commit: `0b32c45e3ad83a953b4bc3fd2feb4ad3cc87c1e8`
- Cross compile: `gcc-aarch64-linux-gnu` + `gcc-arm-linux-gnueabi` via apt

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
| `fatal: Remote branch theettam-2.7 not found` | Implementasi **Dynamic Branch Fallback Loop** (`17` → `main` → `theettam-2.8` → `theettam-2.7`) untuk kloning defconfig |
| **`Package AnyKernel3` gagal `exit code 3` di kedua job** | **Root cause**: `git clone https://github.com/osm0sis/AnyKernel3` gagal di runner (log: "Cloning into 'anykernel'..." lalu langsung exit 3, tanpa pesan fatal — konsisten di semua run; clone repo lain di run yang sama sukses). **Fix**: ganti sumber ke **fork pribadi** `ZxAlif-ID/Kernel_F6` branch `main` (sparse clone folder `anykernel/` saja) |
| `anykernel.sh` berisi `${FLAVOR}` literal | Heredoc `<< 'EOF'` → `<< EOF` agar `${FLAVOR}` ter-expand saat generate |
| `print` tidak ada di ak3-core.sh | Ganti `print "..."` → `ui_print "..."` (hanya `ui_print` yang didefinisikan) |
| Artifact name selalu "release" | Set `RELEASEDATE=${DATE}` di step Package supaya nama artifact memuat tanggal |
| **Package AnyKernel3 gagal `exit code 3` meski sumber diganti fork sendiri** | **Akar masalah: clone git DI RUNNER mati diam-diam (tanpa pesan git) untuk repo mana pun saat step packaging** (osm0sis run #4/#5, fork `ZxAlif-ID/Kernel_F6` run #6) — padahal clone sama sukses di lokal → disimpulkan masalah runner, bukan repo. **Fix `0af93dc`**: vendor AnyKernel3 ke repo (folder `anykernel/`), tidak ada clone sama sekali saat packaging; `anykernel.sh` digenerate via `printf` dengan header peridot proven (`block=/dev/block/by-name/boot`, `is_slot_device=1`, `split_boot; flash_boot;`), package `Image` (bukan Image.gz), `ramdisk_compression=auto` |
| Step packaging "sukses" tapi 0 artifact | `ZIPPATH` ditulis via `GITHUB_ENV` — variabel itu HANYA terlihat di step BERIKUTNYA, jadi di step yang sama nilainya kosong → `zip -r9 "" ...` exit 0 tapi menulis file tersembunyi `.zip`. **Fix `e1d2a62`**: variabel shell biasa + guard `[ -s ]` sebelum upload + `if-no-files-found: error` |
| ack-full gagal di clone ACK: `fetch-pack: unexpected disconnect / early EOF` exit 128 | Clone megarepo `android.googlesource.com/kernel/common` sering putus di tengah transfer di runner (~4-5 menit). **Fix `6478ccd`**: retry 3 attempt + backoff eksponensial + `http.lowSpeedLimit`/`http.lowSpeedTime` agar clone macet gagal cepat |

## Catatan Fork (ZxAlif-ID/Kernel_F6)
- Fork dari `Mohithash/kernel_xiaomi_sm8635`
- **Branch `17` sudah tidak ada** di fork (per 08 Sep 2026). Branch yang ada: `main`, `theettam-2.7`, `theettam-2.7-lts176`, `theettam-premium-sukisu`, `bestrom-a17-theettam`, `flazen-fix-v2.1`, `peridot-6.1.175`, `vos-16.2-clean-optimized`, `releases`
- Workflow memakai branch **`main`** sebagai sumber AnyKernel3 (isi `anykernel/` identik dengan Mohithash; yang dipakai di zip adalah `anykernel.sh` generate sendiri, bukan milik fork)

## Next Decision Point
Kedua opsi base sudah diimplementasikan sebagai matrix:
- **guidix-full** = Opsi A (GuidixX 16.2 — ACK + CLO, proven boot)
- **ack-full** = Opsi B (ACK murni + defconfig Mohithash)
Tinggal diverifikasi dari hasil build: kalau salah satu flavor error/jelek, bisa di-drop dari matrix tanpa mengganggu yang lain (`fail-fast: false`).

## Referensi Penting
- Droidspaces config guide: `ravindu644/Droidspaces-OSS/blob/main/Documentation/Kernel-Configuration.md`
- KernelSU Next setup: `curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/dev-susfs/kernel/setup.sh" | bash -s v3.3.0` (pershoot/dev-susfs — SUSFS hooks built-in, proven via WildKernels r7-r12)
- SUSFS branch untuk kernel 6.1: `gki-android14-6.1` di `gitlab.com/simonpunk/susfs4ksu`
- Antman (Neutron glibc patcher): `github.com/Neutron-Toolchains/antman`
- MiCode peridot source: `github.com/MiCode/Xiaomi_Kernel_OpenSource` branch `peridot-u-oss`
- Mirror MiCode aktif: `github.com/Peridot-Development/kernel_xiaomi_peridot` branch `peridot-u-oss`
- GuidixX (ACK+CLO): `github.com/GuidixX/kernel_xiaomi_sm8635` branch `16.2`
- AnyKernel3 (via fork): `github.com/ZxAlif-ID/Kernel_F6` branch `main` → folder `anykernel/`

## Catatan Lain
- ROM port, kernel harus bersih dari tweak
- Gaming adalah prioritas utama
- Flavor "full" include KernelSU via init_boot (GKI mode)
- Theettam tweaknya: BORE, ADIOS, BBRv3, MGLRU, TEO, HZ=300, CAKE, uclamp — semua dari Mohithash, bukan dari GuidixX — TIDAK dipakai