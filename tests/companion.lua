-- Companion addons (docs/ARCHITECTURE.md, "Companion addons"): ModeCDM runs
-- the Cooldown Manager inside ModeUI's addon table. ModeUI alone keeps the
-- Cooldown Manager's saved settings untouched; ModeCDM loading after ModeUI
-- has started registers late, checks and migrates its settings, and starts;
-- ModeUI-Core hands its addon table only to the companions it lists.
-- Simulated client; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/cooldown_manager_stubs.lua")

-- With ModeCDM loaded alongside: on, with a custom bar and a size of its own.
local first = H.Load({ before = STUBS .. "\nMakeViewers()" })
first.run([==[
    local M = addon.CooldownManager
    assert(M and M.companion == 'ModeCDM' and addon.modules.cooldownManager == M, 'the module comes from ModeCDM')
    assert(LibStub('ModeUI-Core').Companion('ModeCDM') == addon, "ModeCDM gets ModeUI's addon table")
    assert(LibStub('ModeUI-Core').Companion('SomethingElse') == nil and LibStub('ModeUI-Core').Companion() == nil, 'nobody else does')
    addon:SetModuleEnabled('cooldownManager', true)
    assert(M:AddCustomBar('cooldown') == 'custom1' and M:SetOption('essential', 'width', 50))
    assert(SLASH_MODEUICDM1 == '/mcdm')
]==], "with ModeCDM")
local saved = first.saved()

-- ModeUI alone: the Cooldown Manager's settings and places stay as they were.
local alone = H.Load({ before = STUBS, saved = saved, companions = false })
alone.run([==[
    assert(addon.initialized and addon.modules.cooldownManager == nil and addon.CooldownManager == nil, 'no Cooldown Manager without ModeCDM')
    local kept = addon.db.modules.cooldownManager
    assert(kept and kept.enabled == true and kept.essential.width == 50 and #kept.customBars == 1, 'its settings kept, untouched')
    assert(addon.db.positions.cooldownManagerCustom1 ~= nil, 'its places kept')
    assert(SLASH_MODEUICDM1 == nil, 'no /mcdm')
]==], "ModeUI alone")
local afterAlone = alone.saved()

-- ModeCDM after ModeUI's start (version 4 settings): registered late, then
-- migrated and started from Start.lua; on, as saved.
local old = afterAlone.profiles.Default.modules.cooldownManager
old.version, old.essential.fontMedia, old.essential.width, old.essential.height = 4, "Expressway", 42, 34
local late = H.Load({ before = STUBS .. "\nMakeViewers()", saved = afterAlone, lateCompanions = true })
late.run([==[
    local M = addon.CooldownManager
    assert(M and addon.moduleOrder[#addon.moduleOrder] == 'cooldownManager' and #addon.lateModules == 0, 'registered late, started')
    assert(M.db == addon.db.modules.cooldownManager and M.db.version == M.VERSION, 'settings checked and migrated')
    assert(M.db.essential.fontMedia == 'Mode' and M.db.essential.width == 40 and #M.db.customBars == 1, 'old defaults moved, choices kept')
    assert(M.enabled and M.active and M.built and ModeUICooldownEssential and ModeUICooldownCustom1, 'on, as saved')
    assert(Point(ItemsOf(EssentialCooldownViewer)[1])[2] == M.holders.essential, "Blizzard's icons on ModeUI's bars")
    assert(SLASH_MODEUICDM1 == '/mcdm')
    -- A profile switch or import checks the companion's settings like any module's.
    local profile = assert(addon.Database:ValidateProfile(addon.db))
    assert(profile.modules.cooldownManager.version == M.VERSION)
]==], "late ModeCDM")

-- Bad saved data stops ModeCDM with an error from its Start.lua (ModeUI has
-- already started by then); nothing is reset.
local bad = late.saved()
bad.profiles.Default.modules.cooldownManager.essential.width = 900
local ok = pcall(H.Load, { before = STUBS, saved = bad, lateCompanions = true })
assert(not ok, 'bad Cooldown Manager settings are refused, not reset')
print("companion: all checks passed")
