-- Builds ModeUI's procedural shape textures: white with anti-aliased alpha,
-- tinted in game. Run from the repository root with any Lua 5.1+:
--   lua tools/build_shape_textures.lua
--
--   Mode/Flat.tga        ModeFlat: soft rounded fill for settings controls (radius 4, sliced at 5)
--   Mode/Chevron.tga     ModeChevron: small down chevron for dropdowns
--   Nameplates/Glow.tga  soft target glow around a plate, hollow inside (sliced at 12)
--   Nameplates/AuraGlow.tga small glow around an aura icon, hollow inside (sliced at 6)
--   Nameplates/Arrow.tga target arrow pointing right (mirrored for the left)
--   Nameplates/Stripes.tga diagonal stripes for the focus highlight (tiles seamlessly)
--   Mode/SlateHatch.tga  ModeSlateHatch: 4x4 tile, gray 80% with a 1px full-white diagonal; tinted
--                        Mode Slate / 0.8, so the base is Mode Slate and the lines a little lighter
--   UnitFrames/Rested.tga  UnitFrameRested: a "Zz" in square strokes, for the rested badge
--   UnitFrames/Combat.tga  UnitFrameCombat: crossed swords with guards, for the combat badge
--   DamageMeters/Reset.tga  a circular arrow (Reset All Data)
--   DamageMeters/Lock.tga   a closed padlock (window locked)
--   DamageMeters/Unlock.tga an open padlock (window unlocked)
--   DamageMeters/Grip.tga   three diagonal lines in the bottom-right corner (resize)
--   Mode/Close.tga       ModeClose: a thin cross for close buttons
--   Chat/Menu.tga        ChatMenu: a speech bubble outline, the chat menu button's glyph
--   Chat/Channels.tga    ChatChannels: a "#", the chat channels button's glyph
--   Chat/Friends.tga     ChatFriends: a person's head and shoulders, the friends button's glyph
--   Mode/Minimize.tga    ModeMinimize: an arrow into the bottom-left corner (shrink a window)
--   Mode/Maximize.tga    ModeMaximize: an arrow out to the top-right corner (expand a window)
--   Mode/Sheen.tga       ModeSheen: 64x16, a soft diagonal band of light, brighter at the top,
--                        laid over glass tabs (ADD) for a glassy glint
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

-- Strokes: covered within width / 2 of any segment { x1, y1, x2, y2 }, with
-- square ends (the segments are extended by half the width).
local function Strokes(segments, width)
    local half = width / 2
    return function(x, y)
        for _, s in ipairs(segments) do
            local dx, dy = s[3] - s[1], s[4] - s[2]
            local length = math.sqrt(dx * dx + dy * dy)
            local ux, uy = dx / length, dy / length
            local along = (x - s[1]) * ux + (y - s[2]) * uy
            local across = math.abs((x - s[1]) * -uy + (y - s[2]) * ux)
            if along >= -half and along <= length + half and across <= half then return 1 end
        end
        return 0
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


-- Any of several shapes.
local function Union(...)
    local shapes = { ... }
    return function(x, y)
        for _, shape in ipairs(shapes) do if shape(x, y) > 0 then return 1 end end
        return 0
    end
end

