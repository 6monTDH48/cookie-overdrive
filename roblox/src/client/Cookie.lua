-- COOKIE OVERDRIVE — le cookie principal (portage de stage.js drawMainCookie / onClick) :
-- image `cookie:<skin>` + accessoires `acc:<clé>[_niv]` superposés dans le même cadre 640×640 (r = 200),
-- respiration, balancement, écrasement / rebond au clic (ressorts du site), survol, rotation en Fièvre,
-- images rémanentes, glitch RVB, yeux laser.
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RS = game:GetService("ReplicatedStorage")

local D = require(RS:WaitForChild("Shared"):WaitForChild("GameData"))
local K = require(script.Parent:WaitForChild("Kit"))
local new, C = K.new, K.C
local clamp, lerp = K.clamp, K.lerp

local Cookie = {}
Cookie.built = false
local ctx: any = nil
local stage: Frame
local Z = 20 -- ZIndex du cookie dans le stage (derrière < 20 < devant)

-- l'image fait 640 px pour un rayon de 200 px : le cadre mesure 3,2 × r
local FRAME_K = 640 / 200
local BODY_KEYS = { "chips_xl", "crystals", "galaxy_core" }
local TOP_KEYS = { "glaze", "sprinkles", "holo", "rgb_rim", "face", "laser_eyes", "shades", "headphones", "bling", "crown", "halo" }
local EYE_X, EYE_Y = 0.28, -0.06

local root: Frame, spin: Frame, body: ImageLabel, fallbackDisc: Frame?
local shadow: ImageLabel
local hit: TextButton
local after: { Frame } = {}
local glitchR: ImageLabel, glitchC: ImageLabel
local pop: { [string]: number } = {}
local skinId = "classic"
local skinStyle = "classic"
local visNow: { [string]: number } = {}

-- ressorts (même état que `ck` dans stage.js)
local ck = { s = 1, sv = 0, sq = 0, sqv = 0, tilt = 0, tiltv = 0, hover = 0, pulse = 0, spin = 0, spinv = 0, drawR = 120, rot = 0, over = false,
	mouth = 0, cb = 0, cbv = 0, sw = 0, swv = 0, laser = 0, blink = -9, nextBlink = 2 }
Cookie.ck = ck
local glitchStart, nextGlitch, glitchOff = -9, 3, Vector2.zero
local shadowIsGlow = false
local CENTER = UDim2.fromScale(0.5, 0.5)

---------------------------------------------------------------------------- repli si l'image du cookie manque
local CHIPS = { { -0.45, 0.35 }, { 0.35, 0.45 }, { 0.05, -0.05 }, { -0.35, -0.4 }, { 0.5, -0.3 }, { -0.7, -0.05 }, { 0.15, 0.7 }, { 0.62, 0.15 } }
local function buildFallback(sk: any)
	if fallbackDisc then fallbackDisc:Destroy() end
	local disc = new("Frame", {
		Name = "FallbackCookie", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6),
		BackgroundColor3 = C.white, ZIndex = 1, Parent = spin,
	}, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIStroke", { Color = Color3.fromHex(sk.rim), Thickness = 4 }),
		new("UIGradient", { Rotation = 55, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex(sk.light)), ColorSequenceKeypoint.new(0.5, Color3.fromHex(sk.base)), ColorSequenceKeypoint.new(1, Color3.fromHex(sk.dark)) }) }),
	})
	for _, c in CHIPS do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + c[1] * 0.42, 0.5 + c[2] * 0.42), Size = UDim2.fromScale(0.14, 0.13),
			BackgroundColor3 = Color3.fromHex(sk.chip), Rotation = (c[1] * 97) % 40, ZIndex = 2, Parent = disc,
		}, { new("UICorner", { CornerRadius = UDim.new(0.4, 0) }) })
	end
	fallbackDisc = disc
end

