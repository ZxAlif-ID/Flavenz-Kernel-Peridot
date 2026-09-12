# Benchmark — ack-full build | Hasil Benchmark Kernel ACK

> English below — [Bahasa Indonesia](#bahasa-indonesia)

---

## English

Live HTML report: **[media/ack-build-kernel/Antutu-Ack.html](../media/ack-build-kernel/Antutu-Ack.html)** —
also served on **GitHub Pages**: https://zxalif-id.github.io/Flavenz-Kernel-Peridot/

### Environment

| Item | Value |
|---|---|
| Kernel | **Flavenz `ack-full`** (pure ACK android14-6.1 + KSU Next v3.3.0 + SUSFS v2.1.0 + Droidspaces) |
| Device | Redmi Turbo 3 (`peridot`), Snapdragon 8s Gen 3 (SM8635), LPDDR5X + UFS 4.x |
| OS | Android 16 (64-bit) |
| Benchmark | AnTuTu Benchmark V12.0.1 (OB-1) |
| Test | Two runs — no cooler vs active cooler |
| Flash | Directly flashed from the **GitHub Releases zip** (raw asset, no wrapper) |

### Result — total score

| Run | Condition | Score | Percentile |
|---|---|---:|---|
| #1 | No cooler | 1,644,070 | better than 38% of users |
| #2 | Active cooler | **1,813,737** | better than 45% of users |
| **Δ** | **cooler vs no cooler** | **+169,667 pts (+10.3%)** | |

### Breakdown

| Component | No cooler | Cooler | Δ |
|---|---:|---:|---:|
| CPU | 471,867 | 545,611 | **+15.6%** |
| GPU — Adreno 735 | 446,626 | 446,506 | −0.0% |
| Memory — LPDDR5X UFS 4.x | 353,002 | 400,412 | +13.4% |
| UX | 372,575 | 421,208 | +13.1% |

### Thermal & battery

| Metric | No cooler | Cooler |
|---|---:|---:|
| Peak temperature | 40.3°C | **33.8°C** (−6.5°C) |
| Temperature delta during run | +9.8°C | −3.7°C |
| Battery consumed | 10% | 12% (+2%) |

### Notes

- Both runs use the pure ACK kernel with only the flavor additions: KernelSU
  Next, SUSFS, Droidspaces — **no performance tweaks**.
- GPU scores are nearly identical because the Adreno 735 sits in its own
  thermal envelope, separate from the CPU clusters.
- The RAM-latency outlier (+101% on the cooler run) needs multi-run
  confirmation before it can be claimed.
- The active cooler raises battery consumption by ~2% per session.
- **Boot verification**: `ack-full` was flashed straight from
  [Release Flavenz-20260910](https://github.com/ZxAlif-ID/Flavenz-Kernel-Peridot/releases/tag/Flavenz-20260910)
  and has been running stably since — no performance issues; the Duck Detector
  build-time-drift anomaly is fixed (kernel timestamp synced to ROM build date).

### Screenshots

No-cooler run: `media/ack-build-kernel/SS-ACK-KERNEL-BUILD-NO-COOLER-2026-09-11-16-15-44-729.jpg`
· Cooler run: `media/ack-build-kernel/SS-ACK-KERNEL-BUILD-COOLER-2026-09-11-15-54-59-355.jpg`

---

## Bahasa Indonesia

Laporan HTML live: **[media/ack-build-kernel/Antutu-Ack.html](../media/ack-build-kernel/Antutu-Ack.html)** —
juga tersedia di **GitHub Pages**: https://zxalif-id.github.io/Flavenz-Kernel-Peridot/

### Lingkungan uji

| Item | Nilai |
|---|---|
| Kernel | **Flavenz `ack-full`** (ACK murni android14-6.1 + KSU Next v3.3.0 + SUSFS v2.1.0 + Droidspaces) |
| Perangkat | Redmi Turbo 3 (`peridot`), Snapdragon 8s Gen 3 (SM8635), LPDDR5X + UFS 4.x |
| OS | Android 16 (64-bit) |
| Benchmark | AnTuTu Benchmark V12.0.1 (OB-1) |
| Skenario | Dua run — tanpa cooler vs dengan cooler aktif |
| Flash | Langsung dari **zip GitHub Releases** (aset mentah, tanpa pembungkus) |

### Hasil — skor total

| Run | Kondisi | Skor | Persentil |
|---|---|---:|---|
| #1 | Tanpa cooler | 1,644,070 | melampaui 38% pengguna |
| #2 | Dengan cooler | **1,813,737** | melampaui 45% pengguna |
| **Δ** | **cooler vs tanpa cooler** | **+169.667 poin (+10,3%)** | |

### Rincian

| Komponen | Tanpa cooler | Cooler | Δ |
|---|---:|---:|---:|
| CPU | 471,867 | 545,611 | **+15,6%** |
| GPU — Adreno 735 | 446,626 | 446,506 | −0,0% |
| Memory — LPDDR5X UFS 4.x | 353,002 | 400,412 | +13,4% |
| UX | 372,575 | 421,208 | +13,1% |

### Termal & baterai

| Metrik | Tanpa cooler | Dengan cooler |
|---|---:|---:|
| Suhu puncak | 40,3°C | **33,8°C** (−6,5°C) |
| Perubahan suhu saat run | +9,8°C | −3,7°C |
| Baterai terpakai | 10% | 12% (+2%) |

### Catatan

- Kedua run memakai kernel ACK murni tanpa tweak tambahan selain flavor:
  KernelSU Next, SUSFS, Droidspaces.
- Skor GPU hampir identik karena Adreno 735 beroperasi di thermal envelope
  terpisah dari kluster CPU.
- Outlier RAM-latency (+101% pada run cooler) perlu konfirmasi multi-run
  sebelum bisa diklaim.
- Cooler menaikkan konsumsi baterai ~2% per sesi benchmark.
- **Verifikasi boot**: `ack-full` di-flash langsung dari
  [Release Flavenz-20260910](https://github.com/ZxAlif-ID/Flavenz-Kernel-Peridot/releases/tag/Flavenz-20260910)
  dan stabil sejak itu — tidak ada masalah performa; anomali Duck Detector
  "build time drift" sudah hilang (timestamp kernel sinkron dengan tanggal
  build ROM).
