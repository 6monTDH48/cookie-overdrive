#!/usr/bin/env python3
"""Generates roblox/tools/tests/fixtures.luau for test_inflate.luau (Python stdlib only).

Every case is compressed with Python's zlib (the same library pack_assets.py uses) and stored as
base64. The expected output is described by its length and CRC-32, plus the full bytes (base64)
for the smaller cases so the Luau test can compare byte for byte.

Deterministic: fixed random seeds, so re-running produces the same file.
    python3 roblox/tools/tests/make_fixtures.py
"""
import base64
import math
import os
import random
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "fixtures.luau")
FULL_LIMIT = 64_000  # include the expected bytes when the raw data is at most this big


def cookie_rgba(w, h, r, seed):
    """A cookie-like RGBA image: shaded disc with noise and chocolate chips, anti-aliased edge,
    transparent (alpha-bled) background. Roughly as compressible as the real renders."""
    rnd = random.Random(seed)
    cx, cy = w / 2, h / 2
    chips = [(cx + rnd.uniform(-0.7, 0.7) * r, cy + rnd.uniform(-0.7, 0.7) * r, rnd.uniform(0.06, 0.12) * r)
             for _ in range(14)]
    noise = [rnd.randrange(-6, 7) for _ in range(4096)]
    out = bytearray(w * h * 4)
    i = 0
    for y in range(h):
        dy = y + 0.5 - cy
        for x in range(w):
            dx = x + 0.5 - cx
            d = math.sqrt(dx * dx + dy * dy)
            a = max(0.0, min(1.0, r - d + 0.5))
            shade = 1.0 - 0.35 * (d / r) + 0.12 * (-dx - dy) / (r * 1.4)
            cr, cg, cb = 214 * shade, 150 * shade, 84 * shade
            for (hx, hy, hr) in chips:
                ex, ey = x - hx, y - hy
                if ex * ex + ey * ey < hr * hr:
                    cr, cg, cb = 74, 42, 24
                    break
            n = noise[(x * 7 + y * 131) & 4095]
            if d > r + 2:
                cr, cg, cb = 214 * 0.6, 150 * 0.6, 84 * 0.6  # bled background colour
                n = 0
            out[i] = max(0, min(255, int(cr + n)))
            out[i + 1] = max(0, min(255, int(cg + n)))
            out[i + 2] = max(0, min(255, int(cb + n)))
            out[i + 3] = int(round(a * 255))
            i += 4
    return bytes(out)


