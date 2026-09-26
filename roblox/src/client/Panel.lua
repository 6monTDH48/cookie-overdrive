-- COOKIE OVERDRIVE — contenu des onglets du panneau (portage de ui.js : renderers + updaters) :
-- Shop (bâtiments .brow), Upgrades (.ucard), Jeux (.gcard), Pets (slots, œufs, inventaire), Style
-- (skins, thèmes, drip), Quêtes (quêtes, succès, stats), Rebirth, Options (+ classement) et la page
-- Boutique Robux. Chaque page est construite une fois (au changement d'onglet ou de « clé douce »)
-- puis mise à jour sur place toutes les 0,2 s.
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = RS:WaitForChild("Shared")
local D = require(Shared:WaitForChild("GameData"))
local E = require(Shared:WaitForChild("Econ"))
local M = require(Shared:WaitForChild("Monetization"))
local K = require(script.Parent:WaitForChild("Kit"))
local Background = require(script.Parent:WaitForChild("Background"))
local new, C, F = K.new, K.C, K.F
local clamp = K.clamp

local P = {}
local ui: any = nil -- module UI (toast, modal, hatch, setTab…)
local Store: any = nil
local act: (string, ...any) -> any = function() return nil end

P.settings = { buyQty = 1 :: any, pm = 1, particles = 2, shake = true, reduced = false }

---------------------------------------------------------------------------- données du site absentes de GameData
P.TABS = {
	{ id = "shop", l = "Shop" }, { id = "upgrades", l = "Upgrades" }, { id = "games", l = "Jeux" }, { id = "pets", l = "Pets" },
	{ id = "style", l = "Style" }, { id = "quests", l = "Quêtes" }, { id = "rebirth", l = "Rebirth" }, { id = "options", l = "Options" },
}
local MG_ORDER = { "ninja", "flappy", "rhythm", "slots" }
P.MG = {
	ninja = { name = "Cookie Ninja", color = "#ff2bd6", tagline = "Tranche les cookies, évite les brocolis." },
	flappy = { name = "Flappy Cookie", color = "#1ff4ff", tagline = "Fais voler ton cookie entre les verres de lait." },
	rhythm = { name = "Crunch Rythme", color = "#b6ff3b", tagline = "Croque les cookies en rythme." },
	slots = { name = "Casino Crumble", color = "#ffc93c", tagline = "Mise tes cookies. Jackpot = aura infinie." },
}
P.VIS = {
	chips_xl = { "cookie", "Pépites XXL brillantes" }, sprinkles = { "cookie", "Vermicelles arc-en-ciel" }, glaze = { "cookie", "Glaçage bubblegum" },
	crystals = { "cookie", "Cristaux de diamant incrustés" }, rgb_rim = { "cookie", "Contour RGB animé" }, face = { "cookie", "Visage kawaii" },
	shades = { "cookie", "Lunettes pixel « Deal With It »" }, crown = { "cookie", "Couronne dorée" }, headphones = { "cookie", "Casque gamer RGB" },
	bling = { "cookie", "Chaîne en or" }, halo = { "cookie", "Halo divin" }, wings = { "cookie", "Ailes néon" },
	laser_eyes = { "cookie", "Yeux laser à chaque clic" }, galaxy_core = { "cookie", "Fissures galactiques" }, holo = { "cookie", "Reflet holographique" },
	glitch = { "cookie", "Glitch RGB" }, afterimage = { "cookie", "Images rémanentes prismatiques" }, orbiters = { "around", "Mini-cookies en orbite" },
	saturn_ring = { "around", "Anneau planétaire" }, fire_aura = { "around", "Aura de feu" }, lightning = { "around", "Arcs électriques" },
	shockwave = { "around", "Onde de choc à chaque clic" }, confetti_click = { "around", "Explosion de confettis au clic" },
	chat = { "around", "Chat de stream en direct" }, cursor_rgb = { "around", "Anneau de curseurs RGB turbo" }, cookie_rain = { "screen", "Pluie de cookies en fond" },
	disco = { "screen", "Boule disco + spots" }, warp = { "screen", "Vitesse lumière" }, god_rays = { "screen", "Rayons divins" },
	black_hole = { "screen", "Trou noir derrière le cookie" }, beat_pulse = { "screen", "Pulsation sur le beat" },
}
local QUEST_ICON = { clicks = "ui:tap", bake = "ui:cookie", buy = "tab:shop", upgrade = "tab:upgrades", golden = "ui:golden", combo = "ui:fire", crit = "ui:sparkle", minigame = "tab:games", boss = "ui:sword", fever = "ui:rainbow" }
local ACH_ICON = {
	{ "a_click", "ui:tap" }, { "a_bake", "ui:cookie" }, { "a_cps", "ui:bolt" }, { "a_cursor", "b:cursor" }, { "a_granny", "b:granny" }, { "a_b", "tab:shop" },
	{ "a_golden", "ui:golden" }, { "a_crit", "ui:sparkle" }, { "a_combo", "ui:fire" }, { "a_fever", "ui:rainbow" }, { "a_boss", "ui:sword" }, { "a_mg", "tab:games" },
	{ "a_egg", "tab:pets" }, { "a_legend", "pet:unicorn" }, { "a_mythic", "pet:glitchy" }, { "a_rebirth", "tab:rebirth" }, { "a_skins", "tab:style" },
	{ "a_quests", "tab:quests" }, { "a_upg", "tab:upgrades" }, { "a_logo", "ui:search" }, { "a_night", "ui:moon" }, { "a_afk", "ui:clock" },
}
function P.achIcon(id: string): string
	for _, m in ACH_ICON do
		if id == m[1] or string.sub(id, 1, #m[1]) == m[1] then return m[2] end
	end
	return "ui:trophy"
end
P.PASS_ICON = { DoubleCookies = "ui:cookie", AutoClicker = "ui:cursor", VIP = "ui:crown", LuckyEggs = "egg:neon", GoldenMagnet = "ui:golden", SkinPack = "cookie:plasma" }
P.PROD_ICON = { gems = "ui:gem", cookies = "ui:cookie", boost = "ui:bolt", fever = "ui:rainbow" }
local RORD = { mythic = 0, legendary = 1, epic = 2, rare = 3, common = 4 }

local function S(): any return Store.state end
local function Mx(): any return Store.M end
local function fmt(n: number?, int: boolean?): string return K.fmt(n, int) end

---------------------------------------------------------------------------- widgets
local W = {}
P.W = W
local Z = 13 -- ZIndex de base du contenu du panneau

function W.frame(props: { [string]: any }?): Frame
	local f = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = Z })
	for k, v in (props or {}) :: { [string]: any } do if k ~= "Parent" then (f :: any)[k] = v end end
	if props and props.Parent then f.Parent = props.Parent end
	return f
end
-- colonne pleine largeur, hauteur automatique
function W.col(parent: Instance, gap: number?, order: number?): Frame
	local f = W.frame({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order or 0, Parent = parent })
	K.vlist(f, gap or 8)
	return f
end
-- rangée horizontale à taille automatique
function W.row(parent: Instance, gap: number?, order: number?, valign: Enum.VerticalAlignment?): Frame
	local f = W.frame({ Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order or 0, Parent = parent })
	K.hlist(f, gap or 6, nil, valign)
	return f
end
function W.text(parent: Instance?, t: string, size: number, font: Font?, color: Color3?, props: { [string]: any }?): TextLabel
	local l = K.txt(t, size, font or F.body, color or C.ink, { Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = Z, RichText = true })
	for k, v in (props or {}) :: { [string]: any } do if k ~= "Parent" then (l :: any)[k] = v end end
	l.Parent = (props and props.Parent) or parent
	return l
end
-- texte qui passe à la ligne sur toute la largeur
function W.para(parent: Instance, t: string, size: number, font: Font?, color: Color3?, order: number?, align: Enum.TextXAlignment?): TextLabel
	return K.txt(t, size, font or F.body, color or C.muted, {
		Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, RichText = true,
		TextXAlignment = align or Enum.TextXAlignment.Left, LayoutOrder = order or 0, ZIndex = Z, Parent = parent,
	})
end
function W.ol(parent: Instance?, t: string, size: number, color: Color3?, props: { [string]: any }?): TextLabel
	local l = W.text(parent, t, size, F.display, color or C.white, props)
	K.ol(l, size >= 28 and 3 or 2)
	return l
end
function W.icon(parent: Instance?, key: string, size: number, props: { [string]: any }?): ImageLabel
	local p = { Size = UDim2.fromOffset(size, size), ZIndex = Z, Parent = parent }
	for k, v in (props or {}) :: { [string]: any } do p[k] = v end
	return K.img(key, p)
end
-- icône + texte sur une ligne
function W.itext(parent: Instance, key: string?, t: string, size: number, font: Font?, color: Color3?, order: number?, iconK: number?): (Frame, TextLabel)
	local r = W.row(parent, math.max(3, size * 0.25), order)
	if key then W.icon(r, key, math.floor(size * (iconK or 1.2)), { LayoutOrder = 1 }) end
	local l = W.text(r, t, size, font, color, { LayoutOrder = 2 })
	return r, l