-- style d'un skin (les skins Robux n'existent pas sur le site : l'exporteur les peint comme holo / classic / rainbow)
local STYLE = { hologram = "holo", vip = "holo", plasma = "rainbow", rainbow = "rainbow", robux = "classic", golden = "gold", lava = "lava", galaxy = "galaxy", diamond = "diamond", pixel = "pixel", void = "void" }
local applyAcc: () -> ()

function Cookie.setSkin(id: string)
	if id == skinId and (body.Image ~= "" or fallbackDisc ~= nil) and Cookie.built then return end
	Cookie.built = true
	skinId = id
	skinStyle = STYLE[id] or "classic"
	local sk = D.SKIN[id] or D.SKIN.classic
	body.Image = ""
	if K.trySet(body, "cookie:" .. id) then
		if fallbackDisc then fallbackDisc:Destroy(); fallbackDisc = nil end
		body.Visible = true
		glitchR.Image, glitchC.Image = "", ""
		K.trySet(glitchR, "cookie:" .. id)
		K.trySet(glitchC, "cookie:" .. id)
	else
		body.Visible = false
		buildFallback(sk)
	end
	for _, a in after do
		local st = a:FindFirstChildOfClass("UIStroke")
		if st then st.Color = Color3.fromHex(sk.rim) end
	end
	applyAcc() -- pépites XL teintées au skin, reflets / néon en forme de diamant
end
function Cookie.skin(): string return skinId end

---------------------------------------------------------------------------- accessoires
-- Chaque accessoire est une image `acc:*` dans le cadre 640 du cookie. Quelques-uns sont animés ici
-- comme sur le site : visage (clignement, bouche ouverte au clic, yeux cœur en Fièvre), yeux laser
-- (lueur qui pulse), ailes (battement, images fx:wing_left/right), couronne (rebond au clic),
-- auréole (flottement), lunettes (chute avec rebond), néon RVB (rotation).
-- Point d'ancrage de l'apparition élastique (en rayons, comme `begin(c, fx, k, ax, ay)` du site)
local ANCHOR: { [string]: { number } } = { glaze = { 0, -0.2 }, headphones = { 0, -0.4 }, bling = { 0, 0.7 }, crown = { 0.2, -0.9 }, halo = { 0, -1.3 } }
type Acc = { obj: GuiObject, sc: UIScale, key: string, parts: { ImageLabel } }
local acc: { [string]: Acc } = {}

local function accKey(k: string, lvl: number): string
	if k == "chips_xl" then
		local kk = "acc:chips_xl_" .. skinId
		if K.hasImg(kk) then return kk end
	elseif (k == "holo" or k == "rgb_rim") and skinStyle == "diamond" then
		local kk = "acc:" .. k .. "_diamond"
		if K.hasImg(kk) then return kk end
	elseif k == "laser_eyes" then
		return "fx:glow"
	elseif k == "wings" and K.hasImg("fx:wing_left") and K.hasImg("fx:wing_right") then
		return "fx:wings"
	end
	if lvl >= 2 then
		local kk = "acc:" .. k .. "_" .. lvl
		if K.hasImg(kk) then return kk end
	end
	return "acc:" .. k
end

local function layer(parent: Instance, z: number, key: string?): ImageLabel
	local im = new("ImageLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), ZIndex = z, Parent = parent,
	})
	if key then im.Visible = K.trySet(im, key) end
	return im
end

