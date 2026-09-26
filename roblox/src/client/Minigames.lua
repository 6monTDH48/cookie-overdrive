-- COOKIE OVERDRIVE — les 4 mini-jeux (interface 2D)
-- Le gameplay tourne côté client ; la récompense est calculée et plafonnée par le serveur.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local D = require(RS.Shared.GameData)
local K = require(script.Parent.Kit)
local new, Cc = K.new, K.colors

local MG = {}
local act, UI
local overlay, arena, hudLabel, conn, inputConns = nil, nil, nil, nil, {}
local running = false

local function cleanup()
	running = false
	if conn then conn:Disconnect(); conn = nil end
	for _, c in inputConns do c:Disconnect() end
	inputConns = {}
end

local function close()
	cleanup()
	if overlay then overlay:Destroy(); overlay = nil end
	act("mgClose")
end

local function shell(title)
	if overlay then overlay:Destroy() end
	overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Cc.bg, BackgroundTransparency = 0.08, ZIndex = 40, Active = true, Parent = UI.gui })
	K.label(title, 30, { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 36), Parent = overlay })
	hudLabel = K.label("", 22, { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 28), TextColor3 = Cc.cyan, Parent = overlay })
	K.button("✕ Quitter", Cc.red, { Position = UDim2.new(1, -130, 0, 10), Size = UDim2.fromOffset(120, 40), Parent = overlay }, close)
	arena = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(0.94, 0, 1, -100),
		BackgroundColor3 = Cc.panel, ClipsDescendants = true, Parent = overlay,
	}, { K.corner(18), new("UIStroke", { Color = Cc.hot, Thickness = 3 }), new("UIAspectRatioConstraint", { AspectRatio = 1.5, DominantAxis = Enum.DominantAxis.Height }) })
	return arena
end

local function sprite(text, size, parent)
	return new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1,
		Text = text, TextScaled = true, Font = K.BOLD, Parent = parent or arena,
	})
end

-- écran de départ
local function startScreen(title, desc, onGo)
	local f = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = arena }, { K.list(14), new("UIPadding", { PaddingTop = UDim.new(0.2, 0) }) })
	K.label(title, 40, { Parent = f })
	K.small(desc, 18, { TextColor3 = Cc.ink, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(0.8, 0, 0, 60), Parent = f })
	K.button("▶ JOUER", Cc.green, { Size = UDim2.fromOffset(200, 60), TextSize = 28, Parent = f }, function()
		f:Destroy()
		onGo()
	end)
end

local function finish(id, score)
	cleanup()
	local res = act("mgEnd", id, score)
	local f = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Cc.bg, BackgroundTransparency = 0.3, ZIndex = 10, Parent = arena }, { K.list(12), new("UIPadding", { PaddingTop = UDim.new(0.18, 0) }) })
	K.label("FIN DE PARTIE", 40, { Parent = f, ZIndex = 11 })
	if res then
		K.label("Score : " .. D.fmt(res.score) .. (res.isBest and "  🏆 NOUVEAU RECORD !" or ""), 24, { Parent = f, ZIndex = 11, TextColor3 = Cc.gold })
		K.label("+" .. D.fmt(res.cookies) .. " 🍪   +" .. res.gems .. " 💎", 26, { Parent = f, ZIndex = 11, TextColor3 = Cc.lime })
	else
		K.label("Partie trop courte, pas de récompense.", 20, { Parent = f, ZIndex = 11 })
	end
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), Parent = f, ZIndex = 11 }, { K.list(12, Enum.FillDirection.Horizontal) })
	K.button("🔁 Rejouer", Cc.hot, { Size = UDim2.fromOffset(170, 52), ZIndex = 11, Parent = row }, function() MG.open(id) end)
	K.button("Retour", Cc.violet, { Size = UDim2.fromOffset(150, 52), ZIndex = 11, Parent = row }, close)
end

local function onPress(fn)
	table.insert(inputConns, UserInputService.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
			or i.KeyCode == Enum.KeyCode.Space or i.KeyCode == Enum.KeyCode.ButtonA then
			fn(i)
		end
	end))
