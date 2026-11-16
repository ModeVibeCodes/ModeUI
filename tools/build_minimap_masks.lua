-- Builds the Minimap module's mask textures. Run from the repository root
-- with any Lua 5.1+:
--   lua tools/build_minimap_masks.lua
--
-- The game draws the minimap square and stretches its mask (Minimap:
-- SetMaskTexture) over that square, so a mask's shape is a fraction of the
-- map's side. To keep the difference between width and height, and the
-- corner radius, in exact pixels at every size, there is one mask per size
-- and difference (the same lists as Modules/Minimap/Init.lua; the radius is
-- 0 since the map sits in the Mode edge, whose rim covers the corners):
--   Minimap/Mask-<size>-<difference>-<radius>.tga
-- Each is 256x256, white with matching alpha (so it works whichever channel
-- the client reads): a rounded rectangle as wide as the map, `difference`
-- pixels shorter (half off the top, half off the bottom), with `radius`
-- pixel corners. The shape sits half a pixel inside the map's edge, so the
-- mask's soft edge lies under the border and nothing shows outside it.
-- Files are run-length encoded 32-bit TGAs (type 10), the format other
-- minimap addons ship their masks in.
local SIZES, DIFFERENCES, RADII = {}, { 0, 8, 16, 24, 32, 40, 48 }, { 0 }
for size = 140, 280, 4 do SIZES[#SIZES + 1] = size end
local RES, INSET, SAMPLES = 256, 0.5, 8
local ROOT = "ModeUI/Media/Textures/Minimap/"

local function U16(value) return string.char(value % 256, math.floor(value / 256) % 256) end

-- Coverage (0-1) of texel (i, j) for a map `size` wide, `difference` shorter
-- and `radius` round at the corners, in the map's pixel units.
local function Shape(size, difference, radius)
    local s = size / RES
    local left, right = INSET, size - INSET
    local top, bottom = difference / 2 + INSET, size - difference / 2 - INSET
    local r = math.max(0, radius - INSET)
    local function Overlap(a, b, low, high) return math.max(0, math.min(b, high) - math.max(a, low)) end
    local function Inside(x, y)
        if x < left or x > right or y < top or y > bottom then return false end
        local cx = math.max(left + r, math.min(right - r, x))
        local cy = math.max(top + r, math.min(bottom - r, y))
        local dx, dy = x - cx, y - cy
        return dx * dx + dy * dy <= r * r
    end
    return function(i, j)
        local x0, y0 = i * s, j * s
        local x1, y1 = x0 + s, y0 + s
        local inCornerX = x0 < left + r or x1 > right - r
        local inCornerY = y0 < top + r or y1 > bottom - r
        if r == 0 or not (inCornerX and inCornerY) then
            return Overlap(x0, x1, left, right) * Overlap(y0, y1, top, bottom) / (s * s)
        end
        local hits = 0
        for sy = 0, SAMPLES - 1 do
            for sx = 0, SAMPLES - 1 do
                if Inside(x0 + (sx + 0.5) * s / SAMPLES, y0 + (sy + 0.5) * s / SAMPLES) then hits = hits + 1 end
            end
        end
        return hits / (SAMPLES * SAMPLES)
    end
end

-- One row of BGRA pixels as RLE and raw packets (never across rows).
local function EncodeRow(values, parts)
    local n, i = #values, 1
    local function Pixel(v) return string.char(v, v, v, v) end
    while i <= n do
        local run = 1
        while i + run <= n and values[i + run] == values[i] and run < 128 do run = run + 1 end
        if run > 1 then
            parts[#parts + 1] = string.char(0x80 + run - 1) .. Pixel(values[i])
            i = i + run
        else
            local start = i
            local count = 0
            while i <= n and count < 128 and not (i + 1 <= n and values[i + 1] == values[i]) do
                i = i + 1; count = count + 1
            end
            if count == 0 then i = i + 1; count = 1 end
            local raw = {}
            for k = start, start + count - 1 do raw[#raw + 1] = Pixel(values[k]) end
            parts[#parts + 1] = string.char(count - 1) .. table.concat(raw)
        end
    end
end

local function WriteMask(path, coverage)
    -- Type 10 (RLE true color), 32 bits, top-left origin with 8 alpha bits.
    local parts = { string.char(0, 0, 10, 0, 0, 0, 0, 0), U16(0), U16(0), U16(RES), U16(RES), string.char(32, 0x28) }
    for j = 0, RES - 1 do
        local row = {}
        for i = 0, RES - 1 do row[i + 1] = math.floor(math.max(0, math.min(1, coverage(i, j))) * 255 + 0.5) end
        EncodeRow(row, parts)
    end
    local file = assert(io.open(path, "wb"), "cannot write " .. path)
    file:write(table.concat(parts)); file:close()
end

local count = 0
for _, size in ipairs(SIZES) do
    for _, difference in ipairs(DIFFERENCES) do
        for _, radius in ipairs(RADII) do
            WriteMask(string.format("%sMask-%d-%d-%d.tga", ROOT, size, difference, radius), Shape(size, difference, radius))
            count = count + 1
        end
    end
end
print(string.format("minimap masks: %d written to %s", count, ROOT))
