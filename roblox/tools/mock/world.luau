--!nocheck
-- Builds the place (DataModel from the Rojo bundle), the services, runs the real scripts, wires
-- remotes server <-> client in-process, and steps frames on a virtual clock.
local M = require("./mock")
local DATA, S, task, EnumG, getEvent = M.DATA, M.S, M.task, M.EnumG, M.getEvent
local v2, color = M.v2, M.color
local W = {}
W.M = M
local LATENCY = 0.03

local game, grec = M.newInstance("DataModel", "Game")
W.game = game
local services = {}
local function service(name)
	local s = services[name]
	if s then return s end
	s = M.newInstance(name, name)
	DATA[s].lockedParent = true
	DATA[s].parent = game
	table.insert(grec.children, s)
	services[name] = s
	return s
end
local CM = M.CLASS_METHODS
local function methods(class, t) CM[class] = CM[class] or {}; for k, f in t do CM[class][k] = f end end

---------------------------------------------------------------------------------- DataModel
methods("DataModel", {
	GetService = function(_, name)
		if not require("./out/api").services[name] then error("'" .. tostring(name) .. "' is not a valid Service name", 2) end
		return service(name)
	end,
	IsLoaded = function() return true end,
	BindToClose = function(_, fn) W.closeFns = W.closeFns or {}; table.insert(W.closeFns, fn) end,
})
methods("DataModel", { FindService = function(_, n) return services[n] end })
local workspace = service("Workspace")
local cam = M.newInstance("Camera", "Camera")
M.setParent(DATA[cam], workspace)
DATA[workspace].props.CurrentCamera = cam
DATA[cam].getters = { ViewportSize = function() return M.viewport end }

---------------------------------------------------------------------------------- Players
local Players = service("Players")
local player
methods("Players", {
	GetPlayers = function() return player and { player } or {} end,
	GetPlayerByUserId = function(_, id) return (player and DATA[player].props.UserId == id) and player or nil end,
	GetNameFromUserIdAsync = function(_, id) task.wait(0.05); return "Player" .. tostring(id) end,
})
DATA[Players].getters = { LocalPlayer = function() return M.curCtx() == "client" and player or nil end }

---------------------------------------------------------------------------------- RunService
local RunService = service("RunService")
local renderBinds = {}
methods("RunService", {
	IsStudio = function() return true end,
	IsClient = function() return M.curCtx() == "client" end,
	IsServer = function() return M.curCtx() == "server" end,
	IsRunning = function() return true end,
	BindToRenderStep = function(_, name, prio, fn) table.insert(renderBinds, { name = name, prio = prio, fn = fn }); table.sort(renderBinds, function(a, b) return a.prio < b.prio end) end,
	UnbindFromRenderStep = function(_, name) for i, b in renderBinds do if b.name == name then table.remove(renderBinds, i); break end end end,
})

---------------------------------------------------------------------------------- DataStore (in memory)
W.store = {}
local function mkStore(name, ordered)
	local data = W.store[name] or {}
	W.store[name] = data
	local st = {}
	st.GetAsync = function(_, k) task.wait(0.05); return data[k] end
	st.SetAsync = function(_, k, v) task.wait(0.02); data[k] = M.ser(v)[1] end
	st.UpdateAsync = function(_, k, fn) task.wait(0.02); local v = fn(data[k]); if v ~= nil then data[k] = M.ser(v)[1] end; return v end
	if ordered then
		st.GetSortedAsync = function(_, asc, n)
			task.wait(0.05)
			local rows = {}
			for k, v in data do table.insert(rows, { key = k, value = v }) end
			table.sort(rows, function(a, b) if asc then return a.value < b.value end return a.value > b.value end)
			while #rows > n do table.remove(rows) end
			return { GetCurrentPage = function() return rows end, IsFinished = true }
		end
	end
	return st
end
methods("DataStoreService", {
	GetDataStore = function(_, n) return mkStore(n, false) end,
	GetOrderedDataStore = function(_, n) return mkStore(n, true) end,
})

