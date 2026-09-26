-- COOKIE OVERDRIVE — données du jeu (portage Roblox de source/src/js/data.js)
local D = {}

D.buildings = {
	{ id = "cursor", name = "Curseur RGB", cost = 15, cps = 0.1, emoji = "👆", desc = "Clique tout seul. En RGB, évidemment." },
	{ id = "granny", name = "Mamie Gameuse", cost = 100, cps = 1, emoji = "👵", desc = "400 APM et un casque à oreilles de chat." },
	{ id = "farm", name = "Ferme à Pépites", cost = 1100, cps = 8, emoji = "🌾", desc = "Fait pousser des pépites bio (ou presque)." },
	{ id = "mine", name = "Mine de Choco", cost = 12000, cps = 47, emoji = "⛏️", desc = "Creuse des filons de chocolat noir 70 %." },
	{ id = "factory", name = "Usine Néon", cost = 130000, cps = 260, emoji = "🏭", desc = "Chaîne de montage éclairée comme une rave." },
	{ id = "bank", name = "Banque Crypto", cost = 1.4e6, cps = 1400, emoji = "🏦", desc = "Mine du $CRUNCH. Ça pump, ça dump, ça cuit." },
	{ id = "temple", name = "Temple Sucré", cost = 2e7, cps = 7800, emoji = "🛕", desc = "On y prie le Grand Cookie Originel." },
	{ id = "wizard", name = "Tour de Sorcier", cost = 3.3e8, cps = 44000, emoji = "🧙", desc = "Invoque des cookies. Parfois des grenouilles." },
	{ id = "rocket", name = "Fusée Cookie", cost = 5.1e9, cps = 260000, emoji = "🚀", desc = "Rapporte des cookies de la planète Biscuit." },
	{ id = "lab", name = "Labo Alchimie", cost = 7.5e10, cps = 1.6e6, emoji = "⚗️", desc = "Transforme l'or en cookies. Upgrade logique." },
	{ id = "portal", name = "Portail Dimensionnel", cost = 1e12, cps = 1e7, emoji = "🌀", desc = "Ouvre sur la Cookieverse. Ne pas regarder dedans." },
	{ id = "timemachine", name = "Machine Temporelle", cost = 1.4e13, cps = 6.5e7, emoji = "⏳", desc = "Vole des cookies à ton toi du futur." },
	{ id = "antimatter", name = "Condensateur Antimatière", cost = 1.7e14, cps = 4.3e8, emoji = "⚛️", desc = "Condense l'univers en pâte à cookie." },
	{ id = "prism", name = "Prisme RGB", cost = 2.1e15, cps = 2.9e9, emoji = "🔺", desc = "Convertit la lumière pure en cookies. Et en RGB." },
	{ id = "streamer", name = "Stream 24/7", cost = 2.6e16, cps = 2.1e10, emoji = "📺", desc = "Des millions de viewers spamment des cookies." },
}

-- Effets visuels 3D débloqués par les améliorations (max = niveau max)
D.visuals = {
	chips_xl = { max = 1 }, sprinkles = { max = 2 }, glaze = { max = 2 }, crystals = { max = 1 },
	rgb_rim = { max = 1 }, face = { max = 1 }, shades = { max = 1 }, crown = { max = 1 },
	headphones = { max = 1 }, bling = { max = 2 }, halo = { max = 1 }, wings = { max = 1 },
	laser_eyes = { max = 1 }, galaxy_core = { max = 1 }, holo = { max = 1 }, glitch = { max = 1 },
	afterimage = { max = 1 }, orbiters = { max = 3 }, saturn_ring = { max = 1 }, fire_aura = { max = 2 },
	lightning = { max = 1 }, shockwave = { max = 1 }, confetti_click = { max = 1 }, chat = { max = 1 },
	cursor_rgb = { max = 1 }, cookie_rain = { max = 1 }, disco = { max = 1 }, warp = { max = 1 },
	god_rays = { max = 1 }, black_hole = { max = 1 }, beat_pulse = { max = 1 },
}

