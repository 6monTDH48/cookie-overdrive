--!nonstrict
-- COOKIE OVERDRIVE — mini-jeux : briques communes.
-- Couleurs / polices du site, maths, textures procédurales (EditableImage), un petit moteur de
-- dessin « immédiat » (Canvas : chaque frame on redessine avec des objets GUI recyclés, comme le
-- <canvas> du site), les boutons « .btn » de base.css, l'écran d'accueil et la carte de résultats
-- communs à Cookie Ninja et Flappy Cookie.
local TextService = game:GetService("TextService")
local AssetService = game:GetService("AssetService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = {}

----------------------------------------------------------------------------- Img (module partagé)
local Img
do
	local mod = script.Parent.Parent:FindFirstChild("Img")
	local ok, res = false, nil
	if mod and mod:IsA("ModuleScript") then ok, res = pcall(require, mod) end
	if ok and type(res) == "table" then
		Img = res
	else
		Img = {
			has = function() return false end,
			size = function() return Vector2.new(0, 0) end,
			set = function() return false end,
			preload = function() end,
		}
	end
end
C.Img = Img

function C.has(key)
	local ok, r = pcall(Img.has, key)
	return ok and r == true
end

-- taille en pixels d'une image (mise en cache ; 640² par défaut pour les cookies/accessoires)
local sizeCache = {}
function C.imgSize(key)
	local v = sizeCache[key]
	if v then return v end
	local ok, r = pcall(Img.size, key)
	if ok and typeof(r) == "Vector2" and r.X > 0 then
		v = r
	else
		v = Vector2.new(640, 640)
	end
	sizeCache[key] = v
	return v
end

-- Img.set avec cache de la clé courante par objet (évite les re-set inutiles)
local curKey = setmetatable({}, { __mode = "k" })
function C.setImg(label, key)
	if curKey[label] == key then return true end
	local ok, r = pcall(Img.set, label, key)
	if ok and r then
		curKey[label] = key
		return true
	end
	return false
end

----------------------------------------------------------------------------- couleurs & polices
local function hex(s) return Color3.fromHex(s) end
C.hex = hex
C.col = {
	bg = hex("#0b0620"), ink = hex("#fff6fe"), muted = hex("#b3a6dd"), dim = hex("#7d6fae"),
	stroke = hex("#1a0b33"), hot = hex("#ff2bd6"), cyan = hex("#1ff4ff"), lime = hex("#b6ff3b"),
	gold = hex("#ffc93c"), red = hex("#ff4d6d"), violet = hex("#8a5cff"), green = hex("#2bdc6a"),
	orange = hex("#ff8a1f"), white = Color3.new(1, 1, 1), black = Color3.new(0, 0, 0),
}
local INK = C.col.stroke
C.INK = INK

C.FD = Font.new("rbxasset://fonts/families/FredokaOne.json") -- display (Lilita One sur le site)
C.FB = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold) -- corps (Fredoka)
C.FS = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.SemiBold)
C.FM = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Bold) -- chiffres (Chakra Petch)
local LEGACY = { [C.FD] = Enum.Font.FredokaOne, [C.FB] = Enum.Font.Nunito, [C.FS] = Enum.Font.Nunito, [C.FM] = Enum.Font.Sarpanch }

-- largeur d'un texte (mise en page des boutons / pastilles)
function C.textW(text, size, font)
	local ok, v = pcall(TextService.GetTextSize, TextService, text, math.min(100, size), LEGACY[font or C.FD] or Enum.Font.FredokaOne, Vector2.new(4000, 1000))
	if ok and v then return v.X * (size > 100 and size / 100 or 1) end
	return #text * size * 0.55
end

-- largeur mise en cache (mesurée une fois à 100 px puis mise à l'échelle)
local wCache = {}
function C.textWc(text, size, font)
	font = font or C.FD
	local key = text
	local byFont = wCache[font]
	if not byFont then
		byFont = {}
		wCache[font] = byFont
	end
	local w = byFont[key]
	if not w then
		w = C.textW(text, 100, font)
		byFont[key] = w
	end
	return w * size / 100
end

----------------------------------------------------------------------------- maths
C.TAU = math.pi * 2
function C.clamp(v, a, b) return v < a and a or (v > b and b or v) end
function C.lerp(a, b, t) return a + (b - a) * t end
function C.rand(a, b) return a + math.random() * (b - a) end
function C.pick(t) return t[math.random(#t)] end
function C.easeOutBack(t, c1)
	c1 = c1 or 1.70158
	local c3 = c1 + 1
	t -= 1
	return 1 + c3 * t * t * t + c1 * t * t
end
function C.easeOutCubic(t) return 1 - (1 - t) ^ 3 end
-- segment coupé au rectangle [x0,x1]×[y0,y1] (Liang-Barsky) ; nil s'il est dehors
function C.clipSeg(ax, ay, bx, by, x0, y0, x1, y1)
	local dx, dy = bx - ax, by - ay
	local t0, t1 = 0, 1
	local p = { -dx, dx, -dy, dy }
	local q = { ax - x0, x1 - ax, ay - y0, y1 - ay }
	for i = 1, 4 do
		if p[i] == 0 then
			if q[i] < 0 then return nil end
		else
			local r = q[i] / p[i]
			if p[i] < 0 then
				if r > t1 then return nil end
				if r > t0 then t0 = r end
			else
				if r < t0 then return nil end
				if r < t1 then t1 = r end
			end
		end
	end
	return ax + dx * t0, ay + dy * t0, ax + dx * t1, ay + dy * t1
end

-- teinte RGB globale du site : 60°/s
function C.hue(o) return (os.clock() * 60 + (o or 0)) % 360 end

function C.hsl(h, s, l)
	h = (h % 360) / 360
	s = s / 100
	l = l / 100
	if s <= 0 then return Color3.new(l, l, l) end
	local q = l < 0.5 and l * (1 + s) or l + s - l * s
	local p = 2 * l - q
	local function f(t)
		t %= 1
		if t < 1 / 6 then return p + (q - p) * 6 * t end
		if t < 0.5 then return q end
		if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
		return p
	end
	return Color3.new(f(h + 1 / 3), f(h), f(h - 1 / 3))
end

-- dégradé arc-en-ciel du site : rainbow(ctx, x0, x1, h) = 7 arrêts hsl(h + i*55, 100, 64)
function C.rainbowSeq(h, l)
	local k = {}
	for i = 0, 6 do k[i + 1] = ColorSequenceKeypoint.new(i / 6, C.hsl(h + i * 55, 100, l or 64)) end
	return ColorSequence.new(k)
end
-- dégradé RGB fixe (--rgb de base.css)
C.RGB_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0, hex("#ff004c")), ColorSequenceKeypoint.new(1 / 7, hex("#ff8a00")),
	ColorSequenceKeypoint.new(2 / 7, hex("#ffe600")), ColorSequenceKeypoint.new(3 / 7, hex("#2bff88")),
	ColorSequenceKeypoint.new(4 / 7, hex("#00d5ff")), ColorSequenceKeypoint.new(5 / 7, hex("#7a5cff")),
	ColorSequenceKeypoint.new(6 / 7, hex("#ff2bd6")), ColorSequenceKeypoint.new(1, hex("#ff004c")),
})
function C.seq(list) -- { {t, Color3}, ... }
	local k = {}
	for i, v in list do k[i] = ColorSequenceKeypoint.new(v[1], v[2]) end
	return ColorSequence.new(k)
end
function C.nseq(list) -- { {t, transparency}, ... }
	local k = {}
	for i, v in list do k[i] = NumberSequenceKeypoint.new(v[1], v[2]) end
	return NumberSequence.new(k)
end

----------------------------------------------------------------------------- instances
function C.new(class, props, children)
	local o = Instance.new(class)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then parent = v else o[k] = v end
		end
	end
	if children then
		for _, c in children do c.Parent = o end
	end
	if parent then o.Parent = parent end
	return o
end
local new = C.new

