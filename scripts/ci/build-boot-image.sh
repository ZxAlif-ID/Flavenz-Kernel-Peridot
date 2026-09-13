#!/usr/bin/env bash
# =============================================================================
# scripts/ci/build-boot-image.sh
# Repack Image (ack-full) -> fla-boot.img untuk BOOT-TEST (fastboot boot, RAM-only)
#
# Tahap 1 roadmap boot-test (kernel-riset.md §2): mencegah asset tidak-teruji
# masuk Release (pelajaran kasus Guidix 2026-09-13). fla-boot.img = header
# boot.img STOCK (backup user) + payload kernel diganti Image build kita.
# Uji via `fastboot boot` -> TIDAK menulis partisi apa pun; gagal boot =
# reboot normal, tanpa risiko bootloop permanen.
#
# Sumber boot.img (resolusi prioritas):
#   1. BOOTIMG_URL   : URL langsung ke boot.img stock backup
#   2. SELFTEST=true : header SINTETIS dibuat via mkbootimg (membuktikan
#                      pipeline CI tanpa boot.img asli; hasil TIDAK untuk
#                      dipercaya sebagai header stock)
#   3. template/boot.img di repo (jika operator commit)
#
# Env tambahan:
#   SOURCE_RUN_ID : run ID build ack-full sumber Image (kosong = run sukses
#                   terakhir dari workflow "Build Kernel - Peridot (ACK)")
#   LOCAL_IMAGE   : (dev-lokal saja) path Image — skip download artifact via gh
#
# Output: dist/fla-boot-<name>.img + dist/fla-boot-info.txt (+ log unpack)
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------- paths & repo
SCRIPT_PATH="${BASH_SOURCE[0]}"
ROOT=$(cd "$(dirname "$SCRIPT_PATH")/../.." && pwd)
OUTDIR="${BOOT_OUTDIR:-$ROOT/dist}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUTDIR"

REPO="${GITHUB_REPOSITORY:-}"
if [ -z "$REPO" ]; then
  # Dev-lokal: turunkan owner/repo dari remote origin
  REPO=$(git -C "$ROOT" remote get-url origin | sed -E 's#.*github\.com[:/]##; s#\.git$##')
fi

log()  { echo "[fla-boot] $*"; }
fail() { echo "::error::[fla-boot] $*" >&2; exit 1; }

# fetch <url> <out> — retry 3x dengan backoff (transfer runner/lokal sering drop)
fetch() {
  local url="$1" out="$2" i
  for i in 1 2 3; do
    if curl -fsSL --connect-timeout 20 --max-time 600 "$url" -o "$out"; then
      return 0
    fi
    log "fetch attempt $i gagal: $url"
    rm -f "$out"
    [ "$i" = 3 ] || sleep $((i * 15))
  done
  return 1
}

require() { command -v "$1" >/dev/null 2>&1 || fail "binary '$1' tidak ditemukan"; }
for b in curl unzip sha256sum python3 git stat awk sed; do require "$b"; done

# ------------------------------------------------------------------- resolusi mode
if [ -n "${BOOTIMG_URL:-}" ]; then
  MODE=url
elif [ "${SELFTEST:-false}" = "true" ]; then
  MODE=selftest
elif [ -f "$ROOT/template/boot.img" ]; then
  MODE=repo
else
  fail "tidak ada sumber boot.img. Isi input 'bootimg_url' (URL langsung boot.img stock backup), ATAU commit file ke template/boot.img, ATAU dispatch dengan selftest=true untuk selftest pipeline."
fi
log "MODE=$MODE repo=$REPO"

# ------------------------------------------------------------------- magiskboot
# magiskboot DI-VENDOR di repo ini — NOL download eksternal saat build:
#   - aarch64 (host lokal/Droidspaces) : anykernel/tools/magiskboot (vendor AK3 0af93dc)
#   - x86_64  (runner CI)              : scripts/ci/bin/magiskboot-x86_64
#     Provenance: diekstrak dari Magisk v30.7 (topjohnwu/Magisk) asset
#     Magisk-v30.7.apk, entri lib/x86_64/libmagiskboot.so,
#     sha256 a18ecbd7981179494b7d281453d6c4e25b5c719e7d2ef7f6eba3c6be3043c58e.
# Tool ini CUMA alat repack header boot.img di sisi host; payload kernel
# tetap Image ack-full yang boot-proven (KSU-Next + SUSFS + patch Droidspaces),
# diverifikasi sha256 roundtrip di do_verify().
select_magiskboot() {
  case "$(uname -m)" in
    aarch64)
      MAGISKBOOT="$ROOT/anykernel/tools/magiskboot"
      BOOTABI=aarch64
      ;;
    x86_64)
      MAGISKBOOT="$ROOT/scripts/ci/bin/magiskboot-x86_64"
      BOOTABI=x86_64
      ;;
    *) fail "arsitektur tidak dikenal: $(uname -m)" ;;
  esac
  [ -x "$MAGISKBOOT" ] || fail "magiskboot vendor tidak ada/tak executable: $MAGISKBOOT (x86_64 harus di-commit ke scripts/ci/bin/magiskboot-x86_64)"
  # Smoke test: binary harus bisa dieksekusi (usage exit != 0 adalah normal)
  local out
  if ! out=$("$MAGISKBOOT" 2>&1); then
    printf '%s\n' "$out" | head -n 2
  fi
  log "magiskboot vendor siap ($BOOTABI): $MAGISKBOOT"
}

