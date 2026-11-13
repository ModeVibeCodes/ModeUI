local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Nameplates: ModeUI's own plates in the Onyx look, drawn on the
-- game's nameplates. The game keeps placing, stacking and clicking its
-- nameplates; ModeUI fades Blizzard's art and draws health, name, cast bar,
-- raid marker and target highlight. Unit values can be secret and only reach
-- widgets documented as accepting them. See docs/NAMEPLATES.md.
-- Files: Init (this), Driver, Plate, Update, CastBar, Settings.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Nameplates"], category = "interface", defaultEnabled = false,
    configDescription = L["Onyx nameplates with health, names, cast bars and raid markers."],
    modeLayout = { decorateOnly = true } }
addon.Nameplates = M
addon:RegisterModule("nameplates", M)

M.VERSION = 1
local P, RGB = Kit.palette, Kit.RGB
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Enemies attacking you (red) and close to it (orange).
M.threatPalette = { aggro = RGB(255, 72, 72), warning = RGB(255, 160, 64) }

M.defaults = {
    version = M.VERSION,
    width = 140, healthHeight = 12, castHeight = 8,
    healthColorMode = "reaction", softness = 30, healthColor = Copy(P.green), threatColors = true,
    healthText = "percent", healthFontSize = 9,
    showName = true, nameFontSize = 10,
    showCastBar = true, castFontSize = 8, castColor = Copy(P.neutral), castLockedColor = Copy(P.tapped),
    showRaidIcon = true, targetHighlight = true,
    texture = "satin", font = "game", fontMedia = "Expressway", outline = false, shadow = true, liftedShadow = true,
    textColor = Copy(P.text),
}
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

-- Fills defaults and validates; profile validation runs this on detached
-- copies. A future settings change bumps M.VERSION and migrates here.
function M.Initialize(db)
    if db.version == nil then db.version = M.VERSION end
    assert(db.version == M.VERSION, "Invalid nameplate settings version")
    for key, default in pairs(M.defaults) do
        if db[key] == nil then db[key] = Copy(default) end
        local value = db[key]
        assert(Public(value) and type(value) == type(default), "Invalid nameplate setting: " .. key)
        if type(default) == "table" then
            for i = 1, 3 do assert(Number(value[i], 0, 1), "Invalid nameplate color: " .. key) end
        end
    end
    for key, r in pairs(M.ranges) do
        local value = db[key]
        assert(Number(value, r[1], r[2]) and value == math.floor(value), "Invalid nameplate range: " .. key)
    end
    for key, allowed in pairs(ALLOWED) do assert(allowed[db[key]], "Invalid nameplate choice: " .. key) end
    local texture = db.texture
    assert(texture == "satin" or texture == "mode" or texture == "flat" or texture == "default" or texture:sub(1, 6) == "media:",
        "Invalid nameplate texture")
end