function C.corner(r) return new("UICorner", { CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 12) }) end
function C.stroke(color, th, tr)
	return new("UIStroke", { Color = color or INK, Thickness = th or 3, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
function C.tstroke(color, th, tr)
	return new("UIStroke", { Color = color or INK, Thickness = th or 2, Transparency = tr or 0, LineJoinMode = Enum.LineJoinMode.Round })
end

-- sac de connexions : tout est déconnecté à la fermeture
function C.bag()
	local b = { list = {} }
	function b.add(c)
		table.insert(b.list, c)
		return c
	end
	function b.clean()
		for _, c in b.list do
			if typeof(c) == "RBXScriptConnection" then c:Disconnect() elseif typeof(c) == "Instance" then c:Destroy() elseif type(c) == "function" then pcall(c) end
		end
		table.clear(b.list)
	end
	return b
end

-- position d'une entrée (souris / doigt) dans le repère d'un cadre. InputObject.Position ne compte
-- pas la barre du haut de Roblox, nos ScreenGui l'ignorent (IgnoreGuiInset) : on la rajoute.
function C.inputXY(input, frame)
	local p = input.Position
	local ok, tl = pcall(function() return (GuiService:GetGuiInset()) end)
	local ix, iy = 0, 0
	if ok and typeof(tl) == "Vector2" then ix, iy = tl.X, tl.Y end
	local a = frame.AbsolutePosition
	return p.X + ix - a.X, p.Y + iy - a.Y
end

-- l'appareil est-il tactile sans clavier (« pointer: coarse » du site)
function C.coarse()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

----------------------------------------------------------------------------- sons (optionnels)
-- Le site synthétise ses sons en WebAudio. Roblox ne peut pas : renseigner ici des ids de sons
-- uploadés (ex. "rbxassetid://123") pour les activer. Vide = silencieux (aucun chargement raté).
C.SOUNDS = {
	-- tick = "", pop = "", slice = "", combo = "", golden = "", hit = "", miss = "", error = "",
	-- whoosh = "", perfect = "", good = "", win = "", lose = "", coin = "", jump = "", levelup = "",
	-- achievement = "", fever = "", spin = "", reel = "", jackpot = "", click = "",
}
local sndPool = {}
function C.sfx(name, o)
	local id = C.SOUNDS[name]
	if not id or id == "" then return end
	local list = sndPool[name]
	if not list then
		list = { i = 0 }
		for i = 1, 3 do list[i] = new("Sound", { SoundId = id, Volume = 0.5, Parent = SoundService }) end
		sndPool[name] = list
	end
	list.i = list.i % 3 + 1
	local s = list[list.i]
	s.PlaybackSpeed = (o and o.pitch) or 1
	s.Volume = 0.5 * ((o and o.vol) or 1)
	s:Play()
end

----------------------------------------------------------------------------- textures procédurales
-- Formes que le GUI Roblox ne sait pas dessiner (triangles, trapèzes, rayons…) : rendues une fois
-- dans une EditableImage. Renvoie nil si l'API est indisponible (les appelants ont un repli).
local procCache = {}
function C.proc(name, w, h, fill)
	local c = procCache[name]
	if c ~= nil then return c or nil end
	local ok, ei = pcall(function() return AssetService:CreateEditableImage({ Size = Vector2.new(w, h) }) end)
	if not ok or not ei then
		procCache[name] = false
		return nil
	end
	local buf = buffer.create(w * h * 4)
	local okFill = pcall(fill, buf, w, h)
	local okW = okFill and pcall(function() ei:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), buf) end)
	if not okW then
		procCache[name] = false
		pcall(function() ei:Destroy() end)
		return nil
	end
	procCache[name] = ei
	return ei
end
-- EditableImage non mise en cache (textures aléatoires : villes de Flappy…) ; à détruire soi-même
function C.procNew(w, h, fill)
	w = math.clamp(math.floor(w), 1, 1024)
	h = math.clamp(math.floor(h), 1, 1024)
	local ok, ei = pcall(function() return AssetService:CreateEditableImage({ Size = Vector2.new(w, h) }) end)
	if not ok or not ei then return nil end
	local buf = buffer.create(w * h * 4)
	local okFill = pcall(fill, buf, w, h)
	local okW = okFill and pcall(function() ei:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), buf) end)
	if not okW then
		pcall(function() ei:Destroy() end)
		return nil
	end
	return ei
end
function C.procDrop(name)
	local c = procCache[name]
	if c then pcall(function() c:Destroy() end) end
	procCache[name] = nil
end
function C.applyProc(label, ei)
	if not ei then return false end
	return (pcall(function() label.ImageContent = Content.fromObject(ei) end))
end

local function px(buf, w, x, y, r, g, b, a)
	local o = (y * w + x) * 4
	buffer.writeu8(buf, o, r)
	buffer.writeu8(buf, o + 1, g)
	buffer.writeu8(buf, o + 2, b)
	buffer.writeu8(buf, o + 3, a)
end
C.px = px

-- rayon : sommet au centre, ouvert vers +x, demi-angle a (degrés), jusqu'au bord
function C.texWedge(deg)
	deg = math.floor(deg * 2 + 0.5) / 2
	return C.proc("wedge" .. deg, 128, 128, function(buf, w, h)
		local a = math.rad(deg / 2)
		local ca, sa = math.cos(a), math.sin(a)
		local R = w / 2
		for y = 0, h - 1 do
			local py = y + 0.5 - R
			for x = 0, w - 1 do
				local pxx = x + 0.5 - R
				local d1 = py * ca - pxx * sa
				local d2 = -py * ca - pxx * sa
				local d = math.max(d1, d2)
				local al = C.clamp(0.5 - d, 0, 1)
				if al > 0 and pxx > -1 then
					local r = math.sqrt(pxx * pxx + py * py)
					al *= C.clamp(R - r + 0.5, 0, 1)
					px(buf, w, x, y, 255, 255, 255, math.floor(al * 255))
				end
			end
		end
	end)
end

-- trapèze plein : largeur 100 % en haut, `ratio` en bas (verres de lait, autoroute du rythme)
function C.texTrap(ratio)
	ratio = math.floor(ratio * 50 + 0.5) / 50
	return C.proc("trap" .. ratio, 64, 128, function(buf, w, h)
		local cx = w / 2
		for y = 0, h - 1 do
			local hw = cx * C.lerp(1, ratio, (y + 0.5) / h)
			for x = 0, w - 1 do
				local d = math.abs(x + 0.5 - cx)
				local al = C.clamp(hw - d + 0.5, 0, 1)
				if al > 0 then px(buf, w, x, y, 255, 255, 255, math.floor(al * 255)) end
			end
		end
	end)
end
-- côtés d'un trapèze (contour sans haut ni bas) ; t = épaisseur relative à la largeur du haut.
-- La texture a une marge : largeur totale = 64 * (1 + t) ; zone utile = 64 px au milieu.
function C.texTrapEdge(ratio, t)
	ratio = math.floor(ratio * 50 + 0.5) / 50
	t = math.floor(t * 100 + 0.5) / 100
	local W = math.floor(64 * (1 + t) + 0.5)
	W += W % 2
	return C.proc("trapE" .. ratio .. "_" .. t, W, 128, function(buf, w, h)
		local cx = w / 2
		local half = 64 * t / 2
		for y = 0, h - 1 do
			local hw = 32 * C.lerp(1, ratio, (y + 0.5) / h)
			for x = 0, w - 1 do
				local d = math.abs(math.abs(x + 0.5 - cx) - hw)
				local al = C.clamp(half - d + 0.5, 0, 1)
				if al > 0 then px(buf, w, x, y, 255, 255, 255, math.floor(al * 255)) end
			end
		end
	end), W / 64
end

-- halo radial linéaire (glow() du site : couleur pleine au centre → 0 au rayon) ; inner = part pleine
function C.texGlow(inner)
	inner = math.floor((inner or 0) * 20 + 0.5) / 20
	return C.proc("glow" .. inner, 64, 64, function(buf, w, h)
		local R = w / 2
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				local dx, dy = x + 0.5 - R, y + 0.5 - R
				local d = math.sqrt(dx * dx + dy * dy) / R
				local al = d <= inner and 1 or C.clamp(1 - (d - inner) / (1 - inner), 0, 1)
				if al > 0 then px(buf, w, x, y, 255, 255, 255, math.floor(al * 255)) end
			end
		end
	end)
end