-- fx: click, clickCps, bld+x, cps, crit, critX, goldenFreq, goldenDur, comboCap, feverDur
-- req: clicks | bld={id,n} | baked | golden | crits | combo
D.upgrades = {
	{ id = "pepites_xxl", name = "Pépites XXL", cost = 100, fx = { click = 2 }, req = { clicks = 15 }, vis = { "chips_xl", 1 } },
	{ id = "contour_rgb", name = "Contour RGB", cost = 150, fx = { bld = "cursor", x = 2 }, req = { bld = { "cursor", 1 } }, vis = { "rgb_rim", 1 } },
	{ id = "vermicelles", name = "Vermicelles Arc-en-ciel", cost = 1000, fx = { bld = "granny", x = 2 }, req = { bld = { "granny", 1 } }, vis = { "sprinkles", 1 } },
	{ id = "glacage", name = "Glaçage Bubblegum", cost = 2500, fx = { click = 2 }, req = { clicks = 150 }, vis = { "glaze", 1 } },
	{ id = "onde_choc", name = "Onde de Choc", cost = 6000, fx = { crit = 0.04 }, req = { clicks = 300 }, vis = { "shockwave", 1 } },
	{ id = "kawaii", name = "Visage Kawaii", cost = 11000, fx = { bld = "farm", x = 2 }, req = { bld = { "farm", 1 } }, vis = { "face", 1 } },
	{ id = "curseurs_turbo", name = "Curseurs Turbo", cost = 12000, fx = { bld = "cursor", x = 2 }, req = { bld = { "cursor", 25 } }, vis = { "cursor_rgb", 1 } },
	{ id = "deal_with_it", name = "Lunettes Deal With It", cost = 30000, fx = { bld = "cursor", x = 2, clickCps = 0.005 }, req = { bld = { "cursor", 10 } }, vis = { "shades", 1 } },
	{ id = "confettis", name = "Confettis de Clic", cost = 60000, fx = { click = 2 }, req = { clicks = 700 }, vis = { "confetti_click", 1 } },
	{ id = "mamies_speed", name = "Mamies Speedrun", cost = 80000, fx = { bld = "granny", x = 2 }, req = { bld = { "granny", 25 } }, vis = { "sprinkles", 1 } },
	{ id = "orbiteurs", name = "Mini-Cookies Orbitaux", cost = 120000, fx = { bld = "mine", x = 2 }, req = { bld = { "mine", 1 } }, vis = { "orbiters", 1 } },
	{ id = "casque", name = "Casque Gamer RGB", cost = 200000, fx = { bld = "granny", x = 2 }, req = { bld = { "granny", 10 } }, vis = { "headphones", 1 } },
	{ id = "pluie", name = "Pluie de Cookies", cost = 400000, fx = { cps = 1.1 }, req = { baked = 250000 }, vis = { "cookie_rain", 1 } },
	{ id = "tracteurs", name = "Tracteurs Néon", cost = 900000, fx = { bld = "farm", x = 2 }, req = { bld = { "farm", 25 } }, vis = { "glaze", 1 } },
	{ id = "couronne", name = "Couronne du Roi", cost = 1.3e6, fx = { bld = "factory", x = 2 }, req = { bld = { "factory", 1 } }, vis = { "crown", 1 } },
	{ id = "aura_feu", name = "Aura de Feu", cost = 2e6, fx = { comboCap = 2 }, req = { combo = 60 }, vis = { "fire_aura", 1 } },
	{ id = "foreuse", name = "Foreuse Diamant", cost = 1e7, fx = { bld = "mine", x = 2 }, req = { bld = { "mine", 25 } }, vis = { "crystals", 1 } },
	{ id = "chaine_or", name = "Chaîne en Or", cost = 1.4e7, fx = { bld = "bank", x = 2 }, req = { bld = { "bank", 1 } }, vis = { "bling", 1 } },
	{ id = "yeux_laser", name = "Yeux Laser", cost = 2.5e7, fx = { clickCps = 0.01 }, req = { clicks = 2500 }, vis = { "laser_eyes", 1 } },
	{ id = "usine_inferno", name = "Chaîne de Montage Inferno", cost = 1.1e8, fx = { bld = "factory", x = 2 }, req = { bld = { "factory", 25 } }, vis = { "fire_aura", 1 } },
	{ id = "saturne", name = "Anneau de Saturne", cost = 2e8, fx = { bld = "temple", x = 2 }, req = { bld = { "temple", 1 } }, vis = { "saturn_ring", 1 } },
	{ id = "eclairs", name = "Éclairs Statiques", cost = 3e8, fx = { critX = 2 }, req = { crits = 80 }, vis = { "lightning", 1 } },
	{ id = "halo", name = "Halo Divin", cost = 6e8, fx = { goldenFreq = 1.3 }, req = { golden = 5 }, vis = { "halo", 1 } },
	{ id = "bull_run", name = "Crypto Bull Run", cost = 1.2e9, fx = { bld = "bank", x = 2 }, req = { bld = { "bank", 25 } }, vis = { "bling", 1 } },
	{ id = "disco", name = "Boule Disco", cost = 3.3e9, fx = { bld = "wizard", x = 2 }, req = { bld = { "wizard", 1 } }, vis = { "disco", 1 } },
	{ id = "clic_quantique", name = "Clic Quantique", cost = 5e9, fx = { click = 2, clickCps = 0.03 }, req = { clicks = 10000 }, vis = { "orbiters", 1 } },
	{ id = "ailes", name = "Ailes Néon", cost = 8e9, fx = { cps = 1.15 }, req = { baked = 5e9 }, vis = { "wings", 1 } },
	{ id = "holo", name = "Shimmer Holographique", cost = 5.1e10, fx = { bld = "rocket", x = 2 }, req = { bld = { "rocket", 1 } }, vis = { "holo", 1 } },
	{ id = "glitch", name = "Glitch Mode", cost = 1e11, fx = { clickCps = 0.02 }, req = { clicks = 6000 }, vis = { "glitch", 1 } },
	{ id = "warp", name = "Vitesse Lumière", cost = 7.5e11, fx = { bld = "lab", x = 2 }, req = { bld = { "lab", 1 } }, vis = { "warp", 1 } },
	{ id = "rayons", name = "Rayons Divins", cost = 2e12, fx = { goldenDur = 1.5 }, req = { golden = 20 }, vis = { "god_rays", 1 } },
	{ id = "galaxie", name = "Cœur Galactique", cost = 1e13, fx = { bld = "portal", x = 2 }, req = { bld = { "portal", 1 } }, vis = { "galaxy_core", 1 } },
	{ id = "bass", name = "Bass Boost", cost = 5e13, fx = { feverDur = 1.5, comboCap = 3 }, req = { combo = 200 }, vis = { "beat_pulse", 1 } },
	{ id = "essaim", name = "Essaim Orbital", cost = 1.4e14, fx = { bld = "timemachine", x = 2 }, req = { bld = { "timemachine", 1 } }, vis = { "orbiters", 1 } },
	{ id = "trou_noir", name = "Trou Noir", cost = 1.7e15, fx = { bld = "antimatter", x = 2 }, req = { bld = { "antimatter", 1 } }, vis = { "black_hole", 1 } },
	{ id = "prisme", name = "Afterimage Prismatique", cost = 2.1e16, fx = { bld = "prism", x = 2, cps = 1.2 }, req = { bld = { "prism", 1 } }, vis = { "afterimage", 1 } },
	{ id = "chat_direct", name = "Chat en Direct", cost = 2.6e17, fx = { bld = "streamer", x = 2 }, req = { bld = { "streamer", 1 } }, vis = { "chat", 1 } },
}

