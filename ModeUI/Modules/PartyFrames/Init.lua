local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Frames > Party Frames: you and your party in the Onyx look, on one secure
-- group header (SecureGroupHeaderTemplate), so members join, leave and sort
-- in combat. Each member is a health bar with an optional power bar inside
-- the ModeUI border (Mode or Thin); texts and icons sit where the settings
-- put them, and an aura manager places healing buffs, group buffs,
-- defensives, each debuff type and crowd control in their own groups.
-- Blizzard's party frames give way while these are on. Unit values can be
-- secret and only reach widgets documented as accepting them. See
-- docs/PARTY_FRAMES.md.
-- Files: Init (this), Migrations, Driver, Native, Header, Layout, Build,
-- Update, Icons, Auras, AuraContainers, Dispel, Ghost, Preview, Settings,
-- SettingsElements, SettingsAuras.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Party Frames"], category = "frames", defaultEnabled = false,
    configDescription = L["You and your party in the Onyx look, with an aura manager. Configure outside combat."],
    modeLayout = { decorateOnly = true } }
addon.PartyFrames = M
-- The ID is also the saved-settings key (ModeUIDB profile modules.partyFrames).
addon:RegisterModule("partyFrames", M)

-- Version 2: taller frames, box corners and the Thin border, power style and
-- mana filters, shields and overshields, dispel effects by type, and aura
-- groups split into healing buffs, group buffs and one per debuff type, each
-- with its own icon width, height, border and glow (see Migrations.lua).
M.VERSION = 2
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
    name = Element(true, "TOPLEFT", 3, -3, 11),
    healthText = Element(false, "BOTTOMRIGHT", -3, 3, 10),
    status = Element(true, "CENTER", 0, 0, 11),
    role = Element(true, "TOPRIGHT", -2, -2, 12),
    leader = Element(true, "TOPLEFT", 4, 5, 12, "outside"),
    raidIcon = Element(true, "TOP", 0, 6, 14, "outside"),
    readyCheck = Element(true, "CENTER", 0, 0, 22),
    incoming = Element(true, "CENTER", 0, 0, 22),
}
M.elementRanges = { x = { -60, 60, 1 }, y = { -60, 60, 1 } }
M.elementSizeRanges = { text = { 6, 24, 1 }, icon = { 8, 40, 1 } }

-- The game's dispel types that party frames show apart (Blizzard's
-- DebuffTypeColor family; Bleed is Forever's type 11).
M.dispelTypes = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
M.dispelColorKeys = { Magic = "auraMagicColor", Curse = "auraCurseColor", Disease = "auraDiseaseColor",
    Poison = "auraPoisonColor", Bleed = "auraBleedColor" }

-- Aura groups: the aura manager. Each group picks which auras it shows (a game
-- filter string, plus a dispel type for the debuff groups, so the game decides
-- what matches and no secret aura field is compared) and where, with its own
-- icon look. Groups on the same anchor and place continue in one row, in this
-- order, growing the way the first shown one says.
M.auraGroups = { "heals", "buffs", "defensives", "magic", "curse", "disease", "poison", "bleed", "otherDebuffs",
    "crowdControl" }
M.auraGroupLabels = { heals = "Healing Buffs", buffs = "Group Buffs", defensives = "Defensives", magic = "Magic",
    curse = "Curse", disease = "Disease", poison = "Poison", bleed = "Bleed", otherDebuffs = "Other Debuffs",
    crowdControl = "Crowd Control" }
M.HELPFUL = { heals = true, buffs = true, defensives = true }
-- The dispel type each debuff group keeps (includeDispelTypes); Other Debuffs
-- keeps the rest (excludeDispelTypes).
M.groupDispelType = { magic = "Magic", curse = "Curse", disease = "Disease", poison = "Poison", bleed = "Bleed" }
local function TypeFilters()
    return { { id = "all", label = "All", filters = { "HARMFUL" } },
        { id = "mine", label = "Only If You Can Dispel", filters = { "HARMFUL|RAID" } } }
