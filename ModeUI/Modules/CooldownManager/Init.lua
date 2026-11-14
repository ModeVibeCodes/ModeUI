local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Cooldown Manager: Blizzard's own Cooldown Manager (Essential and Utility
-- cooldowns, Tracked Buffs and Tracked Bars) in the Mode look, with custom
-- bars of your own. It has its own window, opened with /mcdm, and stays out
-- of ModeUI's settings window (a standalone module). Blizzard still decides
-- which spells are tracked (its Cooldown Settings) and keeps every icon's
-- cooldown, charges, auras and procs up to date; ModeUI places each bar with
-- its Edit Mode, lays the icons out, skins them, styles their text, draws
-- the glows and decides when each bar shows. Custom bars house tracked
-- spells taken out of Blizzard's viewers. See docs/COOLDOWN_MANAGER.md.
-- Resource Bars (your health, power, a Druid's mana in forms and combo
-- points) live here too, in the same window: see ResourceInit.lua.
-- Files: Init (this), ResourceInit, Migrations, Driver, Custom, Spells,
-- Items, Racials, Blizzard, Layout, Skin, Bars, Text, Glow, Visibility, Resources,
-- ResourceUpdate, SpellMenu, GlowPopout, TextPopout, Picker, Preview,
-- ResourcePreview, Settings, SettingsTabs, ResourceSettings, Window.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Cooldown Manager"], standalone = true, defaultEnabled = false,
    configDescription = L["Blizzard's Cooldown Manager in the Mode look, with custom bars of your own."],
    modeLayout = { decorateOnly = true } }
addon.CooldownManager = M
-- The ID is also the saved-settings key; never change it once released.
addon:RegisterModule("cooldownManager", M)

-- Version 2: one Growth choice (and which way new lines go) replaces Lines,
-- First Icon and Center Lines; Desaturate on Cooldown; active, off-cooldown
-- and buff glows beside the proc glow; custom bars.
-- Version 3: every bar takes the ModeUI border (the owner asked for it on
-- the cooldown bars, November 13, 2026).
-- Version 4 (owner, November 13, 2026): icons 8px wider than tall by
-- default (42 by 34; 36 by 28 on the smaller bars), and anchored bars sit 1
-- physical pixel apart (gapPixels) instead of 4; glows start off on every
-- spell (each switched on in its menu, with its own look).
M.VERSION = 4
M.SLASH = "/mcdm"
local P = Kit.palette
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Blizzard's viewers, in list order. `bar` marks Tracked Bars (a bar beside
-- each icon); `buff` the viewers that show auras rather than cooldowns.
M.viewers = { "essential", "utility", "buffIcon", "buffBar" }
M.viewerSpecs = {
    essential = { label = "Essential Cooldowns" },
    utility = { label = "Utility Cooldowns" },
    buffIcon = { label = "Tracked Buffs", buff = true },
    buffBar = { label = "Tracked Bars", buff = true, bar = true },
}
-- Custom bars: Cooldown Bars take spells from Essential and Utility, Buff
-- Bars from Tracked Buffs. IDs are "custom1", "custom2"...; never reused.
M.customKinds = {
    cooldown = { label = "Cooldown Bar", sources = { "essential", "utility" } },
    buff = { label = "Buff Bar", sources = { "buffIcon" }, buff = true },
}
-- Essential and Utility take spells too (owner, November 14, 2026): from
-- each other or a custom bar, by Spell ID and items; the viewers each
-- takes spells from, its own first.
M.entryViewers = { essential = { "essential", "utility" }, utility = { "utility", "essential" } }
M.MAX_CUSTOM, M.MAX_ENTRIES, M.MAX_NAME = 10, 40, 32

