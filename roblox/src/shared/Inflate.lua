--!native
--!optimize 2
--!strict
--[[
	Inflate — zlib / DEFLATE decoder (RFC 1950 / RFC 1951) and base64 decoder, pure Luau.
	Output always goes into a `buffer`. No Roblox APIs: runs in Roblox and in the Luau CLI.

	Used by Img.lua to decode the images embedded in ReplicatedStorage.Shared.ImageData
	(each module holds base64( zlib( raw RGBA8 ) )).

	API
	  Inflate.base64(s: string, pad: number?, opts: Options?) -> (buffer, number)
	      Decodes standard base64 ("A-Z a-z 0-9 + /", '=' padding optional, no whitespace).
	      Returns a buffer and the number of decoded bytes n. The buffer is n + max(pad, 1)
	      bytes long; the extra bytes are zero (Inflate uses them as read-ahead padding).
	      Errors on invalid characters.

	  Inflate.inflate(src: buffer, opts: Options?) -> (buffer, number, number)
	      Raw DEFLATE stream. Returns (out, outLen, bytesConsumed).
	      If opts.size is given, `out` is exactly that many bytes and the stream must decode to
	      exactly that size (error otherwise). Without it the output grows as needed and is
	      trimmed to outLen.

	  Inflate.zlib(src: buffer, opts: Options?) -> buffer
	      zlib stream (2-byte header, DEFLATE data, adler32). The header is checked; the adler32
	      trailer is checked only when opts.verify is true.

	  Inflate.base64Zlib(s: string, opts: Options?) -> buffer
	      base64 → zlib → buffer in one call (what Img uses).

	  Inflate.adler32(b: buffer, offset: number?, len: number?) -> number

	Options = {
		offset: number?,   -- start of the compressed data in `src` (default 0)
		length: number?,   -- length of the compressed data (default: rest of the buffer)
		size: number?,     -- exact expected output size (recommended: w * h * 4)
		verify: boolean?,  -- zlib: check the adler32 trailer (roughly doubles the time)
		yield: (() -> ())?,-- called to yield when the time budget is exceeded (e.g. task.wait)
		budget: number?,   -- seconds of work between two yields (default 0.004)
		start: number?,    -- os.clock() value the first slice is counted from (default: now)
	}

	When `yield` is given the decoder checks os.clock() every ~16 KB of output (base64: every
	32 KB of text) and calls yield() whenever `budget` seconds have passed, so decoding a large
	image can be spread over several frames from a task.spawn'ed thread without blocking
	rendering. yield() may be anything that yields the current thread (task.wait) or just
	returns.

	Speed (640x640 RGBA cookie, 262 KB of base64 -> 1.6 MB): ~27 ms in the Luau interpreter
	(-O2, ~60 MB/s of output), ~8 ms with native code generation (--!native, ~190 MB/s).

	Implementation notes: 32-bit bit buffer refilled branch-free with one readu32, one-level
	lookup tables (10 bits) for the Huffman codes with a canonical slow path for longer codes,
	table entries pre-encode (symbol or length base, extra bits, code length); short matches
	copied with two u32 read/writes, longer ones with buffer.copy / buffer.fill (overlapping
	matches by doubling copies). base64 reads 2 characters at a time (u16) through two
	65536-entry lookup tables.
]]

local Inflate = {}

export type Options = {
	offset: number?,
	length: number?,
	size: number?,
	verify: boolean?,
	yield: (() -> ())?,
	budget: number?,
	start: number?,
}

local band, bor, rshift, lshift = bit32.band, bit32.bor, bit32.rshift, bit32.lshift
local readu8, readu16, readu32 = buffer.readu8, buffer.readu16, buffer.readu32
local writeu8, writeu32 = buffer.writeu8, buffer.writeu32
local bcopy, bfill, blen, bcreate = buffer.copy, buffer.fill, buffer.len, buffer.create
local clock = os.clock

local FAST = 10 -- bits of the primary Huffman lookup tables
local CHECK = 16384 -- output bytes between two os.clock() checks when yielding
local PAD = 8 -- zero bytes of read-ahead the decoder needs after the input

