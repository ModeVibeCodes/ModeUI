local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Global > Class Colors: optional custom colors per class for every
-- class-colored ModeUI element. Changes apply right away (no reload); turning
-- the module off, or resetting a class, returns to the game's own color.
-- ModeUI's colors are its own; Play The Game Tools keeps its separate setting.
-- Files: Init (this), Driver, Settings.
local L = addon.L
local M = { title = L["Class Colors"], category = "global", defaultEnabled = true,
    configDescription = L["Custom colors for class-colored ModeUI elements, such as names and health bars."],
    modeLayout = { decorateOnly = true } }
addon.ClassColors = M
addon:RegisterModule("classColors", M)

local UnitColor = addon.Domain.UnitColor
M.classes = UnitColor.classes
local KNOWN = {}
for _, class in ipairs(M.classes) do KNOWN[class] = true end
M.knownClasses = KNOWN
local Number = addon.IsNumber

function M.Initialize(db)
    if db.colors == nil then db.colors = {} end
    assert(type(db.colors) == "table", "Invalid class colors.")
    for class, color in pairs(db.colors) do
        assert(KNOWN[class] and type(color) == "table", "Invalid class color: " .. tostring(class))
        for i = 1, 3 do assert(Number(color[i], 0, 1), "Invalid class color channel: " .. class) end
    end
end
