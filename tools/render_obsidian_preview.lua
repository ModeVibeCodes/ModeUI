-- Offline preview of the Mode-Obsidian theme (docs/DESIGN_LANGUAGE.md,
-- "Mode-Obsidian theme"; docs/OBSIDIAN.md): composites the generated textures
-- the way the client tints and layers them, into a PNG, so the look can be
-- checked without the game. It reads Shared/Style/EdgeData.lua for the rings.
-- Run from the repository root after tools/build_mode_assets.lua:
--   lua tools/render_obsidian_preview.lua [out.png]
-- (default design/obsidian/preview.png). The scene: the Player frame with its
-- class ring, an icon, a party member with the Prism glow and a Backlit Magic
-- gradient, a tooltip window, action buttons (one with a proc rim) and an
-- enemy nameplate. Approximate: no text, no portrait art.
local ROOT = "ModeUI/Media/Textures/Mode/"
local D = dofile("ModeUI/Shared/Style/EdgeData.lua")

-- TGA (uncompressed 32-bit, top-left origin) -> { w, h, px = { {r,g,b,a} ... } }
local cache = {}
local function TGA(path)
    if cache[path] then return cache[path] end
    local f = assert(io.open(ROOT .. path .. ".tga", "rb"), path)
    local s = f:read("a"); f:close()
    local w = s:byte(13) + s:byte(14) * 256
    local h = s:byte(15) + s:byte(16) * 256
    local img = { w = w, h = h }
    local o = 19
    for i = 0, w * h - 1 do
        local b, g, r, a = s:byte(o, o + 3)
        img[i] = { r / 255, g / 255, b / 255, a / 255 }
        o = o + 4
    end
    cache[path] = img
    return img
end
local function Hex(h) return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 } end

-- Canvas
local W, H = 340, 230
local C = {}
local function Set(x, y, c) C[y * W + x] = c end
local function Get(x, y) return C[y * W + x] end
for y = 0, H - 1 do
    local t = y / (H - 1)
    local top, mid, bot = Hex("3B4A44"), Hex("1E2629"), Hex("0E1114")
    local a, b, u = top, mid, t / 0.55
    if t > 0.55 then a, b, u = mid, bot, (t - 0.55) / 0.45 end
    for x = 0, W - 1 do Set(x, y, { a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u }) end
end
local function Blend(x, y, color, alpha)
    if x < 0 or y < 0 or x >= W or y >= H or alpha <= 0 then return end
    local c = Get(x, y)
    Set(x, y, { c[1] + (color[1] - c[1]) * alpha, c[2] + (color[2] - c[2]) * alpha, c[3] + (color[3] - c[3]) * alpha })
end
local function Add(x, y, color, alpha)
    if x < 0 or y < 0 or x >= W or y >= H then return end
    local c = Get(x, y)
    Set(x, y, { math.min(1, c[1] + color[1] * alpha), math.min(1, c[2] + color[2] * alpha), math.min(1, c[3] + color[3] * alpha) })
end

-- A nine-sliced texture over a rect (x0, y0, w, h), corners `m` drawn 1:1,
-- edges and middle stretched (nearest), tinted `tint` at `alpha`.
local function Slice(img, m, x0, y0, w, h, tint, alpha, add)
    for y = 0, h - 1 do
        local sy
        if y < m then sy = y elseif y >= h - m then sy = img.h - (h - y) else sy = m + math.floor((y - m) / math.max(1, h - 2 * m) * (img.h - 2 * m)) end
        for x = 0, w - 1 do
            local sx
            if x < m then sx = x elseif x >= w - m then sx = img.w - (w - x) else sx = m + math.floor((x - m) / math.max(1, w - 2 * m) * (img.w - 2 * m)) end
            local p = img[sy * img.w + sx]
            local a = p[4] * (alpha or 1)
            if a > 0 then
                local c = { p[1] * tint[1], p[2] * tint[2], p[3] * tint[3] }
                if add then Add(x0 + x, y0 + y, c, a) else Blend(x0 + x, y0 + y, c, a) end
            end
        end
    end
end
-- A texture stretched over a rect (bilinear), tinted.
local function Stretch(img, x0, y0, w, h, tint, alpha)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local fx, fy = (x + 0.5) / w * img.w - 0.5, (y + 0.5) / h * img.h - 0.5
            local ix, iy = math.max(0, math.min(img.w - 2, math.floor(fx))), math.max(0, math.min(img.h - 2, math.floor(fy)))
            local ux, uy = math.max(0, math.min(1, fx - ix)), math.max(0, math.min(1, fy - iy))
            local acc = { 0, 0, 0, 0 }
            for _, s in ipairs({ { 0, 0, (1 - ux) * (1 - uy) }, { 1, 0, ux * (1 - uy) }, { 0, 1, (1 - ux) * uy }, { 1, 1, ux * uy } }) do
                local p = img[(iy + s[2]) * img.w + ix + s[1]]
                for k = 1, 4 do acc[k] = acc[k] + p[k] * s[3] end
            end
            local a = acc[4] * (alpha or 1)
            if a > 0 then Blend(x0 + x, y0 + y, { acc[1] * tint[1], acc[2] * tint[2], acc[3] * tint[3] }, a) end
        end
    end
