local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Aura icons on a plate, in three groups: crowd control, debuffs and buffs.
-- Each group has its own anchor around the health bar, grow direction, offset,
-- icon size and count. Which auras belong to a group is a game filter string,
-- so the game decides what matches and no secret aura data is compared
-- (Domain/Auras.lua).
--
-- Groups on the same anchor are one row (one aura container in the world:
-- AuraContainers.lua), continuing in group order in the first group's
-- direction. A row starts at its anchor past the spine (Layout.lua): Top and
-- Bottom rows past the name and cast bar, or right on the bar's edge with Sit
-- on Border; Left and Right rows beside the bar. It grows away from the bar;
-- Center is truly centered (the container is anchored by its own middle). Each
-- row keeps an edge mark for whatever follows it (Stacks.lua). Here the
-- settings preview, and clients without containers, place the icons
-- themselves with the same geometry (RowOrigin).
local Kit, Auras = addon.Kit, addon.Domain.Auras
local GROUPS = M.auraGroups
local Horizontal = M.Horizontal

local function Snap(value, px) return math.max(px, math.floor(value / px + 0.5) * px) end
local function Round(value, px) return math.floor(value / px + 0.5) * px end

-- Icon width and height for a group, its 1px band included. Mode (the design
-- language's rule): 4px shorter than wide up to 35px wide, 6px from 36;
-- Cropped: 6px shorter at every size; Square.
M.CROP_PIXELS = 6
function M:AuraSize(plate, group)
    local style, px = self:Style(plate), plate.px or 1
    local size = style[group].size
    local width = Snap(size, px)
    local shape, short = style.auraShape, 0
    if shape == "mode" then short = size >= 36 and 6 or 4 elseif shape == "cropped" then short = M.CROP_PIXELS end
    return width, math.max(px, width - short * px)
end

-- The groups on each row key, in group order: { { key, groups }, ... }.
function M:AuraRows(plate)
    local style, rows, index = self:Style(plate), {}, {}
    for _, group in ipairs(GROUPS) do
        if self:GroupShown(plate, group) then
            local key = self:GroupKey(style, group)
            if not index[key] then index[key] = { key = key, groups = {} }; rows[#rows + 1] = index[key] end
            table.insert(index[key].groups, group)
        end
    end
    return rows
end

-- A centered Top or Bottom row is anchored by its own middle, and its length
-- is secret. With icon + spacing even, every count has the same parity, so
-- one fixed half-pixel nudge puts its edges on whole pixels.
function M:CenterNudge(plate, group, span)
    local px = plate.px or 1
    local width = self:AuraSize(plate, group)
    local w, s = math.floor(width / px + 0.5), math.floor(self:Style(plate).auraSpacing + 0.5)
    if (w + s) % 2 ~= 0 then return 0 end
    local spanOdd = math.floor(span / px + 0.5) % 2 ~= 0
    return ((s % 2 ~= 0) ~= spanOdd) and 0.5 * px or 0
end

-- Where a row starts: the container's anchor point (o.point) on the health
-- box's o.rel, offset (o.x, o.y), its flow anchor and growth (o.h, o.v: 1 or
-- -1), shared by the containers and the reader.
function M:RowOrigin(plate, key, first)
    local style, px = self:Style(plate), plate.px or 1
    local gap, settings = 2 * px, style[first]
    local anchor, grow = settings.anchor, settings.grow
    local top, bottom = anchor:find("^TOP") ~= nil, anchor:find("^BOTTOM") ~= nil
    local side = Horizontal(anchor)
    local center = grow == "center"
    local vertical = grow == "up" or grow == "down" or (center and not (top or bottom))
    local o = { vertical = vertical, center = center, h = grow == "left" and -1 or 1,
        v = (grow == "down" or (center and vertical) or bottom) and -1 or 1 }
    local room = (plate.rowRoom or {})[key] or 0
    local dx, dy = Round(settings.x, px), Round(settings.y, px)
    if top or bottom then
        o.rel = (top and "TOP" or "BOTTOM") .. side
        local past = key:find(":border") and 0 or ((top and plate.above or plate.below) + room)
        dy = dy + (top and (past + gap) or -(past + gap))
        if center and not vertical then
            o.point = top and "BOTTOM" or "TOP"
            o.flow = o.point .. "LEFT"
            if side == "" then dx = dx + self:CenterNudge(plate, first, plate.healthBox:GetWidth()) end
        else
            o.point = (top and "BOTTOM" or "TOP") .. (vertical and side or (o.h == -1 and "RIGHT" or "LEFT"))
            o.flow = o.point
        end
    else
        o.rel = anchor
        local inner = anchor == "LEFT" and "RIGHT" or "LEFT"
        dx = dx + (anchor == "LEFT" and -1 or 1) * (gap + room)
        if vertical then
            o.h = anchor == "LEFT" and -1 or 1
            o.point = center and inner or ((o.v == 1 and "BOTTOM" or "TOP") .. inner)
            o.flow = center and ("TOP" .. inner) or o.point
        else
            o.point = o.h == -1 and "RIGHT" or "LEFT"
            o.flow = o.point
        end
    end
    o.x, o.y = dx, dy
    return o
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

-- The rim color for an icon with By Type borders: its dispel type's color, or
-- the no-type color (orange for crowd control by default). Mode borders: nil.
function M:AuraRimColor(style, dispelType, group)
    if style.auraBorder ~= "type" then return nil end
    local key = dispelType and self.dispelColorKeys[dispelType]
    if key then return style[key] end
    return group == "crowdControl" and style.auraCCNoTypeColor or style.auraNoTypeColor
end

-- The glow color for an icon: crowd control with Crowd Control Glow on gets
-- a glow in its rim color (the no-type crowd control color without By Type).
function M:AuraGlowColor(style, dispelType, group)
    if group ~= "crowdControl" or not style.auraCCGlow then return nil end
    return self:AuraRimColor(style, dispelType, group) or style.auraCCNoTypeColor
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
    -- In the world, aura containers read and update auras themselves; they are
    -- only (re)configured when the plate gets a unit or its layout changes.
    if not plate.sample and self:UsesAuraContainers() then
        if plate.containerUnit ~= plate.unit or plate.containerDirty then
            plate.containerUnit, plate.containerDirty = plate.unit, false
            self:AttachAuraContainers(plate)
        end
        return
    end
    local style, unit = self:Style(plate), plate.unit
    for _, group in ipairs(GROUPS) do
        local settings, count = style[group], 0
        if unit and self:GroupShown(plate, group) then
            local filter = Auras.GroupFilter(group, settings.filter, style.crowdControl.show)
            if filter then
                for index, aura in ipairs(Auras.Collect(unit, { filter }, settings.max)) do
                    local icon = self:AuraIcon(plate, group, index)
                    Auras.Apply(icon, unit, aura, style.auraTimer, style.auraCount)
                    Kit.TintAuraRim(icon, self:AuraRimColor(style, icon.dispelType, group))
                    Kit.GlowAura(icon, self:AuraGlowColor(style, icon.dispelType, group), style.auraGlowStyle)
                    Kit.Write(icon.timer, "")
                    icon:Show()
                    count = index
                end
            end
        end
        self:HideAuras(plate, group, count + 1)
    end
    self:LayoutAuras(plate)
end

-- Places every shown icon (the settings preview, and clients without aura
-- containers): the same rows the containers draw, from RowOrigin, each icon
-- by its corner on whole pixels from the health box's bottom left. Then the
-- rows' edge marks go to their last icons.
function M:LayoutAuras(plate)
    if not plate.sample and self:UsesAuraContainers() then
        if plate.containerUnit then self:AttachAuraContainers(plate) end
        return
    end
    local style, px = self:Style(plate), plate.px or 1
    local spacing = style.auraSpacing * px
    local boxWidth, boxHeight = plate.healthBox:GetWidth(), plate.healthBox:GetHeight()
    for _, row in ipairs(self:AuraRows(plate)) do
        local o = self:RowOrigin(plate, row.key, row.groups[1])
        local cx = (o.rel:find("LEFT") and 0 or o.rel:find("RIGHT") and boxWidth or boxWidth / 2) + o.x
        local cy = (o.rel:find("^TOP") and boxHeight or o.rel:find("^BOTTOM") and 0 or boxHeight / 2) + o.y
        local items, total = {}, -spacing
        for _, group in ipairs(row.groups) do
            local width, height = self:AuraSize(plate, group)
            for index = 1, plate.auraShown[group] or 0 do
                items[#items + 1] = { icon = plate.auraIcons[group][index], w = width, h = height }
                total = total + (o.vertical and height or width) + spacing
            end
        end
        local box, along = nil, 0
        for _, it in ipairs(items) do
            local left, bottom
            if o.center and not o.vertical then
                left = cx - total / 2 + along
                bottom = o.point == "BOTTOM" and cy or cy - it.h
            elseif o.center then
                left = o.point == "RIGHT" and cx - it.w or cx
                bottom = cy + total / 2 - along - it.h
            elseif not o.vertical then
                left = o.h == 1 and cx + along or cx - along - it.w
                bottom = o.point:find("^BOTTOM") and cy or o.point:find("^TOP") and cy - it.h or cy - it.h / 2
            else
                bottom = o.v == 1 and cy + along or cy - along - it.h
                left = o.point:find("LEFT") and cx or o.point:find("RIGHT") and cx - it.w or cx - it.w / 2
            end
            along = along + (o.vertical and it.h or it.w) + spacing
            left, bottom = Round(left, px), Round(bottom, px)
            it.icon:ClearAllPoints()
            it.icon:SetPoint("BOTTOMLEFT", plate.healthBox, "BOTTOMLEFT", left, bottom)
            box = box or { left, left + it.w, bottom, bottom + it.h }
            box[1], box[2] = math.min(box[1], left), math.max(box[2], left + it.w)
            box[3], box[4] = math.min(box[3], bottom), math.max(box[4], bottom + it.h)
        end
        self:PlaceReaderMarks(plate, row.key, box, cx, cy)
    end
    self:PlaceArrows(plate)
end

-- The reader's edge marks: at the last icon's outer edge (an empty row keeps
-- its mark at the row's start, as an empty container shrinks to its anchor),
-- and a name stop at the row's inner edge.
function M:PlaceReaderMarks(plate, key, box, cx, cy)
    local anchor = key:gsub(":border", "")
    local h, top = Horizontal(anchor), anchor:find("^TOP") ~= nil
    local function Put(mark, point, x, y)
        mark:ClearAllPoints()
        mark:SetPoint(point, plate.healthBox, "BOTTOMLEFT", x, y)
    end
    if key:find(":border") then
        for _, side in ipairs({ "LEFT", "RIGHT" }) do
            local stop = plate.nameStops and plate.nameStops[key .. "|" .. side]
            if stop then
                local x = box and (side == "LEFT" and box[1] or box[2]) or cx
                local y = box and (top and box[3] or box[4]) or cy
                Put(stop, (M.StopPoints(key, side)), x, y)
            end
        end
        return
    end
    local mark, point = self:Mark(plate, "auraEnds", key), M.EdgePoint(key)
    local x, y
    if anchor == "LEFT" or anchor == "RIGHT" then
        x = box and (anchor == "LEFT" and box[1] or box[2]) or cx
        y = box and (box[3] + box[4]) / 2 or cy
    else
        x = box and (h == "LEFT" and box[1] or h == "RIGHT" and box[2] or (box[1] + box[2]) / 2) or cx
        y = box and (top and box[4] or box[3]) or cy
    end
    Put(mark, point, x, y)
end
