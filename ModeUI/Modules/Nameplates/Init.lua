local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Frames > Nameplates: ModeUI's own plates in the Mode design language
-- (docs/DESIGN_LANGUAGE.md), drawn on the game's nameplates. The game keeps placing, stacking and clicking its
-- nameplates; ModeUI fades Blizzard's art and draws health, name, cast bar,
-- auras, raid marker and target highlight. Enemy and friendly plates each have
-- their own settings. Unit values can be secret and only reach widgets
-- documented as accepting them. See docs/NAMEPLATES.md.
-- Files: Init (this), Migrations, Driver, Plate, Layout, Target, Indicator, Focus,
-- Combo, SoftTarget, Update, CastBar, Auras, AuraContainers, Preview, Settings.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Nameplates"], category = "frames", defaultEnabled = false, layout = "strip",
    configDescription = L["Mode nameplates with health, names, cast bars, auras and raid markers."],
    modeLayout = { decorateOnly = true } }
addon.Nameplates = M
addon:RegisterModule("nameplates", M)

-- Version 2: separate enemy and friendly settings (version 1 had one set).
-- Version 3: auras added; every bar uses the Mode Gradient texture, so the
-- texture choice is gone.
-- Version 4: crowd control, debuffs and buffs are separate aura groups, each
-- with its own anchor, offset, size and count.
-- Version 5: placement for every element, Name Only display, target styles,
-- the aura skin (shape, border colors by type) and aura grow directions.
-- Version 6: Color Softness is gone (colors are used as they are); Health
-- Opacity and Background Opacity fade the bar and its background; each
-- threat status has its own color.
-- Version 7: the quest, classification and level indicators each have their
-- own anchor, offset and size.
-- Version 8: the no-type crowd control rim's default moves from orange to
-- #FF5948; profiles still on the old default follow it.
-- Version 9: the Mode design language: the frameThin edge (the target's
-- outer line in Ivory, focus in Rosewood), Mode BG fills and empty parts,
-- Mode Cast cast bars with the Comet spark (Cast Texture), Gradient names
-- in SemiBold, Bold health text colored by health, Geist with one shadow.
-- Version 10: auras wear the frameThin edge (Border Size 1 or 2, 1 by
-- default; Corners retire), and auras without a type keep the Gunmetal metal.
-- Version 11: semi-transparent empty bars (Slate at 60%).
M.VERSION = 11
local EMPTY = math.floor(addon.Style.Tone.emptyAlpha * 100 + 0.5)
M.indicatorParts = { "quest", "classification", "level" }
M.indicatorPartLabels = { quest = "Quest", classification = "Elite and Rare", level = "Level" }
M.kinds = { "enemy", "friendly" }
M.kindLabels = { enemy = "Enemy", friendly = "Friendly" }
M.auraGroups = { "crowdControl", "debuffs", "buffs" }
M.auraGroupLabels = { crowdControl = "Crowd Control", debuffs = "Debuffs", buffs = "Buffs" }
local P, RGB = Kit.palette, Kit.RGB
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Default threat colors: the enemy is attacking you (red), or you're losing
-- it or close to pulling it (orange).
M.threatPalette = { aggro = RGB(255, 72, 72), warning = RGB(255, 160, 64) }
-- The setting holding each threat status's color (UnitThreatSituation 1-3).
M.threatColorKeys = { [3] = "threatAggroColor", [2] = "threatLosingColor", [1] = "threatPullingColor" }

-- The way icons line up from their anchor when a group doesn't say otherwise.
M.defaultGrow = { TOPLEFT = "right", TOP = "center", TOPRIGHT = "left", LEFT = "left", RIGHT = "right",
    BOTTOMLEFT = "right", BOTTOM = "center", BOTTOMRIGHT = "left" }

-- One aura group: shown or not, which auras (debuffs and buffs only), and
-- where: an anchor around the plate, the grow direction, an offset, the icon
-- size and how many.
local function Group(show, filter, anchor, size, max)
    return { show = show, filter = filter, anchor = anchor, grow = M.defaultGrow[anchor], x = 0, y = 0, size = size, max = max,
        attach = false }
end

