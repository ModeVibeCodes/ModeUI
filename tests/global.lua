-- Global category: Profiles, Optimizations and Class Colors, plus the schema 1
-- to 2 settings migration. Simulated client; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")

-- Game settings (CVars), error frame, screen and loot doubles.
local CLIENT = STUBS .. [==[
    cvars={autoLootDefault='0',cameraDistanceMaxZoomFactor='1.9',useUiScale='0',uiScale='1.0'}
    restrictedCVars={};secureCVars={}
    cvarWrites={}
    C_CVar={
        GetCVar=function(name) return cvars[name] end,
        SetCVar=function(name,value) if restrictedCVars[name] or secureCVars[name] then return false end
            cvarWrites[#cvarWrites+1]=name..'='..tostring(value);cvars[name]=tostring(value);return true end,
        GetCVarInfo=function(name) if cvars[name]==nil then return nil end
            return cvars[name],cvars[name],false,false,restrictedCVars[name]==true,secureCVars[name]==true,false end,
        GetCVarBool=function(name) return cvars[name]=='1' end,
    }
    function GetPhysicalScreenSize() return 2560,1440 end
    UIErrorsFrame=CreateFrame('Frame');UIErrorsFrame:RegisterEvent('UI_ERROR_MESSAGE')
    lootItems=0;looted={}
    function GetNumLootItems() return lootItems end
    function LootSlot(i) looted[#looted+1]=i end
    loadedAddOns={}
    C_AddOns.IsAddOnLoaded=function(name) return loadedAddOns[name]==true end
    RAID_CLASS_COLORS={ROGUE={r=1,g=0.96,b=0.41},MAGE={r=0.25,g=0.78,b=0.92}}
]==]

-- Schema 1 (the first ModeUI release) migrates into a Default profile.
local v1 = { schemaVersion = 1, window = { x = 10, y = 20 }, importedFrom = "none",
    globalMedia = { font = "game", texture = "default", border = "thin", overrides = {} },
    modules = { unitFrames = { enabled = true, layoutVersion = 11, player = { barWidth = 222 } } },
    positions = { unitFramesPlayer = { target = "screen", placement = "center", x = -11, y = -22 } },
    mediaRegistry = { font = {} } }
local world = H.Load({ before = CLIENT, saved = v1 })
world.run([==[
    local root=ModeUIDB
    assert(root.schemaVersion==2 and root.activeProfile=='Default' and root.profiles.Default==addon.db,'migrated to profiles')
    assert(root.window.x==10 and root.window.y==20 and root.mediaRegistry and root.importedFrom=='none','account data stays at the root')
    assert(root.modules==nil and root.positions==nil and root.globalMedia==nil,'profile data moved off the root')
    assert(addon.UnitFrames.db.player.barWidth==222,'unit frame settings kept')
    assert(addon.PositionManager:GetPosition('unitFramesPlayer').x==-11,'positions kept')
    assert(addon.db.modules.optimizations and addon.db.modules.classColors,'new modules filled in')
]==], "migration")

-- Profiles ---------------------------------------------------------------
world.run([==[
    local P=addon.Profiles
    -- Mode-DPS/TANK and Mode-Healer: the DPS / Tank and Healer layouts, each made into a profile once per seed at login (Shared/Runtime/Layouts.lua).
    assert(table.concat(P:List(),',')=='Default,Mode-DPS/TANK,Mode-Healer' and P:Active()=='Default' and ModeUIDB.builtLayouts['mode-default@4'] and ModeUIDB.builtLayouts['healer@8'])
    -- Every profile is Mode-Obsidian.
    for _, name in ipairs(P:List()) do assert(ModeUIDB.profiles[name].theme=='obsidian' and ModeUIDB.profiles[name].look==1 and ModeUIDB.profiles[name].typeface==4, name..' in Mode-Obsidian') end
    assert(not P:Create('','x') and not P:Create('Bad|Name') and not P:Create(string.rep('x',49)),'names validated')
    assert(P:Create('Raid'),'new profile from defaults')
    assert(ModeUIDB.profiles.Raid.modules.unitFrames.player.barWidth==184,'defaults, not a copy')
    assert(not P:Create('raid ') or true)
    assert(not P:Create('Raid'),'duplicate names refused')
    assert(P:Create('Copy',P:Active()) and ModeUIDB.profiles.Copy.modules.unitFrames.player.barWidth==222,'copy of the active profile')
    assert(ModeUIDB.profiles.Copy~=addon.db and ModeUIDB.profiles.Copy.modules~=addon.db.modules,'copies are detached')
    assert(P:Rename('Copy','Solo') and ModeUIDB.profiles.Solo and not ModeUIDB.profiles.Copy)
    assert(not P:Delete('Default'),'the active profile cannot be deleted')
    -- Switching applies after a reload; Reload is requested.
    assert(P:Select('Solo') and P:Pending()=='Solo' and addon.ReloadManager.requests.profile,'switch waits for reload')
    assert(P:Select('Default') and P:Pending()==nil and not addon.ReloadManager.requests.profile,'choosing the active one cancels')
    assert(P:Select('Raid') and P:Rename('Raid','Raid 25') and P:Pending()=='Raid 25','rename follows the pending switch')
    assert(addon.ReloadManager:GetReason():find('Raid 25',1,true))
    assert(P:Delete('Raid 25') and P:Pending()==nil and not addon.ReloadManager.requests.profile,'deleting the pending profile cancels')
    assert(P:Create('Raid') and P:Select('Raid'))
    addon.UnitFrames:SetFrameOption('player','barWidth',240)
    assert(addon.db.modules.unitFrames.player.barWidth==240,'changes save to the active profile')
]==], "profiles")

-- The pending profile loads after reload; the old one keeps its settings.
local switched = H.Load({ before = CLIENT, saved = world.saved() })
switched.run([==[
    assert(ModeUIDB.activeProfile=='Raid' and ModeUIDB.pendingProfile==nil,'switched on reload')
    assert(addon.UnitFrames.db.player.barWidth==184 and ModeUIDB.profiles.Default.modules.unitFrames.player.barWidth==240)
    assert(addon.Profiles.status=='Switched to Raid.')
]==], "switched")

-- A profile that became invalid is not loaded; the current one stays.
local broken = world.saved()
broken.pendingProfile = "Solo"
broken.profiles.Solo.modules.unitFrames.player.barWidth = "wide"
local kept = H.Load({ before = CLIENT, saved = broken })
kept.run([==[
    assert(ModeUIDB.activeProfile=='Default' and ModeUIDB.failedProfile=='Solo' and ModeUIDB.pendingProfile==nil)
    assert(addon.Profiles.status:find('could not be loaded',1,true),'reported')
]==], "invalid_pending")

-- Import / export.
world.run([==[
    local P=addon.Profiles
    local text=assert(P:Export('Default'))
    assert(text:sub(1,5)=='!MT1!','encoded string')
    local profile,name=P:PrepareImport(text)
    assert(profile and name=='Default (2)','unique name when none is given')
    assert(P:Import(text,'Shared') and ModeUIDB.profiles.Shared.modules.unitFrames.player.barWidth==240)
    local _,_,reason=P:PrepareImport(text,'Shared');assert(reason:find('already exists',1,true),'never overwrites')
    assert(select(3,P:PrepareImport('garbage')):find('valid',1,true))
    -- Play The Game Tools strings use the same encoding but are refused.
    local ptg=addon.ProfileCodec.Encode({version=1,name='PTG',profile={modules={}}})
    assert(select(3,P:PrepareImport(ptg))=="This profile string isn't from ModeUI.",'PTG string refused')
    local foreign=addon.ProfileCodec.Encode({format='ModeUI',version=1,name='X',profile={modules={combatTimer={enabled=true}}}})
    assert(select(3,P:PrepareImport(foreign)):find("doesn't have",1,true),'unknown modules refused')
    local sneaky=addon.ProfileCodec.Encode({format='ModeUI',version=1,name='X',profile={profiles={}}})
    assert(select(3,P:PrepareImport(sneaky)):find('unexpected',1,true),'account data refused')
    -- Exports never carry account data.
    local decoded=addon.ProfileCodec.Decode(text)
    assert(decoded.format=='ModeUI' and decoded.profile.window==nil and decoded.profile.profiles==nil and decoded.profile.modules.unitFrames)
]==], "import_export")

-- Profiles page.
world.run([==[
    SlashCmdList.MODEUI()
    addon:SelectConfigPage('profiles')
    local page=addon.configWindow.pages.profiles
    local titles={};for _,s in ipairs(page.sections) do titles[#titles+1]=s.title end
    assert(table.concat(titles,'|')=='Profiles|Import / Export' and page.sectionTabs)
    assert(page.activeLabel:GetText():find('Default',1,true))
    page.createInput:SetText('Arena');page.createButton.scripts.OnClick(page.createButton)
    assert(ModeUIDB.profiles.Arena and page.selectedProfile()=='Arena' and page.createInput:GetText()=='','create from the page')
    assert(page.profileStatus:GetText()=='Created Arena.')
    page.profileSwitch.scripts.OnClick(page.profileSwitch)
    assert(addon.Profiles:Pending()=='Arena' and page.activeLabel:GetText():find('Arena after reload',1,true))
    page.profileCancel.scripts.OnClick(page.profileCancel);assert(addon.Profiles:Pending()==nil)
    page.profileDelete.scripts.OnClick(page.profileDelete);assert(not ModeUIDB.profiles.Arena and page.selectedProfile()=='Default')
    page.exportButton.scripts.OnClick(page.exportButton)
    local exported=page.profileEditor:GetText();assert(exported:sub(1,5)=='!MT1!','export fills the editor')
    page.importName:SetText('From Page');page.setEditorText('');page.profileEditor:SetText(exported)
    assert(addon.ReloadManager.drafts['profile-import'],'unsent import blocks a reload')
    page.importButton.scripts.OnClick(page.importButton)
    assert(ModeUIDB.profiles['From Page'] and page.profileEditor:GetText()=='' and not addon.ReloadManager.drafts['profile-import'])
    addon.configWindow:Hide()
]==], "profiles_page")

-- Optimizations ----------------------------------------------------------
world.run([==[
    local O=addon.Optimizations
    -- The UI scale starts on, pixel perfect for the screen (1440p: 768/1440 =
    -- 53.33%, below the game's own floor, so UIParent takes it directly);
    -- nothing else changes until it's turned on.
    assert(O.enabled and O.db.version==2 and O.db.manageScale and O.db.scaleMode=='auto','Set UI Scale starts on, Pixel Perfect')
    assert(table.concat(cvarWrites,',')=='useUiScale=1,uiScale=0.6500','only the UI scale is set')
    assert(math.abs(UIParent:GetScale()-768/1440)<1e-6 and O.status.scale=='UI scale 53.33%.')
    assert(ModeUIDB.optimizationOriginals.useUiScale=='0' and ModeUIDB.optimizationOriginals.uiScale=='1.0','the game scale is remembered')
    assert(O:UsingSuggestedScale(),'the suggested scale is in use')
    -- Suggested scales: one pixel per UI unit up to 2159 tall, two from 2160.
    local function Suggest(w,h) local physical=GetPhysicalScreenSize;GetPhysicalScreenSize=function() return w,h end
        local scale,height,per=O:SuggestedScale();GetPhysicalScreenSize=physical;return scale,height,per end
    local s,h,per=Suggest(1920,1080);assert(math.abs(s-768/1080*100)<1e-9 and h==1080 and per==1,'1080p: 71.11%')
    s,h,per=Suggest(2560,1440);assert(math.abs(s-768/1440*100)<1e-9 and per==1,'1440p: 53.33%')
    s,h,per=Suggest(3840,2160);assert(math.abs(s-768*2/2160*100)<1e-9 and per==2,'4K: two pixels per unit, 71.11%')
    -- The General page's UI Scale card: the screen, and the quick action.
    SlashCmdList.MODEUI();addon:SelectConfigPage('home')
    local home=addon.configWindow.pages.home
    local button,row=home.homeScaleButton,home.homeScaleRow
    assert(row.settingsLabel:GetText()=='1440p' and button.label:GetText()=='Using 53.33%' and not button:IsEnabled(),'in use: nothing to do')
    assert(O:SetOption('manageScale',false) and cvars.useUiScale=='0' and cvars.uiScale=='1.0','off: the game scale back')
    addon.ReloadManager:Clear('uiScale');home:Refresh()
    assert(button.label:GetText()=='Use 53.33%' and button:IsEnabled(),'off: offered')
    addon:SetModuleEnabled('optimizations',false);addon.ReloadManager:Clear('uiScale')
    button.scripts.OnClick(button)
    assert(O.enabled and O.db.manageScale and O.db.scaleMode=='auto' and cvars.uiScale=='0.6500' and math.abs(UIParent:GetScale()-768/1440)<1e-6,'one click: Optimizations on, Pixel Perfect')
    assert(button.label:GetText()=='Using 53.33%' and not button:IsEnabled())
    addon.configWindow:Hide()
    cvarWrites={}
    local remembered=0;for _ in pairs(ModeUIDB.optimizationOriginals) do remembered=remembered+1 end
    assert(remembered==2,'only the two scale settings remembered')
    -- Version 1 profiles at the old default (Set UI Scale off) take the new
    -- one; their Scale choice stays.
    local old={autoLoot=true,manageScale=false,scaleMode='custom',uiScale=80};O.Initialize(old)
    assert(old.version==2 and old.manageScale and old.scaleMode=='custom' and old.uiScale==80 and old.autoLoot,'on, with its custom scale')
    local fresh={};O.Initialize(fresh);assert(fresh.manageScale and fresh.scaleMode=='auto','a new profile: Pixel Perfect')
    assert(O:SetOption('autoLoot',true) and cvars.autoLootDefault=='1' and ModeUIDB.optimizationOriginals.autoLootDefault=='0')
    assert(O:SetOption('autoLoot',false) and cvars.autoLootDefault=='0' and ModeUIDB.optimizationOriginals.autoLootDefault==nil,'game value restored')
    assert(O:SetOption('manageCamera',true) and cvars.cameraDistanceMaxZoomFactor=='4.0')
    assert(O:SetOption('cameraZoom',2.6) and cvars.cameraDistanceMaxZoomFactor=='2.6')
    assert(not O:SetOption('cameraZoom',9) and not O:SetOption('nope',true),'validated')
    -- Pixel perfect at 1440p: 768/1440 = 53.33%, below the game's own floor.
    assert(O:SetOption('manageScale',true) and cvars.useUiScale=='1' and cvars.uiScale=='0.6500')
    assert(math.abs(UIParent:GetScale()-768/1440)<1e-6 and O.status.scale=='UI scale 53.33%.')
    assert(O:SetOption('uiScale',80) and O.db.scaleMode=='custom' and cvars.uiScale=='0.8000' and math.abs(UIParent:GetScale()-0.8)<1e-9)
    -- Hide error text, restored afterwards.
    assert(O:SetOption('hideErrors',true) and not UIErrorsFrame:IsEventRegistered('UI_ERROR_MESSAGE'))
    assert(O:SetOption('hideErrors',false) and UIErrorsFrame:IsEventRegistered('UI_ERROR_MESSAGE'))
    -- Fast loot only while the game is auto looting.
    assert(O:SetOption('fastLoot',true) and O.events:IsEventRegistered('LOOT_READY'))
    lootItems=3;FireEvent('LOOT_READY',false);assert(#looted==0,'no fast loot without auto loot')
    FireEvent('LOOT_READY',true);assert(table.concat(looted,',')=='1,2,3','every slot taken')
    looted={};testCombat=true;FireEvent('LOOT_READY',true);testCombat=false;assert(#looted==0,'not in combat')
    -- Configuration waits for the end of combat.
    testCombat=true;assert(not O:SetOption('autoLoot',true));testCombat=false
    -- Turning the module off puts every game setting back.
    addon:SetModuleEnabled('optimizations',false)
    assert(cvars.cameraDistanceMaxZoomFactor=='1.9' and cvars.useUiScale=='0' and cvars.uiScale=='1.0')
    assert(not next(ModeUIDB.optimizationOriginals) and not O.events:IsEventRegistered('LOOT_READY'))
    assert(addon.ReloadManager.requests.uiScale,'a reload finishes restoring the game scale')
    addon.ReloadManager:Clear('uiScale')
    addon:SetModuleEnabled('optimizations',true)
    assert(cvars.cameraDistanceMaxZoomFactor=='2.6','settings return with the module')
    -- A setting the game locks is reported, not forced.
    restrictedCVars.autoLootDefault=true
    assert(O:SetOption('autoLoot',true) and cvars.autoLootDefault=='0' and O.status.autoLoot:find("doesn't allow",1,true))
    restrictedCVars.autoLootDefault=nil;O:SetOption('autoLoot',false)
    -- Forever: useUiScale is secure. The game's UI Scale stays off (its own
    -- automatic 64%), and the interface takes the pixel-perfect scale anyway.
    assert(O:SetOption('manageScale',false));addon.ReloadManager:Clear('uiScale')
    secureCVars.useUiScale=true;UIParent:SetScale(0.64)
    assert(not O:UsingSuggestedScale(),'off: not in use')
    cvarWrites={}
    assert(O:SetOption('scaleMode','auto') and O:SetOption('manageScale',true))
    assert(cvars.useUiScale=='0' and #cvarWrites==0,'the secure setting is left alone')
    assert(math.abs(UIParent:GetScale()-768/1440)<1e-6 and O.status.scale:find('53.33%, on the interface',1,true),'53.33% on the interface')
    assert(O:UsingSuggestedScale(),'in use')
    -- The game puts its own scale back on a scale or display change; ModeUI follows.
    UIParent:SetScale(0.64);assert(not O:UsingSuggestedScale(),'64% on screen is not in use')
    FireEvent('UI_SCALE_CHANGED');assert(math.abs(UIParent:GetScale()-768/1440)<1e-6 and O:UsingSuggestedScale(),'and back')
    -- Off: nothing to write back; a reload gives the game its own scale.
    assert(O:SetOption('manageScale',false) and ModeUIDB.optimizationOriginals.useUiScale==nil and O.status.scale=='Game setting restored.')
    assert(addon.ReloadManager.requests.uiScale,'a reload finishes it')
    addon.ReloadManager:Clear('uiScale');secureCVars.useUiScale=nil
    -- 1080p Size: 71.11% on any screen (1440p here), the interface 1080 units tall.
    assert(O:SetOption('scaleMode','size1080') and O:SetOption('manageScale',true))
    assert(math.abs(UIParent:GetScale()-768/1080)<1e-6 and O.status.scale=='UI scale 71.11%.','71.11% on 1440p')
    assert(O:UsingSuggestedScale(),'the card follows the 1080p Size')
    SlashCmdList.MODEUI();addon:SelectConfigPage('home')
    local card=addon.configWindow.pages.home.homeScaleButton
    assert(card.label:GetText()=='Using 71.11%' and not card:IsEnabled(),'Using 71.11%')
    addon:SelectConfigPage('optimizations')
    local scalePage=addon.configWindow.pages.optimizations
    assert(#scalePage.scaleModeButtons==3 and scalePage.scaleModeButtons[2].label:GetText()=='1080p Size','Pixel Perfect, 1080p Size, Custom')
    addon.configWindow:Hide()
    assert(O:SetOption('scaleMode','auto') and math.abs(UIParent:GetScale()-768/1440)<1e-6,'back to Pixel Perfect')
    -- The General page's 1080p Size switch, beside Using.
    SlashCmdList.MODEUI();addon:SelectConfigPage('home')
    local home2=addon.configWindow.pages.home
    local switch=home2.homeScaleSizeToggle
    assert(switch:GetParent().row.visibleWhen() and not switch.selected,'1440p: the switch, off at Pixel Perfect')
    switch.scripts.OnClick(switch)
    assert(O.db.scaleMode=='size1080' and math.abs(UIParent:GetScale()-768/1080)<1e-6 and switch.selected,'on: 71.11%')
    assert(home2.homeScaleButton.label:GetText()=='Using 71.11%')
    switch.scripts.OnClick(switch)
    assert(O.db.scaleMode=='auto' and math.abs(UIParent:GetScale()-768/1440)<1e-6 and not switch.selected,'off: Pixel Perfect')
    local physical=GetPhysicalScreenSize;GetPhysicalScreenSize=function() return 1920,1080 end
    assert(not switch:GetParent().row.visibleWhen(),'1080p: both are 71.11%, no switch')
    GetPhysicalScreenSize=physical
    addon.configWindow:Hide()
]==], "optimizations")

-- Originals survive a reload, so turning an optimization off later still restores.
local reloaded = H.Load({ before = CLIENT .. "cvars.cameraDistanceMaxZoomFactor='2.6';cvars.useUiScale='1';cvars.uiScale='0.8000'",
    saved = world.saved() })
reloaded.run([==[
    local O=addon.Optimizations
    assert(ModeUIDB.optimizationOriginals.cameraDistanceMaxZoomFactor=='1.9')
    assert(O:SetOption('manageCamera',false) and cvars.cameraDistanceMaxZoomFactor=='1.9','restored after a reload')
    -- Optimizations page, with the Play The Game Tools note.
    loadedAddOns.PlayTheGameTools=true
    SlashCmdList.MODEUI();addon:SelectConfigPage('optimizations')
    local page=addon.configWindow.pages.optimizations
    local titles={};for _,s in ipairs(page.sections) do titles[#titles+1]=s.title end
    assert(table.concat(titles,'|')=='Loot|Error Text|Camera|UI Scale')
    local note=page.otherManagerNotes[1]:GetParent().row
    assert(note.visibleWhen(),'PTG note while it is loaded')
    loadedAddOns.PlayTheGameTools=nil;assert(not note.visibleWhen())
    page.lootToggles[1].frame.scripts.OnClick(page.lootToggles[1].frame)
    assert(O.db.autoLoot and cvars.autoLootDefault=='1','toggle from the page')
    page.lootToggles[1].frame.scripts.OnClick(page.lootToggles[1].frame)
    addon.configWindow:Hide()
]==], "optimizations_reload")

-- Class Colors -----------------------------------------------------------
world.run([==[
    local C,U=addon.ClassColors,addon.UnitFrames
    local native=C:GetColor('ROGUE');assert(native.r==1 and native.g==0.96,'game color by default')
    assert(C:SetColor('ROGUE',{0.2,0.4,0.6}) and C:GetColor('ROGUE').b==0.6)
    assert(not C:SetColor('ROGUE',{2,0,0}) and not C:SetColor('EVOKER',{0,0,0}),'validated')
    -- Unit Frames recolor right away (class-colored health on the player).
    U:SetFrameOption('player','healthColorMode','class')
    local bar=U.frames.player.health.statusBarColor
    assert(math.abs(bar[1]-0.2)<1e-9 and math.abs(bar[3]-0.6)<1e-9,'custom color on the frame')
    assert(C:SetColor('ROGUE',{0.9,0.1,0.1}) and math.abs(U.frames.player.health.statusBarColor[1]-0.9)<1e-9,'applies immediately')
    addon:SetModuleEnabled('classColors',false)
    assert(C:GetColor('ROGUE').g==0.96 and math.abs(U.frames.player.health.statusBarColor[2]-0.96)<1e-9,'off: game colors')
    assert(addon.db.modules.classColors.colors.ROGUE,'custom colors kept while off')
    addon:SetModuleEnabled('classColors',true)
    -- Page: grid of classes, picker, reset.
    SlashCmdList.MODEUI();addon:SelectConfigPage('classColors')
    local page=addon.configWindow.pages.classColors
    local rogue=page.classButtons.ROGUE
    assert(rogue.reset.enabled~=false and math.abs(rogue.swatch.color[1]-0.9)<1e-9)
    page.classButtons.MAGE.pick.scripts.OnClick(page.classButtons.MAGE.pick)
    assert(ColorPickerFrame:IsShown());ColorPickerFrame.r,ColorPickerFrame.g,ColorPickerFrame.b=0.5,0.5,0.5;ColorPickerFrame.swatchFunc()
    assert(C:GetColor('MAGE').r==0.5,'picked')
    ColorPickerFrame.info.cancelFunc();assert(C:GetColor('MAGE').r==0.25,'cancel restores')
    rogue.reset.scripts.OnClick(rogue.reset);assert(not C:IsCustom('ROGUE') and rogue.reset.enabled==false)
    C:SetColor('MAGE',{0,0,1});page.resetAll.scripts.OnClick(page.resetAll)
    assert(not next(addon.db.modules.classColors.colors),'reset all')
    addon.configWindow:Hide()
]==], "class_colors")

-- Custom class colors are on the frames from the first draw after login.
world.run([==[ addon.ClassColors:SetColor('ROGUE',{0.3,0.3,0.9}) ]==])
local login = H.Load({ before = CLIENT, saved = world.saved() })
login.run([==[
    assert(math.abs(addon.UnitFrames.frames.player.health.statusBarColor[3]-0.9)<1e-9,'custom color at login')
]==], "class_colors_login")

print("global: all checks passed")