-- polygone plein + contour (pour l'aile de Flappy, la pépite…) : pts en pixels de texture
local function segDist(px0, py0, ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay
	local l2 = dx * dx + dy * dy
	local t = l2 > 0 and C.clamp(((px0 - ax) * dx + (py0 - ay) * dy) / l2, 0, 1) or 0
	local qx, qy = ax + dx * t - px0, ay + dy * t - py0
	return math.sqrt(qx * qx + qy * qy)
end
function C.rasterPoly(buf, w, h, pts, fill, stroke, sw, lines)
	-- fill = {r,g,b} ou fonction(x, y) -> r,g,b ; stroke = {r,g,b} ; lines = segments intérieurs {x1,y1,x2,y2,w,a}
	local n = #pts
	for y = 0, h - 1 do
		local cy = y + 0.5
		for x = 0, w - 1 do
			local cx = x + 0.5
			local inside = false
			local dmin = 1e9
			local j = n
			for i = 1, n do
				local xi, yi, xj, yj = pts[i][1], pts[i][2], pts[j][1], pts[j][2]
				if (yi > cy) ~= (yj > cy) and cx < (xj - xi) * (cy - yi) / (yj - yi) + xi then inside = not inside end
				local d = segDist(cx, cy, xi, yi, xj, yj)
				if d < dmin then dmin = d end
				j = i
			end
			local fa = inside and C.clamp(dmin + 0.5, 0, 1) or 0
			local sa = stroke and C.clamp(sw / 2 - dmin + 0.5, 0, 1) or 0
			if fa > 0 or sa > 0 then
				local r, g, b
				if type(fill) == "function" then r, g, b = fill(cx, cy) else r, g, b = fill[1], fill[2], fill[3] end
				if lines and inside then
					for _, L in lines do
						local d = segDist(cx, cy, L[1], L[2], L[3], L[4])
						local la = C.clamp(L[5] / 2 - d + 0.5, 0, 1) * L[6]
						if la > 0 then
							r = r + (stroke[1] - r) * la
							g = g + (stroke[2] - g) * la
							b = b + (stroke[3] - b) * la
						end
					end
				end
				-- contour par-dessus le remplissage
				local a = math.max(fa, sa)
				if sa > 0 then
					local k = sa / a
					r = r + (stroke[1] - r) * k
					g = g + (stroke[2] - g) * k
					b = b + (stroke[3] - b) * k
				end
				px(buf, w, x, y, math.floor(r), math.floor(g), math.floor(b), math.floor(a * 255))
			end
		end
	end
end
-- aplatit une suite de commandes {"M",x,y} {"Q",cx,cy,x,y} {"C",c1x,c1y,c2x,c2y,x,y} {"L",x,y}
function C.flatten(cmds, steps)
	steps = steps or 8
	local pts = {}
	local lx, ly = 0, 0
	for _, c in cmds do
		if c[1] == "M" or c[1] == "L" then
			lx, ly = c[2], c[3]
			table.insert(pts, { lx, ly })
		elseif c[1] == "Q" then
			for i = 1, steps do
				local t = i / steps
				local u = 1 - t
				table.insert(pts, { u * u * lx + 2 * u * t * c[2] + t * t * c[4], u * u * ly + 2 * u * t * c[3] + t * t * c[5] })
			end
			lx, ly = c[4], c[5]
		elseif c[1] == "C" then
			for i = 1, steps do
				local t = i / steps
				local u = 1 - t
				table.insert(pts, {
					u * u * u * lx + 3 * u * u * t * c[2] + 3 * u * t * t * c[4] + t * t * t * c[6],
					u * u * u * ly + 3 * u * u * t * c[3] + 3 * u * t * t * c[5] + t * t * t * c[7],
				})
			end
			lx, ly = c[6], c[7]
		end
	end
	return pts
end

----------------------------------------------------------------------------- emoji de secours
C.EMOJI = {
	["ui:cookie"] = "🍪", ["ui:gem"] = "💎", ["ui:star"] = "⭐", ["ui:trophy"] = "🏆", ["ui:play"] = "▶",
	["ui:fire"] = "🔥", ["ui:sword"] = "🗡️", ["ui:golden"] = "🌟", ["ui:tap"] = "👆", ["ui:skull"] = "💀",
	["ui:music"] = "🎵", ["ui:bolt"] = "⚡", ["ui:sparkle"] = "✨", ["ui:gift"] = "🎁", ["ui:close"] = "✖",
	["ui:warning"] = "⚠️", ["ui:heart"] = "❤️", ["ui:heart_empty"] = "🤍", ["ui:clock"] = "⏱️",
	["item:broccoli"] = "🥦", ["item:milk"] = "🥛", ["item:choco"] = "🍫", ["item:seven"] = "7️⃣",
	["item:donut"] = "🍩", ["item:cupcake"] = "🧁", ["mg:ninja"] = "🥷", ["mg:flappy"] = "🐤",
	["mg:rhythm"] = "🎵", ["mg:slots"] = "🎰", ["golden"] = "🌟",
}

-- icône « retenue » (menus, pastilles) : ImageLabel si l'art existe, sinon emoji
function C.icon(parent, key, size, props)
	local l = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), ScaleType = Enum.ScaleType.Fit, Parent = parent })
	if props then for k, v in props do l[k] = v end end
	if not C.setImg(l, key) then
		new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = C.EMOJI[key] or "•", TextScaled = true,
			FontFace = C.FB, TextColor3 = C.col.white, ZIndex = l.ZIndex, Parent = l,
		})
	end
	return l
end

----------------------------------------------------------------------------- joueur (skin + accessoires)
-- rempli par Minigames depuis la synchro serveur
C.player = { skin = "classic", vis = {} }

local BODY_KEYS = { "chips_xl", "crystals", "galaxy_core" }
local TOP_KEYS = { "glaze", "sprinkles", "holo", "rgb_rim", "face", "laser_eyes", "shades", "headphones", "bling", "crown", "halo" }
local function accKey(k, lvl, skin)
	if k == "chips_xl" and skin ~= "classic" and C.has("acc:chips_xl_" .. skin) then return "acc:chips_xl_" .. skin end
	if (k == "holo" or k == "rgb_rim") and skin == "diamond" and C.has("acc:" .. k .. "_diamond") then return "acc:" .. k .. "_diamond" end
	if type(lvl) == "number" and lvl >= 2 and C.has("acc:" .. k .. "_" .. math.floor(lvl)) then return "acc:" .. k .. "_" .. math.floor(lvl) end
	if C.has("acc:" .. k) then return "acc:" .. k end
	return nil
end
local accCache = { sig = nil, back = {}, front = {} }
-- clés des calques d'accessoires : back = derrière le cookie (ailes), front = corps puis dessus
function C.accLayers()
	local p = C.player
	local sig = tostring(p.skin)
	for k, v in p.vis or {} do sig ..= "|" .. tostring(k) .. "=" .. tostring(v) end
	if accCache.sig == sig then return accCache.back, accCache.front end
	local back, front = {}, {}
	local vis = p.vis or {}
	if vis.wings then
		local k = accKey("wings", vis.wings, p.skin)
		if k then table.insert(back, k) end
	end
	for _, k in BODY_KEYS do
		if vis[k] then
			local key = accKey(k, vis[k], p.skin)
			if key then table.insert(front, key) end
		end
	end
	for _, k in TOP_KEYS do
		if vis[k] then
			local key = accKey(k, vis[k], p.skin)
			if key then table.insert(front, key) end
		end
	end
	accCache = { sig = sig, back = back, front = front }
	return back, front
end
-- palette du skin (miettes, bords de tranche…) : Color3 { base, dark, light, chip, chipHi, rim }
local palCache = {}
local DEF_PAL = { base = "#d99a4e", dark = "#a9652a", light = "#f3c783", chip = "#4a2511", chipHi = "#7a4424", rim = "#8a5220" }
function C.pal(skin)
	skin = skin or C.player.skin or "classic"
	local c = palCache[skin]
	if c then return c end
	local src = nil
	pcall(function()
		local D = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))
		src = D.SKIN and D.SKIN[skin]
	end)
	c = {}
	for k, v in DEF_PAL do
		local hv = src and type(src[k]) == "string" and src[k] or v
		local ok, col = pcall(Color3.fromHex, hv)
		c[k] = ok and col or Color3.fromHex(v)
	end
	palCache[skin] = c
	return c
end

function C.cookieKey(skin)
	skin = skin or C.player.skin or "classic"
	if C.has("cookie:" .. skin) then return "cookie:" .. skin, 3.2 end
	if C.has("cookie:classic") then return "cookie:classic", 3.2 end
	if C.has("ui:cookie") then return "ui:cookie", 2.25 end
	return nil, 2
end

----------------------------------------------------------------------------- Canvas (dessin immédiat)
local Canvas = {}
Canvas.__index = Canvas
C.Canvas = Canvas

