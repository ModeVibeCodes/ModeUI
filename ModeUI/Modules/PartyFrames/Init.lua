local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Frames > Party Frames: you and your party in the Mode design language
-- (docs/DESIGN_LANGUAGE.md), on one secure group header
-- (SecureGroupHeaderTemplate), so members join, leave and sort in combat.
-- Each member is a health bar with a 3px power bar inside the `group` edge
-- (1px Gunmetal, members 1px apart), Combined shields on health, a Gradient
-- name and health text colored by health; texts and icons sit where the
-- settings put them, and an aura manager places healing buffs, group buffs,
-- defensives, each debuff type and crowd control in their own groups.
-- Blizzard's party frames give way while these are on. Unit values can be
-- secret and only reach widgets documented as accepting them. See
-- docs/PARTY_FRAMES.md.
-- Files: Init (this), AuraInit, Layouts, Migrations, Driver, Native, Header, Layout, Build,
-- Update, Icons, Auras, AuraContainers, Dispel, Samples, Ghost, Picker,
-- Preview, PreviewTools, Settings, SettingsPower, SettingsElements,
-- SettingsAuras. Aura declarations: AuraInit; the Mode-Default layout: Layouts.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Party Frames"], category = "frames", defaultEnabled = false, layout = "split",
    configDescription = L["You and your party in the Mode look, with an aura manager. Configure outside combat."],
    modeLayout = { decorateOnly = true } }
addon.PartyFrames = M
-- The ID is also the saved-settings key (ModeUIDB profile modules.partyFrames).
addon:RegisterModule("partyFrames", M)

-- Version 2: taller frames, box corners and the Thin border, power style and
-- mana filters, shields and overshields, dispel effects by type, and aura
-- groups split into healing buffs, group buffs and one per debuff type, each
-- with its own icon width, height, border and glow (see Migrations.lua).
-- Version 3: 8px taller, Spacing 1, the power bar's own opacity, fill and
-- text, Dispellable by You first among debuffs (the type groups show the rest)
-- and three Tracked Buffs groups.
-- Version 4: the Mode design language: the group edge (no Border or Corner
-- Size), 150 x 34 + 3 power, Mode Gradient on Mode BG, Combined shields (the
-- shield and overshield textures and colors retire), Gradient names, health
-- text colored by health, the dispel Gradient by default, an aggro rim, Geist.
-- Version 5: Mode Glass health by default; shields get their own tab with a
-- texture, a color (follow the health or custom) and an opacity.
-- Version 6: auras wear the frameThin edge (Border Size 1 or 2; Mode is the
-- Gunmetal metal), and auras without a type take the Gunmetal rim.
-- Version 7: semi-transparent empty bars (Slate at 60%, no black plate behind).
M.VERSION = 7
local EMPTY = math.floor(addon.Style.Tone.emptyAlpha * 100 + 0.5)
M.ELEMENT_ID = "partyFrames"
M.MAX_MEMBERS = 5
M.defaultPosition = { target = "screen", placement = "center", x = -520, y = 120 }
local P, Tone = Kit.palette, addon.Style.Tone
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
    name = Element(true, "LEFT", 17, 0, 12),
    healthText = Element(true, "RIGHT", -4, 0, 11),
    status = Element(true, "CENTER", 0, 0, 11),
    role = Element(true, "LEFT", 2, 0, 12),
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

-- Aura groups, their filters and defaults are in AuraInit.lua.

