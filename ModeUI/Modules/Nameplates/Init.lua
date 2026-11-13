local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Nameplates: ModeUI's own plates in the Onyx look, drawn on the
-- game's nameplates. The game keeps placing, stacking and clicking its
-- nameplates; ModeUI fades Blizzard's art and draws health, name, cast bar,
-- auras, raid marker and target highlight. Enemy and friendly plates each have
-- their own settings. Unit values can be secret and only reach widgets
-- documented as accepting them. See docs/NAMEPLATES.md.
-- Files: Init (this), Driver, Plate, Update, CastBar, Auras, Preview, Settings.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Nameplates"], category = "interface", defaultEnabled = false,
    configDescription = L["Onyx nameplates with health, names, cast bars, auras and raid markers."],
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
M.VERSION = 7
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
        healthOpacity = 100, backgroundOpacity = 55,
        -- Bar textures, for the health and cast bars: Mode Gradient and Flat by default.
        foregroundTexture = "mode", backgroundTexture = "flat",
        threatAggroColor = Copy(M.threatPalette.aggro), threatLosingColor = Copy(M.threatPalette.warning),
        threatPullingColor = Copy(M.threatPalette.warning),
        healthText = enemy and "percent" or "none", healthFontSize = 9,
        healthTextAnchor = "RIGHT", healthTextX = 0, healthTextY = 0,
        showName = true, nameFontSize = 10, nameColorMode = "text", nameAnchor = "TOP", nameX = 0, nameY = 0,
        showCastBar = true, castFontSize = enemy and 9 or 8, castColor = Copy(P.neutral), castLockedColor = Copy(P.tapped),
        castAnchor = "BOTTOM", castX = 0, castY = enemy and -2 or 0,
        castIcon = "LEFT", castShowText = true, castShowTarget = enemy, castShowTimer = true,
        -- Cast texts by anchor around the cast bar: Left, Center and Right sit inside it.
        castTextAnchor = "LEFT", castTextX = 0, castTextY = 0, castTimerAnchor = "RIGHT", castTimerX = 0, castTimerY = 0,
        castTargetAnchor = "BOTTOM", castTargetX = 0, castTargetY = 0, castIconX = 0, castIconY = 0,
        showRaidIcon = true, raidAnchor = "LEFT", raidX = 0, raidY = 0, raidSize = 16,
        -- Indicator: quest icon, classification icon and level, by anchor.
        showIndicator = enemy, indicatorQuest = true, indicatorClassification = true, indicatorLevel = true,
        questAnchor = "LEFT", questX = 0, questY = 0, questSize = 14,
        classificationAnchor = "LEFT", classificationX = 0, classificationY = 0, classificationSize = 14,
        levelAnchor = "LEFT", levelX = 0, levelY = 0, levelSize = 9,
        -- Target indicator: border, glow, arrows, border and arrows, or none.
        targetStyle = "border", targetColor = Copy(P.accent), targetThickness = 1, targetArrowSize = 12, targetArrowGap = 4,
        -- Focus: a highlight, its own health bar texture, and fading other plates.
        focusStyle = "border", focusColor = RGB(255, 181, 71), focusStripeOpacity = 40, focusTexture = "default",
        focusFadeOthers = 100,
        -- Auras: settings for every group, then each group on its own.
        showAuras = true, auraSpacing = 2, auraTimer = true, auraTimerText = true, auraCount = true, auraShape = "cropped", auraBorder = "type",
        auraBorderSize = 2, auraCCGlow = true,
        auraMagicColor = RGB(51, 153, 255), auraCurseColor = RGB(170, 85, 255), auraDiseaseColor = RGB(204, 136, 51),
        auraPoisonColor = RGB(85, 187, 85), auraEnrageColor = RGB(255, 85, 85), auraBleedColor = RGB(200, 45, 45),
        -- Auras without a dispel type (Cheap Shot, most crowd control): orange for
        -- crowd control, the Mode rim for the rest.
        auraNoTypeColor = RGB(37, 40, 44), auraCCNoTypeColor = RGB(255, 140, 40),
        crowdControl = Group(enemy, nil, "LEFT", enemy and 24 or 18, 2),
        debuffs = Group(true, enemy and "mine" or "dispellable", "TOP", enemy and 20 or 16, enemy and 6 or 4),
        buffs = Group(enemy, enemy and "dispellable" or "mine", "RIGHT", enemy and 18 or 14, 3),
        font = "game", fontMedia = "Expressway", outline = false, shadow = true, liftedShadow = true, slug = true,
        textColor = Copy(P.text),
    }
