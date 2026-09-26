/* COOKIE OVERDRIVE — mini-jeu « Cookie Ninja » (id: 'ninja')
 * Fruit-Ninja-like : glisse pour trancher TES cookies (skin + accessoires), évite les brocolis.
 * Aucun emoji affiché : toutes les images viennent de CO.art (js/art.js) avec fallbacks vectoriels.
 * 3 vies, manche de 60 s max, combos multi-tranches, cookies dorés, vagues FRENZY.
 * Contrat : SPEC.md › « Minigame contract ». Tout est créé dans mount() et retiré dans destroy().
 */
(function () {
  'use strict';
  const CO = (window.CO = window.CO || {});

  const FONT = '"Lilita One", "Arial Rounded MT Bold", "Trebuchet MS", sans-serif';
  const STROKE = '#1a0b33';
  const TAU = Math.PI * 2;
  const ROUND = 60;          // durée max d'une manche (s)
  const LIVES = 3;
  const STEP = 0.62;         // durée d'un pas du compte à rebours (s)
  const GO_T = 0.7;
  const CHAIN_GAP = 0.3;     // s max entre deux tranches pour garder la chaîne (combo)
  const SLICE_SPEED = 110;   // px/s mini pour que la lame coupe
  const DEF_PAL = { base: '#d99a4e', dark: '#a9652a', light: '#f3c783', chip: '#4a2511', chipHi: '#7a4424', rim: '#8a5220' };
  const GOLD_PAL = { base: '#ffcc33', dark: '#c98a00', light: '#fff2a8', chip: '#b36b00', chipHi: '#ffe07a', rim: '#8a5a00' };
  const CHIPS = [[-0.4, -0.3], [0.35, -0.2], [0, 0.35], [-0.2, 0.1], [0.4, 0.4]];

  const Q_BOMB = ['skill issue', 'le brocoli t\'a ratio', 'AÏE AÏE AÏE', 'c\'est un légume frérot', 'cheh', 'GREEN FLAG ? non.'];
  const Q_MISS = ['RATÉ !', 'il t\'a ghost', 'trop lent', 'skill issue', 'oups'];
  const Q_COMBO = ['TROP FORT', 'AURA +1000', 'W', 'NO CAP', 'INSANE', 'CHEF !', 'MAIN CHARACTER'];

  const rand = (a, b) => a + Math.random() * (b - a);
  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
  const lerp = (a, b, t) => a + (b - a) * t;
  const pick = (a) => a[(Math.random() * a.length) | 0];
  const easeOutBack = (t) => { const c = 1.70158; t -= 1; return 1 + (c + 1) * t * t * t + c * t * t; };
  const easeOutCubic = (t) => 1 - Math.pow(1 - t, 3);
  const hsl = (h, s, l, a) => 'hsla(' + Math.round(((h % 360) + 360) % 360) + ',' + s + '%,' + l + '%,' + (a == null ? 1 : a) + ')';

  function quipFor(score) {
    if (score >= 150) return 'T\'es un vrai ninja, no cap. Aura infinie.';
    if (score >= 90) return 'AURA +1000, trop fort !';
    if (score >= 45) return 'W énorme, continue comme ça !';
    if (score >= 15) return 'Pas mal… mais on peut faire mieux.';
    return 'skill issue… réessaie !';
  }

  const P = 'cn';
  const CSS = `
.${P}-wrap{position:absolute;inset:0;overflow:hidden;background:#0b0620;color:#fff6fe;font-family:var(--f-body,'Fredoka',system-ui,sans-serif);-webkit-user-select:none;user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:transparent}
.${P}-wrap [hidden]{display:none!important}
.${P}-cv{position:absolute;inset:0;width:100%;height:100%;display:block;touch-action:none;cursor:crosshair}
.${P}-scr{position:absolute;inset:0;box-sizing:border-box;display:flex;flex-direction:column;align-items:center;justify-content:space-between;gap:10px;padding:clamp(10px,3vh,26px) 16px clamp(14px,3.5vh,30px);pointer-events:none}
.${P}-scr>*{pointer-events:auto}
.${P}-top{display:flex;flex-direction:column;align-items:center;gap:2px;text-align:center}
.${P}-emo{display:flex;justify-content:center;animation:${P}-bob 1.5s ease-in-out infinite}
.${P}-hero{display:block;width:clamp(48px,10vh,84px);height:clamp(48px,10vh,84px);object-fit:contain;filter:drop-shadow(0 0 14px rgba(255,43,214,.85))}
.${P}-ic{display:inline-block;width:1.3em;height:1.3em;object-fit:contain;vertical-align:-0.28em;flex:none}
.${P}-noart{display:none!important}
.${P}-it{display:inline-flex;align-items:center;gap:.35em}
.${P}-title{margin:0;font-weight:400;font-size:clamp(36px,11.5vw,86px);line-height:1;white-space:nowrap}
.${P}-title span,.${P}-rec span{display:inline-block;animation:${P}-wave 1.6s ease-in-out infinite}
.${P}-sub{margin-top:6px;font-family:var(--f-mono,monospace);font-weight:700;font-size:clamp(11px,3.3vw,15px);letter-spacing:.1em;text-transform:uppercase;color:#1ff4ff;text-shadow:0 0 10px rgba(31,244,255,.7)}
.${P}-bot{display:flex;flex-direction:column;align-items:center;gap:10px;width:min(100%,440px)}
.${P}-rules{display:grid;grid-template-columns:1fr 1fr;gap:6px;width:100%}
.${P}-rule{display:flex;align-items:center;gap:6px;padding:6px 9px;border-radius:12px;background:rgba(22,11,52,.82);border:2px solid rgba(190,150,255,.25);font-weight:600;font-size:clamp(11.5px,3.3vw,14px);line-height:1.15;box-shadow:0 3px 0 rgba(0,0,0,.35)}
.${P}-rule .${P}-ic{width:1.7em;height:1.7em}
.${P}-best,.${P}-bestl{display:inline-flex;align-items:center;gap:6px}
.${P}-best{font-family:var(--f-mono,monospace);font-weight:700;font-size:15px;letter-spacing:.06em;color:#ffc93c;text-shadow:0 0 12px rgba(255,201,60,.55)}
.${P}-play{min-width:min(240px,80vw);font-size:30px!important;animation:${P}-pulse 1.1s ease-in-out infinite}
.${P}-res{justify-content:center;background:radial-gradient(ellipse at center,rgba(11,6,32,.35),rgba(11,6,32,.78))}
.${P}-frame{width:min(100%,400px);max-height:100%;border-radius:24px;display:flex;animation:${P}-pop .5s cubic-bezier(.2,1.5,.4,1) both}
.${P}-card{flex:1;min-width:0;max-height:100%;box-sizing:border-box;overflow:auto;border-radius:24px;background:linear-gradient(180deg,#26104f,#130731);padding:16px 16px 18px;display:flex;flex-direction:column;align-items:center;gap:4px;text-align:center;box-shadow:inset 0 2px 0 rgba(255,255,255,.12)}
.${P}-head{font-size:clamp(28px,8vw,40px);line-height:1.05;display:inline-flex;align-items:center;gap:.25em}
.${P}-quip{font-weight:600;font-size:15px;color:#d9ccff;margin-bottom:4px}
.${P}-lbl{font-family:var(--f-mono,monospace);font-weight:700;font-size:12px;letter-spacing:.25em;color:#b3a6dd}
.${P}-score{font-size:clamp(56px,17vw,84px);line-height:1}
.${P}-score.${P}-bump{animation:${P}-bump .35s ease-out}
.${P}-rec{font-size:clamp(22px,6.5vw,30px);line-height:1.1;rotate:-3deg;animation:${P}-pop .5s cubic-bezier(.2,1.6,.4,1) both}
.${P}-bestl{font-family:var(--f-mono,monospace);font-weight:700;font-size:13px;color:#ffc93c}
.${P}-stats{display:flex;flex-wrap:wrap;justify-content:center;gap:4px 12px;font-size:13px;font-weight:600;color:#c9bcf2;margin:2px 0 4px}
.${P}-stats>span{display:inline-flex;align-items:center;gap:4px}
.${P}-rw{display:flex;flex-wrap:wrap;gap:8px;justify-content:center;margin:4px 0 10px;animation:${P}-pop .45s cubic-bezier(.2,1.6,.4,1) both}
.${P}-pill{display:inline-flex;align-items:center;gap:6px;font-family:var(--f-display,'Lilita One',sans-serif);font-size:22px;line-height:1;padding:8px 14px 9px;border-radius:999px;border:3px solid #1a0b33;color:#fff;background:linear-gradient(180deg,#ffe066,#ffb800);-webkit-text-stroke:.12em #1a0b33;paint-order:stroke fill;box-shadow:inset 0 2px 0 rgba(255,255,255,.4),0 4px 0 #1a0b33}
.${P}-pill .${P}-ic{width:1.15em;height:1.15em;vertical-align:0}
.${P}-pill.gem{background:linear-gradient(180deg,#7ffaff,#1fd6ff)}
.${P}-pill.hint{background:rgba(40,20,90,.85);font-family:var(--f-body,'Fredoka',sans-serif);-webkit-text-stroke:0;font-size:13px;font-weight:600;color:#b3a6dd;box-shadow:none;border-color:rgba(190,150,255,.3);align-self:center}
.${P}-btns{display:flex;gap:10px;justify-content:center;flex-wrap:wrap;transition:opacity .25s,transform .25s}
.${P}-btns.${P}-wait{opacity:0;transform:translateY(8px);pointer-events:none}
@keyframes ${P}-bob{0%,100%{transform:translateY(0) rotate(-6deg)}50%{transform:translateY(-6px) rotate(6deg)}}
@keyframes ${P}-wave{0%,100%{transform:translateY(0)}50%{transform:translateY(-7px)}}
@keyframes ${P}-pulse{0%,100%{scale:1}50%{scale:1.06}}
@keyframes ${P}-pop{0%{transform:scale(.3);opacity:0}100%{transform:scale(1);opacity:1}}
@keyframes ${P}-bump{0%{transform:scale(1)}40%{transform:scale(1.25)}100%{transform:scale(1)}}
.${P}-rm,.${P}-rm *{animation:none!important}
`;

  function el(tag, cls, html) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html != null) e.innerHTML = html;
    return e;
  }
  function letters(elm, text) {
    elm.textContent = '';
    return Array.from(text).map((ch, i) => {
      const s = document.createElement('span');
      s.textContent = ch === ' ' ? ' ' : ch;
      s.style.animationDelay = (-i * 0.09).toFixed(2) + 's';
      elm.appendChild(s);
      return s;
    });
  }
  function outlined(ctx, str, x, y, size, fill, align) {
    ctx.font = '700 ' + Math.max(8, Math.round(size)) + 'px ' + FONT;
    ctx.textAlign = align || 'center';
    ctx.textBaseline = 'middle';
    ctx.lineJoin = 'round';
    ctx.miterLimit = 2;
    ctx.lineWidth = Math.max(2, size * 0.18);
    ctx.strokeStyle = STROKE;
    ctx.strokeText(str, x, y + size * 0.07);
    ctx.strokeText(str, x, y);
    ctx.fillStyle = fill;
    ctx.fillText(str, x, y);
  }
  /* ---- shared vector art (CO.art from js/art.js) with tolerant fallbacks ---- */
  function artHas(name) {
    const A = CO.art;
    return !!(A && typeof A.el === 'function' && (typeof A.has !== 'function' || A.has(name)));
  }
  // <img> from CO.art; if the icon isn't registered (yet), paint `painter(g, size)` on a small canvas, else hide.
  function artImg(name, cls, painter) {
    if (artHas(name)) {
      try {
        const im = CO.art.el(name, cls);
        if (im) {
          if (cls) cls.split(' ').forEach((c) => c && im.classList.add(c));
          im.setAttribute('alt', ''); im.setAttribute('draggable', 'false');
          if (im.tagName === 'IMG') im.addEventListener('error', () => im.classList.add(P + '-noart'), { once: true });
          return im;
        }
      } catch (e) { /* art pas prête */ }
    }
    if (painter) {
      const c = el('canvas', cls); c.width = c.height = 96;
      const g = c.getContext('2d'); g.translate(48, 48);
      try { painter(g, 84); } catch (e) { /* ignore */ }
      return c;
    }
    return el('span', (cls || '') + ' ' + P + '-noart');
  }
  function artDraw(ctx, name, x, y, size, o) {
    const A = CO.art;
    if (!A || typeof A.draw !== 'function') return false;
    try { return A.draw(ctx, name, x, y, size, o || {}) !== false; } catch (e) { return false; }
  }
  function iconText(parent, name, text, cls, painter) {
    const s = el('span', P + '-it' + (cls ? ' ' + cls : ''));
    s.appendChild(artImg(name, P + '-ic', painter));
    s.appendChild(document.createTextNode(text));
    parent.appendChild(s);
    return s;
  }
  // Fallback broccoli (vector, angry) when CO.art has no 'item:broccoli' yet. Centered at 0,0 in a s×s box.
  function paintBroccoli(g, s) {
    const k = s / 2, lw = Math.max(2, s * 0.06);
    g.lineJoin = 'round'; g.lineCap = 'round';
    g.beginPath(); g.moveTo(-k * 0.24, -k * 0.1); g.lineTo(k * 0.24, -k * 0.1); g.lineTo(k * 0.34, k * 0.86);
    g.quadraticCurveTo(0, k * 0.98, -k * 0.34, k * 0.86); g.closePath();
    g.lineWidth = lw; g.strokeStyle = STROKE; g.stroke(); g.fillStyle = '#a8e66f'; g.fill();
    g.fillStyle = 'rgba(255,255,255,0.35)'; g.fillRect(-k * 0.13, k * 0.05, k * 0.07, k * 0.6);
    const fl = [[-0.5, -0.28, 0.34], [0.5, -0.28, 0.34], [0, -0.55, 0.38], [-0.25, -0.05, 0.28], [0.25, -0.05, 0.28], [-0.24, -0.52, 0.28], [0.25, -0.5, 0.28]];
    g.beginPath();
    for (const f of fl) { g.moveTo(f[0] * k + f[2] * k, f[1] * k); g.arc(f[0] * k, f[1] * k, f[2] * k, 0, TAU); }
    g.lineWidth = lw * 2; g.strokeStyle = STROKE; g.stroke();
    g.fillStyle = '#2fae4a'; g.fill();
    g.fillStyle = '#5fd46b';
    for (const f of fl) { g.beginPath(); g.arc((f[0] - f[2] * 0.25) * k, (f[1] - f[2] * 0.25) * k, f[2] * k * 0.45, 0, TAU); g.fill(); }
    // angry face
    for (const sx of [-1, 1]) {
      g.fillStyle = '#ffffff'; g.beginPath(); g.arc(sx * k * 0.17, -k * 0.34, k * 0.11, 0, TAU); g.fill();
      g.lineWidth = lw * 0.7; g.strokeStyle = STROKE; g.stroke();
      g.fillStyle = STROKE; g.beginPath(); g.arc(sx * k * 0.14, -k * 0.31, k * 0.05, 0, TAU); g.fill();
      g.lineWidth = lw; g.beginPath(); g.moveTo(sx * k * 0.3, -k * 0.52); g.lineTo(sx * k * 0.06, -k * 0.43); g.stroke();
    }
    g.lineWidth = lw * 0.8; g.beginPath(); g.arc(0, -k * 0.08, k * 0.1, Math.PI * 1.15, Math.PI * 1.85); g.stroke();
  }
  function heartPath(ctx, s) {
    const k = s / 2;
    ctx.beginPath();
    ctx.moveTo(0, k * 0.9);
    ctx.bezierCurveTo(-k * 0.2, k * 0.72, -k * 1.05, k * 0.2, -k * 1.0, -k * 0.35);
    ctx.bezierCurveTo(-k * 0.95, -k * 0.95, -k * 0.2, -k * 1.05, 0, -k * 0.45);
    ctx.bezierCurveTo(k * 0.2, -k * 1.05, k * 0.95, -k * 0.95, k * 1.0, -k * 0.35);
    ctx.bezierCurveTo(k * 1.05, k * 0.2, k * 0.2, k * 0.72, 0, k * 0.9);
    ctx.closePath();
  }

  /* ═════════════════════════ MOUNT ═════════════════════════ */
  function mount(root, api) {
    /* ---- settings / api helpers ---- */
    const S = () => { try { return api.settings() || {}; } catch (e) { return {}; } };
    const reduced = () => !!S().reducedMotion;
    const plevel = () => { const p = S().particles; return p === 0 || p === 1 ? p : 2; };
    const canShake = () => S().shake !== false && !reduced();
    const mult = () => [0.3, 0.6, 1][plevel()] * (reduced() ? 0.6 : 1);
    const maxParts = () => [70, 200, 450][plevel()];
    const hue = (o) => { try { return api.hue(o || 0); } catch (e) { return (performance.now() * 0.06 + (o || 0)) % 360; } };
    const pal = () => { try { const s = api.skin(); return (s && s.pal) || DEF_PAL; } catch (e) { return DEF_PAL; } };
    const fmt = (n) => { try { return api.fmt(n); } catch (e) { return String(Math.round(n)); } };
    const bestNow = () => { try { return api.best() || 0; } catch (e) { return 0; } };
    const sfxLast = Object.create(null);
    function sfx(name, o) {
      const t = performance.now();
      if (sfxLast[name] && t - sfxLast[name] < 30) return;
      sfxLast[name] = t;
      try { api.sfx(name, o || {}); } catch (e) { /* pas d'audio */ }
    }

    /* ---- state ---- */
    let W = 0, H = 0, dpr = 1, R = 36, bg = null, cvRect = { left: 0, top: 0 };
    let raf = 0, lastTs = 0, realT = 0, destroyed = false;
    let mode = 'menu';            // menu | count | play | paused | over | results
    let resumeRun = false, countT = 0, countStep = -1, goT = 0;
    let score = 0, lives = LIVES, elapsed = 0, nextWave = 0, lastGold = -99, lastTick = 0, bestAtStart = 0, recAnnounced = false;
    let frenzyAt = [], frenzyOn = false, frenzyEnd = 0;
    let overT = 0, overReason = 'ko', ended = false;
    let stats = { sliced: 0, gold: 0, bombs: 0, maxCombo: 0 };
    let objs = [], halves = [], parts = [], texts = [], rings = [], slashes = [], marks = [], queue = [];
    const blades = new Map();
    let fading = [];
    const ai = { ai: true, pts: [], chainN: 0, chainT: 0, chainX: 0, chainY: 0, lastX: 0, lastY: 0, lastT: 0, busy: false, t: 0, dur: 0.13, x0: 0, y0: 0, x1: 0, y1: 0, cool: 0.8 };
    let demoT = 0.3;
    let shake = 0, flashA = 0, flashCol = '#fff', freeze = 0, scoreBump = 0, timerPulse = 0;
    const heartFx = [0, 0, 0];
    let lookX = -1, lookY = -1;
    let cookieFail = false;
    const spriteCache = new Map();
    const motes = Array.from({ length: 22 }, () => ({ x: Math.random(), y: Math.random(), s: rand(1, 2.6), sp: rand(0.015, 0.05), h: rand(0, 360) }));
    let resT = 0, resStage = 0, resData = null, shownScore = -1, lastTickT = 0, recSpans = [];

    // Title picture: CO.art 'mg:<id>' if available, else the player's own cookie (with accessories).
    function heroArt(name) {
      const fallback = () => {
        const c = el('canvas', P + '-hero'); c.width = c.height = 144;
        const g = c.getContext('2d');
        try { api.drawCookie(g, 72, 72, 54, { accessories: true, rot: -0.25 }); } catch (e) { g.fillStyle = pal().base; g.beginPath(); g.arc(72, 72, 54, 0, TAU); g.fill(); }
        return c;
      };
      if (!artHas(name)) return fallback();
      const im = artImg(name, P + '-hero');
      if (im.tagName === 'IMG') im.addEventListener('error', () => { if (im.parentNode) im.parentNode.replaceChild(fallback(), im); }, { once: true });
      return im;
    }

    /* ---- DOM ---- */
    const wrap = el('div', P + '-wrap');
    const styleEl = el('style'); styleEl.textContent = CSS; wrap.appendChild(styleEl);
    const cv = el('canvas', P + '-cv'); wrap.appendChild(cv);
    const ctx = cv.getContext('2d');

    const menuEl = el('div', P + '-scr ' + P + '-menu',
      '<div class="' + P + '-top"><div class="' + P + '-emo"></div><h2 class="' + P + '-title stroke-text"></h2>' +
      '<div class="' + P + '-sub">Tranche les cookies · évite les brocolis</div></div>' +
      '<div class="' + P + '-bot"><div class="' + P + '-rules"></div><div class="' + P + '-best"></div>' +
      '<button class="btn big green ' + P + '-play" type="button"></button></div>');
    menuEl.querySelector('.' + P + '-emo').appendChild(heroArt('mg:ninja'));
    const titleSpans = letters(menuEl.querySelector('.' + P + '-title'), 'COOKIE NINJA');
    const rulesEl = menuEl.querySelector('.' + P + '-rules');
    [['ui:sword', 'Glisse pour trancher'], ['ui:fire', '3+ d\'un coup = COMBO'], ['ui:golden', 'Cookie doré = +5'], ['item:broccoli', 'Brocoli ou raté = -1 vie', paintBroccoli]]
      .forEach((r) => iconText(rulesEl, r[0], r[1], P + '-rule', r[2]));
    iconText(menuEl.querySelector('.' + P + '-best'), 'ui:trophy', 'RECORD : ' + fmt(bestNow()));
    const playBtn = menuEl.querySelector('.' + P + '-play');
    playBtn.appendChild(artImg('ui:play', P + '-ic'));
    playBtn.appendChild(document.createTextNode('JOUER'));
    wrap.appendChild(menuEl);

    const resEl = el('div', P + '-scr ' + P + '-res',
      '<div class="' + P + '-frame rgb-border"><div class="' + P + '-card">' +
      '<div class="' + P + '-head stroke-text"></div><div class="' + P + '-quip"></div>' +
      '<div class="' + P + '-lbl">SCORE</div><div class="' + P + '-score stroke-text">0</div>' +
      '<div class="' + P + '-rec stroke-text" hidden></div><div class="' + P + '-bestl"></div>' +
      '<div class="' + P + '-stats"></div><div class="' + P + '-rw" hidden></div>' +
      '<div class="' + P + '-btns ' + P + '-wait"><button class="btn green ' + P + '-again" type="button">REJOUER</button>' +
      '<button class="btn dark ' + P + '-quit" type="button">QUITTER</button></div></div></div>');
    resEl.hidden = true;
    const q = (c) => resEl.querySelector('.' + P + '-' + c);
    const rHead = q('head'), rQuip = q('quip'), rScore = q('score'), rRec = q('rec'), rBest = q('bestl'), rStats = q('stats'), rRw = q('rw'), rBtns = q('btns');
    const againBtn = q('again'), quitBtn = q('quit');
    wrap.appendChild(resEl);
    wrap.classList.toggle(P + '-rm', reduced());
    root.appendChild(wrap);

    /* ---- sizing ---- */
    function resize() {
      const rc = root.getBoundingClientRect();
      const w = Math.max(160, Math.round(rc.width)), h = Math.max(200, Math.round(rc.height));
      const d = Math.min(window.devicePixelRatio || 1, plevel() < 2 ? 1.5 : 2);
      cvRect = cv.getBoundingClientRect();
      if (w === W && h === H && d === dpr && bg) return;
      W = w; H = h; dpr = d;
      cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
      R = clamp(Math.min(W, H) * 0.085, 28, 60);
      if (lookX < 0) { lookX = W / 2; lookY = H * 0.3; }
      spriteCache.clear();
      buildBg();
    }
    function buildBg() {
      bg = document.createElement('canvas');
      bg.width = cv.width; bg.height = cv.height;
      const g = bg.getContext('2d');
      g.scale(dpr, dpr);
      let gr = g.createRadialGradient(W / 2, H * 0.45, 0, W / 2, H * 0.45, Math.hypot(W, H) * 0.62);
      gr.addColorStop(0, '#3d1075'); gr.addColorStop(0.45, '#1b0845'); gr.addColorStop(1, '#07031a');
      g.fillStyle = gr; g.fillRect(0, 0, W, H);
      g.globalAlpha = 0.06; g.strokeStyle = '#ff2bd6'; g.lineWidth = 2;
      for (let x = -H; x < W; x += 34) { g.beginPath(); g.moveTo(x, H); g.lineTo(x + H, 0); g.stroke(); }
      g.globalAlpha = 1;
      gr = g.createLinearGradient(0, H * 0.72, 0, H);
      gr.addColorStop(0, 'rgba(255,43,214,0)'); gr.addColorStop(1, 'rgba(255,43,214,0.26)');
      g.fillStyle = gr; g.fillRect(0, H * 0.72, W, H * 0.28);
      gr = g.createRadialGradient(W / 2, H / 2, Math.min(W, H) * 0.3, W / 2, H / 2, Math.hypot(W, H) * 0.62);
      gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(1, 'rgba(0,0,0,0.55)');
      g.fillStyle = gr; g.fillRect(0, 0, W, H);
    }
    function bombSprite(css) {
      const px = Math.max(8, Math.round(css * dpr));
      const A = CO.art;
      if (A && typeof A.sprite === 'function') {
        try { const c = A.sprite('item:broccoli', px); if (c) return c; } catch (e) { /* pas prête */ }
      }
      let c = spriteCache.get(px);
      if (!c) {
        c = document.createElement('canvas'); c.width = c.height = px;
        const g = c.getContext('2d'); g.translate(px / 2, px / 2);
        paintBroccoli(g, px * 0.86);
        spriteCache.set(px, c);
      }
      return c;
    }

    /* ---- cookie painter (api.drawCookie with safe fallback) ---- */
    function fallbackCookie(x, y, r, o) {
      let p = pal();
      if (o && o.skin === 'golden') p = GOLD_PAL;
      ctx.save(); ctx.translate(x, y); ctx.rotate((o && o.rot) || 0);
      ctx.fillStyle = p.base; ctx.beginPath(); ctx.arc(0, 0, r, 0, TAU); ctx.fill();
      ctx.lineWidth = r * 0.08; ctx.strokeStyle = p.rim; ctx.stroke();
      ctx.fillStyle = p.chip;
      for (const c of CHIPS) { ctx.beginPath(); ctx.arc(c[0] * r, c[1] * r, r * 0.13, 0, TAU); ctx.fill(); }
      ctx.restore();
    }
    function cookie(x, y, r, o) {
      if (!cookieFail) {
        try { api.drawCookie(ctx, x, y, r, o); return; } catch (e) {
          cookieFail = true;
          console.warn('[ninja] api.drawCookie a planté, fallback local', e);
          cv.width = cv.width; // reset complet du contexte (pile save/clip)
          ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        }
      }
      fallbackCookie(x, y, r, o);
    }

    /* ---- FX helpers ---- */
    function addText(str, x, y, size, col, life, big) {
      size = Math.min(size, (W * 0.92) / (Math.max(3, str.length) * 0.56));
      const hw = str.length * size * 0.29 + 6;
      x = clamp(x, hw, Math.max(hw, W - hw));
      y = clamp(y, size * 0.7, H - size * 0.7);
      texts.push({ str, x, y, size, col, life: life || 0.8, max: life || 0.8, vy: big ? -R * 0.35 : -R * 1.1, big: !!big });
    }
    function flash(col, a) { if (reduced()) return; flashCol = col; flashA = Math.max(flashA, a); }
    function bumpShake(n) { shake = Math.max(shake, n); }
    function spark(x, y, n, cols, spd, add) {
      n = Math.round(n * mult());
      for (let i = 0; i < n && parts.length < maxParts(); i++) {
        const a = rand(0, TAU), sp = rand(0.3, 1) * spd;
        const l = rand(0.35, 0.8);
        parts.push({ x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, g: H * 0.5, drag: 0.9, life: l, max: l, size: rand(2, 4.5), col: pick(cols), sq: false, rot: 0, vr: 0, add: add !== false });
      }
    }
    function crumbs(x, y, r, p, n) {
      n = Math.round(n * mult());
      const cols = [p.base, p.dark, p.light, p.chip, p.chip];
      for (let i = 0; i < n && parts.length < maxParts(); i++) {
        const a = rand(0, TAU), sp = R * rand(1.5, 6);
        const l = rand(0.5, 1.05);
        parts.push({ x: x + Math.cos(a) * r * 0.4, y: y + Math.sin(a) * r * 0.4, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - R * 2.2, g: H * 1.2, drag: 0.99, life: l, max: l, size: rand(0.08, 0.17) * r, col: pick(cols), sq: Math.random() < 0.65, rot: rand(0, TAU), vr: rand(-12, 12), add: false });
      }
    }
    function confetti(n) {
      n = Math.round(n * mult());
      for (let i = 0; i < n && parts.length < maxParts(); i++) {
        const l = rand(1.6, 2.8);
        parts.push({ x: rand(0, W), y: rand(-40, -5), vx: rand(-40, 40), vy: rand(60, 200), g: H * 0.25, drag: 0.995, life: l, max: l, size: rand(5, 9), col: hsl(rand(0, 360), 100, 62), sq: true, rot: rand(0, TAU), vr: rand(-8, 8), add: false });
      }
    }

    /* ---- launching ---- */
    function launch(kind, o) {
      o = o || {};
      const sp = o.speed || 1;
      const gold = kind === 'gold';
      const g = H * 1.25 * sp * sp * (gold ? 1.3 : 1);
      const r = gold ? R * 0.82 : kind === 'bomb' ? R * 0.95 : R;
      const x = o.x != null ? o.x : rand(W * 0.12, W * 0.88);
      const y = H + r + 4;
      const apexY = o.apexY != null ? o.apexY : gold ? rand(H * 0.1, H * 0.26) : rand(H * 0.14, H * 0.42);
      const vy = -Math.sqrt(2 * g * (y - apexY));
      const tA = -vy / g;
      const tx = o.tx != null ? o.tx : clamp(x + rand(-W * 0.28, W * 0.28), W * 0.12, W * 0.88);
      const acc = kind === 'cookie' && !o.frenzy && objs.filter((b) => b.acc && !b.dead).length < 4;
      objs.push({ kind, x, y, vx: (tx - x) / tA, vy, g, r, rot: rand(0, TAU), vr: rand(-4, 4) * (gold ? 1.8 : 1), frenzy: !!o.frenzy, acc, dead: false, seed: rand(0, 10), aiSkip: false });
    }
    function spawnWave(p) {
      const sp = 1 + 0.32 * p;
      const n = Math.min(5, 1 + Math.floor(Math.random() * (1.5 + p * 3.2)));
      const bombChance = elapsed < 4 ? 0 : 0.1 + 0.22 * p;
      const maxBombs = p > 0.55 ? 2 : 1;
      const fan = n >= 3 && Math.random() < 0.28;
      const baseX = rand(W * 0.25, W * 0.75);
      const wave = [];
      let bombs = 0;
      for (let i = 0; i < n; i++) {
        let kind = 'cookie';
        if (bombs < maxBombs && Math.random() < bombChance) { kind = 'bomb'; bombs++; }
        else if (elapsed - lastGold > 6 && Math.random() < 0.06 + 0.05 * p) { kind = 'gold'; lastGold = elapsed; }
        wave.push({
          at: elapsed + (fan ? i * 0.07 : i * rand(0.12, 0.28)), kind, speed: sp * rand(0.94, 1.06),
          x: fan ? baseX + rand(-18, 18) : undefined,
          tx: fan ? lerp(W * 0.18, W * 0.82, i / (n - 1)) : undefined,
        });
      }
      if (bombs === n) wave[0].kind = 'cookie';
      queue.push(...wave);
      sfx('whoosh', { vol: 0.4, pitch: rand(0.9, 1.15) });
    }
    function startFrenzy() {
      frenzyAt.shift();
      frenzyOn = true; frenzyEnd = elapsed + 3.4;
      addText('FRENZY !!!', W / 2, H * 0.4, R * 1.5, 'rgb', 1.5, true);
      sfx('fever'); flash('rgb', 0.35); bumpShake(8);
      const n = 8 + Math.floor(Math.random() * 5);
      const sp = 1 + 0.25 * (elapsed / ROUND);
      for (let i = 0; i < n; i++) {
        const left = i % 2 === 0;
        queue.push({ at: elapsed + 0.45 + i * rand(0.09, 0.15), kind: 'cookie', frenzy: true, speed: sp * rand(0.95, 1.1),
          x: left ? rand(W * 0.03, W * 0.2) : rand(W * 0.8, W * 0.97), tx: left ? rand(W * 0.35, W * 0.7) : rand(W * 0.3, W * 0.65), apexY: rand(H * 0.12, H * 0.45) });
      }
      nextWave = frenzyEnd + 0.5;
    }
    function flushQueue() {
      for (let i = queue.length - 1; i >= 0; i--) {
        const s = queue[i];
        if (s.at <= elapsed) { queue.splice(i, 1); launch(s.kind, s); }
      }
    }

    /* ---- slicing ---- */
    function segHit(o, x1, y1, x2, y2, rad) {
      const dx = x2 - x1, dy = y2 - y1, l2 = dx * dx + dy * dy;
      const t = l2 ? clamp(((o.x - x1) * dx + (o.y - y1) * dy) / l2, 0, 1) : 0;
      const px = x1 + dx * t - o.x, py = y1 + dy * t - o.y;
      return px * px + py * py <= rad * rad;
    }
    function bladeSeg(b, x1, y1, x2, y2) {
      if (mode !== 'play' && mode !== 'menu' && mode !== 'results') return;
      const ang = Math.atan2(y2 - y1, x2 - x1);
      for (const o of objs) {
        if (o.dead) continue;
        const rad = o.kind === 'bomb' ? o.r * 0.72 : o.r * 1.05;
        if (segHit(o, x1, y1, x2, y2, rad)) sliceObj(o, ang, b);
      }
    }
    function bladeTo(b, x, y, t) {
      const dx = x - b.lastX, dy = y - b.lastY, d = Math.hypot(dx, dy);
      if (d < 0.5) return;
      const dtt = Math.max(0.001, t - b.lastT);
      if (!b.pts.length) b.pts.push({ x: b.lastX, y: b.lastY, t: realT });
      b.pts.push({ x, y, t: realT });
      if (b.pts.length > 48) b.pts.shift();
      if (b.ai || d / dtt > SLICE_SPEED) bladeSeg(b, b.lastX, b.lastY, x, y);
      b.lastX = x; b.lastY = y; b.lastT = t;
    }
    function sliceObj(o, ang, b) {
      o.dead = true;
      const live = mode === 'play';
      const quiet = !!b.ai;
      if (o.kind === 'bomb') { bombBoom(o, live, quiet); return; }
      const gold = o.kind === 'gold';
      const pts = gold ? 5 : 1;
      if (live) { addScore(pts); stats.sliced++; if (gold) stats.gold++; }
      const nx = -Math.sin(ang), ny = Math.cos(ang);
      const push = R * rand(2.2, 3.4);
      for (const side of [-1, 1]) {
        halves.push({ x: o.x + nx * side * 2, y: o.y + ny * side * 2, vx: o.vx * 0.5 + nx * side * push, vy: Math.min(o.vy * 0.4, 0) + ny * side * push - R * 1.5,
          g: o.g, ang, va: side * rand(2, 5), inner: o.rot - ang, side, r: o.r, acc: o.acc, skin: gold ? 'golden' : null });
      }
      crumbs(o.x, o.y, o.r, gold ? GOLD_PAL : pal(), gold ? 18 : 12);
      slashes.push({ x: o.x, y: o.y, ang, len: o.r * 3.4, life: 0.2, max: 0.2 });
      if (b.chainN > 0 && realT - b.chainT < CHAIN_GAP) b.chainN++;
      else { resolveChain(b); b.chainN = 1; }
      b.chainT = realT; b.chainX = o.x; b.chainY = o.y;
      if (!quiet) sfx('slice', { pitch: 1 + Math.min(8, b.chainN - 1) * 0.09 });
      if (live) {
        addText('+' + pts, o.x, o.y - o.r * 0.5, gold ? R * 0.95 : R * 0.72, gold ? '#ffd23c' : '#ffffff', 0.75);
        if (b.chainN >= 2) addText('x' + b.chainN, o.x + o.r, o.y - o.r * 1.35, R * 0.55, 'rgb', 0.5);
      }
      if (gold) {
        rings.push({ x: o.x, y: o.y, r: o.r, dr: R * 9, life: 0.45, max: 0.45, col: '#ffd23c', w: 7 });
        spark(o.x, o.y, 26, ['#ffd23c', '#fff2a8', '#ffffff', '#ffb800'], R * 9);
        if (!quiet) sfx('golden');
        if (live) { freeze = Math.max(freeze, 0.07); bumpShake(7); flash('#ffd23c', 0.18); addText('DORÉ ! +5', o.x, o.y - o.r * 1.8, R * 0.8, '#ffd23c', 1, true); }
      } else {
        spark(o.x, o.y, 6, ['#ffffff', hsl(hue(o.x), 100, 70)], R * 5);
      }
    }
    function resolveChain(b) {
      const n = b.chainN;
      b.chainN = 0;
      if (n < 3 || b.ai || mode !== 'play') return;
      addScore(n);
      stats.maxCombo = Math.max(stats.maxCombo, n);
      const x = clamp(b.chainX, W * 0.25, W * 0.75), y = clamp(b.chainY, H * 0.22, H * 0.7);
      addText('COMBO x' + n + ' !', x, y, R * (0.95 + Math.min(n, 8) * 0.07), 'rgb', 1.15, true);
      addText('+' + n + ' bonus', x, y + R * 0.95, R * 0.55, '#b6ff3b', 1);
      sfx('combo', { pitch: 1 + Math.min(6, n - 3) * 0.08 });
      rings.push({ x, y, r: R * 0.5, dr: R * 10, life: 0.5, max: 0.5, col: 'rgb', w: 8 });
      spark(x, y, 18 + n * 3, [hsl(hue(0), 100, 65), hsl(hue(120), 100, 65), hsl(hue(240), 100, 65), '#ffffff'], R * 8);
      if (n >= 5) { addText(pick(Q_COMBO), x, y - R * 1.2, R * 0.7, '#ffc93c', 1.1, true); flash('rgb', 0.25); bumpShake(8); }
    }
    function bombBoom(o, live, quiet) {
      spark(o.x, o.y, 34, ['#3dff6a', '#1fbf4a', '#ff4d6d', '#ff2040', '#ffffff'], R * 10);
      crumbs(o.x, o.y, o.r, { base: '#3dff6a', dark: '#1a8a3a', light: '#9dff9d', chip: '#0f5a24' }, 16);
      rings.push({ x: o.x, y: o.y, r: o.r, dr: R * 12, life: 0.5, max: 0.5, col: '#ff2040', w: 10 });
      if (!quiet) sfx('hit', { pitch: 0.7 });
      if (!live) return;
      stats.bombs++;
      sfx('error');
      bumpShake(22); flash('#ff2040', 0.5); freeze = Math.max(freeze, 0.16);
      addText('AÏE ! -1 VIE', o.x, o.y, R * 0.9, '#ff4d6d', 1.1, true);
      addText(pick(Q_BOMB), W / 2, H * 0.34, R * 0.7, '#ffffff', 1.3, true);
      loseLife();
    }
    function missed(o) {
      const x = clamp(o.x, R, W - R);
      marks.push({ x, life: 1.2, max: 1.2 });
      addText(pick(Q_MISS), x, H - R * 2.3, R * 0.55, '#ff4d6d', 0.9);
      sfx('miss'); bumpShake(7); flash('#ff2040', 0.15);
      loseLife();
    }
    function loseLife() {
      if (lives <= 0) return;
      lives--;
      heartFx[lives] = 1;
      if (lives <= 0) gameOver('ko');
    }
    function addScore(n) {
      score += n; scoreBump = 1;
      if (!recAnnounced && bestAtStart > 0 && score > bestAtStart) {
        recAnnounced = true;
        addText('NOUVEAU RECORD !', W / 2, H * 0.24, R * 0.8, 'rgb', 1.4, true);
        sfx('achievement');
      }
    }

    /* ---- flow ---- */
    function startRun() {
      if (mode !== 'menu' && mode !== 'results') return;
      if (document.activeElement && wrap.contains(document.activeElement)) document.activeElement.blur();
      menuEl.hidden = true; resEl.hidden = true;
      objs = []; halves = []; parts = []; texts = []; rings = []; slashes = []; marks = []; queue = [];
      blades.clear(); fading = []; ai.pts = []; ai.busy = false; ai.chainN = 0;
      score = 0; lives = LIVES; elapsed = 0; nextWave = 0; lastGold = -99; lastTick = 0;
      bestAtStart = bestNow(); recAnnounced = false;
      frenzyAt = [rand(16, 21), rand(37, 44)]; frenzyOn = false;
      stats = { sliced: 0, gold: 0, bombs: 0, maxCombo: 0 };
      ended = false; heartFx.fill(0); freeze = 0; shake = 0; flashA = 0;
      mode = 'count'; countT = 0; countStep = -1; goT = 0; resumeRun = false;
      wrap.classList.toggle(P + '-rm', reduced());
      sfx('pop');
    }
    function pause() {
      if (mode !== 'play') return;
      blades.forEach((b) => { b.chainN = 0; fading.push(b); });
      blades.clear();
      mode = 'paused';
    }
    function resume() {
      if (mode !== 'paused') return;
      mode = 'count'; countT = 0; countStep = -1; resumeRun = true;
    }
    function gameOver(reason) {
      if (mode !== 'play') return;
      blades.forEach(resolveChain);
      mode = 'over'; overT = 0; overReason = reason; frenzyOn = false; queue = [];
      blades.forEach((b) => fading.push(b)); blades.clear();
      if (reason === 'time') { addText('TEMPS ÉCOULÉ !', W / 2, H * 0.45, R * 1.3, 'rgb', 1.6, true); sfx('win'); }
      else { addText('GAME OVER', W / 2, H * 0.45, R * 1.5, '#ff4d6d', 1.6, true); sfx('lose'); }
    }
    function showResults() {
      if (mode === 'results') return;
      mode = 'results';
      const sc = score;
      const bestBefore = bestNow();
      let unit = 25;
      try { unit = api.unit() || 25; } catch (e) { /* stub */ }
      const cookies = Math.round(unit * sc / 12);
      const gems = sc >= 150 ? 6 : sc >= 90 ? 3 : sc >= 45 ? 1 : 0;
      let r = null;
      if (!ended) {
        ended = true;
        try { r = api.end({ score: sc, cookies, gems }); } catch (e) { console.error('[ninja] api.end', e); }
      }
      r = Object.assign({ cookies, gems, best: Math.max(bestBefore, sc), isNewBest: sc > bestBefore }, r || {});
      resData = { score: sc, cookies: r.cookies, gems: r.gems, best: r.best, isNewBest: !!r.isNewBest && sc > 0 };
      rHead.textContent = '';
      iconText(rHead, overReason === 'time' ? 'ui:clock' : 'ui:skull', overReason === 'time' ? 'TEMPS ÉCOULÉ !' : 'GAME OVER');
      rQuip.textContent = quipFor(sc);
      rScore.textContent = '0'; rScore.classList.remove(P + '-bump'); shownScore = -1;
      rRec.hidden = true; recSpans = letters(rRec, 'NOUVEAU RECORD !');
      rBest.textContent = ''; iconText(rBest, 'ui:trophy', 'Record : ' + fmt(resData.best));
      rStats.textContent = '';
      iconText(rStats, 'ui:cookie', stats.sliced + (stats.sliced > 1 ? ' tranchés' : ' tranché'));
      iconText(rStats, 'ui:golden', stats.gold + (stats.gold > 1 ? ' dorés' : ' doré'));
      iconText(rStats, 'ui:fire', 'combo max x' + (stats.maxCombo || 0));
      rRw.textContent = '';
      const pc = el('span', P + '-pill');
      pc.append('+' + fmt(resData.cookies), artImg('ui:cookie', P + '-ic'));
      rRw.appendChild(pc);
      if (resData.gems > 0) {
        const pg = el('span', P + '-pill gem'); pg.append('+' + resData.gems, artImg('ui:gem', P + '-ic')); rRw.appendChild(pg);
      } else {
        const ph = el('span', P + '-pill hint'); ph.append(artImg('ui:gem', P + '-ic'), sc < 45 ? '1 gemme dès 45 pts' : sc < 90 ? '3 gemmes dès 90 pts' : '6 gemmes dès 150 pts'); rRw.appendChild(ph);
      }
      rRw.hidden = true;
      rBtns.classList.add(P + '-wait');
      wrap.classList.toggle(P + '-rm', reduced());
      resEl.hidden = false;
      resT = 0; resStage = 0; lastTickT = 0;
      demoT = 0.9; ai.cool = 1;
    }

    /* ---- update ---- */
    function updatePlay(dt) {
      elapsed += dt;
      const p = clamp(elapsed / ROUND, 0, 1);
      if (!frenzyOn && frenzyAt.length && elapsed >= frenzyAt[0]) startFrenzy();
      if (frenzyOn && elapsed >= frenzyEnd) frenzyOn = false;
      if (!frenzyOn && elapsed >= nextWave) { spawnWave(p); nextWave = elapsed + lerp(1.55, 0.72, p) + rand(-0.12, 0.18); }
      flushQueue();
      const sec = Math.ceil(ROUND - elapsed);
      if (sec <= 5 && sec >= 1 && sec !== lastTick) { lastTick = sec; sfx('tick', { pitch: 1.2 + (5 - sec) * 0.08 }); timerPulse = 1; }
      if (elapsed >= ROUND) gameOver('time');
    }
    function demoUpdate(dt) {
      demoT -= dt;
      if (demoT <= 0 && objs.length < 7) {
        demoT = rand(0.55, 1.1);
        const k = Math.random();
        launch(k < 0.1 ? 'gold' : k < 0.2 ? 'bomb' : 'cookie', { speed: 0.9 });
        if (Math.random() < 0.35) launch('cookie', { speed: 0.9 });
      }
      aiUpdate(dt);
    }
    function aiUpdate(dt) {
      if (ai.busy) {
        ai.t += dt;
        const k = Math.min(1, ai.t / ai.dur), e = k * k * (3 - 2 * k);
        bladeTo(ai, lerp(ai.x0, ai.x1, e), lerp(ai.y0, ai.y1, e), realT);
        if (k >= 1) { ai.busy = false; ai.cool = rand(0.05, 0.4); }
        return;
      }
      ai.cool -= dt;
      if (ai.cool > 0) return;
      const o = objs.find((b) => !b.dead && !b.aiSkip && b.kind !== 'bomb' && b.vy > -b.g * 0.25 && b.y < H * 0.75);
      if (!o) return;
      if (Math.random() < 0.1) { o.aiSkip = true; return; }
      const T = ai.dur * 0.5;
      const px = o.x + o.vx * T, py = o.y + o.vy * T + 0.5 * o.g * T * T;
      const a = rand(0, TAU), d = o.r * 2.4;
      ai.x0 = px - Math.cos(a) * d; ai.y0 = py - Math.sin(a) * d;
      ai.x1 = px + Math.cos(a) * d; ai.y1 = py + Math.sin(a) * d;
      ai.lastX = ai.x0; ai.lastY = ai.y0; ai.lastT = realT;
      ai.pts = [{ x: ai.x0, y: ai.y0, t: realT }];
      ai.t = 0; ai.busy = true;
    }
    function physics(dt) {
      for (let i = objs.length - 1; i >= 0; i--) {
        const o = objs[i];
        if (o.dead) { objs.splice(i, 1); continue; }
        o.vy += o.g * dt; o.x += o.vx * dt; o.y += o.vy * dt; o.rot += o.vr * dt;
        if (o.vy > 0 && o.y > H + o.r * 1.3) {
          objs.splice(i, 1);
          if (mode === 'play' && o.kind === 'cookie' && !o.frenzy) missed(o);
        }
      }
      for (let i = halves.length - 1; i >= 0; i--) {
        const h = halves[i];
        h.vy += h.g * dt; h.x += h.vx * dt; h.y += h.vy * dt; h.ang += h.va * dt;
        if (h.y > H + h.r * 2.5) halves.splice(i, 1);
      }
      for (let i = parts.length - 1; i >= 0; i--) {
        const p = parts[i];
        p.life -= dt;
        if (p.life <= 0) { parts.splice(i, 1); continue; }
        p.vx *= p.drag; p.vy = p.vy * p.drag + p.g * dt;
        p.x += p.vx * dt; p.y += p.vy * dt; p.rot += p.vr * dt;
      }
      for (let i = texts.length - 1; i >= 0; i--) {
        const t = texts[i];
        t.life -= dt; t.y += t.vy * dt; t.vy *= 0.94;
        if (t.life <= 0) texts.splice(i, 1);
      }
      for (let i = rings.length - 1; i >= 0; i--) { const r = rings[i]; r.life -= dt; r.r += r.dr * dt * (r.life / r.max); if (r.life <= 0) rings.splice(i, 1); }
      for (let i = slashes.length - 1; i >= 0; i--) { slashes[i].life -= dt; if (slashes[i].life <= 0) slashes.splice(i, 1); }
      for (let i = marks.length - 1; i >= 0; i--) { marks[i].life -= dt; if (marks[i].life <= 0) marks.splice(i, 1); }
    }
    function pruneTrail(b) {
      const cut = realT - 0.13;
      while (b.pts.length && b.pts[0].t < cut) b.pts.shift();
    }
    function step(dt) {
      shake = Math.max(0, shake - dt * 60);
      flashA = Math.max(0, flashA - dt * 2.2);
      scoreBump = Math.max(0, scoreBump - dt * 4);
      timerPulse = Math.max(0, timerPulse - dt * 3);
      for (let i = 0; i < 3; i++) heartFx[i] = Math.max(0, heartFx[i] - dt * 1.6);
      for (const m of motes) { m.y -= m.sp * dt; if (m.y < -0.05) { m.y = 1.05; m.x = Math.random(); } }
      if (mode === 'paused') return;
      let sdt = dt;
      if (freeze > 0) { freeze -= dt; sdt = 0; }
      if (mode === 'count') {
        countT += dt;
        const st = Math.min(3, Math.floor(countT / STEP));
        if (st !== countStep) { countStep = st; if (st < 3) sfx('tick', { pitch: 1 + st * 0.18 }); }
        if (st >= 3) {
          mode = 'play'; goT = GO_T;
          sfx('whoosh'); sfx('perfect');
          if (!resumeRun) nextWave = elapsed + 0.35;
          resumeRun = false;
        }
      }
      if (goT > 0) goT -= dt;
      if (mode === 'play' && sdt > 0) updatePlay(sdt);
      if (mode === 'over') { overT += dt; if (overT > 1.5) showResults(); }
      if ((mode === 'menu' || mode === 'results') && sdt > 0) demoUpdate(sdt);
      if (sdt > 0 && mode !== 'count') physics(sdt);
      blades.forEach((b) => { if (b.chainN && realT - b.chainT > CHAIN_GAP) resolveChain(b); });
      if (ai.chainN && realT - ai.chainT > CHAIN_GAP) resolveChain(ai);
      pruneTrail(ai);
      blades.forEach(pruneTrail);
      fading = fading.filter((b) => { pruneTrail(b); return b.pts.length > 0; });
    }

    /* ---- render ---- */
    function glow(x, y, r, rgb, a) {
      const g = ctx.createRadialGradient(x, y, 0, x, y, r);
      g.addColorStop(0, 'rgba(' + rgb + ',' + a + ')'); g.addColorStop(1, 'rgba(' + rgb + ',0)');
      ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
    }
    function drawBg() {
      if (bg) ctx.drawImage(bg, 0, 0, W, H);
      const cx = W / 2, cy = H * 0.48, rr = Math.hypot(W, H);
      const n = 12, h0 = hue(0);
      ctx.save(); ctx.translate(cx, cy); ctx.rotate(realT * (frenzyOn ? 0.8 : 0.12));
      for (let i = 0; i < n; i++) {
        const a0 = (i / n) * TAU;
        ctx.fillStyle = hsl(h0 + i * 30, 100, 60, frenzyOn ? 0.09 : 0.045);
        ctx.beginPath(); ctx.moveTo(0, 0); ctx.arc(0, 0, rr, a0, a0 + (TAU / n) * 0.5); ctx.closePath(); ctx.fill();
      }
      ctx.restore();
      for (const m of motes) {
        ctx.fillStyle = hsl(h0 + m.h, 100, 70, 0.35);
        ctx.beginPath(); ctx.arc(m.x * W, m.y * H, m.s, 0, TAU); ctx.fill();
      }
    }
    function drawObjs() {
      const look = { x: lookX, y: lookY };
      for (const o of objs) {
        if (o.dead) continue;
        if (o.kind === 'bomb') {
          const pulse = 0.5 + 0.5 * Math.sin(realT * 14 + o.seed);
          glow(o.x, o.y, o.r * (1.7 + pulse * 0.5), '255,30,70', 0.35 + pulse * 0.35);
          ctx.save(); ctx.translate(o.x, o.y);
          ctx.strokeStyle = 'rgba(255,60,90,' + (0.5 + pulse * 0.5).toFixed(2) + ')'; ctx.lineWidth = 3;
          ctx.setLineDash([o.r * 0.35, o.r * 0.25]); ctx.lineDashOffset = -realT * 40;
          ctx.beginPath(); ctx.arc(0, 0, o.r * 1.18, 0, TAU); ctx.stroke(); ctx.setLineDash([]);
          ctx.rotate(o.rot * 0.35);
          const s = o.r * 2.3;
          ctx.drawImage(bombSprite(s), -s / 2, -s / 2, s, s);
          ctx.restore();
        } else if (o.kind === 'gold') {
          const pulse = 0.6 + 0.4 * Math.sin(realT * 10 + o.seed);
          glow(o.x, o.y, o.r * 2.2, '255,210,60', 0.55 * pulse);
          ctx.save(); ctx.translate(o.x, o.y); ctx.rotate(realT * 2);
          ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = 'rgba(255,220,90,0.28)';
          for (let i = 0; i < 6; i++) { ctx.rotate(TAU / 6); ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(o.r * 2.3, -o.r * 0.2); ctx.lineTo(o.r * 2.3, o.r * 0.2); ctx.closePath(); ctx.fill(); }
          ctx.restore();
          cookie(o.x, o.y, o.r, { skin: 'golden', rot: o.rot, simple: true });
        } else {
          if (o.frenzy) glow(o.x, o.y, o.r * 1.6, '255,43,214', 0.3);
          cookie(o.x, o.y, o.r, o.acc ? { rot: o.rot, accessories: true, look } : { rot: o.rot, simple: true });
        }
      }
    }
    function drawHalves() {
      for (const h of halves) {
        const p = h.skin === 'golden' ? GOLD_PAL : pal();
        const big = h.r * 2.8;
        ctx.save(); ctx.translate(h.x, h.y); ctx.rotate(h.ang);
        ctx.beginPath();
        if (h.side < 0) ctx.rect(-big, -big, big * 2, big); else ctx.rect(-big, 0, big * 2, big);
        ctx.clip();
        cookie(0, 0, h.r, h.skin ? { skin: h.skin, rot: h.inner, simple: true } : h.acc ? { rot: h.inner, accessories: true } : { rot: h.inner, simple: true });
        ctx.lineCap = 'round';
        ctx.strokeStyle = p.dark; ctx.lineWidth = h.r * 0.2;
        ctx.beginPath(); ctx.moveTo(-h.r * 0.95, 0); ctx.lineTo(h.r * 0.95, 0); ctx.stroke();
        ctx.strokeStyle = p.light; ctx.lineWidth = h.r * 0.09;
        ctx.beginPath(); ctx.moveTo(-h.r * 0.88, 0); ctx.lineTo(h.r * 0.88, 0); ctx.stroke();
        ctx.restore();
      }
    }
    function drawParts() {
      for (const p of parts) {
        const a = clamp(p.life / p.max, 0, 1);
        ctx.globalCompositeOperation = p.add ? 'lighter' : 'source-over';
        ctx.globalAlpha = p.add ? a : Math.min(1, a * 1.8);
        ctx.fillStyle = p.col;
        if (p.sq) {
          ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot);
          ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size * 0.8);
          ctx.restore();
        } else {
          ctx.beginPath(); ctx.arc(p.x, p.y, p.size * (p.add ? 0.4 + a * 0.6 : 1), 0, TAU); ctx.fill();
        }
      }
      ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
    }
    function drawSlashes() {
      ctx.globalCompositeOperation = 'lighter';
      for (const s of slashes) {
        const a = s.life / s.max;
        ctx.save(); ctx.translate(s.x, s.y); ctx.rotate(s.ang);
        ctx.fillStyle = 'rgba(255,255,255,' + a.toFixed(3) + ')';
        ctx.beginPath(); ctx.ellipse(0, 0, (s.len * (1.25 - a * 0.25)) / 2, R * 0.09 * a + 1, 0, 0, TAU); ctx.fill();
        ctx.restore();
      }
      ctx.globalCompositeOperation = 'source-over';
    }
    function drawRings() {
      for (const r of rings) {
        const a = r.life / r.max;
        ctx.globalAlpha = a;
        ctx.strokeStyle = r.col === 'rgb' ? hsl(hue(r.r), 100, 62) : r.col;
        ctx.lineWidth = r.w * a + 1;
        ctx.beginPath(); ctx.arc(r.x, r.y, r.r, 0, TAU); ctx.stroke();
      }
      ctx.globalAlpha = 1;
    }
    function drawMarks() {
      for (const m of marks) {
        const a = m.life / m.max, k = 1 - a;
        ctx.save(); ctx.globalAlpha = Math.min(1, a * 2);
        ctx.translate(m.x, H - R * 0.9); ctx.scale(k < 0.15 ? easeOutBack(k / 0.15) : 1, k < 0.15 ? easeOutBack(k / 0.15) : 1);
        outlined(ctx, 'X', 0, 0, R * 1.1, '#ff4d6d');
        ctx.restore();
      }
    }
    function drawBlade(b) {
      const pts = b.pts, n = pts.length;
      if (n < 2) return;
      const h0 = hue(0), wMax = clamp(R * 0.32, 9, 18);
      ctx.save();
      ctx.globalCompositeOperation = 'lighter'; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      for (let pass = 0; pass < 2; pass++) {
        for (let i = 1; i < n; i++) {
          const k = i / (n - 1);
          const p0 = pts[i - 1], p1 = pts[i];
          if (pass === 0) { ctx.strokeStyle = hsl(h0 + i * 14, 100, 60, 0.4 * k); ctx.lineWidth = 2 + wMax * 1.6 * k; }
          else { ctx.strokeStyle = hsl(h0 + i * 14, 100, 88, 0.95 * k); ctx.lineWidth = 1 + wMax * 0.45 * k; }
          ctx.beginPath(); ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.stroke();
        }
      }
      const tip = pts[n - 1];
      ctx.fillStyle = 'rgba(255,255,255,0.9)';
      ctx.beginPath(); ctx.arc(tip.x, tip.y, wMax * 0.35, 0, TAU); ctx.fill();
      ctx.restore();
    }
    function drawTexts() {
      const rm = reduced();
      for (const t of texts) {
        const age = t.max - t.life;
        const sc = rm ? 1 : age < 0.2 ? easeOutBack(age / 0.2) : 1;
        const a = t.life < t.max * 0.3 ? t.life / (t.max * 0.3) : 1;
        ctx.save(); ctx.globalAlpha = clamp(a, 0, 1); ctx.translate(t.x, t.y);
        if (t.big && !rm) ctx.rotate(Math.sin(age * 16) * 0.04);
        ctx.scale(sc, sc);
        outlined(ctx, t.str, 0, 0, t.size, t.col === 'rgb' ? hsl(hue(t.x * 0.3 + age * 240), 100, 66) : t.col);
        ctx.restore();
      }
    }
    function drawHud() {
      const top = 32;
      // timer bar
      const left = Math.max(0, ROUND - elapsed), frac = left / ROUND;
      ctx.fillStyle = 'rgba(0,0,0,0.4)'; ctx.fillRect(0, 0, W, 6);
      if (left < 10) ctx.fillStyle = '#ff4d6d';
      else { const gr = ctx.createLinearGradient(0, 0, W, 0); gr.addColorStop(0, hsl(hue(0), 100, 60)); gr.addColorStop(0.5, hsl(hue(120), 100, 60)); gr.addColorStop(1, hsl(hue(240), 100, 60)); ctx.fillStyle = gr; }
      ctx.fillRect(0, 0, W * frac, 6);
      // score
      const ss = clamp(W * 0.085, 26, 40) * (1 + scoreBump * 0.35);
      cookie(26, top, 14, { simple: true, rot: realT * 0.8 });
      outlined(ctx, String(score), 46, top + 1, ss, '#ffffff', 'left');
      // timer
      const s = Math.ceil(left);
      const ts = clamp(W * 0.065, 20, 28) * (1 + timerPulse * 0.35);
      const tstr = Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
      outlined(ctx, tstr, W / 2, top, ts, left < 10 ? '#ff4d6d' : '#ffffff');
      artDraw(ctx, 'ui:clock', W / 2 - ctx.measureText(tstr).width / 2 - ts * 0.6, top, ts * 0.95);
      if (frenzyOn) outlined(ctx, 'FRENZY !', W / 2, top + ts * 1.05, 18, hsl(hue(0), 100, 65));
      // hearts
      const hs = clamp(W * 0.07, 22, 30);
      for (let i = 0; i < LIVES; i++) {
        const x = W - 14 - hs * 0.55 - (LIVES - 1 - i) * hs * 1.22;
        const alive = i < lives, fx = heartFx[i];
        const sc = fx > 0 && !reduced() ? 1 + Math.sin(fx * Math.PI) * 0.7 : 1;
        ctx.save(); ctx.translate(x, top); ctx.scale(sc, sc);
        if (alive) glow(0, 0, hs * 0.9, '255,77,109', 0.35);
        if (!artDraw(ctx, alive ? 'ui:heart' : 'ui:heart_empty', 0, 0, hs * 1.3)) {
          heartPath(ctx, hs);
          ctx.lineJoin = 'round'; ctx.lineWidth = Math.max(3, hs * 0.2); ctx.strokeStyle = STROKE; ctx.stroke();
          ctx.fillStyle = alive ? '#ff4d6d' : 'rgba(70,50,110,0.9)';
          ctx.fill();
          if (alive) { ctx.fillStyle = 'rgba(255,255,255,0.6)'; ctx.beginPath(); ctx.ellipse(-hs * 0.2, -hs * 0.18, hs * 0.12, hs * 0.08, -0.6, 0, TAU); ctx.fill(); }
        }
        if (!alive && fx > 0) glow(0, 0, hs, '255,255,255', fx * 0.9);
        ctx.restore();
      }
    }
    function drawCountdown() {
      let label, k, idx;
      if (mode === 'count') { idx = clamp(countStep, 0, 2); label = String(3 - idx); k = (countT - idx * STEP) / STEP; }
      else { idx = 3; label = 'GO !'; k = 1 - goT / GO_T; }
      k = clamp(k, 0, 1);
      const rm = reduced();
      const sc = rm ? 1 : k < 0.35 ? easeOutBack(k / 0.35) : 1 + (k - 0.35) * 0.15;
      const a = k > 0.7 ? 1 - (k - 0.7) / 0.3 : 1;
      const size = Math.min(W, H) * (idx === 3 ? 0.24 : 0.34);
      const cy = H * 0.46;
      if (!rm) {
        ctx.globalAlpha = a * 0.6; ctx.strokeStyle = hsl(hue(idx * 90 + 60), 100, 65); ctx.lineWidth = 6 * (1 - k) + 1;
        ctx.beginPath(); ctx.arc(W / 2, cy, size * (0.6 + k * 0.9), 0, TAU); ctx.stroke(); ctx.globalAlpha = 1;
      }
      ctx.save(); ctx.globalAlpha = a; ctx.translate(W / 2, cy); ctx.scale(sc, sc);
      if (!rm) ctx.rotate((1 - k) * 0.12 * (idx % 2 ? 1 : -1));
      outlined(ctx, label, 0, 0, size, hsl(hue(idx * 90), 100, 65));
      ctx.restore();
      if (mode === 'count') outlined(ctx, resumeRun ? 'ON REPREND !' : 'GLISSE POUR TRANCHER', W / 2, cy + size * 0.75, clamp(W * 0.05, 15, 22), '#ffffff');
    }
    function drawPause() {
      ctx.fillStyle = 'rgba(11,6,32,0.6)'; ctx.fillRect(0, 0, W, H);
      outlined(ctx, 'PAUSE', W / 2, H * 0.44, clamp(W * 0.16, 44, 90), hsl(hue(0), 100, 66));
      outlined(ctx, 'Tape pour reprendre', W / 2, H * 0.44 + 60, clamp(W * 0.05, 16, 24), '#ffffff');
    }
    function render() {
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
      drawBg();
      ctx.save();
      if (shake > 0.3 && canShake()) ctx.translate(rand(-shake, shake), rand(-shake, shake));
      drawMarks();
      drawObjs();
      drawHalves();
      drawParts();
      drawSlashes();
      drawRings();
      fading.forEach(drawBlade); blades.forEach(drawBlade); drawBlade(ai);
      drawTexts();
      ctx.restore();
      if (mode === 'count' || mode === 'play' || mode === 'paused' || mode === 'over') drawHud();
      if (frenzyOn && mode === 'play') {
        ctx.globalAlpha = 0.55 + 0.3 * Math.sin(realT * 12);
        ctx.strokeStyle = hsl(hue(0), 100, 60); ctx.lineWidth = 10; ctx.strokeRect(5, 5, W - 10, H - 10);
        ctx.globalAlpha = 1;
      }
      if (mode === 'count' || goT > 0) drawCountdown();
      if (mode === 'paused') drawPause();
      if (flashA > 0.01 && !reduced()) {
        ctx.globalAlpha = Math.min(0.6, flashA);
        ctx.fillStyle = flashCol === 'rgb' ? hsl(hue(0), 100, 60) : flashCol;
        ctx.fillRect(0, 0, W, H); ctx.globalAlpha = 1;
      }
    }

    /* ---- DOM per-frame ---- */
    function dom(dt) {
      if (!menuEl.hidden || !resEl.hidden) wrap.style.setProperty('--h', Math.round(hue(0)));
      if (!menuEl.hidden) { const h0 = hue(0); titleSpans.forEach((s, i) => { s.style.color = hsl(h0 + i * 26, 100, 66); }); }
      if (resEl.hidden || !resData) return;
      resT += dt;
      const D0 = 0.3, CU = clamp(0.5 + resData.score * 0.008, 0.6, 1.4);
      const k = clamp((resT - D0) / CU, 0, 1);
      const v = Math.round(resData.score * easeOutCubic(k));
      if (v !== shownScore) {
        shownScore = v; rScore.textContent = String(v);
        if (resT - lastTickT > 0.055 && v > 0) { lastTickT = resT; sfx('tick', { pitch: 0.9 + k * 0.9, vol: 0.5 }); }
      }
      if (resStage === 0 && k >= 1) {
        resStage = 1; rScore.classList.add(P + '-bump'); sfx('pop');
        if (resData.isNewBest) { rRec.hidden = false; sfx('achievement'); confetti(70); flash('rgb', 0.2); }
      }
      if (resStage === 1 && resT > D0 + CU + 0.35) { resStage = 2; rRw.hidden = false; sfx('coin'); }
      if (resStage === 2 && resT > D0 + CU + 0.65) { resStage = 3; rBtns.classList.remove(P + '-wait'); }
      if (!rRec.hidden) { const h0 = hue(0); recSpans.forEach((s, i) => { s.style.color = hsl(h0 + i * 22, 100, 66); }); }
    }

    /* ---- loop ---- */
    function frame(ts) {
      if (destroyed) return;
      raf = requestAnimationFrame(frame);
      let dt = lastTs ? (ts - lastTs) / 1000 : 1 / 60;
      lastTs = ts;
      if (!(dt > 0)) dt = 0;
      if (dt > 0.05) dt = 0.05;
      realT += dt;
      step(dt);
      render();
      dom(dt);
    }

    /* ---- input ---- */
    function local(e) { return [e.clientX - cvRect.left, e.clientY - cvRect.top]; }
    function onDown(e) {
      e.preventDefault();
      if (mode === 'paused') { resume(); return; }
      cvRect = cv.getBoundingClientRect();
      try { cv.setPointerCapture(e.pointerId); } catch (_) { /* ok */ }
      const [x, y] = local(e);
      lookX = x; lookY = y;
      const old = blades.get(e.pointerId);
      if (old) fading.push(old);
      blades.set(e.pointerId, { ai: false, pts: [{ x, y, t: realT }], chainN: 0, chainT: 0, chainX: x, chainY: y, lastX: x, lastY: y, lastT: e.timeStamp / 1000 });
    }
    function onMove(e) {
      const b = blades.get(e.pointerId);
      const list = b && e.getCoalescedEvents ? e.getCoalescedEvents() : null;
      const evs = list && list.length ? list : [e];
      for (const ev of evs) {
        const [x, y] = local(ev);
        lookX = x; lookY = y;
        if (b) bladeTo(b, x, y, ev.timeStamp / 1000);
      }
    }
    function onUp(e) {
      const b = blades.get(e.pointerId);
      if (!b) return;
      blades.delete(e.pointerId);
      resolveChain(b);
      fading.push(b);
    }
    function onKey(e) {
      if (destroyed) return;
      const k = e.key;
      if (k === 'Enter') {
        if (mode === 'menu' || (mode === 'results' && resStage >= 3)) { e.preventDefault(); startRun(); }
        else if (mode === 'paused') { e.preventDefault(); resume(); }
      } else if ((k === ' ' || k === 'p' || k === 'P') && mode === 'paused') { e.preventDefault(); resume(); }
      else if ((k === 'p' || k === 'P') && mode === 'play') pause();
    }
    function onVis() { if (document.hidden) pause(); }
    const onPlay = () => startRun();
    const onAgain = () => { if (resStage >= 2) startRun(); };
    const onQuit = () => { try { api.close(); } catch (e) { /* ignore */ } };
    const onCtx = (e) => e.preventDefault();

    cv.addEventListener('pointerdown', onDown);
    cv.addEventListener('pointermove', onMove);
    cv.addEventListener('pointerup', onUp);
    cv.addEventListener('pointercancel', onUp);
    cv.addEventListener('lostpointercapture', onUp);
    cv.addEventListener('contextmenu', onCtx);
    playBtn.addEventListener('click', onPlay);
    againBtn.addEventListener('click', onAgain);
    quitBtn.addEventListener('click', onQuit);
    window.addEventListener('keydown', onKey);
    document.addEventListener('visibilitychange', onVis);
    const ro = typeof ResizeObserver === 'function' ? new ResizeObserver(() => resize()) : null;
    if (ro) ro.observe(root);
    else window.addEventListener('resize', resize);
    resize();
    raf = requestAnimationFrame(frame);

    function destroy() {
      if (destroyed) return;
      destroyed = true;
      cancelAnimationFrame(raf);
      if (ro) ro.disconnect(); else window.removeEventListener('resize', resize);
      window.removeEventListener('keydown', onKey);
      document.removeEventListener('visibilitychange', onVis);
      cv.removeEventListener('pointerdown', onDown);
      cv.removeEventListener('pointermove', onMove);
      cv.removeEventListener('pointerup', onUp);
      cv.removeEventListener('pointercancel', onUp);
      cv.removeEventListener('lostpointercapture', onUp);
      cv.removeEventListener('contextmenu', onCtx);
      playBtn.removeEventListener('click', onPlay);
      againBtn.removeEventListener('click', onAgain);
      quitBtn.removeEventListener('click', onQuit);
      wrap.remove();
      objs = halves = parts = texts = rings = slashes = marks = queue = fading = [];
      blades.clear(); spriteCache.clear(); bg = null;
      cv.width = cv.height = 0;
    }
    return { destroy };
  }

  const def = {
    id: 'ninja',
    name: 'Cookie Ninja',
    color: '#ff2bd6',
    tagline: 'Tranche les cookies, évite les brocolis.',
    howto: 'Glisse pour trancher tes cookies (plusieurs d\'un coup = combo). Touche pas aux brocolis et n\'en laisse pas tomber !',
    mount,
  };
  if (typeof CO.registerMinigame === 'function') CO.registerMinigame(def);
  else (CO._pendingMinigames = CO._pendingMinigames || []).push(def);
})();