--------------------------------------------------------------------------------------------
-- Static tables
--------------------------------------------------------------------------------------------
local LBASE = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
local LEXT = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
local DBASE = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 }
local DEXT = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }
local CLORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

-- Value stored in the tables for each symbol ("v"); a table entry is v * 16 + codeLength.
--   literal/length alphabet: 0..255 literal byte, 256 end of block, 257 invalid,
--                            >= 512: length code, v = 512 + base * 8 + extraBits
--   distance alphabet:       v = base * 16 + extraBits, 0 = invalid code (30, 31)
--   code length alphabet:    v = symbol
local LIT_V: { number } = table.create(288, 257)
for s = 0, 256 do
	LIT_V[s + 1] = s
end
for i = 1, 29 do
	LIT_V[257 + i] = 512 + LBASE[i] * 8 + LEXT[i]
end
local DIST_V: { number } = table.create(32, 0)
for i = 1, 30 do
	DIST_V[i] = DBASE[i] * 16 + DEXT[i]
end
local IDENT_V: { number } = table.create(19, 0)
for i = 1, 19 do
	IDENT_V[i] = i - 1
end

type Huff = { t: { number }, mask: number, count: { number }, syms: { number } }

local function reverseBits(code: number, len: number): number
	local r = 0
	for _ = 1, len do
		r = r * 2 + band(code, 1)
		code = rshift(code, 1)
	end
	return r
end

-- Builds a decoding table from code lengths lens[first .. first + n - 1] (symbols 0 .. n-1).
local function build(lens: { number }, first: number, n: number, vmap: { number }): Huff
	local count = table.create(15, 0)
	for i = 0, n - 1 do
		local l = lens[first + i]
		if l > 0 then
			count[l] += 1
		end
	end
	local left, maxLen = 1, 0
	for l = 1, 15 do
		left = left * 2 - count[l]
		if left < 0 then
			error("inflate: over-subscribed Huffman code", 0)
		end
		if count[l] > 0 then
			maxLen = l
		end
	end
	local offs = table.create(15, 0)
	for l = 1, 14 do
		offs[l + 1] = offs[l] + count[l]
	end
	local syms = table.create(n, 0)
	for i = 0, n - 1 do
		local l = lens[first + i]
		if l > 0 then
			local o = offs[l]
			syms[o + 1] = i
			offs[l] = o + 1
		end
	end
	local bits = if maxLen < FAST then (if maxLen < 1 then 1 else maxLen) else FAST
	local size = lshift(1, bits)
	local t = table.create(size, 0) -- 0 = "not in the table": long or invalid code
	local code, k = 0, 1
	for len = 1, maxLen do
		local c = count[len]
		if len <= bits then
			local step = lshift(1, len)
			for _ = 1, c do
				local e = vmap[syms[k] + 1] * 16 + len
				for j = reverseBits(code, len) + 1, size, step do
					t[j] = e
				end
				k += 1
				code += 1
			end
		else
			k += c
			code += c
		end
		code *= 2
	end
	return { t = t, mask = size - 1, count = count, syms = syms }
end

-- Canonical decoding for codes longer than the table (or invalid). Peeks at `bb`, returns
-- (table entry, code length) or (-1, 0).
local function slowDecode(bb: number, h: Huff, vmap: { number }): (number, number)
	local count, syms = h.count, h.syms
	local code, firstCode, index = 0, 0, 0
	for len = 1, 15 do
		code += band(bb, 1)
		bb = rshift(bb, 1)
		local c = count[len]
		if code - c < firstCode then
			return vmap[syms[index + (code - firstCode) + 1] + 1] * 16 + len, len
		end
		index += c
		firstCode = (firstCode + c) * 2
		code *= 2
	end
	return -1, 0
end

local fixedLit: Huff?, fixedDist: Huff?
local function fixedTables(): (Huff, Huff)
	if not fixedLit then
		local l = table.create(288, 8)
		for i = 145, 256 do
			l[i] = 9
		end
		for i = 257, 280 do
			l[i] = 7
		end
		fixedLit = build(l, 1, 288, LIT_V)
		fixedDist = build(table.create(30, 5), 1, 30, DIST_V)
	end
	return fixedLit :: Huff, fixedDist :: Huff
end

