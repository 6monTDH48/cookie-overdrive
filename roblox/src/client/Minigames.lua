--!nonstrict
-- COOKIE OVERDRIVE — les 4 mini-jeux, en plein écran comme sur le site (.mg-overlay) :
-- bandeau (icône, nom, bouton « Quitter ») + zone de jeu. Chaque jeu vit dans mg/<Jeu>.lua et
-- reproduit mg-<jeu>.js ; mg/Common.lua contient les briques partagées.
-- Le gameplay tourne côté client ; la récompense est calculée et plafonnée par le serveur.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local D = require(RS:WaitForChild("Shared"):WaitForChild("GameData"))
local mgFolder = script.Parent:WaitForChild("mg")
local C = require(mgFolder:WaitForChild("Common"))

local MG = {}
MG.state, MG.live, MG.passes = nil, nil, {}

local act, UI
local gui, inst, curId, session = nil, nil, nil, 0
local round = nil -- manche en cours côté serveur : { t0, ok, sess }
local headerConn = nil

local MODULES = { ninja = "Ninja", flappy = "Flappy", rhythm = "Rhythm", slots = "Slots" }
local mods = {}
local function gameModule(id)
	if mods[id] == nil then
		local m = mgFolder:FindFirstChild(MODULES[id] or "")
		local ok, res = false, nil
		if m then ok, res = pcall(require, m) end
		if not ok then warn("[Minigames] ", id, res) end
		mods[id] = ok and res or false
	end
	return mods[id] or nil
end

local function destroyGui()
	if headerConn then
		headerConn:Disconnect()
		headerConn = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
end

local function stopGame()
	session += 1
	round = nil
	if inst then
		local i = inst
		inst = nil
		local ok, err = pcall(i.destroy)
		if not ok then warn("[Minigames] destroy", err) end
	end
	destroyGui()
	curId = nil
end

function MG.close()
	if not curId and not gui then return end
	stopGame()
	task.spawn(act, "mgClose")
end

----------------------------------------------------------------------------- overlay (bandeau du site)
local function buildShell(id)
	local def = D.MG[id] or { name = id }
	local order = 0
	if UI and UI.gui then order = UI.gui.DisplayOrder end
	gui = C.new("ScreenGui", {
		Name = "CookieMinigame", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None, DisplayOrder = order + 20,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	-- .mg-overlay : radial-gradient(circle at 50% 0%, #2a1468, var(--bg) 70%)
	local back = C.new("Frame", { Name = "Overlay", BackgroundColor3 = C.col.bg, Size = UDim2.fromScale(1, 1), Active = true, ZIndex = 1, Parent = gui })
	local glow = C.new("ImageLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(1.4, 1.4),
		ImageColor3 = C.hex("#2a1468"), ZIndex = 1, Parent = back,
	})
	C.new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width, Parent = glow })
	if not C.applyProc(glow, C.texGlow(0)) then glow:Destroy() end

	local head = C.new("Frame", { Name = "Head", BackgroundColor3 = C.hex("#0a051e"), BackgroundTransparency = 0.2, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 56), ZIndex = 80, Parent = back })
	local line = C.new("Frame", { BackgroundColor3 = C.INK, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3), ZIndex = 81, Parent = head })
	local left = C.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, -3), ZIndex = 81, Parent = head }, {
		C.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	C.icon(left, "mg:" .. id, 38, { LayoutOrder = 1, ZIndex = 82 })
	C.new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Text = def.name,
		FontFace = C.FD, TextSize = 22, TextColor3 = C.col.white, LayoutOrder = 2, ZIndex = 82, Parent = left,
	}, { C.tstroke(C.INK, 2.5) })
	local quit = C.button(head, "Quitter", { style = "red", size = "small", icon = "ui:close", z = 83 }, function() MG.close() end)
	quit.btn.AnchorPoint = Vector2.new(1, 0.5)

	local root = C.new("Frame", { Name = "Root", BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56), ZIndex = 2, Parent = back })

	-- éviter les boutons Roblox du haut de l'écran (menu, chat…)
	local function relayout()
		local ok, inset = pcall(function() return GuiService.TopbarInset end)
		local hh, lx, rx = 56, 12, 12
		if ok and inset and inset.Height > 0 then
			hh = math.max(56, math.floor(inset.Max.Y) + 2)
			lx = math.max(12, math.floor(inset.Min.X) + 8)
			local sw = gui.AbsoluteSize.X
			if inset.Max.X > 0 and inset.Max.X < sw - 4 then rx = math.max(12, sw - math.floor(inset.Max.X) + 8) end
		end
		head.Size = UDim2.new(1, 0, 0, hh)
		left.Position = UDim2.fromOffset(lx, 0)
		quit.btn.Position = UDim2.new(1, -rx, 0.5, -1)
		root.Position = UDim2.fromOffset(0, hh)
		root.Size = UDim2.new(1, 0, 1, -hh)
		line.Size = UDim2.new(1, 0, 0, 3)
	end
	relayout()
	headerConn = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(relayout)
	return root
end

