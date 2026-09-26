/* COOKIE OVERDRIVE — mini-jeu « Flappy Cookie » (id: 'flappy')
 * Flappy-like : TON cookie (skin + accessoires) vole entre des verres de lait géants.
 * Tape / clic / Espace / ↑ pour battre des ailes. Pépites et gemmes = +1.
 * Aucun emoji affiché : toutes les images viennent de CO.art (js/art.js) avec fallbacks vectoriels.
 * Contrat : SPEC.md › « Minigame contract ». Tout est créé dans mount() et retiré dans destroy().
 * Monde en « unités » : 100 u = hauteur du root (u = H/100 px), physique indépendante de la résolution.
 */
(function () {
  'use strict';
  const CO = (window.CO = window.CO || {});

  const FONT = '"Lilita One", "Arial Rounded MT Bold", "Trebuchet MS", sans-serif';
  const MONO = '"Chakra Petch", ui-monospace, monospace';
  const STROKE = '#1a0b33';
  const TAU = Math.PI * 2;
  const STEP = 0.62, GO_T = 0.7;
  const G = 150;          // gravité (u/s²)
  const FLAP = -46;       // impulsion (u/s)
  const VMAX = 78;        // vitesse de chute max
  const GROUND = 90;      // haut du sol (u)
  const BR = 4.3;         // rayon visuel du cookie (u)
  const HR = 3.3;         // rayon de collision (plus petit = fair-play)
  const PW = 14;          // largeur d'un verre (u)
  const DEF_PAL = { base: '#d99a4e', dark: '#a9652a', light: '#f3c783', chip: '#4a2511', chipHi: '#7a4424', rim: '#8a5220' };
  const CHIPS = [[-0.4, -0.3], [0.35, -0.2], [0, 0.35], [-0.2, 0.1], [0.4, 0.4]];

  const Q_DEATH = ['skill issue', 'RIP le cookie', 'cheh', 'le lait a gagné', 'même pas mal ?', 'aura -1000'];
  const Q_AURA = ['W', 'TROP FORT', 'NO CAP', 'INSANE', 'MAIN CHARACTER', 'CHEF !', 'IL VOLE !!'];

  const rand = (a, b) => a + Math.random() * (b - a);
  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
  const lerp = (a, b, t) => a + (b - a) * t;
  const pick = (a) => a[(Math.random() * a.length) | 0];
  const easeOutBack = (t) => { const c = 1.70158; t -= 1; return 1 + (c + 1) * t * t * t + c * t * t; };
  const easeOutCubic = (t) => 1 - Math.pow(1 - t, 3);
  const hsl = (h, s, l, a) => 'hsla(' + Math.round(((h % 360) + 360) % 360) + ',' + s + '%,' + l + '%,' + (a == null ? 1 : a) + ')';

  const gapFor = (s) => Math.max(24, 34 - s * 0.22);
  const speedFor = (s) => Math.min(44, 30 + s * 0.33);
  const spacingFor = (s) => Math.max(37, 45 - s * 0.16);

  function quipFor(score) {
    if (score >= 50) return 'Oiseau légendaire. Aura infinie.';
    if (score >= 25) return 'W énorme, t\'es chaud !';
    if (score >= 10) return 'Pas mal du tout, continue !';
    if (score >= 3) return 'Ça vole… à peu près.';
    return 'skill issue (c\'est dur, on sait)';
  }

  const P = 'cf';
  const CSS = `
.${P}-wrap{position:absolute;inset:0;overflow:hidden;background:#0b0620;color:#fff6fe;font-family:var(--f-body,'Fredoka',system-ui,sans-serif);-webkit-user-select:none;user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:transparent}
.${P}-wrap [hidden]{display:none!important}
.${P}-cv{position:absolute;inset:0;width:100%;height:100%;display:block;touch-action:none;cursor:pointer}
.${P}-scr{position:absolute;inset:0;box-sizing:border-box;display:flex;flex-direction:column;align-items:center;justify-content:space-between;gap:10px;padding:clamp(10px,3vh,26px) 16px clamp(14px,3.5vh,30px);pointer-events:none}
.${P}-scr>*{pointer-events:auto}
.${P}-top{display:flex;flex-direction:column;align-items:center;gap:2px;text-align:center}
.${P}-emo{display:flex;justify-content:center;animation:${P}-bob 1.2s ease-in-out infinite}
.${P}-hero{display:block;width:clamp(48px,10vh,84px);height:clamp(48px,10vh,84px);object-fit:contain;filter:drop-shadow(0 0 14px rgba(31,244,255,.85))}
.${P}-ic{display:inline-block;width:1.3em;height:1.3em;object-fit:contain;vertical-align:-0.28em;flex:none}
.${P}-noart{display:none!important}
.${P}-it{display:inline-flex;align-items:center;gap:.35em}
.${P}-title{margin:0;font-weight:400;font-size:clamp(34px,11vw,84px);line-height:1;white-space:nowrap}
.${P}-title span,.${P}-rec span{display:inline-block;animation:${P}-wave 1.6s ease-in-out infinite}
.${P}-sub{margin-top:6px;font-family:var(--f-mono,monospace);font-weight:700;font-size:clamp(11px,3.3vw,15px);letter-spacing:.1em;text-transform:uppercase;color:#ff2bd6;text-shadow:0 0 10px rgba(255,43,214,.7)}
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
@keyframes ${P}-bob{0%,100%{transform:translateY(0) rotate(-8deg)}50%{transform:translateY(-8px) rotate(8deg)}}
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
  // Fallback milk-glass icon (vector) while CO.art has no 'item:milk'. Centered at 0,0 in a s×s box.
  function paintMilk(g, s) {
    const k = s / 2, lw = Math.max(2, s * 0.06);
    const body = () => { g.beginPath(); g.moveTo(-k * 0.55, -k * 0.85); g.lineTo(k * 0.55, -k * 0.85); g.lineTo(k * 0.42, k * 0.9); g.lineTo(-k * 0.42, k * 0.9); g.closePath(); };
    g.lineJoin = 'round';
    body(); g.fillStyle = 'rgba(200,235,255,0.35)'; g.fill();
    g.beginPath(); g.moveTo(-k * 0.52, -k * 0.42); g.quadraticCurveTo(-k * 0.25, -k * 0.56, 0, -k * 0.44); g.quadraticCurveTo(k * 0.25, -k * 0.32, k * 0.52, -k * 0.44);
    g.lineTo(k * 0.42, k * 0.9); g.lineTo(-k * 0.42, k * 0.9); g.closePath(); g.fillStyle = '#ffffff'; g.fill();
    body(); g.lineWidth = lw; g.strokeStyle = STROKE; g.stroke();
    g.fillStyle = 'rgba(31,244,255,0.55)'; g.fillRect(-k * 0.36, -k * 0.7, k * 0.1, k * 1.45);
  }
  function circRect(cx, cy, r, x, y, w, h) {
    const nx = clamp(cx, x, x + w), ny = clamp(cy, y, y + h);
    const dx = cx - nx, dy = cy - ny;
    return dx * dx + dy * dy < r * r;
  }

  /* ═════════════════════════ MOUNT ═════════════════════════ */
  function mount(root, api) {
    const S = () => { try { return api.settings() || {}; } catch (e) { return {}; } };
    const reduced = () => !!S().reducedMotion;
    const plevel = () => { const p = S().particles; return p === 0 || p === 1 ? p : 2; };
    const canShake = () => S().shake !== false && !reduced();
    const mult = () => [0.3, 0.6, 1][plevel()] * (reduced() ? 0.6 : 1);
    const maxParts = () => [70, 200, 420][plevel()];
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
    let W = 0, H = 0, dpr = 1, u = 6, WW = 60, BX = 18, cvRect = { left: 0, top: 0 };
    let raf = 0, lastTs = 0, realT = 0, destroyed = false;
    let mode = 'menu';                 // menu | count | play | paused | dying | results
    let resumeRun = false, countT = 0, countStep = -1, goT = 0;
    const bird = { y: 45, vy: 0, rot: 0, flap: 0, alive: true, vis: true };
    let pipes = [], parts = [], texts = [], rings = [], trail = [];
    let dist = 0, speed = 30, pipeIdx = 0, trailAcc = 0;
    let score = 0, items = 0, passed = 0, ended = false, bestAtStart = 0, recAnnounced = false;
    let dieT = 0, crumbled = false, deathKind = 'verre';
    let shake = 0, flashA = 0, flashCol = '#fff', freeze = 0, scoreBump = 0;
    let sky = null, far = null, near = null, nearRoofs = [], stars = [];
    let cookieFail = false;
    let resT = 0, resStage = 0, resData = null, shownScore = -1, lastTickT = 0, recSpans = [];
    const diff = () => (mode === 'play' || mode === 'dying' || mode === 'paused' || mode === 'count' ? score : 0);

    // Title picture: CO.art 'mg:<id>' if available, else the player's own cookie (with accessories).
    function heroArt(name) {
      const fallback = () => {
        const c = el('canvas', P + '-hero'); c.width = c.height = 144;
        const g = c.getContext('2d');
        try { api.drawCookie(g, 72, 72, 54, { accessories: true, rot: 0.2 }); } catch (e) { g.fillStyle = pal().base; g.beginPath(); g.arc(72, 72, 54, 0, TAU); g.fill(); }
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
      '<div class="' + P + '-sub">Fais voler ton cookie entre les verres de lait</div></div>' +
      '<div class="' + P + '-bot"><div class="' + P + '-rules"></div><div class="' + P + '-best"></div>' +
      '<button class="btn big green ' + P + '-play" type="button"></button></div>');
    menuEl.querySelector('.' + P + '-emo').appendChild(heroArt('mg:flappy'));
    const titleSpans = letters(menuEl.querySelector('.' + P + '-title'), 'FLAPPY COOKIE');
    const rulesEl = menuEl.querySelector('.' + P + '-rules');
    [['ui:tap', 'Tape / Espace = battre des ailes'], ['item:milk', 'Touche pas les verres de lait', paintMilk], ['ui:gem', 'Pépites et gemmes = +1 bonus'], ['ui:fire', 'Tous les 10 = AURA +10']]
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

    /* ---- sizing + pre-rendered parallax layers ---- */
    function resize() {
      const rc = root.getBoundingClientRect();
      const w = Math.max(160, Math.round(rc.width)), h = Math.max(200, Math.round(rc.height));
      const d = Math.min(window.devicePixelRatio || 1, plevel() < 2 ? 1.5 : 2);
      cvRect = cv.getBoundingClientRect();
      if (w === W && h === H && d === dpr && sky) return;
      W = w; H = h; dpr = d;
      cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
      u = H / 100; WW = W / u; BX = Math.min(WW * 0.3, 40);
      buildBg();
    }
    function mkCanvas(w, h) {
      const c = document.createElement('canvas');
      c.width = Math.max(1, Math.round(w * dpr)); c.height = Math.max(1, Math.round(h * dpr));
      const g = c.getContext('2d'); g.scale(dpr, dpr);
      return [c, g];
    }
    function buildCity(tw, th, minW, maxW, minH, maxH, body, winA, roofs) {
      const [c, g] = mkCanvas(tw, th);
      const wins = ['#ff6ad5', '#1ff4ff', '#ffe066', '#b6ff3b', '#ffffff'];
      let x = 0;
      while (x < tw) {
        const bw = Math.min(rand(minW, maxW) * u, tw - x);
        const bh = rand(minH, maxH) * u;
        g.fillStyle = body; g.fillRect(x, th - bh, bw + 0.5, bh);
        if (Math.random() < 0.25 && bw > 3 * u) { g.fillRect(x + bw * 0.45, th - bh - 3 * u, Math.max(1.5, u * 0.3), 3 * u); }
        const cw = Math.max(1.5, u * 0.75), ch = Math.max(2, u * 1.0);
        for (let wy = th - bh + u * 1.5; wy < th - u; wy += u * 2.4) {
          for (let wx = x + u * 1.1; wx < x + bw - u; wx += u * 1.9) {
            if (Math.random() < 0.32) { g.globalAlpha = winA * rand(0.5, 1); g.fillStyle = pick(wins); g.fillRect(wx, wy, cw, ch); }
          }
        }
        g.globalAlpha = 1;
        if (roofs) roofs.push({ x, w: bw, h: bh });
        x += bw + rand(0, 1.2) * u;
      }
      return c;
    }
    function buildBg() {
      const hz = GROUND * u;
      let g;
      [sky, g] = mkCanvas(W, hz);
      const gr = g.createLinearGradient(0, 0, 0, hz);
      gr.addColorStop(0, '#07021a'); gr.addColorStop(0.4, '#1c0747'); gr.addColorStop(0.78, '#5a137a'); gr.addColorStop(1, '#ff4fa3');
      g.fillStyle = gr; g.fillRect(0, 0, W, hz);
      stars = Array.from({ length: Math.round(W * hz / 5200) + 20 }, () => ({ x: rand(0, W), y: rand(0, hz * 0.62), s: rand(0.6, 1.8), p: rand(0, TAU) }));
      g.fillStyle = '#ffffff';
      for (const s of stars) { g.globalAlpha = rand(0.2, 0.7); g.fillRect(s.x, s.y, s.s, s.s); }
      g.globalAlpha = 1;
      // retro sun (with cut stripes, built on its own layer)
      const sr = Math.min(W, H) * 0.2, scx = W * 0.72, scy = hz - H * 0.17;
      const glow = g.createRadialGradient(scx, scy, sr * 0.6, scx, scy, sr * 2);
      glow.addColorStop(0, 'rgba(255,90,180,0.45)'); glow.addColorStop(1, 'rgba(255,90,180,0)');
      g.fillStyle = glow; g.fillRect(scx - sr * 2, scy - sr * 2, sr * 4, sr * 4);
      const [sun, sg] = mkCanvas(sr * 2 + 4, sr * 2 + 4);
      const sgr = sg.createLinearGradient(0, 0, 0, sr * 2);
      sgr.addColorStop(0, '#fff27a'); sgr.addColorStop(0.55, '#ff8a3d'); sgr.addColorStop(1, '#ff2bd6');
      sg.fillStyle = sgr; sg.beginPath(); sg.arc(sr + 2, sr + 2, sr, 0, TAU); sg.fill();
      sg.globalCompositeOperation = 'destination-out';
      for (let i = 0; i < 7; i++) { const yy = sr + 2 + sr * (0.12 + i * 0.13); sg.fillRect(0, yy, sr * 2 + 4, 1 + i * sr * 0.018); }
      g.drawImage(sun, scx - sr - 2, scy - sr - 2, sr * 2 + 4, sr * 2 + 4);
      // cities (tileable strips)
      const fw = Math.ceil(Math.max(W, 420)), nw = Math.ceil(Math.max(W, 520));
      far = { c: buildCity(fw, 34 * u, 5, 11, 8, 26, '#230c4f', 0.45, null), w: fw, h: 34 * u };
      nearRoofs = [];
      near = { c: buildCity(nw, 48 * u, 8, 16, 12, 40, '#12052c', 0.85, nearRoofs), w: nw, h: 48 * u };
    }

    /* ---- cookie painter (api.drawCookie with safe fallback) ---- */
    function fallbackCookie(x, y, r, o) {
      const p = pal();
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
          console.warn('[flappy] api.drawCookie a planté, fallback local', e);
          cv.width = cv.width;
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
      texts.push({ str, x, y, size, col, life: life || 0.8, max: life || 0.8, vy: big ? -u * 2 : -u * 7, big: !!big });
    }
    function flash(col, a) { if (reduced()) return; flashCol = col; flashA = Math.max(flashA, a); }
    function bumpShake(n) { shake = Math.max(shake, n); }
    function spark(x, y, n, cols, spd, add, g) {
      n = Math.round(n * mult());
      for (let i = 0; i < n && parts.length < maxParts(); i++) {
        const a = rand(0, TAU), sp = rand(0.3, 1) * spd, l = rand(0.35, 0.8);
        parts.push({ x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, g: g == null ? H * 0.4 : g, drag: 0.9, life: l, max: l, size: rand(2, 4.5), col: pick(cols), sq: false, rot: 0, vr: 0, add: add !== false, grow: 0 });
      }
    }
    function puff() {
      if (plevel() === 0) return;
      const x = (BX - BR * 0.8) * u, y = (bird.y + BR * 0.4) * u;
      for (let i = 0; i < 3; i++) {
        const l = rand(0.28, 0.42);
        parts.push({ x: x + rand(-2, 2), y: y + rand(-3, 3), vx: -rand(3, 9) * u, vy: rand(1, 6) * u, g: 0, drag: 0.9, life: l, max: l, size: BR * u * rand(0.22, 0.34), col: '#ffffff', sq: false, rot: 0, vr: 0, add: false, grow: 1.6 });
      }
    }
    function confetti(n) {
      n = Math.round(n * mult());
      for (let i = 0; i < n && parts.length < maxParts(); i++) {
        const l = rand(1.6, 2.8);
        parts.push({ x: rand(0, W), y: rand(-40, -5), vx: rand(-40, 40), vy: rand(60, 200), g: H * 0.25, drag: 0.995, life: l, max: l, size: rand(5, 9), col: hsl(rand(0, 360), 100, 62), sq: true, rot: rand(0, TAU), vr: rand(-8, 8), add: false, grow: 0 });
      }
    }

    /* ---- world ---- */
    function makePipe(x, prevGy, first) {
      const gap = gapFor(diff());
      const lo = gap / 2 + 8, hi = GROUND - gap / 2 - 6;
      let gy = first ? rand(38, 52) : rand(lo, hi);
      gy = clamp(clamp(gy, prevGy - 24, prevGy + 24), lo, hi);
      const item = !first && Math.random() < 0.42 ? { kind: Math.random() < 0.3 ? 'gem' : 'chip', dy: rand(-0.22, 0.22) * gap, got: false, seed: rand(0, TAU) } : null;
      return { x, gy, gap, passed: false, hoff: (pipeIdx++ * 47) % 360, pop: 1, delay: 0, item, wob: rand(0, TAU) };
    }
    function ensurePipes() {
      let last = pipes.length ? pipes[pipes.length - 1] : null;
      let x = last ? last.x : BX + 46 - spacingFor(diff());
      let gy = last ? last.gy : 45;
      let guard = 0;
      while (x < WW + 4 && guard++ < 40) {
        x += spacingFor(diff());
        const p = makePipe(x, gy, !last);
        pipes.push(p); gy = p.gy; last = p;
      }
    }
    function resetWorld(popIn) {
      pipes = []; trail = []; dist = 0; pipeIdx = 0;
      bird.y = 45; bird.vy = 0; bird.rot = 0; bird.flap = 0; bird.alive = true; bird.vis = true;
      ensurePipes();
      if (popIn) pipes.forEach((p, i) => { p.pop = 0; p.delay = 0.15 + i * 0.12; });
    }
    function scroll(dt) {
      dist += speed * dt;
      for (const p of pipes) p.x -= speed * dt;
      for (const t of trail) t.x -= speed * dt;
      while (pipes.length && pipes[0].x + PW < -8) pipes.shift();
      ensurePipes();
    }
    function birdPhysics(dt) {
      bird.vy = Math.min(VMAX, bird.vy + G * dt);
      bird.y += bird.vy * dt;
      if (bird.y < BR) { bird.y = BR; if (bird.vy < 0) bird.vy = 0; }
      const target = clamp(bird.vy / 55, -0.45, 1.2);
      bird.rot += (target - bird.rot) * Math.min(1, dt * 9);
      trailAcc += dt;
      if (trailAcc > 1 / 50) { trailAcc = 0; trail.push({ x: BX, y: bird.y }); if (trail.length > 12) trail.shift(); }
    }
    function flap(demo) {
      bird.vy = FLAP; bird.flap = 1;
      puff();
      if (!demo) sfx('jump', { pitch: rand(0.95, 1.12), vol: 0.6 });
    }
    function updatePlay(dt) {
      speed = speedFor(score);
      birdPhysics(dt);
      scroll(dt);
      if (bird.y + HR >= GROUND) { bird.y = GROUND - HR; die('sol'); return; }
      for (const p of pipes) {
        if (p.x > BX + HR || p.x + PW < BX - HR) continue;
        const top = p.gy - p.gap / 2, bot = p.gy + p.gap / 2;
        if (circRect(BX, bird.y, HR, p.x, -60, PW, top + 60) || circRect(BX, bird.y, HR, p.x, bot, PW, GROUND - bot + 20)) { die('verre'); return; }
      }
      for (const p of pipes) {
        if (!p.passed && p.x + PW / 2 < BX) { p.passed = true; onPass(p); }
        const it = p.item;
        if (it && !it.got) {
          const ix = p.x + PW / 2, iy = p.gy + it.dy + Math.sin(realT * 3 + it.seed) * 1.2;
          if (Math.hypot(ix - BX, iy - bird.y) < HR + 3.4) collect(p, ix, iy);
        }
      }
    }
    function updateDemo(dt) {
      speed = 28;
      const next = pipes.find((p) => p.x + PW > BX - HR - 1);
      const target = next ? next.gy + 3 : 45;
      if (bird.y > target && bird.vy > -4) flap(true);
      birdPhysics(dt);
      bird.y = Math.min(bird.y, GROUND - BR);
      scroll(dt);
      for (const p of pipes) if (!p.passed && p.x + PW / 2 < BX) p.passed = true;
    }
    function addScore(n) {
      score += n; scoreBump = 1;
      if (!recAnnounced && bestAtStart > 0 && score > bestAtStart) {
        recAnnounced = true;
        addText('NOUVEAU RECORD !', W / 2, H * 0.27, u * 6, 'rgb', 1.4, true);
        sfx('achievement');
      }
      if (score % 10 === 0) aura();
    }
    function onPass(p) {
      passed++;
      sfx('pop'); sfx('coin', { pitch: 1 + (score % 10) * 0.06 });
      addText('+1', BX * u, (bird.y - 9) * u, u * 6, '#ffffff', 0.7);
      rings.push({ x: (p.x + PW / 2) * u, y: p.gy * u, r: 2 * u, dr: 40 * u, life: 0.35, max: 0.35, col: hsl(hue(p.hoff), 100, 65), w: 5 });
      addScore(1);
    }
    function collect(p, ix, iy) {
      p.item.got = true; items++;
      const gem = p.item.kind === 'gem';
      sfx('coin', { pitch: 1.6 });
      spark(ix * u, iy * u, 16, gem ? ['#1ff4ff', '#ffffff', '#b16bff'] : ['#ffc93c', '#ffffff', '#7a4424'], u * 22);
      addText(gem ? '+1 GEMME' : '+1 PÉPITE', ix * u, (iy - 6) * u, u * 4.6, gem ? '#1ff4ff' : '#ffc93c', 0.8);
      addScore(1);
    }
    function aura() {
      addText('AURA +10 !', W / 2, H * 0.38, u * 11, 'rgb', 1.4, true);
      addText(pick(Q_AURA), W / 2, H * 0.38 + u * 9, u * 6, '#ffc93c', 1.2);
      flash('rgb', 0.35); sfx('levelup'); bumpShake(6);
      spark(BX * u, bird.y * u, 30, [hsl(hue(0), 100, 65), hsl(hue(120), 100, 65), hsl(hue(240), 100, 65), '#ffffff'], u * 30);
      rings.push({ x: BX * u, y: bird.y * u, r: BR * u, dr: 90 * u, life: 0.6, max: 0.6, col: 'rgb', w: 9 });
    }
    function die(kind) {
      if (!bird.alive) return;
      bird.alive = false; deathKind = kind; mode = 'dying'; dieT = 0; crumbled = false;
      freeze = 0.12; bumpShake(16); flash('#ff3050', 0.4);
      sfx('hit');
    }
    function crumble() {
      crumbled = true; bird.vis = false;
      const x = BX * u, y = bird.y * u, r = BR * u, p = pal();
      const cols = [p.base, p.dark, p.light, p.chip, p.chip, p.chipHi];
      const n = Math.round(48 * mult());
      for (let i = 0; i < n && parts.length < maxParts(); i++) {
        const a = rand(0, TAU), sp = rand(8, 38) * u, l = rand(0.7, 1.3);
        parts.push({ x: x + Math.cos(a) * r * 0.5, y: y + Math.sin(a) * r * 0.5, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 18 * u, g: 140 * u, drag: 0.99, life: l, max: l, size: rand(0.1, 0.24) * r, col: pick(cols), sq: Math.random() < 0.6, rot: rand(0, TAU), vr: rand(-12, 12), add: false, grow: 0 });
      }
      if (deathKind === 'verre') {
        for (let i = 0; i < Math.round(14 * mult()); i++) {
          const a = rand(-Math.PI, 0), sp = rand(10, 30) * u, l = rand(0.5, 0.9);
          parts.push({ x: x + r * 0.8, y, vx: Math.cos(a) * sp * 0.6 - 6 * u, vy: Math.sin(a) * sp, g: 120 * u, drag: 0.99, life: l, max: l, size: rand(0.12, 0.22) * r, col: '#ffffff', sq: false, rot: 0, vr: 0, add: false, grow: 0 });
        }
      }
      rings.push({ x, y, r: r * 0.6, dr: 50 * u, life: 0.45, max: 0.45, col: '#ffffff', w: 7 });
      addText(deathKind === 'sol' ? 'CRASH !' : 'SPLASH !', x + r, y - r * 2, u * 8, '#ff4d6d', 1.2, true);
      addText(pick(Q_DEATH), W / 2, H * 0.3, u * 6, '#ffffff', 1.3, true);
      sfx('lose'); bumpShake(10);
    }

    /* ---- flow ---- */
    function startRun() {
      if (mode !== 'menu' && mode !== 'results') return;
      if (document.activeElement && wrap.contains(document.activeElement)) document.activeElement.blur();
      menuEl.hidden = true; resEl.hidden = true;
      score = 0; items = 0; passed = 0; ended = false; bestAtStart = bestNow(); recAnnounced = false;
      parts = []; texts = []; rings = [];
      freeze = 0; shake = 0; flashA = 0;
      mode = 'count'; countT = 0; countStep = -1; goT = 0; resumeRun = false;
      resetWorld(true);
      wrap.classList.toggle(P + '-rm', reduced());
      sfx('pop');
    }
    function pause() { if (mode === 'play') mode = 'paused'; }
    function resume() { if (mode !== 'paused') return; mode = 'count'; countT = 0; countStep = -1; resumeRun = true; }
    function showResults() {
      if (mode === 'results') return;
      mode = 'results';
      const sc = score;
      const bestBefore = bestNow();
      let unit = 25;
      try { unit = api.unit() || 25; } catch (e) { /* stub */ }
      const cookies = Math.round(unit * sc * 0.35);
      const gems = sc >= 50 ? 8 : sc >= 25 ? 3 : sc >= 10 ? 1 : 0;
      let r = null;
      if (!ended) {
        ended = true;
        try { r = api.end({ score: sc, cookies, gems }); } catch (e) { console.error('[flappy] api.end', e); }
      }
      r = Object.assign({ cookies, gems, best: Math.max(bestBefore, sc), isNewBest: sc > bestBefore }, r || {});
      resData = { score: sc, cookies: r.cookies, gems: r.gems, best: r.best, isNewBest: !!r.isNewBest && sc > 0 };
      rHead.textContent = '';
      if (deathKind === 'sol') iconText(rHead, 'ui:skull', 'CRASH !'); else iconText(rHead, 'item:milk', 'SPLASH !', null, paintMilk);
      rQuip.textContent = quipFor(sc);
      rScore.textContent = '0'; rScore.classList.remove(P + '-bump'); shownScore = -1;
      rRec.hidden = true; recSpans = letters(rRec, 'NOUVEAU RECORD !');
      rBest.textContent = ''; iconText(rBest, 'ui:trophy', 'Record : ' + fmt(resData.best));
      rStats.textContent = '';
      iconText(rStats, 'item:milk', passed + (passed > 1 ? ' verres passés' : ' verre passé'), null, paintMilk);
      iconText(rStats, 'ui:gem', items + ' bonus');
      rRw.textContent = '';
      const pc = el('span', P + '-pill');
      pc.append('+' + fmt(resData.cookies), artImg('ui:cookie', P + '-ic'));
      rRw.appendChild(pc);
      if (resData.gems > 0) {
        const pg = el('span', P + '-pill gem'); pg.append('+' + resData.gems, artImg('ui:gem', P + '-ic')); rRw.appendChild(pg);
      } else {
        const ph = el('span', P + '-pill hint'); ph.append(artImg('ui:gem', P + '-ic'), sc < 10 ? '1 gemme dès 10 pts' : sc < 25 ? '3 gemmes dès 25 pts' : '8 gemmes dès 50 pts'); rRw.appendChild(ph);
      }
      rRw.hidden = true;
      rBtns.classList.add(P + '-wait');
      wrap.classList.toggle(P + '-rm', reduced());
      resEl.hidden = false;
      resT = 0; resStage = 0; lastTickT = 0;
      resetWorld(false);
    }

    /* ---- step ---- */
    function step(dt) {
      shake = Math.max(0, shake - dt * 55);
      flashA = Math.max(0, flashA - dt * 2.2);
      scoreBump = Math.max(0, scoreBump - dt * 4);
      bird.flap = Math.max(0, bird.flap - dt * 4);
      if (mode === 'paused') return;
      let sdt = dt;
      if (freeze > 0) { freeze -= dt; sdt = 0; }
      if (mode === 'count') {
        countT += dt;
        const st = Math.min(3, Math.floor(countT / STEP));
        if (st !== countStep) { countStep = st; if (st < 3) sfx('tick', { pitch: 1 + st * 0.18 }); }
        if (!resumeRun) { bird.y = 45 + Math.sin(realT * 5) * 1.2; bird.vy = 0; bird.rot = Math.sin(realT * 5) * 0.08; }
        for (const p of pipes) { if (p.delay > 0) p.delay -= dt; else p.pop = Math.min(1, p.pop + dt * 2.6); }
        if (st >= 3) {
          mode = 'play'; goT = GO_T; resumeRun = false;
          pipes.forEach((p) => { p.pop = 1; p.delay = 0; });
          flap(true); bird.vy = FLAP * 0.85;
          sfx('whoosh'); sfx('perfect');
        }
      }
      if (goT > 0) goT -= dt;
      if (mode === 'play' && sdt > 0) updatePlay(sdt);
      if (mode === 'dying') {
        if (freeze <= 0 && !crumbled) crumble();
        dieT += dt;
        if (dieT > 1.35) showResults();
      }
      if ((mode === 'menu' || mode === 'results') && sdt > 0) updateDemo(sdt);
      if (sdt > 0 && mode !== 'count') {
        for (let i = parts.length - 1; i >= 0; i--) {
          const p = parts[i];
          p.life -= sdt;
          if (p.life <= 0) { parts.splice(i, 1); continue; }
          p.vx *= p.drag; p.vy = p.vy * p.drag + p.g * sdt;
          p.x += p.vx * sdt; p.y += p.vy * sdt; p.rot += p.vr * sdt;
        }
        for (let i = texts.length - 1; i >= 0; i--) { const t = texts[i]; t.life -= sdt; t.y += t.vy * sdt; t.vy *= 0.94; if (t.life <= 0) texts.splice(i, 1); }
        for (let i = rings.length - 1; i >= 0; i--) { const r = rings[i]; r.life -= sdt; r.r += r.dr * sdt * (r.life / r.max); if (r.life <= 0) rings.splice(i, 1); }
      }
    }

    /* ---- render ---- */
    function drawBg() {
      const hz = GROUND * u, h0 = hue(0);
      if (sky) ctx.drawImage(sky, 0, 0, W, hz);
      for (let i = 0; i < stars.length; i += 4) {
        const s = stars[i];
        ctx.globalAlpha = 0.4 + 0.6 * Math.abs(Math.sin(realT * 2 + s.p));
        ctx.fillStyle = '#ffffff'; ctx.fillRect(s.x, s.y, s.s + 0.6, s.s + 0.6);
      }
      ctx.globalAlpha = 1;
      if (far) {
        const off = (dist * u * 0.12) % far.w;
        for (let x = -off; x < W; x += far.w) ctx.drawImage(far.c, x, hz - far.h, far.w, far.h);
      }
      if (near) {
        const off = (dist * u * 0.32) % near.w;
        for (let x = -off; x < W; x += near.w) ctx.drawImage(near.c, x, hz - near.h, near.w, near.h);
        ctx.beginPath();
        for (let x0 = -off; x0 < W; x0 += near.w) {
          for (const r of nearRoofs) {
            const a = x0 + r.x;
            if (a > W || a + r.w < 0) continue;
            ctx.moveTo(a, hz - r.h); ctx.lineTo(a + r.w, hz - r.h);
          }
        }
        ctx.lineCap = 'round';
        ctx.strokeStyle = hsl(h0 + 200, 100, 60, 0.25); ctx.lineWidth = 6; ctx.stroke();
        ctx.strokeStyle = hsl(h0 + 200, 100, 65, 0.9); ctx.lineWidth = 2; ctx.stroke();
      }
    }
    function drawGround() {
      const hz = GROUND * u, gh = H - hz, h0 = hue(0);
      const gr = ctx.createLinearGradient(0, hz, 0, H);
      gr.addColorStop(0, '#2b0a4f'); gr.addColorStop(1, '#0b0620');
      ctx.fillStyle = gr; ctx.fillRect(0, hz, W, gh);
      ctx.strokeStyle = hsl(h0 + 180, 100, 62, 0.5); ctx.lineWidth = 1.5;
      ctx.beginPath();
      for (let i = 1; i <= 4; i++) { const y = hz + gh * Math.pow(i / 4.4, 1.5); ctx.moveTo(0, y); ctx.lineTo(W, y); }
      const st = 6 * u, o = (dist * u) % st;
      for (let xt = -st * 4 - o; xt < W + st * 4; xt += st) {
        const xb = W / 2 + (xt - W / 2) * 2.4;
        ctx.moveTo(xt, hz); ctx.lineTo(xb, H);
      }
      ctx.stroke();
      ctx.strokeStyle = hsl(h0, 100, 60, 0.3); ctx.lineWidth = 8;
      ctx.beginPath(); ctx.moveTo(0, hz); ctx.lineTo(W, hz); ctx.stroke();
      ctx.strokeStyle = hsl(h0, 100, 68); ctx.lineWidth = 3; ctx.stroke();
    }
    function glassPath(L, hw, bw) {
      ctx.beginPath(); ctx.moveTo(-bw, 0); ctx.lineTo(-hw, -L); ctx.lineTo(hw, -L); ctx.lineTo(bw, 0); ctx.closePath();
    }
    // base at (cx, baseY); dir=+1 → glass stands up (rim above base); dir=-1 → hangs upside-down.
    function drawGlass(cx, baseY, L, dir, h, wob, pop) {
      if (L <= 2 || pop <= 0) return;
      const w = PW * u, hw = w / 2, bw = w * 0.43;
      ctx.save();
      ctx.translate(cx, baseY);
      ctx.scale(1, dir * (reduced() ? pop : easeOutBack(pop)));
      glassPath(L, hw, bw);
      ctx.fillStyle = 'rgba(190,230,255,0.14)'; ctx.fill();
      // milk
      const inset = w * 0.08, lvl = -L + Math.min(L * 0.3, w * 0.5), baseT = w * 0.16;
      const half = (y) => lerp(bw, hw, -y / L) - inset;
      const xl = -half(lvl), xr = half(lvl), n = 8;
      ctx.beginPath();
      ctx.moveTo(-(bw - inset), -baseT);
      ctx.lineTo(xl, lvl);
      const wy = (i) => lvl + Math.sin(realT * 5 + wob + i * 1.3) * w * 0.035 + Math.sin(realT * 3.1 + i * 0.7) * w * 0.02;
      for (let i = 1; i <= n; i++) ctx.lineTo(lerp(xl, xr, i / n), wy(i));
      ctx.lineTo(bw - inset, -baseT);
      ctx.closePath();
      const mg = ctx.createLinearGradient(-hw, 0, hw, 0);
      mg.addColorStop(0, '#d2c9f2'); mg.addColorStop(0.28, '#ffffff'); mg.addColorStop(0.72, '#fbf7ff'); mg.addColorStop(1, '#c9bdf0');
      ctx.fillStyle = mg; ctx.fill();
      ctx.beginPath(); ctx.moveTo(xl, wy(0));
      for (let i = 1; i <= n; i++) ctx.lineTo(lerp(xl, xr, i / n), wy(i));
      ctx.strokeStyle = 'rgba(170,150,230,0.9)'; ctx.lineWidth = Math.max(1.5, w * 0.03); ctx.stroke();
      // shine + thick base
      ctx.fillStyle = 'rgba(255,255,255,0.4)';
      ctx.fillRect(-hw * 0.72, -L + w * 0.3, w * 0.08, Math.max(0, L - w * 0.6));
      ctx.fillStyle = 'rgba(255,255,255,0.2)';
      ctx.fillRect(-hw * 0.5, -L + w * 0.3, w * 0.035, Math.max(0, L - w * 0.6));
      ctx.fillStyle = 'rgba(215,238,255,0.4)'; ctx.fillRect(-bw, -baseT, bw * 2, baseT);
      // neon outline
      glassPath(L, hw, bw);
      ctx.lineJoin = 'round';
      ctx.strokeStyle = hsl(h, 100, 60, 0.28); ctx.lineWidth = w * 0.2; ctx.stroke();
      ctx.strokeStyle = hsl(h, 100, 66); ctx.lineWidth = Math.max(2, w * 0.055); ctx.stroke();
      // rim
      const rw = w * 1.12, rh = w * 0.14;
      ctx.beginPath();
      if (ctx.roundRect) ctx.roundRect(-rw / 2, -L - rh / 2, rw, rh, rh / 2); else ctx.rect(-rw / 2, -L - rh / 2, rw, rh);
      ctx.fillStyle = 'rgba(255,255,255,0.85)'; ctx.fill();
      ctx.strokeStyle = hsl(h, 100, 66); ctx.lineWidth = Math.max(2, w * 0.05); ctx.stroke();
      ctx.restore();
    }
    function drawPipes() {
      const hz = GROUND * u;
      for (const p of pipes) {
        const cx = (p.x + PW / 2) * u;
        if (cx < -PW * u || cx > W + PW * u) continue;
        const h = hue(p.hoff);
        const top = (p.gy - p.gap / 2) * u, bot = (p.gy + p.gap / 2) * u;
        drawGlass(cx, 0, top, -1, h, p.wob, p.pop);
        drawGlass(cx, hz, hz - bot, 1, h + 40, p.wob + 2, p.pop);
      }
    }
    function drawItems() {
      for (const p of pipes) {
        const it = p.item;
        if (!it || it.got || p.pop < 1) continue;
        const x = (p.x + PW / 2) * u, y = (p.gy + it.dy + Math.sin(realT * 3 + it.seed) * 1.2) * u, s = 2.6 * u;
        const gem = it.kind === 'gem';
        const gl = ctx.createRadialGradient(x, y, 0, x, y, s * 2.4);
        gl.addColorStop(0, gem ? 'rgba(31,244,255,0.55)' : 'rgba(255,201,60,0.5)'); gl.addColorStop(1, gem ? 'rgba(31,244,255,0)' : 'rgba(255,201,60,0)');
        ctx.fillStyle = gl; ctx.beginPath(); ctx.arc(x, y, s * 2.4, 0, TAU); ctx.fill();
        ctx.save(); ctx.translate(x, y); ctx.rotate(Math.sin(realT * 2.5 + it.seed) * 0.25);
        ctx.lineJoin = 'round'; ctx.lineWidth = Math.max(2, s * 0.2); ctx.strokeStyle = STROKE;
        if (gem && artDraw(ctx, 'ui:gem', 0, 0, s * 2.3)) {
          /* drawn by CO.art */
        } else if (gem) {
          ctx.beginPath(); ctx.moveTo(0, -s); ctx.lineTo(s * 0.85, -s * 0.25); ctx.lineTo(0, s); ctx.lineTo(-s * 0.85, -s * 0.25); ctx.closePath();
          ctx.stroke();
          ctx.fillStyle = hsl(hue(180 + it.seed * 20), 100, 62); ctx.fill();
          ctx.fillStyle = 'rgba(255,255,255,0.55)';
          ctx.beginPath(); ctx.moveTo(0, -s); ctx.lineTo(s * 0.85, -s * 0.25); ctx.lineTo(0, -s * 0.1); ctx.closePath(); ctx.fill();
        } else {
          ctx.beginPath();
          ctx.moveTo(0, -s * 1.1);
          ctx.bezierCurveTo(s * 0.35, -s * 0.5, s * 1.0, 0, s * 0.85, s * 0.45);
          ctx.quadraticCurveTo(0, s * 0.95, -s * 0.85, s * 0.45);
          ctx.bezierCurveTo(-s * 1.0, 0, -s * 0.35, -s * 0.5, 0, -s * 1.1);
          ctx.closePath();
          ctx.stroke(); ctx.fillStyle = '#5a2d12'; ctx.fill();
          ctx.fillStyle = 'rgba(255,200,140,0.45)';
          ctx.beginPath(); ctx.ellipse(-s * 0.3, -s * 0.1, s * 0.18, s * 0.32, 0.5, 0, TAU); ctx.fill();
        }
        ctx.restore();
        const tw = Math.max(0, Math.sin(realT * 6 + it.seed * 3));
        if (tw > 0.2) {
          ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = 'rgba(255,255,255,' + (tw * 0.9).toFixed(2) + ')';
          const sx = x + s * 0.8, sy = y - s * 0.9, k = s * 0.5 * tw;
          ctx.beginPath(); ctx.moveTo(sx, sy - k); ctx.lineTo(sx + k * 0.25, sy); ctx.lineTo(sx, sy + k); ctx.lineTo(sx - k * 0.25, sy); ctx.closePath(); ctx.fill();
          ctx.beginPath(); ctx.moveTo(sx - k, sy); ctx.lineTo(sx, sy + k * 0.25); ctx.lineTo(sx + k, sy); ctx.lineTo(sx, sy - k * 0.25); ctx.closePath(); ctx.fill();
          ctx.globalCompositeOperation = 'source-over';
        }
      }
    }
    function drawBird() {
      if (!bird.vis) return;
      const x = BX * u, y = bird.y * u, r = BR * u;
      if (plevel() > 0 && trail.length > 1 && mode !== 'count') {
        ctx.globalCompositeOperation = 'lighter';
        for (let i = 0; i < trail.length - 1; i++) {
          const k = i / trail.length;
          ctx.fillStyle = hsl(hue(i * 25), 100, 60, 0.28 * k);
          ctx.beginPath(); ctx.arc(trail[i].x * u, trail[i].y * u, r * (0.35 + 0.55 * k), 0, TAU); ctx.fill();
        }
        ctx.globalCompositeOperation = 'source-over';
      }
      // wing (behind the cookie)
      const wa = bird.flap > 0 ? -1.2 * Math.sin(bird.flap * Math.PI) : Math.sin(realT * (bird.vy < 0 ? 24 : 7)) * 0.22;
      ctx.save();
      ctx.translate(x, y); ctx.rotate(bird.rot); ctx.translate(-r * 0.55, -r * 0.2); ctx.rotate(wa + 0.3);
      ctx.lineJoin = 'round'; ctx.lineCap = 'round'; ctx.lineWidth = Math.max(2, r * 0.13); ctx.strokeStyle = STROKE;
      ctx.beginPath();
      ctx.moveTo(0, -r * 0.05);
      ctx.quadraticCurveTo(-r * 0.55, -r * 0.62, -r * 1.25, -r * 0.42);
      ctx.quadraticCurveTo(-r * 1.08, -r * 0.2, -r * 1.2, -r * 0.06);
      ctx.quadraticCurveTo(-r * 0.98, r * 0.06, -r * 1.05, r * 0.2);
      ctx.quadraticCurveTo(-r * 0.78, r * 0.26, -r * 0.78, r * 0.38);
      ctx.quadraticCurveTo(-r * 0.36, r * 0.34, 0, r * 0.12);
      ctx.closePath();
      ctx.stroke();
      const wg = ctx.createLinearGradient(0, -r * 0.5, 0, r * 0.4);
      wg.addColorStop(0, '#ffffff'); wg.addColorStop(1, '#cfe9ff');
      ctx.fillStyle = wg; ctx.fill();
      ctx.strokeStyle = 'rgba(26,11,51,0.3)'; ctx.lineWidth = Math.max(1, r * 0.055);
      ctx.beginPath(); ctx.moveTo(-r * 0.25, -r * 0.08); ctx.lineTo(-r * 0.95, -r * 0.14); ctx.moveTo(-r * 0.25, r * 0.06); ctx.lineTo(-r * 0.82, r * 0.12); ctx.stroke();
      ctx.restore();
      cookie(x, y, r, { rot: bird.rot, accessories: true, look: { x: x + r * 6, y: y + bird.vy * u * 0.12 } });
    }
    function drawParts() {
      for (const p of parts) {
        const a = clamp(p.life / p.max, 0, 1);
        ctx.globalCompositeOperation = p.add ? 'lighter' : 'source-over';
        ctx.globalAlpha = p.grow ? a * 0.75 : p.add ? a : Math.min(1, a * 1.8);
        ctx.fillStyle = p.col;
        if (p.sq) {
          ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot);
          ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size * 0.8);
          ctx.restore();
        } else {
          const s = p.grow ? p.size * (1 + (1 - a) * p.grow) : p.size * (p.add ? 0.4 + a * 0.6 : 1);
          ctx.beginPath(); ctx.arc(p.x, p.y, s, 0, TAU); ctx.fill();
        }
      }
      ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
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
      const size = clamp(u * 11, 44, 84) * (1 + scoreBump * 0.3);
      const y = Math.max(40, u * 11);
      outlined(ctx, String(score), W / 2, y, size, '#ffffff');
      const b = Math.max(bestAtStart, score);
      if (bestAtStart > 0) {
        ctx.font = '700 13px ' + MONO; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.fillStyle = 'rgba(0,0,0,0.5)'; ctx.fillText('RECORD ' + b, W / 2 + 1, y + size * 0.62 + 1);
        ctx.fillStyle = score > bestAtStart && bestAtStart > 0 ? hsl(hue(0), 100, 70) : '#ffc93c';
        ctx.fillText('RECORD ' + b, W / 2, y + size * 0.62);
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
      const size = Math.min(W, H) * (idx === 3 ? 0.24 : 0.32);
      const cx = W / 2, cy = H * 0.42;
      if (!rm) {
        ctx.globalAlpha = a * 0.6; ctx.strokeStyle = hsl(hue(idx * 90 + 60), 100, 65); ctx.lineWidth = 6 * (1 - k) + 1;
        ctx.beginPath(); ctx.arc(cx, cy, size * (0.6 + k * 0.9), 0, TAU); ctx.stroke(); ctx.globalAlpha = 1;
      }
      ctx.save(); ctx.globalAlpha = a; ctx.translate(cx, cy); ctx.scale(sc, sc);
      if (!rm) ctx.rotate((1 - k) * 0.12 * (idx % 2 ? 1 : -1));
      outlined(ctx, label, 0, 0, size, hsl(hue(idx * 90), 100, 65));
      ctx.restore();
      if (mode === 'count') outlined(ctx, resumeRun ? 'ON REPREND !' : 'TAPE / ESPACE POUR VOLER', cx, cy + size * 0.8, clamp(W * 0.045, 14, 22), '#ffffff');
    }
    function drawPause() {
      ctx.fillStyle = 'rgba(11,6,32,0.6)'; ctx.fillRect(0, 0, W, H);
      outlined(ctx, 'PAUSE', W / 2, H * 0.42, clamp(W * 0.16, 44, 90), hsl(hue(0), 100, 66));
      outlined(ctx, 'Tape pour reprendre', W / 2, H * 0.42 + 60, clamp(W * 0.05, 16, 24), '#ffffff');
    }
    function render() {
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
      ctx.save();
      if (shake > 0.3 && canShake()) ctx.translate(rand(-shake, shake), rand(-shake, shake));
      drawBg();
      drawPipes();
      drawItems();
      drawGround();
      drawRings();
      drawBird();
      drawParts();
      drawTexts();
      ctx.restore();
      if (mode === 'menu') {
        const sg = ctx.createLinearGradient(0, 0, 0, H);
        sg.addColorStop(0, 'rgba(11,6,32,0.72)'); sg.addColorStop(0.3, 'rgba(11,6,32,0.1)');
        sg.addColorStop(0.62, 'rgba(11,6,32,0.1)'); sg.addColorStop(1, 'rgba(11,6,32,0.78)');
        ctx.fillStyle = sg; ctx.fillRect(0, 0, W, H);
      }
      if (mode === 'count' || mode === 'play' || mode === 'paused' || mode === 'dying') drawHud();
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
      if (!menuEl.hidden) { const h0 = hue(0); titleSpans.forEach((s, i) => { s.style.color = hsl(h0 + i * 24, 100, 66); }); }
      if (resEl.hidden || !resData) return;
      resT += dt;
      const D0 = 0.3, CU = clamp(0.5 + resData.score * 0.015, 0.6, 1.4);
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
    function onDown(e) {
      e.preventDefault();
      if (mode === 'paused') { resume(); return; }
      if (mode === 'play') flap(false);
    }
    function onKey(e) {
      if (destroyed) return;
      const k = e.key;
      const isFlap = k === ' ' || e.code === 'Space' || k === 'ArrowUp' || k === 'w' || k === 'W' || k === 'z' || k === 'Z';
      if (isFlap) {
        if (mode === 'play' || mode === 'count' || mode === 'dying' || mode === 'paused') e.preventDefault();
        if (e.repeat) return;
        if (mode === 'play') flap(false);
        else if (mode === 'paused') resume();
        else if (mode === 'menu' && (k === ' ' || e.code === 'Space') && document.activeElement !== playBtn) { e.preventDefault(); startRun(); }
        return;
      }
      if (k === 'Enter') {
        if (mode === 'menu' || (mode === 'results' && resStage >= 3)) { e.preventDefault(); startRun(); }
        else if (mode === 'paused') { e.preventDefault(); resume(); }
      } else if ((k === 'p' || k === 'P') && mode === 'play') pause();
    }
    function onVis() { if (document.hidden) pause(); }
    const onPlay = () => startRun();
    const onAgain = () => { if (resStage >= 2) startRun(); };
    const onQuit = () => { try { api.close(); } catch (e) { /* ignore */ } };
    const onCtx = (e) => e.preventDefault();

    cv.addEventListener('pointerdown', onDown);
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
    resetWorld(false);
    raf = requestAnimationFrame(frame);

    function destroy() {
      if (destroyed) return;
      destroyed = true;
      cancelAnimationFrame(raf);
      if (ro) ro.disconnect(); else window.removeEventListener('resize', resize);
      window.removeEventListener('keydown', onKey);
      document.removeEventListener('visibilitychange', onVis);
      cv.removeEventListener('pointerdown', onDown);
      cv.removeEventListener('contextmenu', onCtx);
      playBtn.removeEventListener('click', onPlay);
      againBtn.removeEventListener('click', onAgain);
      quitBtn.removeEventListener('click', onQuit);
      wrap.remove();
      pipes = parts = texts = rings = trail = [];
      sky = far = near = null;
      cv.width = cv.height = 0;
    }
    return { destroy };
  }

  const def = {
    id: 'flappy',
    name: 'Flappy Cookie',
    color: '#1ff4ff',
    tagline: 'Fais voler ton cookie entre les verres de lait.',
    howto: 'Tape, clique ou Espace pour battre des ailes. Passe entre les verres de lait et chope les pépites !',
    mount,
  };
  if (typeof CO.registerMinigame === 'function') CO.registerMinigame(def);
  else (CO._pendingMinigames = CO._pendingMinigames || []).push(def);
})();
