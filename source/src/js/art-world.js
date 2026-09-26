/* COOKIE OVERDRIVE — art-world.js
 * World art: buildings (b:*), bosses (boss:*), pet eggs (egg:*),
 * minigame items (item:*) and minigame covers (mg:*).
 * Same contract as art.js: 48×48 box, #1a0b33 outline ≈3, vertical gradients, white gloss.
 */
(function () {
  'use strict';
  const A = CO.art, { OL, lg, rg, st, shine, blob, star, gear, P } = A.h;

  /* ───────── local helpers ───────── */
  const CHIP_D = ['M14.5 15.5l4-1.8 2.3 3.4-3 3.2-3.6-1.5z', 'M27.5 11.5l3.8.3.7 3.7-3.6 1.7-2.2-2.7z', 'M31 26l4.1.4.6 4.1-3.6 2.1-2.6-3.1z', 'M17.5 30l3.6-.6 1.6 3.6-2.6 2.6-3.6-2.1z', 'M23 21.3l2.7-1.5 2.1 2.1-1.1 3.1h-3.1z'];
  const ckDef = (id) => rg(id, '#ffe0a8', '#b86f2c', 0.35, 0.3, 0.85);
  /** a ui:cookie-style cookie of radius r at (cx,cy); gradient id must be declared with ckDef(id) */
  function cookie(id, cx, cy, r, sw = 2.6, gloss = true) {
    const k = r / 19.2;
    const amp = Math.max(0.55, 1.3 * k), n = r > 8 ? 18 : 14;
    const cw = P((0.3 + r * 0.06) / k);
    return `<path d="${blob(cx, cy, r, amp, n)}" fill="url(#${id})" ${st(sw)}/>
      <g transform="translate(${P(cx)} ${P(cy)}) scale(${P(k * 1000) / 1000}) translate(-24 -24)">
        <g fill="#4a2511" stroke="${OL}" stroke-width="${cw}" stroke-linejoin="round">${CHIP_D.map((d) => `<path d="${d}"/>`).join('')}</g>
        ${gloss ? `<path d="M11.5 14c1.8-2.4 4.2-3.9 6.8-4.6" fill="none" stroke="#fff" stroke-width="${P(Math.max(1.4, 2.4 * k) / k)}" stroke-linecap="round" opacity=".75"/>` : ''}
      </g>`;
  }
  /** a cookie without the standard chips (for cookies that wear a face) + free-placed chips */
  function cookieFace(id, cx, cy, r, chips, sw = 2.8) {
    const cs = chips.map(([x, y, s, a]) => `<path d="M-2.2-1.4l4-1.8 2.3 3.4-3 3.2-3.6-1.5z" transform="translate(${x} ${y}) rotate(${a || 0}) scale(${s})" stroke-width="${P(1.3 / s)}"/>`).join('');
    return `<path d="${blob(cx, cy, r, Math.max(0.55, (1.3 * r) / 19.2), 18)}" fill="url(#${id})" ${st(sw)}/>
      <g fill="#4a2511" stroke="${OL}" stroke-linejoin="round">${cs}</g>`;
  }
  /** chunky double-stroke line (dark outline + colored core) */
  const line2 = (d, c, w = 3, ow = 3) => `<path d="${d}" fill="none" stroke="${OL}" stroke-width="${w + ow * 2 - 1}" stroke-linecap="round" stroke-linejoin="round"/><path d="${d}" fill="none" stroke="${c}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;
  /** 4-point sparkle */
  const spark = (x, y, R, fill = '#fff', w = 1.5) => `<path d="${star(x, y, R, R * 0.34, 4, 0)}" fill="${fill}" ${st(w)}/>`;
  /** angry eyebrows pair: inner ends low */
  const brows = (lx, rx, y, span = 7, drop = 2.8, w = 3.4) => `<path d="M${P(lx - span / 2)} ${P(y - drop / 2)}L${P(lx + span / 2)} ${P(y + drop / 2)}M${P(rx + span / 2)} ${P(y - drop / 2)}L${P(rx - span / 2)} ${P(y + drop / 2)}" fill="none" stroke="${OL}" stroke-width="${w}" stroke-linecap="round"/>`;
  /** eye: white with pupil + glint (pupil color c) */
  const eye = (x, y, rx, ry, c = OL, pr = 1.9, dx = 0.4, dy = 0.5) => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="#fff" ${st(2)}/><circle cx="${P(x + dx)}" cy="${P(y + dy)}" r="${pr}" fill="${c}"/><circle cx="${P(x + dx - pr * 0.35)}" cy="${P(y + dy - pr * 0.4)}" r="${P(pr * 0.36)}" fill="#fff"/>`;
  const EGG = 'M24 3.5C14.5 3.5 7.5 17.5 7.5 28.5C7.5 38 14.5 44.5 24 44.5S40.5 38 40.5 28.5C40.5 17.5 33.5 3.5 24 3.5Z';

  A.register({
    /* ═════════════════════════ BUILDINGS ═════════════════════════ */
    'b:granny': () => `<defs>${lg('s', '#ffe8d6', '#f2a883')}${lg('h', '#ffffff', '#a79fc6')}${lg('c', '#ff2bd6', '#1ff4ff')}</defs>
      <circle cx="24" cy="8.6" r="5.6" fill="url(#h)" ${st(3)}/>${shine('M20.6 7.4a3.6 3.6 0 0 1 2.4-2.4', 1.6, 0.85)}
      <ellipse cx="24" cy="28.4" rx="14" ry="14.6" fill="url(#s)" ${st(3.2)}/>
      <path d="M10.3 27.6C9.3 17.6 15.5 11.8 24 11.8S38.7 17.6 37.7 27.6C36.3 23 33.4 20.4 30 20.9 28 18.9 25.6 18.7 24 20.3 22.4 18.7 20 18.9 18 20.9 14.6 20.4 11.7 23 10.3 27.6Z" fill="url(#h)" ${st(3)}/>
      <path d="M8.8 27C8.8 7.6 39.2 7.6 39.2 27" fill="none" stroke="${OL}" stroke-width="7.2" stroke-linecap="round"/>
      <path d="M8.8 27C8.8 7.6 39.2 7.6 39.2 27" fill="none" stroke="#8a5cff" stroke-width="3.4" stroke-linecap="round"/>
      <path d="M14 15.5c2.6-2.3 5.6-3.4 9-3.6" fill="none" stroke="#d4c4ff" stroke-width="1.4" stroke-linecap="round"/>
      <path d="M9.4 33.2Q10.2 39.8 17 39.6" fill="none" stroke="${OL}" stroke-width="2.6" stroke-linecap="round"/>
      <rect x="3.8" y="20.6" width="9.6" height="14" rx="4.3" fill="url(#c)" ${st(3)}/><rect x="34.6" y="20.6" width="9.6" height="14" rx="4.3" fill="url(#c)" ${st(3)}/>
      <rect x="6.3" y="23.2" width="2.6" height="8.4" rx="1.3" fill="#fff" opacity=".6"/><rect x="37.1" y="23.2" width="2.6" height="8.4" rx="1.3" fill="#fff" opacity=".6"/>
      <circle cx="18" cy="39.4" r="2.4" fill="#b6ff3b" ${st(1.8)}/>
      <ellipse cx="14.9" cy="34" rx="2.7" ry="1.8" fill="#ff5f9e" opacity=".7"/><ellipse cx="33.1" cy="34" rx="2.7" ry="1.8" fill="#ff5f9e" opacity=".7"/>
      <circle cx="18.8" cy="28.6" r="1.8" fill="${OL}"/><circle cx="29.2" cy="28.6" r="1.8" fill="${OL}"/><circle cx="19.4" cy="27.9" r=".6" fill="#fff"/><circle cx="29.8" cy="27.9" r=".6" fill="#fff"/>
      <g fill="#dff9ff" fill-opacity=".35" ${st(2.2)}><circle cx="18.6" cy="28.2" r="4.6"/><circle cx="29.4" cy="28.2" r="4.6"/></g>
      <path d="M23.2 27.6q.8-.9 1.6 0" fill="none" ${st(2)}/>
      <path d="M22.9 31.9q1.1.9 2.2 0" fill="none" ${st(1.6)}/>
      <path d="M20.4 35.6q3.6 3.8 7.2 0" fill="#ff7a8a" ${st(2.2)}/>`,

    'b:farm': () => `<defs>${lg('w', '#ff7a6b', '#c8182f')}${lg('r', '#9b86f0', '#3f2a8f')}${lg('g', '#fff27a', '#e59a00')}${lg('k', '#fff6b0', '#f0a800')}</defs>
      <g fill="none" stroke="${OL}" stroke-width="2.2" stroke-linecap="round"><path d="M37.4 39V21M42.2 39l-.9-12.5"/></g>
      <g transform="translate(37.4 15.5) rotate(-6)"><path d="M0-9.5C3.6-6.5 3.6 5 0 8.5-3.6 5-3.6-6.5 0-9.5z" fill="url(#k)" ${st(2.2)}/><path d="M-2 -4.3l2 1.6 2-1.6M-2.2 .2l2.2 1.7 2.2-1.7M-1.8 4.6l1.8 1.4 1.8-1.4" fill="none" stroke="${OL}" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round" opacity=".55"/></g>
      <g transform="translate(41.2 22.5) rotate(10)"><path d="M0-7.5C3-5 3 4 0 7-3 4-3-5 0-7.5z" fill="url(#k)" ${st(2.1)}/><path d="M-1.7 -2.6l1.7 1.4 1.7-1.4M-1.7 1.5l1.7 1.4 1.7-1.4" fill="none" stroke="${OL}" stroke-width="1.1" stroke-linecap="round" stroke-linejoin="round" opacity=".55"/></g>
      <rect x="6.5" y="19" width="22.5" height="23" fill="url(#w)" ${st(3)}/>
      <path d="M3.5 21.5L9 11.2 17.75 5.2 26.5 11.2 32 21.5z" fill="url(#r)" ${st(3.1)}/>
      <path d="M7.2 19.6L10.8 12.8 17.75 8 24.7 12.8 28.3 19.6" fill="none" stroke="#fff" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round" opacity=".9"/>
      <circle cx="17.75" cy="15" r="2.8" fill="#ffe07a" ${st(2)}/>
      <rect x="11.5" y="26.5" width="12.5" height="13.5" fill="#ffeede" ${st(2.4)}/><rect x="13.6" y="28.6" width="8.3" height="9.3" fill="#b3122e"/>
      <path d="M13.6 28.6l8.3 9.3M21.9 28.6l-8.3 9.3" stroke="#ffeede" stroke-width="1.8"/>
      <path d="M3 44.5V41.6Q3 38.4 7 38.6Q18 39.6 27 38.2Q35.5 36.2 41 36.4Q45 36.8 45 40V44.5Z" fill="url(#g)" ${st(3)}/>
      <path d="M6 42.2Q20 42.6 30 41.2T43 39.4" fill="none" stroke="#c98a00" stroke-width="1.4" stroke-linecap="round"/>
      <g fill="#6b3514" ${st(1.1)}><path d="M8.5 40.4l1.7-.7.9 1.3-1.2 1.2-1.4-.5z"/><path d="M19 43l1.7-.6.9 1.3-1.2 1.1-1.5-.6z"/><path d="M27.5 40.2l1.6-.8 1 1.2-1.1 1.3-1.5-.5z"/><path d="M37.5 41.8l1.6-.7 1 1.3-1.2 1.1-1.4-.5z"/></g>
      ${shine('M8.5 24v10', 2, 0.55)}`,

    'b:mine': () => `<defs>${lg('r', '#cfc2f5', '#5a468e')}${lg('c', '#c07a46', '#4a2511')}${lg('h', '#ffd9a0', '#9a5a26', 1, 0)}${lg('m', '#ffffff', '#8fa0e8')}${lg('g', '#fff27a', '#e59a00')}</defs>
      <path d="M5.5 42L8 31 16.5 23.5 29.5 21 40.5 27 44 38.5 41 44.5H8.5Q5.5 44.5 5.5 42Z" fill="url(#r)" ${st(3.2)}/>
      <path d="M16.5 23.5L20 31H8M20 31L29.5 21M20 31L28.5 44.5M29.5 21L33 32 44 38.5M33 32L28.5 44.5" fill="none" stroke="${OL}" stroke-width="1.5" stroke-linejoin="round" opacity=".3"/>
      <g fill="url(#c)" ${st(2)}><path d="M10.5 35.5l4.2-3.4 5.2 1.6.4 5-4.6 3-4.8-2z"/><path d="M31.3 25.2l4.6-1 3.2 3.6-2.1 4.1-4.7-.5z"/><path d="M30.8 36.8l4.2-2.6 4.6 2.1-.5 4.5-4.6 1.5-3.6-2.6z"/></g>
      <g fill="none" stroke="#fff" stroke-width="1.3" stroke-linecap="round" opacity=".7"><path d="M12.5 35.4l2.2-1.7"/><path d="M33 25.9l2.4-.5"/><path d="M32.6 36.6l2.1-1.3"/></g>
      ${spark(40.5, 12, 4.2, '#fff6b0', 1.4)}
      <g transform="translate(28 14) rotate(45)">
        <rect x="-2.5" y="1.5" width="5" height="29.5" rx="2.5" fill="url(#h)" ${st(2.6)}/>
        <path d="M-15.5 6Q0-13 15.5 6Q0-1 -15.5 6Z" fill="url(#m)" ${st(2.8)}/>
        <path d="M-10 -.2Q0-6.4 10-.2" fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round" opacity=".85"/>
        <rect x="-3.9" y="-4.6" width="7.8" height="9.2" rx="2" fill="url(#g)" ${st(2.4)}/>
      </g>`,

    'b:factory': () => `<defs>${lg('b', '#8472f5', '#2e1a7a')}${lg('k', '#ff8ae8', '#c5118f')}${ckDef('ck')}</defs>
      <rect x="34.5" y="4.5" width="7.5" height="18" rx="1.6" fill="url(#k)" ${st(3)}/>
      <rect x="34.5" y="8.6" width="7.5" height="3" fill="#1ff4ff" ${st(1.8)}/>
      <path d="M4 38V22L14 14V22L24 14V22L34 14V22H44V38Z" fill="url(#b)" ${st(3.2)}/>
      <path d="M7 21.2L12 17.2M17 21.2L22 17.2M27 21.2L32 17.2" stroke="#8ffbff" stroke-width="2.4" stroke-linecap="round"/>
      <rect x="7.5" y="25" width="6.5" height="5.8" rx="1.3" fill="#ff5ef0" ${st(2)}/><rect x="17" y="25" width="6.5" height="5.8" rx="1.3" fill="#b6ff3b" ${st(2)}/>
      <path d="M36 25.5h5M37 28.5h4" stroke="#1ff4ff" stroke-width="1.8" stroke-linecap="round" opacity=".9"/>
      <rect x="3" y="37.5" width="42" height="7" rx="3.5" fill="#3a2766" ${st(3)}/>
      <g fill="#8ffbff" ${st(1.3)}><circle cx="8" cy="41" r="1.6"/><circle cx="14.5" cy="41" r="1.6"/><circle cx="21" cy="41" r="1.6"/><circle cx="27.5" cy="41" r="1.6"/><circle cx="34" cy="41" r="1.6"/><circle cx="40.5" cy="41" r="1.6"/></g>
      <path d="M19 33.5h4.5M16.5 30.2h4" stroke="#fff" stroke-width="1.8" stroke-linecap="round" opacity=".75"/>
      ${cookie('ck', 30.5, 30.8, 6.8, 2.4)}
      ${shine('M7.5 34.5v-2', 1.8, 0.5)}`,

    'b:bank': () => `<defs>${ckDef('ck')}${lg('m', '#ffffff', '#c7baf5')}${lg('p', '#ffb8f0', '#d0339f')}${rg('c', '#fff6b8', '#e09a00', 0.35, 0.3, 0.85)}</defs>
      <path d="M3.5 17.5L24 4.5l20.5 13z" fill="url(#p)" ${st(3.2)}/>
      <path d="M11.5 15.2L24 7.6l12.5 7.6" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" opacity=".6"/>
      <circle cx="24" cy="12.8" r="2.4" fill="#1ff4ff" ${st(1.6)}/>
      <rect x="5" y="17" width="38" height="5" rx="1.3" fill="url(#m)" ${st(3)}/>
      <g fill="url(#m)" ${st(2.4)}><rect x="8" y="22" width="5" height="14.5"/><rect x="16.5" y="22" width="5" height="14.5"/><rect x="25" y="22" width="5" height="14.5"/><rect x="33.5" y="22" width="5" height="14.5"/></g>
      <g stroke="${OL}" stroke-width="1.1" opacity=".3"><path d="M10.5 24v10.5M19 24v10.5M27.5 24v10.5M36 24v10.5"/></g>
      <rect x="4.5" y="36" width="39" height="4" rx="1.2" fill="url(#m)" ${st(3)}/>
      <rect x="2.5" y="40" width="43" height="4.5" rx="1.6" fill="url(#m)" ${st(3)}/>
      <circle cx="35.2" cy="34.6" r="9" fill="url(#c)" ${st(3)}/>
      <circle cx="35.2" cy="34.6" r="6.2" fill="none" stroke="#b36b00" stroke-width="1.4"/>
      ${cookie('ck', 35.2, 34.6, 4.9, 1.6, false)}
      ${shine('M29.6 31.6a6.5 6.5 0 0 1 3-3', 1.8, 0.9)}`,

    'b:temple': () => `<defs>${lg('g', '#fff27a', '#e59a00')}${lg('w', '#ff8ae8', '#c5118f')}${ckDef('ck')}</defs>
      <path d="M24 10V5" stroke="${OL}" stroke-width="4.6" stroke-linecap="round"/><path d="M24 10V5" stroke="#ffc400" stroke-width="1.8" stroke-linecap="round"/>
      <circle cx="24" cy="4.2" r="2.3" fill="url(#g)" ${st(1.8)}/>
      <rect x="16.5" y="15.5" width="15" height="7" fill="url(#w)" ${st(2.6)}/>
      <path d="M9.5 16.2Q15.5 15.4 19 8.6H29Q32.5 15.4 38.5 16.2Q39.6 18.8 37 18.8H11Q8.4 18.8 9.5 16.2Z" fill="url(#g)" ${st(3)}/>
      <rect x="9.5" y="27" width="29" height="14" fill="url(#w)" ${st(3)}/>
      <g stroke="${OL}" stroke-width="1.6" opacity=".35"><path d="M13.5 31v9M34.5 31v9"/></g>
      <path d="M3.5 27.4Q12 26.2 16.5 20.2H31.5Q36 26.2 44.5 27.4Q45.6 30.6 42.4 30.6H5.6Q2.4 30.6 3.5 27.4Z" fill="url(#g)" ${st(3)}/>
      ${shine('M10 27.4q5.5-1.4 8.4-5.4', 1.8, 0.8)}${shine('M14.2 16.3q4-1.3 5.8-5', 1.6, 0.8)}
      <circle cx="24" cy="35.4" r="6.6" fill="#ffe27a" ${st(2.2)}/>
      ${cookie('ck', 24, 35.4, 4.8, 1.8, false)}
      <rect x="5" y="40.2" width="38" height="4.8" rx="1.6" fill="url(#g)" ${st(3)}/>`,

    'b:wizard': () => `<defs>${lg('h', '#c0a4ff', '#5a22d6')}${lg('g', '#fff27a', '#e59a00')}${lg('s', '#fff9c8', '#ffc93c')}</defs>
      <ellipse cx="21.5" cy="38.5" rx="18.5" ry="5.6" fill="url(#h)" ${st(3.2)}/>
      <path d="M9.5 38C12 30 15 19 20.5 11C23.5 6.6 29.5 3.6 35.5 5.6C31 7.1 28.6 10.2 28.6 15.6C28.6 23 30.8 30.5 33.6 38Q21.5 41.6 9.5 38Z" fill="url(#h)" ${st(3.2)}/>
      ${shine('M15 29c1.6-6 3.6-11.4 6.6-15.6', 2.2, 0.55)}
      <path d="M11.3 32.3Q21.5 35.6 31.6 32.3L33.5 37.9Q21.5 41.4 9.7 37.9Z" fill="url(#g)" ${st(2.6)}/>
      <rect x="19" y="33.4" width="5.2" height="4.6" rx="1" fill="none" stroke="${OL}" stroke-width="1.6"/>
      <path d="${star(21.5, 22.8, 3.9, 1.6)}" fill="url(#s)" ${st(1.5)}/>
      <path d="${star(26.5, 14.2, 2.6, 1.1)}" fill="url(#s)" ${st(1.3)}/>
      <path d="M16.6 30.2a3.2 3.2 0 1 0 2.2-4.8 2.6 2.6 0 1 1-2.2 4.8z" fill="#8ffbff" ${st(1.3)}/>
      <path d="M34.6 43.4L40.6 29" stroke="${OL}" stroke-width="5.8" stroke-linecap="round"/><path d="M34.6 43.4L40.6 29" stroke="#3a2766" stroke-width="2.4" stroke-linecap="round"/><path d="M39.2 32.4L40.6 29" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/>
      <path d="${star(41.2, 23.6, 5, 1.7, 4, 0)}" fill="url(#s)" ${st(1.6)}/>
      <circle cx="45" cy="18.5" r="1.1" fill="#fff"/><circle cx="36.2" cy="20.6" r=".9" fill="#fff"/>`,

    'b:rocket': () => `<defs>${lg('b', '#ffffff', '#b9aff0', 1, 0)}${lg('k', '#ff8ae8', '#c5118f', 1, 0)}${lg('w', '#d8fdff', '#1fb8e0')}${lg('f', '#fff6a0', '#ff4d00')}</defs>
      ${spark(9.5, 9.5, 4, '#fff', 1.3)}${spark(40.5, 39.5, 3.2, '#8ffbff', 1.2)}<circle cx="6" cy="24" r="1.1" fill="#fff" opacity=".8"/><circle cx="24" cy="6" r="1" fill="#fff" opacity=".7"/>
      <g transform="rotate(45 24 24)">
        <path d="M19 33C19 39 22 42 24 46C26 42 29 39 29 33Z" fill="url(#f)" ${st(2.6)}/>
        <path d="M21.6 34C21.6 38 23 40.2 24 42.4C25 40.2 26.4 38 26.4 34Z" fill="#fff6a8"/>
        <path d="M16.6 22L9.6 30.5V36.5L16.6 32Z" fill="url(#k)" ${st(2.8)}/><path d="M31.4 22L38.4 30.5V36.5L31.4 32Z" fill="url(#k)" ${st(2.8)}/>
        <rect x="18.5" y="30" width="11" height="4.6" rx="1.6" fill="#8d7ad0" ${st(2.6)}/>
        <path d="M24 3C31 8 33 17 32 31H16C15 17 17 8 24 3Z" fill="url(#b)" ${st(3.2)}/>
        <path d="M24 3C28.3 6 30.5 10 31.5 14H16.5C17.5 10 19.7 6 24 3Z" fill="url(#k)" ${st(2.6)}/>
        <path d="M24 26.5V31" stroke="${OL}" stroke-width="3.4" stroke-linecap="round"/>
        <circle cx="24" cy="20.5" r="4.6" fill="url(#w)" ${st(2.8)}/>
        <path d="M21.8 19.2a2.6 2.6 0 0 1 2-1.6" fill="none" stroke="#fff" stroke-width="1.4" stroke-linecap="round"/>
        ${shine('M19 17.5v10', 1.9, 0.8)}
      </g>`,

    'b:lab': () => `<defs>${lg('gl', '#ffffff', '#9fe8ff')}${lg('p', '#efffa6', '#3fcf00')}${lg('n', '#a98bff', '#3a2766')}<clipPath id="cl"><circle cx="24" cy="30.5" r="13.5"/></clipPath></defs>
      <circle cx="24" cy="30" r="16.2" fill="#b6ff3b" opacity=".16"/>
      <path d="M19.5 7V17.8A13.5 13.5 0 1 0 28.5 17.8V7Z" fill="url(#gl)" fill-opacity=".6"/>
      <g clip-path="url(#cl)">
        <path d="M8 28.6Q12 26 16 28.2T24 28.2T32 28.2T40 28.2V46H8Z" fill="url(#p)"/>
        <path d="M8 28.6Q12 26 16 28.2T24 28.2T32 28.2T40 28.2" fill="none" stroke="${OL}" stroke-width="1.8" opacity=".55"/>
        <g fill="#fff" opacity=".75"><circle cx="18" cy="35" r="1.8"/><circle cx="29" cy="38.5" r="1.3"/><circle cx="26" cy="32.5" r="1"/><circle cx="21.5" cy="40.5" r="1"/></g>
      </g>
      <path d="M19.5 7V17.8A13.5 13.5 0 1 0 28.5 17.8V7Z" fill="none" ${st(3.2)}/>
      ${shine('M14.2 26.5a10.5 10.5 0 0 0-.3 7.5', 2.4, 0.85)}${shine('M21.6 10v5', 1.6, 0.7)}
      <g fill="#dfff8a" ${st(1.6)}><circle cx="25.3" cy="21.4" r="1.9"/><circle cx="22.7" cy="15.8" r="1.4"/><circle cx="34.5" cy="10.5" r="2.2"/><circle cx="38.5" cy="5" r="1.5"/></g>
      <rect x="16.8" y="3.4" width="14.4" height="5" rx="2.5" fill="url(#n)" ${st(2.8)}/>`,

    'b:portal': () => {
      const arms = [0, 120, 240].map((a) => `<path d="M24 24C24 18.4 28 14.8 34.6 15.8" transform="rotate(${a} 24 24)"/>`).join('');
      const arms2 = [60, 180, 300].map((a) => `<path d="M24 24C24 19.6 26.8 16.8 31.6 17.2" transform="rotate(${a} 24 24)"/>`).join('');
      const studs = Array.from({ length: 8 }, (_, i) => { const a = (i / 8) * Math.PI * 2 - Math.PI / 2; return `<circle cx="${P(24 + Math.cos(a) * 17.3)}" cy="${P(24 + Math.sin(a) * 17.3)}" r="1.9" fill="${i % 2 ? '#1ff4ff' : '#ff2bd6'}" ${st(1.4)}/>`; }).join('');
      return `<defs>${lg('r', '#dcc2ff', '#5b22d0')}<radialGradient id="v" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#ffffff"/><stop offset=".28" stop-color="#8ffbff"/><stop offset=".68" stop-color="#8a5cff"/><stop offset="1" stop-color="#25085a"/></radialGradient></defs>
      <circle cx="24" cy="24" r="21" fill="#8a5cff" opacity=".22"/>
      <circle cx="24" cy="24" r="20.3" fill="url(#r)" ${st(3.2)}/>
      ${studs}
      <circle cx="24" cy="24" r="14" fill="url(#v)" ${st(2.6)}/>
      <g fill="none" stroke="#fff" stroke-width="2.3" stroke-linecap="round" opacity=".85">${arms}</g>
      <g fill="none" stroke="#1ff4ff" stroke-width="1.8" stroke-linecap="round" opacity=".9">${arms2}</g>
      <circle cx="24" cy="24" r="2.6" fill="#fff"/>
      ${shine('M9.2 17.5a16 16 0 0 1 6.3-7.6', 2.4, 0.8)}`;
    },

    'b:timemachine': () => `<defs>${lg('gl', '#ffffff', '#9fe8ff')}${lg('g', '#fff27a', '#d98a00')}${lg('s', '#fffac0', '#ff9d00')}${lg('p', '#c0a4ff', '#5a22d6')}</defs>
      <ellipse cx="24" cy="24" rx="12" ry="16" fill="#ffc93c" opacity=".22"/>
      <path d="M14.5 8.5C14.5 17 21.5 20 22.3 24C21.5 28 14.5 31 14.5 39.5H33.5C33.5 31 26.5 28 25.7 24C26.5 20 33.5 17 33.5 8.5Z" fill="url(#gl)" fill-opacity=".55"/>
      <path d="M16.8 14.2H31.2C30 18.4 26.2 20.8 24 23.6C21.8 20.8 18 18.4 16.8 14.2Z" fill="url(#s)"/>
      <path d="M24 23.2V34" stroke="#ffb000" stroke-width="1.6" stroke-linecap="round"/>
      <path d="M16.2 39.4C17.4 33.6 21 31.4 24 31.4S30.6 33.6 31.8 39.4Z" fill="url(#s)"/>
      <g fill="#fff"><circle cx="21" cy="16.4" r=".8"/><circle cx="27.6" cy="16" r=".7"/><circle cx="23" cy="35.4" r=".8"/></g>
      <path d="M14.5 8.5C14.5 17 21.5 20 22.3 24C21.5 28 14.5 31 14.5 39.5H33.5C33.5 31 26.5 28 25.7 24C26.5 20 33.5 17 33.5 8.5Z" fill="none" ${st(2.8)}/>
      ${shine('M17.4 11c.2 3 1.5 5.2 3.4 6.9', 1.8, 0.85)}
      <rect x="8.4" y="7" width="4.4" height="34" rx="2" fill="url(#p)" ${st(2.6)}/><rect x="35.2" y="7" width="4.4" height="34" rx="2" fill="url(#p)" ${st(2.6)}/>
      <g stroke="${OL}" stroke-width="1.2" opacity=".4"><path d="M8.6 15.5l4 2M8.6 22.5l4 2M8.6 29.5l4 2M35.4 15.5l4 2M35.4 22.5l4 2M35.4 29.5l4 2"/></g>
      <rect x="5" y="3.5" width="38" height="6" rx="3" fill="url(#g)" ${st(3)}/>
      <rect x="5" y="38.5" width="38" height="6" rx="3" fill="url(#g)" ${st(3)}/>
      <circle cx="24" cy="6.5" r="1.9" fill="#ff2bd6" ${st(1.4)}/><circle cx="24" cy="41.5" r="1.9" fill="#1ff4ff" ${st(1.4)}/>
      ${shine('M9 5.6h9', 1.5, 0.7)}`,

    'b:antimatter': () => {
      const rot = [0, 60, 120], cols = ['#1ff4ff', '#b6ff3b', '#ff5ef0'];
      const el = (a, extra) => `<ellipse cx="24" cy="24" rx="19.4" ry="7.4" transform="rotate(${a} 24 24)" ${extra}/>`;
      const ep = (a, t) => { const x = Math.cos(t) * 19.4, y = Math.sin(t) * 7.4, r = (a * Math.PI) / 180; return [P(24 + x * Math.cos(r) - y * Math.sin(r)), P(24 + x * Math.sin(r) + y * Math.cos(r))]; };
      const elec = [[0, -0.35], [60, 2.6], [120, -2.4]].map(([a, t]) => { const [x, y] = ep(a, t); return `<circle cx="${x}" cy="${y}" r="2.5" fill="#fff" ${st(1.8)}/>`; }).join('');
      return `<defs>${rg('n', '#ffffff', '#ff2bd6', 0.38, 0.32, 0.8)}</defs>
      <circle cx="24" cy="24" r="12" fill="#ff2bd6" opacity=".22"/>
      <g fill="none" stroke="${OL}" stroke-width="6">${rot.map((a) => el(a, '')).join('')}</g>
      ${rot.map((a, i) => el(a, `fill="none" stroke="${cols[i]}" stroke-width="2.7"`)).join('')}
      ${elec}
      <circle cx="24" cy="24" r="6.6" fill="url(#n)" ${st(3)}/>
      <path d="M21 21.8a3.6 3.6 0 0 1 2.4-1.6" fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round"/>`;
    },

    'b:prism': () => {
      const E = [29.3, 24], X = 43.6, ys = [13, 17.6, 22.2, 26.8, 31.4, 36, 40.6];
      const cols = ['#ff3d6e', '#ff9a1f', '#ffe23c', '#3dff7a', '#2bb8ff', '#b16bff'];
      const bands = cols.map((c, i) => `<path d="M${E[0]} ${E[1]}L${X} ${ys[i]}V${ys[i + 1]}Z" fill="${c}"/>`).join('');
      return `<defs>${lg('p', '#ffffff', '#9fdcff')}</defs>
      <path d="M${E[0]} ${E[1]}L${X} ${ys[0]}V${ys[6]}Z" fill="none" stroke="${OL}" stroke-width="5" stroke-linejoin="round"/>
      ${bands}
      ${line2('M4.6 28.8L15 24.4', '#fff', 3, 2.6)}
      <path d="M22 6L35.2 36.4Q36.2 39 33.4 39H10.6Q7.8 39 8.8 36.4Z" fill="url(#p)" fill-opacity=".92" ${st(3.2)}/>
      <path d="M22 6L25 39" stroke="${OL}" stroke-width="1.6" opacity=".3"/>
      <path d="M15 24.4L29.3 24" stroke="#fff" stroke-width="2.2" stroke-linecap="round" opacity=".9"/>
      ${shine('M19.2 12.6L12.6 28', 2.4, 0.9)}
      ${spark(8.5, 10, 3.6, '#fff', 1.3)}`;
    },

    'b:streamer': () => `<defs>${lg('f', '#9b86f0', '#3f2a8f')}${lg('s', '#ff2bd6', '#1ff4ff', 1, 1)}${lg('r', '#ff7a8a', '#d0102f')}${lg('m', '#efe8ff', '#8d7ad0')}</defs>
      <path d="M20 34.5L18 41H30L28 34.5Z" fill="url(#m)" ${st(2.6)}/>
      <rect x="12.5" y="40" width="23" height="4.6" rx="2.3" fill="url(#m)" ${st(2.8)}/>
      <rect x="3.5" y="8.5" width="41" height="27.5" rx="4.5" fill="url(#f)" ${st(3.2)}/>
      <rect x="7.2" y="12.2" width="33.6" height="20.2" rx="2.2" fill="url(#s)" ${st(2.2)}/>
      <path d="M9.5 14.6l7-.1M9.6 17.4l3.6-.1" stroke="#fff" stroke-width="1.6" stroke-linecap="round" opacity=".55"/>
      <path d="M21 17.2c0-1.3 1.4-2.1 2.5-1.4l6.8 4.3c1 .7 1 2.2 0 2.8l-6.8 4.3c-1.1.7-2.5-.1-2.5-1.4z" fill="#fff" ${st(2.2)}/>
      <rect x="19" y="3" width="10" height="6.4" rx="3.2" fill="url(#m)" ${st(2.4)}/><circle cx="24" cy="6.2" r="1.7" fill="${OL}"/><circle cx="24.5" cy="5.7" r=".55" fill="#fff"/>
      <rect x="2.4" y="27.6" width="17.2" height="8.4" rx="3" fill="url(#r)" ${st(2.4)}/>
      <circle cx="5.9" cy="31.8" r="1.5" fill="#fff"/>
      <path d="M9 30v3.6h1.9M12.3 30v3.6M13.7 30l1.1 3.6 1.1-3.6M18.4 30h-1.6v3.6h1.6M16.8 31.8h1.3" fill="none" stroke="#fff" stroke-width="1.1" stroke-linecap="round" stroke-linejoin="round"/>`,

    /* ═════════════════════════ BOSSES ═════════════════════════ */
    'boss:broccoli': () => {
      const fl = [[12.5, 20, 7.6], [24, 15.5, 8.8], [35.5, 20, 7.6], [9.8, 27.6, 5], [38.2, 27.6, 5], [18, 25, 7], [30, 25, 7]];
      return `<defs>${lg('f', '#9dff72', '#1c9438')}${lg('s', '#ecffb8', '#7cd648')}${lg('g', '#fff27a', '#e59a00')}</defs>
      <path d="M13.2 27Q13.8 37.5 10.6 42.4Q9.8 45 12.8 45H35.2Q38.2 45 37.4 42.4Q34.2 37.5 34.8 27Z" fill="url(#s)" ${st(3.2)}/>
      <g fill="${OL}" stroke="${OL}" stroke-width="6">${fl.map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}"/>`).join('')}</g>
      <g fill="url(#f)">${fl.map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}"/>`).join('')}</g>
      <g fill="none" stroke="${OL}" stroke-width="1.4" opacity=".35"><path d="M17.8 18.5a7.6 7.6 0 0 1 1.5 5.2M29.8 18.5a7.6 7.6 0 0 0-1.4 5.2M12 26.4a5.2 5.2 0 0 0 1.8 2.8"/></g>
      <g fill="#c8ff9a" opacity=".85"><circle cx="21" cy="11.8" r="1.4"/><circle cx="25.5" cy="10.2" r="1"/><circle cx="10" cy="17.2" r="1.2"/><circle cx="33.6" cy="16" r="1.2"/><circle cx="16.4" cy="22.6" r=".9"/><circle cx="28.4" cy="22" r=".9"/></g>
      ${shine('M18.6 10.4a8 8 0 0 1 4.2-2.3', 2.2, 0.85)}
      <g transform="translate(24.5 7.2) rotate(-8)"><path d="M-7 3.4L-8 -3.4-3.6-.4 0-5.2 3.6-.4 8-3.4 7 3.4Z" fill="url(#g)" ${st(2.2)}/><circle cx="0" cy="1.3" r="1.3" fill="#ff2bd6"/></g>
      ${eye(19.2, 33.4, 3.3, 3.5, '#d0102f', 1.9, 0.6, 0.5)}${eye(28.8, 33.4, 3.3, 3.5, '#d0102f', 1.9, -0.6, 0.5)}
      ${brows(18.8, 29.2, 29.4, 7.4, 3, 3.2)}
      <path d="M19.2 41.4Q24 37.6 28.8 41.4Z" fill="${OL}" ${st(2.2)}/><path d="M21.4 40.1l1 1.5 1-1.9zM26.6 40.1l-1 1.5-1-1.9z" fill="#fff"/>`;
    },

    'boss:dentist': () => `<defs>${lg('gd', '#fff27a', '#e59a00')}${lg('t', '#ffffff', '#b8d2f5')}${lg('m', '#ffffff', '#7fe3ff')}${lg('b', '#8a5cff', '#3a2766')}</defs>
      <path d="M8.5 15C8.5 7 15.5 4.5 19.5 6.5Q24 9 28.5 6.5C32.5 4.5 39.5 7 39.5 15C39.5 21.5 37.2 25.5 36.1 31.2C35 38.2 34.2 44.6 30.6 44.6C27 44.6 27.6 36.8 24 36.8S21 44.6 17.4 44.6C13.8 44.6 13 38.2 11.9 31.2C10.8 25.5 8.5 21.5 8.5 15Z" fill="url(#t)" ${st(3.2)}/>
      ${shine('M12 13.5c.3-3 2-5 4.6-5.6', 2.4, 0.9)}
      <path d="M9.2 14.2Q24 19.2 38.8 14.2" fill="none" stroke="${OL}" stroke-width="5.6" stroke-linecap="round"/><path d="M9.2 14.2Q24 19.2 38.8 14.2" fill="none" stroke="url(#b)" stroke-width="2.4" stroke-linecap="round"/>
      <g transform="rotate(-22 15.6 11.4)"><ellipse cx="15.6" cy="11.4" rx="7" ry="6" fill="url(#gd)" ${st(2.8)}/>
      <ellipse cx="15.6" cy="11.4" rx="4.9" ry="4" fill="url(#m)" stroke="${OL}" stroke-width="1.3"/>
      <path d="M12.6 12.4l3.6-3.6M14.6 13.8l2.8-2.8" stroke="#fff" stroke-width="1.3" stroke-linecap="round"/></g>
      ${eye(18.4, 24.4, 3.3, 3.4, '#d0102f', 1.8, 0.6, 0.6)}${eye(29.6, 24.4, 3.3, 3.4, '#d0102f', 1.8, -0.6, 0.6)}
      ${brows(18, 30, 19.9, 7, 3.2, 3.2)}
      <path d="M16.2 29.4Q24 36.6 31.8 29.4Q24 32.4 16.2 29.4Z" fill="${OL}" ${st(2)}/>
      <path d="M19.6 30.9l1.4 2 1.3-1.6zM25.7 31.3l1.3 1.6 1.4-2z" fill="#fff"/>
      ${spark(41.5, 6.5, 3.4, '#fff', 1.3)}`,

    'boss:salad': () => `<defs>${lg('l', '#e6ffa0', '#39b52a')}${lg('b', '#ffffff', '#aa9ae8')}${rg('t', '#ff9a8a', '#e0102f', 0.35, 0.3, 0.8)}</defs>
      <path d="${blob(12, 20.5, 8.6, 1.3, 16, 0.2)}" fill="url(#l)" ${st(3)}/>
      <path d="${blob(36, 20.5, 8.6, 1.3, 16, 0.4)}" fill="url(#l)" ${st(3)}/>
      <path d="${blob(24, 14.2, 10.2, 1.4, 18)}" fill="url(#l)" ${st(3)}/>
      <g fill="none" stroke="#f6ffd6" stroke-width="1.4" stroke-linecap="round" opacity=".85"><path d="M24 22V9.5M24 15.5l-3.6-3.4M24 18.5l3.8-3.4M11 25l2-8.5M35.8 25l-1.2-8"/></g>
      <circle cx="31.4" cy="17.4" r="4.6" fill="url(#t)" ${st(2.2)}/><path d="M29.6 13.6l1.8 1.4 1.8-1.4" fill="none" stroke="#2e9a2a" stroke-width="1.5" stroke-linecap="round"/><circle cx="30" cy="16.2" r=".9" fill="#fff" opacity=".85"/>
      <circle cx="15.4" cy="17.6" r="4.4" fill="#f2ffdc" ${st(2.2)}/><circle cx="15.4" cy="17.6" r="3" fill="none" stroke="#3aa834" stroke-width="1.3"/><g fill="#7ab84a"><circle cx="14.4" cy="17" r=".6"/><circle cx="16.4" cy="17" r=".6"/><circle cx="15.4" cy="18.8" r=".6"/></g>
      <path d="M4 25.6H44Q44 41 30.8 44.2H17.2Q4 41 4 25.6Z" fill="url(#b)" ${st(3.2)}/>
      <rect x="2.6" y="23.4" width="42.8" height="5.2" rx="2.6" fill="url(#b)" ${st(3)}/>
      ${shine('M7.5 32q1 5.5 4.8 8.6', 2.2, 0.85)}${shine('M6.5 25.4h9', 1.6, 0.8)}
      ${eye(18, 34.2, 3.3, 3.4, '#2e9a2a', 1.8, 0.6, 0.5)}${eye(30, 34.2, 3.3, 3.4, '#2e9a2a', 1.8, -0.6, 0.5)}
      ${brows(17.6, 30.4, 30.2, 7, 3, 3.2)}
      <path d="M20 41.4Q24 38.4 28 41.4" fill="none" ${st(2.6)}/>`,

    'boss:rat': () => `<defs>${lg('f', '#efe8f7', '#8a7ca6')}${lg('e', '#ffc2da', '#ff5c9a')}${rg('r', '#fff0f0', '#ff1f3d', 0.4, 0.4, 0.65)}</defs>
      <circle cx="11.2" cy="13.6" r="8" fill="url(#f)" ${st(3.2)}/><circle cx="36.8" cy="13.6" r="8" fill="url(#f)" ${st(3.2)}/>
      <circle cx="11.5" cy="14" r="4.8" fill="url(#e)"/><circle cx="36.5" cy="14" r="4.8" fill="url(#e)"/>
      <path d="M24 43.2C20 43.2 17.6 40.4 15.6 37.2C11.6 35.6 8.8 31 8.8 25.4C8.8 16.8 15.6 10.6 24 10.6S39.2 16.8 39.2 25.4C39.2 31 36.4 35.6 32.4 37.2C30.4 40.4 28 43.2 24 43.2Z" fill="url(#f)" ${st(3.2)}/>
      ${shine('M13.6 18.4c1.8-2.8 4.4-4.4 7.4-5', 2.2, 0.8)}
      <ellipse cx="24" cy="36.4" rx="7.4" ry="5.6" fill="#f8f4ff" opacity=".85"/>
      <g fill="none" stroke="${OL}" stroke-width="1.5" stroke-linecap="round"><path d="M16.2 34.2L4.2 32.2M16.4 36.6L5 38.4M31.8 34.2L43.8 32.2M31.6 36.6L43 38.4"/></g>
      <circle cx="17.2" cy="25.6" r="5.6" fill="#ff1f3d" opacity=".3"/><circle cx="30.8" cy="25.6" r="5.6" fill="#ff1f3d" opacity=".3"/>
      <ellipse cx="17.6" cy="25.8" rx="3.3" ry="3.5" fill="url(#r)" ${st(2)}/><ellipse cx="30.4" cy="25.8" rx="3.3" ry="3.5" fill="url(#r)" ${st(2)}/>
      <circle cx="18.1" cy="26.4" r="1.2" fill="${OL}"/><circle cx="29.9" cy="26.4" r="1.2" fill="${OL}"/>
      ${brows(17.4, 30.6, 20.8, 7.6, 3.4, 3.4)}
      <path d="M24 35.2V37.2M19.8 36.2Q21.8 38.2 24 37.2Q26.2 38.2 28.2 36.2" fill="none" ${st(1.8)}/>
      <ellipse cx="24" cy="33.4" rx="3.3" ry="2.4" fill="#ff5c9a" ${st(1.8)}/><circle cx="23" cy="32.7" r=".7" fill="#fff" opacity=".8"/>
      <path d="M21.3 37.6h5.4v3.6q0 1.2-1.2 1.2h-3q-1.2 0-1.2-1.2z" fill="#fffbe6" ${st(1.7)}/><path d="M24 37.8v4.4" stroke="${OL}" stroke-width="1.3"/>`,

    'boss:lemon': () => `<defs>${lg('y', '#fffcc4', '#ffc400')}${lg('l', '#c2ff7a', '#2ea52a')}</defs>
      <path d="M34.6 15.2Q33.6 6.4 43.8 3.4Q45.4 12.6 34.6 15.2Z" fill="url(#l)" ${st(2.4)}/><path d="M36.4 12.8Q39.2 8.4 42.4 6" fill="none" stroke="#1d6b1a" stroke-width="1.3" stroke-linecap="round"/>${shine('M37 8.6q1.4-2 3.4-3', 1.4, 0.7)}
      <g transform="rotate(-18 24 26)">
        <path d="M3 26Q3.4 22.6 7.4 21.6C9.8 13 16.2 10.4 24 10.4S38.2 13 40.6 21.6Q44.6 22.6 45 26Q44.6 29.4 40.6 30.4C38.2 39 31.8 41.6 24 41.6S9.8 39 7.4 30.4Q3.4 29.4 3 26Z" fill="url(#y)" ${st(3.2)}/>
        <g fill="#e0a800" opacity=".5"><circle cx="12" cy="31.5" r=".8"/><circle cx="35" cy="34" r=".8"/><circle cx="37" cy="18.5" r=".7"/><circle cx="11" cy="20" r=".7"/><circle cx="28" cy="38.5" r=".8"/><circle cx="17" cy="37.5" r=".7"/></g>
        ${shine('M10.4 19.6c2.6-4.2 6.6-6.4 11.4-6.8', 2.4, 0.9)}
      </g>
      <path d="M12.6 25.4L19 28.4 12.6 30.6" fill="none" ${st(3)}/>
      ${eye(30.4, 26.8, 3.4, 3.1, OL, 1.7, -0.5, 0.6)}
      ${brows(15.4, 30.2, 22.2, 7, 3.4, 3.2)}
      <path d="M20.4 36.2q1.2-1.6 2.4 0t2.4 0 2.4 0" fill="none" ${st(2.4)}/>
      <g fill="#8ffbff" ${st(1.3)}><path d="M36.8 36.4q1.6 2.4 0 3.6-1.6-1.2 0-3.6z"/></g>
      <g fill="none" stroke="${OL}" stroke-width="1.6" stroke-linecap="round"><path d="M40.2 12.4l2.4-2.4M42.6 16.2l3-.8M7 11.6L5 9.4"/></g>`,

    'boss:salt': () => `<defs>${lg('b', '#ffffff', '#c3cff0')}${lg('c', '#ffffff', '#8a85b0')}${lg('k', '#a98bff', '#5a22d6')}</defs>
      <path d="M12.2 16Q12.2 4.6 24 4.6T35.8 16Z" fill="url(#c)" ${st(3)}/>
      <g fill="${OL}"><circle cx="19.4" cy="10.4" r="1.3"/><circle cx="24" cy="8.6" r="1.3"/><circle cx="28.6" cy="10.4" r="1.3"/><circle cx="21.6" cy="13.4" r="1.2"/><circle cx="26.4" cy="13.4" r="1.2"/></g>
      ${shine('M15.4 12.4c.8-2.6 2.4-4.4 4.8-5.2', 2, 0.9)}
      <rect x="10.4" y="14.6" width="27.2" height="5.6" rx="2.2" fill="url(#k)" ${st(3)}/>
      <path d="M12 20.2H36L38.8 39.6Q39.3 44.6 34.5 44.6H13.5Q8.7 44.6 9.2 39.6Z" fill="url(#b)" ${st(3.2)}/>
      <path d="M11.4 37.6Q24 35.6 36.6 37.6L37.4 41.6Q37.2 42.6 35.6 42.6H12.4Q10.8 42.6 10.6 41.6Z" fill="#e9eeff"/>
      <g fill="#b5c0e6"><circle cx="15" cy="40" r=".6"/><circle cx="20" cy="39.2" r=".6"/><circle cx="27" cy="40.2" r=".6"/><circle cx="33" cy="39.4" r=".6"/><circle cx="24" cy="41.2" r=".6"/></g>
      ${shine('M13.6 23.6l-1.2 11', 2.2, 0.9)}
      ${eye(19, 27.4, 3.3, 3.4, '#d0102f', 1.8, 0.6, 0.6)}${eye(29, 27.4, 3.3, 3.4, '#d0102f', 1.8, -0.6, 0.6)}
      ${brows(18.6, 29.4, 22.8, 7, 3.2, 3.2)}
      <path d="M14.6 32.4Q24 42.6 33.4 32.4Q24 36.2 14.6 32.4Z" fill="${OL}" ${st(2)}/>
      <path d="M17.6 33.6l1.5 2.4 1.3-1.9zM27.6 34.1l1.3 1.9 1.5-2.4z" fill="#fff"/>
      <g fill="#fff" ${st(1.2)}><rect x="4.2" y="8" width="2.6" height="2.6" rx=".4" transform="rotate(20 5.5 9.3)"/><rect x="40.6" y="6.4" width="2.4" height="2.4" rx=".4" transform="rotate(-15 41.8 7.6)"/><rect x="41.6" y="22" width="2.2" height="2.2" rx=".4" transform="rotate(30 42.7 23.1)"/><rect x="3.8" y="24" width="2" height="2" rx=".4"/></g>`,

    'boss:ghost': () => `<defs>${lg('g', '#ffffff', '#b9a2ff')}${lg('t', '#fff27a', '#ffb000')}${lg('c', '#ff8ae8', '#c5118f')}</defs>
      <path d="M24 3.5C13.5 3.5 8 11.5 8 21.5V39.5Q8 44 11.5 41.8L15 39.5 18.5 43Q20 44.5 21.5 43L24 40.5 26.5 43Q28 44.5 29.5 43L33 39.5 36.5 41.8Q40 44 40 39.5V21.5C40 11.5 34.5 3.5 24 3.5Z" fill="url(#g)" ${st(3.2)}/>
      ${shine('M12.4 16.5c.8-4.6 3.6-7.8 7.6-9', 2.4, 0.9)}
      <ellipse cx="18.4" cy="19.4" rx="3.2" ry="4" fill="${OL}"/><ellipse cx="29.6" cy="19.4" rx="3.2" ry="4" fill="${OL}"/>
      <circle cx="17.6" cy="18.2" r="1.2" fill="#fff"/><circle cx="28.8" cy="18.2" r="1.2" fill="#fff"/>
      <path d="M13.6 13.2L22.6 16M34.4 13.2L25.4 16" fill="none" stroke="${OL}" stroke-width="3.4" stroke-linecap="round"/>
      <ellipse cx="15" cy="25" rx="2.4" ry="1.5" fill="#ff7ab8" opacity=".6"/><ellipse cx="33" cy="25" rx="2.4" ry="1.5" fill="#ff7ab8" opacity=".6"/>
      <path d="M20 27.4Q24 24.2 28 27.4Z" fill="${OL}" ${st(2.2)}/>
      <path d="M9 31.4Q24 40.4 39 31.4" fill="none" stroke="${OL}" stroke-width="6.8" stroke-linecap="round"/>
      <path d="M9 31.4Q24 40.4 39 31.4" fill="none" stroke="url(#t)" stroke-width="3.8" stroke-linecap="round"/>
      <path d="M9.6 30.6Q24 39.2 38.4 30.6" fill="none" stroke="${OL}" stroke-width="1.3" stroke-dasharray=".9 2.2"/>
      <rect x="38.2" y="28.6" width="4" height="5.6" rx="1" fill="#e8e6f5" ${st(1.8)} transform="rotate(-28 40.2 31.4)"/>
      <circle cx="8.4" cy="32" r="5.8" fill="url(#c)" ${st(2.8)}/><circle cx="8.4" cy="32" r="2" fill="#fff" ${st(1.4)}/>
      <ellipse cx="6.6" cy="36.4" rx="3.2" ry="2.6" fill="url(#g)" ${st(2.4)}/><ellipse cx="41.2" cy="33.6" rx="3.2" ry="2.6" fill="url(#g)" ${st(2.4)}/>`,

    /* ═════════════════════════ EGGS ═════════════════════════ */
    'egg:basic': () => `<defs>${lg('a', '#fff9ea', '#ffc978')}</defs>
      <path d="${EGG}" fill="url(#a)" ${st(3.2)}/>
      <g fill="#ff9a3c" ${st(1.7)}><circle cx="17.5" cy="22.5" r="3.7"/><circle cx="30.5" cy="30.5" r="4.8"/><circle cx="29" cy="15" r="2.7"/><circle cx="15.5" cy="34.5" r="2.7"/><circle cx="24.5" cy="39.4" r="1.9"/></g>
      <ellipse cx="15.5" cy="15" rx="2.4" ry="5.2" transform="rotate(28 15.5 15)" fill="#fff" opacity=".85"/>`,

    'egg:neon': () => `<defs>${lg('a', '#39f0ff', '#ff2bd6')}<clipPath id="e"><path d="${EGG}"/></clipPath></defs>
      <path d="${EGG}" fill="#1ff4ff" opacity=".25" transform="translate(24 24) scale(1.07) translate(-24 -24)"/>
      <path d="${EGG}" fill="url(#a)"/>
      <g clip-path="url(#e)">
        <path d="M4 27L9 22 14 27 19 22 24 27 29 22 34 27 39 22 44 27" fill="none" stroke="#b6ff3b" stroke-width="7.5" stroke-linejoin="round" opacity=".35"/>
        <path d="M4 27L9 22 14 27 19 22 24 27 29 22 34 27 39 22 44 27" fill="none" stroke="${OL}" stroke-width="5.4" stroke-linejoin="round"/>
        <path d="M4 27L9 22 14 27 19 22 24 27 29 22 34 27 39 22 44 27" fill="none" stroke="#eaff9a" stroke-width="2.6" stroke-linejoin="round"/>
        <g fill="#fff" opacity=".9"><circle cx="18" cy="36" r="1.1"/><circle cx="31" cy="39" r=".9"/><circle cx="29.5" cy="13" r="1"/></g>
      </g>
      <path d="${EGG}" fill="none" ${st(3.2)}/>
      <ellipse cx="15.5" cy="14.5" rx="2.4" ry="5.2" transform="rotate(28 15.5 14.5)" fill="#fff" opacity=".85"/>
      ${spark(38.5, 9, 4, '#fff', 1.4)}`,

    'egg:cosmic': () => {
      const sw = [0, 180].map((a) => `<path d="M24 28C24 22 30 20.5 33.5 24.5S31 36 24 36.5" transform="rotate(${a} 24 28)"/>`).join('');
      return `<defs>${lg('a', '#8a3cff', '#0b0620')}${rg('c', '#ffffff', '#ff5ef0', 0.5, 0.5, 0.5)}<clipPath id="e"><path d="${EGG}"/></clipPath></defs>
      <path d="${EGG}" fill="#8a5cff" opacity=".3" transform="translate(24 24) scale(1.07) translate(-24 -24)"/>
      <path d="${EGG}" fill="url(#a)"/>
      <g clip-path="url(#e)">
        <ellipse cx="24" cy="28" rx="14" ry="7" transform="rotate(-24 24 28)" fill="#ff5ef0" opacity=".22"/>
        <g fill="none" stroke-linecap="round"><g stroke="#ff5ef0" stroke-width="3.2" opacity=".75">${sw}</g><g stroke="#8ffbff" stroke-width="1.4" opacity=".9">${sw}</g></g>
        <circle cx="24" cy="28" r="3.4" fill="url(#c)"/>
        <g fill="#fff"><circle cx="14" cy="22" r=".9"/><circle cx="33" cy="17" r=".8"/><circle cx="17" cy="38" r=".8"/><circle cx="35" cy="36" r="1"/><circle cx="21" cy="12" r=".7"/><circle cx="11" cy="31" r=".6"/><circle cx="29" cy="41" r=".6"/></g>
      </g>
      <path d="${EGG}" fill="none" stroke="#b98cff" stroke-width="1.6" opacity=".9" transform="translate(24 24) scale(.93) translate(-24 -24)"/>
      <path d="${EGG}" fill="none" ${st(3.2)}/>
      ${spark(29, 14, 3.4, '#fff6b0', 1.2)}${spark(15.5, 30, 2.4, '#fff', 1)}
      <ellipse cx="15.5" cy="14.5" rx="2.2" ry="4.8" transform="rotate(28 15.5 14.5)" fill="#fff" opacity=".55"/>`;
    },

    /* ═════════════════════════ MINIGAME ITEMS ═════════════════════════ */
    'item:broccoli': () => {
      const fl = [[14.5, 22.5, 7.2], [23.5, 16.5, 8.6], [32.5, 22.5, 7.2], [23.5, 25.5, 7]];
      return `<defs>${lg('f', '#9dff72', '#1c9438')}${lg('s', '#ecffb8', '#7cd648')}${lg('k', '#fff6a8', '#ff5a1f')}</defs>
      <circle cx="23.5" cy="25.5" r="19.6" fill="#ff2b4d" opacity=".2"/>
      <circle cx="23.5" cy="25.5" r="19.6" fill="none" stroke="#ff3d5e" stroke-width="2.4" opacity=".85" stroke-dasharray="5 3.2"/>
      <path d="M17.6 29Q18.2 38 15.6 42Q15 44.6 17.6 44.6H29.4Q32 44.6 31.4 42Q28.8 38 29.4 29Z" fill="url(#s)" ${st(3)}/>
      <rect x="17" y="35.2" width="13" height="3.6" fill="#ff2b4d" ${st(1.8)}/>
      <g fill="${OL}" stroke="${OL}" stroke-width="6">${fl.map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}"/>`).join('')}</g>
      <g fill="url(#f)">${fl.map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}"/>`).join('')}</g>
      <g fill="none" stroke="${OL}" stroke-width="1.4" opacity=".35"><path d="M19 20.6a7.4 7.4 0 0 1 1.4 5M28 20.6a7.4 7.4 0 0 0-1.4 5"/></g>
      ${shine('M18.4 13.4a8.4 8.4 0 0 1 4.4-2.6', 2.2, 0.85)}
      <path d="M28.5 10.6Q31 6 36.2 7.6" fill="none" stroke="${OL}" stroke-width="4.4" stroke-linecap="round"/>
      <path d="M28.5 10.6Q31 6 36.2 7.6" fill="none" stroke="#e8d3a8" stroke-width="1.8" stroke-linecap="round"/>
      <path d="${star(38.6, 8.2, 5.6, 2.4, 8, 0.2)}" fill="url(#k)" ${st(1.6)}/><circle cx="38.6" cy="8.2" r="1.5" fill="#fff"/>
      <path d="M17.4 23.2l4 1.4M29.6 23.2l-4 1.4" stroke="${OL}" stroke-width="2.4" stroke-linecap="round"/>
      <circle cx="19.6" cy="26.4" r="1.6" fill="${OL}"/><circle cx="27.4" cy="26.4" r="1.6" fill="${OL}"/>`;
    },

    'item:milk': () => `<defs>${lg('gl', '#ffffff', '#9fe8ff')}${lg('m', '#ffffff', '#d2dcf8')}<clipPath id="g"><path d="M10.5 9H37.5L34.3 41.8Q34 44.5 31.3 44.5H16.7Q14 44.5 13.7 41.8Z"/></clipPath></defs>
      <path d="M22 38L30.2 6.6Q30.7 4.4 33 4.4H39" fill="none" stroke="${OL}" stroke-width="5.8" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M22 38L30.2 6.6Q30.7 4.4 33 4.4H39" fill="none" stroke="#ff2bd6" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M22 38L30.2 6.6Q30.7 4.4 33 4.4H39" fill="none" stroke="#fff" stroke-width="2.8" stroke-dasharray="2.2 2.2" stroke-linejoin="round"/>
      <path d="M10.5 9H37.5L34.3 41.8Q34 44.5 31.3 44.5H16.7Q14 44.5 13.7 41.8Z" fill="url(#gl)" fill-opacity=".55"/>
      <g clip-path="url(#g)">
        <path d="M8 16.6Q16 13.8 24 16.6T40 16.6V46H8Z" fill="url(#m)"/>
        <path d="M8 16.6Q16 13.8 24 16.6T40 16.6" fill="none" stroke="${OL}" stroke-width="1.8" opacity=".45"/>
        <path d="M31.5 19l-2 21" stroke="#aab8e8" stroke-width="2.4" stroke-linecap="round" opacity=".6"/>
      </g>
      <path d="M10.5 9H37.5L34.3 41.8Q34 44.5 31.3 44.5H16.7Q14 44.5 13.7 41.8Z" fill="none" ${st(3.2)}/>
      ${shine('M14.2 12.4l.5 3.4', 2.2, 0.9)}
      <path d="M13.2 9h21.6" stroke="#fff" stroke-width="1.4" stroke-linecap="round" opacity=".8"/>`,

    'item:choco': () => `<defs>${lg('c', '#c07a46', '#4a2511')}${lg('w', '#ff8ae8', '#c5118f')}${lg('f', '#ffffff', '#aebce6')}${lg('s', '#fff6b0', '#ffc93c')}</defs>
      <g transform="rotate(-14 24 24)">
        <rect x="13" y="6" width="22" height="36" rx="3" fill="url(#c)" ${st(3.2)}/>
        <g fill="none" stroke="#2a1206" stroke-width="1.5" stroke-linejoin="round"><rect x="15.6" y="8.6" width="7.6" height="7" rx="1.2"/><rect x="24.8" y="8.6" width="7.6" height="7" rx="1.2"/><rect x="15.6" y="17.2" width="7.6" height="7" rx="1.2"/><rect x="24.8" y="17.2" width="7.6" height="7" rx="1.2"/></g>
        <g fill="none" stroke="#fff" stroke-width="1.3" stroke-linecap="round" opacity=".45"><path d="M16.8 13.8v-4h4.4M26 13.8v-4h4.4M16.8 22.4v-4h4.4M26 22.4v-4h4.4"/></g>
        <path d="M11.6 25.4L14 23.4 16.4 25.4 18.8 23.4 21.2 25.4 23.6 23.4 26 25.4 28.4 23.4 30.8 25.4 33.2 23.4 36.4 25.4V30H11.6Z" fill="url(#f)" ${st(2.2)}/>
        <rect x="11.6" y="27.4" width="24.8" height="15" rx="2.6" fill="url(#w)" ${st(3.2)}/>
        <path d="M11.6 32.2H36.4M11.6 37.6H36.4" stroke="#1ff4ff" stroke-width="1.6" opacity=".9"/>
        <path d="${star(24, 34.9, 4.2, 1.8)}" fill="url(#s)" ${st(1.4)}/>
        ${shine('M15 30.2v9', 1.8, 0.6)}
      </g>`,

    'item:donut': () => {
      const cols = ['#1ff4ff', '#b6ff3b', '#fff27a', '#ffffff', '#8a5cff', '#ff9a1f'];
      const spr = [[0.2, 11.6, 30], [0.9, 12.6, -40], [1.6, 11.2, 70], [2.3, 12.8, 10], [3.0, 11.8, -60], [3.7, 12.4, 45], [4.4, 11.4, -20], [5.1, 12.6, 80], [5.8, 11.8, -35]]
        .map(([a, r, rot], i) => { const x = P(24 + Math.cos(a) * r), y = P(23.6 + Math.sin(a) * r); return `<g transform="translate(${x} ${y}) rotate(${rot})"><path d="M-1.5 0h3" stroke="${OL}" stroke-width="3.2" stroke-linecap="round"/><path d="M-1.5 0h3" stroke="${cols[i % cols.length]}" stroke-width="1.6" stroke-linecap="round"/></g>`; }).join('');
      return `<defs>${lg('d', '#ffdca0', '#c2742a')}${lg('g', '#ffc6ef', '#ff3dbb')}</defs>
      <path d="M4.5 24.5a19.5 19.5 0 1 0 39 0a19.5 19.5 0 1 0-39 0ZM18 24.5a6 6 0 1 0 12 0a6 6 0 1 0-12 0Z" fill="url(#d)" fill-rule="evenodd" ${st(3.2)}/>
      <path d="${blob(24, 23.6, 15.6, 1.5, 14, 0.3)}M16.4 23.6a7.6 7.6 0 1 0 15.2 0a7.6 7.6 0 1 0-15.2 0Z" fill="url(#g)" fill-rule="evenodd" ${st(2.4)}/>
      <path d="M13.6 34.6q.2 3.6 1.8 3.8t1.4-3" fill="url(#g)" ${st(2.2)}/>
      ${shine('M11 18.6a14 14 0 0 1 6.8-7.4', 2.4, 0.85)}
      ${spr}`;
    },

    'item:cupcake': () => `<defs>${lg('w', '#8ffbff', '#2a7fe0')}${lg('f', '#ffe8f7', '#ff5ec8')}${rg('c', '#ff9a9a', '#d0102f', 0.35, 0.3, 0.8)}</defs>
      <path d="M9.4 28H38.6L34.8 43Q34.4 44.6 32.8 44.6H15.2Q13.6 44.6 13.2 43Z" fill="url(#w)" ${st(3.2)}/>
      <g stroke="${OL}" stroke-width="1.6" stroke-linecap="round" opacity=".4"><path d="M16.2 30.5l1.6 12M21.4 30.5l.6 12.2M26.6 30.5l-.6 12.2M31.8 30.5l-1.6 12"/></g>
      <path d="M6.8 28.4Q4.6 21.8 11 21H37Q43.4 21.8 41.2 28.4Q24 32 6.8 28.4Z" fill="url(#f)" ${st(3)}/>
      <path d="M10.6 21.6Q8.6 15.4 14.6 14.8H33.4Q39.4 15.4 37.4 21.6Q24 24 10.6 21.6Z" fill="url(#f)" ${st(3)}/>
      <path d="M15 15.4Q13.8 9.6 19.4 9.4H28.6Q34.2 9.6 33 15.4Q24 17.2 15 15.4Z" fill="url(#f)" ${st(3)}/>
      ${shine('M11.2 25.6q1-2.6 4-2.8', 1.8, 0.9)}${shine('M14.8 18.8q.8-2 3.4-2.2', 1.8, 0.9)}
      <g transform="translate(0 0)"><path d="M11 24.6l1.8-1.2M20 26.4l1.4 1.4M30.6 25.4l1.8-.8M35.4 23.4l1.2 1.6M18.6 19.2l1.8-.6M27.4 19.8l1.4 1M24 13.4l1.6-1" stroke="${OL}" stroke-width="3" stroke-linecap="round"/>
      <path d="M11 24.6l1.8-1.2M30.6 25.4l1.8-.8M24 13.4l1.6-1" stroke="#1ff4ff" stroke-width="1.5" stroke-linecap="round"/><path d="M20 26.4l1.4 1.4M18.6 19.2l1.8-.6" stroke="#b6ff3b" stroke-width="1.5" stroke-linecap="round"/><path d="M35.4 23.4l1.2 1.6M27.4 19.8l1.4 1" stroke="#fff27a" stroke-width="1.5" stroke-linecap="round"/></g>
      <path d="M25.4 5.6Q26.6 3.2 30.4 3.4" fill="none" stroke="${OL}" stroke-width="3.6" stroke-linecap="round"/><path d="M25.4 5.6Q26.6 3.2 30.4 3.4" fill="none" stroke="#3aa834" stroke-width="1.6" stroke-linecap="round"/>
      <circle cx="24.4" cy="8.2" r="4" fill="url(#c)" ${st(2.4)}/><circle cx="23.1" cy="7" r="1" fill="#fff" opacity=".9"/>`,

    'item:seven': () => {
      const d = 'M9 7.2H39.2V14.4C31.8 21.4 27.2 30.6 26.2 41.6H14.6C15.6 31.2 20.4 22.6 26.6 16.2H9Z';
      return `<defs>${lg('r', '#ff8a8a', '#d80a2c')}</defs>
      <path d="${d}" fill="${OL}" stroke="${OL}" stroke-width="8.4" stroke-linejoin="round"/>
      <path d="${d}" fill="#ffc93c" stroke="#ffc93c" stroke-width="4.2" stroke-linejoin="round"/>
      <path d="${d}" fill="url(#r)"/>
      <path d="M9 7.2H39.2V14.4C31.8 21.4 27.2 30.6 26.2 41.6H14.6C15.6 31.2 20.4 22.6 26.6 16.2H9Z" fill="none" stroke="#b30020" stroke-width="1" opacity=".35"/>
      ${shine('M12 10.2H34', 2.2, 0.85)}${shine('M24.4 20.2c-2.6 3.8-4.6 8.4-5.6 13', 2, 0.6)}
      ${spark(41.5, 34.5, 4.4, '#fff', 1.4)}`;
    },

    /* ═════════════════════════ MINIGAME COVERS ═════════════════════════ */
    'mg:ninja': () => {
      const kat = (rot) => `<g transform="translate(24 24) rotate(${rot})">
          <path d="M-2.8 9V-18Q-2.8-22.8 2.8-24.4V9Z" fill="url(#bl)" ${st(2.5)}/>
          <path d="M.9 7V-20.6" stroke="#fff" stroke-width="1.3" stroke-linecap="round" opacity=".95"/>
          <rect x="-2.5" y="11" width="5" height="11" rx="1.6" fill="#ff2bd6" ${st(2.3)}/>
          <path d="M-2.3 13l4.6 2.4M-2.3 15.4l4.6-2.4M-2.3 17.4l4.6 2.4M-2.3 19.8l4.6-2.4" stroke="${OL}" stroke-width="1.2"/>
          <ellipse cx="0" cy="10" rx="5.4" ry="2.1" fill="url(#gd)" ${st(2.2)}/>
          <circle cx="0" cy="23.2" r="1.8" fill="url(#gd)" ${st(1.6)}/>
        </g>`;
      const th = (-20 * Math.PI) / 180, d = [Math.cos(th), Math.sin(th)], n = [-Math.sin(th), Math.cos(th)];
      const C = [24, 24.5], R = 10.2;
      const pt = (t, s) => [P(C[0] + d[0] * t + n[0] * s), P(C[1] + d[1] * t + n[1] * s)];
      const poly = (s) => { const a = pt(-40, 0), b = pt(40, 0), c = pt(40, s), e = pt(-40, s); return `M${a}L${b}L${c}L${e}Z`.replace(/,/g, ' '); };
      const a = pt(-(R - 0.8), 0), b = pt(R - 0.8, 0);
      const cut = `<path d="M${a[0]} ${a[1]}L${b[0]} ${b[1]}" stroke="${OL}" stroke-width="2.6" stroke-linecap="round"/>`;
      const half = (dx, dy, clip) => `<g transform="translate(${P(dx)} ${P(dy)})"><g clip-path="url(#${clip})">${cookie('ck', C[0], C[1], R, 2.8)}<path d="M${a[0]} ${a[1]}L${b[0]} ${b[1]}" stroke="#f6d09a" stroke-width="6"/></g>${cut}</g>`;
      return `<defs>${lg('bl', '#ffffff', '#8fa0e8', 1, 0)}${lg('gd', '#fff27a', '#e59a00')}${ckDef('ck')}<clipPath id="u"><path d="${poly(-40)}"/></clipPath><clipPath id="v"><path d="${poly(40)}"/></clipPath></defs>
      ${kat(-42)}${kat(42)}
      ${half(-n[0] * 2.6 - 1, -n[1] * 2.6, 'u')}${half(n[0] * 2.6 + 1, n[1] * 2.6, 'v')}
      <path d="M4 31.4Q24 23.4 44 17.4Q25 25.6 4 31.4Z" fill="#1ff4ff" opacity=".5" stroke="#1ff4ff" stroke-width="2" stroke-linejoin="round"/>
      <path d="M4 31.4Q24 23.4 44 17.4Q25 25.6 4 31.4Z" fill="#fff"/>`;
    },

    'mg:flappy': () => {
      const wing = `<path d="M1 1C-1.4-6.6-7.6-12-15.4-12.4C-18.2-12.5-18.8-9.8-16.8-8.6C-19-7.8-18.8-5-16.4-4.6C-17.8-3.2-17-.8-14.6-.9C-15-1.1-14.6 2.6-12 2C-8 3.6-2.6 3.4 1 1Z" fill="url(#w)" ${st(2.6)}/><path d="M-4.4-3.4L-14.4-8.2M-5-.6L-13.6-3.6" fill="none" stroke="#b9acf0" stroke-width="1.4" stroke-linecap="round"/>${shine('M-4.6-6.6C-7-9-10-10.4-13.2-10.6', 1.6, 0.9)}`;
      return `<defs>${lg('w', '#ffffff', '#ece8ff')}${ckDef('ck')}</defs>
      <g transform="translate(19 24.4) rotate(18) scale(.95)">${wing}</g>
      <g transform="translate(29 24.4) rotate(-18) scale(-.95 .95)">${wing}</g>
      <g transform="translate(24 30.2) scale(.93) translate(-24 -29)">
      ${cookieFace('ck', 24, 29, 14.2, [[16.6, 20.8, 0.8, 0], [25.4, 18.2, 0.7, 50], [32.4, 21.6, 0.75, 110], [17.4, 38, 0.72, 200], [30.8, 38.2, 0.78, 150]])}
      ${shine('M13.4 22.4c1.4-2.2 3.2-3.8 5.4-4.6', 2, 0.75)}
      <ellipse cx="19.4" cy="27.2" rx="3.2" ry="3.6" fill="#fff" ${st(2)}/><ellipse cx="28.6" cy="27.2" rx="3.2" ry="3.6" fill="#fff" ${st(2)}/>
      <circle cx="20.2" cy="27.8" r="1.8" fill="${OL}"/><circle cx="29.4" cy="27.8" r="1.8" fill="${OL}"/><circle cx="19.6" cy="27" r=".65" fill="#fff"/><circle cx="28.8" cy="27" r=".65" fill="#fff"/>
      <ellipse cx="15.6" cy="32.6" rx="2.2" ry="1.4" fill="#ff5f9e" opacity=".7"/><ellipse cx="32.4" cy="32.6" rx="2.2" ry="1.4" fill="#ff5f9e" opacity=".7"/>
      <path d="M21.6 33q2.4 2.4 4.8 0" fill="none" ${st(2)}/></g>
      <g stroke="#fff" stroke-width="1.8" stroke-linecap="round" opacity=".7"><path d="M2.5 36h4M3.8 40.4h5"/></g>`;
    },

    'mg:rhythm': () => `<defs>${lg('v', '#5d4aa6', '#1a0b38')}${ckDef('ck')}${lg('n', '#ffffff', '#ffb8f2')}</defs>
      <circle cx="20.5" cy="28" r="18.8" fill="#ff2bd6" opacity=".2"/>
      <circle cx="20.5" cy="28" r="16.8" fill="url(#v)" ${st(3)}/>
      <g fill="none" stroke="#a592e8" stroke-width=".9" opacity=".45"><circle cx="20.5" cy="28" r="14.2"/><circle cx="20.5" cy="28" r="12"/><circle cx="20.5" cy="28" r="10"/></g>
      <path d="M8.6 21.4a13.6 13.6 0 0 1 6.6-6.4" fill="none" stroke="#1ff4ff" stroke-width="2.2" stroke-linecap="round"/>
      <path d="M33.2 33.8a13.6 13.6 0 0 1-5.4 6.2" fill="none" stroke="#ff2bd6" stroke-width="2.2" stroke-linecap="round"/>
      ${cookie('ck', 20.5, 28, 7.6, 2.4)}
      <circle cx="20.5" cy="28" r="1.3" fill="${OL}"/>
      <path d="M32.2 21.6V9.8l11.2-3v11.6" fill="none" stroke="${OL}" stroke-width="7" stroke-linejoin="round" stroke-linecap="round"/>
      <path d="M32.2 21.6V9.8l11.2-3v11.6" fill="none" stroke="url(#n)" stroke-width="3.2" stroke-linejoin="round" stroke-linecap="round"/>
      <path d="M32.2 13.6l11.2-3" stroke="${OL}" stroke-width="2.6" stroke-linecap="round"/>
      <ellipse cx="28.4" cy="22.4" rx="4.6" ry="3.6" transform="rotate(-18 28.4 22.4)" fill="url(#n)" ${st(2.8)}/>
      <ellipse cx="39.6" cy="19.2" rx="4.6" ry="3.6" transform="rotate(-18 39.6 19.2)" fill="url(#n)" ${st(2.8)}/>
      ${spark(8, 8, 3.8, '#8ffbff', 1.3)}${spark(43, 33, 2.8, '#fff', 1.1)}`,

    'mg:slots': () => {
      const seven = (cx) => `<path d="M${P(cx - 2.7)} 22.4H${P(cx + 2.7)}L${P(cx - 0.6)} 29.4" fill="none" stroke="#e0102f" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>`;
      const bulbs = [[11, 12.2], [14.4, 8.8], [19, 7], [24, 7], [28.6, 8.8], [32, 12.2]].map(([x, y], i) => `<circle cx="${x}" cy="${y}" r="1.35" fill="${['#fff27a', '#1ff4ff', '#ffffff'][i % 3]}" ${st(1.1)}/>`).join('');
      return `<defs>${lg('r', '#ff8ae8', '#c5118f')}${lg('g', '#fff27a', '#e59a00')}${rg('k', '#ff9a9a', '#d0102f', 0.35, 0.3, 0.8)}${lg('m', '#ffffff', '#b9b0e0')}</defs>
      <path d="M37.4 30.4H41V12.6" fill="none" stroke="${OL}" stroke-width="5.6" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M37.4 30.4H41V12.6" fill="none" stroke="url(#m)" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
      <circle cx="41" cy="10.4" r="3.8" fill="url(#k)" ${st(2.4)}/><circle cx="39.8" cy="9.2" r="1" fill="#fff" opacity=".9"/>
      <path d="M7 15.4Q7 4.4 21.5 4.4T36 15.4Z" fill="url(#g)" ${st(3)}/>
      ${bulbs}
      <rect x="4.6" y="14" width="33.8" height="30.6" rx="5" fill="url(#r)" ${st(3.2)}/>
      ${shine('M8.4 19v9', 2, 0.6)}
      <rect x="8.6" y="19.2" width="25.8" height="13.2" rx="2.6" fill="#fff" ${st(2.6)}/>
      <path d="M17.2 19.4V32.2M25.8 19.4V32.2" stroke="${OL}" stroke-width="1.6"/>
      ${seven(12.9)}${seven(21.5)}${seven(30.1)}
      <rect x="12" y="36.2" width="19" height="4.6" rx="2.3" fill="#3a2766" ${st(2.2)}/>
      <rect x="18" y="37.8" width="7" height="1.4" rx=".7" fill="#ffc93c"/>`;
    },
  });
})();
