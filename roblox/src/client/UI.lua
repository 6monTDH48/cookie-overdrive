-- COOKIE OVERDRIVE — interface calquée sur le site :
-- logo en haut à gauche, compteur au-dessus du cookie, panneau à onglets ancré à droite (bord RGB),
-- gemmes / étoiles / cadeau en haut à droite, fil d'infos en bas.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")

local D = require(RS.Shared.GameData)
local E = require(RS.Shared.Econ)
local Shop = require(RS.Shared.Monetization)
local K = require(script.Parent.Kit)
local new, Cc = K.new, K.colors

local UI = {}
local Store, act, onCookieTap, Minigames
local gui, play, panel, tabBar, body, goldenLayer, fxLayer, toastList, modalLayer
local refs = {}
local _ = onCookieTap
local currentTab = "buildings"
local rowUpdaters = {}
local buyQty = 1
local hue = 0

local TOP = 64 -- espace laissé à la barre Roblox
local DIM = Color3.fromHex("#7d6fae")
local PINK = Color3.fromHex("#ff8a9c")
local CREAM = Color3.fromHex("#ffe2b0")

---------------------------------------------------------------------------- utilitaires
local function fmt(n) return D.fmt(n or 0) end
local function rgbSeq(offset)
	local ks = {}
	for i = 0, 6 do
		table.insert(ks, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(((i / 6) + (offset or 0)) % 1, 0.9, 1)))
	end
	return ColorSequence.new(ks)
end

local function text(t, size, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Text = t, Font = K.DISPLAY, TextSize = size, TextColor3 = Cc.ink,
		Size = UDim2.new(1, 0, 0, size + 4), TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
	})
	for k, v in props or {} do l[k] = v end
	return l
end
local function outlined(l, th)
	new("UIStroke", { Color = Cc.stroke, Thickness = th or 2, Parent = l })
	return l
end
local function bodyText(t, size, props)
	local p = { Font = K.BODY, TextColor3 = Cc.muted, TextWrapped = true }
	for k, v in props or {} do p[k] = v end
	return text(t, size, p)
end

-- bouton « 3D » façon site (.btn) : couleur haute/basse + ombre
local BTN = {
	violet = { "#7a5cff", "#5a3de0" }, green = { "#4dff8a", "#1fc85a" }, pink = { "#ff6be6", "#ff2bd6" },
	gold = { "#ffe066", "#ffb800" }, cyan = { "#7ffaff", "#1fd6ff" }, red = { "#ff8095", "#ff3d5e" }, dark = { "#3a2a70", "#2a1b58" },
}
local function btn(label, kind, props, onClick)
	local c = BTN[kind] or BTN.violet
	local b = new("TextButton", {
		Text = label, Font = K.DISPLAY, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(110, 38),
	}, {
		K.corner(13), new("UIStroke", { Color = Cc.stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex(c[1]), Color3.fromHex(c[2])) }),
		new("UIStroke", { Color = Color3.fromHex("#1a0b33"), Thickness = 1.5, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }),
	})
	for k, v in props or {} do b[k] = v end
	if onClick then
		b.MouseButton1Click:Connect(function()
			local s = b.Size
			b.Size = UDim2.new(s.X.Scale, s.X.Offset - 4, s.Y.Scale, s.Y.Offset - 3)
			task.delay(0.08, function() b.Size = s end)
			onClick(b)
		end)
	end
	return b
end
local function setBtnKind(b, kind)
	local c = BTN[kind] or BTN.violet
	b:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(Color3.fromHex(c[1]), Color3.fromHex(c[2]))
end

-- carré d'icône (.ico) : dégradé violet + contour sombre
local function icon(emoji, size, parent, pos)
	local f = new("Frame", {
		Size = UDim2.fromOffset(size, size), Position = pos or UDim2.new(), BackgroundColor3 = Color3.new(1, 1, 1), Parent = parent,
	}, {
		K.corner(math.floor(size * 0.28)), new("UIStroke", { Color = Cc.stroke, Thickness = 3 }),
		new("UIGradient", { Rotation = 60, Color = ColorSequence.new(Color3.fromHex("#4a3690"), Color3.fromHex("#1d0f45")) }),
	})
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = emoji, TextScaled = true, Font = K.BOLD, Parent = f }, {
		new("UIPadding", { PaddingTop = UDim.new(0.16, 0), PaddingBottom = UDim.new(0.16, 0), PaddingLeft = UDim.new(0.16, 0), PaddingRight = UDim.new(0.16, 0) }),
	})
	return f
end

-- ligne de liste (.brow)
local function rowFrame(order, height)
	local r = new("TextButton", {
		Text = "", AutoButtonColor = false, LayoutOrder = order, Size = UDim2.new(1, 0, 0, height or 76),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.955, Parent = body,
	}, { K.corner(18), new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.93, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	return r
end
local function setCan(r, can)
	local st = r:FindFirstChildOfClass("UIStroke")
	st.Transparency = can and 0.2 or 0.93
	st.Color = can and Color3.fromHSV(hue, 0.7, 1) or Color3.new(1, 1, 1)
	r.BackgroundColor3 = can and Cc.green or Color3.new(1, 1, 1)
	r.BackgroundTransparency = can and 0.86 or 0.955
	r:SetAttribute("can", can)
end

local function secTitle(order, title, note)
	local f = new("Frame", { LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = body })
	outlined(text(title, 24, { Size = UDim2.new(1, 0, 1, 0), Parent = f }))
	if note then
		bodyText(note, 12, { Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.new(0.45, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = f })
	end
	return f
end
local function subTitle(order, t)
	outlined(text(t, 17, { LayoutOrder = order, TextColor3 = Color3.fromHex("#e8dcff"), Parent = body, Size = UDim2.new(1, 0, 0, 28) }))
end

---------------------------------------------------------------------------- toasts, textes flottants, popups
function UI.toast(t, color)
	if not toastList then return end
	local f = new("Frame", {
		Size = UDim2.new(0, 0, 0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromHex("#0a0518"),
		BackgroundTransparency = 0.2, Parent = toastList,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = color and Color3.fromHex(color) or Cc.hot, Thickness = 2 }), new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) })
	outlined(text(t, 16, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center, Parent = f }))
	task.delay(4, function()
		if f.Parent then f:Destroy() end
	end)
