#!/system/bin/sh
# flavenz_diag.sh — Flavenz Kernel Full Diagnostic
# Run: su -c "sh /sdcard/flavenz_diag.sh | tee /sdcard/flavenz_diag.txt"

OUT=/sdcard/flavenz_diag.txt
exec > "$OUT" 2>&1

echo "=========================================="
echo " FLAVENZ KERNEL DIAGNOSTIC DUMP"
echo " $(date)"
echo "=========================================="

echo ""
echo "=== [1] KERNEL VERSION ==="
uname -r
cat /proc/version

echo ""
echo "=== [2] CPU INFO ==="
cat /proc/cpuinfo | grep -E "^processor|^Hardware|^CPU part|^CPU variant|^CPU architecture"

echo ""
echo "=== [3] CPU TOPOLOGY + FREQ ==="
for cpu in /sys/devices/system/cpu/cpu[0-9]; do
  n=$(basename $cpu)
  online=$(cat $cpu/online 2>/dev/null || echo "1")
  gov=$(cat $cpu/cpufreq/scaling_governor 2>/dev/null || echo "N/A")
  cur=$(cat $cpu/cpufreq/scaling_cur_freq 2>/dev/null || echo "N/A")
  min=$(cat $cpu/cpufreq/scaling_min_freq 2>/dev/null || echo "N/A")
  max=$(cat $cpu/cpufreq/scaling_max_freq 2>/dev/null || echo "N/A")
  cap=$(cat $cpu/cpu_capacity 2>/dev/null || echo "N/A")
  cluster=$(cat $cpu/topology/cluster_id 2>/dev/null || cat $cpu/topology/physical_package_id 2>/dev/null || echo "N/A")
  echo "$n | online=$online | cluster=$cluster | cap=$cap | gov=$gov | cur=${cur}kHz | min=${min}kHz | max=${max}kHz"
done

echo ""
echo "=== [4] AVAILABLE GOVERNORS ==="
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null || echo "N/A"

echo ""
echo "=== [5] SCHEDUTIL TUNABLES ==="
for policy in /sys/devices/system/cpu/cpufreq/policy*/; do
  echo "-- $(basename $policy) --"
  for t in scaling_governor scaling_cur_freq scaling_max_freq \
            schedutil/rate_limit_us schedutil/up_rate_limit_us \
            schedutil/down_rate_limit_us schedutil/hispeed_freq \
            schedutil/hispeed_load schedutil/pl \
            schedutil/iowait_boost_enable; do
    f="$policy$t"
    [ -f "$f" ] && echo "  $(basename $t) = $(cat $f)" || true
  done
done

echo ""
echo "=== [6] WALT SCHEDULER TUNABLES ==="
for f in \
  /proc/sys/kernel/sched_walt_init_task_load_pct \
  /proc/sys/kernel/sched_boost \
  /proc/sys/kernel/sched_upmigrate \
  /proc/sys/kernel/sched_downmigrate \
  /proc/sys/kernel/sched_upmigrate_min_nice \
  /proc/sys/kernel/sched_task_unfilter_period \
  /proc/sys/kernel/sched_busy_hyst_ns \
  /proc/sys/kernel/sched_coloc_busy_hyst_ns \
  /proc/sys/kernel/sched_many_wakeup_threshold \
  /proc/sys/kernel/sched_min_task_util_for_colocation \
  /proc/sys/kernel/sched_conservative_pl \
  /proc/sys/kernel/sched_ravg_hist_size \
  /proc/sys/kernel/sched_window_stats_policy \
  /proc/sys/kernel/sched_predl \
  /proc/sys/kernel/sched_predl_window_size \
  /proc/sys/kernel/sched_account_wait_time \
  /proc/sys/kernel/sched_freq_aggregate \
  /proc/sys/kernel/sched_freq_aggregate_threshold_pct; do
  val=$(cat "$f" 2>/dev/null)
  [ -n "$val" ] && echo "$(basename $f) = $val" || echo "$(basename $f) = MISSING"
done

