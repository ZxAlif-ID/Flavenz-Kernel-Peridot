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
2. **GuidixX 16.2** = ACK + CLO Qualcomm = lebih dekat ke stock, proven boot di peridot ← dipakai untuk flavor **guidix-full** — **FLAVOR DIHAPUS 2026-09-13: BOOTLOOP on-device** (lihat `logs/recovery_20260913.log`)
3. **MiCode peridot-u-oss** = source resmi Xiaomi (paling akurat) tapi butuh Bazel + multi-repo sync (tidak practical di GitHub Actions)
4. **Peridot-Development/kernel_xiaomi_peridot** = pure mirror MiCode, branch `peridot-u-oss`, last update July 2026

### Repo penting yang ditemukan:
- `MiCode/Xiaomi_Kernel_OpenSource` branch `peridot-u-oss` — source resmi Xiaomi
- `Peridot-Development/kernel_xiaomi_peridot` branch `peridot-u-oss` — mirror MiCode aktif
- `GuidixX/kernel_xiaomi_sm8635` branch `16.2` — ACK + CLO, proven → ~~base flavor **guidix-full**~~ (flavor dihapus 2026-09-13, bootloop on-device)
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
- **Matrix 1 job** (`fail-fast: false`) — sejak 2026-09-13:
  1. **ack-full** — clone ACK `kernel/common` @ `0c3d559bcd85` + defconfig dari `Mohithash/kernel_xiaomi_sm8635` (dynamic branch fallback: `17` → `main` → `theettam-2.8` → `theettam-2.7`)
  - ~~**guidix-full** — clone `GuidixX/kernel_xiaomi_sm8635` branch `16.2`~~ → **DIHAPUS 2026-09-13**: bootloop on-device setelah flash zip Guidix (recovery restore boot/dtbo/init_boot/vendor_boot dari backup, ROM NexiunOS masuk lagi — device selamat). Zip Guidix dihapus dari semua Release.
- Step umum: free disk space → install deps (bc, bison, flex, libssl, cpio, pahole, lz4, zstd, gcc-aarch64-linux-gnu, dll) → setup Neutron Clang 30062026 + antman glibc patch → apply Droidspaces & container configs → apply kABI SYSVIPC patch → setup KernelSU Next v3.3.0 (pershoot/dev-susfs) → setup SUSFS v2.1.0 → build (`gki_defconfig` [+ `vendor/peridot_GKI.config`], `Image Image.gz dtbs`) → **Package AnyKernel3** → upload artifact
- Output: artifact per run + **job `release` otomatis** — setelah job matrix sukses, zip flashable mentah + `SHA256SUMS.txt` diterbitkan sebagai aset **GitHub Releases** (tag `Flavenz-YYYYMMDD`) lengkap dengan deskripsi; tanpa zip dalam zip (aset release tidak dibungkus zip, berbeda dari artifact Actions)
- Deterministic build: `KBUILD_BUILD_USER/HOST` di-pin; `KBUILD_BUILD_TIMESTAMP` **dinamis** dari input `rom_build_date` (sinkron `ro.build.date` ROM — fix Duck Detector build-time drift, lihat tabel error)

### Package AnyKernel3 — sumber AK3
- AnyKernel3 **tidak di-clone sama sekali saat build** — clone dari repo mana pun (`osm0sis/AnyKernel3`, fork sendiri) terbukti mati diam-diam `exit code 3` di runner (lihat error log)
- **Sekarang di-vendor ke repo** (`0af93dc`): folder `anykernel/` di root repo ini (sumber awal: `ZxAlif-ID/Kernel_F6@main`, sudah di-rewrite ke Flavenz). Workflow tinggal memakainya saat packaging
- `anykernel.sh` digenerate sendiri oleh workflow via `printf` (branding Flavenz, `do.devicecheck=1`, `device.name1=peridot`, header peridot proven: `block=boot`, `is_slot_device=auto`, `split_boot; flash_boot;`, `ui_print`, `ramdisk_compression=auto` — identik dengan anykernel.sh Mohithash; JANGAN pakai `block=/dev/block/by-name/boot` + `is_slot_device=1`, deteksi slot-nya gagal di OrangeFox → abort, lihat error log)
- Isi zip: `anykernel.sh`, `Image` (+ `Image.gz`), `META-INF/` (update-binary, updater-script), `tools/` (ak3-core.sh, magiskboot, busybox, dll)
- Verifikasi: run 34256171472 — kedua job hijau, 2 artifact @ 17.2 MB

