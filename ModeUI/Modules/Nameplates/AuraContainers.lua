local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Auras through Blizzard's custom aura containers (12.1). While auras are
-- secret (combat, encounters, Mythic+, PvP), addon code can no longer read or
-- count a unit's auras: GetUnitAuras returns secret vectors and the index
-- APIs raise errors. A CustomAuraContainerTemplate reads the auras in secure
-- code and fills buttons that ModeUI styles once, in initializeFrame: the Mode
-- rim (colored by dispel type through AddDispelTypeTexture), the cropped icon
-- (SetIcon), the swipe (SetDurationCooldown) and the stack count
-- (SetApplicationCount). The container follows UNIT_AURA by itself.
--
-- One container per plate and row (an anchor; Sit on Border groups have
-- their own) holds every group there, in group order, so they continue as
-- one row; it sizes itself, and edge marks anchored to it carry whatever
-- follows the row (Stacks.lua). Group filters, counts, sizes and
-- placement change through the container's setters; a change to how buttons
-- look (shape, borders, colors, timer, count, font) builds a new container,
-- because buttons are styled only when made. Clients without the template use
-- the reader in Auras.lua, and so does the settings preview.
-- See Blizzard_AuraContainer (Blizzard_CustomAuraContainer.lua,
-- Blizzard_CustomAuraButton.lua) and docs/API_COMPATIBILITY.md.
local Kit, Auras = addon.Kit, addon.Domain.Auras
local TEMPLATE, DISPELS = Kit.AURA_CONTAINER_TEMPLATE, Kit.DISPEL_NAMES

-- Detection, dispel color curves and the time format are shared with every
-- module that uses containers (Shared/Kit/AuraContainer.lua).
function M:UsesAuraContainers() return Kit.HasAuraContainers() end

