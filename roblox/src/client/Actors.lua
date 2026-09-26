-- COOKIE OVERDRIVE — les « acteurs » du stage (stage.js : petsDraw, goldensDraw, bossDraw, projDraw) :
-- pets équipés autour du cookie (lueur de rareté, saut au clic, tirs vers le cookie), cookies dorés
-- (rayons tournants, apparition élastique, clignotement avant de disparaître, clic), boss (entrée,
-- recul, barre de PV, nom, défaite / fuite) et projectiles vers le boss.
local RS = game:GetService("ReplicatedStorage")

local D = require(RS:WaitForChild("Shared"):WaitForChild("GameData"))
local K = require(script.Parent:WaitForChild("Kit"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local Cookie = require(script.Parent:WaitForChild("Cookie"))
local new, C, F = K.new, K.C, K.F
local clamp, rand, lerp = K.clamp, K.rand, K.lerp

local A = {}
local ctx: any = nil
local stage: Frame
local ZP, ZG, ZB, ZJ = 27, 28, 29, 30 -- pets, dorés, boss, projectiles
local INK = Color3.fromHex("#1a0b33")
local GOLD = Color3.fromHex("#ffc93c")

local function hq(h: number, l: number?): Color3 return K.hsl(math.floor(h / 15 + 0.5) * 15, 1, (l or 60) / 100) end
local function glow(z: number, col: Color3?, parent: Instance?): ImageLabel
	local im = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z, Parent = parent or stage })
	if col then im.ImageColor3 = col end
	if not K.trySet(im, "fx:glow") then im.ImageTransparency = 1; im:SetAttribute("noimg", true) end
	return im
end
local function place(o: GuiObject, x: number, y: number, w: number, h: number?)
	o.Position = UDim2.fromOffset(x, y)
	o.Size = UDim2.fromOffset(w, h or w)
end
local function ellipse(z: number): Frame
	return new("Frame", { BackgroundColor3 = C.black, AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = z, Parent = stage }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end
local function glowA(im: ImageLabel, a: number)
	if im:GetAttribute("noimg") then return end
	im.ImageTransparency = 1 - clamp(a, 0, 1)
end

---------------------------------------------------------------------------- pets
local SLOTS = { { -1.78, 0.25 }, { 1.78, 0.25 }, { 1.5, -1.12 }, { -1.5, -1.12 } }
type Pet = {
	uid: number, id: string, lvl: number, slot: number, born: number, hop: number, hopv: number, nextShot: number,
	glow: ImageLabel, glow2: ImageLabel, shadow: Frame, icon: ImageLabel, badge: Frame, badgeTxt: TextLabel, badgeStroke: UIStroke,
}
local pets: { Pet } = {}
local petKey = ""

local function rarityOf(id: string): any
	local def = D.PET[id]
	return def and D.rarities[def.rarity] or D.rarities.common
end
local function petCol(p: Pet, i: number): Color3
	local def = D.PET[p.id]
	if def and def.rarity == "mythic" then return hq(K.hue(i * 60)) end
	return Color3.fromHex(rarityOf(p.id).color)
end
local function petPos(p: Pet): (number, number, number)
	local R, CX, CY, pl = ctx.R, ctx.CX, ctx.CY, ctx.play
	local sz = clamp(R * 0.46, 30, 70)
	local s = SLOTS[p.slot] or SLOTS[1]
	return clamp(CX + s[1] * R, pl.left + sz * 0.6, pl.left + pl.width - sz * 0.6), CY + s[2] * R, sz
end
local function destroyPet(p: Pet)
	for _, o in { p.glow, p.glow2, p.shadow, p.icon, p.badge } do (o :: Instance):Destroy() end
end
local function makePet(uid: number, id: string, lvl: number, slot: number): Pet
	local g = glow(ZP)
	local g2 = glow(ZP)
	local shadow = ellipse(ZP)
	local icon = K.img("pet:" .. id, { AnchorPoint = Vector2.new(0.5, 0.5), ScaleType = Enum.ScaleType.Fit, ZIndex = ZP, Parent = stage })
	local badge = new("Frame", {
		BackgroundColor3 = INK, AnchorPoint = Vector2.new(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), ZIndex = ZP, Parent = stage,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }) })
	local bst = new("UIStroke", { Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = badge })
	local bt = K.txt("", 11, F.num, C.white, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, ZIndex = ZP, Parent = badge })
	return {
		uid = uid, id = id, lvl = lvl, slot = slot, born = ctx.T, hop = 0, hopv = 0, nextShot = ctx.T + rand(2, 5),
		glow = g, glow2 = g2, shadow = shadow, icon = icon, badge = badge, badgeTxt = bt, badgeStroke = bst,
	}
