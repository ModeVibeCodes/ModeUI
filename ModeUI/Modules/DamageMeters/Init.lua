local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Damage Meters: up to three meter windows in the Mode look. The
-- numbers come from the game's own damage meter (C_DamageMeter); ModeUI only
-- draws them. Each window has its own meter (Damage Done, DPS, Healing...),
-- fight (Current, Overall or an earlier one), size, bars, text and when it
-- shows. Blizzard's meter window is never touched. See docs/DAMAGE_METERS.md.
-- Files: Init (this), Migrations, Driver, Group, Layout, Window, Controls,
-- Render, Menu, Breakdown, Preview, Settings.
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
M.VERSION = 2
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
-- the header strip (#141518), bars for anything without a class (#78808C).
M.BORDER_COLOR, M.BACKGROUND_COLOR = Kit.RGB(16, 16, 16), Kit.RGB(4, 4, 4)
M.HEADER_COLOR, M.OTHER_COLOR = Kit.RGB(20, 21, 24), Kit.RGB(120, 128, 140)
M.TRACK_COLOR = Kit.onyx.track
-- Text is white, outlined, so it reads on any bar color.
M.TEXT_COLOR = { 1, 1, 1 }

local function Style(window)
    return {
        show = window == "window1", meterType = window == "window2" and "healingDone" or window == "window3" and "damageTaken" or "damageDone",
        session = "current", visibility = "always", opacity = 100, clickThrough = false, locked = false,
        -- Group With: another window this one stacks on (Below or Above, Gap
        -- apart) and takes every shared setting from.
        group = "none", groupSide = "below", groupGap = 2,
        -- Size: the window is as tall as its rows, so it always fits them exactly.
        width = 240, rows = 8, rowHeight = 18, spacing = 1, padding = 1,
        -- Frame
        border = "rounded", borderSize = 1, borderColor = Copy(M.BORDER_COLOR),
        backgroundColor = Copy(M.BACKGROUND_COLOR), backgroundOpacity = 75,
        -- Header
        header = true, headerHeight = 20, headerColor = Copy(M.HEADER_COLOR), headerOpacity = 100,
        titleSize = 11, titleColor = Copy(Kit.palette.accent), titleUpper = true, showSession = false, showTimer = true,
        headerButtons = true,
        -- Bars
        barTexture = "mode", barBackground = "flat", barOpacity = 100, barBackgroundOpacity = 25,
        barColorMode = "class", barColor = Copy(Kit.palette.accent), otherColor = Copy(M.OTHER_COLOR),
        icon = "class", alwaysShowMe = true,
        -- Text
        font = "game", fontMedia = "Expressway", outline = true, shadow = true, liftedShadow = false, slug = true,
        nameSize = 12, valueSize = 12, textInset = 4, nameColorMode = "white", textColor = Copy(M.TEXT_COLOR),
        showRank = true, numbers = "both", showPercent = false, decimals = 1,
    }
end
M.styleDefaults = {}
for _, window in ipairs(M.windows) do M.styleDefaults[window] = Style(window) end
M.defaults = { version = M.VERSION }
for _, window in ipairs(M.windows) do M.defaults[window] = Copy(M.styleDefaults[window]) end

-- Keys Copy Style leaves alone: whether, what and when a window shows, and its group.
M.identityKeys = { show = true, meterType = true, session = true, visibility = true,
    group = true, groupSide = true, groupGap = true }
-- Keys a grouped window keeps as its own; every other setting comes from the
-- window at the head of its group, so the group matches.
M.ownKeys = { show = true, meterType = true, session = true, rows = true, group = true, groupSide = true, groupGap = true }
M.colorKeys = { borderColor = true, backgroundColor = true, headerColor = true, titleColor = true,
    barColor = true, otherColor = true, textColor = true }
-- Values for which the texture choices are checked by Kit.ValidBarTexture.
M.textureKeys = { barTexture = true, barBackground = false }

M.ranges = { width = { 120, 600, 1 }, rows = { 1, 40, 1 }, rowHeight = { 10, 40, 1 }, spacing = { 0, 10, 1 },
    padding = { 0, 10, 1 }, borderSize = { 1, 4, 1 }, backgroundOpacity = { 0, 100, 5 },
    headerHeight = { 14, 40, 1 }, headerOpacity = { 0, 100, 5 }, titleSize = { 6, 32, 1 },
    barOpacity = { 10, 100, 5 }, barBackgroundOpacity = { 0, 100, 5 }, opacity = { 10, 100, 5 },
    nameSize = { 6, 32, 1 }, valueSize = { 6, 32, 1 }, textInset = { 0, 20, 1 }, decimals = { 0, 2, 1 }, groupGap = { 0, 20, 1 } }

local meterChoices = {}
for _, info in ipairs(DM.types) do meterChoices[#meterChoices + 1] = { id = info.id, label = info.label } end
M.choices = {
    meterType = meterChoices,
    session = { { id = "current", label = "Current Fight" }, { id = "overall", label = "Overall" } },
    visibility = { { id = "always", label = "Always" }, { id = "combat", label = "In Combat" },
        { id = "group", label = "In a Group" }, { id = "hidden", label = "Hidden" } },
    border = { { id = "rounded", label = "Rounded" }, { id = "square", label = "Square" }, { id = "none", label = "None" } },
    barColorMode = { { id = "class", label = "Class" }, { id = "custom", label = "Custom" } },
    nameColorMode = { { id = "white", label = "Text Color" }, { id = "class", label = "Class" } },
    icon = { { id = "class", label = "Class Icon" }, { id = "none", label = "None" } },
    numbers = { { id = "primary", label = "Amount" }, { id = "both", label = "Amount and Per Second" } },
    group = { { id = "none", label = "None" } },
    groupSide = { { id = "below", label = "Below" }, { id = "above", label = "Above" } },
}
for _, window in ipairs(M.windows) do M.choices.group[#M.choices.group + 1] = { id = window, label = M.windowLabels[window] } end
