-- COOKIE OVERDRIVE — tout ce qui vit autour du cookie (stage.js, zones « around » et « screen ») :
-- anneau de curseurs, parade des bâtiments, étoiles de rebirth, mini-cookies en orbite, anneau de Saturne,
-- aura de feu, éclairs, rayons divins, trou noir, vitesse lumière, pluie de cookies, boule disco,
-- pulsation sur le beat et chat de stream. Objets créés une fois puis recyclés.
local RS = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local D = require(RS:WaitForChild("Shared"):WaitForChild("GameData"))
local K = require(script.Parent:WaitForChild("Kit"))
local Cookie = require(script.Parent:WaitForChild("Cookie"))
local new, C, F = K.new, K.C, K.F
local clamp, rand, lerp = K.clamp, K.rand, K.lerp

local A = {}
-- secousse d'écran sur les temps forts du beat_pulse (branchée par Stage sur Fx.shake)
A.onBeatShake = nil :: ((number) -> ())?
local ctx: any = nil
local stage: Frame
local TAU = math.pi * 2
local V: { [string]: number } = {}
local state: any = nil

-- ZIndex dans le stage (le cookie est à 20)
-- (entiers uniquement : ZIndex est un entier ; le cookie est à 20, ses ombres / rémanences à 17-19)
local ZB = { rays = 1, hole = 2, warp = 3, rain = 4, disco = 5, beat = 6, parade = 7, paradeIcon = 8, paradeBadge = 9, fireGlow = 10, fire = 11, satBack = 12, orbBack = 13, starBack = 14, cursorGlow = 15, cursors = 16, satFront = 22, orbFront = 23, starFront = 24, bolts = 25, ball = 26, chat = 31 }

local HAS: { [string]: boolean } = {}
local function has(key: string): boolean
	if HAS[key] == nil then HAS[key] = K.hasImg(key) end
	return HAS[key]
end
local function hq(h: number, l: number?): Color3 return K.hsl(math.floor(h / 15 + 0.5) * 15, 1, (l or 60) / 100) end

local function sprite(key: string, z: number, parent: Instance?): ImageLabel
	local im = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z, Parent = parent or stage })
	if not K.trySet(im, key) then im.ImageTransparency = 1; im:SetAttribute("noimg", true) end
	return im
end
local function glow(z: number, col: Color3?): ImageLabel
	local im = sprite("fx:glow", z)
	if col then im.ImageColor3 = col end
	return im
end
local function place(o: GuiObject, x: number, y: number, w: number, h: number?)
	o.Position = UDim2.fromOffset(x, y)
	o.Size = UDim2.fromOffset(w, h or w)
end
local function cookieImg(z: number): ImageLabel
	local im = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z, Parent = stage })
	im:SetAttribute("skin", "")
	return im
end
local function setCookieSkin(im: ImageLabel, skin: string)
	if im:GetAttribute("skin") == skin then return end
	im:SetAttribute("skin", skin)
	im.Image = ""
	if not K.trySet(im, "cookie:" .. skin) then K.setImg(im, "ui:cookie", "🍪") end
end

---------------------------------------------------------------------------- anneau de curseurs (toujours visible)
local cursors: { { img: ImageLabel, g: ImageLabel } } = {}
local cursorTap = 0
local function stepCursors()
	local n = math.min(60, (state and state.buildings and state.buildings.cursor) or 0)
	local turbo = V.cursor_rgb ~= nil
	local ps = turbo and Cookie.pop("cursor_rgb") or 1
	local R, CX, CY, AT = ctx.R, ctx.CX, ctx.CY, ctx.AT
	for idx = 1, math.max(n, #cursors) do
		local c = cursors[idx]
		if idx <= n then
			if not c then
				c = { img = sprite("b:cursor", ZB.cursors), g = glow(ZB.cursorGlow) }
				if c.img:GetAttribute("noimg") then K.setImg(c.img, "b:cursor", "👆") end
				cursors[idx] = c
			end
			local i0 = idx - 1
			local row = i0 // 20
			local i = i0 % 20
			local cnt = math.min(20, n - row * 20)
			local rad = R * (1.36 + row * 0.2) * (0.6 + 0.4 * ps)
			local size = clamp(R * 0.2, 14, 30) * (1 - row * 0.08)
			local a = (i / cnt) * TAU + AT * (turbo and 0.9 or 0.22) * (row % 2 == 1 and -1 or 1) + row * 0.3
			local ph = (AT * (turbo and 2.2 or 1.1) - i / cnt) % 1
			local tap = ph < 0.18 and math.sin(ph / 0.18 * math.pi) or 0
			if turbo then tap = math.max(tap, cursorTap) end
			local d = rad - tap * R * 0.12
			local x, y = CX + math.cos(a) * d, CY + math.sin(a) * d
			c.img.Visible = true
			place(c.img, x, y, size)
			c.img.Rotation = math.deg(a - math.pi / 2)
			if turbo and not c.g:GetAttribute("noimg") then
				c.g.Visible = true
				place(c.g, x, y, size * 1.9)
				c.g.ImageColor3 = hq(K.hue(idx * 12))
				c.g.ImageTransparency = 0.15
			else
				c.g.Visible = false
			end
		elseif c then
			c.img.Visible = false
			c.g.Visible = false
		end
	end
end

---------------------------------------------------------------------------- parade des bâtiments (sous le cookie)
type ParadeItem = { id: string, i: number, icon: ImageLabel, g: ImageLabel, badge: Frame, txt: TextLabel, shadow: Frame }
local parade: { ParadeItem } = {}
local paradeKey = ""
local paradeBounce: { [string]: number } = {}
local function paradeItem(): ParadeItem
	local g = glow(ZB.parade)
	local shadow = new("Frame", { BackgroundColor3 = C.black, BackgroundTransparency = 0.5, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = ZB.parade, Parent = stage }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local icon = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = ZB.paradeIcon, Parent = stage })
	local badge = new("Frame", { BackgroundColor3 = C.stroke, BackgroundTransparency = 0.12, AnchorPoint = Vector2.new(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), ZIndex = ZB.paradeBadge, Parent = stage }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
	})
	new("UIStroke", { Thickness = 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.2, Parent = badge })
	local txt = K.txt("", 12, F.num, C.white, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = ZB.paradeBadge, Parent = badge })
	return { id = "", i = 0, icon = icon, g = g, badge = badge, txt = txt, shadow = shadow }
