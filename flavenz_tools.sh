#!/system/bin/sh
# ╔══════════════════════════════════════════════╗
# ║   FLAVENZ KERNEL TOOLS — v1.0.0              ║
# ║   SM8635 Peridot · Termux · interactive CLI  ║
# ╚══════════════════════════════════════════════╝
# Usage: sh /sdcard/flavenz_tools.sh
# Auto-escalate ke root via su jika bukan root

# ─── AUTO SU ───────────────────────────────────
if [ "$(id -u)" != "0" ]; then
  exec su -c "sh $0 $*"
fi

# ─── CONSTANTS ────────────────────────────────
VERSION="1.1.0"
PROFILE_DIR="/sdcard/Project/Kernel/Profile"
DOWNLOAD_DIR="/sdcard/Download"
GH_REPO="ZxAlif-ID/Flavenz-Kernel-Peridot"
PERF_LOG="$PROFILE_DIR/perf_session.log"
PERF_PID_FILE="/data/local/tmp/.flavenz_perf_pid"
DIAG_OUT="/sdcard/Project/Kernel/Profile/flavenz_diag_$(date +%Y%m%d_%H%M%S).txt"
TUNE_LOG="/data/local/tmp/flavenz_perf.log"

# ─── COLORS ───────────────────────────────────
R="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
# fg colors
G="\033[38;2;57;255;20m"       # hijau ok
YL="\033[38;2;255;213;0m"      # kuning warn
RD="\033[38;2;255;77;77m"      # merah bahaya
CY="\033[38;2;34;211;238m"     # cyan aksen
MG="\033[38;2;255;43;214m"     # magenta aksen
DM="\033[38;2;96;108;112m"     # dim neutral
WH="\033[38;2;220;220;220m"    # putih

# ─── UTILS ────────────────────────────────────
nl() { printf "\n"; }
sep() { printf "${DM}──────────────────────────────────────────────${R}\n"; }
ok()  { printf "  ${G}✓${R} $1\n"; }
warn(){ printf "  ${YL}⚠${R} $1\n"; }
err() { printf "  ${RD}✗${R} $1\n"; }
info(){ printf "  ${CY}→${R} $1\n"; }
dim() { printf "  ${DM}$1${R}\n"; }

press_any() { printf "\n${DM}  [ tekan ENTER untuk lanjut ]${R}"; read _dummy; }

# ─── BANNER ───────────────────────────────────
banner() {
  clear
  printf "${MG}${BOLD}"
  printf "  ███████╗██╗      █████╗ ██╗   ██╗███████╗███╗  ███╗\n"
  printf "  ██╔════╝██║     ██╔══██╗██║   ██║██╔════╝████╗████║\n"
  printf "  █████╗  ██║     ███████║██║   ██║█████╗  ██╔████╔██║\n"
  printf "  ██╔══╝  ██║     ██╔══██║╚██╗ ██╔╝██╔══╝  ██║╚██╔╝██║\n"
  printf "  ██║     ███████╗██║  ██║ ╚████╔╝ ███████╗██║ ╚═╝ ██║\n"
  printf "  ╚═╝     ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝     ╚═╝\n"
  printf "${R}"
  printf "  ${DM}KERNEL TOOLS v${VERSION} · SM8635 Peridot · uid=$(id -u)${R}\n"
  sep
}