echo ""
echo "=== [7] UCLAMP ==="
for f in \
  /proc/sys/kernel/sched_util_clamp_min \
  /proc/sys/kernel/sched_util_clamp_max \
  /dev/cpuctl/top-app/cpu.uclamp.min \
  /dev/cpuctl/top-app/cpu.uclamp.max \
  /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive \
  /dev/cpuctl/foreground/cpu.uclamp.min \
  /dev/cpuctl/foreground/cpu.uclamp.max \
  /dev/cpuctl/background/cpu.uclamp.min \
  /dev/cpuctl/background/cpu.uclamp.max \
  /dev/cpuctl/system-background/cpu.uclamp.max; do
  val=$(cat "$f" 2>/dev/null)
  [ -n "$val" ] && echo "$(dirname $f | xargs basename)/$(basename $f) = $val" || echo "$(basename $f) = MISSING"
done

echo ""
echo "=== [8] CGROUP CPU SHARES ==="
for cg in top-app foreground background system system-background; do
  base=/dev/cpuctl/$cg
  [ -d "$base" ] || continue
  shares=$(cat $base/cpu.shares 2>/dev/null || echo "N/A")
  uclamp_min=$(cat $base/cpu.uclamp.min 2>/dev/null || echo "N/A")
  latency=$(cat $base/cpu.uclamp.latency_sensitive 2>/dev/null || echo "N/A")
  echo "$cg | shares=$shares | uclamp.min=$uclamp_min | latency_sensitive=$latency"
done

echo ""
echo "=== [9] THERMAL ZONES ==="
for z in /sys/class/thermal/thermal_zone*/; do
  type=$(cat $z/type 2>/dev/null || echo "?")
  temp=$(cat $z/temp 2>/dev/null || echo "?")
  mode=$(cat $z/mode 2>/dev/null || echo "?")
  policy=$(cat $z/policy 2>/dev/null || echo "?")
  echo "$type | ${temp}mC | mode=$mode | policy=$policy"
done

echo ""
echo "=== [10] THERMAL COOLING DEVICES ==="
for c in /sys/class/thermal/cooling_device*/; do
  type=$(cat $c/type 2>/dev/null || echo "?")
  cur=$(cat $c/cur_state 2>/dev/null || echo "?")
  max=$(cat $c/max_state 2>/dev/null || echo "?")
  echo "$type | cur=$cur | max=$max"
done | sort | uniq | head -30

echo ""
echo "=== [11] THERMAL MESSAGE (XIAOMI) ==="
cat /sys/class/thermal/thermal_message/sconfig 2>/dev/null || echo "sconfig: N/A"
cat /sys/class/thermal/thermal_message/board_sensor_temp 2>/dev/null || echo "board_sensor_temp: N/A"
cat /sys/class/thermal/thermal_message/cpu_limits 2>/dev/null || echo "cpu_limits: N/A"
ls /sys/class/thermal/thermal_message/ 2>/dev/null

echo ""
echo "=== [12] LMh / DCVS ==="
for f in $(find /sys/devices/platform/soc/ -name "lmh_freq_limit" 2>/dev/null); do
  echo "$(dirname $f | xargs basename): $(cat $f)"
done
ls /sys/bus/platform/drivers/qcom-lmh/ 2>/dev/null || echo "qcom-lmh: N/A"
cat /sys/devices/platform/soc/17d50000.qcom,lmh-lite-driver/lmh_freq_limit 2>/dev/null || true

echo ""
echo "=== [13] GPU ==="
GPU=/sys/class/kgsl/kgsl-3d0
echo "model       = $(cat $GPU/gpu_model 2>/dev/null || echo N/A)"
echo "cur_freq    = $(cat $GPU/devfreq/cur_freq 2>/dev/null || cat $GPU/gpuclk 2>/dev/null || echo N/A)"
echo "max_freq    = $(cat $GPU/gpu_max_clock 2>/dev/null || cat $GPU/devfreq/max_freq 2>/dev/null || echo N/A)"
echo "min_freq    = $(cat $GPU/gpu_min_clock 2>/dev/null || cat $GPU/devfreq/min_freq 2>/dev/null || echo N/A)"
echo "governor    = $(cat $GPU/devfreq/governor 2>/dev/null || echo N/A)"
echo "busy_pct    = $(cat $GPU/gpu_busy_percentage 2>/dev/null || echo N/A)"
echo "power_level = $(cat $GPU/power_level 2>/dev/null || echo N/A)"
echo "throttling  = $(cat $GPU/throttling 2>/dev/null || echo N/A)"
echo "available_freqs = $(cat $GPU/devfreq/available_frequencies 2>/dev/null || echo N/A)"
echo "available_governors = $(cat $GPU/devfreq/available_governors 2>/dev/null || echo N/A)"
echo ""
echo "-- GPU DCVS msm-adreno-tz --"
for f in /sys/class/kgsl/kgsl-3d0/dispatch_queue_length \
         /sys/class/kgsl/kgsl-3d0/popp \
         /sys/module/adreno_idler/parameters/adreno_idler_active \
         /sys/module/msm_adreno_tz/parameters/adrenoboost; do
  [ -f "$f" ] && echo "$(basename $f) = $(cat $f)"
