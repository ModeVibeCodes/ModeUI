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
        function button:AddDispelTypeTexture(t, o)
            -- As Blizzard's AddDisplayElement: a list; the same texture twice is an error.
            self.dispelTextures = self.dispelTextures or {}
            for _, held in ipairs(self.dispelTextures) do assert(held ~= t, 'Display element has already been added.') end
            self.dispelTextures[#self.dispelTextures + 1] = t; self.dispelOptions = o
        end
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
    local function Point(f) return f.points[#f.points] end
    assert(M and M.title == 'Buffs & Debuffs' and M.category == 'frames' and not M.enabled, 'off on a fresh profile, in Interface')
    assert(#M.db.customBars == 1 and M.db.customBars[1].name == 'Defensives' and M.db.bars.custom1.cats.bigdef, 'starts with Defensives')
    assert(M.db.customBars[1].preset == 'defensives' and M.db.bars.custom1.cats.tracked and M:Preset('custom1'), 'Defensives is a preset')
    assert(addon.Style.SameColor(M.db.bars.buffs.timerColor, addon.Style.Tone.mono.white)
        and addon.Style.SameColor(M.db.bars.buffs.countColor, addon.Style.Tone.auraStack), 'white time text, green stacks')
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
    -- 32 wide, 4 shorter (the design rule under 36), time text below (10px and 2px): cells 32 x 40.
    local layout = buffs.groups.buffs_all.layout or buffs.groups.buffs_all.options.layout
    assert(layout.elementWidth == 32 and layout.elementHeight == 28 + 12 and layout.elementSpacing == 4)
    local b = buffs.groups.buffs_all.button
    assert(b.modeIcon and b.modeIcon.width == 32 and b.modeIcon.height == 28 and b.iconRegion == b.modeIcon.art, 'the Mode icon on a child')
    assert(b.modeIcon.edge.styleId == 'blizz' and b.modeIcon.edge.rim == 1, 'Mode-Blizz, 1px band')
    assert(b.timerRegion == b.modeOutside and b.countRegion == b.modeIcon.count, 'time text below, stacks')
    -- Cropped by size: the art is 10% wider than its clipping frame on each side (30 x 26 inside a 1px band).
    assert(b.modeIcon.clip.clipsChildren and not b.modeIcon.icon:IsShown(), 'a clipping frame holds the art')
    local lv = b.modeIcon:GetFrameLevel()
    assert(b.modeIcon.clip:GetFrameLevel() == lv + 1 and b.modeIcon.cooldown:GetFrameLevel() == lv + 2 and b.modeIcon.edge.holder:GetFrameLevel() == lv + 3
        and b.modeIcon.textLayer:GetFrameLevel() == lv + 4, 'the art above the black back, under the swipe, border and text')
    assert(math.abs(b.modeIcon.art.width - 30 / 0.8) < 1e-6 and b.modeIcon.art.points[1][1] == 'CENTER')
    assert(Point(b.modeIcon.count)[1] == 'BOTTOMRIGHT' and b.modeIcon.count.font[2] == M.db.bars.buffs.countSize, 'stacks in their corner')
    assert(b.cancel == 'RightButtonUp' and b.tooltipPoint == 'ANCHOR_BOTTOMLEFT', 'right-click cancels; tooltip')
    -- Flow: grows left, rows down, from the top right.
    assert(buffs.flowAnchor == 'TOPRIGHT' and buffs.growth[1] == addon.Kit.AURA_FLOW.Left and buffs.growth[2] == addon.Kit.AURA_FLOW.Down)
    assert(buffs.lineSize == 10 * (32 + 4) - 4, 'ten per row')
    -- Debuffs: colored by type (flat rim handed to the game), private auras come with the container.
    local d = debuffs.groups.debuffs_all.button
    assert(debuffs.groups.debuffs_all.filter == 'HARMFUL' and d.dispelTextures and d.dispelTextures[1] == d.modeIcon.rim and #d.dispelTextures >= 8, 'rim by type, every piece')
    assert(d.cancel == nil and d.clicks == false, 'debuffs take no clicks')
    -- Player Debuffs: every kind in order, each leaving out the tokens before it.
    local pd = M.containers.playerDebuffs.groups
    assert(table.concat(M.containers.playerDebuffs.order, ',') ==
        'playerDebuffs_cc,playerDebuffs_dispellable,playerDebuffs_Magic,playerDebuffs_Curse,playerDebuffs_Disease,playerDebuffs_Poison,playerDebuffs_Bleed,playerDebuffs_other',
        'Boss Debuffs off in (All): they live in Boss & Important')
    assert(pd.playerDebuffs_cc.filter == 'HARMFUL|CROWD_CONTROL' and pd.playerDebuffs_dispellable.filter == 'HARMFUL|RAID|!CROWD_CONTROL')
    assert(pd.playerDebuffs_Magic.filter == 'HARMFUL|!CROWD_CONTROL|!RAID' and pd.playerDebuffs_Magic.candidates.includeDispelTypes.Magic)
    assert(pd.playerDebuffs_boss == nil and pd.playerDebuffs_Magic.candidates.isBossAura == nil)
    assert(pd.playerDebuffs_other.candidates.excludeDispelTypes.Bleed and pd.playerDebuffs_other.candidates.excludeDispelTypes.Magic)
    assert(pd.playerDebuffs_cc.button.timerRegion == pd.playerDebuffs_cc.button.modeIcon.timer, 'time on the icon')
    assert(pd.playerDebuffs_cc.button.modeIcon.edge.styleId == 'blizzEmpty', 'the owner picked Mode-BlizzEmpty')
    local pdi = pd.playerDebuffs_cc.button.modeIcon
    assert(pdi.width == 42 and pdi.height == 36 and pdi.edge.rim == 2, 'Player Debuffs: 42 x 36 with a 2px border')
    assert(M:BarLabel('playerDebuffs') == 'Player Debuffs (All)' and M:BarLabel('playerImportant') == 'Player Debuffs (Boss & Important)')
    -- The Boss & Important preset: Important first, then boss debuffs that aren't, a little bigger, just above (All).
    local pi = M.containers.playerImportant
    assert(table.concat(pi.order, ',') == 'playerImportant_important,playerImportant_boss')
    assert(pi.groups.playerImportant_important.filter == 'HARMFUL|IMPORTANT' and pi.groups.playerImportant_boss.filter == 'HARMFUL|!IMPORTANT'
        and pi.groups.playerImportant_boss.candidates.isBossAura == true, 'each aura once')
    local pii = pi.groups.playerImportant_important.button.modeIcon
    assert(pii.width == 48 and pii.height == 42 and pii.edge.rim == 2 and pii.edge.styleId == 'blizzEmpty')
    local above = M.movers.playerImportant.points[1]
    assert(above[1] == 'BOTTOMRIGHT' and above[2] == M.movers.playerDebuffs and above[3] == 'TOPRIGHT' and above[5] == 6, '6px above (All)')
    -- Defensives (owner's look): 42 x 34, Mode-Thin Silver 2px, no cancel, no tooltip, glowing.
    local def = M.containers.custom1.groups.custom1_bigdef.button
    assert(def.modeIcon.glow:IsShown(), 'soft glow')
    assert(def.modeIcon.width == 42 and def.modeIcon.height == 34 and def.modeIcon.edge.styleId == 'thin' and def.modeIcon.edge.rim == 2)
    assert(def.cancel == nil and def.clicks == false and M.containers.custom1.groups.custom1_tracked == nil, 'no cancel; no spells yet')
    -- Spells You Add: the bar's own buffs, left out of its other kinds.
    assert(M:AddBarSpell('custom1', 21562) and not M:AddBarSpell('custom1', 21562) and not M:AddBarSpell('buffs', 0.5))
    local tracked = M.containers.custom1.groups.custom1_tracked
    assert(tracked and tracked.filter == 'HELPFUL' and tracked.candidates.includeSpellIDs[21562], 'the game keeps the bar to its spells')
    assert(M.containers.custom1.order[1] == 'custom1_tracked', 'first in line')
    assert(M.containers.custom1.groups.custom1_bigdef.candidates.excludeSpellIDs[21562], 'shown once')
    assert(M:RemoveBarSpell('custom1', 21562) and #M.db.bars.custom1.spells == 0)
    assert(not M:SetBarOption('custom1', 'kind', 'debuffs') and not M:SetBarOption('custom1', 'cancel', true), 'the preset keeps its kind, no cancel')

    -- Blizzard's frames step aside: unregistered, their parts hidden (and
    -- kept hidden) where they are, since Blizzard's layout calls
    -- AuraContainer:GetParent():UpdateSize(); the frames stay as anchors.
    assert(BuffFrame.unregistered and DebuffFrame.unregistered and BuffFrame:IsShown())
    assert(BuffFrame.AuraContainer:GetParent() == BuffFrame and not BuffFrame.AuraContainer:IsShown(), 'hidden in place')
    assert(not BuffFrame.CollapseAndExpandButton:IsShown() and DebuffFrame.AuraContainer:GetParent() == DebuffFrame and not DebuffFrame.AuraContainer:IsShown())
    BuffFrame.AuraContainer:Show(); assert(not BuffFrame.AuraContainer:IsShown(), 'hidden again when Blizzard shows it')
    local mover = M.movers.buffs
    assert(_G.ModeUIBuffsDebuffsBuffsMover == mover and mover.points[1][1] == 'TOPRIGHT' and mover.points[1][2] == BuffFrame, 'Buffs sit in Blizzard\'s spot')
    assert(M.movers.debuffs.points[1][2] == M.movers.buffs, 'Debuffs hang from Buffs')
    assert(mover.width == 10 * 32 + 9 * 4 and mover.height == 4 * 40 + 3 * 4, 'the mover holds a full bar')

    -- Width and height: the height follows the width while at its default offset.
    assert(M:SetBarOption('playerBuffs', 'width', 40) and M.db.bars.playerBuffs.height == 34, '6px shorter from 36 wide')
    assert(M:SetBarOption('playerBuffs', 'height', 30) and M:SetBarOption('playerBuffs', 'width', 44) and M.db.bars.playerBuffs.height == 30, 'a height you set stays')
    assert(M:SetBarOption('playerBuffs', 'width', 24) and M:SetBarOption('playerBuffs', 'height', 20))
    -- Text: time above with an offset; stacks top left; the border gap and zoom.
    assert(M:SetBarOption('buffs', 'timer', 'above') and M:SetBarOption('buffs', 'timerY', 3) and M:SetBarOption('buffs', 'countPoint', 'TOPLEFT'))
    local ab = M.containers.buffs.groups.buffs_all.button
    assert(Point(ab.modeIcon)[1] == 'BOTTOM' and Point(ab.modeOutside)[1] == 'BOTTOM' and Point(ab.modeOutside)[5] == 2 + 3, 'time over the icon, 3 up')
    assert(Point(ab.modeIcon.count)[1] == 'TOPLEFT' and not M:SetBarOption('buffs', 'countPoint', 'MIDDLE'))
    assert(M:SetBarOption('buffs', 'borderGap', 2) and M.containers.buffs.groups.buffs_all.button.modeIcon.clip.points[1][4] == 3, 'the art 2px inside the band')
    assert(M:SetBarOption('buffs', 'timer', 'below') and M:SetBarOption('buffs', 'timerY', 0) and M:SetBarOption('buffs', 'countPoint', 'BOTTOMRIGHT') and M:SetBarOption('buffs', 'borderGap', 0))
    -- The border: shifted out 2px and moved 1px right, then a custom color.
    assert(M:SetBarOption('buffs', 'borderShift', 2) and M:SetBarOption('buffs', 'borderX', 1))
    local inner = M.containers.buffs.groups.buffs_all.button.modeIcon.inner
    assert(inner.points[1][4] == (1 - 2) + 1 and inner.points[2][4] == -(1 - 2) + 1, 'the band out 2px, 1px right')
    assert(not M:SetBarOption('buffs', 'borderShift', 9), 'shift in range')
    assert(M:SetBarOption('buffs', 'borderTint', true)
        and M.containers.buffs.groups.buffs_all.button.modeIcon.edge.tint == M.db.bars.buffs.borderColor, 'custom border color')
    assert(M:SetBarOption('buffs', 'borderTint', false) and M:SetBarOption('buffs', 'borderShift', 0) and M:SetBarOption('buffs', 'borderX', 0))
    assert(M:SetOption('outline', 'thick') and M.db.outline == 'thick' and not M:SetOption('outline', 'bold') and not M:SetOption('max', 3))
    assert(M:SetOption('outline', 'none'))

    -- Settings: kinds, All standing alone, sorting, growth.
    assert(M:SetCategory('playerBuffs', 'bigdef', true) and M.containers.playerBuffs.groups.playerBuffs_bigdef, 'a new kind rebuilds the bar')
    assert(M.containers.playerBuffs.groups.playerBuffs_mine.filter == 'HELPFUL|PLAYER|!BIG_DEFENSIVE|!IMPORTANT|!RAID_IN_COMBAT')
    assert(M:SetCategory('playerBuffs', 'all', true) and next(M.db.bars.playerBuffs.cats) == 'all' and #M.containers.playerBuffs.order == 1, 'All stands alone')
    assert(M:SetCategory('playerBuffs', 'mine', true) and not M.db.bars.playerBuffs.cats.all, 'another kind takes All off')
    assert(not M:SetCategory('playerBuffs', 'Magic', true), 'no debuff kinds on a buff bar')
    assert(M:SetBarOption('debuffs', 'sort', 'time') and M.containers.debuffs.groups.debuffs_all.sort[1] == 4, 'sorted by time left')
    assert(M:SetBarOption('debuffs', 'grow', 'down') and M.db.bars.debuffs.wrap == 'right', 'rows go across the growth')
    assert(M.containers.debuffs.axis == addon.Kit.AURA_AXIS.Vertical and M.containers.debuffs.flowAnchor == 'TOPLEFT')
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
    assert(M:SetCategory(id, 'mine', true) and M:SetBarOption(id, 'kind', 'debuffs') and M.db.bars[id].cats.all and M.db.bars[id].byType and not M.db.bars[id].cancel)
    assert(M:SetBarOption(id, 'kind', 'buffs') and M.db.bars[id].cats.mine and not M.db.bars[id].cats.all, 'switching back keeps the kinds picked')
    assert(addon.PositionManager:Element('buffsDebuffsCustom1').allowedTargets.buffsDebuffsCustom2, 'other bars may anchor to it')
    assert(M:DeleteCustomBar(id) and not M.containers.custom2 and not addon.PositionManager:Element('buffsDebuffsCustom2'))
    for i = 1, 7 do assert(M:AddCustomBar()) end
    assert(#M.db.customBars == 8 and M:AddCustomBar() == nil, 'eight custom bars at most')

    -- While auras are secret the game forbids its aura buttons (and the Mode
    -- icon on them) to addon code: snapping the settings window's borders
    -- walks past them instead of erroring (Edge.lua:65, November 18).
    local inner = M.containers.buffs.groups.buffs_all.button.modeIcon.inner
    inner.IsForbidden = function() return true end
    inner.GetParent = function() error('Attempt to access forbidden object from code tainted by an AddOn') end
    assert(pcall(addon.Style.SnapEdges, CreateFrame('Frame')), 'snapping skips forbidden frames')
    inner.IsForbidden, inner.GetParent = nil, nil

    -- Combat: changes wait.
    testCombat, testLockdown = true, true
    assert(not M:SetBarOption('buffs', 'max', 10) and not M:AddCustomBar())
    testCombat, testLockdown = false, false
    FireEvent('PLAYER_REGEN_ENABLED')

    -- Edit Mode: containers wait; the bars show sample icons in their look.
    M:SetEditMode(true)

    local samples = M.samples.playerDebuffs
    assert(samples and samples[1]:IsShown() and M.movers.playerDebuffs:IsShown() and not M.containers.playerDebuffs.enabled, 'samples in Edit Mode')
    assert(samples[1].art.texture:find('Spell_Shadow_Possession'), 'crowd control first')
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
    assert(table.concat(tabs, ',') == 'Bars,Look,Texts,Blacklist,Module', 'five tabs')
    assert(page.heightSlider and page.cropSlider and page.borderGapSlider and page.borderSizeSlider and page.borderShiftSlider
        and page.borderNudge and page.borderTintToggles, 'size and border controls')
    assert(page.timerSizeSlider and page.timerNudge and page.countCorner and page.countNudge and page.outlinePills and page.maxSlider and page.growPills, 'text and behavior controls')
    -- The sample aura on the Texts tab follows the text settings.
    local sample = page.textSample
    assert(sample and sample.icon.count:GetText() == '3' and sample.icon.outside:GetText() == '12', 'a sample with both texts')
    assert(M:SetBarOption('buffs', 'timer', 'center') and sample.icon.timer:GetText() == '12' and M:SetBarOption('buffs', 'timer', 'below'))
    -- The bar list marks each bar on or off.
    local choices = M:BarChoices()
    assert(choices[1].label:find('ON', 1, true) and choices[1].label:find('Buffs', 1, true))
    assert(M:SetBarOption('debuffs', 'show', false) and M:BarChoices()[2].label:find('OFF', 1, true) and M:SetBarOption('debuffs', 'show', true))
    -- + New Bar and Delete Bar sit under the dropdown (which spans its row), Delete only for your own bars.
    local _, add, delete = page.barSelectParts()
    assert(add:GetParent().row ~= page.barSelect:GetParent().row and not delete:IsShown(), 'buttons on their own row')
    page.SetEditing('custom1'); assert(delete:IsShown()); page.SetEditing('buffs')
    local view = page.configPreview
    assert(view and view.pool[1] and view.pool[1]:IsShown() and view.name:GetText() == 'Buffs' and view.state:GetText() == 'ON', 'the preview names the bar')
    assert(view.caption:GetText():find('All Buffs', 1, true))
    assert(page.previewSplit and view.card and view.card.buttons[1]:IsShown() and view.card.buttons[1].label:GetText() == 'Spells You Add', 'Which Auras under the preview')
    assert(not page.categoryGrids.buffs[1]:IsVisible(), 'not also on the Bars tab')
    page.SetEditing('playerDebuffs')
    assert(view.name:GetText() == 'Player Debuffs (All)' and view.pool[1].art.texture:find('Possession'))
    local boss
    for _, button in ipairs(view.card.buttons) do if button.category == 'boss' then boss = button end end
    assert(boss and not boss.selected); boss:GetScript('OnClick')(boss)
    assert(M.db.bars.playerDebuffs.cats.boss, 'Boss Debuffs back on from the preview card'); boss:GetScript('OnClick')(boss)
    assert(not M.db.bars.playerDebuffs.cats.boss)
    assert(view.pool[1].edge.tint ~= nil, 'debuff samples take their type color')
    assert(M:OpenPicker(page.blacklistButton) and M.picker:IsShown(), 'the blacklist picker')
    assert(M.picker.buttons[1].spell == 104280 and M.picker.buttons[3].spell == 21562, 'hidden first, then auras on you')
    local ok = M:AddBlacklistByID(21562)
    assert(ok and M:IsBlacklisted(21562) and not M:AddBlacklistByID(999999), 'by ID')
    assert(M:RemoveBlacklist(21562))
    -- The same picker for a bar's Spells You Add: buffs on you only.
    assert(M:OpenPicker(page.spellsButton, 'custom1') and M.picker.target == 'custom1')
    assert(M.picker.buttons[1].spell == 21562 and not M.picker.buttons[2]:IsShown(), 'only the buff on you')
    M.picker.buttons[1]:GetScript('OnClick')(M.picker.buttons[1])
    assert(M:HasBarSpell('custom1', 21562) and M:AddBarSpellByID('custom1', 1459) and M:HasBarSpell('custom1', 1459), 'added from the picker and by ID')
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

-- Version 1 -> 2: heights and text sizes from each bar's width; Player
-- Debuffs at the old defaults (30 wide, 1px) become 42 wide with 2px; a width
-- the player set stays; the outline becomes a choice.
local v1 = { schemaVersion = 2, activeProfile = 'Default', profiles = { Default = { modules = { buffsDebuffs = {
    enabled = true, settingsVersion = 1, outline = false,
    bars = { playerDebuffs = { width = 30, borderSize = 1, timer = 'center' }, playerBuffs = { width = 42, borderSize = 1 },
        buffs = { width = 32 } } } } } } }
H.Load({ before = STUBS, saved = v1 }).run([==[
    local M = addon.BuffsDebuffs
    local bars = M.db.bars
    assert(M.db.settingsVersion == 3 and M.db.outline == 'none')
    assert(bars.playerDebuffs.width == 42 and bars.playerDebuffs.height == 36 and bars.playerDebuffs.borderSize == 2, 'Player Debuffs grow')
    assert(bars.playerDebuffs.timerSize == 16 and addon.Style.SameColor(bars.playerDebuffs.timerColor, addon.Style.Tone.mono.white))
    assert(bars.playerBuffs.width == 42 and bars.playerBuffs.height == 36 and bars.playerBuffs.borderSize == 1, 'other bars keep their border')
    assert(bars.buffs.height == 28 and bars.buffs.timerSize == 10 and bars.buffs.crop == 10 and bars.buffs.borderGap == 0)
]==], "buffs_debuffs_v2")

-- Version 2 -> 3: white time text and green stacks where still at the old
-- defaults, Boss Debuffs out of Player Debuffs (All) when it still had the
-- old picks, and Defensives a preset in the owner's look (no cancel).
local v2 = { schemaVersion = 2, activeProfile = 'Default', profiles = { Default = { modules = { buffsDebuffs = {
    enabled = true, settingsVersion = 2, customBars = { { id = 'custom1', name = 'Defensives' } }, nextCustom = 2,
    bars = {
        playerDebuffs = { cats = { cc = true, dispellable = true, boss = true, Magic = true, Curse = true, Disease = true,
            Poison = true, Bleed = true, other = true }, timer = 'center', timerColor = { 1, 0.694, 0.184 }, countColor = { 0.949, 0.949, 0.949 } },
        debuffs = { cats = { boss = true }, timerColor = { 0.2, 0.4, 0.6 } },
        custom1 = { kind = 'buffs', cats = { bigdef = true, extdef = true, important = true }, width = 40, height = 34, spacing = 4,
            crop = 10, edgeStyle = 'blizzEmpty', edgeMetal = 'default', borderSize = 1, cancel = true, tooltip = true, timer = 'center' } } } } } } }
H.Load({ before = STUBS, saved = v2 }).run([==[
    local M = addon.BuffsDebuffs
    local bars, Tone, Same = M.db.bars, addon.Style.Tone, addon.Style.SameColor
    assert(M.db.settingsVersion == 3)
    assert(not bars.playerDebuffs.cats.boss and bars.playerDebuffs.cats.cc, 'Boss Debuffs out of (All)')
    assert(bars.debuffs.cats.boss, 'picks of your own stay')
    assert(Same(bars.playerDebuffs.timerColor, Tone.mono.white) and Same(bars.playerDebuffs.countColor, Tone.auraStack))
    assert(Same(bars.debuffs.timerColor, { 0.2, 0.4, 0.6 }), 'a color you picked stays')
    local d = bars.custom1
    assert(M.db.customBars[1].preset == 'defensives' and d.width == 42 and d.height == 34 and d.spacing == 2 and d.crop == 8)
    assert(d.edgeStyle == 'thin' and d.edgeMetal == 'silver' and d.borderSize == 2 and d.cancel == false and d.tooltip == false)
    assert(d.cats.tracked and d.cats.bigdef, 'Spells You Add joins the preset')
]==], "buffs_debuffs_v3")

-- The Mode-Default layout (Layouts.lua): Buffs and Debuffs by the minimap,
-- outer edges on its outer edges; the same at 1080 and 1440.
H.Load({ before = STUBS }).run([==[
    local M = addon.BuffsDebuffs
    for _, variant in ipairs({ '1080', '1440' }) do
        local profile = assert(addon.Layouts:Build('mode-default', variant))
        local db, pos = profile.modules.buffsDebuffs, profile.positions
        local b, d, pb = db.bars.buffs, db.bars.debuffs, db.bars.playerBuffs
        assert(db.enabled == true)
        for _, bar in ipairs({ b, d }) do
            assert(bar.width == 30 and bar.height == 24 and bar.perRow == 12 and bar.grow == 'left' and bar.wrap == 'down'
                and bar.spacing == 1 and bar.timer == 'below' and bar.timerSize == 10, 'Buffs and Debuffs icons')
        end
        assert(b.max == 24 and d.max == 16 and pb.width == 30 and pb.height == 24 and pb.perRow == 5 and pb.spacing == 1 and pb.show == false, 'Player Buffs 30 x 24, five to a row, sharing shadows, off')
        assert(db.bars.playerDebuffs.width == 42 and db.bars.playerImportant.width == 48, 'player debuff bars unchanged')
        assert(db.customBars[1].preset == 'defensives' and db.customBars[1].id == 'custom1')
        local def = db.bars.custom1
        assert(def.width == 40 and def.height == 34 and def.max == 4 and def.borderSize == 2)
        -- Every bar Mode-Thin in its own metal, 1px apart (owner, November 18, 2026); border sizes stay.
        for id, bar in pairs(db.bars) do
            assert(bar.edgeStyle == 'thin' and bar.edgeMetal == 'default' and bar.spacing == 1, id .. ': Mode-Thin, 1px apart')
        end
        assert(db.bars.playerDebuffs.borderSize == 2 and db.bars.custom1.borderSize == 2, 'border sizes kept')
        -- Two rows of cells 24 + 10 + 2 tall, 1 apart: the Debuffs element is 73 tall.
        local w, h = M:BarSize(d, 1)
        assert(w == 12 * 30 + 11 and h == 2 * 36 + 1)
        local function Is(id, target, point, rel, x, y)
            local p = pos[M.ElementId(id)]
            assert(p and p.target == target and p.point == point and p.relativePoint == rel and p.x == x and p.y == y,
                id .. ' placed ' .. tostring(p and p.x) .. ',' .. tostring(p and p.y))
        end
        Is('buffs', 'modeMinimap', 'TOPRIGHT', 'TOPLEFT', -10, 2)
        Is('debuffs', 'modeMinimap', 'TOPRIGHT', 'BOTTOMLEFT', -10, 70)
        Is('custom1', 'screen', 'RIGHT', 'CENTER', -124, 166)
        -- Under the Player frame's bottom border, sharing its shadow pixel, right edges lined up.
        Is('playerBuffs', 'unitFramesPlayerBars', 'TOPRIGHT', 'BOTTOMRIGHT', 0, -1)
    end
    -- The bars may anchor to the minimap (anyTarget).
    addon:SetModuleEnabled('buffsDebuffs', true)
    local element = addon.PositionManager:Element(M.ElementId('buffs'))
    assert(element and element.allowedTargets.modeMinimap, 'Buffs may anchor to the minimap')
]==], "buffs_debuffs_layout")

print("buffs and debuffs: all checks passed")
