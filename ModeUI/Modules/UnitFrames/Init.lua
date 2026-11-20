local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Frames > Unit Frames: secure Player, Target, Target of Target, Focus and Target
-- of Focus frames in the locked Onyx skin
-- (round portrait capping a rounded bar block inside a slate rim).
-- Forever runs the mainline client, so unit values can be secret. They are only
-- handed to widgets/formatters Blizzard documents as accepting secret values;
-- never compared, tested or used in arithmetic here. See docs/UNIT_FRAMES.md.
-- Files: Init (this), Layouts, TextSlots, Migrations, Driver, Native, Layout, Texts, Build, Update,
-- Combo, CastBar, Auras, Status, Preview, Settings, SettingsExtra, SettingsText.
local L = addon.L
local M = { title = L["Unit Frames"], category = "frames", defaultEnabled = true, layout = "strip",
    configDescription = L["Player, Target, Target of Target and Focus frames in the Mode look. Configure outside combat."],
    icon = "UnitFrames",
    -- The settings page keeps its own sections; the Mode layer restyles headings.
    modeLayout = { decorateOnly = true } }
addon.UnitFrames = M
addon:RegisterModule("unitFrames", M)
-- Play The Game Tools carried these frames first: on ModeUI's first start the
-- active PTG profile's unitFrames settings and these positions are copied
-- once (Shared/Runtime/DB.lua).
M.ptgImport = { positions = { "unitFramesPlayer", "unitFramesTarget" } }

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
-- Each frame's stand-in (the same size as the frame, laid out with it) is a
-- target other elements can pick, for Match Width and Match Height and for
-- anchoring where an element takes any ModeUI element. "ModeUI" tells them
-- from Blizzard's own frames in the lists.
for _, unit in ipairs({ "player", "target", "targettarget", "focus", "focustarget" }) do
    addon.Positioning:AddTarget(M.elementIds[unit], addon.L["ModeUI " .. M.titles[unit]], "ModeUI" .. M.frameNames[unit] .. "UnitFramePreview")
end
-- The Player and Target bar blocks (the stand-in's block, its border on its
-- edge) are targets too (owner, November 18, 2026): something hung from a
-- block stays on its border whatever Portrait Size, Health Height or Frame
-- Width do to the frame around it.
M.barsElementIds = { player = "unitFramesPlayerBars", target = "unitFramesTargetBars" }
function M.BarsFrameName(unit) return "ModeUI" .. M.frameNames[unit] .. "UnitFrameBars" end
for _, unit in ipairs({ "player", "target" }) do
    addon.Positioning:AddTarget(M.barsElementIds[unit], addon.L["ModeUI " .. M.titles[unit] .. " Bars"], M.BarsFrameName(unit))