end
function W.round(o: Instance, r: number?) K.round(o, r) end
function W.stroke(o: Instance, col: Color3?, th: number?, tr: number?): UIStroke
	return new("UIStroke", { Color = col or C.stroke, Thickness = th or 3, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o })
end
function W.grad(o: Instance, c1: Color3, c2: Color3, rot: number?, stop: number?): UIGradient
	local seq = stop and ColorSequence.new({ ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(stop, c2), ColorSequenceKeypoint.new(1, c2) }) or ColorSequence.new(c1, c2)
	return new("UIGradient", { Color = seq, Rotation = rot or 90, Parent = o })
end
-- carte translucide (rgba(255,255,255,.045) + bord 2 px rgba(255,255,255,.07))
function W.card(parent: Instance, h: number?, props: { [string]: any }?, radius: number?): Frame
	local f = W.frame({ BackgroundTransparency = 0.955, BackgroundColor3 = C.white, Size = UDim2.new(1, 0, 0, h or 0), Parent = parent })
	if not h then f.AutomaticSize = Enum.AutomaticSize.Y end
	for k, v in (props or {}) :: { [string]: any } do if k ~= "Parent" then (f :: any)[k] = v end end
	W.round(f, radius or 18)
	W.stroke(f, C.white, 2, 0.93)
	return f
end
-- vignette d'icône (.ico) : dégradé violet, bord sombre 3 px, image centrée
function W.icoBox(parent: Instance, key: string, size: number, imgSize: number, c1: string?, radius: number?, props: { [string]: any }?): (Frame, ImageLabel, UIGradient)
	local th = 3
	local f = W.frame({ BackgroundTransparency = 0, BackgroundColor3 = C.white, Size = UDim2.fromOffset(size - th * 2, size - th * 2), Parent = parent })
	for k, v in (props or {}) :: { [string]: any } do if k ~= "Parent" then (f :: any)[k] = v end end
	W.round(f, (radius or 15) - th)
	W.stroke(f, C.stroke, th)
	local g = W.grad(f, Color3.fromHex(c1 or "#4a3690"), Color3.fromHex("#1d0f45"), 55, 0.7)
	local im = W.icon(f, key, imgSize, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	return f, im, g
end
-- barre de progression .mprog (8 px, fond sombre, remplissage acc → acc2)
function W.mprog(parent: Instance, h: number?, order: number?, props: { [string]: any }?): (Frame, Frame)
	local bar = W.frame({ BackgroundTransparency = 0.6, BackgroundColor3 = C.black, Size = UDim2.new(1, 0, 0, (h or 8) - 4), LayoutOrder = order or 0, Parent = parent })
	for k, v in (props or {}) :: { [string]: any } do if k ~= "Parent" then (bar :: any)[k] = v end end
	W.round(bar)
	W.stroke(bar, C.stroke, 2)
	bar.ClipsDescendants = true
	local fill = W.frame({ BackgroundTransparency = 0, BackgroundColor3 = C.white, Size = UDim2.fromScale(0, 1), Parent = bar })
	W.round(fill)
	local g = new("UIGradient", { Parent = fill })
	K.seqBind(g, { 0, 70 }, 0.62)
	return bar, fill
end
function W.secTitle(parent: Instance, title: string, order: number?): (Frame, Frame)
	local f = W.frame({ Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order or 0, Parent = parent })
	W.ol(f, title, 24, C.white, { Position = UDim2.fromOffset(2, 4), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X })
	local right = W.frame({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -2, 0.5, 0), Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, Parent = f })
	K.hlist(right, 4, Enum.HorizontalAlignment.Right)
	return f, right
end
function W.note(parent: Instance, t: string, key: string?, keyAfter: boolean?)
	local l = W.text(parent, t, 12.5, F.body, C.muted, { LayoutOrder = 1 })
	if key then W.icon(parent, key, 16, { LayoutOrder = keyAfter == false and 0 or 2 }) end
	return l
end
function W.subTitle(parent: Instance, key: string, t: string, count: string?, order: number?): TextLabel?
	local f = W.frame({ Size = UDim2.new(1, 0, 0, 42), LayoutOrder = order or 0, Parent = parent })
	local r = W.row(f, 8, 0)
	r.Position = UDim2.fromOffset(2, 14)
	W.icon(r, key, 24, { LayoutOrder = 1 })
	W.text(r, t, 17, F.display, C.lilac, { LayoutOrder = 2 })
	if count then return W.text(r, count, 12, F.num, C.muted, { LayoutOrder = 3 }) end
	return nil
end
function W.empty(parent: Instance, t: string, order: number?)
	local f = W.frame({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order or 0, Parent = parent })
	W.round(f, 16)
	W.stroke(f, C.white, 2, 0.88)
	K.padding(f, 18)
	W.para(f, t, 14, F.body, C.muted, 0, Enum.TextXAlignment.Center)
end
function W.tip(parent: Instance, t: string, order: number?)
	local f = W.frame({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order or 0, Parent = parent })
	K.padding(f, 4, 4, 0, 4)
	W.para(f, t, 12.5, F.body, C.muted)
end
-- grille « auto-fill minmax(min, 1fr) »
function W.grid(parent: Instance, width: number, minW: number, h: number, gap: number?, order: number?, cols: number?): Frame
	local g = gap or 8
	local n = cols or math.max(1, math.floor((width + g) / (minW + g)))
	local f = W.frame({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order or 0, Parent = parent })
	new("UIGridLayout", {
		CellSize = UDim2.new(1 / n, -g * (n - 1) / n, 0, h), CellPadding = UDim2.fromOffset(g, g), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = n, Parent = f,
	})
	return f
end
-- segmented control (.seg)
function W.seg(parent: Instance, items: { { any } }, cur: any, onPick: (any) -> (), order: number?): Frame
	local box = W.frame({ BackgroundTransparency = 0.65, BackgroundColor3 = C.black, Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order or 0, Parent = parent })
	W.round(box, 12)
	W.stroke(box, C.stroke, 2)
	K.padding(box, 2)
	K.hlist(box, 2)
	for i, it in items do
		local on = it[1] == cur
		local b = new("TextButton", {
			Text = it[2], FontFace = F.display, TextSize = 14, TextColor3 = on and C.white or C.muted, AutoButtonColor = false,
			BackgroundColor3 = C.white, BackgroundTransparency = on and 0 or 1, Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = i, ZIndex = Z, Parent = box,
		})
		K.padding(b, 5, 10, 5, 10)
		W.round(b, 9)
		if on then
			K.accBind(b, "BackgroundColor3")
			new("UIStroke", { Color = C.black, Thickness = 1, Transparency = 0.6, Parent = b })
		end
		b.Activated:Connect(function() onPick(it[1]) end)
	end
	return box