-- One kind's settings. `show` off leaves that kind's plates to Blizzard;
-- display "name" draws only the class- or reaction-colored name.
local function Style(kind)
    local enemy = kind == "enemy"
    return {
        show = true, display = "plate",
        width = enemy and 140 or 120, healthHeight = enemy and 12 or 8, castHeight = enemy and 12 or 8,
        healthColorMode = "reaction", healthColor = Copy(P.green), threatColors = enemy,
        -- Colors are used as they are; the bar and its background each fade.
        healthOpacity = 100, backgroundOpacity = EMPTY,
        -- Bar textures: Mode BG fill on Mode BG (Slate), and Mode Cast for the cast bar.
        foregroundTexture = "media:Mode BG", backgroundTexture = "media:Mode BG", castTexture = "media:Mode Cast",
        threatAggroColor = Copy(M.threatPalette.aggro), threatLosingColor = Copy(M.threatPalette.warning),
        threatPullingColor = Copy(M.threatPalette.warning),
        healthText = enemy and "percent" or "none", healthFontSize = 9, healthTextColor = "health", healthTextGlow = true,
        healthTextAnchor = "RIGHT", healthTextX = 0, healthTextY = 0,
        showName = true, nameFontSize = 10, nameColorMode = "gradient", nameAnchor = "TOP", nameX = 0, nameY = 0,
        showCastBar = true, castFontSize = enemy and 9 or 8, castColor = Copy(P.neutral), castLockedColor = Copy(P.tapped),
        castInterruptedColor = Copy(P.hostile),
        castAnchor = "BOTTOM", castX = 0, castY = enemy and -2 or 0,
        castIcon = "LEFT", castShowText = true, castShowTarget = enemy, castShowTimer = true,
        -- Cast texts by anchor around the cast bar: Left, Center and Right sit inside it.
        castTextAnchor = "LEFT", castTextX = 0, castTextY = 0, castTimerAnchor = "RIGHT", castTimerX = 0, castTimerY = 0,
        castTargetAnchor = "BOTTOM", castTargetX = 0, castTargetY = 0, castIconX = 0, castIconY = 0,
        showRaidIcon = true, raidAnchor = "LEFT", raidX = 0, raidY = 0, raidSize = 16,
        -- The soft-target icon (the cursor art the game shows over the unit), above the plate.
        showSoftTarget = true, softTargetSize = 20, softTargetX = 0, softTargetY = 0,
        -- Indicator: quest icon, classification icon and level, by anchor.
        showIndicator = enemy, indicatorQuest = true, indicatorClassification = true, indicatorLevel = true,
        questAnchor = "LEFT", questX = 0, questY = 0, questSize = 14,
        classificationAnchor = "LEFT", classificationX = 0, classificationY = 0, classificationSize = 14,
        levelAnchor = "LEFT", levelX = 0, levelY = 0, levelSize = 9,
        -- Target indicator: border, glow, arrows, border and arrows, or none.
        targetStyle = "border", targetColor = Copy(addon.Style.Tone.ivory), targetThickness = 1, targetArrowSize = 12, targetArrowGap = 4,
        -- Focus: a highlight, its own health bar texture, and fading other plates.
        focusStyle = "border", focusColor = Copy(addon.Style.Tone.rosewood), focusStripeOpacity = 40, focusTexture = "default",
        focusFadeOthers = 100,
        -- Combo points on your target's plate (a Rogue's, or a Cat Form Druid's).
        showCombo = enemy, comboAnchor = "BOTTOM", comboX = 0, comboY = 0, comboSize = 8, comboSpacing = 2,
        comboActiveColor = RGB(240, 84, 84), comboEmptyColor = Copy(Kit.onyx.track),
        -- Auras: settings for every group, then each group on its own.
        showAuras = true, auraSpacing = 2, auraTimer = true, auraTimerText = true, auraCount = true, auraShape = "cropped", auraBorder = "type",
        auraBorderSize = 1, auraCCGlow = true, auraGlowStyle = "gcd",
        auraTimerColor = Copy(P.cooldown),
        auraMagicColor = RGB(51, 153, 255), auraCurseColor = RGB(170, 85, 255), auraDiseaseColor = RGB(204, 136, 51),
        auraPoisonColor = RGB(85, 187, 85), auraEnrageColor = RGB(255, 85, 85), auraBleedColor = RGB(200, 45, 45),
        -- Auras without a dispel type (Cheap Shot, most crowd control): #FF5948 for
        -- crowd control, the Gunmetal rim for the rest.
        auraNoTypeColor = Copy(addon.Style.Tone.gunmetal.mid), auraCCNoTypeColor = RGB(255, 89, 72),
        crowdControl = Group(enemy, nil, "LEFT", enemy and 24 or 18, 2),
        debuffs = Group(true, enemy and "mine" or "dispellable", "TOP", enemy and 20 or 16, enemy and 6 or 4),
        buffs = Group(enemy, enemy and "dispellable" or "mine", "RIGHT", enemy and 18 or 14, 3),
        font = "game", fontMedia = "Mode Geist", outline = false, shadow = true, liftedShadow = false, slug = true,
        textColor = Copy(P.text),
    }
