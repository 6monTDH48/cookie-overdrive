#!/usr/bin/env python3
"""Runs src/client/Img.lua in the Luau CLI against a mocked Roblox API (AssetService,
EditableImage, Content, task scheduler, instances) to test its logic:
sync/async decoding, decode-once, latest-set-wins, uploaded ids, failures, preload, onReady,
release, per-frame budgets.   python3 roblox/tools/tests/test_img.py

Only the logic is tested here; the real Roblox calls are listed in Img.lua and were checked
against the Roblox API type definitions (luau-lsp analyze).
"""
import base64
import os
import shutil
import subprocess
import sys
import tempfile
import zlib

sys.dont_write_bytecode = True  # no __pycache__ next to the tools
HERE = os.path.dirname(os.path.abspath(__file__))
ROBLOX = os.path.dirname(os.path.dirname(HERE))
LUAU = os.environ.get("LUAU", "/home/user/tools/luau")
sys.path.insert(0, HERE)
import make_fixtures  # noqa: E402


def lua_module(key, w, h, rgba):
    z = base64.b64encode(zlib.compress(rgba, 9)).decode()
    return f'{{ key = "{key}", w = {w}, h = {h}, z = "{z}" }}', zlib.crc32(rgba)


PRELUDE = r'''
local InflateReal = require("./Inflate")
local Log = { warns = {}, created = 0, written = 0, destroyed = 0, failCreate = false }

local function typeof(v) if type(v) == "table" and rawget(v, "__inst") then return "Instance" end return type(v) end
local function warn(...) table.insert(Log.warns, table.concat({ ... }, " ")) end

-- Vector2 / Content
local Vector2 = { zero = { X = 0, Y = 0 } }
function Vector2.new(x, y) return { X = x, Y = y } end
local Content = {}
function Content.fromObject(o) return { kind = "object", obj = o } end
function Content.fromUri(u) return { kind = "uri", uri = u } end

-- scheduler: task.spawn resumes immediately, task.wait parks the thread until the next frame
local sleepers, heartbeat = {}, {}
local frame = 0
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then error("thread error: " .. tostring(err)) end
end
local task = {}
function task.spawn(fn, ...) local co = coroutine.create(fn); resume(co, ...); return co end
function task.wait() table.insert(sleepers, coroutine.running()); coroutine.yield(); return 0.016 end
local function stepFrame()
	frame += 1
	for _, f in heartbeat do f() end
	local list = sleepers
	sleepers = {}
	for _, co in list do resume(co) end
end

-- instances
local function inst(className, name, props)
	local o = { __inst = true, ClassName = className, Name = name, children = {} }
	for k, v in props or {} do o[k] = v end
	function o:IsA(c) return c == self.ClassName or (c == "GuiObject" and (self.ClassName == "ImageLabel" or self.ClassName == "ImageButton" or self.ClassName == "Frame")) end
	function o:FindFirstChild(n) return self.children[n] end
	function o:WaitForChild(n) return self.children[n] end
	return o
end
local function add(parent, child) parent.children[child.Name] = child; return child end

local ReplicatedStorage = inst("ReplicatedStorage", "ReplicatedStorage")
local Shared = add(ReplicatedStorage, inst("Folder", "Shared"))
add(Shared, inst("ModuleScript", "Inflate", { __value = InflateReal }))
local ImageData = add(Shared, inst("Folder", "ImageData"))
local AssetIdsModule = add(Shared, inst("ModuleScript", "AssetIds", { __value = {} }))

local AssetService = {}
function AssetService:CreateEditableImage(opts)
	if Log.failCreate then error("EditableImage memory budget exceeded (mock)") end
	Log.created += 1
	local e = { Size = opts.Size, pixels = nil, destroyed = false }
	function e:WritePixelsBuffer(pos, size, buf)
		assert(pos.X == 0 and pos.Y == 0, "position")
		assert(size.X == self.Size.X and size.Y == self.Size.Y, "size")
		assert(buffer.len(buf) == size.X * size.Y * 4, "buffer length")
		Log.written += 1
		self.pixels = buf
	end
	function e:Destroy() self.destroyed = true; Log.destroyed += 1 end
	return e
end
local RunService = { Heartbeat = { Connect = function(_, f) table.insert(heartbeat, f) end } }
local game = { Loaded = { Wait = function() end } }
function game:GetService(n)
	if n == "AssetService" then return AssetService elseif n == "ReplicatedStorage" then return ReplicatedStorage
	elseif n == "RunService" then return RunService end
	error("service " .. n)
end
function game:IsLoaded() return true end
local require = function(ms) assert(ms.__value ~= nil, "mock require of " .. tostring(ms.Name)); return ms.__value end
'''

