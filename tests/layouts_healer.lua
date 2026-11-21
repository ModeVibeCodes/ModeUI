-- The Healer layout (Shared/Runtime/Layouts.lua; owner, November 19, 2026;
-- design/healer-layout/): builds a valid Mode-Healer profile at 1080 and 1440
-- from every module's part, made once per seed at login like Mode-DPS/TANK,
-- and its places line up the way the owner asked: the Player mana frame's bar
-- as wide as the party column and 1px over it, the Target 1px beside it, the
-- Focus 1px under the Target's cast bar, the party column ending level with
-- Essential's second row. Simulated client; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/action_bar_stubs.lua")

local world = H.Load({ before = STUBS })
world.run([==[
    local L, P = addon.Layouts, addon.Profiles
    local spec = assert(L:Get('healer'))
    assert(spec.label == 'Healer' and spec.profileName == 'Mode-Healer' and spec.seed and spec.allModules, 'the Healer layout')
    local parts = {}
    for _, part in ipairs(L.parts.healer) do parts[#parts + 1] = part.module end
    table.sort(parts)
    assert(table.concat(parts, ',') == 'actionBars,bags,buffsDebuffs,cooldownManager,damageMeters,minimap,nameplates,partyFrames,tooltip,unitFrames',
        'every part: ' .. table.concat(parts, ','))
    local UF, PF, CDM, BD = addon.UnitFrames, addon.PartyFrames, addon.CooldownManager, addon.BuffsDebuffs
    local SCREEN = { ['1080'] = 1080, ['1440'] = 1440 }
    for _, variant in ipairs({ '1080', '1440' }) do
        local profile = assert(L:Build('healer', variant))
        local pos, m = profile.positions, profile.modules
        local function At(id, target, point, relative, x, y)
            local p = pos[id]
            assert(p and p.target == target and p.point == point and p.relativePoint == relative and p.x == x and p.y == y,
                id .. ' at ' .. variant .. ': ' .. tostring(p and p.target) .. ' ' .. tostring(p and p.x) .. ', ' .. tostring(p and p.y))
        end
        for id, module in pairs(addon.modules) do
            local db = m[id]
            if db and db.enabled ~= nil and not module.alwaysOn then assert(db.enabled == true, id .. ' on: ' .. variant) end
        end

        -- Essential: 42 x 34 (4px bigger), seven to a line, at Mode-Default's place.
        local cdm = m.cooldownManager
        local eg = CDM.Geometry(cdm.essential, 1, 1)
        assert(cdm.essential.width == 42 and cdm.essential.height == 34 and cdm.essential.perLine == 7 and eg.reach == 2, 'Essential 42 x 34')
        local cdmY = variant == '1440' and 325 or 300
        At('cooldownManagerEssential', 'screen', 'CENTER', 'BOTTOM', 0, cdmY)
        -- Its second line's cells (icon, band, shadow) end 56 under the first line's middle.
        local line = eg.h + 2 * eg.reach
        local e2Bottom = cdmY - SCREEN[variant] / 2 - line / 2 - (line - 1)
        assert(line == 38, 'a line 38 tall with its edges')

        -- Party: you and four, 136 x 64, right edge -323, the last member's
        -- bottom 1px over Essential's second line's (its shadow on that row's shadow).
        local party = m.partyFrames
        local pg = PF.Geometry({ db = party }, 1)
        assert(pg.width == 136 and pg.height == 64 and party.showPlayer and party.showSolo and party.spacing == 1, 'members 136 x 64, you shown, solo too')
        assert(party.edgeStyle == 'obsidian' and party.edgeMetal == 'default' and party.foregroundTexture == 'media:Mode-FG'
            and party.backgroundTexture == 'media:Mode-BG' and party.backgroundOpacity == 85, 'Mode-Border, Mode-FG over Mode-BG at 85')
        assert(m.cooldownManager.essential.edgeStyle == 'obsidianEmpty' and addon.Style.SameColor(m.cooldownManager.essential.edgeColor, addon.Style.Tone.emptyRim),
            'Cooldown Manager icons in Mode-Empty, neutral and darker')
        local column = PF.MAX_MEMBERS * pg.height + (PF.MAX_MEMBERS - 1) * party.spacing
        local p = pos.partyFrames
        assert(p.target == 'screen' and p.point == 'RIGHT' and p.relativePoint == 'CENTER' and p.x == -323, 'party right edge -323')
        local partyBottom, partyTop = p.y - column / 2, p.y + column / 2
        assert(partyBottom == e2Bottom + 1, 'the column ends level with Essential row 2: ' .. variant .. ' ' .. partyBottom .. ' vs ' .. e2Bottom)
        assert(p.y == (variant == '1440' and -288 or -133), 'party middle')
        -- Inside: name top left with the role on its end, health in the middle;
        -- debuffs 20 x 18 (3), Dispellable 22 x 20 (2) on its own row, healing buffs 22 x 18 (3).
        assert(party.nameAnchor == 'TOPLEFT' and party.roleAfterName and party.healthTextAnchor == 'CENTER' and party.healthTextSize == 12)
        local a = party.auras
        assert(a.otherDebuffs.width == 20 and a.otherDebuffs.height == 18 and a.otherDebuffs.max == 3 and a.otherDebuffs.anchor == 'BOTTOMLEFT')
        assert(a.dispellable.width == 22 and a.dispellable.height == 20 and a.dispellable.max == 2 and a.dispellable.anchor == 'LEFT'
            and a.dispellable.y == -1, 'Dispellable on its own row')
        assert(a.heals.show and a.heals.width == 22 and a.heals.height == 18 and a.heals.max == 3 and a.heals.anchor == 'BOTTOMRIGHT')
        for _, group in ipairs(PF.buffGroups) do assert(a[group].show == (group == 'heals'), group .. ' shown only for heals') end
        assert(party.dispelGradientOpacity == 35, 'dispel gradient 35')
        -- Dispellable's row: 1px over the debuffs' (both inside, 2px in from the
        -- edge), and the two rows clear of the centered 12pt health text's middle.
        local debuffTop = pg.height - 2 - a.otherDebuffs.height
        local dispBottom = pg.height / 2 - a.dispellable.y + a.dispellable.height / 2
        assert(debuffTop - dispBottom == 1, 'Dispellable 1px over the debuffs')
        assert(2 + 2 * a.dispellable.width + 1 < pg.width / 2 - 12, 'two Dispellable icons end short of the health text')
        assert(2 + 3 * 20 + 2 < pg.width - 2 - 3 * 22 - 2, 'three debuffs and three healing buffs never touch')

        -- Player: a mana frame, its bar block 20 tall, 136 of bar past its 30px ring.
        local uf = m.unitFrames
        assert(uf.player.barShows == 'mana' and not uf.player.showPower and uf.target.barShows == 'health' and not uf.target.matchPlayer)
        local g = UF:Geometry(uf.player, 1, addon.Style.EdgeDepth('frame'))
        assert(uf.player.healthHeight == 26 and g.blockHeight == 30 and g.portrait == 44 and g.width == 180 and g.height == 44, 'Player 180 x 44: Frame Height 26, a 30px block')
        assert(g.width - g.portrait == pg.width, 'the bar past the ring as wide as the party column')
        local pp, tp, fp = pos.unitFramesPlayer, pos.unitFramesTarget, pos.unitFramesFocus
        assert(pp.point == 'CENTER' and pp.relativePoint == 'CENTER' and tp.point == 'CENTER' and tp.relativePoint == 'CENTER')
        local blockBottom = pp.y - g.height / 2 + g.blockY
        assert(pp.x + g.width / 2 == -323 and blockBottom == partyTop + 1, 'the block on the column, 1px over it')
        -- Target: the same size, its block 1px right of the Player's.
        local tg = UF:Geometry(setmetatable({ showPortrait = true }, { __index = uf.target }), 1, addon.Style.EdgeDepth('frame'))
        assert(tg.width == g.width and tg.height == g.height and tp.y == pp.y and tp.x - tg.width / 2 == -322, 'Target 1px beside')
        local tb = uf.target.buffs
        assert(tb.size == 18 and tb.perRow == 3 and tb.max == 9 and tb.anchor == 'TOPRIGHT' and tb.grow == 'left' and tb.y == -1,
            'Target buffs at its top right, three to a row, 1px over the block')
        -- Three 18px buffs (56) from past the ring leave the left of the bar to the name.
        local tw = tg.width - tg.portrait / 2 - 2 * tg.pad - (tg.tuck + 2)
        assert(tw - (3 * 18 + 2) >= 70, 'room for a name of about 11 letters: ' .. tw - (3 * 18 + 2))
        -- The Target's height is the Player's (Match Height).
        assert(uf.target.matchHeight and profile.sizeMatches.unitFramesTarget.height == 'unitFramesPlayer', 'Target matches the Player height')
        -- Names (12) on the border at the top right; inside, the Player's mana percent and the Target's current health.
        for _, unit in ipairs({ 'player', 'target' }) do
            local s = uf[unit].texts
            assert(s.border.content == 'name' and s.border.align == (unit == 'player' and 'RIGHT' or 'LEFT') and s.border.size == 12,
                unit .. ': name above the border (Player right, Target left)')
        end
        assert(uf.player.texts.right.content == 'powerPercent' and uf.target.texts.left.content == 'healthCurrent' and uf.target.texts.left.size == 12)
        assert(uf.target.castBar.gap == -1 and uf.target.castBar.height == 12 and not uf.targettarget.enabled)
        -- Focus: 136 x 20, 1px under the Target's cast bar (12 + its 1px rim), left edges lined up.
        local fg = UF:Geometry(uf.focus, 1, addon.Style.EdgeDepth('frameThin'))
        assert(fg.width == 136 and fg.height == 20, 'Focus 136 x 20')
        assert(fp.point == 'TOPLEFT' and fp.relativePoint == 'CENTER' and fp.x == -322 and fp.y == blockBottom - 1 - 14 - 1, 'Focus under the cast bar')

        -- ModeCDM: Power and Alternate Mana off; Combo Points a 6px strip 1px
        -- on Essential; the Cast Bar 16 tall at a fixed place over it; Utility 70 under.
        assert(not cdm.resources.power.show and not cdm.resources.mana.show and cdm.resourceLayout == 'separate')
        local combo = cdm.resources.combo
        assert(combo.height == 6 and combo.edgeStyle == 'obsidian' and addon.Style.EdgeMinHeight(CDM.EDGE, 'obsidian', 1) <= 6, 'a thin strip')
        At(CDM.ResourceElementId('combo'), 'cooldownManagerEssential', 'BOTTOM', 'TOP', 0, 1)
        assert(cdm.castBar.height == 16, 'Cast Bar 16')
        At(CDM.CAST_ELEMENT, 'cooldownManagerEssential', 'BOTTOM', 'TOP', 0, 8)
        At('cooldownManagerUtility', 'cooldownManagerEssential', 'TOP', 'BOTTOM', 0, -70)
        local ids = {}
        for _, bar in ipairs(cdm.customBars) do if bar.preset then ids[bar.preset] = bar.id end end
        assert(cdm[ids.defensives].show == false, 'Defensive Cooldowns hidden')
        At(CDM.ElementId(ids.leftBuffs), 'screen', 'CENTER', 'CENTER', -122, -16)
        At(CDM.ElementId(ids.rightBuffs), 'screen', 'CENTER', 'CENTER', 122, -16)
        -- Right Buffs' right edge (34 wide with its edges) is where Player Debuffs counts from.
        local rb = CDM.Geometry(cdm[ids.rightBuffs], 1, 1)
        assert(122 + (cdm[ids.rightBuffs].width + 2 * rb.reach) / 2 == 139, 'Right Buffs ends at 139')
        -- Left Buffs clear of the Target's ring (its right edge 1px past the block's 1px gap, the frame's right end).
        assert(-122 - (cdm[ids.leftBuffs].width + 2 * rb.reach) / 2 > tp.x + tg.width / 2, 'Left Buffs clear of the Target ring')

        -- Buffs & Debuffs: Player Debuffs 6px right of Right Buffs (its 1px
        -- shadow outside), its first row centered on y -16; Boss & Important over it; Defensives at 0, 170.
        local bd = m.buffsDebuffs.bars
        assert(bd.playerDebuffs.grow == 'right' and bd.playerDebuffs.perRow == 6 and bd.playerImportant.grow == 'right')
        At(BD.ElementId('playerDebuffs'), 'screen', 'TOPLEFT', 'CENTER', 146, -16 + 18)
        At(BD.ElementId('playerImportant'), BD.ElementId('playerDebuffs'), 'BOTTOMLEFT', 'TOPLEFT', 0, 6)
        local defensives
        for _, entry in ipairs(m.buffsDebuffs.customBars) do if entry.preset == 'defensives' then defensives = entry.id end end
        local dw = BD:BarSize(bd[defensives], 1)
        At(BD.ElementId(defensives), 'screen', 'LEFT', 'CENTER', -82, 170)
        assert(dw == 163 and math.abs(-82 + dw / 2) <= 0.5, 'Defensives centered on 0')

        -- Everything else as Mode-DPS/TANK.
        local dps = assert(L:Build('mode-default', variant))
        for _, id in ipairs({ 'actionBarsBar1', 'actionBarsMicro', 'modeMinimap', 'damageMetersWindow1', 'buffsDebuffsBuffs',
            'buffsDebuffsDebuffs', 'cooldownManagerBuffIcon' }) do
            local a1, b1 = pos[id], dps.positions[id]
            assert(a1 and b1 and a1.target == b1.target and a1.x == b1.x and a1.y == b1.y, id .. ' as in Mode-DPS/TANK')
        end
    end
    -- Made into a profile once, at login, beside Mode-DPS/TANK; the active profile stays.
    assert(P:Exists('Mode-Healer') and P:Exists('Mode-DPS/TANK') and P:Active() == 'Default' and ModeUIDB.builtLayouts['healer@3'] == true)
    assert(ModeUIDB.profiles['Mode-Healer'].theme == 'obsidian', 'in Mode-Obsidian')
    assert(not P:CreateFromLayout('Mode-Healer', 'healer'), 'its name is taken')
]==], "healer build")

-- Switched to it, ModeUI starts with the Player as a mana frame where the layout put it.
local switching = H.Load({ before = STUBS })
switching.run([==[
    assert(addon.Profiles:Select('Mode-Healer'))
    ModeUIDB.profiles['Mode-Healer'].modules.partyFrames.enabled = false
]==], "select")
H.Load({ before = STUBS, saved = switching.saved() }).run([==[
    local M = addon.UnitFrames
    assert(ModeUIDB.activeProfile == 'Mode-Healer' and M.active and M.db.player.barShows == 'mana', 'the mana frame')
    local function Box(f) local x, y = f:GetCenter(); local w, h = f:GetWidth(), f:GetHeight(); return x - w / 2, y - h / 2, x + w / 2, y + h / 2, w, h end
    local ux, uy = UIParent:GetCenter()
    local pl, pb, pr, pt, pw, ph = Box(M.ghosts.player)
    local tl, tb, tr, tt, tw, th = Box(M.ghosts.target)
    assert(pw == 180 and ph == 44 and tw == 180 and th == 44, 'Edit Mode measures the frames as built')
    assert(pr - ux == -323 and tl - ux == -322 and pb == tb, 'side by side, 1px apart')
    -- Match Height: a Player made shorter takes the Target with it.
    -- (The client tells the Target of the Player's new size through OnSizeChanged,
    -- which the mock doesn't fire: refresh the match as that event does.)
    local PM = addon.PositionManager
    assert(M:SetFrameOption('player', 'healthHeight', 24)); PM:RefreshAnchorSize('unitFramesTarget')
    local _, pb2, _, pt2 = Box(M.ghosts.player)
    local _, tb2, _, tt2 = Box(M.ghosts.target)
    assert(pt2 - pb2 == 40 and tt2 - tb2 == 40, 'the Target follows the Player height: ' .. (pt2 - pb2) .. ' and ' .. (tt2 - tb2))
    assert(M:SetFrameOption('player', 'healthHeight', 26)); PM:RefreshAnchorSize('unitFramesTarget')
    local _, pb3, _, pt3 = Box(M.ghosts.player)
    local _, tb3, _, tt3 = Box(M.ghosts.target)
    assert(pt3 - pb3 == 44 and tt3 - tb3 == 44 and M.frames.target.texts.border.justifyH == 'LEFT', 'back to 44; the Target name at the left')
    local p = M.frames.player
    units.player.mana, units.player.manaMax = 300, 900
    M:Update('player')
    assert(p.health:GetValue() == 300 and not p.power:IsShown(), 'mana on the bar, no power bar')
    assert(p.texts.right:GetText() == '33%' and p.texts.border:GetText() ~= nil, 'the mana percent on the right, the name on the border')
    local essential = addon.PositionManager:GetPosition('cooldownManagerEssential')
    assert(essential and essential.y == 300, 'its places in use')
]==], "healer in use")

print("layouts: Healer checks passed")
