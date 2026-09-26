-- COOKIE OVERDRIVE — interface (HUD, onglets, boutique Robux, popups)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local D = require(RS.Shared.GameData)
local E = require(RS.Shared.Econ)
local Shop = require(RS.Shared.Monetization)
local K = require(script.Parent.Kit)
local new, Cc = K.new, K.colors

local UI = {}
local Store -- { state, live, passes, vis, mult }
local act -- function(name, ...) -> résultat serveur
local onCookieTap -- function(screenPos)
local Minigames

local gui, hud, panel, panelBody, panelTitle, goldenLayer, fxLayer, toastList, modalLayer
local hudRefs = {}
local currentTab = nil
local rowUpdaters = {}
local buyQty = 1

---------------------------------------------------------------------------- utilitaires
local function fmt(n) return D.fmt(n or 0) end

function UI.toast(text, color)
	if not toastList then return end
	local t = K.card({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Cc.panel, BackgroundTransparency = 0.05 }, {
		K.small(text, 15, { TextColor3 = Cc.ink, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Font = K.BOLD }),
	})
	t:FindFirstChildOfClass("UIStroke").Color = color and Color3.fromHex(color) or Cc.hot
	t:FindFirstChildOfClass("UIStroke").Thickness = 3
	t.Parent = toastList
	task.delay(4.5, function()
		if t.Parent then
			TweenService:Create(t, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			task.wait(0.3)
			t:Destroy()
		end
	end)
end

function UI.floatText(text, pos, color, size)
	if not fxLayer then return end
	local l = K.label(text, size or 26, {
		Size = UDim2.fromOffset(300, 40), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pos.X + math.random(-25, 25), pos.Y - 20), TextColor3 = color or Cc.ink,
	})
	l.Parent = fxLayer
	TweenService:Create(l, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = l.Position - UDim2.fromOffset(0, 90), TextTransparency = 1,
	}):Play()
	local st = l:FindFirstChildOfClass("UIStroke")
	TweenService:Create(st, TweenInfo.new(0.9), { Transparency = 1 }):Play()
	task.delay(0.95, function() l:Destroy() end)
end

local function closeModal()
	modalLayer:ClearAllChildren()
	modalLayer.Visible = false
end

-- Popup générique : title, lines, buttons = { {text, color, fn} }
function UI.modal(title, body, buttons, accent)
	modalLayer:ClearAllChildren()
	modalLayer.Visible = true
	local box = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Cc.panel, Parent = modalLayer,
	}, {
		K.corner(18), new("UIStroke", { Color = accent or Cc.hot, Thickness = 4 }), K.pad(16), K.list(10),
		new("UISizeConstraint", { MaxSize = Vector2.new(420, 600) }),
	})
	K.label(title, 28, { LayoutOrder = 1, TextColor3 = accent or Cc.ink, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }).Parent = box
	K.small(body, 16, { LayoutOrder = 2, TextColor3 = Cc.ink, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }).Parent = box
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 3, Parent = box }, { K.list(10, Enum.FillDirection.Horizontal) })
	for _, b in buttons or { { "OK", Cc.green } } do
		K.button(b[1], b[2], { Size = UDim2.new(0, 150, 0, 44) }, function()
			closeModal()
			if b[3] then b[3]() end
		end).Parent = row
	end
	return box
end