end
-- interrupteur (.switch)
function W.switch(parent: Instance, on: boolean, onChange: (boolean) -> (), props: { [string]: any }?): TextButton
	local b = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(48, 26), BackgroundColor3 = on and C.green or Color3.fromHex("#2a1a5a"), ZIndex = Z, Parent = parent })
	for k, v in (props or {}) :: { [string]: any } do (b :: any)[k] = v end
	W.round(b)
	W.stroke(b, C.stroke, 2)
	local knob = W.frame({ BackgroundTransparency = 0, BackgroundColor3 = C.white, Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, on and 25 or 3, 0.5, 0), Parent = b })
	W.round(knob)
	local state = on
	b.Activated:Connect(function()
		state = not state
		b.BackgroundColor3 = state and C.green or Color3.fromHex("#2a1a5a")
		knob:TweenPosition(UDim2.new(0, state and 25 or 3, 0.5, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.2, true)
		onChange(state)
	end)
	return b
end
-- ligne d'option (.opt)
function W.opt(parent: Instance, label: string, desc: string?, order: number?): Frame
	local f = W.card(parent, nil, { LayoutOrder = order or 0 }, 14)
	f:FindFirstChildOfClass("UIStroke"):Destroy()
	K.padding(f, 10, 12, 10, 12)
	local l = W.frame({ Size = UDim2.new(1, -170, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = f })
	K.vlist(l, 1)
	W.para(l, label, 14, F.bold, C.ink, 1)
	if desc then W.para(l, desc, 12, F.body, C.muted, 2) end
	local right = W.frame({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, Parent = f })
	K.hlist(right, 4, Enum.HorizontalAlignment.Right)
	return right
end
function W.btn(parent: Instance, text: string, kind: string, opts: { [string]: any }, onClick: () -> ()): any
	local o = table.clone(opts)
	o.parent = parent
	o.zindex = o.zindex or Z
	o.onClick = onClick
	return K.btn(text, kind, o)
end
-- flash de la ligne achetée (.flash) et secousse si impossible
function W.flash(st: UIStroke)
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < 0.45 do
			local k = (os.clock() - t0) / 0.45
			st.Thickness = 2 + 6 * (1 - k)
			st.Transparency = k
			task.wait()
		end
		st.Thickness = 2
		st:SetAttribute("flash", false)
	end)
end
function W.shake(o: GuiObject)
	task.spawn(function()
		for _, dx in { -6, 6, -4, 4, 0 } do
			o.Position = UDim2.fromOffset(dx, 0)
			task.wait(0.044)
		end
	end)
end

---------------------------------------------------------------------------- état de page (références pour les mises à jour)
local refs: any = {}
local anims: { (number) -> () } = {}
function P.anim(t: number)
	for _, f in anims do f(t) end
end
local renderers: { [string]: (Frame, number) -> () } = {}
local updaters: { [string]: () -> () } = {}
local softKeys: { [string]: () -> string } = {}

local function qty(): any return P.settings.buyQty end

---------------------------------------------------------------------------- SHOP
renderers.shop = function(root: Frame, _w: number)
	local s = S()
	local _, right = W.secTitle(root, "Bâtiments", 1)
	W.seg(right, { { 1, "×1" }, { 10, "×10" }, { 100, "×100" }, { "max", "MAX" } }, qty(), function(v)
		P.settings.buyQty = v
		ui.render(true)
	end)
	local list = W.col(root, 8, 2)
	refs.rows = {}
	local shownLocked = 0
	for i, b in D.buildings do
		if not E.buildingUnlocked(s, i) then
			if shownLocked < 1 then
				shownLocked += 1
				local c = W.card(list, 76, { LayoutOrder = i })
				c.BackgroundTransparency = 0.975
				W.icoBox(c, "ui:lock", 54, 36, nil, 15, { Position = UDim2.fromOffset(12, 11), BackgroundColor3 = Color3.fromRGB(120, 120, 120) })
				W.text(c, "???", 17, F.display, C.muted, { Position = UDim2.fromOffset(75, 9) })
				W.text(c, "Continue à produire pour débloquer", 12.5, F.body, C.dim, { Position = UDim2.fromOffset(75, 30) })
				local cr = W.itext(c, "ui:cookie", fmt(b.cost), 14, F.num, Color3.fromHex("#9a8a9c"))
				cr.Position = UDim2.fromOffset(75, 48)
			end
		else
			local holder = W.frame({ Size = UDim2.new(1, 0, 0, 76), LayoutOrder = i, Parent = list })
			local btn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.white, BackgroundTransparency = 0.955, Size = UDim2.fromScale(1, 1), ZIndex = Z, Parent = holder })
			W.round(btn, 18)
			local st = W.stroke(btn, C.white, 2, 0.93)
			local bgGrad = new("UIGradient", { Parent = btn, Enabled = false,
				Color = ColorSequence.new(Color3.fromRGB(43, 220, 106), C.white),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.84), NumberSequenceKeypoint.new(0.7, 0.96), NumberSequenceKeypoint.new(1, 0.96) }) })
			local ico, _, _ = W.icoBox(btn, "b:" .. b.id, 54, 42, nil, 15, { Position = UDim2.fromOffset(12, 11) })
			local sc = new("UIScale", { Parent = ico })
			W.text(btn, b.name, 17, F.display, C.ink, { Position = UDim2.fromOffset(75, 9), Size = UDim2.new(1, -150, 0, 19), AutomaticSize = Enum.AutomaticSize.None, TextTruncate = Enum.TextTruncate.AtEnd })
			local meta = W.text(btn, "", 12.5, F.body, C.muted, { Position = UDim2.fromOffset(75, 30), Size = UDim2.new(1, -150, 0, 15), AutomaticSize = Enum.AutomaticSize.None, TextTruncate = Enum.TextTruncate.AtEnd })
			local cr, cost = W.itext(btn, "ui:cookie", "", 14, F.num, C.pink)
			cr.Position = UDim2.fromOffset(75, 47)
			local own = W.text(btn, "0", 30, F.display, C.white, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 2), TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 0.1 })
			local q = W.text(btn, "", 11, F.num, C.muted, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 4) })
			local prog = W.frame({ BackgroundTransparency = 0, BackgroundColor3 = C.white, Position = UDim2.new(0, 10, 1, -3), Size = UDim2.fromOffset(0, 3), Parent = btn })
			W.round(prog, 2)
			K.seqBind(new("UIGradient", { Parent = prog }), { 0, 70 }, 0.62)
			local r = { id = b.id, btn = btn, st = st, bg = bgGrad, meta = meta, cost = cost, own = own, q = q, prog = prog, sc = sc, can = nil :: boolean? }
			refs.rows[b.id] = r
			btn.MouseEnter:Connect(function() btn.Position = UDim2.fromOffset(-3, 0); btn.BackgroundTransparency = 0.93 end)
			btn.MouseLeave:Connect(function() btn.Position = UDim2.new(); btn.BackgroundTransparency = 0.955 end)
			btn.Activated:Connect(function()
				local ok = act("buyBuilding", b.id, qty())
				if ok then
					st:SetAttribute("flash", true)
					W.flash(st)
					ui.bought("building", b.id)
				else
					W.shake(btn)
				end
			end)
		end
	end
	W.tip(root, "Astuce : Espace = cliquer le cookie. Les combos rapides déclenchent la FIÈVRE RGB (tout ×3).", 3)
	table.insert(anims, function(t: number)
		for _, r in refs.rows do
			if r.can and not Store.reduced then
				local k = (math.sin(t * math.pi * 2 / 1.6 - math.pi / 2) + 1) / 2
				r.sc.Scale = 1 + 0.06 * k
				r.sc.Parent.Rotation = -3 * k
			elseif r.sc.Scale ~= 1 then
				r.sc.Scale = 1
				r.sc.Parent.Rotation = 0
			end
		end
	end)
end
updaters.shop = function()
	local s, Mm = S(), Mx()
	if not refs.rows then return end
	local q = qty()
	local cps = math.max(1e-9, E.cpsBase(s, Mm))
	for id, r in refs.rows do
		local own = s.buildings[id] or 0
		local mx = E.bMax(s, id)
		local n = q == "max" and math.max(1, mx) or q
		local cost = E.bCost(id, n, own)
		local can = cost <= s.cookies and (q ~= "max" or mx > 0)
		if can ~= r.can then
			r.can = can
			r.bg.Enabled = can
			if can then K.accBind(r.st, "Color", 0, 0.65) else K.accUnbind(r.st); r.st.Color = C.white end
			if not r.st:GetAttribute("flash") then r.st.Transparency = can and 0.25 or 0.93 end
			r.cost.TextColor3 = can and C.lime or C.pink
		end
		r.cost.Text = fmt(cost)
		r.own.Text = tostring(own)
		r.q.Text = n > 1 and ("×" .. n) or ""
		local each = E.buildingCps(s, Mm, id)
		r.meta.Text = own > 0 and (fmt(each) .. "/s chacun · " .. math.floor(each * own / cps * 100 + 0.5) .. " % de ta prod") or (fmt(each) .. "/s chacun")
		r.prog.Size = UDim2.new(clamp(s.cookies / math.max(1, cost), 0, 1), -20, 0, 3)
	end
end
softKeys.shop = function()
	local n = 0
	for i in D.buildings do if E.buildingUnlocked(S(), i) then n += 1 end end
	return tostring(n)
end

---------------------------------------------------------------------------- UPGRADES
local function visLine(u: any): string?
	if not u.vis then return nil end
	local k = u.vis[1]
	local v = P.VIS[k]
	if not v then return nil end
	local cur = (Store.vis or {})[k] or 0
	local mx = (D.visuals[k] and D.visuals[k].max) or 1
	local lvl = (cur > 0 and not S().upgrades[u.id]) and (" (niveau " .. math.min(mx, cur + 1) .. ")") or ""
	local where = v[1] == "cookie" and "Ton cookie gagne" or v[1] == "around" and "Autour du cookie" or "Sur l'écran"
	return where .. " : " .. v[2] .. lvl
end
local function upIcon(u: any): string return u.vis and ("vis:" .. u.vis[1]) or "tab:upgrades" end
local function sortedUpgrades(filter: (any) -> boolean): { any }
	local out = {}
	for _, u in D.upgrades do if filter(u) then table.insert(out, u) end end
	table.sort(out, function(a, b) return a.cost < b.cost end)
	return out
