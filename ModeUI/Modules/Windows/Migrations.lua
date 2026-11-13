local _, addon = ...
local M = addon.Windows
if not M then return end

-- Initialize(db): migrates, fills defaults and validates. Profile validation
-- runs it on detached copies, so it touches nothing but `db`. Bad data stops
-- with an error; settings are never reset. A window added to the registry
-- later is filled in as skinned with the default look; unknown window IDs
-- and stats (from a newer version) are kept.
-- Version 2 (November 13, 2026, per the owner): a 2px border in the unit
-- frames' rim color; a border still at version 1's default color follows.
-- Everything else new is filled in from the defaults.
local Public, Number = addon.IsPublic, addon.IsNumber
local function Copy(value) return addon.ProfileCodec.Copy(value) end

local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for i = 1, 3 do if not (Number(a[i]) and math.abs(a[i] - b[i]) < 1e-6) then return false end end
    return true
end

local ALLOWED = {}
for key, list in pairs(M.choices) do
    local set = {}
    for _, item in ipairs(list) do set[item.id] = true end
    ALLOWED[key] = set
end

function M.Initialize(db)
    if db.version == nil then db.version = M.VERSION end
    if db.version == 1 then
        if Same(db.borderColor, M.OLD_BORDER_COLOR) then db.borderColor = Copy(M.BORDER_COLOR) end
        db.version = 2
    end
    assert(db.version == M.VERSION, "Invalid window settings version")
    for key, default in pairs(M.defaults) do
        if db[key] == nil then db[key] = Copy(default) end
        local value = db[key]
        assert(Public(value) and type(value) == type(default), "Invalid window setting: " .. key)
        if M.colorKeys[key] then
            for i = 1, 3 do assert(Number(value[i], 0, 1), "Invalid window color: " .. key) end
        end
    end
    for id, on in pairs(db.windows) do
        assert(type(id) == "string" and type(on) == "boolean", "Invalid window switch: " .. tostring(id))
    end
    for id in pairs(M.byId) do
        if db.windows[id] == nil then db.windows[id] = true end
        if db.looks[id] == nil then db.looks[id] = Copy(M.LOOK) end
    end
    for id, look in pairs(db.looks) do
        assert(type(id) == "string" and type(look) == "table", "Invalid window look: " .. tostring(id))
        for key, default in pairs(M.LOOK) do
            if look[key] == nil then look[key] = default end
            assert(type(look[key]) == type(default), "Invalid window look setting: " .. key)
        end
        for key, r in pairs(M.lookRanges) do
            assert(Number(look[key], r[1], r[2]) and look[key] == math.floor(look[key]), "Invalid window look range: " .. key)
        end
    end
    for id, on in pairs(db.charStatList) do
        assert(type(id) == "string" and type(on) == "boolean", "Invalid character stat: " .. tostring(id))
    end
    for id, color in pairs(M.STAT_COLORS) do
        if db.charStatColors[id] == nil then db.charStatColors[id] = Copy(color) end
    end
    for id, color in pairs(db.charStatColors) do
        assert(type(id) == "string" and type(color) == "table", "Invalid stat color: " .. tostring(id))
        for i = 1, 3 do assert(Number(color[i], 0, 1), "Invalid stat color: " .. id) end
    end
    for key, r in pairs(M.ranges) do
        local value = db[key]
        assert(Number(value, r[1], r[2]) and value == math.floor(value), "Invalid window range: " .. key)
    end
    for key, allowed in pairs(ALLOWED) do assert(allowed[db[key]], "Invalid window choice: " .. key) end
end
