-- ModeUI startup, Mode-themed window, one Interface > Unit Frames page,
-- settings restoration and the one-time Play The Game Tools import; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")

local metadata = H.Toc()
assert(metadata.SavedVariables == "ModeUIDB", "own SavedVariables")
assert(metadata["X-ModeUI-Edition"] == "Forever" and metadata.Interface == "16001")

local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")
local world = H.Load({ before = STUBS })
world.run([[
    assert(addon.initialized and #addon.moduleOrder==1 and addon.moduleOrder[1]=='unitFrames')
    assert(#addon.categoryOrder==1 and addon.categoryOrder[1]=='interface' and addon.categories.interface.title=='Interface')
    assert(addon.InterfaceTheme.id=='mode' and not addon.InterfaceTheme.blizzardArt,'Mode theme only')
    assert(addon.InterfaceTheme.primary[2]==240/255,'Mode cyan accent')
    assert(SLASH_MODEUI1=='/modeui' and SLASH_PLAYTHEGAMETOOLS1==nil)
    assert(addon.modules.unitFrames.enabled,'unit frames are on for a fresh install')
    assert(ModeUIDB.importedFrom=='none','nothing to import without Play The Game Tools')
    assert(messages[1]:find('ModeUI',1,true),'welcome line')
    SlashCmdList.MODEUI()
    local window=addon.configWindow
    assert(window:IsShown() and window.title:GetText()=='ModeUI' and window.brandLogo,'Mode brand header')
    assert(window.moduleHeader.title:GetText()=='Unit Frames','opens on Interface > Unit Frames')
    assert(window.selectedCategory=='interface' and window.pages.unitFrames:IsShown())
    assert(window.navigationButtons.interface.label:GetText()=='Interface','Interface category heading')
    assert(window.navigationButtons.dashboard==nil and window.navigationButtons.globalSettings==nil,'no Dashboard or Global Settings')
    assert(window.profileButton==nil,'no profile button')
    local nested=window.sidebarModuleButtons.unitFrames
    assert(nested and nested:IsShown() and nested.label:GetText()=='· Unit Frames','Unit Frames nested under Interface')
    local count=0;for _ in pairs(window.sidebarModuleButtons) do count=count+1 end
    assert(count==1,'one module in the sidebar')
    -- Edit Mode opens the ModeUI edit panel with the frames as movable elements.
    assert(addon:SetEditMode(true) and addon.editWindow:IsShown() and not window:IsShown())
    assert(addon.PositionManager.elements.unitFramesPlayer and addon.PositionManager.elements.unitFramesTarget)
    assert(addon:SetEditMode(false) and window:IsShown())
    window:Hide()
    addon.db.window.x=123;addon.db.window.y=45
    addon:SetModuleEnabled('unitFrames',false)
]], "smoke")

local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([[
    assert(addon.db.window.x==123 and addon.db.window.y==45,'window position persists')
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
    assert(M.db.layoutVersion==11 and M.db.player.nameColorMode=='sky','migrated to the current layout')
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
