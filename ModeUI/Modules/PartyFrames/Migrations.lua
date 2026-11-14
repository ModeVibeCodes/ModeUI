local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- Settings validation (and, from version 2 on, the settings migrations).
-- Profile validation runs Initialize on detached copies, so nothing here
-- touches frames. Bad data raises an error; it is never reset.
local Kit = addon.Kit
local Public, Number = addon.IsPublic, addon.IsNumber
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local function Allowed(list)
    local set = {}
    for _, item in ipairs(list) do set[type(item) == "table" and item.id or item] = true end
    return set
end
local CHOICES, ANCHORS, PLACES, GROWS, SHAPES, BORDERS = {}, Allowed(M.anchors), Allowed(M.choices.place),
    Allowed(M.growChoices), Allowed(M.choices.auraShape), Allowed(M.choices.auraBorder)
for key, list in pairs(M.choiceKeys) do CHOICES[key] = Allowed(M.choices[list]) end
local FILTERS = {}
for group, list in pairs(M.auraFilters) do FILTERS[group] = Allowed(list) end

local function Whole(value, range) return Number(value, range[1], range[2]) and value == math.floor(value) end

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
    assert(ANCHORS[value.anchor] and PLACES[value.place] and GROWS[value.grow], "Invalid party aura placement: " .. group)
    assert(SHAPES[value.shape] and BORDERS[value.border], "Invalid party aura look: " .. group)
end

-- Fills defaults and validates. Unknown keys are left alone (a newer
-- ModeUI's settings survive an older one).
function M.Initialize(db)
    if db.version == nil then db.version = M.VERSION end
    assert(db.version == M.VERSION, "Invalid party frame settings version")
    for key, default in pairs(M.defaults) do
        if db[key] == nil then db[key] = Copy(default) end
        local value = db[key]
        assert(Public(value) and type(value) == type(default), "Invalid party frame setting: " .. key)
        if M.colorKeys[key] then
            for i = 1, 3 do assert(Number(value[i], 0, 1), "Invalid party frame color: " .. key) end
        end
    end
    for key, range in pairs(M.ranges) do
        assert(Whole(db[key], range), "Invalid party frame range: " .. key)
    end
    for key, allowed in pairs(CHOICES) do assert(allowed[db[key]], "Invalid party frame choice: " .. key) end
    assert(FILTERS.dispellable[db.dispelFilter], "Invalid party frame dispel filter")
    for _, element in ipairs(M.elements) do
        assert(ANCHORS[db[element .. "Anchor"]] and PLACES[db[element .. "Place"]], "Invalid party frame placement: " .. element)
    end
    local valid = Kit.ValidBarTexture
    assert(valid(db.foregroundTexture, true) and valid(db.backgroundTexture, false)
        and valid(db.powerForegroundTexture, true) and valid(db.powerBackgroundTexture, false), "Invalid party frame texture")
    for _, group in ipairs(M.auraGroups) do
        if db.auras[group] == nil then db.auras[group] = Copy(M.auraDefaults[group]) end
        ValidateGroup(db.auras[group], M.auraDefaults[group], group)
    end
end
