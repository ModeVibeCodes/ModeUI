local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Action Bars: Blizzard's own action buttons, moved onto ModeUI
-- bars in the Mode look. The buttons keep Blizzard's code, so actions,
-- paging, cooldowns, range and keybinds work as before; ModeUI owns where
-- each bar sits, how it's laid out, the button skin, the text and when the
-- bar shows. Every bar has its own settings. See docs/ACTION_BARS.md.
-- Files: Init (this), Migrations, Driver, Bars, Layout, Skin, Text, Fade,
-- Preview, Settings.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Action Bars"], category = "interface", defaultEnabled = false,
    configDescription = L["Action bars in the Mode look: layout, size, borders, text and when each bar shows."],
    modeLayout = { decorateOnly = true } }
addon.ActionBars = M
addon:RegisterModule("actionBars", M)

M.VERSION = 1
local P, onyx = Kit.palette, Kit.onyx
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- The bars, in sidebar order. `prefix` names Blizzard's buttons (prefix..1
-- to prefix..count); `blizzard` lists Blizzard bars whose art ModeUI hides.
M.bars = { "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8", "pet", "stance" }
M.barSpecs = {
    bar1 = { label = "Action Bar 1", prefix = "ActionButton", count = 12, blizzard = { "MainActionBar", "MainMenuBar" }, override = true },
    bar2 = { label = "Action Bar 2", prefix = "MultiBarBottomLeftButton", count = 12 },
    bar3 = { label = "Action Bar 3", prefix = "MultiBarBottomRightButton", count = 12 },
    bar4 = { label = "Action Bar 4", prefix = "MultiBarRightButton", count = 12 },
    bar5 = { label = "Action Bar 5", prefix = "MultiBarLeftButton", count = 12 },
    bar6 = { label = "Action Bar 6", prefix = "MultiBar5Button", count = 12 },
    bar7 = { label = "Action Bar 7", prefix = "MultiBar6Button", count = 12 },
    bar8 = { label = "Action Bar 8", prefix = "MultiBar7Button", count = 12 },
    pet = { label = "Pet Bar", prefix = "PetActionButton", count = 10, blizzard = { "PetActionBar" }, pet = true },
    stance = { label = "Stance Bar", prefix = "StanceButton", count = 10, blizzard = { "StanceBar" }, stance = true },
}
-- Edit Mode element (and saved position key) per bar.
M.elementIds = {}
for _, bar in ipairs(M.bars) do M.elementIds[bar] = "actionBars" .. bar:sub(1, 1):upper() .. bar:sub(2) end

-- Default places, pinned to a screen edge so they hold at any resolution.
local function At(point, x, y) return { target = "screen", placement = "center", point = point, relativePoint = point, x = x, y = y } end
M.defaultPositions = {
    bar1 = At("BOTTOM", 0, 16), bar2 = At("BOTTOM", 0, 58), bar3 = At("BOTTOM", 0, 100),
    bar4 = At("RIGHT", -8, 0), bar5 = At("RIGHT", -52, 0),
    bar6 = At("CENTER", 0, -120), bar7 = At("CENTER", 0, -162), bar8 = At("CENTER", 0, -204),
    pet = At("BOTTOM", 0, 142), stance = At("BOTTOM", 0, 184),
}

-- The texts on a button: the keybind, the stack or charge count, the macro
-- name and the cooldown numbers. Each has its own size, place and color.
M.textParts = { "hotkey", "count", "macro", "cooldown" }
M.textPartLabels = { hotkey = "Keybind", count = "Count", macro = "Macro Name", cooldown = "Cooldown" }

local function Part(prefix, show, size, anchor, color)
    return { [prefix .. "Show"] = show, [prefix .. "Size"] = size, [prefix .. "Anchor"] = anchor,
        [prefix .. "X"] = 0, [prefix .. "Y"] = 0, [prefix .. "Color"] = Copy(color) }
end

-- One bar's settings. Bars 4 and 5 stand upright at the right edge; 6 to 8
-- start hidden. Every button is 42 by 38 by default.
local function Style(bar)
    local spec = M.barSpecs[bar]
    local upright = bar == "bar4" or bar == "bar5"
    local style = {
        show = bar ~= "bar6" and bar ~= "bar7" and bar ~= "bar8",
        buttons = spec.count, perLine = spec.count, orientation = upright and "vertical" or "horizontal", start = "TOPLEFT",
        width = 42, height = 38, spacing = 2,
        border = "rounded", borderColor = Copy(onyx.border), showEmpty = true,
        visibility = "always", customVisibility = "[combat] show; hide", opacity = 100, fade = false, fadeOpacity = 0,
        font = "game", fontMedia = "Expressway", outline = true, shadow = true, liftedShadow = false, slug = true,
    }
    for key, value in pairs(Part("hotkey", true, 11, "TOPRIGHT", P.text)) do style[key] = value end
    for key, value in pairs(Part("count", true, 12, "BOTTOMRIGHT", P.text)) do style[key] = value end
    for key, value in pairs(Part("macro", false, 10, "BOTTOM", P.muted)) do style[key] = value end
    for key, value in pairs(Part("cooldown", true, 14, "CENTER", { 1, 1, 1 })) do style[key] = value end
    return style
end
M.styleDefaults = {}
for _, bar in ipairs(M.bars) do M.styleDefaults[bar] = Style(bar) end
M.defaults = { version = M.VERSION }
for _, bar in ipairs(M.bars) do M.defaults[bar] = Copy(M.styleDefaults[bar]) end

-- Keys Copy Style leaves alone: whether and when a bar shows, and how many
-- buttons it has in what shape.
M.identityKeys = { show = true, buttons = true, perLine = true, orientation = true, start = true,
    visibility = true, customVisibility = true }
M.colorKeys = { borderColor = true }
for _, part in ipairs(M.textParts) do M.colorKeys[part .. "Color"] = true end

M.ranges = { buttons = { 1, 12, 1 }, perLine = { 1, 12, 1 }, width = { 16, 80, 1 }, height = { 16, 80, 1 },
    spacing = { 0, 20, 1 }, opacity = { 10, 100, 5 }, fadeOpacity = { 0, 100, 5 } }
for _, part in ipairs(M.textParts) do
    M.ranges[part .. "Size"] = { 6, 32, 1 }
    M.ranges[part .. "X"] = { -40, 40, 1 }
    M.ranges[part .. "Y"] = { -40, 40, 1 }
end
M.MAX_CONDITIONS = 200

-- Text anchors on the button, read like a compass; Center is the middle.
M.anchors = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
M.anchorLabels = { TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right", LEFT = "Left", CENTER = "Center",
    RIGHT = "Right", BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right" }
M.choices = {
    orientation = { { id = "horizontal", label = "Rows" }, { id = "vertical", label = "Columns" } },
    start = { { id = "TOPLEFT", label = "Top Left" }, { id = "TOPRIGHT", label = "Top Right" },
        { id = "BOTTOMLEFT", label = "Bottom Left" }, { id = "BOTTOMRIGHT", label = "Bottom Right" } },
    border = { { id = "rounded", label = "Rounded" }, { id = "square", label = "Square" }, { id = "none", label = "None" } },
    visibility = { { id = "always", label = "Always" }, { id = "combat", label = "In Combat" },
        { id = "noCombat", label = "Out of Combat" }, { id = "target", label = "In Combat or With a Target" },
        { id = "custom", label = "Custom" } },
}
for _, part in ipairs(M.textParts) do M.choices[part .. "Anchor"] = M.anchors end