## Output ZIP (artifact per flavor)
```
Peridot-Kernel-ACK-KSUNext-v3.3.0-SUSFS-v2.1.0-droidspaces-YYYYMMDD.zip       (ack-full; guidix-full DIHAPUS 2026-09-13)
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
| **Package AnyKernel3 gagal `exit code 3` meski sumber diganti fork sendiri** | **Akar masalah: clone git DI RUNNER mati diam-diam (tanpa pesan git) untuk repo mana pun saat step packaging** (osm0sis run #4/#5, fork `ZxAlif-ID/Kernel_F6` run #6) — padahal clone sama sukses di lokal → disimpulkan masalah runner, bukan repo. **Fix `0af93dc`**: vendor AnyKernel3 ke repo (folder `anykernel/`), tidak ada clone sama sekali saat packaging; `anykernel.sh` digenerate via `printf` (header waktu itu masih `block=/dev/block/by-name/boot` + `is_slot_device=1` — kemudian diganti `block=boot` + `is_slot_device=auto` di `a76a91b`, lihat baris OrangeFox di bawah), package `Image` (bukan Image.gz), `ramdisk_compression=auto` |
| Step packaging "sukses" tapi 0 artifact | `ZIPPATH` ditulis via `GITHUB_ENV` — variabel itu HANYA terlihat di step BERIKUTNYA, jadi di step yang sama nilainya kosong → `zip -r9 "" ...` exit 0 tapi menulis file tersembunyi `.zip`. **Fix `e1d2a62`**: variabel shell biasa + guard `[ -s ]` sebelum upload + `if-no-files-found: error` |
| ack-full gagal di clone ACK: `fetch-pack: unexpected disconnect / early EOF` exit 128 | Clone megarepo `android.googlesource.com/kernel/common` sering putus di tengah transfer di runner (~4-5 menit). **Fix `6478ccd`**: retry 3 attempt + backoff eksponensial + `http.lowSpeedLimit`/`http.lowSpeedTime` agar clone macet gagal cepat |
| **Flash di OrangeFox R12 gagal: `Unable to determine active slot. Aborting...` → `Updater process ended with ERROR: 1`** (bukti: `logs/recovery.log:1725-1729`) | AK3 base 20231020 mendeteksi slot hanya via `getprop` + `/proc/cmdline`; di peridot/HyperOS 3 GKI 6.1, `androidboot.slot_suffix` masuk lewat **bootconfig** (`/proc/bootconfig`) dan shell installer OrangeFox tidak punya `getprop` di PATH — padahal recovery sendiri tahu slotnya (`ro.boot.slot_suffix=_a`, log baris 930). **Fix**: (1) generated `anykernel.sh` memakai `block=boot` + `is_slot_device=auto` (identik dengan `anykernel.sh` Mohithash yang proven flash & boot di peridot; `auto` tidak pernah abort); (2) patch `tools/ak3-core.sh` menambah fallback `/system/bin/getprop` + parsing `/proc/bootconfig` sebagai defense-in-depth |
| **Zip dalam zip (artifact GitHub dibungkus zip luar)** | Perilaku bawaan `upload-artifact`: hasil download selalu `<artifact>.zip` → diekstrak → baru zip flashable di dalamnya. **Fix**: job `release` baru menerbitkan zip flashable secara mentah sebagai aset **GitHub Releases** (aset release tidak pernah dibungkus) + `SHA256SUMS.txt` + catatan rilis; job berjalan hanya jika kedua job matrix sukses |
| **Run 34279539210: job release gagal `expected exactly 2 flashable zips, found 0`** | Dua bug sekaligus di logika unwrap milik saya: (1) deteksi wrapper pakai `unzip -l \| grep '\.zip$'` — baris PERTAMA output `unzip -l` selalu `Archive: <path>.zip`, jadi SEMUA zip terdeteksi sebagai "wrapper" → diekstrak lalu zip flashable-nya ikut TERHAPUS; (2) `download-artifact@v4` + `merge-multiple: true` ternyata sudah mengekstrak isi artifact langsung (zip flashable utuh di root), jadi sebenarnya tidak ada wrapper sama sekali. **Fix `d91e765`**: deteksi berdasarkan ISI (zip AK3 selalu berisi `anykernel.sh`; hanya zip TANPA `anykernel.sh` yang dianggap wrapper) + log `flashable (keep)` / `unwrapping wrapper zip` + guard `COUNT == 2` tetap sebagai jaring pengaman. Dry-run lokal untuk 2 layout (plain & wrapper) lolos sebelum push |
| **Duck Detector "Build time drift": kernel `2026-09-07` vs system `2026-07-01` (diff 68 hari)** | **Akar masalah**: `KBUILD_BUILD_TIMESTAMP` di-pin hardcode `Mon Sep  7 12:00:00 UTC 2026` di workflow, sedangkan tanggal build system (≈ `ro.build.date` ROM HyperOS 3 port) = 2026-07-01. Duck Detector membandingkan tanggal di `#1 SMP PREEMPT ...` (uname -a, dari `uts_banner`) vs tanggal build system → mismatch 68 hari dianggap anomali custom kernel. (Ref: webroot KSUN — "Duck Detector: Build time drift" muncul ketika timestamp uname tidak sinkron; Integrity-Box menjual "Spoof Build Time" sebagai fix, kita perbaiki di sumbernya saat build.) **Fix**: input workflow baru `rom_build_date` (default `2026-07-01`), step `Compute ROM-synced build timestamp` menurunkan `KBUILD_BUILD_TIMESTAMP` ke format uts_banner (`Wed Jul  1 00:00:00 UTC 2026`) — menerima epoch (`ro.build.date.utc`, disarankan), `YYYY-MM-DD`, atau string `ro.build.date` utuh; gagal keras jika tidak bisa di-parse. Saat ROM di-update: dispatch ulang dengan `ro.build.date.utc` baru → uname otomatis sinkron lagi. |
| **Verifikasi akhir (run 34283279734): SEMUA HIJAU** | `guidix-full` ✅ `ack-full` ✅ `Publish to GitHub Releases` ✅ → Release **`Flavenz-20260908`** terbit (Latest): 2 zip @ 17.2 MB + `SHA256SUMS.txt`. Dicek lokal dari zip yang DIUNDUH: 0 nested zip, header baru `block=boot;` + `is_slot_device=auto;` ada di dalam zip, patch bootconfig ada di `tools/ak3-core.sh`, `sha256sum -c` OK/OK. https://github.com/ZxAlif-ID/Flavenz-Kernel-Peridot/releases/tag/Flavenz-20260908 |

