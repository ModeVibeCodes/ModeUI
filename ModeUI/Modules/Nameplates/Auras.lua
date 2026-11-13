local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Aura icons on a plate. The kinds shown (crowd control, debuffs, buffs) are
-- game filter strings, so the game decides what matches and no secret aura
-- data is compared (Domain/Auras.lua). Crowd control comes first, then
-- debuffs, then buffs, up to the style's maximum.
local Kit, Auras = addon.Kit, addon.Domain.Auras

function M:AuraIcon(plate, index)
    local icon = plate.auraIcons[index]
    if not icon then
        icon = Kit.AuraIcon(plate.auraLayer)
        plate.auraIcons[index] = icon
        local style, px = self:Style(plate), plate.px or 1
        Kit.LayoutAuraIcon(icon, math.max(px, math.floor(style.auraSize / px + 0.5) * px), px, style, plate.fontPath or Kit.FontPath(style, self.id))
    end
    return icon
end

function M:HideAuras(plate, from)
    for index = from or 1, #plate.auraIcons do plate.auraIcons[index]:Hide() end
    plate.auraCount = (from or 1) - 1
end

function M:UpdateAuras(plate)
    local style, unit = self:Style(plate), plate.unit
    if not unit or not style.showAuras then self:HideAuras(plate); return end
    local filters = Auras.Filters(style.auraCrowdControl, style.auraDebuffs, style.auraBuffs)
    local list = Auras.Collect(unit, filters, style.auraMax)
    for index, aura in ipairs(list) do
        local icon = self:AuraIcon(plate, index)
        Auras.Apply(icon, unit, aura, style.auraTimer, style.auraCount)
        icon:Show()
    end
    self:HideAuras(plate, #list + 1)
    self:LayoutAuras(plate, #list)
end

-- Places `count` icons by the style's position and alignment. Above sits over
-- the name (or the health box when names are off); Below sits under the cast
-- bar; Left and Right grow outward from the health box.
function M:LayoutAuras(plate, count)
    if count == 0 then return end
    local style, px = self:Style(plate), plate.px or 1
    local size = math.max(px, math.floor(style.auraSize / px + 0.5) * px)
    local step = size + style.auraSpacing * px
    local row = count * step - style.auraSpacing * px
    local position, gap = style.auraPosition, 2 * px
    for index = 1, count do
        local icon, offset = plate.auraIcons[index], (index - 1) * step
        icon:ClearAllPoints()
        if position == "left" or position == "right" then
            local side = position == "left" and -1 or 1
            -- Left icons start past the raid marker so they never cover it.
            local clear = gap + ((position == "left" and style.showRaidIcon) and (plate.markSize or 0) + 3 * px or 0)
            local anchor, point = position == "left" and "LEFT" or "RIGHT", position == "left" and "RIGHT" or "LEFT"
            icon:SetPoint(point, plate.healthBox, anchor, side * (clear + offset), 0)
        else
            local above = position == "above"
            local host = above and (style.showName and plate.name or plate.healthBox) or plate
            local vertical, edge = above and "BOTTOM" or "TOP", above and "TOP" or "BOTTOM"
            local x
            if style.auraAlign == "left" then x = offset
            elseif style.auraAlign == "right" then x = plate:GetWidth() - row + offset
            else x = (plate:GetWidth() - row) / 2 + offset end
            icon:SetPoint(vertical .. "LEFT", host, edge .. "LEFT", math.floor(x / px + 0.5) * px, (above and 1 or -1) * gap)
        end
    end
end
