-- COOKIE OVERDRIVE — kit UI partagé : jetons de design du site (couleurs, polices, boutons .btn),
-- images (Img + repli emoji), formatage des nombres « à la française », couleurs RGB animées.
-- ⚠️ L'API historique (K.new, K.colors, K.label, K.small, K.button, K.card, K.corner, K.stroke,
-- K.textStroke, K.pad, K.list, K.rgb, K.fmtTime, K.DISPLAY/BODY/BOLD) est utilisée par Minigames.lua :
-- ne pas la modifier, seulement ajouter.
local RS = game:GetService("ReplicatedStorage")
local D = require(RS:WaitForChild("Shared"):WaitForChild("GameData"))

local K = {}

---------------------------------------------------------------------------- images (Img.lua, écrit par un autre module)
local function stubImg()
	return {
		has = function(_key: string): boolean return false end,
		size = function(_key: string): Vector2 return Vector2.new(1, 1) end,
		set = function(_obj: Instance, _key: string): boolean return false end,
		preload = function(_prefixes: { string }?) end,
	}
end
local Img: any = nil
do
	local mod = script.Parent:WaitForChild("Img", 15)
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		if ok and type(res) == "table" then Img = res else warn("[Cookie] Img.lua n'a pas pu être chargé : " .. tostring(res)) end
	else
		warn("[Cookie] Img.lua introuvable : les emojis remplacent les images")
	end
	if not Img then Img = stubImg() end
end
K.Img = Img

function K.hasImg(key: string): boolean
	local ok, r = pcall(Img.has, key)
	return ok and r == true
end

-- Applique l'image `key` sur un ImageLabel/ImageButton. false si indisponible (l'objet n'est pas modifié).
function K.trySet(obj: Instance, key: string): boolean
	local ok, r = pcall(Img.set, obj, key)
	return ok and r == true
end

function K.preload(prefixes: { string })
	task.spawn(function()
		pcall(Img.preload, prefixes)
	end)
end

---------------------------------------------------------------------------- couleurs & polices
K.colors = {
	bg = Color3.fromHex("#0b0620"), panel = Color3.fromHex("#160b34"), panel2 = Color3.fromHex("#22124a"),
	ink = Color3.fromHex("#fff6fe"), muted = Color3.fromHex("#b3a6dd"), stroke = Color3.fromHex("#1a0b33"),
	hot = Color3.fromHex("#ff2bd6"), cyan = Color3.fromHex("#1ff4ff"), lime = Color3.fromHex("#b6ff3b"),
	gold = Color3.fromHex("#ffc93c"), red = Color3.fromHex("#ff4d6d"), violet = Color3.fromHex("#8a5cff"),
	green = Color3.fromHex("#2bdc6a"),
	-- ajouts (jetons de base.css)
	dim = Color3.fromHex("#7d6fae"), orange = Color3.fromHex("#ff8a1f"), panelSolid = Color3.fromHex("#1a0d3d"),
	pink = Color3.fromHex("#ff8a9c"), cream = Color3.fromHex("#ffe2b0"), white = Color3.new(1, 1, 1), black = Color3.new(0, 0, 0),
	softInk = Color3.fromHex("#e5dcff"), lilac = Color3.fromHex("#e8dcff"), fxInk = Color3.fromHex("#e0d6ff"),
}
local Cc = K.colors
K.C = Cc

-- Anciennes polices (Enum.Font) — utilisées par Minigames.lua
K.DISPLAY = Enum.Font.FredokaOne
K.BODY = Enum.Font.GothamMedium
K.BOLD = Enum.Font.GothamBold

-- Polices du site : Lilita One → Fredoka One, Fredoka → Nunito, Chakra Petch → Sarpanch
K.F = {
	display = Font.new("rbxasset://fonts/families/FredokaOne.json"),
	body = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.SemiBold),
	medium = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Medium),
	bold = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold),
	heavy = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold),
	num = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Bold),
	numSemi = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.SemiBold),
}
local F = K.F

