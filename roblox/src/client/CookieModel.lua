-- COOKIE OVERDRIVE — le cookie géant (dessiné comme sur le site, sur un disque 3D)
-- Local : chaque joueur voit son propre skin et ses améliorations.
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local D = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameData"))

local C = {}
C.scene = nil -- décor (Scene.lua), branché par Main

local CENTER = Vector3.new(0, 15, 0)
local R = 10 -- rayon
local THICK = 3

local model, body, rim, faceFolder, visFolder, petFolder
local pivot = CFrame.new(CENTER)
local currentSkin, currentTheme, currentVisKey
local skinDef, bigChips, faceVis = nil, false, {}
local rgbSkin = false
local scalePulse = 0
local orbiters, spinners = {}, {}
local beatPulse = false

-- le cylindre Roblox a son axe sur X : on le tourne pour que ses faces regardent la caméra (+Z)
local BASE_ROT = CFrame.Angles(0, math.rad(90), 0)
local local_ = {} -- [part] = CFrame relatif au cookie

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

local function attach(p, rel)
	weld(p)
	local_[p] = rel
end

---------------------------------------------------------------- dessin du cookie
-- positions des pépites (coordonnées -1..1)
local CHIPS = { { -0.45, 0.35 }, { 0.35, 0.45 }, { 0.05, -0.05 }, { -0.35, -0.4 }, { 0.5, -0.3 }, { -0.7, -0.05 }, { 0.15, 0.75 }, { 0.72, 0.15 }, { -0.1, -0.75 }, { -0.55, 0.7 }, { 0.62, -0.62 } }
local SPRINKLES = { "#ff2bd6", "#1ff4ff", "#b6ff3b", "#ffc93c", "#8a5cff" }
local faceRoots = {}

local function circle(parent, cx, cy, size, color, z)
	local f = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cx, cy), Size = UDim2.fromScale(size, size),
		BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z or 1,
	}, parent)
	mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
	return f
end

local function drawFace(root, skin, big, vis)
	root:ClearAllChildren()
	local hex = Color3.fromHex
	local base, dark, light, rimC = hex(skin.base), hex(skin.dark), hex(skin.light), hex(skin.rim)
	local rng = Random.new(42) -- même dessin à chaque fois
	local grad = ColorSequence.new({ ColorSequenceKeypoint.new(0, light), ColorSequenceKeypoint.new(0.45, base), ColorSequenceKeypoint.new(1, dark) })
	-- bord bosselé (contour sombre)
	circle(root, 0.5, 0.5, 0.95, rimC, 1)
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2
		circle(root, 0.5 + math.cos(a) * 0.44, 0.5 + math.sin(a) * 0.44, 0.12 + (i % 3) * 0.015, rimC, 1)
	end
	-- pâte : dégradé lumière (haut-gauche) → ombre (bas-droite)
	local dough = circle(root, 0.5, 0.5, 0.91, Color3.new(1, 1, 1), 2)
	mk("UIGradient", { Rotation = 55, Color = grad }, dough)
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2
		local bump = circle(root, 0.5 + math.cos(a) * 0.415, 0.5 + math.sin(a) * 0.415, 0.1 + (i % 3) * 0.012, Color3.new(1, 1, 1), 2)
		mk("UIGradient", { Rotation = 55, Color = grad }, bump)
	end
	-- glaçage (amélioration)
	if vis.glaze then
		local gl = circle(root, 0.5, 0.48, 0.7, hex(vis.glaze >= 2 and "#8ad8ff" or "#ff8ad8"), 3)
		gl.BackgroundTransparency = 0.1
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			circle(root, 0.5 + math.cos(a) * 0.33, 0.48 + math.sin(a) * 0.33 + (i % 2) * 0.03, 0.1, gl.BackgroundColor3, 3).BackgroundTransparency = 0.1
		end
	end
	-- reflet doux
	circle(root, 0.36, 0.33, 0.34, light, 3).BackgroundTransparency = 0.75
	-- craquelures
	for _ = 1, 8 do
		mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.22 + rng:NextNumber() * 0.56, 0.22 + rng:NextNumber() * 0.56),
			Size = UDim2.fromScale(0.05 + rng:NextNumber() * 0.1, 0.007), Rotation = rng:NextInteger(0, 180),
			BackgroundColor3 = dark, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 3,
		}, root)
	end
	-- pépites (ombre + pépite + éclat)
	local sz = big and 0.12 or 0.09
	for _, c in CHIPS do
		local x, y = 0.5 + c[1] * 0.34, 0.5 + c[2] * 0.34
		local s2 = sz * (0.8 + rng:NextNumber() * 0.45)
		circle(root, x + 0.006, y + 0.012, s2, dark, 4).BackgroundTransparency = 0.25
		local chip = circle(root, x, y, s2, hex(skin.chip), 5)
		chip.Rotation = rng:NextInteger(0, 90)
		chip:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.4, 0)
		circle(root, x - s2 * 0.2, y - s2 * 0.22, s2 * 0.34, hex(skin.chipHi), 6).BackgroundTransparency = 0.2
	end
	-- vermicelles (amélioration)
	if vis.sprinkles then
		for i = 1, 16 * vis.sprinkles do
			local a, r = rng:NextNumber() * math.pi * 2, math.sqrt(rng:NextNumber()) * 0.36
			mk("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r),
				Size = UDim2.fromScale(0.045, 0.012), Rotation = rng:NextInteger(0, 180), BorderSizePixel = 0, ZIndex = 7,
				BackgroundColor3 = hex(SPRINKLES[i % #SPRINKLES + 1]),
			}, root)
		end
	end
end

function C.redrawFace(vis)
	faceVis = vis or faceVis
	if not skinDef then return end
	for _, root in faceRoots do drawFace(root, skinDef, bigChips, faceVis) end
end

local function build()
	model = mk("Model", { Name = "MyCookie" }, workspace)
	body = mk("Part", {
		Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(THICK, R * 2, R * 2),
		Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false, CastShadow = false,
	}, model)
	rim = mk("Part", {
		Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(THICK * 0.8, R * 2 + 0.6, R * 2 + 0.6),
		Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false, CastShadow = false,
	}, model)
	faceFolder = mk("Folder", { Name = "Faces" }, model)
	for side = -1, 1, 2 do
		local face = mk("Part", { Name = "Face", Size = Vector3.new(R * 2.1, R * 2.1, 0.05), Transparency = 1 }, faceFolder)
		attach(face, CFrame.new(0, 0, side * (THICK / 2 + 0.05)))
		local sg = mk("SurfaceGui", {
			Face = side > 0 and Enum.NormalId.Back or Enum.NormalId.Front, LightInfluence = 0.1, Brightness = 1.1,
			CanvasSize = Vector2.new(640, 640), ClipsDescendants = true,
		}, face)
		table.insert(faceRoots, mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, sg))
	end
	visFolder = mk("Folder", { Name = "Visuals" }, model)
	model.PrimaryPart = body
	mk("PointLight", { Range = 30, Brightness = 1, Color = Color3.fromHex("#ffc93c") }, body)
	petFolder = mk("Folder", { Name = "MyPets" }, workspace)