# ------------------------------------------------------------------- Image sumber
get_image() {
  cd "$WORK"
  if [ -n "${LOCAL_IMAGE:-}" ]; then
    cp "$LOCAL_IMAGE" Image
    log "Image dari LOCAL_IMAGE (dev-lokal): $LOCAL_IMAGE"
    SOURCE_NOTE="Image dari LOCAL_IMAGE (dev-lokal)"
    return 0
  fi

  local run_id="${SOURCE_RUN_ID:-}"
  if [ -z "$run_id" ]; then
    run_id=$(gh api "repos/$REPO/actions/workflows/build-droidspaces.yml/runs?status=success&branch=main&per_page=1" \
      --jq '.workflow_runs[0].id') || fail "query run ack-full terakhir gagal (gh api)"
    [ -n "$run_id" ] || fail "tidak ada run sukses dari build-droidspaces.yml di branch main"
  fi
  RUN_URL="https://github.com/$REPO/actions/runs/$run_id"
  log "run sumber Image: $RUN_URL"

  local art_name
  art_name=$(gh api "repos/$REPO/actions/runs/$run_id/artifacts?per_page=100" \
    --jq '[.artifacts[] | select(.name | startswith("Peridot-Kernel-ack-full-"))] | sort_by(.id) | last | .name') \
    || fail "query artifact run $run_id gagal"
  [ -n "$art_name" ] || fail "artifact Peridot-Kernel-ack-full-* tidak ditemukan di run $run_id"
  log "artifact: $art_name"

  rm -rf "$WORK/artifact_dl"
  gh run download "$run_id" -R "$REPO" -n "$art_name" -D "$WORK/artifact_dl" \
    || fail "gh run download artifact $art_name gagal"

  local akzip
  akzip=$(find "$WORK/artifact_dl" -name 'Peridot-Kernel-*.zip' | head -n1)
  [ -n "$akzip" ] || fail "zip flashable tidak ada dalam artifact $art_name"
  unzip -o "$akzip" Image -d "$WORK" >/dev/null || fail "Image tidak ada dalam zip $akzip"

  SOURCE_NOTE="Image dari artifact ${art_name} (run ${RUN_URL})"
  return 0
}

verify_image() {
  local img="$WORK/Image"
  [ -s "$img" ] || fail "Image kosong/tidak ada"
  local size
  size=$(stat -c%s "$img")
  [ "$size" -gt 8388608 ] || fail "Image terlalu kecil (${size} byte) — artifact salah?"
  # Banner uname via tr (portable, tanpa binutils strings)
  VER=$(tr -c '[:print:]' '\n' < "$img" | grep -m1 '^Linux version' || true)
  [ -n "$VER" ] || fail "banner 'Linux version' tidak ditemukan di Image"
  echo "$VER" | grep -q '6.1.138-android14-11-g0c3d559bcd85' \
    || fail "uname Image tidak cocok base 6.1.138: '${VER}'"
  log "Image OK (${size} byte): ${VER}"
}