## Catatan Fork (ZxAlif-ID/Kernel_F6) — DEPRECATED 2026-09-12
> Repo tidak dipakai lagi. Riwayat di bawah dipertahankan hanya sebagai arsip sejarah; sumber AnyKernel3
> kini 100% dari folder `anykernel/` yang di-vendor di repo ini (sejak `0af93dc`).
- Fork dari `Mohithash/kernel_xiaomi_sm8635`
- **Branch `17` sudah tidak ada** di fork (per 08 Sep 2026). Branch yang ada: `main`, `theettam-2.7`, `theettam-2.7-lts176`, `theettam-premium-sukisu`, `bestrom-a17-theettam`, `flazen-fix-v2.1`, `peridot-6.1.175`, `vos-16.2-clean-optimized`, `releases`
- Workflow memakai branch **`main`** sebagai sumber AnyKernel3 (isi `anykernel/` identik dengan Mohithash; yang dipakai di zip adalah `anykernel.sh` generate sendiri, bukan milik fork)

## Status Task Terkini (2026-09-08 malam — SEMUA SELESAI)
1. **Fix flash abort OrangeFox** (`a76a91b`): generated + vendored `anykernel.sh` → `block=boot` + `is_slot_device=auto` (proven Mohithash); patch `ak3-core.sh` tambah fallback `/system/bin/getprop` + parsing `/proc/bootconfig` (unit-tested). Akar masalah di `logs/recovery.log` (slot via bootconfig, tanpa `getprop` di PATH installer).
2. **Job `release` auto-publish** (`a76a91b` + `d91e765`): setelah kedua leg matrix sukses → unwrap zip pembungkus (deteksi by content `anykernel.sh`), guard COUNT==2, `SHA256SUMS.txt`, publish RAW assets ke Release `Flavenz-YYYYMMDD` + notes bilingual. Bug unwrap pertama (deteksi `unzip -l | grep '\.zip$'` menghapus flashable — header `Archive:` selalu match) sudah fix di `d91e765`.
3. **Verifikasi akhir run 34283279734: 3 job HIJAU** → Release `Flavenz-20260908`: 2 zip @ 17.2 MB + SHA256SUMS.txt; zip diunduh & dicek lokal (0 nested zip, header baru ada, patch ada, sha256 OK).
4. **Docs & disclaimer + LICENSE GPLv2** (`2f03c17`, `010c8df`): README Disclaimer (project pribadi, AS-IS, tanggung jawab masing-masing, keamanan tidak dijamin), section Downloads ditulis ulang (Releases = 1 zip langsung; artifacts = dibungkus zip luar), error log sinkron.
5. **Workflow `compare-kernel-zips.yml`** (`22fa2dd`, run 34290247236 sukses): one-shot perbandingan `template/Kernel-Peridot-Fix.zip` (proven user) vs release zip vs Mohithash v2.8 → laporan otomatis di-commit ke `logs/zip-comparison-<timestamp>.md`. Hasil kunci: template = AK3 Mohithash murni + Image sendiri; zip kita **kompatibel dengan template (PASS ×4)**; AK3 upstream kini `20260904` (kita `20231020`, upstream BELUM punya bootconfig → pertahankan patch).
6. **Fix Duck Detector build time drift** (2026-09-10, commit `7e5880b`): timestamp build kernel kini diturunkan dari `ro.build.date` ROM via input `rom_build_date` (default `2026-07-01`) — uname -a sinkron dengan system, anomali "build time drift / mismatch" hilang. Droidspaces **full requirement terkonfirmasi via flash test user** (diinjeksi ke AK3 Theettam, boot OK). **Terverifikasi run 34425680767 (3 job hijau)** → Release `Flavenz-20260910`: `strings Image` dari zip yang DIUNDUH menunjukkan `#1 SMP PREEMPT Wed Jul  1 00:00:00 UTC 2026` di kedua flavor (tidak ada lagi `Sep  7 2026`), `sha256sum -c` OK/OK.
7. **VERIFIKASI FLASH — TUNTAS (2026-09-11/12, laporan user)**: zip `ack-full` dari Release `Flavenz-20260910` di-flash LANGSUNG dari asset release (tanpa injeksi ke AK3 lain) → **boot OK, stabil, tidak ada masalah performa**. Duck Detector: anomali "build time drift" **hilang** (timestamp kernel = tanggal build ROM). Checklist Droidspaces = **full requirement** ✅. Benchmark AnTuTu V12.0.1 (ack-full): 1.644.070 (tanpa cooler) → 1.813.737 (cooler, +10,3%); detail di [`docs/benchmark/benchmark-ack.md`](benchmark/benchmark-ack.md) + laporan live di `media/ack-build-kernel/Antutu-Ack.html`. Saat ROM di-update: dispatch ulang dengan `ro.build.date.utc` yang baru.
8. **PENGHAPUSAN FLAVOR guidix-full (2026-09-13, laporan user)**: zip Guidix `Peridot-Kernel-Guidix-...-droidspaces-*.zip` **BOOTLOOP** di ROM NexiunOS V5 user (bukti: `logs/recovery_20260913.log` — device diselamatkan via restore backup boot/dtbo/init_boot/vendor_boot + reflash ROM NexiunOS dari OrangeFox). Tindakan: (1) kedua asset zip Guidix dihapus dari Release `Flavenz-20260908` & `Flavenz-20260910`; (2) workflow build-droidspaces.yml → matrix 1 flavor (`ack-full` saja), guard COUNT 2→1, notes release diupdate; (3) docs/README sinkron. Catatan akar masalah: "proven boot" GuidixX 16.2 tidak berlaku untuk kombinasi ROM port user — base CLO vs vendor NexiunOS tidak cocok. ack-full (ACK murni + defconfig Mohithash) tetap jadi satu-satunya flavor.

