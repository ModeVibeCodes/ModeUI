local _, addon = ...

-- Ways into the settings window from Blizzard's own UI (owner, November 13,
-- 2026): a ModeUI button in the game menu (Esc), in its own section between
-- Shop and AddOns, and an entry in the minimap's addon compartment, the menu
-- that holds every addon's minimap button. Both use the brand colors: "Mode"
-- in the ModeUI cyan, "UI" in white.
-- Forever source (wow-ui-source, forever branch):
--   Blizzard_GameMenu/Shared/GameMenuFrame.lua (GameMenuFrameMixin:InitButtons,
--   :AddButton, .buttons, :SetupGamepadButtons) and
--   Blizzard_SharedXML/Shared/Frame/MainMenuFrameTemplates.lua (layoutIndex,
--   topPadding, AddSection's 20 px); Blizzard_Minimap/Mainline/AddonCompartment.lua
--   (AddonCompartmentFrame:RegisterAddon), extended by Camelot/AddonCompartment.lua.
-- Nothing is stored on Blizzard's frames; every hook is a post-hook.
local L = addon.L
local Launchers = {}
addon.Launchers = Launchers

Launchers.BRAND_TEXT = "|cff00f0ffMode|r|cffffffffUI|r"
-- The gap Blizzard's AddSection leaves between groups of game menu buttons.
local SECTION_SPACING = 20

local function TextOf(button)
    local ok, text = pcall(button.GetText, button)
    if ok and addon.IsPublic(text) then return text end
end

-- The list the menu lays out, in order. Forever keeps it in menu.buttons;
-- without it, the pool's active buttons sorted by layoutIndex.
local function MenuButtons(menu)
    if type(menu.buttons) == "table" then return menu.buttons, true end
    local list = {}
    if menu.buttonPool and menu.buttonPool.EnumerateActive then
        for button in menu.buttonPool:EnumerateActive() do list[#list + 1] = button end
    end
    table.sort(list, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)
    return list, false
end

-- Where ModeUI's section goes: before the first button that starts a new
-- section after Options (Shop is in Options' section). That is AddOns on a
-- normal menu, and stays right when another addon renamed or added buttons.
local function InsertIndex(list, own)
    local options
    for index, button in ipairs(list) do
        if button ~= own and TextOf(button) == GAMEMENU_OPTIONS then options = index; break end
    end
    if not options then return 1 end
    for index = options + 1, #list do
        local button = list[index]
        if button ~= own and button.topPadding then return index end
    end
    return options + 1
end

local function Place(menu, own)
    local list, owned = MenuButtons(menu)
    for index, button in ipairs(list) do
        if button == own then table.remove(list, index); break end
    end
    local index = InsertIndex(list, own)
    local after = list[index]
    -- Its own section: a gap above (none at the very top) and below.
    own.topPadding = index > 1 and SECTION_SPACING or nil
    if after then after.topPadding = after.topPadding or SECTION_SPACING end
    if owned then
        table.insert(list, index, own)
        -- Keep layout, controller traversal and narration in the same order
        -- (Play The Game Tools renumbers the same way, so both buttons fit).
        for position, button in ipairs(list) do
            button.layoutIndex = position
            if NarrationUtil and type(NarrationUtil.MakeIndexInfo) == "function" then
                button.NarrationGetIndexInfo = function() return NarrationUtil.MakeIndexInfo(position, #list) end
            end
        end
        if menu.ResetGamepadButtons and menu.SetupGamepadButtons then
            menu:ResetGamepadButtons(); menu:SetupGamepadButtons()
        end
    elseif after then
        own.layoutIndex = (after.layoutIndex or 1) - 0.5
    end
    if menu.MarkDirty then menu:MarkDirty() end
end

-- Runs after every InitButtons; Blizzard's Reset releases the pooled button
-- on each rebuild, so it is added again each time the menu opens.
local function AddMenuButton(menu)
    if not addon.initialized or addon.InCombat() then return end
    local own = menu:AddButton(Launchers.BRAND_TEXT, function()
        if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION) end
        HideUIPanel(menu)
        addon:OpenConfig()
    end)
    if own then Place(menu, own) end
end

local menuHooked = false
local function HookGameMenu()
    if menuHooked then return true end
    local menu = GameMenuFrame
    if type(menu) ~= "table" or type(menu.InitButtons) ~= "function" or type(menu.AddButton) ~= "function"
        or type(hooksecurefunc) ~= "function" or type(HideUIPanel) ~= "function" then return false end
    hooksecurefunc(menu, "InitButtons", AddMenuButton)
    menuHooked = true
    return true
end

local compartmentAdded = false
local function AddCompartmentEntry()
    local compartment = AddonCompartmentFrame
    if compartmentAdded or type(compartment) ~= "table" or type(compartment.RegisterAddon) ~= "function" then
        return compartmentAdded
    end
    compartment:RegisterAddon({
        text = Launchers.BRAND_TEXT,
        func = function() addon:ToggleConfig() end,
        funcOnEnter = function(button)
            if not GameTooltip or not button then return end
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            GameTooltip:SetText(Launchers.BRAND_TEXT)
            GameTooltip:AddLine(L["Click to open or close the ModeUI settings."], 1, 1, 1)
            GameTooltip:Show()
        end,
        funcOnLeave = function() if GameTooltip then GameTooltip:Hide() end end,
    })
    compartmentAdded = true
    return true
end

-- Called once by Boot after the modules start. The game menu may load after
-- ModeUI, so its hook waits for ADDON_LOADED when the menu isn't there yet.
function addon:InstallLaunchers()
    AddCompartmentEntry()
    if not HookGameMenu() then
        addon.Events:On(Launchers, "ADDON_LOADED", function()
            if HookGameMenu() then addon.Events:Off(Launchers, "ADDON_LOADED") end
        end)
    end
end

function Launchers:Installed() return menuHooked, compartmentAdded end
