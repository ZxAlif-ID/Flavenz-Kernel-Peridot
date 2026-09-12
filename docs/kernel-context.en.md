# Kernel Build Context — Peridot (POCO F6)

> English translation of kernel-context.md (Bahasa Indonesia, canonical).
> Update both files together on every change.

## Device Info
- **Device**: Xiaomi POCO F6 / Redmi Turbo 3 (codename: peridot)
- **Chipset**: Snapdragon 8s Gen 3 (SM8635)
- **ROM**: Port of the Redmi Turbo 3 / nezha vendor, HyperOS 3
- **Android**: 16 (API 36)
- **Fingerprint**: `Redmi/peridot/peridot:14/UKQ1.240624.001/OS3.0.310.0.WNPCNXM`

## Stock Kernel Info
- **Kernel string**: `6.1.138-android14-11-g0c3d559bcd85-ab14529422`
- **Commit prefix**: `0c3d559bcd85`
- **Stock toolchain**: AOSP clang 17.0.2 r487747c + PGO + BOLT + LTO
- **Build date**: Wed Dec 3 02:05:30 UTC 2025
- **Type**: GKI kernel 6.1
- **Scheduler**: schedutil + sugov (standard GKI, no WALT)
- **No Xiaomi tweaks** in the kernel — pure stock GKI
- **Stock performance is good** purely because of PGO+BOLT+LTO at compile time, not kernel tweaks

## Build Goals
- Kernel close to stock + Droidspaces for gaming
- **Do not use** the Theettam kernel (BORE, ADIOS, BBRv3 etc. = unwanted performance tweaks)
- Root: KernelSU Next v3.3.0
- Priorities: gaming performance + Droidspaces container

## Kernel Base Research
Based on deep research + Gemini AI confirmation + official Android documentation:

### Peridot kernel hierarchy:
1. **Pure ACK** = cannot boot on peridot without device tree/CLO — not practical
2. **GuidixX 16.2** = ACK + Qualcomm CLO = closest to stock, proven boot on peridot ← used for flavor **guidix-full**
3. **MiCode peridot-u-oss** = official Xiaomi source (most accurate) but needs Bazel + multi-repo sync (not practical on GitHub Actions)
4. **Peridot-Development/kernel_xiaomi_peridot** = pure MiCode mirror, branch `peridot-u-oss`, last update July 2026

### Important repos found:
- `MiCode/Xiaomi_Kernel_OpenSource` branch `peridot-u-oss` — official Xiaomi source
- `Peridot-Development/kernel_xiaomi_peridot` branch `peridot-u-oss` — active MiCode mirror
- `GuidixX/kernel_xiaomi_sm8635` branch `16.2` — ACK + CLO, proven → base of flavor **guidix-full**
- `Mohithash/kernel_xiaomi_sm8635` branch `17` — ACK + CLO + BORE/ADIOS (contains tweaks); used only as **source of defconfig + anykernel**, not as a base
- `ZxAlif-ID/Kernel_F6` — **private fork** of `Mohithash/kernel_xiaomi_sm8635`, branch `main`; used as the **AnyKernel3** source in the workflow (DEPRECATED — see the note below)

### Why stock kernel + Droidspaces is not possible:
Droidspaces needs namespace configs that do NOT exist in the stock Xiaomi kernel. A new kernel build is mandatory — no shortcut.

## Droidspaces Check Result
```
[✗] PID namespace        → CONFIG_PID_NS=y needs to be added
[✗] IPC namespace        → CONFIG_IPC_NS=y needs to be added
[✗] devtmpfs support     → optional
[✗] User namespace       → optional, for Docker
```
Everything else already PASSES (Network NS, Bridge, Veth, OverlayFS, etc.).

## Configs added (Droidspaces + build)
Appended to `gki_defconfig` (or `vendor/peridot_GKI.config` if present) by the "Apply Droidspaces & Container Configs" step:
```
CONFIG_SYSVIPC=y        ← mandatory + kABI relocation patch
CONFIG_PID_NS=y         ← mandatory
CONFIG_IPC_NS=y         ← mandatory
CONFIG_USER_NS=y
CONFIG_NET_NS=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_POSIX_MQUEUE=y   ← mandatory
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_TMPFS_XATTR=y
CONFIG_LTO=y / CONFIG_LTO_CLANG=y / CONFIG_LTO_CLANG_THIN=y
CONFIG_KALLSYMS=y / CONFIG_KALLSYMS_ALL=y
```