end
-- Which auras: each choice is one or more filter strings, shown one after
-- another (AuraUtil.AuraFilters; RAID_IN_COMBAT is what Blizzard's raid
-- frames show in combat: heals over time and short buffs).
M.auraFilters = {
    heals = {
        { id = "all", label = "All Healing Buffs", filters = { "HELPFUL|RAID_IN_COMBAT" } },
        { id = "mine", label = "Your Healing Buffs", filters = { "HELPFUL|PLAYER|RAID_IN_COMBAT" } },
    },
    buffs = {
        { id = "group", label = "Group Buffs", filters = { "HELPFUL|!RAID_IN_COMBAT" } },
        { id = "cast", label = "Ones You Can Cast", filters = { "HELPFUL|RAID|!RAID_IN_COMBAT" } },
        { id = "mine", label = "Yours", filters = { "HELPFUL|PLAYER|!RAID_IN_COMBAT" } },
        { id = "all", label = "All", filters = { "HELPFUL" } },
    },
    defensives = {
        { id = "both", label = "Big and External", filters = { "HELPFUL|EXTERNAL_DEFENSIVE", "HELPFUL|BIG_DEFENSIVE" } },
        { id = "external", label = "External Defensives", filters = { "HELPFUL|EXTERNAL_DEFENSIVE" } },
        { id = "big", label = "Big Defensives", filters = { "HELPFUL|BIG_DEFENSIVE" } },
        { id = "important", label = "Important", filters = { "HELPFUL|IMPORTANT" } },
    },
    magic = TypeFilters(), curse = TypeFilters(), disease = TypeFilters(), poison = TypeFilters(), bleed = TypeFilters(),
    otherDebuffs = {
        { id = "raid", label = "Raid Frame Debuffs", filters = { "HARMFUL|RAID_IN_COMBAT" } },
        { id = "all", label = "All Without a Type", filters = { "HARMFUL" } },
        { id = "mine", label = "Yours", filters = { "HARMFUL|PLAYER" } },
    },
    crowdControl = { { id = "all", label = "Crowd Control", filters = { "HARMFUL|CROWD_CONTROL" } } },
    -- The debuffs the dispel effects react to (Highlights tab).
    dispel = {
        { id = "mine", label = "Ones You Can Dispel", filters = { "HARMFUL|RAID" } },
        { id = "group", label = "Ones Your Group Can Dispel", filters = { "HARMFUL|RAID_PLAYER_DISPELLABLE" } },
        { id = "any", label = "Any With a Type", filters = { "HARMFUL" } },
    },
}
-- One group: shown or not, which auras, where (an anchor on or past the bars,
-- the way it grows, an offset, how many and per row) and how its icons look:
-- width and height, border (by type, Mode, custom or none) and its size, and a
-- glow (off by default) colored by type or a color of its own.
local function Group(show, filter, anchor, place, grow, width, height, max)
    return { show = show, filter = filter, anchor = anchor, place = place, grow = grow, x = 0, y = 0, width = width,
        height = height, max = max, perRow = max, spacing = 1, border = "type", borderSize = 1,
        borderColor = Copy(Kit.BORDER_COLOR), timer = true, timerText = false, count = true, tooltip = true,
        glow = "none", glowColor = "type", glowCustomColor = RGB(255, 209, 92) }
end
M.auraDefaults = {
    heals = Group(true, "all", "BOTTOMRIGHT", "inside", "left", 16, 12, 3),
    buffs = Group(false, "group", "TOPRIGHT", "inside", "left", 14, 10, 3),
    defensives = Group(true, "both", "CENTER", "inside", "right", 20, 16, 1),
    otherDebuffs = Group(true, "raid", "BOTTOMLEFT", "inside", "right", 18, 14, 2),
    crowdControl = Group(false, "all", "LEFT", "outside", "left", 24, 20, 1),
}
-- Every debuff type starts in one row at the bottom left, before Other Debuffs.
for group in pairs(M.groupDispelType) do M.auraDefaults[group] = Group(true, "all", "BOTTOMLEFT", "inside", "right", 18, 14, 2) end
M.auraRanges = { x = { -80, 80, 1 }, y = { -80, 80, 1 }, width = { 8, 48, 1 }, height = { 8, 48, 1 }, max = { 1, 10, 1 },
    perRow = { 1, 10, 1 }, spacing = { 0, 8, 1 }, borderSize = { 1, 3, 1 } }
