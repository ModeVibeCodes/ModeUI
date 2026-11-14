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
    assert(M.db.version == 1 and M.db.fontMedia == 'Expressway' and M.db.foregroundTexture == 'mode' and M.db.backgroundTexture == 'slate')
    assert(M.db.nameShow and M.db.nameAnchor == 'TOPLEFT' and M.db.leaderPlace == 'outside' and M.db.auras.buffs.filter == 'mine')
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
    assert(p1.health.value.label == 'p1hp' and p1.health.high.label == 'p1max', 'secret health straight to the bar')
    assert(p1.texts.name.text.label == 'p1name', 'secret name straight to SetText')
    assert(p1.healPrediction.value.label == 'heals' and p1.absorb.value.label == 'absorbs', 'heals and absorbs ride on health')
    assert(Point(p1.healPrediction)[2] == p1.health:GetStatusBarTexture() and Point(p1.absorb)[2] == p1.healPrediction:GetStatusBarTexture())
    assert(p1.alphaFromBoolean and p1.alphaFromBoolean[1].label == 'range' and p1.alphaFromBoolean[3] == 0.45, 'secret range via SetAlphaFromBoolean')
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
    -- Your target: the border in the highlight color.
    targetUnit = 'party2'; FireEvent('PLAYER_TARGET_CHANGED')
    assert(tank.isTarget and tank.targetRing.top:IsShown() and not p1.targetRing.top:IsShown())
    targetUnit = nil; FireEvent('PLAYER_TARGET_CHANGED'); assert(not tank.targetRing.top:IsShown())

    -- Healers-only power: the tank's health takes the whole height.
    assert(M:SetOption('powerShown', 'healers') and p1.power:IsShown() and not tank.power:IsShown())
    assert(tank.health.height == tank.geometry.innerHeight and p1.health.height < p1.geometry.innerHeight)
    assert(M:SetOption('powerShown', 'all') and tank.power:IsShown())

    -- Layout: role sort, reverse, growth and spacing through header attributes.
    assert(M:SetOption('sortBy', 'role') and h.attributes.groupBy == 'ASSIGNEDROLE' and h.attributes.groupingOrder == 'TANK,HEALER,DAMAGER,NONE')
    assert(M.members[1].unit == 'party2' and M.members[2].unit == 'party1' and M.members[3].unit == 'player', 'tank, healer, damage')
    assert(M.members[1].icons.role.atlas == 'roleicon-tiny-tank', 'icons follow the new unit')
    assert(M:SetOption('sortBy', 'group') and h.attributes.groupBy == nil)
    assert(M:SetOption('reverseOrder', true) and M.members[1].unit == 'party2' and M:SetOption('reverseOrder', false))
    assert(M:SetOption('growth', 'right') and h.attributes.point == 'LEFT' and h.attributes.xOffset > 0 and h.attributes.yOffset == 0)
    assert(Point(h)[1] == 'LEFT', 'the header is anchored at the edge it grows from')
    assert(M:SetOption('spacing', 10) and h.attributes.xOffset == 10 and M:SetOption('growth', 'down'))
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
    assert(M:SetElementOption('healthText', 'show', true) and p1.texts.healthText.text.secret, 'secret percent text')

    -- Hide Blizzard off, and switching the module off, put PartyFrame back.
    assert(M:SetOption('hideBlizzard', false) and PartyFrame.parent == UIParent)
    assert(M:SetOption('hideBlizzard', true) and PartyFrame.parent == M.hiddenParent)
    addon:SetModuleEnabled('partyFrames', false)
    assert(PartyFrame.parent == UIParent and drivers[h] == nil and not h:IsShown(), 'off: header hidden, Blizzard back')
    assert(next(p1.events.events) == nil, 'member events off')
    addon:SetModuleEnabled('partyFrames', true)
    assert(h:IsShown() and PartyFrame.parent == M.hiddenParent and M.members[2].unit == 'party1')
]==], "party_header")

