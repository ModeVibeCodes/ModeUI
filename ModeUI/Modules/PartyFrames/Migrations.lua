local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- Settings validation and the settings migrations (versions listed in
-- Init.lua beside M.VERSION). Profile validation runs Initialize on detached
-- copies, so nothing here touches frames. Bad data raises an error; it is
-- never reset.
local Kit = addon.Kit
local Public, Number = addon.IsPublic, addon.IsNumber
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local function Allowed(list)
    local set = {}
    for _, item in ipairs(list) do set[type(item) == "table" and item.id or item] = true end
    return set
end
local CHOICES, GROUP_CHOICES, FILTERS = {}, {}, {}
for key, list in pairs(M.choiceKeys) do CHOICES[key] = Allowed(M.choices[list]) end
for key, list in pairs(M.groupChoiceKeys) do GROUP_CHOICES[key] = Allowed(M.choices[list] or M[list]) end
for group, list in pairs(M.auraFilters) do FILTERS[group] = Allowed(list) end
local ANCHORS, PLACES = Allowed(M.anchors), Allowed(M.choices.place)

local function Whole(value, range) return Number(value, range[1], range[2]) and value == math.floor(value) end
local function Color(value) return Public(value) and type(value) == "table" and Number(value[1], 0, 1) and Number(value[2], 0, 1) and Number(value[3], 0, 1) end

-- Version 1 -> 2. Frames at the old default size take the new, taller one.
-- Buffs become Healing Buffs (in their place), Debuffs' place goes to every
-- debuff type and Other Debuffs, Dispellable is folded into the types, and
-- each group's size and shape become a width and height. The dispel highlight
-- style becomes the per-type effects.
local OLD_FILTERS = { buffs = { mine = "mine", mineRaid = "mine", raid = "all", cast = "all", all = "all" },
    debuffs = { raid = "raid", all = "all", notDispellable = "all", mine = "mine" } }
local function Sized(old)
    local group = Copy(old)
    if Number(old.size, 8, 48) then
        group.width = math.floor(old.size)
        group.height = old.shape == "square" and group.width or math.max(8, group.width - 4)
    end
    group.size, group.shape = nil, nil
    return group
end
local function MigrateV1(db)
    if db.healthHeight == 34 then db.healthHeight = M.defaults.healthHeight end
    if db.powerHeight == 5 then db.powerHeight = M.defaults.powerHeight end
    local old = type(db.auras) == "table" and db.auras or {}
    local auras = {}
    if type(old.buffs) == "table" then
        auras.heals = Sized(old.buffs)
        auras.heals.filter = OLD_FILTERS.buffs[old.buffs.filter] or "all"
    end
    if type(old.debuffs) == "table" then
        local place = Sized(old.debuffs)
        for group in pairs(M.groupDispelType) do
            local typed = Copy(place)
            typed.filter = "all"
            auras[group] = typed
        end
        auras.otherDebuffs = Copy(place)
        auras.otherDebuffs.filter = OLD_FILTERS.debuffs[old.debuffs.filter] or "raid"
    end
    for _, group in ipairs({ "defensives", "crowdControl" }) do
        if type(old[group]) == "table" then auras[group] = Sized(old[group]) end
    end
    db.auras = auras
    local style = db.dispelHighlight
    if style ~= nil then
        db.dispel = {}
        for _, kind in ipairs(M.dispelTypes) do
            db.dispel[kind] = { border = style == "border", health = false, gradient = style == "fill" }
        end
    end
    db.dispelHighlight = nil
end