-- Skins : couleurs du cookie 3D (base / pépites / contour) + matériau
D.skins = {
	{ id = "classic", name = "Classique", cost = 0, base = "#d99a4e", dark = "#a9652a", light = "#f3c783", chipHi = "#7a4424", chip = "#4a2511", rim = "#8a5220", material = "SmoothPlastic" },
	{ id = "double_choco", name = "Double Choco", cost = 15, base = "#6b3a1f", dark = "#3f1f0e", light = "#915833", chipHi = "#ffffff", chip = "#f5e6d0", rim = "#2e160a", material = "SmoothPlastic" },
	{ id = "red_velvet", name = "Red Velvet", cost = 25, base = "#c02640", dark = "#7a0f22", light = "#e8566c", chipHi = "#ffffff", chip = "#fff3e6", rim = "#5e0a1a", material = "SmoothPlastic" },
	{ id = "matcha", name = "Matcha Zen", cost = 25, base = "#8dbf5a", dark = "#5e8a34", light = "#bde38f", chipHi = "#ffffff", chip = "#f7f2e0", rim = "#466a24", material = "SmoothPlastic" },
	{ id = "pixel", name = "Pixel 8-bit", cost = 40, base = "#e0a050", dark = "#9c5a1c", light = "#ffd08a", chipHi = "#6e3a1c", chip = "#3a1c0c", rim = "#1a0b33", material = "Brick" },
	{ id = "lava", name = "Magma", cost = 60, base = "#2a1210", dark = "#140806", light = "#4a221c", chipHi = "#ffd000", chip = "#ff6a00", rim = "#ff3d00", material = "CrackedLava" },
	{ id = "galaxy", name = "Galaxie", cost = 80, base = "#2b1060", dark = "#120530", light = "#6a3cc9", chipHi = "#9ff6ff", chip = "#ff5ef0", rim = "#b16bff", material = "Neon" },
	{ id = "diamond", name = "Diamant", cost = 120, base = "#9ff3ff", dark = "#3fb6d9", light = "#ffffff", chipHi = "#ffffff", chip = "#e0fbff", rim = "#63d6f0", material = "Glass" },
	{ id = "hologram", name = "Hologramme", cost = 150, base = "#39f0ff", dark = "#0b6d8a", light = "#b7fbff", chipHi = "#ffffff", chip = "#ff4fe1", rim = "#39f0ff", material = "ForceField" },
	{ id = "golden", name = "Cookie Doré", cost = 0, unlock = { ach = "a_golden10", text = "Attrape 10 cookies dorés" }, base = "#ffcc33", dark = "#c98a00", light = "#fff2a8", chipHi = "#ffe07a", chip = "#b36b00", rim = "#8a5a00", material = "Foil" },
	{ id = "rainbow", name = "Arc-en-ciel RGB", cost = 250, base = "#ff4fd8", dark = "#7a2cff", light = "#ffffff", chipHi = "#5a3a8a", chip = "#1a0b33", rim = "#ffffff", material = "Neon", rgb = true },
	{ id = "void", name = "Néant", cost = 0, unlock = { rebirths = 3, text = "Fais 3 Rebirths" }, base = "#07030f", dark = "#000000", light = "#1d1033", chipHi = "#ffffff", chip = "#b16bff", rim = "#b16bff", material = "Slate" },
	-- Skins exclusifs aux Game Passes / produits Robux
	{ id = "vip", name = "VIP Diamant Rose", cost = 0, unlock = { pass = "VIP", text = "Game Pass VIP" }, base = "#ff2bd6", dark = "#a0108a", light = "#ff9cf0", chipHi = "#ffffff", chip = "#ffffff", rim = "#ffc93c", material = "Glass", rgb = false },
	{ id = "robux", name = "Cookie Robux", cost = 0, unlock = { pass = "SkinPack", text = "Pack Skins Exclusifs" }, base = "#2bdc6a", dark = "#138a3c", light = "#9dffc0", chipHi = "#4a4a6a", chip = "#0b0620", rim = "#ffffff", material = "Foil" },
	{ id = "plasma", name = "Plasma Overdrive", cost = 0, unlock = { pass = "SkinPack", text = "Pack Skins Exclusifs" }, base = "#1ff4ff", dark = "#0b6d8a", light = "#b7fbff", chipHi = "#ffffff", chip = "#ff2bd6", rim = "#8a5cff", material = "Neon", rgb = true },
}

