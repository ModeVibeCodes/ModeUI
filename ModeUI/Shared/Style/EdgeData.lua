local _, addon = ...
-- The border data (docs/DESIGN_LANGUAGE.md, "Borders"): styles, shapes,
-- lighting, roles and the rings each border is drawn from. Pure data with no
-- client calls, so tools/build_mode_assets.lua loads this file too and draws
-- exactly the art these rings name. Colors are tone names (Style.Tone.metal).
local D = {}

-- Styles in menu order. shape: a SHAPES family; light: a LIGHTS entry; metal:
-- the default Tone.metal key.
D.STYLE_ORDER = { "blizz", "blizzEmpty", "thin", "round" }
D.STYLES = {
    blizz = { label = "Mode-Blizz", shape = "cut", light = "specular", metal = "silver" },
    blizzEmpty = { label = "Mode-BlizzEmpty", shape = "cut", light = "flat", metal = "silver" },
    thin = { label = "Mode-Thin", shape = "cut", light = "bevel", metal = "steel" },
    round = { label = "Mode-Round", shape = "round", light = "bevel", metal = "silver" },
}
D.METAL_ORDER = { "silver", "steel", "gunmetal" }
D.METAL_LABELS = { silver = "Silver", steel = "Steel", gunmetal = "Gunmetal" }

-- The corner of a role's outermost ring (a 45-degree cut's leg, or a radius),
-- by shape and size, and the art's size: width and height in texels and the
-- slice margin (the corner, drawn 1:1; the middle rows stretch, so a lighting
-- profile spans the whole ring). Each ring further in steps its corner in by
-- its depth: a cut by 2 - sqrt(2) per pixel, a radius by 1.
D.SHAPES = {
    cutHeavy = { cut = 5, w = 16, h = 64, margin = 6 },
    cutThin = { cut = 3, w = 16, h = 64, margin = 4 },
    roundHeavy = { radius = 12, w = 32, h = 64, margin = 12 },
    roundThin = { radius = 6, w = 16, h = 64, margin = 6 },
}
D.CUT_STEP = 2 - math.sqrt(2)

-- Lighting profiles: alpha stops { t, alpha } down a ring's height (t 0 at its
-- top, 1 at its bottom) for a white layer tinted with one metal tone. Laid in
-- order over a base ring, they draw the study's multi-stop gradients exactly:
-- over `mid`, a `hi` layer at alpha s is mid mixed s toward hi, and so on.
D.PROFILES = {
    -- Specular band, 2px: mid, hi 16%, mid 32%, dark 56%, mid 82%, light (over dark).
    s2m = { { 0, 1 }, { 0.32, 1 }, { 0.56, 0 }, { 0.82, 1 }, { 1, 1 } },
    s2l = { { 0, 0 }, { 0.82, 0 }, { 1, 1 } },
    s2h = { { 0, 0 }, { 0.16, 1 }, { 0.32, 0 }, { 1, 0 } },
    -- Specular band, 1px: mid, hi 16%, mid 34%, dark 58%, light (over dark).
    s1m = { { 0, 1 }, { 0.34, 1 }, { 0.58, 0 }, { 1, 0 } },
    s1l = { { 0, 0 }, { 0.58, 0 }, { 1, 1 } },
    s1h = { { 0, 0 }, { 0.16, 1 }, { 0.34, 0 }, { 1, 0 } },
    -- Bevel, 2px: the outer lip hi, light 40%, mid (over mid); the inner row
    -- mid, dark 50%, deep (over deep).
    b2ol = { { 0, 1 }, { 0.4, 1 }, { 1, 0 } },
    b2oh = { { 0, 1 }, { 0.4, 0 }, { 1, 0 } },
    b2id = { { 0, 1 }, { 0.5, 1 }, { 1, 0 } },
    b2im = { { 0, 1 }, { 0.5, 0 }, { 1, 0 } },
    -- Bevel, 1px: hi fading to mid (over mid).
    b1h = { { 0, 1 }, { 1, 0 } },
}

