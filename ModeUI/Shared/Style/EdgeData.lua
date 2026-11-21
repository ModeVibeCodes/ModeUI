local _, addon = ...
-- The border data (docs/DESIGN_LANGUAGE.md, "Borders"): styles, shapes,
-- lighting, roles and the rings each border is drawn from. Pure data with no
-- client calls, so tools/build_mode_assets.lua loads this file too and draws
-- exactly the art these rings name. Colors are tone names (Style.Tone.metal).
-- The Mode-Blizz styles (Mode-Blizz, Mode-BlizzEmpty, Mode-Thin, Mode-Round)
-- were retired on November 20, 2026; their data and art are kept outside the
-- addon in archive/mode-blizz/.
local D = {}

-- Styles in menu order. shape: a SHAPES family; light: a LIGHTS entry; metal:
-- the default Tone.metal key. Mode-Border: soft round corners, a dark glass
-- band with a lit top row and a champagne bottom row; the portrait ring in
-- its own lighting (`ring`). Mode-Empty: the same shape, one flat color
-- (flatTone: the metal tone an untinted flat band takes).
D.STYLE_ORDER = { "obsidian", "obsidianEmpty" }
D.STYLES = {
    obsidian = { label = "Mode-Border", shape = "soft", light = "obsidian", metal = "obsidian", ring = "obsidianRing" },
    obsidianEmpty = { label = "Mode-Empty", shape = "soft", light = "flat", metal = "obsidian", flatTone = "hi" },
}
-- Saved style ids from before November 20, 2026, and the style each draws as
-- (they stay valid; the look step in Shared/Runtime/DB.lua moves saved ones
-- to the style itself).
D.ALIASES = { blizz = "obsidian", thin = "obsidian", round = "obsidian", blizzEmpty = "obsidianEmpty" }
D.METAL_ORDER = { "silver", "steel", "gunmetal" }
D.METAL_LABELS = { silver = "Silver", steel = "Steel", gunmetal = "Gunmetal", obsidian = "Obsidian" }

-- The corner of a role's outermost ring (a radius), by shape and size, and the
-- art's size: width and height in texels and the slice margin (the corner,
-- drawn 1:1; the middle rows stretch, so a lighting profile spans the whole
-- ring). Each ring further in steps its radius in by its depth.
D.SHAPES = {
    softHeavy = { radius = 6, w = 16, h = 64, margin = 6 },
    softThin = { radius = 4, w = 16, h = 64, margin = 4 },
}

-- Lighting profiles: alpha stops { t, alpha } down a ring's height (t 0 at its
-- top, 1 at its bottom) for a white layer tinted with one metal tone, laid in
-- order over a base ring.
D.PROFILES = {
    -- The lit top row (hi) fading out a little over a third of the way down the
    -- sides, and the champagne bottom row (light) fading in over the last
    -- third, both over the dark glass base (deep). Long, soft fades (owner,
    -- November 20, 2026: the change at the edge read too dark).
    o1h = { { 0, 1 }, { 0.08, 0.85 }, { 0.42, 0 }, { 1, 0 } },
    o1l = { { 0, 0 }, { 0.62, 0 }, { 0.92, 0.7 }, { 1, 1 } },
    -- The portrait ring: the color (mid) with a lit top (hi) and a deeper
    -- bottom (dark).
    orh = { { 0, 1 }, { 0.32, 0 }, { 1, 0 } },
    ord = { { 0, 0 }, { 0.6, 0 }, { 1, 0.85 } },
}

-- The band's layers by lighting and band width. row: "all" (the whole band),
-- "outer" or "inner" (one 1px row of a 2px band); tone: the metal tone it is
-- painted; profile: its alpha (none: the solid base).
D.LIGHTS = {
    flat = { [1] = { { row = "all", tone = "mid" } }, [2] = { { row = "all", tone = "mid" } } },
    -- A 2px band keeps its outer row dark glass and lights the inner one.
    obsidian = {
        [1] = { { row = "all", tone = "deep" }, { row = "all", tone = "hi", profile = "o1h" },
            { row = "all", tone = "light", profile = "o1l" } },
        [2] = { { row = "all", tone = "deep" }, { row = "inner", tone = "hi", profile = "o1h" },
            { row = "inner", tone = "light", profile = "o1l" } },
    },
    -- The portrait ring (a disc: the whole band in the color).
    obsidianRing = {
        [1] = { { row = "all", tone = "mid" }, { row = "all", tone = "hi", profile = "orh" }, { row = "all", tone = "dark", profile = "ord" } },
        [2] = { { row = "all", tone = "mid" }, { row = "all", tone = "hi", profile = "orh" }, { row = "all", tone = "dark", profile = "ord" } },
    },
}

-- Roles. size: the shape's size; rim: the band's width (1 or 2); shadow: the
-- 1px outer shadow ring; gap: the 1px black line inside the band, outside the
-- host (true) or "inside" it, over the host's outermost pixel, so the role
-- keeps the reach it had before the line; soft: the drop shadow; flat: a
-- one-color band (opts.color); style: the default style.
D.PRESETS = {
    frame = { size = "Heavy", rim = 2, shadow = true, gap = "inside", soft = true, style = "obsidian" },
    frameThin = { size = "Thin", rim = 1, shadow = true, style = "obsidian" },
    group = { size = "Thin", rim = 1, style = "obsidian" },
    window = { size = "Heavy", rim = 2, shadow = true, gap = "inside", soft = true, style = "obsidian" },
    card = { size = "Thin", rim = 1, gap = true, style = "obsidian" },
    control = { size = "Thin", rim = 1, shadow = true, style = "obsidian" },
    line = { size = "Thin", rim = 1, shadow = true, flat = true, style = "obsidian" },
    empty = { size = "Thin", rim = 1, shadow = true, flat = true, style = "obsidianEmpty" },
}

-- The style a saved style id draws as: itself, the style an old id became
-- (D.ALIASES), or nil for anything else.
function D.Style(styleId)
    if D.STYLES[styleId] then return styleId end
    return D.ALIASES[styleId]
end

-- The rings of a border, outside in: { kind ("shadow", "band", "gap"), key
-- (the art), out (its outer edge, pixels outside the host), tone, profile }.
-- Returns the rings and the reach (an inside black line has out 0).
function D.Rings(preset, styleId, rim)
    local def = assert(D.PRESETS[preset], "unknown border role " .. tostring(preset))
    local style = D.STYLES[D.Style(styleId) or def.style]
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

-- The portrait ring (Style.Ring): a style's 2px lighting laid over a whole
-- disc, so it runs down the disc's height. Each layer is a disc ("Ring" ..
-- profile; a base is the plain Circle) in one metal tone; an "inner" row's
-- disc sits 1px inside the outer one.
D.RING = { style = "obsidian", rim = 2 }
function D.RingLayers(styleId)
    local style = D.STYLES[D.Style(styleId) or D.RING.style]
    return D.LIGHTS[style.ring or style.light][D.RING.rim]
end
-- Every lighting profile a ring can draw, sorted: the art the builder writes.
function D.RingProfiles()
    local seen, list = {}, {}
    for styleId in pairs(D.STYLES) do
        for _, layer in ipairs(D.RingLayers(styleId)) do
            if layer.profile and not seen[layer.profile] then seen[layer.profile] = true; list[#list + 1] = layer.profile end
        end
    end
    table.sort(list)
    return list
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
