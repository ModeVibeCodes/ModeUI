local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Aura icons on a plate, in three groups: crowd control, debuffs and buffs.
-- Each group has its own anchor around the health bar, grow direction, offset,
-- icon size and count. Which auras belong to a group is a game filter string,
-- so the game decides what matches and no secret aura data is compared
-- (Domain/Auras.lua).
--
-- Anchors read like a compass. Top anchors sit above everything over the bar
-- (name, cast bar), Bottom anchors below everything under it, lined up with the
-- bar's left edge, middle or right edge; Left and Right sit beside the bar (past
-- a raid marker on that side). Icons then grow Right, Left, Up, Down or from the
-- Center. Groups sharing an anchor continue one after another in group order,
-- in the first group's direction.
local Kit, Auras = addon.Kit, addon.Domain.Auras
local GROUPS = M.auraGroups

local function Snap(value, px) return math.max(px, math.floor(value / px + 0.5) * px) end
local function Round(value, px) return math.floor(value / px + 0.5) * px end

-- Icon width and height for a group: cropped icons are 4px wider than tall.
M.CROP_PIXELS = 4
function M:AuraSize(plate, group)
    local style, px = self:Style(plate), plate.px or 1
    local width = Snap(style[group].size, px)
    local height = style.auraShape == "cropped" and math.max(px, width - M.CROP_PIXELS * px) or width
    return width, height
end

-- The band that groups set to Sit on Health Bar take above ("TOP") or below
-- ("BOTTOM") the bar: their tallest icon plus a gap, or 0. Only Top and Bottom
-- anchors can sit on the bar.
function M:AttachedRoom(plate, side)
    local style, px = self:Style(plate), plate.px or 1
    if not style.showAuras or plate.nameOnly then return 0 end
    local tallest = 0
    for _, group in ipairs(GROUPS) do
        local settings = style[group]
        if settings.show and settings.attach and settings.anchor:find("^" .. side) then
            local _, height = self:AuraSize(plate, group)
            tallest = math.max(tallest, height)
        end
    end
    return tallest > 0 and tallest + 2 * px or 0
end

function M:LayoutAuraIcon(plate, icon, group)
    local width, height = self:AuraSize(plate, group)
    local style = self:Style(plate)
    Kit.LayoutAuraIcon(icon, width, height, plate.px or 1, style, plate.fontPath or Kit.FontPath(style, self.id))
end

function M:AuraIcon(plate, group, index)
    local pool = plate.auraIcons[group]
    local icon = pool[index]
    if not icon then
        icon = Kit.AuraIcon(plate.auraLayer)
        pool[index] = icon
        self:LayoutAuraIcon(plate, icon, group)
    end
    icon.auraGroup = group
    return icon
end

-- The rim color for an icon: its dispel type's color with By Type borders.
function M:AuraRimColor(style, dispelType)
    local key = style.auraBorder == "type" and dispelType and self.dispelColorKeys[dispelType]
    return key and style[key] or nil
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
            local filter = Auras.GroupFilter(group, settings.filter, style.crowdControl.show)
            if filter then
                for index, aura in ipairs(Auras.Collect(unit, { filter }, settings.max)) do
                    local icon = self:AuraIcon(plate, group, index)
                    Auras.Apply(icon, unit, aura, style.auraTimer, style.auraCount)
                    Kit.TintAuraRim(icon, self:AuraRimColor(style, icon.dispelType))
                    icon:Show()
                    count = index
                end
            end
        end
        self:HideAuras(plate, group, count + 1)
    end
    self:LayoutAuras(plate)
end

local STEP = { right = { 1, 0 }, left = { -1, 0 }, up = { 0, 1 }, down = { 0, -1 } }

-- Places every shown icon. Positions are worked out as centers relative to the
-- health bar's center, then snapped to whole pixels at each icon's corner.
function M:LayoutAuras(plate)
    local style, px = self:Style(plate), plate.px or 1
    local spacing, gap = style.auraSpacing * px, 2 * px
    local boxWidth, boxHeight = plate.healthBox:GetWidth(), plate.healthBox:GetHeight()
    local function Clear(side) return self:SideRoom(plate, side) end
    -- How far each side's aura row reaches past the bar, for the arrows.
    local extent = { LEFT = 0, RIGHT = 0 }
    -- Gather each anchor's icons in group order.
    local byAnchor, order = {}, {}
    for _, group in ipairs(GROUPS) do
        local settings, count = style[group], plate.auraShown[group] or 0
        if count > 0 then
            local list = byAnchor[settings.anchor]
            if not list then
                list = { grow = settings.grow, attach = settings.attach }
                byAnchor[settings.anchor] = list; order[#order + 1] = settings.anchor
            end
            local width, height = self:AuraSize(plate, group)
            for index = 1, count do
                list[#list + 1] = { icon = plate.auraIcons[group][index], w = width, h = height, dx = Round(settings.x, px), dy = Round(settings.y, px) }
            end
        end
    end
    for _, anchor in ipairs(order) do
        local list = byAnchor[anchor]
        local grow = list.grow
        local vertical = grow == "up" or grow == "down" or (grow == "center" and (anchor == "LEFT" or anchor == "RIGHT"))
        -- Length of the run along its axis, for centering.
        local length = -spacing
        for _, item in ipairs(list) do length = length + (vertical and item.h or item.w) + spacing end
        local along = 0
        for _, item in ipairs(list) do
            local w, h = item.w, item.h
            -- The first icon's center for this anchor, its inner edge on the plate.
            local cx, cy
            if anchor:find("^TOP") or anchor:find("^BOTTOM") then
                local top = anchor:find("^TOP") ~= nil
                -- On the bar's edge, or past everything above or below it.
                local past = list.attach and 0 or (top and plate.above or plate.below)
                cy = top and (boxHeight / 2 + past + gap + h / 2) or -(boxHeight / 2 + past + gap + h / 2)
                cx = anchor:find("LEFT") and (-boxWidth / 2 + w / 2) or anchor:find("RIGHT") and (boxWidth / 2 - w / 2) or 0
            elseif anchor == "LEFT" then
                cx, cy = -(boxWidth / 2 + gap + Clear("LEFT") + w / 2), 0
            else
                cx, cy = boxWidth / 2 + gap + Clear("RIGHT") + w / 2, 0
            end
            local size = vertical and h or w
            if grow == "center" then
                local offset = -length / 2 + along + size / 2
                if vertical then cy = cy + offset else cx = cx + offset end
            else
                local step = STEP[grow]
                cx, cy = cx + step[1] * along, cy + step[2] * along
            end
            along = along + size + spacing
            local left = Round(cx - w / 2 + boxWidth / 2, px) + item.dx
            local bottom = Round(cy - h / 2 + boxHeight / 2, px) + item.dy
            item.icon:ClearAllPoints()
            item.icon:SetPoint("BOTTOMLEFT", plate.healthBox, "BOTTOMLEFT", left, bottom)
            if anchor == "LEFT" then extent.LEFT = math.max(extent.LEFT, -left + gap)
            elseif anchor == "RIGHT" then extent.RIGHT = math.max(extent.RIGHT, left + w - boxWidth + gap) end
        end
    end
    plate.auraExtent = extent
    self:PlaceArrows(plate)
end