## PENDING — Pelajari & Tiru `build-theettam.yml` (Mohithash) sebagai Acuan Alur Workflow
**Sumber acuan (JANGAN dimodifikasi isinya, murni dipelajari polanya)**: https://github.com/Mohithash/kernel_xiaomi_sm8635/blob/theettam-2.8/.github/workflows/build-theettam.yml (ada juga di branch `17` & `master`; file pendukung: `scripts/ci/build-flavor.sh`, `scripts/ci/pins.env`, `scripts/ci/kmi-baseline/`)

Alur yang membuatnya "bekerja sangat baik" (hasil analisis 2026-09-08):
1. **Plan job** — job `plan` menghasilkan daftar flavor via `$GITHUB_OUTPUT` (dinamis; flavor APatch hanya masuk matrix bila input superkey diisi) → matrix build tidak perlu diedit saat menambah flavor.
2. **Build per flavor via SATU script** — semua flavor dikerjakan `scripts/ci/build-flavor.sh` (CI dan lokal = perilaku identik: pin sama, toolchain sama, gate sama). Workflow YAML hanya orkestrasi.
3. **Concurrency guard** — `concurrency.group` per ref+event dengan `cancel-in-progress` otomatis (push baru membatalkan run lama; manual dispatch tidak).
4. **Toolchain PINNED + CHECKSUMMED** — Neutron clang `30062026` dengan `sha256sum -c` (env `NEUTRON_SHA256`), antman di-pin commit + checksum, **tidak pernah di-cache** (binari hasil patch glibc rusak saat cache restore — pernah dibuktikan `cb6b7b88612a`). antman di-retry 4× backoff (mirror hiccup wget exit 8).
5. **ccache** — `actions/cache` pada `~/.ccache` dengan restore-key per-flavor → build ulang jauh lebih cepat.
6. **KMI gate** — setiap flavor di-compile-verify & di-gate KMI terhadap baseline boot-tested (`scripts/ci/kmi-baseline/`), `KMI_STRICT=1`, output `kmi-diff.txt` di-artifact.
7. **Dua artifact terpisah** — `zip-<flavor>` (deliverable, `if-no-files-found: error`) dan `build-<flavor>` (`always()`: `out/build.log`, `Image-*`, `Module.symvers-*`, `config-*`, `kmi-diff.txt` untuk debug).
8. **Release terpisah & eksplisit** — job `release` hanya jalan bila dispatch dengan `release=true`; hasil SELALU `prerelease: true` + `make_latest: false` dengan disclaimer "compile-verified ≠ boot-tested" di body.
9. **Pins di `scripts/ci/pins.env`** — semua versi (toolchain, KSU, SUSFS) di satu file env, bukan tersebar di YAML.

