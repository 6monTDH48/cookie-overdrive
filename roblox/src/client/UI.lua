-- COOKIE OVERDRIVE — interface (portage de index.html + ui.js) : barre du haut (logo, gemmes, étoiles,
-- cadeau, boutique Robux), HUD de la zone de jeu (boulangerie, compteur, CPS, combo, buffs, indice,
-- bannières, ticker), panneau à bord RGB avec 8 onglets (contenu : Panel.lua), toasts, popup de succès,
-- fenêtres modales, éclosion d'œuf, flash de rebirth. Trois mises en page : PC, mobile paysage
-- (panneau latéral compact) et mobile portrait (feuille du bas, comme le site < 900 px).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = RS:WaitForChild("Shared")
local D = require(Shared:WaitForChild("GameData"))
local E = require(Shared:WaitForChild("Econ"))
local K = require(script.Parent:WaitForChild("Kit"))
local Panel = require(script.Parent:WaitForChild("Panel"))
local Stage = require(script.Parent:WaitForChild("Stage"))
local new, C, F = K.new, K.C, K.F
local clamp = K.clamp

local UI = {}
local player = Players.LocalPlayer
local Store: any = nil
local act: (string, ...any) -> any = function() return nil end
local Minigames: any = nil

UI.tab = "shop"
UI.prevTab = "shop"
UI.mobile = false
UI.mode = "desktop"
UI.renderedOnce = false

-- ZIndex des couches (le stage est à 1, l'overlay des mini-jeux dans sa propre ScreenGui)
local ZL = { hud = 10, panel = 12, top = 14, toasts = 60, ach = 61, modal = 80, hatch = 90, flash = 99 }

local gui: ScreenGui
local L: any = {} -- références d'interface
local hud: any = { disp = 0, lastStr = "", lastCps = "", lastGems = -1, lastStars = -1, buffKey = "?", bannerKey = "?", gt = "", gready = nil }
local geo: any = { W = 1280, H = 720, TOP = 64, pw = 420, play = { left = 0, top = 64, width = 800, height = 656 } }
local expanded = false
local blockers = 0 -- modales / éclosion ouvertes (Espace désactivé)

---------------------------------------------------------------------------- utilitaires
local function tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function frame(props: { [string]: any }?): Frame
	local f = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0 })
	for k, v in (props or {}) :: { [string]: any } do if k ~= "Parent" then (f :: any)[k] = v end end
	if props and props.Parent then f.Parent = props.Parent end
	return f
end
-- texte .ol du site : contour 2 px + ombre portée 0 4px 0 (dy = 6 : .ol-lg, contour 3 px)
-- = étiquette principale + copie sombre décalée dessous
local function olShadow(parent: Instance, text: string, size: number, color: Color3, dy: number, props: { [string]: any }?): (Frame, TextLabel, TextLabel)
	local box = frame({ Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, Parent = parent })
	for k, v in (props or {}) :: { [string]: any } do (box :: any)[k] = v end
	local th = dy >= 6 and 3 or 2
	local sh = K.txt(text, size, F.display, C.stroke, { Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, Position = UDim2.fromOffset(0, dy), RichText = true, ZIndex = 1, Parent = box })
	K.ol(sh, th, C.stroke)
	local l = K.txt(text, size, F.display, color, { Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, RichText = true, ZIndex = 2, Parent = box })
	K.ol(l, th, C.stroke)
	return box, l, sh
end
-- ombre portée « 0 dy 0 var(--stroke) » d'une boîte dont la bordure (UIStroke, dessinée à l'extérieur) fait `th` px
local function dropShadow(parent: Instance, th: number, dy: number, radius: number, z: number?): Frame
	local d = frame({
		Name = "Drop", BackgroundTransparency = 0, BackgroundColor3 = C.stroke, Position = UDim2.fromOffset(-th, dy - th),
		Size = UDim2.new(1, 2 * th, 1, 2 * th), ZIndex = z or 0, Parent = parent,
	})
	K.round(d, radius + th)
	return d
end
-- dégradé d'un bouton .iconbtn : reflet clair en haut, bande sombre en bas (inset box-shadows du site)
local function iconSeq(top: string, bottom: string, dark: string?): ColorSequence
	local c1, c2 = Color3.fromHex(top), Color3.fromHex(bottom)
	local c3 = dark and Color3.fromHex(dark) or c2
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, c1:Lerp(Color3.new(1, 1, 1), 0.25)), ColorSequenceKeypoint.new(0.07, c1),
		ColorSequenceKeypoint.new(0.86, c2), ColorSequenceKeypoint.new(0.9, c3), ColorSequenceKeypoint.new(1, c3),
	})
end
-- fondu de sortie d'un arbre d'objets (opacity → 0 du site)
local function fadeTree(root: Instance, dur: number)
	for _, o in root:GetDescendants() do
		if o:IsA("TextLabel") or o:IsA("TextButton") then
			tween(o, dur, { TextTransparency = 1, BackgroundTransparency = 1 })
		elseif o:IsA("ImageLabel") then
			tween(o, dur, { ImageTransparency = 1, BackgroundTransparency = 1 })
		elseif o:IsA("Frame") then
			tween(o, dur, { BackgroundTransparency = 1 })
		elseif o:IsA("UIStroke") then
			tween(o, dur, { Transparency = 1 })
		end
	end
end

-- emojis des messages serveur → icône du site (le site n'affiche aucun emoji)
local EMO_ICON = {
	["💎"] = "ui:gem", ["🍪"] = "ui:cookie", ["🎁"] = "ui:gift", ["⚠"] = "ui:warning", ["🏆"] = "ui:trophy", ["⚡"] = "ui:bolt",
	["🌈"] = "ui:rainbow", ["🔥"] = "ui:fire", ["⭐"] = "ui:star", ["👑"] = "ui:crown", ["🎮"] = "tab:games", ["🥚"] = "tab:pets",
	["🌪"] = "ui:tornado", ["🎨"] = "tab:style", ["🍀"] = "egg:neon", ["🧲"] = "ui:golden", ["🤖"] = "ui:cursor", ["✖"] = "ui:cookie",
}
local function isEmoji(cp: number): boolean
	return cp >= 0x1F000 or (cp >= 0x2600 and cp <= 0x27BF) or cp == 0xFE0F or cp == 0x200D or cp == 0x2B50 or cp == 0x2B06 or cp == 0x2934 or (cp >= 0x2190 and cp <= 0x21FF and cp ~= 0x2192)
end
function UI.stripEmoji(text: string): (string, string?)
	local out, icon = {}, nil
	local ok = pcall(function()
		for _, cp in utf8.codes(text) do
			if isEmoji(cp) then
				if not icon then icon = EMO_ICON[utf8.char(cp)] end
			else
				table.insert(out, utf8.char(cp))
			end
		end
	end)
	if not ok then return text, nil end
	local s = table.concat(out)
	s = string.gsub(s, "%s+", " ")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	s = string.gsub(s, "%s+([!%.,…])", "%1")
	return s, icon
end

---------------------------------------------------------------------------- mise en page
local function computeLayout()
	local abs = gui.AbsoluteSize
	local Wd, Hd = math.max(320, abs.X), math.max(240, abs.Y)
	local mode = (Wd >= 900 and Hd >= 520) and "desktop" or (Wd > Hd and "compact" or "portrait")
	local TOP = mode == "desktop" and 64 or (mode == "compact" and 50 or 54)
	local g: any = { W = Wd, H = Hd, TOP = TOP, mode = mode }
	if mode == "desktop" then
		g.pw = clamp(Wd * 0.33, 360, 470)
		g.panel = { x = Wd - 12 - g.pw, y = TOP + 2, w = g.pw, h = Hd - TOP - 14 }
		g.play = { left = 0, top = TOP, width = Wd - (g.pw + 22), height = Hd - TOP }
	elseif mode == "compact" then
		g.pw = clamp(Wd * 0.42, 300, 440)
		g.panel = { x = Wd - 8 - g.pw, y = TOP + 2, w = g.pw, h = Hd - TOP - 10 }
		g.play = { left = 0, top = TOP, width = Wd - (g.pw + 16), height = Hd - TOP }
	else
		local sheet = math.floor(Hd * (expanded and 0.76 or 0.47))
		g.pw = Wd - 16
		g.panel = { x = 8, y = Hd - 8 - sheet, w = Wd - 16, h = sheet }
		g.play = { left = 0, top = TOP, width = Wd, height = math.max(120, Hd - TOP - (sheet + 12)) }
	end
	return g
end

---------------------------------------------------------------------------- barre du haut
-- .pill : fond sombre, bordure 3 px, ombre 0 3px 0. Structure : holder (place dans la rangée) →
-- face (centrée, porte le UIScale du « bump » pour grossir depuis le centre) → ombre, fond, contenu
local function pill(parent: Instance, key: string, order: number): any
	local holder = frame({ Size = UDim2.fromOffset(60, 41), LayoutOrder = order, Parent = parent })
	local face = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X, Parent = holder })
	local drop = dropShadow(face, 3, 3, 999, 1)
	local bg = frame({ BackgroundTransparency = 0.15, BackgroundColor3 = Color3.fromRGB(20, 10, 48), Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = face })
	K.round(bg)
	K.border(bg, C.stroke, 3)
	local content = frame({ Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3, Parent = face })
	local pad = K.padding(content, 0, 12, 0, 6)
	K.hlist(content, 6)
	local icon = K.img(key, { Name = "Icon", Size = UDim2.fromOffset(30, 30), LayoutOrder = 1, ZIndex = 3, Parent = content })
	local l = K.txt("0", 18, F.display, C.ink, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, ZIndex = 3, Parent = content })
	local sc = new("UIScale", { Parent = face })
	local r = { holder = holder, face = face, icon = icon, label = l, pad = pad, drop = drop, sc = sc, h = 38 }
	-- la rangée suit la largeur réelle de la pastille (mesurée à l'échelle 1)
	local function sync()
		if sc.Scale ~= 1 then return end
		local w = face.AbsoluteSize.X
		holder.Size = UDim2.fromOffset(w, r.h + 3)
		face.Position = UDim2.fromOffset(w / 2, r.h / 2)
	end
	r.sync = sync
	face:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
	return r
end
local function sizePill(r: any, h: number, mobile: boolean)
	r.h = h
	r.face.Size = UDim2.fromOffset(0, h)
	r.icon.Size = UDim2.fromOffset(mobile and 22 or 30, mobile and 22 or 30)
	r.pad.PaddingRight, r.pad.PaddingLeft = UDim.new(0, mobile and 9 or 12), UDim.new(0, mobile and 4 or 6)
	r.label.TextSize = mobile and 15 or 18
	r.sync()
end
-- .iconbtn : 42 px, coins 14, dégradé violet, ombre 0 3px 0, s'enfonce de 2 px à l'appui.
-- face centrée (rotation / échelle du « giftWiggle » autour du centre) → ombre + bouton
local function iconBtn(parent: Instance, key: string?, order: number, text: string?): any
	local holder = frame({ Size = UDim2.fromOffset(42, 45), LayoutOrder = order, Parent = parent })
	local face = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(21, 21), Size = UDim2.fromOffset(42, 42), Parent = holder })
	local drop = dropShadow(face, 3, 3, 14, 1)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.white, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = face })
	local corner = new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = b })
	K.border(b, C.stroke, 3)
	local g = new("UIGradient", { Rotation = 90, Color = iconSeq("#3a2a70", "#251652", "#170d38"), Parent = b })
	if key then K.img(key, { Name = "Icon", Size = UDim2.fromOffset(25, 25), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3, Parent = b }) end
	if text then
		local l = K.txt(text, 17, F.display, C.white, { Name = "Label", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = b })
		K.ol(l, 2)
	end
	b.MouseButton1Down:Connect(function() b.Position = UDim2.fromOffset(0, 2) end)
	b.MouseButton1Up:Connect(function() b.Position = UDim2.new() end)
	b.MouseLeave:Connect(function() b.Position = UDim2.new() end)
	local sc = new("UIScale", { Parent = face })
	return { holder = holder, face = face, btn = b, grad = g, drop = drop, corner = corner, sc = sc }
