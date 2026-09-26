--!strict
--[[
	Img — shows the site's art (exported PNGs) on ImageLabels / ImageButtons.   (CONTRACT.md §3)

	Two sources per asset key (e.g. "ui:gem", "cookie:classic", "bg:synthwave"):
	  1. ReplicatedStorage.Shared.AssetIds[key] ~= 0  → uploaded Roblox image: .Image = "rbxassetid://id"
	  2. otherwise ReplicatedStorage.Shared.ImageData  → the PNG embedded as base64(zlib(RGBA8)),
	     decoded here (Shared.Inflate) into an EditableImage, shown with
	     .ImageContent = Content.fromObject(editableImage). One EditableImage per key, shared by
	     every object showing it.

	API
	  Img.has(key) -> boolean                 key known (embedded or uploaded)
	  Img.size(key) -> Vector2                pixel size (Vector2.zero if unknown / upload-only)
	  Img.set(obj, key) -> boolean            obj: ImageLabel | ImageButton. false = unknown key or
	                                          image creation failed; obj is then left unchanged
	                                          (show an emoji instead). Small images (<= 256 px) are
	                                          decoded immediately while this frame's budget allows;
	                                          big ones (cookie 640, backgrounds) are decoded in the
	                                          background and appear a few frames later (true is
	                                          returned right away). If set() is called again on
	                                          the same object before that, the latest key wins.
	  Img.preload(prefixes: {string}? | string?)  queue decoding in the background, e.g.
	                                          Img.preload({ "cookie:classic", "bg:synthwave" }).
	                                          nil = everything, but mind the memory: every decoded
	                                          image is an EditableImage of w*h*4 bytes (all ~210
	                                          images = ~110 MB; a 640x640 cookie/accessory = 1.6 MB).
	                                          Preload what is on screen soon; release() the rest.
	  Img.ready(key) -> boolean               pixels available now (uploaded or decoded)
	  Img.onReady(key, fn: (ok: boolean) -> ()) call fn once the key is decoded (or failed);
	                                          starts decoding if needed. Called in a new thread.
	  Img.content(key) -> Content?            the Content to use elsewhere (ImageContent of other
	                                          classes, MeshPart.TextureContent...), nil if not ready
	  Img.release(key)                        destroy a decoded EditableImage to free memory (only
	                                          when nothing shows it anymore)
	  Img.stats() -> { decoded, pending, failed, bytes }   bytes = EditableImage memory in use

	Tunable: Img.frameBudget = seconds of decoding allowed per frame, immediate (inside set())
	and background together (default 0.005). A frame never spends much more than that decoding.
	If the budget is used up, set() queues even small images; they appear on the next frames.
	Img.preloadLimit = bytes of EditableImages above which preload() stops decoding (default
	48 MB; set() is never limited). Protects the device's EditableImage memory budget.
	Decoding speed (Luau interpreter): ~50-60 MB/s of RGBA, i.e. ~1 ms for a 128x128 icon and
	~30 ms for a 640x640 cookie, spread over several frames.
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Inflate = require(Shared:WaitForChild("Inflate"))

type ImageModule = { key: string, w: number, h: number, z: string }
type Entry = {
	state: string, -- "queued" | "decoding" | "ready" | "failed"
	editable: EditableImage?,
	content: Content?,
	w: number,
	h: number,
}

local Img = {}
Img.frameBudget = 0.005
Img.preloadLimit = 48 * 1024 * 1024
local SMALL = 256 -- max side decoded synchronously inside set()

--------------------------------------------------------------------------------------------
-- index / ids / modules (loaded lazily on first use)
--------------------------------------------------------------------------------------------
local index: { [string]: string } = {}
local ids: { [string]: number } = {}
local imageFolder: Instance? = nil
local loaded = false

local function ensureLoaded()
	if loaded then
		return
	end
	loaded = true
	local folder = Shared:FindFirstChild("ImageData")
	if not folder and not game:IsLoaded() then
		game.Loaded:Wait()
		folder = Shared:FindFirstChild("ImageData")
	end
	if folder then
		imageFolder = folder
		local idx = folder:FindFirstChild("_index") or folder:WaitForChild("_index", 5)
		if idx and idx:IsA("ModuleScript") then
			local ok, res = pcall(require, idx)
			if ok and type(res) == "table" then
				index = res :: any
			else
				warn("[Img] ImageData._index failed to load: " .. tostring(res))
			end
		end
	else
		warn("[Img] ReplicatedStorage.Shared.ImageData not found (run roblox/tools/pack_assets.py)")
	end
	local idsModule = Shared:FindFirstChild("AssetIds")
	if idsModule and idsModule:IsA("ModuleScript") then
		local ok, res = pcall(require, idsModule)
		if ok and type(res) == "table" then
			ids = res :: any
		end
	end
end

local function uploadedId(key: string): number
	local id = ids[key]
	if type(id) == "number" and id > 0 then
		return id
	end
	return 0
end

local modules: { [string]: ImageModule } = {}

local function getModule(key: string, wait: boolean): ImageModule?
	local m = modules[key]
	if m then
		return m
	end
	local name = index[key]
	local folder = imageFolder
	if not name or not folder then
		return nil
	end
	local ms = folder:FindFirstChild(name)
	if not ms and wait then
		ms = folder:WaitForChild(name, 10)
	end
	if not ms or not ms:IsA("ModuleScript") then
		return nil
	end
	local ok, res = pcall(require, ms)
	if not ok or type(res) ~= "table" or type(res.z) ~= "string" or type(res.w) ~= "number" or type(res.h) ~= "number" then
		warn("[Img] bad ImageData module " .. name .. ": " .. tostring(res))
		return nil
	end
	modules[key] = res :: any
	return res :: any
end

--------------------------------------------------------------------------------------------
-- decoding
--------------------------------------------------------------------------------------------
local entries: { [string]: Entry } = {}
local waiting: { [string]: { GuiObject } } = {} -- objects to update when a key becomes ready
local latest: { [GuiObject]: string } = {} -- object -> key it is waiting for (latest set() wins)
local callbacks: { [string]: { (boolean) -> () } } = {}
local hi: { string } = {} -- decode queue: keys requested by set()/onReady()
local lo: { string } = {} -- decode queue: preload()
local workerRunning = false
local spent = 0 -- decoding seconds used during the current frame (set() + worker)
local liveBytes = 0 -- memory of the EditableImages currently alive
local warned: { [string]: boolean } = {}

RunService.Heartbeat:Connect(function()
	spent = 0
end)

local function fail(key: string, why: string)
	if not warned[key] then
		warned[key] = true
		warn(string.format("[Img] %s: %s", key, why))
	end
end

-- Creates the (empty) EditableImage for a key. Cheap; done before decoding so a creation
-- failure (EditableImage not allowed, memory budget) costs no decoding time.
local function createEntry(key: string, wait: boolean): Entry?
	local m = getModule(key, wait)
	if not m then
		return nil
	end
	local w, h = m.w, m.h
	local ok, editable = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
	end)
	local e: Entry
	if ok and editable then
		e = { state = "queued", editable = editable, w = w, h = h }
		liveBytes += w * h * 4
	else
		fail(key, "CreateEditableImage failed: " .. tostring(editable))
		e = { state = "failed", w = w, h = h }
	end
	entries[key] = e
	return e
end

local function missingEntry(key: string): Entry
	fail(key, "ImageData module missing")
	local e: Entry = { state = "failed", w = 0, h = 0 }
	entries[key] = e
	return e
end

local function finish(key: string, e: Entry)
	local ok = e.state == "ready"
	local list = waiting[key]
	waiting[key] = nil
	if list then
		for _, obj in list do
			if latest[obj] == key then
				latest[obj] = nil
				if ok then
					pcall(function()
						(obj :: any).ImageContent = e.content
					end)
				end
			end
		end
	end
	local cbs = callbacks[key]
	callbacks[key] = nil
	if cbs then
		for _, fn in cbs do
			task.spawn(fn, ok)
		end
	end
end

-- Decodes the pixels of a queued entry and writes them into its EditableImage.
-- yieldFn ~= nil: may yield (background worker); nil: synchronous.
local function fill(key: string, e: Entry, yieldFn: (() -> ())?, budget: number?)
	e.state = "decoding"
	local ok, err = pcall(function()
		local m = getModule(key, yieldFn ~= nil)
		if not m then
			error("ImageData module missing", 0)
		end
		local w, h = m.w, m.h
		local rgba = Inflate.base64Zlib(m.z, { size = w * h * 4, yield = yieldFn, budget = budget })
		local editable = e.editable :: EditableImage
		editable:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), rgba)
		e.content = Content.fromObject(editable)
	end)
	if ok then
		e.state = "ready"
	else
		e.state = "failed"
		if e.editable then
			pcall(function()
				(e.editable :: EditableImage):Destroy()
			end)
			e.editable = nil
			liveBytes -= e.w * e.h * 4
		end
		fail(key, tostring(err))
	end
	finish(key, e)