local function buildAcc(k: string, key: string, parent: Instance, z: number): Acc
	local holder = new("Frame", {
		Name = "Acc_" .. k, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), ZIndex = z, Parent = parent,
	})
	local a: Acc = { obj = holder, sc = new("UIScale", { Parent = holder }), key = key, parts = {} }
	if k == "face" then
		-- 1 normal · 2 clignement · 3 bouche ouverte · 4 Fièvre (yeux cœur)
		for i, v in { "acc:face", "acc:face_blink", "acc:face_open", "acc:face_fever" } do
			local im = layer(holder, i, K.hasImg(v) and v or "acc:face")
			im.Visible = im.Visible and i == 1
			a.parts[i] = im
		end
	elseif k == "laser_eyes" then
		for side = 1, 2 do
			local im = layer(holder, side, "fx:glow")
			im.ImageColor3 = Color3.fromHex("#ff2b3b")
			im.Position = UDim2.fromScale(0.5 + (side == 1 and -EYE_X or EYE_X) / FRAME_K, 0.5 + EYE_Y / FRAME_K)
			a.parts[side] = im
		end
	elseif key == "fx:wings" then
		-- racine de chaque aile en (±0,7 r ; −0,12 r) = centre de l'image, qui fait 512 px pour r = 176
		local wk = (512 / 176) / FRAME_K
		for side = 1, 2 do
			local im = layer(holder, side, side == 1 and "fx:wing_left" or "fx:wing_right")
			im.Size = UDim2.fromScale(wk, wk)
			im.Position = UDim2.fromScale(0.5 + (side == 1 and -0.7 or 0.7) / FRAME_K, 0.5 - 0.12 / FRAME_K)
			a.parts[side] = im
		end
	else
		a.parts[1] = layer(holder, 1, key)
	end
	return a
end

local function ensureAcc(k: string, lvl: number, parent: Instance, z: number)
	local key = accKey(k, lvl)
	local a = acc[k]
	if a and a.key == key then return end
	if a then a.obj:Destroy() end
	acc[k] = buildAcc(k, key, parent, z)
end

applyAcc = function()
	if not root then return end
	local vis = visNow
	-- ailes derrière le corps, clés « corps » qui tournent avec le cookie, clés « dessus »
	if vis.wings then ensureAcc("wings", vis.wings, root, 1) end
	for i, k in BODY_KEYS do
		if vis[k] then ensureAcc(k, vis[k], spin, 2 + i) end
	end
	for i, k in TOP_KEYS do
		if vis[k] then ensureAcc(k, vis[k], root, 10 + i) end
	end
	for k, a in acc do
		if not vis[k] then
			a.obj:Destroy()
			acc[k] = nil
		end
	end
end

-- vis = { [clé] = niveau } ; renvoie les clés nouvellement ajoutées
function Cookie.setVis(vis: { [string]: number }, silent: boolean?): { string }
	local added = {}
	for k in vis do
		if not visNow[k] then
			table.insert(added, k)
			if not silent then pop[k] = ctx.T end
		end
	end
	visNow = table.clone(vis)
	applyAcc()
	return added
end
function Cookie.pop(k: string): number
	local t0 = pop[k]
	if not t0 then return 1 end
	local p = (ctx.T - t0) / 0.75
	if p >= 1 then pop[k] = nil; return 1 end
	return ctx.reduced and K.easeOutCubic(p) or K.elasticOut(p)
end
function Cookie.markPop(k: string) pop[k] = ctx.T end
-- les lunettes tombent avec un rebond (drop() du site) au lieu de l'apparition élastique
local function shadesDrop(): number
	local t0 = pop.shades
	if not t0 then return 1 end
	local p = (ctx.T - t0) / 0.8
	if p >= 1 then return 1 end
	return K.bounceOut(p)
end

---------------------------------------------------------------------------- impulsions
function Cookie.tap(x: number, _y: number)
	ck.sqv = clamp(ck.sqv + 8, -13, 13)
	ck.sv = clamp(ck.sv - 1.3, -2.6, 2.6)
	ck.tiltv = clamp(ck.tiltv + clamp((x - ctx.CX) / ctx.R, -1, 1) * 2, -3.5, 3.5)
	ck.mouth = 1
	ck.cbv = clamp(ck.cbv - 2.2, -4, 4)
	ck.swv = clamp(ck.swv + (x < ctx.CX and 1 or -1) * 0.7, -2.5, 2.5)