# ------------------------------------------------------------------- boot.img sumber
make_synthetic_bootimg() {
  # Header boot image v4 dibangun MURNI python3 (format tetap, tanpa tool
  # eksternal): magic | kernel | ramdisk | v4 fields | cmdline + vendor v4 tail.
  # Cuma untuk selftest pipeline — bukan header stock peridot.
  python3 - "$WORK/Image" "$WORK/boot.img" <<'PY'
import struct, sys, gzip, os

kernel_path, out_path = sys.argv[1], sys.argv[2]

with open(kernel_path, "rb") as f:
    kernel = f.read()
# magiskboot menuntut gzip agar mengenali payload kernel saat repack
kernel_gz = gzip.compress(kernel, compresslevel=6)

pagesize = 4096
cmdline = b"fla-boot SELFTEST synthetic header - NOT stock"
# Layout resmi AOSP boot_img_hdr_v3 (total 1580 byte; v4 butuh 1584 + signature,
# jadi selftest pakai v3 yang kanonik & konsisten):
#   0  magic "ANDROID!"   8  kernel_size    12  ramdisk_size
#  16  os_version        20  header_size    24  reserved[4] (16 byte, nol)
#  40  header_version    44  cmdline[1536]
hdr = bytearray(1580)
hdr[0:8] = b"ANDROID!"
struct.pack_into("<I", hdr,  8, len(kernel_gz))   # kernel_size (payload gzip)
struct.pack_into("<I", hdr, 16, 0)                # os_version = none
struct.pack_into("<I", hdr, 20, 1580)             # header_size (v3)
struct.pack_into("<I", hdr, 40, 3)                # header_version = 3
hdr[44:44+len(cmdline)] = cmdline

# ramdisk KOSONG (ramdisk_size=0): GKI peridot memang tidak punya ramdisk di
# boot.img (init_boot terpisah) — sekaligus menghindari magiskboot EINVAL
# pada cpio gzip kosong. Terbukti OK di matrix uji: v3 tanpa ramdisk repack exit 0.
def pad_to_page(data):
    n = (len(data) + pagesize - 1) // pagesize * pagesize
    return data + b"\x00" * (n - len(data))

blob = pad_to_page(bytes(hdr)) + pad_to_page(kernel_gz)
with open(out_path, "wb") as f:
    f.write(blob)
print(f"synthetic v3: hdr={len(hdr)} kernel_gz={len(kernel_gz)} total={len(blob)}")
PY
  [ -s "$WORK/boot.img" ] || fail "boot.img sintetis tidak terbuat"
  log "boot.img SINTETIS dibuat (selftest — bukan header stock peridot)"
}

get_bootimg() {
  cd "$WORK"
  case "$MODE" in
    selftest)
      make_synthetic_bootimg
      SOURCE_HEADER="SINTETIS (mkbootimg, selftest — bukan header stock peridot)"
      ;;
    url)
      fetch "$BOOTIMG_URL" "$WORK/boot.img" || fail "download bootimg_url gagal"
      SOURCE_HEADER="boot.img stock dari BOOTIMG_URL"
      ;;
    repo)
      cp "$ROOT/template/boot.img" "$WORK/boot.img"
      SOURCE_HEADER="boot.img stock dari template/boot.img (repo)"
      ;;
  esac
  [ -s "$WORK/boot.img" ] || fail "boot.img sumber kosong"
  local size
  size=$(stat -c%s "$WORK/boot.img")
  if [ "$MODE" != "selftest" ]; then
    # Sanity gate hanya untuk header STOCK (url/repo): boot.img peridot asli
    # puluhan MB. Selftest sintetis sengaja kecil.
    [ "$size" -gt 8388608 ] || fail "boot.img sumber terlalu kecil (${size} byte) — file salah?"
  fi
  BOOT_SHA=$(sha256sum "$WORK/boot.img" | cut -d' ' -f1)
  BOOT_SIZE=$size
  log "boot.img sumber OK (${size} byte, sha256 ${BOOT_SHA})"
}

# ------------------------------------------------------------------- repack + verify
INFO_LOG="$WORK/info-log.txt"
: > "$INFO_LOG"

do_repack() {
  mkdir -p "$WORK/repack"
  cd "$WORK/repack"
  cp "$WORK/boot.img" .
  log "unpack stock boot.img..."
  "$MAGISKBOOT" unpack boot.img 2>&1 | tee unpack-stock.log | tee -a "$INFO_LOG"
  {
    echo "--- isi hasil unpack stock ---"
    ls -l | sed -n '/kernel\|ramdisk\|dtb\|second\|recovery_dtbo/p'
    echo "(catatan) magiskboot repack memakai header file asli apa adanya, hanya update ukuran field."
  } | tee -a "$INFO_LOG"

  # Payload kernel diganti Image kita (GKI peridot: init_boot terpisah, ramdisk
  # generic TIDAK di boot.img — ramdisk/dtb yang ada dibiarkan utuh).
  cp "$WORK/Image" ./kernel

  "$MAGISKBOOT" repack boot.img fla-boot.img 2>&1 | tee repack.log | tee -a "$INFO_LOG"
  [ -s fla-boot.img ] || fail "repack tidak menghasilkan fla-boot.img"
  log "repack OK: $(stat -c%s fla-boot.img) byte"
}

