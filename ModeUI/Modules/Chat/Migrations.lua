local _, addon = ...
local M = addon.Chat
if not M then return end

-- Initialize(db): migrates, fills defaults and validates. Profile validation
-- runs it on detached copies, so it touches nothing but `db`. Bad data stops
-- with an error; settings are never reset.
-- Version 2 (November 13, 2026, per the owner): the window moved to Mode
-- Slate at 60% inside the unit frames' rim color, and the scroll bar is
-- skinned and shown. Values still at version 1's defaults follow; anything
-- the user picked stays.
local Public, Number = addon.IsPublic, addon.IsNumber
local function Copy(value) return addon.ProfileCodec.Copy(value) end

local ALLOWED = {}
for key, list in pairs(M.choices) do
    local set = {}
    for _, item in ipairs(list) do set[item.id] = true end
    ALLOWED[key] = set
end

local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for i = 1, 3 do if not (Number(a[i]) and math.abs(a[i] - b[i]) < 1e-6) then return false end end
    return true
end

-- Version 1's fill (later defaults follow on through the steps below);
-- its border color went with the border in version 4.
local function MigrateV1(db)
    if Same(db.backgroundColor, addon.Style.LEGACY.windowFill) then db.backgroundColor = Copy(addon.Kit.onyx.slate) end
    if db.backgroundOpacity == 72 then db.backgroundOpacity = M.defaults.backgroundOpacity end
    if db.scrollBar == false then db.scrollBar = true end
    db.version = 2
end

function M.Initialize(db)
    if db.version == nil then db.version = M.VERSION end
    if db.version == 1 then MigrateV1(db) end
    -- Version 3 (November 13, 2026, per the owner): the fill is the unit
    -- frames' health color; a fill still at version 2's Mode Slate follows.
    if db.version == 2 then
        if Same(db.backgroundColor, addon.Kit.onyx.slate) then db.backgroundColor = Copy(addon.Kit.onyx.health) end
        db.version = 3
    end
    -- Version 4 (November 13, 2026, per the owner): the window takes ModeUI's
    -- standard border, which has no settings, so Border, Border Size and
    -- Border Color go.
    if db.version == 3 then
        db.border, db.borderSize, db.borderColor = nil, nil, nil
        db.version = 4
    end
    -- Version 5: the health color moved from #1C1E21 to #131212.
    if db.version == 4 then
        if addon.Kit.IsOldOnyxHealth(db.backgroundColor) then db.backgroundColor = Copy(addon.Kit.onyx.health) end
        db.version = 5
    end
    -- Version 6 (Phase 7): the Mode design language. Graphite panel for a
    -- fill still at #131212; the Mode typeface for a face still at Expressway.
    if db.version == 5 then
        if Same(db.backgroundColor, addon.Kit.onyx.health) then db.backgroundColor = Copy(M.BACKGROUND_COLOR) end
        if db.fontMedia == "Expressway" then db.fontMedia = addon.Style.FONT_DEFAULT end
        db.version = 6
    end
    assert(db.version == M.VERSION, "Invalid chat settings version")
    for key, default in pairs(M.defaults) do
        if db[key] == nil then db[key] = Copy(default) end
        local value = db[key]
        assert(Public(value) and type(value) == type(default), "Invalid chat setting: " .. key)
        if M.colorKeys[key] then
            for i = 1, 3 do assert(Number(value[i], 0, 1), "Invalid chat color: " .. key) end
        end
    end
    for key, r in pairs(M.ranges) do
        local value = db[key]
        assert(Number(value, r[1], r[2]) and value == math.floor(value), "Invalid chat range: " .. key)
    end
    for key, allowed in pairs(ALLOWED) do assert(allowed[db[key]], "Invalid chat choice: " .. key) end
end