---------------------------------------------------------------------------- création d'instances (API historique)
function K.new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local o = Instance.new(class)
	local parent = nil
	for k, v in (props or {}) :: { [string]: any } do
		if k == "Parent" then parent = v else (o :: any)[k] = v end
	end
	for _, c in (children or {}) :: { Instance } do c.Parent = o end
	if parent then o.Parent = parent end
	return o
end
local new = K.new

function K.corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 12) }) end
function K.stroke(color, th) return new("UIStroke", { Color = color or Cc.stroke, Thickness = th or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
function K.textStroke(color, th) return new("UIStroke", { Color = color or Cc.stroke, Thickness = th or 2 }) end
function K.pad(p) return new("UIPadding", { PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p), PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p) }) end
function K.list(pad, dir, align)
	return new("UIListLayout", { Padding = UDim.new(0, pad or 6), FillDirection = dir or Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = align or Enum.HorizontalAlignment.Center })
end

-- Texte « Roblox » : gros, blanc, contour sombre
function K.label(text, size, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Text = text, Font = K.DISPLAY, TextSize = size or 20,
		TextColor3 = Cc.ink, Size = UDim2.new(1, 0, 0, (size or 20) + 6), TextWrapped = true,
	}, { K.textStroke() })
	for k, v in (props or {}) :: { [string]: any } do l[k] = v end
	return l
end