def gradient_rgba(w, h):
    out = bytearray(w * h * 4)
    i = 0
    for y in range(h):
        for x in range(w):
            out[i] = (x * 255) // max(1, w - 1)
            out[i + 1] = (y * 255) // max(1, h - 1)
            out[i + 2] = ((x + y) // 6) & 255
            out[i + 3] = 255 if (x // 16 + y // 16) % 5 else 128
            i += 4
    return bytes(out)


def zipf_bytes(n, seed):
    """No repeats worth matching, very skewed symbol frequencies -> Huffman codes up to 15 bits."""
    rnd = random.Random(seed)
    weights = [1.0 / (k + 1) ** 2.2 for k in range(256)]
    syms = list(range(256))
    rnd.shuffle(syms)
    return bytes(rnd.choices(syms, weights, k=n))


def compress(data, level=9, wbits=15, strategy=zlib.Z_DEFAULT_STRATEGY, memlevel=8):
    c = zlib.compressobj(level, zlib.DEFLATED, wbits, memlevel, strategy)
    return c.compress(data) + c.flush()


def main():
    rnd = random.Random(1234)
    text = (b"Cookie Overdrive! Clique le cookie, achete des batiments, fais un rebirth. " * 40
            + bytes(rnd.randrange(32, 127) for _ in range(3000)))
    rand100k = bytes(rnd.randrange(256) for _ in range(70_000))
    rand32k = bytes(rnd.randrange(256) for _ in range(32768))
    img64 = cookie_rgba(64, 64, 20, 1)
    img256 = cookie_rgba(256, 256, 80, 2)
    img640 = cookie_rgba(640, 640, 200, 3)
    grad = gradient_rgba(512, 288)
    img128 = cookie_rgba(128, 128, 40, 4)

    cases = []

    def add(name, data, comp, mode="zlib"):
        # sanity: Python must round-trip what it wrote
        if mode == "zlib":
            assert zlib.decompress(comp) == data
        else:
            assert zlib.decompress(comp, -15) == data
        cases.append((name, mode, comp, data))

    add("empty", b"", compress(b""))
    add("one byte", b"x", compress(b"x"))
    add("hello (fixed huffman)", b"hello hello hello world", compress(b"hello hello hello world"))
    add("text level 9", text, compress(text))
    add("text level 1", text, compress(text, 1))
    add("text Z_FIXED", text, compress(text, 9, strategy=zlib.Z_FIXED))
    add("text Z_HUFFMAN_ONLY", text, compress(text, 9, strategy=zlib.Z_HUFFMAN_ONLY))
    add("text raw deflate", text, compress(text, 6, wbits=-15), mode="raw")
    add("text window 512", text, compress(text, 9, wbits=9))
    add("random 70k level 9", rand100k, compress(rand100k))
    add("random 70k level 0 (stored, 2 blocks)", rand100k, compress(rand100k, 0))
    rep = rand32k + rand32k[:20000]
    add("distance 32768", rep, compress(rep, 9))
    add("abc repeated (overlap dist 3)", b"abc" * 60000, compress(b"abc" * 60000))
    add("zeros 1MB (dist 1 runs)", bytes(1 << 20), compress(bytes(1 << 20)))
    pat = bytes(range(7)) * 20000
    add("period 7 (overlap copies)", pat, compress(pat))
    z = zipf_bytes(120_000, 7)
    add("zipf (long codes)", z, compress(z))
    add("zipf Z_HUFFMAN_ONLY", z, compress(z, 9, strategy=zlib.Z_HUFFMAN_ONLY))
    mixed = text + rand100k[:30000] + bytes(5000) + text[::-1] + b"\xff" * 3000
    add("mixed blocks", mixed, compress(mixed, 6))
    add("rgba 64x64", img64, compress(img64))
    add("rgba 256x256", img256, compress(img256))
    add("rgba 128x128 Z_RLE", img128, compress(img128, 9, strategy=zlib.Z_RLE))
    add("rgba 256x256 level 1", img256, compress(img256, 1))
    add("rgba 640x640 cookie", img640, compress(img640, 9))
    add("rgba 512x288 gradient", grad, compress(grad, 9))

    lines = [
        "-- Generated by make_fixtures.py (Python zlib " + zlib.ZLIB_VERSION + "). Do not edit.",
        "-- z = base64 of the compressed stream, n = expected size, crc = CRC-32 of the output,",
        "-- raw = base64 of the expected output (small cases only).",
        "return {",
    ]
    total = 0
    for name, mode, comp, data in cases:
        zb = base64.b64encode(comp).decode()
        raw = base64.b64encode(data).decode() if len(data) <= FULL_LIMIT else None
        total += len(zb) + (len(raw) if raw else 0)
        fields = [
            f'name = "{name}"',
            f'mode = "{mode}"',
            f"n = {len(data)}",
            f"crc = {zlib.crc32(data)}",
            f'z = "{zb}"',
        ]
        if raw is not None:
            fields.append(f'raw = "{raw}"')
        if name.startswith("rgba 640x640"):
            fields.append("bench = true")
        lines.append("\t{ " + ", ".join(fields) + " },")
    lines.append("}")
    with open(OUT, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {OUT}: {len(cases)} cases, {total / 1024:.0f} KB of base64")
    for name, mode, comp, data in cases:
        print(f"  {name:42s} raw {len(data):>8} -> {len(comp):>8} bytes")


if __name__ == "__main__":
    main()