end
-- supplément quand le serveur annonce un critique
function Cookie.crit(x: number)
	ck.sqv = clamp(ck.sqv + 5, -13, 13)
	ck.sv = clamp(ck.sv - 0.9, -2.6, 2.6)
	ck.tiltv = clamp(ck.tiltv + clamp((x - ctx.CX) / ctx.R, -1, 1) * 1.2, -3.5, 3.5)
	ck.cbv = clamp(ck.cbv - 1.2, -4, 4)
	ck.swv = clamp(ck.swv + (x < ctx.CX and 1 or -1) * 0.5, -2.5, 2.5)
end
function Cookie.kick(v: number) ck.sv -= v end
function Cookie.beat() ck.pulse = 1 end

function Cookie.isOver(x: number, y: number): boolean
	local dx, dy = x - ctx.CX, y - ctx.CY
	return math.sqrt(dx * dx + dy * dy) <= ctx.R * math.max(1, ck.s) * (1 + 0.05 * ck.hover) * 1.02
end

function Cookie.eyePos(side: number): Vector2
	local r = ck.drawR
	local co, si = math.cos(ck.rot), math.sin(ck.rot)
	local lx, ly = side * EYE_X * r * (1 + 0.14 * ck.sq), EYE_Y * r * (1 - 0.14 * ck.sq)
	return Vector2.new(ctx.CX + lx * co - ly * si, ctx.CY + lx * si + ly * co)
end

---------------------------------------------------------------------------- yeux laser
type Laser = { beams: { Frame }, eyeGlow: { ImageLabel }, hitGlow: ImageLabel, x: number, y: number, t0: number }
local lasers: { Laser } = {}
local laserFree: { Laser } = {}
local frontLayer: Frame
local function glowImg(parent: Instance, z: number, col: Color3): ImageLabel
	local im = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = col, ZIndex = z, Parent = parent })
	if not K.trySet(im, "fx:glow") then im.Visible = false; im:SetAttribute("noimg", true) end
	return im
end
function Cookie.laser(x: number, y: number)
	if #lasers > 5 then
		local old = table.remove(lasers, 1) :: Laser
		for _, b in old.beams do b.Visible = false end
		for _, g in old.eyeGlow do g.Visible = false end
		old.hitGlow.Visible = false
		table.insert(laserFree, old)
	end
	local L = table.remove(laserFree)
	if not L then
		local beams = {}
		for _ = 1, 2 do
			table.insert(beams, new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 30, 50), ZIndex = 1, Parent = frontLayer }))
			table.insert(beams, new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromHex("#ff3b4f"), ZIndex = 2, Parent = frontLayer }))
			table.insert(beams, new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.white, ZIndex = 3, Parent = frontLayer }))
		end
		L = { beams = beams, eyeGlow = { glowImg(frontLayer, 4, Color3.fromHex("#ff2b3b")), glowImg(frontLayer, 4, Color3.fromHex("#ff2b3b")) }, hitGlow = glowImg(frontLayer, 4, Color3.fromHex("#ff6b3b")), x = 0, y = 0, t0 = 0 }
	end
	local l = L :: Laser
	l.x, l.y, l.t0 = x, y, ctx.T
	table.insert(lasers, l)
	ck.laser = 1
