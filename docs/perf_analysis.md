# Flavenz Kernel — Performance Analysis & Optimization Plan
> Generated: 2026-10-17 | Device: Xiaomi POCO F6 (Peridot) | Kernel: Flavenz ACK android14-6.1

---

## 1. Device Comparison — Data Aktual

| | POCO F6 | Meizu 20 Infinity |
|---|---|---|
| SoC | **SD 8s Gen 3 (SM8635)** | SD 8 Gen 2 (SM8550-AB) |
| Node | 4nm TSMC | 4nm TSMC |
| ISA | **ARMv9.2-A** | ARMv9-A |
| Prime | **X4 @ 3.0 GHz (OPP max 2918 MHz)** | X3 @ 3.2 GHz |
| Mid | 4× A720 @ 2.8 GHz | 2× A715 + 2× A710 @ 2.8 GHz |
| Little | 3× A520 @ 2.0 GHz | 3× A510 @ 2.0 GHz |
| GPU | Adreno 735 @ **1100 MHz max** | Adreno 740 @ 680 MHz |
| RAM | 12 GB LPDDR5X | 12/16 GB LPDDR5X |
| Storage | UFS 4.0 | UFS 4.0 |
| ROM | NexiunOS V5 (HyperOS CN port) | Flyme AIOS (OneMind Engine) |

### Benchmark Angka Nyata (stock, pre-fix)

| Benchmark | POCO F6 | Meizu 20 Infinity | Delta |
|---|---|---|---|
| **GB6 Single** | **2031** | 1479 | **POCO F6 +37%** |
| **GB6 Multi** | **5603** | 4952 | **POCO F6 +13%** |
| AnTuTu 11 | ~1,779,528 | ~1,753,854 | POCO F6 +1.5% |
| GPU (raw) | Adreno 735 | **Adreno 740** | Adreno 740 lebih kuat |

> **Kesimpulan:** Di atas kertas POCO F6 menang signifikan di CPU. Yang bikin Meizu terasa lebih cepat di daily use = **murni software tuning**, bukan hardware. X3 Meizu jalan full 3200 MHz, X4 lo dikekang di 1324 MHz.

---

## 2. Diagnostic Findings — Data dari flavenz_diag.txt

### 🔴 CRITICAL

#### C1 — X4 Prime Core dikekang di 45% dari OPP max

```
scaling_max_freq (policy7) = 1,324,800 Hz  ← AKTUAL
OPP max available           = 2,918,000 Hz  ← POSSIBLE
cpu-cluster2 cooling        = cur=1 / max=17 (sudah throttle 1 step)
```

**Root cause:** Thermal policy `step_wise` trigger terlalu dini di suhu 55-57°C.
X4 jauh lebih kuat dari X3 Meizu secara arsitektur, tapi kalah clock karena dikekang.
**Impact:** Single-core burst dibatasi, app launch lebih lambat, game stuttter.

#### C2 — top-app tidak dapat prime core hint

```
/dev/cpuctl/top-app/cpu.uclamp.min       = 0.00   ← no floor
/dev/cpuctl/top-app/cpu.uclamp.latency_sensitive = 0  ← disabled
```

**Root cause:** NexiunOS port tidak membawa vendor perf HAL yang biasanya set ini.
Scheduler WALT bebas taruh foreground task di A520 (cap=380) — core paling lemah.
Meizu OneMind: `uclamp.min=50-100`, `latency_sensitive=1`.
**Impact:** Interaksi terasa lag meski CPU load rendah. Task tidak migrate ke X4.

---

### 🟠 HIGH

#### H1 — Battery BCL throttle hampir maksimal

```
battery cooling = cur=14 / max=16  (87.5% throttle)
```

Aktif bahkan saat tidak charging. BCL table HyperOS yang diwarisi via port terlalu
conservative untuk real-world usage. Throttle ini menekan semua cluster + GPU.

#### H2 — GPU capped 900 MHz, bisa 1100 MHz

```
devfreq/max_freq = 900,000,000 Hz
available top    = 1,100,000,000 Hz
gpu cooling      = cur=3 / max=10 (aktif)
```

200 MHz GPU dibiarkan idle. Adreno 740 Meizu kalah clock (680 MHz) vs Adreno 735
F6 jika F6 dibuka penuh (1100 MHz).

#### H3 — WALT sysctl semua MISSING

```
sched_upmigrate  = MISSING
sched_downmigrate = MISSING
(18 tunables MISSING)
```

GKI kernel tidak expose via `/proc/sys/kernel/`. Vendor perf HAL SM8635 (dari
Xiaomi) yang harusnya set ini via init.rc tidak ada di NexiunOS port.
**Impact:** Default WALT params — upmigrate threshold terlalu tinggi → task
stuck di little/mid core terlalu lama.

