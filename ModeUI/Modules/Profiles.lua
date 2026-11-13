local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Global > Profiles: the settings page for addon.Profiles (Shared/Runtime/Profiles.lua).
-- Always on: there is always an active profile.
local M = { title = "Profiles", category = "global", alwaysOn = true,
    configDescription = "Save, switch and share your ModeUI setups. Profiles are shared by every character on this account." }
addon.ProfilesModule = M
addon:RegisterModule("profiles", M)
