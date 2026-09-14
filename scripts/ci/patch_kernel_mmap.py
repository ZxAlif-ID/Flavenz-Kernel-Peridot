#!/usr/bin/env python3
"""Insert synthetic [kernel.kallsyms] MMAP2 event into a perf.data (PERFILE2).

Device recorded with kptr_restrict=2 -> perf.data has ZERO kernel MMAP events,
so create_llvm_prof (quipper) cannot attribute kernel samples to the kernel DSO.
This patcher inserts one MMAP2 event (start=_text, size=_end-_text) at the head
of the data section. Sample IPs minus _text are KASLR-slide-invariant.

Design notes (all proven against quipper source + CI runs 34889560179/34893746931/
34897353379):
- MMAP2 (not MMAP): mirrors the events perf 5.15 actually writes in our files
  (kernel text mapped as exec, attr sample_id_all), so quipper's fixed/variable
  payload math holds by construction.
- Layout: pid,tid,start,len,pgoff (24) + maj,min,ino,ino_gen,prot,flags (32)
  + reserved (8) + filename NUL-padded to 8 (quipper: GetUint64AlignedStringLength)
  + 32 B zero sample-id tail. header.size MUST equal the real byte span
  (perf events are 8-aligned; header size == disk span).
- quipper enforces header.size > fixed_payload + aligned_filename (perf_serializer
  GetSampleInfoReaderForEvent) - the zero tail satisfies that for MMAP2.
- quipper reads events by header data_size: growing data_size requires shifting
  the trailing feature-section descriptor table and bumping its absolute offsets
  (perf tools read by count and never notice; quipper does).

Usage: patch_kernel_mmap.py <in.data> <out.data> <text_addr> <kernel_len>
"""
import struct
import sys

PERFILE2 = 0x32454c4946524550
FN = b"[kernel.kallsyms]"


def build_event(text, klen):
    # Layout terukur dari MMAP2 asli di segmen rekaman (kernel 5.15):
    # hdr8 + pid4 tid4 start8 len8 pgoff8 (=40) + maj4 min4 ino8 ino_gen8 (=64)
    # + prot4 flags4 (=72) -> filename @72. TANPA reserved tambahan.
    body = struct.pack("<IIQQQ", 0xFFFFFFFF, 0xFFFFFFFF, text, klen, 0)
    body += struct.pack("<IIQQ", 0, 0, 0, 0)          # maj,min,ino,ino_gen
    body += struct.pack("<II", 5, 0)                  # prot (r-x), flags
    assert len(body) == 64
    body += FN + b"\x00"
    total = (8 + len(body) + 7) // 8 * 8
    total += 32                                       # sample-id tail (zeros)
    ev = struct.pack("<IHH", 10, 0, total) + body
    ev += b"\x00" * (total - len(ev))
    assert len(ev) == total and total % 8 == 0
    assert ev[72:72 + len(FN)] == FN                  # nama persis di offset kernel
    return ev


def main():
    inp, outp, text_s, len_s = sys.argv[1:5]
    text = int(text_s, 0)
    klen = int(len_s, 0)
    ev = build_event(text, klen)

    with open(inp, "rb") as f:
        head = f.read(96)
    if struct.unpack_from("<Q", head, 0)[0] != PERFILE2:
        sys.exit(f"not PERFILE2: {inp}")
    h = struct.unpack_from("<Q9Q", head, 8)
    data_off, data_size = h[4], h[5]
    data_end = data_off + data_size

    with open(inp, "rb") as f:
        f.seek(data_off)
        if FN in f.read(4096):
            print(f"SKIP {inp}: {FN.decode()} sudah ada di data section")
            return

    with open(inp, "rb") as f:
        f.seek(data_end)
        desc0 = f.read(16)
    table_len = 0
    if len(desc0) == 16:
        d0_off, _ = struct.unpack("<QQ", desc0)
        if data_end < d0_off <= data_end + 65536:
            table_len = d0_off - data_end

    with open(inp, "rb") as f:
        f.seek(0)
        header = bytearray(f.read(data_off))
        f.seek(data_off)
        data = f.read(data_size)
        f.seek(data_end)
        tail = f.read()

    struct.pack_into("<QQ", header, 8 + 8 * 4, data_off, data_size + len(ev))

    if table_len:
        tbl = bytearray(tail[:table_len])
        for k in range(0, table_len, 16):
            off, size = struct.unpack_from("<QQ", tbl, k)
            if off:
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
    print(f"patched {outp}: MMAP2 start={text:#x} len={klen:#x} "
          f"(+{len(ev)} B; {note})")


if __name__ == "__main__":
    main()