local function grow(out: buffer, cap: number, used: number, need: number, fixed: boolean): (buffer, number)
	if fixed then
		error("inflate: data decodes to more bytes than the expected size", 0)
	end
	local ncap = cap * 2
	while ncap < need do
		ncap *= 2
	end
	local nb = bcreate(ncap)
	bcopy(nb, 0, out, 0, used)
	return nb, ncap
end

--------------------------------------------------------------------------------------------
-- Core decoder. inp must have >= PAD readable bytes after inEnd.
--------------------------------------------------------------------------------------------
local function core(
	inp: buffer,
	ip: number,
	inEnd: number,
	out: buffer,
	cap: number,
	fixed: boolean,
	yieldFn: (() -> ())?,
	budget: number,
	t0: number
): (buffer, number, number)
	local bb, bc = 0, 0 -- bit buffer (LSB first) and number of valid bits in it
	local op = 0
	local checkAt = if yieldFn then CHECK else math.huge
	local final = 0
	repeat
		-- block header (3 bits)
		bb = bor(bb, lshift(readu32(inp, ip), bc))
		ip += rshift(31 - bc, 3)
		bc = bor(bc, 24)
		final = band(bb, 1)
		local btype = band(rshift(bb, 1), 3)
		bb = rshift(bb, 3)
		bc -= 3

		if btype == 0 then
			-- stored block: drop to a byte boundary and give the unread whole bytes back
			ip -= rshift(bc, 3)
			bb, bc = 0, 0
			if ip + 4 > inEnd then
				error("inflate: truncated input", 0)
			end
			local len = readu16(inp, ip)
			if readu16(inp, ip + 2) ~= 65535 - len then
				error("inflate: stored block length mismatch", 0)
			end
			ip += 4
			if ip + len > inEnd then
				error("inflate: truncated input", 0)
			end
			if op + len > cap then
				out, cap = grow(out, cap, op, op + len, fixed)
			end
			bcopy(out, op, inp, ip, len)
			ip += len
			op += len
		elseif btype == 3 then
			error("inflate: invalid block type", 0)
		else
			local lh: Huff, dh: Huff
			if btype == 1 then
				lh, dh = fixedTables()
			else
				-- dynamic block: read the code length code, then the literal/length and distance code lengths
				bb = bor(bb, lshift(readu32(inp, ip), bc))
				ip += rshift(31 - bc, 3)
				bc = bor(bc, 24)
				local hlit = band(bb, 31) + 257
				local hdist = band(rshift(bb, 5), 31) + 1
				local hclen = band(rshift(bb, 10), 15) + 4
				bb = rshift(bb, 14)
				bc -= 14
				if hlit > 286 or hdist > 30 then
					error("inflate: too many length or distance codes", 0)
				end
				local cl = table.create(19, 0)
				for i = 1, hclen do
					if bc < 3 then
						bb = bor(bb, lshift(readu32(inp, ip), bc))
						ip += rshift(31 - bc, 3)
						bc = bor(bc, 24)
					end
					cl[CLORDER[i] + 1] = band(bb, 7)
					bb = rshift(bb, 3)
					bc -= 3
				end
				local ch = build(cl, 1, 19, IDENT_V)
				local ct, cmask = ch.t, ch.mask
				local total = hlit + hdist
				local lens = table.create(total, 0)
				local i = 1
				while i <= total do
					bb = bor(bb, lshift(readu32(inp, ip), bc))
					ip += rshift(31 - bc, 3)
					bc = bor(bc, 24)
					local e = ct[band(bb, cmask) + 1]
					local l = band(e, 15)
					if l == 0 then
						e, l = slowDecode(bb, ch, IDENT_V)
						if l == 0 then
							error("inflate: invalid code length code", 0)
						end
					end
					bb = rshift(bb, l)
					bc -= l
					local sym = rshift(e, 4)
					if sym < 16 then
						lens[i] = sym
						i += 1
					else
						local rep, val = 0, 0
						if sym == 16 then
							if i == 1 then
								error("inflate: repeat with no previous length", 0)
							end
							val = lens[i - 1]
							rep = 3 + band(bb, 3)
							bb = rshift(bb, 2)
							bc -= 2
						elseif sym == 17 then
							rep = 3 + band(bb, 7)
							bb = rshift(bb, 3)
							bc -= 3
						else
							rep = 11 + band(bb, 127)
							bb = rshift(bb, 7)
							bc -= 7
						end
						if i + rep - 1 > total then
							error("inflate: code lengths overflow", 0)
						end
						for k = i, i + rep - 1 do
							lens[k] = val
						end
						i += rep
					end
				end
				if lens[257] == 0 then
					error("inflate: missing end-of-block code", 0)
				end
				lh = build(lens, 1, hlit, LIT_V)
				dh = build(lens, hlit + 1, hdist, DIST_V)
			end

			-- Huffman-coded data: the hot loop
			local lt, lmask = lh.t, lh.mask
			local dt, dmask = dh.t, dh.mask
			while true do
				if bc < 15 then
					bb = bor(bb, lshift(readu32(inp, ip), bc))
					ip += rshift(31 - bc, 3)
					bc = bor(bc, 24)
				end
				local e = lt[band(bb, lmask) + 1]
				local l = band(e, 15)
				if l == 0 then
					e, l = slowDecode(bb, lh, LIT_V)
					if l == 0 then
						error("inflate: invalid literal/length code", 0)
					end
				end
				bb = rshift(bb, l)
				bc -= l
				local v = rshift(e, 4)
				if v < 256 then
					if op >= cap then
						out, cap = grow(out, cap, op, op + 1, fixed)
					end
					writeu8(out, op, v)
					op += 1
				elseif v >= 512 then
					-- length (base + up to 5 extra bits), then distance code (up to 15 bits)
					if bc < 20 then
						bb = bor(bb, lshift(readu32(inp, ip), bc))
						ip += rshift(31 - bc, 3)
						bc = bor(bc, 24)
					end
					local len = rshift(v, 3) - 64
					local ext = band(v, 7)
					if ext > 0 then
						len += band(bb, lshift(1, ext) - 1)
						bb = rshift(bb, ext)
						bc -= ext
					end
					local de = dt[band(bb, dmask) + 1]
					local dl = band(de, 15)
					if dl == 0 then
						de, dl = slowDecode(bb, dh, DIST_V)
						if dl == 0 then
							error("inflate: invalid distance code", 0)
						end
					end
					bb = rshift(bb, dl)
					bc -= dl
					local dv = rshift(de, 4)
					local dist = rshift(dv, 4)
					local dext = band(dv, 15)
					if dext > 0 then
						if bc < dext then
							bb = bor(bb, lshift(readu32(inp, ip), bc))
							ip += rshift(31 - bc, 3)
							bc = bor(bc, 24)
						end
						dist += band(bb, lshift(1, dext) - 1)
						bb = rshift(bb, dext)
						bc -= dext
					end
					local src = op - dist
					if dist == 0 or src < 0 then
						error("inflate: invalid distance", 0)
					end
					if op + len > cap then
						out, cap = grow(out, cap, op, op + len, fixed)
					end
					if dist >= 4 and len <= 8 and op + 8 <= cap then
						-- short match (the most common case in images), source at least 4 bytes back:
						-- two 4-byte copies. Bytes written past op + len are scratch space that the
						-- following output overwrites before anything can read them.
						writeu32(out, op, readu32(out, src))
						writeu32(out, op + 4, readu32(out, src + 4))
					elseif dist >= len then
						bcopy(out, op, out, src, len)
					elseif dist == 1 then
						bfill(out, op, readu8(out, src), len)
					elseif len < 16 then
						for k = 0, len - 1 do
							writeu8(out, op + k, readu8(out, src + k))
						end
					else
						-- overlapping match: repeat the `dist`-byte pattern by doubling copies
						local done = 0
						while done < len do
							local n = dist + done
							if n > len - done then
								n = len - done
							end
							bcopy(out, op + done, out, src, n)
							done += n
						end
					end
					op += len
					if op >= checkAt then
						checkAt = op + CHECK
						if clock() - t0 >= budget then
							(yieldFn :: () -> ())()
							t0 = clock()
						end
					end
				elseif v == 256 then
					break
				else
					error("inflate: invalid literal/length symbol", 0)
				end
			end
		end
		if ip > inEnd + 4 then
			error("inflate: truncated input", 0)
		end
		if yieldFn and clock() - t0 >= budget then
			yieldFn()
			t0 = clock()
		end
	until final == 1
	local consumed = ip - rshift(bc, 3)
	if consumed > inEnd then
		error("inflate: truncated input", 0)
	end
	return out, op, consumed
