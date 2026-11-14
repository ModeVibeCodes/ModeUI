local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- The aura manager on each member. Each group (buffs, debuffs, dispellable,
-- defensives, crowd control) shows the auras of its filters, at its anchor:
-- inside the bars at that point, or outside past their edge, growing Right,
-- Left, Up or Down and wrapping after Per Row. In the world, Blizzard's aura
-- containers draw them (AuraContainers.lua), so they keep working while auras
-- are secret; clients without containers and the settings preview use the
-- reader here (Domain.Auras), which needs readable auras.
local Kit, Auras = addon.Kit, addon.Domain.Auras
M.CROP_PIXELS = 4 -- cropped icons are this many pixels wider than tall
M.HELPFUL = { buffs = true, defensives = true }

function M:GroupFilters(group, choice)
    for _, item in ipairs(self.auraFilters[group]) do if item.id == choice then return item.filters end end
    return {}
end

-- Icon width and height in whole pixels.
function M:AuraSize(adb, px)
    local width = math.max(px, math.floor(adb.size / px + 0.5) * px)
    return width, adb.shape == "cropped" and math.max(px, width - self.CROP_PIXELS * px) or width
end

-- Where a group's first icon sits and which way the rest go. Returns the
-- icons' corner, the point on the bars it joins, the offset, whether rows
-- run across, and the step directions along a row (dx) and between rows (dy).
function M:AuraPlacement(f, adb, width, height)
    local g = f.geometry
    local px = g.px
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local anchor, grow = adb.anchor, adb.grow
    local h, v = self.Horizontal(anchor), self.Vertical(anchor)
    local across = grow == "left" or grow == "right"
    local outside = adb.place == "outside" and anchor ~= "CENTER"
    local cornerH, cornerV, x, y = h, v, Round(adb.x), Round(adb.y)
    if outside and v ~= "" then
        cornerV = v == "TOP" and "BOTTOM" or "TOP"
        y = y + (v == "TOP" and px or -px)
    elseif outside then
        cornerH = h == "LEFT" and "RIGHT" or "LEFT"
        x = x + (h == "LEFT" and -px or px)
    else
        local inset = g.border + px
        x = x + (h == "LEFT" and inset or h == "RIGHT" and -inset or 0)
        y = y + (v == "TOP" and -inset or v == "BOTTOM" and inset or 0)
    end
    -- A middle anchor starts its first icon centered on it.
    if cornerH == "" and across then
        cornerH = grow == "left" and "RIGHT" or "LEFT"
        x = x + (grow == "left" and 1 or -1) * Round(width / 2)
    end
    if cornerV == "" and not across then
        cornerV = grow == "down" and "TOP" or "BOTTOM"
        y = y + (grow == "down" and 1 or -1) * Round(height / 2)
    end
    local corner = (cornerV .. cornerH) ~= "" and (cornerV .. cornerH) or "CENTER"
    local dx, dy
    if across then dx, dy = grow == "left" and -1 or 1, cornerV == "BOTTOM" and 1 or -1
    else dx, dy = cornerH == "RIGHT" and -1 or 1, grow == "up" and 1 or -1 end
    return corner, anchor, x, y, across, dx, dy
end

-- A per-group style for Kit.LayoutAuraIcon: the module's text settings plus
-- the group's own timer text.
function M:AuraStyle(adb)
    local db = self.db
    return setmetatable({ auraTimerText = adb.timerText, auraBorderSize = 1, auraCorners = "sharp",
        auraTimerColor = db.auraTimerColor }, { __index = db })
end

-- The rim color: the dispel type's color with By Type borders, else the Mode rim.
function M:AuraRimColor(adb, dispelType)
    local db = self.db
    if adb.border ~= "type" then return Kit.BORDER_COLOR end
    local key = dispelType and self.dispelColorKeys[dispelType]
    return key and db[key] or db.auraNoTypeColor
end

local TOOLTIP = { [true] = "SetUnitBuffByAuraInstanceID", [false] = "SetUnitDebuffByAuraInstanceID" }
local function ShowTooltip(icon)
    local tip, method = GameTooltip, TOOLTIP[M.HELPFUL[icon.auraGroup] == true]
    if not tip or not icon.auraUnit or icon.auraID == nil or not tip[method] then return end
    tip:SetOwner(icon, "ANCHOR_BOTTOMRIGHT")
    if pcall(tip[method], tip, icon.auraUnit, icon.auraID, icon.auraFilter) then tip:Show() else tip:Hide() end
end
local function HideTooltip(icon)
    if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == icon then GameTooltip:Hide() end
end

function M:ReaderIcon(f, group, index)
    local pool = f.auraIcons[group]
    if not pool[index] then
        local icon = Kit.AuraIcon(f.auraLayer)
        icon.auraGroup = group
        icon:SetScript("OnEnter", ShowTooltip)
        icon:SetScript("OnLeave", HideTooltip)
        pool[index] = icon
    end
    return pool[index]
end

