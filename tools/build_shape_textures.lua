-- Builds ModeUI's procedural shape textures: white with anti-aliased alpha,
-- tinted in game. Run from the repository root with any Lua 5.1+:
--   lua tools/build_shape_textures.lua
--
--   Mode/Flat.tga        ModeFlat: soft rounded fill for settings controls (radius 4, sliced at 5)
--   Mode/Card.tga        ModeCard: settings cards (radius 6, sliced at 7)
--   Mode/Circle.tga      ModeCircle: switch knobs and slider thumbs (unsliced)
--   Mode/Switch.tga      ModeSwitch: 32x16 stadium switch track (sliced 8 left and right)
--   Mode/Track.tga       ModeTrack: 8x4 stadium slider track (sliced 2 left and right)
--   Mode/Chevron.tga     ModeChevron: small down chevron for dropdowns
--   Nameplates/Rim.tga   plate and aura rims (radius 3, sliced at 4)
--   Nameplates/Gap.tga   the black gap inside a rim (radius 2, sliced at 3)
--   Nameplates/Glow.tga  soft target glow around a plate, hollow inside (sliced at 12)
--   Nameplates/Arrow.tga target arrow pointing right (mirrored for the left)
--   Nameplates/Stripes.tga diagonal stripes for the focus highlight (tiles seamlessly)
local SAMPLES = 8
local ROOT = "ModeUI/Media/Textures/"

-- Shape tests take a point in pixel units and return coverage 0-1.
local function RoundedRect(width, height, radius)
    return function(x, y)
        local cx = math.max(radius, math.min(width - radius, x))
        local cy = math.max(radius, math.min(height - radius, y))
        local dx, dy = x - cx, y - cy
        return dx * dx + dy * dy <= radius * radius and 1 or 0
    end
end

-- A soft falloff around a hollow core: alpha fades from 1 at the rounded
-- core's edge to 0 over `blur` pixels (smoothstep). The core's whole square is
-- empty (exactly the sliced center), so the glow never shows through a
-- see-through plate background.
local function Glow(size, inset, radius, blur)
    return function(x, y)
        if x >= inset and x <= size - inset and y >= inset and y <= size - inset then return 0 end
        local low, high = inset + radius, size - inset - radius
        local cx, cy = math.max(low, math.min(high, x)), math.max(low, math.min(high, y))
        local distance = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2) - radius
        if distance <= 0 then return 1 end
        local t = math.max(0, 1 - distance / blur)
        return t * t * (3 - 2 * t)
    end
end

-- Diagonal stripes, `width` pixels wide every `period` pixels; the period
-- divides the tile so it repeats without a seam.
local function Stripes(period, width)
    return function(x, y) return ((x + y) % period) < width and 1 or 0 end
end

local function Triangle(ax, ay, bx, by, cx, cy)
    local function Side(px, py, x1, y1, x2, y2) return (px - x2) * (y1 - y2) - (x1 - x2) * (py - y2) end
    return function(x, y)
        local d1, d2, d3 = Side(x, y, ax, ay, bx, by), Side(x, y, bx, by, cx, cy), Side(x, y, cx, cy, ax, ay)
        local negative = d1 < 0 or d2 < 0 or d3 < 0
        local positive = d1 > 0 or d2 > 0 or d3 > 0
        return (negative and positive) and 0 or 1
    end
end

-- A stroked polyline with round joins and caps, `thickness` pixels wide.
local function Stroke(points, thickness)
    local half = thickness / 2
    local function Distance(px, py, ax, ay, bx, by)
        local vx, vy = bx - ax, by - ay
        local t = math.max(0, math.min(1, ((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy)))
        local dx, dy = px - (ax + t * vx), py - (ay + t * vy)
        return math.sqrt(dx * dx + dy * dy)
    end
    return function(x, y)
        for i = 1, #points - 1 do
            local a, b = points[i], points[i + 1]
            if Distance(x, y, a[1], a[2], b[1], b[2]) <= half then return 1 end
        end
        return 0
    end
end

-- { path, width, height, shape, supersample }
local TEXTURES = {
    { "Mode/Flat.tga", 16, 16, RoundedRect(16, 16, 4), true },
    { "Mode/Card.tga", 16, 16, RoundedRect(16, 16, 6), true },
    { "Mode/Circle.tga", 16, 16, RoundedRect(16, 16, 8), true },
    { "Mode/Switch.tga", 32, 16, RoundedRect(32, 16, 8), true },
    { "Mode/Track.tga", 8, 4, RoundedRect(8, 4, 2), true },
    { "Mode/Chevron.tga", 16, 16, Stroke({ { 4.5, 6 }, { 8, 9.5 }, { 11.5, 6 } }, 1.6), true },
    { "Nameplates/Rim.tga", 16, 16, RoundedRect(16, 16, 3), true },
    { "Nameplates/Gap.tga", 16, 16, RoundedRect(16, 16, 2), true },
    { "Nameplates/Glow.tga", 32, 32, Glow(32, 12, 2, 11), false },
    { "Nameplates/Arrow.tga", 16, 16, Triangle(3, 2, 14, 8, 3, 14), true },
    { "Nameplates/Stripes.tga", 16, 16, Stripes(8, 3), true },
}

local function Coverage(shape, px, py, supersample)
    if not supersample then return shape(px + 0.5, py + 0.5) end
    local hits = 0
    for sy = 0, SAMPLES - 1 do
        for sx = 0, SAMPLES - 1 do
            hits = hits + shape(px + (sx + 0.5) / SAMPLES, py + (sy + 0.5) / SAMPLES)
        end
    end
    return hits / (SAMPLES * SAMPLES)
end

local function U16(value) return string.char(value % 256, math.floor(value / 256) % 256) end

-- Uncompressed 32-bit TGA, top-left origin, BGRA pixels.
local function WriteTGA(path, width, height, shape, supersample)
    local parts = { string.char(0, 0, 2, 0, 0, 0, 0, 0), U16(0), U16(0), U16(width), U16(height), string.char(32, 0x28) }
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local alpha = math.floor(Coverage(shape, x, y, supersample) * 255 + 0.5)
            parts[#parts + 1] = string.char(255, 255, 255, alpha)
        end
    end
    local file = assert(io.open(path, "wb"))
    file:write(table.concat(parts))
    file:close()
end

for _, texture in ipairs(TEXTURES) do
    WriteTGA(ROOT .. texture[1], texture[2], texture[3], texture[4], texture[5])
    print("wrote " .. ROOT .. texture[1])
end