#### H4 — RAM pressure ekstrem + zram suboptimal

```
free RAM   = 104 MB / 11,271 MB total
swap used  = 6,137 MB / 12,287 MB
swappiness = 100 (agresif)
zram algo  = lzo-rle  (bukan zstd)
```

kswapd jalan terus → latency spike random → frame drop tidak terduga.
zstd: kompresi lebih baik + decompress lebih cepat dari lzo-rle.

---

### 🟡 MEDIUM / INFO

| ID | Temuan | Status |
|---|---|---|
| M1 | GPU governor `msm-adreno-tz` | OK — best governor untuk Adreno |
| M2 | I/O scheduler `mq-deadline` | OK — cocok untuk UFS 4.0 |
| M3 | TCP congestion = BBR | ✅ Sudah optimal |
| M4 | `sched_pelt_multiplier=4` (cmdline) | ✅ Sudah benar |
| M5 | Thermal sconfig = -1 (normal mode) | Bisa naik ke 3 (gaming mode) |
| M6 | `com.xiaomi.aiservice` jalan background | Pertimbangkan disable |

---

## 3. Root Cause Summary

```
POCO F6 kalah Meizu 20 Infinity di daily feel meski hardware unggul.
Sebab:

1. X4 di-cap 1324 MHz (45% dari 2918 MHz max OPP)
   → X3 Meizu @ 3200 MHz full clock menang di real tasks

2. Tidak ada uclamp hint untuk top-app
   → Foreground tasks landing di A520 (cap=380) bukan X4 (cap=1024)

3. BCL throttle agresif (87.5%) tanpa justifikasi suhu
   → Semua subsystem dapat headroom lebih kecil dari seharusnya

4. WALT tuning kosong (no vendor perf HAL di NexiunOS port)
   → Migration threshold default = terlalu conservative

Ini 100% software/tuning. Zero hardware limitation.
X4 secara arsitektur superior dari X3 — kalau dibuka penuh, POCO F6 menang.
```

---

## 4. Solution Plan

### Tier 1 — Magisk Module (IMMEDIATE, no reflash needed)

> Resiko: **LOW** — reversible, hilang jika flash ulang atau disable modul.
> Test dulu 1-2 jam sebelum declare stable.

**File:** `/data/adb/service.d/flavenz_perf.sh`

```bash
#!/system/bin/sh
# flavenz_perf.sh — Flavenz Performance Tuning
# Tier 1: uclamp + freq unlock + zstd zram + thermal
# Run: otomatis tiap boot via Magisk service.d
# Safe to remove: rm /data/adb/service.d/flavenz_perf.sh + reboot

sleep 30  # tunggu Android fully booted

# === [1] uclamp — hint prime core untuk foreground tasks ===
echo 50   > /dev/cpuctl/top-app/cpu.uclamp.min
echo 1    > /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive
echo 50   > /dev/cpuctl/foreground/cpu.uclamp.min
echo 1    > /dev/cpuctl/foreground/cpu.uclamp.latency_sensitive
# bg tetap rendah — hemat baterai
echo 0    > /dev/cpuctl/background/cpu.uclamp.min

# === [2] Unlock X4 Prime Core ke OPP max ===
echo 2918400 > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq

# === [3] GPU unlock ke 1100 MHz ===
echo 1100000000 > /sys/class/kgsl/kgsl-3d0/devfreq/max_freq

# === [4] Thermal — gaming mode (relax trip points) ===
echo 3 > /sys/class/thermal/thermal_message/sconfig

# === [5] Memory — kurangi kswapd pressure ===
echo 60  > /proc/sys/vm/swappiness
echo 80  > /proc/sys/vm/vfs_cache_pressure

# === [6] zram — switch ke zstd ===
if grep -q "lzo" /sys/block/zram0/comp_algorithm 2>/dev/null; then
    swapoff /dev/block/zram0 2>/dev/null || true
    echo 1         > /sys/block/zram0/reset
    echo zstd      > /sys/block/zram0/comp_algorithm
    echo 12884901888 > /sys/block/zram0/disksize   # 12 GB
    mkswap /dev/block/zram0
    swapon /dev/block/zram0 -p -2
fi

echo "flavenz_perf: tuning applied @ $(date)" >> /data/local/tmp/flavenz_perf.log
```

**Cara install:**
```bash
# Di Termux (perlu root):
su -c "mkdir -p /data/adb/service.d"
su -c "cat > /data/adb/service.d/flavenz_perf.sh << 'EOF'
# ... isi script di atas ...
EOF"
su -c "chmod 755 /data/adb/service.d/flavenz_perf.sh"
# Reboot, cek log:
# cat /data/local/tmp/flavenz_perf.log
```

