local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface suite: secure Player, Target, Target of Target, Focus and Target
-- of Focus frames in the locked Onyx skin
-- (round portrait capping a rounded bar block inside a slate rim).
-- Forever runs the mainline client, so unit values can be secret. They are only
-- handed to widgets/formatters Blizzard documents as accepting secret values;
-- never compared, tested or used in arithmetic here. See docs/UNIT_FRAMES.md.
-- Files: Init (this), Migrations, Driver, Native, Layout, Build, Update, Settings.
local L = addon.L
local M = { title = L["Unit Frames"], category = "interface", defaultEnabled = true,
    configDescription = L["Player, Target, Target of Target and Focus frames in the Onyx look. Configure outside combat."],
    -- The settings page keeps its own sections; the Mode layer restyles headings.
    modeLayout = { decorateOnly = true } }
addon.UnitFrames = M
addon:RegisterModule("unitFrames", M)

M.CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

-- Player and Target, then the smaller Target of Target, Focus and Target of
-- Focus frames (owner, November 13, 2026). The unit tokens are also the keys
-- of their saved settings.
M.units = { "player", "target", "targettarget", "focus", "focustarget" }
M.labels = { player = "Player", target = "Target", targettarget = "Target of Target", focus = "Focus",
    focustarget = "Target of Focus" }
-- How settings name each frame, and the part of its global frame names.
M.titles = { player = "Player Frame", target = "Target Frame", targettarget = "Target of Target", focus = "Focus Frame",
    focustarget = "Target of Focus" }
M.frameNames = { player = "Player", target = "Target", targettarget = "TargetTarget", focus = "Focus", focustarget = "FocusTarget" }
M.elementIds = { player = "unitFramesPlayer", target = "unitFramesTarget", targettarget = "unitFramesTargetTarget",
    focus = "unitFramesFocus", focustarget = "unitFramesFocusTarget" }
M.defaultPositions = {
    player = { target = "screen", placement = "center", x = -280, y = -200 },
    target = { target = "screen", placement = "center", x = 280, y = -200 },
    targettarget = { target = "screen", placement = "center", x = 360, y = -280 },
    focus = { target = "screen", placement = "center", x = -460, y = 40 },
    focustarget = { target = "screen", placement = "center", x = -400, y = -40 },
}
-- The game sends no unit events for these; their frames refresh on a timer.
M.polledUnits = { targettarget = true, focustarget = true }
-- Frames that can attach to another ModeUI frame instead of a screen position
-- (Attach to Target Frame / Attach to Focus Frame), and the corner they join:
-- this frame's `point` to the parent's `relative`.
M.attachParents = { targettarget = "target", focustarget = "focus" }
M.attachPoints = { bottomright = { point = "TOPRIGHT", relative = "BOTTOMRIGHT" },
    bottomleft = { point = "TOPLEFT", relative = "BOTTOMLEFT" }, right = { point = "LEFT", relative = "RIGHT" },
    left = { point = "RIGHT", relative = "LEFT" }, topright = { point = "BOTTOMRIGHT", relative = "TOPRIGHT" } }
-- Version 13: Target of Target, Focus and Target of Focus defaults (see Migrations.lua).
M.LAYOUT_VERSION = 13

local function RGB(r, g, b) return { r / 255, g / 255, b / 255 } end
-- Mode text and gameplay colors, and the locked Onyx skin (Shared/Kit/Palette.lua).
M.palette, M.onyx = addon.Kit.palette, addon.Kit.onyx
-- Plain-text name colors that contrast the cool Onyx/slate skin (owner's
-- picks). Sky, the owner's own color (layout version 11), is the default.
M.nameAccents = { sky = RGB(145, 198, 255), champagne = RGB(242, 223, 184), lilac = RGB(201, 187, 255),
    frost = RGB(234, 241, 248) }
M.ACCENT = M.nameAccents.sky

