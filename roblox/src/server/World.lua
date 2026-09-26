-- COOKIE OVERDRIVE — décor partagé : arène néon + classement mondial
-- (le cookie géant est construit côté client pour que chacun voie son propre skin)
local World = {}

local boardFrame

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = workspace
	return p
end

function World.init()
	local arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = workspace

	-- piédestal central
	local ped = part({ Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 34, 34), CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromHex("#1a0b33"), Material = Enum.Material.SmoothPlastic })
	ped.Parent = arena
	local ring = part({ Name = "NeonRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 36, 36), CFrame = CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromHex("#ff2bd6"), Material = Enum.Material.Neon, CanCollide = false })
	ring.Parent = arena

	-- piliers néon autour de l'arène
	local cols = { "#ff2bd6", "#1ff4ff", "#b6ff3b", "#ffc93c", "#8a5cff", "#ff4d6d" }
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		local p = part({ Name = "Pillar", Size = Vector3.new(2, 30, 2), CFrame = CFrame.new(math.cos(a) * 70, 15, math.sin(a) * 70), Color = Color3.fromHex(cols[(i - 1) % #cols + 1]), Material = Enum.Material.Neon })
		p.Parent = arena
		local l = Instance.new("PointLight")
		l.Color = p.Color
		l.Range = 30
		l.Brightness = 2
		l.Parent = p
	end

	-- panneau du classement
	local bd = part({ Name = "Leaderboard", Size = Vector3.new(30, 20, 1), CFrame = CFrame.new(0, 14, -60), Color = Color3.fromHex("#0b0620"), Material = Enum.Material.SmoothPlastic })
	bd.Parent = arena
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.Parent = bd
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.15, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromHex("#ffc93c")
	title.Text = "🏆 TOP COOKIE BAKERS 🏆"
	title.Parent = sg
	boardFrame = Instance.new("Frame")
	boardFrame.BackgroundTransparency = 1
	boardFrame.Position = UDim2.new(0.05, 0, 0.17, 0)
	boardFrame.Size = UDim2.new(0.9, 0, 0.8, 0)
	boardFrame.Parent = sg
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0.01, 0)
	lay.Parent = boardFrame

	-- panneau boutique Robux (décoratif, invite à ouvrir l'onglet Boutique)
	local shop = part({ Name = "ShopSign", Size = Vector3.new(22, 8, 1), CFrame = CFrame.new(-45, 10, -40) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromHex("#2bdc6a"), Material = Enum.Material.Neon })
	shop.Parent = arena
	local ssg = Instance.new("SurfaceGui")
	ssg.Face = Enum.NormalId.Back
	ssg.Parent = shop
	local st = Instance.new("TextLabel")
	st.Size = UDim2.fromScale(1, 1)
	st.BackgroundTransparency = 1
	st.Font = Enum.Font.FredokaOne
	st.TextScaled = true
	st.TextColor3 = Color3.new(1, 1, 1)
	st.TextStrokeTransparency = 0
	st.Text = "💎 BOUTIQUE : Cookies ×2, Auto-Clicker, VIP ! 💎"
	st.Parent = ssg
end

function World.setLeaderboard(rows)
	if not boardFrame then return end
	for _, c in boardFrame:GetChildren() do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	local D = require(game:GetService("ReplicatedStorage").Shared.GameData)
	for _, r in rows do
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0.09, 0)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = r.rank == 1 and Color3.fromHex("#ffc93c") or Color3.new(1, 1, 1)
		l.Text = string.format("#%d  %s  —  %s 🍪", r.rank, r.name, D.fmt(r.value))
		l.LayoutOrder = r.rank
		l.Parent = boardFrame
	end
end

function World.onJoin(player)
	-- tag VIP au-dessus de la tête
	player.CharacterAdded:Connect(function(char)
		if not player:GetAttribute("VIP") then return end
		local head = char:WaitForChild("Head", 5)
		if not head then return end
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(120, 30)
		bb.StudsOffset = Vector3.new(0, 2.5, 0)
		bb.AlwaysOnTop = true
		bb.Parent = head
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.fromHex("#ffc93c")
		t.TextStrokeTransparency = 0
		t.Text = "👑 VIP"
		t.Parent = bb
	end)
end

return World