-- Thèmes : ambiance de la Lighting + couleur du sol
D.themes = {
	{ id = "synthwave", name = "Synthwave", cost = 0, ambient = "#6b1a8f", floor = "#120428", fog = "#ff3d9a" },
	{ id = "galaxy", name = "Nébuleuse", cost = 30, ambient = "#7a2cff", floor = "#070214", fog = "#2b1060" },
	{ id = "matrix", name = "Matrice Sucrée", cost = 40, ambient = "#00ff88", floor = "#010a06", fog = "#003a1c" },
	{ id = "candy", name = "Candy Pop", cost = 40, ambient = "#ffb3e6", floor = "#b3e5ff", fog = "#fff3b3" },
	{ id = "inferno", name = "Inferno", cost = 60, ambient = "#ff6a00", floor = "#1a0202", fog = "#a0100a" },
	{ id = "aurora", name = "Aurore Boréale", cost = 80, ambient = "#0bd6a0", floor = "#02101a", fog = "#5b3cff" },
}

D.rarities = {
	common = { name = "Commun", color = "#b8c4d9", rank = 0 },
	rare = { name = "Rare", color = "#3d9bff", rank = 1 },
	epic = { name = "Épique", color = "#b14dff", rank = 2 },
	legendary = { name = "Légendaire", color = "#ffb800", rank = 3 },
	mythic = { name = "Mythique", color = "#ff2bd6", rank = 4 },
}

