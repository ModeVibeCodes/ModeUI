local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Global > Optimizations: auto loot, fast loot, hidden error text, max camera
-- distance and UI scale. ModeUI only touches a game setting while you have
-- that optimization turned on, and everything but the UI scale starts off.
-- The UI scale starts on (owner, November 15, 2026): Pixel Perfect for the
-- screen the game reports, so ModeUI's 1px edges land on whole pixels at
-- 1080p, 1440p and beyond (GameSettings.lua, SuggestedScale). Turning an
-- optimization off (or the whole module) puts back the value the game had
-- before ModeUI changed it. The General page's UI Scale card (Settings.lua,
-- BuildHomeCard) applies the suggested scale in one click.
-- Files: Init (this), GameSettings, Driver, Settings.
local L = addon.L
local M = { title = L["Optimizations"], category = "global", defaultEnabled = true,
    configDescription = L["Loot, error text, camera distance and UI scale. The UI scale starts pixel perfect for your screen; the rest waits until you turn it on."],
    modeLayout = { decorateOnly = true } }
addon.Optimizations = M
addon:RegisterModule("optimizations", M)

-- Version 2: Set UI Scale starts on, at the Pixel Perfect scale.
M.VERSION = 2
M.defaults = { version = M.VERSION, autoLoot = false, fastLoot = false, hideErrors = false,
    manageCamera = false, cameraZoom = 4, manageScale = true, scaleMode = "auto", uiScale = 71 }
M.ranges = { cameraZoom = { 1, 4 }, uiScale = { 40, 115 } }
-- Scale: Pixel Perfect (auto), 1080p Size (size1080: the interface 1080 UI
-- units tall on any screen, 71.11%; owner, November 24, 2026, for 1440p) or
-- Custom.
M.scaleModes = { auto = true, size1080 = true, custom = true }
-- Floor of the game's own UI scale setting; smaller scales are applied to
-- UIParent directly, as Blizzard's pixel-perfect scale does.
M.CVAR_SCALE_FLOOR = 0.65

local Public, Number = addon.IsPublic, addon.IsNumber

function M.Initialize(db)
    -- Version 1 -> 2: a profile still at version 1's default (Set UI Scale
    -- off) takes the new one; its Scale choice (Pixel Perfect or a custom
    -- scale) stays.
    if db.version == nil then
        if db.manageScale == false then db.manageScale = true end
        db.version = M.VERSION
    end
    assert(db.version == M.VERSION, "Invalid optimization settings version.")
    for key, default in pairs(M.defaults) do
        if db[key] == nil then db[key] = default end
        assert(Public(db[key]) and type(db[key]) == type(default), "Invalid optimization setting: " .. key)
    end
    for key, range in pairs(M.ranges) do
        assert(Number(db[key], range[1], range[2]), "Invalid optimization range: " .. key)
    end
    assert(M.scaleModes[db.scaleMode], "Invalid UI scale mode.")
end