end
M.styleDefaults = { enemy = Style("enemy"), friendly = Style("friendly") }
M.defaults = { version = M.VERSION, enemy = Copy(M.styleDefaults.enemy), friendly = Copy(M.styleDefaults.friendly) }
-- Keys Copy Style leaves alone.
M.identityKeys = { show = true }
M.colorKeys = { healthColor = true, focusColor = true, threatAggroColor = true, threatLosingColor = true, threatPullingColor = true, castColor = true, castLockedColor = true, textColor = true, targetColor = true,
    auraMagicColor = true, auraCurseColor = true, auraDiseaseColor = true, auraPoisonColor = true, auraEnrageColor = true,
    auraBleedColor = true, auraNoTypeColor = true, auraCCNoTypeColor = true }
-- Aura border colors by the game's dispel type name.
M.dispelColorKeys = { Magic = "auraMagicColor", Curse = "auraCurseColor", Disease = "auraDiseaseColor",
    Poison = "auraPoisonColor", Enrage = "auraEnrageColor", Bleed = "auraBleedColor" }
-- The game's dispel type IDs, the x values of a dispel color curve
-- (C_UnitAuras.GetAuraDispelTypeColor); "none" gets the no-type color.
M.dispelTypeIDs = { [0] = "none", [1] = "Magic", [2] = "Curse", [3] = "Disease", [4] = "Poison", [5] = "none",
    [9] = "Enrage", [10] = "none", [11] = "Bleed", [12] = "none" }

M.ranges = { width = { 80, 250, 1 }, healthHeight = { 4, 30, 1 }, castHeight = { 4, 20, 1 },
    auraBorderSize = { 1, 3, 1 },
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
    targetThickness = { 1, 3, 1 }, targetArrowSize = { 8, 48, 1 }, targetArrowGap = { 0, 60, 1 } }
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
    nameColorMode = { { id = "text", label = "Text Color" }, { id = "class", label = "Class or Reaction" } },
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
    nameAnchor = M.elementAnchors, healthTextAnchor = M.elementAnchors, raidAnchor = M.elementAnchors,
    questAnchor = M.elementAnchors, classificationAnchor = M.elementAnchors, levelAnchor = M.elementAnchors,
}
M.growChoices = { { id = "right", label = "Right" }, { id = "left", label = "Left" }, { id = "up", label = "Up" },
    { id = "down", label = "Down" }, { id = "center", label = "Center" } }
M.groupFilters = {
    debuffs = { { id = "mine", label = "Yours" }, { id = "dispellable", label = "Ones You Can Dispel" }, { id = "all", label = "All" } },
    buffs = { { id = "dispellable", label = "Dispellable or Stealable" }, { id = "important", label = "Important" },
        { id = "mine", label = "Yours" }, { id = "all", label = "All" } },
}

local Public, Number = addon.IsPublic, addon.IsNumber
local function Allowed(list)
    local set = {}
    for _, item in ipairs(list) do set[type(item) == "table" and item.id or item] = true end
    return set
end
local ALLOWED, ANCHORS, FILTERS, GROWS = {}, Allowed(M.anchors), {}, Allowed(M.growChoices)
for key, list in pairs(M.choices) do ALLOWED[key] = Allowed(list) end
for group, list in pairs(M.groupFilters) do FILTERS[group] = Allowed(list) end