end

---------------------------------------------------------------------------- COOKIE NINJA
local function ninja()
	shell("🥷 COOKIE NINJA")
	startScreen("Cookie Ninja", "Glisse (ou tape) sur les cookies pour les trancher.\nÉvite les brocolis 🥦 ! 30 secondes.", function()
		if not act("mgStart", "ninja") then return close() end
		running = true
		local items, score, t, spawnAcc, dur = {}, 0, 0, 0, 30
		local down = false
		table.insert(inputConns, UserInputService.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then down = true end
		end))
		table.insert(inputConns, UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then down = false end
		end))
		local function slice(it)
			if it.dead then return end
			it.dead = true
			if it.bomb then
				score = math.max(0, score - 5)
				UI.floatText("-5 🥦", it.label.AbsolutePosition, Cc.red)
			else
				score += it.golden and 5 or 1
				UI.floatText(it.golden and "+5" or "+1", it.label.AbsolutePosition, Cc.gold)
			end
			TweenService:Create(it.label, TweenInfo.new(0.2), { TextTransparency = 1, Rotation = 90 }):Play()
			task.delay(0.2, function() it.label:Destroy() end)
		end
		conn = RunService.RenderStepped:Connect(function(dt)
			t += dt
			spawnAcc += dt
			local rate = 0.55 - math.min(0.3, t / 100)
			while spawnAcc > rate do
				spawnAcc -= rate
				local r = math.random()
				local bomb, golden = r < 0.15, r > 0.95
				local it = { x = math.random() * 0.8 + 0.1, y = 1.1, vx = (math.random() - 0.5) * 0.4, vy = -(1.2 + math.random() * 0.4), bomb = bomb, golden = golden }
				it.label = sprite(bomb and "🥦" or golden and "🌟" or "🍪", 70)
				it.label.Active = true
				local function hit() if down or UserInputService.TouchEnabled then slice(it) end end
				it.label.MouseEnter:Connect(hit)
				it.label.InputBegan:Connect(function(i)
					if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then slice(it) end
				end)
				table.insert(items, it)
			end
			for i = #items, 1, -1 do
				local it = items[i]
				it.vy += 1.3 * dt
				it.x += it.vx * dt
				it.y += it.vy * dt
				if not it.dead then
					it.label.Position = UDim2.fromScale(it.x, it.y)
					it.label.Rotation += dt * 180
				end
				if it.y > 1.2 and it.vy > 0 then
					if not it.dead then it.label:Destroy() end
					table.remove(items, i)
				end
			end
			hudLabel.Text = "Score : " .. score .. "   ⏱ " .. math.max(0, math.ceil(dur - t))
			if t >= dur then
				for _, it in items do if not it.dead then it.label:Destroy() end end
				finish("ninja", score)
			end
		end)
	end)
end