end
local function updateLasers()
	for i = #lasers, 1, -1 do
		local L = lasers[i]
		local k = (ctx.T - L.t0) / 0.24
		if k >= 1 then
			for _, b in L.beams do b.Visible = false end
			for _, g in L.eyeGlow do g.Visible = false end
			L.hitGlow.Visible = false
			table.insert(laserFree, table.remove(lasers, i) :: Laser)
		else
			local a = 1 - k * k
			for s = 1, 2 do
				local side = s == 1 and -1 or 1
				local e = Cookie.eyePos(side)
				local dx, dy = L.x - e.X, L.y - e.Y
				local d = math.sqrt(dx * dx + dy * dy)
				if d < ctx.R * 0.2 then
					dx, dy = L.x - ctx.CX, L.y - ctx.CY
					d = math.sqrt(dx * dx + dy * dy)
					if d < 1 then dx, dy, d = 0, -1, 1 end
				end
				local len = 3000
				local mid = UDim2.fromOffset(e.X + dx / d * len / 2, e.Y + dy / d * len / 2)
				local rot = math.deg(math.atan2(dy, dx))
				local widths, trs = { 13, 4.5, 1.6 }, { 0.72, 0, 0 }
				for j = 1, 3 do
					local b = L.beams[(s - 1) * 3 + j]
					b.Visible = true
					b.Position, b.Size, b.Rotation = mid, UDim2.fromOffset(len, widths[j]), rot
					b.BackgroundTransparency = 1 - (1 - trs[j]) * a
				end
				local g = L.eyeGlow[s]
				if not g:GetAttribute("noimg") then
					g.Visible = true
					g.Position = UDim2.fromOffset(e.X, e.Y)
					g.Size = UDim2.fromOffset(ctx.R * 0.5, ctx.R * 0.5)
					g.ImageTransparency = 1 - a
				end
			end
			if not L.hitGlow:GetAttribute("noimg") then
				local s = ctx.R * 0.6 * (1 + k)
				L.hitGlow.Visible = true
				L.hitGlow.Position = UDim2.fromOffset(L.x, L.y)
				L.hitGlow.Size = UDim2.fromOffset(s, s)
				L.hitGlow.ImageTransparency = 1 - a
			end
		end
	end
end