M.choices = {
    growth = { { id = "down", label = "Down" }, { id = "up", label = "Up" }, { id = "right", label = "Right" },
        { id = "left", label = "Left" } },
    sortBy = { { id = "group", label = "Party Order" }, { id = "role", label = "Role" } },
    healthColorMode = { { id = "class", label = "Class Color" }, { id = "default", label = "Dark" }, { id = "custom", label = "Custom" } },
    shieldsColorMode = { { id = "health", label = "Follow Health" }, { id = "custom", label = "Custom" } },
    powerColorMode = { { id = "type", label = "Power Type" }, { id = "custom", label = "Custom" } },
    powerShown = { { id = "all", label = "Everyone" }, { id = "healers", label = "Healers" }, { id = "mana", label = "Mana Users" },
        { id = "healerMana", label = "Healer Mana" }, { id = "none", label = "No One" } },
    powerStyle = { { id = "below", label = "Below Health" }, { id = "inset", label = "Inset" } },
    powerAlign = { { id = "LEFT", label = "Left" }, { id = "CENTER", label = "Center" }, { id = "RIGHT", label = "Right" } },
    powerText = { { id = "percent", label = "Percent" }, { id = "percentPlain", label = "Percent, No Sign" }, { id = "current", label = "Current" } },
    arrange = { { id = "vertical", label = "Vertical" }, { id = "horizontal", label = "Horizontal" } },
    nameColorMode = { { id = "gradient", label = "Gradient" }, { id = "class", label = "Soft Class" }, { id = "text", label = "Text Color" },
        { id = "custom", label = "Custom" } },
    healthTextColor = { { id = "health", label = "By Health" }, { id = "text", label = "Text Color" } },
    healthText = { { id = "percent", label = "Percent" }, { id = "percentPlain", label = "Percent, No Sign" },
        { id = "current", label = "Current Health" }, { id = "deficit", label = "Missing Health" } },
    fillDirection = { { id = "standard", label = "Left to Right" }, { id = "reverse", label = "Right to Left" } },
    highlightStyle = { { id = "border", label = "Border" }, { id = "fill", label = "Tint" }, { id = "none", label = "None" } },
    auraBorder = { { id = "type", label = "By Type" }, { id = "mode", label = "Mode" }, { id = "custom", label = "Custom" },
        { id = "none", label = "None" } },
    auraGlow = { { id = "none", label = "Off" }, { id = "gcd", label = "GCD Flash" }, { id = "soft", label = "Soft Glow" } },
    auraGlowColor = { { id = "type", label = "By Type" }, { id = "custom", label = "Custom" } },
    place = { { id = "inside", label = "Inside" }, { id = "outside", label = "Outside" } },
    dispelFrom = { { id = "top", label = "Top" }, { id = "bottom", label = "Bottom" } },
    edgeStyle = addon.Style.EdgeStyleChoices(),
    edgeMetal = addon.Style.EdgeMetalChoices(),
}

