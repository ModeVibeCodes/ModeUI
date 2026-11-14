local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Settings validation and the one-time layout-version migrations. Profile
-- validation runs Initialize on detached copies.
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local Public, Number, Kit = M.Public, M.Number, addon.Kit
local ALLOWED = {}
for key, list in pairs(M.choices) do
    ALLOWED[key] = {}
    for _, item in ipairs(list) do ALLOWED[key][item.id] = true end
end

local function Fill(target, defaults, label)
    for key, default in pairs(defaults) do
        if target[key] == nil then target[key] = Copy(default) end
        local v = target[key]
        assert(Public(v) and type(v) == type(default), "Invalid unit frame setting: " .. label .. key)
        if type(default) == "table" then
            for i = 1, 3 do assert(Number(v[i], 0, 1), "Invalid unit frame color: " .. label .. key) end
        end
    end
end
local function Ranged(v, r) return Number(v, r[1], r[2]) and v == math.floor(v) end

-- Phase-1 (layout version 1) frames: values a user changed from the phase-1
-- defaults carry into both frames once; everything else adopts the defaults.
local V1_FRAME = { width = 220, height = 36, powerHeight = 8 }
-- A frame's defaults as of layout version 16, text keys included.
local function LegacyFrame(unit)
    local frame = Copy(M.frameDefaults[unit])
    for key, value in pairs(M.legacyText[unit]) do frame[key] = Copy(value) end
    return frame
end
local function LegacyDefault(unit, key)
    local value = M.legacyText[unit][key]
    if value == nil then return M.frameDefaults[unit][key] end
    return value
end
local function MigrateV1(db)
    for _, unit in ipairs(M.units) do
        local old = db[unit]
        if type(old) == "table" then
            local new = LegacyFrame(unit)
            for _, key in ipairs({ "enabled", "hideBlizzard", "showPower", "showName", "healthText" }) do
                if type(old[key]) == type(new[key]) then new[key] = old[key] end
            end
            if old.showLevel == false then new.levelStyle = "none" end
            if Number(old.powerHeight, 2, 30) and old.powerHeight ~= V1_FRAME.powerHeight then new.powerHeight = math.floor(old.powerHeight) end
            if Number(old.width, 100, 400) and old.width ~= V1_FRAME.width then new.barWidth = math.floor(old.width) end
            if Number(old.height, 18, 80) and old.height ~= V1_FRAME.height then
                local power = new.showPower and new.powerHeight + 2 or 0
                new.healthHeight = math.max(10, math.min(60, math.floor(old.height - power - 8)))
            end
            if Number(db.scale, 50, 200) and db.scale ~= 100 then new.scale = math.floor(db.scale) end
            if db.classColor == false then new.healthColorMode = "custom" end
            local c = db.healthColor
            if type(c) == "table" and Number(c[1], 0, 1) and Number(c[2], 0, 1) and Number(c[3], 0, 1)
                and not (math.abs(c[1] - 52 / 255) < 1e-6 and math.abs(c[2] - 168 / 255) < 1e-6 and math.abs(c[3] - 83 / 255) < 1e-6) then
                new.healthColor = Copy(c); new.healthColorMode = "custom"
            end
            if Number(db.fontSize, 8, 24) and db.fontSize ~= 12 then
                new.nameFontSize = math.floor(db.fontSize); new.healthFontSize = math.floor(db.fontSize)
            end
            if type(db.fontMedia) == "string" and db.fontMedia ~= "" then new.font, new.fontMedia = db.font, db.fontMedia end
            if type(db.outline) == "boolean" then new.outline = db.outline end
            if type(db.shadow) == "boolean" then new.shadow = db.shadow end
            db[unit] = new
        end
    end
end