end
local function stepParade()
	local st = state
	if not st or not st.buildings then return end
	local list = {}
	for _, b in D.buildings do
		if b.id ~= "cursor" and (st.buildings[b.id] or 0) > 0 then table.insert(list, b.id) end
	end
	local key = table.concat(list, ",")
	local pl, R, AT, T = ctx.play, ctx.R, ctx.AT, ctx.T
	local y = pl.top + pl.height * 0.835
	local sz = clamp(R * 0.3, 22, 34)
	local gap = sz * 2.15
	local total = #list * gap
	local left, right = pl.left + 8, pl.left + pl.width - 8
	local scroll = total > right - left
	local reps = scroll and 2 or 1
	local need = #list * reps
	if key ~= paradeKey then
		paradeKey = key
		for i = 1, math.max(need, #parade) do
			local it = parade[i]
			if i <= need then
				if not it then it = paradeItem(); parade[i] = it end
				local idx = (i - 1) % math.max(1, #list) + 1
				local id = list[idx]
				if it.id ~= id then
					it.id = id
					it.icon.Image = ""
					K.setImg(it.icon, "b:" .. id)
				end
				it.i = idx
			elseif it then
				it.id = ""
				it.icon.Visible, it.g.Visible, it.badge.Visible, it.shadow.Visible = false, false, false, false
			end
		end
	end
	local x0 = scroll and (left - ((AT * 26) % total) + gap / 2) or (pl.left + pl.width / 2 - total / 2 + gap / 2)
	for i = 1, #parade do
		local it = parade[i]
		if i > need or it.id == "" then
			it.icon.Visible, it.g.Visible, it.badge.Visible, it.shadow.Visible = false, false, false, false
		else
			local rep = (i - 1) // math.max(1, #list)
			local x = x0 + (it.i - 1) * gap + rep * total
			local a = scroll and clamp(math.min(x - left, right - x) / 50, 0, 1) or 1
			local vis = a > 0 and x > left - gap and x < right + gap
			it.icon.Visible, it.g.Visible, it.badge.Visible, it.shadow.Visible = vis, vis and not it.g:GetAttribute("noimg"), vis, vis
			if vis then
				local bt = paradeBounce[it.id] and T - paradeBounce[it.id] or 9
				local bb = bt < 0.6 and math.sin(bt * 16) * (1 - bt / 0.6) * 8 or 0
				local yy = y + math.sin(AT * 2.4 + (it.i - 1) * 0.9) * 3 - math.abs(bb)
				place(it.g, x, y + 2, sz * 2.3)
				it.g.ImageColor3 = hq(K.hue((it.i - 1) * 40))
				it.g.ImageTransparency = 1 - a * 0.55
				place(it.shadow, x, y + sz * 0.55, sz * 0.9, sz * 0.24)
				it.shadow.BackgroundTransparency = 1 - a * 0.5
				place(it.icon, x, yy, sz * (1 + math.abs(bb) * 0.02))
				it.icon.ImageTransparency = 1 - a
				it.badge.Position = UDim2.fromOffset(x + sz * 0.42, y + sz * 0.42)
				local bs = it.badge:FindFirstChildOfClass("UIStroke")
				if bs then bs.Color = K.hsl(K.hue((it.i - 1) * 40), 1, 0.65) end
				local txt = "×" .. tostring(st.buildings[it.id] or 0)
				if it.txt.Text ~= txt then it.txt.Text = txt end
				it.txt.TextSize = math.floor(sz * 0.36 + 3)
			end
		end
	end
end
function A.bounce(id: string)
	paradeBounce[id] = ctx.T
	if id == "cursor" then cursorTap = 1 end
end

---------------------------------------------------------------------------- étoiles de rebirth (ellipse inclinée)
local stars: { { img: ImageLabel, g: ImageLabel } } = {}
local function stepStars()
	local n = math.min(10, (state and state.rebirths) or 0)
	local R, CX, CY, AT = ctx.R, ctx.CX, ctx.CY, ctx.AT
	local rx, ry, tilt, sz = R * 1.14, R * 0.34, 0.3, clamp(R * 0.13, 10, 22)
	for i = 1, math.max(n, #stars) do
		local s = stars[i]
		if i <= n then
			if not s then
				s = { img = sprite("ui:star", ZB.starFront), g = glow(ZB.starFront, C.gold) }
				if s.img:GetAttribute("noimg") then K.setImg(s.img, "ui:star", "⭐") end
				stars[i] = s
			end
			local a = AT * 0.9 + ((i - 1) / n) * TAU
			local depth = math.sin(a)
			local lx, ly = math.cos(a) * rx, math.sin(a) * ry
			local x = CX + lx * math.cos(tilt) - ly * math.sin(tilt)
			local y = CY - R * 0.1 + lx * math.sin(tilt) + ly * math.cos(tilt)
			local size = sz * (0.85 + depth * 0.2)
			local front = depth > 0
			s.img.ZIndex = front and ZB.starFront or ZB.starBack
			s.g.ZIndex = s.img.ZIndex
			s.img.Visible = true
			place(s.img, x, y, size)
			s.img.Rotation = math.deg(AT * 1.5 + i)
			s.img.ImageTransparency = front and 0 or 0.25
			s.g.Visible = not s.g:GetAttribute("noimg")
			place(s.g, x, y, size * 2.4)
			s.g.ImageTransparency = 0.4
		elseif s then
			s.img.Visible, s.g.Visible = false, false
		end
	end
end

---------------------------------------------------------------------------- mini-cookies en orbite
local ORB = { { -0.5, 1.5, 0.3, 1.1 }, { 0.42, 1.78, 0.36, -0.8 }, { 1.25, 1.62, 0.24, 1.4 } }
local orbs: { { img: ImageLabel, g: ImageLabel } } = {}
local function stepOrbiters()
	local lvl = math.min(3, V.orbiters or 0)
	local n = lvl * 3
	local s = Cookie.pop("orbiters")
	local R, CX, CY, AT = ctx.R, ctx.CX, ctx.CY, ctx.AT
	local skin = Cookie.skin()
	for i = 1, math.max(n, #orbs) do
		local o = orbs[i]
		if i <= n and s > 0.01 then
			if not o then
				o = { img = cookieImg(ZB.orbFront), g = glow(ZB.orbFront) }
				orbs[i] = o
			end
			setCookieSkin(o.img, skin)
			local i0 = i - 1
			local ob = ORB[i0 % 3 + 1]
			local k = i0 // 3
			local per = math.ceil(n / 3)
			local a = AT * ob[4] + (k / per) * TAU + (i0 % 3) * 0.7
			local dep = math.sin(a) * math.sign(ob[4])
			local rx = R * ob[2] * s
			local lx, ly = math.cos(a) * rx, math.sin(a) * rx * ob[3]
			local x = CX + lx * math.cos(ob[1]) - ly * math.sin(ob[1])
			local y = CY + lx * math.sin(ob[1]) + ly * math.cos(ob[1])
			local sz = R * 0.15 * (1 + dep * 0.25) * s
			local front = dep > 0
			o.img.ZIndex = front and ZB.orbFront or ZB.orbBack
			o.g.ZIndex = o.img.ZIndex
			o.img.Visible = true
			place(o.img, x, y, sz * 3.2)
			o.img.Rotation = math.deg(AT * 2 + i)
			o.img.ImageTransparency = front and 0 or 0.15
			o.g.Visible = not o.g:GetAttribute("noimg")
			place(o.g, x, y, sz * 3.2)
			o.g.ImageColor3 = hq(K.hue(i * 40))
			o.g.ImageTransparency = 0.5
		elseif o then
			o.img.Visible, o.g.Visible = false, false
		end
	end
end

---------------------------------------------------------------------------- anneau de Saturne
-- fx:saturn_back / fx:saturn_front : 512×256, centre du cookie = centre de l'image, R = 128 → 4R × 2R.
-- Les poussières dessinées dans l'image sont figées ; quelques poussières animées tournent par-dessus.
-- Repli : 4 anneaux fx:ring coupés en deux (moitié arrière derrière le cookie, moitié avant devant).
local sat: any = nil
local SAT_BANDS = { { 1.52, 30, 0.5 }, { 1.7, 0, 0.42 }, { 1.9, 300, 0.55 }, { 2.02, 200, 0.7 } }
local SAT_DOTS = 14
local function buildSaturn()
	sat = { dots = {} }
	if has("fx:saturn_back") and has("fx:saturn_front") then
		sat.back = sprite("fx:saturn_back", ZB.satBack)
		sat.front = sprite("fx:saturn_front", ZB.satFront)
	elseif has("fx:ring") then
		sat.bands = {}
		local sz = K.Img.size("fx:ring")
		if sz.X < 1 then sz = Vector2.new(512, 512) end
		for _, b in SAT_BANDS do
			local back = sprite("fx:ring", ZB.satBack)
			local front = sprite("fx:ring", ZB.satFront)
			back.ImageRectOffset, back.ImageRectSize = Vector2.zero, Vector2.new(sz.X, sz.Y / 2)
			front.ImageRectOffset, front.ImageRectSize = Vector2.new(0, sz.Y / 2), Vector2.new(sz.X, sz.Y / 2)
			table.insert(sat.bands, { back = back, front = front, r = b[1], off = b[2], al = b[3] })
		end
	end
	for _ = 1, SAT_DOTS do table.insert(sat.dots, glow(ZB.satFront)) end
end
local function stepSaturn()
	if not V.saturn_ring then
		if sat then
			if sat.back then sat.back.Visible = false; sat.front.Visible = false end
			for _, b in sat.bands or {} do b.back.Visible = false; b.front.Visible = false end
			for _, d in sat.dots do d.Visible = false end
		end
		return
	end
	if not sat then buildSaturn() end
	local s = Cookie.pop("saturn_ring")
	local R, CX, CY, AT = ctx.R, ctx.CX, ctx.CY, ctx.AT
	local tilt, sy = -0.38, 0.26
	local ct, st = math.cos(tilt), math.sin(tilt)
	if sat.back then
		for _, im in { sat.back, sat.front } do
			im.Visible = s > 0.01
			place(im, CX, CY, R * 4 * s, R * 2 * s)
		end
	elseif sat.bands then
		for _, b in sat.bands do
			-- le trait de fx:ring est au rayon 240/256 de l'image
			local w = R * b.r * 2 * s * (256 / 240)
			local h = w * sy
			local col = K.hsl(K.hue(b.off), 0.9, 0.72)
			local ox, oy = -st * h / 4, ct * h / 4
			for j, im in { b.back, b.front } do
				local sign = j == 1 and -1 or 1
				im.Visible = s > 0.01
				place(im, CX + ox * sign, CY + oy * sign, w, h / 2)
				im.Rotation = math.deg(tilt)
				im.ImageColor3 = col
				im.ImageTransparency = 1 - b.al
			end
		end
	end
	for i, d in sat.dots do
		local a = i * 2.39 + AT * 0.45 * (1 + (i % 3) * 0.12)
		local dep = math.sin(a)
		local rr = R * (1.5 + ((i * 0.618) % 1) * 0.5) * s
		local lx, ly = math.cos(a) * rr, math.sin(a) * rr * sy
		d.Visible = s > 0.01 and not d:GetAttribute("noimg")
		d.ZIndex = dep > 0 and ZB.satFront or ZB.satBack
		place(d, CX + lx * ct - ly * st, CY + lx * st + ly * ct, R * 0.09)
		d.ImageColor3 = hq(K.hue(i * 10), 75)
	end
end

---------------------------------------------------------------------------- aura de feu
type Flame = { im: ImageLabel, x: number, y: number, vx: number, vy: number, life: number, max: number, s: number, core: boolean }
local fire: { Flame } = {}
local fireFree: { ImageLabel } = {}
local fireGlow: ImageLabel? = nil
local FIRE_COLS = { Color3.fromHex("#ff2b2b"), Color3.fromHex("#ff5a00"), Color3.fromHex("#ff9a1f"), Color3.fromHex("#ffd23c") }
local CORE_COLS = { Color3.fromHex("#5a3cff"), Color3.fromHex("#8a5cff"), Color3.fromHex("#3dc8ff"), Color3.fromHex("#bff6ff") }
local fireAcc = 0
local function stepFire(dt: number)
	local R, CX, CY, heat = ctx.R, ctx.CX, ctx.CY, ctx.heat
	for i = #fire, 1, -1 do
		local f = fire[i]
		f.life -= dt
		if f.life <= 0 then
			f.im.Visible = false
			table.insert(fireFree, f.im)
			fire[i] = fire[#fire]
			fire[#fire] = nil
		else
			f.x += f.vx * dt
			f.y += f.vy * dt
			f.vy -= 60 * dt
			local k = clamp(f.life / f.max, 0, 1)
			local cols = f.core and CORE_COLS or FIRE_COLS
			f.im.ImageColor3 = cols[math.min(4, math.floor(k * 4) + 1)]
			f.im.ImageTransparency = 1 - math.min(1, k * 1.6) * 0.8
			place(f.im, f.x, f.y, f.s * (0.4 + k * 0.8))
		end
	end
	local lvl = V.fire_aura or 0
	if lvl > 0 then
		if not fireGlow then fireGlow = glow(ZB.fireGlow, Color3.fromRGB(255, 110, 20)) end
		local g = fireGlow :: ImageLabel
		local s = Cookie.pop("fire_aura")
		g.Visible = not g:GetAttribute("noimg")
		place(g, CX, CY, R * (1.45 + heat * 0.3) * s * 2.3)
		g.ImageTransparency = 1 - (0.4 + heat * 0.3)
		if not has("fx:glow") then return end
		local rate = (45 + 150 * heat + (ctx.fever and 90 or 0)) * (lvl >= 2 and 1.5 or 1) * clamp(ctx.pm, 0.25, 1) * 0.5
		local cap = math.floor(70 * clamp(ctx.pm, 0.3, 1))
		fireAcc += rate * dt
		while fireAcc >= 1 and #fire < cap do
			fireAcc -= 1
			local im = table.remove(fireFree) or glow(ZB.fire)
			im.Visible = true
			local a = math.random() * TAU
			local rr = Cookie.ck.drawR * 0.93
			local core = lvl >= 2 and math.random() < 0.4
			table.insert(fire, {
				im = im, x = CX + math.cos(a) * rr, y = CY + math.sin(a) * rr, vx = rand(-18, 18) + math.cos(a) * 25, vy = -rand(50, 130) * (1 + heat * 0.8),
				life = rand(0.45, 0.85) * (core and 0.7 or 1), max = 0.85, s = R * rand(0.2, 0.34) * (1 + heat * 0.5) * 1.6, core = core,
			})
		end
		if fireAcc > 3 then fireAcc = 0 end
	elseif fireGlow then
		fireGlow.Visible = false
	end
end

---------------------------------------------------------------------------- éclairs statiques
type Bolt = { segs: { Frame }, pts: { number }, t0: number, life: number, col: Color3 }
local bolts: { Bolt } = {}
local boltFree: { { Frame } } = {}
local boltT = 0
local function makeSegs(): { Frame }
	local segs = {}
	for _ = 1, 8 do
		local f = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = C.white, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = ZB.bolts, Parent = stage })
		new("UIStroke", { Thickness = 2.2, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
		table.insert(segs, f)
	end
	return segs
end
local function stepLightning(dt: number)
	if V.lightning then
		boltT -= dt
		local iv = ctx.fever and 0.05 or 0.26 - ctx.heat * 0.18
		if boltT <= 0 then
			boltT = iv * rand(0.5, 1.5)
			if #bolts < 6 then
				local out = math.random() < 0.45
				local a0 = math.random() * TAU
				local a1 = out and a0 + rand(-0.3, 0.3) or a0 + rand(0.5, 1.4) * (math.random() < 0.5 and -1 or 1)
				local bulge, reach = rand(0.15, 0.4), rand(1.45, 1.95)
				local pts = {}
				for i = 0, 8 do
					local k = i / 8
					table.insert(pts, lerp(a0, a1, k))
					table.insert(pts, out and lerp(1, reach, k) or 1 + math.sin(k * math.pi) * bulge)
				end
				local segs = table.remove(boltFree) or makeSegs()
				local col = math.random() < 0.5 and C.cyan or Color3.fromHex("#a57bff")
				for _, s in segs do
					local st = s:FindFirstChildOfClass("UIStroke")
					if st then st.Color = col end
				end
				table.insert(bolts, { segs = segs, pts = pts, t0 = ctx.T, life = rand(0.1, 0.22), col = col })
			end
		end
	end
	local s = Cookie.pop("lightning")
	local R, CX, CY = ctx.R, ctx.CX, ctx.CY
	for i = #bolts, 1, -1 do
		local b = bolts[i]
		if ctx.T - b.t0 > b.life or not V.lightning then
			for _, f in b.segs do f.Visible = false end
			table.insert(boltFree, b.segs)
			table.remove(bolts, i)
		else
			local px, py = 0, 0
			local flick = math.random() < 0.2 and 0.5 or 0
			for j = 0, 8 do
				local jit = (j == 0 or j == 8) and 0 or R * 0.07
				local a, rr = b.pts[j * 2 + 1], b.pts[j * 2 + 2] * R * Cookie.ck.s * s
				local x, y = CX + math.cos(a) * rr + rand(-jit, jit), CY + math.sin(a) * rr + rand(-jit, jit)
				if j > 0 then
					local f = b.segs[j]
					local dx, dy = x - px, y - py
					f.Visible = true
					f.Position = UDim2.fromOffset((x + px) / 2, (y + py) / 2)
					f.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 1.5, 1.6)
					f.Rotation = math.deg(math.atan2(dy, dx))
					f.BackgroundTransparency = flick
				end
				px, py = x, y
			end
		end
	end
end

---------------------------------------------------------------------------- rayons divins
local rays: { ImageLabel }? = nil
local function stepRays()
	if not V.god_rays then
		if rays then for _, r in rays do r.Visible = false end end
		return
	end
	if not rays then
		rays = { sprite("fx:god_rays", ZB.rays), sprite("fx:god_rays", ZB.rays) }
	end
	local rs = rays :: { ImageLabel }
	local s = Cookie.pop("god_rays")
	local len = math.sqrt(ctx.W ^ 2 + ctx.H ^ 2) * 0.75 * s
	for i, im in rs do
		im.Visible = not im:GetAttribute("noimg")
		place(im, ctx.CX, ctx.CY, len * 2)
		-- l'image contient déjà les 2 couches du site ; deux copies qui tournent en sens inverse
		if i == 1 then
			im.Rotation = math.deg(ctx.AT * 0.12)
			im.ImageTransparency = 0.35
		else
			im.Rotation = math.deg(-ctx.AT * 0.2 + 0.22)
			im.ImageTransparency = 0.6
		end
	end
end

---------------------------------------------------------------------------- trou noir
-- fx:black_hole : la lueur extérieure (R × 6) = largeur de l'image. Poussières qui tombent animées par-dessus.
local hole: any = nil
local function stepHole()
	if not V.black_hole then
		if hole then
			for _, o in hole.parts do o.Visible = false end
			for _, d in hole.dots do d.Visible = false end
		end
		return
	end
	if not hole then
		hole = { parts = {}, dots = {} }
		if has("fx:black_hole") then
			hole.img = sprite("fx:black_hole", ZB.hole)
			hole.parts = { hole.img }
		else
			-- repli : lueurs orange / violette + disque sombre
			hole.g1 = glow(ZB.hole, Color3.fromRGB(255, 120, 40))
			hole.g2 = glow(ZB.hole, Color3.fromHex("#7a2cff"))
			hole.dark = new("Frame", { BackgroundColor3 = C.black, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = ZB.hole, Parent = stage }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			hole.parts = { hole.g1, hole.g2, hole.dark }
		end
		for _ = 1, 22 do table.insert(hole.dots, glow(ZB.hole)) end
	end
	local s = Cookie.pop("black_hole")
	local R, CX, CY, AT = ctx.R, ctx.CX, ctx.CY, ctx.AT
	if hole.img then
		hole.img.Visible = s > 0.01
		place(hole.img, CX, CY, R * 6 * s)
	else
		for _, o in hole.parts do o.Visible = s > 0.01 end
		place(hole.g1, CX, CY, R * 6 * s); hole.g1.ImageTransparency = 0.2
		place(hole.g2, CX, CY, R * 4.6 * s); hole.g2.ImageTransparency = 0.2
		place(hole.dark, CX, CY, R * 2.2 * s)
	end
	for i, d in hole.dots do
		local k = (AT * 0.25 + i * 0.137) % 1
		local a = i * 2.2 + k * 5 + AT * 0.5
		local rad = R * (2.9 - k * 1.7) * s
		d.Visible = s > 0.01 and not d:GetAttribute("noimg")
		place(d, CX + math.cos(a) * rad, CY + math.sin(a) * rad * 0.45, R * 0.12 * s)
		d.ImageColor3 = i % 2 == 1 and Color3.fromHex("#ffb347") or Color3.fromHex("#c07bff")
		d.ImageTransparency = 1 - math.sin(k * math.pi)
	end
end

---------------------------------------------------------------------------- vitesse lumière
type Streak = { f: Frame, a: number, d: number, w: number, h: number }
local warp: { Streak }? = nil
local function stepWarp(dt: number)
	if not V.warp then
		if warp then for _, w in warp do w.f.Visible = false end end
		return
	end
	if not warp then
		local ws: { Streak } = {}
		warp = ws
		for _ = 1, 80 do
			table.insert(ws, { f = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = ZB.warp, Parent = stage }), a = math.random() * TAU, d = math.random(), w = rand(0.8, 2.4), h = math.random() * 360 })
		end
	end
	local s = Cookie.pop("warp")
	local sp = (1 + ctx.heat * 3 + (ctx.fever and 3 or 0)) * (ctx.reduced and 0.4 or 1)
	local maxD = math.sqrt(ctx.W ^ 2 + ctx.H ^ 2) * 0.75
	local n = math.floor(80 * clamp(ctx.pm * 1.2, 0.35, 1))
	for i, w in warp :: { Streak } do
		if i > n then
			w.f.Visible = false
		else
			w.d += dt * sp * (0.12 + w.d * 1.4)
			if w.d > 1 then w.d = rand(0, 0.08); w.a = math.random() * TAU end
			local d0 = ctx.R * 1.1 + w.d * maxD
			local len = (12 + w.d * 110) * sp * 0.6
			local x, y = math.cos(w.a), math.sin(w.a)
			local dm = d0 + len / 2
			w.f.Visible = true
			w.f.Position = UDim2.fromOffset(ctx.CX + x * dm, ctx.CY + y * dm)
			w.f.Size = UDim2.fromOffset(len, math.max(1, w.w * (0.5 + w.d)))
			w.f.Rotation = math.deg(w.a)
			w.f.BackgroundColor3 = hq(K.hue(w.h), 70)
			w.f.BackgroundTransparency = 1 - clamp(w.d * 3, 0, 1) * 0.8 * s
		end
	end
end

---------------------------------------------------------------------------- pluie de cookies
type Drop = { im: ImageLabel, x: number, y: number, z: number, rot: number, vr: number }
local rain: { Drop }? = nil
local function stepRain(dt: number)
	if not V.cookie_rain then
		if rain then for _, d in rain do d.im.Visible = false end end
		return
	end
	if not rain then
		local rs: { Drop } = {}
		rain = rs
		for i = 1, 32 do
			table.insert(rs, { im = cookieImg(ZB.rain), x = math.random(), y = math.random(), z = 0.25 + (i / 32) * 0.75, rot = math.random() * TAU, vr = rand(-1.5, 1.5) })
		end
	end
	local s = Cookie.pop("cookie_rain")
	local skin = Cookie.skin()
	local n = math.floor(32 * clamp(ctx.pm, 0.4, 1))
	for i, d in rain :: { Drop } do
		if i > n then
			d.im.Visible = false
		else
			setCookieSkin(d.im, skin)
			d.y += (40 + 170 * d.z) * dt * (ctx.fever and 1.8 or 1) / ctx.H
			d.rot += d.vr * dt
			if d.y > 1.08 then d.y = -0.08; d.x = math.random() end
			d.im.Visible = true
			place(d.im, d.x * ctx.W, d.y * ctx.H, (6 + 15 * d.z) * s * 3.2)
			d.im.Rotation = math.deg(d.rot)
			d.im.ImageTransparency = 1 - (0.25 + 0.55 * d.z) * s
		end
	end
end

---------------------------------------------------------------------------- boule disco + spots
local disco: any = nil
function A.discoPos(): (number, number, number)
	local pl = ctx.play
	return pl.left + math.max(44, pl.width * 0.12), pl.top + math.max(46, pl.height * 0.15), clamp(ctx.R * 0.3, 20, 42)
end
local function stepDisco()
	if not V.disco then
		if disco then
			disco.ball.Visible, disco.str.Visible, disco.halo.Visible, disco.spark.Visible = false, false, false, false
			for _, sp in disco.spots do sp.g.Visible = false; sp.beam.Visible = false end
		end
		return
	end
	if not disco then
		disco = { spots = {} }
		disco.str = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(220, 220, 255), BackgroundTransparency = 0.4, AnchorPoint = Vector2.new(0.5, 0), ZIndex = ZB.ball, Parent = stage })
		disco.halo = glow(ZB.ball)
		disco.ball = sprite("fx:disco_ball", ZB.ball)
		if disco.ball:GetAttribute("noimg") then
			disco.ball.ImageTransparency = 0
			disco.ball.BackgroundTransparency = 0
			disco.ball.BackgroundColor3 = Color3.fromRGB(150, 150, 190)
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = disco.ball })
			new("UIStroke", { Color = C.stroke, Thickness = 2, Parent = disco.ball })
		end
		disco.spark = sprite(has("fx:spark") and "fx:spark" or "fx:star", ZB.ball)
		for _ = 1, 7 do
			local beam = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = ZB.disco, Parent = stage }, {
				new("UIGradient", { Transparency = NumberSequence.new(0.8, 1) }),
			})
			table.insert(disco.spots, { g = glow(ZB.disco), beam = beam })
		end
	end
	local s = Cookie.pop("disco")
	local bx, by, br = A.discoPos()
	local r = br * s
	local W, H, AT = ctx.W, ctx.H, ctx.AT
	local sz = math.min(W, H) * 0.42
	for i, sp in disco.spots do
		local i0 = i - 1
		local x = W * (0.5 + 0.46 * math.sin(AT * 0.45 * (1 + i0 * 0.13) + i0 * 1.3))
		local y = H * (0.5 + 0.42 * math.cos(AT * 0.37 * (1 + i0 * 0.11) + i0 * 2.1))
		local col = hq(K.hue(i0 * 51), 60)
		sp.g.Visible = not sp.g:GetAttribute("noimg")
		place(sp.g, x, y, sz)
		sp.g.ImageColor3 = col
		sp.g.ImageTransparency = 1 - 0.32 * s
		local dx, dy = x - bx, y - by
		local dl = math.sqrt(dx * dx + dy * dy)
		sp.beam.Visible = true
		sp.beam.Position = UDim2.fromOffset((x + bx) / 2, (y + by) / 2)
		sp.beam.Size = UDim2.fromOffset(dl, sz * 0.2)
		sp.beam.Rotation = math.deg(math.atan2(dy, dx))
		sp.beam.BackgroundColor3 = K.hsl(K.hue(i0 * 51), 1, 0.7)
		local gr = sp.beam:FindFirstChildOfClass("UIGradient")
		if gr then gr.Transparency = NumberSequence.new(1 - 0.18 * s, 1) end
	end
	local pl = ctx.play
	disco.str.Visible = true
	disco.str.Position = UDim2.fromOffset(bx, pl.top - 4)
	disco.str.Size = UDim2.fromOffset(1.5, math.max(0, by - r - pl.top + 4))
	disco.halo.Visible = not disco.halo:GetAttribute("noimg")
	place(disco.halo, bx, by, r * 4)
	disco.halo.ImageColor3 = hq(K.hue(0), 75)
	disco.halo.ImageTransparency = 0.4
	disco.ball.Visible = r > 1
	-- fx:disco_ball : boule de rayon 111 px dans une image de 256
	place(disco.ball, bx, by, disco.ball:GetAttribute("noimg") and r * 2 or r * 256 / 111)
	disco.ball.Rotation = 0
	disco.spark.Visible = not disco.spark:GetAttribute("noimg")
	local z = r * (1 + 0.5 * math.sin(AT * 5))
	place(disco.spark, bx - r * 0.35, by - r * 0.35, z)