---------------------------------------------------------------------------------- Marketplace
methods("MarketplaceService", {
	PromptGamePassPurchase = function(_, p, id) W.prompts = (W.prompts or 0) + 1 end,
	PromptProductPurchase = function(_, p, id) W.prompts = (W.prompts or 0) + 1 end,
	UserOwnsGamePassAsync = function() task.wait(0.02); return false end,
})

---------------------------------------------------------------------------------- HttpService (JSON)
local function jenc(v)
	local t = type(v)
	if t == "nil" then return "null" elseif t == "boolean" then return tostring(v) elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "null" end
		return string.format("%.17g", v)
	elseif t == "string" then
		return '"' .. string.gsub(v, '[%c"\\]', function(c) return string.format("\\u%04x", string.byte(c)) end) .. '"'
	elseif t == "table" then
		local out = {}
		if #v > 0 or next(v) == nil then
			for _, x in v do table.insert(out, jenc(x)) end
			return "[" .. table.concat(out, ",") .. "]"
		end
		for k, x in v do table.insert(out, jenc(tostring(k)) .. ":" .. jenc(x)) end
		return "{" .. table.concat(out, ",") .. "}"
	end
	error("HttpService:JSONEncode: cannot encode " .. t, 3)
end
local function jdec(s)
	local i = 1
	local function ws() i = string.find(s, "[^%s]", i) or #s + 1 end
	local val
	local function str()
		local j = i + 1
		local out = {}
		while true do
			local c = string.sub(s, j, j)
			if c == "" then error("Can't parse JSON", 0) end
			if c == '"' then break end
			if c == "\\" then
				local e = string.sub(s, j + 1, j + 1)
				if e == "u" then table.insert(out, utf8.char(tonumber(string.sub(s, j + 2, j + 5), 16))); j += 6
				else table.insert(out, ({ n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" })[e] or e); j += 2 end
			else table.insert(out, c); j += 1 end
		end
		i = j + 1
		return table.concat(out)
	end
	val = function()
		ws()
		local c = string.sub(s, i, i)
		if c == "{" then
			i += 1; local o = {}; ws()
			if string.sub(s, i, i) == "}" then i += 1; return o end
			while true do ws(); local k = str(); ws(); i += 1; o[k] = val(); ws(); local d = string.sub(s, i, i); i += 1; if d == "}" then return o end end
		elseif c == "[" then
			i += 1; local o = {}; ws()
			if string.sub(s, i, i) == "]" then i += 1; return o end
			while true do table.insert(o, val()); ws(); local d = string.sub(s, i, i); i += 1; if d == "]" then return o end end
		elseif c == '"' then return str()
		elseif string.sub(s, i, i + 3) == "true" then i += 4; return true
		elseif string.sub(s, i, i + 4) == "false" then i += 5; return false
		elseif string.sub(s, i, i + 3) == "null" then i += 4; return nil end
		local n = string.match(s, "^-?[%d%.eE+-]+", i)
		if not n then error("Can't parse JSON", 0) end
		i += #n
		return tonumber(n)
	end
	return val()
end
methods("HttpService", {
	JSONEncode = function(_, v) return jenc(v) end,
	JSONDecode = function(_, s) return jdec(s) end,
	GenerateGUID = function() return "00000000-0000-0000-0000-000000000000" end,
})

---------------------------------------------------------------------------------- Tweens
local tweens = {}
local TWEENABLE = { number = true, boolean = true, UDim2 = true, UDim = true, Vector2 = true, Color3 = true, Rect = true, EnumItem = true, CFrame = true, Vector3 = true }
local function lerpV(a, b, t)
	local ty = M.typeof(a)
	if ty == "number" then return a + (b - a) * t end
	if ty == "UDim2" then return a:Lerp(b, t) end
	if ty == "Vector2" then return a:Lerp(b, t) end
	if ty == "Color3" then return a:Lerp(b, t) end
	if ty == "UDim" then return UDim.new(a.Scale + (b.Scale - a.Scale) * t, a.Offset + (b.Offset - a.Offset) * t) end
	return t >= 1 and b or a
end
local function ease(style, dir, t)
	local n = style and style.Name or "Quad"
	local function f(x)
		if n == "Linear" then return x elseif n == "Back" then local s = 1.70158; return x * x * ((s + 1) * x - s)
		elseif n == "Sine" then return 1 - math.cos(x * math.pi / 2) end
		return x * x
	end
	local d = dir and dir.Name or "Out"
	if d == "In" then return f(t) elseif d == "Out" then return 1 - f(1 - t) end
	return t < 0.5 and f(t * 2) / 2 or 1 - f((1 - t) * 2) / 2
end
methods("TweenService", {
	Create = function(_, inst, info, goals)
		if M.typeof(inst) ~= "Instance" then error("TweenService:Create: Instance expected", 2) end
		if M.typeof(info) ~= "TweenInfo" then error("TweenService:Create: TweenInfo expected", 2) end
		local rec = DATA[inst]
		for k, v in goals do
			local ok, cur = pcall(function() return inst[k] end)
			if not ok then error(string.format("TweenService:Create no property named '%s' for object '%s'", tostring(k), rec.props.Name), 2) end
			local ct, vt = M.typeof(cur), M.typeof(v)
			if not TWEENABLE[vt] or (cur ~= nil and ct ~= vt) then
				error(string.format("TweenService:Create property named '%s' cannot be tweened due to type mismatch (property is a '%s', but given type is '%s')", k, ct, vt), 2)
			end
		end
		local tw = { inst = inst, info = info, goals = goals, Completed = M.newSignal("Completed"), PlaybackState = EnumG.PlaybackState.Begin }
		M.TAG[tw] = "Instance"
		function tw.Play(self)
			if self.playing then return end
			for _, o in tweens do
				if o.inst == inst and o ~= self then for k in goals do if o.goals[k] ~= nil then o.goals[k] = nil end end end
			end
			self.start, self.t0 = {}, S.now + (info.DelayTime or 0)
			for k in goals do self.start[k] = inst[k] end
			self.playing = true
			table.insert(tweens, self)
		end
		function tw.Cancel(self) self.playing = false; local i = table.find(tweens, self); if i then table.remove(tweens, i) end end
		tw.Pause = tw.Cancel
		function tw.Destroy(self) self:Cancel() end
		return tw
	end,
})
local function stepTweens()
	for i = #tweens, 1, -1 do
		local tw = tweens[i]
		if S.now >= tw.t0 then
			local p = tw.info.Time > 0 and math.min(1, (S.now - tw.t0) / tw.info.Time) or 1
			local e = ease(tw.info.EasingStyle, tw.info.EasingDirection, p)
			for k, g in tw.goals do
				local ok, err = pcall(function() tw.inst[k] = lerpV(tw.start[k], g, p >= 1 and 1 or e) end)
				if not ok then M.finding("error", "tween write failed: " .. tostring(err)) end
			end
			if p >= 1 then
				table.remove(tweens, i)
				tw.playing = false
				tw.PlaybackState = EnumG.PlaybackState.Completed
				tw.Completed:Fire(EnumG.PlaybackState.Completed)
			end
		end
	end
end
methods("GuiObject", {
	TweenPosition = function(self, pos, dir, style, t)
		local tw = CM.TweenService.Create(nil, self, TweenInfo.new(t or 1, style, dir), { Position = pos })
		tw:Play()
		return true
	end,
})
TweenInfo = M.globals.TweenInfo
UDim = M.globals.UDim

---------------------------------------------------------------------------------- input services
local UIS = service("UserInputService")
DATA[UIS].props.TouchEnabled = false
DATA[UIS].props.KeyboardEnabled = true
DATA[UIS].props.MouseEnabled = true
W.mouse = v2(0, 0)
methods("UserInputService", {
	GetMouseLocation = function() return W.mouse end,
	GetFocusedTextBox = function() return nil end,
	IsKeyDown = function() return false end,
})
local GuiService = service("GuiService")
local function refreshInset()
	DATA[GuiService].props.TopbarInset = M.globals.Rect.new(v2(104, 0), v2(M.viewport.X - 60, M.INSET))
end
refreshInset()
DATA[GuiService].props.ReducedMotionEnabled = false
methods("GuiService", { GetGuiInset = function() return v2(0, M.INSET), v2(0, 0) end })
local CAS = service("ContextActionService")
local actions = {}
methods("ContextActionService", {
	BindActionAtPriority = function(_, name, fn, _touch, prio, ...)
		for i, a in actions do if a.name == name then table.remove(actions, i); break end end
		table.insert(actions, { name = name, fn = fn, prio = prio, keys = { ... } })
		table.sort(actions, function(a, b) return a.prio > b.prio end)
	end,
	BindAction = function(self, name, fn, touch, ...) CM.ContextActionService.BindActionAtPriority(self, name, fn, touch, 2000, ...) end,
	UnbindAction = function(_, name) for i, a in actions do if a.name == name then table.remove(actions, i); break end end end,
})
W.actions = actions
methods("StarterGui", { SetCoreGuiEnabled = function() end, SetCore = function() end, GetCoreGuiEnabled = function() return false end })
methods("TextService", {
	GetTextSize = function(_, text, size, font, frame)
		if type(text) ~= "string" or type(size) ~= "number" or M.typeof(font) ~= "EnumItem" or M.typeof(frame) ~= "Vector2" then
			error("TextService:GetTextSize: bad arguments", 2)
		end
		local n = utf8.len(text) or #text
		return v2(math.min(frame.X, n * size * 0.55), size)
	end,
})
local liveEditable = 0
methods("AssetService", {
	CreateEditableImage = function(_, opts)
		local sz = opts and opts.Size or v2(512, 512)
		if M.typeof(sz) ~= "Vector2" or sz.X < 1 or sz.Y < 1 or sz.X > 1024 or sz.Y > 1024 then error("CreateEditableImage: invalid Size", 2) end
		local ei = { Size = sz }
		M.TAG[ei] = "EditableImage"
		function ei.WritePixelsBuffer(self, pos, size, buf)
			if M.typeof(pos) ~= "Vector2" or M.typeof(size) ~= "Vector2" or type(buf) ~= "buffer" then error("WritePixelsBuffer: bad arguments", 2) end
			if buffer.len(buf) ~= size.X * size.Y * 4 then error(string.format("WritePixelsBuffer: buffer size %d does not match %dx%dx4", buffer.len(buf), size.X, size.Y), 2) end
			if pos.X + size.X > sz.X or pos.Y + size.Y > sz.Y then error("WritePixelsBuffer: region out of bounds", 2) end
		end
		function ei.Destroy(self) if not self.dead then self.dead = true; liveEditable -= 1 end end
		liveEditable += 1
		return ei
	end,
})

---------------------------------------------------------------------------------- remotes
local function deliver(fn)
	local co = M.newThread(fn, "net")
	S.threadCtx[co] = nil
	task.delay(LATENCY, function() fn() end)
end
M.onCreate.RemoteEvent = function(rec)
	rec.getters = rec.getters or {}
	local self = rec.self
	CM.RemoteEvent = CM.RemoteEvent or {
		FireServer = function(r, ...)
			if M.curCtx() ~= "client" then error("FireServer can only be called from the client", 2) end
			local a = M.ser(...)
			task.delay(LATENCY, function() M.getEvent(r, "OnServerEvent"):Fire(player, table.unpack(a, 1, a.n)) end)
		end,
		FireClient = function(r, p, ...)
			if M.curCtx() == "client" then error("FireClient can only be called from the server", 2) end
			if M.typeof(p) ~= "Instance" or DATA[p].class ~= "Player" then error("FireClient: player argument must be a Player object", 2) end
			local a = M.ser(...)
			task.delay(LATENCY, function() M.getEvent(r, "OnClientEvent"):Fire(table.unpack(a, 1, a.n)) end)
		end,
		FireAllClients = function(r, ...) if player then CM.RemoteEvent.FireClient(r, player, ...) end end,
	}
end
M.onCreate.RemoteFunction = function(rec)
	CM.RemoteFunction = CM.RemoteFunction or {
		InvokeServer = function(r, ...)
			if M.curCtx() ~= "client" then error("InvokeServer can only be called from the client", 2) end
			local a = M.ser(...)
			local co = coroutine.running()
			task.delay(LATENCY, function()
				local cb = DATA[r].props.OnServerInvoke
				if not cb then M.finding("error", "InvokeServer on " .. DATA[r].props.Name .. " without OnServerInvoke"); return end
				local srv = M.newThread(function()
					local res = table.pack(pcall(cb, player, table.unpack(a, 1, a.n)))
					if not res[1] then
						M.finding("error", "OnServerInvoke error: " .. tostring(res[2]))
						task.delay(LATENCY, function() M.resume(co, false, res[2]) end)
						return
					end
					local out = M.ser(table.unpack(res, 2, res.n))
					task.delay(LATENCY, function() M.resume(co, true, out) end)
				end, "server")
				M.resume(srv)
			end)
			local ok, out = coroutine.yield()
			if not ok then error(out, 2) end
			return table.unpack(out, 1, out.n)
		end,
	}
end

---------------------------------------------------------------------------------- scripts
local baseEnv = getfenv(0)
local realRequire = require
local caches = { server = {}, client = {} }
local startClock = os.time()
local function makeEnv(scriptInst, ctx)
	local env = {}
	for k, v in M.globals do env[k] = v end
	env.script = scriptInst
	env.game = game
	env.workspace = workspace
	env.Workspace = workspace
	env.print = function(...) table.insert(M.logs, table.concat(table.pack(...) and { ... } or {}, " ")) end
	env.warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
		M.finding("warn", "[" .. ctx .. "] " .. table.concat(parts, " "))
	end
	env.tick = function() return startClock + S.now end
	env.time = function() return S.now end
	env.elapsedTime = env.time
	env.os = setmetatable({ clock = function() return S.now end, time = function(t) if t then return os.time(t) end return startClock + math.floor(S.now) end }, { __index = os })
	env.wait = function(t) return task.wait(t) end
	env.spawn = function(f) task.defer(f) end
	env.delay = function(t, f) task.delay(t, f) end
	env.require = function(m) return W.require(m, ctx) end
	env.shared = {}
	return setmetatable(env, { __index = baseEnv })
end
function W.require(m, ctx)
	if M.typeof(m) ~= "Instance" then error("Attempted to call require with invalid argument(s).", 2) end
	local rec = DATA[m]
	if rec.class ~= "ModuleScript" then error("Attempted to call require with invalid argument(s).", 2) end
	local cache = caches[ctx]
	local e = cache[rec]
	if e then
		if e.loading then
			while e.loading do task.wait() end
		end
		if e.failed then error("Requested module experienced an error while loading", 2) end
		return e.value
	end
	e = { loading = true }
	cache[rec] = e
	local ok, res
	if rec.native then
		ok, res = pcall(realRequire, rec.native)
	else
		local fn, cerr = loadstring(rec.source, "=" .. M.fullName(m))
		if not fn then ok, res = false, cerr else
			setfenv(fn, makeEnv(m, ctx))
			local r = table.pack(pcall(fn))
			ok, res = r[1], r[2]
			if ok and r.n ~= 2 then ok, res = false, "Module code did not return exactly one value" end
		end
	end
	e.loading = false
	if not ok then
		e.failed = true
		M.finding("error", "module " .. M.fullName(m) .. " failed: " .. tostring(res))
		error("Requested module experienced an error while loading", 2)
	end
	e.value = res
	return res
end
local function runScript(inst, ctx)
	local rec = DATA[inst]
	local fn, err = loadstring(rec.source, "=" .. M.fullName(inst))
	if not fn then M.finding("error", err); return end
	setfenv(fn, makeEnv(inst, ctx))
	local co = M.newThread(fn, ctx)
	M.resume(co)
	M.drain()
end

---------------------------------------------------------------------------------- build place
local function build(node, parent)
	local inst
	if parent == nil then
		inst = game
	elseif services[node.name] or require("./out/api").services[node.class] and node.class == node.name then
		inst = service(node.name)
	else
		inst = M.newInstance(node.class, node.name)
		DATA[inst].source, DATA[inst].native = node.source, node.native
		M.setParent(DATA[inst], parent)
	end
	for _, c in node.children do build(c, inst) end
	return inst
end
build(M.BUNDLE, nil)
-- StarterPlayerScripts' default PlayerModule
local sps = DATA[service("StarterPlayer")].children
local spsFolder
for _, c in sps do if DATA[c].props.Name == "StarterPlayerScripts" then spsFolder = c end end
local pm = M.newInstance("ModuleScript", "PlayerModule")
DATA[pm].source = "local c = {Disable = function() end, Enable = function() end}\nreturn {GetControls = function() return c end}"
M.setParent(DATA[pm], spsFolder)

function W.bootServer()
	S.bootCtx = "server"
	for _, d in CM.DataModel.GetService(game, "ServerScriptService"):GetDescendants() do
		if DATA[d].class == "Script" then runScript(d, "server") end
	end
	S.bootCtx = nil
end
function W.addPlayer(userId)
	player = M.newInstance("Player", "TestPlayer")
	local pr = DATA[player].props
	pr.UserId = userId or 12345
	pr.DisplayName = "Testeur"
	local pg = M.newInstance("PlayerGui", "PlayerGui")
	M.setParent(DATA[pg], player)
	local ps = M.newInstance("PlayerScripts", "PlayerScripts")
	M.setParent(DATA[ps], player)
	M.setParent(DATA[player], Players)
	W.player, W.playerGui, W.playerScripts = player, pg, ps
	getEvent(DATA[Players], "PlayerAdded"):FireNow(player)
	return player
end
function W.bootClient()
	S.bootCtx = "client"
	for _, c in DATA[spsFolder].children do M.setParent(DATA[c:Clone()], W.playerScripts) end
	for _, d in W.playerScripts:GetDescendants() do
		if DATA[d].class == "LocalScript" then runScript(d, "client") end
	end
	S.bootCtx = nil
end
function W.clientRequire(path) -- e.g. {"CookieClient","UI"}
	local x = W.playerScripts
	for _, n in path do x = x:FindFirstChild(n) end
	S.bootCtx = "client"
	local v
	local co = M.newThread(function() v = W.require(x, "client") end, "client")
	M.resume(co)
	S.bootCtx = nil
	return v
end

---------------------------------------------------------------------------------- frame loop
W.fps = 60
function W.step(dt)
	dt = dt or 1 / W.fps
	S.now += dt
	S.frame += 1
	getEvent(DATA[RunService], "RenderStepped"):Fire(dt)
	for _, b in table.clone(renderBinds) do local co = M.newThread(b.fn, "client"); table.insert(S.deferred, { co, table.pack(dt) }) end
	M.drain()
	stepTweens()
	getEvent(DATA[RunService], "Stepped"):Fire(S.now, dt)
	M.drain()
	getEvent(DATA[RunService], "Heartbeat"):Fire(dt)
	M.drain()
	M.runTimers()
	M.drain()
end
function W.run(seconds)
	local n = math.floor(seconds * W.fps + 0.5)
	for _ = 1, n do W.step() end
end

---------------------------------------------------------------------------------- input
local function inputObj(ut, kc, pos)
	local io = { UserInputType = ut, KeyCode = kc or EnumG.KeyCode.Unknown, Position = M.globals.Vector3.new(pos and pos.X or 0, pos and pos.Y or 0, 0),
		Delta = M.globals.Vector3.new(0, 0, 0), UserInputState = EnumG.UserInputState.Begin }
	M.TAG[io] = "InputObject"
	return io
end
function W.key(kc)
	local io = inputObj(EnumG.UserInputType.Keyboard, kc)
	local processed = false
	for _, a in table.clone(actions) do
		if table.find(a.keys, kc) then
			processed = true
			local co = M.newThread(function() a.fn(a.name, EnumG.UserInputState.Begin, io) end, "client")
			M.resume(co)
			break
		end
	end
	getEvent(DATA[UIS], "InputBegan"):FireNow(io, processed)
	io.UserInputState = EnumG.UserInputState.End
	for _, a in table.clone(actions) do
		if table.find(a.keys, kc) then local co = M.newThread(function() a.fn(a.name, EnumG.UserInputState.End, io) end, "client"); M.resume(co); break end
	end
	getEvent(DATA[UIS], "InputEnded"):FireNow(io, processed)
end
-- click a GuiButton (or tap a GuiObject) at its centre; pos in inset space
function W.click(gui, down)
	local rec = DATA[gui]
	local x, y, w, h = M.guiRect(rec)
	local pos = v2(x + w / 2, y + h / 2)
	W.mouse = v2(pos.X, pos.Y + M.INSET)
	local io = inputObj(EnumG.UserInputType.MouseButton1, nil, pos)
	getEvent(rec, "InputBegan"):Fire(io)
	getEvent(DATA[UIS], "InputBegan"):Fire(io, M.isA(rec.class, "GuiButton"))
	if M.isA(rec.class, "GuiButton") then getEvent(rec, "MouseButton1Down"):Fire(pos.X, pos.Y) end
	M.drain()
	if down then return io end
	io.UserInputState = EnumG.UserInputState.End
	getEvent(rec, "InputEnded"):Fire(io)
	getEvent(DATA[UIS], "InputEnded"):Fire(io, M.isA(rec.class, "GuiButton"))
	if M.isA(rec.class, "GuiButton") then
		getEvent(rec, "MouseButton1Up"):Fire(pos.X, pos.Y)
		getEvent(rec, "MouseButton1Click"):Fire()
		getEvent(rec, "Activated"):Fire(io, 1)
	end
	M.drain()
end
function W.mouseMove(x, y) -- inset space
	W.mouse = v2(x, y + M.INSET)
	local io = inputObj(EnumG.UserInputType.MouseMovement, nil, v2(x, y))
	io.UserInputState = EnumG.UserInputState.Change
	getEvent(DATA[UIS], "InputChanged"):FireNow(io, false)
end
function W.mouseUp()
	local io = inputObj(EnumG.UserInputType.MouseButton1, nil, W.mouse - v2(0, M.INSET))
	io.UserInputState = EnumG.UserInputState.End
	getEvent(DATA[UIS], "InputEnded"):FireNow(io, false)
end

---------------------------------------------------------------------------------- queries
function W.findAll(root, pred)
	local out = {}
	for _, d in root:GetDescendants() do if pred(d, DATA[d]) then table.insert(out, d) end end
	return out
end
function W.find(root, pred) return W.findAll(root, pred)[1] end
function W.byName(root, name) return W.find(root, function(_, r) return r.props.Name == name end) end
-- the button whose (descendant) label shows `text`
function W.buttonWithText(root, text)
	for _, d in root:GetDescendants() do
		local r = DATA[d]
		if (r.class == "TextLabel" or r.class == "TextButton") and type(r.props.Text) == "string" and string.find(r.props.Text, text, 1, true) and not r.destroyed then
			local a = d
			while a and not M.isA(DATA[a].class, "GuiButton") do a = DATA[a].parent end
			if a then return a end
		end
	end
	return nil
end
W.DATA = DATA
return W