**Cara kita meniru (TANPA memodifikasi workflow Mohithash — hanya mengadopsi pola ke workflow kita, base ACK murni, flavor Flavenz: `ack-full`; `guidix-full` dihapus 2026-09-13)**:
- [ ] Ekstrak logika build ke `scripts/ci/build-flavor.sh` (satu script per flavor, dipakai CI & lokal)
- [ ] Pin + checksum Neutron clang & antman di env (tambah `NEUTRON_SHA256`, `ANTMAN_SHA256`)
- [ ] Tambah job `plan` → matrix dinamis dari output (siapkan slot flavor baru tanpa edit YAML)
- [ ] Tambah `concurrency` group + `cancel-in-progress`
- [ ] Tambah ccache per-flavor + `timeout-minutes: 180`
- [ ] Pertimbangkan KMI gate sederhana (bandingkan symbol/kmi versi `ack-full` vs baseline Image yang proven boot)
- [ ] Pecah artifact jadi `zip-*` (error) + `build-*` (always, log + build artifacts)
- [ ] Release: pertahankan job `release` milik kita (sudah jalan), tambahkan pola `prerelease` bila build belum boot-tested

## Next Decision Point
Matrix kini tinggal satu opsi (per 2026-09-13):
- ~~**guidix-full** = Opsi A (GuidixX 16.2 — ACK + CLO, proven boot)~~ → **DIHAPUS: bootloop on-device** (logs/recovery_20260913.log) — "proven boot" GuidixX ternyata tidak berlaku untuk ROM NexiunOS V5 user
- **ack-full** = Opsi B (ACK murni + defconfig Mohithash) — **boot-verified** di ROM user (release Flavenz-20260910)
Kalau nanti mau coba base lain, tambahkan sebagai flavor matrix baru + verifikasi boot dulu sebelum dipublikasikan.