function K.small(text, size, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Text = text, Font = K.BODY, TextSize = size or 14,
		TextColor3 = Cc.muted, Size = UDim2.new(1, 0, 0, (size or 14) + 4), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for k, v in (props or {}) :: { [string]: any } do l[k] = v end
	return l
end

-- Bouton simple (ombre dessous) ; color = Color3
function K.button(text, color, props, onClick)
	local b = new("TextButton", {
		Text = text, Font = K.DISPLAY, TextSize = 18, TextColor3 = Cc.ink,
		BackgroundColor3 = color or Cc.green, AutoButtonColor = true, Size = UDim2.new(0, 120, 0, 40),
	}, { K.corner(10), K.stroke(Cc.stroke, 3), K.textStroke(Cc.stroke, 2) })
	for k, v in (props or {}) :: { [string]: any } do b[k] = v end
	if onClick then
		b.MouseButton1Click:Connect(function()
			local s = b.Size
			b.Size = UDim2.new(s.X.Scale * 0.95, s.X.Offset * 0.95, s.Y.Scale * 0.95, s.Y.Offset * 0.95)
			task.delay(0.08, function() b.Size = s end)
			onClick(b)
		end)
	end
	return b
end

function K.card(props, children)
	local f = new("Frame", { BackgroundColor3 = Cc.panel2, Size = UDim2.new(1, 0, 0, 70) }, { K.corner(12), K.stroke(Cc.stroke, 2), K.pad(8) })
	for k, v in (props or {}) :: { [string]: any } do f[k] = v end
	for _, c in (children or {}) :: { Instance } do c.Parent = f end
	return f
end

function K.rgb(t, off)
	return Color3.fromHSV(((t or os.clock()) * 0.12 + (off or 0)) % 1, 0.85, 1)
end

function K.fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	if sec >= 3600 then return string.format("%dh%02d", sec // 3600, (sec % 3600) // 60) end
	return string.format("%d:%02d", sec // 60, sec % 60)
end

---------------------------------------------------------------------------- maths & easing (stage.js)
function K.clamp(v: number, a: number, b: number): number
	if v < a then return a elseif v > b then return b end
	return v
end
local clamp = K.clamp
function K.lerp(a: number, b: number, t: number): number return a + (b - a) * t end
function K.rand(a: number, b: number): number return a + math.random() * (b - a) end
function K.easeOutCubic(t: number): number t = clamp(t, 0, 1); return 1 - (1 - t) ^ 3 end
function K.easeInOut(t: number): number
	t = clamp(t, 0, 1)
	if t < 0.5 then return 2 * t * t end
	return 1 - ((-2 * t + 2) ^ 2) / 2
end
function K.easeOutBack(t: number): number
	local s = 1.9
	t = clamp(t, 0, 1) - 1
	return t * t * ((s + 1) * t + s) + 1
end
function K.elasticOut(t: number): number
	t = clamp(t, 0, 1)
	if t == 0 or t == 1 then return t end
	return 2 ^ (-10 * t) * math.sin(((t - 0.075) * math.pi * 2) / 0.3) + 1
end
function K.bounceOut(t: number): number
	t = clamp(t, 0, 1)
	local n, d = 7.5625, 2.75
	if t < 1 / d then return n * t * t end
	if t < 2 / d then t -= 1.5 / d; return n * t * t + 0.75 end
	if t < 2.5 / d then t -= 2.25 / d; return n * t * t + 0.9375 end
	t -= 2.625 / d
	return n * t * t + 0.984375
end

---------------------------------------------------------------------------- RGB global (--h du site)
-- La teinte avance de 60°/s (×2,2 pendant la Fièvre), comme CO.hue().
K.H = 300
function K.stepHue(dt: number, fever: boolean)
	K.H = (K.H + dt * 60 * (fever and 2.2 or 1)) % 360
end
function K.hue(offset: number?): number
	return (K.H + (offset or 0)) % 360
end
-- hsl(h°, s 0..1, l 0..1) → Color3 (même rendu que le CSS hsl())
function K.hsl(h: number, s: number?, l: number?): Color3
	local S, L = s or 1, l or 0.62
	local hh = (h % 360) / 360
	if S <= 0 then return Color3.new(L, L, L) end
	local q = L < 0.5 and L * (1 + S) or L + S - L * S
	local p = 2 * L - q
	local function f(t: number): number
		t %= 1
		if t < 1 / 6 then return p + (q - p) * 6 * t end
		if t < 0.5 then return q end
		if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
		return p
	end
	return Color3.new(f(hh + 1 / 3), f(hh), f(hh - 1 / 3))
end
-- couleur d'accent du site : hsl(var(--h) 100% 62%)
function K.acc(offset: number?): Color3 return K.hsl(K.hue(offset), 1, 0.62) end

-- dégradé conique du site (#ff004c → … → #ff004c)
local RAINBOW = { "#ff004c", "#ff8a00", "#ffe600", "#2bff88", "#00d5ff", "#7a5cff", "#ff2bd6", "#ff004c" }
function K.rainbowSeq(): ColorSequence
	local ks = {}
	for i, hex in RAINBOW do table.insert(ks, ColorSequenceKeypoint.new((i - 1) / (#RAINBOW - 1), Color3.fromHex(hex))) end
	return ColorSequence.new(ks)
end
-- dégradé de teintes décalées (texte flottant arc-en-ciel)
function K.hueSeq(h0: number, span: number?, l: number?): ColorSequence
	local ks = {}
	for i = 0, 4 do table.insert(ks, ColorSequenceKeypoint.new(i / 4, K.hsl(h0 + i * (span or 55), 1, l or 0.62))) end
	return ColorSequence.new(ks)
end

function K.hex(c: Color3): string return "#" .. c:ToHex() end

function K.darken(c: Color3, v: number): Color3
	local h, s, vv = c:ToHSV()
	return Color3.fromHSV(h, s, vv * v)
end
function K.gray(c: Color3): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s * 0.15, v * 0.7)
end

---------------------------------------------------------------------------- nombres (CO.fmt du site, format court)
local SUF = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "UDc", "DDc", "TDc" }
local function dec(x: number, d: number): string
	local s = string.format("%." .. d .. "f", x)
	if string.find(s, "%.") then s = string.gsub(string.gsub(s, "0+$", ""), "%.$", "") end
	return (string.gsub(s, "%.", ","))
end
local function spaced(n: number): string
	local s = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1 ")))
	return (string.gsub(out, "^ ", ""))
end
function K.fmt(n: number?, int: boolean?): string
	local x = tonumber(n) or 0
	if x ~= x then return "0" end
	if x == math.huge then return "∞" end
	local neg = x < 0
	x = math.abs(x)
	local s
	if x < 1000 then
		s = (x < 100 and x % 1 ~= 0 and not int) and dec(x, 1) or spaced(x)
	else
		local e = math.floor(math.log10(x) / 3)
		if e >= #SUF then
			local p = math.floor(math.log10(x))
			s = dec(x / 10 ^ p, 2) .. "e" .. p
		else
			local v = x / 1000 ^ e
			s = dec(v, v >= 100 and 0 or v >= 10 and 1 or 2) .. " " .. SUF[e + 1]
		end
	end
	return (neg and "-" or "") .. s
end
function K.fmtInt(n: number?): string return K.fmt(math.floor(tonumber(n) or 0), true) end
-- CO.fmtTime : « 12 s », « 3 min 05 », « 1 h 05 »
function K.fmtDur(sec: number): string
	sec = math.max(0, math.floor(sec + 0.5))
	local h, m, s = sec // 3600, (sec % 3600) // 60, sec % 60
	if h > 0 then return h .. " h " .. string.format("%02d", m) end
	if m > 0 then return m .. " min " .. string.format("%02d", s) end
	return s .. " s"
end

---------------------------------------------------------------------------- emojis de secours (si une image manque)
local EMO: { [string]: string } = {
	["ui:cookie"] = "🍪", ["ui:golden"] = "🍪", ["ui:gem"] = "💎", ["ui:star"] = "⭐", ["ui:heart"] = "❤️", ["ui:heart_empty"] = "🤍",
	["ui:lock"] = "🔒", ["ui:trophy"] = "🏆", ["ui:play"] = "▶", ["ui:dice"] = "🎲", ["ui:close"] = "✖", ["ui:check"] = "✔",
	["ui:clock"] = "⏰", ["ui:gift"] = "🎁", ["ui:save"] = "💾", ["ui:home"] = "🏠", ["ui:sparkle"] = "✨", ["ui:fire"] = "🔥",
	["ui:bolt"] = "⚡", ["ui:tornado"] = "🌪️", ["ui:sword"] = "⚔️", ["ui:crown"] = "👑", ["ui:chart"] = "📊", ["ui:cursor"] = "👆",
	["ui:tap"] = "👆", ["ui:rainbow"] = "🌈", ["ui:moon"] = "🌙", ["ui:warning"] = "⚠️", ["ui:search"] = "🔍", ["ui:skull"] = "💀",
	["ui:music"] = "🎵", ["ui:sound"] = "🔊", ["ui:mute"] = "🔇",
	["tab:shop"] = "🏭", ["tab:upgrades"] = "⚡", ["tab:games"] = "🎮", ["tab:pets"] = "🥚", ["tab:style"] = "🎨",
	["tab:quests"] = "📜", ["tab:rebirth"] = "🔄", ["tab:options"] = "⚙️",
	["egg:basic"] = "🥚", ["egg:neon"] = "🥚", ["egg:cosmic"] = "🥚", ["golden"] = "🍪",
	["item:broccoli"] = "🥦", ["item:milk"] = "🥛", ["item:choco"] = "🍫", ["item:donut"] = "🍩", ["item:cupcake"] = "🧁", ["item:seven"] = "7️⃣",
}
for _, b in D.buildings do EMO["b:" .. b.id] = b.emoji end
for _, p in D.pets do EMO["pet:" .. p.id] = p.emoji end
for _, b in D.bosses do EMO["boss:" .. b.id] = b.emoji end
for _, m in D.minigames do EMO["mg:" .. m.id] = m.emoji end
function K.emoji(key: string): string
	local e = EMO[key]
	if e then return e end
	if string.sub(key, 1, 4) == "vis:" then return "✨" end
	if string.sub(key, 1, 7) == "cookie:" then return "🍪" end
	return ""
end

-- Met l'image `key` sur `obj` ; sinon un emoji (TextLabel enfant « Fallback ») prend sa place.
function K.setImg(obj: any, key: string, emoji: string?): boolean
	local fb = obj:FindFirstChild("Fallback")
	if K.trySet(obj, key) then
		if fb then fb:Destroy() end
		obj.ImageTransparency = obj:GetAttribute("imgT") or 0
		return true
	end
	-- aucune image : on masque l'ancienne et on affiche l'emoji
	obj:SetAttribute("imgT", obj.ImageTransparency)
	obj.ImageTransparency = 1
	local e = emoji or K.emoji(key)
	if e ~= "" then
		if not fb then
			fb = new("TextLabel", {
				Name = "Fallback", BackgroundTransparency = 1, Size = UDim2.fromScale(0.86, 0.86), Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5), TextScaled = true, FontFace = F.bold, TextColor3 = Cc.white, ZIndex = obj.ZIndex, Parent = obj,
			})
		end
		fb.Text = e
	elseif fb then
		fb:Destroy()
	end
	return false
end

-- ImageLabel avec image (ou emoji de secours)
function K.img(key: string?, props: { [string]: any }?, emoji: string?): ImageLabel
	local o = new("ImageLabel", { BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(24, 24) })
	for k, v in (props or {}) :: { [string]: any } do
		if k ~= "Parent" then (o :: any)[k] = v end
	end
	if key then K.setImg(o, key, emoji) end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end

---------------------------------------------------------------------------- textes
function K.txt(text: string, size: number, font: Font?, color: Color3?, props: { [string]: any }?): TextLabel
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = font or F.body, TextColor3 = color or Cc.ink,
		Size = UDim2.new(1, 0, 0, math.ceil(size * 1.25)), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
	})
	for k, v in (props or {}) :: { [string]: any } do
		if k ~= "Parent" then (l :: any)[k] = v end
	end
	if props and props.Parent then l.Parent = props.Parent end
	return l
end
-- contour épais sombre (.ol du site)
function K.ol(obj: any, th: number?, color: Color3?): any
	new("UIStroke", { Color = color or Cc.stroke, Thickness = th or 2, LineJoinMode = Enum.LineJoinMode.Round, Parent = obj })
	return obj
end
-- texte .ol : police display, blanc, contour
function K.olTxt(text: string, size: number, props: { [string]: any }?): TextLabel
	local l = K.txt(text, size, F.display, Cc.ink, props)
	K.ol(l, math.max(1.5, size * 0.09))
	return l
end

function K.round(obj: Instance, r: number?): Instance
	new("UICorner", { CornerRadius = r and UDim.new(0, r) or UDim.new(1, 0), Parent = obj })
	return obj
end
function K.border(obj: Instance, color: Color3?, th: number?, tr: number?): UIStroke
	return new("UIStroke", { Color = color or Cc.stroke, Thickness = th or 3, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = obj })
end
function K.grad(obj: Instance, c1: Color3, c2: Color3, rot: number?): UIGradient
	return new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rot or 90, Parent = obj })
