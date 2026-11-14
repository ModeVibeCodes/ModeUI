local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- Initialize(db): fills defaults and validates every viewer's settings.
-- Profile validation runs it on detached copies, so it touches no frames.
-- Bad data stops with an error; settings are never reset. Version 1 is the
-- first; later versions migrate here, one step at a time.
local Public, Number = addon.IsPublic, addon.IsNumber
local Kit = addon.Kit
local function Copy(value) return addon.ProfileCodec.Copy(value) end

local ALLOWED = {}
for key, list in pairs(M.choices) do
    local set = {}
    for _, item in ipairs(list) do set[type(item) == "table" and item.id or item] = true end
    ALLOWED[key] = set
end
local MAX_SPELLS = 200

local function Whole(value, range) return Number(value, range[1], range[2]) and value == math.floor(value) end

-- Per-spell switches: a cooldown ID ("1234") to { hide = true, proc = false,
-- ready = false }, each kept only while it differs from the viewer.
local function ValidSpells(spells, viewer)
    local count = 0
    for id, entry in pairs(spells) do
        count = count + 1
        assert(type(id) == "string" and id:match("^%d+$") and #id <= 12 and type(entry) == "table" and next(entry) ~= nil,
            "Invalid cooldown manager spell: " .. viewer)
        for kind, value in pairs(entry) do
            assert(M.spellKinds[kind] ~= nil and value == M.spellKinds[kind], "Invalid cooldown manager spell switch: " .. viewer)
        end
    end
    assert(count <= MAX_SPELLS, "Too many cooldown manager spells: " .. viewer)
end

local function Validate(style, viewer)
    assert(Public(style) and type(style) == "table", "Invalid cooldown manager settings: " .. viewer)
    for key, default in pairs(M.styleDefaults[viewer]) do
        if style[key] == nil then style[key] = Copy(default) end
        local value = style[key]
        assert(Public(value) and type(value) == type(default), "Invalid cooldown manager setting: " .. viewer .. "." .. key)
        if M.colorKeys[key] then
            for i = 1, 3 do assert(Number(value[i], 0, 1), "Invalid cooldown manager color: " .. viewer .. "." .. key) end
        end
    end
    for key, r in pairs(M.ranges) do
        assert(Whole(style[key], r), "Invalid cooldown manager range: " .. viewer .. "." .. key)
    end
    for _, key in ipairs({ "width", "height" }) do
        assert(Whole(style[key], M:SizeRange(viewer, key)), "Invalid cooldown manager size: " .. viewer .. "." .. key)
    end
    for key, allowed in pairs(ALLOWED) do assert(allowed[style[key]], "Invalid cooldown manager choice: " .. viewer .. "." .. key) end
    assert(Kit.ValidBarTexture(style.barTexture, true), "Invalid cooldown manager bar texture: " .. viewer)
    assert(Kit.ValidBarTexture(style.barBackground, false), "Invalid cooldown manager bar background: " .. viewer)
    ValidSpells(style.spells, viewer)
end

function M.Initialize(db)
    if db.version == nil then db.version = M.VERSION end
    assert(db.version == M.VERSION, "Invalid cooldown manager settings version")
    for _, viewer in ipairs(M.viewers) do
        if db[viewer] == nil then db[viewer] = Copy(M.styleDefaults[viewer]) end
        Validate(db[viewer], viewer)
    end
end