end

-- Tones (Style.Tone under Mode-Obsidian).
local metal = { hi = Hex("6E6E74"), light = Hex("8C806A"), mid = Hex("2A2A2D"), dark = Hex("18181A"), deep = Hex("0F0F11") }
local BLACK = { 0, 0, 0 }
local darkFill, slate, ice, mana = Hex("161618"), Hex("46464B"), Hex("D6EBFF"), Hex("4096FF")
local class = Hex("FF7C0A")

-- A border of role `preset` around host rect (hx, hy, hw, hh).
local function Border(preset, hx, hy, hw, hh, tintBand)
    local rings = D.Rings(preset, "obsidian")
    for _, ring in ipairs(rings) do
        local spec = D.SHAPES[ring.shape]
        local img = TGA("Borders/" .. ring.key)
        local out = ring.out
        local tint, alpha
        if ring.kind == "shadow" then tint, alpha = BLACK, 0.9
        elseif ring.kind == "gap" then tint, alpha = BLACK, 1
        else tint, alpha = tintBand and (not ring.profile and tintBand) or metal[ring.tone], 1
            if tintBand and ring.profile then alpha = 0 end end
        Slice(img, spec.margin, hx - out, hy - out, hw + 2 * out, hh + 2 * out, tint, alpha)
    end
end

-- A bar: track (Mode-Obsidian Track tinted slate at 85%), fill (Mode-Obsidian
-- base x color, plus its lift), the ice end line 1px in.
local function Bar(x0, y0, w, h, value, color, track, endLine, liftKey, baseKey)
    local trackImg = TGA("Bars/" .. (track or "ObsidianTrack"))
    Stretch(trackImg, x0, y0, w, h, slate, 0.85)
    local fw = math.floor(w * value + 0.5)
    if fw > 0 then
        Stretch(TGA("Bars/" .. (baseKey or "ObsidianBase")), x0, y0, fw, h, color, 1)
        if liftKey ~= false then
            local lift = TGA("Bars/" .. (liftKey or "ObsidianLift"))
            for y = 0, h - 1 do for x = 0, fw - 1 do
                local p = lift[math.floor((y + 0.5) / h * lift.h) * lift.w + math.floor((x + 0.5) / fw * lift.w)]
                Blend(x0 + x, y0 + y, { 1, 1, 1 }, p[4])
            end end
        end
        if endLine and fw < w then for y = 1, h - 2 do Blend(x0 + fw - 1, y0 + y, ice, 0.85) end end
    end
end

-- The Player frame: the bar block (34 + 1 + 3) at the `frame` role, the ring.
local bx, by, bw = 104, 52, 184
-- the block's back (Tone.shadow) and health / hairline / power
for y = 0, 37 do for x = 0, bw - 1 do Blend(bx + x, by + y, BLACK, 1) end end
Bar(bx, by, bw, 34, 0.58, darkFill, nil, true)
Bar(bx, by + 35, bw, 3, 0.64, mana, "ObsidianTrack", false, "GradientLift", "Solid")
Border("frame", bx, by, bw, 38)

-- The portrait ring: 62px, class tones (Style.ColorTones).
local function Tones(c)
    local function T(t) local r = {}; for i = 1, 3 do r[i] = t >= 0 and c[i] + (1 - c[i]) * t or c[i] * (1 + t) end; return r end
    return { hi = T(0.6), light = T(0.3), mid = T(0), dark = T(-0.45), deep = T(-0.65) }
end
local d = 62
local rx, ry = bx - d + math.floor(d * 0.36 + 0.5), by + 19 - d / 2
local tones = Tones(class)
Stretch(TGA("Masks/Circle"), rx - 1, ry - 1, d + 2, d + 2, BLACK, 0.9)
for _, layer in ipairs(D.RingLayers("obsidian")) do
    Stretch(TGA(layer.profile and ("Borders/Ring" .. layer.profile) or "Masks/Circle"), rx, ry, d, d, tones[layer.tone], 1)
end
Stretch(TGA("Masks/Circle"), rx + 2, ry + 2, d - 4, d - 4, BLACK, 1)
-- a placeholder portrait: a dark warm disc
Stretch(TGA("Masks/Circle"), rx + 3, ry + 3, d - 6, d - 6, Hex("3A2A1E"), 1)