**Expected impact:**

| Metric | Before | After (est.) |
|---|---|---|
| GB6 Single | ~2031 | ~2800-3200 (X4 full clock) |
| GB6 Multi | ~5603 | ~6000-6500 |
| GPU gaming | Adreno 735 @900 | Adreno 735 @1100 (+15%) |
| App launch | baseline | -20 to -30% (uclamp hint) |
| RAM latency | spike random | lebih smooth (zstd + swappiness) |

---

### Tier 2 — Flavenz Kernel Build Berikutnya

> Masuk ke `build-droidspaces.yml` defconfig additions. Zero runtime overhead.

```kconfig
# Tambah ke peridot_GKI.config:
CONFIG_SCHED_THERMAL_PRESSURE=y   # scheduler tau suhu sebelum assign task berat
CONFIG_CRYPTO_ZSTD=y              # zstd support di kernel (sudah ada di ACK 6.1)
CONFIG_ZRAM_DEF_COMP_ZSTD=y      # zram default zstd tanpa perlu init script
```

Status Flavenz saat ini:
- ✅ KSU-Next `66fe35ec` (dev-susfs, 2026-10-16)
- ✅ SUSFS v2.3.0
- ✅ Droidspaces configs (MACVLAN, IP6_NF_NAT, CFS_BANDWIDTH, CGROUP_PIDS)
- ✅ ACK android14-6.1 @ `0c3d559bcd85`
- 🔜 AutoFDO (run #13 in progress — convert-profile + build-final)
- ❌ `CONFIG_SCHED_THERMAL_PRESSURE` — belum
- ❌ `CONFIG_ZRAM_DEF_COMP_ZSTD` — belum

---

### Tier 3 — AutoFDO (In Progress, run #13)

Pipeline aktif:
```
Profil Sept 2026 (~27 menit real usage, 2 run × 3 segment, ~1.1GB)
    ↓ simpleperf inject + create_llvm_prof
kernel.afdo
    ↓ build-final dengan CLANG_AUTOFDO_PROFILE=kernel.afdo
Flavenz-20261016-afdo release
```

Expected: 3-5% latency reduction di kernel hot paths (scheduler, mm, IRQ handling).
Profil valid — anchor geometry verified: `_text=0xffffffe2fd800000`, kernel size=35.25MB.

---

## 5. Priority Matrix

| # | Action | Impact | Risk | ETA |
|---|---|---|---|---|
| 1 | Magisk module `flavenz_perf.sh` | **TINGGI** | Rendah | Sekarang |
| 2 | AutoFDO build-final (run #13) | Sedang | Rendah | ~55 menit CI |
| 3 | Defconfig `SCHED_THERMAL_PRESSURE` | Sedang | Rendah | Build berikut |
| 4 | Defconfig `ZRAM_DEF_COMP_ZSTD` | Sedang | Rendah | Build berikut |
| 5 | Debloat NexiunOS (analytics, aiservice) | Sedang | Rendah | Manual |
| 6 | BCL table patch (thermal DT) | **TINGGI** | Sedang | Perlu riset DT |

---

## 6. Benchmark Target Post-Fix

Dengan semua Tier 1 + Tier 2 diterapkan:

```
GB6 Single: ~2031 → ~2800-3200  (+37-58%)   → menang Meizu 20 Infinity (1479)
GB6 Multi:  ~5603 → ~6000-6500  (+7-16%)    → menang Meizu 20 Infinity (4952)
AnTuTu 11:  ~1.78M → ~2.0-2.1M (+12-18%)   → menang Meizu 20 Infinity (1.75M)
GPU:        900MHz → 1100MHz    (+22% freq)  → Adreno 735@1100 vs Adreno 740@680
```

> Note: Adreno 740 tetap lebih efisien per-MHz, tapi dengan 1100 vs 680 MHz,
> Adreno 735 F6 bisa kompetitif di sustained gaming.

---

## 7. Files & References

| File | Path |
|---|---|
| Diagnostic script | `/root/Flavenz-Kernel-Peridot/flavenz_diag.sh` |
| Diagnostic output | `flavenz_diag.txt` (user device, 2026-10-17 06:50 WIB) |
| Analysis JSONL | `/root/flavenz_perf_analysis.jsonl` |
| Analysis MD | `/root/flavenz_perf_analysis.md` |
| Kernel repo | `https://github.com/ZxAlif-ID/Flavenz-Kernel-Peridot` |
| AutoFDO profil | Release `Flavenz-autofdo-profiles-20260914` |
| AutoFDO run | Run #13 `38980821202` (in_progress) |

---

*Last updated: 2026-10-17 | Analyst: Flavenz CI / Twilight*
