local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Cooldown Manager: Blizzard's own Cooldown Manager (Essential
-- and Utility cooldowns, Tracked Buffs and Tracked Bars) in the Mode look.
-- Blizzard still decides which spells are tracked (its Cooldown Settings)
-- and keeps every icon's cooldown, charges, auras and procs up to date;
-- ModeUI places each viewer with its Edit Mode, lays the icons out, skins
-- them, styles their text, draws the glows and decides when each viewer
-- shows. Every viewer has its own settings, and each spell in it can be
-- hidden or have its glows switched off. See docs/COOLDOWN_MANAGER.md.
-- Files: Init (this), Migrations, Driver, Blizzard, Layout, Skin, Bars, Text,
-- Glow, Visibility, SpellMenu, Preview, Settings.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Cooldown Manager"], category = "interface", defaultEnabled = false,
    configDescription = L["Blizzard's Cooldown Manager in the Mode look: placement, layout, borders, text, glows and per-spell options."],
    modeLayout = { decorateOnly = true } }
addon.CooldownManager = M
-- The ID is also the saved-settings key; never change it once released.
addon:RegisterModule("cooldownManager", M)

M.VERSION = 1
local P = Kit.palette
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- The viewers, in sidebar order. `bar` marks Tracked Bars (a bar beside each
-- icon); `buff` the viewers that show auras rather than cooldowns.
M.viewers = { "essential", "utility", "buffIcon", "buffBar" }
M.viewerSpecs = {
    essential = { label = "Essential Cooldowns" },
    utility = { label = "Utility Cooldowns" },
    buffIcon = { label = "Tracked Buffs", buff = true },
    buffBar = { label = "Tracked Bars", buff = true, bar = true },
}
function M:IsBar(viewer) return self.viewerSpecs[viewer] ~= nil and self.viewerSpecs[viewer].bar == true end
function M:IsBuff(viewer) return self.viewerSpecs[viewer] ~= nil and self.viewerSpecs[viewer].buff == true end

-- Edit Mode element (and saved position key) and frame name per viewer.
M.elementIds, M.frameNames = {}, {}
for _, viewer in ipairs(M.viewers) do
    local name = viewer:sub(1, 1):upper() .. viewer:sub(2)
    M.elementIds[viewer] = "cooldownManager" .. name
    M.frameNames[viewer] = "ModeUICooldown" .. name