end

-- state.pets = { {uid, id, lvl} }, state.equipped = { uid }
function A.setPets(state: any)
	if not state or not state.pets then return end
	local list = {}
	local byUid = {}
	for _, p in state.pets do byUid[p.uid] = p end
	for _, uid in state.equipped or {} do
		local p = byUid[uid]
		if p and D.PET[p.id] and #list < #SLOTS then table.insert(list, p) end
	end
	local parts = {}
	for i, p in list do parts[i] = p.uid .. ":" .. p.id .. ":" .. p.lvl end
	local key = table.concat(parts, ",")
	if key == petKey then return end
	petKey = key
	local old = pets
	pets = {}
	for i, p in list do
		local keep: Pet? = nil
		for j, o in old do
			if o.uid == p.uid then keep = o; table.remove(old, j); break end
		end
		if keep then
			keep.slot, keep.lvl = i, p.lvl
			table.insert(pets, keep)
		else
			table.insert(pets, makePet(p.uid, p.id, p.lvl, i))
		end
	end
	for _, o in old do destroyPet(o) end
end

-- éclosion d'un pet équipé : il réapparaît avec l'effet élastique + étincelles
function A.petHatched(id: string)
	for _, p in pets do
		if p.id == id then
			p.born = ctx.T
			local x, y = petPos(p)
			Fx.sparkleRing(x, y, 12, 26, nil, 260)
			Fx.burst(x, y, 20, { speed = 300, size = 18 })
		end
	end
end

type Shot = { g: ImageLabel, s: ImageLabel, x0: number, y0: number, t0: number, col: Color3, on: boolean }
local shots: { Shot } = {}
local function shoot(x: number, y: number, col: Color3)
	local sh: Shot? = nil
	for _, s in shots do if not s.on then sh = s; break end end
	if not sh then
		local s = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = ZJ, Parent = stage })
		if not K.trySet(s, "fx:spark") then s.Visible = false; s:SetAttribute("noimg", true) end
		local nsh: Shot = { g = glow(ZJ), s = s, x0 = 0, y0 = 0, t0 = 0, col = col, on = false }
		table.insert(shots, nsh)
		sh = nsh
	end
	local o = sh :: Shot
	o.on, o.x0, o.y0, o.t0, o.col = true, x, y, ctx.T, col
	o.g.ImageColor3 = col
end

