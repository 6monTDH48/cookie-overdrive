#!/usr/bin/env node
/* Cookie Overdrive → Roblox PNG exporter.
 *
 *   node roblox/tools/export/export.js            (from the repo root, or any cwd)
 *   node roblox/tools/export/export.js --qa=DIR   (also writes contact sheets to DIR for eyeballing)
 *
 * Renders every image the Roblox port needs (see roblox/CONTRACT.md §1–2) with the WEBSITE'S OWN
 * drawing code in headless Chromium: source/src/js/{data,art,art-world,art-pets}.js + a patched copy of
 * stage.js that exposes its private painters as CO._stageInternals. Output:
 *   roblox/assets/png/<key with ':' → '__'>.png   (RGBA8 PNG, alpha-bled, deterministic)
 *   roblox/assets/manifest.json                    { key: { file, w, h } }
 * The PNG folder is wiped first, so the manifest always lists exactly the files on disk.
 *
 * Takes ~2 min. Needs the `playwright` node module (resolved from $PLAYWRIGHT_MODULE, a normal
 * require(), ./node_modules, then the session scratchpad install) and Chromium ($CHROME_PATH, default
 * /opt/pw-browsers/chromium-1194/…, else Playwright's own). Fonts (Lilita One, Chakra Petch — only the
 * bling medal text and the matrix rain use text) are vendored in ./fonts, so it runs offline.
 * Files: page-core.js (frozen-time CO stub), page-render.js (all renderers + the frame geometry of every
 * fx sprite, in comments), png.js (PNG writer + alpha bleed).
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { encodeRGBA, bleedAlpha } = require('./png');

const ROOT = path.resolve(__dirname, '../../..');
const JS = path.join(ROOT, 'source/src/js');
const OUT_DIR = path.join(ROOT, 'roblox/assets/png');
const MANIFEST = path.join(ROOT, 'roblox/assets/manifest.json');
const GAMEDATA = path.join(ROOT, 'roblox/src/shared/GameData.lua');
const CHROME = process.env.CHROME_PATH || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const QA = (process.argv.find((a) => a.startsWith('--qa=')) || '').slice(5);

function loadPlaywright() {
  const tries = [process.env.PLAYWRIGHT_MODULE, 'playwright', path.join(__dirname, 'node_modules/playwright'),
    '/tmp/claude-0/-home-user-cookie-overdrive/aed3e740-a1db-515b-a995-7f37fffe853e/scratchpad/node_modules/playwright'].filter(Boolean);
  for (const t of tries) { try { return require(t); } catch (e) { /* next */ } }
  throw new Error('playwright module not found (set PLAYWRIGHT_MODULE=/path/to/node_modules/playwright)');
}

/* ───────── what to render ───────── */
const BIG_SVG = ['pet:', 'egg:', 'boss:', 'mg:', 'item:'];          // 256 px, everything else 128 px
// Site-less skins from GameData.lua → site style used to paint them (CONTRACT §1).
const EXTRA_SKIN_STYLE = { vip: 'holo', robux: 'classic', plasma: 'rainbow' };
// Frozen time / RGB hue per skin style, picked so animated overlays read well as a still.
const SKIN_T = { classic: [0, 0], pixel: [0.1, 0], lava: [0.6, 0], galaxy: [1.1, 0], diamond: [1.6, 190], holo: [Math.PI / 18, 0],
  gold: [1.5, 0], rainbow: [Math.PI / 6, 320], void: [0.8, 0] };
const SKIN_T_ID = { plasma: [Math.PI / 6, 175] };                      // cyan → violet → pink like its palette
// Accessory stills: t = 0 (no swing / bob), laser glow at its pulse peak, holo sweep across the middle.
const ACC_T = { holo: 1.2, laser_eyes: Math.PI / 12, galaxy_core: 0.9, rgb_rim: 0.3, wings: 0.25 }; // wings: slightly raised so the tips stay inside 640 px
const ACC_HUE = 300;
const BG_T = { synthwave: [3.2, 0], galaxy: [7.3, 0], matrix: [0, 0], candy: [2.0, 0], inferno: [1.3, 0], aurora: [2.6, 0] };

function parseGameDataSkins() {
  const src = fs.readFileSync(GAMEDATA, 'utf8');
  const a = src.indexOf('D.skins = {'); if (a < 0) throw new Error('D.skins not found in GameData.lua');
  const b = src.indexOf('\n}', a);
  const out = [];
  for (const line of src.slice(a, b).split('\n')) {
    const id = /\bid\s*=\s*"([^"]+)"/.exec(line); if (!id) continue;
    const pal = {}; let m; const re = /\b(base|dark|light|chipHi|chip|rim)\s*=\s*"(#[0-9a-fA-F]{6})"/g;
    while ((m = re.exec(line))) pal[m[1]] = m[2].toLowerCase();
    const name = /\bname\s*=\s*"([^"]+)"/.exec(line);
    out.push({ id: id[1], name: name ? name[1] : id[1], pal });
  }
  return out;
}

