local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Damage Meters: up to three meter windows in the Mode design
-- language (docs/DESIGN_LANGUAGE.md, "Windows and panels"). The
-- numbers come from the game's own damage meter (C_DamageMeter); ModeUI only
-- draws them. Each window has its own meter (Damage Done, DPS, Healing...),
-- fight (Current, Overall or an earlier one), size, bars, text and when it
-- shows. Blizzard's own meter is hidden while this is on (Hide Blizzard's
-- Meter); it keeps recording. See docs/DAMAGE_METERS.md.
-- Files: Init (this), Layouts, Migrations, Driver, Group, Layout, Window, Controls,
-- Render, Menu, Breakdown, Blizzard, Preview, Settings.
local L, Kit = addon.L, addon.Kit
local DM = addon.Domain.DamageMeter
local M = { title = L["Damage Meters"], category = "interface", defaultEnabled = false,
    configDescription = L["Damage, healing and more from the game's own meter, in Mode windows: size, bars, text and when each window shows."],
    modeLayout = { decorateOnly = true } }
addon.DamageMeters = M
addon:RegisterModule("damageMeters", M)

-- Version 2: white outlined text (the owner asked for text that stands out
-- on any bar color), Decimals, header buttons (fight, Reset, lock) with the
-- fight name off the header text, Lock Window, and groups.
-- Version 3: each text (Name, Value, Title, Timer) has its own font, size,
-- outline, shadow and color; names pure white and outlined; whole numbers
-- by default (Decimals 0-3); Separator; the header is an Onyx bar with its
-- own texture.
-- Version 4: groups stack Above by default (the owner wanted a grouped
-- window on top of the one it follows), and Hide Blizzard's Meter.
-- Version 6: the window takes ModeUI's standard border (owner); Border,
-- Border Size and Border Color are retired.
-- Version 7: the title keeps the meter's own capitals (owner: not every
-- letter capitalized) and takes Title Position, Title X and Title Y.
-- Version 9 (November 15, 2026, Phase 7): the Mode design language: a
-- Graphite window in the `window` edge, a Mode Title header, Mode Panel bars
-- on Mode BG, Ivory accents and the Mode typeface. Values still at version
-- 8's defaults follow.
M.VERSION = 9
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- The windows, in sidebar order, with their Edit Mode element (and saved
-- position key) and frame names. Each window's stand-in ("Mover") is what
-- Edit Mode drags; the window hangs from it.
M.windows = { "window1", "window2", "window3" }
M.windowLabels = { window1 = "Window 1", window2 = "Window 2", window3 = "Window 3" }
M.elementIds, M.frameNames = {}, {}
for index, window in ipairs(M.windows) do
    M.elementIds[window] = "damageMetersWindow" .. index
    M.frameNames[window] = "ModeUIDamageMeter" .. index
