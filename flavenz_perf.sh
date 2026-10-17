#!/system/bin/sh
# flavenz_perf.sh — Flavenz Performance Tuning Module
# Install: /data/adb/service.d/flavenz_perf.sh (chmod 755)
# Auto-run: tiap boot via Magisk service.d
# Log: /data/local/tmp/flavenz_perf.log
# Remove: rm file + reboot (fully reversible)

LOG=/data/local/tmp/flavenz_perf.log
TS=$(date "+%Y-%m-%d %H:%M:%S")

log() { echo "[$TS] $1" >> "$LOG"; }

log "flavenz_perf: starting..."

# Tunggu Android fully booted (Magisk service.d jalan early)
sleep 30

# === [1] uclamp — hint prime core untuk foreground tasks ===
# top-app: latency_sensitive=1 → task langsung migrate ke X4 (cap=1024)
# uclamp.min=50 → floor utilization hint, scheduler utamakan prime/mid core
echo 50   > /dev/cpuctl/top-app/cpu.uclamp.min          2>/dev/null && log "uclamp top-app min=50 OK" || log "WARN: uclamp top-app min failed"
echo 1    > /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive  2>/dev/null && log "uclamp top-app latency=1 OK" || log "WARN: uclamp top-app latency failed"
echo 50   > /dev/cpuctl/foreground/cpu.uclamp.min        2>/dev/null && log "uclamp fg min=50 OK" || log "WARN: uclamp fg min failed"
echo 1    > /dev/cpuctl/foreground/cpu.uclamp.latency_sensitive 2>/dev/null || true
# background: tetap rendah — hemat baterai
echo 0    > /dev/cpuctl/background/cpu.uclamp.min        2>/dev/null || true
echo 0    > /dev/cpuctl/background/cpu.uclamp.latency_sensitive 2>/dev/null || true

# === [2] Unlock X4 Prime Core ke OPP max ===
# Stock/port cap: 1324800 kHz
# OPP max: 2918400 kHz (verified dari OPP table flavenz_diag.txt)
echo 2918400 > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq 2>/dev/null \
  && log "X4 max freq = 2918400 kHz OK" \
  || log "WARN: X4 freq unlock failed"

# Juga pastikan min tidak terlalu rendah (633 MHz sudah OK, tidak perlu ubah)

# === [3] GPU unlock ke 1100 MHz ===
# Stock: 900 MHz, Available: 1100 MHz (confirmed dari flavenz_diag)
echo 1100000000 > /sys/class/kgsl/kgsl-3d0/devfreq/max_freq 2>/dev/null \
  && log "GPU max_freq = 1100 MHz OK" \
  || log "WARN: GPU freq unlock failed"

# === [4] Thermal — gaming/performance mode ===
# sconfig=-1: normal (default)
# sconfig=3:  gaming mode (relax thermal trip points)
# NOTE: jika device terasa panas berlebih, comment baris ini
echo 3 > /sys/class/thermal/thermal_message/sconfig 2>/dev/null \
  && log "thermal sconfig=3 (gaming mode) OK" \
  || log "WARN: thermal sconfig failed (mungkin perlu Xiaomi thermal HAL)"

# === [5] Memory tuning — kurangi kswapd pressure ===
# Default swappiness=100 terlalu agresif, bikin latency spike
echo 60  > /proc/sys/vm/swappiness           2>/dev/null && log "swappiness=60 OK" || true
echo 80  > /proc/sys/vm/vfs_cache_pressure   2>/dev/null && log "vfs_cache_pressure=80 OK" || true
echo 4   > /proc/sys/vm/page-cluster         2>/dev/null || true

# === [6] zram — switch ke zstd (lebih cepat decompress dari lzo-rle) ===
ALGO=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null || echo "")
if echo "$ALGO" | grep -q "zstd"; then
    log "zram: zstd sudah aktif, skip"
elif echo "$ALGO" | grep -q "lzo"; then
    log "zram: switching lzo-rle → zstd..."
    swapoff /dev/block/zram0 2>/dev/null || true
    sleep 1
    echo 1             > /sys/block/zram0/reset
    echo zstd          > /sys/block/zram0/comp_algorithm
    echo 12884901888   > /sys/block/zram0/disksize     # 12 GB
    mkswap /dev/block/zram0
    swapon /dev/block/zram0 -p -2
    log "zram: zstd switch done"
else
    log "zram: algo=$ALGO, skip (tidak dikenal)"
fi

# === [7] I/O — tuning minor ===
for disk in /sys/block/sd*; do
    [ -d "$disk" ] || continue
    # read_ahead: tetap 512KB (sudah OK untuk UFS 4.0)
    # nr_requests: bisa naik sedikit untuk throughput
    echo 256 > "$disk/queue/nr_requests" 2>/dev/null || true
done

# === DONE ===
log "flavenz_perf: all tuning applied"
log "--- STATE AFTER TUNING ---"
log "X4 max_freq: $(cat /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq 2>/dev/null)"
log "GPU max_freq: $(cat /sys/class/kgsl/kgsl-3d0/devfreq/max_freq 2>/dev/null)"
log "top-app uclamp.min: $(cat /dev/cpuctl/top-app/cpu.uclamp.min 2>/dev/null)"
log "top-app latency_sensitive: $(cat /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive 2>/dev/null)"
log "swappiness: $(cat /proc/sys/vm/swappiness)"
log "zram algo: $(cat /sys/block/zram0/comp_algorithm 2>/dev/null)"
log "thermal sconfig: $(cat /sys/class/thermal/thermal_message/sconfig 2>/dev/null)"
log "---"
