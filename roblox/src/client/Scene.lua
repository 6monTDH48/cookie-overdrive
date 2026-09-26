-- COOKIE OVERDRIVE — décor synthwave (comme le site) + caméra fixe type « clicker »
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

local S = {}

local camera = workspace.CurrentCamera
local folder
local sunGrad, gridParts, mountainEdges = nil, {}, {}
local COOKIE = Vector3.new(0, 15, 0)
local CAM_DIST = 67
local FOV = 50
local CAM_Y = 11.4
local PITCH = 0.137 -- caméra levée : l'horizon passe sous le cookie, comme sur le site
S.rightInset = 0 -- largeur (px) occupée par le panneau à droite

-- thème → couleurs du décor
local THEMES = {
	synthwave = { sunTop = "#ffd23c", sunBot = "#ff2bd6", grid = "#1ff4ff", sky = "#6b1a8f", haze = "#ff3d9a", floor = "#0d0420", mount = "#1a0536" },
	galaxy = { sunTop = "#ff9cf5", sunBot = "#7a2cff", grid = "#b16bff", sky = "#2b1060", haze = "#7a2cff", floor = "#070214", mount = "#12052e" },
	matrix = { sunTop = "#b6ff3b", sunBot = "#00a85a", grid = "#00ff88", sky = "#003a1c", haze = "#00ff88", floor = "#010a06", mount = "#02180c" },
	candy = { sunTop = "#fff3b3", sunBot = "#ff8ad8", grid = "#8ad8ff", sky = "#ffb3e6", haze = "#ffd6f2", floor = "#3a2360", mount = "#6b4a9a" },
	inferno = { sunTop = "#ffd000", sunBot = "#ff3d00", grid = "#ff6a00", sky = "#5a0505", haze = "#ff3d00", floor = "#1a0202", mount = "#2a0404" },
	aurora = { sunTop = "#b7fbff", sunBot = "#0bd6a0", grid = "#5b3cff", sky = "#02303a", haze = "#0bd6a0", floor = "#02101a", mount = "#032028" },
}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = folder
	return p
end

local function build()
	folder = Instance.new("Folder")
	folder.Name = "SynthwaveScene"
	folder.Parent = workspace

	-- éclairage de nuit
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.GlobalShadows = false
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.12
	atm.Offset = 0.1
	atm.Glare = 0.4
	atm.Haze = 1.5
	atm.Parent = Lighting
	S.atm = atm
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 24
	bloom.Threshold = 0.85
	bloom.Parent = Lighting

	-- sol sombre
	S.floor = part({ Size = Vector3.new(2000, 1, 2000), Position = Vector3.new(0, -0.6, -600), Material = Enum.Material.SmoothPlastic })

	-- grille néon (lignes vers l'horizon + lignes transversales)
	for i = -60, 60 do
		table.insert(gridParts, part({ Size = Vector3.new(0.25, 0.1, 1400), Position = Vector3.new(i * 12, 0, -600), Material = Enum.Material.Neon }))
	end
	for j = 0, 60 do
		table.insert(gridParts, part({ Size = Vector3.new(1600, 0.1, 0.25), Position = Vector3.new(0, 0, 40 - j * 14), Material = Enum.Material.Neon }))
	end

	-- soleil rayé
	local sun = part({ Size = Vector3.new(314, 314, 1), Position = Vector3.new(0, 108, -700), Transparency = 1 })
	S.sun = sun
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.LightInfluence = 0
	sg.Brightness = 1.4
	sg.CanvasSize = Vector2.new(520, 520)
	sg.Parent = sun
	local disc = Instance.new("CanvasGroup")
	disc.Size = UDim2.fromScale(1, 1)
	disc.BackgroundColor3 = Color3.new(1, 1, 1)
	disc.Parent = sg
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = disc
	sunGrad = Instance.new("UIGradient")
	sunGrad.Rotation = 90
	sunGrad.Parent = disc
	for k = 0, 7 do
		local stripe = Instance.new("Frame")
		stripe.BorderSizePixel = 0
		stripe.BackgroundColor3 = Color3.fromHex("#0b0620")
		stripe.Position = UDim2.fromScale(0, 0.5 + k * 0.06)
		stripe.Size = UDim2.new(1, 0, 0, 3 + k * 2.2)
		stripe.Parent = disc
		S["stripe" .. k] = stripe
	end

	-- montagnes (silhouettes à bord néon)
	math.randomseed(7)
	for i = -12, 12 do
		local h = 30 + math.random() * 60
		local w = 80 + math.random() * 60
		local cf = CFrame.new(i * 55, -4 + h * 0.05, -560 - math.random() * 60) * CFrame.Angles(0, 0, math.rad(45))
		local m = part({ Size = Vector3.new(w * 0.5, w * 0.5, 4), CFrame = cf, Material = Enum.Material.SmoothPlastic })
		local edge = part({ Size = m.Size + Vector3.new(1.2, 1.2, -3), CFrame = cf * CFrame.new(0, 0, -1), Material = Enum.Material.Neon })
		table.insert(mountainEdges, { m, edge })
	end
	math.randomseed(os.clock() * 1000)
end

function S.setTheme(id)
	local th = THEMES[id] or THEMES.synthwave
	local hex = Color3.fromHex
	sunGrad.Color = ColorSequence.new(hex(th.sunTop), hex(th.sunBot))
	for _, g in gridParts do g.Color = hex(th.grid) end
	S.floor.Color = hex(th.floor)
	for k = 0, 7 do S["stripe" .. k].BackgroundColor3 = hex(th.floor) end
	for _, pair in mountainEdges do
		pair[1].Color = hex(th.mount)
		pair[2].Color = hex(th.haze)
	end
	S.atm.Color = hex(th.sky)
	S.atm.Decay = hex(th.haze)
	Lighting.Ambient = hex(th.sky)
	Lighting.OutdoorAmbient = hex(th.sky)
	local bp = workspace:FindFirstChild("Baseplate")
	if bp then bp.Transparency = 1 end
end

-- position à l'écran (fraction 0..1 de la largeur) où doit apparaître le cookie
local function cookieScreenX()
	local vw = camera.ViewportSize.X
	local area = vw - S.rightInset
	return (area / 2) / vw
end

function S.start()
	build()
	S.setTheme("synthwave")
	-- écran épuré comme sur le site : pas de liste des joueurs, d'inventaire ni de fenêtre de chat
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	pcall(function()
		local tcs = game:GetService("TextChatService")
		tcs:WaitForChild("ChatWindowConfiguration", 5).Enabled = false
		tcs:WaitForChild("ChatInputBarConfiguration", 5).Enabled = false
	end)
	RunService:BindToRenderStep("CookieCamera", Enum.RenderPriority.Camera.Value + 1, function()
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = FOV
		local vp = camera.ViewportSize
		local aspect = vp.X / math.max(1, vp.Y)
		local halfW = math.tan(math.rad(FOV / 2)) * CAM_DIST * aspect
		-- décale la caméra pour centrer le cookie dans la zone de jeu (à gauche du panneau)
		local xOff = (0.5 - cookieScreenX()) * 2 * halfW
		local pos = Vector3.new(xOff, CAM_Y, COOKIE.Z + CAM_DIST)
		camera.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, math.tan(PITCH), -1))
		-- le soleil reste pile derrière le cookie à l'écran
		local sunDepth = CAM_DIST + 700
		S.sun.Position = Vector3.new(xOff * (1 - sunDepth / CAM_DIST), CAM_Y + 0.126 * sunDepth, -700)
	end)
end

return S