-- The band's layers by lighting and band width. row: "all" (the whole band),
-- "outer" or "inner" (one 1px row of a 2px band); tone: the metal tone it is
-- painted; profile: its alpha (none: the solid base).
D.LIGHTS = {
    flat = { [1] = { { row = "all", tone = "mid" } }, [2] = { { row = "all", tone = "mid" } } },
    specular = {
        [1] = { { row = "all", tone = "dark" }, { row = "all", tone = "mid", profile = "s1m" },
            { row = "all", tone = "light", profile = "s1l" }, { row = "all", tone = "hi", profile = "s1h" } },
        [2] = { { row = "all", tone = "dark" }, { row = "all", tone = "mid", profile = "s2m" },
            { row = "all", tone = "light", profile = "s2l" }, { row = "all", tone = "hi", profile = "s2h" } },
    },
    bevel = {
        [1] = { { row = "all", tone = "mid" }, { row = "all", tone = "hi", profile = "b1h" } },
        [2] = { { row = "outer", tone = "mid" }, { row = "outer", tone = "light", profile = "b2ol" },
            { row = "outer", tone = "hi", profile = "b2oh" }, { row = "inner", tone = "deep" },
            { row = "inner", tone = "dark", profile = "b2id" }, { row = "inner", tone = "mid", profile = "b2im" } },
    },
}

-- Roles. size: the shape's size; rim: the band's width (1 or 2); shadow: the
-- 1px outer shadow ring; gap: the 1px black line inside the band, outside the
-- host (true) or "inside" it, over the host's outermost pixel, so the role
-- keeps the reach it had before the line; soft: the drop shadow; flat: a
-- one-color band (opts.color); style: the default style.
D.PRESETS = {
    frame = { size = "Heavy", rim = 2, shadow = true, gap = "inside", soft = true, style = "blizz" },
    frameThin = { size = "Thin", rim = 1, shadow = true, style = "blizz" },
    group = { size = "Thin", rim = 1, style = "blizz" },
    window = { size = "Heavy", rim = 2, shadow = true, gap = "inside", soft = true, style = "thin" },
    card = { size = "Thin", rim = 1, gap = true, style = "thin" },
    control = { size = "Thin", rim = 1, shadow = true, style = "thin" },
    line = { size = "Thin", rim = 1, shadow = true, flat = true, style = "thin" },
    empty = { size = "Thin", rim = 1, shadow = true, flat = true, style = "blizzEmpty" },
}

-- The rings of a border, outside in: { kind ("shadow", "band", "gap"), key
-- (the art), out (its outer edge, pixels outside the host), tone, profile }.
-- Returns the rings and the reach (an inside black line has out 0).
function D.Rings(preset, styleId, rim)
    local def = assert(D.PRESETS[preset], "unknown border role " .. tostring(preset))
    local style = D.STYLES[styleId] or D.STYLES[def.style]
    rim = rim == 2 and 2 or rim == 1 and 1 or def.rim
    local shadow = def.shadow and 1 or 0
    local reach = shadow + rim + (def.gap == true and 1 or 0)
    local shape = style.shape .. def.size
    local rings = {}
    local function Ring(kind, depth, thick, tone, profile)
        local key = shape .. depth .. thick .. (profile or "")
        rings[#rings + 1] = { kind = kind, key = key, shape = shape, depth = depth, thick = thick,
            out = reach - depth, tone = tone, profile = profile }
    end
    if shadow == 1 then Ring("shadow", 0, 1) end
    local light = def.flat and "flat" or style.light
    for _, layer in ipairs(D.LIGHTS[light][rim]) do
        local depth, thick = shadow, rim
        if layer.row == "outer" then thick = 1 elseif layer.row == "inner" then depth, thick = shadow + 1, 1 end
        Ring("band", depth, thick, layer.tone, layer.profile)
    end
    if def.gap then Ring("gap", shadow + rim, 1) end
    return rings, reach
end

-- Every ring any border can draw (each role in each style, at either band
-- width), by key: the art the builder writes and the game registers.
function D.AllRings()
    local all = {}
    for preset in pairs(D.PRESETS) do
        for styleId in pairs(D.STYLES) do
            for rim = 1, 2 do
                for _, ring in ipairs((D.Rings(preset, styleId, rim))) do all[ring.key] = ring end
            end
        end
    end
    return all
end

if addon then
    local Style = addon.Style or {}
    addon.Style = Style
    Style.EDGE_DATA = D
end
return D