-- Sizes and places a group's reader icons.
function M:LayoutReaderGroup(f, group)
    local adb, g = self.db.auras[group], f.geometry
    if not g then return end
    local width, height = self:AuraSize(adb, g.px)
    local corner, point, x, y, across, dx, dy = self:AuraPlacement(f, adb, width, height)
    local spacing, style = adb.spacing * g.px, self:AuraStyle(adb)
    for index = 1, f.auraShown[group] do
        local icon = f.auraIcons[group][index]
        Kit.LayoutAuraIcon(icon, width, height, g.px, style, f.fontPath)
        -- Icons take the mouse only for tooltips; clicks fall through to the member.
        if icon.SetMouseMotionEnabled and icon.SetMouseClickEnabled then
            icon:SetMouseMotionEnabled(adb.tooltip); icon:SetMouseClickEnabled(false)
        else icon:EnableMouse(adb.tooltip) end
        local step, line = (index - 1) % adb.perRow, math.floor((index - 1) / adb.perRow)
        local ox = across and step * (width + spacing) or line * (width + spacing)
        local oy = across and line * (height + spacing) or step * (height + spacing)
        icon:ClearAllPoints()
        icon:SetPoint(corner, f.panel, point, x + dx * ox, y + dy * oy)
    end
end

local function HideFrom(f, group, from)
    local pool = f.auraIcons[group]
    for index = from, #pool do pool[index]:Hide() end
    f.auraShown[group] = from - 1
end

function M:LayoutAuras(f)
    if self:UsesContainers(f) then self:AttachAuras(f); return end
    for _, group in ipairs(self.auraGroups) do self:LayoutReaderGroup(f, group) end
end

-- Reader path: every group's auras, and the dispel highlight from the first
-- debuff you can dispel whose type the game shows.
function M:UpdateAuras(f)
    if self:UsesContainers(f) or not self:Live(f) then return end
    for _, group in ipairs(self.auraGroups) do
        local adb, count = self.db.auras[group], 0
        local filters = self:GroupFilters(group, adb.filter)
        if adb.show then
            for index, aura in ipairs(Auras.Collect(f.unit, filters, adb.max)) do
                local icon = self:ReaderIcon(f, group, index)
                Auras.Apply(icon, f.unit, aura, adb.timer, adb.count)
                icon.auraUnit, icon.auraID, icon.auraFilter = f.unit, Auras.Field(aura, "auraInstanceID"), filters[1]
                Kit.TintAuraRim(icon, self:AuraRimColor(adb, icon.dispelType))
                icon:Show()
                count = index
            end
        end
        HideFrom(f, group, count + 1)
        self:LayoutReaderGroup(f, group)
    end
    local dispel
    if self.db.dispelHighlight ~= "none" then
        local first = Auras.Collect(f.unit, self:GroupFilters("dispellable", self.db.dispelFilter), 1)[1]
        local name = first and Auras.Field(first, "dispelName")
        dispel = addon.IsPublic(name) and type(name) == "string" and name or nil
    end
    self:PaintDispel(f, dispel)
end

-- The dispel highlight from a public dispel type (reader path and samples).
function M:PaintDispel(f, dispelType)
    local style = self.db.dispelHighlight
    local key = dispelType and self.dispelColorKeys[dispelType]
    local color = key and self.db[key]
    local ring = f.dispelRing
    for _, region in ipairs({ ring.top, ring.bottom }) do
        region:SetShown(color ~= nil and style == "border"); if color then Kit.Tint(region, color, 1) end
    end
    for _, e in pairs(ring.ends) do
        e.strip:Hide(); e.cap:SetShown(color ~= nil and style == "border"); if color then Kit.Tint(e.cap, color, 1) end
    end
    f.dispelFill:SetShown(color ~= nil and style == "fill")
    if color then Kit.Tint(f.dispelFill, color, 0.25) end
end

-- Stand-ins and the preview: sample icons in every group that is on.
M.SAMPLE_AURAS = { buffs = "Interface\\Icons\\Spell_Holy_Renew", debuffs = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    dispellable = "Interface\\Icons\\Spell_Frost_FrostNova", defensives = "Interface\\Icons\\Spell_Holy_PowerWordShield",
    crowdControl = "Interface\\Icons\\Spell_Nature_Polymorph" }
M.SAMPLE_TYPES = { debuffs = { "Magic", "Poison" }, dispellable = { "Magic", "Curse" }, crowdControl = { "Magic" } }
function M:PaintAuraSample(f, index)
    for _, group in ipairs(self.auraGroups) do
        local adb = self.db.auras[group]
        -- Every member shows buffs and debuffs; the rarer groups show on a few.
        local count = adb.show and (group == "buffs" or group == "debuffs" or index % 2 == 1) and math.min(adb.max, 3) or 0
        for i = 1, count do
            local icon = self:ReaderIcon(f, group, i)
            icon.auraUnit, icon.auraID = nil, nil
            icon.icon:SetTexture(self.SAMPLE_AURAS[group])
            Kit.Write(icon.count, adb.count and i == 1 and "2" or "")
            Kit.Write(icon.timer, adb.timerText and tostring(4 + 3 * i) or "")
            icon.cooldown:Hide()
            Kit.TintAuraRim(icon, self:AuraRimColor(adb, (self.SAMPLE_TYPES[group] or {})[i]))
            icon:Show()
        end
        HideFrom(f, group, count + 1)
        self:LayoutReaderGroup(f, group)
    end
    self:PaintDispel(f, index == 2 and "Magic" or nil)
end
