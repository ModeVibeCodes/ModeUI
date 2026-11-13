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

function M.Initialize(db)
    if db.version == nil then db.version = M.VERSION end
    assert(db.version == M.VERSION, "Invalid damage meter settings version")
    for _, window in ipairs(M.windows) do
        if db[window] == nil then db[window] = Copy(M.styleDefaults[window]) end
        Validate(db[window], window)
    end
end