TESTS = r'''
local fails = 0
local function check(c, msg) if not c then fails += 1; print("FAIL: " .. msg) end end
local CRC = table.create(256, 0)
for n = 0, 255 do local c = n for _ = 1, 8 do if bit32.band(c, 1) ~= 0 then c = bit32.bxor(0xEDB88320, bit32.rshift(c, 1)) else c = bit32.rshift(c, 1) end end CRC[n + 1] = c end
local function crc32(b) local c = 0xFFFFFFFF for i = 0, buffer.len(b) - 1 do c = bit32.bxor(CRC[bit32.band(bit32.bxor(c, buffer.readu8(b, i)), 255) + 1], bit32.rshift(c, 8)) end return bit32.bxor(c, 0xFFFFFFFF) end
local function label(cls) return inst(cls or "ImageLabel", "L", { Image = "", ImageContent = nil }) end
local function pixelsOf(obj) return obj.ImageContent and obj.ImageContent.obj and obj.ImageContent.obj.pixels end

-- basic queries
check(Img.has("ui:gem") and Img.has("cookie:classic") and not Img.has("nope"), "has")
check(Img.has("ui:uploaded"), "has() true for an upload-only key")
local s = Img.size("cookie:classic")
check(s.X == 640 and s.Y == 640, "size cookie")
check(Img.size("nope").X == 0, "size unknown = zero")

-- unknown key / non-image object
local l0 = label()
check(Img.set(l0, "nope") == false and l0.ImageContent == nil and l0.Image == "", "unknown key -> false, unchanged")
check(Img.set(label("Frame"), "ui:gem") == false, "Frame -> false")

-- small image: synchronous
local l1 = label()
check(Img.set(l1, "ui:gem") == true, "set small returns true")
check(pixelsOf(l1) ~= nil and crc32(pixelsOf(l1)) == EXPECT["ui:gem"], "small image applied synchronously with right pixels")
check(Img.ready("ui:gem"), "ready small")
-- same key again: cached, no new EditableImage
local created = Log.created
local l1b = label()
Img.set(l1b, "ui:gem")
check(Log.created == created and l1b.ImageContent == l1.ImageContent, "cached per key")

-- uploaded id wins
local lu = label()
check(Img.set(lu, "ui:uploaded") == true and lu.Image == "rbxassetid://987654", "uploaded id -> rbxassetid")
check(Img.set(label(), "b:up_and_embedded") and Log.created == created, "uploaded id preferred over ImageData")
check(Img.ready("ui:uploaded") and Img.content("ui:uploaded").uri == "rbxassetid://987654", "content() for uploaded")

-- large image: asynchronous, decoded once for several objects
local a, b = label(), label()
local cbOk = nil
Img.onReady("cookie:classic", function(ok) cbOk = ok end)
check(Img.set(a, "cookie:classic") == true, "set big returns true")
check(Img.set(b, "cookie:classic") == true, "set big (2nd object) returns true")
check(a.ImageContent == nil, "big not applied synchronously")
local writesBefore = Log.written
local frames = 0
while not Img.ready("cookie:classic") and frames < 1000 do stepFrame(); frames += 1 end
check(Img.ready("cookie:classic"), "big decoded eventually")
check(frames >= 2, "big decode spread over several frames (" .. frames .. ")")
check(Log.written == writesBefore + 1, "decoded once for two objects")
check(pixelsOf(a) ~= nil and a.ImageContent == b.ImageContent and crc32(pixelsOf(a)) == EXPECT["cookie:classic"], "big applied to both objects")
stepFrame()
check(cbOk == true, "onReady called with true")

-- latest set() wins while pending
local c = label()
Img.set(c, "cookie:chocolate")   -- big, pending
Img.set(c, "ui:gem")             -- small, immediate
for _ = 1, 400 do stepFrame() end
check(Img.ready("cookie:chocolate"), "second big decoded")
check(c.ImageContent == l1.ImageContent, "latest set() wins over an older pending key")

-- corrupted module: false, unchanged
local lb = label()
check(Img.set(lb, "ui:broken") == false and lb.ImageContent == nil, "corrupt data -> false, unchanged")
check(#Log.warns >= 1, "warning logged")

-- EditableImage creation failure: false, unchanged
Log.failCreate = true
local lf = label()
check(Img.set(lf, "ui:star") == false and lf.ImageContent == nil, "creation failure -> false, unchanged")
local failCb = nil
Img.onReady("ui:star", function(ok) failCb = ok end)
stepFrame()
check(failCb == false, "onReady(false) for failed key")
Log.failCreate = false
Img.release("ui:star")   -- failed entries can be released to retry
check(Img.set(lf, "ui:star") == true and lf.ImageContent ~= nil, "retry after release")

-- preload: background, only matching prefixes
Img.preload({ "bg:" })
check(not Img.ready("bg:synthwave"), "preload does not block")
for _ = 1, 400 do stepFrame() end
check(Img.ready("bg:synthwave") and Img.ready("bg:galaxy"), "preload decoded bg:*")
check(not Img.ready("acc:crown"), "preload skipped other prefixes")

-- sync budget: with a tiny budget, extra small images go async
Img.frameBudget = 0
local many = {}
for i = 1, 3 do many[i] = label(); check(Img.set(many[i], "icon:" .. i), "set icon " .. i) end
check(many[1].ImageContent == nil, "zero budget -> async")
for _ = 1, 50 do stepFrame() end
check(many[1].ImageContent ~= nil and many[3].ImageContent ~= nil, "async small applied later")
Img.frameBudget = 0.005

-- preloadLimit: preload stops when EditableImage memory would exceed it; set() is not limited
Img.release("cookie:chocolate")
local before = Img.stats().bytes
Img.preloadLimit = before + 64 * 64 * 4 + 1 -- room for acc:crown (64x64) but not a 640x640 cookie
Img.preload({ "cookie:" , "acc:" })
for _ = 1, 400 do stepFrame() end
check(Img.stats().bytes <= Img.preloadLimit, "preload respects preloadLimit")
check(Img.ready("acc:crown"), "small preload fits (acc:crown)")
check(not Img.ready("cookie:chocolate"), "big preload skipped over the limit")
local ld = label()
check(Img.set(ld, "cookie:classic") == true, "set() not limited by preloadLimit")
Img.preloadLimit = 48 * 1024 * 1024

-- a big image never blocks the calling frame for long
stepFrame()
local lh = label()
local t0 = os.clock()
check(Img.set(lh, "fx:huge") == true, "set huge")
local dt = os.clock() - t0
check(dt < 0.008, string.format("set() of a 1024x576 image blocked %.1f ms (< 8 expected)", dt * 1000))
local worst, n = 0, 0
while not Img.ready("fx:huge") and n < 1000 do
	local f0 = os.clock()
	stepFrame()
	worst = math.max(worst, os.clock() - f0)
	n += 1
end
check(lh.ImageContent ~= nil and crc32(pixelsOf(lh)) == EXPECT["fx:huge"], "huge applied")
check(worst < 0.008, string.format("worst frame %.1f ms while decoding (< 8 expected)", worst * 1000))
print(string.format("fx:huge 1024x576: set() %.1f ms, then %d frames, worst frame %.1f ms", dt * 1000, n, worst * 1000))

-- release
local d0 = Log.destroyed
Img.release("ui:gem")
check(Log.destroyed == d0 + 1 and not Img.ready("ui:gem"), "release destroys the EditableImage")
local st = Img.stats()
check(st.decoded >= 5 and st.pending == 0, "stats " .. st.decoded .. "/" .. st.pending)

print(string.format("Img mock test: %d failure(s), %d EditableImages created, %d written", fails, Log.created, Log.written))
if fails > 0 then error(fails .. " failure(s)", 0) end
'''


