# Contributing | Berkontribusi

English below — [Bahasa Indonesia](#bahasa-indonesia)

## English

Thanks for your interest in this project. It is a personal, non-commercial
kernel build for the Xiaomi POCO F6 / Redmi Turbo 3 (`peridot`), provided
AS-IS — but bug reports and thoughtful pull requests are welcome.

### Reporting issues

- Use the **Bug report** template. Fill in device, ROM, flavor
  (`guidix-full` / `ack-full`), the release tag or zip name, and what happened.
- For **flash or boot failures**, attach the **full recovery log as text**
  (OrangeFox/TWRP → "Copy Log"). Screenshots of logs are hard to work with.
- Feature ideas → the **Feature request** template. Note the project's hard
  constraints: stock-like stability, no experimental schedulers/tweaks.

### Pull requests

- This repository holds **build orchestration** (GitHub Actions workflow),
  **AnyKernel3 packaging**, and **documentation** — the kernel sources are
  upstream (ACK / GuidixX / Qualcomm) and are not stored here.
- Keep changes minimal and explain the *what* and *why*. Reference existing
  issues or CI runs where relevant.
- CI is **dispatch-only**: verification builds are dispatched manually by the
  maintainer after review, so a green check is not automatic on PRs.

### Translations

`README.md` / `README.id.md` and `docs/kernel-context.md` /
`docs/kernel-context.en.md` are maintained bilingually. If you change one
language version, update its counterpart in the same PR.

## Bahasa Indonesia

Terima kasih sudah tertarik. Proyek ini bersifat pribadi, non-komersial, dan
disediakan AS-IS — tapi laporan bug dan PR yang bagus selalu diterima.

**Laporan masalah** — pakai template **Bug report** (device, ROM, flavor,
release/zip, kronologi). Untuk flash/boot gagal, lampirkan **recovery.log
lengkap sebagai teks** (OrangeFox/TWRP → "Copy Log"), bukan screenshot.
Usulan fitur → template **Feature request** (ingat: stabilitas stock-like
adalah syarat mutlak, tanpa scheduler eksperimental).

**Pull request** — repo ini berisi orkestrasi build (GitHub Actions),
packaging AnyKernel3, dan dokumentasi; source kernel ada di upstream. Ubahan
sebaiknya minimal dan jelaskan *apa* + *kenapa*. CI hanya berjalan via
dispatch manual (workflow_dispatch) oleh maintainer setelah review.

**Dokumen dua bahasa** — `README` dan `docs/kernel-context.md` wajib
sinkron EN ↔ ID. Mengubah satu versi = perbarui padanannya di PR yang sama.
