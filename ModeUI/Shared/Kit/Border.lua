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
-- host, so above content one level up). Returns the end depth and the rim's
-- thickness, where content starts.
function Kit.LayoutModeBorder(border, host, options)
    local px = options.px or 1
    local thickness = Kit.BORDER_PIXELS * px
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
-- deep at each corner. The corners are the cap art's own corners: the top and
-- bottom quarters of Mode/CapLeft and CapRight are quarter circles, hollowed
-- by the same quarter of the cap's hole mask, so they match the bar ends.
-- `border.masks` (one per corner) round the content 1 pixel under the rim.
local CORNERS = { TOPLEFT = { "LEFT", 0, 0.25, 1, -1 }, TOPRIGHT = { "RIGHT", 0, 0.25, -1, -1 },
    BOTTOMLEFT = { "LEFT", 0.75, 1, 1, 1 }, BOTTOMRIGHT = { "RIGHT", 0.75, 1, -1, 1 } }
local CAP = { LEFT = "ModeCapLeft", RIGHT = "ModeCapRight" }
local HOLE = { LEFT = "ModeCapHoleLeft", RIGHT = "ModeCapHoleRight" }
local function Path(key) return (addon.Media:GetTexture(key)) end

function Kit.ModeBoxBorder(host)
    local edge = CreateFrame("Frame", nil, host)
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
        border.masks[corner] = host:CreateMaskTexture()
    end
    return border
end

-- options: px (Kit.PixelSize), radius (the corners' depth, whole pixels),
-- color (default Kit.BORDER_COLOR), level (default two above the host).
-- Returns the radius and the rim's thickness.
function Kit.LayoutModeBoxBorder(border, host, options)
    local px = options.px or 1
    local thickness = Kit.BORDER_PIXELS * px
    local radius = math.max(thickness, math.floor((options.radius or thickness) / px + 0.5) * px)
    local color = options.color or Kit.BORDER_COLOR
    local s = border.strips
    for _, strip in pairs(s) do strip:ClearAllPoints(); Kit.Tint(strip, color, 1) end
    s.TOP:SetPoint("TOPLEFT", host, "TOPLEFT", radius, 0); s.TOP:SetPoint("TOPRIGHT", host, "TOPRIGHT", -radius, 0)
    s.BOTTOM:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", radius, 0); s.BOTTOM:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -radius, 0)
    s.LEFT:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -radius); s.LEFT:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, radius)
    s.RIGHT:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -radius); s.RIGHT:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, radius)
    s.TOP:SetHeight(thickness); s.BOTTOM:SetHeight(thickness); s.LEFT:SetWidth(thickness); s.RIGHT:SetWidth(thickness)
    local inset = math.max(0, thickness - px)
    for corner, spec in pairs(CORNERS) do
        local side, top, bottom, x, y = spec[1], spec[2], spec[3], spec[4], spec[5]
        local c, mask = border.corners[corner], border.masks[corner]
        c.cap:SetTexture(Path(CAP[side])); c.cap:SetTexCoord(0, 1, top, bottom); Kit.Tint(c.cap, color, 1)
        c.cap:ClearAllPoints(); c.cap:SetPoint(corner, host, corner, 0, 0); c.cap:SetSize(radius, radius)
        local hole = math.max(px, radius - thickness)
        c.hole:SetTexture(Path(HOLE[side]), "CLAMPTOWHITE", "CLAMPTOWHITE"); c.hole:SetTexCoord(0, 1, top, bottom)
        c.hole:ClearAllPoints(); c.hole:SetPoint(corner, host, corner, x * thickness, y * thickness); c.hole:SetSize(hole, hole)
        local reach = math.max(px, radius - inset)
        mask:SetTexture(Path(CAP[side]), "CLAMPTOWHITE", "CLAMPTOWHITE"); mask:SetTexCoord(0, 1, top, bottom)
        mask:ClearAllPoints(); mask:SetPoint(corner, host, corner, x * inset, y * inset); mask:SetSize(reach, reach)
    end
    border.edge:SetFrameLevel(options.level or host:GetFrameLevel() + 2)
    border.radius, border.thickness = radius, thickness
    return radius, thickness
end

-- Rounds content regions to a box border's corners.
function Kit.MaskToBoxBorder(border, regions)
    local m = border.masks
    Kit.AddMasks(regions, { m.TOPLEFT, m.TOPRIGHT, m.BOTTOMLEFT, m.BOTTOMRIGHT })
end
