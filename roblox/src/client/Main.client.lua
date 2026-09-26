-- COOKIE OVERDRIVE — client : relie le serveur (Remotes) au stage 2D (Stage), à l'interface (UI / Panel)
-- et aux mini-jeux. Tout l'écran est une ScreenGui plein écran comme le site : pas de 3D, caméra figée.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = RS:WaitForChild("Shared")
local D = require(Shared:WaitForChild("GameData"))
local E = require(Shared:WaitForChild("Econ"))
local Remotes = RS:WaitForChild("Remotes")
local ClickEv = Remotes:WaitForChild("Click") :: RemoteEvent
local ActionFn = Remotes:WaitForChild("Action") :: RemoteFunction
local SyncEv = Remotes:WaitForChild("Sync") :: RemoteEvent
local FxEv = Remotes:WaitForChild("Fx") :: RemoteEvent

local K = require(script.Parent:WaitForChild("Kit"))
local Stage = require(script.Parent:WaitForChild("Stage"))
local UI = require(script.Parent:WaitForChild("UI"))
local Panel = require(script.Parent:WaitForChild("Panel"))
local Minigames = require(script.Parent:WaitForChild("Minigames"))

local player = Players.LocalPlayer

local Store: any = {
	state = nil, live = nil, passes = {}, vis = {}, mult = { bld = {}, petSlots = 3 },
	M = nil, reduced = false,
}

local function act(name: string, ...: any): any
	local args = table.pack(...)
	local ok, res = pcall(function() return ActionFn:InvokeServer(name, table.unpack(args, 1, args.n)) end)
	if not ok then
		warn("[Cookie] action " .. name .. " : " .. tostring(res))
		return nil
	end
	return res
end

---------------------------------------------------------------------------- environnement Roblox
-- pas de personnage à piloter, pas de 3D visible : caméra figée, contrôles et CoreGui inutiles coupés
local function setupEnvironment()
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.new(0, 5000, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local c = workspace.CurrentCamera
		if c then c.CameraType = Enum.CameraType.Scriptable end
	end)
	task.spawn(function()
		local ok, pm = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10) :: any)
		end)
		if ok and pm then pcall(function() pm:GetControls():Disable() end) end
	end)
	for _, t in { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.Chat } do
		pcall(function() StarterGui:SetCoreGuiEnabled(t, false) end)
	end
	pcall(function() (player:WaitForChild("PlayerGui") :: PlayerGui).ScreenOrientation = Enum.ScreenOrientation.Sensor end)
end
setupEnvironment()

---------------------------------------------------------------------------- clics
-- Le serveur accepte 20 clics/s (seau de 20 jetons) : on applique le même seau pour que chaque « +N »
-- reçu corresponde à un clic envoyé ; les positions attendent leur réponse dans une file (FIFO).
local bucket, bucketT = 20, os.clock()
local pending: { { x: number, y: number, t: number } } = {}
local function tap(pos: Vector2)
	if Minigames.isOpen() then return end
	Stage.tap(pos.X, pos.Y)
	UI.pulseCount()
	local t = os.clock()
	bucket = math.min(20, bucket + (t - bucketT) * 20)
	bucketT = t
	if bucket < 1 then return end
	bucket -= 1
	table.insert(pending, { x = pos.X, y = pos.Y, t = t })
	if #pending > 40 then table.remove(pending, 1) end
	ClickEv:FireServer()
end
local function popTap(): (number, number)
	local now = os.clock()
	while #pending > 0 do
		local p = table.remove(pending, 1) :: any
		if now - p.t < 1.5 then return p.x, p.y end
	end
	local ctx = Stage.ctx
	return ctx.CX + K.rand(-0.4, 0.4) * ctx.R, ctx.CY + K.rand(-0.4, 0.2) * ctx.R
end

---------------------------------------------------------------------------- cookies dorés
local function goldenToast(label: string)
	local dur = (Store.M and Store.M.goldenDur) or 1
	local txt
	if string.find(label, "FRÉNÉSIE", 1, true) then
		txt = "Production ×7 pendant " .. math.floor(30 * dur + 0.5) .. " s !"
	elseif string.find(label, "CLIC-TEMPÊTE", 1, true) then
		txt = "Chaque clic ×77 pendant " .. math.floor(10 * dur + 0.5) .. " s. SPAM !"
	elseif string.find(label, "RGB", 1, true) then
		txt = "Fièvre RGB instantanée !"
	end
	if txt then UI.toast(txt, "#ffc93c", "ui:golden") end
end
local function onGolden(id: number)
	task.spawn(function()
		local res = act("golden", id)
		Stage.goldenCaught(id, res)
		if type(res) == "table" and res.label then goldenToast(tostring(res.label)) end
	end)
end

