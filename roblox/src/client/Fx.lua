-- COOKIE OVERDRIVE — effets du stage (portage de stage.js) : particules (pool), ondes de choc,
-- nombres flottants « +N », grands labels centraux, flash et tremblement d'écran.
-- Tous les objets sont recyclés : aucune création d'instance par image.
local TextService = game:GetService("TextService")

local K = require(script.Parent:WaitForChild("Kit"))
local new, C, F = K.new, K.C, K.F
local clamp, lerp, rand = K.clamp, K.lerp, K.rand

local Fx = {}
local ctx: any = nil
local layerLow: Frame, layerHigh: Frame, layerText: Frame, flashFrame: Frame
local TAU = math.pi * 2

---------------------------------------------------------------------------- réglages
local MAXP = 240 -- particules actives max (× réglage Particules)
Fx.pm = 1 -- multiplicateur de quantité (0,22 éco · 0,55 normal · 1 ULTRA)
Fx.shakeOn = true
Fx.reduced = false

local function hq(h: number, l: number?): Color3
	return K.hsl(math.floor(h / 15 + 0.5) * 15, 1, (l or 60) / 100)
end
Fx.hq = hq
local function pick<T>(t: { T }): T return t[math.random(#t)] end
local function cnt(n: number): number return math.max(0, math.floor(n * Fx.pm + 0.5)) end

---------------------------------------------------------------------------- pools d'objets
type P = {
	obj: GuiObject, kind: string, isImg: boolean, x: number, y: number, vx: number, vy: number, life: number, max: number,
	size: number, col: Color3, g: number, drag: number, rot: number, vr: number, key: string?,
}
local active: { P } = {}
local free: { [string]: { P } } = {}
local HAS: { [string]: boolean } = {}

local function hasKey(key: string): boolean
	if HAS[key] == nil then HAS[key] = K.hasImg(key) end
	return HAS[key]
end

local function makeObj(kind: string, key: string?): (GuiObject, boolean)
	local parent = (kind == "confetti" or kind == "crumb" or kind == "icon") and layerLow or layerHigh
	if kind == "glow" or kind == "star" or kind == "ember" or kind == "icon" then
		local k = key or (kind == "star" and "fx:spark" or "fx:glow")
		if kind == "star" and not hasKey(k) and hasKey("fx:star") then k = "fx:star" end
		if hasKey(k) then
			local im = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = parent })
			if K.trySet(im, k) then return im, true end
			im:Destroy()
		end
		if kind == "icon" and key then
			local im = K.img(key, { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = parent })
			return im, true
		end
		-- repli : pastille ronde (glow) ou losange (étoile)
		local f = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = parent })
		if kind == "star" then f.Rotation = 45 else new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f }) end
		return f, false
	end
	local f = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = parent })
	return f, false
end

local function acquire(kind: string, key: string?): P?
	if #active >= MAXP * math.max(0.3, Fx.pm) then return nil end
	local pk = kind .. (key or "")
	local list = free[pk]
	local p: P
	if list and #list > 0 then
		p = table.remove(list) :: P
	else
		local o, isImg = makeObj(kind, key)
		p = { obj = o, kind = kind, isImg = isImg, x = 0, y = 0, vx = 0, vy = 0, life = 1, max = 1, size = 10, col = C.white, g = 0, drag = 1, rot = 0, vr = 0, key = key }
	end
	p.obj.Visible = true
	table.insert(active, p)
	return p
end

