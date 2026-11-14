#!/usr/bin/env python3
"""Write a copy of a binary .rbxl with script sources replaced from a src/ tree.

Usage: python3 tools/rbxl_patch_sources.py <in.rbxl> <src_dir> <out.rbxl>
Script files are matched by full path (<Service>/<...>/<Name>.<kind>.luau, as written by rbxl_extract.py).
Patched PROP chunks are stored uncompressed (valid in the binary format); other chunks are copied as is.
"""
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(__file__))
from rbxl_extract import SCRIPT_CLASSES, decompress, full_path, parse, referents  # noqa: E402


def main():
    src_file, src_dir, out_file = sys.argv[1:4]
    names, sources, klass, parent = parse(src_file)
    wanted = {}
    for ref, cname in klass.items():
        if cname in SCRIPT_CLASSES:
            parts = full_path(ref, names, parent)
            p = os.path.join(src_dir, *parts[:-1], f"{parts[-1]}.{SCRIPT_CLASSES[cname]}.luau")
            if os.path.exists(p):
                wanted[ref] = open(p, encoding="utf-8").read()
    raw = open(src_file, "rb").read()
    out = bytearray(raw[:32])
    pos = 32
    classes = {}
    patched = 0
    while pos < len(raw):
        head = raw[pos:pos + 16]
        name = head[:4]
        clen, ulen = struct.unpack("<II", head[4:12])
        body = raw[pos + 16:pos + 16 + (clen or ulen)]
        pos += 16 + (clen or ulen)
        data = decompress(body, ulen) if clen else body
        if name == b"INST":
            cid, = struct.unpack("<I", data[0:4])
            ln, = struct.unpack("<I", data[4:8])
            cname = data[8:8 + ln].decode()
            p = 9 + ln
            cnt, = struct.unpack("<I", data[p:p + 4])
            classes[cid] = (cname, referents(data[p + 4:p + 4 + 4 * cnt], cnt))
        if name == b"PROP":
            cid, = struct.unpack("<I", data[0:4])
            ln, = struct.unpack("<I", data[4:8])
            pname = data[8:8 + ln].decode()
            cname, refs = classes.get(cid, ("", []))
            if pname == "Source" and cname in SCRIPT_CLASSES and any(r in wanted for r in refs):
                p = 8 + ln + 1
                values = []
                for r in refs:
                    sl, = struct.unpack("<I", data[p:p + 4])
                    old = data[p + 4:p + 4 + sl]
                    p += 4 + sl
                    if r in wanted:
                        values.append(wanted[r].encode("utf-8"))
                        patched += 1
                    else:
                        values.append(old)
                new = bytearray(data[:8 + ln + 1])
                for v in values:
                    new += struct.pack("<I", len(v)) + v
                out += name + struct.pack("<III", 0, len(new), 0) + new
                continue
        out += head + body
        if name == b"END\x00":
            out += raw[pos:]
            break
    open(out_file, "wb").write(out)
    print(f"patched {patched} scripts -> {out_file} ({len(out)} bytes)")


if __name__ == "__main__":
    main()
