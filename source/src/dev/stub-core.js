/* DEV STUB of js/core.js — same public API surface, fake behaviour.
 * Load order in a harness:  js/data.js → dev/stub-core.js → (js/stage.js | js/mg-*.js)
 * The real core.js will expose exactly these members (see SPEC.md).
 */
(function () {
  'use strict';
  const CO = (window.CO = window.CO || {});
  const D = CO.data;

  /* ── events ── */
  const handlers = {};
  CO.on = (ev, fn) => { (handlers[ev] = handlers[ev] || []).push(fn); return () => CO.off(ev, fn); };
  CO.off = (ev, fn) => { const a = handlers[ev]; if (a) { const i = a.indexOf(fn); if (i >= 0) a.splice(i, 1); } };
  CO.emit = (ev, p) => { (handlers[ev] || []).slice().forEach((fn) => { try { fn(p || {}); } catch (e) { console.error(e); } }); };

  /* ── time / rgb ── */
  CO.now = () => performance.now() / 1000;
  CO.hue = (offset = 0) => ((CO.now() * 60 * (CO.state.settings.rgbSpeed || 0) + offset) % 360 + 360) % 360;
  CO.bpm = 120;
  CO.beatPhase = () => ((CO.now() * CO.bpm) / 60) % 1;

  /* ── state ── */
  CO.state = {
    cookies: 12345, totalBaked: 50000, allTimeBaked: 50000, clicks: 420, gems: 99, rebirths: 2, stars: 3,
    buildings: { cursor: 24, granny: 8, farm: 5, mine: 3, factory: 2, bank: 1, temple: 1, wizard: 0, rocket: 0, lab: 0, portal: 0, timemachine: 0, antimatter: 0, prism: 0, streamer: 0 },
    upgrades: {}, skin: 'classic', skinsOwned: { classic: true }, theme: 'synthwave', themesOwned: { synthwave: true },
    pets: [{ uid: 1, id: 'cat', lvl: 1 }, { uid: 2, id: 'unicorn', lvl: 2 }, { uid: 3, id: 'glitchy', lvl: 1 }],
    equipped: [1, 2, 3],
    mg: {}, flags: { logo: 0 },
    stats: { golden: 0, crits: 0, maxCombo: 0, fevers: 0, bossKills: 0, eggs: 0, quests: 0 },
    settings: { sfx: 0.6, music: 0.5, musicOn: false, rgbSpeed: 1, particles: 2, shake: true, trail: true, reducedMotion: false, numFormat: 'short', showFps: true, uiHue: 'rgb', clickSound: 'pop' },
  };
  CO.settings = CO.state.settings;
  CO.vis = {};                       // harness toggles keys → level
  CO.combo = { count: 0, mult: 1, heat: 0 };
  CO.fever = { active: false, until: 0 };
  CO.buffs = [];
  CO.golden = { list: [] };
  CO.boss = null;

  CO.skin = () => D.skins.find((s) => s.id === CO.state.skin) || D.skins[0];
  CO.theme = () => D.themes.find((t) => t.id === CO.state.theme) || D.themes[0];
  CO.petDef = (id) => D.pets.find((p) => p.id === id);
  CO.equippedPets = () => CO.state.equipped.map((uid) => CO.state.pets.find((p) => p.uid === uid)).filter(Boolean).map((p) => ({ uid: p.uid, lvl: p.lvl, def: CO.petDef(p.id) }));
  CO.cpsBase = () => 1234;
  CO.cpsNow = () => 1234 * (CO.fever.active ? 3 : 1);
  CO.clickValue = () => 42;

  /* ── formatting ── */
  const SUF = ['', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No', 'Dc'];
  CO.fmt = (n) => {
    if (!isFinite(n)) return '∞';
    if (n < 1000) return (Math.round(n * 10) / 10).toLocaleString('fr-FR');
    const e = Math.floor(Math.log10(n) / 3);
    if (e >= SUF.length) return n.toExponential(2).replace('+', '');
    return (n / Math.pow(1000, e)).toFixed(2).replace(/\.?0+$/, '') + ' ' + SUF[e];
  };

  /* ── clicks (fake) ── */
  let lastClick = 0;
  CO.clickCookie = (x, y) => {
    const t = CO.now();
    CO.combo.count = t - lastClick < 1.2 ? CO.combo.count + 1 : 1;
    lastClick = t;
    CO.combo.mult = 1 + Math.min(4, Math.floor(CO.combo.count / 10) * 0.5);
    CO.combo.heat = Math.min(1, CO.combo.count / 100);
    const crit = Math.random() < 0.08;
    const amount = CO.clickValue() * CO.combo.mult * (crit ? 10 : 1);
    CO.state.cookies += amount; CO.state.clicks++;
    CO.emit('click', { x, y, amount, crit, combo: CO.combo.count, mult: CO.combo.mult });
    if (CO.boss) {
      const dmg = CO.combo.mult * (crit ? 10 : 1);
      CO.boss.hp = Math.max(0, CO.boss.hp - dmg);
      CO.emit('boss:hit', { dmg, crit, boss: CO.boss });
      if (CO.boss.hp <= 0) { const b = CO.boss; CO.boss = null; CO.emit('boss:defeat', { boss: b }); }
    }
    return { amount, crit };
  };
  CO.clickGolden = (id) => {
    const g = CO.golden.list.find((x) => x.id === id); if (!g) return;
    CO.golden.list = CO.golden.list.filter((x) => x !== g);
    const eff = D.golden[Math.floor(Math.random() * D.golden.length)];
    CO.emit('golden:click', { g, kind: eff.kind, label: eff.label, color: eff.color });
  };
  // harness helpers
  let gid = 1;
  CO._spawnGolden = () => { const g = { id: gid++, x: 0.1 + Math.random() * 0.8, y: 0.12 + Math.random() * 0.76, born: CO.now(), life: 12 }; CO.golden.list.push(g); CO.emit('golden:spawn', { g }); };
  CO._spawnBoss = () => { const d = D.bosses[Math.floor(Math.random() * D.bosses.length)]; CO.boss = { ...d, hp: 100, maxHp: 100, born: CO.now(), until: CO.now() + 30 }; CO.emit('boss:spawn', { boss: CO.boss }); };
  CO._fever = (on) => { CO.fever.active = on; CO.fever.until = CO.now() + 8; CO.emit(on ? 'fever:start' : 'fever:end'); };
  setInterval(() => { // expire goldens, decay combo
    const t = CO.now();
    CO.golden.list = CO.golden.list.filter((g) => { if (t - g.born > g.life) { CO.emit('golden:expire', { g }); return false; } return true; });
    if (t - lastClick > 1.2) { CO.combo.count = Math.max(0, CO.combo.count - 3); CO.combo.heat = Math.min(1, CO.combo.count / 100); CO.combo.mult = 1 + Math.min(4, Math.floor(CO.combo.count / 10) * 0.5); }
    if (CO.boss && t > CO.boss.until) { const b = CO.boss; CO.boss = null; CO.emit('boss:escape', { boss: b }); }
  }, 100);
  setInterval(() => CO.emit('beat', { n: 0 }), 500);

  /* ── audio (tiny) ── */
  let actx = null, out = null;
  CO.audio = () => {
    try {
      if (!actx) { actx = new (window.AudioContext || window.webkitAudioContext)(); out = actx.createGain(); out.gain.value = CO.settings.sfx; out.connect(actx.destination); }
      if (actx.state === 'suspended') actx.resume();
      return { ctx: actx, out };
    } catch (e) { return null; }
  };
  CO.sfx = {
    play(name, opts = {}) {
      const a = CO.audio(); if (!a) return;
      const o = a.ctx.createOscillator(), g = a.ctx.createGain(), t = a.ctx.currentTime;
      o.type = 'triangle'; o.frequency.value = 440 * (opts.pitch || 1) * (name === 'error' ? 0.5 : 1);
      g.gain.setValueAtTime(0.2 * (opts.vol || 1), t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.12);
      o.connect(g); g.connect(a.out); o.start(t); o.stop(t + 0.13);
    },
  };

  /* ── cookie drawing proxy (stage.js provides the real one) ── */
  CO.drawCookie = (ctx, x, y, r, opts = {}) => {
    if (CO.stage && CO.stage.drawCookie) return CO.stage.drawCookie(ctx, x, y, r, opts);
    const p = (opts.skin ? D.skins.find((s) => s.id === opts.skin) : CO.skin()).pal;
    ctx.save(); ctx.translate(x, y); ctx.rotate(opts.rot || 0);
    ctx.fillStyle = p.base; ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.fill();
    ctx.lineWidth = r * 0.08; ctx.strokeStyle = p.rim; ctx.stroke();
    ctx.fillStyle = p.chip; [[-.4, -.3], [.35, -.2], [0, .35], [-.2, .1], [.4, .4]].forEach(([a, b]) => { ctx.beginPath(); ctx.arc(a * r, b * r, r * 0.13, 0, Math.PI * 2); ctx.fill(); });
    ctx.restore();
  };

  /* ── toast (console in stub) ── */
  CO.toast = (text, opts) => console.log('[toast]', text, opts || '');

  /* ── minigames ── */
  CO.minigames = {};
  CO.registerMinigame = (def) => { CO.minigames[def.id] = def; CO.emit('minigame:registered', { id: def.id }); };
  CO.unit = () => Math.max(25, CO.cpsBase() * 60);
  CO.minigameApi = (id, onClose) => {
    const rec = (CO.state.mg[id] = CO.state.mg[id] || { best: 0, plays: 0 });
    return {
      id,
      unit: () => CO.unit(),
      cookies: () => CO.state.cookies,
      spend: (n) => { if (n <= CO.state.cookies) { CO.state.cookies -= n; return true; } return false; },
      end: ({ score = 0, cookies = 0, gems = 0 } = {}) => {
        const isNewBest = score > rec.best; if (isNewBest) rec.best = score; rec.plays++;
        CO.state.cookies += cookies; CO.state.gems += gems;
        console.log('[minigame end]', { id, score, cookies, gems, best: rec.best, isNewBest });
        return { cookies, gems, best: rec.best, isNewBest };
      },
      grant: ({ cookies = 0, gems = 0 } = {}) => { CO.state.cookies += cookies; CO.state.gems += gems; console.log('[minigame grant]', { cookies, gems }); },
      best: () => rec.best,
      fmt: CO.fmt,
      sfx: (n, o) => CO.sfx.play(n, o),
      audio: () => CO.audio(),
      drawCookie: (...a) => CO.drawCookie(...a),
      skin: () => CO.skin(),
      vis: () => CO.vis,
      hue: (o) => CO.hue(o),
      settings: () => CO.settings,
      toast: (t, o) => CO.toast(t, o),
      close: () => onClose && onClose(),
    };
  };
})();
