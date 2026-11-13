local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Aura icons on a plate, in three groups: crowd control, debuffs and buffs.
-- Each group has its own anchor around the plate, offset, icon size and count.
-- Which auras belong to a group is a game filter string, so the game decides
-- what matches and no secret aura data is compared (Domain/Auras.lua).
--
-- Anchors read like a compass. Top anchors sit above the name (or the health
-- bar when names are off) and Bottom anchors below the cast bar; Left, Center
-- and Right line the row up with the plate's edges or middle. Left and Right
-- sit beside the health bar and grow outward. Groups sharing an anchor stack
-- outward in group order.
local Kit, Auras = addon.Kit, addon.Domain.Auras
local GROUPS = M.auraGroups

local function Snap(value, px) return math.max(px, math.floor(value / px + 0.5) * px) end
local function Round(value, px) return math.floor(value / px + 0.5) * px end

function M:AuraIcon(plate, group, index)
    local pool = plate.auraIcons[group]
    local icon = pool[index]
    if not icon then
        icon = Kit.AuraIcon(plate.auraLayer)
        pool[index] = icon
        local style, px = self:Style(plate), plate.px or 1
        Kit.LayoutAuraIcon(icon, Snap(style[group].size, px), px, style, plate.fontPath or Kit.FontPath(style, self.id))
    end
    icon.auraGroup = group
    return icon
end

-- Hides one group's icons from `from` on, or every group's when group is nil.
function M:HideAuras(plate, group, from)
    for _, name in ipairs(group and { group } or GROUPS) do
        local pool = plate.auraIcons[name]
        for index = (group and from) or 1, #pool do pool[index]:Hide() end
        plate.auraShown[name] = ((group and from) or 1) - 1
    end
    local total = 0
    for _, name in ipairs(GROUPS) do total = total + (plate.auraShown[name] or 0) end
    plate.auraCount = total
end

function M:UpdateAuras(plate)
    local style, unit = self:Style(plate), plate.unit
    for _, group in ipairs(GROUPS) do
        local settings, count = style[group], 0
        if unit and style.showAuras and settings.show then
            local crowdControlShown = style.crowdControl.show
            local filter = Auras.GroupFilter(group, settings.filter, crowdControlShown)
            if filter then
                for index, aura in ipairs(Auras.Collect(unit, { filter }, settings.max)) do
                    local icon = self:AuraIcon(plate, group, index)
                    Auras.Apply(icon, unit, aura, style.auraTimer, style.auraCount)
                    icon:Show()
                    count = index
                end
            end
        end
        self:HideAuras(plate, group, count + 1)
    end
    self:LayoutAuras(plate)
end

local TOP = { TOPLEFT = "LEFT", TOP = "CENTER", TOPRIGHT = "RIGHT" }
local BOTTOM = { BOTTOMLEFT = "LEFT", BOTTOM = "CENTER", BOTTOMRIGHT = "RIGHT" }

-- Places every shown icon by its group's anchor and offset.
function M:LayoutAuras(plate)
    local style, px = self:Style(plate), plate.px or 1
    local spacing, gap = style.auraSpacing * px, 2 * px
    local stacked = {} -- distance already used outward from each anchor
    local width = plate:GetWidth()
    for _, group in ipairs(GROUPS) do
        local settings, count = style[group], plate.auraShown[group] or 0
        if count > 0 then
            local anchor, size = settings.anchor, Snap(settings.size, px)
            local step = size + spacing
            local row = count * step - spacing
            local used = stacked[anchor] or 0
            local dx, dy = Round(settings.x, px), Round(settings.y, px)
            for index = 1, count do
                local icon, along = plate.auraIcons[group][index], (index - 1) * step
                icon:ClearAllPoints()
                if TOP[anchor] or BOTTOM[anchor] then
                    local align = TOP[anchor] or BOTTOM[anchor]
                    local start = align == "LEFT" and 0 or align == "RIGHT" and width - row or (width - row) / 2
                    local x = Round(start + along, px) + dx
                    if TOP[anchor] then
                        local host = style.showName and plate.name or plate.healthBox
                        icon:SetPoint("BOTTOMLEFT", host, "TOPLEFT", x, gap + used + dy)
                    else
                        icon:SetPoint("TOPLEFT", plate, "BOTTOMLEFT", x, -(gap + used) + dy)
                    end
                elseif anchor == "LEFT" then
                    -- Left icons start past the raid marker so they never cover it.
                    local clear = gap + (style.showRaidIcon and (plate.markSize or 0) + 3 * px or 0)
                    icon:SetPoint("RIGHT", plate.healthBox, "LEFT", -(clear + used + along) + dx, dy)
                else
                    icon:SetPoint("LEFT", plate.healthBox, "RIGHT", gap + used + along + dx, dy)
                end
            end
            local horizontal = anchor == "LEFT" or anchor == "RIGHT"
            stacked[anchor] = used + (horizontal and row or size) + spacing
        end
    end
end