D.pets = {
	{ id = "hamster", name = "Hamster Crunch", emoji = "🐹", rarity = "common", bonus = { click = 0.06 } },
	{ id = "frog", name = "Crapaud Crêpe", emoji = "🐸", rarity = "common", bonus = { cps = 0.06 } },
	{ id = "chick", name = "Poussin Beurre", emoji = "🐥", rarity = "common", bonus = { all = 0.04 } },
	{ id = "cat", name = "Chat Choco", emoji = "🐱", rarity = "rare", bonus = { cps = 0.15 } },
	{ id = "dog", name = "Doggo Biscuit", emoji = "🐶", rarity = "rare", bonus = { click = 0.15 } },
	{ id = "fox", name = "Renard Caramel", emoji = "🦊", rarity = "rare", bonus = { all = 0.1 } },
	{ id = "panda", name = "Panda Pépite", emoji = "🐼", rarity = "epic", bonus = { cps = 0.3 } },
	{ id = "octopus", name = "Poulpe Glacé", emoji = "🐙", rarity = "epic", bonus = { click = 0.3, crit = 0.02 } },
	{ id = "owl", name = "Hibou Sucré", emoji = "🦉", rarity = "epic", bonus = { all = 0.15, golden = 1.15 } },
	{ id = "unicorn", name = "Licorne RGB", emoji = "🦄", rarity = "legendary", bonus = { all = 0.5 } },
	{ id = "dragon", name = "Dragon Cramé", emoji = "🐉", rarity = "legendary", bonus = { click = 0.8, crit = 0.03 } },
	{ id = "robot", name = "Robot Cuiseur", emoji = "🤖", rarity = "legendary", bonus = { cps = 0.8 } },
	{ id = "glitchy", name = "Glitchy", emoji = "👾", rarity = "mythic", bonus = { all = 1.0, crit = 0.05 } },
	{ id = "whale", name = "Baleine Lactée", emoji = "🐋", rarity = "mythic", bonus = { cps = 1.5, golden = 1.25 } },
}

