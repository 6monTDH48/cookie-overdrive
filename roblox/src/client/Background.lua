-- COOKIE OVERDRIVE — décor plein écran (thèmes de stage.js) :
-- image `bg:<thème>` (cadrée comme le canvas : soleil / point de fuite derrière le cookie, horizon à 63 %)
-- + couches animées en GUI : étoiles qui scintillent, grille synthwave qui défile, étoiles filantes,
-- pluie de glyphes (Matrice), bulles (Candy), braises (Inferno), vignette et teinte de Fièvre.
local K = require(script.Parent:WaitForChild("Kit"))
local new, C = K.new, K.C
local clamp, rand = K.clamp, K.rand

local B = {}
local ctx: any = nil
local root: Frame
local fallback: Frame, fallbackGrad: UIGradient
local imgA: ImageLabel, imgB: ImageLabel
local tint: Frame
local vig: { [string]: Frame } = {}
local vigGrad: UIGradient
local themeId = "synthwave"
local fadeT0 = -9
local layers: { [string]: any } = {}

-- Position dans l'image exportée du point placé sous le cookie (soleil / point de fuite), et de l'horizon.
-- L'exporteur peint le site dans une fenêtre 1400×787,5 : zone de jeu = 1400 − (clamp(33vw) + 22) = 916 px
-- → centre du cookie en x = 458 / 1400 ; horizon synthwave à 0,63 H.
B.IMG_CX = 458 / 1400
B.IMG_HZ = 0.63
B.IMG_ASPECT = 1024 / 576

-- dégradés « aperçu » du site (data.js themes[].preview) : repli si l'image manque + vignettes du Style
B.PREVIEW = {
	synthwave = { rot = 90, keys = { { 0, "#1a0536" }, { 0.45, "#6b1a8f" }, { 0.62, "#ff3d9a" }, { 0.63, "#120428" }, { 1, "#120428" } } },
	galaxy = { rot = 35, keys = { { 0, "#070214" }, { 0.3, "#5a26c8" }, { 0.5, "#140630" }, { 0.72, "#c02c7c" }, { 1, "#070214" } } },
	matrix = { rot = 90, keys = { { 0, "#012a14" }, { 0.5, "#01130a" }, { 1, "#010a06" } } },
	candy = { rot = 45, keys = { { 0, "#ffb3e6" }, { 0.5, "#b3e5ff" }, { 1, "#fff3b3" } } },
	inferno = { rot = -90, keys = { { 0, "#ff6a00" }, { 0.35, "#a0100a" }, { 0.75, "#1a0202" }, { 1, "#120101" } } },
	aurora = { rot = 80, keys = { { 0, "#021a1f" }, { 0.35, "#0bd6a0" }, { 0.6, "#5b3cff" }, { 1, "#02101a" } } },
}
function B.previewSeq(id: string): (ColorSequence, number)
	local p = B.PREVIEW[id] or B.PREVIEW.synthwave
	local ks = {}
	for _, k in p.keys do table.insert(ks, ColorSequenceKeypoint.new(k[1], Color3.fromHex(k[2]))) end
	return ColorSequence.new(ks), p.rot
end

---------------------------------------------------------------------------- aléatoire déterministe (Random avec graine)
local function seeded(seed: number): () -> number
	local r = Random.new(seed)
	return function(): number return r:NextNumber() end
end
local STARS = {}
do
	local rng = seeded(2024)
	for _ = 1, 160 do table.insert(STARS, { x = rng(), y = rng(), s = 0.5 + rng() * 1.6, ph = rng() * math.pi * 2, l = math.floor(rng() * 3) }) end
end

local function dot(parent: Instance, z: number): Frame
	return new("Frame", { BorderSizePixel = 0, BackgroundColor3 = C.white, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(2, 2), ZIndex = z, Parent = parent })
end

---------------------------------------------------------------------------- couches par thème
local build: { [string]: (Frame) -> any } = {}
local step: { [string]: (any, number, number) -> () } = {}