def main():
    images = {
        "ui:gem": (128, 128, make_fixtures.cookie_rgba(128, 128, 40, 11)),
        "ui:star": (64, 64, make_fixtures.cookie_rgba(64, 64, 20, 12)),
        "b:up_and_embedded": (32, 32, bytes(32 * 32 * 4)),
        "cookie:classic": (640, 640, make_fixtures.cookie_rgba(640, 640, 200, 13)),
        "cookie:chocolate": (640, 640, make_fixtures.cookie_rgba(640, 640, 200, 14)),
        "bg:synthwave": (512, 288, make_fixtures.gradient_rgba(512, 288)),
        "bg:galaxy": (300, 300, make_fixtures.cookie_rgba(300, 300, 100, 15)),
        "acc:crown": (64, 64, make_fixtures.cookie_rgba(64, 64, 20, 16)),
        "fx:huge": (1024, 576, make_fixtures.gradient_rgba(1024, 576)),
    }
    for i in range(1, 4):
        images[f"icon:{i}"] = (48, 48, make_fixtures.cookie_rgba(48, 48, 15, 20 + i))
    lines = []
    index = []
    expect = []
    for n, (key, (w, h, rgba)) in enumerate(sorted(images.items())):
        src, crc = lua_module(key, w, h, rgba)
        name = key.replace(":", "__")
        lines.append(f'add(ImageData, inst("ModuleScript", "{name}", {{ __value = {src} }}))')
        index.append(f'["{key}"] = "{name}"')
        expect.append(f'["{key}"] = {crc}')
    # corrupted data module
    lines.append('add(ImageData, inst("ModuleScript", "ui__broken", { __value = { key = "ui:broken", w = 8, h = 8, z = "eNorz0vOz0vOz0vOz0vOz0vOz0sAAA==" } }))')
    index.append('["ui:broken"] = "ui__broken"')
    lines.append('add(ImageData, inst("ModuleScript", "_index", { __value = { ' + ", ".join(index) + " } }))")
    lines.append('AssetIdsModule.__value = { ["ui:gem"] = 0, ["ui:uploaded"] = 987654, ["b:up_and_embedded"] = 55 }')
    lines.append("local EXPECT = { " + ", ".join(expect) + " }")

    with open(os.path.join(ROBLOX, "src", "client", "Img.lua")) as f:
        img_src = f.read()
    img_src = "\n".join(l for l in img_src.split("\n") if not l.startswith("--!"))
    harness = PRELUDE + "\n".join(lines) + "\nlocal Img = (function()\n" + img_src + "\nend)()\n" + TESTS

    tmp = tempfile.mkdtemp(prefix="img_test_")
    try:
        shutil.copy(os.path.join(ROBLOX, "src", "shared", "Inflate.lua"), os.path.join(tmp, "Inflate.lua"))
        path = os.path.join(tmp, "harness.luau")
        with open(path, "w") as f:
            f.write(harness)
        r = subprocess.run([LUAU, "-O2", path], capture_output=True, text=True)
        sys.stdout.write(r.stdout)
        sys.stderr.write(r.stderr)
        return r.returncode
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