## Configs that must NOT be enabled
- `CONFIG_CGROUP_DEVICE`, `CONFIG_CGROUP_PIDS`, `CONFIG_BRIDGE_NETFILTER`, `CONFIG_NF_TABLES`
- Reason: proven to bootloop on peridot (from Mohithash's notes)

## Required patches (GKI 6.1)
- **Mandatory kABI patch**: `001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch`
  - Location: `ravindu644/Droidspaces-OSS` → `Documentation/resources/kernel-patches/GKI/below-kernel-6.12/`
  - Purpose: relocate SYSVIPC into ANDROID_KABI_RESERVE slots 6/7/8 so vendor_dlkm does not crash
- **SUSFS patches** (both flavors):
  - `susfs/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch` (branch `gki-android14-6.1`)
  - Manual copy: `susfs/kernel_patches/fs/susfs.c` → `kernel/fs/` and `susfs/kernel_patches/include/linux/susfs*.h` → `kernel/include/linux/`
  - `10_enable_susfs_for_ksu.patch` — **not needed**, already built into pershoot/dev-susfs

## Current Workflow Flow (build-droidspaces.yml)
- **Trigger**: `workflow_dispatch` (manual, Actions → Run workflow)
- **Matrix of 2 parallel jobs** (`fail-fast: false`):
  1. **guidix-full** — clone `GuidixX/kernel_xiaomi_sm8635` branch `16.2`
  2. **ack-full** — clone ACK `kernel/common` @ `0c3d559bcd85` + defconfig from `Mohithash/kernel_xiaomi_sm8635` (dynamic branch fallback: `17` → `main` → `theettam-2.8` → `theettam-2.7`)
- Common steps: free disk space → install dependencies (bc, bison, flex, libssl, cpio, pahole, lz4, zstd, gcc-aarch64-linux-gnu, etc.) → setup Neutron Clang 30062026 + antman glibc patch → apply Droidspaces & container configs → apply kABI SYSVIPC patch → setup KernelSU Next v3.3.0 (pershoot/dev-susfs) → setup SUSFS v2.1.0 → build (`gki_defconfig` [+ `vendor/peridot_GKI.config`], `Image Image.gz dtbs`) → **Package AnyKernel3** → upload artifact
- Output: artifact per run + **automatic `release` job** — after both matrix jobs succeed, raw flashable zips + `SHA256SUMS.txt` are published as **GitHub Releases** assets (tag `Flavenz-YYYYMMDD`) with full notes; no zip-in-zip (release assets are never wrapped, unlike Actions artifacts)
- Deterministic build: `KBUILD_BUILD_USER/HOST` pinned; `KBUILD_BUILD_TIMESTAMP` **dynamic** from the `rom_build_date` input (synced to the ROM's `ro.build.date` — fixes Duck Detector build-time drift, see the error table)

### Package AnyKernel3 — AK3 source
- AnyKernel3 is **never cloned at build time** — cloning from any repo (`osm0sis/AnyKernel3`, own fork) proved to die silently with `exit code 3` on the runner (see error log)
- **Now vendored into the repo** (`0af93dc`): `anykernel/` folder at the repo root (initial source: `ZxAlif-ID/Kernel_F6@main`, rewritten to Flavenz). The workflow simply uses it at packaging time
- `anykernel.sh` is generated by the workflow itself via `printf` (Flavenz branding, `do.devicecheck=1`, `device.name1=peridot`, proven peridot header: `block=boot`, `is_slot_device=auto`, `split_boot; flash_boot;`, `ui_print`, `ramdisk_compression=auto` — identical to Mohithash's anykernel.sh; do NOT use `block=/dev/block/by-name/boot` + `is_slot_device=1`, its slot detection fails on OrangeFox → abort, see error log)
- Zip contents: `anykernel.sh`, `Image` (+ `Image.gz`), `META-INF/` (update-binary, updater-script), `tools/` (ak3-core.sh, magiskboot, busybox, etc.)
- Verification: run 34256171472 — both jobs green, 2 artifacts @ 17.2 MB

## Output ZIP (artifact per flavor)
```
Peridot-Kernel-Guidix-KSUNext-v3.3.0-SUSFS-v2.1.0-droidspaces-YYYYMMDD.zip   (guidix-full)
Peridot-Kernel-ACK-KSUNext-v3.3.0-SUSFS-v2.1.0-droidspaces-YYYYMMDD.zip       (ack-full)
```

## Toolchain
- **Neutron Clang 23** build `30062026`
  - URL: `https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/30062026/neutron-clang-30062026.tar.zst`
  - Needs **antman** for the glibc patch that makes it compatible with the Ubuntu runner
  - antman commit: `0b32c45e3ad83a953b4bc3fd2feb4ad3cc87c1e8`
- Cross compile: `gcc-aarch64-linux-gnu` + `gcc-arm-linux-gnueabi` via apt

## Errors already fixed
| Error | Fix |
|---|---|
| `ubuntu-22.04` deprecated | Switch to `ubuntu-24.04` |
| `upload-artifact@v4` outdated | Update to `@v7` (then removed in v1.9) |
| No `actions/checkout` | Add `actions/checkout@v6` |
| Heredoc defconfig indent bug | Switch to `printf` |
| `inputs.flavor` wrong context | Fix to `github.event.inputs.flavor` |
| `Image.gz-dtb` legacy format | Fix to `Image` + `Image.gz` |
| Missing free disk space | Add a free-disk-space step |
| Cross-compile toolchain missing | Add `gcc-aarch64-linux-gnu` via apt |
| `kernel` dir already exists when cloning | Add `rm -rf kernel` before clone |
| `peridot_defconfig` missing in GuidixX | Switch source to Mohithash, use `gki_defconfig` + `peridot_GKI.config` |
| `mkdir vendor` after `cp` | Fix order: `mkdir` first, then `cp` |
| ZyCromerZ 17.0.6 URL dead | Switch to 16.0.6-20260807 |
| `ld.lld not found` in ZyCromerZ | Switch to Neutron Clang 23 |
| Neutron without antman glibc patch | Add antman `--patch=glibc` |
| `-Wdefault-const-init-*` error | Copy `Makefile.extrawarn` from Mohithash |
| `-Wuninitialized-const-pointer` error | Append disable flag to `Makefile.extrawarn` |
| Heredoc `<< 'EOF'` inside `run: \|` | Switch to `printf '%s\n'` per line — the YAML parser misreads an unindented EOF terminator |
| `${FLAVOR}` unavailable in the Push step | Inject via `env: FLAVOR: ${{ github.event.inputs.flavor }}` in the Push step |
| `git checkout/switch` fails on a dirty working dir | Add `git clean -fdx` + `git reset --hard HEAD` before switching branch |
| SUSFS patch error `No such file or directory` | Fix explicit paths: copy `fs/susfs.c` + `include/linux/susfs*.h`, apply the patch per file instead of globbing `GKI/*.patch` |
| ZIP lands at the root of the `releases/` branch | Fix: zip goes into the `${RELEASEDATE}/` subfolder |
| ZIPNAME `full` flavor not informative | Fix: `Peridot-Kernel-KSUNext-{VER}-SUSFS-{VER}-droidspaces-{DATE}.zip` |
| KSU-Next `next` branch does not include SUSFS hooks | Switch to `pershoot/KernelSU-Next` branch `dev-susfs` — hooks built in, `10_enable_susfs_for_ksu.patch` not needed |
| `fatal: Remote branch theettam-2.7 not found` | Implement a **Dynamic Branch Fallback Loop** (`17` → `main` → `theettam-2.8` → `theettam-2.7`) for defconfig cloning |
| **Package AnyKernel3 fails with `exit code 3` in both jobs** | **Root cause**: `git clone https://github.com/osm0sis/AnyKernel3` dies on the runner (log: "Cloning into 'anykernel'..." then immediate exit 3, no fatal message — consistent across all runs; other clones in the same run succeed). **Fix**: switch the source to the **private fork** `ZxAlif-ID/Kernel_F6` branch `main` (sparse clone of the `anykernel/` folder only) |
| `anykernel.sh` contains a literal `${FLAVOR}` | Heredoc `<< 'EOF'` → `<< EOF` so `${FLAVOR}` expands |
| `print` missing in ak3-core.sh | Replace `print "..."` → `ui_print "..."` (only `ui_print` is defined) |
| Artifact name always "release" | Set `RELEASEDATE=${DATE}` in the Package step so the artifact name includes the date |
| **Package AnyKernel3 fails with `exit code 3` even with our own fork** | **Root cause: git clone ON THE RUNNER dies silently (no git message) for any repo during the packaging step** (osm0sis runs #4/#5, fork `ZxAlif-ID/Kernel_F6` run #6) — while the same clone succeeds locally → concluded a runner problem, not a repo problem. **Fix `0af93dc`**: vendor AnyKernel3 into the repo (`anykernel/` folder), no clone at all during packaging; `anykernel.sh` generated via `printf` (header at the time still `block=/dev/block/by-name/boot` + `is_slot_device=1` — later changed to `block=boot` + `is_slot_device=auto` in `a76a91b`, see the OrangeFox row below), package `Image` (not Image.gz), `ramdisk_compression=auto` |
| Packaging step "succeeds" but 0 artifacts | `ZIPPATH` written via `GITHUB_ENV` — that variable is ONLY visible in the NEXT step, so in the same step its value is empty → `zip -r9 "" ...` exits 0 but writes a hidden `.zip`. **Fix `e1d2a62`**: plain shell variables + a `[ -s ]` guard before upload + `if-no-files-found: error` |
| ack-full fails cloning ACK: `fetch-pack: unexpected disconnect / early EOF` exit 128 | Cloning the `android.googlesource.com/kernel/common` megarepo often drops mid-transfer on the runner (~4-5 minutes). **Fix `6478ccd`**: 3 retry attempts + exponential backoff + `http.lowSpeedLimit`/`http.lowSpeedTime` so a stalled clone fails fast |
| **Flash on OrangeFox R12 fails: `Unable to determine active slot. Aborting...` → `Updater process ended with ERROR: 1`** (evidence: `logs/recovery.log:1725-1729`) | AK3 base 20231020 detects the slot only via `getprop` + `/proc/cmdline`; on peridot/HyperOS 3 GKI 6.1, `androidboot.slot_suffix` arrives via **bootconfig** (`/proc/bootconfig`) and the OrangeFox installer shell has no `getprop` in PATH — while recovery itself knows the slot (`ro.boot.slot_suffix=_a`, log line 930). **Fix**: (1) the generated `anykernel.sh` uses `block=boot` + `is_slot_device=auto` (identical to Mohithash's proven anykernel.sh; `auto` never aborts); (2) patch `tools/ak3-core.sh` adding a `/system/bin/getprop` fallback + `/proc/bootconfig` parsing as defense-in-depth |
| **Zip in zip (GitHub artifacts wrapped in an outer zip)** | Default `upload-artifact` behavior: a downloaded artifact is always wrapped in `<artifact>.zip` → extract → flashable zip inside. **Fix**: a new `release` job publishes the flashable zips raw as **GitHub Releases** assets (release assets are never wrapped) + `SHA256SUMS.txt` + release notes; the job runs only if both matrix jobs succeed |
| **Run 34279539210: release job failed `expected exactly 2 flashable zips, found 0`** | Two bugs in my own unwrap logic: (1) wrapper detection via `unzip -l \| grep '\.zip$'` — the FIRST line of `unzip -l` output is always `Archive: <path>.zip`, so EVERY zip was detected as a "wrapper" → extracted, and the flashable zip inside got DELETED; (2) `download-artifact@v4` + `merge-multiple: true` already extracts the artifact contents (flashable zip intact at the root), so there was never a wrapper at all. **Fix `d91e765`**: detect by CONTENT (an AK3 zip always contains `anykernel.sh`; only a zip WITHOUT `anykernel.sh` is treated as a wrapper) + log `flashable (keep)` / `unwrapping wrapper zip` + the `COUNT == 2` guard kept as a safety net. Local dry-run of 2 layouts (plain & wrapper) passed before push |
| **Duck Detector "Build time drift": kernel `2026-09-07` vs system `2026-07-01` (68-day diff)** | **Root cause**: `KBUILD_BUILD_TIMESTAMP` hardcoded as `Mon Sep  7 12:00:00 UTC 2026` in the workflow, while the system build date (≈ `ro.build.date` of the HyperOS 3 port ROM) = 2026-07-01. Duck Detector compares the date in `#1 SMP PREEMPT ...` (uname -a, from `uts_banner`) against the system build date → the 68-day mismatch is flagged as a custom-kernel anomaly. (Ref: KSUN webroot — "Duck Detector: Build time drift" appears when the uname timestamp is out of sync; Integrity-Box sells "Spoof Build Time" as the fix, we fix it at the source during build.) **Fix**: new workflow input `rom_build_date` (default `2026-07-01`); the `Compute ROM-synced build timestamp` step derives `KBUILD_BUILD_TIMESTAMP` into uts_banner format (`Wed Jul  1 00:00:00 UTC 2026`) — accepts an epoch (`ro.build.date.utc`, recommended), `YYYY-MM-DD`, or a full `ro.build.date` string; hard-fails if unparseable. When the ROM is updated: re-dispatch with the new `ro.build.date.utc` → uname re-syncs automatically. |
| **Final verification (run 34283279734): ALL GREEN** | `guidix-full` ✅ `ack-full` ✅ `Publish to GitHub Releases` ✅ → Release **`Flavenz-20260908`** published (Latest): 2 zips @ 17.2 MB + `SHA256SUMS.txt`. Checked locally from the DOWNLOADED zips: 0 nested zips, the new headers `block=boot;` + `is_slot_device=auto;` present inside the zip, bootconfig patch present in `tools/ak3-core.sh`, `sha256sum -c` OK/OK. https://github.com/ZxAlif-ID/Flavenz-Kernel-Peridot/releases/tag/Flavenz-20260908 |

## Fork Note (ZxAlif-ID/Kernel_F6) — DEPRECATED 2026-09-12
> This repo is no longer used. The history below is kept only as a historical archive; the AnyKernel3
> source is now 100% the `anykernel/` folder vendored in this repo (since `0af93dc`).
- Fork of `Mohithash/kernel_xiaomi_sm8635`
- **Branch `17` no longer exists** on the fork (as of Sep 8, 2026). Remaining branches: `main`, `theettam-2.7`, `theettam-2.7-lts176`, `theettam-premium-sukisu`, `bestrom-a17-theettam`, `flazen-fix-v2.1`, `peridot-6.1.175`, `vos-16.2-clean-optimized`, `releases`
- The workflow used branch **`main`** as the AnyKernel3 source (its `anykernel/` contents are identical to Mohithash's; what ships in the zip is our own generated `anykernel.sh`, not the fork's)

## Current Task Status (verified flash — COMPLETE)
1. **OrangeFox flash-abort fix** (`a76a91b`): generated + vendored `anykernel.sh` → `block=boot` + `is_slot_device=auto` (Mohithash-proven); `ak3-core.sh` patched with a `/system/bin/getprop` fallback + `/proc/bootconfig` parsing (unit-tested). Root cause found in `logs/recovery.log` (slot via bootconfig, no `getprop` in the installer's PATH).
2. **Automatic `release` job** (`a76a91b` + `d91e765`): after both matrix legs succeed → unwrap wrapper zips (content-based detection via `anykernel.sh`), COUNT==2 guard, `SHA256SUMS.txt`, publish RAW assets to Release `Flavenz-YYYYMMDD` + bilingual notes. The first unwrap bug (detecting via `unzip -l | grep '\.zip$'` deleted the flashable — the `Archive:` header always matched) was fixed in `d91e765`.
3. **Final verification run 34283279734: 3 GREEN jobs** → Release `Flavenz-20260908`: 2 zips @ 17.2 MB + SHA256SUMS.txt; zips downloaded and checked locally (0 nested zips, new headers present, patch present, sha256 OK).
4. **Docs & disclaimer + LICENSE GPLv2** (`2f03c17`, `010c8df`): README Disclaimer (personal project, AS-IS, each user bears their own responsibility, no security guarantee), Downloads section rewritten (Releases = 1 direct zip; artifacts = wrapped in an outer zip), error log synced.
5. **Workflow `compare-kernel-zips.yml`** (`22fa2dd`, run 34290247236 success): one-shot comparison of `template/Kernel-Peridot-Fix.zip` (user-proven) vs our release zip vs Mohithash v2.8 → report auto-committed to `logs/zip-comparison-<timestamp>.md`. Key result: template = pure Mohithash AK3 + its own Image; our zip is **compatible with the template (PASS ×4)**; AK3 upstream is now `20260904` (ours `20231020`, upstream still lacks bootconfig → keep the patch).
6. **Duck Detector build-time-drift fix** (2026-09-10, commit `7e5880b`): the kernel build timestamp is now derived from the ROM's `ro.build.date` via the `rom_build_date` input (default `2026-07-01`) — uname -a is synced with the system, the "build time drift / mismatch" anomaly is gone. Droidspaces **full requirements confirmed via the user's flash test** (injected into AK3 Theettam, boot OK). **Verified by run 34425680767 (3 green jobs)** → Release `Flavenz-20260910`: `strings Image` from the DOWNLOADED zips shows `#1 SMP PREEMPT Wed Jul  1 00:00:00 UTC 2026` on both flavors (no more `Sep  7 2026`), `sha256sum -c` OK/OK.
7. **FLASH VERIFICATION — COMPLETE (2026-09-11/12, user report)**: the `ack-full` zip from Release `Flavenz-20260910` was flashed STRAIGHT from the release asset (no injection into another AK3) → **boots OK, stable, no performance issues**. Duck Detector: the "build time drift" anomaly is **gone** (kernel timestamp = ROM build date). Droidspaces checklist = **full requirement** ✅. AnTuTu V12.0.1 benchmark (ack-full): 1,644,070 (no cooler) → 1,813,737 (cooler, +10.3%); details in `docs/benchmark/benchmark-ack.md` + the live report in `media/ack-build-kernel/Antutu-Ack.html`. When the ROM is updated: re-dispatch with the new `ro.build.date.utc`.

## PENDING — Study & Mirror `build-theettam.yml` (Mohithash) as the Workflow Reference
**Reference source (do NOT modify it, purely study the pattern)**: https://github.com/Mohithash/kernel_xiaomi_sm8635/blob/theettam-2.8/.github/workflows/build-theettam.yml (also on branches `17` & `master`; supporting files: `scripts/ci/build-flavor.sh`, `scripts/ci/pins.env`, `scripts/ci/kmi-baseline/`)

What makes it "work very well" (analysis of 2026-09-08):
1. **Plan job** — a `plan` job produces the flavor list via `$GITHUB_OUTPUT` (dynamic; the APatch flavor only enters the matrix when a superkey input is provided) → the build matrix never needs editing when adding flavors.
2. **Per-flavor build via ONE script** — every flavor is handled by `scripts/ci/build-flavor.sh` (CI and local behave identically: same pins, same toolchain, same gates). The workflow YAML only orchestrates.
3. **Concurrency guard** — `concurrency.group` per ref+event with automatic `cancel-in-progress` (a new push cancels an old run; manual dispatch does not).
4. **Toolchain PINNED + CHECKSUMMED** — Neutron clang `30062026` with `sha256sum -c` (env `NEUTRON_SHA256`), antman pinned to a commit + checksum, **never cached** (glibc-patched binaries rot on cache restore — proven once by `cb6b7b88612a`). antman retried 4× with backoff (mirror hiccup, wget exit 8).
5. **ccache** — `actions/cache` on `~/.ccache` with a per-flavor restore-key → rebuilds are far faster.
6. **KMI gate** — every flavor is compile-verified & KMI-gated against a boot-tested baseline (`scripts/ci/kmi-baseline/`), `KMI_STRICT=1`, `kmi-diff.txt` emitted as an artifact.
7. **Two separate artifacts** — `zip-<flavor>` (deliverable, `if-no-files-found: error`) and `build-<flavor>` (`always()`: `out/build.log`, `Image-*`, `Module.symvers-*`, `config-*`, `kmi-diff.txt` for debugging).
8. **Separate & explicit release** — the `release` job only runs when dispatching with `release=true`; results are ALWAYS `prerelease: true` + `make_latest: false` with a "compile-verified ≠ boot-tested" disclaimer in the body.
9. **Pins in `scripts/ci/pins.env`** — all versions (toolchain, KSU, SUSFS) in one env file, not scattered across YAML.

**How we mirror it (WITHOUT modifying Mohithash's workflow — only adopting the patterns into our workflow; bases stay pure ACK & GuidixX, Flavenz flavors: `guidix-full`/`ack-full`)**:
- [ ] Extract build logic into `scripts/ci/build-flavor.sh` (one script per flavor, used by CI & local)
- [ ] Pin + checksum Neutron clang & antman in env (add `NEUTRON_SHA256`, `ANTMAN_SHA256`)
- [ ] Add a `plan` job → dynamic matrix from output (slot for new flavors without YAML edits)
- [ ] Add a `concurrency` group + `cancel-in-progress`
- [ ] Add per-flavor ccache + `timeout-minutes: 180`
- [ ] Consider a simple KMI gate (compare symbols/kmi version of `ack-full` vs a boot-proven baseline Image)
- [ ] Split artifacts into `zip-*` (error) + `build-*` (always, log + build artifacts)
- [ ] Release: keep our existing `release` job (already working), add the `prerelease` pattern when a build is not yet boot-tested

## Next Decision Point
Both base options are implemented as a matrix:
- **guidix-full** = Option A (GuidixX 16.2 — ACK + CLO, proven boot)
- **ack-full** = Option B (pure ACK + Mohithash defconfig)
Remaining verification comes from build results: if one flavor errors or underperforms, it can be dropped from the matrix without touching the other (`fail-fast: false`).

## Key References
- Droidspaces config guide: `ravindu644/Droidspaces-OSS/blob/main/Documentation/Kernel-Configuration.md`
- KernelSU Next setup: `curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/dev-susfs/kernel/setup.sh" | bash -s v3.3.0` (pershoot/dev-susfs — SUSFS hooks built in, proven via WildKernels r7-r12)
- SUSFS branch for kernel 6.1: `gki-android14-6.1` on `gitlab.com/simonpunk/susfs4ksu`
- Antman (Neutron glibc patcher): `github.com/Neutron-Toolchains/antman`
- MiCode peridot source: `github.com/MiCode/Xiaomi_Kernel_OpenSource` branch `peridot-u-oss`
- Active MiCode mirror: `github.com/Peridot-Development/kernel_xiaomi_peridot` branch `peridot-u-oss`
- GuidixX (ACK+CLO): `github.com/GuidixX/kernel_xiaomi_sm8635` branch `16.2`
- ~~AnyKernel3 (via fork): `github.com/ZxAlif-ID/Kernel_F6` branch `main`~~ → `anykernel/` folder (local vendor, sole source since `0af93dc`)

## Other Notes
- Ported ROM — the kernel must stay free of tweaks
- Gaming is the top priority
- Flavor "full" includes KernelSU via init_boot (GKI mode)
- Theettam's tweaks: BORE, ADIOS, BBRv3, MGLRU, TEO, HZ=300, CAKE, uclamp — all from Mohithash, not from GuidixX — NOT used

## Bilingual Document Policy
- **`docs/kernel-context.md`** (this file's Indonesian original) = canonical source of truth.
- **`docs/kernel-context.en.md`** (this file) = the English translation; it MUST be updated whenever the canonical file changes.
- Benchmark: `docs/benchmark/benchmark-ack.md` (EN + ID in one file).
- Rule: every PR/commit that changes one version must update its counterpart in the same commit.