-- SYNTHWAVE : étoiles + sol recouvert d'une grille néon qui défile vers le joueur
build.synthwave = function(f)
	local L = { stars = {}, v = {}, h = {} }
	for i = 1, 70 do
		local s = STARS[i]
		if s.y <= 0.55 then table.insert(L.stars, { d = dot(f, 2), s = s }) end
	end
	L.floor = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = C.white, ZIndex = 3, Parent = f }, {
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#2a0648"), Color3.fromHex("#06010e")) }),
	})
	L.grid = new("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 4, Parent = f })
	for i = -16, 16 do
		local glow = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0.82, ZIndex = 4, Parent = L.grid })
		local core = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0.12, ZIndex = 5, Parent = L.grid })
		table.insert(L.v, { i = i, glow = glow, core = core })
	end
	for _ = 1, 26 do
		local glow = new("Frame", { BorderSizePixel = 0, BackgroundTransparency = 0.82, ZIndex = 4, Parent = L.grid })
		local core = new("Frame", { BorderSizePixel = 0, BackgroundTransparency = 0.12, ZIndex = 5, Parent = L.grid })
		table.insert(L.h, { glow = glow, core = core })
	end
	-- lueur rose à l'horizon + ombre sous l'horizon
	L.haze = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(255, 80, 190), ZIndex = 6, Parent = f }, {
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.55), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	L.shade = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(6, 1, 14), ZIndex = 6, Parent = f }, {
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.3, 1) }),
	})
	return L
end
step.synthwave = function(L, t, _dt)
	local W, H, CX = ctx.W, ctx.H, ctx.CX
	local hz = H * 0.63
	for _, e in L.stars do
		local s = e.s
		e.d.Position = UDim2.fromOffset(s.x * W, s.y * hz)
		e.d.Size = UDim2.fromOffset(math.max(1.5, s.s * 1.2), math.max(1.5, s.s * 1.2))
		e.d.BackgroundTransparency = 1 - (0.3 + 0.5 * math.abs(math.sin(t * 1.3 + s.ph)))
	end
	L.floor.Position = UDim2.fromOffset(0, hz)
	L.floor.Size = UDim2.fromOffset(W, H - hz + 2)
	L.grid.Position = UDim2.fromOffset(0, hz)
	L.grid.Size = UDim2.fromOffset(W, H - hz + 2)
	local col = K.hsl(K.hue(290), 1, 0.62)
	local gh = H - hz
	if L.lastW ~= W or L.lastH ~= H or L.lastCX ~= CX then
		L.lastW, L.lastH, L.lastCX = W, H, CX
		for _, v in L.v do
			local x0, x1 = CX + v.i * 14, CX + v.i * W * 0.1
			local dx, dy = x1 - x0, gh
			local len = math.sqrt(dx * dx + dy * dy)
			local mid = UDim2.fromOffset((x0 + x1) / 2, gh / 2)
			local rot = math.deg(math.atan2(dy, dx))
			v.glow.Position, v.glow.Size, v.glow.Rotation = mid, UDim2.fromOffset(len, 5), rot
			v.core.Position, v.core.Size, v.core.Rotation = mid, UDim2.fromOffset(len, 1.6), rot
		end
	end
	for _, v in L.v do
		v.glow.BackgroundColor3 = col
		v.core.BackgroundColor3 = col
	end
	local spd = ctx.fever and 2.4 or 0.55
	local frac = (t * spd) % 1
	local camH = gh * 1.1
	for k, h in L.h do
		local d = k - frac
		local y = d > 0.2 and camH / (d * 0.9) or math.huge
		if y <= gh then
			h.glow.Visible, h.core.Visible = true, true
			h.glow.Position, h.glow.Size = UDim2.fromOffset(0, y - 2.5), UDim2.fromOffset(W, 5)
			h.core.Position, h.core.Size = UDim2.fromOffset(0, y - 0.8), UDim2.fromOffset(W, 1.6)
			h.glow.BackgroundColor3 = col
			h.core.BackgroundColor3 = col
		else
			h.glow.Visible, h.core.Visible = false, false
		end
	end
	L.haze.Position = UDim2.fromOffset(0, hz - 30)
	L.haze.Size = UDim2.fromOffset(W, 70)
	L.shade.Position = UDim2.fromOffset(0, hz)
	L.shade.Size = UDim2.fromOffset(W, gh * 0.35)
end

-- NÉBULEUSE : champ d'étoiles en parallaxe + étoile filante
build.galaxy = function(f)
	local L = { stars = {} }
	for i = 1, 120 do table.insert(L.stars, { d = dot(f, 2), s = STARS[i] }) end
	L.shoot = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(220, 240, 255), AnchorPoint = Vector2.new(1, 0.5), Visible = false, ZIndex = 3, Parent = f }, {
		new("UIGradient", { Transparency = NumberSequence.new(1, 0) }),
	})
	return L