-- odds : liste ordonnée {rareté, poids} (les probabilités sont affichées dans l'UI)
D.eggs = {
	{ id = "basic", name = "Œuf Basique", cost = 30, color = "#ffd79a", odds = { { "common", 70 }, { "rare", 25 }, { "epic", 5 } } },
	{ id = "neon", name = "Œuf Néon", cost = 120, color = "#ff2bd6", odds = { { "rare", 55 }, { "epic", 35 }, { "legendary", 10 } } },
	{ id = "cosmic", name = "Œuf Cosmique", cost = 400, color = "#7a2cff", odds = { { "epic", 50 }, { "legendary", 40 }, { "mythic", 10 } } },
}

D.golden = {
	{ kind = "lucky", weight = 40, label = "CHANCEUX !", color = "#ffd23c" },
	{ kind = "frenzy", weight = 30, label = "FRÉNÉSIE ×7", color = "#ff5a1f", buff = { id = "frenzy", name = "Frénésie", emoji = "🔥", dur = 30, cps = 7 } },
	{ kind = "clickstorm", weight = 14, label = "CLIC-TEMPÊTE ×77", color = "#1ff4ff", buff = { id = "clickstorm", name = "Clic-Tempête", emoji = "🌪️", dur = 10, click = 77 } },
	{ kind = "rgbstorm", weight = 8, label = "RGB STORM", color = "#ff2bd6" },
	{ kind = "gems", weight = 8, label = "PLUIE DE GEMMES", color = "#3dffb0" },
}

D.bosses = {
	{ id = "broccoli", name = "Brocoli Tyran", emoji = "🥦", color = "#3dff6a" },
	{ id = "dentist", name = "Dentiste Suprême", emoji = "🦷", color = "#e8f4ff" },
	{ id = "salad", name = "Salade Détox", emoji = "🥗", color = "#9dff3d" },
	{ id = "rat", name = "Rat des Placards", emoji = "🐀", color = "#b0a0c0" },
	{ id = "lemon", name = "Citron Acide", emoji = "🍋", color = "#fff23d" },
	{ id = "salt", name = "Salière Maléfique", emoji = "🧂", color = "#ffffff" },
	{ id = "ghost", name = "Fantôme du Régime", emoji = "👻", color = "#c9b6ff" },
}

D.minigames = {
	{ id = "ninja", name = "Cookie Ninja", emoji = "🥷", baked = 50, text = "Produis 50 cookies" },
	{ id = "flappy", name = "Flappy Cookie", emoji = "🐤", baked = 1000, text = "Produis 1 000 cookies" },
	{ id = "rhythm", name = "Crunch Rythme", emoji = "🎵", baked = 25000, text = "Produis 25 000 cookies" },
	{ id = "slots", name = "Casino Crumble", emoji = "🎰", baked = 250000, text = "Produis 250 000 cookies" },
}

-- Succès : check(state, api) — api fournit cpsBase, petDef, totalBuildings
D.achievements = {
	{ id = "a_click1", name = "Premier Crunch", gems = 1, desc = "Clique sur le cookie.", check = function(s) return s.clicks >= 1 end },
	{ id = "a_click100", name = "Doigt Chaud", gems = 3, desc = "100 clics.", check = function(s) return s.clicks >= 100 end },
	{ id = "a_click1k", name = "Tendinite Speedrun", gems = 5, desc = "1 000 clics.", check = function(s) return s.clicks >= 1000 end },
	{ id = "a_click10k", name = "Clavier Mécanique Humain", gems = 10, desc = "10 000 clics.", check = function(s) return s.clicks >= 10000 end },
	{ id = "a_click50k", name = "Ce N'est Plus un Jeu", gems = 25, desc = "50 000 clics.", check = function(s) return s.clicks >= 50000 end },
	{ id = "a_bake100", name = "Petite Fournée", gems = 1, desc = "Produis 100 cookies.", check = function(s) return s.allTimeBaked >= 100 end },
	{ id = "a_bake1k", name = "Boulanger du Dimanche", gems = 3, desc = "Produis 1 000 cookies.", check = function(s) return s.allTimeBaked >= 1e3 end },
	{ id = "a_bake10k", name = "Influenceur Cookie", gems = 5, desc = "Produis 10 000 cookies.", check = function(s) return s.allTimeBaked >= 1e4 end },
	{ id = "a_bake100k", name = "Startup Sucrée", gems = 8, desc = "Produis 100 000 cookies.", check = function(s) return s.allTimeBaked >= 1e5 end },
	{ id = "a_bake1m", name = "MILLIONNAIRE", gems = 12, desc = "Produis 1 million de cookies.", check = function(s) return s.allTimeBaked >= 1e6 end },
	{ id = "a_bake100m", name = "Licorne de la Tech", gems = 20, desc = "Produis 100 millions de cookies.", check = function(s) return s.allTimeBaked >= 1e8 end },
	{ id = "a_bake1b", name = "Milliardaire Croustillant", gems = 30, desc = "Produis 1 milliard de cookies.", check = function(s) return s.allTimeBaked >= 1e9 end },
	{ id = "a_bake1t", name = "L'Économie, C'est Moi", gems = 50, desc = "Produis 1 000 milliards de cookies.", check = function(s) return s.allTimeBaked >= 1e12 end },
	{ id = "a_cps10", name = "Ça Tourne Tout Seul", gems = 3, desc = "10 cookies/seconde.", check = function(_, c) return c.cpsBase() >= 10 end },
	{ id = "a_cps1k", name = "Machine de Guerre", gems = 8, desc = "1 000 cookies/seconde.", check = function(_, c) return c.cpsBase() >= 1e3 end },
	{ id = "a_cps100k", name = "Usine à Gaz Sucré", gems = 15, desc = "100 000 cookies/seconde.", check = function(_, c) return c.cpsBase() >= 1e5 end },
	{ id = "a_cps10m", name = "Singularité Cookie", gems = 30, desc = "10 millions de cookies/seconde.", check = function(_, c) return c.cpsBase() >= 1e7 end },
	{ id = "a_b50", name = "Promoteur Immobilier", gems = 5, desc = "Possède 50 bâtiments.", check = function(_, c) return c.totalBuildings() >= 50 end },
	{ id = "a_b200", name = "Ville Cookie", gems = 15, desc = "Possède 200 bâtiments.", check = function(_, c) return c.totalBuildings() >= 200 end },
	{ id = "a_b500", name = "Métropole RGB", gems = 30, desc = "Possède 500 bâtiments.", check = function(_, c) return c.totalBuildings() >= 500 end },
	{ id = "a_cursor50", name = "Armée de Doigts", gems = 5, desc = "Possède 50 Curseurs RGB.", check = function(s) return (s.buildings.cursor or 0) >= 50 end },
	{ id = "a_granny50", name = "Maison de Retraite E-sport", gems = 8, desc = "Possède 50 Mamies Gameuses.", check = function(s) return (s.buildings.granny or 0) >= 50 end },
	{ id = "a_golden1", name = "Chercheur d'Or", gems = 3, desc = "Attrape un cookie doré.", check = function(s) return s.stats.golden >= 1 end },
	{ id = "a_golden10", name = "Pépite Hunter", gems = 8, desc = "Attrape 10 cookies dorés. Débloque le skin Cookie Doré.", check = function(s) return s.stats.golden >= 10 end },
	{ id = "a_golden50", name = "Midas du Cookie", gems = 20, desc = "Attrape 50 cookies dorés.", check = function(s) return s.stats.golden >= 50 end },
	{ id = "a_crit100", name = "Coup Critique !", gems = 5, desc = "100 clics critiques.", check = function(s) return s.stats.crits >= 100 end },
	{ id = "a_combo50", name = "Combo Débloqué", gems = 3, desc = "Atteins un combo de 50.", check = function(s) return s.stats.maxCombo >= 50 end },
	{ id = "a_combo150", name = "Ultra Combo", gems = 8, desc = "Atteins un combo de 150.", check = function(s) return s.stats.maxCombo >= 150 end },
	{ id = "a_combo300", name = "C-C-C-COMBO BREAKER", gems = 15, desc = "Atteins un combo de 300.", check = function(s) return s.stats.maxCombo >= 300 end },
	{ id = "a_fever1", name = "FIÈVRE RGB", gems = 5, desc = "Déclenche le mode Fièvre.", check = function(s) return s.stats.fevers >= 1 end },
	{ id = "a_fever10", name = "Accro à l'Adrénaline", gems = 12, desc = "Déclenche 10 fois la Fièvre.", check = function(s) return s.stats.fevers >= 10 end },
	{ id = "a_boss1", name = "Tueur de Boss", gems = 8, desc = "Bats ton premier boss.", check = function(s) return s.stats.bossKills >= 1 end },
	{ id = "a_boss10", name = "Chasseur de Boss", gems = 20, desc = "Bats 10 boss.", check = function(s) return s.stats.bossKills >= 10 end },
	{ id = "a_mg_all", name = "Touche-à-Tout", gems = 10, desc = "Joue aux 4 mini-jeux.", check = function(s)
		for _, k in { "ninja", "flappy", "rhythm", "slots" } do
			if not (s.mg[k] and s.mg[k].plays > 0) then return false end
		end
		return true
	end },
	{ id = "a_mg10", name = "Gamer Assidu", gems = 8, desc = "Termine 10 parties de mini-jeux.", check = function(s)
		local n = 0
		for _, m in s.mg do n += m.plays or 0 end
		return n >= 10
	end },
	{ id = "a_egg1", name = "C'est un Œuf !", gems = 3, desc = "Fais éclore un œuf.", check = function(s) return s.stats.eggs >= 1 end },
	{ id = "a_egg10", name = "Éleveur Pro", gems = 10, desc = "Fais éclore 10 œufs.", check = function(s) return s.stats.eggs >= 10 end },
	{ id = "a_legend", name = "LÉGENDAIRE !!", gems = 15, desc = "Obtiens un pet légendaire.", check = function(s, c)
		for _, p in s.pets do if c.petDef(p.id).rarity == "legendary" then return true end end
		return false
	end },
	{ id = "a_mythic", name = "MYTHIQUE ?!", gems = 30, desc = "Obtiens un pet mythique.", check = function(s, c)
		for _, p in s.pets do if c.petDef(p.id).rarity == "mythic" then return true end end
		return false
	end },
	{ id = "a_rebirth1", name = "Renaissance", gems = 15, desc = "Fais ton premier Rebirth.", check = function(s) return s.rebirths >= 1 end },
	{ id = "a_rebirth5", name = "Phénix Sucré", gems = 40, desc = "Fais 5 Rebirths.", check = function(s) return s.rebirths >= 5 end },
	{ id = "a_skins4", name = "Fashion Week", gems = 8, desc = "Possède 4 skins de cookie.", check = function(s)
		local n = 0
		for _ in s.skinsOwned do n += 1 end
		return n >= 4
	end },
	{ id = "a_quests10", name = "Quêteur", gems = 10, desc = "Termine 10 quêtes.", check = function(s) return s.stats.quests >= 10 end },
	{ id = "a_upg20", name = "Collectionneur", gems = 10, desc = "Achète 20 améliorations.", check = function(_, c) return c.upgradeCount() >= 20 end },
	{ id = "a_upg37", name = "FULL DRIP", gems = 40, desc = "Achète toutes les améliorations.", check = function(_, c) return c.upgradeCount() >= 37 end },
	{ id = "a_afk", name = "Mode AFK", gems = 5, desc = "Secret : ne clique pas pendant 3 minutes.", check = function(_, c) return c.idleFor() >= 180 and c.cpsBase() > 0 end },
}

-- Quêtes : n(state, api) donne l'objectif
D.quests = {
	{ type = "clicks", text = "Clique {n} fois sur le cookie", gems = 6, n = function() return ({ 100, 200, 350 })[math.random(3)] end },
	{ type = "bake", text = "Produis {n} cookies", gems = 8, fmt = true, n = function(_, c) return math.max(500, math.floor(c.cpsBase() * 150)) end },
	{ type = "buy", text = "Achète {n} bâtiments", gems = 6, n = function() return ({ 5, 10, 15 })[math.random(3)] end },
	{ type = "upgrade", text = "Achète {n} amélioration(s)", gems = 7, n = function() return math.random(1, 2) end },
	{ type = "golden", text = "Attrape {n} cookie(s) doré(s)", gems = 10, n = function() return math.random(1, 2) end },
	{ type = "combo", text = "Atteins un combo de {n}", gems = 8, n = function() return ({ 40, 70, 100 })[math.random(3)] end },
	{ type = "crit", text = "Fais {n} clics critiques", gems = 7, n = function() return ({ 5, 10, 15 })[math.random(3)] end },
	{ type = "minigame", text = "Termine {n} partie(s) de mini-jeu", gems = 9, needs = "minigame", n = function() return math.random(1, 2) end },
	{ type = "boss", text = "Bats {n} boss", gems = 14, needs = "boss", n = function() return 1 end },
	{ type = "fever", text = "Déclenche {n} Fièvre(s) RGB", gems = 9, n = function() return 1 end },
}

D.news = {
	"BREAKING : une mamie gameuse atteint 400 APM sur un four à cookies.",
	"Un cookie ratio un brownie en direct. La toile s'enflamme.",
	"Les experts confirment : ton cookie est littéralement le main character.",
	"Le lait annonce une collab exclusive avec ton cookie. Hype totale.",
	"« C'est pas du sucre, c'est de l'aura » déclare le cookie.",
	"Les dentistes du monde entier demandent une pause. Demande refusée.",
	"Un brocoli a tenté d'infiltrer la boulangerie. Il a été cancel.",
	"Record mondial : 1 million de clics sans toucher d'herbe.",
	"Alerte météo : averses de pépites attendues cet après-midi.",
	"Étude : le RGB augmente la productivité de 300 %. Source : tkt.",
	"La Banque Crypto lance le $CRUNCH. Ça pump.",
	"« No cap, ce cookie est bussin » — un critique gastronomique.",
	"Les curseurs réclament des congés payés. Refusés.",
	"Le cookie doré a encore ghosté trois joueurs aujourd'hui.",
	"Mode Fièvre détecté dans ton serveur. Restez hydratés.",
	"Le Stream 24/7 bat un record : 3 millions de « W » dans le chat.",
	"Ta mamie gameuse vient de te carry en ranked. Gênant.",
}

-- Helpers
local function index(list)
	local t = {}
	for _, v in list do t[v.id] = v end
	return t
end
D.BLD = index(D.buildings)
D.UPG = index(D.upgrades)
D.SKIN = index(D.skins)
D.THEME = index(D.themes)
D.PET = index(D.pets)
D.EGG = index(D.eggs)
D.ACH = index(D.achievements)
D.MG = index(D.minigames)

-- Formatage des nombres (courts, style simulateur Roblox)
local SUF = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "UDc", "DDc", "TDc" }
function D.fmt(n)
	if n ~= n then return "0" end
	if n < 1000 then
		if n < 10 and n % 1 ~= 0 then return (string.gsub(string.format("%.1f", n), "%.", ",")) end
		return tostring(math.floor(n))
	end
	local e = math.floor(math.log10(n) / 3)
	if e >= #SUF then return string.format("%.2e", n) end
	local v = n / 10 ^ (e * 3)
	local s = v >= 100 and string.format("%.0f", v) or v >= 10 and string.format("%.1f", v) or string.format("%.2f", v)
	if string.find(s, "%.") then s = string.gsub(string.gsub(s, "0+$", ""), "%.$", "") end
	return (string.gsub(s, "%.", ",")) .. " " .. SUF[e + 1]
end

function D.color(hex)
	return Color3.fromHex(hex)
end

return D