local function stepPets(dt: number)
	local T, AT, R, CX, CY = ctx.T, ctx.AT, ctx.R, ctx.CX, ctx.CY
	for i, p in pets do
		local x0, y0, sz0 = petPos(p)
		p.hopv -= 1400 * dt
		p.hop += p.hopv * dt
		if p.hop < 0 then p.hop, p.hopv = 0, 0 end
		local age = T - p.born
		local s = ctx.reduced and K.easeOutCubic(age / 0.5) or K.elasticOut(age / 0.7)
		local sz = sz0 * s
		local x = x0
		local y = y0 + math.sin(AT * 2 + (i - 1) * 2.1) * R * 0.05 - p.hop
		local tilt = math.sin(AT * 1.6 + (i - 1)) * 0.1 + (p.hop > 0 and -0.15 * math.sign(x0 - CX) or 0)
		local gcol = petCol(p, i - 1)
		local mythic = (D.PET[p.id] and D.PET[p.id].rarity) == "mythic"
		place(p.glow, x, y, sz * 2.1)
		p.glow.ImageColor3 = gcol
		glowA(p.glow, 0.55 + 0.25 * math.sin(AT * 3 + (i - 1)))
		p.glow2.Visible = mythic and not p.glow2:GetAttribute("noimg")
		if mythic then
			place(p.glow2, x + math.cos(AT * 3) * sz * 0.2, y + math.sin(AT * 3) * sz * 0.2, sz * 1.6)
			p.glow2.ImageColor3 = hq(K.hue((i - 1) * 60 + 120))
			glowA(p.glow2, 0.5)
		end
		place(p.shadow, x0, y0 + sz0 * 0.55, sz * 0.72 * math.max(0.3, 1 - p.hop / 120), sz * 0.18)
		p.shadow.BackgroundTransparency = 0.65
		place(p.icon, x, y, sz)
		p.icon.Rotation = math.deg(tilt)
		p.badge.Visible = p.lvl > 1
		if p.lvl > 1 then
			p.badge.Position = UDim2.fromOffset(x + sz * 0.32, y + sz * 0.42)
			p.badgeStroke.Color = gcol
			local t = "Nv." .. p.lvl
			if p.badgeTxt.Text ~= t then p.badgeTxt.Text = t end
		end
		if T > p.nextShot and not ctx.paused then
			p.nextShot = T + rand(3, 6.5)
			shoot(x, y, gcol)
		end
	end
	for _, s in shots do
		if s.on then
			local k = (T - s.t0) / 0.5
			if k >= 1 then
				s.on = false
				s.g.Visible, s.s.Visible = false, false
				local a = math.atan2(s.y0 - CY, s.x0 - CX)
				Fx.burst(CX + math.cos(a) * R * 0.8, CY + math.sin(a) * R * 0.8, 8, { cols = { s.col, C.white }, speed = 160, size = 12, life = 0.5 })
				Cookie.kick(0.25)
			else
				local e = K.easeInOut(k)
				local x = lerp(s.x0, CX, e)
				local y = lerp(s.y0, CY, e) - math.sin(k * math.pi) * R * 0.5
				s.g.Visible = not s.g:GetAttribute("noimg")
				place(s.g, x, y, R * 0.35)
				s.s.Visible = not s.s:GetAttribute("noimg")
				place(s.s, x, y, R * 0.28 * (1 + 0.3 * math.sin(T * 30)))
			end
		end
	end
end

function A.onTap()
	for _, p in pets do
		if p.hop < 6 then p.hopv = rand(240, 340) end
	end
end

---------------------------------------------------------------------------- cookies dorés
type Gold = {
	id: number, x: number, y: number, born: number, life: number, seen: number, rays: ImageLabel, ck: ImageLabel, hit: TextButton,
	px: number, py: number, r: number, gone: boolean,
}
local golds: { [number]: Gold } = {}
local caught: { [number]: boolean } = {}
local onGolden: (id: number) -> () = function() end
local SPARK_COLS = { Color3.fromHex("#ffd23c"), Color3.fromHex("#fff3a0") }

local function goldPx(g: Gold): (number, number)
	local pl = ctx.play
	return pl.left + g.x * pl.width, pl.top + g.y * pl.height
end
local function removeGold(g: Gold)
	g.rays:Destroy(); g.ck:Destroy(); g.hit:Destroy()
	golds[g.id] = nil