local function release(i: number)
	local p = active[i]
	active[i] = active[#active]
	active[#active] = nil
	p.obj.Visible = false
	local pk = p.kind .. (p.key or "")
	free[pk] = free[pk] or {}
	table.insert(free[pk], p)
end

local function setColor(p: P, c: Color3)
	p.col = c
	if p.isImg then (p.obj :: ImageLabel).ImageColor3 = c else p.obj.BackgroundColor3 = c end
end

-- spawn(type, x, y, vx, vy, life, size, col, g, drag)
function Fx.spawn(kind: string, x: number, y: number, vx: number, vy: number, life: number, size: number, col: Color3?, g: number?, drag: number?, key: string?): P?
	local p = acquire(kind, key)
	if not p then return nil end
	p.x, p.y, p.vx, p.vy, p.life, p.max, p.size = x, y, vx, vy, life, life, size
	p.g, p.drag = g or 0, drag or 1
	p.rot, p.vr = math.random() * TAU, rand(-9, 9)
	if kind ~= "icon" then setColor(p, col or C.white) end
	return p
end

function Fx.burst(x: number, y: number, n: number, o: { [string]: any }?)
	local opt = o or {}
	local sp, cols, life = opt.speed or 300, opt.cols, opt.life or 0.9
	n = cnt(n)
	for i = 0, n - 1 do
		local a = opt.ang and (opt.ang + rand(-(opt.spread or 0.6), opt.spread or 0.6)) or math.random() * TAU
		local v = sp * rand(0.25, 1)
		local col = cols and pick(cols) or hq(K.hue(math.random() * 360))
		local kind = opt.type or (i % 3 == 0 and "star" or i % 3 == 1 and "glow" or "spark")
		local r0 = opt.r0 or 0
		Fx.spawn(kind, x + math.cos(a) * r0, y + math.sin(a) * r0, math.cos(a) * v, math.sin(a) * v,
			life * rand(0.6, 1.2), (opt.size or 14) * rand(0.6, 1.3), col, opt.g or 0, opt.drag or 0.94)
	end
end

function Fx.confettiBurst(x: number, y: number, n: number, o: { [string]: any }?)
	local opt = o or {}
	n = cnt(n)
	for _ = 1, n do
		local a = (opt.ang or -math.pi / 2) + rand(-(opt.spread or 1.2), opt.spread or 1.2)
		local v = (opt.speed or 520) * rand(0.35, 1)
		Fx.spawn("confetti", x + rand(-(opt.w or 0), opt.w or 0), y, math.cos(a) * v, math.sin(a) * v, rand(1.3, 2.4) * (opt.lifeK or 1), rand(7, 13),
			hq(math.random() * 360, rand(55, 68)), opt.g or 900, 0.975)
	end
end

function Fx.crumbs(x: number, y: number, n: number, cols: { Color3 })
	n = cnt(n)
	for _ = 1, n do
		local a = rand(-math.pi, 0) + rand(-0.5, 0.5)
		local v = rand(120, 380)
		Fx.spawn("crumb", x, y, math.cos(a) * v, math.sin(a) * v, rand(0.5, 0.9), rand(3, 7), pick(cols), 1100, 0.985)
	end
end

function Fx.sparkleRing(x: number, y: number, rad: number, n: number, cols: { Color3 }?, speed: number?)
	n = cnt(n)
	for i = 0, n - 1 do
		local a = i / math.max(1, n) * TAU
		local s = speed or 220
		Fx.spawn(i % 2 == 1 and "star" or "glow", x + math.cos(a) * rad, y + math.sin(a) * rad, math.cos(a) * s, math.sin(a) * s,
			rand(0.5, 0.9), rand(14, 24), cols and pick(cols) or hq(K.hue(i * 20), 65), 0, 0.93)
	end
end

-- pluie de confettis plein écran (fx:confetti du site)
function Fx.confettiRain()
	local W, H = ctx.W, ctx.H
	for _ = 1, cnt(90) do
		Fx.spawn("confetti", rand(0, W), rand(-60, -5), rand(-80, 80), rand(60, 260), rand(2.2, 3.6), rand(8, 14), hq(math.random() * 360, rand(55, 68)), 320, 0.99)
	end
	Fx.burst(ctx.CX, ctx.CY, 60, { speed = 620, size = 22, life = 1.1 })
	Fx.confettiBurst(ctx.CX, ctx.CY, 30, { speed = 650, spread = 1.7 })
	Fx.ring(ctx.CX, ctx.CY, ctx.R, math.max(W, H) * 0.6, 0.9, 18, "rgb")
	Fx.flash(0.35)
	Fx.shake(8)
end

-- pluie de gemmes (cookie doré « gemmes »)
function Fx.iconRain(key: string, n: number)
	local pl = ctx.play
	for _ = 1, cnt(n) do
		local p = Fx.spawn("icon", rand(pl.left, pl.left + pl.width), pl.top - 20, rand(-30, 30), rand(60, 200), 2.2, rand(18, 28), nil, 380, 1, key)
		if p then p.obj.Size = UDim2.fromOffset(p.size, p.size) end
	end
end

local function updateParticles(dt: number)
	for i = #active, 1, -1 do
		local p = active[i]
		p.life -= dt
		if p.life <= 0 then
			release(i)
		else
			if p.drag ~= 1 then
				local d = p.drag ^ (dt * 60)
				p.vx *= d
				p.vy *= d
			end
			p.vy += p.g * dt
			p.x += p.vx * dt
			p.y += p.vy * dt
			p.rot += p.vr * dt
			local k = p.life / p.max
			local o = p.obj
			local kind = p.kind
			if kind == "confetti" then
				p.vx += math.sin(p.rot * 1.3) * 40 * dt
				local a = k < 0.25 and k / 0.25 or 1
				o.Position = UDim2.fromOffset(p.x, p.y)
				o.Size = UDim2.fromOffset(p.size, math.max(1, p.size * 0.5 * math.abs(math.cos(p.rot * 2.1))))
				o.Rotation = math.deg(p.rot)
				o.BackgroundTransparency = 1 - a
			elseif kind == "crumb" then
				local a = k < 0.25 and k / 0.25 or 1
				o.Position = UDim2.fromOffset(p.x, p.y)
				o.Size = UDim2.fromOffset(p.size, p.size * 0.8)
				o.Rotation = math.deg(p.rot)
				o.BackgroundTransparency = 1 - a
			elseif kind == "spark" then
				local a = k < 0.35 and k / 0.35 or 1
				local len = math.sqrt(p.vx * p.vx + p.vy * p.vy) * 0.045
				o.Position = UDim2.fromOffset(p.x - p.vx * 0.0225, p.y - p.vy * 0.0225)
				o.Size = UDim2.fromOffset(math.max(1, len), math.max(1, p.size * 0.18 * k))
				o.Rotation = math.deg(math.atan2(p.vy, p.vx))
				o.BackgroundTransparency = 1 - a
			elseif kind == "icon" then
				local a = k < 0.25 and k / 0.25 or 1
				o.Position = UDim2.fromOffset(p.x, p.y)
				o.Rotation = math.deg(p.rot * 0.2)
				if p.isImg then (o :: ImageLabel).ImageTransparency = 1 - a end
			else
				local a = k < 0.35 and k / 0.35 or 1
				local s
				if kind == "star" then
					s = p.size * (0.4 + 0.8 * math.sin(k * math.pi))
				elseif kind == "ember" then
					a *= 0.6 + 0.4 * math.sin(p.rot * 3)
					s = p.size
				else
					s = p.size * (0.35 + 0.65 * k)
				end
				o.Position = UDim2.fromOffset(p.x, p.y)
				o.Size = UDim2.fromOffset(s, s)
				if p.isImg then
					(o :: ImageLabel).ImageTransparency = 1 - a
				else
					o.BackgroundTransparency = 1 - a * (kind == "glow" and 0.5 or 0.9)
				end
			end
		end
	end
end

---------------------------------------------------------------------------- ondes de choc
type Ring = { f: Frame, st: UIStroke, gr: UIGradient, x: number, y: number, r0: number, r1: number, t0: number, dur: number, w: number, rgb: boolean }
local rings: { Ring } = {}
local ringFree: { Ring } = {}
function Fx.ring(x: number, y: number, r0: number, r1: number, dur: number, w: number, col: any)
	if #rings > 16 then return end
	local r = table.remove(ringFree)
	if not r then
		local f = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Parent = layerHigh }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local st = new("UIStroke", { Color = C.white, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
		local gr = new("UIGradient", { Color = K.rainbowSeq(), Parent = st })
		r = { f = f, st = st, gr = gr, x = 0, y = 0, r0 = 0, r1 = 0, t0 = 0, dur = 1, w = 1, rgb = false }
	end
	local ring = r :: Ring
	ring.x, ring.y, ring.r0, ring.r1, ring.t0, ring.dur, ring.w = x, y, r0, r1, ctx.T, dur, w
	ring.rgb = col == "rgb"
	ring.gr.Enabled = ring.rgb
	ring.st.Color = ring.rgb and C.white or (typeof(col) == "Color3" and col or C.gold)
	ring.f.Visible = true
	table.insert(rings, ring)
end

local function updateRings()
	for i = #rings, 1, -1 do
		local g = rings[i]
		local p = (ctx.T - g.t0) / g.dur
		if p >= 1 then
			g.f.Visible = false
			table.insert(ringFree, table.remove(rings, i) :: Ring)
		else
			local rad = lerp(g.r0, g.r1, K.easeOutCubic(p))
			g.f.Position = UDim2.fromOffset(g.x, g.y)
			g.f.Size = UDim2.fromOffset(rad * 2, rad * 2)
			g.st.Thickness = g.w * (1 - p) + 1
			g.st.Transparency = p
			if g.rgb then g.gr.Rotation = (ctx.AT * 115) % 360 end
		end
	end
end

---------------------------------------------------------------------------- nombres flottants (+N, CRIT!, -dégâts)
type Txt = { l: TextLabel, sc: UIScale, gr: UIGradient, st: UIStroke, crit: TextLabel, extra: TextLabel, x: number, y: number, vx: number, vy: number, t0: number, life: number, kind: string, size: number }
local texts: { Txt } = {}
local textFree: { Txt } = {}
local CRIT_SEQ = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("#fff6a8")), ColorSequenceKeypoint.new(0.5, Color3.fromHex("#ffc93c")), ColorSequenceKeypoint.new(1, Color3.fromHex("#ff8a00")) })
local function textW(s: string, size: number): number
	local ok, v = pcall(TextService.GetTextSize, TextService, s, size, Enum.Font.FredokaOne, Vector2.new(4000, 400))
	return ok and v.X or #s * size * 0.55