-- Points along a circle's arc, from `from` to `to` degrees (0 is right,
-- 90 is down in texture space).
local function Arc(cx, cy, radius, from, to, steps)
    local points = {}
    for i = 0, steps do
        local a = math.rad(from + (to - from) * i / steps)
        points[#points + 1] = { cx + radius * math.cos(a), cy + radius * math.sin(a) }
    end
    return points
end

-- Damage meter header glyphs: a circular arrow, padlocks and a resize grip.
local function Reset()
    -- The arc leaves a gap at the top; the arrowhead sits on its right end,
    -- pointing along the arc into the gap.
    local start = -40
    local arc = Arc(8, 8.5, 4.6, start, 250, 24)
    local a = math.rad(start)
    local ex, ey = arc[1][1], arc[1][2]
    local nx, ny, dx, dy = math.cos(a), math.sin(a), math.sin(a), -math.cos(a)
    return Union(Stroke(arc, 1.6), Triangle(ex + nx * 2.6, ey + ny * 2.6, ex - nx * 2.6, ey - ny * 2.6, ex + dx * 3, ey + dy * 3))
end
local function Padlock(open)
    local body = function(x, y) return (x >= 3.5 and x <= 12.5 and y >= 7.5 and y <= 14) and RoundedRect(9, 6.5, 1.5)(x - 3.5, y - 7.5) or 0 end
    local shackle = open and { { 10.5, 7.5 } } or { { 5.5, 7.5 } }
    local arc = Arc(8, 5, 2.5, 180, 360, 12)
    if open then
        shackle = { { 10.5, 7.5 }, { 10.5, 4.2 } }
        for i = #arc, 1, -1 do shackle[#shackle + 1] = { arc[i][1], arc[i][2] - 0.8 } end
        shackle[#shackle + 1] = { 5.5, 5.4 }
    else
        shackle = { { 5.5, 7.5 }, { 5.5, 5 } }
        for _, p in ipairs(arc) do shackle[#shackle + 1] = p end
        shackle[#shackle + 1] = { 10.5, 7.5 }
    end
    return Union(body, Stroke(shackle, 1.6))
end
local function Grip()
    return Union(Stroke({ { 14.5, 5.5 }, { 5.5, 14.5 } }, 1.3), Stroke({ { 14.5, 9.5 }, { 9.5, 14.5 } }, 1.3),
        Stroke({ { 14.5, 13.5 }, { 13.5, 14.5 } }, 1.3))
end

-- { path, width, height, shape, supersample[, color] }
local TEXTURES = {
    { "Mode/Flat.tga", 16, 16, RoundedRect(16, 16, 4), true },
    { "Mode/Chevron.tga", 16, 16, Stroke({ { 4.5, 6 }, { 8, 9.5 }, { 11.5, 6 } }, 1.6), true },
    { "Nameplates/Glow.tga", 32, 32, Glow(32, 12, 2, 11), false },
    { "Nameplates/AuraGlow.tga", 24, 24, Glow(24, 6, 2, 5), false },
    { "Nameplates/Arrow.tga", 16, 16, Triangle(3, 2, 14, 8, 3, 14), true },
    { "Nameplates/Stripes.tga", 16, 16, Stripes(8, 3), true },
    { "UnitFrames/Rested.tga", 32, 32, Strokes({ { 5, 8, 16, 8 }, { 16, 8, 5, 21 }, { 5, 21, 16, 21 },
        { 19, 15, 27, 15 }, { 27, 15, 19, 24 }, { 19, 24, 27, 24 } }, 3), true },
    { "UnitFrames/Combat.tga", 32, 32, Strokes({ { 7, 7, 25, 25 }, { 25, 7, 7, 25 }, { 4, 22, 10, 28 }, { 22, 28, 28, 22 } }, 3), true },
    { "Mode/Close.tga", 16, 16, Strokes({ { 4.5, 4.5, 11.5, 11.5 }, { 11.5, 4.5, 4.5, 11.5 } }, 1.4), true },
    { "Chat/Menu.tga", 16, 16, Stroke({ { 2.5, 2.5 }, { 13.5, 2.5 }, { 13.5, 10.5 }, { 7.5, 10.5 }, { 4.5, 13.5 },
        { 4.5, 10.5 }, { 2.5, 10.5 }, { 2.5, 2.5 } }, 1), true },
    { "Chat/Channels.tga", 16, 16, Strokes({ { 5.5, 3.5, 5.5, 12.5 }, { 10.5, 3.5, 10.5, 12.5 },
        { 3.5, 5.5, 12.5, 5.5 }, { 3.5, 10.5, 12.5, 10.5 } }, 1), true },
    { "Mode/SlateHatch.tga", 4, 4, function() return 1 end, false, function(x, y)
        local v = (x + y) % 4 == 0 and 1 or 0.8
        return v, v, v
    end },
    { "DamageMeters/Reset.tga", 16, 16, Reset(), true },
    { "DamageMeters/Lock.tga", 16, 16, Padlock(false), true },
    { "DamageMeters/Unlock.tga", 16, 16, Padlock(true), true },
    { "DamageMeters/Grip.tga", 16, 16, Grip(), true },
    { "Chat/Friends.tga", 16, 16, Union(Stroke(Arc(8, 5.5, 2.75, 0, 360, 32), 1.1), Stroke(Arc(8, 15.5, 5.5, 200, 340, 20), 1.1)), true },
    { "Mode/Minimize.tga", 16, 16, Strokes({ { 11.5, 4.5, 5, 11 }, { 4.5, 6.5, 4.5, 11.5 }, { 4.5, 11.5, 9.5, 11.5 } }, 1.4), true },
    { "Mode/Maximize.tga", 16, 16, Strokes({ { 4.5, 11.5, 11, 5 }, { 6.5, 4.5, 11.5, 4.5 }, { 11.5, 4.5, 11.5, 9.5 } }, 1.4), true },
    { "Mode/Sheen.tga", 64, 16, function(x, y)
        -- A band leaning right, 10 px wide, feathered (smoothstep), fading toward the bottom.
        local distance = math.abs((x - 18) - (16 - y) * 0.9)
        local t = math.max(0, math.min(1, 1 - distance / 10))
        local band = t * t * (3 - 2 * t)
        return band * (1 - 0.6 * y / 16)
    end, false },
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
local function WriteTGA(path, width, height, shape, supersample, color)
    local parts = { string.char(0, 0, 2, 0, 0, 0, 0, 0), U16(0), U16(0), U16(width), U16(height), string.char(32, 0x28) }
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local alpha = math.floor(Coverage(shape, x, y, supersample) * 255 + 0.5)
            local r, g, b = 1, 1, 1
            if color then r, g, b = color(x, y) end
            local function Byte(c) return math.floor(math.max(0, math.min(1, c)) * 255 + 0.5) end
            parts[#parts + 1] = string.char(Byte(b), Byte(g), Byte(r), alpha)
        end
    end
    local file = assert(io.open(path, "wb"))
    file:write(table.concat(parts))
    file:close()
end

for _, texture in ipairs(TEXTURES) do
    WriteTGA(ROOT .. texture[1], texture[2], texture[3], texture[4], texture[5], texture[6])
    print("wrote " .. ROOT .. texture[1])
end
