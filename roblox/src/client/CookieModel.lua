-- COOKIE OVERDRIVE — le cookie géant 3D (local : chaque joueur voit son skin et ses améliorations)
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local D = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameData"))

local C = {}

local CENTER = Vector3.new(0, 15, 0)
local R = 10 -- rayon
local THICK = 3

local model, body, rim, chipsFolder, visFolder, pivot
local currentSkin, currentTheme, currentVisKey
local rgbSkin = false
local scalePulse = 0
local orbiters, spinners = {}, {}
local beatPulse = false
local petFolder

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end

local function weld(p)
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
end

local function build()
	model = mk("Model", { Name = "MyCookie" }, workspace)
	pivot = CFrame.new(CENTER)
	body = mk("Part", {
		Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(THICK, R * 2, R * 2),
		Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = true,
	}, model)
	rim = mk("Part", {
		Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(THICK * 0.8, R * 2 + 0.8, R * 2 + 0.8),
		Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false,
	}, model)
	chipsFolder = mk("Folder", { Name = "Chips" }, model)
	visFolder = mk("Folder", { Name = "Visuals" }, model)
	model.PrimaryPart = body
	mk("PointLight", { Range = 40, Brightness = 1.5, Color = Color3.fromHex("#ffc93c") }, body)
	petFolder = mk("Folder", { Name = "MyPets" }, workspace)
end

-- positions des pépites sur la face (coordonnées -1..1)
local CHIPS = { { -0.45, 0.35 }, { 0.35, 0.45 }, { 0.05, -0.05 }, { -0.35, -0.4 }, { 0.5, -0.3 }, { -0.7, -0.05 }, { 0.15, 0.75 }, { 0.72, 0.15 }, { -0.1, -0.75 } }