# ─── DASHBOARD ────────────────────────────────
dashboard() {
  banner
  printf "${CY}${BOLD}  ● DASHBOARD${R}\n"
  sep
  nl

  # Kernel
  KVER=$(uname -r 2>/dev/null || echo "unknown")
  printf "  ${WH}${BOLD}Kernel${R}        ${CY}$KVER${R}\n"

  # KSU
  KSU_VER=$(cat /proc/kernelsu 2>/dev/null | head -1 || echo "N/A")
  KSU_STATUS=""
  if [ -d /data/adb/ksu ] || [ -f /proc/kernelsu ]; then
    KSU_STATUS="${G}ACTIVE${R}"
  else
    KSU_STATUS="${RD}NOT FOUND${R}"
  fi
  printf "  ${WH}${BOLD}KSU-Next${R}      $KSU_STATUS ${DM}($KSU_VER)${R}\n"

  # Module
  if [ -d /data/adb/modules/flavenz_perf ] && \
     [ ! -f /data/adb/modules/flavenz_perf/disable ]; then
    printf "  ${WH}${BOLD}Perf Module${R}   ${G}ENABLED${R}\n"
  elif [ -d /data/adb/modules/flavenz_perf ]; then
    printf "  ${WH}${BOLD}Perf Module${R}   ${YL}DISABLED${R}\n"
  else
    printf "  ${WH}${BOLD}Perf Module${R}   ${RD}NOT INSTALLED${R}\n"
  fi

  nl
  sep
  printf "${CY}${BOLD}  ● CPU${R}\n"
  sep

  # CPU clusters
  for cpu in 0 3 7; do
    FREQ=$(cat /sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_cur_freq 2>/dev/null || echo "N/A")
    MAX=$(cat /sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_max_freq 2>/dev/null || echo "N/A")
    TEMP=""
    case $cpu in
      0) LABEL="${DM}Little A520${R}" ;;
      3) LABEL="${YL}Mid   A720${R}" ;;
      7) LABEL="${RD}Prime X4  ${R}" ;;
    esac
    # freq ke MHz
    FREQ_MHZ=$(( ${FREQ:-0} / 1000 ))
    MAX_MHZ=$(( ${MAX:-0} / 1000 ))
    if [ "$cpu" = "7" ] && [ "$MAX_MHZ" -ge 2900 ] 2>/dev/null; then
      MAX_LABEL="${G}${MAX_MHZ} MHz${R}"
    elif [ "$cpu" = "7" ]; then
      MAX_LABEL="${RD}${MAX_MHZ} MHz ← CAPPED${R}"
    else
      MAX_LABEL="${WH}${MAX_MHZ} MHz${R}"
    fi
    printf "  cpu%-2s ${LABEL}  cur=${CY}%4d MHz${R}  max=%s\n" \
      "$cpu" "$FREQ_MHZ" "$MAX_LABEL"
  done

  nl
  sep
  printf "${CY}${BOLD}  ● MEMORY & THERMAL${R}\n"
  sep

  # RAM
  FREE_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $4}')
  TOTAL_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
  SWAP_USED=$(free -m 2>/dev/null | awk '/^Swap:/{print $3}')
  SWAP_TOTAL=$(free -m 2>/dev/null | awk '/^Swap:/{print $2}')
  SWAPPINESS=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "?")
  ZRAM_ALGO=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null | tr -d '[]' | awk '{print $1}')

  if [ "${FREE_MB:-0}" -gt 500 ] 2>/dev/null; then
    RAM_COLOR="$G"
  elif [ "${FREE_MB:-0}" -gt 200 ] 2>/dev/null; then
    RAM_COLOR="$YL"
  else
    RAM_COLOR="$RD"
  fi

  printf "  ${WH}RAM free${R}      ${RAM_COLOR}${FREE_MB} MB${R} / ${TOTAL_MB} MB\n"
  printf "  ${WH}Swap used${R}     ${CY}${SWAP_USED} MB${R} / ${SWAP_TOTAL} MB\n"
  printf "  ${WH}Swappiness${R}    "
  if [ "${SWAPPINESS:-100}" -le 60 ] 2>/dev/null; then
    printf "${G}${SWAPPINESS}${R}\n"
  else
    printf "${YL}${SWAPPINESS} ← tinggi${R}\n"
  fi
  printf "  ${WH}ZRAM algo${R}     "
  if echo "$ZRAM_ALGO" | grep -q "zstd"; then
    printf "${G}zstd${R}\n"
  else
    printf "${YL}${ZRAM_ALGO} ← bukan zstd${R}\n"
  fi

  # GPU
  GPU_FREQ=$(cat /sys/class/kgsl/kgsl-3d0/devfreq/cur_freq 2>/dev/null || echo "0")
  GPU_MAX=$(cat /sys/class/kgsl/kgsl-3d0/devfreq/max_freq 2>/dev/null || echo "0")
  GPU_MHZ=$(( ${GPU_FREQ:-0} / 1000000 ))
  GPU_MAX_MHZ=$(( ${GPU_MAX:-0} / 1000000 ))
  printf "  ${WH}GPU cur/max${R}   ${CY}${GPU_MHZ} MHz${R} / "
  if [ "$GPU_MAX_MHZ" -ge 1100 ] 2>/dev/null; then
    printf "${G}${GPU_MAX_MHZ} MHz${R}\n"
  else
    printf "${YL}${GPU_MAX_MHZ} MHz ← capped${R}\n"
  fi

  # Thermal
  SCONFIG=$(cat /sys/class/thermal/thermal_message/sconfig 2>/dev/null || echo "?")
  printf "  ${WH}Thermal mode${R}  "
  case "$SCONFIG" in
    3) printf "${G}gaming (sconfig=3)${R}\n" ;;
    0) printf "${YL}normal (sconfig=0)${R}\n" ;;
    -1) printf "${DM}default (sconfig=-1)${R}\n" ;;
    *) printf "${DM}sconfig=${SCONFIG}${R}\n" ;;
  esac

  # uclamp
  UCLAMP=$(cat /dev/cpuctl/top-app/cpu.uclamp.min 2>/dev/null || echo "?")
  LATENCY=$(cat /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive 2>/dev/null || echo "?")
  printf "  ${WH}uclamp top-app${R} "
  if [ "${UCLAMP:-0}" -ge 50 ] && [ "${LATENCY:-0}" = "1" ] 2>/dev/null; then
    printf "${G}min=${UCLAMP} · latency=1${R}\n"
  else
    printf "${YL}min=${UCLAMP} · latency=${LATENCY} ← tidak optimal${R}\n"
  fi

  # Profiling status
  nl
  sep
  printf "${CY}${BOLD}  ● PROFILING${R}\n"
  sep
  if [ -f "$PERF_PID_FILE" ] && kill -0 "$(cat $PERF_PID_FILE)" 2>/dev/null; then
    PPID=$(cat "$PERF_PID_FILE")
    ELAPSED=$(ps -p "$PPID" -o etime= 2>/dev/null | tr -d ' ' || echo "?")
    printf "  ${G}${BOLD}● RECORDING${R}   pid=${PPID}  elapsed=${ELAPSED}\n"
    printf "  ${DM}Output dir: ${PROFILE_DIR}/${R}\n"
  else
    printf "  ${DM}○ Tidak ada sesi profiling aktif${R}\n"
  fi

  nl
  sep
  dim "Profile dir  : $PROFILE_DIR"
  dim "Download dir : $DOWNLOAD_DIR"
  nl
}