end
renderers.upgrades = function(root: Frame, w: number)
	local s = S()
	local _, right = W.secTitle(root, "Upgrades", 1)
	W.note(right, "Chaque upgrade transforme ton cookie")
	local avail = sortedUpgrades(function(u) return not s.upgrades[u.id] and E.reqMet(s, u) end)
	local locked = sortedUpgrades(function(u) return not s.upgrades[u.id] and not E.reqMet(s, u) end)
	local list = W.col(root, 8, 2)
	refs.cards = {}
	if #avail == 0 then W.empty(list, "Rien à acheter pour l'instant. Continue à cliquer et à construire !") end
	for i, u in avail do
		local c = W.card(list, nil, { LayoutOrder = i })
		K.padding(c, 10)
		local inner = W.col(c, 8)
		local top = W.frame({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = inner })
		local ico, _, g = W.icoBox(top, upIcon(u), 50, 40, "#5a3fb0", 14)
		local txt = W.frame({ Position = UDim2.fromOffset(60, 0), Size = UDim2.new(1, -60, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = top })
		K.vlist(txt, 2)
		W.para(txt, u.name, 16.5, F.display, C.ink, 1)
		W.para(txt, E.fxText(u), 12.5, F.body, C.fxInk, 2)
		local vl = visLine(u)
		if vl then
			local vr = W.row(txt, 4, 3)
			W.icon(vr, "ui:gift", 15, { LayoutOrder = 1 })
			W.text(vr, vl, 12.5, F.bold, C.lime, { LayoutOrder = 2, TextWrapped = true, Size = UDim2.fromOffset(math.max(120, w - 110), 0), AutomaticSize = Enum.AutomaticSize.Y })
		end
		local row = W.frame({ Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 2, Parent = inner })
		local cr, cl = W.itext(row, "ui:cookie", fmt(u.cost), 14, F.num, C.pink)
		cr.AnchorPoint = Vector2.new(0, 0.5)
		cr.Position = UDim2.fromScale(0, 0.5)
		local b = W.btn(row, "ACHETER", "green", { small = true, size = UDim2.fromOffset(96, 32), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, 0, 0.5, 0) }, function()
			if act("buyUpgrade", u.id) then ui.bought("upgrade", u.id); ui.render(true) end
		end)
		local st = c:FindFirstChildOfClass("UIStroke")
		refs.cards[u.id] = { st = st, g = g, ico = ico, cost = cl, btn = b, can = nil :: boolean?, price = u.cost }
	end
	if #locked > 0 then
		W.subTitle(root, "ui:lock", "Bientôt", nil, 3)
		local l2 = W.col(root, 8, 4)
		for i = 1, math.min(3, #locked) do
			local u = locked[i]
			local c = W.card(l2, nil, { LayoutOrder = i })
			K.padding(c, 10)
			local top = W.frame({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = c })
			local ico, im = W.icoBox(top, upIcon(u), 50, 40, "#5a3fb0", 14)
			ico.BackgroundColor3 = Color3.fromRGB(110, 110, 110)
			im.ImageColor3 = Color3.fromRGB(90, 90, 90)
			im.ImageTransparency = math.max(im.ImageTransparency, 0.2)
			local txt = W.frame({ Position = UDim2.fromOffset(60, 0), Size = UDim2.new(1, -60, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = top })
			K.vlist(txt, 2)
			W.para(txt, u.name, 16.5, F.display, Color3.fromHex("#b9b0cf"), 1)
			local vl = visLine(u)
			if vl then W.para(txt, vl, 12.5, F.bold, Color3.fromHex("#8fb34a"), 2) end
			local rr = W.row(txt, 4, 3)
			W.icon(rr, "ui:lock", 15, { LayoutOrder = 1 })
			W.text(rr, E.reqText(u), 12.5, F.body, C.gold, { LayoutOrder = 2 })
		end
	end
	local owned = {}
	for _, u in D.upgrades do if s.upgrades[u.id] then table.insert(owned, u) end end
	W.subTitle(root, "ui:trophy", "Collection", #owned .. " / " .. #D.upgrades, 5)
	if #owned == 0 then
		W.empty(root, "Ta collection est vide. Ton premier upgrade arrive vite !", 6)
	else
		local tiles = W.frame({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 6, Parent = root })
		new("UIGridLayout", { CellSize = UDim2.fromOffset(42, 42), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tiles })
		for i, u in owned do
			local t = W.frame({ BackgroundTransparency = 0, BackgroundColor3 = C.white, LayoutOrder = i, Parent = tiles })
			W.round(t, 12)
			W.stroke(t, C.stroke, 2)
			W.grad(t, Color3.fromHex("#4a3690"), Color3.fromHex("#1d0f45"), 55, 0.7)
			W.icon(t, upIcon(u), 32, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		end
	end
end
updaters.upgrades = function()
	if not refs.cards then return end
	local s = S()
	for _, r in refs.cards do
		local can = r.price <= s.cookies
		if can ~= r.can then
			r.can = can
			if can then
				K.accBind(r.st, "Color", 0, 0.65)
				r.st.Transparency = 0.25
				K.seqBind(r.g, { 0, 0 }, 0.6)
			else
				K.accUnbind(r.st)
				r.st.Color, r.st.Transparency = C.white, 0.93
				K.seqUnbind(r.g)
				r.g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("#5a3fb0")), ColorSequenceKeypoint.new(0.7, Color3.fromHex("#1d0f45")), ColorSequenceKeypoint.new(1, Color3.fromHex("#1d0f45")) })
			end
			r.cost.TextColor3 = can and C.lime or C.pink
			r.btn:setOff(not can)
		end
	end
end
softKeys.upgrades = function()
	local s = S()
	local n, o = 0, 0
	for _, u in D.upgrades do
		if s.upgrades[u.id] then o += 1 elseif E.reqMet(s, u) then n += 1 end
	end
	return n .. "|" .. o
end

---------------------------------------------------------------------------- JEUX
local function mgUnlocked(id: string): boolean return E.minigameUnlocked(S(), id) end
renderers.games = function(root: Frame, w: number)
	local s = S()
	local _, right = W.secTitle(root, "Mini-jeux", 1)
	W.note(right, "Gagne des cookies et des", "ui:gem")
	local cols = w < 300 and 1 or 2
	local grid = W.grid(root, w, 100, ui.mobile and 160 or 176, 10, 2, cols)
	for i, id in MG_ORDER do
		local d, def = P.MG[id], D.MG[id]
		local unlocked = mgUnlocked(id)
		local rec = (s.mg and s.mg[id]) or { best = 0, plays = 0 }
		local gc = Color3.fromHex(d.color)
		local card = W.frame({ BackgroundTransparency = 0, BackgroundColor3 = C.white, LayoutOrder = i, ClipsDescendants = true, Parent = grid })
		W.round(card, 20)
		W.stroke(card, C.stroke, 3)
		new("UIGradient", { Rotation = 60, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, unlocked and gc or K.gray(gc)), ColorSequenceKeypoint.new(0.62, Color3.fromHex("#1d0f45")), ColorSequenceKeypoint.new(1, Color3.fromHex("#1d0f45")) }), Parent = card })
		local emo = W.icon(card, "mg:" .. id, 78, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Rotation = 14, ZIndex = Z })
		if not unlocked then emo.ImageColor3 = Color3.fromRGB(120, 120, 120) end
		local body = W.frame({ Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 1, -38), Parent = card })
		K.vlist(body, 6)
		local nm = W.ol(body, d.name, ui.mobile and 17 or 20, C.white, { LayoutOrder = 1, Size = UDim2.new(0.75, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true })
		nm.TextXAlignment = Enum.TextXAlignment.Left
		W.para(body, d.tagline, 12.5, F.body, Color3.fromHex("#eee6ff"), 2)
		local bottom = W.frame({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.new(1, -24, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
		K.vlist(bottom, 6)
		if unlocked then
			if rec.plays and rec.plays > 0 then
				W.itext(bottom, "ui:trophy", "Record : " .. fmt(rec.best, true) .. " · " .. rec.plays .. " partie" .. (rec.plays > 1 and "s" or ""), 12, F.num, C.gold, 1)
			else
				W.itext(bottom, "ui:sparkle", "Jamais joué", 12, F.num, C.gold, 1)
			end
			W.btn(bottom, "JOUER", "green", { icon = "ui:play", size = UDim2.new(1, 0, 0, 40), layoutOrder = 2 }, function() ui.openMinigame(id) end)
			if (rec.plays or 0) == 0 then
				local rib = W.text(card, "NOUVEAU", 12, F.display, C.white, { Position = UDim2.fromOffset(10, -2), BackgroundTransparency = 0, BackgroundColor3 = C.red })
				K.padding(rib, 5, 8, 3, 8)
				W.round(rib, 8)
				W.stroke(rib, C.stroke, 2)
			end
		else
			W.itext(bottom, "ui:lock", def.text, 12.5, F.body, C.white, 1)
			local _, fill = W.mprog(bottom, 10, 2)
			fill.Size = UDim2.fromScale(clamp(s.allTimeBaked / def.baked, 0, 1), 1)
		end
	end
	W.tip(root, "Les mini-jeux utilisent TON cookie (skin + accessoires). Récompenses indexées sur ta production.", 3)
end
softKeys.games = function()
	local parts = {}
	for i, id in MG_ORDER do
		local def = D.MG[id]
		parts[i] = mgUnlocked(id) and "u" or tostring(math.floor(clamp(S().allTimeBaked / def.baked, 0, 1) * 40))
	end
	return table.concat(parts, ",")
end

---------------------------------------------------------------------------- PETS
local function rarityColor(r: string): Color3
	return Color3.fromHex((D.rarities[r] or D.rarities.common).color)
end
function P.equippedPets(): { any }
	return E.equippedPets(S())
end
local function rarityStroke(st: UIStroke, rarity: string, off: number?)
	if rarity == "mythic" then K.rgbBind(st, off) else st.Color = rarityColor(rarity) end
end
renderers.pets = function(root: Frame, w: number)
	local s = S()
	local slotsN = (Store.mult and Store.mult.petSlots) or 3
	local _, right = W.secTitle(root, "Pets", 1)
	W.note(right, slotsN .. " pets équipés max")
	local eq = P.equippedPets()
	local slots = W.grid(root, w, 60, 76, 8, 2, 3)
	for i = 1, slotsN do
		local p = eq[i]
		local sl = W.frame({ BackgroundTransparency = 0.8, BackgroundColor3 = C.black, LayoutOrder = i, Parent = slots })
		W.round(sl, 16)
		if p then
			local st = W.stroke(sl, C.white, 3)
			rarityStroke(st, p.def.rarity, i * 0.3)
			local g = W.icon(sl, "fx:glow", 70, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ImageColor3 = rarityColor(p.def.rarity), ImageTransparency = 0.55 })
			g.ScaleType = Enum.ScaleType.Stretch
			W.icon(sl, "pet:" .. p.def.id, 54, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
			if p.lvl > 1 then W.text(sl, "Nv." .. p.lvl, 11, F.display, C.gold, { Position = UDim2.fromOffset(6, 3) }) end
		else
			W.stroke(sl, C.white, 2, 0.82)
			W.text(sl, "Slot libre", 12, F.body, C.muted, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		end
	end
	local Mm = Mx()
	W.para(root, #eq > 0 and ("Bonus pets : Prod +" .. math.floor((Mm.petCps - 1) * 100 + 0.5) .. " % · Clic +" .. math.floor((Mm.petClick - 1) * 100 + 0.5) .. " %") or "Équipe un pet pour booster ta prod", 13, F.bold, C.lime, 3, Enum.TextXAlignment.Center)
	W.subTitle(root, "tab:pets", "Œufs", "doublon = niveau +1", 4)
	local eggs = W.grid(root, w, 90, 206, 8, 5, 3)
	refs.eggs = {}
	for i, e in D.eggs do
		local c = W.card(eggs, nil, { LayoutOrder = i, Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None })
		local col = W.frame({ Size = UDim2.new(1, -16, 1, -20), Position = UDim2.fromOffset(8, 10), Parent = c })
		K.vlist(col, 6, Enum.HorizontalAlignment.Center)
		local ehold = W.frame({ Size = UDim2.fromOffset(66, 66), LayoutOrder = 1, Parent = col })
		local eimg = W.icon(ehold, "egg:" .. e.id, 66, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		local nm = W.ol(col, e.name, 14.5, C.white, { LayoutOrder = 2 })
		nm.TextXAlignment = Enum.TextXAlignment.Center
		local odds = W.frame({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = col })
		K.vlist(odds, 0, Enum.HorizontalAlignment.Center)
		for j, o in e.odds do
			local R = D.rarities[o[1]]
			W.text(odds, R.name .. " " .. o[2] .. " %", 11, F.body, o[1] == "mythic" and Color3.fromHex("#ff6be6") or Color3.fromHex(R.color), { LayoutOrder = j })
		end
		local b = W.btn(col, " " .. e.cost, "gold", { small = true, icon = "ui:gem", size = UDim2.new(1, 0, 0, 32), layoutOrder = 4 }, function() ui.hatch(e.id) end)
		refs.eggs[e.id] = { btn = b, cost = e.cost }
		local ph = i * 0.8
		table.insert(anims, function(t: number)
			if Store.reduced then return end
			local k = math.sin((t + ph) * math.pi * 2 / 2.4)
			eimg.Position = UDim2.new(0.5, 0, 0.5, -2 - 2 * k)
			eimg.Rotation = 1.5 + 1.5 * k
		end)
	end
	-- Robux : pass Œufs Chanceux / VIP (upsell discret dans le style du site)
	local up = W.col(root, 6, 6)
	if not Store.passes.LuckyEggs then
		W.btn(up, "Œufs Chanceux : 30 % de relance vers mieux", "dark", { small = true, icon = "egg:neon", size = UDim2.new(1, 0, 0, 34), layoutOrder = 1 }, function() ui.buyPass("LuckyEggs") end)
	end
	if not Store.passes.VIP then
		W.btn(up, "VIP : +2 emplacements de pets", "dark", { small = true, icon = "ui:crown", size = UDim2.new(1, 0, 0, 34), layoutOrder = 2 }, function() ui.buyPass("VIP") end)
	end
	W.subTitle(root, "ui:heart", "Inventaire", #s.pets .. " / " .. #D.pets, 7)
	if #s.pets == 0 then
		W.empty(root, "Ouvre un œuf pour obtenir ton premier pet ! Les gemmes se gagnent avec les succès, les quêtes, les boss et les mini-jeux.", 8)
	else
		local list = table.clone(s.pets)
		table.sort(list, function(a, b)
			local ra, rb = RORD[D.PET[a.id].rarity], RORD[D.PET[b.id].rarity]
			if ra ~= rb then return ra < rb end
			return a.lvl > b.lvl
		end)
		local inv = W.grid(root, w, 82, 108, 8, 8)
		for i, p in list do
			local d = D.PET[p.id]
			local isEq = table.find(s.equipped, p.uid) ~= nil
			local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.white, BackgroundTransparency = 0.95, LayoutOrder = i, ZIndex = Z, Parent = inv })
			W.round(b, 16)
			local st = W.stroke(b, C.white, 3)
			rarityStroke(st, d.rarity, i * 0.13)
			local g = W.icon(b, "fx:glow", 64, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 34), ImageColor3 = rarityColor(d.rarity), ImageTransparency = 0.6 })
			g.ScaleType = Enum.ScaleType.Stretch
			W.icon(b, "pet:" .. d.id, 48, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 9) })
			W.text(b, d.name, 11.5, F.bold, C.ink, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.new(1, -8, 0, 28), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 0.95 })
			W.text(b, D.rarities[d.rarity].name, 10.5, F.display, d.rarity == "mythic" and Color3.fromHex("#ff2bd6") or rarityColor(d.rarity), { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6) })
			if p.lvl > 1 then W.text(b, "Nv." .. p.lvl, 11, F.display, C.gold, { Position = UDim2.fromOffset(6, 3) }) end
			if isEq then
				local ck = W.frame({ BackgroundTransparency = 0, BackgroundColor3 = C.green, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -16, 0, -8), ZIndex = Z + 2, Parent = b })
				W.round(ck)
				W.stroke(ck, C.stroke, 2)
				W.icon(ck, "ui:check", 15, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = Z + 3 })
			end
			b.Activated:Connect(function()
				local res = act("equip", p.uid)
				if type(res) == "table" and res.err then ui.toast(res.err, "#ff4d6d", "tab:pets") end
				ui.render(true)
			end)
		end
	end
