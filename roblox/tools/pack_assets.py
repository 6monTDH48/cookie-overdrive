#!/usr/bin/env python3
"""pack_assets.py — embeds the exported PNGs into the Roblox place as Luau ModuleScripts.

Reads   roblox/assets/manifest.json + roblox/assets/png/*.png   (written by the exporter)
Writes  roblox/src/shared/ImageData/<file-stem>.lua   one module per image:
            return { key = "ui:gem", w = 128, h = 128, z = "<base64(zlib(raw RGBA8))>" }
        roblox/src/shared/ImageData/_index.lua        return { ["ui:gem"] = "ui__gem", ... }
        roblox/src/shared/AssetIds.lua                return { ["ui:gem"] = 0, ... }
                                                      (non-zero ids already present are kept)
Pixels are raw RGBA8, unpremultiplied, row-major, top row first, compressed with zlib level 9.
At runtime src/client/Img.lua decodes them with src/shared/Inflate.lua into EditableImages.

Python 3.8+ standard library only (PNG decoding is implemented here), so it runs anywhere:
    python3 roblox/tools/pack_assets.py            # from the repository root (or anywhere)
Options: --assets DIR  --out DIR  --ids FILE  --jobs N  --force  --top N

Deterministic and idempotent: files are rewritten only when their content changes, modules whose
key disappeared from the manifest are deleted, and a module is re-encoded only when its PNG
changed (the PNG's SHA-1 is stored in the module's first line) or with --force.
"""
import argparse
import base64
import hashlib
import itertools
import json
import os
import re
import struct
import sys
import zlib
from concurrent.futures import ProcessPoolExecutor

PACK_VERSION = 1
MAX_SIDE = 1024  # EditableImage limit
HEADER_RE = re.compile(r"^-- pack_assets v(\d+) png-sha1=([0-9a-f]{40})")
ID_RE = re.compile(r'\[\s*"((?:[^"\\]|\\.)*)"\s*\]\s*=\s*(\d+)')

HERE = os.path.dirname(os.path.abspath(__file__))
ROBLOX = os.path.dirname(HERE)


# --------------------------------------------------------------------------------------------
# PNG decoding (all colour types and bit depths, Adam7 interlacing) -> RGBA8 bytes
# --------------------------------------------------------------------------------------------
PNG_SIG = b"\x89PNG\r\n\x1a\n"
_AND255 = (255).__and__
_SWAR = {}


def _swar_masks(n):
    m = _SWAR.get(n)
    if m is None:
        m = (int.from_bytes(b"\x7f" * n, "little"), int.from_bytes(b"\x80" * n, "little"))
        _SWAR[n] = m
    return m


def _unfilter_row(ftype, filt, prev, bpp):
    """Reconstructs one PNG scanline. filt/prev are bytes-like of equal length."""
    n = len(filt)
    if ftype == 0:
        return bytes(filt)
    if ftype == 1:  # Sub: running sum per channel, all in C via accumulate + map
        out = bytearray(n)
        for c in range(bpp):
            out[c::bpp] = bytes(map(_AND255, itertools.accumulate(filt[c::bpp])))
        return bytes(out)
    if ftype == 2:  # Up: byte-wise addition of two rows with big-int SWAR arithmetic
        lo, hi = _swar_masks(n)
        a = int.from_bytes(filt, "little")
        b = int.from_bytes(prev, "little")
        return (((a & lo) + (b & lo)) ^ ((a ^ b) & hi)).to_bytes(n, "little")
    out = bytearray(n)
    if ftype == 3:  # Average
        for i in range(min(bpp, n)):
            out[i] = (filt[i] + (prev[i] >> 1)) & 255
        for i in range(bpp, n):
            out[i] = (filt[i] + ((out[i - bpp] + prev[i]) >> 1)) & 255
        return bytes(out)
    if ftype == 4:  # Paeth
        for i in range(min(bpp, n)):
            out[i] = (filt[i] + prev[i]) & 255
        for i in range(bpp, n):
            a = out[i - bpp]
            b = prev[i]
            c = prev[i - bpp]
            pa = b - c if b > c else c - b
            pb = a - c if a > c else c - a
            pc = a + b - c - c
            if pc < 0:
                pc = -pc
            if pa <= pb and pa <= pc:
                p = a
            elif pb <= pc:
                p = b
            else:
                p = c
            out[i] = (filt[i] + p) & 255
        return bytes(out)
    raise ValueError(f"bad PNG filter type {ftype}")