end
M.styleDefaults = { enemy = Style("enemy"), friendly = Style("friendly") }
M.defaults = { version = M.VERSION, enemy = Copy(M.styleDefaults.enemy), friendly = Copy(M.styleDefaults.friendly) }
-- Keys Copy Style leaves alone.
M.identityKeys = { show = true }
M.colorKeys = { healthColor = true, focusColor = true, threatAggroColor = true, threatLosingColor = true, threatPullingColor = true, castColor = true, castLockedColor = true, castInterruptedColor = true, textColor = true, targetColor = true,
    auraMagicColor = true, auraCurseColor = true, auraDiseaseColor = true, auraPoisonColor = true, auraEnrageColor = true,
    auraBleedColor = true, auraNoTypeColor = true, auraCCNoTypeColor = true, auraTimerColor = true,
    comboActiveColor = true, comboEmptyColor = true }
-- Aura border colors by the game's dispel type name.
M.dispelColorKeys = { Magic = "auraMagicColor", Curse = "auraCurseColor", Disease = "auraDiseaseColor",
    Poison = "auraPoisonColor", Enrage = "auraEnrageColor", Bleed = "auraBleedColor" }
-- The game's dispel type IDs, the x values of a dispel color curve
-- (C_UnitAuras.GetAuraDispelTypeColor); "none" gets the no-type color.
M.dispelTypeIDs = Kit.DISPEL_TYPE_IDS

M.ranges = { width = { 80, 250, 1 }, healthHeight = { 4, 30, 1 }, castHeight = { 4, 20, 1 },
    auraBorderSize = { 1, 2, 1 },
    healthOpacity = { 10, 100, 5 }, backgroundOpacity = { 0, 100, 5 },
    healthFontSize = { 6, 20, 1 }, nameFontSize = { 6, 20, 1 }, castFontSize = { 6, 20, 1 }, auraSpacing = { 0, 8, 1 },
    nameX = { -50, 50, 1 }, nameY = { -50, 50, 1 }, healthTextX = { -50, 50, 1 }, healthTextY = { -50, 50, 1 },
    castX = { -50, 50, 1 }, castY = { -50, 50, 1 },
    focusStripeOpacity = { 10, 100, 5 }, focusFadeOthers = { 20, 100, 5 },
    castTextX = { -50, 50, 1 }, castTextY = { -50, 50, 1 }, castTimerX = { -50, 50, 1 }, castTimerY = { -50, 50, 1 },
    castTargetX = { -50, 50, 1 }, castTargetY = { -50, 50, 1 }, castIconX = { -50, 50, 1 }, castIconY = { -50, 50, 1 },
    questX = { -50, 50, 1 }, questY = { -50, 50, 1 }, questSize = { 8, 32, 1 },
    classificationX = { -50, 50, 1 }, classificationY = { -50, 50, 1 }, classificationSize = { 8, 32, 1 },
    levelX = { -50, 50, 1 }, levelY = { -50, 50, 1 }, levelSize = { 6, 20, 1 }, raidX = { -50, 50, 1 }, raidY = { -50, 50, 1 }, raidSize = { 10, 40, 1 },
    softTargetSize = { 12, 40, 1 }, softTargetX = { -50, 50, 1 }, softTargetY = { -50, 50, 1 },
    targetThickness = { 1, 3, 1 }, targetArrowSize = { 8, 48, 1 }, targetArrowGap = { 0, 60, 1 },
    comboX = { -50, 50, 1 }, comboY = { -50, 50, 1 }, comboSize = { 4, 24, 1 }, comboSpacing = { 0, 12, 1 } }