function patchedStage() {
  let s = fs.readFileSync(path.join(JS, 'stage.js'), 'utf8');
  // (a) BASE.holo: its hard-coded cyan/ice rgba() literals ARE the hologram palette's base/light
  //     (#39f0ff = 57,240,255 and #b7fbff = 183,251,255), so reading them from the palette renders
  //     'hologram' identically and lets the site-less VIP skin use its own pink palette.
  const h0 = s.indexOf('    holo(g, r, p, rng) {'), h1 = s.indexOf('    gold(g, r, p, rng, sk) {');
  if (h0 < 0 || h1 < h0) throw new Error('stage.js patch: BASE.holo not found');
  let holo = s.slice(h0, h1); const n0 = holo.length;
  holo = holo.replace(/'rgba\(57,240,255,(\.\d+)\)'/g, 'rgba(p.base, $1)').replace(/'rgba\(183,251,255,(\.\d+)\)'/g, 'rgba(p.light, $1)');
  if (holo.length === n0 || /57,240,255|183,251,255/.test(holo)) throw new Error('stage.js patch: holo colours not replaced');
  s = s.slice(0, h0) + holo + s.slice(h1);
  // (b) expose the private painters / state setters.
  const anchor = '  CO.stage = { init, resize, drawCookie, isOverCookie };';
  if (!s.includes(anchor)) throw new Error('stage.js patch: CO.stage anchor not found');
  const expose = `
  CO._stageInternals = {
    ACC, BODY_KEYS, TOP_KEYS, THEMES, BASE, ANIM, MOUNT, STARS, FIRE, BOLTS, INK, EYE_X, EYE_Y, ck, play, BUCKETS,
    drawBase, skinDef, shapePath, bodyPath, diamondPath, glowSprite, sparkSprite, star5, candySprites, starPath, hsl, hq,
    drawVignette, godRays, blackHole, saturn, discoBall, fireUpdate, fireDraw, lightning, goldensDraw,
    set(o) {
      if ('W' in o) W = o.W; if ('H' in o) H = o.H; if ('CX' in o) CX = o.CX; if ('CY' in o) CY = o.CY; if ('R' in o) R = o.R;
      if ('T' in o) T = o.T; if ('AT' in o) AT = o.AT; if ('dpr' in o) dpr = o.dpr; if ('V' in o) V = o.V;
      if ('pm' in o) pm = o.pm; if ('heat' in o) heat = o.heat;
    },
    setPlay(o) { Object.assign(play, o); },
    resetMatrix() { MX = null; mxAcc = 0; },
  };
`;
  return s.replace(anchor, expose + anchor);
}

function buildHtml() {
  const font = (f) => fs.readFileSync(path.join(__dirname, 'fonts', f)).toString('base64');
  const read = (f) => fs.readFileSync(f, 'utf8').replace(/<\/script/gi, '<\\/script');
  const scripts = [
    read(path.join(__dirname, 'page-core.js')),
    read(path.join(JS, 'data.js')), read(path.join(JS, 'art.js')), read(path.join(JS, 'art-world.js')), read(path.join(JS, 'art-pets.js')),
    patchedStage().replace(/<\/script/gi, '<\\/script'),
    read(path.join(__dirname, 'page-render.js')),
  ];
  return `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{font-family:'Lilita One';font-weight:400;src:url(data:font/woff2;base64,${font('LilitaOne-latin.woff2')}) format('woff2');}
@font-face{font-family:'Chakra Petch';font-weight:600;src:url(data:font/woff2;base64,${font('ChakraPetch-600-latin.woff2')}) format('woff2');}
html,body{margin:0;background:transparent}</style></head><body>
${scripts.map((s) => '<script>' + s + '</script>').join('\n')}
</body></html>`;
}

const fileOf = (key) => key.replace(/:/g, '__') + '.png';

