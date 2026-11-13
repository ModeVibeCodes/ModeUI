local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Action Bars: Blizzard's own action buttons, moved onto ModeUI
-- bars in the Mode look. The buttons keep Blizzard's code, so actions,
-- paging, cooldowns, range and keybinds work as before; ModeUI owns where
-- each bar sits, how it's laid out, the button skin, the text and when the
-- bar shows. Every bar has its own settings. See docs/ACTION_BARS.md.
-- Files: Init (this), Migrations, Driver, Layout, Skin, Text, Bars, Visibility,
-- Keybind, Glow, GlowMenu, Preview, Settings.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Action Bars"], category = "interface", defaultEnabled = false,
    configDescription = L["Action bars in the Mode look: layout, size, borders, text and when each bar shows."],
    modeLayout = { decorateOnly = true } }
addon.ActionBars = M
addon:RegisterModule("actionBars", M)

-- Version 2: buttons 42 by 36; Background Opacity; Show gains Mouseover and
-- Hidden (Mouseover replaces the Fade Until Mouseover switch); amber
-- cooldown numbers; bars stack on each other by default.
-- Version 3: the border is a hollow frame (it no longer tints a see-through
-- background), 2px by default (Border Size) in #404542; Background Color
-- (#040404); macro names #69A5B9; 1px spacing.
-- Version 4: every bar's border becomes #101010 and its Background Opacity
-- 75% (the owner asked for all bars); Blizzard's empty buttons use Background
-- Opacity too; paging (Page Switching, Page Conditions) and glows (proc glow,
-- ready glow, icon opacity on cooldown).
-- Version 5: icons desaturate on cooldown (Desaturate Icon); keybinds 2px
-- smaller and shortened ("sE" for Shift-E); per-button glow switches.
M.VERSION = 5
local P = Kit.palette
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
-- Edit Mode element (and saved position key) per bar, and the frame names:
-- the secure bar and its Edit Mode stand-in ("Mover").
M.elementIds, M.frameNames = {}, {}
for _, bar in ipairs(M.bars) do
    M.elementIds[bar] = "actionBars" .. bar:sub(1, 1):upper() .. bar:sub(2)
    local spec = M.barSpecs[bar]
    M.frameNames[bar] = spec.pet and "ModeUIPetBar" or spec.stance and "ModeUIStanceBar" or "ModeUIActionBar" .. bar:sub(4)
end
-- Every bar can be anchored to any other bar through its stand-in, as well
-- as to the screen and the game's frames. Loops are refused when an anchor is
-- chosen (PositionManager:WouldLoop), not by list order.
local BASE_TARGETS = { "screen", "player", "target", "focus", "minimap", "party" }
M.allowedTargets = {}
for index, bar in ipairs(M.bars) do
    local allowed = Copy(BASE_TARGETS)
    for other, otherBar in ipairs(M.bars) do
        if other ~= index then allowed[#allowed + 1] = M.elementIds[otherBar] end
    end
    M.allowedTargets[bar] = allowed
    addon.Positioning:AddTarget(M.elementIds[bar], L[M.barSpecs[bar].label], M.frameNames[bar] .. "Mover")
end

-- Default places: Action Bar 1 pinned to the bottom of the screen with 2, 3,
-- the pet bar and the stance bar stacked on it; 4 on the right edge with 5
-- beside it; 6 to 8 (hidden) near the middle.
local function At(point, x, y) return { target = "screen", placement = "center", point = point, relativePoint = point, x = x, y = y } end
local function On(bar, placement, x, y) return { target = M.elementIds[bar], placement = placement, x = x, y = y } end
M.defaultPositions = {
    bar1 = At("BOTTOM", 0, 16), bar2 = On("bar1", "above", 0, 4), bar3 = On("bar2", "above", 0, 4),
    bar4 = At("RIGHT", -8, 0), bar5 = On("bar4", "left", -4, 0),
    bar6 = At("CENTER", 0, -120), bar7 = At("CENTER", 0, -162), bar8 = At("CENTER", 0, -204),
    pet = On("bar3", "above", 0, 4), stance = On("pet", "above", 0, 4),
}
-- Version 1's defaults; a saved place still equal to one moves to the new default.
M.oldDefaultPositions = { bar2 = At("BOTTOM", 0, 58), bar3 = At("BOTTOM", 0, 100), bar5 = At("RIGHT", -52, 0),
    pet = At("BOTTOM", 0, 142), stance = At("BOTTOM", 0, 184) }

-- The texts on a button: the keybind, the stack or charge count, the macro
-- name and the cooldown numbers. Each has its own size, place and color.
M.textParts = { "hotkey", "count", "macro", "cooldown" }
M.textPartLabels = { hotkey = "Keybind", count = "Count", macro = "Macro Name", cooldown = "Cooldown" }

-- Cooldown numbers are amber (#FFB12F) by default.
M.COOLDOWN_COLOR = Kit.RGB(255, 177, 47)
-- The border (#404542), the background inside it (#040404) and macro names (#69A5B9).
M.BORDER_COLOR, M.BACKGROUND_COLOR, M.MACRO_COLOR = Kit.RGB(16, 16, 16), Kit.RGB(4, 4, 4), Kit.RGB(105, 165, 185)
M.BACKGROUND_OPACITY = 75
-- Proc glows are gold by default; the ready glow is the Mode cyan.
M.PROC_COLOR, M.READY_COLOR = Kit.RGB(255, 210, 90), Kit.palette.accent
local function Part(prefix, show, size, anchor, color)
    return { [prefix .. "Show"] = show, [prefix .. "Size"] = size, [prefix .. "Anchor"] = anchor,
        [prefix .. "X"] = 0, [prefix .. "Y"] = 0, [prefix .. "Color"] = Copy(color) }
end

-- One bar's settings. Bars 4 and 5 stand upright at the right edge; 6 to 8
-- start hidden. Every button is 42 by 36 by default.
local function Style(bar)
    local spec = M.barSpecs[bar]
    local upright = bar == "bar4" or bar == "bar5"
    local style = {
        show = bar ~= "bar6" and bar ~= "bar7" and bar ~= "bar8",
        buttons = spec.count, perLine = spec.count, orientation = upright and "vertical" or "horizontal", start = "TOPLEFT",
        width = 42, height = 36, spacing = 1,
        border = "rounded", borderSize = 2, borderColor = Copy(M.BORDER_COLOR),
        backgroundColor = Copy(M.BACKGROUND_COLOR), showEmpty = true, backgroundOpacity = M.BACKGROUND_OPACITY,
        visibility = "always", customVisibility = "[combat] show; hide", opacity = 100, fadeOpacity = 0,
        font = "game", fontMedia = "Expressway", outline = true, shadow = true, liftedShadow = false, slug = true,
        -- Paging: Action Bar 1 follows the game's own paging (stances, forms,
        -- vehicles, page keys) unless it has Page Conditions; other bars keep
        -- their page until Page Switching is on.
        paging = bar == "bar1", pageConditions = bar == "bar1" and "" or "[mod:shift] 2; [mod:ctrl] 3; [mod:alt] 4",
        procGlow = "mode", procColor = Copy(M.PROC_COLOR), procPulse = true,
        readyGlow = true, readyStyle = "glow", readyColor = Copy(M.READY_COLOR), readyDuration = 2, cooldownOpacity = 100,
        cooldownDesaturate = true, hotkeyShort = true,
        -- Buttons whose proc glow or ready glow is off, by place: { ["3"] = { ready = false } }.
        buttonGlows = {},
    }
    for key, value in pairs(Part("hotkey", true, 9, "TOPRIGHT", P.text)) do style[key] = value end
    for key, value in pairs(Part("count", true, 12, "BOTTOMRIGHT", P.text)) do style[key] = value end
    for key, value in pairs(Part("macro", false, 10, "BOTTOM", M.MACRO_COLOR)) do style[key] = value end
    for key, value in pairs(Part("cooldown", true, 14, "CENTER", M.COOLDOWN_COLOR)) do style[key] = value end
    return style
end
M.styleDefaults = {}
for _, bar in ipairs(M.bars) do M.styleDefaults[bar] = Style(bar) end
M.defaults = { version = M.VERSION }
for _, bar in ipairs(M.bars) do M.defaults[bar] = Copy(M.styleDefaults[bar]) end

-- Keys Copy Style leaves alone: whether and when a bar shows, and how many
-- buttons it has in what shape.
M.identityKeys = { show = true, buttons = true, perLine = true, orientation = true, start = true,
    visibility = true, customVisibility = true, buttonGlows = true, paging = true, pageConditions = true }
M.colorKeys = { borderColor = true, backgroundColor = true, procColor = true, readyColor = true }
for _, part in ipairs(M.textParts) do M.colorKeys[part .. "Color"] = true end

M.ranges = { buttons = { 1, 12, 1 }, perLine = { 1, 12, 1 }, width = { 16, 80, 1 }, height = { 16, 80, 1 },
    spacing = { 0, 20, 1 }, opacity = { 10, 100, 5 }, fadeOpacity = { 0, 100, 5 }, backgroundOpacity = { 0, 100, 5 }, borderSize = { 1, 4, 1 },
    readyDuration = { 1, 10, 1 }, cooldownOpacity = { 20, 100, 5 } }
for _, part in ipairs(M.textParts) do
    M.ranges[part .. "Size"] = { 6, 32, 1 }
    M.ranges[part .. "X"] = { -40, 40, 1 }
    M.ranges[part .. "Y"] = { -40, 40, 1 }
end
M.MAX_CONDITIONS = 200
-- Each bar's own page (Blizzard's actionpage for its buttons); paging shows
-- other pages on the same buttons. The pet and stance bars don't page.
M.pages = { bar1 = 1, bar2 = 6, bar3 = 5, bar4 = 3, bar5 = 4, bar6 = 13, bar7 = 14, bar8 = 15 }

-- Text anchors on the button, read like a compass; Center is the middle.
M.anchors = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
M.anchorLabels = { TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right", LEFT = "Left", CENTER = "Center",
    RIGHT = "Right", BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right" }
M.choices = {
    orientation = { { id = "horizontal", label = "Rows" }, { id = "vertical", label = "Columns" } },
    start = { { id = "TOPLEFT", label = "Top Left" }, { id = "TOPRIGHT", label = "Top Right" },
        { id = "BOTTOMLEFT", label = "Bottom Left" }, { id = "BOTTOMRIGHT", label = "Bottom Right" } },
    border = { { id = "rounded", label = "Rounded" }, { id = "square", label = "Square" }, { id = "none", label = "None" } },
    procGlow = { { id = "mode", label = "Mode Glow" }, { id = "border", label = "Border" }, { id = "blizzard", label = "Blizzard" },
        { id = "none", label = "None" } },
    readyStyle = { { id = "glow", label = "Glow" }, { id = "border", label = "Border" } },
    visibility = { { id = "always", label = "Always" }, { id = "mouseover", label = "Mouseover" }, { id = "hidden", label = "Hidden" },
        { id = "combat", label = "In Combat" }, { id = "noCombat", label = "Out of Combat" },
        { id = "target", label = "In Combat or With a Target" }, { id = "custom", label = "Custom" } },
}
for _, part in ipairs(M.textParts) do M.choices[part .. "Anchor"] = M.anchors end