---------------------------------------------------------------------------- boucle
function Cookie.step(dt: number)
	local T, AT, R = ctx.T, ctx.AT, ctx.R
	ck.sv += ((1 - ck.s) * 260 - ck.sv * 12) * dt
	ck.s += ck.sv * dt
	ck.sqv += (-ck.sq * 320 - ck.sqv * 10) * dt
	ck.sq += ck.sqv * dt
	ck.tiltv += (-ck.tilt * 120 - ck.tiltv * 9) * dt
	ck.tilt += ck.tiltv * dt
	ck.hover = lerp(ck.hover, ck.over and 1 or 0, 1 - math.exp(-dt * 10))
	ck.pulse *= math.exp(-dt * 6)
	ck.spinv = lerp(ck.spinv, ctx.fever and 3.4 or 0, 1 - math.exp(-dt * 2))
	ck.spin += ck.spinv * dt
	ck.cbv += (-ck.cb * 220 - ck.cbv * 9) * dt
	ck.cb += ck.cbv * dt
	ck.swv += (-ck.sw * 40 - ck.swv * 2.5) * dt
	ck.sw += ck.swv * dt
	ck.mouth = math.max(0, ck.mouth - dt * 3)
	ck.laser = math.max(0, ck.laser - dt * 4)
	if T > ck.nextBlink then ck.blink = T; ck.nextBlink = T + K.rand(2.2, 5) end

	local s = clamp(ck.s, 0.82, 1.18) * (1 + 0.05 * ck.hover) * (1 + 0.018 * math.sin(AT * 2.3)) * (1 + 0.05 * ck.pulse)
	local r = R * s
	ck.drawR = r
	ck.rot = math.sin(AT * 0.9) * 0.045 + clamp(ck.tilt, -0.2, 0.2)
	local sq = clamp(ck.sq, -0.8, 0.8)
	local side = r * FRAME_K
	local CX, CY = ctx.CX, ctx.CY

	-- glitch RVB périodique
	local vis = visNow
	if vis.glitch and T > nextGlitch then
		glitchStart = T
		nextGlitch = T + (ctx.fever and K.rand(0.6, 1.5) or K.rand(2, 4))
		glitchOff = Vector2.new(K.rand(-0.1, 0.1) * R, K.rand(-0.03, 0.03) * R)
	end
	local glitching = vis.glitch and T - glitchStart < 0.15
	local jx, jy = 0, 0
	if glitching then jx, jy = glitchOff.X * (math.random() < 0.5 and 1 or -1), glitchOff.Y end

	root.Position = UDim2.fromOffset(CX + jx, CY + jy)
	root.Size = UDim2.fromOffset(side * (1 + 0.14 * sq), side * (1 - 0.14 * sq))
	root.Rotation = math.deg(ck.rot)
	spin.Rotation = math.deg(ck.spin)

	-- ombre portée (fx:shadow : dégradé noir 50 % → 0 sur 1,15 r, image = 2,3 r)
	shadow.Position = UDim2.fromOffset(CX + R * 0.05, CY + R * 0.16)
	local shd = r * (shadowIsGlow and 2.6 or 2.3)
	shadow.Size = UDim2.fromOffset(shd, shd)

	-- zone de clic
	hit.Position = UDim2.fromOffset(CX, CY)
	hit.Size = UDim2.fromOffset(R * 2.1, R * 2.1)

	-- skins animés
	if skinStyle == "holo" then
		local n = math.sin(T * 37) * math.sin(T * 23.3)
		body.ImageTransparency = 1 - (n > 0.93 and 0.45 or 0.85 + 0.15 * math.sin(T * 9))
	else
		body.ImageTransparency = 0
	end

	-- images rémanentes prismatiques
	if vis.afterimage then
		local ps = Cookie.pop("afterimage")
		for i, a in after do
			local ox = math.sin(AT * 2.4 - i * 0.5) * R * 0.1 * i * ps
			local oy = math.cos(AT * 1.9 - i * 0.5) * R * 0.055 * i * ps
			a.Visible = true
			a.Position = UDim2.fromOffset(CX + ox, CY + oy)
			local d = r * 2 * 0.955 * (1 + 0.02 * i)
			a.Size = UDim2.fromOffset(d, d)
			a.Rotation = math.deg(ck.rot - i * 0.05)
			a.BackgroundColor3 = K.hsl(K.hue(i * 70), 1, 0.6)
			a.BackgroundTransparency = 1 - (0.3 - i * 0.05) * ps
			local st = a:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = K.hsl(K.hue(i * 70 + 30), 1, 0.7)
				st.Transparency = 1 - 0.5 * ps
			end
		end
	elseif after[1].Visible then
		for _, a in after do a.Visible = false end
	end

	-- dédoublement RVB pendant le glitch
	if glitching and body.Visible then
		local d = R * 0.07 * (ctx.fever and 1.6 or 1)
		glitchR.Visible, glitchC.Visible = true, true
		glitchR.Position = UDim2.fromOffset(CX - d, CY)
		glitchC.Position = UDim2.fromOffset(CX + d, CY)
		glitchR.Size = root.Size
		glitchC.Size = root.Size
		glitchR.Rotation, glitchC.Rotation = root.Rotation, root.Rotation
	elseif glitchR.Visible then
		glitchR.Visible, glitchC.Visible = false, false
	end

	-- accessoires : apparition élastique autour de leur ancre + petites animations du site
	for k, a in acc do
		local ps = k == "shades" and 1 or Cookie.pop(k)
		a.sc.Scale = math.max(0.001, ps)
		local an = ANCHOR[k]
		local ox, oy = 0, 0
		if an and ps ~= 1 then ox, oy = an[1] * (1 - ps), an[2] * (1 - ps) end
		if k == "crown" then
			oy += ck.cb
		elseif k == "halo" then
			oy += math.sin(T * 2) * 0.05
		elseif k == "shades" then
			local d = shadesDrop()
			oy -= (1 - d) * 2.4
			a.obj.Rotation = math.deg((1 - d) * 0.5)
			a.parts[1].ImageTransparency = 1 - clamp(d * 3, 0, 1)
		elseif k == "rgb_rim" and skinStyle ~= "diamond" then
			-- dégradé conique qui tourne à 1,6 rad/s pendant que la teinte avance de 60°/s → ~32°/s à l'écran
			a.obj.Rotation = (T * 31.7) % 360
		elseif k == "face" then
			local f = vis.face and a.parts
			if f then
				local idx = ctx.fever and 4 or (T - ck.blink < 0.13 and 2) or (ck.mouth > 0.06 and 3) or 1
				for i, im in f do
					local want = i == idx
					if im.Visible ~= want then im.Visible = want end
				end
			end
		elseif k == "laser_eyes" then
			local kk = clamp(0.35 + 0.2 * math.sin(T * 6) + ck.laser * 0.9, 0, 1)
			local sz = (0.34 + ck.laser * 0.35) / FRAME_K
			for _, im in a.parts do
				im.Size = UDim2.fromScale(sz, sz)
				im.ImageTransparency = 1 - kk
			end
		elseif k == "wings" and #a.parts == 2 then
			local flap = math.sin(T * (3 + (ctx.heat or 0) * 10)) * 0.24
			a.parts[1].Rotation = math.deg(flap)
			a.parts[2].Rotation = math.deg(-flap)
		end
		if ox ~= 0 or oy ~= 0 or a.obj.Position ~= CENTER then
			a.obj.Position = UDim2.fromScale(0.5 + ox / FRAME_K, 0.5 + oy / FRAME_K)
		end
	end

	updateLasers()