M.growChoices = { { id = "right", label = "Right" }, { id = "left", label = "Left" }, { id = "up", label = "Up" },
    { id = "down", label = "Down" } }

M.choices = {
    growth = { { id = "down", label = "Down" }, { id = "up", label = "Up" }, { id = "right", label = "Right" },
        { id = "left", label = "Left" } },
    sortBy = { { id = "group", label = "Party Order" }, { id = "role", label = "Role" } },
    borderStyle = Kit.BORDER_CHOICES,
    healthColorMode = { { id = "class", label = "Class Color" }, { id = "default", label = "Onyx" }, { id = "custom", label = "Custom" } },
    powerColorMode = { { id = "type", label = "Power Type" }, { id = "custom", label = "Custom" } },
    powerShown = { { id = "all", label = "Everyone" }, { id = "healers", label = "Healers" }, { id = "mana", label = "Mana Users" },
        { id = "healerMana", label = "Healer Mana" }, { id = "none", label = "No One" } },
    powerStyle = { { id = "below", label = "Below Health" }, { id = "inset", label = "Inset" } },
    powerAlign = { { id = "LEFT", label = "Left" }, { id = "CENTER", label = "Center" }, { id = "RIGHT", label = "Right" } },
    nameColorMode = { { id = "class", label = "Class Color" }, { id = "text", label = "Text Color" }, { id = "custom", label = "Custom" } },
    healthText = { { id = "percent", label = "Percent" }, { id = "percentPlain", label = "Percent, No Sign" },
        { id = "current", label = "Current Health" }, { id = "deficit", label = "Missing Health" } },
    fillDirection = { { id = "standard", label = "Left to Right" }, { id = "reverse", label = "Right to Left" } },
    highlightStyle = { { id = "border", label = "Border" }, { id = "fill", label = "Tint" }, { id = "none", label = "None" } },
    auraBorder = { { id = "type", label = "By Type" }, { id = "mode", label = "Mode" }, { id = "custom", label = "Custom" },
        { id = "none", label = "None" } },
    auraGlow = { { id = "none", label = "Off" }, { id = "gcd", label = "GCD Flash" }, { id = "soft", label = "Soft Glow" } },
    auraGlowColor = { { id = "type", label = "By Type" }, { id = "custom", label = "Custom" } },
    place = { { id = "inside", label = "Inside" }, { id = "outside", label = "Outside" } },
}