def _unfilter(data, pos, w, h, bits_pp):
    """Returns (list of reconstructed rows, new position)."""
    stride = (w * bits_pp + 7) // 8
    bpp = max(1, bits_pp // 8)
    rows = []
    prev = bytes(stride)
    for _ in range(h):
        ftype = data[pos]
        row = _unfilter_row(ftype, data[pos + 1:pos + 1 + stride], prev, bpp)
        if len(row) != stride:
            raise ValueError("truncated PNG image data")
        rows.append(row)
        prev = row
        pos += 1 + stride
    return rows, pos


def _samples(row, w, depth, channels):
    """Row bytes -> bytes of 8-bit samples (depth 16: high byte, depth < 8: unpacked, NOT scaled)."""
    n = w * channels
    if depth == 8:
        return bytes(row[:n])
    if depth == 16:
        return bytes(row[0:2 * n:2])
    per = 8 // depth
    mask = (1 << depth) - 1
    out = bytearray(n)
    for i in range(n):
        out[i] = (row[i // per] >> (8 - depth - (i % per) * depth)) & mask
    return bytes(out)


def _to_rgba(samples, w, ctype, depth, plte, trns, raw_row=None):
    """8-bit samples of one row -> RGBA8 bytes."""
    out = bytearray(w * 4)
    if ctype == 6:
        return samples
    if ctype == 2:
        out[0::4] = samples[0::3]
        out[1::4] = samples[1::3]
        out[2::4] = samples[2::3]
        out[3::4] = b"\xff" * w
        if trns is not None and len(trns) >= 6:
            key = struct.unpack(">HHH", trns[:6])
            if depth == 16:
                vals = struct.unpack(f">{w * 3}H", raw_row[:w * 6])
                for x in range(w):
                    if vals[3 * x:3 * x + 3] == key:
                        out[4 * x + 3] = 0
            else:
                for x in range(w):
                    if (samples[3 * x], samples[3 * x + 1], samples[3 * x + 2]) == key:
                        out[4 * x + 3] = 0
        return bytes(out)
    if ctype in (0, 4):
        g = samples[0::2] if ctype == 4 else samples
        if depth < 8:
            scale = 255 // ((1 << depth) - 1)
            g = bytes(v * scale for v in g)
        out[0::4] = g
        out[1::4] = g
        out[2::4] = g
        if ctype == 4:
            out[3::4] = samples[1::2]
        else:
            out[3::4] = b"\xff" * w
            if trns is not None and len(trns) >= 2:
                key = struct.unpack(">H", trns[:2])[0]
                if depth == 16:
                    vals = struct.unpack(f">{w}H", raw_row[:w * 2])
                else:
                    vals = samples  # unscaled samples compare with the key directly
                for x in range(w):
                    if vals[x] == key:
                        out[4 * x + 3] = 0
        return bytes(out)
    if ctype == 3:
        if plte is None:
            raise ValueError("palette PNG without PLTE")
        n = len(plte) // 3
        tr = [plte[3 * i] if i < n else 0 for i in range(256)]
        tg = [plte[3 * i + 1] if i < n else 0 for i in range(256)]
        tb = [plte[3 * i + 2] if i < n else 0 for i in range(256)]
        ta = [255] * 256
        if trns is not None:
            for i, a in enumerate(trns[:256]):
                ta[i] = a
        out[0::4] = samples.translate(bytes(tr))
        out[1::4] = samples.translate(bytes(tg))
        out[2::4] = samples.translate(bytes(tb))
        out[3::4] = samples.translate(bytes(ta))
        return bytes(out)
    raise ValueError(f"bad PNG colour type {ctype}")


def read_png(path):
    """Decodes a PNG file. Returns (width, height, RGBA8 bytes), unpremultiplied, top row first."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != PNG_SIG:
        raise ValueError("not a PNG file")
    pos = 8
    ihdr = None
    plte = trns = None
    idat = []
    while pos + 8 <= len(data):
        length, ctype = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", body)
        elif ctype == b"PLTE":
            plte = body
        elif ctype == b"tRNS":
            trns = body
        elif ctype == b"IDAT":
            idat.append(body)
        elif ctype == b"IEND":
            break
    if ihdr is None or not idat:
        raise ValueError("PNG without IHDR/IDAT")
    w, h, depth, ctype, comp, filt, interlace = ihdr
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(ctype)
    if channels is None or comp != 0 or filt != 0 or interlace not in (0, 1):
        raise ValueError(f"unsupported PNG (colour type {ctype}, interlace {interlace})")
    if depth not in (1, 2, 4, 8, 16) or (ctype in (2, 4, 6) and depth < 8) or (ctype == 3 and depth > 8):
        raise ValueError(f"bad PNG bit depth {depth} for colour type {ctype}")
    if ctype in (4, 6):
        trns = None
    raw = zlib.decompress(b"".join(idat))
    bits_pp = channels * depth

    def row_rgba(row, width):
        return _to_rgba(_samples(row, width, depth, channels), width, ctype, depth, plte, trns, row)

    if interlace == 0:
        rows, _ = _unfilter(raw, 0, w, h, bits_pp)
        return w, h, b"".join(row_rgba(r, w) for r in rows)

    # Adam7
    out = bytearray(w * h * 4)
    pos = 0
    for (x0, y0, dx, dy) in ((0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4),
                             (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2)):
        pw = (w - x0 + dx - 1) // dx if w > x0 else 0
        ph = (h - y0 + dy - 1) // dy if h > y0 else 0
        if pw == 0 or ph == 0:
            continue
        rows, pos = _unfilter(raw, pos, pw, ph, bits_pp)
        for j, r in enumerate(rows):
            px = row_rgba(r, pw)
            y = y0 + j * dy
            for i in range(pw):
                o = (y * w + x0 + i * dx) * 4
                out[o:o + 4] = px[4 * i:4 * i + 4]
    return w, h, bytes(out)


# --------------------------------------------------------------------------------------------
# Luau output helpers
# --------------------------------------------------------------------------------------------
def lua_str(s):
    out = ['"']
    for ch in s:
        o = ord(ch)
        if ch == '"' or ch == "\\":
            out.append("\\" + ch)
        elif o < 32 or o == 127:
            out.append("\\%03d" % o)
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def lua_unescape(s):
    return re.sub(r"\\(.)", r"\1", s)


def module_source(key, w, h, z_b64, sha1):
    return (f"-- pack_assets v{PACK_VERSION} png-sha1={sha1} -- generated by roblox/tools/pack_assets.py, do not edit\n"
            f"return {{ key = {lua_str(key)}, w = {w}, h = {h}, z = \"{z_b64}\" }}\n")


def parse_module(text):
    """Returns (version, sha1, key, w, h, z) from a generated module, or None."""
    lines = text.split("\n", 1)
    m = HEADER_RE.match(lines[0])
    if not m or len(lines) < 2:
        return None
    body = re.match(r'return \{ key = "((?:[^"\\]|\\.)*)", w = (\d+), h = (\d+), z = "([A-Za-z0-9+/=]*)" \}', lines[1])
    if not body:
        return None
    return (int(m.group(1)), m.group(2), lua_unescape(body.group(1)), int(body.group(2)), int(body.group(3)),
            body.group(4))


def write_if_changed(path, text):
    data = text.encode("utf-8")
    try:
        with open(path, "rb") as f:
            if f.read() == data:
                return False
    except FileNotFoundError:
        pass
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(data)
    os.replace(tmp, path)
    return True


# --------------------------------------------------------------------------------------------
# Packing
# --------------------------------------------------------------------------------------------
def encode_png(path):
    """Worker: PNG file -> (w, h, raw length, zlib length, base64 text)."""
    w, h, rgba = read_png(path)
    comp = zlib.compress(rgba, 9)
    return w, h, len(rgba), len(comp), base64.b64encode(comp).decode("ascii")


def sha1_file(path):
    with open(path, "rb") as f:
        return hashlib.sha1(f.read()).hexdigest()


def read_asset_ids(path):
    ids = {}
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except FileNotFoundError:
        return ids
    for m in ID_RE.finditer(text):
        ids[lua_unescape(m.group(1))] = int(m.group(2))
    return ids


def asset_ids_source(ids):
    lines = [
        "-- AssetIds : ids des images envoyées sur Roblox (clé -> id). 0 = pas encore envoyée : l'image",
        "-- est alors décodée depuis ReplicatedStorage.Shared.ImageData au lancement (EditableImage).",
        "-- Rempli automatiquement par roblox/tools/UploadImages.lua (à coller dans la barre de commande",
        "-- de Roblox Studio). pack_assets.py régénère la liste des clés et garde les ids non nuls.",
        "return {",
    ]
    for key in sorted(ids):
        lines.append(f"\t[{lua_str(key)}] = {ids[key]},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def index_source(index):
    lines = [
        "-- generated by roblox/tools/pack_assets.py, do not edit",
        "-- asset key -> name of the ModuleScript in this folder (ReplicatedStorage.Shared.ImageData)",
        "return {",
    ]
    for key in sorted(index):
        lines.append(f"\t[{lua_str(key)}] = {lua_str(index[key])},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def valid_stem(stem):
    if not stem or stem in ("_index", "init") or stem.endswith((".server", ".client")):
        return False
    return re.fullmatch(r"[A-Za-z0-9_\-.]+", stem) is not None


def human(n):
    return f"{n / 1048576:.2f} MB" if n >= 1048576 else f"{n / 1024:.1f} KB"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--assets", default=os.path.join(ROBLOX, "assets"), help="folder with manifest.json and png/")
    ap.add_argument("--out", default=os.path.join(ROBLOX, "src", "shared", "ImageData"), help="ImageData folder")
    ap.add_argument("--ids", default=os.path.join(ROBLOX, "src", "shared", "AssetIds.lua"), help="AssetIds.lua path")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 1, help="parallel PNG decoders")
    ap.add_argument("--force", action="store_true", help="re-encode every image even if its PNG is unchanged")
    ap.add_argument("--top", type=int, default=15, help="number of largest modules listed in the report")
    args = ap.parse_args(argv)

    manifest_path = os.path.join(args.assets, "manifest.json")
    png_dir = os.path.join(args.assets, "png")
    try:
        with open(manifest_path, encoding="utf-8") as f:
            manifest = json.load(f)
    except FileNotFoundError:
        print(f"error: {manifest_path} not found (run the exporter first)", file=sys.stderr)
        return 2
    os.makedirs(args.out, exist_ok=True)

    errors = []
    items = []  # (key, stem, png path, manifest w, manifest h)
    stems = {}
    for key in sorted(manifest):
        entry = manifest[key]
        fname = entry.get("file") or (key.replace(":", "__") + ".png")
        stem = fname[:-4] if fname.lower().endswith(".png") else fname
        if not valid_stem(stem):
            errors.append(f"{key}: unusable module name '{stem}'")
            continue
        if stem in stems:
            errors.append(f"{key}: module name '{stem}' already used by {stems[stem]}")
            continue
        path = os.path.join(png_dir, fname)
        if not os.path.isfile(path):
            errors.append(f"{key}: missing {path}")
            continue
        stems[stem] = key
        items.append((key, stem, path, entry.get("w"), entry.get("h")))

    # reuse modules whose PNG did not change
    results = {}  # key -> (w, h, rawlen, zlen, b64, sha1)
    todo = []
    for key, stem, path, mw, mh in items:
        sha1 = sha1_file(path)
        mod_path = os.path.join(args.out, stem + ".lua")
        cached = None
        if not args.force and os.path.isfile(mod_path):
            with open(mod_path, encoding="utf-8") as f:
                cached = parse_module(f.read())
        if cached and cached[0] == PACK_VERSION and cached[1] == sha1 and cached[2] == key:
            _, _, _, w, h, z = cached
            zlen = len(base64.b64decode(z))
            results[key] = (w, h, w * h * 4, zlen, z, sha1)
        else:
            todo.append((key, path, sha1))

    if todo:
        print(f"encoding {len(todo)} image(s) ({len(items) - len(todo)} unchanged)...")
        if args.jobs > 1 and len(todo) > 1:
            with ProcessPoolExecutor(max_workers=min(args.jobs, len(todo))) as ex:
                futures = {key: ex.submit(encode_png, path) for key, path, _ in todo}
                outs = {}
                for key, fut in futures.items():
                    try:
                        outs[key] = fut.result()
                    except Exception as e:  # noqa: BLE001 - report and continue
                        outs[key] = e
        else:
            outs = {}
            for key, path, _ in todo:
                try:
                    outs[key] = encode_png(path)
                except Exception as e:  # noqa: BLE001
                    outs[key] = e
        for key, path, sha1 in todo:
            r = outs[key]
            if isinstance(r, Exception):
                errors.append(f"{key}: cannot decode {path}: {r}")
                continue
            results[key] = r + (sha1,)
    else:
        print(f"all {len(items)} image(s) unchanged")

    # validate sizes and write modules
    index = {}
    written = 0
    for key, stem, path, mw, mh in items:
        if key not in results:
            continue
        w, h, rawlen, zlen, z, sha1 = results[key]
        if w > MAX_SIDE or h > MAX_SIDE or w < 1 or h < 1:
            errors.append(f"{key}: {w}x{h} exceeds the {MAX_SIDE}px EditableImage limit, skipped")
            del results[key]
            continue
        if (mw, mh) != (w, h):
            print(f"warning: {key}: manifest says {mw}x{mh}, PNG is {w}x{h} (using the PNG size)")
        if write_if_changed(os.path.join(args.out, stem + ".lua"), module_source(key, w, h, z, sha1)):
            written += 1
        index[key] = stem

    # delete stale modules
    keep = set(index.values()) | {"_index"}
    removed = []
    for name in sorted(os.listdir(args.out)):
        base, ext = os.path.splitext(name)
        if ext in (".lua", ".luau") and base not in keep:
            os.remove(os.path.join(args.out, name))
            removed.append(name)
        elif name.endswith(".lua.tmp"):
            os.remove(os.path.join(args.out, name))
    idx_changed = write_if_changed(os.path.join(args.out, "_index.lua"), index_source(index))

    # AssetIds: every key, keeping non-zero ids (also for keys no longer in the manifest)
    old_ids = read_asset_ids(args.ids)
    ids = {key: 0 for key in index}
    for key, v in old_ids.items():
        if v != 0:
            ids[key] = v
    ids_changed = write_if_changed(args.ids, asset_ids_source(ids))

    # size report
    rows = sorted(((results[k][4].__len__(), k) for k in index), reverse=True)
    tot_raw = sum(results[k][2] for k in index)
    tot_z = sum(results[k][3] for k in index)
    tot_b64 = sum(len(results[k][4]) for k in index)
    print()
    print(f"{'largest modules':34s} {'size':>9s} {'RGBA':>10s} {'zlib':>10s} {'module':>10s} {'ratio':>6s}")
    for n, k in rows[:args.top]:
        w, h, rawlen, zlen, _, _ = results[k]
        print(f"  {k:32s} {f'{w}x{h}':>9s} {human(rawlen):>10s} {human(zlen):>10s} {human(n):>10s} {rawlen / max(1, zlen):5.1f}x")
    groups = {}
    for k in index:
        g = k.split(":", 1)[0] if ":" in k else k
        c = groups.setdefault(g, [0, 0, 0])
        c[0] += 1
        c[1] += results[k][2]
        c[2] += len(results[k][4])
    print(f"\n{'by prefix':34s} {'count':>9s} {'RGBA':>10s} {'module':>10s}")
    for g in sorted(groups, key=lambda g: -groups[g][2]):
        c = groups[g]
        print(f"  {g + ':':32s} {c[0]:>9d} {human(c[1]):>10s} {human(c[2]):>10s}")
    print(f"\nTOTAL {len(index)} images: RGBA {human(tot_raw)}, zlib {human(tot_z)}, "
          f"ImageData modules {human(tot_b64)} (ratio {tot_raw / max(1, tot_z):.1f}x)")
    print(f"files: {written} module(s) written, {len(removed)} stale removed"
          f"{', _index.lua updated' if idx_changed else ''}{', AssetIds.lua updated' if ids_changed else ''}")
    uploaded = sum(1 for k in index if ids.get(k, 0) != 0)
    if uploaded:
        print(f"AssetIds: {uploaded}/{len(index)} images already uploaded (ids kept)")
    if removed:
        print("removed: " + ", ".join(removed[:20]) + (" ..." if len(removed) > 20 else ""))
    if errors:
        print(f"\n{len(errors)} error(s):", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