end

local function worker()
	local t0 = os.clock()
	local function account()
		local now = os.clock()
		spent += now - t0
		t0 = now
	end
	local function yieldFn() -- next frame (Inflate calls it when its slice budget is used)
		account()
		task.wait()
		t0 = os.clock()
	end
	while true do
		account()
		if spent >= Img.frameBudget then
			yieldFn()
		end
		local key = table.remove(hi, 1)
		local preloading = false
		if not key then
			key = table.remove(lo, 1)
			preloading = true
		end
		if not key then
			break
		end
		if preloading and not entries[key] then
			local m = getModule(key, true)
			if m and liveBytes + m.w * m.h * 4 > Img.preloadLimit then
				continue -- preload only while there is memory to spare
			end
		end
		local e = entries[key] or createEntry(key, true) or missingEntry(key)
		if e.state == "queued" then
			fill(key, e, yieldFn, math.max(0.001, Img.frameBudget - spent))
		elseif e.state == "failed" then
			finish(key, e)
		end
	end
	workerRunning = false
end

local function enqueue(key: string, high: boolean)
	local e = entries[key]
	if e and e.state ~= "queued" then
		return -- decoding, ready or failed
	end
	if high then
		local i = table.find(lo, key)
		if i then
			table.remove(lo, i)
		end
		if not table.find(hi, key) then
			table.insert(hi, key)
		end
	elseif not table.find(hi, key) and not table.find(lo, key) then
		table.insert(lo, key)
	end
	if not workerRunning then
		workerRunning = true
		task.spawn(worker)
	end
