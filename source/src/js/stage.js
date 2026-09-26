/* COOKIE OVERDRIVE — stage.js
 * Full-screen canvas renderer: animated theme backgrounds, the big cookie with every upgrade layer,
 * particles, golden cookies, boss, pets, floating numbers, fever mode.
 * Sets CO.stage = { init(canvas), resize(), drawCookie(ctx,x,y,r,opts), isOverCookie(x,y) }.
 * No emojis anywhere: pictures come from CO.art (vector sprites) or are drawn procedurally.
 */
(function () {
  'use strict';
  const CO = (window.CO = window.CO || {});

  /* ═════════════════════════ utils ═════════════════════════ */
  const TAU = Math.PI * 2;
  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
  const lerp = (a, b, t) => a + (b - a) * t;
  const rand = (a, b) => a + Math.random() * (b - a);
  const pick = (arr) => arr[(Math.random() * arr.length) | 0];
  const easeOutCubic = (t) => 1 - Math.pow(1 - clamp(t, 0, 1), 3);
  const easeInOut = (t) => { t = clamp(t, 0, 1); return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; };
  const easeOutBack = (t) => { const s = 1.9; t = clamp(t, 0, 1) - 1; return t * t * ((s + 1) * t + s) + 1; };
  const elasticOut = (t) => { t = clamp(t, 0, 1); if (t === 0 || t === 1) return t; return Math.pow(2, -10 * t) * Math.sin(((t - 0.075) * TAU) / 0.3) + 1; };
  const bounceOut = (t) => {
    t = clamp(t, 0, 1); const n = 7.5625, d = 2.75;
    if (t < 1 / d) return n * t * t;
    if (t < 2 / d) return n * (t -= 1.5 / d) * t + 0.75;
    if (t < 2.5 / d) return n * (t -= 2.25 / d) * t + 0.9375;
    return n * (t -= 2.625 / d) * t + 0.984375;
  };
  function mulberry32(a) {
    return function () { a |= 0; a = (a + 0x6d2b79f5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  }
  const hashStr = (s) => { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; };
  const hsl = (h, s = 100, l = 60, a = 1) => (a >= 1 ? `hsl(${h | 0},${s}%,${l}%)` : `hsla(${h | 0},${s}%,${l}%,${a.toFixed(3)})`);
  const hq = (h, l = 60) => `hsl(${(((Math.round(h / 15) * 15) % 360) + 360) % 360},100%,${l}%)`; // quantised (sprite cache friendly)
  const hue = (o = 0) => (CO.hue ? CO.hue(o) : (o % 360));
  const S = () => CO.settings || (CO.state && CO.state.settings) || {};
  const DATA = () => CO.data || {};
  const INK = '#1a0b33';
  const FONT_D = '"Lilita One", "Arial Rounded MT Bold", "Trebuchet MS", sans-serif';
  const FONT_B = 'Fredoka, "Segoe UI", system-ui, sans-serif';
  const FONT_M = '"Chakra Petch", ui-monospace, Menlo, monospace';
  const mk = (w, h) => { const c = document.createElement('canvas'); c.width = Math.max(1, Math.ceil(w)); c.height = Math.max(1, Math.ceil(h || w)); return c; };
  const RGB_CACHE = new Map();
  function hexRgb(hex) {
    let v = RGB_CACHE.get(hex); if (v) return v;
    let h = hex.replace('#', ''); if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    const n = parseInt(h, 16); v = [(n >> 16) & 255, (n >> 8) & 255, n & 255]; RGB_CACHE.set(hex, v); return v;
  }
  const rgba = (hex, a) => { const v = hexRgb(hex); return `rgba(${v[0]},${v[1]},${v[2]},${a})`; };
  const mixHex = (a, b, t) => { const x = hexRgb(a), y = hexRgb(b); return `rgb(${lerp(x[0], y[0], t) | 0},${lerp(x[1], y[1], t) | 0},${lerp(x[2], y[2], t) | 0})`; };
  function rrect(c, x, y, w, h, r) {
    w = nn(w); h = nn(h); r = nn(Math.min(r, w / 2, h / 2));
    c.beginPath(); c.moveTo(x + r, y); c.arcTo(x + w, y, x + w, y + h, r); c.arcTo(x + w, y + h, x, y + h, r);
    c.arcTo(x, y + h, x, y, r); c.arcTo(x, y, x + w, y, r); c.closePath();
  }
  function starPath(c, x, y, R, r, n = 5, rot = -Math.PI / 2) {
    c.beginPath();
    for (let i = 0; i < n * 2; i++) { const a = rot + (i * Math.PI) / n, rr = i % 2 ? r : R; i ? c.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr) : c.moveTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); }
    c.closePath();
  }
  function heartPath(c, x, y, s) {
    c.beginPath(); c.moveTo(x, y + s * 0.75);
    c.bezierCurveTo(x - s * 1.25, y - s * 0.05, x - s * 0.55, y - s * 0.95, x, y - s * 0.35);
    c.bezierCurveTo(x + s * 0.55, y - s * 0.95, x + s * 1.25, y - s * 0.05, x, y + s * 0.75); c.closePath();
  }
  /* radius-safe canvas helpers (negative / NaN radii would throw IndexSizeError) */
  const nn = (v) => (v > 0 ? v : 0);
  const fin = (v) => (isFinite(v) ? v : 0);
  function radG(c, x0, y0, r0, x1, y1, r1) { r0 = nn(r0); return c.createRadialGradient(fin(x0), fin(y0), r0, fin(x1), fin(y1), Math.max(nn(r1), r0 + 0.001)); }
  function arcS(c, x, y, r, a0, a1, ccw) { c.arc(fin(x), fin(y), nn(r), fin(a0), fin(a1), !!ccw); }
  function ellS(c, x, y, rx, ry, rot, a0, a1, ccw) { c.ellipse(fin(x), fin(y), nn(rx), nn(ry), fin(rot), fin(a0), fin(a1), !!ccw); }
  const scaleOf = (c) => { if (!c.getTransform) return 1; const m = c.getTransform(); return Math.sqrt(m.a * m.a + m.b * m.b) || 1; };

  /* ═════════════════════════ stage state ═════════════════════════ */
  let cvs = null, ctx = null, W = 800, H = 600, dpr = 1, inited = false;
  const play = { left: 0, top: 0, width: 800, height: 600, right: 800, bottom: 600 };
  let CX = 400, CY = 330, R = 120;
  let T = 0, AT = 0, DT = 1 / 60;            // T = CO.now(); AT = animation clock (slowed by reducedMotion)
  let V = {};                                 // CO.vis snapshot for this frame
  let degrade = 0, degradeMul = 1, pBudget = 900, pm = 1;
  let paused = false, lastPausedDraw = 0, lastTs = 0, lastPlayRead = 0;
  let shakeAmp = 0, shx = 0, shy = 0, flash = 0, flashCol = '255,255,255';
  let feverK = 0, feverT0 = -99, bgPulse = 0, cursorTap = 0, heat = 0;
  const ptr = { x: -9999, y: -9999, on: false, t: -9, trail: [] };
  const ck = { s: 1, sv: 0, sq: 0, sqv: 0, tilt: 0, tiltv: 0, hover: 0, mouth: 0, cb: 0, cbv: 0, sw: 0, swv: 0, pulse: 0, spin: 0, spinv: 0, blink: 0, nextBlink: 2, laser: 0, drawR: 120, rot: 0 };
  const pop = {};                              // visual key → time it was added (equip animation)
  const reduced = () => !!S().reducedMotion;
  const feverOn = () => !!(CO.fever && CO.fever.active);
  function shake(a) { if (S().shake === false || reduced()) return; shakeAmp = Math.max(shakeAmp, a); }
  function doFlash(a, rgb) { if (reduced()) return; flash = Math.max(flash, a); flashCol = rgb || '255,255,255'; }
  function popScale(k) {
    const t0 = pop[k]; if (t0 == null) return 1;
    const p = (T - t0) / 0.75; if (p >= 1) { delete pop[k]; return 1; }
    return reduced() ? easeOutCubic(p) : elasticOut(p);
  }

  /* ═════════════════════════ sprite caches ═════════════════════════ */
  const GLOW = new Map(), SPARK = new Map();
  function glowSprite(col) {
    let s = GLOW.get(col); if (s) return s;
    s = mk(64); const g = s.getContext('2d');
    const gr = radG(g, 32, 32, 0, 32, 32, 32);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.2, 'rgba(255,255,255,.7)');
    gr.addColorStop(0.5, 'rgba(255,255,255,.2)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, 64, 64); g.globalCompositeOperation = 'source-in'; g.fillStyle = col; g.fillRect(0, 0, 64, 64);
    if (GLOW.size > 400) GLOW.clear(); GLOW.set(col, s); return s;
  }
  function sparkSprite(col) {
    let s = SPARK.get(col); if (s) return s;
    s = mk(64); const g = s.getContext('2d');
    g.drawImage(glowSprite(col), 16, 16, 32, 32);
    g.fillStyle = col; g.beginPath();
    g.moveTo(32, 2); g.quadraticCurveTo(35, 29, 62, 32); g.quadraticCurveTo(35, 35, 32, 62); g.quadraticCurveTo(29, 35, 2, 32); g.quadraticCurveTo(29, 29, 32, 2); g.fill();
    g.fillStyle = '#fff'; g.beginPath(); g.moveTo(32, 14); g.quadraticCurveTo(33.5, 30.5, 50, 32); g.quadraticCurveTo(33.5, 33.5, 32, 50); g.quadraticCurveTo(30.5, 33.5, 14, 32); g.quadraticCurveTo(30.5, 30.5, 32, 14); g.fill();
    if (SPARK.size > 200) SPARK.clear(); SPARK.set(col, s); return s;
  }
  const spr = (c, img, x, y, size) => c.drawImage(img, x - size / 2, y - size / 2, size, size);
  let STAR5 = null, GLOVE = null;
  function star5() {
    if (STAR5) return STAR5; STAR5 = mk(64); const g = STAR5.getContext('2d');
    const gr = g.createLinearGradient(0, 6, 0, 58); gr.addColorStop(0, '#fff3a0'); gr.addColorStop(0.5, '#ffc93c'); gr.addColorStop(1, '#e08a00');
    starPath(g, 32, 34, 28, 12.5); g.fillStyle = gr; g.fill(); g.lineJoin = 'round'; g.lineWidth = 4; g.strokeStyle = INK; g.stroke();
    g.fillStyle = 'rgba(255,255,255,.75)'; g.beginPath(); ellS(g, 25, 25, 6, 3, -0.6, 0, TAU); g.fill();
    return STAR5;
  }
  function glove() {
    if (GLOVE) return GLOVE; GLOVE = mk(64); const g = GLOVE.getContext('2d');
    g.lineJoin = 'round'; g.lineWidth = 4; g.strokeStyle = INK; g.fillStyle = '#ffffff';
    rrect(g, 26, 5, 12, 32, 6); g.fill(); g.stroke();
    rrect(g, 16, 26, 32, 30, 10); g.fill(); g.stroke();
    g.beginPath(); ellS(g, 15, 38, 6, 9, -0.5, 0, TAU); g.fill(); g.stroke();
    g.fillStyle = '#ffffff'; g.fillRect(28, 26, 8, 6);
    g.strokeStyle = 'rgba(26,11,51,.35)'; g.lineWidth = 2; g.beginPath(); g.moveTo(24, 44); g.lineTo(40, 44); g.stroke();
    return GLOVE;
  }
  /** draw a CO.art icon centred in a size×size box; false if the art is not available (yet) */
  function icon(c, name, x, y, size, rot, alpha) {
    const A = CO.art; if (!A || !A.sprite) return false;
    let img = null; try { img = A.sprite(name, size * dpr); } catch (e) { img = null; }
    if (!img) return false;
    if (alpha != null && alpha <= 0) return true;
    if (rot) {
      c.save(); if (alpha != null) c.globalAlpha *= alpha; c.translate(x, y); c.rotate(rot);
      c.drawImage(img, -size / 2, -size / 2, size, size); c.restore();
    } else {
      const ga = c.globalAlpha; if (alpha != null) c.globalAlpha = ga * alpha;
      c.drawImage(img, x - size / 2, y - size / 2, size, size); c.globalAlpha = ga;
    }
    return true;
  }

  /* ═════════════════════════ text ═════════════════════════ */
  function outlined(c, text, x, y, size, fill, opts) {
    c.font = `${(opts && opts.weight) || ''} ${size | 0}px ${(opts && opts.font) || FONT_D}`;
    c.textAlign = (opts && opts.align) || 'center'; c.textBaseline = 'middle'; c.lineJoin = 'round';
    c.strokeStyle = INK; c.lineWidth = size * 0.2;
    c.strokeText(text, x, y + size * 0.07);
    c.strokeText(text, x, y);
    c.fillStyle = fill; c.fillText(text, x, y);
  }
  function rainbowGrad(c, x, w, off) {
    const g = c.createLinearGradient(x - w / 2, 0, x + w / 2, 0);
    for (let i = 0; i <= 4; i++) g.addColorStop(i / 4, hsl(hue((off || 0) + i * 55), 100, 62));
    return g;
  }

  /* ═════════════════════════ particles ═════════════════════════ */
  const P = [], POOL = [];
  function spawn(type, x, y, vx, vy, life, size, col, g, drag, add) {
    if (P.length >= pBudget) return null;
    const p = POOL.pop() || {};
    p.type = type; p.x = x; p.y = y; p.vx = vx; p.vy = vy; p.life = life; p.max = life; p.size = size; p.col = col;
    p.g = g || 0; p.drag = drag == null ? 1 : drag; p.add = add == null ? true : add;
    p.rot = Math.random() * TAU; p.vr = rand(-9, 9); p.name = null; p.skin = null;
    P.push(p); return p;
  }
  const cnt = (n) => Math.max(0, Math.round(n * pm));
  function burst(x, y, n, o) {
    o = o || {};
    const sp = o.speed || 300, cols = o.cols, life = o.life || 0.9;
    n = cnt(n);
    for (let i = 0; i < n; i++) {
      const a = o.ang != null ? o.ang + rand(-(o.spread || 0.6), o.spread || 0.6) : Math.random() * TAU;
      const v = sp * rand(0.25, 1);
      const col = cols ? pick(cols) : hq(hue(Math.random() * 360));
      const type = o.type || (i % 3 === 0 ? 'star' : i % 3 === 1 ? 'glow' : 'spark');
      spawn(type, x + (o.r0 ? Math.cos(a) * o.r0 : 0), y + (o.r0 ? Math.sin(a) * o.r0 : 0), Math.cos(a) * v, Math.sin(a) * v,
        life * rand(0.6, 1.2), (o.size || 14) * rand(0.6, 1.3), col, o.g || 0, o.drag || 0.94, type !== 'crumb' && type !== 'confetti' && type !== 'cookie');
    }
  }
  function confettiBurst(x, y, n, o) {
    o = o || {}; n = cnt(n);
    for (let i = 0; i < n; i++) {
      const a = (o.ang != null ? o.ang : -Math.PI / 2) + rand(-(o.spread || 1.2), o.spread || 1.2);
      const v = (o.speed || 520) * rand(0.35, 1);
      spawn('confetti', x + rand(-(o.w || 0), o.w || 0), y, Math.cos(a) * v, Math.sin(a) * v, rand(1.3, 2.4) * (o.lifeK || 1), rand(7, 13),
        hq(Math.random() * 360, rand(55, 68)), o.g || 900, 0.975, false);
    }
  }
  function updateParticles(dt) {
    for (let i = P.length - 1; i >= 0; i--) {
      const p = P[i]; p.life -= dt;
      if (p.life <= 0) { P[i] = P[P.length - 1]; P.pop(); POOL.push(p); continue; }
      if (p.drag !== 1) { const d = Math.pow(p.drag, dt * 60); p.vx *= d; p.vy *= d; }
      p.vy += p.g * dt; p.x += p.vx * dt; p.y += p.vy * dt; p.rot += p.vr * dt;
      if (p.type === 'confetti') p.vx += Math.sin(p.rot * 1.3) * 40 * dt;
    }
  }
  function baseXf(c) { c.setTransform(dpr, 0, 0, dpr, dpr * shx, dpr * shy); }
  function xf(c, x, y, rot, sx, sy) {
    const co = Math.cos(rot) * dpr, si = Math.sin(rot) * dpr;
    c.setTransform(co * sx, si * sx, -si * sy, co * sy, dpr * (x + shx), dpr * (y + shy));
  }
  function drawParticles(c) {
    for (let i = 0; i < P.length; i++) {
      const p = P[i]; if (p.add) continue;
      const k = p.life / p.max, a = k < 0.25 ? k / 0.25 : 1;
      c.globalAlpha = a;
      if (p.type === 'confetti') { c.fillStyle = p.col; xf(c, p.x, p.y, p.rot, 1, Math.cos(p.rot * 2.1)); c.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2); }
      else if (p.type === 'crumb') { c.fillStyle = p.col; xf(c, p.x, p.y, p.rot, 1, 1); c.fillRect(-p.size / 2, -p.size / 2, p.size, p.size * 0.8); }
      else if (p.type === 'cookie') { baseXf(c); drawCookie(c, p.x, p.y, p.size, { simple: true, rot: p.rot, skin: p.skin || undefined }); }
      else if (p.type === 'icon') { baseXf(c); if (!icon(c, p.name, p.x, p.y, p.size, p.rot * 0.2)) spr(c, sparkSprite(p.col), p.x, p.y, p.size); }
    }
    baseXf(c);
    c.globalCompositeOperation = 'lighter';
    for (let i = 0; i < P.length; i++) {
      const p = P[i]; if (!p.add) continue;
      const k = p.life / p.max; c.globalAlpha = k < 0.35 ? k / 0.35 : 1;
      if (p.type === 'glow') spr(c, glowSprite(p.col), p.x, p.y, p.size * (0.35 + 0.65 * k));
      else if (p.type === 'star') spr(c, sparkSprite(p.col), p.x, p.y, p.size * (0.4 + 0.8 * Math.sin(k * Math.PI)));
      else if (p.type === 'spark') { c.strokeStyle = p.col; c.lineWidth = Math.max(1, p.size * 0.18 * k); c.beginPath(); c.moveTo(p.x, p.y); c.lineTo(p.x - p.vx * 0.045, p.y - p.vy * 0.045); c.stroke(); }
      else if (p.type === 'ember') { c.globalAlpha *= 0.6 + 0.4 * Math.sin(p.rot * 3); spr(c, glowSprite(p.col), p.x, p.y, p.size); }
    }
    c.globalCompositeOperation = 'source-over'; c.globalAlpha = 1;
  }

  /* rings (shockwaves) */
  const RINGS = [];
  function ring(x, y, r0, r1, dur, w, col) { if (RINGS.length > 40) RINGS.shift(); RINGS.push({ x, y, r0, r1, t0: T, dur, w, col }); }
  function drawRings(c) {
    c.globalCompositeOperation = 'lighter';
    for (let i = RINGS.length - 1; i >= 0; i--) {
      const g = RINGS[i], p = (T - g.t0) / g.dur;
      if (p >= 1) { RINGS.splice(i, 1); continue; }
      const rad = lerp(g.r0, g.r1, easeOutCubic(p)), w = g.w * (1 - p) + 1;
      c.globalAlpha = 1 - p;
      if (g.col === 'rgb') {
        const h0 = hue(0);
        for (let s = 0; s < 6; s++) { c.strokeStyle = hsl(h0 + s * 60, 100, 62); c.lineWidth = w; c.beginPath(); arcS(c, g.x, g.y, rad, (s / 6) * TAU + AT * 2, ((s + 1) / 6) * TAU + AT * 2 + 0.02); c.stroke(); }
      } else { c.strokeStyle = g.col; c.lineWidth = w; c.beginPath(); arcS(c, g.x, g.y, rad, 0, TAU); c.stroke(); }
    }
    c.globalAlpha = 1; c.globalCompositeOperation = 'source-over';
  }

  /* ═════════════════════════ cookie shape ═════════════════════════ */
  const SHAPE_N = 72, SHAPE = new Float32Array(SHAPE_N * 2);
  for (let i = 0; i < SHAPE_N; i++) {
    const a = (i / SHAPE_N) * TAU;
    const f = 1 + 0.022 * Math.sin(5 * a + 1.3) + 0.016 * Math.sin(9 * a + 0.4) + 0.01 * Math.sin(14 * a + 2.1) + 0.006 * Math.sin(23 * a + 0.7);
    SHAPE[i * 2] = Math.cos(a) * f * 0.955; SHAPE[i * 2 + 1] = Math.sin(a) * f * 0.955;
  }
  function shapePath(c, r, k) {
    const s = r * (k || 1); c.beginPath();
    for (let i = 0; i < SHAPE_N; i++) { const x = SHAPE[i * 2] * s, y = SHAPE[i * 2 + 1] * s; i ? c.lineTo(x, y) : c.moveTo(x, y); }
    c.closePath();
  }
  const DIA_N = 16;
  function diamondPath(c, r) {
    c.beginPath();
    for (let i = 0; i < DIA_N; i++) { const a = (i / DIA_N) * TAU - Math.PI / 2; i ? c.lineTo(Math.cos(a) * r, Math.sin(a) * r) : c.moveTo(Math.cos(a) * r, Math.sin(a) * r); }
    c.closePath();
  }
  function bodyPath(c, r, sk, k) { if (sk.style === 'diamond') diamondPath(c, r * 0.99 * (k || 1)); else shapePath(c, r, k); }
  function inDisk(rng, max) { const a = rng() * TAU, d = Math.sqrt(rng()) * max; return [Math.cos(a) * d, Math.sin(a) * d]; }
  function blobPath(c, x, y, rad, rng, n) {
    n = n || 7; const pts = [];
    for (let i = 0; i < n; i++) { const a = (i / n) * TAU, rr = rad * (0.78 + rng() * 0.36); pts.push(x + Math.cos(a) * rr, y + Math.sin(a) * rr); }
    c.beginPath();
    for (let i = 0; i < n; i++) {
      const px = pts[i * 2], py = pts[i * 2 + 1], qx = pts[((i + 1) % n) * 2], qy = pts[((i + 1) % n) * 2 + 1];
      if (i === 0) c.moveTo((pts[(n - 1) * 2] + px) / 2, (pts[(n - 1) * 2 + 1] + py) / 2);
      c.quadraticCurveTo(px, py, (px + qx) / 2, (py + qy) / 2);
    }
    c.closePath();
  }
  function genCracks(seed, n, len, radial) {
    const rng = mulberry32(seed), out = [];
    for (let k = 0; k < n; k++) {
      let a = rng() * TAU, rad = radial ? rng() * 0.1 : rng() * 0.45;
      let x = Math.cos(a) * rad, y = Math.sin(a) * rad, dir = radial ? a : a + (rng() - 0.5) * 2;
      const pts = [x, y], steps = radial ? 9 : 3 + ((rng() * 4) | 0);
      for (let s = 0; s < steps; s++) {
        dir += (rng() - 0.5) * (radial ? 0.9 : 1.2); const L = len * (0.6 + rng() * 0.8);
        x += Math.cos(dir) * L; y += Math.sin(dir) * L;
        if (x * x + y * y > 0.83) break;
        pts.push(x, y);
      }
      if (pts.length >= 4) out.push(pts);
    }
    return out;
  }
  function strokePolys(c, polys, r) {
    c.beginPath();
    for (const pts of polys) { c.moveTo(pts[0] * r, pts[1] * r); for (let i = 2; i < pts.length; i += 2) c.lineTo(pts[i] * r, pts[i + 1] * r); }
    c.stroke();
  }
  const LAVA_CRACKS = genCracks(4242, 11, 0.2, false);
  const CORE_CRACKS = genCracks(777, 7, 0.14, true);
  function softGlow(g, r, r0, r1, col) {
    const gr = radG(g, 0, 0, r * r0, 0, 0, r * r1);
    gr.addColorStop(0, col); gr.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = gr; g.beginPath(); arcS(g, 0, 0, r * r1, 0, TAU); g.fill();
  }
  function speckles(g, r, rng, n, light, dark, max) {
    for (let i = 0; i < n; i++) {
      const [x, y] = inDisk(rng, max || 0.92); g.fillStyle = rng() < 0.5 ? light : dark;
      g.beginPath(); arcS(g, x * r, y * r, r * (0.006 + rng() * 0.014), 0, TAU); g.fill();
    }
  }
  function chipsLayer(g, r, rng, n, chip, chipHi, spread) {
    const pos = [];
    for (let tries = 0; pos.length < n && tries < 300; tries++) {
      const [x, y] = inDisk(rng, spread || 0.74);
      if (pos.every(([a, b]) => (a - x) ** 2 + (b - y) ** 2 > 0.07)) pos.push([x, y]);
    }
    for (const [ux, uy] of pos) {
      const x = ux * r, y = uy * r, rad = r * (0.07 + rng() * 0.045), seed = rng() * 1e6;
      g.fillStyle = 'rgba(0,0,0,.32)'; blobPath(g, x + rad * 0.15, y + rad * 0.25, rad, mulberry32(seed)); g.fill();
      g.fillStyle = chip; blobPath(g, x, y, rad, mulberry32(seed)); g.fill();
      g.fillStyle = chipHi; blobPath(g, x - rad * 0.28, y - rad * 0.3, rad * 0.45, mulberry32(seed + 1)); g.fill();
      g.fillStyle = 'rgba(255,255,255,.55)'; g.beginPath(); arcS(g, x - rad * 0.38, y - rad * 0.42, rad * 0.15, 0, TAU); g.fill();
    }
    return pos;
  }
  function rimLight(g, r, sk) {
    const gr = g.createLinearGradient(-r, -r, r * 0.3, r * 0.3);
    gr.addColorStop(0, 'rgba(255,255,255,.55)'); gr.addColorStop(0.5, 'rgba(255,255,255,0)');
    g.strokeStyle = gr; g.lineWidth = r * 0.035; bodyPath(g, r, sk, 0.94); g.stroke();
  }

  /* ═════════════════════════ skin base textures (cached per skin & size bucket) ═════════════════════════ */
  const BASE = {
    classic(g, r, p, rng, sk) {
      shapePath(g, r, 1); g.fillStyle = p.rim; g.fill();
      const gr = radG(g, -0.3 * r, -0.35 * r, 0.05 * r, 0, 0, r);
      gr.addColorStop(0, p.light); gr.addColorStop(0.5, p.base); gr.addColorStop(0.86, p.dark); gr.addColorStop(1, p.rim);
      shapePath(g, r, 0.965); g.fillStyle = gr; g.fill();
      g.save(); shapePath(g, r, 0.965); g.clip();
      for (let i = 0; i < 26; i++) {
        const [x, y] = inDisk(rng, 0.85), br = r * (0.07 + rng() * 0.12);
        const lg = radG(g, x * r - br * 0.3, y * r - br * 0.3, 0, x * r, y * r, br);
        lg.addColorStop(0, rgba(p.light, 0.32)); lg.addColorStop(1, rgba(p.light, 0));
        g.fillStyle = lg; g.fillRect(x * r - br, y * r - br, br * 2, br * 2);
      }
      speckles(g, r, rng, 180, rgba(p.light, 0.35), rgba(p.dark, 0.4));
      g.strokeStyle = rgba(p.dark, 0.45); g.lineWidth = r * 0.014; g.lineCap = 'round';
      const cr = genCracks(hashStr(sk.id), 6, 0.1, false); strokePolys(g, cr, r);
      const sh = radG(g, r * 0.25, r * 0.3, r * 0.3, 0, 0, r * 1.05);
      sh.addColorStop(0, 'rgba(0,0,0,0)'); sh.addColorStop(1, 'rgba(0,0,0,.28)'); g.fillStyle = sh; g.fillRect(-r, -r, 2 * r, 2 * r);
      g.restore();
      chipsLayer(g, r, rng, 11, p.chip, p.chipHi);
      rimLight(g, r, sk);
    },
    pixel(g, r, p, rng) {
      const N = 18, cell = Math.max(1, Math.round((2 * r) / N)), half = (cell * N) / 2;
      const inside = (i, j) => { if (i < 0 || j < 0 || i >= N || j >= N) return false; const x = ((i + 0.5) / N) * 2 - 1, y = ((j + 0.5) / N) * 2 - 1; return x * x + y * y < 0.9; };
      const chips = new Set();
      for (let k = 0, tries = 0; k < 8 && tries < 200; tries++) {
        const i = 3 + ((rng() * 11) | 0), j = 3 + ((rng() * 11) | 0);
        if (!inside(i, j) || !inside(i + 1, j + 1) || chips.has(i + ',' + j) || chips.has(i - 1 + ',' + j) || chips.has(i + ',' + (j - 1)) || chips.has(i + 1 + ',' + j) || chips.has(i + ',' + (j + 1))) continue;
        chips.add(i + ',' + j); k++;
      }
      g.imageSmoothingEnabled = false;
      for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) {
        const x = -half + i * cell, y = -half + j * cell;
        if (!inside(i, j)) { if (inside(i - 1, j) || inside(i + 1, j) || inside(i, j - 1) || inside(i, j + 1)) { g.fillStyle = INK; g.fillRect(x, y, cell, cell); } continue; }
        const ux = ((i + 0.5) / N) * 2 - 1, uy = ((j + 0.5) / N) * 2 - 1, d = Math.sqrt(ux * ux + uy * uy);
        let col = d > 0.8 ? p.dark : ux + uy < -0.7 ? p.light : p.base;
        if (d > 0.8 && ux + uy < -0.6) col = p.base;
        if (d < 0.8 && rng() < 0.07) col = p.dark;
        g.fillStyle = col; g.fillRect(x, y, cell, cell);
      }
      for (const key of chips) {
        const [i, j] = key.split(',').map(Number), x = -half + i * cell, y = -half + j * cell;
        g.fillStyle = p.chip; g.fillRect(x, y, cell * 2, cell * 2);
        g.fillStyle = p.chipHi; g.fillRect(x, y, cell, cell);
      }
      g.fillStyle = '#ffffff'; g.fillRect(-half + 4 * cell, -half + 5 * cell, cell, cell); g.fillRect(-half + 5 * cell, -half + 4 * cell, cell, cell);
      g.fillStyle = 'rgba(255,255,255,.55)'; g.fillRect(-half + 6 * cell, -half + 3 * cell, cell, cell);
    },
    lava(g, r, p, rng) {
      softGlow(g, r, 0.85, 1.28, 'rgba(255,80,0,.55)');
      const gr = radG(g, -0.25 * r, -0.3 * r, 0, 0, 0, r);
      gr.addColorStop(0, p.light); gr.addColorStop(0.55, p.base); gr.addColorStop(1, p.dark);
      shapePath(g, r, 1); g.fillStyle = gr; g.fill();
      g.save(); shapePath(g, r, 1); g.clip();
      for (let i = 0; i < 16; i++) { const [x, y] = inDisk(rng, 0.85); g.fillStyle = rgba(p.light, 0.35 + rng() * 0.3); blobPath(g, x * r, y * r, r * (0.1 + rng() * 0.12), rng, 6); g.fill(); }
      speckles(g, r, rng, 120, 'rgba(255,120,40,.18)', 'rgba(0,0,0,.4)');
      g.lineJoin = 'round'; g.lineCap = 'round';
      g.strokeStyle = 'rgba(255,90,0,.55)'; g.lineWidth = r * 0.09; strokePolys(g, LAVA_CRACKS, r);
      g.strokeStyle = '#ff6a00'; g.lineWidth = r * 0.045; strokePolys(g, LAVA_CRACKS, r);
      g.strokeStyle = '#ffd000'; g.lineWidth = r * 0.016; strokePolys(g, LAVA_CRACKS, r);
      const eg = radG(g, 0, 0, r * 0.75, 0, 0, r); eg.addColorStop(0, 'rgba(255,60,0,0)'); eg.addColorStop(1, 'rgba(255,60,0,.45)');
      g.fillStyle = eg; g.fillRect(-r, -r, 2 * r, 2 * r);
      g.restore();
      g.strokeStyle = p.rim; g.lineWidth = r * 0.03; shapePath(g, r, 0.99); g.stroke();
    },
    galaxy(g, r, p, rng) {
      softGlow(g, r, 0.9, 1.26, 'rgba(177,107,255,.5)');
      const gr = radG(g, -0.2 * r, -0.25 * r, 0, 0, 0, r);
      gr.addColorStop(0, p.light); gr.addColorStop(0.5, p.base); gr.addColorStop(1, p.dark);
      shapePath(g, r, 1); g.fillStyle = gr; g.fill();
      g.save(); shapePath(g, r, 1); g.clip(); g.globalCompositeOperation = 'lighter';
      const neb = ['rgba(255,94,240,.3)', 'rgba(57,198,255,.26)', 'rgba(122,44,255,.35)', 'rgba(255,138,61,.18)'];
      for (let i = 0; i < 10; i++) {
        const [x, y] = inDisk(rng, 0.8), br = r * (0.25 + rng() * 0.35);
        const lg = radG(g, x * r, y * r, 0, x * r, y * r, br); lg.addColorStop(0, neb[i % 4]); lg.addColorStop(1, 'rgba(0,0,0,0)');
        g.fillStyle = lg; g.fillRect(x * r - br, y * r - br, br * 2, br * 2);
      }
      for (let i = 0; i < 80; i++) { const [x, y] = inDisk(rng, 0.95); g.fillStyle = `rgba(255,255,255,${(0.3 + rng() * 0.7).toFixed(2)})`; g.fillRect(x * r, y * r, r * 0.012 + 0.5, r * 0.012 + 0.5); }
      for (let i = 0; i < 9; i++) {
        const [x, y] = inDisk(rng, 0.72), s = r * (0.16 + rng() * 0.1);
        g.drawImage(sparkSprite(i % 2 ? p.chip : p.chipHi), x * r - s / 2, y * r - s / 2, s, s);
      }
      g.restore();
      g.strokeStyle = p.rim; g.lineWidth = r * 0.03; shapePath(g, r, 0.99); g.stroke();
      g.strokeStyle = 'rgba(255,255,255,.45)'; g.lineWidth = r * 0.01; shapePath(g, r, 0.965); g.stroke();
    },
    diamond(g, r, p, rng) {
      softGlow(g, r, 0.9, 1.24, 'rgba(159,243,255,.45)');
      const inner = [], outer = [];
      for (let i = 0; i < 8; i++) { const a = ((i + 0.5) / 8) * TAU - Math.PI / 2; inner.push([Math.cos(a) * 0.5 * r, Math.sin(a) * 0.5 * r]); }
      for (let i = 0; i < DIA_N; i++) { const a = (i / DIA_N) * TAU - Math.PI / 2; outer.push([Math.cos(a) * 0.99 * r, Math.sin(a) * 0.99 * r]); }
      const c0 = [-0.04 * r, -0.05 * r], tris = [];
      for (let i = 0; i < 8; i++) {
        const a = inner[i], b = inner[(i + 1) % 8];
        tris.push([c0, a, b]);
        tris.push([a, outer[(2 * i + 1) % DIA_N], outer[(2 * i + 2) % DIA_N]]);
        tris.push([a, outer[(2 * i + 2) % DIA_N], b]);
        tris.push([a, outer[(2 * i) % DIA_N], outer[(2 * i + 1) % DIA_N]]);
      }
      const L = -2.3;
      g.lineJoin = 'round';
      for (const t of tris) {
        const mx = (t[0][0] + t[1][0] + t[2][0]) / 3, my = (t[0][1] + t[1][1] + t[2][1]) / 3;
        const ang = Math.atan2(my, mx), dist = Math.hypot(mx, my) / r;
        const shade = clamp(0.5 + 0.42 * Math.cos(ang - L) + (rng() - 0.5) * 0.35 - dist * 0.1, 0, 1);
        g.fillStyle = shade > 0.5 ? mixHex(p.base, p.light, (shade - 0.5) * 2) : mixHex(p.dark, p.base, shade * 2);
        g.beginPath(); g.moveTo(t[0][0], t[0][1]); g.lineTo(t[1][0], t[1][1]); g.lineTo(t[2][0], t[2][1]); g.closePath(); g.fill();
        g.strokeStyle = 'rgba(255,255,255,.5)'; g.lineWidth = Math.max(0.6, r * 0.01); g.stroke();
      }
      g.strokeStyle = p.rim; g.lineWidth = r * 0.04; diamondPath(g, r * 0.99); g.stroke();
      g.strokeStyle = 'rgba(255,255,255,.9)'; g.lineWidth = r * 0.012; diamondPath(g, r * 0.97); g.stroke();
      g.fillStyle = 'rgba(255,255,255,.28)'; g.beginPath(); g.moveTo(c0[0], c0[1]); g.lineTo(inner[5][0], inner[5][1]); g.lineTo(inner[6][0], inner[6][1]); g.closePath(); g.fill();
    },
    holo(g, r, p, rng) {
      softGlow(g, r, 0.9, 1.24, 'rgba(57,240,255,.4)');
      const gr = radG(g, 0, 0, 0, 0, 0, r);
      gr.addColorStop(0, 'rgba(57,240,255,.16)'); gr.addColorStop(0.7, 'rgba(57,240,255,.3)'); gr.addColorStop(1, 'rgba(57,240,255,.6)');
      shapePath(g, r, 1); g.fillStyle = gr; g.fill();
      g.save(); shapePath(g, r, 1); g.clip();
      g.strokeStyle = 'rgba(183,251,255,.3)'; g.lineWidth = Math.max(0.7, r * 0.008); g.beginPath();
      for (let i = -5; i <= 5; i++) { g.moveTo(-r, (i * r) / 5); g.lineTo(r, (i * r) / 5); g.moveTo((i * r) / 5, -r); g.lineTo((i * r) / 5, r); }
      g.stroke();
      g.strokeStyle = 'rgba(183,251,255,.45)'; g.beginPath(); arcS(g, 0, 0, r * 0.6, 0, TAU); g.stroke();
      g.restore();
      for (let i = 0; i < 9; i++) {
        const [x, y] = inDisk(rng, 0.7), s = r * (0.06 + rng() * 0.04);
        g.drawImage(glowSprite(p.chip), x * r - s * 2, y * r - s * 2, s * 4, s * 4);
        g.strokeStyle = p.chip; g.lineWidth = r * 0.022; g.beginPath(); arcS(g, x * r, y * r, s, 0, TAU); g.stroke();
      }
      g.strokeStyle = p.rim; g.lineWidth = r * 0.04; shapePath(g, r, 0.99); g.stroke();
      g.strokeStyle = 'rgba(255,255,255,.8)'; g.lineWidth = r * 0.01; shapePath(g, r, 0.99); g.stroke();
    },
    gold(g, r, p, rng, sk) {
      softGlow(g, r, 0.9, 1.22, 'rgba(255,204,51,.35)');
      shapePath(g, r, 1); g.fillStyle = p.rim; g.fill();
      const gr = g.createLinearGradient(-r, -r, r, r);
      gr.addColorStop(0, p.light); gr.addColorStop(0.22, p.base); gr.addColorStop(0.42, p.dark); gr.addColorStop(0.58, p.base); gr.addColorStop(0.76, p.light); gr.addColorStop(1, p.dark);
      shapePath(g, r, 0.965); g.fillStyle = gr; g.fill();
      g.lineWidth = r * 0.03;
      g.save(); g.translate(r * 0.012, r * 0.012); g.strokeStyle = 'rgba(138,90,0,.6)'; shapePath(g, r, 0.8); g.stroke(); g.restore();
      g.save(); g.translate(-r * 0.012, -r * 0.012); g.strokeStyle = 'rgba(255,242,168,.85)'; shapePath(g, r, 0.8); g.stroke(); g.restore();
      chipsLayer(g, r, rng, 8, p.chip, p.chipHi, 0.66);
      rimLight(g, r, sk);
    },
    rainbow(g, r, p, rng, sk) { // overlay only — the body colour is painted live (hue-cycling)
      g.save(); shapePath(g, r, 0.965); g.clip();
      const hi = radG(g, -0.3 * r, -0.35 * r, 0, -0.3 * r, -0.35 * r, r * 0.7);
      hi.addColorStop(0, 'rgba(255,255,255,.55)'); hi.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = hi; g.fillRect(-r, -r, 2 * r, 2 * r);
      const dk = radG(g, 0, 0, r * 0.6, 0, 0, r); dk.addColorStop(0, 'rgba(20,0,40,0)'); dk.addColorStop(1, 'rgba(20,0,40,.4)');
      g.fillStyle = dk; g.fillRect(-r, -r, 2 * r, 2 * r);
      speckles(g, r, rng, 140, 'rgba(255,255,255,.3)', 'rgba(26,11,51,.25)');
      g.restore();
      chipsLayer(g, r, rng, 11, p.chip, p.chipHi);
      g.strokeStyle = 'rgba(255,255,255,.85)'; g.lineWidth = r * 0.03; shapePath(g, r, 0.975); g.stroke();
      g.strokeStyle = INK; g.lineWidth = r * 0.02; shapePath(g, r, 1.0); g.stroke();
      rimLight(g, r, sk);
    },
    void(g, r, p, rng) {
      softGlow(g, r, 0.88, 1.32, 'rgba(177,107,255,.6)');
      const gr = radG(g, -0.15 * r, -0.2 * r, 0, 0, 0, r);
      gr.addColorStop(0, p.light); gr.addColorStop(0.55, p.base); gr.addColorStop(1, p.dark);
      shapePath(g, r, 1); g.fillStyle = gr; g.fill();
      g.save(); shapePath(g, r, 1); g.clip();
      const ng = radG(g, 0, 0, r * 0.55, 0, 0, r); ng.addColorStop(0, 'rgba(177,107,255,0)'); ng.addColorStop(1, 'rgba(177,107,255,.3)');
      g.fillStyle = ng; g.fillRect(-r, -r, 2 * r, 2 * r);
      for (let i = 0; i < 90; i++) { const [x, y] = inDisk(rng, 0.95); g.fillStyle = rng() < 0.3 ? 'rgba(200,160,255,.8)' : `rgba(255,255,255,${(0.2 + rng() * 0.6).toFixed(2)})`; g.fillRect(x * r, y * r, r * 0.01 + 0.4, r * 0.01 + 0.4); }
      for (let i = 0; i < 8; i++) { const [x, y] = inDisk(rng, 0.7), s = r * 0.2; g.globalAlpha = 0.55; g.drawImage(glowSprite(p.chip), x * r - s / 2, y * r - s / 2, s, s); }
      g.restore();
      g.strokeStyle = p.rim; g.lineWidth = r * 0.03; shapePath(g, r, 0.99); g.stroke();
      g.strokeStyle = 'rgba(255,255,255,.6)'; g.lineWidth = r * 0.008; shapePath(g, r, 0.97); g.stroke();
    },
  };

  const BUCKETS = [16, 32, 64, 128, 256, 400], PAD = 1.34;
  const baseCache = new Map();
  function skinDef(id) {
    const D = DATA(), list = D.skins || [];
    if (id) { const s = list.find((x) => x.id === id); if (s) return s; }
    return (CO.skin && CO.skin()) || list[0] || { id: 'classic', style: 'classic', pal: { base: '#d99a4e', dark: '#a9652a', light: '#f3c783', chip: '#4a2511', chipHi: '#7a4424', rim: '#8a5220' } };
  }
  function getBase(sk, rr) {
    const key = sk.id + '|' + rr; let c = baseCache.get(key); if (c) return c;
    const size = Math.ceil(rr * 2 * PAD) + 2; c = mk(size, size);
    const g = c.getContext('2d'); g.translate(size / 2, size / 2);
    (BASE[sk.style] || BASE.classic)(g, rr, sk.pal, mulberry32(hashStr(sk.id) ^ 0x9e3779b9), sk);
    baseCache.set(key, c); return c;
  }
  function paintRainbowBody(c, r, t) {
    const h = hue(0), g = c.createLinearGradient(-r, -r, r, r);
    g.addColorStop(0, hsl(h, 100, 64)); g.addColorStop(0.5, hsl(h + 70, 100, 60)); g.addColorStop(1, hsl(h + 150, 100, 58));
    c.fillStyle = g; shapePath(c, r, 1); c.fill();
  }
  function drawBase(c, sk, r, t, full) {
    const px = r * scaleOf(c); let rr = 400;
    for (let i = 0; i < BUCKETS.length; i++) if (BUCKETS[i] >= px) { rr = BUCKETS[i]; break; }
    if (sk.style === 'rainbow') paintRainbowBody(c, r, t);
    const img = getBase(sk, rr), hw = (img.width / 2) * (r / rr);
    const ga = c.globalAlpha;
    if (sk.style === 'holo' && full) { const n = Math.sin(t * 37) * Math.sin(t * 23.3); c.globalAlpha = ga * (n > 0.93 ? 0.45 : 0.85 + 0.15 * Math.sin(t * 9)); }
    if (sk.style === 'pixel') { const sm = c.imageSmoothingEnabled; c.imageSmoothingEnabled = false; c.drawImage(img, -hw, -hw, hw * 2, hw * 2); c.imageSmoothingEnabled = sm; }
    else c.drawImage(img, -hw, -hw, hw * 2, hw * 2);
    c.globalAlpha = ga;
    if (full && ANIM[sk.style]) ANIM[sk.style](c, r, t, sk.pal, sk);
  }

  /* animated skin overlays (non-simple draws only) */
  let SWIRL = null;
  function swirl() {
    if (SWIRL) return SWIRL; SWIRL = mk(256); const g = SWIRL.getContext('2d'); g.translate(128, 128);
    const cols = ['#ff5ef0', '#39c6ff', '#b16bff', '#ffffff'];
    for (let arm = 0; arm < 3; arm++) for (let i = 0; i < 90; i++) {
      const k = i / 90, a = arm * (TAU / 3) + k * 4.2, rad = 8 + k * 112;
      const s = 10 + (1 - k) * 26; g.globalAlpha = 0.25 + (1 - k) * 0.35;
      g.drawImage(glowSprite(cols[(arm + (i % 2)) % 4]), Math.cos(a) * rad - s / 2, Math.sin(a) * rad - s / 2, s, s);
    }
    g.globalAlpha = 1; g.drawImage(glowSprite('#ffffff'), -30, -30, 60, 60);
    return SWIRL;
  }
  const TW = []; { const rng = mulberry32(99); for (let i = 0; i < 12; i++) { const [x, y] = inDisk(rng, 0.85); TW.push([x, y, rng() * TAU]); } }
  const ANIM = {
    lava(c, r, t) {
      c.save(); c.globalCompositeOperation = 'lighter'; c.lineJoin = 'round'; c.lineCap = 'round';
      c.globalAlpha = 0.3 + 0.25 * Math.sin(t * 2.6); c.strokeStyle = '#ff5a00'; c.lineWidth = r * 0.1; strokePolys(c, LAVA_CRACKS, r);
      c.globalAlpha = 0.9; c.setLineDash([r * 0.07, r * 0.32]); c.lineDashOffset = -t * r * 0.5;
      c.strokeStyle = '#fff3a0'; c.lineWidth = r * 0.028; strokePolys(c, LAVA_CRACKS, r); c.setLineDash([]);
      for (let i = 0; i < 7; i++) {
        const ph = (t * 0.55 + i / 7) % 1, x = Math.sin(i * 12.9) * 0.6 * r + Math.sin(t * 2 + i) * 0.05 * r, y = Math.cos(i * 7.1) * 0.45 * r - ph * r * 0.9;
        c.globalAlpha = (1 - ph) * 0.9; const s = r * (0.14 - ph * 0.08); c.drawImage(glowSprite(i % 2 ? '#ffb000' : '#ff5a00'), x - s / 2, y - s / 2, s, s);
      }
      c.restore();
    },
    galaxy(c, r, t) {
      c.save(); shapePath(c, r, 1); c.clip(); c.globalCompositeOperation = 'lighter';
      c.globalAlpha = 0.45; c.rotate(t * 0.35); c.drawImage(swirl(), -r * 1.05, -r * 1.05, r * 2.1, r * 2.1); c.rotate(-t * 0.35);
      for (let i = 0; i < TW.length; i++) { const [x, y, ph] = TW[i]; const a = Math.max(0, Math.sin(t * 2.6 + ph)); c.globalAlpha = a; const s = r * 0.16 * a + 1; c.drawImage(sparkSprite('#e8fbff'), x * r - s / 2, y * r - s / 2, s, s); }
      c.restore();
    },
    diamond(c, r, t) {
      c.save(); diamondPath(c, r * 0.99); c.clip(); c.globalCompositeOperation = 'lighter';
      const ph = (t * 0.4) % 1.5, x = lerp(-2.2 * r, 2.2 * r, ph / 1.5), h = hue(0);
      c.rotate(-0.7); const g = c.createLinearGradient(x - r * 0.4, 0, x + r * 0.4, 0);
      g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.3, hsl(h, 100, 70, 0.3)); g.addColorStop(0.5, 'rgba(255,255,255,.45)'); g.addColorStop(0.7, hsl(h + 140, 100, 70, 0.3)); g.addColorStop(1, 'rgba(255,255,255,0)');
      c.fillStyle = g; c.fillRect(-2 * r, -2 * r, 4 * r, 4 * r); c.rotate(0.7);
      for (let i = 0; i < 6; i++) {
        const ph2 = (t * 0.7 + i * 0.37) % 1; if (ph2 > 0.3) continue;
        const a = ((i * 5 + 2) / DIA_N) * TAU - Math.PI / 2, rad = i % 2 ? 0.5 : 0.9, s = r * 0.5 * Math.sin((ph2 / 0.3) * Math.PI);
        c.drawImage(sparkSprite(hq(h + i * 60, 80)), Math.cos(a) * rad * r - s / 2, Math.sin(a) * rad * r - s / 2, s, s);
      }
      c.restore();
    },
    holo(c, r, t, p) {
      c.save(); shapePath(c, r, 1); c.clip();
      c.fillStyle = 'rgba(200,255,255,.14)'; const sp = r * 0.07, off = (t * r * 0.35) % sp;
      for (let y = -r - sp + off; y < r; y += sp) c.fillRect(-r, y, 2 * r, r * 0.022);
      c.restore();
      c.save(); c.globalCompositeOperation = 'lighter'; c.lineWidth = r * 0.03; const d = r * (0.025 + 0.02 * Math.sin(t * 5));
      c.translate(-d, 0); c.strokeStyle = 'rgba(255,0,90,.7)'; shapePath(c, r, 0.99); c.stroke();
      c.translate(2 * d, 0); c.strokeStyle = 'rgba(0,140,255,.7)'; shapePath(c, r, 0.99); c.stroke();
      c.restore();
    },
    gold(c, r, t) {
      const ph = (t % 2.8) / 2.8; if (ph > 0.5) return;
      c.save(); shapePath(c, r, 0.97); c.clip(); c.globalCompositeOperation = 'lighter'; c.rotate(0.55);
      const x = lerp(-1.6 * r, 1.6 * r, easeInOut(ph / 0.5)), g = c.createLinearGradient(x - r * 0.25, 0, x + r * 0.25, 0);
      g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.5, 'rgba(255,255,230,.75)'); g.addColorStop(1, 'rgba(255,255,255,0)');
      c.fillStyle = g; c.fillRect(-2 * r, -2 * r, 4 * r, 4 * r); c.restore();
    },
    rainbow(c, r, t) {
      const s = r * 0.3 * Math.max(0, Math.sin(t * 3)); if (s < 1) return;
      c.save(); c.globalCompositeOperation = 'lighter'; c.drawImage(sparkSprite('#ffffff'), -0.45 * r - s / 2, -0.5 * r - s / 2, s, s); c.restore();
    },
    void(c, r, t) {
      c.save(); c.globalCompositeOperation = 'lighter';
      for (let k = 0; k < 2; k++) {
        c.strokeStyle = k ? 'rgba(177,107,255,.2)' : 'rgba(210,160,255,.4)'; c.lineWidth = r * (k ? 0.035 : 0.018); c.beginPath();
        for (let i = 0; i <= 64; i++) { const a = (i / 64) * TAU, rad = r * (1.1 + k * 0.1 + 0.03 * Math.sin(8 * a + t * (k ? -2.4 : 3))); i ? c.lineTo(Math.cos(a) * rad, Math.sin(a) * rad) : c.moveTo(Math.cos(a) * rad, Math.sin(a) * rad); }
        c.stroke();
      }
      shapePath(c, r, 0.97); c.clip(); c.globalAlpha = 0.18; c.rotate(-t * 0.25); c.drawImage(swirl(), -r, -r, 2 * r, 2 * r); c.rotate(t * 0.25);
      for (let i = 0; i < TW.length; i += 2) { const [x, y, ph] = TW[i]; const a = Math.max(0, Math.sin(t * 2 + ph)); c.globalAlpha = a; const s = r * 0.12 * a + 1; c.drawImage(sparkSprite('#d9b8ff'), x * r - s / 2, y * r - s / 2, s, s); }
      c.restore();
    },
    pixel(c, r, t) {
      const ph = (t * 0.8) % 1; if (ph > 0.25) return;
      const cell = (2 * r) / 18, k = Math.floor(t * 0.8) % 5, i = [5, 11, 8, 12, 4][k], j = [11, 6, 13, 9, 7][k];
      const x = -r + i * cell, y = -r + j * cell; c.fillStyle = 'rgba(255,255,255,.9)';
      c.fillRect(x, y - cell, cell, cell * 3); c.fillRect(x - cell, y, cell * 3, cell);
    },
  };

  /* ═════════════════════════ zone:'cookie' accessories ═════════════════════════ */
  function begin(c, fx, k, ax, ay) {
    const s = fx.pop ? fx.pop(k) : 1; if (s <= 0.002) return false;
    c.save(); if (s !== 1) { c.translate(ax, ay); c.scale(s, s); c.translate(-ax, -ay); }
    return true;
  }
  const XL = [[-0.42, -0.4, 0.14], [0.36, -0.46, 0.12], [0.05, -0.06, 0.15], [-0.3, 0.4, 0.13], [0.5, 0.14, 0.13], [-0.64, 0.02, 0.11], [0.24, 0.52, 0.12]];
  const XL_RNG = [0.1, 0.9, 0.3, 0.7, 0.5, 0.2, 0.8];
  const SPR = []; { const rng = mulberry32(31337); for (let i = 0; i < 90;) { const [x, y] = inDisk(rng, 0.8); if (Math.abs(y + 0.06) < 0.18 && Math.abs(Math.abs(x) - 0.28) < 0.16) continue; SPR.push([x, y, rng() * TAU]); i++; } }
  const SPR_COL = ['#ff3b6b', '#ffd23c', '#3dff8a', '#3dc8ff', '#b36bff', '#ff8a1f', '#ffffff'];
  const CRY = [[-0.52, -0.18, 0.16, 0.3], [0.32, 0.3, 0.13, -0.5], [0.14, -0.55, 0.12, 0.9], [-0.22, 0.56, 0.1, -0.2], [0.6, -0.22, 0.11, 1.3]];
  const SHADES = [
    'XXXXXXXXXXXXXXXXXXXXXXXX',
    '.XWWXXXXXXX..XWWXXXXXXX.',
    '.XXWWXXXXXX..XXWWXXXXXX.',
    '..XXXXXXXX....XXXXXXXX..',
    '...XXXXXX......XXXXXX...',
  ];
  const DRIPS = [0.35, 0.78, 1.2, 1.57, 1.95, 2.38, 2.8];
  const EYE_X = 0.28, EYE_Y = -0.06;

  const ACC = {
    chips_xl(c, r, t, l, fx, sk) {
      if (!begin(c, fx, 'chips_xl', 0, 0)) return;
      const p = sk.pal;
      for (let i = 0; i < XL.length; i++) {
        const [ux, uy, us] = XL[i], x = ux * r, y = uy * r, s = us * r, rng = mulberry32(i * 97 + 5);
        c.fillStyle = 'rgba(0,0,0,.35)'; blobPath(c, x + s * 0.12, y + s * 0.22, s, rng, 8); c.fill();
        const g = radG(c, x - s * 0.35, y - s * 0.4, s * 0.1, x, y, s * 1.1);
        g.addColorStop(0, p.chipHi); g.addColorStop(1, p.chip);
        c.fillStyle = g; blobPath(c, x, y, s, mulberry32(i * 97 + 5), 8); c.fill();
        c.lineWidth = s * 0.1; c.strokeStyle = 'rgba(0,0,0,.3)'; c.stroke();
        c.fillStyle = 'rgba(255,255,255,.85)'; c.beginPath(); ellS(c, x - s * 0.33, y - s * 0.4, s * 0.3, s * 0.15, -0.6, 0, TAU); c.fill();
        c.fillStyle = 'rgba(255,255,255,.5)'; c.beginPath(); arcS(c, x + s * 0.35, y + s * 0.28, s * 0.09, 0, TAU); c.fill();
        const gl = Math.max(0, Math.sin(t * 2 + XL_RNG[i] * 9)); if (gl > 0.9) { const z = s * 1.6 * (gl - 0.9) * 10; c.save(); c.globalCompositeOperation = 'lighter'; c.drawImage(sparkSprite('#ffffff'), x - s * 0.33 - z / 2, y - s * 0.4 - z / 2, z, z); c.restore(); }
      }
      c.restore();
    },
    crystals(c, r, t, l, fx) {
      if (!begin(c, fx, 'crystals', 0, 0)) return;
      c.lineJoin = 'round';
      for (let i = 0; i < CRY.length; i++) {
        const [ux, uy, us, rot] = CRY[i], s = us * r;
        c.save(); c.translate(ux * r, uy * r); c.rotate(rot);
        c.fillStyle = 'rgba(0,0,0,.3)'; c.beginPath(); ellS(c, s * 0.1, s * 0.15, s * 0.62, s * 1.02, 0, 0, TAU); c.fill();
        const g = c.createLinearGradient(-s * 0.55, -s, s * 0.55, s); g.addColorStop(0, '#ffffff'); g.addColorStop(0.45, '#9ff3ff'); g.addColorStop(1, '#2a9bd6');
        c.beginPath(); c.moveTo(0, -s); c.lineTo(s * 0.55, -s * 0.35); c.lineTo(s * 0.55, s * 0.45); c.lineTo(0, s); c.lineTo(-s * 0.55, s * 0.45); c.lineTo(-s * 0.55, -s * 0.35); c.closePath();
        c.fillStyle = g; c.fill(); c.strokeStyle = 'rgba(10,40,80,.8)'; c.lineWidth = s * 0.12; c.stroke();
        c.strokeStyle = 'rgba(255,255,255,.7)'; c.lineWidth = s * 0.06; c.beginPath(); c.moveTo(0, -s); c.lineTo(0, s); c.moveTo(-s * 0.55, -s * 0.35); c.lineTo(0, -s * 0.1); c.lineTo(s * 0.55, -s * 0.35); c.stroke();
        c.fillStyle = 'rgba(255,255,255,.55)'; c.beginPath(); c.moveTo(0, -s); c.lineTo(-s * 0.55, -s * 0.35); c.lineTo(-s * 0.55, s * 0.45); c.lineTo(0, -s * 0.1); c.closePath(); c.fill();
        c.restore();
        const gl = Math.pow(Math.max(0, Math.sin(t * 2.4 + i * 1.9)), 4), z = s * 3.2 * gl;
        if (z > 1) { c.save(); c.globalCompositeOperation = 'lighter'; c.drawImage(sparkSprite('#dffcff'), ux * r - z / 2, (uy - us * 0.6) * r - z / 2, z, z); c.restore(); }
      }
      c.restore();
    },
    galaxy_core(c, r, t, l, fx) {
      if (!begin(c, fx, 'galaxy_core', 0, 0)) return;
      shapePath(c, r, 0.97); c.clip(); c.globalCompositeOperation = 'lighter';
      c.globalAlpha = 0.6 + 0.2 * Math.sin(t * 2); c.rotate(t * 0.9); const w = r * 1.1; c.drawImage(swirl(), -w / 2, -w / 2, w, w); c.rotate(-t * 0.9);
      c.globalAlpha = 1; c.lineJoin = 'round'; c.lineCap = 'round'; const h = hue(260);
      c.strokeStyle = hsl(h, 100, 60, 0.45); c.lineWidth = r * 0.1; strokePolys(c, CORE_CRACKS, r);
      c.strokeStyle = '#ff5ef0'; c.lineWidth = r * 0.04; strokePolys(c, CORE_CRACKS, r);
      c.strokeStyle = '#ffffff'; c.lineWidth = r * 0.014; strokePolys(c, CORE_CRACKS, r);
      c.setLineDash([r * 0.05, r * 0.25]); c.lineDashOffset = -t * r * 0.8; c.strokeStyle = '#9ff6ff'; c.lineWidth = r * 0.035; strokePolys(c, CORE_CRACKS, r); c.setLineDash([]);
      c.restore();
    },
    glaze(c, r, t, l, fx) {
      if (!begin(c, fx, 'glaze', 0, -0.2 * r)) return;
      const pink = '#ff6fd1', light = '#ffd0f2';
      c.lineJoin = 'round'; c.lineCap = 'round';
      if (l >= 2) {
        c.beginPath();
        for (let i = 0; i < SHAPE_N; i++) { const x = SHAPE[i * 2] * r * 1.03, y = SHAPE[i * 2 + 1] * r * 1.03; i ? c.lineTo(x, y) : c.moveTo(x, y); }
        c.closePath();
        for (let i = 64; i >= 0; i--) { const a = (i / 64) * TAU, rad = r * (0.8 + 0.035 * Math.sin(7 * a + 1) + 0.02 * Math.sin(13 * a)); i === 64 ? c.moveTo(Math.cos(a) * rad, Math.sin(a) * rad) : c.lineTo(Math.cos(a) * rad, Math.sin(a) * rad); }
        c.closePath();
        const g = c.createLinearGradient(0, -r, 0, r); g.addColorStop(0, '#ff9be3'); g.addColorStop(1, '#ff4fc3');
        c.fillStyle = g; c.fill('evenodd'); c.strokeStyle = 'rgba(160,20,110,.55)'; c.lineWidth = r * 0.015; c.stroke();
        for (let i = 0; i < DRIPS.length; i++) {
          const a = DRIPS[i], x0 = Math.cos(a) * r * 0.97, y0 = Math.sin(a) * r * 0.94;
          const len = r * (0.13 + 0.07 * Math.sin(t * 2.4 + i * 1.7) + (i % 3) * 0.03), w = r * (0.055 + (i % 2) * 0.015), sway = Math.sin(t * 3 + i) * r * 0.012;
          c.fillStyle = '#ff5ccb'; c.beginPath(); c.moveTo(x0 - w, y0 - r * 0.05); c.lineTo(x0 + w, y0 - r * 0.05); c.lineTo(x0 + w * 0.8 + sway, y0 + len); arcS(c, x0 + sway, y0 + len, w * 0.8, 0, Math.PI); c.closePath(); c.fill();
          c.fillStyle = 'rgba(255,255,255,.55)'; c.beginPath(); ellS(c, x0 - w * 0.35 + sway, y0 + len * 0.6, w * 0.18, len * 0.25, 0, 0, TAU); c.fill();
        }
      }
      c.save(); shapePath(c, r, 0.97); c.clip();
      const zz = (ofs, y0, y1) => {
        c.beginPath();
        for (let i = 0; i <= 9; i++) { const x = -r + i * 0.23 * r, y = (i % 2 ? y1 : y0) * r + Math.sin(i * 2.3 + ofs) * r * 0.05; i ? c.quadraticCurveTo(x - 0.115 * r, (y + (i % 2 ? y0 : y1) * r) / 2 + r * 0.06, x, y) : c.moveTo(x, y); }
      };
      c.strokeStyle = 'rgba(120,10,80,.35)'; c.lineWidth = r * 0.085; c.save(); c.translate(0, r * 0.015); zz(0, -0.74, -0.32); c.stroke(); c.restore();
      c.strokeStyle = pink; c.lineWidth = r * 0.075; zz(0, -0.74, -0.32); c.stroke();
      c.strokeStyle = light; c.lineWidth = r * 0.022; c.save(); c.translate(-r * 0.01, -r * 0.018); zz(0, -0.74, -0.32); c.stroke(); c.restore();
      if (l >= 2) { c.strokeStyle = pink; c.lineWidth = r * 0.06; zz(1.7, 0.48, 0.8); c.stroke(); c.strokeStyle = light; c.lineWidth = r * 0.018; c.save(); c.translate(-r * 0.01, -r * 0.015); zz(1.7, 0.48, 0.8); c.stroke(); c.restore(); }
      c.restore();
      c.restore();
    },
    sprinkles(c, r, t, l, fx) {
      if (!begin(c, fx, 'sprinkles', 0, 0)) return;
      const n = l >= 2 ? 90 : 46, len = r * 0.045, w = r * 0.032;
      c.lineCap = 'round';
      if (l >= 2) {
        c.globalCompositeOperation = 'lighter'; c.lineWidth = w * 2.8;
        for (let i = 0; i < n; i += 2) { const [x, y, a] = SPR[i]; c.strokeStyle = hsl(hue(i * 23), 100, 60, 0.22); c.beginPath(); c.moveTo(x * r - Math.cos(a) * len, y * r - Math.sin(a) * len); c.lineTo(x * r + Math.cos(a) * len, y * r + Math.sin(a) * len); c.stroke(); }
        c.globalCompositeOperation = 'source-over'; c.lineWidth = w;
        for (let i = 0; i < n; i++) { const [x, y, a] = SPR[i]; c.strokeStyle = hsl(hue(i * 23), 100, 62); c.beginPath(); c.moveTo(x * r - Math.cos(a) * len, y * r - Math.sin(a) * len); c.lineTo(x * r + Math.cos(a) * len, y * r + Math.sin(a) * len); c.stroke(); }
      } else {
        c.lineWidth = w * 1.5; c.strokeStyle = 'rgba(0,0,0,.25)'; c.beginPath();
        for (let i = 0; i < n; i++) { const [x, y, a] = SPR[i]; c.moveTo(x * r - Math.cos(a) * len + w * 0.3, y * r - Math.sin(a) * len + w * 0.4); c.lineTo(x * r + Math.cos(a) * len + w * 0.3, y * r + Math.sin(a) * len + w * 0.4); }
        c.stroke(); c.lineWidth = w;
        for (let k = 0; k < SPR_COL.length; k++) {
          c.strokeStyle = SPR_COL[k]; c.beginPath();
          for (let i = k; i < n; i += SPR_COL.length) { const [x, y, a] = SPR[i]; c.moveTo(x * r - Math.cos(a) * len, y * r - Math.sin(a) * len); c.lineTo(x * r + Math.cos(a) * len, y * r + Math.sin(a) * len); }
          c.stroke();
        }
      }
      c.restore();
    },
    holo(c, r, t, l, fx, sk) {
      if (!begin(c, fx, 'holo', 0, 0)) return;
      bodyPath(c, r, sk, 0.99); c.clip(); c.globalCompositeOperation = 'lighter';
      const h = hue(0);
      if (c.createConicGradient) {
        const cg = c.createConicGradient(t * 0.6, 0, 0);
        for (let i = 0; i <= 6; i++) cg.addColorStop(i / 6, hsl(h + i * 60, 100, 60, 0.13));
        c.fillStyle = cg; c.fillRect(-r, -r, 2 * r, 2 * r);
      }
      const ph = (t % 2.4) / 2.4, x = lerp(-1.9 * r, 1.9 * r, ph);
      c.rotate(-0.6); const g = c.createLinearGradient(x - r * 0.55, 0, x + r * 0.55, 0);
      g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.25, hsl(h, 100, 65, 0.35)); g.addColorStop(0.5, hsl(h + 60, 100, 80, 0.6));
      g.addColorStop(0.75, hsl(h + 140, 100, 65, 0.35)); g.addColorStop(1, 'rgba(255,255,255,0)');
      c.fillStyle = g; c.fillRect(-2 * r, -2 * r, 4 * r, 4 * r);
      c.restore();
    },
    rgb_rim(c, r, t, l, fx, sk) {
      if (!begin(c, fx, 'rgb_rim', 0, 0)) return;
      const h = hue(0); let g;
      if (c.createConicGradient) { g = c.createConicGradient(t * 1.6, 0, 0); for (let i = 0; i <= 6; i++) g.addColorStop(i / 6, hsl(h + i * 60, 100, 60)); }
      else g = hsl(h, 100, 60);
      c.globalCompositeOperation = 'lighter'; c.strokeStyle = g;
      c.globalAlpha = 0.3; c.lineWidth = r * 0.18; bodyPath(c, r, sk, 1.03); c.stroke();
      c.globalAlpha = 1; c.lineWidth = r * 0.055; c.stroke();
      c.globalCompositeOperation = 'source-over'; c.globalAlpha = 0.85; c.lineWidth = r * 0.014; c.strokeStyle = '#fff'; c.stroke();
      c.restore();
    },
    face(c, r, t, l, fx) {
      if (!begin(c, fx, 'face', 0, 0)) return;
      const ey = EYE_Y * r, er = 0.125 * r;
      c.fillStyle = 'rgba(255,90,160,.5)';
      c.beginPath(); ellS(c, -0.47 * r, 0.14 * r, 0.11 * r, 0.06 * r, 0, 0, TAU); ellS(c, 0.47 * r, 0.14 * r, 0.11 * r, 0.06 * r, 0, 0, TAU); c.fill();
      c.lineCap = 'round'; c.lineJoin = 'round';
      for (let side = -1; side <= 1; side += 2) {
        const x = side * EYE_X * r;
        if (fx.fever) {
          const s = er * (1.25 + 0.15 * Math.sin(t * 12)), heart = Math.floor(t * 2) % 2 === 0;
          if (heart) heartPath(c, x, ey, s * 0.95); else starPath(c, x, ey, s * 1.05, s * 0.45);
          c.fillStyle = heart ? '#ff3b8d' : '#ffd23c'; c.fill(); c.strokeStyle = INK; c.lineWidth = r * 0.03; c.stroke();
          c.fillStyle = 'rgba(255,255,255,.8)'; c.beginPath(); arcS(c, x - s * 0.3, ey - s * 0.25, s * 0.16, 0, TAU); c.fill();
        } else if (fx.blink > 0.5) {
          c.strokeStyle = INK; c.lineWidth = r * 0.035; c.beginPath(); arcS(c, x, ey - er * 0.35, er * 0.8, 0.2 * Math.PI, 0.8 * Math.PI); c.stroke();
        } else {
          c.fillStyle = '#fff'; c.beginPath(); ellS(c, x, ey, er, er * 1.12, 0, 0, TAU); c.fill();
          c.strokeStyle = INK; c.lineWidth = r * 0.03; c.stroke();
          const ox = (fx.lx || 0) * er * 0.38, oy = (fx.ly || 0) * er * 0.42;
          c.fillStyle = INK; c.beginPath(); arcS(c, x + ox, ey + oy, er * 0.62, 0, TAU); c.fill();
          c.fillStyle = '#fff'; c.beginPath(); arcS(c, x + ox - er * 0.24, ey + oy - er * 0.26, er * 0.2, 0, TAU); arcS(c, x + ox + er * 0.2, ey + oy + er * 0.2, er * 0.09, 0, TAU); c.fill();
        }
      }
      const m = fx.mouth || 0, my = 0.17 * r;
      if (m > 0.06) {
        const hgt = r * (0.05 + 0.17 * m);
        c.beginPath(); c.moveTo(-0.15 * r, my); c.lineTo(0.15 * r, my); ellS(c, 0, my, 0.15 * r, hgt, 0, 0, Math.PI); c.closePath();
        c.fillStyle = '#5a0a1f'; c.fill();
        c.save(); c.clip(); c.fillStyle = '#ff6b8a'; c.beginPath(); ellS(c, 0, my + hgt, 0.09 * r, hgt * 0.5, 0, 0, TAU); c.fill(); c.restore();
        c.strokeStyle = INK; c.lineWidth = r * 0.03; c.stroke();
      } else {
        c.strokeStyle = INK; c.lineWidth = r * 0.035; c.beginPath(); arcS(c, 0, my - 0.07 * r, 0.1 * r, 0.18 * Math.PI, 0.82 * Math.PI); c.stroke();
      }
      c.restore();
    },
    laser_eyes(c, r, t, l, fx) {
      const k = 0.35 + 0.2 * Math.sin(t * 6) + (fx.laser || 0) * 0.9, s = r * (0.34 + (fx.laser || 0) * 0.35);
      c.save(); c.globalCompositeOperation = 'lighter'; c.globalAlpha = clamp(k, 0, 1);
      const img = glowSprite('#ff2b3b');
      c.drawImage(img, -EYE_X * r - s / 2, EYE_Y * r - s / 2, s, s); c.drawImage(img, EYE_X * r - s / 2, EYE_Y * r - s / 2, s, s);
      c.restore();
    },
    shades(c, r, t, l, fx) {
      const d = fx.drop ? fx.drop() : 1; if (d <= 0) return;
      const p = 0.047 * r, x0 = -12 * p, y0 = EYE_Y * r - 2.1 * p - (1 - d) * r * 2.4;
      c.save(); if (d < 1) { c.translate(0, y0); c.rotate((1 - d) * 0.5); c.translate(0, -y0); c.globalAlpha *= clamp(d * 3, 0, 1); }
      c.fillStyle = '#0a0612'; c.beginPath();
      for (let j = 0; j < SHADES.length; j++) for (let i = 0; i < 24; i++) if (SHADES[j][i] !== '.') c.rect(x0 + i * p - 0.3, y0 + j * p - 0.3, p + 0.6, p + 0.6);
      c.rect(x0 - 2 * p, y0, 2 * p + 0.5, p); c.rect(x0 + 24 * p - 0.5, y0, 2 * p, p);
      c.fill();
      c.fillStyle = '#ffffff'; c.beginPath();
      for (let j = 0; j < SHADES.length; j++) for (let i = 0; i < 24; i++) if (SHADES[j][i] === 'W') c.rect(x0 + i * p, y0 + j * p, p, p);
      c.fill();
      c.restore();
    },
    headphones(c, r, t, l, fx) {
      if (!begin(c, fx, 'headphones', 0, -0.4 * r)) return;
      const h0 = hue(0);
      c.lineCap = 'round';
      c.beginPath(); arcS(c, 0, 0.04 * r, 1.08 * r, Math.PI * 1.06, Math.PI * 1.94);
      c.strokeStyle = INK; c.lineWidth = r * 0.15; c.stroke();
      c.strokeStyle = '#3a2a5c'; c.lineWidth = r * 0.09; c.stroke();
      c.save(); c.globalCompositeOperation = 'lighter'; c.strokeStyle = hsl(h0, 100, 60); c.lineWidth = r * 0.025; c.stroke(); c.restore();
      c.beginPath(); c.moveTo(-0.95 * r, 0.12 * r); c.quadraticCurveTo(-0.95 * r, 0.5 * r, -0.42 * r, 0.44 * r);
      c.strokeStyle = INK; c.lineWidth = r * 0.055; c.stroke(); c.strokeStyle = '#3a2a5c'; c.lineWidth = r * 0.03; c.stroke();
      c.save(); c.globalCompositeOperation = 'lighter'; c.drawImage(glowSprite(hq(h0 + 180)), -0.42 * r - r * 0.12, 0.44 * r - r * 0.12, r * 0.24, r * 0.24); c.restore();
      c.fillStyle = INK; c.beginPath(); arcS(c, -0.42 * r, 0.44 * r, r * 0.045, 0, TAU); c.fill();
      for (let side = -1; side <= 1; side += 2) {
        const x = side * 1.0 * r, y = 0.04 * r;
        c.save(); c.globalCompositeOperation = 'lighter'; c.globalAlpha = 0.7; const gs = r * 0.8; c.drawImage(glowSprite(hq(h0 + side * 90)), x - gs / 2, y - gs / 2, gs, gs); c.restore();
        rrect(c, x - 0.14 * r, y - 0.23 * r, 0.28 * r, 0.46 * r, 0.11 * r);
        const g = c.createLinearGradient(x - 0.14 * r, 0, x + 0.14 * r, 0); g.addColorStop(0, '#3a2a5c'); g.addColorStop(1, '#140b28');
        c.fillStyle = g; c.fill(); c.strokeStyle = INK; c.lineWidth = r * 0.03; c.stroke();
        rrect(c, x - 0.085 * r, y - 0.16 * r, 0.17 * r, 0.32 * r, 0.07 * r);
        c.save(); c.globalCompositeOperation = 'lighter'; c.strokeStyle = hsl(h0 + side * 90, 100, 62); c.lineWidth = r * 0.035; c.stroke(); c.restore();
        c.fillStyle = 'rgba(255,255,255,.35)'; c.beginPath(); ellS(c, x - 0.06 * r * side, y - 0.14 * r, 0.03 * r, 0.06 * r, 0, 0, TAU); c.fill();
      }
      c.restore();
    },
    bling(c, r, t, l, fx) {
      if (!begin(c, fx, 'bling', 0, 0.7 * r)) return;
      const big = l >= 2, sw = Math.sin(t * 2.1) * 0.12 + (fx.swing || 0);
      const ax = -0.66 * r, ay = 0.38 * r, bx = 0.66 * r, by = 0.38 * r, qx = sw * r * 0.4, qy = 1.12 * r;
      const n = 22, linkR = r * (big ? 0.042 : 0.034);
      for (let pass = 0; pass < 2; pass++) {
        for (let i = 0; i <= n; i++) {
          const k = i / n, u = 1 - k;
          const x = u * u * ax + 2 * u * k * qx + k * k * bx, y = u * u * ay + 2 * u * k * qy + k * k * by;
          const tx = 2 * u * (qx - ax) + 2 * k * (bx - qx), ty = 2 * u * (qy - ay) + 2 * k * (by - qy), a = Math.atan2(ty, tx);
          c.beginPath(); ellS(c, x, y, linkR * 1.25, linkR * (i % 2 ? 0.55 : 0.9), a, 0, TAU);
          if (pass === 0) { c.strokeStyle = INK; c.lineWidth = linkR * 0.95; c.stroke(); }
          else { c.strokeStyle = big ? (i % 3 ? '#fff6cf' : '#bff6ff') : i % 2 ? '#ffd23c' : '#ffe98a'; c.lineWidth = linkR * 0.5; c.stroke(); }
        }
      }
      const bx0 = 0.25 * ax + 0.5 * qx + 0.25 * bx, by0 = 0.25 * ay + 0.5 * qy + 0.25 * by;
      const rad = r * (big ? 0.24 : 0.18), len = rad + r * 0.06, ma = sw * 1.4, mx = bx0 + Math.sin(ma) * len, my = by0 + Math.cos(ma) * len;
      c.strokeStyle = INK; c.lineWidth = r * 0.03; c.beginPath(); c.moveTo(bx0, by0); c.lineTo(bx0 + Math.sin(ma) * (len - rad), by0 + Math.cos(ma) * (len - rad)); c.stroke();
      const g = radG(c, mx - rad * 0.35, my - rad * 0.4, rad * 0.1, mx, my, rad);
      g.addColorStop(0, '#fff6c8'); g.addColorStop(0.5, '#ffcc33'); g.addColorStop(1, '#c98a00');
      c.fillStyle = g; c.beginPath(); arcS(c, mx, my, rad, 0, TAU); c.fill(); c.strokeStyle = INK; c.lineWidth = r * 0.03; c.stroke();
      c.strokeStyle = '#b37400'; c.lineWidth = r * 0.015; c.beginPath(); arcS(c, mx, my, rad * 0.78, 0, TAU); c.stroke();
      c.font = `${Math.round(rad * 0.95)}px ${FONT_D}`; c.textAlign = 'center'; c.textBaseline = 'middle';
      c.fillStyle = '#fff3b0'; c.fillText('CO', mx - rad * 0.04, my - rad * 0.02); c.fillStyle = '#8a5a00'; c.fillText('CO', mx, my + rad * 0.04);
      if (big) {
        for (let i = 0; i < 12; i++) { const a = (i / 12) * TAU; c.fillStyle = i % 2 ? '#e8fdff' : '#9ff3ff'; c.beginPath(); arcS(c, mx + Math.cos(a) * rad * 0.9, my + Math.sin(a) * rad * 0.9, rad * 0.1, 0, TAU); c.fill(); }
        c.save(); c.globalCompositeOperation = 'lighter';
        for (let i = 0; i < 3; i++) { const gl = Math.pow(Math.max(0, Math.sin(t * 3 + i * 2.1)), 3), z = rad * 1.6 * gl; if (z < 1) continue; const a = i * 2.1 + 0.5; c.drawImage(sparkSprite('#ffffff'), mx + Math.cos(a) * rad * 0.9 - z / 2, my + Math.sin(a) * rad * 0.9 - z / 2, z, z); }
        c.restore();
      }
      c.restore();
    },
    crown(c, r, t, l, fx) {
      const ax = 0.2 * r, ay = -0.9 * r + (fx.cb || 0) * r;
      if (!begin(c, fx, 'crown', ax, ay)) return;
      c.translate(ax, ay); c.rotate(0.22 + Math.sin(t * 1.3) * 0.04);
      const w = 0.72 * r, h = 0.44 * r;
      c.lineJoin = 'round';
      c.beginPath(); c.moveTo(-w / 2, 0); c.lineTo(-w / 2, -h); c.lineTo(-w / 4, -h * 0.48); c.lineTo(0, -h * 1.15); c.lineTo(w / 4, -h * 0.48); c.lineTo(w / 2, -h); c.lineTo(w / 2, 0); c.closePath();
      const g = c.createLinearGradient(0, -h, 0, 0); g.addColorStop(0, '#fff2a8'); g.addColorStop(0.5, '#ffc93c'); g.addColorStop(1, '#d99100');
      c.fillStyle = g; c.fill(); c.strokeStyle = INK; c.lineWidth = r * 0.035; c.stroke();
      rrect(c, -w / 2 - r * 0.02, -h * 0.26, w + r * 0.04, h * 0.3, r * 0.03);
      const g2 = c.createLinearGradient(0, -h * 0.26, 0, h * 0.04); g2.addColorStop(0, '#ffd966'); g2.addColorStop(1, '#b87700');
      c.fillStyle = g2; c.fill(); c.stroke();
      const peaks = [[-w / 2, -h], [0, -h * 1.15], [w / 2, -h]];
      for (const [x, y] of peaks) { c.fillStyle = '#fff6c8'; c.beginPath(); arcS(c, x, y, r * 0.055, 0, TAU); c.fill(); c.lineWidth = r * 0.025; c.stroke(); }
      const jw = [['#ff3b6b', -w * 0.3], ['#1ff4ff', 0], ['#3dff8a', w * 0.3]];
      for (const [col, x] of jw) {
        c.fillStyle = col; c.beginPath(); ellS(c, x, -h * 0.11, r * 0.055, r * 0.065, 0, 0, TAU); c.fill(); c.lineWidth = r * 0.02; c.stroke();
        c.fillStyle = 'rgba(255,255,255,.8)'; c.beginPath(); arcS(c, x - r * 0.018, -h * 0.11 - r * 0.022, r * 0.016, 0, TAU); c.fill();
      }
      c.fillStyle = 'rgba(255,255,255,.55)'; c.beginPath(); c.moveTo(-w * 0.42, -h * 0.35); c.lineTo(-w * 0.42, -h * 0.82); c.lineTo(-w * 0.34, -h * 0.5); c.closePath(); c.fill();
      const gl = Math.pow(Math.max(0, Math.sin(t * 2.2)), 6), z = r * 0.45 * gl;
      if (z > 1) { c.globalCompositeOperation = 'lighter'; c.drawImage(sparkSprite('#fff6c8'), -z / 2, -h * 1.15 - z / 2, z, z); }
      c.restore();
    },
    halo(c, r, t, l, fx) {
      const y = -1.3 * r + Math.sin(t * 2) * 0.05 * r;
      if (!begin(c, fx, 'halo', 0, y)) return;
      c.globalCompositeOperation = 'lighter';
      c.beginPath(); ellS(c, 0, y, 0.48 * r, 0.12 * r, 0, 0, TAU);
      c.strokeStyle = 'rgba(255,215,110,.3)'; c.lineWidth = r * 0.17; c.stroke();
      c.strokeStyle = '#ffe07a'; c.lineWidth = r * 0.065; c.stroke();
      c.strokeStyle = '#fffbe6'; c.lineWidth = r * 0.022; c.stroke();
      c.globalAlpha = 0.5; c.drawImage(glowSprite('#ffe9a0'), -r * 0.7, y - r * 0.35, r * 1.4, r * 0.7);
      c.restore();
    },
    wings(c, r, t, l, fx) {
      if (!begin(c, fx, 'wings', 0, 0)) return;
      const spd = 3 + (fx.heat || 0) * 10, flap = Math.sin(t * spd) * 0.24, h0 = hue(0);
      c.lineJoin = 'round'; c.lineCap = 'round';
      for (let side = -1; side <= 1; side += 2) {
        c.save(); c.scale(side, 1); c.translate(0.7 * r, -0.12 * r); c.rotate(-flap - 0.12);
        const col = side < 0 ? h0 + 180 : h0;
        for (let pass = 0; pass < 2; pass++) {
          for (let i = 4; i >= 0; i--) {
            const ang = -1.05 + i * 0.3, len = r * (1.3 - i * 0.13);
            c.beginPath(); c.moveTo(0, 0);
            c.quadraticCurveTo(Math.cos(ang - 0.28) * len * 0.62, Math.sin(ang - 0.28) * len * 0.62, Math.cos(ang) * len, Math.sin(ang) * len);
            c.quadraticCurveTo(Math.cos(ang + 0.26) * len * 0.55, Math.sin(ang + 0.26) * len * 0.55, 0, 0);
            if (pass === 0) { c.fillStyle = hsl(col + i * 16, 100, 72, 0.3); c.fill(); }
            else { c.globalCompositeOperation = 'lighter'; c.strokeStyle = hsl(col + i * 16, 100, 60, 0.4); c.lineWidth = r * 0.1; c.stroke(); c.strokeStyle = hsl(col + i * 16, 100, 80); c.lineWidth = r * 0.03; c.stroke(); c.globalCompositeOperation = 'source-over'; }
          }
        }
        c.restore();
      }
      c.restore();
    },
  };
  const BODY_KEYS = ['chips_xl', 'crystals', 'galaxy_core'];
  const TOP_KEYS = ['glaze', 'sprinkles', 'holo', 'rgb_rim', 'face', 'laser_eyes', 'shades', 'headphones', 'bling', 'crown', 'halo'];

  function extFx(o, x, y, t) {
    let lx = 0, ly = 0;
    if (o.look && isFinite(o.look.x)) {
      let dx = o.look.x - x, dy = o.look.y - y; const rot = o.rot || 0;
      if (rot) { const c0 = Math.cos(-rot), s0 = Math.sin(-rot); const nx = dx * c0 - dy * s0; dy = dx * s0 + dy * c0; dx = nx; }
      const d = Math.hypot(dx, dy) || 1, k = Math.min(1, d / 80); lx = (dx / d) * k; ly = (dy / d) * k;
    }
    return { lx, ly, blink: (t % 4.3) < 0.13 ? 1 : 0, mouth: 0, fever: feverOn(), heat: (CO.combo && CO.combo.heat) || 0 };
  }

  /** Reusable cookie painter (stage, minigames, UI thumbnails). */
  function drawCookie(c, x, y, r, o) {
    o = o || {};
    if (!(r > 0.5) || !c) return;
    const sk = skinDef(o.skin), t = o.t != null ? o.t : CO.now ? CO.now() : performance.now() / 1000;
    c.save(); c.translate(x, y); if (o.rot) c.rotate(o.rot);
    const sq = o.squash || 0; if (sq) c.scale(1 + 0.14 * sq, 1 - 0.14 * sq);
    if (o.simple) { drawBase(c, sk, r, t, false); c.restore(); return; }
    const vis = o.accessories ? o.vis || CO.vis || {} : null;
    const fx = o._fx || extFx(o, x, y, t);
    if (vis && vis.wings) ACC.wings(c, r, t, vis.wings, fx, sk);
    c.save(); if (fx.spin) c.rotate(fx.spin);
    drawBase(c, sk, r, t, true);
    if (vis) for (let i = 0; i < BODY_KEYS.length; i++) { const k = BODY_KEYS[i]; if (vis[k]) ACC[k](c, r, t, vis[k], fx, sk); }
    c.restore();
    if (vis) for (let i = 0; i < TOP_KEYS.length; i++) { const k = TOP_KEYS[i]; if (vis[k]) ACC[k](c, r, t, vis[k], fx, sk); }
    c.restore();
  }

  /* ═════════════════════════ themes (full-screen animated backgrounds) ═════════════════════════ */
  const STARS = []; { const rng = mulberry32(2024); for (let i = 0; i < 220; i++) STARS.push({ x: rng(), y: rng(), s: 0.5 + rng() * 1.6, ph: rng() * TAU, l: (rng() * 3) | 0 }); }
  const MOUNT = []; { const rng = mulberry32(55); for (let i = 0; i <= 40; i++) MOUNT.push(0.3 + rng() * 0.7 * (0.5 + 0.5 * Math.sin(i * 0.7))); }
  let NEB = null;
  function nebula() {
    if (NEB) return NEB; NEB = mk(256); const g = NEB.getContext('2d');
    const blobs = [[0.28, 0.38, 0.5, 'rgba(122,44,255,.75)'], [0.72, 0.64, 0.45, 'rgba(255,61,154,.6)'], [0.58, 0.22, 0.32, 'rgba(31,184,255,.45)'], [0.18, 0.78, 0.35, 'rgba(60,20,160,.6)'], [0.86, 0.2, 0.28, 'rgba(255,120,200,.35)']];
    g.globalCompositeOperation = 'lighter';
    for (const [x, y, r, col] of blobs) { const gr = radG(g, x * 256, y * 256, 0, x * 256, y * 256, r * 256); gr.addColorStop(0, col); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, 256, 256); }
    return NEB;
  }
  let AUR = null;
  function auroraStrips() {
    if (AUR) return AUR; AUR = ['#2bffb0', '#1fd6ff', '#8a5cff', '#ff4fd8'].map((col) => {
      const s = mk(4, 128), g = s.getContext('2d'), gr = g.createLinearGradient(0, 0, 0, 128);
      gr.addColorStop(0, rgba(col, 0)); gr.addColorStop(0.6, rgba(col, 0.25)); gr.addColorStop(0.9, rgba(col, 0.85)); gr.addColorStop(1, rgba(col, 0));
      g.fillStyle = gr; g.fillRect(0, 0, 4, 128); return s;
    });
    return AUR;
  }
  let CANDY = null;
  function candySprites() {
    if (CANDY) return CANDY;
    const make = (kind, c1, c2) => {
      const s = mk(96), g = s.getContext('2d'); g.translate(48, 48); g.lineJoin = 'round'; g.lineWidth = 4; g.strokeStyle = 'rgba(80,20,90,.6)';
      if (kind === 0) {
        for (const d of [-1, 1]) { g.beginPath(); g.moveTo(d * 18, 0); g.lineTo(d * 42, -16); g.lineTo(d * 38, 0); g.lineTo(d * 42, 16); g.closePath(); g.fillStyle = c2; g.fill(); g.stroke(); }
        g.beginPath(); arcS(g, 0, 0, 21, 0, TAU); g.fillStyle = c1; g.fill(); g.stroke();
        g.strokeStyle = 'rgba(255,255,255,.7)'; g.lineWidth = 5; g.beginPath(); arcS(g, 0, 0, 13, -2.4, -1.2); g.stroke();
      } else if (kind === 1) {
        g.fillStyle = '#fff'; g.fillRect(-3, 10, 6, 36); g.strokeRect(-3, 10, 6, 36);
        g.beginPath(); arcS(g, 0, -6, 24, 0, TAU); g.fillStyle = c1; g.fill(); g.stroke();
        g.strokeStyle = c2; g.lineWidth = 6; g.beginPath(); for (let a = 0; a < 14; a += 0.2) { const rr = a * 1.6; a ? g.lineTo(Math.cos(a) * rr, -6 + Math.sin(a) * rr) : g.moveTo(0, -6); } g.stroke();
      } else {
        g.beginPath(); for (let i = 0; i < 10; i++) { const a = (i / 10) * TAU, rr = i % 2 ? 22 : 30; i ? g.lineTo(Math.cos(a) * rr, Math.sin(a) * rr) : g.moveTo(Math.cos(a) * rr, Math.sin(a) * rr); } g.closePath();
        g.fillStyle = c1; g.fill(); g.stroke(); g.fillStyle = c2; g.beginPath(); arcS(g, 0, 0, 11, 0, TAU); g.fill();
      }
      return s;
    };
    CANDY = [make(0, '#ff6fb5', '#ffd1e8'), make(1, '#8fe3ff', '#ff6fd1'), make(2, '#ffe36f', '#ff8ad1'), make(0, '#9dff8a', '#fff3a0'), make(1, '#ffb36f', '#ffffff'), make(2, '#c7a0ff', '#ffffff')];
    return CANDY;
  }
  const BUBBLES = []; for (let i = 0; i < 28; i++) BUBBLES.push({ x: Math.random(), y: Math.random(), r: rand(8, 34), sp: rand(12, 40), ph: Math.random() * TAU, k: i % 6, candy: i < 10 });
  const EMBERS = []; for (let i = 0; i < 80; i++) EMBERS.push({ x: Math.random(), y: Math.random(), sp: rand(30, 110), s: rand(3, 9), ph: Math.random() * TAU });
  let MX = null, MXG = null, MXcols = [], mxAcc = 0;
  const GLYPHS = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン0123456789';
  function mxInit() {
    MX = mk(Math.ceil(W), Math.ceil(H)); MXG = MX.getContext('2d');
    MXG.fillStyle = '#010a06'; MXG.fillRect(0, 0, MX.width, MX.height);
    const n = Math.ceil(W / 18); MXcols = [];
    for (let i = 0; i < n; i++) MXcols.push({ y: -Math.floor(Math.random() * 40), sp: Math.random() < 0.3 ? 2 : 1, prev: '' });
  }
  function mxStep() {
    const g = MXG, cell = 18, fev = feverOn();
    g.fillStyle = 'rgba(1,10,6,0.13)'; g.fillRect(0, 0, MX.width, MX.height);
    g.font = `600 15px ${FONT_M}`; g.textAlign = 'center'; g.textBaseline = 'middle';
    for (let i = 0; i < MXcols.length; i++) {
      const col = MXcols[i];
      for (let s = 0; s < col.sp; s++) {
        const x = i * cell + cell / 2, y = col.y * cell;
        if (col.prev) { g.fillStyle = fev ? hq(hue(i * 12), 55) : '#19e57a'; g.fillText(col.prev, x, y - cell); }
        if (Math.random() < 0.025) { drawCookie(g, x, y, 6.5, { simple: true, rot: Math.random() * TAU }); col.prev = ''; }
        else { const ch = GLYPHS[(Math.random() * GLYPHS.length) | 0]; g.fillStyle = fev ? '#ffffff' : '#d8ffe8'; g.fillText(ch, x, y); col.prev = ch; }
        col.y++;
        if (y > MX.height && Math.random() > 0.96) { col.y = -Math.floor(Math.random() * 10); col.prev = ''; }
      }
    }
  }
  const THEMES = {
    synthwave(c, t) {
      const hz = H * 0.63, h0 = hue(0);
      let g = c.createLinearGradient(0, 0, 0, hz);
      g.addColorStop(0, '#0e0224'); g.addColorStop(0.5, '#3c0f66'); g.addColorStop(0.82, '#9c2489'); g.addColorStop(1, '#ff4fa3');
      c.fillStyle = g; c.fillRect(0, 0, W, hz);
      c.fillStyle = '#ffffff';
      for (let i = 0; i < 90; i++) { const s = STARS[i]; if (s.y > 0.55) continue; c.globalAlpha = 0.3 + 0.5 * Math.abs(Math.sin(t * 1.3 + s.ph)); c.fillRect(s.x * W, s.y * hz, s.s, s.s); }
      c.globalAlpha = 1;
      const sr = Math.min(W, H) * 0.22, sx = CX, sy = hz - sr * 0.55;
      c.save(); c.globalCompositeOperation = 'lighter'; c.globalAlpha = 0.55; spr(c, glowSprite('#ff4f9a'), sx, sy, sr * 4.2); c.restore();
      const sky = g;
      c.save(); c.beginPath(); arcS(c, sx, sy, sr, 0, TAU);
      g = c.createLinearGradient(0, sy - sr, 0, sy + sr * 0.45); g.addColorStop(0, '#fff45c'); g.addColorStop(0.5, '#ffa02e'); g.addColorStop(1, '#ff2d8e');
      c.fillStyle = g; c.fill(); c.clip();
      const per = sr * 0.13, off = (t * 10) % per; c.fillStyle = sky; c.beginPath();
      for (let y = sy - sr * 0.4 + off; y < sy + sr; y += per) { const k = clamp((y - (sy - sr * 0.4)) / (sr * 0.9), 0, 1); c.rect(sx - sr, y, sr * 2, per * (0.1 + 0.55 * k)); }
      c.fill(); c.restore();
      c.fillStyle = '#1b0634'; c.beginPath(); c.moveTo(0, hz);
      for (let i = 0; i <= 40; i++) { const x = (i / 40) * W, dist = Math.abs(x - CX) / (W * 0.5); c.lineTo(x, hz - MOUNT[i] * H * 0.09 * (0.25 + dist)); }
      c.lineTo(W, hz); c.closePath(); c.fill();
      c.save(); c.globalCompositeOperation = 'lighter'; c.strokeStyle = hsl(h0 + 300, 100, 60, 0.55); c.lineWidth = 1.5; c.stroke(); c.restore();
      g = c.createLinearGradient(0, hz, 0, H); g.addColorStop(0, '#2a0648'); g.addColorStop(1, '#06010e');
      c.fillStyle = g; c.fillRect(0, hz, W, H - hz);
      c.save(); c.beginPath(); c.rect(0, hz, W, H - hz); c.clip(); c.globalCompositeOperation = 'lighter';
      const spd = feverOn() ? 2.4 : 0.55, frac = (t * spd) % 1, camH = (H - hz) * 1.1;
      const col = hsl(h0 + 290, 100, 62);
      for (let pass = 0; pass < 2; pass++) {
        c.strokeStyle = col; c.lineWidth = pass ? 1.4 : 5; c.globalAlpha = pass ? 0.9 : 0.18; c.beginPath();
        for (let i = -16; i <= 16; i++) { c.moveTo(CX + i * 14, hz); c.lineTo(CX + i * W * 0.1, H); }
        for (let k = 1; k < 26; k++) { const d = k - frac; if (d <= 0.2) continue; const y = hz + camH / (d * 0.9); if (y > H) continue; c.moveTo(0, y); c.lineTo(W, y); }
        c.stroke();
      }
      c.globalAlpha = 1; g = c.createLinearGradient(0, hz - 30, 0, hz + 40); g.addColorStop(0, 'rgba(255,80,190,0)'); g.addColorStop(0.45, 'rgba(255,80,190,.45)'); g.addColorStop(1, 'rgba(255,80,190,0)');
      c.fillStyle = g; c.fillRect(0, hz - 30, W, 70); c.restore();
      g = c.createLinearGradient(0, hz, 0, hz + (H - hz) * 0.35); g.addColorStop(0, 'rgba(6,1,14,.7)'); g.addColorStop(1, 'rgba(6,1,14,0)');
      c.fillStyle = g; c.fillRect(0, hz, W, (H - hz) * 0.35);
    },
    galaxy(c, t) {
      c.fillStyle = '#070214'; c.fillRect(0, 0, W, H);
      const n = nebula(), big = Math.max(W, H) * 1.3;
      c.save(); c.globalCompositeOperation = 'lighter';
      c.translate(W / 2, H / 2); c.rotate(t * 0.01); c.globalAlpha = 0.9; c.drawImage(n, -big / 2 + Math.sin(t * 0.05) * 40, -big / 2, big, big);
      c.rotate(2.2); c.globalAlpha = 0.45; c.drawImage(n, -big * 0.4, -big * 0.4, big * 0.8, big * 0.8);
      c.restore();
      const px = ptr.x > -999 ? (ptr.x - W / 2) / W : 0, py = ptr.x > -999 ? (ptr.y - H / 2) / H : 0;
      c.fillStyle = '#ffffff';
      for (let i = 0; i < STARS.length; i++) {
        const s = STARS[i], L = s.l + 1, x = (((s.x * W + t * 4 * L - px * 12 * L) % W) + W) % W, y = (((s.y * H - py * 12 * L) % H) + H) % H;
        c.globalAlpha = 0.25 + 0.75 * Math.abs(Math.sin(t * (0.6 + s.l * 0.5) + s.ph)); const z = s.s * (0.6 + L * 0.35);
        c.fillRect(x, y, z, z);
      }
      c.globalAlpha = 1;
      const sp = (t * 0.23) % 1, si = Math.floor(t * 0.23);
      if (sp < 0.12) {
        const rng = mulberry32(si * 13 + 1), x0 = rng() * W, y0 = rng() * H * 0.4, k = sp / 0.12;
        c.save(); c.globalCompositeOperation = 'lighter'; c.strokeStyle = `rgba(220,240,255,${(1 - k).toFixed(2)})`; c.lineWidth = 2; c.beginPath();
        c.moveTo(x0 + k * 300, y0 + k * 120); c.lineTo(x0 + k * 300 - 90, y0 + k * 120 - 36); c.stroke(); c.restore();
      }
    },
    matrix(c, t, dt) {
      if (!MX || MX.width !== Math.ceil(W) || MX.height !== Math.ceil(H)) mxInit();
      mxAcc += dt; let steps = 0; while (mxAcc > 0.06 && steps < 3) { mxStep(); mxAcc -= 0.06; steps++; } if (mxAcc > 0.2) mxAcc = 0;
      c.drawImage(MX, 0, 0, W, H);
      const g = radG(c, CX, CY, 0, CX, CY, Math.max(W, H) * 0.7); g.addColorStop(0, 'rgba(0,40,20,.25)'); g.addColorStop(1, 'rgba(0,0,0,.35)');
      c.fillStyle = g; c.fillRect(0, 0, W, H);
    },
    candy(c, t, dt) {
      const sh = Math.sin(t * 0.2) * 0.15, g = c.createLinearGradient(0, 0, W, H);
      g.addColorStop(0, '#ff9ad9'); g.addColorStop(clamp(0.5 + sh, 0.2, 0.8), '#9fd8ff'); g.addColorStop(1, '#ffe79a');
      c.fillStyle = g; c.fillRect(0, 0, W, H);
      const cs = candySprites();
      for (let i = 0; i < BUBBLES.length; i++) {
        const b = BUBBLES[i]; b.y -= (b.sp * dt) / H; if (b.y < -0.1) { b.y = 1.1; b.x = Math.random(); }
        const x = b.x * W + Math.sin(t * 0.8 + b.ph) * 18, y = b.y * H;
        if (b.candy) { const s = b.r * 2.4; c.globalAlpha = 0.6; c.save(); c.translate(x, y); c.rotate(t * 0.4 + b.ph); c.drawImage(cs[b.k], -s / 2, -s / 2, s, s); c.restore(); }
        else {
          c.globalAlpha = 1; c.fillStyle = 'rgba(255,255,255,.14)'; c.strokeStyle = 'rgba(255,255,255,.55)'; c.lineWidth = 1.5;
          c.beginPath(); arcS(c, x, y, b.r, 0, TAU); c.fill(); c.stroke();
          c.strokeStyle = 'rgba(255,255,255,.8)'; c.lineWidth = 2.5; c.beginPath(); arcS(c, x, y, b.r * 0.7, -2.5, -1.6); c.stroke();
        }
      }
      c.globalAlpha = 1; c.fillStyle = 'rgba(34,8,62,.42)'; c.fillRect(0, 0, W, H);
    },
    inferno(c, t, dt) {
      let g = radG(c, W / 2, H * 1.15, 0, W / 2, H * 1.15, H * 1.25);
      g.addColorStop(0, '#ff7a1a'); g.addColorStop(0.3, '#c8200c'); g.addColorStop(0.65, '#4a0605'); g.addColorStop(1, '#120101');
      c.fillStyle = g; c.fillRect(0, 0, W, H);
      c.save(); c.globalCompositeOperation = 'lighter';
      for (let i = 0; i < 5; i++) {
        const by = H * (0.45 + i * 0.12); c.fillStyle = `rgba(255,110,30,${0.05 + i * 0.01})`; c.beginPath(); c.moveTo(0, by + 40);
        for (let x = 0; x <= W + 20; x += 20) c.lineTo(x, by + Math.sin(x * 0.012 + t * (1.5 + i * 0.3) + i) * 10 + Math.sin(x * 0.031 - t * 2) * 4);
        c.lineTo(W, by + 40); c.closePath(); c.fill();
      }
      const fe = feverOn();
      for (let i = 0; i < EMBERS.length; i++) {
        const e = EMBERS[i]; e.y -= (e.sp * dt * (fe ? 2 : 1)) / H; if (e.y < -0.05) { e.y = 1.05; e.x = Math.random(); }
        const x = e.x * W + Math.sin(t * 1.5 + e.ph) * 20, y = e.y * H;
        c.globalAlpha = clamp(e.y * 1.4, 0, 1) * (0.6 + 0.4 * Math.sin(t * 7 + e.ph)); spr(c, glowSprite(i % 3 ? '#ff7a1a' : '#ffd23c'), x, y, e.s * 3.2);
      }
      c.restore(); c.globalAlpha = 1;
      c.fillStyle = '#140202'; c.beginPath(); c.moveTo(0, H);
      for (let i = 0; i <= 40; i++) c.lineTo((i / 40) * W, H - MOUNT[(i + 13) % 41] * H * 0.11 - 10);
      c.lineTo(W, H); c.closePath(); c.fill(); c.strokeStyle = 'rgba(255,100,20,.5)'; c.lineWidth = 2; c.stroke();
    },
    aurora(c, t) {
      let g = c.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#01121a'); g.addColorStop(0.6, '#03262c'); g.addColorStop(1, '#010c14');
      c.fillStyle = g; c.fillRect(0, 0, W, H);
      c.fillStyle = '#ffffff';
      for (let i = 0; i < 140; i++) { const s = STARS[i]; if (s.y > 0.75) continue; c.globalAlpha = 0.2 + 0.6 * Math.abs(Math.sin(t * 0.9 + s.ph)); c.fillRect(s.x * W, s.y * H, s.s * 0.8, s.s * 0.8); }
      c.globalAlpha = 1;
      const strips = auroraStrips(), rib = [[0.2, 0.05, 0.004, 0.35, 0, 0.3], [0.3, 0.06, 0.0033, -0.28, 1, 0.26], [0.26, 0.04, 0.0052, 0.22, 2, 0.2], [0.38, 0.05, 0.0028, 0.3, 3, 0.18]];
      c.save(); c.globalCompositeOperation = 'lighter';
      const step = W > 900 ? 7 : 5;
      for (const [yy, amp, fq, sp, si, hh] of rib) {
        const img = strips[si]; c.globalAlpha = feverOn() ? 0.85 : 0.6;
        for (let x = 0; x < W; x += step) {
          const y = H * yy + Math.sin(x * fq + t * sp) * H * amp + Math.sin(x * fq * 2.3 - t * sp * 0.7) * H * amp * 0.4;
          const h = H * hh * (0.65 + 0.35 * Math.sin(x * 0.004 + t * 0.6 + si));
          c.drawImage(img, x, y - h, step + 1, h);
        }
      }
      c.restore(); c.globalAlpha = 1;
      c.fillStyle = '#010a0f'; c.beginPath(); c.moveTo(0, H);
      for (let i = 0; i <= 40; i++) c.lineTo((i / 40) * W, H - MOUNT[(i + 7) % 41] * H * 0.1 - 8 - (i % 3 === 0 ? 14 : 0));
      c.lineTo(W, H); c.closePath(); c.fill();
    },
  };
  let themeId = 'synthwave', prevTheme = null, themeT0 = -9;
  function drawTheme(c, dt) {
    const cur = THEMES[themeId] || THEMES.synthwave, p = (T - themeT0) / 0.8;
    if (prevTheme && p < 1 && THEMES[prevTheme]) {
      THEMES[prevTheme](c, AT, dt); c.globalAlpha = easeOutCubic(p); cur(c, AT, dt); c.globalAlpha = 1;
    } else { prevTheme = null; cur(c, AT, dt); }
  }
  function drawVignette(c) {
    const g = radG(c, CX, CY, Math.min(W, H) * 0.3, CX, CY, Math.max(W, H) * 0.85);
    g.addColorStop(0, 'rgba(5,2,15,0)'); g.addColorStop(1, 'rgba(5,2,15,.62)');
    c.fillStyle = g; c.fillRect(0, 0, W, H);
    if (W >= 700 && play.right < W - 40) {
      const g2 = c.createLinearGradient(play.right - 30, 0, W, 0); g2.addColorStop(0, 'rgba(5,2,15,0)'); g2.addColorStop(1, 'rgba(5,2,15,.5)');
      c.fillStyle = g2; c.fillRect(play.right - 30, 0, W - play.right + 30, H);
    } else if (W < 700 && play.bottom < H - 40) {
      const g2 = c.createLinearGradient(0, play.bottom - 30, 0, H); g2.addColorStop(0, 'rgba(5,2,15,0)'); g2.addColorStop(1, 'rgba(5,2,15,.5)');
      c.fillStyle = g2; c.fillRect(0, play.bottom - 30, W, H - play.bottom + 30);
    }
  }

  /* ═════════════════════════ zone:'screen' visuals ═════════════════════════ */
  function godRays(c) {
    const s = popScale('god_rays'), len = Math.hypot(W, H) * 0.75 * s, n = 14;
    c.save(); c.translate(CX, CY); c.globalCompositeOperation = 'lighter';
    for (let layer = 0; layer < 2; layer++) {
      c.rotate(layer ? -AT * 0.2 : AT * 0.12);
      const g = radG(c, 0, 0, R * 0.5, 0, 0, len);
      const col = layer ? hsl(hue(40), 100, 70, 0.14) : 'rgba(255,240,190,.3)';
      g.addColorStop(0, col); g.addColorStop(1, 'rgba(255,240,190,0)');
      c.fillStyle = g; c.beginPath();
      for (let i = 0; i < n; i++) { const a = (i / n) * TAU + layer * 0.22, w = 0.07 + 0.035 * Math.sin(i * 3.1 + AT * 1.3); c.moveTo(0, 0); arcS(c, 0, 0, len, a - w, a + w); c.closePath(); }
      c.fill();
    }
    c.restore();
  }
  function blackHole(c) {
    const s = popScale('black_hole');
    c.save(); c.translate(CX, CY); c.scale(s, s); c.globalCompositeOperation = 'lighter';
    c.globalAlpha = 0.8; spr(c, glowSprite('rgba(255,120,40,1)'), 0, 0, R * 6); spr(c, glowSprite('#7a2cff'), 0, 0, R * 4.6); c.globalAlpha = 1;
    c.save(); c.rotate(-0.28); c.scale(1, 0.32);
    for (let i = 0; i < 40; i++) {
      const ring = i % 10, rad = R * (1.3 + ring * 0.13), a0 = AT * (2.4 - ring * 0.17) + i * 2.39, len = 0.5 + ((i * 0.37) % 1) * 1.3;
      c.strokeStyle = i % 3 === 0 ? 'rgba(255,180,70,.6)' : i % 3 === 1 ? 'rgba(255,90,40,.5)' : 'rgba(170,80,255,.55)';
      c.lineWidth = R * (0.05 + (i % 4) * 0.015); c.beginPath(); arcS(c, 0, 0, rad, a0, a0 + len); c.stroke();
    }
    c.strokeStyle = 'rgba(255,225,170,.85)'; c.lineWidth = R * 0.05; c.beginPath(); arcS(c, 0, 0, R * 1.28, 0, TAU); c.stroke();
    c.restore();
    c.strokeStyle = 'rgba(255,200,140,.25)'; c.lineWidth = R * 0.14; c.beginPath(); arcS(c, 0, 0, R * 1.16, 0, TAU); c.stroke();
    c.strokeStyle = 'rgba(255,230,190,.7)'; c.lineWidth = 2.5; c.stroke();
    for (let i = 0; i < 22; i++) {
      const k = (AT * 0.25 + i * 0.137) % 1, a = i * 2.2 + k * 5 + AT * 0.5, rad = R * (2.9 - k * 1.7);
      c.globalAlpha = Math.sin(k * Math.PI); spr(c, glowSprite(i % 2 ? '#ffb347' : '#c07bff'), Math.cos(a) * rad, Math.sin(a) * rad * 0.45, R * 0.12);
    }
    c.globalCompositeOperation = 'source-over'; c.globalAlpha = 1;
    const dg = radG(c, 0, 0, R * 0.9, 0, 0, R * 1.14); dg.addColorStop(0, 'rgba(0,0,0,.95)'); dg.addColorStop(1, 'rgba(0,0,0,0)');
    c.fillStyle = dg; c.beginPath(); arcS(c, 0, 0, R * 1.14, 0, TAU); c.fill();
    c.restore();
  }
  const WARP = []; for (let i = 0; i < 150; i++) WARP.push({ a: Math.random() * TAU, d: Math.random(), w: rand(0.8, 2.4), h: Math.random() * 360 });
  function warp(c, dt) {
    const s = popScale('warp'), sp = (1 + heat * 3 + (feverOn() ? 3 : 0)) * (reduced() ? 0.4 : 1), maxD = Math.hypot(W, H) * 0.75;
    c.save(); c.globalCompositeOperation = 'lighter'; c.lineCap = 'round';
    const n = Math.round(WARP.length * clamp(pm * 1.2, 0.35, 1));
    for (let i = 0; i < n; i++) {
      const w = WARP[i]; w.d += dt * sp * (0.12 + w.d * 1.4);
      if (w.d > 1) { w.d = rand(0, 0.08); w.a = Math.random() * TAU; }
      const d0 = R * 1.1 + w.d * maxD, len = (12 + w.d * 110) * sp * 0.6;
      const x = Math.cos(w.a), y = Math.sin(w.a);
      c.globalAlpha = clamp(w.d * 3, 0, 1) * 0.8 * s; c.strokeStyle = hq(hue(w.h), 70); c.lineWidth = w.w * (0.5 + w.d);
      c.beginPath(); c.moveTo(CX + x * d0, CY + y * d0); c.lineTo(CX + x * (d0 + len), CY + y * (d0 + len)); c.stroke();
    }
    c.restore();
  }
  const RAIN = []; for (let i = 0; i < 40; i++) RAIN.push({ x: Math.random(), y: Math.random(), z: 0.25 + (i / 40) * 0.75, rot: Math.random() * TAU, vr: rand(-1.5, 1.5) });
  function cookieRain(c, dt) {
    const s = popScale('cookie_rain'), n = Math.round(RAIN.length * clamp(pm, 0.4, 1)), sk = skinDef();
    for (let i = 0; i < n; i++) {
      const d = RAIN[i]; d.y += ((40 + 170 * d.z) * dt * (feverOn() ? 1.8 : 1)) / H; d.rot += d.vr * dt;
      if (d.y > 1.08) { d.y = -0.08; d.x = Math.random(); }
      c.globalAlpha = (0.25 + 0.55 * d.z) * s;
      drawCookie(c, d.x * W, d.y * H, (6 + 15 * d.z) * s, { simple: true, rot: d.rot, skin: sk.id });
    }
    c.globalAlpha = 1;
  }
  function discoPos() { return { x: play.left + Math.max(44, play.width * 0.12), y: play.top + Math.max(46, play.height * 0.15), r: clamp(R * 0.3, 20, 42) }; }
  function discoBack(c) {
    const s = popScale('disco'), b = discoPos(), n = 7, sz = Math.min(W, H) * 0.42;
    c.save(); c.globalCompositeOperation = 'lighter';
    for (let i = 0; i < n; i++) {
      const x = W * (0.5 + 0.46 * Math.sin(AT * 0.45 * (1 + i * 0.13) + i * 1.3)), y = H * (0.5 + 0.42 * Math.cos(AT * 0.37 * (1 + i * 0.11) + i * 2.1));
      const col = hq(hue(i * 51), 60);
      const dx = x - b.x, dy = y - b.y, dl = Math.hypot(dx, dy) || 1, px = (-dy / dl) * sz * 0.16, py = (dx / dl) * sz * 0.16;
      const g = c.createLinearGradient(b.x, b.y, x, y); g.addColorStop(0, hsl(hue(i * 51), 100, 70, 0.16 * s)); g.addColorStop(1, hsl(hue(i * 51), 100, 60, 0));
      c.fillStyle = g; c.beginPath(); c.moveTo(b.x, b.y); c.lineTo(x + px, y + py); c.lineTo(x - px, y - py); c.closePath(); c.fill();
      c.globalAlpha = 0.32 * s; spr(c, glowSprite(col), x, y, sz); c.globalAlpha = 1;
    }
    c.restore();
  }
  function discoBall(c) {
    const s = popScale('disco'), b = discoPos(), r = b.r * s; if (r < 1) return;
    c.strokeStyle = 'rgba(220,220,255,.6)'; c.lineWidth = 1.5; c.beginPath(); c.moveTo(b.x, play.top - 4); c.lineTo(b.x, b.y - r); c.stroke();
    c.save(); c.globalCompositeOperation = 'lighter'; c.globalAlpha = 0.6; spr(c, glowSprite(hq(hue(0), 75)), b.x, b.y, r * 4); c.restore();
    c.save(); c.beginPath(); arcS(c, b.x, b.y, r, 0, TAU); c.clip();
    c.fillStyle = '#3c3a5c'; c.fillRect(b.x - r, b.y - r, 2 * r, 2 * r);
    const rows = 9, cols = 16, rot = AT * 1.1;
    for (let j = 0; j < rows; j++) {
      const lat0 = -Math.PI / 2 + (j / rows) * Math.PI, lat1 = lat0 + Math.PI / rows, y0 = b.y + Math.sin(lat0) * r, y1 = b.y + Math.sin(lat1) * r;
      const rr = Math.cos((lat0 + lat1) / 2) * r;
      for (let k = 0; k < cols; k++) {
        const lon = (k / cols) * TAU + rot, lon2 = lon + TAU / cols; if (Math.cos(lon + Math.PI / cols) < 0) continue;
        const x0 = b.x + Math.sin(lon) * rr, x1 = b.x + Math.sin(lon2) * rr, hsh = ((j * 31 + k * 17) % 13) / 13;
        const lit = Math.max(0, Math.cos(lon + Math.PI / cols - 0.6)) * 0.7 + hsh * 0.3;
        c.fillStyle = hsh > 0.82 ? hq(hue(j * 40 + k * 20), 70) : `rgb(${(90 + lit * 165) | 0},${(95 + lit * 160) | 0},${(130 + lit * 125) | 0})`;
        c.fillRect(Math.min(x0, x1) + 0.4, y0 + 0.4, Math.abs(x1 - x0) - 0.4, y1 - y0 - 0.4);
      }
    }
    c.restore();
    c.strokeStyle = INK; c.lineWidth = 2; c.beginPath(); arcS(c, b.x, b.y, r, 0, TAU); c.stroke();
    c.save(); c.globalCompositeOperation = 'lighter'; const z = r * (1 + 0.5 * Math.sin(AT * 5)); spr(c, sparkSprite('#ffffff'), b.x - r * 0.35, b.y - r * 0.35, z); c.restore();
  }

  /* ═════════════════════════ always-on: building parade, cursor ring, rebirth stars ═════════════════════════ */
  const paradeBounce = {};
  function parade(c) {
    const st = CO.state; if (!st || !st.buildings) return;
    const list = (DATA().buildings || []).filter((b) => b.id !== 'cursor' && (st.buildings[b.id] || 0) > 0);
    if (!list.length) return;
    const y = play.top + play.height * 0.835, sz = clamp(R * 0.3, 22, 34), gap = sz * 2.15, total = list.length * gap;
    const left = play.left + 8, right = play.right - 8, span = right - left, scroll = total > span;
    const x0 = scroll ? left - ((AT * 26) % total) + gap / 2 : play.left + play.width / 2 - total / 2 + gap / 2;
    c.font = `700 ${Math.round(sz * 0.36 + 3)}px ${FONT_M}`; c.textAlign = 'center'; c.textBaseline = 'middle';
    for (let rep = 0; rep < (scroll ? 2 : 1); rep++) for (let i = 0; i < list.length; i++) {
      const b = list[i], x = x0 + i * gap + rep * total; if (x < left - gap || x > right + gap) continue;
      const a = scroll ? clamp(Math.min(x - left, right - x) / 50, 0, 1) : 1; if (a <= 0) continue;
      const bt = paradeBounce[b.id] != null ? T - paradeBounce[b.id] : 9, bb = bt < 0.6 ? Math.sin(bt * 16) * (1 - bt / 0.6) * 8 : 0;
      const yy = y + Math.sin(AT * 2.4 + i * 0.9) * 3 - Math.abs(bb);
      c.globalAlpha = a * 0.55; c.globalCompositeOperation = 'lighter'; spr(c, glowH(hue(i * 40)), x, y + 2, sz * 2.3); c.globalCompositeOperation = 'source-over';
      c.globalAlpha = a * 0.5; c.fillStyle = '#000'; c.beginPath(); ellS(c, x, y + sz * 0.55, sz * 0.45, sz * 0.12, 0, 0, TAU); c.fill();
      c.globalAlpha = a;
      if (!icon(c, 'b:' + b.id, x, yy, sz * (1 + Math.abs(bb) * 0.02))) { c.fillStyle = hq(i * 40, 60); c.beginPath(); arcS(c, x, yy, sz * 0.4, 0, TAU); c.fill(); c.strokeStyle = INK; c.lineWidth = 2.5; c.stroke(); }
      const txt = '×' + (st.buildings[b.id] || 0), tw = c.measureText(txt).width + 8, bx = x + sz * 0.42, by = y + sz * 0.42;
      c.fillStyle = 'rgba(26,11,51,.88)'; rrect(c, bx - tw / 2, by - 8, tw, 16, 8); c.fill();
      c.strokeStyle = hsl(hue(i * 40), 100, 65, 0.8); c.lineWidth = 1.2; c.stroke();
      c.fillStyle = '#fff'; c.fillText(txt, bx, by + 0.5);
    }
    c.globalAlpha = 1;
  }
  const glowH = (h, l) => glowSprite(hq(h, l || 60));
  function cursorRing(c) {
    const n = Math.min(60, (CO.state && CO.state.buildings && CO.state.buildings.cursor) || 0); if (!n) return;
    const turbo = !!V.cursor_rgb, ps = turbo ? popScale('cursor_rgb') : 1;
    for (let idx = 0; idx < n; idx++) {
      const row = (idx / 20) | 0, i = idx % 20, cnt = Math.min(20, n - row * 20);
      const rad = R * (1.36 + row * 0.2) * (0.6 + 0.4 * ps), size = clamp(R * 0.2, 14, 30) * (1 - row * 0.08);
      const a = (i / cnt) * TAU + AT * (turbo ? 0.9 : 0.22) * (row % 2 ? -1 : 1) + row * 0.3;
      let ph = (AT * (turbo ? 2.2 : 1.1) - i / cnt) % 1; if (ph < 0) ph += 1;
      let tap = ph < 0.18 ? Math.sin((ph / 0.18) * Math.PI) : 0; if (turbo) tap = Math.max(tap, cursorTap);
      const d = rad - tap * R * 0.12, x = CX + Math.cos(a) * d, y = CY + Math.sin(a) * d, rot = a - Math.PI / 2;
      if (turbo) { c.globalCompositeOperation = 'lighter'; c.globalAlpha = 0.85; spr(c, glowH(hue(idx * 12)), x, y, size * 1.9); c.globalCompositeOperation = 'source-over'; c.globalAlpha = 1; }
      if (!icon(c, 'b:cursor', x, y, size, rot)) { c.save(); c.translate(x, y); c.rotate(rot); c.drawImage(glove(), -size / 2, -size / 2, size, size); c.restore(); }
    }
  }
  function rebirthStars(c, front) {
    const n = Math.min(10, (CO.state && CO.state.rebirths) || 0); if (!n) return;
    const rx = R * 1.14, ry = R * 0.34, tilt = 0.3, sz = clamp(R * 0.13, 10, 22);
    for (let i = 0; i < n; i++) {
      const a = AT * 0.9 + (i / n) * TAU, depth = Math.sin(a); if ((depth > 0) !== front) continue;
      const lx = Math.cos(a) * rx, ly = Math.sin(a) * ry, x = CX + lx * Math.cos(tilt) - ly * Math.sin(tilt), y = CY - R * 0.1 + lx * Math.sin(tilt) + ly * Math.cos(tilt);
      const s = sz * (0.85 + depth * 0.2);
      c.globalCompositeOperation = 'lighter'; c.globalAlpha = 0.6; spr(c, glowSprite('#ffc93c'), x, y, s * 2.4); c.globalCompositeOperation = 'source-over'; c.globalAlpha = front ? 1 : 0.75;
      if (!icon(c, 'ui:star', x, y, s, AT * 1.5 + i)) { c.save(); c.translate(x, y); c.rotate(AT * 1.5 + i); c.drawImage(star5(), -s / 2, -s / 2, s, s); c.restore(); }
      c.globalAlpha = 1;
    }
  }

  /* ═════════════════════════ zone:'around' ═════════════════════════ */
  function saturn(c, front) {
    const s = popScale('saturn_ring'); if (s < 0.01) return;
    const tilt = -0.38, sy = 0.26, h0 = hue(0), a0 = front ? 0 : Math.PI, a1 = front ? Math.PI : TAU;
    c.save(); c.translate(CX, CY); c.rotate(tilt); c.scale(s, s * sy);
    const bands = [[1.52, 0.1, 30, 0.5], [1.7, 0.17, 0, 0.42], [1.9, 0.07, 300, 0.55], [2.02, 0.03, 200, 0.7]];
    for (const [rr, w, off, al] of bands) { c.strokeStyle = hsl(h0 + off, 90, 72, al); c.lineWidth = R * w; c.beginPath(); arcS(c, 0, 0, R * rr, a0, a1); c.stroke(); }
    c.globalCompositeOperation = 'lighter'; c.strokeStyle = hsl(h0 + 180, 100, 75, 0.7); c.lineWidth = 1.5 / sy; c.beginPath(); arcS(c, 0, 0, R * 1.62, a0, a1); c.stroke();
    c.restore();
    c.save(); c.globalCompositeOperation = 'lighter';
    const ct = Math.cos(tilt), st = Math.sin(tilt);
    for (let i = 0; i < 36; i++) {
      const a = i * 2.39 + AT * 0.45 * (1 + (i % 3) * 0.12), dep = Math.sin(a); if ((dep > 0) !== front) continue;
      const rr = R * (1.5 + ((i * 0.618) % 1) * 0.5) * s, lx = Math.cos(a) * rr, ly = Math.sin(a) * rr * sy;
      spr(c, glowH(h0 + i * 10, 75), CX + lx * ct - ly * st, CY + lx * st + ly * ct, R * 0.09);
    }
    c.restore();
  }
  const ORB = [[-0.5, 1.5, 0.3, 1.1], [0.42, 1.78, 0.36, -0.8], [1.25, 1.62, 0.24, 1.4]];
  function orbiters(c, front) {
    const lvl = Math.min(3, V.orbiters || 0), n = lvl * 3, s = popScale('orbiters'); if (!n || s < 0.01) return;
    const sk = skinDef();
    for (let i = 0; i < n; i++) {
      const o = ORB[i % 3], k = (i / 3) | 0, per = Math.ceil(n / 3);
      const a = AT * o[3] + (k / per) * TAU + (i % 3) * 0.7, dep = Math.sin(a) * Math.sign(o[3]); if ((dep > 0) !== front) continue;
      const rx = R * o[1] * s, lx = Math.cos(a) * rx, ly = Math.sin(a) * rx * o[2];
      const x = CX + lx * Math.cos(o[0]) - ly * Math.sin(o[0]), y = CY + lx * Math.sin(o[0]) + ly * Math.cos(o[0]), sz = R * 0.15 * (1 + dep * 0.25) * s;
      c.globalCompositeOperation = 'lighter'; c.globalAlpha = 0.5; spr(c, glowH(hue(i * 40)), x, y, sz * 3.2); c.globalCompositeOperation = 'source-over'; c.globalAlpha = front ? 1 : 0.85;
      drawCookie(c, x, y, sz, { simple: true, rot: AT * 2 + i, skin: sk.id });
    }
    c.globalAlpha = 1;
  }
  const FIRE = [];
  function fireUpdate(dt) {
    for (let i = FIRE.length - 1; i >= 0; i--) { const f = FIRE[i]; f.life -= dt; if (f.life <= 0) { FIRE[i] = FIRE[FIRE.length - 1]; FIRE.pop(); continue; } f.x += f.vx * dt; f.y += f.vy * dt; f.vy -= 60 * dt; }
    const lvl = V.fire_aura || 0; if (!lvl) return;
    const rate = (45 + 150 * heat + (feverOn() ? 90 : 0)) * (lvl >= 2 ? 1.5 : 1) * clamp(pm, 0.25, 1), cap = 260 * clamp(pm, 0.3, 1);
    let nn = rate * dt; while (nn > 0 && FIRE.length < cap) {
      if (nn < 1 && Math.random() > nn) break; nn -= 1;
      const a = Math.random() * TAU, rr = ck.drawR * 0.93, core = lvl >= 2 && Math.random() < 0.4;
      FIRE.push({ x: CX + Math.cos(a) * rr, y: CY + Math.sin(a) * rr, vx: rand(-18, 18) + Math.cos(a) * 25, vy: -rand(50, 130) * (1 + heat * 0.8), life: rand(0.45, 0.85) * (core ? 0.7 : 1), max: 0.85, s: R * rand(0.2, 0.34) * (1 + heat * 0.5), core });
    }
  }
  const FIRE_COLS = ['#ff2b2b', '#ff5a00', '#ff9a1f', '#ffd23c'], CORE_COLS = ['#5a3cff', '#8a5cff', '#3dc8ff', '#bff6ff'];
  function fireDraw(c) {
    if (!V.fire_aura && !FIRE.length) return;
    c.save(); c.globalCompositeOperation = 'lighter';
    if (V.fire_aura) {
      const s = popScale('fire_aura'), g = radG(c, CX, CY, R * 0.85, CX, CY, R * (1.45 + heat * 0.3) * s);
      g.addColorStop(0, `rgba(255,110,20,${(0.4 + heat * 0.3).toFixed(2)})`); g.addColorStop(1, 'rgba(255,60,0,0)');
      c.fillStyle = g; c.beginPath(); arcS(c, CX, CY, R * 1.8, 0, TAU); c.fill();
    }
    for (let i = 0; i < FIRE.length; i++) {
      const f = FIRE[i], k = clamp(f.life / f.max, 0, 1), cols = f.core ? CORE_COLS : FIRE_COLS;
      c.globalAlpha = Math.min(1, k * 1.6) * 0.8; spr(c, glowSprite(cols[Math.min(3, (k * 4) | 0)]), f.x, f.y, f.s * (0.4 + k * 0.8));
    }
    c.restore();
  }
  const BOLTS = []; let boltT = 0;
  function makeBolt() {
    const out = Math.random() < 0.45, a0 = Math.random() * TAU, n = 8, pts = [];
    const a1 = out ? a0 + rand(-0.3, 0.3) : a0 + rand(0.5, 1.4) * (Math.random() < 0.5 ? -1 : 1);
    const bulge = rand(0.15, 0.4), reach = rand(1.45, 1.95);
    for (let i = 0; i <= n; i++) {
      const k = i / n, a = lerp(a0, a1, k), rr = out ? lerp(1.0, reach, k) : 1.0 + Math.sin(k * Math.PI) * bulge;
      pts.push(a, rr);
    }
    return { pts, t0: T, life: rand(0.1, 0.22), col: Math.random() < 0.5 ? '#1ff4ff' : '#a57bff' };
  }
  function lightning(c, dt) {
    if (!V.lightning) return;
    boltT -= dt; const iv = feverOn() ? 0.05 : 0.26 - heat * 0.18;
    if (boltT <= 0) { boltT = iv * rand(0.5, 1.5); if (BOLTS.length < 8) BOLTS.push(makeBolt()); }
    const s = popScale('lightning');
    c.save(); c.globalCompositeOperation = 'lighter'; c.lineJoin = 'round'; c.lineCap = 'round';
    for (let i = BOLTS.length - 1; i >= 0; i--) {
      const b = BOLTS[i]; if (T - b.t0 > b.life) { BOLTS.splice(i, 1); continue; }
      c.beginPath();
      for (let j = 0; j < b.pts.length; j += 2) {
        const jit = j === 0 || j === b.pts.length - 2 ? 0 : R * 0.07, a = b.pts[j], rr = b.pts[j + 1] * R * ck.s * s;
        const x = CX + Math.cos(a) * rr + rand(-jit, jit), y = CY + Math.sin(a) * rr + rand(-jit, jit);
        j ? c.lineTo(x, y) : c.moveTo(x, y);
      }
      c.globalAlpha = Math.random() < 0.2 ? 0.4 : 1;
      c.strokeStyle = b.col; c.globalAlpha *= 0.3; c.lineWidth = 7; c.stroke();
      c.globalAlpha = 1; c.lineWidth = 2.4; c.stroke(); c.strokeStyle = '#ffffff'; c.lineWidth = 1; c.stroke();
    }
    c.restore();
  }
  const CHAT = [];
  const CHAT_USERS = [['xX_Crunch_Xx', '#ff5ea8'], ['mamie_gameuse', '#ffd23c'], ['cookieGOD', '#1ff4ff'], ['brocoli_hater', '#3dff8a'], ['pepite92', '#ff8a1f'], ['lait_demi_ecreme', '#c9b6ff'], ['RGB_enjoyer', '#ff2bd6'], ['tkt_frr', '#b6ff3b'], ['nocap_nico', '#7ab8ff'], ['zinzin_du_four', '#ffb36f']];
  const CHAT_MSG = ['W', 'POG', 'GG', 'no cap', '+1 abonné', "le cookie a trop d'aura", 'ratio le brocoli', "CHAT C'EST RÉEL", 'masterclass', 'le goat', 'aura +1000', 'wsh le combo', 'ça cuit ça cuit', "c'est validé", 'il est chaud là', 'W W W', 'KEKW', 'jpp', 'trop fort frr', 'le cookie a mangé'];
  function chatSpawn() {
    if (CHAT.length >= (play.width < 560 ? 3 : 7)) CHAT.shift();
    const [user, col] = pick(CHAT_USERS), msg = pick(CHAT_MSG), ic = Math.random() < 0.35 ? (Math.random() < 0.5 ? 'ui:heart' : 'ui:fire') : null;
    const side = CHAT.length ? -CHAT[CHAT.length - 1].side : 1;
    CHAT.push({ user, col, msg, ic, side, t0: T, y0: rand(0.2, 0.6), jit: rand(-10, 10) });
  }
  let chatT = 1;
  function chatDraw(c, dt) {
    if (V.chat) { chatT -= dt; if (chatT <= 0) { chatT = feverOn() ? rand(0.3, 0.6) : rand(1.1, 2); chatSpawn(); } }
    const s = V.chat ? popScale('chat') : 1;
    for (let i = CHAT.length - 1; i >= 0; i--) {
      const m = CHAT[i], age = T - m.t0; if (age > 4.5) { CHAT.splice(i, 1); continue; }
      const a = Math.min(1, age / 0.2) * (age > 3.7 ? 1 - (age - 3.7) / 0.8 : 1) * s;
      const narrow = play.width < 560, fs = narrow ? 11 : 13;
      c.font = `600 ${fs}px ${FONT_B}`; m.uw = c.measureText(m.user + ': ').width; m.w = m.uw + c.measureText(m.msg).width + 20 + (m.ic ? 18 : 0);
      let x = narrow ? (m.side < 0 ? play.left + 6 : play.right - m.w - 6) : m.side < 0 ? CX - R * 1.3 - m.w + m.jit : CX + R * 1.3 + m.jit; x = clamp(x, play.left + 6, play.right - m.w - 6);
      const y = (narrow ? CY - R * 0.25 : CY + R * m.y0) - age * 28, h = narrow ? 20 : 24;
      c.globalAlpha = a * 0.9; c.fillStyle = 'rgba(14,6,34,.85)'; rrect(c, x, y - h / 2, m.w, h, 9); c.fill();
      c.strokeStyle = hsl(hue(i * 50), 100, 65, 0.7); c.lineWidth = 1.5; c.stroke();
      c.globalAlpha = a; c.textAlign = 'left'; c.textBaseline = 'middle';
      c.fillStyle = m.col; c.fillText(m.user + ':', x + 10, y + 0.5); c.fillStyle = '#fff6fe'; c.fillText(m.msg, x + 10 + m.uw, y + 0.5);
      if (m.ic) icon(c, m.ic, x + m.w - 15, y, 15);
    }
    c.globalAlpha = 1;
  }

  /* ═════════════════════════ pets ═════════════════════════ */
  let PETS = [];
  function refreshPets() {
    const eq = (CO.equippedPets && CO.equippedPets()) || [], old = PETS;
    PETS = eq.slice(0, 3).map((p, i) => {
      const prev = old.find((o) => o.uid === p.uid);
      return prev ? Object.assign(prev, { def: p.def, lvl: p.lvl, slot: i }) : { uid: p.uid, def: p.def, lvl: p.lvl, slot: i, born: T, hop: 0, hopv: 0, next: T + rand(2, 5) };
    }).filter((p) => p.def);
  }
  function petPos(p) {
    const sz = clamp(R * 0.46, 30, 70), slots = [[-1.78, 0.25], [1.78, 0.25], [1.5, -1.12]], s = slots[p.slot] || slots[0];
    return { x: clamp(CX + s[0] * R, play.left + sz * 0.6, play.right - sz * 0.6), y: CY + s[1] * R, sz };
  }
  const SHOTS = [];
  function petsDraw(c, dt) {
    const rar = DATA().rarities || {};
    for (let i = 0; i < PETS.length; i++) {
      const p = PETS[i], pos = petPos(p), rd = rar[p.def.rarity] || {};
      p.hopv -= 1400 * dt; p.hop += p.hopv * dt; if (p.hop < 0) { p.hop = 0; p.hopv = 0; }
      const s = reduced() ? easeOutCubic((T - p.born) / 0.5) : elasticOut((T - p.born) / 0.7), sz = pos.sz * s;
      const x = pos.x, y = pos.y + Math.sin(AT * 2 + i * 2.1) * R * 0.05 - p.hop, tilt = Math.sin(AT * 1.6 + i) * 0.1 + (p.hop > 0 ? -0.15 * Math.sign(pos.x - CX) : 0);
      const gcol = rd.glow === 'rgb' || rd.color === 'rgb' ? hq(hue(i * 60)) : rd.color || '#ffffff';
      c.globalCompositeOperation = 'lighter'; c.globalAlpha = 0.55 + 0.25 * Math.sin(AT * 3 + i); spr(c, glowSprite(gcol), x, y, sz * 2.1);
      if (rd.glow === 'rgb') { c.globalAlpha = 0.5; spr(c, glowSprite(hq(hue(i * 60 + 120))), x + Math.cos(AT * 3) * sz * 0.2, y + Math.sin(AT * 3) * sz * 0.2, sz * 1.6); }
      c.globalCompositeOperation = 'source-over'; c.globalAlpha = 0.35; c.fillStyle = '#000';
      c.beginPath(); ellS(c, pos.x, pos.y + pos.sz * 0.55, sz * 0.36 * Math.max(0.3, 1 - p.hop / 120), sz * 0.09, 0, 0, TAU); c.fill(); c.globalAlpha = 1;
      if (!icon(c, 'pet:' + p.def.id, x, y, sz, tilt)) {
        c.fillStyle = rd.color && rd.color !== 'rgb' ? rd.color : hq(hue(i * 60)); c.beginPath(); arcS(c, x, y, sz * 0.38, 0, TAU); c.fill(); c.strokeStyle = INK; c.lineWidth = 3; c.stroke();
        outlined(c, (p.def.name || '?')[0], x, y, sz * 0.4, '#fff');
      }
      if (p.lvl > 1) {
        c.font = `700 11px ${FONT_M}`; const txt = 'Nv.' + p.lvl, tw = c.measureText(txt).width + 10, bx = x + sz * 0.32, by = y + sz * 0.42;
        c.fillStyle = INK; rrect(c, bx - tw / 2, by - 8, tw, 16, 8); c.fill(); c.strokeStyle = gcol; c.lineWidth = 1.5; c.stroke();
        c.fillStyle = '#fff'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(txt, bx, by + 0.5);
      }
      if (T > p.next && !paused) { p.next = T + rand(3, 6.5); SHOTS.push({ x0: x, y0: y, t0: T, dur: 0.5, col: gcol }); }
    }
    c.save(); c.globalCompositeOperation = 'lighter';
    for (let i = SHOTS.length - 1; i >= 0; i--) {
      const s = SHOTS[i], k = (T - s.t0) / s.dur;
      if (k >= 1) { SHOTS.splice(i, 1); const a = Math.atan2(s.y0 - CY, s.x0 - CX); burst(CX + Math.cos(a) * R * 0.8, CY + Math.sin(a) * R * 0.8, 8, { cols: [s.col, '#ffffff'], speed: 160, size: 12, life: 0.5 }); ck.sv -= 0.25; continue; }
      const e = easeInOut(k), x = lerp(s.x0, CX, e), y = lerp(s.y0, CY, e) - Math.sin(k * Math.PI) * R * 0.5;
      spr(c, glowSprite(s.col), x, y, R * 0.35); spr(c, sparkSprite('#ffffff'), x, y, R * 0.28 * (1 + 0.3 * Math.sin(T * 30)));
    }
    c.restore();
  }

  /* ═════════════════════════ golden cookies ═════════════════════════ */
  const GOLD_POS = new Map();
  function goldPx(g) { return { x: play.left + g.x * play.width, y: play.top + g.y * play.height }; }
  function goldensDraw(c) {
    GOLD_POS.clear();
    const list = (CO.golden && CO.golden.list) || []; if (!list.length) return;
    const gr = clamp(R * 0.28, 24, 40);
    for (let i = 0; i < list.length; i++) {
      const g = list[i], p = goldPx(g), age = T - g.born, rem = g.life - age;
      const a = rem < 2 ? clamp(rem / 2, 0, 1) * (0.75 + 0.25 * Math.sin(T * 18)) : 1, s = reduced() ? easeOutCubic(age / 0.4) : elasticOut(age / 0.6);
      const x = p.x, y = p.y + Math.sin(AT * 2.2 + g.id) * 6, r = gr * s;
      c.save(); c.translate(x, y); c.rotate(AT * 0.7); c.globalCompositeOperation = 'lighter'; c.globalAlpha = a;
      const rg = radG(c, 0, 0, r * 0.6, 0, 0, r * 3.2); rg.addColorStop(0, 'rgba(255,220,90,.55)'); rg.addColorStop(1, 'rgba(255,220,90,0)');
      c.fillStyle = rg; c.beginPath();
      for (let k = 0; k < 10; k++) { const an = (k / 10) * TAU; c.moveTo(0, 0); arcS(c, 0, 0, r * 3.2, an - 0.12, an + 0.12); c.closePath(); }
      c.fill(); c.globalAlpha = a * (0.7 + 0.2 * Math.sin(T * 5)); spr(c, glowSprite('#ffc93c'), 0, 0, r * 4.2);
      c.restore();
      c.globalAlpha = a; drawCookie(c, x, y, r, { skin: 'golden', t: T, rot: Math.sin(AT * 1.5 + g.id) * 0.25 }); c.globalAlpha = 1;
      if (Math.random() < 0.12 * pm) spawn('star', x + rand(-r, r), y + rand(-r, r), rand(-20, 20), rand(-50, -10), 0.6, rand(10, 18), '#fff3a0');
      GOLD_POS.set(g.id, { x, y, r: Math.max(40, gr * 1.35) });
    }
  }

  /* ═════════════════════════ boss ═════════════════════════ */
  let BV = null; const PROJ = []; let lastProj = null;
  function bossPos() {
    const size = Math.max(60, R * 1.1);
    return { x: Math.min(play.right - size * 0.62, Math.max(play.left + play.width * 0.8, CX + R * 1.45)), y: play.top + play.height * 0.34, size };
  }
  function bossHit(dmg, crit) {
    if (!BV) return; const bp = bossPos();
    BV.flash = 1; BV.kbv += crit ? 700 : 380; shake(crit ? 9 : 3);
    addText(bp.x + rand(-20, 20), bp.y - bp.size * 0.2, '-' + (CO.fmt ? CO.fmt(dmg) : Math.round(dmg)), crit ? 'crit' : 'dmg');
    burst(bp.x - bp.size * 0.25, bp.y, crit ? 18 : 8, { cols: ['#ffffff', BV.boss.color || '#ff4d6d', '#ffd23c'], speed: crit ? 420 : 260, size: 14, life: 0.5 });
  }
  function bossDraw(c, dt) {
    const B = CO.boss;
    if (B && (!BV || BV.state !== 'live' || BV.boss.id !== B.id)) BV = { boss: B, t0: T, hpD: B.hp / (B.maxHp || 1), trail: 1, flash: 0, kb: 0, kbv: 0, state: 'live', tEnd: 0 };
    if (!BV) return;
    const bp = bossPos(); let x = bp.x, y = bp.y, sc = 1, rot = 0, al = 1;
    BV.kbv += (-BV.kb * 260 - BV.kbv * 16) * dt; BV.kb += BV.kbv * dt; BV.flash = Math.max(0, BV.flash - dt * 6);
    if (BV.state === 'live') {
      const k = (T - BV.t0) / 0.8; x = lerp(W + bp.size, bp.x, easeOutBack(k)); sc = k < 1 ? 0.6 + 0.4 * easeOutCubic(k) : 1;
      const hpT = B ? B.hp / (B.maxHp || 1) : BV.hpD; BV.hpD = lerp(BV.hpD, hpT, 1 - Math.exp(-dt * 14)); BV.trail = BV.trail > BV.hpD ? Math.max(BV.hpD, BV.trail - dt * 0.5) : BV.hpD;
    } else if (BV.state === 'dead') { const k = (T - BV.tEnd) / 0.3; if (k >= 1) { BV = null; return; } sc = 1 + k * 0.6; al = 1 - k; }
    else { const k = (T - BV.tEnd) / 1; if (k >= 1) { BV = null; return; } x += k * k * W * 0.7; y -= k * H * 0.35; sc = 1 - k * 0.7; rot = k * 7; al = 1 - k * 0.8; }
    x += BV.kb * 0.5; rot += Math.sin(AT * 3) * 0.14 + BV.kb * 0.005; y += Math.sin(AT * 2.3) * 8;
    const size = bp.size * sc * (1 + 0.05 * Math.sin(AT * 4)), col = BV.boss.color || '#ff4d6d';
    c.globalAlpha = al; c.globalCompositeOperation = 'lighter'; c.globalAlpha = al * (0.45 + 0.2 * Math.sin(AT * 5)); spr(c, glowSprite(col), x, y, size * 2.4);
    c.globalAlpha = al * 0.35; spr(c, glowSprite('#ff2b3b'), x, y + size * 0.1, size * 1.8);
    c.globalCompositeOperation = 'source-over'; c.globalAlpha = al * 0.4; c.fillStyle = '#000'; c.beginPath(); ellS(c, x, y + size * 0.6, size * 0.4, size * 0.08, 0, 0, TAU); c.fill(); c.globalAlpha = al;
    if (!icon(c, 'boss:' + BV.boss.id, x, y, size, rot)) {
      c.save(); c.translate(x, y); c.rotate(rot); c.fillStyle = col; c.beginPath(); arcS(c, 0, 0, size * 0.42, 0, TAU); c.fill(); c.strokeStyle = INK; c.lineWidth = 4; c.stroke();
      c.fillStyle = INK; c.beginPath(); c.moveTo(-size * 0.25, -size * 0.12); c.lineTo(-size * 0.06, -size * 0.04); c.lineTo(-size * 0.22, 0.02 * size); c.fill(); c.beginPath(); c.moveTo(size * 0.25, -size * 0.12); c.lineTo(size * 0.06, -size * 0.04); c.lineTo(size * 0.22, 0.02 * size); c.fill();
      c.lineWidth = 4; c.strokeStyle = INK; c.beginPath(); arcS(c, 0, size * 0.2, size * 0.13, 1.15 * Math.PI, 1.85 * Math.PI); c.stroke(); c.restore();
    }
    if (BV.flash > 0) { c.globalCompositeOperation = 'lighter'; c.globalAlpha = BV.flash; icon(c, 'boss:' + BV.boss.id, x, y, size, rot); icon(c, 'boss:' + BV.boss.id, x, y, size, rot); spr(c, glowSprite('#ffffff'), x, y, size * 1.4); c.globalCompositeOperation = 'source-over'; }
    c.globalAlpha = al;
    if (BV.state === 'live') {
      const bw = clamp(R * 1.5, 110, 200), bh = 15, bx = clamp(x - bw / 2, play.left + 8, play.right - bw - 8), by = y + size * 0.62, bxc = bx + bw / 2;
      c.font = `${clamp(R * 0.15, 15, 21) | 0}px ${FONT_D}`; const nw = c.measureText(BV.boss.name || 'BOSS').width;
      outlined(c, BV.boss.name || 'BOSS', clamp(x, play.left + nw / 2 + 8, play.right - nw / 2 - 8), y - size * 0.64, clamp(R * 0.15, 15, 21), '#ffffff');
      c.fillStyle = INK; rrect(c, bx - 3, by - 3, bw + 6, bh + 6, 9); c.fill();
      c.fillStyle = '#3a1030'; rrect(c, bx, by, bw, bh, 6); c.fill();
      if (BV.trail > BV.hpD) { c.fillStyle = 'rgba(255,255,255,.75)'; rrect(c, bx, by, bw * BV.trail, bh, 6); c.fill(); }
      const low = BV.hpD < 0.3, hg = low ? rainbowGrad(c, bx + bw / 2, bw) : c.createLinearGradient(bx, 0, bx + bw, 0);
      if (!low) { hg.addColorStop(0, '#ff3d5e'); hg.addColorStop(1, '#ff9a1f'); }
      if (BV.hpD > 0.005) { c.fillStyle = hg; rrect(c, bx, by, Math.max(bh, bw * BV.hpD), bh, 6); c.fill(); }
      c.fillStyle = 'rgba(255,255,255,.28)'; rrect(c, bx + 3, by + 2, Math.max(0, bw * BV.hpD - 6), bh * 0.35, 3); c.fill();
      const tl = B ? Math.max(0, Math.ceil(B.until - T)) : 0;
      c.font = `700 12px ${FONT_M}`; c.textAlign = 'center'; c.textBaseline = 'middle';
      c.fillStyle = tl <= 5 ? '#ff4d6d' : '#fff6fe'; c.fillText(Math.ceil(BV.hpD * 100) + ' %  ·  ' + tl + ' s', bxc, by + bh + 13);
    }
    c.globalAlpha = 1;
  }
  function projDraw(c) {
    for (let i = PROJ.length - 1; i >= 0; i--) {
      const p = PROJ[i], k = (T - p.t0) / p.dur, bp = bossPos(), tx = bp.x - bp.size * 0.15, ty = bp.y;
      if (k >= 1) { PROJ.splice(i, 1); if (p.hit) bossHit(p.hit.dmg, p.hit.crit); else burst(tx, ty, 5, { cols: ['#ffffff', '#ffd23c'], speed: 180, size: 10, life: 0.35 }); if (lastProj === p) lastProj = null; continue; }
      if (p.kind === 'laser') {
        const e = eyePos(p.side); c.save(); c.globalCompositeOperation = 'lighter'; c.lineCap = 'round'; c.globalAlpha = 1 - k * 0.5;
        c.strokeStyle = 'rgba(255,40,60,.35)'; c.lineWidth = 12; c.beginPath(); c.moveTo(e.x, e.y); c.lineTo(tx, ty); c.stroke();
        c.strokeStyle = '#ff4d6d'; c.lineWidth = 4; c.stroke(); c.strokeStyle = '#fff'; c.lineWidth = 1.5; c.stroke(); c.restore();
      } else {
        const e = easeInOut(k), x = lerp(CX, tx, e), y = lerp(CY - R * 0.3, ty, e) - Math.sin(k * Math.PI) * R * 0.6;
        c.globalCompositeOperation = 'lighter'; spr(c, glowSprite('#ffc93c'), x, y, R * 0.45); c.globalCompositeOperation = 'source-over';
        drawCookie(c, x, y, R * 0.13, { simple: true, rot: k * 12 });
      }
    }
  }

  /* ═════════════════════════ floating numbers & labels ═════════════════════════ */
  const TEXTS = [], LABELS = [];
  function addText(x, y, text, kind, extra) {
    if (TEXTS.length > 44) TEXTS.shift();
    const size = kind === 'crit' ? 44 : kind === 'dmg' ? 26 : kind === 'small' ? 18 : 30;
    TEXTS.push({ x, y, vx: rand(-40, 40), vy: kind === 'crit' ? -170 : -140, t0: T, life: kind === 'crit' ? 1.3 : 1.05, text, kind, size, extra });
  }
  function textsDraw(c) {
    for (let i = TEXTS.length - 1; i >= 0; i--) {
      const t = TEXTS[i], age = T - t.t0; if (age > t.life) { TEXTS.splice(i, 1); continue; }
      const k = age / t.life, sc = age < 0.12 ? 0.5 + (age / 0.12) * 0.75 : age < 0.25 ? 1.25 - ((age - 0.12) / 0.13) * 0.25 : 1;
      const x = t.x + t.vx * age, y = t.y + t.vy * age * (1 - age * 0.35), sz = t.size * sc * clamp(R / 140, 0.75, 1.15);
      c.globalAlpha = k > 0.7 ? 1 - (k - 0.7) / 0.3 : 1;
      c.font = `${sz | 0}px ${FONT_D}`; const w = c.measureText(t.text).width;
      let fill;
      if (t.kind === 'crit') { fill = c.createLinearGradient(0, y - sz / 2, 0, y + sz / 2); fill.addColorStop(0, '#fff6a8'); fill.addColorStop(0.5, '#ffc93c'); fill.addColorStop(1, '#ff8a00'); }
      else if (t.kind === 'dmg') fill = '#ff4d6d';
      else if (t.kind === 'combo') fill = '#1ff4ff';
      else fill = rainbowGrad(c, x, w, i * 30);
      outlined(c, t.text, x, y, sz, fill);
      if (t.kind === 'crit') outlined(c, 'CRIT!', x, y - sz * 0.85, sz * 0.5, '#ff4d6d');
      if (t.extra) outlined(c, t.extra, x + w / 2 + sz * 0.55, y + sz * 0.1, sz * 0.5, '#1ff4ff');
    }
    c.globalAlpha = 1;
  }
  function addLabel(text, color, big) {
    if (!text) return; if (LABELS.length > 4) LABELS.shift();
    LABELS.push({ text: String(text), color: color || '#ffffff', t0: T, dur: 2.3, big: big == null ? 1 : big });
  }
  function labelsDraw(c) {
    for (let i = LABELS.length - 1; i >= 0; i--) {
      const L = LABELS[i], age = T - L.t0; if (age > L.dur) { LABELS.splice(i, 1); continue; }
      const sc = reduced() ? 1 : age < 0.45 ? elasticOut(age / 0.45) : 1, k = age / L.dur;
      const base = clamp(play.width * 0.085, 28, 64) * L.big, sz = base * sc;
      const x = play.left + play.width / 2, y = play.top + play.height * 0.36 - age * 22 - i * base * 0.2;
      c.globalAlpha = k > 0.72 ? 1 - (k - 0.72) / 0.28 : 1;
      c.save(); c.translate(x, y); c.rotate(Math.sin(age * 6) * 0.03 * (1 - k));
      c.font = `${sz | 0}px ${FONT_D}`; const w = c.measureText(L.text).width;
      let fs = sz; if (w > play.width * 0.94) { fs = (sz * play.width * 0.94) / w; }
      const fill = L.color === 'rgb' ? rainbowGrad(c, 0, w * (fs / sz)) : L.color;
      c.globalCompositeOperation = 'lighter'; const ga = c.globalAlpha; c.globalAlpha = ga * 0.45;
      spr(c, glowSprite(L.color === 'rgb' ? hq(hue(0)) : L.color.charAt(0) === '#' ? L.color : '#ffffff'), 0, 0, Math.min(w, play.width) * 1.1);
      c.globalAlpha = ga; c.globalCompositeOperation = 'source-over';
      outlined(c, L.text, 0, 0, fs, fill);
      c.restore();
    }
    c.globalAlpha = 1;
  }

  /* ═════════════════════════ lasers (laser_eyes) ═════════════════════════ */
  const LASERS = [];
  function eyePos(side) {
    const r = ck.drawR, co = Math.cos(ck.rot), si = Math.sin(ck.rot), lx = side * EYE_X * r * (1 + 0.14 * ck.sq), ly = EYE_Y * r * (1 - 0.14 * ck.sq);
    return { x: CX + lx * co - ly * si, y: CY + lx * si + ly * co };
  }
  function lasersDraw(c) {
    if (!LASERS.length) return;
    c.save(); c.globalCompositeOperation = 'lighter'; c.lineCap = 'round';
    for (let i = LASERS.length - 1; i >= 0; i--) {
      const L = LASERS[i], k = (T - L.t0) / 0.24; if (k >= 1) { LASERS.splice(i, 1); continue; }
      const a = 1 - k * k;
      for (let side = -1; side <= 1; side += 2) {
        const e = eyePos(side); let dx = L.x - e.x, dy = L.y - e.y, d = Math.hypot(dx, dy);
        if (d < R * 0.2) { dx = L.x - CX; dy = L.y - CY; d = Math.hypot(dx, dy); if (d < 1) { dx = 0; dy = -1; d = 1; } }
        const ex = e.x + (dx / d) * 3000, ey = e.y + (dy / d) * 3000;
        c.globalAlpha = a; c.strokeStyle = 'rgba(255,30,50,.28)'; c.lineWidth = 13; c.beginPath(); c.moveTo(e.x, e.y); c.lineTo(ex, ey); c.stroke();
        c.strokeStyle = '#ff3b4f'; c.lineWidth = 4.5; c.stroke(); c.strokeStyle = '#ffffff'; c.lineWidth = 1.6; c.stroke();
        spr(c, glowSprite('#ff2b3b'), e.x, e.y, R * 0.5);
      }
      c.globalAlpha = a; spr(c, glowSprite('#ff6b3b'), L.x, L.y, R * 0.6 * (1 + k));
    }
    c.restore();
  }

  /* ═════════════════════════ the main cookie ═════════════════════════ */
  let glitchStart = -9, nextGlitch = 3, GB = null, GT1 = null, GT2 = null, glitchOff = [];
  const mainFx = {
    pop: popScale, drop() { const t0 = pop.shades; if (t0 == null) return 1; return bounceOut((T - t0) / 0.8); },
    lx: 0, ly: 0, blink: 0, mouth: 0, fever: false, heat: 0, spin: 0, cb: 0, swing: 0, laser: 0,
  };
  function updateFx() {
    let dx, dy;
    if (ptr.x > -999 && T - ptr.t < 6) { dx = ptr.x - CX; dy = ptr.y - CY; }
    else { dx = Math.sin(AT * 0.7) * 60; dy = Math.cos(AT * 0.53) * 30; }
    const d = Math.hypot(dx, dy) || 1, k = Math.min(1, d / (R * 2));
    mainFx.lx = lerp(mainFx.lx, (dx / d) * k, 0.3); mainFx.ly = lerp(mainFx.ly, (dy / d) * k, 0.3);
    if (T > ck.nextBlink) { ck.blink = T; ck.nextBlink = T + rand(2.2, 5); }
    mainFx.blink = T - ck.blink < 0.13 ? 1 : 0;
    mainFx.mouth = ck.mouth; mainFx.fever = feverOn(); mainFx.heat = heat; mainFx.spin = ck.spin; mainFx.cb = ck.cb; mainFx.swing = ck.sw; mainFx.laser = ck.laser;
  }
  function paintCookie(c, x, y, r) {
    drawCookie(c, x, y, r, { skin: undefined, t: T, rot: ck.rot, squash: clamp(ck.sq, -0.8, 0.8), accessories: true, _fx: mainFx });
  }
  function tinted(src, dst, col) {
    const g = dst.getContext('2d'); g.setTransform(1, 0, 0, 1, 0, 0); g.globalCompositeOperation = 'source-over'; g.clearRect(0, 0, dst.width, dst.height);
    g.drawImage(src, 0, 0); g.globalCompositeOperation = 'source-in'; g.fillStyle = col; g.fillRect(0, 0, dst.width, dst.height); g.globalCompositeOperation = 'source-over';
  }
  function drawMainCookie(c) {
    const s = clamp(ck.s, 0.82, 1.18) * (1 + 0.05 * ck.hover) * (1 + 0.018 * Math.sin(AT * 2.3)) * (1 + 0.05 * ck.pulse), r = R * s;
    ck.drawR = r; ck.rot = Math.sin(AT * 0.9) * 0.045 + clamp(ck.tilt, -0.2, 0.2);
    const sg = radG(c, CX + R * 0.05, CY + R * 0.16, R * 0.4, CX + R * 0.05, CY + R * 0.16, r * 1.15);
    sg.addColorStop(0, 'rgba(0,0,0,.5)'); sg.addColorStop(1, 'rgba(0,0,0,0)'); c.fillStyle = sg; c.beginPath(); arcS(c, CX + R * 0.05, CY + R * 0.16, r * 1.15, 0, TAU); c.fill();
    if (V.afterimage) {
      const ps = popScale('afterimage'), sk = skinDef();
      c.save(); c.globalCompositeOperation = 'lighter';
      for (let i = 4; i >= 1; i--) {
        const ox = Math.sin(AT * 2.4 - i * 0.5) * R * 0.1 * i * ps, oy = Math.cos(AT * 1.9 - i * 0.5) * R * 0.055 * i * ps;
        c.save(); c.translate(CX + ox, CY + oy); c.rotate(ck.rot - i * 0.05);
        c.fillStyle = hsl(hue(i * 70), 100, 60, (0.3 - i * 0.05) * ps); bodyPath(c, r * (1 + 0.02 * i), sk, 1); c.fill();
        c.strokeStyle = hsl(hue(i * 70 + 30), 100, 70, 0.5 * ps); c.lineWidth = 2; c.stroke(); c.restore();
      }
      c.restore();
    }
    const glitching = V.glitch && T - glitchStart < 0.15 && degrade < 2;
    if (!glitching) { paintCookie(c, CX, CY, r); return; }
    const half = R * 2.3, px = Math.ceil(half * 2 * dpr);
    if (!GB || GB.width !== px) { GB = mk(px); GT1 = mk(px); GT2 = mk(px); }
    const g = GB.getContext('2d'); g.setTransform(1, 0, 0, 1, 0, 0); g.clearRect(0, 0, px, px); g.setTransform(dpr, 0, 0, dpr, 0, 0);
    paintCookie(g, half, half, r);
    tinted(GB, GT1, 'rgb(255,0,70)'); tinted(GB, GT2, 'rgb(0,220,255)');
    const d = R * 0.07 * (feverOn() ? 1.6 : 1), x0 = CX - half, y0 = CY - half, n = glitchOff.length, sh = (half * 2) / n;
    c.save(); c.globalCompositeOperation = 'lighter'; c.globalAlpha = 0.75;
    c.drawImage(GT1, x0 - d, y0, half * 2, half * 2); c.drawImage(GT2, x0 + d, y0, half * 2, half * 2); c.restore();
    for (let i = 0; i < n; i++) { const sy = (i * px) / n; c.drawImage(GB, 0, sy, px, px / n, x0 + glitchOff[i] * R, y0 + i * sh, half * 2, sh + 0.5); }
  }

  /* ═════════════════════════ overlays: fever, flash, trail, fps ═════════════════════════ */
  function feverOverlay(c) {
    if (feverK < 0.01) return;
    const h0 = hue(0), bt = CO.beatPhase ? 1 - CO.beatPhase() : 0.5, bw = (7 + 7 * bt) * feverK;
    c.save(); c.globalCompositeOperation = 'lighter';
    const vg = radG(c, W / 2, H / 2, Math.min(W, H) * 0.35, W / 2, H / 2, Math.max(W, H) * 0.75);
    vg.addColorStop(0, 'rgba(0,0,0,0)'); vg.addColorStop(1, hsl(h0, 100, 50, 0.3 * feverK)); c.fillStyle = vg; c.fillRect(0, 0, W, H);
    let g;
    if (c.createConicGradient) { g = c.createConicGradient(AT * 1.5, W / 2, H / 2); for (let i = 0; i <= 6; i++) g.addColorStop(i / 6, hsl(h0 + i * 60, 100, 60)); } else g = hsl(h0, 100, 60);
    c.strokeStyle = g; c.globalAlpha = 0.35 * feverK; c.lineWidth = bw * 3.2; c.strokeRect(0, 0, W, H);
    c.globalAlpha = feverK; c.lineWidth = bw; c.strokeRect(bw / 2, bw / 2, W - bw, H - bw);
    c.restore();
  }
  function trailDraw(c) {
    const tr = ptr.trail; while (tr.length && T - tr[0].t > 0.32) tr.shift();
    if (S().trail === false || tr.length < 2) return;
    c.save(); c.globalCompositeOperation = 'lighter'; c.lineCap = 'round'; c.lineJoin = 'round';
    for (let i = 1; i < tr.length; i++) {
      const a = tr[i - 1], b = tr[i], k = 1 - (T - b.t) / 0.32;
      c.strokeStyle = hsl(hue(i * 14), 100, 62, clamp(k, 0, 1) * 0.9); c.lineWidth = 2 + 9 * k;
      c.beginPath(); c.moveTo(a.x, a.y); c.lineTo(b.x, b.y); c.stroke();
    }
    c.restore();
  }
  let fpsShow = 60, fpsN = 0, fpsAcc = 0, fpsEMA = 60, lowT = 0, highT = 0;
  function fpsTrack(dt) {
    fpsN++; fpsAcc += dt; if (fpsAcc >= 0.5) { fpsShow = fpsN / fpsAcc; fpsN = 0; fpsAcc = 0; }
    fpsEMA = lerp(fpsEMA, 1 / Math.max(dt, 0.001), 0.05);
    if (fpsEMA < 40) { lowT += dt; highT = 0; } else { lowT = Math.max(0, lowT - dt * 0.5); if (fpsEMA > 57) highT += dt; }
    if (lowT > 3 && degrade < 2) { degrade++; lowT = 0; highT = 0; applyDegrade(); }
    else if (highT > 15 && degrade > 0) { degrade--; highT = 0; applyDegrade(); }
  }
  function applyDegrade() { degradeMul = [1, 0.55, 0.3][degrade]; resize(); }
  function fpsDraw(c) {
    if (!S().showFps) return;
    const txt = Math.round(fpsShow) + ' FPS' + (degrade ? ' · eco ' + degrade : '');
    c.font = `700 11px ${FONT_M}`; const w = c.measureText(txt).width + 12;
    c.fillStyle = 'rgba(11,6,32,.7)'; rrect(c, 8, H - 26, w, 18, 6); c.fill();
    c.fillStyle = fpsShow < 40 ? '#ff4d6d' : '#b6ff3b'; c.textAlign = 'left'; c.textBaseline = 'middle'; c.fillText(txt, 14, H - 16.5);
  }

  /* ═════════════════════════ update & render ═════════════════════════ */
  function update(dt) {
    V = CO.vis || {}; heat = clamp((CO.combo && CO.combo.heat) || 0, 0, 1);
    const st = S(); pBudget = ([80, 300, 900][st.particles] || (st.particles === 0 ? 80 : 900)) * (reduced() ? 0.5 : 1) * degradeMul;
    pm = ([0.22, 0.55, 1][st.particles] != null ? [0.22, 0.55, 1][st.particles] : 1) * (reduced() ? 0.5 : 1) * degradeMul;
    ck.sv += ((1 - ck.s) * 260 - ck.sv * 12) * dt; ck.s += ck.sv * dt;
    ck.sqv += (-ck.sq * 320 - ck.sqv * 10) * dt; ck.sq += ck.sqv * dt;
    ck.tiltv += (-ck.tilt * 120 - ck.tiltv * 9) * dt; ck.tilt += ck.tiltv * dt;
    ck.cbv += (-ck.cb * 220 - ck.cbv * 9) * dt; ck.cb += ck.cbv * dt;
    ck.swv += (-ck.sw * 40 - ck.swv * 2.5) * dt; ck.sw += ck.swv * dt;
    const over = ptr.on && isOverCookie(ptr.x, ptr.y);
    ck.hover = lerp(ck.hover, over ? 1 : 0, 1 - Math.exp(-dt * 10));
    ck.mouth = Math.max(0, ck.mouth - dt * 3); ck.laser = Math.max(0, ck.laser - dt * 4); ck.pulse *= Math.exp(-dt * 6);
    const fev = feverOn(); feverK = lerp(feverK, fev ? 1 : 0, 1 - Math.exp(-dt * 4));
    ck.spinv = lerp(ck.spinv, fev ? 3.4 : 0, 1 - Math.exp(-dt * 2)); ck.spin += ck.spinv * dt;
    cursorTap = Math.max(0, cursorTap - dt * 5); bgPulse *= Math.exp(-dt * 5);
    shakeAmp *= Math.exp(-dt * 9); flash *= Math.exp(-dt * 5);
    if (V.glitch && T > nextGlitch) {
      glitchStart = T; nextGlitch = T + (fev ? rand(0.6, 1.5) : rand(2, 4));
      glitchOff = []; const n = 6 + ((Math.random() * 4) | 0); for (let i = 0; i < n; i++) glitchOff.push(Math.random() < 0.5 ? 0 : rand(-0.14, 0.14));
    }
    if (fev && !reduced() && Math.random() < 0.5 * pm) { const a = Math.random() * TAU, rr = R * rand(1.1, 1.8); spawn('star', CX + Math.cos(a) * rr, CY + Math.sin(a) * rr, 0, -20, 0.7, rand(12, 22), hq(hue(Math.random() * 360), 70)); }
    updateParticles(dt); fireUpdate(dt); updateFx();
    let over2 = over; if (!over2) for (const g of GOLD_POS.values()) if (Math.hypot(ptr.x - g.x, ptr.y - g.y) <= g.r) { over2 = true; break; }
    const cur = ptr.on && over2 ? 'pointer' : ''; if (cvs && cvs.style.cursor !== cur) cvs.style.cursor = cur;
  }
  function render(dt) {
    const c = ctx;
    c.setTransform(dpr, 0, 0, dpr, 0, 0); c.globalAlpha = 1; c.globalCompositeOperation = 'source-over';
    drawTheme(c, dt);
    if (feverK > 0.01) { c.globalCompositeOperation = 'lighter'; c.fillStyle = hsl(hue(0), 100, 50, 0.07 * feverK + 0.05 * bgPulse); c.fillRect(0, 0, W, H); c.globalCompositeOperation = 'source-over'; }
    else if (bgPulse > 0.02) { c.globalCompositeOperation = 'lighter'; c.fillStyle = hsl(hue(0), 100, 55, 0.06 * bgPulse); c.fillRect(0, 0, W, H); c.globalCompositeOperation = 'source-over'; }
    drawVignette(c);
    shx = shy = 0; if (shakeAmp > 0.3) { shx = rand(-1, 1) * shakeAmp; shy = rand(-1, 1) * shakeAmp; }
    baseXf(c);
    if (V.god_rays) godRays(c);
    if (V.black_hole) blackHole(c);
    if (V.warp) warp(c, DT);
    if (V.cookie_rain) cookieRain(c, DT);
    if (V.disco) discoBack(c);
    if (bgPulse > 0.05 && V.beat_pulse) { c.globalCompositeOperation = 'lighter'; c.globalAlpha = bgPulse * 0.5; spr(c, glowH(hue(0)), CX, CY, R * 5); c.globalAlpha = 1; c.globalCompositeOperation = 'source-over'; }
    parade(c);
    fireDraw(c);
    if (V.saturn_ring) saturn(c, false);
    if (V.orbiters) orbiters(c, false);
    rebirthStars(c, false);
    cursorRing(c);
    drawMainCookie(c);
    if (V.saturn_ring) saturn(c, true);
    if (V.orbiters) orbiters(c, true);
    rebirthStars(c, true);
    lightning(c, DT);
    drawRings(c);
    lasersDraw(c);
    if (V.disco) discoBall(c);
    petsDraw(c, DT);
    goldensDraw(c);
    bossDraw(c, DT);
    projDraw(c);
    chatDraw(c, DT);
    drawParticles(c);
    textsDraw(c);
    labelsDraw(c);
    c.setTransform(dpr, 0, 0, dpr, 0, 0);
    feverOverlay(c);
    if (flash > 0.01) { c.fillStyle = `rgba(${flashCol},${(flash * 0.6).toFixed(3)})`; c.fillRect(0, 0, W, H); }
    trailDraw(c);
    fpsDraw(c);
  }
  function frame() {
    requestAnimationFrame(frame);
    const now = performance.now();
    let dt = (now - lastTs) / 1000; lastTs = now; if (!(dt > 0)) dt = 1 / 60; dt = Math.min(dt, 0.05);
    if (paused) { if (now - lastPausedDraw < 1000) return; lastPausedDraw = now; }
    T = CO.now ? CO.now() : now / 1000; DT = dt * (reduced() ? 0.5 : 1); AT += DT;
    if (now - lastPlayRead > 500) readPlay();
    { const k = 1 - Math.exp(-dt * 12); CX = lerp(CX, tgt.x, k); CY = lerp(CY, tgt.y, k); R = lerp(R, tgt.r, k); }
    if (!paused) fpsTrack(dt);
    try { update(DT); render(DT); } catch (e) { if (!frame.err) { frame.err = 1; console.error('[stage]', e); } }
  }

  /* ═════════════════════════ layout ═════════════════════════ */
  const tgt = { x: 400, y: 330, r: 120, init: false }; let snapLayout = false;
  function readPlay() {
    lastPlayRead = performance.now();
    const el = document.getElementById('play'); let r = el && el.getBoundingClientRect();
    if (!r || r.width < 20 || r.height < 20) r = { left: 0, top: 0, width: W, height: H };
    play.left = r.left; play.top = r.top; play.width = r.width; play.height = r.height; play.right = r.left + r.width; play.bottom = r.top + r.height;
    tgt.x = r.left + r.width / 2; tgt.y = r.top + r.height * 0.56; tgt.r = clamp(Math.min(r.width, r.height * 0.8) * 0.22, 60, 170);
    if (!tgt.init || snapLayout) { tgt.init = true; snapLayout = false; CX = tgt.x; CY = tgt.y; R = tgt.r; }
  }
  function resize() {
    if (!cvs) return;
    W = window.innerWidth || 800; H = window.innerHeight || 600;
    const st = S(); let d = Math.min(window.devicePixelRatio || 1, 2); if ((st.particles != null ? st.particles : 2) < 2) d = Math.min(d, 1.5);
    if (degrade >= 1) d = Math.min(d, 1.25); if (degrade >= 2) d = 1;
    dpr = d;
    const pw = Math.round(W * dpr), ph = Math.round(H * dpr);
    if (cvs.width !== pw || cvs.height !== ph) { cvs.width = pw; cvs.height = ph; }
    snapLayout = true; readPlay();
  }
  function isOverCookie(x, y) { return Math.hypot(x - CX, y - CY) <= R * Math.max(1, ck.s) * (1 + 0.05 * ck.hover) * 1.02; }

  /* ═════════════════════════ events ═════════════════════════ */
  function crumbs(x, y, n) {
    const p = skinDef().pal, cols = [p.base, p.dark, p.light, p.chip];
    n = cnt(n);
    for (let i = 0; i < n; i++) { const a = rand(-Math.PI, 0) + rand(-0.5, 0.5), v = rand(120, 380); spawn('crumb', x, y, Math.cos(a) * v, Math.sin(a) * v, rand(0.5, 0.9), rand(3, 7), pick(cols), 1100, 0.985, false); }
  }
  function sparkleRing(x, y, rad, n, cols, speed) {
    n = cnt(n);
    for (let i = 0; i < n; i++) { const a = (i / n) * TAU; spawn(i % 2 ? 'star' : 'glow', x + Math.cos(a) * rad, y + Math.sin(a) * rad, Math.cos(a) * (speed || 220), Math.sin(a) * (speed || 220), rand(0.5, 0.9), rand(14, 24), cols ? pick(cols) : hq(hue(i * 20), 65), 0, 0.93); }
  }
  let lastWave = -9;
  function onClick(e) {
    const x = isFinite(e.x) ? e.x : CX, y = isFinite(e.y) ? e.y : CY, crit = !!e.crit;
    ck.sqv = clamp(ck.sqv + (crit ? 13 : 8), -13, 13); ck.sv = clamp(ck.sv - (crit ? 2.2 : 1.3), -2.6, 2.6);
    ck.tiltv = clamp(ck.tiltv + clamp((x - CX) / R, -1, 1) * (crit ? 3.2 : 2), -3.5, 3.5);
    ck.mouth = 1; ck.cbv = clamp(ck.cbv - (crit ? 3.4 : 2.2), -4, 4); ck.swv = clamp(ck.swv + (x < CX ? 1 : -1) * (crit ? 1.2 : 0.7), -2.5, 2.5);
    const amt = e.amount != null ? '+' + (CO.fmt ? CO.fmt(e.amount) : Math.round(e.amount)) : '+1';
    addText(x, y - 12, amt, crit ? 'crit' : 'num', e.mult > 1 ? 'x' + (Math.round(e.mult * 10) / 10).toString().replace('.', ',') : null);
    crumbs(x, y, crit ? 16 : 8);
    if (crit) { shake(10); burst(x, y, 16, { cols: ['#ffd23c', '#fff3a0', '#ff8a00'], speed: 380, size: 16, life: 0.6 }); ring(x, y, 10, R * 0.9, 0.4, 8, '#ffd23c'); }
    else shake(1.2);
    if (V.shockwave && (crit || T - lastWave > 0.14)) { lastWave = T; ring(CX, CY, R * 0.95, R * (crit ? 3 : 2.3), crit ? 0.6 : 0.45, R * (crit ? 0.1 : 0.06), 'rgb'); }
    if (V.confetti_click) confettiBurst(x, y, crit ? 34 : 16, { speed: 460, spread: 1.4 });
    if (V.laser_eyes) { if (LASERS.length > 6) LASERS.shift(); LASERS.push({ x, y, t0: T }); ck.laser = 1; burst(x, y, 10, { cols: ['#ff3b4f', '#ffb0b8', '#ffffff'], speed: 320, size: 12, life: 0.4, type: 'spark' }); }
    if (V.chat && Math.random() < (feverOn() ? 0.45 : 0.22)) chatSpawn();
    if (V.cursor_rgb) cursorTap = 1;
    for (const p of PETS) if (p.hop < 6) p.hopv = rand(240, 340);
    if (CO.boss) {
      if (PROJ.length > 24) PROJ.shift();
      lastProj = { t0: T, dur: V.laser_eyes ? 0.12 : 0.32, kind: V.laser_eyes ? 'laser' : 'cookie', side: Math.random() < 0.5 ? -1 : 1, hit: null };
      PROJ.push(lastProj);
    }
  }
  function goldPoint(g) { const p = GOLD_POS.get(g && g.id); return p || (g ? goldPx(g) : { x: CX, y: CY }); }
  const handlers = {
    click: onClick,
    'golden:spawn'(e) { const p = goldPoint(e.g); sparkleRing(p.x, p.y, 10, 12, ['#ffd23c', '#fff3a0'], 160); },
    'golden:expire'(e) { const p = goldPoint(e.g); burst(p.x, p.y, 10, { cols: ['#b3a6dd', '#ffe9a0'], speed: 90, size: 18, life: 0.7, type: 'glow' }); },
    'golden:click'(e) {
      const p = goldPoint(e.g);
      burst(p.x, p.y, 50, { cols: ['#ffd23c', '#fff3a0', '#ff8a00', '#ffffff'], speed: 520, size: 20, life: 1 });
      confettiBurst(p.x, p.y, 24, { speed: 520 });
      ring(p.x, p.y, 20, R * 2.2, 0.6, 14, '#ffd23c'); ring(p.x, p.y, 10, R * 1.4, 0.45, 8, 'rgb');
      addLabel(e.label, e.color === 'rgb' ? 'rgb' : e.color || '#ffd23c', 1); shake(8); doFlash(0.35, '255,220,120');
      if (e.kind === 'gems') for (let i = 0; i < cnt(14); i++) { const q = spawn('icon', rand(play.left, play.right), play.top - 20, rand(-30, 30), rand(60, 200), 2.2, rand(18, 28), '#3dffb0', 380, 1, false); if (q) q.name = 'ui:gem'; }
    },
    'fever:start'() {
      feverT0 = T; burst(CX, CY, 140, { speed: 700, size: 22, life: 1.2, r0: R * 0.8 });
      confettiBurst(CX, CY - R * 0.5, 40, { speed: 700, spread: 1.6 });
      ring(CX, CY, R, Math.max(W, H) * 0.8, 0.9, 24, 'rgb'); ring(CX, CY, R, R * 3, 0.6, 12, '#ffffff');
      doFlash(0.6); shake(16); addLabel('FIÈVRE RGB !!', 'rgb', 1.15); ck.sv -= 3;
    },
    'fever:end'() { ring(CX, CY, R, R * 2.4, 0.5, 8, 'rgb'); },
    'boss:spawn'(e) { BV = null; const b = e.boss || CO.boss; if (b) BV = { boss: b, t0: T, hpD: 1, trail: 1, flash: 0, kb: 0, kbv: 0, state: 'live', tEnd: 0 }; shake(10); doFlash(0.25, '255,60,80'); },
    'boss:hit'(e) {
      if (lastProj && !lastProj.hit && T - lastProj.t0 < 0.08) lastProj.hit = { dmg: e.dmg, crit: e.crit };
      else bossHit(e.dmg, e.crit);
    },
    'boss:defeat'(e) {
      const bp = bossPos(), col = (e.boss && e.boss.color) || '#3dff6a';
      for (const p of PROJ) if (p.hit) { p.hit = null; }
      burst(bp.x, bp.y, 160, { cols: [col, '#ffffff', '#ffd23c', '#ff4d6d'], speed: 800, size: 24, life: 1.3 });
      confettiBurst(bp.x, bp.y, 50, { speed: 700, spread: 1.8 });
      ring(bp.x, bp.y, 20, R * 3.5, 0.8, 26, col); ring(bp.x, bp.y, 10, R * 2.2, 0.6, 14, 'rgb'); ring(bp.x, bp.y, 5, R * 1.2, 0.35, 10, '#ffffff');
      doFlash(0.6); shake(20); addLabel('BOSS VAINCU !', 'rgb', 1.2);
      if (BV) { BV.state = 'dead'; BV.tEnd = T; }
    },
    'boss:escape'() { if (BV) { BV.state = 'escape'; BV.tEnd = T; } addLabel("Il s'est enfui…", '#b3a6dd', 0.7); },
    visuals(e) {
      const added = (e && e.added) || [];
      for (const k of added) {
        pop[k] = T;
        const zone = DATA().visuals && DATA().visuals[k] && DATA().visuals[k].zone;
        sparkleRing(CX, CY, R * (zone === 'screen' ? 1.4 : 1.1), 28, null, 300);
        ring(CX, CY, R * 0.9, R * 2.6, 0.6, 16, 'rgb'); ring(CX, CY, R * 0.9, R * 1.9, 0.45, 8, '#ffffff');
      }
      if (added.length) { doFlash(0.45); ck.sv -= 2.5; shake(5); }
    },
    skin() { doFlash(0.4); ck.sv -= 3; sparkleRing(CX, CY, R, 30, null, 320); ring(CX, CY, R * 0.9, R * 2.4, 0.55, 14, 'rgb'); },
    theme(e) { const id = (e && e.id) || (CO.state && CO.state.theme); if (id && id !== themeId && THEMES[id]) { prevTheme = themeId; themeId = id; themeT0 = T; } },
    pets() { refreshPets(); },
    'pet:hatch'(e) {
      refreshPets(); const p = PETS.find((q) => e.pet && q.uid === e.pet.uid);
      const pos = p ? petPos(p) : { x: CX, y: CY };
      if (p) p.born = T;
      sparkleRing(pos.x, pos.y, 12, 26, null, 260); burst(pos.x, pos.y, 20, { speed: 300, size: 18 });
    },
    achievement() { sparkleRing(CX, CY, R * 1.15, 36, ['#ffd23c', '#fff3a0', '#ffffff'], 260); ring(CX, CY, R, R * 2.2, 0.6, 10, '#ffd23c'); },
    'fx:confetti'() {
      const n = 110;
      for (let i = 0; i < cnt(n); i++) spawn('confetti', rand(0, W), rand(-60, -5), rand(-80, 80), rand(60, 260), rand(2.2, 3.6), rand(8, 14), hq(Math.random() * 360, rand(55, 68)), 320, 0.99, false);
      burst(CX, CY, 60, { speed: 620, size: 22, life: 1.1 }); confettiBurst(CX, CY, 30, { speed: 650, spread: 1.7 });
      ring(CX, CY, R, Math.max(W, H) * 0.6, 0.9, 18, 'rgb'); doFlash(0.35); shake(8);
    },
    rebirth() { burst(CX, CY, 80, { cols: ['#ffd23c', '#fff3a0', '#ffffff'], speed: 600, size: 22 }); ring(CX, CY, R, R * 3, 0.8, 18, '#ffd23c'); doFlash(0.5, '255,230,150'); },
    beat() { if (V.beat_pulse) { ck.pulse = 1; bgPulse = 1; if (feverOn()) shake(4); } },
    buy(e) { if (e && e.kind === 'building') { paradeBounce[e.id] = T; if (e.id === 'cursor') cursorTap = 1; } },
    settings() { resize(); },
    layout() { readPlay(); },
    load() { refreshPets(); handlers.theme({ id: CO.state && CO.state.theme }); },
    'minigame:open'() { paused = true; lastPausedDraw = 0; },
    'minigame:close'() { paused = false; lastTs = performance.now(); },
  };

  /* ═════════════════════════ input ═════════════════════════ */
  function onPointerDown(e) {
    const x = e.clientX, y = e.clientY;
    ptr.x = x; ptr.y = y; ptr.t = T; ptr.on = true;
    for (const [id, p] of GOLD_POS) if (Math.hypot(x - p.x, y - p.y) <= p.r) { if (CO.clickGolden) CO.clickGolden(id); e.preventDefault(); return; }
    if (isOverCookie(x, y)) { if (CO.clickCookie) CO.clickCookie(x, y); e.preventDefault(); }
  }
  function onPointerMove(e) {
    ptr.x = e.clientX; ptr.y = e.clientY; ptr.t = T; ptr.on = e.target === cvs;
    const tr = ptr.trail, l = tr[tr.length - 1];
    if (e.pointerType !== 'touch' && (!l || Math.hypot(l.x - ptr.x, l.y - ptr.y) > 3)) { tr.push({ x: ptr.x, y: ptr.y, t: T }); if (tr.length > 40) tr.shift(); }
  }

  /* ═════════════════════════ public API ═════════════════════════ */
  function init(canvas) {
    if (inited) { if (canvas && canvas !== cvs) { cvs = canvas; ctx = cvs.getContext('2d'); resize(); } return; }
    inited = true;
    cvs = canvas || document.getElementById('stage');
    if (!cvs) { cvs = document.createElement('canvas'); cvs.id = 'stage'; cvs.style.cssText = 'position:fixed;inset:0;'; document.body.prepend(cvs); }
    ctx = cvs.getContext('2d');
    cvs.style.width = '100%'; cvs.style.height = '100%'; cvs.style.touchAction = 'manipulation'; cvs.style.userSelect = 'none';
    T = CO.now ? CO.now() : performance.now() / 1000;
    if (CO.state && CO.state.theme && THEMES[CO.state.theme]) themeId = CO.state.theme;
    resize(); refreshPets();
    if (CO.on) for (const k of Object.keys(handlers)) CO.on(k, (e) => handlers[k](e || {}));
    cvs.addEventListener('pointerdown', onPointerDown);
    window.addEventListener('pointermove', onPointerMove, { passive: true });
    window.addEventListener('pointerdown', (e) => { if (e.target !== cvs) ptr.on = false; }, { passive: true });
    document.addEventListener('pointerleave', () => { ptr.on = false; });
    window.addEventListener('blur', () => { ptr.on = false; });
    window.addEventListener('resize', resize);
    if (window.visualViewport) window.visualViewport.addEventListener('resize', resize);
    lastTs = performance.now();
    requestAnimationFrame(frame);
  }

  CO.stage = { init, resize, drawCookie, isOverCookie };
})();
