/* COOKIE OVERDRIVE — ui.js
 * DOM layer: HUD, tabs (shop, upgrades, games, pets, style, quests, rebirth, options),
 * toasts, achievement popups, egg hatching, minigame overlay host, ticker.
 * No emojis: every picture comes from CO.art (vector illustrations).
 */
(function () {
  'use strict';
  const CO = window.CO, D = CO.data;
  const $ = (s, r) => (r || document).querySelector(s);
  const S = () => CO.state;
  const fmt = (n, o) => CO.fmt(n, o);
  const I = (name, cls) => CO.art.el(name, cls);

  /* ─────────── tiny DOM helper ─────────── */
  function h(sel, attrs, ...kids) {
    const m = sel.match(/^([a-z0-9]+)?((?:[.#][\w-]+)*)$/i) || [];
    const el = document.createElement(m[1] || 'div');
    (m[2] || '').replace(/([.#])([\w-]+)/g, (_, t, v) => { if (t === '.') el.classList.add(v); else el.id = v; });
    if (attrs && (typeof attrs !== 'object' || attrs instanceof Node || Array.isArray(attrs))) { kids.unshift(attrs); attrs = null; }
    if (attrs) for (const [k, v] of Object.entries(attrs)) {
      if (v == null || v === false) continue;
      if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2), v);
      else if (k === 'style' && typeof v === 'object') { for (const [sk, sv] of Object.entries(v)) { if (sk.startsWith('--')) el.style.setProperty(sk, sv); else el.style[sk] = sv; } }
      else if (v === true) el.setAttribute(k, '');
      else el.setAttribute(k, v);
    }
    const add = (k) => { if (k == null || k === false) return; if (Array.isArray(k)) k.forEach(add); else el.append(k instanceof Node ? k : document.createTextNode(String(k))); };
    kids.forEach(add);
    return el;
  }
  const clampN = (v, a, b) => Math.max(a, Math.min(b, v));
  let lsOk = true;
  const lsGet = (k) => { try { return localStorage.getItem(k); } catch (e) { lsOk = false; return null; } };
  const lsSet = (k, v) => { try { localStorage.setItem(k, v); } catch (e) { lsOk = false; } };
  const gem = (n) => [String(n), I('ui:gem')];
  const cookieAmt = (txt) => [I('ui:cookie'), ' ', txt];

  const ui = (CO.ui = { tab: 'shop', overlay: null });

  const TABS = [
    { id: 'shop', l: 'Shop' }, { id: 'upgrades', l: 'Upgrades' }, { id: 'games', l: 'Jeux' }, { id: 'pets', l: 'Pets' },
    { id: 'style', l: 'Style' }, { id: 'quests', l: 'Quêtes' }, { id: 'rebirth', l: 'Rebirth' }, { id: 'options', l: 'Options' },
  ];
  const MG_ORDER = ['ninja', 'flappy', 'rhythm', 'slots'];
  const MG_FALLBACK = {
    ninja: { name: 'Cookie Ninja', color: '#ff2bd6', tagline: 'Tranche les cookies, évite les brocolis.' },
    flappy: { name: 'Flappy Cookie', color: '#1ff4ff', tagline: 'Fais voler ton cookie entre les verres de lait.' },
    rhythm: { name: 'Crunch Rythme', color: '#b6ff3b', tagline: 'Croque les cookies en rythme.' },
    slots: { name: 'Casino Crumble', color: '#ffc93c', tagline: 'Mise tes cookies. Jackpot = aura infinie.' },
  };
  const mgDef = (id) => CO.minigames[id] || MG_FALLBACK[id];

  const QUEST_ICON = { clicks: 'ui:tap', bake: 'ui:cookie', buy: 'tab:shop', upgrade: 'tab:upgrades', golden: 'ui:golden', combo: 'ui:fire', crit: 'ui:sparkle', minigame: 'tab:games', boss: 'ui:sword', fever: 'ui:rainbow' };
  function achIcon(a) {
    const id = a.id;
    const map = [['a_click', 'ui:tap'], ['a_bake', 'ui:cookie'], ['a_cps', 'ui:bolt'], ['a_cursor', 'b:cursor'], ['a_granny', 'b:granny'], ['a_b', 'tab:shop'], ['a_golden', 'ui:golden'], ['a_crit', 'ui:sparkle'],
      ['a_combo', 'ui:fire'], ['a_fever', 'ui:rainbow'], ['a_boss', 'ui:sword'], ['a_mg', 'tab:games'], ['a_egg', 'tab:pets'], ['a_legend', 'pet:unicorn'], ['a_mythic', 'pet:glitchy'], ['a_rebirth', 'tab:rebirth'],
      ['a_skins', 'tab:style'], ['a_quests', 'tab:quests'], ['a_upg', 'tab:upgrades'], ['a_logo', 'ui:search'], ['a_night', 'ui:moon'], ['a_afk', 'ui:clock']];
    const hit = map.find(([p]) => id === p || id.startsWith(p));
    return hit ? hit[1] : 'ui:trophy';
  }

  /* ═════════════════════════ TABS ═════════════════════════ */
  const body = () => $('#tab-body');
  const renderers = {};
  const updaters = {};
  function buildTabs() {
    const nav = $('#tabs');
    nav.innerHTML = '';
    TABS.forEach((t) => {
      nav.append(h('button.tab', { type: 'button', role: 'tab', id: 'tab-' + t.id, 'aria-selected': String(ui.tab === t.id), 'data-tab': t.id, onclick: () => setTab(t.id) },
        h('span.e', I('tab:' + t.id)), h('span', t.l), h('span.badge', { hidden: true, id: 'badge-' + t.id })));
    });
  }
  function setTab(id, keepScroll) {
    if (ui.tab !== id) CO.sfx.play('tick', { pitch: 1.4 });
    ui.tab = id;
    lsSet('co-tab', id);
    document.querySelectorAll('.tab').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.tab === id)));
    render(keepScroll);
    if (window.innerWidth < 900) { const b = document.getElementById('tab-' + id); if (b && b.scrollIntoView) b.scrollIntoView({ inline: 'center', block: 'nearest', behavior: 'smooth' }); }
  }
  ui.setTab = setTab;
  function render(keepScroll) {
    const el = body(); const top = el.scrollTop;
    el.innerHTML = '';
    const fn = renderers[ui.tab];
    if (fn) el.append(fn());
    el.scrollTop = keepScroll ? top : 0;
    const up = updaters[ui.tab]; if (up) up();
    if (softKeys[ui.tab]) lastSoft[ui.tab] = softKeys[ui.tab]();
  }
  ui.render = render;
  const rerender = (tabs) => { if (!tabs || tabs.includes(ui.tab)) render(true); };
  const subTitle = (icon, text, count) => h('div.sub-title', I(icon), h('span', text), count != null ? h('span.count', count) : null);

  /* ═════════════════════════ SHOP ═════════════════════════ */
  function qtyOf() { const q = S().settings.buyQty; return q === 'max' ? 'max' : +q || 1; }
  renderers.shop = () => {
    const s = S(), q = qtyOf();
    const seg = h('div.seg', { role: 'group', 'aria-label': 'Quantité' },
      [1, 10, 100, 'max'].map((v) => h('button', { type: 'button', 'aria-pressed': String(q === v), onclick: () => { CO.setSetting('buyQty', v); render(true); } }, v === 'max' ? 'MAX' : '×' + v)));
    const list = h('div.blist');
    let shownLocked = 0;
    D.buildings.forEach((b) => {
      if (!CO.buildingUnlocked(b.id)) {
        if (shownLocked >= 1) return; shownLocked++;
        list.append(h('div.brow.locked', { 'aria-disabled': 'true' },
          h('div.ico', I('ui:lock')),
          h('div', h('div.nm', '???'), h('div.meta', 'Continue à produire pour débloquer'), h('div.cost', cookieAmt(fmt(b.cost)))),
          h('div.own', '')));
        return;
      }
      const row = h('button.brow', { type: 'button', 'data-b': b.id, title: b.desc, onclick: () => buyB(b.id, row) },
        h('div.ico', I('b:' + b.id)),
        h('div', h('div.nm', b.name), h('div.meta', { 'data-meta': 1 }), h('div.cost', I('ui:cookie'), ' ', h('span', { 'data-cost': 1 }))),
        h('div.own', { 'data-own': 1 }, String(s.buildings[b.id] || 0)),
        h('span.qty', { 'data-q': 1 }),
        h('i.prog', { 'data-prog': 1 }));
      list.append(row);
    });
    return h('div', h('div.sec-title', h('h2.ol', 'Bâtiments'), seg), list,
      h('p.muted.tip', 'Astuce : Espace = cliquer le cookie. Les combos rapides déclenchent la FIÈVRE RGB (tout ×3).'));
  };
  updaters.shop = () => {
    const s = S(), q = qtyOf(), cps = CO.cpsBase() || 1;
    body().querySelectorAll('.brow[data-b]').forEach((row) => {
      const id = row.dataset.b, own = s.buildings[id] || 0;
      const mx = CO.bMax(id);
      const n = q === 'max' ? Math.max(1, mx) : q;
      const cost = CO.bCost(id, n);
      row.classList.toggle('can', cost <= s.cookies && (q !== 'max' || mx > 0));
      row.querySelector('[data-cost]').textContent = fmt(cost);
      row.querySelector('[data-own]').textContent = own;
      row.querySelector('[data-q]').textContent = n > 1 ? '×' + n : '';
      const each = CO.buildingCps(id);
      row.querySelector('[data-meta]').textContent = own ? fmt(each) + '/s chacun · ' + Math.round(((each * own) / cps) * 100) + ' % de ta prod' : fmt(each) + '/s chacun';
      row.querySelector('[data-prog]').style.width = clampN((s.cookies / cost) * 100, 0, 100) + '%';
    });
  };
  function buyB(id, row) {
    CO.unlockAudio(); CO.touch();
    if (CO.buyBuilding(id, qtyOf())) { row.classList.remove('flash'); void row.offsetWidth; row.classList.add('flash'); updaters.shop(); }
    else row.animate([{ transform: 'translateX(0)' }, { transform: 'translateX(-6px)' }, { transform: 'translateX(6px)' }, { transform: 'translateX(0)' }], { duration: 220 });
  }

  /* ═════════════════════════ UPGRADES ═════════════════════════ */
  function visLine(u) {
    if (!u.vis) return null;
    const v = D.visuals[u.vis[0]]; if (!v) return null;
    const cur = CO.vis[u.vis[0]] || 0;
    const lvl = cur && !S().upgrades[u.id] ? ' (niveau ' + Math.min(v.max || 1, cur + 1) + ')' : '';
    const where = v.zone === 'cookie' ? 'Ton cookie gagne' : v.zone === 'around' ? 'Autour du cookie' : 'Sur l\'écran';
    return where + ' : ' + v.name + lvl;
  }
  const upIcon = (u) => (u.vis ? 'vis:' + u.vis[0] : 'tab:upgrades');
  renderers.upgrades = () => {
    const s = S();
    const avail = D.upgrades.filter((u) => !s.upgrades[u.id] && CO.reqMet(u)).sort((a, b) => a.cost - b.cost);
    const locked = D.upgrades.filter((u) => !s.upgrades[u.id] && !CO.reqMet(u)).sort((a, b) => a.cost - b.cost).slice(0, 3);
    const owned = D.upgrades.filter((u) => s.upgrades[u.id]);
    const wrap = h('div', h('div.sec-title', h('h2.ol', 'Upgrades'), h('span.note', 'Chaque upgrade transforme ton cookie')));
    const list = h('div.ulist');
    if (!avail.length) list.append(h('div.empty', 'Rien à acheter pour l\'instant. Continue à cliquer et à construire !'));
    avail.forEach((u) => {
      const btn = h('button.btn.green.small', { type: 'button', onclick: () => { CO.unlockAudio(); if (CO.buyUpgrade(u.id)) render(true); } }, 'ACHETER');
      const vl = visLine(u);
      list.append(h('div.ucard', { 'data-u': u.id },
        h('div.ico', I(upIcon(u))),
        h('div', h('div.nm', u.name), h('div.fx', CO.fxText(u)), vl ? h('div.vis', I('ui:gift'), ' ', vl) : null),
        h('div.row', h('span.c', cookieAmt(fmt(u.cost))), btn)));
    });
    wrap.append(list);
    if (locked.length) {
      wrap.append(subTitle('ui:lock', 'Bientôt'));
      const l2 = h('div.ulist');
      locked.forEach((u) => {
        const vl = visLine(u);
        l2.append(h('div.ucard.locked', h('div.ico', I(upIcon(u))),
          h('div', h('div.nm', u.name), vl ? h('div.vis', I('ui:gift'), ' ', vl) : null, h('div.req', I('ui:lock'), ' ', CO.reqText(u)))));
      });
      wrap.append(l2);
    }
    wrap.append(subTitle('ui:trophy', 'Collection', owned.length + ' / ' + D.upgrades.length));
    if (!owned.length) wrap.append(h('div.empty', 'Ta collection est vide. Ton premier upgrade arrive vite !'));
    else wrap.append(h('div.utiles', owned.map((u) => h('span.utile', { title: u.name + ' — ' + CO.fxText(u) }, I(upIcon(u))))));
    return wrap;
  };
  updaters.upgrades = () => {
    const s = S();
    body().querySelectorAll('.ucard[data-u]').forEach((c) => {
      const can = CO.idx.UPG[c.dataset.u].cost <= s.cookies;
      c.classList.toggle('can', can);
      const b = c.querySelector('button'); if (b) b.classList.toggle('off', !can);
    });
  };

  /* ═════════════════════════ MINIGAMES ═════════════════════════ */
  renderers.games = () => {
    const s = S();
    const grid = h('div.ggrid');
    MG_ORDER.forEach((id) => {
      const d = mgDef(id), unlocked = CO.minigameUnlocked(id), rec = s.mg[id] || { best: 0, plays: 0 };
      const u = D.minigameUnlocks[id];
      grid.append(h('div.gcard' + (unlocked ? '' : '.locked'), { style: { '--gc': d.color } },
        unlocked && !s.mgSeen[id] ? h('span.new.ribbon', 'NOUVEAU') : null,
        h('span.emo', I('mg:' + id)),
        h('div.nm.ol', d.name),
        h('div.tg', d.tagline || ''),
        unlocked
          ? [h('div.best', rec.plays ? [I('ui:trophy'), ' Record : ' + fmt(rec.best, { int: 1 }) + ' · ' + rec.plays + ' partie' + (rec.plays > 1 ? 's' : '')] : [I('ui:sparkle'), ' Jamais joué']),
            h('button.btn.green', { type: 'button', onclick: () => openMinigame(id), disabled: !CO.minigames[id] }, CO.minigames[id] ? [I('ui:play'), ' JOUER'] : 'Chargement…')]
          : [h('div.lock', I('ui:lock'), ' ' + u.text), h('div.mprog', h('i', { style: { width: clampN((s.allTimeBaked / u.baked) * 100, 0, 100) + '%' } }))]));
    });
    return h('div', h('div.sec-title', h('h2.ol', 'Mini-jeux'), h('span.note', 'Gagne des cookies et des ', I('ui:gem'))), grid,
      h('p.muted.tip', 'Les mini-jeux utilisent TON cookie (skin + accessoires). Récompenses indexées sur ta production.'));
  };

  function openMinigame(id) {
    const def = CO.minigames[id];
    if (!def || !CO.minigameUnlocked(id) || ui.overlay) return;
    CO.unlockAudio();
    S().mgSeen[id] = true;
    let closed = false, inst = null;
    const root = h('div.mg-root');
    const close = () => {
      if (closed) return; closed = true;
      try { inst && inst.destroy && inst.destroy(); } catch (e) { console.error(e); }
      overlay.remove(); ui.overlay = null;
      window.removeEventListener('keydown', onKey, true);
      CO.emit('minigame:close', { id });
      CO.save(); render(true);
    };
    const onKey = (e) => { if (e.key === 'Escape') { e.preventDefault(); close(); } };
    const overlay = h('div.mg-overlay', { role: 'dialog', 'aria-label': def.name },
      h('div.mg-head', I('mg:' + id, 'mgi'), h('span.t.ol', def.name), h('button.btn.red.small', { type: 'button', onclick: close }, I('ui:close'), ' Quitter')),
      root);
    document.body.append(overlay);
    ui.overlay = overlay;
    window.addEventListener('keydown', onKey, true);
    CO.emit('minigame:open', { id });
    try { inst = def.mount(root, CO.minigameApi(id, close)); } catch (e) { console.error(e); CO.toast('Oups, ce mini-jeu a planté.', { icon: 'ui:warning' }); close(); }
  }
  ui.openMinigame = openMinigame;

  /* ═════════════════════════ PETS ═════════════════════════ */
  const RORD = { mythic: 0, legendary: 1, epic: 2, rare: 3, common: 4 };
  function rarityStyle(r) {
    const R = D.rarities[r];
    return R.color === 'rgb' ? { '--rc': '#ff2bd6', '--rg': 'rgba(255,43,214,.9)' } : { '--rc': R.color, '--rg': R.glow };
  }
  renderers.pets = () => {
    const s = S(), eq = CO.equippedPets();
    const slots = h('div.slots');
    for (let i = 0; i < CO.maxPetSlots; i++) {
      const p = eq[i];
      slots.append(p
        ? h('div.slot.full' + (p.def.rarity === 'mythic' ? '.rgbc' : ''), { style: rarityStyle(p.def.rarity), title: p.def.name }, I('pet:' + p.def.id), p.lvl > 1 ? h('span.lv', 'Nv.' + p.lvl) : null)
        : h('div.slot', 'Slot libre'));
    }
    const M = CO.mult;
    const sum = h('div.petsum', eq.length ? 'Bonus pets : Prod +' + Math.round((M.petCps - 1) * 100) + ' % · Clic +' + Math.round((M.petClick - 1) * 100) + ' %' : 'Équipe un pet pour booster ta prod');
    const eggs = h('div.eggs');
    D.eggs.forEach((e) => {
      const odds = Object.entries(e.odds).map(([r, w]) => { const R = D.rarities[r]; return h('div', { style: { color: R.color === 'rgb' ? '#ff6be6' : R.color } }, R.name + ' ' + w + ' %'); });
      eggs.append(h('div.egg',
        h('div.shape', I('egg:' + e.id)),
        h('div.nm.ol', e.name), h('div.odds', odds),
        h('button.btn.gold.small', { type: 'button', 'data-egg': e.id, onclick: () => hatchFlow(e.id) }, I('ui:gem'), ' ' + e.cost)));
    });
    const inv = h('div.pgrid');
    s.pets.slice().sort((a, b) => RORD[CO.petDef(a.id).rarity] - RORD[CO.petDef(b.id).rarity] || b.lvl - a.lvl).forEach((p) => {
      const d = CO.petDef(p.id), R = D.rarities[d.rarity];
      inv.append(h('button.pet' + (s.equipped.includes(p.uid) ? '.eq' : '') + (d.rarity === 'mythic' ? '.rgbc' : ''), { type: 'button', style: rarityStyle(d.rarity), title: d.name + ' — ' + CO.petPower(p) + ' (clique pour équiper / retirer)', onclick: () => { CO.toggleEquip(p.uid); render(true); } },
        p.lvl > 1 ? h('span.lv', 'Nv.' + p.lvl) : null,
        h('span.e', I('pet:' + d.id)), h('span.n', d.name), h('span.r', R.name)));
    });
    return h('div',
      h('div.sec-title', h('h2.ol', 'Pets'), h('span.note', '3 pets équipés max')),
      slots, sum,
      subTitle('tab:pets', 'Œufs', 'doublon = niveau +1'), eggs,
      subTitle('ui:heart', 'Inventaire', s.pets.length + ' / ' + D.pets.length),
      s.pets.length ? inv : h('div.empty', 'Ouvre un œuf pour obtenir ton premier pet ! Les gemmes se gagnent avec les succès, les quêtes, les boss et les mini-jeux.'));
  };
  updaters.pets = () => {
    body().querySelectorAll('[data-egg]').forEach((b) => b.classList.toggle('off', S().gems < CO.idx.EGG[b.dataset.egg].cost));
  };

  function hatchFlow(eggId) {
    const egg = CO.idx.EGG[eggId];
    CO.unlockAudio();
    if (S().gems < egg.cost) { CO.sfx.play('error'); CO.toast('Pas assez de gemmes (' + egg.cost + ' requises).', { icon: 'ui:gem', color: '#ff4d6d' }); return; }
    const res = CO.hatch(eggId); if (!res) return;
    const R = D.rarities[res.rarity];
    const rm = S().settings.reducedMotion;
    const rays = h('div.rays');
    const flash = h('div.flashw');
    const bigegg = h('div.bigegg', I('egg:' + eggId));
    const caption = h('div.ol', { style: { fontSize: '22px' } }, 'Ça bouge…');
    const box = h('div.stagebox', bigegg, caption);
    const ov = h('div.hatch', { role: 'dialog', 'aria-label': 'Éclosion' }, rays, box, flash);
    document.body.append(ov);
    let revealed = false; const timers = [];
    const later = (fn, ms) => timers.push(setTimeout(fn, ms));
    const reveal = () => {
      if (revealed) return; revealed = true; timers.forEach(clearTimeout);
      if (!rm) flash.classList.add('go');
      CO.sfx.play('hatch'); if (RORD[res.rarity] <= 1) CO.sfx.play('jackpot', { vol: 0.6 });
      ov.classList.add('reveal');
      if (R.color === 'rgb') rays.style.background = 'repeating-conic-gradient(from 0deg, #ff004c 0 7deg, transparent 7deg 18deg, #ffe600 18deg 25deg, transparent 25deg 36deg, #2bff88 36deg 43deg, transparent 43deg 54deg, #00d5ff 54deg 61deg, transparent 61deg 72deg)';
      else rays.style.setProperty('--rcol', R.color);
      const col = R.color === 'rgb' ? 'var(--acc)' : R.color;
      box.innerHTML = '';
      box.append(
        h('div.rar.ol', { style: { color: col } }, R.name.toUpperCase() + (res.rarity === 'mythic' ? ' ?!' : ' !')),
        h('div.petbig', { style: { '--rg': R.color === 'rgb' ? '#ff2bd6' : R.glow } }, I('pet:' + res.id)),
        h('div.pname.ol', res.def.name),
        h('div.pinfo', res.isNew ? 'NOUVEAU PET !' : 'DOUBLON → NIVEAU ' + res.lvl + ' !'),
        h('div.pinfo', { style: { color: 'var(--lime)' } }, CO.petPower({ id: res.id, lvl: res.lvl })),
        h('div.btnrow', { style: { justifyContent: 'center', marginTop: '10px' } },
          h('button.btn.gold', { type: 'button', onclick: () => { close(); hatchFlow(eggId); }, disabled: S().gems < egg.cost }, 'ENCORE ', I('ui:gem'), ' ' + egg.cost),
          h('button.btn.green', { type: 'button', onclick: () => close() }, 'TROP BIEN !')));
      if (R.color === 'rgb' || res.rarity === 'legendary') CO.emit('fx:confetti', {});
    };
    const close = () => { timers.forEach(clearTimeout); ov.remove(); document.removeEventListener('keydown', onKey); if (ui.tab === 'pets') render(true); };
    const onKey = (e) => { if (e.key === 'Escape') close(); else if (!revealed && (e.key === ' ' || e.key === 'Enter')) reveal(); };
    document.addEventListener('keydown', onKey);
    ov.addEventListener('pointerdown', () => { if (!revealed) reveal(); });
    CO.sfx.play('whoosh');
    if (!rm) {
      [0, 250, 500, 700, 900, 1050, 1200, 1320, 1440, 1540].forEach((ms, i) => later(() => CO.sfx.play('tick', { pitch: 0.8 + i * 0.12 }), ms));
      later(() => { bigegg.classList.add('hard'); caption.textContent = 'IL VA ÉCLORE !!'; }, 950);
    }
    later(reveal, rm ? 300 : 1700);
  }

  /* ═════════════════════════ STYLE ═════════════════════════ */
  let skinCanvases = [];
  renderers.style = () => {
    const s = S();
    skinCanvases = [];
    const grid = h('div.skins');
    D.skins.forEach((sk) => {
      const owned = !!s.skinsOwned[sk.id], cur = s.skin === sk.id, gated = !!sk.unlock && !owned;
      const cv = h('canvas', { width: 128, height: 128, 'aria-hidden': 'true' });
      skinCanvases.push([cv, sk.id]);
      let label, cls;
      if (cur) { label = 'ÉQUIPÉ'; cls = 'eq'; }
      else if (owned) { label = 'Équiper'; cls = 'ok'; }
      else if (gated) { label = [I('ui:lock'), ' ' + sk.unlock.text]; cls = 'no'; }
      else { label = [I('ui:gem'), ' ' + sk.cost]; cls = s.gems >= sk.cost ? 'ok' : 'no'; }
      grid.append(h('button.skin' + (cur ? '.cur' : '') + (gated ? '.lockd' : ''), { type: 'button', title: sk.name, onclick: () => { CO.unlockAudio(); if (CO.buySkin(sk.id)) render(true); else if (!gated && !owned) CO.toast('Il te faut ' + sk.cost + ' gemmes pour ce skin.', { icon: 'ui:gem', color: '#ff4d6d' }); } },
        cv, h('span.n', sk.name), h('span.p.' + cls, label)));
    });
    const themes = h('div.themes');
    D.themes.forEach((th) => {
      const owned = !!s.themesOwned[th.id], cur = s.theme === th.id;
      const color = cur ? 'var(--cyan)' : owned || s.gems >= th.cost ? 'var(--lime)' : '#ff8a9c';
      themes.append(h('button.theme' + (cur ? '.cur' : ''), { type: 'button', onclick: () => { CO.unlockAudio(); if (CO.buyTheme(th.id)) render(true); else CO.toast('Il te faut ' + th.cost + ' gemmes pour ce thème.', { icon: 'ui:gem', color: '#ff4d6d' }); } },
        h('div.pv', { style: { background: th.preview } }),
        h('div.info', h('span.n', th.name), h('span.tp', { style: { color } }, cur ? 'ACTIF' : owned ? 'Choisir' : [I('ui:gem'), ' ' + th.cost]))));
    });
    const drip = Object.keys(CO.vis);
    const chips = drip.length
      ? h('div.utiles', drip.map((k) => h('span.buff', { title: D.visuals[k].name }, h('span.e', I('vis:' + k)), D.visuals[k].name + (CO.vis[k] > 1 ? ' ×' + CO.vis[k] : ''))))
      : h('div.empty', 'Aucun accessoire. Achète des upgrades pour pimper ton cookie !');
    return h('div',
      h('div.sec-title', h('h2.ol', 'Style'), h('span.note', 'Skins & thèmes avec tes ', I('ui:gem'))),
      subTitle('ui:cookie', 'Skins du cookie'), grid,
      subTitle('tab:style', 'Thèmes du décor'), themes,
      subTitle('ui:sparkle', 'Ton drip actuel', drip.length + ' effets'), chips);
  };
  function drawSkinThumbs() {
    for (const [cv, id] of skinCanvases) {
      if (!cv.isConnected) continue;
      const ctx = cv.getContext('2d');
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, cv.width, cv.height);
      try { CO.drawCookie(ctx, 64, 64, 50, { skin: id, rot: Math.sin(CO.now() * 1.2 + id.length) * 0.15 }); } catch (e) { /* stage not ready */ }
    }
  }

  /* ═════════════════════════ QUESTS & ACHIEVEMENTS ═════════════════════════ */
  renderers.quests = () => {
    const s = S();
    const ql = h('div.qlist');
    s.quests.forEach((q) => {
      const pct = clampN((q.progress / q.target) * 100, 0, 100);
      const acts = q.done
        ? h('button.btn.gold.small', { type: 'button', onclick: () => { const g = CO.claimQuest(q.id); if (g) { CO.toast('+' + g + ' gemmes récupérées !', { icon: 'ui:gem', color: '#b6ff3b' }); render(true); } } }, 'RÉCLAMER +', gem(q.gems))
        : [h('span.qr', '+', gem(q.gems)),
          h('button.btn.dark.small', { type: 'button', title: 'Changer de quête (3 gemmes)', onclick: () => { if (CO.rerollQuest(q.id)) render(true); else CO.toast('Il faut 3 gemmes pour changer de quête.', { icon: 'ui:dice' }); } }, I('ui:dice'), ' 3', I('ui:gem'))];
      ql.append(h('div.quest' + (q.done ? '.done' : ''), { 'data-q': q.id },
        h('div.e', I(QUEST_ICON[q.type] || 'tab:quests')),
        h('div', h('div.t', CO.questText(q)), h('div.pr', h('div.mprog', h('i', { style: { width: pct + '%' } })), h('span', { 'data-qt': 1 }, fmt(Math.floor(q.progress), { int: 1 }) + ' / ' + fmt(q.target, { int: 1 })))),
        h('div.acts', acts)));
    });
    const got = D.achievements.filter((a) => s.achievements[a.id]).length;
    const info = h('div.achinfo', 'Touche un badge pour voir le détail.');
    const achs = h('div.achs');
    D.achievements.forEach((a) => {
      const ok = !!s.achievements[a.id], hidden = !ok && a.secret;
      achs.append(h('button.ach' + (ok ? '' : '.no'), { type: 'button', title: hidden ? '???' : a.name, onclick: () => {
        info.innerHTML = '';
        info.append(h('b', hidden ? 'Succès secret' : a.name), h('br'),
          h('span.muted', hidden ? 'Indice : ' + a.hint : [a.desc + ' · +' + a.gems + ' ', I('ui:gem')]));
      } }, I(hidden ? 'ui:lock' : achIcon(a))));
    });
    const st = s.stats;
    const stat = (k, v) => h('div.stat', h('div.k', k), h('div.v', v));
    return h('div',
      h('div.sec-title', h('h2.ol', 'Quêtes'), h('span.note', 'Des gemmes à gratter en boucle')), ql,
      subTitle('ui:trophy', 'Succès', got + ' / ' + D.achievements.length + ' · +' + got + ' % de prod'), achs, info,
      subTitle('ui:chart', 'Stats'),
      h('div.stats',
        stat('Cookies produits (total)', fmt(s.allTimeBaked)), stat('Cette vie', fmt(s.totalBaked)),
        stat('Clics', fmt(s.clicks, { int: 1 })), stat('Record CPS', fmt(st.bestCps) + '/s'),
        stat('Combo max', fmt(st.maxCombo, { int: 1 })), stat('Fièvres', st.fevers),
        stat('Cookies dorés', st.golden), stat('Boss vaincus', st.bossKills),
        stat('Œufs ouverts', st.eggs), stat('Temps de jeu', CO.fmtTime(st.playTime))));
  };
  updaters.quests = () => {
    S().quests.forEach((q) => {
      const el = body().querySelector('[data-q="' + q.id + '"]'); if (!el) return;
      el.querySelector('.mprog i').style.width = clampN((q.progress / q.target) * 100, 0, 100) + '%';
      el.querySelector('[data-qt]').textContent = fmt(Math.floor(q.progress), { int: 1 }) + ' / ' + fmt(q.target, { int: 1 });
    });
  };

  /* ═════════════════════════ REBIRTH ═════════════════════════ */
  let rbArmed = 0;
  renderers.rebirth = () => {
    const s = S(), gain = CO.rebirthGain();
    const nextNeed = Math.pow(gain + 1, 2) * CO.REBIRTH_MIN, prevNeed = gain ? Math.pow(gain, 2) * CO.REBIRTH_MIN : 0;
    const pct = clampN(((s.totalBaked - prevNeed) / (nextNeed - prevNeed)) * 100, 0, 100);
    const btn = h('button.btn.big.gold', { type: 'button', id: 'rb-btn', disabled: gain < 1, style: { width: '100%', marginTop: '12px' }, onclick: () => {
      if (gain < 1) return;
      if (Date.now() - rbArmed > 3500) { rbArmed = Date.now(); btn.textContent = 'SÛR ? CLIQUE ENCORE !'; btn.classList.remove('gold'); btn.classList.add('red'); CO.sfx.play('tick'); setTimeout(() => { if (rbArmed && Date.now() - rbArmed >= 3500 && btn.isConnected) { rbArmed = 0; render(true); } }, 3600); return; }
      rbArmed = 0; const g = CO.rebirth(); if (g) rebirthFx(g);
    } }, gain >= 1 ? ['REBIRTH  +' + fmt(gain, { int: 1 }) + ' ', I('ui:star')] : 'REBIRTH verrouillé');
    return h('div',
      h('div.rb-hero',
        h('div.big.ol.ol-lg', I('tab:rebirth', 'xl'), ' REBIRTH'),
        h('div', { style: { marginTop: '6px', fontWeight: 600 } }, I('ui:star'), ' ' + fmt(s.stars, { int: 1 }) + ' étoile' + (s.stars > 1 ? 's' : '') + ' → +' + fmt(s.stars * 10, { int: 1 }) + ' % sur tout · ' + s.rebirths + ' rebirth' + (s.rebirths > 1 ? 's' : '')),
        h('div.gain.ol', gain >= 1 ? ['+' + fmt(gain, { int: 1 }) + ' ', I('ui:star'), ' si tu renais maintenant'] : 'Pas encore…'),
        h('div.muted', { style: { fontSize: '13px' } }, gain >= 1 ? 'Prochaine étoile à ' + fmt(nextNeed) + ' cookies (cette vie)' : 'Produis ' + fmt(CO.REBIRTH_MIN) + ' cookies dans cette vie pour ta 1ʳᵉ étoile'),
        h('div.mprog', { style: { marginTop: '8px' } }, h('i', { style: { width: pct + '%' } })),
        btn),
      h('div.rb-cols',
        h('div.rb-box', h('h4', I('ui:skull'), ' Tu perds'), 'Cookies', h('br'), 'Bâtiments', h('br'), 'Upgrades (et leurs effets sur le cookie)'),
        h('div.rb-box', h('h4', I('ui:gem'), ' Tu gardes'), 'Gemmes, pets, skins, thèmes', h('br'), 'Succès et records', h('br'),
          h('b', { style: { color: 'var(--gold)' } }, '+10 % par étoile, pour toujours'), h('br'), h('b', { style: { color: 'var(--cyan)' } }, '+10 gemmes par étoile gagnée'))),
      h('p.muted.tip', 'Le skin Néant se débloque au 3ᵉ rebirth.'));
  };
  function rebirthFx(g) {
    const fx = h('div.rbflash', h('div.ol.ol-lg', 'REBIRTH ! +' + g + ' ', I('ui:star', 'xl')));
    document.body.append(fx);
    setTimeout(() => fx.remove(), 2300);
    CO.emit('fx:confetti', {});
    render();
  }

  /* coarse keys: when they change, the visible tab is re-rendered (max once per second) */
  const lastSoft = {};
  const softKeys = {
    shop: () => D.buildings.filter((b) => CO.buildingUnlocked(b.id)).length,
    upgrades: () => D.upgrades.filter((u) => !S().upgrades[u.id] && CO.reqMet(u)).length + '|' + Object.keys(S().upgrades).length,
    games: () => MG_ORDER.map((id) => (CO.minigameUnlocked(id) ? (CO.minigames[id] ? 'u' : 'l') : Math.floor(clampN(S().allTimeBaked / D.minigameUnlocks[id].baked, 0, 1) * 40))).join(','),
    rebirth: () => CO.rebirthGain() + '|' + Math.floor(clampN(S().totalBaked / (Math.pow(CO.rebirthGain() + 1, 2) * CO.REBIRTH_MIN), 0, 1) * 50),
    quests: () => S().quests.map((q) => q.id + (q.done ? 'd' : '')).join(','),
    style: () => S().gems,
    pets: () => S().pets.length + '|' + S().equipped.join(','),
  };

  /* ═════════════════════════ OPTIONS ═════════════════════════ */
  function sw(key, label, desc) {
    const id = 'opt-' + key;
    const input = h('input', { type: 'checkbox', id, checked: !!S().settings[key], onchange: (e) => { CO.setSetting(key, e.target.checked); applySettings(); } });
    return h('div.opt', h('label', { for: id }, label, desc ? h('span.d', desc) : null), h('span.switch', input, h('span')));
  }
  function range(key, label, min, max, step, desc) {
    const id = 'opt-' + key;
    return h('div.opt', h('label', { for: id }, label, desc ? h('span.d', desc) : null),
      h('input', { type: 'range', id, min, max, step, value: S().settings[key], oninput: (e) => { CO.setSetting(key, +e.target.value); if (key === 'sfx') CO.sfx.play('pop'); applySettings(); } }));
  }
  function select(key, label, options, desc, parse) {
    const id = 'opt-' + key, cur = String(S().settings[key]);
    return h('div.opt', h('label', { for: id }, label, desc ? h('span.d', desc) : null),
      h('select', { id, onchange: (e) => { CO.setSetting(key, parse ? parse(e.target.value) : e.target.value); applySettings(); if (key === 'clickSound') CO.sfx.play('click'); } },
        options.map(([v, l]) => h('option', { value: v, selected: String(v) === cur }, l))));
  }
  renderers.options = () => {
    const s = S();
    const nameId = 'opt-bakery';
    const nameInput = h('input.txt', { id: nameId, type: 'text', maxlength: 28, value: s.bakery || '', placeholder: 'La Boulangerie RGB', oninput: (e) => { s.bakery = e.target.value.slice(0, 28); updateBakery(); } });
    const ta = h('textarea', { id: 'save-io', placeholder: 'Colle un code de sauvegarde ici pour l\'importer…', 'aria-label': 'Code de sauvegarde' });
    let resetArmed = 0;
    const resetBtn = h('button.btn.red.small', { type: 'button', onclick: () => {
      if (Date.now() - resetArmed > 3500) { resetArmed = Date.now(); resetBtn.textContent = 'VRAIMENT ? TOUT EFFACER'; return; }
      CO.hardReset(); CO.toast('Partie réinitialisée.', { icon: 'ui:rainbow' }); setTab('shop');
    } }, 'Réinitialiser la partie');
    return h('div',
      h('div.sec-title', h('h2.ol', 'Options')),
      h('div.opts', h('div.opt', h('label', { for: nameId }, 'Nom de ta boulangerie', h('span.d', 'Affiché au-dessus du compteur')), nameInput)),
      subTitle('ui:sound', 'Son'),
      h('div.opts',
        range('sfx', 'Effets sonores', 0, 1, 0.05),
        sw('musicOn', 'Musique', 'Générée en direct, elle s\'emballe en Fièvre'),
        select('track', 'Morceau', CO.musicTracks || [['synthwave', 'Synthwave']]),
        range('music', 'Volume musique', 0, 1, 0.05),
        select('clickSound', 'Son du clic', D.clickSounds.map((c) => [c.id, c.name]))),
      subTitle('ui:sparkle', 'Visuel'),
      h('div.opts',
        select('particles', 'Particules', [[0, 'Éco (PC patate)'], [1, 'Normal'], [2, 'ULTRA']], 'Baisse si ça rame', (v) => +v),
        range('rgbSpeed', 'Vitesse du RGB', 0, 3, 0.25, '0 = arrêté'),
        select('uiHue', 'Couleur de l\'interface', [['rgb', 'RGB auto'], [320, 'Rose'], [190, 'Cyan'], [90, 'Lime'], [45, 'Or'], [265, 'Violet'], [0, 'Rouge']], null, (v) => (v === 'rgb' ? 'rgb' : +v)),
        sw('shake', 'Tremblements d\'écran'),
        sw('trail', 'Traînée RGB du curseur'),
        sw('reducedMotion', 'Mouvements réduits', 'Moins de flashs et d\'animations'),
        sw('showFps', 'Afficher les FPS')),
      subTitle('ui:chart', 'Nombres'),
      h('div.opts', select('numFormat', 'Format', [['short', 'Court (1,25 M)'], ['long', 'Long (1,25 million)'], ['sci', 'Scientifique (1,25e6)']])),
      subTitle('ui:save', 'Sauvegarde', lsOk ? 'auto toutes les 12 s' : 'stockage bloqué : exporte ton code !'),
      h('div.savebox',
        h('div.btnrow',
          h('button.btn.green.small', { type: 'button', onclick: () => { CO.save(); CO.toast('Sauvegardé !', { icon: 'ui:save', color: '#2bdc6a' }); } }, 'Sauvegarder'),
          h('button.btn.cyan.small', { type: 'button', onclick: () => {
            const code = CO.exportSave(); ta.value = code; ta.select();
            const p = navigator.clipboard && navigator.clipboard.writeText ? navigator.clipboard.writeText(code) : Promise.reject(new Error('no clipboard'));
            p.then(() => CO.toast('Code copié dans le presse-papier.', { icon: 'ui:check', color: '#1ff4ff' }), () => CO.toast('Code prêt : sélectionne-le et copie-le.', { icon: 'ui:save' }));
          } }, 'Exporter'),
          h('button.btn.small', { type: 'button', onclick: () => { if (CO.importSave(ta.value)) { CO.toast('Sauvegarde importée !', { icon: 'ui:check', color: '#2bdc6a' }); render(); } else CO.toast('Code invalide. Il doit commencer par CO1|', { icon: 'ui:warning', color: '#ff4d6d' }); } }, 'Importer')),
        h('div.btnrow',
          h('button.btn.small', { type: 'button', onclick: () => {
            const code = CO.exportSave(); if (!code) return;
            try {
              const a = document.createElement('a');
              a.href = URL.createObjectURL(new Blob([code], { type: 'text/plain' }));
              a.download = 'cookie-overdrive-' + new Date().toISOString().slice(0, 10) + '.txt';
              document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 2000);
              CO.toast('Fichier de sauvegarde téléchargé.', { icon: 'ui:save', color: '#1ff4ff' });
            } catch (e) { CO.toast('Téléchargement impossible : utilise Exporter.', { icon: 'ui:warning', color: '#ff4d6d' }); }
          } }, 'Télécharger'),
          h('button.btn.small', { type: 'button', onclick: () => {
            const inp = document.createElement('input'); inp.type = 'file'; inp.accept = '.txt,text/plain';
            inp.onchange = () => {
              const f = inp.files && inp.files[0]; if (!f) return;
              f.text().then((txt) => {
                if (CO.importSave(txt)) { CO.toast('Sauvegarde chargée depuis le fichier !', { icon: 'ui:check', color: '#2bdc6a' }); render(); }
                else CO.toast('Fichier invalide.', { icon: 'ui:warning', color: '#ff4d6d' });
              });
            };
            inp.click();
          } }, 'Charger un fichier'),
          CO.hasBackup() ? h('button.btn.small', { type: 'button', onclick: () => {
            if (!confirm('Revenir à la sauvegarde de secours (jusqu\'à ~5 min plus ancienne) ?')) return;
            if (CO.restoreBackup()) { CO.save(); CO.toast('Sauvegarde de secours restaurée.', { icon: 'ui:check', color: '#2bdc6a' }); render(); }
            else CO.toast('Secours illisible.', { icon: 'ui:warning', color: '#ff4d6d' });
          } }, 'Secours') : null),
        ta, h('div.btnrow', resetBtn)));
  };

  function applySettings() {
    const st = S().settings;
    document.body.classList.toggle('rm', !!st.reducedMotion);
    const bm = $('#btn-music'), bs = $('#btn-sfx');
    bm.classList.toggle('on', !!st.musicOn);
    bs.classList.toggle('on', st.sfx > 0);
    const want = st.sfx > 0 ? 'ui:sound' : 'ui:mute';
    if (bs.dataset.ic !== want) { bs.dataset.ic = want; bs.innerHTML = ''; bs.append(I(want)); }
  }

  /* ═════════════════════════ HUD ═════════════════════════ */
  const hud = { disp: 0, lastStr: '', lastCps: '', lastGems: -1, lastStars: -1, buffKey: '', bannerKey: '' };
  let bakeryEl = null, countNum = null;
  const E = {};
  function cacheEls() { ['cpsv', 'cps', 'combo', 'combo-n', 'combo-m', 'combo-fill', 'buffs', 'banners', 'gems', 'stars', 'hint'].forEach((id) => (E[id] = document.getElementById(id))); E.gift = document.getElementById('btn-gift'); E.giftT = document.getElementById('gift-t'); }
  function updateBakery() {
    if (!bakeryEl) return;
    const nm = S().bakery && S().bakery.trim() ? S().bakery.trim() : 'La Boulangerie RGB';
    bakeryEl.innerHTML = ''; bakeryEl.append(I('ui:home'), ' ', nm);
  }
  function hudFrame(dt) {
    const s = S(), st = s.settings;
    const hue = st.uiHue === 'rgb' ? CO.hue() : +st.uiHue;
    document.documentElement.style.setProperty('--h', hue.toFixed(1));
    // counter (smooth)
    const target = s.cookies, d = target - hud.disp;
    hud.disp = Math.abs(d) < 1 || Math.abs(d) / (Math.abs(target) + 1) < 0.0005 ? target : hud.disp + d * Math.min(1, dt * 12);
    const str = fmt(Math.floor(hud.disp), { int: 1 });
    if (str !== hud.lastStr) { hud.lastStr = str; countNum.textContent = str; }
    const cs = fmt(CO.cpsNow());
    if (cs !== hud.lastCps) { hud.lastCps = cs; E.cpsv.textContent = cs; }
    E.cps.classList.toggle('boost', CO.buffs.length > 0 || CO.fever.active);
    // combo
    const c = CO.combo, now = CO.now();
    const showCombo = c.count >= 3 || CO.fever.active;
    E.combo.classList.toggle('idle', !showCombo);
    if (showCombo) {
      E['combo-n'].textContent = CO.fever.active ? 'FIÈVRE RGB' : 'COMBO ' + Math.floor(c.count);
      E['combo-m'].textContent = CO.fever.active ? '×' + CO.feverMult + ' · ' + Math.max(0, CO.fever.until - now).toFixed(1).replace('.', ',') + ' s' : '×' + String(c.mult).replace('.', ',');
      E['combo-fill'].style.width = (CO.fever.active ? clampN(((CO.fever.until - now) / CO.mult.feverDur) * 100, 0, 100) : c.heat * 100) + '%';
      E.combo.classList.toggle('hot', c.heat > 0.7 || CO.fever.active);
    }
    // buffs
    const key = CO.buffs.map((b) => b.id).join(',');
    if (key !== hud.buffKey) {
      hud.buffKey = key; E.buffs.innerHTML = '';
      CO.buffs.forEach((b) => E.buffs.append(h('span.buff', { 'data-id': b.id }, h('span.e', I(b.icon || 'ui:bolt')), b.name + (b.cps ? ' ×' + b.cps : b.click ? ' clic ×' + b.click : ''), h('span.t'), h('i.drain'))));
    }
    CO.buffs.forEach((b) => {
      const el = E.buffs.querySelector('[data-id="' + b.id + '"]'); if (!el) return;
      el.querySelector('.t').textContent = Math.ceil(b.until - now) + ' s';
      el.querySelector('.drain').style.width = clampN(((b.until - now) / b.dur) * 100, 0, 100) + '%';
    });
    // banners
    const bkey = (CO.fever.active ? 'F' : '') + (CO.boss ? 'B' + CO.boss.id : '');
    if (bkey !== hud.bannerKey) {
      hud.bannerKey = bkey; E.banners.innerHTML = '';
      if (CO.boss) E.banners.append(h('div.banner.boss.ol', I('boss:' + CO.boss.id, 'bn'), ' ' + CO.boss.name + ' attaque !', h('small', { id: 'bn-boss-t' })));
      if (CO.fever.active) E.banners.append(h('div.banner.fever.ol', I('ui:rainbow', 'bn'), ' FIÈVRE RGB — TOUT ×' + CO.feverMult));
    }
    if (CO.boss) { const t = document.getElementById('bn-boss-t'); if (t) t.textContent = 'PV ' + Math.ceil((CO.boss.hp / CO.boss.maxHp) * 100) + ' % · ' + Math.max(0, Math.ceil(CO.boss.until - now)) + ' s'; }
    // pills
    if (s.gems !== hud.lastGems) { const up = s.gems > hud.lastGems && hud.lastGems >= 0; hud.lastGems = s.gems; E.gems.textContent = fmt(s.gems, { int: 1 }); if (up) bump('#pill-gems'); }
    if (s.stars !== hud.lastStars) { hud.lastStars = s.stars; E.stars.textContent = fmt(s.stars, { int: 1 }); }
    if (s.clicks > 0 && !E.hint.classList.contains('gone')) E.hint.classList.add('gone');
    const gin = CO.giftIn(), gready = gin <= 0;
    if (gready !== hud.gready) { hud.gready = gready; E.gift.classList.toggle('ready', gready); }
    const gt = gready ? 'PRÊT' : (gin >= 60 ? Math.ceil(gin / 60) + ' min' : Math.ceil(gin) + ' s');
    if (gt !== hud.gt) { hud.gt = gt; E.giftT.textContent = gt; }
  }
  function bump(sel) { const el = $(sel); el.classList.remove('bump'); void el.offsetWidth; el.classList.add('bump'); }
  function placeHint() {
    const r = $('#play').getBoundingClientRect();
    const R = clampN(Math.min(r.width, r.height * 0.8) * 0.22, 60, 170);
    E.hint.style.top = Math.min(r.height - 120, r.height * 0.56 + R + 22) + 'px';
  }

  function updateBadges() {
    const s = S();
    const setB = (id, n) => { const b = document.getElementById('badge-' + id); if (!b) return; if (n > 0) { b.hidden = false; b.textContent = n > 9 ? '9+' : n; } else b.hidden = true; };
    setB('upgrades', D.upgrades.filter((u) => !s.upgrades[u.id] && CO.reqMet(u) && u.cost <= s.cookies).length);
    setB('quests', s.quests.filter((q) => q.done).length);
    setB('games', MG_ORDER.filter((id) => CO.minigameUnlocked(id) && CO.minigames[id] && !s.mgSeen[id]).length);
    setB('pets', D.eggs.some((e) => s.gems >= e.cost) && s.pets.length < 3 ? 1 : 0);
    setB('rebirth', CO.rebirthGain() >= 1 && s.rebirths === 0 ? 1 : 0);
  }

  /* ═════════════════════════ TOASTS & POPUPS ═════════════════════════ */
  function toast({ text, icon, color }) {
    const wrap = $('#toasts');
    while (wrap.children.length >= 4) wrap.firstChild.remove();
    const t = h('div.toast', { style: { '--tc': color || 'var(--violet)' } }, h('span.e', I(icon && CO.art.has(icon) ? icon : 'ui:sparkle')), h('span', text));
    wrap.append(t);
    setTimeout(() => { t.classList.add('out'); setTimeout(() => t.remove(), 320); }, 3200);
  }
  const achQueue = []; let achBusy = false;
  function achPopup(a) { achQueue.push(a); if (!achBusy) nextAch(); }
  function nextAch() {
    const a = achQueue.shift(); const pop = $('#achpop');
    if (!a) { achBusy = false; return; }
    achBusy = true;
    pop.innerHTML = '';
    pop.append(h('div.achcard', h('span.e', I(achIcon(a))), h('div', h('div.k', 'SUCCÈS DÉBLOQUÉ !'), h('div.n', a.name), h('div.g', '+' + a.gems + ' ', I('ui:gem'), ' · +1 % de prod'))));
    requestAnimationFrame(() => pop.classList.add('show'));
    setTimeout(() => { pop.classList.remove('show'); setTimeout(nextAch, 520); }, 3300);
  }
  function modal(title, text, buttons, art) {
    const back = h('div.modal-back', { role: 'dialog', 'aria-modal': 'true' });
    const close = () => back.remove();
    back.append(h('div.modal', art ? h('div.modal-art', I(art)) : null, h('h3.ol.ol-lg', title), h('p', text), h('div.btnrow', { style: { justifyContent: 'center' } },
      buttons.map((b) => h('button.btn' + (b.cls ? '.' + b.cls : ''), { type: 'button', onclick: () => { close(); if (b.fn) b.fn(); } }, b.label)))));
    document.body.append(back);
    return close;
  }
  ui.modal = modal;

  /* ═════════════════════════ TICKER ═════════════════════════ */
  function tickerLine() {
    const s = S(), dyn = [];
    if (CO.boss) dyn.push('EN DIRECT : ' + CO.boss.name + ' attaque ta boulangerie ! Clique le cookie pour riposter !');
    if (s.clicks > 50) dyn.push('Tu as cliqué ' + fmt(s.clicks, { int: 1 }) + ' fois. Ton index mérite une statue.');
    if (CO.cpsBase() > 0) dyn.push('Ta production : ' + fmt(CO.cpsBase()) + ' cookies/s. Les voisins commencent à s\'inquiéter.');
    if (s.pets.length) { const p = s.pets[Math.floor(Math.random() * s.pets.length)]; dyn.push('Ton ' + CO.petDef(p.id).name + ' a été élu employé du mois.'); }
    if (s.rebirths) dyn.push('Rebirth n°' + s.rebirths + ' confirmé. Le cookie est revenu encore plus fort.');
    const pool = D.news.concat(dyn, dyn);
    return pool[Math.floor(Math.random() * pool.length)];
  }
  function runTicker() {
    const msg = $('#ticker-msg'), track = msg.parentElement;
    msg.textContent = tickerLine();
    const dist = msg.offsetWidth + track.offsetWidth + 20;
    const anim = msg.animate([{ transform: 'translate(0,-50%)' }, { transform: 'translate(' + -dist + 'px,-50%)' }], { duration: (dist / 85) * 1000, easing: 'linear' });
    anim.onfinish = () => setTimeout(runTicker, 300);
  }

  /* ═════════════════════════ EVENTS ═════════════════════════ */
  function bindEvents() {
    CO.on('toast', toast);
    CO.on('achievement', ({ a }) => { achPopup(a); rerender(['quests']); });
    CO.on('buy', ({ kind }) => { if (kind === 'upgrade' || kind === 'building') rerender(['upgrades']); if (kind === 'skin' || kind === 'theme') rerender(['style']); });
    CO.on('visuals', ({ added }) => {
      if (!ui.ready || !added || !added.length) return;
      added.forEach((k) => { const v = D.visuals[k]; if (v) toast({ text: 'Nouveau sur ton cookie : ' + v.name + ' !', icon: 'vis:' + k, color: 'var(--hot)' }); });
    });
    CO.on('quest:done', () => rerender(['quests']));
    CO.on('quests', () => rerender(['quests']));
    CO.on('pets', () => rerender(['pets']));
    CO.on('rebirth', () => render());
    CO.on('tab:blocked', () => {
      if (document.getElementById('tab-block')) return;
      const d = document.createElement('div'); d.id = 'tab-block';
      d.style.cssText = 'position:fixed;inset:0;z-index:99999;display:grid;place-items:center;background:rgba(8,4,20,.92);color:#fff;font:600 18px/1.5 Fredoka,sans-serif;text-align:center;padding:24px';
      d.innerHTML = '<div><div style="font-size:42px">🍪</div>Le jeu est ouvert dans un autre onglet.<br>Ta progression continue là-bas.<br><br><button type="button" style="font:inherit;padding:10px 22px;border-radius:12px;border:0;background:#ff3ea5;color:#fff;cursor:pointer">Jouer ici</button></div>';
      d.querySelector('button').onclick = () => location.reload();
      document.body.appendChild(d);
    });
    if (CO.restoredBackup) setTimeout(() => CO.toast('Sauvegarde principale abîmée : secours restauré.', { icon: 'ui:warning', color: '#ffb020' }), 1500);
    CO.on('load', () => { if (ui.ready) { applySettings(); updateBakery(); render(); } });
    CO.on('minigame:end', () => rerender(['games']));
    CO.on('minigame:registered', () => rerender(['games']));
    CO.on('golden:click', ({ kind }) => {
      const txt = { frenzy: 'Production ×7 pendant ' + Math.round(30 * CO.mult.goldenDur) + ' s !', clickstorm: 'Chaque clic ×77 pendant ' + Math.round(10 * CO.mult.goldenDur) + ' s. SPAM !', rgbstorm: 'Fièvre RGB instantanée !' }[kind];
      if (txt) toast({ text: txt, icon: 'ui:golden', color: '#ffc93c' });
    });
    CO.on('boss:spawn', ({ boss }) => toast({ text: 'BOSS : ' + boss.name + ' ! Clique le cookie pour l\'attaquer (30 s)', icon: 'boss:' + boss.id, color: '#ff4d6d' }));
    CO.on('fever:start', () => document.body.classList.add('fever'));
    CO.on('fever:end', () => document.body.classList.remove('fever'));
    CO.on('settings', ({ key }) => { if (key === 'numFormat') { hud.lastStr = ''; hud.lastCps = ''; hud.lastGems = -1; hud.lastStars = -1; } });
    const known = {};
    MG_ORDER.forEach((id) => (known[id] = CO.minigameUnlocked(id)));
    let bossKnown = CO.bossUnlocked();
    CO.on('second', () => {
      MG_ORDER.forEach((id) => {
        if (!known[id] && CO.minigameUnlocked(id)) { known[id] = true; toast({ text: 'Mini-jeu débloqué : ' + mgDef(id).name + ' ! Va dans l\'onglet Jeux.', icon: 'mg:' + id, color: mgDef(id).color }); CO.sfx.play('levelup'); }
      });
      if (!bossKnown && CO.bossUnlocked()) { bossKnown = true; toast({ text: 'Les BOSS vont bientôt débarquer. Prépare ton index.', icon: 'ui:sword', color: '#ff4d6d' }); }
      updateBadges();
      const kf = softKeys[ui.tab];
      if (kf) { const k = kf(); if (k !== lastSoft[ui.tab] && Date.now() - rbArmed > 3500) render(true); }
    });

    $('#btn-gift').addEventListener('click', () => {
      CO.unlockAudio();
      const res = CO.claimGift();
      if (!res) { CO.toast('Prochain cadeau dans ' + CO.fmtTime(CO.giftIn()) + '.', { icon: 'ui:clock' }); return; }
      modal('CADEAU !', h('span.reward.ol', res.label), [{ label: 'MERCI !', cls: 'gold' }], res.icon);
      CO.emit('fx:confetti', {});
    });
    $('#btn-music').addEventListener('click', () => { CO.unlockAudio(); CO.setSetting('musicOn', !S().settings.musicOn); applySettings(); if (ui.tab === 'options') render(true); });
    $('#btn-sfx').addEventListener('click', () => { CO.unlockAudio(); const st = S().settings; if (st.sfx > 0) { st._lastSfx = st.sfx; CO.setSetting('sfx', 0); } else { CO.setSetting('sfx', st._lastSfx || 0.55); CO.sfx.play('pop'); } applySettings(); if (ui.tab === 'options') render(true); });
    $('#logo').addEventListener('click', () => {
      const s = S(); s.flags.logo = (s.flags.logo || 0) + 1; CO.unlockAudio(); CO.sfx.play('pop', { pitch: 0.8 + Math.min(1.5, s.flags.logo * 0.1) });
      $('#logo').animate([{ transform: 'rotate(0) scale(1)' }, { transform: 'rotate(-8deg) scale(1.1)' }, { transform: 'rotate(0) scale(1)' }], { duration: 300 });
    });
    $('#sheet-handle').addEventListener('click', () => { document.body.classList.toggle('expanded'); setTimeout(() => { CO.emit('layout', {}); placeHint(); }, 380); });

    // Space = click the cookie (no key-repeat autoclick)
    document.addEventListener('keydown', (e) => {
      if (e.code !== 'Space' || e.repeat || ui.overlay || document.querySelector('.hatch,.modal-back')) return;
      const t = e.target; if (t && t.closest && t.closest('input,textarea,select,button,[contenteditable]')) return;
      e.preventDefault();
      const r = $('#play').getBoundingClientRect();
      CO.clickCookie(r.left + r.width / 2, r.top + r.height * 0.56);
    });
    let rsz = null;
    window.addEventListener('resize', () => { clearTimeout(rsz); rsz = setTimeout(() => { CO.emit('layout', {}); placeHint(); }, 120); });
  }

  /* ═════════════════════════ LOOP ═════════════════════════ */
  let lastF = performance.now(), upAcc = 0, thumbAcc = 0;
  function loop(t) {
    const dt = Math.min(0.1, (t - lastF) / 1000); lastF = t;
    try {
      hudFrame(dt);
      upAcc += dt; thumbAcc += dt;
      if (upAcc > 0.2) { upAcc = 0; const up = updaters[ui.tab]; if (up) up(); }
      if (ui.tab === 'style' && thumbAcc > 0.08) { thumbAcc = 0; drawSkinThumbs(); }
    } catch (e) { console.error(e); }
    requestAnimationFrame(loop);
  }

  /* ═════════════════════════ INIT ═════════════════════════ */
  ui.init = () => {
    cacheEls();
    CO.art.preload(['ui:', 'pet:', 'boss:', 'b:', 'item:', 'egg:']);
    document.documentElement.style.setProperty('--ic-check', 'url("' + CO.art.url('ui:check') + '")');
    // static art in the shell
    $('#pill-gems .i').append(I('ui:gem'));
    $('#pill-stars .i').append(I('ui:star'));
    $('#btn-music').append(I('ui:music'));
    $('#btn-gift').prepend(I('ui:gift'));
    $('#logo').prepend(I('ui:golden', 'logo-mark'));
    $('#cps').prepend(I('ui:bolt'), ' ');
    E.hint.prepend(I('ui:tap', 'hand'));
    if (CO.state.clicks > 0) { E.hint.style.transition = 'none'; E.hint.classList.add('gone'); requestAnimationFrame(() => (E.hint.style.transition = '')); }
    const count = $('#count'); count.innerHTML = '';
    countNum = h('span', '0'); count.append(countNum, h('span.u', 'cookies'));
    bakeryEl = h('div.bakery.ol');
    $('#hud').prepend(bakeryEl); updateBakery();
    hud.disp = S().cookies;
    const saved = lsGet('co-tab'); if (saved && TABS.some((t) => t.id === saved)) ui.tab = saved;
    buildTabs(); bindEvents(); applySettings(); render(); placeHint(); updateBadges();
    requestAnimationFrame(loop);
    setTimeout(runTicker, 600);
    ui.ready = true;
    if (CO.offline) {
      const o = CO.offline;
      modal('RE !', 'Pendant ton absence (' + CO.fmtTime(o.away) + '), ta boulangerie a cuit +' + fmt(o.gain) + ' cookies (50 % d\'efficacité hors-ligne).', [{ label: 'LET\'S GOOO', cls: 'green', fn: () => CO.unlockAudio() }], 'ui:cookie');
    } else if (S().allTimeBaked === 0 && S().clicks === 0) {
      modal('COOKIE OVERDRIVE', 'Clique le cookie. Chaque upgrade le transforme : lunettes, couronne, yeux laser, trou noir… Enchaîne les combos pour la FIÈVRE RGB, collectionne des pets, bats des boss et débloque 4 mini-jeux.', [
        { label: [I('ui:music'), ' JOUER AVEC LA MUSIQUE'], cls: 'green', fn: () => { CO.unlockAudio(); CO.setSetting('musicOn', true); applySettings(); } },
        { label: 'Sans musique', cls: 'dark', fn: () => CO.unlockAudio() },
      ], 'ui:golden');
    }
  };
})();
