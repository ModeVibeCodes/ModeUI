-- Builds the Mode design language's textures (docs/DESIGN_LANGUAGE.md). Every
-- file is a power-of-two 32-bit TGA. Run from the repository root with Lua 5.3+:
--   lua tools/build_mode_assets.lua
-- (on the owner's machine: the lua-language-server binary bundled with the VS Code
-- Lua extension runs it). Shared/Style/Assets.lua lists how each file is used.
--
-- Borders/  white art tinted in game. Outer radius 4 ("Round 4"), every inner
--           edge steps in by the rim's own thickness, so each ring is even and
--           the rim covers its own inner corner: no masks.
--   Rim1, Rim2       Mode Empty: a flat 1px / 2px rim (sliced at 5)
--   Edge1, Edge2     Mode Light, Edge-lit: the rim's top edge only, laid over the rim
--   Sheen1           Mode Light, Sheen: a soft band of light through the middle of a 1px rim
--   Shadow           the 1px dark ring one size up (radius 5, sliced at 6)
--   Gap              the 1px black gap inside a window rim (radius 3, sliced at 4)
--   Soft             a soft drop shadow under frames and windows (sliced at 12)
--   RingSheen        a disc with a light band, laid over a portrait's metal disc
-- Bars/     luminance art multiplied by the bar color (SetVertexColor), and white
--           "Lift" overlays (alpha only) that add light the multiply can't.
--   Solid (8x8), MatteBase/MatteLift, BG, ButtonBase/ButtonLift, GlassBase/GlassLift,
--   CastBase/CastLift, GradientLift, Panel (+PanelLift), Title, and the single
--   baked files Gradient, Button, Glass, Cast that other addons get through
--   LibSharedMedia (and Matte). Shield: a 32x32 tile, a 1px 45-degree line every 8 texels.
--   CometHead, CometTrail, LineGlow: the Comet spark and the shield finish line.
-- Controls/ Knob (slide toggle block, radius 2), Blade (slider thumb).
-- Icons/    the module icons for the settings sidebar and icon rail (tools/mode_icons.lua).
-- Masks/    Circle: a filled disc (portrait metal disc and the portrait's own crop).
local here = (debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "")
local T = dofile(here .. "mode_tga.lua")
local ROOT = "ModeUI/Media/Textures/Mode/"

local function Folder(path)
    local dir = (ROOT .. path):match("^(.*)/[^/]+$")
    if package.config:sub(1, 1) == "\\" then os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" 2>nul')
    else os.execute("mkdir -p '" .. dir .. "'") end
end
local written = 0
local function Save(path, w, h, pixel)
    Folder(path)
    T.Write(ROOT .. path .. ".tga", w, h, pixel)
    written = written + 1
    print("wrote " .. ROOT .. path .. ".tga")
end
-- White with alpha from a shape's coverage (times an optional alpha function).
local function Shape(path, w, h, shape, alpha)
    Save(path, w, h, function(x, y)
        local a = T.Coverage(shape, x, y)
        if alpha and a > 0 then a = a * alpha(x + 0.5, y + 0.5) end
        return 1, 1, 1, a
    end)
end
-- Gray luminance (opaque), multiplied by the vertex color in game.
local function Luma(path, w, h, value)
    Save(path, w, h, function(x, y) local v = value(x, y); return v, v, v, 1 end)
end
-- White, alpha only.
local function Lift(path, w, h, alpha)
    Save(path, w, h, function(x, y) return 1, 1, 1, alpha(x, y) end)
end

-- Borders ------------------------------------------------------------------
local S = 16
local rim1, rim2 = T.Ring(S, S, 4, 1), T.Ring(S, S, 4, 2)
Shape("Borders/Rim1", S, S, rim1)
Shape("Borders/Rim2", S, S, rim2)
-- Edge-lit: the outermost row of the rim where it faces up (the top edge and
-- the upper part of the top corners).
local function TopFacing(x, y)
    if y < 1 then return 1 end
    if y >= 4 then return 0 end
    local cx = x < 8 and 4 or S - 4
    local dx, dy = x - cx, y - 4
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 3 then return 0 end
    return (-dy / d) > 0.6 and 1 or 0
end
Shape("Borders/Edge1", S, S, function(x, y) return rim1(x, y) * TopFacing(x, y) end)
Shape("Borders/Edge2", S, S, function(x, y) return rim2(x, y) * TopFacing(x, y) end)
-- Sheen: strongest through the middle rows, fading to nothing at the top and bottom.
Shape("Borders/Sheen1", S, S, rim1, function(_, y) return T.Smooth(1 - math.abs(y - S / 2) / (S / 2)) end)
Shape("Borders/Shadow", S, S, T.Ring(S, S, 5, 1))
Shape("Borders/Gap", S, S, T.Ring(S, S, 3, 1))
-- Soft shadow: a rounded box (radius 6) whose alpha falls off over 5px outside it.
do
    local W, inner = 32, 6
    Save("Borders/Soft", W, W, function(x, y)
        local px, py = x + 0.5, y + 0.5
        local cx = math.max(inner + 6, math.min(W - inner - 6, px))
        local cy = math.max(inner + 6, math.min(W - inner - 6, py))
        local d = math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2) - 6
        local a = d <= 0 and 1 or (1 - T.Smooth(d / 5))
        return 0, 0, 0, a
    end)
