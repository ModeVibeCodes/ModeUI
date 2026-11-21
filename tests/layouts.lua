-- Built-in layouts (Shared/Runtime/Layouts.lua): Mode-DPS/TANK (DPS / Tank)
-- builds a valid profile at 1080 and 1440 from every module's part, in
-- Mode-Obsidian, becomes its own profile once per seed at login (never made
-- active; an earlier seed's profile of the same name is kept as "(old)"), and
-- ModeUI starts with it once the player switches to it. Each module's own test
-- checks its values; this one checks the whole. Simulated client; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/action_bar_stubs.lua")

local world = H.Load({ before = STUBS })
world.run([==[
    local L, P = addon.Layouts, addon.Profiles
    local spec = assert(L:Get('mode-default'))
    assert(spec.label == 'DPS / Tank' and spec.profileName == 'Mode-DPS/TANK' and spec.seed == 'mode-default@4', 'the DPS / Tank layout')
    local MODULES = { 'actionBars', 'bags', 'buffsDebuffs', 'cooldownManager', 'damageMeters', 'minimap', 'nameplates', 'partyFrames', 'tooltip', 'unitFrames' }
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
        -- The Mode-Obsidian look (owner, November 20, 2026): every module's
        -- theme part ran after the layout's; frames in Mode-Border in its own
        -- metal, dark health in Mode-FG over Mode-BG; the Cooldown Manager's
        -- icons in Mode-Empty with a neutral, darker rim.
        assert(profile.theme == 'obsidian' and profile.look == 1, 'Mode-Obsidian')
        for id in pairs(profile.modules) do
            assert(not addon.Themes.parts.obsidian[id] or profile.themeParts[id] == 'obsidian', id .. ': its theme part ran')
        end
        assert(uf.player.edgeStyle == 'obsidian' and uf.player.edgeMetal == 'default' and uf.player.healthColorMode == 'default'
            and uf.player.foregroundTexture == 'media:Mode-FG' and uf.player.backgroundTexture == 'media:Mode-BG', 'Unit Frames in Mode-Obsidian')
        for _, viewer in ipairs({ 'essential', 'utility', 'buffIcon', 'buffBar' }) do
            local style = cdm[viewer]
            assert(style.edgeStyle == 'obsidianEmpty' and style.edgeMetal == 'default' and addon.Style.SameColor(style.edgeColor, addon.Style.Tone.emptyRim)
                and addon.Style.IsFlatStyle(style.edgeStyle), viewer .. ': Mode-Empty, neutral and darker')
        end
        for _, bar in ipairs(cdm.customBars) do assert(cdm[bar.id].edgeStyle == 'obsidianEmpty', bar.id .. ': Mode-Empty') end
        assert(profile.modules.partyFrames.dispelFrom == 'bottom' and profile.modules.nameplates.enemy.backgroundTexture == 'media:Mode-BG', 'Party Frames and Nameplates in Mode-Obsidian')
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
        -- The tooltip left of the meters, its bottom on Damage Done's, 4 apart;
        -- the bag window's bottom-right corner on Healing Done's top-left, 4
        -- apart each way (owner, November 20, 2026).
        local tip, bags = profile.positions.modeTooltip, profile.positions.modeBags
        assert(tip.target == 'damageMetersWindow1' and tip.point == 'BOTTOMRIGHT' and tip.relativePoint == 'BOTTOMLEFT' and tip.x == -4 and tip.y == 0, 'tooltip by the meters')
        assert(profile.modules.tooltip.position == 'anchor' and profile.modules.tooltip.anchorPoint == 'BOTTOMRIGHT', 'the tooltip grows away from the meters')
        assert(bags.target == 'damageMetersWindow2' and bags.point == 'BOTTOMRIGHT' and bags.relativePoint == 'TOPLEFT' and bags.x == -4 and bags.y == 4, 'bags on the top meter')
        assert(profile.modules.bags.growFrom == 'BOTTOMRIGHT', 'the bag window grows away from the meters')
        assert(uf.totems.attach == 'below' and uf.totems.size == 24, 'totem timers under the Player frame')
        -- Tracked Bars under Utility (their stand-in covered the Target frame);
        -- resource texts that fit their bars.
        local tracked = profile.positions.cooldownManagerBuffBar
        assert(tracked and tracked.target == 'cooldownManagerUtility' and tracked.point == 'TOP' and tracked.relativePoint == 'BOTTOM' and tracked.y == -4, 'Tracked Bars under Utility')
        assert(cdm.resources.power.textSize == 9 and cdm.resources.power.textSize < cdm.resources.power.height and not cdm.resources.combo.textShow, 'texts fit their bars')
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
    assert(P:Exists('Mode-DPS/TANK') and P:Active() == 'Default' and ModeUIDB.builtLayouts['mode-default@4'] == true, 'Mode-DPS/TANK made')
    assert(ModeUIDB.profiles['Mode-DPS/TANK'].theme == 'obsidian', 'in Mode-Obsidian')
    assert(not P:CreateFromLayout('Mode-DPS/TANK', 'mode-default'), 'its name is taken')
    assert(not P:CreateFromLayout('Other', 'nope') and not P:Exists('Other'), 'unknown layout refused')
    assert(P:CreateFromLayout('Raid Copy', 'mode-default') and P:Exists('Raid Copy'), 'another profile from it')
    assert(P:Delete('Mode-DPS/TANK'))
]==], "build")

-- Deleted, it stays deleted: the layout became a profile once per account.
H.Load({ before = STUBS, saved = world.saved() }).run([==[
    assert(not addon.Profiles:Exists('Mode-DPS/TANK') and addon.Profiles:Exists('Raid Copy'), 'made once per account')
]==], "once")

-- An account the first seeds reached (November 18-19, 2026: Mode-Default and
-- Mode-Healer, in Mode-Blizz) gets the new ones: Mode-DPS/TANK beside the old
-- Mode-Default, and the old Mode-Healer kept as "Mode-Healer (old)" (still the
-- active profile if it was) beside the new one. Every profile is Mode-Obsidian.
local before = H.Load({ before = STUBS }).saved()
before.builtLayouts = { ['mode-default'] = true, healer = true }
before.profiles['Mode-DPS/TANK'] = nil
before.profiles['Mine'] = { modules = { unitFrames = { player = { barWidth = 150 } } } }
before.profiles['Mode-Default'] = { modules = { unitFrames = { player = { barWidth = 199, edgeStyle = 'thin', edgeMetal = 'steel' } } } }
before.profiles['Mode-Healer'] = { modules = { unitFrames = { player = { barWidth = 142 } } } }
for name in pairs(before.profiles) do before.profiles[name].theme, before.profiles[name].themeParts, before.profiles[name].look = nil, nil, nil end
before.activeProfile = 'Mode-Healer'
H.Load({ before = STUBS, saved = before }).run([==[
    local P = addon.Profiles
    assert(table.concat(P:List(), ',') == 'Default,Mine,Mode-Default,Mode-DPS/TANK,Mode-Healer,Mode-Healer (old)', table.concat(P:List(), ','))
    assert(P:Active() == 'Mode-Healer (old)' and addon.UnitFrames.db.player.barWidth == 142, 'the old Mode-Healer stays in use, renamed')
    assert(ModeUIDB.profiles['Mode-Healer'].modules.unitFrames.player.barShows == 'mana', 'a new Mode-Healer from the layout')
    assert(ModeUIDB.builtLayouts['mode-default@4'] and ModeUIDB.builtLayouts['healer@8'])
    assert(addon.db.theme == 'obsidian' and addon.db.themeParts.unitFrames == 'obsidian', 'the active profile is Mode-Obsidian')
]==], "reseed")
local reseeded = H.Load({ before = STUBS, saved = before }).saved()
H.Load({ before = STUBS, saved = reseeded }).run([==[
    -- Once per seed: nothing new the next time.
    assert(table.concat(addon.Profiles:List(), ',') == 'Default,Mine,Mode-Default,Mode-DPS/TANK,Mode-Healer,Mode-Healer (old)')
    -- Every other profile turns Mode-Obsidian when it is checked (switching to it).
    local old = assert(addon.Database:ValidateProfile(ModeUIDB.profiles['Mode-Default']))
    assert(old.theme == 'obsidian' and old.modules.unitFrames.player.edgeStyle == 'obsidian' and old.modules.unitFrames.player.edgeMetal == 'default'
        and old.modules.unitFrames.player.barWidth == 199, 'the old Mode-Default: Mode-Obsidian, its own sizes kept')
]==], "reseed once")

-- A rebuilt layout's next seed (@3 after @2): the profiles @2 made are kept
-- as "(old)", a profile the player named themselves stays, new ones are made.
local second = H.Load({ before = STUBS }).saved()
second.builtLayouts = { ['mode-default'] = true, healer = true, ['mode-default@2'] = true, ['healer@2'] = true }
second.profiles['Mode-DPS/TANK'].modules.unitFrames.player.barWidth = 177
-- Party Frames' secure header needs tests/party_frames.lua's client.
second.profiles['Mode-DPS/TANK'].modules.partyFrames.enabled = false
second.activeProfile = 'Mode-DPS/TANK'
H.Load({ before = STUBS, saved = second }).run([==[
    local P = addon.Profiles
    assert(table.concat(P:List(), ',') == 'Default,Mode-DPS/TANK,Mode-DPS/TANK (old),Mode-Healer,Mode-Healer (old)', table.concat(P:List(), ','))
    assert(P:Active() == 'Mode-DPS/TANK (old)' and addon.UnitFrames.db.player.barWidth == 177, 'the tuned profile stays in use, renamed')
    assert(ModeUIDB.profiles['Mode-DPS/TANK'].positions.modeTooltip.target == 'damageMetersWindow1', 'the new one has the new places')
]==], "seed 3")

-- Switched to it (applies on reload), ModeUI starts with every module of the layout.
local switching = H.Load({ before = STUBS })
-- Party Frames' secure group header needs tests/party_frames.lua's client, which
-- runs its part of the layout; here it stays off.
switching.run([==[
    assert(addon.Profiles:Select('Mode-DPS/TANK'))
    ModeUIDB.profiles['Mode-DPS/TANK'].modules.partyFrames.enabled = false
]==], "select")
H.Load({ before = STUBS, saved = switching.saved() }).run([==[
    assert(ModeUIDB.activeProfile == 'Mode-DPS/TANK', 'switched')
    for _, id in ipairs({ 'actionBars', 'buffsDebuffs', 'cooldownManager', 'damageMeters', 'minimap', 'unitFrames' }) do
        assert(addon.modules[id].enabled, id .. ' started')
    end
    local essential = addon.PositionManager:GetPosition('cooldownManagerEssential')
    assert(essential and essential.target == 'screen' and essential.y == 300, 'its places in use')
]==], "in use")

print("layouts: all checks passed")