end
updaters.pets = function()
	if not refs.eggs then return end
	for _, r in refs.eggs do r.btn:setOff(S().gems < r.cost) end
end
softKeys.pets = function()
	local s = S()
	return #s.pets .. "|" .. table.concat(s.equipped, ",") .. "|" .. tostring(Store.mult and Store.mult.petSlots) .. (Store.passes.LuckyEggs and "L" or "") .. (Store.passes.VIP and "V" or "")
end

---------------------------------------------------------------------------- STYLE
renderers.style = function(root: Frame, w: number)
	local s = S()
	local _, right = W.secTitle(root, "Style", 1)
	W.note(right, "Skins & thèmes avec tes", "ui:gem")
	W.subTitle(root, "ui:cookie", "Skins du cookie", nil, 2)
	local grid = W.grid(root, w, 96, 128, 8, 3)
	local thumbs = {}
	for i, sk in D.skins do
		local owned = s.skinsOwned[sk.id] == true
		local cur = s.skin == sk.id
		local gated = sk.unlock ~= nil and not owned
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.white, BackgroundTransparency = 0.95, LayoutOrder = i, ZIndex = Z, Parent = grid })
		W.round(b, 16)
		local st = W.stroke(b, C.white, 2, 0.92)
		if cur then K.accBind(st, "Color", 0, 0.62); st.Transparency = 0 end
		local im = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(64 * 1.6, 64 * 1.6), ZIndex = Z, Parent = b })
		-- l'image du cookie fait 3,2 r : r = 50 px dans un canvas de 128 affiché en 64 → 25 px → image 80 px
		im.Size = UDim2.fromOffset(80, 80)
		im.Position = UDim2.new(0.5, 0, 0, -1)
		if not K.trySet(im, "cookie:" .. sk.id) then K.setImg(im, "ui:cookie", "🍪") end
		if gated then im.ImageColor3 = Color3.fromRGB(50, 50, 50) end
		table.insert(thumbs, { im, #sk.id })
		W.text(b, sk.name, 13.5, F.display, C.ink, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 76), Size = UDim2.new(1, -8, 0, 30), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 0.95 })
		local pr = W.row(b, 3, 0)
		pr.AnchorPoint = Vector2.new(0.5, 1)
		pr.Position = UDim2.new(0.5, 0, 1, -7)
		if cur then
			W.text(pr, "ÉQUIPÉ", 12, F.num, C.cyan, { LayoutOrder = 2 })
		elseif owned then
			W.text(pr, "Équiper", 12, F.num, C.lime, { LayoutOrder = 2 })
		elseif gated then
			W.icon(pr, "ui:lock", 14, { LayoutOrder = 1 })
			W.text(pr, sk.unlock.text, 11, F.num, C.pink, { LayoutOrder = 2, TextWrapped = true, Size = UDim2.fromOffset(math.max(60, w / math.max(1, math.floor((w + 8) / 104)) - 30), 0), AutomaticSize = Enum.AutomaticSize.Y })
		else
			W.icon(pr, "ui:gem", 14, { LayoutOrder = 1 })
			W.text(pr, tostring(sk.cost), 12, F.num, s.gems >= sk.cost and C.lime or C.pink, { LayoutOrder = 2 })
		end
		b.Activated:Connect(function()
			if cur then return end
			if gated and sk.unlock.pass then ui.buyPass(sk.unlock.pass); return end
			if act("skin", sk.id) then
				ui.render(true)
			elseif gated then
				ui.toast(sk.unlock.text .. " pour débloquer ce skin.", "#ff4d6d", "ui:lock")
			elseif not owned then
				ui.toast("Il te faut " .. sk.cost .. " gemmes pour ce skin.", "#ff4d6d", "ui:gem")
			end
		end)
	end
	table.insert(anims, function(t: number)
		for _, th in thumbs do th[1].Rotation = math.deg(math.sin(t * 1.2 + th[2]) * 0.15) end
	end)
	W.subTitle(root, "tab:style", "Thèmes du décor", nil, 4)
	local tg = W.grid(root, w, 120, 92, 8, 5)
	for i, th in D.themes do
		local owned = s.themesOwned[th.id] == true
		local cur = s.theme == th.id
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.black, LayoutOrder = i, ZIndex = Z, ClipsDescendants = true, Parent = tg })
		W.round(b, 13)
		local st = W.stroke(b, C.stroke, 3)
		if cur then K.accBind(st, "Color", 0, 0.62) end
		local pv = W.frame({ BackgroundTransparency = 0, BackgroundColor3 = C.white, Size = UDim2.new(1, 0, 0, 58), Parent = b })
		local seq, rot = Background.previewSeq(th.id)
		new("UIGradient", { Color = seq, Rotation = rot, Parent = pv })
		local info = W.frame({ BackgroundTransparency = 0.05, BackgroundColor3 = Color3.fromRGB(15, 8, 38), Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58), Parent = b })
		W.text(info, th.name, 13.5, F.display, C.ink, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.new(1, -60, 0, 18), AutomaticSize = Enum.AutomaticSize.None, TextTruncate = Enum.TextTruncate.AtEnd })
		local tp = W.row(info, 2, 0)
		tp.AnchorPoint = Vector2.new(1, 0.5)
		tp.Position = UDim2.new(1, -8, 0.5, 0)
		local col = cur and C.cyan or ((owned or s.gems >= th.cost) and C.lime or C.pink)
		if cur then W.text(tp, "ACTIF", 12, F.num, col)
		elseif owned then W.text(tp, "Choisir", 12, F.num, col)
		else
			W.icon(tp, "ui:gem", 14, { LayoutOrder = 1 })
			W.text(tp, tostring(th.cost), 12, F.num, col, { LayoutOrder = 2 })
		end
		b.Activated:Connect(function()
			if cur then return end
			if act("theme", th.id) then ui.render(true)
			else ui.toast("Il te faut " .. th.cost .. " gemmes pour ce thème.", "#ff4d6d", "ui:gem") end
		end)
	end
	local drip = {}
	for k, lvl in Store.vis or {} do table.insert(drip, { k, lvl }) end
	table.sort(drip, function(a, b) return a[1] < b[1] end)
	W.subTitle(root, "ui:sparkle", "Ton drip actuel", #drip .. " effets", 6)
	if #drip == 0 then
		W.empty(root, "Aucun accessoire. Achète des upgrades pour pimper ton cookie !", 7)
	else
		local wrap = W.frame({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 7, Parent = root })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = wrap })
		for i, d in drip do
			local v = P.VIS[d[1]]
			P.chip(wrap, "vis:" .. d[1], (v and v[2] or d[1]) .. (d[2] > 1 and (" ×" .. d[2]) or ""), i)
		end
	end
