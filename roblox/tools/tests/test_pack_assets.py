#!/usr/bin/env python3
"""Tests for roblox/tools/pack_assets.py (stdlib only):  python3 roblox/tools/tests/test_pack_assets.py

1. PNG decoder: every colour type / bit depth, all 5 filter types, Adam7 interlacing, tRNS,
   against a small independent reference encoder written here. Also the exporter's own encoder
   (roblox/tools/export/png.js) when node is available.
2. End-to-end packing in a temporary folder: module format, _index, AssetIds (non-zero ids kept),
   idempotency (second run writes nothing), cache invalidation, stale module deletion.
"""
import base64
import json
import os
import random
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

sys.dont_write_bytecode = True  # no __pycache__ next to the tools
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import pack_assets  # noqa: E402

FAILS = []


def check(cond, msg):
    if not cond:
        FAILS.append(msg)
        print("FAIL:", msg)


# ---------------------------------------------------------------- reference PNG encoder
def chunk(t, body):
    return struct.pack(">I", len(body)) + t + body + struct.pack(">I", zlib.crc32(t + body))


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    return a if pa <= pb and pa <= pc else (b if pb <= pc else c)


def filter_row(ft, row, prev, bpp):
    out = bytearray(len(row))
    for i, x in enumerate(row):
        a = row[i - bpp] if i >= bpp else 0
        b = prev[i]
        c = prev[i - bpp] if i >= bpp else 0
        pred = (0, a, b, (a + b) >> 1, paeth(a, b, c))[ft]
        out[i] = (x - pred) & 255
    return bytes(out)


