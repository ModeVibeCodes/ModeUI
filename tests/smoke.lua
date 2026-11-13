-- ModeUI startup, Mode-themed window with Interface and Global categories,
-- settings restoration and the one-time Play The Game Tools import; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")

local metadata = H.Toc()
assert(metadata.SavedVariables == "ModeUIDB", "own SavedVariables")
assert(metadata["X-ModeUI-Edition"] == "Forever" and metadata.Interface == "16001")

local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")
local world = H.Load({ before = STUBS })
world.run([[
    assert(addon.initialized and table.concat(addon.moduleOrder,',')=='unitFrames,nameplates,actionBars,profiles,optimizations,classColors')
    assert(table.concat(addon.categoryOrder,',')=='interface,global' and addon.categories.interface.title=='Interface' and addon.categories.global.title=='Global')
    assert(table.concat(addon.categories.global.modules,',')=='profiles,optimizations,classColors')
    assert(addon.InterfaceTheme.id=='mode' and not addon.InterfaceTheme.blizzardArt,'Mode theme only')
    assert(addon.InterfaceTheme.primary[2]==240/255,'Mode cyan accent')
    assert(SLASH_MODEUI1=='/modeui' and SLASH_PLAYTHEGAMETOOLS1==nil)
    assert(addon.modules.unitFrames.enabled,'unit frames are on for a fresh install')
    assert(not addon.modules.nameplates.enabled,'nameplates start off')
    assert(not addon.modules.actionBars.enabled,'action bars start off')
    assert(ModeUIDB.importedFrom=='none','nothing to import without Play The Game Tools')
    assert(ModeUIDB.schemaVersion==2 and ModeUIDB.activeProfile=='Default' and ModeUIDB.profiles.Default==addon.db,'Default profile')
    assert(messages[1]:find('ModeUI',1,true),'welcome line')
    -- Settings are built on demand: no window or page until the user opens one.
    assert(addon.configWindow==nil,'settings window waits for /modeui')
    SlashCmdList.MODEUI()
    local window=addon.configWindow
    assert(window:IsShown() and window.title:GetText()=='ModeUI' and window.brandLogo,'Mode brand header')
    assert(window.moduleHeader.title:GetText()=='Unit Frames','opens on Interface > Unit Frames')
    assert(window.selectedCategory=='interface' and window.pages.unitFrames:IsShown())
    assert(window.navigationButtons.interface.label:GetText()=='INTERFACE' and window.navigationButtons.global.label:GetText()=='GLOBAL','category headings (uppercase captions)')
    assert(window.navigationButtons.dashboard==nil and window.navigationButtons.globalSettings==nil,'no Dashboard or Global Settings')
    assert(window.profileButton==nil,'no profile button')
    local nested=window.sidebarModuleButtons.unitFrames
    assert(nested and nested:IsShown() and nested.label:GetText()=='· Unit Frames','Unit Frames nested under Interface')
    local count=0;for _ in pairs(window.sidebarModuleButtons) do count=count+1 end
    assert(count==6,'six pages in the sidebar')
    assert(window.sidebarModuleButtons.nameplates:IsShown(),'Nameplates nested under Interface')
    addon:SelectConfigPage('nameplates');assert(window.pages.nameplates:IsShown() and window.moduleHeader.title:GetText()=='Nameplates')
    assert(window.sidebarModuleButtons.actionBars:IsShown(),'Action Bars nested under Interface')
    addon:SelectConfigPage('actionBars');assert(window.pages.actionBars:IsShown() and window.moduleHeader.title:GetText()=='Action Bars')
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
    assert(M.db.layoutVersion==14 and M.db.player.nameColorMode=='sky','migrated to the current layout')
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