end
local function sizeIconBtn(r: any, sz: number, radius: number)
	r.holder.Size = UDim2.fromOffset(sz, sz + 3)
	r.face.Size = UDim2.fromOffset(sz, sz)
	r.face.Position = UDim2.fromOffset(sz / 2, sz / 2)
	r.corner.CornerRadius = UDim.new(0, radius)
	local dc = r.drop:FindFirstChildOfClass("UICorner")
	if dc then dc.CornerRadius = UDim.new(0, radius + 3) end
end

local function buildTopbar()
	local top = frame({ Name = "Topbar", BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(8, 4, 24), ZIndex = ZL.top, Parent = gui })
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(0.7, 0.45), NumberSequenceKeypoint.new(1, 1) }), Parent = top })
	L.top = top
	-- logo : cookie doré qui tourne + COOKIE / OVERDRIVE
	local logo = new("TextButton", { Name = "Logo", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, Parent = top })
	K.hlist(logo, 6, nil, Enum.VerticalAlignment.Center)
	L.logoMark = K.img("ui:golden", { Size = UDim2.fromOffset(36, 36), LayoutOrder = 1, Parent = logo })
	local boxA, la, sa = olShadow(logo, "COOKIE", 27, C.white, 4, { Rotation = -3, LayoutOrder = 2 })
	local boxB, lb, sb = olShadow(logo, "OVERDRIVE", 27, C.white, 4, { Rotation = 2, LayoutOrder = 3 })
	K.accBind(lb, "TextColor3")
	L.logo, L.logoA, L.logoB, L.logoSA, L.logoSB, L.logoBoxB = logo, la, lb, sa, sb, boxB
	local _ = boxA
	L.logoSc = new("UIScale", { Parent = logo })
	logo.Activated:Connect(function()
		L.logoSc.Scale = 0.94
		tween(L.logoSc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		logo.Rotation = -8
		tween(logo, 0.3, { Rotation = 0 }, Enum.EasingStyle.Back)
	end)
	-- pastilles à droite
	local pills = frame({ Name = "Pills", AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, Parent = top })
	K.hlist(pills, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	L.pills = pills
	L.gemPill = pill(pills, "ui:gem", 1)
	L.starPill = pill(pills, "ui:star", 2)
	L.gems, L.gemSc, L.stars = L.gemPill.label, L.gemPill.sc, L.starPill.label
	-- cadeau (toutes les 8 min) avec étiquette PRÊT / minuteur (.gt, 9 px sous le bouton)
	local gift = iconBtn(pills, "ui:gift", 3)
	L.gift = gift
	local gt = K.txt("", 10, F.display, C.muted, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -7), Size = UDim2.fromOffset(0, 14), AutomaticSize = Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = C.panelSolid, ZIndex = 4, Parent = gift.btn,
	})
	K.round(gt)
	K.border(gt, C.stroke, 2)
	K.padding(gt, 0, 5, 0, 5)
	L.giftT = gt
	gift.btn.Activated:Connect(function() UI.claimGift() end)
	-- boutique Robux (remplace les boutons musique / effets sonores du site) : .btn.green
	local shop = iconBtn(pills, nil, 4, "R$")
	shop.grad.Color = iconSeq("#4dff8a", "#1fc85a", "#0f8a3a")
	L.shop = shop
	shop.btn.Activated:Connect(function() UI.openRobux() end)
end

---------------------------------------------------------------------------- HUD de la zone de jeu
local function buildHud()
	local play = frame({ Name = "Play", ZIndex = ZL.hud, Parent = gui })
	L.play = play
	local col = frame({ Name = "Hud", Position = UDim2.fromOffset(0, 2), Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = play })
	K.vlist(col, 4, Enum.HorizontalAlignment.Center)
	L.hud = col
	-- nom de la boulangerie
	local bk = frame({ Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1, Parent = col })
	K.hlist(bk, 5, nil, Enum.VerticalAlignment.Center)
	K.img("ui:home", { Size = UDim2.fromOffset(19, 19), LayoutOrder = 1, Parent = bk })
	local bkName = player.DisplayName ~= "" and player.DisplayName or player.Name
	local _, bl = olShadow(bk, "La Boulangerie de " .. bkName, 14, C.cream, 4, { LayoutOrder = 2 })
	L.bakery = bl
	-- compteur (.ol-lg) + unité
	local cbox, cl, cs = olShadow(col, "0", 62, C.white, 6, { LayoutOrder = 2 })
	L.count, L.countSh = cl, cs
	L.countSc = new("UIScale", { Parent = cbox })
	-- CPS
	local cps = frame({ BackgroundTransparency = 0.45, BackgroundColor3 = Color3.fromRGB(10, 5, 30), Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3, Parent = col })
	K.round(cps)
	K.border(cps, C.white, 2, 0.92)
	K.padding(cps, 3, 12, 3, 12)
	K.hlist(cps, 4, nil, Enum.VerticalAlignment.Center)
	L.cpsIcon = K.img("ui:bolt", { Size = UDim2.fromOffset(17, 17), LayoutOrder = 1, Parent = cps })
	L.cpsV = K.txt("0", 15, F.num, C.lime, { Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2, Parent = cps })
	L.cpsU = K.txt(" / seconde", 15, F.num, C.white, { Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3, Parent = cps })
	L.cps = cps
	-- combo (CanvasGroup pour le fondu .idle)
	local combo = new("CanvasGroup", { Name = "Combo", BackgroundTransparency = 1, Size = UDim2.fromOffset(320, 36), GroupTransparency = 1, LayoutOrder = 4, Parent = col })
	local lbl = frame({ Size = UDim2.new(1, 0, 0, 18), Parent = combo })
	local nb, nl, ns = olShadow(lbl, "COMBO 0", 15, C.white, 4, { Position = UDim2.fromOffset(3, 0) })
	local mb, ml, ms = olShadow(lbl, "×1", 15, C.white, 4, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 0) })
	K.accBind(ml, "TextColor3")
	L.comboN, L.comboNS, L.comboM, L.comboMS = nl, ns, ml, ms
	local _ = nb
	local _ = mb
	local bar = frame({ BackgroundTransparency = 0.3, BackgroundColor3 = Color3.fromRGB(10, 5, 30), Position = UDim2.fromOffset(2, 21), Size = UDim2.new(1, -4, 0, 10), Parent = combo })
	K.round(bar)
	K.border(bar, C.stroke, 2)
	L.comboBar = bar
	local fill = frame({ BackgroundTransparency = 0, BackgroundColor3 = C.white, Size = UDim2.fromScale(0, 1), Parent = bar })
	K.round(fill)
	K.seqBind(new("UIGradient", { Parent = fill }), { 0, 60, 120 }, 0.6)
	L.comboFill = fill
	L.combo = combo
	L.comboShown = false
	-- buffs
	local buffs = frame({ Name = "Buffs", Size = UDim2.new(1, -20, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = col })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = buffs })
	L.buffs = buffs
	L.buffRefs = {}
	-- indice « CLIQUE LE COOKIE ! »
	local hint = new("CanvasGroup", { Name = "Hint", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(300, 84), Parent = play })
	K.img("ui:tap", { Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Parent = hint })
	olShadow(hint, "CLIQUE LE COOKIE !", 22, C.white, 4, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 48) })
	L.hint = hint
	L.hintGone = false
	-- bannières (boss / fièvre)
	local banners = frame({ Name = "Banners", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -44), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = play })
	K.vlist(banners, 6, Enum.HorizontalAlignment.Center)
	L.banners = banners
	-- ticker d'infos
	local tk = frame({ Name = "Ticker", BackgroundTransparency = 0.28, BackgroundColor3 = Color3.fromRGB(8, 4, 24), AnchorPoint = Vector2.new(0, 1), ClipsDescendants = true, Parent = play })
	K.round(tk)
	K.border(tk, C.white, 2, 0.92)
	local tag = frame({ BackgroundTransparency = 0, BackgroundColor3 = C.red, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = tk })
	K.round(tag)
	K.padding(tag, 0, 12, 0, 12)
	local tagL = K.txt("INFO", 13, F.display, C.white, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = tag })
	-- coin carré à droite de l'étiquette (le ticker arrondi la coupe à gauche seulement)
	frame({ BackgroundTransparency = 0, BackgroundColor3 = C.red, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 14, 1, 0), ZIndex = 0, Parent = tag })
	local track = new("CanvasGroup", { BackgroundTransparency = 1, Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -50, 1, 0), Parent = tk })
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.04, 0), NumberSequenceKeypoint.new(0.96, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = track })
	local msg = K.txt("", 14, F.medium, Color3.fromHex("#e9e0ff"), { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = track })
	L.ticker, L.tickerTag, L.tickerTagL, L.tickerTrack, L.tickerMsg = tk, tag, tagL, track, msg
	L.tickX, L.tickNext = 0, 0.6