function C.canvas(parent, z, name)
	local f = new("Frame", { Name = name or "Canvas", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z or 1, Parent = parent })
	return setmetatable({ frame = f, pools = {}, z = 0 }, Canvas)
end

local function hideF(o) o.f.Visible = false end
local function showF(o) o.f.Visible = true end

function Canvas:begin()
	self.z = 0
	for _, p in self.pools do p.n = 0 end
end
function Canvas:finish()
	for _, p in self.pools do
		for i = p.n + 1, p.shown do p.hide(p.items[i]) end
		p.shown = p.n
	end
end
function Canvas:clear()
	self:begin()
	self:finish()
end
function Canvas:destroy()
	self.frame:Destroy()
	self.pools = {}
end
function Canvas:take(kind, make, hide, show)
	local p = self.pools[kind]
	if not p then
		p = { items = {}, n = 0, shown = 0, hide = hide or hideF, show = show or showF }
		self.pools[kind] = p
	end
	local n = p.n + 1
	p.n = n
	local o = p.items[n]
	if not o then
		o = make(self.frame)
		p.items[n] = o
	elseif n > p.shown then
		p.show(o)
	end
	self.z += 2
	return o, self.z
end

local function a2t(a)
	if a == nil then return 0 end
	return 1 - (a < 0 and 0 or (a > 1 and 1 or a))
end
C.a2t = a2t

local function mkRect(parent)
	return { f = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Parent = parent }) }
end
-- rectangle centré (rot en degrés)
function Canvas:rect(cx, cy, w, h, color, alpha, rot)
	local o, z = self:take("rect", mkRect)
	local f = o.f
	f.Position = UDim2.fromOffset(cx, cy)
	f.Size = UDim2.fromOffset(w, h)
	f.Rotation = rot or 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = a2t(alpha)
	f.ZIndex = z
	return f
end
function Canvas:rectTL(x, y, w, h, color, alpha)
	return self:rect(x + w / 2, y + h / 2, w, h, color, alpha, 0)
end

local function mkBox(parent)
	local f = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Parent = parent })
	local o = { f = f }
	o.c = new("UICorner", { CornerRadius = UDim.new(0, 0), Parent = f })
	o.s = new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, BorderStrokePosition = Enum.BorderStrokePosition.Center, Enabled = false, Color = INK, Parent = f })
	o.g = new("UIGradient", { Enabled = false, Parent = f })
	return o
end
-- boîte générique : o = {color, alpha, radius, rot, stroke, sw, sa, grad, gradT, grot, gradOff}
function Canvas:box(cx, cy, w, h, opt)
	local o, z = self:take("box", mkBox)
	local f = o.f
	f.Position = UDim2.fromOffset(cx, cy)
	f.Size = UDim2.fromOffset(w, h)
	f.Rotation = opt.rot or 0
	f.ZIndex = z
	if opt.grad or opt.gradT then
		f.BackgroundColor3 = opt.color or C.col.white
		o.g.Enabled = true
		o.g.Color = opt.grad or ColorSequence.new(opt.color or C.col.white)
		o.g.Transparency = opt.gradT or NumberSequence.new(0)
		o.g.Rotation = opt.grot or 0
		o.g.Offset = opt.gradOff or Vector2.zero
	else
		f.BackgroundColor3 = opt.color or C.col.white
		o.g.Enabled = false
	end
	f.BackgroundTransparency = opt.color == false and 1 or a2t(opt.alpha)
	local r = opt.radius
	o.c.CornerRadius = r and (r >= 999 and UDim.new(1, 0) or UDim.new(0, r)) or UDim.new(0, 0)
	if opt.stroke then
		o.s.Enabled = true
		o.s.Color = opt.stroke
		o.s.Thickness = opt.sw or 2
		o.s.Transparency = a2t(opt.sa)
	else
		o.s.Enabled = false
	end
	return f
end

local function mkCirc(parent)
	local f = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Parent = parent })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
	local s = new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, BorderStrokePosition = Enum.BorderStrokePosition.Center, Enabled = false, Parent = f })
	return { f = f, s = s }
end
-- disque (alpha = remplissage, sc/sw/sa = contour centré sur le bord)
function Canvas:circle(cx, cy, r, color, alpha, sc, sw, sa, rx)
	local o, z = self:take("circ", mkCirc)
	local f = o.f
	f.Position = UDim2.fromOffset(cx, cy)
	f.Size = UDim2.fromOffset(2 * (rx or r), 2 * r)
	f.Rotation = 0
	f.ZIndex = z
	if color then
		f.BackgroundColor3 = color
		f.BackgroundTransparency = a2t(alpha)
	else
		f.BackgroundTransparency = 1
	end
	if sc then
		o.s.Enabled = true
		o.s.Color = sc
		o.s.Thickness = sw or 2
		o.s.Transparency = a2t(sa)
	else
		o.s.Enabled = false
	end
	return f
end
function Canvas:ring(cx, cy, r, w, color, alpha)
	if r <= 0 then return end
	return self:circle(cx, cy, r, nil, 0, color, w, alpha)
end

local function mkLineR(parent)
	local f = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Parent = parent })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
	return { f = f }
end
-- segment (round = extrémités arrondies)
function Canvas:line(x1, y1, x2, y2, w, color, alpha, round)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	local o, z = self:take(round and "lineR" or "rect", round and mkLineR or mkRect)
	local f = o.f
	f.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
	f.Size = UDim2.fromOffset(len + (round and w or 0), w)
	f.Rotation = math.deg(math.atan2(dy, dx))
	f.BackgroundColor3 = color
	f.BackgroundTransparency = a2t(alpha)
	f.ZIndex = z
	return f
end

local function mkImg(parent)
	local l = new("ImageLabel", { BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), ScaleType = Enum.ScaleType.Stretch, Parent = parent })
	return { f = l }
