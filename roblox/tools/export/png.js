/* Minimal PNG writer (RGBA8, non-interlaced) + alpha bleeding, no dependencies.
 *
 *   encodeRGBA(width, height, rgbaBuffer) -> Buffer (PNG file)
 *   bleedAlpha(width, height, rgbaBuffer, passes) -> mutates buffer in place
 *
 * Output is always colour type 6 (RGBA, 8 bit, unpremultiplied) so any PNG reader used by
 * the packer (roblox/tools/pack_assets.py) only has to support one layout.
 * Several row-filter / zlib-strategy combinations are tried and the smallest file is kept.
 */
'use strict';
const zlib = require('zlib');

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td), 0);
  return Buffer.concat([len, td, crc]);
}

function paeth(a, b, c) {
  const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
  return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
}

/** Filter every row with `mode` (0–4) or, for 'adaptive', the filter with the smallest sum of |values|. */
function filterRows(w, h, rgba, mode) {
  const bpp = 4, stride = w * bpp, out = Buffer.alloc((stride + 1) * h), zero = Buffer.alloc(stride);
  const tmp = Buffer.alloc(stride), modes = mode === 'adaptive' ? [0, 1, 2, 3, 4] : [mode];
  for (let y = 0; y < h; y++) {
    const row = rgba.subarray(y * stride, (y + 1) * stride), prev = y ? rgba.subarray((y - 1) * stride, y * stride) : zero;
    let best = -1, bestSum = Infinity;
    for (const f of modes) {
      let sum = 0;
      for (let i = 0; i < stride; i++) {
        const a = i >= bpp ? row[i - bpp] : 0, b = prev[i], c = i >= bpp ? prev[i - bpp] : 0, x = row[i];
        const v = (f === 0 ? x : f === 1 ? x - a : f === 2 ? x - b : f === 3 ? x - ((a + b) >> 1) : x - paeth(a, b, c)) & 0xff;
        tmp[i] = v; sum += v < 128 ? v : 256 - v;
        if (sum >= bestSum) break;
      }
      if (sum < bestSum) { bestSum = sum; best = f; tmp.copy(out, y * (stride + 1) + 1); }
    }
    out[y * (stride + 1)] = best;
  }
  return out;
}

// (row filter, zlib strategy) pairs tried for every image; the smallest stream wins (lossless either way)
const TRIALS = [['adaptive', 0], ['adaptive', 1], [0, 0], [1, 1], [2, 1]]; // strategy 0 = default, 1 = Z_FILTERED

function encodeRGBA(w, h, rgba) {
  if (rgba.length !== w * h * 4) throw new Error(`encodeRGBA: buffer ${rgba.length} != ${w}*${h}*4`);
  let idat = null;
  for (const [mode, strategy] of TRIALS) {
    const z = zlib.deflateSync(filterRows(w, h, rgba, mode), { level: 9, memLevel: 9, strategy });
    if (!idat || z.length < idat.length) idat = z;
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr), chunk('IDAT', idat), chunk('IEND', Buffer.alloc(0)),
  ]);
}

/** Alpha bleeding: every fully transparent pixel within `passes` px (4-neighbour distance) of a visible
 *  one takes the RGB of its nearest visible neighbour (alpha stays 0), so Roblox's bilinear filtering /
 *  mipmaps don't pull black into the edges. Copying (not averaging) keeps long runs → cheap in PNG. */
function bleedAlpha(w, h, rgba, passes) {
  const n = w * h, known = new Uint8Array(n);
  for (let i = 0; i < n; i++) known[i] = rgba[i * 4 + 3] > 0 ? 1 : 0;
  let frontier = [];
  for (let i = 0; i < n; i++) if (!known[i]) {
    const x = i % w, y = (i / w) | 0;
    if ((x > 0 && known[i - 1]) || (y > 0 && known[i - w]) || (x < w - 1 && known[i + 1]) || (y < h - 1 && known[i + w])) frontier.push(i);
  }
  for (let p = 0; p < passes && frontier.length; p++) {
    const src = new Int32Array(frontier.length);
    for (let f = 0; f < frontier.length; f++) {
      const i = frontier[f], x = i % w, y = (i / w) | 0; let j = -1;
      if (x > 0 && known[i - 1] === 1) j = i - 1;
      else if (y > 0 && known[i - w] === 1) j = i - w;
      else if (x < w - 1 && known[i + 1] === 1) j = i + 1;
      else if (y < h - 1 && known[i + w] === 1) j = i + w;
      src[f] = j;
    }
    const next = [];
    for (let f = 0; f < frontier.length; f++) {
      const i = frontier[f], j = src[f]; if (j < 0) continue;
      rgba[i * 4] = rgba[j * 4]; rgba[i * 4 + 1] = rgba[j * 4 + 1]; rgba[i * 4 + 2] = rgba[j * 4 + 2];
    }
    for (let f = 0; f < frontier.length; f++) if (src[f] >= 0) known[frontier[f]] = 1;
    for (let f = 0; f < frontier.length; f++) {
      const i = frontier[f]; if (src[f] < 0) continue; const x = i % w, y = (i / w) | 0;
      if (x > 0 && !known[i - 1]) { known[i - 1] = 2; next.push(i - 1); }
      if (y > 0 && !known[i - w]) { known[i - w] = 2; next.push(i - w); }
      if (x < w - 1 && !known[i + 1]) { known[i + 1] = 2; next.push(i + 1); }
      if (y < h - 1 && !known[i + w]) { known[i + w] = 2; next.push(i + w); }
    }
    for (const j of next) known[j] = 0;
    frontier = next;
  }
}

module.exports = { encodeRGBA, bleedAlpha, crc32 };
