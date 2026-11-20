local _, ns = ...
local addon = ns.ModeUI or {}
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
local Tone = addon.Style.Tone
local function Copy(value) return addon.ProfileCodec.Copy(value) end

M.resources = { "power", "combo", "mana", "health" }
-- segmented: one box per point. colorModes: the Bar Color choices it offers.
-- texts: the Text formats it offers (Show Text turns the text on or off).
-- marks: Tick Marks at power values. group: joins the Grouped block (Group
-- Resources; Power hosts it).
local VALUE_TEXTS = { "current", "percent", "both", "currentMax" }
M.resourceSpecs = {
    power = { label = "Power", colorModes = { "power", "class", "custom" }, texts = VALUE_TEXTS, marks = true, group = true },
    combo = { label = "Combo Points", segmented = true, colorModes = { "custom", "class" }, texts = { "current" }, group = true },
    mana = { label = "Alternate Mana", colorModes = { "power", "class", "custom" }, texts = VALUE_TEXTS, marks = true, group = true },
    health = { label = "Health", colorModes = { "class", "custom" }, texts = VALUE_TEXTS },
}
-- Group Resources: Power, Combo Points and Alternate Mana in one border.
M.resourceGroup = { "power", "combo", "mana" }
-- Tick Marks: one to start, up to five with Add Tick Mark (owner, November 18, 2026).
M.MARK_MAX = 5
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