end

-- kind : "num" (arc-en-ciel) | "crit" (or) | "dmg" (rouge) | "combo" (cyan) | "small" | Color3 (couleur fixe)
function Fx.text(x: number, y: number, text: string, kind: any, extra: string?, sizeOverride: number?)
	if #texts > 26 then
		local old = table.remove(texts, 1) :: Txt
		old.l.Visible = false
		table.insert(textFree, old)
	end
	local t = table.remove(textFree)
	if not t then
		local l = new("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(600, 60), FontFace = F.display,
			TextColor3 = C.white, TextXAlignment = Enum.TextXAlignment.Center, Parent = layerText,
		})
		local sc = new("UIScale", { Parent = l })
		local st = new("UIStroke", { Color = C.stroke, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
		local gr = new("UIGradient", { Rotation = 0, Parent = l })
		local crit = new("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(300, 30),
			FontFace = F.display, Text = "CRIT!", TextColor3 = C.red, Parent = l,
		}, { new("UIStroke", { Color = C.stroke, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round }) })
		local ex = new("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(120, 30), FontFace = F.display,
			TextColor3 = C.cyan, TextXAlignment = Enum.TextXAlignment.Left, Parent = l,
		}, { new("UIStroke", { Color = C.stroke, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round }) })
		t = { l = l, sc = sc, gr = gr, st = st, crit = crit, extra = ex, x = 0, y = 0, vx = 0, vy = 0, t0 = 0, life = 1, kind = "num", size = 30 }
	end
	local tt = t :: Txt
	local k = typeof(kind) == "string" and kind or "color"
	local size = sizeOverride or (k == "crit" and 44 or k == "dmg" and 26 or k == "small" and 18 or 30)
	size *= clamp(ctx.R / 140, 0.75, 1.15)
	tt.x, tt.y, tt.vx, tt.vy, tt.t0 = x, y, rand(-40, 40), k == "crit" and -170 or -140, ctx.T
	tt.life, tt.kind, tt.size = k == "crit" and 1.3 or 1.05, k, size
	local l = tt.l
	l.Text = text
	l.TextSize = math.floor(size)
	l.Size = UDim2.fromOffset(textW(text, math.floor(size)) + 20, size * 1.3)
	tt.st.Thickness = math.max(2, size * 0.1)
	if k == "crit" then
		tt.gr.Enabled, tt.gr.Rotation, tt.gr.Color = true, 90, CRIT_SEQ
		l.TextColor3 = C.white
	elseif k == "num" then
		tt.gr.Enabled, tt.gr.Rotation, tt.gr.Color = true, 0, K.hueSeq(K.hue(#texts * 30), 55)
		l.TextColor3 = C.white
	else
		tt.gr.Enabled = false
		l.TextColor3 = k == "dmg" and C.red or k == "combo" and C.cyan or (typeof(kind) == "Color3" and kind or C.white)
	end
	tt.crit.Visible = k == "crit"
	if k == "crit" then
		tt.crit.TextSize = math.floor(size * 0.5)
		tt.crit.Position = UDim2.new(0.5, 0, 0, size * 0.12)
	end
	if extra and extra ~= "" then
		tt.extra.Visible = true
		tt.extra.Text = extra
		tt.extra.TextSize = math.floor(size * 0.5)
		tt.extra.Position = UDim2.new(1, -10 + size * 0.15, 0.55, 0)
	else
		tt.extra.Visible = false
	end
	l.Visible = true
	table.insert(texts, tt)
end

local function updateTexts()
	local T = ctx.T
	for i = #texts, 1, -1 do
		local t = texts[i]
		local age = T - t.t0
		if age > t.life then
			t.l.Visible = false
			table.insert(textFree, table.remove(texts, i) :: Txt)
		else
			local k = age / t.life
			local sc = age < 0.12 and 0.5 + (age / 0.12) * 0.75 or age < 0.25 and 1.25 - ((age - 0.12) / 0.13) * 0.25 or 1
			local x = t.x + t.vx * age
			local y = t.y + t.vy * age * (1 - age * 0.35)
			t.l.Position = UDim2.fromOffset(x, y)
			t.sc.Scale = sc
			local tr = k > 0.7 and (k - 0.7) / 0.3 or 0
			t.l.TextTransparency = tr
			t.st.Transparency = tr
			if t.crit.Visible then t.crit.TextTransparency = tr end
			if t.extra.Visible then t.extra.TextTransparency = tr end
		end
	end
end

---------------------------------------------------------------------------- grands labels (FIÈVRE RGB !!, BOSS VAINCU !, cookie doré…)
type Lbl = { root: Frame, l: TextLabel, glow: ImageLabel, sc: UIScale, gr: UIGradient, st: UIStroke, t0: number, dur: number, big: number, rgb: boolean, col: Color3 }
local labels: { Lbl } = {}
local labelFree: { Lbl } = {}
function Fx.label(text: string, color: any, big: number?)
	if not text or text == "" then return end
	if #labels > 4 then
		local old = table.remove(labels, 1) :: Lbl
		old.root.Visible = false
		table.insert(labelFree, old)
	end
	local L = table.remove(labelFree)
	if not L then
		local root = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), Parent = layerText })
		local glow = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ImageTransparency = 0.55, Parent = root })
		if not K.trySet(glow, "fx:glow") then glow.Visible = false end
		local l = new("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
			FontFace = F.display, TextColor3 = C.white, TextXAlignment = Enum.TextXAlignment.Center, Parent = root,
		})
		local st = new("UIStroke", { Color = C.stroke, Thickness = 5, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
		local gr = new("UIGradient", { Parent = l })
		local sc = new("UIScale", { Parent = root })
		L = { root = root, l = l, glow = glow, sc = sc, gr = gr, st = st, t0 = 0, dur = 2.3, big = 1, rgb = false, col = C.white }
	end
	local lb = L :: Lbl
	lb.t0, lb.dur, lb.big = ctx.T, 2.3, big or 1
	lb.rgb = color == "rgb"
	lb.col = typeof(color) == "Color3" and color or (type(color) == "string" and color ~= "rgb" and Color3.fromHex(color)) or C.white
	local pl = ctx.play
	local base = clamp(pl.width * 0.085, 28, 64) * lb.big
	local w = textW(text, math.floor(base))
	local fs = base
	if w > pl.width * 0.94 then fs = base * pl.width * 0.94 / w; w = pl.width * 0.94 end
	lb.l.Text = text
	lb.l.TextSize = math.floor(fs)
	lb.st.Thickness = math.max(3, fs * 0.1)
	lb.root.Size = UDim2.fromOffset(w + 30, fs * 1.4)
	lb.glow.Size = UDim2.fromOffset(math.min(w, pl.width) * 1.1, math.min(w, pl.width) * 1.1)
	lb.gr.Enabled = lb.rgb
	lb.l.TextColor3 = lb.rgb and C.white or lb.col
	lb.root.Visible = true
	table.insert(labels, lb)
end

local function updateLabels()
	local T, pl = ctx.T, ctx.play
	for i = #labels, 1, -1 do
		local L = labels[i]
		local age = T - L.t0
		if age > L.dur then
			L.root.Visible = false
			table.insert(labelFree, table.remove(labels, i) :: Lbl)
		else
			local k = age / L.dur
			local sc = Fx.reduced and 1 or (age < 0.45 and K.elasticOut(age / 0.45) or 1)
			local base = clamp(pl.width * 0.085, 28, 64) * L.big
			L.root.Position = UDim2.fromOffset(pl.left + pl.width / 2, pl.top + pl.height * 0.36 - age * 22 - (i - 1) * base * 0.2)
			L.root.Rotation = math.deg(math.sin(age * 6) * 0.03 * (1 - k))
			L.sc.Scale = math.max(0.01, sc)
			local tr = k > 0.72 and (k - 0.72) / 0.28 or 0
			L.l.TextTransparency = tr
			L.st.Transparency = tr
			L.glow.ImageTransparency = 1 - (1 - tr) * 0.45
			if L.rgb then
				L.gr.Color = K.hueSeq(K.hue(0), 55)
				L.glow.ImageColor3 = hq(K.hue(0))
			else
				L.glow.ImageColor3 = L.col
			end
		end
	end
end

---------------------------------------------------------------------------- flash & tremblement
local flash, flashCol = 0, C.white
local shakeAmp = 0
Fx.offset = Vector2.zero
function Fx.flash(a: number, col: Color3?)
	if Fx.reduced then return end
	flash = math.max(flash, a)
	flashCol = col or C.white
end
function Fx.shake(a: number)
	if not Fx.shakeOn or Fx.reduced then return end
	shakeAmp = math.max(shakeAmp, a)
end

---------------------------------------------------------------------------- boucle
function Fx.step(dt: number)
	updateParticles(dt)
	updateRings()
	updateTexts()
	updateLabels()
	shakeAmp *= math.exp(-dt * 9)
	flash *= math.exp(-dt * 5)
	if shakeAmp > 0.3 then
		Fx.offset = Vector2.new(rand(-1, 1) * shakeAmp, rand(-1, 1) * shakeAmp)
	else
		Fx.offset = Vector2.zero
	end
	if flash > 0.01 then
		flashFrame.Visible = true
		flashFrame.BackgroundColor3 = flashCol
		flashFrame.BackgroundTransparency = 1 - flash * 0.6
	else
		flashFrame.Visible = false
	end
end

-- Efface tout (changement de thème, rebirth…)
function Fx.clear()
	for i = #active, 1, -1 do release(i) end
end

function Fx.count(): number return #active end

-- low : particules « normales » (confettis, miettes) · high : additives (glow, étincelles) · text : nombres & labels
function Fx.init(context: any, low: Frame, high: Frame, textLayer: Frame, overlay: Frame)
	ctx = context
	layerLow, layerHigh, layerText = low, high, textLayer
	flashFrame = new("Frame", { Name = "Flash", BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 5, Parent = overlay })
end

return Fx
