local _, addon = ...
local Kit = addon.Kit

-- The ModeUI border (owner, November 13, 2026: the unit frames' border is the
-- standard for every border in ModeUI). One crisp rim, no glow or second
-- line:
-- - 2 physical pixels wide (Kit.BORDER_PIXELS), on whole pixels;
-- - the Onyx frame rim color (Kit.BORDER_COLOR), a little lighter than the
--   Onyx border so it stands apart from what it holds;
-- - rounded-rectangle ends: a straight end with round corners, a quarter of
--   the box's height deep (Kit.CAP_DEPTH, Capsule.lua), either end or both
--   (a straight end where something caps it, like a portrait);
-- - drawn on its own frame above what the box holds, and that content is
--   rounded by the border's end masks reaching 1 pixel under the rim, so the
--   rim covers the content's soft edge and no seam shows.
-- Round things (portrait rings, badges, combo points) use the same color and
-- thickness on a circle.
Kit.BORDER_PIXELS = 2
Kit.BORDER_COLOR = Kit.onyx.frameRim
-- The thin variant (owner, November 13, 2026): the same border one physical
-- pixel wide, for pixel-perfect rows with a 1 pixel gap. Layouts take
-- options.thickness (in pixels); Kit.BorderPixels names the two choices.
Kit.BORDER_THIN_PIXELS = 1
Kit.BORDER_CHOICES = { { id = "mode", label = "Mode" }, { id = "thin", label = "Thin" } }
function Kit.BorderPixels(choice) return choice == "thin" and Kit.BORDER_THIN_PIXELS or Kit.BORDER_PIXELS end
local BOTH = { LEFT = true, RIGHT = true }

-- A border for `host`: `border.edge` (the frame the rim draws on),
-- `border.ring` (Kit.CapRing) and `border.masks` (LEFT, RIGHT end masks).
function Kit.ModeBorder(host)
    local edge = CreateFrame("Frame", nil, host)
    edge:SetAllPoints(host)
    return { edge = edge, ring = Kit.CapRing(edge, 0), masks = { LEFT = Kit.EndMask(host), RIGHT = Kit.EndMask(host) } }
end

-- Lays the border round its host. options: px (one physical pixel in the
-- host's units, Kit.PixelSize), height (the box's height, for the end depth),
-- rounded ({ LEFT = bool, RIGHT = bool }; default both), color (default
-- Kit.BORDER_COLOR), level (the rim's frame level; default two above the
-- host, so above content one level up), thickness (pixels; default
-- Kit.BORDER_PIXELS). Returns the end depth and the rim's thickness, where
-- content starts.
function Kit.LayoutModeBorder(border, host, options)
    local px = options.px or 1
    local thickness = (options.thickness or Kit.BORDER_PIXELS) * px
    local depth = Kit.CapDepth(options.height, px)
    local rounded = options.rounded or BOTH
    Kit.PlaceCapRing(border.ring, host, 0, thickness, options.color or Kit.BORDER_COLOR, depth, rounded)
    local inset = math.max(0, thickness - px)
    for side, mask in pairs(border.masks) do Kit.PlaceEndMask(mask, host, side, depth, inset, rounded[side] and true or false) end
    border.edge:SetFrameLevel(options.level or host:GetFrameLevel() + 2)
    border.depth, border.thickness = depth, thickness
    return depth, thickness
end

-- Rounds content regions (bar textures, backgrounds) to the border's ends.
function Kit.MaskToBorder(border, regions) Kit.AddMasks(regions, { border.masks.LEFT, border.masks.RIGHT }) end