---------------------------------------------------------------------------- HUD
local function buildHud()
	hud = new("Frame", { Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })

	-- compteur de cookies (haut centre)
	local top = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(360, 96),
		BackgroundColor3 = Cc.panel, BackgroundTransparency = 0.15, Parent = hud,
	}, { K.corner(16), new("UIStroke", { Color = Cc.hot, Thickness = 3 }), K.list(0) })
	hudRefs.topStroke = top:FindFirstChildOfClass("UIStroke")
	hudRefs.cookies = K.label("🍪 0", 36, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 42) })
	hudRefs.cookies.Parent = top
	hudRefs.cps = K.label("0 / seconde", 17, { LayoutOrder = 2, TextColor3 = Cc.cyan, Font = K.BOLD })
	hudRefs.cps.Parent = top
	-- barre de combo / chaleur
	local bar = new("Frame", { LayoutOrder = 3, Size = UDim2.new(0.86, 0, 0, 12), BackgroundColor3 = Cc.stroke, Parent = top }, { K.corner(6) })
	hudRefs.heat = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Cc.hot, Parent = bar }, { K.corner(6) })
	hudRefs.combo = K.label("", 14, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, -1), Parent = bar, TextSize = 12 })

	-- gemmes / étoiles (haut gauche)
	local left = new("Frame", { Position = UDim2.fromOffset(8, 60), Size = UDim2.fromOffset(170, 80), BackgroundTransparency = 1, Parent = hud }, { K.list(4, nil, Enum.HorizontalAlignment.Left) })
	local function chip(color)
		local f = new("Frame", { Size = UDim2.fromOffset(160, 34), BackgroundColor3 = Cc.panel, BackgroundTransparency = 0.1, Parent = left }, { K.corner(17), new("UIStroke", { Color = color, Thickness = 2 }) })
		return K.label("", 20, { Size = UDim2.fromScale(1, 1), Parent = f })
	end
	hudRefs.gems = chip(Cc.lime)
	hudRefs.stars = chip(Cc.gold)

	-- buffs (sous le compteur)
	hudRefs.buffs = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(500, 30), BackgroundTransparency = 1, Parent = hud }, { K.list(6, Enum.FillDirection.Horizontal) })

	-- boss
	local boss = new("Frame", { Visible = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 142), Size = UDim2.fromOffset(380, 58), BackgroundColor3 = Cc.panel, Parent = hud }, { K.corner(12), new("UIStroke", { Color = Cc.red, Thickness = 3 }), K.pad(6), K.list(4) })
	hudRefs.boss = boss
	hudRefs.bossName = K.label("", 18, { LayoutOrder = 1, Parent = boss })
	local hpBg = new("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = Cc.stroke, Parent = boss }, { K.corner(7) })
	hudRefs.bossHp = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Cc.red, Parent = hpBg }, { K.corner(7) })

	-- bannière fièvre
	hudRefs.fever = K.label("🌈 FIÈVRE RGB ×3 🌈", 40, { Visible = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 205), Size = UDim2.fromOffset(500, 50), Parent = hud })

	-- gros bouton cookie (tap mobile / clic rapide)
	local tap = new("TextButton", {
		Name = "TapCookie", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -60), Size = UDim2.fromOffset(130, 130),
		BackgroundColor3 = Color3.fromHex("#d99a4e"), Text = "🍪", TextScaled = true, Font = K.BOLD, AutoButtonColor = false, Parent = hud,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Cc.hot, Thickness = 5 }) })
	hudRefs.tap = tap
	hudRefs.tapStroke = tap:FindFirstChildOfClass("UIStroke")
	tap.MouseButton1Down:Connect(function()
		local p = UserInputService:GetMouseLocation()
		tap.Size = UDim2.fromOffset(118, 118)
		task.delay(0.06, function() tap.Size = UDim2.fromOffset(130, 130) end)
		onCookieTap(Vector2.new(p.X, p.Y - 36))
	end)
	K.small("Clique le cookie géant ou ce bouton !", 12, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -40), Size = UDim2.fromOffset(200, 16), TextColor3 = Cc.ink, Parent = hud })

	-- cadeau gratuit + auto-clicker
	hudRefs.gift = K.button("🎁 Cadeau", Cc.gold, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 154, 1, -140), Size = UDim2.fromOffset(130, 40), TextSize = 16, Parent = hud }, function()
		local r = act("gift")
		if r then UI.modal("🎁 CADEAU !", r, { { "Merci !", Cc.green } }, Cc.gold) end
	end)
	hudRefs.auto = K.button("🤖 Auto : ON", Cc.cyan, { Visible = false, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 154, 1, -92), Size = UDim2.fromOffset(130, 40), TextSize = 16, Parent = hud }, function()
		act("autoClick", not Store.state.autoClick)
	end)

	-- fil d'actus
	local ticker = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Cc.bg, BackgroundTransparency = 0.2, ClipsDescendants = true, Parent = hud })
	hudRefs.news = K.small("", 15, { Size = UDim2.new(3, 0, 1, 0), TextColor3 = Cc.muted, TextWrapped = false, Parent = ticker })
	task.spawn(function()
		while true do
			hudRefs.news.Text = "📰  " .. D.news[math.random(#D.news)]
			hudRefs.news.Position = UDim2.new(1, 0, 0, 0)
			local tw = TweenService:Create(hudRefs.news, TweenInfo.new(18, Enum.EasingStyle.Linear), { Position = UDim2.new(-1.1, 0, 0, 0) })
			tw:Play()
			tw.Completed:Wait()
		end
	end)
end

---------------------------------------------------------------------------- panneau à onglets
local TABS = {
	{ id = "buildings", label = "🏠", title = "Bâtiments" },
	{ id = "upgrades", label = "⬆️", title = "Améliorations" },
	{ id = "pets", label = "🐾", title = "Pets & Œufs" },
	{ id = "style", label = "🎨", title = "Skins & Thèmes" },
	{ id = "quests", label = "📜", title = "Quêtes" },
	{ id = "games", label = "🎮", title = "Mini-jeux" },
	{ id = "ach", label = "🏆", title = "Succès" },
	{ id = "rebirth", label = "⭐", title = "Rebirth" },
	{ id = "shop", label = "💎", title = "BOUTIQUE ROBUX" },
}
local tabBuilders = {}

local function openTab(id)
	if currentTab == id and panel.Visible then
		panel.Visible = false
		currentTab = nil
		return
	end
	currentTab = id
	panel.Visible = true
	UI.rebuild(true)
end
UI.openTab = openTab

function UI.rebuild(resetScroll)
	if not panel.Visible or not currentTab or not Store.state then return end
	local pos = panelBody.CanvasPosition
	for _, c in panelBody:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
	end
	rowUpdaters = {}
	for _, t in TABS do if t.id == currentTab then panelTitle.Text = t.label .. "  " .. t.title end end
	tabBuilders[currentTab](panelBody)
	UI.refreshRows()
	if not resetScroll then panelBody.CanvasPosition = pos end
end

function UI.refreshRows()
	for _, f in rowUpdaters do f() end
end

local function buildPanel()
	-- rail d'onglets (droite)
	local rail = new("ScrollingFrame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.new(0, 64, 0.8, 0),
		BackgroundTransparency = 1, ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		Parent = gui,
	}, { K.list(6) })
	for i, t in TABS do
		local b = K.button(t.label, t.id == "shop" and Cc.green or Cc.violet, { Size = UDim2.fromOffset(56, 52), TextSize = 26, LayoutOrder = i }, function() openTab(t.id) end)
		b.Parent = rail
		if t.id == "shop" then
			hudRefs.shopBtn = b
		end
	end

	panel = new("Frame", {
		Visible = false, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -76, 0.5, 0), Size = UDim2.new(0.42, 0, 0.82, 0),
		BackgroundColor3 = Cc.panel, BackgroundTransparency = 0.05, Parent = gui,
	}, { K.corner(18), new("UIStroke", { Color = Cc.violet, Thickness = 3 }), new("UISizeConstraint", { MinSize = Vector2.new(280, 200), MaxSize = Vector2.new(470, 2000) }) })
	panelTitle = K.label("", 24, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -60, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	K.button("✕", Cc.red, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(36, 32), Parent = panel }, function()
		panel.Visible = false
		currentTab = nil
	end)
	panelBody = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -52), BackgroundTransparency = 1, ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = panel,
	}, { K.list(8), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 10) }) })
