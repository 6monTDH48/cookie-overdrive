/* In-page stand-in for js/core.js used by the exporter harness (no timers, no audio, no save).
 * Time and RGB hue are frozen and driven by the exporter:
 *   window.__T   → CO.now()           window.__HUE → CO.hue(0)
 * Math.random is replaced by a seedable PRNG so every export is byte-for-byte reproducible:
 *   window.__seed(n)
 */
(function () {
  'use strict';
  const CO = (window.CO = window.CO || {});
  function mulberry32(a) {
    return function () { a |= 0; a = (a + 0x6d2b79f5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  }
  window.__seed = (n) => { Math.random = mulberry32(n >>> 0); };
  window.__seed(12345);
  window.__T = 0; window.__HUE = 0;

  const handlers = {};
  CO.on = (ev, fn) => { (handlers[ev] = handlers[ev] || []).push(fn); return () => CO.off(ev, fn); };
  CO.off = (ev, fn) => { const a = handlers[ev]; if (a) { const i = a.indexOf(fn); if (i >= 0) a.splice(i, 1); } };
  CO.emit = (ev, p) => { (handlers[ev] || []).slice().forEach((fn) => fn(p || {})); };

  CO.now = () => window.__T;
  CO.hue = (o = 0) => ((((window.__HUE + o) % 360) + 360) % 360);
  CO.bpm = 120;
  CO.beatPhase = () => 0;

  CO.state = {
    cookies: 0, totalBaked: 0, allTimeBaked: 0, clicks: 0, gems: 0, rebirths: 0, stars: 0,
    buildings: {}, upgrades: {}, skin: 'classic', skinsOwned: { classic: true }, theme: 'synthwave', themesOwned: { synthwave: true },
    pets: [], equipped: [], mg: {}, flags: {}, stats: {},
    settings: { sfx: 0, music: 0, musicOn: false, rgbSpeed: 1, particles: 2, shake: false, trail: false, reducedMotion: false, numFormat: 'short', showFps: false, uiHue: 'rgb' },
  };
  CO.settings = CO.state.settings;
  CO.vis = {};
  CO.combo = { count: 0, mult: 1, heat: 0 };
  CO.fever = { active: false, until: 0 };
  CO.buffs = [];
  CO.golden = { list: [] };
  CO.boss = null;
  const D = () => CO.data;
  CO.skin = () => D().skins.find((s) => s.id === CO.state.skin) || D().skins[0];
  CO.theme = () => D().themes.find((t) => t.id === CO.state.theme) || D().themes[0];
  CO.petDef = (id) => D().pets.find((p) => p.id === id);
  CO.equippedPets = () => [];
  CO.fmt = (n) => String(Math.round(n));
})();