end

local function prepare(src: buffer, opts: Options?): (buffer, number, number)
	local off = (opts and opts.offset) or 0
	local len = (opts and opts.length) or (blen(src) - off)
	if off < 0 or len < 0 or off + len > blen(src) then
		error("inflate: offset/length out of range", 0)
	end
	if blen(src) - (off + len) >= PAD then
		return src, off, off + len
	end
	local p = bcreate(len + PAD) -- padded copy (read-ahead needs PAD bytes after the data)
	bcopy(p, 0, src, off, len)
	return p, 0, len
end

local function run(inp: buffer, ip: number, inEnd: number, opts: Options?): (buffer, number, number)
	local size = opts and opts.size
	local yieldFn = opts and opts.yield
	local budget = (opts and opts.budget) or 0.004
	local out: buffer, cap: number
	if size then
		out, cap = bcreate(size), size
	else
		cap = math.max(4 * (inEnd - ip), 1024)
		out = bcreate(cap)
	end
	local op, consumed
	out, op, consumed = core(inp, ip, inEnd, out, cap, size ~= nil, yieldFn, budget, (opts and opts.start) or clock())
	if size then
		if op ~= size then
			error(string.format("inflate: decoded %d bytes, expected %d", op, size), 0)
		end
	elseif op ~= blen(out) then
		local trimmed = bcreate(op)
		bcopy(trimmed, 0, out, 0, op)
		out = trimmed
	end
	return out, op, consumed