done

echo ""
echo "=== [14] MEMORY ==="
free -m
echo ""
echo "vm.swappiness           = $(cat /proc/sys/vm/swappiness)"
echo "vm.vfs_cache_pressure   = $(cat /proc/sys/vm/vfs_cache_pressure)"
echo "vm.dirty_ratio          = $(cat /proc/sys/vm/dirty_ratio)"
echo "vm.dirty_background_ratio = $(cat /proc/sys/vm/dirty_background_ratio)"
echo "vm.extra_free_kbytes    = $(cat /proc/sys/vm/extra_free_kbytes 2>/dev/null || echo N/A)"
echo "vm.page-cluster         = $(cat /proc/sys/vm/page-cluster 2>/dev/null || echo N/A)"
echo ""
echo "-- ZRAM --"
echo "disksize   = $(cat /sys/block/zram0/disksize 2>/dev/null | awk '{printf "%.0f MB", $1/1048576}')"
echo "algorithm  = $(cat /sys/block/zram0/comp_algorithm 2>/dev/null)"
echo "mem_used   = $(cat /sys/block/zram0/mem_used_total 2>/dev/null | awk '{printf "%.0f MB", $1/1048576}')"
swapon --show 2>/dev/null || cat /proc/swaps

echo ""
echo "=== [15] I/O SCHEDULER ==="
for disk in $(ls /sys/block/ | grep -E "^(sd|mmcblk|sda|nvme)"); do
  sched=$(cat /sys/block/$disk/queue/scheduler 2>/dev/null || echo "N/A")
  rq=$(cat /sys/block/$disk/queue/nr_requests 2>/dev/null || echo "N/A")
  ra=$(cat /sys/block/$disk/queue/read_ahead_kb 2>/dev/null || echo "N/A")
  echo "$disk | scheduler=$sched | nr_requests=$rq | read_ahead_kb=$ra"
done

echo ""
echo "=== [16] TOP WAKELOCK HOLDERS ==="
cat /sys/kernel/debug/wakeup_sources 2>/dev/null | \
  awk 'NR==1 || NR>1' | sort -k3 -rn | head -20 || \
  echo "wakeup_sources: N/A (coba mount debugfs dulu)"

echo ""
echo "=== [17] CPU FREQ OPP TABLE ==="
for policy in /sys/devices/system/cpu/cpufreq/policy0 \
              /sys/devices/system/cpu/cpufreq/policy4 \
              /sys/devices/system/cpu/cpufreq/policy7; do
  [ -d "$policy" ] || continue
  echo "-- $(basename $policy) --"
  cat $policy/scaling_available_frequencies 2>/dev/null | tr ' ' '\n' | \
    awk '{printf "%d MHz\n", $1/1000}'
done

echo ""
echo "=== [18] RUNNING PROCESSES (TOP 15 CPU) ==="
top -b -n 1 2>/dev/null | head -30 || \
  ps -A --sort=-%cpu 2>/dev/null | head -20 || \
  ps | head -20

echo ""
echo "=== [19] ACTIVE WAKELOCKS (POWER STAT) ==="
cat /sys/power/wake_lock 2>/dev/null || echo "wake_lock: N/A"
dumpsys power 2>/dev/null | grep -E "Wake Locks:|PARTIAL_WAKE_LOCK|mWakefulness|Display Power" | head -20 || true

echo ""
echo "=== [20] KERNEL CMDLINE ==="
cat /proc/cmdline

echo ""
echo "=== [21] SYSCTL RELEVANT ==="
sysctl kernel.sched_child_runs_first 2>/dev/null || true
sysctl kernel.sched_autogroup_enabled 2>/dev/null || true
sysctl kernel.perf_cpu_time_max_percent 2>/dev/null || true
sysctl net.ipv4.tcp_congestion_control 2>/dev/null || true

echo ""
echo "=========================================="
echo " DONE — output saved to /sdcard/flavenz_diag.txt"
echo "=========================================="