def pack_row(samples, depth):
    if depth == 8:
        return bytes(samples)
    if depth == 16:
        return b"".join(struct.pack(">H", s) for s in samples)
    per = 8 // depth
    out = bytearray((len(samples) + per - 1) // per)
    for i, s in enumerate(samples):
        out[i // per] |= s << (8 - depth - (i % per) * depth)
    return bytes(out)


def encode_png(w, h, ctype, depth, pixels, interlace=0, plte=None, trns=None, rnd=None):
    """pixels[y][x] = tuple of samples. Filters chosen randomly per row (all 5 types used)."""
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    bpp = max(1, channels * depth // 8)
    raw = bytearray()

    def emit(sub):  # sub: list of rows of pixel tuples
        prev = None
        for r in sub:
            row = pack_row([s for px in r for s in px], depth)
            if prev is None:
                prev = bytes(len(row))
            ft = rnd.randrange(5)
            raw.append(ft)
            raw.extend(filter_row(ft, row, prev, bpp))
            prev = row

    if interlace == 0:
        emit(pixels)
    else:
        for (x0, y0, dx, dy) in ((0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4),
                                 (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2)):
            sub = [[pixels[y][x] for x in range(x0, w, dx)] for y in range(y0, h, dy)]
            if sub and sub[0]:
                emit(sub)
    out = pack_assets.PNG_SIG + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, depth, ctype, 0, 0, interlace))
    if plte is not None:
        out += chunk(b"PLTE", plte)
    if trns is not None:
        out += chunk(b"tRNS", trns)
    z = zlib.compress(bytes(raw), 6)
    out += chunk(b"IDAT", z[: len(z) // 2]) + chunk(b"IDAT", z[len(z) // 2:])  # split IDAT on purpose
    return out + chunk(b"IEND", b"")


def expected_rgba(ctype, depth, px, plte, trns):
    if ctype == 6:
        return tuple(s >> 8 if depth == 16 else s for s in px)
    if ctype == 2:
        rgb = tuple(s >> 8 if depth == 16 else s for s in px)
        a = 0 if trns is not None and px == struct.unpack(">HHH", trns) else 255
        return rgb + (a,)
    if ctype == 0:
        s = px[0]
        g = s >> 8 if depth == 16 else s * (255 // ((1 << depth) - 1))
        a = 0 if trns is not None and s == struct.unpack(">H", trns)[0] else 255
        return (g, g, g, a)
    if ctype == 4:
        g, a = (s >> 8 if depth == 16 else s for s in px)
        return (g, g, g, a)
    if ctype == 3:
        i = px[0]
        a = trns[i] if trns is not None and i < len(trns) else 255
        return (plte[3 * i], plte[3 * i + 1], plte[3 * i + 2], a)
    raise AssertionError


def test_png_decoder(tmp):
    rnd = random.Random(42)
    combos = [(0, d) for d in (1, 2, 4, 8, 16)] + [(2, 8), (2, 16), (4, 8), (4, 16), (6, 8), (6, 16)] + \
             [(3, d) for d in (1, 2, 4, 8)]
    n = 0
    for ctype, depth in combos:
        for interlace in (0, 1):
            for (w, h) in ((1, 1), (5, 3), (13, 11), (33, 9)):
                channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
                maxv = (1 << depth) - 1
                plte = trns = None
                if ctype == 3:
                    ncol = min(1 << depth, 200)
                    plte = bytes(rnd.randrange(256) for _ in range(3 * ncol))
                    trns = bytes(rnd.randrange(256) for _ in range(ncol // 2))
                    maxv = ncol - 1
                # smooth-ish data so every filter produces varied bytes
                pixels = [[tuple(min(maxv, max(0, (x * 37 + y * 11 + c * 50 + rnd.randrange(-3, 4)) % (maxv + 1)))
                                 for c in range(channels)) for x in range(w)] for y in range(h)]
                if ctype in (0, 2) and rnd.random() < 0.7:
                    key = pixels[0][0]
                    trns = struct.pack(">H", key[0]) if ctype == 0 else struct.pack(">HHH", *key)
                data = encode_png(w, h, ctype, depth, pixels, interlace, plte, trns, rnd)
                path = os.path.join(tmp, "t.png")
                with open(path, "wb") as f:
                    f.write(data)
                gw, gh, rgba = pack_assets.read_png(path)
                exp = b"".join(bytes(expected_rgba(ctype, depth, pixels[y][x], plte, trns))
                               for y in range(h) for x in range(w))
                check((gw, gh) == (w, h) and rgba == exp,
                      f"PNG decode ctype={ctype} depth={depth} interlace={interlace} {w}x{h}")
                n += 1
    # a larger RGBA image through every filter (exercises the fast paths on long rows)
    w, h = 300, 40
    pixels = [[((x * 3 + y) & 255, (x ^ y) & 255, (x * y) & 255, 255 if x % 7 else x & 255) for x in range(w)]
              for y in range(h)]
    data = encode_png(w, h, 6, 8, pixels, 0, None, None, rnd)
    with open(os.path.join(tmp, "big.png"), "wb") as f:
        f.write(data)
    _, _, rgba = pack_assets.read_png(os.path.join(tmp, "big.png"))
    check(rgba == b"".join(bytes(p) for row in pixels for p in row), "PNG decode 300x40 RGBA")
    n += 1
    print(f"PNG decoder: {n} images checked")


def test_exporter_encoder(tmp):
    """Round trip through roblox/tools/export/png.js (the encoder that writes the real assets)."""
    png_js = os.path.join(os.path.dirname(HERE), "export", "png.js")
    if not shutil.which("node") or not os.path.isfile(png_js):
        print("exporter encoder: skipped (node or png.js missing)")
        return
    w, h = 97, 61
    rnd = random.Random(7)
    rgba = bytes((x * 5 + y * 3 + c * 70 + rnd.randrange(3)) & 255 if c < 3 else (255 if (x + y) % 9 else 0)
                 for y in range(h) for x in range(w) for c in range(4))
    raw_path = os.path.join(tmp, "in.rgba")
    out_path = os.path.join(tmp, "out.png")
    with open(raw_path, "wb") as f:
        f.write(rgba)
    js = (f"const p=require({json.dumps(png_js)});const fs=require('fs');"
          f"fs.writeFileSync({json.dumps(out_path)},p.encodeRGBA({w},{h},fs.readFileSync({json.dumps(raw_path)})));")
    subprocess.run(["node", "-e", js], check=True)
    gw, gh, got = pack_assets.read_png(out_path)
    check((gw, gh) == (w, h) and got == rgba, "exporter png.js round trip")
    print("exporter encoder: round trip ok")


# ---------------------------------------------------------------- end-to-end packing
def write_png_rgba(path, w, h, rgba):
    rows = b"".join(b"\x00" + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))
    data = (pack_assets.PNG_SIG + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(data)


def run_pack(assets, out, ids):
    import contextlib
    import io
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        code = pack_assets.main(["--assets", assets, "--out", out, "--ids", ids, "--jobs", "2"])
    return code, buf.getvalue()


def test_pack(tmp):
    assets = os.path.join(tmp, "assets")
    os.makedirs(os.path.join(assets, "png"))
    out = os.path.join(tmp, "ImageData")
    ids_path = os.path.join(tmp, "AssetIds.lua")
    images = {
        "ui:gem": (16, 16),
        "cookie:classic": (64, 64),
        "acc:crown_2": (40, 24),
        "b:cursor": (8, 8),
    }
    pixels = {}
    manifest = {}
    for i, (key, (w, h)) in enumerate(images.items()):
        rgba = bytes(((x * 7 + y * 3 + c * 40 + i) & 255) for y in range(h) for x in range(w) for c in range(4))
        pixels[key] = rgba
        fname = key.replace(":", "__") + ".png"
        write_png_rgba(os.path.join(assets, "png", fname), w, h, rgba)
        manifest[key] = {"file": fname, "w": w, "h": h}
    with open(os.path.join(assets, "manifest.json"), "w") as f:
        json.dump(manifest, f)
    # stale module + pre-existing AssetIds with one uploaded image and one removed key
    os.makedirs(out)
    with open(os.path.join(out, "old__thing.lua"), "w") as f:
        f.write("return {}\n")
    with open(ids_path, "w") as f:
        f.write('return {\n\t["ui:gem"] = 123456,\n\t["b:cursor"] = 0,\n\t["gone:key"] = 777,\n}\n')

    code, log = run_pack(assets, out, ids_path)
    check(code == 0, "pack exit code 0\n" + log)
    check(not os.path.exists(os.path.join(out, "old__thing.lua")), "stale module removed")
    for key, rgba in pixels.items():
        stem = key.replace(":", "__")
        with open(os.path.join(out, stem + ".lua")) as f:
            parsed = pack_assets.parse_module(f.read())
        check(parsed is not None, f"module {stem} parses")
        if parsed:
            _, _, pkey, w, h, z = parsed
            check(pkey == key and (w, h) == images[key], f"module {stem} key/size")
            check(zlib.decompress(base64.b64decode(z)) == rgba, f"module {stem} pixels")
    with open(os.path.join(out, "_index.lua")) as f:
        idx = f.read()
    for key in images:
        check(f'["{key}"] = "{key.replace(":", "__")}",' in idx, f"_index has {key}")
    ids = pack_assets.read_asset_ids(ids_path)
    check(ids.get("ui:gem") == 123456, "non-zero AssetId kept")
    check(ids.get("gone:key") == 777, "non-zero AssetId of a removed key kept")
    check(ids.get("cookie:classic") == 0 and ids.get("b:cursor") == 0, "new keys get 0")

    # idempotent: nothing rewritten
    mtimes = {n: os.path.getmtime(os.path.join(out, n)) for n in os.listdir(out)}
    code, log = run_pack(assets, out, ids_path)
    check(code == 0 and "0 module(s) written" in log and "all 4 image(s) unchanged" in log, "second run is a no-op\n" + log)
    check(mtimes == {n: os.path.getmtime(os.path.join(out, n)) for n in os.listdir(out)}, "no file touched")

    # a changed PNG is re-encoded; a removed key deletes its module
    rgba = bytes(255 - b for b in pixels["b:cursor"])
    write_png_rgba(os.path.join(assets, "png", "b__cursor.png"), 8, 8, rgba)
    del manifest["acc:crown_2"]
    with open(os.path.join(assets, "manifest.json"), "w") as f:
        json.dump(manifest, f)
    code, log = run_pack(assets, out, ids_path)
    check(code == 0 and "encoding 1 image(s)" in log, "only the changed PNG is re-encoded\n" + log)
    check(not os.path.exists(os.path.join(out, "acc__crown_2.lua")), "module of removed key deleted")
    with open(os.path.join(out, "b__cursor.lua")) as f:
        z = pack_assets.parse_module(f.read())[5]
    check(zlib.decompress(base64.b64decode(z)) == rgba, "re-encoded pixels")

    # missing PNG -> error code, other images still packed
    manifest["ui:missing"] = {"file": "ui__missing.png", "w": 4, "h": 4}
    with open(os.path.join(assets, "manifest.json"), "w") as f:
        json.dump(manifest, f)
    code, log = run_pack(assets, out, ids_path)
    check(code == 1 and os.path.exists(os.path.join(out, "ui__gem.lua")), "missing PNG reported, rest kept")
    print("packing: end-to-end checks done")


def main():
    tmp = tempfile.mkdtemp(prefix="pack_test_")
    try:
        test_png_decoder(tmp)
        test_exporter_encoder(tmp)
        test_pack(tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if FAILS:
        print(f"\n{len(FAILS)} failure(s)")
        return 1
    print("\nall pack_assets tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
