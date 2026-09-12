# Changelog

All notable changes to this repository. Build releases are tagged
`Flavenz-YYYYMMDD` — see [Releases](https://github.com/ZxAlif-ID/Flavenz-Kernel-Peridot/releases).
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2026-09-12] — Repository & docs
### Added
- Community standards files: CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CITATION.cff,
  CHANGELOG, issue templates (bug / feature), .gitignore.
- Benchmark documentation for the **ack-full** build (`docs/benchmark/`) with a
  live HTML report served via **GitHub Pages**.
- Bilingual docs policy: `docs/kernel-context.md` (ID, canonical) +
  `docs/kernel-context.en.md` (EN translation); `README.md` (EN) +
  `README.id.md` (ID).
### Changed
- `docs/kernel-context.md`: Kernel_F6 marked **deprecated** (AnyKernel3 fully
  vendored since `0af93dc`); flash-test verification recorded.
- README: language switcher, benchmark section, fixed device badge link.

## [Flavenz-20260910] — 2026-09-10 (run 34425680767)
### Fixed
- **Duck Detector "Build time drift"**: `KBUILD_BUILD_TIMESTAMP` is now derived
  from the ROM's `ro.build.date` via the `rom_build_date` workflow input
  (default `2026-07-01`) instead of a hardcoded CI timestamp — `uname -a`
  matches the system build date, integrity checkers no longer flag the kernel
  (commit `7e5880b`).
### Verified
- 3/3 jobs green; both flavors embed `#1 SMP PREEMPT Wed Jul  1 00:00:00 UTC 2026`
  (checked via `strings Image` on the downloaded release zips); `sha256sum -c` OK.

## [Flavenz-20260908] — 2026-09-08 (run 34283279734)
### Fixed
- **OrangeFox flash abort** (`Unable to determine active slot`): generated +
  vendored `anykernel.sh` use the proven `block=boot` + `is_slot_device=auto`
  header; `tools/ak3-core.sh` patched with `/system/bin/getprop` and
  `/proc/bootconfig` fallbacks (`a76a91b`).
- **Release job wrapper detection**: wrapper zips are detected by content
  (`anykernel.sh` presence), not by `unzip -l | grep '\.zip$'` — flashable zips
  are no longer deleted during unwrap (`d91e765`).
### Added
- Automated `release` job publishing raw flashable zips + `SHA256SUMS.txt` to
  GitHub Releases (no zip-in-zip).
- One-shot `compare-kernel-zips.yml` (template vs release vs upstream AK3).

## [2026-09-08] — Build pipeline stabilization
### Fixed
- AnyKernel3 **vendored** into `anykernel/` (`0af93dc`) — runner-side git clones
  died silently with exit 3 during packaging; vendoring removes the failure class.
- Packaging step wrote `ZIPPATH` via `GITHUB_ENV` but read it in the same step →
  empty path, hidden zip file (`e1d2a62`).
- ACK megarepo clone dropped mid-transfer → 3-attempt retry with backoff +
  `http.lowSpeedLimit` / `http.lowSpeedTime` (`6478ccd`).

## [2026-09-07] — Initial public build pipeline
### Added
- `build-droidspaces.yml`: 2-job matrix (`guidix-full`, `ack-full`), Neutron
  Clang 30062026 + antman, KernelSU Next v3.3.0 (pershoot/dev-susfs), SUSFS
  v2.1.0, Droidspaces container configs + SYSVIPC kABI relocation patch.