end

function C.setSkin(id, big)
	local skin = D.SKIN[id] or D.skins[1]
	local key = id .. tostring(big)
	if currentSkin == key then return end
	currentSkin = key
	skinDef, bigChips = skin, big
	body.Color = Color3.fromHex(skin.dark)
	rim.Color = Color3.fromHex(skin.rim)
	rgbSkin = skin.rgb == true
	C.redrawFace()
end

function C.setTheme(id)
	if currentTheme == id then return end
	currentTheme = id
	if C.scene then C.scene.setTheme(id) end
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

	C.redrawFace(vis)
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

---------------------------------------------------------------- pets (flottent autour du cookie)
local petBoards = {}
function C.setPets(list) -- list = { {emoji, color} }
	for _, b in petBoards do b.part:Destroy() end
	petBoards = {}
	for i, p in list do
		local part = mk("Part", { Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1, Anchored = true, CanCollide = false, CanQuery = false }, petFolder)
		local bb = mk("BillboardGui", { Size = UDim2.fromScale(4, 4), LightInfluence = 0 }, part)
		mk("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = p.emoji, TextScaled = true, Font = Enum.Font.GothamBold }, bb)
		mk("PointLight", { Color = Color3.fromHex(p.color), Range = 8, Brightness = 2 }, part)
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
		-- léger flottement, le cookie reste face à la caméra comme sur le site
		pivot = CFrame.new(CENTER + Vector3.new(0, math.sin(t * 1.5) * 0.35, 0)) * CFrame.Angles(0, math.sin(t * 0.5) * 0.1, math.sin(t * 0.8) * 0.03)
		body.Size = Vector3.new(THICK, R * 2, R * 2) * s
		body.CFrame = pivot * BASE_ROT
		rim.Size = Vector3.new(THICK * 0.8, R * 2 + 0.6, R * 2 + 0.6) * s
		rim.CFrame = pivot * BASE_ROT
		if rgbSkin then rim.Color = Color3.fromHSV((t * 0.15) % 1, 0.8, 1) end
		for p, rel in local_ do
			if p.Parent then
				p.CFrame = pivot * CFrame.new(rel.Position * s) * (rel - rel.Position)
				if p.Name == "Face" then p.Size = Vector3.new(R * 2.1 * s, R * 2.1 * s, 0.05) end
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
		-- pets
		local n = #petBoards
		for _, b in petBoards do
			local a = (b.i - 0.5) / math.max(1, n) * math.pi * 2 + t * 0.35
			b.part.Position = CENTER + Vector3.new(math.cos(a) * (R + 5), math.sin(a) * (R + 3) * 0.6 + math.sin(t * 3 + b.i) * 0.4, 3)
		end
	end)
end

return C
