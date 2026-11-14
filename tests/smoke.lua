-- ModeUI startup, Mode-themed window with Global, Interface and Frames categories,
-- settings restoration and the one-time Play The Game Tools import; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")

local metadata = H.Toc()
assert(metadata.SavedVariables == "ModeUIDB", "own SavedVariables")
assert(metadata["X-ModeUI-Edition"] == "Forever" and metadata.Interface == "16001")

local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")
local world = H.Load({ before = STUBS })
world.run([[
    assert(addon.initialized and table.concat(addon.moduleOrder,',')=='profiles,optimizations,classColors,windows,chat,damageMeters,actionBars,tooltip,bags,unitFrames,nameplates')
    -- Sidebar order (owner, November 13, 2026): Global, Interface, Frames.
    assert(table.concat(addon.categoryOrder,',')=='global,interface,frames' and addon.categories.interface.title=='Interface'
        and addon.categories.global.title=='Global' and addon.categories.frames.title=='Frames')
    assert(table.concat(addon.categories.global.modules,',')=='profiles,optimizations,classColors')
    assert(table.concat(addon.categories.interface.modules,',')=='windows,chat,damageMeters,actionBars,tooltip,bags')
    assert(table.concat(addon.categories.frames.modules,',')=='unitFrames,nameplates')
    assert(addon.InterfaceTheme.id=='mode' and not addon.InterfaceTheme.blizzardArt,'Mode theme only')
    assert(addon.InterfaceTheme.primary[2]==240/255,'Mode cyan accent')
    assert(SLASH_MODEUI1=='/modeui' and SLASH_PLAYTHEGAMETOOLS1==nil)
    assert(addon.modules.unitFrames.enabled,'unit frames are on for a fresh install')
    assert(not addon.modules.nameplates.enabled,'nameplates start off')
    assert(not addon.modules.actionBars.enabled,'action bars start off')
    assert(not addon.modules.damageMeters.enabled,'damage meters start off')
    assert(ModeUIDB.importedFrom=='none','nothing to import without Play The Game Tools')
    assert(ModeUIDB.schemaVersion==2 and ModeUIDB.activeProfile=='Default' and ModeUIDB.profiles.Default==addon.db,'Default profile')
    assert(messages[1]:find('ModeUI',1,true),'welcome line')
    -- Settings are built on demand: no window or page until the user opens one.
    assert(addon.configWindow==nil,'settings window waits for /modeui')
    SlashCmdList.MODEUI()
    local window=addon.configWindow
    assert(window:IsShown() and window.title:GetText()=='ModeUI' and window.brandLogo==nil,'Mode brand header: the wordmark, no logo')
    assert(window.title.font[2]==addon.InterfaceTheme.fontSize.section+7,'wordmark 7 px larger than before')
    assert(window.moduleHeader.title:GetText()=='Profiles','opens on the first page in the sidebar, Global > Profiles')
    assert(window.selectedCategory=='global' and window.pages.profiles:IsShown())
    assert(window.navigationButtons.interface.label:GetText()=='INTERFACE' and window.navigationButtons.global.label:GetText()=='GLOBAL'
        and window.navigationButtons.frames.label:GetText()=='FRAMES','category headings (uppercase captions)')
    local function Top(id) return select(5, window.navigationButtons[id]:GetPoint(1)) end
    assert(Top('global')>Top('interface') and Top('interface')>Top('frames'),'Global above Interface above Frames')
    assert(window.navigationButtons.dashboard==nil and window.navigationButtons.globalSettings==nil,'no Dashboard or Global Settings')
    assert(window.profileButton==nil,'no profile button')
    local nested=window.sidebarModuleButtons.unitFrames
    assert(nested and nested:IsShown() and nested.label:GetText()=='· Unit Frames','Unit Frames nested under Frames')
    local count=0;for _ in pairs(window.sidebarModuleButtons) do count=count+1 end
    assert(count==11,'eleven pages in the sidebar')
    assert(window.sidebarModuleButtons.bags:IsShown(),'Bags nested under Interface')
    addon:SelectConfigPage('bags');assert(window.pages.bags:IsShown() and window.moduleHeader.title:GetText()=='Bags')
    assert(window.sidebarModuleButtons.nameplates:IsShown(),'Nameplates nested under Frames')
    addon:SelectConfigPage('unitFrames');assert(window.selectedCategory=='frames' and window.pages.unitFrames:IsShown())
    addon:SelectConfigPage('nameplates');assert(window.pages.nameplates:IsShown() and window.moduleHeader.title:GetText()=='Nameplates')
    assert(window.sidebarModuleButtons.actionBars:IsShown(),'Action Bars nested under Interface')
    addon:SelectConfigPage('actionBars');assert(window.pages.actionBars:IsShown() and window.moduleHeader.title:GetText()=='Action Bars')
    assert(window.sidebarModuleButtons.damageMeters:IsShown(),'Damage Meters nested under Interface')
    addon:SelectConfigPage('damageMeters');assert(window.pages.damageMeters:IsShown() and window.moduleHeader.title:GetText()=='Damage Meters')
    for _,id in ipairs({'profiles','optimizations','classColors'}) do
        assert(window.sidebarModuleButtons[id]:IsShown(),id..' nested under Global')
        addon:SelectConfigPage(id);assert(window.pages[id]:IsShown() and window.moduleHeader.title:GetText()==addon.modules[id].title,id)
    end
    addon:SelectConfigPage('profiles');assert(not window.moduleHeader.toggle:IsShown(),'Profiles has no on/off switch')
    addon:SelectConfigPage('optimizations');assert(window.moduleHeader.toggle:IsShown())
    addon:SetModuleEnabled('profiles',false);assert(addon.modules.profiles.enabled,'Profiles stays on')
    addon:SelectConfigPage('unitFrames')
    -- Edit Mode opens the ModeUI edit panel with the frames as movable elements.
    assert(addon:SetEditMode(true) and addon.editWindow:IsShown() and not window:IsShown())
    assert(addon.PositionManager.elements.unitFramesPlayer and addon.PositionManager.elements.unitFramesTarget)
    assert(addon:SetEditMode(false) and window:IsShown())
    window:Hide()
    addon.root.window.x=123;addon.root.window.y=45
    addon:SetModuleEnabled('unitFrames',false)
]], "smoke")

