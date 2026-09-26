-- COOKIE OVERDRIVE — serveur (autorité sur l'économie, les sauvegardes et les achats Robux)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local D = require(Shared.GameData)
local E = require(Shared.Econ)
local Shop = require(Shared.Monetization)
local World = require(script.Parent.World)

--------------------------------------------------------------------------- remotes
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
local function remote(class, name)
	local r = Instance.new(class)
	r.Name = name
	r.Parent = Remotes
	return r
end
local ClickEv = remote("RemoteEvent", "Click") -- client → serveur
local ActionFn = remote("RemoteFunction", "Action") -- client → serveur (réponse)
local SyncEv = remote("RemoteEvent", "Sync") -- serveur → client (état)
local FxEv = remote("RemoteEvent", "Fx") -- serveur → client (événements ponctuels)
Remotes.Parent = ReplicatedStorage

--------------------------------------------------------------------------- datastore
local STORE_NAME = "CookieOverdrive_v1"
local store = nil
local okStore = pcall(function() store = DataStoreService:GetDataStore(STORE_NAME) end)
if not okStore then store = nil end
local board = nil
pcall(function() board = DataStoreService:GetOrderedDataStore("CookieOverdrive_AllTime_v1") end)

local sessions = {} -- [Player] = session

local function now() return os.clock() end
local function rand(a, b) return a + math.random() * (b - a) end

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local o = {}
	for k, v in t do o[k] = deepCopy(v) end
	return o
end

local function loadData(player)
	if not store then return E.defaultState(), false end
	local key = "u_" .. player.UserId
	for attempt = 1, 4 do
		local ok, data = pcall(function() return store:GetAsync(key) end)
		if ok then
			if type(data) == "table" then return E.merge(E.defaultState(), data), true end
			return E.defaultState(), false
		end
		task.wait(attempt)
	end
	return nil, false -- échec : on ne sauvegardera pas pour ne rien écraser
end

local function saveData(player)
	local ses = sessions[player]
	if not ses or not store or ses.noSave then return false end
	ses.s.lastSave = os.time()
	local data = deepCopy(ses.s)
	local key = "u_" .. player.UserId
	for attempt = 1, 3 do
		local ok = pcall(function()
			store:UpdateAsync(key, function() return data end)
		end)
		if ok then
			if board then
				local v = math.floor(math.log10(ses.s.allTimeBaked + 1) * 1e6)
				pcall(function() board:SetAsync(key, v) end)
			end
			return true
		end
		task.wait(attempt)
	end
	return false
end

--------------------------------------------------------------------------- helpers de session
local function fx(player, kind, payload)
	FxEv:FireClient(player, kind, payload)
end
local function toast(player, text, color)
	fx(player, "toast", { text = text, color = color })
end

local function recalc(ses)
	ses.M = E.recalc(ses.s, ses.passes)
	ses.dirty = true
end


local function questProgress(ses, qtype, amount, isMax)
	for _, q in ses.s.quests do
		if q.type == qtype and not q.done then
			q.progress = isMax and math.max(q.progress, amount) or q.progress + amount
			if q.progress >= q.target then
				q.progress = q.target
				q.done = true
				ses.dirty = true
				toast(ses.player, "Quête terminée ! Réclame ta récompense 🎁", "#b6ff3b")
			end
		end
	end
end

local function earn(ses, n)
	if not (n > 0) or n ~= n or n == math.huge then return end
	local s = ses.s
	s.cookies += n
	s.totalBaked += n
	s.allTimeBaked += n
	questProgress(ses, "bake", n)
end

local function addGems(ses, n, bonus)
	n = math.floor(n)
	if bonus and ses.passes.VIP then n = math.floor(n * 1.5) end
	ses.s.gems += n
	ses.dirty = true
	return n
end

local function addBuff(ses, b)
	local t = now()
	local dur = b.dur * ses.M.goldenDur
	for _, ex in ses.buffs do
		if ex.id == b.id then
			ex.untilT = t + dur
			ex.dur = dur
			return
		end
	end
	table.insert(ses.buffs, { id = b.id, name = b.name, emoji = b.emoji, cps = b.cps, click = b.click, dur = dur, untilT = t + dur })
end

local function startFever(ses)
	local t = now()
	ses.fever.active = true
	ses.fever.untilT = t + ses.M.feverDur
	ses.combo.heat = 1
	ses.s.stats.fevers += 1
	questProgress(ses, "fever", 1)
	fx(ses.player, "fever", { on = true })
end

local function endFever(ses)
	ses.fever.active = false
	ses.fever.cooldownUntil = now() + 20
	ses.combo.count = 0
	ses.combo.mult = 1
	ses.combo.heat = 0
	fx(ses.player, "fever", { on = false })
end

local function cpsNow(ses) return E.cpsNow(ses.s, ses.M, ses.buffs, ses.fever.active) end
local function clickValue(ses) return E.clickValue(ses.s, ses.M, ses.buffs, ses.fever.active) end

--------------------------------------------------------------------------- quêtes
local QT = {}
for _, q in D.quests do QT[q.type] = q end

local function questAllowed(ses, q)
	if q.needs == "minigame" then return E.minigameUnlocked(ses.s, "ninja") end
	if q.needs == "boss" then return ses.s.allTimeBaked >= E.BOSS_UNLOCK end
	return true
end

local function newQuest(ses, exclude)
	local pool = {}
	for _, q in D.quests do
		if questAllowed(ses, q) and not table.find(exclude, q.type) then table.insert(pool, q) end
	end
	if #pool == 0 then pool = D.quests end
	local q = pool[math.random(#pool)]
	local target = math.max(1, math.floor(q.n(ses.s, ses.api) + 0.5))
	local s = ses.s
	local id = s.questUid
	s.questUid += 1
	return { id = id, type = q.type, target = target, progress = 0, gems = q.gems, done = false }
end

local function questTypes(ses)
	local t = {}
	for _, q in ses.s.quests do table.insert(t, q.type) end
	return t
end

local function ensureQuests(ses)
	local keep = {}
	for _, q in ses.s.quests do if QT[q.type] then table.insert(keep, q) end end
	ses.s.quests = keep
	while #ses.s.quests < 3 do table.insert(ses.s.quests, newQuest(ses, questTypes(ses))) end
end

--------------------------------------------------------------------------- succès
local function checkAchievements(ses)
	local s, any = ses.s, false
	for _, a in D.achievements do
		if not s.achievements[a.id] then
			local ok, res = pcall(a.check, s, ses.api)
			if ok and res then
				s.achievements[a.id] = os.time()
				addGems(ses, a.gems, true)
				any = true
				fx(ses.player, "achievement", { name = a.name, desc = a.desc, gems = a.gems })
			end
		end
	end
	for _, sk in D.skins do
		if sk.unlock and not s.skinsOwned[sk.id] and E.skinUnlockMet(s, sk, ses.passes) then
			s.skinsOwned[sk.id] = true
			toast(ses.player, "Skin débloqué : " .. sk.name .. " !", "#ffc93c")
			any = true
		end
	end
	if any then recalc(ses) end
end

--------------------------------------------------------------------------- cookies dorés & boss
local goldenUid = 0
local function spawnGolden(ses)
	local x, y
	repeat
		x, y = rand(0.08, 0.92), rand(0.2, 0.85)
	until math.abs(x - 0.5) > 0.2 or math.abs(y - 0.5) > 0.25
	goldenUid += 1
	table.insert(ses.golden, { id = goldenUid, x = x, y = y, born = now(), life = 13 })
end

local function pickWeighted(list, weightOf)
	local tot = 0
	for _, e in list do tot += weightOf(e) end
	local r = math.random() * tot
	for _, e in list do
		r -= weightOf(e)
		if r <= 0 then return e end
	end
	return list[1]
end

local function clickGolden(ses, id)
	local g
	for i, x in ses.golden do
		if x.id == id then
			g = x
			table.remove(ses.golden, i)
			break
		end
	end
	if not g then return nil end
	ses.lastInteract = now()
	local s = ses.s
	local eff = pickWeighted(D.golden, function(e) return e.weight end)
	local label = eff.label
	if eff.kind == "lucky" then
		local gain = math.max(13, math.min(s.cookies * 0.15, cpsNow(ses) * 900) + clickValue(ses) * 30) + 13
		earn(ses, gain)
		label = "CHANCEUX ! +" .. D.fmt(gain)
	elseif eff.buff then
		addBuff(ses, eff.buff)
	elseif eff.kind == "rgbstorm" then
		if not ses.fever.active then
			ses.fever.cooldownUntil = 0
			startFever(ses)
		else
			ses.fever.untilT += 5
		end
	elseif eff.kind == "gems" then
		local n = addGems(ses, math.random(3, 8), true)
		label = "PLUIE DE GEMMES +" .. n
	end
	s.stats.golden += 1
	questProgress(ses, "golden", 1)
	ses.dirty = true
	return { label = label, color = eff.color }
end

local function spawnBoss(ses)
	local d = D.bosses[math.random(#D.bosses)]
	local k = ses.s.stats.bossKills
	local hp = math.floor(80 * (1 + 0.35 * math.min(k, 30)) + 0.5)
	local t = now()
	ses.boss = { id = d.id, name = d.name, emoji = d.emoji, color = d.color, hp = hp, maxHp = hp, untilT = t + 30 }
	fx(ses.player, "boss", { state = "spawn", name = d.name, emoji = d.emoji })
end

local function defeatBoss(ses)
	local b = ses.boss
	if not b then return end
	ses.boss = nil
	local s = ses.s
	s.stats.bossKills += 1
	local cookies = math.max(500, cpsNow(ses) * 300 + clickValue(ses) * 100)
	earn(ses, cookies)
	local gems = addGems(ses, math.min(20, 8 + s.stats.bossKills), true)
	addBuff(ses, { id = "victory", name = "Victoire", emoji = "🏆", dur = 60, cps = 2 })
	questProgress(ses, "boss", 1)
	ses.nextBoss = now() + rand(240, 420)
	fx(ses.player, "boss", { state = "defeat", name = b.name })
	toast(ses.player, b.name .. " vaincu ! +" .. D.fmt(cookies) .. " cookies et +" .. gems .. " 💎", "#ffc93c")
end

local function escapeBoss(ses)
	local b = ses.boss
	if not b then return end
	ses.boss = nil
	local stolen = math.floor(ses.s.cookies * 0.02)
	ses.s.cookies -= stolen
	ses.nextBoss = now() + rand(240, 420)
	fx(ses.player, "boss", { state = "escape", name = b.name })
	toast(ses.player, b.name .. " s'est enfui" .. (stolen > 0 and " avec " .. D.fmt(stolen) .. " cookies…" or "…"), "#ff4d6d")
end

--------------------------------------------------------------------------- clic
local function doClick(ses, auto)
	local s, t = ses.s, now()
	if not auto then
		ses.lastClick = t
		ses.lastInteract = t
	end
	local c = ses.combo
	c.count += 1
	c.mult = E.comboMultFor(ses.M, c.count)
	if c.count > s.stats.maxCombo then s.stats.maxCombo = math.floor(c.count) end
	questProgress(ses, "combo", c.count, true)
	local crit = math.random() < ses.M.crit
	local amount = clickValue(ses) * c.mult * (crit and ses.M.critX or 1)
	s.clicks += 1
	earn(ses, amount)
	questProgress(ses, "clicks", 1)
	if crit then
		s.stats.crits += 1
		questProgress(ses, "crit", 1)
	end
	if not ses.fever.active then
		local cool = t < ses.fever.cooldownUntil
		c.heat = math.min(cool and 0.95 or 1, c.count / E.FEVER_AT)
		if c.count >= E.FEVER_AT and not cool then startFever(ses) end
	else
		c.heat = 1
	end
	if ses.boss then
		local dmg = math.floor(c.mult * (crit and 5 or 1) * (1 + (ses.M.petClick - 1) * 0.25) * 10 + 0.5) / 10
		ses.boss.hp = math.max(0, ses.boss.hp - dmg)
		if ses.boss.hp <= 0 then defeatBoss(ses) end
	end
	return amount, crit
end

ClickEv.OnServerEvent:Connect(function(player)
	local ses = sessions[player]
	if not ses then return end
	-- anti-autoclick externe : 20 clics/s max
	local t = now()
	ses.bucket = math.min(20, ses.bucket + (t - ses.bucketT) * 20)
	ses.bucketT = t
	if ses.bucket < 1 then return end
	ses.bucket -= 1
	local amount, crit = doClick(ses, false)
	fx(player, "click", { a = amount, c = crit, n = math.floor(ses.combo.count) })
end)

--------------------------------------------------------------------------- pets
local function autoBestEquip(ses, inst)
	local s = ses.s
	local worst
	for _, uid in s.equipped do
		for _, p in s.pets do
			if p.uid == uid and (not worst or D.rarities[D.PET[p.id].rarity].rank < D.rarities[D.PET[worst.id].rarity].rank) then worst = p end
		end
	end
	if worst and D.rarities[D.PET[inst.id].rarity].rank > D.rarities[D.PET[worst.id].rarity].rank then
		s.equipped[table.find(s.equipped, worst.uid)] = inst.uid
	end
end

local function rollRarity(egg)
	return pickWeighted(egg.odds, function(o) return o[2] end)[1]
end

local function hatch(ses, eggId)
	local egg, s = D.EGG[eggId], ses.s
	if not egg then return nil end
	if s.gems < egg.cost then return { err = "Pas assez de gemmes 💎" } end
	s.gems -= egg.cost
	local rarity = rollRarity(egg)
	local lucky = false
	if ses.passes.LuckyEggs and math.random() < 0.3 then
		local r2 = rollRarity(egg)
		if D.rarities[r2].rank > D.rarities[rarity].rank then rarity = r2; lucky = true end
	end
	local pool = {}
	for _, p in D.pets do if p.rarity == rarity then table.insert(pool, p) end end
	local def = pool[math.random(#pool)]
	local inst, isNew
	for _, p in s.pets do if p.id == def.id then inst = p end end
	if inst then
		inst.lvl = math.min(10, inst.lvl + 1)
		isNew = false
	else
		inst = { uid = s.petUid, id = def.id, lvl = 1 }
		s.petUid += 1
		table.insert(s.pets, inst)
		isNew = true
		if #s.equipped < E.petSlots(ses.passes) then table.insert(s.equipped, inst.uid) else autoBestEquip(ses, inst) end
	end
	s.stats.eggs += 1
	recalc(ses)
	return { ok = true, id = def.id, lvl = inst.lvl, isNew = isNew, rarity = rarity, lucky = lucky }
end

--------------------------------------------------------------------------- mini-jeux
-- Récompense calculée côté serveur à partir du score, bornée par la durée réelle.
local MG_RULES = {
	ninja = { minDur = 25, maxRate = 6, cookies = 0.06, gemsPer = 25 },
	flappy = { minDur = 3, maxRate = 0.9, cookies = 0.35, gemsPer = 10 },
	rhythm = { minDur = 25, maxRate = 50, cookies = 0.002, gemsPer = 150 },
}

local function mgEnd(ses, id, score)
	local rule = MG_RULES[id]
	local st = ses.mgStart
	ses.mgStart = nil
	if not rule or not st or st.id ~= id or type(score) ~= "number" or score ~= score then return nil end
	local elapsed = now() - st.t
	if elapsed < rule.minDur and id ~= "flappy" then return nil end
	score = math.clamp(math.floor(score), 0, math.floor(elapsed * rule.maxRate) + 1)
	local s = ses.s
	local rec = s.mg[id] or { best = 0, plays = 0 }
	s.mg[id] = rec
	local isBest = score > rec.best
	if isBest then rec.best = score end
	rec.plays += 1
	local cookies = E.unit(s, ses.M) * score * rule.cookies
	earn(ses, cookies)
	local gems = addGems(ses, math.floor(score / rule.gemsPer), true)
	questProgress(ses, "minigame", 1)
	ses.dirty = true
	return { cookies = cookies, gems = gems, best = rec.best, isBest = isBest, score = score }
end

-- Machine à sous : entièrement côté serveur (mise en cookies, jamais en Robux)
local REELS = { "🍪", "🍪", "🍪", "🍫", "🍫", "🥛", "🥛", "💎", "⭐", "7️⃣" }
local PAY = { ["🍪"] = 3, ["🍫"] = 6, ["🥛"] = 10, ["💎"] = 25, ["⭐"] = 50, ["7️⃣"] = 150 }
local function spin(ses, betIdx)
	local s = ses.s
	local mults = { 1, 5, 25 }
	local m = mults[betIdx]
	if not m then return nil end
	local bet = math.floor(E.unit(s, ses.M) * 0.1 * m)
	if s.cookies < bet then return { err = "Pas assez de cookies pour miser " .. D.fmt(bet) } end
	s.cookies -= bet
	local r = { REELS[math.random(#REELS)], REELS[math.random(#REELS)], REELS[math.random(#REELS)] }
	local win, gems = 0, 0
	if r[1] == r[2] and r[2] == r[3] then
		win = bet * PAY[r[1]]
		if r[1] == "💎" then gems = 5 * m end
		if r[1] == "7️⃣" then gems = 20 * m end
	elseif r[1] == r[2] or r[2] == r[3] or r[1] == r[3] then
		win = bet * 1.5
	end
	if win > 0 then earn(ses, win) end
	if gems > 0 then gems = addGems(ses, gems, true) end
	local rec = s.mg.slots or { best = 0, plays = 0 }
	s.mg.slots = rec
	rec.plays += 1
	if win > rec.best then rec.best = win end
	questProgress(ses, "minigame", 1)
	ses.dirty = true
	return { reels = r, bet = bet, win = win, gems = gems }
end

--------------------------------------------------------------------------- actions client
local Actions = {}

function Actions.buyBuilding(ses, id, qty)
	local s = ses.s
	if not D.BLD[id] then return false end
	local n = qty == "max" and E.bMax(s, id) or math.clamp(math.floor(tonumber(qty) or 1), 1, 1000)
	if n <= 0 then return false end
	local cost = E.bCost(id, n, s.buildings[id] or 0)
	if cost > s.cookies then return false end
	s.cookies -= cost
	s.buildings[id] = (s.buildings[id] or 0) + n
	questProgress(ses, "buy", n)
	ses.dirty = true
	return true
end

function Actions.buyUpgrade(ses, id)
	local u, s = D.UPG[id], ses.s
	if not u or s.upgrades[id] or not E.reqMet(s, u) or u.cost > s.cookies then return false end
	s.cookies -= u.cost
	s.upgrades[id] = true
	recalc(ses)
	questProgress(ses, "upgrade", 1)
	return true
end

function Actions.skin(ses, id)
	local sk, s = D.SKIN[id], ses.s
	if not sk then return false end
	if not s.skinsOwned[id] then
		if sk.unlock then
			if not E.skinUnlockMet(s, sk, ses.passes) then return false end
		elseif s.gems < sk.cost then
			return false
		else
			s.gems -= sk.cost
		end
		s.skinsOwned[id] = true
	end
	s.skin = id
	ses.dirty = true
	return true
end

function Actions.theme(ses, id)
	local th, s = D.THEME[id], ses.s
	if not th then return false end
	if not s.themesOwned[id] then
		if s.gems < th.cost then return false end
		s.gems -= th.cost
		s.themesOwned[id] = true
	end
	s.theme = id
	ses.dirty = true
	return true
end

function Actions.hatch(ses, eggId) return hatch(ses, eggId) end

function Actions.equip(ses, uid)
	local s = ses.s
	local i = table.find(s.equipped, uid)
	if i then
		table.remove(s.equipped, i)
	else
		local owned = false
		for _, p in s.pets do if p.uid == uid then owned = true end end
		if not owned then return false end
		if #s.equipped >= E.petSlots(ses.passes) then return { err = E.petSlots(ses.passes) .. " pets max équipés." } end
		table.insert(s.equipped, uid)
	end
	recalc(ses)
	return true
end

function Actions.claimQuest(ses, id)
	local s = ses.s
	for i, q in s.quests do
		if q.id == id and q.done then
			local g = addGems(ses, q.gems, true)
			s.stats.quests += 1
			s.quests[i] = newQuest(ses, questTypes(ses))
			return g
		end
	end
	return false
end

function Actions.rerollQuest(ses, id)
	local s = ses.s
	if s.gems < 3 then return false end
	for i, q in s.quests do
		if q.id == id then
			s.gems -= 3
			s.quests[i] = newQuest(ses, questTypes(ses))
			ses.dirty = true
			return true
		end
	end
	return false
end

function Actions.gift(ses)
	local s = ses.s
	if os.time() < (s.nextGift or 0) then return false end
	s.nextGift = os.time() + E.GIFT_EVERY
	local r = math.random()
	local label
	if r < 0.45 then
		label = "+" .. addGems(ses, math.random(4, 10), true) .. " gemmes 💎"
	elseif r < 0.8 then
		local n = E.unit(s, ses.M) * rand(2, 5)
		earn(ses, n)
		label = "+" .. D.fmt(n) .. " cookies 🍪"
	else
		addBuff(ses, { id = "gift", name = "Cadeau", emoji = "🎁", dur = 45, cps = 3 })
		label = "Production ×3 pendant 45 s 🎁"
	end
	ses.dirty = true
	return label
end

function Actions.rebirth(ses)
	local s = ses.s
	local gain = E.rebirthGain(s)
	if gain < 1 then return false end
	s.stars += gain
	s.rebirths += 1
	addGems(ses, 10 * gain, true)
	s.cookies, s.totalBaked = 0, 0
	for _, b in D.buildings do s.buildings[b.id] = 0 end
	s.upgrades = {}
	ses.buffs, ses.golden, ses.boss = {}, {}, nil
	ses.combo = { count = 0, mult = 1, heat = 0 }
	if ses.fever.active then endFever(ses) end
	recalc(ses)
	saveData(ses.player)
	return gain
end

function Actions.golden(ses, id) return clickGolden(ses, id) end

function Actions.mgStart(ses, id)
	if not MG_RULES[id] or not E.minigameUnlocked(ses.s, id) then return false end
	ses.mgStart = { id = id, t = now() }
	ses.inMinigame = true
	return true
end

function Actions.mgEnd(ses, id, score)
	ses.inMinigame = false
	local res = mgEnd(ses, id, score)
	-- ne pas punir les joueurs partis en mini-jeu
	local t = now()
	if ses.nextGolden < t + 8 then ses.nextGolden = t + rand(8, 20) end
	if ses.boss then ses.boss.untilT = math.max(ses.boss.untilT, t + 12) end
	return res
end

function Actions.mgClose(ses)
	ses.inMinigame = false
	ses.mgStart = nil
	return true
end

function Actions.spin(ses, betIdx)
	if not E.minigameUnlocked(ses.s, "slots") then return nil end
	return spin(ses, betIdx)
end

function Actions.autoClick(ses, on)
	ses.s.autoClick = on == true
	ses.dirty = true
	return ses.s.autoClick
end

-- Achats Robux : le client demande, le serveur ouvre la fenêtre officielle Roblox
function Actions.buyPass(ses, key)
	local p = Shop.passByKey[key]
	if not p or p.id == 0 or ses.passes[key] then return false end
	MarketplaceService:PromptGamePassPurchase(ses.player, p.id)
	return true
end

function Actions.buyProduct(ses, key)
	local p = Shop.productByKey[key]
	if not p or p.id == 0 then return false end
	MarketplaceService:PromptProductPurchase(ses.player, p.id)
	return true
end

ActionFn.OnServerInvoke = function(player, name, a, b)
	local ses = sessions[player]
	local f = Actions[name]
	if not ses or not f or type(name) ~= "string" then return nil end
	local ok, res = pcall(f, ses, a, b)
	if not ok then
		warn("[Cookie] action " .. name .. " : " .. tostring(res))
		return nil
	end
	ses.dirty = true
	return res
end

--------------------------------------------------------------------------- Game Passes & Developer Products
local function applyPass(ses, key)
	if ses.passes[key] then return end
	ses.passes[key] = true
	recalc(ses)
	checkAchievements(ses)
	if key == "VIP" then ses.player:SetAttribute("VIP", true) end
end

local function refreshPasses(ses)
	for _, p in Shop.passes do
		if p.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(ses.player.UserId, p.id)
			end)
			if ok and owns then applyPass(ses, p.key) end
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local ses = sessions[player]
	local p = Shop.passById[passId]
	if ses and p and purchased then
		applyPass(ses, p.key)
		ses.s.stats.robuxSpent += p.price
		fx(player, "purchase", { name = p.name, emoji = p.emoji })
		saveData(player)
	end
end)

local function grantProduct(ses, p)
	local s = ses.s
	if p.kind == "gems" then
		addGems(ses, p.n, false)
	elseif p.kind == "cookies" then
		earn(ses, math.max(E.unit(s, ses.M) * 10, E.cpsBase(s, ses.M) * 60 * p.n))
	elseif p.kind == "boost" then
		local base = math.max(os.time(), s.boostUntil or 0)
		s.boostUntil = base + p.dur
		s.boostMult = p.mult
	elseif p.kind == "fever" then
		ses.fever.cooldownUntil = 0
		if ses.fever.active then ses.fever.untilT += 8 else startFever(ses) end
	end
	s.stats.robuxSpent += p.price
	ses.dirty = true
end

MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local ses = player and sessions[player]
	if not ses then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local s = ses.s
	if s.receipts[info.PurchaseId] then return Enum.ProductPurchaseDecision.PurchaseGranted end
	local p = Shop.productById[info.ProductId]
	if not p then return Enum.ProductPurchaseDecision.NotProcessedYet end
	grantProduct(ses, p)
	s.receipts[info.PurchaseId] = os.time()
	-- on garde au plus 60 reçus
	local list = {}
	for k, v in s.receipts do table.insert(list, { k, v }) end
	if #list > 60 then
		table.sort(list, function(x, y) return x[2] < y[2] end)
		for i = 1, #list - 60 do s.receipts[list[i][1]] = nil end
	end
	if not saveData(player) and store then
		-- sauvegarde impossible : Roblox renverra le reçu plus tard
		s.receipts[info.PurchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	fx(player, "purchase", { name = p.name, emoji = p.emoji })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--------------------------------------------------------------------------- joueurs
local function makeLeaderstats(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local c = Instance.new("StringValue")
	c.Name = "🍪 Cookies"
	c.Parent = ls
	local r = Instance.new("IntValue")
	r.Name = "⭐ Rebirths"
	r.Parent = ls
	ls.Parent = player
	return c, r
end

local function onJoin(player)
	local s, loaded = loadData(player)
	local noSave = false
	if not s then
		s = E.defaultState()
		noSave = true
		task.defer(function()
			toast(player, "⚠️ Sauvegarde indisponible, ta progression de cette session ne sera pas enregistrée.", "#ff4d6d")
		end)
	end
	local t = now()
	local ses = {
		player = player, s = s, passes = {}, noSave = noSave,
		combo = { count = 0, mult = 1, heat = 0 },
		fever = { active = false, untilT = 0, cooldownUntil = 0 },
		buffs = {}, golden = {}, boss = nil,
		nextGolden = t + rand(20, 40), nextBoss = nil,
		lastClick = -10, lastInteract = t,
		bucket = 20, bucketT = t, autoAcc = 0,
		secAcc = 0, saveAcc = 0, dirty = true, fullAcc = 0,
	}
	ses.api = {
		cpsBase = function() return E.cpsBase(ses.s, ses.M) end,
		petDef = E.petDef,
		idleFor = function() return now() - ses.lastInteract end,
		totalBuildings = function()
			local n = 0
			for _, v in ses.s.buildings do n += v end
			return n
		end,
		upgradeCount = function()
			local n = 0
			for _ in ses.s.upgrades do n += 1 end
			return n
		end,
	}
	sessions[player] = ses
	ses.M = E.recalc(s, ses.passes)
	refreshPasses(ses)
	ensureQuests(ses)
	ses.cookiesVal, ses.rebirthVal = makeLeaderstats(player)
	-- gains hors-ligne : 50 %, max 12 h
	if loaded then
		local away = math.min(12 * 3600, os.time() - (s.lastSave or os.time()))
		if away > 60 then
			local gain = E.cpsBase(s, ses.M) * away * 0.5
			if gain > 0 then
				earn(ses, gain)
				task.delay(2, function()
					fx(player, "offline", { away = away, gain = gain })
				end)
			end
		end
	end
	World.onJoin(player)
end

local function onLeave(player)
	saveData(player)
	sessions[player] = nil
end

Players.PlayerAdded:Connect(onJoin)
for _, p in Players:GetPlayers() do task.spawn(onJoin, p) end
Players.PlayerRemoving:Connect(onLeave)
game:BindToClose(function()
	for p in sessions do
		task.spawn(saveData, p)
	end
	if not RunService:IsStudio() then task.wait(3) end
end)

--------------------------------------------------------------------------- boucle de jeu
local function snapshot(ses)
	local t = now()
	local buffs = {}
	for _, b in ses.buffs do table.insert(buffs, { id = b.id, name = b.name, emoji = b.emoji, left = b.untilT - t, dur = b.dur }) end
	local golden = {}
	for _, g in ses.golden do table.insert(golden, { id = g.id, x = g.x, y = g.y, left = g.life - (t - g.born) }) end
	local boss
	if ses.boss then
		local b = ses.boss
		boss = { name = b.name, emoji = b.emoji, color = b.color, hp = b.hp, maxHp = b.maxHp, left = b.untilT - t }
	end
	return {
		cookies = ses.s.cookies, totalBaked = ses.s.totalBaked, allTimeBaked = ses.s.allTimeBaked,
		gems = ses.s.gems, cps = cpsNow(ses), cpsBase = E.cpsBase(ses.s, ses.M), click = clickValue(ses),
		combo = { n = math.floor(ses.combo.count), mult = ses.combo.mult, heat = ses.combo.heat },
		fever = ses.fever.active and (ses.fever.untilT - t) or 0,
		buffs = buffs, golden = golden, boss = boss,
		boost = math.max(0, (ses.s.boostUntil or 0) - os.time()), boostMult = ses.s.boostMult,
		giftIn = math.max(0, (ses.s.nextGift or 0) - os.time()),
	}
end

local lastT = now()
RunService.Heartbeat:Connect(function()
	local t = now()
	local dt = t - lastT
	if dt < 0.1 then return end
	lastT = t
	for player, ses in sessions do
		local s = ses.s
		-- production
		local cps = cpsNow(ses)
		if cps > 0 then earn(ses, cps * dt) end
		-- auto-clicker (Game Pass)
		if ses.passes.AutoClicker and s.autoClick and not ses.inMinigame then
			ses.autoAcc += dt * 6
			while ses.autoAcc >= 1 do
				ses.autoAcc -= 1
				doClick(ses, true)
			end
		end
		-- déclin du combo
		local c = ses.combo
		if not ses.fever.active and t - ses.lastClick > 0.7 and c.count > 0 and not (ses.passes.AutoClicker and s.autoClick) then
			c.count = math.max(0, c.count - dt * (18 + c.count * 0.6))
			c.mult = E.comboMultFor(ses.M, c.count)
			c.heat = math.min(t < ses.fever.cooldownUntil and 0.95 or 1, c.count / E.FEVER_AT)
		end
		if ses.fever.active and t >= ses.fever.untilT then endFever(ses) end
		-- buffs
		for i = #ses.buffs, 1, -1 do
			if t >= ses.buffs[i].untilT then table.remove(ses.buffs, i) end
		end
		-- cookies dorés
		for i = #ses.golden, 1, -1 do
			if t - ses.golden[i].born > ses.golden[i].life then table.remove(ses.golden, i) end
		end
		if not ses.inMinigame and t >= ses.nextGolden then
			if #ses.golden < 2 then spawnGolden(ses) end
			ses.nextGolden = t + rand(45, 110) / ses.M.goldenFreq
		elseif ses.inMinigame then
			ses.nextGolden = math.max(ses.nextGolden, t + 5)
		end
		-- boss
		if ses.boss and t >= ses.boss.untilT then escapeBoss(ses) end
		if not ses.boss and s.allTimeBaked >= E.BOSS_UNLOCK and not ses.inMinigame then
			ses.nextBoss = ses.nextBoss or t + rand(90, 150)
			if t >= ses.nextBoss then spawnBoss(ses) end
		end
		-- chaque seconde
		ses.secAcc += dt
		ses.saveAcc += dt
		ses.fullAcc += dt
		if ses.secAcc >= 1 then
			s.stats.playTime += ses.secAcc
			ses.secAcc = 0
			checkAchievements(ses)
			ses.cookiesVal.Value = D.fmt(s.cookies)
			ses.rebirthVal.Value = s.rebirths
		end
		if ses.saveAcc >= 60 then
			ses.saveAcc = 0
			task.spawn(saveData, player)
		end
		-- synchro
		if ses.dirty or ses.fullAcc >= 2 then
			ses.dirty = false
			ses.fullAcc = 0
			local receipts = s.receipts
			s.receipts = nil -- inutile côté client
			local payload = { live = snapshot(ses), state = s, passes = ses.passes, vis = ses.M.vis, mult = { bld = ses.M.bld, petSlots = E.petSlots(ses.passes) } }
			SyncEv:FireClient(player, payload)
			s.receipts = receipts
		else
			SyncEv:FireClient(player, { live = snapshot(ses) })
		end
	end
end)

--------------------------------------------------------------------------- classement global
task.spawn(function()
	while true do
		task.wait(5)
		if board then
			local ok, pages = pcall(function() return board:GetSortedAsync(false, 10) end)
			if ok then
				local rows = {}
				for i, e in pages:GetCurrentPage() do
					local uid = tonumber(string.sub(e.key, 3))
					local name = "???"
					pcall(function() name = Players:GetNameFromUserIdAsync(uid) end)
					table.insert(rows, { rank = i, name = name, value = 10 ^ (e.value / 1e6) - 1 })
				end
				World.setLeaderboard(rows)
			end
		end
		task.wait(55)
	end
end)

World.init()