end

function UI.floatText(t, pos, color, size)
	if not fxLayer then return end
	local l = outlined(text(t, size or 28, {
		Size = UDim2.fromOffset(320, 44), AnchorPoint = Vector2.new(0.5, 0.5), TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(pos.X + math.random(-25, 25), pos.Y - 10), TextColor3 = color or Cc.ink, Parent = fxLayer,
	}), 3)
	TweenService:Create(l, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = l.Position - UDim2.fromOffset(0, 100), TextTransparency = 1 }):Play()
	TweenService:Create(l:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.9), { Transparency = 1 }):Play()
	task.delay(0.95, function() l:Destroy() end)
end

local function closeModal()
	modalLayer:ClearAllChildren()
	modalLayer.Visible = false
end

function UI.modal(title, msg, buttons, accent)
	modalLayer:ClearAllChildren()
	modalLayer.Visible = true
	local box = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromHex("#1a0d3d"), Parent = modalLayer,
	}, {
		K.corner(26), new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3 }), K.pad(20), K.list(12),
		new("UISizeConstraint", { MaxSize = Vector2.new(440, 640) }),
	})
	new("UIGradient", { Rotation = 45, Color = rgbSeq(0), Parent = box:FindFirstChildOfClass("UIStroke") })
	outlined(text(title, 30, { LayoutOrder = 1, TextColor3 = accent or Cc.ink, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Parent = box }), 3)
	bodyText(msg, 17, { LayoutOrder = 2, TextColor3 = Cc.ink, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = box })
	local r = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 3, Parent = box }, { K.list(10, Enum.FillDirection.Horizontal) })
	for _, b in buttons or { { "OK", "green" } } do
		btn(b[1], b[2], { Size = UDim2.fromOffset(160, 46), TextSize = 19, Parent = r }, function()
			closeModal()
			if b[3] then b[3]() end
		end)
	end
end

---------------------------------------------------------------------------- barre du haut (logo + icônes)
local function buildTopBar()
	-- logo
	local logo = new("Frame", { Position = UDim2.fromOffset(16, TOP - 8), Size = UDim2.fromOffset(330, 44), BackgroundTransparency = 1, Parent = gui }, { K.list(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left) })
	logo:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(40, 40), Text = "🍪", TextScaled = true, Font = K.BOLD, Parent = logo })
	outlined(text('COOKIE <font color="#9b6bff">OVERDRIVE</font>', 30, { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Parent = logo }), 2.5)
	refs.logo = logo

	-- icônes en haut à droite
	local bar = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 10), Size = UDim2.fromOffset(460, 46), BackgroundTransparency = 1, Parent = gui }, {
		K.list(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right),
	})
	bar:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center
	local function chip(order)
		local f = new("Frame", { LayoutOrder = order, Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromHex("#0a0518"), BackgroundTransparency = 0.35, Parent = bar }, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.92, Thickness = 2 }),
			new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }),
		})
		return text("", 18, { Font = K.BOLD, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = f })
	end
	refs.gems = chip(1)
	refs.stars = chip(2)
	local function iconBtn(order, emoji, kind, onClick)
		local b = btn(emoji, kind, { LayoutOrder = order, Size = UDim2.fromOffset(44, 44), TextSize = 24 }, onClick)
		b.Parent = bar
		return b
	end
	refs.gift = iconBtn(3, "🎁", "gold", function()
		local r = act("gift")
		if r then UI.modal("🎁 CADEAU !", r, { { "Merci !", "green" } }, Cc.gold) end
	end)
	refs.giftTag = outlined(text("PRÊT", 11, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(52, 16), TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("#1a0d3d"), ZIndex = 3, Parent = refs.gift }))
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = refs.giftTag })
	refs.auto = iconBtn(4, "🤖", "cyan", function() act("autoClick", not Store.state.autoClick) end)
	refs.auto.Visible = false
	refs.shopBtn = iconBtn(5, "💎", "green", function() UI.openTab("shop") end)
end

