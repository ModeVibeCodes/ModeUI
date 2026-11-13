local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- The target indicator: Border (the rims turn the target color, thicker with
-- Border Thickness), Glow (a soft halo), Arrows (pointing in from both sides),
-- Border and Arrows, or None. Name Only plates color the name instead of a
-- border or glow. The target is found by comparing nameplate frames, never by
-- a secret unit comparison.
local Kit, Domain = addon.Kit, addon.Domain
local ONYX = Kit.onyx
local GLOW_OUTSET = 12 -- the glow texture's solid core starts 12 texels in

function M:LayoutTarget(plate)
    local db, px = self:Style(plate), plate.px or 1
    local host = plate.nameOnly and plate.name or plate.healthBox
    local thickness = (db.targetThickness - 1) * px
    plate.targetOutline:ClearAllPoints()
    plate.targetOutline:SetPoint("TOPLEFT", plate.healthBox, "TOPLEFT", -thickness, thickness)
    plate.targetOutline:SetPoint("BOTTOMRIGHT", plate.healthBox, "BOTTOMRIGHT", thickness, -thickness)
    M.SkinRounded(plate.targetOutline, "NameplateRim", true)
    plate.targetGlow:ClearAllPoints()
    plate.targetGlow:SetPoint("TOPLEFT", host, "TOPLEFT", -GLOW_OUTSET, GLOW_OUTSET)
    plate.targetGlow:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", GLOW_OUTSET, -GLOW_OUTSET)
    Kit.Rounded(plate.targetGlow, "NameplateGlow")
    local size = math.max(px, math.floor(db.targetArrowSize / px + 0.5) * px)
    local gapPixels = db.targetArrowGap * px
    -- Arrows clear a raid marker standing on their side.
    local function Clear(side) return (db.showRaidIcon and db.raidAnchor == side) and (plate.markSize or 0) + 3 * px or 0 end
    for side, arrow in pairs(plate.arrows) do
        addon.Media:ApplyTexture(arrow, "NameplateArrow")
        arrow:SetSize(size, size)
        arrow:ClearAllPoints()
        if side == "left" then
            arrow:SetTexCoord(0, 1, 0, 1)
            arrow:SetPoint("RIGHT", host, "LEFT", -(gapPixels + Clear("LEFT")), 0)
        else
            arrow:SetTexCoord(1, 0, 0, 1)
            arrow:SetPoint("LEFT", host, "RIGHT", gapPixels + Clear("RIGHT"), 0)
        end
    end
end

-- The name's color when it isn't the target: the class or reaction color for
-- Name Only and Class or Reaction names, the text color otherwise.
function M:NameColor(plate)
    local db = self:Style(plate)
    if plate.nameOnly or db.nameColorMode == "class" then
        local color = plate.sampleNameColor or (plate.unit and self:IdentityColor(plate))
        if color then return color end
    end
    return db.textColor
end

function M:PaintTarget(plate, targeted)
    local db = self:Style(plate)
    local style, color = db.targetStyle, db.targetColor
    local border = targeted and (style == "border" or style == "borderArrows")
    local glow = targeted and style == "glow"
    local arrows = targeted and (style == "arrows" or style == "borderArrows")
    local rim = (border and not plate.nameOnly) and color or ONYX.border
    Kit.Tint(plate.healthBox.rim, rim, 1)
    Kit.Tint(plate.castBox.rim, rim, 1)
    plate.targetOutline:SetShown(border and not plate.nameOnly and db.targetThickness > 1)
    Kit.Tint(plate.targetOutline, color, 1)
    plate.targetGlow:SetShown(glow and not plate.nameOnly)
    Kit.Tint(plate.targetGlow, color, 0.85)
    for _, arrow in pairs(plate.arrows) do
        arrow:SetShown(arrows)
        Kit.Tint(arrow, color, 1)
    end
    local name = (plate.nameOnly and (border or glow)) and color or self:NameColor(plate)
    plate.name:SetTextColor(name[1], name[2], name[3], 1)
    plate.targeted = targeted
end

-- The target's nameplate frame is compared directly.
function M:UpdateTarget(plate, targetPlate)
    if targetPlate == nil then targetPlate = Domain.Nameplate.ForUnit("target") or false end
    self:PaintTarget(plate, self:Style(plate).targetStyle ~= "none" and plate.unit ~= nil and plate.nameplate == targetPlate)
end

function M:UpdateTargets()
    local targetPlate = Domain.Nameplate.ForUnit("target") or false
    for _, plate in pairs(self.byUnit) do self:UpdateTarget(plate, targetPlate) end
end