end
function K.padding(obj: Instance, t: number, r: number?, b: number?, l: number?): UIPadding
	return new("UIPadding", {
		PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r or t), PaddingBottom = UDim.new(0, b or t), PaddingLeft = UDim.new(0, l or r or t), Parent = obj,
	})
end
function K.hlist(obj: Instance, gap: number?, halign: Enum.HorizontalAlignment?, valign: Enum.VerticalAlignment?): UIListLayout
	return new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, gap or 6), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left, VerticalAlignment = valign or Enum.VerticalAlignment.Center, Parent = obj,
	})
end
function K.vlist(obj: Instance, gap: number?, halign: Enum.HorizontalAlignment?): UIListLayout
	return new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, gap or 6), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left, Parent = obj,
	})
end

---------------------------------------------------------------------------- bouton .btn du site (dégradé, contour, ombre portée)
K.BTN = {
	violet = { "#7a5cff", "#5a3de0", "#3a22a8" }, green = { "#4dff8a", "#1fc85a", "#0f8a3a" }, pink = { "#ff6be6", "#ff2bd6", "#b0108f" },
	gold = { "#ffe066", "#ffb800", "#c07a00" }, cyan = { "#7ffaff", "#1fd6ff", "#0a8fb8" }, red = { "#ff8095", "#ff3d5e", "#b3142f" },
	dark = { "#3a2a70", "#2a1b58", "#170d38" },
}
local function btnSeq(kind: string, off: boolean): ColorSequence
	local c = K.BTN[kind] or K.BTN.violet
	local c1, c2, c3 = Color3.fromHex(c[1]), Color3.fromHex(c[2]), Color3.fromHex(c[3])
	if off then c1, c2, c3 = K.gray(c1), K.gray(c2), K.gray(c3) end
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, c1:Lerp(Color3.new(1, 1, 1), 0.25)), ColorSequenceKeypoint.new(0.1, c1),
		ColorSequenceKeypoint.new(0.8, c2), ColorSequenceKeypoint.new(0.86, c3), ColorSequenceKeypoint.new(1, c3),
	})
