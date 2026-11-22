#!/usr/bin/env python3
"""Extract scripts (and their hierarchy) from a binary .rbxl/.rbxm place file.

Usage: python3 tools/rbxl_extract.py <place.rbxl> <out_dir> [--root Name ...]
Writes each LuaSourceContainer as <out_dir>/<Service>/<...path>/<Name>.<kind>.luau
(kind: module | client | server) and prints a summary. Needs Python 3.14+ (compression.zstd).
"""
import os
import struct
import sys

try:
    from compression import zstd
except ImportError:  # pragma: no cover
    zstd = None

SCRIPT_CLASSES = {"ModuleScript": "module", "LocalScript": "client", "Script": "server"}


def lz4_block(src: bytes, size: int) -> bytes:
    out = bytearray()
    i = 0
    n = len(src)
    while i < n:
        token = src[i]
        i += 1
        lit = token >> 4
        if lit == 15:
            while True:
                b = src[i]
                i += 1
                lit += b
                if b != 255:
                    break
        out += src[i:i + lit]
        i += lit
        if i >= n:
            break
        off = src[i] | (src[i + 1] << 8)
        i += 2
        ml = token & 15
        if ml == 15:
            while True:
                b = src[i]
                i += 1
                ml += b
                if b != 255:
                    break
        ml += 4
        start = len(out) - off
        for k in range(ml):
            out.append(out[start + k])
    return bytes(out[:size])


def decompress(comp: bytes, usize: int) -> bytes:
    if comp[:4] == b"\x28\xb5\x2f\xfd":
        return zstd.decompress(comp)
    return lz4_block(comp, usize)


def deinterleave_i32(data: bytes, count: int):
    vals = []
    for i in range(count):
        b = bytes((data[i], data[i + count], data[i + 2 * count], data[i + 3 * count]))
        u = struct.unpack(">I", b)[0]
        vals.append((u >> 1) ^ -(u & 1))
    return vals


def referents(data: bytes, count: int):
    vals = deinterleave_i32(data, count)
    acc = 0
    out = []
    for v in vals:
        acc += v
        out.append(acc)
    return out


def parse(path):
    raw = open(path, "rb").read()
    assert raw[:8] == b"<roblox!", "not a binary roblox file"
    pos = 32
    classes = {}  # classId -> (name, refs)
    names = {}  # ref -> name
    sources = {}  # ref -> source
    klass = {}  # ref -> className
    parent = {}
    while pos < len(raw):
        name = raw[pos:pos + 4]
        clen, ulen = struct.unpack("<II", raw[pos + 4:pos + 12])
        pos += 16
        if clen == 0:
            data = raw[pos:pos + ulen]
            pos += ulen
        else:
            data = decompress(raw[pos:pos + clen], ulen)
            pos += clen
        if name == b"END\x00":
            break
        if name == b"INST":
            cid, = struct.unpack("<I", data[0:4])
            ln, = struct.unpack("<I", data[4:8])
            cname = data[8:8 + ln].decode()
            p = 8 + ln
            p += 1  # object format
            cnt, = struct.unpack("<I", data[p:p + 4])
            p += 4
            refs = referents(data[p:p + 4 * cnt], cnt)
            classes[cid] = (cname, refs)
            for r in refs:
                klass[r] = cname
        elif name == b"PROP":
            cid, = struct.unpack("<I", data[0:4])
            ln, = struct.unpack("<I", data[4:8])
            pname = data[8:8 + ln].decode()
            p = 8 + ln
            tid = data[p]
            p += 1
            if tid != 0x01 or cid not in classes:
                continue
            cname, refs = classes[cid]
            if pname not in ("Name", "Source"):
                continue
            for r in refs:
                sl, = struct.unpack("<I", data[p:p + 4])
                s = data[p + 4:p + 4 + sl]
                p += 4 + sl
                if pname == "Name":
                    names[r] = s.decode("utf-8", "replace")
                else:
                    sources[r] = s.decode("utf-8", "replace")
        elif name == b"PRNT":
            cnt, = struct.unpack("<I", data[1:5])
            kids = referents(data[5:5 + 4 * cnt], cnt)
            pars = referents(data[5 + 4 * cnt:5 + 8 * cnt], cnt)
            for k, pr in zip(kids, pars):
                parent[k] = pr
    return names, sources, klass, parent


def full_path(ref, names, parent):
    parts = []
    while ref is not None and ref != -1 and ref in names:
        parts.append(names[ref])
        ref = parent.get(ref)
    return list(reversed(parts))


def main():
    src, out = sys.argv[1], sys.argv[2]
    roots = set(sys.argv[sys.argv.index("--root") + 1:]) if "--root" in sys.argv else None
    names, sources, klass, parent = parse(src)
    count = 0
    for ref, cname in klass.items():
        if cname not in SCRIPT_CLASSES or ref not in sources:
            continue
        parts = full_path(ref, names, parent)
        if roots and not (set(parts) & roots):
            continue
        dest = os.path.join(out, *parts[:-1], f"{parts[-1]}.{SCRIPT_CLASSES[cname]}.luau")
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w") as fh:
            fh.write(sources[ref])
        count += 1
        print(f"{'/'.join(parts):70s} {cname:12s} {len(sources[ref]):7d}")
    print("scripts:", count)


if __name__ == "__main__":
    main()
