local _, addon = ...
local M = addon.ProfilesModule
if not M then return end

-- Profiles are created, switched and shared by Shared/Runtime/Profiles.lua,
-- which sends PROFILES_CHANGED after every change. An open settings window
-- shows the change at once.
function M:OnInitialize()
    addon.RegisterMessage(self, addon.Messages.PROFILES_CHANGED, function()
        if addon.configWindow and addon.RefreshConfig then addon:RefreshConfig() end
    end)
end