-- What each debuff type does to a member that has it (Highlights tab).
local function Effects() return { border = true, health = false, gradient = false } end
M.defaults = {
    version = M.VERSION,
    -- Group layout.
    hideBlizzard = true, showSolo = false, showPlayer = true, reverseOrder = false, sortBy = "group", growth = "down", spacing = 4, scale = 100,
    -- Each member: bars inside the ModeUI border, Mode (2px) or Thin (1px),
    -- with box corners as round as the chat windows'.
    width = 132, healthHeight = 44, borderStyle = "mode", corner = 7,
    powerHeight = 6, powerShown = "all", powerStyle = "below", powerWidth = 70, powerAlign = "CENTER", powerX = 0, powerY = 3,
    foregroundTexture = "mode", backgroundTexture = "slate", healthOpacity = 100, backgroundOpacity = 70,
    powerForegroundTexture = "mode", powerBackgroundTexture = "slate", fillDirection = "standard", fillEdge = true,
    healthColorMode = "class", healthColor = Copy(P.green), powerColorMode = "type", powerColor = Copy(P.mana),
    -- Out of range, dead and offline members fade.
    rangeFade = true, rangeOpacity = 45, deadOpacity = 70,
    -- Incoming heals, shields riding on the health and overshields filling
    -- back from full health, in Mode Slate Hatch by default.
    showHealPrediction = true, healTexture = "flat", healPredictionColor = RGB(92, 214, 132), healPredictionOpacity = 45,
    showAbsorbs = true, shieldTexture = "slateHatch", absorbColor = RGB(214, 236, 255), absorbOpacity = 60,
    showOvershields = true, overshieldTexture = "slateHatch", overshieldColor = RGB(240, 246, 255), overshieldOpacity = 80,
    -- Highlights: your target and the mouse.
    targetHighlight = "border", targetColor = Copy(P.accent), hoverHighlight = true,
    -- Debuff effects by type: border, health color and a gradient, each per type.
    dispelFilter = "mine", dispelGradientOpacity = 60,
    dispel = { Magic = Effects(), Curse = Effects(), Disease = Effects(), Poison = Effects(), Bleed = Effects() },
    -- Text.
    nameColorMode = "class", nameColor = Copy(P.text), healthText = "percent", nameWidth = 85,
    font = "game", fontMedia = "Expressway", outline = false, shadow = true, liftedShadow = true, slug = false,
    textColor = Copy(P.text), hideDamagerRole = false,
    -- Aura rims, glows and dispel effects by type (Blizzard's DebuffTypeColor family).
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

M.ranges = { spacing = { 0, 40, 1 }, scale = { 50, 200, 1 }, width = { 60, 300, 1 }, healthHeight = { 12, 100, 1 },
    corner = { 2, 16, 1 }, powerHeight = { 2, 30, 1 }, powerWidth = { 20, 100, 5 }, powerX = { -60, 60, 1 },
    powerY = { -60, 60, 1 }, healthOpacity = { 10, 100, 5 }, backgroundOpacity = { 0, 100, 5 },
    rangeOpacity = { 10, 100, 5 }, deadOpacity = { 10, 100, 5 }, healPredictionOpacity = { 10, 100, 5 },
    absorbOpacity = { 10, 100, 5 }, overshieldOpacity = { 10, 100, 5 }, dispelGradientOpacity = { 10, 100, 5 },
    nameWidth = { 30, 100, 5 } }
for _, element in ipairs(M.elements) do
    local sizes = M.textElements[element] and M.elementSizeRanges.text or M.elementSizeRanges.icon
    M.ranges[element .. "X"], M.ranges[element .. "Y"], M.ranges[element .. "Size"] = M.elementRanges.x, M.elementRanges.y, sizes
end
M.colorKeys = { healthColor = true, powerColor = true, healPredictionColor = true, absorbColor = true, overshieldColor = true,
    targetColor = true, nameColor = true, textColor = true, auraMagicColor = true, auraCurseColor = true,
    auraDiseaseColor = true, auraPoisonColor = true, auraBleedColor = true, auraNoTypeColor = true, auraTimerColor = true }
-- Setting key -> its choice list; element anchors and places are checked with them.
M.choiceKeys = { growth = "growth", sortBy = "sortBy", borderStyle = "borderStyle", healthColorMode = "healthColorMode",
    powerColorMode = "powerColorMode", powerShown = "powerShown", powerStyle = "powerStyle", powerAlign = "powerAlign",
    nameColorMode = "nameColorMode", healthText = "healthText", fillDirection = "fillDirection", targetHighlight = "highlightStyle" }
M.groupChoiceKeys = { border = "auraBorder", glow = "auraGlow", glowColor = "auraGlowColor", grow = "growChoices",
    anchor = "anchors", place = "place" }
-- Texture choices are shared with every bar (Shared/Kit/Shape.lua).
M.TextureChoices = Kit.BarTextureChoices
M.FillChoices = Kit.FillTextureChoices
-- Preview samples (session only): one member, a party, or raid sizes laid out
-- in groups of five, to see how the layout scales.
M.previewSamples = { { id = "one", label = "One", count = 1, scale = 1 }, { id = "party", label = "Party", count = 5, scale = 0.8 },
    { id = "raid10", label = "Raid 10", count = 10, scale = 0.62 }, { id = "raid20", label = "Raid 20", count = 20, scale = 0.5 },
    { id = "raid40", label = "Raid 40", count = 40, scale = 0.38 } }