---------------------------------------------------------------------------- zone de jeu (à gauche du panneau)
local function buildPlay()
	play = new("Frame", { Name = "Play", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, TOP + 40), Size = UDim2.new(1, 0, 1, -(TOP + 40)), Parent = gui })
	goldenLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = play })

	-- compteur (#hud)
	local hud = new("Frame", { Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1, Parent = play }, { K.list(4) })
	text("🏠 La Boulangerie RGB", 16, { LayoutOrder = 1, TextColor3 = CREAM, Font = K.BOLD, TextXAlignment = Enum.TextXAlignment.Center, Parent = hud })
	refs.count = outlined(text("0", 60, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 62), TextXAlignment = Enum.TextXAlignment.Center, Parent = hud }), 3)
	local pill = new("Frame", { LayoutOrder = 3, Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromHex("#0a051e"), BackgroundTransparency = 0.45, Parent = hud }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.92, Thickness = 2 }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})
	refs.cps = text("", 15, { Font = K.BOLD, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = pill })
	-- combo
	local combo = new("Frame", { LayoutOrder = 4, Size = UDim2.fromOffset(320, 36), BackgroundTransparency = 1, Parent = hud })
	refs.comboBox = combo
	refs.comboL = outlined(text("COMBO 0", 15, { Size = UDim2.new(1, 0, 0, 18), Parent = combo }))
	refs.comboM = outlined(text("×1", 15, { Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Right, Parent = combo }))
	local barBg = new("Frame", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = Color3.fromHex("#0a051e"), Parent = combo }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Cc.stroke, Thickness = 2 }),
	})
	refs.comboFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = barBg }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	refs.comboGrad = new("UIGradient", { Color = rgbSeq(0), Parent = refs.comboFill })
	-- buffs
	refs.buffs = new("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = hud }, { K.list(6, Enum.FillDirection.Horizontal) })

	-- « CLIQUE LE COOKIE ! »
	refs.hint = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.74, 0), Size = UDim2.fromOffset(300, 80), BackgroundTransparency = 1, Parent = play }, { K.list(0) })
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(46, 46), Text = "👆", TextScaled = true, Font = K.BOLD, Parent = refs.hint })
	outlined(text("CLIQUE LE COOKIE !", 24, { TextXAlignment = Enum.TextXAlignment.Center, Parent = refs.hint }), 2.5)

	-- bannières (fièvre, boss)
	local banners = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1, Parent = play }, {
		new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function banner(order)
		local f = new("Frame", { LayoutOrder = order, Visible = false, Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromHex("#0a051e"), BackgroundTransparency = 0.3, Parent = banners }, {
			K.corner(16), new("UIStroke", { Color = Cc.stroke, Thickness = 3 }), new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }),
		})
		local l = outlined(text("", 26, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = f }), 2.5)
		return f, l
	end
	refs.bossBox, refs.bossText = banner(1)
	local hpBg = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, -10, 1, -3), Size = UDim2.new(1, 20, 0, 6), BackgroundColor3 = Cc.stroke, Parent = refs.bossBox }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	refs.bossHp = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Cc.red, Parent = hpBg }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	refs.feverBox, refs.feverText = banner(2)
	refs.feverText.Text = "🌈 FIÈVRE RGB — TOUT ×3 !"

	-- toasts (au-dessus des bannières)
	toastList = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -200), Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1, ZIndex = 30, Parent = play }, {
		new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- fil d'infos (#ticker)
	local ticker = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -8), Size = UDim2.new(1, -28, 0, 30), BackgroundColor3 = Color3.fromHex("#080418"), BackgroundTransparency = 0.28, ClipsDescendants = true, Parent = play }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.92, Thickness = 2 }),
	})
	local tag = new("Frame", { Size = UDim2.new(0, 56, 1, 0), BackgroundColor3 = Cc.red, ZIndex = 2, Parent = ticker }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	text("INFO", 13, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2, Parent = tag })
	local track = new("Frame", { Position = UDim2.fromOffset(60, 0), Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true, Parent = ticker })
	local msg = text("", 14, { Font = K.BODY, TextColor3 = Color3.fromHex("#e9e0ff"), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = track })
	task.spawn(function()
		while true do
			msg.Text = D.news[math.random(#D.news)]
			msg.Position = UDim2.new(1, 0, 0, 0)
			task.wait()
			local dist = track.AbsoluteSize.X + msg.AbsoluteSize.X
			local tw = TweenService:Create(msg, TweenInfo.new(dist / 90, Enum.EasingStyle.Linear), { Position = UDim2.new(0, -msg.AbsoluteSize.X, 0, 0) })
			tw:Play()
			tw.Completed:Wait()
		end
	end)
end

---------------------------------------------------------------------------- panneau à onglets
local TABS = {
	{ id = "buildings", e = "🏭", l = "Shop" },
	{ id = "upgrades", e = "⚡", l = "Upgrades" },
	{ id = "games", e = "🎮", l = "Jeux" },
	{ id = "pets", e = "🥚", l = "Pets" },
	{ id = "style", e = "🎨", l = "Style" },
	{ id = "quests", e = "📜", l = "Quêtes" },
	{ id = "rebirth", e = "🔄", l = "Rebirth" },
	{ id = "ach", e = "🏆", l = "Succès" },
	{ id = "shop", e = "💎", l = "Robux" },
}
local tabBtns = {}
local tabBuilders = {}

function UI.openTab(id)
	currentTab = id
	for tid, b in tabBtns do
		local on = tid == id
		b.BackgroundTransparency = on and 0 or 1
		b:FindFirstChildOfClass("UIStroke").Enabled = on
	end
	UI.rebuild(true)
end

function UI.rebuild(resetScroll)
	if not Store.state then return end
	local pos = body.CanvasPosition
	for _, c in body:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
	end
	rowUpdaters = {}
	tabBuilders[currentTab]()
	UI.refreshRows()
	if not resetScroll then body.CanvasPosition = pos end
end

function UI.refreshRows()
	for _, f in rowUpdaters do f() end
end

local function buildPanel()
	panel = new("Frame", {
		Name = "Panel", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, TOP), Size = UDim2.new(0.36, 0, 1, -(TOP + 12)),
		BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = gui,
	}, {
		K.corner(26), new("UISizeConstraint", { MinSize = Vector2.new(300, 0), MaxSize = Vector2.new(460, 10000) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#1a0d3d"), Color3.fromHex("#0e0724")), Transparency = NumberSequence.new(0.06) }),
	})
	refs.panelStroke = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3.5, Parent = panel })
	refs.panelGrad = new("UIGradient", { Color = rgbSeq(0), Parent = refs.panelStroke })

	-- onglets
	tabBar = new("Frame", { Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.82, Parent = panel }, {
		new("UIGridLayout", { CellSize = UDim2.new(1 / #TABS, -4, 0, 54), CellPadding = UDim2.fromOffset(4, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 4) }),
	})
	new("Frame", { Position = UDim2.new(0, 0, 0, 66), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.94, BorderSizePixel = 0, Parent = panel })
	for i, t in TABS do
		local b = new("TextButton", { LayoutOrder = i, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = tabBar }, {
			K.corner(12), new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.3, Thickness = 2, Enabled = false, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#b04dff"), Color3.fromHex("#5a1fb0")) }),
		})
		new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 26), Text = t.e, TextScaled = true, Font = K.BOLD, Parent = b })
		outlined(text(t.l, 11, { Position = UDim2.new(0, 0, 1, -17), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = t.id == "shop" and Cc.lime or Cc.ink, TextScaled = true, Parent = b }), 1)
		b.MouseButton1Click:Connect(function() UI.openTab(t.id) end)
		tabBtns[t.id] = b
	end

	body = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 1, -68), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, ScrollBarImageColor3 = Color3.fromHex("#4a3590"), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = panel,
	}, { K.list(8), new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 18) }) })
