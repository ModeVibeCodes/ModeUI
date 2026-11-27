-- ModeCDM per spec (owner, November 26, 2026): each specialization keeps
-- which spells sit on which bar, the viewers' spell order and where every
-- ModeCDM bar sits; a spec change puts one away and brings the other back.
-- Simulated client; not WoW rendering, security or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/cooldown_manager_stubs.lua") .. [[
    specIndex = 1
    local specIDs = { 259, 260 }
    C_SpecializationInfo = { GetSpecialization = function() return specIndex end }
    GetSpecializationInfo = function(index) return specIDs[index] end
    function SwitchSpec(index, essential)
        specIndex = index
        EssentialCooldownViewer.ids = essential
        EssentialCooldownViewer:RefreshLayout()
        FireEvent('PLAYER_SPECIALIZATION_CHANGED', 'player')
    end
]]

local world = H.Load({ before = STUBS .. "\nMakeViewers()" })
world.run([==[
    local M, PM = addon.CooldownManager, addon.PositionManager
    addon:SetModuleEnabled('cooldownManager', true)
    FireEvent('PLAYER_ENTERING_WORLD')
    assert(M.db.activeSpec == 259 and next(M.db.specs) == nil, 'the first spec keeps the live setup')
    local E = M.ElementId('essential')
    local function Place(x) assert(PM:SetPosition(E, { target = 'screen', placement = 'center', x = x, y = 20 })) end
    local function Keys(id) local list = {}; for _, entry in ipairs(M:PreviewEntries(id)) do list[#list + 1] = entry.key end; return table.concat(list, ',') end

    -- Spec one: a spell on a custom bar, Essential reordered, Essential moved.
    local bar = M:AddCustomBar('cooldown')
    assert(M:AddEntry(bar, '103') and M:MoveSpell('essential', '105', 1))
    Place(40)
    assert(Keys('essential') == '105,101,102,104' and M:Entries(bar)[1] == '103', 'set up in spec one')

    -- Spec two, never played: it starts from spec one's setup.
    SwitchSpec(2, { 101, 102, 103, 104, 105 })
    assert(M.db.activeSpec == 260 and M.db.specs['259'] and M.db.specs['260'] == nil, 'spec one put away')
    assert(M:Entries(bar)[1] == '103' and PM:GetPosition(E).x == 40, 'spec two starts from it')
    -- Spec two's own changes leave spec one's alone.
    assert(M:RemoveEntry(bar, '103') and M:MoveSpell('essential', '102', 1))
    Place(-60)
    assert(#M:Entries(bar) == 0 and Keys('essential'):sub(1, 3) == '102', 'set up in spec two')

    -- Back to spec one: its spells, order and place.
    SwitchSpec(1, { 101, 102, 103, 104, 105 })
    assert(M.db.activeSpec == 259 and M.db.specs['259'] == nil and M.db.specs['260'], 'spec two put away')
    assert(M:Entries(bar)[1] == '103' and Keys('essential') == '105,101,102,104', "spec one's spells and order")
    assert(PM:GetPosition(E).x == 40 and addon.db.positions[E].x == 40, "spec one's place")
    local frame = PM:Element(E).frame
    local _, _, _, x = frame:GetPoint(1)
    assert(math.abs(x - 40) < 0.01, 'the bar itself moved back')

    -- And spec two again.
    SwitchSpec(2, { 101, 102, 103, 104, 105 })
    assert(#M:Entries(bar) == 0 and Keys('essential'):sub(1, 3) == '102' and PM:GetPosition(E).x == -60, "spec two's setup")

    -- The same spec again changes nothing; nothing changes in combat.
    assert(not M:SyncSpec(), 'same spec: no change')
    testLockdown = true; specIndex = 1
    assert(not M:SyncSpec() and M.db.activeSpec == 260, 'not in combat')
    testLockdown = false; FireEvent('PLAYER_REGEN_ENABLED')
    assert(M.db.activeSpec == 259 and M:Entries(bar)[1] == '103', 'after combat')

    -- A deleted bar leaves every spec's setup.
    assert(M.db.specs['260'].entries[bar] and M:DeleteCustomBar(bar))
    assert(M.db.specs['260'].entries[bar] == nil and M.db.specs['260'].positions[M.ElementId(bar)] == nil, 'forgotten in spec two')
]==], "cdm specs")

-- Saved and loaded again; bad setups stop startup rather than being reset.
local saved = world.saved()
assert(pcall(H.Load, { before = STUBS, saved = saved }), 'spec setups load again')
local function Refused(change, label)
    local copy = world.saved()
    change(copy.profiles.Default.modules.cooldownManager)
    assert(not pcall(H.Load, { before = STUBS, saved = copy }), "invalid spec setups are refused: " .. label)
end
Refused(function(db) db.specs = { ['260'] = { colors = {} } } end, "an unknown part")
Refused(function(db) db.specs = { spec = {} } end, "a spec that isn't an ID")
Refused(function(db) db.specs['260'].order = { nowhere = { '101' } } end, "a viewer")
Refused(function(db) db.specs['260'].positions = { cooldownManagerEssential = { x = 'far' } } end, "a position")
Refused(function(db) db.activeSpec = 'Assassination' end, "the active spec")
print("cdm specs: ok")