-- The same border on a box taller than a bar (a panel, a meter window): a
-- rounded rectangle, where the quarter-of-the-height ends above would bulge.
-- Same rim (2 physical pixels, Kit.BORDER_COLOR, its own frame above the
-- content), straight strips along each side, and a round corner `radius`
-- deep at each corner. Each corner is a whole quarter-circle texture
-- (Mode/Corner*, the cap art's corner on its own) hollowed by its hole mask
-- (Mode/CornerHole*), so they match the bar ends. Whole textures, not a
-- quarter of the cap picked by texture coordinates: in game, masks cut that
-- way left the corners solid (owner's report, November 13, 2026).
-- `border.masks` (one per corner) round the content 1 pixel under the rim.
-- The client holds at most 3 masks on a texture, so content only takes the
-- corners it reaches (Kit.MaskToBoxBorder), and the background is three
-- bands (Kit.BoxFill): top and bottom rounded, the middle plain.
local CORNERS = { TOPLEFT = { "LEFT", 0, 0.25, 1, -1 }, TOPRIGHT = { "RIGHT", 0, 0.25, -1, -1 },
    BOTTOMLEFT = { "LEFT", 0.75, 1, 1, 1 }, BOTTOMRIGHT = { "RIGHT", 0.75, 1, -1, 1 } }
local CORNER_ART = { TOPLEFT = "TopLeft", TOPRIGHT = "TopRight", BOTTOMLEFT = "BottomLeft", BOTTOMRIGHT = "BottomRight" }
local function Path(key) return (addon.Media:GetTexture(key)) end

-- `owner` (default `host`) is the frame the rim and the masks belong to, for
-- a host that is a region rather than a frame (a chat window's box); the rim
-- and the masks are still laid round `host`. Pass `level` to the layout then.
function Kit.ModeBoxBorder(host, owner)
    owner = owner or host
    local edge = CreateFrame("Frame", nil, owner)
    edge:SetAllPoints(host)
    local border = { edge = edge, strips = {}, corners = {}, masks = {} }
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local strip = edge:CreateTexture(nil, "BACKGROUND")
        strip:SetTexture(Kit.FLAT)
        border.strips[side] = strip
    end
    for corner in pairs(CORNERS) do
        local cap, hole = edge:CreateTexture(nil, "BACKGROUND"), edge:CreateMaskTexture()
        cap:AddMaskTexture(hole)
        border.corners[corner] = { cap = cap, hole = hole }
        border.masks[corner] = owner:CreateMaskTexture()
    end
    -- For content reaching all four corners: a rounded end down each side.
    border.ends = { LEFT = Kit.EndMask(owner), RIGHT = Kit.EndMask(owner) }
    return border
end

-- options: px (Kit.PixelSize), radius (the corners' depth, whole pixels),
-- color (default Kit.BORDER_COLOR), level (default two above the host),
-- thickness (pixels; default Kit.BORDER_PIXELS). Returns the radius and the
-- rim's thickness.
function Kit.LayoutModeBoxBorder(border, host, options)
    local px = options.px or 1
    local thickness = (options.thickness or Kit.BORDER_PIXELS) * px
    local radius = math.max(thickness, math.floor((options.radius or thickness) / px + 0.5) * px)
    local color = options.color or Kit.BORDER_COLOR
    local s = border.strips
    for _, strip in pairs(s) do strip:ClearAllPoints(); Kit.Tint(strip, color, 1) end
    s.TOP:SetPoint("TOPLEFT", host, "TOPLEFT", radius, 0); s.TOP:SetPoint("TOPRIGHT", host, "TOPRIGHT", -radius, 0)
    s.BOTTOM:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", radius, 0); s.BOTTOM:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -radius, 0)
    s.LEFT:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -radius); s.LEFT:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, radius)
    s.RIGHT:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -radius); s.RIGHT:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, radius)
    s.TOP:SetHeight(thickness); s.BOTTOM:SetHeight(thickness); s.LEFT:SetWidth(thickness); s.RIGHT:SetWidth(thickness)
    -- Content is rounded at the rim's outer curve, not its inner one: the rim
    -- draws above it, so the extra is hidden, and every pixel inside the outer
    -- curve is covered by content or rim. Rounding both at the inner curve
    -- left the two soft (anti-aliased) edges meeting on the same pixels, which
    -- let the background show through at the corners (owner's screenshots,
    -- November 14, 2026).
    local inset = 0
    for corner, spec in pairs(CORNERS) do
        local x, y = spec[4], spec[5]
        local c, mask = border.corners[corner], border.masks[corner]
        local art, holeArt = "ModeCorner" .. CORNER_ART[corner], "ModeCornerHole" .. CORNER_ART[corner]
        c.cap:SetTexture(Path(art)); c.cap:SetTexCoord(0, 1, 0, 1); Kit.Tint(c.cap, color, 1)
        c.cap:ClearAllPoints(); c.cap:SetPoint(corner, host, corner, 0, 0); c.cap:SetSize(radius, radius)
        -- The hole starts half a pixel further in than the straight edges, so the
        -- curve keeps the rim's width along the diagonal (a 2px ring on a small
        -- radius otherwise covers a single pixel at 45 degrees). The hole is a
        -- mask, sampled per pixel, so the half-pixel offset stays crisp.
        local edge = thickness + px / 2
        local hole = math.max(px, radius - edge)
        c.hole:SetTexture(Path(holeArt), "CLAMPTOWHITE", "CLAMPTOWHITE")
        c.hole:ClearAllPoints(); c.hole:SetPoint(corner, host, corner, x * edge, y * edge); c.hole:SetSize(hole, hole)
        local reach = math.max(px, radius - inset)
        mask:SetTexture(Path(art), "CLAMPTOWHITE", "CLAMPTOWHITE")
        mask:ClearAllPoints(); mask:SetPoint(corner, host, corner, x * inset, y * inset); mask:SetSize(reach, reach)
    end
    for side, mask in pairs(border.ends) do Kit.PlaceEndMask(mask, host, side, radius, inset, true) end
    border.edge:SetFrameLevel(options.level or host:GetFrameLevel() + 2)
    border.radius, border.thickness, border.inset = radius, thickness, inset
    return radius, thickness
