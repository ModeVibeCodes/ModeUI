local _, addon = ...
local Kit = addon.Kit

-- Boxes with rounded ends (owner, November 13, 2026: a straight end with a
-- gradual curve into it, like a rounded rectangle):
-- the straight edges stay hard-edged flat strips on whole pixels, and each
-- rounded end is a cap (Mode/Cap*.tga) whose depth is a share of the
-- box's height. A ring is a cap hollowed by a hole mask, so nothing opaque
-- sits inside it; what a box holds (bars) is rounded the same way by end
-- masks. Masks use CLAMPTOWHITE, so everything outside their own area stays.

-- How deep a rounded end is: a quarter of the height. The cap textures are a
-- straight end with round corners as wide as the texture (64x256), so at this
-- depth the corners stay circular and the end edge runs straight between them.
Kit.CAP_DEPTH = 0.25
function Kit.CapDepth(height, px)
    return math.max(px, math.floor(height * Kit.CAP_DEPTH / px + 0.5) * px)
end

local function Path(key) return (addon.Media:GetTexture(key)) end
local CAP = { LEFT = "ModeCapLeft", RIGHT = "ModeCapRight" }
local HOLE = { LEFT = "ModeCapHoleLeft", RIGHT = "ModeCapHoleRight" }
local OTHER = { LEFT = "RIGHT", RIGHT = "LEFT" }
local INWARD = { LEFT = 1, RIGHT = -1 } -- the x direction from that end into the box

-- A ring: top and bottom strips, and for each end either a straight strip or
-- a rounded cap with its hole.
function Kit.CapRing(parent, sublevel)
    local ring = { ends = {} }
    local function Flat()
        local t = parent:CreateTexture(nil, "BACKGROUND", nil, sublevel or 0)
        t:SetTexture(Kit.FLAT)
        return t
    end
    ring.top, ring.bottom = Flat(), Flat()
    for side in pairs(CAP) do
        local cap = parent:CreateTexture(nil, "BACKGROUND", nil, sublevel or 0)
        local hole = parent:CreateMaskTexture()
        cap:AddMaskTexture(hole)
        ring.ends[side] = { strip = Flat(), cap = cap, hole = hole }
    end
    return ring
end

-- Lays a ring `inset` units inside `host`, `thickness` wide, in `color`.
-- `rounded` = { LEFT = bool, RIGHT = bool }; `depth` from Kit.CapDepth.
function Kit.PlaceCapRing(ring, host, inset, thickness, color, depth, rounded)
    local function From(side) return rounded[side] and depth or inset end
    for _, strip in ipairs({ ring.top, ring.bottom }) do
        strip:ClearAllPoints(); Kit.Tint(strip, color, 1); strip:SetHeight(thickness)
    end
    ring.top:SetPoint("TOPLEFT", host, "TOPLEFT", From("LEFT"), -inset)
    ring.top:SetPoint("TOPRIGHT", host, "TOPRIGHT", -From("RIGHT"), -inset)
    ring.bottom:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", From("LEFT"), inset)
    ring.bottom:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -From("RIGHT"), inset)
    for side, e in pairs(ring.ends) do
        local x = INWARD[side]
        e.strip:ClearAllPoints(); e.cap:ClearAllPoints(); e.hole:ClearAllPoints()
        e.strip:SetShown(not rounded[side]); e.cap:SetShown(rounded[side] and true or false)
        if rounded[side] then
            e.cap:SetTexture(Path(CAP[side])); Kit.Tint(e.cap, color, 1)
            e.cap:SetPoint("TOP" .. side, host, "TOP" .. side, x * inset, -inset)
            e.cap:SetPoint("BOTTOM" .. side, host, "BOTTOM" .. side, x * inset, inset)
            e.cap:SetWidth(depth - inset)
            local edge = inset + thickness
            e.hole:SetTexture(Path(HOLE[side]), "CLAMPTOWHITE", "CLAMPTOWHITE")
            e.hole:SetPoint("TOP" .. side, host, "TOP" .. side, x * edge, -edge)
            e.hole:SetPoint("BOTTOM" .. side, host, "BOTTOM" .. side, x * edge, edge)
            e.hole:SetWidth(math.max(1, depth - edge))
        else
            Kit.Tint(e.strip, color, 1)
            e.strip:SetPoint("TOP" .. side, host, "TOP" .. side, x * inset, -inset - thickness)
            e.strip:SetPoint("BOTTOM" .. side, host, "BOTTOM" .. side, x * inset, inset + thickness)
            e.strip:SetWidth(thickness)
        end
    end
end

-- An end mask: what it is added to keeps only the half oval at that end,
-- `inset` units inside the host. Off, it sits just past the host's end and
-- clips nothing.
function Kit.EndMask(parent) return parent:CreateMaskTexture() end
function Kit.PlaceEndMask(mask, host, side, depth, inset, on)
    mask:SetTexture(Path(CAP[side]), "CLAMPTOWHITE", "CLAMPTOWHITE")
    mask:ClearAllPoints()
    if on then
        local x = INWARD[side]
        mask:SetPoint("TOP" .. side, host, "TOP" .. side, x * inset, -inset)
        mask:SetPoint("BOTTOM" .. side, host, "BOTTOM" .. side, x * inset, inset)
        mask:SetWidth(math.max(1, depth - inset))
    else
        mask:SetPoint("TOP" .. OTHER[side], host, "TOP" .. side, 0, 0)
        mask:SetPoint("BOTTOM" .. OTHER[side], host, "BOTTOM" .. side, 0, 0)
        mask:SetWidth(1)
    end
end

-- Adds masks to regions once each (a region keeps a mask it was given).
function Kit.AddMasks(regions, masks)
    for _, region in ipairs(regions) do
        if region and region.AddMaskTexture then
            region.capMasks = region.capMasks or {}
            for _, mask in ipairs(masks) do
                if not region.capMasks[mask] then region.capMasks[mask] = true; region:AddMaskTexture(mask) end
            end
        end
    end
end
