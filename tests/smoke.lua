-- ModeUI startup, the hybrid Mode settings window (Interface, Panels, System),
-- settings restoration and the one-time Play The Game Tools import; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")

local metadata = H.Toc()
assert(metadata.SavedVariables == "ModeUIDB", "own SavedVariables")
assert(metadata["X-ModeUI-Edition"] == "Forever" and metadata.Interface == "16001")

local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")
local world = H.Load({ before = STUBS })
world.run([[
    assert(addon.initialized and table.concat(addon.moduleOrder,',')=='profiles,optimizations,classColors,windows,chat,damageMeters,actionBars,cooldownManager,tooltip,bags,minimap,unitFrames,nameplates,partyFrames')
    -- Sidebar order and captions (docs/DESIGN_LANGUAGE.md): Interface, Panels, System.
    assert(table.concat(addon.categoryOrder,',')=='frames,interface,global' and addon.categories.frames.title=='Interface'
        and addon.categories.interface.title=='Panels' and addon.categories.global.title=='System')
    assert(table.concat(addon.categories.global.modules,',')=='profiles,optimizations,classColors')
    assert(table.concat(addon.categories.interface.modules,',')=='windows,chat,damageMeters,actionBars,tooltip,bags,minimap')
    assert(table.concat(addon.categories.frames.modules,',')=='unitFrames,nameplates,partyFrames')
    assert(addon.InterfaceTheme.id=='mode' and not addon.InterfaceTheme.blizzardArt,'Mode theme only')
    assert(addon.Style.SameColor(addon.InterfaceTheme.primary,addon.Style.Tone.ivory),'Mode Ivory accent')
    assert(SLASH_MODEUI1=='/modeui' and SLASH_PLAYTHEGAMETOOLS1==nil)
    assert(addon.modules.unitFrames.enabled,'unit frames are on for a fresh install')
    assert(not addon.modules.nameplates.enabled,'nameplates start off')
    assert(not addon.modules.partyFrames.enabled,'party frames start off')
    assert(not addon.modules.actionBars.enabled,'action bars start off')
    assert(not addon.modules.damageMeters.enabled,'damage meters start off')
    assert(not addon.modules.minimap.enabled,'the minimap starts off')
    assert(not addon.modules.cooldownManager.enabled,'the cooldown manager starts off')
    assert(ModeUIDB.importedFrom=='none','nothing to import without Play The Game Tools')
    assert(ModeUIDB.schemaVersion==2 and ModeUIDB.activeProfile=='Default' and ModeUIDB.profiles.Default==addon.db,'Default profile')
    assert(messages[1]:find('ModeUI',1,true),'welcome line')
    -- Settings are built on demand: no window or page until the user opens one.
    assert(addon.configWindow==nil,'settings window waits for /modeui')
    SlashCmdList.MODEUI()
    local window=addon.configWindow
    local S=addon.ConfigWidgets.SETTINGS_SIZES
    local function Click(button) button:GetScript('OnClick')(button) end
    local function Has(list,value) for _,v in ipairs(list or {}) do if v==value then return true end end end
    assert(window:IsShown() and window:GetWidth()==1000 and S.sidebar==184 and S.rail==48 and S.column==432,'the artifact measurements')
    assert(window.title:GetText()=='M O D E' and window.title.font[2]==addon.InterfaceTheme.fontSize.brand,'MODE wordmark')
    assert(window.title.font[1]:find('Geist%-Bold%.ttf$'),'the wordmark in Geist Bold')
    -- Opens on the main panel: full sidebar, General page, no breadcrumb.
    assert(window.selectedPage=='home' and window.layout=='home' and window.pages.home:IsShown())
    assert(window.moduleHeader.title:GetText()=='General' and not window.moduleHeader.toggle:IsShown())
    assert(window.sidebar:IsShown() and not window.rail:IsShown() and not window.previewPane:IsShown())
    assert(not window.backButton:IsShown() and not window.resetButton:IsShown(),'no breadcrumb or Reset on the main panel')
    assert(window.pages.home.cardColumns==4 and window.pages.home.homeProfile and window.pages.home.homeResetWindow,'General cards, four across')
    local cards=window.pages.home.cards
    assert(#cards==4 and cards[1].frame:GetHeight()==cards[4].frame:GetHeight() and cards[1].top==cards[4].top,'a grid row: one height for every card')
    assert(window.navigationButtons.frames.label:GetText()=='INTERFACE' and window.navigationButtons.interface.label:GetText()=='PANELS'
        and window.navigationButtons.global.label:GetText()=='SYSTEM','category captions (uppercase)')
    local function Top(row) return select(5, row:GetPoint(1)) end
    local rows=window.sidebarModuleButtons
    assert(Top(rows.home)>Top(rows.unitFrames) and Top(rows.unitFrames)>Top(rows.chat) and Top(rows.chat)>Top(rows.profiles),'General, then Interface, Panels, System')
    assert(rows.unitFrames.label:GetText()=='Unit Frames' and rows.unitFrames.icon and rows.unitFrames.dot and not rows.profiles.dot,'icons and on/off dots')
    local count=0;for _ in pairs(rows) do count=count+1 end
    assert(count==14,'General and thirteen modules in the sidebar')
    assert(window.profileSelect and window.searchInput and window.closeButton,'header: search, profile, close')
    assert(window.doneButton and window.editButton and window.reloadButton and window.previewButton,'footer buttons')
    -- A simple module keeps the sidebar and the whole page, with a breadcrumb.
    addon:SelectConfigPage('bags')
    assert(window.layout=='page' and window.pages.bags:IsShown() and window.moduleHeader.title:GetText()=='Bags')
    assert(window.backButton:IsShown() and window.crumbTitle:GetText()=='Bags' and window.sidebar:IsShown())
    assert(window.resetButton:IsShown() and select(2,window.editButton:GetPoint(1))==window.resetButton,'Bags has a reset to defaults; Edit Mode beside it')
    assert(window.pages.bags.cardColumns==2 and window.pages.bags.autoColumns,'existing pages show their cards as tiles, two across')
    -- Small previews: the icon rail, the preview across the top, tiles below.
    addon:SelectConfigPage('unitFrames')
    assert(window.layout=='strip' and window.rail:IsShown() and not window.sidebar:IsShown() and not window.previewPane:IsShown())
    assert(window.selectedCategory=='frames' and window.pages.unitFrames:IsShown() and not window.pages.unitFrames.previewSplit)
    assert(window.pages.unitFrames.previewArea:GetParent()==window.pages.unitFrames and window.pages.unitFrames.cardColumns==2,'preview strip and tiles')
    assert(window.railButtons.unitFrames.selected and not window.resetButton:IsShown())
    assert(select(2,window.editButton:GetPoint(1))==window.doneButton,'without Reset, Edit Mode sits beside Done')
    addon:SelectConfigPage('nameplates');assert(window.layout=='strip')
    addon:SelectConfigPage('actionBars');assert(window.layout=='strip','one bar at a time: a strip')
    -- Tall previews: the settings column beside the live preview.
    for _,id in ipairs({'partyFrames'}) do
        addon:SelectConfigPage(id);assert(window.layout=='split' and window.pages[id]:IsShown() and window.moduleHeader.title:GetText()==addon.modules[id].title,id)
        assert(window.previewPane:IsShown() and window.pages[id].previewArea:GetParent()==window.previewPane and window.pages[id].previewArea:IsShown(),id..' preview in the pane')
        assert(window.column:GetWidth()>=480+44 and window.pages[id].cardColumns==nil,'the column fits a page not yet rebuilt')
    end
    addon:SelectConfigPage('chat');assert(not window.pages.partyFrames.previewArea:IsShown() and not window.previewPane:IsShown(),'one preview at a time')
    -- Back: the rail's home, "All modules", the wordmark or Esc; Esc on the main panel closes.
    Click(window.railButtons.home);assert(window.selectedPage=='home' and window.sidebar:IsShown())
    addon:SelectConfigPage('chat');Click(window.backButton);assert(window.selectedPage=='home')
    addon:SelectConfigPage('chat');Click(window.wordmark);assert(window.selectedPage=='home')
    addon:SelectConfigPage('unitFrames')
    assert(window.backCatcher:IsShown() and Has(UISpecialFrames,'ModeUIConfigBack'))
    window.backCatcher:Hide();assert(window:IsShown() and window.selectedPage=='home' and window.backCatcher:IsShown(),'Esc: module to main panel')
    window.backCatcher:Hide();assert(not window:IsShown(),'Esc: main panel to closed')
    SlashCmdList.MODEUI();assert(window:IsShown() and window.selectedPage=='home')
    -- Segmented choices: side by side while every label fits; a row that can't
    -- fit them on a shared line stays on its own; narrower still, one per line.
    local W=addon.ConfigWidgets
    local test=W.Page(UIParent);test.cardColumns=2;test:Group('Fit')
    local host=test:Row('Pick')
    local segments=W.Exclusive(host,{{label='Alpha Choice',value=1},{label='Bravo Choice',value=2},{label='Charlie Choice',value=3}},
        function() return 1 end,function() end)
    local row,box=host.row,segments[1]:GetParent()
    row:layoutChildren(900);assert(not box.vertical and row:GetHeight()==58,'side by side when the labels fit')
    assert(row.segmentNeeds[1]()>100,'too wide to share a narrow line')
    row:layoutChildren(100);assert(box.vertical and row:GetHeight()>58,'one per line when even the full width is short')
    row:layoutChildren(900);assert(not box.vertical and row:GetHeight()==58,'and back')
    -- Combat closes the window.
    window:GetScript('OnEvent')(window,'PLAYER_REGEN_DISABLED');assert(not window:IsShown(),'closes when combat starts')
    SlashCmdList.MODEUI();assert(window:IsShown())
    for _,id in ipairs({'minimap','windows','chat','tooltip','bags'}) do
        addon:SelectConfigPage(id);assert(window.layout=='page' and window.pages[id]:IsShown() and window.moduleHeader.title:GetText()==addon.modules[id].title,id)
    end
    -- The Cooldown Manager is standalone: its own window, opened with /mcdm.
    assert(window.sidebarModuleButtons.cooldownManager==nil and addon.modules.cooldownManager.standalone,'no Cooldown Manager page here')
    assert(SLASH_MODEUICDM1=='/mcdm' and addon.CooldownManager.window==nil,'its window waits for /mcdm')
    SlashCmdList.MODEUICDM()
    assert(ModeUICooldownManagerWindow:IsShown() and addon.CooldownManager.page,'/mcdm opens it')
    SlashCmdList.MODEUICDM()
    assert(not ModeUICooldownManagerWindow:IsShown(),'and closes it')
    assert(window.sidebarModuleButtons.damageMeters:IsShown(),'Damage Meters under Panels')
    addon:SelectConfigPage('damageMeters');assert(window.pages.damageMeters:IsShown() and window.moduleHeader.title:GetText()=='Damage Meters')
    for _,id in ipairs({'profiles','optimizations','classColors'}) do
        assert(window.sidebarModuleButtons[id]:IsShown(),id..' under System')
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

-- ModeUI's interface is Geist (docs/DESIGN_LANGUAGE.md, "Text"), even when an
-- installed provider brings Expressway; choosing the bundled Lato keeps Lato.
local function TitleFont(before)
    local world = H.Load({ before = before })
    return world.run([[ SlashCmdList.MODEUI(); return addon.configWindow.title.font[1] ]], "font")
end
assert(TitleFont(STUBS):find("Geist", 1, true), "Geist by default")
local provider = STUBS .. "\ntestProviderFonts = { [AYIJE_EXPRESSWAY] = true }\n"
provider = "AYIJE_EXPRESSWAY = 'Interface' .. string.char(92) .. 'AddOns' .. string.char(92) .. 'AyijeUI' .. string.char(92) .. 'Media' .. string.char(92) .. 'Fonts' .. string.char(92) .. 'Expressway.ttf'\n" .. provider
assert(TitleFont(provider):find("Geist", 1, true), "Geist even with Expressway installed")
print("fonts: Geist by default")