end

function Inflate.inflate(src: buffer, opts: Options?): (buffer, number, number)
	local inp, ip, inEnd = prepare(src, opts)
	local out, n, consumed = run(inp, ip, inEnd, opts)
	return out, n, consumed - ip
end

function Inflate.adler32(b: buffer, offset: number?, len: number?): number
	local i = offset or 0
	local e = i + (len or (blen(b) - i))
	local s1, s2 = 1, 0
	while i < e do
		-- numbers are doubles: 1 MB chunks keep s2 far below 2^53 before the modulo
		local stop = math.min(i + 1048576, e) - 1
		for j = i, stop do
			s1 += readu8(b, j)
			s2 += s1
		end
		s1 %= 65521
		s2 %= 65521
		i = stop + 1
	end
	return s2 * 65536 + s1
end

function Inflate.zlib(src: buffer, opts: Options?): buffer
	local inp, ip, inEnd = prepare(src, opts)
	if inEnd - ip < 6 then
		error("inflate: zlib stream too short", 0)
	end
	local cmf, flg = readu8(inp, ip), readu8(inp, ip + 1)
	if band(cmf, 15) ~= 8 or rshift(cmf, 4) > 7 or (cmf * 256 + flg) % 31 ~= 0 then
		error("inflate: bad zlib header", 0)
	end
	if band(flg, 32) ~= 0 then
		error("inflate: zlib preset dictionary not supported", 0)
	end
	local out, n, consumed = run(inp, ip + 2, inEnd, opts)
	if opts and opts.verify then
		if consumed + 4 > inEnd then
			error("inflate: missing adler32", 0)
		end
		local expect = bor(
			lshift(readu8(inp, consumed), 24),
			lshift(readu8(inp, consumed + 1), 16),
			lshift(readu8(inp, consumed + 2), 8),
			readu8(inp, consumed + 3)
		)
		if Inflate.adler32(out, 0, n) ~= expect then
			error("inflate: adler32 mismatch", 0)
		end
	end
	return out
end

