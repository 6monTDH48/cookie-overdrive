-- COOKIE OVERDRIVE — options payantes (Robux)
--
-- ⚠️ À CONFIGURER : crée chaque Game Pass et chaque Developer Product dans le
-- Creator Hub (create.roblox.com → ton expérience → Monétisation), puis colle
-- son ID numérique ci-dessous à la place du 0. Tant qu'un ID vaut 0, le bouton
-- s'affiche mais indique « Bientôt dispo ».
local M = {}

-- Game Passes : achat unique, permanent.
M.passes = {
	{ key = "DoubleCookies", id = 0, price = 199, emoji = "✖️2", name = "Cookies ×2", desc = "Double TOUTE ta production et tes clics. Pour toujours." },
	{ key = "AutoClicker", id = 0, price = 149, emoji = "🤖", name = "Auto-Clicker", desc = "Clique 6 fois par seconde tout seul (activable/désactivable)." },
	{ key = "VIP", id = 0, price = 299, emoji = "👑", name = "VIP", desc = "+2 emplacements de pets, gemmes ×1,5, skin VIP exclusif, tag VIP dans le chat." },
	{ key = "LuckyEggs", id = 0, price = 249, emoji = "🍀", name = "Œufs Chanceux", desc = "Chaque œuf a 30 % de chance d'être relancé en gardant le meilleur pet." },
	{ key = "GoldenMagnet", id = 0, price = 129, emoji = "🧲", name = "Aimant Doré", desc = "Cookies dorés 2× plus fréquents et effets 50 % plus longs." },
	{ key = "SkinPack", id = 0, price = 99, emoji = "🎨", name = "Pack Skins Exclusifs", desc = "Débloque les skins Cookie Robux et Plasma Overdrive." },
}

-- Developer Products : achats consommables, rachetables à volonté.
-- kind : gems (n gemmes) | cookies (n minutes de production, min. garanti) | boost (×mult pendant dur s) | fever
M.products = {
	{ key = "Gems100", id = 0, price = 49, emoji = "💎", name = "100 Gemmes", kind = "gems", n = 100 },
	{ key = "Gems550", id = 0, price = 199, emoji = "💎", name = "550 Gemmes", kind = "gems", n = 550, tag = "+10 % BONUS" },
	{ key = "Gems1500", id = 0, price = 449, emoji = "💎", name = "1 500 Gemmes", kind = "gems", n = 1500, tag = "MEILLEURE OFFRE" },
	{ key = "Cookies1h", id = 0, price = 39, emoji = "🍪", name = "Sac de Cookies", kind = "cookies", n = 60, desc = "1 h de production instantanée" },
	{ key = "Cookies12h", id = 0, price = 149, emoji = "🍪", name = "Camion de Cookies", kind = "cookies", n = 720, desc = "12 h de production instantanée" },
	{ key = "Boost3x", id = 0, price = 79, emoji = "⚡", name = "Boost ×3 (15 min)", kind = "boost", mult = 3, dur = 900 },
	{ key = "Fever", id = 0, price = 25, emoji = "🌈", name = "Fièvre RGB instantanée", kind = "fever" },
}

M.passByKey = {}
M.passById = {}
for _, p in M.passes do
	M.passByKey[p.key] = p
	if p.id ~= 0 then M.passById[p.id] = p end
end
M.productByKey = {}
M.productById = {}
for _, p in M.products do
	M.productByKey[p.key] = p
	if p.id ~= 0 then M.productById[p.id] = p end
end

return M