local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([[
    assert(addon.root.window.x==123 and addon.root.window.y==45 and addon.db.window==nil,'window position persists, account-wide')
    assert(not addon.modules.unitFrames.enabled,'module state persists')
    assert(ModeUIDB.importedFrom=='none','import is one-time')
]], "restore")

-- Play The Game Tools stored these frames before ModeUI. ModeUI copies the
-- active profile's unit frame settings and positions once and never edits PTG.
local ptg = { schemaVersion = 1, profileVersion = 1, defaultProfile = "Default", characters = {},
    accountSelection = { activeProfile = "Mode", manualProfile = "Mode", specEnabled = false, specProfiles = {} },
    profiles = {
        Default = { modules = { unitFrames = { enabled = false } } },
        Mode = { modules = { unitFrames = { enabled = true, layoutVersion = 10,
            player = { barWidth = 260, nameColorMode = "lilac" }, target = { barWidth = 210, matchPlayer = false } } },
            positions = { unitFramesPlayer = { target = "screen", placement = "center", x = -300, y = -150 } } },
    } }
local imported = H.Load({ before = STUBS, ptg = ptg })
imported.run([[
    local M=addon.UnitFrames
    assert(ModeUIDB.importedFrom=='PlayTheGameTools:Mode','imported from the active PTG profile')
    assert(M.enabled and M.db.player.barWidth==260 and M.db.target.barWidth==210 and M.db.target.matchPlayer==false)
    assert(M.db.layoutVersion==M.LAYOUT_VERSION and M.db.player.nameColorMode=='sky','migrated to the current layout')
    local position=addon.PositionManager:GetPosition('unitFramesPlayer')
    assert(position.x==-300 and position.y==-150,'Player frame position imported')
    assert(PTGToolsDB.profiles.Mode.modules.unitFrames.layoutVersion==10,'PTG data left untouched')
    assert(PTGToolsDB.profiles.Mode.modules.unitFrames.player.nameColorMode=='lilac')
]], "import")