--------------------------------------------------------------------------------------------
-- base64
--------------------------------------------------------------------------------------------
-- A group of 4 characters c0..c3 (6 bits each: a b c d) decodes to 3 bytes x0 x1 x2, written
-- as one little-endian u32 x0 + x1<<8 + x2<<16 (the 4th byte is overwritten by the next group).
-- The group is read as two u16 (c0 + c1*256, c2 + c3*256); two 65536-entry u32 tables (built on
-- first use, 256 KB each) give each pair's contribution to that u32. Invalid pairs map to
-- 0xFFFFFFFF so the sum overflows 24 bits.
local B64P: buffer?, B64Q: buffer?
local B64V: { number } = table.create(256, -1) -- single character -> 6-bit value, -1 invalid
do
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for v = 0, 63 do
		B64V[string.byte(alphabet, v + 1) + 1] = v
	end
end

local function b64Tables(): (buffer, buffer)
	if not B64P then
		local P, Q = bcreate(65536 * 4), bcreate(65536 * 4)
		bfill(P, 0, 0xFF)
		bfill(Q, 0, 0xFF)
		for c0 = 0, 255 do
			local a = B64V[c0 + 1]
			if a >= 0 then
				for c1 = 0, 255 do
					local b = B64V[c1 + 1]
					if b >= 0 then
						local idx = (c0 + c1 * 256) * 4
						writeu32(P, idx, lshift(a, 2) + rshift(b, 4) + lshift(band(b, 15), 12))
						writeu32(Q, idx, lshift(rshift(a, 2), 8) + lshift(band(a, 3), 22) + lshift(b, 16))
					end
				end
			end
		end
		B64P, B64Q = P, Q
	end
	return B64P :: buffer, B64Q :: buffer
end

-- returns (buffer, decoded length, os.clock() at the start of the current time slice)
local function decode64(s: string, pad: number?, opts: Options?): (buffer, number, number)
	local n = #s
	while n > 0 and string.byte(s, n) == 61 do -- strip '='
		n -= 1
	end
	local rem = n % 4
	if rem == 1 then
		error("base64: invalid length", 0)
	end
	local groups = (n - rem) // 4
	local outLen = groups * 3 + (if rem == 0 then 0 else rem - 1)
	local extra = math.max(pad or 0, 1)
	local out = bcreate(outLen + extra)
	local src = buffer.fromstring(s)
	local yieldFn = opts and opts.yield
	local budget = (opts and opts.budget) or 0.004
	local P, Q = b64Tables()
	local o = 0
	local i = 0
	local stopAll = groups * 4
	local t0 = (opts and opts.start) or clock()
	while i < stopAll do
		-- chunks of 32 KB of text between clock checks
		local stop = math.min(i + 32768, stopAll) - 4
		for j = i, stop, 4 do
			local v = readu32(P, readu16(src, j) * 4) + readu32(Q, readu16(src, j + 2) * 4)
			if v > 0xFFFFFF then
				error("base64: invalid character", 0)
			end
			writeu32(out, o, v)
			o += 3
		end
		i = stop + 4
		if yieldFn and clock() - t0 >= budget then
			yieldFn()
			t0 = clock()
		end
	end
	if rem > 0 then
		local a, b = B64V[readu8(src, i) + 1], B64V[readu8(src, i + 1) + 1]
		local c = if rem == 3 then B64V[readu8(src, i + 2) + 1] else 0
		if a < 0 or b < 0 or c < 0 then
			error("base64: invalid character", 0)
		end
		local v = a * 262144 + b * 4096 + c * 64 -- 24 bits, big-endian bytes
		writeu8(out, o, rshift(v, 16))
		if rem == 3 then
			writeu8(out, o + 1, band(rshift(v, 8), 255))
		end
	end
	-- the last full group wrote one byte past its 3 bytes: clear it if it is past the data
	writeu8(out, outLen, 0)
	return out, outLen, t0
end

function Inflate.base64(s: string, pad: number?, opts: Options?): (buffer, number)
	local out, n = decode64(s, pad, opts)
	return out, n
end

-- base64 string → zlib inflate → buffer (exactly opts.size bytes when given).
function Inflate.base64Zlib(s: string, opts: Options?): buffer
	local comp, n, t0 = decode64(s, PAD, opts)
	local o: Options = {
		offset = 0,
		length = n,
		size = opts and opts.size,
		verify = opts and opts.verify,
		yield = opts and opts.yield,
		budget = opts and opts.budget,
		start = t0, -- the time slice continues from the base64 phase
	}
	return Inflate.zlib(comp, o)
end

return Inflate
