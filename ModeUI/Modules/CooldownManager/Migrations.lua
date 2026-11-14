local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- Initialize(db): migrates, fills defaults and validates every bar's
-- settings. Profile validation runs it on detached copies, so it touches no
-- frames. Bad data stops with an error; settings are never reset.
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
-- A spell's key: a cooldown ID ("1234"), or a custom spell's ID ("s1234").
local function Key(value) return type(value) == "string" and value:match("^s?%d+$") ~= nil and #value <= 12 end

-- A spell's glow while it's on: its look (the off-cooldown glow also when).
local STYLES = {}
for _, item in ipairs(M.glowStyles) do STYLES[item.id] = true end
local function ValidGlow(glow, kind, id)
    assert(type(glow) == "table" and STYLES[glow.style] and type(glow.pulse) == "boolean", "Invalid cooldown manager spell glow: " .. id)
    assert(type(glow.color) == "table", "Invalid cooldown manager spell glow color: " .. id)
    for i = 1, 3 do assert(Number(glow.color[i], 0, 1), "Invalid cooldown manager spell glow color: " .. id) end
    for _, key in ipairs({ "lines", "thickness" }) do assert(Whole(glow[key], M.glowRanges[key]), "Invalid cooldown manager spell glow: " .. id) end
    if kind == "ready" then
        assert((glow.mode == "flash" or glow.mode == "always") and Whole(glow.duration, M.glowRanges.duration), "Invalid cooldown manager spell glow: " .. id)
    end
end

-- Per-spell settings: a key ("1234", "s1234") to { hide = true } and the
-- glows that are on; an empty entry isn't kept.
local function ValidSpells(spells, id)
    local count = 0
    for key, entry in pairs(spells) do
        count = count + 1
        assert(Key(key) and type(entry) == "table" and next(entry) ~= nil, "Invalid cooldown manager spell: " .. id)
        for kind, value in pairs(entry) do
            local want = M.spellKinds[kind]
            assert(want ~= nil, "Invalid cooldown manager spell switch: " .. id)
            if want == "glow" then ValidGlow(value, kind, id) else assert(value == want, "Invalid cooldown manager spell switch: " .. id) end
        end
    end
    assert(count <= MAX_SPELLS, "Too many cooldown manager spells: " .. id)
end

local function Validate(style, id, defaults, bar)
    assert(Public(style) and type(style) == "table", "Invalid cooldown manager settings: " .. id)
    for key, default in pairs(defaults) do
        if style[key] == nil then style[key] = Copy(default) end
        local value = style[key]
        assert(Public(value) and type(value) == type(default), "Invalid cooldown manager setting: " .. id .. "." .. key)
        if M.colorKeys[key] then
            for i = 1, 3 do assert(Number(value[i], 0, 1), "Invalid cooldown manager color: " .. id .. "." .. key) end
        end
    end
    for key, r in pairs(M.ranges) do assert(Whole(style[key], r), "Invalid cooldown manager range: " .. id .. "." .. key) end
    local sizes = M.sizeRanges[bar and "bar" or "icon"]
    for _, key in ipairs({ "width", "height" }) do assert(Whole(style[key], sizes[key]), "Invalid cooldown manager size: " .. id .. "." .. key) end
    for key, allowed in pairs(ALLOWED) do assert(allowed[style[key]], "Invalid cooldown manager choice: " .. id .. "." .. key) end
    local lines = M.LinesFor(style.grow)
    assert(style.lineGrowth == lines[1] or style.lineGrowth == lines[2], "Invalid cooldown manager line growth: " .. id)
    assert(Kit.ValidBarTexture(style.barTexture, true), "Invalid cooldown manager bar texture: " .. id)
    assert(Kit.ValidBarTexture(style.barBackground, false), "Invalid cooldown manager bar background: " .. id)
    ValidSpells(style.spells, id)
end