-- What each debuff type does to a member that has it (Highlights tab).
local function Effects() return { border = false, health = false, gradient = true } end
M.defaults = {
    version = M.VERSION,
    -- Group layout.
    hideBlizzard = true, showSolo = false, showPlayer = true, reverseOrder = false, sortBy = "group", growth = "down", spacing = 1, scale = 100,
    -- Each member: 150 x 34 health and 3px power in the group edge, Mode
    -- Glass on Mode BG.
    width = 150, healthHeight = 34,
    foregroundTexture = "media:Mode Glass", backgroundTexture = "media:Mode BG", healthOpacity = 100, backgroundOpacity = EMPTY,
    fillDirection = "standard", fillEdge = true, healthColorMode = "class", healthColor = Copy(P.green),
    -- The member's border, its inset power bar's and the dispel rim's shape
    -- (docs/DESIGN_LANGUAGE.md, "Choosing a border"): Mode-Blizz in its own
    -- metal (owner, November 17, 2026).
    edgeStyle = "blizz", edgeMetal = "default",
    -- Power Bars and Resources: who shows it, where, how it looks, its text.
    powerShown = "all", powerStyle = "below", powerHeight = 3, powerWidth = 70, powerAlign = "CENTER", powerX = 0, powerY = 3,
    powerForegroundTexture = "media:Mode Gradient", powerBackgroundTexture = "media:Mode BG", powerOpacity = 100, powerBackgroundOpacity = EMPTY,
    powerFillDirection = "standard", powerColorMode = "type", powerColor = Copy(P.mana),
    powerTextShow = false, powerText = "percent", powerTextSize = 9, powerTextAlign = "CENTER", powerTextX = 0, powerTextY = 0,
    -- Out of range, dead and offline members fade.
    rangeFade = true, rangeOpacity = 55, deadOpacity = 70,
    -- Incoming heals ride on the health; shields are Combined (Style.Shield):
    -- on the health's end, and the whole shield back from full health.
    showHealPrediction = true, healTexture = "flat", healPredictionColor = Copy(Tone.healPrediction), healPredictionOpacity = 45,
    showAbsorbs = true, showOvershields = true,
    -- The shields' look (Shields tab, Shield:SetLook): Mode Shield, tinted
    -- from the health, at the standard strength.
    shieldsTexture = "Shield", shieldsColorMode = "health", shieldsColor = Copy(addon.Style.Tone.textBright), shieldsOpacity = 100,
    -- Highlights: your target (the rim in Ivory), aggro (the rim in the
    -- hostile red) and the mouse.
    targetHighlight = "border", targetColor = Copy(addon.Style.Tone.ivory), hoverHighlight = true, aggroHighlight = true,
    -- The Prism glow round a member (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian
    -- theme"): on mouseover, and on your focus, in the member's class color.
    hoverGlow = false, focusGlow = false,
    -- Debuff effects by type: border, health color and a gradient from the
    -- top edge (56% fading over 72% of the health), each per type.
    dispelFilter = "mine", dispelGradientOpacity = 56,
    -- Where the gradient rises from: the top edge, or the bottom (Backlit,
    -- Mode-Obsidian).
    dispelFrom = "top",
    dispel = { Magic = Effects(), Curse = Effects(), Disease = Effects(), Poison = Effects(), Bleed = Effects() },
    -- Text.
    nameColorMode = "gradient", nameColor = Copy(P.text), healthText = "percent", healthTextColor = "health", healthTextGlow = true, nameWidth = 60,
    font = "game", fontMedia = addon.Style.FONT_DEFAULT, outline = false, shadow = true, liftedShadow = false, slug = false,
    -- After Name: the role icon on the name's end (its Offset X and Y from there).
    textColor = Copy(P.text), hideDamagerRole = false, roleAfterName = false,
    -- Aura rims, glows and dispel effects by type (Blizzard's DebuffTypeColor family).
    auraMagicColor = Copy(Tone.debuffType.Magic), auraCurseColor = Copy(Tone.debuffType.Curse),
    auraDiseaseColor = Copy(Tone.debuffType.Disease), auraPoisonColor = Copy(Tone.debuffType.Poison),
    auraBleedColor = Copy(Tone.debuffType.Bleed), auraNoTypeColor = Copy(Tone.gunmetal.mid),
    auraTimerColor = Copy(P.cooldown),
}
for _, element in ipairs(M.elements) do
    for key, value in pairs(M.elementDefaults[element]) do
        M.defaults[element .. key:sub(1, 1):upper() .. key:sub(2)] = value
    end
end

M.ranges = { spacing = { 0, 40, 1 }, scale = { 50, 200, 1 }, width = { 60, 300, 1 }, healthHeight = { 12, 100, 1 },
    powerHeight = { 2, 30, 1 }, powerWidth = { 20, 100, 5 }, powerX = { -60, 60, 1 },
    powerY = { -60, 60, 1 }, powerOpacity = { 10, 100, 5 }, powerBackgroundOpacity = { 0, 100, 5 },
    powerTextSize = { 6, 20, 1 }, powerTextX = { -60, 60, 1 }, powerTextY = { -60, 60, 1 }, healthOpacity = { 10, 100, 5 }, backgroundOpacity = { 0, 100, 5 },
    rangeOpacity = { 10, 100, 5 }, deadOpacity = { 10, 100, 5 }, healPredictionOpacity = { 10, 100, 5 },
    dispelGradientOpacity = { 10, 100, 1 }, shieldsOpacity = { 10, 200, 5 },
    nameWidth = { 30, 100, 5 } }
for _, element in ipairs(M.elements) do
    local sizes = M.textElements[element] and M.elementSizeRanges.text or M.elementSizeRanges.icon
    M.ranges[element .. "X"], M.ranges[element .. "Y"], M.ranges[element .. "Size"] = M.elementRanges.x, M.elementRanges.y, sizes
end
M.colorKeys = { healthColor = true, powerColor = true, healPredictionColor = true, shieldsColor = true,
    targetColor = true, nameColor = true, textColor = true, auraMagicColor = true, auraCurseColor = true,
    auraDiseaseColor = true, auraPoisonColor = true, auraBleedColor = true, auraNoTypeColor = true, auraTimerColor = true }
-- Setting key -> its choice list; element anchors and places are checked with them.
M.choiceKeys = { growth = "growth", sortBy = "sortBy", healthColorMode = "healthColorMode", shieldsColorMode = "shieldsColorMode",
    powerColorMode = "powerColorMode", powerShown = "powerShown", powerStyle = "powerStyle", powerAlign = "powerAlign",
    nameColorMode = "nameColorMode", healthText = "healthText", healthTextColor = "healthTextColor", fillDirection = "fillDirection", targetHighlight = "highlightStyle",
    powerFillDirection = "fillDirection", powerText = "powerText", powerTextAlign = "powerAlign",
    edgeStyle = "edgeStyle", edgeMetal = "edgeMetal", dispelFrom = "dispelFrom" }
M.groupChoiceKeys = { border = "auraBorder", glow = "auraGlow", glowColor = "auraGlowColor", grow = "growChoices",
    anchor = "anchors", place = "place" }
-- Texture choices are shared with every bar (Shared/Kit/Shape.lua).
M.TextureChoices = Kit.BarTextureChoices
M.FillChoices = Kit.FillTextureChoices
-- Preview samples (session only): one member, a party, or raid sizes laid out
-- in groups of five. Each has a scale it keeps unless the layout would not
-- fit; the preview grows taller to hold it.
M.previewSamples = { { id = "one", label = "One", count = 1, scale = 1 }, { id = "party", label = "Party", count = 5, scale = 0.8 },
    { id = "raid10", label = "Raid 10", count = 10, scale = 0.62 }, { id = "raid20", label = "Raid 20", count = 20, scale = 0.5 },
    { id = "raid40", label = "Raid 40", count = 40, scale = 0.38 } }
