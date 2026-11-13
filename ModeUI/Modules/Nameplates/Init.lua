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
M.VERSION = 4
M.kinds = { "enemy", "friendly" }
M.kindLabels = { enemy = "Enemy", friendly = "Friendly" }
M.auraGroups = { "crowdControl", "debuffs", "buffs" }
M.auraGroupLabels = { crowdControl = "Crowd Control", debuffs = "Debuffs", buffs = "Buffs" }
local P, RGB = Kit.palette, Kit.RGB
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Enemies attacking you (red) and close to it (orange).
M.threatPalette = { aggro = RGB(255, 72, 72), warning = RGB(255, 160, 64) }

-- One aura group: shown or not, which auras (debuffs and buffs only), and
-- where: an anchor around the plate, an offset, the icon size and how many.
local function Group(show, filter, anchor, size, max)
    return { show = show, filter = filter, anchor = anchor, x = 0, y = 0, size = size, max = max }
end

-- One kind's settings. `show` off leaves that kind's plates to Blizzard.
local function Style(kind)
    local enemy = kind == "enemy"
    return {
        show = true,
        width = enemy and 140 or 120, healthHeight = enemy and 12 or 8, castHeight = 8,
        healthColorMode = "reaction", softness = 30, healthColor = Copy(P.green), threatColors = enemy,
        healthText = enemy and "percent" or "none", healthFontSize = 9,
        showName = true, nameFontSize = 10,
        showCastBar = true, castFontSize = 8, castColor = Copy(P.neutral), castLockedColor = Copy(P.tapped),
        showRaidIcon = true, targetHighlight = true,
        -- Auras: settings for every group, then each group on its own.
        showAuras = true, auraSpacing = 2, auraTimer = true, auraCount = true,
        crowdControl = Group(enemy, nil, "LEFT", enemy and 24 or 18, 2),
        debuffs = Group(true, enemy and "mine" or "dispellable", "TOP", enemy and 20 or 16, enemy and 6 or 4),
        buffs = Group(enemy, enemy and "dispellable" or "mine", "RIGHT", enemy and 18 or 14, 3),
        font = "game", fontMedia = "Expressway", outline = false, shadow = true, liftedShadow = true,
        textColor = Copy(P.text),
    }
end
M.styleDefaults = { enemy = Style("enemy"), friendly = Style("friendly") }
M.defaults = { version = M.VERSION, enemy = Copy(M.styleDefaults.enemy), friendly = Copy(M.styleDefaults.friendly) }
-- Keys Copy Style leaves alone.
M.identityKeys = { show = true }
M.colorKeys = { healthColor = true, castColor = true, castLockedColor = true, textColor = true }

M.ranges = { width = { 80, 250, 1 }, healthHeight = { 4, 30, 1 }, castHeight = { 4, 20, 1 }, softness = { 0, 100, 5 },
    healthFontSize = { 6, 20, 1 }, nameFontSize = { 6, 20, 1 }, castFontSize = { 6, 20, 1 }, auraSpacing = { 0, 8, 1 } }
M.groupRanges = { size = { 10, 40, 1 }, max = { 1, 12, 1 }, x = { -50, 50, 1 }, y = { -50, 50, 1 } }
-- Anchors around the plate, read like a compass: Top sits above the name,
-- Bottom below the cast bar, Left and Right beside the health bar.
M.anchors = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
M.anchorLabels = { TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right", LEFT = "Left", RIGHT = "Right",
    BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right" }
M.choices = {
    healthColorMode = { { id = "reaction", label = "Reaction and Class" }, { id = "reactionOnly", label = "Reaction" },
        { id = "onyx", label = "Onyx" }, { id = "custom", label = "Custom" } },
    healthText = { { id = "percent", label = "Percent" }, { id = "current", label = "Current Health" },
        { id = "both", label = "Current and Percent" }, { id = "none", label = "None" } },
}
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
local ALLOWED, ANCHORS, FILTERS = {}, Allowed(M.anchors), {}
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
                value.show, value.anchor = show, anchor
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
    if db.version == nil then db.version = M.VERSION end
    assert(db.version == M.VERSION, "Invalid nameplate settings version")
    for _, kind in ipairs(M.kinds) do
        if db[kind] == nil then db[kind] = Copy(M.styleDefaults[kind]) end
        Validate(db[kind], kind)
    end
end