-- Custom bars: at most MAX_CUSTOM, each with a unique "customN" ID below
-- nextCustom, a name, a kind and its spells (unique cooldown ID keys).
local function ValidCustom(db)
    assert(type(db.customBars) == "table" and #db.customBars <= M.MAX_CUSTOM, "Invalid cooldown manager custom bars")
    assert(Whole(db.nextCustom, { 1, 100000 }), "Invalid cooldown manager custom bar counter")
    local ids = {}
    for index, bar in pairs(db.customBars) do
        assert(type(index) == "number" and index >= 1 and index <= #db.customBars and type(bar) == "table", "Invalid cooldown manager custom bar")
        local number = type(bar.id) == "string" and tonumber(bar.id:match("^custom(%d+)$"))
        assert(number and number < db.nextCustom and not ids[bar.id], "Invalid cooldown manager custom bar ID")
        ids[bar.id] = true
        assert(M.customKinds[bar.kind], "Invalid cooldown manager custom bar kind: " .. bar.id)
        assert(type(bar.name) == "string" and bar.name ~= "" and #bar.name <= M.MAX_NAME and not bar.name:find("[\r\n|]"),
            "Invalid cooldown manager custom bar name: " .. bar.id)
        assert(type(bar.entries) == "table" and #bar.entries <= M.MAX_ENTRIES, "Invalid cooldown manager custom bar spells: " .. bar.id)
        local seen = {}
        for i, key in pairs(bar.entries) do
            assert(type(i) == "number" and i >= 1 and i <= #bar.entries and Key(key) and not seen[key], "Invalid cooldown manager custom bar spell: " .. bar.id)
            -- Spells by ID go on Cooldown Bars only.
            assert(bar.kind == "cooldown" or key:sub(1, 1) ~= "s", "Invalid cooldown manager custom spell: " .. bar.id)
            seen[key] = true
        end
        if db[bar.id] == nil then db[bar.id] = Copy(M.customDefaults[bar.kind]) end
        Validate(db[bar.id], bar.id, M.customDefaults[bar.kind], false)
    end
end

-- Version 1 -> 2: Lines, First Icon and Center Lines become one Growth and
-- the way new lines go; the ready glow switch and its style become the Off
-- Cooldown glow's style (a flash, as before).
local function GrowthFromV1(style)
    local start = type(style.start) == "string" and style.start or "TOPLEFT"
    if style.orientation == "vertical" then
        style.grow = style.center ~= false and "centerV" or (start:find("BOTTOM") and "up" or "down")
        style.lineGrowth = start:find("RIGHT") and "left" or "right"
    else
        style.grow = style.center ~= false and "centerH" or (start:find("RIGHT") and "left" or "right")
        style.lineGrowth = start:find("BOTTOM") and "up" or "down"
    end
    style.orientation, style.start, style.center = nil, nil, nil
    if type(style.readyGlow) == "boolean" then
        style.readyGlow = style.readyGlow and (style.readyStyle == "border" and "border" or "mode") or "none"
        style.readyMode = "flash"
    end
    style.readyStyle = nil
end

-- Version 2 -> 3: the ModeUI border on every bar. A Rounded border (the
-- old default) becomes it, and the old default color (#101010) its color;
-- Square and None stay as chosen.
local function SameColor(a, b) return type(a) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end
local function BorderToV3(style)
    if style.border == "rounded" or style.border == nil then style.border = "mode" end
    if style.borderColor == nil or SameColor(style.borderColor, M.OLD_BORDER_COLOR) then style.borderColor = Copy(M.BORDER_COLOR) end
end

function M.Initialize(db)
    if db.version == nil then db.version = M.VERSION end
    if db.version == 1 then
        for _, viewer in ipairs(M.viewers) do if type(db[viewer]) == "table" then GrowthFromV1(db[viewer]) end end
        db.version = 2
    end
    if db.version == 2 then
        for _, viewer in ipairs(M.viewers) do if type(db[viewer]) == "table" then BorderToV3(db[viewer]) end end
        for _, bar in ipairs(type(db.customBars) == "table" and db.customBars or {}) do
            if type(bar) == "table" and type(bar.id) == "string" and type(db[bar.id]) == "table" then BorderToV3(db[bar.id]) end
        end
        db.version = 3
    end
    -- Version 3 -> 4: sizes still at version 3's defaults take version 4's;
    -- the places, kept outside this table, move on start (Driver.lua).
    if db.version == 3 then
        local function Resize(style, old, new)
            if type(style) == "table" and style.width == old[1] and style.height == old[2] then style.width, style.height = new.width, new.height end
        end
        for _, viewer in ipairs({ "essential", "utility", "buffIcon" }) do Resize(db[viewer], M.oldSizes[viewer], M.styleDefaults[viewer]) end
        for _, bar in ipairs(type(db.customBars) == "table" and db.customBars or {}) do
            if type(bar) == "table" and M.customKinds[bar.kind] and type(bar.id) == "string" then
                Resize(db[bar.id], M.oldSizes[bar.kind], M.customDefaults[bar.kind])
            end
        end
        -- Glows start off on every spell now: the old per-spell "off" marks
        -- go; a bar's None (no longer a look) becomes Mode Glow.
        local function Glows(style)
            if type(style) ~= "table" then return end
            for _, kind in ipairs(M.glowKinds) do if style[kind .. "Glow"] == "none" then style[kind .. "Glow"] = "mode" end end
            for key, entry in pairs(type(style.spells) == "table" and style.spells or {}) do
                if type(entry) == "table" then
                    for _, kind in ipairs(M.glowKinds) do if entry[kind] == false then entry[kind] = nil end end
                    if next(entry) == nil then style.spells[key] = nil end
                end
            end
        end
        for _, viewer in ipairs(M.viewers) do Glows(db[viewer]) end
        for _, bar in ipairs(type(db.customBars) == "table" and db.customBars or {}) do
            if type(bar) == "table" and type(bar.id) == "string" then Glows(db[bar.id]) end
        end
        db.movePlaces = true
        db.version = 4
    end
    assert(db.version == M.VERSION, "Invalid cooldown manager settings version")
    if db.customBars == nil then db.customBars = {} end
    if db.nextCustom == nil then db.nextCustom = 1 end
    for _, viewer in ipairs(M.viewers) do
        if db[viewer] == nil then db[viewer] = Copy(M.styleDefaults[viewer]) end
        Validate(db[viewer], viewer, M.styleDefaults[viewer], M.viewerSpecs[viewer].bar)
    end
    ValidCustom(db)
    -- Resource Bars (ResourceInit.lua): added without a version step; a
    -- profile saved before them takes their defaults.
    M.ValidateResources(db)
end
