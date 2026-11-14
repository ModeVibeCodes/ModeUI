local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- Resource Bars: your own health and power next to the cooldowns, in
-- ModeUI's look (the ModeUI border, Mode Gradient over Mode Slate, the
-- module's font). Each bar has its own settings and its own place in
-- ModeUI's Edit Mode, and shows in the /mcdm window's list under Resource
-- Bars. Plain frames: they update and fade in combat too.
--   Power           the power your character shows now (mana, rage, energy)
--   Combo Points    one segment per point (Rogues, Druids in Cat Form)
--   Alternate Mana  a Druid's mana while Bear or Cat Form shows another power
--   Health          your health (off until you turn it on)
-- Saved in db.resources[id]; a missing bar or setting takes its default.
-- Declarations and validation; Resources.lua builds and lays the bars out,
-- ResourceUpdate.lua fills them, ResourceSettings.lua is their page.
local L, Kit = addon.L, addon.Kit
local Public, Number = addon.IsPublic, addon.IsNumber
local P = Kit.palette
local function Copy(value) return addon.ProfileCodec.Copy(value) end

M.resources = { "power", "combo", "mana", "health" }
-- segmented: one box per point. colorModes: the Bar Color choices it offers.
-- texts: the Text choices it offers.
local VALUE_TEXTS = { "none", "current", "percent", "both", "currentMax" }
M.resourceSpecs = {
    power = { label = "Power", colorModes = { "power", "class", "custom" }, texts = VALUE_TEXTS },
    combo = { label = "Combo Points", segmented = true, colorModes = { "custom", "class" }, texts = { "none", "current" } },
    mana = { label = "Alternate Mana", colorModes = { "power", "class", "custom" }, texts = VALUE_TEXTS },
    health = { label = "Health", colorModes = { "class", "custom" }, texts = VALUE_TEXTS },
}
function M:IsResource(id) return type(id) == "string" and self.resourceSpecs[id] ~= nil end
function M:ResourceLabel(id) return L[self.resourceSpecs[id].label] end