-- offsets relatifs au cookie (le cookie est un cylindre dont l'axe est Z une fois tourné)
local BASE_ROT = CFrame.Angles(0, math.rad(90), 0) -- axe du cylindre (X) → Z monde
local local_ = {} -- [part] = CFrame relatif au pivot

local function attach(p, rel)
	weld(p)
	local_[p] = rel
end

local function rebuildChips(skin, big)
	chipsFolder:ClearAllChildren()
	local size = big and 2.2 or 1.5
	for side = -1, 1, 2 do
		for _, c in CHIPS do
			local p = mk("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Color = Color3.fromHex(skin.chip), Material = Enum.Material.SmoothPlastic }, chipsFolder)
			attach(p, CFrame.new(c[1] * R * 0.85, c[2] * R * 0.85, side * THICK * 0.45))
		end
	end
end

function C.setSkin(id, bigChips)
	local skin = D.SKIN[id] or D.skins[1]
	local key = id .. tostring(bigChips)
	if currentSkin == key then return end
	currentSkin = key
	body.Color = Color3.fromHex(skin.base)
	body.Material = Enum.Material[skin.material] or Enum.Material.SmoothPlastic
	rim.Color = Color3.fromHex(skin.rim)
	rgbSkin = skin.rgb == true
	rebuildChips(skin, bigChips)
end

function C.setTheme(id)
	if currentTheme == id then return end
	currentTheme = id
	local th = D.THEME[id] or D.themes[1]
	Lighting.Ambient = Color3.fromHex(th.ambient):Lerp(Color3.new(0, 0, 0), 0.4)
	Lighting.OutdoorAmbient = Color3.fromHex(th.ambient)
	Lighting.FogColor = Color3.fromHex(th.fog)
	Lighting.FogStart = 60
	Lighting.FogEnd = 400
	local bp = workspace:FindFirstChild("Baseplate")
	if bp then bp.Color = Color3.fromHex(th.floor) end
end

---------------------------------------------------------------- effets visuels des améliorations
local function emojiBoard(text, rel, size)
	local anchor = mk("Part", { Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 }, visFolder)
	attach(anchor, rel)
	local bb = mk("BillboardGui", { Size = UDim2.fromScale(size, size), LightInfluence = 0, AlwaysOnTop = false }, anchor)
	mk("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, TextScaled = true, Font = Enum.Font.GothamBold }, bb)
	return anchor
end

local function neonPart(props, rel)
	local p = mk("Part", props, visFolder)
	p.Material = p.Material == Enum.Material.Plastic and Enum.Material.Neon or p.Material
	attach(p, rel)
	return p
end

local function particles(parent, props)
	return mk("ParticleEmitter", props, parent)
end

local function faceBoard(text)
	-- texte « collé » sur la face avant du cookie
	local p = mk("Part", { Size = Vector3.new(R * 1.4, R * 1.4, 0.1), Transparency = 1 }, visFolder)
	attach(p, CFrame.new(0, 0, THICK * 0.55))
	local sg = mk("SurfaceGui", { Face = Enum.NormalId.Back, LightInfluence = 0, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 20 }, p)
	mk("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, TextScaled = true, Font = Enum.Font.GothamBold }, sg)
	local sg2 = sg:Clone()
	sg2.Face = Enum.NormalId.Front
	sg2.Parent = p
	return p
end

function C.setVisuals(vis)
	-- clé de cache pour ne reconstruire que quand ça change
	local keys = {}
	for k, v in vis do table.insert(keys, k .. v) end
	table.sort(keys)
	local key = table.concat(keys, ",")
	if key == currentVisKey then return end
	currentVisKey = key
	for p in local_ do
		if p.Parent == visFolder or (p.Parent and p:IsDescendantOf(visFolder)) then local_[p] = nil end
	end
	visFolder:ClearAllChildren()
	orbiters, spinners = {}, {}
	beatPulse = vis.beat_pulse ~= nil
	for _, s in Lighting:GetChildren() do
		if s.Name == "CookieFx" then s:Destroy() end
	end

	if vis.glaze then
		neonPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, R * 1.6, R * 1.6), Color = Color3.fromHex("#ff8ad8"), Material = Enum.Material.SmoothPlastic }, CFrame.new(0, 0.6, THICK * 0.45) * CFrame.Angles(0, math.rad(90), 0))
		if vis.glaze >= 2 then
			neonPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, R * 1.6, R * 1.6), Color = Color3.fromHex("#8ad8ff"), Material = Enum.Material.SmoothPlastic }, CFrame.new(0, 0.6, -THICK * 0.45) * CFrame.Angles(0, math.rad(90), 0))
		end
	end
	if vis.sprinkles then
		local cols = { "#ff2bd6", "#1ff4ff", "#b6ff3b", "#ffc93c", "#8a5cff" }
		for i = 1, 18 * vis.sprinkles do
			local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * R * 0.8
			neonPart({ Size = Vector3.new(0.3, 1, 0.3), Color = Color3.fromHex(cols[i % #cols + 1]) }, CFrame.new(math.cos(a) * r, math.sin(a) * r, THICK * 0.62) * CFrame.Angles(0, 0, math.random() * 6))
		end
	end
	if vis.crystals then
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			neonPart({ Size = Vector3.new(1.2, 1.2, 1.2), Color = Color3.fromHex("#9ff3ff"), Material = Enum.Material.Glass, Transparency = 0.2 }, CFrame.new(math.cos(a) * R * 0.6, math.sin(a) * R * 0.6, THICK * 0.55) * CFrame.Angles(0.7, 0.7, 0))
		end
	end
	if vis.rgb_rim then
		local p = neonPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(THICK * 0.6, R * 2 + 1.6, R * 2 + 1.6), Color = Color3.new(1, 0, 1) }, CFrame.Angles(0, math.rad(90), 0))
		p.Name = "RGB"
	end
	if vis.face and not vis.shades then faceBoard("◕‿◕") end
	if vis.shades then faceBoard("😎") end
	if vis.crown then emojiBoard("👑", CFrame.new(0, R + 3, 0), 9) end
	if vis.headphones then emojiBoard("🎧", CFrame.new(0, R * 0.2, 0), 26) end
	if vis.bling then emojiBoard(vis.bling >= 2 and "📿💰" or "📿", CFrame.new(0, -R - 2, 1), 7) end
	if vis.halo then
		neonPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, R * 1.4, R * 1.4), Color = Color3.fromHex("#fff6a8") }, CFrame.new(0, R + 6, 0) * CFrame.Angles(0, 0, math.rad(90)))
	end
	if vis.wings then
		emojiBoard("🪽", CFrame.new(-R - 5, 2, 0), 12)
		emojiBoard("🪽", CFrame.new(R + 5, 2, 0), 12)
	end
	if vis.laser_eyes then
		for s = -1, 1, 2 do
			local p = neonPart({ Size = Vector3.new(0.4, 0.4, 40), Color = Color3.fromHex("#ff2020"), Transparency = 0.3 }, CFrame.new(s * 2.5, 2.5, THICK * 0.5 + 20))
			p.Name = "Laser"
		end
	end
	if vis.orbiters then
		for i = 1, vis.orbiters * 3 do
			local p = mk("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 3, 3), Color = body.Color, Material = Enum.Material.SmoothPlastic }, visFolder)
			weld(p)
			table.insert(orbiters, { part = p, off = i / (vis.orbiters * 3) * math.pi * 2, radius = R + 4 + (i % 3) * 2, speed = 0.8 + (i % 3) * 0.3 })
		end
	end
	if vis.saturn_ring then
		local p = neonPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, R * 3.4, R * 3.4), Color = Color3.fromHex("#ffc93c"), Transparency = 0.5 }, CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(20), 0, 0))
		table.insert(spinners, { part = p, speed = 0.4 })
	end
	if vis.fire_aura then
		mk("Fire", { Size = 14 + 6 * vis.fire_aura, Heat = 12, Color = Color3.fromHex("#ff6a00"), SecondaryColor = Color3.fromHex("#ff2bd6") }, body)
	end
	if vis.lightning or vis.glitch then
		particles(body, { Rate = 12, Lifetime = NumberRange.new(0.1, 0.3), Speed = NumberRange.new(20), LightEmission = 1, Size = NumberSequence.new(0.6), Color = ColorSequence.new(Color3.fromHex("#1ff4ff"), Color3.fromHex("#ff2bd6")), SpreadAngle = Vector2.new(180, 180) })
	end
	if vis.holo or vis.galaxy_core then
		mk("Sparkles", { SparkleColor = Color3.fromHex(vis.galaxy_core and "#b16bff" or "#39f0ff") }, body)
	end
	if vis.cursor_rgb then
		for i = 1, 10 do
			local a = emojiBoard("👆", CFrame.new(), 3)
			local_[a] = nil
			table.insert(orbiters, { part = a, off = i / 10 * math.pi * 2, radius = R + 2, speed = -1.6 })
		end
	end
	if vis.chat then
		emojiBoard("💬 W  🔥 no cap  👑 GOAT", CFrame.new(R + 10, R, 0), 14)
	end
	if vis.cookie_rain then
		local sky = mk("Part", { Size = Vector3.new(160, 1, 160), Transparency = 1 }, visFolder)
		attach(sky, CFrame.new(0, 45, 0))
		particles(sky, { Rate = 25, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(15, 25), EmissionDirection = Enum.NormalId.Bottom, Size = NumberSequence.new(1.5), Color = ColorSequence.new(Color3.fromHex("#d99a4e")), Texture = "rbxasset://textures/particles/sparkles_main.dds" })
	end
	if vis.disco then
		local ball = neonPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), Color = Color3.fromHex("#e0e0ff"), Material = Enum.Material.Foil }, CFrame.new(0, R + 16, 0))
		table.insert(spinners, { part = ball, speed = 1 })
		for i = 1, 4 do
			mk("SpotLight", { Range = 60, Brightness = 5, Angle = 30, Face = Enum.NormalId.Bottom, Color = Color3.fromHSV(i / 4, 1, 1) }, ball)
		end
	end
	if vis.warp then
		particles(body, { Rate = 40, Lifetime = NumberRange.new(0.4), Speed = NumberRange.new(80), LightEmission = 1, Size = NumberSequence.new(0.3), Color = ColorSequence.new(Color3.new(1, 1, 1)), SpreadAngle = Vector2.new(180, 180) })
	end
	if vis.god_rays then
		mk("SunRaysEffect", { Name = "CookieFx", Intensity = 0.25, Spread = 0.8 }, Lighting)
		mk("BloomEffect", { Name = "CookieFx", Intensity = 1, Size = 30, Threshold = 0.9 }, Lighting)
	end
	if vis.black_hole then
		neonPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(R * 3, R * 3, R * 3), Color = Color3.new(0, 0, 0), Material = Enum.Material.SmoothPlastic }, CFrame.new(0, 0, -R * 2.2))
		local disk = neonPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, R * 4.5, R * 4.5), Color = Color3.fromHex("#ff6a00"), Transparency = 0.4 }, CFrame.new(0, 0, -R * 2.2) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(12), 0, 0))
		table.insert(spinners, { part = disk, speed = 2 })
	end
	if vis.afterimage then
		for i = 1, 3 do
			local ghost = mk("Part", { Shape = Enum.PartType.Cylinder, Size = body.Size, Color = Color3.fromHSV(i / 3, 1, 1), Material = Enum.Material.ForceField, Transparency = 0.3 }, visFolder)
			attach(ghost, CFrame.new(i * 1.5 - 3, 0, -1 - i) * BASE_ROT:Inverse())
		end
	end
