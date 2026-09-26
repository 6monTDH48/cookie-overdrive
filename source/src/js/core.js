/* COOKIE OVERDRIVE — core.js
 * Engine: state, economy, combo/fever, golden cookies, bosses, pets, quests,
 * achievements, minigame host API, synthesized audio + music, save/load.
 * Public surface documented in SPEC.md.
 */
(function () {
  'use strict';
  const CO = (window.CO = window.CO || {});
  const D = CO.data;
  const SAVE_KEY = 'cookie-overdrive-v1';

  /* ═════════════════════════ EVENTS ═════════════════════════ */
  const handlers = {};
  CO.on = (ev, fn) => { (handlers[ev] = handlers[ev] || []).push(fn); return () => CO.off(ev, fn); };
  CO.off = (ev, fn) => { const a = handlers[ev]; if (a) { const i = a.indexOf(fn); if (i >= 0) a.splice(i, 1); } };
  CO.emit = (ev, p) => {
    const list = handlers[ev]; if (!list) return;
    list.slice().forEach((fn) => { try { fn(p || {}); } catch (e) { console.error('[CO:' + ev + ']', e); } });
  };

  /* ═════════════════════════ TIME / RGB ═════════════════════════ */
  CO.now = () => performance.now() / 1000;
  let hueClock = 0, hueLast = CO.now();
  CO.hue = (offset = 0) => {
    const t = CO.now();
    const sp = (CO.settings && CO.settings.rgbSpeed != null ? CO.settings.rgbSpeed : 1) * (CO.fever && CO.fever.active ? 2.2 : 1);
    hueClock += (t - hueLast) * 60 * sp; hueLast = t;
    return (((hueClock + offset) % 360) + 360) % 360;
  };
  CO.bpm = 116;
  let beatOrigin = CO.now();
  CO.beatPhase = () => ((((CO.now() - beatOrigin) * CO.bpm) / 60) % 1 + 1) % 1;

  /* ═════════════════════════ UTIL ═════════════════════════ */
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const rand = (a, b) => a + Math.random() * (b - a);
  const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
  const isObj = (o) => o && typeof o === 'object' && !Array.isArray(o);
  function merge(def, src) {
    const out = Array.isArray(def) ? def.slice() : { ...def };
    if (!isObj(src)) return out;
    for (const k of Object.keys(src)) {
      if (isObj(def[k]) && isObj(src[k])) out[k] = merge(def[k], src[k]);
      else if (src[k] !== undefined) out[k] = src[k];
    }
    return out;
  }
  const byId = (arr) => Object.fromEntries(arr.map((x) => [x.id, x]));
  const BLD = byId(D.buildings), UPG = byId(D.upgrades), SKIN = byId(D.skins), THEME = byId(D.themes), PET = byId(D.pets), EGG = byId(D.eggs), ACH = byId(D.achievements);
  CO.idx = { BLD, UPG, SKIN, THEME, PET, EGG, ACH };

  /* ═════════════════════════ NUMBER FORMAT ═════════════════════════ */
  const SUF = ['', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No', 'Dc', 'UDc', 'DDc', 'TDc'];
  const LONG = ['', '', 'million', 'milliard', 'billion', 'billiard', 'trillion', 'trilliard', 'quadrillion', 'quadrilliard', 'quintillion', 'quintilliard', 'sextillion', 'sextilliard'];
  const dec = (x, d) => x.toFixed(d).replace(/\.?0+$/, '').replace('.', ',');
  const spaced = (n) => Math.floor(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  CO.fmt = (n, opts) => {
    if (n == null || isNaN(n)) return '0';
    if (!isFinite(n)) return '∞';
    const neg = n < 0; n = Math.abs(n);
    const f = (CO.settings && CO.settings.numFormat) || 'short';
    let s;
    if (n < 1000) s = n < 100 && n % 1 !== 0 && !(opts && opts.int) ? dec(n, 1) : spaced(n);
    else if (f === 'sci') s = n < 1e6 ? spaced(n) : dec(n / Math.pow(10, Math.floor(Math.log10(n))), 2) + 'e' + Math.floor(Math.log10(n));
    else if (f === 'long') {
      if (n < 1e6) s = spaced(n);
      else { const e = Math.floor(Math.log10(n) / 3); if (e < LONG.length) { const v = n / Math.pow(1000, e); s = dec(v, 2) + ' ' + LONG[e] + (v >= 2 ? 's' : ''); } else s = n.toExponential(2).replace('+', ''); }
    } else {
      const e = Math.floor(Math.log10(n) / 3);
      if (e >= SUF.length) s = dec(n / Math.pow(10, Math.floor(Math.log10(n))), 2) + 'e' + Math.floor(Math.log10(n));
      else { const v = n / Math.pow(1000, e); s = dec(v, v >= 100 ? 0 : v >= 10 ? 1 : 2) + ' ' + SUF[e]; }
    }
    return (neg ? '-' : '') + s;
  };
  CO.fmtTime = (sec) => {
    sec = Math.max(0, Math.round(sec));
    const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
    if (h) return h + ' h ' + String(m).padStart(2, '0');
    if (m) return m + ' min ' + String(s).padStart(2, '0');
    return s + ' s';
  };

  /* ═════════════════════════ STATE ═════════════════════════ */
  const reduced = (() => { try { return window.matchMedia('(prefers-reduced-motion: reduce)').matches; } catch (e) { return false; } })();
  function defaultSettings() {
    return { sfx: 0.55, music: 0.4, musicOn: false, rgbSpeed: 1, particles: 2, shake: !reduced, trail: true, reducedMotion: reduced, numFormat: 'short', showFps: false, uiHue: 'rgb', clickSound: 'pop', buyQty: 1, track: 'synthwave' };
  }
  function defaultState() {
    return {
      v: 1,
      cookies: 0, totalBaked: 0, allTimeBaked: 0, clicks: 0, clickBaked: 0,
      gems: 0, rebirths: 0, stars: 0, lastDaily: '', dailyStreak: 0,
      buildings: Object.fromEntries(D.buildings.map((b) => [b.id, 0])),
      upgrades: {},
      skin: 'classic', skinsOwned: { classic: true },
      theme: 'synthwave', themesOwned: { synthwave: true },
      pets: [], equipped: [], petUid: 1,
      achievements: {},
      quests: [], questUid: 1,
      mg: {}, mgSeen: {},
      flags: { logo: 0 },
      nextGift: 0, gifts: 0,
      stats: { golden: 0, crits: 0, maxCombo: 0, fevers: 0, bossKills: 0, eggs: 0, quests: 0, startedAt: Date.now(), playTime: 0, bestCps: 0 },
      settings: defaultSettings(),
      lastSave: Date.now(),
    };
  }
  CO.state = defaultState();
  CO.settings = CO.state.settings;

  /* ═════════════════════════ DERIVED MULTIPLIERS ═════════════════════════ */
  const M = { click: 1, clickCps: 0, bld: {}, cps: 1, crit: 0.03, critX: 10, goldenFreq: 1, goldenDur: 1, comboCap: 3, feverDur: 8, petCps: 1, petClick: 1, star: 1, ach: 1 };
  CO.mult = M;
  CO.vis = {};
  CO.maxPetSlots = 3;

  function recalc(silent) {
    const s = CO.state;
    M.click = 1; M.clickCps = 0; M.cps = 1; M.crit = 0.03; M.critX = 10; M.goldenFreq = 1; M.goldenDur = 1; M.comboCap = 3; M.feverDur = 8;
    D.buildings.forEach((b) => (M.bld[b.id] = 1));
    const vis = {};
    for (const u of D.upgrades) {
      if (!s.upgrades[u.id]) continue;
      const fx = u.fx;
      if (fx.click) M.click *= fx.click;
      if (fx.clickCps) M.clickCps += fx.clickCps;
      if (fx.bld) M.bld[fx.bld] *= fx.x || 1;
      if (fx.cps) M.cps *= fx.cps;
      if (fx.crit) M.crit += fx.crit;
      if (fx.critX) M.critX *= fx.critX;
      if (fx.goldenFreq) M.goldenFreq *= fx.goldenFreq;
      if (fx.goldenDur) M.goldenDur *= fx.goldenDur;
      if (fx.comboCap) M.comboCap += fx.comboCap;
      if (fx.feverDur) M.feverDur *= fx.feverDur;
      if (u.vis) { const [k, l] = u.vis; const max = (D.visuals[k] && D.visuals[k].max) || 1; vis[k] = Math.min(max, (vis[k] || 0) + l); }
    }
    // pets
    let pc = 0, pk = 0;
    for (const p of CO.equippedPets()) {
      const b = p.def.bonus, lv = 1 + 0.5 * (p.lvl - 1);
      if (b.cps) pc += b.cps * lv;
      if (b.click) pk += b.click * lv;
      if (b.all) { pc += b.all * lv; pk += b.all * lv; }
      if (b.crit) M.crit += b.crit;
      if (b.golden) M.goldenFreq *= b.golden;
    }
    M.petCps = 1 + pc; M.petClick = 1 + pk;
    M.star = 1 + 0.1 * s.stars;
    M.ach = 1 + 0.01 * Object.keys(s.achievements).length;
    // visuals diff
    const prev = CO.vis;
    const added = Object.keys(vis).filter((k) => (prev[k] || 0) < vis[k]);
    const removed = Object.keys(prev).some((k) => !vis[k]);
    CO.vis = vis;
    if (!silent && (added.length || removed)) CO.emit('visuals', { vis, added });
  }
  CO.recalc = recalc;

  /* ═════════════════════════ ECONOMY ═════════════════════════ */
  const GROWTH = 1.14, BLD_POWER = 1.5; // tuned by simulation: faster, "hyperactive" pacing
  CO.buildingCps = (id) => BLD[id].cps * BLD_POWER * M.bld[id] * M.cps * M.petCps * M.star * M.ach;
  CO.cpsBase = () => {
    let t = 0; const b = CO.state.buildings;
    for (const d of D.buildings) if (b[d.id]) t += d.cps * b[d.id] * M.bld[d.id];
    return t * BLD_POWER * M.cps * M.petCps * M.star * M.ach;
  };
  const buffMul = (key) => CO.buffs.reduce((m, b) => m * (b[key] || 1), 1);
  CO.feverMult = 3;
  CO.cpsNow = () => CO.cpsBase() * buffMul('cps') * (CO.fever.active ? CO.feverMult : 1);
  CO.clickValue = () => {
    const base = M.click + CO.cpsBase() * buffMul('cps') * M.clickCps;
    return base * M.petClick * M.star * buffMul('click') * (CO.fever.active ? CO.feverMult : 1);
  };
  CO.bCost = (id, n = 1, owned) => {
    const d = BLD[id]; const o = owned != null ? owned : CO.state.buildings[id] || 0;
    return Math.ceil((d.cost * Math.pow(GROWTH, o) * (Math.pow(GROWTH, n) - 1)) / (GROWTH - 1));
  };
  CO.bMax = (id) => {
    const d = BLD[id], o = CO.state.buildings[id] || 0;
    const c0 = d.cost * Math.pow(GROWTH, o);
    const n = Math.floor(Math.log((CO.state.cookies * (GROWTH - 1)) / c0 + 1) / Math.log(GROWTH));
    return Math.max(0, n);
  };
  CO.buildingUnlocked = (id) => {
    const i = D.buildings.findIndex((b) => b.id === id);
    if (i <= 1) return true;
    const s = CO.state;
    return (s.buildings[id] || 0) > 0 || (s.buildings[D.buildings[i - 1].id] || 0) > 0 || s.allTimeBaked >= D.buildings[i].cost * 0.4;
  };
  function earn(n, src) {
    if (!(n > 0)) return;
    const s = CO.state;
    s.cookies += n; s.totalBaked += n; s.allTimeBaked += n;
    questProgress('bake', n);
  }
  CO.earn = earn;

  CO.buyBuilding = (id, qty) => {
    const s = CO.state;
    let n = qty === 'max' ? CO.bMax(id) : qty || 1;
    if (n <= 0) { CO.sfx.play('error'); return false; }
    const cost = CO.bCost(id, n);
    if (cost > s.cookies) { CO.sfx.play('error'); return false; }
    s.cookies -= cost; s.buildings[id] = (s.buildings[id] || 0) + n;
    questProgress('buy', n);
    CO.sfx.play('buy', { pitch: 1 + Math.min(0.6, (s.buildings[id] % 10) * 0.05) });
    CO.emit('buy', { kind: 'building', id, n });
    return true;
  };

  function reqMet(u) {
    const r = u.req || {}, s = CO.state;
    if (r.clicks != null && s.clicks < r.clicks) return false;
    if (r.bld && (s.buildings[r.bld[0]] || 0) < r.bld[1]) return false;
    if (r.baked != null && s.totalBaked < r.baked) return false;
    if (r.golden != null && s.stats.golden < r.golden) return false;
    if (r.crits != null && s.stats.crits < r.crits) return false;
    if (r.combo != null && s.stats.maxCombo < r.combo) return false;
    return true;
  }
  CO.reqMet = reqMet;
  CO.reqText = (u) => {
    const r = u.req || {};
    if (r.clicks != null) return 'Clique ' + CO.fmt(r.clicks, { int: 1 }) + ' fois';
    if (r.bld) return 'Possède ' + r.bld[1] + ' × ' + BLD[r.bld[0]].name;
    if (r.baked != null) return 'Produis ' + CO.fmt(r.baked) + ' cookies';
    if (r.golden != null) return 'Attrape ' + r.golden + ' cookies dorés';
    if (r.crits != null) return 'Fais ' + r.crits + ' clics critiques';
    if (r.combo != null) return 'Atteins un combo de ' + r.combo;
    return '';
  };
  CO.fxText = (u) => {
    const fx = u.fx, out = [];
    if (fx.bld) out.push(BLD[fx.bld].name + ' ×' + fx.x);
    if (fx.click) out.push('Clic ×' + fx.click);
    if (fx.clickCps) out.push('Clic +' + Math.round(fx.clickCps * 1000) / 10 + ' % du CPS');
    if (fx.cps) out.push('Production +' + Math.round((fx.cps - 1) * 100) + ' %');
    if (fx.crit) out.push('Chance critique +' + Math.round(fx.crit * 100) + ' %');
    if (fx.critX) out.push('Dégâts critiques ×' + fx.critX);
    if (fx.goldenFreq) out.push('Cookies dorés +' + Math.round((fx.goldenFreq - 1) * 100) + ' % plus fréquents');
    if (fx.goldenDur) out.push('Effets dorés +' + Math.round((fx.goldenDur - 1) * 100) + ' % plus longs');
    if (fx.comboCap) out.push('Combo max +×' + fx.comboCap / 2);
    if (fx.feverDur) out.push('Fièvre +' + Math.round((fx.feverDur - 1) * 100) + ' % plus longue');
    return out.join(' · ');
  };
  CO.upgradeState = (u) => (CO.state.upgrades[u.id] ? 'owned' : reqMet(u) ? 'available' : 'locked');

  CO.buyUpgrade = (id) => {
    const u = UPG[id], s = CO.state;
    if (!u || s.upgrades[id] || !reqMet(u)) return false;
    if (u.cost > s.cookies) { CO.sfx.play('error'); return false; }
    s.cookies -= u.cost; s.upgrades[id] = true;
    recalc();
    questProgress('upgrade', 1);
    CO.sfx.play('upgrade');
    CO.emit('buy', { kind: 'upgrade', id, n: 1 });
    return true;
  };

  /* ═════════════════════════ CLICK / COMBO / FEVER ═════════════════════════ */
  CO.combo = { count: 0, mult: 1, heat: 0 };
  CO.fever = { active: false, until: 0, cooldownUntil: 0 };
  CO.buffs = [];
  const FEVER_AT = 120;
  let lastClickT = -10, lastInteractT = CO.now();
  CO.idleFor = () => CO.now() - lastInteractT;
  CO.touch = () => { lastInteractT = CO.now(); };

  function comboMultFor(count) { return 1 + Math.min(M.comboCap - 1, Math.floor(count / 15) * 0.5); }

  CO.clickCookie = (x, y) => {
    const s = CO.state, t = CO.now();
    unlockAudio();
    lastClickT = t; lastInteractT = t;
    const c = CO.combo;
    c.count += 1;
    c.mult = comboMultFor(c.count);
    if (c.count > s.stats.maxCombo) s.stats.maxCombo = Math.floor(c.count);
    questProgress('combo', c.count, true);
    const crit = Math.random() < M.crit;
    const amount = CO.clickValue() * c.mult * (crit ? M.critX : 1);
    s.clicks++; s.clickBaked += amount;
    earn(amount, 'click');
    questProgress('clicks', 1);
    if (crit) { s.stats.crits++; questProgress('crit', 1); }
    // heat & fever
    if (!CO.fever.active) {
      c.heat = t < CO.fever.cooldownUntil ? Math.min(0.95, c.count / FEVER_AT) : Math.min(1, c.count / FEVER_AT);
      if (c.count >= FEVER_AT && t >= CO.fever.cooldownUntil) startFever();
    } else c.heat = 1;
    // sounds
    const pitch = 1 + Math.min(0.6, c.count / 250) + rand(-0.04, 0.04);
    CO.sfx.play(crit ? 'crit' : 'click', { pitch });
    if (c.count % 25 === 0) CO.sfx.play('combo', { pitch: 1 + Math.min(1, c.count / 200) });
    CO.emit('click', { x, y, amount, crit, combo: Math.floor(c.count), mult: c.mult });
    // boss damage
    if (CO.boss) {
      const dmg = Math.round(c.mult * (crit ? 5 : 1) * (1 + (M.petClick - 1) * 0.25) * 10) / 10;
      CO.boss.hp = Math.max(0, CO.boss.hp - dmg);
      CO.emit('boss:hit', { dmg, crit, boss: CO.boss });
      if (CO.boss.hp <= 0) defeatBoss();
    }
    return { amount, crit };
  };

  function startFever() {
    const s = CO.state, t = CO.now();
    CO.fever.active = true; CO.fever.until = t + M.feverDur;
    CO.combo.heat = 1;
    s.stats.fevers++;
    questProgress('fever', 1);
    CO.sfx.play('fever');
    music.intensity(1);
    CO.emit('fever:start', {});
  }
  function endFever() {
    CO.fever.active = false; CO.fever.cooldownUntil = CO.now() + 20;
    CO.combo.count = 0; CO.combo.mult = 1; CO.combo.heat = 0;
    music.intensity(0);
    CO.emit('fever:end', {});
  }
  CO.startFever = startFever;

  function addBuff(b) {
    const t = CO.now(), dur = b.dur * M.goldenDur;
    const ex = CO.buffs.find((x) => x.id === b.id);
    if (ex) { ex.until = t + dur; ex.dur = dur; return; }
    const buff = { ...b, dur, until: t + dur };
    CO.buffs.push(buff);
    CO.emit('buff:start', { buff });
  }
  CO.addBuff = addBuff;

  /* ═════════════════════════ GOLDEN COOKIES ═════════════════════════ */
  CO.golden = { list: [], next: CO.now() + rand(25, 45) };
  let gid = 1;
  let mgOpen = null;
  function spawnGolden() {
    let x, y, tries = 0;
    do { x = rand(0.1, 0.9); y = rand(0.22, 0.85); tries++; } while (Math.hypot(x - 0.5, (y - 0.56) * 1.2) < 0.3 && tries < 20);
    const g = { id: gid++, x, y, born: CO.now(), life: 13 };
    CO.golden.list.push(g);
    CO.sfx.play('golden', { vol: 0.5, pitch: 1.5 });
    CO.emit('golden:spawn', { g });
  }
  CO.spawnGolden = spawnGolden;
  CO.clickGolden = (id) => {
    const g = CO.golden.list.find((x) => x.id === id);
    if (!g) return;
    unlockAudio(); lastInteractT = CO.now();
    CO.golden.list = CO.golden.list.filter((x) => x !== g);
    const s = CO.state;
    // weighted pick
    const tot = D.golden.reduce((a, e) => a + e.weight, 0);
    let r = Math.random() * tot, eff = D.golden[0];
    for (const e of D.golden) { if ((r -= e.weight) <= 0) { eff = e; break; } }
    let label = eff.label;
    if (eff.kind === 'lucky') {
      const gain = Math.max(13, Math.min(s.cookies * 0.15, CO.cpsNow() * 900) + CO.clickValue() * 30) + 13;
      earn(gain); label = 'CHANCEUX ! +' + CO.fmt(gain);
    } else if (eff.kind === 'frenzy' || eff.kind === 'clickstorm') {
      addBuff(eff.buff);
    } else if (eff.kind === 'rgbstorm') {
      if (!CO.fever.active) { CO.fever.cooldownUntil = 0; startFever(); } else CO.fever.until += 5;
    } else if (eff.kind === 'gems') {
      const n = 3 + Math.floor(Math.random() * 6); s.gems += n; label = 'PLUIE DE GEMMES +' + n;
    }
    s.stats.golden++;
    questProgress('golden', 1);
    CO.sfx.play('golden');
    CO.emit('golden:click', { g, kind: eff.kind, label, color: eff.color });
  };

  /* ═════════════════════════ BOSSES ═════════════════════════ */
  CO.boss = null;
  const BOSS_UNLOCK = 5000;
  CO.bossUnlocked = () => CO.state.allTimeBaked >= BOSS_UNLOCK;
  let nextBossAt = null;
  function spawnBoss() {
    const d = pick(D.bosses), k = CO.state.stats.bossKills;
    const hp = Math.round(80 * (1 + 0.35 * Math.min(k, 30)));
    const t = CO.now();
    CO.boss = { ...d, hp, maxHp: hp, born: t, until: t + 30 };
    CO.sfx.play('boss');
    CO.emit('boss:spawn', { boss: CO.boss });
  }
  CO.spawnBoss = spawnBoss;
  function defeatBoss() {
    const b = CO.boss, s = CO.state; if (!b) return;
    CO.boss = null;
    s.stats.bossKills++;
    const cookies = Math.max(500, CO.cpsNow() * 300 + CO.clickValue() * 100);
    const gems = Math.min(20, 8 + s.stats.bossKills);
    earn(cookies); s.gems += gems;
    addBuff({ id: 'victory', name: 'Victoire', icon: 'ui:trophy', dur: 60, cps: 2 });
    questProgress('boss', 1);
    b.reward = { cookies, gems };
    nextBossAt = CO.now() + rand(240, 420);
    CO.sfx.play('levelup');
    CO.emit('boss:defeat', { boss: b });
    CO.toast(b.name + ' vaincu ! +' + CO.fmt(cookies) + ' cookies et +' + gems + ' gemmes', { icon: 'ui:sword', color: '#ffc93c' });
  }
  function escapeBoss() {
    const b = CO.boss, s = CO.state; if (!b) return;
    CO.boss = null;
    const stolen = Math.floor(s.cookies * 0.02);
    s.cookies -= stolen;
    b.stolen = stolen;
    nextBossAt = CO.now() + rand(240, 420);
    CO.sfx.play('lose');
    CO.emit('boss:escape', { boss: b });
    CO.toast(b.name + ' s\'est enfui' + (stolen > 0 ? ' avec ' + CO.fmt(stolen) + ' cookies…' : '…'), { icon: 'ui:warning', color: '#ff4d6d' });
  }

  /* ═════════════════════════ PETS ═════════════════════════ */
  CO.petDef = (id) => PET[id];
  CO.equippedPets = () => {
    const s = CO.state;
    return (s.equipped || []).map((uid) => s.pets.find((p) => p.uid === uid)).filter(Boolean).map((p) => ({ uid: p.uid, lvl: p.lvl, def: PET[p.id] })).filter((p) => p.def);
  };
  CO.petPower = (p) => { // human-readable bonus
    const b = PET[p.id].bonus, lv = 1 + 0.5 * (p.lvl - 1), out = [];
    if (b.all) out.push('Tout +' + Math.round(b.all * lv * 100) + ' %');
    if (b.cps) out.push('Prod. +' + Math.round(b.cps * lv * 100) + ' %');
    if (b.click) out.push('Clic +' + Math.round(b.click * lv * 100) + ' %');
    if (b.crit) out.push('Crit +' + Math.round(b.crit * 100) + ' %');
    if (b.golden) out.push('Dorés +' + Math.round((b.golden - 1) * 100) + ' %');
    return out.join(' · ');
  };
  CO.hatch = (eggId) => {
    const egg = EGG[eggId], s = CO.state;
    if (!egg) return null;
    if (s.gems < egg.cost) { CO.sfx.play('error'); return null; }
    s.gems -= egg.cost;
    const tot = Object.values(egg.odds).reduce((a, b) => a + b, 0);
    let r = Math.random() * tot, rarity = Object.keys(egg.odds)[0];
    for (const [k, w] of Object.entries(egg.odds)) { if ((r -= w) <= 0) { rarity = k; break; } }
    const def = pick(D.pets.filter((p) => p.rarity === rarity));
    let inst = s.pets.find((p) => p.id === def.id), isNew = false;
    if (inst) inst.lvl = Math.min(10, inst.lvl + 1);
    else { inst = { uid: s.petUid++, id: def.id, lvl: 1 }; s.pets.push(inst); isNew = true; }
    if (isNew && s.equipped.length < CO.maxPetSlots) s.equipped.push(inst.uid);
    else if (!isNew) { /* keep */ }
    else autoBestEquip(inst);
    s.stats.eggs++;
    questProgress('egg', 1);
    recalc();
    CO.emit('pets', {});
    const pet = { uid: inst.uid, id: def.id, def, lvl: inst.lvl, isNew, rarity };
    CO.emit('pet:hatch', { pet });
    return pet;
  };
  const RANK = { common: 0, rare: 1, epic: 2, legendary: 3, mythic: 4 };
  function autoBestEquip(inst) {
    // replace the weakest equipped pet if the new one outranks it
    const s = CO.state;
    let worst = null;
    for (const uid of s.equipped) { const p = s.pets.find((x) => x.uid === uid); if (!worst || RANK[PET[p.id].rarity] < RANK[PET[worst.id].rarity]) worst = p; }
    if (worst && RANK[PET[inst.id].rarity] > RANK[PET[worst.id].rarity]) s.equipped[s.equipped.indexOf(worst.uid)] = inst.uid;
  }
  CO.toggleEquip = (uid) => {
    const s = CO.state, i = s.equipped.indexOf(uid);
    if (i >= 0) s.equipped.splice(i, 1);
    else { if (s.equipped.length >= CO.maxPetSlots) { CO.sfx.play('error'); CO.toast('3 pets max équipés. Retire-en un d\'abord.', { icon: 'tab:pets' }); return false; } s.equipped.push(uid); }
    recalc(); CO.sfx.play('pop'); CO.emit('pets', {});
    return true;
  };

  /* ═════════════════════════ SKINS & THEMES ═════════════════════════ */
  CO.skin = () => SKIN[CO.state.skin] || D.skins[0];
  CO.theme = () => THEME[CO.state.theme] || D.themes[0];
  CO.skinUnlockMet = (sk) => {
    const u = sk.unlock; if (!u) return true;
    if (u.ach) return !!CO.state.achievements[u.ach];
    if (u.rebirths != null) return CO.state.rebirths >= u.rebirths;
    return false;
  };
  CO.buySkin = (id) => {
    const sk = SKIN[id], s = CO.state; if (!sk) return false;
    if (!s.skinsOwned[id]) {
      if (sk.unlock) { if (!CO.skinUnlockMet(sk)) { CO.sfx.play('error'); return false; } }
      else { if (s.gems < sk.cost) { CO.sfx.play('error'); return false; } s.gems -= sk.cost; }
      s.skinsOwned[id] = true; CO.sfx.play('upgrade'); CO.emit('buy', { kind: 'skin', id, n: 1 });
    }
    s.skin = id; CO.sfx.play('pop'); CO.emit('skin', { id });
    return true;
  };
  CO.buyTheme = (id) => {
    const th = THEME[id], s = CO.state; if (!th) return false;
    if (!s.themesOwned[id]) { if (s.gems < th.cost) { CO.sfx.play('error'); return false; } s.gems -= th.cost; s.themesOwned[id] = true; CO.sfx.play('upgrade'); CO.emit('buy', { kind: 'theme', id, n: 1 }); }
    s.theme = id; CO.emit('theme', { id });
    return true;
  };

  /* ═════════════════════════ ACHIEVEMENTS ═════════════════════════ */
  function checkAchievements() {
    const s = CO.state; let any = false;
    for (const a of D.achievements) {
      if (s.achievements[a.id]) continue;
      let ok = false; try { ok = a.check(s, CO); } catch (e) { ok = false; }
      if (ok) {
        s.achievements[a.id] = Date.now(); s.gems += a.gems; any = true;
        CO.sfx.play('achievement');
        CO.emit('achievement', { a });
      }
    }
    // unlockable skins become owned automatically
    for (const sk of D.skins) if (sk.unlock && !s.skinsOwned[sk.id] && CO.skinUnlockMet(sk)) { s.skinsOwned[sk.id] = true; CO.toast('Skin débloqué : ' + sk.name + ' !', { icon: 'tab:style', color: '#ffc93c' }); }
    if (any) recalc(true);
  }

  /* ═════════════════════════ QUESTS ═════════════════════════ */
  const QT = Object.fromEntries(D.quests.map((q) => [q.type, q]));
  function questAllowed(q) {
    if (q.needs === 'minigame') return Object.keys(D.minigameUnlocks).some((id) => CO.minigameUnlocked(id) && CO.minigames[id]);
    if (q.needs === 'boss') return CO.bossUnlocked();
    return true;
  }
  function newQuest(exclude) {
    const s = CO.state;
    const pool = D.quests.filter((q) => questAllowed(q) && !exclude.includes(q.type));
    const q = pick(pool.length ? pool : D.quests);
    const target = Math.max(1, Math.round(q.n(s, CO)));
    return { id: s.questUid++, type: q.type, target, progress: 0, gems: q.gems, done: false };
  }
  function ensureQuests() {
    const s = CO.state;
    s.quests = (s.quests || []).filter((q) => QT[q.type]);
    while (s.quests.length < 3) s.quests.push(newQuest(s.quests.map((q) => q.type)));
  }
  CO.questText = (q) => {
    const t = QT[q.type]; if (!t) return '';
    const n = t.fmt ? CO.fmt(q.target) : String(q.target);
    return t.text.replace('{n}', n);
  };
    function questProgress(type, amount, isMax) {
    const s = CO.state; if (!s.quests) return;
    for (const q of s.quests) {
      if (q.type !== type || q.done) continue;
      q.progress = isMax ? Math.max(q.progress, amount) : q.progress + amount;
      if (q.progress >= q.target) { q.progress = q.target; q.done = true; CO.sfx.play('coin'); CO.emit('quest:done', { q }); CO.toast('Quête terminée ! Réclame ta récompense.', { icon: 'tab:quests', color: '#b6ff3b' }); }
    }
  }
  CO.questProgress = questProgress;
  CO.claimQuest = (id) => {
    const s = CO.state, i = s.quests.findIndex((q) => q.id === id);
    if (i < 0 || !s.quests[i].done) return false;
    const q = s.quests[i];
    s.gems += q.gems; s.stats.quests++;
    s.quests.splice(i, 1, newQuest(s.quests.map((x) => x.type)));
    CO.sfx.play('coin', { pitch: 1.2 });
    CO.emit('quests', {});
    return q.gems;
  };
  CO.rerollQuest = (id) => {
    const s = CO.state, i = s.quests.findIndex((q) => q.id === id);
    if (i < 0) return false;
    if (s.gems < 3) { CO.sfx.play('error'); return false; }
    s.gems -= 3;
    s.quests.splice(i, 1, newQuest(s.quests.map((x) => x.type)));
    CO.sfx.play('whoosh'); CO.emit('quests', {});
    return true;
  };

  /* ═════════════════════════ MINIGAMES ═════════════════════════ */
  CO.minigames = CO.minigames || {};
  CO.registerMinigame = (def) => { CO.minigames[def.id] = def; CO.emit('minigame:registered', { id: def.id }); };
  CO.minigameUnlocked = (id) => { const u = D.minigameUnlocks[id]; return !u || CO.state.allTimeBaked >= u.baked; };
  CO.unit = () => Math.max(25, CO.cpsBase() * 60, CO.clickValue() * 90);
  CO.minigameApi = (id, onClose) => {
    const s = CO.state;
    const rec = (s.mg[id] = s.mg[id] || { best: 0, plays: 0 });
    let ended = 0;
    return {
      id,
      unit: () => CO.unit(),
      cookies: () => s.cookies,
      spend: (n) => { n = Math.floor(n); if (n > 0 && n <= s.cookies) { s.cookies -= n; return true; } return false; },
      grant: ({ cookies = 0, gems = 0 } = {}) => { if (cookies > 0) earn(cookies); if (gems > 0) s.gems += Math.floor(gems); },
      end: ({ score = 0, cookies = 0, gems = 0 } = {}) => {
        ended++;
        const isNewBest = score > rec.best;
        if (isNewBest) rec.best = score;
        rec.plays++;
        cookies = Math.max(0, cookies || 0); gems = Math.max(0, Math.floor(gems || 0));
        if (cookies > 0) earn(cookies);
        s.gems += gems;
        questProgress('minigame', 1);
        CO.emit('minigame:end', { id, score, cookies, gems, isNewBest });
        save();
        return { cookies, gems, best: rec.best, isNewBest };
      },
      best: () => rec.best,
      fmt: (n) => CO.fmt(n),
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
  CO.on('minigame:open', (p) => { mgOpen = p.id || true; music.duck(true); });
  CO.on('minigame:close', () => {
    mgOpen = null; music.duck(false);
    // don't punish players who were in a minigame
    const t = CO.now();
    if (CO.golden.next < t + 8) CO.golden.next = t + rand(8, 20);
    if (CO.boss) CO.boss.until = Math.max(CO.boss.until, t + 12);
  });

  CO.drawCookie = (ctx, x, y, r, opts = {}) => {
    if (CO.stage && CO.stage.drawCookie) return CO.stage.drawCookie(ctx, x, y, r, opts);
    const p = (opts.skin ? SKIN[opts.skin] || CO.skin() : CO.skin()).pal;
    ctx.save(); ctx.translate(x, y); ctx.rotate(opts.rot || 0);
    ctx.fillStyle = p.base; ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.fill();
    ctx.lineWidth = r * 0.08; ctx.strokeStyle = p.rim; ctx.stroke();
    ctx.fillStyle = p.chip;
    [[-0.4, -0.3], [0.35, -0.2], [0, 0.35], [-0.2, 0.1], [0.4, 0.4]].forEach(([a, b]) => { ctx.beginPath(); ctx.arc(a * r, b * r, r * 0.13, 0, Math.PI * 2); ctx.fill(); });
    ctx.restore();
  };

  /* ═════════════════════════ FREE GIFT (every 8 min) ═════════════════════════ */
  CO.GIFT_EVERY = 8 * 60 * 1000;
  CO.giftIn = () => Math.max(0, (CO.state.nextGift || 0) - Date.now()) / 1000;
  CO.claimGift = () => {
    const s = CO.state;
    if (CO.giftIn() > 0) { CO.sfx.play('error'); return null; }
    s.nextGift = Date.now() + CO.GIFT_EVERY; s.gifts = (s.gifts || 0) + 1;
    const r = Math.random();
    let res;
    if (r < 0.45) { const n = 4 + Math.floor(Math.random() * 7); s.gems += n; res = { kind: 'gems', icon: 'ui:gem', label: '+' + n + ' gemmes' }; }
    else if (r < 0.8) { const n = CO.unit() * (2 + Math.random() * 3); earn(n); res = { kind: 'cookies', icon: 'ui:cookie', label: '+' + CO.fmt(n) + ' cookies' }; }
    else { addBuff({ id: 'gift', name: 'Cadeau', icon: 'ui:gift', dur: 45, cps: 3 }); res = { kind: 'buff', icon: 'ui:gift', label: 'Production ×3 pendant 45 s' }; }
    CO.sfx.play('jackpot', { vol: 0.5 });
    CO.emit('gift', res);
    save();
    return res;
  };

  /* ═════════════════════════ REBIRTH ═════════════════════════ */
  CO.REBIRTH_MIN = 1e6;
  CO.rebirthGain = () => Math.floor(Math.sqrt(CO.state.totalBaked / CO.REBIRTH_MIN));
  CO.rebirth = () => {
    const s = CO.state, gain = CO.rebirthGain();
    if (gain < 1) { CO.sfx.play('error'); return false; }
    s.stars += gain; s.rebirths++;
    s.gems += 10 * gain;
    s.cookies = 0; s.totalBaked = 0; s.clickBaked = 0;
    D.buildings.forEach((b) => (s.buildings[b.id] = 0));
    s.upgrades = {};
    CO.buffs = []; CO.golden.list = []; CO.boss = null;
    CO.combo.count = 0; CO.combo.mult = 1; CO.combo.heat = 0;
    if (CO.fever.active) endFever();
    recalc();
    CO.sfx.play('levelup'); CO.sfx.play('jackpot', { vol: 0.6 });
    CO.emit('rebirth', { stars: gain });
    save();
    return gain;
  };

  /* ═════════════════════════ AUDIO ═════════════════════════ */
  let actx = null, master = null, sfxBus = null, musicBus = null, comp = null, noiseBuf = null;
  function ensureAudio() {
    if (actx) return actx;
    try {
      const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return null;
      actx = new AC();
      comp = actx.createDynamicsCompressor(); comp.threshold.value = -14; comp.ratio.value = 4; comp.attack.value = 0.003; comp.release.value = 0.18;
      master = actx.createGain(); master.gain.value = 0.9;
      sfxBus = actx.createGain(); sfxBus.gain.value = CO.settings.sfx;
      musicBus = actx.createGain(); musicBus.gain.value = 0;
      sfxBus.connect(master); musicBus.connect(master); master.connect(comp); comp.connect(actx.destination);
      noiseBuf = actx.createBuffer(1, actx.sampleRate * 1, actx.sampleRate);
      const d = noiseBuf.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
      return actx;
    } catch (e) { actx = null; return null; }
  }
  function unlockAudio() {
    const c = ensureAudio(); if (!c) return;
    if (c.state === 'suspended') c.resume().catch(() => {});
    if (CO.settings.musicOn && !music.playing) music.start();
  }
  CO.unlockAudio = unlockAudio;
  CO.audio = () => { const c = ensureAudio(); if (!c) return null; if (c.state === 'suspended') c.resume().catch(() => {}); return { ctx: c, out: sfxBus }; };
  CO.applyVolumes = () => {
    if (!actx) return;
    const t = actx.currentTime;
    sfxBus.gain.setTargetAtTime(CO.settings.sfx, t, 0.03);
    musicBus.gain.setTargetAtTime(CO.settings.musicOn && !music.ducked ? CO.settings.music * 0.55 : 0, t, 0.08);
  };

  let voices = 0;
  let routed = null; // per-call volume bus used by CO.sfx.play
  function voice(dur) { voices++; setTimeout(() => voices--, dur * 1000 + 60); }
  function tone(freq, dur, o = {}) {
    const c = actx; const t = c.currentTime + (o.delay || 0);
    const osc = c.createOscillator(), g = c.createGain();
    osc.type = o.type || 'sine';
    osc.frequency.setValueAtTime(freq, t);
    if (o.slide) osc.frequency.exponentialRampToValueAtTime(Math.max(20, o.slide), t + (o.slideT || dur));
    if (o.detune) osc.detune.value = o.detune;
    const v = (o.vol != null ? o.vol : 0.25);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(v, t + (o.attack || 0.005));
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    let node = osc;
    if (o.filter) { const f = c.createBiquadFilter(); f.type = o.filter; f.frequency.value = o.ff || 2000; f.Q.value = o.q || 1; node.connect(f); node = f; }
    node.connect(g); g.connect(o.out || routed || sfxBus);
    osc.start(t); osc.stop(t + dur + 0.02);
    voice(dur + (o.delay || 0));
  }
  function noise(dur, o = {}) {
    const c = actx; const t = c.currentTime + (o.delay || 0);
    const src = c.createBufferSource(); src.buffer = noiseBuf; src.loop = true;
    const f = c.createBiquadFilter(); f.type = o.filter || 'bandpass'; f.frequency.setValueAtTime(o.ff || 2000, t); f.Q.value = o.q || 1;
    if (o.slide) f.frequency.exponentialRampToValueAtTime(o.slide, t + dur);
    const g = c.createGain(); const v = o.vol != null ? o.vol : 0.2;
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(v, t + (o.attack || 0.003)); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f); f.connect(g); g.connect(o.out || routed || sfxBus);
    src.start(t, Math.random() * 0.5); src.stop(t + dur + 0.02);
    voice(dur + (o.delay || 0));
  }
  const NOTE = (n) => 440 * Math.pow(2, (n - 69) / 12);
  const SFX = {
    click(p) {
      const k = CO.settings.clickSound;
      if (k === 'crunch') { noise(0.07, { ff: 2400 * p, q: 0.8, vol: 0.35 }); noise(0.05, { ff: 900 * p, q: 2, vol: 0.2, delay: 0.02 }); }
      else if (k === 'laser') tone(1500 * p, 0.12, { type: 'square', slide: 180, vol: 0.09 });
      else if (k === 'chip') { tone(880 * p, 0.05, { type: 'square', vol: 0.08 }); tone(1320 * p, 0.05, { type: 'square', vol: 0.07, delay: 0.045 }); }
      else if (k === 'bubble') tone(320 * p, 0.09, { slide: 950 * p, vol: 0.3 });
      else { tone(720 * p, 0.07, { slide: 240 * p, vol: 0.32 }); noise(0.03, { ff: 3000, vol: 0.08 }); }
    },
    crit(p) { tone(220 * p, 0.28, { type: 'sawtooth', slide: 55, vol: 0.22, filter: 'lowpass', ff: 1400 }); noise(0.12, { ff: 4000, q: 0.6, vol: 0.3 }); tone(1760 * p, 0.25, { type: 'triangle', vol: 0.12, delay: 0.02 }); },
    buy(p) { tone(NOTE(84) * p, 0.08, { type: 'triangle', vol: 0.2 }); tone(NOTE(88) * p, 0.12, { type: 'triangle', vol: 0.2, delay: 0.06 }); },
    upgrade(p) { [72, 76, 79, 84, 88].forEach((n, i) => tone(NOTE(n) * p, 0.16, { type: 'square', vol: 0.07, delay: i * 0.045, filter: 'lowpass', ff: 3500 })); },
    error() { tone(160, 0.09, { type: 'square', vol: 0.12, filter: 'lowpass', ff: 900 }); tone(120, 0.12, { type: 'square', vol: 0.12, delay: 0.1, filter: 'lowpass', ff: 900 }); },
    golden(p) { [79, 83, 86, 91, 95].forEach((n, i) => tone(NOTE(n) * p, 0.4, { type: 'sine', vol: 0.12, delay: i * 0.05 })); noise(0.5, { filter: 'highpass', ff: 7000, vol: 0.06 }); },
    achievement() { [[72, 0], [76, 0.1], [79, 0.2], [84, 0.3], [88, 0.3], [91, 0.3]].forEach(([n, d]) => tone(NOTE(n), 0.45, { type: 'square', vol: 0.07, delay: d, filter: 'lowpass', ff: 4000 })); tone(NOTE(48), 0.6, { type: 'triangle', vol: 0.2, delay: 0.3 }); },
    combo(p) { tone(600 * p, 0.12, { type: 'square', slide: 1200 * p, vol: 0.08, filter: 'lowpass', ff: 3000 }); },
    fever() { noise(1.2, { filter: 'bandpass', ff: 300, slide: 8000, q: 1.5, vol: 0.25, attack: 0.9 }); [57, 64, 69, 72, 76].forEach((n) => tone(NOTE(n), 1.4, { type: 'sawtooth', vol: 0.05, delay: 0.9, filter: 'lowpass', ff: 2500 })); tone(55, 0.8, { type: 'sine', vol: 0.5, delay: 0.9, slide: 40 }); },
    hatch() { noise(0.15, { ff: 1500, vol: 0.3 }); [84, 88, 91, 96].forEach((n, i) => tone(NOTE(n), 0.5, { type: 'triangle', vol: 0.12, delay: 0.15 + i * 0.07 })); },
    coin(p) { tone(988 * p, 0.07, { type: 'square', vol: 0.08 }); tone(1319 * p, 0.3, { type: 'square', vol: 0.08, delay: 0.07 }); },
    whoosh() { noise(0.3, { filter: 'bandpass', ff: 400, slide: 3000, q: 2, vol: 0.2 }); },
    hit(p) { tone(140 * p, 0.15, { slide: 50, vol: 0.4 }); noise(0.08, { ff: 1800, vol: 0.25 }); },
    slice(p) { noise(0.12, { filter: 'highpass', ff: 2500 * p, slide: 9000, vol: 0.22 }); },
    miss() { tone(300, 0.2, { type: 'triangle', slide: 120, vol: 0.18 }); },
    perfect(p) { tone(NOTE(88) * p, 0.18, { type: 'triangle', vol: 0.14 }); tone(NOTE(95) * p, 0.22, { type: 'sine', vol: 0.1, delay: 0.03 }); },
    good(p) { tone(NOTE(84) * p, 0.14, { type: 'triangle', vol: 0.12 }); },
    jump(p) { tone(380 * p, 0.12, { slide: 760 * p, vol: 0.18, type: 'triangle' }); },
    spin() { for (let i = 0; i < 6; i++) noise(0.03, { ff: 3000, vol: 0.08, delay: i * 0.05 }); },
    reel(p) { noise(0.05, { ff: 1200, q: 3, vol: 0.3 }); tone(90 * p, 0.08, { vol: 0.3 }); },
    win() { [72, 76, 79, 84].forEach((n, i) => tone(NOTE(n), 0.25, { type: 'square', vol: 0.08, delay: i * 0.08, filter: 'lowpass', ff: 4000 })); },
    jackpot() { for (let i = 0; i < 12; i++) tone(NOTE(72 + [0, 4, 7, 12, 16, 19][i % 6] + (i >= 6 ? 12 : 0)), 0.3, { type: 'square', vol: 0.07, delay: i * 0.06, filter: 'lowpass', ff: 5000 }); for (let i = 0; i < 8; i++) tone(1319 + i * 50, 0.2, { type: 'square', vol: 0.04, delay: 0.7 + i * 0.07 }); },
    lose() { [[60, 0], [59, 0.25], [58, 0.5], [57, 0.75]].forEach(([n, d], i) => tone(NOTE(n), i === 3 ? 0.7 : 0.25, { type: 'sawtooth', vol: 0.07, delay: d, filter: 'lowpass', ff: 1200, slide: i === 3 ? NOTE(55) : undefined })); },
    boss() { [40, 41, 46].forEach((n) => tone(NOTE(n), 1.1, { type: 'sawtooth', vol: 0.09, filter: 'lowpass', ff: 700 })); noise(0.9, { filter: 'lowpass', ff: 200, vol: 0.3 }); },
    levelup() { [60, 64, 67, 72, 76, 79, 84].forEach((n, i) => tone(NOTE(n), 0.2, { type: 'square', vol: 0.07, delay: i * 0.05, filter: 'lowpass', ff: 4500 })); },
    tick(p) { tone(2000 * p, 0.02, { type: 'square', vol: 0.04 }); },
    pop(p) { tone(500 * p, 0.06, { slide: 900 * p, vol: 0.22 }); },
  };
  CO.sfx = {
    play(name, o = {}) {
      if (!CO.settings.sfx) return;
      const c = ensureAudio(); if (!c || c.state !== 'running') return;
      if (voices > 40 && (name === 'click' || name === 'tick')) return;
      const fn = SFX[name]; if (!fn) return;
      const v = o.vol != null ? o.vol : 1;
      try {
        if (v !== 1) { const g = c.createGain(); g.gain.value = v; g.connect(sfxBus); routed = g; fn(o.pitch || 1); routed = null; setTimeout(() => g.disconnect(), 3000); }
        else fn(o.pitch || 1);
      } catch (e) { routed = null; }
    },
  };

  /* ─── Music: procedural synthwave loop (A minor: Am F C G) ─── */
  const music = (() => {
    const m = { playing: false, ducked: false, level: 0 };
    let timer = null, step = 0, nextT = 0, bar = 0, beatN = 0;
    const CH = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]; // Am F C G
    const BASS = [45, 41, 36, 43];
    const stepDur = () => 60 / CO.bpm / 4;
    // Classical melodies (public domain) over the same drum engine. mel: [midi|0 (rest), length in 16th steps]
    const TRI = { Am: [57, 60, 64], E: [56, 59, 64], Dm: [57, 62, 65], C: [55, 60, 64], G: [55, 59, 62], F: [57, 60, 65] };
    const ROOT = { Am: 45, E: 40, Dm: 38, C: 36, G: 43, F: 41 };
    const TRACKS = {
      korobeiniki: { ch: ['E', 'Am', 'E', 'Am', 'Dm', 'C', 'E', 'Am'], wave: 'square',
        mel: [[76, 4], [71, 2], [72, 2], [74, 4], [72, 2], [71, 2], [69, 4], [69, 2], [72, 2], [76, 4], [74, 2], [72, 2], [71, 6], [72, 2], [74, 4], [76, 4], [72, 4], [69, 4], [69, 8],
          [0, 2], [74, 4], [77, 2], [81, 4], [79, 2], [77, 2], [76, 6], [72, 2], [76, 4], [74, 2], [72, 2], [71, 4], [71, 2], [72, 2], [74, 4], [76, 4], [72, 4], [69, 4], [69, 8]] },
      ode: { ch: ['C', 'G', 'C', 'G', 'C', 'G', 'C', 'C'], wave: 'triangle',
        mel: [[76, 4], [76, 4], [77, 4], [79, 4], [79, 4], [77, 4], [76, 4], [74, 4], [72, 4], [72, 4], [74, 4], [76, 4], [76, 6], [74, 2], [74, 8],
          [76, 4], [76, 4], [77, 4], [79, 4], [79, 4], [77, 4], [76, 4], [74, 4], [72, 4], [72, 4], [74, 4], [76, 4], [74, 6], [72, 2], [72, 8]] },
      montagne: { ch: ['Am', 'E', 'Am', 'E', 'Am', 'E', 'Am', 'E'], wave: 'sawtooth',
        mel: [].concat(...[0, 1].map(() => [[69, 2], [71, 2], [72, 2], [74, 2], [76, 2], [72, 2], [76, 4], [75, 2], [71, 2], [75, 4], [74, 2], [70, 2], [74, 4],
          [69, 2], [71, 2], [72, 2], [74, 2], [76, 2], [72, 2], [76, 2], [81, 2], [79, 2], [76, 2], [72, 2], [76, 2], [79, 8]])) },
      elise: { ch: ['E', 'Am', 'E', 'E', 'Am', 'Am', 'E', 'Am', 'E', 'E', 'Am', 'Am'], wave: 'triangle',
        mel: [].concat(...[0, 1].map(() => [[76, 2], [75, 2], [76, 2], [75, 2], [76, 2], [71, 2], [74, 2], [72, 2], [69, 6], [60, 2], [64, 2], [69, 2], [71, 4],
          [64, 2], [68, 2], [71, 2], [72, 6], [64, 2], [76, 2], [75, 2], [76, 2], [75, 2], [76, 2], [71, 2], [74, 2], [72, 2], [69, 6], [60, 2], [64, 2], [69, 2], [71, 4], [64, 2], [72, 2], [71, 2], [69, 10]])) },
    };
    Object.values(TRACKS).forEach((tr) => { tr.at = []; let i = 0; tr.mel.forEach(([n, l]) => { if (n) tr.at[i] = [n, l]; i += l; }); tr.len = Math.max(i, tr.ch.length * 16); });
    CO.musicTracks = [['synthwave', 'Synthwave (originale)'], ['korobeiniki', 'Korobeïniki (thème Tetris)'], ['ode', 'Hymne à la Joie — Beethoven'], ['montagne', 'Antre du Roi de la Montagne — Grieg'], ['elise', 'Lettre à Élise — Beethoven']];
    function kick(t) { const o = actx.createOscillator(), g = actx.createGain(); o.frequency.setValueAtTime(150, t); o.frequency.exponentialRampToValueAtTime(42, t + 0.14); g.gain.setValueAtTime(0.9, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.3); o.connect(g); g.connect(musicBus); o.start(t); o.stop(t + 0.32); }
    function snare(t) { const s = actx.createBufferSource(); s.buffer = noiseBuf; const f = actx.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 1800; f.Q.value = 0.7; const g = actx.createGain(); g.gain.setValueAtTime(0.45, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.18); s.connect(f); f.connect(g); g.connect(musicBus); s.start(t, Math.random() * 0.5); s.stop(t + 0.2); const o = actx.createOscillator(), g2 = actx.createGain(); o.frequency.value = 190; g2.gain.setValueAtTime(0.25, t); g2.gain.exponentialRampToValueAtTime(0.001, t + 0.1); o.connect(g2); g2.connect(musicBus); o.start(t); o.stop(t + 0.12); }
    function hat(t, v) { const s = actx.createBufferSource(); s.buffer = noiseBuf; const f = actx.createBiquadFilter(); f.type = 'highpass'; f.frequency.value = 8000; const g = actx.createGain(); g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.05); s.connect(f); f.connect(g); g.connect(musicBus); s.start(t, Math.random() * 0.5); s.stop(t + 0.06); }
    function synth(freq, t, dur, type, vol, ff) { const o = actx.createOscillator(), o2 = actx.createOscillator(), f = actx.createBiquadFilter(), g = actx.createGain(); o.type = o2.type = type; o.frequency.value = freq; o2.frequency.value = freq; o2.detune.value = 9; f.type = 'lowpass'; f.frequency.setValueAtTime(ff, t); f.Q.value = 3; g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + 0.01); g.gain.exponentialRampToValueAtTime(0.0001, t + dur); o.connect(f); o2.connect(f); f.connect(g); g.connect(musicBus); o.start(t); o2.start(t); o.stop(t + dur + 0.02); o2.stop(t + dur + 0.02); }
    function schedule() {
      if (!actx) return;
      while (nextT < actx.currentTime + 0.15) {
        const t = nextT, s = step % 16, chord = (bar >> 1) % 4, hot = m.level > 0;
        if (s % 4 === 0) {
          kick(t);
          const n = beatN++; const delay = Math.max(0, (t - actx.currentTime) * 1000);
          setTimeout(() => { beatOrigin = CO.now(); CO.emit('beat', { n }); }, delay);
        }
        if (s === 4 || s === 12) snare(t);
        if (s % 2 === 1 || hot) hat(t, s % 2 === 1 ? 0.12 : 0.05);
        const tr = TRACKS[CO.settings.track];
        if (tr) {
          const pos = step % tr.len, cn = tr.ch[Math.floor(pos / 16) % tr.ch.length];
          if (s % 2 === 0) synth(NOTE(ROOT[cn] + (s % 4 === 2 ? 12 : 0)), t, stepDur() * 1.8, 'sawtooth', 0.14, hot ? 1400 : 700);
          if (s === 0) TRI[cn].forEach((n) => synth(NOTE(n), t, stepDur() * 15, 'sawtooth', 0.025, 1400));
          const nt = tr.at[pos]; if (nt) synth(NOTE(nt[0]), t, stepDur() * nt[1] * 0.95, tr.wave, hot ? 0.075 : 0.06, hot ? 5000 : 3200);
        } else {
        if (s % 2 === 0) synth(NOTE(BASS[chord] + (s % 4 === 2 ? 12 : 0)), t, stepDur() * 1.8, 'sawtooth', 0.16, hot ? 1400 : 700);
        if (s === 0 && bar % 2 === 0) CH[chord].forEach((n) => synth(NOTE(n + 12), t, stepDur() * 30, 'sawtooth', 0.035, 1600));
        if ((hot || bar % 8 >= 4)) { const arp = CH[chord]; synth(NOTE(arp[s % 3] + 24 + (s % 8 >= 6 ? 12 : 0)), t, stepDur() * 0.9, 'square', hot ? 0.05 : 0.03, hot ? 5000 : 2600); }
        }
        nextT += stepDur(); step++; if (step % 16 === 0) bar++;
      }
    }
    m.start = () => {
      if (!ensureAudio() || m.playing) return;
      m.playing = true; step = 0; bar = 0; nextT = actx.currentTime + 0.08;
      timer = setInterval(schedule, 30); schedule();
      CO.applyVolumes();
    };
    m.stop = () => { m.playing = false; clearInterval(timer); timer = null; CO.applyVolumes(); };
    m.duck = (on) => { m.ducked = on; CO.applyVolumes(); };
    m.intensity = (l) => { m.level = l; };
    return m;
  })();
  CO.music = music;
  // virtual beat clock when music is off (for beat_pulse)
  setInterval(() => {
    if (music.playing) return;
    const t = CO.now(), per = 60 / CO.bpm;
    if (t - beatOrigin >= per) { beatOrigin += per * Math.floor((t - beatOrigin) / per); CO.emit('beat', { n: 0 }); }
  }, 20);

  CO.setSetting = (k, v) => {
    CO.settings[k] = v;
    if (k === 'sfx' || k === 'music') CO.applyVolumes();
    if (k === 'track' && music.playing) { music.stop(); music.start(); }
    if (k === 'musicOn') { if (v) { unlockAudio(); music.start(); } else music.stop(); }
    CO.emit('settings', { settings: CO.settings, key: k });
    saveSoon();
  };

  /* ═════════════════════════ TOAST ═════════════════════════ */
  CO.toast = (text, opts = {}) => CO.emit('toast', { text, ...opts });

  /* ═════════════════════════ SAVE / LOAD ═════════════════════════ */
  let saveTimer = null, saveBlocked = false;
  const BACKUP_KEY = SAVE_KEY + '-backup';
  // other tab took over the save slot → stop writing so we never clobber newer progress
  const TAB_ID = Math.random().toString(36).slice(2);
  let tabChan = null;
  try {
    tabChan = new BroadcastChannel('cookie-overdrive');
    tabChan.onmessage = (e) => {
      const m = e.data || {};
      if (m.type === 'hello' && m.id !== TAB_ID && !saveBlocked) { save(); tabChan.postMessage({ type: 'yield', to: m.id }); saveBlocked = true; CO.emit('tab:blocked', {}); }
      else if (m.type === 'yield' && m.to === TAB_ID && load()) { afterLoad(); CO.emit('load', { imported: true }); }
    };
  } catch (e) { tabChan = null; }
  function save() {
    if (saveBlocked) return false;
    CO.state.lastSave = Date.now();
    let raw;
    try { raw = JSON.stringify(CO.state); } catch (e) { return false; }
    try {
      // rotate: keep the previous good save as a backup (≥ 5 min apart) in case the main slot gets corrupted
      const prev = localStorage.getItem(SAVE_KEY);
      if (prev && prev !== raw) {
        const bk = localStorage.getItem(BACKUP_KEY);
        let bkAge = Infinity;
        try { bkAge = Date.now() - (JSON.parse(bk || '{}').lastSave || 0); } catch (e) { /* corrupt backup */ }
        if (bkAge > 5 * 60 * 1000) { try { JSON.parse(prev); localStorage.setItem(BACKUP_KEY, prev); } catch (e) { /* skip bad prev */ } }
      }
      localStorage.setItem(SAVE_KEY, raw);
      return true;
    } catch (e) { return false; }
  }
  function saveSoon() { clearTimeout(saveTimer); saveTimer = setTimeout(save, 800); }
  CO.save = save;
  function adopt(obj) {
    const st = merge(defaultState(), obj);
    st.settings = merge(defaultSettings(), obj && obj.settings);
    // sanity
    D.buildings.forEach((b) => { st.buildings[b.id] = Math.max(0, Math.floor(+st.buildings[b.id] || 0)); });
    ['cookies', 'totalBaked', 'allTimeBaked', 'gems', 'stars', 'rebirths', 'clicks'].forEach((k) => { st[k] = +st[k]; if (!Number.isFinite(st[k]) || st[k] < 0) st[k] = 0; });
    if (!Number.isFinite(+st.lastSave) || +st.lastSave > Date.now() + 60000) st.lastSave = Date.now();
    st.pets = (st.pets || []).filter((p) => PET[p.id]);
    st.equipped = (st.equipped || []).filter((uid) => st.pets.some((p) => p.uid === uid)).slice(0, CO.maxPetSlots);
    if (!SKIN[st.skin] || !st.skinsOwned[st.skin]) st.skin = 'classic';
    if (!THEME[st.theme] || !st.themesOwned[st.theme]) st.theme = 'synthwave';
    CO.state = st; CO.settings = st.settings;
  }
  function load() {
    let raw = null;
    try { raw = localStorage.getItem(SAVE_KEY); } catch (e) { raw = null; }
    const tryRaw = (r) => { if (!r) return false; try { const o = JSON.parse(r); if (!isObj(o)) return false; adopt(o); return true; } catch (e) { return false; } };
    if (tryRaw(raw)) return true;
    let bk = null;
    try { bk = localStorage.getItem(BACKUP_KEY); } catch (e) { bk = null; }
    if (tryRaw(bk)) { CO.restoredBackup = true; return true; }
    return false;
  }
  CO.hasBackup = () => { try { return !!localStorage.getItem(BACKUP_KEY); } catch (e) { return false; } };
  CO.restoreBackup = () => {
    let bk = null;
    try { bk = localStorage.getItem(BACKUP_KEY); } catch (e) { bk = null; }
    if (!bk) return false;
    try { const o = JSON.parse(bk); if (!isObj(o)) return false; adopt(o); afterLoad(); CO.emit('load', { imported: true }); return true; } catch (e) { return false; }
  };
  CO.saveBlocked = () => saveBlocked;
  CO.exportSave = () => {
    save();
    try { return 'CO1|' + btoa(unescape(encodeURIComponent(JSON.stringify(CO.state)))); } catch (e) { return ''; }
  };
  CO.importSave = (str) => {
    try {
      str = String(str || '').trim();
      if (str.startsWith('CO1|')) str = str.slice(4);
      const obj = JSON.parse(decodeURIComponent(escape(atob(str))));
      if (!obj || typeof obj !== 'object' || obj.cookies == null) return false;
      adopt(obj); afterLoad(); save();
      CO.emit('load', { imported: true });
      return true;
    } catch (e) { return false; }
  };
  CO.hardReset = () => {
    const keepSettings = CO.state.settings;
    CO.state = defaultState(); CO.state.settings = keepSettings; CO.settings = keepSettings;
    CO.buffs = []; CO.golden.list = []; CO.boss = null; CO.combo.count = 0; CO.combo.mult = 1; CO.combo.heat = 0; CO.fever.active = false;
    afterLoad(); save();
    CO.emit('load', { reset: true });
  };
  function afterLoad() {
    recalc(true);
    ensureQuests();
    CO.emit('visuals', { vis: CO.vis, added: [] });
    CO.emit('skin', { id: CO.state.skin });
    CO.emit('theme', { id: CO.state.theme });
    CO.emit('pets', {});
  }

  /* ═════════════════════════ LOOP ═════════════════════════ */
  let lastT = CO.now(), secAcc = 0, saveAcc = 0;
  function tick() {
    const t = CO.now();
    let dt = t - lastT; lastT = t;
    if (dt <= 0) return; if (dt > 3600) dt = 3600;
    const s = CO.state;
    // production
    const cps = CO.cpsNow();
    if (cps > 0) earn(cps * dt, 'cps');
    // combo decay
    const c = CO.combo;
    if (!CO.fever.active && t - lastClickT > 0.7 && c.count > 0) {
      c.count = Math.max(0, c.count - dt * (18 + c.count * 0.6));
      c.mult = comboMultFor(c.count);
      c.heat = Math.min(t < CO.fever.cooldownUntil ? 0.95 : 1, c.count / FEVER_AT);
    }
    if (CO.fever.active && t >= CO.fever.until) endFever();
    // buffs
    if (CO.buffs.length) {
      const keep = [];
      for (const b of CO.buffs) { if (t < b.until) keep.push(b); else CO.emit('buff:end', { buff: b }); }
      CO.buffs = keep;
    }
    // golden
    for (const g of CO.golden.list.slice()) if (t - g.born > g.life) { CO.golden.list.splice(CO.golden.list.indexOf(g), 1); CO.emit('golden:expire', { g }); }
    if (!mgOpen && t >= CO.golden.next) {
      if (CO.golden.list.length < 2 && document.visibilityState !== 'hidden') spawnGolden();
      CO.golden.next = t + rand(45, 110) / M.goldenFreq;
    } else if (mgOpen) CO.golden.next = Math.max(CO.golden.next, t + 5);
    // boss
    if (CO.boss && t >= CO.boss.until) escapeBoss();
    if (!CO.boss && CO.bossUnlocked() && !mgOpen && document.visibilityState !== 'hidden') {
      if (nextBossAt == null) nextBossAt = t + rand(90, 150);
      if (t >= nextBossAt) spawnBoss();
    }
    // per-second
    secAcc += dt; saveAcc += dt;
    if (secAcc >= 1) {
      s.stats.playTime += secAcc; secAcc = 0;
      const base = CO.cpsBase(); if (base > s.stats.bestCps) s.stats.bestCps = base;
      checkAchievements();
      CO.emit('second', {});
    }
    if (saveAcc >= 12) { saveAcc = 0; save(); }
    CO.emit('tick', { dt });
  }

  /* ═════════════════════════ BOOT ═════════════════════════ */
  CO.offline = null;
  CO.start = (hotData) => {
    let loaded = false;
    if (hotData && hotData.state && typeof hotData.state === 'object') { try { adopt(hotData.state); loaded = true; } catch (e) { loaded = false; } }
    if (!loaded) loaded = load();
    afterLoad();
    // offline progress (50 % efficiency, 12 h cap)
    if (loaded && !(hotData && hotData.state)) {
      const away = Math.min(12 * 3600, (Date.now() - (CO.state.lastSave || Date.now())) / 1000);
      if (away > 60) {
        const gain = CO.cpsBase() * away * 0.5;
        if (gain > 0) { earn(gain, 'offline'); CO.offline = { away, gain }; }
      }
    }
    // daily gift: gems for coming back each day, streak bonus up to 7 days
    try {
      const day = new Date().toISOString().slice(0, 10), st = CO.state;
      if (st.lastDaily !== day) {
        const yest = new Date(Date.now() - 864e5).toISOString().slice(0, 10);
        st.dailyStreak = st.lastDaily === yest ? Math.min(7, (+st.dailyStreak || 0) + 1) : 1;
        st.lastDaily = day;
        const g = 2 + st.dailyStreak;
        st.gems += g;
        CO.daily = { gems: g, streak: st.dailyStreak };
        setTimeout(() => CO.toast('Cadeau du jour : +' + g + ' gemmes (série ' + st.dailyStreak + '/7)', { icon: 'ui:gem', color: '#ffcc33' }), 2500);
      }
    } catch (e) { /* optional */ }
    lastT = CO.now();
    setInterval(tick, 50);
    window.addEventListener('pagehide', save);
    window.addEventListener('beforeunload', save);
    if (tabChan) tabChan.postMessage({ type: 'hello', id: TAB_ID });
    try { if (navigator.storage && navigator.storage.persist) navigator.storage.persist().catch(() => {}); } catch (e) { /* optional */ }
    document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'hidden') save(); });
    // hot-reload snapshot for republishes
    try { if (window.claude && window.claude.hot && typeof window.claude.hot.snapshot === 'function') window.claude.hot.snapshot(() => ({ state: CO.state })); } catch (e) { /* optional */ }
    CO.emit('load', { loaded });
  };
})();