end
local function makeGold(e: any): Gold
	local rays = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = ZG, Parent = stage })
	local ck = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = ZG, Parent = stage })
	local split = K.hasImg("fx:golden_rays") and K.hasImg("cookie:golden")
	if split then
		-- rayons + lueur (tournent) et cookie doré (se balance) séparés, comme goldensDraw()
		K.trySet(rays, "fx:golden_rays")
		K.trySet(ck, "cookie:golden")
		ck:SetAttribute("k", 3.2)
	elseif K.trySet(ck, "golden") then
		rays.Visible = false
		ck:SetAttribute("k", 6.4) -- image figée : cookie r = 40 dans 256 px
	else
		rays.Visible = false
		K.setImg(ck, "ui:golden", "🍪")
		ck:SetAttribute("k", 2.4)
	end
	local hit = new("TextButton", {
		Text = "", BackgroundTransparency = 1, AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = ZG + 1, Selectable = false, Parent = stage,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local g: Gold = {
		id = e.id, x = e.x, y = e.y, born = ctx.T - math.max(0, 13 - (e.left or 13)), life = 13, seen = ctx.T,
		rays = rays, ck = ck, hit = hit, px = 0, py = 0, r = 30, gone = false,
	}
	hit.Activated:Connect(function()
		if g.gone or caught[g.id] then return end
		caught[g.id] = true
		g.gone = true
		onGolden(g.id)
	end)
	return g
end

-- live.golden = { {id, x, y, left} }
function A.setGolden(list: { any }?)
	local seen: { [number]: boolean } = {}
	for _, e in (list or {}) :: { any } do
		seen[e.id] = true
		if not caught[e.id] then
			local g = golds[e.id]
			if not g then
				g = makeGold(e)
				golds[e.id] = g
				local x, y = goldPx(g)
				Fx.sparkleRing(x, y, 10, 12, SPARK_COLS, 160)
			end
			local gg = g :: Gold
			gg.life = (ctx.T - gg.born) + (e.left or 0)
		end
	end
	for id, g in golds do
		if not seen[id] and not g.gone then
			-- expiré (ou pris ailleurs) : petit nuage de lueurs
			Fx.burst(g.px, g.py, 10, { cols = { Color3.fromHex("#b3a6dd"), Color3.fromHex("#ffe9a0") }, speed = 90, size = 18, life = 0.7, type = "glow" })
			removeGold(g)
		end
	end
end

-- réponse du serveur à un clic sur un doré : { label, color } (ou nil si raté)
function A.goldenCaught(id: number, res: any)
	local g = golds[id]
	local x, y = ctx.CX, ctx.CY
	if g then
		x, y = g.px, g.py
		removeGold(g)
	end
	if type(res) ~= "table" then return end
	local R = ctx.R
	Fx.burst(x, y, 50, { cols = { Color3.fromHex("#ffd23c"), Color3.fromHex("#fff3a0"), Color3.fromHex("#ff8a00"), C.white }, speed = 520, size = 20, life = 1 })
	Fx.confettiBurst(x, y, 24, { speed = 520 })
	Fx.ring(x, y, 20, R * 2.2, 0.6, 14, Color3.fromHex("#ffd23c"))
	Fx.ring(x, y, 10, R * 1.4, 0.45, 8, "rgb")
	local label = tostring(res.label or "")
	local rgb = string.find(label, "RGB", 1, true) ~= nil
	Fx.label(label, rgb and "rgb" or (res.color and Color3.fromHex(res.color) or Color3.fromHex("#ffd23c")), 1)
	Fx.shake(8)
	Fx.flash(0.35, Color3.fromRGB(255, 220, 120))
	if string.find(label, "GEMMES", 1, true) then Fx.iconRain("ui:gem", 14) end
end

local function stepGolden()
	local T, AT, R = ctx.T, ctx.AT, ctx.R
	local gr = clamp(R * 0.28, 24, 40)
	for id, g in golds do
		if g.gone then
			g.rays.Visible, g.ck.Visible, g.hit.Visible = false, false, false
		else
			local age = T - g.born
			local rem = g.life - age
			local a = rem < 2 and clamp(rem / 2, 0, 1) * (0.75 + 0.25 * math.sin(T * 18)) or 1
			local s = ctx.reduced and K.easeOutCubic(age / 0.4) or K.elasticOut(age / 0.6)
			local x0, y0 = goldPx(g)
			local x, y = x0, y0 + math.sin(AT * 2.2 + id) * 6
			local r = gr * s
			g.px, g.py = x, y
			if g.rays.Visible then
				place(g.rays, x, y, r * 6.4)
				g.rays.Rotation = math.deg(AT * 0.7)
				g.rays.ImageTransparency = 1 - a * (0.85 + 0.15 * math.sin(T * 5))
			end
			local kk = g.ck:GetAttribute("k") or 3.2
			place(g.ck, x, y, r * kk)
			g.ck.Rotation = math.deg(math.sin(AT * 1.5 + id) * 0.25)
			g.ck.ImageTransparency = 1 - a
			local hr = math.max(40, gr * 1.35)
			place(g.hit, x, y, hr * 2)
			if math.random() < 0.12 * Fx.pm then
				Fx.spawn("star", x + rand(-r, r), y + rand(-r, r), rand(-20, 20), rand(-50, -10), 0.6, rand(10, 18), Color3.fromHex("#fff3a0"))
			end
		end
	end
end

---------------------------------------------------------------------------- boss
type BV = {
	id: string, name: string, color: Color3, t0: number, hpD: number, trail: number, flash: number, kb: number, kbv: number,
	state: string, tEnd: number, left: number, hp: number, maxHp: number,
}
local bv: BV? = nil
local bossUI: any = nil
local lastHp: number? = nil

local function bossIdByName(name: string?): string
	for _, b in D.bosses do
		if b.name == name then return b.id end
	end
	return "broccoli"
end
local function bossPos(): (number, number, number)
	local pl, R, CX = ctx.play, ctx.R, ctx.CX
	local size = math.max(60, R * 1.1)
	local right = pl.left + pl.width
	return math.min(right - size * 0.62, math.max(pl.left + pl.width * 0.8, CX + R * 1.45)), pl.top + pl.height * 0.34, size
end

local function buildBossUI()
	local ui: any = {}
	ui.glow = glow(ZB)
	ui.glowRed = glow(ZB, Color3.fromHex("#ff2b3b"))
	ui.shadow = ellipse(ZB)
	ui.img = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ScaleType = Enum.ScaleType.Fit, ZIndex = ZB, Parent = stage })
	ui.flash = glow(ZB, C.white)
	ui.name = K.txt("", 18, F.display, C.white, {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 24), AutomaticSize = Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = ZB, Parent = stage,
	})
	K.ol(ui.name, 3, INK)
	ui.bar = new("Frame", { BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = ZB, Parent = stage }, { new("UICorner", { CornerRadius = UDim.new(0, 9) }) })
	ui.track = new("Frame", { BackgroundColor3 = Color3.fromHex("#3a1030"), BorderSizePixel = 0, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), ZIndex = ZB, Parent = ui.bar }, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	ui.trail = new("Frame", { BackgroundColor3 = C.white, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = ZB, Parent = ui.track }, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	ui.fill = new("Frame", { BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = ZB, Parent = ui.track }, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	ui.fillGrad = new("UIGradient", { Color = ColorSequence.new(Color3.fromHex("#ff3d5e"), Color3.fromHex("#ff9a1f")), Parent = ui.fill })
	ui.shine = new("Frame", { BackgroundColor3 = C.white, BackgroundTransparency = 0.72, BorderSizePixel = 0, Position = UDim2.fromOffset(3, 2), ZIndex = ZB, Parent = ui.track }, { new("UICorner", { CornerRadius = UDim.new(0, 3) }) })
	ui.info = K.txt("", 12, F.num, C.ink, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(160, 16), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = ZB, Parent = stage })
	new("UIStroke", { Color = INK, Thickness = 1.5, Transparency = 0.3, Parent = ui.info })
	ui.laser = {}
	return ui
end
local function bossUIVisible(v: boolean)
	if not bossUI then return end
	for _, k in { "glow", "glowRed", "shadow", "img", "flash", "name", "bar", "info" } do bossUI[k].Visible = v end
end

local function bossHit(dmg: number, crit: boolean)
	local b = bv
	if not b then return end
	local x, y, size = bossPos()
	b.flash = 1
	b.kbv += crit and 700 or 380
	Fx.shake(crit and 9 or 3)
	Fx.text(x + rand(-20, 20), y - size * 0.2, "-" .. K.fmt(dmg), crit and "crit" or "dmg")
	Fx.burst(x - size * 0.25, y, crit and 18 or 8, { cols = { C.white, b.color, Color3.fromHex("#ffd23c") }, speed = crit and 420 or 260, size = 14, life = 0.5 })
end

-- projectiles vers le boss (un par clic tant qu'il est là)
type Proj = { t0: number, dur: number, kind: string, side: number, dmg: number, crit: boolean, hasHit: boolean, g: ImageLabel, ck: ImageLabel, beams: { Frame }, on: boolean }
local projs: { Proj } = {}
local function projObj(): Proj
	for _, p in projs do if not p.on then return p end end
	local ck = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = ZJ, Parent = stage })
	ck:SetAttribute("skin", "")
	local beams = {}
	for j, spec in { { Color3.fromRGB(255, 40, 60), 0.65, 12 }, { Color3.fromHex("#ff4d6d"), 0, 4 }, { C.white, 0, 1.5 } } do
		beams[j] = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = spec[1], BackgroundTransparency = spec[2], Size = UDim2.fromOffset(1, spec[3]), ZIndex = ZJ, Visible = false, Parent = stage })
		beams[j]:SetAttribute("a", spec[2])
		beams[j]:SetAttribute("w", spec[3])
	end
	local p: Proj = { t0 = 0, dur = 0.3, kind = "cookie", side = 1, dmg = 0, crit = false, hasHit = false, g = glow(ZJ, GOLD), ck = ck, beams = beams, on = false }
	table.insert(projs, p)
	return p