-- Layout versions 2-7 only changed keys that are either still used (name
-- alignment, the 22 -> 26 health bar, Expressway, the level's own size) or
-- retired by version 9; each step keeps its effect on the keys that remain.
local function MigrateV2toV7(db, from)
    for _, unit in ipairs(M.units) do
        local frame = db[unit]
        if type(frame) == "table" then
            if from <= 5 then
                frame.nameAlign = "RIGHT"
                if frame.healthHeight == 22 then frame.healthHeight = 26 end
            end
            if from <= 6 and frame.fontMedia == "PTG Lato" then frame.fontMedia = "Expressway" end
            if from <= 7 and frame.levelFontSize == nil and Number(frame.healthFontSize, 6, 24) then
                frame.levelFontSize = math.floor(frame.healthFontSize)
            end
        end
    end
end

-- Layout version 8 -> 9, per the owner: one locked Onyx skin. Palettes, border
-- styles, background/border colors and thickness, and the name sheen are
-- retired; health uses Default (#131212), Class Color or Custom; names use the
-- Mist accent; the portrait ring becomes the class gradient unless Custom.
local RETIRED = { "palette", "paletteHealth", "paletteTrack", "paletteBorder", "paletteInner", "rimThickness",
    "gapThickness", "hairlineThickness", "nameSheen", "nameSheenStrength", "borderStyle", "borderColor", "borderOpacity",
    "backgroundColor", "backgroundOpacity", "trimColor", "showFrameEdge", "barBorderColor", "barBorderOpacity", "portraitSize" }
-- Every retired key, for checks; each migration removes only its own.
M.retiredKeys = {}
for _, key in ipairs(RETIRED) do M.retiredKeys[#M.retiredKeys + 1] = key end
local HEALTH_MODE = { custom = "custom", class = "class", reaction = "class" }
local function MigrateV8(db)
    for _, unit in ipairs(M.units) do
        local frame = db[unit]
        if type(frame) == "table" then
            frame.healthColorMode = HEALTH_MODE[frame.healthColorMode] or "default"
            frame.nameColorMode = "accent"
            if frame.portraitRing ~= "custom" then frame.portraitRing = "class" end
            if frame.namePosition ~= "bar" then frame.namePosition = "above" end
            if frame.levelStyle ~= "none" then frame.levelStyle = "badge" end
            for _, key in ipairs(RETIRED) do frame[key] = nil end
        end
    end
end

-- Layout version 9 -> 10, per the owner: the Mist accent and its glow are
-- replaced by Champagne/Lilac/Frost names with a crisp lifted shadow.
local RETIRED_V10 = { "nameGlow", "nameGlowStrength" }
for _, key in ipairs(RETIRED_V10) do M.retiredKeys[#M.retiredKeys + 1] = key end
local function MigrateV9(db)
    for _, unit in ipairs(M.units) do
        local frame = db[unit]
        if type(frame) == "table" then
            if frame.nameColorMode ~= "class" and frame.nameColorMode ~= "custom" then frame.nameColorMode = "champagne" end
            for _, key in ipairs(RETIRED_V10) do frame[key] = nil end
        end
    end
end

-- Layout version 10 -> 11, per the owner: Sky (#91C6FF) names to try, the
-- lifted shadow on every text instead of just the name, and a matched Target
-- that copies the Player's text layout rather than mirroring it.
local PRESET_NAME = { champagne = true, lilac = true, frost = true }
M.retiredKeys[#M.retiredKeys + 1] = "nameLift"
local function MigrateV10(db)
    for _, unit in ipairs(M.units) do
        local frame = db[unit]
        if type(frame) == "table" then
            if PRESET_NAME[frame.nameColorMode] then frame.nameColorMode = "sky" end
            if type(frame.nameLift) == "boolean" then frame.liftedShadow = frame.nameLift end
            frame.nameLift = nil
        end
    end
end

-- Layout version 11 -> 12, per the owner: every bar uses the Mode Gradient
-- texture (Kit.ModeGradient), so the Bar Texture choice is retired.
M.retiredKeys[#M.retiredKeys + 1] = "texture"
local function MigrateV11(db)
    for _, unit in ipairs(M.units) do
        if type(db[unit]) == "table" then db[unit].texture = nil end
    end
end

-- Layout version 12 -> 13, per the owner: new Target of Target, Focus and
-- Target of Focus defaults (no portrait, name in the bar, 75%/90% scale, the
-- small Focus). A setting still at its version 12 default takes the new one;
-- anything the user changed stays.
local SMALL_V12 = { scale = 100, showPortrait = true, namePosition = "above", nameAlign = "RIGHT" }
local V12 = { targettarget = SMALL_V12, focustarget = SMALL_V12,
    focus = { scale = 100, showPortrait = true, namePosition = "above", nameAlign = "RIGHT", barWidth = 150, healthHeight = 22,
        powerHeight = 8, nameFontSize = 12, healthFontSize = 11, levelStyle = "badge" } }
local function MigrateV12(db)
    for unit, old in pairs(V12) do
        local frame = db[unit]
        if type(frame) == "table" then
            for key, value in pairs(old) do
                if frame[key] == value then frame[key] = Copy(LegacyDefault(unit, key)) end
            end
        end
    end
end

-- Layout version 13 -> 14, per the owner: bar backgrounds become Mode Slate at
-- 70%. A frame still on the old Flat texture or the old 25% takes the new one.
local function MigrateV13(db)
    for _, unit in ipairs(M.units) do
        local frame = db[unit]
        if type(frame) == "table" then
            if frame.backgroundTexture == "flat" then frame.backgroundTexture = "slate" end
            if frame.barBackgroundOpacity == 25 then frame.barBackgroundOpacity = 70 end
        end
    end
    -- Frame Width became each frame's own: a matched Target keeps the width it
    -- showed (the Player's).
    local player, target = db.player, db.target
    if type(player) == "table" and type(target) == "table" and target.matchPlayer == true and Number(player.barWidth, 100, 400) then
        target.barWidth = math.floor(player.barWidth)
    end
end

-- Layout version 14 -> 15, per the owner: the level moves to the health bar's
-- bottom corner (a new key, so frames take it on load), and a Target matching
-- the Player mirrors its text: health on the left, level bottom right.
local function MigrateV14(db)
    local target = db.target
    if type(target) == "table" and target.matchPlayer == true then target.mirrorText = true end
end

-- Layout version 15 -> 16, per the owner: one border (the black gap inside the
-- rim is gone, a geometry change) and names above the frame sit on the border.
local function MigrateV15(db)
    for _, unit in ipairs(M.units) do
        local frame = db[unit]
        if type(frame) == "table" and frame.namePosition == "above" then frame.namePosition = "border" end
    end
end

-- Layout version 16 -> 17, per the owner: text slots (TextSlots.lua) replace
-- the name, level, health and power text keys. Each frame's texts move into
-- the matching slots, so nothing moves; the old keys are removed.
local LEGACY_TEXT = {}
for key in pairs(M.legacyText.player) do LEGACY_TEXT[#LEGACY_TEXT + 1] = key end
for _, key in ipairs(LEGACY_TEXT) do M.retiredKeys[#M.retiredKeys + 1] = key end
local function MigrateV16(db)
    for _, unit in ipairs(M.units) do
        local frame = db[unit]
        if type(frame) == "table" then
            local old = setmetatable({}, { __index = function(_, key)
                local value = frame[key]
                if value == nil or not Public(value) then return LegacyDefault(unit, key) end
                return value
            end })
            if type(frame.texts) ~= "table" then frame.texts = M.SlotsFromLegacy(unit, old) end
            for _, key in ipairs(LEGACY_TEXT) do frame[key] = nil end
        end
    end
end

-- Layout version 17 -> 18, per the owner: the power bar and the cast bar get
-- their own textures (and the power bar its own opacity). Each starts as the
-- shared bar settings it used, so nothing changes on screen.
local SHARED_POWER = { foregroundTexture = "powerForegroundTexture", backgroundTexture = "powerBackgroundTexture",
    barForegroundOpacity = "powerForegroundOpacity", barBackgroundOpacity = "powerBackgroundOpacity" }
local function MigrateV17(db)
    for _, unit in ipairs(M.units) do
        local frame = db[unit]
        if type(frame) == "table" then
            for from, to in pairs(SHARED_POWER) do
                if frame[to] == nil and Public(frame[from]) then frame[to] = frame[from] end
            end
            local cast = frame.castBar
            if type(cast) == "table" and Public(cast) then
                if cast.foregroundTexture == nil and Public(frame.foregroundTexture) then cast.foregroundTexture = frame.foregroundTexture end
                if cast.backgroundTexture == nil and Public(frame.backgroundTexture) then cast.backgroundTexture = frame.backgroundTexture end
            end
        end
    end
end

-- Version 18 -> 19: a Focus cast bar still at the old 3px gap moves to the
-- 8px the owner asked for. Full Width (on) and Bar Width take their defaults.
local function MigrateV18(db)
    local cast = type(db.focus) == "table" and db.focus.castBar
    if type(cast) == "table" and Public(cast) and cast.gap == 3 then cast.gap = 8 end
end

-- Pure defaults, one-time migration and validation; profile validation runs
-- this on detached copies. Retired phase-1 top-level keys are left in place.
function M.Initialize(db)
    -- Phase-1 frames take the version 16 defaults, then gain text slots.
    if db.layoutVersion == nil and type(db.player) == "table" and db.player.width ~= nil then MigrateV1(db); db.layoutVersion = 16 end
    local from = db.layoutVersion
    if Number(from, 2, 7) then MigrateV2toV7(db, from); db.layoutVersion = 8 end
    if db.layoutVersion == 8 then MigrateV8(db); db.layoutVersion = 9 end
    if db.layoutVersion == 9 then MigrateV9(db); db.layoutVersion = 10 end
    if db.layoutVersion == 10 then MigrateV10(db); db.layoutVersion = 11 end
    if db.layoutVersion == 11 then MigrateV11(db); db.layoutVersion = 12 end
    if db.layoutVersion == 12 then MigrateV12(db); db.layoutVersion = 13 end
    if db.layoutVersion == 13 then MigrateV13(db); db.layoutVersion = 14 end
    if db.layoutVersion == 14 then MigrateV14(db); db.layoutVersion = 15 end
    if db.layoutVersion == 15 then MigrateV15(db); db.layoutVersion = 16 end
    if db.layoutVersion == 16 then MigrateV16(db); db.layoutVersion = 17 end
    if db.layoutVersion == 17 then MigrateV17(db); db.layoutVersion = 18 end
    if db.layoutVersion == 18 then MigrateV18(db); db.layoutVersion = M.LAYOUT_VERSION end
    db.layoutVersion = db.layoutVersion or M.LAYOUT_VERSION
    assert(db.layoutVersion == M.LAYOUT_VERSION, "Invalid unit frame layout version")
    for _, unit in ipairs(M.units) do
        if db[unit] == nil then db[unit] = Copy(M.frameDefaults[unit]) end
        local frame = db[unit]
        assert(Public(frame) and type(frame) == "table", "Invalid unit frame settings: " .. unit)
        Fill(frame, M.frameDefaults[unit], unit .. ".")
        for key, r in pairs(M.frameRanges) do assert(Ranged(frame[key], r), "Invalid unit frame range: " .. unit .. "." .. key) end
        for key, list in pairs(M.choiceKeys) do assert(ALLOWED[list][frame[key]], "Invalid unit frame choice: " .. unit .. "." .. key) end
        assert(Kit.ValidBarTexture(frame.foregroundTexture, true) and Kit.ValidBarTexture(frame.backgroundTexture, false)
            and Kit.ValidBarTexture(frame.powerForegroundTexture, true) and Kit.ValidBarTexture(frame.powerBackgroundTexture, false),
            "Invalid unit frame texture: " .. unit)
        local cast = M.ValidateTable(frame, "castBar", M.CastDefaults(unit), M.castRanges, M.castChoices)
        assert(Kit.ValidBarTexture(cast.foregroundTexture, true) and Kit.ValidBarTexture(cast.backgroundTexture, false),
            "Invalid unit frame cast bar texture: " .. unit)
        M.ValidateTable(frame, "status", M.StatusDefaults(unit), M.statusRanges, M.statusChoices)
        local texts = M.ValidateTable(frame, "texts", {}, {})
        for _, slot in ipairs(M.textSlots) do
            M.ValidateTable(texts, slot, M.TextDefaults(unit, slot), M.textRanges, M.TextChoices(slot))
        end
        for _, group in ipairs(M.auraGroups) do
            M.ValidateTable(frame, group, M.AuraDefaults(unit, group), M.auraRanges, M.AuraChoices(group))
        end
    end
    M.ValidateTable(db, "comboPoints", M.comboDefaults, M.comboRanges, { arc = "comboArc" })
end

-- A nested settings table (combo points, and per-frame cast bar and auras):
-- filled with defaults, then every range and choice checked.
function M.ValidateTable(parent, key, defaults, ranges, choiceLists)
    if parent[key] == nil then parent[key] = Copy(defaults) end
    local t = parent[key]
    assert(Public(t) and type(t) == "table", "Invalid unit frame settings: " .. key)
    Fill(t, defaults, key .. ".")
    for name, r in pairs(ranges) do assert(Ranged(t[name], r), "Invalid unit frame range: " .. key .. "." .. name) end
    for name, list in pairs(choiceLists or {}) do assert(ALLOWED[list][t[name]], "Invalid unit frame choice: " .. key .. "." .. name) end
    return t
end
