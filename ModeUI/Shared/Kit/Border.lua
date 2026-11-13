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
