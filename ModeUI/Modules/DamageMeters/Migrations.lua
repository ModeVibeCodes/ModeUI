local _, addon = ...
local M = addon.DamageMeters
if not M then return end

-- Initialize(db): fills defaults and validates every window's settings.
-- Profile validation runs it on detached copies, so it touches no frames.
-- Bad data stops with an error; settings are never reset. Later changes add
-- a migration here, keyed by db.version.
local Public, Number, Kit = addon.IsPublic, addon.IsNumber, addon.Kit
local function Copy(value) return addon.ProfileCodec.Copy(value) end

local ALLOWED = {}
for key, list in pairs(M.choices) do
    local set = {}
    for _, item in ipairs(list) do set[item.id] = true end
    ALLOWED[key] = set
end

local function Validate(style, window)
    assert(Public(style) and type(style) == "table", "Invalid damage meter settings: " .. window)
    for key, default in pairs(M.styleDefaults[window]) do
        if style[key] == nil then style[key] = Copy(default) end
        local value = style[key]
        assert(Public(value) and type(value) == type(default), "Invalid damage meter setting: " .. window .. "." .. key)
        if M.colorKeys[key] then
            for i = 1, 3 do assert(Number(value[i], 0, 1), "Invalid damage meter color: " .. window .. "." .. key) end
        end
    end
    for key, r in pairs(M.ranges) do
        local value = style[key]
        assert(Number(value, r[1], r[2]) and value == math.floor(value), "Invalid damage meter range: " .. window .. "." .. key)
    end
    for key, allowed in pairs(ALLOWED) do assert(allowed[style[key]], "Invalid damage meter choice: " .. window .. "." .. key) end
    for key, foreground in pairs(M.textureKeys) do
        assert(Kit.ValidBarTexture(style[key], foreground), "Invalid damage meter texture: " .. window .. "." .. key)
    end
end

-- Version 1 -> 2: text still at version 1's gray (#D4D4D4) turns white and
-- outlined, and the header text drops the fight name, now on its own button.
-- New settings (Decimals, Lock Window, groups, header buttons) take their
-- defaults.
local function SameColor(a, b) return type(a) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end
local function MigrateV1(db)
    for _, window in ipairs(M.windows) do
        local style = db[window]
        if type(style) == "table" then
            if SameColor(style.textColor, Kit.palette.text) then
                style.textColor = Copy(M.TEXT_COLOR)
                if style.outline == false then style.outline = true end
            end
            if style.showSession == true then style.showSession = false end
        end
    end
end

-- Version 2 -> 3: the shared text settings become each text's own: the font,
-- shadow and slug go to all four texts, Text Color to names and values, Name
-- Color's "Text Color" becomes "Color". The owner asked for outlined text and
-- pure white names, so those are set on every window. Decimals still at
-- version 2's default (1) become whole numbers; a header still at version
-- 2's #141518 takes the Onyx health color. Old keys are removed.
local OLD_HEADER = { 20 / 255, 21 / 255, 24 / 255 }
local SHARED_TEXT = { "font", "fontMedia", "outline", "shadow", "liftedShadow", "slug", "textColor", "nameColorMode" }
local function MigrateV2(db)
    for _, window in ipairs(M.windows) do
        local style = db[window]
        if type(style) == "table" then
            for _, part in ipairs(M.textParts) do
                local function From(key, fallback) if style[key] ~= nil then return Copy(style[key]) end return fallback end
                style[part .. "Font"] = From("font", nil)
                style[part .. "FontMedia"] = From("fontMedia", nil)
                style[part .. "Shadow"] = From("shadow", nil)
                style[part .. "Lifted"] = From("liftedShadow", nil)
                style[part .. "Slug"] = From("slug", nil)
                style[part .. "Outline"] = true
            end
            if type(style.textColor) == "table" then style.valueColor = Copy(style.textColor) end
            style.nameColor = Copy(M.TEXT_COLOR)
            style.nameColorMode = style.nameColorMode == "class" and "class" or "custom"
            if style.decimals == 1 then style.decimals = 0 end
            if SameColor(style.headerColor, OLD_HEADER) then style.headerColor = Copy(M.HEADER_COLOR) end
            for _, key in ipairs(SHARED_TEXT) do if key ~= "nameColorMode" then style[key] = nil end end
        end
    end
end

-- Version 3 -> 4: groups stack Above by default. The owner grouped Window 2
-- with Window 1 and it went below, off the screen; every window still on
-- version 3's default (Below) turns Above. Hide Blizzard's Meter takes its
-- default (on).
local function MigrateV3(db)
    for _, window in ipairs(M.windows) do
        local style = db[window]
        if type(style) == "table" and style.groupSide == "below" then style.groupSide = "above" end
    end
end

-- A window can't group with itself, and groups never loop.
local function ValidateGroups(db)
    for _, window in ipairs(M.windows) do
        local seen, current = { [window] = true }, db[window].group
        while current ~= "none" do
            assert(not seen[current], "Invalid damage meter group: " .. window)
            seen[current] = true
            current = db[current].group
        end
    end
end

function M.Initialize(db)
    if db.version == 1 then MigrateV1(db); db.version = 2 end
    if db.version == 2 then MigrateV2(db); db.version = 3 end
    if db.version == 3 then MigrateV3(db); db.version = 4 end
    if db.version == nil then db.version = M.VERSION end
    assert(db.version == M.VERSION, "Invalid damage meter settings version")
    if db.hideBlizzard == nil then db.hideBlizzard = true end
    assert(Public(db.hideBlizzard) and type(db.hideBlizzard) == "boolean", "Invalid damage meter setting: hideBlizzard")
    for _, window in ipairs(M.windows) do
        if db[window] == nil then db[window] = Copy(M.styleDefaults[window]) end
        Validate(db[window], window)
    end
    ValidateGroups(db)
end