# ─── PERF START ───────────────────────────────
perf_start() {
  banner
  printf "${G}${BOLD}  ● START PROFILING${R}\n"
  sep
  nl

  if [ -f "$PERF_PID_FILE" ] && kill -0 "$(cat $PERF_PID_FILE)" 2>/dev/null; then
    warn "Profiling sudah berjalan! pid=$(cat $PERF_PID_FILE)"
    press_any
    return
  fi

  # Cek simpleperf
  SP_PATH=""
  for p in /data/local/tmp/simpleperf /system/bin/simpleperf $(which simpleperf 2>/dev/null); do
    [ -x "$p" ] && SP_PATH="$p" && break
  done

  if [ -z "$SP_PATH" ]; then
    err "simpleperf tidak ditemukan!"
    nl
    info "Install:"
    dim "  cp /apex/com.android.runtime/bin/simpleperf /data/local/tmp/"
    dim "  chmod 755 /data/local/tmp/simpleperf"
    press_any
    return
  fi

  mkdir -p "$PROFILE_DIR"
  SEG_NAME="seg_$(date +%Y%m%d_%H%M%S)"
  OUT_FILE="$PROFILE_DIR/${SEG_NAME}.data"

  printf "  ${WH}simpleperf${R}   ${G}${SP_PATH}${R}\n"
  printf "  ${WH}Output${R}       ${CY}${OUT_FILE}${R}\n"
  printf "  ${WH}Event${R}        cpu-cycles:k (kernel)\n"
  printf "  ${WH}Duration${R}     background (stop manual)\n"
  nl
  printf "  ${YL}Mulai recording? (y/n): ${R}"
  read CONFIRM
  [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ] && return

  "$SP_PATH" record \
    -e cpu-cycles:k \
    -a \
    -g \
    --call-graph dwarf \
    -o "$OUT_FILE" \
    --duration 3600 \
    >> "$PERF_LOG" 2>&1 &

  echo $! > "$PERF_PID_FILE"
  sleep 1

  if kill -0 "$(cat $PERF_PID_FILE)" 2>/dev/null; then
    ok "Profiling started! pid=$(cat $PERF_PID_FILE)"
    ok "File: $OUT_FILE"
    info "Stop via menu → Stop Profiling"
  else
    err "simpleperf gagal start. Cek: cat $PERF_LOG"
    rm -f "$PERF_PID_FILE"
  fi

  press_any
}

