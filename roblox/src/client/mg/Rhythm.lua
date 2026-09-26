--!nonstrict
-- COOKIE OVERDRIVE — mini-jeu « Crunch Rythme » (port de mg-rhythm.js).
-- Jeu de rythme 4 colonnes sur une autoroute synthwave en perspective : la partition (156 notes,
-- 126 BPM, 26 mesures) est exactement celle du site. Roblox ne peut pas synthétiser la musique du
-- site : le jeu tourne sur l'horloge « silencieuse » du site (son mode sans audio) et le beat se
-- voit (lignes de mesure, pulsations, soleil, égaliseur).
-- Score : PERFECT 300 / GOOD 100 × multi comme le site ; le serveur reçoit score / 50 (6 / 2 × multi)
-- pour rester sous son plafond de 50 pts/s.
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")

local C = require(script.Parent:WaitForChild("Common"))

local hex, hsl, clamp, rand, TAU = C.hex, C.hsl, C.clamp, C.rand, C.TAU
local WHITE, BLACK, INK = C.col.white, C.col.black, C.INK

local BPM = 126
local SPB = 60 / BPM -- secondes par temps
local STEP = SPB / 4 -- une double-croche
local STEPS = 26 * 16
local COUNT_IN = 4 -- temps de 3-2-1-GO avant le morceau
local APPROACH = 1.15 -- s pour qu'une note tombe du haut à la ligne
local WIN_P, WIN_G, WIN_EARLY = 0.045, 0.09, 0.14
local INPUT_OFFSET = 0.012
local SCALE = 50 -- points affichés = points serveur × 50
local MAX_PARTS = 320
local LANE_COL = { hex("#1ff4ff"), hex("#ff2bd6"), hex("#b6ff3b"), hex("#ffc93c") }
local KEY_LABEL = { "D", "F", "J", "K" }
local KEYMAP = {
	[Enum.KeyCode.D] = 0, [Enum.KeyCode.F] = 1, [Enum.KeyCode.J] = 2, [Enum.KeyCode.K] = 3,
	[Enum.KeyCode.Left] = 0, [Enum.KeyCode.Down] = 1, [Enum.KeyCode.Up] = 2, [Enum.KeyCode.Right] = 3,
}
local COL = {
	red = hex("#ff4d6d"), gold = hex("#ffc93c"), lime = hex("#b6ff3b"), cyan = hex("#1ff4ff"), violet = hex("#8a5cff"),
	muted = hex("#b3a6dd"), pink = Color3.fromRGB(255, 43, 214), grid = Color3.fromRGB(31, 244, 255),
	div = Color3.fromRGB(190, 150, 255), recep = Color3.fromRGB(10, 4, 30), shade = Color3.fromRGB(8, 3, 24), veil = hex("#0b0620"),
}

-- partition du site (buildChart() de mg-rhythm.js) : { pas de double-croche, colonne 0-3, accord }
local CHART_DATA = {
	{0,0,0},{8,0,0},{16,1,0},{24,1,0},{32,0,0},{36,1,0},{40,0,0},{44,1,0},{48,1,0},{52,0,0},{56,1,0},{60,0,0},{64,0,0},
	{68,2,0},{72,0,0},{76,3,0},{80,1,0},{84,3,0},{88,1,0},{92,2,0},{96,0,0},{100,2,0},{104,0,0},{108,3,0},{112,1,0},
	{116,3,0},{120,1,0},{124,2,0},{126,1,0},{128,0,1},{128,3,1},{132,2,0},{134,3,0},{136,0,0},{140,3,0},{142,1,0},
	{144,2,0},{148,3,0},{150,2,0},{152,1,0},{156,2,0},{158,1,0},{160,0,1},{160,3,1},{164,2,0},{166,3,0},{168,0,0},
	{172,3,0},{174,1,0},{176,2,0},{180,3,0},{182,2,0},{184,1,0},{188,2,0},{190,1,0},{192,0,0},{194,1,0},{196,2,0},
	{198,3,0},{200,0,0},{202,1,0},{204,2,0},{206,3,0},{208,0,0},{210,1,0},{212,2,0},{214,3,0},{216,0,0},{217,1,0},
	{218,2,0},{219,3,0},{224,0,1},{224,3,1},{226,1,0},{228,2,0},{232,2,0},{234,1,0},{236,2,0},{240,3,1},{240,0,1},
	{244,2,0},{246,1,0},{248,0,0},{252,3,0},{253,2,0},{254,1,0},{255,0,0},{256,3,1},{256,2,1},{260,2,0},{262,3,0},
	{264,2,0},{268,3,0},{270,2,0},{272,3,1},{272,0,1},{278,1,0},{280,2,0},{284,3,0},{285,2,0},{286,1,0},{287,0,0},
	{288,2,1},{288,3,1},{290,1,0},{292,2,0},{294,3,0},{296,2,0},{298,1,0},{300,2,0},{302,1,0},{304,3,1},{304,0,1},
	{306,2,0},{308,3,0},{310,1,0},{312,0,0},{314,2,0},{316,3,0},{317,2,0},{318,1,0},{319,0,0},{320,3,1},{320,2,1},
	{322,1,0},{324,2,0},{326,3,0},{328,2,0},{330,3,0},{332,2,0},{334,3,0},{336,2,1},{336,0,1},{338,3,0},{340,1,0},
	{342,2,0},{344,3,0},{346,2,0},{348,3,0},{349,2,0},{350,1,0},{351,0,0},{352,2,0},{356,1,0},{360,0,0},{364,3,0},
	{368,0,0},{372,1,0},{376,0,0},{380,3,0},{384,0,0},{388,2,0},{392,0,0},{396,3,0},{400,0,1},{400,3,1},
}
local CHART = {}
for i, d in CHART_DATA do
	CHART[i] = { t = d[1] * STEP, lane = d[2], step = d[1], chord = d[3] == 1 }