end

---------------------------------------------------------------------------- entrées
local function inputPos(input: InputObject): Vector2
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseMovement then
		return UserInputService:GetMouseLocation()
	end
	local inset = GuiService:GetGuiInset()
	return Vector2.new(input.Position.X, input.Position.Y) + inset
end

function Cookie.init(context: any, stageFrame: Frame, front: Frame, onTap: (Vector2) -> ())
	ctx = context
	stage = stageFrame
	frontLayer = front
	shadow = new("ImageLabel", { Name = "CookieShadow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = Z - 3, Parent = stage })
	if not K.trySet(shadow, "fx:shadow") then
		shadowIsGlow = true
		shadow.ImageColor3, shadow.ImageTransparency = Color3.new(0, 0, 0), 0.45
		if not K.trySet(shadow, "fx:glow") then shadow.Visible = false end
	end
	for i = 1, 4 do
		after[i] = new("Frame", { Name = "Afterimage" .. i, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.hot, Visible = false, ZIndex = Z - 2, Parent = stage }, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			new("UIStroke", { Color = C.white, Thickness = 2 }),
		})
	end
	glitchR = new("ImageLabel", { Name = "GlitchR", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = Color3.fromRGB(255, 0, 70), ImageTransparency = 0.35, Visible = false, ZIndex = Z - 1, Parent = stage })
	glitchC = new("ImageLabel", { Name = "GlitchC", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = Color3.fromRGB(0, 220, 255), ImageTransparency = 0.35, Visible = false, ZIndex = Z - 1, Parent = stage })
	root = new("Frame", { Name = "Cookie", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = Z, Parent = stage })
	spin = new("Frame", { Name = "Spin", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = root })
	body = new("ImageLabel", { Name = "Body", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = spin })
	hit = new("TextButton", {
		Name = "CookieHit", Text = "", BackgroundTransparency = 1, AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = Z + 1,
		Selectable = false, Parent = stage,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = hit })
	hit.MouseEnter:Connect(function() ck.over = true end)
	hit.MouseLeave:Connect(function() ck.over = false end)
	hit.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		local pos = inputPos(input)
		local ap, as = hit.AbsolutePosition, hit.AbsoluteSize
		local inside = pos.X >= ap.X - 40 and pos.X <= ap.X + as.X + 40 and pos.Y >= ap.Y - 40 and pos.Y <= ap.Y + as.Y + 40
		if not inside then
			pos = ap + as / 2 -- conversion de coordonnées douteuse : on compte le clic au centre
		elseif not Cookie.isOver(pos.X, pos.Y) then
			return
		end
		onTap(pos)
	end)
	Cookie.setSkin("classic")
end

Cookie.Z = Z
return Cookie