end

---------------------------------------------------------------------------- panneau
local function buildPanel()
	local p = frame({ Name = "Panel", BackgroundTransparency = 0, BackgroundColor3 = C.white, ZIndex = ZL.panel, Parent = gui })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(26, 13, 61), Color3.fromRGB(14, 7, 36)), Transparency = NumberSequence.new(0.1, 0.08), Parent = p })
	L.panelCorner = new("UICorner", { CornerRadius = UDim.new(0, 26), Parent = p })
	K.border(p, C.stroke, 3)
	-- bord RGB (.rgb-edge::after) : anneau de 3 px juste à l'intérieur du bord sombre
	local edge = frame({ Name = "RgbEdge", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), ZIndex = 20, Parent = p })
	L.edgeCorner = new("UICorner", { CornerRadius = UDim.new(0, 23), Parent = edge })
	local es = new("UIStroke", { Thickness = 3, Transparency = 0.1, Color = C.white, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = edge })
	K.spinBind(new("UIGradient", { Parent = es }), 60)
	L.panel = p
	-- poignée de la feuille (mobile portrait)
	local handle = new("TextButton", { Name = "Handle", Text = "", AutoButtonColor = false, BackgroundColor3 = C.white, BackgroundTransparency = 0.72, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(46, 5), Visible = false, ZIndex = 21, Parent = p })
	K.round(handle)
	local hitArea = new("TextButton", { Text = "", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 40, 1, 20), ZIndex = 22, Parent = handle })
	local function toggle()
		expanded = not expanded
		UI.relayout()
	end
	handle.Activated:Connect(toggle)
	hitArea.Activated:Connect(toggle)
	L.handle = handle
	-- onglets
	-- fond des onglets (rgba(0,0,0,.18) + filet bas) : coins du haut arrondis comme le panneau (overflow: hidden)
	local tabsClip = frame({ Name = "TabsBg", ClipsDescendants = true, Size = UDim2.new(1, 0, 0, 77), ZIndex = 2, Parent = p })
	local tabsBg = frame({ BackgroundTransparency = 0.82, BackgroundColor3 = C.black, Size = UDim2.new(1, 0, 1, 40), ZIndex = 2, Parent = tabsClip })
	L.tabsRound = new("UICorner", { CornerRadius = UDim.new(0, 26), Parent = tabsBg })
	frame({ BackgroundTransparency = 0.94, BackgroundColor3 = C.white, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), ZIndex = 3, Parent = tabsClip })
	L.tabsBg = tabsClip
	local tabs = new("ScrollingFrame", {
		Name = "Tabs", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, ZIndex = 3, Parent = p,
	})
	L.tabs = tabs
	L.tabList = K.hlist(tabs, 4, nil, Enum.VerticalAlignment.Top)
	L.tabBtns = {}
	for i, t in Panel.TABS do
		local b = new("TextButton", { Name = "Tab_" .. t.id, Text = "", AutoButtonColor = false, BackgroundColor3 = C.white, BackgroundTransparency = 1, Size = UDim2.fromOffset(58, 57), LayoutOrder = i, ZIndex = 3, Parent = tabs })
		K.round(b, 14)
		local sel = new("UIGradient", { Rotation = 90, Enabled = false, Transparency = NumberSequence.new(0.45, 0.65), Parent = b })
		local st = new("UIStroke", { Thickness = 2, Transparency = 1, Color = C.white, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
		local ic = K.img("tab:" .. t.id, { Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 5), ZIndex = 4, Parent = b })
		local lb = K.txt(t.l, 11, F.body, C.muted, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = b })
		local badge = K.txt("", 11, F.display, C.white, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, -2), Size = UDim2.fromOffset(18, 18), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0, BackgroundColor3 = C.red, Visible = false, ZIndex = 6, Parent = b,
		})
		K.round(badge)
		K.border(badge, C.stroke, 2)
		K.padding(badge, 0, 4, 0, 4)
		L.tabBtns[t.id] = { btn = b, sel = sel, st = st, icon = ic, label = lb, badge = badge }
		b.MouseEnter:Connect(function() if UI.tab ~= t.id then b.BackgroundTransparency = 0.94; lb.TextColor3 = C.white end end)
		b.MouseLeave:Connect(function() if UI.tab ~= t.id then b.BackgroundTransparency = 1; lb.TextColor3 = C.muted end end)
		b.Activated:Connect(function() UI.setTab(t.id) end)
	end
	-- corps défilant
	local body = new("ScrollingFrame", {
		Name = "Body", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = Color3.fromHex("#4a3590"),
		ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, ZIndex = 2, Parent = p,
	})
	K.padding(body, 12, 12, 18, 12)
	L.body = body
	body:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
		if L.page and UI.tab and math.abs(L.page.AbsoluteSize.X - (body.AbsoluteWindowSize.X - 28)) > 2 then UI.render(true) end
	end)
end

local function styleTab(id: string)
	for tid, r in L.tabBtns do
		local on = tid == id
		r.sel.Enabled = on
		r.btn.BackgroundTransparency = on and 0 or 1
		r.label.TextColor3 = on and C.white or C.muted
		if on then
			K.seqBind(r.sel, { 0, 40 }, 0.5)
			K.accBind(r.st, "Color", 0, 0.7)
			r.st.Transparency = 0.3
		else
			K.seqUnbind(r.sel)
			K.accUnbind(r.st)
			r.st.Transparency = 1
			r.icon.Position = UDim2.new(0.5, 0, 0, 5)
			r.icon.Rotation = 0
		end
	end
end

---------------------------------------------------------------------------- onglets & rendu
local lastSoft = ""
local page: Frame? = nil
function UI.render(keepScroll: boolean?)
	if not L.body then return end
	local body = L.body :: ScrollingFrame
	local y = body.CanvasPosition.Y
	if page then page:Destroy() end
	-- largeur fixe en pixels : la page ne peut plus déborder à droite du panneau
	local width = math.max(200, body.AbsoluteWindowSize.X - 24 - 4)
	local pg = frame({ Name = "Page_" .. UI.tab, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2, Parent = body })
	K.vlist(pg, 8)
	page = pg
	L.page = pg
	Panel.render(UI.tab, pg, width)
	lastSoft = Panel.softKey(UI.tab)
	if keepScroll then
		task.defer(function() body.CanvasPosition = Vector2.new(0, y) end)
	else
		body.CanvasPosition = Vector2.zero
	end
end
function UI.setTab(id: string)
	if id ~= "robux" then UI.prevTab = id end
	UI.tab = id
	styleTab(id)
	UI.render(false)
	-- mobile : l'onglet choisi reste visible dans la barre défilante
	local r = L.tabBtns[id]
	if r and UI.mobile then
		local tabs = L.tabs :: ScrollingFrame
		local x = r.btn.AbsolutePosition.X - tabs.AbsolutePosition.X + tabs.CanvasPosition.X
		local target = math.max(0, x - tabs.AbsoluteSize.X / 2 + 29)
		tween(tabs, 0.25, { CanvasPosition = Vector2.new(target, 0) })
	end
