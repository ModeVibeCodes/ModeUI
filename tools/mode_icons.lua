-- The Mode module icons (docs/DESIGN_LANGUAGE.md, "Settings window"): 32x32
-- white line glyphs drawn on a 32-unit grid with a 2.6-unit stroke (about one
-- pixel at the 13-15px the sidebar and icon rail draw them), tinted in game.
-- Each entry is a shape test (x, y) -> 0 or 1 for T.Coverage.
local I = {}
local W = 2.6

local function Segment(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local length2 = dx * dx + dy * dy
    return function(x, y)
        local t = length2 > 0 and math.max(0, math.min(1, ((x - ax) * dx + (y - ay) * dy) / length2)) or 0
        local ex, ey = x - (ax + t * dx), y - (ay + t * dy)
        return ex * ex + ey * ey <= (W / 2) ^ 2
    end
end
local function Line(...)
    local points, parts = { ... }, {}
    for i = 1, #points - 3, 2 do parts[#parts + 1] = Segment(points[i], points[i + 1], points[i + 2], points[i + 3]) end
    return function(x, y)
        for _, part in ipairs(parts) do if part(x, y) then return true end end
        return false
    end
end
-- Signed distance to a rounded rectangle.
local function RoundRect(x0, y0, x1, y1, r)
    local cx, cy, hx, hy = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    return function(x, y)
        local qx, qy = math.abs(x - cx) - hx, math.abs(y - cy) - hy
        local outside = math.sqrt(math.max(qx, 0) ^ 2 + math.max(qy, 0) ^ 2)
        return outside + math.min(math.max(qx, qy), 0) - r
    end
end
local function Box(x0, y0, x1, y1, r)
    local d = RoundRect(x0, y0, x1, y1, r or 2)
    return function(x, y) return math.abs(d(x, y)) <= W / 2 end
end
local function Block(x0, y0, x1, y1, r)
    local d = RoundRect(x0, y0, x1, y1, r or 1)
    return function(x, y) return d(x, y) <= 0 end
end
-- A circle's outline; keep(x, y) limits it to an arc.
local function Ring(cx, cy, r, keep)
    return function(x, y)
        if keep and not keep(x, y) then return false end
        return math.abs(math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2) - r) <= W / 2
    end
end
local function Dot(cx, cy, r)
    return function(x, y) return (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r end
end
local function Any(...)
    local parts = { ... }
    return function(x, y)
        for _, part in ipairs(parts) do if part(x, y) then return 1 end end
        return 0
    end
end

I.Home = Any(Line(4, 15, 16, 5, 28, 15), Line(8, 12, 8, 27, 24, 27, 24, 12), Line(13, 27, 13, 20, 19, 20, 19, 27))
I.UnitFrames = Any(Ring(8.5, 16, 5), Box(16.5, 11, 29, 21))
I.GroupFrames = Any(Box(4, 4, 28, 11), Box(4, 13, 28, 20), Box(4, 22, 28, 29))
I.Nameplates = Any(Line(10, 8, 22, 8), Box(4, 13, 28, 22), Block(7, 16, 18, 19, 0.5))
I.ActionBars = Any(Box(4, 4, 14, 14), Box(18, 4, 28, 14), Box(4, 18, 14, 28), Box(18, 18, 28, 28))
I.DamageMeters = Any(Block(5, 20, 10, 28), Block(13.5, 13, 18.5, 28), Block(22, 6, 27, 28), Line(3, 29.5, 29, 29.5))
I.Chat = Any(Box(4, 5, 28, 21, 3), Line(10, 21, 8, 27, 15, 21))
I.Windows = Any(Box(4, 5, 28, 27), Line(4, 11, 28, 11))
I.Tooltip = Any(Box(4, 4, 28, 21), Line(9, 10, 23, 10), Line(9, 15, 19, 15), Line(13, 21, 16, 26, 19, 21))
I.Bags = Any(Box(6, 11, 26, 28, 3), Ring(16, 11, 5, function(_, y) return y <= 11 end))
I.Minimap = Any(Ring(16, 16, 11), Dot(16, 16, 2.6), Line(16, 3, 16, 6))
I.Profiles = Any(Ring(16, 10, 5), Ring(16, 30, 10, function(_, y) return y <= 27 end))
I.Optimizations = Any(Line(18, 3, 8, 18, 16, 18, 13, 29, 24, 13, 16, 13, 18, 3))
I.ClassColors = Any(Ring(11, 11.5, 5.5), Ring(21, 11.5, 5.5), Ring(16, 20.5, 5.5))
I.Cooldowns = Any(Ring(16, 16, 11), Line(16, 16, 16, 9), Line(16, 16, 21, 19))
I.Back = Any(Line(19, 7, 10, 16, 19, 25))

-- Glyphs for controls and marks (not module icons).
-- Clean Up: a broom, its handle from the top right to the binding, the head
-- fanning down left with one bristle line.
I.CleanUp = Any(Line(28, 3, 19.5, 12.5), Line(14, 11, 22, 19), Line(14, 11, 5, 22, 4, 28, 10, 27, 22, 19), Line(15, 18, 8.5, 25))
-- Quest: a disc with the "!" cut out (a quest item's mark, tinted the quest tone).
do
    local disc, dot = Dot(16, 16, 15), Dot(16, 24, 2.6)
    I.Quest = function(x, y)
        local bang = (x >= 13.5 and x <= 18.5 and y >= 6 and y <= 19) or dot(x, y)
        return (disc(x, y) and not bang) and 1 or 0
    end
end
I.GLYPHS = { "CleanUp", "Quest" }

-- Menu order, for the build and the test.
I.ORDER = { "Home", "UnitFrames", "GroupFrames", "Nameplates", "ActionBars", "DamageMeters", "Chat", "Windows",
    "Tooltip", "Bags", "Minimap", "Profiles", "Optimizations", "ClassColors", "Cooldowns", "Back" }

return I