end

-- ligne générique : icône, titre, sous-titre, bouton
local function row(parent, order, icon, title, sub, btnText, btnColor, onBuy)
	local card = K.card({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 74), Parent = parent })
	K.label(icon, 34, { Size = UDim2.fromOffset(46, 56), Position = UDim2.fromOffset(0, 0), Parent = card })
	local t = K.label(title, 18, { Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -170, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	local s = K.small(sub, 13, { Position = UDim2.fromOffset(52, 24), Size = UDim2.new(1, -170, 0, 34), TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
	local b
	if btnText then
		b = K.button(btnText, btnColor or Cc.green, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(108, 46), TextSize = 15, TextWrapped = true, Parent = card }, onBuy)
	end
	return card, t, s, b
end

local function setBuyable(b, ok)
	b.BackgroundColor3 = ok and Cc.green or Color3.fromHex("#4a3f6b")
	b.TextColor3 = ok and Cc.ink or Cc.muted
end

local function section(parent, order, text)
	K.label(text, 20, { LayoutOrder = order, TextColor3 = Cc.gold, Parent = parent })
end

---------------------------------------------------------------------------- onglet : bâtiments
tabBuilders.buildings = function(body)
	local s = Store.state
	local qrow = new("Frame", { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = body }, { K.list(6, Enum.FillDirection.Horizontal) })
	for _, q in { 1, 10, 100, "max" } do
		K.button(q == "max" and "MAX" or "×" .. q, buyQty == q and Cc.hot or Cc.violet, { Size = UDim2.fromOffset(70, 36), Parent = qrow }, function()
			buyQty = q
			UI.rebuild()
		end)
	end
	for i, d in D.buildings do
		if E.buildingUnlocked(s, i) then
			local card, t, sub, b = row(body, i, d.emoji, d.name, d.desc, "", Cc.green, function()
				act("buyBuilding", d.id, buyQty)
			end)
			table.insert(rowUpdaters, function()
				local st = Store.state
				local owned = st.buildings[d.id] or 0
				local n = buyQty == "max" and math.max(1, E.bMax(st, d.id)) or buyQty
				local cost = E.bCost(d.id, n, owned)
				local per = D.BLD[d.id].cps * E.BLD_POWER * (Store.mult.bld[d.id] or 1)
				t.Text = d.name .. "  ×" .. owned
				sub.Text = "+" .. fmt(per) .. "/s chacun (base) · " .. d.desc
				b.Text = "🍪 " .. fmt(cost) .. (n > 1 and ("\n×" .. n) or "")
				setBuyable(b, st.cookies >= cost)
			end)
		else
			row(body, i, "❔", "???", "Continue à produire pour débloquer.", nil)
			break
		end
	end
end

---------------------------------------------------------------------------- onglet : améliorations
tabBuilders.upgrades = function(body)
	local s = Store.state
	local list = {}
	for _, u in D.upgrades do
		if not s.upgrades[u.id] then table.insert(list, u) end
	end
	table.sort(list, function(a, b)
		local ra, rb = E.reqMet(s, a), E.reqMet(s, b)
		if ra ~= rb then return ra end
		return a.cost < b.cost
	end)
	local n = 0
	for _, u in s.upgrades do n += 1 end
	K.small(n .. " / " .. #D.upgrades .. " achetées — chaque amélioration ajoute un effet visuel au cookie géant !", 14, { LayoutOrder = 0, TextColor3 = Cc.cyan, Size = UDim2.new(1, 0, 0, 36), Parent = body })
	for i, u in list do
		local ok = E.reqMet(s, u)
		local _, _, _, b = row(body, i, ok and "✨" or "🔒", u.name, ok and E.fxText(u) or ("🔒 " .. E.reqText(u)), ok and ("🍪 " .. fmt(u.cost)) or "Verrouillé", Cc.green, function()
			act("buyUpgrade", u.id)
		end)
		table.insert(rowUpdaters, function() setBuyable(b, ok and Store.state.cookies >= u.cost) end)
	end
end

---------------------------------------------------------------------------- onglet : pets
local function hatchAnim(res)
	local def = D.PET[res.id]
	local rar = D.rarities[res.rarity]
	UI.modal(
		(res.isNew and "NOUVEAU PET !" or "PET AMÉLIORÉ !"),
		def.emoji .. "\n" .. def.name .. "\n" .. rar.name .. " · niveau " .. res.lvl .. (res.lucky and "\n🍀 Œuf Chanceux activé !" or "") .. "\n" .. E.petPower({ id = res.id, lvl = res.lvl }),
		{ { "Trop bien !", Cc.green } },
		Color3.fromHex(rar.color)
	)
end

tabBuilders.pets = function(body)
	local s = Store.state
	section(body, 0, "🥚 Œufs (payés en gemmes 💎)")
	for i, egg in D.eggs do
		local odds = {}
		for _, o in egg.odds do table.insert(odds, D.rarities[o[1]].name .. " " .. o[2] .. " %") end
		local _, _, _, b = row(body, i, "🥚", egg.name, "Probabilités : " .. table.concat(odds, " · "), "💎 " .. egg.cost, Cc.green, function()
			local res = act("hatch", egg.id)
			if res and res.ok then hatchAnim(res) elseif res and res.err then UI.toast(res.err, "#ff4d6d") end
		end)
		table.insert(rowUpdaters, function() setBuyable(b, Store.state.gems >= egg.cost) end)
	end
	if not Store.passes.LuckyEggs then
		K.button("🍀 Œufs Chanceux (Game Pass) — meilleurs pets !", Cc.green, { LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 40), TextSize = 15, Parent = body }, function() act("buyPass", "LuckyEggs") end)
	end
	local slots = Store.mult.petSlots or 3
	section(body, 20, "🐾 Tes pets (" .. #s.equipped .. "/" .. slots .. " équipés)")
	if slots < 5 then
		K.button("👑 VIP : +2 emplacements de pets", Cc.gold, { LayoutOrder = 21, Size = UDim2.new(1, 0, 0, 40), TextSize = 15, Parent = body }, function() act("buyPass", "VIP") end)
	end
	local pets = table.clone(s.pets)
	table.sort(pets, function(a, b) return D.rarities[D.PET[a.id].rarity].rank > D.rarities[D.PET[b.id].rarity].rank end)
	for i, p in pets do
		local def = D.PET[p.id]
		local eq = table.find(s.equipped, p.uid) ~= nil
		local card, t = row(body, 30 + i, def.emoji, def.name .. " Nv." .. p.lvl, D.rarities[def.rarity].name .. " · " .. E.petPower(p), eq and "Retirer" or "Équiper", eq and Cc.red or Cc.cyan, function()
			local r = act("equip", p.uid)
			if type(r) == "table" and r.err then UI.toast(r.err, "#ff4d6d") end
		end)
		t.TextColor3 = Color3.fromHex(D.rarities[def.rarity].color)
		if eq then card:FindFirstChildOfClass("UIStroke").Color = Cc.lime end
	end
	if #pets == 0 then K.small("Aucun pet pour l'instant. Fais éclore un œuf !", 14, { LayoutOrder = 30, Parent = body }) end
end

---------------------------------------------------------------------------- onglet : style
tabBuilders.style = function(body)
	local s = Store.state
	section(body, 0, "🍪 Skins du cookie")
	for i, sk in D.skins do
		local owned = s.skinsOwned[sk.id]
		local btn, col
		if s.skin == sk.id then
			btn, col = "Équipé ✓", Cc.lime
		elseif owned then
			btn, col = "Équiper", Cc.cyan
		elseif sk.unlock and sk.unlock.pass then
			btn, col = "Robux 💰", Cc.green
		elseif sk.unlock then
			btn, col = "🔒", Color3.fromHex("#4a3f6b")
		else
			btn, col = "💎 " .. sk.cost, Cc.green
		end
		local card = row(body, i, "🍪", sk.name, sk.unlock and ("Déblocage : " .. sk.unlock.text) or (sk.cost == 0 and "Gratuit" or "Skin payé en gemmes"), btn, col, function()
			if not owned and sk.unlock and sk.unlock.pass then
				act("buyPass", sk.unlock.pass)
			else
				act("skin", sk.id)
			end
		end)
		card.BackgroundColor3 = Color3.fromHex(sk.base):Lerp(Cc.panel2, 0.55)
	end
	section(body, 50, "🌆 Thèmes de l'arène")
	for i, th in D.themes do
		local owned = s.themesOwned[th.id]
		local card = row(body, 50 + i, "🌆", th.name, owned and "Débloqué" or "Thème payé en gemmes", s.theme == th.id and "Actif ✓" or owned and "Activer" or ("💎 " .. th.cost), s.theme == th.id and Cc.lime or Cc.green, function()
			act("theme", th.id)
		end)
		card.BackgroundColor3 = Color3.fromHex(th.ambient):Lerp(Cc.panel2, 0.6)
	end
end

---------------------------------------------------------------------------- onglet : quêtes
tabBuilders.quests = function(body)
	local s = Store.state
	for i, q in s.quests do
		local def
		for _, d in D.quests do if d.type == q.type then def = d end end
		if def then
			local text = string.gsub(def.text, "{n}", def.fmt and fmt(q.target) or tostring(q.target))
			local card = K.card({ LayoutOrder = i, Size = UDim2.new(1, 0, 0, 104), Parent = body })
			K.label(text, 17, { Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			local bg = new("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = Cc.stroke, Parent = card }, { K.corner(7) })
			new("Frame", { Size = UDim2.fromScale(math.clamp(q.progress / q.target, 0, 1), 1), BackgroundColor3 = q.done and Cc.lime or Cc.cyan, Parent = bg }, { K.corner(7) })
			K.small(fmt(q.progress) .. " / " .. fmt(q.target) .. "  ·  récompense 💎 " .. q.gems, 13, { Position = UDim2.fromOffset(0, 48), Parent = card })
			if q.done then
				K.button("Réclamer 💎", Cc.gold, { Position = UDim2.new(1, -130, 0, 64), Size = UDim2.fromOffset(130, 32), TextSize = 15, Parent = card }, function()
					local g = act("claimQuest", q.id)
					if g then UI.toast("+" .. g .. " gemmes 💎", "#b6ff3b") end
				end)
			else
				K.button("Changer (💎3)", Cc.violet, { Position = UDim2.new(1, -130, 0, 64), Size = UDim2.fromOffset(130, 32), TextSize = 14, Parent = card }, function()
					act("rerollQuest", q.id)
				end)
			end
		end
	end
end

---------------------------------------------------------------------------- onglet : mini-jeux
tabBuilders.games = function(body)
	local s = Store.state
	for i, m in D.minigames do
		local ok = E.minigameUnlocked(s, m.id)
		local rec = s.mg[m.id]
		row(body, i, m.emoji, m.name, ok and ("Record : " .. fmt(rec and rec.best or 0) .. " · parties : " .. (rec and rec.plays or 0)) or ("🔒 " .. m.text), ok and "JOUER" or "🔒", ok and Cc.hot or Color3.fromHex("#4a3f6b"), function()
			if ok then
				panel.Visible = false
				currentTab = nil
				Minigames.open(m.id)
			end
		end)
	end
end

---------------------------------------------------------------------------- onglet : succès
tabBuilders.ach = function(body)
	local s = Store.state
	local n = 0
	for _ in s.achievements do n += 1 end
	K.small(n .. " / " .. #D.achievements .. " débloqués · chaque succès = +1 % de production", 14, { LayoutOrder = 0, TextColor3 = Cc.cyan, Parent = body })
	for i, a in D.achievements do
		local got = s.achievements[a.id] ~= nil
		local card = row(body, i, got and "🏆" or "🔒", a.name, a.desc .. "  (💎 " .. a.gems .. ")", nil)
		if got then card:FindFirstChildOfClass("UIStroke").Color = Cc.gold else card.BackgroundTransparency = 0.4 end
	end
end

---------------------------------------------------------------------------- onglet : rebirth
tabBuilders.rebirth = function(body)
	local s = Store.state
	local gain = E.rebirthGain(s)
	K.label("⭐ " .. s.stars .. " étoiles · " .. s.rebirths .. " rebirth(s)", 22, { LayoutOrder = 1, TextColor3 = Cc.gold, Parent = body })
	K.small("Chaque étoile donne +10 % de production et de clics, POUR TOUJOURS. Le rebirth remet à zéro tes cookies, bâtiments et améliorations, mais tu gardes gemmes, pets, skins et succès.", 15, { LayoutOrder = 2, TextColor3 = Cc.ink, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = body })
	K.label(gain >= 1 and ("Rebirth maintenant : +" .. gain .. " ⭐ et +" .. gain * 10 .. " 💎") or ("Il faut " .. fmt(E.REBIRTH_MIN) .. " cookies produits depuis le dernier rebirth."), 18, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = body })
	local b = K.button("⭐ REBIRTH ⭐", Cc.gold, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 56), TextSize = 26, Parent = body }, function()
		if gain < 1 then return end
		UI.modal("Rebirth ?", "Tu vas repartir de zéro avec +" .. gain .. " ⭐ (+" .. gain * 10 .. "% de production). Sûr ?", {
			{ "Annuler", Cc.red },
			{ "GO !", Cc.gold, function()
				local g = act("rebirth")
				if g then UI.modal("⭐ RENAISSANCE ⭐", "+" .. g .. " étoiles ! Ton cookie est plus fort que jamais.", nil, Cc.gold) end
			end },
		}, Cc.gold)
	end)
	setBuyable(b, gain >= 1)
end

---------------------------------------------------------------------------- onglet : boutique Robux
tabBuilders.shop = function(body)
	local passes = Store.passes
	K.label("💎 Game Passes (à vie)", 22, { LayoutOrder = 0, TextColor3 = Cc.lime, Parent = body })
	for i, p in Shop.passes do
		local owned = passes[p.key]
		local btn = owned and "Possédé ✓" or (p.id == 0 and "Bientôt" or ("R$ " .. p.price))
		local card = row(body, i, p.emoji, p.name, p.desc, btn, owned and Cc.lime or Cc.green, function()
			if not owned then
				if not act("buyPass", p.key) then UI.toast("Bientôt disponible !", "#ffc93c") end
			end
		end)
		card:FindFirstChildOfClass("UIStroke").Color = owned and Cc.lime or Cc.gold
	end
	K.label("🛒 Packs & Boosts", 22, { LayoutOrder = 50, TextColor3 = Cc.cyan, Parent = body })
	for i, p in Shop.products do
		local desc = p.desc or ""
		if p.kind == "gems" then desc = "Pour les œufs, skins et thèmes." .. (p.tag and ("  🔥 " .. p.tag) or "")
		elseif p.kind == "boost" then desc = "Toute ta production ×" .. p.mult .. " pendant " .. math.floor(p.dur / 60) .. " min (cumulable)."
		elseif p.kind == "fever" then desc = "Déclenche la Fièvre RGB (×3) tout de suite !" end
		row(body, 50 + i, p.emoji, p.name, desc, p.id == 0 and "Bientôt" or ("R$ " .. p.price), Cc.green, function()
			if not act("buyProduct", p.key) then UI.toast("Bientôt disponible !", "#ffc93c") end
		end)
	end
	K.small("Les achats passent par la fenêtre officielle Roblox. Les probabilités des œufs sont affichées dans l'onglet Pets.", 12, { LayoutOrder = 200, Size = UDim2.new(1, 0, 0, 34), Parent = body })
end

---------------------------------------------------------------------------- cookies dorés
local goldenButtons = {}
local function refreshGolden(list)
	local seen = {}
	for _, g in list do
		seen[g.id] = true
		if not goldenButtons[g.id] then
			local b = new("TextButton", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(g.x, g.y), Size = UDim2.fromOffset(78, 78),
				BackgroundColor3 = Cc.gold, Text = "🍪", TextScaled = true, Font = K.BOLD, Parent = goldenLayer,
			}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Color3.fromHex("#fff2a8"), Thickness = 5 }) })
			b.MouseButton1Click:Connect(function()
				local res = act("golden", g.id)
				local p = b.AbsolutePosition + b.AbsoluteSize / 2
				b:Destroy()
				goldenButtons[g.id] = nil
				if res then
					UI.floatText(res.label, p, Color3.fromHex(res.color), 32)
					UI.toast("✨ " .. res.label, res.color)
				end
			end)
			TweenService:Create(b, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.fromOffset(90, 90), Rotation = 12 }):Play()
			goldenButtons[g.id] = b
		end
	end
	for id, b in goldenButtons do
		if not seen[id] then
			b:Destroy()
			goldenButtons[id] = nil
		end
	end