end

---------------------------------------------------------------------------- Shop (bâtiments)
tabBuilders.buildings = function()
	local s = Store.state
	local head = secTitle(0, "Bâtiments")
	local seg = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.65, Parent = head }, {
		K.corner(12), new("UIStroke", { Color = Cc.stroke, Thickness = 2 }), K.list(2, Enum.FillDirection.Horizontal), K.pad(2),
	})
	for i, q in { 1, 10, 100, "max" } do
		local on = buyQty == q
		local b = new("TextButton", { LayoutOrder = i, Text = q == "max" and "MAX" or "×" .. q, Font = K.DISPLAY, TextSize = 14, TextColor3 = on and Color3.new(1, 1, 1) or Cc.muted, Size = UDim2.fromOffset(46, 28), BackgroundColor3 = Cc.violet, BackgroundTransparency = on and 0 or 1, AutoButtonColor = false, Parent = seg }, { K.corner(9) })
		b.MouseButton1Click:Connect(function()
			buyQty = q
			UI.rebuild()
		end)
	end
	for i, d in D.buildings do
		local unlocked = E.buildingUnlocked(s, i)
		local r = rowFrame(i, 76)
		icon(unlocked and d.emoji or "🔒", 54, r, UDim2.fromOffset(9, 11))
		local nm = outlined(text(unlocked and d.name or "???", 17, { Position = UDim2.fromOffset(76, 10), Size = UDim2.new(1, -140, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, Parent = r }), 1.5)
		local meta = bodyText("", 12.5, { Position = UDim2.fromOffset(76, 31), Size = UDim2.new(1, -140, 0, 16), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = r })
		local cost = text("", 14, { Font = K.BOLD, Position = UDim2.fromOffset(76, 49), Size = UDim2.new(1, -140, 0, 18), TextColor3 = PINK, Parent = r })
		local own = outlined(text("0", 30, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(60, 34), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(235, 235, 235), Parent = r }), 2)
		if not unlocked then
			r.BackgroundTransparency = 0.975
			nm.TextColor3 = DIM
			meta.Text = "Continue à produire pour débloquer"
			cost.Text = "🍪 " .. fmt(d.cost)
			cost.TextColor3 = DIM
			own.Visible = false
			break
		end
		r.MouseButton1Click:Connect(function() act("buyBuilding", d.id, buyQty) end)
		table.insert(rowUpdaters, function()
			local st = Store.state
			local owned = st.buildings[d.id] or 0
			local n = buyQty == "max" and math.max(1, E.bMax(st, d.id)) or buyQty
			local c = E.bCost(d.id, n, owned)
			local per = D.BLD[d.id].cps * E.BLD_POWER * (Store.mult.bld[d.id] or 1)
			meta.Text = fmt(per) .. "/s chacun" .. (n > 1 and ("  ·  ×" .. n) or "")
			cost.Text = "🍪 " .. fmt(c)
			own.Text = tostring(owned)
			local can = st.cookies >= c
			cost.TextColor3 = can and Cc.lime or PINK
			setCan(r, can)
		end)
	end
	bodyText("Astuce : Espace = cliquer le cookie. Les combos rapides déclenchent la FIÈVRE RGB (tout ×3).", 12.5, { LayoutOrder = 100, Size = UDim2.new(1, 0, 0, 34), Parent = body })
end

---------------------------------------------------------------------------- Upgrades
tabBuilders.upgrades = function()
	local s = Store.state
	local owned, list = 0, {}
	for _, u in D.upgrades do
		if s.upgrades[u.id] then owned += 1 else table.insert(list, u) end
	end
	table.sort(list, function(a, b)
		local ra, rb = E.reqMet(s, a), E.reqMet(s, b)
		if ra ~= rb then return ra end
		return a.cost < b.cost
	end)
	secTitle(0, "Améliorations", owned .. " / " .. #D.upgrades .. " · chacune change le look du cookie")
	for i, u in list do
		local ok = E.reqMet(s, u)
		local r = rowFrame(i, 92)
		icon(ok and "✨" or "🔒", 50, r, UDim2.fromOffset(10, 10))
		outlined(text(u.name, 16.5, { Position = UDim2.fromOffset(72, 8), Size = UDim2.new(1, -80, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, Parent = r }), 1.5)
		bodyText(ok and E.fxText(u) or ("🔒 " .. E.reqText(u)), 12.5, { Position = UDim2.fromOffset(72, 30), Size = UDim2.new(1, -80, 0, 30), TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = ok and Color3.fromHex("#e0d6ff") or Cc.gold, Parent = r })
		local c = text("🍪 " .. fmt(u.cost), 14, { Font = K.BOLD, Position = UDim2.fromOffset(12, 64), Size = UDim2.new(0.5, 0, 0, 20), TextColor3 = PINK, Parent = r })
		if ok then
			local b = btn("Acheter", "green", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(96, 30), TextSize = 14, Parent = r }, function() act("buyUpgrade", u.id) end)
			table.insert(rowUpdaters, function()
				local can = Store.state.cookies >= u.cost
				c.TextColor3 = can and Cc.lime or PINK
				setBtnKind(b, can and "green" or "dark")
				setCan(r, can)
			end)
		else
			r.BackgroundTransparency = 0.975
		end
	end
	if #list == 0 then bodyText("FULL DRIP : toutes les améliorations sont achetées 🔥", 15, { LayoutOrder = 1, TextColor3 = Cc.lime, Parent = body }) end
end

---------------------------------------------------------------------------- Jeux
local GAME_COLORS = { ninja = "#ff2bd6", flappy = "#ffc93c", rhythm = "#1ff4ff", slots = "#b6ff3b" }
tabBuilders.games = function()
	local s = Store.state
	secTitle(0, "Mini-jeux", "Gagne des cookies et des gemmes")
	local grid = new("Frame", { LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = body }, {
		new("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 176), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, m in D.minigames do
		local ok = E.minigameUnlocked(s, m.id)
		local rec = s.mg[m.id]
		local card = new("TextButton", { LayoutOrder = i, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = grid }, {
			K.corner(20), new("UIStroke", { Color = Cc.stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			new("UIGradient", { Rotation = 60, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex(GAME_COLORS[m.id])), ColorSequenceKeypoint.new(0.62, Color3.fromHex("#1d0f45")), ColorSequenceKeypoint.new(1, Color3.fromHex("#1d0f45")) }) }),
		})
		new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -8), Size = UDim2.fromOffset(70, 70), Rotation = 14, Text = m.emoji, TextScaled = true, Font = K.BOLD, Parent = card })
		outlined(text(m.name, 20, { Position = UDim2.fromOffset(12, 26), Size = UDim2.new(0.75, 0, 0, 48), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = card }), 2)
		bodyText(ok and "Record : " .. fmt(rec and rec.best or 0) or ("🔒 " .. m.text), 12, { Position = UDim2.new(0, 12, 1, -64), Size = UDim2.new(1, -24, 0, 16), TextColor3 = Cc.gold, Parent = card })
		btn(ok and "JOUER" or "🔒", ok and "pink" or "dark", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -24, 0, 36), Parent = card }, function()
			if ok then Minigames.open(m.id) end
		end)
		if not ok then card.BackgroundTransparency = 0.4 end
	end