end
local LAST_T = CHART[#CHART].t
local SONG_LEN = STEPS * STEP
local DEMO_A, DEMO_LEN = 14 * 16 * STEP, 8 * 16 * STEP -- l'écran d'accueil boucle le drop

local SKY_SEQ = C.seq({ { 0, hex("#0b0620") }, { 0.3, hex("#240a45") }, { 0.4, hex("#6a1668") }, { 0.405, hex("#14062b") }, { 1, hex("#0d0421") } })
-- dégradé du soleil dans le repère du disque (de hor - sr à hor + 0,2 sr sur le site)
local SUN_SEQ = C.seq({ { 0, hex("#ffe66b") }, { 0.33, hex("#ff7a59") }, { 0.6, hex("#ff2bd6") }, { 1, hex("#ff2bd6") } })

local function mult(c) return math.min(4, 1 + math.floor(c / 25) * 0.5) end
local function multStr(m) return (string.gsub(tostring(m), "%.", ",")) end
local function fmtInt(n)
	local s = tostring(math.floor(n + 0.5))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1 ")))
	if string.sub(out, 1, 1) == " " then out = string.sub(out, 2) end
	return out
end
local function easeBack(x, c1)
	c1 = c1 or 1.9
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function texEqStripe()
	return C.proc("eqStripe", 4, 12, function(buf, w, h)
		for y = 0, 8 do
			for x = 0, w - 1 do C.px(buf, w, x, y, 255, 255, 255, 255) end
		end
	end)
end

local Rhythm = {}

function Rhythm.mount(ctx)
	local root = ctx.root
	local bag = C.bag()
	local destroyed = false
	local coarse = C.coarse()

	----------------------------------------------------------------------- géométrie
	local W, H = 320, 480
	local G = { hw = 300, lw = 75, cx = 160, hitY = 400, persp = 0.6, nr = 24, speed = 300 }
	local function kAt(y) return G.persp + (1 - G.persp) * (y / G.hitY) end
	local function laneX(l, y) return G.cx + ((l + 0.5) * G.lw - G.hw / 2) * kAt(y) end
	local function laneFromXY(x, y) return clamp(math.floor(((x - G.cx) / kAt(clamp(y, 0, H))) / G.lw + 2), 0, 3) end
	local function sideRoom() return (W - G.hw * kAt(G.hitY)) / 2 >= 160 end

	----------------------------------------------------------------------- état
	local mode = "start" -- start | play | results
	local notes, first = {}, 1
	local score, combo, maxCombo, nP, nG, nM, hype, hypeMaxShown, rgbMode = 0, 0, 0, 0, 0, 0, 0, false, false
	local songT, perfT0 = -10, 0
	local lastCount = 99
	local held = { false, false, false, false }
	local press, flashL, missL = { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }
	local ptrLane = {}
	local judge = nil
	local comboPop, shake, flash, flashCol = 0, 0, 0, WHITE
	local parts, rings, banners = {}, {}, {}
	local demo0 = os.clock()
	local demoPrev = DEMO_A
	local res = nil
	local runId = 0

	local function colOf(l) return rgbMode and hsl(C.hue(l * 50), 100, 62) or LANE_COL[l + 1] end

	----------------------------------------------------------------------- calques fixes
	local sky = C.new("Frame", { Name = "Sky", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = root })
	local skyGrad = C.new("UIGradient", { Rotation = 90, Color = SKY_SEQ, Parent = sky })
	local sunClip = C.new("Frame", { Name = "Sun", BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2, Parent = root })
	local sunDisc = C.new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 2, Parent = sunClip }, { C.corner(UDim.new(1, 0)) })
	local sunGrad = C.new("UIGradient", { Rotation = 90, Color = SUN_SEQ, Parent = sunDisc })
	local sunBars = {}
	for i = 1, 6 do sunBars[i] = C.new("Frame", { BackgroundColor3 = hex("#2a0b4a"), BorderSizePixel = 0, ZIndex = 3, Parent = root }) end
	local cvBg = C.canvas(root, 4, "Floor")
	local cvSide = C.canvas(root, 5, "Side")
	local eqEI = texEqStripe()
	local eqBars = {}
	for i = 1, 9 do
		local b = C.new("ImageLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(8, 12),
			ZIndex = 6, Visible = false, Parent = root,
		})
		if not C.applyProc(b, eqEI) then
			b.Image = ""
			b.BackgroundTransparency = 0.4
		end
		local g = C.new("UIGradient", { Rotation = 90, Parent = b })
		eqBars[i] = { img = b, grad = g }
	end
	local world = C.new("Frame", { Name = "World", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = root })
	local highway = C.new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 180, ZIndex = 1, Parent = world }, {
		C.new("UIGradient", {
			Rotation = -90,
			Color = C.seq({ { 0, Color3.fromRGB(8, 3, 26) }, { 0.6, Color3.fromRGB(10, 4, 32) }, { 1, Color3.fromRGB(8, 3, 24) } }),
			Transparency = C.nseq({ { 0, 0.75 }, { 0.6, 0.22 }, { 1, 0.1 } }),
		}),
	})
	local beams = {}
	for l = 1, 4 do
		beams[l] = C.new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2, Visible = false, Parent = world }, {
			C.new("UIGradient", { Rotation = 90, Transparency = C.nseq({ { 0, 0 }, { 1, 1 } }) }),
		})
	end
	local cvW = C.canvas(world, 3, "Track")
	local cvH = C.canvas(root, 20, "Hud")
	local hit = C.new("TextButton", {
		Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ZIndex = 40, Selectable = false, Parent = root,
	})
	local layer = C.new("Frame", { Name = "Layer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = root })

	local function layoutStatic()
		local kT, kB = kAt(0), kAt(H)
		local half = G.hw / 2
		if C.applyProc(highway, C.texTrap(kT / kB)) then
			highway.Position = UDim2.fromOffset(G.cx, H / 2)
			highway.Size = UDim2.fromOffset(G.hw * kB, H)
		else
			highway.Visible = false
		end
		local yb, kb = G.hitY, kAt(G.hitY)
		local tex = C.texTrap(kT / kb)
		for l = 0, 3 do
			local b = beams[l + 1]
			local ct = G.cx + ((l + 0.5) * G.lw - half) * kT
			local cb = G.cx + ((l + 0.5) * G.lw - half) * kb
			local dx = cb - ct
			if C.applyProc(b, tex) then
				b.Position = UDim2.fromOffset((ct + cb) / 2, yb / 2)
				b.Size = UDim2.fromOffset(G.lw * kb, math.sqrt(dx * dx + yb * yb))
				-- le « haut » de la texture (côté large) pointe vers la ligne de frappe
				b.Rotation = math.deg(math.atan2(dx, -yb))
			else
				b.Image = ""
			end
		end
	end

	----------------------------------------------------------------------- effets
	local function burst(x, y, lane, perfect)
		local pal = C.pal()
		local cols = { pal.base, pal.light, pal.chip, pal.dark }
		for i = 1, perfect and 18 or 10 do
			if #parts >= MAX_PARTS then break end
			table.insert(parts, { x = x, y = y, vx = rand(-280, 280), vy = rand(-560, -120), g = 1300, life = rand(0.35, 0.75), age = 0, sz = rand(2.5, 6.5), col = cols[(i - 1) % 4 + 1], rot = rand(0, 6), vr = rand(-12, 12), sh = 0 })
		end
		for _ = 1, perfect and 10 or 5 do
			if #parts >= MAX_PARTS then break end
			local a, sp = rand(-math.pi, 0), rand(250, 620)
			table.insert(parts, { x = x, y = y, vx = math.cos(a) * sp, vy = math.sin(a) * sp, g = 300, life = rand(0.2, 0.45), age = 0, sz = rand(2, 3.5), col = colOf(lane), rot = 0, vr = 0, sh = 1 })
		end
		table.insert(rings, { x = x, y = y, age = 0, life = perfect and 0.4 or 0.3, r0 = G.nr * 0.9, col = colOf(lane), w = perfect and 6 or 4 })
	end
	local function confetti(n)
		for _ = 1, n do
			if #parts >= MAX_PARTS then break end
			table.insert(parts, { x = rand(0, W), y = rand(-60, -10), vx = rand(-60, 60), vy = rand(80, 260), g = 120, life = rand(2, 3.5), age = 0, sz = rand(4, 8), col = hsl(rand(0, 360), 100, 62), rot = rand(0, 6), vr = rand(-8, 8), sh = 2 })
		end
	end
	local function banner(text, col, big, icon)
		table.insert(banners, { text = text, col = col, age = 0, big = big == true, icon = icon })
		if #banners > 3 then table.remove(banners, 1) end
	end
	local function doFlash(a, col)
		flash = math.max(flash, a)
		flashCol = col or WHITE
	end

	----------------------------------------------------------------------- jugement
	local function onHit(n, perfect, early)
		n.j = perfect and 1 or 2
		n.jt = songT
		combo += 1
		if combo > maxCombo then maxCombo = combo end
		score += (perfect and 6 or 2) * mult(combo)
		if perfect then nP += 1 else nG += 1 end
		hype = math.min(1, hype + (perfect and 0.022 or 0.011))
		judge = { text = perfect and "PERFECT" or "GOOD", perfect = perfect, early = early, age = 0 }
		flashL[n.lane + 1] = 1
		comboPop = 1
		burst(laneX(n.lane, G.hitY), G.hitY, n.lane, perfect)
		C.sfx(perfect and "perfect" or "good", { vol = 0.35, pitch = 1 + n.lane * 0.06 })
		if combo % 25 == 0 then
			banner("COMBO ×" .. combo, COL.gold, true, "ui:fire")
			if mult(combo) > mult(combo - 1) then banner("MULTI ×" .. multStr(mult(combo)), COL.lime, false, "ui:bolt") end
			C.sfx("combo", { vol = 0.6, pitch = 1 + math.min(combo, 150) / 300 })
			shake = math.max(shake, 7)
			doFlash(0.18, WHITE)
		end
		if combo == 50 then
			rgbMode = true
			banner("MODE RGB ACTIVÉ", "rgb", true, "ui:sparkle")
			doFlash(0.35, WHITE)
			confetti(40)
		end
		if hype >= 1 and not hypeMaxShown then
			hypeMaxShown = true
			banner("HYPE MAX", "rgb", false, "ui:fire")
		end
	end
	local function onMiss(n)
		n.j = -1
		n.jt = songT
		nM += 1
		if combo >= 10 then banner("COMBO BREAK", COL.red) end
		combo = 0
		rgbMode = false
		hype = math.max(0, hype - 0.15)
		if hype < 0.9 then hypeMaxShown = false end
		judge = { text = "MISS", miss = true, age = 0 }
		missL[n.lane + 1] = 1
		shake = math.max(shake, 5)
		C.sfx("miss", { vol = 0.45 })
	end
	local function songNow() return os.clock() - perfT0 end
	local function pressLane(lane)
		held[lane + 1] = true
		press[lane + 1] = 1
		if mode ~= "play" then return end
		local t = songNow() - INPUT_OFFSET
		local best, bd = nil, 1e9
		for i = first, #notes do
			local n = notes[i]
			if n.t - t > WIN_EARLY then break end
			if n.j == 0 and n.lane == lane then
				local d = math.abs(n.t - t)
				if d < bd then
					bd = d
					best = n
				end
			end
		end
		if not best or bd > WIN_EARLY then return end -- tap dans le vide : pas de pénalité
		if bd <= WIN_P then
			onHit(best, true, best.t > t)
		elseif bd <= WIN_G then
			onHit(best, false, best.t > t)
		else
			onMiss(best)
		end
	end
	local function releaseLane(lane) held[lane + 1] = false end

	----------------------------------------------------------------------- panneaux (.cor-panel)
	local panel = nil
	local function clearLayer()
		if panel then
			panel.destroy()
			panel = nil
		end
	end
	local function makePanel()
		local P = { t0 = os.clock() }
		local holder = C.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(400, 300), ZIndex = 51, Parent = layer })
		local scale = C.new("UIScale", { Scale = 0.6, Parent = holder })
		local glow = C.new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ImageColor3 = COL.lime, ImageTransparency = 0.67, ZIndex = 51, Parent = holder })
		if not C.applyProc(glow, C.texGlow(0.6)) then glow.Visible = false end
		local shadowF = C.new("Frame", { BackgroundColor3 = INK, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 8), Size = UDim2.fromScale(1, 1), ZIndex = 52, Parent = holder }, { C.corner(24) })
		local ringF = C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 53, Parent = holder }, {
			C.corner(24), C.new("UIStroke", { Color = COL.lime, Thickness = 5, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		local body = C.new("Frame", {
			BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Active = true, ZIndex = 54, Parent = holder,
		}, {
			C.corner(24),
			C.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(44, 18, 98), Color3.fromRGB(16, 7, 40)), Transparency = C.nseq({ { 0, 0.1 }, { 1, 0.06 } }) }),
			C.new("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			C.new("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
			C.new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		P.body = body
		P.Z = 55
		local order = 0
		function P.next()
			order += 1
			return order
		end
		function P.row(h, pad)
			return C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h), LayoutOrder = P.next(), ZIndex = P.Z, Parent = body }, {
				C.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, pad or 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
		end
		function P.label(parent, text, size, color, font, props)
			local l = C.new("TextLabel", {
				BackgroundTransparency = 1, Size = UDim2.fromOffset(0, math.ceil(size * 1.3)), AutomaticSize = Enum.AutomaticSize.X, Text = text,
				FontFace = font or C.FB, TextSize = size, TextColor3 = color or WHITE, ZIndex = P.Z + 1, Parent = parent,
			})
			if props then for k, v in props do l[k] = v end end
			return l
		end
		function P.para(text, size, color, font, rich)
			return C.new("TextLabel", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text, RichText = rich == true,
				FontFace = font or C.FB, TextSize = size, TextColor3 = color or WHITE, TextWrapped = true, LayoutOrder = P.next(), ZIndex = P.Z + 1, Parent = body,
			})
		end
		function P.layout()
			holder.Size = UDim2.fromOffset(math.min(400, W - 24), holder.Size.Y.Offset)
		end
		-- suit la taille naturelle du panneau ; pop d'entrée (cor-in) + réduction si l'écran est trop bas
		function P.frame()
			local s = scale.Scale
			if s > 0.05 then
				local nat = body.AbsoluteSize.Y / s
				holder.Size = UDim2.fromOffset(math.min(400, W - 24), nat)
				glow.Size = UDim2.fromOffset(holder.Size.X.Offset + 90, nat + 90)
				local fit = nat > 0 and math.min(1, (H - 24) / (nat + 8)) or 1
				local k = clamp((os.clock() - P.t0) / 0.45, 0, 1)
				local e = easeBack(k, 2.2)
				scale.Scale = math.max(0.06, (0.6 + 0.4 * e) * fit)
				holder.Position = UDim2.new(0.5, 0, 0.5, (1 - e) * 30)
			end
			shadowF.Size = UDim2.fromScale(1, 1)
			ringF.Size = UDim2.fromScale(1, 1)
		end
		function P.destroy() holder:Destroy() end
		P.holder = holder
		P.layout()
		return P
	end
	-- touche <kbd> du site
	local function kbd(parent, text, order)
		local f = C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(38, 38), LayoutOrder = order, ZIndex = 56, Parent = parent })
		C.new("Frame", { BackgroundColor3 = INK, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 3), Size = UDim2.fromOffset(38, 35), ZIndex = 56, Parent = f }, { C.corner(9) })
		local k = C.new("TextLabel", {
			BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromOffset(38, 35), Text = text, FontFace = C.FD, TextSize = 18,
			TextColor3 = INK, ZIndex = 57, Parent = f,
		}, { C.corner(9), C.new("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		return k
	end

	local startRun -- défini plus bas
	local function showStart()
		mode = "start"
		clearLayer()
		local P = makePanel()
		panel = P
		local fs = clamp(W * 0.11, 34, 52)
		local t1 = C.waveTitle(nil, "CRUNCH", fs, { LayoutOrder = P.next(), ZIndex = 56 })
		t1.row.Parent = P.body
		local t2 = C.waveTitle(nil, "RYTHME", fs, { LayoutOrder = P.next(), ZIndex = 56 })
		t2.row.Parent = P.body
		t2.offset = 6
		P.para("Croque les cookies en rythme. Full combo ou rien.", 14, COL.muted, C.FS)
		local heroF = C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(118, 118), LayoutOrder = P.next(), ZIndex = 56, Parent = P.body })
		local heroCv = C.canvas(heroF, 56, "Hero")
		if not coarse then
			local keys = P.row(40, 7)
			for i, k in KEY_LABEL do kbd(keys, k, i) end
		end
		local how = coarse and "Tape les <b><font color=\"#b6ff3b\">4 colonnes</font></b>" or "Appuie (ou <b><font color=\"#b6ff3b\">← ↓ ↑ →</font></b>, ou clique)"
		how ..= " quand le cookie touche la ligne. <b><font color=\"#b6ff3b\">PERFECT</font></b> = ±45 ms. Enchaîne pour le <b><font color=\"#b6ff3b\">multi ×4</font></b> et le mode RGB."
		P.para(how, 14, hex("#ece4ff"), C.FS, true)
		local bestRow = P.row(24, 6)
		C.icon(bestRow, "ui:trophy", 18, { LayoutOrder = 1, ZIndex = 57 })
		local best = ctx.best()
		P.label(bestRow, "RECORD : " .. (best > 0 and fmtInt(best * SCALE) or "—"), 15, COL.gold, C.FM, { LayoutOrder = 2 })
		local goRow = P.row(62)
		local go = C.button(goRow, "JOUER", { style = "green", size = "big", icon = "ui:play", iconAfter = true, z = 58 }, function() startRun() end)
		P.para(C.SOUNDS.perfect and "Mets le son, la prod est une dinguerie" or "Suis le beat : les lignes tombent en rythme", 12, hex("#8f81c4"), C.FS)

		function P.update(T)
			t1.update(T, 5, 1.1, 28, 0.08, 64, -3)
			t2.update(T, 5, 1.1, 28, 0.08, 64, -3)
			go.scale.Scale = 1 + 0.035 * (1 - math.cos(((T % 1) / 1) * TAU))
			-- héros : cookie qui danse sur le beat + notes qui flottent (drawHero)
			local w, h = 118, 118
			local bp = (T / SPB) % 1
			local bounce = (1 - bp) ^ 2.5
			local R = math.min(w, h) * 0.34
			heroCv:begin()
			heroCv:glow(w / 2, h / 2, R * 1.45, hsl(C.hue(0), 100, 60), 0.55, 0.28)
			heroCv:circle(w / 2, h * 0.9, R * 0.14, BLACK, 0.35, nil, nil, nil, R * (0.8 - bounce * 0.15))
			heroCv:cookie(w / 2, h * 0.5 - bounce * R * 0.16, R, math.sin(T * 2.4) * 0.2, { acc = true, squash = bounce * 0.25 })
			for i = 0, 2 do
				local k = (T * 0.6 + i / 3) % 1
				local s = R * 0.42
				heroCv:icon("ui:music", w / 2 + (i - 1) * R * 1.15 + math.sin(T * 3 + i) * 5 + s * 0.2, h * 0.62 - k * h * 0.5 - s * 0.45, s * 1.25, math.deg(math.sin(T * 4 + i) * 0.25), math.sin(k * math.pi), hsl(C.hue(i * 120), 100, 80))
			end
			heroCv:finish()
		end
	end

	local RANK_COL = { S = COL.gold, A = COL.lime, B = COL.cyan, C = COL.violet, D = COL.red }
	local RANK_MSG = {
		S = "T'es un robot ou quoi ?? Aura infinie.", A = "Propre. Grosse aura.", B = "Pas mal du tout, continue !",
		C = "Mid… mais on y croit.", D = "Skill issue (tkt, rejoue).",
	}
	local function showResults()
		clearLayer()
		local P = makePanel()
		panel = P
		local rank = res.rank
		local rc = RANK_COL[rank]
		-- rang (cor-rank : arrive à 1,2 s en tournant)
		local rs = math.min(100, clamp(W * 0.26, 76, 112))
		local rankF = C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, rs * 0.95), LayoutOrder = P.next(), ZIndex = 56, Parent = P.body })
		local rankGlow = C.new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(rs * 1.6, rs * 1.6), ImageColor3 = rc, ImageTransparency = 0.5, ZIndex = 56, Parent = rankF })
		if not C.applyProc(rankGlow, C.texGlow(0.2)) then rankGlow.Visible = false end
		local function rankLab(z, col, dy)
			return C.new("TextLabel", {
				BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, dy), Size = UDim2.fromOffset(rs * 1.4, rs * 1.1),
				Text = rank, FontFace = C.FD, TextSize = rs, TextColor3 = col, ZIndex = z, Parent = rankF,
			}, { C.tstroke(INK, rs * 0.07), C.new("UIScale", { Scale = 0 }) })
		end
		local rankSh = rankLab(57, INK, rs * 0.06)
		local rankL = rankLab(58, rc, 0)
		local msg = P.para(RANK_MSG[rank], 15, hex("#e9e0ff"), C.FB)
		msg.TextTransparency = 1
		-- NOUVEAU RECORD (affiché quand le serveur le confirme)
		local nbRow = C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = P.next(), Visible = false, ZIndex = 56, Parent = P.body })
		local nb = C.waveTitle(nbRow, "NOUVEAU RECORD !", 26, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 57 })
		nb.row.Parent = nbRow
		local nbScale = C.new("UIScale", { Parent = nb.row })
		-- score
		local sc = C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = P.next(), ZIndex = 56, Parent = P.body })
		C.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), Text = "SCORE", FontFace = C.FM, TextSize = 11, TextColor3 = COL.muted, ZIndex = 57, Parent = sc })
		local scoreL = C.new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 44), Text = "0", FontFace = C.FD, TextSize = 40,
			TextColor3 = WHITE, ZIndex = 57, Parent = sc,
		}, { C.tstroke(INK, 3) })
		if nM == 0 then
			local fc = P.row(30, 6)
			C.icon(fc, "ui:fire", 24, { LayoutOrder = 1, ZIndex = 57 })
			local fcl = P.label(fc, "FULL COMBO", 22, COL.gold, C.FD, { LayoutOrder = 2 })
			C.tstroke(INK, 2).Parent = fcl
			C.icon(fc, "ui:fire", 24, { LayoutOrder = 3, ZIndex = 57 })
		end
		-- grille 3×2
		local grid = C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 2 * 50 + 6), LayoutOrder = P.next(), ZIndex = 56, Parent = P.body }, {
			C.new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -4, 0, 50), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local total = #notes
		local cells = {
			{ "PRÉCISION", string.format("%.1f", res.acc * 100):gsub("%.", ",") .. " %", WHITE },
			{ "COMBO MAX", tostring(maxCombo), WHITE },
			{ "NOTES", (nP + nG) .. "/" .. total, WHITE },
			{ "PERFECT", tostring(nP), COL.lime },
			{ "GOOD", tostring(nG), COL.cyan },
			{ "MISS", tostring(nM), COL.red },
		}
		for i, c in cells do
			local cell = C.new("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.7, LayoutOrder = i, ZIndex = 56, Parent = grid }, {
				C.corner(12), C.new("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.93, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			})
			C.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 13), Text = c[1], FontFace = C.FM, TextSize = 10, TextColor3 = COL.muted, ZIndex = 57, Parent = cell })
			C.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 19), Size = UDim2.new(1, 0, 0, 26), Text = c[2], FontFace = C.FD, TextSize = 20, TextColor3 = c[3], TextScaled = false, ZIndex = 57, Parent = cell })
		end
		-- récompenses (pastilles .cor-chip), remplies à la réponse du serveur
		-- (la rangée garde sa place ; seul son contenu « pop » : pas de ré-agencement du panneau)
		local rewRow = P.row(44, 8)
		local rew = C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Visible = false, ZIndex = 56, Parent = rewRow }, {
			C.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local rewScale = C.new("UIScale", { Scale = 0, Parent = rew })
		local rewT = nil
		local function chip(kind, text, key, order)
			local col = kind == "gem" and COL.cyan or (kind == "none" and hex("#7d6fae") or COL.gold)
			local tc = kind == "gem" and hex("#d8fdff") or (kind == "none" and COL.muted or hex("#fff1c2"))
			local f = C.new("Frame", {
				BackgroundColor3 = kind == "none" and WHITE or col, BackgroundTransparency = kind == "none" and 0.95 or (kind == "gem" and 0.87 or 0.85),
				Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order, ZIndex = 56, Parent = rew,
			}, {
				C.corner(UDim.new(1, 0)), C.new("UIStroke", { Color = col, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				C.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
				C.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			P.label(f, text, kind == "none" and 16 or 21, tc, C.FD, { LayoutOrder = 1, ZIndex = 57 })
			if key then C.icon(f, key, 22, { LayoutOrder = 2, ZIndex = 57 }) end
			if kind ~= "none" then
				local g = C.new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 50, 1, 40), ImageColor3 = col, ImageTransparency = 0.72, ZIndex = 55, Parent = f })
				if not C.applyProc(g, C.texGlow(0.5)) then g:Destroy() end
			end
		end
		function P.rewards(r, hint)
			if r then
				local n = 0
				if (r.cookies or 0) > 0 then
					n += 1
					chip("gold", "+" .. ctx.fmt(r.cookies), "ui:cookie", n)
				end
				if (r.gems or 0) > 0 then
					n += 1
					chip("gem", "+" .. ctx.fmt(r.gems), "ui:gem", n)
				end
				if n == 0 then chip("none", "+0 (ratio)", "ui:cookie", 1) end
				if r.isBest and res.score > 0 then
					nbRow.Visible = true
					C.sfx("achievement", { vol = 0.8 })
				end
			else
				chip("none", hint or "Manche non validée", "ui:warning", 1)
			end
			rew.Visible = true
			rewT = os.clock()
		end
		local btns = P.row(52, 10)
		local again = C.button(btns, "REJOUER", { style = "green", z = 58 }, function() startRun() end)
		again.btn.LayoutOrder = 1
		local quit = C.button(btns, "QUITTER", { style = "dark", z = 58 }, function() ctx.close() end)
		quit.btn.LayoutOrder = 2

		if rank == "S" or rank == "A" then
			confetti(rank == "S" and 140 or 70)
			doFlash(0.3, WHITE)
		end
		C.sfx((rank == "S" or rank == "A" or rank == "B") and "win" or "lose", { vol = 0.8 })

		local shown = -1
		function P.update(T, dt)
			local e = T - res.t
			-- défilement du score
			local k = clamp((e - 0.2) / 1.1, 0, 1)
			local v = math.floor(res.score * SCALE * (1 - (1 - k) ^ 3) + 0.5)
			if v ~= shown then
				shown = v
				scoreL.Text = fmtInt(v)
				if k < 1 and T - res.lastTick > 0.07 then
					res.lastTick = T
					C.sfx("tick", { vol = 0.35, pitch = 0.8 + k })
				end
			end
			if res.rank == "S" and math.random() < dt * 6 then confetti(4) end
			-- rang : scale 3 → 1, rotation -20° → 0 (0,6 s après 1,2 s)
			local rk = clamp((e - 1.2) / 0.6, 0, 1)
			local rsc = rk <= 0 and 0 or (3 + (1 - 3) * easeBack(rk, 2.6))
			for _, l in { rankL, rankSh } do
				l:FindFirstChildOfClass("UIScale").Scale = math.max(0, rsc)
				l.Rotation = -20 * (1 - rk)
				l.TextTransparency = 1 - clamp(rk * 2, 0, 1)
			end
			rankGlow.Visible = rk > 0
			-- message à 1,5 s
			msg.TextTransparency = 1 - clamp((e - 1.5) / 0.4, 0, 1)
			-- NOUVEAU RECORD (cor-nb : 1 ↔ 1,1 et ±2°)
			if nbRow.Visible then
				nb.update(T, 0, 1, 24, 0, 64)
				local a = (math.sin(T * math.pi / 0.7) + 1) / 2
				nbScale.Scale = 1 + 0.1 * a
				nb.row.Rotation = -2 + 4 * a
			end
			if rewT then rewScale.Scale = easeBack(clamp((os.clock() - rewT) / 0.45, 0, 1), 2.4) end
		end
	end

	----------------------------------------------------------------------- déroulé
	function startRun()
		if destroyed then return end
		if mode == "play" then return end
		clearLayer()
		C.sfx("click", { vol = 0.6 })
		notes = {}
		for i, n in CHART do notes[i] = { t = n.t, lane = n.lane, step = n.step, chord = n.chord, j = 0, jt = 0 } end
		first = 1
		score, combo, maxCombo, nP, nG, nM, hype, hypeMaxShown, rgbMode = 0, 0, 0, 0, 0, 0, 0, false, false
		judge = nil
		table.clear(banners)
		lastCount = 99
		res = nil
		local lead = 0.35 + COUNT_IN * SPB
		perfT0 = os.clock() + lead
		songT = -lead
		mode = "play"
		runId += 1
		ctx.startRound()
	end
	local function finish()
		mode = "results"
		local total = #notes
		local acc = total > 0 and (nP + nG * 0.5) / total or 0
		local rank = acc >= 0.95 and "S" or (acc >= 0.85 and "A" or (acc >= 0.7 and "B" or (acc >= 0.5 and "C" or "D")))
		res = { acc = acc, rank = rank, score = score, t = os.clock(), lastTick = 0 }
		showResults()
		local myRun = runId
		ctx.endRound(score, function(r, hint)
			if destroyed or myRun ~= runId or mode ~= "results" or not panel or not panel.rewards then return end
			panel.rewards(r, hint)
		end)
	end
	local function abortRun(msg)
		if mode ~= "play" then return end
		ctx.toast(msg, "#ff4d6d")
		for i = 1, 4 do held[i] = false end
		table.clear(ptrLane)
		showStart()
	end

	----------------------------------------------------------------------- mise à jour
	local function update(dt, T)
		if mode == "play" then
			songT = songNow()
			if songT < 0 then
				local b = math.floor(songT / SPB)
				if b ~= lastCount and b >= -COUNT_IN then
					lastCount = b
					C.sfx("tick", { pitch = b == -1 and 1.5 or 1 })
					if b == -1 then doFlash(0.25, WHITE) end
				end
			end
			while first <= #notes and notes[first].j ~= 0 do first += 1 end
			for i = first, #notes do
				local n = notes[i]
				if n.t > songT then break end
				if n.j == 0 and songT - n.t > WIN_G then onMiss(n) end
			end
			if first > #notes and songT > LAST_T + 1.1 then finish() end
			hype = math.max(0, hype - dt * 0.02)
		else
			-- démo : le drop tourne en boucle, joué par un bot
			local dT = DEMO_A + ((T - demo0) % DEMO_LEN)
			local prev = demoPrev
			demoPrev = dT
			for _, n in CHART do
				if n.t >= DEMO_A and n.t < DEMO_A + DEMO_LEN then
					local crossed
					if dT >= prev then crossed = n.t > prev and n.t <= dT else crossed = n.t > prev or n.t <= dT end
					if crossed then
						flashL[n.lane + 1] = 1
						press[n.lane + 1] = 1
						if mode == "start" then burst(laneX(n.lane, G.hitY), G.hitY, n.lane, true) end
					end
				end
			end
			songT = dT
		end
		for i = 1, 4 do
			press[i] = held[i] and 1 or math.max(0, press[i] - dt * 7)
			flashL[i] = math.max(0, flashL[i] - dt * 4)
			missL[i] = math.max(0, missL[i] - dt * 3)
		end
		comboPop = math.max(0, comboPop - dt * 5)
		shake = math.max(0, shake - dt * 30)
		flash = math.max(0, flash - dt * 2.5)
		if judge then
			judge.age += dt
			if judge.age > 0.6 then judge = nil end
		end
		for i = #banners, 1, -1 do
			banners[i].age += dt
			if banners[i].age > 1.3 then table.remove(banners, i) end
		end
		local n, i = #parts, 1
		while i <= n do
			local p = parts[i]
			p.age += dt
			if p.age >= p.life then
				parts[i] = parts[n]
				parts[n] = nil
				n -= 1
			else
				p.vy += p.g * dt
				p.x += p.vx * dt
				p.y += p.vy * dt
				p.rot += p.vr * dt
				i += 1
			end
		end
		for j = #rings, 1, -1 do
			rings[j].age += dt
			if rings[j].age >= rings[j].life then table.remove(rings, j) end
		end
	end

	----------------------------------------------------------------------- rendu
	local BOX = {}
	local function box(cv, x, y, w, h, o)
		table.clear(BOX)
		for k, v in o do BOX[k] = v end
		return cv:box(x, y, w, h, BOX)
	end
	local function gradLine(cv, x1, y1, x2, y2, w, seq, alpha)
		local dx, dy = x2 - x1, y2 - y1
		return box(cv, (x1 + x2) / 2, (y1 + y2) / 2, math.sqrt(dx * dx + dy * dy) + w, w, { color = WHITE, alpha = alpha, grad = seq, grot = 0, rot = math.deg(math.atan2(dy, dx)), radius = 999 })
	end
	local function clipLine(cv, x1, y1, x2, y2, w, col, a, y0)
		local ax, ay, bx, by = C.clipSeg(x1, y1, x2, y2, -w, y0 or -w, W + w, H + w)
		if ax then cv:line(ax, ay, bx, by, w, col, a) end
	end
	local lastSkyRgb = false
	local function drawBg(T, vt, pulse)
		local h = C.hue(0)
		local hor = H * 0.4
		if rgbMode then
			skyGrad.Color = C.seq({ { 0, hsl(h, 85, 10) }, { 0.4, hsl(h + 50, 95, 32) }, { 0.42, hsl(h + 180, 90, 12) }, { 1, hsl(h + 120, 90, 16) } })
			sunGrad.Color = C.seq({ { 0, hsl(h + 60, 100, 65) }, { 0.6, hsl(h + 300, 100, 55) }, { 1, hsl(h + 300, 100, 55) } })
			lastSkyRgb = true
		elseif lastSkyRgb then
			skyGrad.Color = SKY_SEQ
			sunGrad.Color = SUN_SEQ
			lastSkyRgb = false
		end
		-- soleil (demi-disque coupé à l'horizon) + bandes
		local sr = math.min(W, H) * 0.2 * (1 + pulse * 0.05)
		sunClip.Position = UDim2.fromOffset(W / 2 - sr, hor - sr)
		sunClip.Size = UDim2.fromOffset(2 * sr, sr)
		sunDisc.Size = UDim2.fromOffset(2 * sr, 2 * sr)
		local barCol = rgbMode and hsl(h, 85, 12) or hex("#2a0b4a")
		for i = 0, 5 do
			local yy = hor - sr * 0.08 - i * sr * 0.14
			local hh = math.min(math.max(1.5, sr * 0.035 * (6 - i) * 0.5), hor - yy)
			local b = sunBars[i + 1]
			b.Position = UDim2.fromOffset(W / 2 - sr, yy)
			b.Size = UDim2.fromOffset(2 * sr, hh)
			b.BackgroundColor3 = barCol
		end
		-- sol quadrillé qui défile sur le beat
		local ph = (vt / SPB) % 1
		for k = 0, 11 do
			local z = (k + ph) / 12
			local y = hor + (H - hor) * z * z
			if rgbMode then
				cvBg:rectTL(0, y - 0.75, W, 1.5, hsl(h + k * 25, 100, 60), 0.25 + z * 0.5)
			else
				cvBg:rectTL(0, y - 0.75, W, 1.5, COL.pink, 0.18 + z * 0.55)
			end
		end
		for k = -10, 10 do
			local col, a = COL.grid, 0.28
			if rgbMode then col, a = hsl(h + k * 18, 100, 60), 0.45 end
			clipLine(cvBg, W / 2 + k * W * 0.03, hor, W / 2 + k * W * 0.24, H, 1.5, col, a, hor)
		end
		-- lasers de hype
		if hype > 0.6 and mode == "play" then
			local a = (hype - 0.6) / 0.4
			for i = 0, 3 do
				local ang = math.sin(T * 1.3 + i * 1.7) * 0.6 - math.pi / 2
				local x0 = i < 2 and 0 or W
				local x1 = x0 + math.cos(ang + (i < 2 and 0.5 or -0.5)) * H * 1.5
				local y1 = H + math.sin(ang) * H * 1.5
				clipLine(cvBg, x0, H, x1, y1, 10, hsl(C.hue(i * 90), 100, 60), 0.18 * a)
			end
		end
		if pulse > 0 and mode == "play" and songT >= 0 then cvBg:rectTL(0, 0, W, H, WHITE, pulse * (rgbMode and 0.07 or 0.035)) end
	end
	local function drawSides(T, vt, beatPh)
		local room = sideRoom()
		for _, b in eqBars do b.img.Visible = room end
		if not room then return end
		local side = (W - G.hw * kAt(G.hitY)) / 2
		local pulse = (1 - beatPh) ^ 3
		local beatN = math.floor(vt / SPB)
		local hype2 = mode == "play" and math.min(1, combo / 60) or 0.5
		-- gauche : ton cookie qui danse
		local R = clamp(side * 0.27, 46, 118)
		local x, y = side * 0.5, H * 0.56
		local lean = (beatN % 2 == 1 and 1 or -1) * (0.12 + hype2 * 0.25) * (1 - beatPh * 0.6)
		cvSide:glow(x, y, R * 2.2, hsl(C.hue(0), 100, 60), 0.35 + pulse * 0.2, 0.18)
		cvSide:circle(x, y + R * 1.12, R * 0.16, BLACK, 0.4, nil, nil, nil, R * (0.85 - pulse * 0.15))
		cvSide:cookie(x, y - pulse * R * (0.18 + hype2 * 0.2), R, lean, { acc = true, squash = pulse * 0.3 })
		for i = 0, 1 do
			local k = (T * 0.7 + i * 0.5) % 1
			local s = R * 0.34
			local nx, ny = x + (i == 1 and 1 or -1) * R * 1.05, y - R * 0.4 - k * R * 1.2
			cvSide:icon("ui:music", nx + s * 0.2, ny - s * 0.45, s * 1.25, math.deg(math.sin(T * 3 + i) * 0.3), math.sin(k * math.pi) * 0.9, hsl(C.hue(i * 150), 100, 80))
		end
		-- droite : égaliseur RGB
		local n = 9
		local ex0, ew = W - side * 0.88, side * 0.76
		local bw = ew / n
		local baseY, maxH = H * 0.74, H * 0.42
		for i = 0, n - 1 do
			local wob = 0.5 + 0.5 * math.sin(i * 1.9 + vt * 7.3) * math.cos(i * 0.7 - vt * 3.1)
			local hgt = maxH * (0.12 + (0.35 + hype2 * 0.4) * wob * (0.45 + pulse * 0.55)) * (mode == "play" and 1 or 0.6)
			local segs = math.max(1, math.floor(hgt / 12))
			local b = eqBars[i + 1]
			b.img.Position = UDim2.fromOffset(ex0 + i * bw + 2, baseY + 2)
			b.img.Size = UDim2.fromOffset(bw - 4, segs * 12)
			b.img.TileSize = UDim2.fromOffset(math.max(1, bw - 4), 12)
			local h0 = C.hue(i * 22)
			b.grad.Color = ColorSequence.new(hsl(h0 + (segs - 1) * 8, 100, 60), hsl(h0, 100, 60))
			b.grad.Transparency = NumberSequence.new(0.05, 0.65)
		end
	end
	local function drawHighway(vt)
		local kT, kB = kAt(0), kAt(H)
		local half = G.hw / 2
		for l = 0, 3 do
			local b = beams[l + 1]
			local a = math.max(flashL[l + 1] * 0.55, press[l + 1] * 0.3, missL[l + 1] * 0.5)
			if a <= 0.01 then
				b.Visible = false
			else
				b.Visible = true
				b.ImageColor3 = missL[l + 1] > flashL[l + 1] and COL.red or colOf(l)
				b.ImageTransparency = 1 - a
			end
		end
		-- lignes de temps
		local b0 = math.floor(vt / SPB)
		local b1 = b0 + math.ceil(APPROACH / SPB) + 2
		for b = b0, b1 do
			local y = G.hitY - (b * SPB - vt) * G.speed
			if y >= 0 and y <= G.hitY then
				local k = kAt(y)
				local strong = b % 4 == 0
				cvW:rect(G.cx, y, G.hw * k, strong and 2 or 1, WHITE, strong and 0.22 or 0.07)
			end
		end
		-- séparateurs
		for i = 1, 3 do
			cvW:line(G.cx + (i * G.lw - half) * kT, 0, G.cx + (i * G.lw - half) * kB, H, 1.5, COL.div, 0.18)
		end
		-- rails RGB
		for side = -1, 1, 2 do
			local x0, x1 = G.cx + side * half * kT, G.cx + side * half * kB
			local ks = {}
			for i = 0, 4 do ks[i + 1] = ColorSequenceKeypoint.new(i / 4, hsl(C.hue(i * 60 + (side > 0 and 180 or 0)), 100, 62)) end
			local seq = ColorSequence.new(ks)
			gradLine(cvW, x0, 0, x1, H, 9, seq, 0.3)
			gradLine(cvW, x0, 0, x1, H, 3, seq, 1)
		end
		-- ligne de frappe arc-en-ciel
		local kh = kAt(G.hitY)
		local seq = C.rainbowSeq(C.hue(0))
		box(cvW, G.cx, G.hitY, G.hw * kh, 12, { color = WHITE, alpha = 0.35, grad = seq, radius = 6 })
		box(cvW, G.cx, G.hitY, G.hw * kh, 4, { color = WHITE, alpha = 1, grad = seq, radius = 2 })
	end
	local function drawNoteSet(list, vt, from, offset, demo)
		local function yOf(n) return G.hitY - (n.t + offset - vt) * G.speed end
		local function inDemo(n) return n.t + offset > vt and n.t >= DEMO_A and n.t < DEMO_A + DEMO_LEN end
		-- barres d'accord
		for i = from, #list - 1 do
			local a, b = list[i], list[i + 1]
			local y = yOf(a)
			if y < -G.nr * 2 then break end
			if a.chord and b.step == a.step and y <= G.hitY + G.nr then
				local ok
				if demo then ok = inDemo(a) else ok = a.j == 0 and b.j == 0 end
				if ok then
					local k = kAt(y)
					cvW:line(laneX(a.lane, y), y, laneX(b.lane, y), y, 7 * k, WHITE, 0.7, true)
					cvW:line(laneX(a.lane, y), y, laneX(b.lane, y), y, 3 * k, hsl(C.hue(0), 100, 65), 1, true)
				end
			end
		end
		for i = from, #list do
			local n = list[i]
			local y = yOf(n)
			if y < -G.nr * 2 then break end
			local alpha = 1
			local skip = false
			if demo then
				skip = not inDemo(n)
			elseif n.j > 0 then
				skip = true
			elseif n.j < 0 then
				alpha = 1 - (vt - n.jt) / 0.35
				skip = alpha <= 0
			end
			if not skip and y <= H + G.nr * 2 then
				local k = kAt(y)
				local x, r = laneX(n.lane, y), G.nr * kAt(y)
				local col = n.j < 0 and COL.red or colOf(n.lane)
				cvW:glow(x, y, r * 1.7, col, alpha * 0.55, 0.3)
				cvW:ring(x, y, r * 1.02, 5 * k, INK, alpha)
				cvW:cookie(x, y, r, vt * 2.2 + n.lane * 1.3 + n.step, { alpha = alpha })
				cvW:ring(x, y, r * 1.1, 2.5 * k, col, alpha)
			end
		end
	end
	local function drawReceptors(beatPh)
		for l = 0, 3 do
			local x, y = laneX(l, G.hitY), G.hitY
			local k = kAt(y)
			local col = colOf(l)
			local p = press[l + 1]
			local r = G.nr * k * (1.08 - p * 0.1 + (1 - beatPh) ^ 4 * 0.06)
			if flashL[l + 1] > 0 or p > 0 then
				local a = math.max(flashL[l + 1], p * 0.6)
				cvW:glow(x, y, r * 2.4, col, a * 0.7, 0.12)
			end
			if p > 0.05 then
				cvW:circle(x, y, r, col, 0.35 + p * 0.3)
			else
				cvW:circle(x, y, r, COL.recep, 0.75)
			end
			cvW:ring(x, y, r, 7, INK, 1)
			cvW:ring(x, y, r, 4, col, 1)
			cvW:ring(x, y, r * 0.62, 1.5, col, 0.6)
			if not coarse then cvW:text(KEY_LABEL[l + 1], x, y + 1, math.floor(r * 0.62 + 0.5), WHITE, 1, "center", 0, 1, { lw = 0.22 }) end
		end
	end
	local function drawParticles()
		for _, p in parts do
			local a = 1 - p.age / p.life
			local al = math.min(1, a * 1.6)
			if p.sh == 1 then
				cvW:line(p.x, p.y, p.x - p.vx * 0.03, p.y - p.vy * 0.03, p.sz, p.col, al, true)
			elseif p.sh == 2 then
				cvW:rect(p.x, p.y, p.sz, p.sz * 0.6 * math.abs(math.cos(p.rot * 2)) + 1, p.col, al, math.deg(p.rot))
			else
				cvW:rect(p.x, p.y, p.sz, p.sz, p.col, al, math.deg(p.rot))
			end
		end
		for _, r in rings do
			local k = r.age / r.life
			cvW:ring(r.x, r.y, r.r0 * (1 + k * 1.3), r.w * (1 - k) + 1, r.col, 1 - k)
		end
	end
	local TXT = {}
	local function otext(cv, str, x, y, size, color, alpha, align, lw, grad, rot, sc)
		TXT.lw = lw or 0.2
		TXT.grad = grad
		return cv:text(str, x, y, size, color, alpha, align or "center", rot or 0, sc or 1, TXT)
	end
	local function drawCombo()
		if combo < 3 or mode ~= "play" then return end
		local y = G.hitY * 0.42
		local sz = math.min(W * 0.2, 78) * (1 + comboPop * 0.3) * (1 + math.min(combo, 200) / 800)
		local dx, dy = 0, 0
		if comboPop > 0.2 and combo % 25 == 0 then
			dx, dy = rand(-4, 4), rand(-4, 4)
		end
		otext(cvW, tostring(combo), G.cx + dx, y + dy, math.floor(sz + 0.5), WHITE, 0.9, "center", 0.16, combo >= 50 and C.rainbowSeq(C.hue(0)) or nil)
		otext(cvW, "COMBO", G.cx, y + sz * 0.62, math.floor(sz * 0.3 + 0.5), combo >= 25 and COL.gold or COL.muted, 0.9, "center", 0.22)
	end
	local function drawJudge()
		if not judge then return end
		local a = judge.age
		local y = G.hitY - math.min(150, G.hitY * 0.28) - (judge.miss and -a * 40 or a * 20)
		local pop = a < 0.1 and 0.5 + easeBack(a / 0.1) * 0.7 or 1.2 - math.min(0.2, (a - 0.1) * 0.8)
		local sz = math.floor(math.min(W * 0.12, 46) * pop + 0.5)
		local al = a > 0.4 and math.max(0, 1 - (a - 0.4) / 0.2) or 1
		if judge.miss then
			otext(cvW, "MISS", G.cx, y, sz, COL.red, al)
		elseif judge.perfect then
			otext(cvW, "PERFECT", G.cx, y, sz, WHITE, al, "center", 0.2, C.rainbowSeq(C.hue(0) + a * 600))
		else
			otext(cvW, "GOOD", G.cx, y, sz, COL.cyan, al)
			otext(cvW, judge.early and "TÔT" or "TARD", G.cx, y + sz * 0.72, math.floor(sz * 0.36 + 0.5), COL.muted, al)
		end
	end
	local function drawBanners()
		local yy = H * 0.24
		for _, b in banners do
			local a = b.age
			local s = a < 0.15 and 0.3 + easeBack(a / 0.15) * 0.7 or 1
			local sz = math.floor(math.min(W * (b.big and 0.085 or 0.065), b.big and 40 or 30) * s + 0.5)
			local al = a > 1 and math.max(0, 1 - (a - 1) / 0.3) or 1
			local y = yy - a * 18
			if b.col == "rgb" then
				otext(cvW, b.text, G.cx, y, sz, WHITE, al, "center", 0.2, C.rainbowSeq(C.hue(0) + a * 300))
			else
				otext(cvW, b.text, G.cx, y, sz, b.col, al)
			end
			if b.icon then
				local tw = C.textWc(b.text, sz, C.FD)
				local rr = math.deg(math.sin(a * 12) * 0.15)
				cvW:icon(b.icon, G.cx - tw / 2 - sz * 0.75, y, sz * 1.15, rr, al)
				cvW:icon(b.icon, G.cx + tw / 2 + sz * 0.75, y, sz * 1.15, -rr, al)
			end
			yy += sz * 1.25
		end
	end
	local function drawHUD(T, vt, beatPh)
		box(cvH, W / 2, 46, W, 92, { color = COL.shade, alpha = 1, gradT = C.nseq({ { 0, 0.15 }, { 1, 1 } }), grot = 90 })
		local prog = clamp(vt / SONG_LEN, 0, 1)
		cvH:rectTL(0, 0, W, 4, WHITE, 0.1)
		if prog > 0 then box(cvH, W * prog / 2, 2, W * prog, 4, { color = WHITE, alpha = 1, grad = C.rainbowSeq(C.hue(0)) }) end
		local pad = 12
		cvH:ptext("SCORE", pad, 17, 11, COL.muted, 1, "left")
		otext(cvH, fmtInt(score * SCALE), pad, 40, 24, WHITE, 1, "left", 0.2)
		local m = mult(combo)
		cvH:ptext("MULTI", W - pad, 17, 11, COL.muted, 1, "right")
		otext(cvH, "×" .. multStr(m), W - pad, 40, 24, m > 1 and COL.gold or WHITE, 1, "right", 0.2, m >= 4 and C.rainbowSeq(C.hue(0)) or nil)
		if not sideRoom() then
			local bounce = (1 - beatPh) ^ 3
			local hr = clamp(W * 0.055, 18, 28) * (rgbMode and 1.15 or 1)
			cvH:cookie(W / 2, 34 - bounce * 5, hr, math.sin(T * (rgbMode and 9 or 4)) * (rgbMode and 0.35 or 0.12), { acc = true, squash = bounce * 0.3 })
		end
		-- jauge de hype
		local bw = math.min(W - pad * 2, G.hw + 60)
		local bx, by, bh = (W - bw) / 2, 64, 11
		box(cvH, bx + bw / 2, by + bh / 2, bw, bh, { color = BLACK, alpha = 0.5, radius = 6, stroke = INK, sw = 3, sa = 1 })
		if hype > 0.002 then
			local fw = math.max(bh, bw * hype)
			box(cvH, bx + fw / 2, by + bh / 2, fw, bh, { color = WHITE, alpha = 1, radius = 6, grad = C.rainbowSeq(C.hue(0) + T * 90) })
			box(cvH, bx + fw / 2, by + bh * 0.2, math.max(0, fw - 6), bh * 0.4, { color = WHITE, alpha = 0.35, radius = 3 })
		end
		cvH:ptext(hype >= 1 and "HYPE MAX" or "HYPE", bx + 6, by + bh / 2 + 0.5, 9, WHITE, 1, "left")
	end
	local CD_COL = { COL.red, COL.gold, COL.lime }
	local function drawCountdown(vt)
		if mode ~= "play" or vt >= 0 then return end
		local b = math.floor(vt / SPB)
		local cy = H * 0.42
		if b < -COUNT_IN then
			otext(cvH, "PRÊT ?", G.cx, cy, math.floor(math.min(W * 0.14, 60) + 0.5), WHITE)
			return
		end
		local ph = vt / SPB - b
		local idx = b + COUNT_IN + 1
		local label = ({ "3", "2", "1", "GO !" })[idx]
		local go = b == -1
		local sz = math.floor(math.min(W, H) * (go and 0.2 or 0.28) * (1.35 - 0.35 * math.min(1, ph * 3)) + 0.5)
		if go then
			otext(cvH, label, G.cx, cy, sz, WHITE, 1 - ph * 0.5, "center", 0.14, C.rainbowSeq(C.hue(0)))
		else
			otext(cvH, label, G.cx, cy, sz, CD_COL[idx], 1 - ph * 0.5, "center", 0.14)
		end
	end
	local function render(T)
		local vt = songT
		local beatPh = (vt / SPB) % 1
		local pulse = (1 - beatPh) ^ 3
		cvBg:begin()
		drawBg(T, vt, pulse)
		cvBg:finish()
		cvSide:begin()
		drawSides(T, vt, beatPh)
		cvSide:finish()
		world.Position = shake > 0 and UDim2.fromOffset(rand(-shake, shake), rand(-shake, shake)) or UDim2.fromOffset(0, 0)
		cvW:begin()
		drawHighway(vt)
		drawCombo()
		if mode == "play" then
			local from = first
			while from > 1 and notes[from - 1].t > vt - 0.5 do from -= 1 end
			drawNoteSet(notes, vt, math.min(from, #notes), 0, false)
		else
			drawNoteSet(CHART, vt, 1, 0, true)
			if vt + APPROACH > DEMO_A + DEMO_LEN then drawNoteSet(CHART, vt, 1, DEMO_LEN, true) end
		end
		drawReceptors(beatPh)
		if mode ~= "play" then cvW:rectTL(-20, -20, W + 40, H + 40, COL.veil, 0.42) end
		drawParticles()
		drawJudge()
		drawBanners()
		cvW:finish()
		cvH:begin()
		if mode == "play" then
			drawHUD(T, vt, beatPh)
			drawCountdown(vt)
		end
		if flash > 0 then cvH:rectTL(0, 0, W, H, flashCol, flash) end
		cvH:finish()
	end

	----------------------------------------------------------------------- boucle
	local function resize()
		local s = root.AbsoluteSize
		local w, h = math.max(200, math.floor(s.X + 0.5)), math.max(240, math.floor(s.Y + 0.5))
		if w == W and h == H then return end
		W, H = w, h
		G.hw = math.min(W - 16, 500)
		G.lw = G.hw / 4
		G.cx = W / 2
		G.hitY = H - clamp(H * 0.16, 76, 128)
		G.persp = 0.6
		G.nr = math.min(G.lw * 0.33, 30)
		G.speed = (G.hitY + G.nr * 2) / APPROACH
		layoutStatic()
		if panel then panel.layout() end
	end
	bag.add(RunService.RenderStepped:Connect(function(dt)
		if destroyed then return end
		if not (dt > 0) then dt = 0 end
		if dt > 0.05 then dt = 0.05 end
		local T = os.clock()
		resize()
		update(dt, T)
		render(T)
		if panel then
			panel.frame()
			if panel.update then panel.update(T, dt) end
		end
	end))

	----------------------------------------------------------------------- entrées
	local function laneAt(input)
		local x, y = C.inputXY(input, root)
		return laneFromXY(x, y)
	end
	bag.add(hit.InputBegan:Connect(function(input)
		if mode ~= "play" then return end
		local ut = input.UserInputType
		if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch then
			local key = ut == Enum.UserInputType.Touch and input or "mouse"
			local lane = laneAt(input)
			ptrLane[key] = lane
			pressLane(lane)
		end
	end))
	bag.add(UIS.InputEnded:Connect(function(input)
		local ut = input.UserInputType
		local key = ut == Enum.UserInputType.Touch and input or (ut == Enum.UserInputType.MouseButton1 and "mouse" or nil)
		if key == nil then return end
		local l = ptrLane[key]
		if l ~= nil then
			ptrLane[key] = nil
			local still = false
			for _, v in ptrLane do
				if v == l then still = true end
			end
			if not still then releaseLane(l) end
		end
	end))
	-- D F J K / flèches / Espace : captées pour ne pas déplacer l'avatar derrière le jeu
	local function canStart() return mode == "start" or (mode == "results" and res ~= nil and os.clock() - res.t > 0.8) end
	CAS:BindActionAtPriority("CookieRhythmKeys", function(_, state, input)
		local lane = KEYMAP[input.KeyCode]
		if lane ~= nil then
			if state == Enum.UserInputState.Begin then
				pressLane(lane)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				releaseLane(lane)
			end
		elseif input.KeyCode == Enum.KeyCode.Space and state == Enum.UserInputState.Begin and canStart() then
			startRun()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.D, Enum.KeyCode.F, Enum.KeyCode.J, Enum.KeyCode.K,
		Enum.KeyCode.Left, Enum.KeyCode.Down, Enum.KeyCode.Up, Enum.KeyCode.Right, Enum.KeyCode.Space)
	bag.add(function() CAS:UnbindAction("CookieRhythmKeys") end)
	bag.add(UIS.InputBegan:Connect(function(input)
		if UIS:GetFocusedTextBox() then return end
		if (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) and canStart() then startRun() end
	end))
	bag.add(UIS.WindowFocusReleased:Connect(function()
		for i = 1, 4 do held[i] = false end
		table.clear(ptrLane)
		-- sans la fenêtre, l'horloge continue : la manche est annulée (comme l'onglet caché du site)
		abortRun("Partie annulée : t'as quitté la fenêtre")
	end))

	resize()
	showStart()

	return {
		destroy = function()
			if destroyed then return end
			destroyed = true
			bag.clean()
			clearLayer()
			table.clear(parts)
			table.clear(rings)
			table.clear(banners)
			cvBg:destroy()
			cvSide:destroy()
			cvW:destroy()
			cvH:destroy()
		end,
	}
end

return Rhythm
