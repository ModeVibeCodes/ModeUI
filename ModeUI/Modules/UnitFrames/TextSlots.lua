local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Text slots (owner, November 13, 2026, after EllesmereUI): fixed spots on a
-- frame, each showing one piece of text picked from a list, with its own font
-- size, color and offsets. Nine spots on the health bar, one on the top
-- border (the name sitting on it) and three on the power bar. Saved in
-- db[unit].texts[slot]; a Target matching the Player uses the Player's slots,
-- swapped left for right when it mirrors them (Texts.lua lays them out).
local function Copy(value) return addon.ProfileCodec.Copy(value) end

M.textSlots = { "topLeft", "top", "topRight", "left", "center", "right", "bottomLeft", "bottom", "bottomRight", "border",
    "powerLeft", "powerCenter", "powerRight" }
M.healthSlots = { "topLeft", "top", "topRight", "left", "center", "right", "bottomLeft", "bottom", "bottomRight" }
M.powerSlots = { "powerLeft", "powerCenter", "powerRight" }
M.textSlotLabels = { topLeft = "Top Left", top = "Top", topRight = "Top Right", left = "Left", center = "Center", right = "Right",
    bottomLeft = "Bottom Left", bottom = "Bottom", bottomRight = "Bottom Right", border = "On the Border",
    powerLeft = "Power Left", powerCenter = "Power Center", powerRight = "Power Right" }
-- Where a slot sits: its bar, and the bar's point it is anchored to.
M.slotPlaces = {
    topLeft = { bar = "health", h = "LEFT", v = "TOP" }, top = { bar = "health", h = "CENTER", v = "TOP" },
    topRight = { bar = "health", h = "RIGHT", v = "TOP" }, left = { bar = "health", h = "LEFT", v = "CENTER" },
    center = { bar = "health", h = "CENTER", v = "CENTER" }, right = { bar = "health", h = "RIGHT", v = "CENTER" },
    bottomLeft = { bar = "health", h = "LEFT", v = "BOTTOM" }, bottom = { bar = "health", h = "CENTER", v = "BOTTOM" },
    bottomRight = { bar = "health", h = "RIGHT", v = "BOTTOM" }, border = { bar = "border" },
    powerLeft = { bar = "power", h = "LEFT", v = "CENTER" }, powerCenter = { bar = "power", h = "CENTER", v = "CENTER" },
    powerRight = { bar = "power", h = "RIGHT", v = "CENTER" } }
-- A mirrored Target shows each Player slot on the other side.
M.slotMirror = { topLeft = "topRight", topRight = "topLeft", left = "right", right = "left", bottomLeft = "bottomRight",
    bottomRight = "bottomLeft", powerLeft = "powerRight", powerRight = "powerLeft" }

-- What a slot can show, and which unit data it follows.
M.choices.textContent = { { id = "none", label = "None" }, { id = "name", label = "Name" }, { id = "level", label = "Level" },
    { id = "levelName", label = "Level and Name" }, { id = "healthPercent", label = "Health Percent" },
    { id = "healthCurrent", label = "Health Current" }, { id = "healthBoth", label = "Health Current and Percent" },
    { id = "healthDeficit", label = "Health Deficit" }, { id = "powerPercent", label = "Power Percent" },
    { id = "powerCurrent", label = "Power Current" }, { id = "powerBoth", label = "Power Current and Percent" } }
M.contentKind = { name = "name", level = "name", levelName = "name", healthPercent = "health", healthCurrent = "health",
    healthBoth = "health", healthDeficit = "health", powerPercent = "power", powerCurrent = "power", powerBoth = "power" }
-- Default: names in the Name Color, the level muted, numbers in the Text Color.
M.choices.textColorMode = { { id = "default", label = "Default" }, { id = "custom", label = "Custom" },
    { id = "reaction", label = "Reaction" }, { id = "class", label = "Class Color" }, { id = "difficulty", label = "Level Difficulty" } }
