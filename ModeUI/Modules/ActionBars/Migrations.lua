local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- Initialize(db): fills defaults and validates every bar's settings. Profile
-- validation runs it on detached copies, so it touches no frames. Bad data
-- stops with an error; settings are never reset.
local Public, Number = addon.IsPublic, addon.IsNumber
local function Copy(value) return addon.ProfileCodec.Copy(value) end

local ALLOWED = {}
for key, list in pairs(M.choices) do
    local set = {}
    for _, item in ipairs(list) do set[type(item) == "table" and item.id or item] = true end
    ALLOWED[key] = set
end

-- Custom show conditions are macro conditions ("[combat] show; hide"): one
-- line of text. Whether the game understands them is checked when applied.
local function ValidConditions(text)
    return type(text) == "string" and #text <= M.MAX_CONDITIONS and not text:find("[\r\n]")
end

local function Validate(style, bar)
    assert(Public(style) and type(style) == "table", "Invalid action bar settings: " .. bar)
    for key, default in pairs(M.styleDefaults[bar]) do
        if style[key] == nil then style[key] = Copy(default) end
        local value = style[key]
        assert(Public(value) and type(value) == type(default), "Invalid action bar setting: " .. bar .. "." .. key)
        if M.colorKeys[key] then
            for i = 1, 3 do assert(Number(value[i], 0, 1), "Invalid action bar color: " .. bar .. "." .. key) end
        end
    end
    for key, r in pairs(M.ranges) do
        local value = style[key]
        assert(Number(value, r[1], r[2]) and value == math.floor(value), "Invalid action bar range: " .. bar .. "." .. key)
    end
    -- The pet and stance bars have ten buttons.
    assert(style.buttons <= M.barSpecs[bar].count, "Invalid action bar button count: " .. bar)
    for key, allowed in pairs(ALLOWED) do assert(allowed[style[key]], "Invalid action bar choice: " .. bar .. "." .. key) end
    assert(ValidConditions(style.customVisibility), "Invalid action bar conditions: " .. bar)
end

-- Version 1 -> 2: settings still at version 1's defaults take the new ones
-- (42 by 36 buttons, amber cooldown numbers); Fade Until Mouseover becomes
-- the Mouseover show choice. Background Opacity takes its default.
local function SameColor(a, b) return type(a) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end
local function MigrateV1(db)
    for _, bar in ipairs(M.bars) do
        local style = db[bar]
        if type(style) == "table" then
            if style.height == 38 then style.height = 36 end
            if SameColor(style.cooldownColor, { 1, 1, 1 }) then style.cooldownColor = Copy(M.COOLDOWN_COLOR) end
            if style.fade == true and style.visibility == "always" then style.visibility = "mouseover" end
            style.fade = nil
        end
    end
    -- The bars' places live outside this table; OnInitialize moves them (Driver.lua).
    db.movePlaces = true
end

function M.Initialize(db)
    if db.version == 1 then MigrateV1(db); db.version = 2 end
    if db.version == nil then db.version = M.VERSION end
    assert(db.version == M.VERSION, "Invalid action bar settings version")
    for _, bar in ipairs(M.bars) do
        if db[bar] == nil then db[bar] = Copy(M.styleDefaults[bar]) end
        Validate(db[bar], bar)
    end
end