end

export type Btn = {
	root: Frame, face: TextButton, label: TextLabel, icon: ImageLabel?, kind: string, off: boolean,
	setKind: (self: Btn, kind: string) -> (), setOff: (self: Btn, off: boolean) -> (), setText: (self: Btn, t: string) -> (),
}

-- opts : size (UDim2), textSize, small, big, icon (clé), iconAfter (bool), layoutOrder, parent, zindex, onClick
function K.btn(text: string, kind: string?, opts: { [string]: any }?): Btn
	local o = opts or {}
	local small, big = o.small == true, o.big == true
	local ts = o.textSize or (small and 14 or big and 24 or 17)
	local radius = small and 11 or big and 18 or 14
	local drop = small and 3 or 4
	local root = new("Frame", {
		BackgroundTransparency = 1, Size = o.size or UDim2.fromOffset(120, small and 32 or big and 58 or 42),
		LayoutOrder = o.layoutOrder or 0, ZIndex = o.zindex or 1, AnchorPoint = o.anchor or Vector2.zero, Position = o.position or UDim2.new(),
	})
	local z = o.zindex or 1
	new("Frame", {
		Name = "Drop", BackgroundColor3 = Cc.stroke, Position = UDim2.fromOffset(0, drop), Size = UDim2.new(1, 0, 1, -drop), ZIndex = z, Parent = root,
	}, { new("UICorner", { CornerRadius = UDim.new(0, radius) }) })
	local face = new("TextButton", {
		Name = "Face", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 1, -drop), ZIndex = z + 1, Parent = root,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, radius) }),
		new("UIStroke", { Color = Cc.stroke, Thickness = small and 2 or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		new("UIGradient", { Name = "G", Rotation = 90, Color = btnSeq(kind or "violet", false) }),
	})
	local content = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 2, Parent = face })
	K.hlist(content, 5, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local icon: ImageLabel? = nil
	if o.icon then
		local is = math.floor(ts * 1.25)
		icon = K.img(o.icon, { Size = UDim2.fromOffset(is, is), LayoutOrder = o.iconAfter and 3 or 1, ZIndex = z + 3, Parent = content })
	end
	local label = K.txt(text, ts, F.display, Cc.white, {
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2, ZIndex = z + 3, Parent = content, RichText = true,
	})
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.6, Parent = label })
	if text == "" then label.Visible = false end
	local b: any = { root = root, face = face, label = label, icon = icon, kind = kind or "violet", off = false }
	function b.setKind(self: Btn, k: string)
		if self.kind == k then return end
		self.kind = k
		local g = self.face:FindFirstChild("G") :: UIGradient
		g.Color = btnSeq(k, self.off)
	end
	function b.setOff(self: Btn, off: boolean)
		if self.off == off then return end
		self.off = off
		local g = self.face:FindFirstChild("G") :: UIGradient
		g.Color = btnSeq(self.kind, off)
		self.label.TextTransparency = off and 0.25 or 0
	end
	function b.setText(self: Btn, t: string)
		if self.label.Text ~= t then self.label.Text = t end
		self.label.Visible = t ~= ""
	end
	-- appui : la face descend sur son ombre
	face.MouseButton1Down:Connect(function() face.Position = UDim2.fromOffset(0, drop - 1) end)
	face.MouseButton1Up:Connect(function() face.Position = UDim2.new() end)
	face.MouseLeave:Connect(function() face.Position = UDim2.new() end)
	if o.onClick then
		face.Activated:Connect(function()
			face.Position = UDim2.new()
			o.onClick(b)
		end)
	end
	if o.parent then root.Parent = o.parent end
	return b :: Btn