-- Colors that follow the unit (owner, November 13, 2026), and the texts each
-- one suits: Reaction (hostile red, neutral yellow, friendly green, tapped
-- gray) and Class Color (players' class, others' reaction) for any text;
-- Level Difficulty (the game's color for a level against yours) for the level.
M.unitColorModes = { "reaction", "class", "difficulty" }
local ALL = { reaction = true, class = true }
local LEVEL = { reaction = true, class = true, difficulty = true }
function M.TextColorModeFits(content, mode)
    if mode == "default" or mode == "custom" then return true end
    if content == "none" then return false end
    return (content == "level" and LEVEL or ALL)[mode] == true
end
M.choices.textAlign = M.choices.position
M.textRanges = { size = { 6, 24, 1 }, x = { -100, 100, 1 }, y = { -100, 100, 1 } }
function M.TextChoices(slot)
    local choices = { content = "textContent", colorMode = "textColorMode" }
    if slot == "border" then choices.align = "textAlign" end
    return choices
end

-- The text settings of layout version 16 (one name, level, health and power
-- text, each placed by its own keys): kept to migrate saved frames, and the
-- slots' defaults are those defaults converted, so nothing moves.
local function Legacy(extra)
    local keys = { showName = true, namePosition = "border", nameAlign = "RIGHT", nameFontSize = 12, nameOffsetX = 0,
        nameOffsetY = 0, levelStyle = "badge", levelFontSize = 11, levelColor = Copy(M.palette.muted), levelOffsetX = 0,
        levelOffsetY = 0, levelPosition = "corner", healthText = "percent", healthTextPosition = "RIGHT", healthFontSize = 11,
        healthTextOffsetX = 0, healthTextOffsetY = 0, powerText = "none", powerTextPosition = "CENTER", powerFontSize = 9,
        powerTextOffsetX = 0, powerTextOffsetY = 0 }
    for key, value in pairs(extra or {}) do keys[key] = value end
    return keys
end
local SMALL = { nameFontSize = 11, healthFontSize = 10, levelStyle = "none", namePosition = "bar", nameAlign = "LEFT" }
M.legacyText = { player = Legacy(), target = Legacy(), targettarget = Legacy(SMALL), focus = Legacy(SMALL),
    focustarget = Legacy(SMALL) }

local SIDE_SLOT = { LEFT = "left", CENTER = "center", RIGHT = "right" }
local POWER_SLOT = { LEFT = "powerLeft", CENTER = "powerCenter", RIGHT = "powerRight" }
local HEALTH = { percent = "healthPercent", current = "healthCurrent", both = "healthBoth" }
local POWER = { percent = "powerPercent", current = "powerCurrent", both = "powerBoth" }
local OVERFLOW = { left = "topLeft", center = "top", right = "topRight", bottomLeft = "topLeft", bottomRight = "topRight" }
local function Whole(v, low, high, default)
    if not M.Number(v, low, high) then return default end
    return math.floor(v)
end
local function Color(c, default)
    if type(c) == "table" and M.Number(c[1], 0, 1) and M.Number(c[2], 0, 1) and M.Number(c[3], 0, 1) then return { c[1], c[2], c[3] } end
    return Copy(default)
end

-- Slots from version 16 text keys (`old` reads a frame's saved keys, falling
-- back to the defaults). Names Above Frame sit on the border, raised by the
-- distance between the two; a level Beside Health Text goes to the bottom
-- corner. A text whose spot is taken moves to that spot's top row.
function M.SlotsFromLegacy(unit, old)
    local text = M.palette.text
    local slots = {}
    for _, slot in ipairs(M.textSlots) do
        local size = slot == "border" and 12 or M.slotPlaces[slot].bar == "power" and 9 or 11
        slots[slot] = { content = "none", size = size, x = 0, y = 0, colorMode = "default", color = Copy(text) }
    end
    slots.border.align = "RIGHT"
    local function Put(slot, content, size, x, y, color)
        if slots[slot].content ~= "none" then slot = OVERFLOW[slot] end
        local s = slot and slots[slot]
        if not s or s.content ~= "none" then return end
        s.content, s.size = content, Whole(size, 6, 24, s.size)
        s.x, s.y = Whole(x, -100, 100, 0), Whole(y, -100, 100, 0)
        if color then s.colorMode, s.color = "custom", color end
    end
    local nameSize = Whole(old.nameFontSize, 6, 24, 12)
    if old.showName ~= false then
        local align = SIDE_SLOT[old.nameAlign] and old.nameAlign or "RIGHT"
        if old.namePosition == "bar" then
            Put(SIDE_SLOT[align], "name", nameSize, old.nameOffsetX, old.nameOffsetY)
        else
            local y = Whole(old.nameOffsetY, -100, 100, 0)
            if old.namePosition == "above" then y = math.min(100, y + 4 + math.floor(nameSize * 0.25 + 0.5)) end
            Put("border", "name", nameSize, old.nameOffsetX, y)
            slots.border.align = align
        end
    end
    if HEALTH[old.healthText] then
        Put(SIDE_SLOT[old.healthTextPosition] or "right", HEALTH[old.healthText], old.healthFontSize, old.healthTextOffsetX,
            old.healthTextOffsetY)
    end
    if old.levelStyle ~= "none" then
        local corner = old.portraitSide == "right" and "bottomRight" or "bottomLeft"
        local muted = M.palette.muted
        local c = Color(old.levelColor, muted)
        local custom = math.abs(c[1] - muted[1]) > 1e-6 or math.abs(c[2] - muted[2]) > 1e-6 or math.abs(c[3] - muted[3]) > 1e-6
        Put(corner, "level", old.levelFontSize, old.levelOffsetX, old.levelOffsetY, custom and c or nil)
    end
    if POWER[old.powerText] then
        Put(POWER_SLOT[old.powerTextPosition] or "powerCenter", POWER[old.powerText], old.powerFontSize, old.powerTextOffsetX,
            old.powerTextOffsetY)
    end
    for _, slot in ipairs(M.powerSlots) do
        if slots[slot].content == "none" then slots[slot].size = Whole(old.powerFontSize, 6, 24, 9) end
    end
    if slots.border.content == "none" then slots.border.size = nameSize end
    return slots
end

-- Each frame's default slots: its version 16 defaults, converted.
local defaults = {}
function M.TextDefaults(unit, slot)
    if not defaults[unit] then
        local old = setmetatable({}, { __index = function(_, key)
            local value = M.legacyText[unit][key]
            if value == nil then return M.frameDefaults[unit][key] end
            return value
        end })
        defaults[unit] = M.SlotsFromLegacy(unit, old)
    end
    return Copy(defaults[unit][slot])
end
