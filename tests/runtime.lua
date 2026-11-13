-- Shared/Runtime services (Events, Defer, Callbacks, Locale, combat broadcast)
-- and the Shared/Domain readers. Simulated client; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")

local world = H.Load({ before = STUBS })
world.run([==[
    assert(addon.IsPublic(1) and addon.IsNumber(0.5, 0, 1) and not addon.IsNumber(2, 0, 1) and not addon.IsNumber(0/0))

    -- Events: one handler per owner, in subscription order, safe to unsubscribe mid-dispatch.
    local E, seen = addon.Events, {}
    local a, b = {}, {}
    E:On(a, 'TEST_EVENT', function(event, value) seen[#seen + 1] = 'a' .. value; E:Off(a, 'TEST_EVENT') end)
    E:On(b, 'TEST_EVENT', function(event, value) seen[#seen + 1] = 'b' .. value end)
    E:On(b, 'TEST_EVENT', function(event, value) seen[#seen + 1] = 'B' .. value end)
    FireEvent('TEST_EVENT', 1); FireEvent('TEST_EVENT', 2)
    assert(table.concat(seen, ',') == 'a1,B1,B2', 'order, replacement and removal: ' .. table.concat(seen, ','))
    assert(E:IsOn(b, 'TEST_EVENT') and not E:IsOn(a, 'TEST_EVENT'))
    E:OffAll(b)
    assert(not E.frame:IsEventRegistered('TEST_EVENT'), 'the frame lets go of events nobody wants')

    -- Defer: runs now outside combat; in combat the latest task per key waits.
    local D, runs = addon.Defer, {}
    assert(D:Run('now', function() runs[#runs + 1] = 'now' end) and runs[1] == 'now')
    testCombat = true
    assert(not D:Run('x', function() runs[#runs + 1] = 'x1' end))
    D:Run('y', function() runs[#runs + 1] = 'y' end)
    D:Run('x', function() runs[#runs + 1] = 'x2' end)
    D:Queue('gone', function() runs[#runs + 1] = 'gone' end); D:Cancel('gone')
    assert(D:IsQueued('x') and #runs == 1)
    testCombat = false
    FireEvent('PLAYER_REGEN_ENABLED')
    assert(table.concat(runs, ',') == 'now,x2,y', 'queue order: ' .. table.concat(runs, ','))
    assert(not D:IsQueued('x'))

    -- Callbacks: ModeUI_ messages only.
    local heard
    addon.RegisterMessage('runtime test', 'ModeUI_Test', function(message, value) heard = message .. value end)
    addon:SendMessage('ModeUI_Test', 7)
    assert(heard == 'ModeUI_Test7')
    assert(not pcall(addon.SendMessage, addon, 'Other'), 'message names are namespaced')

    -- Locale: English falls back; only the client's language is applied.
    local L = addon.L
    assert(L['Unit Frames'] == 'Unit Frames')
    assert(not addon:RegisterLocale('deDE', { ['Unit Frames'] = 'Einheitenfenster' }) and L['Unit Frames'] == 'Unit Frames')
    assert(addon:RegisterLocale('enUS', { ['Global'] = 'Global' }) and rawget(L, 'Global') == 'Global')

    -- Switching a module sends MODULE_TOGGLED.
    local toggled
    addon.RegisterMessage('runtime test', addon.Messages.MODULE_TOGGLED, function(_, id, on) toggled = id .. tostring(on) end)
    addon:SetModuleEnabled('unitFrames', false)
    assert(toggled == 'unitFramesfalse')
    addon:SetModuleEnabled('unitFrames', true)

    -- Media changes during combat wait for one refresh afterwards.
    local M, refreshed = addon.Media, 0
    M:RegisterBorderListener({}, function() refreshed = refreshed + 1 end)
    testCombat = true
    M:RefreshBorders()
    assert(refreshed == 0 and M.borderPending and D:IsQueued('media'))
    testCombat = false
    FireEvent('PLAYER_REGEN_ENABLED')
    assert(refreshed == 1 and not M.borderPending and not M.pending)

    -- Domain: guarded calls treat secret or failed answers as unknown.
    local Q, D2 = addon.Domain.Query, addon.Domain
    local secret = { secret = true }
    assert(Q.Truthy(function() return true end) and not Q.Truthy(function() return secret end) and not Q.Truthy(nil))
    assert(Q.Plain(function() return 1, secret end) == nil and Q.Plain(function() return 1, 2 end) == 1)
    assert(not Q.Call(function() error('boom') end))
    local level, classification = 60, 'elite'
    local savedLevel, savedClass = UnitLevel, UnitClassification
    UnitLevel = function() return level end; UnitClassification = function() return classification end
    assert(D2.Level.Text('target') == '60+')
    level, classification = -1, 'normal'; assert(D2.Level.Text('target') == '??')
    level = secret; assert(D2.Level.Text('target') == '', 'a secret level shows nothing')
    UnitLevel, UnitClassification = savedLevel, savedClass
    assert(D2.Power.Color('RAGE')[1] == 0.86 and D2.Power.Color(nil) == D2.Power.defaultColor)
    -- Class colors: a module's override wins, the game's color otherwise.
    local UC = D2.UnitColor
    local before = UC.override
    UC.SetClassOverride(function(class) if class == 'MAGE' then return { r = 1, g = 0, b = 0 } end end)
    assert(UC.Class('MAGE').r == 1 and UC.Class('DRUID').r == UC.NativeClass('DRUID').r)
    UC.SetClassOverride(before)

    -- Combat start and end reach enabled modules.
    local states = {}
    addon.modules.unitFrames.OnCombatStateChanged = function(_, inCombat) states[#states + 1] = inCombat end
    testCombat = true; FireEvent('PLAYER_REGEN_DISABLED')
    testCombat = false; FireEvent('PLAYER_REGEN_ENABLED')
    assert(states[1] == true and states[2] == false)
]==], "runtime")
print("runtime: all checks passed")
