local addonName, addon = ...
-- Package failure must stop before ADDON_LOADED can initialize settings.
if addon.Edition and not addon.Edition:CheckClient() then return end
addon.developmentPhase = "Forever Beta"
function addon:BuildIdentification()
    local ok, version = false, nil
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        ok, version = pcall(C_AddOns.GetAddOnMetadata, addonName, "Version")
    end
    if not ok or not addon.IsPublic(version) or type(version) ~= "string" or version == "" then version = "unknown" end
    self.buildVersion = version:sub(1, 48)
    return "v" .. self.buildVersion .. " | " .. self.developmentPhase .. " | /modeui"
end

addon.Events:On(addon, "ADDON_LOADED", function(_, loadedName)
    if loadedName ~= addonName or addon.initialized then
        return
    end
    addon.Events:Off(addon, "ADDON_LOADED")
    if addon.Edition and not addon.Edition:CheckClient() then return end
    addon.Media:AttachLibrary()
    addon:InitializeDatabase()
    addon.Media:DiscoverMedia()
    addon:ApplyInterfaceTheme()
    addon:InitializeModules()
    addon.initialized = true
    addon:InitializeDisplayModes()
    addon.Media:Initialize()
    addon.ReloadManager:Start()
    addon:PrintAction(addon:BuildIdentification(), "welcome")

    SLASH_MODEUI1 = "/modeui"
    SlashCmdList.MODEUI = function(text)
        if type(text) == "string" and text:lower():match("^%s*resetwindow%s*$") then
            addon:ResetConfigWindowPosition(); return
        end
        addon:ToggleConfig()
    end
end)
