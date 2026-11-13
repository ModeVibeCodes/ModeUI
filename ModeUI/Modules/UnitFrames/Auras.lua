local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Buffs and debuffs on a frame, each group with its own settings. A group's
-- rows start at a corner of the health bar's span (Top Right: the first icon's
-- right edge on the health bar's right edge) and stack away from the frame, so
-- they line up with the bars and never reach over the portrait. Top rows sit
-- just over the bar block, or over the name when it is above the frame on that
-- side; bottom rows sit under the bars, or under a cast bar below them.
-- Which auras show is a game filter string and their fields may be secret
-- (Shared/Domain/Auras.lua); icons are Kit.AuraIcon in the Mode look, with
-- the game's aura tooltip on hover.
local Kit, Auras = addon.Kit, addon.Domain.Auras
M.AURA_CROP = 4 -- cropped icons are this many pixels wider than tall, like the nameplates'
M.AURA_SAMPLE = 4
local SAMPLE_ICONS = { buffs = "Interface\\Icons\\Spell_Holy_WordFortitude", debuffs = "Interface\\Icons\\Spell_Shadow_ShadowWordPain" }

function M:BuildAuras(f)
    f.auraLayer = CreateFrame("Frame", nil, f)
    f.auraLayer:SetAllPoints(f)
    f.auraIcons, f.auraShown = { buffs = {}, debuffs = {} }, { buffs = 0, debuffs = 0 }
end

-- Icon width and height in whole pixels.
function M:AuraSize(adb, px)
    local width = math.max(px, math.floor(adb.size / px + 0.5) * px)
    return width, adb.shape == "cropped" and math.max(px, width - self.AURA_CROP * px) or width
end

-- Hovering an icon shows the game's tooltip for that aura (owner, November 13,
-- 2026): GameTooltip:SetUnitBuffByAuraInstanceID / SetUnitDebuffByAuraInstanceID
-- (Blizzard_SharedXMLGame TooltipDataHandler). Their arguments may be secret
-- only for Blizzard's own code, so while the game hides an aura's ID the call
-- fails under pcall and no tooltip shows. Icons take mouse motion only where
-- the client allows it, so clicks still reach the world.
local TOOLTIP = { buffs = "SetUnitBuffByAuraInstanceID", debuffs = "SetUnitDebuffByAuraInstanceID" }
local function ShowTooltip(icon)
    local tip, method = GameTooltip, TOOLTIP[icon.auraGroup]
    if not tip or not icon.auraUnit or icon.auraID == nil or not method or not tip[method] then return end
    tip:SetOwner(icon, "ANCHOR_BOTTOMRIGHT")
    if pcall(tip[method], tip, icon.auraUnit, icon.auraID, icon.auraFilter) then tip:Show() else tip:Hide() end
end
local function HideTooltip(icon)
    if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == icon then GameTooltip:Hide() end
end

function M:AuraIcon(f, group, index)
    local pool = f.auraIcons[group]
    if not pool[index] then
        local icon = Kit.AuraIcon(f.auraLayer)
        icon.auraGroup = group
        if icon.SetMouseMotionEnabled and icon.SetMouseClickEnabled then
            icon:SetMouseMotionEnabled(true); icon:SetMouseClickEnabled(false)
        else icon:EnableMouse(true) end
        icon:SetScript("OnEnter", ShowTooltip)
        icon:SetScript("OnLeave", HideTooltip)
        pool[index] = icon
    end
    return pool[index]
end

-- How far past the bars a group's first row starts, and whether it is a top row.
function M:AuraOrigin(f, unit, adb)
    local fdb, g = self:FrameDB(unit), f.geometry
    local px = g.px
    local function Snap(v) return math.max(px, math.floor(v / px + 0.5) * px) end
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local gap = 2 * px
    if adb.anchor:find("^TOP") then
        local side = adb.anchor:find("RIGHT") and "RIGHT" or "LEFT"
        local nameAbove = fdb.showName and fdb.namePosition ~= "bar" and (fdb.nameAlign == side or fdb.nameAlign == "CENTER")
        if nameAbove then return true, math.max(g.pad + gap, Round(self:NameBottom(fdb, g)) + Snap(fdb.nameFontSize + 2) + gap) end
        return true, g.pad + gap
    end
    local cast = self.db[unit].castBar
    local below = cast.enabled and cast.position == "below" and Round(cast.gap) + Snap(cast.height) + 2 * g.pad or 0
    return false, g.pad + gap + below
