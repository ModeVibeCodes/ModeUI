local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface suite: secure Player and Target frames in the locked Onyx skin
-- (round portrait capping a rounded bar block inside a slate rim).
-- Forever runs the mainline client, so unit values can be secret. They are only
-- handed to widgets/formatters Blizzard documents as accepting secret values;
-- never compared, tested or used in arithmetic here. See docs/UNIT_FRAMES.md.
-- Files: Init (this), Migrations, Driver, Layout, Build, Update, Settings.
local L = addon.L
local M = { title = L["Unit Frames"], category = "interface", defaultEnabled = true,
    configDescription = L["Player and Target frames in the Onyx look. Configure outside combat."],
    -- The settings page keeps its own sections; the Mode layer restyles headings.
    modeLayout = { decorateOnly = true } }
addon.UnitFrames = M
addon:RegisterModule("unitFrames", M)

M.CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

M.units = { "player", "target" }
M.labels = { player = "Player", target = "Target" }
M.elementIds = { player = "unitFramesPlayer", target = "unitFramesTarget" }
M.defaultPositions = {
    player = { target = "screen", placement = "center", x = -280, y = -200 },
    target = { target = "screen", placement = "center", x = 280, y = -200 },
}
M.LAYOUT_VERSION = 11

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
}
-- Setting key -> choice list.
M.choiceKeys = { healthText = "healthText", powerText = "powerText", healthTextPosition = "position",
    powerTextPosition = "position", nameAlign = "position", portraitSide = "side", portraitStyle = "portraitStyle",
    portraitRing = "ring", namePosition = "namePosition", nameColorMode = "nameColor", levelStyle = "level",
    healthColorMode = "healthColor", powerColorMode = "powerColor" }

local function Copy(value) return addon.ProfileCodec.Copy(value) end
M.Public = addon.IsPublic
M.Number = addon.IsNumber

local function Frame(side)
    return { enabled = true, hideBlizzard = true, scale = 100, barWidth = 180, healthHeight = 26,
        -- Target only: mirror the Player frame's look (side and visibility stay its own).
        matchPlayer = side == "right",
        -- Target only, while matched: mirror the Player's text alignment and
        -- horizontal offsets to the other side (off: same layout as the Player).
        mirrorText = false,
        showPower = true, powerHeight = 10,
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
        texture = "satin", font = "game", fontMedia = "Expressway", outline = false, shadow = true,
        -- The suite's text style: every text gets a crisp opaque 1px shadow plus
        -- a lighter second shadow 2px out (owner, layout version 11).
        liftedShadow = true, textColor = Copy(M.palette.text) }
end
M.frameDefaults = { player = Frame("left"), target = Frame("right") }
M.frameRanges = { scale = { 50, 200, 1 }, barWidth = { 100, 400, 1 }, healthHeight = { 10, 60, 1 },
    powerHeight = { 2, 30, 1 }, nameFontSize = { 8, 24, 1 }, healthFontSize = { 8, 24, 1 }, powerFontSize = { 6, 20, 1 },
    portraitScale = { 100, 200, 5 }, classSoftness = { 0, 100, 5 }, levelFontSize = { 6, 24, 1 },
    nameOffsetX = { -100, 100, 1 }, nameOffsetY = { -100, 100, 1 }, levelOffsetX = { -100, 100, 1 }, levelOffsetY = { -100, 100, 1 },
    healthTextOffsetX = { -100, 100, 1 }, healthTextOffsetY = { -100, 100, 1 },
    powerTextOffsetX = { -100, 100, 1 }, powerTextOffsetY = { -100, 100, 1 } }
-- Keys that describe placement/identity rather than style; Copy Style skips them.
M.identityKeys = { enabled = true, hideBlizzard = true, portraitSide = true, matchPlayer = true, mirrorText = true }
M.defaults = { player = Copy(M.frameDefaults.player), target = Copy(M.frameDefaults.target), layoutVersion = M.LAYOUT_VERSION }