end

---------------------------------------------------------------- pets qui suivent le joueur
local petBoards = {}
function C.setPets(list) -- list = { {emoji, color} }
	for _, b in petBoards do b.part:Destroy() end
	petBoards = {}
	for i, p in list do
		local part = mk("Part", { Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1, Anchored = true, CanCollide = false, CanQuery = false }, petFolder)
		local bb = mk("BillboardGui", { Size = UDim2.fromScale(3, 3), LightInfluence = 0 }, part)
		mk("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = p.emoji, TextScaled = true, Font = Enum.Font.GothamBold }, bb)
		mk("PointLight", { Color = Color3.fromHex(p.color), Range = 6, Brightness = 2 }, part)
		table.insert(petBoards, { part = part, i = i })
	end
end

---------------------------------------------------------------- interactions
function C.isCookie(inst)
	return inst and model and inst:IsDescendantOf(model)
end

function C.pulse(crit)
	scalePulse = crit and 0.18 or 0.08
end

function C.worldPos()
	return CENTER
end

function C.shockwave(color)
	local ring = mk("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, R * 2, R * 2), Color = color or Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.3, Anchored = true, CanCollide = false, CanQuery = false, CFrame = pivot * BASE_ROT }, workspace)
	TweenService:Create(ring, TweenInfo.new(0.5), { Size = Vector3.new(0.2, R * 5, R * 5), Transparency = 1 }):Play()
	task.delay(0.55, function() ring:Destroy() end)
end

function C.confetti()
	local p = mk("Part", { Size = Vector3.new(1, 1, 1), Transparency = 1, Anchored = true, CanCollide = false, CanQuery = false, Position = CENTER + Vector3.new(0, 0, THICK) }, workspace)
	local e = particles(p, { Rate = 0, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(20, 35), SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -40, 0), Size = NumberSequence.new(0.5), Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("#ff2bd6")), ColorSequenceKeypoint.new(0.5, Color3.fromHex("#1ff4ff")), ColorSequenceKeypoint.new(1, Color3.fromHex("#b6ff3b")) }), LightEmission = 0.6 })
	e:Emit(25)
	task.delay(2, function() p:Destroy() end)