-- Version 2 -> 3. Frames at the old default height and spacing take the new
-- ones (8px taller, 1px apart). The power bar gets its own opacities, copied
-- from the bars'. Debuff type groups that showed every debuff of their type
-- now show the ones you can't dispel, as Dispellable by You comes first in
-- their row (in the Magic group's place).
local function MigrateV2(db)
    if db.healthHeight == 44 then db.healthHeight = M.defaults.healthHeight end
    if db.spacing == 4 then db.spacing = M.defaults.spacing end
    if db.powerOpacity == nil and Number(db.healthOpacity, 10, 100) then db.powerOpacity = db.healthOpacity end
    if db.powerBackgroundOpacity == nil and Number(db.backgroundOpacity, 0, 100) then db.powerBackgroundOpacity = db.backgroundOpacity end
    local auras = type(db.auras) == "table" and db.auras or nil
    if not auras then return end
    for group in pairs(M.groupDispelType) do
        local g = auras[group]
        if type(g) == "table" and (g.filter == "all" or g.filter == "mine") then g.filter = "notMine" end
    end
    if auras.dispellable == nil and type(auras.magic) == "table" then
        local place = Copy(M.auraDefaults.dispellable)
        for _, key in ipairs({ "anchor", "place", "grow", "x", "y", "width", "height", "spacing", "perRow" }) do
            if auras.magic[key] ~= nil then place[key] = auras.magic[key] end
        end
        auras.dispellable = place
    end
end

-- A tracked group's spells: whole spell IDs, each once, at most MAX_TRACKED_SPELLS.
local function ValidateSpells(spells, group)
    assert(#spells <= M.MAX_TRACKED_SPELLS, "Too many tracked spells: " .. group)
    local seen = {}
    for key, id in pairs(spells) do
        assert(type(key) == "number" and key >= 1 and key <= #spells and key == math.floor(key), "Invalid tracked spell list: " .. group)
        assert(Number(id, 1, 10000000) and id == math.floor(id) and not seen[id], "Invalid tracked spell: " .. group)
        seen[id] = true
    end
end

local function ValidateGroup(value, default, group)
    assert(Public(value) and type(value) == "table", "Invalid party aura group: " .. group)
    for key, fallback in pairs(default) do
        if value[key] == nil then value[key] = Copy(fallback) end
        assert(Public(value[key]) and type(value[key]) == type(fallback), "Invalid party aura setting: " .. group .. "." .. key)
    end
    for key, range in pairs(M.auraRanges) do
        assert(Whole(value[key], range), "Invalid party aura range: " .. group .. "." .. key)
    end
    assert(FILTERS[group][value.filter], "Invalid party aura filter: " .. group)
    for key, allowed in pairs(GROUP_CHOICES) do assert(allowed[value[key]], "Invalid party aura choice: " .. group .. "." .. key) end
    assert(Color(value.borderColor) and Color(value.glowCustomColor), "Invalid party aura color: " .. group)
    if default.spells then ValidateSpells(value.spells, group) end
end

local function ValidateDispel(db)
    assert(Public(db.dispel) and type(db.dispel) == "table", "Invalid party frame dispel effects")
    for _, kind in ipairs(M.dispelTypes) do
        if db.dispel[kind] == nil then db.dispel[kind] = Copy(M.defaults.dispel[kind]) end
        local effects = db.dispel[kind]
        assert(Public(effects) and type(effects) == "table", "Invalid party frame dispel effects: " .. kind)
        for key, fallback in pairs(M.defaults.dispel[kind]) do
            if effects[key] == nil then effects[key] = fallback end
            assert(type(effects[key]) == "boolean", "Invalid party frame dispel effect: " .. kind .. "." .. key)
        end
    end
end

-- Fills defaults, migrates and validates. Unknown keys are left alone (a
-- newer ModeUI's settings survive an older one).
function M.Initialize(db)
    if db.version == 1 then MigrateV1(db); db.version = 2 end
    if db.version == 2 then MigrateV2(db); db.version = 3 end
    if db.version == nil then db.version = M.VERSION end
    assert(db.version == M.VERSION, "Invalid party frame settings version")
    for key, default in pairs(M.defaults) do
        if db[key] == nil then db[key] = Copy(default) end
        local value = db[key]
        assert(Public(value) and type(value) == type(default), "Invalid party frame setting: " .. key)
        if M.colorKeys[key] then assert(Color(value), "Invalid party frame color: " .. key) end
    end
    for key, range in pairs(M.ranges) do
        assert(Whole(db[key], range), "Invalid party frame range: " .. key)
    end
    for key, allowed in pairs(CHOICES) do assert(allowed[db[key]], "Invalid party frame choice: " .. key) end
    assert(FILTERS.dispel[db.dispelFilter], "Invalid party frame dispel filter")
    for _, element in ipairs(M.elements) do
        assert(ANCHORS[db[element .. "Anchor"]] and PLACES[db[element .. "Place"]], "Invalid party frame placement: " .. element)
    end
    local valid, fill = Kit.ValidBarTexture, Kit.ValidFillTexture
    assert(valid(db.foregroundTexture, true) and valid(db.backgroundTexture, false)
        and valid(db.powerForegroundTexture, true) and valid(db.powerBackgroundTexture, false), "Invalid party frame texture")
    assert(fill(db.healTexture) and fill(db.shieldTexture) and fill(db.overshieldTexture), "Invalid party frame fill texture")
    ValidateDispel(db)
    for _, group in ipairs(M.auraGroups) do
        if db.auras[group] == nil then db.auras[group] = Copy(M.auraDefaults[group]) end
        ValidateGroup(db.auras[group], M.auraDefaults[group], group)
    end
end
