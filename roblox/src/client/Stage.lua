-- COOKIE OVERDRIVE — le « canvas » du site en GUI 2D : fond animé, cookie, effets autour, pets,
-- cookies dorés, boss, particules, textes, flash et bordure de Fièvre. Porte stage.js (update/render
-- + gestionnaires d'événements) ; les modules Background / Around / Cookie / Actors / Fx dessinent.
local RS = game:GetService("ReplicatedStorage")

local K = require(script.Parent:WaitForChild("Kit"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local Background = require(script.Parent:WaitForChild("Background"))
local Cookie = require(script.Parent:WaitForChild("Cookie"))
local Around = require(script.Parent:WaitForChild("Around"))
local Actors = require(script.Parent:WaitForChild("Actors"))
local D = require(RS:WaitForChild("Shared"):WaitForChild("GameData"))
local new, C = K.new, K.C
local clamp, rand = K.clamp, K.rand

local S = {}
local TAU = math.pi * 2

-- contexte partagé par tous les modules du stage
local ctx = {
	W = 1280, H = 720, CX = 400, CY = 400, R = 120,
	play = { left = 0, top = 64, width = 800, height = 656 },
	T = 0, AT = 0, dt = 1 / 60,
	fever = false, feverK = 0, heat = 0, bgPulse = 0,
	reduced = false, mobile = false, pm = 1, paused = false,
}
S.ctx = ctx

local root: Frame
local stage: Frame
local overlay: Frame
local feverFx: { outer: Frame, inner: Frame, outerStroke: UIStroke, innerStroke: UIStroke, outerGrad: UIGradient, innerGrad: UIGradient, vig: { Frame } }
local vis: { [string]: number } = {}
local lastWave = -9
local CRUMBS = { Color3.fromHex("#a9652a"), Color3.fromHex("#d99a4e"), Color3.fromHex("#4a2511"), Color3.fromHex("#f3c783") }

---------------------------------------------------------------------------- mise en page
-- play = zone de jeu (#play du site) en pixels écran
function S.setLayout(W: number, H: number, play: { left: number, top: number, width: number, height: number }, mobile: boolean)
	ctx.W, ctx.H, ctx.mobile = W, H, mobile
	ctx.play = play
	ctx.CX = play.left + play.width / 2
	ctx.CY = play.top + play.height * 0.56
	ctx.R = clamp(math.min(play.width, play.height * 0.8) * 0.22, 60, 170)
	Background.dirty = true
end

function S.setVis(v: { [string]: number }, silent: boolean?): { string }
	vis = v
	local added = Cookie.setVis(v, silent)
	Around.setVis(v)
	if not silent and #added > 0 then
		local R, CX, CY = ctx.R, ctx.CX, ctx.CY
		for _ in added do
			Fx.sparkleRing(CX, CY, R * 1.1, 28, nil, 300)
			Fx.ring(CX, CY, R * 0.9, R * 2.6, 0.6, 16, "rgb")
			Fx.ring(CX, CY, R * 0.9, R * 1.9, 0.45, 8, C.white)
		end
		Fx.flash(0.45)
		Cookie.kick(2.5)
		Fx.shake(5)
	end
	return added
end

function S.setState(s: any)
	Around.setState(s)
	Actors.setPets(s)
end

function S.setSkin(id: string, fx: boolean?)
	if id == Cookie.skin() and Cookie.built then return end
	Cookie.setSkin(id)
	if fx then
		local R, CX, CY = ctx.R, ctx.CX, ctx.CY
		Fx.flash(0.4)
		Cookie.kick(3)
		Fx.sparkleRing(CX, CY, R, 30, nil, 320)
		Fx.ring(CX, CY, R * 0.9, R * 2.4, 0.55, 14, "rgb")
	end
end

function S.setTheme(id: string)
	Background.setTheme(id)
end

function S.setLive(live: any)
	ctx.fever = (live.fever or 0) > 0
	ctx.heat = clamp((live.combo and live.combo.heat) or 0, 0, 1)
	Actors.setGolden(live.golden)
	Actors.setBoss(live.boss)
end

function S.setSettings(o: { [string]: any })
	if o.reduced ~= nil then ctx.reduced = o.reduced; Fx.reduced = o.reduced end
	if o.shake ~= nil then Fx.shakeOn = o.shake end
	if o.pm ~= nil then ctx.pm = o.pm; Fx.pm = o.pm end
end

-- mini-jeu ouvert (overlay opaque par-dessus) : le stage est masqué et n'est plus animé
function S.setPaused(p: boolean)
	ctx.paused = p
	if root then root.Visible = not p end
	if p then Fx.clear() end
end

---------------------------------------------------------------------------- clic sur le cookie (onClick du site, partie locale)
-- Tout ce qui ne dépend pas de la réponse du serveur part immédiatement.
function S.tap(x: number, y: number)
	local R, CX, CY, T = ctx.R, ctx.CX, ctx.CY, ctx.T
	Cookie.tap(x, y)
	Fx.crumbs(x, y, 8, CRUMBS)
	Fx.shake(1.2)
	if vis.shockwave and T - lastWave > 0.14 then
		lastWave = T
		Fx.ring(CX, CY, R * 0.95, R * 2.3, 0.45, R * 0.06, "rgb")
	end
	if vis.confetti_click then Fx.confettiBurst(x, y, 16, { speed = 460, spread = 1.4 }) end
	if vis.laser_eyes then
		Cookie.laser(x, y)
		Fx.burst(x, y, 10, { cols = { Color3.fromHex("#ff3b4f"), Color3.fromHex("#ffb0b8"), C.white }, speed = 320, size = 12, life = 0.4, type = "spark" })
	end
	Around.onTap()
	Actors.onTap()
	Actors.fireAtBoss(vis.laser_eyes ~= nil)
end

-- clic automatique (pass Auto-Clicker, 6/s côté serveur) : version discrète du clic
function S.autoTap()
	local a = math.random() * TAU
	local rr = ctx.R * 0.8 * math.sqrt(math.random())
	local x, y = ctx.CX + math.cos(a) * rr, ctx.CY + math.sin(a) * rr
	Cookie.tap(x, y)
	Fx.crumbs(x, y, 3, CRUMBS)
	Actors.fireAtBoss(vis.laser_eyes ~= nil)
end

-- réponse du serveur : +N (et critique) au point du clic
function S.clickResult(x: number, y: number, amount: number, crit: boolean, mult: number?)
	local R, CX, CY = ctx.R, ctx.CX, ctx.CY
	local extra = nil
	if mult and mult > 1 then extra = "x" .. string.gsub(tostring(math.floor(mult * 10 + 0.5) / 10), "%.", ",") end
	Fx.text(x, y - 12, "+" .. K.fmt(amount), crit and "crit" or "num", extra)
	if crit then
		Cookie.crit(x)
		Fx.crumbs(x, y, 8, CRUMBS)
		Fx.shake(10)
		Fx.burst(x, y, 16, { cols = { Color3.fromHex("#ffd23c"), Color3.fromHex("#fff3a0"), Color3.fromHex("#ff8a00") }, speed = 380, size = 16, life = 0.6 })
		Fx.ring(x, y, 10, R * 0.9, 0.4, 8, Color3.fromHex("#ffd23c"))
		if vis.shockwave then Fx.ring(CX, CY, R * 0.95, R * 3, 0.6, R * 0.1, "rgb") end
		if vis.confetti_click then Fx.confettiBurst(x, y, 18, { speed = 460, spread = 1.4 }) end
		Actors.critHint()
	end
end

---------------------------------------------------------------------------- événements (handlers du site)
function S.feverStart()
	local R, CX, CY, W, H = ctx.R, ctx.CX, ctx.CY, ctx.W, ctx.H
	Fx.burst(CX, CY, 140, { speed = 700, size = 22, life = 1.2, r0 = R * 0.8 })
	Fx.confettiBurst(CX, CY - R * 0.5, 40, { speed = 700, spread = 1.6 })
	Fx.ring(CX, CY, R, math.max(W, H) * 0.8, 0.9, 24, "rgb")
	Fx.ring(CX, CY, R, R * 3, 0.6, 12, C.white)
	Fx.flash(0.6)
	Fx.shake(16)
	Fx.label("FIÈVRE RGB !!", "rgb", 1.15)
	Cookie.kick(3)
end
function S.feverEnd()
	Fx.ring(ctx.CX, ctx.CY, ctx.R, ctx.R * 2.4, 0.5, 8, "rgb")
end
function S.bossSpawn() Actors.bossSpawn() end
function S.bossDefeat() Actors.bossDefeat() end
function S.bossEscape() Actors.bossEscape() end
function S.goldenCaught(id: number, res: any) Actors.goldenCaught(id, res) end
function S.petHatched(id: string) Actors.petHatched(id) end
function S.achievement()
	local R, CX, CY = ctx.R, ctx.CX, ctx.CY
	Fx.sparkleRing(CX, CY, R * 1.15, 36, { Color3.fromHex("#ffd23c"), Color3.fromHex("#fff3a0"), C.white }, 260)
	Fx.ring(CX, CY, R, R * 2.2, 0.6, 10, Color3.fromHex("#ffd23c"))
end
function S.confetti() Fx.confettiRain() end
function S.rebirth()
	local R, CX, CY = ctx.R, ctx.CX, ctx.CY
	Fx.burst(CX, CY, 80, { cols = { Color3.fromHex("#ffd23c"), Color3.fromHex("#fff3a0"), C.white }, speed = 600, size = 22 })
	Fx.ring(CX, CY, R, R * 3, 0.8, 18, Color3.fromHex("#ffd23c"))
	Fx.flash(0.5, Color3.fromRGB(255, 230, 150))
end
function S.label(text: string, col: any, big: number?) Fx.label(text, col, big) end
function S.isOverGolden(): boolean return false end

---------------------------------------------------------------------------- bordure de Fièvre (feverOverlay du site)
local function buildFever()
	local function band(z: number): (Frame, UIStroke, UIGradient)
		local f = new("Frame", { BackgroundTransparency = 1, ZIndex = z, Visible = false, Parent = overlay })
		local st = new("UIStroke", { Color = C.white, Thickness = 8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
		local g = new("UIGradient", { Color = K.rainbowSeq(), Parent = st })
		return f, st, g
	end
	local o, os, og = band(3)
	local i, is, ig = band(4)
	local vg = {}
	for n = 1, 4 do
		local f = new("Frame", { BorderSizePixel = 0, ZIndex = 2, Visible = false, Parent = overlay })
		new("UIGradient", { Rotation = ({ 90, -90, 0, 180 })[n], Transparency = NumberSequence.new(0.7, 1), Parent = f })
		vg[n] = f
	end
	feverFx = { outer = o, inner = i, outerStroke = os, innerStroke = is, outerGrad = og, innerGrad = ig, vig = vg }
end
local function stepFever()
	local k = ctx.feverK
	local on = k > 0.01
	local f = feverFx
	f.outer.Visible, f.inner.Visible = on, on
	for _, v in f.vig do v.Visible = on end
	if not on then return end
	local W, H = ctx.W, ctx.H
	local bt = 1 - ((ctx.T * 116 / 60) % 1)
	local bw = (7 + 7 * bt) * k
	-- trait extérieur large et transparent + trait net, tous deux collés aux bords de l'écran
	local wo = bw * 3.2
	f.outer.Position = UDim2.fromOffset(wo, wo)
	f.outer.Size = UDim2.fromOffset(W - 2 * wo, H - 2 * wo)
	f.outerStroke.Thickness = wo
	f.outerStroke.Transparency = 1 - 0.35 * k
	f.inner.Position = UDim2.fromOffset(bw, bw)
	f.inner.Size = UDim2.fromOffset(W - 2 * bw, H - 2 * bw)
	f.innerStroke.Thickness = bw
	f.innerStroke.Transparency = 1 - k
	local rot = (ctx.AT * 1.5 * 57.3 + K.H) % 360
	f.outerGrad.Rotation, f.innerGrad.Rotation = rot, rot
	-- vignette colorée (dégradé radial hsl(h,100%,50%) à 30 %)
	local col = K.hsl(K.hue(0), 1, 0.5)
	local vs = { { 0, 0, W, H * 0.3 }, { 0, H * 0.7, W, H * 0.3 }, { 0, 0, W * 0.25, H }, { W * 0.75, 0, W * 0.25, H } }
	for n, v in f.vig do
		local r = vs[n]
		v.Position = UDim2.fromOffset(r[1], r[2])
		v.Size = UDim2.fromOffset(r[3], r[4])
		v.BackgroundColor3 = col
		v.BackgroundTransparency = 1 - 0.55 * k
	end
end

---------------------------------------------------------------------------- boucle
function S.step(dt: number)
	if ctx.paused then return end
	dt = math.min(dt, 0.1)
	ctx.dt = dt
	ctx.T += dt
	ctx.AT += dt * (ctx.reduced and 0.5 or 1)
	K.stepHue(dt, ctx.fever)
	ctx.feverK = K.lerp(ctx.feverK, ctx.fever and 1 or 0, 1 - math.exp(-dt * 4))
	ctx.bgPulse *= math.exp(-dt * 5)
	Background.step(dt)
	Around.step(dt)
	Cookie.step(dt)
	Actors.step(dt)
	-- étoiles autour du cookie pendant la Fièvre
	if ctx.fever and not ctx.reduced and math.random() < 0.5 * ctx.pm then
		local a = math.random() * TAU
		local rr = ctx.R * rand(1.1, 1.8)
		Fx.spawn("star", ctx.CX + math.cos(a) * rr, ctx.CY + math.sin(a) * rr, 0, -20, 0.7, rand(12, 22), Fx.hq(K.hue(math.random() * 360), 70))
	end
	Fx.step(dt)
	stage.Position = UDim2.fromOffset(Fx.offset.X, Fx.offset.Y)
	stepFever()
end

function S.init(gui: ScreenGui, onTap: (Vector2) -> (), onGolden: (id: number) -> ())
	root = new("Frame", { Name = "StageRoot", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = gui })
	Background.init(ctx, root)
	stage = new("Frame", { Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = root })
	local lasers = new("Frame", { Name = "Lasers", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 25, Parent = stage })
	local low = new("Frame", { Name = "FxLow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 32, Parent = stage })
	local high = new("Frame", { Name = "FxHigh", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 33, Parent = stage })
	local text = new("Frame", { Name = "FxText", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 34, Parent = stage })
	overlay = new("Frame", { Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = root })
	Fx.init(ctx, low, high, text, overlay)
	Cookie.init(ctx, stage, lasers, onTap)
	Around.init(ctx, stage)
	Around.onBeatShake = function(a: number) Fx.shake(a) end
	Actors.init(ctx, stage, onGolden)
	buildFever()
	S.root = root
end

S.D = D
return S