# ─── PERF STOP ────────────────────────────────
perf_stop() {
  banner
  printf "${RD}${BOLD}  ● STOP PROFILING${R}\n"
  sep
  nl

  if [ ! -f "$PERF_PID_FILE" ] || ! kill -0 "$(cat $PERF_PID_FILE)" 2>/dev/null; then
    warn "Tidak ada sesi profiling aktif"
    press_any
    return
  fi

  PPID=$(cat "$PERF_PID_FILE")
  printf "  ${WH}PID${R}   ${CY}${PPID}${R}\n"
  nl
  printf "  ${YL}Stop sekarang? (y/n): ${R}"
  read CONFIRM
  [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ] && return

  kill -INT "$PPID" 2>/dev/null
  sleep 2
  kill -9 "$PPID" 2>/dev/null
  rm -f "$PERF_PID_FILE"

  ok "Profiling dihentikan"
  nl

  # List hasil
  printf "  ${WH}${BOLD}Files di $PROFILE_DIR:${R}\n"
  ls -lh "$PROFILE_DIR"/*.data 2>/dev/null | while read line; do
    printf "  ${CY}$line${R}\n"
  done || warn "Belum ada file .data"

  press_any
}

# ─── PERF STATUS ──────────────────────────────
perf_status() {
  banner
  printf "${CY}${BOLD}  ● STATUS PROFILING${R}\n"
  sep
  nl

  if [ -f "$PERF_PID_FILE" ] && kill -0 "$(cat $PERF_PID_FILE)" 2>/dev/null; then
    PPID=$(cat "$PERF_PID_FILE")
    ok "Profiling AKTIF  pid=${PPID}"
    printf "\n  ${WH}Runtime info:${R}\n"
    ps -p "$PPID" -o pid,etime,vsz,rss 2>/dev/null | while read line; do
      printf "  ${DM}$line${R}\n"
    done
  else
    warn "Tidak ada sesi aktif"
  fi

  nl
  printf "  ${WH}${BOLD}Semua profil:${R}\n"
  if ls "$PROFILE_DIR"/*.data 2>/dev/null | head -1 > /dev/null 2>&1; then
    ls -lh "$PROFILE_DIR"/*.data | while read PERM _ USR GRP SZ MON DAY TM FILE; do
      printf "  ${G}●${R} ${CY}$(basename $FILE)${R}  ${WH}${SZ}${R}  ${DM}${MON} ${DAY} ${TM}${R}\n"
    done
  else
    dim "Belum ada profil tersimpan"
  fi

  nl
  sep
  dim "Dir: $PROFILE_DIR"
  press_any
}

# ─── APPLY TUNING ─────────────────────────────
apply_tuning() {
  banner
  printf "${G}${BOLD}  ● APPLY PERFORMANCE TUNING${R}\n"
  sep
  nl
  info "Ini apply semua tuning tanpa reboot (manual run)"
  info "Efek sama dengan service.sh Magisk module"
  nl
  printf "  ${YL}Lanjut? (y/n): ${R}"
  read CONFIRM
  [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ] && return

  nl

  # uclamp
  printf "  ${DM}uclamp top-app...${R}"
  echo 50 > /dev/cpuctl/top-app/cpu.uclamp.min 2>/dev/null && \
  echo 1  > /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive 2>/dev/null && \
  echo 50 > /dev/cpuctl/foreground/cpu.uclamp.min 2>/dev/null && \
  echo 1  > /dev/cpuctl/foreground/cpu.uclamp.latency_sensitive 2>/dev/null && \
    ok "uclamp top-app/foreground min=50 latency=1" || err "uclamp failed"

  # X4 freq
  printf "  ${DM}X4 freq unlock...${R}"
  echo 2918400 > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq 2>/dev/null && \
    ok "X4 max_freq = 2918400 kHz" || err "X4 freq unlock failed"

  # GPU
  printf "  ${DM}GPU unlock...${R}"
  echo 1100000000 > /sys/class/kgsl/kgsl-3d0/devfreq/max_freq 2>/dev/null && \
    ok "GPU max_freq = 1100 MHz" || err "GPU unlock failed"

  # Thermal
  printf "  ${DM}Thermal gaming mode...${R}"
  echo 3 > /sys/class/thermal/thermal_message/sconfig 2>/dev/null && \
    ok "thermal sconfig = 3" || warn "thermal sconfig failed"

  # Swappiness
  printf "  ${DM}Swappiness...${R}"
  echo 60 > /proc/sys/vm/swappiness 2>/dev/null && \
  echo 80 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null && \
    ok "swappiness=60 vfs_cache_pressure=80" || err "swappiness failed"

  # zram
  ALGO=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null || echo "")
  if echo "$ALGO" | grep -q "\[zstd\]"; then
    ok "zram: zstd sudah aktif"
  else
    printf "  ${DM}zram switch ke zstd...${R}"
    swapoff /dev/block/zram0 2>/dev/null; sleep 1
    echo 1           > /sys/block/zram0/reset
    echo zstd        > /sys/block/zram0/comp_algorithm
    echo 12884901888 > /sys/block/zram0/disksize
    mkswap /dev/block/zram0 2>/dev/null
    swapon /dev/block/zram0 -p -2 2>/dev/null && \
      ok "zram → zstd" || warn "zram switch failed"
  fi

  nl
  ok "Semua tuning diapply!"
  press_any
}

# ─── DIAGNOSTICS ──────────────────────────────
run_diag() {
  banner
  printf "${CY}${BOLD}  ● DIAGNOSTIC DUMP${R}\n"
  sep
  nl

  DIAG_OUT="$PROFILE_DIR/flavenz_diag_$(date +%Y%m%d_%H%M%S).txt"
  info "Output: $DIAG_OUT"
  nl

  # Cek script diag
  DIAG_SH=""
  for p in /sdcard/flavenz_diag.sh /data/local/tmp/flavenz_diag.sh \
           /data/data/com.termux/files/home/flavenz_diag.sh; do
    [ -f "$p" ] && DIAG_SH="$p" && break
  done

  if [ -n "$DIAG_SH" ]; then
    info "Pakai: $DIAG_SH"
    printf "  ${YL}Jalankan? (y/n): ${R}"
    read CONFIRM
    [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ] && return
    sh "$DIAG_SH" > "$DIAG_OUT" 2>&1
    ok "Diag selesai → $DIAG_OUT"
  else
    warn "flavenz_diag.sh tidak ditemukan, jalankan diag inline..."
    printf "  ${YL}Lanjut inline diag? (y/n): ${R}"
    read CONFIRM
    [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ] && return

    {
      echo "=== FLAVENZ INLINE DIAG $(date) ==="
      echo "--- KERNEL ---"
      uname -r
      echo "--- CPU ---"
      for c in 0 3 7; do
        echo "cpu$c max=$(cat /sys/devices/system/cpu/cpu${c}/cpufreq/scaling_max_freq 2>/dev/null) cur=$(cat /sys/devices/system/cpu/cpu${c}/cpufreq/scaling_cur_freq 2>/dev/null)"
      done
      echo "--- uclamp ---"
      echo "top-app.min=$(cat /dev/cpuctl/top-app/cpu.uclamp.min 2>/dev/null)"
      echo "latency=$(cat /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive 2>/dev/null)"
      echo "--- GPU ---"
      echo "max=$(cat /sys/class/kgsl/kgsl-3d0/devfreq/max_freq 2>/dev/null)"
      echo "--- THERMAL ---"
      echo "sconfig=$(cat /sys/class/thermal/thermal_message/sconfig 2>/dev/null)"
      echo "--- MEMORY ---"
      free -m
      echo "swappiness=$(cat /proc/sys/vm/swappiness)"
      echo "zram_algo=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null)"
      echo "--- BCL ---"
      find /sys/class/thermal -name "type" -exec grep -l "battery" {} \; 2>/dev/null | \
        head -3 | while read t; do
          DIR=$(dirname "$t")
          echo "$(cat $t 2>/dev/null): cur=$(cat $DIR/cur_state 2>/dev/null) max=$(cat $DIR/max_state 2>/dev/null)"
        done
    } > "$DIAG_OUT" 2>&1
    ok "Inline diag → $DIAG_OUT"
  fi

  nl
  dim "File tersimpan di: $DIAG_OUT"
  press_any
}

# ─── VIEW LOG ─────────────────────────────────
view_log() {
  banner
  printf "${CY}${BOLD}  ● LOGS${R}\n"
  sep
  nl

  printf "  ${WH}${BOLD}[1]${R} Perf module log  ${DM}($TUNE_LOG)${R}\n"
  printf "  ${WH}${BOLD}[2]${R} Profiling log    ${DM}($PERF_LOG)${R}\n"
  printf "  ${WH}${BOLD}[3]${R} Semua profil (ls)${R}\n"
  printf "  ${WH}${BOLD}[0]${R} Kembali\n"
  nl
  printf "  ${CY}Pilih: ${R}"
  read LCHOICE

  case "$LCHOICE" in
    1)
      nl
      if [ -f "$TUNE_LOG" ]; then
        printf "${DM}--- ${TUNE_LOG} ---${R}\n"
        cat "$TUNE_LOG"
      else
        warn "Log belum ada. Module belum pernah jalan?"
      fi
      press_any ;;
    2)
      nl
      if [ -f "$PERF_LOG" ]; then
        printf "${DM}--- ${PERF_LOG} (tail 40) ---${R}\n"
        tail -40 "$PERF_LOG"
      else
        warn "Log profiling kosong"
      fi
      press_any ;;
    3)
      nl
      printf "  ${WH}${BOLD}Profile dir: ${CY}$PROFILE_DIR${R}\n\n"
      ls -lh "$PROFILE_DIR" 2>/dev/null || warn "Dir kosong / belum ada"
      press_any ;;
    0) return ;;
  esac
}

# ─── DYNAMIC DOWNLOAD MANAGER ────────────────
download_file() {
  _url="$1"
  _dest="$2"
  _sha_url="$3"
  _name="$(basename "$_dest")"

  mkdir -p "$(dirname "$_dest")"
  nl
  info "Mengunduh: ${CY}${_name}${R}"
  dim "URL    : ${_url}"
  dim "Tujuan : ${_dest}"
  nl

  if command -v curl >/dev/null 2>&1; then
    curl -# -L -f "$_url" -o "$_dest"
    _rc=$?
  else
    wget -q --show-progress -O "$_dest" "$_url"
    _rc=$?
  fi

  if [ $_rc -eq 0 ] && [ -s "$_dest" ]; then
    _sz=$(ls -lh "$_dest" 2>/dev/null | awk '{print $5}')
    ok "Download selesai: ${G}${_name}${R} (${_sz})"
    info "File tersimpan: ${CY}${_dest}${R}"

    if [ -n "$_sha_url" ]; then
      nl
      info "Verifikasi checksum SHA256..."
      _expected=$(curl -sL "$_sha_url" 2>/dev/null | grep "$_name" | awk '{print $1}')
      if [ -n "$_expected" ]; then
        _actual=$(sha256sum "$_dest" 2>/dev/null | awk '{print $1}')
        if [ "$_expected" = "$_actual" ]; then
          ok "SHA256 Cocok: ${G}${_actual:0:16}...${R} (VERIFIED)"
        else
          warn "SHA256 Mismatch!"
          dim "Expected : ${_expected}"
          dim "Actual   : ${_actual}"
        fi
      else
        dim "File SHA256SUMS tidak memuat nama file ini"
      fi
    fi
  else
    err "Download gagal (${_name})! Periksa koneksi internet."
    rm -f "$_dest" 2>/dev/null
  fi
}

fetch_github_data() {
  printf "  ${CY}↻${R} ${DM}Mengambil data release & module terbaru dari GitHub...${R}\n"

  _cache_rel="/data/local/tmp/.flavenz_rel.json"
  _cache_mod="/data/local/tmp/.flavenz_mod.json"

  curl -sL --max-time 10 -H "User-Agent: FlavenzTools" \
    "https://api.github.com/repos/${GH_REPO}/releases" > "$_cache_rel" 2>/dev/null

  curl -sL --max-time 10 -H "User-Agent: FlavenzTools" \
    "https://api.github.com/repos/${GH_REPO}/contents/modules" > "$_cache_mod" 2>/dev/null

  REL_LIST=$(sed -e 's/[{}]/\n/g' -e 's/,/\n/g' "$_cache_rel" 2>/dev/null | \
  awk '
  BEGIN { tag=""; prerelease=""; zip_url=""; sha_url=""; zip_name="" }
  /"tag_name":/ {
    if (tag != "" && zip_url != "") {
      print tag "|" prerelease "|" zip_name "|" zip_url "|" sha_url
      zip_url = ""; sha_url = ""; zip_name = ""
    }
    s = $0; sub(/.*"tag_name":[ \t]*"/, "", s); sub(/".*/, "", s)
    tag = s
  }
  /"prerelease":/ {
    s = $0; sub(/.*"prerelease":[ \t]*/, "", s); sub(/[,\r\n ].*/, "", s)
    prerelease = s
  }
  /"browser_download_url":/ {
    s = $0; sub(/.*"browser_download_url":[ \t]*"/, "", s); sub(/".*/, "", s)
    if (s ~ /\.zip$/) {
      zip_url = s
      n = split(s, parts, "/")
      zip_name = parts[n]
    } else if (s ~ /SHA256SUMS\.txt$/) {
      sha_url = s
    }
  }
  END {
    if (tag != "" && zip_url != "") {
      print tag "|" prerelease "|" zip_name "|" zip_url "|" sha_url
    }
  }
  ')

  MOD_LIST=$(sed -e 's/[{}]/\n/g' -e 's/,/\n/g' "$_cache_mod" 2>/dev/null | \
  awk '
  /"name":/ {
    s = $0; sub(/.*"name":[ \t]*"/, "", s); sub(/".*/, "", s)
    name = s
  }
  /"download_url":/ {
    s = $0; sub(/.*"download_url":[ \t]*"/, "", s); sub(/".*/, "", s)
    if (name ~ /\.zip$/) {
      print name "|" s
      name = ""
    }
  }
  ')

  AFDO_TAG=""; AFDO_ZIP=""; AFDO_URL=""; AFDO_SHA=""
  STABLE_TAG=""; STABLE_ZIP=""; STABLE_URL=""; STABLE_SHA=""
  MOD_NAME=""; MOD_URL=""

  if [ -n "$REL_LIST" ]; then
    _afdo_entry=$(echo "$REL_LIST" | grep -i "afdo" | head -1)
    if [ -z "$_afdo_entry" ]; then
      _afdo_entry=$(echo "$REL_LIST" | grep "|true|" | head -1)
    fi
    if [ -n "$_afdo_entry" ]; then
      AFDO_TAG=$(echo "$_afdo_entry" | cut -d'|' -f1)
      AFDO_ZIP=$(echo "$_afdo_entry" | cut -d'|' -f3)
      AFDO_URL=$(echo "$_afdo_entry" | cut -d'|' -f4)
      AFDO_SHA=$(echo "$_afdo_entry" | cut -d'|' -f5)
    fi

    _stable_entry=$(echo "$REL_LIST" | grep "|false|" | head -1)
    if [ -n "$_stable_entry" ]; then
      STABLE_TAG=$(echo "$_stable_entry" | cut -d'|' -f1)
      STABLE_ZIP=$(echo "$_stable_entry" | cut -d'|' -f3)
      STABLE_URL=$(echo "$_stable_entry" | cut -d'|' -f4)
      STABLE_SHA=$(echo "$_stable_entry" | cut -d'|' -f5)
    fi
  fi

  if [ -n "$MOD_LIST" ]; then
    MOD_NAME=$(echo "$MOD_LIST" | head -1 | cut -d'|' -f1)
    MOD_URL=$(echo "$MOD_LIST" | head -1 | cut -d'|' -f2)
  fi

  # Fallback jika offline / rate limited
  if [ -z "$AFDO_URL" ]; then
    AFDO_TAG="Flavenz-20261017-afdo"
    AFDO_ZIP="Peridot-Kernel-ACK-AutoFDO-KSUNext-f8ab5e81-SUSFS-v2.3.0-droidspaces-20261017.zip"
    AFDO_URL="https://github.com/${GH_REPO}/releases/download/${AFDO_TAG}/${AFDO_ZIP}"
    AFDO_SHA="https://github.com/${GH_REPO}/releases/download/${AFDO_TAG}/SHA256SUMS.txt"
  fi

  if [ -z "$STABLE_URL" ]; then
    STABLE_TAG="Flavenz-20261016"
    STABLE_ZIP="Peridot-Kernel-ACK-KSUNext-66fe35ec-SUSFS-v2.3.0-droidspaces-20261016.zip"
    STABLE_URL="https://github.com/${GH_REPO}/releases/download/${STABLE_TAG}/${STABLE_ZIP}"
    STABLE_SHA="https://github.com/${GH_REPO}/releases/download/${STABLE_TAG}/SHA256SUMS.txt"
  fi

  if [ -z "$MOD_URL" ]; then
    MOD_NAME="flavenz_perf_v1.0.0.zip"
    MOD_URL="https://raw.githubusercontent.com/${GH_REPO}/main/modules/${MOD_NAME}"
  fi
}