end
UI.openTab = UI.setTab
function UI.openRobux() UI.setTab("robux") end
function UI.openMinigame(id: string)
	if Minigames and Minigames.open then Minigames.open(id) end
end
function UI.bought(_kind: string, _id: string) end
function UI.buyPass(key: string)
	if not act("buyPass", key) then UI.toast("Bientôt disponible !", "#ffc93c", "ui:clock") end
end
function UI.buyProduct(key: string)
	if not act("buyProduct", key) then UI.toast("Bientôt disponible !", "#ffc93c", "ui:clock") end
end
function UI.applySettings()
	local st = Panel.settings
	Store.reduced = st.reduced
	Stage.setSettings({ reduced = st.reduced, shake = st.shake, pm = st.pm })
end

---------------------------------------------------------------------------- mise en page appliquée
function UI.relayout()
	local g = computeLayout()
	geo = g
	local mobile = g.mode ~= "desktop"
	UI.mobile, UI.mode = mobile, g.mode
	local TOP = g.TOP
	-- barre du haut (évite les boutons Roblox en haut à gauche)
	local inset = GuiService.TopbarInset
	local left = math.max(mobile and 10 or 14, inset.Min.X + 8)
	local right = g.W - (mobile and 10 or 14)
	if inset.Max.X > inset.Min.X and inset.Max.X < g.W - 4 then right = math.min(right, inset.Max.X - 8) end
	L.top.Size = UDim2.fromOffset(g.W, TOP)
	L.logo.Position = UDim2.fromOffset(left, TOP / 2)
	L.pills.Position = UDim2.fromOffset(right, TOP / 2)
	local fs = mobile and 20 or 27
	for _, l in { L.logoA, L.logoB, L.logoSA, L.logoSB } do l.TextSize = fs end
	L.logoMark.Size = UDim2.fromOffset(math.floor(fs * 1.35), math.floor(fs * 1.35))
	L.logoBoxB.Visible = g.W >= 520
	L.starPill.holder.Visible = g.W >= 380
	local ph = mobile and 32 or 38
	sizePill(L.gemPill, ph, mobile)
	sizePill(L.starPill, ph, mobile)
	local ib = mobile and 36 or 42
	sizeIconBtn(L.gift, ib, mobile and 12 or 14)
	sizeIconBtn(L.shop, ib, mobile and 12 or 14)
	local pillsList = L.pills:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	pillsList.Padding = UDim.new(0, mobile and 5 or 8)
	-- zone de jeu + HUD
	local pl = g.play
	L.play.Position = UDim2.fromOffset(pl.left, pl.top)
	L.play.Size = UDim2.fromOffset(pl.width, pl.height)
	local cfs = mobile and 34 or math.floor(clamp(g.W * 0.052, 36, 62))
	L.count.TextSize, L.countSh.TextSize = cfs, cfs
	L.cpsV.TextSize, L.cpsU.TextSize = mobile and 12.5 or 15, mobile and 12.5 or 15
	local cpad = L.cps:FindFirstChildOfClass("UIPadding")
	if cpad then cpad.PaddingTop, cpad.PaddingBottom = UDim.new(0, mobile and 2 or 3), UDim.new(0, mobile and 2 or 3) end
	L.combo.Size = UDim2.fromOffset(math.min(320, pl.width * 0.8), mobile and 31 or 36)
	for _, l in { L.comboN, L.comboNS, L.comboM, L.comboMS } do l.TextSize = mobile and 13 or 15 end
	L.comboBar.Size = UDim2.new(1, -4, 0, mobile and 7 or 10)
	L.comboBar.Position = UDim2.fromOffset(2, mobile and 19 or 21)
	local R = clamp(math.min(pl.width, pl.height * 0.8) * 0.22, 60, 170)
	L.hint.Position = UDim2.new(0.5, 0, 0, math.min(pl.height - 120, pl.height * 0.56 + R + 22))
	L.banners.Position = UDim2.new(0.5, 0, 1, mobile and -32 or -44)
	local tkh = mobile and 24 or 30
	local tkm = mobile and 8 or 14
	L.ticker.Position = UDim2.new(0, tkm, 1, mobile and -4 or -8)
	L.ticker.Size = UDim2.new(1, -2 * tkm, 0, tkh)
	L.tickerTagL.TextSize = mobile and 11 or 13
	local tp = L.tickerTag:FindFirstChildOfClass("UIPadding")
	if tp then tp.PaddingLeft, tp.PaddingRight = UDim.new(0, mobile and 8 or 12), UDim.new(0, mobile and 8 or 12) end
	L.tickerMsg.TextSize = mobile and 12 or 14
	-- panneau
	local P = g.panel
	L.panel.Position = UDim2.fromOffset(P.x, P.y)
	L.panel.Size = UDim2.fromOffset(P.w, P.h)
	L.panelCorner.CornerRadius = UDim.new(0, g.mode == "portrait" and 22 or 26)
	L.edgeCorner.CornerRadius = UDim.new(0, g.mode == "portrait" and 19 or 23)
	L.tabsRound.CornerRadius = UDim.new(0, g.mode == "portrait" and 22 or 26)
	L.handle.Visible = g.mode == "portrait"
	local tabTop = g.mode == "portrait" and 8 or (mobile and 8 or 10)
	local tabH = 57
	local barH = tabTop + tabH + (mobile and 6 or 8)
	L.tabsBg.Size = UDim2.new(1, 0, 0, barH + 2)
	local tabs = L.tabs :: ScrollingFrame
	tabs.Position = UDim2.fromOffset(mobile and 8 or 10, tabTop)
	tabs.Size = UDim2.new(1, mobile and -16 or -20, 0, tabH)
	local n = #Panel.TABS
	if mobile then
		L.tabList.Padding = UDim.new(0, 2)
		for _, r in L.tabBtns do r.btn.Size = UDim2.fromOffset(58, tabH) end
		tabs.ScrollingEnabled = true
	else
		L.tabList.Padding = UDim.new(0, 4)
		local w = (P.w - 20 - 4 * (n - 1)) / n
		for _, r in L.tabBtns do r.btn.Size = UDim2.fromOffset(w, tabH) end
		tabs.ScrollingEnabled = false
		tabs.CanvasPosition = Vector2.zero
	end
	L.body.Position = UDim2.fromOffset(0, barH + 2)
	L.body.Size = UDim2.new(1, 0, 1, -(barH + 2))
	-- toasts / popup succès
	if mobile then
		L.toasts.AnchorPoint = Vector2.new(0.5, 0)
		L.toasts.Position = UDim2.fromOffset(g.W / 2, TOP + (g.mode == "portrait" and 96 or 10))
		L.toastList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	else
		L.toasts.AnchorPoint = Vector2.new(0, 0)
		L.toasts.Position = UDim2.fromOffset(14, TOP + 10)
		L.toastList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	end
	L.toasts.Size = UDim2.fromOffset(math.min(mobile and 420 or 330, g.W - 32), 0)
	-- stage (cookie, fond…)
	Stage.setLayout(g.W, g.H, pl, g.mode == "portrait")
	if UI.tab and L.lastWidth ~= P.w then
		L.lastWidth = P.w
		UI.render(true)
	end
end

