local _, addon = ...
-- Icons and portraits (docs/DESIGN_LANGUAGE.md, "Sizes"). Square elements are a
-- little wider than tall, cropped evenly; portraits sit in a Mode border ring.
local Style = addon.Style
local Tone = Style.Tone
local D = Style.EDGE_DATA

-- The ring's lighting discs, every style's (EdgeData D.RingProfiles): "Ring" .. profile.
for _, profile in ipairs(D.RingProfiles()) do
    Style.ASSETS["Ring" .. profile] = { file = "Borders\\Ring" .. profile }
end

-- Height for an icon `width` pixels wide: 4px shorter up to 35, 6px from 36.
function Style.IconHeight(width)
    if width >= 36 then return width - 6 end
    return width - 4
end

-- Crops an icon texture to fill `width` x `height` without stretching: Blizzard
-- icons carry a 1/14 border trimmed on every side, then the extra width is
-- taken off the top and bottom.
function Style.CropIcon(texture, width, height)
    local trim = 1 / 14
    local span = 1 - 2 * trim
    local ratio = (width and height and width > 0) and (height / width) or 1
    local cut = span * (1 - ratio) / 2
    texture:SetTexCoord(trim, 1 - trim, trim + cut, 1 - trim - cut)
end

-- A frame's shape mask: the game's own SetMaskTexture on a frame that draws
-- its content square (the Minimap; its rectangle is cropped this way). Mode
-- borders never use masks; this is the frame's shape, not a border.
function Style.SetShapeMask(frame, path)
    if frame and frame.SetMaskTexture then frame:SetMaskTexture(path) end
end

-- A portrait in a ring (the `ring` preset): a metal disc `diameter + 2 * rim`
-- wide in a border style's lighting (Mode-Blizz by default: a base disc and
-- its lighting discs, D.RingLayers), a 1px dark shadow ring outside it, the
-- 1px black line inside it, and the portrait texture cropped to a circle on
-- top. Returns { frame, portrait, disc, layers } sized in `host`'s units.
Style.RING_RIM = 3 -- the `ring` preset's band and black line, in physical pixels

-- Places the shadow ring 1px outside the metal, the black line (a black disc)
-- on the metal's inner pixel, and the portrait `rim` pixels in: a 2px band,
-- the line, the whole portrait, in the same size of ring (owner's pick).
local function PlaceInner(ring)
    local px, frame = ring.px, ring.frame
    ring.shadow:ClearAllPoints()
    ring.shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", -px, px)
    ring.shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", px, -px)
    for _, part in ipairs({ { ring.line, ring.rim - 1 }, { ring.portrait, ring.rim } }) do
        local inset = part[2] * px
        part[1]:ClearAllPoints()
        part[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
        part[1]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    end
end

function Style.Ring(host, diameter, rim, styleId)
    rim = rim or Style.RING_RIM
    local px = Style.Pixel(host)
    local outer = (diameter + 2 * rim) * px
    local ring = { rim = rim, px = px, pool = {}, layers = {} }
    local frame = CreateFrame("Frame", nil, host)
    frame:SetSize(outer, outer)
    ring.frame = frame
    -- The 1px shadow ring outside the metal (like `frameThin`).
    local shadow = frame:CreateTexture(nil, "BORDER", nil, -1)
    Style.ApplyAsset(shadow, "Circle")
    Style.Paint(shadow, Tone.shadow, Tone.shadowAlpha)
    -- The 1px black line between the metal and the portrait (the `frame`
    -- role's line); nothing behind shows through the portrait's edges.
    local line = frame:CreateTexture(nil, "ARTWORK", nil, -1)
    Style.ApplyAsset(line, "Circle")
    Style.Paint(line, Tone.shadow)
    local portrait = frame:CreateTexture(nil, "ARTWORK")
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(Style.AssetPath("Circle"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(portrait)
    portrait:AddMaskTexture(mask)
    ring.portrait, ring.mask, ring.line, ring.shadow = portrait, mask, line, shadow
    PlaceInner(ring)
    Style.SetRingStyle(ring, styleId)
    return ring
end

-- Places the metal's discs: an "inner" row's disc 1px inside the outer one.
local function PlaceLayers(ring)
    for _, layer in ipairs(ring.layers) do
        local inset = layer.row == "inner" and ring.px or 0
        layer.texture:ClearAllPoints()
        layer.texture:SetPoint("TOPLEFT", ring.frame, "TOPLEFT", inset, -inset)
        layer.texture:SetPoint("BOTTOMRIGHT", ring.frame, "BOTTOMRIGHT", -inset, inset)
    end
end

-- Draws the ring's metal in a border style (a Style.EDGE_STYLES id; anything
-- else: Mode-Border): the base disc, then each lighting disc over it, in order.
-- Paint it again after (Style.PaintRing).
function Style.SetRingStyle(ring, styleId)
    styleId = Style.ThemeStyle(Style.EdgeStyle(styleId) or D.RING.style)
    if ring.styleId == styleId then return end
    ring.styleId = styleId
    local layers = {}
    for i, layer in ipairs(D.RingLayers(styleId)) do
        local texture = ring.pool[i]
        if not texture then
            texture = ring.frame:CreateTexture(nil, "BORDER", nil, i - 1)
            ring.pool[i] = texture
        end
        Style.ApplyAsset(texture, layer.profile and ("Ring" .. layer.profile) or "Circle")
        texture:Show()
        layers[i] = { texture = texture, tone = layer.tone, profile = layer.profile, row = layer.row }
    end
    for i = #layers + 1, #ring.pool do ring.pool[i]:Hide() end
    ring.layers, ring.disc = layers, layers[1].texture
    PlaceLayers(ring)
    Style.PaintRing(ring)
end

-- Resizes a ring to `outer` (its full width in its host's units), the portrait
-- `rim` physical pixels in (the 2px band, then the 1px black line).
function Style.LayoutRing(ring, outer, px)
    px = px or Style.Pixel(ring.frame)
    ring.px = px
    ring.frame:SetSize(outer, outer)
    PlaceInner(ring)
    PlaceLayers(ring)
end

-- A metal's five tones made from one color (Style.PaintRing): hi and light
-- toward white, dark and deep toward black, mid the color itself. The spread
-- is the Portrait Ring Lab's at Gradient Strength 100% (owner, November 18, 2026).
local SPREAD = { hi = 0.6, light = 0.3, mid = 0, dark = -0.45, deep = -0.65 }
function Style.ColorTones(color)
    local tones = {}
    for name, t in pairs(SPREAD) do
        local c = {}
        for i = 1, 3 do c[i] = t >= 0 and color[i] + (1 - color[i]) * t or color[i] * (1 + t) end
        tones[name] = c
    end
    return tones
end

-- The ring's look: its style's lighting in a border metal (`metalId`, a
-- Tone.metal key; anything else: the suite's metal, else the style's), or in tones made
-- from `color` (a class or reaction color, a custom color, the combat red;
-- Style.ColorTones). The shadow ring and the black line keep their black.
function Style.PaintRing(ring, color, metalId)
    local tones = color and Style.ColorTones(color) or Tone.metal[metalId] or Tone.metal[Style.suiteMetal]
        or Tone.metal[D.STYLES[ring.styleId].metal]
    for _, layer in ipairs(ring.layers) do
        layer.texture:Show()
        Style.Paint(layer.texture, tones[layer.tone])
    end
end