end

---------------------------------------------------------------- animation
function C.start()
	build()
	local t0 = os.clock()
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		scalePulse = math.max(0, scalePulse - dt * 0.6)
		local beat = beatPulse and (math.max(0, math.sin(t * math.pi * 4)) ^ 8) * 0.05 or 0
		local s = 1 + scalePulse + beat
		pivot = CFrame.new(CENTER + Vector3.new(0, math.sin(t * 1.5) * 0.8, 0)) * CFrame.Angles(0, math.sin(t * 0.6) * 0.5, 0)
		body.Size = Vector3.new(THICK, R * 2, R * 2) * s
		body.CFrame = pivot * BASE_ROT
		rim.Size = Vector3.new(THICK * 0.8, R * 2 + 0.8, R * 2 + 0.8) * s
		rim.CFrame = pivot * BASE_ROT
		if rgbSkin then body.Color = Color3.fromHSV((t * 0.15) % 1, 0.7, 1) end
		for p, rel in local_ do
			if p.Parent then
				local cf = rel
				p.CFrame = pivot * CFrame.new(cf.Position * s) * (cf - cf.Position)
				if p.Name == "RGB" then p.Color = Color3.fromHSV((t * 0.3) % 1, 1, 1) end
			else
				local_[p] = nil
			end
		end
		for _, o in orbiters do
			local a = o.off + t * o.speed
			o.part.CFrame = pivot * CFrame.new(math.cos(a) * o.radius, math.sin(a) * o.radius * 0.35, math.sin(a) * o.radius) * CFrame.Angles(0, a, 0)
		end
		for _, sp in spinners do
			if local_[sp.part] then local_[sp.part] *= CFrame.Angles(sp.speed * dt, 0, 0) end
		end
		-- pets autour du joueur
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local n = #petBoards
			for _, b in petBoards do
				local a = b.i / math.max(1, n) * math.pi * 2 + t * 0.8
				local target = root.Position + Vector3.new(math.cos(a) * 5, 2 + math.sin(t * 3 + b.i) * 0.5, math.sin(a) * 5)
				b.part.Position = b.part.Position:Lerp(target, math.min(1, dt * 6))
			end
		end
	end)
end

return C