end
-- pastille .buff (drip, buffs du HUD)
function P.chip(parent: Instance, key: string, label: string, order: number?): (Frame, TextLabel)
	local f = W.frame({ BackgroundTransparency = 0.2, BackgroundColor3 = Color3.fromRGB(10, 5, 30), Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order or 0, Parent = parent })
	W.round(f)
	W.stroke(f, C.stroke, 2)
	K.padding(f, 3, 10, 3, 4)
	K.hlist(f, 6)
	local e = W.frame({ BackgroundTransparency = 0.9, BackgroundColor3 = C.white, Size = UDim2.fromOffset(22, 22), LayoutOrder = 1, Parent = f })
	W.round(e)
	W.icon(e, key, 18, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local l = W.text(f, label, 14, F.display, C.ink, { LayoutOrder = 2 })
	return f, l
end
softKeys.style = function()
	local s = S()
	local n = 0
	for _ in Store.vis or {} do n += 1 end
	return s.gems .. "|" .. s.skin .. "|" .. s.theme .. "|" .. n
end

---------------------------------------------------------------------------- QUÊTES
local function questText(q: any): string
	for _, d in D.quests do
		if d.type == q.type then
			local n = d.fmt and fmt(q.target, true) or tostring(q.target)
			return (string.gsub(d.text, "{n}", n))
		end
	end
	return "Quête"
end
local function gemInline(parent: Instance, prefix: string, n: number, size: number, color: Color3, order: number?)
	local r = W.row(parent, 2, order)
	W.text(r, prefix .. n, size, F.display, color, { LayoutOrder = 1 })
	W.icon(r, "ui:gem", math.floor(size * 1.15), { LayoutOrder = 2 })
	return r
end
renderers.quests = function(root: Frame, w: number)
	local s = S()
	local _, right = W.secTitle(root, "Quêtes", 1)
	W.note(right, "Des gemmes à gratter en boucle")
	local ql = W.col(root, 8, 2)
	refs.quests = {}
	for i, q in s.quests or {} do
		local c = W.card(ql, 76, { LayoutOrder = i })
		if q.done then
			local st = c:FindFirstChildOfClass("UIStroke")
			if st then st.Color, st.Transparency = C.lime, 0 end
			c.BackgroundTransparency = 0
			c.BackgroundColor3 = C.white
			new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(182, 255, 59), C.white), Transparency = NumberSequence.new(0.86, 0.96), Parent = c })
		end
		W.icon(c, QUEST_ICON[q.type] or "tab:quests", 36, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 13, 0.5, 0) })
		local mid = W.frame({ Position = UDim2.fromOffset(62, 10), Size = UDim2.new(1, -62 - 122, 1, -20), Parent = c })
		W.text(mid, questText(q), 14, F.bold, C.ink, { Size = UDim2.new(1, 0, 0, 34), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1 })
		local pr = W.frame({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 16), Parent = mid })
		local bar, fill = W.mprog(pr, 10, 0, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, -74, 0, 8) })
		local _ = bar
		local qt = W.text(pr, "", 12, F.num, C.muted, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), TextXAlignment = Enum.TextXAlignment.Right })
		local acts = W.frame({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(112, 60), Parent = c })
		local actsL = K.vlist(acts, 5, Enum.HorizontalAlignment.Center)
		actsL.VerticalAlignment = Enum.VerticalAlignment.Center
		if q.done then
			W.btn(acts, "RÉCLAMER +" .. q.gems, "gold", { small = true, icon = "ui:gem", iconAfter = true, size = UDim2.fromOffset(112, 34), textSize = 13 }, function()
				local g = act("claimQuest", q.id)
				if g then ui.toast("+" .. tostring(g) .. " gemmes récupérées !", "#b6ff3b", "ui:gem"); ui.render(true) end
			end)
		else
			gemInline(acts, "+", q.gems, 14, C.gold, 1)
			W.btn(acts, "3", "dark", { small = true, icon = "ui:dice", size = UDim2.fromOffset(70, 28), textSize = 13, layoutOrder = 2 }, function()
				if act("rerollQuest", q.id) then ui.render(true) else ui.toast("Il faut 3 gemmes pour changer de quête.", "#ff4d6d", "ui:dice") end
			end)
		end
		refs.quests[q.id] = { fill = fill, qt = qt }
	end
	local got = 0
	for _, a in D.achievements do if s.achievements[a.id] then got += 1 end end
	W.subTitle(root, "ui:trophy", "Succès", got .. " / " .. #D.achievements .. " · +" .. got .. " % de prod", 3)
	local achs = W.grid(root, w, 46, 46, 6, 4)
	local info = W.frame({ BackgroundTransparency = 0.75, BackgroundColor3 = C.black, Size = UDim2.new(1, 0, 0, 40), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = root })
	W.round(info, 12)
	K.padding(info, 8, 10, 8, 10)
	local infoL = W.para(info, "Touche un badge pour voir le détail.", 13, F.body, C.ink)
	for i, a in D.achievements do
		local ok = s.achievements[a.id] ~= nil
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.white, BackgroundTransparency = ok and 0 or 0.96, LayoutOrder = i, ZIndex = Z, Parent = achs })
		W.round(b, 14)
		W.stroke(b, C.stroke, 2)
		if ok then W.grad(b, Color3.fromHex("#6a4fd0"), Color3.fromHex("#231255"), 55, 0.7) end
		local im = W.icon(b, P.achIcon(a.id), ok and 28 or 20, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		if not ok then im.ImageColor3 = Color3.fromRGB(110, 110, 110); im.ImageTransparency = math.max(im.ImageTransparency, 0.4) end
		b.Activated:Connect(function()
			infoL.Text = "<b>" .. a.name .. "</b>\n<font color=\"#b3a6dd\">" .. a.desc .. " · +" .. a.gems .. " 💎</font>"
		end)
	end
	W.subTitle(root, "ui:chart", "Stats", nil, 6)
	local st = s.stats or {}
	local stats = W.grid(root, w, 100, 50, 6, 7, 2)
	local function stat(i: number, k: string, v: string)
		local f = W.frame({ BackgroundTransparency = 0.78, BackgroundColor3 = C.black, LayoutOrder = i, Parent = stats })
		W.round(f, 12)
		K.padding(f, 8, 10, 8, 10)
		K.vlist(f, 1)
		W.text(f, k, 11.5, F.body, C.muted, { LayoutOrder = 1 })
		W.text(f, v, 15, F.num, C.ink, { LayoutOrder = 2 })
	end
	local live = Store.live or {}
	stat(1, "Cookies produits (total)", fmt(s.allTimeBaked))
	stat(2, "Cette vie", fmt(s.totalBaked))
	stat(3, "Clics", fmt(s.clicks, true))
	stat(4, "Production", fmt(live.cpsBase or 0) .. "/s")
	stat(5, "Combo max", fmt(st.maxCombo or 0, true))
	stat(6, "Fièvres", tostring(st.fevers or 0))
	stat(7, "Cookies dorés", tostring(st.golden or 0))
	stat(8, "Boss vaincus", tostring(st.bossKills or 0))
	stat(9, "Œufs ouverts", tostring(st.eggs or 0))
	stat(10, "Temps de jeu", K.fmtDur(st.playTime or 0))
end
updaters.quests = function()
	if not refs.quests then return end
	for _, q in S().quests or {} do
		local r = refs.quests[q.id]
		if r then
			r.fill.Size = UDim2.fromScale(clamp(q.progress / math.max(1, q.target), 0, 1), 1)
			r.qt.Text = fmt(math.floor(q.progress), true) .. " / " .. fmt(q.target, true)
		end
	end
end
softKeys.quests = function()
	local parts = {}
	for i, q in S().quests or {} do parts[i] = q.id .. (q.done and "d" or "") end
	local n = 0
	for _ in S().achievements do n += 1 end
	return table.concat(parts, ",") .. "|" .. n
end

---------------------------------------------------------------------------- REBIRTH
local rbArmed = 0
renderers.rebirth = function(root: Frame, _w: number)
	local s = S()
	local gain = E.rebirthGain(s)
	local nextNeed = (gain + 1) ^ 2 * E.REBIRTH_MIN
	local prevNeed = gain > 0 and gain ^ 2 * E.REBIRTH_MIN or 0
	local pct = clamp((s.totalBaked - prevNeed) / (nextNeed - prevNeed), 0, 1)
	local hero = W.frame({ BackgroundTransparency = 0.75, BackgroundColor3 = C.black, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = root })
	W.round(hero, 22)
	W.stroke(hero, C.stroke, 3)
	-- halo coloré en haut (radial-gradient hsl(var(--h) 90% 45% / .5))
	local halo = W.icon(hero, "fx:glow", 10, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(1.3, 1.1), ImageTransparency = 0.45, ZIndex = Z })
	halo.ScaleType = Enum.ScaleType.Stretch
	K.accBind(halo, "ImageColor3", 0, 0.45, 0.9)
	K.padding(hero, 16, 12, 16, 12)
	local col = W.frame({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = hero })
	K.vlist(col, 6, Enum.HorizontalAlignment.Center)
	local big = W.row(col, 8, 1)
	W.icon(big, "tab:rebirth", 46, { LayoutOrder = 1 })
	local bl = W.ol(big, "REBIRTH", 46, C.white, { LayoutOrder = 2 })
	K.ol(bl, 3)
	local line = W.row(col, 4, 2)
	W.icon(line, "ui:star", 17, { LayoutOrder = 1 })
	W.text(line, fmt(s.stars, true) .. " étoile" .. (s.stars > 1 and "s" or "") .. " → +" .. fmt(s.stars * 10, true) .. " % sur tout · " .. s.rebirths .. " rebirth" .. (s.rebirths > 1 and "s" or ""), 14, F.bold, C.ink, { LayoutOrder = 2 })
	local g = W.row(col, 6, 3)
	if gain >= 1 then
		W.ol(g, "+" .. fmt(gain, true), 30, C.gold, { LayoutOrder = 1 })
		W.icon(g, "ui:star", 32, { LayoutOrder = 2 })
		W.ol(g, "si tu renais maintenant", 30, C.gold, { LayoutOrder = 3 })
		local gl = g:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		gl.Wraps = true
		gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		g.AutomaticSize = Enum.AutomaticSize.Y
		g.Size = UDim2.fromScale(1, 0)
	else
		W.ol(g, "Pas encore…", 30, C.gold)
	end
	W.para(col, gain >= 1 and ("Prochaine étoile à " .. fmt(nextNeed) .. " cookies (cette vie)") or ("Produis " .. fmt(E.REBIRTH_MIN) .. " cookies dans cette vie pour ta 1ʳᵉ étoile"), 13, F.body, C.muted, 4, Enum.TextXAlignment.Center)
	local _, fill = W.mprog(col, 10, 5)
	fill.Size = UDim2.fromScale(pct, 1)
	local b
	b = W.btn(col, gain >= 1 and ("REBIRTH  +" .. fmt(gain, true)) or "REBIRTH verrouillé", "gold", { big = true, icon = gain >= 1 and "ui:star" or nil, iconAfter = true, size = UDim2.new(1, 0, 0, 58), layoutOrder = 6 }, function()
		if gain < 1 then return end
		if os.clock() - rbArmed > 3.5 then
			rbArmed = os.clock()
			b:setText("SÛR ? CLIQUE ENCORE !")
			if b.icon then b.icon.Visible = false end
			b:setKind("red")
			task.delay(3.6, function()
				if rbArmed > 0 and os.clock() - rbArmed >= 3.5 and b.root.Parent then rbArmed = 0; ui.render(true) end
			end)
			return
		end
		rbArmed = 0
		local got = act("rebirth")
		if got then ui.rebirthFx(got) end
	end)
	b:setOff(gain < 1)
	local cols = W.grid(root, 200, 100, 150, 8, 2, 2)
	local function box(i: number, key: string, title: string, lines: { string })
		local f = W.frame({ BackgroundTransparency = 0.75, BackgroundColor3 = C.black, LayoutOrder = i, Parent = cols })
		W.round(f, 14)
		K.padding(f, 10)
		K.vlist(f, 2)
		W.itext(f, key, title, 15, F.display, C.ink, 0)
		for j, l in lines do W.para(f, l, 13, F.body, C.ink, j) end
		return f
	end
	box(1, "ui:skull", "Tu perds", { "Cookies", "Bâtiments", "Upgrades (et leurs effets sur le cookie)" })
	box(2, "ui:gem", "Tu gardes", { "Gemmes, pets, skins, thèmes", "Succès et records", '<b><font color="#ffc93c">+10 % par étoile, pour toujours</font></b>', '<b><font color="#1ff4ff">+10 gemmes par étoile gagnée</font></b>' })
	W.tip(root, "Le skin Néant se débloque au 3ᵉ rebirth.", 3)