-- The aura manager without containers (reader path) and the samples.
world.run([==[
    local M = addon.PartyFrames
    local p1 = M.members[2]
    units.party1.helpful = { { icon = 'renew', auraInstanceID = 11, duration = 0, expirationTime = 0 },
        { icon = 'fort', auraInstanceID = 12, duration = 0, expirationTime = 0 } }
    units.party1.harmful = { { icon = 'pain', auraInstanceID = 21, dispelName = 'Magic', duration = 0, expirationTime = 0 } }
    auraFilters = {}
    FireEvent('UNIT_AURA', 'party1')
    assert(p1.auraIcons.buffs[1]:IsShown() and p1.auraIcons.buffs[1].icon.texture == 'renew' and p1.auraIcons.buffs[2]:IsShown())
    assert(p1.auraIcons.debuffs[1]:IsShown() and p1.auraIcons.debuffs[1].rim.vertexColor[3] == M.db.auraMagicColor[3], 'rim by type')
    local seen = table.concat(auraFilters, ',')
    assert(seen:find('HELPFUL|PLAYER', 1, true) and seen:find('HARMFUL|RAID_IN_COMBAT', 1, true) and seen:find('HELPFUL|EXTERNAL_DEFENSIVE', 1, true), seen)
    -- Placement: buffs at the bottom right inside, growing left.
    local b = Point(p1.auraIcons.buffs[1]); assert(b[1] == 'BOTTOMRIGHT' and b[2] == p1.panel and b[3] == 'BOTTOMRIGHT' and b[4] < 0 and b[5] > 0)
    local b2 = Point(p1.auraIcons.buffs[2]); assert(b2[4] < b[4] and b2[5] == b[5], 'second buff to the left')
    assert(M:SetAuraOption('buffs', 'perRow', 1) and Point(p1.auraIcons.buffs[2])[5] > b[5], 'Per Row 1 wraps upward')
    assert(M:SetAuraOption('buffs', 'place', 'outside') and M:SetAuraOption('buffs', 'anchor', 'RIGHT'))
    b = Point(p1.auraIcons.buffs[1]); assert(b[1]:find('LEFT') and b[3] == 'RIGHT', 'outside right: starts past the right edge')
    assert(M:SetAuraOption('buffs', 'show', false) and not p1.auraIcons.buffs[1]:IsShown())
    assert(not M:SetAuraOption('buffs', 'filter', 'nonsense') and not M:SetAuraOption('buffs', 'size', 99), 'validated')
    -- The dispel highlight from a public type.
    assert(p1.dispelRing.top:IsShown() and p1.dispelRing.top.vertexColor[3] == M.db.auraMagicColor[3], 'dispel border in the type color')
    assert(M:SetOption('dispelHighlight', 'fill') and p1.dispelFill:IsShown() and not p1.dispelRing.top:IsShown())
    assert(M:CopyAuraGroup('debuffs', 'crowdControl') and M.db.auras.crowdControl.anchor == M.db.auras.debuffs.anchor and M.db.auras.crowdControl.filter == 'all')
    assert(M:ResetSettings('buffs') and M.db.auras.buffs.show and M.db.auras.buffs.place == 'inside')

    -- Edit Mode: the stand-in shows the sample party and moves the header.
    M:SetEditMode(true)
    local ghost = M.ghost
    assert(ghost:IsShown() and #ghost.faces == 5 and ghost.faces[5].texts.status.text == 'Dead', 'sample party')
    assert(ghost.faces[1].icons.leader:IsShown() and ghost.faces[3].targetRing.top:IsShown(), 'sample icons and target')
    assert(ghost.faces[1].auraIcons.buffs[1]:IsShown(), 'sample auras')
    assert(math.abs(ghost.height - (5 * ghost.faces[1].geometry.height + 4 * M.db.spacing)) < 1, 'room for five')
    M:SetEditMode(false); assert(not ghost:IsShown())
    assert(M:CanTestDisplay() and M:SetTestDisplay(true) and ghost:IsShown() and M:SetTestDisplay(false) and not ghost:IsShown())

    -- The settings page builds on demand, with every tab, and the preview jumps.
    SlashCmdList.MODEUI(); addon:SelectConfigPage('partyFrames')
    local page = M.page
    assert(page and page:IsShown() and page.configPreview and page.elementSelect and page.auraGroupSelect, 'page built')
    assert(M:JumpTo('element:role') and page.partyElement() == 'role')
    assert(M:JumpTo('auras:defensives') and page.partyAuraGroup() == 'defensives')
    assert(M:JumpTo('health'))
]==], "party_auras")

-- 12.1 aura containers: groups and the dispel highlight drawn by the game.
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
        function button:AddDispelTypeTexture(t, o) self.dispelTextures = self.dispelTextures or {}; self.dispelTextures[#self.dispelTextures + 1] = t; self.dispelOptions = o end
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
            self.slots[key] = { filter = filter, button = button }
            return button
        end
        function c:SetAuraGroupFilterString(key, f) self.groups[key].filter = f end
        function c:SetAuraGroupMaxFrameCount(key, n) self.groups[key].max = n end
        function c:SetAuraGroupLayout(key, l) self.groups[key].layout = l end
        function c:SetAuraGroupEnabled(key, on) self.groups[key].enabled = on end
        function c:SetEnabled(on) self.enabled = on end
        function c:SetUnit(unit) self.unit = unit end
        function c:UpdateAllAuras() self.updates = (self.updates or 0) + 1 end
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
    assert(C.buffs and C.debuffs and C.defensives and C.buffs.template == 'CustomAuraContainerTemplate', 'one container per group')
    assert(C.buffs.enabled and C.buffs.unit == 'party1' and C.buffs.updates >= 1, 'pointed at the unit')
    assert(C.buffs.groups.buffs1.filter == 'HELPFUL|PLAYER' and not C.buffs.groups.buffs2.enabled, 'one filter, second slot off')
    assert(C.defensives.groups.defensives1.filter == 'HELPFUL|EXTERNAL_DEFENSIVE' and C.defensives.groups.defensives2.filter == 'HELPFUL|BIG_DEFENSIVE'
        and C.defensives.groups.defensives2.enabled, 'Big and External continue in one row')
    assert(not C.dispellable.enabled and not C.crowdControl.enabled, 'groups off by default stay off')
    local button = C.debuffs.groups.debuffs1.button
    assert(button.iconRegion == button.icon and button.cooldownRegion == button.cooldown and button.countRegion == button.count, 'regions registered')
    assert(button.dispelTextures[1] == button.rim and button.dispelOptions.customDispelColorCurve.points[1].r == M.db.auraMagicColor[1], 'rim by type')
    assert(button.clicks == false, 'clicks fall through to the member')
    assert(C.buffs.flowAnchor == 'BOTTOMRIGHT' and Point(C.buffs)[2] == p1.panel and C.buffs.lineSize > 0, 'placed at the anchor, wraps per row')
    -- The dispel highlight: a slot whose button holds the border, colored by type by the game.
    local slot = p1.dispelContainer
    assert(slot and slot.slots.dispel.filter == 'HARMFUL|RAID' and slot.unit == 'party1' and slot.enabled)
    local sb = slot.slots.dispel.button
    assert(#sb.dispelTextures == 4 and sb.dispelOptions.customDispelColorCurve.points[3].g == M.db.auraDiseaseColor[2], 'border pieces by type')
    -- Look changes build new containers; counts change through setters.
    local debuffs = C.debuffs
    assert(M:SetAuraOption('debuffs', 'max', 5) and p1.auraContainers.debuffs == debuffs and debuffs.groups.debuffs1.max == 5)
    assert(M:SetAuraOption('debuffs', 'shape', 'square') and p1.auraContainers.debuffs ~= debuffs and not debuffs.enabled, 'look change: new container')
    assert(M:SetAuraOption('debuffs', 'filter', 'all') and p1.auraContainers.debuffs.groups.debuffs1.filter == 'HARMFUL')
    assert(M:SetOption('dispelHighlight', 'none') and not slot.enabled)
    -- Units follow the header.
    roster = { 'party2' }; GroupChanged()
    assert(M.members[2].auraContainers.buffs.unit == 'party2', 'containers follow the unit')
]==], "party_containers")

-- Invalid saved settings stop validation instead of being reset.
local broken = world.saved()
broken.profiles.Default.modules.partyFrames.width = 'wide'
assert(not pcall(H.Load, { before = STUBS, saved = broken }), 'invalid party settings are refused, not reset')
local saved = world.saved()
saved.profiles.Default.modules.partyFrames.auras.buffs.anchor = 'NOWHERE'
assert(not pcall(H.Load, { before = STUBS, saved = saved }), 'invalid aura group refused')
print("party frames: all checks passed")
