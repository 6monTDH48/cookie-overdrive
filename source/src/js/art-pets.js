/* COOKIE OVERDRIVE — art-pets.js
 * Pets (pet:<id>) and upgrade visual-effect icons (vis:<key>).
 * Same contract as art.js: 48×48 bodies, #1a0b33 outline, gradients, white gloss.
 */
(function () {
  'use strict';
  const A = CO.art, { OL, lg, rg, st, shine, blob, star } = A.h;
  const P = A.h.P || ((x) => Math.round(x * 100) / 100);
  const D2R = Math.PI / 180;

  /* ───────── extra helpers ───────── */
  const stops = (list) => list.map((c, i) => Array.isArray(c) ? `<stop offset="${c[0]}" stop-color="${c[1]}"${c[2] != null ? ` stop-opacity="${c[2]}"` : ''}/>` : `<stop offset="${P(i / (list.length - 1))}" stop-color="${c}"/>`).join('');
  /** multi-stop gradient in user space (continuous across several shapes) */
  const lgU = (id, list, x1 = 0, y1 = 0, x2 = 0, y2 = 48) => `<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}">${stops(list)}</linearGradient>`;
  /** multi-stop gradient in bounding-box space */
  const lgM = (id, list, x2 = 0, y2 = 1) => `<linearGradient id="${id}" x1="0" y1="0" x2="${x2}" y2="${y2}">${stops(list)}</linearGradient>`;
  const rgM = (id, list, cx = 0.5, cy = 0.5, r = 0.5) => `<radialGradient id="${id}" cx="${cx}" cy="${cy}" r="${r}">${stops(list)}</radialGradient>`;
  /** several shapes merged under one outline (thick stroke layer, then fill layer) */
  const uni = (shapes, fill, w = 3) => `<g fill="${OL}" stroke="${OL}" stroke-width="${w * 2}" stroke-linejoin="round" stroke-linecap="round">${shapes}</g><g fill="${fill}">${shapes}</g>`;
  /** filled shape whose inner decorations are clipped to it, outline drawn last */
  const body = (id, d, fill, inner = '', w = 3) => `<clipPath id="${id}"><path d="${d}"/></clipPath><path d="${d}" fill="${fill}"/><g clip-path="url(#${id})">${inner}</g><path d="${d}" fill="none" ${st(w)}/>`;
  /** chunky outlined stroke (tails, tentacles, cables) */
  const tube = (d, color, w = 4, ow = 3) => `<path d="${d}" fill="none" stroke="${OL}" stroke-width="${w + ow}" stroke-linecap="round" stroke-linejoin="round"/><path d="${d}" fill="none" stroke="${color}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;
  const spark = (x, y, R, c = '#fff', w = 1.5) => `<path d="${star(x, y, R, R * 0.34, 4, 0)}" fill="${c}" ${st(w)}/>`;
  const pt = (cx, cy, r, deg) => [cx + Math.cos(deg * D2R) * r, cy + Math.sin(deg * D2R) * r];
  const ps = (p) => P(p[0]) + ' ' + P(p[1]);

  /* ── the pet family face kit ── */
  function eye(x, y, r = 3.6, o = {}) {
    const ry = o.ry || r * 1.18;
    let s = `<ellipse cx="${x}" cy="${y}" rx="${r}" ry="${P(ry)}" fill="${o.fill || OL}"/>`;
    if (o.iris) s += `<ellipse cx="${x}" cy="${P(y + ry * 0.45)}" rx="${P(r * 0.66)}" ry="${P(ry * 0.36)}" fill="${o.iris}" opacity=".95"/>`;
    s += `<circle cx="${P(x - r * 0.3)}" cy="${P(y - ry * 0.36)}" r="${P(r * 0.46)}" fill="#fff"/><circle cx="${P(x + r * 0.4)}" cy="${P(y + ry * 0.3)}" r="${P(r * 0.2)}" fill="#fff"/>`;
    return s;
  }
  const eyes = (cx, y, gap, r, o) => eye(cx - gap, y, r, o) + eye(cx + gap, y, r, o);
  const blush = (cx, y, gap, rx = 2.8, c = '#ff5fa2', o = 0.55) => `<g fill="${c}" opacity="${o}"><ellipse cx="${cx - gap}" cy="${y}" rx="${rx}" ry="${P(rx * 0.58)}"/><ellipse cx="${cx + gap}" cy="${y}" rx="${rx}" ry="${P(rx * 0.58)}"/></g>`;
  const wmouth = (x, y, w = 1.5, sw = 1.6) => `<path d="M${P(x - 2 * w)} ${y}Q${P(x - w)} ${P(y + 1.35 * w)} ${x} ${y}Q${P(x + w)} ${P(y + 1.35 * w)} ${P(x + 2 * w)} ${y}" fill="none" ${st(sw)}/>`;
  const smile = (x, y, w = 2.4, sw = 1.7) => `<path d="M${P(x - w)} ${y}Q${x} ${P(y + w * 0.9)} ${P(x + w)} ${y}" fill="none" ${st(sw)}/>`;
  const openMouth = (x, y, w = 2.6, h = 3.4) => `<path d="M${P(x - w)} ${y}Q${x} ${P(y + h * 1.6)} ${P(x + w)} ${y}Z" fill="#7a1f3d" ${st(1.5)}/><path d="M${P(x - w * 0.5)} ${P(y + h * 0.62)}Q${x} ${P(y + h * 0.2)} ${P(x + w * 0.5)} ${P(y + h * 0.62)}Q${x} ${P(y + h * 0.85)} ${P(x - w * 0.5)} ${P(y + h * 0.62)}Z" fill="#ff7a9c"/>`;

  /* ── cookies for the vis icons ── */
  const CHIP = [[-3, -1.5], [1, -3.3], [3.3, 0.1], [0.3, 3.3], [-3.3, 1.8]];
  function chip(x, y, s = 1, rot = 0, fill = '#4a2511', w = 1.5) {
    const c = Math.cos(rot), n = Math.sin(rot);
    return `<path d="${CHIP.map(([a, b], i) => (i ? 'L' : 'M') + P(x + (a * c - b * n) * s) + ' ' + P(y + (a * n + b * c) * s)).join('')}Z" fill="${fill}" ${st(w)}/>`;
  }
  const CK_CHIPS = [[17.5, 17, 1, 0], [29.6, 13.5, 1, 0.8], [33, 29.2, 1.05, 2], [19.8, 32.7, 1, 4], [25.4, 22.9, 0.8, 1]];
  const CK_EDGE = [[12.5, 30.5, 0.8, 1], [35.5, 31, 0.9, 2], [31, 10.5, 0.8, 0.5], [15, 12, 0.75, 3], [24, 38.5, 0.8, 4]];
  function cookie(cx, cy, r, o = {}) {
    const k = r / 19.2, id = o.id || 'ck', pal = o.pal || ['#ffe0a8', '#b86f2c'];
    const cw = o.cw || (k < 0.75 ? 1.2 : 1.5);
    let s = `<defs>${rg(id, pal[0], pal[1], 0.35, 0.3, 0.85)}</defs><path d="${blob(cx, cy, r, 1.3 * k, o.n || 18, o.phase || 0)}" fill="url(#${id})" ${st(o.w || 3)}/>`;
    (o.chips || CK_CHIPS).forEach(([x, y, sc = 1, rot = 0]) => { s += chip(cx + (x - 24) * k, cy + (y - 24) * k, sc * k, rot, o.chip || '#4a2511', cw); });
    if (o.shine !== false) s += shine(`M${P(cx - 12.5 * k)} ${P(cy - 10 * k)}c${P(1.8 * k)} ${P(-2.4 * k)} ${P(4.2 * k)} ${P(-3.9 * k)} ${P(6.8 * k)} ${P(-4.6 * k)}`, P(Math.max(1.4, 2.4 * k)), 0.75);
    return s;
  }
  const MK = rg('mk', '#ffe0a8', '#b86f2c', 0.35, 0.3, 0.85);
  /** tiny cookie (needs MK in defs) */
  function mini(cx, cy, r, w = 2.2) {
    return `<path d="${blob(cx, cy, r, r * 0.07, 14)}" fill="url(#mk)" ${st(w)}/><g fill="#4a2511"><circle cx="${P(cx - r * 0.36)}" cy="${P(cy - r * 0.18)}" r="${P(r * 0.18)}"/><circle cx="${P(cx + r * 0.3)}" cy="${P(cy - r * 0.36)}" r="${P(r * 0.15)}"/><circle cx="${P(cx + r * 0.16)}" cy="${P(cy + r * 0.36)}" r="${P(r * 0.18)}"/></g>`;
  }
  const cookieEdge = (cx, cy, r, n = 18) => blob(cx, cy, r, 1.3 * (r / 19.2), n);

  /* ═════════════════════════ PETS ═════════════════════════ */
  const HAM = 'M24 7.5C35.5 7.5 43.5 16 43.5 27.5 43.5 38 35 44 24 44 13 44 4.5 38 4.5 27.5 4.5 16 12.5 7.5 24 7.5Z';
  const CHICK = 'M24 8C35.5 8 43 16.3 43 26.8 43 36.8 35 43 24 43 13 43 5 36.8 5 26.8 5 16.3 12.5 8 24 8Z';
  const CAT_HEAD = 'M24 9.5C35.5 9.5 43.5 15.5 43.5 24.5 43.5 32.5 35.5 37.5 24 37.5 12.5 37.5 4.5 32.5 4.5 24.5 4.5 15.5 12.5 9.5 24 9.5Z';
  const DOG_HEAD = 'M24 7C35 7 42 14.5 42 24 42 33.5 34.5 39 24 39 13.5 39 6 33.5 6 24 6 14.5 13 7 24 7Z';
  const FOX_HEAD = 'M24 10C34 10 40.5 14.5 42 21.5L45.5 26.5 40.5 27.8C38 34 32 38 24 38 16 38 10 34 7.5 27.8L2.5 26.5 6 21.5C7.5 14.5 14 10 24 10Z';
  const PANDA_HEAD = 'M24 7.5C36 7.5 43.5 15 43.5 24.5 43.5 32.5 36 37.5 24 37.5 12 37.5 4.5 32.5 4.5 24.5 4.5 15 12 7.5 24 7.5Z';
  const OCTO_HEAD = 'M24 4.5C35 4.5 42 12.5 42 22 42 30 35 35.5 24 35.5 13 35.5 6 30 6 22 6 12.5 13 4.5 24 4.5Z';
  const OWL = 'M24 7.5C35 7.5 42 14.5 42 25 42 36 34.5 43.5 24 43.5 13.5 43.5 6 36 6 25 6 14.5 13 7.5 24 7.5Z';
  const UNI_HEAD = 'M24 11C33.5 11 39.5 17.5 39.5 26.5 39.5 35.5 32.5 42.5 24 42.5 15.5 42.5 8.5 35.5 8.5 26.5 8.5 17.5 14.5 11 24 11Z';
  const DRAGON_HEAD = 'M24 8.5C33 8.5 39 14.5 39 22.5 39 30.5 33 35.8 24 35.8 15 35.8 9 30.5 9 22.5 9 14.5 15 8.5 24 8.5Z';
  const WHALE = 'M21 13C31.5 13 38.5 19.5 38.5 28.5 38.5 37.5 31.5 43.5 21 43.5 10.5 43.5 3.5 37.5 3.5 28.5 3.5 19.5 10.5 13 21 13Z';
  const mirror = (d) => d.replace(/(-?\d*\.?\d+)\s+(-?\d*\.?\d+)/g, (m, x, y) => P(48 - parseFloat(x)) + ' ' + y);

  function pinwheel(cx, cy, r, n, c) {
    let s = '';
    for (let i = 0; i < n; i++) {
      const a = (i / n) * 360, b = a + 180 / n;
      s += `<path d="M${cx} ${cy}Q${ps(pt(cx, cy, r * 0.62, a - 28))} ${ps(pt(cx, cy, r, a))}A${r} ${r} 0 0 1 ${ps(pt(cx, cy, r, b))}Q${ps(pt(cx, cy, r * 0.62, b - 28))} ${cx} ${cy}Z" fill="${c}"/>`;
    }
    return s;
  }

  /* pixel alien grid for Glitchy (u = 3) */
  const GLITCHY = [
    '..A........A..',
    '...#......#...',
    '....######....',
    '..##########..',
    '.############.',
    '.##EE####EE##.',
    '###EE####EE###',
    '###EE####EE###',
    '#BB###MM###BB#',
    '##############',
    '.############.',
    '..##..##..##..',
  ];
  function gridPath(rows, x0, y0, u, test) {
    let d = '';
    rows.forEach((row, j) => {
      let i = 0;
      while (i < row.length) {
        if (!test(row[i])) { i++; continue; }
        let k = i; while (k < row.length && test(row[k])) k++;
        d += `M${P(x0 + i * u)} ${P(y0 + j * u)}h${P((k - i) * u)}v${u}h${P(-(k - i) * u)}z`;
        i = k;
      }
    });
    return d;
  }

  A.register({
    /* ── COMMON ── */
    'pet:hamster': () => `<defs>${lgU('b', ['#ffe4b8', '#f7a24c', '#e2771f'], 0, 7, 0, 44)}${lg('p', '#ffc8dc', '#ff7aa8')}</defs>
      <circle cx="10.6" cy="10" r="6.2" fill="url(#b)" ${st(3)}/><circle cx="37.4" cy="10" r="6.2" fill="url(#b)" ${st(3)}/>
      <circle cx="11.2" cy="10.6" r="3.4" fill="url(#p)"/><circle cx="36.8" cy="10.6" r="3.4" fill="url(#p)"/>
      ${body('c', HAM, 'url(#b)', `<path d="M24 7.5c-2.3 0-2.9 3.6-2.1 7.2.4 1.4 3.8 1.4 4.2 0 .8-3.6.2-7.2-2.1-7.2z" fill="#c9611a" opacity=".5"/>
        <g fill="#fff4e2"><ellipse cx="14.5" cy="32.5" rx="8.2" ry="7"/><ellipse cx="33.5" cy="32.5" rx="8.2" ry="7"/><ellipse cx="24" cy="39" rx="11.5" ry="7.5"/></g>`)}
      ${eyes(24, 24.5, 7, 3.6)}${blush(24, 31, 13, 3)}
      <path d="M22.4 31.3h3.2v2.3a.8.8 0 0 1-.8.8h-1.6a.8.8 0 0 1-.8-.8z" fill="#fff" stroke="${OL}" stroke-width="1.2" stroke-linejoin="round"/><path d="M24 31.3v2.9" stroke="${OL}" stroke-width=".9"/>
      ${wmouth(24, 30.8, 1.5)}<path d="M22.3 27.8h3.4l-1.7 1.9z" fill="#ff7aa8" ${st(1.3)}/>
      <g fill="#ffd9c4" ${st(1.6)}><ellipse cx="18.5" cy="40.8" rx="3.1" ry="2.3"/><ellipse cx="29.5" cy="40.8" rx="3.1" ry="2.3"/></g>
      ${shine('M9.5 19c1.6-3.6 4.4-6.2 8-7.4', 2.4, 0.8)}`,

    'pet:frog': () => {
      const sh = `<circle cx="14.5" cy="15" r="8"/><circle cx="33.5" cy="15" r="8"/><path d="M24 16.5C36 16.5 44 22 44 31 44 39.5 35.5 44 24 44 12.5 44 4 39.5 4 31 4 22 12 16.5 24 16.5Z"/>`;
      return `<defs>${lgU('b', ['#c8ff8a', '#62df4a', '#26a83a'], 0, 7, 0, 44)}${lg('y', '#fff8d2', '#ffd98a')}</defs>
      ${uni(sh, 'url(#b)')}
      <ellipse cx="24" cy="37.5" rx="11.5" ry="5.8" fill="url(#y)"/>
      <g fill="#e2a45a" opacity=".55"><circle cx="19" cy="37" r="1.1"/><circle cx="27.5" cy="39.5" r="1.3"/><circle cx="29" cy="35.5" r=".8"/></g>
      <g fill="#1f9434" opacity=".45"><circle cx="24" cy="21" r="1.5"/><circle cx="20.5" cy="19.5" r="1"/><circle cx="27.5" cy="19.5" r="1"/></g>
      ${eye(14.5, 15.2, 4.2)}${eye(33.5, 15.2, 4.2)}
      ${blush(24, 28, 14, 3.1, '#ff86c0', 0.85)}
      <path d="M15.5 27.5Q24 35 32.5 27.5" fill="none" ${st(2.1)}/>
      <g fill="#7ae85a" ${st(1.8)}><ellipse cx="11.5" cy="40" rx="3.6" ry="2.4"/><ellipse cx="36.5" cy="40" rx="3.6" ry="2.4"/></g>
      ${shine('M9.3 12.6a6 6 0 0 1 3.4-4', 2.2, 0.85)}${shine('M6.6 33c-.1-1.6.2-3 .9-4.3', 2.2, 0.7)}`;
    },

    'pet:chick': () => `<defs>${lgU('b', ['#fff9c0', '#ffd83a', '#ffb000'], 0, 3, 0, 44)}${lg('k', '#ffc24a', '#ff7a12')}</defs>
      <g fill="url(#b)" ${st(2.4)}><ellipse cx="18.6" cy="8" rx="2.6" ry="4.8" transform="rotate(-34 18.6 8)"/><ellipse cx="29.4" cy="8" rx="2.6" ry="4.8" transform="rotate(34 29.4 8)"/><ellipse cx="24" cy="6.4" rx="3" ry="5"/></g>
      <ellipse cx="5.4" cy="27.5" rx="4.4" ry="7" transform="rotate(28 5.4 27.5)" fill="#ffc21a" ${st(2.6)}/><ellipse cx="42.6" cy="27.5" rx="4.4" ry="7" transform="rotate(-28 42.6 27.5)" fill="#ffc21a" ${st(2.6)}/>
      <g fill="url(#k)" ${st(1.8)}><ellipse cx="18" cy="43.4" rx="3.6" ry="2.2"/><ellipse cx="30" cy="43.4" rx="3.6" ry="2.2"/></g>
      ${body('c', CHICK, 'url(#b)', `<ellipse cx="24" cy="38" rx="11" ry="7" fill="#fffbe2" opacity=".75"/>`)}
      ${eyes(24, 23.5, 7, 3.5)}${blush(24, 29.5, 12.5, 3)}
      <path d="M20.3 28.2Q24 25.6 27.7 28.2Q24 30.2 20.3 28.2Z" fill="url(#k)" ${st(1.6)}/><path d="M21.7 29.3Q24 33 26.3 29.3Z" fill="#ff8a1f" ${st(1.5)}/>
      ${shine('M10 19.5c1.6-3.4 4.4-5.9 8-7', 2.4, 0.8)}`,

    /* ── RARE ── */
    'pet:cat': () => {
      const earL = 'M7.2 20.5L8.4 4.8Q9 4 9.8 4.5L21.5 11.8Z';
      return `<defs>${lgU('b', ['#fff6e2', '#f7d19c', '#e3a45e'], 0, 4, 0, 46)}${lg('ch', '#8a4a24', '#4a2511')}${lg('p', '#ffc8dc', '#ff7aa8')}${lg('r', '#ff6b8e', '#d8134a')}</defs>
      ${tube('M34 40C43 41 45.5 33 42 27.5', 'url(#b)', 4.4, 3.4)}<path d="M42.9 29.3c-.4-1.3-1-2.5-1.8-3.6" stroke="#6b3517" stroke-width="4.2" stroke-linecap="round"/>
      <ellipse cx="24" cy="39" rx="11.5" ry="5.6" fill="url(#b)" ${st(3)}/>
      <path d="${earL}" fill="url(#b)" ${st(3)}/><path d="${mirror(earL)}" fill="url(#ch)" ${st(3)}/>
      <path d="M10.2 15.5L10.9 8.2 16.8 12.2Z" fill="url(#p)"/><path d="M37.8 15.5L37.1 8.2 31.2 12.2Z" fill="#ff9ac0" opacity=".85"/>
      ${body('c', CAT_HEAD, 'url(#b)', `<path d="M27.5 8.5C33 7.5 41.5 9.5 42.5 16.5 42 21 37 22.5 33.5 20.5 30.5 18.5 27 14.5 27.5 8.5Z" fill="url(#ch)"/>
        <ellipse cx="14" cy="12" rx="3.8" ry="2.4" transform="rotate(-15 14 12)" fill="url(#ch)"/>${shine('M30.5 11.5c2.5-.6 5 0 6.5 1.4', 1.6, 0.45)}`)}
      ${eyes(24, 24.5, 7.5, 3.7, { iris: '#ffc94a' })}${blush(24, 29.5, 13, 2.8)}
      <path d="M22.5 27.3h3l-1.5 1.7z" fill="#ff7aa8" ${st(1.2)}/>${wmouth(24, 29.4, 1.4, 1.5)}
      <g stroke="${OL}" stroke-width="1.4" stroke-linecap="round"><path d="M2.5 25.8l5.2 1M2.8 30l5-.9M45.5 25.8l-5.2 1M45.2 30l-5-.9"/></g>
      <path d="M14 36Q24 40.6 34 36" fill="none" stroke="${OL}" stroke-width="5.2" stroke-linecap="round"/><path d="M14 36Q24 40.6 34 36" fill="none" stroke="url(#r)" stroke-width="2.4" stroke-linecap="round"/>
      <circle cx="24" cy="41.5" r="3.4" fill="#e9a85a" ${st(1.8)}/><g fill="#4a2511"><circle cx="22.8" cy="40.6" r=".75"/><circle cx="25.3" cy="41.2" r=".65"/><circle cx="23.8" cy="42.8" r=".7"/></g>
      <g fill="#ffe7cc" ${st(1.6)}><ellipse cx="18" cy="42.5" rx="3" ry="2"/><ellipse cx="30" cy="42.5" rx="3" ry="2"/></g>
      ${shine('M9.5 18c1.6-2.6 4-4.4 6.8-5.2', 2.4, 0.8)}`;
    },

    'pet:dog': () => {
      const earL = 'M13.5 10.5C6.5 9.5 2.8 15.5 3.5 24.5 4 30 7.5 32 10.2 29.5 12.4 27 14.4 18 13.5 10.5Z';
      return `<defs>${lgU('b', ['#fff0c8', '#f2c177', '#d9964a'], 0, 6, 0, 46)}${lgU('e', ['#d99450', '#9a5222'], 0, 10, 0, 32)}${lg('t', '#8fd6ff', '#2a7bff')}${lg('g', '#fff2a8', '#e0a800')}</defs>
      <ellipse cx="24" cy="40" rx="11" ry="5.3" fill="url(#b)" ${st(3)}/>
      <g fill="#fff4dc" ${st(1.6)}><ellipse cx="18.5" cy="43.3" rx="3.1" ry="2"/><ellipse cx="29.5" cy="43.3" rx="3.1" ry="2"/></g>
      ${body('c', DOG_HEAD, 'url(#b)', `<ellipse cx="24" cy="31.5" rx="9" ry="6.8" fill="#fff8e8"/>`)}
      <path d="${earL}" fill="url(#e)" ${st(3)}/><path d="${mirror(earL)}" fill="url(#e)" ${st(3)}/>
      <g fill="#6e3514" opacity=".75"><circle cx="8.2" cy="17" r=".95"/><circle cx="7.3" cy="21.5" r=".95"/><circle cx="9.8" cy="24.5" r=".95"/><circle cx="39.8" cy="17" r=".95"/><circle cx="40.7" cy="21.5" r=".95"/><circle cx="38.2" cy="24.5" r=".95"/></g>
      <g fill="#b56a2e" opacity=".8"><ellipse cx="17" cy="16.5" rx="2" ry="1.3"/><ellipse cx="31" cy="16.5" rx="2" ry="1.3"/></g>
      ${eyes(24, 22.5, 7, 3.6)}${blush(24, 29.5, 10.2, 2.4)}
      <path d="M22.3 33.2Q22.3 37.6 24 37.6 25.7 37.6 25.7 33.2Z" fill="#ff7a9c" ${st(1.4)}/><path d="M24 34v2.4" stroke="#d8406a" stroke-width=".9" stroke-linecap="round"/>
      <path d="M24 29.6v1.8M20.4 31.8Q22.2 33.8 24 31.4 25.8 33.8 27.6 31.8" fill="none" ${st(1.6)}/>
      <path d="M21 27.4Q24 25.8 27 27.4 26.6 30 24 30.4 21.4 30 21 27.4Z" fill="${OL}"/><ellipse cx="23" cy="27.2" rx="1.1" ry=".6" fill="#fff" opacity=".85"/>
      <path d="M14.5 37.2Q24 41.6 33.5 37.2" fill="none" stroke="${OL}" stroke-width="5.2" stroke-linecap="round"/><path d="M14.5 37.2Q24 41.6 33.5 37.2" fill="none" stroke="url(#t)" stroke-width="2.4" stroke-linecap="round"/>
      ${uni('<circle cx="20.3" cy="40.6" r="1.6"/><circle cx="20.3" cy="43.2" r="1.6"/><circle cx="27.7" cy="40.6" r="1.6"/><circle cx="27.7" cy="43.2" r="1.6"/><rect x="20.3" y="40.4" width="7.4" height="3"/>', 'url(#g)', 1.3)}
      ${shine('M15.6 11.6c1.6-1.4 3.6-2.3 5.8-2.6', 2.2, 0.8)}${shine('M5.8 14.8c.8-1.4 2-2.4 3.4-2.9', 1.8, 0.6)}`;
    },

    'pet:fox': () => {
      const earL = 'M6.5 20L6.8 3.8Q7.1 3 7.9 3.4L20.5 11.5Z';
      return `<defs>${lgU('b', ['#ffd18a', '#f5963a', '#e0661a'], 0, 4, 0, 44)}${lgU('t', ['#ffd18a', '#e0661a'], 32, 18, 46, 42)}${lg('cr', '#e89a3e', '#a4500e')}</defs>
      <path d="M33 40.5C43 43 47 34 44.8 25.5 43.5 20 39.5 18.2 37.5 20.5 39.5 27 37.5 33.5 32 36.5Z" fill="url(#t)" ${st(3)}/>
      <path d="M44.2 22.8C43 20 40.5 19 38.8 19.8 39.6 21.3 40.1 22.8 40.4 24.4 41.8 23.4 43 23 44.2 22.8Z" fill="#fff8ea"/>
      <ellipse cx="24" cy="40.5" rx="9.5" ry="5" fill="url(#b)" ${st(3)}/><ellipse cx="24" cy="40.8" rx="5" ry="3.4" fill="#fff8ea"/>
      <g fill="#fff4e0" ${st(1.6)}><ellipse cx="19" cy="43.6" rx="2.8" ry="1.9"/><ellipse cx="29" cy="43.6" rx="2.8" ry="1.9"/></g>
      <path d="${earL}" fill="url(#b)" ${st(3)}/><path d="${mirror(earL)}" fill="url(#b)" ${st(3)}/>
      <path d="M9 15L9.3 7.6 15.3 11.4Z" fill="#fff8ea"/><path d="M39 15L38.7 7.6 32.7 11.4Z" fill="#fff8ea"/>
      ${body('c', FOX_HEAD, 'url(#b)', `<path d="M3 26C9 24.5 16 25.5 20.5 29.2L24 31.2 27.5 29.2C32 25.5 39 24.5 45 26 43 35 35 39 24 39 13 39 5 35 3 26Z" fill="#fff8ea"/>
        <path d="M8 9H40V14.6C38.6 14.6 38 15.4 38 17 38 19.2 34.8 19.2 34.8 17V16C33.2 15.4 31.4 15.8 30.4 16.6 29.2 17.6 29.4 21.6 26.8 21.6 24.2 21.6 24.6 17.4 23.2 16.6 21.6 15.8 19.4 15.8 18.2 16.8 17.2 17.8 17.3 19.6 15.6 19.6 13.8 19.6 14 16.4 12.8 15.6 11.4 14.8 9.6 15.2 8 15Z" fill="url(#cr)" ${st(1.8)}/>
        ${shine('M20 12.6c2.6-.9 5.4-.9 8 0', 1.6, 0.6)}`)}
      ${eyes(24, 25.2, 7.5, 3.5, { iris: '#ff9a3c' })}${blush(24, 30.5, 13, 2.7)}
      <ellipse cx="24" cy="30.6" rx="2.1" ry="1.45" fill="${OL}"/><ellipse cx="23.4" cy="30.2" rx=".7" ry=".4" fill="#fff" opacity=".85"/>
      ${wmouth(24, 32.4, 1.3, 1.5)}
      ${shine('M9 12.4c.2-1.8.5-3.4 1-4.6', 1.8, 0.7)}`;
    },

    /* ── EPIC ── */
    'pet:panda': () => {
      const patchL = 'M20 15.6C18.8 19.2 22.4 22.2 21.4 26.6 20.6 30.2 17.4 31.4 14.6 30.8 11.2 30 10.2 26.4 11.4 23.2 12.8 19.6 17.6 19 20 15.6Z';
      return `<defs>${lgU('w', ['#ffffff', '#f1ecff', '#cfc4f0'], 0, 6, 0, 46)}${lg('ch', '#8a4a24', '#3a1a08')}${lg('m', '#b388ff', '#6a3fe0')}</defs>
      <circle cx="11" cy="11" r="5.6" fill="url(#ch)" ${st(3)}/><circle cx="37" cy="11" r="5.6" fill="url(#ch)" ${st(3)}/>
      <ellipse cx="24" cy="39.5" rx="12" ry="5.8" fill="url(#w)" ${st(3)}/>
      ${body('c', PANDA_HEAD, 'url(#w)', '')}
      <path d="${patchL}" fill="url(#ch)"/><path d="${mirror(patchL)}" fill="url(#ch)"/>
      ${eyes(24, 24.8, 7.9, 3.1, { iris: '#b388ff' })}${blush(24, 31, 13.5, 2.6)}
      <path d="M22.2 28.6Q24 27.6 25.8 28.6 25.4 30.3 24 30.5 22.6 30.3 22.2 28.6Z" fill="${OL}"/>${wmouth(24, 31, 1.3, 1.5)}
      ${cookie(24, 39.8, 6.2, { id: 'k', chips: [[17.5, 17, 1.2, 0], [30, 14, 1.2, 0.8], [31, 30, 1.3, 2], [18.5, 31, 1.2, 4]], cw: 1, shine: false, w: 2.4 })}
      <g fill="url(#ch)" ${st(2.2)}><ellipse cx="16.2" cy="39" rx="3.4" ry="4" transform="rotate(20 16.2 39)"/><ellipse cx="31.8" cy="39" rx="3.4" ry="4" transform="rotate(-20 31.8 39)"/></g>
      ${shine('M9.5 17.5c1.8-3.6 4.8-6.4 8.6-7.6', 2.4, 0.9)}
      ${spark(42.5, 22, 3.4, '#e9d4ff', 1.3)}${spark(5, 36, 2.8, '#e9d4ff', 1.2)}`;
    },

    'pet:octopus': () => {
      const arms = ['M13 29.5C8 30.5 4.8 34 5.2 38.2 5.6 41.4 9.4 41.8 10 39.2', 'M17.5 33C16 36.5 15.6 39.2 17.2 41.8', 'M24 34C24.4 37 23.4 39.4 24.6 41.8', 'M30.5 33C32 36.5 32.4 39.2 30.8 41.8', 'M35 29.5C40 30.5 43.2 34 42.8 38.2 42.4 41.4 38.6 41.8 38 39.2'];
      const icing = 'M3 3H45V14.8C43.2 14.8 42.5 15.8 42.5 17.6 42.5 20.2 39.3 20.2 39.3 17.6V16.4C37.5 15.7 34.8 16.2 33.3 16.9 31.8 17.6 32 22.4 29.2 22.4 26.5 22.4 26.9 17.6 25.6 17 23.6 16.2 21.2 16.6 19.6 17.4 18.2 18.1 18.5 20.8 16.3 20.8 14.2 20.8 14.6 17.6 13.2 16.8 11.2 15.8 8.2 16.2 3 16.3Z';
      return `<defs>${lgU('b', ['#d8fbff', '#6fd4ff', '#2a8ee8'], 0, 4, 0, 44)}${lg('i', '#ffffff', '#ffd2f0')}</defs>
      <g fill="none" stroke="${OL}" stroke-width="8.4" stroke-linecap="round" stroke-linejoin="round">${arms.map((d) => `<path d="${d}"/>`).join('')}</g>
      <g fill="none" stroke="url(#b)" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">${arms.map((d) => `<path d="${d}"/>`).join('')}</g>
      <g fill="#e8fcff" opacity=".85"><circle cx="6.6" cy="37" r=".8"/><circle cx="16.6" cy="38.6" r=".8"/><circle cx="23.9" cy="39" r=".8"/><circle cx="31.4" cy="38.6" r=".8"/><circle cx="41.4" cy="37" r=".8"/></g>
      ${body('c', OCTO_HEAD, 'url(#b)', `<path d="${icing}" fill="url(#i)" ${st(1.8)}/>
        <g stroke-width="1.7" stroke-linecap="round"><path d="M12 9.5l2.2-1" stroke="#ff4fb8"/><path d="M19 7l1.4 1.8" stroke="#ffd23c"/><path d="M26 9.5l2.3-.6" stroke="#3dd6ff"/><path d="M33 7.2l1.6 1.6" stroke="#6cff5a"/><path d="M37.5 12l2.2-.8" stroke="#b16bff"/><path d="M16 13.2l1.9.9" stroke="#3dd6ff"/><path d="M23 12.4l-.6 2" stroke="#ff4fb8"/><path d="M30 13l2 .4" stroke="#ffd23c"/><path d="M9 13.6l1.4-1.4" stroke="#6cff5a"/></g>
        ${shine('M10.5 9.2c1.6-1.6 3.6-2.6 5.8-3', 1.8, 0.9)}`)}
      ${eyes(24, 26.2, 7, 3.6, { iris: '#5fe6ff' })}${blush(24, 30.8, 12.5, 2.7)}${openMouth(24, 29.6, 2, 2.4)}
      ${spark(43, 5, 3.4, '#dff9ff', 1.3)}${spark(4.5, 24.5, 2.6, '#dff9ff', 1.2)}`;
    },

    'pet:owl': () => {
      const tuftL = 'M9 17L6.3 3.4Q6.4 2.6 7.2 2.9L18.6 10Z';
      const wingL = 'M7 23.5C3.6 29 4.6 36.5 10.5 40.5 13.5 35.5 13 28 7 23.5Z';
      return `<defs>${lgU('b', ['#ffc6f2', '#f07ae0', '#b64ae0'], 0, 3, 0, 44)}${lg('w', '#d36cf0', '#7a2cc9')}${lg('g', '#fff2a0', '#ffae00')}</defs>
      <path d="${tuftL}" fill="url(#b)" ${st(3)}/><path d="${mirror(tuftL)}" fill="url(#b)" ${st(3)}/>
      <path d="M9.3 11.5L8.4 6.6 13 9.4Z" fill="#fff" opacity=".55"/><path d="M38.7 11.5L39.6 6.6 35 9.4Z" fill="#fff" opacity=".55"/>
      <g fill="url(#g)" ${st(1.6)}><path d="M17.2 42.5l-1 2.6h2l.3-1.3.3 1.3h2l-1-2.6z"/><path d="M27.2 42.5l-1 2.6h2l.3-1.3.3 1.3h2l-1-2.6z"/></g>
      ${body('c', OWL, 'url(#b)', `<circle cx="24" cy="36.5" r="7.4" fill="#fff"/>${pinwheel(24, 36.5, 7.4, 5, '#ff4fa8')}<circle cx="24" cy="36.5" r="7.4" fill="none" stroke="${OL}" stroke-width="1.6"/>
        <path d="${wingL}" fill="url(#w)" ${st(2.2)}/><path d="${mirror(wingL)}" fill="url(#w)" ${st(2.2)}/>
        <g stroke="#ffd6fb" stroke-width="1.5" stroke-linecap="round" opacity=".85"><path d="M6.8 29l3.4 1.6M7.4 33.5l3.8 1.4M40.2 30.6l-3.4-1.6M40.6 35l-3.8-1.4"/></g>`)}
      <g fill="#fff1fb" ${st(2.2)}><circle cx="16.5" cy="20.5" r="7.2"/><circle cx="31.5" cy="20.5" r="7.2"/></g>
      ${eyes(24, 20.8, 7.5, 4.1, { iris: '#ff4fd8' })}
      <path d="M21.8 25.6h4.4L24 29.6z" fill="url(#g)" ${st(1.6)}/>
      ${blush(24, 28.5, 12.8, 2.4)}
      ${shine('M20.4 11.4c1.2-.7 2.5-1.1 3.8-1.2', 1.8, 0.8)}
      ${spark(43.5, 18, 3.2, '#ffe0fb', 1.3)}${spark(4.5, 41.5, 2.6, '#ffe0fb', 1.2)}`;
    },

    /* ── LEGENDARY ── */
    'pet:unicorn': () => {
      const earL = 'M13 19L11.4 6.6Q11.7 5.8 12.5 6.1L21 12.8Z';
      const mane = 'M21 12.2C12.4 12 6.8 19 7 28 7.2 34.4 9.6 39.2 13.6 42.2';
      const lock = (x, y, rot, s, c) => `<path d="M-4 -1C-4 -5 2 -6.5 4 -2.5 5.5 .5 4.5 4 3 6.5 1.5 2.5-1 1.5-4-1Z" transform="translate(${x} ${y}) rotate(${rot}) scale(${s})" fill="${c}" stroke="${OL}" stroke-width="${P(2.4 / s)}" stroke-linejoin="round"/>`;
      return `<defs>${lgU('b', ['#ffffff', '#f6eeff', '#dccaff'], 0, 10, 0, 44)}${lgM('h', ['#fffbd0', '#ffd23c', '#e59a00'], 1, 1)}${rgM('gl', [[0, '#fff3a0', 0.9], [1, '#ffd23c', 0]])}</defs>
      <circle cx="24" cy="7.5" r="9" fill="url(#gl)"/>
      <path d="${mane}" fill="none" stroke="${OL}" stroke-width="11.4" stroke-linecap="round"/>
      <path d="${mane}" fill="none" stroke="#ff5f9e" stroke-width="7.8" stroke-linecap="round"/>
      <path d="${mane}" fill="none" stroke="#ffd23c" stroke-width="4.8" stroke-linecap="round"/>
      <path d="${mane}" fill="none" stroke="#3dd6ff" stroke-width="1.8" stroke-linecap="round"/>
      <path d="${earL}" fill="url(#b)" ${st(3)}/><path d="${mirror(earL)}" fill="url(#b)" ${st(3)}/>
      <path d="M14.2 15.4L13.4 9.4 17.8 12.6Z" fill="#ffb3dc"/><path d="M33.8 15.4L34.6 9.4 30.2 12.6Z" fill="#ffb3dc"/>
      ${body('c', UNI_HEAD, 'url(#b)', `<ellipse cx="24" cy="40" rx="9.5" ry="5.2" fill="#ffe2f3"/>`)}
      ${lock(30.8, 16.2, 34, 1.05, '#b16bff')}${lock(16.6, 16.6, 10, 1.1, '#3dd6ff')}${lock(21.4, 15.4, 20, 1.2, '#ff5f9e')}${lock(26.4, 14.8, 30, 1.15, '#ffd23c')}
      <path d="M24 0.8L28.4 12.8Q24 14.6 19.6 12.8Z" fill="url(#h)" ${st(2.6)}/>
      <path d="M21.4 9.6Q24 10.8 27 9.2M22.7 6Q24.2 6.9 25.6 5.8" fill="none" stroke="#c07800" stroke-width="1.3" stroke-linecap="round"/>
      ${shine('M22.4 5l-1 4', 1.2, 0.9)}
      ${eyes(24, 28, 6.6, 3.5, { iris: '#ff5fd6' })}
      <path d="M14.2 25.8l-2.2-1.1M14.6 23.8l-1.4-1.7M33.8 25.8l2.2-1.1M33.4 23.8l1.4-1.7" stroke="${OL}" stroke-width="1.4" stroke-linecap="round"/>
      ${blush(24, 33.4, 10.8, 2.5)}${smile(24, 36.6, 2, 1.5)}
      ${spark(41.5, 7, 3.8, '#ffe066', 1.4)}${spark(44, 30, 2.6, '#ffe066', 1.2)}${spark(40.5, 41, 2.2, '#fff', 1.1)}`;
    },

    'pet:dragon': () => {
      const wingL = 'M16 25C13 16.6 8.6 10 2.4 7.2 2.8 11.6 2.2 15 1.6 17.6 4 17.2 5.6 18.4 5.4 21 7.4 20.4 9.2 21.6 9.4 24 11.4 23.6 13.2 24.8 13.6 27.2Z';
      const hornL = 'M15.6 12.4C14.2 8.6 11.8 5.6 8.2 3.4 13.2 2 18.2 4.2 21.2 8.8Z';
      const flame = 'M42.6 24.6C45.2 27 46.4 29.6 46 32 45.6 34.4 44 35.8 42.3 35.8 40.5 35.8 38.9 34.4 38.7 32.3 38.5 30.4 39.5 29 40.3 27.8 40.7 29.1 41.2 29.7 41.7 29.4 41.4 27.8 41.4 26.2 42.6 24.6Z';
      return `<defs>${lgU('b', ['#ffc27a', '#ff7a2a', '#c8340a'], 0, 6, 0, 46)}${lgU('w', ['#ffe89a', '#ffa04a', '#e0561a'], 0, 12, 0, 32)}${lgM('g', ['#fffbd0', '#ffd23c', '#e59a00'])}${lgM('f', ['#fff6b0', '#ffc21a', '#ff4a00'])}${lg('s', '#fff3c4', '#ffc94a')}</defs>
      <path d="${wingL}" fill="url(#w)" ${st(2.6)}/><path d="${mirror(wingL)}" fill="url(#w)" ${st(2.6)}/>
      <path d="M3.4 8.8L5 20.4M3.8 9L9 23.4M44.6 8.8L43 20.4M44.2 9L39 23.4" stroke="#e0661f" stroke-width="1.1" stroke-linecap="round" opacity=".8"/>
      <path d="${hornL}" fill="url(#g)" ${st(2.4)}/><path d="${mirror(hornL)}" fill="url(#g)" ${st(2.4)}/>
      <path d="M18.6 9.6L19.8 4.8 22.8 8.4ZM21.8 8.2L24 2.6 26.2 8.2ZM25.2 8.4L28.2 4.8 29.4 9.6Z" fill="url(#g)" ${st(2)}/>
      ${tube('M31 42.4C36 43.8 41.4 43.4 42.3 41.4', 'url(#b)', 4.4, 3.4)}
      <ellipse cx="24" cy="39.6" rx="10.4" ry="5.8" fill="url(#b)" ${st(3)}/>
      <ellipse cx="24" cy="39.4" rx="5.6" ry="4" fill="url(#s)"/><path d="M20.2 38h7.6M20.6 40.8h6.8" stroke="#e8a23c" stroke-width="1.2" stroke-linecap="round"/>
      <g fill="#ffe0b0" ${st(1.6)}><ellipse cx="18" cy="44" rx="3" ry="2"/><ellipse cx="30" cy="44" rx="3" ry="2"/></g>
      ${body('c', DRAGON_HEAD, 'url(#b)', `<ellipse cx="24" cy="36" rx="10" ry="5" fill="#ffd08a" opacity=".55"/>
        <g fill="none" stroke="#e0561a" stroke-width="1.2" stroke-linecap="round" opacity=".6"><path d="M10.4 24.6q1.3.9 2.6 0M11.4 27.6q1.3.9 2.6 0M35 24.6q1.3.9 2.6 0M34 27.6q1.3.9 2.6 0"/></g>`)}
      <g fill="#8a2a08"><ellipse cx="22.3" cy="26.6" rx=".9" ry=".65"/><ellipse cx="25.7" cy="26.6" rx=".9" ry=".65"/></g>
      <path d="M20 30Q24 33.4 28 30" fill="none" ${st(1.7)}/>
      <g fill="#fff" stroke="${OL}" stroke-width="1" stroke-linejoin="round"><path d="M20.9 30.8l1.8.6-1.1 1.6z"/><path d="M27.1 30.8l-1.8.6 1.1 1.6z"/></g>
      ${eyes(24, 20.6, 6.6, 3.4, { iris: '#ffd23c' })}
      ${blush(24, 26.2, 11, 2.3)}
      <g transform="translate(0 6.2)"><path d="${flame}" fill="url(#f)" ${st(2.2)}/>
      <path d="M42.3 29.8C43.5 30.9 44.1 32 43.9 33.1 43.7 34.2 43 34.8 42.3 34.8 41.4 34.8 40.7 34.1 40.7 33.1 40.7 32.2 41.2 31.5 41.6 31.1 41.8 31.7 42.1 31.9 42.3 31.7Z" fill="#fff6c0"/></g>
      <g fill="#d9964a" ${st(1)}><path d="M44.4 27.6l1.8-.4.6 1.6-1.4 1-1.2-.8z"/><path d="M37.4 29.4l1.6.2.2 1.5-1.5.6-.8-1.1z"/></g>
      ${shine('M13.4 15.4c1.2-1.8 2.8-3.2 4.8-4.2', 2.2, 0.8)}
      ${spark(5, 38, 2.6, '#ffe066', 1.2)}${spark(35.5, 2.8, 2.2, '#ffe066', 1.1)}`;
    },

    'pet:robot': () => `<defs>${lgU('m', ['#ffffff', '#e2dcff', '#9d8fd6'], 0, 14, 0, 46)}${lg('s', '#2d1a5c', '#140a2e')}${lg('g', '#fff2a0', '#e59a00')}${lg('h', '#ffffff', '#e4dcff')}${rg('o', '#fff8c0', '#ff3d6e', 0.4, 0.35, 0.7)}</defs>
      ${tube('M40 21.5Q43.5 18 43 12.5', '#b8acf0', 1.8, 2.8)}<circle cx="43" cy="10.4" r="2.8" fill="url(#o)" ${st(2)}/>
      <g fill="url(#m)" ${st(2.6)}><rect x="6" y="33" width="5.5" height="8.5" rx="2.75" transform="rotate(14 8.75 37.25)"/><rect x="36.5" y="33" width="5.5" height="8.5" rx="2.75" transform="rotate(-14 39.25 37.25)"/></g>
      <g fill="url(#g)" ${st(2)}><circle cx="8.2" cy="42.2" r="2.5"/><circle cx="39.8" cy="42.2" r="2.5"/></g>
      <rect x="12" y="31" width="24" height="14.5" rx="5" fill="url(#m)" ${st(3)}/>
      <circle cx="24" cy="38.4" r="5.6" fill="url(#g)" ${st(2)}/>${cookie(24, 38.4, 4, { id: 'k', chips: [[17.5, 17, 1.4, 0], [30, 15, 1.4, 1], [29, 31, 1.4, 2], [17.5, 30.5, 1.3, 4]], cw: 0.9, w: 1.6, shine: false })}
      <g fill="url(#g)" ${st(2.2)}><rect x="4.6" y="20.5" width="5" height="10" rx="2.2"/><rect x="38.4" y="20.5" width="5" height="10" rx="2.2"/></g>
      <rect x="8" y="14.5" width="32" height="20" rx="7" fill="url(#m)" ${st(3)}/>
      <rect x="11.8" y="17.6" width="24.4" height="13.8" rx="4.4" fill="url(#s)" ${st(2)}/>
      <path d="M14.5 21.5l3-3" stroke="#fff" stroke-width="1.4" stroke-linecap="round" opacity=".3"/>
      <g fill="#5ff8ff"><ellipse cx="19" cy="23.8" rx="2.5" ry="3.1"/><ellipse cx="29" cy="23.8" rx="2.5" ry="3.1"/></g>
      <g fill="#fff"><circle cx="18.2" cy="22.7" r="1"/><circle cx="28.2" cy="22.7" r="1"/></g>
      <path d="M21.6 27.8Q24 29.8 26.4 27.8" fill="none" stroke="#5ff8ff" stroke-width="1.6" stroke-linecap="round"/>
      <g fill="#ff6fb8" opacity=".75"><rect x="13.8" y="26.8" width="3" height="1.6" rx=".8"/><rect x="31.2" y="26.8" width="3" height="1.6" rx=".8"/></g>
      <path d="M13.8 15.6C9 15.8 8.2 9 13.2 8.4 13.6 4 19.8 2.4 22.8 5.4 25.4 2.4 31.6 3.4 32.6 7.6 38.2 7 39 15.6 34.2 15.6Z" fill="url(#h)" ${st(2.6)}/>
      <rect x="13.2" y="12.4" width="21.6" height="5" rx="1.6" fill="url(#h)" ${st(2.4)}/>
      <path d="M20 8.2v3.6M27.6 7.8v4" stroke="#c9bdf2" stroke-width="1.4" stroke-linecap="round"/>
      ${shine('M11 21.5v6', 2, 0.8)}${shine('M15.5 7.8a3.4 3.4 0 0 1 3-2', 1.6, 0.8)}
      ${spark(4.5, 9, 3.2, '#ffe066', 1.3)}${spark(45, 32, 2.4, '#ffe066', 1.1)}`,

    /* ── MYTHIC ── */
    'pet:glitchy': () => {
      const u = 2.7, x0 = 5.1, y0 = 7.8;
      const solid = gridPath(GLITCHY, x0, y0, u, (c) => c !== '.');
      const eyesD = gridPath(GLITCHY, x0, y0, u, (c) => c === 'E');
      const blushD = gridPath(GLITCHY, x0, y0, u, (c) => c === 'B');
      const mouthD = gridPath(GLITCHY, x0, y0, u, (c) => c === 'M');
      const tipD = gridPath(GLITCHY, x0, y0, u, (c) => c === 'A');
      const sil = `<path d="${solid}"/>`;
      return `<defs>${lgU('b', ['#d4ff9a', '#5ff06a', '#16b86a'], 0, 8, 0, 42)}</defs>
      <g fill="#ff2bd6" stroke="#ff2bd6" stroke-width="5.6" stroke-linejoin="round" transform="translate(-1.8 -.5)">${sil}</g>
      <g fill="#1ff4ff" stroke="#1ff4ff" stroke-width="5.6" stroke-linejoin="round" transform="translate(1.8 .5)">${sil}</g>
      <g fill="${OL}" stroke="${OL}" stroke-width="5" stroke-linejoin="round">${sil}</g>
      <path d="${solid}" fill="url(#b)"/>
      <path d="${tipD}" fill="#ff2bd6"/><path d="M${x0 + 2 * u} ${y0}h1.3v1.3h-1.3zM${x0 + 11 * u} ${y0}h1.3v1.3h-1.3z" fill="#fff"/>
      <path d="M${x0 + 3 * u} ${y0 + 2 * u}h${3 * u}v${u * 0.5}h${-3 * u}zM${x0 + 1 * u} ${y0 + 4 * u}h${u}v${u}h${-u}z" fill="#fff" opacity=".55"/>
      <path d="${eyesD}" fill="${OL}"/>
      <path d="M${x0 + 3 * u} ${y0 + 5 * u}h${u}v${u}h${-u}zM${x0 + 9 * u} ${y0 + 5 * u}h${u}v${u}h${-u}z" fill="#fff"/>
      <path d="M${x0 + 4 * u + 1} ${y0 + 7 * u + 1}h${u - 1}v${u - 1}h${1 - u}zM${x0 + 10 * u + 1} ${y0 + 7 * u + 1}h${u - 1}v${u - 1}h${1 - u}z" fill="#1ff4ff"/>
      <path d="${blushD}" fill="#ff5fa2" opacity=".75"/><path d="${mouthD}" fill="${OL}"/>
      <path d="M${x0 + 6 * u + 1} ${y0 + 8 * u + 1.2}h${2 * u - 2}v${u - 1.2}h${2 - 2 * u}z" fill="#ff5f8a"/>
      <g opacity=".22" fill="${OL}"><rect x="3" y="${y0 + 3.2 * u}" width="42" height="1"/><rect x="3" y="${y0 + 9.3 * u}" width="42" height="1"/></g>
      <rect x="${x0 + 13 * u - 2}" y="${y0 + 6 * u}" width="5" height="${u}" fill="#1ff4ff" ${st(1.2)}/>
      <rect x="${x0 - 2.5}" y="${y0 + 9 * u}" width="4" height="${u * 0.8}" fill="#ff2bd6" ${st(1.2)}/>
      <g ${st(1.2)}><rect x="40" y="3" width="3.2" height="3.2" fill="#ff2bd6"/><rect x="44" y="8" width="2.2" height="2.2" fill="#fff"/><rect x="3" y="44" width="2.6" height="2.6" fill="#1ff4ff"/><rect x="40.5" y="43.5" width="2.6" height="2.6" fill="#b6ff3b"/><rect x="2" y="2.5" width="2.2" height="2.2" fill="#b6ff3b"/></g>`;
    },

    'pet:whale': () => {
      const stock = 'M29.4 34.5C35 33.4 38.4 27.6 38 19L41.8 18.8C43 29 39 37 31 39Z';
      const fluke = 'M40 20C37 19 33.4 16.2 32.2 11.4 35.4 11 38.2 12.4 40.2 14.8 40.8 11.8 42.2 9.2 44.4 8 44.8 12.8 43.4 17.4 40 20Z';
      const finL = 'M6.5 34C2.8 33.4 1.8 37 3 39.6 5.4 40 7.8 38.8 9.4 36.4Z';
      const milk = 'M2 31C7.5 26.5 14 25.4 21 27.4 28 25.4 34.5 26.5 40 31 39 39 31.5 44 21 44 10.5 44 3 39 2 31Z';
      return `<defs>${lgU('b', ['#9a80ff', '#4a2cc9', '#1d0f66'], 0, 8, 0, 44)}${lg('mk', '#ffffff', '#e2dbff')}${rgM('n', [[0, '#ff6fe0', 0.85], [1, '#ff6fe0', 0]])}${rgM('n2', [[0, '#5ff8ff', 0.7], [1, '#5ff8ff', 0]])}</defs>
      ${uni(`<path d="${stock}"/><path d="${fluke}"/>`, 'url(#b)', 2.8)}
      <path d="M35 13.4l2.4 2.4M43.2 11l-1.4 3.2" stroke="#fff" stroke-width="1.1" stroke-linecap="round" opacity=".55"/>
      <path d="${finL}" fill="url(#b)" ${st(2.6)}/>
      ${tube('M21 14.5V8.2', '#fff', 3.2, 3)}${tube('M21 10Q17.6 5.2 14.6 7.6', '#fff', 2.8, 3)}${tube('M21 10Q24.4 5.2 27.4 7.6', '#fff', 2.8, 3)}
      <g fill="#fff" ${st(1.6)}><circle cx="21" cy="4.4" r="2.4"/><circle cx="13.4" cy="9" r="1.9"/><circle cx="28.6" cy="9" r="1.9"/></g>
      ${body('c', WHALE, 'url(#b)', `<path d="M-1 26C9 16 27 13 43 18L43 22C27 18 10 21 -1 30Z" fill="#c8b8ff" opacity=".3"/>
        <ellipse cx="11" cy="19.5" rx="7" ry="5" fill="url(#n)"/><ellipse cx="31" cy="20" rx="6" ry="4.2" fill="url(#n2)"/>
        <g fill="#fff"><circle cx="8" cy="23" r=".8"/><circle cx="17" cy="17.4" r=".65"/><circle cx="26" cy="15.8" r=".7"/><circle cx="35.6" cy="23" r=".8"/><circle cx="28.5" cy="21.6" r=".5"/><circle cx="14" cy="22.4" r=".5"/></g>
        ${spark(21.5, 20.5, 2.4, '#fff', 0.9)}${spark(6.5, 27.5, 1.6, '#fff', 0.8)}${spark(37, 27, 1.8, '#fff', 0.8)}
        <path d="${milk}" fill="url(#mk)" ${st(1.8)}/>
        <path d="M14 40.6Q21 42.8 28 40.6M16.6 43Q21 44.2 25.4 43" fill="none" stroke="#b9aaf0" stroke-width="1.3" stroke-linecap="round"/>`)}
      ${eyes(21, 31.6, 7, 3.5, { iris: '#8a6cff' })}${blush(21, 36.2, 12.4, 2.5)}${smile(21, 36.4, 2.2, 1.6)}
      ${shine('M7 22.5c2.4-3.6 6-6 10.4-7', 2.4, 0.8)}
      ${spark(4.5, 12, 3.2, '#fff', 1.3)}${spark(44, 42.5, 2.6, '#5ff8ff', 1.2)}${spark(8, 4.5, 2, '#ff9af0', 1.1)}`;
    },
  });

  /* ═════════════════════════ VISUAL-EFFECT ICONS ═════════════════════════ */
  const SPR = ['#ff3d6e', '#ffd23c', '#3dff7a', '#2bb8ff', '#b16bff', '#ff8a1f', '#ffffff', '#ff5fd6'];
  const sprinkle = (x, y, a, c, len = 5) => { const dx = P(Math.cos(a * D2R) * len / 2), dy = P(Math.sin(a * D2R) * len / 2); const d = `M${P(x - dx)} ${P(y - dy)}L${P(x + dx)} ${P(y + dy)}`; return `<path d="${d}" stroke="${OL}" stroke-width="3.8" stroke-linecap="round"/><path d="${d}" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>`; };
  function arcD(cx, cy, r, a0, a1) { const p0 = pt(cx, cy, r, a0), p1 = pt(cx, cy, r, a1); return `M${ps(p0)}A${r} ${r} 0 ${Math.abs(a1 - a0) > 180 ? 1 : 0} 1 ${ps(p1)}`; }
  function wedge(cx, cy, r0, r1, a, w0, w1) {
    const p = (r, da) => ps(pt(cx, cy, r, a + da));
    const d0 = (w0 / r0) / D2R / 2, d1 = (w1 / r1) / D2R / 2;
    return `M${p(r0, -d0)}L${p(r1, -d1)}L${p(r1, d1)}L${p(r0, d0)}Z`;
  }
  const bolt = (d, fill) => `<path d="${d}" fill="${fill}" ${st(2.2)}/>`;
  const CURSOR = 'M11 5l27 20-12 1.5 7 13-5.2 2.6-7-13L12 38z';
  function cursorAt(tx, ty, deg, s, fill) {
    return `<path d="${CURSOR}" transform="translate(${P(tx)} ${P(ty)}) rotate(${P(deg)}) scale(${s}) translate(-11 -5)" fill="${fill}" stroke="${OL}" stroke-width="${P(2.2 / s)}" stroke-linejoin="round"/>`;
  }
  function shard(x, y, L, W, deg, fill) {
    const r = deg * D2R, c = Math.cos(r), n = Math.sin(r);
    const T = ([a, b]) => P(x + a * c - b * n) + ' ' + P(y + a * n + b * c);
    const pts = [[0, -L], [W, -L * 0.5], [W, L * 0.55], [0, L * 0.8], [-W, L * 0.55], [-W, -L * 0.5]];
    return `<path d="M${pts.map(T).join('L')}Z" fill="${fill}" ${st(2)}/><path d="M${T([0, -L])}L${T([0, L * 0.8])}" stroke="#fff" stroke-width="1" opacity=".6"/><path d="M${T([-W * 0.55, -L * 0.3])}L${T([-W * 0.55, L * 0.35])}" stroke="#fff" stroke-width="1.3" stroke-linecap="round" opacity=".9"/>`;
  }
  function chainLinks(p0, p1, p2, n) {
    let s = '';
    for (let i = 0; i <= n; i++) {
      const t = i / n, u = 1 - t;
      const x = u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0], y = u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1];
      const dx = 2 * u * (p1[0] - p0[0]) + 2 * t * (p2[0] - p1[0]), dy = 2 * u * (p1[1] - p0[1]) + 2 * t * (p2[1] - p1[1]);
      const ang = Math.atan2(dy, dx) / D2R;
      s += i % 2 ? `<ellipse cx="${P(x)}" cy="${P(y)}" rx="2.3" ry="1.2" transform="rotate(${P(ang)} ${P(x)} ${P(y)})" fill="#ffc400" ${st(1.3)}/>` : `<ellipse cx="${P(x)}" cy="${P(y)}" rx="2.5" ry="1.7" transform="rotate(${P(ang)} ${P(x)} ${P(y)})" fill="url(#gd)" ${st(1.4)}/>`;
    }
    return s;
  }

  A.register({
    'vis:chips_xl': () => {
      const big = (x, y, s, rot) => `<g transform="translate(${x} ${y}) rotate(${rot}) scale(${s})"><path d="M0 -6.5C1.6 -4.4 5.6 -2.2 5.6 1.8 5.6 5 3 6.6 0 6.6S-5.6 5 -5.6 1.8C-5.6 -2.2 -1.6 -4.4 0 -6.5Z" fill="url(#c)" stroke="${OL}" stroke-width="${P(2 / s)}" stroke-linejoin="round"/><ellipse cx="-2.2" cy="0" rx="1.3" ry="2.3" transform="rotate(20)" fill="#fff" opacity=".85"/><circle cx="2.4" cy="3.4" r=".7" fill="#fff" opacity=".6"/></g>`;
      return `${cookie(24, 25, 19.5, { chips: [] })}<defs>${lg('c', '#9a5a30', '#2e1206')}</defs>
      ${big(16, 17, 1.05, -12)}${big(31.5, 15, 0.95, 14)}${big(32, 32, 1.15, 8)}${big(16.5, 33, 1.05, -6)}${big(24.5, 24.5, 0.7, 30)}
      ${spark(40.5, 7, 4.5, '#fff', 1.5)}`;
    },

    'vis:sprinkles': () => {
      const list = [[14, 17, 30], [22, 12, 100], [31, 14, -20], [37, 22, 60], [17, 26, -50], [26, 21, 10], [34, 31, 120], [25, 30, 70], [16, 35, 15], [28, 38, -35], [10, 24, 80], [21, 40, 45], [36, 38, 170], [31, 7.5, 20], [9, 31, -30]];
      return `${cookie(24, 24, 19.5, { chips: [[17.5, 21, 0.7, 1], [30, 26, 0.7, 2], [22, 34.5, 0.6, 3]] })}
      ${list.map(([x, y, a], i) => sprinkle(x, y, a, SPR[i % SPR.length], 5.2)).join('')}`;
    },

    'vis:glaze': () => `${cookie(24, 24, 19.5, { chips: [[10.5, 16, 0.75, 1], [37.5, 17, 0.75, 2], [9.5, 32, 0.8, 3], [38.5, 32.5, 0.8, 4], [24, 41, 0.8, 0], [16, 39.5, 0.6, 1], [32.5, 40, 0.6, 2]], shine: false })}
      <defs>${lgM('g', ['#ffd6f4', '#ff8ad8', '#f0409e'])}</defs>
      <path d="M11.5 21C11.5 14 17 10.5 24 10.8 31.5 10.5 36.5 14.5 36.5 21 36.5 24 35.8 26 35.4 27.6 35 29.4 35.8 32.2 34.2 33 32.6 33.8 31.8 32.2 31.8 30.6 31.4 29.4 29.8 29.4 29 30.8 28.2 32.2 28.6 36.2 26.8 37 25 37.8 24.2 35.8 24.2 33.4 24.2 31.8 22.8 31 21.2 31.4 19.6 31.8 19.6 34 17.8 34 16 34 16.4 31.8 15.2 30.4 13.8 29 11.5 28.6 11.5 25.4Z" fill="url(#g)" ${st(2.6)}/>
      ${shine('M15.4 18.4c1.4-2.8 3.8-4.4 7-4.8', 2.4, 0.9)}<ellipse cx="31" cy="16" rx="1.8" ry="1.1" fill="#fff" opacity=".75"/>
      <path d="M14.2 25.6c.2 1.2.6 2 1.3 2.6" stroke="#fff" stroke-width="1.4" stroke-linecap="round" opacity=".6"/>`,

    'vis:crystals': () => `${cookie(24, 25, 19, { chips: [[31, 12.5, 0.9, 0.8], [13, 31, 0.9, 2], [22, 39, 0.8, 4], [38.5, 24, 0.7, 1]] })}
      <defs>${lgM('g', ['#ffffff', '#8ffbff', '#1fa8e0'], 1, 1)}${lgM('p', ['#ffffff', '#ffb8f2', '#d84ad0'], 1, 1)}</defs>
      ${shard(15, 17.5, 9, 3.8, -26, 'url(#g)')}${shard(21.8, 18, 6.4, 3, 12, 'url(#g)')}
      ${shard(31.5, 30.5, 10, 4.2, 24, 'url(#p)')}${shard(24.6, 33.4, 6.4, 3, -14, 'url(#g)')}
      ${shard(35, 16.5, 6, 2.8, 38, 'url(#g)')}
      ${spark(7.5, 6.5, 3.8, '#fff', 1.4)}${spark(42.5, 42, 3.4, '#bff8ff', 1.3)}`,

    'vis:rgb_rim': () => {
      const cols = ['#ff2b5e', '#ff8a1f', '#ffe14a', '#3dff7a', '#1ff4ff', '#2b7bff', '#b16bff', '#ff2bd6'];
      return `<circle cx="24" cy="24" r="20" fill="none" stroke="${OL}" stroke-width="8.6"/>
      ${cols.map((c, i) => `<path d="${arcD(24, 24, 20, i * 45 - 90, i * 45 - 44)}" fill="none" stroke="${c}" stroke-width="4.6"/>`).join('')}
      <path d="${arcD(24, 24, 20, 200, 240)}" fill="none" stroke="#fff" stroke-width="1.4" stroke-linecap="round" opacity=".8"/>
      ${cookie(24, 24, 14.2, { chips: [[17.5, 17, 1.1, 0], [30, 14, 1.1, 0.8], [32.5, 29.5, 1.15, 2], [19.5, 32, 1.1, 4], [25.4, 23, 0.9, 1]] })}`;
    },

    'vis:face': () => `${cookie(24, 24, 19.5, { chips: CK_EDGE })}
      ${eyes(24, 21, 7, 3.9)}${blush(24, 27.5, 12.5, 3)}${openMouth(24, 27.2, 2.6, 3)}`,

    'vis:shades': () => {
      const g = ['#################', '.######...######.', '.######...######.', '..####.....####..'];
      const u = 2.45, x0 = 24 - 8.5 * u, y0 = 17;
      const d = gridPath(g, x0, y0, u, (c) => c === '#');
      return `${cookie(24, 26, 18.5, { chips: CK_EDGE })}
      <g transform="rotate(-7 24 22)">${uni(`<path d="${d}"/>`, '#1c1030', 1.6)}
      <path d="M${P(x0 + 2 * u)} ${P(y0 + u)}h${u}v${u}h${-u}zM${P(x0 + 3 * u)} ${P(y0 + 2 * u)}h${u}v${u}h${-u}zM${P(x0 + 11 * u)} ${P(y0 + u)}h${u}v${u}h${-u}zM${P(x0 + 12 * u)} ${P(y0 + 2 * u)}h${u}v${u}h${-u}z" fill="#fff"/>
      <path d="M${P(x0 + 0.4 * u)} ${P(y0 + 0.4 * u)}h${P(16.2 * u)}" stroke="#6a5a9a" stroke-width="1" opacity=".8"/></g>
      <path d="M22 35.5Q26 37.5 29.5 34" fill="none" ${st(2)}/>`;
    },

    'vis:crown': () => `${cookie(24, 29.5, 16.5)}
      <defs>${lg('gc', '#fff27a', '#e59a00')}</defs>
      <g transform="rotate(-10 24 14)">
        <path d="M12.4 21.5L10.6 8.4 17.4 13.2 24 4.8 30.6 13.2 37.4 8.4 35.6 21.5Z" fill="url(#gc)" ${st(2.8)}/>
        <rect x="11.2" y="18.6" width="25.6" height="6" rx="2.2" fill="url(#gc)" ${st(2.6)}/>
        <circle cx="24" cy="21.6" r="2.1" fill="#ff2bd6" ${st(1.4)}/><circle cx="17" cy="21.6" r="1.6" fill="#1ff4ff" ${st(1.3)}/><circle cx="31" cy="21.6" r="1.6" fill="#b6ff3b" ${st(1.3)}/>
        <g fill="#fff" ${st(1.5)}><circle cx="10.4" cy="8" r="2.2"/><circle cx="24" cy="4.2" r="2.4"/><circle cx="37.6" cy="8" r="2.2"/></g>
        ${shine('M14.6 13.4l.9 4.6', 1.8, 0.85)}</g>
      ${spark(42, 6, 3.4, '#fff', 1.3)}`,

    'vis:headphones': () => `${cookie(24, 26.5, 16.5, { chips: [[17.5, 19, 1, 0], [29.6, 15, 1, 0.8], [31, 30, 1.05, 2], [20, 33, 1, 4], [25.4, 24, 0.8, 1]] })}
      <defs>${lgU('band', ['#ff2bd6', '#b16bff', '#1ff4ff'], 6, 0, 42, 0)}${lg('cup', '#5a3fa0', '#241446')}</defs>
      ${tube('M8.5 25C8.5 8 39.5 8 39.5 25', 'url(#band)', 4.4, 3.6)}
      <path d="M13.5 13.6c2.8-2.4 6.4-3.6 10.5-3.6" stroke="#fff" stroke-width="1.3" stroke-linecap="round" opacity=".7" fill="none"/>
      ${tube('M7.5 34Q9 41.5 17 41', '#3a2766', 2, 3)}<circle cx="18.2" cy="40.8" r="2.4" fill="#b6ff3b" ${st(1.8)}/>
      <g fill="url(#cup)" ${st(3)}><rect x="2.6" y="19.5" width="10.4" height="16" rx="4.6"/><rect x="35" y="19.5" width="10.4" height="16" rx="4.6"/></g>
      <rect x="5.4" y="22.4" width="4.8" height="10.2" rx="2.4" fill="none" stroke="#ff2bd6" stroke-width="2"/><rect x="37.8" y="22.4" width="4.8" height="10.2" rx="2.4" fill="none" stroke="#1ff4ff" stroke-width="2"/>
      ${shine('M5 23v3', 1.4, 0.7)}${shine('M37.4 23v3', 1.4, 0.7)}`,

    'vis:bling': () => `${cookie(24, 21, 17.5)}
      <defs>${lg('gd', '#fff6a8', '#e0a000')}${lgM('gp', ['#fffbd0', '#ffd23c', '#d98a00'])}</defs>
      ${chainLinks([7.5, 21], [24, 50], [40.5, 21], 14)}
      <path d="M24 34.6v3" stroke="${OL}" stroke-width="3.6" stroke-linecap="round"/><path d="M24 34.6v3" stroke="#ffc400" stroke-width="1.6" stroke-linecap="round"/>
      <circle cx="24" cy="41" r="5.6" fill="url(#gp)" ${st(2.6)}/><path d="${star(24, 41.3, 3.6, 1.5)}" fill="#fff6c0" stroke="#c07800" stroke-width="1" stroke-linejoin="round"/>
      ${shine('M20.5 39.2a4 4 0 0 1 2-2.4', 1.3, 0.9)}
      ${spark(33, 44, 2.6, '#fff', 1.1)}${spark(40.5, 31, 3, '#fff6a8', 1.2)}`,

    'vis:halo': () => `<defs>${rgM('gl', [[0, '#fff6b0', 0.9], [0.55, '#ffd23c', 0.35], [1, '#ffd23c', 0]])}${lgU('gh', ['#fffbd0', '#ffc400'], 0, 4, 0, 13)}</defs>
      <ellipse cx="24" cy="10.5" rx="21" ry="9" fill="url(#gl)"/>
      ${cookie(24, 29.5, 16.5)}
      <ellipse cx="24" cy="8.5" rx="13.5" ry="4.6" fill="none" stroke="${OL}" stroke-width="7.4"/>
      <ellipse cx="24" cy="8.5" rx="13.5" ry="4.6" fill="none" stroke="url(#gh)" stroke-width="3.6"/>
      <path d="M13.6 6.8Q18 4.8 23 4.6" fill="none" stroke="#fff" stroke-width="1.3" stroke-linecap="round" opacity=".9"/>
      ${spark(42.5, 16, 3.2, '#fff6b0', 1.3)}${spark(5.5, 17.5, 2.6, '#fff', 1.2)}`,

    'vis:wings': () => {
      const wingL = 'M17 21C13 13.5 7.5 9 2.2 8.6 2.6 11.6 3.6 13.6 5 15 2.8 15.8 2.4 18 3.4 19.8 4.6 21.6 7 22 8.2 21.8 6.8 23.6 7 25.8 8.6 27.4 10.6 29.2 14 28.8 17.6 27Z';
      return `<defs>${lgU('wg', ['#ffffff', '#c4fcff', '#5fe0ff', '#b98cff'], 0, 8, 0, 30)}</defs>
      <g transform="translate(1.6 0)"><path d="${wingL}" fill="none" stroke="#ff8af0" stroke-width="5.4" stroke-linejoin="round" opacity=".55"/><path d="${wingL}" fill="url(#wg)" ${st(2.6)}/>
        <path d="M5.4 15.2C9 16.4 12.4 18.6 15.4 21.4M8.4 21.9C10.8 22.7 13 24 15 25.8" fill="none" stroke="#ff4fd8" stroke-width="1.4" stroke-linecap="round" opacity=".85"/>${shine('M7 11.2c2.6.4 5 1.6 7.2 3.4', 1.4, 0.9)}</g>
      <g transform="translate(-1.6 0)"><path d="${mirror(wingL)}" fill="none" stroke="#ff8af0" stroke-width="5.4" stroke-linejoin="round" opacity=".55"/><path d="${mirror(wingL)}" fill="url(#wg)" ${st(2.6)}/>
        <path d="M42.6 15.2C39 16.4 35.6 18.6 32.6 21.4M39.6 21.9C37.2 22.7 35 24 33 25.8" fill="none" stroke="#ff4fd8" stroke-width="1.4" stroke-linecap="round" opacity=".85"/>${shine('M41 11.2c-2.6.4-5 1.6-7.2 3.4', 1.4, 0.9)}</g>
      ${cookie(24, 28, 14, { chips: [[17.5, 17, 1.1, 0], [30, 14, 1.1, 0.8], [32.5, 29.5, 1.15, 2], [19.5, 32, 1.1, 4], [25.4, 23, 0.9, 1]] })}
      ${spark(24, 6.5, 3.4, '#bffcff', 1.3)}`;
    },

    'vis:laser_eyes': () => {
      const beam = (x0, y0, x1, y1, w0, w1) => { const a = Math.atan2(y1 - y0, x1 - x0), nx = -Math.sin(a), ny = Math.cos(a); return `M${P(x0 + nx * w0)} ${P(y0 + ny * w0)}L${P(x1 + nx * w1)} ${P(y1 + ny * w1)}A${w1} ${w1} 0 0 0 ${P(x1 - nx * w1)} ${P(y1 - ny * w1)}L${P(x0 - nx * w0)} ${P(y0 - ny * w0)}Z`; };
      const E1 = [12, 18.5], E2 = [22, 18.5], T1 = [35, 37.8], T2 = [43.2, 36.4];
      return `${cookie(17, 22, 14.5, { chips: [[13, 32, 0.9, 1], [29, 34, 0.9, 2], [20, 39, 0.8, 4], [31, 10.5, 0.8, 0.5], [15, 10.5, 0.75, 3]] })}
      <defs>${lgU('lb', ['#ff9a9a', '#ff1f3d', '#d0001e'], 12, 18, 40, 40)}${rgM('lg', [[0, '#fff', 1], [0.35, '#ff3d3d', 0.9], [1, '#ff1f3d', 0]])}</defs>
      <path d="${beam(...E1, ...T1, 1.4, 3)}" fill="url(#lb)" ${st(2)}/><path d="${beam(...E2, ...T2, 1.4, 3)}" fill="url(#lb)" ${st(2)}/>
      <path d="M${E1}L${P(T1[0] - 1.5)} ${P(T1[1] - 1.3)}M${E2}L${P(T2[0] - 1.5)} ${P(T2[1] - 1.3)}" stroke="#fff" stroke-width="1.3" stroke-linecap="round" opacity=".9"/>
      <circle cx="${E1[0]}" cy="${E1[1]}" r="5.4" fill="url(#lg)"/><circle cx="${E2[0]}" cy="${E2[1]}" r="5.4" fill="url(#lg)"/>
      <g fill="#fff" ${st(1.4)}><circle cx="${E1[0]}" cy="${E1[1]}" r="2.2"/><circle cx="${E2[0]}" cy="${E2[1]}" r="2.2"/></g>
      <path d="${star(E1[0], E1[1], 5.6, 1, 4, 0)}" fill="#fff" opacity=".9"/><path d="${star(E2[0], E2[1], 5.6, 1, 4, 0)}" fill="#fff" opacity=".9"/>
      ${spark(T1[0] + 0.5, T1[1] + 0.5, 3.4, '#fff', 1.2)}${spark(T2[0] + 0.3, T2[1] + 0.4, 3.4, '#fff', 1.2)}`;
    },

    'vis:galaxy_core': () => {
      const cracks = ['M24 24L19 20.5 16 21 11.5 15.5', 'M19 20.5L18 15', 'M24 24L28 18.5 33 16.5 35.5 11', 'M24 24L30 27 33.5 26 38 30', 'M30 27L31.5 32', 'M24 24L22 30 17 33 14.5 38', 'M24 24L20.5 26.5 10.5 27.5'];
      const all = cracks.map((d) => `<path d="${d}"/>`).join('');
      return `${cookie(24, 24, 19.5, { pal: ['#f0c78c', '#8a4a1c'], chips: [[14, 12, 0.8, 1], [37, 20, 0.8, 2], [30, 38, 0.8, 3], [10, 33, 0.7, 4]] })}
      <defs>${rgM('core', [[0, '#ffffff', 1], [0.35, '#ff9af0', 1], [0.7, '#b16bff', 0.7], [1, '#7a2cff', 0]])}</defs>
      <g fill="none" stroke="${OL}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">${all}</g>
      <g fill="none" stroke="#c77bff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">${all}</g>
      <g fill="none" stroke="#ffffff" stroke-width="1.1" stroke-linecap="round" stroke-linejoin="round" opacity=".9">${all}</g>
      <circle cx="24" cy="24" r="7.5" fill="url(#core)"/><path d="${star(24, 24, 5, 1.5, 4, 0)}" fill="#fff" ${st(1.2)}/>
      ${spark(41.5, 6.5, 3.4, '#9ff6ff', 1.3)}${spark(6, 42, 2.8, '#ff9af0', 1.2)}`;
    },

    'vis:holo': () => {
      const edge = cookieEdge(24, 24, 19.5);
      return `${cookie(24, 24, 19.5, { shine: false, chips: [] })}
      <defs>${lgM('ho', ['#ff6ff0', '#6ff6ff', '#fff36f', '#a88cff', '#6fffb8', '#ff6ff0'], 1, 1)}<clipPath id="hc"><path d="${edge}"/></clipPath></defs>
      <path d="${edge}" fill="url(#ho)" opacity=".74"/>
      <g clip-path="url(#hc)" fill="#fff" opacity=".7"><path d="M4 22L22 4h5L4 27z"/><path d="M14 38L38 14h2.4L14 40.4z"/><path d="M24 44L44 24v3L27 44z"/></g>
      ${CK_CHIPS.map(([x, y, sc, rot]) => chip(x, y, sc, rot, '#4a2511')).join('')}
      <path d="${edge}" fill="none" ${st(3)}/>
      ${shine('M11.5 14c1.8-2.4 4.2-3.9 6.8-4.6')}
      ${spark(40.5, 8, 4.2, '#fff', 1.4)}${spark(8, 40, 3, '#bffcff', 1.2)}${spark(43, 38, 2.2, '#ffc8f6', 1.1)}`;
    },

    'vis:glitch': () => {
      const edge = cookieEdge(24, 24, 17.5);
      const main = cookie(24, 24, 17.5, { id: 'c1' });
      return `<path d="${edge}" fill="#ff2bd6" transform="translate(-3.6 -.6)" opacity=".95"/><path d="${edge}" fill="#1ff4ff" transform="translate(3.6 .6)" opacity=".95"/>
      ${main}
      <defs><clipPath id="s1"><rect x="0" y="27.5" width="48" height="4.6"/></clipPath><clipPath id="s2"><rect x="0" y="13" width="48" height="3.2"/></clipPath></defs>
      <g clip-path="url(#s1)"><g transform="translate(5 0)">${cookie(24, 24, 17.5, { id: 'c2', shine: false })}</g></g>
      <g clip-path="url(#s2)"><g transform="translate(-4 0)">${cookie(24, 24, 17.5, { id: 'c3', shine: false })}</g></g>
      <g ${st(1.3)}><rect x="3" y="5" width="4" height="4" fill="#ff2bd6"/><rect x="40" y="38" width="4.4" height="4.4" fill="#1ff4ff"/><rect x="41" y="7" width="2.8" height="2.8" fill="#fff"/><rect x="5.5" y="40" width="3" height="3" fill="#b6ff3b"/><rect x="37" y="3" width="2.4" height="2.4" fill="#1ff4ff"/></g>`;
    },

    'vis:afterimage': () => {
      const ghost = (cx, c, o) => `<path d="${cookieEdge(cx, 24, 14.5)}" fill="${c}" stroke="${c}" stroke-width="2" opacity="${o}"/>`;
      return `${ghost(15, '#ff2bd6', 0.35)}${ghost(19.5, '#ffe14a', 0.5)}${ghost(24.5, '#1ff4ff', 0.7)}
      <g stroke-linecap="round" stroke-width="2.2"><path d="M2.5 16h5" stroke="#ff2bd6" opacity=".7"/><path d="M2 24h4" stroke="#ffe14a" opacity=".8"/><path d="M2.5 32h5" stroke="#1ff4ff" opacity=".8"/></g>
      ${cookie(31, 24, 14.5, { chips: [[17.5, 17, 1.1, 0], [30, 14, 1.1, 0.8], [32.5, 29.5, 1.15, 2], [19.5, 32, 1.1, 4], [25.4, 23, 0.9, 1]] })}`;
    },

    'vis:orbiters': () => {
      const rot = -22, rx = 19.5, ry = 8, cy = 25;
      const at = (t) => { const x = rx * Math.cos(t * D2R), y = ry * Math.sin(t * D2R), r = rot * D2R; return [24 + x * Math.cos(r) - y * Math.sin(r), cy + x * Math.sin(r) + y * Math.cos(r)]; };
      const trail = (t0, t1) => `M${ps(at(t0))}A${rx} ${ry} ${rot} 0 1 ${ps(at(t1))}`;
      const half = (sweep) => `<path d="M${24 - rx} ${cy}A${rx} ${ry} 0 0 ${sweep} ${24 + rx} ${cy}" transform="rotate(${rot} 24 ${cy})" fill="none" stroke="${OL}" stroke-width="5.2"/><path d="M${24 - rx} ${cy}A${rx} ${ry} 0 0 ${sweep} ${24 + rx} ${cy}" transform="rotate(${rot} 24 ${cy})" fill="none" stroke="#8ffbff" stroke-width="2.6"/>`;
      const m1 = at(155), m2 = at(345), m3 = at(300);
      return `<defs>${MK}</defs>${half(1)}
      ${mini(m3[0], m3[1], 3.6, 1.8)}
      ${cookie(24, cy, 10.8, { chips: [[17.5, 17, 1.3, 0], [30, 14, 1.3, 0.8], [32, 30, 1.3, 2], [19, 31.5, 1.3, 4]] })}
      ${half(0)}
      <g fill="none" stroke-linecap="round" stroke-width="2.6"><path d="${trail(118, 147)}" stroke="#ff2bd6" opacity=".85"/><path d="${trail(308, 337)}" stroke="#b6ff3b" opacity=".85"/></g>
      ${mini(m1[0], m1[1], 6)}${mini(m2[0], m2[1], 5.6)}
      ${spark(8, 8, 3, '#fff', 1.2)}${spark(40, 41, 2.6, '#8ffbff', 1.1)}`;
    },

    'vis:saturn_ring': () => {
      const rot = -18, rx = 21, ry = 7.2;
      const ringBack = `<ellipse cx="24" cy="24" rx="${rx}" ry="${ry}" transform="rotate(${rot} 24 24)" fill="none"`;
      const front = `<path d="M${24 - rx} 24A${rx} ${ry} 0 0 0 ${24 + rx} 24" transform="rotate(${rot} 24 24)" fill="none"`;
      return `<defs>${lgU('rg', ['#1ff4ff', '#b16bff', '#ff2bd6'], 4, 0, 44, 0)}</defs>
      ${ringBack} stroke="${OL}" stroke-width="8"/>${ringBack} stroke="url(#rg)" stroke-width="4"/>
      ${cookie(24, 24, 14, { chips: [[17.5, 17, 1.1, 0], [30, 14, 1.1, 0.8], [32.5, 29.5, 1.15, 2], [19.5, 32, 1.1, 4], [25.4, 23, 0.9, 1]] })}
      ${front} stroke="${OL}" stroke-width="8" stroke-linecap="round"/>${front} stroke="url(#rg)" stroke-width="4" stroke-linecap="round"/>
      <path d="M${24 - rx + 3} 26.2A${rx - 3} ${ry - 1.8} 0 0 0 ${24} ${24 + ry - 1.8}" transform="rotate(${rot} 24 24)" fill="none" stroke="#fff" stroke-width="1.1" stroke-linecap="round" opacity=".75"/>
      ${spark(41, 6.5, 3.2, '#fff', 1.3)}${spark(7, 41, 2.6, '#bffcff', 1.2)}`;
    },

    'vis:fire_aura': () => `<defs>${lgM('fo', ['#ff2b5e', '#ff6a00', '#ffc21a', '#fff27a'])}${lgM('fi', ['#ffb300', '#fff27a', '#fffbe0'])}</defs>
      <path d="M24 46C12 46 4 39 4 29 4 22 7.8 17.8 9.8 12.8 11.2 15.8 12.4 17.6 14.4 18.8 14 12.8 16.6 6.8 21.2 2.2 21.6 7 23 10 25.6 12 27.2 8.4 29.6 5.8 33.2 4.4 32.2 9 33.6 13 36.2 16 37.4 14 38.2 12 38.2 9.4 41.8 13.6 44 20 44 28 44 39 36 46 24 46Z" fill="url(#fo)" ${st(3)}/>
      <path d="M24 44C15.5 44 9.5 39 9.5 31.5 9.5 26.5 12 23.6 13.5 20 14.6 22 15.6 23.2 17 24 17 19.5 19 15.6 22 12.4 22.4 15.6 23.6 17.6 25.6 19 26.8 16.4 28.6 14.6 31 13.6 30.4 16.8 31.4 19.4 33.2 21.4 34 20 34.6 18.6 34.6 16.8 37.2 19.8 38.6 24.4 38.6 30 38.6 38.6 32.6 44 24 44Z" fill="url(#fi)" opacity=".9"/>
      ${cookie(24, 31.5, 12.2, { chips: [[17.5, 17, 1.2, 0], [30, 14, 1.2, 0.8], [32.5, 29.5, 1.2, 2], [19.5, 32, 1.2, 4]] })}
      <g fill="#ffe14a" ${st(1.2)}><circle cx="6" cy="8" r="1.5"/><circle cx="42.5" cy="6" r="1.3"/><circle cx="45" cy="17" r="1"/></g>`,

    'vis:lightning': () => `<defs>${lgM('el', ['#ffffff', '#bffcff', '#1fc8ff'])}</defs>
      <g fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M6 36l4.5-2.5 1 4 4-3M42 36l-4.5-2.5-1 4-4-3M24 44.5l-2.2-2.8 3.2-1.4-2-2.6" stroke="${OL}" stroke-width="4.6"/>
      <path d="M6 36l4.5-2.5 1 4 4-3M42 36l-4.5-2.5-1 4-4-3M24 44.5l-2.2-2.8 3.2-1.4-2-2.6" stroke="#8ffbff" stroke-width="2"/></g>
      ${cookie(24, 26, 13.5, { chips: [[17.5, 17, 1.2, 0], [30, 14, 1.2, 0.8], [32.5, 29.5, 1.2, 2], [19.5, 32, 1.2, 4]] })}
      ${bolt('M11.5 2.5L3.5 13.8H8.6L4.6 22.6 15.4 10.4H10.6L14.8 2.5Z', 'url(#el)')}
      ${bolt('M38.2 2.5L33.2 11.6H37.4L33 21.4 44.4 9H39.8L43.2 2.5Z', 'url(#el)')}
      ${spark(24, 6, 3, '#fff', 1.2)}`,

    'vis:shockwave': () => `<defs>${lgM('bu', ['#fffbd0', '#ffd23c', '#ff8a1f'])}</defs>
      ${[[-70, -20], [0, 50], [110, 160], [180, 230]].map(([a, b]) => `<path d="${arcD(24, 24, 20.5, a, b)}" fill="none" stroke="${OL}" stroke-width="6.4" stroke-linecap="round"/><path d="${arcD(24, 24, 20.5, a, b)}" fill="none" stroke="#8ffbff" stroke-width="3" stroke-linecap="round"/>`).join('')}
      ${[[-30, 20], [65, 100], [140, 170], [235, 265]].map(([a, b]) => `<path d="${arcD(24, 24, 20.5, a + 5, b - 5)}" fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round" opacity=".55"/>`).join('')}
      <path d="${star(24, 24, 16.5, 10.5, 10, -Math.PI / 2)}" fill="url(#bu)" ${st(2.4)}/>
      ${cookie(24, 24, 10.5, { chips: [[17.5, 17, 1.3, 0], [30, 14, 1.3, 0.8], [31.5, 30, 1.3, 2], [19, 31.5, 1.3, 4]] })}`,

    'vis:confetti_click': () => {
      const rects = [[7, 9, 30, '#ff2bd6'], [39, 8, -25, '#1ff4ff'], [43, 27, 60, '#ffe14a'], [5, 30, -50, '#b6ff3b'], [33, 43, 15, '#ff8a1f'], [13, 43, 70, '#b16bff'], [24, 4, 10, '#3dff7a']];
      const tris = [[16, 5, '#ffe14a', 20], [44, 17, '#ff2bd6', -30], [4, 19, '#1ff4ff', 40], [42, 38, '#b16bff', 0]];
      return `${cookie(24, 25, 12.8, { chips: [[17.5, 17, 1.2, 0], [30, 14, 1.2, 0.8], [32.5, 29.5, 1.2, 2], [19.5, 32, 1.2, 4]] })}
      <g stroke="#fff" stroke-width="1.6" stroke-linecap="round" opacity=".7"><path d="M11.5 14.5l-2-2M36.5 14.5l2-2M11 36l-2 2M37 36l2 2"/></g>
      ${rects.map(([x, y, a, c]) => `<rect x="${x - 2.4}" y="${y - 1.4}" width="4.8" height="2.8" rx=".6" transform="rotate(${a} ${x} ${y})" fill="${c}" ${st(1.3)}/>`).join('')}
      ${tris.map(([x, y, c, a]) => `<path d="M${x} ${y - 2.6}l2.4 4.2h-4.8z" transform="rotate(${a} ${x} ${y})" fill="${c}" ${st(1.3)}/>`).join('')}
      ${tube('M30 3.5q1.6 1.2 3.2 0t3.2 0', '#ff5f8a', 1.6, 2.4)}${tube('M3 38q1.2 1.6 0 3.2t0 3.2', '#1ff4ff', 1.6, 2.4)}${tube('M44.5 44q-1.6-1.2-3.2 0', '#ffe14a', 1.6, 2.4)}`;
    },

    'vis:chat': () => {
      const W = 'M22.6 9.2L25.4 17.6 29.4 11.6 33.4 17.6 36.2 9.2';
      return `<defs>${MK}${lg('b1', '#d0bcff', '#7a4ae8')}${lg('b2', '#ff9aea', '#e21fb8')}</defs>
      <path d="M21 3.5H40.6A4.8 4.8 0 0 1 45.4 8.3V17.9A4.8 4.8 0 0 1 40.6 22.7H23.4L17.2 27.4 18.6 22.4A4.8 4.8 0 0 1 16.2 18V8.3A4.8 4.8 0 0 1 21 3.5Z" fill="url(#b1)" ${st(3)}/>
      <path d="${W}" fill="none" stroke="${OL}" stroke-width="5.6" stroke-linecap="round" stroke-linejoin="round"/><path d="${W}" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>
      ${shine('M19.6 7.4v3.4', 1.6, 0.7)}
      <path d="M29.6 26.4H41.4A3.8 3.8 0 0 1 45.2 30.2V35.6A3.8 3.8 0 0 1 41.4 39.4H31.6L26.6 42.6 27.6 38.8A3.8 3.8 0 0 1 25.8 35.6V30.2A3.8 3.8 0 0 1 29.6 26.4Z" fill="url(#b2)" ${st(2.8)}/>
      <path d="M35.5 37.2S30.6 34.3 30.6 31.2C30.6 29.6 31.8 28.6 33 28.6 34.1 28.6 35 29.2 35.5 30.1 36 29.2 36.9 28.6 38 28.6 39.2 28.6 40.4 29.6 40.4 31.2 40.4 34.3 35.5 37.2 35.5 37.2Z" fill="#fff" ${st(1.5)}/>
      ${cookie(12, 35.5, 9.8, { chips: [[17.5, 17, 1.3, 0], [30, 14, 1.3, 0.8], [31.5, 30, 1.3, 2], [18.5, 31, 1.3, 4]] })}
      <path d="M5 16.5h5.5M5 21h8" stroke="#8ffbff" stroke-width="2.4" stroke-linecap="round" opacity=".75"/>`;
    },

    'vis:cursor_rgb': () => {
      const cols = [['#ffd6f6', '#ff2bd6'], ['#d6fdff', '#18c8ff'], ['#f0ffd0', '#7fd800'], ['#fff6c8', '#ffae00']];
      let defs = '', s = '';
      cols.forEach(([a, b], i) => {
        defs += lg('c' + i, a, b);
        const phi = i * 90 - 135, tip = pt(24, 24, 10.6, phi);
        s += cursorAt(tip[0], tip[1], phi + 298.3, 0.44, `url(#c${i})`);
      });
      const dots = [[24, 5.5, '#ff2bd6'], [42.5, 24, '#1ff4ff'], [24, 42.5, '#b6ff3b'], [5.5, 24, '#ffd23c']].map(([x, y, c]) => spark(x, y, 3.2, c, 1.2)).join('');
      return `<defs>${defs}</defs><circle cx="24" cy="24" r="17" fill="none" stroke="#fff" stroke-width="1.5" stroke-dasharray="2.2 3" opacity=".45"/>
      ${cookie(24, 24, 9.4, { chips: [[17.5, 17, 1.4, 0], [30, 14.5, 1.4, 0.8], [30.5, 30, 1.4, 2], [18.5, 30.5, 1.4, 4]], w: 2.6 })}${s}${dots}`;
    },

    'vis:cookie_rain': () => {
      const list = [[12, 13, 6.4], [34, 8.5, 5.2], [26, 27.5, 8], [9.5, 36, 5.4], [39, 34, 6.8]];
      const streaks = list.map(([x, y, r]) => { const a = 250 * D2R, s = Math.cos(a), c = Math.sin(a); const off = r * 0.55; return `<path d="M${P(x - off + s * (r + 1))} ${P(y + c * (r + 1))}l${P(s * 7)} ${P(c * 7)}M${P(x + off + s * (r + 1))} ${P(y + c * (r + 1))}l${P(s * 5)} ${P(c * 5)}"/>`; }).join('');
      return `<defs>${MK}</defs><g stroke="#8ffbff" stroke-width="2" stroke-linecap="round" opacity=".65" fill="none">${streaks}</g>
      ${list.map(([x, y, r]) => mini(x, y, r, r > 7 ? 2.6 : 2.2)).join('')}
      ${shine('M21.5 23.5a6 6 0 0 1 3-2.6', 1.6, 0.75)}`;
    },

    'vis:disco': () => {
      const cx = 24, cy = 27, r = 15.5;
      let tiles = '';
      const cols = ['#ff2bd6', '#1ff4ff', '#fff', '#b6ff3b', '#ffd23c', '#b16bff'];
      [[18, 20], [26, 17], [31, 24], [21, 28], [28, 32], [16, 33], [34, 30], [23, 36]].forEach(([x, y], i) => { tiles += `<rect x="${x - 1.7}" y="${y - 1.7}" width="3.4" height="3.4" fill="${cols[i % cols.length]}" opacity=".9"/>`; });
      return `<defs>${rg('db', '#ffffff', '#6a5aa8', 0.35, 0.3, 0.85)}<clipPath id="dc"><circle cx="${cx}" cy="${cy}" r="${r}"/></clipPath>
        ${lgM('sp1', [[0, '#ff9af2', 0.85], [1, '#ff9af2', 0]], 0, 1)}${lgM('sp2', [[0, '#9ffcff', 0.85], [1, '#9ffcff', 0]], 0, 1)}</defs>
      <path d="M16 33L1 47H15Z" fill="url(#sp1)"/><path d="M32 33L47 47H33Z" fill="url(#sp2)"/>
      <path d="M24 1.5V11" stroke="${OL}" stroke-width="3.6" stroke-linecap="round"/><path d="M24 1.5V11" stroke="#c9bdf2" stroke-width="1.4" stroke-linecap="round"/>
      <rect x="20.6" y="9.6" width="6.8" height="3.6" rx="1.2" fill="#c9bdf2" ${st(2)}/>
      <circle cx="${cx}" cy="${cy}" r="${r}" fill="url(#db)"/>
      <g clip-path="url(#dc)">${tiles}
        <g fill="none" stroke="${OL}" stroke-width="1" opacity=".45">
          ${[-11.5, -7.7, -3.9, 0, 3.9, 7.7, 11.5].map((dy) => `<path d="M${cx - r} ${cy + dy}H${cx + r}"/>`).join('')}
          <path d="M${cx} ${cy - r}V${cy + r}"/>${[0.36, 0.7, 0.95].map((k) => `<ellipse cx="${cx}" cy="${cy}" rx="${P(r * k)}" ry="${r}"/>`).join('')}
        </g>
        <path d="M11 18a15.5 15.5 0 0 1 8-6.5" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity=".8" fill="none"/></g>
      <circle cx="${cx}" cy="${cy}" r="${r}" fill="none" ${st(3)}/>
      ${spark(8, 12, 4, '#fff', 1.4)}${spark(41, 14, 3.2, '#8ffbff', 1.3)}${spark(43, 39, 2.4, '#ff9af0', 1.1)}${spark(5, 40, 2.4, '#ffe14a', 1.1)}`;
    },

    'vis:warp': () => {
      const cols = ['#ffffff', '#1ff4ff', '#ff2bd6', '#ffe14a', '#b16bff', '#ffffff', '#3dff7a', '#1ff4ff'];
      let s = '';
      for (let i = 0; i < 16; i++) {
        const a = i * 22.5 + (i % 2 ? 6 : 0), long = i % 2 === 0;
        const r0 = long ? 12.5 : 14.5, r1 = long ? 22.2 : 19.5;
        s += `<path d="${wedge(24, 24, r0, r1, a, 0.6, long ? 3.2 : 2.4)}" fill="${cols[i % cols.length]}" ${st(1.3)}/>`;
      }
      return `${s}${cookie(24, 24, 9.5, { chips: [[17.5, 17, 1.4, 0], [30, 14.5, 1.4, 0.8], [30.5, 30, 1.4, 2], [18.5, 30.5, 1.4, 4]], w: 2.6 })}`;
    },

    'vis:god_rays': () => {
      let rays = '';
      for (let i = 0; i < 12; i++) {
        const a = i * 30 - 90, long = i % 2 === 0;
        rays += `<path d="${wedge(24, 24, 9, long ? 22.4 : 18.5, a, 2.6, long ? 7.8 : 5.6)}" fill="url(${long ? '#ry' : '#ry2'})" ${st(2)}/>`;
      }
      return `<defs>${rgM('gl', [[0, '#fffbe0', 1], [0.5, '#ffe066', 0.6], [1, '#ffd23c', 0]])}${lgM('ry', ['#ffffff', '#ffe066'])}${lgM('ry2', ['#fff6c0', '#ffb300'])}</defs>
      <circle cx="24" cy="24" r="23" fill="url(#gl)" opacity=".75"/>${rays}
      <circle cx="24" cy="24" r="14.6" fill="#fff6b0" opacity=".85"/>
      ${cookie(24, 24, 12.2, { chips: [[17.5, 17, 1.2, 0], [30, 14, 1.2, 0.8], [32.5, 29.5, 1.2, 2], [19.5, 32, 1.2, 4]] })}`;
    },

    'vis:black_hole': () => {
      const rot = -16, rx = 19.4, ry = 6.6;
      const back = `<path d="M${24 - rx} 25A${rx} ${ry} 0 0 1 ${24 + rx} 25" transform="rotate(${rot} 24 25)" fill="none"`;
      const front = `<path d="M${24 - rx} 25A${rx} ${ry} 0 0 0 ${24 + rx} 25" transform="rotate(${rot} 24 25)" fill="none"`;
      const disk = (el) => `${el} stroke="${OL}" stroke-width="9" stroke-linecap="round"/>${el} stroke="url(#dk)" stroke-width="5.2" stroke-linecap="round"/>${el} stroke="#fff6c0" stroke-width="1.4" stroke-linecap="round" opacity=".85"/>`;
      return `<defs>${MK}${lgU('dk', ['#ff2bd6', '#ff8a1f', '#ffe14a', '#ff8a1f', '#b16bff'], 4, 0, 44, 0)}${rgM('hz', [[0, '#000', 1], [0.7, '#10061f', 1], [0.86, '#ff9a3c', 0.9], [1, '#ff2bd6', 0]])}</defs>
      <circle cx="24" cy="25" r="14" fill="url(#hz)"/>
      ${disk(back)}
      <circle cx="24" cy="25" r="9.6" fill="#07030f" ${st(3)}/>
      <path d="M16.6 20.5a9.6 9.6 0 0 1 12-4.8" fill="none" stroke="#ffb35c" stroke-width="1.6" stroke-linecap="round"/>
      ${disk(front)}
      <path d="M40 9.5Q33 7 29 12" fill="none" stroke="#ffe14a" stroke-width="1.8" stroke-linecap="round" stroke-dasharray="2 2.4" opacity=".8"/>
      ${mini(41, 8, 4.8, 2)}
      ${spark(6, 7, 2.8, '#fff', 1.2)}${spark(9, 43, 2.2, '#ff9af0', 1.1)}${spark(44, 42, 2, '#9ff6ff', 1)}`;
    },

    'vis:beat_pulse': () => `<defs>${lg('cab', '#6a4ec0', '#241446')}${rg('tw', '#ffffff', '#1ff4ff', 0.35, 0.3, 0.8)}</defs>
      ${[[15.8, 1], [20.6, 0.65]].map(([r, o]) => `<path d="${arcD(24, 29, r, 145, 215)}" fill="none" stroke="${OL}" stroke-width="5.6" stroke-linecap="round" opacity="${o}"/><path d="${arcD(24, 29, r, 145, 215)}" fill="none" stroke="#ff2bd6" stroke-width="2.6" stroke-linecap="round" opacity="${o}"/><path d="${arcD(24, 29, r, -35, 35)}" fill="none" stroke="${OL}" stroke-width="5.6" stroke-linecap="round" opacity="${o}"/><path d="${arcD(24, 29, r, -35, 35)}" fill="none" stroke="#1ff4ff" stroke-width="2.6" stroke-linecap="round" opacity="${o}"/>`).join('')}
      <rect x="12.5" y="4" width="23" height="40" rx="5" fill="url(#cab)" ${st(3)}/>
      ${shine('M15.5 9v8', 1.8, 0.5)}
      <circle cx="24" cy="12.4" r="4.4" fill="#1a1033" ${st(2)}/><circle cx="24" cy="12.4" r="2.3" fill="url(#tw)"/>
      <circle cx="24" cy="29" r="10" fill="#1a1033" ${st(2.4)}/>
      <circle cx="24" cy="29" r="9.4" fill="none" stroke="#b16bff" stroke-width="1.4" opacity=".9"/>
      ${cookie(24, 29, 7.4, { chips: [[17.5, 17, 1.4, 0], [30, 14.5, 1.4, 0.8], [30.5, 30, 1.4, 2], [18.5, 30.5, 1.4, 4]], w: 2.2 })}
      <g fill="#b6ff3b" ${st(1)}><circle cx="16" cy="41" r="1"/><circle cx="32" cy="41" r="1"/></g>`,
  });
})();
