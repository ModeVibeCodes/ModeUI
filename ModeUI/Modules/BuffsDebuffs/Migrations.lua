local _, addon = ...
local M = addon.BuffsDebuffs
if not M then return end

-- Settings: defaults, validation and versions. Profile checks run these on
-- detached copies, so they touch nothing but the tables they're given. Bad
-- data stops with an error; nothing is ever reset.
local Style = addon.Style
local Public, Number = addon.IsPublic, addon.IsNumber
local function Copy(value) return addon.ProfileCodec.Copy(value) end

local BOOLEANS = { show = true, swipe = true, count = true, tooltip = true, cancel = true, byType = true }
local CHOICES = { kind = "kind", sort = "sort", grow = "grow", wrap = "wrap", timer = "timer", glow = "glow", glowColor = "glowColor" }
local function InList(list, value)
    for _, choice in ipairs(list) do if choice.id == value then return true end end
    return false
end
local function Color(value)
    if type(value) ~= "table" then return false end
    for i = 1, 3 do if not Number(value[i], 0, 1) then return false end end
    return true
end

-- One bar: missing keys from its defaults, then every value checked.
function M.ValidateBar(bar, defaults, fixedKind, where)
    assert(type(bar) == "table", "Invalid " .. where)
    for key, value in pairs(defaults) do if bar[key] == nil then bar[key] = Copy(value) end end
    for key in pairs(BOOLEANS) do assert(type(bar[key]) == "boolean", "Invalid " .. where .. "." .. key) end
    for key, list in pairs(CHOICES) do
        assert(Public(bar[key]) and InList(M.choices[list], bar[key]), "Invalid " .. where .. "." .. key)
    end
    assert(fixedKind == nil or bar.kind == fixedKind, "Invalid " .. where .. ".kind")
    -- Rows run across the way the icons grow.
    assert(M.HORIZONTAL[bar.grow] ~= M.HORIZONTAL[bar.wrap], "Invalid " .. where .. ".wrap")
    for key, range in pairs(M.ranges) do
        local value = bar[key]
        assert(Number(value, range[1], range[2]) and value == math.floor(value), "Invalid " .. where .. "." .. key)
    end
    assert(Public(bar.edgeStyle) and Style.EdgeStyle(bar.edgeStyle) ~= nil, "Invalid " .. where .. ".edgeStyle")
    assert(bar.edgeMetal == "default" or (Public(bar.edgeMetal) and Style.Tone.metal[bar.edgeMetal] ~= nil), "Invalid " .. where .. ".edgeMetal")
    assert(Color(bar.glowCustomColor) and Color(bar.timerColor) and Color(bar.countColor), "Invalid " .. where .. " colors")
    local point = false
    for _, name in ipairs(M.POINTS) do if bar.countPoint == name then point = true end end
    assert(point, "Invalid " .. where .. ".countPoint")
    assert(type(bar.cats) == "table", "Invalid " .. where .. ".cats")
    for id, on in pairs(bar.cats) do
        assert(on == true and M.categoryById[bar.kind][id] ~= nil, "Invalid " .. where .. ".cats." .. tostring(id))
    end
end