-- Version 1 kept one flat set of settings; both kinds start from it.
local function MigrateV1(db)
    for _, kind in ipairs(M.kinds) do
        local style = {}
        for key in pairs(M.styleDefaults.enemy) do
            if db[key] ~= nil then style[key] = Copy(db[key]) end
        end
        db[kind] = style
    end
    for key in pairs(M.styleDefaults.enemy) do db[key] = nil end
    db.texture = nil -- retired in version 3
end

-- Version 2 -> 3: the texture choice is retired; new aura keys take defaults.
local function MigrateV2(db)
    for _, kind in ipairs(M.kinds) do
        if type(db[kind]) == "table" then db[kind].texture = nil end
    end
end

-- Version 3 -> 4: the one aura row becomes three groups placed where it was.
local RETIRED_V3 = { "auraCrowdControl", "auraDebuffs", "auraBuffs", "auraPosition", "auraAlign", "auraSize", "auraMax" }
local POSITION = { above = "TOP", below = "BOTTOM", left = "LEFT", right = "RIGHT" }
local ALIGN = { left = "LEFT", right = "RIGHT" }
local function MigrateV3(db)
    for _, kind in ipairs(M.kinds) do
        local style, defaults = db[kind], M.styleDefaults[kind]
        if type(style) == "table" and style.auraPosition ~= nil then
            local anchor = POSITION[style.auraPosition] or "TOP"
            if (anchor == "TOP" or anchor == "BOTTOM") and ALIGN[style.auraAlign] then anchor = anchor .. ALIGN[style.auraAlign] end
            local function From(group, show, filter)
                local value = Copy(defaults[group])
                value.show, value.anchor, value.grow = show, anchor, M.defaultGrow[anchor]
                if Number(style.auraSize, 10, 40) then value.size = math.floor(style.auraSize) end
                if Number(style.auraMax, 1, 12) then value.max = math.floor(style.auraMax) end
                if FILTERS[group] and FILTERS[group][filter] then value.filter = filter end
                return value
            end
            style.crowdControl = From("crowdControl", style.auraCrowdControl == true)
            style.debuffs = From("debuffs", style.auraDebuffs ~= "none", style.auraDebuffs)
            style.buffs = From("buffs", style.auraBuffs ~= "none", style.auraBuffs)
        end
        if type(style) == "table" then for _, key in ipairs(RETIRED_V3) do style[key] = nil end end
    end
end

-- Version 4 -> 5: the target highlight switch becomes a target style, and each
-- aura group grows the way its anchor did.
local function MigrateV4(db)
    for _, kind in ipairs(M.kinds) do
        local style = db[kind]
        if type(style) == "table" then
            if style.targetHighlight ~= nil then style.targetStyle = style.targetHighlight == false and "none" or "border" end
            style.targetHighlight = nil
            for _, group in ipairs(M.auraGroups) do
                local value = style[group]
                if type(value) == "table" and value.grow == nil then value.grow = M.defaultGrow[value.anchor] end
            end
        end
    end
end

-- Version 5 -> 6: Color Softness is retired; the opacities take defaults.
local function MigrateV5(db)
    for _, kind in ipairs(M.kinds) do
        if type(db[kind]) == "table" then db[kind].softness = nil end
    end
end

-- Version 6 -> 7: the one indicator's place and sizes go to each indicator.
local RETIRED_V6 = { "indicatorAnchor", "indicatorX", "indicatorY", "indicatorSize", "indicatorFontSize" }
local function MigrateV6(db)
    for _, kind in ipairs(M.kinds) do
        local style = db[kind]
        if type(style) == "table" then
            if type(style.indicatorAnchor) == "string" then
                for _, part in ipairs(M.indicatorParts) do
                    style[part .. "Anchor"], style[part .. "X"], style[part .. "Y"] = style.indicatorAnchor, style.indicatorX, style.indicatorY
                end
                style.questSize, style.classificationSize, style.levelSize = style.indicatorSize, style.indicatorSize, style.indicatorFontSize
            end
            for _, key in ipairs(RETIRED_V6) do style[key] = nil end
        end
    end