end
-- A window can be anchored to a window listed before it (never in a loop).
local BASE_TARGETS = { "screen", "player", "target", "focus", "minimap", "party" }
M.allowedTargets = {}
for index, window in ipairs(M.windows) do
    local allowed = Copy(BASE_TARGETS)
    for earlier = 1, index - 1 do allowed[#allowed + 1] = M.elementIds[M.windows[earlier]] end
    M.allowedTargets[window] = allowed
    addon.Positioning:AddTarget(M.elementIds[window], L[M.windowLabels[window]], M.frameNames[window] .. "Mover")
end
-- Window 1 sits on the right edge, below the middle; 2 and 3 stack on it.
M.defaultPositions = {
    window1 = { target = "screen", placement = "center", point = "RIGHT", relativePoint = "RIGHT", x = -12, y = -140 },
    window2 = { target = M.elementIds.window1, placement = "above", x = 0, y = 4 },
    window3 = { target = M.elementIds.window2, placement = "above", x = 0, y = 4 },
}

-- Colors: the window in Graphite panel, the header a Mode Title strip in
-- Graphite raised, bars for anything without a class in Graphite muted. The
-- edge is the Mode `window` edge, in Border Style and Border Metal. Names and values are
-- pure white (owner) and outlined, so they read on any bar color. Earlier
-- defaults, for migrations, are in Migrations.lua and Style.LEGACY.
local Tone = addon.Style.Tone
local G = Tone.graphite
M.BACKGROUND_COLOR, M.HEADER_COLOR = Copy(G.panel), Copy(G.raised)
M.OTHER_COLOR, M.TEXT_COLOR = Copy(G.muted), Copy(Tone.mono.white)

-- The texts, each with its own font, size, outline, shadow, slug and color
-- (keys prefixed with the part: nameFont, valueOutline, timerColor...).
-- Names and values can take the class color instead.
M.textParts = { "name", "value", "title", "timer" }
M.textPartLabels = { name = "Name", value = "Value", title = "Title", timer = "Timer" }
M.classColorParts = { name = true, value = true }
M.textPartKeys = { "Font", "FontMedia", "Size", "Outline", "Shadow", "Lifted", "Slug", "Color" }
local function TextPart(style, prefix, size, color, mode)
    style[prefix .. "Font"], style[prefix .. "FontMedia"], style[prefix .. "Size"] = "game", addon.Style.FONT_DEFAULT, size
    style[prefix .. "Outline"], style[prefix .. "Shadow"], style[prefix .. "Lifted"], style[prefix .. "Slug"] = true, true, false, true
    style[prefix .. "Color"] = Copy(color)
    if mode then style[prefix .. "ColorMode"] = mode end
end

local function Style(window)
    local style = {
        show = window == "window1", meterType = window == "window2" and "healingDone" or window == "window3" and "damageTaken" or "damageDone",
        session = "current", visibility = "always", opacity = 100, clickThrough = false, locked = false,
        -- Group With: another window this one stacks on (Above or Below, Gap
        -- apart) and takes every shared setting from.
        group = "none", groupSide = "above", groupGap = 2,
        -- Edit Mode's Match Width and Match Height: anchored on another
        -- element, the window takes its width (on by default; Rows stay) or
        -- as many rows as fit its height.
        matchWidth = true, matchHeight = false,
        -- Size: the window is as tall as its rows, so it always fits them exactly.
        width = 240, rows = 8, rowHeight = 18, spacing = 1, padding = 1,
        -- Frame
        backgroundColor = Copy(M.BACKGROUND_COLOR), backgroundOpacity = 75,
        -- Border Style and Border Metal (docs/DESIGN_LANGUAGE.md, "Choosing a
        -- border"): the window, its breakdown and its menu in Mode-Thin in its
        -- own metal (owner, November 17, 2026).
        edgeStyle = "thin", edgeMetal = "default",
        -- Header
        header = true, headerHeight = 20, headerTexture = "media:Mode Title", headerColor = Copy(M.HEADER_COLOR), headerOpacity = 100,
        titleUpper = false, showSession = false, showTimer = true, headerButtons = true,
        -- The title's place: Left, Center or Right in the room the timer and
        -- buttons leave, moved by Title X and Title Y (interface units).
        titleAlign = "left", titleOffsetX = 0, titleOffsetY = 0,
        -- Bars
        -- Mode Panel bars on Mode BG (tinted Slate), as the approved probe.
        barTexture = "media:Mode Panel", barBackground = "media:Mode BG", barOpacity = 100, barBackgroundOpacity = 100,
        barColorMode = "class", barColor = Copy(Tone.ivory), otherColor = Copy(M.OTHER_COLOR),
        icon = "class", alwaysShowMe = true,
        -- Text: numbers are whole by default (Decimals 0-3); Separator joins
        -- the amount, per second and percent.
        textInset = 4, showRank = true, numbers = "both", showPercent = false, decimals = 0, separator = "paren",
    }
    TextPart(style, "name", 12, M.TEXT_COLOR, "custom")
    TextPart(style, "value", 12, M.TEXT_COLOR, "custom")
    TextPart(style, "title", 11, G.text)
    TextPart(style, "timer", 11, G.muted)
    return style
end
M.styleDefaults = {}
for _, window in ipairs(M.windows) do M.styleDefaults[window] = Style(window) end
-- Hide Blizzard's Meter (the whole module): Blizzard's own meter window steps
-- aside while ModeUI's are on. Its data keeps recording either way.
M.defaults = { version = M.VERSION, hideBlizzard = true }
for _, window in ipairs(M.windows) do M.defaults[window] = Copy(M.styleDefaults[window]) end

-- Keys Copy Style leaves alone: whether, what and when a window shows, and its group.
M.identityKeys = { show = true, meterType = true, session = true, visibility = true,
    group = true, groupSide = true, groupGap = true, matchWidth = true, matchHeight = true }
-- Keys a grouped window keeps as its own; every other setting comes from the
-- window at the head of its group, so the group matches.
M.ownKeys = { show = true, meterType = true, session = true, rows = true, group = true, groupSide = true, groupGap = true,
    matchWidth = true, matchHeight = true }
-- Copy & Apply: what each choice copies. All is every setting but the
-- identity keys. Window brings its size, frame and header with it; Bars the
-- rows' look; Text every text and number setting.
M.copyScopes = {
    window = { "width", "padding", "opacity", "backgroundColor", "backgroundOpacity", "edgeStyle", "edgeMetal",
        "header", "headerHeight", "headerTexture", "headerColor", "headerOpacity", "titleUpper", "titleAlign", "titleOffsetX", "titleOffsetY",
        "showSession", "showTimer", "headerButtons" },
    bars = { "rowHeight", "spacing", "barTexture", "barBackground", "barOpacity", "barBackgroundOpacity", "barColorMode",
        "barColor", "otherColor", "icon", "alwaysShowMe" },
    text = { "textInset", "showRank", "numbers", "showPercent", "decimals", "separator", "nameColorMode", "valueColorMode" },
}
M.copyScopeChoices = { { id = "all", label = "All" }, { id = "window", label = "Window" }, { id = "bars", label = "Bars" }, { id = "text", label = "Text" } }
M.colorKeys = { backgroundColor = true, headerColor = true, barColor = true, otherColor = true }
-- Values for which the texture choices are checked by Kit.ValidBarTexture
-- (true: a foreground, which may be Mode Gradient).
M.textureKeys = { barTexture = true, barBackground = false, headerTexture = true }

M.ranges = { width = { 120, 600, 1 }, rows = { 1, 40, 1 }, rowHeight = { 10, 40, 1 }, spacing = { 0, 10, 1 },
    padding = { 0, 10, 1 }, backgroundOpacity = { 0, 100, 5 },
    headerHeight = { 14, 40, 1 }, headerOpacity = { 0, 100, 5 }, titleOffsetX = { -40, 40, 1 }, titleOffsetY = { -10, 10, 1 },
    barOpacity = { 10, 100, 5 }, barBackgroundOpacity = { 0, 100, 5 }, opacity = { 10, 100, 5 },
    textInset = { 0, 20, 1 }, decimals = { 0, 3, 1 }, groupGap = { 0, 20, 1 } }
for _, part in ipairs(M.textParts) do
    for _, suffix in ipairs(M.textPartKeys) do table.insert(M.copyScopes.text, part .. suffix) end
    M.colorKeys[part .. "Color"] = true
    M.ranges[part .. "Size"] = { 6, 32, 1 }
end
-- How the amount, per second and percent are joined: "5K (179, 61%)",
-- "5K / 179 / 61%" and so on. "||" is how text writes a single "|" (a lone
-- one starts an escape code).
M.separators = { paren = true, slash = " / ", bar = " || ", dot = " · ", dash = " - ", comma = ", ", space = "  " }

local meterChoices = {}
for _, info in ipairs(DM.types) do meterChoices[#meterChoices + 1] = { id = info.id, label = info.label } end
M.choices = {
    meterType = meterChoices,
    session = { { id = "current", label = "Current Fight" }, { id = "overall", label = "Overall" } },
    visibility = { { id = "always", label = "Always" }, { id = "combat", label = "In Combat" },
        { id = "group", label = "In a Group" }, { id = "hidden", label = "Hidden" } },
    barColorMode = { { id = "class", label = "Class" }, { id = "custom", label = "Custom" } },
    nameColorMode = { { id = "custom", label = "Color" }, { id = "class", label = "Class" } },
    valueColorMode = { { id = "custom", label = "Color" }, { id = "class", label = "Class" } },
    separator = { { id = "paren", label = "( )" }, { id = "slash", label = "/" }, { id = "bar", label = "|" },
        { id = "dot", label = "·" }, { id = "dash", label = "-" }, { id = "comma", label = "," }, { id = "space", label = "Space" } },
    icon = { { id = "class", label = "Class Icon" }, { id = "none", label = "None" } },
    titleAlign = { { id = "left", label = "Left" }, { id = "center", label = "Center" }, { id = "right", label = "Right" } },
    numbers = { { id = "primary", label = "Amount" }, { id = "both", label = "Amount and Per Second" } },
    group = { { id = "none", label = "None" } },
    groupSide = { { id = "above", label = "Above" }, { id = "below", label = "Below" } },
    edgeStyle = addon.Style.EdgeStyleChoices(),
    edgeMetal = addon.Style.EdgeMetalChoices(),
}
for _, window in ipairs(M.windows) do M.choices.group[#M.choices.group + 1] = { id = window, label = M.windowLabels[window] } end