end

---------------------------------------------------------------------------- Pets
local function hatchAnim(res)
	local def = D.PET[res.id]
	local rar = D.rarities[res.rarity]
	UI.modal((res.isNew and "NOUVEAU PET !" or "PET AMÉLIORÉ !"),
		def.emoji .. "  " .. def.name .. "\n" .. rar.name .. " · niveau " .. res.lvl .. (res.lucky and "\n🍀 Œuf Chanceux activé !" or "") .. "\n" .. E.petPower({ id = res.id, lvl = res.lvl }),
		{ { "Trop bien !", "green" } }, Color3.fromHex(rar.color))
end

tabBuilders.pets = function()
	local s = Store.state
	secTitle(0, "Œufs", "payés en gemmes 💎")
	for i, egg in D.eggs do
		local odds = {}
		for _, o in egg.odds do table.insert(odds, D.rarities[o[1]].name .. " " .. o[2] .. " %") end
		local r = rowFrame(i, 82)
		icon("🥚", 54, r, UDim2.fromOffset(9, 14))
		outlined(text(egg.name, 17, { Position = UDim2.fromOffset(76, 8), Size = UDim2.new(1, -190, 0, 20), Parent = r }), 1.5)
		bodyText(table.concat(odds, " · "), 12, { Position = UDim2.fromOffset(76, 30), Size = UDim2.new(1, -190, 0, 44), TextYAlignment = Enum.TextYAlignment.Top, Parent = r })
		local b = btn("💎 " .. egg.cost, "green", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(100, 40), Parent = r }, function()
			local res = act("hatch", egg.id)
			if res and res.ok then hatchAnim(res) elseif res and res.err then UI.toast(res.err, "#ff4d6d") end
		end)
		table.insert(rowUpdaters, function() setBtnKind(b, Store.state.gems >= egg.cost and "green" or "dark") end)
	end
	if not Store.passes.LuckyEggs then
		btn("🍀 Œufs Chanceux : meilleurs pets !", "gold", { LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 40), TextSize = 15, Parent = body }, function() act("buyPass", "LuckyEggs") end)
	end
	local slots = Store.mult.petSlots or 3
	subTitle(20, "🐾 Tes pets  (" .. #s.equipped .. "/" .. slots .. " équipés)")
	if slots < 5 then
		btn("👑 VIP : +2 emplacements", "gold", { LayoutOrder = 21, Size = UDim2.new(1, 0, 0, 38), TextSize = 15, Parent = body }, function() act("buyPass", "VIP") end)
	end
	local pets = table.clone(s.pets)
	table.sort(pets, function(a, b) return D.rarities[D.PET[a.id].rarity].rank > D.rarities[D.PET[b.id].rarity].rank end)
	for i, p in pets do
		local def = D.PET[p.id]
		local rar = D.rarities[def.rarity]
		local eq = table.find(s.equipped, p.uid) ~= nil
		local r = rowFrame(30 + i, 70)
		icon(def.emoji, 50, r, UDim2.fromOffset(9, 10))
		outlined(text(def.name .. "  <font size=\"13\">Nv." .. p.lvl .. "</font>", 16, { Position = UDim2.fromOffset(70, 8), Size = UDim2.new(1, -180, 0, 20), TextColor3 = Color3.fromHex(rar.color), Parent = r }), 1.5)
		bodyText(rar.name .. " · " .. E.petPower(p), 12, { Position = UDim2.fromOffset(70, 30), Size = UDim2.new(1, -180, 0, 32), TextYAlignment = Enum.TextYAlignment.Top, Parent = r })
		btn(eq and "Retirer" or "Équiper", eq and "red" or "cyan", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(96, 36), TextSize = 14, Parent = r }, function()
			local res = act("equip", p.uid)
			if type(res) == "table" and res.err then UI.toast(res.err, "#ff4d6d") end
		end)
		if eq then setCan(r, true) end
	end
	if #pets == 0 then
		local e = bodyText("Aucun pet pour l'instant. Fais éclore un œuf !", 14, { LayoutOrder = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 56), Parent = body })
		new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.88, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = e })
		new("UICorner", { CornerRadius = UDim.new(0, 16), Parent = e })
	end
