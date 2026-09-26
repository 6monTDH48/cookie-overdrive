/* COOKIE OVERDRIVE — mg-rhythm.js : « Crunch Rythme » (id: rhythm)
 * 4-lane vertical rhythm game on a procedurally generated synthwave track (WebAudio).
 * The music and the chart are both derived from the same step data (SONG), so every note
 * sits exactly on a 16th/8th of the track. Timing is read from the audio output clock.
 */
(function () {
  'use strict';
  const CO = window.CO;
  if (!CO || typeof CO.registerMinigame !== 'function') return;

  /* ───────────────────────── constants ───────────────────────── */
  const FD = '"Lilita One", "Arial Rounded MT Bold", "Trebuchet MS", sans-serif';
  const FM = '"Chakra Petch", ui-monospace, Menlo, monospace';
  const INK = '#1a0b33';

  const BPM = 126;
  const SPB = 60 / BPM;              // seconds per beat
  const STEP = SPB / 4;              // one 16th
  const BARS = 26;
  const STEPS = BARS * 16;
  const COUNT_IN = 4;                // beats of 3-2-1-GO before the song
  const APPROACH = 1.15;             // seconds for a note to fall from the top to the hit line
  const WIN_P = 0.045, WIN_G = 0.09, WIN_EARLY = 0.14;
  const INPUT_OFFSET = 0.012;        // global offset: input events arrive a bit late
  const LANE_COL = ['#1ff4ff', '#ff2bd6', '#b6ff3b', '#ffc93c'];
  const KEYMAP = { KeyD: 0, KeyF: 1, KeyJ: 2, KeyK: 3, ArrowLeft: 0, ArrowDown: 1, ArrowUp: 2, ArrowRight: 3 };
  const KEY_LABEL = ['D', 'F', 'J', 'K'];

  /* ───────────────────────── song data ───────────────────────── */
  // A minor synthwave: Am – F – C – G, one chord per bar.
  const CHORDS = [
    { bass: 33, arp: [69, 72, 76, 81], pad: [57, 60, 64] }, // Am
    { bass: 29, arp: [65, 69, 72, 77], pad: [53, 57, 60] }, // F
    { bass: 36, arp: [67, 72, 76, 79], pad: [55, 60, 64] }, // C
    { bass: 31, arp: [67, 71, 74, 79], pad: [55, 59, 62] }, // G
  ];
  const ARP = [0, 1, 2, 3, 1, 2, 3, 2, 0, 1, 2, 3, 3, 2, 1, 0];
  // drop lead: [step in 4-bar loop, midi, length in 16ths]
  const LEAD = [
    [0, 69, 2], [2, 72, 2], [4, 76, 4], [8, 74, 2], [10, 72, 2], [12, 76, 4],
    [16, 77, 4], [20, 76, 2], [22, 72, 2], [24, 69, 4], [28, 72, 4],
    [32, 79, 4], [36, 76, 2], [38, 79, 2], [40, 81, 4], [44, 79, 2], [46, 76, 2],
    [48, 74, 6], [54, 71, 2], [56, 74, 4], [60, 79, 4],
  ];

  function section(bar) {
    if (bar < 4) return 'intro';
    if (bar < 8) return 'verseA';
    if (bar < 12) return 'verseB';
    if (bar < 14) return 'build';
    if (bar < 22) return 'drop';
    if (bar < 24) return 'break';
    return 'outro';
  }

  function stepEvents(i) {
    const bar = i >> 4, s = i & 15, sec = section(bar), ch = CHORDS[bar & 3];
    const ev = [];
    const q = s % 4 === 0;
    let kick;
    if (sec === 'build') kick = q && !(bar === 13 && s >= 12);
    else if (sec === 'outro') kick = bar === 24 ? q : s === 0;
    else kick = q;
    if (kick) ev.push({ k: 'kick' });
    if ((s === 4 || s === 12) && (sec === 'verseA' || sec === 'verseB' || sec === 'drop' || (sec === 'outro' && bar === 24))) ev.push({ k: 'clap' });
    if (sec === 'build') {
      if (bar === 12 && s % 2 === 0) ev.push({ k: 'snare', v: 0.35 + s * 0.025 });
      if (bar === 13 && s < 12) ev.push({ k: 'snare', v: 0.55 + s * 0.035 });
    }
    if (sec === 'verseB' || sec === 'drop' || (sec === 'build' && !(bar === 13 && s >= 12))) {
      if (s % 4 === 2) ev.push({ k: 'hat', open: sec === 'drop', v: 0.6 });
      else ev.push({ k: 'hat', v: s % 2 ? 0.22 : 0.34 });
    } else if (sec !== 'outro' || bar === 24) {
      if (s % 4 === 2) ev.push({ k: 'hat', v: 0.5 });
    }
    const cut = sec === 'intro' ? 380 : sec === 'verseA' ? 700 : sec === 'drop' ? 1700 : 1000;
    const pump = (sec === 'intro' && bar >= 2) || sec === 'verseA' || sec === 'verseB' || sec === 'drop' ||
      (sec === 'build' && !(bar === 13 && s >= 8)) || (sec === 'outro' && bar === 24);
    if (pump && s % 2 === 0) ev.push({ k: 'bass', m: ch.bass + (s % 4 === 0 ? 0 : 12), len: 2, cut });
    if (sec === 'break' && s === 0) ev.push({ k: 'bass', m: ch.bass, len: 15, cut: 520 });
    if (bar === 25 && s === 0) ev.push({ k: 'bass', m: 33, len: 24, cut: 600 });
    const arpOn = sec === 'verseA' ? s % 2 === 0 : (sec === 'verseB' || sec === 'build' || sec === 'drop' || sec === 'break' || (sec === 'outro' && bar === 24));
    if (arpOn) {
      const ai = ARP[s];
      let acut = sec === 'verseA' ? 900 : sec === 'verseB' ? 1700 : sec === 'drop' ? 3200 : sec === 'break' ? 2200 : 1600;
      if (sec === 'build') acut = 1200 + ((bar - 12) * 16 + s) * 140;
      ev.push({ k: 'arp', m: ch.arp[ai], ai, cut: acut, v: sec === 'verseA' ? 0.7 : 1 });
    }
    if (sec === 'drop') {
      const ls = ((bar - 14) & 3) * 16 + s;
      for (const n of LEAD) if (n[0] === ls) ev.push({ k: 'lead', m: n[1], len: n[2], hi: bar >= 18 });
    }
    if (s === 0 && (sec === 'verseB' || sec === 'drop' || sec === 'break')) ev.push({ k: 'pad', ms: ch.pad, len: 16 });
    if (s === 0 && bar === 25) ev.push({ k: 'pad', ms: [57, 60, 64, 69], len: 28 });
    if (s === 0 && (bar === 4 || bar === 8 || bar === 14 || bar === 18 || bar === 22 || bar === 25)) ev.push({ k: 'crash', v: bar === 14 || bar === 25 ? 1 : 0.6 });
    if (i === 12 * 16) ev.push({ k: 'riser', len: 32 });
    if (i === 14 * 16) ev.push({ k: 'boom' });
    return ev;
  }

  const SONG = [];
  for (let i = 0; i < STEPS; i++) SONG.push(stepEvents(i));

  /* chart: generated from SONG so every note is on an instrument hit */
  function fixLanes(lanes, avoid) {
    const out = [];
    for (const l0 of lanes) {
      let pick = l0;
      for (const d of [0, 1, -1, 2, -2, 3, -3]) {
        const c = l0 + d;
        if (c < 0 || c > 3 || avoid.includes(c) || out.includes(c)) continue;
        pick = c; break;
      }
      out.push(pick);
    }
    return out;
  }
  function buildChart() {
    const out = [];
    const bucket = (m) => (m <= 69 ? 0 : m <= 72 ? 1 : m <= 76 ? 2 : 3);
    const recent = [];
    for (let i = 0; i < STEPS; i++) {
      const bar = i >> 4, s = i & 15, sec = section(bar), c = bar & 3;
      const ev = SONG[i];
      const get = (k) => ev.find((e) => e.k === k);
      const kickL = (c + (s >> 2)) % 2;
      const clapL = 2 + (((s >> 3) + c) % 2);
      let lanes = null;
      switch (sec) {
        case 'intro':
          if (get('kick') && (bar >= 2 || s % 8 === 0)) lanes = [kickL];
          break;
        case 'verseA':
          if (get('kick') && s % 8 === 0) lanes = [kickL];
          else if (get('clap')) lanes = [clapL];
          else if (bar === 7 && s === 14) lanes = [get('arp').ai];
          break;
        case 'verseB':
          if (get('kick') && s % 8 === 0) lanes = s === 0 && bar % 2 === 0 ? [kickL, 3] : [kickL];
          else if (get('clap')) lanes = [clapL];
          else if (s === 6 || s === 14) lanes = [get('arp').ai];
          break;
        case 'build':
          if (bar === 12 && s % 2 === 0) lanes = [(s >> 1) % 4];
          else if (bar === 13 && s < 8 && s % 2 === 0) lanes = [(s >> 1) % 4];
          else if (bar === 13 && s >= 8 && s < 12) lanes = [s % 4];
          break;
        case 'drop': {
          const burst = bar % 2 === 1 && s >= 12;
          const lead = get('lead');
          if (burst) lanes = [get('arp').ai];
          else if (lead) { const l = bucket(lead.m); lanes = s === 0 ? [l, l <= 1 ? 3 : 0] : [l]; }
          else if (bar >= 18 && s % 2 === 0) lanes = [get('arp').ai];
          break;
        }
        case 'break':
          if (s % 4 === 0) lanes = [get('arp').ai];
          break;
        default: // outro
          if (bar === 24) {
            if (get('kick') && s % 8 === 0) lanes = [kickL];
            else if (get('clap')) lanes = [clapL];
          } else if (s === 0) lanes = [0, 3];
      }
      if (!lanes) continue;
      lanes = fixLanes(lanes, recent.filter((r) => i - r.step <= 2).map((r) => r.lane));
      for (const l of lanes) { out.push({ t: i * STEP, lane: l, step: i, chord: lanes.length > 1 }); recent.push({ step: i, lane: l }); }
      if (recent.length > 8) recent.splice(0, recent.length - 8);
    }
    return out;
  }
  const CHART = buildChart();
  const LAST_T = CHART[CHART.length - 1].t;
  const SONG_LEN = STEPS * STEP;
  const DEMO_A = 14 * 16 * STEP, DEMO_LEN = 8 * 16 * STEP; // attract mode loops the drop

  /* ───────────────────────── synth ───────────────────────── */
  function createSynth(a) {
    const ctx = a.ctx;
    const live = new Map(); // source → chain to disconnect
    const master = ctx.createGain(); master.gain.value = 0.8;
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -16; comp.knee.value = 8; comp.ratio.value = 5; comp.attack.value = 0.002; comp.release.value = 0.12;
    master.connect(comp); comp.connect(a.out);
    const duck = ctx.createGain(); duck.connect(master);
    const send = ctx.createGain(); send.gain.value = 0.3;
    const dl = ctx.createDelay(1.5); dl.delayTime.value = STEP * 3;
    const fb = ctx.createGain(); fb.gain.value = 0.33;
    const dlf = ctx.createBiquadFilter(); dlf.type = 'lowpass'; dlf.frequency.value = 2600;
    send.connect(dl); dl.connect(dlf); dlf.connect(fb); fb.connect(dl); dlf.connect(master);
    const fixed = [master, comp, duck, send, dl, fb, dlf];

    const nb = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
    const nd = nb.getChannelData(0);
    for (let i = 0; i < nd.length; i++) nd[i] = Math.random() * 2 - 1;

    const mtof = (m) => 440 * Math.pow(2, (m - 69) / 12);
    function reg(src, chain) {
      live.set(src, chain);
      src.onended = () => { live.delete(src); for (const n of chain) { try { n.disconnect(); } catch (e) { /* */ } } };
    }
    function noise(t, dur, type, freq, vol, dest, q) {
      const s = ctx.createBufferSource(); s.buffer = nb; s.loop = true;
      const f = ctx.createBiquadFilter(); f.type = type; f.frequency.value = freq; if (q) f.Q.value = q;
      const g = ctx.createGain();
      g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
      s.connect(f); f.connect(g); g.connect(dest);
      s.start(t, Math.random() * 0.8); s.stop(t + dur + 0.02); reg(s, [s, f, g]);
      return g;
    }
    function tone(t, type, f0, f1, dur, vol, dest) {
      const o = ctx.createOscillator(), g = ctx.createGain();
      o.type = type; o.frequency.setValueAtTime(f0, t); if (f1) o.frequency.exponentialRampToValueAtTime(f1, t + dur * 0.4);
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + 0.004); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
      o.connect(g); g.connect(dest); o.start(t); o.stop(t + dur + 0.02); reg(o, [o, g]);
    }
    const I = {
      kick(t) {
        const o = ctx.createOscillator(), g = ctx.createGain();
        o.type = 'sine'; o.frequency.setValueAtTime(170, t); o.frequency.exponentialRampToValueAtTime(44, t + 0.12);
        g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(1, t + 0.005); g.gain.exponentialRampToValueAtTime(0.001, t + 0.42);
        o.connect(g); g.connect(master); o.start(t); o.stop(t + 0.45); reg(o, [o, g]);
        noise(t, 0.014, 'highpass', 2500, 0.22, master);
        duck.gain.setValueAtTime(0.28, t); duck.gain.linearRampToValueAtTime(1, t + 0.2);
      },
      clap(t) {
        const s = ctx.createBufferSource(); s.buffer = nb; s.loop = true;
        const f = ctx.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 1150; f.Q.value = 0.9;
        const g = ctx.createGain();
        g.gain.setValueAtTime(0.0001, t);
        for (const o of [0, 0.011, 0.022]) { g.gain.setValueAtTime(0.75, t + o); g.gain.exponentialRampToValueAtTime(0.1, t + o + 0.009); }
        g.gain.setValueAtTime(0.6, t + 0.031); g.gain.exponentialRampToValueAtTime(0.001, t + 0.26);
        s.connect(f); f.connect(g); g.connect(master); g.connect(send);
        s.start(t, Math.random() * 0.5); s.stop(t + 0.3); reg(s, [s, f, g]);
        tone(t, 'triangle', 190, 150, 0.09, 0.22, master);
      },
      snare(t, e) { noise(t, 0.12, 'bandpass', 1800, 0.5 * e.v, master, 0.7); tone(t, 'triangle', 220, 170, 0.07, 0.18 * e.v, master); },
      hat(t, e) { noise(t, e.open ? 0.16 : 0.035, 'highpass', 7800, 0.26 * e.v, master); },
      bass(t, e) {
        const dur = e.len * STEP;
        const o1 = ctx.createOscillator(), o2 = ctx.createOscillator(), f = ctx.createBiquadFilter(), g = ctx.createGain();
        o1.type = 'sawtooth'; o2.type = 'sawtooth'; o1.frequency.value = mtof(e.m); o2.frequency.value = mtof(e.m); o2.detune.value = 9;
        f.type = 'lowpass'; f.Q.value = 5;
        f.frequency.setValueAtTime(e.cut * 3.2, t); f.frequency.exponentialRampToValueAtTime(e.cut, t + 0.09);
        g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.3, t + 0.006);
        g.gain.setValueAtTime(0.3, t + dur * 0.6); g.gain.exponentialRampToValueAtTime(0.001, t + dur * 0.95 + 0.04);
        o1.connect(f); o2.connect(f); f.connect(g); g.connect(duck);
        o1.start(t); o2.start(t); o1.stop(t + dur + 0.06); o2.stop(t + dur + 0.06);
        reg(o1, [o1, f, g]); reg(o2, [o2]);
      },
      arp(t, e) {
        const o = ctx.createOscillator(), f = ctx.createBiquadFilter(), g = ctx.createGain();
        o.type = 'square'; o.frequency.value = mtof(e.m);
        f.type = 'lowpass'; f.frequency.value = Math.min(9000, e.cut); f.Q.value = 2;
        g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.085 * e.v, t + 0.004); g.gain.exponentialRampToValueAtTime(0.001, t + 0.15);
        o.connect(f); f.connect(g); g.connect(duck); g.connect(send);
        o.start(t); o.stop(t + 0.17); reg(o, [o, f, g]);
      },
      lead(t, e) {
        const dur = e.len * STEP;
        const f = ctx.createBiquadFilter(), g = ctx.createGain(), lfo = ctx.createOscillator(), lg = ctx.createGain();
        f.type = 'lowpass'; f.frequency.value = e.hi ? 4200 : 3000; f.Q.value = 1;
        lfo.frequency.value = 5.5; lg.gain.value = 14; lfo.connect(lg);
        const oscs = [-8, 8].concat(e.hi ? [1200] : []).map((det) => {
          const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.value = mtof(e.m); o.detune.value = det;
          lg.connect(o.detune); o.connect(f); return o;
        });
        g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.1, t + 0.012);
        g.gain.setValueAtTime(0.1, t + dur); g.gain.exponentialRampToValueAtTime(0.001, t + dur + 0.14);
        f.connect(g); g.connect(master); g.connect(send);
        const end = t + dur + 0.16;
        oscs.forEach((o, i) => { o.start(t); o.stop(end); reg(o, i ? [o] : [o, f, g]); });
        lfo.start(t); lfo.stop(end); reg(lfo, [lfo, lg]);
      },
      pad(t, e) {
        const dur = e.len * STEP;
        const f = ctx.createBiquadFilter(), g = ctx.createGain();
        f.type = 'lowpass'; f.frequency.value = 1400;
        g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.035, t + 0.35);
        g.gain.setValueAtTime(0.035, t + dur); g.gain.linearRampToValueAtTime(0.0001, t + dur + 0.45);
        f.connect(g); g.connect(duck);
        let first = true;
        for (const m of e.ms) for (const det of [-11, 11]) {
          const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.value = mtof(m); o.detune.value = det;
          o.connect(f); o.start(t); o.stop(t + dur + 0.5); reg(o, first ? [o, f, g] : [o]); first = false;
        }
      },
      crash(t, e) { const g = noise(t, 1.6, 'highpass', 4500, 0.28 * e.v, master); g.connect(send); },
      riser(t, e) {
        const dur = e.len * STEP;
        const s = ctx.createBufferSource(); s.buffer = nb; s.loop = true;
        const f = ctx.createBiquadFilter(); f.type = 'bandpass'; f.Q.value = 3;
        f.frequency.setValueAtTime(300, t); f.frequency.exponentialRampToValueAtTime(7000, t + dur);
        const g = ctx.createGain(); g.gain.setValueAtTime(0.001, t); g.gain.exponentialRampToValueAtTime(0.32, t + dur);
        s.connect(f); f.connect(g); g.connect(master);
        s.start(t); s.stop(t + dur); reg(s, [s, f, g]);
      },
      boom(t) { tone(t, 'sine', 90, 30, 1.2, 0.7, master); },
    };
    return {
      ctx,
      play(e, t) { const fn = I[e.k]; if (fn) fn(t, e); },
      blip(t, go) {
        tone(t, 'square', go ? 1046 : 784, 0, go ? 0.4 : 0.16, 0.12, master);
        if (go) tone(t, 'square', 1568, 0, 0.4, 0.07, master);
      },
      crunch(lane, perfect) {
        const t = ctx.currentTime;
        noise(t, 0.05, 'bandpass', 2000 + lane * 450, 0.4, master, 1.4);
        if (perfect) tone(t, 'sine', 1300 + lane * 140, 0, 0.06, 0.09, master);
      },
      kill() {
        live.forEach((chain, src) => {
          src.onended = null;
          try { src.stop(0); } catch (e) { /* not started */ }
          for (const n of chain) { try { n.disconnect(); } catch (e) { /* */ } }
        });
        live.clear();
        for (const n of fixed) { try { n.disconnect(); } catch (e) { /* */ } }
      },
    };
  }

  /* ───────────────────────── helpers ───────────────────────── */
  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
  const rand = (a, b) => a + Math.random() * (b - a);
  const hsl = (h, s, l, a) => (a === undefined ? `hsl(${h},${s}%,${l}%)` : `hsla(${h},${s}%,${l}%,${a})`);
  const easeOutBack = (x) => { const c1 = 1.9, c3 = c1 + 1; return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2); };
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
  function el(tag, cls, html) { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; }
  function letters(text) { return text.split('').map((c) => (c === ' ' ? '<span class="l sp">&nbsp;</span>' : `<span class="l">${c}</span>`)).join(''); }
  const fmtInt = (n) => Math.round(n).toLocaleString('fr-FR');

  /* shared vector art (CO.art from art.js, optional). No emoji anywhere: every picture is vector. */
  function artDraw(ctx, name, x, y, size, opts) {
    const A = CO.art;
    if (!A || typeof A.draw !== 'function') return false;
    try { return A.draw(ctx, name, x, y, size, opts || {}) !== false; } catch (e) { return false; }
  }
  // DOM icon slot; hydrateArt() swaps in CO.art.el(name) or keeps the CSS fallback shape
  const ico = (name, fb) => `<i class="cor-ico cor-fb-${fb || 'none'}" data-art="${name}"></i>`;
  function hydrateArt(scope) {
    const A = CO.art;
    if (!A || typeof A.el !== 'function') return;
    scope.querySelectorAll('[data-art]').forEach((slot) => {
      const name = slot.getAttribute('data-art');
      if (typeof A.has === 'function' && !A.has(name)) return; // unknown icon → keep the CSS fallback
      let img = null;
      try { img = A.el(name, 'cor-img'); } catch (e) { img = null; }
      if (img) { slot.classList.add('has-art'); slot.appendChild(img); }
    });
  }
  function noteGlyph(c, x, y, s, col, rot) {
    if (artDraw(c, 'ui:music', x + s * 0.2, y - s * 0.45, s * 1.25, { rot: rot || 0 })) return;
    c.save(); c.translate(x, y); c.rotate(rot || -0.2);
    c.beginPath();
    c.ellipse(0, 0, s * 0.3, s * 0.22, -0.35, 0, Math.PI * 2);
    c.moveTo(s * 0.2, -s * 0.05); c.lineTo(s * 0.2, -s * 0.95);
    c.quadraticCurveTo(s * 0.62, -s * 0.8, s * 0.62, -s * 0.42); c.quadraticCurveTo(s * 0.5, -s * 0.6, s * 0.32, -s * 0.62);
    c.lineTo(s * 0.32, -s * 0.05); c.closePath();
    c.lineJoin = 'round'; c.lineWidth = s * 0.14; c.strokeStyle = INK; c.stroke();
    c.fillStyle = col; c.fill();
    c.restore();
  }

  const CSS = `
.cor-wrap{position:absolute;inset:0;overflow:hidden;background:#0b0620;color:#fff6fe;font-family:'Fredoka',system-ui,sans-serif;-webkit-user-select:none;user-select:none;-webkit-tap-highlight-color:transparent}
.cor-cv{position:absolute;inset:0;width:100%;height:100%;display:block;touch-action:none}
.cor-layer{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;padding:12px;box-sizing:border-box;pointer-events:none}
.cor-panel{pointer-events:auto;position:relative;width:min(400px,100%);max-height:100%;overflow-y:auto;box-sizing:border-box;padding:14px 16px 16px;border-radius:24px;text-align:center;background:linear-gradient(180deg,rgba(44,18,98,.9),rgba(16,7,40,.94));border:3px solid #1a0b33;box-shadow:0 0 0 2px rgba(182,255,59,.6),0 0 38px rgba(182,255,59,.33),0 8px 0 #1a0b33;animation:cor-in .45s cubic-bezier(.2,1.5,.4,1) both;scrollbar-width:none}
.cor-panel::-webkit-scrollbar{display:none}
.cor-title{font-size:clamp(34px,11vw,52px);line-height:.95;margin:2px 0 2px;white-space:nowrap}
.cor-title .l{display:inline-block;animation:cor-wave 1.1s ease-in-out infinite}
.cor-title .sp{width:.25em}
.cor-sub{font-weight:600;color:#b3a6dd;font-size:14px;margin-bottom:2px}
.cor-hero{width:118px;height:118px;display:block;margin:0 auto}
.cor-how{font-size:14px;line-height:1.35;color:#ece4ff;margin:2px 0 8px}
.cor-how b{color:#b6ff3b}
.cor-keys{display:flex;gap:7px;justify-content:center;margin:4px 0 8px}
.cor-keys kbd{font-family:'Lilita One',sans-serif;font-size:18px;min-width:36px;padding:5px 0 7px;border-radius:9px;border:2px solid #1a0b33;color:#1a0b33;box-shadow:0 3px 0 #1a0b33;background:#fff}
.cor-best{font-family:'Chakra Petch',monospace;font-weight:700;color:#ffc93c;margin:4px 0 12px;font-size:15px;letter-spacing:.04em}
.cor-tip{font-size:12px;color:#8f81c4;margin-top:10px}
.cor-go{animation:cor-pulse 1s ease-in-out infinite}
.cor-rank{font-family:'Lilita One',sans-serif;font-size:clamp(76px,26vw,112px);line-height:.9;margin-top:2px;-webkit-text-stroke:.07em #1a0b33;paint-order:stroke fill;animation:cor-rank .6s cubic-bezier(.2,1.8,.4,1) 1.2s both}
.cor-rmsg{font-weight:700;font-size:15px;color:#e9e0ff;margin:2px 0 4px;animation:cor-in .4s ease 1.5s both}
.cor-nb{font-size:26px;margin:4px 0;animation:cor-nb .7s ease-in-out infinite alternate}
.cor-nb .l{display:inline-block}
.cor-score{margin:4px 0}
.cor-score span{display:block;font-family:'Chakra Petch',monospace;font-size:11px;letter-spacing:.14em;color:#b3a6dd}
.cor-score b{font-family:'Lilita One',sans-serif;font-weight:400;font-size:40px;line-height:1.05}
.cor-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;margin:8px 0}
.cor-grid div{background:rgba(0,0,0,.3);border-radius:12px;padding:5px 2px 6px;border:2px solid rgba(255,255,255,.07)}
.cor-grid span{display:block;font-family:'Chakra Petch',monospace;font-weight:700;font-size:10px;color:#b3a6dd;letter-spacing:.06em}
.cor-grid b{font-family:'Lilita One',sans-serif;font-weight:400;font-size:20px}
.cor-grid .p b{color:#b6ff3b}.cor-grid .g b{color:#1ff4ff}.cor-grid .m b{color:#ff4d6d}
.cor-fc{font-size:22px;color:#ffc93c;margin:2px 0}
.cor-rew{display:flex;gap:8px;justify-content:center;flex-wrap:wrap;margin:8px 0 14px}
.cor-chip{font-family:'Lilita One',sans-serif;font-size:21px;padding:6px 14px 8px;border-radius:999px;background:rgba(255,201,60,.15);border:2px solid #ffc93c;color:#fff1c2;box-shadow:0 0 16px rgba(255,201,60,.35);animation:cor-in .45s cubic-bezier(.2,1.6,.4,1) both}
.cor-chip.gem{background:rgba(31,244,255,.13);border-color:#1ff4ff;color:#d8fdff;box-shadow:0 0 16px rgba(31,244,255,.35)}
.cor-chip.none{background:rgba(255,255,255,.05);border-color:#7d6fae;color:#b3a6dd;box-shadow:none}
.cor-btns{display:flex;gap:10px;justify-content:center;flex-wrap:wrap}
.cor-ico{display:inline-block;width:1.15em;height:1.15em;vertical-align:-.22em;margin:0 .12em;position:relative;flex:0 0 auto}
.cor-ico img,.cor-img{width:100%;height:100%;display:block;object-fit:contain}
.cor-ico.has-art{background:none!important;clip-path:none!important;box-shadow:none!important}
.cor-fb-none:not(.has-art){display:none}
.cor-fb-cookie{border-radius:50%;background:radial-gradient(circle at 34% 36%,#4a2511 0 9%,transparent 10%),radial-gradient(circle at 66% 52%,#4a2511 0 9%,transparent 10%),radial-gradient(circle at 42% 72%,#4a2511 0 8%,transparent 9%),#d99a4e;box-shadow:inset 0 0 0 .1em #8a5220,0 0 0 .08em #1a0b33}
.cor-fb-gem{background:linear-gradient(135deg,#e6feff,#1ff4ff 50%,#0a8fb8);clip-path:polygon(50% 100%,0 36%,20% 6%,80% 6%,100% 36%)}
.cor-fb-trophy{background:linear-gradient(#fff0a0,#ffb800);clip-path:polygon(12% 4%,88% 4%,82% 44%,58% 62%,58% 76%,76% 76%,76% 96%,24% 96%,24% 76%,42% 76%,42% 62%,18% 44%)}
.cor-fb-play{background:#fff;clip-path:polygon(18% 8%,94% 50%,18% 92%)}
.cor-fb-fire{background:linear-gradient(#fff08a,#ff8a1f 55%,#ff2b4a);clip-path:polygon(50% 0,70% 30%,86% 20%,96% 60%,80% 96%,20% 96%,4% 60%,20% 34%,34% 46%)}
.cor-rm .cor-title .l,.cor-rm .cor-go,.cor-rm .cor-nb{animation:none}
@keyframes cor-in{from{transform:scale(.6) translateY(30px);opacity:0}to{transform:none;opacity:1}}
@keyframes cor-wave{0%,100%{transform:translateY(0)}50%{transform:translateY(-5px) rotate(-3deg)}}
@keyframes cor-pulse{0%,100%{transform:scale(1)}50%{transform:scale(1.07)}}
@keyframes cor-rank{from{transform:scale(3) rotate(-20deg);opacity:0}to{transform:none;opacity:1}}
@keyframes cor-nb{from{transform:scale(1) rotate(-2deg)}to{transform:scale(1.1) rotate(2deg)}}
`;

  /* ───────────────────────── minigame ───────────────────────── */
  CO.registerMinigame({
    id: 'rhythm',
    name: 'Crunch Rythme',
    color: '#b6ff3b',
    tagline: 'Croque les cookies en rythme. Full combo ou rien.',
    howto: 'Tape la bonne colonne (D F J K / flèches / tap) quand le cookie touche la ligne. PERFECT = ±45 ms.',
    mount,
  });

  function mount(root, api) {
    let alive = true;
    const S = () => api.settings() || {};
    const wrap = el('div', 'cor-wrap');
    const style = el('style'); style.textContent = CSS; wrap.appendChild(style);
    const cv = el('canvas', 'cor-cv'); wrap.appendChild(cv);
    const ctx = cv.getContext('2d');
    const layer = el('div', 'cor-layer'); wrap.appendChild(layer);
    root.appendChild(wrap);
    if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
    const coarse = !!(window.matchMedia && window.matchMedia('(pointer: coarse)').matches);

    /* layout */
    let W = 320, H = 480, DPR = 1;
    const G = { hw: 300, lw: 75, cx: 160, hitY: 400, persp: 0.6, nr: 24, speed: 300 };
    function resize() {
      const r = root.getBoundingClientRect();
      W = Math.max(200, r.width || root.clientWidth || 320); H = Math.max(240, r.height || root.clientHeight || 480);
      DPR = Math.min(2, window.devicePixelRatio || 1);
      cv.width = Math.round(W * DPR); cv.height = Math.round(H * DPR);
      G.hw = Math.min(W - 16, 500);
      G.lw = G.hw / 4;
      G.cx = W / 2;
      G.hitY = H - clamp(H * 0.16, 76, 128);
      G.persp = 0.6;
      G.nr = Math.min(G.lw * 0.33, 30);
      G.speed = (G.hitY + G.nr * 2) / APPROACH;
    }
    const ro = new ResizeObserver(resize); ro.observe(root);
    resize();
    const kAt = (y) => G.persp + (1 - G.persp) * (y / G.hitY);
    const laneX = (l, y) => G.cx + ((l + 0.5) * G.lw - G.hw / 2) * kAt(y);
    const laneFromXY = (x, y) => clamp(Math.floor(((x - G.cx) / kAt(clamp(y, 0, H))) / G.lw + 2), 0, 3);

    /* run state */
    let mode = 'start'; // start | play | results
    let notes = [], first = 0;
    let score = 0, combo = 0, maxCombo = 0, nP = 0, nG = 0, nM = 0, hype = 0, hypeMaxShown = false, rgbMode = false;
    let songT = -10, synth = null, schedTimer = 0, nextStep = 0, t0 = 0, audioMode = false, perfT0 = 0, waitSince = 0;
    const clk = { base: 0, init: false };
    let lastCount = 99;
    const held = [false, false, false, false];
    const press = [0, 0, 0, 0], flashL = [0, 0, 0, 0], missL = [0, 0, 0, 0];
    const ptrLane = new Map();
    let judge = null, comboPop = 0, shake = 0, flash = 0, flashCol = '#fff';
    const parts = [], rings = [], banners = [];
    let demo0 = performance.now() / 1000, demoPrev = DEMO_A;
    let res = null; // results data
    let heroCv = null, titleLs = [], nbLs = [], scoreEl = null;

    const colOf = (l) => (rgbMode ? hsl((api.hue(l * 50) + 0) % 360, 100, 62) : LANE_COL[l]);
    const budget = () => { const s = S(); return [0.3, 0.6, 1][clamp(s.particles == null ? 2 : s.particles, 0, 2)] * (s.reducedMotion ? 0.45 : 1); };
    const maxParts = () => [90, 220, 480][clamp(S().particles == null ? 2 : S().particles, 0, 2)];
    const canShake = () => { const s = S(); return s.shake !== false && !s.reducedMotion; };
    const mult = (c) => Math.min(4, 1 + Math.floor(c / 25) * 0.5);

    /* ── clock ── */
    function audioSongTime() {
      const c = synth.ctx;
      let ct = c.currentTime - (c.outputLatency || c.baseLatency || 0);
      if (c.getOutputTimestamp) {
        const ts = c.getOutputTimestamp();
        if (ts && ts.contextTime > 0 && ts.performanceTime > 0) ct = ts.contextTime + (performance.now() - ts.performanceTime) / 1000;
      }
      return ct - t0;
    }
    function songNow() {
      const perf = performance.now() / 1000;
      if (!audioMode || !synth) return perf - perfT0;
      const raw = audioSongTime();
      if (!clk.init) { clk.base = raw - perf; clk.init = true; } else {
        const err = raw - (perf + clk.base);
        if (Math.abs(err) > 0.05) clk.base = raw - perf; else clk.base += err * 0.06;
      }
      return perf + clk.base;
    }
    function schedule() {
      if (!synth) return;
      const c = synth.ctx, horizon = c.currentTime + 0.25;
      while (nextStep < STEPS && t0 + nextStep * STEP < horizon) {
        const tt = t0 + nextStep * STEP;
        if (tt >= c.currentTime - 0.02) for (const e of SONG[nextStep]) synth.play(e, tt);
        nextStep++;
      }
      if (nextStep >= STEPS) { clearInterval(schedTimer); schedTimer = 0; }
    }
    function killAudio() {
      if (schedTimer) { clearInterval(schedTimer); schedTimer = 0; }
      if (synth) { synth.kill(); synth = null; }
    }

    /* ── FX ── */
    function burst(x, y, lane, perfect) {
      const b = budget(); const pal = (api.skin() || {}).pal || {};
      const cols = [pal.base || '#d99a4e', pal.light || '#f3c783', pal.chip || '#4a2511', pal.dark || '#a9652a'];
      const n = Math.round((perfect ? 18 : 10) * b), lim = maxParts();
      for (let i = 0; i < n && parts.length < lim; i++) {
        parts.push({ x, y, vx: rand(-280, 280), vy: rand(-560, -120), g: 1300, life: rand(0.35, 0.75), age: 0, sz: rand(2.5, 6.5), col: cols[i % cols.length], rot: rand(0, 6), vr: rand(-12, 12), sh: 0 });
      }
      const ns = Math.round((perfect ? 10 : 5) * b);
      for (let i = 0; i < ns && parts.length < lim; i++) {
        const a = rand(-Math.PI, 0), sp = rand(250, 620);
        parts.push({ x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, g: 300, life: rand(0.2, 0.45), age: 0, sz: rand(2, 3.5), col: colOf(lane), rot: 0, vr: 0, sh: 1 });
      }
      rings.push({ x, y, age: 0, life: perfect ? 0.4 : 0.3, r0: G.nr * 0.9, col: colOf(lane), w: perfect ? 6 : 4 });
    }
    function confetti(n) {
      const lim = maxParts(); n = Math.round(n * budget());
      for (let i = 0; i < n && parts.length < lim; i++) {
        parts.push({ x: rand(0, W), y: rand(-60, -10), vx: rand(-60, 60), vy: rand(80, 260), g: 120, life: rand(2, 3.5), age: 0, sz: rand(4, 8), col: hsl(rand(0, 360), 100, 62), rot: rand(0, 6), vr: rand(-8, 8), sh: 2 });
      }
    }
    function banner(text, col, big, icon) { banners.push({ text, col, age: 0, big: !!big, icon }); if (banners.length > 3) banners.shift(); }
    function doFlash(a, col) { if (S().reducedMotion) return; flash = Math.max(flash, a); flashCol = col || '#fff'; }

    /* ── judgement ── */
    function onHit(n, perfect, early) {
      n.j = perfect ? 1 : 2; n.jt = songT;
      combo++; if (combo > maxCombo) maxCombo = combo;
      score += Math.round((perfect ? 300 : 100) * mult(combo));
      if (perfect) nP++; else nG++;
      hype = Math.min(1, hype + (perfect ? 0.022 : 0.011));
      judge = { text: perfect ? 'PERFECT' : 'GOOD', perfect, early, age: 0 };
      flashL[n.lane] = 1; comboPop = 1;
      burst(laneX(n.lane, G.hitY), G.hitY, n.lane, perfect);
      if (synth) synth.crunch(n.lane, perfect);
      else api.sfx(perfect ? 'perfect' : 'good', { vol: 0.35, pitch: 1 + n.lane * 0.06 });
      if (combo % 25 === 0) {
        banner(`COMBO ×${combo}`, '#ffc93c', true, 'ui:fire');
        if (mult(combo) > mult(combo - 1)) banner(`MULTI ×${String(mult(combo)).replace('.', ',')}`, '#b6ff3b', false, 'ui:bolt');
        api.sfx('combo', { vol: 0.6, pitch: 1 + Math.min(combo, 150) / 300 });
        if (canShake()) shake = Math.max(shake, 7);
        doFlash(0.18, '#fff');
      }
      if (combo === 50) { rgbMode = true; banner('MODE RGB ACTIVÉ', 'rgb', true, 'ui:sparkle'); doFlash(0.35, '#fff'); confetti(40); }
      if (hype >= 1 && !hypeMaxShown) { hypeMaxShown = true; banner('HYPE MAX', 'rgb', false, 'ui:fire'); }
    }
    function onMiss(n) {
      n.j = -1; n.jt = songT; nM++;
      if (combo >= 10) banner('COMBO BREAK', '#ff4d6d');
      combo = 0; rgbMode = false;
      hype = Math.max(0, hype - 0.15); if (hype < 0.9) hypeMaxShown = false;
      judge = { text: 'MISS', miss: true, age: 0 };
      missL[n.lane] = 1;
      if (canShake()) shake = Math.max(shake, 5);
      api.sfx('miss', { vol: 0.45 });
    }
    function pressLane(lane, evStamp) {
      held[lane] = true; press[lane] = 1;
      if (mode !== 'play') return;
      const lag = clamp((performance.now() - (evStamp || performance.now())) / 1000, 0, 0.1);
      const t = songNow() - lag - INPUT_OFFSET;
      let best = null, bd = 1e9;
      for (let i = first; i < notes.length; i++) {
        const n = notes[i];
        if (n.t - t > WIN_EARLY) break;
        if (n.j || n.lane !== lane) continue;
        const d = Math.abs(n.t - t);
        if (d < bd) { bd = d; best = n; }
      }
      if (!best || bd > WIN_EARLY) return; // ghost tap: no penalty
      if (bd <= WIN_P) onHit(best, true, best.t > t);
      else if (bd <= WIN_G) onHit(best, false, best.t > t);
      else onMiss(best);
    }
    function releaseLane(lane) { held[lane] = false; }

    /* ── flow ── */
    function clearLayer() { layer.innerHTML = ''; heroCv = null; titleLs = []; nbLs = []; scoreEl = null; }
    function showStart() {
      mode = 'start'; clearLayer();
      const p = el('div', 'cor-panel');
      const best = api.best() || 0;
      p.innerHTML = `
        <div class="cor-title stroke-text">${letters('CRUNCH')}<br>${letters('RYTHME')}</div>
        <div class="cor-sub">Croque les cookies en rythme. Full combo ou rien.</div>
        <canvas class="cor-hero"></canvas>
        ${coarse ? '' : '<div class="cor-keys"><kbd>D</kbd><kbd>F</kbd><kbd>J</kbd><kbd>K</kbd></div>'}
        <div class="cor-how">${coarse ? 'Tape les <b>4 colonnes</b>' : 'Appuie (ou <b>← ↓ ↑ →</b>, ou clique)'} quand le cookie touche la ligne. <b>PERFECT</b> = ±45 ms. Enchaîne pour le <b>multi ×4</b> et le mode RGB.</div>
        <div class="cor-best">${ico('ui:trophy', 'trophy')} RECORD : ${best ? fmtInt(best) : '—'}</div>
        <button class="btn big green cor-go" type="button">JOUER ${ico('ui:play', 'play')}</button>
        <div class="cor-tip">Mets le son, la prod est une dinguerie</div>`;
      hydrateArt(p);
      layer.appendChild(p);
      heroCv = p.querySelector('.cor-hero');
      titleLs = [...p.querySelectorAll('.cor-title .l')];
      titleLs.forEach((s, i) => { s.style.animationDelay = `${-i * 0.08}s`; });
      p.querySelector('.cor-go').addEventListener('click', startRun);
    }
    function startRun() {
      if (!alive) return;
      clearLayer();
      api.sfx('click', { vol: 0.6 });
      notes = CHART.map((n) => ({ t: n.t, lane: n.lane, step: n.step, chord: n.chord, j: 0, jt: 0 }));
      first = 0; score = 0; combo = 0; maxCombo = 0; nP = 0; nG = 0; nM = 0; hype = 0; hypeMaxShown = false; rgbMode = false;
      judge = null; banners.length = 0; lastCount = 99; res = null;
      killAudio();
      const lead = 0.35 + COUNT_IN * SPB;
      audioMode = false;
      let a = null;
      try { a = api.audio && api.audio(); } catch (e) { a = null; }
      if (a && a.ctx && a.out) {
        try {
          synth = createSynth(a);
          t0 = a.ctx.currentTime + lead; nextStep = 0; clk.init = false; audioMode = true;
          for (let k = 0; k < COUNT_IN; k++) synth.blip(t0 - (COUNT_IN - k) * SPB, k === COUNT_IN - 1);
          schedule();
          schedTimer = setInterval(schedule, 30);
        } catch (e) { killAudio(); audioMode = false; }
      }
      perfT0 = performance.now() / 1000 + lead;
      waitSince = performance.now();
      songT = -lead;
      mode = 'play';
    }
    function finish() {
      mode = 'results';
      if (schedTimer) { clearInterval(schedTimer); schedTimer = 0; }
      const total = notes.length;
      const acc = total ? (nP + nG * 0.5) / total : 0;
      const rank = acc >= 0.95 ? 'S' : acc >= 0.85 ? 'A' : acc >= 0.7 ? 'B' : acc >= 0.5 ? 'C' : 'D';
      const cookies = Math.round(api.unit() * 6 * acc * acc);
      const gems = rank === 'S' ? 6 : rank === 'A' ? 3 : rank === 'B' ? 1 : 0;
      let r = null;
      try { r = api.end({ score, cookies, gems }); } catch (e) { r = null; }
      r = r || { cookies, gems, isNewBest: false };
      res = { acc, rank, score, r, t: performance.now() / 1000, lastTick: 0 };
      showResults();
    }
    function showResults() {
      clearLayer();
      const { acc, rank, r } = res;
      const msgs = { S: 'T\'es un robot ou quoi ?? Aura infinie.', A: 'Propre. Grosse aura.', B: 'Pas mal du tout, continue !', C: 'Mid… mais on y croit.', D: 'Skill issue (tkt, rejoue).' };
      const rc = { S: '#ffc93c', A: '#b6ff3b', B: '#1ff4ff', C: '#8a5cff', D: '#ff4d6d' }[rank];
      const p = el('div', 'cor-panel');
      const chips = [];
      if (r.cookies > 0) chips.push(`<span class="cor-chip">+${api.fmt(r.cookies)} ${ico('ui:cookie', 'cookie')}</span>`);
      if (r.gems > 0) chips.push(`<span class="cor-chip gem" style="animation-delay:.15s">+${api.fmt(r.gems)} ${ico('ui:gem', 'gem')}</span>`);
      if (!chips.length) chips.push(`<span class="cor-chip none">+0 ${ico('ui:cookie', 'cookie')} (ratio)</span>`);
      p.innerHTML = `
        <div class="cor-rank" style="color:${rc};text-shadow:0 .06em 0 #1a0b33,0 0 34px ${rc}">${rank}</div>
        <div class="cor-rmsg">${msgs[rank]}</div>
        ${r.isNewBest ? `<div class="cor-nb stroke-text">${letters('NOUVEAU RECORD !')}</div>` : ''}
        <div class="cor-score"><span>SCORE</span><b class="stroke-text">0</b></div>
        ${nM === 0 ? `<div class="cor-fc stroke-text">${ico('ui:fire', 'fire')} FULL COMBO ${ico('ui:fire', 'fire')}</div>` : ''}
        <div class="cor-grid">
          <div><span>PRÉCISION</span><b>${(acc * 100).toFixed(1).replace('.', ',')} %</b></div>
          <div><span>COMBO MAX</span><b>${maxCombo}</b></div>
          <div><span>NOTES</span><b>${nP + nG}/${notes.length}</b></div>
          <div class="p"><span>PERFECT</span><b>${nP}</b></div>
          <div class="g"><span>GOOD</span><b>${nG}</b></div>
          <div class="m"><span>MISS</span><b>${nM}</b></div>
        </div>
        <div class="cor-rew">${chips.join('')}</div>
        <div class="cor-btns"><button class="btn green cor-again" type="button">REJOUER</button><button class="btn dark cor-quit" type="button">QUITTER</button></div>`;
      hydrateArt(p);
      layer.appendChild(p);
      scoreEl = p.querySelector('.cor-score b');
      nbLs = [...p.querySelectorAll('.cor-nb .l')];
      p.querySelector('.cor-again').addEventListener('click', startRun);
      p.querySelector('.cor-quit').addEventListener('click', () => api.close());
      if (rank === 'S' || rank === 'A') { confetti(rank === 'S' ? 140 : 70); doFlash(0.3, '#fff'); }
      api.sfx(['S', 'A', 'B'].includes(rank) ? 'win' : 'lose', { vol: 0.8 });
      if (r.isNewBest) api.sfx('achievement', { vol: 0.8 });
    }

    /* ── input ── */
    function onPointerDown(e) {
      if (mode !== 'play') return;
      e.preventDefault();
      const r = cv.getBoundingClientRect();
      const lane = laneFromXY(e.clientX - r.left, e.clientY - r.top);
      ptrLane.set(e.pointerId, lane);
      pressLane(lane, e.timeStamp);
    }
    function onPointerUp(e) {
      const l = ptrLane.get(e.pointerId);
      if (l != null) { ptrLane.delete(e.pointerId); if (![...ptrLane.values()].includes(l)) releaseLane(l); }
    }
    function onKeyDown(e) {
      if (e.ctrlKey || e.metaKey || e.altKey) return;
      const lane = KEYMAP[e.code];
      if (lane != null) {
        e.preventDefault();
        if (!e.repeat) pressLane(lane, e.timeStamp);
        return;
      }
      if (e.code === 'Enter' || e.code === 'Space') {
        if (mode === 'start' || (mode === 'results' && res && performance.now() / 1000 - res.t > 0.8)) { e.preventDefault(); if (!e.repeat) startRun(); }
        else if (mode === 'play') e.preventDefault();
      }
    }
    function onKeyUp(e) { const lane = KEYMAP[e.code]; if (lane != null) releaseLane(lane); }
    function onBlur() { for (let i = 0; i < 4; i++) held[i] = false; ptrLane.clear(); }
    function onVis() {
      // tab hidden mid-song: rAF stops but audio would keep going → abort the run cleanly
      if (document.hidden && mode === 'play') { killAudio(); api.toast('Partie annulée : t\'as quitté l\'onglet', { icon: 'ui:warning', color: '#ff4d6d' }); showStart(); }
    }
    cv.addEventListener('pointerdown', onPointerDown);
    cv.addEventListener('pointerup', onPointerUp);
    cv.addEventListener('pointercancel', onPointerUp);
    cv.addEventListener('pointerleave', onPointerUp);
    cv.addEventListener('contextmenu', (e) => e.preventDefault());
    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    window.addEventListener('blur', onBlur);
    document.addEventListener('visibilitychange', onVis);

    /* ── update ── */
    function update(dt, T) {
      const rm = !!S().reducedMotion;
      wrap.classList.toggle('cor-rm', rm);
      if (mode === 'play') {
        songT = songNow();
        if (audioMode && synth && synth.ctx.state !== 'running' && performance.now() - waitSince > 1200 && songT < 0) {
          // audio never started (autoplay policy…) → silent performance clock
          const keep = songT; killAudio(); audioMode = false; perfT0 = performance.now() / 1000 - keep;
        }
        if (songT < 0) {
          const b = Math.floor(songT / SPB);
          if (b !== lastCount && b >= -COUNT_IN) { lastCount = b; if (!audioMode) api.sfx('tick', { pitch: b === -1 ? 1.5 : 1 }); if (b === -1) doFlash(0.25, '#fff'); }
        }
        while (first < notes.length && notes[first].j) first++;
        for (let i = first; i < notes.length; i++) {
          const n = notes[i];
          if (n.t > songT) break;
          if (!n.j && songT - n.t > WIN_G) onMiss(n);
        }
        if (first >= notes.length && songT > LAST_T + 1.1) finish();
        hype = Math.max(0, hype - dt * 0.02);
      } else {
        // attract mode: loop the drop silently with an autoplay bot
        const dT = DEMO_A + ((T - demo0) % DEMO_LEN);
        const prev = demoPrev; demoPrev = dT;
        for (const n of CHART) {
          if (n.t < DEMO_A || n.t >= DEMO_A + DEMO_LEN) continue;
          const crossed = dT >= prev ? n.t > prev && n.t <= dT : n.t > prev || n.t <= dT;
          if (crossed) { flashL[n.lane] = 1; press[n.lane] = 1; if (mode === 'start') burst(laneX(n.lane, G.hitY), G.hitY, n.lane, true); }
        }
        songT = dT;
      }
      for (let i = 0; i < 4; i++) {
        press[i] = held[i] ? 1 : Math.max(0, press[i] - dt * 7);
        flashL[i] = Math.max(0, flashL[i] - dt * 4);
        missL[i] = Math.max(0, missL[i] - dt * 3);
      }
      comboPop = Math.max(0, comboPop - dt * 5);
      shake = Math.max(0, shake - dt * 30);
      flash = Math.max(0, flash - dt * 2.5);
      if (judge) { judge.age += dt; if (judge.age > 0.6) judge = null; }
      for (let i = banners.length - 1; i >= 0; i--) { banners[i].age += dt; if (banners[i].age > 1.3) banners.splice(i, 1); }
      for (let i = parts.length - 1; i >= 0; i--) {
        const p = parts[i]; p.age += dt;
        if (p.age >= p.life) { parts.splice(i, 1); continue; }
        p.vy += p.g * dt; p.x += p.vx * dt; p.y += p.vy * dt; p.rot += p.vr * dt;
      }
      for (let i = rings.length - 1; i >= 0; i--) { rings[i].age += dt; if (rings[i].age >= rings[i].life) rings.splice(i, 1); }
      // DOM bits
      titleLs.forEach((s, i) => { s.style.color = hsl(api.hue(i * 28), 100, 64); });
      nbLs.forEach((s, i) => { s.style.color = hsl(api.hue(i * 24), 100, 64); });
      if (res && scoreEl) {
        const k = clamp((T - res.t - 0.2) / 1.1, 0, 1);
        const shown = Math.round(res.score * (1 - Math.pow(1 - k, 3)));
        scoreEl.textContent = fmtInt(shown);
        if (k < 1 && T - res.lastTick > 0.07) { res.lastTick = T; api.sfx('tick', { vol: 0.35, pitch: 0.8 + k }); }
        if (res.rank === 'S' && Math.random() < dt * 6) confetti(4);
      }
    }

    /* ── render ── */
    function drawBg(T, vt, pulse, rm) {
      const h = api.hue(0);
      const hor = H * 0.4;
      let g = ctx.createLinearGradient(0, 0, 0, H);
      if (rgbMode) {
        g.addColorStop(0, hsl(h, 85, 10)); g.addColorStop(0.4, hsl((h + 50) % 360, 95, 32)); g.addColorStop(0.42, hsl((h + 180) % 360, 90, 12)); g.addColorStop(1, hsl((h + 120) % 360, 90, 16));
      } else {
        g.addColorStop(0, '#0b0620'); g.addColorStop(0.3, '#240a45'); g.addColorStop(0.4, '#6a1668'); g.addColorStop(0.405, '#14062b'); g.addColorStop(1, '#0d0421');
      }
      ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      // sun
      const sr = Math.min(W, H) * 0.2 * (1 + (rm ? 0 : pulse * 0.05));
      ctx.save();
      ctx.beginPath(); ctx.rect(0, 0, W, hor); ctx.clip();
      const sg = ctx.createLinearGradient(0, hor - sr, 0, hor + sr * 0.2);
      if (rgbMode) { sg.addColorStop(0, hsl((h + 60) % 360, 100, 65)); sg.addColorStop(1, hsl((h + 300) % 360, 100, 55)); } else { sg.addColorStop(0, '#ffe66b'); sg.addColorStop(0.55, '#ff7a59'); sg.addColorStop(1, '#ff2bd6'); }
      ctx.globalAlpha = 0.85;
      ctx.fillStyle = sg; ctx.beginPath(); ctx.arc(W / 2, hor, sr, Math.PI, 0); ctx.fill();
      ctx.globalAlpha = 1;
      ctx.fillStyle = rgbMode ? hsl(h, 85, 12) : '#2a0b4a';
      for (let i = 0; i < 6; i++) { const yy = hor - sr * 0.08 - i * sr * 0.14; ctx.fillRect(W / 2 - sr, yy, sr * 2, Math.max(1.5, sr * 0.035 * (6 - i) * 0.5)); }
      ctx.restore();
      // floor grid
      ctx.save();
      ctx.beginPath(); ctx.rect(0, hor, W, H - hor); ctx.clip();
      const lines = 12, ph = rm ? 0 : ((vt / SPB) % 1 + 1) % 1;
      ctx.lineWidth = 1.5;
      for (let k = 0; k < lines; k++) {
        const z = (k + ph) / lines;
        const y = hor + (H - hor) * z * z;
        ctx.strokeStyle = rgbMode ? hsl((h + k * 25) % 360, 100, 60, 0.25 + z * 0.5) : `rgba(255,43,214,${0.18 + z * 0.55})`;
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(W, y); ctx.stroke();
      }
      for (let k = -10; k <= 10; k++) {
        ctx.strokeStyle = rgbMode ? hsl((h + k * 18 + 360) % 360, 100, 60, 0.45) : 'rgba(31,244,255,.28)';
        ctx.beginPath(); ctx.moveTo(W / 2 + k * W * 0.03, hor); ctx.lineTo(W / 2 + k * W * 0.24, H); ctx.stroke();
      }
      ctx.restore();
      // hype lasers
      if (hype > 0.6 && mode === 'play' && !rm) {
        ctx.save(); ctx.globalCompositeOperation = 'lighter';
        const a = (hype - 0.6) / 0.4;
        for (let i = 0; i < 4; i++) {
          const ang = Math.sin(T * 1.3 + i * 1.7) * 0.6 - Math.PI / 2;
          const x0 = i < 2 ? 0 : W, y0 = H;
          ctx.strokeStyle = hsl(api.hue(i * 90), 100, 60, 0.18 * a);
          ctx.lineWidth = 10;
          ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x0 + Math.cos(ang + (i < 2 ? 0.5 : -0.5)) * H * 1.5, y0 + Math.sin(ang) * H * 1.5); ctx.stroke();
        }
        ctx.restore();
      }
      if (!rm && pulse > 0 && mode === 'play' && songT >= 0) { ctx.fillStyle = `rgba(255,255,255,${pulse * (rgbMode ? 0.07 : 0.035)})`; ctx.fillRect(0, 0, W, H); }
    }

    function drawHighway(vt, T) {
      const kT = kAt(0), kB = kAt(H);
      const half = G.hw / 2;
      ctx.beginPath();
      ctx.moveTo(G.cx - half * kT, 0); ctx.lineTo(G.cx + half * kT, 0); ctx.lineTo(G.cx + half * kB, H); ctx.lineTo(G.cx - half * kB, H); ctx.closePath();
      const g = ctx.createLinearGradient(0, 0, 0, H);
      g.addColorStop(0, 'rgba(8,3,26,.25)'); g.addColorStop(0.6, 'rgba(10,4,32,.78)'); g.addColorStop(1, 'rgba(8,3,24,.9)');
      ctx.fillStyle = g; ctx.fill();
      // lane beams
      for (let l = 0; l < 4; l++) {
        const a = Math.max(flashL[l] * 0.55, press[l] * 0.3, missL[l] * 0.5);
        if (a <= 0.01) continue;
        const x0t = G.cx + (l * G.lw - half) * kT, x1t = G.cx + ((l + 1) * G.lw - half) * kT;
        const yb = G.hitY, kb = kAt(yb);
        const x0b = G.cx + (l * G.lw - half) * kb, x1b = G.cx + ((l + 1) * G.lw - half) * kb;
        const lg = ctx.createLinearGradient(0, 0, 0, yb);
        const col = missL[l] > flashL[l] ? '#ff4d6d' : colOf(l);
        lg.addColorStop(0, 'rgba(0,0,0,0)'); lg.addColorStop(1, col);
        ctx.globalAlpha = a; ctx.fillStyle = lg;
        ctx.beginPath(); ctx.moveTo(x0t, 0); ctx.lineTo(x1t, 0); ctx.lineTo(x1b, yb); ctx.lineTo(x0b, yb); ctx.closePath(); ctx.fill();
        ctx.globalAlpha = 1;
      }
      // beat lines
      const b0 = Math.floor(vt / SPB), b1 = b0 + Math.ceil(APPROACH / SPB) + 2;
      for (let b = b0; b <= b1; b++) {
        const y = G.hitY - (b * SPB - vt) * G.speed;
        if (y < 0 || y > G.hitY) continue;
        const k = kAt(y);
        ctx.strokeStyle = b % 4 === 0 ? 'rgba(255,255,255,.22)' : 'rgba(255,255,255,.07)';
        ctx.lineWidth = b % 4 === 0 ? 2 : 1;
        ctx.beginPath(); ctx.moveTo(G.cx - half * k, y); ctx.lineTo(G.cx + half * k, y); ctx.stroke();
      }
      // dividers
      ctx.lineWidth = 1.5;
      for (let i = 1; i < 4; i++) {
        ctx.strokeStyle = 'rgba(190,150,255,.18)';
        ctx.beginPath(); ctx.moveTo(G.cx + (i * G.lw - half) * kT, 0); ctx.lineTo(G.cx + (i * G.lw - half) * kB, H); ctx.stroke();
      }
      // RGB rails
      for (const side of [-1, 1]) {
        const x0 = G.cx + side * half * kT, x1 = G.cx + side * half * kB;
        const rg = ctx.createLinearGradient(0, 0, 0, H);
        for (let i = 0; i <= 4; i++) rg.addColorStop(i / 4, hsl(api.hue(i * 60 + (side > 0 ? 180 : 0)), 100, 62));
        ctx.strokeStyle = rg;
        ctx.globalAlpha = 0.3; ctx.lineWidth = 9; ctx.beginPath(); ctx.moveTo(x0, 0); ctx.lineTo(x1, H); ctx.stroke();
        ctx.globalAlpha = 1; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(x0, 0); ctx.lineTo(x1, H); ctx.stroke();
      }
      // hit line
      const kh = kAt(G.hitY);
      const hx0 = G.cx - half * kh, hx1 = G.cx + half * kh;
      ctx.strokeStyle = rainbow(ctx, hx0, hx1, api.hue(0));
      ctx.globalAlpha = 0.35; ctx.lineWidth = 12; ctx.beginPath(); ctx.moveTo(hx0, G.hitY); ctx.lineTo(hx1, G.hitY); ctx.stroke();
      ctx.globalAlpha = 1; ctx.lineWidth = 4; ctx.beginPath(); ctx.moveTo(hx0, G.hitY); ctx.lineTo(hx1, G.hitY); ctx.stroke();
    }

    function drawNoteSet(list, vt, from, offset, demo) {
      // chord bars first
      const yOf = (n) => G.hitY - (n.t + offset - vt) * G.speed;
      for (let i = from; i < list.length - 1; i++) {
        const a = list[i], b = list[i + 1];
        const y = yOf(a);
        if (y < -G.nr * 2) break;
        if (!a.chord || b.step !== a.step) continue;
        if (!demo && (a.j || b.j)) continue;
        if (demo && (a.t + offset <= vt || a.t < DEMO_A || a.t >= DEMO_A + DEMO_LEN)) continue;
        if (y > G.hitY + G.nr) continue;
        const k = kAt(y);
        ctx.strokeStyle = 'rgba(255,255,255,.7)'; ctx.lineWidth = 7 * k; ctx.lineCap = 'round';
        ctx.beginPath(); ctx.moveTo(laneX(a.lane, y), y); ctx.lineTo(laneX(b.lane, y), y); ctx.stroke();
        ctx.strokeStyle = hsl(api.hue(0), 100, 65); ctx.lineWidth = 3 * k;
        ctx.beginPath(); ctx.moveTo(laneX(a.lane, y), y); ctx.lineTo(laneX(b.lane, y), y); ctx.stroke();
      }
      for (let i = from; i < list.length; i++) {
        const n = list[i];
        const y = yOf(n);
        if (y < -G.nr * 2) break;
        let alpha = 1;
        if (demo) { if (n.t + offset <= vt || n.t < DEMO_A || n.t >= DEMO_A + DEMO_LEN) continue; }
        else if (n.j > 0) continue;
        else if (n.j < 0) { alpha = 1 - (vt - n.jt) / 0.35; if (alpha <= 0) continue; }
        if (y > H + G.nr * 2) continue;
        const k = kAt(y), x = laneX(n.lane, y), r = G.nr * k;
        const col = n.j < 0 ? '#ff4d6d' : colOf(n.lane);
        ctx.globalAlpha = alpha;
        const gg = ctx.createRadialGradient(x, y, r * 0.5, x, y, r * 1.7);
        gg.addColorStop(0, col); gg.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.globalCompositeOperation = 'lighter';
        ctx.fillStyle = gg; ctx.globalAlpha = alpha * 0.55;
        ctx.beginPath(); ctx.arc(x, y, r * 1.7, 0, Math.PI * 2); ctx.fill();
        ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = alpha;
        ctx.strokeStyle = INK; ctx.lineWidth = 5 * k;
        ctx.beginPath(); ctx.arc(x, y, r * 1.02, 0, Math.PI * 2); ctx.stroke();
        api.drawCookie(ctx, x, y, r, { rot: vt * 2.2 + n.lane * 1.3 + n.step, simple: true });
        ctx.strokeStyle = col; ctx.lineWidth = 2.5 * k;
        ctx.beginPath(); ctx.arc(x, y, r * 1.1, 0, Math.PI * 2); ctx.stroke();
        ctx.globalAlpha = 1;
      }
    }

    function drawReceptors(T, beatPh) {
      for (let l = 0; l < 4; l++) {
        const x = laneX(l, G.hitY), y = G.hitY, k = kAt(y);
        const col = colOf(l);
        const r = G.nr * k * (1.08 - press[l] * 0.1 + (S().reducedMotion ? 0 : Math.pow(1 - beatPh, 4) * 0.06));
        if (flashL[l] > 0 || press[l] > 0) {
          const a = Math.max(flashL[l], press[l] * 0.6);
          ctx.globalCompositeOperation = 'lighter';
          const gg = ctx.createRadialGradient(x, y, r * 0.3, x, y, r * 2.4);
          gg.addColorStop(0, col); gg.addColorStop(1, 'rgba(0,0,0,0)');
          ctx.globalAlpha = a * 0.7; ctx.fillStyle = gg;
          ctx.beginPath(); ctx.arc(x, y, r * 2.4, 0, Math.PI * 2); ctx.fill();
          ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
        }
        ctx.fillStyle = press[l] > 0.05 ? col : 'rgba(10,4,30,.75)';
        ctx.globalAlpha = press[l] > 0.05 ? 0.35 + press[l] * 0.3 : 1;
        ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
        ctx.globalAlpha = 1;
        ctx.strokeStyle = INK; ctx.lineWidth = 7; ctx.stroke();
        ctx.strokeStyle = col; ctx.lineWidth = 4; ctx.stroke();
        ctx.lineWidth = 1.5; ctx.globalAlpha = 0.6;
        ctx.beginPath(); ctx.arc(x, y, r * 0.62, 0, Math.PI * 2); ctx.stroke();
        ctx.globalAlpha = 1;
        if (!coarse) otext(ctx, KEY_LABEL[l], x, y + 1, Math.round(r * 0.62), '#fff', 'center', 0.22);
      }
    }

    function drawParticles() {
      for (const p of parts) {
        const a = 1 - p.age / p.life;
        ctx.globalAlpha = Math.min(1, a * 1.6);
        ctx.fillStyle = p.col;
        if (p.sh === 1) {
          ctx.strokeStyle = p.col; ctx.lineWidth = p.sz; ctx.lineCap = 'round';
          ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - p.vx * 0.03, p.y - p.vy * 0.03); ctx.stroke();
        } else {
          ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot);
          if (p.sh === 2) ctx.fillRect(-p.sz / 2, -p.sz * 0.3, p.sz, p.sz * 0.6 * Math.abs(Math.cos(p.rot * 2)) + 1);
          else ctx.fillRect(-p.sz / 2, -p.sz / 2, p.sz, p.sz);
          ctx.restore();
        }
      }
      ctx.globalAlpha = 1;
      for (const r of rings) {
        const k = r.age / r.life;
        ctx.globalAlpha = 1 - k; ctx.strokeStyle = r.col; ctx.lineWidth = r.w * (1 - k) + 1;
        ctx.beginPath(); ctx.arc(r.x, r.y, r.r0 * (1 + k * 1.3), 0, Math.PI * 2); ctx.stroke();
      }
      ctx.globalAlpha = 1;
    }

    function drawCombo(T) {
      if (combo < 3 || mode !== 'play') return;
      const y = G.hitY * 0.42;
      const sz = Math.min(W * 0.2, 78) * (1 + comboPop * 0.3) * (1 + Math.min(combo, 200) / 800);
      let dx = 0, dy = 0;
      if (comboPop > 0.2 && canShake() && combo % 25 === 0) { dx = rand(-4, 4); dy = rand(-4, 4); }
      ctx.globalAlpha = 0.9;
      const fill = combo >= 50 ? rainbow(ctx, G.cx - sz, G.cx + sz, api.hue(0)) : '#fff';
      otext(ctx, String(combo), G.cx + dx, y + dy, Math.round(sz), fill, 'center', 0.16);
      otext(ctx, 'COMBO', G.cx, y + sz * 0.62, Math.round(sz * 0.3), combo >= 25 ? '#ffc93c' : '#b3a6dd', 'center', 0.22);
      ctx.globalAlpha = 1;
    }

    function drawJudge() {
      if (!judge) return;
      const a = judge.age;
      const y = G.hitY - Math.min(150, G.hitY * 0.28) - (judge.miss ? -a * 40 : a * 20);
      const pop = a < 0.1 ? 0.5 + easeOutBack(a / 0.1) * 0.7 : 1.2 - Math.min(0.2, (a - 0.1) * 0.8);
      const sz = Math.round(Math.min(W * 0.12, 46) * pop);
      ctx.globalAlpha = a > 0.4 ? Math.max(0, 1 - (a - 0.4) / 0.2) : 1;
      if (judge.miss) otext(ctx, 'MISS', G.cx, y, sz, '#ff4d6d');
      else if (judge.perfect) otext(ctx, 'PERFECT', G.cx, y, sz, rainbow(ctx, G.cx - sz * 2.2, G.cx + sz * 2.2, api.hue(0) + a * 600));
      else {
        otext(ctx, 'GOOD', G.cx, y, sz, '#1ff4ff');
        otext(ctx, judge.early ? 'TÔT' : 'TARD', G.cx, y + sz * 0.72, Math.round(sz * 0.36), '#b3a6dd');
      }
      ctx.globalAlpha = 1;
    }

    function drawBanners() {
      let yy = H * 0.24;
      for (const b of banners) {
        const a = b.age;
        const s = a < 0.15 ? 0.3 + easeOutBack(a / 0.15) * 0.7 : 1;
        const sz = Math.round(Math.min(W * (b.big ? 0.085 : 0.065), b.big ? 40 : 30) * s);
        ctx.globalAlpha = a > 1 ? Math.max(0, 1 - (a - 1) / 0.3) : 1;
        const fill = b.col === 'rgb' ? rainbow(ctx, G.cx - W * 0.35, G.cx + W * 0.35, api.hue(0) + a * 300) : b.col;
        otext(ctx, b.text, G.cx, yy - a * 18, sz, fill);
        if (b.icon) {
          ctx.font = `${sz}px ${FD}`;
          const tw = ctx.measureText(b.text).width;
          artDraw(ctx, b.icon, G.cx - tw / 2 - sz * 0.75, yy - a * 18, sz * 1.15, { rot: Math.sin(a * 12) * 0.15 });
          artDraw(ctx, b.icon, G.cx + tw / 2 + sz * 0.75, yy - a * 18, sz * 1.15, { rot: -Math.sin(a * 12) * 0.15 });
        }
        yy += sz * 1.25;
      }
      ctx.globalAlpha = 1;
    }

    function drawHUD(T, vt, beatPh) {
      // top shade
      const hg = ctx.createLinearGradient(0, 0, 0, 92);
      hg.addColorStop(0, 'rgba(8,3,24,.85)'); hg.addColorStop(1, 'rgba(8,3,24,0)');
      ctx.fillStyle = hg; ctx.fillRect(0, 0, W, 92);
      // progress
      const prog = clamp(vt / SONG_LEN, 0, 1);
      ctx.fillStyle = 'rgba(255,255,255,.1)'; ctx.fillRect(0, 0, W, 4);
      ctx.fillStyle = rainbow(ctx, 0, W, api.hue(0)); ctx.fillRect(0, 0, W * prog, 4);
      const pad = 12;
      ctx.font = `700 11px ${FM}`; ctx.textAlign = 'left'; ctx.textBaseline = 'alphabetic'; ctx.fillStyle = '#b3a6dd';
      ctx.fillText('SCORE', pad, 22);
      otext(ctx, fmtInt(score), pad, 40, 24, '#fff', 'left', 0.2);
      const m = mult(combo);
      ctx.font = `700 11px ${FM}`; ctx.textAlign = 'right'; ctx.fillStyle = '#b3a6dd';
      ctx.fillText('MULTI', W - pad, 22);
      otext(ctx, `×${String(m).replace('.', ',')}`, W - pad, 40, 24, m >= 4 ? rainbow(ctx, W - 80, W, api.hue(0)) : m > 1 ? '#ffc93c' : '#fff', 'right', 0.2);
      // hero cookie dancing on the beat (on wide screens it dances on the side instead)
      if (!sideRoom()) {
        const bounce = S().reducedMotion ? 0 : Math.pow(1 - beatPh, 3);
        const hr = clamp(W * 0.055, 18, 28) * (1 + (rgbMode ? 0.15 : 0));
        api.drawCookie(ctx, W / 2, 34 - bounce * 5, hr, { accessories: true, rot: Math.sin(T * (rgbMode ? 9 : 4)) * (rgbMode ? 0.35 : 0.12), squash: bounce * 0.3 });
      }
      // hype bar
      const bw = Math.min(W - pad * 2, G.hw + 60), bx = (W - bw) / 2, by = 64, bh = 11;
      ctx.fillStyle = 'rgba(0,0,0,.5)'; ctx.strokeStyle = INK; ctx.lineWidth = 3;
      rrect(bx, by, bw, bh, 6); ctx.fill(); ctx.stroke();
      if (hype > 0.002) {
        ctx.save(); rrect(bx, by, bw * hype, bh, 6); ctx.clip();
        ctx.fillStyle = rainbow(ctx, bx, bx + bw, api.hue(0) + T * 90);
        ctx.fillRect(bx, by, bw * hype, bh);
        ctx.fillStyle = 'rgba(255,255,255,.35)'; ctx.fillRect(bx, by, bw * hype, bh * 0.4);
        ctx.restore();
      }
      ctx.font = `700 9px ${FM}`; ctx.textAlign = 'left'; ctx.textBaseline = 'middle'; ctx.fillStyle = '#fff';
      ctx.fillText(hype >= 1 ? 'HYPE MAX' : 'HYPE', bx + 6, by + bh / 2 + 0.5);
    }
    function rrect(x, y, w, h, r) {
      r = Math.min(r, w / 2, h / 2);
      ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r); ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
    }

    function sideRoom() { return (W - G.hw * kAt(G.hitY)) / 2 >= 160; }
    function drawSides(T, vt, beatPh) {
      if (!sideRoom()) return;
      const rm = !!S().reducedMotion;
      const side = (W - G.hw * kAt(G.hitY)) / 2;
      const pulse = rm ? 0 : Math.pow(1 - beatPh, 3);
      const beatN = Math.floor(vt / SPB);
      const hype2 = mode === 'play' ? Math.min(1, combo / 60) : 0.5;
      // left: the player's cookie dancing to the track
      const R = clamp(side * 0.27, 46, 118);
      const x = side * 0.5, y = H * 0.56;
      const lean = rm ? 0 : (beatN % 2 ? 1 : -1) * (0.12 + hype2 * 0.25) * (1 - beatPh * 0.6);
      const gg = ctx.createRadialGradient(x, y, R * 0.4, x, y, R * 2.2);
      gg.addColorStop(0, hsl(api.hue(0), 100, 60, 0.35 + pulse * 0.2)); gg.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = gg; ctx.beginPath(); ctx.arc(x, y, R * 2.2, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = 'rgba(0,0,0,.4)'; ctx.beginPath(); ctx.ellipse(x, y + R * 1.12, R * (0.85 - pulse * 0.15), R * 0.16, 0, 0, Math.PI * 2); ctx.fill();
      api.drawCookie(ctx, x, y - pulse * R * (0.18 + hype2 * 0.2), R, { accessories: true, rot: lean, squash: pulse * 0.3 });
      if (!rm) for (let i = 0; i < 2; i++) {
        const k = (T * 0.7 + i * 0.5) % 1;
        ctx.globalAlpha = Math.sin(k * Math.PI) * 0.9;
        noteGlyph(ctx, x + (i ? 1 : -1) * R * 1.05, y - R * 0.4 - k * R * 1.2, R * 0.34, hsl(api.hue(i * 150), 100, 65), Math.sin(T * 3 + i) * 0.3);
      }
      ctx.globalAlpha = 1;
      // right: RGB equaliser pumping on the beat
      const n = 9, ex0 = W - side * 0.88, ew = side * 0.76, bw = ew / n;
      const baseY = H * 0.74, maxH = H * 0.42;
      for (let i = 0; i < n; i++) {
        const wob = 0.5 + 0.5 * Math.sin(i * 1.9 + vt * 7.3) * Math.cos(i * 0.7 - vt * 3.1);
        const hgt = maxH * (0.12 + (0.35 + hype2 * 0.4) * wob * (0.45 + pulse * 0.55)) * (mode === 'play' ? 1 : 0.6);
        const segs = Math.max(1, Math.floor(hgt / 12));
        for (let j = 0; j < segs; j++) {
          ctx.fillStyle = hsl((api.hue(i * 22) + j * 8) % 360, 100, 60, 0.35 + 0.6 * (j / segs));
          ctx.fillRect(ex0 + i * bw + 2, baseY - (j + 1) * 12 + 2, bw - 4, 9);
        }
      }
    }

    function drawCountdown(vt) {
      if (mode !== 'play' || vt >= 0) return;
      const b = Math.floor(vt / SPB);
      const cy = H * 0.42;
      if (b < -COUNT_IN) { otext(ctx, 'PRÊT ?', G.cx, cy, Math.round(Math.min(W * 0.14, 60)), '#fff'); return; }
      const ph = vt / SPB - b;
      const label = ['3', '2', '1', 'GO !'][b + COUNT_IN];
      const go = b === -1;
      const sz = Math.round(Math.min(W, H) * (go ? 0.2 : 0.28) * (1.35 - 0.35 * Math.min(1, ph * 3)));
      ctx.globalAlpha = 1 - ph * 0.5;
      otext(ctx, label, G.cx, cy, sz, go ? rainbow(ctx, G.cx - sz * 1.3, G.cx + sz * 1.3, api.hue(0)) : ['#ff4d6d', '#ffc93c', '#b6ff3b'][b + COUNT_IN], 'center', 0.14);
      ctx.globalAlpha = 1;
    }

    function drawHero(T) {
      if (!heroCv) return;
      const w = heroCv.clientWidth, h = heroCv.clientHeight;
      if (!w || !h) return;
      const pw = Math.round(w * DPR), ph = Math.round(h * DPR);
      if (heroCv.width !== pw || heroCv.height !== ph) { heroCv.width = pw; heroCv.height = ph; }
      const c = heroCv.getContext('2d');
      c.setTransform(DPR, 0, 0, DPR, 0, 0); c.clearRect(0, 0, w, h);
      const rm = S().reducedMotion;
      const bp = ((T / SPB) % 1);
      const bounce = rm ? 0 : Math.pow(1 - bp, 2.5);
      const R = Math.min(w, h) * 0.34;
      const gg = c.createRadialGradient(w / 2, h / 2, R * 0.4, w / 2, h / 2, R * 1.45);
      gg.addColorStop(0, hsl(api.hue(0), 100, 60, 0.55)); gg.addColorStop(1, 'rgba(0,0,0,0)');
      c.fillStyle = gg; c.fillRect(0, 0, w, h);
      c.fillStyle = 'rgba(0,0,0,.35)'; c.beginPath(); c.ellipse(w / 2, h * 0.9, R * (0.8 - bounce * 0.15), R * 0.14, 0, 0, Math.PI * 2); c.fill();
      api.drawCookie(c, w / 2, h * 0.5 - bounce * R * 0.16, R, { accessories: true, rot: rm ? 0 : Math.sin(T * 2.4) * 0.2, squash: bounce * 0.25 });
      // music notes floating
      if (!rm) {
        for (let i = 0; i < 3; i++) {
          const k = (T * 0.6 + i / 3) % 1;
          c.globalAlpha = Math.sin(k * Math.PI);
          noteGlyph(c, w / 2 + (i - 1) * R * 1.15 + Math.sin(T * 3 + i) * 5, h * 0.62 - k * h * 0.5, R * 0.42, hsl(api.hue(i * 120), 100, 65), Math.sin(T * 4 + i) * 0.25);
        }
        c.globalAlpha = 1;
      }
    }

    function render(T, dt) {
      const rm = !!S().reducedMotion;
      ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
      const vt = songT;
      const beatPh = ((vt / SPB) % 1 + 1) % 1;
      const pulse = Math.pow(1 - beatPh, 3);
      drawBg(T, vt, pulse, rm);
      drawSides(T, vt, beatPh);
      ctx.save();
      if (shake > 0 && canShake()) ctx.translate(rand(-shake, shake), rand(-shake, shake));
      drawHighway(vt, T);
      drawCombo(T);
      if (mode === 'play') {
        let from = first;
        while (from > 0 && notes[from - 1].t > vt - 0.5) from--;
        drawNoteSet(notes, vt, from, 0, false);
      } else {
        drawNoteSet(CHART, vt, 0, 0, true);
        if (vt + APPROACH > DEMO_A + DEMO_LEN) drawNoteSet(CHART, vt, 0, DEMO_LEN, true);
      }
      drawReceptors(T, beatPh);
      if (mode !== 'play') { ctx.fillStyle = 'rgba(11,6,32,.42)'; ctx.fillRect(-20, -20, W + 40, H + 40); }
      drawParticles();
      drawJudge();
      drawBanners();
      ctx.restore();
      if (mode === 'play') { drawHUD(T, vt, beatPh); drawCountdown(vt); }
      if (flash > 0) { ctx.globalAlpha = flash; ctx.fillStyle = flashCol; ctx.fillRect(0, 0, W, H); ctx.globalAlpha = 1; }
      drawHero(T);
    }

    /* ── loop ── */
    let raf = 0, last = performance.now();
    function frame(now) {
      if (!alive) return;
      raf = requestAnimationFrame(frame);
      const dt = Math.min(0.05, Math.max(0, (now - last) / 1000)); last = now;
      const T = performance.now() / 1000;
      update(dt, T);
      render(T, dt);
    }
    showStart();
    raf = requestAnimationFrame(frame);

    return {
      // read-only snapshot for harness bots / debugging
      debug: () => ({ mode, songT, audioMode, notes, score, combo, maxCombo, nP, nG, nM, hype, parts: parts.length }),
      destroy() {
        if (!alive) return;
        alive = false;
        cancelAnimationFrame(raf);
        killAudio();
        ro.disconnect();
        window.removeEventListener('keydown', onKeyDown);
        window.removeEventListener('keyup', onKeyUp);
        window.removeEventListener('blur', onBlur);
        document.removeEventListener('visibilitychange', onVis);
        layer.innerHTML = '';
        wrap.remove();
        parts.length = 0; rings.length = 0; banners.length = 0;
      },
    };
  }
})();
