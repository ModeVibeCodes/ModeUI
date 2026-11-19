-- Built-in layouts (Shared/Runtime/Layouts.lua): Mode-Default (DPS / Tank)
-- builds a valid profile at 1080 and 1440 from every module's part, becomes
-- its own profile once per account at login (never made active), and ModeUI
-- starts with it once the player switches to it. Each module's own test
-- checks its values; this one checks the whole. Simulated client; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/action_bar_stubs.lua")

local world = H.Load({ before = STUBS })
world.run([==[
    local L, P = addon.Layouts, addon.Profiles
    local spec = assert(L:Get('mode-default'))
    assert(spec.label == 'DPS / Tank' and spec.profileName == 'Mode-Default' and spec.seed, 'the DPS / Tank layout')
    local MODULES = { 'actionBars', 'buffsDebuffs', 'cooldownManager', 'damageMeters', 'minimap', 'partyFrames', 'unitFrames' }
    local parts = {}
    for _, part in ipairs(L.parts['mode-default']) do parts[#parts + 1] = part.module end
    table.sort(parts)
    assert(table.concat(parts, ',') == table.concat(MODULES, ','), 'every part: ' .. table.concat(parts, ','))
    -- The UI height picks the places: 1440's from 1260 up.
    assert(L.Variant(1080) == '1080' and L.Variant(1200) == '1080' and L.Variant(1440) == '1440' and L.Variant(1600) == '1440'
        and L.Variant(nil) == '1080', 'variants')
    local targets = { screen = true }
    for _, item in ipairs(addon.Positioning.targets) do targets[item.id] = true end
    for _, variant in ipairs({ '1080', '1440' }) do
        local profile = assert(L:Build('mode-default', variant))
        for _, id in ipairs(MODULES) do assert(profile.modules[id].enabled == true, id .. ' on: ' .. variant) end
        -- Chat keeps Blizzard's Edit Mode place (not in the layout).
        for id, position in pairs(profile.positions) do
            assert(targets[position.target], id .. ' hangs from ' .. tostring(position.target) .. ', which is no target')
        end
        -- The center block: 300 above the bottom at 1080, 325 at 1440.
        local y = variant == '1440' and 325 or 300
        for _, id in ipairs({ 'cooldownManagerEssential', 'unitFramesPlayer', 'unitFramesTarget' }) do
            local p = profile.positions[id]
            assert(p.target == 'screen' and p.relativePoint == 'BOTTOM' and p.y == y, id .. ' at ' .. y)
        end
        assert(profile.positions.unitFramesPlayer.x == -256 and profile.positions.unitFramesTarget.x == 256, 'frames either side: ' .. tostring(profile.positions.unitFramesPlayer.x))
        -- Every module on (allModules), Profiles always on.
        for id, module in pairs(addon.modules) do
            local db = profile.modules[id]
            if db and db.enabled ~= nil and not module.alwaysOn then assert(db.enabled == true, id .. ' on: ' .. variant) end
        end
        -- What the places count on (owner's tuning, November 18, 2026): Essential
        -- is 288 wide with its edges, so the frames' bands sit 10 from its band;
        -- the Player frame is 206 x 46 (Portrait Size 145) with its 32px bar
        -- block, 34 with its shadow as an Essential icon is with its edge.
        local cdm, uf = profile.modules.cooldownManager, profile.modules.unitFrames
        local essential = addon.CooldownManager.Geometry(cdm.essential, 1, 1)
        assert(essential.width == 288 and essential.reach == 2, 'Essential 288 wide')
        local g = addon.UnitFrames:Geometry(uf.player, 1, addon.Style.EdgeDepth('frame'))
        assert(uf.player.portraitScale == 145 and g.width == 206 and g.height == 46 and g.blockHeight == 32, 'Player 206 x 46')
        assert(g.blockHeight + 2 == essential.h + 2 * essential.reach, 'as tall as an Essential icon')
        assert(256 - 206 / 2 - (288 / 2 - 1) == 10, '10px between the bands')
        -- Defensive Cooldowns and Player Buffs hang from the bar block (owner,
        -- November 18, 2026: they clipped the frame once Portrait Size changed).
        local function On(id, target, point, relative, x, y)
            local p = profile.positions[id]
            assert(p and p.target == target and p.point == point and p.relativePoint == relative and p.x == x and p.y == y, id)
        end
        local defensives
        for _, bar in ipairs(cdm.customBars) do if bar.preset == 'defensives' then defensives = bar.id end end
        On(addon.CooldownManager.ElementId(defensives), 'unitFramesPlayerBars', 'BOTTOMRIGHT', 'TOPRIGHT', 1, 0)
        On(addon.BuffsDebuffs.ElementId('playerBuffs'), 'unitFramesPlayerBars', 'TOPRIGHT', 'BOTTOMRIGHT', 0, -1)
        -- At any Portrait Size and Health Height, at Frame Width 161 and up (five
        -- 30px buffs, 154 wide, need that much beside the ring; the layout uses 166),
        -- neither touches the portrait ring (its disc and shadow) nor the block.
        local BD = addon.BuffsDebuffs
        local buffW, buffH = BD:BarSize(profile.modules.buffsDebuffs.bars.playerBuffs, 1)
        local dg = addon.CooldownManager.Geometry(cdm[defensives], 6, 1)
        local defW, defH = dg.extent.width, dg.extent.height
        local function Clear(l, t, r, b, cx, cy, radius)
            local nx, ny = math.max(l, math.min(cx, r)), math.max(t, math.min(cy, b))
            return (nx - cx) ^ 2 + (ny - cy) ^ 2 >= radius ^ 2
        end
        for scale = 100, 200, 5 do
            for health = 10, 60, 2 do
                for width = 161, 260, 3 do
                    local fdb = setmetatable({ portraitScale = scale, healthHeight = health, barWidth = width }, { __index = uf.player })
                    local fg = addon.UnitFrames:Geometry(fdb, 1, addon.Style.EdgeDepth('frame'))
                    local top, bottom, right = fg.blockY, fg.blockY + fg.blockHeight, fg.width
                    local cx, cy, radius = fg.portrait / 2, fg.height / 2, fg.portrait / 2 + 1
                    -- Frame coordinates, y down; each rect with its icons' 1px shadow.
                    local case = scale .. '% ' .. health .. 'h ' .. width .. 'w'
                    assert(Clear(right - buffW - 1, bottom, right + 1, bottom + 2 + buffH, cx, cy, radius), 'Player Buffs clear of the ring: ' .. case)
                    assert(Clear(right + 2 - defW, top - defH, right + 2, top, cx, cy, radius), 'Defensive Cooldowns clear of the ring: ' .. case)
                end
            end
        end
        -- Minimap and meters show exactly as wide (the minimap's edge sits outside it).
        assert(profile.modules.damageMeters.window1.width == profile.modules.minimap.size + 2 * addon.Style.EdgeReach('frame'),
            'minimap as wide as the meters')
        -- The five default bars are in it.
        local tags = {}
        for _, bar in ipairs(profile.modules.cooldownManager.customBars) do if bar.preset then tags[#tags + 1] = bar.preset end end
        assert(#tags == 5, 'five default bars')
    end
    assert(not L:Build('nope'), 'unknown layout')
    -- Made into a profile once, at login; the active profile stays.
    assert(P:Exists('Mode-Default') and P:Active() == 'Default' and ModeUIDB.builtLayouts['mode-default'] == true, 'Mode-Default made')
    assert(not P:CreateFromLayout('Mode-Default', 'mode-default'), 'its name is taken')
    assert(not P:CreateFromLayout('Other', 'nope') and not P:Exists('Other'), 'unknown layout refused')
    assert(P:CreateFromLayout('Raid Copy', 'mode-default') and P:Exists('Raid Copy'), 'another profile from it')
    assert(P:Delete('Mode-Default'))
]==], "build")

-- Deleted, it stays deleted: the layout became a profile once per account.
H.Load({ before = STUBS, saved = world.saved() }).run([==[
    assert(not addon.Profiles:Exists('Mode-Default') and addon.Profiles:Exists('Raid Copy'), 'made once per account')
]==], "once")

-- Switched to it (applies on reload), ModeUI starts with every module of the layout.
local switching = H.Load({ before = STUBS })
-- Party Frames' secure group header needs tests/party_frames.lua's client, which
-- runs its part of the layout; here it stays off.
switching.run([==[
    assert(addon.Profiles:Select('Mode-Default'))
    ModeUIDB.profiles['Mode-Default'].modules.partyFrames.enabled = false
]==], "select")
H.Load({ before = STUBS, saved = switching.saved() }).run([==[
    assert(ModeUIDB.activeProfile == 'Mode-Default', 'switched')
    for _, id in ipairs({ 'actionBars', 'buffsDebuffs', 'cooldownManager', 'damageMeters', 'minimap', 'unitFrames' }) do
        assert(addon.modules[id].enabled, id .. ' started')
    end
    local essential = addon.PositionManager:GetPosition('cooldownManagerEssential')
    assert(essential and essential.target == 'screen' and essential.y == 300, 'its places in use')
]==], "in use")

print("layouts: all checks passed")
