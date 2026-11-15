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
    assert(ValidConditions(style.pageConditions), "Invalid action bar page conditions: " .. bar)
    -- Per-button glow switches: a place ("1"-"12") to { proc, ready } set false.
    for place, glows in pairs(style.buttonGlows) do
        local index = type(place) == "string" and place:match("^%d+$") and tonumber(place)
        assert(index and index >= 1 and index <= M.barSpecs[bar].count and type(glows) == "table", "Invalid action bar button glow: " .. bar)
        for kind, on in pairs(glows) do
            assert((kind == "proc" or kind == "ready" or kind == "gray") and on == false, "Invalid action bar button glow: " .. bar)
        end
    end
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

-- Version 2 -> 3: a border color, macro color or spacing still at version
-- 2's default takes the new one; Border Size and Background Color take theirs.
local OLD_BORDER, OLD_MACRO = addon.Kit.onyx.border, addon.Kit.palette.muted
local function MigrateV2(db)
    for _, bar in ipairs(M.bars) do
        local style = db[bar]
        if type(style) == "table" then
            if SameColor(style.borderColor, OLD_BORDER) then style.borderColor = Copy(M.BORDER_COLOR) end
            if SameColor(style.macroColor, OLD_MACRO) then style.macroColor = Copy(M.MACRO_COLOR) end
            if style.spacing == 2 then style.spacing = 1 end
        end
    end
end

-- Version 3 -> 4: the owner asked for #101010 borders and 75% Background
-- Opacity on every bar, so these replace whatever was set.
local function MigrateV3(db)
    for _, bar in ipairs(M.bars) do
        local style = db[bar]
        if type(style) == "table" then
            style.borderColor, style.backgroundOpacity = Copy(M.BORDER_COLOR), M.BACKGROUND_OPACITY
        end
    end
end

-- Version 4 -> 5: keybinds 2px smaller on every bar, as the owner asked.
local function MigrateV4(db)
    for _, bar in ipairs(M.bars) do
        local style = db[bar]
        if type(style) == "table" and addon.IsNumber(style.hotkeySize) then style.hotkeySize = math.max(6, style.hotkeySize - 2) end
    end
end

-- Version 5 -> 6: the Mode design language. Values still at their version 5
-- default take the new one; anything the player picked stays. Rounded and
-- Square borders become the Mode edge; Border Size and Border Color retire.
local V5 = { fontMedia = { "Expressway", "Mode Geist" }, outline = { true, false }, spacing = { 1, 4 },
    backgroundOpacity = { 75, 100 }, procGlow = { "mode", "border" }, hotkeySize = { 9, 10 }, cooldownSize = { 14, 13 } }
local Same = addon.Style.SameColor
local function MigrateV5(db)
    local Tone, P = addon.Style.Tone, addon.Kit.palette
    for _, bar in ipairs(M.bars) do
        local style = db[bar]
        if type(style) == "table" and Public(style) then
            for key, change in pairs(V5) do if style[key] == change[1] then style[key] = change[2] end end
            if not M.barSpecs[bar].utility then
                if style.width == 42 then style.width = 40 end
                if style.height == 36 then style.height = 34 end
                if style.countSize == 12 then style.countSize = 11 end
            end
            if style.border == "rounded" or style.border == "square" then style.border = "mode" end
            for _, key in ipairs(M.retiredKeys) do style[key] = nil end
            if Same(style.backgroundColor, M.BACKGROUND_COLOR) then style.backgroundColor = Copy(Tone.mono.panel) end
            if Same(style.procColor, M.PROC_COLOR) then style.procColor = Copy(Tone.celadon) end
            if Same(style.readyColor, M.READY_COLOR) then style.readyColor = Copy(Tone.ivory) end
            if Same(style.hotkeyColor, P.text) then style.hotkeyColor = Copy(Tone.graphite.secondary) end
            if Same(style.countColor, P.text) then style.countColor = Copy(Tone.textBright) end
        end
    end
end

function M.Initialize(db)
    if db.version == 1 then MigrateV1(db); db.version = 2 end
    if db.version == 2 then MigrateV2(db); db.version = 3 end
    if db.version == 3 then MigrateV3(db); db.version = 4 end
    if db.version == 4 then MigrateV4(db); db.version = 5 end
    if db.version == 5 then MigrateV5(db); db.version = 6 end
    if db.version == nil then db.version = M.VERSION end
    assert(db.version == M.VERSION, "Invalid action bar settings version")
    for _, bar in ipairs(M.bars) do
        if db[bar] == nil then db[bar] = Copy(M.styleDefaults[bar]) end
        Validate(db[bar], bar)
    end
end