end
softKeys.rebirth = function()
	local s = S()
	local g = E.rebirthGain(s)
	return g .. "|" .. math.floor(clamp(s.totalBaked / ((g + 1) ^ 2 * E.REBIRTH_MIN), 0, 1) * 50) .. "|" .. s.rebirths
end
function P.rebirthArmed(): boolean return os.clock() - rbArmed < 3.5 end

---------------------------------------------------------------------------- OPTIONS (+ classement)
local function leaderboard(): { any }
	local v = RS:FindFirstChild("Leaderboard")
	if not v or not v:IsA("StringValue") or v.Value == "" then return {} end
	local ok, rows = pcall(HttpService.JSONDecode, HttpService, v.Value)
	return ok and type(rows) == "table" and rows or {}
end
renderers.options = function(root: Frame, _w: number)
	W.secTitle(root, "Options", 1)
	local shop = W.col(root, 8, 2)
	W.btn(shop, "BOUTIQUE ROBUX", "green", { icon = "ui:gem", size = UDim2.new(1, 0, 0, 46), layoutOrder = 1 }, function() ui.openRobux() end)
	W.subTitle(root, "ui:sparkle", "Visuel", nil, 3)
	local opts = W.col(root, 8, 4)
	local st = P.settings
	W.seg(W.opt(opts, "Particules", "Baisse si ça rame", 1), { { 0, "Éco" }, { 1, "Normal" }, { 2, "ULTRA" } }, st.particles, function(v)
		st.particles = v
		st.pm = ({ [0] = 0.22, [1] = 0.55, [2] = 1 })[v] or 1
		ui.applySettings()
		ui.render(true)
	end)
	W.switch(W.opt(opts, "Tremblements d'écran", nil, 2), st.shake, function(on) st.shake = on; ui.applySettings() end)
	W.switch(W.opt(opts, "Mouvements réduits", "Moins de flashs et d'animations", 3), st.reduced, function(on) st.reduced = on; ui.applySettings() end)
	if Store.passes.AutoClicker then
		W.switch(W.opt(opts, "Auto-Clicker", "6 clics par seconde, tout seul", 4), S().autoClick == true, function(on) act("autoClick", on) end)
	end
	W.subTitle(root, "ui:trophy", "Classement mondial", "cookies produits", 5)
	local rows = leaderboard()
	refs.lbKey = RS:FindFirstChild("Leaderboard") and (RS.Leaderboard :: StringValue).Value or ""
	if #rows == 0 then
		W.empty(root, "Le classement se met à jour toutes les quelques minutes.", 6)
	else
		local list = W.col(root, 4, 6)
		local me = Players.LocalPlayer.Name
		for i, r in rows do
			if i > 50 then break end
			local c = W.card(list, 34, { LayoutOrder = i }, 12)
			if r.name == me then
				local s2 = c:FindFirstChildOfClass("UIStroke")
				if s2 then K.accBind(s2, "Color", 0, 0.62); s2.Transparency = 0 end
			end
			local rc = (r.rank == 1 and C.gold) or (r.rank == 2 and Color3.fromHex("#e0e6ff")) or (r.rank == 3 and Color3.fromHex("#ff9a5a")) or C.muted
			W.text(c, "#" .. tostring(r.rank), 14, F.display, rc, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0) })
			W.text(c, tostring(r.name), 14, F.bold, C.ink, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 52, 0.5, 0), Size = UDim2.new(1, -160, 0, 18), AutomaticSize = Enum.AutomaticSize.None, TextTruncate = Enum.TextTruncate.AtEnd })
			local vr = W.itext(c, "ui:cookie", fmt(tonumber(r.value) or 0), 13, F.num, C.lime)
			vr.AnchorPoint = Vector2.new(1, 0.5)
			vr.Position = UDim2.new(1, -10, 0.5, 0)
		end
	end