end

-- Rounds content regions to the corners they reach; call after the layout.
-- `edges` = { left, top, right, bottom }: how far in from each of the host's
-- edges the regions sit. Content reaching all four corners (a lone row as
-- tall as the box) takes the two side ends instead: their corners are as
-- wide as the radius and a quarter of the box's height tall, so on a box at
-- least four corners tall they round at least as far as the rim.
function Kit.MaskToBoxBorder(border, regions, edges)
    local r, masks = border.radius, {}
    for corner, spec in pairs(CORNERS) do
        local h, v = spec[1] == "LEFT" and edges.left or edges.right, spec[2] == 0 and edges.top or edges.bottom
        if h < r and v < r then masks[#masks + 1] = border.masks[corner] end
    end
    if #masks == 4 then masks = { border.ends.LEFT, border.ends.RIGHT } end
    for _, region in ipairs(regions) do Kit.SetMasks(region, masks) end
end

-- A box's background: three flat bands on the host's BACKGROUND layer.
function Kit.BoxFill(host, sublevel)
    local fill = {}
    for _, band in ipairs({ "top", "middle", "bottom" }) do
        fill[band] = host:CreateTexture(nil, "BACKGROUND", nil, sublevel or -8)
        fill[band]:SetTexture(Kit.FLAT)
    end
    return fill
end

-- Lays the background `inset` units inside the host (after the border's
-- layout): the top and bottom bands are as deep as the corners and rounded
-- by them, the middle fills between. The bands meet on whole pixels, so the
-- background shows no seam at any opacity.
function Kit.LayoutBoxFill(fill, border, host, inset, color, alpha)
    local r, m = border.radius, border.masks
    local band = math.max(0, r - inset)
    for _, texture in pairs(fill) do texture:ClearAllPoints(); Kit.Tint(texture, color, alpha) end
    fill.top:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -inset)
    fill.top:SetPoint("TOPRIGHT", host, "TOPRIGHT", -inset, -inset)
    fill.top:SetHeight(band)
    fill.middle:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -r)
    fill.middle:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, r)
    fill.bottom:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", inset, inset)
    fill.bottom:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, inset)
    fill.bottom:SetHeight(band)
    Kit.SetMasks(fill.top, { m.TOPLEFT, m.TOPRIGHT })
    Kit.SetMasks(fill.middle, {})
    Kit.SetMasks(fill.bottom, { m.BOTTOMLEFT, m.BOTTOMRIGHT })
end