end

---------------------------------------------------------------------------- couleurs vivantes (--h du site)
-- Objets dont la couleur suit la teinte globale : mis à jour une fois par image par K.stepLive().
-- accBind(obj, "BackgroundColor3", décalage, luminosité, saturation) · seqBind(UIGradient, {décalages}, lum)
-- spinBind(UIGradient, °/s) : dégradé arc-en-ciel qui tourne (bord RGB) · rgbBind(UIStroke) : bordure .rgbc
local accReg: { [Instance]: { any } } = setmetatable({}, { __mode = "k" }) :: any
local seqReg: { [Instance]: { any } } = setmetatable({}, { __mode = "k" }) :: any
local spinReg: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local rgbReg: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
function K.accBind(obj: Instance, prop: string, off: number?, l: number?, sat: number?)
	local e = { prop, off or 0, l or 0.62, sat or 1 }
	accReg[obj] = e;
	(obj :: any)[prop] = K.hsl(K.hue(e[2]), e[4], e[3])
end
function K.accUnbind(obj: Instance) accReg[obj] = nil end
function K.seqBind(g: UIGradient, offs: { number }, l: number?)
	seqReg[g] = { offs, l or 0.6 }
end
function K.seqUnbind(g: UIGradient) seqReg[g] = nil end
function K.spinBind(g: UIGradient, speed: number?)
	g.Color = K.rainbowSeq()
	spinReg[g] = speed or 60