---------------------------------------------------------------------------- toasts
function UI.toast(text: string, color: any?, icon: string?)
	if not L.toasts then return end
	local clean, emIcon = UI.stripEmoji(tostring(text or ""))
	local col: Color3 = C.violet
	if typeof(color) == "Color3" then col = color
	elseif type(color) == "string" and string.sub(color, 1, 1) == "#" then
		local ok, c = pcall(Color3.fromHex, color)
		if ok then col = c end
	end
	local key = icon or emIcon or "ui:sparkle"
	local list = L.toasts:GetChildren()
	local items = {}
	for _, ch in list do if ch:IsA("Frame") and ch:GetAttribute("live") then table.insert(items, ch) end end
	table.sort(items, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	while #items >= 4 do (table.remove(items, 1) :: Frame):Destroy() end
	L.toastN += 1
	local holder = frame({ Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = L.toastN, Parent = L.toasts })
	holder:SetAttribute("live", true)
	local t = frame({ BackgroundTransparency = 0.05, BackgroundColor3 = Color3.fromRGB(18, 9, 44), Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, Parent = holder })
	K.round(t, 16)
	K.border(t, C.stroke, 3)
	K.padding(t, 8, 14, 8, 8)
	K.hlist(t, 10, nil, Enum.VerticalAlignment.Center)
	local e = frame({ BackgroundTransparency = 0, BackgroundColor3 = col, Size = UDim2.fromOffset(34, 34), LayoutOrder = 1, Parent = t })
	K.round(e, 11)
	K.border(e, C.stroke, 2)
	K.img(key, { Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = e })
	local maxW = math.min(UI.mobile and 420 or 330, geo.W - 32) - 70
	local l = K.txt(clean, UI.mobile and 13 or 13.5, F.bold, C.ink, { Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, TextWrapped = true, LayoutOrder = 2, Parent = t })
	new("UISizeConstraint", { MaxSize = Vector2.new(maxW, math.huge), Parent = l })
	-- ombre portée 0 4px 0 (la bordure de 3 px est dessinée à l'extérieur)
	dropShadow(holder, 3, 4, 16, 0)
	t.ZIndex = 1
	K.padding(holder, 3, 3, 7, 3)
	local sc = new("UIScale", { Scale = 0.8, Parent = holder })
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(3.2, function()
		if not holder.Parent then return end
		holder:SetAttribute("live", false)
		tween(sc, 0.3, { Scale = 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		fadeTree(holder, 0.3)
		task.wait(0.3)
		holder:Destroy()
	end)
end

---------------------------------------------------------------------------- popup de succès
local achQueue: { any } = {}
local achBusy = false
local function nextAch()
	local a = table.remove(achQueue, 1)
	if not a then achBusy = false; return end
	achBusy = true
	local root = L.achRoot :: Frame
	for _, ch in root:GetChildren() do ch:Destroy() end
	local mobile = UI.mobile
	local card = frame({ BackgroundTransparency = 0, BackgroundColor3 = C.white, Size = UDim2.fromOffset(0, 82), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3, Parent = root })
	new("UISizeConstraint", { MinSize = Vector2.new(mobile and 250 or 280, 0), Parent = card })
	K.round(card, 22)
	K.border(card, C.stroke, 4)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#ffe066"), Color3.fromHex("#ffb800")), Parent = card })
	K.padding(card, 10, 20, 10, 10)
	K.hlist(card, 12, nil, Enum.VerticalAlignment.Center)
	-- 0 0 40px rgba(255,200,0,.5)
	local glow = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1.3, 40, 2.2, 0), ImageColor3 = Color3.fromRGB(255, 200, 0), ImageTransparency = 0.45, ZIndex = 1, Parent = root })
	if not K.trySet(glow, "fx:glow") then glow:Destroy() end
	local e = frame({ BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("#fff7d6"), Size = UDim2.fromOffset(58, 58), LayoutOrder = 1, ZIndex = 3, Parent = card })
	K.round(e, 16)
	K.border(e, C.stroke, 3)
	local ic = K.img(Panel.achIcon(a.id or ""), { Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Rotation = -200, ZIndex = 4, Parent = e })
	local isc = new("UIScale", { Scale = 0.2, Parent = ic })
	tween(ic, 0.6, { Rotation = 0 }, Enum.EasingStyle.Back)
	tween(isc, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	local txt = frame({ Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2, ZIndex = 3, Parent = card })
	K.vlist(txt, 1)
	K.txt("SUCCÈS DÉBLOQUÉ !", 13, F.display, C.stroke, { Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, TextTransparency = 0.25, LayoutOrder = 1, ZIndex = 3, Parent = txt })
	K.txt(a.name or "", 21, F.display, C.stroke, { Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2, ZIndex = 3, Parent = txt })
	local g = frame({ Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3, ZIndex = 3, Parent = txt })
	K.hlist(g, 3)
	K.txt("+" .. tostring(a.gems or 0), 13, F.num, C.stroke, { Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1, ZIndex = 3, Parent = g })
	K.img("ui:gem", { Size = UDim2.fromOffset(15, 15), LayoutOrder = 2, ZIndex = 3, Parent = g })
	K.txt("· +1 % de prod", 13, F.num, C.stroke, { Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3, ZIndex = 3, Parent = g })
	dropShadow(root, 4, 6, 22, 2)
	-- entrée : translateY(-190 %) → 0 avec rebond ; sortie inverse
	local g2 = geo
	local hidden, shown
	if mobile then
		root.AnchorPoint = Vector2.new(0.5, 1)
		local bottom = g2.mode == "portrait" and (g2.H - g2.panel.y + 20) or 20
		shown = UDim2.fromOffset(g2.W / 2, g2.H - bottom)
		hidden = UDim2.fromOffset(g2.W / 2, g2.H - bottom + 82 * 1.6 + bottom)
	else
		root.AnchorPoint = Vector2.new(1, 0)
		shown = UDim2.fromOffset(g2.W - (g2.pw + 36), g2.TOP + 10)
		hidden = UDim2.fromOffset(g2.W - (g2.pw + 36), g2.TOP + 10 - 82 * 1.9 - 20)
	end
	root.Position = hidden
	root.Visible = true
	tween(root, 0.5, { Position = shown }, Enum.EasingStyle.Back)
	task.delay(3.3, function()
		tween(root, 0.35, { Position = hidden }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.52)
		nextAch()
	end)
end
function UI.achievement(a: any)
	table.insert(achQueue, a)
	if not achBusy then nextAch() end
end

---------------------------------------------------------------------------- modales
-- buttons : { {text, kind, fn} } ou { {text = , kind = , fn = } } ; art = clé d'image au-dessus du titre
function UI.modal(title: string, body: any, buttons: { any }?, accent: Color3?, art: string?): () -> ()
	blockers += 1
	local back = new("TextButton", { Name = "Modal", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(6, 2, 18), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = ZL.modal, Parent = gui })
	tween(back, 0.25, { BackgroundTransparency = 0.28 })
	local closed = false
	local escConn: RBXScriptConnection? = nil
	local function close()
		if closed then return end
		closed = true
		blockers = math.max(0, blockers - 1)
		if escConn then escConn:Disconnect() end
		back:Destroy()
	end
	local mw = math.min(440, geo.W - 32)
	local holder = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(mw, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2, Parent = back })
	local m = frame({ BackgroundTransparency = 0, BackgroundColor3 = C.white, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2, Parent = holder })
	K.round(m, 26)
	K.border(m, C.stroke, 4)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#2a1668"), Color3.fromHex("#150a38")), Parent = m })
	K.padding(m, art and 66 or 22, 20, 20, 20)
	local col = frame({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2, Parent = m })
	K.vlist(col, 8, Enum.HorizontalAlignment.Center)
	dropShadow(holder, 4, 8, 26, 1)
	if art then
		local a = K.img(art, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(92, 92), ZIndex = 5, Parent = holder })
		local asc = new("UIScale", { Scale = 0, Parent = a })
		a.Rotation = -40
		tween(asc, 0.7, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(a, 0.7, { Rotation = 0 }, Enum.EasingStyle.Back)
	end
	olShadow(col, title, 30, accent or C.white, 6, { LayoutOrder = 1 })
	if type(body) == "string" then
		K.txt(body, 15, F.body, C.softInk, { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Center, LineHeight = 1.2, LayoutOrder = 2, ZIndex = 2, Parent = col })
	elseif typeof(body) == "Instance" then
		local bo = body :: GuiObject
		bo.LayoutOrder = 2
		bo.Parent = col
	elseif type(body) == "function" then
		body(col)
	end
	local br = frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, ZIndex = 2, Parent = col })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = br })
	K.padding(br, 8, 0, 0, 0)
	local list = buttons or { { "OK", "green" } }
	for i, b in list do
		local text = b.text or b.label or b[1] or "OK"
		local kind = b.kind or b.cls or b[2] or "violet"
		local fn = b.fn or b[3]
		local ts = game:GetService("TextService")
		local okW, sz = pcall(ts.GetTextSize, ts, text, 17, Enum.Font.FredokaOne, Vector2.new(1000, 40))
		local bw = math.clamp((okW and sz.X or #text * 9) + 44 + (b.icon and 24 or 0), 90, mw - 40)
		K.btn(text, kind, { size = UDim2.fromOffset(bw, 46), layoutOrder = i, parent = br, zindex = 3, icon = b.icon, onClick = function()
			close()
			if fn then task.spawn(fn) end
		end })
	end
	local sc = new("UIScale", { Scale = 0.5, Parent = holder })
	tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	-- Échap ferme la fenêtre ; Entrée valide le premier bouton
	escConn = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Return then
			local first = list[1]
			close()
			local fn = first and (first.fn or first[3])
			if input.KeyCode == Enum.KeyCode.Return and fn then task.spawn(fn) end
		end
	end)
	return close
end
function UI.blocking(): boolean return blockers > 0 end

---------------------------------------------------------------------------- éclosion d'œuf
function UI.hatch(eggId: string)
	local egg = D.EGG[eggId]
	local s = Store.state
	if not egg or not s then return end
	if s.gems < egg.cost then
		UI.toast("Pas assez de gemmes (" .. egg.cost .. " requises).", "#ff4d6d", "ui:gem")
		return
	end
	blockers += 1
	local reduced = Panel.settings.reduced
	local ov = new("TextButton", { Name = "Hatch", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(4, 1, 12), BackgroundTransparency = 0.05, Size = UDim2.fromScale(1, 1), ZIndex = ZL.hatch, ClipsDescendants = true, Parent = gui })
	-- fond radial (rgba(40,20,90,.85) au centre)
	local rad = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.45), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(1.6, 1.6), ImageColor3 = Color3.fromRGB(40, 20, 90), ImageTransparency = 0.1, ZIndex = 1, Parent = ov })
	rad.SizeConstraint = Enum.SizeConstraint.RelativeXX
	if not K.trySet(rad, "fx:glow") then rad:Destroy() end
	local rays = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(1.3, 1.3), ImageTransparency = 1, ZIndex = 2, Parent = ov })
	rays.SizeConstraint = Enum.SizeConstraint.RelativeXX
	if not K.trySet(rays, "fx:god_rays") then rays.Visible = false end
	local box = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(math.min(420, geo.W - 20), 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 3, Parent = ov })
	local col = frame({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 3, Parent = box })
	K.vlist(col, 10, Enum.HorizontalAlignment.Center)
	local eggSz = math.min(190, geo.H * 0.4)
	local eggHold = frame({ Size = UDim2.fromOffset(eggSz, eggSz), LayoutOrder = 1, ZIndex = 3, Parent = col })
	local big = K.img("egg:" .. eggId, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(eggSz, eggSz), ZIndex = 3, Parent = eggHold })
	local capBox, cap, capSh = olShadow(col, "Ça bouge…", 22, C.white, 4, { LayoutOrder = 2 })
	local flash = frame({ BackgroundTransparency = 1, BackgroundColor3 = C.white, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = ov })
	local t0 = os.clock()
	local result: any = nil
	local revealed, closed = false, false
	local conn: RBXScriptConnection? = nil
	local keyConn: RBXScriptConnection? = nil
	local function close()
		if closed then return end
		closed = true
		blockers = math.max(0, blockers - 1)
		if conn then conn:Disconnect() end
		if keyConn then keyConn:Disconnect() end
		ov:Destroy()
		if UI.tab == "pets" then UI.render(true) end
	end
	local function reveal()
		if revealed or not result then return end
		revealed = true
		if result.err or not result.ok then
			close()
			UI.toast(tostring(result.err or "Oups, l'œuf n'a pas éclos."), "#ff4d6d", "ui:gem")
			return
		end
		local R = D.rarities[result.rarity] or D.rarities.common
		local mythic = result.rarity == "mythic"
		local rc = Color3.fromHex(R.color)
		if not reduced then
			flash.BackgroundTransparency = 0
			tween(flash, 0.6, { BackgroundTransparency = 1 })
		end
		eggHold:Destroy()
		capBox:Destroy()
		rays.ImageColor3 = rc
		tween(rays, 0.4, { ImageTransparency = 0.45 })
		if mythic then K.accBind(rays, "ImageColor3", 0, 0.62) end
		local _, rl = olShadow(col, string.upper(R.name) .. (mythic and " ?!" or " !"), 22, rc, 4, { LayoutOrder = 1 })
		if mythic then K.accBind(rl, "TextColor3") end
		local def = D.PET[result.id]
		local psz = math.min(220, geo.H * 0.38)
		local ph = frame({ Size = UDim2.fromOffset(psz, psz), LayoutOrder = 2, ZIndex = 3, Parent = col })
		local pg = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.5, 1.5), ImageColor3 = mythic and C.hot or rc, ImageTransparency = 0.35, ZIndex = 3, Parent = ph })
		if not K.trySet(pg, "fx:glow") then pg:Destroy() end
		local pi = K.img("pet:" .. result.id, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Rotation = -40, ZIndex = 4, Parent = ph })
		local psc = new("UIScale", { Scale = 0, Parent = pi })
		tween(psc, 0.7, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(pi, 0.7, { Rotation = 0 }, Enum.EasingStyle.Back)
		olShadow(col, def and def.name or result.id, 38, C.white, 4, { LayoutOrder = 3 })
		local info = K.txt(result.isNew and "NOUVEAU PET !" or ("DOUBLON → NIVEAU " .. tostring(result.lvl) .. " !"), 15, F.bold, C.softInk, { Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 4, ZIndex = 3, Parent = col })
		local _ = info
		K.txt(E.petPower({ id = result.id, lvl = result.lvl }) .. (result.lucky and "  ·  Œuf chanceux !" or ""), 15, F.bold, C.lime, { Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 5, ZIndex = 3, Parent = col })
		local br = frame({ Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 6, ZIndex = 3, Parent = col })
		K.hlist(br, 8)
		K.padding(br, 10, 0, 0, 0)
		local again = K.btn("ENCORE  " .. egg.cost, "gold", { size = UDim2.fromOffset(150, 46), icon = "ui:gem", iconAfter = true, layoutOrder = 1, parent = br, zindex = 4, onClick = function()
			if Store.state and Store.state.gems >= egg.cost then
				close()
				UI.hatch(eggId)
			end
		end })
		again:setOff((Store.state and Store.state.gems or 0) < egg.cost)
		K.btn("TROP BIEN !", "green", { size = UDim2.fromOffset(150, 46), layoutOrder = 2, parent = br, zindex = 4, onClick = close })
		if mythic or result.rarity == "legendary" then Stage.confetti() end
		Stage.petHatched(result.id)
	end
	ov.Activated:Connect(function()
		if not revealed and result then reveal() end
	end)
	keyConn = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			if revealed or result then close() end
		elseif (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return) and not revealed and result then
			reveal()
		end
	end)
	task.spawn(function()
		local r = act("hatch", eggId)
		result = type(r) == "table" and r or { err = "Oups, réessaie." }
		if result.err then reveal() end
	end)
	-- secousses de l'œuf puis révélation à 1,7 s (0,3 s en mouvements réduits)
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - t0
		if not revealed then
			local per = t > 0.95 and 0.06 or 0.12
			local ph = (t % per) / per
			if not reduced then
				big.Rotation = ph < 0.5 and -4 + 16 * ph or 4 - 16 * (ph - 0.5)
				big.Position = UDim2.new(0.5, 0, 0.5, ph > 0.25 and ph < 0.75 and -3 or 0)
			end
			if t > 0.95 and cap.Text ~= "IL VA ÉCLORE !!" then
				cap.Text, capSh.Text = "IL VA ÉCLORE !!", "IL VA ÉCLORE !!"
			end
			if t > (reduced and 0.3 or 1.7) and result then reveal() end
		else
			rays.Rotation = (t * 45) % 360
		end
	end)