---------------------------------------------------------------------------- FLAPPY COOKIE
local function flappy()
	shell("🐤 FLAPPY COOKIE")
	startScreen("Flappy Cookie", "Tape / clique / Espace pour voler.\nPasse entre les bouteilles de lait !", function()
		if not act("mgStart", "flappy") then return close() end
		running = true
		local y, vy, score, t = 0.5, 0, 0, 0
		local pipes, pipeAcc = {}, 1.2
		local bird = sprite("🍪", 56)
		bird.Position = UDim2.fromScale(0.25, y)
		local over = false
		onPress(function()
			if not over then vy = -0.9 end
		end)
		conn = RunService.RenderStepped:Connect(function(dt)
			dt = math.min(dt, 1 / 30)
			t += dt
			vy += 2.6 * dt
			y += vy * dt
			bird.Position = UDim2.fromScale(0.25, y)
			bird.Rotation = math.clamp(vy * 60, -30, 70)
			pipeAcc += dt
			if pipeAcc > 1.6 then
				pipeAcc = 0
				local gap = math.random() * 0.45 + 0.28
				local p = { x = 1.1, gap = gap, passed = false }
				p.top = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0.08, 0, gap - 0.14, 0), BackgroundColor3 = Color3.fromHex("#e8f4ff"), Parent = arena }, { K.corner(6), K.stroke(Cc.cyan, 3) })
				p.bot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0.08, 0, 1 - gap - 0.14, 0), BackgroundColor3 = Color3.fromHex("#e8f4ff"), Parent = arena }, { K.corner(6), K.stroke(Cc.cyan, 3) })
				table.insert(pipes, p)
			end
			local speed = 0.32 + math.min(0.2, t / 200)
			local dead = y > 1.02 or y < -0.05
			for i = #pipes, 1, -1 do
				local p = pipes[i]
				p.x -= speed * dt
				p.top.Position = UDim2.fromScale(p.x, p.gap - 0.14)
				p.bot.Position = UDim2.fromScale(p.x, p.gap + 0.14)
				-- collision (arène au ratio 1.5 : 0.04 de largeur ≈ 0.06 de hauteur)
				if math.abs(p.x - 0.25) < 0.055 and math.abs(y - p.gap) > 0.14 - 0.035 then dead = true end
				if not p.passed and p.x < 0.25 then
					p.passed = true
					score += 1
				end
				if p.x < -0.1 then
					p.top:Destroy(); p.bot:Destroy()
					table.remove(pipes, i)
				end
			end
			hudLabel.Text = "Score : " .. score
			if dead and not over then
				over = true
				finish("flappy", score)
			end
		end)
	end)
end

---------------------------------------------------------------------------- CRUNCH RYTHME
local function rhythm()
	shell("🎵 CRUNCH RYTHME")
	local KEYS = { Enum.KeyCode.D, Enum.KeyCode.F, Enum.KeyCode.J, Enum.KeyCode.K }
	local COLS = { Cc.hot, Cc.cyan, Cc.lime, Cc.gold }
	startScreen("Crunch Rythme", "Touche les notes quand elles atteignent la ligne.\nClavier : D F J K — ou tape sur les colonnes. 35 secondes.", function()
		if not act("mgStart", "rhythm") then return close() end
		running = true
		local notes, score, combo, t, dur = {}, 0, 0, 0, 35
		local HIT_Y, SPEED = 0.85, 0.55
		local bpm = 128
		local beat = 60 / bpm
		local nextNote = 1
		for lane = 1, 4 do
			local col = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromScale((lane - 1) * 0.25, 0), Size = UDim2.fromScale(0.25, 1), BackgroundColor3 = COLS[lane], BackgroundTransparency = 0.88, Parent = arena })
			col.MouseButton1Down:Connect(function() MG._rhythmHit(lane) end)
			K.label(KEYS[lane].Name, 22, { Position = UDim2.fromScale(0, 0.92), Size = UDim2.fromScale(1, 0.08), Parent = col })
		end
		new("Frame", { Position = UDim2.fromScale(0, HIT_Y), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Cc.ink, Parent = arena })
		function MG._rhythmHit(lane)
			if not running then return end
			local best, bi
			for i, n in notes do
				if n.lane == lane and not n.done then
					local d = math.abs(n.y - HIT_Y)
					if d < 0.09 and (not best or d < best) then best, bi = d, i end
				end
			end
			if bi then
				local n = notes[bi]
				n.done = true
				local at = n.label.AbsolutePosition
				n.label:Destroy()
				combo += 1
				local pts = best < 0.035 and 10 or 5
				score += pts + math.min(combo, 20) // 5
				UI.floatText(best < 0.035 and "PARFAIT" or "BIEN", at, best < 0.035 and Cc.lime or Cc.cyan, 22)
			else
				combo = 0
			end
		end
		table.insert(inputConns, UserInputService.InputBegan:Connect(function(i)
			local lane = table.find(KEYS, i.KeyCode)
			if lane then MG._rhythmHit(lane) end
		end))
		conn = RunService.RenderStepped:Connect(function(dt)
			t += dt
			-- motif : une note par demi-temps, lanes pseudo-aléatoires, parfois des pauses
			while t + HIT_Y / SPEED >= nextNote * beat / 2 + 1 and nextNote * beat / 2 < dur - 2 do
				if math.random() < 0.72 then
					local lane = math.random(4)
					local n = { lane = lane, y = 0 }
					n.label = sprite("🍪", 54)
					n.label.Position = UDim2.fromScale((lane - 0.5) * 0.25, 0)
					n.born = t
					table.insert(notes, n)
				end
				nextNote += 1
			end
			for i = #notes, 1, -1 do
				local n = notes[i]
				n.y += SPEED * dt
				if not n.done then
					n.label.Position = UDim2.fromScale((n.lane - 0.5) * 0.25, n.y)
					if n.y > HIT_Y + 0.1 then
						n.done = true
						n.label:Destroy()
						combo = 0
					end
				end
				if n.done then table.remove(notes, i) end
			end
			hudLabel.Text = "Score : " .. score .. "   Combo : " .. combo .. "   ⏱ " .. math.max(0, math.ceil(dur - t))
			if t >= dur then
				for _, n in notes do if not n.done then n.label:Destroy() end end
				finish("rhythm", score)
			end
		end)
	end)
