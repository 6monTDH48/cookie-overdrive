/* In-page renderers for the exporter (loaded after the site's data/art/stage scripts).
 * Every EXP.* function returns { w, h, b64 } where b64 is the raw RGBA8 (unpremultiplied,
 * row-major) canvas content, base64-encoded. Rendering uses the SITE'S OWN painters exposed by
 * the patched stage.js as CO._stageInternals (SI). Where the site draws a sprite inline (sun,
 * mountains, golden rays, spark/star/glow sprites) the few lines are mirrored here 1:1 at a
 * higher resolution; the stage.js function each copy mirrors is named in its comment, together with
 * the frame geometry (where the cookie centre / radius R sits in the sprite) the GUI needs.
 */
(function () {
  'use strict';
  const CO = window.CO, SI = CO._stageInternals, TAU = Math.PI * 2;
  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);

  function mk(w, h) { const c = document.createElement('canvas'); c.width = w; c.height = h || w; return c; }
  function b64(u8) { let s = ''; const CH = 0x8000; for (let i = 0; i < u8.length; i += CH) s += String.fromCharCode.apply(null, u8.subarray(i, i + CH)); return btoa(s); }
  function out(cv) { const d = cv.getContext('2d').getImageData(0, 0, cv.width, cv.height).data; return { w: cv.width, h: cv.height, b64: b64(d) }; }
  function setTime(t, hue) { window.__T = t; window.__HUE = hue; SI.set({ T: t, AT: t }); }
  /** skip the n-th (1-based) calls of ctx[method] — used to drop a single draw call of a site painter */
  function skipCalls(g, method, which) {
    const orig = g[method]; let n = 0;
    g[method] = function () { n++; if (which.includes(n)) { if (method === 'stroke' || method === 'fill') this.beginPath(); return; } return orig.apply(this, arguments); };
    return () => { g[method] = orig; };
  }
  /** paint the cached skin texture at exactly radius r instead of the next size bucket (crisper, and the
   *  pixel skin keeps whole-pixel cells: the 256 bucket has a half-pixel origin that shows seams) */
  function exactBase(r, fn) {
    const B = SI.BUCKETS, saved = B.slice(); B.length = 0; B.push(r, ...saved.filter((v) => v > r));
    try { return fn(); } finally { B.length = 0; B.push(...saved); }
  }
  function neutralFx(extra) { return Object.assign({ lx: 0, ly: 0, blink: 0, mouth: 0, fever: false, heat: 0 }, extra || {}); }
  const whiteGlow = (() => { // stage.js glowSprite(): the same 4 stops, rendered at 256 px
    const s = mk(256), g = s.getContext('2d'), gr = g.createRadialGradient(128, 128, 0, 128, 128, 128);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.2, 'rgba(255,255,255,.7)');
    gr.addColorStop(0.5, 'rgba(255,255,255,.2)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, 256, 256); return s;
  })();
  function tintedGlow(col) { const s = mk(256), g = s.getContext('2d'); g.drawImage(whiteGlow, 0, 0); g.globalCompositeOperation = 'source-in'; g.fillStyle = col; g.fillRect(0, 0, 256, 256); return s; }

  const EXP = (window.EXP = {});
  EXP.info = () => ({
    art: CO.art.names(),
    skins: CO.data.skins.map((s) => ({ id: s.id, style: s.style, pal: s.pal })),
    themes: CO.data.themes.map((t) => t.id),
    visuals: Object.fromEntries(Object.entries(CO.data.visuals).map(([k, v]) => [k, v.max || 1])),
    BODY_KEYS: SI.BODY_KEYS, TOP_KEYS: SI.TOP_KEYS, ACC: Object.keys(SI.ACC),
  });
  EXP.addSkin = (def) => { const L = CO.data.skins; const i = L.findIndex((s) => s.id === def.id); if (i >= 0) L[i] = def; else L.push(def); };

  /* ── 1. SVG art ── */
  EXP.svg = async (name, size) => {
    const svg = CO.art.svg(name); if (!svg) throw new Error('unknown art ' + name);
    const url = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg.replace('width="256" height="256"', `width="${size}" height="${size}"`));
    const im = new Image(); im.src = url; await im.decode();
    const cv = mk(size), g = cv.getContext('2d'); g.imageSmoothingQuality = 'high';
    g.drawImage(im, 0, 0, size, size);
    const r = out(cv), d = g.getImageData(0, 0, size, size).data; let edge = 0;
    for (let i = 0; i < size; i++) edge = Math.max(edge, d[i * 4 + 3], d[((size - 1) * size + i) * 4 + 3], d[(i * size) * 4 + 3], d[(i * size + size - 1) * 4 + 3]);
    r.edgeAlpha = edge; return r;
  };

  /* ── 2. cookie bodies: CO.stage.drawCookie(ctx, 320, 320, 200, {skin, t, accessories:false}) ── */
  EXP.cookie = (skinId, t, hue) => {
    setTime(t, hue); window.__seed(7);
    const cv = mk(640), g = cv.getContext('2d');
    exactBase(200, () => CO.stage.drawCookie(g, 320, 320, 200, { skin: skinId, t, accessories: false }));
    return out(cv);
  };

  /* ── 3. accessories: ACC[key](ctx, r, t, lvl, fx, skin) after translating to the centre (as drawCookie does) ── */
  EXP.acc = (key, lvl, t, hue, skinId, fxExtra) => {
    setTime(t, hue); window.__seed(11);
    const cv = mk(640), g = cv.getContext('2d'), sk = SI.skinDef(skinId || 'classic');
    g.save(); g.translate(320, 320);
    SI.ACC[key](g, 200, t, lvl, neutralFx(fxExtra), sk);
    g.restore();
    return out(cv);
  };

  /* ── 4. theme backgrounds: the site at a 1400×787.5 (16:9) desktop viewport, scaled to 1024×576 ── */
  const VW = 1400, VH = 787.5, TOP = 64, PW = clamp(VW * 0.33, 360, 470) + 22; // index.html: --top 64px, --pw clamp(360px,33vw,470px), #play right = pw+22
  const PLAY = { left: 0, top: TOP, width: VW - PW, height: VH - TOP };
  EXP.stageGeom = () => {
    const cx = PLAY.left + PLAY.width / 2, cy = PLAY.top + PLAY.height * 0.56, R = clamp(Math.min(PLAY.width, PLAY.height * 0.8) * 0.22, 60, 170);
    return { VW, VH, cx, cy, R, fx: cx / VW, fy: cy / VH, fR: R / VW };
  };
  EXP.bg = (id, t, hue, warm) => {
    const G = EXP.stageGeom(), OW = 1024, OH = 576;
    setTime(t, hue); window.__seed(99);
    SI.set({ W: VW, H: VH, CX: G.cx, CY: G.cy, R: G.R, dpr: 1, V: {} });
    SI.setPlay({ left: PLAY.left, top: PLAY.top, width: PLAY.width, height: PLAY.height, right: VW, bottom: VH }); // right=VW: no panel-side darkening
    if (id === 'matrix') SI.resetMatrix();
    // paint at the site's own CSS-pixel scale (1400×788, like a dpr-1 screen), then downscale once
    const big = mk(VW, Math.ceil(VH)), g = big.getContext('2d');
    if (id === 'matrix') { // let the rain fill the screen: warm-up steps (one mxStep per call)
      const scratch = mk(8).getContext('2d'); for (let i = 0; i < (warm || 260); i++) SI.THEMES.matrix(scratch, t, 0.061);
      SI.THEMES.matrix(g, t, 0);
    } else SI.THEMES[id](g, t, 0);
    g.setTransform(1, 0, 0, 1, 0, 0); g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
    SI.drawVignette(g);
    const cv = mk(OW, OH), o = cv.getContext('2d'); o.imageSmoothingEnabled = true; o.imageSmoothingQuality = 'high';
    o.drawImage(big, 0, 0, VW, VH, 0, 0, OW, OH);
    return out(cv);
  };

  /* ── 5. fx sprites ── */
  const FX = (EXP.fx = {});
  FX.glow = () => { const cv = mk(256); cv.getContext('2d').drawImage(whiteGlow, 0, 0); return out(cv); };
  function sparkPaths(g, outer, inner) { // stage.js sparkSprite() at 2× (128 px)
    g.save(); g.scale(2, 2);
    if (outer) {
      g.drawImage(whiteGlow, 16, 16, 32, 32);
      g.fillStyle = '#fff'; g.beginPath();
      g.moveTo(32, 2); g.quadraticCurveTo(35, 29, 62, 32); g.quadraticCurveTo(35, 35, 32, 62); g.quadraticCurveTo(29, 35, 2, 32); g.quadraticCurveTo(29, 29, 32, 2); g.fill();
    }
    if (inner) { g.fillStyle = '#fff'; g.beginPath(); g.moveTo(32, 14); g.quadraticCurveTo(33.5, 30.5, 50, 32); g.quadraticCurveTo(33.5, 33.5, 32, 50); g.quadraticCurveTo(30.5, 33.5, 14, 32); g.quadraticCurveTo(30.5, 30.5, 32, 14); g.fill(); }
    g.restore();
  }
  FX.spark = () => { const cv = mk(128); sparkPaths(cv.getContext('2d'), true, true); return out(cv); };
  FX.spark_core = () => { const cv = mk(128); sparkPaths(cv.getContext('2d'), false, true); return out(cv); };
  FX.star = () => { // stage.js star5() at 2× (128 px)
    const cv = mk(128), g = cv.getContext('2d'); g.scale(2, 2);
    const gr = g.createLinearGradient(0, 6, 0, 58); gr.addColorStop(0, '#fff3a0'); gr.addColorStop(0.5, '#ffc93c'); gr.addColorStop(1, '#e08a00');
    SI.starPath(g, 32, 34, 28, 12.5); g.fillStyle = gr; g.fill(); g.lineJoin = 'round'; g.lineWidth = 4; g.strokeStyle = SI.INK; g.stroke();
    g.fillStyle = 'rgba(255,255,255,.75)'; g.beginPath(); g.ellipse(25, 25, 6, 3, -0.6, 0, TAU); g.fill();
    return out(cv);
  };
  // drawRings(): strokeStyle col, lineWidth w, arc(rad). 'rgb' = 6 arcs of hsl(h0 + s*60, 100%, 62%).
  FX.ring = () => { const cv = mk(512), g = cv.getContext('2d'); g.strokeStyle = '#fff'; g.lineWidth = 14; g.beginPath(); g.arc(256, 256, 240, 0, TAU); g.stroke(); return out(cv); };
  FX.ring_rgb = (t, hue) => {
    setTime(t, hue); const cv = mk(512), g = cv.getContext('2d'), h0 = CO.hue(0);
    for (let s = 0; s < 6; s++) { g.strokeStyle = SI.hsl(h0 + s * 60, 100, 62); g.lineWidth = 14; g.beginPath(); g.arc(256, 256, 240, (s / 6) * TAU, ((s + 1) / 6) * TAU + 0.02); g.stroke(); }
    return out(cv);
  };
  FX.god_rays = (t, hue) => { // godRays(): len = hypot(W,H)*0.75 → 256 px; inner radius R*0.5 with the desktop R/len ratio
    setTime(t, hue); const G = EXP.stageGeom(), len = Math.hypot(G.VW, G.VH) * 0.75;
    SI.set({ W: 256 / 0.75, H: 0, CX: 256, CY: 256, R: 256 * (G.R / len) });
    const cv = mk(512), g = cv.getContext('2d'); SI.godRays(g); return out(cv);
  };
  FX.black_hole = (t, hue) => { // blackHole(): outer glow R*6 = image width
    setTime(t, hue); window.__seed(5); SI.set({ CX: 256, CY: 256, R: 512 / 6 });
    const cv = mk(512), g = cv.getContext('2d'); SI.blackHole(g); return out(cv);
  };
  FX.saturn = (t, hue, front) => { // saturn(c, front): image = 512×256, cookie centre = image centre, R = 128 (width = 4R)
    setTime(t, hue); SI.set({ CX: 256, CY: 128, R: 128 });
    const cv = mk(512, 256), g = cv.getContext('2d'); SI.saturn(g, front); return out(cv);
  };
  FX.disco_ball = (t, hue) => { // discoBall(): r = 42 at play (0,0,100,100) → ball centre (44,46); scaled so r = 111 px; string + glow dropped
    setTime(t, hue); SI.set({ R: 150 }); SI.setPlay({ left: 0, top: 0, width: 100, height: 100, right: 100, bottom: 100 });
    const cv = mk(256), g = cv.getContext('2d'), k = 111 / 42;
    g.setTransform(k, 0, 0, k, 128 - 44 * k, 128 - 46 * k);
    const u1 = skipCalls(g, 'stroke', [1]), u2 = skipCalls(g, 'drawImage', [1]);
    SI.discoBall(g); u1(); u2();
    return out(cv);
  };
  FX.sun_synthwave = (t) => { // THEMES.synthwave sun disc, stripes cut out (transparent) instead of painted with the sky
    const cv = mk(512), g = cv.getContext('2d'), sr = 255, sx = 256, sy = 256;
    g.beginPath(); g.arc(sx, sy, sr, 0, TAU);
    const gr = g.createLinearGradient(0, sy - sr, 0, sy + sr * 0.45); gr.addColorStop(0, '#fff45c'); gr.addColorStop(0.5, '#ffa02e'); gr.addColorStop(1, '#ff2d8e');
    g.fillStyle = gr; g.fill();
    const per = sr * 0.13, off = (t * 10 * (sr / (Math.min(VW, VH) * 0.22))) % per; // same stripe phase as the stage at time t
    g.globalCompositeOperation = 'destination-out'; g.beginPath();
    for (let y = sy - sr * 0.4 + off; y < sy + sr; y += per) { const kk = clamp((y - (sy - sr * 0.4)) / (sr * 0.9), 0, 1); g.rect(sx - sr, y, sr * 2, per * (0.1 + 0.55 * kk)); }
    g.fill();
    return out(cv);
  };
  FX.mountains_synthwave = (hue) => { // THEMES.synthwave mountain silhouette + glowing edge, full width, horizon = bottom row
    setTime(0, hue);
    const G = EXP.stageGeom(), W = G.VW, H = G.VH, hz = H * 0.63, CX = G.cx, h0 = CO.hue(0);
    const OW = 512, OH = 48, s = OW / W, top = hz - OH / s;
    const cv = mk(OW, OH), g = cv.getContext('2d'); g.setTransform(s, 0, 0, s, 0, -top * s);
    g.fillStyle = '#1b0634'; g.beginPath(); g.moveTo(0, hz);
    for (let i = 0; i <= 40; i++) { const x = (i / 40) * W, dist = Math.abs(x - CX) / (W * 0.5); g.lineTo(x, hz - SI.MOUNT[i] * H * 0.09 * (0.25 + dist)); }
    g.lineTo(W, hz); g.closePath(); g.fill();
    g.save(); g.globalCompositeOperation = 'lighter'; g.strokeStyle = SI.hsl(h0 + 300, 100, 60, 0.55); g.lineWidth = 1.5; g.stroke(); g.restore();
    return out(cv);
  };
  FX.fire_aura = (lvl, steps) => { // fireUpdate()/fireDraw() simulated around a cookie of R = 150 site px, drawn with R = 128 px
    setTime(0, 0); window.__seed(21 + lvl);
    const k = 128 / 150, C = 256 / k;
    SI.set({ CX: C, CY: C, R: 150, V: { fire_aura: lvl }, pm: 1, heat: 0 }); SI.ck.drawR = 150; SI.FIRE.length = 0;
    for (let i = 0; i < (steps || 150); i++) SI.fireUpdate(1 / 60);
    const cv = mk(512), g = cv.getContext('2d'); g.setTransform(k, 0, 0, k, 0, 0); SI.fireDraw(g);
    SI.FIRE.length = 0; SI.set({ V: {} });
    return out(cv);
  };
  FX.fire = () => { // one fire_aura particle integrated over its life (colour by life: FIRE_COLS, size s*(0.4+k*0.8))
    const W = 128, H = 256, cv = mk(W, H), g = cv.getContext('2d'); g.globalCompositeOperation = 'lighter';
    const cols = ['#ff2b2b', '#ff5a00', '#ff9a1f', '#ffd23c'].map(tintedGlow), s = 92, life = 0.85;
    let x = W / 2, y = H - s * 0.55, vy = -150; const dt = 1 / 240;
    for (let t = 0; t < life; t += dt) {
      const kk = clamp((life - t) / life, 0, 1), sz = s * (0.4 + kk * 0.8);
      g.globalAlpha = Math.min(1, kk * 1.6) * 0.8 * 0.05;
      g.drawImage(cols[Math.min(3, (kk * 4) | 0)], x - sz / 2, y - sz / 2, sz, sz);
      y += vy * dt; vy -= 60 * dt;
    }
    return out(cv);
  };
  FX.lightning = (t) => { // lightning(): 8 live bolts around a cookie of R = 120 at the centre
    setTime(t, 0); window.__seed(33); SI.set({ CX: 256, CY: 256, R: 120, V: { lightning: 1 }, heat: 0 }); SI.BOLTS.length = 0; SI.ck.s = 1;
    const scratch = mk(8).getContext('2d'); for (let i = 0; i < 8; i++) SI.lightning(scratch, 1);
    const cv = mk(512), g = cv.getContext('2d'); SI.lightning(g, 0); SI.BOLTS.length = 0; SI.set({ V: {} });
    return out(cv);
  };
  FX.bolt = (col) => { // one bolt as lightning() strokes it (glow 7 px @30 %, core 2.4 px, white 1 px), at 2×, left→right
    window.__seed(col === '#1ff4ff' ? 3 : 4);
    const W = 256, H = 64, cv = mk(W, H), g = cv.getContext('2d'); g.scale(2, 2);
    g.globalCompositeOperation = 'lighter'; g.lineJoin = 'round'; g.lineCap = 'round'; g.beginPath();
    const n = 8, x0 = 6, x1 = W / 2 - 6, jit = 120 * 0.07;
    for (let j = 0; j <= n; j++) { const k = j / n, jj = j === 0 || j === n ? 0 : jit; const x = x0 + (x1 - x0) * k + (Math.random() * 2 - 1) * jj * 0.5, y = H / 4 + (Math.random() * 2 - 1) * jj; j ? g.lineTo(x, y) : g.moveTo(x, y); }
    g.strokeStyle = col; g.globalAlpha = 0.3; g.lineWidth = 7; g.stroke();
    g.globalAlpha = 1; g.lineWidth = 2.4; g.stroke(); g.strokeStyle = '#ffffff'; g.lineWidth = 1; g.stroke();
    return out(cv);
  };
  FX.shadow = () => { // drawMainCookie() drop shadow: radial rgba(0,0,0,.5) from 0.4R to 1.15R; image = 2.3R wide, R = 111.3
    const cv = mk(256), g = cv.getContext('2d'), R = 128 / 1.15;
    const sg = g.createRadialGradient(128, 128, R * 0.4, 128, 128, R * 1.15); sg.addColorStop(0, 'rgba(0,0,0,.5)'); sg.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = sg; g.beginPath(); g.arc(128, 128, R * 1.15, 0, TAU); g.fill(); return out(cv);
  };
  FX.silhouette = (diamond) => { // bodyPath(): same relative frame as cookie:* (r = 0.3125 × size)
    const cv = mk(512), g = cv.getContext('2d'); g.translate(256, 256); g.fillStyle = '#fff';
    SI.bodyPath(g, 160, { style: diamond ? 'diamond' : 'classic' }, 1); g.fill(); return out(cv);
  };
  FX.golden_rays = (t) => { // goldensDraw() rays + glow without the cookie; r = 40 → rays reach 3.2r = 128 = image edge
    setTime(t, 0); const cv = mk(256), g = cv.getContext('2d'), r = 40, T = t, AT = t;
    g.translate(128, 128); g.rotate(AT * 0.7); g.globalCompositeOperation = 'lighter';
    const rg = g.createRadialGradient(0, 0, r * 0.6, 0, 0, r * 3.2); rg.addColorStop(0, 'rgba(255,220,90,.55)'); rg.addColorStop(1, 'rgba(255,220,90,0)');
    g.fillStyle = rg; g.beginPath();
    for (let k = 0; k < 10; k++) { const an = (k / 10) * TAU; g.moveTo(0, 0); g.arc(0, 0, r * 3.2, an - 0.12, an + 0.12); g.closePath(); }
    g.fill(); g.globalAlpha = 0.7 + 0.2 * Math.sin(T * 5); const gs = r * 4.2; g.drawImage(tintedGlow('#ffc93c'), -gs / 2, -gs / 2, gs, gs);
    return out(cv);
  };
  FX.wing = (side, hue) => { // ACC.wings(): one wing, its root (±0.7r, -0.12r) at the image centre, flap = 0, r = 176
    setTime(0, hue); const r = 176, cv = mk(512), g = cv.getContext('2d'), sk = SI.skinDef('classic');
    const cx = 256 - side * 0.7 * r, cy = 256 + 0.12 * r; // cookie centre in image space
    g.save(); g.beginPath(); if (side > 0) g.rect(cx, 0, 512 - cx, 512); else g.rect(0, 0, cx, 512); g.clip();
    g.translate(cx, cy); SI.ACC.wings(g, r, 0, 1, neutralFx(), sk); g.restore();
    return out(cv);
  };
  FX.candy = (i) => { const src = SI.candySprites()[i], cv = mk(src.width, src.height); cv.getContext('2d').drawImage(src, 0, 0); return out(cv); };

  /* ── 6. golden cookie exactly as goldensDraw() paints it (cookie r = 40, rays 3.2r = image edge) ── */
  EXP.golden = (t) => {
    setTime(t, 0); window.__seed(1);
    SI.set({ R: 150, W: 256, H: 256, CX: 128, CY: 128 }); SI.setPlay({ left: 0, top: 0, width: 256, height: 256, right: 256, bottom: 256 });
    CO.golden.list = [{ id: 0, x: 0.5, y: 0.5, born: t - 100, life: 1e9 }];
    const cv = mk(256), g = cv.getContext('2d'); exactBase(40, () => SI.goldensDraw(g));
    CO.golden.list = [];
    return out(cv);
  };

  /* ── QA helpers ── */
  EXP.sheet = async (items, cell, cols, bg) => { // items: [{b64? url, label}] → contact sheet PNG data URL
    const rows = Math.ceil(items.length / cols), cv = mk(cols * cell, rows * (cell + 16)), g = cv.getContext('2d');
    g.fillStyle = bg || '#0b0620'; g.fillRect(0, 0, cv.width, cv.height);
    for (let i = 0; i < items.length; i++) {
      const it = items[i], im = new Image(); im.src = it.url; await im.decode();
      const x = (i % cols) * cell, y = Math.floor(i / cols) * (cell + 16), sc = Math.min(cell / im.width, cell / im.height);
      g.drawImage(im, x + (cell - im.width * sc) / 2, y + (cell - im.height * sc) / 2, im.width * sc, im.height * sc);
      g.fillStyle = '#fff'; g.font = '11px sans-serif'; g.textAlign = 'center'; g.fillText(it.label, x + cell / 2, y + cell + 12);
    }
    return cv.toDataURL('image/png');
  };
})();