end

---------------------------------------------------------------------------- mises à jour
function UI.onLive(live)
	hudRefs.cookies.Text = "🍪 " .. fmt(live.cookies)
	hudRefs.cps.Text = fmt(live.cps) .. " / seconde  ·  clic " .. fmt(live.click)
	hudRefs.gems.Text = "💎 " .. fmt(live.gems)
	hudRefs.heat.Size = UDim2.fromScale(live.fever > 0 and 1 or live.combo.heat, 1)
	hudRefs.combo.Text = live.combo.n > 0 and ("COMBO " .. live.combo.n .. "  ×" .. live.combo.mult) or ""
	hudRefs.fever.Visible = live.fever > 0
	-- buffs
	for _, c in hudRefs.buffs:GetChildren() do
		if c:IsA("TextLabel") or c:IsA("Frame") then c:Destroy() end
	end
	local function buffChip(text, color)
		local f = new("Frame", { Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Cc.panel, Parent = hudRefs.buffs }, { K.corner(14), new("UIStroke", { Color = color, Thickness = 2 }), new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
		K.label(text, 15, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = f })
	end
	for _, b in live.buffs do buffChip(b.emoji .. " " .. b.name .. " " .. math.ceil(b.left) .. "s", Cc.hot) end
	if live.boost > 0 then buffChip("⚡ Boost ×" .. live.boostMult .. " " .. K.fmtTime(live.boost), Cc.lime) end
	-- boss
	if live.boss then
		hudRefs.boss.Visible = true
		hudRefs.bossName.Text = live.boss.emoji .. " " .. live.boss.name .. " — " .. math.ceil(live.boss.left) .. "s — CLIQUE !"
		hudRefs.bossHp.Size = UDim2.fromScale(live.boss.hp / live.boss.maxHp, 1)
	else
		hudRefs.boss.Visible = false
	end
	-- cadeau
	hudRefs.gift.Text = live.giftIn > 0 and ("🎁 " .. K.fmtTime(live.giftIn)) or "🎁 Cadeau !"
	hudRefs.gift.BackgroundColor3 = live.giftIn > 0 and Color3.fromHex("#4a3f6b") or Cc.gold
	refreshGolden(live.golden)
	UI.refreshRows()
end

function UI.onFull()
	local s = Store.state
	hudRefs.stars.Text = "⭐ " .. s.stars .. " étoiles"
	hudRefs.auto.Visible = Store.passes.AutoClicker == true
	hudRefs.auto.Text = s.autoClick and "🤖 Auto : ON" or "🤖 Auto : OFF"
	local sk = D.SKIN[s.skin]
	if sk then hudRefs.tap.BackgroundColor3 = Color3.fromHex(sk.base) end
	UI.rebuild(false)
end

---------------------------------------------------------------------------- init
function UI.init(store, actFn, tapFn, minigames)
	Store, act, onCookieTap, Minigames = store, actFn, tapFn, minigames
	gui = new("ScreenGui", { Name = "CookieUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	goldenLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = gui })
	buildHud()
	buildPanel()
	fxLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20, Parent = gui })
	toastList = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -34), Size = UDim2.fromOffset(340, 300), BackgroundTransparency = 1, ZIndex = 30, Parent = gui }, {
		new("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	modalLayer = new("Frame", { Visible = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 50, Active = true, Parent = gui })
	UI.gui = gui
	-- bordure RGB animée + bouton boutique qui clignote
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		hudRefs.topStroke.Color = K.rgb(t)
		hudRefs.tapStroke.Color = K.rgb(t, 0.3)
		if hudRefs.fever.Visible then hudRefs.fever.TextColor3 = K.rgb(t * 3) end
		if hudRefs.shopBtn then hudRefs.shopBtn.Rotation = math.sin(t * 4) * 6 end
	end)
end

return UI
