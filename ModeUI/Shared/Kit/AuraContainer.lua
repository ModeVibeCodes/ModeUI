local _, addon = ...
local Kit = addon.Kit

-- Blizzard's custom aura containers (12.1, Blizzard_AuraContainer; Forever
-- ships it with no game-type gate). While auras are secret, addon code can't
-- read or count a unit's auras; a CustomAuraContainerTemplate reads them in
-- secure code and fills buttons the addon styles once, in initializeFrame.
-- These helpers are shared by every module that uses containers (Nameplates,
-- Party Frames); each module builds and places its own containers.
Kit.AURA_CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"

-- Whether the client has the template (C_XMLUtil.GetTemplateInfo). Asked
-- once; clients without it use Domain.Auras' reader instead.
local hasContainers
function Kit.HasAuraContainers()
    if hasContainers == nil then
        local ok, info = pcall(function() return C_XMLUtil and C_XMLUtil.GetTemplateInfo(Kit.AURA_CONTAINER_TEMPLATE) end)
        hasContainers = (ok and info ~= nil) and true or false
    end
    return hasContainers
end

-- The game's dispel type IDs, the x values of a dispel color curve
-- (C_UnitAuras.GetAuraDispelTypeColor); "none" gets the no-type color.
Kit.DISPEL_TYPE_IDS = { [0] = "none", [1] = "Magic", [2] = "Curse", [3] = "Disease", [4] = "Poison", [5] = "none",
    [9] = "Enrage", [10] = "none", [11] = "Bleed", [12] = "none" }
Kit.DISPEL_NAMES = { "Magic", "Curse", "Disease", "Poison", "Enrage", "Bleed" }

-- Dispel colors for AddDispelTypeTexture: a step curve on the dispel type IDs
-- colors auras whose type is secret; the name map is the fallback on clients
-- without color curves. colorOf(name) returns { r, g, b } for "none" or a
-- dispel type name.
function Kit.AuraDispelColors(colorOf, alpha)
    local function Color(c) return CreateColor(c[1], c[2], c[3], alpha or 1) end
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum and Enum.LuaCurveType then
        local ok, curve = pcall(function()
            local made = C_CurveUtil.CreateColorCurve()
            made:SetType(Enum.LuaCurveType.Step)
            for id, name in pairs(Kit.DISPEL_TYPE_IDS) do made:AddPoint(id, Color(colorOf(name))) end
            return made
        end)
        if ok and curve then return { customDispelColorCurve = curve } end
    end
    local map = { None = Color(colorOf("none")) }
    for _, name in ipairs(Kit.DISPEL_NAMES) do map[name] = Color(colorOf(name)) end
    return { customDispelColorMap = map }
end

-- Options for AddDispelTypeTexture: keep our texture, recolor it by type,
-- for every aura (harmful, helpful, with or without a type).
function Kit.AuraDispelOptions(colors)
    local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
    local options = { style = styles and styles.PreserveAsset, showWhenHarmful = true, showWhenHelpful = true,
        showWithoutDispelType = true }
    for key, value in pairs(colors) do options[key] = value end
    return options
end

-- Seconds as whole numbers, minutes past a minute ("12", "3m"); nil leaves
-- the game's own format. Made once. `hours` adds hours past an hour ("2h")
-- for long buffs (Buffs & Debuffs), a formatter of its own.
local formatters = {}
function Kit.AuraTimeFormatter(hours)
    local key = hours and "hours" or "minutes"
    if formatters[key] == nil then
        formatters[key] = false
        if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter then
            local ok, made = pcall(function()
                local f = C_StringUtil.CreateNumericRuleFormatter()
                f:AddBreakpoint({ threshold = 0, step = 1, format = "%d" })
                f:AddBreakpoint({ threshold = 60, format = "%dm", components = { { div = 60, step = 1 } } })
                if hours then f:AddBreakpoint({ threshold = 3600, format = "%dh", components = { { div = 3600, step = 1 } } }) end
                return f
            end)
            if ok and made then formatters[key] = made end
        end
    end
    return formatters[key] or nil
end

local FLOW = AnchorUtil and AnchorUtil.FlowDirection or { Left = -1, Right = 1, Up = 1, Down = -1 }
local AXIS = AnchorUtil and AnchorUtil.FlowLayoutAxis or { Horizontal = 0, Vertical = 1 }
Kit.AURA_FLOW, Kit.AURA_AXIS = FLOW, AXIS
