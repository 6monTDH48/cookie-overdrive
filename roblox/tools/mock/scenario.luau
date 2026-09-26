--!nocheck
-- Scenario: server boot + join (seeded save), client boot, cookie clicks, every panel tab (+ a few
-- actions), then each minigame: open, start, play a few seconds, quit. Prints RESULT: PASS/FAIL.
local W = require("./world")
local M, DATA = W.M, W.DATA
local E = M.EnumG
local function step(msg) print("== " .. msg) end

-- rich save so every tab / minigame is unlocked (offline gains too: lastSave 1 h ago)
W.store["CookieOverdrive_v1"] = { u_12345 = {
	cookies = 1e15, totalBaked = 1e15, allTimeBaked = 1e15, clicks = 500, gems = 5000, lastSave = os.time() - 3600,
	buildings = { cursor = 30, granny = 12, farm = 5 },
} }

step("server boot"); W.bootServer(); W.run(1)
step("player join"); W.addPlayer(12345); W.run(0.5)
step("client boot"); W.bootClient(); W.run(4)
local pg = W.playerGui
local gui = pg:FindFirstChild("CookieOverdrive")
assert(gui, "main ScreenGui missing")

step("close modals (offline / welcome)")
for _ = 1, 3 do
	local m = W.byName(gui, "Modal")
	if m then W.key(E.KeyCode.Escape) end
	W.run(0.3)
end

step("cookie clicks")
local hit = W.byName(gui, "CookieHit")
for _ = 1, 40 do W.click(hit); W.run(0.05) end
W.key(E.KeyCode.Space)
W.run(2)

step("tabs")
for _, id in { "shop", "upgrades", "games", "pets", "style", "quests", "rebirth", "options" } do
	local b = W.byName(gui, "Tab_" .. id)
	assert(b, "tab button " .. id)
	W.click(b); W.run(0.6)
	local page = W.byName(gui, "Page_" .. id)
	if not page then M.finding("error", "tab " .. id .. " did not render its page") end
	if id == "shop" then
		local row = W.find(page, function(d, r) return r.class == "TextButton" end)
		if row then W.click(row); W.run(0.4) end
	elseif id == "upgrades" then
		local b2 = W.buttonWithText(page, "ACHETER"); if b2 then W.click(b2); W.run(0.4) end
	elseif id == "pets" then
		local egg = W.buttonWithText(page, " 30"); if egg then W.click(egg); W.run(2.5); W.key(E.KeyCode.Escape); W.run(0.5) end
	elseif id == "style" then
		local s = W.buttonWithText(W.byName(gui, "Page_style"), "Équiper") or W.buttonWithText(W.byName(gui, "Page_style"), "15")
		if s then W.click(s); W.run(0.5) end
	end
end
step("robux page")
local shop = W.buttonWithText(gui, "R$"); if shop then W.click(shop); W.run(0.5) end
local ret = W.buttonWithText(gui, "Retour"); if ret then W.click(ret); W.run(0.5) end
step("gift")
local gift = W.find(gui, function(d, r) return r.class == "TextButton" and d:FindFirstChild("Icon") and r.parent and DATA[r.parent].props.Name == "Frame" end)

step("minigames")
local tabGames = W.byName(gui, "Tab_games")
local ORDER = { "ninja", "flappy", "rhythm", "slots" }
for i, id in ORDER do
	W.click(tabGames); W.run(0.4)
	local page = W.byName(gui, "Page_games")
	local plays = W.findAll(page, function(d, r) return r.class == "TextButton" and r.props.Name == "Face" and W.buttonWithText(d, "JOUER") == d end)
	local b = plays[i]
	if not b then M.finding("error", "no JOUER button for " .. id); continue end
	W.click(b); W.run(1)
	local mg = pg:FindFirstChild("CookieMinigame")
	if not mg then M.finding("error", "minigame " .. id .. " did not open"); continue end
	step("  " .. id .. " start")
	if id == "slots" then
		for _ = 1, 3 do W.key(E.KeyCode.Space); W.run(3) end
		W.key(E.KeyCode.Two); W.key(E.KeyCode.Space); W.run(3)
	else
		W.key(E.KeyCode.Return); W.run(3)
		local hitF = W.byName(mg, "Hit")
		for k = 1, 60 do
			if id == "ninja" then
				local io = W.click(hitF, true)
				for j = 1, 6 do W.mouseMove(200 + j * 60, 300 + (k % 5) * 30); W.step() end
				W.mouseUp()
			elseif id == "flappy" then
				W.key(E.KeyCode.Space); W.run(0.25)
			else
				W.key(({ E.KeyCode.D, E.KeyCode.F, E.KeyCode.J, E.KeyCode.K })[k % 4 + 1]); W.run(0.2)
				if hitF then W.click(hitF) end
			end
		end
		W.run(id == "flappy" and 8 or 40) -- let the round end / results screen
	end
	step("  " .. id .. " quit")
	local q = W.buttonWithText(mg, "Quitter")
	if q then W.click(q) else M.finding("error", "no Quitter button in " .. id) end
	W.run(1)
	if pg:FindFirstChild("CookieMinigame") then M.finding("error", "minigame " .. id .. " still open after Quitter") end
end
step("idle 10 s"); W.run(10)

print(string.format("\n%d errors, %d distinct warnings, %d instances created, virtual time %.1f s", #M.errors, #M.warns, M.instCount, M.S.now))
for _, w in M.warns do print(string.format("WARN x%d: %s", w.n, string.sub(w.msg, 1, 400))) end
for _, e in M.errors do print(string.format("ERROR x%d: %s", e.n, e.msg)) end
print(#M.errors == 0 and "RESULT: PASS" or "RESULT: FAIL")
