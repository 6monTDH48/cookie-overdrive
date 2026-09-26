/* COOKIE OVERDRIVE — art.js
 * Vector art library (no emojis anywhere in the game).
 * Every picture is an SVG body drawn in a 48×48 box, chunky dark outline (#1a0b33),
 * gradient fills and a white gloss — Roblox-simulator style.
 *
 *   CO.art.register({ 'ns:name': '<svg body>' | () => '<svg body>' })
 *   CO.art.svg(name)            → full SVG markup
 *   CO.art.url(name)            → data: URL (for <img> / CSS)
 *   CO.art.el(name, cls, alt)   → <img> element (DOM)
 *   CO.art.sprite(name, px)     → cached canvas (px bucketed) or null while decoding
 *   CO.art.draw(ctx, name, cx, cy, size, {alpha, rot}) → true if drawn
 *   CO.art.has(name)
 * Helpers for authors: CO.art.h = { OL, lg, rg, st, shine, blob, star }
 */
(function () {
  'use strict';
  const CO = (window.CO = window.CO || {});
  const OL = '#1a0b33';
  const P = (x) => Math.round(x * 100) / 100;

  /* ───────── authoring helpers ───────── */
  const lg = (id, c1, c2, x2 = 0, y2 = 1) => `<linearGradient id="${id}" x1="0" y1="0" x2="${x2}" y2="${y2}"><stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/></linearGradient>`;
  const rg = (id, c1, c2, cx = 0.35, cy = 0.3, r = 0.8) => `<radialGradient id="${id}" cx="${cx}" cy="${cy}" r="${r}"><stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/></radialGradient>`;
  const st = (w = 3, c = OL) => `stroke="${c}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"`;
  const shine = (d, w = 2.4, o = 0.75) => `<path d="${d}" fill="none" stroke="#fff" stroke-width="${w}" stroke-linecap="round" opacity="${o}"/>`;
  /** bumpy round blob path (cookies, clouds) */
  function blob(cx, cy, r, amp, n, phase = 0) {
    const pts = [];
    for (let i = 0; i < n; i++) { const a = (i / n) * Math.PI * 2 + phase; const rr = r + (i % 2 ? -amp : amp); pts.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]); }
    let d = '';
    for (let i = 0; i < n; i++) {
      const p = pts[i], q = pts[(i + 1) % n];
      const m = [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2];
      if (i === 0) { const l = pts[n - 1]; d += 'M' + P((l[0] + p[0]) / 2) + ' ' + P((l[1] + p[1]) / 2); }
      d += 'Q' + P(p[0]) + ' ' + P(p[1]) + ' ' + P(m[0]) + ' ' + P(m[1]);
    }
    return d + 'Z';
  }
  function star(cx, cy, R, r, pts = 5, rot = -Math.PI / 2) {
    let d = '';
    for (let i = 0; i < pts * 2; i++) { const a = rot + (i * Math.PI) / pts, rr = i % 2 ? r : R; d += (i ? 'L' : 'M') + P(cx + Math.cos(a) * rr) + ' ' + P(cy + Math.sin(a) * rr); }
    return d + 'Z';
  }
  function gear(cx, cy, ro, ri, teeth) {
    const step = (Math.PI * 2) / teeth; let d = '';
    for (let i = 0; i < teeth; i++) {
      const a = i * step - Math.PI / 2;
      [[ri, -0.3], [ro, -0.17], [ro, 0.17], [ri, 0.3]].forEach(([r, k], j) => { d += (i === 0 && j === 0 ? 'M' : 'L') + P(cx + Math.cos(a + k * step) * r) + ' ' + P(cy + Math.sin(a + k * step) * r); });
    }
    return d + 'Z';
  }

  /* ───────── registry / rendering ───────── */
  const defs = {};
  const cacheSvg = {}, cacheUrl = {}, imgs = {}, sprites = {};
  function register(obj) { Object.assign(defs, obj); for (const k of Object.keys(obj)) { delete cacheSvg[k]; delete cacheUrl[k]; delete imgs[k]; delete sprites[k]; } }
  function svg(name) {
    if (cacheSvg[name]) return cacheSvg[name];
    const d = defs[name]; if (!d) return '';
    const body = typeof d === 'function' ? d() : d;
    return (cacheSvg[name] = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="256" height="256">${body}</svg>`);
  }
  function url(name) {
    if (cacheUrl[name]) return cacheUrl[name];
    const s = svg(name); if (!s) return '';
    return (cacheUrl[name] = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(s));
  }
  function img(name) {
    if (imgs[name]) return imgs[name];
    const u = url(name); if (!u) return null;
    const im = new Image(); im.decoding = 'async'; im.src = u; imgs[name] = im;
    return im;
  }
  const BUCKETS = [24, 48, 96, 160, 256, 384];
  function sprite(name, px) {
    const b = BUCKETS.find((x) => x >= px) || 384;
    const key = name + '@' + b;
    if (sprites[key]) return sprites[key];
    const im = img(name);
    if (!im || !im.complete || !im.naturalWidth) return null;
    const c = document.createElement('canvas'); c.width = c.height = b;
    try { c.getContext('2d').drawImage(im, 0, 0, b, b); } catch (e) { return null; }
    return (sprites[key] = c);
  }
  function draw(ctx, name, cx, cy, size, o) {
    const dpr = (ctx.getTransform ? Math.abs(ctx.getTransform().a) : 1) || 1;
    const sp = sprite(name, size * dpr);
    if (!sp) return false;
    const a = o && o.alpha != null ? o.alpha : 1;
    if (a <= 0) return true;
    ctx.save();
    if (a !== 1) ctx.globalAlpha *= a;
    ctx.translate(cx, cy);
    if (o && o.rot) ctx.rotate(o.rot);
    if (o && o.flip) ctx.scale(-1, 1);
    ctx.drawImage(sp, -size / 2, -size / 2, size, size);
    ctx.restore();
    return true;
  }
  function el(name, cls, alt) {
    const i = document.createElement('img');
    i.src = url(name) || url('ui:sparkle');
    i.alt = alt || ''; i.draggable = false; i.className = 'ic' + (cls ? ' ' + cls : '');
    if (!alt) i.setAttribute('aria-hidden', 'true');
    return i;
  }
  function preload(prefixes) { Object.keys(defs).forEach((k) => { if (!prefixes || prefixes.some((p) => k.startsWith(p))) img(k); }); }

  CO.art = { register, svg, url, img, sprite, draw, el, preload, has: (n) => !!defs[n], names: () => Object.keys(defs), h: { OL, lg, rg, st, shine, blob, star, gear, P } };

  /* ═════════════════════════ UI ICONS ═════════════════════════ */
  const COOKIE_EDGE = blob(24, 24, 19.2, 1.3, 18);
  const chips = (c) => `<g fill="${c}" ${st(1.5)}><path d="M14.5 15.5l4-1.8 2.3 3.4-3 3.2-3.6-1.5z"/><path d="M27.5 11.5l3.8.3.7 3.7-3.6 1.7-2.2-2.7z"/><path d="M31 26l4.1.4.6 4.1-3.6 2.1-2.6-3.1z"/><path d="M17.5 30l3.6-.6 1.6 3.6-2.6 2.6-3.6-2.1z"/><path d="M23 21.3l2.7-1.5 2.1 2.1-1.1 3.1h-3.1z"/></g>`;

  register({
    'ui:cookie': () => `<defs>${rg('a', '#ffe0a8', '#b86f2c', 0.35, 0.3, 0.85)}</defs>
      <path d="${COOKIE_EDGE}" fill="url(#a)" ${st(3)}/>${chips('#4a2511')}
      ${shine('M11.5 14c1.8-2.4 4.2-3.9 6.8-4.6')}`,

    'ui:golden': () => `<defs>${rg('a', '#fff6b8', '#e09a00', 0.35, 0.3, 0.85)}</defs>
      <path d="${COOKIE_EDGE}" fill="url(#a)" ${st(3)}/>${chips('#b36b00')}
      ${shine('M11.5 14c1.8-2.4 4.2-3.9 6.8-4.6', 2.6, 0.9)}
      <path d="${star(39, 9, 6.5, 2.2, 4, 0)}" fill="#fff" ${st(1.6)}/><path d="${star(8, 38, 4.5, 1.6, 4, 0)}" fill="#fff" ${st(1.4)}/>`,

    'ui:gem': () => `<defs>${lg('a', '#c4fff8', '#12b8c9')}</defs>
      <path d="M13 8h22l9 11-20 24L4 19z" fill="url(#a)" ${st(3.2)}/>
      <path d="M4 19h40M17 8l-4 11 11 24 11-24-4-11M13 19l11-11 11 11" fill="none" stroke="${OL}" stroke-width="1.7" stroke-linejoin="round" opacity=".45"/>
      ${shine('M9 18l6-7', 2.6, 0.9)}`,

    'ui:star': () => `<defs>${lg('a', '#fff6b0', '#ffae00')}</defs>
      <path d="${star(24, 25.5, 20, 9)}" fill="url(#a)" ${st(3.2)}/>${shine('M17 18.5l4-2', 2.6, 0.9)}`,

    'ui:heart': () => `<defs>${lg('a', '#ff8fb0', '#e0103f')}</defs>
      <path d="M24 42S5 30.5 5 17.5C5 11 9.6 6.5 15 6.5c4 0 7 2.3 9 5.5 2-3.2 5-5.5 9-5.5 5.4 0 10 4.5 10 11C43 30.5 24 42 24 42z" fill="url(#a)" ${st(3.2)}/>
      ${shine('M10.5 15c.6-2.6 2.5-4.3 4.9-4.5', 2.6, 0.9)}`,

    'ui:heart_empty': () => `<path d="M24 42S5 30.5 5 17.5C5 11 9.6 6.5 15 6.5c4 0 7 2.3 9 5.5 2-3.2 5-5.5 9-5.5 5.4 0 10 4.5 10 11C43 30.5 24 42 24 42z" fill="#3a2766" ${st(3.2)}/>`,

    'ui:lock': () => `<defs>${lg('a', '#ffe27a', '#d99400')}${lg('b', '#eee8ff', '#8d7ad0')}</defs>
      <path d="M15 23v-7a9 9 0 0 1 18 0v7" fill="none" stroke="${OL}" stroke-width="9.5"/>
      <path d="M15 23v-7a9 9 0 0 1 18 0v7" fill="none" stroke="url(#b)" stroke-width="4.5"/>
      <rect x="8.5" y="21" width="31" height="23" rx="5.5" fill="url(#a)" ${st(3.2)}/>
      <path d="M24 27.5a3.2 3.2 0 0 1 1.7 5.9l1 4.6h-5.4l1-4.6A3.2 3.2 0 0 1 24 27.5z" fill="${OL}"/>
      ${shine('M13 26v7', 2.4, 0.8)}`,

    'ui:trophy': () => `<defs>${lg('a', '#fff27a', '#e59a00')}</defs>
      <path d="M13 11.5H6.5c0 7.5 3 11.5 9 12M35 11.5h6.5c0 7.5-3 11.5-9 12" fill="none" stroke="${OL}" stroke-width="7.5" stroke-linecap="round"/>
      <path d="M13 11.5H6.5c0 7.5 3 11.5 9 12M35 11.5h6.5c0 7.5-3 11.5-9 12" fill="none" stroke="#ffc400" stroke-width="3.2" stroke-linecap="round"/>
      <path d="M12 6.5h24v9.5c0 8-5.4 13-12 13s-12-5-12-13z" fill="url(#a)" ${st(3.2)}/>
      <path d="M21 29h6v6.5h-6z" fill="url(#a)" ${st(2.6)}/>
      <rect x="13.5" y="35" width="21" height="8" rx="2.5" fill="#b16bff" ${st(3)}/>
      <path d="${star(24, 16, 5, 2.2)}" fill="#fff" opacity=".9"/>${shine('M16 10.5v6', 2.4, 0.8)}`,

    'ui:play': () => `<defs>${lg('a', '#aaff96', '#18b246')}</defs>
      <path d="M14 9c0-2.4 2.6-3.8 4.6-2.6l20.6 13.8c1.8 1.2 1.8 3.8 0 5L18.6 39c-2 1.3-4.6-.1-4.6-2.5z" fill="url(#a)" ${st(3.2)}/>${shine('M18.5 12.5v9', 2.6, 0.85)}`,

    'ui:dice': () => `<defs>${lg('a', '#ffffff', '#cfc4ff')}</defs>
      <rect x="6.5" y="6.5" width="35" height="35" rx="9" fill="url(#a)" ${st(3.2)}/>
      <g fill="${OL}"><circle cx="16" cy="16" r="3.3"/><circle cx="32" cy="16" r="3.3"/><circle cx="24" cy="24" r="3.3"/><circle cx="16" cy="32" r="3.3"/><circle cx="32" cy="32" r="3.3"/></g>`,

    'ui:close': () => `<g stroke="${OL}" stroke-width="12" stroke-linecap="round"><path d="M12 12l24 24M36 12L12 36"/></g><g stroke="#ff4d6d" stroke-width="6" stroke-linecap="round"><path d="M12 12l24 24M36 12L12 36"/></g>`,

    'ui:check': () => `<path d="M9 25l9.5 9.5L39 13" fill="none" stroke="${OL}" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/><path d="M9 25l9.5 9.5L39 13" fill="none" stroke="#3dff7a" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>`,

    'ui:clock': () => `<defs>${lg('a', '#ffffff', '#cfc4ff')}</defs>
      <circle cx="24" cy="25" r="18" fill="url(#a)" ${st(3.2)}/><path d="M24 14v11l7 5" fill="none" ${st(3.6)}/>
      <g fill="${OL}"><circle cx="24" cy="10.5" r="1.6"/><circle cx="24" cy="39.5" r="1.6"/><circle cx="9.5" cy="25" r="1.6"/><circle cx="38.5" cy="25" r="1.6"/></g>`,

    'ui:gift': () => `<defs>${lg('a', '#ff8ae8', '#c5118f')}${lg('b', '#fff27a', '#e59a00')}</defs>
      <path d="M24 14c-3-7-12-8-12-3 0 3.5 6 4 12 3zM24 14c3-7 12-8 12-3 0 3.5-6 4-12 3z" fill="url(#b)" ${st(2.8)}/>
      <rect x="7" y="20" width="34" height="23" rx="3" fill="url(#a)" ${st(3.2)}/>
      <rect x="5" y="14" width="38" height="8" rx="2.5" fill="url(#a)" ${st(3.2)}/>
      <path d="M20 14h8v29h-8z" fill="url(#b)" ${st(2.6)}/>${shine('M10 26v10', 2.2, 0.7)}`,

    'ui:save': () => `<defs>${lg('a', '#8fd0ff', '#2a6bff')}</defs>
      <path d="M8 8h26l6 6v26H8z" fill="url(#a)" ${st(3.2)}/>
      <rect x="14" y="8" width="18" height="11" rx="1.5" fill="#e8f2ff" ${st(2.6)}/><rect x="26" y="10.5" width="3.5" height="6" fill="${OL}"/>
      <rect x="13" y="26" width="22" height="14" rx="2" fill="#fff" ${st(2.6)}/><path d="M17 31h14M17 35h10" stroke="#9aa6c9" stroke-width="2" stroke-linecap="round"/>`,

    'ui:home': () => `<defs>${lg('a', '#ffe9c7', '#e3a864')}${lg('b', '#ff8ae8', '#c5118f')}</defs>
      <path d="M10 22v20h28V22" fill="url(#a)" ${st(3.2)}/>
      <path d="M5 24L24 7l19 17" fill="none" stroke="${OL}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M5 24L24 7l19 17" fill="none" stroke="url(#b)" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/>
      <rect x="20" y="29" width="8" height="13" rx="2" fill="#8a4a1c" ${st(2.4)}/><rect x="30" y="26" width="5" height="5" rx="1" fill="#8ffbff" ${st(2)}/>`,

    'ui:sparkle': () => `<defs>${lg('a', '#ffffff', '#ffd23c')}</defs>
      <path d="M24 3Q27 21 45 24Q27 27 24 45Q21 27 3 24Q21 21 24 3Z" fill="url(#a)" ${st(3)}/>
      <path d="${star(40, 9, 5, 1.6, 4, 0)}" fill="#fff" ${st(1.5)}/>`,

    'ui:fire': () => `<defs>${lg('a', '#ffe14a', '#ff3d00')}</defs>
      <path d="M24 44c-9 0-15-6-15-14 0-7 4.5-11 7-16 1 3 2 5 4.5 6-1-6 2.5-12.5 8-16-.5 5 2 8.5 5.5 12.5 3.5 4 5 7.5 5 12.5C39 38 33 44 24 44z" fill="url(#a)" ${st(3.2)}/>
      <path d="M24 41.5c-4.3 0-7.3-2.8-7.3-6.6 0-3.4 2.4-5.3 3.9-7.8.8 1.9 1.9 2.9 3.4 3.4-.3-2.9 1.3-5.5 3.4-7.3.3 2.9 1.5 4.5 2.9 6.4 1.5 1.9 2 3.5 2 5.4 0 3.9-3.7 6.5-8.3 6.5z" fill="#fff4a8"/>`,

    'ui:bolt': () => `<defs>${lg('a', '#fff58a', '#ffae00')}</defs>
      <path d="M28 3L8 27h13l-5 18 22-27H25z" fill="url(#a)" ${st(3.2)}/>${shine('M25.5 8.5L13.5 23.5', 2.6, 0.75)}`,

    'ui:tornado': () => `<g fill="none" stroke="${OL}" stroke-width="7.5" stroke-linecap="round"><path d="M7 9c10 3 24 3 34 0"/><path d="M10 17c8 2.5 20 2.5 28 0"/><path d="M14 25c6 2 14 2 20 0"/><path d="M18 33c4 1.5 9 1.5 13 0"/><path d="M22 40.5c2 .8 4 .8 6 0"/></g>
      <g fill="none" stroke="#8ffbff" stroke-width="3.4" stroke-linecap="round"><path d="M7 9c10 3 24 3 34 0"/><path d="M10 17c8 2.5 20 2.5 28 0"/><path d="M14 25c6 2 14 2 20 0"/><path d="M18 33c4 1.5 9 1.5 13 0"/><path d="M22 40.5c2 .8 4 .8 6 0"/></g>`,

    'ui:sword': () => `<defs>${lg('a', '#ffffff', '#9fb0ff')}</defs>
      <path d="M37.5 5H43v5.5L24 29.5 18.5 24z" fill="url(#a)" ${st(3)}/>
      <path d="M13 22l13 13" stroke="${OL}" stroke-width="8.5" stroke-linecap="round"/><path d="M13 22l13 13" stroke="#ffc400" stroke-width="4" stroke-linecap="round"/>
      <path d="M17.5 30.5l-8.5 8.5" stroke="${OL}" stroke-width="8" stroke-linecap="round"/><path d="M17.5 30.5l-8.5 8.5" stroke="#b16bff" stroke-width="3.8" stroke-linecap="round"/>
      <circle cx="7.5" cy="40.5" r="3.6" fill="#ffc400" ${st(2.6)}/>${shine('M39 8.5L26 21.5', 1.8, 0.9)}`,

    'ui:crown': () => `<defs>${lg('a', '#fff27a', '#e59a00')}</defs>
      <path d="M6 36L4 14l10 8 10-14 10 14 10-8-2 22z" fill="url(#a)" ${st(3.2)}/>
      <rect x="5.5" y="34" width="37" height="8" rx="2.5" fill="url(#a)" ${st(3)}/>
      <circle cx="24" cy="38" r="2.6" fill="#ff2bd6" ${st(1.6)}/><circle cx="14" cy="38" r="2.1" fill="#1ff4ff" ${st(1.5)}/><circle cx="34" cy="38" r="2.1" fill="#b6ff3b" ${st(1.5)}/>
      <g fill="#fff" ${st(1.6)}><circle cx="4" cy="13" r="2.6"/><circle cx="24" cy="7.5" r="2.8"/><circle cx="44" cy="13" r="2.6"/></g>`,

    'ui:chart': () => `<rect x="6" y="6" width="36" height="36" rx="7" fill="#2a1a5a" ${st(3)}/>
      <rect x="11.5" y="26" width="6" height="11" rx="1.5" fill="#1ff4ff" ${st(2)}/><rect x="21" y="19" width="6" height="18" rx="1.5" fill="#b6ff3b" ${st(2)}/><rect x="30.5" y="11.5" width="6" height="25.5" rx="1.5" fill="#ff2bd6" ${st(2)}/>`,

    'ui:cursor': () => `<defs>${lg('a', '#ffffff', '#d4ccff')}</defs>
      <path d="M11 5l27 20-12 1.5 7 13-5.2 2.6-7-13L12 38z" fill="url(#a)" ${st(3.2)}/>${shine('M14.5 12v15', 2, 0.8)}`,

    'ui:tap': () => `<defs>${lg('a', '#ffffff', '#d4ccff')}</defs>
      <path d="M19 44c-4 0-7-3-7.5-7l-1.5-9c-.4-2.2 2.8-3.4 4-1.2L16 30V9c0-2.4 1.8-4 3.8-4s3.7 1.6 3.7 4v12c.3-2 1.8-3 3.4-3 1.7 0 3 1.2 3.2 3 .5-1.6 1.8-2.4 3.3-2.4 1.8 0 3.1 1.4 3.2 3.2.6-1.1 1.6-1.7 2.8-1.7 1.9 0 3.3 1.6 3.3 3.6V33c0 6-4.5 11-10.5 11z" fill="url(#a)" ${st(3)}/>
      <path d="M23.5 21v6M30.1 21v5M36.6 21.8v4.8" stroke="${OL}" stroke-width="1.8" stroke-linecap="round"/>${shine('M19 9v13', 1.8, 0.8)}`,

    'ui:rainbow': () => `<g fill="none" stroke-linecap="round">
      <path d="M5 37a19 19 0 0 1 38 0" stroke="${OL}" stroke-width="21"/>
      <path d="M5 37a19 19 0 0 1 38 0" stroke="#ff3d6e" stroke-width="4.5"/><path d="M9.5 37a14.5 14.5 0 0 1 29 0" stroke="#ffd23c" stroke-width="4.5"/>
      <path d="M14 37a10 10 0 0 1 20 0" stroke="#3dff7a" stroke-width="4.5"/><path d="M18.5 37a5.5 5.5 0 0 1 11 0" stroke="#2bb8ff" stroke-width="4.5"/></g>`,

    'ui:moon': () => `<defs>${lg('a', '#fffbd0', '#ffc93c')}</defs>
      <path d="M31 5.5A19 19 0 1 0 42.5 35 15.5 15.5 0 0 1 31 5.5z" fill="url(#a)" ${st(3.2)}/>
      <circle cx="18" cy="30" r="2.6" fill="#e0a800" opacity=".6"/><circle cx="14" cy="21" r="1.8" fill="#e0a800" opacity=".6"/>`,

    'ui:warning': () => `<defs>${lg('a', '#fff27a', '#ffae00')}</defs>
      <path d="M24 5L44 41H4z" fill="url(#a)" ${st(3.4)}/><path d="M24 17v11" stroke="${OL}" stroke-width="4.5" stroke-linecap="round"/><circle cx="24" cy="34.5" r="2.7" fill="${OL}"/>`,

    'ui:search': () => `<path d="M29 29l12 12" stroke="${OL}" stroke-width="10" stroke-linecap="round"/><path d="M29 29l12 12" stroke="#b16bff" stroke-width="5" stroke-linecap="round"/>
      <circle cx="20" cy="20" r="13" fill="#bff8ff" fill-opacity=".85" ${st(3.4)}/>${shine('M13.5 16a7.5 7.5 0 0 1 5-5', 2.6, 0.9)}`,

    'ui:skull': () => `<defs>${lg('a', '#ffffff', '#cfc4ff')}</defs>
      <path d="M24 5C14 5 7 12 7 21c0 5.5 2.7 9.5 6 11.5V39c0 2 1.6 3.5 3.5 3.5h15c2 0 3.5-1.6 3.5-3.5v-6.5c3.3-2 6-6 6-11.5C41 12 34 5 24 5z" fill="url(#a)" ${st(3.2)}/>
      <ellipse cx="17" cy="22" rx="4.5" ry="5" fill="${OL}"/><ellipse cx="31" cy="22" rx="4.5" ry="5" fill="${OL}"/><path d="M24 28l-2.5 4h5z" fill="${OL}"/>
      <path d="M19 37v5M24 37v5M29 37v5" stroke="${OL}" stroke-width="2"/>`,

    /* ── tabs ── */
    'tab:shop': () => `<defs>${lg('a', '#c3adff', '#6a3fe0')}${lg('b', '#ff9aea', '#e21fb8')}</defs>
      <circle cx="37" cy="4.5" r="2.6" fill="#fff" opacity=".45"/><circle cx="41" cy="1.8" r="1.6" fill="#fff" opacity=".3"/>
      <rect x="31" y="7" width="7.5" height="15" rx="2" fill="url(#b)" ${st(3)}/>
      <path d="M4 44V22l12-8v8l12-8v8l12-8v30z" fill="url(#a)" ${st(3.2)}/>
      ${shine('M7.5 22.5l6-4', 2.2, 0.6)}
      <rect x="8" y="27" width="7.5" height="6.5" rx="1.6" fill="#8ffbff" ${st(2)}/><rect x="29" y="27" width="7.5" height="6.5" rx="1.6" fill="#8ffbff" ${st(2)}/>
      <rect x="17.5" y="31.5" width="9" height="12.5" rx="2.2" fill="#ffcf4a" ${st(2.4)}/>`,
    'tab:upgrades': () => `<defs>${lg('a', '#fff58a', '#ffae00')}</defs>
      <path d="M28 3L8 27h13l-5 18 22-27H25z" fill="url(#a)" ${st(3.2)}/>${shine('M25.5 8.5L13.5 23.5', 2.6, 0.75)}`,
    'tab:games': () => `<defs>${lg('a', '#ff9aea', '#c5118f')}</defs>
      <path d="M15 13h18c6.5 0 10.5 5 11.5 11.5l1.2 8.5c.8 5.5-5.6 8.6-9.6 4.6L31 32H17l-5.1 5.6c-4 4-10.4.9-9.6-4.6l1.2-8.5C4.5 18 8.5 13 15 13z" fill="url(#a)" ${st(3.2)}/>
      ${shine('M11 17.5c1.8-1.3 3.6-1.8 5.6-1.8', 2.2, 0.6)}
      <path d="M13 20h4v4h4v4h-4v4h-4v-4H9v-4h4z" fill="#fff" ${st(1.8)}/>
      <circle cx="33" cy="21.5" r="3.3" fill="#8ffbff" ${st(1.8)}/><circle cx="38.6" cy="27.2" r="3.3" fill="#c6ff4a" ${st(1.8)}/>`,
    'tab:pets': () => `<defs>${lg('a', '#fff8e8', '#ffab4a')}</defs>
      <path d="M24 3.5C15 3.5 8 17 8 28c0 9.5 7 16.5 16 16.5S40 37.5 40 28C40 17 33 3.5 24 3.5z" fill="url(#a)" ${st(3.2)}/>
      <circle cx="17.5" cy="25" r="3.6" fill="#ff5ec8" ${st(1.7)}/><circle cx="30" cy="33" r="4.6" fill="#39d9ff" ${st(1.7)}/><circle cx="29" cy="17" r="2.7" fill="#b6ff3b" ${st(1.7)}/>
      <ellipse cx="15.5" cy="15.5" rx="2.4" ry="5" transform="rotate(28 15.5 15.5)" fill="#fff" opacity=".85"/>`,
    'tab:style': () => `<defs>${lg('a', '#ffefd6', '#e3a864')}</defs>
      <path d="M24 5C12.5 5 4 13 4 23.5 4 33 10.5 40 18 40c3.2 0 4.5-2 4.5-4.2 0-3 2.2-5.3 5.3-5.3H33c7 0 11-4.6 11-11C44 11.8 35.4 5 24 5z" fill="url(#a)" ${st(3.2)}/>
      <circle cx="13.5" cy="21.5" r="3.7" fill="#ff3d6e" ${st(1.8)}/><circle cx="21" cy="13" r="3.7" fill="#ffd23c" ${st(1.8)}/>
      <circle cx="31" cy="13.2" r="3.7" fill="#2bdcff" ${st(1.8)}/><circle cx="37.3" cy="21" r="3.4" fill="#8bff3b" ${st(1.8)}/><circle cx="15" cy="31" r="3.2" fill="${OL}"/>`,
    'tab:quests': () => `<defs>${lg('a', '#fff6dc', '#efc57a')}${lg('b', '#ff8a6a', '#c2361a')}</defs>
      <rect x="11" y="8" width="26" height="32" rx="3" fill="url(#a)" ${st(3)}/>
      <path d="M16 18h16M16 23h16M16 28h9" stroke="#b58447" stroke-width="2.4" stroke-linecap="round"/>
      <circle cx="31" cy="31.5" r="4.2" fill="#ff2bd6" ${st(1.8)}/>
      <rect x="7" y="4.5" width="34" height="7.5" rx="3.75" fill="url(#b)" ${st(3)}/><rect x="7" y="36" width="34" height="7.5" rx="3.75" fill="url(#b)" ${st(3)}/>
      ${shine('M11 7.2h8', 1.8, 0.6)}`,
    'tab:rebirth': () => `<defs>${lg('a', '#9ffff2', '#1fb8ff')}${lg('s', '#fff6b0', '#ffb000')}</defs>
      <g fill="none" stroke="${OL}" stroke-width="10.5" stroke-linecap="round"><path d="M9.9 18.9A15 15 0 0 1 38.1 18.9"/><path d="M38.1 29.1A15 15 0 0 1 9.9 29.1"/></g>
      <path d="M40.1 24.5L43.2 16.1 32.6 19.9zM7.9 23.5L15.4 28.2 4.8 31.9z" fill="${OL}" stroke="${OL}" stroke-width="5" stroke-linejoin="round"/>
      <g fill="none" stroke="url(#a)" stroke-width="5.2" stroke-linecap="round"><path d="M9.9 18.9A15 15 0 0 1 38.1 18.9"/><path d="M38.1 29.1A15 15 0 0 1 9.9 29.1"/></g>
      <path d="M40.1 24.5L43.2 16.1 32.6 19.9zM7.9 23.5L15.4 28.2 4.8 31.9z" fill="#5fe6ff"/>
      <path d="${star(24, 24.5, 8.5, 3.8)}" fill="url(#s)" ${st(2.2)}/>`,
    'tab:options': () => `<defs>${lg('a', '#efe8ff', '#8d7ad0')}${lg('b', '#ff8ae8', '#b016d4')}</defs>
      <path d="${gear(24, 24, 21, 15.5, 8)}" fill="url(#a)" ${st(3)}/>
      <circle cx="24" cy="24" r="8.5" fill="url(#b)" ${st(3)}/><circle cx="24" cy="24" r="3.2" fill="${OL}"/>
      ${shine('M14 13.5a14 14 0 0 1 6-3.6', 2.2, 0.7)}`,

    'ui:music': () => `<defs>${lg('a', '#ffffff', '#ffb8f2')}</defs>
      <path d="M18 34V11l21-5v24" fill="none" stroke="${OL}" stroke-width="8" stroke-linejoin="round" stroke-linecap="round"/>
      <path d="M18 34V11l21-5v24" fill="none" stroke="url(#a)" stroke-width="3.6" stroke-linejoin="round" stroke-linecap="round"/>
      <path d="M18 16l21-5" stroke="${OL}" stroke-width="3" stroke-linecap="round"/>
      <ellipse cx="12.5" cy="35" rx="7" ry="5.5" transform="rotate(-18 12.5 35)" fill="url(#a)" ${st(3)}/>
      <ellipse cx="33.5" cy="31" rx="7" ry="5.5" transform="rotate(-18 33.5 31)" fill="url(#a)" ${st(3)}/>`,
    'ui:sound': () => `<defs>${lg('a', '#ffffff', '#bfe9ff')}</defs>
      <path d="M5 18h8l11-9v30l-11-9H5z" fill="url(#a)" ${st(3)}/>
      <g fill="none" stroke="${OL}" stroke-width="7" stroke-linecap="round"><path d="M30 17a9 9 0 0 1 0 14"/><path d="M35 11a17 17 0 0 1 0 26"/></g>
      <g fill="none" stroke="#8ffbff" stroke-width="3" stroke-linecap="round"><path d="M30 17a9 9 0 0 1 0 14"/><path d="M35 11a17 17 0 0 1 0 26"/></g>`,
    'ui:mute': () => `<defs>${lg('a', '#ffffff', '#bfe9ff')}</defs>
      <path d="M5 18h8l11-9v30l-11-9H5z" fill="url(#a)" ${st(3)}/>
      <g stroke="${OL}" stroke-width="7.5" stroke-linecap="round"><path d="M30 17l12 14M42 17L30 31"/></g>
      <g stroke="#ff4d6d" stroke-width="3.6" stroke-linecap="round"><path d="M30 17l12 14M42 17L30 31"/></g>`,
  });

  // the cursor building reuses the glove, with an RGB cuff
  register({
    'b:cursor': () => `<defs>${lg('a', '#ffffff', '#d4ccff')}${lg('c', '#ff2bd6', '#1ff4ff', 1, 0)}</defs>
      <path d="M19 42c-4 0-7-3-7.5-7l-1.5-9c-.4-2.2 2.8-3.4 4-1.2L16 28V7c0-2.4 1.8-4 3.8-4s3.7 1.6 3.7 4v12c.3-2 1.8-3 3.4-3 1.7 0 3 1.2 3.2 3 .5-1.6 1.8-2.4 3.3-2.4 1.8 0 3.1 1.4 3.2 3.2.6-1.1 1.6-1.7 2.8-1.7 1.9 0 3.3 1.6 3.3 3.6V31c0 6-4.5 11-10.5 11z" fill="url(#a)" ${st(3)}/>
      <path d="M23.5 19v6M30.1 19v5M36.6 19.8v4.8" stroke="${OL}" stroke-width="1.8" stroke-linecap="round"/>
      <rect x="14" y="38" width="28" height="7.5" rx="3" fill="url(#c)" ${st(2.8)}/>${shine('M19 7v13', 1.8, 0.8)}`,
  });
})();
