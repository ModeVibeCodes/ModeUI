local _, ns = ...
local addon = ns.ModeUI or {}
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
-- A spell's key: a cooldown ID ("1234"), a custom spell's ID ("s1234") or
-- an item's ("i1234").
local function Key(value) return type(value) == "string" and value:match("^[si]?%d+$") ~= nil and #value <= 12 end

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

-- A spell's own text looks: { [part] = { show, size, anchor, x, y, color,
-- font, fontMedia, outline, shadow } } for texts the bars have.
local OUTLINES, ANCHORS, PARTS = {}, {}, {}
for _, item in ipairs(M.outlineChoices) do OUTLINES[item.id] = true end
for _, anchor in ipairs(M.anchors) do ANCHORS[anchor] = true end
for _, part in ipairs(M.textParts) do PARTS[part] = true end
local function ValidText(text, id)
    assert(type(text) == "table" and next(text) ~= nil, "Invalid cooldown manager spell text: " .. id)
    for part, look in pairs(text) do
        assert(PARTS[part] and type(look) == "table", "Invalid cooldown manager spell text: " .. id)
        local bad = "Invalid cooldown manager spell text: " .. id .. "." .. part
        for field in pairs(look) do assert(M.textFields[field], bad) end
        assert(type(look.show) == "boolean" and type(look.shadow) == "boolean" and OUTLINES[look.outline], bad)
        assert(Whole(look.size, M.ranges[part .. "Size"]) and ANCHORS[look.anchor], bad)
        assert(Whole(look.x, M.ranges[part .. "X"]) and Whole(look.y, M.ranges[part .. "Y"]), bad)
        assert(type(look.font) == "string" and type(look.fontMedia) == "string" and #look.font <= 200 and #look.fontMedia <= 200, bad)
        assert(type(look.color) == "table", bad)
        for i = 1, 3 do assert(Number(look.color[i], 0, 1), bad) end
    end
end

-- Per-spell settings: a key ("1234", "s1234") to { hide = true }, the
-- glows that are on and its own texts; an empty entry isn't kept.
local function ValidSpells(spells, id)
    local count = 0
    for key, entry in pairs(spells) do
        count = count + 1
        assert(Key(key) and type(entry) == "table" and next(entry) ~= nil, "Invalid cooldown manager spell: " .. id)
        for kind, value in pairs(entry) do
            local want = M.spellKinds[kind]
            assert(want ~= nil, "Invalid cooldown manager spell switch: " .. id)
            if want == "glow" then ValidGlow(value, kind, id)
            elseif want == "text" then ValidText(value, id)
            else assert(value == want, "Invalid cooldown manager spell switch: " .. id) end
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

-- A bar's own list of spells: unique keys, at most MAX_ENTRIES; spells and
-- items by ID only where `own` allows them.
local function ValidList(entries, id, own)
    assert(type(entries) == "table" and #entries <= M.MAX_ENTRIES, "Invalid cooldown manager bar spells: " .. id)
    local seen = {}
    for i, key in pairs(entries) do
        assert(type(i) == "number" and i >= 1 and i <= #entries and Key(key) and not seen[key], "Invalid cooldown manager bar spell: " .. id)
        assert(own or key:match("^%d+$"), "Invalid cooldown manager custom spell: " .. id)
        seen[key] = true
    end
end

-- The spells Essential and Utility took (added without a version step: a
-- profile saved before them starts with none).
local function ValidExtras(db)
    if db.extras == nil then db.extras = {} end
    assert(type(db.extras) == "table", "Invalid cooldown manager viewer spells")
    for viewer in pairs(db.extras) do assert(M.entryViewers[viewer], "Invalid cooldown manager viewer spells") end
    for viewer in pairs(M.entryViewers) do
        if db.extras[viewer] == nil then db.extras[viewer] = {} end
        ValidList(db.extras[viewer], viewer, true)
    end
end

-- A viewer's spell order: unique keys (added without a version step: a
-- profile saved before it keeps Blizzard's order).
local function ValidOrder(db)
    if db.order == nil then db.order = {} end
    assert(type(db.order) == "table", "Invalid cooldown manager spell order")
    for viewer, keys in pairs(db.order) do
        assert(M.viewerSpecs[viewer] and type(keys) == "table" and #keys <= M.MAX_ORDER, "Invalid cooldown manager spell order")
        local seen = {}
        for i, key in pairs(keys) do
            assert(type(i) == "number" and i >= 1 and i <= #keys and Key(key) and not seen[key], "Invalid cooldown manager spell order: " .. viewer)
            seen[key] = true
        end
    end
end

-- The bar racials show on: "none", Essential, Utility or a custom Cooldown
-- Bar (added without a version step: a profile saved before shows them on
-- Utility).
local function ValidRacials(db)
    if db.racials == nil then db.racials = "utility" end
    local ok = db.racials == "none" or M.entryViewers[db.racials] ~= nil
    for _, bar in ipairs(db.customBars) do if bar.id == db.racials and bar.kind == "cooldown" then ok = true end end
    assert(ok, "Invalid cooldown manager racials bar")
end

-- Custom bars: at most MAX_CUSTOM, each with a unique "customN" ID below
-- nextCustom, a name, a kind and its spells (unique cooldown ID keys); a
-- default bar's preset tag (Presets.lua), once per profile, gives its defaults.
local function ValidCustom(db)
    assert(type(db.customBars) == "table" and #db.customBars <= M.MAX_CUSTOM, "Invalid cooldown manager custom bars")
    assert(Whole(db.nextCustom, { 1, 100000 }), "Invalid cooldown manager custom bar counter")
    local ids, presets = {}, {}
    for index, bar in pairs(db.customBars) do
        assert(type(index) == "number" and index >= 1 and index <= #db.customBars and type(bar) == "table", "Invalid cooldown manager custom bar")
        local number = type(bar.id) == "string" and tonumber(bar.id:match("^custom(%d+)$"))
        assert(number and number < db.nextCustom and not ids[bar.id], "Invalid cooldown manager custom bar ID")
        ids[bar.id] = true
        assert(M.customKinds[bar.kind], "Invalid cooldown manager custom bar kind: " .. bar.id)
        assert(type(bar.name) == "string" and bar.name ~= "" and #bar.name <= M.MAX_NAME and not bar.name:find("[\r\n|]"),
            "Invalid cooldown manager custom bar name: " .. bar.id)
        -- On custom bars, spells and items by ID go on Cooldown Bars only.
        ValidList(bar.entries, bar.id, bar.kind == "cooldown")
        M.ValidPreset(bar, presets)
        local defaults = M.BarDefaults(bar)
        if db[bar.id] == nil then db[bar.id] = Copy(defaults) end
        Validate(db[bar.id], bar.id, defaults, false)
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
    if style.borderColor == nil or SameColor(style.borderColor, M.OLD.rimColor) then style.borderColor = Copy(M.OLD.borderColor) end
end

-- Version 4 -> 5: the Mode design language. Values still at a version 4
-- default take the new one; anything the player picked stays. Rounded and
-- Square borders become the Mode edge; Border Size and Border Color retire.
local Same, Tone = addon.Style.SameColor, addon.Style.Tone
local function Swap(t, key, old, new) if Same(t[key], old) then t[key] = Copy(new) end end
local function StyleToV5(style, sizeKey, defaults)
    if type(style) ~= "table" or not Public(style) then return end
    local O = M.OLD
    if style.border == "rounded" or style.border == "square" then style.border = "mode" end
    for _, key in ipairs(M.retiredKeys) do style[key] = nil end
    local old = M.v4Sizes[sizeKey]
    if old and style.width == old[1] and style.height == old[2] then style.width, style.height = defaults.width, defaults.height end
    Swap(style, "backgroundColor", O.background, defaults.backgroundColor)
    if style.backgroundOpacity == O.backgroundOpacity then style.backgroundOpacity = defaults.backgroundOpacity end
    if style.fontMedia == "Expressway" then style.fontMedia = defaults.fontMedia end
    if style.outline == true then style.outline = false end
    if style.procGlow == "blizzard" then style.procGlow = defaults.procGlow end
    if style.readyGlow == "pixel" then style.readyGlow = defaults.readyGlow end
    for kind, color in pairs(O.glows) do Swap(style, kind .. "Color", color, defaults[kind .. "Color"]) end
    -- A spell's glow switched on kept the old default color as its own.
    for _, entry in pairs(type(style.spells) == "table" and style.spells or {}) do
        for kind, color in pairs(O.glows) do
            if type(entry) == "table" and type(entry[kind]) == "table" then Swap(entry[kind], "color", color, defaults[kind .. "Color"]) end
        end
    end
    local small = defaults.cooldownSize == 10
    if style.cooldownSize == (small and 12 or 15) then style.cooldownSize = defaults.cooldownSize end
    if style.countSize == (small and 10 or 12) then style.countSize = defaults.countSize end
    for _, part in ipairs({ "name", "duration" }) do if style[part .. "Size"] == 11 then style[part .. "Size"] = defaults[part .. "Size"] end end
    Swap(style, "cooldownColor", O.cooldown, Tone.cooldown)
    for _, part in ipairs({ "count", "name", "duration" }) do Swap(style, part .. "Color", O.text, Tone.textBright) end
    if style.barTexture == "mode" then style.barTexture = defaults.barTexture end
    if style.barBackground == "slate" then style.barBackground = defaults.barBackground end
    if style.barBackgroundOpacity == 70 then style.barBackgroundOpacity = defaults.barBackgroundOpacity end
    if style.showSpark == false then style.showSpark = true end
    -- The cyan bar color becomes your class color; a color you chose stays, as Custom.
    if style.barColorMode == nil then
        if style.barColor == nil or Same(style.barColor, O.bar) then style.barColorMode, style.barColor = "class", Copy(M.BAR_COLOR)
        else style.barColorMode = "custom" end
    end
end
local function ResourceToV5(style)
    if type(style) ~= "table" or not Public(style) then return end
    style.borderColor = nil
    if style.barTexture == "mode" then style.barTexture = "media:Mode Gradient" end
    if style.barBackground == "slate" then style.barBackground = "media:Mode BG" end
    if style.barBackgroundOpacity == 70 then style.barBackgroundOpacity = M.RESOURCE_EMPTY end
    if style.fontMedia == "Expressway" then style.fontMedia = addon.Style.FONT_DEFAULT end
    if style.outline == true then style.outline = false end
    Swap(style, "textColor", M.OLD.text, Tone.textBright)
    Swap(style, "barColor", addon.Style.LEGACY.comboRed, Tone.reaction.hostile)
    Swap(style, "barColor", addon.Kit.palette.mana, Tone.power)
    Swap(style, "barColor", addon.Kit.palette.green, Tone.reaction.friendly)
end
local function MigrateV4(db)
    for _, viewer in ipairs(M.viewers) do StyleToV5(db[viewer], viewer, M.styleDefaults[viewer]) end
    for _, bar in ipairs(type(db.customBars) == "table" and db.customBars or {}) do
        if type(bar) == "table" and M.customKinds[bar.kind] and type(bar.id) == "string" then
            StyleToV5(db[bar.id], bar.kind, M.customDefaults[bar.kind])
        end
    end
    for _, style in pairs(type(db.resources) == "table" and db.resources or {}) do ResourceToV5(style) end
end

-- Version 5 -> 6 (owner, November 17, 2026): resource bars in Mode-Round
-- and Gunmetal, thinner, with the combo point count on their left. A value
-- still at version 5's default takes the new one; new keys (Dark mode, Rim
-- Color, Tick Marks, the combo layout) fill from their defaults; Separate
-- Resources stays, so no bar moves.
local function MigrateV5(db)
    local old = M.V5_RESOURCE
    for _, id in ipairs(M.resources) do
        local style, defaults = type(db.resources) == "table" and db.resources[id], M.resourceDefaults[id]
        if type(style) == "table" and Public(style) then
            if style.edgeStyle == "blizz" then style.edgeStyle = defaults.edgeStyle end
            if style.edgeMetal == "default" then style.edgeMetal = defaults.edgeMetal end
            if old.height[id] and style.height == old.height[id] then style.height = defaults.height end
            if id == "combo" and style.text == old.comboText then style.text = defaults.text end
        end
    end
end

-- Version 6 -> 7 (owner's first in-game look, November 18, 2026): heights
-- still at version 6's defaults take 16/10/8; the text is always centered,
-- with Show Text in place of the None format; Tick Marks become a list (the
-- ticks in use, else the first slot) behind Show Tick Marks, on when a tick
-- was in use.
local function MigrateV6(db)
    local old = M.V6_RESOURCE
    for _, id in ipairs(M.resources) do
        local style, defaults = type(db.resources) == "table" and db.resources[id], M.resourceDefaults[id]
        if type(style) == "table" and Public(style) then
            if old.height[id] and style.height == old.height[id] then style.height = defaults.height end
            if style.textShow == nil and style.text ~= nil then
                style.textShow = style.text ~= "none"
                if style.text == "none" then style.text = defaults.text end
            end
            style.textAnchor = nil
            local marks = style.marks
            if defaults.marks and type(marks) == "table" and Public(marks) then
                local used = {}
                for _, mark in ipairs(marks) do
                    if type(mark) == "table" and Public(mark) and Number(mark.value, 1) then used[#used + 1] = mark end
                end
                if style.marksShow == nil then style.marksShow = #used > 0 end
                if #used == 0 and type(marks[1]) == "table" then used[1] = marks[1] end
                if #used > 0 then style.marks = used end
            end
        end
    end
end

function M.Initialize(db)
    -- A new profile: version 8's settings, then the version 9 step's bars.
    if db.version == nil then db.version = 8 end
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
    if db.version == 4 then MigrateV4(db); db.version = 5 end
    if db.version == 5 then MigrateV5(db); db.version = 6 end
    if db.version == 6 then MigrateV6(db); db.version = 7 end
    -- Version 7 -> 8: the Cast Bar sits above Essential, where Buff Icons
    -- sat; a Buff Icons place still at that default moves above the cast bar
    -- on start (kept outside this table: CastBar.lua, MoveBuffIconsForCast).
    if db.version == 7 then db.moveBuffIcons = true; db.version = 8 end
    -- Version 8 -> 9: the five default bars the profile doesn't hold, after
    -- its own (Presets.lua); its bars stay as they are.
    if db.version == 8 then M.SeedPresets(db); db.version = 9 end
    assert(db.version == M.VERSION, "Invalid cooldown manager settings version")
    if db.customBars == nil then db.customBars = {} end
    if db.nextCustom == nil then db.nextCustom = 1 end
    for _, viewer in ipairs(M.viewers) do
        if db[viewer] == nil then db[viewer] = Copy(M.styleDefaults[viewer]) end
        Validate(db[viewer], viewer, M.styleDefaults[viewer], M.viewerSpecs[viewer].bar)
    end
    ValidCustom(db)
    ValidExtras(db)
    ValidOrder(db)
    ValidRacials(db)
    -- Resource Bars (ResourceInit.lua): added without a version step; a
    -- profile saved before them takes their defaults.
    M.ValidateResources(db)
    -- The Cast Bar (CastInit.lua): the same.
    M.ValidateCast(db)
end