end
-- Every viewer can anchor to the others, the screen and the game's frames.
local BASE_TARGETS = { "screen", "player", "target", "focus", "minimap", "party" }
M.allowedTargets = {}
for index, viewer in ipairs(M.viewers) do
    local allowed = Copy(BASE_TARGETS)
    for other, otherViewer in ipairs(M.viewers) do
        if other ~= index then allowed[#allowed + 1] = M.elementIds[otherViewer] end
    end
    M.allowedTargets[viewer] = allowed
    addon.Positioning:AddTarget(M.elementIds[viewer], L[M.viewerSpecs[viewer].label], M.frameNames[viewer])
end

-- Default places, near Blizzard's own: Essential above the middle of the
-- action bars, Utility under it, Tracked Buffs on top; Tracked Bars to the
-- right, growing upward.
local function At(point, x, y) return { target = "screen", placement = "center", point = point, relativePoint = point, x = x, y = y } end
M.defaultPositions = {
    essential = At("BOTTOM", 0, 300),
    utility = { target = M.elementIds.essential, placement = "below", x = 0, y = -4 },
    buffIcon = { target = M.elementIds.essential, placement = "above", x = 0, y = 4 },
    buffBar = At("BOTTOM", 330, 300),
}

-- The texts. Icons show the cooldown numbers and a count (charges, or an
-- aura's stacks); bars show the spell's name, the time left and the stacks.
M.textParts = { "cooldown", "count", "name", "duration" }
M.textPartLabels = { cooldown = "Cooldown", count = "Count", name = "Name", duration = "Duration" }
M.iconParts, M.barParts = { "cooldown", "count" }, { "name", "duration", "count" }
function M:Parts(viewer) return self:IsBar(viewer) and self.barParts or self.iconParts end

-- Colors: the Action Bars look (a #101010 border around a #040404 background
-- at 75%), amber cooldown numbers, a dark swipe; proc glows gold and the
-- ready glow Mode cyan; bars in Mode cyan over Mode Slate.
M.BORDER_COLOR, M.BACKGROUND_COLOR, M.BACKGROUND_OPACITY = Kit.RGB(16, 16, 16), Kit.RGB(4, 4, 4), 75
M.COOLDOWN_COLOR, M.SWIPE_COLOR = Copy(P.cooldown), Kit.RGB(0, 0, 0)
M.PROC_COLOR, M.READY_COLOR = Kit.RGB(255, 210, 90), Copy(P.accent)
M.BAR_COLOR = Copy(P.accent)
local function Part(prefix, show, size, anchor, color)
    return { [prefix .. "Show"] = show, [prefix .. "Size"] = size, [prefix .. "Anchor"] = anchor,
        [prefix .. "X"] = 0, [prefix .. "Y"] = 0, [prefix .. "Color"] = Copy(color) }
end

-- One viewer's settings. Essential icons are the action buttons' 42 by 36;
-- Utility and Tracked Buffs smaller; Tracked Bars 220 by 22. Rows are
-- centered. Tracked Buffs and Bars grow upward from their place.
local SIZES = { essential = { 42, 36 }, utility = { 35, 30 }, buffIcon = { 35, 30 }, buffBar = { 220, 22 } }
local function Style(viewer)
    local bar, size = viewer == "buffBar", SIZES[viewer]
    local style = {
        show = true,
        perLine = bar and 1 or 12, orientation = "horizontal", start = M:IsBuff(viewer) and "BOTTOMLEFT" or "TOPLEFT",
        center = true, width = size[1], height = size[2], spacing = 2,
        border = "rounded", borderSize = 2, borderColor = Copy(M.BORDER_COLOR),
        backgroundColor = Copy(M.BACKGROUND_COLOR), backgroundOpacity = M.BACKGROUND_OPACITY,
        -- The cooldown: a flat swipe in Swipe Color at Swipe Opacity; Edge is
        -- the bright line on its rim, Ready Flash Blizzard's flash as it ends.
        swipeColor = Copy(M.SWIPE_COLOR), swipeOpacity = 70, showEdge = false, showBling = true, showFlash = true,
        rangeTint = true, debuffBorder = false,
        font = "game", fontMedia = "Expressway", outline = true, shadow = true, slug = true,
        procGlow = "mode", procColor = Copy(M.PROC_COLOR), procPulse = true,
        readyGlow = false, readyStyle = "glow", readyColor = Copy(M.READY_COLOR), readyDuration = 2,
        visibility = "always", opacity = 100, fadeOpacity = 0,
        -- Tracked Bars: the bar's texture and color, its background, the icon's side and the spark.
        barTexture = "mode", barColor = Copy(M.BAR_COLOR), barBackground = "slate", barBackgroundOpacity = 70,
        iconSide = "left", showSpark = false,
        -- Spells with their own switches, by cooldown ID: { ["1234"] = { hide = true, proc = false, ready = false } }.
        spells = {},
    }
    local small = viewer ~= "essential"
    for key, value in pairs(Part("cooldown", true, small and 12 or 15, "CENTER", M.COOLDOWN_COLOR)) do style[key] = value end
    for key, value in pairs(Part("count", true, small and 10 or 12, "BOTTOMRIGHT", P.text)) do style[key] = value end
    for key, value in pairs(Part("name", true, 11, "LEFT", P.text)) do style[key] = value end
    for key, value in pairs(Part("duration", true, 11, "RIGHT", P.text)) do style[key] = value end
    return style
end
M.styleDefaults = {}
for _, viewer in ipairs(M.viewers) do M.styleDefaults[viewer] = Style(viewer) end
M.defaults = { version = M.VERSION }
for _, viewer in ipairs(M.viewers) do M.defaults[viewer] = Copy(M.styleDefaults[viewer]) end

-- Keys Copy Style leaves alone: whether and when a viewer shows, its shape,
-- and its spells' switches.
M.identityKeys = { show = true, perLine = true, orientation = true, start = true, width = true, height = true,
    visibility = true, spells = true }
M.colorKeys = { borderColor = true, backgroundColor = true, swipeColor = true, procColor = true, readyColor = true, barColor = true }
for _, part in ipairs(M.textParts) do M.colorKeys[part .. "Color"] = true end

M.ranges = { perLine = { 1, 20, 1 }, spacing = { 0, 20, 1 },
    borderSize = { 1, 4, 1 }, backgroundOpacity = { 0, 100, 5 }, swipeOpacity = { 0, 100, 5 }, readyDuration = { 1, 10, 1 },
    opacity = { 10, 100, 5 }, fadeOpacity = { 0, 100, 5 }, barBackgroundOpacity = { 0, 100, 5 } }
for _, part in ipairs(M.textParts) do
    M.ranges[part .. "Size"] = { 6, 32, 1 }
    M.ranges[part .. "X"] = { -40, 40, 1 }
    M.ranges[part .. "Y"] = { -40, 40, 1 }
end
-- Width and height per kind: icons are small, bars long and thin.
M.sizeRanges = { icon = { width = { 16, 80, 1 }, height = { 16, 80, 1 } }, bar = { width = { 60, 400, 2 }, height = { 8, 40, 1 } } }
function M:SizeRange(viewer, key) return self.sizeRanges[self:IsBar(viewer) and "bar" or "icon"][key] end

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
    visibility = { { id = "always", label = "Always" }, { id = "combat", label = "In Combat" }, { id = "noCombat", label = "Out of Combat" },
        { id = "target", label = "In Combat or With a Target" }, { id = "mouseover", label = "Mouseover" }, { id = "hidden", label = "Hidden" } },
    iconSide = { { id = "left", label = "Left" }, { id = "right", label = "Right" } },
}
for _, part in ipairs(M.textParts) do M.choices[part .. "Anchor"] = M.anchors end
-- Per-spell switches, and the value each stores while it differs from the viewer.
M.spellKinds = { hide = true, proc = false, ready = false }
