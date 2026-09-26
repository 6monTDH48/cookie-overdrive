-- COOKIE OVERDRIVE — formules d'économie partagées (serveur = autorité, client = affichage)
local D = require(script.Parent.GameData)
local E = {}

E.GROWTH = 1.14
E.BLD_POWER = 1.5
E.FEVER_AT = 120
E.FEVER_MULT = 3
E.REBIRTH_MIN = 1e6
E.BASE_PET_SLOTS = 3
E.BOSS_UNLOCK = 5000
E.GIFT_EVERY = 8 * 60

function E.defaultState()
	local b = {}
	for _, d in D.buildings do b[d.id] = 0 end
	return {
		v = 1,
		cookies = 0, totalBaked = 0, allTimeBaked = 0, clicks = 0,
		gems = 0, rebirths = 0, stars = 0,
		buildings = b, upgrades = {},
		skin = "classic", skinsOwned = { classic = true },
		theme = "synthwave", themesOwned = { synthwave = true },
		pets = {}, equipped = {}, petUid = 1,
		achievements = {}, quests = {}, questUid = 1,
		mg = {},
		nextGift = 0,
		boostUntil = 0, boostMult = 1,
		autoClick = true,
		receipts = {},
		stats = { golden = 0, crits = 0, maxCombo = 0, fevers = 0, bossKills = 0, eggs = 0, quests = 0, playTime = 0, robuxSpent = 0 },
		lastSave = os.time(),
	}
end

-- Remplit les champs manquants d'une sauvegarde plus ancienne
function E.merge(def, src)
	if type(src) ~= "table" then return def end
	for k, v in def do
		if src[k] == nil then
			src[k] = v
		elseif type(v) == "table" and type(src[k]) == "table" and next(v) ~= nil and #v == 0 then
			E.merge(v, src[k])
		end
	end
	return src
end

function E.petDef(id) return D.PET[id] end

function E.petSlots(passes)
	return E.BASE_PET_SLOTS + (passes.VIP and 2 or 0)
end

function E.equippedPets(s)
	local out = {}
	for _, uid in s.equipped do
		for _, p in s.pets do
			if p.uid == uid and D.PET[p.id] then
				table.insert(out, { uid = p.uid, lvl = p.lvl, def = D.PET[p.id] })
				break
			end
		end
	end
	return out
end

-- Calcule tous les multiplicateurs dérivés. passes = {key=true}
function E.recalc(s, passes)
	local M = { click = 1, clickCps = 0, bld = {}, cps = 1, crit = 0.03, critX = 10, goldenFreq = 1, goldenDur = 1, comboCap = 3, feverDur = 8 }
	for _, b in D.buildings do M.bld[b.id] = 1 end
	local vis = {}
	for _, u in D.upgrades do
		if s.upgrades[u.id] then
			local fx = u.fx
			if fx.click then M.click *= fx.click end
			if fx.clickCps then M.clickCps += fx.clickCps end
			if fx.bld then M.bld[fx.bld] *= fx.x or 1 end
			if fx.cps then M.cps *= fx.cps end
			if fx.crit then M.crit += fx.crit end
			if fx.critX then M.critX *= fx.critX end
			if fx.goldenFreq then M.goldenFreq *= fx.goldenFreq end
			if fx.goldenDur then M.goldenDur *= fx.goldenDur end
			if fx.comboCap then M.comboCap += fx.comboCap end
			if fx.feverDur then M.feverDur *= fx.feverDur end
			if u.vis then
				local k, l = u.vis[1], u.vis[2]
				local max = (D.visuals[k] and D.visuals[k].max) or 1
				vis[k] = math.min(max, (vis[k] or 0) + l)
			end
		end
	end
	local pc, pk = 0, 0
	for _, p in E.equippedPets(s) do
		local b, lv = p.def.bonus, 1 + 0.5 * (p.lvl - 1)
		if b.cps then pc += b.cps * lv end
		if b.click then pk += b.click * lv end
		if b.all then pc += b.all * lv; pk += b.all * lv end
		if b.crit then M.crit += b.crit end
		if b.golden then M.goldenFreq *= b.golden end
	end
	M.petCps = 1 + pc
	M.petClick = 1 + pk
	M.star = 1 + 0.1 * s.stars
	local nAch = 0
	for _ in s.achievements do nAch += 1 end
	M.ach = 1 + 0.01 * nAch
	-- Game Passes
	M.pass = passes.DoubleCookies and 2 or 1
	if passes.GoldenMagnet then M.goldenFreq *= 2; M.goldenDur *= 1.5 end
	M.vis = vis
	return M
end

-- Boost acheté (Developer Product) encore actif ?
function E.boostMult(s)
	return (s.boostUntil or 0) > os.time() and (s.boostMult or 1) or 1
end

function E.cpsBase(s, M)
	local t = 0
	for _, d in D.buildings do
		local n = s.buildings[d.id] or 0
		if n > 0 then t += d.cps * n * M.bld[d.id] end
	end
	return t * E.BLD_POWER * M.cps * M.petCps * M.star * M.ach * M.pass * E.boostMult(s)
end

function E.buildingCps(s, M, id)
	return D.BLD[id].cps * E.BLD_POWER * M.bld[id] * M.cps * M.petCps * M.star * M.ach * M.pass * E.boostMult(s)
end

-- buffMul(key) et feverActive viennent de l'état live (serveur)
function E.cpsNow(s, M, buffs, fever)
	local m = 1
	for _, b in buffs do m *= b.cps or 1 end
	return E.cpsBase(s, M) * m * (fever and E.FEVER_MULT or 1)