end
local RGBC = { "#ff004c", "#ffe600", "#2bff88", "#00d5ff", "#ff2bd6", "#ff004c" }
local RGBC3: { Color3 } = {}
for i, h in RGBC do RGBC3[i] = Color3.fromHex(h) end
function K.rgbBind(st: Instance, off: number?) rgbReg[st] = off or 0 end
function K.rgbUnbind(st: Instance) rgbReg[st] = nil end
local liveT = 0
function K.stepLive(dt: number)
	liveT += dt
	for obj, e in accReg do
		if obj.Parent then (obj :: any)[e[1]] = K.hsl(K.hue(e[2]), e[4], e[3]) end
	end
	for g, e in seqReg do
		if g.Parent then
			local ks = {}
			local n = #e[1]
			for i, o in e[1] do ks[i] = ColorSequenceKeypoint.new(n == 1 and 0 or (i - 1) / (n - 1), K.hsl(K.hue(o), 1, e[2])) end
			if n == 1 then ks[2] = ColorSequenceKeypoint.new(1, ks[1].Value) end
			(g :: UIGradient).Color = ColorSequence.new(ks)
		end
	end
	-- conic-gradient(from var(--h)) : la teinte avance → on fait tourner le dégradé
	local rot = K.H % 360
	for g, sp in spinReg do
		if g.Parent then (g :: UIGradient).Rotation = (rot + liveT * (sp - 60)) % 360 end
	end
	-- @keyframes rgbBorder (2 s, 5 couleurs)
	for st, off in rgbReg do
		if st.Parent then
			local p = ((liveT + off) / 2) % 1 * 5
			local i = math.floor(p)
			local sti: any = st
			sti.Color = RGBC3[i + 1]:Lerp(RGBC3[i + 2], p - i)
		end
	end
end

return K