download_manager() {
  mkdir -p "$DOWNLOAD_DIR"
  banner
  printf "${MG}${BOLD}  ● DOWNLOAD MANAGER (DYNAMIC GITHUB)${R}\n"
  sep
  nl
  fetch_github_data

  while true; do
    banner
    printf "${MG}${BOLD}  ● DOWNLOAD MANAGER (DYNAMIC GITHUB)${R}\n"
    sep
    nl
    printf "  ${WH}Folder Tujuan:${R} ${CY}${DOWNLOAD_DIR}/${R}\n"
    nl
    sep
    printf "  ${CY}${BOLD}[1] Latest AutoFDO Kernel${R} ${YL}(Rekomendasi)${R}\n"
    printf "      Tag  : ${G}${AFDO_TAG}${R} ${DM}(Pre-release)${R}\n"
    printf "      File : ${WH}${AFDO_ZIP}${R}\n"
    nl
    printf "  ${CY}${BOLD}[2] Latest Stable Kernel${R}\n"
    printf "      Tag  : ${G}${STABLE_TAG}${R} ${DM}(Stable)${R}\n"
    printf "      File : ${WH}${STABLE_ZIP}${R}\n"
    nl
    printf "  ${CY}${BOLD}[3] Latest Performance Module${R}\n"
    printf "      File : ${WH}${MOD_NAME}${R}\n"
    printf "      Tipe : ${DM}KSU-Next Magisk Module (X4 + uclamp + GPU + zstd)${R}\n"
    nl
    printf "  ${G}${BOLD}[4] Download Keduanya (Latest AutoFDO + Perf Module)${R}\n"
    printf "  ${WH}${BOLD}[5] Pilih dari Daftar Semua Release${R}\n"
    printf "  ${WH}${BOLD}[6] Ganti Folder Download${R} ${DM}(saat ini: ${DOWNLOAD_DIR})${R}\n"
    printf "  ${CY}${BOLD}[7] Refresh Data GitHub${R}\n"
    printf "  ${DM}${BOLD}[0] Kembali ke Menu Utama${R}\n"
    sep
    nl
    printf "  ${CY}Pilih [0-7]: ${R}"
    read DM_CHOICE

    case "$DM_CHOICE" in
      1)
        download_file "$AFDO_URL" "${DOWNLOAD_DIR}/${AFDO_ZIP}" "$AFDO_SHA"
        press_any ;;
      2)
        download_file "$STABLE_URL" "${DOWNLOAD_DIR}/${STABLE_ZIP}" "$STABLE_SHA"
        press_any ;;
      3)
        download_file "$MOD_URL" "${DOWNLOAD_DIR}/${MOD_NAME}" ""
        press_any ;;
      4)
        download_file "$AFDO_URL" "${DOWNLOAD_DIR}/${AFDO_ZIP}" "$AFDO_SHA"
        download_file "$MOD_URL" "${DOWNLOAD_DIR}/${MOD_NAME}" ""
        nl
        ok "Semua file tersimpan di: ${CY}${DOWNLOAD_DIR}/${R}"
        info "Langkah flash & install:"
        dim "  1. Flash ${AFDO_ZIP} via KSU-Next Manager / Recovery (init_boot only)"
        dim "  2. Reboot sistem"
        dim "  3. Install ${MOD_NAME} via KSU-Next Manager (Modules -> Install)"
        press_any ;;
      5)
        banner
        printf "${CY}${BOLD}  ● SEMUA RELEASE FLAVENZ${R}\n"
        sep
        nl
        if [ -z "$REL_LIST" ]; then
          warn "Daftar release kosong atau GitHub API tidak terjangkau"
          press_any
          continue
        fi

        _idx=1
        echo "$REL_LIST" | while IFS='|' read -r _tag _prerelease _zip _url _sha; do
          if [ "$_prerelease" = "true" ]; then
            _type="${YL}[Pre-release]${R}"
          else
            _type="${G}[Stable]${R}"
          fi
          printf "  ${BOLD}[%d]${R} %s %s\n      ${DM}%s${R}\n" "$_idx" "$_type" "$_tag" "$_zip"
          _idx=$((_idx + 1))
        done

        nl
        printf "  ${CY}Pilih nomor release (0 untuk batal): ${R}"
        read SEL_NUM

        if [ "$SEL_NUM" -gt 0 ] 2>/dev/null; then
          _selected_line=$(echo "$REL_LIST" | sed -n "${SEL_NUM}p")
          if [ -n "$_selected_line" ]; then
            _sel_tag=$(echo "$_selected_line" | cut -d'|' -f1)
            _sel_zip=$(echo "$_selected_line" | cut -d'|' -f3)
            _sel_url=$(echo "$_selected_line" | cut -d'|' -f4)
            _sel_sha=$(echo "$_selected_line" | cut -d'|' -f5)
            download_file "$_sel_url" "${DOWNLOAD_DIR}/${_sel_zip}" "$_sel_sha"
          else
            warn "Nomor tidak valid"
          fi
        fi
        press_any ;;
      6)
        banner
        printf "${CY}${BOLD}  ● GANTI FOLDER DOWNLOAD${R}\n"
        sep
        nl
        printf "  Folder sekarang : ${CY}%s${R}\n" "$DOWNLOAD_DIR"
        printf "  ${YL}Masukkan path baru: ${R}"
        read NEW_DIR
        if [ -n "$NEW_DIR" ]; then
          DOWNLOAD_DIR="$NEW_DIR"
          mkdir -p "$DOWNLOAD_DIR"
          ok "Folder download diubah ke: $DOWNLOAD_DIR"
        fi
        press_any ;;
      7)
        fetch_github_data
        ok "Data GitHub diperbarui!"
        sleep 1 ;;
      0)
        return ;;
      *)
        warn "Pilihan tidak valid"
        sleep 1 ;;
    esac
  done
}

