/* COOKIE OVERDRIVE — data.js
 * Pure game data. No logic besides tiny check() lambdas that receive (state, CO).
 * Loaded first. Everything else reads CO.data.
 */
(function () {
  'use strict';
  const CO = (window.CO = window.CO || {});

  /* ───────────────────────── BUILDINGS ───────────────────────── */
  const buildings = [
    { id: 'cursor',      name: 'Curseur RGB', cost: 15,      cps: 0.1,    desc: 'Clique tout seul. En RGB, évidemment.' },
    { id: 'granny',      name: 'Mamie Gameuse', cost: 100,     cps: 1,      desc: '400 APM et un casque à oreilles de chat.' },
    { id: 'farm',        name: 'Ferme à Pépites', cost: 1100,    cps: 8,      desc: 'Fait pousser des pépites bio (ou presque).' },
    { id: 'mine',        name: 'Mine de Choco', cost: 12000,   cps: 47,     desc: 'Creuse des filons de chocolat noir 70 %.' },
    { id: 'factory',     name: 'Usine Néon', cost: 130000,  cps: 260,    desc: 'Chaîne de montage éclairée comme une rave.' },
    { id: 'bank',        name: 'Banque Crypto', cost: 1.4e6,   cps: 1400,   desc: 'Mine du $CRUNCH. Ça pump, ça dump, ça cuit.' },
    { id: 'temple',      name: 'Temple Sucré', cost: 2e7,     cps: 7800,   desc: 'On y prie le Grand Cookie Originel.' },
    { id: 'wizard',      name: 'Tour de Sorcier', cost: 3.3e8,   cps: 44000,  desc: 'Invoque des cookies. Parfois des grenouilles.' },
    { id: 'rocket',      name: 'Fusée Cookie', cost: 5.1e9,   cps: 260000, desc: 'Rapporte des cookies de la planète Biscuit.' },
    { id: 'lab',         name: 'Labo Alchimie', cost: 7.5e10,  cps: 1.6e6,  desc: 'Transforme l\'or en cookies. Upgrade logique.' },
    { id: 'portal',      name: 'Portail Dimensionnel', cost: 1e12,    cps: 1e7,    desc: 'Ouvre sur la Cookieverse. Ne pas regarder dedans.' },
    { id: 'timemachine', name: 'Machine Temporelle', cost: 1.4e13,  cps: 6.5e7,  desc: 'Vole des cookies à ton toi du futur.' },
    { id: 'antimatter',  name: 'Condensateur Antimatière', cost: 1.7e14,  cps: 4.3e8,  desc: 'Condense l\'univers en pâte à cookie.' },
    { id: 'prism',       name: 'Prisme RGB', cost: 2.1e15,  cps: 2.9e9,  desc: 'Convertit la lumière pure en cookies. Et en RGB.' },
    { id: 'streamer',    name: 'Stream 24/7', cost: 2.6e16,  cps: 2.1e10, desc: 'Des millions de viewers spamment des cookies.' },
    { id: 'ai',          name: 'IA Pâtissière', cost: 3.1e17,  cps: 1.5e11, desc: 'Elle a lu toutes les recettes du monde. Elle en invente de meilleures.' },
    { id: 'dyson',       name: 'Sphère de Dyson Choco', cost: 3.7e18,  cps: 1.1e12, desc: 'Capture toute l\'énergie d\'une étoile pour préchauffer le four.' },
    { id: 'multiverse',  name: 'Usine Multivers', cost: 4.4e19,  cps: 8e12,   desc: 'Chaque univers parallèle bosse pour toi. Même celui où tu es un brocoli.' },
    { id: 'bigbang',     name: 'Big Bang Sucré', cost: 5.5e20,  cps: 6e13,   desc: 'Crée des univers entiers faits de pâte à cookie.' },
  ];

  /* ───────────────────────── VISUAL LAYERS ─────────────────────────
   * Keys that upgrades turn on (CO.vis[key] = level). The stage draws each.
   * zone: 'cookie' = attached to the cookie (also drawn by drawCookie w/ accessories)
   *       'around' = around the cookie on the main stage
   *       'screen' = background / full screen                                   */
  const visuals = {
    chips_xl:       { zone: 'cookie', name: 'Pépites XXL brillantes' },
    sprinkles:      { zone: 'cookie', name: 'Vermicelles arc-en-ciel', max: 2 },
    glaze:          { zone: 'cookie', name: 'Glaçage bubblegum', max: 2 },
    crystals:       { zone: 'cookie', name: 'Cristaux de diamant incrustés' },
    rgb_rim:        { zone: 'cookie', name: 'Contour RGB animé' },
    face:           { zone: 'cookie', name: 'Visage kawaii (suit ta souris)' },
    shades:         { zone: 'cookie', name: 'Lunettes pixel « Deal With It »' },
    crown:          { zone: 'cookie', name: 'Couronne dorée' },
    headphones:     { zone: 'cookie', name: 'Casque gamer RGB' },
    bling:          { zone: 'cookie', name: 'Chaîne en or', max: 2 },
    halo:           { zone: 'cookie', name: 'Halo divin' },
    wings:          { zone: 'cookie', name: 'Ailes néon' },
    laser_eyes:     { zone: 'cookie', name: 'Yeux laser à chaque clic' },
    galaxy_core:    { zone: 'cookie', name: 'Fissures galactiques' },
    holo:           { zone: 'cookie', name: 'Reflet holographique' },
    glitch:         { zone: 'cookie', name: 'Glitch RGB' },
    afterimage:     { zone: 'cookie', name: 'Images rémanentes prismatiques' },
    orbiters:       { zone: 'around', name: 'Mini-cookies en orbite', max: 3 },
    saturn_ring:    { zone: 'around', name: 'Anneau planétaire' },
    fire_aura:      { zone: 'around', name: 'Aura de feu', max: 2 },
    lightning:      { zone: 'around', name: 'Arcs électriques' },
    shockwave:      { zone: 'around', name: 'Onde de choc à chaque clic' },
    confetti_click: { zone: 'around', name: 'Explosion de confettis au clic' },
    chat:           { zone: 'around', name: 'Chat de stream en direct' },
    cursor_rgb:     { zone: 'around', name: 'Anneau de curseurs RGB turbo' },
    cookie_rain:    { zone: 'screen', name: 'Pluie de cookies en fond' },
    disco:          { zone: 'screen', name: 'Boule disco + spots' },
    warp:           { zone: 'screen', name: 'Vitesse lumière' },
    god_rays:       { zone: 'screen', name: 'Rayons divins' },
    black_hole:     { zone: 'screen', name: 'Trou noir derrière le cookie' },
    beat_pulse:     { zone: 'screen', name: 'Pulsation sur le beat' },
  };

  /* ───────────────────────── UPGRADES ─────────────────────────
   * fx:  click (×), clickCps (+% of CPS per click), bld+x (building ×), cps (×),
   *      crit (+chance), critX (× crit mult), goldenFreq (×), goldenDur (×),
   *      comboCap (+max combo multiplier), feverDur (×)
   * req: clicks | bld:[id,n] | baked | golden | crits | combo
   * vis: [key, levelToAdd]                                                  */
  const upgrades = [
    { id: 'pepites_xxl',   name: 'Pépites XXL', cost: 100,     fx: { click: 2 },                       req: { clicks: 15 },            vis: ['chips_xl', 1] },
    { id: 'contour_rgb',   name: 'Contour RGB', cost: 150,     fx: { bld: 'cursor', x: 2 },            req: { bld: ['cursor', 1] },    vis: ['rgb_rim', 1] },
    { id: 'vermicelles',   name: 'Vermicelles Arc-en-ciel', cost: 1000,    fx: { bld: 'granny', x: 2 },            req: { bld: ['granny', 1] },    vis: ['sprinkles', 1] },
    { id: 'glacage',       name: 'Glaçage Bubblegum', cost: 2500,    fx: { click: 2 },                       req: { clicks: 150 },           vis: ['glaze', 1] },
    { id: 'onde_choc',     name: 'Onde de Choc', cost: 6000,    fx: { crit: 0.04 },                     req: { clicks: 300 },           vis: ['shockwave', 1] },
    { id: 'kawaii',        name: 'Visage Kawaii', cost: 11000,   fx: { bld: 'farm', x: 2 },              req: { bld: ['farm', 1] },      vis: ['face', 1] },
    { id: 'curseurs_turbo',name: 'Curseurs Turbo', cost: 12000,   fx: { bld: 'cursor', x: 2 },            req: { bld: ['cursor', 25] },   vis: ['cursor_rgb', 1] },
    { id: 'deal_with_it',  name: 'Lunettes Deal With It', cost: 30000,   fx: { bld: 'cursor', x: 2, clickCps: 0.005 }, req: { bld: ['cursor', 10] }, vis: ['shades', 1] },
    { id: 'confettis',     name: 'Confettis de Clic', cost: 60000,   fx: { click: 2 },                       req: { clicks: 700 },           vis: ['confetti_click', 1] },
    { id: 'mamies_speed',  name: 'Mamies Speedrun', cost: 80000,   fx: { bld: 'granny', x: 2 },            req: { bld: ['granny', 25] },   vis: ['sprinkles', 1] },
    { id: 'orbiteurs',     name: 'Mini-Cookies Orbitaux', cost: 120000,  fx: { bld: 'mine', x: 2 },              req: { bld: ['mine', 1] },      vis: ['orbiters', 1] },
    { id: 'casque',        name: 'Casque Gamer RGB', cost: 200000,  fx: { bld: 'granny', x: 2 },            req: { bld: ['granny', 10] },   vis: ['headphones', 1] },
    { id: 'pluie',         name: 'Pluie de Cookies', cost: 400000,  fx: { cps: 1.1 },                       req: { baked: 250000 },         vis: ['cookie_rain', 1] },
    { id: 'tracteurs',     name: 'Tracteurs Néon', cost: 900000,  fx: { bld: 'farm', x: 2 },              req: { bld: ['farm', 25] },     vis: ['glaze', 1] },
    { id: 'couronne',      name: 'Couronne du Roi', cost: 1.3e6,   fx: { bld: 'factory', x: 2 },           req: { bld: ['factory', 1] },   vis: ['crown', 1] },
    { id: 'aura_feu',      name: 'Aura de Feu', cost: 2e6,     fx: { comboCap: 2 },                    req: { combo: 60 },             vis: ['fire_aura', 1] },
    { id: 'foreuse',       name: 'Foreuse Diamant', cost: 1e7,     fx: { bld: 'mine', x: 2 },              req: { bld: ['mine', 25] },     vis: ['crystals', 1] },
    { id: 'chaine_or',     name: 'Chaîne en Or', cost: 1.4e7,   fx: { bld: 'bank', x: 2 },              req: { bld: ['bank', 1] },      vis: ['bling', 1] },
    { id: 'yeux_laser',    name: 'Yeux Laser', cost: 2.5e7,   fx: { clickCps: 0.01 },                 req: { clicks: 2500 },          vis: ['laser_eyes', 1] },
    { id: 'usine_inferno', name: 'Chaîne de Montage Inferno', cost: 1.1e8,   fx: { bld: 'factory', x: 2 },           req: { bld: ['factory', 25] },  vis: ['fire_aura', 1] },
    { id: 'saturne',       name: 'Anneau de Saturne', cost: 2e8,     fx: { bld: 'temple', x: 2 },            req: { bld: ['temple', 1] },    vis: ['saturn_ring', 1] },
    { id: 'eclairs',       name: 'Éclairs Statiques', cost: 3e8,     fx: { critX: 2 },                       req: { crits: 80 },             vis: ['lightning', 1] },
    { id: 'halo',          name: 'Halo Divin', cost: 6e8,     fx: { goldenFreq: 1.3 },                req: { golden: 5 },             vis: ['halo', 1] },
    { id: 'bull_run',      name: 'Crypto Bull Run', cost: 1.2e9,   fx: { bld: 'bank', x: 2 },              req: { bld: ['bank', 25] },     vis: ['bling', 1] },
    { id: 'disco',         name: 'Boule Disco', cost: 3.3e9,   fx: { bld: 'wizard', x: 2 },            req: { bld: ['wizard', 1] },    vis: ['disco', 1] },
    { id: 'clic_quantique',name: 'Clic Quantique', cost: 5e9,     fx: { click: 2, clickCps: 0.03 },       req: { clicks: 10000 },         vis: ['orbiters', 1] },
    { id: 'ailes',         name: 'Ailes Néon', cost: 8e9,     fx: { cps: 1.15 },                      req: { baked: 5e9 },            vis: ['wings', 1] },
    { id: 'holo',          name: 'Shimmer Holographique', cost: 5.1e10,  fx: { bld: 'rocket', x: 2 },            req: { bld: ['rocket', 1] },    vis: ['holo', 1] },
    { id: 'glitch',        name: 'Glitch Mode', cost: 1e11,    fx: { clickCps: 0.02 },                 req: { clicks: 6000 },          vis: ['glitch', 1] },
    { id: 'warp',          name: 'Vitesse Lumière', cost: 7.5e11,  fx: { bld: 'lab', x: 2 },               req: { bld: ['lab', 1] },       vis: ['warp', 1] },
    { id: 'rayons',        name: 'Rayons Divins', cost: 2e12,    fx: { goldenDur: 1.5 },                 req: { golden: 20 },            vis: ['god_rays', 1] },
    { id: 'galaxie',       name: 'Cœur Galactique', cost: 1e13,    fx: { bld: 'portal', x: 2 },            req: { bld: ['portal', 1] },    vis: ['galaxy_core', 1] },
    { id: 'bass',          name: 'Bass Boost', cost: 5e13,    fx: { feverDur: 1.5, comboCap: 3 },     req: { combo: 200 },            vis: ['beat_pulse', 1] },
    { id: 'essaim',        name: 'Essaim Orbital', cost: 1.4e14,  fx: { bld: 'timemachine', x: 2 },       req: { bld: ['timemachine', 1] }, vis: ['orbiters', 1] },
    { id: 'trou_noir',     name: 'Trou Noir', cost: 1.7e15,  fx: { bld: 'antimatter', x: 2 },        req: { bld: ['antimatter', 1] }, vis: ['black_hole', 1] },
    { id: 'prisme',        name: 'Afterimage Prismatique', cost: 2.1e16,  fx: { bld: 'prism', x: 2, cps: 1.2 },   req: { bld: ['prism', 1] },     vis: ['afterimage', 1] },
    { id: 'chat_direct',   name: 'Chat en Direct', cost: 2.6e17,  fx: { bld: 'streamer', x: 2 },          req: { bld: ['streamer', 1] },  vis: ['chat', 1] },
    { id: 'ai_1',          name: 'Réseau de Neurones Sucré', cost: 3.1e18, fx: { bld: 'ai', x: 2 },          req: { bld: ['ai', 1] },          vis: ['glitch', 1] },
    { id: 'ai_25',         name: 'Superintelligence Gourmande', cost: 7.8e19, fx: { bld: 'ai', x: 2 },     req: { bld: ['ai', 25] },         vis: ['holo', 1] },
    { id: 'dyson_1',       name: 'Panneaux Solaires Pépite', cost: 3.7e19, fx: { bld: 'dyson', x: 2 },    req: { bld: ['dyson', 1] },       vis: ['god_rays', 1] },
    { id: 'dyson_25',      name: 'Étoile Apprivoisée', cost: 9.2e20, fx: { bld: 'dyson', x: 2 },          req: { bld: ['dyson', 25] },      vis: ['halo', 1] },
    { id: 'multi_1',       name: 'Câbles Interdimensionnels', cost: 4.4e20, fx: { bld: 'multiverse', x: 2 }, req: { bld: ['multiverse', 1] }, vis: ['warp', 1] },
    { id: 'multi_25',      name: 'Conseil des Toi Alternatifs', cost: 1.1e22, fx: { bld: 'multiverse', x: 2 }, req: { bld: ['multiverse', 25] }, vis: ['afterimage', 1] },
    { id: 'bang_1',        name: 'Inflation Cosmique', cost: 5.5e21, fx: { bld: 'bigbang', x: 2 },       req: { bld: ['bigbang', 1] },     vis: ['galaxy_core', 1] },
    { id: 'bang_25',       name: 'Théorie du Tout (Chocolat)', cost: 1.4e23, fx: { bld: 'bigbang', x: 2, cps: 1.2 }, req: { bld: ['bigbang', 25] }, vis: ['black_hole', 1] },
    // ── vague 2 : paliers 25 / 50 et bonus globaux ──
    { id: 'curseurs_50',   name: 'Curseurs Hyperthreadés', cost: 5e6,     fx: { bld: 'cursor', x: 3 },            req: { bld: ['cursor', 50] },   vis: ['cursor_rgb', 1] },
    { id: 'mamies_50',     name: 'Mamies Pro League', cost: 4e7,     fx: { bld: 'granny', x: 3 },            req: { bld: ['granny', 50] },   vis: ['headphones', 1] },
    { id: 'ferme_50',      name: 'Serres Hydroponiques', cost: 4.4e8,   fx: { bld: 'farm', x: 3 },              req: { bld: ['farm', 50] },     vis: ['sprinkles', 1] },
    { id: 'temple_25',     name: 'Chorale Céleste', cost: 5e9,     fx: { bld: 'temple', x: 2 },            req: { bld: ['temple', 25] },   vis: ['halo', 1] },
    { id: 'wizard_25',     name: 'Grimoire Interdit', cost: 8e10,    fx: { bld: 'wizard', x: 2 },            req: { bld: ['wizard', 25] },   vis: ['disco', 1] },
    { id: 'rocket_25',     name: 'Réacteurs Ionique', cost: 1.3e12,  fx: { bld: 'rocket', x: 2 },            req: { bld: ['rocket', 25] },   vis: ['warp', 1] },
    { id: 'lab_25',        name: 'Pierre Philosophale', cost: 1.9e13,  fx: { bld: 'lab', x: 2 },               req: { bld: ['lab', 25] },      vis: ['crystals', 1] },
    { id: 'portal_25',     name: 'Multivers Stable', cost: 2.5e14,  fx: { bld: 'portal', x: 2 },            req: { bld: ['portal', 25] },   vis: ['galaxy_core', 1] },
    { id: 'time_25',       name: 'Paradoxe Maîtrisé', cost: 3.5e15,  fx: { bld: 'timemachine', x: 2 },       req: { bld: ['timemachine', 25] }, vis: ['afterimage', 1] },
    { id: 'anti_25',       name: 'Singularité Domptée', cost: 4.3e16,  fx: { bld: 'antimatter', x: 2 },        req: { bld: ['antimatter', 25] }, vis: ['black_hole', 1] },
    { id: 'prism_25',      name: 'Spectre Infini', cost: 5.3e17,  fx: { bld: 'prism', x: 2 },             req: { bld: ['prism', 25] },    vis: ['holo', 1] },
    { id: 'stream_25',     name: 'Raid de 100 000 Viewers', cost: 6.5e18, fx: { bld: 'streamer', x: 2 },     req: { bld: ['streamer', 25] }, vis: ['chat', 1] },
    { id: 'crit_2',        name: 'Doigt Stroboscopique', cost: 3e10,    fx: { crit: 0.04 },                     req: { crits: 300 },            vis: ['lightning', 1] },
    { id: 'lucky_2',       name: 'Trèfle à Quatre Pépites', cost: 9e13,    fx: { goldenFreq: 1.25 },               req: { golden: 50 },            vis: ['god_rays', 1] },
    { id: 'clic_divin',    name: 'Index Divin', cost: 4e14,    fx: { click: 3, clickCps: 0.02 },       req: { clicks: 25000 },         vis: ['laser_eyes', 1] },
    { id: 'turbo_global',  name: 'Overclock Total', cost: 1e18,    fx: { cps: 1.25 },                      req: { baked: 5e17 },           vis: ['glitch', 1] },
  ];

  /* ───────────────────────── SKINS ─────────────────────────
   * style tells the renderer which texture routine to use.
   * pal: base / dark / light / chip / chipHi / rim (hex)                      */
  const skins = [
    { id: 'classic',      name: 'Classique',        style: 'classic', cost: 0,   pal: { base: '#d99a4e', dark: '#a9652a', light: '#f3c783', chip: '#4a2511', chipHi: '#7a4424', rim: '#8a5220' } },
    { id: 'double_choco', name: 'Double Choco',     style: 'classic', cost: 15,  pal: { base: '#6b3a1f', dark: '#3f1f0e', light: '#915833', chip: '#f5e6d0', chipHi: '#ffffff', rim: '#2e160a' } },
    { id: 'red_velvet',   name: 'Red Velvet',       style: 'classic', cost: 25,  pal: { base: '#c02640', dark: '#7a0f22', light: '#e8566c', chip: '#fff3e6', chipHi: '#ffffff', rim: '#5e0a1a' } },
    { id: 'matcha',       name: 'Matcha Zen',       style: 'classic', cost: 25,  pal: { base: '#8dbf5a', dark: '#5e8a34', light: '#bde38f', chip: '#f7f2e0', chipHi: '#ffffff', rim: '#466a24' } },
    { id: 'pixel',        name: 'Pixel 8-bit',      style: 'pixel',   cost: 40,  pal: { base: '#e0a050', dark: '#9c5a1c', light: '#ffd08a', chip: '#3a1c0c', chipHi: '#6e3a1c', rim: '#1a0b33' } },
    { id: 'lava',         name: 'Magma',            style: 'lava',    cost: 60,  pal: { base: '#2a1210', dark: '#140806', light: '#4a221c', chip: '#ff6a00', chipHi: '#ffd000', rim: '#ff3d00' } },
    { id: 'galaxy',       name: 'Galaxie',          style: 'galaxy',  cost: 80,  pal: { base: '#2b1060', dark: '#120530', light: '#6a3cc9', chip: '#ff5ef0', chipHi: '#9ff6ff', rim: '#b16bff' } },
    { id: 'diamond',      name: 'Diamant',          style: 'diamond', cost: 120, pal: { base: '#9ff3ff', dark: '#3fb6d9', light: '#ffffff', chip: '#e0fbff', chipHi: '#ffffff', rim: '#63d6f0' } },
    { id: 'hologram',     name: 'Hologramme',       style: 'holo',    cost: 150, pal: { base: '#39f0ff', dark: '#0b6d8a', light: '#b7fbff', chip: '#ff4fe1', chipHi: '#ffffff', rim: '#39f0ff' } },
    { id: 'golden',       name: 'Cookie Doré',      style: 'gold',    cost: 0, unlock: { ach: 'a_golden10', text: 'Attrape 10 cookies dorés' }, pal: { base: '#ffcc33', dark: '#c98a00', light: '#fff2a8', chip: '#b36b00', chipHi: '#ffe07a', rim: '#8a5a00' } },
    { id: 'rainbow',      name: 'Arc-en-ciel RGB',  style: 'rainbow', cost: 250, pal: { base: '#ff4fd8', dark: '#7a2cff', light: '#ffffff', chip: '#1a0b33', chipHi: '#5a3a8a', rim: '#ffffff' } },
    { id: 'mint',         name: 'Menthe Glaciale',  style: 'classic', cost: 30,  pal: { base: '#9fe8d2', dark: '#4fb89a', light: '#d8fff2', chip: '#2b1a12', chipHi: '#5a3a28', rim: '#3a9a80' } },
    { id: 'blueberry',    name: 'Myrtille',         style: 'classic', cost: 35,  pal: { base: '#5b5bd6', dark: '#2e2e8a', light: '#9a9aff', chip: '#e8e0ff', chipHi: '#ffffff', rim: '#23236a' } },
    { id: 'retro_gb',     name: 'Game Boy',         style: 'pixel',   cost: 70,  pal: { base: '#8bac0f', dark: '#306230', light: '#9bbc0f', chip: '#0f380f', chipHi: '#306230', rim: '#0f380f' } },
    { id: 'ice',          name: 'Cristal de Glace', style: 'diamond', cost: 140, pal: { base: '#cfe9ff', dark: '#7aa8d6', light: '#ffffff', chip: '#9ad0ff', chipHi: '#ffffff', rim: '#5b8fc9' } },
    { id: 'plasma',       name: 'Plasma',           style: 'lava',    cost: 180, pal: { base: '#12062a', dark: '#05010f', light: '#2a1060', chip: '#00e5ff', chipHi: '#e0ffff', rim: '#7a2cff' } },
    { id: 'nebula_rose',  name: 'Nébuleuse Rose',   style: 'galaxy',  cost: 200, pal: { base: '#5a0f4a', dark: '#2a0522', light: '#b03c8f', chip: '#ffd0f0', chipHi: '#ffffff', rim: '#ff5ec8' } },
    { id: 'void',         name: 'Néant',            style: 'void',    cost: 0, unlock: { rebirths: 3, text: 'Fais 3 Rebirths' }, pal: { base: '#07030f', dark: '#000000', light: '#1d1033', chip: '#b16bff', chipHi: '#ffffff', rim: '#b16bff' } },
  ];

  /* ───────────────────────── THEMES (backgrounds) ───────────────────────── */
  const themes = [
    { id: 'synthwave', name: 'Synthwave',        cost: 0,  preview: 'linear-gradient(180deg,#1a0536 0%,#6b1a8f 45%,#ff3d9a 62%,#120428 63%,#120428 100%)' },
    { id: 'galaxy',    name: 'Nébuleuse',        cost: 30, preview: 'radial-gradient(circle at 30% 40%,#7a2cff 0%,transparent 45%),radial-gradient(circle at 70% 65%,#ff3d9a 0%,transparent 40%),#070214' },
    { id: 'matrix',    name: 'Matrice Sucrée',   cost: 40, preview: 'repeating-linear-gradient(90deg,#00ff88 0 2px,transparent 2px 14px),#010a06' },
    { id: 'candy',     name: 'Candy Pop',        cost: 40, preview: 'linear-gradient(135deg,#ffb3e6,#b3e5ff 50%,#fff3b3)' },
    { id: 'inferno',   name: 'Inferno',          cost: 60, preview: 'radial-gradient(circle at 50% 110%,#ff6a00 0%,#a0100a 40%,#1a0202 75%)' },
    { id: 'aurora',    name: 'Aurore Boréale',   cost: 80, preview: 'linear-gradient(170deg,#021a1f 0%,#0bd6a0 35%,#5b3cff 60%,#02101a 100%)' },
  ];

  /* ───────────────────────── PETS & EGGS ───────────────────────── */
  const rarities = {
    common:    { name: 'Commun',     color: '#b8c4d9', glow: 'rgba(184,196,217,.6)' },
    rare:      { name: 'Rare',       color: '#3d9bff', glow: 'rgba(61,155,255,.75)' },
    epic:      { name: 'Épique',     color: '#b14dff', glow: 'rgba(177,77,255,.8)' },
    legendary: { name: 'Légendaire', color: '#ffb800', glow: 'rgba(255,184,0,.9)' },
    mythic:    { name: 'Mythique',   color: 'rgb',     glow: 'rgb' }, // animated rainbow
  };
  // bonus: click / cps / all (fraction), golden (freq ×), crit (+chance)
  const pets = [
    { id: 'hamster',  name: 'Hamster Crunch', rarity: 'common',    bonus: { click: 0.06 } },
    { id: 'frog',     name: 'Crapaud Crêpe', rarity: 'common',    bonus: { cps: 0.06 } },
    { id: 'chick',    name: 'Poussin Beurre', rarity: 'common',    bonus: { all: 0.04 } },
    { id: 'cat',      name: 'Chat Choco', rarity: 'rare',      bonus: { cps: 0.15 } },
    { id: 'dog',      name: 'Doggo Biscuit', rarity: 'rare',      bonus: { click: 0.15 } },
    { id: 'fox',      name: 'Renard Caramel', rarity: 'rare',      bonus: { all: 0.1 } },
    { id: 'panda',    name: 'Panda Pépite', rarity: 'epic',      bonus: { cps: 0.3 } },
    { id: 'octopus',  name: 'Poulpe Glacé', rarity: 'epic',      bonus: { click: 0.3, crit: 0.02 } },
    { id: 'owl',      name: 'Hibou Sucré', rarity: 'epic',      bonus: { all: 0.15, golden: 1.15 } },
    { id: 'unicorn',  name: 'Licorne RGB', rarity: 'legendary', bonus: { all: 0.5 } },
    { id: 'dragon',   name: 'Dragon Cramé', rarity: 'legendary', bonus: { click: 0.8, crit: 0.03 } },
    { id: 'robot',    name: 'Robot Cuiseur', rarity: 'legendary', bonus: { cps: 0.8 } },
    { id: 'glitchy',  name: 'Glitchy', rarity: 'mythic',    bonus: { all: 1.0, crit: 0.05 } },
    { id: 'whale',    name: 'Baleine Lactée', rarity: 'mythic',    bonus: { cps: 1.5, golden: 1.25 } },
  ];
  const eggs = [
    { id: 'basic',  name: 'Œuf Basique', cost: 30,  colors: ['#fff6e0', '#ffd79a'], odds: { common: 70, rare: 25, epic: 5 } },
    { id: 'neon',   name: 'Œuf Néon', cost: 120, colors: ['#39f0ff', '#ff2bd6'], odds: { rare: 55, epic: 35, legendary: 10 } },
    { id: 'cosmic', name: 'Œuf Cosmique', cost: 400, colors: ['#7a2cff', '#0b0620'], odds: { epic: 50, legendary: 40, mythic: 10 } },
  ];

  /* ───────────────────────── GOLDEN COOKIES ───────────────────────── */
  const golden = [
    { kind: 'lucky',      weight: 40, label: 'CHANCEUX !',        color: '#ffd23c' },
    { kind: 'frenzy',     weight: 30, label: 'FRÉNÉSIE ×7',       color: '#ff5a1f', buff: { id: 'frenzy', name: 'Frénésie', icon: 'ui:fire', dur: 30, cps: 7 } },
    { kind: 'clickstorm', weight: 14, label: 'CLIC-TEMPÊTE ×77',  color: '#1ff4ff', buff: { id: 'clickstorm', name: 'Clic-Tempête', icon: 'ui:tornado', dur: 10, click: 77 } },
    { kind: 'rgbstorm',   weight: 8,  label: 'RGB STORM',         color: 'rgb' },
    { kind: 'gems',       weight: 8,  label: 'PLUIE DE GEMMES',   color: '#3dffb0' },
    { kind: 'blessing',   weight: 10, label: 'BÉNÉDICTION ×3 (60 s)', color: '#fff27a', buff: { id: 'blessing', name: 'Bénédiction', icon: 'ui:crown', dur: 60, cps: 3 } },
    { kind: 'overclock',  weight: 6,  label: 'OVERCLOCK ×15',     color: '#ff2bd6', buff: { id: 'overclock', name: 'Overclock', icon: 'ui:bolt', dur: 15, cps: 15 } },
    { kind: 'bossbait',   weight: 4,  label: 'APPÂT À BOSS !',    color: '#ff4d6d' },
  ];

  /* ───────────────────────── BOSSES ───────────────────────── */
  const bosses = [
    { id: 'broccoli', name: 'Brocoli Tyran', color: '#3dff6a' },
    { id: 'dentist',  name: 'Dentiste Suprême', color: '#e8f4ff' },
    { id: 'salad',    name: 'Salade Détox', color: '#9dff3d' },
    { id: 'rat',      name: 'Rat des Placards', color: '#b0a0c0' },
    { id: 'lemon',    name: 'Citron Acide', color: '#fff23d' },
    { id: 'salt',     name: 'Salière Maléfique', color: '#ffffff' },
    { id: 'ghost',    name: 'Fantôme du Régime', color: '#c9b6ff' },
    { id: 'celery',     name: 'Céleri Ninja',            color: '#9dff72', minKills: 3 },
    { id: 'toothbrush', name: 'Brosse à Dents Laser',    color: '#7ff0ff', minKills: 5 },
    { id: 'raisin',     name: 'Cookie aux Raisins Traître', color: '#c47aff', minKills: 7 },
    { id: 'kale',       name: 'Chou Kale Hipster',       color: '#b8ff9a', minKills: 9 },
    { id: 'bottle',     name: 'Bouteille d\'Eau Plate', color: '#d8f6ff', minKills: 11 },
    { id: 'scale',      name: 'Balance Maudite',         color: '#ffffff', minKills: 13 },
    { id: 'nutribot',   name: 'Nutribot 3000',           color: '#1ff4ff', minKills: 15 },
  ];
  // every 10th fight: the mega boss. The final boss ends the game (see CO.finalGoal).
  const megaBoss = { id: 'king', name: 'Roi Brocoli', color: '#ff5c7a', mega: true };
  const finalBoss = { id: 'final', name: 'LE GRAND RÉGIME', color: '#b16bff', final: true };

  /* ───────────────────────── MINIGAME UNLOCKS ─────────────────────────
   * Minigame modules register themselves; this only says when they unlock. */
  const minigameUnlocks = {
    ninja:  { baked: 50,     text: 'Produis 50 cookies' },
    flappy: { baked: 1000,   text: 'Produis 1 000 cookies' },
    rhythm: { baked: 25000,  text: 'Produis 25 000 cookies' },
    slots:  { baked: 250000, text: 'Produis 250 000 cookies' },
  };

  /* ───────────────────────── ACHIEVEMENTS ───────────────────────── */
  const B = (s, id) => s.buildings[id] || 0;
  const totalB = (s) => Object.values(s.buildings).reduce((a, b) => a + b, 0);
  const achievements = [
    { id: 'a_ai',        name: 'Singularité Sucrée', gems: 20, desc: 'Possède une IA Pâtissière.',        check: (s) => B(s, 'ai') >= 1 },
    { id: 'a_bigbang',   name: 'Créateur d\'Univers', gems: 50, desc: 'Possède un Big Bang Sucré.',     check: (s) => B(s, 'bigbang') >= 1 },
    { id: 'a_bld500',    name: 'Empire Industriel', gems: 25, desc: 'Possède 500 bâtiments au total.',    check: (s) => totalB(s) >= 500 },
    { id: 'a_boss5',     name: 'Chasseur de Légumes', gems: 8,  desc: 'Bats 5 boss.',                          check: (s) => s.stats.bossKills >= 5 },
    { id: 'a_boss15',    name: 'Terreur du Potager', gems: 15, desc: 'Bats 15 boss.',                         check: (s) => s.stats.bossKills >= 15 },
    { id: 'a_boss40',    name: 'Végétarien Repenti', gems: 30, desc: 'Bats 40 boss.',                         check: (s) => s.stats.bossKills >= 40 },
    { id: 'a_elite',     name: 'Élite Écrasée', gems: 10, desc: 'Bats un boss ÉLITE.',                        check: (s) => (s.stats.eliteKills || 0) >= 1 },
    { id: 'a_king',      name: 'Régicide', gems: 20, desc: 'Bats le Roi Brocoli.',                             check: (s) => (s.stats.megaKills || 0) >= 1 },
    { id: 'a_final',     name: 'FIN : Le Cookie Suprême', gems: 100, desc: 'Bats LE GRAND RÉGIME.',            check: (s) => !!s.gameWon },
    { id: 'a_play1h',    name: 'Une Heure de Crunch', gems: 10, desc: 'Joue 1 heure.',                         check: (s) => s.stats.playTime >= 3600 },
    { id: 'a_play3h',    name: 'Marathon Sucré', gems: 25, desc: 'Joue 3 heures.',                             check: (s) => s.stats.playTime >= 10800 },
    { id: 'a_daily3',    name: 'Habitué', gems: 5,  desc: 'Série de 3 jours de connexion.',        check: (s) => (s.dailyStreak || 0) >= 3 },
    { id: 'a_daily7',    name: 'Accro au Cookie', gems: 15, desc: 'Série de 7 jours de connexion.',        check: (s) => (s.dailyStreak || 0) >= 7 },
    { id: 'a_skins8',    name: 'Garde-Robe Sucrée', gems: 20, desc: 'Possède 8 skins.',                    check: (s) => Object.values(s.skinsOwned || {}).filter(Boolean).length >= 8 },
    { id: 'a_dj',        name: 'DJ Cookie', gems: 3,  desc: 'Change de morceau de musique.',            check: (s) => !!s.settings && s.settings.track && s.settings.track !== 'synthwave' },
    { id: 'a_upg50',     name: 'Collectionneur d\'Upgrades', gems: 25, desc: 'Achète 50 upgrades.',  check: (s) => Object.values(s.upgrades || {}).filter(Boolean).length >= 50 },
    { id: 'a_click1',    name: 'Premier Crunch', gems: 1,  desc: 'Clique sur le cookie.',                check: (s) => s.clicks >= 1 },
    { id: 'a_click100',  name: 'Doigt Chaud', gems: 3,  desc: '100 clics.',                           check: (s) => s.clicks >= 100 },
    { id: 'a_click1k',   name: 'Tendinite Speedrun', gems: 5,  desc: '1 000 clics.',                         check: (s) => s.clicks >= 1000 },
    { id: 'a_click10k',  name: 'Clavier Mécanique Humain', gems: 10, desc: '10 000 clics.',                        check: (s) => s.clicks >= 10000 },
    { id: 'a_click50k',  name: 'Ce N\'est Plus un Jeu', gems: 25, desc: '50 000 clics.',                        check: (s) => s.clicks >= 50000 },
    { id: 'a_bake100',   name: 'Petite Fournée', gems: 1,  desc: 'Produis 100 cookies.',                 check: (s) => s.allTimeBaked >= 100 },
    { id: 'a_bake1k',    name: 'Boulanger du Dimanche', gems: 3,  desc: 'Produis 1 000 cookies.',               check: (s) => s.allTimeBaked >= 1e3 },
    { id: 'a_bake10k',   name: 'Influenceur Cookie', gems: 5,  desc: 'Produis 10 000 cookies.',              check: (s) => s.allTimeBaked >= 1e4 },
    { id: 'a_bake100k',  name: 'Startup Sucrée', gems: 8,  desc: 'Produis 100 000 cookies.',             check: (s) => s.allTimeBaked >= 1e5 },
    { id: 'a_bake1m',    name: 'MILLIONNAIRE', gems: 12, desc: 'Produis 1 million de cookies.',        check: (s) => s.allTimeBaked >= 1e6 },
    { id: 'a_bake100m',  name: 'Licorne de la Tech', gems: 20, desc: 'Produis 100 millions de cookies.',     check: (s) => s.allTimeBaked >= 1e8 },
    { id: 'a_bake1b',    name: 'Milliardaire Croustillant', gems: 30, desc: 'Produis 1 milliard de cookies.',       check: (s) => s.allTimeBaked >= 1e9 },
    { id: 'a_bake1t',    name: 'L\'Économie, C\'est Moi', gems: 50, desc: 'Produis 1 000 milliards de cookies.',  check: (s) => s.allTimeBaked >= 1e12 },
    { id: 'a_cps10',     name: 'Ça Tourne Tout Seul', gems: 3,  desc: '10 cookies/seconde.',                  check: (s, c) => c.cpsBase() >= 10 },
    { id: 'a_cps1k',     name: 'Machine de Guerre', gems: 8,  desc: '1 000 cookies/seconde.',               check: (s, c) => c.cpsBase() >= 1e3 },
    { id: 'a_cps100k',   name: 'Usine à Gaz Sucré', gems: 15, desc: '100 000 cookies/seconde.',             check: (s, c) => c.cpsBase() >= 1e5 },
    { id: 'a_cps10m',    name: 'Singularité Cookie', gems: 30, desc: '10 millions de cookies/seconde.',      check: (s, c) => c.cpsBase() >= 1e7 },
    { id: 'a_b50',       name: 'Promoteur Immobilier', gems: 5,  desc: 'Possède 50 bâtiments.',                check: (s) => totalB(s) >= 50 },
    { id: 'a_b200',      name: 'Ville Cookie', gems: 15, desc: 'Possède 200 bâtiments.',               check: (s) => totalB(s) >= 200 },
    { id: 'a_b500',      name: 'Métropole RGB', gems: 30, desc: 'Possède 500 bâtiments.',               check: (s) => totalB(s) >= 500 },
    { id: 'a_cursor50',  name: 'Armée de Doigts', gems: 5,  desc: 'Possède 50 Curseurs RGB.',             check: (s) => B(s, 'cursor') >= 50 },
    { id: 'a_granny50',  name: 'Maison de Retraite E-sport', gems: 8,  desc: 'Possède 50 Mamies Gameuses.',          check: (s) => B(s, 'granny') >= 50 },
    { id: 'a_golden1',   name: 'Chercheur d\'Or', gems: 3,  desc: 'Attrape un cookie doré.',              check: (s) => s.stats.golden >= 1 },
    { id: 'a_golden10',  name: 'Pépite Hunter', gems: 8,  desc: 'Attrape 10 cookies dorés. Débloque le skin Cookie Doré.', check: (s) => s.stats.golden >= 10 },
    { id: 'a_golden50',  name: 'Midas du Cookie', gems: 20, desc: 'Attrape 50 cookies dorés.',            check: (s) => s.stats.golden >= 50 },
    { id: 'a_crit100',   name: 'Coup Critique !', gems: 5,  desc: '100 clics critiques.',                 check: (s) => s.stats.crits >= 100 },
    { id: 'a_combo50',   name: 'Combo Débloqué', gems: 3,  desc: 'Atteins un combo de 50.',              check: (s) => s.stats.maxCombo >= 50 },
    { id: 'a_combo150',  name: 'Ultra Combo', gems: 8,  desc: 'Atteins un combo de 150.',             check: (s) => s.stats.maxCombo >= 150 },
    { id: 'a_combo300',  name: 'C-C-C-COMBO BREAKER', gems: 15, desc: 'Atteins un combo de 300.',             check: (s) => s.stats.maxCombo >= 300 },
    { id: 'a_fever1',    name: 'FIÈVRE RGB', gems: 5,  desc: 'Déclenche le mode Fièvre.',            check: (s) => s.stats.fevers >= 1 },
    { id: 'a_fever10',   name: 'Accro à l\'Adrénaline', gems: 12, desc: 'Déclenche 10 fois la Fièvre.',         check: (s) => s.stats.fevers >= 10 },
    { id: 'a_boss1',     name: 'Tueur de Boss', gems: 8,  desc: 'Bats ton premier boss.',               check: (s) => s.stats.bossKills >= 1 },
    { id: 'a_boss10',    name: 'Chasseur de Boss', gems: 20, desc: 'Bats 10 boss.',                        check: (s) => s.stats.bossKills >= 10 },
    { id: 'a_mg_all',    name: 'Touche-à-Tout', gems: 10, desc: 'Joue aux 4 mini-jeux.',                check: (s) => ['ninja', 'flappy', 'rhythm', 'slots'].every((k) => s.mg[k] && s.mg[k].plays > 0) },
    { id: 'a_mg10',      name: 'Gamer Assidu', gems: 8,  desc: 'Termine 10 parties de mini-jeux.',     check: (s) => Object.values(s.mg).reduce((a, m) => a + (m.plays || 0), 0) >= 10 },
    { id: 'a_egg1',      name: 'C\'est un Œuf !', gems: 3,  desc: 'Fais éclore un œuf.',                  check: (s) => s.stats.eggs >= 1 },
    { id: 'a_egg10',     name: 'Éleveur Pro', gems: 10, desc: 'Fais éclore 10 œufs.',                 check: (s) => s.stats.eggs >= 10 },
    { id: 'a_legend',    name: 'LÉGENDAIRE !!', gems: 15, desc: 'Obtiens un pet légendaire.',           check: (s, c) => s.pets.some((p) => c.petDef(p.id).rarity === 'legendary') },
    { id: 'a_mythic',    name: 'MYTHIQUE ?!', gems: 30, desc: 'Obtiens un pet mythique.',             check: (s, c) => s.pets.some((p) => c.petDef(p.id).rarity === 'mythic') },
    { id: 'a_rebirth1',  name: 'Renaissance', gems: 15, desc: 'Fais ton premier Rebirth.',            check: (s) => s.rebirths >= 1 },
    { id: 'a_rebirth5',  name: 'Phénix Sucré', gems: 40, desc: 'Fais 5 Rebirths.',                     check: (s) => s.rebirths >= 5 },
    { id: 'a_skins4',    name: 'Fashion Week', gems: 8,  desc: 'Possède 4 skins de cookie.',           check: (s) => Object.keys(s.skinsOwned).length >= 4 },
    { id: 'a_quests10',  name: 'Quêteur', gems: 10, desc: 'Termine 10 quêtes.',                   check: (s) => s.stats.quests >= 10 },
    { id: 'a_upg20',     name: 'Collectionneur', gems: 10, desc: 'Achète 20 améliorations.',             check: (s) => Object.keys(s.upgrades).length >= 20 },
    { id: 'a_upg37',     name: 'FULL DRIP', gems: 40, desc: 'Achète toutes les améliorations.',     check: (s) => Object.keys(s.upgrades).length >= upgrades.length },
    { id: 'a_logo',      name: 'Curieux', gems: 5,  desc: 'Secret.', secret: true, hint: 'Clique 10 fois sur le logo.', check: (s) => s.flags.logo >= 10 },
    { id: 'a_night',     name: 'Noctambule', gems: 5,  desc: 'Secret.', secret: true, hint: 'Joue entre minuit et 5 h.',   check: () => { const h = new Date().getHours(); return h >= 0 && h < 5; } },
    { id: 'a_afk',       name: 'Mode AFK', gems: 5,  desc: 'Secret.', secret: true, hint: 'Ne clique pas pendant 3 minutes.', check: (s, c) => c.idleFor() >= 180 && c.cpsBase() > 0 },
  ];

  /* ───────────────────────── QUESTS ───────────────────────── */
  // type → how core tracks progress. n(s,c) picks a target. gems = reward.
  const quests = [
    { type: 'clicks',  text: 'Clique {n} fois sur le cookie', n: () => [100, 200, 350][Math.floor(Math.random() * 3)], gems: 6 },
    { type: 'bake',    text: 'Produis {n} cookies', n: (s, c) => Math.max(500, Math.round(c.cpsBase() * 150)), gems: 8, fmt: true },
    { type: 'buy',     text: 'Achète {n} bâtiments', n: () => [5, 10, 15][Math.floor(Math.random() * 3)], gems: 6 },
    { type: 'upgrade', text: 'Achète {n} amélioration(s)', n: () => 1 + Math.floor(Math.random() * 2), gems: 7 },
    { type: 'golden',  text: 'Attrape {n} cookie(s) doré(s)', n: () => 1 + Math.floor(Math.random() * 2), gems: 10 },
    { type: 'combo',   text: 'Atteins un combo de {n}', n: () => [40, 70, 100][Math.floor(Math.random() * 3)], gems: 8 },
    { type: 'crit',    text: 'Fais {n} clics critiques', n: () => [5, 10, 15][Math.floor(Math.random() * 3)], gems: 7 },
    { type: 'minigame',text: 'Termine {n} partie(s) de mini-jeu', n: () => 1 + Math.floor(Math.random() * 2), gems: 9, needs: 'minigame' },
    { type: 'boss',    text: 'Bats {n} boss', n: () => 1, gems: 14, needs: 'boss' },
    { type: 'fever',   text: 'Déclenche {n} Fièvre(s) RGB', n: () => 1, gems: 9 },
  ];

  /* ───────────────────────── NEWS TICKER ───────────────────────── */
  const news = [
    'BREAKING : une mamie gameuse atteint 400 APM sur un four à cookies.',
    'Un cookie ratio un brownie en direct. La toile s\'enflamme.',
    'Les experts confirment : ton cookie est littéralement le main character.',
    'Le lait annonce une collab exclusive avec ton cookie. Hype totale.',
    '« C\'est pas du sucre, c\'est de l\'aura » déclare le cookie.',
    'Les dentistes du monde entier demandent une pause. Demande refusée.',
    'Un brocoli a tenté d\'infiltrer la boulangerie. Il a été cancel.',
    'Ton cookie a plus d\'abonnés que toi. On dit ça, on dit rien.',
    'Record mondial : 1 million de clics sans toucher d\'herbe.',
    'Alerte météo : averses de pépites attendues cet après-midi.',
    'Le cookie passe en RGB. La gamer room de ton cousin est en PLS.',
    'Étude : le RGB augmente la productivité de 300 %. Source : tkt.',
    'Une mamie gameuse signe chez une grosse équipe e-sport.',
    'Pénurie de lait : les cookies trempent dans du jus d\'orange. L\'horreur.',
    'Le cookie a été vu en train de flex sa chaîne en or.',
    'Un streamer tente 24 h de cookie clicker. Son index demande l\'asile.',
    'La Banque Crypto lance le $CRUNCH. Ça pump.',
    '« No cap, ce cookie est bussin » — un critique gastronomique.',
    'Les curseurs réclament des congés payés. Refusés.',
    'Nouvelle étude : 9 cookies sur 10 préfèrent être cliqués.',
    'Le cookie doré a encore ghosté trois joueurs aujourd\'hui.',
    'Un chat choco a appris à cliquer. Il réclame un salaire.',
    'Le Portail Dimensionnel ramène un cookie d\'un univers fait de cookies. Rien ne change.',
    'Le Trou Noir aspire tout… sauf ton cookie. Respect.',
    'Mode Fièvre détecté dans ta ville. Restez hydratés.',
    'Le Brocoli Tyran jure de revenir. Personne n\'a peur.',
    'Sondage : 100 % des cookies votent pour plus de pépites.',
    'Le Stream 24/7 bat un record : 3 millions de « W » dans le chat.',
    'Ta mamie gameuse vient de te carry en ranked. Gênant.',
    'Beethoven aurait composé l\'Hymne à la Joie en mangeant un cookie. Source : tkt.',
    'Le Roi de la Montagne réclame des droits d\'auteur. Il est dans le domaine public, frérot.',
    'Tetris porte plainte : ton cookie empile trop bien les pépites.',
    'Nouveau skin Game Boy : les parents pleurent de nostalgie.',
    'Un cookie a été vu en train de faire la queue pour un concert de clavecin.',
    'Le Roi Brocoli exige un tribut de 10 000 fleurettes. Refusé.',
    'Un Céleri Ninja a été vu sur les toits. Il est très croquant.',
    'Le Cookie aux Raisins Traître prétend être aux pépites. Personne n\'est dupe.',
    'Le Nutribot 3000 a calculé tes calories. Il a planté.',
    'Rumeur : LE GRAND RÉGIME attend les boulangers les plus acharnés…',
    'La Balance Maudite affiche « ERREUR ». Victoire morale.',
    'Un Poulpe Glacé aperçu en train de cliquer avec ses 8 bras. Triche ?',
  ];

  /* ───────────────────────── MISC ───────────────────────── */
  const clickSounds = [
    { id: 'pop',    name: 'Pop' },
    { id: 'crunch', name: 'Crunch' },
    { id: 'laser',  name: 'Laser' },
    { id: 'chip',   name: '8-bit' },
    { id: 'bubble', name: 'Bulle' },
  ];

  CO.data = {
    megaBoss, finalBoss,
    buildings, visuals, upgrades, skins, themes, rarities, pets, eggs,
    golden, bosses, minigameUnlocks, achievements, quests, news, clickSounds,
  };
})();