M.groupRanges = { size = { 10, 40, 1 }, max = { 1, 12, 1 }, x = { -50, 50, 1 }, y = { -50, 50, 1 } }
-- Anchors around the plate, read like a compass: Top sits above the name,
-- Bottom below the cast bar, Left and Right beside the health bar.
M.anchors = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
M.anchorLabels = { TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right", LEFT = "Left", RIGHT = "Right",
    BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right" }
M.anchorLabels.CENTER = "Center"
-- Text and the raid marker can also sit in the middle. Text anchored Left,
-- Center or Right sits inside the health bar; the marker sits beside it.
M.elementAnchors = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
M.choices = {
    healthColorMode = { { id = "reaction", label = "Reaction and Class" }, { id = "reactionOnly", label = "Reaction" },
        { id = "onyx", label = "Onyx" }, { id = "custom", label = "Custom" } },
    healthText = { { id = "percent", label = "Percent" }, { id = "current", label = "Current Health" },
        { id = "both", label = "Current and Percent" }, { id = "none", label = "None" } },
    display = { { id = "plate", label = "Plate" }, { id = "name", label = "Name Only" } },
    nameColorMode = { { id = "gradient", label = "Gradient" }, { id = "class", label = "Class or Reaction" }, { id = "text", label = "Text Color" } },
    healthTextColor = { { id = "health", label = "By Health" }, { id = "text", label = "Text Color" } },
    castAnchor = { { id = "BOTTOM", label = "Below" }, { id = "TOP", label = "Above" } },
    castIcon = { { id = "LEFT", label = "Left" }, { id = "RIGHT", label = "Right" }, { id = "OUTLEFT", label = "Outside Left" },
        { id = "OUTRIGHT", label = "Outside Right" }, { id = "none", label = "Hidden" } },
    focusStyle = { { id = "border", label = "Border" }, { id = "glow", label = "Glow" }, { id = "stripes", label = "Stripes" },
        { id = "none", label = "None" } },
    castTextAnchor = M.elementAnchors, castTimerAnchor = M.elementAnchors, castTargetAnchor = M.elementAnchors,
    targetStyle = { { id = "border", label = "Border" }, { id = "glow", label = "Glow" }, { id = "arrows", label = "Arrows" },
        { id = "borderArrows", label = "Border and Arrows" }, { id = "none", label = "None" } },
    auraShape = { { id = "cropped", label = "Cropped" }, { id = "square", label = "Square" } },
    auraBorder = { { id = "type", label = "By Type" }, { id = "mode", label = "Mode" } },
    auraGlowStyle = { { id = "gcd", label = "GCD Flash" }, { id = "soft", label = "Soft Glow" } },
    nameAnchor = M.elementAnchors, healthTextAnchor = M.elementAnchors, raidAnchor = M.elementAnchors,
    questAnchor = M.elementAnchors, classificationAnchor = M.elementAnchors, levelAnchor = M.elementAnchors,
    comboAnchor = M.elementAnchors,
}
M.growChoices = { { id = "right", label = "Right" }, { id = "left", label = "Left" }, { id = "up", label = "Up" },
    { id = "down", label = "Down" }, { id = "center", label = "Center" } }
M.groupFilters = {
    debuffs = { { id = "mine", label = "Yours" }, { id = "dispellable", label = "Ones You Can Dispel" }, { id = "all", label = "All" } },
    buffs = { { id = "dispellable", label = "Dispellable or Stealable" }, { id = "important", label = "Important" },
        { id = "mine", label = "Yours" }, { id = "all", label = "All" } },
}

-- Texture choices are shared with every bar (Shared/Kit/Shape.lua).
M.TextureChoices = Kit.BarTextureChoices
