local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- The target indicator: Border (docs/DESIGN_LANGUAGE.md: the edge's outer
-- line in the target color, Ivory by default; Border Thickness 2 or 3 tints
-- the rim too), Glow (a soft halo), Arrows (pointing in from both sides),
-- Border and Arrows, or None. Name Only plates color the name instead of a
-- border or glow. The target is found by comparing nameplate frames, never by
-- a secret unit comparison.
local Kit, Domain, Style = addon.Kit, addon.Domain, addon.Style
local GLOW_OUTSET = 12 -- the glow texture's hollow core starts 12 texels in

function M:LayoutTarget(plate)
    local db, px = self:Style(plate), plate.px or 1
    local host = plate.nameOnly and plate.name or plate.healthBox
    plate.targetGlow:ClearAllPoints()
    plate.targetGlow:SetPoint("TOPLEFT", host, "TOPLEFT", -GLOW_OUTSET, GLOW_OUTSET)
    plate.targetGlow:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", GLOW_OUTSET, -GLOW_OUTSET)
    Kit.Rounded(plate.targetGlow, "NameplateGlow")
    for side, arrow in pairs(plate.arrows) do
        addon.Media:ApplyTexture(arrow, "NameplateArrow")
        if side == "left" then arrow:SetTexCoord(0, 1, 0, 1) else arrow:SetTexCoord(1, 0, 0, 1) end
    end
    self:PlaceArrows(plate)
end

-- Arrows always sit outside everything beside the bar on their side: the raid
-- marker, the indicator, any aura row anchored Left or Right and the combo
-- points, which are placed here first. Called again whenever the aura rows or
-- the combo points change.
function M:PlaceArrows(plate)
    self:PlaceCombo(plate)
    local db, px = self:Style(plate), plate.px or 1
    local host = plate.nameOnly and plate.name or plate.healthBox
    local size = math.max(px, math.floor(db.targetArrowSize / px + 0.5) * px)
    local gapPixels = db.targetArrowGap * px
    local extent = plate.auraExtent or {}
    local function Clear(side) return math.max(self:SideRoom(plate, side), extent[side] or 0, self:ComboRoom(plate, side)) end
    for side, arrow in pairs(plate.arrows) do
        arrow:SetSize(size, size)
        arrow:ClearAllPoints()
        if side == "left" then arrow:SetPoint("RIGHT", host, "LEFT", -(gapPixels + Clear("LEFT")), 0)
        else arrow:SetPoint("LEFT", host, "RIGHT", gapPixels + Clear("RIGHT"), 0) end
    end
end

-- The name's color when it isn't the target: the class or reaction color for
-- Name Only, Gradient and Class or Reaction names, the text color otherwise.
function M:NameColor(plate)
    local db = self:Style(plate)
    if plate.nameOnly or db.nameColorMode ~= "text" then
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
    -- The outer line: the target's, else the focus's; a thicker target
    -- border tints the rim as well.
    local outer = (border and not plate.nameOnly) and color or self:FocusRimColor(plate)
    local rim = (border and not plate.nameOnly and db.targetThickness > 1) and color or nil
    for _, box in ipairs({ plate.healthBox, plate.castBox }) do
        box.edge:SetHighlight(outer)
        box.edge:SetTint(rim)
    end
    plate.targetGlow:SetShown(glow and not plate.nameOnly)
    Kit.Tint(plate.targetGlow, color, 0.85)
    for _, arrow in pairs(plate.arrows) do
        arrow:SetShown(arrows)
        Kit.Tint(arrow, color, 1)
    end
    plate.targeted = targeted
    plate.nameOverride = (plate.nameOnly and (border or glow)) and color or nil
    self:PaintName(plate, plate.nameOverride)
end

-- Writes the name (possibly secret) and paints it: `override` (a Name Only
-- target), the Gradient in the class or reaction color (SemiBold, one color
-- per letter), or one color.
function M:PaintName(plate, override)
    local text, name = plate.name, plate.nameValue
    if name == nil then return end
    local db = self:Style(plate)
    if not override and db.nameColorMode == "gradient" and not plate.nameOnly then
        Style.SetName(text, name, self:NameColor(plate), "gradient")
        if text.lift then text.lift:SetText(name) end
        return
    end
    local color = override or self:NameColor(plate)
    Kit.Write(text, name)
    text:SetTextColor(color[1], color[2], color[3], 1)
end
function M:WriteName(plate, name)
    plate.nameValue = name
    self:PaintName(plate, plate.nameOverride)
end

-- Health text: By Health (Rosewood at 30% and under, through Ivory, to
-- Celadon; the client evaluates the curve for a live unit) or the text color.
-- `fraction` is the sample's plain health.
function M:PaintHealthText(plate, fraction)
    local db, text = self:Style(plate), plate.healthText
    if db.healthTextColor == "health" then
        if fraction then
            local c = Style.HealthTextColorAt(fraction)
            text:SetTextColor(c[1], c[2], c[3], 1); return
        elseif plate.unit and Style.PaintHealthText(text, plate.unit) then return end
    end
    local c = db.textColor
    text:SetTextColor(c[1], c[2], c[3], 1)
end

-- The target's nameplate frame is compared directly.
function M:UpdateTarget(plate, targetPlate)
    if targetPlate == nil then targetPlate = Domain.Nameplate.ForUnit("target") or false end
    self:PaintTarget(plate, self:Style(plate).targetStyle ~= "none" and plate.unit ~= nil and plate.nameplate == targetPlate)
end

function M:UpdateTargets()
    local targetPlate = Domain.Nameplate.ForUnit("target") or false
    for _, plate in pairs(self.byUnit) do self:UpdateTarget(plate, targetPlate) end
    -- Combo points live on the target, so they follow it to its plate.
    self:UpdateCombos()
end
