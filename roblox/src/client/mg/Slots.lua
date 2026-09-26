--!nonstrict
-- COOKIE OVERDRIVE — mini-jeu « Casino Crumble » (port de mg-slots.js).
-- Machine à sous néon à 3 rouleaux : marquise arc-en-ciel, ampoules, rouleaux cylindriques avec
-- flou de vitesse, suspense sur le 3e rouleau, levier, compteur de gains, historique, fontaines de
-- pièces / cookies / gemmes, JACKPOT.
-- Le tirage et les gains sont décidés par le SERVEUR (act("spin", 1..3)) : 3 niveaux de mise
-- (×1, ×5, ×25 de l'unité), symboles 🍪 🍫 🥛 💎 ⭐ 7️⃣, paires ×1,5 ; les rouleaux démarrent tout de
-- suite et s'arrêtent sur le résultat reçu.
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")

local C = require(script.Parent:WaitForChild("Common"))

local hex, hsl, clamp, rand, pick, TAU = C.hex, C.hsl, C.clamp, C.rand, C.pick, C.TAU
local WHITE, BLACK, INK = C.col.white, C.col.black, C.INK
local MAX_PARTS = 260
local VMAX = 21

-- symboles du serveur → art du site
local FROM_SERVER = { ["🍪"] = "cookie", ["🍫"] = "choco", ["🥛"] = "milk", ["💎"] = "gem", ["⭐"] = "star", ["7️⃣"] = "seven" }
local ART = { seven = "item:seven", gem = "ui:gem", choco = "item:choco", milk = "item:milk", star = "ui:star" }
local STRIP = { "cookie", "cookie", "cookie", "choco", "choco", "milk", "milk", "gem", "star", "seven" } -- mêmes poids que le serveur
local PAY = { cookie = 3, choco = 6, milk = 10, gem = 25, star = 50, seven = 150 }
local BETS = { { label = "×1", m = 1 }, { label = "×5", m = 5 }, { label = "×25", m = 25, red = true } }

local COL = {
	gold = hex("#ffc93c"), pink = hex("#ff2bd6"), cyan = hex("#1ff4ff"), lime = hex("#b6ff3b"), green = hex("#2bdc6a"),
	red = hex("#ff4d6d"), muted = hex("#b3a6dd"), dim = hex("#7d6fae"), bulbOff = hex("#3b2466"), meterBg = hex("#07021a"),
	head = Color3.fromRGB(10, 3, 28), lever = hex("#2a1060"), ball = hex("#ff2b4a"), stick = hex("#d6dbf0"),
	coinD = hex("#b86e00"), coinL = hex("#fff3b0"), salmon = hex("#ff8095"),
}
local BODY_SEQ = C.seq({ { 0, hex("#6a1fb8") }, { 0.45, hex("#3a0f78") }, { 1, hex("#1e0746") } })
local REEL_SEQ = C.seq({ { 0, hex("#f3e9ff") }, { 0.5, hex("#ffffff") }, { 1, hex("#e2d4ff") } })
local BG_SEQ = C.seq({ { 0, hex("#12062e") }, { 0.6, hex("#1d0840") }, { 1, hex("#0a0418") } })

local function easeBack(x, c1)
	c1 = c1 or 1.3
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end
local function easeOut3(x) return 1 - (1 - x) ^ 3 end
local function multStr(m) return (string.gsub(tostring(m), "%.", ",")) end
local DOTS = { "·", "· ", "· ·", "· · ", "· · ·" } -- '· · ·'.slice(0, n) (le point médian fait 2 octets)

-- triangle de la ligne de paiement (pointe vers +x), rose contouré
local function texTri()
	return C.proc("slotTri", 32, 40, function(buf, w, h)
		C.rasterPoly(buf, w, h, { { 4, 4 }, { 28, 20 }, { 4, 36 } }, { 255, 43, 214 }, { 26, 11, 51 }, 4)
	end)
end

local Slots = {}

function Slots.mount(ctx)
	local root = ctx.root
	local bag = C.bag()
	local destroyed = false
	local coarse = C.coarse()

	----------------------------------------------------------------------- état
	local W, H = 0, 0 -- 0 : force la première mise en page
	local M = { x = 0, y = 0, w = 0, h = 0, cs = 80, pad = 10, gap = 8, headH = 50, winH = 150, meterH = 40, reelY = 0, meterY = 0, lever = false, lx = 0, ly = 0, bulbs = {} }
	local level = 1
	local spinning, lockUntil, curBet, result, outcome, resolved = false, 0, 0, nil, nil, true
	local spins, streak = 0, 0
	local spinId = 0
	local anticip, anticipT, tickT = false, 0, 0
	local meter = { from = 0, to = 0, t0 = 0, dur = 1, label = "BONNE CHANCE", kind = "idle", lastTick = 0 }
	local fx = { rays = 0, raysCol = "rgb", tint = 0, tintCol = COL.green, flash = 0, flashCol = WHITE, shake = 0, big = nil, hero = 0, fountain = 0, fountainKind = "coin", bounce = 0, hitGlow = 0, deny = 0, denyT = -9 }
	local parts, rings = {}, {}
	local leverPull, leverT = 0, -9
	local frozenBank = nil
	local lastBank, bankBumpT = -1, 0
	local styledLevel = 0

	local reels = {}
	for i = 1, 3 do
		local strip = {}
		for k = 1, 64 do strip[k] = pick(STRIP) end
		reels[i] = { strip = strip, off = math.random(0, 63), v = 0, state = "idle", stopAt = 0, from = 0, F = 0, t0 = 0, dur = 0.5, target = nil, land = 0 }
	end
	local function symAt(r, idx) return r.strip[(idx % 64) + 1] end

	----------------------------------------------------------------------- calques
	C.new("Frame", { Name = "Bg", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = root }, {
		C.new("UIGradient", { Rotation = 90, Color = BG_SEQ }),
	})
	local cvBg = C.canvas(root, 2, "Rays")
	local mach = C.new("Frame", { Name = "Machine", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = root })
	local cvBody = C.canvas(mach, 1, "Body")
	local reelF = {}
	for i = 1, 3 do
		local f = C.new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 3, Parent = mach }, {
			C.new("UIGradient", { Rotation = 90, Color = REEL_SEQ }),
		})
		local corner = C.corner(10)
		corner.Parent = f
		local cv = C.canvas(f, 1, "Symbols")
		local shadeCorner = C.corner(10)
		local shade = C.new("Frame", { BackgroundColor3 = Color3.fromRGB(30, 8, 70), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = f }, {
			C.new("UIGradient", { Rotation = 90, Transparency = C.nseq({ { 0, 0.22 }, { 0.24, 1 }, { 0.76, 1 }, { 1, 0.22 } }) }),
			shadeCorner,
		})
		local shine = C.new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), ZIndex = 60, Parent = f }, {
			C.new("UIGradient", { Transparency = C.nseq({ { 0, 1 }, { 0.5, 0.65 }, { 1, 1 } }) }),
		})
		reelF[i] = { f = f, corner = corner, shadeCorner = shadeCorner, cv = cv, shade = shade, shine = shine }
	end
	local cvTop = C.canvas(mach, 8, "Front")
	local cvFx = C.canvas(root, 20, "Fx")
	local hit = C.new("TextButton", {
		Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ZIndex = 25, Selectable = false, Parent = root,
	})

	----------------------------------------------------------------------- barre du haut (.cos-top)
	local top = C.new("Frame", { Name = "Top", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 34), ZIndex = 30, Parent = root })
	-- pastille banque : halo + ombre + corps (largeur recalculée à chaque changement de valeur)
	local bankHolder = C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(80, 31), ZIndex = 30, Parent = top })
	local bankScale = C.new("UIScale", { Parent = bankHolder })
	local bankGlow = C.new("ImageLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 34, 1, 34),
		ImageColor3 = COL.gold, ImageTransparency = 0.7, ZIndex = 30, Parent = bankHolder,
	})
	if not C.applyProc(bankGlow, C.texGlow(0.5)) then bankGlow:Destroy() end
	C.new("Frame", { BackgroundColor3 = INK, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 3), Size = UDim2.fromScale(1, 1), ZIndex = 31, Parent = bankHolder }, { C.corner(UDim.new(1, 0)) })
	local bankPill = C.new("Frame", { BackgroundColor3 = Color3.fromRGB(10, 4, 30), BackgroundTransparency = 0.3, Size = UDim2.fromScale(1, 1), ZIndex = 32, Parent = bankHolder }, {
		C.corner(UDim.new(1, 0)), C.new("UIStroke", { Color = COL.gold, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		C.new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 12) }),
		C.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	C.icon(bankPill, "ui:cookie", 22, { LayoutOrder = 1, ZIndex = 33 })
	local bankV = C.new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Text = "0", FontFace = C.FD, TextSize = 20,
		TextColor3 = WHITE, LayoutOrder = 2, ZIndex = 33, Parent = bankPill,
	}, { C.tstroke(INK, 1.5) })
	local function setBankText(t)
		bankV.Text = t
		bankHolder.Size = UDim2.fromOffset(math.ceil(7 + 22 + 6 + C.textWc(t, 20, C.FD) + 12 + 2), 31)
	end
	setBankText("0")
	local hist = C.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(1, -160, 0, 34), ClipsDescendants = true, ZIndex = 30, Parent = top }, {
		C.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local histChips = {}
	local histOrder = 0

	----------------------------------------------------------------------- commandes (.cos-bottom)
	local bottom = C.new("Frame", { Name = "Bottom", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(470, 150), ZIndex = 30, Parent = root })
	local betLine = C.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(300, 24), ZIndex = 30, Parent = bottom }, {
		C.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	C.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Text = "MISE", FontFace = C.FM, TextSize = 13, TextColor3 = COL.muted, LayoutOrder = 1, ZIndex = 31, Parent = betLine })
	local betV = C.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Text = "0", FontFace = C.FD, TextSize = 22, TextColor3 = WHITE, LayoutOrder = 2, ZIndex = 31, Parent = betLine })
	local betIcon = C.icon(betLine, "ui:cookie", 22, { LayoutOrder = 3, ZIndex = 31 })

	local spin -- défini plus bas
	local setBet
	local betBtns = {}
	for i, b in BETS do
		betBtns[i] = C.button(bottom, b.label, { style = b.red and "red" or "dark", size = "small", z = 32 }, function() setBet(i) end)
	end
	local spinBtn = C.button(bottom, "SPIN", { style = "pink", size = "big", font = 28, z = 32 }, function() spin() end)
	local hint = C.new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(300, 12), Text = coarse and "TAPE LA MACHINE OU SPIN" or "ESPACE = SPIN · 1 2 3 = MISE",
		FontFace = C.FM, TextSize = 11, TextColor3 = COL.dim, ZIndex = 31, Parent = bottom,
	})
	local bottomH = 150

	----------------------------------------------------------------------- mise / banque
	local function liveCookies()
		local v = ctx.cookies()
		return math.max(0, math.floor(v or 0))
	end
	local function unitNow()
		if ctx.unit then return ctx.unit() end
		local L = ctx.live() or {}
		return math.max(25, (L.cpsBase or 0) * 60, (L.click or 0) * 90)
	end
	local function betFor(i) return math.floor(unitNow() * 0.1 * BETS[i].m) end
	local function bankShown()
		if frozenBank then return math.max(0, math.floor(frozenBank)) end
		return liveCookies()
	end
	local function refreshBet()
		local b = bankShown()
		local bet = betFor(level)
		local ok = spinning or b >= bet
		betV.Text = ok and ctx.fmt(bet) or "PAS ASSEZ"
		betV.TextColor3 = ok and WHITE or COL.red
		betIcon.Visible = ok
		for i, B in betBtns do
			if styledLevel == level then break end
			local sel = i == level
			if BETS[i].red then
				B.setStyle(sel and "redsel" or "red", WHITE)
			else
				B.setStyle(sel and "sel" or "dark", sel and INK or WHITE)
			end
		end
		styledLevel = level
		if b ~= lastBank then
			if lastBank >= 0 and b > lastBank then bankBumpT = os.clock() end
			lastBank = b
			setBankText(ctx.fmt(b))
		end
	end
	function setBet(i)
		if level == i then return end
		level = i
		C.sfx("tick", { pitch = 0.9 + i * 0.2, vol = 0.6 })
		refreshBet()
	end

	----------------------------------------------------------------------- effets
	local function bigText(text, col, dur, style, sub) fx.big = { text = text, col = col, t0 = os.clock(), dur = dur, style = style, sub = sub or "" } end
	local function flash(a, col)
		fx.flash = math.max(fx.flash, a)
		fx.flashCol = col
	end
	local function reelX(i) return M.x + M.pad + (i - 1) * (M.cs + M.gap) end
	local function shockwave(n)
		for i = 0, n - 1 do table.insert(rings, { x = M.x + M.w / 2, y = M.reelY + M.winH / 2, age = -i * 0.12, life = 0.9, max = math.max(W, H) * 0.8, h = i * 90 }) end
	end
	local function sparks(x, y, n, col)
		for _ = 1, n do
			if #parts >= MAX_PARTS then break end
			local a, sp = rand(0, TAU), rand(120, 380)
			table.insert(parts, { k = "spark", x = x, y = y, vx = math.cos(a) * sp, vy = math.sin(a) * sp, g = 200, life = rand(0.2, 0.45), age = 0, sz = rand(1.5, 3), col = col })
		end
	end
	local function coins(n, x, y, power, kind)
		for _ = 1, n do
			if #parts >= MAX_PARTS then break end
			table.insert(parts, { k = kind or "coin", x = x + rand(-M.cs * 0.6, M.cs * 0.6), y = y, vx = rand(-260, 260) * power, vy = rand(-900, -480) * power, g = 1500, life = rand(1.2, 2.2), age = 0, sz = rand(0.09, 0.14) * M.cs, spin = rand(0, TAU), vs = rand(6, 14) })
		end
	end
	local function confetti(n)
		for _ = 1, n do
			if #parts >= MAX_PARTS then break end
			table.insert(parts, { k = "conf", x = rand(0, W), y = rand(-80, -10), vx = rand(-60, 60), vy = rand(60, 240), g = 90, life = rand(2.2, 3.6), age = 0, sz = rand(4, 9), spin = rand(0, TAU), vs = rand(-8, 8), col = hsl(rand(0, 360), 100, 62) })
		end
	end
	local function deny(msg, sub)
		C.sfx("error", { vol = 0.8 })
		fx.deny = 1
		fx.denyT = os.clock()
		fx.shake = math.max(fx.shake, 9)
		bigText(msg or "PAS ASSEZ DE COOKIES", COL.red, 1.4, "deny", sub or "Va cliquer un peu et reviens")
	end

	----------------------------------------------------------------------- historique (.cos-chip)
	local CHIP = {
		lose = { WHITE, COL.dim, hex("#23164a") }, pair = { WHITE, WHITE, COL.green }, triple = { INK, INK, COL.lime },
		star3 = { WHITE, WHITE, COL.pink }, gem3 = { INK, INK, COL.cyan }, jackpot = { WHITE, WHITE, WHITE },
	}
	local function pushHistory(o)
		local st = CHIP[o.kind] or CHIP.lose
		local txt = o.kind == "lose" and "L" or ("×" .. multStr(o.mult))
		histOrder -= 1
		local cw = math.ceil(C.textWc(txt, 14, C.FD) + 16 + (o.kind == "gem3" and 18 or 0) + 2)
		local holder = C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(cw, 24), LayoutOrder = histOrder, ZIndex = 32, Parent = hist })
		local chip = C.new("Frame", {
			BackgroundColor3 = st[3], Size = UDim2.fromScale(1, 1), ZIndex = 32, Parent = holder,
		}, {
			C.corner(UDim.new(1, 0)), C.new("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			C.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
			C.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		if o.kind == "jackpot" then C.new("UIGradient", { Color = C.RGB_SEQ, Parent = chip }) end
		local l = C.new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, Text = txt, FontFace = C.FD, TextSize = 14,
			TextColor3 = o.kind == "lose" and COL.dim or st[1], LayoutOrder = 1, ZIndex = 33, Parent = chip,
		})
		if o.kind == "jackpot" then C.tstroke(INK, 1).Parent = l end
		if o.kind == "gem3" then C.icon(chip, "ui:gem", 15, { LayoutOrder = 2, ZIndex = 33 }) end
		local sc = C.new("UIScale", { Scale = 0.2, Parent = chip })
		table.insert(histChips, 1, { f = holder, sc = sc, t0 = os.clock() })
		while #histChips > 7 do
			local old = table.remove(histChips)
			old.f:Destroy()
		end
	end

	----------------------------------------------------------------------- tirage
	local function evaluate(s)
		local a, b, c = s[1], s[2], s[3]
		if a == b and b == c then
			local kind = a == "seven" and "jackpot" or (a == "star" and "star3" or (a == "gem" and "gem3" or "triple"))
			return { kind = kind, mult = PAY[a], hit = { 1, 2, 3 } }
		end
		local hitL = (a == b and { 1, 2 }) or (a == c and { 1, 3 }) or (b == c and { 2, 3 }) or nil
		if hitL then return { kind = "pair", mult = 1.5, hit = hitL } end
		return { kind = "lose", mult = 0, hit = {} }
	end
	local function hasHit(o, i)
		if not o then return false end
		for _, v in o.hit do
			if v == i then return true end
		end
		return false
	end

	local resolve
	-- tirage refusé (ou sans réponse) : les rouleaux s'arrêtent à vide, rien n'est misé
	local function failSpin(msg, sub)
		spinId += 1
		deny(msg, sub)
		outcome = { kind = "none", mult = 0, hit = {} }
		result = nil
		local now = os.clock()
		for _, r in reels do
			if r.state == "spin" then
				r.target = pick(STRIP)
				r.stopAt = now
			end
		end
		frozenBank = nil
	end
	function spin()
		local T = os.clock()
		if destroyed or spinning or T < lockUntil then return end
		local est = betFor(level)
		if liveCookies() < est then
			deny()
			refreshBet()
			return
		end
		spinning, resolved = true, false
		spins += 1
		spinId += 1
		local myId = spinId
		result, outcome = nil, nil
		anticip = false
		for i, r in reels do
			r.state = "spin"
			r.v = -3
			r.stopAt = T + 0.55 + (i - 1) * 0.3
			r.target = nil
		end
		leverT = T
		meter = { from = 0, to = 0, t0 = T, dur = 1, label = "ÇA TOURNE…", kind = "spin", lastTick = 0 }
		fx.big = nil
		fx.hitGlow = 0
		frozenBank = bankShown() - est
		C.sfx("spin", { vol = 0.8 })
		C.sfx("whoosh", { vol = 0.5 })
		refreshBet()
		local betIdx = level
		task.spawn(function()
			local ok, res = pcall(ctx.act, "spin", betIdx)
			if destroyed or myId ~= spinId then return end
			local now = os.clock()
			if not ok or type(res) ~= "table" or res.err or type(res.reels) ~= "table" then
				if type(res) == "table" and res.err then
					failSpin("PAS ASSEZ DE COOKIES")
				else
					failSpin("MACHINE INDISPONIBLE", "Réessaie dans un instant")
				end
				return
			end
			local syms = {}
			for i = 1, 3 do syms[i] = FROM_SERVER[res.reels[i]] or "cookie" end
			result = syms
			outcome = evaluate(syms)
			outcome.win = tonumber(res.win) or 0
			outcome.gems = tonumber(res.gems) or 0
			curBet = tonumber(res.bet) or est
			frozenBank = (frozenBank or 0) + est - curBet
			for i, r in reels do
				r.target = syms[i]
				r.stopAt = math.max(r.stopAt, now + 0.1 + (i - 1) * 0.3)
			end
			if syms[1] == syms[2] then reels[3].stopAt += 0.95 end
		end)
	end

	local function reelStopped(i, T)
		local r = reels[i]
		C.sfx("reel", { pitch = 1 + (i - 1) * 0.12, vol = 0.9 })
		fx.bounce = math.max(fx.bounce, 1)
		fx.shake = math.max(fx.shake, 2.5)
		sparks(reelX(i) + M.cs / 2, M.reelY + M.winH / 2, 8, WHITE)
		r.land = 1
		if i == 2 and result and result[1] == result[2] then
			anticip = true
			anticipT, tickT = T, T
			if result[1] == "seven" then
				bigText("77…", "rgb", 1.3, "small", "LE JACKPOT EST LÀ")
			else
				bigText("ÇA SENT BON…", COL.gold, 1.3, "small")
			end
		end
		if i == 3 then
			anticip = false
			resolve(T)
		end
	end

	function resolve(T)
		if resolved then return end
		resolved = true
		spinning = false
		local o = outcome
		frozenBank = nil
		if not o or o.kind == "none" then
			meter = { from = 0, to = 0, t0 = T, dur = 1, label = "BONNE CHANCE", kind = "idle", lastTick = 0 }
			refreshBet()
			return
		end
		local win = math.floor((o.win or 0) + 0.5)
		streak = o.mult > 0 and math.max(1, streak + 1) or math.min(-1, streak - 1)
		pushHistory(o)
		local dur = ({ jackpot = 3, star3 = 2, gem3 = 1.6, triple = 1.2, pair = 0.6 })[o.kind] or 0.5
		meter = { from = 0, to = win, t0 = T, dur = dur, label = win > 0 and "GAIN" or "PERDU", kind = o.kind, lastTick = 0, gems = o.gems }
		fx.hitGlow = #o.hit > 0 and 1 or 0
		local gemsTxt = (o.gems or 0) > 0 and ("  ·  +" .. o.gems .. " GEMMES") or ""
		if o.kind == "jackpot" then
			lockUntil = T + 2.2
			C.sfx("jackpot", { vol = 1 })
			bigText("JACKPOT", "rgb", 4, "jackpot", "×150  ·  +" .. ctx.fmt(win) .. gemsTxt)
			fx.rays, fx.raysCol, fx.hero, fx.fountain, fx.fountainKind = 4.5, "rgb", 4, 2.8, "coin"
			flash(0.9, WHITE)
			fx.shake = 16
			shockwave(3)
			confetti(160)
		elseif o.kind == "star3" then
			lockUntil = T + 1.4
			C.sfx("win", { vol = 1 })
			C.sfx("levelup", { vol = 0.7 })
			bigText("MEGA CRUNCH", COL.pink, 2.6, "win", "×50  ·  +" .. ctx.fmt(win))
			fx.rays, fx.raysCol, fx.hero, fx.fountain, fx.fountainKind = 2.6, COL.pink, 2.6, 1.6, "cookie"
			flash(0.5, hex("#ff9aea"))
			fx.shake = 10
			shockwave(2)
		elseif o.kind == "gem3" then
			lockUntil = T + 1.2
			C.sfx("win", { vol = 1 })
			C.sfx("achievement", { vol = 0.6 })
			bigText("DIAMOND HANDS", COL.cyan, 2.4, "win", "×25  ·  +" .. ctx.fmt(win) .. gemsTxt)
			fx.rays, fx.raysCol, fx.fountain, fx.fountainKind = 2, COL.cyan, 1.4, "gem"
			flash(0.4, hex("#bffcff"))
			fx.shake = 8
			shockwave(1)
		elseif o.kind == "triple" then
			lockUntil = T + 0.9
			C.sfx("win", { vol = 0.9 })
			bigText("BIG W", COL.lime, 1.8, "win", "×" .. o.mult .. "  ·  +" .. ctx.fmt(win))
			fx.fountain, fx.fountainKind = 1, "coin"
			fx.shake = 6
			shockwave(1)
		elseif o.kind == "pair" then
			lockUntil = T + 0.25
			C.sfx("coin", { vol = 0.8 })
			bigText(pick({ "PAS MAL", "W", "NICE", "PETIT W" }), WHITE, 1.1, "small", "×1,5  ·  +" .. ctx.fmt(win))
			coins(10, M.x + M.w / 2, M.meterY, 0.6)
		else
			lockUntil = T + 0.2
			C.sfx("lose", { vol = 0.4 })
			bigText(pick({ "RATIO", "L", "PRESQUE…", "TKT, LA PROCHAINE", "AÏE", "ÇA PIQUE" }), COL.muted, 1, "small")
		end
		refreshBet()
	end

	----------------------------------------------------------------------- mise en page
	local function layout()
		local short = H < 520 and W > H
		-- commandes du bas
		local bw = math.min(470, W - 20)
		local rowGap = short and 5 or 7
		local betH = betBtns[1].h
		local spinH = spinBtn.h
		local y = 0
		betLine.Size = UDim2.fromOffset(bw, short and 20 or 24)
		betLine.Position = UDim2.fromOffset(bw / 2, y)
		y += (short and 20 or 24) + rowGap
		if short then
			-- une seule rangée : mises à gauche, SPIN à droite
			local half = (bw - 6) / 2
			local each = (half - 12) / 3
			for i, B in betBtns do
				B.btn.Size = UDim2.fromOffset(each, betH)
				B.btn.Position = UDim2.fromOffset((i - 1) * (each + 6), y + (spinH - betH) / 2)
			end
			spinBtn.btn.Size = UDim2.fromOffset(half, spinH)
			spinBtn.btn.Position = UDim2.fromOffset(half + 6, y)
			y += spinH + 4
			hint.Visible = false
		else
			local each = (bw - 12) / 3
			for i, B in betBtns do
				B.btn.Size = UDim2.fromOffset(each, betH)
				B.btn.Position = UDim2.fromOffset((i - 1) * (each + 6), y)
			end
			y += betH + 4 + rowGap
			spinBtn.btn.Size = UDim2.fromOffset(bw, spinH)
			spinBtn.btn.Position = UDim2.fromOffset(0, y)
			y += spinH + 4 + rowGap
			hint.Visible = true
			hint.Size = UDim2.fromOffset(bw, 12)
			hint.Position = UDim2.fromOffset(bw / 2, y)
			y += 12
		end
		bottomH = y
		bottom.Size = UDim2.fromOffset(bw, bottomH)
		bottom.Position = UDim2.new(0.5, 0, 1, short and -8 or -12)
		-- machine
		local topH = 8 + 34 + 4
		local botH = bottomH + (short and 8 or 12) + 10
		local areaT = topH
		local areaH = math.max(160, H - botH - topH)
		M.lever = W >= 520
		local maxW = math.min(W - 16 - (M.lever and 90 or 0), 600)
		local cs = clamp(math.min(maxW / 3.5, (areaH - 18) / 3.62), 40, 150)
		M.cs, M.pad, M.gap = cs, cs * 0.15, cs * 0.1
		M.headH, M.winH, M.meterH = cs * 0.66, cs * 1.95, cs * 0.5
		M.w = cs * 3 + M.gap * 2 + M.pad * 2
		M.h = M.pad * 2 + M.headH + M.pad * 0.6 + M.winH + M.pad * 0.6 + M.meterH
		M.x = (W - M.w) / 2 - (M.lever and 26 or 0)
		M.y = areaT + (areaH - M.h) / 2
		M.reelY = M.y + M.pad + M.headH + M.pad * 0.6
		M.meterY = M.reelY + M.winH + M.pad * 0.6
		M.lx, M.ly = M.x + M.w + cs * 0.26, M.reelY + M.winH * 0.55
		M.bulbs = {}
		local inset = cs * 0.075
		local x0, y0, x1, y1 = M.x + inset, M.y + inset, M.x + M.w - inset, M.y + M.h - inset
		local stp = clamp(cs * 0.24, 14, 30)
		local function edge(ax, ay, bx, by)
			local L = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
			local n = math.max(1, math.floor(L / stp + 0.5))
			for i = 0, n - 1 do table.insert(M.bulbs, { ax + (bx - ax) * (i / n), ay + (by - ay) * (i / n) }) end
		end
		edge(x0, y0, x1, y0)
		edge(x1, y0, x1, y1)
		edge(x1, y1, x0, y1)
		edge(x0, y1, x0, y0)
		for i, R in reelF do
			R.f.Position = UDim2.fromOffset(reelX(i), M.reelY)
			R.f.Size = UDim2.fromOffset(cs, M.winH)
			R.corner.CornerRadius = UDim.new(0, cs * 0.14)
			R.shadeCorner.CornerRadius = UDim.new(0, cs * 0.14)
			R.shine.Size = UDim2.new(0, cs * 0.6, 1, 0)
		end
		hist.Size = UDim2.new(1, -(bankHolder.Size.X.Offset + 12), 0, 34)
	end

	----------------------------------------------------------------------- mise à jour
	local function update(dt, T)
		for i, r in reels do
			r.land = math.max(0, r.land - dt * 3)
			if r.state == "spin" then
				local vmax = VMAX
				if i == 3 and anticip then vmax = 9 + math.sin((T - anticipT) * 7) * 1.5 end
				r.v = r.v < vmax and math.min(vmax, r.v + 70 * dt) or math.max(vmax, r.v - 25 * dt)
				r.off += r.v * dt
				if T >= r.stopAt and r.v > 4 and r.target then
					r.F = math.floor(r.off) + 4
					r.strip[(r.F % 64) + 1] = r.target
					r.from, r.t0 = r.off, T
					r.dur = clamp(((r.F - r.off) * 3.4) / r.v, 0.3, 0.95)
					r.state = "stop"
				end
			elseif r.state == "stop" then
				local u = (T - r.t0) / r.dur
				if u >= 1 then
					r.off = r.F
					r.state = "idle"
					r.v = 0
					reelStopped(i, T)
				else
					r.off = r.from + (r.F - r.from) * easeBack(u, 1.25)
				end
			end
		end
		if spinning and not outcome and T - leverT > 10 then failSpin("MACHINE INDISPONIBLE", "Réessaie dans un instant") end
		if anticip and T - tickT > 0.11 then
			tickT = T
			C.sfx("tick", { pitch = 1 + (T - anticipT) * 0.5, vol = 0.5 })
		end
		local lt = T - leverT
		leverPull = lt < 0 and 0 or (lt < 0.14 and lt / 0.14 or (lt < 0.55 and 1 - easeOut3((lt - 0.14) / 0.41) or 0))
		if meter.to > 0 then
			local k = clamp((T - meter.t0) / meter.dur, 0, 1)
			if k < 1 and T - meter.lastTick > 0.075 then
				meter.lastTick = T
				C.sfx("coin", { pitch = 0.9 + k * 0.7, vol = 0.35 })
			end
		end
		if fx.fountain > 0 then
			fx.fountain -= dt
			local jack = outcome and outcome.kind == "jackpot"
			local n = (fx.fountainKind == "coin" and 60 or 36) * dt * (jack and 2.2 or 1)
			local cnt = math.floor(n) + (math.random() < n % 1 and 1 or 0)
			coins(cnt, M.x + M.w / 2, M.meterY + M.meterH * 0.5, 1, fx.fountainKind)
			if jack and math.random() < dt * 4 then confetti(12) end
		end
		fx.rays = math.max(0, fx.rays - dt)
		fx.hero = math.max(0, fx.hero - dt)
		fx.tint = math.max(0, fx.tint - dt * 0.45)
		fx.flash = math.max(0, fx.flash - dt * 2.2)
		fx.shake = math.max(0, fx.shake - dt * 28)
		fx.bounce = math.max(0, fx.bounce - dt * 5)
		fx.hitGlow = math.max(0, fx.hitGlow - dt * 0.25)
		fx.deny = math.max(0, fx.deny - dt * 2)
		if fx.big and T - fx.big.t0 > fx.big.dur then fx.big = nil end
		local n, i = #parts, 1
		while i <= n do
			local p = parts[i]
			p.age += dt
			if p.age >= p.life or p.y > H + 80 then
				parts[i] = parts[n]
				parts[n] = nil
				n -= 1
			else
				p.vy += p.g * dt
				p.x += p.vx * dt
				p.y += p.vy * dt
				if p.spin then p.spin += p.vs * dt end
				i += 1
			end
		end
		for j = #rings, 1, -1 do
			rings[j].age += dt
			if rings[j].age > rings[j].life then table.remove(rings, j) end
		end
	end

	----------------------------------------------------------------------- rendu
	local BOX = {}
	local function box(cv, x, y, w, h, o)
		table.clear(BOX)
		for k, v in o do BOX[k] = v end
		return cv:box(x, y, w, h, BOX)
	end
	local TXT = {}
	local function otext(cv, str, x, y, size, color, alpha, align, lw, grad, rot, sc)
		TXT.lw = lw or 0.2
		TXT.grad = grad
		return cv:text(str, x, y, math.max(1, size), color, alpha, align or "center", rot or 0, sc or 1, TXT)
	end
	local function raysCol(i)
		if fx.raysCol == "rgb" then return hsl(i * 20 + C.hue(0), 100, 60), 0.22 * math.min(1, fx.rays / 0.6) end
		return fx.raysCol, (i % 2 == 1 and 0.1 or 0.2) * math.min(1, fx.rays / 0.6)
	end
	local function bgRay(i)
		if i % 2 == 1 then return hsl(C.hue(i * 25), 90, 55), 0.05 end
		return WHITE, 0.025
	end
	local function drawBg(T)
		local cx, cy = M.x + M.w / 2, M.reelY + M.winH / 2
		local big = math.max(W, H)
		cvBg:rays(cx, cy, big * 1.2, 14, 0.5, T * 0.12, bgRay)
		cvBg:glow(cx, cy, big * 0.7, hsl(C.hue(60), 90, 40), 0.24, 0.1)
		cvBg:glow(cx, cy, big * 0.35, hsl(C.hue(0), 90, 55), 0.35, 0.1)
		for i = 0, 25 do
			local x, y = ((i * 137.5) % 100) / 100 * W, ((i * 71.3) % 100) / 100 * H
			cvBg:rectTL(x, y, 2, 2, WHITE, 0.25 + 0.25 * math.sin(T * 2 + i * 1.7))
		end
		if fx.rays > 0 then cvBg:rays(cx, cy, big, 18, 0.45, T * 0.9, raysCol) end
	end
	local function drawMachine(T)
		local x, y, w, h, cs = M.x, M.y, M.w, M.h, M.cs
		box(cvBody, x + w / 2, y + 6 + (h + 4) / 2, w + 8, h + 4, { color = BLACK, alpha = 0.45, radius = cs * 0.26 })
		box(cvBody, x + w / 2, y + h / 2, w, h, { color = WHITE, alpha = 1, grad = BODY_SEQ, grot = 90, radius = cs * 0.24, stroke = INK, sw = 5, sa = 1 })
		box(cvBody, x + w / 2, y + h / 2, w - 10, h - 10, { color = false, radius = cs * 0.2, stroke = fx.tint > 0.3 and COL.green or COL.gold, sw = 3, sa = 1 })
		-- ampoules
		local br = clamp(cs * 0.045, 3, 6.5)
		local k = (outcome and not spinning) and outcome.kind or "idle"
		local winning = not spinning and T - (meter.t0 or 0) < (meter.dur or 0) + 1.2 and k ~= "lose" and k ~= "idle" and k ~= "none"
		for i, b in M.bulbs do
			local on, col
			if k == "jackpot" and winning then
				on, col = true, hsl(C.hue(0) + (i - 1) * 12 + T * 400, 100, 62)
			elseif winning then
				on, col = math.floor(T * 9) % 2 == (i - 1) % 2, hsl(C.hue((i - 1) * 10), 100, 64)
			elseif spinning then
				on, col = ((i - 1) + math.floor(T * 22)) % 3 == 0, hsl(C.hue((i - 1) * 14), 100, 64)
			else
				on, col = ((i - 1) + math.floor(T * 7)) % 4 == 0, hsl(C.hue((i - 1) * 14), 100, 64)
			end
			if on then
				cvBody:circle(b[1], b[2], br * 2.3, col, 0.28)
				cvBody:circle(b[1], b[2], br, WHITE, 1, col, br * 0.55, 1)
			else
				cvBody:circle(b[1], b[2], br, COL.bulbOff, 1)
			end
		end
		-- marquise
		local hx, hy, hw, hh = x + M.pad, y + M.pad, w - M.pad * 2, M.headH
		box(cvBody, hx + hw / 2, hy + hh / 2, hw, hh, { color = COL.head, alpha = 0.85, radius = cs * 0.14, stroke = INK, sw = 3, sa = 1 })
		local ts = math.floor(math.min(hh * 0.5, hw / 8.2) + 0.5)
		otext(cvBody, "CASINO CRUMBLE", x + w / 2, hy + hh * 0.38, ts, WHITE, 1, "center", 0.2, C.rainbowSeq(C.hue(0) + T * 60))
		local st, sc = "MISE TES COOKIES, NO CAP", COL.muted
		if streak >= 5 then
			st, sc = streak .. " W D'AFFILÉE — T'ES EN FEU", COL.gold
		elseif streak >= 2 then
			st, sc = "SÉRIE DE " .. streak .. " W", COL.lime
		elseif streak <= -6 then
			st, sc = "LE CASINO GAGNE TOUJOURS (NO CAP)", COL.red
		elseif streak <= -3 then
			st, sc = (-streak) .. " L D'AFFILÉE… ÇA VA TOURNER", COL.salmon
		end
		local fs = math.floor(clamp(hh * 0.2, 9, 14) + 0.5)
		local tw = C.textWc(st, fs, C.FM)
		if tw > hw - 10 then fs = math.max(7, fs * (hw - 10) / tw) end
		cvBody:ptext(st, x + w / 2, hy + hh * 0.8, fs, sc, 1, "center")
	end
	local function drawSym(cv, sym, x, y, size, blur)
		if sym == "cookie" then
			if blur > 0.05 then
				cv:cookie(x, y - blur * size * 0.3, size * 0.38, 0, { alpha = 0.3 })
				cv:cookie(x, y + blur * size * 0.3, size * 0.38, 0, { alpha = 0.3 })
			end
			cv:cookie(x, y, size * 0.38, 0)
			return
		end
		local key = ART[sym]
		if blur > 0.05 then
			local stt = 1 + blur * 0.35
			if cv:img(key, x, y - blur * size * 0.32, size, size * stt, 0, nil, 0.28) then
				cv:img(key, x, y + blur * size * 0.32, size, size * stt, 0, nil, 0.28)
				cv:img(key, x, y, size, size * stt, 0, nil, 0.9)
				return
			end
		end
		cv:icon(key, x, y, size)
	end
	local function drawReels(T)
		local cs, winH, reelY = M.cs, M.winH, M.reelY
		local mid = reelY + winH / 2
		for i = 1, 3 do
			local r, R = reels[i], reelF[i]
			local rx = reelX(i)
			local blur = 0
			if r.state == "spin" then
				blur = clamp(math.abs(r.v) / VMAX, 0, 1)
			elseif r.state == "stop" then
				blur = clamp(1 - (T - r.t0) / r.dur, 0, 1) * 0.6
			end
			local cv = R.cv
			cv:begin()
			local base = math.floor(r.off)
			for k = -2, 2 do
				local idx = base + k
				local yy = winH / 2 + (r.off - idx) * cs
				if yy >= -cs and yy <= winH + cs then
					local sym = symAt(r, idx)
					local isRes = not spinning and r.state == "idle" and idx == math.floor(r.off + 0.5)
					local sz = cs * 0.8
					if isRes and hasHit(outcome, i) and fx.hitGlow > 0 then sz *= 1 + math.sin(T * 12) * 0.06 * fx.hitGlow end
					if isRes and r.land > 0 then sz *= 1 + r.land * 0.12 end
					drawSym(cv, sym, cs / 2, yy, sz, blur)
				end
			end
			cv:finish()
			-- reflet qui balaie la vitre
			local sw = ((T * 0.35 + (i - 1) * 0.12) % 1.6) - 0.3
			R.shine.Position = UDim2.fromOffset(sw * cs * 1.6, 0)
			-- cadre, suspense, gain
			box(cvTop, rx + cs / 2, mid, cs, winH, { color = false, radius = cs * 0.14, stroke = INK, sw = 4, sa = 1 })
			if i == 3 and anticip then
				box(cvTop, rx + cs / 2, mid, cs, winH, { color = false, radius = cs * 0.14, stroke = hsl(C.hue(0) + T * 300, 100, 60), sw = 6, sa = 0.6 + math.sin(T * 18) * 0.4 })
			end
			if not spinning and hasHit(outcome, i) and fx.hitGlow > 0 then
				local col = outcome.kind == "jackpot" and hsl(C.hue((i - 1) * 40) + T * 200, 100, 60) or COL.gold
				box(cvTop, rx + cs / 2, mid, cs - 6, cs, { color = false, radius = cs * 0.12, stroke = col, sw = 5, sa = math.min(1, fx.hitGlow * 1.5) })
			end
		end
		-- ligne de paiement pointillée + flèches
		local px0, px1 = M.x + M.pad * 0.35, M.x + M.w - M.pad * 0.35
		local lit = not spinning and outcome and outcome.mult > 0 and fx.hitGlow > 0
		local x = px0 + 10
		local n = 0
		while x < px1 - 10 do
			local seg = math.min(8, px1 - 10 - x)
			local col = lit and hsl(C.hue(0) + T * 200 + (x - px0) / (px1 - px0) * 330, 100, 64) or COL.pink
			cvTop:rect(x + seg / 2, mid, seg, 3, col, lit and 0.9 or 0.68)
			x += 14
			n += 1
		end
		local tri = texTri()
		if tri then
			cvTop:pimg("tri", tri, px0 + 6, mid, 14, 18, 0)
			cvTop:pimg("tri", tri, px1 - 6, mid, 14, 18, 180)
		end
	end
	local function drawMeter(T)
		local cs = M.cs
		local x, w, y, h = M.x + M.pad, M.w - M.pad * 2, M.meterY, M.meterH
		box(cvTop, x + w / 2, y + h / 2, w, h, { color = COL.meterBg, alpha = 1, radius = h * 0.35, stroke = INK, sw = 3, sa = 1 })
		box(cvTop, x + w / 2, y + h / 2, w - 6, h - 6, { color = false, radius = h * 0.3, stroke = COL.gold, sw = 1.5, sa = 0.35 })
		local ls = math.floor(clamp(h * 0.3, 9, 14) + 0.5)
		if cs >= 72 then
			local lc = meter.kind == "lose" and COL.salmon or COL.muted
			cvTop:ptext(meter.label, x + h * 0.4, y + h / 2 + 1, ls, lc, 1, "left")
		end
		local k = clamp((T - meter.t0) / meter.dur, 0, 1)
		local vs = math.floor(clamp(h * 0.56, 14, 30) + 0.5)
		local txt, col, grad = nil, WHITE, nil
		if meter.kind == "idle" then
			txt, col = coarse and "TAPE SPIN" or "ESPACE / LEVIER", hex("#6a5ca0")
		elseif meter.kind == "spin" then
			txt, col = DOTS[1 + math.floor(T * 6) % 5], hex("#6a5ca0")
		elseif meter.to > 0 then
			txt = "+" .. ctx.fmt(math.floor(meter.to * easeOut3(k) + 0.5))
			col = COL.gold
			if meter.kind == "jackpot" then grad = C.rainbowSeq(C.hue(0) + T * 200) end
		else
			txt = "0"
		end
		local iconS = vs * 1.05
		local hasIcon = meter.to > 0
		local tx = x + w - h * 0.4 - (hasIcon and iconS + 4 or 0)
		otext(cvTop, txt, tx, y + h / 2 + 1, vs, col, 1, "right", 0.18, grad)
		if hasIcon then cvTop:icon("ui:cookie", x + w - h * 0.4 - iconS / 2, y + h / 2, iconS) end
	end
	local function drawLever(T)
		if not M.lever then return end
		local cs = M.cs
		local bx, by = M.lx, M.ly
		box(cvTop, bx - cs * 0.06, by, cs * 0.28, cs * 0.48, { color = COL.lever, alpha = 1, radius = cs * 0.08, stroke = INK, sw = 4, sa = 1 })
		cvTop:rect(bx - cs * 0.06, by, cs * 0.28, cs * 0.08, COL.gold, 1)
		local a0, a1 = -math.pi / 2 + 0.12, math.pi / 2 - 0.25
		local ang = a0 + (a1 - a0) * leverPull
		local L = cs * 1.15
		local ex, ey = bx + math.cos(ang) * L * 0.55, by + math.sin(ang) * L
		cvTop:line(bx, by, ex, ey, cs * 0.11, INK, 1, true)
		cvTop:line(bx, by, ex, ey, cs * 0.06, COL.stick, 1, true)
		local br = cs * 0.15
		cvTop:circle(ex, ey, br, COL.ball, 1, INK, 3.5, 1)
		cvTop:glow(ex - br * 0.35, ey - br * 0.35, br * 0.6, hex("#ffb3c1"), 0.9, 0.2)
		if not spinning and os.clock() > lockUntil then
			cvTop:ring(ex, ey, br * 1.5, 3, WHITE, 0.35 + 0.35 * math.sin(T * 5))
		end
	end
	local function drawParts()
		for _, p in parts do
			local a = math.min(1, (1 - p.age / p.life) * 2.5)
			if p.k == "coin" then
				local sx = math.max(0.15, math.abs(math.cos(p.spin)))
				cvFx:circle(p.x, p.y, p.sz, COL.coinD, a, INK, 2, a, p.sz * sx)
				cvFx:circle(p.x, p.y, p.sz * 0.78, COL.gold, a, nil, nil, nil, p.sz * 0.78 * sx)
				cvFx:rect(p.x, p.y, p.sz * 0.24 * sx, p.sz * 0.9, COL.coinL, a)
			elseif p.k == "cookie" then
				cvFx:cookie(p.x, p.y, p.sz * 1.1, p.spin, { alpha = a })
			elseif p.k == "gem" then
				cvFx:icon("ui:gem", p.x, p.y, p.sz * 2.4, math.deg(math.sin(p.spin) * 0.4), a)
			elseif p.k == "conf" then
				cvFx:rect(p.x, p.y, p.sz, p.sz * 0.6 * math.abs(math.cos(p.spin * 1.7)) + 1, p.col, a, math.deg(p.spin))
			else
				cvFx:line(p.x, p.y, p.x - p.vx * 0.03, p.y - p.vy * 0.03, p.sz, p.col, a, true)
			end
		end
		for _, r in rings do
			if r.age >= 0 then
				local k = r.age / r.life
				cvFx:ring(r.x, r.y, r.max * easeOut3(k), 14 * (1 - k) + 2, hsl(C.hue(r.h) + k * 120, 100, 62), 1 - k)
			end
		end
	end
	local function drawHero(T)
		if fx.hero <= 0 then return end
		local a = math.min(1, fx.hero / 0.5)
		local age = ((outcome and outcome.kind == "jackpot") and 4 or 2.6) - fx.hero
		local s = easeBack(clamp(age / 0.6, 0, 1), 1.6)
		local R = math.min(W, H) * 0.2 * s
		local cx, cy = W / 2, M.reelY + M.winH / 2 - R * 0.15
		cvFx:glow(cx, cy, R * 2, hsl(C.hue(0), 100, 65), 0.6 * a, 0.25)
		if R > 2 then cvFx:cookie(cx, cy, R, math.sin(T * 5) * 0.3, { acc = true, squash = math.max(0, math.sin(T * 10)) * 0.2, alpha = a }) end
	end
	local function drawBig(T)
		local b = fx.big
		if not b then return end
		local age = T - b.t0
		local out = b.dur - age
		local cx, cy = W / 2, M.reelY + M.winH / 2
		local pop = easeBack(clamp(age / 0.35, 0, 1), 2)
		local alpha = clamp(out / 0.35, 0, 1)
		if b.style == "jackpot" then
			local sz = math.floor(math.min(W * 0.17, 120) * pop + 0.5)
			if sz < 2 then return end
			local letters = {}
			for _, ch in utf8.codes(b.text) do table.insert(letters, utf8.char(ch)) end
			local widths, tw = {}, 0
			for i, ch in letters do
				widths[i] = C.textWc(ch, sz, C.FD)
				tw += widths[i]
			end
			local x = cx - tw / 2
			for i, ch in letters do
				local yy = cy + math.sin(T * 9 + (i - 1) * 0.7) * sz * 0.08
				otext(cvFx, ch, x + widths[i] / 2, yy, sz, hsl(C.hue((i - 1) * 40) + T * 360, 100, 62), alpha)
				x += widths[i]
			end
			if b.sub ~= "" then otext(cvFx, b.sub, cx, cy + sz * 0.75, math.floor(sz * 0.3 + 0.5), WHITE, alpha) end
		elseif b.style == "small" or b.style == "deny" then
			local deny = b.style == "deny"
			local sz = math.floor(math.min(W * (deny and 0.075 or 0.1), deny and 40 or 60) * pop + 0.5)
			local yy = deny and cy or M.reelY - sz * 0.1 - age * 12
			if b.col == "rgb" then
				otext(cvFx, b.text, cx, yy, sz, WHITE, alpha, "center", 0.2, C.rainbowSeq(C.hue(0) + T * 300))
			else
				otext(cvFx, b.text, cx, yy, sz, b.col, alpha)
			end
			if b.sub ~= "" then otext(cvFx, b.sub, cx, yy + sz * 0.78, math.floor(sz * 0.42 + 0.5), WHITE, alpha) end
		else
			local sz = math.floor(math.min(W * 0.13, 88) * pop + 0.5)
			if b.col == "rgb" then
				otext(cvFx, b.text, cx, cy, sz, WHITE, alpha, "center", 0.2, C.rainbowSeq(C.hue(0) + T * 300))
			else
				otext(cvFx, b.text, cx, cy, sz, b.col, alpha)
			end
			if b.sub ~= "" then otext(cvFx, b.sub, cx, cy + sz * 0.72, math.floor(sz * 0.32 + 0.5), WHITE, alpha) end
		end
	end
	local DENY_X = { 0, -7, 7, -5, 4, 0 }
	local function denyOffset(T)
		local k = (T - fx.denyT) / 0.38
		if k < 0 or k >= 1 then return 0 end
		local f = k * 5
		local i = math.floor(f)
		return DENY_X[i + 1] + (DENY_X[i + 2] - DENY_X[i + 1]) * (f - i)
	end
	local function render(T)
		cvBg:begin()
		drawBg(T)
		cvBg:finish()
		-- secousse + rebond de la machine à l'arrêt d'un rouleau
		local ox, oy = 0, 0
		if fx.shake > 0 then ox, oy = rand(-fx.shake, fx.shake), rand(-fx.shake, fx.shake) end
		oy += math.sin(fx.bounce * math.pi) * M.cs * 0.03
		mach.Position = UDim2.fromOffset(ox, oy)
		cvBody:begin()
		drawMachine(T)
		cvBody:finish()
		cvTop:begin()
		drawReels(T)
		drawMeter(T)
		drawLever(T)
		cvTop:finish()
		cvFx:begin()
		drawHero(T)
		drawParts()
		drawBig(T)
		if fx.tint > 0 then cvFx:rectTL(0, 0, W, H, fx.tintCol, fx.tint * 0.28) end
		if fx.flash > 0 then cvFx:rectTL(0, 0, W, H, fx.flashCol, fx.flash) end
		cvFx:finish()
		-- DOM : banque (bump), secousse du refus, bouton SPIN grisé
		bankScale.Scale = os.clock() - bankBumpT < 0.14 and 1.14 or 1
		local dx = denyOffset(T)
		betLine.Position = UDim2.fromOffset(bottom.Size.X.Offset / 2 + dx, 0)
		spinBtn.body.Position = UDim2.fromOffset(dx, spinBtn.body.Position.Y.Offset)
		spinBtn.setOff(spinning or T < lockUntil)
		for _, c in histChips do
			local k = clamp((T - c.t0) / 0.35, 0, 1)
			if k < 1 or c.sc.Scale ~= 1 then c.sc.Scale = 0.2 + 0.8 * easeBack(k, 2.4) end
		end
	end

	----------------------------------------------------------------------- boucle
	local domT = 0
	local function resize()
		local s = root.AbsoluteSize
		local w, h = math.max(240, math.floor(s.X + 0.5)), math.max(300, math.floor(s.Y + 0.5))
		if w == W and h == H then return end
		W, H = w, h
		layout()
	end
	bag.add(RunService.RenderStepped:Connect(function(dt)
		if destroyed then return end
		if not (dt > 0) then dt = 0 end
		if dt > 0.05 then dt = 0.05 end
		local T = os.clock()
		resize()
		update(dt, T)
		render(T)
		if T - domT > 0.2 then
			domT = T
			refreshBet()
			hist.Size = UDim2.new(1, -(bankHolder.Size.X.Offset + 12), 0, 34)
		end
	end))

	----------------------------------------------------------------------- entrées
	bag.add(hit.InputBegan:Connect(function(input)
		local ut = input.UserInputType
		if ut ~= Enum.UserInputType.MouseButton1 and ut ~= Enum.UserInputType.Touch then return end
		local x, y = C.inputXY(input, root)
		local onMachine = x >= M.x and x <= M.x + M.w and y >= M.y and y <= M.y + M.h
		local onLever = M.lever and math.abs(x - M.lx) < M.cs * 0.4 and y > M.ly - M.cs * 1.4 and y < M.ly + M.cs * 0.4
		if onMachine or onLever then spin() end
	end))
	local BET_KEYS = {
		[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.KeypadOne] = 1, [Enum.KeyCode.KeypadTwo] = 2, [Enum.KeyCode.KeypadThree] = 3,
	}
	-- Espace / Entrée = SPIN, 1 2 3 = mise (captés : pas de saut / d'outil de l'avatar)
	CAS:BindActionAtPriority("CookieSlotsKeys", function(_, state, input)
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
		local k = input.KeyCode
		if k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter then
			spin()
		elseif BET_KEYS[k] then
			setBet(BET_KEYS[k])
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter,
		Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.KeypadOne, Enum.KeyCode.KeypadTwo, Enum.KeyCode.KeypadThree)
	bag.add(function() CAS:UnbindAction("CookieSlotsKeys") end)

	resize()
	refreshBet()

	return {
		destroy = function()
			if destroyed then return end
			destroyed = true
			-- un tirage en cours est déjà payé par le serveur : rien à rendre ici
			bag.clean()
			table.clear(parts)
			table.clear(rings)
			cvBg:destroy()
			cvBody:destroy()
			cvTop:destroy()
			cvFx:destroy()
			for _, R in reelF do R.cv:destroy() end
		end,
	}
end

return Slots