end

---------------------------------------------------------------------------- Style
tabBuilders.style = function()
	local s = Store.state
	secTitle(0, "Skins", "le look de ton cookie")
	local grid = new("Frame", { LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = body }, {
		new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, 132), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, sk in D.skins do
		local owned = s.skinsOwned[sk.id]
		local on = s.skin == sk.id
		local card = new("TextButton", { LayoutOrder = i, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = on and 0.85 or 0.955, Parent = grid }, {
			K.corner(16), new("UIStroke", { Color = on and Cc.lime or Color3.new(1, 1, 1), Transparency = on and 0 or 0.93, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		-- mini cookie
		local disc = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card }, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Color3.fromHex(sk.rim), Thickness = 3 }),
			new("UIGradient", { Rotation = 55, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex(sk.light)), ColorSequenceKeypoint.new(0.5, Color3.fromHex(sk.base)), ColorSequenceKeypoint.new(1, Color3.fromHex(sk.dark)) }) }),
		})
		for _, c in { { 0.3, 0.35 }, { 0.65, 0.3 }, { 0.45, 0.62 }, { 0.72, 0.68 } } do
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromScale(0.18, 0.18), BackgroundColor3 = Color3.fromHex(sk.chip), Parent = disc }, { K.corner(4) })
		end
		outlined(text(sk.name, 13, { Position = UDim2.fromOffset(4, 72), Size = UDim2.new(1, -8, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card }), 1)
		local label, kind
		if on then label, kind = "Équipé ✓", "dark"
		elseif owned then label, kind = "Équiper", "cyan"
		elseif sk.unlock and sk.unlock.pass then label, kind = "Robux", "green"
		elseif sk.unlock then label, kind = "🔒", "dark"
		else label, kind = "💎 " .. sk.cost, "violet" end
		btn(label, kind, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -14, 0, 30), TextSize = 13, Parent = card }, function()
			if on then return end
			if not owned and sk.unlock and sk.unlock.pass then act("buyPass", sk.unlock.pass)
			elseif not owned and sk.unlock then UI.toast("🔒 " .. sk.unlock.text, "#ffc93c")
			else act("skin", sk.id) end
		end)
	end
	subTitle(50, "🌆 Thèmes")
	for i, th in D.themes do
		local owned = s.themesOwned[th.id]
		local on = s.theme == th.id
		local r = rowFrame(50 + i, 62)
		new("Frame", { Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = Color3.new(1, 1, 1), Parent = r }, {
			K.corner(12), new("UIStroke", { Color = Cc.stroke, Thickness = 3 }),
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex(th.ambient), Color3.fromHex(th.floor)) }),
		})
		outlined(text(th.name, 17, { Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -180, 1, 0), Parent = r }), 1.5)
		btn(on and "Actif ✓" or owned and "Activer" or ("💎 " .. th.cost), on and "dark" or owned and "cyan" or "violet", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(96, 36), TextSize = 14, Parent = r }, function()
			if not on then act("theme", th.id) end
		end)
		if on then setCan(r, true) end
	end
end

---------------------------------------------------------------------------- Quêtes
tabBuilders.quests = function()
	local s = Store.state
	secTitle(0, "Quêtes", "3 quêtes à la fois · récompense en 💎")
	for i, q in s.quests do
		local def
		for _, d in D.quests do if d.type == q.type then def = d end end
		if def then
			local r = rowFrame(i, 100)
			icon("📜", 46, r, UDim2.fromOffset(10, 10))
			outlined(text((string.gsub(def.text, "{n}", def.fmt and fmt(q.target) or tostring(q.target))), 16, { Position = UDim2.fromOffset(66, 10), Size = UDim2.new(1, -76, 0, 20), TextWrapped = true, Parent = r }), 1.5)
			local bg = new("Frame", { Position = UDim2.fromOffset(66, 38), Size = UDim2.new(1, -78, 0, 12), BackgroundColor3 = Color3.fromHex("#0a051e"), Parent = r }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Cc.stroke, Thickness = 2 }) })
			local fill = new("Frame", { Size = UDim2.fromScale(math.clamp(q.progress / q.target, 0, 1), 1), BackgroundColor3 = q.done and Cc.lime or Cc.cyan, Parent = bg }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			local _ = fill
			bodyText(fmt(q.progress) .. " / " .. fmt(q.target) .. "   ·   💎 " .. q.gems, 12.5, { Position = UDim2.fromOffset(66, 56), Size = UDim2.new(1, -190, 0, 16), Parent = r })
			if q.done then
				setCan(r, true)
				btn("Réclamer 💎", "gold", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(116, 32), TextSize = 14, Parent = r }, function()
					local g = act("claimQuest", q.id)
					if g then UI.toast("+" .. g .. " gemmes 💎", "#b6ff3b") end
				end)
			else
				btn("Changer 💎3", "dark", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(116, 32), TextSize = 13, Parent = r }, function() act("rerollQuest", q.id) end)
			end
		end
	end
end