end

local function ValidateGroup(value, default, label)
    assert(Public(value) and type(value) == "table", "Invalid nameplate aura group: " .. label)
    for key, fallback in pairs(default) do
        if value[key] == nil then value[key] = fallback end
        assert(Public(value[key]) and type(value[key]) == type(fallback), "Invalid nameplate aura setting: " .. label .. "." .. key)
    end
    for key, r in pairs(M.groupRanges) do
        local number = value[key]
        assert(Number(number, r[1], r[2]) and number == math.floor(number), "Invalid nameplate aura range: " .. label .. "." .. key)
    end
    assert(ANCHORS[value.anchor], "Invalid nameplate aura anchor: " .. label)
    assert(GROWS[value.grow], "Invalid nameplate aura grow direction: " .. label)
end

-- Texture choices are "mode" (foreground only), "flat", or any SharedMedia
-- status bar ("media:<name>"); a missing one draws as the default until it loads.
local function ValidTexture(value, foreground)
    return value == "flat" or (foreground and value == "mode") or (type(value) == "string" and value:match("^media:.+") ~= nil)
end
function M.TextureChoices(foreground)
    local list = { { id = "flat", label = "Flat" } }
    if foreground then table.insert(list, 1, { id = "mode", label = "Mode Gradient" }) end
    for _, choice in ipairs(addon.Media:GetStatusBars()) do
        if choice.key ~= "default" then list[#list + 1] = { id = choice.key, label = choice.label } end
    end
    return list
end

local function Validate(style, kind)
    assert(Public(style) and type(style) == "table", "Invalid nameplate settings: " .. kind)
    for key, default in pairs(M.styleDefaults[kind]) do
        if style[key] == nil then style[key] = Copy(default) end
        local value = style[key]
        assert(Public(value) and type(value) == type(default), "Invalid nameplate setting: " .. kind .. "." .. key)
        if M.colorKeys[key] then
            for i = 1, 3 do assert(Number(value[i], 0, 1), "Invalid nameplate color: " .. kind .. "." .. key) end
        end
    end
    for key, r in pairs(M.ranges) do
        local value = style[key]
        assert(Number(value, r[1], r[2]) and value == math.floor(value), "Invalid nameplate range: " .. kind .. "." .. key)
    end
    for key, allowed in pairs(ALLOWED) do assert(allowed[style[key]], "Invalid nameplate choice: " .. kind .. "." .. key) end
    assert(ValidTexture(style.foregroundTexture, true) and ValidTexture(style.backgroundTexture, false), "Invalid nameplate texture: " .. kind)
    assert(style.focusTexture == "default" or ValidTexture(style.focusTexture, true), "Invalid nameplate focus texture: " .. kind)
    for _, group in ipairs(M.auraGroups) do
        ValidateGroup(style[group], M.styleDefaults[kind][group], kind .. "." .. group)
        if FILTERS[group] then assert(FILTERS[group][style[group].filter], "Invalid nameplate aura filter: " .. kind .. "." .. group) end
    end
end

-- Fills defaults, migrates and validates; profile validation runs this on
-- detached copies.
function M.Initialize(db)
    if db.version == 1 then MigrateV1(db); db.version = 2 end
    if db.version == 2 then MigrateV2(db); db.version = 3 end
    if db.version == 3 then MigrateV3(db); db.version = 4 end
    if db.version == 4 then MigrateV4(db); db.version = 5 end
    if db.version == 5 then MigrateV5(db); db.version = 6 end
    if db.version == 6 then MigrateV6(db); db.version = 7 end
    if db.version == nil then db.version = M.VERSION end
    assert(db.version == M.VERSION, "Invalid nameplate settings version")
    for _, kind in ipairs(M.kinds) do
        if db[kind] == nil then db[kind] = Copy(M.styleDefaults[kind]) end
        Validate(db[kind], kind)
    end
end