-- Everything buttons bake in when they are made.
local function LookKey(style, path, px)
    local t = style.auraTimerColor
    local parts = { style.auraShape, style.auraBorder, style.auraBorderSize, tostring(style.auraCCGlow),
        style.auraGlowStyle, string.format("%.3f,%.3f,%.3f", t[1], t[2], t[3]), tostring(style.auraTimer), tostring(style.auraTimerText), tostring(style.auraCount), path, px,
        tostring(style.outline), tostring(style.shadow), tostring(style.liftedShadow), tostring(style.slug) }
    local colors = { "auraNoTypeColor", "auraCCNoTypeColor" }
    for _, name in ipairs(DISPELS) do colors[#colors + 1] = M.dispelColorKeys[name] end
    for _, key in ipairs(colors) do
        local c = style[key]
        parts[#parts + 1] = string.format("%.3f,%.3f,%.3f", c[1], c[2], c[3])
    end
    return table.concat(parts, "|")
end

local function NoTypeColor(style, group)
    return group == "crowdControl" and style.auraCCNoTypeColor or style.auraNoTypeColor
end

-- The rim colors by dispel type. A step curve on the game's dispel type IDs
-- (C_UnitAuras.GetAuraDispelTypeColor) colors auras whose type is secret; the
-- name map is the fallback when the client has no color curves. "None" and the
-- IDs without a named type take the no-type color.
local function DispelColors(style, group, alpha)
    local none = NoTypeColor(style, group)
    return Kit.AuraDispelColors(function(name) return name == "none" and none or style[M.dispelColorKeys[name]] end, alpha)
end

-- Seconds as whole numbers, minutes past a minute ("12", "3m").
function M:AuraTimeFormatter() return Kit.AuraTimeFormatter() end

-- Styles one button as it is made: the parts of Kit.AuraIcon on the button,
-- then registers them so the container fills them (possibly with secrets).
local function Initializer(style, group, width, height, px, path)
    local colors = style.auraBorder == "type" and DispelColors(style, group) or nil
    local formatter = M:AuraTimeFormatter()
    return function(button)
        Kit.AuraIconParts(button)
        Kit.LayoutAuraIcon(button, width, height, px, style, path)
        Kit.TintAuraRim(button, nil)
        button:SetIcon(button.icon)
        if style.auraTimer then button:SetDurationCooldown(button.cooldown) else button.cooldown:Hide() end
        -- The time text is filled by the game; its lifted copy can't follow.
        button.timer.lift:Hide()
        if style.auraTimerText then
            button:SetDurationText(button.timer, formatter and { textFormatter = formatter } or nil)
        else button.timer:Hide() end
        -- The stack count is filled by the game; its lifted copy can't follow.
        button.count.lift:Hide()
        if style.auraCount then button:SetApplicationCount(button.count) else button.count:Hide() end
        if colors then
            local options = { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
                showWhenHarmful = true, showWhenHelpful = true, showWithoutDispelType = true }
            for key, value in pairs(colors) do options[key] = value end
            Kit.DispelAuraRim(button, options, style.auraNoTypeColor)
        end
        -- Crowd control glows in its rim color: the GCD flash (looping, started
        -- here while the button is still ours to touch) or a soft halo.
        if group == "crowdControl" and style.auraCCGlow then
            local gcd = style.auraGlowStyle ~= "soft"
            local region = gcd and button.flash or button.glow
            local alpha = gcd and Kit.AURA_FLASH_ALPHA or Kit.AURA_GLOW_ALPHA
            local c = style.auraCCNoTypeColor
            local glowColors = style.auraBorder == "type" and DispelColors(style, group, alpha)
                or { customDispelColorMap = { None = CreateColor(c[1], c[2], c[3], alpha) } }
            local options = { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
                showWhenHarmful = true, showWhenHelpful = true, showWithoutDispelType = true }
            for key, value in pairs(glowColors) do options[key] = value end
            region:Show()
            if gcd and button.flashAnim then button.flashAnim:Play() end
            button:AddDispelTypeTexture(region, options)
        end
    end
end

-- The groups on each row key (the anchor, ":border" for Sit on Border), in
-- group order: { key = { group, ... } }, every group (a hidden group is a
-- disabled one, so switching it on needs no new container).
local function GroupsByKey(self, style)
    local byKey, order = {}, {}
    for _, group in ipairs(M.auraGroups) do
        local key = self:GroupKey(style, group)
        if not byKey[key] then byKey[key] = {}; order[#order + 1] = key end
        table.insert(byKey[key], group)
    end
    return byKey, order
end

local function Layout(self, plate, group, style, px)
    local width, height = self:AuraSize(plate, group)
    local spacing = style.auraSpacing * px
    return { elementSpacing = spacing, lineSpacing = spacing, groupSpacing = spacing, elementWidth = width, elementHeight = height }
end

-- Makes (or keeps) the container for one row key and its groups.
local function Container(self, plate, rowKey, groups, style, px, path)
    local key = table.concat(groups, ",") .. "|" .. LookKey(style, path, px)
    local containers = plate.auraContainers
    local current = containers[rowKey]
    if current and current.lookKey == key then return current end
    if current then current:SetEnabled(false); current:Hide() end
    local container = CreateFrame("AuraContainer", nil, plate.auraLayer, TEMPLATE)
    container:SetSize(1, 1)
    for _, group in ipairs(groups) do
        local width, height = self:AuraSize(plate, group)
        local filter = Auras.GroupFilter(group, style[group].filter, style.crowdControl.show) or "HARMFUL"
        container:AddAuraGroup(group, filter, { maxFrameCount = style[group].max, layout = Layout(self, plate, group, style, px),
            initializeFrame = Initializer(style, group, width, height, px, path) })
    end
    container.lookKey = key
    container:SetEnabled(false)
    containers[rowKey] = container
    return container
end

local FLOW = AnchorUtil and AnchorUtil.FlowDirection or { Left = -1, Right = 1, Up = 1, Down = -1 }
local AXIS = AnchorUtil and AnchorUtil.FlowLayoutAxis or { Horizontal = 0, Vertical = 1 }

-- The container's point on its far edge, where its edge mark sits.
local function OuterPoint(key)
    if key == "LEFT" or key == "RIGHT" then return key end
    return (key:find("^TOP") and "TOP" or "BOTTOM") .. M.Horizontal(key)
end

-- Places one container from its row's origin (Auras.lua RowOrigin): anchored
-- by that point (a centered row by its own middle, so it stays centered as it
-- resizes), growing away from the bar. Then its marks: the edge mark on its
-- far edge, and the name stops on its inner edges. The container's size is
-- secret; the marks are anchored to it, so whatever follows them moves with it.
local function Place(self, plate, container, rowKey, first)
    local o = self:RowOrigin(plate, rowKey, first)
    container:ClearAllPoints()
    container:SetPoint(o.point, plate.healthBox, o.rel, o.x, o.y)
    container:SetFlowLayoutAnchorPoint(o.flow)
    container:SetFlowLayoutAxis(o.vertical and AXIS.Vertical or AXIS.Horizontal)
    container:SetFlowLayoutGrowthDirection(o.h == -1 and FLOW.Left or FLOW.Right, o.v == -1 and FLOW.Down or FLOW.Up)
    if rowKey:find(":border") then
        for _, side in ipairs({ "LEFT", "RIGHT" }) do
            local stop = plate.nameStops and plate.nameStops[rowKey .. "|" .. side]
            if stop then
                local point, onRow = M.StopPoints(rowKey, side)
                stop:ClearAllPoints(); stop:SetPoint(point, container, onRow)
            end
        end
    else
        local mark = self:Mark(plate, "auraEnds", rowKey)
        mark:ClearAllPoints(); mark:SetPoint(M.EdgePoint(rowKey), container, OuterPoint(rowKey))
    end
end

-- Builds, configures and places the containers and points them at the unit;
-- called when a plate is filled and whenever its settings change.
function M:AttachAuraContainers(plate)
    local style, px, unit = self:Style(plate), plate.px or 1, plate.unit
    plate.auraContainers = plate.auraContainers or {}
    local byKey, order = GroupsByKey(self, style)
    local used = {}
    for _, rowKey in ipairs(order) do
        local groups = byKey[rowKey]
        local container = Container(self, plate, rowKey, groups, style, px, plate.fontPath or Kit.FontPath(style, self.id))
        used[rowKey] = true
        local any, first = false, nil
        for _, group in ipairs(groups) do
            local settings = style[group]
            local on = unit ~= nil and self:GroupShown(plate, group)
            local filter = Auras.GroupFilter(group, settings.filter, style.crowdControl.show)
            if on and filter then
                container:SetAuraGroupFilterString(group, filter)
                container:SetAuraGroupMaxFrameCount(group, settings.max)
                container:SetAuraGroupLayout(group, Layout(self, plate, group, style, px))
                first = first or group
            end
            container:SetAuraGroupEnabled(group, on and filter ~= nil)
            any = any or (on and filter ~= nil)
        end
        Place(self, plate, container, rowKey, first or groups[1])
        if any then
            container:SetEnabled(true); container:SetUnit(unit); container:Show(); container:UpdateAllAuras()
        else
            container:SetEnabled(false); container:Hide()
        end
    end
    for rowKey, container in pairs(plate.auraContainers) do
        if not used[rowKey] then container:SetEnabled(false); container:Hide() end
    end
    self:PlaceArrows(plate)
end

-- Stops every container on a plate (the plate lost its unit).
function M:DetachAuraContainers(plate)
    for _, container in pairs(plate.auraContainers or {}) do
        container:SetEnabled(false); container:Hide()
    end
end