end

---------------------------------------------------------------------------- pulsation sur le beat (116 BPM)
local beatAcc = 0
local beatGlow: ImageLabel? = nil
local function stepBeat(dt: number)
	if V.beat_pulse then
		beatAcc += dt
		local per = 60 / 116
		if beatAcc >= per then
			beatAcc -= per
			Cookie.beat()
			ctx.bgPulse = 1
			if ctx.fever and A.onBeatShake then A.onBeatShake(4) end
		end
		if not beatGlow then beatGlow = glow(ZB.beat) end
		local g = beatGlow :: ImageLabel
		g.Visible = ctx.bgPulse > 0.05 and not g:GetAttribute("noimg")
		if g.Visible then
			place(g, ctx.CX, ctx.CY, ctx.R * 5)
			g.ImageColor3 = hq(K.hue(0))
			g.ImageTransparency = 1 - ctx.bgPulse * 0.5
		end
	elseif beatGlow then
		beatGlow.Visible = false
	end
end

---------------------------------------------------------------------------- chat de stream
local CHAT_USERS = { { "xX_Crunch_Xx", "#ff5ea8" }, { "mamie_gameuse", "#ffd23c" }, { "cookieGOD", "#1ff4ff" }, { "brocoli_hater", "#3dff8a" }, { "pepite92", "#ff8a1f" }, { "lait_demi_ecreme", "#c9b6ff" }, { "RGB_enjoyer", "#ff2bd6" }, { "tkt_frr", "#b6ff3b" }, { "nocap_nico", "#7ab8ff" }, { "zinzin_du_four", "#ffb36f" } }
local CHAT_MSG = { "W", "POG", "GG", "no cap", "+1 abonné", "le cookie a trop d'aura", "ratio le brocoli", "CHAT C'EST RÉEL", "masterclass", "le goat", "aura +1000", "wsh le combo", "ça cuit ça cuit", "c'est validé", "il est chaud là", "W W W", "KEKW", "jpp", "trop fort frr", "le cookie a mangé" }
type Msg = { f: Frame, l: TextLabel, st: UIStroke, ic: ImageLabel, side: number, t0: number, y0: number, jit: number, w: number, hasIc: boolean }
local chat: { Msg } = {}
local chatFree: { Msg } = {}
local chatT = 1
local function chatSpawn()
	local narrow = ctx.play.width < 560
	if #chat >= (narrow and 3 or 7) then
		local old = table.remove(chat, 1) :: Msg
		old.f.Visible = false
		table.insert(chatFree, old)
	end
	local m = table.remove(chatFree)
	if not m then
		local f = new("Frame", { BackgroundColor3 = Color3.fromRGB(14, 6, 34), BackgroundTransparency = 0.15, AnchorPoint = Vector2.new(0, 0.5), ZIndex = ZB.chat, Parent = stage }, { new("UICorner", { CornerRadius = UDim.new(0, 9) }) })
		local st = new("UIStroke", { Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
		local l = K.txt("", 13, F.bold, C.ink, { RichText = true, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -10, 1, 0), ZIndex = ZB.chat, Parent = f })
		local ic = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(15, 15), ZIndex = ZB.chat, Parent = f })
		m = { f = f, l = l, st = st, ic = ic, side = 1, t0 = 0, y0 = 0, jit = 0, w = 100, hasIc = false }
	end
	local mm = m :: Msg
	local u = CHAT_USERS[math.random(#CHAT_USERS)]
	local msg = CHAT_MSG[math.random(#CHAT_MSG)]
	local icKey = math.random() < 0.35 and (math.random() < 0.5 and "ui:heart" or "ui:fire") or nil
	local fs = narrow and 11 or 13
	mm.l.TextSize = fs
	mm.l.Text = '<font color="' .. u[2] .. '">' .. u[1] .. ":</font> " .. msg
	local ok, bounds = pcall(TextService.GetTextSize, TextService, u[1] .. ": " .. msg, fs, Enum.Font.GothamBold, Vector2.new(1000, 50))
	mm.w = (ok and bounds.X or 120) + 20 + (icKey and 18 or 0)
	mm.hasIc = icKey ~= nil
	mm.ic.Visible = false
	if icKey then
		mm.ic.Image = ""
		mm.ic.Visible = K.setImg(mm.ic, icKey)
	end
	mm.side = #chat > 0 and -chat[#chat].side or 1
	mm.t0, mm.y0, mm.jit = ctx.T, rand(0.2, 0.6), rand(-10, 10)
	mm.f.Visible = true
	table.insert(chat, mm)
end
local function stepChat(dt: number)
	if V.chat then
		chatT -= dt
		if chatT <= 0 then
			chatT = ctx.fever and rand(0.3, 0.6) or rand(1.1, 2)
			chatSpawn()
		end
	end
	local s = V.chat and Cookie.pop("chat") or 1
	local pl, R, CX, CY, T = ctx.play, ctx.R, ctx.CX, ctx.CY, ctx.T
	local narrow = pl.width < 560
	for i = #chat, 1, -1 do
		local m = chat[i]
		local age = T - m.t0
		if age > 4.5 then
			m.f.Visible = false
			table.insert(chatFree, table.remove(chat, i) :: Msg)
		else
			local a = math.min(1, age / 0.2) * (age > 3.7 and 1 - (age - 3.7) / 0.8 or 1) * s
			local x
			if narrow then x = m.side < 0 and pl.left + 6 or pl.left + pl.width - m.w - 6
			else x = m.side < 0 and CX - R * 1.3 - m.w + m.jit or CX + R * 1.3 + m.jit end
			x = clamp(x, pl.left + 6, math.max(pl.left + 6, pl.left + pl.width - m.w - 6))
			local y = (narrow and CY - R * 0.25 or CY + R * m.y0) - age * 28
			local h = narrow and 20 or 24
			m.f.Position = UDim2.fromOffset(x, y)
			m.f.Size = UDim2.fromOffset(m.w, h)
			m.f.BackgroundTransparency = 1 - a * 0.9 * 0.85
			m.st.Color = K.hsl(K.hue(i * 50), 1, 0.65)
			m.st.Transparency = 1 - a * 0.7
			m.l.TextTransparency = 1 - a
			if m.hasIc then m.ic.ImageTransparency = 1 - a end
		end
	end
end

---------------------------------------------------------------------------- API
function A.setVis(vis: { [string]: number }) V = vis end
function A.setState(s: any)
	-- rebond de la parade quand un bâtiment est acheté
	if state and state.buildings and s and s.buildings then
		for id, n in s.buildings do
			if n > (state.buildings[id] or 0) then A.bounce(id) end
		end
	end
	state = s
end

function A.onTap()
	if V.chat and math.random() < (ctx.fever and 0.45 or 0.22) then chatSpawn() end
	if V.cursor_rgb then cursorTap = 1 end
end

function A.step(dt: number)
	cursorTap = math.max(0, cursorTap - dt * 5)
	stepRays()
	stepHole()
	stepWarp(dt)
	stepRain(dt)
	stepDisco()
	stepBeat(dt)
	stepParade()
	stepFire(dt)
	stepSaturn()
	stepOrbiters()
	stepStars()
	stepCursors()
	stepLightning(dt)
	stepChat(dt)
end

function A.init(context: any, stageFrame: Frame)
	ctx = context
	stage = stageFrame
end

return A
