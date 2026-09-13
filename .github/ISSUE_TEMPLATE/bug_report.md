---
name: Bug report
about: Flash failure, bootloop, detection anomaly, or unexpected behavior
title: "[bug] "
labels:
  - bug
---

**Device / ROM**
- Device: (POCO F6 / Redmi Turbo 3)
- ROM + version: (e.g. HyperOS 3 port, build date)
- Android version:

**Kernel build**
- Flavor: `ack-full` (guidix-full was removed on 2026-09-13)
- Release tag or zip name:
- CI run link (if relevant):

**What happened?**
A clear description of the failure (flash abort, bootloop, checker anomaly,
performance regression, ...).

**Steps to reproduce**
1. ...
2. ...

**Logs**
- For flash/boot failures attach the **full recovery log as text**
  (OrangeFox/TWRP → "Copy Log"). Do not paste screenshots of logs.
- For detection anomalies (Duck Detector / Holmes / Native Detector) attach the
  exact anomaly text and the output of `uname -a`.

**Checklist**
- [ ] The zip was downloaded from **GitHub Releases** (raw, not an Actions artifact wrapper)
- [ ] `boot` and `init_boot` were backed up before flashing
