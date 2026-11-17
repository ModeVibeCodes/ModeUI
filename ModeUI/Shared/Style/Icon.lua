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
-- its lighting discs, D.RingLayers), a 1px dark shadow ring outside it, and
-- the portrait texture cropped to a circle on top. Returns { frame, portrait,
-- disc, layers } sized in `host`'s units.
Style.RING_RIM = 3 -- the `ring` preset's metal, in physical pixels
function Style.Ring(host, diameter, rim, styleId)
    rim = rim or Style.RING_RIM
    local px = Style.Pixel(host)
    local outer = (diameter + 2 * rim) * px
    local ring = { rim = rim, px = px, pool = {}, layers = {} }
    local frame = CreateFrame("Frame", nil, host)
    frame:SetSize(outer, outer)
    ring.frame = frame
    -- The 1px shadow ring, one pixel outside the metal (like `frameThin`).
    local shadow = frame:CreateTexture(nil, "BORDER", nil, -1)
    Style.ApplyAsset(shadow, "Circle")
    Style.Paint(shadow, Tone.shadow, Tone.shadowAlpha)
    shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", -px, px)
    shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", px, -px)
    -- A dark disc under the portrait: nothing behind shows through its edges.
    local back = frame:CreateTexture(nil, "ARTWORK", nil, -1)
    Style.ApplyAsset(back, "Circle")
    Style.Paint(back, Tone.mono.panel)
    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", rim * px, -rim * px)
    portrait:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -rim * px, rim * px)
    back:SetAllPoints(portrait)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(Style.AssetPath("Circle"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(portrait)
    portrait:AddMaskTexture(mask)
    ring.portrait, ring.mask, ring.back, ring.shadow = portrait, mask, back, shadow
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
-- else: Mode-Blizz): the base disc, then each lighting disc over it, in order.
-- Paint it again after (Style.PaintRing).
function Style.SetRingStyle(ring, styleId)
    styleId = Style.EdgeStyle(styleId) or D.RING.style
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

-- Resizes a ring to `outer` (its full width in its host's units) and keeps the
-- portrait `rim` physical pixels inside it.
function Style.LayoutRing(ring, outer, px)
    px = px or Style.Pixel(ring.frame)
    ring.px = px
    ring.frame:SetSize(outer, outer)
    ring.shadow:ClearAllPoints()
    ring.shadow:SetPoint("TOPLEFT", ring.frame, "TOPLEFT", -px, px)
    ring.shadow:SetPoint("BOTTOMRIGHT", ring.frame, "BOTTOMRIGHT", px, -px)
    local inset = ring.rim * px
    ring.portrait:ClearAllPoints()
    ring.portrait:SetPoint("TOPLEFT", ring.frame, "TOPLEFT", inset, -inset)
    ring.portrait:SetPoint("BOTTOMRIGHT", ring.frame, "BOTTOMRIGHT", -inset, inset)
    PlaceLayers(ring)
end

-- The ring's look: its style in a border metal (`metalId`, a Tone.metal key;
-- anything else: the style's own metal), or with `color` (a class color, a
-- custom color, the combat red) Mode-BlizzEmpty: that flat color alone.
function Style.PaintRing(ring, color, metalId)
    local metal = Tone.metal[metalId] or Tone.metal[D.STYLES[ring.styleId].metal]
    for _, layer in ipairs(ring.layers) do
        local shown = not (color and layer.profile)
        layer.texture:SetShown(shown)
        if shown then Style.Paint(layer.texture, color or metal[layer.tone]) end
    end
end