# ─── MAIN MENU ────────────────────────────────
main_menu() {
  while true; do
    banner
    printf "${WH}${BOLD}  MENU UTAMA${R}\n"
    sep
    nl
    printf "  ${G}${BOLD}[1]${R}  Dashboard & Info\n"
    printf "  ${G}${BOLD}[2]${R}  ${G}Start${R} Profiling AutoFDO\n"
    printf "  ${RD}${BOLD}[3]${R}  ${RD}Stop${R}  Profiling\n"
    printf "  ${CY}${BOLD}[4]${R}  Status Profiling & File\n"
    printf "  ${YL}${BOLD}[5]${R}  Apply Performance Tuning (manual)\n"
    printf "  ${MG}${BOLD}[6]${R}  Diagnostic Dump → /sdcard/\n"
    printf "  ${CY}${BOLD}[7]${R}  Lihat Logs\n"
    printf "  ${WH}${BOLD}[8]${R}  Download Kernel & Module ${G}(Dynamic GitHub)${R}\n"
    nl
    printf "  ${DM}${BOLD}[0]${R}  ${DM}Exit${R}\n"
    nl
    sep
    # Status profiling di footer
    if [ -f "$PERF_PID_FILE" ] && kill -0 "$(cat $PERF_PID_FILE)" 2>/dev/null; then
      printf "  ${G}● PROFILING AKTIF${R}  pid=$(cat $PERF_PID_FILE)\n"
    else
      printf "  ${DM}○ Profiling tidak aktif${R}\n"
    fi
    nl
    printf "  ${CY}Pilih [0-8]: ${R}"
    read CHOICE

    case "$CHOICE" in
      1) dashboard; press_any ;;
      2) perf_start ;;
      3) perf_stop ;;
      4) perf_status ;;
      5) apply_tuning ;;
      6) run_diag ;;
      7) view_log ;;
      8) download_manager ;;
      0)
        clear
        printf "${MG}${BOLD}  Flavenz Tools — bye!${R}\n\n"
        exit 0 ;;
      *)
        warn "Pilihan tidak valid"
        sleep 1 ;;
    esac
  done
}

# ─── ENTRY ────────────────────────────────────
mkdir -p "$PROFILE_DIR" "$DOWNLOAD_DIR"
main_menu