end
-- image d'art (clé du manifeste). Renvoie nil si l'art manque (l'appelant dessine un repli).
function Canvas:img(key, cx, cy, w, h, rot, color, alpha, rectOff, rectSize)
	local kind = "i:" .. key
	local p = self.pools[kind]
	if p and p.bad then return nil end
	local o, z = self:take(kind, function(parent)
		local it = mkImg(parent)
		it.ok = C.setImg(it.f, key)
		return it
	end)
	if not o.ok then
		self.pools[kind].bad = true
		o.f.Visible = false
		return nil
	end
	local l = o.f
	l.Position = UDim2.fromOffset(cx, cy)
	l.Size = UDim2.fromOffset(w, h)
	l.Rotation = rot or 0
	l.ImageColor3 = color or C.col.white
	l.ImageTransparency = a2t(alpha)
	l.ImageRectOffset = rectOff or Vector2.zero
	l.ImageRectSize = rectSize or Vector2.zero
	l.ZIndex = z
	return l
end
-- image procédurale (EditableImage) ; grad = dégradé (ColorSequence) optionnel, grot = son angle
function Canvas:pimg(name, ei, cx, cy, w, h, rot, color, alpha, grad, grot)
	if not ei then return nil end
	local o, z = self:take("p:" .. name, mkImg)
	local l = o.f
	if o.ei ~= ei then
		-- un même pool peut servir plusieurs textures (trapèzes de ratios différents…)
		C.applyProc(l, ei)
		o.ei = ei
	end
	l.Position = UDim2.fromOffset(cx, cy)
	l.Size = UDim2.fromOffset(w, h)
	l.Rotation = rot or 0
	l.ImageColor3 = color or C.col.white
	l.ImageTransparency = a2t(alpha)
	l.ZIndex = z
	if grad then
		if not o.g then o.g = new("UIGradient", { Parent = l }) end
		o.g.Enabled = true
		o.g.Color = grad
		o.g.Rotation = grot or 0
	elseif o.g then
		o.g.Enabled = false
	end
	return l
end
-- halo radial (glow() du site)
function Canvas:glow(cx, cy, r, color, alpha, inner)
	local ei = C.texGlow(inner or 0)
	if ei then return self:pimg("glow" .. (inner or 0), ei, cx, cy, 2 * r, 2 * r, 0, color, alpha) end
	return self:circle(cx, cy, r * 0.6, color, (alpha or 1) * 0.4)
end
-- rayons : n rayons de demi-ouverture frac*(360/n), tournés de rot (rad), longueur L
function Canvas:rays(cx, cy, L, n, frac, rot, colorFn)
	local ei = C.texWedge(360 / n * frac)
	for i = 0, n - 1 do
		local a0 = rot + (i / n) * C.TAU
		local mid = a0 + (C.TAU / n) * frac / 2
		local col, al = colorFn(i)
		if ei then
			self:pimg("wedge" .. n .. "_" .. frac, ei, cx, cy, 2 * L, 2 * L, math.deg(mid), col, al)
		else
			local w = L * math.tan((C.TAU / n) * frac / 2)
			self:line(cx, cy, cx + math.cos(mid) * L, cy + math.sin(mid) * L, w, col, al * 0.8)
		end
	end
end

-- texte contouré (outlined() / otext() du site) : UIStroke + copie décalée vers le bas
local function mkText(parent)
	local function lab()
		local l = new("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(3000, 40),
			FontFace = C.FD, TextSize = 20, TextColor3 = C.col.white, TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center, Parent = parent,
		})
		local st = new("UIStroke", { Color = INK, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
		local sc = new("UIScale", { Scale = 1, Parent = l })
		return l, st, sc
	end
	local sh, ss, ssc = lab()
	sh.TextColor3 = INK
	local m, ms, msc = lab()
	local g = new("UIGradient", { Enabled = false, Parent = m })
	return { f = m, sh = sh, ss = ss, ssc = ssc, ms = ms, msc = msc, g = g }
end
local function hideT(o)
	o.f.Visible = false
	o.sh.Visible = false
end
local function showT(o) o.f.Visible = true end
local ALIGN = {
	center = { Vector2.new(0.5, 0.5), Enum.TextXAlignment.Center },
	left = { Vector2.new(0, 0.5), Enum.TextXAlignment.Left },
	right = { Vector2.new(1, 0.5), Enum.TextXAlignment.Right },
}
-- opt : font, grad (ColorSequence), noShadow, lw (épaisseur relative du contour, 0.18 par défaut
-- comme outlined()), strokeCol
function Canvas:text(str, x, y, size, color, alpha, align, rot, scale, opt)
	local o, z = self:take("text", mkText, hideT, showT)
	opt = opt or {}
	scale = scale or 1
	size = math.max(1, size)
	local k = size > 100 and size / 100 or 1
	local ts = size / k
	local al = ALIGN[align or "center"]
	-- avec un dégradé, le label épouse le texte (sinon le dégradé s'étale sur 3000 px)
	local wl = opt.grad and (C.textWc(str, ts, opt.font or C.FD) + ts * 0.4) or 3000
	local lw = math.max(2, size * (opt.lw or 0.18)) / 2 / k
	local tr = a2t(alpha)
	local font = opt.font or C.FD
	for i = 1, 2 do
		local l = i == 1 and o.sh or o.f
		local st = i == 1 and o.ss or o.ms
		local sc = i == 1 and o.ssc or o.msc
		l.Text = str
		l.FontFace = font
		l.TextSize = ts
		l.AnchorPoint = al[1]
		l.TextXAlignment = al[2]
		l.Size = UDim2.fromOffset(wl, ts * 1.4)
		l.Rotation = rot or 0
		l.TextTransparency = tr
		st.Thickness = lw
		st.Transparency = tr
		st.Color = opt.strokeCol or INK
		sc.Scale = k * scale
		l.ZIndex = z - 1 + i
	end
	o.f.Position = UDim2.fromOffset(x, y)
	if opt.noShadow then
		o.sh.Visible = false
	else
		o.sh.Visible = true
		local dy = size * 0.07 * scale
		local r = math.rad(rot or 0)
		o.sh.Position = UDim2.fromOffset(x - math.sin(r) * dy, y + math.cos(r) * dy)
		o.sh.TextColor3 = opt.strokeCol or INK
	end
	if opt.grad then
		o.f.TextColor3 = C.col.white
		o.g.Enabled = true
		o.g.Color = opt.grad
	else
		o.f.TextColor3 = color or C.col.white
		o.g.Enabled = false
	end
	return o.f
end
-- texte simple (sans contour) : libellés mono du HUD
local function mkPText(parent)
	return {
		f = new("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(3000, 20),
			FontFace = C.FM, TextSize = 12, TextColor3 = C.col.white, Parent = parent,
		}),
	}
end
function Canvas:ptext(str, x, y, size, color, alpha, align, font)
	local o, z = self:take("ptext", mkPText)
	local l = o.f
	local al = ALIGN[align or "center"]
	l.Text = str
	l.FontFace = font or C.FM
	l.TextSize = math.min(100, size)
	l.AnchorPoint = al[1]
	l.TextXAlignment = al[2]
	l.Size = UDim2.fromOffset(3000, size * 1.4)
	l.Position = UDim2.fromOffset(x, y)
	l.TextColor3 = color or C.col.white
	l.TextTransparency = a2t(alpha)
	l.ZIndex = z
	return l
end
-- icône d'art avec repli emoji
function Canvas:icon(key, cx, cy, size, rot, alpha, color)
	local l = self:img(key, cx, cy, size, size, rot, color, alpha)
	if l then return l end
	return self:ptext(C.EMOJI[key] or "•", cx, cy, size * 0.8, C.col.white, alpha, "center", C.FB)
end

-- le cookie du joueur (skin + accessoires) : opt = {skin, acc, squash, alpha, t}
function Canvas:cookie(cx, cy, r, rot, opt)
	opt = opt or {}
	local key, mul = C.cookieKey(opt.skin)
	local deg = math.deg(rot or 0)
	local sq = opt.squash or 0
	local sx, sy = 1 + 0.14 * sq, 1 - 0.14 * sq
	local alpha = opt.alpha
	local color = opt.color
	if not key then
		return self:ptext("🍪", cx, cy, r * 2, C.col.white, alpha, "center", C.FB)
	end
	local size = r * mul
	local back, front
	if opt.acc and mul == 3.2 then back, front = C.accLayers() end
	if back then
		for _, k in back do self:img(k, cx, cy, size * sx, size * sy, deg, color, alpha) end
	end
	local l = self:img(key, cx, cy, size * sx, size * sy, deg, color, alpha)
	if front then
		local t = opt.t or os.clock()
		for _, k in front do
			local kk = k
			if k == "acc:face" and (t % 4.3) < 0.13 and C.has("acc:face_blink") then kk = "acc:face_blink" end
			self:img(kk, cx, cy, size * sx, size * sy, deg, color, alpha)
		end
	end
	return l
end

----------------------------------------------------------------------------- boutons .btn (base.css)
C.BTN = {
	violet = { "#7a5cff", "#5a3de0", "#3a22a8" }, green = { "#4dff8a", "#1fc85a", "#0f8a3a" },
	pink = { "#ff6be6", "#ff2bd6", "#b0108f" }, gold = { "#ffe066", "#ffb800", "#c07a00" },
	cyan = { "#7ffaff", "#1fd6ff", "#0a8fb8" }, red = { "#ff8095", "#ff3d5e", "#b3142f" },
	dark = { "#3a2a70", "#2a1b58", "#170d38" }, sel = { "#fff3b0", "#ffc93c", "#c07a00" },
	redsel = { "#ffd0d8", "#ff4d6d", "#b3142f" },
}
C.BTN_SIZE = {
	normal = { font = 17, px = 16, pt = 9, pb = 11, r = 14, b = 3 },
	big = { font = 24, px = 26, pt = 13, pb = 15, r = 18, b = 3 },
	small = { font = 14, px = 10, pt = 6, pb = 8, r = 11, b = 2 },
}
local function gray(c)
	local l = c.R * 0.3 + c.G * 0.59 + c.B * 0.11
	return Color3.new((l + (c.R - l) * 0.15) * 0.7, (l + (c.G - l) * 0.15) * 0.7, (l + (c.B - l) * 0.15) * 0.7)
end

-- opt : style, size ("normal"/"big"/"small"), font (px), icon (clé), iconAfter, textColor, w, h, minW, z
function C.button(parent, text, opt, onClick)
	opt = opt or {}
	local S = C.BTN_SIZE[opt.size or "normal"]
	local fs = opt.font or S.font
	local z = opt.z or 1
	local iconS = opt.icon and math.floor(fs * 1.15) or 0
	local tw = C.textW(text, fs, C.FD)
	local w = opt.w or math.max(opt.minW or 0, math.ceil(tw + (opt.icon and iconS + 6 or 0) + S.px * 2 + S.b * 2))
	local h = opt.h or math.ceil(fs + S.pt + S.pb + S.b * 2)
	local root = new("TextButton", {
		Name = "Btn", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h),
		ZIndex = z, Selectable = false, Parent = parent,
	})
	new("Frame", { BackgroundColor3 = INK, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 4), Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = root }, { C.corner(S.r) })
	local body = new("Frame", { BackgroundColor3 = C.col.white, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = root }, {
		C.corner(S.r), new("UIStroke", { Color = INK, Thickness = S.b, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local face = new("Frame", { BackgroundColor3 = C.col.white, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -4), ZIndex = z + 2, Parent = body }, { C.corner(S.r) })
	local grad = new("UIGradient", { Rotation = 90, Parent = face })
	local shine = new("Frame", {
		BackgroundColor3 = C.col.white, BackgroundTransparency = 0.65, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 1), Size = UDim2.new(1, -S.r, 0, 3), ZIndex = z + 3, Parent = body,
	}, { C.corner(2) })
	local content = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -2), ZIndex = z + 4, Parent = body }, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local label = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(0, fs + 4), AutomaticSize = Enum.AutomaticSize.X, Text = text,
		FontFace = C.FD, TextSize = fs, TextColor3 = opt.textColor or C.col.white, LayoutOrder = 2, ZIndex = z + 5, Parent = content,
	}, { new("UIStroke", { Color = C.col.black, Thickness = 1, Transparency = 0.75 }) })
	local icon
	if opt.icon then
		icon = C.icon(content, opt.icon, iconS, { LayoutOrder = opt.iconAfter and 3 or 1, ZIndex = z + 5 })
	end
	local scale = new("UIScale", { Scale = 1, Parent = root })
	local B = { btn = root, label = label, body = body, face = face, scale = scale, icon = icon, w = w, h = h, off = false, style = opt.style or "violet" }
	local hover, down = false, false
	local function paint()
		local c = C.BTN[B.style] or C.BTN.violet
		local c1, c2, c3 = hex(c[1]), hex(c[2]), hex(c[3])
		if B.off then c1, c2, c3 = gray(c1), gray(c2), gray(c3) end
		if hover and not B.off then
			c1 = c1:Lerp(C.col.white, 0.1)
			c2 = c2:Lerp(C.col.white, 0.1)
		end
		grad.Color = ColorSequence.new(c1, c2)
		body.BackgroundColor3 = c3
		shine.BackgroundTransparency = B.off and 0.85 or 0.65
		label.TextTransparency = B.off and 0.35 or 0
		local dy = (down and not B.off) and 3 or (hover and not B.off and -1 or 0)
		body.Position = UDim2.fromOffset(0, dy)
	end
	B.paint = paint
	function B.setStyle(st, textColor)
		B.style = st
		if textColor then label.TextColor3 = textColor end
		paint()
	end
	function B.setOff(v)
		if B.off == v then return end
		B.off = v
		paint()
	end
	function B.setText(t) label.Text = t end
	root.MouseEnter:Connect(function()
		hover = true
		paint()
	end)
	root.MouseLeave:Connect(function()
		hover = false
		down = false
		paint()
	end)
	root.MouseButton1Down:Connect(function()
		down = true
		paint()
	end)
	root.MouseButton1Up:Connect(function()
		down = false
		paint()
	end)
	if onClick then
		root.Activated:Connect(function()
			down = false
			paint()
			if not B.off then onClick(B) end
		end)
	end
	paint()
	return B
