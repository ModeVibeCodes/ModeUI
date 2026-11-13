local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Global > Profiles: the settings page for addon.Profiles (Shared/Runtime/Profiles.lua).
-- Always on: there is always an active profile.
-- Files: Init (this), Driver, Settings.
local L = addon.L
local M = { title = L["Profiles"], category = "global", alwaysOn = true,
    configDescription = L["Save, switch and share your ModeUI setups. Profiles are shared by every character on this account."],
    modeLayout = { decorateOnly = true } }
addon.ProfilesModule = M
addon:RegisterModule("profiles", M)