-- Edit Mode element IDs (also the saved positions' keys) and frame names.
local function Capital(id) return id:sub(1, 1):upper() .. id:sub(2) end
function M.ResourceElementId(id) return "cooldownManagerResource" .. Capital(id) end
function M.ResourceFrameName(id) return "ModeUIResource" .. Capital(id) end

-- Resource bars attach to the screen, your frames, the viewers and each
-- other; the viewers and custom bars can attach to them in turn.
M.resourceTargets = {}
for _, id in ipairs(M.resources) do
    addon.Positioning:AddTarget(M.ResourceElementId(id), L[M.resourceSpecs[id].label], M.ResourceFrameName(id))
end
for _, id in ipairs(M.resources) do
    local allowed = Copy(M.BASE_TARGETS)
    for _, viewer in ipairs(M.viewers) do allowed[#allowed + 1] = M.ElementId(viewer) end
    for _, other in ipairs(M.resources) do
        if other ~= id then allowed[#allowed + 1] = M.ResourceElementId(other) end
    end
    M.resourceTargets[id] = allowed
end
for _, id in ipairs(M.resources) do
    for _, viewer in ipairs(M.viewers) do table.insert(M.allowedTargets[viewer], M.ResourceElementId(id)) end
    M.customTargets[#M.customTargets + 1] = M.ResourceElementId(id)
end

-- Default places: a stack under Utility Cooldowns (Power, Combo Points,
-- Alternate Mana, Health), each 1 physical pixel under the last (the gap
-- the placement keeps; version 4); each matches the width
-- of what it hangs from, so the stack lines up with the cooldowns.
local function Below(target) return { target = target, placement = "below", x = 0, y = 0 } end
M.resourcePositions = {
    power = Below(M.ElementId("utility")), combo = Below(M.ResourceElementId("power")),
    mana = Below(M.ResourceElementId("combo")), health = Below(M.ResourceElementId("mana")),
}

-- Combo points in the nameplates' combo red; health in your class color.
M.COMBO_COLOR = Kit.RGB(240, 84, 84)
local function Style(show, height, colorMode, color, text, size)
    return {
        show = show, width = 300, height = height, matchWidth = true,
        border = "mode", borderColor = Copy(Kit.BORDER_COLOR),
        barTexture = "mode", colorMode = colorMode, barColor = Copy(color), barOpacity = 100,
        barBackground = "slate", barBackgroundOpacity = 70,
        -- Fill direction, smooth changes (the client eases the bar toward a
        -- new value), the 1px line where the fill ends, and the gap between
        -- combo points.
        reverse = false, smooth = true, fillEdge = true, spacing = 2,
        text = text, textAnchor = "CENTER", textSize = size, textX = 0, textY = 0, textColor = Copy(P.text),
        font = "game", fontMedia = "Expressway", outline = true, shadow = true, slug = true,
        visibility = "always", opacity = 100, fadeOpacity = 0,
    }
end
M.resourceDefaults = {
    power = Style(true, 14, "power", P.mana, "current", 11),
    combo = Style(true, 10, "custom", M.COMBO_COLOR, "none", 10),
    mana = Style(true, 8, "power", P.mana, "none", 9),
    health = Style(false, 14, "class", P.green, "percent", 11),
}

M.resourceRanges = { width = { 40, 600, 1 }, height = { 4, 40, 1 }, spacing = { 0, 12, 1 },
    barOpacity = { 10, 100, 5 }, barBackgroundOpacity = { 0, 100, 5 },
    textSize = { 6, 32, 1 }, textX = { -60, 60, 1 }, textY = { -40, 40, 1 },
    opacity = { 10, 100, 5 }, fadeOpacity = { 0, 100, 5 } }
M.resourceColorKeys = { borderColor = true, barColor = true, textColor = true }
M.resourceAlphaKeys = { opacity = true, fadeOpacity = true }
-- Keys Reset to Defaults leaves alone: whether it shows and its size.
M.resourceIdentityKeys = { show = true, width = true, height = true, matchWidth = true }

local COLOR_LABELS = { power = "Power Type", class = "Class Color", custom = "Custom" }
local TEXT_LABELS = { none = "None", current = "Current", percent = "Percent", both = "Current and Percent",
    currentMax = "Current / Max" }
local function List(ids, labels)
    local list = {}
    for _, id in ipairs(ids) do list[#list + 1] = { id = id, label = labels[id] } end
    return list
end
M.resourceChoices = {
    border = { { id = "mode", label = "ModeUI" }, { id = "none", label = "None" } },
    textAnchor = { { id = "LEFT", label = "Left" }, { id = "CENTER", label = "Center" }, { id = "RIGHT", label = "Right" } },
    reverse = { { id = false, label = "Left to Right" }, { id = true, label = "Right to Left" } },
    visibility = M.choices.visibility,
}
-- A bar's own Bar Color and Text choices.
function M:ResourceColorChoices(id) return List(self.resourceSpecs[id].colorModes, COLOR_LABELS) end
function M:ResourceTextChoices(id)
    local labels = setmetatable({ current = id == "combo" and "Count" or "Current" }, { __index = TEXT_LABELS })
    return List(self.resourceSpecs[id].texts, labels)
end

-- Validation ------------------------------------------------------------------

local function Set(list)
    local set = {}
    for _, item in ipairs(list) do set[type(item) == "table" and item.id or item] = true end
    return set
end
local ALLOWED = { border = Set(M.resourceChoices.border), textAnchor = Set(M.resourceChoices.textAnchor),
    visibility = Set(M.resourceChoices.visibility) }
local function Whole(value, range) return Number(value, range[1], range[2]) and value == math.floor(value) end

local function ValidateResource(style, id)
    local defaults = M.resourceDefaults[id]
    assert(Public(style) and type(style) == "table", "Invalid resource bar settings: " .. id)
    for key, default in pairs(defaults) do
        if style[key] == nil then style[key] = Copy(default) end
        local value = style[key]
        assert(Public(value) and type(value) == type(default), "Invalid resource bar setting: " .. id .. "." .. key)
        if M.resourceColorKeys[key] then
            for i = 1, 3 do assert(Number(value[i], 0, 1), "Invalid resource bar color: " .. id .. "." .. key) end
        end
    end
    for key, range in pairs(M.resourceRanges) do assert(Whole(style[key], range), "Invalid resource bar range: " .. id .. "." .. key) end
    for key, allowed in pairs(ALLOWED) do assert(allowed[style[key]], "Invalid resource bar choice: " .. id .. "." .. key) end
    local spec = M.resourceSpecs[id]
    assert(Set(spec.colorModes)[style.colorMode], "Invalid resource bar color mode: " .. id)
    assert(Set(spec.texts)[style.text], "Invalid resource bar text: " .. id)
    assert(Kit.ValidBarTexture(style.barTexture, true), "Invalid resource bar texture: " .. id)
    assert(Kit.ValidBarTexture(style.barBackground, false), "Invalid resource bar background: " .. id)
end

-- Fills in and checks db.resources (called by Initialize). Bad data stops
-- with an error; nothing is reset.
function M.ValidateResources(db)
    if db.resources == nil then db.resources = {} end
    assert(Public(db.resources) and type(db.resources) == "table", "Invalid resource bars")
    for _, id in ipairs(M.resources) do
        if db.resources[id] == nil then db.resources[id] = Copy(M.resourceDefaults[id]) end
        ValidateResource(db.resources[id], id)
    end
end
