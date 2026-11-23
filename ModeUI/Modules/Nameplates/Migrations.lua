local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Settings validation and the settings-version migrations (the versions are
-- listed in Init.lua beside M.VERSION). Profile validation runs Initialize on
-- detached copies, so nothing here touches frames.
local Kit = addon.Kit
local function Copy(value) return addon.ProfileCodec.Copy(value) end

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

-- Version 7 -> 8: the old orange default (255, 140, 40) becomes #FF5948;
-- a color the owner picked stays.
local function MigrateV7(db)
    local function Near(a, b) return math.abs(a - b) < 0.002 end
    for _, kind in ipairs(M.kinds) do
        local style = db[kind]
        local c = type(style) == "table" and style.auraCCNoTypeColor
        if type(c) == "table" and Number(c[1]) and Number(c[2]) and Number(c[3])
            and Near(c[1], 1) and Near(c[2], 140 / 255) and Near(c[3], 40 / 255) then
            style.auraCCNoTypeColor = Copy(addon.Style.Tone.debuffType.crowdControl)
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

-- Version 8 -> 9: the Mode design language. Values still at their version 8
-- default take the new one, per kind; anything the player picked stays.
local V8 = { foregroundTexture = "mode", backgroundTexture = "flat", backgroundOpacity = 55, nameColorMode = "text",
    fontMedia = "Expressway", liftedShadow = true }
local function MigrateV8(db)
    for _, kind in ipairs(M.kinds) do
        local style, defaults = db[kind], M.styleDefaults[kind]
        if type(style) == "table" then
            for key, old in pairs(V8) do if style[key] == old then style[key] = Copy(defaults[key]) end end
            if addon.Style.SameColor(style.targetColor, Kit.palette.accent) then style.targetColor = Copy(defaults.targetColor) end
            if addon.Style.SameColor(style.focusColor, addon.Style.LEGACY.nameplateFocus) then style.focusColor = Copy(defaults.focusColor) end
        end
    end
end

-- Version 9 -> 10: auras wear the frameThin edge. Border Size 2 (the old
-- default) takes 1, 3 becomes 2; Corners retire; the old no-type rim takes
-- the Gunmetal one.
local function MigrateV9(db)
    for _, kind in ipairs(M.kinds) do
        local style = db[kind]
        if type(style) == "table" then
            if style.auraBorderSize == 2 then style.auraBorderSize = 1 elseif style.auraBorderSize == 3 then style.auraBorderSize = 2 end
            style.auraCorners = nil
            if addon.Style.SameColor(style.auraNoTypeColor, Kit.onyx.border) then
                style.auraNoTypeColor = Copy(M.styleDefaults[kind].auraNoTypeColor)
            end
        end
    end
end

-- Version 10 -> 11: empty bars still solid (100) take the semi-transparent 60.
local function MigrateV10(db)
    for _, kind in ipairs(M.kinds) do
        local style = db[kind]
        if type(style) == "table" and style.backgroundOpacity == 100 then style.backgroundOpacity = 60 end
    end
end

local ValidTexture = Kit.ValidBarTexture

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
    assert(ValidTexture(style.castTexture, true), "Invalid nameplate cast texture: " .. kind)
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
    if db.version == 7 then MigrateV7(db); db.version = 8 end
    if db.version == 8 then MigrateV8(db); db.version = 9 end
    if db.version == 9 then MigrateV9(db); db.version = 10 end
    if db.version == 10 then MigrateV10(db); db.version = 11 end
    if db.version == 11 then M.MigrateV11(db); db.version = 12 end
    if db.version == nil then db.version = M.VERSION end
    assert(db.version == M.VERSION, "Invalid nameplate settings version")
    for _, kind in ipairs(M.kinds) do
        if db[kind] == nil then db[kind] = Copy(M.styleDefaults[kind]) end
        Validate(db[kind], kind)
    end
    if db.hideBlizzardCombatIcon == nil then db.hideBlizzardCombatIcon = false end
    assert(type(db.hideBlizzardCombatIcon) == "boolean", "Invalid nameplate setting: hideBlizzardCombatIcon")
    M.ValidateSavedCVars(db)
end
