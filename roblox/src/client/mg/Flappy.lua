--!nonstrict
-- COOKIE OVERDRIVE — mini-jeu « Flappy Cookie » (port de mg-flappy.js).
-- TON cookie (skin + accessoires) vole entre des verres de lait géants, au-dessus d'une ville
-- synthwave en parallaxe. Tape / clic / Espace / ↑ / W / Z pour battre des ailes ; pépites et
-- gemmes = +1 ; tous les 10 points, AURA +10. Monde en « unités » : 100 u = hauteur de la zone.
-- Rendu : couches fixes (ciel, soleil, villes en EditableImage) + Canvas redessiné chaque frame.
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")

local C = require(script.Parent:WaitForChild("Common"))

local STEP, GO_T = 0.62, 0.7
local G = 150 -- gravité (u/s²)
local FLAP = -46 -- impulsion (u/s)
local VMAX = 78 -- vitesse de chute max
local GROUND = 90 -- haut du sol (u)
local BR = 4.3 -- rayon visuel du cookie (u)
local HR = 3.3 -- rayon de collision
local PW = 14 -- largeur d'un verre (u)
local MAX_PARTS = 300
local SERVER_RATE = 0.9 -- points/s acceptés par le serveur (Main.server.lua › MG_RULES.flappy)

local hex, hsl, clamp, lerp, rand, pick, TAU = C.hex, C.hsl, C.clamp, C.lerp, C.rand, C.pick, C.TAU
local WHITE, BLACK = C.col.white, C.col.black
local COL = {
	red = hex("#ff4d6d"), hit = hex("#ff3050"), gold = hex("#ffc93c"), cyan = hex("#1ff4ff"), violet = hex("#b16bff"),
	chipD = hex("#7a4424"), veil = hex("#0b0620"), glass = Color3.fromRGB(190, 230, 255), base = Color3.fromRGB(215, 238, 255),
	wave = Color3.fromRGB(170, 150, 230), gemGlow = Color3.fromRGB(31, 244, 255), chipGlow = Color3.fromRGB(255, 201, 60),
	sunGlow = Color3.fromRGB(255, 90, 180),
}
local MILK_STOPS = { { 0, hex("#d2c9f2") }, { 0.28, hex("#ffffff") }, { 0.72, hex("#fbf7ff") }, { 1, hex("#c9bdf0") } }
local MILK_SEQ = C.seq(MILK_STOPS)
local function milkAt(t)
	t = clamp(t, 0, 1)
	for i = 2, #MILK_STOPS do
		local a, b = MILK_STOPS[i - 1], MILK_STOPS[i]
		if t <= b[1] then return a[2]:Lerp(b[2], (t - a[1]) / (b[1] - a[1])) end
	end
	return MILK_STOPS[#MILK_STOPS][2]
end
local SKY_SEQ = C.seq({ { 0, hex("#07021a") }, { 0.4, hex("#1c0747") }, { 0.78, hex("#5a137a") }, { 1, hex("#ff4fa3") } })
local GROUND_SEQ = ColorSequence.new(hex("#2b0a4f"), hex("#0b0620"))
local WIN_COLS = { { 255, 106, 213 }, { 31, 244, 255 }, { 255, 224, 102 }, { 182, 255, 59 }, { 255, 255, 255 } }

local Q_DEATH = { "skill issue", "RIP le cookie", "cheh", "le lait a gagné", "même pas mal ?", "aura -1000" }
local Q_AURA = { "W", "TROP FORT", "NO CAP", "INSANE", "MAIN CHARACTER", "CHEF !", "IL VOLE !!" }

local function gapFor(s) return math.max(24, 34 - s * 0.22) end
local function speedFor(s) return math.min(44, 30 + s * 0.33) end
local function spacingFor(s) return math.max(37, 45 - s * 0.16) end

local function quipFor(score)
	if score >= 50 then return "Oiseau légendaire. Aura infinie." end
	if score >= 25 then return "W énorme, t'es chaud !" end
	if score >= 10 then return "Pas mal du tout, continue !" end
	if score >= 3 then return "Ça vole… à peu près." end
	return "skill issue (c'est dur, on sait)"
end
local function ulen(s) return utf8.len(s) or #s end
local function circRect(cx, cy, r, x, y, w, h)
	local nx, ny = clamp(cx, x, x + w), clamp(cy, y, y + h)
	local dx, dy = cx - nx, cy - ny
	return dx * dx + dy * dy < r * r
end

----------------------------------------------------------------------------- textures
-- aile (chemin quadratique du site, en rayons r) : zone x ∈ [-1.42, 0.12], y ∈ [-0.76, 0.5]
local WING = { x0 = -1.42, y0 = -0.76, w = 1.54, h = 1.26 }
local function texWing()
	return C.proc("flappyWing", 128, 105, function(buf, w, h)
		local S = w / WING.w
		local function X(v) return (v - WING.x0) * S end
		local function Y(v) return (v - WING.y0) * S end
		local function Q(cx, cy, x, y) return { "Q", X(cx), Y(cy), X(x), Y(y) } end
		local pts = C.flatten({
			{ "M", X(0), Y(-0.05) }, Q(-0.55, -0.62, -1.25, -0.42), Q(-1.08, -0.2, -1.2, -0.06), Q(-0.98, 0.06, -1.05, 0.2),
			Q(-0.78, 0.26, -0.78, 0.38), Q(-0.36, 0.34, 0, 0.12),
		}, 10)
		local function fill(_, cy)
			local t = clamp((cy / S + WING.y0 + 0.5) / 0.9, 0, 1)
			return 255 + (207 - 255) * t, 255 + (233 - 255) * t, 255
		end
		local lw = 0.055 * S
		C.rasterPoly(buf, w, h, pts, fill, { 26, 11, 51 }, 0.13 * S, {
			{ X(-0.25), Y(-0.08), X(-0.95), Y(-0.14), lw, 0.3 }, { X(-0.25), Y(0.06), X(-0.82), Y(0.12), lw, 0.3 },
		})
	end)
end
-- pépite de chocolat : zone [-1.2, 1.2] × [-1.3, 1.1] (en s)
local function texChip()
	return C.proc("flappyChip", 64, 64, function(buf, w, h)
		local S = w / 2.4
		local function X(v) return (v + 1.2) * S end
		local function Y(v) return (v + 1.3) * S end
		local pts = C.flatten({
			{ "M", X(0), Y(-1.1) },
			{ "C", X(0.35), Y(-0.5), X(1.0), Y(0), X(0.85), Y(0.45) },
			{ "Q", X(0), Y(0.95), X(-0.85), Y(0.45) },
			{ "C", X(-1.0), Y(0), X(-0.35), Y(-0.5), X(0), Y(-1.1) },
		}, 10)
		local ca, sa = math.cos(-0.5), math.sin(-0.5)
		local function fill(cx, cy)
			local x, y = cx / S - 1.2 + 0.3, cy / S - 1.3 + 0.1
			local rx, ry = x * ca - y * sa, x * sa + y * ca
			local e = (rx / 0.18) ^ 2 + (ry / 0.32) ^ 2
			local k = e <= 1 and 0.45 or 0
			return 90 + (255 - 90) * k, 45 + (200 - 45) * k, 18 + (140 - 18) * k
		end
		C.rasterPoly(buf, w, h, pts, fill, { 26, 11, 51 }, math.max(2, 0.2 * S))
	end)
end
-- scintillement (étoile à 4 branches)
local function texSparkle()
	return C.proc("flappySparkle", 64, 64, function(buf, w, h)
		local k = w / 2
		C.rasterPoly(buf, w, h, { { k, 0 }, { k + k * 0.25, k }, { k, 2 * k }, { k - k * 0.25, k } }, { 255, 255, 255 })
		local buf2 = buffer.create(w * h * 4)
		C.rasterPoly(buf2, w, h, { { 0, k }, { k, k + k * 0.25 }, { 2 * k, k }, { k, k - k * 0.25 } }, { 255, 255, 255 })
		for i = 0, w * h - 1 do
			local a2 = buffer.readu8(buf2, i * 4 + 3)
			if a2 > buffer.readu8(buf, i * 4 + 3) then
				buffer.writeu32(buf, i * 4, buffer.readu32(buf2, i * 4))
			end
		end
	end)
end
-- soleil rétro à bandes découpées
local function texSun()
	return C.proc("flappySun", 256, 256, function(buf, w, h)
		local R, cx, cy = 126, 128, 128
		local cuts = {}
		for i = 0, 6 do
			local yy = cy + R * (0.12 + i * 0.13)
			cuts[i + 1] = { yy, yy + 0.6 + i * R * 0.018 }
		end
		local c0, c1, c2 = hex("#fff27a"), hex("#ff8a3d"), hex("#ff2bd6")
		for y = 0, h - 1 do
			local py = y + 0.5
			local t = clamp((py - (cy - R)) / (2 * R), 0, 1)
			local col = t < 0.55 and c0:Lerp(c1, t / 0.55) or c1:Lerp(c2, (t - 0.55) / 0.45)
			local cut = 1
			for _, c in cuts do
				local cov = clamp(math.min(py + 0.5, c[2]) - math.max(py - 0.5, c[1]), 0, 1)
				cut = math.min(cut, 1 - cov)
			end
			for x = 0, w - 1 do
				local dx, dy = x + 0.5 - cx, py - cy
				local a = clamp(R - math.sqrt(dx * dx + dy * dy) + 0.5, 0, 1) * cut
				if a > 0 then C.px(buf, w, x, y, math.floor(col.R * 255), math.floor(col.G * 255), math.floor(col.B * 255), math.floor(a * 255)) end
			end
		end
	end)
end

local Flappy = {}

function Flappy.mount(ctx)
	local root = ctx.root
	local bag = C.bag()
	local destroyed = false

	----------------------------------------------------------------------- état
	local W, H, u, WW, BX = 0, 0, 6, 60, 18
	local realT = 0
	local mode = "menu" -- menu | count | play | paused | dying | results
	local resumeRun, countT, countStep, goT = false, 0, -1, 0
	local bird = { y = 45, vy = 0, rot = 0, flap = 0, alive = true, vis = true }
	local pipes, parts, texts, rings, trail = {}, {}, {}, {}, {}
	local dist, speed, pipeIdx, trailAcc = 0, 30, 0, 0
	local score, items, passed, bestAtStart, recAnnounced = 0, 0, 0, 0, false
	local dieT, crumbled, deathKind = 0, false, "verre"
	local shake, flashA, flashCol, flashRgb, freeze, scoreBump = 0, 0, WHITE, false, 0, 0
	local stars = {}
	local runT0, runId = 0, 0
	local function diff()
		if mode == "play" or mode == "dying" or mode == "paused" or mode == "count" then return score end
		return 0
	end

	----------------------------------------------------------------------- calques
	local world = C.new("Frame", { Name = "World", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = root })
	local sky = C.new("Frame", { Name = "Sky", BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 1, Parent = world }, {
		C.new("UIGradient", { Rotation = 90, Color = SKY_SEQ }),
	})
	local starF = C.new("Frame", { Name = "Stars", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = world })
	local sunGlow = C.new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = COL.sunGlow, ImageTransparency = 0.55, ZIndex = 3, Parent = world })
	if not C.applyProc(sunGlow, C.texGlow(0.3)) then sunGlow.Visible = false end
	local sun = C.new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, Parent = world })
	if not C.applyProc(sun, texSun()) then
		sun.BackgroundTransparency = 0
		sun.BackgroundColor3 = hex("#ff8a3d")
		C.corner(UDim.new(1, 0)).Parent = sun
	end
	local cvStars = C.canvas(world, 5, "Twinkle")
	local farTiles, nearTiles = {}, {}
	for i = 1, 2 do
		farTiles[i] = C.new("Frame", { BackgroundTransparency = 1, ZIndex = 6, Parent = world })
		nearTiles[i] = C.new("Frame", { BackgroundTransparency = 1, ZIndex = 7, Parent = world })
	end
	local cv = C.canvas(world, 10, "Main")
	local shade = C.new("Frame", {
		Name = "MenuShade", BackgroundColor3 = COL.veil, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = root,
	}, { C.new("UIGradient", { Rotation = 90, Transparency = C.nseq({ { 0, 0.28 }, { 0.3, 0.9 }, { 0.62, 0.9 }, { 1, 0.22 } }) }) })
	local cvH = C.canvas(root, 30, "Hud")
	local hit = C.new("TextButton", {
		Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ZIndex = 40, Selectable = false, Parent = root,
	})

	local startRun
	local menu = C.menuScreen(root, {
		hero = "mg:flappy", heroGlow = hex("#1ff4ff"), title = "FLAPPY COOKIE", sub = "Fais voler ton cookie entre les verres de lait",
		subColor = C.col.hot, hueStep = 24, fmt = ctx.fmt, best = ctx.best(), bobPer = 1.2, bobAmp = 4, bobDeg = 8,
		rules = {
			{ "ui:tap", "Tape / Espace = battre des ailes" }, { "item:milk", "Touche pas les verres de lait" },
			{ "ui:gem", "Pépites et gemmes = +1 bonus" }, { "ui:fire", "Tous les 10 = AURA +10" },
		},
		onPlay = function() startRun() end,
	})
	local res = C.resultsCard(root, {
		cuK = 0.015,
		onAgain = function() startRun() end,
		onQuit = function() ctx.close() end,
	})

	----------------------------------------------------------------------- fond (buildBg)
	local cityEI = {}
	local far, near = nil, nil
	local nearRoofs = {}
	local function genCity(tw, th, minW, maxW, minH, maxH, winA, roofs)
		local blds = {}
		local x = 0
		while x < tw do
			local bw = math.min(rand(minW, maxW) * u, tw - x)
			local bh = rand(minH, maxH) * u
			local b = { x = x, w = bw, h = bh, wins = {} }
			if math.random() < 0.25 and bw > 3 * u then b.ant = { x + bw * 0.45, math.max(1.5, u * 0.3), 3 * u } end
			local cw, ch = math.max(1.5, u * 0.75), math.max(2, u * 1.0)
			local wy = th - bh + u * 1.5
			while wy < th - u do
				local wx = x + u * 1.1
				while wx < x + bw - u do
					if math.random() < 0.32 then table.insert(b.wins, { wx, wy, cw, ch, pick(WIN_COLS), winA * rand(0.5, 1) }) end
					wx += u * 1.9
				end
				wy += u * 2.4
			end
			table.insert(blds, b)
			if roofs then table.insert(roofs, { x = x, w = bw, h = bh }) end
			x += bw + rand(0, 1.2) * u
		end
		return blds
	end
	-- rend une bande de ville dans une EditableImage (≤ 1024 px, affichée étirée en « pixelated »)
	local function cityImage(tw, th, blds, body)
		local k = math.min(1, 1024 / tw, 1024 / th)
		local br, bgc, bb = math.floor(body.R * 255 + 0.5), math.floor(body.G * 255 + 0.5), math.floor(body.B * 255 + 0.5)
		return C.procNew(math.ceil(tw * k), math.ceil(th * k), function(buf, w, h)
			local function rect(x, y, rw, rh, r, g, b, a)
				local x0, x1 = math.max(0, math.floor(x * k + 0.5)), math.min(w, math.floor((x + rw) * k + 0.5))
				local y0, y1 = math.max(0, math.floor(y * k + 0.5)), math.min(h, math.floor((y + rh) * k + 0.5))
				if x1 <= x0 then x1 = math.min(w, x0 + 1) end
				if y1 <= y0 then y1 = math.min(h, y0 + 1) end
				for yy = y0, y1 - 1 do
					for xx = x0, x1 - 1 do
						local o = (yy * w + xx) * 4
						local da = buffer.readu8(buf, o + 3)
						if a >= 1 or da == 0 then
							buffer.writeu8(buf, o, r)
							buffer.writeu8(buf, o + 1, g)
							buffer.writeu8(buf, o + 2, b)
							buffer.writeu8(buf, o + 3, a >= 1 and 255 or math.floor(a * 255))
						else
							buffer.writeu8(buf, o, math.floor(buffer.readu8(buf, o) * (1 - a) + r * a))
							buffer.writeu8(buf, o + 1, math.floor(buffer.readu8(buf, o + 1) * (1 - a) + g * a))
							buffer.writeu8(buf, o + 2, math.floor(buffer.readu8(buf, o + 2) * (1 - a) + b * a))
						end
					end
				end
			end
			for _, b in blds do
				rect(b.x, th - b.h, b.w + 0.5, b.h, br, bgc, bb, 1)
				if b.ant then rect(b.ant[1], th - b.h - b.ant[3], b.ant[2], b.ant[3], br, bgc, bb, 1) end
				for _, wn in b.wins do rect(wn[1], wn[2], wn[3], wn[4], wn[5][1], wn[5][2], wn[5][3], wn[6]) end
			end
		end)
	end
	local function fillTiles(tiles, tw, th, blds, body)
		local ei = cityImage(tw, th, blds, body)
		if ei then table.insert(cityEI, ei) end
		for _, t in tiles do
			t:ClearAllChildren()
			t.Size = UDim2.fromOffset(tw, th)
			if ei then
				local l = C.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ResampleMode = Enum.ResamplerMode.Pixelated, ZIndex = t.ZIndex, Parent = t })
				C.applyProc(l, ei)
			else
				-- sans EditableImage : immeubles seuls (pas de fenêtres)
				for _, b in blds do
					C.new("Frame", { BackgroundColor3 = body, BorderSizePixel = 0, Position = UDim2.fromOffset(b.x, th - b.h), Size = UDim2.fromOffset(b.w + 0.5, b.h), ZIndex = t.ZIndex, Parent = t })
				end
			end
		end
	end
	local function buildBg()
		for _, ei in cityEI do pcall(function() ei:Destroy() end) end
		table.clear(cityEI)
		local hz = GROUND * u
		sky.Size = UDim2.fromOffset(W, hz)
		-- étoiles fixes
		starF:ClearAllChildren()
		stars = {}
		local n = math.min(220, math.floor(W * hz / 5200 + 0.5) + 20)
		for i = 1, n do
			local s = { x = rand(0, W), y = rand(0, hz * 0.62), s = rand(0.6, 1.8), p = rand(0, TAU) }
			stars[i] = s
			C.new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 1 - rand(0.2, 0.7), BorderSizePixel = 0, Position = UDim2.fromOffset(s.x, s.y), Size = UDim2.fromOffset(math.max(1, s.s), math.max(1, s.s)), ZIndex = 2, Parent = starF })
		end
		-- soleil
		local sr = math.min(W, H) * 0.2
		local scx, scy = W * 0.72, hz - H * 0.17
		sun.Position = UDim2.fromOffset(scx, scy)
		sun.Size = UDim2.fromOffset(sr * 2 * 128 / 126, sr * 2 * 128 / 126)
		sunGlow.Position = sun.Position
		sunGlow.Size = UDim2.fromOffset(sr * 4, sr * 4)
		-- villes (bandes raccordables)
		local fw, nw = math.ceil(math.max(W, 420)), math.ceil(math.max(W, 520))
		far = { w = fw, h = 34 * u }
		fillTiles(farTiles, fw, far.h, genCity(fw, far.h, 5, 11, 8, 26, 0.45, nil), hex("#230c4f"))
		nearRoofs = {}
		near = { w = nw, h = 48 * u }
		fillTiles(nearTiles, nw, near.h, genCity(nw, near.h, 8, 16, 12, 40, 0.85, nearRoofs), hex("#12052c"))
	end

	----------------------------------------------------------------------- effets
	local function addText(str, x, y, size, col, life, big)
		local n = math.max(3, ulen(str))
		size = math.min(size, (W * 0.92) / (n * 0.56))
		local hw = n * size * 0.29 + 6
		x = clamp(x, hw, math.max(hw, W - hw))
		y = clamp(y, size * 0.7, H - size * 0.7)
		table.insert(texts, { str = str, x = x, y = y, size = size, col = col, life = life or 0.8, max = life or 0.8, vy = big and -u * 2 or -u * 7, big = big == true })
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
	local function spark(x, y, n, cols, spd, add, g)
		for _ = 1, n do
			if #parts >= MAX_PARTS then break end
			local a, sp, l = rand(0, TAU), rand(0.3, 1) * spd, rand(0.35, 0.8)
			table.insert(parts, { x = x, y = y, vx = math.cos(a) * sp, vy = math.sin(a) * sp, g = g or H * 0.4, drag = 0.9, life = l, max = l, size = rand(2, 4.5), col = pick(cols), sq = false, rot = 0, vr = 0, add = add ~= false, grow = 0 })
		end
	end
	local function puff()
		local x, y = (BX - BR * 0.8) * u, (bird.y + BR * 0.4) * u
		for _ = 1, 3 do
			if #parts >= MAX_PARTS then break end
			local l = rand(0.28, 0.42)
			table.insert(parts, { x = x + rand(-2, 2), y = y + rand(-3, 3), vx = -rand(3, 9) * u, vy = rand(1, 6) * u, g = 0, drag = 0.9, life = l, max = l, size = BR * u * rand(0.22, 0.34), col = WHITE, sq = false, rot = 0, vr = 0, add = false, grow = 1.6 })
		end
	end
	local function confetti(n)
		for _ = 1, n do
			if #parts >= MAX_PARTS then break end
			local l = rand(1.6, 2.8)
			table.insert(parts, { x = rand(0, W), y = rand(-40, -5), vx = rand(-40, 40), vy = rand(60, 200), g = H * 0.25, drag = 0.995, life = l, max = l, size = rand(5, 9), col = hsl(rand(0, 360), 100, 62), sq = true, rot = rand(0, TAU), vr = rand(-8, 8), add = false, grow = 0 })
		end
	end

	----------------------------------------------------------------------- monde
	-- Le serveur n'accepte que 0,9 pt/s depuis JOUER : un bonus n'apparaît que s'il reste de la
	-- marge quand le verre arrivera sur le cookie (invisible pour le joueur, comme sur le site
	-- au début de partie ; les bonus se raréfient seulement quand le rythme devient très rapide).
	local function itemBudgetOK(x)
		if mode ~= "play" and mode ~= "count" then return true end
		local ahead = 0
		for _, p in pipes do
			if not p.passed then
				ahead += 1
				if p.item and not p.item.got then ahead += 1 end
			end
		end
		local tReach = math.max(0, (x - BX) / math.max(speed, 1))
		local E = os.clock() - runT0
		return score + ahead + 2 <= SERVER_RATE * (E + tReach + 1.4) + 1
	end
	local function makePipe(x, prevGy, first)
		local gap = gapFor(diff())
		local lo, hi = gap / 2 + 8, GROUND - gap / 2 - 6
		local gy = first and rand(38, 52) or rand(lo, hi)
		gy = clamp(clamp(gy, prevGy - 24, prevGy + 24), lo, hi)
		local item = nil
		if not first and math.random() < 0.42 and itemBudgetOK(x) then
			item = { kind = math.random() < 0.3 and "gem" or "chip", dy = rand(-0.22, 0.22) * gap, got = false, seed = rand(0, TAU) }
		end
		local p = { x = x, gy = gy, gap = gap, passed = false, hoff = (pipeIdx * 47) % 360, pop = 1, delay = 0, item = item, wob = rand(0, TAU) }
		pipeIdx += 1
		return p
	end
	local function ensurePipes()
		local last = pipes[#pipes]
		local x = last and last.x or BX + 46 - spacingFor(diff())
		local gy = last and last.gy or 45
		local guard = 0
		while x < WW + 4 and guard < 40 do
			guard += 1
			x += spacingFor(diff())
			local p = makePipe(x, gy, last == nil)
			table.insert(pipes, p)
			gy = p.gy
			last = p
		end
	end
	local function resetWorld(popIn)
		pipes, trail = {}, {}
		dist, pipeIdx = 0, 0
		bird.y, bird.vy, bird.rot, bird.flap, bird.alive, bird.vis = 45, 0, 0, 0, true, true
		ensurePipes()
		if popIn then
			for i, p in pipes do
				p.pop = 0
				p.delay = 0.15 + (i - 1) * 0.12
			end
		end
	end
	local function scroll(dt)
		dist += speed * dt
		for _, p in pipes do p.x -= speed * dt end
		for _, t in trail do t.x -= speed * dt end
		while #pipes > 0 and pipes[1].x + PW < -8 do table.remove(pipes, 1) end
		ensurePipes()
	end
	local function birdPhysics(dt)
		bird.vy = math.min(VMAX, bird.vy + G * dt)
		bird.y += bird.vy * dt
		if bird.y < BR then
			bird.y = BR
			if bird.vy < 0 then bird.vy = 0 end
		end
		local target = clamp(bird.vy / 55, -0.45, 1.2)
		bird.rot += (target - bird.rot) * math.min(1, dt * 9)
		trailAcc += dt
		if trailAcc > 1 / 50 then
			trailAcc = 0
			table.insert(trail, { x = BX, y = bird.y })
			if #trail > 12 then table.remove(trail, 1) end
		end
	end
	local function flap(demo)
		bird.vy = FLAP
		bird.flap = 1
		puff()
		if not demo then C.sfx("jump", { pitch = rand(0.95, 1.12), vol = 0.6 }) end
	end
	local function aura()
		addText("AURA +10 !", W / 2, H * 0.38, u * 11, "rgb", 1.4, true)
		addText(pick(Q_AURA), W / 2, H * 0.38 + u * 9, u * 6, COL.gold, 1.2)
		flash("rgb", 0.35)
		C.sfx("levelup")
		bumpShake(6)
		spark(BX * u, bird.y * u, 30, { hsl(C.hue(0), 100, 65), hsl(C.hue(120), 100, 65), hsl(C.hue(240), 100, 65), WHITE }, u * 30)
		table.insert(rings, { x = BX * u, y = bird.y * u, r = BR * u, dr = 90 * u, life = 0.6, max = 0.6, col = "rgb", w = 9 })
	end
	local function addScore(n)
		score += n
		scoreBump = 1
		if not recAnnounced and bestAtStart > 0 and score > bestAtStart then
			recAnnounced = true
			addText("NOUVEAU RECORD !", W / 2, H * 0.27, u * 6, "rgb", 1.4, true)
			C.sfx("achievement")
		end
		if score % 10 == 0 then aura() end
	end
	local function onPass(p)
		passed += 1
		C.sfx("pop")
		C.sfx("coin", { pitch = 1 + (score % 10) * 0.06 })
		addText("+1", BX * u, (bird.y - 9) * u, u * 6, WHITE, 0.7)
		table.insert(rings, { x = (p.x + PW / 2) * u, y = p.gy * u, r = 2 * u, dr = 40 * u, life = 0.35, max = 0.35, col = hsl(C.hue(p.hoff), 100, 65), w = 5 })
		addScore(1)
	end
	local function collect(p, ix, iy)
		p.item.got = true
		items += 1
		local gem = p.item.kind == "gem"
		C.sfx("coin", { pitch = 1.6 })
		spark(ix * u, iy * u, 16, gem and { COL.cyan, WHITE, COL.violet } or { COL.gold, WHITE, COL.chipD }, u * 22)
		addText(gem and "+1 GEMME" or "+1 PÉPITE", ix * u, (iy - 6) * u, u * 4.6, gem and COL.cyan or COL.gold, 0.8)
		addScore(1)
	end
	local function die(kind)
		if not bird.alive then return end
		bird.alive = false
		deathKind = kind
		mode = "dying"
		dieT, crumbled = 0, false
		freeze = 0.12
		bumpShake(16)
		flash(COL.hit, 0.4)
		C.sfx("hit")
	end
	local function crumble()
		crumbled = true
		bird.vis = false
		local x, y, r, p = BX * u, bird.y * u, BR * u, C.pal()
		local cols = { p.base, p.dark, p.light, p.chip, p.chip, p.chipHi }
		for _ = 1, 48 do
			if #parts >= MAX_PARTS then break end
			local a, sp, l = rand(0, TAU), rand(8, 38) * u, rand(0.7, 1.3)
			table.insert(parts, {
				x = x + math.cos(a) * r * 0.5, y = y + math.sin(a) * r * 0.5, vx = math.cos(a) * sp, vy = math.sin(a) * sp - 18 * u, g = 140 * u, drag = 0.99,
				life = l, max = l, size = rand(0.1, 0.24) * r, col = pick(cols), sq = math.random() < 0.6, rot = rand(0, TAU), vr = rand(-12, 12), add = false, grow = 0,
			})
		end
		if deathKind == "verre" then
			for _ = 1, 14 do
				if #parts >= MAX_PARTS then break end
				local a, sp, l = rand(-math.pi, 0), rand(10, 30) * u, rand(0.5, 0.9)
				table.insert(parts, { x = x + r * 0.8, y = y, vx = math.cos(a) * sp * 0.6 - 6 * u, vy = math.sin(a) * sp, g = 120 * u, drag = 0.99, life = l, max = l, size = rand(0.12, 0.22) * r, col = WHITE, sq = false, rot = 0, vr = 0, add = false, grow = 0 })
			end
		end
		table.insert(rings, { x = x, y = y, r = r * 0.6, dr = 50 * u, life = 0.45, max = 0.45, col = WHITE, w = 7 })
		addText(deathKind == "sol" and "CRASH !" or "SPLASH !", x + r, y - r * 2, u * 8, COL.red, 1.2, true)
		addText(pick(Q_DEATH), W / 2, H * 0.3, u * 6, WHITE, 1.3, true)
		C.sfx("lose")
		bumpShake(10)
	end
	local function updatePlay(dt)
		speed = speedFor(score)
		birdPhysics(dt)
		scroll(dt)
		if bird.y + HR >= GROUND then
			bird.y = GROUND - HR
			die("sol")
			return
		end
		for _, p in pipes do
			if not (p.x > BX + HR or p.x + PW < BX - HR) then
				local top, bot = p.gy - p.gap / 2, p.gy + p.gap / 2
				if circRect(BX, bird.y, HR, p.x, -60, PW, top + 60) or circRect(BX, bird.y, HR, p.x, bot, PW, GROUND - bot + 20) then
					die("verre")
					return
				end
			end
		end
		for _, p in pipes do
			if not p.passed and p.x + PW / 2 < BX then
				p.passed = true
				onPass(p)
			end
			local it = p.item
			if it and not it.got then
				local ix, iy = p.x + PW / 2, p.gy + it.dy + math.sin(realT * 3 + it.seed) * 1.2
				local dx, dy = ix - BX, iy - bird.y
				if math.sqrt(dx * dx + dy * dy) < HR + 3.4 then collect(p, ix, iy) end
			end
		end
	end
	local function updateDemo(dt)
		speed = 28
		local nxt = nil
		for _, p in pipes do
			if p.x + PW > BX - HR - 1 then
				nxt = p
				break
			end
		end
		local target = nxt and nxt.gy + 3 or 45
		if bird.y > target and bird.vy > -4 then flap(true) end
		birdPhysics(dt)
		bird.y = math.min(bird.y, GROUND - BR)
		scroll(dt)
		for _, p in pipes do
			if not p.passed and p.x + PW / 2 < BX then p.passed = true end
		end
	end

	----------------------------------------------------------------------- déroulé
	function startRun()
		if mode ~= "menu" and mode ~= "results" then return end
		if mode == "results" and res.stage < 2 then return end
		menu.show(false)
		res.hide()
		score, items, passed = 0, 0, 0
		bestAtStart = ctx.best()
		recAnnounced = false
		parts, texts, rings = {}, {}, {}
		freeze, shake, flashA = 0, 0, 0
		mode = "count"
		countT, countStep, goT, resumeRun = 0, -1, 0, false
		runT0 = os.clock()
		runId += 1
		ctx.startRound()
		resetWorld(true)
		C.sfx("pop")
	end
	local function pause()
		if mode == "play" then mode = "paused" end
	end
	local function resume()
		if mode ~= "paused" then return end
		mode = "count"
		countT, countStep, resumeRun = 0, -1, true
	end
	local function showResults()
		if mode == "results" then return end
		mode = "results"
		local sc = score
		local bestBefore = ctx.best()
		local sol = deathKind == "sol"
		res.show({
			head = sol and "CRASH !" or "SPLASH !", headIcon = sol and "ui:skull" or "item:milk", quip = quipFor(sc),
			score = sc, best = math.max(bestBefore, sc), isBest = sc > bestBefore and sc > 0, fmt = ctx.fmt,
			stats = {
				{ "item:milk", passed .. (passed > 1 and " verres passés" or " verre passé") },
				{ "ui:gem", items .. " bonus" },
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
		end, 4)
		resetWorld(false)
	end

	----------------------------------------------------------------------- pas de simulation
	local function step(dt)
		shake = math.max(0, shake - dt * 55)
		flashA = math.max(0, flashA - dt * 2.2)
		scoreBump = math.max(0, scoreBump - dt * 4)
		bird.flap = math.max(0, bird.flap - dt * 4)
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
			if not resumeRun then
				bird.y = 45 + math.sin(realT * 5) * 1.2
				bird.vy = 0
				bird.rot = math.sin(realT * 5) * 0.08
			end
			for _, p in pipes do
				if p.delay > 0 then p.delay -= dt else p.pop = math.min(1, p.pop + dt * 2.6) end
			end
			if st >= 3 then
				mode = "play"
				goT = GO_T
				resumeRun = false
				for _, p in pipes do
					p.pop = 1
					p.delay = 0
				end
				flap(true)
				bird.vy = FLAP * 0.85
				C.sfx("whoosh")
				C.sfx("perfect")
			end
		end
		if goT > 0 then goT -= dt end
		if mode == "play" and sdt > 0 then updatePlay(sdt) end
		if mode == "dying" then
			if freeze <= 0 and not crumbled then crumble() end
			dieT += dt
			if dieT > 1.35 then showResults() end
		end
		if (mode == "menu" or mode == "results") and sdt > 0 then updateDemo(sdt) end
		if sdt > 0 and mode ~= "count" then
			local n, i = #parts, 1
			while i <= n do
				local p = parts[i]
				p.life -= sdt
				if p.life <= 0 then
					parts[i] = parts[n]
					parts[n] = nil
					n -= 1
				else
					p.vx *= p.drag
					p.vy = p.vy * p.drag + p.g * sdt
					p.x += p.vx * sdt
					p.y += p.vy * sdt
					p.rot += p.vr * sdt
					i += 1
				end
			end
			for j = #texts, 1, -1 do
				local t = texts[j]
				t.life -= sdt
				t.y += t.vy * sdt
				t.vy *= 0.94
				if t.life <= 0 then table.remove(texts, j) end
			end
			for j = #rings, 1, -1 do
				local r = rings[j]
				r.life -= sdt
				r.r += r.dr * sdt * (r.life / r.max)
				if r.life <= 0 then table.remove(rings, j) end
			end
		end
	end

	----------------------------------------------------------------------- rendu
	local BOX = {}
	local function box(c, x, y, w, h, col, a, radius, stroke, sw, sa, rot, grad, grot)
		BOX.color, BOX.alpha, BOX.radius, BOX.stroke, BOX.sw, BOX.sa, BOX.rot, BOX.grad, BOX.grot = col, a, radius, stroke, sw, sa, rot, grad, grot
		return c:box(x, y, w, h, BOX)
	end
	local function drawBg()
		local hz = GROUND * u
		cvStars:begin()
		for i = 1, #stars, 4 do
			local s = stars[i]
			cvStars:rectTL(s.x, s.y, s.s + 0.6, s.s + 0.6, WHITE, 0.4 + 0.6 * math.abs(math.sin(realT * 2 + s.p)))
		end
		cvStars:finish()
		if far then
			local off = (dist * u * 0.12) % far.w
			for i, t in farTiles do t.Position = UDim2.fromOffset(-off + (i - 1) * far.w, hz - far.h) end
		end
		if near then
			local off = (dist * u * 0.32) % near.w
			for i, t in nearTiles do t.Position = UDim2.fromOffset(-off + (i - 1) * near.w, hz - near.h) end
			-- liserés néon des toits
			local c1, c2 = hsl(C.hue(200), 100, 60), hsl(C.hue(200), 100, 65)
			for k = 0, 1 do
				local x0 = -off + k * near.w
				for _, r in nearRoofs do
					local a = x0 + r.x
					if a <= W and a + r.w >= 0 then
						local y = hz - r.h
						cv:line(a, y, a + r.w, y, 6, c1, 0.25, true)
						cv:line(a, y, a + r.w, y, 2, c2, 0.9, true)
					end
				end
			end
		end
	end
	local function drawGround()
		local hz = GROUND * u
		local gh = H - hz
		box(cv, W / 2, hz + gh / 2, W, gh, WHITE, 1, nil, nil, nil, nil, 0, GROUND_SEQ, 90)
		local lc = hsl(C.hue(180), 100, 62)
		for i = 1, 4 do
			local y = hz + gh * (i / 4.4) ^ 1.5
			cv:rectTL(0, y - 0.75, W, 1.5, lc, 0.5)
		end
		local st = 6 * u
		local o = (dist * u) % st
		local xt = -st * 4 - o
		while xt < W + st * 4 do
			local xb = W / 2 + (xt - W / 2) * 2.4
			cv:line(xt, hz, xb, H, 1.5, lc, 0.5)
			xt += st
		end
		cv:rectTL(0, hz - 4, W, 8, hsl(C.hue(0), 100, 60), 0.3)
		cv:rectTL(0, hz - 1.5, W, 3, hsl(C.hue(0), 100, 68), 1)
	end
	-- verre de lait : base en (cx, baseY) ; dir = 1 debout, -1 suspendu (tête en bas)
	local function drawGlass(cx, baseY, L, dir, h, wob, pop)
		if L <= 2 or pop <= 0 then return end
		local w = PW * u
		local hw, bw = w / 2, w * 0.43
		local s = C.easeOutBack(pop)
		local function Y(yl) return baseY + dir * s * yl end
		local flip = dir > 0 and 0 or 180
		-- verre translucide
		local rimY, baseY2 = Y(-L), Y(0)
		cv:pimg("trapG", C.texTrap(bw / hw), cx, (rimY + baseY2) / 2, w, math.abs(baseY2 - rimY), flip, COL.glass, 0.14)
		-- lait
		local inset = w * 0.08
		local lvl = -L + math.min(L * 0.3, w * 0.5)
		local baseT = w * 0.16
		local function half(yl) return lerp(bw, hw, -yl / L) - inset end
		local xl, xr = -half(lvl), half(lvl)
		local topW, botW = xr - xl, 2 * (bw - inset)
		local y1, y2 = Y(lvl), Y(-baseT)
		if topW > 0 and math.abs(y2 - y1) > 0.5 then
			cv:pimg("trapM", C.texTrap(botW / topW), cx, (y1 + y2) / 2, topW, math.abs(y2 - y1), flip, WHITE, 1, MILK_SEQ, 0)
		end
		-- surface ondulée (bandes de lait + trait)
		local n = 8
		local amp = w * 0.06
		local lw = math.max(1.5, w * 0.03)
		local function wy(i) return lvl + math.sin(realT * 5 + wob + i * 1.3) * w * 0.035 + math.sin(realT * 3.1 + i * 0.7) * w * 0.02 end
		local px, py = xl, wy(0)
		for i = 1, n do
			local qx, qy = lerp(xl, xr, i / n), wy(i)
			local mx = (px + qx) / 2
			local ymid = (py + qy) / 2
			local seg = math.sqrt((qx - px) ^ 2 + ((qy - py) * s) ^ 2)
			local rot = math.deg(math.atan2((qy - py) * s * dir, qx - px))
			-- bande sous la vague (vers la base) pour combler jusqu'au corps du lait
			local bh = amp * 2 * s
			cv:rect(cx + mx, Y(ymid) + dir * bh / 2, seg + 1, bh, milkAt((mx + hw) / w), 1, rot)
			cv:line(cx + px, Y(py), cx + qx, Y(qy), lw, COL.wave, 0.9, true)
			px, py = qx, qy
		end
		-- reflets + fond épais
		local shineL = math.max(0, L - w * 0.6)
		if shineL > 0 then
			local ya, yb = Y(-L + w * 0.3), Y(-L + w * 0.3 + shineL)
			cv:rect(cx - hw * 0.72 + w * 0.04, (ya + yb) / 2, w * 0.08, math.abs(yb - ya), WHITE, 0.4)
			cv:rect(cx - hw * 0.5 + w * 0.0175, (ya + yb) / 2, w * 0.035, math.abs(yb - ya), WHITE, 0.2)
		end
		local b1, b2 = Y(-baseT), Y(0)
		cv:rect(cx, (b1 + b2) / 2, bw * 2, math.abs(b2 - b1), COL.base, 0.4)
		-- contour néon (halo + trait)
		local P = { { -bw, 0 }, { -hw, -L }, { hw, -L }, { bw, 0 } }
		local cGlow, cLine = hsl(h, 100, 60), hsl(h, 100, 66)
		for pass = 1, 2 do
			local lwp = pass == 1 and w * 0.2 or math.max(2, w * 0.055)
			for i = 1, 4 do
				local a, b = P[i], P[i % 4 + 1]
				cv:line(cx + a[1], Y(a[2]), cx + b[1], Y(b[2]), lwp, pass == 1 and cGlow or cLine, pass == 1 and 0.28 or 1, true)
			end
		end
		-- bord (rim)
		local rw, rh = w * 1.12, w * 0.14 * s
		box(cv, cx, Y(-L), rw, math.max(1, rh), WHITE, 0.85, 999, cLine, math.max(2, w * 0.05), 1)
	end
	local function drawPipes()
		local hz = GROUND * u
		for _, p in pipes do
			local cx = (p.x + PW / 2) * u
			if cx >= -PW * u and cx <= W + PW * u then
				local h = C.hue(p.hoff)
				local top, bot = (p.gy - p.gap / 2) * u, (p.gy + p.gap / 2) * u
				drawGlass(cx, 0, top, -1, h, p.wob, p.pop)
				drawGlass(cx, hz, hz - bot, 1, h + 40, p.wob + 2, p.pop)
			end
		end
	end
	local chipEI, sparkEI = nil, nil
	local function drawItems()
		chipEI = chipEI or texChip()
		sparkEI = sparkEI or texSparkle()
		for _, p in pipes do
			local it = p.item
			if it and not it.got and p.pop >= 1 then
				local x = (p.x + PW / 2) * u
				local y = (p.gy + it.dy + math.sin(realT * 3 + it.seed) * 1.2) * u
				local s = 2.6 * u
				local gem = it.kind == "gem"
				cv:glow(x, y, s * 2.4, gem and COL.gemGlow or COL.chipGlow, gem and 0.55 or 0.5)
				local rot = math.sin(realT * 2.5 + it.seed) * 0.25
				if gem then
					if not cv:img("ui:gem", x, y, s * 2.3, s * 2.3, math.deg(rot)) then
						cv:ptext("💎", x, y, s * 1.8, WHITE, 1, "center", C.FB)
					end
				elseif chipEI then
					-- centre de la texture = (0, -0.1 s) dans le repère de la pépite
					cv:pimg("chip", chipEI, x + math.sin(rot) * 0.1 * s, y - math.cos(rot) * 0.1 * s, s * 2.4, s * 2.4, math.deg(rot))
				else
					cv:circle(x, y, s * 0.8, hex("#5a2d12"), 1, C.INK, 2, 1)
				end
				local tw = math.max(0, math.sin(realT * 6 + it.seed * 3))
				if tw > 0.2 and sparkEI then
					local k = s * 0.5 * tw
					cv:pimg("spark", sparkEI, x + s * 0.8, y - s * 0.9, 2 * k, 2 * k, 0, WHITE, tw * 0.9)
				end
			end
		end
	end
	local wingEI = nil
	local function drawBird()
		if not bird.vis then return end
		local x, y, r = BX * u, bird.y * u, BR * u
		if #trail > 1 and mode ~= "count" then
			for i = 1, #trail - 1 do
				local k = (i - 1) / #trail
				cv:circle(trail[i].x * u, trail[i].y * u, r * (0.35 + 0.55 * k), hsl(C.hue((i - 1) * 25), 100, 60), 0.28 * k)
			end
		end
		-- aile (derrière le cookie), pivot à sa racine
		wingEI = wingEI or texWing()
		local wa = bird.flap > 0 and -1.2 * math.sin(bird.flap * math.pi) or math.sin(realT * (bird.vy < 0 and 24 or 7)) * 0.22
		local cr, sr = math.cos(bird.rot), math.sin(bird.rot)
		local rx, ry = x + (-0.55 * r) * cr - (-0.2 * r) * sr, y + (-0.55 * r) * sr + (-0.2 * r) * cr
		local a2 = bird.rot + wa + 0.3
		local ca, sa = math.cos(a2), math.sin(a2)
		local lx, ly = (WING.x0 + WING.w / 2) * r, (WING.y0 + WING.h / 2) * r
		if wingEI then
			cv:pimg("wing", wingEI, rx + lx * ca - ly * sa, ry + lx * sa + ly * ca, WING.w * r, WING.h * r, math.deg(a2))
		end
		cv:cookie(x, y, r, bird.rot, { acc = true })
	end
	local function drawParts()
		for _, p in parts do
			local a = clamp(p.life / p.max, 0, 1)
			if p.sq then
				cv:rect(p.x, p.y, p.size, p.size * 0.8, p.col, math.min(1, a * 1.8), math.deg(p.rot))
			elseif p.grow > 0 then
				cv:circle(p.x, p.y, p.size * (1 + (1 - a) * p.grow), p.col, a * 0.75)
			elseif p.add then
				cv:circle(p.x, p.y, p.size * (0.4 + a * 0.6), p.col, a)
			else
				cv:circle(p.x, p.y, p.size, p.col, math.min(1, a * 1.8))
			end
		end
	end
	local function drawRings()
		for _, r in rings do
			local a = r.life / r.max
			cv:ring(r.x, r.y, r.r, r.w * a + 1, r.col == "rgb" and hsl(C.hue(r.r), 100, 62) or r.col, a)
		end
	end
	local function drawTexts()
		for _, t in texts do
			local age = t.max - t.life
			local sc = age < 0.2 and C.easeOutBack(age / 0.2) or 1
			local a = t.life < t.max * 0.3 and t.life / (t.max * 0.3) or 1
			local rot = t.big and math.deg(math.sin(age * 16) * 0.04) or 0
			local col = t.col == "rgb" and hsl(C.hue(t.x * 0.3 + age * 240), 100, 66) or t.col
			cv:text(t.str, t.x, t.y, t.size, col, clamp(a, 0, 1), "center", rot, sc)
		end
	end
	local function drawHud()
		local size = clamp(u * 11, 44, 84) * (1 + scoreBump * 0.3)
		local y = math.max(40, u * 11)
		cvH:text(tostring(score), W / 2, y, size, WHITE)
		if bestAtStart > 0 then
			local b = math.max(bestAtStart, score)
			local str = "RECORD " .. b
			cvH:ptext(str, W / 2 + 1, y + size * 0.62 + 1, 13, BLACK, 0.5)
			cvH:ptext(str, W / 2, y + size * 0.62, 13, score > bestAtStart and hsl(C.hue(0), 100, 70) or COL.gold, 1)
		end
	end
	local function drawCountdown()
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
		local size = math.min(W, H) * (idx == 3 and 0.24 or 0.32)
		local cx, cy = W / 2, H * 0.42
		cvH:ring(cx, cy, size * (0.6 + k * 0.9), 6 * (1 - k) + 1, hsl(C.hue(idx * 90 + 60), 100, 65), a * 0.6)
		cvH:text(label, cx, cy, size, hsl(C.hue(idx * 90), 100, 65), a, "center", math.deg((1 - k) * 0.12 * (idx % 2 == 1 and 1 or -1)), sc)
		if mode == "count" then
			cvH:text(resumeRun and "ON REPREND !" or "TAPE / ESPACE POUR VOLER", cx, cy + size * 0.8, clamp(W * 0.045, 14, 22), WHITE)
		end
	end
	local function render()
		world.Position = shake > 0.3 and UDim2.fromOffset(rand(-shake, shake), rand(-shake, shake)) or UDim2.fromOffset(0, 0)
		cv:begin()
		drawBg()
		drawPipes()
		drawItems()
		drawGround()
		drawRings()
		drawBird()
		drawParts()
		drawTexts()
		cv:finish()
		shade.Visible = mode == "menu"
		cvH:begin()
		if mode == "count" or mode == "play" or mode == "paused" or mode == "dying" then drawHud() end
		if mode == "count" or goT > 0 then drawCountdown() end
		if mode == "paused" then
			cvH:rectTL(0, 0, W, H, COL.veil, 0.6)
			cvH:text("PAUSE", W / 2, H * 0.42, clamp(W * 0.16, 44, 90), hsl(C.hue(0), 100, 66))
			cvH:text("Tape pour reprendre", W / 2, H * 0.42 + 60, clamp(W * 0.05, 16, 24), WHITE)
		end
		if flashA > 0.01 then
			cvH:rectTL(0, 0, W, H, flashRgb and hsl(C.hue(0), 100, 60) or flashCol, math.min(0.6, flashA))
		end
		cvH:finish()
	end

	----------------------------------------------------------------------- boucle
	local pendingBg, pendingT = false, 0
	local function resize()
		local sz = root.AbsoluteSize
		local w, h = math.max(160, math.floor(sz.X + 0.5)), math.max(200, math.floor(sz.Y + 0.5))
		if w == W and h == H then return end
		local first = W == 0
		W, H = w, h
		u = H / 100
		WW = W / u
		BX = math.min(WW * 0.3, 40)
		menu.layout(W, H)
		res.layout(W, H)
		-- la ville est régénérée quand la taille ne bouge plus (redimensionnement de fenêtre)
		if first then buildBg() else pendingBg, pendingT = true, 0.3 end
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
		if pendingBg then
			pendingT -= dt
			if pendingT <= 0 then
				pendingBg = false
				buildBg()
			end
		end
		step(dt)
		render()
		if mode == "menu" then menu.update(realT) end
		if mode == "results" then res.update(dt, realT, FX) end
	end))

	----------------------------------------------------------------------- entrées
	local function tap()
		if mode == "paused" then
			resume()
		elseif mode == "play" then
			flap(false)
		end
	end
	bag.add(hit.InputBegan:Connect(function(input)
		local ut = input.UserInputType
		if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch then tap() end
	end))
	-- Espace / ↑ / W / Z : battre des ailes (capturées pour ne pas faire sauter / marcher l'avatar)
	CAS:BindActionAtPriority("CookieFlappyFlap", function(_, state, input)
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
		if mode == "play" then
			flap(false)
		elseif mode == "paused" then
			resume()
		elseif mode == "menu" and input.KeyCode == Enum.KeyCode.Space then
			startRun()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.Up, Enum.KeyCode.W, Enum.KeyCode.Z)
	bag.add(function() CAS:UnbindAction("CookieFlappyFlap") end)
	bag.add(UIS.InputBegan:Connect(function(input)
		if UIS:GetFocusedTextBox() then return end
		local k = input.KeyCode
		if k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter then
			if mode == "menu" or (mode == "results" and res.stage >= 3) then
				startRun()
			elseif mode == "paused" then
				resume()
			end
		elseif k == Enum.KeyCode.P and mode == "play" then
			pause()
		end
	end))
	bag.add(UIS.WindowFocusReleased:Connect(pause))

	resize()
	resetWorld(false)
	menu.show(true)

	return {
		destroy = function()
			if destroyed then return end
			destroyed = true
			bag.clean()
			for _, ei in cityEI do pcall(function() ei:Destroy() end) end
			table.clear(cityEI)
			pipes, parts, texts, rings, trail = {}, {}, {}, {}, {}
			cvStars:destroy()
			cv:destroy()
			cvH:destroy()
		end,
	}
end

return Flappy
