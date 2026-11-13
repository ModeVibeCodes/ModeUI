local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Global > Optimizations: auto loot, fast loot, hidden error text, max camera
-- distance and UI scale. Everything is off by default, and ModeUI only touches
-- a game setting while you have that optimization turned on. Turning it off (or
-- the whole module) puts back the value the game had before ModeUI changed it.
-- Files: Init (this), GameSettings, Driver, Settings.
local L = addon.L
local M = { title = L["Optimizations"], category = "global", defaultEnabled = true,
    configDescription = L["Loot, error text, camera distance and UI scale. Nothing changes until you turn it on."],
    modeLayout = { decorateOnly = true } }
addon.Optimizations = M
addon:RegisterModule("optimizations", M)

M.defaults = { autoLoot = false, fastLoot = false, hideErrors = false,
    manageCamera = false, cameraZoom = 4, manageScale = false, scaleMode = "auto", uiScale = 71 }
M.ranges = { cameraZoom = { 1, 4 }, uiScale = { 40, 115 } }
M.scaleModes = { auto = true, custom = true }
-- Floor of the game's own UI scale setting; smaller scales are applied to
-- UIParent directly, as Blizzard's pixel-perfect scale does.
M.CVAR_SCALE_FLOOR = 0.65

local Public, Number = addon.IsPublic, addon.IsNumber

function M.Initialize(db)
    for key, default in pairs(M.defaults) do
        if db[key] == nil then db[key] = default end
        assert(Public(db[key]) and type(db[key]) == type(default), "Invalid optimization setting: " .. key)
    end
    for key, range in pairs(M.ranges) do
        assert(Number(db[key], range[1], range[2]), "Invalid optimization range: " .. key)
    end
    assert(M.scaleModes[db.scaleMode], "Invalid UI scale mode.")
end
