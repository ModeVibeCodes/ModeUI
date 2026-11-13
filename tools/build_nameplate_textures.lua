-- Builds the nameplate rim textures: white, anti-aliased rounded rectangles
-- (alpha = coverage), tinted in game. Small corner radii so a plate's health
-- and cast boxes are rounded alike even when only 7-10 UI units tall.
-- Run from the repository root with any Lua 5.1+:
--   lua tools/build_nameplate_textures.lua
local SIZE, SAMPLES = 16, 8
local DEST = "ModeUI/Media/Textures/Nameplates/"

-- Each texture: corner radius in pixels. Media slices them one pixel past the
-- radius (Rim 3 -> slice 4, Gap 2 -> slice 3); the gap is drawn 1px inside the rim.
local TEXTURES = { Rim = 3, Gap = 2 }

local function Inside(x, y, radius)
    local cx = math.max(radius, math.min(SIZE - radius, x))
    local cy = math.max(radius, math.min(SIZE - radius, y))
    local dx, dy = x - cx, y - cy
    return dx * dx + dy * dy <= radius * radius
end

local function Coverage(px, py, radius)
    local hits = 0
    for sy = 0, SAMPLES - 1 do
        for sx = 0, SAMPLES - 1 do
            if Inside(px + (sx + 0.5) / SAMPLES, py + (sy + 0.5) / SAMPLES, radius) then hits = hits + 1 end
        end
    end
    return hits / (SAMPLES * SAMPLES)
end

local function U16(value) return string.char(value % 256, math.floor(value / 256) % 256) end

-- Uncompressed 32-bit TGA, top-left origin, BGRA pixels.
local function WriteTGA(path, radius)
    local parts = { string.char(0, 0, 2, 0, 0, 0, 0, 0), U16(0), U16(0), U16(SIZE), U16(SIZE), string.char(32, 0x28) }
    for y = 0, SIZE - 1 do
        for x = 0, SIZE - 1 do
            local alpha = math.floor(Coverage(x, y, radius) * 255 + 0.5)
            parts[#parts + 1] = string.char(255, 255, 255, alpha)
        end
    end
    local file = assert(io.open(path, "wb"))
    file:write(table.concat(parts))
    file:close()
end

for name, radius in pairs(TEXTURES) do
    WriteTGA(DEST .. name .. ".tga", radius)
    print("wrote " .. DEST .. name .. ".tga (radius " .. radius .. ")")
end
