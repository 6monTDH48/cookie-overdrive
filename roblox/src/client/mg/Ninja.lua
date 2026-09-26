--!nonstrict
-- COOKIE OVERDRIVE — mini-jeu « Cookie Ninja » (port de mg-ninja.js).
-- Fruit-Ninja : glisse pour trancher TES cookies (skin + accessoires), évite les brocolis.
-- 3 vies, manche de 60 s max, combos multi-tranches, cookies dorés, vagues FRENZY, démo auto
-- (lame IA) derrière le menu et les résultats. Tout est dessiné chaque frame avec des objets GUI
-- recyclés (Canvas) ; aucune Instance n'est créée pendant le jeu.
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local C = require(script.Parent:WaitForChild("Common"))

local ROUND = 60 -- durée max d'une manche (s)
local LIVES = 3
local STEP = 0.62 -- un pas du compte à rebours (s)
local GO_T = 0.7
local CHAIN_GAP = 0.3 -- s max entre deux tranches pour garder la chaîne (combo)
local SLICE_SPEED = 110 -- px/s mini pour que la lame coupe
local MAX_PARTS = 320

local hex, hsl, clamp, lerp, rand, pick, TAU = C.hex, C.hsl, C.clamp, C.lerp, C.rand, C.pick, C.TAU
local WHITE, BLACK = C.col.white, C.col.black
local RED = hex("#ff4d6d")
local GOLD_PAL = { base = hex("#ffcc33"), dark = hex("#c98a00"), light = hex("#fff2a8"), chip = hex("#b36b00"), chipHi = hex("#ffe07a"), rim = hex("#8a5a00") }
local BOMB_PAL = { base = hex("#3dff6a"), dark = hex("#1a8a3a"), light = hex("#9dff9d"), chip = hex("#0f5a24") }
local COL = {
	gold = hex("#ffd23c"), goldL = hex("#fff2a8"), goldD = hex("#ffb800"), goldRay = hex("#ffdc5a"),
	bombGlow = Color3.fromRGB(255, 30, 70), bombRing = Color3.fromRGB(255, 60, 90), pinkGlow = Color3.fromRGB(255, 43, 214),
	heartGlow = Color3.fromRGB(255, 77, 109), lime = hex("#b6ff3b"), yellow = hex("#ffc93c"),
	g1 = hex("#3dff6a"), g2 = hex("#1fbf4a"), r1 = hex("#ff4d6d"), r2 = hex("#ff2040"), veil = hex("#0b0620"),
}

local Q_BOMB = { "skill issue", "le brocoli t'a ratio", "AÏE AÏE AÏE", "c'est un légume frérot", "cheh", "GREEN FLAG ? non." }
local Q_MISS = { "RATÉ !", "il t'a ghost", "trop lent", "skill issue", "oups" }
local Q_COMBO = { "TROP FORT", "AURA +1000", "W", "NO CAP", "INSANE", "CHEF !", "MAIN CHARACTER" }

local function quipFor(score)
	if score >= 150 then return "T'es un vrai ninja, no cap. Aura infinie." end
	if score >= 90 then return "AURA +1000, trop fort !" end
	if score >= 45 then return "W énorme, continue comme ça !" end
	if score >= 15 then return "Pas mal… mais on peut faire mieux." end
	return "skill issue… réessaie !"
end

local function ulen(s) return utf8.len(s) or #s end

-- rayures diagonales du fond (tuile 34 px, lignes x + y = cte comme le site)
local function texStripes()
	return C.proc("ninjaStripes", 34, 34, function(buf, w, h)
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				local d = (x + y + 1) % 34
				local dist = math.min(d, 34 - d) / math.sqrt(2)
				local al = clamp(1.5 - dist, 0, 1)
				if al > 0 then C.px(buf, w, x, y, 255, 255, 255, math.floor(al * 255)) end
			end
		end
	end)
end
-- vignette : transparente jusqu'à `inner`, puis noir 55 %
local function texVignette(inner)
	inner = math.floor(inner * 20 + 0.5) / 20
	return C.proc("ninjaVig" .. inner, 128, 128, function(buf, w, h)
		local R = w / 2
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				local dx, dy = x + 0.5 - R, y + 0.5 - R
				local d = math.sqrt(dx * dx + dy * dy) / R
				local al = 0.55 * clamp((d - inner) / (1 - inner), 0, 1)
				if al > 0 then C.px(buf, w, x, y, 0, 0, 0, math.floor(al * 255)) end
			end
		end
	end)
end

local Ninja = {}