end

--------------------------------------------------------------------------------------------
-- public API
--------------------------------------------------------------------------------------------
function Img.has(key: string): boolean
	ensureLoaded()
	return type(key) == "string" and (index[key] ~= nil or uploadedId(key) ~= 0)
end

function Img.size(key: string): Vector2
	ensureLoaded()
	local e = entries[key]
	if e and e.w > 0 then
		return Vector2.new(e.w, e.h)
	end
	if type(key) ~= "string" or not index[key] then
		return Vector2.zero
	end
	-- before the game has finished loading, the module may not be replicated yet: wait for it
	local m = getModule(key, not game:IsLoaded())
	if m then
		return Vector2.new(m.w, m.h)
	end
	return Vector2.zero
end

function Img.set(obj: GuiObject, key: string): boolean
	ensureLoaded()
	if type(key) ~= "string" or typeof(obj) ~= "Instance" or not (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) then
		return false
	end
	local id = uploadedId(key)
	if id ~= 0 then
		local ok = pcall(function()
			(obj :: any).Image = "rbxassetid://" .. id
		end)
		if ok then
			latest[obj] = nil
		end
		return ok
	end
	if not index[key] then
		return false
	end
	local e = entries[key] or createEntry(key, false)
	if not e then
		-- module not replicated yet: let the worker wait for it
		latest[obj] = key
		local list = waiting[key] or {}
		waiting[key] = list
		table.insert(list, obj)
		enqueue(key, true)
		return true
	end
	if e.state == "queued" and e.w <= SMALL and e.h <= SMALL and spent < Img.frameBudget then
		local t0 = os.clock()
		fill(key, e, nil)
		spent += os.clock() - t0
	end
	if e.state == "ready" then
		local ok = pcall(function()
			(obj :: any).ImageContent = e.content
		end)
		if ok then
			latest[obj] = nil
		end
		return ok
	elseif e.state == "failed" then
		return false
	end
	latest[obj] = key
	local list = waiting[key] or {}
	waiting[key] = list
	table.insert(list, obj)
	enqueue(key, true)
	return true
end

function Img.preload(prefixes: ({ string } | string)?)
	ensureLoaded()
	local list: { string }? = if type(prefixes) == "string" then { prefixes } else prefixes :: { string }?
	local keys = {}
	for key in index do
		if uploadedId(key) == 0 and not entries[key] then
			local match = list == nil
			if list then
				for _, p in list do
					if string.sub(key, 1, #p) == p then
						match = true
						break
					end
				end
			end
			if match then
				table.insert(keys, key)
			end
		end
	end
	table.sort(keys)
	for _, key in keys do
		enqueue(key, false)
	end
end

function Img.ready(key: string): boolean
	ensureLoaded()
	if uploadedId(key) ~= 0 then
		return true
	end
	local e = entries[key]
	return e ~= nil and e.state == "ready"
end

function Img.onReady(key: string, fn: (ok: boolean) -> ())
	ensureLoaded()
	local e = entries[key]
	if uploadedId(key) ~= 0 or (e and e.state == "ready") then
		task.spawn(fn, true)
		return
	end
	if not index[key] or (e and e.state == "failed") then
		task.spawn(fn, false)
		return
	end
	local cbs = callbacks[key] or {}
	callbacks[key] = cbs
	table.insert(cbs, fn)
	enqueue(key, true)
end

function Img.content(key: string): Content?
	ensureLoaded()
	local id = uploadedId(key)
	if id ~= 0 then
		return Content.fromUri("rbxassetid://" .. id)
	end
	local e = entries[key]
	if e and e.state == "ready" then
		return e.content
	end
	return nil
end

function Img.release(key: string)
	local e = entries[key]
	if e and (e.state == "ready" or e.state == "failed") then
		entries[key] = nil
		warned[key] = nil
		if e.editable then
			liveBytes -= e.w * e.h * 4
			pcall(function()
				(e.editable :: EditableImage):Destroy()
			end)
		end
	end
end

function Img.stats(): { decoded: number, pending: number, failed: number, bytes: number }
	local s = { decoded = 0, pending = 0, failed = 0, bytes = 0 }
	s.bytes = liveBytes
	for _, e in entries do
		if e.state == "ready" then
			s.decoded += 1
		elseif e.state == "failed" then
			s.failed += 1
		else
			s.pending += 1
		end
	end
	s.pending += #hi + #lo
	return s
end

return Img