----------------------------------------------------------------------------- contexte passé aux jeux
local function makeCtx(id, root)
	local mySession = session
	local ctx = { id = id, root = root, gui = gui, fmt = D.fmt, act = act }
	function ctx.alive() return session == mySession and gui ~= nil end
	function ctx.close() if ctx.alive() then MG.close() end end
	function ctx.best()
		local s = MG.state
		local r = s and s.mg and s.mg[id]
		return (r and r.best) or 0
	end
	function ctx.cookies()
		if MG.live and MG.live.cookies then return MG.live.cookies end
		return (MG.state and MG.state.cookies) or 0
	end
	function ctx.live() return MG.live end
	-- unité économique du serveur (E.unit) : base des mises du casino et des gains des mini-jeux
	local unitS, unitV = nil, nil
	function ctx.unit()
		local s = MG.state
		if s and s ~= unitS then
			local ok, u = pcall(function()
				local E = require(RS:WaitForChild("Shared"):WaitForChild("Econ"))
				return E.unit(s, E.recalc(s, MG.passes or {}))
			end)
			unitS, unitV = s, (ok and type(u) == "number") and u or nil
		end
		if unitV then return unitV end
		local L = MG.live or {}
		return math.max(25, (L.cpsBase or 0) * 60, (L.click or 0) * 90)
	end
	function ctx.toast(t, col)
		if UI and UI.toast then pcall(UI.toast, t, col) end
	end
	-- début de manche : act("mgStart") en tâche de fond (le compte à rebours démarre tout de suite)
	function ctx.startRound()
		local r = { t0 = os.clock(), ok = nil, sess = mySession }
		round = r
		task.spawn(function()
			local ok = act("mgStart", id)
			if round == r then
				r.ok = ok == true
				if not r.ok and ctx.alive() then
					ctx.toast("Mini-jeu indisponible pour le moment.", "#ff4d6d")
					MG.close()
				end
			end
		end)
	end
	-- fin de manche : envoie le score (en attendant au besoin ≤ maxWait s, 2,5 par défaut, que la manche soit assez longue
	-- pour le serveur) puis cb(res, hint) ; res = {score, cookies, gems, best, isBest} ou nil
	function ctx.endRound(score, cb, maxWait)
		local r = round
		round = nil
		local rule = C.RULES[id] or { minDur = 0, rate = 1e9, gemsPer = 1e9 }
		task.spawn(function()
			if not r then
				cb(nil, "Manche non validée")
				return
			end
			local waited = 0
			while r.ok == nil and waited < 12 do
				waited += task.wait(0.05)
			end
			if not ctx.alive() then return end
			if not r.ok then
				cb(nil, "Manche non validée")
				return
			end
			local el = os.clock() - r.t0
			local need = math.max(rule.minDur, (score - 1) / rule.rate) + 0.35
			if need - el > 0 and need - el <= (maxWait or 2.5) then task.wait(need - el) end
			if not ctx.alive() then return end
			el = os.clock() - r.t0
			local res = act("mgEnd", id, score)
			if not ctx.alive() then return end
			if res == nil and el < rule.minDur then
				cb(nil, "Manche trop courte : " .. rule.minDur .. " s mini pour gagner")
			else
				cb(res, nil)
			end
		end)
	end
	function ctx.gemHint(score)
		local rule = C.RULES[id]
		if not rule then return "" end
		local n = math.floor(score / rule.gemsPer) + 1
		return n .. (n > 1 and " gemmes dès " or " gemme dès ") .. (n * rule.gemsPer) .. " pts"
	end
	return ctx
end

----------------------------------------------------------------------------- API
function MG.open(id)
	if not MODULES[id] then return end
	if curId or gui then
		stopGame()
		task.spawn(act, "mgClose")
	end
	local mod = gameModule(id)
	if not mod then
		if UI and UI.toast then pcall(UI.toast, "Oups, ce mini-jeu a planté.", "#ff4d6d") end
		return
	end
	session += 1
	curId = id
	-- décodage en tâche de fond de l'art utile (seulement les accessoires portés par le joueur)
	local pre = { "mg:", "item:", "ui:", "cookie:" .. tostring(C.player.skin), "cookie:golden" }
	local back, front = C.accLayers()
	for _, k in back do table.insert(pre, k) end
	for _, k in front do table.insert(pre, k) end
	pcall(C.Img.preload, pre)
	local root = buildShell(id)
	local ctx = makeCtx(id, root)
	local ok, res = pcall(mod.mount, ctx)
	if ok and type(res) == "table" then
		inst = res
	else
		warn("[Minigames] mount", id, res)
		stopGame()
		task.spawn(act, "mgClose")
		if UI and UI.toast then pcall(UI.toast, "Oups, ce mini-jeu a planté.", "#ff4d6d") end
	end
end

function MG.isOpen() return gui ~= nil end

function MG.init(actFn, ui)
	act, UI = actFn, ui
	-- copie locale de l'état synchronisé (record, cookies, skin + accessoires du joueur)
	task.spawn(function()
		local remotes = RS:WaitForChild("Remotes")
		local sync = remotes:WaitForChild("Sync")
		sync.OnClientEvent:Connect(function(p)
			if type(p) ~= "table" then return end
			if p.live then MG.live = p.live end
			if p.state then
				MG.state = p.state
				C.player.skin = p.state.skin or "classic"
				C.player.vis = p.vis or {}
				if type(p.passes) == "table" then MG.passes = p.passes end
			end
		end)
	end)
end

return MG