-- A small Mode-Obsidian icon frame (frameThin, 40x34) and a party frame with
-- its Prism glow (group role) and a Backlit Magic gradient.
local ix, iy = 104, 104
for y = 0, 33 do for x = 0, 39 do Blend(ix + x, iy + y, Hex("2D4E73"), 1) end end
Border("frameThin", ix, iy, 40, 34)
local px, py = 168, 104
Slice(TGA("Glows/Prism"), 14, px - 8, py - 8, 150 + 16, 30 + 16, class, 0.55, true)
for y = 0, 29 do for x = 0, 149 do Blend(px + x, py + y, BLACK, 1) end end
Bar(px, py, 150, 30, 0.72, darkFill, nil, true)
for y = 0, 29 do local a = 0.56 * math.max(0, (y - 30 * 0.28) / (30 * 0.72)); for x = 0, 149 do Blend(px + x, py + y, Hex("3399FF"), a) end end
Border("group", px, py, 150, 30)

-- A tooltip: the `window` role round a Graphite panel (Mode-Obsidian), with
-- a title line and two text lines as bars of light (no font here).
local tx, ty, tw, th = 24, 156, 150, 60
for y = 0, th - 1 do for x = 0, tw - 1 do Blend(tx + x, ty + y, Hex("0B0B0C"), 0.95) end end
for x = 8, 90 do for y = 9, 12 do Blend(tx + x, ty + y, Hex("E5484D"), 0.9) end end
for x = 8, 120 do for y = 22, 24 do Blend(tx + x, ty + y, Hex("8A857C"), 0.8) end end
for x = 8, 110 do Blend(tx + x, ty + 31, Hex("232325"), 1) end
for x = 8, 100 do for y = 38, 40 do Blend(tx + x, ty + y, Hex("FFB12F"), 0.85) end end
Border("window", tx, ty, tw, th)

-- Action buttons (the `frame` role, 40x34, 4px apart outside the shadows);
-- the third has a proc: an `empty` rim in Celadon over its edge (2px).
for i = 0, 2 do
    local x0, y0 = 196 + i * 47, 158
    local face = ({ Hex("6B3A12"), Hex("1F4A2E"), Hex("3D2563") })[i + 1]
    for y = 0, 33 do for x = 0, 39 do Blend(x0 + x, y0 + y, face, 1) end end
    Border("frame", x0, y0, 40, 34)
    if i == 2 then
        for _, ring in ipairs(D.Rings("empty", "obsidianEmpty", 2)) do
            local spec = D.SHAPES[ring.shape]
            if not ring.profile then
                local tint = ring.kind == "shadow" and BLACK or Hex("B4CDB6")
                Slice(TGA("Borders/" .. ring.key), spec.margin, x0 - ring.out, y0 - ring.out, 40 + 2 * ring.out, 34 + 2 * ring.out, tint, ring.kind == "shadow" and 0.9 or 1)
            end
        end
    end
end

-- An enemy nameplate (frameThin, 130x9): reaction red on Mode BG fill, the
-- Mode-Obsidian Track behind it.
local nx, ny = 200, 206
for y = 0, 8 do for x = 0, 129 do Blend(nx + x, ny + y, BLACK, 1) end end
Bar(nx, ny, 130, 9, 0.7, Hex("E5484D"), nil, false, false, "BG")
Border("frameThin", nx, ny, 130, 9)

-- PNG writer (stored deflate blocks), scaled `S` times.
local S = 4
local function U32(n) return string.char((n >> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255) end
local crcTable = {}
for i = 0, 255 do local c = i; for _ = 1, 8 do c = (c & 1) == 1 and (0xEDB88320 ~ (c >> 1)) or (c >> 1) end; crcTable[i] = c end
local function CRC(s) local c = 0xFFFFFFFF; for i = 1, #s do c = crcTable[(c ~ s:byte(i)) & 255] ~ (c >> 8) end; return c ~ 0xFFFFFFFF end
local function Chunk(kind, data) return U32(#data) .. kind .. data .. U32(CRC(kind .. data)) end
local rows = {}
for y = 0, H * S - 1 do
    local row = { "\0" }
    for x = 0, W * S - 1 do
        local c = Get(x // S, y // S)
        row[#row + 1] = string.char(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
    end
    rows[#rows + 1] = table.concat(row)
end
local raw = table.concat(rows)
local blocks, a, b = {}, 1, 0
for i = 1, #raw do a = (a + raw:byte(i)) % 65521; b = (b + a) % 65521 end
local pos = 1
while pos <= #raw do
    local len = math.min(65535, #raw - pos + 1)
    local final = (pos + len > #raw) and 1 or 0
    blocks[#blocks + 1] = string.char(final, len & 255, len >> 8, (~len) & 255, ((~len) >> 8) & 255) .. raw:sub(pos, pos + len - 1)
    pos = pos + len
end
local idat = "\120\1" .. table.concat(blocks) .. U32((b << 16) | a)
local png = "\137PNG\r\n\26\n" .. Chunk("IHDR", U32(W * S) .. U32(H * S) .. string.char(8, 2, 0, 0, 0)) .. Chunk("IDAT", idat) .. Chunk("IEND", "")
local path = arg[1] or "design/obsidian/preview.png"
local out = assert(io.open(path, "wb")); out:write(png); out:close()
print("wrote " .. path)