end
step.galaxy = function(L, t, _dt)
	local W, H = ctx.W, ctx.H
	for _, e in L.stars do
		local s = e.s
		local Lv = s.l + 1
		local x = (s.x * W + t * 4 * Lv) % W
		local y = (s.y * H) % H
		local z = s.s * (0.6 + Lv * 0.35) + 0.6
		e.d.Position = UDim2.fromOffset(x, y)
		e.d.Size = UDim2.fromOffset(z, z)
		e.d.BackgroundTransparency = 1 - (0.25 + 0.75 * math.abs(math.sin(t * (0.6 + s.l * 0.5) + s.ph)))
	end
	local sp = (t * 0.23) % 1
	if sp < 0.12 then
		local si = math.floor(t * 0.23)
		local rng = seeded(si * 13 + 1)
		local x0, y0, k = rng() * W, rng() * H * 0.4, sp / 0.12
		local x, y = x0 + k * 300, y0 + k * 120
		L.shoot.Visible = true
		L.shoot.Position = UDim2.fromOffset(x, y)
		L.shoot.Size = UDim2.fromOffset(97, 2)
		L.shoot.Rotation = math.deg(math.atan2(36, 90))
		L.shoot.BackgroundTransparency = k
	else
		L.shoot.Visible = false
	end
end

-- AURORE : étoiles qui scintillent (les rubans sont dans l'image)
build.aurora = function(f)
	local L = { stars = {} }
	for i = 1, 110 do
		local s = STARS[i]
		if s.y <= 0.75 then table.insert(L.stars, { d = dot(f, 2), s = s }) end
	end
	return L
end
step.aurora = function(L, t, _dt)
	local W, H = ctx.W, ctx.H
	for _, e in L.stars do
		local s = e.s
		e.d.Position = UDim2.fromOffset(s.x * W, s.y * H)
		e.d.Size = UDim2.fromOffset(math.max(1.2, s.s), math.max(1.2, s.s))
		e.d.BackgroundTransparency = 1 - (0.2 + 0.6 * math.abs(math.sin(t * 0.9 + s.ph)))
	end
end

-- MATRICE SUCRÉE : colonnes de glyphes qui tombent
local GLYPHS = {}
for _, cp in { 0x30A2, 0x30A4, 0x30A6, 0x30A8, 0x30AA, 0x30AB, 0x30AD, 0x30AF, 0x30B1, 0x30B3, 0x30B5, 0x30B7, 0x30B9, 0x30BB, 0x30BD, 0x30BF, 0x30C1, 0x30C4, 0x30C6, 0x30C8, 0x30CA, 0x30CB, 0x30CC, 0x30CD, 0x30CE, 0x30CF, 0x30D2, 0x30D5, 0x30D8, 0x30DB, 0x30DE, 0x30DF, 0x30E0, 0x30E1, 0x30E2, 0x30E4, 0x30E6, 0x30E8, 0x30E9, 0x30EA, 0x30EB, 0x30EC, 0x30ED, 0x30EF, 0x30F3 } do
	table.insert(GLYPHS, utf8.char(cp))
end
for d = 0, 9 do table.insert(GLYPHS, tostring(d)) end
local function glyph(): string return GLYPHS[math.random(#GLYPHS)] end

build.matrix = function(f)
	local L = { cols = {}, acc = 0 }
	for i = 1, 26 do
		local lab = new("TextLabel", {
			BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(0, 255, 136), FontFace = K.F.num, TextSize = 16, RichText = true,
			TextYAlignment = Enum.TextYAlignment.Bottom, TextXAlignment = Enum.TextXAlignment.Center, LineHeight = 1, ZIndex = 2, Parent = f,
		}, { new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.15) }) })
		local c = { l = lab, y = -math.random(0, 20), chars = {}, x = (i - 0.5) / 26, speed = rand(0.8, 1.4), acc = 0 }
		for _ = 1, 16 do table.insert(c.chars, glyph()) end
		table.insert(L.cols, c)
	end
	return L