end

---------------------------------------------------------------------------- rebirth
function UI.rebirthFx(gain: number)
	local fx = frame({ Name = "RebirthFlash", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = ZL.flash, Parent = gui })
	local w = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.6, 1.6), ImageColor3 = C.white, Parent = fx })
	w.SizeConstraint = Enum.SizeConstraint.RelativeXX
	local c2 = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(2.4, 2.4), Parent = fx })
	c2.SizeConstraint = Enum.SizeConstraint.RelativeXX
	K.accBind(c2, "ImageColor3", 0, 0.7)
	if not K.trySet(w, "fx:glow") then w.Visible = false end
	if not K.trySet(c2, "fx:glow") then c2.Visible = false end
	local fs = clamp(geo.W * 0.1, 48, 110)
	local row = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, Parent = fx })
	K.hlist(row, 10)
	olShadow(row, "REBIRTH ! +" .. tostring(gain), fs, C.gold, 4, { LayoutOrder = 1 })
	K.img("ui:star", { Size = UDim2.fromOffset(fs * 0.9, fs * 0.9), LayoutOrder = 2, Parent = row })
	local sc = new("UIScale", { Scale = 0.5, Parent = row })
	tween(sc, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	Stage.confetti()
	Stage.rebirth()
	task.delay(1.32, function()
		for _, o in fx:GetDescendants() do
			if o:IsA("ImageLabel") then tween(o, 0.88, { ImageTransparency = 1 }) end
			if o:IsA("TextLabel") then tween(o, 0.88, { TextTransparency = 1 }) end
			if o:IsA("UIStroke") then tween(o, 0.88, { Transparency = 1 }) end
		end
		task.wait(1)
		fx:Destroy()
	end)
	UI.render(false)
end

---------------------------------------------------------------------------- cadeau, hors-ligne, achats
function UI.claimGift()
	local live = Store.live or {}
	if (live.giftIn or 0) > 0 then
		UI.toast("Prochain cadeau dans " .. K.fmtDur(live.giftIn) .. ".", nil, "ui:clock")
		return
	end
	local res = act("gift")
	if not res then
		UI.toast("Prochain cadeau dans " .. K.fmtDur(math.max(1, live.giftIn or 0)) .. ".", nil, "ui:clock")
		return
	end
	local label, icon = UI.stripEmoji(tostring(res))
	UI.modal("CADEAU !", function(col: Frame)
		olShadow(col, label, 28, C.gold, 4, { LayoutOrder = 2 })
	end, { { "MERCI !", "gold" } }, nil, icon or "ui:gift")
	Stage.confetti()
end
function UI.offline(away: number, gain: number)
	UI.modal("RE !", "Pendant ton absence (" .. K.fmtDur(away) .. "), ta boulangerie a cuit +" .. K.fmt(gain) .. " cookies (50 % d'efficacité hors-ligne).", { { "LET'S GOOO", "green" } }, nil, "ui:cookie")
end
function UI.welcome()
	UI.modal("COOKIE OVERDRIVE", "Clique le cookie. Chaque upgrade le transforme : lunettes, couronne, yeux laser, trou noir… Enchaîne les combos pour la FIÈVRE RGB, collectionne des pets, bats des boss et débloque 4 mini-jeux.", { { "C'EST PARTI !", "green" } }, nil, "ui:golden")
end
function UI.purchase(name: string, emoji: string?)
	local _, icon = UI.stripEmoji(emoji or "")
	UI.modal("MERCI !", tostring(name) .. " est activé. Profite bien !", { { "SUPER !", "green" } }, nil, icon or "ui:gift")
	Stage.confetti()
end

-- texte flottant (API du contrat, utilisable par les mini-jeux) : couche propre au-dessus de tout,
-- y compris de l'overlay des mini-jeux ; étiquettes recyclées
local floatGui: ScreenGui? = nil
local floatFree: { TextLabel } = {}
function UI.floatText(text: string, pos: Vector2, color: Color3?, size: number?)
	if not gui then return end
	if not floatGui then
		floatGui = new("ScreenGui", {
			Name = "CookieFloatText", ResetOnSpawn = false, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None,
			DisplayOrder = gui.DisplayOrder + 40, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = gui.Parent,
		})
	end
	local l = table.remove(floatFree)
	if not l then
		l = K.txt("", 26, F.display, C.white, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, TextXAlignment = Enum.TextXAlignment.Center })
		K.ol(l, 3)
	end
	local lab = l :: TextLabel
	local stroke = lab:FindFirstChildOfClass("UIStroke") :: UIStroke
	lab.Text = text
	lab.TextSize = math.floor(size or 26)
	lab.TextColor3 = color or C.white
	lab.TextTransparency = 0
	stroke.Transparency = 0
	stroke.Thickness = math.max(2, (size or 26) * 0.1)
	lab.Position = UDim2.fromOffset(pos.X, pos.Y)
	lab.Parent = floatGui
	tween(lab, 0.9, { Position = UDim2.fromOffset(pos.X + math.random(-20, 20), pos.Y - 70) })
	tween(lab, 0.9, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(stroke, 0.9, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.95, function()
		lab.Parent = nil
		table.insert(floatFree, lab)
	end)
end

---------------------------------------------------------------------------- ticker
local function tickerLine(): string
	local s, live = Store.state, Store.live or {}
	local dyn = {}
	if s then
		if live.boss then table.insert(dyn, "EN DIRECT : " .. live.boss.name .. " attaque ta boulangerie ! Clique le cookie pour riposter !") end
		if s.clicks > 50 then table.insert(dyn, "Tu as cliqué " .. K.fmt(s.clicks, true) .. " fois. Ton index mérite une statue.") end
		if (live.cpsBase or 0) > 0 then table.insert(dyn, "Ta production : " .. K.fmt(live.cpsBase) .. " cookies/s. Les voisins commencent à s'inquiéter.") end
		if #s.pets > 0 then
			local p = s.pets[math.random(#s.pets)]
			local d = D.PET[p.id]
			if d then table.insert(dyn, "Ton " .. d.name .. " a été élu employé du mois.") end
		end
		if s.rebirths > 0 then table.insert(dyn, "Rebirth n°" .. s.rebirths .. " confirmé. Le cookie est revenu encore plus fort.") end
	end
	local pool = table.clone(D.news)
	for _ = 1, 2 do for _, l in dyn do table.insert(pool, l) end end
	return pool[math.random(#pool)]
end
local function stepTicker(dt: number)
	local msg, track = L.tickerMsg :: TextLabel, L.tickerTrack :: CanvasGroup
	local tagW = math.floor((L.tickerTag :: Frame).AbsoluteSize.X)
	if track.Position.X.Offset ~= tagW then
		track.Position = UDim2.fromOffset(tagW, 0)
		track.Size = UDim2.new(1, -tagW, 1, 0)
	end
	if L.tickNext > 0 then
		L.tickNext -= dt
		if L.tickNext <= 0 then
			msg.Text = tickerLine()
			L.tickX = track.AbsoluteSize.X
			msg.Visible = true
		else
			msg.Visible = false
			return
		end
	end
	L.tickX -= 85 * dt
	msg.Position = UDim2.fromOffset(math.floor(L.tickX), 0)
	if L.tickX < -msg.AbsoluteSize.X - 20 then L.tickNext = 0.3 end
end

---------------------------------------------------------------------------- HUD : boucle
local BUFF_ICON = { frenzy = "ui:fire", clickstorm = "ui:tornado", gift = "ui:gift", victory = "ui:trophy" }
-- multiplicateurs (le serveur n'envoie que id, nom, durée) : GameData.golden + bonus serveur (cadeau, victoire)
local BUFF_MULT: { [string]: { cps: number?, click: number? } } = { gift = { cps = 3 }, victory = { cps = 2 } }
for _, g in D.golden do if g.buff then BUFF_MULT[g.buff.id] = { cps = g.buff.cps, click = g.buff.click } end end
local function buildBuffs(buffs: { any })
	for _, ch in L.buffs:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
	L.buffRefs = {}
	for i, b in buffs do
		local m = BUFF_MULT[b.id] or {}
		local label = tostring(b.name) .. ((m.cps and m.cps > 1) and (" ×" .. m.cps) or (m.click and (" clic ×" .. m.click)) or "")
		-- .buff : pastille + minuteur ; la barre .drain est posée par-dessus (hors mise en page)
		local holder = frame({ Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = i, Parent = L.buffs })
		local chip = Panel.chip(holder, BUFF_ICON[b.id] or "ui:bolt", label, 1)
		local t = K.txt("", 12, F.num, C.muted, { Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3, Parent = chip })
		local clip = new("CanvasGroup", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = holder })
		K.round(clip)
		local drain = frame({ BackgroundTransparency = 0, BackgroundColor3 = C.white, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3), Parent = clip })
		K.accBind(drain, "BackgroundColor3")
		L.buffRefs[b.id] = { t = t, drain = drain }
	end
end
local function stepHud(dt: number)
	local s, live = Store.state, Store.live
	if not s or not live then return end
	local ctx = Stage.ctx
	-- compteur lissé
	local target = live.cookies or s.cookies
	local d = target - hud.disp
	if math.abs(d) < 1 or math.abs(d) / (math.abs(target) + 1) < 0.0005 then hud.disp = target else hud.disp += d * math.min(1, dt * 12) end
	local str = K.fmt(math.floor(hud.disp), true)
	if str ~= hud.lastStr then
		hud.lastStr = str
		local usz = math.floor(L.count.TextSize * 0.42)
		local txt = str .. '<font size="' .. usz .. '" color="#ffe2b0"> cookies</font>'
		L.count.Text = txt
		L.countSh.Text = str .. '<font size="' .. usz .. '"> cookies</font>'
	end
	local cs = K.fmt(live.cps or 0)
	if cs ~= hud.lastCps then hud.lastCps = cs; L.cpsV.Text = cs end
	local boost = (#(live.buffs or {}) > 0) or (live.fever or 0) > 0
	if boost ~= hud.boost then
		hud.boost = boost
		if boost then K.accBind(L.cpsV, "TextColor3") else K.accUnbind(L.cpsV); L.cpsV.TextColor3 = C.lime end
	end
	-- combo / fièvre
	local combo = live.combo or { n = 0, mult = 1, heat = 0 }
	local fever = (live.fever or 0) > 0
	local show = (combo.n or 0) >= 3 or fever
	if show ~= L.comboShown then
		L.comboShown = show
		tween(L.combo, 0.3, { GroupTransparency = show and 0 or 1 })
	end
	if show then
		local n = fever and "FIÈVRE RGB" or ("COMBO " .. math.floor(combo.n))
		local m
		if fever then
			m = "×" .. E.FEVER_MULT .. " · " .. string.gsub(string.format("%.1f", math.max(0, live.fever)), "%.", ",") .. " s"
			L.comboFill.Size = UDim2.fromScale(clamp(live.fever / math.max(1, (Store.M and Store.M.feverDur) or 8), 0, 1), 1)
		else
			m = "×" .. string.gsub(tostring(math.floor((combo.mult or 1) * 10 + 0.5) / 10), "%.", ",")
			L.comboFill.Size = UDim2.fromScale(clamp(combo.heat or 0, 0, 1), 1)
		end
		if L.comboN.Text ~= n then L.comboN.Text, L.comboNS.Text = n, n end
		if L.comboM.Text ~= m then L.comboM.Text, L.comboMS.Text = m, m end
	end
	-- buffs
	local key = ""
	for _, b in live.buffs or {} do key ..= b.id .. "," end
	if key ~= hud.buffKey then hud.buffKey = key; buildBuffs(live.buffs or {}) end
	for _, b in live.buffs or {} do
		local r = L.buffRefs[b.id]
		if r then
			r.t.Text = math.ceil(math.max(0, b.left)) .. " s"
			r.drain.Size = UDim2.new(clamp(b.left / math.max(1, b.dur), 0, 1), 0, 0, 3)
		end
	end
	-- bannières
	local boss = live.boss
	local bkey = (fever and "F" or "") .. (boss and ("B" .. boss.name) or "")
	if bkey ~= hud.bannerKey then
		hud.bannerKey = bkey
		for _, ch in L.banners:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
		hud.bossT = nil
		local fs = UI.mobile and 18 or math.floor(clamp(geo.W * 0.026, 20, 30))
		local function banner(order: number, icon: string, text: string, color: Color3?, acc: boolean): (Frame, Frame)
			local holder = frame({ Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order, Parent = L.banners })
			local b = frame({ BackgroundTransparency = 0.3, BackgroundColor3 = Color3.fromRGB(10, 5, 30), Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, Parent = holder })
			K.round(b, 16)
			K.border(b, C.stroke, 3)
			K.padding(b, 4, 18, 6, 18)
			K.hlist(b, 6, nil, Enum.VerticalAlignment.Center)
			K.img(icon, { Size = UDim2.fromOffset(math.floor(fs * 1.3), math.floor(fs * 1.3)), LayoutOrder = 1, Parent = b })
			local _, l = olShadow(b, text, fs, color or C.white, 4, { LayoutOrder = 2 })
			if acc then K.accBind(l, "TextColor3") end
			local sc = new("UIScale", { Scale = 0.3, Parent = holder })
			tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			return holder, b
		end
		if boss then
			local bid = "broccoli"
			for _, bd in D.bosses do if bd.name == boss.name then bid = bd.id end end
			local _, b = banner(1, "boss:" .. bid, boss.name .. " attaque !", C.pink, false)
			hud.bossT = K.txt("", math.floor(fs * 0.55), F.num, C.muted, { Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3, Parent = b })
		end
		if fever then
			local h = banner(2, "ui:rainbow", "FIÈVRE RGB — TOUT ×" .. E.FEVER_MULT, nil, true)
			hud.feverBanner = h
		else
			hud.feverBanner = nil
		end
	end
	if boss and hud.bossT then
		hud.bossT.Text = "PV " .. math.ceil(boss.hp / math.max(1, boss.maxHp) * 100) .. " % · " .. math.max(0, math.ceil(boss.left)) .. " s"
	end
	if hud.feverBanner and not Panel.settings.reduced then
		hud.feverBanner.Rotation = math.sin(ctx.T * math.pi * 2 / 0.25) * 1.5
	end
	-- pastilles
	local gems = live.gems or s.gems
	if gems ~= hud.lastGems then
		local up = hud.lastGems >= 0 and gems > hud.lastGems
		hud.lastGems = gems
		L.gems.Text = K.fmt(gems, true)
		if up then
			L.gemSc.Scale = 1.22
			tween(L.gemSc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end
	if s.stars ~= hud.lastStars then hud.lastStars = s.stars; L.stars.Text = K.fmt(s.stars, true) end
	-- indice
	if not L.hintGone and s.clicks > 0 then
		L.hintGone = true
		tween(L.hint, 0.4, { GroupTransparency = 1 })
	end
	if not L.hintGone then
		-- @keyframes bob : translateY(0 → -10px) en 1 s aller-retour
		L.hintBob = Panel.settings.reduced and 0 or -10 * (math.sin(ctx.T * math.pi * 2) + 1) / 2
	end
	-- cadeau
	local gin = live.giftIn or 0
	local ready = gin <= 0
	if ready ~= hud.gready then
		hud.gready = ready
		L.gift.grad.Color = ready and iconSeq("#ffe066", "#ffb800") or iconSeq("#3a2a70", "#251652", "#170d38")
		L.giftT.BackgroundColor3 = ready and C.red or C.panelSolid
		L.giftT.TextColor3 = ready and C.white or C.muted
	end
	local gt = ready and "PRÊT" or (gin >= 60 and (math.ceil(gin / 60) .. " min") or (math.ceil(gin) .. " s"))
	if gt ~= hud.gt then hud.gt = gt; L.giftT.Text = gt end
	-- @keyframes giftWiggle (1,2 s) : -12° ×1,08 → 10° ×1,08 → repos
	local gb = L.gift.face :: Frame
	if ready and not Panel.settings.reduced then
		local p = (ctx.T % 1.2) / 1.2
		local rot, sc = 0, 1
		if p < 0.1 then rot, sc = -12 * (p / 0.1), 1 + 0.08 * (p / 0.1)
		elseif p < 0.2 then rot, sc = -12 + 22 * ((p - 0.1) / 0.1), 1.08
		elseif p < 0.3 then rot, sc = 10 - 10 * ((p - 0.2) / 0.1), 1.08 - 0.08 * ((p - 0.2) / 0.1) end
		gb.Rotation = rot
		L.gift.sc.Scale = sc
	elseif gb.Rotation ~= 0 then
		gb.Rotation = 0
		L.gift.sc.Scale = 1
	end
end

-- pulsation du compteur à chaque clic (#count.pulse)
function UI.pulseCount()
	if not L.countSc then return end
	L.countSc.Scale = 1.06
	tween(L.countSc, 0.18, { Scale = 1 })
end

local upAcc, secAcc = 0, 0
function UI.step(dt: number)
	K.stepLive(dt)
	stepHud(dt)
	stepTicker(dt)
	local t = Stage.ctx.T
	-- logo qui tourne (8 s / tour), icône de l'onglet actif qui se balance
	L.logoMark.Rotation = (t * 45) % 360
	local r = L.tabBtns[UI.tab]
	if r and not Panel.settings.reduced then
		local k = (math.sin(t * math.pi * 2 / 1.4 - math.pi / 2) + 1) / 2
		r.icon.Position = UDim2.new(0.5, 0, 0, 5 - 2 * k)
		r.icon.Rotation = -6 * k
	end
	if L.hintBob and not L.hintGone then
		local R = Stage.ctx.R
		local pl = geo.play
		L.hint.Position = UDim2.new(0.5, 0, 0, math.min(pl.height - 120, pl.height * 0.56 + R + 22) + L.hintBob)
	end
	Panel.anim(t)
	upAcc += dt
	secAcc += dt
	if upAcc > 0.2 then
		upAcc = 0
		Panel.update(UI.tab)
	end
	if secAcc > 1 then
		secAcc = 0
		UI.checkSoft()
		UI.badges()
		UI.second()
	end
end
-- annonces du site (événement « second ») : mini-jeu débloqué, arrivée des boss
local known: { [string]: boolean }? = nil
local bossKnown = false
function UI.second()
	local s = Store.state
	if not s then return end
	if not known then
		local k = {}
		for _, id in Panel.MG_ORDER do k[id] = E.minigameUnlocked(s, id) end
		known = k
		bossKnown = s.allTimeBaked >= E.BOSS_UNLOCK
		return
	end
	local kn = known :: { [string]: boolean }
	for _, id in Panel.MG_ORDER do
		if not kn[id] and E.minigameUnlocked(s, id) then
			kn[id] = true
			local m = Panel.MG[id]
			UI.toast("Mini-jeu débloqué : " .. (m and m.name or id) .. " ! Va dans l'onglet Jeux.", m and m.color or "#ff2bd6", "mg:" .. id)
		end
	end
	if not bossKnown and s.allTimeBaked >= E.BOSS_UNLOCK then
		bossKnown = true
		UI.toast("Les BOSS vont bientôt débarquer. Prépare ton index.", "#ff4d6d", "ui:sword")
	end
end
function UI.checkSoft()
	if not Store.state then return end
	local k = Panel.softKey(UI.tab)
	if k ~= lastSoft and not Panel.rebirthArmed() then UI.render(true) end
end
function UI.badges()
	local b = Panel.badges()
	for id, r in L.tabBtns do
		local n = b[id] or 0
		local vis = n > 0
		if r.badge.Visible ~= vis then
			r.badge.Visible = vis
			if vis then
				local sc = r.badge:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = r.badge })
				sc.Scale = 1.3
				tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
		if vis then r.badge.Text = n > 9 and "9+" or tostring(n) end
	end
end

-- appelé à chaque état complet reçu du serveur
function UI.onFull()
	if not L.body then return end
	if not UI.renderedOnce then
		UI.renderedOnce = true
		hud.disp = Store.state.cookies
		UI.render(false)
		UI.badges()
	else
		UI.checkSoft()
	end
end
function UI.onLive(_live: any) end

-- mini-jeu ouvert : l'overlay opaque des mini-jeux couvre tout ; on masque le jeu (toasts et modales restent)
function UI.setMinigame(open: boolean)
	if not L.top then return end
	L.top.Visible = not open
	L.play.Visible = not open
	L.panel.Visible = not open
	Stage.setPaused(open)
	if not open then UI.render(true) end
end

---------------------------------------------------------------------------- init
-- onTap(pos) : clic sur le cookie · onGolden(id) : clic sur un cookie doré
function UI.init(store: any, actFn: (string, ...any) -> any, mg: any, onTap: (Vector2) -> (), onGolden: (id: number) -> ())
	Store, act, Minigames = store, actFn, mg
	local pg = player:WaitForChild("PlayerGui") :: PlayerGui
	gui = new("ScreenGui", {
		Name = "CookieOverdrive", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5, ScreenInsets = Enum.ScreenInsets.None, Parent = pg,
	})
	UI.gui = gui
	Stage.init(gui, onTap, onGolden)
	Panel.init(UI, Store, act)
	buildTopbar()
	buildHud()
	buildPanel()
	-- toasts + popup de succès
	local toasts = frame({ Name = "Toasts", Size = UDim2.fromOffset(330, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = ZL.toasts, Parent = gui })
	L.toastList = K.vlist(toasts, 6)
	L.toasts = toasts
	L.toastN = 0
	L.achRoot = frame({ Name = "AchPop", Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, Visible = false, ZIndex = ZL.ach, Parent = gui })
	styleTab(UI.tab)
	-- « Mouvements réduits » suit le réglage d'accessibilité Roblox au démarrage
	local okR, rm = pcall(function() return GuiService.ReducedMotionEnabled end)
	if okR and rm == true then Panel.settings.reduced = true end
	UI.applySettings()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() UI.relayout() end)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function() UI.relayout() end)
	UI.relayout()
	return gui
end

return UI
