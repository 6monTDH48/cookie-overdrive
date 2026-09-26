/* COOKIE OVERDRIVE — mg-slots.js : « Casino Crumble » (id: slots)
 * Neon 3-reel slot machine. Outcome table tuned for an expected return of ~0.945 × bet per spin
 * (see _sim on the definition: pickOutcome + evaluate are pure and verified by simulation).
 * No emoji anywhere: symbols come from CO.art (art.js) with hand-drawn vector fallbacks.
 */
(function () {
  'use strict';
  const CO = window.CO;
  if (!CO || typeof CO.registerMinigame !== 'function') return;

  const FD = '"Lilita One", "Arial Rounded MT Bold", "Trebuchet MS", sans-serif';
  const FM = '"Chakra Petch", ui-monospace, Menlo, monospace';
  const INK = '#1a0b33';
  const TAU = Math.PI * 2;

  /* ───────────────────────── math model ───────────────────────── */
  const SYMS = ['cookie', 'seven', 'gem', 'choco', 'milk', 'donut', 'cupcake', 'broc'];
  const ART = { seven: 'item:seven', gem: 'ui:gem', choco: 'item:choco', milk: 'item:milk', donut: 'item:donut', cupcake: 'item:cupcake', broc: 'item:broccoli' };
  // Probability of each outcome class per spin (payout × bet, stake included).
  const OUTCOMES = [
    { kind: 'jackpot', p: 0.0065 },  // 7 7 7        ×25
    { kind: 'cookie3', p: 0.013 },   // cookie ×3    ×10
    { kind: 'gem3', p: 0.016 },      // gem ×3       ×5 + 15 gems
    { kind: 'triple', p: 0.042 },    // other ×3     ×4
    { kind: 'pair', p: 0.27 },       // any 2 (not broccoli) ×1.5
    { kind: 'broc3', p: 0.02 },      // SKILL ISSUE  ×0
    { kind: 'lose', p: 1 },          // remainder
  ];
  const PAIR_W = { cookie: 2, seven: 1.2, gem: 1.6, choco: 4, milk: 4, donut: 4, cupcake: 4 };
  const ODD_W = { cookie: 3, seven: 2, gem: 2.5, choco: 4, milk: 4, donut: 4, cupcake: 4, broc: 4 };
  function wpick(w, excl, rng) {
    const keys = Object.keys(w).filter((k) => !excl.includes(k));
    let tot = 0; for (const k of keys) tot += w[k];
    let r = rng() * tot;
    for (const k of keys) { r -= w[k]; if (r < 0) return k; }
    return keys[keys.length - 1];
  }
  function pickOutcome(rng) {
    rng = rng || Math.random;
    let r = rng(), kind = 'lose';
    for (const o of OUTCOMES) { if (r < o.p) { kind = o.kind; break; } r -= o.p; }
    let s;
    switch (kind) {
      case 'jackpot': s = ['seven', 'seven', 'seven']; break;
      case 'cookie3': s = ['cookie', 'cookie', 'cookie']; break;
      case 'gem3': s = ['gem', 'gem', 'gem']; break;
      case 'broc3': s = ['broc', 'broc', 'broc']; break;
      case 'triple': { const k = ['choco', 'milk', 'donut', 'cupcake'][Math.floor(rng() * 4)]; s = [k, k, k]; break; }
      case 'pair': {
        const k = wpick(PAIR_W, [], rng), odd = wpick(ODD_W, [k], rng);
        s = [k, k, k]; s[Math.floor(rng() * 3)] = odd; break;
      }
      default:
        if (rng() < 0.12) { const odd = wpick(ODD_W, ['broc'], rng); s = ['broc', 'broc', 'broc']; s[Math.floor(rng() * 3)] = odd; }
        else { const a = wpick(ODD_W, [], rng), b = wpick(ODD_W, [a], rng), c = wpick(ODD_W, [a, b], rng); s = [a, b, c]; }
    }
    return s;
  }
  // the rules — payout is always computed from the symbols shown
  function evaluate(s) {
    const [a, b, c] = s;
    if (a === b && b === c) {
      if (a === 'seven') return { kind: 'jackpot', mult: 25, gems: 0, hit: [0, 1, 2] };
      if (a === 'cookie') return { kind: 'cookie3', mult: 10, gems: 0, hit: [0, 1, 2] };
      if (a === 'gem') return { kind: 'gem3', mult: 5, gems: 15, hit: [0, 1, 2] };
      if (a === 'broc') return { kind: 'broc3', mult: 0, gems: 0, hit: [0, 1, 2] };
      return { kind: 'triple', mult: 4, gems: 0, hit: [0, 1, 2] };
    }
    const hit = a === b ? [0, 1] : a === c ? [0, 2] : b === c ? [1, 2] : null;
    if (hit && s[hit[0]] !== 'broc') return { kind: 'pair', mult: 1.5, gems: 0, hit };
    return { kind: 'lose', mult: 0, gems: 0, hit: [] };
  }

  /* ───────────────────────── helpers ───────────────────────── */
  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
  const rand = (a, b) => a + Math.random() * (b - a);
  const hsl = (h, s, l, a) => (a === undefined ? `hsl(${h},${s}%,${l}%)` : `hsla(${h},${s}%,${l}%,${a})`);
  const easeOutBack = (x, c1) => { c1 = c1 || 1.3; const c3 = c1 + 1; return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2); };
  const easeOut3 = (x) => 1 - Math.pow(1 - x, 3);
  function el(tag, cls, html) { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; }
  function otext(ctx, str, x, y, size, fill, align, lw) {
    ctx.font = `${size}px ${FD}`;
    ctx.textAlign = align || 'center'; ctx.textBaseline = 'middle'; ctx.lineJoin = 'round';
    ctx.lineWidth = size * (lw || 0.2); ctx.strokeStyle = INK;
    ctx.strokeText(str, x, y + size * 0.07);
    ctx.strokeText(str, x, y);
    ctx.fillStyle = fill; ctx.fillText(str, x, y);
  }
  function rainbow(ctx, x0, x1, h) {
    const g = ctx.createLinearGradient(x0, 0, x1, 0);
    for (let i = 0; i <= 6; i++) g.addColorStop(i / 6, hsl((h + i * 55) % 360, 100, 64));
    return g;
  }
  function rr(c, x, y, w, h, r) {
    r = Math.max(0, Math.min(r, w / 2, h / 2));
    c.beginPath(); c.moveTo(x + r, y); c.arcTo(x + w, y, x + w, y + h, r); c.arcTo(x + w, y + h, x, y + h, r); c.arcTo(x, y + h, x, y, r); c.arcTo(x, y, x + w, y, r); c.closePath();
  }
  const ico = (name, fb) => `<i class="cos-ico cos-fb-${fb || 'none'}" data-art="${name}"></i>`;
  function hydrateArt(scope) {
    const A = CO.art;
    if (!A || typeof A.el !== 'function') return;
    scope.querySelectorAll('[data-art]').forEach((slot) => {
      if (slot.classList.contains('has-art')) return;
      const name = slot.getAttribute('data-art');
      if (typeof A.has === 'function' && !A.has(name)) return; // unknown icon → keep the CSS fallback
      let img = null;
      try { img = A.el(name, 'cos-img'); } catch (e) { img = null; }
      if (img) { slot.classList.add('has-art'); slot.appendChild(img); }
    });
  }
  function artDraw(ctx, name, x, y, size, opts) {
    const A = CO.art;
    if (!A || typeof A.draw !== 'function') return false;
    try { return A.draw(ctx, name, x, y, size, opts || {}) !== false; } catch (e) { return false; }
  }

  /* hand-drawn fallback symbols, drawn centred at 0,0 in a box of size s */
  const FB = {
    seven(c, s) {
      c.font = `${Math.round(s * 0.98)}px ${FD}`; c.textAlign = 'center'; c.textBaseline = 'middle'; c.lineJoin = 'round';
      c.lineWidth = s * 0.15; c.strokeStyle = INK;
      c.strokeText('7', 0, s * 0.09); c.strokeText('7', 0, s * 0.04);
      const g = c.createLinearGradient(0, -s * 0.4, 0, s * 0.4);
      g.addColorStop(0, '#ff3d7a'); g.addColorStop(0.35, '#ffe600'); g.addColorStop(0.65, '#2bff88'); g.addColorStop(1, '#00b3ff');
      c.fillStyle = g; c.fillText('7', 0, s * 0.04);
      c.globalAlpha = 0.5; c.fillStyle = '#fff'; c.fillRect(-s * 0.22, -s * 0.33, s * 0.3, s * 0.05); c.globalAlpha = 1;
    },
    gem(c, s) {
      const r = s * 0.42;
      const P = [[-0.6, -0.55], [0.6, -0.55], [1, -0.1], [0, 0.9], [-1, -0.1]];
      c.beginPath(); P.forEach(([x, y], i) => (i ? c.lineTo(x * r, y * r) : c.moveTo(x * r, y * r))); c.closePath();
      const g = c.createLinearGradient(-r, -r, r, r);
      g.addColorStop(0, '#e6feff'); g.addColorStop(0.5, '#1ff4ff'); g.addColorStop(1, '#0a7fb8');
      c.lineJoin = 'round'; c.lineWidth = s * 0.07; c.strokeStyle = INK; c.stroke(); c.fillStyle = g; c.fill();
      c.strokeStyle = 'rgba(255,255,255,.75)'; c.lineWidth = s * 0.025;
      c.beginPath(); c.moveTo(-r, -0.1 * r); c.lineTo(r, -0.1 * r);
      c.moveTo(-0.6 * r, -0.55 * r); c.lineTo(-0.3 * r, -0.1 * r); c.lineTo(0, 0.9 * r); c.lineTo(0.3 * r, -0.1 * r); c.lineTo(0.6 * r, -0.55 * r);
      c.moveTo(-0.3 * r, -0.1 * r); c.lineTo(0, -0.55 * r); c.lineTo(0.3 * r, -0.1 * r); c.stroke();
      c.fillStyle = 'rgba(255,255,255,.85)'; c.beginPath(); c.moveTo(-0.55 * r, -0.45 * r); c.lineTo(-0.2 * r, -0.45 * r); c.lineTo(-0.38 * r, -0.2 * r); c.closePath(); c.fill();
    },
    choco(c, s) {
      c.rotate(-0.22);
      const w = s * 0.5, h = s * 0.8;
      rr(c, -w / 2, -h / 2, w, h, s * 0.06); c.lineWidth = s * 0.07; c.strokeStyle = INK; c.stroke();
      c.fillStyle = '#5a2d14'; c.fill();
      for (let yy = 0; yy < 3; yy++) for (let xx = 0; xx < 2; xx++) {
        const cx = -w / 2 + s * 0.05 + xx * (w - s * 0.1) / 2, cy = -h / 2 + s * 0.05 + yy * s * 0.14;
        rr(c, cx + s * 0.012, cy + s * 0.012, (w - s * 0.1) / 2 - s * 0.024, s * 0.12, s * 0.02);
        c.fillStyle = '#7a4424'; c.fill();
        c.fillStyle = 'rgba(255,220,180,.35)'; c.fillRect(cx + s * 0.03, cy + s * 0.025, s * 0.06, s * 0.02);
      }
      rr(c, -w / 2 - s * 0.02, h / 2 - h * 0.42, w + s * 0.04, h * 0.42 + s * 0.02, s * 0.05);
      const g = c.createLinearGradient(-w / 2, 0, w / 2, 0); g.addColorStop(0, '#b0108f'); g.addColorStop(0.5, '#ff4fe1'); g.addColorStop(1, '#b0108f');
      c.lineWidth = s * 0.06; c.stroke(); c.fillStyle = g; c.fill();
      c.fillStyle = '#ffc93c'; c.fillRect(-w / 2 - s * 0.01, h / 2 - h * 0.32, w + s * 0.02, s * 0.07);
    },
    milk(c, s) {
      const tw = s * 0.52, bw = s * 0.38, h = s * 0.76, top = -h / 2;
      c.save();
      c.strokeStyle = '#ff2bd6'; c.lineWidth = s * 0.06; c.lineCap = 'round';
      c.beginPath(); c.moveTo(s * 0.05, top + s * 0.1); c.lineTo(s * 0.22, top - s * 0.1); c.stroke();
      c.restore();
      c.beginPath(); c.moveTo(-tw / 2, top); c.lineTo(tw / 2, top); c.lineTo(bw / 2, h / 2); c.lineTo(-bw / 2, h / 2); c.closePath();
      c.lineJoin = 'round'; c.lineWidth = s * 0.07; c.strokeStyle = INK; c.stroke();
      c.fillStyle = 'rgba(200,230,255,.35)'; c.fill();
      const mt = top + h * 0.22, k = (mt - top) / h, mw = tw - (tw - bw) * k;
      c.beginPath(); c.moveTo(-mw / 2 + s * 0.025, mt); c.lineTo(mw / 2 - s * 0.025, mt); c.lineTo(bw / 2 - s * 0.03, h / 2 - s * 0.03); c.lineTo(-bw / 2 + s * 0.03, h / 2 - s * 0.03); c.closePath();
      const g = c.createLinearGradient(-tw / 2, 0, tw / 2, 0); g.addColorStop(0, '#ffffff'); g.addColorStop(1, '#d6e2ff');
      c.fillStyle = g; c.fill();
      c.fillStyle = 'rgba(255,255,255,.9)'; c.fillRect(-tw / 2 + s * 0.07, top + s * 0.06, s * 0.05, h * 0.7);
    },
    donut(c, s) {
      const R = s * 0.41, r = s * 0.13;
      c.beginPath(); c.arc(0, 0, R, 0, TAU); c.arc(0, 0, r, 0, TAU, true);
      c.lineWidth = s * 0.07; c.strokeStyle = INK; c.stroke(); c.fillStyle = '#e3a15c'; c.fill('evenodd');
      c.beginPath();
      for (let i = 0; i <= 24; i++) { const a = (i / 24) * TAU, rr2 = R * (0.84 + Math.sin(i * 2.7) * 0.05); i ? c.lineTo(Math.cos(a) * rr2, Math.sin(a) * rr2) : c.moveTo(Math.cos(a) * rr2, Math.sin(a) * rr2); }
      c.closePath(); c.moveTo(r * 1.35, 0); c.arc(0, 0, r * 1.35, 0, TAU, true);
      c.fillStyle = '#ff6be6'; c.fill('evenodd');
      const cols = ['#fff', '#1ff4ff', '#ffe600', '#b6ff3b', '#8a5cff'];
      for (let i = 0; i < 12; i++) {
        const a = i * 2.4, d = r * 1.6 + (i % 3) * R * 0.14;
        c.save(); c.translate(Math.cos(a) * d, Math.sin(a) * d); c.rotate(a * 1.7);
        c.fillStyle = cols[i % cols.length]; c.fillRect(-s * 0.03, -s * 0.01, s * 0.06, s * 0.02); c.restore();
      }
      c.fillStyle = 'rgba(255,255,255,.5)'; c.beginPath(); c.ellipse(-R * 0.45, -R * 0.5, R * 0.18, R * 0.08, -0.6, 0, TAU); c.fill();
    },
    cupcake(c, s) {
      const y0 = s * 0.02, y1 = s * 0.42, tw = s * 0.64, bw = s * 0.44;
      c.beginPath(); c.moveTo(-tw / 2, y0); c.lineTo(tw / 2, y0); c.lineTo(bw / 2, y1); c.lineTo(-bw / 2, y1); c.closePath();
      c.lineJoin = 'round'; c.lineWidth = s * 0.07; c.strokeStyle = INK; c.stroke(); c.fillStyle = '#1fd6ff'; c.fill();
      c.strokeStyle = 'rgba(10,80,120,.55)'; c.lineWidth = s * 0.03;
      for (let i = -2; i <= 2; i++) { c.beginPath(); c.moveTo(i * tw * 0.17, y0 + s * 0.02); c.lineTo(i * bw * 0.17, y1 - s * 0.02); c.stroke(); }
      const blobs = [[0, -s * 0.04, s * 0.33], [0, -s * 0.2, s * 0.24], [0, -s * 0.33, s * 0.14]];
      c.strokeStyle = INK; c.lineWidth = s * 0.07;
      for (const [x, y, r] of blobs) { c.beginPath(); c.ellipse(x, y, r, r * 0.62, 0, 0, TAU); c.stroke(); }
      blobs.forEach(([x, y, r], i) => { c.beginPath(); c.ellipse(x, y, r, r * 0.62, 0, 0, TAU); c.fillStyle = i % 2 ? '#ffd1f4' : '#ff8fe8'; c.fill(); });
      c.beginPath(); c.arc(s * 0.02, -s * 0.44, s * 0.07, 0, TAU); c.lineWidth = s * 0.05; c.stroke(); c.fillStyle = '#ff2b4a'; c.fill();
      c.fillStyle = 'rgba(255,255,255,.8)'; c.beginPath(); c.arc(0, -s * 0.46, s * 0.02, 0, TAU); c.fill();
    },
    broc(c, s) {
      c.beginPath(); c.moveTo(-s * 0.1, s * 0.02); c.lineTo(s * 0.1, s * 0.02); c.lineTo(s * 0.13, s * 0.42); c.lineTo(-s * 0.13, s * 0.42); c.closePath();
      c.lineJoin = 'round'; c.lineWidth = s * 0.07; c.strokeStyle = INK; c.stroke(); c.fillStyle = '#a6e37a'; c.fill();
      const fl = [[-s * 0.2, -s * 0.06, s * 0.17], [s * 0.2, -s * 0.06, s * 0.17], [0, -s * 0.22, s * 0.21], [0, -s * 0.02, s * 0.16]];
      for (const [x, y, r] of fl) { c.beginPath(); c.arc(x, y, r, 0, TAU); c.stroke(); }
      fl.forEach(([x, y, r], i) => { c.beginPath(); c.arc(x, y, r, 0, TAU); c.fillStyle = i % 2 ? '#2f9e3c' : '#3dbb4a'; c.fill(); });
      c.fillStyle = 'rgba(200,255,170,.55)';
      fl.forEach(([x, y, r]) => { c.beginPath(); c.arc(x - r * 0.3, y - r * 0.3, r * 0.28, 0, TAU); c.fill(); });
      c.fillStyle = INK;
      c.beginPath(); c.arc(-s * 0.05, s * 0.16, s * 0.022, 0, TAU); c.arc(s * 0.05, s * 0.16, s * 0.022, 0, TAU); c.fill();
      c.lineWidth = s * 0.02; c.beginPath(); c.arc(0, s * 0.27, s * 0.04, Math.PI * 1.15, Math.PI * 1.85); c.stroke();
    },
  };

  const CSS = `
.cos-wrap{position:absolute;inset:0;overflow:hidden;background:#0b0620;color:#fff6fe;font-family:'Fredoka',system-ui,sans-serif;-webkit-user-select:none;user-select:none;-webkit-tap-highlight-color:transparent}
.cos-cv{position:absolute;inset:0;width:100%;height:100%;display:block;touch-action:none}
.cos-top{position:absolute;left:0;right:0;top:0;display:flex;align-items:center;gap:8px;padding:8px 10px;box-sizing:border-box;pointer-events:none}
.cos-bank{display:flex;align-items:center;gap:6px;font-family:'Lilita One',sans-serif;font-size:20px;line-height:1;padding:5px 12px 6px 7px;border-radius:999px;background:rgba(10,4,30,.7);border:2px solid #ffc93c;box-shadow:0 0 14px rgba(255,201,60,.35),0 3px 0 #1a0b33;white-space:nowrap;transition:transform .12s}
.cos-bank.up{transform:scale(1.14)}
.cos-hist{display:flex;gap:5px;overflow:hidden;flex:1;justify-content:flex-end;min-width:0}
.cos-chip{flex:0 0 auto;font-family:'Lilita One',sans-serif;font-size:14px;line-height:1;padding:4px 8px 5px;border-radius:999px;border:2px solid #1a0b33;background:#3a2a70;color:#fff;animation:cos-pop .35s cubic-bezier(.2,1.7,.4,1) both;display:flex;align-items:center;gap:3px}
.cos-chip.l{background:#23164a;color:#7d6fae}
.cos-chip.w{background:#2bdc6a}
.cos-chip.t{background:#b6ff3b;color:#1a0b33}
.cos-chip.c{background:#ff2bd6}
.cos-chip.g{background:#1ff4ff;color:#1a0b33}
.cos-chip.j{background:linear-gradient(90deg,#ff004c,#ff8a00,#ffe600,#2bff88,#00d5ff,#7a5cff,#ff2bd6);text-shadow:0 1px 0 #1a0b33}
.cos-chip.x{background:#2f7d2a;color:#c8ff9e}
.cos-bottom{position:absolute;left:0;right:0;bottom:0;display:flex;flex-direction:column;align-items:center;gap:7px;padding:6px 10px 12px;box-sizing:border-box}
.cos-betline{font-family:'Chakra Petch',monospace;font-weight:700;font-size:13px;letter-spacing:.1em;color:#b3a6dd;display:flex;align-items:center;gap:6px;line-height:1;height:24px}
.cos-betline b{font-family:'Lilita One',sans-serif;font-weight:400;font-size:22px;color:#fff;letter-spacing:.02em}
.cos-betline.no b{color:#ff4d6d}
.cos-row{display:flex;gap:6px;width:min(470px,100%)}
.cos-row .btn{flex:1 1 0;min-width:0;padding-left:4px;padding-right:4px;white-space:nowrap}
.cos-bets .btn.sel{--c1:#fff3b0;--c2:#ffc93c;--c3:#c07a00;color:#1a0b33;text-shadow:none}
.cos-bets .btn.red.sel{--c1:#ffd0d8;--c2:#ff4d6d;--c3:#b3142f;color:#fff}
.cos-spin{font-size:28px!important;letter-spacing:.06em}
.cos-free{animation:cos-pulse .9s ease-in-out infinite;font-size:19px!important}
.cos-hint{font-size:11px;color:#7d6fae;font-family:'Chakra Petch',monospace;font-weight:600;letter-spacing:.06em;height:12px}
.cos-shake{animation:cos-shake .38s linear}
.cos-ico{display:inline-block;width:1.1em;height:1.1em;vertical-align:-.18em;position:relative;flex:0 0 auto}
.cos-ico img,.cos-img{width:100%;height:100%;display:block;object-fit:contain}
.cos-ico.has-art{background:none!important;clip-path:none!important;box-shadow:none!important;border-radius:0!important}
.cos-fb-none:not(.has-art){display:none}
.cos-fb-cookie{border-radius:50%;background:radial-gradient(circle at 34% 36%,#4a2511 0 9%,transparent 10%),radial-gradient(circle at 66% 52%,#4a2511 0 9%,transparent 10%),radial-gradient(circle at 42% 72%,#4a2511 0 8%,transparent 9%),#d99a4e;box-shadow:inset 0 0 0 .1em #8a5220,0 0 0 .08em #1a0b33}
.cos-fb-gem{background:linear-gradient(135deg,#e6feff,#1ff4ff 50%,#0a8fb8);clip-path:polygon(50% 100%,0 36%,20% 6%,80% 6%,100% 36%)}
.cos-fb-gift{background:linear-gradient(90deg,transparent 42%,#fff 42% 58%,transparent 58%),linear-gradient(transparent 38%,#fff 38% 50%,transparent 50%),#ff2bd6;border-radius:.15em;box-shadow:0 0 0 .08em #1a0b33}
.cos-rm .cos-free{animation:none}
.cos-short .cos-bottom{flex-direction:row;flex-wrap:wrap;justify-content:center;gap:6px;padding:4px 8px 8px}
.cos-short .cos-hint{display:none}
.cos-short .cos-betline{width:100%;justify-content:center;height:20px}
.cos-short .cos-row{width:auto;flex:1 1 220px;max-width:360px}
.cos-short .cos-actions .btn{font-size:18px!important;padding:8px 10px 10px}
@keyframes cos-pop{from{transform:scale(.2);opacity:0}to{transform:none;opacity:1}}
@keyframes cos-pulse{0%,100%{transform:scale(1)}50%{transform:scale(1.06)}}
@keyframes cos-shake{0%,100%{transform:none}20%{transform:translateX(-7px)}40%{transform:translateX(7px)}60%{transform:translateX(-5px)}80%{transform:translateX(4px)}}
`;

  /* ───────────────────────── minigame ───────────────────────── */
  CO.registerMinigame({
    id: 'slots',
    name: 'Casino Crumble',
    color: '#ffc93c',
    tagline: 'Mise tes cookies. Jackpot = aura infinie.',
    howto: 'Choisis ta mise, tire le levier (ou ESPACE). Trois 7 = JACKPOT ×25. Trois brocolis = skill issue.',
    mount,
    _sim: { pickOutcome, evaluate, OUTCOMES },
  });

  function mount(root, api) {
    let alive = true;
    const S = () => api.settings() || {};
    const wrap = el('div', 'cos-wrap');
    const style = el('style'); style.textContent = CSS; wrap.appendChild(style);
    const cv = el('canvas', 'cos-cv'); wrap.appendChild(cv);
    const ctx = cv.getContext('2d');
    const coarse = !!(window.matchMedia && window.matchMedia('(pointer: coarse)').matches);

    const top = el('div', 'cos-top', `<div class="cos-bank">${ico('ui:cookie', 'cookie')}<span class="v">0</span></div><div class="cos-hist"></div>`);
    const bottom = el('div', 'cos-bottom', `
      <div class="cos-betline">MISE <b>0</b> ${ico('ui:cookie', 'cookie')}</div>
      <div class="cos-row cos-bets">
        <button class="btn small dark" type="button" data-p="0.1">10 %</button>
        <button class="btn small dark" type="button" data-p="0.25">25 %</button>
        <button class="btn small dark" type="button" data-p="0.5">50 %</button>
        <button class="btn small red" type="button" data-p="1">ALL IN</button>
      </div>
      <div class="cos-row cos-actions">
        <button class="btn big gold cos-free" type="button">GRATUIT ${ico('ui:gift', 'gift')}</button>
        <button class="btn big pink cos-spin" type="button">SPIN</button>
      </div>
      <div class="cos-hint">${coarse ? 'TAPE LA MACHINE OU SPIN' : 'ESPACE = SPIN · 1 2 3 4 = MISE'}</div>`);
    wrap.appendChild(top); wrap.appendChild(bottom);
    hydrateArt(wrap);
    root.appendChild(wrap);
    if (document.activeElement && document.activeElement.blur) document.activeElement.blur();

    const bankEl = top.querySelector('.cos-bank'), bankV = bankEl.querySelector('.v'), histEl = top.querySelector('.cos-hist');
    const betLine = bottom.querySelector('.cos-betline'), betV = betLine.querySelector('b');
    const betBtns = [...bottom.querySelectorAll('.cos-bets .btn')];
    const freeBtn = bottom.querySelector('.cos-free'), spinBtn = bottom.querySelector('.cos-spin');
    // free spin button label: long version when there is room
    if (root.clientWidth >= 400) { freeBtn.innerHTML = `TOUR GRATUIT ${ico('ui:gift', 'gift')}`; hydrateArt(freeBtn); }

    /* ── state ── */
    let W = 320, H = 480, DPR = 1;
    const M = { x: 0, y: 0, w: 0, h: 0, cs: 80, pad: 10, gap: 8, headH: 50, winH: 150, meterH: 40, reelY: 0, meterY: 0, lever: false, lx: 0, ly: 0, bulbs: [] };
    let betPct = 0.1, freeLeft = 1;
    let spinning = false, lockUntil = 0, curBet = 0, curFree = false, result = null, outcome = null, resolved = true;
    let spins = 0, bestMult = 0, streak = 0, forced = null;
    let anticip = false, anticipT = 0, tickT = 0;
    let meter = { from: 0, to: 0, t0: 0, dur: 1, label: 'BONNE CHANCE', kind: 'idle', lastTick: 0 };
    let fx = { rays: 0, raysCol: 'rgb', tint: 0, tintCol: '#2bdc6a', flash: 0, flashCol: '#fff', shake: 0, big: null, hero: 0, fountain: 0, fountainKind: 'coin', droop: 0, bounce: 0, hitGlow: 0, deny: 0 };
    const parts = [], rings = [];
    let leverPull = 0, leverT = -9;
    let lastBank = -1, bankBumpT = 0;
    const live = new Map(); // own WebAudio sources
    let riserStop = null;

    const reels = [0, 1, 2].map(() => {
      const strip = [];
      for (let i = 0; i < 64; i++) strip.push(SYMS[Math.floor(Math.random() * SYMS.length)]);
      return { strip, off: Math.floor(Math.random() * 64), v: 0, state: 'idle', stopAt: 0, from: 0, F: 0, t0: 0, dur: 0.5, target: 'cookie', land: 0 };
    });
    const symAt = (r, idx) => r.strip[((idx % 64) + 64) % 64];

    /* ── symbol sprites (CO.art sprite → CO.art.draw → vector fallback), cached per pixel size ── */
    const cache = new Map();
    function symSprite(sym, px) {
      const key = sym + ':' + px;
      const now = performance.now();
      const e = cache.get(key);
      if (e && (e.art || now - e.t < 1000)) return e.cv;
      const A = CO.art;
      if (A && typeof A.sprite === 'function') {
        let sp = null; try { sp = A.sprite(ART[sym], px); } catch (err) { sp = null; }
        if (sp) { cache.set(key, { cv: sp, art: true, t: now }); return sp; }
      }
      const c2 = (e && !e.art && e.cv) || document.createElement('canvas');
      c2.width = px; c2.height = px;
      const g = c2.getContext('2d');
      g.setTransform(1, 0, 0, 1, 0, 0); g.clearRect(0, 0, px, px);
      let art = false;
      if (artDraw(g, ART[sym], px / 2, px / 2, px)) art = true;
      else { g.translate(px / 2, px / 2); FB[sym](g, px); }
      cache.set(key, { cv: c2, art, t: now });
      return c2;
    }
    function drawSym(c, sym, x, y, size, blur) {
      if (sym === 'cookie') {
        if (blur > 0.05) {
          c.globalAlpha = 0.3; api.drawCookie(c, x, y - blur * size * 0.3, size * 0.38, { simple: true }); api.drawCookie(c, x, y + blur * size * 0.3, size * 0.38, { simple: true });
          c.globalAlpha = 1;
        }
        api.drawCookie(c, x, y, size * 0.38, { simple: true, rot: 0 });
        return;
      }
      const px = Math.max(16, Math.round(size * DPR));
      const sp = symSprite(sym, px);
      if (blur > 0.05) {
        const st = 1 + blur * 0.35;
        c.globalAlpha = 0.28; c.drawImage(sp, x - size / 2, y - size * st / 2 - blur * size * 0.32, size, size * st);
        c.drawImage(sp, x - size / 2, y - size * st / 2 + blur * size * 0.32, size, size * st);
        c.globalAlpha = 0.9; c.drawImage(sp, x - size / 2, y - size * st / 2, size, size * st);
        c.globalAlpha = 1;
      } else c.drawImage(sp, x - size / 2, y - size / 2, size, size);
    }

    /* ── own audio (anticipation riser, sad trombone, fanfare) ── */
    function audio() { try { return api.audio(); } catch (e) { return null; } }
    function reg(src, chain) { live.set(src, chain); src.onended = () => { live.delete(src); chain.forEach((n) => { try { n.disconnect(); } catch (e) { /* */ } }); }; }
    function voice(type, f0, f1, t, dur, vol, a) {
      const o = a.ctx.createOscillator(), g = a.ctx.createGain(), f = a.ctx.createBiquadFilter();
      o.type = type; o.frequency.setValueAtTime(f0, t); if (f1) o.frequency.exponentialRampToValueAtTime(f1, t + dur);
      f.type = 'lowpass'; f.frequency.value = 2400;
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + 0.015); g.gain.setValueAtTime(vol, t + dur * 0.8); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
      o.connect(f); f.connect(g); g.connect(a.out); o.start(t); o.stop(t + dur + 0.02); reg(o, [o, f, g]);
      return o;
    }
    function startRiser(dur) {
      const a = audio(); if (!a) return null;
      const t = a.ctx.currentTime;
      const o = a.ctx.createOscillator(), g = a.ctx.createGain(), lfo = a.ctx.createOscillator(), lg = a.ctx.createGain();
      o.type = 'triangle'; o.frequency.setValueAtTime(260, t); o.frequency.exponentialRampToValueAtTime(1100, t + dur);
      lfo.frequency.value = 9; lg.gain.value = 0.05; lfo.connect(lg); lg.connect(g.gain);
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.09, t + dur * 0.9);
      o.connect(g); g.connect(a.out); o.start(t); lfo.start(t); o.stop(t + dur + 0.3); lfo.stop(t + dur + 0.3);
      reg(o, [o, g]); reg(lfo, [lfo, lg]);
      return () => { try { const n = a.ctx.currentTime; g.gain.cancelScheduledValues(n); g.gain.setValueAtTime(0.06, n); g.gain.exponentialRampToValueAtTime(0.001, n + 0.08); o.stop(n + 0.1); lfo.stop(n + 0.1); } catch (e) { /* */ } };
    }
    function sadTrombone() {
      const a = audio(); if (!a) return;
      const t = a.ctx.currentTime + 0.05;
      [[293.7, 0.32], [277.2, 0.32], [261.6, 0.32]].forEach(([f, d], i) => voice('sawtooth', f, f * 0.985, t + i * 0.34, d, 0.12, a));
      const o = voice('sawtooth', 246.9, 233, t + 1.02, 1.1, 0.13, a);
      const lfo = a.ctx.createOscillator(), lg = a.ctx.createGain();
      lfo.frequency.value = 6; lg.gain.value = 5; lfo.connect(lg); lg.connect(o.frequency);
      lfo.start(t + 1.1); lfo.stop(t + 2.15); reg(lfo, [lfo, lg]);
    }
    function fanfare() {
      const a = audio(); if (!a) return;
      const t = a.ctx.currentTime + 0.02;
      [523, 659, 784, 1047, 784, 1047, 1319, 1568].forEach((f, i) => voice('square', f, 0, t + i * 0.085, i === 7 ? 0.6 : 0.12, 0.07, a));
    }
    function killAudio() {
      live.forEach((chain, src) => { src.onended = null; try { src.stop(0); } catch (e) { /* */ } chain.forEach((n) => { try { n.disconnect(); } catch (e) { /* */ } }); });
      live.clear(); riserStop = null;
    }

    /* ── layout ── */
    function resize() {
      const r = root.getBoundingClientRect();
      W = Math.max(240, r.width || root.clientWidth || 320); H = Math.max(300, r.height || root.clientHeight || 480);
      DPR = Math.min(2, window.devicePixelRatio || 1);
      cv.width = Math.round(W * DPR); cv.height = Math.round(H * DPR);
      wrap.classList.toggle('cos-short', H < 520 && W > H);
      const topH = top.offsetHeight + 4, botH = bottom.offsetHeight + 4;
      const areaT = topH, areaH = Math.max(160, H - botH - topH);
      M.lever = W >= 520;
      const maxW = Math.min(W - 16 - (M.lever ? 90 : 0), 600);
      const cs = clamp(Math.min(maxW / 3.5, (areaH - 18) / 3.62), 40, 150);
      M.cs = cs; M.pad = cs * 0.15; M.gap = cs * 0.1;
      M.headH = cs * 0.66; M.winH = cs * 1.95; M.meterH = cs * 0.5;
      M.w = cs * 3 + M.gap * 2 + M.pad * 2;
      M.h = M.pad * 2 + M.headH + M.pad * 0.6 + M.winH + M.pad * 0.6 + M.meterH;
      M.x = (W - M.w) / 2 - (M.lever ? 26 : 0);
      M.y = areaT + (areaH - M.h) / 2;
      M.reelY = M.y + M.pad + M.headH + M.pad * 0.6;
      M.meterY = M.reelY + M.winH + M.pad * 0.6;
      M.lx = M.x + M.w + cs * 0.26; M.ly = M.reelY + M.winH * 0.55;
      // bulbs around the frame
      M.bulbs = [];
      const inset = cs * 0.075, x0 = M.x + inset, y0 = M.y + inset, x1 = M.x + M.w - inset, y1 = M.y + M.h - inset;
      const step = clamp(cs * 0.24, 14, 30);
      const edge = (ax, ay, bx, by) => { const L = Math.hypot(bx - ax, by - ay), n = Math.max(1, Math.round(L / step)); for (let i = 0; i < n; i++) M.bulbs.push([ax + (bx - ax) * (i / n), ay + (by - ay) * (i / n)]); };
      edge(x0, y0, x1, y0); edge(x1, y0, x1, y1); edge(x1, y1, x0, y1); edge(x0, y1, x0, y0);
      cache.clear();
    }
    const ro = new ResizeObserver(resize); ro.observe(root);
    resize();

    /* ── bank / bet ── */
    const bank = () => Math.max(0, Math.floor(api.cookies() || 0));
    function betFor(p) { const b = bank(); return p >= 1 ? b : Math.max(10, Math.floor(b * p)); }
    function refreshBet() {
      const b = bank();
      const bet = betFor(betPct);
      const ok = b >= 10 && bet <= b;
      betV.textContent = ok ? api.fmt(bet) : 'PAS ASSEZ';
      betLine.classList.toggle('no', !ok);
      betBtns.forEach((x) => x.classList.toggle('sel', +x.dataset.p === betPct));
      if (b !== lastBank) { if (lastBank >= 0 && b > lastBank) { bankEl.classList.add('up'); bankBumpT = performance.now(); } lastBank = b; bankV.textContent = api.fmt(b); }
      if (bankBumpT && performance.now() - bankBumpT > 140) { bankEl.classList.remove('up'); bankBumpT = 0; }
    }
    function setBet(p) { if (betPct === p) return; betPct = p; api.sfx('tick', { pitch: 0.9 + p * 0.6, vol: 0.6 }); refreshBet(); }
    betBtns.forEach((b) => b.addEventListener('click', () => setBet(+b.dataset.p)));
    freeBtn.addEventListener('click', () => spin(true));
    spinBtn.addEventListener('click', () => spin(false));
    refreshBet();

    function shakeDom(elm) { elm.classList.remove('cos-shake'); void elm.offsetWidth; elm.classList.add('cos-shake'); }
    function deny() {
      api.sfx('error', { vol: 0.8 });
      fx.deny = 1; if (canShake()) fx.shake = Math.max(fx.shake, 9);
      shakeDom(betLine); shakeDom(spinBtn);
      bigText('PAS ASSEZ DE COOKIES', '#ff4d6d', 1.4, 'deny', 'Va cliquer un peu et reviens');
    }
    const canShake = () => { const s = S(); return s.shake !== false && !s.reducedMotion; };
    const budget = () => { const s = S(); return [0.3, 0.6, 1][clamp(s.particles == null ? 2 : s.particles, 0, 2)] * (s.reducedMotion ? 0.45 : 1); };
    const maxParts = () => [100, 240, 520][clamp(S().particles == null ? 2 : S().particles, 0, 2)];

    /* ── spin ── */
    function spin(free) {
      const T = performance.now() / 1000;
      if (!alive || spinning || T < lockUntil) return;
      let bet;
      if (free) {
        if (freeLeft <= 0) return;
        freeLeft = 0; freeBtn.remove();
        bet = Math.max(50, Math.floor(bank() * 0.05));
      } else {
        bet = betFor(betPct);
        if (bank() < 10 || bet < 10 || !api.spend(bet)) { deny(); return; }
      }
      curBet = bet; curFree = free; spinning = true; resolved = false; spins++;
      result = forced || pickOutcome(); forced = null;
      outcome = evaluate(result);
      anticip = false; anticipT = 0;
      reels.forEach((r, i) => {
        r.state = 'spin'; r.v = -3; r.stopAt = T + 0.55 + i * 0.3; r.target = result[i];
      });
      if (result[0] === result[1]) reels[2].stopAt += 0.95;
      leverT = T;
      meter = { from: 0, to: 0, t0: T, dur: 1, label: free ? 'TOUR GRATUIT !' : 'ÇA TOURNE…', kind: 'spin', lastTick: 0 };
      fx.big = null; fx.hitGlow = 0; fx.droop = 0;
      api.sfx('spin', { vol: 0.8 });
      api.sfx('whoosh', { vol: 0.5 });
      refreshBet();
    }

    function reelStopped(i, T) {
      const r = reels[i];
      api.sfx('reel', { pitch: 1 + i * 0.12, vol: 0.9 });
      fx.bounce = Math.max(fx.bounce, 1);
      if (canShake()) fx.shake = Math.max(fx.shake, 2.5);
      const x = reelX(i) + M.cs / 2;
      sparks(x, M.reelY + M.winH / 2, 8, '#fff');
      r.land = 1;
      if (i === 1 && result[0] === result[1]) {
        anticip = true; anticipT = T; tickT = T;
        riserStop = startRiser(1.6);
        if (result[0] === 'broc') bigText('OH NON…', '#7dff6a', 1.3, 'small', 'pas le brocoli…');
        else if (result[0] === 'seven') bigText('77…', 'rgb', 1.3, 'small', 'LE JACKPOT EST LÀ');
        else bigText('ÇA SENT BON…', '#ffc93c', 1.3, 'small');
      }
      if (i === 2) { anticip = false; if (riserStop) { riserStop(); riserStop = null; } resolve(T); }
    }

    function resolve(T) {
      if (resolved) return;
      resolved = true; spinning = false;
      const o = outcome;
      const win = Math.round(curBet * o.mult);
      if (win > 0 || o.gems > 0) api.grant({ cookies: win, gems: o.gems });
      if (o.mult > bestMult) bestMult = o.mult;
      streak = o.mult > 0 ? Math.max(1, streak + 1) : Math.min(-1, streak - 1);
      pushHistory(o);
      const dur = { jackpot: 3, cookie3: 2, gem3: 1.6, triple: 1.2, pair: 0.6 }[o.kind] || 0.5;
      meter = { from: 0, to: win, t0: T, dur, label: win > 0 ? 'GAIN' : o.kind === 'broc3' ? 'BROCOLI' : 'PERDU', kind: o.kind, lastTick: 0, gems: o.gems };
      fx.hitGlow = o.hit.length ? 1 : 0;
      const b = budget();
      switch (o.kind) {
        case 'jackpot':
          lockUntil = T + 2.2;
          api.sfx('jackpot', { vol: 1 }); fanfare();
          bigText('JACKPOT', 'rgb', 4, 'jackpot', `×25  ·  +${api.fmt(win)}`);
          fx.rays = 4.5; fx.raysCol = 'rgb'; fx.hero = 4; fx.fountain = 2.8; fx.fountainKind = 'coin';
          flash(0.9, '#fff'); if (canShake()) fx.shake = 16;
          shockwave(3); confetti(160 * b);
          break;
        case 'cookie3':
          lockUntil = T + 1.4;
          api.sfx('win', { vol: 1 }); api.sfx('levelup', { vol: 0.7 });
          bigText('MEGA CRUNCH', '#ff2bd6', 2.6, 'win', `×10  ·  +${api.fmt(win)}`);
          fx.rays = 2.6; fx.raysCol = '#ff2bd6'; fx.hero = 2.6; fx.fountain = 1.6; fx.fountainKind = 'cookie';
          flash(0.5, '#ff9aea'); if (canShake()) fx.shake = 10; shockwave(2);
          break;
        case 'gem3':
          lockUntil = T + 1.2;
          api.sfx('win', { vol: 1 }); api.sfx('achievement', { vol: 0.6 });
          bigText('DIAMOND HANDS', '#1ff4ff', 2.4, 'win', `×5  ·  +${o.gems} GEMMES`);
          fx.rays = 2; fx.raysCol = '#1ff4ff'; fx.fountain = 1.4; fx.fountainKind = 'gem';
          flash(0.4, '#bffcff'); if (canShake()) fx.shake = 8; shockwave(1);
          break;
        case 'triple':
          lockUntil = T + 0.9;
          api.sfx('win', { vol: 0.9 });
          bigText('BIG W', '#b6ff3b', 1.8, 'win', `×4  ·  +${api.fmt(win)}`);
          fx.fountain = 1; fx.fountainKind = 'coin'; if (canShake()) fx.shake = 6; shockwave(1);
          break;
        case 'pair':
          lockUntil = T + 0.25;
          api.sfx('coin', { vol: 0.8 });
          bigText(['PAS MAL', 'W', 'NICE', 'PETIT W'][Math.floor(Math.random() * 4)], '#fff', 1.1, 'small', `×1,5  ·  +${api.fmt(win)}`);
          coins(10 * b, M.x + M.w / 2, M.meterY, 0.6);
          break;
        case 'broc3':
          lockUntil = T + 1.8;
          api.sfx('lose', { vol: 0.9 }); sadTrombone();
          bigText('SKILL ISSUE', '#7dff6a', 3, 'fail', 'trois brocolis. aucune aura.');
          fx.tint = 1; fx.tintCol = '#2bdc6a'; fx.droop = 1; fx.fountain = 0;
          brocRain(46 * b);
          break;
        default:
          lockUntil = T + 0.2;
          api.sfx('lose', { vol: 0.4 });
          bigText(['RATIO', 'L', 'PRESQUE…', 'TKT, LA PROCHAINE', 'AÏE', 'ÇA PIQUE'][Math.floor(Math.random() * 6)], '#b3a6dd', 1, 'small');
      }
      refreshBet();
    }

    function pushHistory(o) {
      const cls = { jackpot: 'j', cookie3: 'c', gem3: 'g', triple: 't', pair: 'w', broc3: 'x', lose: 'l' }[o.kind];
      const txt = o.kind === 'lose' ? 'L' : o.kind === 'broc3' ? 'BROCO' : `×${String(o.mult).replace('.', ',')}`;
      const chip = el('span', 'cos-chip ' + cls, o.kind === 'gem3' ? `${txt} ${ico('ui:gem', 'gem')}` : txt);
      hydrateArt(chip);
      histEl.insertBefore(chip, histEl.firstChild);
      while (histEl.children.length > 7) histEl.lastChild.remove();
    }

    /* ── FX helpers ── */
    function bigText(text, col, dur, style, sub) { fx.big = { text, col, t0: performance.now() / 1000, dur, style, sub: sub || '' }; }
    function flash(a, col) { if (S().reducedMotion) return; fx.flash = Math.max(fx.flash, a); fx.flashCol = col; }
    function shockwave(n) { for (let i = 0; i < n; i++) rings.push({ x: M.x + M.w / 2, y: M.reelY + M.winH / 2, age: -i * 0.12, life: 0.9, max: Math.max(W, H) * 0.8, h: i * 90 }); }
    function sparks(x, y, n, col) {
      n = Math.round(n * budget()); const lim = maxParts();
      for (let i = 0; i < n && parts.length < lim; i++) { const a = rand(0, TAU), sp = rand(120, 380); parts.push({ k: 'spark', x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, g: 200, life: rand(0.2, 0.45), age: 0, sz: rand(1.5, 3), col }); }
    }
    function coins(n, x, y, power, kind) {
      n = Math.round(n); const lim = maxParts();
      for (let i = 0; i < n && parts.length < lim; i++) {
        parts.push({ k: kind || 'coin', x: x + rand(-M.cs * 0.6, M.cs * 0.6), y, vx: rand(-260, 260) * power, vy: rand(-900, -480) * power, g: 1500, life: rand(1.2, 2.2), age: 0, sz: rand(0.09, 0.14) * M.cs, spin: rand(0, TAU), vs: rand(6, 14), col: '#ffc93c' });
      }
    }
    function confetti(n) {
      n = Math.round(n); const lim = maxParts();
      for (let i = 0; i < n && parts.length < lim; i++) parts.push({ k: 'conf', x: rand(0, W), y: rand(-80, -10), vx: rand(-60, 60), vy: rand(60, 240), g: 90, life: rand(2.2, 3.6), age: 0, sz: rand(4, 9), spin: rand(0, TAU), vs: rand(-8, 8), col: hsl(rand(0, 360), 100, 62) });
    }
    function brocRain(n) {
      n = Math.round(n); const lim = maxParts();
      for (let i = 0; i < n && parts.length < lim; i++) parts.push({ k: 'broc', x: rand(0, W), y: rand(-H * 0.6, -20), vx: rand(-30, 30), vy: rand(120, 300), g: 380, life: rand(2, 3.2), age: 0, sz: rand(0.28, 0.5) * M.cs, spin: rand(0, TAU), vs: rand(-3, 3) });
    }

    /* ── input ── */
    const reelX = (i) => M.x + M.pad + i * (M.cs + M.gap);
    function onPointerDown(e) {
      const r = cv.getBoundingClientRect(); const x = e.clientX - r.left, y = e.clientY - r.top;
      const onMachine = x >= M.x && x <= M.x + M.w && y >= M.y && y <= M.y + M.h;
      const onLever = M.lever && Math.abs(x - M.lx) < M.cs * 0.4 && y > M.ly - M.cs * 1.4 && y < M.ly + M.cs * 0.4;
      if (onMachine || onLever) { e.preventDefault(); spin(false); }
    }
    function onKey(e) {
      if (e.ctrlKey || e.metaKey || e.altKey) return;
      if (e.code === 'Space' || e.code === 'Enter' || e.code === 'NumpadEnter') { e.preventDefault(); if (!e.repeat) spin(false); return; }
      const k = { Digit1: 0.1, Digit2: 0.25, Digit3: 0.5, Digit4: 1, Numpad1: 0.1, Numpad2: 0.25, Numpad3: 0.5, Numpad4: 1 }[e.code];
      if (k) { e.preventDefault(); setBet(k); }
    }
    function onKeyUp(e) { if (e.code === 'Space') e.preventDefault(); }
    cv.addEventListener('pointerdown', onPointerDown);
    cv.addEventListener('contextmenu', (e) => e.preventDefault());
    window.addEventListener('keydown', onKey);
    window.addEventListener('keyup', onKeyUp);

    /* ── update ── */
    const VMAX = 21;
    function update(dt, T) {
      const rm = !!S().reducedMotion;
      wrap.classList.toggle('cos-rm', rm);
      reels.forEach((r, i) => {
        r.land = Math.max(0, r.land - dt * 3);
        if (r.state === 'spin') {
          let vmax = VMAX;
          if (i === 2 && anticip) vmax = 9 + Math.sin((T - anticipT) * 7) * 1.5;
          r.v = r.v < vmax ? Math.min(vmax, r.v + 70 * dt) : Math.max(vmax, r.v - 25 * dt);
          r.off += r.v * dt;
          if (T >= r.stopAt && r.v > 4) {
            r.F = Math.floor(r.off) + 4;
            r.strip[((r.F % 64) + 64) % 64] = r.target;
            r.from = r.off; r.t0 = T;
            r.dur = clamp(((r.F - r.off) * 3.4) / r.v, 0.3, 0.95);
            r.state = 'stop';
          }
        } else if (r.state === 'stop') {
          const u = (T - r.t0) / r.dur;
          if (u >= 1) { r.off = r.F; r.state = 'idle'; r.v = 0; reelStopped(i, T); }
          else r.off = r.from + (r.F - r.from) * easeOutBack(u, 1.25);
        }
      });
      if (anticip && T - tickT > 0.11) { tickT = T; api.sfx('tick', { pitch: 1 + (T - anticipT) * 0.5, vol: 0.5 }); }
      // lever
      const lt = T - leverT;
      leverPull = lt < 0 ? 0 : lt < 0.14 ? lt / 0.14 : lt < 0.55 ? 1 - easeOut3((lt - 0.14) / 0.41) : 0;
      // win meter count-up ticks
      if (meter.to > 0) {
        const k = clamp((T - meter.t0) / meter.dur, 0, 1);
        if (k < 1 && T - meter.lastTick > 0.075) { meter.lastTick = T; api.sfx('coin', { pitch: 0.9 + k * 0.7, vol: 0.35 }); }
      }
      // fountains
      if (fx.fountain > 0) {
        fx.fountain -= dt;
        const b = budget();
        const n = (fx.fountainKind === 'coin' ? 60 : 36) * b * dt * (outcome && outcome.kind === 'jackpot' ? 2.2 : 1);
        const cnt = Math.floor(n) + (Math.random() < n % 1 ? 1 : 0);
        coins(cnt, M.x + M.w / 2, M.meterY + M.meterH * 0.5, 1, fx.fountainKind);
        if (outcome && outcome.kind === 'jackpot' && Math.random() < dt * 4) confetti(12 * b);
      }
      fx.rays = Math.max(0, fx.rays - dt); fx.hero = Math.max(0, fx.hero - dt);
      fx.tint = Math.max(0, fx.tint - dt * 0.45); fx.flash = Math.max(0, fx.flash - dt * 2.2);
      fx.shake = Math.max(0, fx.shake - dt * 28); fx.bounce = Math.max(0, fx.bounce - dt * 5);
      fx.hitGlow = Math.max(0, fx.hitGlow - dt * 0.25); fx.deny = Math.max(0, fx.deny - dt * 2);
      if (fx.droop > 0) fx.droop = Math.max(0, fx.droop - dt * 0.4);
      if (fx.big && T - fx.big.t0 > fx.big.dur) fx.big = null;
      for (let i = parts.length - 1; i >= 0; i--) {
        const p = parts[i]; p.age += dt;
        if (p.age >= p.life || p.y > H + 80) { parts.splice(i, 1); continue; }
        p.vy += p.g * dt; p.x += p.vx * dt; p.y += p.vy * dt; if (p.spin !== undefined) p.spin += p.vs * dt;
      }
      for (let i = rings.length - 1; i >= 0; i--) { rings[i].age += dt; if (rings[i].age > rings[i].life) rings.splice(i, 1); }
    }

    /* ── render ── */
    function drawBg(T, rm) {
      const g = ctx.createLinearGradient(0, 0, 0, H);
      g.addColorStop(0, '#12062e'); g.addColorStop(0.6, '#1d0840'); g.addColorStop(1, '#0a0418');
      ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      const cx = M.x + M.w / 2, cy = M.reelY + M.winH / 2;
      // slow rotating light rays
      const rays = 14, rot = rm ? 0 : T * 0.12;
      ctx.save(); ctx.translate(cx, cy); ctx.rotate(rot);
      for (let i = 0; i < rays; i++) {
        ctx.fillStyle = i % 2 ? hsl(api.hue(i * 25), 90, 55, 0.05) : 'rgba(255,255,255,.025)';
        ctx.beginPath(); ctx.moveTo(0, 0); ctx.arc(0, 0, Math.max(W, H) * 1.2, (i / rays) * TAU, ((i + 0.5) / rays) * TAU); ctx.closePath(); ctx.fill();
      }
      ctx.restore();
      const rg = ctx.createRadialGradient(cx, cy, M.cs * 0.5, cx, cy, Math.max(W, H) * 0.7);
      rg.addColorStop(0, hsl(api.hue(0), 90, 55, 0.35)); rg.addColorStop(0.5, hsl(api.hue(60), 90, 40, 0.12)); rg.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = rg; ctx.fillRect(0, 0, W, H);
      // twinkles
      for (let i = 0; i < 26; i++) {
        const x = ((i * 137.5) % 100) / 100 * W, y = ((i * 71.3) % 100) / 100 * H;
        const a = 0.25 + 0.25 * Math.sin(T * 2 + i * 1.7);
        ctx.fillStyle = `rgba(255,255,255,${a})`; ctx.fillRect(x, y, 2, 2);
      }
      // big win rays
      if (fx.rays > 0) {
        const a = Math.min(1, fx.rays / 0.6);
        ctx.save(); ctx.translate(cx, cy); ctx.rotate(rm ? 0 : T * 0.9);
        ctx.globalCompositeOperation = 'lighter';
        for (let i = 0; i < 18; i++) {
          ctx.fillStyle = fx.raysCol === 'rgb' ? hsl((i * 20 + api.hue(0)) % 360, 100, 60, 0.22 * a) : hexA(fx.raysCol, (i % 2 ? 0.1 : 0.2) * a);
          ctx.beginPath(); ctx.moveTo(0, 0); ctx.arc(0, 0, Math.max(W, H), (i / 18) * TAU, ((i + 0.45) / 18) * TAU); ctx.closePath(); ctx.fill();
        }
        ctx.restore();
      }
    }
    function hexA(hex, a) { const n = parseInt(hex.slice(1), 16); return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`; }

    function drawMachine(T, rm) {
      const { x, y, w, h, cs } = M;
      // body
      ctx.save();
      rr(ctx, x - 4, y + 6, w + 8, h + 4, cs * 0.26); ctx.fillStyle = 'rgba(0,0,0,.45)'; ctx.fill();
      rr(ctx, x, y, w, h, cs * 0.24);
      const bg = ctx.createLinearGradient(0, y, 0, y + h);
      bg.addColorStop(0, '#6a1fb8'); bg.addColorStop(0.45, '#3a0f78'); bg.addColorStop(1, '#1e0746');
      ctx.fillStyle = bg; ctx.fill();
      ctx.lineWidth = 5; ctx.strokeStyle = INK; ctx.stroke();
      rr(ctx, x + 5, y + 5, w - 10, h - 10, cs * 0.2);
      ctx.lineWidth = 3; ctx.strokeStyle = fx.tint > 0.3 ? '#2bdc6a' : '#ffc93c'; ctx.stroke();
      // bulbs
      const bn = M.bulbs.length, br = clamp(cs * 0.045, 3, 6.5);
      const k = outcome && !spinning ? outcome.kind : 'idle';
      const winning = !spinning && T - (meter.t0 || 0) < (meter.dur || 0) + 1.2 && k !== 'lose' && k !== 'idle';
      for (let i = 0; i < bn; i++) {
        const [bx, by] = M.bulbs[i];
        let on, col;
        if (k === 'broc3' && winning) { on = Math.floor(T * 2) % 2 === 0; col = '#2bdc6a'; }
        else if (k === 'jackpot' && winning) { on = true; col = hsl((api.hue(0) + i * 12 + T * 400) % 360, 100, 62); }
        else if (winning) { on = Math.floor(T * 9) % 2 === (i % 2); col = hsl(api.hue(i * 10), 100, 64); }
        else if (spinning) { on = (i + Math.floor(T * 22)) % 3 === 0; col = hsl(api.hue(i * 14), 100, 64); }
        else { on = rm ? i % 3 === 0 : (i + Math.floor(T * 7)) % 4 === 0; col = hsl(api.hue(i * 14), 100, 64); }
        if (on) {
          ctx.fillStyle = col; ctx.globalAlpha = 0.28;
          ctx.beginPath(); ctx.arc(bx, by, br * 2.3, 0, TAU); ctx.fill(); ctx.globalAlpha = 1;
        }
        ctx.beginPath(); ctx.arc(bx, by, br, 0, TAU);
        ctx.fillStyle = on ? '#fff' : '#3b2466'; ctx.fill();
        if (on) { ctx.lineWidth = br * 0.55; ctx.strokeStyle = col; ctx.stroke(); }
      }
      // header / marquee
      const hx = x + M.pad, hy = y + M.pad, hw = w - M.pad * 2, hh = M.headH;
      rr(ctx, hx, hy, hw, hh, cs * 0.14); ctx.fillStyle = 'rgba(10,3,28,.85)'; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = INK; ctx.stroke();
      const ts = Math.round(Math.min(hh * 0.5, hw / 8.2));
      const title = 'CASINO CRUMBLE';
      otext(ctx, title, x + w / 2, hy + hh * 0.38, ts, rainbow(ctx, hx, hx + hw, api.hue(0) + (rm ? 0 : T * 60)), 'center', 0.2);
      // streak line
      let st = 'MISE TES COOKIES, NO CAP', sc = '#b3a6dd';
      if (streak >= 5) { st = `${streak} W D'AFFILÉE — T'ES EN FEU`; sc = '#ffc93c'; }
      else if (streak >= 2) { st = `SÉRIE DE ${streak} W`; sc = '#b6ff3b'; }
      else if (streak <= -6) { st = 'LE CASINO GAGNE TOUJOURS (NO CAP)'; sc = '#ff4d6d'; }
      else if (streak <= -3) { st = `${-streak} L D'AFFILÉE… ÇA VA TOURNER`; sc = '#ff8095'; }
      if (freeLeft > 0 && spins === 0) { st = 'UN TOUR GRATUIT T\'ATTEND'; sc = '#ffc93c'; }
      ctx.font = `700 ${Math.round(clamp(hh * 0.2, 9, 14))}px ${FM}`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillStyle = sc; ctx.fillText(st, x + w / 2, hy + hh * 0.8, hw - 10);
      ctx.restore();
    }

    function drawReels(T, rm) {
      const { cs, winH, reelY } = M;
      const mid = reelY + winH / 2;
      for (let i = 0; i < 3; i++) {
        const r = reels[i], rx = reelX(i);
        ctx.save();
        rr(ctx, rx, reelY, cs, winH, cs * 0.14);
        const g = ctx.createLinearGradient(0, reelY, 0, reelY + winH);
        g.addColorStop(0, '#f3e9ff'); g.addColorStop(0.5, '#ffffff'); g.addColorStop(1, '#e2d4ff');
        ctx.fillStyle = g; ctx.fill();
        ctx.clip();
        const blur = r.state === 'spin' ? clamp(Math.abs(r.v) / VMAX, 0, 1) : r.state === 'stop' ? clamp(1 - (T - r.t0) / r.dur, 0, 1) * 0.6 : 0;
        const base = Math.floor(r.off);
        for (let k = -2; k <= 2; k++) {
          const idx = base + k;
          const yy = mid + (r.off - idx) * cs;
          if (yy < reelY - cs || yy > reelY + winH + cs) continue;
          const sym = symAt(r, idx);
          const isRes = !spinning && r.state === 'idle' && idx === Math.round(r.off);
          let sz = cs * 0.8;
          if (isRes && outcome && outcome.hit.includes(i) && fx.hitGlow > 0 && !rm) sz *= 1 + Math.sin(T * 12) * 0.06 * fx.hitGlow;
          if (isRes && r.land > 0) sz *= 1 + r.land * 0.12;
          drawSym(ctx, sym, rx + cs / 2, yy, sz, blur);
        }
        // cylinder shading
        const sh = ctx.createLinearGradient(0, reelY, 0, reelY + winH);
        sh.addColorStop(0, 'rgba(30,8,70,.78)'); sh.addColorStop(0.24, 'rgba(30,8,70,0)'); sh.addColorStop(0.76, 'rgba(30,8,70,0)'); sh.addColorStop(1, 'rgba(30,8,70,.78)');
        ctx.fillStyle = sh; ctx.fillRect(rx, reelY, cs, winH);
        // glass shine sweep
        if (!rm) {
          const sw = ((T * 0.35 + i * 0.12) % 1.6) - 0.3;
          const sx = rx + sw * cs * 1.6;
          const gl = ctx.createLinearGradient(sx - cs * 0.3, 0, sx + cs * 0.3, 0);
          gl.addColorStop(0, 'rgba(255,255,255,0)'); gl.addColorStop(0.5, 'rgba(255,255,255,.35)'); gl.addColorStop(1, 'rgba(255,255,255,0)');
          ctx.fillStyle = gl; ctx.fillRect(rx, reelY, cs, winH);
        }
        ctx.restore();
        // frame
        rr(ctx, rx, reelY, cs, winH, cs * 0.14);
        ctx.lineWidth = 4; ctx.strokeStyle = INK; ctx.stroke();
        // anticipation glow on reel 3
        if (i === 2 && anticip) {
          const a = 0.6 + Math.sin(T * 18) * 0.4;
          ctx.lineWidth = 6; ctx.strokeStyle = hsl(api.hue(0) + T * 300, 100, 60, a); ctx.stroke();
        }
        // winning highlight
        if (!spinning && outcome && outcome.hit.includes(i) && fx.hitGlow > 0) {
          const col = outcome.kind === 'broc3' ? '#2bdc6a' : outcome.kind === 'jackpot' ? hsl(api.hue(i * 40) + T * 200, 100, 60) : '#ffc93c';
          ctx.save(); ctx.globalAlpha = Math.min(1, fx.hitGlow * 1.5);
          rr(ctx, rx + 3, mid - cs * 0.5, cs - 6, cs, cs * 0.12);
          ctx.lineWidth = 5; ctx.strokeStyle = col; ctx.stroke();
          ctx.restore();
        }
      }
      // payline
      const px0 = M.x + M.pad * 0.35, px1 = M.x + M.w - M.pad * 0.35;
      ctx.save();
      ctx.globalAlpha = 0.9;
      ctx.strokeStyle = !spinning && outcome && outcome.mult > 0 && fx.hitGlow > 0 ? rainbow(ctx, px0, px1, api.hue(0) + T * 200) : 'rgba(255,43,214,.75)';
      ctx.lineWidth = 3; ctx.setLineDash([8, 6]);
      ctx.beginPath(); ctx.moveTo(px0 + 10, mid); ctx.lineTo(px1 - 10, mid); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#ff2bd6'; ctx.strokeStyle = INK; ctx.lineWidth = 2.5;
      for (const [sx, d] of [[px0, 1], [px1, -1]]) {
        ctx.beginPath(); ctx.moveTo(sx, mid - 9); ctx.lineTo(sx + 12 * d, mid); ctx.lineTo(sx, mid + 9); ctx.closePath(); ctx.stroke(); ctx.fill();
      }
      ctx.restore();
    }

    function drawMeter(T) {
      const { cs } = M;
      const x = M.x + M.pad, w = M.w - M.pad * 2, y = M.meterY, h = M.meterH;
      rr(ctx, x, y, w, h, h * 0.35);
      ctx.fillStyle = '#07021a'; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = INK; ctx.stroke();
      rr(ctx, x + 3, y + 3, w - 6, h - 6, h * 0.3); ctx.lineWidth = 1.5; ctx.strokeStyle = 'rgba(255,201,60,.35)'; ctx.stroke();
      const ls = Math.round(clamp(h * 0.3, 9, 14));
      ctx.font = `700 ${ls}px ${FM}`; ctx.textAlign = 'left'; ctx.textBaseline = 'middle';
      ctx.fillStyle = meter.kind === 'broc3' ? '#7dff6a' : meter.kind === 'lose' ? '#ff8095' : '#b3a6dd';
      if (cs >= 72) ctx.fillText(meter.label, x + h * 0.4, y + h / 2 + 1);
      const k = clamp((T - meter.t0) / meter.dur, 0, 1);
      const vs = Math.round(clamp(h * 0.56, 14, 30));
      let txt, col = '#fff';
      if (meter.kind === 'idle') { txt = coarse ? 'TAPE SPIN' : 'ESPACE / LEVIER'; col = '#6a5ca0'; }
      else if (meter.kind === 'spin') { txt = '· · ·'.slice(0, 1 + Math.floor(T * 6) % 5); col = '#6a5ca0'; }
      else if (meter.to > 0) { txt = '+' + api.fmt(Math.round(meter.to * easeOut3(k))); col = meter.kind === 'jackpot' ? rainbow(ctx, x + w * 0.4, x + w, api.hue(0) + T * 200) : '#ffc93c'; }
      else txt = meter.kind === 'broc3' ? 'SKILL ISSUE' : '0';
      const iconS = vs * 1.05;
      const hasIcon = meter.to > 0;
      const tx = x + w - h * 0.4 - (hasIcon ? iconS + 4 : 0);
      otext(ctx, txt, tx, y + h / 2 + 1, vs, col, 'right', 0.18);
      if (hasIcon) {
        const ix = x + w - h * 0.4 - iconS / 2, iy = y + h / 2;
        if (!artDraw(ctx, 'ui:cookie', ix, iy, iconS)) api.drawCookie(ctx, ix, iy, iconS * 0.42, { simple: true });
      }
    }

    function drawLever(T) {
      if (!M.lever) return;
      const { cs } = M;
      const bx = M.lx, by = M.ly;
      // base
      rr(ctx, bx - cs * 0.2, by - cs * 0.24, cs * 0.28, cs * 0.48, cs * 0.08);
      ctx.fillStyle = '#2a1060'; ctx.fill(); ctx.lineWidth = 4; ctx.strokeStyle = INK; ctx.stroke();
      ctx.fillStyle = '#ffc93c'; ctx.fillRect(bx - cs * 0.2, by - cs * 0.04, cs * 0.28, cs * 0.08);
      // stick: angle from up (-π/2 + 0.15) to down (π/2 - 0.3)
      const a0 = -Math.PI / 2 + 0.12, a1 = Math.PI / 2 - 0.25;
      const ang = a0 + (a1 - a0) * leverPull;
      const L = cs * 1.15;
      const ex = bx + Math.cos(ang) * L * 0.55, ey = by + Math.sin(ang) * L;
      ctx.lineCap = 'round';
      ctx.strokeStyle = INK; ctx.lineWidth = cs * 0.11; ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(ex, ey); ctx.stroke();
      const sg = ctx.createLinearGradient(bx - 6, 0, bx + 6, 0); sg.addColorStop(0, '#9aa3c7'); sg.addColorStop(0.5, '#ffffff'); sg.addColorStop(1, '#8a92b8');
      ctx.strokeStyle = sg; ctx.lineWidth = cs * 0.06; ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(ex, ey); ctx.stroke();
      const br = cs * 0.15;
      const bg = ctx.createRadialGradient(ex - br * 0.35, ey - br * 0.35, br * 0.1, ex, ey, br);
      bg.addColorStop(0, '#ffb3c1'); bg.addColorStop(0.4, '#ff2b4a'); bg.addColorStop(1, '#a0001e');
      ctx.beginPath(); ctx.arc(ex, ey, br, 0, TAU); ctx.fillStyle = bg; ctx.fill(); ctx.lineWidth = 3.5; ctx.strokeStyle = INK; ctx.stroke();
      if (!spinning && performance.now() / 1000 > lockUntil && !S().reducedMotion) {
        ctx.globalAlpha = 0.35 + 0.35 * Math.sin(T * 5);
        ctx.beginPath(); ctx.arc(ex, ey, br * 1.5, 0, TAU); ctx.lineWidth = 3; ctx.strokeStyle = '#fff'; ctx.stroke();
        ctx.globalAlpha = 1;
      }
    }

    function drawParts() {
      for (const p of parts) {
        const a = Math.min(1, (1 - p.age / p.life) * 2.5);
        ctx.globalAlpha = a;
        if (p.k === 'coin') {
          const sx = Math.max(0.15, Math.abs(Math.cos(p.spin)));
          ctx.save(); ctx.translate(p.x, p.y); ctx.scale(sx, 1);
          ctx.beginPath(); ctx.arc(0, 0, p.sz, 0, TAU); ctx.fillStyle = '#b86e00'; ctx.fill();
          ctx.lineWidth = 2; ctx.strokeStyle = INK; ctx.stroke();
          ctx.beginPath(); ctx.arc(0, 0, p.sz * 0.78, 0, TAU); ctx.fillStyle = '#ffc93c'; ctx.fill();
          ctx.fillStyle = '#fff3b0'; ctx.fillRect(-p.sz * 0.12, -p.sz * 0.45, p.sz * 0.24, p.sz * 0.9);
          ctx.restore();
        } else if (p.k === 'cookie') {
          api.drawCookie(ctx, p.x, p.y, p.sz * 1.1, { simple: true, rot: p.spin });
        } else if (p.k === 'gem') {
          ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(Math.sin(p.spin) * 0.4);
          const s = p.sz * 2.4, sp = symSprite('gem', Math.max(16, Math.round(s * DPR)));
          ctx.drawImage(sp, -s / 2, -s / 2, s, s); ctx.restore();
        } else if (p.k === 'broc') {
          ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.spin);
          const s = p.sz, sp = symSprite('broc', Math.max(16, Math.round(s * DPR)));
          ctx.drawImage(sp, -s / 2, -s / 2, s, s); ctx.restore();
        } else if (p.k === 'conf') {
          ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.spin);
          ctx.fillStyle = p.col; ctx.fillRect(-p.sz / 2, -p.sz * 0.3, p.sz, p.sz * 0.6 * Math.abs(Math.cos(p.spin * 1.7)) + 1);
          ctx.restore();
        } else {
          ctx.strokeStyle = p.col; ctx.lineWidth = p.sz; ctx.lineCap = 'round';
          ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - p.vx * 0.03, p.y - p.vy * 0.03); ctx.stroke();
        }
      }
      ctx.globalAlpha = 1;
      for (const r of rings) {
        if (r.age < 0) continue;
        const k = r.age / r.life;
        ctx.globalAlpha = 1 - k; ctx.lineWidth = 14 * (1 - k) + 2;
        ctx.strokeStyle = hsl((api.hue(r.h) + k * 120) % 360, 100, 62);
        ctx.beginPath(); ctx.arc(r.x, r.y, r.max * easeOut3(k), 0, TAU); ctx.stroke();
      }
      ctx.globalAlpha = 1;
    }

    function drawHero(T) {
      if (fx.hero <= 0) return;
      const a = Math.min(1, fx.hero / 0.5), age = (outcome && outcome.kind === 'jackpot' ? 4 : 2.6) - fx.hero;
      const s = easeOutBack(clamp(age / 0.6, 0, 1), 1.6);
      const R = Math.min(W, H) * 0.2 * s;
      const cx = W / 2, cy = M.reelY + M.winH / 2 - R * 0.15;
      ctx.save(); ctx.globalAlpha = a;
      const gg = ctx.createRadialGradient(cx, cy, R * 0.5, cx, cy, R * 2);
      gg.addColorStop(0, hsl(api.hue(0), 100, 65, 0.6)); gg.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = gg; ctx.beginPath(); ctx.arc(cx, cy, R * 2, 0, TAU); ctx.fill();
      if (R > 2) api.drawCookie(ctx, cx, cy, R, { accessories: true, rot: S().reducedMotion ? 0 : Math.sin(T * 5) * 0.3, squash: Math.max(0, Math.sin(T * 10)) * 0.2 });
      ctx.restore();
    }

    function drawBig(T, rm) {
      const b = fx.big; if (!b) return;
      const age = T - b.t0, out = b.dur - age;
      const cx = W / 2;
      let cy = M.reelY + M.winH / 2;
      const pop = easeOutBack(clamp(age / 0.35, 0, 1), 2);
      const alpha = clamp(out / 0.35, 0, 1);
      ctx.save(); ctx.globalAlpha = alpha;
      if (b.style === 'jackpot') {
        const sz = Math.round(Math.min(W * 0.17, 120) * pop);
        ctx.font = `${sz}px ${FD}`;
        const letters = b.text.split('');
        const widths = letters.map((ch) => ctx.measureText(ch).width);
        const tw = widths.reduce((s, x) => s + x, 0);
        let x = cx - tw / 2;
        ctx.textAlign = 'left'; ctx.textBaseline = 'middle'; ctx.lineJoin = 'round';
        const ys = letters.map((_, i) => cy + (rm ? 0 : Math.sin(T * 9 + i * 0.7) * sz * 0.08));
        ctx.lineWidth = sz * 0.2; ctx.strokeStyle = INK;
        letters.forEach((ch, i) => { ctx.strokeText(ch, x, ys[i] + sz * 0.07); ctx.strokeText(ch, x, ys[i]); x += widths[i]; });
        x = cx - tw / 2;
        letters.forEach((ch, i) => { ctx.fillStyle = hsl((api.hue(i * 40) + T * 360) % 360, 100, 62); ctx.fillText(ch, x, ys[i]); x += widths[i]; });
        if (b.sub) otext(ctx, b.sub, cx, cy + sz * 0.75, Math.round(sz * 0.3), '#fff');
      } else if (b.style === 'fail') {
        const sz = Math.round(Math.min(W * 0.13, 92) * pop);
        ctx.translate(cx, cy); ctx.rotate(rm ? -0.06 : Math.sin(T * 7) * 0.12 - 0.05);
        otext(ctx, b.text, rm ? 0 : Math.sin(T * 23) * 3, 0, sz, b.col);
        if (b.sub) otext(ctx, b.sub, 0, sz * 0.72, Math.round(sz * 0.3), '#d8ffc8');
      } else if (b.style === 'small' || b.style === 'deny') {
        const sz = Math.round(Math.min(W * (b.style === 'deny' ? 0.075 : 0.1), b.style === 'deny' ? 40 : 60) * pop);
        const yy = b.style === 'deny' ? cy : M.reelY - sz * 0.1 - age * 12;
        otext(ctx, b.text, cx, yy, sz, b.col === 'rgb' ? rainbow(ctx, cx - sz * 2, cx + sz * 2, api.hue(0) + T * 300) : b.col);
        if (b.sub) otext(ctx, b.sub, cx, yy + sz * 0.78, Math.round(sz * 0.42), '#fff');
      } else {
        const sz = Math.round(Math.min(W * 0.13, 88) * pop);
        otext(ctx, b.text, cx, cy, sz, b.col === 'rgb' ? rainbow(ctx, cx - sz * 3, cx + sz * 3, api.hue(0) + T * 300) : b.col);
        if (b.sub) otext(ctx, b.sub, cx, cy + sz * 0.72, Math.round(sz * 0.32), '#fff');
      }
      ctx.restore();
    }

    function render(T) {
      const rm = !!S().reducedMotion;
      ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
      drawBg(T, rm);
      ctx.save();
      if (fx.shake > 0 && canShake()) ctx.translate(rand(-fx.shake, fx.shake), rand(-fx.shake, fx.shake));
      // machine transform: bounce on reel stop, droop on skill issue
      const pcx = M.x + M.w / 2, pcy = M.y + M.h;
      ctx.translate(pcx, pcy);
      if (!rm) ctx.translate(0, Math.sin(fx.bounce * Math.PI) * M.cs * 0.03);
      if (fx.droop > 0) { const d = Math.sin(Math.min(1, (1 - fx.droop) * 3) * Math.PI * 0.5); ctx.rotate(-0.07 * fx.droop * (rm ? 0.3 : 1 + Math.sin(T * 6) * 0.2 * d)); ctx.scale(1 + 0.04 * fx.droop, 1 - 0.06 * fx.droop); }
      ctx.translate(-pcx, -pcy);
      drawMachine(T, rm);
      drawReels(T, rm);
      drawMeter(T);
      drawLever(T);
      ctx.restore();
      drawHero(T);
      drawParts();
      drawBig(T, rm);
      if (fx.tint > 0) { ctx.globalAlpha = fx.tint * 0.28; ctx.fillStyle = fx.tintCol; ctx.fillRect(0, 0, W, H); ctx.globalAlpha = 1; }
      if (fx.flash > 0) { ctx.globalAlpha = fx.flash; ctx.fillStyle = fx.flashCol; ctx.fillRect(0, 0, W, H); ctx.globalAlpha = 1; }
    }

    /* ── loop ── */
    let raf = 0, last = performance.now(), domT = 0;
    function frame(now) {
      if (!alive) return;
      raf = requestAnimationFrame(frame);
      const dt = Math.min(0.05, Math.max(0, (now - last) / 1000)); last = now;
      const T = performance.now() / 1000;
      update(dt, T);
      render(T);
      if (T - domT > 0.2) { domT = T; refreshBet(); spinBtn.classList.toggle('off', spinning || T < lockUntil); }
    }
    raf = requestAnimationFrame(frame);

    return {
      force: (syms) => { forced = syms; }, // harness/testing only: next spin lands on these symbols
      debug: () => ({ spinning, spins, bestMult, streak, result, outcome, curBet, freeLeft, parts: parts.length, liveAudio: live.size }),
      destroy() {
        if (!alive) return;
        alive = false;
        cancelAnimationFrame(raf);
        // a spin still rolling is paid out instantly: closing never eats a win
        if (spinning && !resolved && outcome) {
          resolved = true; spinning = false;
          const win = Math.round(curBet * outcome.mult);
          if (win > 0 || outcome.gems > 0) api.grant({ cookies: win, gems: outcome.gems });
          if (outcome.mult > bestMult) bestMult = outcome.mult;
        }
        if (spins >= 3) { try { api.end({ score: bestMult, cookies: 0, gems: 0 }); } catch (e) { /* */ } }
        killAudio();
        ro.disconnect();
        window.removeEventListener('keydown', onKey);
        window.removeEventListener('keyup', onKeyUp);
        wrap.remove();
        parts.length = 0; rings.length = 0; cache.clear();
      },
    };
  }
})();