---------------------------------------------------------------------------- Rebirth
tabBuilders.rebirth = function()
	local s = Store.state
	local gain = E.rebirthGain(s)
	secTitle(0, "Rebirth", s.rebirths .. " rebirth(s)")
	local r = rowFrame(1, 0)
	r.AutomaticSize = Enum.AutomaticSize.Y
	new("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = r })
	K.pad(16).Parent = r
	outlined(text("⭐ " .. s.stars .. " étoiles", 34, { LayoutOrder = 1, TextColor3 = Cc.gold, TextXAlignment = Enum.TextXAlignment.Center, Parent = r }), 3)
	bodyText("Chaque étoile = +10 % de production et de clics, pour toujours. Tu repars de zéro (cookies, bâtiments, améliorations) mais tu gardes gemmes, pets, skins et succès.", 14, { LayoutOrder = 2, TextColor3 = Cc.ink, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = r })
	outlined(text(gain >= 1 and ("Maintenant : +" .. gain .. " ⭐  et  +" .. gain * 10 .. " 💎") or ("Encore un peu : il faut " .. fmt(E.REBIRTH_MIN) .. " cookies produits."), 17, { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = r }), 1.5)
	btn("🔄 REBIRTH", gain >= 1 and "gold" or "dark", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 54), TextSize = 26, Parent = r }, function()
		if gain < 1 then return end
		UI.modal("Rebirth ?", "Tu repars de zéro avec +" .. gain .. " ⭐ (+" .. gain * 10 .. " % de production). Sûr ?", {
			{ "Annuler", "red" },
			{ "GO !", "gold", function()
				local g = act("rebirth")
				if g then UI.modal("⭐ RENAISSANCE ⭐", "+" .. g .. " étoiles ! Ton cookie est plus fort que jamais.", nil, Cc.gold) end
			end },
		}, Cc.gold)
	end)
end

---------------------------------------------------------------------------- Succès (+ classement mondial)
tabBuilders.ach = function()
	local s = Store.state
	local n = 0
	for _ in s.achievements do n += 1 end
	local lb = RS:FindFirstChild("Leaderboard")
	local ok, rows = pcall(function() return HttpService:JSONDecode(lb and lb.Value or "[]") end)
	if ok and #rows > 0 then
		secTitle(0, "Top mondial", "cookies produits au total")
		for i, row in rows do
			local r = rowFrame(i, 40)
			outlined(text(string.format("#%d   %s", row.rank, row.name), 16, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -140, 1, 0), TextColor3 = row.rank == 1 and Cc.gold or Cc.ink, Parent = r }), 1.5)
			text("🍪 " .. fmt(row.value), 14, { Font = K.BOLD, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.new(0, 120, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Cc.lime, Parent = r })
		end
	end
	secTitle(20, "Succès", n .. " / " .. #D.achievements .. " · +1 % de prod chacun")
	for i, a in D.achievements do
		local got = s.achievements[a.id] ~= nil
		local r = rowFrame(20 + i, 62)
		icon(got and "🏆" or "🔒", 44, r, UDim2.fromOffset(9, 9))
		outlined(text(a.name, 16, { Position = UDim2.fromOffset(64, 8), Size = UDim2.new(1, -120, 0, 20), TextColor3 = got and Cc.gold or Cc.ink, Parent = r }), 1.5)
		bodyText(a.desc, 12, { Position = UDim2.fromOffset(64, 30), Size = UDim2.new(1, -120, 0, 28), TextYAlignment = Enum.TextYAlignment.Top, Parent = r })
		text("💎 " .. a.gems, 14, { Font = K.BOLD, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(60, 20), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = got and Cc.lime or DIM, Parent = r })
		if not got then r.BackgroundTransparency = 0.975 end
	end
end

---------------------------------------------------------------------------- Boutique Robux
tabBuilders.shop = function()
	local passes = Store.passes
	secTitle(0, "Boutique", "achats en Robux")
	subTitle(1, "💎 Game Passes (à vie)")
	for i, p in Shop.passes do
		local owned = passes[p.key]
		local r = rowFrame(1 + i, 84)
		icon(p.emoji, 54, r, UDim2.fromOffset(9, 15))
		outlined(text(p.name, 17, { Position = UDim2.fromOffset(76, 8), Size = UDim2.new(1, -190, 0, 20), Parent = r }), 1.5)
		bodyText(p.desc, 12, { Position = UDim2.fromOffset(76, 30), Size = UDim2.new(1, -190, 0, 48), TextYAlignment = Enum.TextYAlignment.Top, Parent = r })
		btn(owned and "Possédé ✓" or (p.id == 0 and "Bientôt" or ("R$ " .. p.price)), owned and "dark" or "green", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(100, 40), Parent = r }, function()
			if not owned and not act("buyPass", p.key) then UI.toast("Bientôt disponible !", "#ffc93c") end
		end)
		setCan(r, owned == true)
	end
	subTitle(50, "🛒 Packs & Boosts")
	for i, p in Shop.products do
		local desc = p.desc or ""
		if p.kind == "gems" then desc = "Pour les œufs, skins et thèmes." .. (p.tag and ("  🔥 " .. p.tag) or "")
		elseif p.kind == "boost" then desc = "Toute ta production ×" .. p.mult .. " pendant " .. math.floor(p.dur / 60) .. " min (cumulable)."
		elseif p.kind == "fever" then desc = "Déclenche la Fièvre RGB (×3) tout de suite !" end
		local r = rowFrame(50 + i, 72)
		icon(p.emoji, 50, r, UDim2.fromOffset(9, 11))
		outlined(text(p.name, 17, { Position = UDim2.fromOffset(72, 10), Size = UDim2.new(1, -186, 0, 20), Parent = r }), 1.5)
		bodyText(desc, 12, { Position = UDim2.fromOffset(72, 32), Size = UDim2.new(1, -186, 0, 32), TextYAlignment = Enum.TextYAlignment.Top, Parent = r })
		btn(p.id == 0 and "Bientôt" or ("R$ " .. p.price), "green", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(100, 40), Parent = r }, function()
			if not act("buyProduct", p.key) then UI.toast("Bientôt disponible !", "#ffc93c") end
		end)
	end
	bodyText("Les achats passent par la fenêtre officielle Roblox. Les probabilités des œufs sont affichées dans l'onglet Pets.", 12, { LayoutOrder = 200, Size = UDim2.new(1, 0, 0, 34), Parent = body })
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
				BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false, Parent = goldenLayer,
			}, {
				new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Color3.fromHex("#fff2a8"), Thickness = 4 }),
				new("UIGradient", { Rotation = 55, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("#fff2a8")), ColorSequenceKeypoint.new(0.5, Color3.fromHex("#ffcc33")), ColorSequenceKeypoint.new(1, Color3.fromHex("#c98a00")) }) }),
			})
			for _, c in { { 0.32, 0.35 }, { 0.65, 0.3 }, { 0.45, 0.65 }, { 0.72, 0.62 } } do
				new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromScale(0.16, 0.16), BackgroundColor3 = Color3.fromHex("#b36b00"), Parent = b }, { K.corner(5) })
			end
			b.MouseButton1Click:Connect(function()
				local res = act("golden", g.id)
				local p = b.AbsolutePosition + b.AbsoluteSize / 2
				b:Destroy()
				goldenButtons[g.id] = nil
				if res then
					UI.floatText(res.label, p, Color3.fromHex(res.color), 34)
					UI.toast("✨ " .. res.label, res.color)
				end
			end)
			TweenService:Create(b, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.fromOffset(90, 90), Rotation = 14 }):Play()
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
	refs.count.Text = fmt(live.cookies) .. '<font size="26" color="#ffe2b0"> cookies</font>'
	refs.cps.Text = '⚡ <font color="' .. (live.boost > 0 and "#ff2bd6" or "#b6ff3b") .. '">' .. fmt(live.cps) .. "</font> / seconde"
	refs.gems.Text = "💎  " .. fmt(live.gems)
	local c = live.combo
	refs.comboBox.Visible = c.n > 0 or live.fever > 0
	refs.comboL.Text = live.fever > 0 and "FIÈVRE RGB !" or ("COMBO " .. c.n)
	refs.comboM.Text = "×" .. (live.fever > 0 and "3" or tostring(c.mult))
	refs.comboFill.Size = UDim2.fromScale(live.fever > 0 and 1 or c.heat, 1)
	refs.feverBox.Visible = live.fever > 0
	-- buffs
	for _, ch in refs.buffs:GetChildren() do
		if ch:IsA("Frame") then ch:Destroy() end
	end
	local function buffChip(t)
		local f = new("Frame", { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromHex("#0a051e"), BackgroundTransparency = 0.2, Parent = refs.buffs }, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Cc.stroke, Thickness = 2 }), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		})
		outlined(text(t, 14, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = f }), 1.5)
	end
	for _, b in live.buffs do buffChip(b.emoji .. " " .. b.name .. '  <font color="#b3a6dd">' .. math.ceil(b.left) .. "s</font>") end
	if live.boost > 0 then buffChip("⚡ Boost ×" .. live.boostMult .. '  <font color="#b3a6dd">' .. K.fmtTime(live.boost) .. "</font>") end
	-- boss
	if live.boss then
		refs.bossBox.Visible = true
		refs.bossText.Text = live.boss.emoji .. " " .. live.boss.name .. '  <font size="16" color="#ff8a9c">' .. math.ceil(live.boss.left) .. "s — CLIQUE !</font>"
		refs.bossHp.Size = UDim2.fromScale(live.boss.hp / live.boss.maxHp, 1)
	else
		refs.bossBox.Visible = false
	end
	-- cadeau
	refs.giftTag.Text = live.giftIn > 0 and K.fmtTime(live.giftIn) or "PRÊT"
	refs.giftTag.TextColor3 = live.giftIn > 0 and Cc.muted or Cc.lime
	refreshGolden(live.golden)
	UI.refreshRows()
