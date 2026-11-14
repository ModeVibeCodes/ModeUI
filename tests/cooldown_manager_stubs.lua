-- Blizzard's Cooldown Manager, simulated for the Cooldown Manager tests: the
-- four viewers with Blizzard's item frames (pool, RefreshLayout, grid Layout,
-- RefreshData, the item methods ModeUI hooks), C_CooldownViewer, C_Spell and
-- the spell alert manager. Blizzard's frames refuse any field written from
-- ModeUI's own files (the taint rule); the client's native state is allowed.
    local methods = getmetatable(UIParent).__index
    function methods:IsMouseOver() return self.mouseOver == true end
    function methods:SetMouseMotionEnabled(on) self.motion = on end
    function methods:SetMouseClickEnabled(on) self.clicks = on end
    function methods:GetAtlas() return self.atlas end
    function methods:SetSwipeColor(...) self.swipeColor = {...} end
    function methods:SetSwipeTexture(path) self.swipeTexture = path end
    function methods:SetDrawBling(on) self.drawBling = on end
    function methods:SetHideCountdownNumbers(on) self.hideNumbers = on end
    function methods:GetCountdownFontString()
        self.countdown = self.countdown or self:CreateFontString(nil, 'OVERLAY')
        return self.countdown
    end
    function methods:GetRegions() return unpack(self.regions or {}) end
    -- Alpha from a boolean that may be secret (allowed for addon code).
    function methods:SetAlphaFromBoolean(value) self.alphaFromBoolean = value; if not issecretvalue(value) then self.alpha = value and 1 or 0 end end
    local createTexture = methods.CreateTexture
    function methods:CreateTexture(...)
        local texture = createTexture(self, ...)
        self.regions = self.regions or {}; self.regions[#self.regions + 1] = texture
        return texture
    end
    function methods:CreateMaskTexture()
        local mask = createTexture(self, nil, 'ARTWORK'); mask.kind = 'MaskTexture'
        self.regions = self.regions or {}; self.regions[#self.regions + 1] = mask
        return mask
    end

    -- Writes from ModeUI's files onto Blizzard's frames fail the test.
    blizzardWrites = {}
    local function Guard(frame)
        setmetatable(frame, { __index = methods, __newindex = function(t, key, value)
            local source = debug.getinfo(2, 'S').source
            if source:find('Modules/', 1, true) or source:find('Shared/', 1, true) then
                blizzardWrites[#blizzardWrites + 1] = tostring(key) .. ' from ' .. source
            end
            rawset(t, key, value)
        end })
        return frame
    end

    -- The game's data: cooldown IDs to spells; spells cooling down.
    spellsOf = { [101] = 5001, [102] = 5002, [103] = 5003, [104] = 5004, [105] = 5005,
        [201] = 6001, [202] = 6002, [301] = 7001, [302] = 7002, [401] = 8001, [402] = 8002 }
    cooling = {}
    cvarOn = true
    C_CVar = { GetCVarBool = function(name) assert(name == 'cooldownViewerEnabled'); return cvarOn end }
    C_CooldownViewer = {
        IsCooldownViewerAvailable = function() return true, '' end,
        GetCooldownViewerCooldownInfo = function(id) return spellsOf[id] and { cooldownID = id, spellID = spellsOf[id] } or nil end,
    }
    C_Spell = {
        GetSpellName = function(spell) return 'Spell ' .. spell end,
        GetSpellTexture = function(spell) return 'icon:' .. spell end,
        GetSpellCooldown = function(spell) return { isActive = cooling[spell] == true, isOnGCD = false, startTime = Secret('start'), duration = Secret('duration') } end,
    }
    -- Spells by ID: IDs under 900000 exist; durations are opaque objects.
    knownSpells, spellCharges, spellUsable, overrides = {}, {}, {}, {}
    C_Spell.DoesSpellExist = function(id) return id < 900000 end
    C_Spell.GetOverrideSpell = function(id) return overrides[id] or id end
    C_Spell.GetSpellCooldownDuration = function(id, ignoreGCD) assert(ignoreGCD == true); return { duration = 'cd:' .. id } end
    C_Spell.GetSpellChargeDuration = function(id) return { duration = 'charge:' .. id } end
    C_Spell.GetSpellCharges = function(id)
        local c = spellCharges[id]
        if c then return { currentCharges = c.current, maxCharges = c.max, isActive = c.active } end
    end
    C_Spell.IsSpellUsable = function(id) local u = spellUsable[id]; if u then return u[1], u[2] end return true, false end
    C_SpellBook = { IsSpellKnown = function(id) return knownSpells[id] ~= false end }
    function methods:SetCooldownFromDurationObject(duration) self.durationObject = duration end
    function GameTooltip:SetOwner(owner) self.owner = owner end
    function GameTooltip:SetSpellByID(id) self.spell = id end
    CooldownViewerConstants = { ITEM_AURA_COLOR = { r = 1, g = 0.8, b = 0 }, ITEM_COOLDOWN_COLOR = { r = 0, g = 0, b = 0, a = 0.7 } }
    -- Blizzard's Cooldown Settings window (Open CDM).
    cdmToggles = 0
    CooldownViewerSettings = { TogglePanel = function() cdmToggles = cdmToggles + 1 end }
    ActionButtonSpellAlertManager = { activeAlerts = {} }
    function ActionButtonSpellAlertManager:ShowAlert(button)
        if not button.SpellActivationAlert then rawset(button, 'SpellActivationAlert', CreateFrame('Frame', nil, button)) end
        button.SpellActivationAlert:Show(); self.activeAlerts[button] = 1
    end
    function ActionButtonSpellAlertManager:HideAlert(button)
        if button.SpellActivationAlert then button.SpellActivationAlert:Hide() end
        self.activeAlerts[button] = nil
    end

    -- One of Blizzard's item frames (mixin methods copied onto the frame).
    local function Item(viewer, bar, buff)
        local item = Guard(CreateFrame('Frame', nil, viewer))
        if bar then
            item.Icon = CreateFrame('Frame', nil, item)
            item.Icon.Icon = item.Icon:CreateTexture(nil, 'ARTWORK')
            item.Icon.mask = item.Icon:CreateMaskTexture(); item.Icon.Icon:AddMaskTexture(item.Icon.mask)
            item.Icon.Applications = item.Icon:CreateFontString()
            item.Bar = CreateFrame('StatusBar', nil, item)
            item.Bar.BarBG = item.Bar:CreateTexture(nil, 'BACKGROUND')
            item.Bar.Pip = item.Bar:CreateTexture(nil, 'OVERLAY')
            item.Bar.Name = item.Bar:CreateFontString(); item.Bar.Duration = item.Bar:CreateFontString()
            item.DebuffBorder = CreateFrame('Frame', nil, item)
            function item:SetBarContent(content)
                self.Icon:SetShown(content ~= 'name')
                self.Bar:SetPoint('LEFT', self.Icon, 'RIGHT', 2, 0)
            end
            function item:SetBarWidth(width) self:SetWidth(width) end
        else
            item.Icon = item:CreateTexture(nil, 'ARTWORK')
            item.mask = item:CreateMaskTexture(); item.Icon:AddMaskTexture(item.mask)
            item.overlay = item:CreateTexture(nil, 'OVERLAY'); item.overlay:SetAtlas('UI-HUD-CoolDownManager-IconOverlay')
            item.Cooldown = CreateFrame('Cooldown', nil, item)
            if buff then
                item.Applications = CreateFrame('Frame', nil, item)
                item.Applications.Applications = item.Applications:CreateFontString()
                item.DebuffBorder = CreateFrame('Frame', nil, item)
                function item:RefreshCooldownInfo() self.Cooldown:SetSwipeColor(0, 0, 0, 0.7) end
                -- A buff's active state, kept by Blizzard (secret in combat).
                function item:SetIsActive(active) self.isActive = active end
            else
                item.OutOfRange = item:CreateTexture(nil, 'OVERLAY'); item.OutOfRange:SetAtlas('UI-CooldownManager-OORshadow')
                item.ChargeCount = CreateFrame('Frame', nil, item)
                item.ChargeCount.Current = item.ChargeCount:CreateFontString()
                item.CooldownFlash = CreateFrame('Frame', nil, item)
                -- Blizzard sets its swipe and edge on every refresh.
                function item:RefreshSpellCooldownInfo()
                    local c = self.cooldownSwipeColor
                    self.Cooldown:SetSwipeColor(c.r, c.g, c.b, c.a or 1); self.Cooldown:SetDrawEdge(true)
                end
                item.cooldownSwipeColor = CooldownViewerConstants.ITEM_COOLDOWN_COLOR
                -- Blizzard's own gray, set on each refresh.
                function item:RefreshIconDesaturation() self.Icon:SetDesaturated(self.blizzardGray == true) end
                -- Blizzard's tint: red out of range (and its shade, shown or hidden).
                function item:RefreshIconColor()
                    if self.spellOutOfRange then self.Icon:SetVertexColor(0.64, 0.15, 0.15, 1) else self.Icon:SetVertexColor(1, 1, 1, 1) end
                    self.OutOfRange:SetShown(self.spellOutOfRange == true)
                end
                function item:SetIsActive(active) self.isActive = active end
            end
        end
        item.activeState = true
        function item:GetCooldownID() return self.cooldownID end
        function item:SetCooldownID(id) self.cooldownID = id end
        function item:ClearCooldownID() self.cooldownID = nil end
        function item:SetTooltipsShown(on) self:SetMouseClickEnabled(false); self:SetMouseMotionEnabled(on) end
        function item:UpdateShownState()
            local shown = self.cooldownID ~= nil and (not buff or self.activeState)
            if self.secretShown then self.shown = Secret('shown') elseif shown then self:Show() else self:Hide() end
        end
        return item
    end

    -- A viewer: Blizzard's frame with its pool and grid layout.
    function MakeViewer(name, ids, bar, buff)
        local viewer = Guard(CreateFrame('Frame', name, UIParent))
        viewer:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, 300)
        viewer.ids, viewer.tooltipsShown, viewer.iconScale = ids, true, 1.5
        local active, free = {}, {}
        viewer.itemFramePool = {
            Acquire = function() local item = table.remove(free) or Item(viewer, bar, buff); active[#active + 1] = item; item:Show(); return item end,
            ReleaseAll = function() for _, item in ipairs(active) do item:Hide(); item:ClearAllPoints(); item.layoutIndex = nil; free[#free + 1] = item end; active = {} end,
            EnumerateActive = function() local i = 0; return function() i = i + 1; return active[i] end end,
            GetNumActive = function() return #active end,
        }
        function viewer:OnAcquireItemFrame(item)
            item:SetScale(self.iconScale); item:SetTooltipsShown(self.tooltipsShown)
            if bar then item:SetBarContent('both'); item:SetBarWidth(220) end
        end
        function viewer:Layout()
            for item in self.itemFramePool:EnumerateActive() do
                item:ClearAllPoints(); item:SetPoint('TOPLEFT', self, 'TOPLEFT', (item.layoutIndex - 1) * 50, 0)
            end
        end
        function viewer:RefreshData()
            for item in self.itemFramePool:EnumerateActive() do
                local id = self.ids[item.layoutIndex]
                if id then item:SetCooldownID(id) else item:ClearCooldownID() end
                item:UpdateShownState()
                if item.RefreshSpellCooldownInfo then item:RefreshSpellCooldownInfo() end
            end
        end
        function viewer:RefreshLayout()
            self.itemFramePool:ReleaseAll()
            for i = 1, math.max(#self.ids, 2) do
                local item = self.itemFramePool:Acquire()
                item.layoutIndex = i
                self:OnAcquireItemFrame(item)
            end
            self:RefreshData()
            self:Layout()
        end
        viewer:RefreshLayout()
        return viewer
    end
    function MakeViewers()
        MakeViewer('EssentialCooldownViewer', { 101, 102, 103, 104, 105 })
        MakeViewer('UtilityCooldownViewer', { 201, 202 })
        MakeViewer('BuffIconCooldownViewer', { 301, 302 }, false, true)
        MakeViewer('BuffBarCooldownViewer', { 401, 402 }, true, true)
    end
    function ItemsOf(viewer)
        local list = {}
        for item in viewer.itemFramePool:EnumerateActive() do list[#list + 1] = item end
        return list
    end
    -- Blizzard's Cooldown frame: whether it shows an aura's time (12.x).
    function methods:SetUseAuraDisplayTime(on) self.auraTime = on end
    -- Your class's full cooldown sets, learned or not (106 unlearned, 303
    -- and 106 not shown by the viewers).
    Enum = Enum or {}
    Enum.CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 }
    spellsOf[106], spellsOf[303] = 5006, 7003
    classSets, unlearned = { [0] = { 101, 102, 103, 104, 105, 106 }, [1] = { 201, 202 }, [2] = { 301, 302, 303 }, [3] = { 401, 402 } }, { [106] = true }
    C_CooldownViewer.GetCooldownViewerCategorySet = function(category, allowUnlearned) assert(allowUnlearned == true); return classSets[category] or {} end
    C_CooldownViewer.GetCooldownViewerCooldownInfo = function(id)
        return spellsOf[id] and { cooldownID = id, spellID = spellsOf[id], isKnown = not unlearned[id] } or nil
    end
    -- Items: names, counts, cooldowns, what's in the backpack. Linen Cloth
    -- (2589) has no Use: effect.
    itemNames = { [5512] = 'Healthstone', [191380] = 'Healing Potion', [7676] = 'Thistle Tea', [2589] = 'Linen Cloth' }
    itemCounts, itemCooldowns, backpack = { [5512] = 1, [191380] = 3, [2589] = 20 }, {}, { 5512, 2589, 191380 }
    C_Item = {
        DoesItemExistByID = function(id) return itemNames[id] ~= nil end,
        RequestLoadItemDataByID = function() end,
        GetItemNameByID = function(id) return itemNames[id] end,
        GetItemIconByID = function(id) return itemNames[id] and 'item:' .. id or nil end,
        GetItemCount = function(id, bank, uses) assert(bank == false and uses == true); return itemCounts[id] or 0 end,
        IsUsableItem = function(id) return (itemCounts[id] or 0) > 0, false end,
        GetItemSpell = function(id) if itemNames[id] and id ~= 2589 then return 'Use', 80000 + id % 1000 end end,
    }
    C_Container = {
        GetItemCooldown = function(id) local c = itemCooldowns[id]; if c then return c[1], c[2], 1 end return 0, 0, 1 end,
        GetContainerNumSlots = function(bag) return bag == 0 and #backpack or 0 end,
        GetContainerItemInfo = function(bag, slot)
            local id = bag == 0 and backpack[slot]
            if id then return { itemID = id, iconFileID = 'item:' .. id, stackCount = itemCounts[id], itemName = itemNames[id] } end
        end,
    }
    function GameTooltip:SetItemByID(id) self.item = id end