-- Invalid PTG data is ignored rather than imported or blocking startup.
local broken = H.Load({ before = STUBS, ptg = { profiles = { Default = { modules = { unitFrames = { player = { barWidth = "wide" } } } } },
    defaultProfile = "Default" } })
broken.run([[
    assert(addon.initialized and ModeUIDB.importedFrom=='none' and addon.UnitFrames.db.player.barWidth==180)
]], "import_invalid")

-- The game menu (Esc) and the minimap's addon compartment open ModeUI. The
-- menu double follows Forever's GameMenuFrameMixin: InitButtons rebuilds the
-- list each time, AddSection leaves a 20 px gap before the next button.
local MENU = STUBS .. [==[
    GAMEMENU_OPTIONS='Options';BLIZZARD_STORE='Shop';ADDONS='AddOns';HUD_EDIT_MODE_MENU='Edit Mode'
    LOG_OUT='Log Out';RETURN_TO_GAME='Return to Game'
    SOUNDKIT={IG_MAINMENU_OPTION=852};sounds={};function PlaySound(id) sounds[#sounds+1]=id end
    hiddenPanels={};function HideUIPanel(frame) hiddenPanels[#hiddenPanels+1]=frame;frame:Hide() end
    function MakeGameMenu()
        local menu=CreateFrame('Frame')
        function menu:AddButton(text,callback)
            local button=CreateFrame('Button');button.text=text;button.callback=callback
            button.layoutIndex=self.nextLayoutIndex;self.nextLayoutIndex=self.nextLayoutIndex+1
            button.topPadding=self.sectionSpacing;self.sectionSpacing=nil
            self.buttons[#self.buttons+1]=button;self.dirty=true;return button
        end
        function menu:AddSection() self.sectionSpacing=20 end
        function menu:MarkDirty() self.dirty=true end
        function menu:InitButtons()
            self.buttons={};self.nextLayoutIndex=1
            self:AddButton(GAMEMENU_OPTIONS);self:AddButton(BLIZZARD_STORE);self:AddSection()
            self:AddButton(ADDONS);self:AddButton(HUD_EDIT_MODE_MENU);self:AddSection()
            self:AddButton(LOG_OUT);self:AddSection();self:AddButton(RETURN_TO_GAME)
        end
        return menu
    end
    function MenuLabels(menu)
        local list={};for _,button in ipairs(menu.buttons) do list[#list+1]=button end
        table.sort(list,function(a,b) return a.layoutIndex<b.layoutIndex end)
        local labels={};for i,button in ipairs(list) do labels[i]=button.text..(button.topPadding and '+' or '') end
        return table.concat(labels,',')
    end
    tooltipLines={};function GameTooltip:SetOwner(owner) self.owner=owner end
    function GameTooltip:SetText(text) tooltipLines={text} end
    function GameTooltip:AddLine(text) tooltipLines[#tooltipLines+1]=text end
    compartment={};AddonCompartmentFrame={RegisterAddon=function(self,data) compartment[#compartment+1]=data end}
]==]
local BRAND = "|cff00f0ffMode|r|cffffffffUI|r"
local menuWorld = H.Load({ before = MENU .. "\nGameMenuFrame=MakeGameMenu()\n" })
menuWorld.run(([[
    local BRAND=%q
    assert(addon.Launchers.BRAND_TEXT==BRAND,'Mode in cyan, UI in white')
    GameMenuFrame:InitButtons()
    assert(MenuLabels(GameMenuFrame)=='Options,Shop,'..BRAND..'+,AddOns+,Edit Mode,Log Out+,Return to Game+',
        'ModeUI has its own section between Shop and AddOns: '..MenuLabels(GameMenuFrame))
    GameMenuFrame:InitButtons()
    assert(#GameMenuFrame.buttons==7,'one ModeUI button after every rebuild')
    assert(addon.configWindow==nil,'the menu builds no settings window')
    local own;for _,button in ipairs(GameMenuFrame.buttons) do if button.text==BRAND then own=button end end
    own.callback()
    assert(hiddenPanels[1]==GameMenuFrame and sounds[1]==852,'closes the game menu')
    assert(addon.configWindow and addon.configWindow:IsShown(),'opens the settings window')
    own.callback();assert(addon.configWindow:IsShown(),'never closes an open window')
    testLockdown=true;GameMenuFrame:InitButtons();testLockdown=false
    assert(#GameMenuFrame.buttons==6,'no button added in combat')
    -- The minimap's addon compartment: one entry that opens and closes ModeUI.
    assert(#compartment==1 and compartment[1].text==BRAND and compartment[1].icon==nil)
    compartment[1].func();assert(not addon.configWindow:IsShown(),'compartment click closes the open window')
    compartment[1].func();assert(addon.configWindow:IsShown(),'and opens it again')
    compartment[1].funcOnEnter(CreateFrame('Button'));compartment[1].funcOnLeave()
    assert(tooltipLines[1]==BRAND and tooltipLines[2]:find('open or close',1,true),'compartment tooltip')
]]):format(BRAND), "launchers")

-- Play The Game Tools moves its own button to the top and renumbers; ModeUI's
-- section still lands between Shop and AddOns.
local shared = H.Load({ before = MENU .. [==[
    GameMenuFrame=MakeGameMenu()
    hooksecurefunc(GameMenuFrame,'InitButtons',function(menu)
        local button=menu:AddButton('PTG',function() end)
        table.remove(menu.buttons);table.insert(menu.buttons,1,button)
        for i,item in ipairs(menu.buttons) do item.layoutIndex=i end
    end)
]==] })
shared.run(([[
    GameMenuFrame:InitButtons()
    assert(MenuLabels(GameMenuFrame)=='PTG,Options,Shop,'..%q..'+,AddOns+,Edit Mode,Log Out+,Return to Game+',MenuLabels(GameMenuFrame))
]]):format(BRAND), "launchers_ptg")

-- Blizzard_GameMenu can load after ModeUI; the hook waits for it.
local late = H.Load({ before = MENU })
late.run(([[
    assert(not addon.Launchers:Installed(),'no game menu yet')
    GameMenuFrame=MakeGameMenu();FireEvent('ADDON_LOADED','Blizzard_GameMenu')
    assert(addon.Launchers:Installed(),'hooked once the menu exists')
    GameMenuFrame:InitButtons();assert(MenuLabels(GameMenuFrame):find(%q,1,true))
]]):format(BRAND), "launchers_late")

-- Without a game menu or compartment (or their APIs) nothing is added.
local bare = H.Load({ before = STUBS })
bare.run([[
    local menuHooked,compartmentAdded=addon.Launchers:Installed()
    assert(addon.initialized and not menuHooked and not compartmentAdded)
]], "launchers_absent")
print("launchers: game menu and addon compartment")

print("smoke: all checks passed")

-- Every bundled asset the code names ships in the package.
local assets = H.Load({ before = STUBS })
local missing = {}
for key, asset in pairs(assets.addon.Media.Textures) do
    local path = H.addonDir .. "Media/Textures/" .. asset.file
    local file = io.open(path, "rb"); if file then file:close() else missing[#missing + 1] = key end
end
for _, name in ipairs({ "Lato-Regular.ttf", "Lato-Bold.ttf" }) do
    local file = io.open(H.addonDir .. "Media/Fonts/" .. name, "rb"); if file then file:close() else missing[#missing + 1] = name end
end
assert(#missing == 0, "missing assets: " .. table.concat(missing, ", "))
print("assets: all present")

-- ModeUI's interface uses Expressway when an installed provider brings it,
-- and the bundled Lato otherwise.
local function TitleFont(before)
    local world = H.Load({ before = before })
    return world.run([[ SlashCmdList.MODEUI(); return addon.configWindow.title.font[1] ]], "font")
end
assert(TitleFont(STUBS):find("Lato", 1, true), "Lato without Expressway")
local provider = STUBS .. "\ntestProviderFonts = { [AYIJE_EXPRESSWAY] = true }\n"
provider = "AYIJE_EXPRESSWAY = 'Interface' .. string.char(92) .. 'AddOns' .. string.char(92) .. 'AyijeUI' .. string.char(92) .. 'Media' .. string.char(92) .. 'Fonts' .. string.char(92) .. 'Expressway.ttf'\n" .. provider
assert(TitleFont(provider):find("Expressway", 1, true), "Expressway by default when installed")
print("fonts: Expressway by default")