end
local lastProj: Proj? = nil
function A.fireAtBoss(laser: boolean)
	if not bv or (bv :: BV).state ~= "live" then return end
	local n = 0
	for _, p in projs do if p.on then n += 1 end end
	if n > 24 then return end
	local p = projObj()
	p.on, p.t0, p.kind, p.side, p.dmg, p.crit, p.hasHit = true, ctx.T, laser and "laser" or "cookie", math.random() < 0.5 and -1 or 1, 0, false, false
	p.dur = laser and 0.12 or 0.32
	lastProj = p
end
function A.critHint()
	if lastProj and ctx.T - lastProj.t0 < 0.4 then lastProj.crit = true end
end

local function stepProj()
	local T, R, CX, CY = ctx.T, ctx.R, ctx.CX, ctx.CY
	local bx, by, bsize = bossPos()
	local tx, ty = bx - bsize * 0.15, by
	local skin = Cookie.skin()
	for _, p in projs do
		if p.on then
			local k = (T - p.t0) / p.dur
			if k >= 1 then
				p.on = false
				p.g.Visible, p.ck.Visible = false, false
				for _, b in p.beams do b.Visible = false end
				if p.hasHit then bossHit(p.dmg, p.crit)
				else Fx.burst(tx, ty, 5, { cols = { C.white, Color3.fromHex("#ffd23c") }, speed = 180, size = 10, life = 0.35 }) end
				if lastProj == p then lastProj = nil end
			elseif p.kind == "laser" then
				local e = Cookie.eyePos(p.side)
				local dx, dy = tx - e.X, ty - e.Y
				local len = math.sqrt(dx * dx + dy * dy)
				for _, b in p.beams do
					b.Visible = true
					b.Position = UDim2.fromOffset((e.X + tx) / 2, (e.Y + ty) / 2)
					b.Size = UDim2.fromOffset(len, b:GetAttribute("w") or 2)
					b.Rotation = math.deg(math.atan2(dy, dx))
					b.BackgroundTransparency = 1 - (1 - (b:GetAttribute("a") or 0)) * (1 - k * 0.5)
				end
			else
				local e = K.easeInOut(k)
				local x = lerp(CX, tx, e)
				local y = lerp(CY - R * 0.3, ty, e) - math.sin(k * math.pi) * R * 0.6
				p.g.Visible = not p.g:GetAttribute("noimg")
				place(p.g, x, y, R * 0.45)
				if p.ck:GetAttribute("skin") ~= skin then
					p.ck:SetAttribute("skin", skin)
					p.ck.Image = ""
					if not K.trySet(p.ck, "cookie:" .. skin) then K.setImg(p.ck, "ui:cookie", "🍪") end
				end
				p.ck.Visible = true
				place(p.ck, x, y, R * 0.13 * 3.2)
				p.ck.Rotation = math.deg(k * 12)
			end
		end
	end
