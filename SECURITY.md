# Security Policy

## Supported versions

This is a personal, non-commercial project maintained best-effort. Only the
**latest published GitHub Release** is supported. Older releases and CI
artifacts are provided as-is and receive no updates.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting:

1. Open the repository → **Security** tab → **Report a vulnerability**.
2. Describe the issue, affected flavor (`guidix-full` / `ack-full`), and how to
   reproduce it.

**Do not open a public issue** for anything that could be exploited on a
device. Public reports will be handled with lower priority and may be removed.

## Scope

- This repository contains **build orchestration, AnyKernel3 packaging, and
  documentation** — the kernel sources themselves are upstream (ACK, GuidixX,
  Qualcomm CLO) and vulnerabilities there belong to the respective projects.
- No bounty, no SLA. The kernels are provided **AS-IS** with no security
  guarantee — see the Disclaimer in the README. Always back up `boot` and
  `init_boot` before flashing.

## Bahasa Indonesia

Proyek pribadi, non-komersial, dirawat best-effort — hanya **rilis terbaru**
yang didukung. Laporkan kerentanan secara privat lewat tab **Security →
Report a vulnerability**; jangan buka issue publik untuk hal yang bisa
dieksploitasi. Kernel disediakan **AS-IS**, keamanan tidak dijamin — selalu
backup `boot` & `init_boot` sebelum flash.