end

----------------------------------------------------------------------------- lettres animées
-- titre dont chaque lettre ondule (@keyframes wave) et prend une couleur arc-en-ciel
function C.waveTitle(parent, text, size, props)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, size * 1.2), AutomaticSize = Enum.AutomaticSize.X }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
	if props then for k, v in props do row[k] = v end end
	local T = { row = row, letters = {}, size = size }
	local i = 0
	for _, ch in utf8.codes(text) do
		i += 1
		local c = utf8.char(ch)
		local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, size * 1.2), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, ZIndex = row.ZIndex, Parent = row })
		local sh = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromOffset(c == " " and size * 0.3 or 0, size * 1.2), AutomaticSize = Enum.AutomaticSize.X,
			Text = c == " " and "" or c, FontFace = C.FD, TextSize = size, TextColor3 = INK, ZIndex = row.ZIndex, Parent = holder,
		}, { C.tstroke(INK, math.max(1.5, size * 0.07)) })
		local l = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromOffset(c == " " and size * 0.3 or 0, size * 1.2), AutomaticSize = Enum.AutomaticSize.X,
			Text = c == " " and "" or c, FontFace = C.FD, TextSize = size, TextColor3 = C.col.white, ZIndex = row.ZIndex + 1, Parent = holder,
		}, { C.tstroke(INK, math.max(1.5, size * 0.07)) })
		table.insert(T.letters, { l = l, sh = sh, i = i })
	end
	function T.setSize(s)
		T.size = s
		row.Size = UDim2.fromOffset(0, s * 1.2)
		for _, L in T.letters do
			L.l.TextSize = s
			L.sh.TextSize = s
			L.l.Parent.Size = UDim2.fromOffset(0, s * 1.2)
			local sp = L.l.Text == ""
			L.l.Size = UDim2.fromOffset(sp and s * 0.3 or 0, s * 1.2)
			L.sh.Size = UDim2.fromOffset(sp and s * 0.3 or 0, s * 1.2)
			L.l:FindFirstChildOfClass("UIStroke").Thickness = math.max(1.5, s * 0.07)
			L.sh:FindFirstChildOfClass("UIStroke").Thickness = math.max(1.5, s * 0.07)
		end
	end
	-- amp = amplitude de l'onde (px), per = période (s), hueStep = décalage de teinte par lettre,
	-- rot = rotation (°) au sommet de l'onde ; T.offset décale l'indice (titre sur 2 lignes)
	T.offset = 0
	function T.update(T0, amp, per, hueStep, delayStep, light, rot)
		local h0 = C.hue(0)
		for _, L in T.letters do
			local i = L.i - 1 + T.offset
			local ph = ((T0 + i * (delayStep or 0.09)) % per) / per
			local w = 0.5 - 0.5 * math.cos(ph * C.TAU)
			local dy = -amp * w
			L.l.Position = UDim2.fromOffset(0, dy)
			L.sh.Position = UDim2.fromOffset(0, dy + T.size * 0.08)
			if rot then
				L.l.Rotation = rot * w
				L.sh.Rotation = rot * w
			end
			L.l.TextColor3 = C.hsl(h0 + i * hueStep, 100, light or 66)
		end
	end
	return T
end

----------------------------------------------------------------------------- tour serveur
-- Règles du serveur (Main.server.lua › MG_RULES) : durée mini et points/s maxi.
C.RULES = {
	ninja = { minDur = 25, rate = 6, gemsPer = 25 },
	flappy = { minDur = 0, rate = 0.9, gemsPer = 10 },
	rhythm = { minDur = 25, rate = 50, gemsPer = 150 },
}