## Referensi Penting
- Droidspaces config guide: `ravindu644/Droidspaces-OSS/blob/main/Documentation/Kernel-Configuration.md`
- KernelSU Next setup: `curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/dev-susfs/kernel/setup.sh" | bash -s v3.3.0` (pershoot/dev-susfs — SUSFS hooks built-in, proven via WildKernels r7-r12)
- SUSFS branch untuk kernel 6.1: `gki-android14-6.1` di `gitlab.com/simonpunk/susfs4ksu`
- Antman (Neutron glibc patcher): `github.com/Neutron-Toolchains/antman`
- MiCode peridot source: `github.com/MiCode/Xiaomi_Kernel_OpenSource` branch `peridot-u-oss`
- Mirror MiCode aktif: `github.com/Peridot-Development/kernel_xiaomi_peridot` branch `peridot-u-oss`
- GuidixX (ACK+CLO): `github.com/GuidixX/kernel_xiaomi_sm8635` branch `16.2`
- ~~AnyKernel3 (via fork): `github.com/ZxAlif-ID/Kernel_F6` branch `main`~~ → folder `anykernel/` (vendor lokal, sumber tunggal sejak `0af93dc`)

## Catatan Lain
- ROM port, kernel harus bersih dari tweak
- Gaming adalah prioritas utama
- Flavor "full" include KernelSU via init_boot (GKI mode)
- Theettam tweaknya: BORE, ADIOS, BBRv3, MGLRU, TEO, HZ=300, CAKE, uclamp — semua dari Mohithash, bukan dari GuidixX — TIDAK dipakai

## Kebijakan Dokumen Dua Bahasa
- **`docs/kernel-context.md`** (file ini, Bahasa Indonesia) = kanon/sumber kebenaran.
- **`docs/kernel-context.en.md`** = terjemahan Inggris; WAJIB ikut diupdate setiap ada perubahan di file ini.
- Benchmark: `docs/benchmark/benchmark-ack.md` (EN + ID dalam satu file).
- Aturan: setiap PR/commit yang mengubah satu versi wajib memperbarui padanannya di commit yang sama.