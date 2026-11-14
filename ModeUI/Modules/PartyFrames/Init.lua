local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Frames > Party Frames: you and your party in the Onyx look, on one secure
-- group header (SecureGroupHeaderTemplate), so members join, leave and sort
-- in combat. Each member is a health bar with an optional power bar inside
-- the ModeUI border; texts and icons sit where the settings put them, and an
-- aura manager places buffs, debuffs, dispellable debuffs, defensives and
-- crowd control in their own groups. Blizzard's party frames give way while
-- these are on. Unit values can be secret and only reach widgets documented
-- as accepting them. See docs/PARTY_FRAMES.md.
-- Files: Init (this), Migrations, Driver, Native, Header, Layout, Build,
-- Update, Icons, Auras, AuraContainers, Ghost, Preview, Settings, SettingsAuras.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Party Frames"], category = "frames", defaultEnabled = false,
    configDescription = L["You and your party in the Onyx look, with an aura manager. Configure outside combat."],
    modeLayout = { decorateOnly = true } }
addon.PartyFrames = M
-- The ID is also the saved-settings key (ModeUIDB profile modules.partyFrames).
addon:RegisterModule("partyFrames", M)

M.VERSION = 1
M.ELEMENT_ID = "partyFrames"
M.MAX_MEMBERS = 5
M.defaultPosition = { target = "screen", placement = "center", x = -520, y = 120 }
local P, RGB = Kit.palette, Kit.RGB
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Points around (and inside) a member's bars, read like a compass.
M.anchors = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
M.anchorLabels = { TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right", LEFT = "Left", CENTER = "Center",
    RIGHT = "Right", BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right" }

-- Texts and icons on a member, each with its own switch, anchor, offset and
-- size (keys <element>Show, <element>Anchor, <element>X, <element>Y,
-- <element>Size). Inside: on the bars at the anchor. Outside: past the bars'
-- edge on the anchor's side (Center stays inside).
M.elements = { "name", "healthText", "status", "role", "leader", "raidIcon", "readyCheck", "incoming" }
M.elementLabels = { name = "Name", healthText = "Health Text", status = "Dead and Offline", role = "Role",
    leader = "Leader", raidIcon = "Raid Marker", readyCheck = "Ready Check", incoming = "Summon and Resurrect" }
M.textElements = { name = true, healthText = true, status = true }
local function Element(show, anchor, x, y, size, place)
    return { show = show, anchor = anchor, x = x, y = y, size = size, place = place or "inside" }
end
M.elementDefaults = {
    name = Element(true, "TOPLEFT", 3, -2, 11),
    healthText = Element(false, "BOTTOMRIGHT", -3, 2, 10),
    status = Element(true, "CENTER", 0, 0, 11),
    role = Element(true, "TOPRIGHT", -2, -2, 12),
    leader = Element(true, "TOPLEFT", 4, 5, 12, "outside"),
    raidIcon = Element(true, "TOP", 0, 6, 14, "outside"),
    readyCheck = Element(true, "CENTER", 0, 0, 22),
    incoming = Element(true, "CENTER", 0, 0, 22),
}
M.elementRanges = { x = { -60, 60, 1 }, y = { -60, 60, 1 } }
M.elementSizeRanges = { text = { 6, 24, 1 }, icon = { 8, 40, 1 } }

-- Aura groups: the aura manager. Each group picks which auras it shows (a game
-- filter string, so the game decides what matches and no secret aura field is
-- compared) and where, with its own icon look.
M.auraGroups = { "buffs", "debuffs", "dispellable", "defensives", "crowdControl" }
M.auraGroupLabels = { buffs = "Buffs", debuffs = "Debuffs", dispellable = "Dispellable", defensives = "Defensives",
    crowdControl = "Crowd Control" }
-- Which auras: each choice is one or more filter strings, shown one after
-- another (AuraUtil.AuraFilters; RAID_IN_COMBAT is what Blizzard's raid
-- frames show in combat).
M.auraFilters = {
    buffs = {
        { id = "mine", label = "Yours", filters = { "HELPFUL|PLAYER" } },
        { id = "mineRaid", label = "Your Heals Over Time", filters = { "HELPFUL|PLAYER|RAID_IN_COMBAT" } },
        { id = "raid", label = "Raid Frame Buffs", filters = { "HELPFUL|RAID_IN_COMBAT" } },
        { id = "cast", label = "Ones You Can Cast", filters = { "HELPFUL|RAID" } },
        { id = "all", label = "All", filters = { "HELPFUL" } },
    },
    debuffs = {
        { id = "raid", label = "Raid Frame Debuffs", filters = { "HARMFUL|RAID_IN_COMBAT" } },
        { id = "all", label = "All", filters = { "HARMFUL" } },
        { id = "notDispellable", label = "Ones You Can't Dispel", filters = { "HARMFUL|!RAID" } },
        { id = "mine", label = "Yours", filters = { "HARMFUL|PLAYER" } },
    },
    dispellable = {
        { id = "mine", label = "Ones You Can Dispel", filters = { "HARMFUL|RAID" } },
        { id = "group", label = "Ones Your Group Can Dispel", filters = { "HARMFUL|RAID_PLAYER_DISPELLABLE" } },
        { id = "any", label = "Any Dispellable", filters = { "HARMFUL|DISPELLABLE" } },
    },
    defensives = {
        { id = "both", label = "Big and External", filters = { "HELPFUL|EXTERNAL_DEFENSIVE", "HELPFUL|BIG_DEFENSIVE" } },
        { id = "external", label = "External Defensives", filters = { "HELPFUL|EXTERNAL_DEFENSIVE" } },
        { id = "big", label = "Big Defensives", filters = { "HELPFUL|BIG_DEFENSIVE" } },
        { id = "important", label = "Important", filters = { "HELPFUL|IMPORTANT" } },
    },
    crowdControl = {
        { id = "all", label = "Crowd Control", filters = { "HARMFUL|CROWD_CONTROL" } },
    },
}
-- One group: shown or not, which auras, where (an anchor on or past the bars,
-- the way it grows, an offset, how many and per row) and how its icons look.
local function Group(show, filter, anchor, place, grow, size, max)
    return { show = show, filter = filter, anchor = anchor, place = place, grow = grow, x = 0, y = 0, size = size,
        max = max, perRow = max, spacing = 1, shape = "cropped", border = "type", timer = true, timerText = false,
        count = true, tooltip = true }
end
M.auraDefaults = {
    buffs = Group(true, "mine", "BOTTOMRIGHT", "inside", "left", 16, 3),
    debuffs = Group(true, "raid", "BOTTOMLEFT", "inside", "right", 18, 3),
    dispellable = Group(false, "mine", "RIGHT", "outside", "right", 22, 2),
    defensives = Group(true, "both", "CENTER", "inside", "right", 18, 1),
    crowdControl = Group(false, "all", "LEFT", "outside", "left", 22, 1),
}
M.auraRanges = { x = { -80, 80, 1 }, y = { -80, 80, 1 }, size = { 8, 40, 1 }, max = { 1, 10, 1 }, perRow = { 1, 10, 1 },
    spacing = { 0, 8, 1 } }
M.growChoices = { { id = "right", label = "Right" }, { id = "left", label = "Left" }, { id = "up", label = "Up" },
    { id = "down", label = "Down" } }

M.choices = {
    growth = { { id = "down", label = "Down" }, { id = "up", label = "Up" }, { id = "right", label = "Right" },
        { id = "left", label = "Left" } },
    sortBy = { { id = "group", label = "Party Order" }, { id = "role", label = "Role" } },
    healthColorMode = { { id = "class", label = "Class Color" }, { id = "default", label = "Onyx" }, { id = "custom", label = "Custom" } },
    powerColorMode = { { id = "type", label = "Power Type" }, { id = "custom", label = "Custom" } },
    powerShown = { { id = "all", label = "Everyone" }, { id = "healers", label = "Healers" }, { id = "none", label = "No One" } },
    nameColorMode = { { id = "class", label = "Class Color" }, { id = "text", label = "Text Color" }, { id = "custom", label = "Custom" } },
    healthText = { { id = "percent", label = "Percent" }, { id = "current", label = "Current Health" },
        { id = "deficit", label = "Missing Health" } },
    fillDirection = { { id = "standard", label = "Left to Right" }, { id = "reverse", label = "Right to Left" } },
    highlightStyle = { { id = "border", label = "Border" }, { id = "fill", label = "Tint" }, { id = "none", label = "None" } },
    auraShape = { { id = "cropped", label = "Cropped" }, { id = "square", label = "Square" } },
    auraBorder = { { id = "type", label = "By Type" }, { id = "mode", label = "Mode" } },
    place = { { id = "inside", label = "Inside" }, { id = "outside", label = "Outside" } },
}

M.defaults = {
    version = M.VERSION,
    -- Group layout.
    hideBlizzard = true, showSolo = false, showPlayer = true, reverseOrder = false, sortBy = "group", growth = "down", spacing = 4, scale = 100,
    -- Each member: bars inside the ModeUI border.
    width = 132, healthHeight = 34, powerHeight = 5, powerShown = "all",
    foregroundTexture = "mode", backgroundTexture = "slate", healthOpacity = 100, backgroundOpacity = 70,
    powerForegroundTexture = "mode", powerBackgroundTexture = "slate", fillDirection = "standard", fillEdge = true,
    healthColorMode = "class", healthColor = Copy(P.green), powerColorMode = "type", powerColor = Copy(P.mana),
    -- Out of range, dead and offline members fade.
    rangeFade = true, rangeOpacity = 45, deadOpacity = 70,
    -- Incoming heals and absorb shields over the health bar.
    showHealPrediction = true, healPredictionColor = RGB(92, 214, 132), healPredictionOpacity = 45,
    showAbsorbs = true, absorbColor = RGB(214, 236, 255), absorbOpacity = 45,
    -- Highlights: your target, and a debuff you can dispel.
    targetHighlight = "border", targetColor = Copy(P.accent),
    dispelHighlight = "border", dispelFilter = "mine", hoverHighlight = true,
    -- Text.
    nameColorMode = "class", nameColor = Copy(P.text), healthText = "percent", nameWidth = 85,
    font = "game", fontMedia = "Expressway", outline = false, shadow = true, liftedShadow = true, slug = false,
    textColor = Copy(P.text), hideDamagerRole = false,
    -- Aura rims by dispel type (Blizzard's DebuffTypeColor family).
    auraMagicColor = RGB(51, 153, 255), auraCurseColor = RGB(170, 85, 255), auraDiseaseColor = RGB(204, 136, 51),
    auraPoisonColor = RGB(85, 187, 85), auraBleedColor = RGB(200, 45, 45), auraNoTypeColor = Copy(Kit.BORDER_COLOR),
    auraTimerColor = Copy(P.cooldown),
}
for _, element in ipairs(M.elements) do
    for key, value in pairs(M.elementDefaults[element]) do
        M.defaults[element .. key:sub(1, 1):upper() .. key:sub(2)] = value
    end
end
M.defaults.auras = Copy(M.auraDefaults)

M.ranges = { spacing = { 0, 40, 1 }, scale = { 50, 200, 1 }, width = { 60, 300, 1 }, healthHeight = { 12, 80, 1 },
    powerHeight = { 2, 20, 1 }, healthOpacity = { 10, 100, 5 }, backgroundOpacity = { 0, 100, 5 },
    rangeOpacity = { 10, 100, 5 }, deadOpacity = { 10, 100, 5 }, healPredictionOpacity = { 10, 100, 5 },
    absorbOpacity = { 10, 100, 5 }, nameWidth = { 30, 100, 5 } }
for _, element in ipairs(M.elements) do
    local sizes = M.textElements[element] and M.elementSizeRanges.text or M.elementSizeRanges.icon
    M.ranges[element .. "X"], M.ranges[element .. "Y"], M.ranges[element .. "Size"] = M.elementRanges.x, M.elementRanges.y, sizes
end
M.colorKeys = { healthColor = true, powerColor = true, healPredictionColor = true, absorbColor = true, targetColor = true,
    nameColor = true, textColor = true, auraMagicColor = true, auraCurseColor = true, auraDiseaseColor = true,
    auraPoisonColor = true, auraBleedColor = true, auraNoTypeColor = true, auraTimerColor = true }
-- Setting key -> its choice list; element anchors and places are checked with them.
M.choiceKeys = { growth = "growth", sortBy = "sortBy", healthColorMode = "healthColorMode",
    powerColorMode = "powerColorMode", powerShown = "powerShown", nameColorMode = "nameColorMode", healthText = "healthText",
    fillDirection = "fillDirection", targetHighlight = "highlightStyle", dispelHighlight = "highlightStyle" }
M.dispelColorKeys = { Magic = "auraMagicColor", Curse = "auraCurseColor", Disease = "auraDiseaseColor",
    Poison = "auraPoisonColor", Bleed = "auraBleedColor" }
-- Texture choices are shared with every bar (Shared/Kit/Shape.lua).
M.TextureChoices = Kit.BarTextureChoices
