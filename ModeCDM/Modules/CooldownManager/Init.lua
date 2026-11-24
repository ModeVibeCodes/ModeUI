local _, ns = ...
local addon = ns.ModeUI or {}
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
-- The player's Cast Bar too: see CastInit.lua.
-- The five default bars (Defensive Cooldowns and four buff bars): see
-- Presets.lua. Its part of the Mode-Default layout: Layouts.lua.
-- Files: Init (this), ResourceInit, CastInit, Presets, Migrations, Driver,
-- Custom, Spells, Items, Racials, Blizzard, Tracking, Layout, Skin, Bars, Text, Glow,
-- Visibility, Resources, ResourceSnap, ResourceGroup, ResourceMarks,
-- ResourceUpdate, CastBar, SpellMenu, GlowPopout, TextPopout, Picker,
-- Preview, PreviewDrag, ResourcePreview, CastPreview, SettingsHelpers,
-- Settings, SettingsTabs, ResourceSettings, ResourceSettingsLook,
-- CastSettings, Window, Layouts.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Cooldown Manager"], standalone = true, defaultEnabled = false,
    configDescription = L["Blizzard's Cooldown Manager in the Mode look, with custom bars of your own."],
    modeLayout = { decorateOnly = true },
    -- Shipped as its own addon, ModeCDM (ModeCDM/Core.lua): it may register
    -- after ModeUI has started, and starts from ModeCDM/Start.lua then.
    companion = "ModeCDM" }
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
-- Version 5: the Mode design language (docs/DESIGN_LANGUAGE.md, "Cooldown
-- icons"): icons 40 by 34 (32 by 28 on the smaller bars) in the `frameThin`
-- edge outside the icon (Border: Mode or None; Border Size, Border Color and
-- the slot rims retire), a Mode Button face in Mono panel, Urbanist Bold text
-- in the Mode colors, Celadon procs and buffs, Ivory active and ready glows;
-- Tracked Bars in Mode Gradient on Mode BG with the Comet spark, in your
-- class color (Bar Color: Class Color or Custom).
-- Version 6 (owner, November 17, 2026): Resource Bars in Mode-Round and
-- Gunmetal, Dark mode, thinner (Power 10, Combo Points and Alternate Mana 6),
-- the combo point count on; Rim Color, Tick Marks, Grouped or Separated combo
-- points and Group Resources added (ResourceInit.lua, Migrations.lua).
-- Version 7 (owner's first in-game look, November 18, 2026): heights 16/10/8,
-- the text always centered behind Show Text, Tick Marks a list of one to five
-- behind Show Tick Marks.
-- Version 8 (owner, November 18, 2026): the Cast Bar above Essential; Buff
-- Icons at their old default move above it.
-- Version 9 (owner, November 18, 2026): the five default bars (Presets.lua)
-- join a profile after its own bars, while there's room; up to 15 custom
-- bars. A new profile starts with them.
-- Version 10 (owner, November 20, 2026): the Cast Bar in your class color;
-- a Bar Mode still at Dark (the old default) takes Color.
-- Version 11 (owner, November 23, 2026): every Mode cast bar in light blue,
-- orange-red when it can't be interrupted; old default colors follow.
M.VERSION = 11
M.SLASH = "/mcdm"
local P, Mode = Kit.palette, addon.Style
local Tone = Mode.Tone
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Blizzard's viewers, in list order. `bar` marks Tracked Bars (a bar beside
-- each icon); `buff` the viewers that show auras rather than cooldowns;
-- `category` the Blizzard Cooldown Manager category each shows (Tracking.lua).
M.viewers = { "essential", "utility", "buffIcon", "buffBar" }
M.viewerSpecs = {
    essential = { label = "Essential Cooldowns", category = "Essential" },
    utility = { label = "Utility Cooldowns", category = "Utility" },
    buffIcon = { label = "Tracked Buffs", buff = true, category = "TrackedBuff" },
    buffBar = { label = "Tracked Bars", buff = true, bar = true, category = "TrackedBar" },
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
M.MAX_CUSTOM, M.MAX_ENTRIES, M.MAX_NAME = 15, 40, 32

-- Element (and saved position) IDs and frame names.
local function Capital(id) return id:sub(1, 1):upper() .. id:sub(2) end
function M.ElementId(id) return "cooldownManager" .. Capital(id) end
function M.FrameName(id) return "ModeUICooldown" .. Capital(id) end
-- Every bar is an Edit Mode target (elements register with anyTarget, so
-- any ModeUI element can hang from any other).
for _, viewer in ipairs(M.viewers) do
    addon.Positioning:AddTarget(M.ElementId(viewer), L[M.viewerSpecs[viewer].label], M.FrameName(viewer))
end

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

-- Colors (docs/DESIGN_LANGUAGE.md): a Mode Button face in Mono panel, the
-- cooldown color for the numbers, a black swipe; Celadon procs and buffs,
-- Ivory active and off-cooldown glows; tracked bars in your class color (or
-- Ivory when Custom).
M.SWIPE_COLOR = Copy(Tone.shadow)
M.GLOW_COLORS = { proc = Copy(Tone.celadon), active = Copy(Tone.ivory), ready = Copy(Tone.ivory), buff = Copy(Tone.celadon) }
M.BAR_COLOR = Copy(Tone.ivory)
-- Version 2-4 defaults, kept for migrations: the ModeUI border and the old
-- Rounded rim, the slot background at 75%, gold procs, green active and buff
-- glows, the cyan ready glow and bars, the old text and cooldown colors.
M.OLD = { borderColor = Kit.BORDER_COLOR, rimColor = Mode.LEGACY.slotRim, background = Mode.LEGACY.slotBackground,
    backgroundOpacity = 75, glows = { proc = Mode.LEGACY.procGold, active = P.green, ready = P.accent, buff = P.green },
    bar = P.accent, text = P.text, cooldown = P.cooldown }
local function Part(prefix, show, size, anchor, color)
    return { [prefix .. "Show"] = show, [prefix .. "Size"] = size, [prefix .. "Anchor"] = anchor,
        [prefix .. "X"] = 0, [prefix .. "Y"] = 0, [prefix .. "Color"] = Copy(color) }
end

-- One bar's settings. Essential icons are the action buttons' 40 by 34;
-- Utility and Tracked Buffs 32 by 28; Tracked Bars 220 by 16. Lines are
-- centered; Tracked Buffs and Bars add new lines upward. Spacing counts
-- between the edges' shadows.
local function Style(size, perLine, lineGrowth, small)
    local style = {
        show = true,
        perLine = perLine, grow = "centerH", lineGrowth = lineGrowth,
        width = size[1], height = size[2], spacing = 2,
        -- Match Width / Match Height (Edit Mode): the size of what it hangs from.
        matchWidth = false, matchHeight = false,
        border = "mode", backgroundColor = Copy(Tone.mono.panel), backgroundOpacity = 100,
        -- The border's style and metal (docs/DESIGN_LANGUAGE.md, "Choosing a border"):
        -- icons and the Tracked Bars' boxes; Mode-Empty with a neutral, darker
        -- rim (owner, November 20, 2026).
        edgeStyle = "obsidianEmpty", edgeMetal = "default",
        -- Border Size (the band, 1 or 2px) and Border Color (Mode-Empty's
        -- flat band; owner, November 18, 2026).
        edgeSize = 1, edgeColor = Copy(Tone.emptyRim),
        -- The cooldown: icons go gray while a spell cools down; a flat swipe
        -- in Swipe Color at Swipe Opacity; Edge is the bright line on its
        -- rim, Ready Flash Blizzard's flash as it ends.
        desaturate = true, swipeColor = Copy(M.SWIPE_COLOR), swipeOpacity = 70, showEdge = false, showBling = true, showFlash = true,
        rangeTint = true, debuffBorder = false,
        font = "game", fontMedia = Mode.FONT_DEFAULT, outline = false, shadow = true, slug = true,
        -- Glows start off on every spell (owner, November 13, 2026); a spell's
        -- menu switches one on, starting from these looks.
        procGlow = "border", activeGlow = "border", readyGlow = "mode", buffGlow = "mode",
        procPulse = false, activePulse = false, readyPulse = true, buffPulse = false,
        readyMode = "flash", readyDuration = 2, glowLines = 8, glowThickness = 2,
        -- While a spell's effect is up, Blizzard swaps its cooldown for the
        -- effect's time in a full-color gold swipe; off (the default), the
        -- icon keeps showing its cooldown, gray.
        auraSwipe = false,
        visibility = "always", opacity = 100, fadeOpacity = 0,
        -- Tracked Bars: the bar's texture and color (your class color, or
        -- Bar Color when Custom), its background, the icon's side and the
        -- Comet spark.
        barTexture = "media:Mode-FG", barColorMode = "class", barColor = Copy(M.BAR_COLOR),
        -- The empty part: Mode-BG at the Mode-Obsidian empty opacity (85%).
        barBackground = "media:Mode-BG", barBackgroundOpacity = math.floor(Tone.emptyAlpha * 100 + 0.5), iconSide = "left", showSpark = true,
        -- Spells with their own switches, by cooldown ID: { ["1234"] = { hide = true, proc = false } }.
        spells = {},
    }
    for _, kind in ipairs(M.glowKinds) do style[kind .. "Color"] = Copy(M.GLOW_COLORS[kind]) end
    for key, value in pairs(Part("cooldown", true, small and 10 or 13, "CENTER", Tone.cooldown)) do style[key] = value end
    for key, value in pairs(Part("count", true, small and 10 or 11, "BOTTOMRIGHT", Tone.textBright)) do style[key] = value end
    for key, value in pairs(Part("name", true, 10, "LEFT", Tone.textBright)) do style[key] = value end
    for key, value in pairs(Part("duration", true, 10, "RIGHT", Tone.textBright)) do style[key] = value end
    return style
end
M.styleDefaults = {
    essential = Style({ 40, 34 }, 12, "down"), utility = Style({ 32, 28 }, 12, "down", true),
    buffIcon = Style({ 32, 28 }, 12, "up", true), buffBar = Style({ 220, 16 }, 1, "up", true),
}
M.customDefaults = { cooldown = Style({ 40, 34 }, 8, "down"), buff = Style({ 32, 28 }, 8, "up", true) }
-- Version 4's default sizes and text sizes, which move to version 5's.
M.v4Sizes = { essential = { 42, 34 }, utility = { 36, 28 }, buffIcon = { 36, 28 }, buffBar = { 220, 22 }, cooldown = { 42, 34 }, buff = { 36, 28 } }
-- Keys version 5 retired (the Mode edge has one size and color).
M.retiredKeys = { "borderSize", "borderColor" }
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
M.colorKeys = { backgroundColor = true, swipeColor = true, barColor = true, edgeColor = true }
for _, kind in ipairs(M.glowKinds) do M.colorKeys[kind .. "Color"] = true end
for _, part in ipairs(M.textParts) do M.colorKeys[part .. "Color"] = true end

-- Spacing below 0 overlaps the edges' shadows (-1: one shared pixel; -2: the bands touch).
M.ranges = { perLine = { 1, 20, 1 }, spacing = { -2, 20, 1 }, glowLines = { 2, 16, 1 }, glowThickness = { 1, 4, 1 },
    backgroundOpacity = { 0, 100, 5 }, swipeOpacity = { 0, 100, 5 }, readyDuration = { 1, 10, 1 },
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
    border = { { id = "mode", label = "Mode" }, { id = "none", label = "None" } },
    edgeStyle = Mode.EdgeStyleChoices(), edgeMetal = Mode.EdgeMetalChoices(),
    edgeSize = { { id = 1, label = "1px" }, { id = 2, label = "2px" } },
    barColorMode = { { id = "class", label = "Class Color" }, { id = "custom", label = "Custom" } },
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