end

-- Sizes and places the shown icons of every group.
function M:LayoutAuras(f, unit)
    local g = f.geometry
    if not g or not f.auraIcons then return end
    local fdb, px = self:FrameDB(unit), g.px
    local path = self:FontPath(fdb)
    f.auraLayer:SetFrameLevel(f.textLayer:GetFrameLevel() + 1)
    for _, group in ipairs(self.auraGroups) do
        local adb, count = self.db[unit][group], f.auraShown[group]
        local width, height = self:AuraSize(adb, px)
        local top, start = self:AuraOrigin(f, unit, adb)
        local side = adb.anchor:find("RIGHT") and "RIGHT" or "LEFT"
        local bar = top and f.health or (fdb.showPower and f.power or f.health)
        local spacing = math.floor(adb.spacing + 0.5) * px
        local direction = adb.grow == "left" and -1 or 1
        local dx, dy = math.floor(adb.x + 0.5) * px, math.floor(adb.y + 0.5) * px
        for index = 1, count do
            local icon = f.auraIcons[group][index]
            Kit.LayoutAuraIcon(icon, width, height, px, fdb, path)
            local column, row = (index - 1) % adb.perRow, math.floor((index - 1) / adb.perRow)
            local x = direction * column * (width + spacing) + dx
            local y = start + row * (height + spacing)
            icon:ClearAllPoints()
            if top then icon:SetPoint("BOTTOM" .. side, bar, "TOP" .. side, x, y + dy)
            else icon:SetPoint("TOP" .. side, bar, "BOTTOM" .. side, x, -y + dy) end
        end
    end
end

local function HideFrom(f, group, from)
    local pool = f.auraIcons[group]
    for index = from, #pool do pool[index]:Hide() end
    f.auraShown[group] = from - 1
end

-- The rim: the dispel type's color with By Type borders, else the Onyx rim.
function M:AuraRim(icon, adb, dispelType)
    Kit.TintAuraRim(icon, adb.border == "type" and dispelType and self.dispelColors[dispelType] or nil)
end

function M:UpdateAuras(unit)
    local f = self.frames and self.frames[unit]
    if not f or not f.auraIcons then return end
    for _, group in ipairs(self.auraGroups) do
        local adb, count = self.db[unit][group], 0
        local filter = Auras.frameFilters[group][adb.filter]
        if self:FrameOn(unit) and adb.enabled and filter then
            for index, aura in ipairs(Auras.Collect(unit, { filter }, adb.max)) do
                local icon = self:AuraIcon(f, group, index)
                Auras.Apply(icon, unit, aura, adb.timer, adb.count)
                icon.auraUnit, icon.auraID, icon.auraFilter = unit, Auras.Field(aura, "auraInstanceID"), filter
                self:AuraRim(icon, adb, icon.dispelType)
                icon:Show()
                count = index
            end
        end
        HideFrom(f, group, count + 1)
    end
    self:LayoutAuras(f, unit)
end

-- Stand-ins show a few sample icons per group that is on.
function M:PaintAuraSample(g, unit)
    if not g.auraIcons then return end
    for _, group in ipairs(self.auraGroups) do
        local adb = self.db[unit][group]
        local count = adb.enabled and math.min(adb.max, self.AURA_SAMPLE) or 0
        for index = 1, count do
            local icon = self:AuraIcon(g, group, index)
            icon.auraUnit, icon.auraID = nil, nil -- samples have no tooltip
            icon.icon:SetTexture(SAMPLE_ICONS[group])
            Kit.Write(icon.count, adb.count and index == 1 and "2" or "")
            icon.cooldown:Hide()
            self:AuraRim(icon, adb, group == "debuffs" and (index == 1 and "Magic" or index == 2 and "Poison") or nil)
            icon:Show()
        end
        HideFrom(g, group, count + 1)
    end
    self:LayoutAuras(g, unit)
end
