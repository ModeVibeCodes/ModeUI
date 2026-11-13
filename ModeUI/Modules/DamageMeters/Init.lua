local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Damage Meters: up to three meter windows in the Mode look. The
-- numbers come from the game's own damage meter (C_DamageMeter); ModeUI only
-- draws them. Each window has its own meter (Damage Done, DPS, Healing...),
-- fight (Current, Overall or an earlier one), size, bars, text and when it
-- shows. Blizzard's own meter is hidden while this is on (Hide Blizzard's
-- Meter); it keeps recording. See docs/DAMAGE_METERS.md.
-- Files: Init (this), Migrations, Driver, Group, Layout, Window, Controls,
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
M.VERSION = 4
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

-- Colors: the window rim (#101010), the background inside it (#040404),
-- bars for anything without a class (#78808C). The header is an Onyx bar:
-- the Unit Frames health fill (#1C1E21) in Mode Gradient.
M.BORDER_COLOR, M.BACKGROUND_COLOR = Kit.RGB(16, 16, 16), Kit.RGB(4, 4, 4)
M.HEADER_COLOR, M.OTHER_COLOR = Kit.onyx.health, Kit.RGB(120, 128, 140)
M.TRACK_COLOR = Kit.onyx.track
-- Names and values are pure white and outlined, so they read on any bar color.
M.TEXT_COLOR = { 1, 1, 1 }

-- The texts, each with its own font, size, outline, shadow, slug and color
-- (keys prefixed with the part: nameFont, valueOutline, timerColor...).
-- Names and values can take the class color instead.
M.textParts = { "name", "value", "title", "timer" }
M.textPartLabels = { name = "Name", value = "Value", title = "Title", timer = "Timer" }
M.classColorParts = { name = true, value = true }
M.textPartKeys = { "Font", "FontMedia", "Size", "Outline", "Shadow", "Lifted", "Slug", "Color" }
local function TextPart(style, prefix, size, color, mode)
    style[prefix .. "Font"], style[prefix .. "FontMedia"], style[prefix .. "Size"] = "game", "Expressway", size
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
        -- Size: the window is as tall as its rows, so it always fits them exactly.
        width = 240, rows = 8, rowHeight = 18, spacing = 1, padding = 1,
        -- Frame
        border = "rounded", borderSize = 1, borderColor = Copy(M.BORDER_COLOR),
        backgroundColor = Copy(M.BACKGROUND_COLOR), backgroundOpacity = 75,
        -- Header
        header = true, headerHeight = 20, headerTexture = "mode", headerColor = Copy(M.HEADER_COLOR), headerOpacity = 100,
        titleUpper = true, showSession = false, showTimer = true, headerButtons = true,
        -- Bars
        barTexture = "mode", barBackground = "flat", barOpacity = 100, barBackgroundOpacity = 25,
        barColorMode = "class", barColor = Copy(Kit.palette.accent), otherColor = Copy(M.OTHER_COLOR),
        icon = "class", alwaysShowMe = true,
        -- Text: numbers are whole by default (Decimals 0-3); Separator joins
        -- the amount, per second and percent.
        textInset = 4, showRank = true, numbers = "both", showPercent = false, decimals = 0, separator = "paren",
    }
    TextPart(style, "name", 12, M.TEXT_COLOR, "custom")
    TextPart(style, "value", 12, M.TEXT_COLOR, "custom")
    TextPart(style, "title", 11, Kit.palette.accent)
    TextPart(style, "timer", 11, Kit.palette.muted)
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
    group = true, groupSide = true, groupGap = true }
-- Keys a grouped window keeps as its own; every other setting comes from the
-- window at the head of its group, so the group matches.
M.ownKeys = { show = true, meterType = true, session = true, rows = true, group = true, groupSide = true, groupGap = true }
M.colorKeys = { borderColor = true, backgroundColor = true, headerColor = true, barColor = true, otherColor = true }
-- Values for which the texture choices are checked by Kit.ValidBarTexture
-- (true: a foreground, which may be Mode Gradient).
M.textureKeys = { barTexture = true, barBackground = false, headerTexture = true }

M.ranges = { width = { 120, 600, 1 }, rows = { 1, 40, 1 }, rowHeight = { 10, 40, 1 }, spacing = { 0, 10, 1 },
    padding = { 0, 10, 1 }, borderSize = { 1, 4, 1 }, backgroundOpacity = { 0, 100, 5 },
    headerHeight = { 14, 40, 1 }, headerOpacity = { 0, 100, 5 },
    barOpacity = { 10, 100, 5 }, barBackgroundOpacity = { 0, 100, 5 }, opacity = { 10, 100, 5 },
    textInset = { 0, 20, 1 }, decimals = { 0, 3, 1 }, groupGap = { 0, 20, 1 } }
for _, part in ipairs(M.textParts) do
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
    border = { { id = "rounded", label = "Rounded" }, { id = "square", label = "Square" }, { id = "none", label = "None" } },
    barColorMode = { { id = "class", label = "Class" }, { id = "custom", label = "Custom" } },
    nameColorMode = { { id = "custom", label = "Color" }, { id = "class", label = "Class" } },
    valueColorMode = { { id = "custom", label = "Color" }, { id = "class", label = "Class" } },
    separator = { { id = "paren", label = "( )" }, { id = "slash", label = "/" }, { id = "bar", label = "|" },
        { id = "dot", label = "·" }, { id = "dash", label = "-" }, { id = "comma", label = "," }, { id = "space", label = "Space" } },
    icon = { { id = "class", label = "Class Icon" }, { id = "none", label = "None" } },
    numbers = { { id = "primary", label = "Amount" }, { id = "both", label = "Amount and Per Second" } },
    group = { { id = "none", label = "None" } },
    groupSide = { { id = "above", label = "Above" }, { id = "below", label = "Below" } },
}
for _, window in ipairs(M.windows) do M.choices.group[#M.choices.group + 1] = { id = window, label = M.windowLabels[window] } end