-- The Mode look (docs/DESIGN_LANGUAGE.md, "Bars"): the `frameThin` edge
-- outside each box (Mode-Round in Gunmetal, owner's pick, November 17, 2026),
-- Mode Gradient over Mode BG (Slate at 60%, so the world shows through),
-- Geist Bold text. Dark mode by default: the fill in darkFill and the text in
-- the bar's own color. Combo points in the hostile red with their count;
-- health in your class color.
M.RESOURCE_EMPTY = math.floor(Tone.emptyAlpha * 100 + 0.5)
local function Style(show, height, colorMode, color, text, size, extra)
    local style = {
        show = show, width = 300, height = height, matchWidth = true,
        border = "mode",
        -- Border Style and Border Metal (docs/DESIGN_LANGUAGE.md, "Choosing a border").
        edgeStyle = "obsidian", edgeMetal = "default",
        -- Border Size: the band, 1 or 2px (owner, November 18, 2026).
        edgeSize = 1,
        -- Rim Color: the metal (edgeMetal), the bar's color, or a custom one;
        -- the last two paint the band flat.
        rimColor = "metal", rimCustom = Copy(Tone.ivory),
        barTexture = "media:Mode-FG", colorMode = colorMode, barColor = Copy(color), barOpacity = 100,
        barBackground = "media:Mode-BG", barBackgroundOpacity = M.RESOURCE_EMPTY,
        -- Bar Mode: Color, or Dark (the unit frames' dark mode: the fill in
        -- darkFill, the text in the bar's color, class color or a custom one).
        barMode = "dark", darkText = "power", darkTextColor = Copy(Tone.textBright),
        -- Fill direction, smooth changes (the client eases the bar toward a
        -- new value), the 1px line where the fill ends, and the gap between
        -- combo points.
        reverse = false, smooth = true, fillEdge = true, spacing = 2,
        -- The text sits in the middle of its bar (owner, November 18, 2026).
        textShow = true, text = text, textSize = size, textX = 0, textY = 0, textColor = Copy(Tone.textBright),
        font = "game", fontMedia = addon.Style.FONT_DEFAULT, outline = false, shadow = true, slug = true,
        visibility = "always", opacity = 100, fadeOpacity = 0,
    }
    for key, value in pairs(extra or {}) do style[key] = value end
    return style
end
-- Tick Marks (off until Show Tick Marks): one to five ticks, each a power
-- value (0: none) and the power type it shows on ("any" or a token), so a
-- Druid's 40 Energy hides in Bear Form.
local function Marks()
    return { marksShow = false, marks = { { value = 0, power = "any" } }, markColor = Copy(Tone.ivory), markWidth = 1 }
end
M.resourceDefaults = {
    power = Style(true, 16, "power", Tone.power, "current", 11, Marks()),
    -- Combo Points: Grouped (one border, a line between points) or Separated
    -- (a border per point); Full Combo Points Color once every point is lit.
    combo = Style(true, 10, "custom", Tone.reaction.hostile, "current", 10, { layout = "grouped",
        dividerWidth = 1, dividerColor = Copy(Tone.shadow), fullShow = false, fullColor = Copy(Tone.ivory) }),
    mana = Style(true, 8, "power", Tone.power, "current", 9, Marks()),
    health = Style(false, 14, "class", Tone.reaction.friendly, "percent", 11),
}
-- Alternate Mana starts without its text.
M.resourceDefaults.mana.textShow = false
-- Version 5's heights and combo text (MigrateV5 moves a value still at them).
M.V5_RESOURCE = { height = { power = 14, combo = 10, mana = 8 }, comboText = "none" }
-- Version 6's heights (MigrateV6 moves a height still at them).
M.V6_RESOURCE = { height = { power = 10, combo = 6, mana = 6 } }

M.resourceRanges = { width = { 40, 600, 1 }, height = { 4, 40, 1 }, spacing = { 0, 12, 1 }, edgeSize = { 1, 2, 1 },
    barOpacity = { 10, 100, 5 }, barBackgroundOpacity = { 0, 100, 5 },
    textSize = { 6, 32, 1 }, textX = { -60, 60, 1 }, textY = { -40, 40, 1 },
    opacity = { 10, 100, 5 }, fadeOpacity = { 0, 100, 5 }, markWidth = { 1, 2, 1 }, dividerWidth = { 1, 2, 1 } }
M.MARK_RANGE = { 0, 100000, 1 }
M.resourceColorKeys = { barColor = true, textColor = true, rimCustom = true, darkTextColor = true, markColor = true,
    dividerColor = true, fullColor = true }
M.resourceAlphaKeys = { opacity = true, fadeOpacity = true }
-- Keys Reset to Defaults leaves alone: whether it shows and its size.
M.resourceIdentityKeys = { show = true, width = true, height = true, matchWidth = true }

local COLOR_LABELS = { power = "Power Type", class = "Class Color", custom = "Custom" }
local TEXT_LABELS = { current = "Current", percent = "Percent", both = "Current and Percent",
    currentMax = "Current / Max" }
local function List(ids, labels)
    local list = {}
    for _, id in ipairs(ids) do list[#list + 1] = { id = id, label = labels[id] } end
    return list
end
M.resourceChoices = {
    border = { { id = "mode", label = "Mode" }, { id = "none", label = "None" } },
    edgeStyle = addon.Style.EdgeStyleChoices(), edgeMetal = addon.Style.EdgeMetalChoices(),
    rimColor = { { id = "metal", label = "Metal" }, { id = "bar", label = "Bar Color" }, { id = "custom", label = "Custom" } },
    barMode = { { id = "color", label = "Color" }, { id = "dark", label = "Dark" } },
    darkText = { { id = "power", label = "Power Type" }, { id = "class", label = "Class Color" }, { id = "custom", label = "Custom" } },
    layout = { { id = "grouped", label = "Grouped" }, { id = "separated", label = "Separated" } },
    resourceLayout = { { id = "separate", label = "Separate Resources" }, { id = "grouped", label = "Group Resources" } },
    markPower = { { id = "any", label = "Any Power" }, { id = "ENERGY", label = "Energy" }, { id = "RAGE", label = "Rage" },
        { id = "MANA", label = "Mana" }, { id = "FOCUS", label = "Focus" } },
    reverse = { { id = false, label = "Left to Right" }, { id = true, label = "Right to Left" } },
    visibility = M.choices.visibility,
}
-- A bar's own Bar Color and Text choices.
function M:ResourceColorChoices(id) return List(self.resourceSpecs[id].colorModes, COLOR_LABELS) end
function M:ResourceTextChoices(id)
    local labels = setmetatable({ current = id == "combo" and "Count" or "Current" }, { __index = TEXT_LABELS })
    return List(self.resourceSpecs[id].texts, labels)
end
-- Dark text: "power" is the bar's own color, named Power Type where the bar shows a power.
function M:ResourceDarkTextChoices(id)
    local list = Copy(self.resourceChoices.darkText)
    if self.resourceSpecs[id].colorModes[1] ~= "power" then list[1].label = "Bar Color" end
    return list
end

-- Rim Color in one picker: Default Metal (the style's own), Silver, Steel,
-- Gunmetal, Bar Color or Custom; saved as rimColor plus edgeMetal, so
-- edgeMetal keeps its meaning everywhere else.
function M.ResourceRimChoices()
    local list = {}
    for _, metal in ipairs(addon.Style.EdgeMetalChoices()) do
        list[#list + 1] = { id = metal.id, label = metal.id == "default" and "Default Metal" or metal.label }
    end
    list[#list + 1] = { id = "bar", label = "Bar Color" }
    list[#list + 1] = { id = "custom", label = "Custom" }
    return list
end
function M:ResourceRim(id)
    local style = self.db.resources[id]
    return style.rimColor == "metal" and style.edgeMetal or style.rimColor
end
function M:SetResourceRim(id, choice)
    if choice == "bar" or choice == "custom" then return self:SetResourceOption(id, "rimColor", choice) end
    return self:SetResourceOption(id, "edgeMetal", choice) and self:SetResourceOption(id, "rimColor", "metal")
end

-- Validation ------------------------------------------------------------------

local function Set(list)
    local set = {}
    for _, item in ipairs(list) do set[type(item) == "table" and item.id or item] = true end
    return set
end
local ALLOWED = { border = Set(M.resourceChoices.border),
    visibility = Set(M.resourceChoices.visibility), edgeStyle = Set(M.resourceChoices.edgeStyle),
    edgeMetal = Set(M.resourceChoices.edgeMetal), rimColor = Set(M.resourceChoices.rimColor),
    barMode = Set(M.resourceChoices.barMode), darkText = Set(M.resourceChoices.darkText), layout = Set(M.resourceChoices.layout) }
local MARK_POWER = Set(M.resourceChoices.markPower)
local function Whole(value, range) return Number(value, range[1], range[2]) and value == math.floor(value) end

-- Tick Marks: a list of one to MARK_MAX, each a whole value (0: none) and a power type.
local function ValidateMarks(marks, id)
    local count = #marks
    assert(count >= 1 and count <= M.MARK_MAX, "Invalid resource bar tick marks: " .. id)
    for key in pairs(marks) do assert(Public(key) and Whole(key, { 1, count }), "Invalid resource bar tick marks: " .. id) end
    for _, mark in ipairs(marks) do
        assert(Public(mark) and type(mark) == "table" and Whole(mark.value, M.MARK_RANGE) and MARK_POWER[mark.power],
            "Invalid resource bar tick mark: " .. id)
    end
end

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
    for key, range in pairs(M.resourceRanges) do
        if defaults[key] ~= nil then assert(Whole(style[key], range), "Invalid resource bar range: " .. id .. "." .. key) end
    end
    for key, allowed in pairs(ALLOWED) do
        if defaults[key] ~= nil then assert(allowed[style[key]], "Invalid resource bar choice: " .. id .. "." .. key) end
    end
    if defaults.marks then ValidateMarks(style.marks, id) end
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
    -- Separate Resources (each bar on its own) or Group Resources.
    if db.resourceLayout == nil then db.resourceLayout = "separate" end
    assert(Set(M.resourceChoices.resourceLayout)[db.resourceLayout], "Invalid resource bar layout")
end
