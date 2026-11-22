local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Global > Appearance: the suite's look (docs/DESIGN_LANGUAGE.md, "Suite
-- defaults"; the owner's settings review, November 21, 2026). The font every
-- module's text follows while its Font is "Suite", and the metal of every
-- border whose Border Metal is "Suite". A module keeps its own value once you
-- pick one on its page; this page lists those and takes them back to the
-- suite. The values live in the profile's globalMedia (Shared/Runtime/DB.lua),
-- so the module itself saves nothing. Always on.
-- Files: Init (this), Driver, Settings.
local L = addon.L
local M = { title = L["Appearance"], category = "global", alwaysOn = true, icon = "Windows",
    configDescription = L["The font and border metal every module follows unless you customize it."],
    modeLayout = { decorateOnly = true } }
addon.Appearance = M
addon:RegisterModule("appearance", M)

function M.Initialize(db) assert(type(db) == "table", "Invalid appearance settings.") end