end
softKeys.options = function()
	local v = RS:FindFirstChild("Leaderboard")
	return (v and v:IsA("StringValue") and #v.Value or 0) .. "|" .. tostring(Store.passes.AutoClicker) .. tostring(S().autoClick)
end

---------------------------------------------------------------------------- BOUTIQUE ROBUX
renderers.robux = function(root: Frame, _w: number)
	local _, right = W.secTitle(root, "Boutique", 1)
	W.btn(right, "Retour", "dark", { small = true, icon = "ui:close", size = UDim2.fromOffset(96, 30) }, function() ui.setTab(ui.prevTab or "shop") end)
	W.para(root, "Soutiens le jeu et booste ta boulangerie. Les achats passent par la fenêtre officielle Roblox.", 12.5, F.body, C.muted, 2)
	W.subTitle(root, "ui:crown", "Game Passes", "pour toujours", 3)
	local list = W.col(root, 8, 4)
	for i, p in M.passes do
		local owned = Store.passes[p.key] == true
		local c = W.card(list, nil, { LayoutOrder = i })
		K.padding(c, 10)
		if owned then local s2 = c:FindFirstChildOfClass("UIStroke"); if s2 then s2.Color, s2.Transparency = C.lime, 0.3 end end
		local top = W.frame({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = c })
		W.icoBox(top, P.PASS_ICON[p.key] or "ui:star", 50, 40, "#5a3fb0", 14)
		local txt = W.frame({ Position = UDim2.fromOffset(60, 0), Size = UDim2.new(1, -60 - 104, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = top })
		K.vlist(txt, 2)
		W.para(txt, p.name, 16.5, F.display, C.ink, 1)
		W.para(txt, p.desc or "", 12.5, F.body, C.fxInk, 2)
		local b = W.btn(top, owned and "ACQUIS" or ("R$ " .. p.price), owned and "dark" or "green", { small = true, size = UDim2.fromOffset(96, 34), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, 0, 0.5, 0), icon = owned and "ui:check" or nil }, function()
			if not owned then ui.buyPass(p.key) end
		end)
		b:setOff(owned)
	end
	W.subTitle(root, "ui:gem", "Gemmes & bonus", "achats répétables", 5)
	local grid = W.col(root, 8, 6)
	for i, p in M.products do
		local c = W.card(grid, nil, { LayoutOrder = i })
		K.padding(c, 10)
		local top = W.frame({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = c })
		W.icoBox(top, P.PROD_ICON[p.kind] or "ui:gem", 50, 40, "#5a3fb0", 14)
		local txt = W.frame({ Position = UDim2.fromOffset(60, 0), Size = UDim2.new(1, -60 - 104, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = top })
		K.vlist(txt, 2)
		local nr = W.row(txt, 6, 1)
		W.text(nr, p.name, 16.5, F.display, C.ink, { LayoutOrder = 1 })
		if p.tag then
			local tag = W.text(nr, p.tag, 11, F.display, C.white, { LayoutOrder = 2, BackgroundTransparency = 0, BackgroundColor3 = C.red })
			K.padding(tag, 2, 6, 2, 6)
			W.round(tag, 8)
			W.stroke(tag, C.stroke, 2)
		end
		W.para(txt, p.desc or (p.kind == "gems" and "Pour les œufs, skins et thèmes" or p.kind == "fever" and "Déclenche la FIÈVRE RGB (tout ×3) tout de suite" or ""), 12.5, F.body, C.fxInk, 2)
		W.btn(top, "R$ " .. p.price, "gold", { small = true, size = UDim2.fromOffset(96, 34), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, 0, 0.5, 0) }, function() ui.buyProduct(p.key) end)
	end
end
softKeys.robux = function()
	local k = {}
	for key in Store.passes do table.insert(k, key) end
	table.sort(k)
	return table.concat(k, ",")
end

---------------------------------------------------------------------------- API
function P.render(tab: string, root: Frame, width: number)
	refs = {}
	anims = {}
	local fn = renderers[tab]
	if fn and S() then
		local ok, err = pcall(fn, root, width)
		if not ok then warn("[Panel] " .. tab .. " : " .. tostring(err)) end
	end
	P.update(tab)
end
function P.update(tab: string)
	local fn = updaters[tab]
	if fn and S() then
		local ok, err = pcall(fn)
		if not ok then warn("[Panel] maj " .. tab .. " : " .. tostring(err)) end
	end
end
function P.softKey(tab: string): string
	local fn = softKeys[tab]
	if not fn or not S() then return "" end
	local ok, k = pcall(fn)
	return ok and k or ""
end
-- pastilles des onglets (updateBadges du site)
function P.badges(): { [string]: number }
	local s = S()
	if not s then return {} end
	local b = { upgrades = 0, quests = 0, games = 0, pets = 0, rebirth = 0 }
	for _, u in D.upgrades do
		if not s.upgrades[u.id] and E.reqMet(s, u) and u.cost <= s.cookies then b.upgrades += 1 end
	end
	for _, q in s.quests or {} do if q.done then b.quests += 1 end end
	for _, id in MG_ORDER do
		if E.minigameUnlocked(s, id) and not (s.mg and s.mg[id] and (s.mg[id].plays or 0) > 0) then b.games += 1 end
	end
	local canEgg = false
	for _, e in D.eggs do if s.gems >= e.cost then canEgg = true end end
	b.pets = (canEgg and #s.pets < 3) and 1 or 0
	b.rebirth = (E.rebirthGain(s) >= 1 and s.rebirths == 0) and 1 or 0
	return b
end
P.questText = questText
P.MG_ORDER = MG_ORDER

function P.init(uiModule: any, store: any, actFn: (string, ...any) -> any)
	ui = uiModule
	Store = store
	act = actFn
end

return P
