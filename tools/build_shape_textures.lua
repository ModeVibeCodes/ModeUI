-- Builds ModeUI's procedural shape textures: white with anti-aliased alpha,
-- tinted in game. Run from the repository root with any Lua 5.1+:
--   lua tools/build_shape_textures.lua
--
--   Mode/Flat.tga        ModeFlat: soft rounded fill for settings elements (radius 4, sliced at 5)
--   Nameplates/Rim.tga   plate and aura rims (radius 3, sliced at 4)
--   Nameplates/Gap.tga   the black gap inside a rim (radius 2, sliced at 3)
--   Nameplates/Glow.tga  soft target glow around a plate (sliced at 12)
--   Nameplates/Arrow.tga target arrow pointing right (mirrored for the left)
local SAMPLES = 8
local ROOT = "ModeUI/Media/Textures/"

-- Shape tests take a point in pixel units and return coverage 0-1.
local function RoundedRect(size, radius)
    return function(x, y)
        local cx = math.max(radius, math.min(size - radius, x))
        local cy = math.max(radius, math.min(size - radius, y))
        local dx, dy = x - cx, y - cy
        return dx * dx + dy * dy <= radius * radius and 1 or 0
    end
end

-- A rounded core with a soft falloff around it: alpha fades from 1 at the
-- core's edge to 0 over `blur` pixels (smoothstep).
local function Glow(size, inset, radius, blur)
    return function(x, y)
        local low, high = inset + radius, size - inset - radius
        local cx, cy = math.max(low, math.min(high, x)), math.max(low, math.min(high, y))
        local distance = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2) - radius
        if distance <= 0 then return 1 end
        local t = math.max(0, 1 - distance / blur)
        return t * t * (3 - 2 * t)
    end
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

local TEXTURES = {
    { "Mode/Flat.tga", 16, RoundedRect(16, 4), true },
    { "Nameplates/Rim.tga", 16, RoundedRect(16, 3), true },
    { "Nameplates/Gap.tga", 16, RoundedRect(16, 2), true },
    { "Nameplates/Glow.tga", 32, Glow(32, 12, 2, 11), false },
    { "Nameplates/Arrow.tga", 16, Triangle(3, 2, 14, 8, 3, 14), true },
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
local function WriteTGA(path, size, shape, supersample)
    local parts = { string.char(0, 0, 2, 0, 0, 0, 0, 0), U16(0), U16(0), U16(size), U16(size), string.char(32, 0x28) }
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local alpha = math.floor(Coverage(shape, x, y, supersample) * 255 + 0.5)
            parts[#parts + 1] = string.char(255, 255, 255, alpha)
        end
    end
    local file = assert(io.open(path, "wb"))
    file:write(table.concat(parts))
    file:close()
end

for _, texture in ipairs(TEXTURES) do
    WriteTGA(ROOT .. texture[1], texture[2], texture[3], texture[4])
    print("wrote " .. ROOT .. texture[1])
end