do_verify() {
  mkdir -p "$WORK/verify"
  cd "$WORK/verify"
  cp "$WORK/repack/fla-boot.img" .
  log "verifikasi: unpack ulang fla-boot.img (roundtrip)..."
  "$MAGISKBOOT" unpack fla-boot.img 2>&1 | tee unpack-new.log | tee -a "$INFO_LOG"
  [ -s kernel ] || fail "roundtrip: kernel tidak ada di hasil unpack ulang"

  local sha_img sha_k2
  sha_img=$(sha256sum "$WORK/Image" | cut -d' ' -f1)
  sha_k2=$(sha256sum kernel | cut -d' ' -f1)
  if [ "$sha_img" = "$sha_k2" ]; then
    echo "[verify] payload kernel IDENTIK dengan Image sumber (sha256 sama)" | tee -a "$INFO_LOG"
  else
    fail "roundtrip gagal: sha256 kernel repack (${sha_k2}) != Image sumber (${sha_img})"
  fi

  # Komponen non-kernel WAJIB identik dengan unpack stock (tidak tersentuh)
  local rp="$WORK/repack" f ok=1
  for f in ramdisk.cpio dtb second recovery_dtbo extra; do
    if [ -f "$rp/$f" ]; then
      if [ -f "$f" ] && [ "$(sha256sum "$rp/$f" | cut -d' ' -f1)" = "$(sha256sum "$f" | cut -d' ' -f1)" ]; then
        echo "[verify] $f terpreservasi identik" | tee -a "$INFO_LOG"
      else
        echo "[verify] GAGAL: $f berubah saat repack" | tee -a "$INFO_LOG"
        ok=0
      fi
    fi
  done
  [ "$ok" = 1 ] || fail "ada komponen non-kernel yang berubah saat repack"

  # Dump header 128 byte pertama (human-verifiable di info file)
  { echo "--- header hexdump stock (128 byte) ---"; xxd -l 128 "$WORK/boot.img" 2>/dev/null || od -A x -t x1z -N 128 "$WORK/boot.img"
    echo "--- header hexdump fla-boot (128 byte) ---"; xxd -l 128 "$WORK/repack/fla-boot.img" 2>/dev/null || od -A x -t x1z -N 128 "$WORK/repack/fla-boot.img"
  } | tee -a "$INFO_LOG"
}

# ------------------------------------------------------------------- stage + info
stage_out() {
  local new_size new_sha date_suffix name
  new_size=$(stat -c%s "$WORK/repack/fla-boot.img")
  new_sha=$(sha256sum "$WORK/repack/fla-boot.img" | cut -d' ' -f1)
  date_suffix=$(date -u +%Y%m%d)
  name="fla-boot-${date_suffix}"
  [ "$MODE" = "selftest" ] && name="${name}-selftest"

  cp "$WORK/repack/fla-boot.img" "$OUTDIR/${name}.img"

  {
    echo "=== fla-boot.img build info (${date_suffix} UTC) ==="
    echo "Mode              : $MODE"
    echo "Sumber header     : $SOURCE_HEADER"
    echo "Sumber kernel     : $SOURCE_NOTE"
    echo "Banner Image      : ${VER}"
    echo "boot.img stock    : ${BOOT_SIZE} byte, sha256 ${BOOT_SHA}"
    echo "fla-boot.img      : ${new_size} byte, sha256 ${new_sha}"
    echo ""
    if [ "$MODE" = "selftest" ]; then
      echo "!!! MODE SELFTEST: header sintetis, BUKAN header stock peridot."
      echo "!!! File ini HANYA membuktikan pipeline. Jangan dipakai uji boot device."
      echo ""
    fi
    echo "=== CARA UJI (RAM-only, tidak menulis partisi) ==="
    echo "1. Download artifact ini, ekstrak zip Actions (artifact selalu dibungkus zip)"
    echo "2. Reboot ke bootloader, lalu:  fastboot boot ${name}.img"
    echo "3. Catat hasil: uname -r, uptime, apakah ada panic/reboot sendiri"
    echo ""
    echo "Jika bootloader Xiaomi memblokir 'fastboot boot':"
    echo "  fallback slot nonaktif + fastboot set_active (reversible, TAPI menyentuh"
    echo "  partisi — risiko lebih tinggi; diskusi dulu sebelum dilakukan)."
    echo ""
    echo "=== Log unpack ==="
    cat "$INFO_LOG"
  } > "$OUTDIR/fla-boot-info.txt"

  # Export ke step berikutnya (CI saja — GITHUB_ENV tidak ada di dev-lokal)
  if [ -n "${GITHUB_ENV:-}" ]; then
    {
      echo "BOOT_ARTIFACT_NAME=${name}"
      echo "BOOT_OUTDIR=${OUTDIR}"
    } >> "$GITHUB_ENV"
  fi

  log "dist: ${OUTDIR}/${name}.img + fla-boot-info.txt"
  ls -lh "$OUTDIR"
}

select_magiskboot
get_image
verify_image
get_bootimg
do_repack
do_verify
stage_out
log "SELESAI — fla-boot.img siap di-download untuk boot-test"