local function ValidateCustomList(db)
    assert(type(db.customBars) == "table" and #db.customBars <= M.MAX_CUSTOM, "Invalid buffs and debuffs custom bars")
    assert(Number(db.nextCustom, 1, 100000) and db.nextCustom == math.floor(db.nextCustom), "Invalid buffs and debuffs nextCustom")
    local seen = {}
    for index, entry in ipairs(db.customBars) do
        assert(type(entry) == "table" and Public(entry.id) and type(entry.id) == "string" and entry.id:match("^custom%d+$")
            and not seen[entry.id], "Invalid buffs and debuffs custom bar " .. index)
        assert(Public(entry.name) and type(entry.name) == "string" and entry.name ~= "" and #entry.name <= 40,
            "Invalid buffs and debuffs custom bar name " .. index)
        seen[entry.id] = true
    end
end

local function ValidateBlacklist(list)
    assert(type(list) == "table" and #list <= M.MAX_BLACKLIST, "Invalid buffs and debuffs blacklist")
    local seen = {}
    for index, id in ipairs(list) do
        assert(Number(id, 1, 10000000) and id == math.floor(id) and not seen[id], "Invalid blacklist entry " .. index)
        seen[id] = true
    end
end

function M.Initialize(db)
    -- A new profile starts with the owner's Defensives bar.
    if db.settingsVersion == nil and db.customBars == nil then
        db.customBars = { { id = "custom1", name = M.firstCustom.name } }
        db.bars = db.bars or {}
        db.bars.custom1 = db.bars.custom1 or Copy(M.firstCustom.bar)
        db.nextCustom = 2
    end
    -- Version 2 (owner, after the first in-game look, November 17, 2026):
    -- icon height, crop, border gap and text settings per bar; Player
    -- Debuffs 42 wide with a 2px border where still at the old defaults; the
    -- outline as a choice.
    if db.settingsVersion == 1 then
        for id, bar in pairs(type(db.bars) == "table" and db.bars or {}) do
            if type(bar) == "table" and Number(bar.width) then
                if id == "playerDebuffs" then
                    if bar.width == 30 then bar.width = 42 end
                    if bar.borderSize == 1 then bar.borderSize = 2 end
                end
                M.FillSizes(bar)
            end
        end
        if db.outline == false then db.outline = "none" elseif db.outline == true then db.outline = "outline" end
        db.settingsVersion = 2
    end
    for key, value in pairs(M.defaults) do
        if db[key] == nil then db[key] = Copy(value) end
    end
    assert(Number(db.settingsVersion, 1, M.SETTINGS_VERSION), "Invalid buffs and debuffs settings version")
    db.settingsVersion = M.SETTINGS_VERSION
    assert(type(db.bars) == "table", "Invalid buffs and debuffs bars")
    for _, id in ipairs(M.FIXED) do
        if db.bars[id] == nil then db.bars[id] = Copy(M.barDefaults[id]) end
        M.ValidateBar(db.bars[id], M.barDefaults[id], M.FIXED_KIND[id], "bar " .. id)
    end
    ValidateCustomList(db)
    for _, entry in ipairs(db.customBars) do
        if db.bars[entry.id] == nil then db.bars[entry.id] = Copy(M.customDefaults) end
        M.ValidateBar(db.bars[entry.id], M.customDefaults, nil, "bar " .. entry.id)
    end
    ValidateBlacklist(db.blacklist)
    for _, key in ipairs({ "shadow", "liftedShadow", "slug" }) do
        assert(type(db[key]) == "boolean", "Invalid buffs and debuffs " .. key)
    end
    assert(Public(db.outline) and InList(M.choices.outline, db.outline), "Invalid buffs and debuffs outline")
    assert(Public(db.font) and type(db.font) == "string" and Public(db.fontMedia) and type(db.fontMedia) == "string",
        "Invalid buffs and debuffs font")
    assert(Color(db.textColor) and Color(db.timerColor), "Invalid buffs and debuffs text colors")
end

-- The Player frame's auras move here from Unit Frames (owner, November 17,
-- 2026). Unit Frames keeps its saved Player buffs and debuffs untouched; on
-- this module's first start in a profile, a Player frame that showed either
-- turns this module on, so nobody loses their Player auras. The bars take
-- the owner's canvas layout rather than the old sizes.
function M.Adopt(db, modules)
    if db.settingsVersion ~= nil then return end
    local frames = type(modules) == "table" and modules.unitFrames
    local player = type(frames) == "table" and frames.player
    if type(player) ~= "table" then return end
    local function On(group) return type(player[group]) == "table" and player[group].enabled == true end
    if On("buffs") or On("debuffs") then db.enabled = true end
end
