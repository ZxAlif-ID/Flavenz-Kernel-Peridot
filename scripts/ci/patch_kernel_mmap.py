#!/usr/bin/env python3
"""Insert synthetic [kernel.kallsyms] MMAP event into a perf.data (PERFILE2).

Device recorded with kptr_restrict=2 -> perf.data has ZERO kernel MMAP events,
so create_llvm_prof cannot attribute kernel samples to the kernel DSO. This
patcher inserts one MMAP event (start=_text, size=_end-_text, pgoff=0) at the
head of the data section. Sample IPs minus _text are KASLR-slide-invariant, so
offsets land on the same vmlinux symbols regardless of the recording boot.

Usage: patch_kernel_mmap.py <in.data> <out.data> <text_addr_hex> <kernel_len_hex>

NOTE: perf feature sections live AFTER the data section; extending data_size
shifts them consistently and readers recompute their base from the header.
"""
import struct
import sys


def main():
    inp, outp, text_s, len_s = sys.argv[1:5]
    text = int(text_s, 0)
    klen = int(len_s, 0)

    fn = b"[kernel.kallsyms]"
    ev = struct.pack("<IHH", 1, 0, 40 + len(fn) + 1)  # MMAP, misc=0
    ev += struct.pack("<IIQQQ", 0xFFFFFFFF, 0xFFFFFFFF, text, klen, 0)
    ev += fn + b"\x00"
    if len(ev) % 8:
        ev += b"\x00" * (8 - len(ev) % 8)

    with open(inp, "rb") as f:
        head = f.read(520)
    h = struct.unpack_from("<Q9Q", head, 8)
    data_off, data_size = h[4], h[5]
    if struct.unpack_from("<Q", head, 0)[0] != 0x32454c4946524550:
        sys.exit(f"not PERFILE2: {inp}")
    # guard idempotensi: kalau data section awal sudah memuat nama kernel DSO, skip
    with open(inp, "rb") as f:
        f.seek(data_off)
        probe = f.read(4096)
    if fn in probe:
        print(f"SKIP {inp}: [kernel.kallsyms] sudah ada di data section")
        return
    head = bytearray(open(inp, "rb").read(data_off))
    struct.pack_into("<QQ", head, 8 + 8 * 4, data_off, data_size + len(ev))

    with open(outp, "wb") as o, open(inp, "rb") as src:
        o.write(head)
        o.write(ev)
        src.seek(data_off)
        while True:
            c = src.read(8 << 20)
            if not c:
                break
            o.write(c)
    print(f"patched {outp}: MMAP [kernel.kallsyms] start={text:#x} len={klen:#x} (+{len(ev)} B, data {data_size}->{data_size + len(ev)})")


if __name__ == "__main__":
    main()