end

---------------------------------------------------------------------------- CASINO CRUMBLE
local function slots()
	shell("🎰 CASINO CRUMBLE")
	local f = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = arena }, { K.list(14), new("UIPadding", { PaddingTop = UDim.new(0.08, 0) }) })
	K.small("3 identiques = gros gain · 2 identiques = mise ×1,5 · 💎💎💎 et 7️⃣7️⃣7️⃣ donnent des gemmes !\nOn mise des cookies du jeu, jamais de vrais Robux.", 15, { TextColor3 = Cc.ink, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(0.9, 0, 0, 44), Parent = f })
	local reelRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.8, 0, 0.35, 0), Parent = f }, { K.list(12, Enum.FillDirection.Horizontal) })
	local reels = {}
	for i = 1, 3 do
		local box = new("Frame", { Size = UDim2.new(0.3, 0, 1, 0), BackgroundColor3 = Cc.bg, Parent = reelRow }, { K.corner(14), new("UIStroke", { Color = Cc.gold, Thickness = 4 }) })
		reels[i] = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "🍪", TextScaled = true, Font = K.BOLD, Parent = box })
	end
	local result = K.label("Choisis ta mise !", 24, { Parent = f })
	local btns = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), Parent = f }, { K.list(12, Enum.FillDirection.Horizontal) })
	local spinning = false
	local SYMS = { "🍪", "🍫", "🥛", "💎", "⭐", "7️⃣" }
	local plays = 0
	for i, m in { 1, 5, 25 } do
		K.button("MISE ×" .. m, i == 3 and Cc.hot or Cc.green, { Size = UDim2.fromOffset(150, 56), TextSize = 22, Parent = btns }, function()
			if spinning then return end
			spinning = true
			local res = act("spin", i)
			if not res or res.err then
				result.Text = res and res.err or "Impossible de jouer."
				spinning = false
				return
			end
			plays += 1
			-- animation des rouleaux
			for k = 1, 3 do
				task.spawn(function()
					for _ = 1, 8 + k * 5 do
						reels[k].Text = SYMS[math.random(#SYMS)]
						task.wait(0.05)
					end
					reels[k].Text = res.reels[k]
				end)
			end
			task.wait(0.05 * 23 + 0.1)
			if res.win > 0 then
				result.Text = "GAGNÉ +" .. D.fmt(res.win) .. " 🍪" .. (res.gems > 0 and ("  +" .. res.gems .. " 💎") or "")
				result.TextColor3 = Cc.lime
			else
				result.Text = "Perdu… mise : " .. D.fmt(res.bet) .. " 🍪"
				result.TextColor3 = Cc.red
			end
			spinning = false
		end)
	end
	hudLabel.Text = "La mise dépend de ta production actuelle"
end

---------------------------------------------------------------------------- API
function MG.open(id)
	cleanup()
	if id == "ninja" then ninja()
	elseif id == "flappy" then flappy()
	elseif id == "rhythm" then rhythm()
	elseif id == "slots" then slots() end
end

function MG.isOpen() return overlay ~= nil end

function MG.init(actFn, ui)
	act, UI = actFn, ui
end

return MG
