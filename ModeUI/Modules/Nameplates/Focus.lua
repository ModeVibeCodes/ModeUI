local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Your focus target's plate. Highlight: Border (the rims turn the focus color;
-- the target's border wins on a plate that is both), Glow (a soft halo in the
-- focus color), Stripes (diagonal stripes over the health bar) or None. Focus
-- Texture swaps the focus plate's health bar texture, and Other Plates Opacity
-- fades every other plate while you have a focus. Like the target, the focus
-- is found by comparing nameplate frames.
local Kit, Domain = addon.Kit, addon.Domain

local function Snap(value, px) return math.max(px, math.floor(value / px + 0.5) * px) end

-- Built with the plate (BuildPlate).
function M:BuildFocus(plate)
    plate.focusGlow = plate:CreateTexture(nil, "BACKGROUND", nil, -7)
    plate.focusStripes = plate.health:CreateTexture(nil, "ARTWORK", nil, 2)
    plate.focusGlow:Hide(); plate.focusStripes:Hide()
end

-- Glow and stripe placement; called from LayoutPlate.
function M:LayoutFocus(plate)
    local px = plate.px or 1
    local outset = 12
    plate.focusGlow:ClearAllPoints()
    plate.focusGlow:SetPoint("TOPLEFT", plate.healthBox, "TOPLEFT", -outset, outset)
    plate.focusGlow:SetPoint("BOTTOMRIGHT", plate.healthBox, "BOTTOMRIGHT", outset, -outset)
    Kit.Rounded(plate.focusGlow, "NameplateGlow")
    local stripes = plate.focusStripes
    stripes:ClearAllPoints(); stripes:SetAllPoints(plate.health)
    -- A 16 texel tile repeated across the bar, one texel per physical pixel.
    local path = addon.Media:GetTexture("NameplateStripes")
    if path then stripes:SetTexture(path, "REPEAT", "REPEAT") end
    local tile = 16 * px
    stripes:SetTexCoord(0, Snap(plate.health:GetWidth(), px) / tile, 0, Snap(plate.health:GetHeight(), px) / tile)
    -- LayoutBox just drew the kind's own texture; repaint the focus state.
    plate.healthTexture = self:Style(plate).foregroundTexture
    if plate.focused ~= nil then self:PaintFocus(plate, plate.focused, plate.anyFocus) end
end

-- The rim color a focus border adds, or nil; the target's border wins.
function M:FocusRimColor(plate)
    local db = self:Style(plate)
    if plate.focused and db.focusStyle == "border" and not plate.nameOnly then return db.focusColor end
end

-- Paints a plate as the focus, or not. `anyFocus` says whether some plate is
-- the focus, for fading the others.
function M:PaintFocus(plate, focused, anyFocus)
    local db = self:Style(plate)
    local style, color = db.focusStyle, db.focusColor
    plate.focused, plate.anyFocus = focused, anyFocus
    local plateShown = not plate.nameOnly
    plate.focusGlow:SetShown(focused and style == "glow" and plateShown)
    Kit.Tint(plate.focusGlow, color, 0.85)
    plate.focusStripes:SetShown(focused and style == "stripes" and plateShown)
    Kit.Tint(plate.focusStripes, color, db.focusStripeOpacity / 100)
    -- The focus plate can use its own health bar texture.
    local texture = (focused and db.focusTexture ~= "default") and db.focusTexture or db.foregroundTexture
    if plate.healthTexture ~= texture then
        plate.healthTexture = texture
        Kit.BarForeground(plate.health, texture, plate.health:GetHeight(), plate.px or 1)
    end
    plate:SetAlpha((anyFocus and not focused) and db.focusFadeOthers / 100 or 1)
    -- Rims: the focus border unless the target's own border is showing.
    self:PaintTarget(plate, plate.targeted == true)
end

function M:UpdateFocus(plate, focusPlate)
    if focusPlate == nil then focusPlate = Domain.Nameplate.ForUnit("focus") or false end
    self:PaintFocus(plate, plate.unit ~= nil and focusPlate ~= false and plate.nameplate == focusPlate, focusPlate ~= false)
end

function M:UpdateFocuses()
    local focusPlate = Domain.Nameplate.ForUnit("focus") or false
    for _, plate in pairs(self.byUnit) do self:UpdateFocus(plate, focusPlate) end
end