end
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
-- Version 14: Mode Slate bar backgrounds at 70%.
-- Version 15: the level in the health bar's bottom corner; a matched Target mirrors the Player.
-- Version 16: one border (no black gap); the name sits on the top border.
-- Version 17: text slots replace the name, level, health and power text keys.
-- Version 18: the power bar and cast bar get their own textures (and the power
-- bar its own opacity), copied from the shared bar textures.
-- Version 19: the Focus cast bar sits 8px from the frame (owner); cast bars
-- get Full Width and Bar Width.
-- Version 20: the Mode design language (docs/DESIGN_LANGUAGE.md): 3px power,
-- Mode Matte health, Mode Gradient power, Mode Cast casts, Mode BG empty bars,
-- Geist, Gradient names, the Steel Sheen ring, 2px cast gap, Combined shields.
-- Version 21 (owner's in-game check): Portrait Size 140, the single Mode text
-- shadow (no lifted copy), the cast bar icon on the portrait side.
-- Version 22: health text colored by health, 22px auras five to a row, 11px cast text.
-- Version 23: semi-transparent empty bars (Slate at 60%, no black plate behind).
-- Version 24: the portrait ring in the class or reaction color (owner).
M.LAYOUT_VERSION = 24
local EMPTY = math.floor(addon.Style.Tone.emptyAlpha * 100 + 0.5)

local Tone = addon.Style.Tone
-- Mode text and gameplay colors, and the locked Onyx skin (Shared/Kit/Palette.lua).
M.palette, M.onyx = addon.Kit.palette, addon.Kit.onyx
-- Every unit frame rim (bar block, cast bar, badges, combo points): a little
-- lighter than the Onyx border, so it stands apart from the health bar.
M.RIM_COLOR = addon.Kit.BORDER_COLOR
-- Plain-text name colors that contrast the cool Onyx/slate skin (owner's
-- picks). Sky, the owner's own color (layout version 11), is the default.
M.nameAccents = Tone.nameAccent
M.ACCENT = M.nameAccents.sky

M.choices = {
    position = { { id = "LEFT", label = "Left" }, { id = "CENTER", label = "Center" }, { id = "RIGHT", label = "Right" } },
    side = { { id = "left", label = "Left" }, { id = "right", label = "Right" } },
    portraitStyle = { { id = "portrait", label = "Character Portrait" }, { id = "class", label = "Class Icon" } },
    ring = { { id = "border", label = "Metal" }, { id = "class", label = "Class Color" }, { id = "custom", label = "Custom" } },
    nameColor = { { id = "gradient", label = "Gradient" }, { id = "sky", label = "Sky" }, { id = "champagne", label = "Champagne" }, { id = "lilac", label = "Lilac" },
        { id = "frost", label = "Frost" }, { id = "class", label = "Class Color" }, { id = "custom", label = "Custom" } },
    healthColor = { { id = "default", label = "Default" }, { id = "class", label = "Class Color" }, { id = "custom", label = "Custom" } },
    -- Health texts: by health (Rosewood low, Ivory, Celadon full) or the Text Color.
    healthText = { { id = "health", label = "By Health" }, { id = "text", label = "Text Color" } },
    powerColor = { { id = "type", label = "Power Type" }, { id = "custom", label = "Custom" } },
    attachPoint = { { id = "bottomright", label = "Below, Right Edges" }, { id = "bottomleft", label = "Below, Left Edges" },
        { id = "right", label = "Right Side" }, { id = "left", label = "Left Side" }, { id = "topright", label = "Above, Right Edges" } },
    fill = { { id = "standard", label = "Left to Right" }, { id = "reverse", label = "Right to Left" } },
    edgeStyle = addon.Style.EdgeStyleChoices(),
    edgeMetal = addon.Style.EdgeMetalChoices(),
    -- Text glow colors (Style.TextHalo): Deep, Ink, Match Text.
    glowColor = addon.Style.GLOW_COLORS,
}
-- Ring Finish's choices after the metals (Settings.lua, M.RingFinish).
M.ringFinishes = { M.choices.ring[2], M.choices.ring[3] }
-- Bar Shows (owner, November 19, 2026: the Healer layout's "mana frame"):
-- the health bar shows the unit's health, or its mana (Update.lua).
M.choices.barShows = { { id = "health", label = "Health" }, { id = "mana", label = "Mana" } }
M.choices.prismGlow = { { id = "none", label = "Off" }, { id = "hover", label = "Mouseover" }, { id = "always", label = "Always" } }
-- Setting key -> choice list.
M.choiceKeys = { portraitSide = "side", portraitStyle = "portraitStyle", portraitRing = "ring", healthTextColor = "healthText",
    nameColorMode = "nameColor", healthColorMode = "healthColor", powerColorMode = "powerColor", attachPoint = "attachPoint",
    fillDirection = "fill", edgeStyle = "edgeStyle", edgeMetal = "edgeMetal", portraitRingStyle = "edgeStyle",
    portraitRingMetal = "edgeMetal", healthTextGlowColor = "glowColor",
    nameTextGlowColor = "glowColor", barShows = "barShows", prismGlow = "prismGlow" }

local function Copy(value) return addon.ProfileCodec.Copy(value) end
M.Public = addon.IsPublic
M.Number = addon.IsNumber

local function Frame(side, extra)
    -- 184 wide, 34px health, a 66px portrait in its 70px ring (docs/DESIGN_LANGUAGE.md, "Sizes").
    local frame = { enabled = true, hideBlizzard = true, scale = 100, barWidth = 184, healthHeight = 34,
        -- What the health bar shows: health, or mana (a "mana frame": Bar Shows).
        barShows = "health",
        -- Target only: mirror the Player frame's look (side and visibility stay its own).
        matchPlayer = false,
        -- Edit Mode's Match Width and Match Height (Layout.lua, MatchedFrame):
        -- the frame takes the size of the element picked for each.
        matchWidth = false, matchHeight = false,
        -- Target only, while matched: mirror the Player's text alignment and
        -- horizontal offsets to the other side (off: same layout as the Player).
        mirrorText = false,
        -- 3px power on every frame (docs/DESIGN_LANGUAGE.md, "Bars").
        showPower = true, powerHeight = 3,
        -- Both bars: fill (foreground) and empty bar (background) textures and
        -- opacity. The background is mostly see-through by default, so the fill
        -- stands out against the world behind it (owner, November 13, 2026).
        -- Mode Slate at 70% (owner, November 13, 2026): a solid near-neutral gray
        -- behind the fill, strong enough not to feel see-through.
        -- Mode Matte health over Mode BG on Slate, semi-transparent (docs/DESIGN_LANGUAGE.md, "Bars").
        foregroundTexture = "media:Mode-FG", backgroundTexture = "media:Mode-BG", barForegroundOpacity = 100, barBackgroundOpacity = EMPTY,
        -- The power bar's own (owner, November 13, 2026: each part of the frame
        -- has its own texture settings); the keys above are the health bar's.
        powerForegroundTexture = "media:Mode-FG", powerBackgroundTexture = "media:Mode-BG", powerForegroundOpacity = 100,
        powerBackgroundOpacity = EMPTY,
        -- Combined shields on the health bar (Style.Shield).
        showShields = true,
        -- A 1px light line where the health fill ends.
        fillEdge = true,
        showPortrait = true, portraitStyle = "portrait", portraitSide = side,
        portraitScale = 140, -- portrait diameter as a % of the bar block
        -- The ring in the class or reaction color, flat, with its black line
        -- (owner, November 18, 2026); Metal draws the style and metal below.
        portraitRing = "class", portraitRingColor = Copy(M.ACCENT),
        -- The ring's own Mode border style and metal (Style.SetRingStyle):
        -- Mode-Blizz in its Silver (owner, November 17, 2026).
        portraitRingStyle = "obsidian", portraitRingMetal = "default",
        -- The color of names in text slots (TextSlots.lua places every text).
        nameColorMode = "gradient", nameColor = Copy(M.ACCENT),
        healthColorMode = "default", healthColor = Copy(M.palette.green),
        -- Health texts in the bars: colored by health (Style.PaintHealthText).
        healthTextColor = "health",
        -- Text glow (Style.TextHalo, owner's picks, November 17, 2026): health
        -- numbers in Deep at 15%, names in Ink at 20%.
        healthTextGlow = true, healthTextGlowColor = "deep", healthTextGlowStrength = 15,
        nameTextGlow = true, nameTextGlowColor = "ink", nameTextGlowStrength = 20,
        powerColorMode = "type", powerColor = Copy(M.palette.mana),
        font = "game", fontMedia = addon.Style.FONT_DEFAULT, outline = false, shadow = true,
        -- The suite's text style: every text gets a crisp opaque 1px shadow plus
        -- a lighter second shadow 2px out (owner, layout version 11).
        -- The Mode text shadow only: one crisp 1px shadow (docs/DESIGN_LANGUAGE.md).
        liftedShadow = false, textColor = Copy(M.palette.text),
        -- Target of Target and Target of Focus only: attached to their parent frame.
        attach = false, attachPoint = "bottomright", attachOffsetX = 0, attachOffsetY = -2,
        -- Which way health and power fill (and drain). The Target runs the
        -- other way from the Player by default (owner, November 13, 2026).
        fillDirection = "standard",
        -- The frame's and its cast bar's border (docs/DESIGN_LANGUAGE.md,
        -- "Choosing a border"): Mode-Blizz in its own metal (owner, November 17, 2026).
        edgeStyle = "obsidian", edgeMetal = "default",
        -- Player and Target: the Mode Frame border's soft drop (owner, November
        -- 18, 2026: off where icons sit on the border, as in Mode-Default).
        dropShadow = true,
        -- The Prism glow round the bar block (docs/DESIGN_LANGUAGE.md,
        -- "Mode-Obsidian theme"): Off, on Mouseover, or Always (the Focus
        -- frame under Mode-Obsidian), in the unit's class or reaction color.
        prismGlow = "none" }
    for key, value in pairs(extra or {}) do frame[key] = value end
    return frame
end
-- Target of Target (owner, November 13, 2026): small, no portrait or level,
-- 75% scale, the name inside the health bar on the left (its text slots,
-- TextSlots.lua), attached under the Target frame's bottom-right corner.
-- Target of Focus is the same under the Focus frame, and Focus is the same
-- frame at 90% scale, placed on its own.
-- 22px health and 3px power (docs/DESIGN_LANGUAGE.md, "Sizes").
local function Small(scale, attach, width)
    return { barWidth = width or 130, healthHeight = 22, powerHeight = 3, scale = scale, showPortrait = false, attach = attach }
end
-- The Target mirrors the Player by default: health text on the left, level in
-- its bottom right corner (owner, November 13, 2026).
-- The Player and Target portraits are 165% of the bar block (owner, November 18, 2026).
M.frameDefaults = { player = Frame("left", { portraitScale = 165 }),
    target = Frame("right", { matchPlayer = true, mirrorText = true, fillDirection = "reverse", portraitScale = 165 }),
    targettarget = Frame("left", Small(75, true)), focus = Frame("right", Small(90, false, 160)), focustarget = Frame("left", Small(75, true)) }
M.frameRanges = { scale = { 50, 200, 1 }, barWidth = { 100, 400, 1 }, healthHeight = { 10, 60, 1 },
    powerHeight = { 2, 30, 1 }, portraitScale = { 100, 200, 5 },
    barForegroundOpacity = { 10, 100, 5 }, barBackgroundOpacity = { 0, 100, 5 }, powerForegroundOpacity = { 10, 100, 5 },
    powerBackgroundOpacity = { 0, 100, 5 }, attachOffsetX = { -200, 200, 1 }, attachOffsetY = { -200, 200, 1 },
    healthTextGlowStrength = { 5, 40, 5 }, nameTextGlowStrength = { 5, 40, 5 } }
-- Keys that describe placement/identity rather than style; Copy Style skips them.
M.identityKeys = { enabled = true, hideBlizzard = true, portraitSide = true, matchPlayer = true, mirrorText = true,
    attach = true, attachPoint = true, attachOffsetX = true, attachOffsetY = true, fillDirection = true,
    matchWidth = true, matchHeight = true }
-- Combo points around the Target frame's portrait (owner, November 13, 2026).
-- Their own table, not per frame, so they stay editable while the Target
-- matches the Player. Sizes are in the Target frame's units.
M.comboDefaults = { enabled = true, hideBlizzard = true, arc = "topOuter", size = 10, spacing = 3, distance = 3,
    activeColor = Copy(Tone.comboPoint), emptyColor = Copy(M.onyx.track) }
M.comboRanges = { size = { 6, 24, 1 }, spacing = { 0, 12, 1 }, distance = { 0, 20, 1 } }
-- Where the arc sits around the portrait. "outer" is the side away from the
-- bars; without a portrait the points line up under the bars.
M.choices.comboArc = { { id = "topOuter", label = "Upper Outer" }, { id = "outer", label = "Outer Side" },
    { id = "bottomOuter", label = "Lower Outer" }, { id = "top", label = "Top" }, { id = "bottom", label = "Bottom" } }
-- Each frame's cast bar (owner, November 13, 2026), in db[unit].castBar: a
-- box with the frame's rim and gap under (or over) the bar block, its bar
-- lined up with the health bar. On for the Player, Target and Focus.
M.castDefaults = { enabled = true, hideBlizzard = true, position = "below", height = 14, gap = 2, icon = "near",
    fullWidth = true, width = 160,
    foregroundTexture = "media:Mode-FG", backgroundTexture = "media:Mode-BG",
    showText = true, showTimer = true, fontSize = 11, outline = true, color = Copy(M.palette.neutral), lockedColor = Copy(M.palette.tapped) }
-- Gap -1: the bar 1px from the frame, the two shadows sharing one pixel, as
-- Mode's icons and frames do (owner, November 19, 2026).
M.castRanges = { height = { 6, 40, 1 }, gap = { -1, 40, 1 }, fontSize = { 6, 20, 1 }, width = { 40, 400, 1 } }
M.choices.castPosition = { { id = "below", label = "Below Frame" }, { id = "above", label = "Above Frame" } }
M.choices.castIcon = { { id = "far", label = "Away from Portrait" }, { id = "near", label = "Portrait Side" }, { id = "none", label = "Hidden" } }
M.castChoices = { position = "castPosition", icon = "castIcon" }
local CAST_OFF = { targettarget = true, focustarget = true }
function M.CastDefaults(unit)
    local defaults = Copy(M.castDefaults)
    defaults.enabled = not CAST_OFF[unit]
    -- The owner asked for the Focus cast bar 8px from the frame.
    if unit == "focus" then defaults.gap = 8 end
    return defaults
end
-- Buffs and debuffs (owner, November 13, 2026), in db[unit].buffs and
-- db[unit].debuffs, with the same options. Rows start at a corner of the
-- health bar's span, lined up with its edge, so they never reach over the
-- portrait. Buffs are on for the Target, at its top right; debuffs start off,
-- under the frame.
M.auraGroups = { "buffs", "debuffs" }
M.auraGroupLabels = { buffs = "Buffs", debuffs = "Debuffs" }
-- 22px icons, five to a row, so a row on the border ends before the name.
M.auraDefaults = { enabled = false, filter = "all", anchor = "TOPRIGHT", grow = "left", size = 22, spacing = 2, max = 8,
    perRow = 5, x = 0, y = 0, shape = "cropped", border = "type", timer = true, count = true }
M.auraRanges = { size = { 10, 40, 1 }, spacing = { 0, 10, 1 }, max = { 1, 16, 1 }, perRow = { 1, 16, 1 },
    x = { -100, 100, 1 }, y = { -100, 100, 1 } }
M.choices.auraAnchor = { { id = "TOPRIGHT", label = "Top Right" }, { id = "TOPLEFT", label = "Top Left" },
    { id = "BOTTOMRIGHT", label = "Bottom Right" }, { id = "BOTTOMLEFT", label = "Bottom Left" } }
M.choices.auraGrow = { { id = "left", label = "Left" }, { id = "right", label = "Right" } }
M.choices.auraShape = { { id = "cropped", label = "Cropped" }, { id = "square", label = "Square" } }
M.choices.auraBorder = { { id = "type", label = "By Type" }, { id = "mode", label = "Mode" } }
M.choices.buffsFilter = { { id = "all", label = "All" }, { id = "mine", label = "Yours" },
    { id = "dispellable", label = "Dispellable or Stealable" } }
M.choices.debuffsFilter = { { id = "all", label = "All" }, { id = "mine", label = "Yours" },
    { id = "dispellable", label = "Ones You Can Dispel" } }
-- Rim colors by the game's dispel type name, as Blizzard's DebuffTypeColor.
M.dispelColors = Tone.dispel
function M.AuraDefaults(unit, group)
    local defaults = Copy(M.auraDefaults)
    if group == "buffs" then defaults.enabled = unit == "target"
    else defaults.anchor, defaults.grow = "BOTTOMRIGHT", "left" end
    return defaults
end
function M.AuraChoices(group)
    return { filter = group .. "Filter", anchor = "auraAnchor", grow = "auraGrow", shape = "auraShape", border = "auraBorder" }
end
-- Settings every frame keeps for itself: a Target matching the Player still
-- uses its own cast bar and auras (unlike identity keys, Copy Style and Reset
-- include them).
-- Status on the portrait (owner, November 13, 2026), in db[unit].status: a
-- rested badge (Player only) and a combat badge on the ring's corners, a red
-- ring in combat, and on the Player a pulse while something you haven't
-- targeted has pulled you. Corners swap sides on a right-hand portrait.
M.statusDefaults = { restIcon = true, restCorner = "topLeft", combatIcon = true, combatCorner = "bottomLeft", badgeSize = 20,
    mirror = true, combatRing = true, ringColor = Copy(Tone.combatRing), pulse = true }
M.statusRanges = { badgeSize = { 12, 32, 1 } }
M.choices.statusCorner = { { id = "topLeft", label = "Top Left" }, { id = "topRight", label = "Top Right" },
    { id = "bottomLeft", label = "Bottom Left" }, { id = "bottomRight", label = "Bottom Right" } }
M.statusChoices = { restCorner = "statusCorner", combatCorner = "statusCorner" }
function M.StatusDefaults(unit)
    local defaults = Copy(M.statusDefaults)
    local player = unit == "player"
    defaults.restIcon, defaults.combatRing, defaults.pulse = player, player, player
    defaults.combatIcon = player or unit == "target"
    return defaults
end
-- Frame Width (barWidth) too, so a matched Target can be wider or narrower;
-- Bar Shows, so a Player mana frame never turns a matched Target into one.
M.ownKeys = { castBar = true, buffs = true, debuffs = true, barWidth = true, status = true, barShows = true }
M.defaults = { layoutVersion = M.LAYOUT_VERSION, comboPoints = Copy(M.comboDefaults) }
for _, unit in ipairs(M.units) do M.defaults[unit] = Copy(M.frameDefaults[unit]) end
