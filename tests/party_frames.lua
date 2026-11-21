-- Party Frames: the secure group header, Blizzard's party frames, members
-- with secret values, icons, range, the aura manager (reader and containers),
-- settings validation and the settings page. Simulated client; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local UNIT_STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")

-- A party, Blizzard's PartyFrame, and a SecureGroupHeaderTemplate stand-in that
-- behaves like Forever's SecureGroupHeaders.lua: it lists the group (the
-- player first, then party1..), groups by assigned role, reverses for DESC,
-- creates buttons when it needs more (running initialConfigFunction's
-- CallMethod), hands out units and shows only the buttons it uses.
local STUBS = UNIT_STUBS .. [==[
    local methods = getmetatable(UIParent).__index
    function methods:GetAttribute(key) return self.attributes and self.attributes[key] end
    local setAttribute = methods.SetAttribute
    function methods:SetAttribute(key, value)
        setAttribute(self, key, value)
        if self.scripts.OnAttributeChanged then self.scripts.OnAttributeChanged(self, key, value) end
    end
    function methods:SetParent(parent) assert(not InCombatLockdown(), 'SetParent in combat'); self.parent = parent end
    function methods:SetSpriteSheetCell(index) self.cell = index end
    function methods:SetAlphaFromBoolean(value, a, b) self.alphaFromBoolean = { value, a, b }; self.alpha = nil end
    function methods:SetRolesets(value) assert(not InCombatLockdown()); self.rolesets = value end
    function methods:IsVisible() local f = self; while f do if not f.shown then return false end f = f.parent end return true end
    units.party1 = { exists = true, health = Secret('p1hp'), max = Secret('p1max'), power = Secret('p1p'), powerMax = Secret('p1pm'),
        token = 'MANA', name = Secret('p1name'), level = 60, class = 'PRIEST', isPlayer = true, connected = true }
    units.party2 = { exists = true, health = 500, max = 1000, power = 10, powerMax = 100, token = 'RAGE', name = 'Tankard',
        level = 60, class = 'WARRIOR', isPlayer = true, connected = true }
    roster, roles, inGroup = { 'party1', 'party2' }, { player = 'DAMAGER', party1 = 'HEALER', party2 = 'TANK' }, true
    function UnitGroupRolesAssigned(u) return roles[u] or 'NONE' end
    function UnitIsGroupLeader(u) return u == 'party2' end
    function HasLFGRestrictions() return false end
    readyStatus = {}
    function GetReadyCheckStatus(u) return readyStatus[u] end
    function UnitHasIncomingResurrection() return false end
    Enum = Enum or {}; Enum.SummonStatus = { None = 0, Pending = 1, Accepted = 2, Declined = 3 }
    summons = {}
    -- Auras: RAID keeps the ones you can dispel (aura.dispellable), !RAID the rest.
    local getAuras = C_UnitAuras.GetUnitAuras
    C_UnitAuras.GetUnitAuras = function(unit, filter, max)
        local list, kept = getAuras(unit, filter, 40), {}
        for _, a in ipairs(list) do
            local raid = filter:find('|RAID', 1, true) and not filter:find('|RAID_', 1, true)
            local notRaid = filter:find('|!RAID', 1, true) and not filter:find('|!RAID_', 1, true)
            if (not raid or a.dispellable) and (not notRaid or not a.dispellable) and #kept < max then kept[#kept + 1] = a end
        end
        return kept
    end
    C_Spell = { GetSpellName = function(id) return 'Spell' .. id end, GetSpellTexture = function(id) return 'icon' .. id end }
    C_IncomingSummon = { HasIncomingSummon = function(u) return summons[u] ~= nil end, IncomingSummonStatus = function(u) return summons[u] end }
    function UnitPhaseReason() return nil end
    inRange = { party1 = Secret('range'), party2 = true }
    function UnitInRange(u) return inRange[u], true end
    function UnitGetIncomingHeals() return Secret('heals') end
    function UnitGetTotalAbsorbs() return Secret('absorbs') end
    function GetRaidTargetIndex(u) if u == 'party2' then return Secret('mark') end end
    targetUnit = nil
    function UnitIsUnit(a, b) return a == b or (b == 'target' and a == targetUnit) end
    drivers = {}
    -- State drivers run in secure code, so they may show and hide in combat.
    local function Evaluate(f)
        local cond = drivers[f]
        if not cond then return end
        local lockdown = testLockdown
        testLockdown = false
        f:SetShown(cond:find('; show$') ~= nil or inGroup)
        testLockdown = lockdown
    end
    function RegisterAttributeDriver(f, attribute, cond)
        assert(not InCombatLockdown() and attribute == 'state-visibility'); drivers[f] = cond; Evaluate(f)
    end
    function UnregisterAttributeDriver(f) assert(not InCombatLockdown()); drivers[f] = nil end
    function GroupChanged() for f in pairs(drivers) do Evaluate(f) end; FireEvent('GROUP_ROSTER_UPDATE') end
    PartyFrame = CreateFrame('Frame', 'PartyFrame', UIParent)
    CompactPartyFrame = CreateFrame('Frame', 'CompactPartyFrame', PartyFrame)
    headers = {}
    local ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }
    local Update
    -- The header's own code is secure: it may show, hide and place its buttons
    -- in combat. Addon code reacting to it (OnAttributeChanged) still runs in
    -- combat, so the lockdown comes back before any member script runs.
    local function Secure(h, fn)
        local lockdown = testLockdown
        testLockdown = false
        local units = fn(h)
        testLockdown = lockdown
        return units
    end
    function Update(h)
        local a = h.attributes
        local list = {}
        if inGroup or a.showSolo then
            if a.showPlayer or a.showSolo or not inGroup then list[#list + 1] = 'player' end
            if inGroup then for _, u in ipairs(roster) do list[#list + 1] = u end end
        end
        if a.groupBy == 'ASSIGNEDROLE' then
            local index = {}; for i, u in ipairs(list) do index[u] = i end
            table.sort(list, function(x, y)
                local rx, ry = ORDER[roles[x] or 'NONE'], ORDER[roles[y] or 'NONE']
                if rx ~= ry then return rx < ry end
                return index[x] < index[y]
            end)
        end
        if a.sortDir == 'DESC' then local r = {}; for i = #list, 1, -1 do r[#r + 1] = list[i] end; list = r end
        local start = a.startingIndex or 1
        -- configureChildren: how many buttons it shows (and so needs).
        local shown, perColumn, columns = #list - (start - 1), a.unitsPerColumn, 1
        if perColumn and shown > perColumn then columns = math.min(math.ceil(shown / perColumn), a.maxColumns or 1)
        else perColumn = shown end
        shown = math.min((start - 1) + perColumn * columns, #list) - (start - 1)
        local need = math.max(1, shown)
        for i = 1, need do
            if not a['child' .. i] then
                local child = CreateFrame(a.templateType or 'Button', h:GetName() .. 'UnitButton' .. i, h, a.template)
                h[i] = child
                -- initialConfigFunction: click attributes, then CallMethod.
                assert(a.initialConfigFunction:find('CallMethod%("InitializeMember"'), 'config calls back')
                child:SetAttribute('*type1', 'target'); child:SetAttribute('*type2', 'togglemenu')
                h.attributes['child' .. i] = child
                h:InitializeMember(child:GetName())
            end
        end
        local assigned = {}
        Secure(h, function()
            local i = 0
            for n = start, start + need - 1 do
                i = i + 1
                local child = a['child' .. i]
                child:SetPoint(a.point or 'TOP', h, a.point or 'TOP', 0, 0)
                assigned[#assigned + 1] = { child, list[n] }
                child.attributes.unit = list[n]
                child.shown = true
            end
            i = i + 1
            while a['child' .. i] do
                local child = a['child' .. i]
                child.shown = false; child.points = {}; child.attributes.unit = nil
                assigned[#assigned + 1] = { child, nil }
                i = i + 1
            end
        end)
        for _, pair in ipairs(assigned) do
            local child = pair[1]
            if child.scripts.OnAttributeChanged then child.scripts.OnAttributeChanged(child, 'unit', pair[2]) end
            if child.shown and child.scripts.OnShow then child.scripts.OnShow(child) end
        end
        h.updates = (h.updates or 0) + 1
    end
    local create = CreateFrame
    function CreateFrame(kind, name, parent, template)
        if template ~= 'SecureGroupHeaderTemplate' then return create(kind, name, parent, template) end
        assert(not InCombatLockdown(), 'header made in combat')
        local h = create('Frame', name, parent)
        h.secure, h.attributes = true, {}
        h:Hide()
        h:SetScript('OnAttributeChanged', function(self, key)
            if key == '_ignore' or self.attributes._ignore then return end
            if self:IsVisible() then Update(self) end
        end)
        h:HookScript('OnShow', function(self) Update(self) end)
        h:RegisterEvent('GROUP_ROSTER_UPDATE')
        h:SetScript('OnEvent', function(self) if self:IsVisible() then Update(self) end end)
        headers[#headers + 1] = h
        return h
    end
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M = addon.PartyFrames
    assert(M and addon.modules.partyFrames == M and M.category == 'frames' and M.defaultEnabled == false)
    assert(not M.enabled and M.header == nil and M.ghost == nil, 'off by default; nothing built')
    -- The Mode-Obsidian look (the theme part runs on every profile): Urbanist,
    -- Mode-FG on Mode-BG at 85%, 150 x 34 + 3, Gradient names, Backlit
    -- dispels, the Prism glow on mouseover and focus.
    assert(M.db.version == 7 and M.db.fontMedia == 'Mode' and M.db.foregroundTexture == 'media:Mode-FG' and M.db.backgroundTexture == 'media:Mode-BG')
    assert(M.db.dispelFrom == 'bottom' and M.db.hoverGlow and M.db.focusGlow and not M.db.hoverHighlight, 'Backlit dispels, the glow in place of the mouse tint')
    assert(M.db.shieldsTexture == 'Shield' and M.db.shieldsColorMode == 'health' and M.db.shieldsOpacity == 100, 'the standard shield look')
    assert(M.db.backgroundOpacity == 85 and M.db.powerBackgroundOpacity == 85, 'see-through empty bars')
    assert(M.db.nameShow and M.db.nameAnchor == 'LEFT' and M.db.leaderPlace == 'outside' and M.db.auras.heals.filter == 'all')
    assert(M.db.spacing == 1 and M.db.auras.dispellable.show and M.db.auras.magic.filter == 'notMine' and M.db.auras.tracked1.spells[1] == nil)
    assert(M.db.healthHeight == 34 and M.db.width == 150 and M.db.powerHeight == 3 and M.db.borderStyle == nil and M.db.corner == nil)
    assert(M.db.shieldTexture == nil and M.db.nameColorMode == 'class' and M.db.healthTextColor == 'health' and M.db.aggroHighlight and M.db.healthTextShow)
    assert(M.db.auras.magic.glow == 'none' and M.db.dispel.Magic.gradient and not M.db.dispel.Magic.border and not M.db.dispel.Magic.health, 'glows off, the dispel Gradient by default')
    assert(PartyFrame.parent == UIParent, 'Blizzard untouched while off')

    -- Enabling in combat waits; nothing secure is made until combat ends.
    testLockdown, testCombat = true, true
    addon:SetModuleEnabled('partyFrames', true)
    assert(M.active and M.header == nil and PartyFrame.parent == UIParent, 'combat enable deferred')
    testLockdown, testCombat = false, false
    FireEvent('PLAYER_REGEN_ENABLED')
    local h = M.header
    assert(h and h.secure and h:GetName() == 'ModeUIPartyHeader' and h.rolesets == 'unitFrames', 'secure header after combat')
    assert(#M.members == 5 and h.attributes.startingIndex == 1, 'all five buttons made up front')
    assert(h.attributes.template == 'SecureUnitButtonTemplate' and h.attributes.showParty and not h.attributes.showRaid)
    assert(drivers[h] == '[group:raid] hide; [group] show; hide' and h:IsShown(), 'shown in a party by its state driver')
    assert(PartyFrame.parent == M.hiddenParent and not M.hiddenParent:IsShown(), 'Blizzard party frames hidden by parent')
    local m1 = M.members[1]
    assert(m1.secure and m1.attributes['*type2'] == 'togglemenu' and m1.clickRegistration == 'AnyUp')
    -- The player first, then the party.
    assert(M.members[1].unit == 'player' and M.members[2].unit == 'party1' and M.members[3].unit == 'party2')
    assert(not M.members[4]:IsShown() and M.members[4].unit == nil, 'unused buttons hidden')
    assert(h.attributes.point == 'TOP' and h.attributes.yOffset < 0 and h.attributes.xOffset == 0, 'grows down')
    assert(M.members[2].width == M.members[2].geometry.width and M.members[2].height % 2 == 0, 'sized, even pixels')

    -- Secret values reach only widgets that accept them.
    local p1 = M.members[2]
    assert(p1.panel.edge.pieces and #p1.panel.edge.parts[1] == 8 and p1.powerEdge.pieces, 'party edges in pieces (owner, November 18, 2026)')
    assert(p1.health.value.label == 'p1hp' and p1.health.high.label == 'p1max', 'secret health straight to the bar')
    assert(p1.texts.name.text.label == 'p1name', 'secret name straight to SetText')
    assert(p1.healPrediction.value.label == 'heals' and Point(p1.healPrediction)[2] == p1.health:GetStatusBarTexture(), 'heals ride on health')
    -- Combined shields (Style.Shield): the secret shield on the health's end, the whole one back from max.
    local shield = p1.health.shield
    assert(shield and shield.attached.value.label == 'absorbs' and shield.full.reverseFill == true and p1.health.reverseFill == false)
    -- The group edge round the bars' area: a 1px rim, nothing masked.
    assert(p1.panel.edge.preset == 'group' and p1.geometry.border == 1 and #(p1.health:GetStatusBarTexture().masks or {}) == 0)
    assert(Point(p1.health)[2] == p1.panel.inner, 'the bars fill the area inside the rim')
    -- Border Style and Border Metal (owner, November 17, 2026): Mode-Border in
    -- its own metal by default, the member and its inset power bar together;
    -- any style keeps the size; an old id (Mode-Round) draws as Mode-Border.
    local Metal = addon.Style.Tone.metal
    assert(M.db.edgeStyle == 'obsidian' and M.db.edgeMetal == 'default' and p1.panel.edge.styleId == 'obsidian'
        and p1.panel.edge:Metal() == Metal.obsidian and p1.powerEdge.styleId == 'obsidian', 'members in Mode-Border')
    local wide, tall = p1.geometry.width, p1.geometry.height
    assert(M:SetOption('edgeStyle', 'obsidianEmpty') and p1.panel.edge.styleId == 'obsidianEmpty' and p1.powerEdge.styleId == 'obsidianEmpty'
        and p1.geometry.width == wide and p1.geometry.height == tall and p1.width == wide, 'Mode-Empty, same size')
    assert(M:SetOption('edgeStyle', 'round') and p1.panel.edge.styleId == 'obsidian', 'an old id draws as Mode-Border')
    assert(M:SetOption('edgeMetal', 'gunmetal') and p1.panel.edge:Metal() == Metal.gunmetal and p1.powerEdge:Metal() == Metal.gunmetal)
    assert(not M:SetOption('edgeStyle', 'nope') and not M:SetOption('edgeMetal', 'gold') and M.db.edgeStyle == 'round', 'unknown styles are refused')
    assert(M:SetOption('edgeStyle', 'obsidian') and M:SetOption('edgeMetal', 'default') and p1.panel.edge.styleId == 'obsidian'
        and p1.panel.edge:Metal() == Metal.obsidian)
    -- Mode-FG draws its base with the white lift over the fill; the empty
    -- part is Slate at 85% with no black plate behind it.
    local S = addon.Style
    assert(p1.health.statusBarTexture == S.AssetPath('FGBase') and p1.health.sheen:IsShown() and p1.health.sheen.texture == S.AssetPath('FGLift'), 'Mode-FG base + lift')
    assert(Point(p1.health.sheen)[2] == p1.health:GetStatusBarTexture(), 'the lift follows the fill')
    assert(math.abs(p1.health.bg.vertexColor[4] - 0.85) < 1e-6 and p1.panel.back.vertexColor[4] == 0, 'see-through, no plate')
    assert(M:SetOption('healthColorMode', 'default') and p1.health.statusBarColor[1] == S.Tone.darkFill[1] and S.Hex('161618')[2] == S.Tone.darkFill[2], 'Dark is #161618 (Mode-Obsidian)')
    assert(M:SetOption('healthColorMode', 'class'))
    -- Health Text Glow: on by default, a halo on the health text's side.
    local hg = p1.texts.healthText.glow
    assert(M.db.healthTextGlow and hg and hg.on and hg:IsShown() and hg.points[1][1] == 'RIGHT', 'health numbers glow')
    assert(M:SetOption('healthTextGlow', false) and not hg:IsShown() and M:SetOption('healthTextGlow', true) and hg:IsShown())
    assert(p1.alphaFromBoolean and p1.alphaFromBoolean[1].label == 'range' and p1.alphaFromBoolean[3] == 0.55, 'secret range via SetAlphaFromBoolean')
    assert(M.members[1]:GetAlpha() == 1 and M.members[3]:GetAlpha() == 1, 'you and members in range stay opaque')
    -- Class color by default.
    local priest = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PRIEST
    assert(p1.health.statusBarColor and p1.health.statusBarColor[4] == 1)
    -- Icons: roles, leader, raid marker through SetSpriteSheetCell (secret index).
    local tank = M.members[3]
    assert(tank.icons.role.atlas == 'roleicon-tiny-tank' and p1.icons.role.atlas == 'roleicon-tiny-healer')
    assert(tank.icons.leader:IsShown() and tank.icons.leader.atlas == 'UI-HUD-UnitFrame-Player-Group-LeaderIcon' and not p1.icons.leader:IsShown())
    assert(tank.icons.raidIcon:IsShown() and tank.icons.raidIcon.cell.label == 'mark' and not p1.icons.raidIcon:IsShown())
    readyStatus.party1 = 'ready'; FireEvent('READY_CHECK')
    assert(p1.icons.readyCheck:IsShown() and p1.icons.readyCheck.atlas == 'UI-LFG-ReadyMark' and not tank.icons.readyCheck:IsShown())
    readyStatus.party1 = nil; FireEvent('READY_CHECK_FINISHED')
    assert(not p1.icons.readyCheck:IsShown(), 'cleared after the check')
    summons.party1 = 1; FireEvent('INCOMING_SUMMON_CHANGED', 'party1')
    assert(p1.icons.incoming:IsShown() and p1.icons.incoming.atlas == 'RaidFrame-Icon-SummonPending')
    summons.party1 = nil; FireEvent('INCOMING_SUMMON_CHANGED', 'party1'); assert(not p1.icons.incoming:IsShown())
    -- Dead and offline: status text and the faded alpha.
    units.party2.dead = true; FireEvent('UNIT_HEALTH', 'party2')
    assert(tank.texts.status.text == 'Dead' and tank:GetAlpha() == 0.7 and tank.texts.healthText.text ~= '75%')
    units.party2.dead = false; FireEvent('UNIT_CONNECTION', 'party2'); assert(tank.texts.status.text == '' and tank:GetAlpha() == 1)
    -- Your target: the rim swapped to Ivory (the size never changes).
    targetUnit = 'party2'; FireEvent('PLAYER_TARGET_CHANGED')
    assert(tank.isTarget and tank.panel.edge.tint == M.db.targetColor and p1.panel.edge.tint == nil)
    targetUnit = nil; FireEvent('PLAYER_TARGET_CHANGED'); assert(tank.panel.edge.tint == nil)
    -- Aggro: the rim in the hostile red; your target wins.
    function UnitThreatSituation(u, mob) if mob == nil then return threat[u] end end
    threat = { party1 = 3 }; FireEvent('UNIT_THREAT_SITUATION_UPDATE', 'party1')
    assert(p1.hasAggro and p1.panel.edge.tint == addon.Style.Tone.reaction.hostile, 'aggro rim')
    assert(M:SetOption('aggroHighlight', false) and p1.panel.edge.tint == nil and M:SetOption('aggroHighlight', true))
    threat = {}; FireEvent('UNIT_THREAT_SITUATION_UPDATE', 'party1'); assert(p1.panel.edge.tint == nil)

    -- Healers-only power: the tank's health takes the whole height.
    assert(M:SetOption('powerShown', 'healers') and p1.power:IsShown() and not tank.power:IsShown())
    assert(tank.health.height == tank.geometry.innerHeight and p1.health.height < p1.geometry.innerHeight)
    -- Mana Users and Healer Mana: the Rogue (energy) and the Warrior (rage) show none.
    local me = M.members[1]
    assert(M:SetOption('powerShown', 'mana') and p1.power:IsShown() and not tank.power:IsShown() and not me.power:IsShown())
    roles.party1 = 'DAMAGER'; FireEvent('PLAYER_ROLES_ASSIGNED')
    assert(M:SetOption('powerShown', 'healerMana') and not p1.power:IsShown(), 'a damage dealer with mana: hidden')
    roles.party1 = 'HEALER'; FireEvent('PLAYER_ROLES_ASSIGNED'); assert(p1.power:IsShown(), 'healer with mana')
    -- Inset: on the health bar, Power Width wide, in its own border.
    assert(M:SetOption('powerShown', 'all') and M:SetOption('powerStyle', 'inset') and M:SetOption('powerWidth', 50))
    local g = p1.geometry
    assert(p1.health.height == g.innerHeight and math.abs(p1.power.width - g.innerWidth / 2) < 1 and p1.powerEdge.holder:IsShown())
    local pp = Point(p1.power); assert(pp[1] == 'BOTTOM' and pp[3] == 'BOTTOM' and pp[5] == g.border + 3, 'centered, 3px up')
    assert(M:SetOption('powerStyle', 'below') and not p1.powerEdge.holder:IsShown() and M:SetOption('powerHeight', 10) and p1.power.height == 10)
    assert(M:SetOption('powerHeight', 3))

    -- Layout: role sort, reverse, growth and spacing through header attributes.
    assert(M:SetOption('sortBy', 'role') and h.attributes.groupBy == 'ASSIGNEDROLE' and h.attributes.groupingOrder == 'TANK,HEALER,DAMAGER,NONE')
    assert(M.members[1].unit == 'party2' and M.members[2].unit == 'party1' and M.members[3].unit == 'player', 'tank, healer, damage')
    assert(M.members[1].icons.role.atlas == 'roleicon-tiny-tank', 'icons follow the new unit')
    assert(M:SetOption('sortBy', 'group') and h.attributes.groupBy == nil)
    assert(M:SetOption('reverseOrder', true) and M.members[1].unit == 'party2' and M:SetOption('reverseOrder', false))
    assert(M:SetOption('growth', 'right') and h.attributes.point == 'LEFT' and h.attributes.xOffset > 0 and h.attributes.yOffset == 0)
    -- The header hangs by the point it lays members out from (Blizzard centers
    -- each member on it and sizes the header itself), at that point of the stand-in.
    assert(Point(h)[1] == 'LEFT', 'the header is anchored by the point it grows from')
    assert(M:SetOption('spacing', 10) and h.attributes.xOffset == 10 and M:SetOption('growth', 'down'))
    local gl, gw, gb, gh = M.ghost:GetLeft(), M.ghost:GetWidth(), M.ghost:GetBottom(), M.ghost:GetHeight()
    local hp = Point(h)
    assert(hp[1] == 'TOP' and hp[3] == 'BOTTOMLEFT' and math.abs(hp[4] - (gl + gw / 2)) <= 0.5 and math.abs(hp[5] - (gb + gh)) <= 0.5,
        'growing down: by its top, on the stand-in top middle, so the header width never moves the column')
    assert(M:SetOption('showPlayer', false) and M.members[1].unit == 'party1' and M:SetOption('showPlayer', true))
    assert(not M:SetOption('growth', 'sideways') and not M:SetOption('width', 9000) and not M:SetOption('nope', 1), 'validated')
    -- Settings never change in combat.
    testLockdown, testCombat = true, true
    assert(not M:SetOption('width', 150), 'no changes in combat')
    -- Roster changes in combat: the header hands out units, members follow.
    roster = { 'party2' }; GroupChanged()
    assert(M.members[2].unit == 'party2' and not M.members[3]:IsShown(), 'header updates in combat')
    testLockdown, testCombat = false, false
    roster = { 'party1', 'party2' }; GroupChanged()

    -- Solo: hidden, unless Show When Solo.
    inGroup = false; GroupChanged()
    assert(not h:IsShown(), 'hidden when solo')
    assert(M:SetOption('showSolo', true) and drivers[h] == '[group:raid] hide; show' and h:IsShown() and M.members[1].unit == 'player')
    assert(M:SetOption('showSolo', false)); inGroup = true; GroupChanged()

    -- Elements: placed by anchor; inside on the bars, outside past their edge.
    assert(M:SetElementOption('role', 'anchor', 'LEFT') and M:SetElementOption('role', 'place', 'outside'))
    local q = Point(p1.icons.role); assert(q[1] == 'RIGHT' and q[2] == p1.panel and q[3] == 'LEFT', 'role outside on the left')
    assert(M:SetElementOption('name', 'anchor', 'CENTER') and Point(p1.texts.name)[1] == 'CENTER' and p1.texts.name.justifyH == 'CENTER')
    assert(M:SetElementOption('name', 'show', false) and not p1.texts.name:IsShown() and M:SetElementOption('name', 'show', true))
    assert(not M:SetElementOption('name', 'anchor', 'MIDDLE') and not M:SetElementOption('bogus', 'show', true))
    -- Role After Name (owner, November 19, 2026): the name sizes to its text
    -- (width 0, one anchor) and the role icon hangs from its end at Offset X/Y;
    -- with the name hidden the icon goes back to its own anchor.
    assert(M.db.roleAfterName == false and M:SetOption('roleAfterName', true))
    assert(M:SetElementOption('name', 'anchor', 'TOPLEFT') and M:SetElementOption('role', 'x', 2) and M:SetElementOption('role', 'y', 0))
    q = Point(p1.icons.role); assert(q[1] == 'LEFT' and q[2] == p1.texts.name and q[3] == 'RIGHT' and q[4] == 2 and q[5] == 0, 'role on the name end')
    assert(p1.texts.name:GetWidth() == 0 and #p1.texts.name.points == 1, 'the name takes its text width')
    assert(M:SetElementOption('name', 'show', false) and Point(p1.icons.role)[2] == p1.panel, 'no name: the role keeps its own place')
    assert(M:SetElementOption('name', 'show', true) and M:SetOption('roleAfterName', false) and p1.texts.name:GetWidth() > 0)
    assert(Point(p1.icons.role)[2] == p1.panel and M:SetElementOption('name', 'anchor', 'CENTER'))
    assert(M:SetElementOption('healthText', 'show', true) and p1.texts.healthText.text.secret, 'secret percent text')
    assert(M:SetOption('healthText', 'percentPlain') and p1.texts.healthText.text.formatted == '%.0f', 'percent with no sign')

    -- Hide Blizzard off, and switching the module off, put PartyFrame back.
    assert(M:SetOption('hideBlizzard', false) and PartyFrame.parent == UIParent)
    assert(M:SetOption('hideBlizzard', true) and PartyFrame.parent == M.hiddenParent)
    addon:SetModuleEnabled('partyFrames', false)
    assert(PartyFrame.parent == UIParent and drivers[h] == nil and not h:IsShown(), 'off: header hidden, Blizzard back')
    assert(next(p1.events.events) == nil, 'member events off')
    addon:SetModuleEnabled('partyFrames', true)
    assert(h:IsShown() and PartyFrame.parent == M.hiddenParent and M.members[2].unit == 'party1')
]==], "party_header")

-- The aura manager without containers (reader path), samples and the page.
world.run([==[
    local M = addon.PartyFrames
    local p1 = M.members[2]
    units.party1.helpful = { { icon = 'renew', auraInstanceID = 11, spellId = 139, duration = 0, expirationTime = 0 },
        { icon = 'rejuv', auraInstanceID = 12, spellId = 774, duration = 0, expirationTime = 0 } }
    units.party1.harmful = { { icon = 'pain', auraInstanceID = 21, dispelName = 'Magic', dispellable = true, duration = 0, expirationTime = 0 },
        { icon = 'frost', auraInstanceID = 23, dispelName = 'Magic', duration = 0, expirationTime = 0 },
        { icon = 'rend', auraInstanceID = 22, duration = 0, expirationTime = 0 } }
    auraFilters = {}
    FireEvent('UNIT_AURA', 'party1')
    assert(p1.auraIcons.heals[1]:IsShown() and p1.auraIcons.heals[1].icon.texture == 'renew' and p1.auraIcons.heals[2]:IsShown())
    -- Dispellable by You first, then by type the ones you can't dispel, the untyped one in Other Debuffs.
    assert(p1.auraIcons.dispellable[1].icon.texture == 'pain' and p1.auraIcons.dispellable[1].rim.vertexColor[3] == M.db.auraMagicColor[3])
    assert(not (p1.auraIcons.dispellable[2] and p1.auraIcons.dispellable[2]:IsShown()), 'only the dispellable one')
    assert(p1.auraIcons.magic[1]:IsShown() and p1.auraIcons.magic[1].icon.texture == 'frost' and p1.auraIcons.magic[1].rim.vertexColor[3] == M.db.auraMagicColor[3])
    assert(p1.auraIcons.otherDebuffs[1].icon.texture == 'rend' and not (p1.auraIcons.otherDebuffs[2] and p1.auraIcons.otherDebuffs[2]:IsShown()))
    assert(not p1.auraIcons.curse[1] or not p1.auraIcons.curse[1]:IsShown(), 'no curse')
    local seen = table.concat(auraFilters, ',')
    assert(seen:find('HELPFUL|RAID_IN_COMBAT', 1, true) and seen:find('HARMFUL|RAID_IN_COMBAT', 1, true) and seen:find('HELPFUL|EXTERNAL_DEFENSIVE', 1, true), seen)
    -- One row per anchor: Dispellable, then Magic, then Other Debuffs.
    local dp, mg, od = Point(p1.auraIcons.dispellable[1]), Point(p1.auraIcons.magic[1]), Point(p1.auraIcons.otherDebuffs[1])
    assert(dp[1] == 'BOTTOMLEFT' and mg[4] == dp[4] + 18 + 1 and od[1] == 'BOTTOMLEFT' and od[4] == mg[4] + 18 + 1 and od[5] == mg[5], 'continues in one row')
    -- Tracked Buffs: + adds a buff by spell; the healing buffs leave it out.
    assert(M:AddTrackedSpell('tracked1', 774) and M.db.auras.tracked1.spells[1] == 774)
    assert(p1.auraIcons.tracked1[1]:IsShown() and p1.auraIcons.tracked1[1].icon.texture == 'rejuv', 'rejuv in Tracked Buffs 1')
    assert(p1.auraIcons.heals[1].icon.texture == 'renew' and not (p1.auraIcons.heals[2] and p1.auraIcons.heals[2]:IsShown()), 'and not in Healing Buffs')
    assert(not M:AddTrackedSpell('tracked1', 774) and not M:AddTrackedSpell('heals', 139) and not M:AddTrackedSpell('tracked2', 0.5))
    assert(M:AddTrackedSpell('tracked2', 774) and M.db.auras.tracked1.spells[1] == nil and M.db.auras.tracked2.spells[1] == 774, 'moves between groups')
    assert(M:RemoveTrackedSpell('tracked2', 774) and M.db.auras.tracked2.spells[1] == nil and p1.auraIcons.heals[2]:IsShown(), 'back in Healing Buffs')
    local candidates = M:BuffCandidates()
    assert(#candidates >= 2 and candidates[1].name == 'Spell' .. candidates[1].id, 'buffs on you and your party')
    -- Each group its own width and height.
    assert(p1.auraIcons.heals[1].width == 16 and p1.auraIcons.heals[1].height == 12)
    assert(M:SetAuraOption('magic', 'width', 24) and M:SetAuraOption('magic', 'height', 20) and p1.auraIcons.magic[1].width == 24)
    assert(Point(p1.auraIcons.otherDebuffs[1])[4] == mg[4] + 24 + 1, 'the next one moves along')
    -- Placement: healing buffs at the bottom right inside, growing left; wrapping by Per Row.
    local b = Point(p1.auraIcons.heals[1]); assert(b[1] == 'BOTTOMRIGHT' and b[2] == p1.panel and b[3] == 'BOTTOMRIGHT' and b[4] < 0 and b[5] > 0)
    local b2 = Point(p1.auraIcons.heals[2]); assert(b2[4] < b[4] and b2[5] == b[5], 'second to the left')
    assert(M:SetAuraOption('heals', 'perRow', 1) and Point(p1.auraIcons.heals[2])[5] > b[5], 'Per Row 1 wraps upward')
    assert(M:SetAuraOption('heals', 'place', 'outside') and M:SetAuraOption('heals', 'anchor', 'RIGHT'))
    b = Point(p1.auraIcons.heals[1]); assert(b[1]:find('LEFT') and b[3] == 'RIGHT', 'outside right: starts past the right edge')
    -- Borders and glows per group: custom colors, none, a glow by type (off by default).
    assert(M:SetAuraOption('magic', 'border', 'custom') and M:SetAuraOption('magic', 'borderColor', { 1, 0, 0 }) and p1.auraIcons.magic[1].rim.vertexColor[1] == 1)
    assert(M:SetAuraOption('magic', 'border', 'none') and not p1.auraIcons.magic[1].edge.holder:IsShown())
    assert(not p1.auraIcons.magic[1].glow:IsShown() and not p1.auraIcons.magic[1].flash:IsShown(), 'no glow by default')
    assert(M:SetAuraOption('magic', 'glow', 'soft') and p1.auraIcons.magic[1].glow:IsShown() and p1.auraIcons.magic[1].glow.vertexColor[3] == M.db.auraMagicColor[3])
    assert(M:SetAuraOption('magic', 'border', 'type') and M:SetAuraOption('magic', 'borderSize', 2) and p1.auraIcons.magic[1].edge.rim == 2 and not M:SetAuraOption('magic', 'borderSize', 3), 'border size 1 or 2')
    assert(M:SetAuraOption('heals', 'show', false) and not p1.auraIcons.heals[1]:IsShown())
    assert(not M:SetAuraOption('heals', 'filter', 'nonsense') and not M:SetAuraOption('heals', 'width', 99) and not M:SetAuraOption('heals', 'glow', 'blink'), 'validated')
    -- Debuff effects by type: the Gradient rising from the bottom edge by
    -- default (Backlit, Mode-Obsidian; 72% of the health, from 56%), the rim
    -- and the health color when chosen.
    assert(p1.dispel.gradient:IsShown() and p1.dispel.gradient.gradient and p1.panel.edge.tint == nil, 'Magic gradient')
    assert(math.abs(p1.dispel.gradient.height - p1.health.height * 0.72) < 0.01 and Point(p1.dispel.gradient)[1] == 'BOTTOMLEFT')
    assert(math.abs(p1.dispel.gradient.gradient[2].a - 0.56) < 1e-9 and p1.dispel.gradient.gradient[3].a == 0, 'fades out upward')
    assert(M:SetOption('dispelFrom', 'top') and Point(p1.dispel.gradient)[1] == 'TOPLEFT' and math.abs(p1.dispel.gradient.gradient[3].a - 0.56) < 1e-9, 'or from the top edge')
    assert(M:SetOption('dispelFrom', 'bottom'))
    assert(M:SetDispelEffect('Magic', 'health', true) and p1.dispel.health:IsShown() and p1.dispel.health.vertexColor[3] == M.db.auraMagicColor[3])
    assert(M:SetDispelEffect('Magic', 'border', true) and p1.panel.edge.tint == M.db.auraMagicColor, 'the rim in the type color')
    assert(M:SetDispelEffect('Magic', 'border', false) and p1.panel.edge.tint == nil and M:SetDispelEffect('Magic', 'health', false))
    assert(not M:SetDispelEffect('Magic', 'sparkle', true) and not M:SetDispelEffect('Arcane', 'border', true), 'validated')
    assert(M:CopyAuraGroup('otherDebuffs', 'crowdControl') and M.db.auras.crowdControl.anchor == M.db.auras.otherDebuffs.anchor and M.db.auras.crowdControl.filter == 'all')
    assert(M:ResetSettings('heals') and M.db.auras.heals.show and M.db.auras.heals.place == 'inside')

    -- Edit Mode: the stand-in shows the sample party; resizing keeps its top left in place.
    M:SetEditMode(true)
    local ghost = M.ghost
    assert(ghost:IsShown() and #ghost.faces == 5 and ghost.faces[5].texts.status.text == 'Dead', 'sample party')
    assert(ghost.faces[1].icons.leader:IsShown() and ghost.faces[3].panel.edge.tint == M.db.targetColor, 'sample icons and target')
    assert(ghost.faces[1].panel.edge.tint == addon.Style.Tone.reaction.hostile, 'sample aggro')
    assert(ghost.faces[1].auraIcons.heals[1]:IsShown() and ghost.faces[3].health.shield.full:GetAlpha() == 1, 'sample auras and overshield')
    assert(math.abs(ghost.height - (5 * ghost.faces[1].geometry.height + 4 * M.db.spacing)) < 1, 'room for five')
    local x1, y1 = M:GhostCorner()
    assert(M:SetOption('width', 180) and M:SetOption('healthHeight', 60))
    local x2, y2 = M:GhostCorner()
    assert(math.abs(x1 - x2) < 1 and math.abs(y1 - y2) < 1, 'the top left stays put when the size changes')
    M:SetEditMode(false); assert(not ghost:IsShown())
    assert(M:CanTestDisplay() and M:SetTestDisplay(true) and ghost:IsShown() and M:SetTestDisplay(false) and not ghost:IsShown())

    -- The settings page builds on demand; the preview shows one member, or a party or raid.
    SlashCmdList.MODEUI(); addon:SelectConfigPage('partyFrames')
    local page = M.page
    local view = page.configPreview
    assert(page and page:IsShown() and view and page.elementSelect and page.auraGroupSelect and page.dispelToggles and page.borderStyleSelect and page.borderMetalSelect, 'page built')
    local function Shown() local n = 0; for _, face in ipairs(view.faces) do if face:IsShown() then n = n + 1 end end; return n end
    assert(M.previewSample == 'one' and Shown() == 1, 'one member by default')
    assert(#page.previewHeaderButtons == 6 and page.previewStateSelect and M:SetPreviewSample('raid20') and Shown() == 20 and view.faces[1]:GetScale() == 0.5)
    local corner = Point(view.faces[6])
    assert(corner[1] == 'TOPLEFT' and corner[4] > 0, 'the second group beside the first')
    local before = Point(view.group)
    assert(M:SetOption('width', 140) and Point(view.group)[4] == before[4] and Point(view.group)[5] == before[5], 'groups stay put')
    assert(M:SetPreviewSample('one') and not M:SetPreviewSample('raid99'))
    -- Jumps, and the Auras tab's preview: one member with only the group being edited.
    assert(M:JumpTo('element:role') and page.partyElement() == 'role')
    assert(M:JumpTo('auras:curse') and page.partyAuraGroup() == 'curse')
    page:SelectSectionTab(page.jumpTargets.auras.section)
    assert(M:PreviewAuraGroup() == 'curse' and Shown() == 1 and view.faces[1].auraIcons.curse[1]:IsShown(), 'the edited group')
    assert(not view.faces[1].auraIcons.otherDebuffs[1]:IsShown(), 'other groups hidden')
    -- Nudges: one pixel per click, within range.
    local x = M.db.auras.curse.x
    page.auraNudge[4]:GetScript('OnClick')(page.auraNudge[4]); assert(M.db.auras.curse.x == x + 1, 'right one pixel')
    page.auraNudge[2]:GetScript('OnClick')(page.auraNudge[2]); assert(M.db.auras.curse.y == 1, 'up one pixel')
    assert(M:JumpTo('health'))
    -- Clicking an aura in the preview opens the Auras tab at its group (it took clicks away from the health bar).
    page:SelectSectionTab(page.jumpTargets.health.section)
    local sample = view.faces[1]
    local icon = sample.auraIcons.heals[1]
    assert(icon:IsShown() and icon.mouse == true and icon.jump == 'auras:heals', 'the icon takes the click')
    icon:GetScript('OnMouseUp')(icon, 'LeftButton')
    assert(M:PreviewSection() == 'Auras' and page.partyAuraGroup() == 'heals', 'auras open, not Bars')
    -- The Auras tab: Buffs and Debuffs, and a quick list of that kind's groups beside the sample.
    assert(view.quick:IsShown() and view.quickRows[1].group == 'heals' and view.quickRows[4].add:IsShown(), 'buff groups, + on tracked')
    page.SetAuraKind('debuffs')
    assert(page.partyAuraGroup() == 'dispellable' and view.quickRows[1].group == 'dispellable' and not view.quickRows[1].add:IsShown())
    view.quickRows[2]:GetScript('OnClick')(view.quickRows[2]); assert(page.partyAuraGroup() == 'magic', 'the quick list picks the group')
    page.SetAuraGroup('tracked2')
    assert(M:OpenPicker('tracked2', view.quickRows[5].add) and M.picker:IsShown() and #M.picker.buttons >= 1, '+ opens the picker')
    local pick = M.picker.buttons[1]
    pick:GetScript('OnClick')(pick); assert(#M.db.auras.tracked2.spells == 1, 'clicking a buff adds it')
    M.picker:Hide()
    -- Each tab shows what it edits on the first sample, and stops when you leave it.
    assert(M:SetDispelEffect('Magic', 'border', true))
    page:SelectSectionTab(page.jumpTargets.dispel.section)
    assert(M:PreviewSection() == 'Highlights and Overlay' and not view.quick:IsShown())
    assert(view.faces[1].panel.edge.tint == M.db.auraMagicColor and view.faces[1].dispel.gradient:IsShown(), 'dispel overlay previewed')
    page.SetDispelType('Curse'); assert(view.faces[1].dispel.gradient.gradient[3].r == M.db.auraCurseColor[1] and view.faces[1].panel.edge.tint ~= M.db.auraCurseColor, 'the picked type (Curse: Gradient only)')
    page:SelectSectionTab(page.jumpTargets.health.section)
    assert(view.faces[1].panel.edge.tint ~= M.db.auraCurseColor and not view.faces[1].dispel.gradient:IsShown(), 'gone on another tab')
    -- Shields have their own tab: a shield on the first sample; with the
    -- Overshield state, the whole shield back from full health.
    page:SelectSectionTab(page.jumpTargets.shields.section)
    assert(M:PreviewSection() == 'Shields' and view.faces[1].health.shield.attached.value == 14, 'shield previewed')
    M.previewStates.overshield = true; page:SelectSectionTab(page.jumpTargets.shields.section)
    assert(view.faces[1].health.shield.full:GetAlpha() == 1 and view.faces[1].health.shield.full.value == 24, 'overshield previewed')
    assert(M:SetOption('showOvershields', false) and view.faces[1].health.shield.full:GetAlpha() == 0 and M:SetOption('showOvershields', true))
    M.previewStates.overshield = nil
    -- The look reaches the shield: texture, custom color, opacity (10-200%).
    assert(M:SetOption('shieldsTexture', 'FG') and view.faces[1].health.shield.look.texture == 'FG' and not M:SetOption('shieldsTexture', 'Glass'), 'Mode-FG; a retired texture is refused')
    assert(view.faces[1].health.shield.attachedLines.texture:find('FG'), 'the lines take the texture')
    assert(M:SetOption('shieldsColorMode', 'custom') and view.faces[1].health.shield.look.color == M.db.shieldsColor)
    assert(M:SetOption('shieldsOpacity', 150) and view.faces[1].health.shield.look.opacity == 1.5 and not M:SetOption('shieldsOpacity', 250))
    assert(math.abs(view.faces[1].health.shield.attachedLift.vertexColor[4] - 0.63) < 1e-6, 'lift at 150% of 42%')
    assert(M:SetOption('shieldsTexture', 'Shield') and M:SetOption('shieldsColorMode', 'health') and M:SetOption('shieldsOpacity', 100))
    page:SelectSectionTab(page.jumpTargets.element.section); page.SetElement('readyCheck')
    assert(view.faces[1].icons.readyCheck:IsShown(), 'ready check previewed')
    page:SelectSectionTab(page.jumpTargets.power.section)
    assert(M:SetOption('powerShown', 'healerMana') and view.faces[1].power:IsShown(), 'a healer with mana on the power tab')
    assert(M:SetOption('powerTextShow', true) and view.faces[1].powerText.text == '70%' and M:SetOption('powerOpacity', 50))
    assert(view.faces[1].power.statusBarColor[4] == 0.5 and M:SetOption('powerShown', 'all'))
    -- Show: states on every sample.
    assert(M:TogglePreviewState('dead') and view.faces[1].texts.status.text == 'Dead' and M:TogglePreviewState('dead'))
    assert(view.faces[1].texts.status.text == '' and not M:TogglePreviewState('sparkles'))
    -- Party: five members fit; the preview grows to hold them.
    assert(M:SetPreviewSample('party') and Shown() == 5)
    local _, height = M:GetPreviewSize()
    local last = view.faces[5]
    assert(height >= 5 * last.geometry.height * last:GetScale() + 24, 'tall enough for five')
    -- Arrange: Vertical or Horizontal.
    assert(page.arrangePills and M:SetOption('growth', 'right') and M.header.attributes.point == 'LEFT')
    assert(M:SetOption('growth', 'down'))
]==], "party_auras")

local CONTAINERS = STUBS .. [==[
    C_XMLUtil = { GetTemplateInfo = function(name) if name == 'CustomAuraContainerTemplate' then return {} end end }
    Enum.CustomAuraButtonDispelTypeTextureStyle = { PreserveAsset = 3 }
    Enum.LuaCurveType = { Linear = 0, Step = 1 }
    C_CurveUtil = { CreateColorCurve = function()
        local curve = { points = {} }
        function curve:SetType(t) self.type = t end
        function curve:AddPoint(x, color) self.points[x] = color end
        return curve
    end }
    containers = {}
    local createFrame = CreateFrame
    local function Button(parent)
        local button = createFrame('Frame', nil, parent)
        function button:SetIcon(t) self.iconRegion = t end
        function button:SetDurationCooldown(cd) self.cooldownRegion = cd end
        function button:SetApplicationCount(fs) self.countRegion = fs end
        function button:AddDispelTypeTexture(t, o)
            -- As Blizzard's AddDisplayElement: a list; the same texture twice is an error.
            self.dispelTextures = self.dispelTextures or {}
            for _, held in ipairs(self.dispelTextures) do assert(held ~= t, 'Display element has already been added.') end
            self.dispelTextures[#self.dispelTextures + 1] = t; self.dispelOptions = o
        end
        function button:SetDurationText(fs, o) self.timerRegion, self.timerOptions = fs, o end
        function button:SetMouseClickEnabled(on) self.clicks = on end
        return button
    end
    function CreateFrame(kind, name, parent, template)
        if kind ~= 'AuraContainer' then return createFrame(kind, name, parent, template) end
        local c = createFrame('Frame', name, parent)
        c.template, c.groups, c.slots = template, {}, {}
        function c:AddAuraGroup(key, filter, options)
            assert(not self.groups[key], 'groups are added once')
            local button = Button(self)
            options.initializeFrame(button)
            self.groups[key] = { filter = filter, options = options, enabled = true, max = options.maxFrameCount, button = button }
        end
        function c:AddAuraSlot(key, filter, options)
            local button = Button(self)
            options.initializeFrame(button)
            self.slots[key] = { filter = filter, button = button, options = options }
            return button
        end
        function c:SetAuraGroupFilterString(key, f) self.groups[key].filter = f end
        function c:SetAuraGroupMaxFrameCount(key, n) self.groups[key].max = n end
        function c:SetAuraGroupLayout(key, l) self.groups[key].layout = l end
        -- As Blizzard_AuraContainer: candidate filters always read the auras
        -- again; the enabled state and the unit do when they change.
        function c:UpdateAllAuras() self.updates = (self.updates or 0) + 1 end
        function c:SetAuraGroupCandidateFilters(key, f) self.groups[key].candidates = f; self:UpdateAllAuras() end
        function c:SetAuraGroupEnabled(key, on) self.groups[key].enabled = on end
        function c:SetEnabled(on) if self.enabled ~= on then self.enabled = on; self:UpdateAllAuras() end end
        function c:SetUnit(unit) if self.unit ~= unit then self.unit = unit; self:UpdateAllAuras() end end
        function c:SetFlowLayoutAnchorPoint(p) self.flowAnchor = p end
        function c:SetFlowLayoutAxis(a) self.axis = a end
        function c:SetFlowLayoutGrowthDirection(h, v) self.growth = { h, v } end
        function c:SetFlowLayoutMaximumLineSize(n) self.lineSize = n end
        containers[#containers + 1] = c
        return c
    end
]==]
H.Load({ before = CONTAINERS }).run([==[
    local M = addon.PartyFrames
    addon:SetModuleEnabled('partyFrames', true)
    local p1 = M.members[2]
    local C = p1.auraContainers
    -- One container per anchor and place; the debuff types and Other Debuffs share the bottom left.
    local row = C['BOTTOMLEFT|inside']
    assert(C['BOTTOMRIGHT|inside'] and row and C['CENTER|inside'] and row.template == 'CustomAuraContainerTemplate', 'one container per anchor')
    assert(row.enabled and row.unit == 'party1' and row.updates >= 1, 'pointed at the unit')
    assert(row.groups.dispellable1.filter == 'HARMFUL|RAID' and row.groups.dispellable1.options.candidateFilters == nil, 'dispellable by you first')
    assert(row.groups.magic1.options.candidateFilters.includeDispelTypes.Magic and row.groups.magic1.filter == 'HARMFUL|!RAID', 'magic by type')
    assert(row.groups.otherDebuffs1.options.candidateFilters.excludeDispelTypes.Curse and row.groups.otherDebuffs1.filter == 'HARMFUL|RAID_IN_COMBAT')
    local heals = C['BOTTOMRIGHT|inside']
    assert(heals.groups.heals1.filter == 'HELPFUL|RAID_IN_COMBAT' and not heals.groups.heals2.enabled)
    assert(C['CENTER|inside'].groups.defensives2.filter == 'HELPFUL|BIG_DEFENSIVE' and C['CENTER|inside'].groups.defensives2.enabled)
    assert(not C['TOPRIGHT|inside'].enabled and not C['LEFT|outside'].enabled, 'group buffs and crowd control start off')
    local button = row.groups.magic1.button
    assert(button.iconRegion == button.icon and button.countRegion == button.count and button.dispelTextures[1] == button.rim)
    assert(button.dispelOptions.customDispelColorCurve.points[1].r == M.db.auraMagicColor[1] and button.clicks == false)
    assert(row.flowAnchor == 'BOTTOMLEFT' and Point(row)[2] == p1.panel and row.lineSize > 0, 'placed by the first shown group')
    -- A glow by type registers the glow with the game's dispel colors.
    assert(M:SetAuraOption('magic', 'glow', 'gcd') and p1.auraContainers['BOTTOMLEFT|inside'] ~= row and not row.enabled, 'look change: new container')
    local glowing = p1.auraContainers['BOTTOMLEFT|inside'].groups.magic1.button
    assert(glowing.dispelTextures[9] == glowing.flash and glowing.flash:IsShown(), 'glow by type, after the eight rim pieces')
    -- Moving one type gives it a container of its own.
    assert(M:SetAuraOption('curse', 'anchor', 'TOPLEFT') and p1.auraContainers['TOPLEFT|inside'].groups.curse1)
    assert(p1.auraContainers['BOTTOMLEFT|inside'].groups.curse1 == nil, 'out of the shared row')
    -- Debuff effects: one aura slot per type, kept to it by the game.
    local slots = p1.dispelContainer
    assert(slots and slots.slots.Magic.filter == 'HARMFUL|RAID' and slots.slots.Magic.options.candidateFilters.includeDispelTypes.Magic)
    assert(slots.unit == 'party1' and slots.enabled and slots.slots.Bleed)
    local sb = slots.slots.Magic.button
    assert(sb.dispelEffects.gradient:IsShown() and not sb.dispelEffects.rim.holder:IsShown(), 'the slot holds the Gradient')
    assert(not sb.dispelEffects.health:IsShown() and #(sb.dispelEffects.health.masks or {}) == 0, 'nothing masked')
    assert(M:SetDispelEffect('Magic', 'border', true) and p1.dispelContainer.slots.Magic.button.dispelEffects.rim.tint == M.db.auraMagicColor)
    -- The dispel rim takes the Border Style's shape (in the type's color).
    assert(p1.dispelContainer.slots.Magic.button.dispelEffects.rim.styleId == 'obsidian')
    local before = p1.dispelContainer
    assert(M:SetOption('edgeStyle', 'obsidianEmpty') and p1.dispelContainer ~= before, 'a new style: new slots')
    local rim = p1.dispelContainer.slots.Magic.button.dispelEffects.rim
    assert(rim.styleId == 'obsidianEmpty' and rim.tint == M.db.auraMagicColor and M:SetOption('edgeStyle', 'obsidian'))
    slots = p1.dispelContainer
    assert(M:SetDispelEffect('Curse', 'health', true) and p1.dispelContainer ~= slots and p1.dispelContainer.slots.Curse.button.dispelEffects.health:IsShown())
    for _, kind in ipairs(M.dispelTypes) do
        assert(M:SetDispelEffect(kind, 'border', false) and M:SetDispelEffect(kind, 'health', false) and M:SetDispelEffect(kind, 'gradient', false))
    end
    assert(next(p1.dispelContainer.slots) == nil, 'no effects: no slots')
    -- Overshields through the heal prediction calculator: shown when the shield overflows.
    function CreateUnitHealPredictionCalculator()
        local c = {}
        function c:GetMaximumHealth() return Secret('max') end
        function c:GetIncomingHeals() return Secret('heal') end
        function c:GetDamageAbsorbs() return Secret('shield'), Secret('over') end
        function c:GetTotalDamageAbsorbs() return Secret('total') end
        return c
    end
    function UnitGetDetailedHealPrediction(unit, healer, calc) assert(healer == 'player') end
    for _, f in ipairs(M.members) do f.calculator = nil end
    FireEvent('UNIT_ABSORB_AMOUNT_CHANGED', 'party1')
    local shield = p1.health.shield
    assert(shield.attached.value.label == 'shield' and shield.full.value.label == 'total' and p1.healPrediction.value.label == 'heal')
    -- Tracked Buffs: kept to their spells by the game; Healing Buffs leaves them out.
    local top = p1.auraContainers['TOPRIGHT|inside']
    assert(not top.groups.tracked11.enabled, 'an empty tracked group shows nothing')
    assert(M:AddTrackedSpell('tracked1', 774))
    top = p1.auraContainers['TOPRIGHT|inside']
    assert(top.groups.tracked11.enabled and top.groups.tracked11.candidates.includeSpellIDs[774], 'tracked by spell ID')
    assert(p1.auraContainers['BOTTOMRIGHT|inside'].groups.heals1.candidates.excludeSpellIDs[774], 'left out of Healing Buffs')
    roster = { 'party2' }; GroupChanged()
    assert(M.members[2].auraContainers['BOTTOMRIGHT|inside'].unit == 'party2', 'containers follow the unit')
    -- Joining a group: the header hands every button its unit again on each
    -- roster and name event. The same units read no auras again, and a burst
    -- waits for one pass on the next frame.
    local function Reads() local n = 0; for _, c in ipairs(containers) do n = n + (c.updates or 0) end; return n end
    local reads = Reads()
    for _ = 1, 20 do FireEvent('GROUP_ROSTER_UPDATE'); M.header.scripts.OnEvent(M.header, 'UNIT_NAME_UPDATE', 'nameplate1') end
    assert(Reads() == reads, 'the same units: no aura work')
    local pending, after, update, redraws = {}, C_Timer.After, M.UpdateMember, 0
    C_Timer.After = function(_, fn) pending[#pending + 1] = fn end
    M.UpdateMember = function(...) redraws = redraws + 1; return update(...) end
    for _ = 1, 10 do FireEvent('GROUP_ROSTER_UPDATE') end
    assert(#pending == 1 and redraws == 0, 'a burst waits for the next frame')
    pending[1]()
    assert(redraws == #M.members and Reads() == reads, 'each member redrawn once')
    C_Timer.After, M.UpdateMember = after, update
    -- Someone else behind the same unit: its auras are read again, once.
    local guid = UnitGUID
    UnitGUID = function(u) return u == 'party2' and 'Player-Other' or guid(u) end
    FireEvent('GROUP_ROSTER_UPDATE')
    local more = Reads()
    assert(more > reads, 'a new person: auras read again')
    FireEvent('GROUP_ROSTER_UPDATE')
    assert(Reads() == more, 'then nothing more')
    UnitGUID = guid
]==], "party_containers")

-- Version 1 settings move to version 2: old default sizes take the new ones,
-- Buffs becomes Healing Buffs, Debuffs' place goes to every type, the dispel
-- highlight style to the effects.
local v1 = world.saved()
local pf = v1.profiles.Default.modules.partyFrames
for key in pairs(pf) do if key ~= 'enabled' then pf[key] = nil end end
pf.version, pf.healthHeight, pf.powerHeight, pf.width, pf.dispelHighlight = 1, 34, 5, 150, 'fill'
pf.auras = { buffs = { show = true, filter = 'mine', anchor = 'TOPLEFT', place = 'inside', grow = 'right', x = 2, y = 0, size = 20,
    max = 4, perRow = 4, spacing = 1, shape = 'cropped', border = 'mode', timer = true, timerText = false, count = true, tooltip = true },
    debuffs = { show = true, filter = 'all', anchor = 'BOTTOMRIGHT', place = 'outside', grow = 'down', x = 0, y = 0, size = 16,
    max = 3, perRow = 3, spacing = 2, shape = 'square', border = 'type', timer = true, timerText = true, count = true, tooltip = true } }
H.Load({ before = STUBS, saved = v1 }).run([==[
    local db = addon.PartyFrames.db
    assert(db.version == 7 and db.healthHeight == 34 and db.powerHeight == 3 and db.width == 150 and db.spacing == 1, 'old defaults move, picked values stay')
    local heals = db.auras.heals
    assert(heals.anchor == 'TOPLEFT' and heals.width == 20 and heals.height == 16 and heals.filter == 'mine' and heals.border == 'mode' and heals.size == nil)
    for _, group in ipairs({ 'magic', 'curse', 'disease', 'poison', 'bleed', 'otherDebuffs' }) do
        local g = db.auras[group]
        assert(g.anchor == 'BOTTOMRIGHT' and g.place == 'outside' and g.grow == 'down' and g.width == 16 and g.height == 16, group)
    end
    assert(db.auras.otherDebuffs.filter == 'all' and db.auras.magic.filter == 'notMine' and db.auras.buffs.show == false)
    -- Version 3: Dispellable by You takes the Magic group's place, first in its row.
    local d = db.auras.dispellable
    assert(d.anchor == 'BOTTOMRIGHT' and d.place == 'outside' and d.grow == 'down' and d.width == 16 and d.filter == 'mine' and d.show)
    assert(db.powerOpacity == 100 and db.powerBackgroundOpacity == 85 and db.auras.tracked1.spells[1] == nil, 'the empty part at the default (Mode-Obsidian: 85)')
    assert(db.dispelHighlight == nil and db.dispel.Magic.gradient and not db.dispel.Magic.border, 'fill became the gradient')
]==], "party_v1")

-- Version 3 -> 4: values at the version 3 defaults take the Mode ones, the
-- player's own choices stay, Border, Corner Size and the shield looks retire.
local v3 = world.saved()
local p3 = v3.profiles.Default.modules.partyFrames
p3.version, p3.width, p3.healthHeight, p3.powerHeight, p3.borderStyle, p3.corner = 3, 132, 60, 6, 'thin', 9
p3.foregroundTexture, p3.backgroundTexture, p3.fontMedia, p3.liftedShadow, p3.nameColorMode = 'mode', 'slate', 'Expressway', true, 'custom'
p3.shieldTexture, p3.absorbColor, p3.overshieldOpacity, p3.rangeOpacity = 'slateHatch', { 1, 1, 1 }, 80, 45
p3.nameAnchor, p3.nameX, p3.nameY, p3.nameSize = 'TOPLEFT', 3, -3, 11
p3.healthTextAnchor, p3.healthTextX, p3.healthTextY, p3.healthTextSize = 'TOP', 0, 0, 10
p3.dispel = { Magic = { border = true, health = false, gradient = false }, Curse = { border = true, health = true, gradient = false } }
H.Load({ before = STUBS, saved = v3 }).run([==[
    local db, M = addon.PartyFrames.db, addon.PartyFrames
    assert(db.version == 7 and db.width == 150 and db.healthHeight == 60 and db.powerHeight == 3, 'defaults move, a picked height stays')
    assert(db.borderStyle == nil and db.corner == nil and db.shieldTexture == nil and db.absorbColor == nil and db.overshieldOpacity == nil, 'retired')
    assert(db.foregroundTexture == 'media:Mode-FG' and db.backgroundTexture == 'media:Mode-BG' and db.fontMedia == 'Mode')
    assert(db.liftedShadow == false and db.nameColorMode == 'custom' and db.rangeOpacity == 55, 'a picked name color stays')
    assert(db.nameAnchor == 'LEFT' and db.nameX == 17 and db.healthTextAnchor == 'TOP', 'elements at the old place move; moved ones stay')
    assert(db.dispel.Magic.gradient and not db.dispel.Magic.border, 'border alone was the default: Gradient now')
    assert(db.dispel.Curse.border and db.dispel.Curse.health and not db.dispel.Curse.gradient, 'a picked set stays')
]==], "party_v3")

-- Version 4 -> 5: Mode Gradient health (the version 4 default) becomes the
-- default (Mode-FG now); another picked texture stays.
for _, case in ipairs({ { 'media:Mode Gradient', 'media:Mode-FG' }, { 'media:Mode Matte', 'media:Mode Matte' } }) do
    local v4 = world.saved()
    local p4 = v4.profiles.Default.modules.partyFrames
    p4.version, p4.foregroundTexture = 4, case[1]
    p4.shieldsTexture, p4.shieldsColorMode, p4.shieldsColor, p4.shieldsOpacity = nil, nil, nil, nil
    local loaded = H.Load({ before = STUBS, saved = v4 })
    loaded.run("local db = addon.PartyFrames.db; assert(db.version == 7 and db.foregroundTexture == '" .. case[2] ..
        "' and db.shieldsTexture == 'Shield' and db.shieldsOpacity == 100, 'v4 -> v5: ' .. db.foregroundTexture)", "party_v4")
end

-- Version 5 -> 6: auras wear the frameThin edge: Border Size 3 becomes 2,
-- the old no-type rim takes the Gunmetal one, a picked color stays.
local v5 = world.saved()
local p5 = v5.profiles.Default.modules.partyFrames
p5.version, p5.auras.magic.borderSize, p5.auras.curse.borderSize = 5, 3, 1
p5.auraNoTypeColor = { 64 / 255, 69 / 255, 76 / 255 }
H.Load({ before = STUBS, saved = v5 }).run([==[
    local db = addon.PartyFrames.db
    assert(db.version == 7 and db.auras.magic.borderSize == 2 and db.auras.curse.borderSize == 1, 'size 3 becomes 2')
    assert(addon.Style.SameColor(db.auraNoTypeColor, addon.Style.Tone.gunmetal.mid), 'the Gunmetal no-type rim')
]==], "party_v5")

-- Version 6 -> 7: solid empty bars (100) take the see-through 60; picked values stay.
local v6 = world.saved()
local p6 = v6.profiles.Default.modules.partyFrames
p6.version, p6.backgroundOpacity, p6.powerBackgroundOpacity = 6, 100, 35
p6.edgeStyle, p6.edgeMetal = nil, nil
H.Load({ before = STUBS, saved = v6 }).run([==[
    local db = addon.PartyFrames.db
    assert(db.version == 7 and db.backgroundOpacity == 60 and db.powerBackgroundOpacity == 35, '100 becomes 60')
    assert(db.edgeStyle == 'obsidian' and db.edgeMetal == 'default', 'the border keys arrive with their defaults')
]==], "party_v6")

-- Invalid saved settings stop validation instead of being reset.
local broken = world.saved()
broken.profiles.Default.modules.partyFrames.width = 'wide'
assert(not pcall(H.Load, { before = STUBS, saved = broken }), 'invalid party settings are refused, not reset')
local saved = world.saved()
saved.profiles.Default.modules.partyFrames.auras.heals.anchor = 'NOWHERE'
assert(not pcall(H.Load, { before = STUBS, saved = saved }), 'invalid aura group refused')
print("party frames: all checks passed")

-- The Mode-DPS/TANK layout (DPS / Tank, Modules/PartyFrames/Layouts.lua): the
-- values it writes at both screen heights, then the stand-in Edit Mode moves
-- in a world that uses the profile.
local layoutWorld = H.Load({ before = STUBS })
layoutWorld.run([==[
    local M = addon.PartyFrames
    local ICONS = { heals = '18x12', defensives = '22x16', dispellable = '20x14', otherDebuffs = '20x14', magic = '20x14',
        curse = '20x14', disease = '20x14', poison = '20x14', bleed = '20x14', crowdControl = '24x18', buffs = '16x10',
        tracked1 = '16x10', tracked2 = '16x10', tracked3 = '16x10' }
    for variant, y in pairs({ ['1080'] = 40, ['1440'] = -1 }) do
        local profile = assert(addon.Layouts:Build('mode-default', variant))
        local db, p = profile.modules.partyFrames, profile.positions.partyFrames
        assert(db.enabled == true and db.width == 136 and db.healthHeight == 30 and db.powerHeight == 3 and db.powerStyle == 'below')
        assert(db.spacing == 1 and db.growth == 'down' and db.showPlayer == false and db.powerShown == 'healers')
        assert(db.healthColorMode == 'default', 'health in Dark (owner, November 18, 2026)')
        assert(db.foregroundTexture == 'media:Mode-FG' and db.backgroundTexture == 'media:Mode-BG' and db.edgeStyle == 'obsidian' and db.edgeMetal == 'default', 'the Mode-Obsidian look after the layout')
        for group, size in pairs(ICONS) do
            local a = db.auras[group]
            assert(a.width .. 'x' .. a.height == size and a.width - a.height == 6, group)
        end
        -- Buffs: Big Defensives only (owner, November 18, 2026); debuffs keep their defaults.
        for _, group in ipairs(M.buffGroups) do
            assert(db.auras[group].show == (group == 'defensives'), group .. ': only the defensives show')
        end
        assert(db.auras.defensives.filter == 'big' and db.auras.dispellable.show and db.auras.otherDebuffs.show, 'Big Defensives; debuffs as they were')
        -- Everything else keeps its default.
        assert(db.auras.heals.anchor == 'BOTTOMRIGHT' and db.auras.heals.max == 3 and db.scale == 100 and db.sortBy == 'group')
        -- Every member 36 tall with its rim: 30 health, the 1px line, 3 power, 1px rim top and bottom.
        local g = M.Geometry({ db = db }, 1)
        assert(g.height == 36 and g.width == 136 and g.healthHeight == 30 and g.innerHeight == 34)
        -- The stand-in is a full party (5 x 36 + 4 = 184); the four members take
        -- its top 147, their middle at y, so its own middle is 18.5 lower (rounded).
        assert(p.target == 'screen' and p.point == 'RIGHT' and p.relativePoint == 'CENTER' and p.x == -359 and p.y == y - 18,
            variant .. ': ' .. tostring(p.x) .. ',' .. tostring(p.y))
    end
]==], "party_layout")
-- Only this module's part (and its places) go into the Default profile, so
-- the check stays on these frames whatever other modules add to the layout.
local used = layoutWorld.saved()
local built, default = used.profiles['Mode-DPS/TANK'], used.profiles.Default
default.modules.partyFrames = built.modules.partyFrames
for _, id in ipairs({ 'partyFrames' }) do default.positions[id] = built.positions[id] end
H.Load({ before = STUBS, saved = used }).run([==[
    local M = addon.PartyFrames
    assert(M.active and M.ghost, 'party frames on')
    local ghost = M.ghost
    local x, y = ghost:GetCenter()
    local ux, uy = UIParent:GetCenter()
    assert(ghost:GetWidth() == 136 and ghost:GetHeight() == 184, 'room for five')
    local right, top = x + 68 - ux, y + 92 - uy
    assert(right == -359 and top == 114, 'right edge at -359 (the Player portrait), the top 74 over 40')
    -- Four members from the top: 4 x 36 + 3 = 147, their middle half a pixel over 40.
    assert(top - 147 / 2 == 40.5)
    -- The secure header hangs by its top on the stand-in's top middle (from
    -- UIParent's BOTTOMLEFT): members centered on it line up with the stand-in.
    local point, _, relative, hx, hy = unpack(M.header.anchor)
    assert(point == 'TOP' and relative == 'BOTTOMLEFT' and hx == ghost:GetLeft() + 68 and hy == ghost:GetBottom() + 184)
    assert(M.header:GetAttribute('showPlayer') == false and M.header:GetAttribute('point') == 'TOP', 'four members, from the top')
]==], "party_layout_world")
print("party frames: Mode-DPS/TANK layout checks passed")