end

function UI.onFull()
	local s = Store.state
	refs.stars.Text = "⭐  " .. s.stars
	refs.auto.Visible = Store.passes.AutoClicker == true
	refs.auto.Text = s.autoClick and "🤖" or "💤"
	refs.hint.Visible = s.clicks < 25
	UI.rebuild(false)
end

-- largeur occupée à droite par le panneau (pour centrer le cookie dans la zone de jeu)
function UI.rightInset()
	return panel and (panel.AbsoluteSize.X + 24) or 0
end

-- position écran du cookie (pour la touche Espace)
function UI.playCenter()
	return play.AbsolutePosition + Vector2.new(play.AbsoluteSize.X / 2, play.AbsoluteSize.Y * 0.5)
end

---------------------------------------------------------------------------- init
function UI.init(store, actFn, tapFn, minigames)
	Store, act, onCookieTap, Minigames = store, actFn, tapFn, minigames
	gui = new("ScreenGui", { Name = "CookieUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	buildPlay()
	buildPanel()
	buildTopBar()
	fxLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20, Parent = gui })
	modalLayer = new("Frame", { Visible = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 50, Active = true, Parent = gui })
	UI.gui = gui
	-- la zone de jeu s'arrête au panneau
	local function relayout()
		local w = UI.rightInset()
		play.Size = UDim2.new(1, -w, 1, -(TOP + 40))
	end
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	relayout()
	UI.openTab("buildings")
	-- bords RGB animés
	RunService.RenderStepped:Connect(function()
		hue = (os.clock() * 0.08) % 1
		refs.panelGrad.Rotation = (os.clock() * 40) % 360
		refs.comboGrad.Offset = Vector2.new(math.sin(os.clock() * 2) * 0.2, 0)
		for _, b in tabBtns do
			if b.BackgroundTransparency == 0 then b:FindFirstChildOfClass("UIStroke").Color = Color3.fromHSV(hue, 0.6, 1) end
		end
		for _, r in body:GetChildren() do
			if r:GetAttribute("can") then r:FindFirstChildOfClass("UIStroke").Color = Color3.fromHSV(hue, 0.7, 1) end
		end
		if refs.feverBox.Visible then refs.feverText.TextColor3 = Color3.fromHSV((os.clock() * 0.6) % 1, 0.8, 1) end
		-- sous le cookie (le cookie occupe ~43 %→75 % de la hauteur d'écran)
		refs.hint.Position = UDim2.new(0.5, 0, 0, gui.AbsoluteSize.Y * 0.765 - play.AbsolutePosition.Y + math.sin(os.clock() * 6) * 6)
		refs.shopBtn.Rotation = math.sin(os.clock() * 4) * 8
	end)
end

return UI
