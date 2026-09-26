-- COOKIE OVERDRIVE — client : relie serveur, cookie 3D, interface et mini-jeux
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local D = require(RS:WaitForChild("Shared"):WaitForChild("GameData"))
local Remotes = RS:WaitForChild("Remotes")
local ClickEv, ActionFn, SyncEv, FxEv = Remotes:WaitForChild("Click"), Remotes:WaitForChild("Action"), Remotes:WaitForChild("Sync"), Remotes:WaitForChild("Fx")

local Cookie = require(script.Parent:WaitForChild("CookieModel"))
local UI = require(script.Parent:WaitForChild("UI"))
local Minigames = require(script.Parent:WaitForChild("Minigames"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Store = { state = nil, live = nil, passes = {}, vis = {}, mult = { bld = {}, petSlots = 3 } }

local function act(name, ...)
	local ok, res = pcall(function(...) return ActionFn:InvokeServer(name, ...) end, ...)
	if not ok then
		warn(res)
		return nil
	end
	return res
end

-- dernier point cliqué, pour afficher le « +N » au bon endroit
local lastTap = Vector2.new(0, 0)
local function tap(screenPos)
	lastTap = screenPos
	Cookie.pulse(false)
	ClickEv:FireServer()
end

Cookie.start()
Minigames.init(act, UI)
UI.init(Store, act, tap, Minigames)

-- clic direct sur le cookie 3D
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or Minigames.isOpen() then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local pos = input.Position
	local ray = camera:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if hit and Cookie.isCookie(hit.Instance) then
		tap(Vector2.new(pos.X, pos.Y))
	end
end)

----------------------------------------------------------------------------- synchro serveur
SyncEv.OnClientEvent:Connect(function(p)
	Store.live = p.live
	if p.state then
		Store.state = p.state
		Store.passes = p.passes or {}
		Store.vis = p.vis or {}
		Store.mult = p.mult or Store.mult
		local s = p.state
		Cookie.setSkin(s.skin, Store.vis.chips_xl ~= nil)
		Cookie.setTheme(s.theme)
		Cookie.setVisuals(Store.vis)
		local pets = {}
		for _, uid in s.equipped do
			for _, pet in s.pets do
				if pet.uid == uid then
					local def = D.PET[pet.id]
					table.insert(pets, { emoji = def.emoji, color = D.rarities[def.rarity].color })
				end
			end
		end
		Cookie.setPets(pets)
		UI.onFull()
	end
	if Store.state then
		Store.state.cookies = p.live.cookies
		Store.state.gems = p.live.gems
		Store.state.totalBaked = p.live.totalBaked
		Store.state.allTimeBaked = p.live.allTimeBaked
		UI.onLive(p.live)
	end
end)

----------------------------------------------------------------------------- événements ponctuels
FxEv.OnClientEvent:Connect(function(kind, d)
	if kind == "click" then
		local vis = Store.vis
		UI.floatText("+" .. D.fmt(d.a), lastTap, d.c and Color3.fromHex("#ffc93c") or Color3.new(1, 1, 1), d.c and 34 or 26)
		if d.c then
			Cookie.pulse(true)
			UI.floatText("CRITIQUE !", lastTap + Vector2.new(0, -40), Color3.fromHex("#ff2bd6"), 22)
		end
		if vis.shockwave and (d.c or d.n % 10 == 0) then Cookie.shockwave(Color3.fromHSV(os.clock() % 1, 1, 1)) end
		if vis.confetti_click and d.n % 15 == 0 then Cookie.confetti() end
	elseif kind == "toast" then
		UI.toast(d.text, d.color)
	elseif kind == "achievement" then
		UI.toast("🏆 Succès : " .. d.name .. "  (+" .. d.gems .. " 💎)", "#ffc93c")
	elseif kind == "fever" then
		if d.on then UI.toast("🌈 FIÈVRE RGB ! Tout ×3 !", "#ff2bd6") end
	elseif kind == "boss" then
		if d.state == "spawn" then UI.toast(d.emoji .. " " .. d.name .. " attaque ! Clique pour le battre !", "#ff4d6d") end
	elseif kind == "offline" then
		UI.modal("Bon retour ! 👋", "Pendant ton absence (" .. math.floor(d.away / 60) .. " min), ta boulangerie a produit\n+" .. D.fmt(d.gain) .. " 🍪", {
			{ "Cool !", Color3.fromHex("#2bdc6a") },
			{ "×3 Boost 💎", Color3.fromHex("#ff2bd6"), function() UI.openTab("shop") end },
		})
	elseif kind == "purchase" then
		UI.modal("MERCI ! " .. d.emoji, d.name .. " est activé. Profite bien ! 🍪", nil, Color3.fromHex("#2bdc6a"))
	end
end)

-- Première visite : petite aide
task.delay(4, function()
	if Store.state and Store.state.clicks == 0 then
		UI.modal("COOKIE OVERDRIVE 🍪", "Clique sur le cookie géant (ou le bouton 🍪 en bas à gauche) pour produire des cookies.\nAchète des bâtiments et des améliorations avec les onglets à droite !", { { "C'est parti !", Color3.fromHex("#2bdc6a") } })
	end
end)

