-- Small helpers for writing ModeUI's procedural textures: 32-bit TGA output,
-- supersampled shape coverage and the shape tests the Mode assets share.
local T = {}
T.SAMPLES = 8

local function U16(value) return string.char(value % 256, math.floor(value / 256) % 256) end
local function Byte(c) return math.floor(math.max(0, math.min(1, c)) * 255 + 0.5) end
T.Byte = Byte

-- Writes an uncompressed 32-bit TGA (top-left origin, BGRA). `pixel(x, y)` gets
-- the pixel's top-left corner and returns r, g, b, a in 0-1.
function T.Write(path, width, height, pixel)
    assert(width & (width - 1) == 0 and height & (height - 1) == 0, path .. ": sizes must be powers of two")
    local parts = { string.char(0, 0, 2, 0, 0, 0, 0, 0), U16(0), U16(0), U16(width), U16(height), string.char(32, 0x28) }
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local r, g, b, a = pixel(x, y)
            parts[#parts + 1] = string.char(Byte(b), Byte(g), Byte(r), Byte(a))
        end
    end
    local file = assert(io.open(path, "wb"))
    file:write(table.concat(parts))
    file:close()
end

-- Average of a shape test (point -> 0..1) over a pixel, SAMPLES x SAMPLES.
function T.Coverage(shape, px, py)
    local n, hits = T.SAMPLES, 0
    for sy = 0, n - 1 do
        for sx = 0, n - 1 do hits = hits + shape(px + (sx + 0.5) / n, py + (sy + 0.5) / n) end
    end
    return hits / (n * n)
end

-- Inside a rounded rectangle from (x0, y0) to (x1, y1) with corner radius r.
function T.RoundedRect(x0, y0, x1, y1, r)
    return function(x, y)
        if x < x0 or x > x1 or y < y0 or y > y1 then return 0 end
        if r <= 0 then return 1 end
        local cx = math.max(x0 + r, math.min(x1 - r, x))
        local cy = math.max(y0 + r, math.min(y1 - r, y))
        local dx, dy = x - cx, y - cy
        return dx * dx + dy * dy <= r * r and 1 or 0
    end
end

-- The rim of a rounded box: inside the outer box (radius r) and outside the box
-- inset by t (radius r - t), so the ring is t wide all round.
function T.Ring(w, h, r, t)
    local outer = T.RoundedRect(0, 0, w, h, r)
    local inner = T.RoundedRect(t, t, w - t, h - t, math.max(0, r - t))
    return function(x, y) return outer(x, y) * (1 - inner(x, y)) end
end

-- Inside a circle.
function T.Circle(cx, cy, radius)
    return function(x, y)
        local dx, dy = x - cx, y - cy
        return dx * dx + dy * dy <= radius * radius and 1 or 0
    end
end

function T.Smooth(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end

function T.Lerp(a, b, t) return a + (b - a) * t end

-- A repeatable pseudo-random sequence (no math.random state), for grain.
function T.Noise(seed)
    local state = seed
    return function()
        state = (state * 16807) % 2147483647
        return state / 2147483647
    end
end

return T
