-- Builds the Mode design language's textures (docs/DESIGN_LANGUAGE.md). Every
-- file is a power-of-two 32-bit TGA. Run from the repository root with Lua 5.3+:
--   lua tools/build_mode_assets.lua
-- (on the owner's machine: the lua-language-server binary bundled with the VS Code
-- Lua extension runs it). Shared/Style/Assets.lua lists how each file is used.
--
-- Borders/  white art tinted in game. Every ring Shared/Style/EdgeData.lua can
--           name (D.AllRings): <shape><depth><thickness>[<profile>], a ring of
--           that thickness whose outer corner is the shape's corner stepped in
--           by its depth, so each ring is even and the innermost covers its own
--           inner corner: no masks. A profile ring's alpha follows the lighting
--           down its height (the middle rows stretch over the border's height).
--   Soft             a soft drop shadow under frames and windows (sliced at 12)
--   Ring<profile>    the portrait ring's lighting (EdgeData D.RingProfiles): a
--                    disc whose alpha follows a style's lighting profile down
--                    its height, laid over the metal's base disc
-- Bars/     luminance art multiplied by the bar color (SetVertexColor), and white
--           "Lift" overlays (alpha only) that add light the multiply can't.
--   Solid (8x8); FGBase/FGLift (+ baked FG): Mode-FG, the dark glass fill of
--   every bar and surface; BG: Mode-BG, the lighter graphite empty part;
--   SurfaceLift: the large panels' soft sheen (Surface).
--   Shield: a 32x32 tile, a 1px 45-degree line every 8 texels.
--   CometHead, CometTrail, LineGlow: the Comet spark and the shield finish line.
--   (The Mode-Blizz textures and borders were retired on November 20, 2026;
--   archive/mode-blizz/ keeps them and the builder that drew them.)
-- Glows/   TextGlow: a soft capsule of light behind health numbers (stretched).
--          Prism: Mode-Obsidian's glow round a frame on mouseover and focus (sliced at 14).
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
local EDGE = dofile(here .. "../ModeUI/Shared/Style/EdgeData.lua")
-- The alpha of a lighting profile at t (0 at the ring's top, 1 at its bottom).
local function Profile(stops, t)
    for i = 1, #stops - 1 do
        local a, b = stops[i], stops[i + 1]
        if t <= b[1] then return T.Lerp(a[2], b[2], (t - a[1]) / math.max(1e-6, b[1] - a[1])) end
    end
    return stops[#stops][2]
end
local function EdgeShape(spec, w, h, inset, step)
    return T.RoundedRect(inset, inset, w - inset, h - inset, math.max(0, spec.radius - step))
end
local rings, keys = EDGE.AllRings(), {}
for key in pairs(rings) do keys[#keys + 1] = key end
table.sort(keys)
for _, key in ipairs(keys) do
    local ring = rings[key]
    local spec = EDGE.SHAPES[ring.shape]
    local w, h = spec.w, spec.h
    local outer = EdgeShape(spec, w, h, 0, ring.depth)
    local inner = EdgeShape(spec, w, h, ring.thick, ring.depth + ring.thick)
    local stops = ring.profile and EDGE.PROFILES[ring.profile]
    Shape("Borders/" .. key, w, h, function(x, y) return outer(x, y) * (1 - inner(x, y)) end,
        stops and function(_, y) return Profile(stops, y / h) end)
end
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
-- Portrait ring lighting: every style's lighting layers over a whole disc.
for _, profile in ipairs(EDGE.RingProfiles()) do
    local stops = EDGE.PROFILES[profile]
    Shape("Borders/Ring" .. profile, 128, 128, T.Circle(64, 64, 64), function(_, y) return Profile(stops, y / 128) end)
end

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
-- Single-file versions for other addons (LibSharedMedia): the lift baked over a
-- base that leaves 10% headroom, so the light still reads after the multiply.
local function Baked(path, base, lift)
    Luma(path, BW, BH, function(x, y)
        local a = lift(x, y)
        return math.min(1, (base(x, y) * 0.9) * (1 - a) + a)
    end)
end
-- Mode-FG (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme"): the dark glass
-- fill (a base 100% to 82% down, a faint 1px top line and a soft band of
-- light fading out by the middle) and Mode-BG, the lighter graphite empty
-- part (100% to 76% down, opaque; tinted Slate in game).
local fgBase = Profile({ { 0, 1 }, { 1, 0.82 } })
local fgLift = function(x, y)
    if y == 0 then return 0.12 end
    return Profile({ { 0, 0.07 }, { 0.25, 0.05 }, { 0.5, 0 }, { 1, 0 } })(x, y)
end
Luma("Bars/FGBase", BW, BH, fgBase)
Lift("Bars/FGLift", BW, BH, fgLift)
Baked("Bars/FG", fgBase, fgLift)
Luma("Bars/BG", BW, BH, Profile({ { 0, 1 }, { 1, 0.76 } }))
-- The large panels' sheen (the approved mock's: white 4.5% at the top, gone
-- 40% down), with no top line.
Lift("Bars/SurfaceLift", BW, BH, Profile({ { 0, 0.045 }, { 0.4, 0 }, { 1, 0 } }))
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

-- Glows --------------------------------------------------------------------
-- Text glow: a soft capsule, brightest along the middle 40% of its width and
-- fading round to nothing at every edge (no visible box); drawn stretched.
Lift("Glows/TextGlow", 128, 32, function(x, y)
    local tx = math.max(0, math.abs(x + 0.5 - 64) / 64 - 0.4) / 0.6
    local ty = math.abs(y + 0.5 - 16) / 16
    local r = math.min(1, math.sqrt(tx * tx + ty * ty))
    return 0.85 * (1 - T.Smooth(r)) ^ 2
end)

-- Mode-Prism: the glow behind a frame on mouseover and focus, sliced at 14.
-- The frame's edge sits 8 texels in from the border: the light is strongest
-- there and fades out over the 8 texels outside it and 6 texels inside it.
-- (Signed distance to a rounded box, radius 4, around texels 8-24.)
Save("Glows/Prism", 32, 32, function(x, y)
    local qx, qy = math.abs(x + 0.5 - 16) - 4, math.abs(y + 0.5 - 16) - 4
    local outside = math.sqrt(math.max(qx, 0) ^ 2 + math.max(qy, 0) ^ 2)
    local d = outside + math.min(math.max(qx, qy), 0) - 4
    local a
    if d >= 0 then a = (1 - T.Smooth(math.min(1, d / 8))) ^ 1.6
    else a = (1 - T.Smooth(math.min(1, -d / 6))) ^ 2 end
    return 1, 1, 1, 0.9 * a
end)

-- Icons --------------------------------------------------------------------
local ICONS = dofile(here .. "mode_icons.lua")
for _, name in ipairs(ICONS.ORDER) do Shape("Icons/" .. name, 32, 32, ICONS[name]) end
for _, name in ipairs(ICONS.GLYPHS) do Shape("Icons/" .. name, 32, 32, ICONS[name]) end

-- Controls -----------------------------------------------------------------
Shape("Controls/Knob", 8, 8, T.RoundedRect(0, 0, 8, 8, 2))
Luma("Controls/Blade", 8, 16, function(_, y) return T.Lerp(1, 0.6, (y + 0.5) / 16) end)

-- Masks --------------------------------------------------------------------
Shape("Masks/Circle", 128, 128, T.Circle(64, 64, 64))

print(written .. " Mode textures written")
