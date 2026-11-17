-- Buffs & Debuffs: bars on Blizzard's custom aura containers, the stand-in
-- for Blizzard's buff frames, settings, custom bars, the blacklist, the Unit
-- Frames handover, Edit Mode samples and the settings page. Simulated
-- client; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local UNIT_STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")

-- Blizzard_AuraContainer as far as the module uses it (the globals it exports
-- and a container that records groups, enchants, layout and flow), and
-- Blizzard's BuffFrame and DebuffFrame with their parts.
local STUBS = UNIT_STUBS .. [==[
    Enum = Enum or {}; C_UnitAuras = C_UnitAuras or {}
    C_XMLUtil = { GetTemplateInfo = function(name) if name == 'CustomAuraContainerTemplate' then return {} end end }
    Enum.CustomAuraButtonDispelTypeTextureStyle = { PreserveAsset = 3 }
    Enum.LuaCurveType = { Linear = 0, Step = 1 }
    Enum.SecrecyLevel = { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 }
    AuraContainerSortMethod = { Default = 0, Expiration = 4, Name = 6 }
    AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
    AuraContainerItemEnchantmentSlot = { MainHand = 0, OffHand = 1, Ranged = 2 }
    CustomAuraContainerItemEnchantmentPlacement = { BeforeAuraGroups = 0, AfterAuraGroups = 1 }
    neverSecret = { [57724] = true }
    C_Secrets = { GetSpellAuraSecrecy = function(id) return neverSecret[id] and 0 or 2 end }
    C_CurveUtil = { CreateColorCurve = function()
        local curve = { points = {} }
        function curve:SetType(t) self.type = t end
        function curve:AddPoint(x, color) self.points[x] = color end
        return curve
    end }
    cvars = { ActionButtonUseKeyDown = false }
    function GetCVarBool(name) return cvars[name] end
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
        function button:SetCancelAuraButtons(b) self.cancel = b end
        function button:SetTooltipAnchorPoint(p) self.tooltipPoint = p end
        return button
    end
    function CreateFrame(kind, name, parent, template)
        if kind ~= 'AuraContainer' then return createFrame(kind, name, parent, template) end
        local c = createFrame('Frame', name, parent)
        c.template, c.groups, c.order, c.enchantSlots = template, {}, {}, {}
        function c:AddAuraGroup(key, filter, options)
            assert(not self.groups[key], 'groups are added once')
            local button = Button(self)
            options.initializeFrame(button)
            self.groups[key] = { filter = filter, options = options, enabled = true, max = options.maxFrameCount, button = button,
                candidates = options.candidateFilters }
            self.order[#self.order + 1] = key
        end
        function c:AddItemEnchantment(slot, options)
            local button = Button(self)
            options.initializeFrame(button)
            self.enchantSlots[#self.enchantSlots + 1] = { slot = slot, button = button }
            return button
        end
        function c:SetItemEnchantmentLayout(l) self.enchantLayout = l end
        function c:SetAuraGroupFilterString(key, f) self.groups[key].filter = f end
        function c:SetAuraGroupMaxFrameCount(key, n) self.groups[key].max = n end
        function c:SetAuraGroupLayout(key, l) self.groups[key].layout = l end
        function c:SetAuraGroupSortMethod(key, m, d) self.groups[key].sort = { m, d } end
        function c:UpdateAllAuras() self.updates = (self.updates or 0) + 1 end
        function c:SetAuraGroupCandidateFilters(key, f) self.groups[key].candidates = f; self.candidateCalls = (self.candidateCalls or 0) + 1 end
        function c:SetAuraGroupEnabled(key, on) self.groups[key].enabled = on end
        function c:SetEnabled(on) self.enabled = on end
        function c:SetUnit(unit) self.unit = unit end
        function c:SetFlowLayoutAnchorPoint(p) self.flowAnchor = p end
        function c:SetFlowLayoutAxis(a) self.axis = a end
        function c:SetFlowLayoutGrowthDirection(h, v) self.growth = { h, v } end
        function c:SetFlowLayoutMaximumLineSize(n) self.lineSize = n end
        containers[#containers + 1] = c
        return c
    end
    local methods = getmetatable(UIParent).__index
    function methods:SetParent(parent) self.parent = parent end
    function methods:UnregisterAllEvents() self.unregistered = true end
    function methods:IsVisible() local f = self; while f do if not f.shown then return false end f = f.parent end return true end
    BuffFrame = createFrame('Frame', 'BuffFrame', UIParent)
    BuffFrame:SetSize(300, 80); BuffFrame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -220, -14)
    BuffFrame.AuraContainer = createFrame('Frame', nil, BuffFrame)
    BuffFrame.CollapseAndExpandButton = createFrame('Button', nil, BuffFrame)
    DebuffFrame = createFrame('Frame', 'DebuffFrame', UIParent)
    DebuffFrame.AuraContainer = createFrame('Frame', nil, DebuffFrame)
    units.player.auras = { { spellId = 21562, icon = 135987 }, { spellId = 57724, icon = 136224, harmful = true } }
    C_UnitAuras.GetUnitAuras = function(unit, filter)
        local list = {}
        for _, aura in ipairs((units[unit] or {}).auras or {}) do
            if (filter:find('HARMFUL') ~= nil) == (aura.harmful == true) then list[#list + 1] = aura end
        end
        return list
    end
    C_Spell = C_Spell or {}
    C_Spell.GetSpellName = function(id) return ({ [21562] = 'Power Word: Fortitude', [57724] = 'Sated', [104280] = 'Well Fed', [1459] = 'Arcane Intellect' })[id] end
    C_Spell.GetSpellTexture = function(id) return 136000 + (id % 100) end
]==]

-- A fresh profile: off by default; switched on, every bar is a container.
H.Load({ before = STUBS }).run([==[
    local M = addon.BuffsDebuffs
    assert(M and M.title == 'Buffs & Debuffs' and M.category == 'frames' and not M.enabled, 'off on a fresh profile, in Interface')
    assert(#M.db.customBars == 1 and M.db.customBars[1].name == 'Defensives' and M.db.bars.custom1.cats.bigdef, 'starts with Defensives')
    assert(M.db.blacklist[1] == 104280 and M.db.blacklist[2] == 57724, 'Well Fed and Sated hidden')
    assert(#containers == 0 and not BuffFrame.unregistered, 'nothing built while off')
    addon:SetModuleEnabled('buffsDebuffs', true)
    local buffs, debuffs = M.containers.buffs, M.containers.debuffs
    assert(buffs and debuffs and M.containers.playerBuffs and M.containers.playerDebuffs and M.containers.custom1, 'a container per bar')
    assert(buffs.template == 'CustomAuraContainerTemplate' and buffs.unit == 'player' and buffs.enabled and buffs.updates >= 1)
    -- Buffs: All (one group) plus the weapon enchants after it.
    assert(#buffs.order == 1 and buffs.groups.buffs_all.filter == 'HELPFUL' and #buffs.enchantSlots == 2, 'all buffs and both enchants')
    assert(buffs.enchantLayout.placement == 1 and buffs.groups.buffs_all.max == 32)
    assert(buffs.groups.buffs_all.candidates.excludeSpellIDs[104280] and buffs.groups.buffs_all.candidates.excludeSpellIDs[57724], 'the blacklist goes to the game')
    -- 32 wide, 6 shorter, time text below: cells 32 x 38.
    local layout = buffs.groups.buffs_all.layout or buffs.groups.buffs_all.options.layout
    assert(layout.elementWidth == 32 and layout.elementHeight == 26 + 12 and layout.elementSpacing == 4)
    local b = buffs.groups.buffs_all.button
    assert(b.modeIcon and b.modeIcon.width == 32 and b.modeIcon.height == 26 and b.iconRegion == b.modeIcon.icon, 'the Mode icon on a child')
    assert(b.modeIcon.edge.styleId == 'blizz' and b.modeIcon.edge.rim == 1, 'Mode-Blizz, 1px band')
    assert(b.timerRegion == b.modeBelow and b.countRegion == b.modeIcon.count, 'time text below, stacks')
    assert(b.cancel == 'RightButtonUp' and b.tooltipPoint == 'ANCHOR_BOTTOMLEFT', 'right-click cancels; tooltip')
    -- Flow: grows left, rows down, from the top right.
    assert(buffs.flowAnchor == 'TOPRIGHT' and buffs.growth[1] == addon.Kit.AURA_FLOW.Left and buffs.growth[2] == addon.Kit.AURA_FLOW.Down)
    assert(buffs.lineSize == 10 * (32 + 4) - 4, 'ten per row')
    -- Debuffs: colored by type (flat rim handed to the game), private auras come with the container.
    local d = debuffs.groups.debuffs_all.button
    assert(debuffs.groups.debuffs_all.filter == 'HARMFUL' and d.dispelTextures and d.dispelTextures[1] == d.modeIcon.rim, 'rim by type')
    assert(d.cancel == nil and d.clicks == false, 'debuffs take no clicks')
    -- Player Debuffs: every kind in order, each leaving out the tokens before it.
    local pd = M.containers.playerDebuffs.groups
    assert(table.concat(M.containers.playerDebuffs.order, ',') ==
        'playerDebuffs_cc,playerDebuffs_dispellable,playerDebuffs_boss,playerDebuffs_Magic,playerDebuffs_Curse,playerDebuffs_Disease,playerDebuffs_Poison,playerDebuffs_Bleed,playerDebuffs_other')
    assert(pd.playerDebuffs_cc.filter == 'HARMFUL|CROWD_CONTROL' and pd.playerDebuffs_dispellable.filter == 'HARMFUL|RAID|!CROWD_CONTROL')
    assert(pd.playerDebuffs_Magic.filter == 'HARMFUL|!CROWD_CONTROL|!RAID' and pd.playerDebuffs_Magic.candidates.includeDispelTypes.Magic)
    assert(pd.playerDebuffs_boss.candidates.isBossAura == true and pd.playerDebuffs_Magic.candidates.isBossAura == nil)
    assert(pd.playerDebuffs_other.candidates.excludeDispelTypes.Bleed and pd.playerDebuffs_other.candidates.excludeDispelTypes.Magic)
    assert(pd.playerDebuffs_cc.button.timerRegion == pd.playerDebuffs_cc.button.modeIcon.timer, 'time on the icon')
    assert(pd.playerDebuffs_cc.button.modeIcon.edge.styleId == 'blizzEmpty', 'the owner picked Mode-BlizzEmpty')
    -- Defensives glow Aura Gold.
    local def = M.containers.custom1.groups.custom1_bigdef.button
    assert(def.modeIcon.glow:IsShown(), 'soft glow')

    -- Blizzard's frames step aside: unregistered, their buttons parked; the frames stay as anchors.
    assert(BuffFrame.unregistered and DebuffFrame.unregistered and BuffFrame:IsShown())
    assert(BuffFrame.AuraContainer.parent ~= BuffFrame and BuffFrame.CollapseAndExpandButton.parent ~= BuffFrame and DebuffFrame.AuraContainer.parent ~= DebuffFrame)
    local mover = M.movers.buffs
    assert(_G.ModeUIBuffsDebuffsBuffsMover == mover and mover.points[1][1] == 'TOPRIGHT' and mover.points[1][2] == BuffFrame, 'Buffs sit in Blizzard\'s spot')
    assert(M.movers.debuffs.points[1][2] == M.movers.buffs, 'Debuffs hang from Buffs')
    assert(mover.width == 10 * 32 + 9 * 4 and mover.height == 4 * 38 + 3 * 4, 'the mover holds a full bar')

    -- Settings: kinds, All standing alone, sorting, growth.
    assert(M:SetCategory('playerBuffs', 'bigdef', true) and M.containers.playerBuffs.groups.playerBuffs_bigdef, 'a new kind rebuilds the bar')
    assert(M.containers.playerBuffs.groups.playerBuffs_mine.filter == 'HELPFUL|PLAYER|!BIG_DEFENSIVE|!IMPORTANT|!RAID_IN_COMBAT')
    assert(M:SetCategory('playerBuffs', 'all', true) and next(M.db.bars.playerBuffs.cats) == 'all' and #M.containers.playerBuffs.order == 1, 'All stands alone')
    assert(M:SetCategory('playerBuffs', 'mine', true) and not M.db.bars.playerBuffs.cats.all, 'another kind takes All off')
    assert(not M:SetCategory('playerBuffs', 'Magic', true), 'no debuff kinds on a buff bar')
    assert(M:SetBarOption('debuffs', 'sort', 'time') and debuffs.groups.debuffs_all.sort[1] == 4, 'sorted by time left')
    assert(M:SetBarOption('debuffs', 'grow', 'down') and M.db.bars.debuffs.wrap == 'right', 'rows go across the growth')
    assert(debuffs.axis == addon.Kit.AURA_AXIS.Vertical and debuffs.flowAnchor == 'TOPLEFT')
    assert(not M:SetBarOption('debuffs', 'wrap', 'down'), 'rows never run the way the icons grow')
    assert(not M:SetBarOption('debuffs', 'kind', 'buffs'), 'Blizzard\'s stand-ins keep their kind')
    assert(not M:SetBarOption('buffs', 'width', 99) and not M:SetBarOption('buffs', 'edgeStyle', 'gold'))
    local before = M.containers.buffs
    assert(M:SetBarOption('buffs', 'edgeStyle', 'thin') and M.containers.buffs ~= before and not before.enabled, 'a new look builds a new container')
    assert(M.containers.buffs.groups.buffs_all.button.modeIcon.edge.styleId == 'thin')
    local calls = M.containers.debuffs.candidateCalls or 0
    assert(M:SetBarOption('debuffs', 'max', 8) and (M.containers.debuffs.candidateCalls or 0) == calls, 'candidate filters only when the blacklist changes')
    assert(M:AddBlacklist(1459) and M.containers.debuffs.groups.debuffs_all.candidates.excludeSpellIDs[1459], 'the blacklist reaches every bar')
    assert(M:RemoveBlacklist(1459) and not M.containers.debuffs.groups.debuffs_all.candidates.excludeSpellIDs[1459])
    assert(not M:AddBlacklist(1459.5) and not M:AddBlacklist(104280), 'whole spell IDs, once')
    assert(M:BlacklistReach(57724) == 'all' and M:BlacklistReach(104280) == 'buffs', 'Sated hides everywhere; Well Fed only as a buff')

    -- Custom bars: added, renamed, anchored to, deleted.
    local id = M:AddCustomBar()
    assert(id == 'custom2' and M.containers.custom2 and M.db.customBars[2].name == 'Bar 2' and _G.ModeUIBuffsDebuffsCustom2Mover)
    assert(M:RenameCustomBar(id, 'Boss') and M:BarLabel(id) == 'Boss' and not M:RenameCustomBar(id, '  '))
    assert(M:SetBarOption(id, 'kind', 'debuffs') and M.db.bars[id].cats.all and M.db.bars[id].byType and not M.db.bars[id].cancel)
    assert(addon.PositionManager:Element('buffsDebuffsCustom1').allowedTargets.buffsDebuffsCustom2, 'other bars may anchor to it')
    assert(M:DeleteCustomBar(id) and not M.containers.custom2 and not addon.PositionManager:Element('buffsDebuffsCustom2'))
    for i = 1, 7 do assert(M:AddCustomBar()) end
    assert(#M.db.customBars == 8 and M:AddCustomBar() == nil, 'eight custom bars at most')

    -- Combat: changes wait.
    testCombat, testLockdown = true, true
    assert(not M:SetBarOption('buffs', 'max', 10) and not M:AddCustomBar())
    testCombat, testLockdown = false, false
    FireEvent('PLAYER_REGEN_ENABLED')

    -- Edit Mode: containers wait; the bars show sample icons in their look.
    M:SetEditMode(true)

    local samples = M.samples.playerDebuffs
    assert(samples and samples[1]:IsShown() and M.movers.playerDebuffs:IsShown() and not M.containers.playerDebuffs.enabled, 'samples in Edit Mode')
    assert(samples[1].icon.texture:find('Spell_Shadow_Possession'), 'crowd control first')
    M:SetEditMode(false)
    assert(not samples[1]:IsShown() and M.containers.playerDebuffs.enabled)

    -- Off: Blizzard's frames come back with a reload.
    addon:SetModuleEnabled('buffsDebuffs', false)
    assert(not M.containers.buffs.enabled and addon.ReloadManager:IsPending(), 'a reload gives Blizzard\'s frames back')
]==], "buffs_debuffs")

-- The settings page builds on demand; its preview shows the bar being edited.
H.Load({ before = STUBS }).run([==[
    local M = addon.BuffsDebuffs
    addon:SetModuleEnabled('buffsDebuffs', true)
    SlashCmdList.MODEUI(); addon:SelectConfigPage('buffsDebuffs')
    local page = M.page
    assert(page and page:IsShown() and page.barSelect and page.categoryGrids.buffs and page.categoryGrids.debuffs and page.borderStyleSelect, 'page built')
    local tabs = {}
    for _, section in ipairs(page.sections) do tabs[#tabs + 1] = section.title end
    assert(table.concat(tabs, ',') == 'Bars,Look,Blacklist,Module', 'four tabs')
    local view = page.configPreview
    assert(view and view.pool[1] and view.pool[1]:IsShown() and view.caption:GetText():find('Buffs', 1, true), 'the preview shows Buffs')
    page.SetEditing('playerDebuffs')
    assert(view.caption:GetText():find('Player Debuffs', 1, true) and view.pool[1].icon.texture:find('Possession'))
    assert(view.pool[1].edge.tint ~= nil, 'debuff samples take their type color')
    assert(M:OpenPicker(page.blacklistButton) and M.picker:IsShown(), 'the blacklist picker')
    assert(M.picker.buttons[1].spell == 104280 and M.picker.buttons[3].spell == 21562, 'hidden first, then auras on you')
    local ok = M:AddBlacklistByID(21562)
    assert(ok and M:IsBlacklisted(21562) and not M:AddBlacklistByID(999999), 'by ID')
]==], "buffs_debuffs_page")

-- The Player frame's auras move here: a profile whose Player frame showed
-- debuffs starts with this module on; Unit Frames keeps its settings.
local saved = { schemaVersion = 2, activeProfile = 'Default', profiles = { Default = { modules = {
    unitFrames = { player = { debuffs = { enabled = true, size = 38 } } } } } } }
H.Load({ before = STUBS, saved = saved }).run([==[
    local M = addon.BuffsDebuffs
    assert(M.enabled and M.db.enabled, 'Player debuffs were on: the module starts on')
    assert(addon.modules.unitFrames.db.player.debuffs.enabled == true, 'Unit Frames keeps its saved Player auras')
    assert(M.containers.playerDebuffs and M.containers.playerDebuffs.enabled)
]==], "buffs_debuffs_handover")

print("buffs and debuffs: all checks passed")
