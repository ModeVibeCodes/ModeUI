local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Nameplates: ModeUI's own plates in the Onyx look, drawn on the
-- game's nameplates. The game keeps placing, stacking and clicking its
-- nameplates; ModeUI fades Blizzard's art and draws health, name, cast bar,
-- raid marker and target highlight. Enemy and friendly plates each have their
-- own settings. Unit values can be secret and only reach widgets documented as
-- accepting them. See docs/NAMEPLATES.md.
-- Files: Init (this), Driver, Plate, Update, CastBar, Preview, Settings.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Nameplates"], category = "interface", defaultEnabled = false,
    configDescription = L["Onyx nameplates with health, names, cast bars and raid markers."],
    modeLayout = { decorateOnly = true } }
addon.Nameplates = M
addon:RegisterModule("nameplates", M)

-- Version 2: separate enemy and friendly settings (version 1 had one set).
M.VERSION = 2
M.kinds = { "enemy", "friendly" }
M.kindLabels = { enemy = "Enemy", friendly = "Friendly" }
local P, RGB = Kit.palette, Kit.RGB
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Enemies attacking you (red) and close to it (orange).
M.threatPalette = { aggro = RGB(255, 72, 72), warning = RGB(255, 160, 64) }

-- One kind's settings. `show` off leaves that kind's plates to Blizzard.
local function Style(kind)
    local enemy = kind == "enemy"
    return {
        show = true,
        width = enemy and 140 or 120, healthHeight = enemy and 12 or 8, castHeight = 8,
        healthColorMode = "reaction", softness = 30, healthColor = Copy(P.green), threatColors = enemy,
        healthText = enemy and "percent" or "none", healthFontSize = 9,
        showName = true, nameFontSize = 10,
        showCastBar = true, castFontSize = 8, castColor = Copy(P.neutral), castLockedColor = Copy(P.tapped),
        showRaidIcon = true, targetHighlight = true,
        texture = "satin", font = "game", fontMedia = "Expressway", outline = false, shadow = true, liftedShadow = true,
        textColor = Copy(P.text),
    }
end
M.styleDefaults = { enemy = Style("enemy"), friendly = Style("friendly") }
M.defaults = { version = M.VERSION, enemy = Copy(M.styleDefaults.enemy), friendly = Copy(M.styleDefaults.friendly) }
-- Keys Copy Style leaves alone.
M.identityKeys = { show = true }

M.ranges = { width = { 80, 250, 1 }, healthHeight = { 4, 30, 1 }, castHeight = { 4, 20, 1 }, softness = { 0, 100, 5 },
    healthFontSize = { 6, 20, 1 }, nameFontSize = { 6, 20, 1 }, castFontSize = { 6, 20, 1 } }
M.choices = {
    healthColorMode = { { id = "reaction", label = "Reaction and Class" }, { id = "reactionOnly", label = "Reaction" },
        { id = "onyx", label = "Onyx" }, { id = "custom", label = "Custom" } },
    healthText = { { id = "percent", label = "Percent" }, { id = "current", label = "Current Health" },
        { id = "both", label = "Current and Percent" }, { id = "none", label = "None" } },
}
M.textures = { { id = "satin", label = "Satin" }, { id = "mode", label = "Mode" }, { id = "flat", label = "Flat" },
    { id = "default", label = "Use Global Setting" } }

local Public, Number = addon.IsPublic, addon.IsNumber
local ALLOWED = {}
for key, list in pairs(M.choices) do
    ALLOWED[key] = {}
    for _, item in ipairs(list) do ALLOWED[key][item.id] = true end
end

-- Version 1 kept one flat set of settings; both kinds start from it.
local function MigrateV1(db)
    for _, kind in ipairs(M.kinds) do
        local style = {}
        for key in pairs(M.styleDefaults.enemy) do
            if db[key] ~= nil then style[key] = Copy(db[key]) end
        end
        db[kind] = style
    end
    for key in pairs(M.styleDefaults.enemy) do db[key] = nil end
end

local function Validate(style, kind)
    assert(Public(style) and type(style) == "table", "Invalid nameplate settings: " .. kind)
    for key, default in pairs(M.styleDefaults[kind]) do
        if style[key] == nil then style[key] = Copy(default) end
        local value = style[key]
        assert(Public(value) and type(value) == type(default), "Invalid nameplate setting: " .. kind .. "." .. key)
        if type(default) == "table" then
            for i = 1, 3 do assert(Number(value[i], 0, 1), "Invalid nameplate color: " .. kind .. "." .. key) end
        end
    end
    for key, r in pairs(M.ranges) do
        local value = style[key]
        assert(Number(value, r[1], r[2]) and value == math.floor(value), "Invalid nameplate range: " .. kind .. "." .. key)
    end
    for key, allowed in pairs(ALLOWED) do assert(allowed[style[key]], "Invalid nameplate choice: " .. kind .. "." .. key) end
    local texture = style.texture
    assert(texture == "satin" or texture == "mode" or texture == "flat" or texture == "default" or texture:sub(1, 6) == "media:",
        "Invalid nameplate texture: " .. kind)
end

-- Fills defaults, migrates and validates; profile validation runs this on
-- detached copies.
function M.Initialize(db)
    if db.version == 1 then MigrateV1(db); db.version = 2 end
    if db.version == nil then db.version = M.VERSION end
    assert(db.version == M.VERSION, "Invalid nameplate settings version")
    for _, kind in ipairs(M.kinds) do
        if db[kind] == nil then db[kind] = Copy(M.styleDefaults[kind]) end
        Validate(db[kind], kind)
    end
end