end
step.matrix = function(L, _t, dt)
	local W, H = ctx.W, ctx.H
	local cell = 18
	local rows = math.ceil(H / cell) + 16
	for _, c in L.cols do
		c.acc += dt * c.speed * (ctx.fever and 2 or 1)
		local moved = false
		while c.acc > 0.06 do
			c.acc -= 0.06
			c.y += 1
			table.remove(c.chars, 1)
			table.insert(c.chars, glyph())
			moved = true
			if c.y > rows then c.y = -math.random(0, 12) end
		end
		if moved or c.l.Text == "" then
			local head = c.chars[#c.chars]
			c.l.Text = table.concat(c.chars, "\n", 1, #c.chars - 1) .. '\n<font color="#d8ffe8">' .. head .. "</font>"
		end
		c.l.TextSize = cell - 2
		c.l.Size = UDim2.fromOffset(cell + 4, cell * 16)
		c.l.Position = UDim2.fromOffset(c.x * W - cell / 2, c.y * cell - cell * 16)
	end
end

-- CANDY POP : bulles qui montent
build.candy = function(f)
	local L = { b = {} }
	for i = 1, 20 do
		local r = rand(8, 34)
		local fr = new("Frame", { BackgroundColor3 = C.white, BackgroundTransparency = 0.86, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(r * 2, r * 2), ZIndex = 2, Parent = f }, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			new("UIStroke", { Color = C.white, Transparency = 0.45, Thickness = 1.5 }),
		})
		table.insert(L.b, { f = fr, x = math.random(), y = math.random(), sp = rand(12, 40), ph = math.random() * math.pi * 2, i = i })
	end
	return L
end
step.candy = function(L, t, dt)
	local W, H = ctx.W, ctx.H
	for _, b in L.b do
		b.y -= b.sp * dt / H
		if b.y < -0.1 then b.y = 1.1; b.x = math.random() end
		b.f.Position = UDim2.fromOffset(b.x * W + math.sin(t * 0.8 + b.ph) * 18, b.y * H)
	end
end

-- INFERNO : braises qui s'élèvent
build.inferno = function(f)
	local L = { e = {} }
	local hasGlow = K.hasImg("fx:glow")
	for i = 1, 45 do
		local o: GuiObject
		if hasGlow then
			local im = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2, Parent = f })
			K.trySet(im, "fx:glow")
			im.ImageColor3 = i % 3 == 0 and Color3.fromHex("#ffd23c") or Color3.fromHex("#ff7a1a")
			o = im
		else
			o = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromHex("#ff7a1a"), ZIndex = 2, Parent = f }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
		table.insert(L.e, { o = o, img = hasGlow, x = math.random(), y = math.random(), sp = rand(30, 110), s = rand(3, 9), ph = math.random() * math.pi * 2 })
	end
	return L
end
step.inferno = function(L, t, dt)
	local W, H = ctx.W, ctx.H
	for _, e in L.e do
		e.y -= e.sp * dt * (ctx.fever and 2 or 1) / H
		if e.y < -0.05 then e.y = 1.05; e.x = math.random() end
		local a = clamp(e.y * 1.4, 0, 1) * (0.6 + 0.4 * math.sin(t * 7 + e.ph))
		local s = e.img and e.s * 3.2 or e.s
		e.o.Position = UDim2.fromOffset(e.x * W + math.sin(t * 1.5 + e.ph) * 20, e.y * H)
		e.o.Size = UDim2.fromOffset(s, s)
		if e.img then (e.o :: ImageLabel).ImageTransparency = 1 - a else e.o.BackgroundTransparency = 1 - a end
	end
end

---------------------------------------------------------------------------- image de fond cadrée
local function placeImage(im: ImageLabel)
	local W, H, CX = ctx.W, ctx.H, ctx.CX
	-- l'image doit couvrir l'écran avec son point (IMG_CX, IMG_HZ) posé en (CX, 0,63·H)
	local needW = math.max(CX / B.IMG_CX, (W - CX) / (1 - B.IMG_CX))
	local h = math.max(H, needW / B.IMG_ASPECT)
	local w = h * B.IMG_ASPECT
	im.AnchorPoint = Vector2.new(B.IMG_CX, B.IMG_HZ)
	im.Position = UDim2.fromOffset(CX, H * 0.63)
	im.Size = UDim2.fromOffset(w, h)
end

local function applyTheme(im: ImageLabel, id: string): boolean
	im.Image = ""
	return K.trySet(im, "bg:" .. id)
end