M.choices = {
    healthText = { { id = "percent", label = "Percent" }, { id = "current", label = "Current Health" },
        { id = "both", label = "Current and Percent" }, { id = "none", label = "None" } },
    powerText = { { id = "none", label = "None" }, { id = "percent", label = "Percent" },
        { id = "current", label = "Current Power" }, { id = "both", label = "Current and Percent" } },
    position = { { id = "LEFT", label = "Left" }, { id = "CENTER", label = "Center" }, { id = "RIGHT", label = "Right" } },
    side = { { id = "left", label = "Left" }, { id = "right", label = "Right" } },
    portraitStyle = { { id = "portrait", label = "Character Portrait" }, { id = "class", label = "Class Icon" } },
    ring = { { id = "class", label = "Class Gradient" }, { id = "border", label = "Default" }, { id = "custom", label = "Custom" } },
    namePosition = { { id = "above", label = "Above Frame" }, { id = "bar", label = "On Health Bar" } },
    nameColor = { { id = "sky", label = "Sky" }, { id = "champagne", label = "Champagne" }, { id = "lilac", label = "Lilac" },
        { id = "frost", label = "Frost" }, { id = "class", label = "Class Color" }, { id = "custom", label = "Custom" } },
    level = { { id = "badge", label = "Shown" }, { id = "none", label = "Hidden" } },
    healthColor = { { id = "default", label = "Default" }, { id = "class", label = "Class Color" }, { id = "custom", label = "Custom" } },
    powerColor = { { id = "type", label = "Power Type" }, { id = "custom", label = "Custom" } },
    attachPoint = { { id = "bottomright", label = "Below, Right Edges" }, { id = "bottomleft", label = "Below, Left Edges" },
        { id = "right", label = "Right Side" }, { id = "left", label = "Left Side" }, { id = "topright", label = "Above, Right Edges" } },
}
-- Setting key -> choice list.
M.choiceKeys = { healthText = "healthText", powerText = "powerText", healthTextPosition = "position",
    powerTextPosition = "position", nameAlign = "position", portraitSide = "side", portraitStyle = "portraitStyle",
    portraitRing = "ring", namePosition = "namePosition", nameColorMode = "nameColor", levelStyle = "level",
    healthColorMode = "healthColor", powerColorMode = "powerColor", attachPoint = "attachPoint" }

local function Copy(value) return addon.ProfileCodec.Copy(value) end
M.Public = addon.IsPublic
M.Number = addon.IsNumber

local function Frame(side, extra)
    local frame = { enabled = true, hideBlizzard = true, scale = 100, barWidth = 180, healthHeight = 26,
        -- Target only: mirror the Player frame's look (side and visibility stay its own).
        matchPlayer = false,
        -- Target only, while matched: mirror the Player's text alignment and
        -- horizontal offsets to the other side (off: same layout as the Player).
        mirrorText = false,
        showPower = true, powerHeight = 10,
        -- Both bars: fill (foreground) and empty bar (background) textures and
        -- opacity. The background is mostly see-through by default, so the fill
        -- stands out against the world behind it (owner, November 13, 2026).
        foregroundTexture = "mode", backgroundTexture = "flat", barForegroundOpacity = 100, barBackgroundOpacity = 25,
        showPortrait = true, portraitStyle = "portrait", portraitSide = side,
        portraitScale = 150, -- portrait diameter as a % of the bar block
        portraitRing = "class", portraitRingColor = Copy(M.ACCENT),
        showName = true, namePosition = "above", nameAlign = "RIGHT", nameFontSize = 12,
        nameColorMode = "sky", nameColor = Copy(M.ACCENT), nameOffsetX = 0, nameOffsetY = 0,
        -- Class/reaction colors are blended this far toward white (pastel).
        classSoftness = 40,
        levelStyle = "badge", levelFontSize = 11, levelColor = Copy(M.palette.muted), levelOffsetX = 0, levelOffsetY = 0,
        healthColorMode = "default", healthColor = Copy(M.palette.green),
        healthText = "percent", healthTextPosition = "RIGHT", healthFontSize = 11, healthTextOffsetX = 0, healthTextOffsetY = 0,
        powerColorMode = "type", powerColor = Copy(M.palette.mana),
        powerText = "none", powerTextPosition = "CENTER", powerFontSize = 9, powerTextOffsetX = 0, powerTextOffsetY = 0,
        font = "game", fontMedia = "Expressway", outline = false, shadow = true,
        -- The suite's text style: every text gets a crisp opaque 1px shadow plus
        -- a lighter second shadow 2px out (owner, layout version 11).
        liftedShadow = true, textColor = Copy(M.palette.text),
        -- Target of Target and Target of Focus only: attached to their parent frame.
        attach = false, attachPoint = "bottomright", attachOffsetX = 0, attachOffsetY = -2 }
    for key, value in pairs(extra or {}) do frame[key] = value end
    return frame