function Ninja.mount(ctx)
	local root = ctx.root
	local bag = C.bag()
	local destroyed = false

	----------------------------------------------------------------------- état
	local W, H, R = 0, 0, 36
	local realT = 0
	local mode = "menu" -- menu | count | play | paused | over | results
	local resumeRun, countT, countStep, goT = false, 0, -1, 0
	local score, lives, elapsed, nextWave, lastGold, lastTick, bestAtStart, recAnnounced = 0, LIVES, 0, 0, -99, 0, 0, false
	local frenzyAt, frenzyOn, frenzyEnd = {}, false, 0
	local overT, overReason = 0, "ko"
	local stats = { sliced = 0, gold = 0, bombs = 0, maxCombo = 0 }
	local objs, halves, parts, texts, rings, slashes, marks, queue = {}, {}, {}, {}, {}, {}, {}, {}
	local blades = {} -- clé : "mouse" ou l'InputObject du doigt
	local fading = {}
	local ai = { ai = true, pts = {}, chainN = 0, chainT = 0, chainX = 0, chainY = 0, lastX = 0, lastY = 0, lastT = 0, busy = false, t = 0, dur = 0.13, x0 = 0, y0 = 0, x1 = 0, y1 = 0, cool = 0.8 }
	local demoT = 0.3
	local shake, flashA, flashCol, flashRgb, freeze, scoreBump, timerPulse = 0, 0, WHITE, false, 0, 0, 0
	local heartFx = { 0, 0, 0 }
	local motes = {}
	for i = 1, 22 do
		motes[i] = { x = math.random(), y = math.random(), s = rand(1, 2.6), sp = rand(0.015, 0.05), h = rand(0, 360) }
	end
	local runId = 0

	----------------------------------------------------------------------- fond fixe (buildBg)
	local bgF = C.new("Frame", { Name = "Bg", BackgroundColor3 = hex("#07031a"), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = root })
	local function bgImg(z, color, tr)
		return C.new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = color, ImageTransparency = tr or 0, ZIndex = z, Parent = bgF })
	end
	-- radial-gradient #3d1075 → #1b0845 (45 %) → #07031a : deux halos linéaires superposés
	local g1 = bgImg(1, hex("#1b0845"))
	local g2 = bgImg(2, hex("#3d1075"))
	if not (C.applyProc(g1, C.texGlow(0.45)) and C.applyProc(g2, C.texGlow(0))) then
		bgF.BackgroundColor3 = hex("#1b0845")
		g1.Visible = false
		g2.Visible = false
	end
	local stripes = C.new("ImageLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(34, 34),
		ImageColor3 = hex("#ff2bd6"), ImageTransparency = 0.94, ZIndex = 3, Parent = bgF,
	})
	if not C.applyProc(stripes, texStripes()) then stripes.Visible = false end
	C.new("Frame", {
		BackgroundColor3 = hex("#ff2bd6"), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.28), ZIndex = 4, Parent = bgF,
	}, { C.new("UIGradient", { Rotation = 90, Transparency = C.nseq({ { 0, 1 }, { 1, 0.74 } }) }) })
	local vig = bgImg(5, BLACK)
	local vigInner = -1

	local function layoutBg()
		local diag = math.sqrt(W * W + H * H)
		local r1 = diag * 0.62
		g1.Position = UDim2.fromOffset(W / 2, H * 0.45)
		g1.Size = UDim2.fromOffset(2 * r1, 2 * r1)
		g2.Position = g1.Position
		g2.Size = UDim2.fromOffset(2 * r1 * 0.45, 2 * r1 * 0.45)
		local inner = math.floor(clamp(math.min(W, H) * 0.3 / r1, 0.05, 0.9) * 20 + 0.5) / 20
		if inner ~= vigInner then
			vigInner = inner
			vig.Visible = C.applyProc(vig, texVignette(inner))
		end
		vig.Position = UDim2.fromOffset(W / 2, H / 2)
		vig.Size = UDim2.fromOffset(2 * r1, 2 * r1)
	end

	----------------------------------------------------------------------- calques dynamiques
	local cvBg = C.canvas(root, 5, "Rays")
	local cvW = C.canvas(root, 6, "World")
	local cvH = C.canvas(root, 7, "Hud")
	local hit = C.new("TextButton", {
		Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ZIndex = 40, Selectable = false, Parent = root,
	})

	local startRun -- déclarée plus bas
	local menu = C.menuScreen(root, {
		hero = "mg:ninja", heroGlow = hex("#ff2bd6"), title = "COOKIE NINJA", sub = "Tranche les cookies · évite les brocolis",
		subColor = C.col.cyan, hueStep = 26, fmt = ctx.fmt, best = ctx.best(),
		rules = {
			{ "ui:sword", "Glisse pour trancher" }, { "ui:fire", "3+ d'un coup = COMBO" },
			{ "ui:golden", "Cookie doré = +5" }, { "item:broccoli", "Brocoli ou raté = -1 vie" },
		},
		onPlay = function() startRun() end,
	})
	local res = C.resultsCard(root, {
		cuK = 0.008,
		onAgain = function() startRun() end,
		onQuit = function() ctx.close() end,
	})

	----------------------------------------------------------------------- effets
	local function addText(str, x, y, size, col, life, big)
		local n = math.max(3, ulen(str))
		size = math.min(size, (W * 0.92) / (n * 0.56))
		local hw = n * size * 0.29 + 6
		x = clamp(x, hw, math.max(hw, W - hw))
		y = clamp(y, size * 0.7, H - size * 0.7)
		table.insert(texts, { str = str, x = x, y = y, size = size, col = col, life = life or 0.8, max = life or 0.8, vy = big and -R * 0.35 or -R * 1.1, big = big == true })
	end
	local function flash(col, a)
		if col == "rgb" then
			flashRgb = true
		else
			flashRgb = false
			flashCol = col
		end
		flashA = math.max(flashA, a)
	end
	local function bumpShake(n) shake = math.max(shake, n) end
	local function spark(x, y, n, cols, spd, add)
		for _ = 1, n do
			if #parts >= MAX_PARTS then break end
			local a, sp = rand(0, TAU), rand(0.3, 1) * spd
			local l = rand(0.35, 0.8)
			table.insert(parts, { x = x, y = y, vx = math.cos(a) * sp, vy = math.sin(a) * sp, g = H * 0.5, drag = 0.9, life = l, max = l, size = rand(2, 4.5), col = pick(cols), sq = false, rot = 0, vr = 0, add = add ~= false })
		end
	end
	local function crumbs(x, y, r, p, n)
		local cols = { p.base, p.dark, p.light, p.chip, p.chip }
		for _ = 1, n do
			if #parts >= MAX_PARTS then break end
			local a, sp = rand(0, TAU), R * rand(1.5, 6)
			local l = rand(0.5, 1.05)
			table.insert(parts, {
				x = x + math.cos(a) * r * 0.4, y = y + math.sin(a) * r * 0.4, vx = math.cos(a) * sp, vy = math.sin(a) * sp - R * 2.2, g = H * 1.2, drag = 0.99,
				life = l, max = l, size = rand(0.08, 0.17) * r, col = pick(cols), sq = math.random() < 0.65, rot = rand(0, TAU), vr = rand(-12, 12), add = false,
			})
		end
	end
	local function confetti(n)
		for _ = 1, n do
			if #parts >= MAX_PARTS then break end
			local l = rand(1.6, 2.8)
			table.insert(parts, { x = rand(0, W), y = rand(-40, -5), vx = rand(-40, 40), vy = rand(60, 200), g = H * 0.25, drag = 0.995, life = l, max = l, size = rand(5, 9), col = hsl(rand(0, 360), 100, 62), sq = true, rot = rand(0, TAU), vr = rand(-8, 8), add = false })
		end
	end

	----------------------------------------------------------------------- lancers
	local function launch(kind, o)
		o = o or {}
		local sp = o.speed or 1
		local gold = kind == "gold"
		local g = H * 1.25 * sp * sp * (gold and 1.3 or 1)
		local r = gold and R * 0.82 or (kind == "bomb" and R * 0.95 or R)
		local x = o.x or rand(W * 0.12, W * 0.88)
		local y = H + r + 4
		local apexY = o.apexY or (gold and rand(H * 0.1, H * 0.26) or rand(H * 0.14, H * 0.42))
		local vy = -math.sqrt(2 * g * (y - apexY))
		local tA = -vy / g
		local tx = o.tx or clamp(x + rand(-W * 0.28, W * 0.28), W * 0.12, W * 0.88)
		local acc = false
		if kind == "cookie" and not o.frenzy then
			local n = 0
			for _, b in objs do
				if b.acc and not b.dead then n += 1 end
			end
			acc = n < 4
		end
		table.insert(objs, {
			kind = kind, x = x, y = y, vx = (tx - x) / tA, vy = vy, g = g, r = r, rot = rand(0, TAU), vr = rand(-4, 4) * (gold and 1.8 or 1),
			frenzy = o.frenzy == true, acc = acc, dead = false, seed = rand(0, 10), aiSkip = false,
		})
	end
	local function spawnWave(p)
		local sp = 1 + 0.32 * p
		local n = math.min(5, 1 + math.floor(math.random() * (1.5 + p * 3.2)))
		local bombChance = elapsed < 4 and 0 or 0.1 + 0.22 * p
		local maxBombs = p > 0.55 and 2 or 1
		local fan = n >= 3 and math.random() < 0.28
		local baseX = rand(W * 0.25, W * 0.75)
		local wave = {}
		local bombs = 0
		for i = 0, n - 1 do
			local kind = "cookie"
			if bombs < maxBombs and math.random() < bombChance then
				kind = "bomb"
				bombs += 1
			elseif elapsed - lastGold > 6 and math.random() < 0.06 + 0.05 * p then
				kind = "gold"
				lastGold = elapsed
			end
			local s = { at = elapsed + (fan and i * 0.07 or i * rand(0.12, 0.28)), kind = kind, speed = sp * rand(0.94, 1.06) }
			if fan then
				s.x = baseX + rand(-18, 18)
				s.tx = lerp(W * 0.18, W * 0.82, i / (n - 1))
			end
			wave[i + 1] = s
		end
		if bombs == n then wave[1].kind = "cookie" end
		for _, s in wave do table.insert(queue, s) end
		C.sfx("whoosh", { vol = 0.4, pitch = rand(0.9, 1.15) })
	end
	local function startFrenzy()
		table.remove(frenzyAt, 1)
		frenzyOn = true
		frenzyEnd = elapsed + 3.4
		addText("FRENZY !!!", W / 2, H * 0.4, R * 1.5, "rgb", 1.5, true)
		C.sfx("fever")
		flash("rgb", 0.35)
		bumpShake(8)
		local n = 8 + math.random(0, 4)
		local sp = 1 + 0.25 * (elapsed / ROUND)
		for i = 0, n - 1 do
			local left = i % 2 == 0
			table.insert(queue, {
				at = elapsed + 0.45 + i * rand(0.09, 0.15), kind = "cookie", frenzy = true, speed = sp * rand(0.95, 1.1),
				x = left and rand(W * 0.03, W * 0.2) or rand(W * 0.8, W * 0.97), tx = left and rand(W * 0.35, W * 0.7) or rand(W * 0.3, W * 0.65),
				apexY = rand(H * 0.12, H * 0.45),
			})
		end
		nextWave = frenzyEnd + 0.5
	end
	local function flushQueue()
		for i = #queue, 1, -1 do
			local s = queue[i]
			if s.at <= elapsed then
				table.remove(queue, i)
				launch(s.kind, s)
			end
		end
	end

	----------------------------------------------------------------------- tranches
	local loseLife, gameOver
	local function addScore(n)
		score += n
		scoreBump = 1
		if not recAnnounced and bestAtStart > 0 and score > bestAtStart then
			recAnnounced = true
			addText("NOUVEAU RECORD !", W / 2, H * 0.24, R * 0.8, "rgb", 1.4, true)
			C.sfx("achievement")
		end
	end
	local function resolveChain(b)
		local n = b.chainN
		b.chainN = 0
		if n < 3 or b.ai or mode ~= "play" then return end
		addScore(n)
		stats.maxCombo = math.max(stats.maxCombo, n)
		local x, y = clamp(b.chainX, W * 0.25, W * 0.75), clamp(b.chainY, H * 0.22, H * 0.7)
		addText("COMBO x" .. n .. " !", x, y, R * (0.95 + math.min(n, 8) * 0.07), "rgb", 1.15, true)
		addText("+" .. n .. " bonus", x, y + R * 0.95, R * 0.55, COL.lime, 1)
		C.sfx("combo", { pitch = 1 + math.min(6, n - 3) * 0.08 })
		table.insert(rings, { x = x, y = y, r = R * 0.5, dr = R * 10, life = 0.5, max = 0.5, col = "rgb", w = 8 })
		spark(x, y, 18 + n * 3, { hsl(C.hue(0), 100, 65), hsl(C.hue(120), 100, 65), hsl(C.hue(240), 100, 65), WHITE }, R * 8)
		if n >= 5 then
			addText(pick(Q_COMBO), x, y - R * 1.2, R * 0.7, COL.yellow, 1.1, true)
			flash("rgb", 0.25)
			bumpShake(8)
		end
	end
	local function bombBoom(o, live, quiet)
		spark(o.x, o.y, 34, { COL.g1, COL.g2, COL.r1, COL.r2, WHITE }, R * 10)
		crumbs(o.x, o.y, o.r, BOMB_PAL, 16)
		table.insert(rings, { x = o.x, y = o.y, r = o.r, dr = R * 12, life = 0.5, max = 0.5, col = COL.r2, w = 10 })
		if not quiet then C.sfx("hit", { pitch = 0.7 }) end
		if not live then return end
		stats.bombs += 1
		C.sfx("error")
		bumpShake(22)
		flash(COL.r2, 0.5)
		freeze = math.max(freeze, 0.16)
		addText("AÏE ! -1 VIE", o.x, o.y, R * 0.9, RED, 1.1, true)
		addText(pick(Q_BOMB), W / 2, H * 0.34, R * 0.7, WHITE, 1.3, true)
		loseLife()
	end
	local function sliceObj(o, ang, b)
		o.dead = true
		local live = mode == "play"
		local quiet = b.ai == true
		if o.kind == "bomb" then
			bombBoom(o, live, quiet)
			return
		end
		local gold = o.kind == "gold"
		local pts = gold and 5 or 1
		if live then
			addScore(pts)
			stats.sliced += 1
			if gold then stats.gold += 1 end
		end
		local nx, ny = -math.sin(ang), math.cos(ang)
		local push = R * rand(2.2, 3.4)
		for side = -1, 1, 2 do
			table.insert(halves, {
				x = o.x + nx * side * 2, y = o.y + ny * side * 2, vx = o.vx * 0.5 + nx * side * push, vy = math.min(o.vy * 0.4, 0) + ny * side * push - R * 1.5,
				g = o.g, ang = ang, va = side * rand(2, 5), side = side, r = o.r, acc = o.acc, skin = gold and "golden" or nil,
			})
		end
		crumbs(o.x, o.y, o.r, gold and GOLD_PAL or C.pal(), gold and 18 or 12)
		table.insert(slashes, { x = o.x, y = o.y, ang = ang, len = o.r * 3.4, life = 0.2, max = 0.2 })
		if b.chainN > 0 and realT - b.chainT < CHAIN_GAP then
			b.chainN += 1
		else
			resolveChain(b)
			b.chainN = 1
		end
		b.chainT = realT
		b.chainX = o.x
		b.chainY = o.y
		if not quiet then C.sfx("slice", { pitch = 1 + math.min(8, b.chainN - 1) * 0.09 }) end
		if live then
			addText("+" .. pts, o.x, o.y - o.r * 0.5, gold and R * 0.95 or R * 0.72, gold and COL.gold or WHITE, 0.75)
			if b.chainN >= 2 then addText("x" .. b.chainN, o.x + o.r, o.y - o.r * 1.35, R * 0.55, "rgb", 0.5) end
		end
		if gold then
			table.insert(rings, { x = o.x, y = o.y, r = o.r, dr = R * 9, life = 0.45, max = 0.45, col = COL.gold, w = 7 })
			spark(o.x, o.y, 26, { COL.gold, COL.goldL, WHITE, COL.goldD }, R * 9)
			if not quiet then C.sfx("golden") end
			if live then
				freeze = math.max(freeze, 0.07)
				bumpShake(7)
				flash(COL.gold, 0.18)
				addText("DORÉ ! +5", o.x, o.y - o.r * 1.8, R * 0.8, COL.gold, 1, true)
			end
		else
			spark(o.x, o.y, 6, { WHITE, hsl(C.hue(o.x), 100, 70) }, R * 5)
		end
	end
	local function segHit(o, x1, y1, x2, y2, rad)
		local dx, dy = x2 - x1, y2 - y1
		local l2 = dx * dx + dy * dy
		local t = l2 > 0 and clamp(((o.x - x1) * dx + (o.y - y1) * dy) / l2, 0, 1) or 0
		local px, py = x1 + dx * t - o.x, y1 + dy * t - o.y
		return px * px + py * py <= rad * rad
	end
	local function bladeSeg(b, x1, y1, x2, y2)
		if mode ~= "play" and mode ~= "menu" and mode ~= "results" then return end
		local ang = math.atan2(y2 - y1, x2 - x1)
		for _, o in objs do
			if not o.dead then
				local rad = o.kind == "bomb" and o.r * 0.72 or o.r * 1.05
				if segHit(o, x1, y1, x2, y2, rad) then sliceObj(o, ang, b) end
			end
		end
	end
	local function bladeTo(b, x, y, t)
		local dx, dy = x - b.lastX, y - b.lastY
		local d = math.sqrt(dx * dx + dy * dy)
		if d < 0.5 then return end
		local dtt = math.max(0.001, t - b.lastT)
		if #b.pts == 0 then table.insert(b.pts, { x = b.lastX, y = b.lastY, t = realT }) end
		table.insert(b.pts, { x = x, y = y, t = realT })
		if #b.pts > 48 then table.remove(b.pts, 1) end
		if b.ai or d / dtt > SLICE_SPEED then bladeSeg(b, b.lastX, b.lastY, x, y) end
		b.lastX, b.lastY, b.lastT = x, y, t
	end
	local function missed(o)
		local x = clamp(o.x, R, W - R)
		table.insert(marks, { x = x, life = 1.2, max = 1.2 })
		addText(pick(Q_MISS), x, H - R * 2.3, R * 0.55, RED, 0.9)
		C.sfx("miss")
		bumpShake(7)
		flash(COL.r2, 0.15)
		loseLife()
	end
	function loseLife()
		if lives <= 0 then return end
		lives -= 1
		heartFx[lives + 1] = 1
		if lives <= 0 then gameOver("ko") end
	end

	----------------------------------------------------------------------- déroulé
	local function forEachBlade(fn)
		for _, b in blades do fn(b) end
	end
	function startRun()
		if mode ~= "menu" and mode ~= "results" then return end
		if mode == "results" and res.stage < 2 then return end
		menu.show(false)
		res.hide()
		objs, halves, parts, texts, rings, slashes, marks, queue = {}, {}, {}, {}, {}, {}, {}, {}
		blades, fading = {}, {}
		ai.pts = {}
		ai.busy = false
		ai.chainN = 0
		score, lives, elapsed, nextWave, lastGold, lastTick = 0, LIVES, 0, 0, -99, 0
		bestAtStart = ctx.best()
		recAnnounced = false
		frenzyAt = { rand(16, 21), rand(37, 44) }
		frenzyOn = false
		stats = { sliced = 0, gold = 0, bombs = 0, maxCombo = 0 }
		heartFx = { 0, 0, 0 }
		freeze, shake, flashA = 0, 0, 0
		mode = "count"
		countT, countStep, goT, resumeRun = 0, -1, 0, false
		runId += 1
		ctx.startRound()
		C.sfx("pop")
	end
	local function pause()
		if mode ~= "play" then return end
		forEachBlade(function(b)
			b.chainN = 0
			table.insert(fading, b)
		end)
		blades = {}
		mode = "paused"
	end
	local function resume()
		if mode ~= "paused" then return end
		mode = "count"
		countT, countStep, resumeRun = 0, -1, true
	end
	function gameOver(reason)
		if mode ~= "play" then return end
		forEachBlade(resolveChain)
		mode = "over"
		overT, overReason, frenzyOn, queue = 0, reason, false, {}
		forEachBlade(function(b) table.insert(fading, b) end)
		blades = {}
		if reason == "time" then
			addText("TEMPS ÉCOULÉ !", W / 2, H * 0.45, R * 1.3, "rgb", 1.6, true)
			C.sfx("win")
		else
			addText("GAME OVER", W / 2, H * 0.45, R * 1.5, RED, 1.6, true)
			C.sfx("lose")
		end
	end
	local function showResults()
		if mode == "results" then return end
		mode = "results"
		local sc = score
		local bestBefore = ctx.best()
		local time = overReason == "time"
		res.show({
			head = time and "TEMPS ÉCOULÉ !" or "GAME OVER", headIcon = time and "ui:clock" or "ui:skull", quip = quipFor(sc),
			score = sc, best = math.max(bestBefore, sc), isBest = sc > bestBefore and sc > 0, fmt = ctx.fmt,
			stats = {
				{ "ui:cookie", stats.sliced .. (stats.sliced > 1 and " tranchés" or " tranché") },
				{ "ui:golden", stats.gold .. (stats.gold > 1 and " dorés" or " doré") },
				{ "ui:fire", "combo max x" .. stats.maxCombo },
			},
		})
		local myRun = runId
		ctx.endRound(sc, function(r, hint)
			if destroyed or myRun ~= runId or mode ~= "results" then return end
			if r then
				hint = ctx.gemHint(r.score or sc)
				if r.best then menu.setBest(r.best) end
			end
			res.rewards(r, hint)
		end)
		demoT = 0.9
		ai.cool = 1
	end

	----------------------------------------------------------------------- mise à jour
	local function updatePlay(dt)
		elapsed += dt
		local p = clamp(elapsed / ROUND, 0, 1)
		if not frenzyOn and #frenzyAt > 0 and elapsed >= frenzyAt[1] then startFrenzy() end
		if frenzyOn and elapsed >= frenzyEnd then frenzyOn = false end
		if not frenzyOn and elapsed >= nextWave then
			spawnWave(p)
			nextWave = elapsed + lerp(1.55, 0.72, p) + rand(-0.12, 0.18)
		end
		flushQueue()
		local sec = math.ceil(ROUND - elapsed)
		if sec <= 5 and sec >= 1 and sec ~= lastTick then
			lastTick = sec
			C.sfx("tick", { pitch = 1.2 + (5 - sec) * 0.08 })
			timerPulse = 1
		end
		if elapsed >= ROUND then gameOver("time") end
	end
	local function aiUpdate(dt)
		if ai.busy then
			ai.t += dt
			local k = math.min(1, ai.t / ai.dur)
			local e = k * k * (3 - 2 * k)
			bladeTo(ai, lerp(ai.x0, ai.x1, e), lerp(ai.y0, ai.y1, e), realT)
			if k >= 1 then
				ai.busy = false
				ai.cool = rand(0.05, 0.4)
			end
			return
		end
		ai.cool -= dt
		if ai.cool > 0 then return end
		local o = nil
		for _, b in objs do
			if not b.dead and not b.aiSkip and b.kind ~= "bomb" and b.vy > -b.g * 0.25 and b.y < H * 0.75 then
				o = b
				break
			end
		end
		if not o then return end
		if math.random() < 0.1 then
			o.aiSkip = true
			return
		end
		local T = ai.dur * 0.5
		local px, py = o.x + o.vx * T, o.y + o.vy * T + 0.5 * o.g * T * T
		local a, d = rand(0, TAU), o.r * 2.4
		ai.x0, ai.y0 = px - math.cos(a) * d, py - math.sin(a) * d
		ai.x1, ai.y1 = px + math.cos(a) * d, py + math.sin(a) * d
		ai.lastX, ai.lastY, ai.lastT = ai.x0, ai.y0, realT
		ai.pts = { { x = ai.x0, y = ai.y0, t = realT } }
		ai.t = 0
		ai.busy = true
	end
	local function demoUpdate(dt)
		demoT -= dt
		if demoT <= 0 and #objs < 7 then
			demoT = rand(0.55, 1.1)
			local k = math.random()
			launch(k < 0.1 and "gold" or (k < 0.2 and "bomb" or "cookie"), { speed = 0.9 })
			if math.random() < 0.35 then launch("cookie", { speed = 0.9 }) end
		end
		aiUpdate(dt)
	end
	local function physics(dt)
		for i = #objs, 1, -1 do
			local o = objs[i]
			if o.dead then
				table.remove(objs, i)
			else
				o.vy += o.g * dt
				o.x += o.vx * dt
				o.y += o.vy * dt
				o.rot += o.vr * dt
				if o.vy > 0 and o.y > H + o.r * 1.3 then
					table.remove(objs, i)
					if mode == "play" and o.kind == "cookie" and not o.frenzy then missed(o) end
				end
			end
		end
		for i = #halves, 1, -1 do
			local h = halves[i]
			h.vy += h.g * dt
			h.x += h.vx * dt
			h.y += h.vy * dt
			h.ang += h.va * dt
			if h.y > H + h.r * 2.5 then table.remove(halves, i) end
		end
		local n = #parts
		local i = 1
		while i <= n do
			local p = parts[i]
			p.life -= dt
			if p.life <= 0 then
				parts[i] = parts[n]
				parts[n] = nil
				n -= 1
			else
				p.vx *= p.drag
				p.vy = p.vy * p.drag + p.g * dt
				p.x += p.vx * dt
				p.y += p.vy * dt
				p.rot += p.vr * dt
				i += 1
			end
		end
		for j = #texts, 1, -1 do
			local t = texts[j]
			t.life -= dt
			t.y += t.vy * dt
			t.vy *= 0.94
			if t.life <= 0 then table.remove(texts, j) end
		end
		for j = #rings, 1, -1 do
			local r = rings[j]
			r.life -= dt
			r.r += r.dr * dt * (r.life / r.max)
			if r.life <= 0 then table.remove(rings, j) end
		end
		for j = #slashes, 1, -1 do
			slashes[j].life -= dt
			if slashes[j].life <= 0 then table.remove(slashes, j) end
		end
		for j = #marks, 1, -1 do
			marks[j].life -= dt
			if marks[j].life <= 0 then table.remove(marks, j) end
		end
	end
	local function pruneTrail(b)
		local cut = realT - 0.13
		local pts = b.pts
		local k = 0
		while k < #pts and pts[k + 1].t < cut do k += 1 end
		if k > 0 then
			for _ = 1, k do table.remove(pts, 1) end
		end
	end
	local function step(dt)
		shake = math.max(0, shake - dt * 60)
		flashA = math.max(0, flashA - dt * 2.2)
		scoreBump = math.max(0, scoreBump - dt * 4)
		timerPulse = math.max(0, timerPulse - dt * 3)
		for i = 1, 3 do heartFx[i] = math.max(0, heartFx[i] - dt * 1.6) end
		for _, m in motes do
			m.y -= m.sp * dt
			if m.y < -0.05 then
				m.y = 1.05
				m.x = math.random()
			end
		end
		if mode == "paused" then return end
		local sdt = dt
		if freeze > 0 then
			freeze -= dt
			sdt = 0
		end
		if mode == "count" then
			countT += dt
			local st = math.min(3, math.floor(countT / STEP))
			if st ~= countStep then
				countStep = st
				if st < 3 then C.sfx("tick", { pitch = 1 + st * 0.18 }) end
			end
			if st >= 3 then
				mode = "play"
				goT = GO_T
				C.sfx("whoosh")
				C.sfx("perfect")
				if not resumeRun then nextWave = elapsed + 0.35 end
				resumeRun = false
			end
		end
		if goT > 0 then goT -= dt end
		if mode == "play" and sdt > 0 then updatePlay(sdt) end
		if mode == "over" then
			overT += dt
			if overT > 1.5 then showResults() end
		end
		if (mode == "menu" or mode == "results") and sdt > 0 then demoUpdate(sdt) end
		if sdt > 0 and mode ~= "count" then physics(sdt) end
		forEachBlade(function(b)
			if b.chainN > 0 and realT - b.chainT > CHAIN_GAP then resolveChain(b) end
		end)
		if ai.chainN > 0 and realT - ai.chainT > CHAIN_GAP then resolveChain(ai) end
		pruneTrail(ai)
		forEachBlade(pruneTrail)
		for i = #fading, 1, -1 do
			pruneTrail(fading[i])
			if #fading[i].pts == 0 then table.remove(fading, i) end
		end
	end

	----------------------------------------------------------------------- rendu
	local BOX = {}
	local function pill(cv, x, y, w, h, col, a, rotDeg)
		BOX.color, BOX.alpha, BOX.radius, BOX.rot = col, a, 999, rotDeg
		return cv:box(x, y, w, h, BOX)
	end
	local function goldRay() return COL.goldRay, 0.3 end

	local function drawBg()
		local cx, cy = W / 2, H * 0.48
		local rr = math.sqrt(W * W + H * H)
		local h0 = C.hue(0)
		local al = frenzyOn and 0.09 or 0.045
		cvBg:rays(cx, cy, rr, 12, 0.5, realT * (frenzyOn and 0.8 or 0.12), function(i) return hsl(h0 + i * 30, 100, 60), al end)
		for _, m in motes do cvBg:circle(m.x * W, m.y * H, m.s, hsl(h0 + m.h, 100, 70), 0.35) end
	end
	-- moitié de cookie : l'image est recadrée (ImageRect) sur sa moitié haute ou basse et tournée
	-- selon l'angle de coupe — la découpe du site (clip) sans ClipsDescendants (incompatible rotation)
	local function halfImg(cv, key, h, S, deg, ca, sa)
		local sz = C.imgSize(key)
		local iw, ih = sz.X, sz.Y
		local oy = h.side < 0 and -S / 4 or S / 4
		local cx, cy = h.x - sa * oy, h.y + ca * oy
		return cv:img(key, cx, cy, S, S / 2, deg, nil, 1, Vector2.new(0, h.side < 0 and 0 or ih / 2), Vector2.new(iw, ih / 2))
	end
	local function drawHalves(cv)
		for _, h in halves do
			local p = h.skin == "golden" and GOLD_PAL or C.pal()
			local key, mul = C.cookieKey(h.skin)
			local deg = math.deg(h.ang)
			local ca, sa = math.cos(h.ang), math.sin(h.ang)
			if key then
				local S = h.r * mul
				local back, front
				if h.acc and mul == 3.2 then back, front = C.accLayers() end
				if back then
					for _, k in back do halfImg(cv, k, h, S, deg, ca, sa) end
				end
				halfImg(cv, key, h, S, deg, ca, sa)
				if front then
					for _, k in front do halfImg(cv, k, h, S, deg, ca, sa) end
				end
			else
				-- sans art : demi-disque approché par un disque décalé
				local oy = h.side * h.r * 0.35
				cv:circle(h.x - sa * oy, h.y + ca * oy, h.r * 0.7, p.base, 1)
			end
			-- tranche : bord foncé + liseré clair (la moitié côté mie de chaque trait, comme le clip)
			local o1 = h.side * h.r * 0.05
			cv:rect(h.x - sa * o1, h.y + ca * o1, h.r * 1.9, h.r * 0.1, p.dark, 1, deg)
			local o2 = h.side * h.r * 0.0225
			cv:rect(h.x - sa * o2, h.y + ca * o2, h.r * 1.76, h.r * 0.045, p.light, 1, deg)
		end
	end
	local function drawObjs(cv)
		for _, o in objs do
			if not o.dead then
				if o.kind == "bomb" then
					local pulse = 0.5 + 0.5 * math.sin(realT * 14 + o.seed)
					cv:glow(o.x, o.y, o.r * (1.7 + pulse * 0.5), COL.bombGlow, 0.35 + pulse * 0.35)
					-- anneau pointillé qui tourne (setLineDash du site)
					local rr = o.r * 1.18
					local nd = 12
					local off = realT * 40 / rr
					local dashA = (o.r * 0.35) / rr
					local ra = 0.5 + pulse * 0.5
					for i = 0, nd - 1 do
						local a0 = off + i * TAU / nd
						local a1 = a0 + dashA
						cv:line(o.x + math.cos(a0) * rr, o.y + math.sin(a0) * rr, o.x + math.cos(a1) * rr, o.y + math.sin(a1) * rr, 3, COL.bombRing, ra)
					end
					local s = o.r * 2.3
					if not cv:img("item:broccoli", o.x, o.y, s, s, math.deg(o.rot * 0.35)) then
						cv:ptext("🥦", o.x, o.y, s * 0.8, WHITE, 1, "center", C.FB)
					end
				elseif o.kind == "gold" then
					local pulse = 0.6 + 0.4 * math.sin(realT * 10 + o.seed)
					cv:glow(o.x, o.y, o.r * 2.2, COL.gold, 0.55 * pulse)
					cv:rays(o.x, o.y, o.r * 2.3, 6, 1 / 6, realT * 2, goldRay)
					cv:cookie(o.x, o.y, o.r, o.rot, { skin = "golden" })
				else
					if o.frenzy then cv:glow(o.x, o.y, o.r * 1.6, COL.pinkGlow, 0.3) end
					cv:cookie(o.x, o.y, o.r, o.rot, { acc = o.acc })
				end
			end
		end
	end
	local function drawParts(cv)
		for _, p in parts do
			local a = clamp(p.life / p.max, 0, 1)
			if p.sq then
				cv:rect(p.x, p.y, p.size, p.size * 0.8, p.col, math.min(1, a * 1.8), math.deg(p.rot))
			elseif p.add then
				cv:circle(p.x, p.y, p.size * (0.4 + a * 0.6), p.col, a)
			else
				cv:circle(p.x, p.y, p.size, p.col, math.min(1, a * 1.8))
			end
		end
	end
	local function drawSlashes(cv)
		for _, s in slashes do
			local a = s.life / s.max
			pill(cv, s.x, s.y, s.len * (1.25 - a * 0.25), 2 * (R * 0.09 * a + 1), WHITE, a, math.deg(s.ang))
		end
	end
	local function drawRings(cv)
		for _, r in rings do
			local a = r.life / r.max
			local col = r.col == "rgb" and hsl(C.hue(r.r), 100, 62) or r.col
			cv:ring(r.x, r.y, r.r, r.w * a + 1, col, a)
		end
	end
	local function drawMarks(cv)
		for _, m in marks do
			local a = m.life / m.max
			local k = 1 - a
			local sc = k < 0.15 and C.easeOutBack(k / 0.15) or 1
			cv:text("X", m.x, H - R * 0.9, R * 1.1, RED, math.min(1, a * 2), "center", 0, sc)
		end
	end
	local function drawBlade(cv, b)
		local pts = b.pts
		local n = #pts
		if n < 2 then return end
		local h0 = C.hue(0)
		local wMax = clamp(R * 0.32, 9, 18)
		for pass = 0, 1 do
			for i = 2, n do
				local k = (i - 1) / (n - 1)
				local p0, p1 = pts[i - 1], pts[i]
				if pass == 0 then
					cv:line(p0.x, p0.y, p1.x, p1.y, 2 + wMax * 1.6 * k, hsl(h0 + (i - 1) * 14, 100, 60), 0.4 * k, true)
				else
					cv:line(p0.x, p0.y, p1.x, p1.y, 1 + wMax * 0.45 * k, hsl(h0 + (i - 1) * 14, 100, 88), 0.95 * k, true)
				end
			end
		end
		local tip = pts[n]
		cv:circle(tip.x, tip.y, wMax * 0.35, WHITE, 0.9)
	end
	local function drawTexts(cv)
		for _, t in texts do
			local age = t.max - t.life
			local sc = age < 0.2 and C.easeOutBack(age / 0.2) or 1
			local a = t.life < t.max * 0.3 and t.life / (t.max * 0.3) or 1
			local rot = t.big and math.deg(math.sin(age * 16) * 0.04) or 0
			local col = t.col == "rgb" and hsl(C.hue(t.x * 0.3 + age * 240), 100, 66) or t.col
			cv:text(t.str, t.x, t.y, t.size, col, clamp(a, 0, 1), "center", rot, sc)
		end
	end
	local widthCache = {}
	local function textW100(str)
		local w = widthCache[str]
		if not w then
			w = C.textW(str, 100, C.FD)
			widthCache[str] = w
		end
		return w
	end
	local function barSeq(frac, h0)
		local function colAt(u)
			if u <= 0.5 then return hsl(h0, 100, 60):Lerp(hsl(h0 + 120, 100, 60), u / 0.5) end
			return hsl(h0 + 120, 100, 60):Lerp(hsl(h0 + 240, 100, 60), (u - 0.5) / 0.5)
		end
		if frac > 0.5 then
			return ColorSequence.new({
				ColorSequenceKeypoint.new(0, colAt(0)), ColorSequenceKeypoint.new(0.5 / frac, colAt(0.5)), ColorSequenceKeypoint.new(1, colAt(frac)),
			})
		end
		return ColorSequence.new(colAt(0), colAt(math.max(frac, 0.001)))
	end
	local HUDBOX = {}
	local function drawHud(cv)
		local top = 32
		local left = math.max(0, ROUND - elapsed)
		local frac = left / ROUND
		cv:rectTL(0, 0, W, 6, BLACK, 0.4)
		if frac > 0 then
			if left < 10 then
				cv:rectTL(0, 0, W * frac, 6, RED, 1)
			else
				HUDBOX.color, HUDBOX.alpha, HUDBOX.grad = WHITE, 1, barSeq(frac, C.hue(0))
				cv:box(W * frac / 2, 3, W * frac, 6, HUDBOX)
			end
		end
		-- score
		local ss = clamp(W * 0.085, 26, 40) * (1 + scoreBump * 0.35)
		cv:cookie(26, top, 14, realT * 0.8)
		cv:text(tostring(score), 46, top + 1, ss, WHITE, 1, "left")
		-- chrono
		local s = math.ceil(left)
		local ts = clamp(W * 0.065, 20, 28) * (1 + timerPulse * 0.35)
		local tstr = string.format("%d:%02d", s // 60, s % 60)
		cv:text(tstr, W / 2, top, ts, left < 10 and RED or WHITE)
		cv:icon("ui:clock", W / 2 - textW100(tstr) * ts / 200 - ts * 0.6, top, ts * 0.95)
		if frenzyOn then cv:text("FRENZY !", W / 2, top + ts * 1.05, 18, hsl(C.hue(0), 100, 65)) end
		-- vies
		local hs = clamp(W * 0.07, 22, 30)
		for i = 0, LIVES - 1 do
			local x = W - 14 - hs * 0.55 - (LIVES - 1 - i) * hs * 1.22
			local alive = i < lives
			local fx = heartFx[i + 1]
			local sc = fx > 0 and 1 + math.sin(fx * math.pi) * 0.7 or 1
			if alive then cv:glow(x, top, hs * 0.9 * sc, COL.heartGlow, 0.35) end
			local key = alive and "ui:heart" or "ui:heart_empty"
			if not cv:img(key, x, top, hs * 1.3 * sc, hs * 1.3 * sc) then
				cv:ptext(alive and "❤️" or "🤍", x, top, hs * sc, WHITE, 1, "center", C.FB)
			end
			if not alive and fx > 0 then cv:glow(x, top, hs * sc, WHITE, fx * 0.9) end
		end
	end
	local function drawCountdown(cv)
		local label, k, idx
		if mode == "count" then
			idx = clamp(countStep, 0, 2)
			label = tostring(3 - idx)
			k = (countT - idx * STEP) / STEP
		else
			idx = 3
			label = "GO !"
			k = 1 - goT / GO_T
		end
		k = clamp(k, 0, 1)
		local sc = k < 0.35 and C.easeOutBack(k / 0.35) or 1 + (k - 0.35) * 0.15
		local a = k > 0.7 and 1 - (k - 0.7) / 0.3 or 1
		local size = math.min(W, H) * (idx == 3 and 0.24 or 0.34)
		local cy = H * 0.46
		cv:ring(W / 2, cy, size * (0.6 + k * 0.9), 6 * (1 - k) + 1, hsl(C.hue(idx * 90 + 60), 100, 65), a * 0.6)
		cv:text(label, W / 2, cy, size, hsl(C.hue(idx * 90), 100, 65), a, "center", math.deg((1 - k) * 0.12 * (idx % 2 == 1 and 1 or -1)), sc)
		if mode == "count" then
			cv:text(resumeRun and "ON REPREND !" or "GLISSE POUR TRANCHER", W / 2, cy + size * 0.75, clamp(W * 0.05, 15, 22), WHITE)
		end
	end
	local FRAME = {}
	local function render()
		cvBg:begin()
		drawBg()
		cvBg:finish()

		cvW:begin()
		if shake > 0.3 then
			cvW.frame.Position = UDim2.fromOffset(rand(-shake, shake), rand(-shake, shake))
		else
			cvW.frame.Position = UDim2.fromOffset(0, 0)
		end
		drawMarks(cvW)
		drawObjs(cvW)
		drawHalves(cvW)
		drawParts(cvW)
		drawSlashes(cvW)
		drawRings(cvW)
		for _, b in fading do drawBlade(cvW, b) end
		for _, b in blades do drawBlade(cvW, b) end
		drawBlade(cvW, ai)
		drawTexts(cvW)
		cvW:finish()

		cvH:begin()
		if mode == "count" or mode == "play" or mode == "paused" or mode == "over" then drawHud(cvH) end
		if frenzyOn and mode == "play" then
			FRAME.color, FRAME.stroke, FRAME.sw, FRAME.sa = false, hsl(C.hue(0), 100, 60), 10, 0.55 + 0.3 * math.sin(realT * 12)
			cvH:box(W / 2, H / 2, W - 10, H - 10, FRAME)
		end
		if mode == "count" or goT > 0 then drawCountdown(cvH) end
		if mode == "paused" then
			cvH:rectTL(0, 0, W, H, COL.veil, 0.6)
			cvH:text("PAUSE", W / 2, H * 0.44, clamp(W * 0.16, 44, 90), hsl(C.hue(0), 100, 66))
			cvH:text("Tape pour reprendre", W / 2, H * 0.44 + 60, clamp(W * 0.05, 16, 24), WHITE)
		end
		if flashA > 0.01 then
			cvH:rectTL(0, 0, W, H, flashRgb and hsl(C.hue(0), 100, 60) or flashCol, math.min(0.6, flashA))
		end
		cvH:finish()
	end

	----------------------------------------------------------------------- boucle
	local function resize()
		local s = root.AbsoluteSize
		local w, h = math.max(160, math.floor(s.X + 0.5)), math.max(200, math.floor(s.Y + 0.5))
		if w == W and h == H then return end
		W, H = w, h
		R = clamp(math.min(W, H) * 0.085, 28, 60)
		layoutBg()
		menu.layout(W, H)
		res.layout(W, H)
	end
	local FX = {
		onRecord = function()
			confetti(70)
			flash("rgb", 0.2)
		end,
	}
	bag.add(RunService.RenderStepped:Connect(function(dt)
		if destroyed then return end
		if not (dt > 0) then dt = 0 end
		if dt > 0.05 then dt = 0.05 end
		realT += dt
		resize()
		step(dt)
		render()
		if mode == "menu" then menu.update(realT) end
		if mode == "results" then res.update(dt, realT, FX) end
	end))

	----------------------------------------------------------------------- entrées
	local function onDown(key, x, y)
		if mode == "paused" then
			resume()
			return
		end
		local old = blades[key]
		if old then table.insert(fading, old) end
		blades[key] = { ai = false, pts = { { x = x, y = y, t = realT } }, chainN = 0, chainT = 0, chainX = x, chainY = y, lastX = x, lastY = y, lastT = os.clock() }
	end
	local function onUp(key)
		local b = blades[key]
		if not b then return end
		blades[key] = nil
		resolveChain(b)
		table.insert(fading, b)
	end
	bag.add(hit.InputBegan:Connect(function(input)
		local ut = input.UserInputType
		if ut == Enum.UserInputType.MouseButton1 then
			local x, y = C.inputXY(input, root)
			onDown("mouse", x, y)
		elseif ut == Enum.UserInputType.Touch then
			local x, y = C.inputXY(input, root)
			onDown(input, x, y)
		end
	end))
	bag.add(UIS.InputChanged:Connect(function(input)
		local ut = input.UserInputType
		local b
		if ut == Enum.UserInputType.MouseMovement then
			b = blades.mouse
		elseif ut == Enum.UserInputType.Touch then
			b = blades[input]
		end
		if b then
			local x, y = C.inputXY(input, root)
			bladeTo(b, x, y, os.clock())
		end
	end))
	bag.add(UIS.InputEnded:Connect(function(input)
		local ut = input.UserInputType
		if ut == Enum.UserInputType.MouseButton1 then
			onUp("mouse")
		elseif ut == Enum.UserInputType.Touch then
			onUp(input)
		end
	end))
	bag.add(UIS.InputBegan:Connect(function(input)
		if UIS:GetFocusedTextBox() then return end
		local k = input.KeyCode
		if k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter then
			if mode == "menu" or (mode == "results" and res.stage >= 3) then
				startRun()
			elseif mode == "paused" then
				resume()
			end
		elseif (k == Enum.KeyCode.Space or k == Enum.KeyCode.P) and mode == "paused" then
			resume()
		elseif k == Enum.KeyCode.P and mode == "play" then
			pause()
		end
	end))
	bag.add(UIS.WindowFocusReleased:Connect(pause))

	resize()
	menu.show(true)

	return {
		destroy = function()
			if destroyed then return end
			destroyed = true
			bag.clean()
			objs, halves, parts, texts, rings, slashes, marks, queue, fading = {}, {}, {}, {}, {}, {}, {}, {}, {}
			blades = {}
			cvBg:destroy()
			cvW:destroy()
			cvH:destroy()
		end,
	}
end

return Ninja