function B.setTheme(id: string)
	if id == themeId and imgA.Visible then return end
	local had = imgA.Visible
	themeId = id
	-- l'ancien fond reste dessous (imgA), le nouveau (imgB) apparaît en fondu
	if had then
		imgA, imgB = imgB, imgA
	end
	local ok = applyTheme(imgB, id)
	local seq, rot = B.previewSeq(id)
	fallbackGrad.Color, fallbackGrad.Rotation = seq, rot
	imgB.Visible = ok
	imgB.ImageTransparency = had and 1 or 0
	-- l'image exportée contient déjà la vignette du site : bords plus légers par-dessus
	for _, k in { "top", "bottom", "left", "right" } do vig[k].BackgroundTransparency = ok and 0.45 or 0 end
	imgB.ZIndex = 1
	imgA.ZIndex = 0
	fadeT0 = ctx.T
	placeImage(imgB)
	if not ok then imgA.Visible = false end
	for tid, L in layers do L.frame.Visible = tid == id end
	if not layers[id] and build[id] then
		local f = new("Frame", { Name = "Anim_" .. id, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = root })
		layers[id] = { frame = f, data = build[id](f) }
	end
end

function B.step(dt: number)
	local t = ctx.AT
	-- fondu entre thèmes
	local p = (ctx.T - fadeT0) / 0.8
	if p < 1 then
		imgB.ImageTransparency = 1 - K.easeOutCubic(p)
	else
		imgB.ImageTransparency = 0
		if imgA.Visible and imgA ~= imgB then imgA.Visible = false end
	end
	if B.dirty then
		B.dirty = false
		placeImage(imgA)
		placeImage(imgB)
		B.layoutVignette()
	end
	local L = layers[themeId]
	if L and step[themeId] then step[themeId](L.data, t, dt) end
	-- teinte RGB (Fièvre / pulsation)
	local a = 0.07 * ctx.feverK + 0.06 * ctx.bgPulse
	if a > 0.004 then
		tint.Visible = true
		tint.BackgroundColor3 = K.hsl(K.hue(0), 1, 0.5)
		tint.BackgroundTransparency = 1 - a
	else
		tint.Visible = false
	end
end

function B.layoutVignette()
	local W, H, pl = ctx.W, ctx.H, ctx.play
	vig.top.Size = UDim2.fromOffset(W, H * 0.3)
	vig.bottom.Position = UDim2.fromOffset(0, H * 0.72)
	vig.bottom.Size = UDim2.fromOffset(W, H * 0.28)
	vig.left.Size = UDim2.fromOffset(W * 0.18, H)
	vig.right.Position = UDim2.fromOffset(W * 0.82, 0)
	vig.right.Size = UDim2.fromOffset(W * 0.18, H)
	-- assombrit le décor derrière le panneau (côté droit sur PC, en bas sur mobile)
	if ctx.mobile then
		vig.panel.Position = UDim2.fromOffset(0, pl.top + pl.height - 30)
		vig.panel.Size = UDim2.fromOffset(W, H - (pl.top + pl.height) + 30)
		vigGrad.Rotation = 90
	else
		local x0 = pl.left + pl.width - 30
		vig.panel.Position = UDim2.fromOffset(x0, 0)
		vig.panel.Size = UDim2.fromOffset(math.max(0, W - x0), H)
		vigGrad.Rotation = 0
	end
end

function B.init(context: any, parent: Instance)
	ctx = context
	root = new("Frame", { Name = "Background", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = parent })
	fallback = new("Frame", { Name = "Fallback", BorderSizePixel = 0, BackgroundColor3 = C.white, Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = root })
	fallbackGrad = new("UIGradient", { Parent = fallback })
	imgA = new("ImageLabel", { Name = "BgA", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Stretch, Visible = false, ZIndex = 0, Parent = root })
	imgB = new("ImageLabel", { Name = "BgB", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Stretch, Visible = false, ZIndex = 1, Parent = root })
	-- vignette (bords assombris, comme drawVignette)
	local function edge(name: string, rot: number, tr0: number): Frame
		local f = new("Frame", { Name = name, BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(5, 2, 15), ZIndex = 6, Parent = root })
		new("UIGradient", { Rotation = rot, Transparency = NumberSequence.new(tr0, 1), Parent = f })
		return f
	end
	vig.top = edge("VigTop", 90, 0.5)
	vig.bottom = edge("VigBottom", -90, 0.45)
	vig.left = edge("VigLeft", 0, 0.55)
	vig.right = edge("VigRight", 180, 0.55)
	vig.panel = new("Frame", { Name = "VigPanel", BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(5, 2, 15), ZIndex = 6, Parent = root })
	vigGrad = new("UIGradient", { Transparency = NumberSequence.new(1, 0.5), Parent = vig.panel })
	tint = new("Frame", { Name = "Tint", BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 7, Parent = root })
	B.dirty = true
	themeId = ""
	B.setTheme("synthwave")
end

return B