end
-- Portrait ring light: a disc with a soft horizontal band through its middle.
Shape("Borders/RingSheen", 128, 128, T.Circle(64, 64, 64), function(_, y) return T.Smooth(1 - math.abs(y - 64) / 64) end)

-- Bars ---------------------------------------------------------------------
local BW, BH = 256, 32
local function Profile(points)  -- { {t, v}, ... } over the bar height, t in 0-1
    return function(_, y)
        local t = (y + 0.5) / BH
        for i = 1, #points - 1 do
            local a, b = points[i], points[i + 1]
            if t <= b[1] then return T.Lerp(a[2], b[2], (t - a[1]) / (b[1] - a[1])) end
        end
        return points[#points][2]
    end
end
Luma("Bars/Solid", 8, 8, function() return 1 end)
local matte = Profile({ { 0, 1 }, { 1, 0.78 } })
local bg = Profile({ { 0, 0.66 }, { 0.38, 1 }, { 1, 1 } })
Luma("Bars/MatteBase", BW, BH, matte)
Luma("Bars/BG", BW, BH, bg)
-- Matte's sheen: a faint 1px top line, then a soft band of light that fades
-- out by the middle; gentle, so the face still reads as matte.
local matteLift = function(x, y)
    if y == 0 then return 0.16 end
    return Profile({ { 0, 0.11 }, { 0.2, 0.08 }, { 0.5, 0.025 }, { 0.62, 0 }, { 1, 0 } })(x, y)
end
Lift("Bars/MatteLift", BW, BH, matteLift)
local gradientLift = Profile({ { 0, 0.20 }, { 0.5, 0 }, { 1, 0 } })
local buttonBase = function(x, y) if y == BH - 1 then return 0.55 end return Profile({ { 0, 1 }, { 0.55, 1 }, { 1, 0.86 } })(x, y) end
local buttonLift = function(x, y) if y == 0 then return 0.30 end return Profile({ { 0, 0.10 }, { 0.55, 0 }, { 1, 0 } })(x, y) end
local glassBase = Profile({ { 0, 1 }, { 0.56, 0.96 }, { 1, 0.84 } })
local glassLift = Profile({ { 0, 0.20 }, { 0.44, 0.11 }, { 0.5, 0 }, { 1, 0 } })
local castBase = Profile({ { 0, 1 }, { 0.58, 1 }, { 1, 0.74 } })
local castLift = Profile({ { 0, 0.10 }, { 0.20, 0.34 }, { 0.42, 0.10 }, { 0.58, 0 }, { 1, 0 } })
Lift("Bars/GradientLift", BW, BH, gradientLift)
Luma("Bars/ButtonBase", BW, BH, buttonBase); Lift("Bars/ButtonLift", BW, BH, buttonLift)
Luma("Bars/GlassBase", BW, BH, glassBase); Lift("Bars/GlassLift", BW, BH, glassLift)
Luma("Bars/CastBase", BW, BH, castBase); Lift("Bars/CastLift", BW, BH, castLift)
-- Single-file versions for other addons (LibSharedMedia): the lift baked over a
-- base that leaves 10% headroom, so the light still reads after the multiply.
local function Baked(path, base, lift)
    Luma(path, BW, BH, function(x, y)
        local a = lift(x, y)
        return math.min(1, (base(x, y) * 0.9) * (1 - a) + a)
    end)
end
Baked("Bars/Matte", matte, matteLift)
Baked("Bars/Gradient", function() return 1 end, gradientLift)
Baked("Bars/Button", buttonBase, buttonLift)
Baked("Bars/Glass", glassBase, glassLift)
Baked("Bars/Cast", castBase, castLift)
-- Panel (brushed): faint horizontal streaks, one value per row plus fine grain;
-- tiles in both directions, drawn 1:1.
do
    local rnd = T.Noise(7)
    local rows = {}
    for y = 0, 63 do rows[y] = rnd() end
    local grain = T.Noise(19)
    Luma("Bars/Panel", 256, 64, function(_, y) return 0.95 + (rows[y] - 0.5) * 0.08 + (grain() - 0.5) * 0.03 end)
    Lift("Bars/PanelLift", BW, BH, Profile({ { 0, 0.08 }, { 0.6, 0 }, { 1, 0 } }))
end
-- Title (grain): even fine noise, tiles both ways, drawn 1:1.
do
    local rnd = T.Noise(13)
    Luma("Bars/Title", 128, 128, function() return 0.96 + (rnd() - 0.5) * 0.08 end)
end
-- Shield (Hairline): a 1px line at 45 degrees every 8 texels; perpendicular spacing about 5.7px at 1:1.
Shape("Bars/Shield", 32, 32, function(x, y)
    local d = (x + y) % 8
    return (d < 1.414) and 1 or 0
end)
-- Comet spark: an oval head with a soft glow (drawn 10px wide over the bar), and
-- its trail (drawn about 21px long behind the head, tinted from the bar color).
Save("Bars/CometHead", 32, 64, function(x, y)
    local nx, ny = (x + 0.5 - 16) / 6.4, (y + 0.5 - 32) / 32
    local r = math.sqrt(nx * nx + ny * ny)
    local core = r <= 0.78 and 1 or r <= 1 and T.Lerp(1, 0, (r - 0.78) / 0.22) or 0
    local gx = math.abs(x + 0.5 - 16) / 16
    local glow = (1 - T.Smooth(gx)) * (1 - T.Smooth(math.abs(ny))) * 0.35
    return 1, 1, 1, math.max(core, glow)
end)
Lift("Bars/CometTrail", 64, 16, function(x) return 0.7 * ((x + 0.5) / 64) end)
Lift("Bars/LineGlow", 16, 64, function(x) return 0.8 * (1 - T.Smooth(math.abs(x + 0.5 - 8) / 8)) end)

-- Icons --------------------------------------------------------------------
local ICONS = dofile(here .. "mode_icons.lua")
for _, name in ipairs(ICONS.ORDER) do Shape("Icons/" .. name, 32, 32, ICONS[name]) end

-- Controls -----------------------------------------------------------------
Shape("Controls/Knob", 8, 8, T.RoundedRect(0, 0, 8, 8, 2))
Luma("Controls/Blade", 8, 16, function(_, y) return T.Lerp(1, 0.6, (y + 0.5) / 16) end)

-- Masks --------------------------------------------------------------------
Shape("Masks/Circle", 128, 128, T.Circle(64, 64, 64))

print(written .. " Mode textures written")