---------------------------------------------------------------------------- démarrage
Minigames.init(act, UI)
UI.init(Store, act, Minigames, tap, onGolden)
K.preload({ "ui:", "tab:", "cookie:classic", "fx:glow", "fx:ring", "fx:spark", "fx:star", "fx:shadow", "golden", "fx:golden_rays", "cookie:golden" })

-- Espace = cliquer le cookie (comme sur le site : pas pendant une fenêtre, un œuf ou un mini-jeu)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.Space then return end
	if UI.blocking() or Minigames.isOpen() or not Store.state then return end
	local ctx = Stage.ctx
	tap(Vector2.new(ctx.CX, ctx.CY))
end)

---------------------------------------------------------------------------- synchro serveur
local firstFull = true
local offlineShown = false
SyncEv.OnClientEvent:Connect(function(p: any)
	if type(p) ~= "table" then return end
	if p.state then
		local s = p.state
		local prevSkin = Store.state and Store.state.skin
		Store.state = s
		Store.passes = p.passes or Store.passes or {}
		Store.vis = p.vis or Store.vis or {}
		Store.mult = p.mult or Store.mult
		local ok, M = pcall(E.recalc, s, Store.passes)
		if ok then Store.M = M end
		Stage.setSkin(s.skin, prevSkin ~= nil and prevSkin ~= s.skin)
		Stage.setTheme(s.theme)
		Stage.setState(s)
		local added = Stage.setVis(Store.vis, firstFull)
		if not firstFull then
			for _, k in added do
				local v = Panel.VIS[k]
				local name = v and v[2] or k
				UI.toast("Nouveau sur ton cookie : " .. name .. " !", "#ff2bd6", "vis:" .. k)
			end
		end
	end
	local live = p.live
	if type(live) == "table" then
		Store.live = live
		local s = Store.state
		if s then
			s.cookies = live.cookies or s.cookies
			s.gems = live.gems or s.gems
			s.totalBaked = live.totalBaked or s.totalBaked
			s.allTimeBaked = live.allTimeBaked or s.allTimeBaked
		end
		Stage.setLive(live)
	end
	if p.state then
		UI.onFull()
		if firstFull then
			firstFull = false
			-- première visite : fenêtre d'accueil du site (sauf si le bilan hors-ligne s'affiche)
			task.delay(1.2, function()
				local s = Store.state
				if not offlineShown and s and s.allTimeBaked == 0 and s.clicks == 0 then UI.welcome() end
			end)
		end
	end
	if live then UI.onLive(live) end
end)

---------------------------------------------------------------------------- événements ponctuels
local function achId(name: string): string
	for _, a in D.achievements do
		if a.name == name then return a.id end
	end
	return ""
end
local function bossId(name: string?): string
	for _, b in D.bosses do
		if b.name == name then return b.id end
	end
	return "broccoli"
end
FxEv.OnClientEvent:Connect(function(kind: string, d: any)
	d = type(d) == "table" and d or {}
	if kind == "click" then
		local x, y = popTap()
		local combo = Store.live and Store.live.combo
		Stage.clickResult(x, y, tonumber(d.a) or 0, d.c == true, combo and combo.mult or nil)
	elseif kind == "toast" then
		UI.toast(tostring(d.text or ""), d.color)
	elseif kind == "achievement" then
		UI.achievement({ id = achId(d.name), name = d.name, desc = d.desc, gems = d.gems })
		Stage.achievement()
		UI.checkSoft()
	elseif kind == "fever" then
		if d.on then Stage.feverStart() else Stage.feverEnd() end
	elseif kind == "boss" then
		if d.state == "spawn" then
			UI.toast("BOSS : " .. tostring(d.name) .. " ! Clique le cookie pour l'attaquer (30 s)", "#ff4d6d", "boss:" .. bossId(d.name))
			Stage.bossSpawn()
		elseif d.state == "defeat" then
			Stage.bossDefeat()
		elseif d.state == "escape" then
			Stage.bossEscape()
		end
	elseif kind == "offline" then
		offlineShown = true
		UI.offline(tonumber(d.away) or 0, tonumber(d.gain) or 0)
	elseif kind == "purchase" then
		UI.purchase(tostring(d.name or ""), d.emoji)
	end
end)

---------------------------------------------------------------------------- boucle
local mgWasOpen = false
local autoAcc = 0
RunService.RenderStepped:Connect(function(dt: number)
	local open = Minigames.isOpen()
	if open ~= mgWasOpen then
		mgWasOpen = open
		UI.setMinigame(open)
	end
	if not open then
		-- Auto-Clicker (6 clics/s côté serveur) : petits clics visibles sur le cookie
		local s = Store.state
		if s and s.autoClick and Store.passes.AutoClicker then
			autoAcc += dt * 6
			while autoAcc >= 1 do
				autoAcc -= 1
				Stage.autoTap()
			end
		else
			autoAcc = 0
		end
		Stage.step(dt)
	end
	UI.step(dt)
end)