end

function E.clickValue(s, M, buffs, fever)
	local cm, km = 1, 1
	for _, b in buffs do cm *= b.cps or 1; km *= b.click or 1 end
	local base = M.click + E.cpsBase(s, M) * cm * M.clickCps
	return base * M.petClick * M.star * M.pass * E.boostMult(s) * km * (fever and E.FEVER_MULT or 1)
end

function E.comboMultFor(M, count)
	return 1 + math.min(M.comboCap - 1, math.floor(count / 15) * 0.5)
end

function E.bCost(id, n, owned)
	local d = D.BLD[id]
	local g = E.GROWTH
	return math.ceil(d.cost * g ^ owned * (g ^ n - 1) / (g - 1) - 1e-6)
end

function E.bMax(s, id)
	local d = D.BLD[id]
	local o = s.buildings[id] or 0
	local c0 = d.cost * E.GROWTH ^ o
	local n = math.floor(math.log(s.cookies * (E.GROWTH - 1) / c0 + 1) / math.log(E.GROWTH))
	return math.max(0, n)
end

function E.buildingUnlocked(s, i)
	if i <= 2 then return true end
	local id, prev = D.buildings[i].id, D.buildings[i - 1].id
	return (s.buildings[id] or 0) > 0 or (s.buildings[prev] or 0) > 0 or s.allTimeBaked >= D.buildings[i].cost * 0.4
end

function E.reqMet(s, u)
	local r = u.req or {}
	if r.clicks and s.clicks < r.clicks then return false end
	if r.bld and (s.buildings[r.bld[1]] or 0) < r.bld[2] then return false end
	if r.baked and s.totalBaked < r.baked then return false end
	if r.golden and s.stats.golden < r.golden then return false end
	if r.crits and s.stats.crits < r.crits then return false end
	if r.combo and s.stats.maxCombo < r.combo then return false end
	return true
end

function E.reqText(u)
	local r = u.req or {}
	if r.clicks then return "Clique " .. D.fmt(r.clicks) .. " fois" end
	if r.bld then return "Possède " .. r.bld[2] .. " × " .. D.BLD[r.bld[1]].name end
	if r.baked then return "Produis " .. D.fmt(r.baked) .. " cookies" end
	if r.golden then return "Attrape " .. r.golden .. " cookies dorés" end
	if r.crits then return "Fais " .. r.crits .. " clics critiques" end
	if r.combo then return "Atteins un combo de " .. r.combo end
	return ""
end

function E.fxText(u)
	local fx, out = u.fx, {}
	if fx.bld then table.insert(out, D.BLD[fx.bld].name .. " ×" .. fx.x) end
	if fx.click then table.insert(out, "Clic ×" .. fx.click) end
	if fx.clickCps then table.insert(out, "Clic +" .. (fx.clickCps * 100) .. " % du CPS") end
	if fx.cps then table.insert(out, "Production +" .. math.floor((fx.cps - 1) * 100 + 0.5) .. " %") end
	if fx.crit then table.insert(out, "Critique +" .. math.floor(fx.crit * 100 + 0.5) .. " %") end
	if fx.critX then table.insert(out, "Dégâts critiques ×" .. fx.critX) end
	if fx.goldenFreq then table.insert(out, "Dorés +" .. math.floor((fx.goldenFreq - 1) * 100 + 0.5) .. " % plus fréquents") end
	if fx.goldenDur then table.insert(out, "Effets dorés +" .. math.floor((fx.goldenDur - 1) * 100 + 0.5) .. " %") end
	if fx.comboCap then table.insert(out, "Combo max +×" .. fx.comboCap / 2) end
	if fx.feverDur then table.insert(out, "Fièvre +" .. math.floor((fx.feverDur - 1) * 100 + 0.5) .. " %") end
	return table.concat(out, " · ")
end

function E.petPower(p)
	local b, lv, out = D.PET[p.id].bonus, 1 + 0.5 * (p.lvl - 1), {}
	if b.all then table.insert(out, "Tout +" .. math.floor(b.all * lv * 100 + 0.5) .. " %") end
	if b.cps then table.insert(out, "Prod. +" .. math.floor(b.cps * lv * 100 + 0.5) .. " %") end
	if b.click then table.insert(out, "Clic +" .. math.floor(b.click * lv * 100 + 0.5) .. " %") end
	if b.crit then table.insert(out, "Crit +" .. math.floor(b.crit * 100 + 0.5) .. " %") end
	if b.golden then table.insert(out, "Dorés +" .. math.floor((b.golden - 1) * 100 + 0.5) .. " %") end
	return table.concat(out, " · ")
end

function E.rebirthGain(s)
	return math.floor(math.sqrt(s.totalBaked / E.REBIRTH_MIN))
end

function E.minigameUnlocked(s, id)
	local m = D.MG[id]
	return m ~= nil and s.allTimeBaked >= m.baked
end

function E.unit(s, M)
	return math.max(25, E.cpsBase(s, M) * 60, E.clickValue(s, M, {}, false) * 90)
end

function E.skinUnlockMet(s, sk, passes)
	local u = sk.unlock
	if not u then return true end
	if u.ach then return s.achievements[u.ach] ~= nil end
	if u.rebirths then return s.rebirths >= u.rebirths end
	if u.pass then return passes[u.pass] == true end
	return false
end

return E
