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
VERSION="1.0.0"
PROFILE_DIR="/sdcard/Project/Kernel/Profile"
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
  dim "Profile dir: $PROFILE_DIR"
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

# ─── INSTALL MODULE ───────────────────────────
install_module() {
  banner
  printf "${MG}${BOLD}  ● DOWNLOAD & INFO MODULE${R}\n"
  sep
  nl

  info "flavenz_perf_v1.0.0.zip — KSU-Next Magisk module"
  nl
  printf "  ${WH}Download ke /sdcard/:${R}\n"
  printf "  ${CY}curl -fsSL https://github.com/ZxAlif-ID/Flavenz-Kernel-Peridot/raw/main/modules/flavenz_perf_v1.0.0.zip -o /sdcard/flavenz_perf_v1.0.0.zip${R}\n"
  nl
  printf "  ${WH}Kernel AutoFDO (latest):${R}\n"
  printf "  ${CY}curl -fsSL https://github.com/ZxAlif-ID/Flavenz-Kernel-Peridot/releases/download/Flavenz-20261017-afdo/Peridot-Kernel-ACK-AutoFDO-KSUNext-66fe35ec-SUSFS-v2.3.0-droidspaces-20261017.zip -o /sdcard/Flavenz-afdo.zip${R}\n"
  nl

  printf "  ${YL}Download module sekarang? (y/n): ${R}"
  read CONFIRM
  if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
    if command -v curl > /dev/null 2>&1; then
      curl -fsSL \
        "https://github.com/ZxAlif-ID/Flavenz-Kernel-Peridot/raw/main/modules/flavenz_perf_v1.0.0.zip" \
        -o /sdcard/flavenz_perf_v1.0.0.zip && \
        ok "Downloaded → /sdcard/flavenz_perf_v1.0.0.zip" || \
        err "Download failed — cek koneksi"
    else
      err "curl tidak ada. Pakai wget:"
      dim "  wget -O /sdcard/flavenz_perf_v1.0.0.zip <url_diatas>"
    fi
  fi

  press_any
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
    printf "  ${WH}${BOLD}[8]${R}  Download Module / Kernel Info\n"
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
      8) install_module ;;
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
mkdir -p "$PROFILE_DIR"
main_menu