----------------------------------------------------------------------------- écran d'accueil (Ninja / Flappy)
-- Reproduit .cn-menu / .cf-menu : héros qui se dandine, titre en vague RGB, sous-titre mono,
-- grille de 4 règles, record, gros bouton JOUER vert pulsant.
function C.menuScreen(parent, o)
	local M = {}
	local f = new("Frame", { Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = parent })
	M.frame = f
	local hero = C.icon(f, o.hero, 84, { AnchorPoint = Vector2.new(0.5, 0), ZIndex = 52 })
	local heroGlow = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = o.heroGlow, ImageTransparency = 0.25, ZIndex = 51, Parent = f })
	if not C.applyProc(heroGlow, C.texGlow(0.2)) then heroGlow.Visible = false end
	local title = C.waveTitle(f, o.title, 60, { AnchorPoint = Vector2.new(0.5, 0), ZIndex = 52, Parent = f })
	local sub = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(1, -32, 0, 18), Text = string.upper(o.sub),
		FontFace = C.FM, TextSize = 15, TextColor3 = o.subColor, TextWrapped = true, ZIndex = 52, Parent = f,
	}, { new("UIStroke", { Color = o.subColor, Thickness = 1, Transparency = 0.8 }) })
	local bot = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), ZIndex = 52, Parent = f })
	local rules = {}
	for i, r in o.rules do
		local sh = new("Frame", { BackgroundColor3 = C.col.black, BackgroundTransparency = 0.65, ZIndex = 52, Parent = bot }, { C.corner(12) })
		local box = new("Frame", {
			BackgroundColor3 = hex("#160b34"), BackgroundTransparency = 0.18, ZIndex = 53, Parent = bot,
		}, { C.corner(12), C.stroke(hex("#be96ff"), 2, 0.75) })
		local ic = C.icon(box, r[1], 24, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), ZIndex = 54 })
		local tx = new("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 39, 0.5, 0), Size = UDim2.new(1, -46, 1, -8),
			Text = r[2], FontFace = C.FB, TextSize = 14, TextColor3 = C.col.ink, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			LineHeight = 1.0, ZIndex = 54, Parent = box,
		})
		rules[i] = { box = box, sh = sh, ic = ic, tx = tx }
	end
	local best = new("Frame", { BackgroundTransparency = 1, ZIndex = 53, Parent = bot }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	C.icon(best, "ui:trophy", 18, { LayoutOrder = 1, ZIndex = 54 })
	local bestTx = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Text = "RECORD : 0",
		FontFace = C.FM, TextSize = 15, TextColor3 = C.col.gold, LayoutOrder = 2, ZIndex = 54, Parent = best,
	}, { new("UIStroke", { Color = C.col.gold, Thickness = 1, Transparency = 0.8 }) })
	local play = C.button(bot, "JOUER", { style = "green", size = "big", font = 30, icon = "ui:play", minW = 240, z = 55 }, function()
		if o.onPlay then o.onPlay() end
	end)
	play.btn.AnchorPoint = Vector2.new(0.5, 1)
	M.play = play

	function M.setBest(n) bestTx.Text = "RECORD : " .. (o.fmt and o.fmt(n) or tostring(n)) end
	M.setBest(o.best or 0)

	local W, H = 0, 0
	function M.layout(w, h)
		W, H = w, h
		local padT = C.clamp(h * 0.03, 10, 26)
		local padB = C.clamp(h * 0.035, 14, 30)
		local hs = C.clamp(h * 0.1, 48, 84)
		hero.Size = UDim2.fromOffset(hs, hs)
		hero.Position = UDim2.fromOffset(w / 2, padT)
		heroGlow.Size = UDim2.fromOffset(hs * 1.9, hs * 1.9)
		local ts = C.clamp(w * 0.115, 36, 86)
		title.setSize(ts)
		title.row.Position = UDim2.fromOffset(w / 2, padT + hs + 2)
		local ss = C.clamp(w * 0.033, 11, 15)
		sub.TextSize = ss
		sub.Size = UDim2.new(1, -32, 0, ss * 2.6)
		sub.Position = UDim2.fromOffset(w / 2, padT + hs + 2 + ts * 1.1 + 6)
		local bw = math.min(w - 32, 440)
		local fsR = C.clamp(w * 0.033, 11.5, 14)
		local rh = math.floor(fsR * 2.3 + 14)
		local colW = (bw - 6) / 2
		for i, r in rules do
			local cx = (i - 1) % 2
			local cy = math.floor((i - 1) / 2)
			r.box.Size = UDim2.fromOffset(colW, rh)
			r.box.Position = UDim2.fromOffset(cx * (colW + 6), cy * (rh + 6))
			r.sh.Size = r.box.Size
			r.sh.Position = r.box.Position + UDim2.fromOffset(0, 3)
			r.tx.TextSize = fsR
			local isz = math.floor(fsR * 1.7)
			r.ic.Size = UDim2.fromOffset(isz, isz)
			r.tx.Position = UDim2.new(0, 9 + isz + 6, 0.5, 0)
			r.tx.Size = UDim2.new(1, -(9 + isz + 6 + 6), 1, -6)
		end
		local rowsH = math.ceil(#rules / 2) * (rh + 6) - 6
		best.Size = UDim2.fromOffset(bw, 22)
		best.Position = UDim2.fromOffset(0, rowsH + 10)
		local pw = math.max(play.w, math.min(240, w * 0.8))
		play.btn.Size = UDim2.fromOffset(pw, play.h)
		local totalH = rowsH + 10 + 22 + 10 + play.h + 4
		play.btn.Position = UDim2.fromOffset(bw / 2, totalH - 4)
		bot.Size = UDim2.fromOffset(bw, totalH)
		bot.Position = UDim2.fromOffset(w / 2, h - padB)
	end

	function M.update(T)
		-- @keyframes bob : 0 % (0, -deg) → 50 % (-2·amp px, +deg)
		local per, amp, deg = o.bobPer or 1.5, o.bobAmp or 3, o.bobDeg or 6
		local c = math.cos(((T % per) / per) * C.TAU)
		hero.Position = UDim2.fromOffset(W / 2, C.clamp(H * 0.03, 10, 26) - amp + amp * c)
		hero.Rotation = -deg * c
		heroGlow.Position = UDim2.fromOffset(W / 2, hero.Position.Y.Offset + hero.Size.Y.Offset / 2)
		title.update(T, 7, 1.6, o.hueStep or 26, 0.09, 66)
		local p = (T % 1.1) / 1.1
		play.scale.Scale = 1 + 0.03 * (1 - math.cos(p * C.TAU))
	end
	function M.show(v) f.Visible = v end
	return M
end

----------------------------------------------------------------------------- carte de résultats (Ninja / Flappy)
-- .cn-res : voile, cadre à bord RGB, titre, phrase, SCORE qui défile, record, stats, pastilles
-- de gains puis boutons REJOUER / QUITTER.
function C.resultsCard(parent, o)
	local R = { stage = -1, bumpT = nil, recT = nil, rwT = nil }
	local veil = new("Frame", { Name = "Results", BackgroundColor3 = hex("#0b0620"), BackgroundTransparency = 0.2, Size = UDim2.fromScale(1, 1), ZIndex = 60, Visible = false, Active = o.blockAll == true, Parent = parent })
	new("UIGradient", { Transparency = C.nseq({ { 0, 0.03 }, { 0.5, 0.56 }, { 1, 0.03 } }), Parent = veil })
	local scaleHolder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(400, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 61, Parent = veil })
	local uis = new("UIScale", { Scale = 1, Parent = scaleHolder })
	local card = new("Frame", {
		BackgroundColor3 = C.col.white, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 62, Active = true, Parent = scaleHolder,
	}, {
		C.corner(24),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("#26104f"), hex("#130731")) }),
		new("UIPadding", { PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 18), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
		new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local rgb = new("UIStroke", { Thickness = 3, Color = C.col.white, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
	local rgbGrad = new("UIGradient", { Color = C.RGB_SEQ, Parent = rgb })
	local Z = 63
	local function row(order, h)
		return new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h), LayoutOrder = order, ZIndex = Z, Parent = card }, {
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
	end
	local function stext(parent, text, size, color, font, order)
		local l = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromOffset(0, size * 1.25), AutomaticSize = Enum.AutomaticSize.X, Text = text,
			FontFace = font or C.FD, TextSize = size, TextColor3 = color or C.col.white, LayoutOrder = order or 2, ZIndex = Z + 1, Parent = parent,
		})
		return l
	end
	-- titre
	local headRow = row(1, 44)
	local headIcon = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(40, 40), LayoutOrder = 1, ZIndex = Z, Parent = headRow })
	local headTx = stext(headRow, "GAME OVER", 38, C.col.white, C.FD, 2)
	C.tstroke(INK, 2.6).Parent = headTx
	local quip = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Text = "", FontFace = C.FB, TextSize = 15, TextColor3 = hex("#d9ccff"),
		TextWrapped = true, LayoutOrder = 2, ZIndex = Z + 1, Parent = card,
	})
	new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Text = "S C O R E", FontFace = C.FM, TextSize = 12, TextColor3 = C.col.muted,
		LayoutOrder = 3, ZIndex = Z + 1, Parent = card,
	})
	local scoreRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 80), LayoutOrder = 4, ZIndex = Z, Parent = card })
	local scoreTx = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		Text = "0", FontFace = C.FD, TextSize = 80, TextColor3 = C.col.white, ZIndex = Z + 2, Parent = scoreRow,
	}, { C.tstroke(INK, 5) })
	local scoreSh = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 6), Size = UDim2.fromScale(1, 1),
		Text = "0", FontFace = C.FD, TextSize = 80, TextColor3 = INK, ZIndex = Z + 1, Parent = scoreRow,
	}, { C.tstroke(INK, 5) })
	local scoreScale = new("UIScale", { Scale = 1, Parent = scoreTx })
	local scoreScale2 = new("UIScale", { Scale = 1, Parent = scoreSh })
	local recRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 5, Visible = false, ZIndex = Z, Parent = card })
	local rec = C.waveTitle(recRow, "NOUVEAU RECORD !", 28, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = Z + 1 })
	rec.row.Parent = recRow
	local recScale = new("UIScale", { Scale = 1, Parent = rec.row })
	local bestRow = row(6, 18)
	C.icon(bestRow, "ui:trophy", 15, { LayoutOrder = 1, ZIndex = Z + 1 })
	local bestTx = stext(bestRow, "Record : 0", 13, C.col.gold, C.FM, 2)
	local statsRow = row(7, 20)
	statsRow:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 12)
	local rwRow = row(8, 46)
	rwRow.Visible = false
	local rwScale = new("UIScale", { Scale = 1, Parent = rwRow })
	local btnRow = row(9, 50)
	btnRow:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 10)
	local again = C.button(btnRow, "REJOUER", { style = "green", z = Z + 2 }, function() if R.stage >= 2 and o.onAgain then o.onAgain() end end)
	local quit = C.button(btnRow, "QUITTER", { style = "dark", z = Z + 2 }, function() if o.onQuit then o.onQuit() end end)
	again.btn.LayoutOrder = 1
	quit.btn.LayoutOrder = 2
	btnRow.Visible = false

	local function clearKids(fr)
		for _, ch in fr:GetChildren() do
			if not ch:IsA("UIListLayout") then ch:Destroy() end
		end
	end
	local function statItem(parent, key, text, order)
		local it = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order, ZIndex = Z, Parent = parent }, {
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		C.icon(it, key, 16, { LayoutOrder = 1, ZIndex = Z + 1 })
		stext(it, text, 13, hex("#c9bcf2"), C.FB, 2)
	end
	-- pastille .pill (or / gemme / indice)
	local function pill(kind, text, key)
		local isHint = kind == "hint"
		local fs = isHint and 13 or 22
		local tw = C.textW(text, fs, isHint and C.FB or C.FD)
		local isz = isHint and 16 or math.floor(fs * 1.15)
		local w = tw + isz + 6 + 28
		local h = isHint and 30 or 40
		local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h + (isHint and 0 or 4)), ZIndex = Z, Parent = rwRow })
		if not isHint then
			new("Frame", { BackgroundColor3 = INK, Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(w, h), ZIndex = Z, Parent = holder }, { C.corner(UDim.new(1, 0)) })
		end
		local body = new("Frame", {
			BackgroundColor3 = isHint and hex("#28145a") or C.col.white, BackgroundTransparency = isHint and 0.15 or 0,
			Size = UDim2.fromOffset(w, h), ZIndex = Z + 1, Parent = holder,
		}, {
			C.corner(UDim.new(1, 0)), C.stroke(isHint and hex("#be96ff") or INK, isHint and 2 or 3, isHint and 0.7 or 0),
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		if not isHint then
			new("UIGradient", { Rotation = 90, Color = kind == "gem" and ColorSequence.new(hex("#7ffaff"), hex("#1fd6ff")) or ColorSequence.new(hex("#ffe066"), hex("#ffb800")), Parent = body })
		end
		local tx = stext(body, text, fs, isHint and C.col.muted or C.col.white, isHint and C.FB or C.FD, isHint and 2 or 1)
		if not isHint then C.tstroke(INK, fs * 0.08).Parent = tx end
		C.icon(body, key, isz, { LayoutOrder = isHint and 1 or 2, ZIndex = Z + 2 })
	end

	R.stage = -1
	local availH = 600
	local data, t, shown, lastTick = nil, 0, -1, 0
	local rewardsIn = false
	function R.show(d)
		-- d : head, headIcon, quip, score, best, stats = {{key, text}}, isBest
		data = d
		t, shown, lastTick = 0, -1, 0
		R.stage = 0
		rewardsIn = false
		clearKids(headIcon)
		C.icon(headIcon, d.headIcon, 40, { ZIndex = Z + 1 })
		headTx.Text = d.head
		quip.Text = d.quip
		scoreTx.Text = "0"
		scoreSh.Text = "0"
		recRow.Visible = false
		bestTx.Text = "Record : " .. d.fmt(d.best or 0)
		clearKids(statsRow)
		for i, s in d.stats do statItem(statsRow, s[1], s[2], i) end
		clearKids(rwRow)
		rwRow.Visible = false
		btnRow.Visible = false
		veil.Visible = true
		uis.Scale = 0.3
	end
	-- résultat serveur arrivé (ou nil) : on construit les pastilles
	function R.rewards(res, hint)
		clearKids(rwRow)
		if res then
			pill("gold", "+" .. data.fmt(res.cookies or 0), "ui:cookie")
			if (res.gems or 0) > 0 then pill("gem", "+" .. tostring(res.gems), "ui:gem") else pill("hint", hint or "", "ui:gem") end
			bestTx.Text = "Record : " .. data.fmt(res.best or data.best or 0)
			if res.isBest and data.score > 0 then data.isBest = true end
		else
			pill("hint", hint or "Pas de récompense", "ui:warning")
		end
		rewardsIn = true
	end
	function R.hide()
		veil.Visible = false
		R.stage = -1
		data = nil
	end
	function R.layout(w, h)
		local cw = math.min(w - 32, 400)
		scaleHolder.Size = UDim2.fromOffset(cw, 0)
		availH = h
		local s = C.clamp(w * 0.17, 56, 84)
		scoreRow.Size = UDim2.new(1, 0, 0, s * 1.05)
		scoreTx.TextSize = math.min(100, s)
		scoreSh.TextSize = math.min(100, s)
		headTx.TextSize = C.clamp(w * 0.08, 28, 40)
	end
	function R.update(dt, T, fx)
		if not data then return end
		rgbGrad.Rotation = C.hue(0)
		t += dt
		-- le cadre peut dépasser en hauteur sur petit écran : on réduit
		local natural = uis.Scale > 0.05 and scaleHolder.AbsoluteSize.Y / uis.Scale or 0
		local fit = natural > 0 and math.min(1, (availH - 16) / natural) or 1
		local pk = C.clamp(t / 0.5, 0, 1)
		uis.Scale = (0.3 + 0.7 * C.easeOutBack(pk, 2.2)) * fit
		local D0 = 0.3
		local CU = C.clamp(0.5 + data.score * (o.cuK or 0.008), 0.6, 1.4)
		local k = C.clamp((t - D0) / CU, 0, 1)
		local v = math.floor(data.score * C.easeOutCubic(k) + 0.5)
		if v ~= shown then
			shown = v
			scoreTx.Text = tostring(v)
			scoreSh.Text = tostring(v)
			if t - lastTick > 0.055 and v > 0 then
				lastTick = t
				C.sfx("tick", { pitch = 0.9 + k * 0.9, vol = 0.5 })
			end
		end
		if R.stage == 0 and k >= 1 then
			R.stage = 1
			R.bumpT = t
			C.sfx("pop")
			if data.isBest then
				recRow.Visible = true
				R.recT = t
				C.sfx("achievement")
				if fx then fx.onRecord() end
			end
		end
		if R.bumpT then
			local b = C.clamp((t - R.bumpT) / 0.35, 0, 1)
			local s = b < 0.4 and 1 + 0.25 * (b / 0.4) or 1 + 0.25 * (1 - (b - 0.4) / 0.6)
			scoreScale.Scale = s
			scoreScale2.Scale = s
		end
		if recRow.Visible then
			rec.update(T, 7, 1.6, 22, 0.09, 66)
			recScale.Scale = C.easeOutBack(C.clamp((t - (R.recT or 0)) / 0.5, 0, 1), 2.5)
		end
		-- les gains s'affichent quand l'animation est finie ET que le serveur a répondu
		if R.stage == 1 and t > D0 + CU + 0.35 and rewardsIn then
			R.stage = 2
			R.rwT = t
			rwRow.Visible = true
			C.sfx("coin")
		end
		if R.rwT then rwScale.Scale = C.easeOutBack(C.clamp((t - R.rwT) / 0.45, 0, 1), 2.5) end
		if R.stage == 2 and t > (R.rwT or 0) + 0.3 then
			R.stage = 3
			btnRow.Visible = true
		end
		-- si le serveur tarde vraiment, on laisse quand même rejouer / quitter
		if R.stage == 1 and t > D0 + CU + 6 then
			R.stage = 3
			btnRow.Visible = true
		end
	end
	R.frame = veil
	return R
end

return C