end
-- Target of Target (owner, November 13, 2026): small, no portrait or level,
-- 75% scale, the name inside the health bar on the left, attached under the
-- Target frame's bottom-right corner. Target of Focus is the same under the
-- Focus frame, and Focus is the same frame at 90% scale, placed on its own.
local function Small(scale, attach)
    return { barWidth = 110, healthHeight = 16, powerHeight = 6, nameFontSize = 11, healthFontSize = 10, levelStyle = "none",
        scale = scale, showPortrait = false, namePosition = "bar", nameAlign = "LEFT", attach = attach }
end
M.frameDefaults = { player = Frame("left"), target = Frame("right", { matchPlayer = true }),
    targettarget = Frame("left", Small(75, true)), focus = Frame("right", Small(90, false)), focustarget = Frame("left", Small(75, true)) }
M.frameRanges = { scale = { 50, 200, 1 }, barWidth = { 100, 400, 1 }, healthHeight = { 10, 60, 1 },
    powerHeight = { 2, 30, 1 }, nameFontSize = { 8, 24, 1 }, healthFontSize = { 8, 24, 1 }, powerFontSize = { 6, 20, 1 },
    portraitScale = { 100, 200, 5 }, classSoftness = { 0, 100, 5 }, levelFontSize = { 6, 24, 1 },
    barForegroundOpacity = { 10, 100, 5 }, barBackgroundOpacity = { 0, 100, 5 },
    nameOffsetX = { -100, 100, 1 }, nameOffsetY = { -100, 100, 1 }, levelOffsetX = { -100, 100, 1 }, levelOffsetY = { -100, 100, 1 },
    healthTextOffsetX = { -100, 100, 1 }, healthTextOffsetY = { -100, 100, 1 },
    powerTextOffsetX = { -100, 100, 1 }, powerTextOffsetY = { -100, 100, 1 },
    attachOffsetX = { -200, 200, 1 }, attachOffsetY = { -200, 200, 1 } }
-- Keys that describe placement/identity rather than style; Copy Style skips them.
M.identityKeys = { enabled = true, hideBlizzard = true, portraitSide = true, matchPlayer = true, mirrorText = true,
    attach = true, attachPoint = true, attachOffsetX = true, attachOffsetY = true }
-- Combo points around the Target frame's portrait (owner, November 13, 2026).
-- Their own table, not per frame, so they stay editable while the Target
-- matches the Player. Sizes are in the Target frame's units.
M.comboDefaults = { enabled = true, hideBlizzard = true, arc = "topOuter", size = 10, spacing = 3, distance = 3,
    activeColor = RGB(240, 84, 84), emptyColor = Copy(M.onyx.track) }
M.comboRanges = { size = { 6, 24, 1 }, spacing = { 0, 12, 1 }, distance = { 0, 20, 1 } }
-- Where the arc sits around the portrait. "outer" is the side away from the
-- bars; without a portrait the points line up under the bars.
M.choices.comboArc = { { id = "topOuter", label = "Upper Outer" }, { id = "outer", label = "Outer Side" },
    { id = "bottomOuter", label = "Lower Outer" }, { id = "top", label = "Top" }, { id = "bottom", label = "Bottom" } }
M.defaults = { layoutVersion = M.LAYOUT_VERSION, comboPoints = Copy(M.comboDefaults) }
for _, unit in ipairs(M.units) do M.defaults[unit] = Copy(M.frameDefaults[unit]) end
