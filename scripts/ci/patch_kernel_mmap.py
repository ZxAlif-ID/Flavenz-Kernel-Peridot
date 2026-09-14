#!/usr/bin/env python3
"""Insert synthetic [kernel.kallsyms] MMAP event into a perf.data (PERFILE2, perf 5.15).

Device recorded with kptr_restrict=2 -> perf.data has ZERO kernel MMAP events,
so create_llvm_prof (quipper) cannot attribute kernel samples to the kernel DSO.
This patcher inserts one MMAP event (start=_text, size=_end-_text, pgoff=0) at
the head of the data section. Sample IPs minus _text are KASLR-slide-invariant.

QUIRK (proven CI run 34893746931): quipper reads events by header data_size,
so growing data_size without moving the trailing feature-section descriptor
table makes it parse table bytes as events -> "Event size 0 ... UNKNOWN_EVENT_0 /
Error reading build ID header". Fix: shift the whole tail (descriptor table +
feature data) +64 and increment every descriptor's absolute offset by +64.

Usage: patch_kernel_mmap.py <in.data> <out.data> <text_addr> <kernel_len>
"""
import struct
import sys

PERFILE2 = 0x32454c4946524550


def main():
    inp, outp, text_s, len_s = sys.argv[1:5]
    text = int(text_s, 0)
    klen = int(len_s, 0)

    fn = b"[kernel.kallsyms]"
    # PERF WAJIB: event size harus kelipatan 8 (header = span aktual di disk).
    body = struct.pack("<IIQQQ", 0xFFFFFFFF, 0xFFFFFFFF, text, klen, 0) + fn + b"\x00"
    total = 8 + len(body)
    total = (total + 7) // 8 * 8
    ev = struct.pack("<IHH", 1, 0, total) + body
    ev += b"\x00" * (total - len(ev))
    assert len(ev) == total and total % 8 == 0

    with open(inp, "rb") as f:
        head = f.read(96)
    if struct.unpack_from("<Q", head, 0)[0] != PERFILE2:
        sys.exit(f"not PERFILE2: {inp}")
    h = struct.unpack_from("<Q9Q", head, 8)
    data_off, data_size = h[4], h[5]
    data_end = data_off + data_size

    # guard idempotensi
    with open(inp, "rb") as f:
        f.seek(data_off)
        if fn in f.read(4096):
            print(f"SKIP {inp}: [kernel.kallsyms] sudah ada di data section")
            return

    with open(inp, "rb") as f:
        f.seek(data_end)
        desc0 = f.read(16)
    if len(desc0) == 16:
        d0_off, d0_size = struct.unpack("<QQ", desc0)
        # tabel deskriptor menutup [data_end, desc0.off); butuh sanity
        if data_end < d0_off <= data_end + 65536:
            table_len = d0_off - data_end
        else:
            table_len = 0
    else:
        table_len = 0

    with open(inp, "rb") as f:
        f.seek(0)
        header = bytearray(f.read(data_off))
        f.seek(data_off)
        data = f.read(data_size)
        f.seek(data_end)
        tail = f.read()  # tabel + feature data (akan geser +len(ev))

    struct.pack_into("<QQ", header, 8 + 8 * 4, data_off, data_size + len(ev))

    if table_len:
        tbl = bytearray(tail[:table_len])
        for k in range(0, table_len, 16):
            off, size = struct.unpack_from("<QQ", tbl, k)
            if off:  # slot kosong = {0,0} dibiarkan
                struct.pack_into("<Q", tbl, k, off + len(ev))
        tail = bytes(tbl) + tail[table_len:]
        note = f"tail shifted +{len(ev)} (table {table_len} B, offsets bumped)"
    else:
        note = "no feature table detected, tail copied verbatim"

    with open(outp, "wb") as o:
        o.write(header)
        o.write(ev)
        o.write(data)
        o.write(tail)
    print(f"patched {outp}: MMAP start={text:#x} len={klen:#x} (+{len(ev)} B; {note})")


if __name__ == "__main__":
    main()
