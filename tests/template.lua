-- docs/module-template runs as a real module: registration, saved settings,
-- lifecycle, events, combat deferral and its on-demand settings page.
-- Simulated client; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")

-- Load the template's files in the order its XML lists them.
local xml = H.Read(H.root .. "docs/module-template/Example.xml")
local files = {}
for file in xml:gmatch('<Script file="([^"]+)"/>') do files[#files + 1] = "docs/module-template/" .. file end
assert(files[1]:match("Init.lua$") and #files == 3, "template XML loads Init, Driver, Settings")

local world = H.Load({ before = STUBS, files = files })
world.run([==[
    local M = addon.Example
    assert(M and addon.modules.example == M and M.category == 'interface' and not M.enabled, 'registered, off by default')
    assert(addon.categories.interface.modules[#addon.categories.interface.modules] == 'example')
    assert(M.db.showTarget == true and M.db.scale == 100 and M.frame == nil, 'defaults filled, nothing built while off')
    assert(not addon.Events:IsOn(M, 'PLAYER_TARGET_CHANGED'))

    addon:SetModuleEnabled('example', true)
    assert(M.enabled and M.frame and M.frame:IsShown(), 'built on first enable')
    assert(addon.Events:IsOn(M, 'PLAYER_TARGET_CHANGED'))
    FireEvent('PLAYER_TARGET_CHANGED')

    assert(not M:SetOption('scale', 500) and M.db.scale == 100, 'out-of-range values are refused')
    assert(M:SetOption('scale', 150) and M.frame:GetScale() == 1.5)
    testCombat = true
    assert(not M:SetOption('scale', 120), 'no settings changes in combat')
    M.db.scale = 120; M:Refresh()
    assert(M.frame:GetScale() == 1.5 and addon.Defer:IsQueued('example:refresh'), 'frame changes wait for combat to end')
    testCombat = false
    FireEvent('PLAYER_REGEN_ENABLED')
    assert(M.frame:GetScale() == 1.2)

    -- The page exists only once the window opens it.
    SlashCmdList.MODEUI()
    local window = addon.configWindow
    assert(window.pages.example == nil, 'page built on demand')
    addon:SelectConfigPage('example')
    local page = window.pages.example
    assert(page and page:IsShown() and page.scaleSlider and window.moduleHeader.title:GetText() == 'Example')
    window:Hide()

    addon:SetModuleEnabled('example', false)
    assert(not M.frame:IsShown() and not addon.Events:IsOn(M, 'PLAYER_TARGET_CHANGED'), 'off releases events and hides')
]==], "template")

local restored = H.Load({ before = STUBS, files = files, saved = world.saved() })
restored.run([==[
    local M = addon.Example
    assert(not M.enabled and M.db.scale == 120 and M.frame == nil, 'settings persist; still nothing built while off')
]==], "template_restore")
print("template: all checks passed")