-- Element (and saved position) IDs and frame names.
local function Capital(id) return id:sub(1, 1):upper() .. id:sub(2) end
function M.ElementId(id) return "cooldownManager" .. Capital(id) end
function M.FrameName(id) return "ModeUICooldown" .. Capital(id) end
-- Blizzard's viewers anchor to each other, the screen and the game's frames;
-- custom bars to those and the viewers.
local BASE_TARGETS = { "screen", "player", "target", "focus", "minimap", "party" }
M.BASE_TARGETS = BASE_TARGETS
M.allowedTargets = {}
for index, viewer in ipairs(M.viewers) do
    local allowed = Copy(BASE_TARGETS)
    for other, otherViewer in ipairs(M.viewers) do
        if other ~= index then allowed[#allowed + 1] = M.ElementId(otherViewer) end
    end
    M.allowedTargets[viewer] = allowed
    addon.Positioning:AddTarget(M.ElementId(viewer), L[M.viewerSpecs[viewer].label], M.FrameName(viewer))
end
M.customTargets = Copy(BASE_TARGETS)
for _, viewer in ipairs(M.viewers) do M.customTargets[#M.customTargets + 1] = M.ElementId(viewer) end

-- Default places, near Blizzard's own: Essential above the middle of the
-- action bars, Utility under it, Tracked Buffs on top; Tracked Bars to the
-- right. New custom bars start in the middle of the screen.
local function At(point, x, y) return { target = "screen", placement = "center", point = point, relativePoint = point, x = x, y = y } end
M.defaultPositions = {
    essential = At("BOTTOM", 0, 300),
    utility = { target = M.ElementId("essential"), placement = "below", x = 0, y = 0 },
    buffIcon = { target = M.ElementId("essential"), placement = "above", x = 0, y = 0 },
    buffBar = At("BOTTOM", 330, 300),
}
function M.CustomPosition(index) return At("CENTER", 0, 120 - 48 * ((index - 1) % 6)) end

-- The texts. Icons show the cooldown numbers and a count (charges, or an
-- aura's stacks); bars show the spell's name, the time left and the stacks.
M.textParts = { "cooldown", "count", "name", "duration" }
M.textPartLabels = { cooldown = "Cooldown", count = "Count", name = "Name", duration = "Duration" }
M.iconParts, M.barParts = { "cooldown", "count" }, { "name", "duration", "count" }

-- The glows: Proc (the game lighting a spell up), Active (the spell's effect
-- is up, which Blizzard shows with its gold swipe), Off Cooldown (a flash
-- when it's ready, or a glow for as long as it is) and Buff (a tracked buff
-- is up). Cooldown icons have the first three, buff icons the last.
M.glowKinds = { "proc", "active", "ready", "buff" }
M.glowLabels = { proc = "Proc Glow", active = "Active Glow", ready = "Off Cooldown Glow", buff = "Buff Glow" }
M.cooldownGlows, M.buffGlows = { "proc", "active", "ready" }, { "buff" }

-- Colors: the ModeUI border (Kit.BORDER_COLOR) around the Action Bars'
-- background (#040404 at 75%; Rounded and Square borders were #101010), amber cooldown numbers, a dark swipe; procs gold, active and
-- buff glows green, the off-cooldown glow Mode cyan; bars Mode cyan over
-- Mode Slate.
M.BORDER_COLOR, M.OLD_BORDER_COLOR = Kit.BORDER_COLOR, Kit.RGB(16, 16, 16)
M.BACKGROUND_COLOR, M.BACKGROUND_OPACITY = Kit.RGB(4, 4, 4), 75
M.COOLDOWN_COLOR, M.SWIPE_COLOR = Copy(P.cooldown), Kit.RGB(0, 0, 0)
M.GLOW_COLORS = { proc = Kit.RGB(255, 210, 90), active = Copy(P.green), ready = Copy(P.accent), buff = Copy(P.green) }
M.BAR_COLOR = Copy(P.accent)
local function Part(prefix, show, size, anchor, color)
    return { [prefix .. "Show"] = show, [prefix .. "Size"] = size, [prefix .. "Anchor"] = anchor,
        [prefix .. "X"] = 0, [prefix .. "Y"] = 0, [prefix .. "Color"] = Copy(color) }
end

-- One bar's settings. Essential icons are the action buttons' 42 by 36;
-- Utility and Tracked Buffs smaller; Tracked Bars 220 by 22. Lines are
-- centered; Tracked Buffs and Bars add new lines upward.
local function Style(size, perLine, lineGrowth, small)
    local style = {
        show = true,
        perLine = perLine, grow = "centerH", lineGrowth = lineGrowth,
        width = size[1], height = size[2], spacing = 2,
        -- Match Width / Match Height (Edit Mode): the size of what it hangs from.
        matchWidth = false, matchHeight = false,
        border = "mode", borderSize = 2, borderColor = Copy(M.BORDER_COLOR),
        backgroundColor = Copy(M.BACKGROUND_COLOR), backgroundOpacity = M.BACKGROUND_OPACITY,
        -- The cooldown: icons go gray while a spell cools down; a flat swipe
        -- in Swipe Color at Swipe Opacity; Edge is the bright line on its
        -- rim, Ready Flash Blizzard's flash as it ends.
        desaturate = true, swipeColor = Copy(M.SWIPE_COLOR), swipeOpacity = 70, showEdge = false, showBling = true, showFlash = true,
        rangeTint = true, debuffBorder = false,
        font = "game", fontMedia = "Expressway", outline = true, shadow = true, slug = true,
        -- Glows start off on every spell (owner, November 13, 2026); a spell's
        -- menu switches one on, starting from these looks.
        procGlow = "blizzard", activeGlow = "border", readyGlow = "pixel", buffGlow = "mode",
        procPulse = false, activePulse = false, readyPulse = true, buffPulse = false,
        readyMode = "flash", readyDuration = 2, glowLines = 8, glowThickness = 2,
        -- While a spell's effect is up, Blizzard swaps its cooldown for the
        -- effect's time in a full-color gold swipe; off (the default), the
        -- icon keeps showing its cooldown, gray.
        auraSwipe = false,
        visibility = "always", opacity = 100, fadeOpacity = 0,
        -- Tracked Bars: the bar's texture and color, its background, the icon's side and the spark.
        barTexture = "mode", barColor = Copy(M.BAR_COLOR), barBackground = "slate", barBackgroundOpacity = 70,
        iconSide = "left", showSpark = false,
        -- Spells with their own switches, by cooldown ID: { ["1234"] = { hide = true, proc = false } }.
        spells = {},
    }
    for _, kind in ipairs(M.glowKinds) do style[kind .. "Color"] = Copy(M.GLOW_COLORS[kind]) end
    for key, value in pairs(Part("cooldown", true, small and 12 or 15, "CENTER", M.COOLDOWN_COLOR)) do style[key] = value end
    for key, value in pairs(Part("count", true, small and 10 or 12, "BOTTOMRIGHT", P.text)) do style[key] = value end
    for key, value in pairs(Part("name", true, 11, "LEFT", P.text)) do style[key] = value end
    for key, value in pairs(Part("duration", true, 11, "RIGHT", P.text)) do style[key] = value end
    return style
end
M.styleDefaults = {
    essential = Style({ 42, 34 }, 12, "down"), utility = Style({ 36, 28 }, 12, "down", true),
    buffIcon = Style({ 36, 28 }, 12, "up", true), buffBar = Style({ 220, 22 }, 1, "up", true),
}
M.customDefaults = { cooldown = Style({ 42, 34 }, 8, "down"), buff = Style({ 36, 28 }, 8, "up", true) }
-- Version 3's default sizes, which move to version 4's (sizes chosen by hand stay).
M.oldSizes = { essential = { 42, 36 }, utility = { 35, 30 }, buffIcon = { 35, 30 }, cooldown = { 42, 36 }, buff = { 35, 30 } }
-- extras: the spells Essential and Utility took themselves (Custom.lua).
-- order: a viewer's spell order once you move one (Custom.lua).
-- racials: the bar your racial abilities show on (Racials.lua).
M.defaults = { version = M.VERSION, customBars = {}, nextCustom = 1, extras = { essential = {}, utility = {} }, order = {}, racials = "utility" }
M.MAX_ORDER = 200
for _, viewer in ipairs(M.viewers) do M.defaults[viewer] = Copy(M.styleDefaults[viewer]) end

-- Keys Copy Style leaves alone: whether and when a bar shows, its shape,
-- and its spells' switches.
M.identityKeys = { show = true, perLine = true, grow = true, lineGrowth = true, width = true, height = true,
    matchWidth = true, matchHeight = true,
    visibility = true, spells = true }
M.colorKeys = { borderColor = true, backgroundColor = true, swipeColor = true, barColor = true }
for _, kind in ipairs(M.glowKinds) do M.colorKeys[kind .. "Color"] = true end
for _, part in ipairs(M.textParts) do M.colorKeys[part .. "Color"] = true end

M.ranges = { perLine = { 1, 20, 1 }, spacing = { 0, 20, 1 }, glowLines = { 2, 16, 1 }, glowThickness = { 1, 4, 1 },
    borderSize = { 1, 4, 1 }, backgroundOpacity = { 0, 100, 5 }, swipeOpacity = { 0, 100, 5 }, readyDuration = { 1, 10, 1 },
    opacity = { 10, 100, 5 }, fadeOpacity = { 0, 100, 5 }, barBackgroundOpacity = { 0, 100, 5 } }
for _, part in ipairs(M.textParts) do
    M.ranges[part .. "Size"] = { 6, 32, 1 }
    M.ranges[part .. "X"] = { -40, 40, 1 }
    M.ranges[part .. "Y"] = { -40, 40, 1 }
end
-- Width and height per kind: icons are small, bars long and thin.
M.sizeRanges = { icon = { width = { 16, 80, 1 }, height = { 16, 80, 1 } }, bar = { width = { 60, 400, 2 }, height = { 8, 40, 1 } } }

-- Growth: centered rows or columns, or from one side. Rows add new lines
-- down or up, columns right or left.
M.horizontalGrowth = { centerH = true, right = true, left = true }
M.lineChoices = { horizontal = { "down", "up" }, vertical = { "right", "left" } }
function M.LinesFor(grow) return M.horizontalGrowth[grow] and M.lineChoices.horizontal or M.lineChoices.vertical end

M.anchors = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
M.anchorLabels = { TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right", LEFT = "Left", CENTER = "Center",
    RIGHT = "Right", BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right" }
-- Glow looks: Mode Glow (soft), Border, Pixel (marching lines), Blizzard
-- (the action bar proc loop) and GCD (the Assisted Combat ants).
local GLOW_STYLES = { { id = "mode", label = "Mode Glow" }, { id = "border", label = "Border" }, { id = "pixel", label = "Pixel" },
    { id = "blizzard", label = "Blizzard" }, { id = "gcd", label = "GCD" } }
M.glowStyles = GLOW_STYLES
M.choices = {
    grow = { { id = "centerH", label = "Centered Horizontal" }, { id = "centerV", label = "Centered Vertical" },
        { id = "right", label = "Horizontal Right" }, { id = "left", label = "Horizontal Left" },
        { id = "down", label = "Vertical Down" }, { id = "up", label = "Vertical Up" } },
    lineGrowth = { { id = "down", label = "Down" }, { id = "up", label = "Up" }, { id = "right", label = "Right" }, { id = "left", label = "Left" } },
    border = { { id = "mode", label = "ModeUI" }, { id = "rounded", label = "Rounded" }, { id = "square", label = "Square" }, { id = "none", label = "None" } },
    procGlow = GLOW_STYLES, activeGlow = GLOW_STYLES, readyGlow = GLOW_STYLES, buffGlow = GLOW_STYLES,
    readyMode = { { id = "flash", label = "Flash" }, { id = "always", label = "While Ready" } },
    visibility = { { id = "always", label = "Always" }, { id = "combat", label = "In Combat" }, { id = "noCombat", label = "Out of Combat" },
        { id = "target", label = "In Combat or With a Target" }, { id = "mouseover", label = "Mouseover" }, { id = "hidden", label = "Hidden" } },
    iconSide = { { id = "left", label = "Left" }, { id = "right", label = "Right" } },
}
for _, part in ipairs(M.textParts) do M.choices[part .. "Anchor"] = M.anchors end
-- Per-spell settings: hide (true while hidden), each glow while it's on
-- ({ style, color, pulse, lines, thickness }; the off-cooldown glow also mode
-- and duration), and text, the spell's own look per text (Text.lua).
M.spellKinds = { hide = true, proc = "glow", active = "glow", ready = "glow", buff = "glow", text = "text" }
M.outlineChoices = { { id = "none", label = "None" }, { id = "outline", label = "Outline" }, { id = "thick", label = "Thick" } }
M.textFields = { show = true, size = true, anchor = true, x = true, y = true, color = true, font = true, fontMedia = true, outline = true, shadow = true }
M.glowRanges = { lines = { 2, 16, 1 }, thickness = { 1, 4, 1 }, duration = { 1, 10, 1 } }