async function main() {
  const { chromium } = loadPlaywright();
  const browser = await chromium.launch({ executablePath: fs.existsSync(CHROME) ? CHROME : undefined, args: ['--force-color-profile=srgb', '--disable-gpu'] });
  const page = await browser.newPage({ viewport: { width: 800, height: 600 }, deviceScaleFactor: 1 });
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await page.setContent(buildHtml(), { waitUntil: 'load' });
  if (errors.length) throw new Error('page errors:\n' + errors.join('\n'));
  await page.evaluate(async () => { await document.fonts.load("40px 'Lilita One'"); await document.fonts.load("600 15px 'Chakra Petch'"); await document.fonts.ready; });

  const info = await page.evaluate(() => EXP.info());
  fs.mkdirSync(OUT_DIR, { recursive: true });
  for (const f of fs.readdirSync(OUT_DIR)) if (f.endsWith('.png')) fs.unlinkSync(path.join(OUT_DIR, f));

  const manifest = {}, notes = [], sheets = {};
  let total = 0;
  async function job(key, fn, args, group) {
    const r = await page.evaluate(([fn, args]) => {
      const path = fn.split('.'); let f = window.EXP; for (const p of path) f = f[p];
      return f(...args);
    }, [fn, args]);
    if (r.w > 1024 || r.h > 1024) throw new Error(`${key}: ${r.w}×${r.h} exceeds 1024`);
    const rgba = Buffer.from(r.b64, 'base64');
    let visible = 0; for (let i = 3; i < rgba.length; i += 4) if (rgba[i]) { visible++; }
    if (!visible) throw new Error(`${key}: image is empty`);
    if (r.edgeAlpha > 0) notes.push(`${key}: art touches its 48×48 box edge (max edge alpha ${r.edgeAlpha}) — same clipping as on the site`);
    bleedAlpha(r.w, r.h, rgba, 8);
    const png = encodeRGBA(r.w, r.h, rgba), file = fileOf(key);
    fs.writeFileSync(path.join(OUT_DIR, file), png);
    manifest[key] = { file, w: r.w, h: r.h }; total += png.length;
    (sheets[group] = sheets[group] || []).push(key);
    process.stdout.write(`  ${key.padEnd(34)} ${String(r.w).padStart(4)}×${String(r.h).padEnd(4)} ${(png.length / 1024).toFixed(1).padStart(7)} KB\n`);
  }

  /* 1. SVG art */
  console.log(`SVG art (${info.art.length})`);
  for (const name of info.art) await job(name, 'svg', [name, BIG_SVG.some((p) => name.startsWith(p)) ? 256 : 128], name.split(':')[0]);

  /* 2. cookie skins (GameData order) */
  const gd = parseGameDataSkins(), siteSkins = Object.fromEntries(info.skins.map((s) => [s.id, s]));
  console.log(`cookie skins (${gd.length})`);
  for (const s of gd) {
    let style;
    if (siteSkins[s.id]) style = siteSkins[s.id].style; // site data used as-is
    else {
      style = EXTRA_SKIN_STYLE[s.id];
      if (!style) throw new Error(`skin ${s.id} is not on the site and has no style mapping`);
      for (const k of ['base', 'dark', 'light', 'chip', 'chipHi', 'rim']) if (!s.pal[k]) throw new Error(`skin ${s.id}: palette.${k} missing in GameData`);
      await page.evaluate((def) => EXP.addSkin(def), { id: s.id, name: s.name, style, pal: s.pal });
    }
    const [t, hue] = SKIN_T_ID[s.id] || SKIN_T[style] || [0, 0];
    await job('cookie:' + s.id, 'cookie', [s.id, t, hue], 'cookie');
  }

  /* 3. accessories (+ _<lvl> for max > 1) */
  const accKeys = [...info.BODY_KEYS, ...info.TOP_KEYS, 'wings'];
  console.log(`accessories (${accKeys.length} keys)`);
  for (const k of accKeys) {
    const max = info.visuals[k] || 1, t = ACC_T[k] || 0;
    for (let l = 1; l <= max; l++) await job(l === 1 ? 'acc:' + k : `acc:${k}_${l}`, 'acc', [k, l, t, ACC_HUE, 'classic', null], 'acc');
  }
  // extra stills of the face for the GUI's blink / click / fever animation
  await job('acc:face_blink', 'acc', ['face', 1, 0, ACC_HUE, 'classic', { blink: 1 }], 'acc');
  await job('acc:face_open', 'acc', ['face', 1, 0, ACC_HUE, 'classic', { mouth: 1 }], 'acc');
  await job('acc:face_fever', 'acc', ['face', 1, 0.1, ACC_HUE, 'classic', { fever: true }], 'acc');
  // chips_xl is painted with the current skin's chip colours on the site → one variant per skin
  for (const s of gd) if (s.id !== 'classic') await job('acc:chips_xl_' + s.id, 'acc', ['chips_xl', 1, 0, ACC_HUE, s.id, null], 'acc_skin');

  /* 4. theme backgrounds */
  console.log(`backgrounds (${info.themes.length})`);
  for (const id of info.themes) { const [t, hue] = BG_T[id] || [2, 0]; await job('bg:' + id, 'bg', [id, t, hue], 'bg'); }

  /* 5. fx sprites */
  console.log('fx sprites');
  await job('fx:glow', 'fx.glow', [], 'fx');
  await job('fx:spark', 'fx.spark', [], 'fx');
  await job('fx:spark_core', 'fx.spark_core', [], 'fx');
  await job('fx:star', 'fx.star', [], 'fx');
  await job('fx:ring', 'fx.ring', [], 'fx');
  await job('fx:ring_rgb', 'fx.ring_rgb', [0, 0], 'fx');
  await job('fx:god_rays', 'fx.god_rays', [0.7, 0], 'fx');
  await job('fx:black_hole', 'fx.black_hole', [1.7, 0], 'fx');
  await job('fx:saturn_back', 'fx.saturn', [0.6, 200, false], 'fx');
  await job('fx:saturn_front', 'fx.saturn', [0.6, 200, true], 'fx');
  await job('fx:disco_ball', 'fx.disco_ball', [0, 0], 'fx'); // t = 0: tiles unrotated, twinkle at its mean size (r)
  await job('fx:sun_synthwave', 'fx.sun_synthwave', [BG_T.synthwave[0]], 'fx');
  await job('fx:mountains_synthwave', 'fx.mountains_synthwave', [BG_T.synthwave[1]], 'fx');
  await job('fx:fire', 'fx.fire', [], 'fx');
  await job('fx:fire_aura', 'fx.fire_aura', [1], 'fx');
  await job('fx:fire_aura_2', 'fx.fire_aura', [2], 'fx');
  await job('fx:bolt', 'fx.bolt', ['#1ff4ff'], 'fx');
  await job('fx:bolt_violet', 'fx.bolt', ['#a57bff'], 'fx');
  await job('fx:lightning', 'fx.lightning', [0], 'fx');
  await job('fx:shadow', 'fx.shadow', [], 'fx');
  await job('fx:silhouette', 'fx.silhouette', [false], 'fx');
  await job('fx:silhouette_diamond', 'fx.silhouette', [true], 'fx');
  await job('fx:golden_rays', 'fx.golden_rays', [0], 'fx');
  await job('fx:wing_left', 'fx.wing', [-1, ACC_HUE], 'fx');
  await job('fx:wing_right', 'fx.wing', [1, ACC_HUE], 'fx');
  for (let i = 0; i < 6; i++) await job('fx:candy_' + (i + 1), 'fx.candy', [i], 'fx');

  /* 6. golden cookie */
  await job('golden', 'golden', [0], 'fx');

  if (errors.length) throw new Error('page errors:\n' + errors.join('\n'));
  const sorted = Object.fromEntries(Object.keys(manifest).sort().map((k) => [k, manifest[k]]));
  fs.writeFileSync(MANIFEST, JSON.stringify(sorted, null, 2) + '\n');

  if (QA) {
    fs.mkdirSync(QA, { recursive: true });
    for (const [group, keys] of Object.entries(sheets)) {
      const big = group === 'bg' ? 340 : group === 'cookie' || group.startsWith('acc') ? 200 : 128;
      const items = keys.map((k) => ({ url: 'data:image/png;base64,' + fs.readFileSync(path.join(OUT_DIR, manifest[k].file)).toString('base64'), label: k }));
      const cols = group === 'bg' ? 2 : Math.min(8, Math.max(4, Math.ceil(Math.sqrt(items.length))));
      for (const bg of group === 'bg' ? ['#0b0620'] : ['#0b0620', '#8a7fb0']) {
        const url = await page.evaluate(([items, big, cols, bg]) => EXP.sheet(items, big, cols, bg), [items, big, cols, bg]);
        fs.writeFileSync(path.join(QA, `sheet-${group}${bg === '#0b0620' ? '' : '-light'}.png`), Buffer.from(url.split(',')[1], 'base64'));
      }
    }
  }
  await browser.close();

  const byPrefix = {};
  for (const k of Object.keys(sorted)) { const p = k.includes(':') ? k.split(':')[0] : k; byPrefix[p] = (byPrefix[p] || 0) + 1; }
  console.log(`\n${Object.keys(sorted).length} images, ${(total / 1024 / 1024).toFixed(2)} MB → ${path.relative(ROOT, OUT_DIR)}/`);
  console.log(Object.entries(byPrefix).map(([p, n]) => `${p}: ${n}`).join(', '));
  if (notes.length) console.log('\nnotes:\n  ' + notes.join('\n  '));
}

module.exports = { buildHtml, parseGameDataSkins, loadPlaywright, CHROME };
if (require.main === module) main().catch((e) => { console.error(e.stack || String(e)); process.exit(1); });