end

-- live.boss = { name, emoji, color, hp, maxHp, left } | nil
function A.setBoss(b: any)
	if b then
		local id = bossIdByName(b.name)
		if not bv or bv.state ~= "live" or bv.id ~= id then
			local nb: BV = {
				id = id, name = b.name or "BOSS", color = b.color and Color3.fromHex(b.color) or Color3.fromHex("#ff4d6d"), t0 = ctx.T,
				hpD = (b.hp or 1) / math.max(1, b.maxHp or 1), trail = 1, flash = 0, kb = 0, kbv = 0, state = "live", tEnd = 0,
				left = b.left or 30, hp = b.hp or 1, maxHp = b.maxHp or 1,
			}
			bv = nb
			lastHp = b.hp
			if not bossUI then bossUI = buildBossUI() end
			bossUI.img.Image = ""
			local f = bossUI.img:FindFirstChild("Fallback")
			if f then f:Destroy() end
			K.setImg(bossUI.img, "boss:" .. id, b.emoji)
			bossUI.name.Text = nb.name
		else
			local cur = bv :: BV
			cur.hp, cur.maxHp, cur.left = b.hp or cur.hp, b.maxHp or cur.maxHp, b.left or cur.left
			if lastHp and b.hp and b.hp < lastHp then
				local dmg = lastHp - b.hp
				local lp = lastProj
				if lp and lp.on and ctx.T - lp.t0 < 0.5 then
					lp.dmg += dmg
					lp.hasHit = true
				else
					bossHit(dmg, false)
				end
			end
			lastHp = b.hp
		end
	elseif bv and bv.state == "live" then
		-- disparu sans événement (l'événement Fx boss défaite / fuite arrive normalement avant)
		bv.state, bv.tEnd = "escape", ctx.T
	end
end
function A.bossDefeat()
	local x, y = bossPos()
	local b = bv
	local col = b and b.color or Color3.fromHex("#3dff6a")
	for _, p in projs do p.hasHit = false end
	local R = ctx.R
	Fx.burst(x, y, 160, { cols = { col, C.white, Color3.fromHex("#ffd23c"), Color3.fromHex("#ff4d6d") }, speed = 800, size = 24, life = 1.3 })
	Fx.confettiBurst(x, y, 50, { speed = 700, spread = 1.8 })
	Fx.ring(x, y, 20, R * 3.5, 0.8, 26, col)
	Fx.ring(x, y, 10, R * 2.2, 0.6, 14, "rgb")
	Fx.ring(x, y, 5, R * 1.2, 0.35, 10, C.white)
	Fx.flash(0.6)
	Fx.shake(20)
	Fx.label("BOSS VAINCU !", "rgb", 1.2)
	if b then b.state, b.tEnd = "dead", ctx.T end
end
function A.bossEscape()
	local b = bv
	if b then b.state, b.tEnd = "escape", ctx.T end
	Fx.label("Il s'est enfui…", Color3.fromHex("#b3a6dd"), 0.7)
end
function A.bossSpawn()
	Fx.shake(10)
	Fx.flash(0.25, Color3.fromRGB(255, 60, 80))
end
function A.bossActive(): boolean return bv ~= nil and (bv :: BV).state == "live" end

local function stepBoss(dt: number)
	local b = bv
	if not b then
		bossUIVisible(false)
		return
	end
	local T, AT, W, H, R = ctx.T, ctx.AT, ctx.W, ctx.H, ctx.R
	local bx, by, bsize = bossPos()
	local x, y, sc, rot, al = bx, by, 1, 0, 1
	b.kbv += (-b.kb * 260 - b.kbv * 16) * dt
	b.kb += b.kbv * dt
	b.flash = math.max(0, b.flash - dt * 6)
	if b.state == "live" then
		local k = (T - b.t0) / 0.8
		x = lerp(W + bsize, bx, K.easeOutBack(k))
		sc = k < 1 and 0.6 + 0.4 * K.easeOutCubic(k) or 1
		local hpT = b.hp / math.max(1, b.maxHp)
		b.hpD = lerp(b.hpD, hpT, 1 - math.exp(-dt * 14))
		b.trail = b.trail > b.hpD and math.max(b.hpD, b.trail - dt * 0.5) or b.hpD
		b.left = math.max(0, b.left - dt)
	elseif b.state == "dead" then
		local k = (T - b.tEnd) / 0.3
		if k >= 1 then bv = nil; bossUIVisible(false); return end
		sc, al = 1 + k * 0.6, 1 - k
	else
		local k = (T - b.tEnd) / 1
		if k >= 1 then bv = nil; bossUIVisible(false); return end
		x += k * k * W * 0.7
		y -= k * H * 0.35
		sc, rot, al = 1 - k * 0.7, k * 7, 1 - k * 0.8
	end
	x += b.kb * 0.5
	rot += math.sin(AT * 3) * 0.14 + b.kb * 0.005
	y += math.sin(AT * 2.3) * 8
	local size = bsize * sc * (1 + 0.05 * math.sin(AT * 4))
	local ui = bossUI
	bossUIVisible(true)
	ui.glow.ImageColor3 = b.color
	place(ui.glow, x, y, size * 2.4)
	glowA(ui.glow, al * (0.45 + 0.2 * math.sin(AT * 5)))
	place(ui.glowRed, x, y + size * 0.1, size * 1.8)
	glowA(ui.glowRed, al * 0.35)
	place(ui.shadow, x, y + size * 0.6, size * 0.8, size * 0.16)
	ui.shadow.BackgroundTransparency = 1 - al * 0.4
	place(ui.img, x, y, size)
	ui.img.Rotation = math.deg(rot)
	ui.img.ImageTransparency = ui.img:FindFirstChild("Fallback") and 1 or 1 - al
	ui.flash.Visible = b.flash > 0.02 and not ui.flash:GetAttribute("noimg")
	if ui.flash.Visible then
		place(ui.flash, x, y, size * 1.4)
		glowA(ui.flash, b.flash)
	end
	local live = b.state == "live"
	ui.bar.Visible, ui.name.Visible, ui.info.Visible = live, live, live
	if live then
		local pl = ctx.play
		local right = pl.left + pl.width
		local bw, bh = clamp(R * 1.5, 110, 200), 15
		local barX = clamp(x - bw / 2, pl.left + 8, right - bw - 8)
		local barY = y + size * 0.62
		ui.bar.Position = UDim2.fromOffset(barX - 3, barY - 3)
		ui.bar.Size = UDim2.fromOffset(bw + 6, bh + 6)
		ui.trail.Visible = b.trail > b.hpD
		ui.trail.Size = UDim2.fromOffset(bw * b.trail, bh)
		ui.fill.Visible = b.hpD > 0.005
		ui.fill.Size = UDim2.fromOffset(math.max(bh, bw * b.hpD), bh)
		if b.hpD < 0.3 then
			ui.fillGrad.Color = K.hueSeq(K.hue(0))
		else
			ui.fillGrad.Color = ColorSequence.new(Color3.fromHex("#ff3d5e"), Color3.fromHex("#ff9a1f"))
		end
		ui.shine.Size = UDim2.fromOffset(math.max(0, bw * b.hpD - 6), bh * 0.35)
		local fs = math.floor(clamp(R * 0.15, 15, 21))
		ui.name.TextSize = fs
		ui.name.Size = UDim2.fromOffset(10, fs + 6)
		local nw = ui.name.AbsoluteSize.X
		ui.name.Position = UDim2.fromOffset(clamp(x, pl.left + nw / 2 + 8, math.max(pl.left + nw / 2 + 8, right - nw / 2 - 8)), y - size * 0.64)
		local tl = math.max(0, math.ceil(b.left))
		ui.info.Text = math.ceil(b.hpD * 100) .. " %  ·  " .. tl .. " s"
		ui.info.TextColor3 = tl <= 5 and Color3.fromHex("#ff4d6d") or C.ink
		ui.info.Position = UDim2.fromOffset(barX + bw / 2, barY + bh + 13)
	end
end

---------------------------------------------------------------------------- API
function A.step(dt: number)
	stepPets(dt)
	stepGolden()
	stepBoss(dt)
	stepProj()
end

function A.init(context: any, stageFrame: Frame, goldenHandler: (id: number) -> ())
	ctx = context
	stage = stageFrame
	onGolden = goldenHandler
end

return A
