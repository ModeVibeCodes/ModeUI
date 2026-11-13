-- Action bar client stubs (Blizzard's bars and buttons, secure handlers, bindings, cooldowns, spell alerts) shared by the action bar tests.
    local methods = getmetatable(UIParent).__index
    local setParent = methods.SetParent
    function methods:SetParent(parent)
        assert(not (self.secure and InCombatLockdown()), 'SetParent on secure frame in combat')
        return setParent(self, parent)
    end
    function methods:IsMouseOver() return self.mouseOver == true end
    function methods:GetAttribute(key) return self.attributes and self.attributes[key] end
    function methods:RemoveMaskTexture(mask) assert(self.mask == mask, 'removes its own mask'); self.mask = nil end
    function methods:GetTexture() return self.texture end
    function methods:GetCooldownTimes() return (self.realStart or 0) * 1000, (self.realDuration or 0) * 1000 end
    function methods:GetCountdownFontString()
        self.countdown = self.countdown or self:CreateFontString(nil, 'OVERLAY')
        return self.countdown
    end
    -- Secret text makes a FontString's measurements secret too (as in the client).
    local setText = methods.SetText
    function methods:SetText(text)
        if self.kind == 'FontString' and issecretvalue(text) then self.secretContent = true end
        return setText(self, text)
    end
    for _, name in ipairs({ 'GetWidth', 'GetHeight', 'GetStringWidth', 'GetStringHeight' }) do
        local get = methods[name]
        methods[name] = function(self, ...) if self.secretContent then return Secret('measure') end return get(self, ...) end
    end
    -- The stub's own anchor math needs real sizes; the client's does it natively.
    local setPoint = methods.SetPoint
    function methods:SetPoint(point, relative, ...)
        local own, other = self.secretContent, type(relative) == 'table' and relative.secretContent
        self.secretContent = nil; if other then relative.secretContent = nil end
        local result = setPoint(self, point, relative, ...)
        self.secretContent = own; if other then relative.secretContent = other end
        return result
    end
    RED_FONT_COLOR = { GetRGB = function() return 1, 0.125, 0.125 end }
    RANGE_INDICATOR = '*'
    testForms = 0
    function GetNumShapeshiftForms() return testForms end
    -- Secure handlers record what was asked of them.
    drivers, wraps = {}, {}
    function RegisterStateDriver(frame, state, values)
        assert(not InCombatLockdown(), 'state driver in combat'); drivers[frame] = drivers[frame] or {}; drivers[frame][state] = values
        -- Out of combat with no pet battle, the last clause decides (enough for these bars).
        if values:match("hide$") then frame:Hide() else frame:Show() end
    end
    function UnregisterStateDriver(frame, state) if drivers[frame] then drivers[frame][state] = nil end end
    function SecureHandlerWrapScript(frame, script, header, body) wraps[#wraps + 1] = { frame = frame, script = script, header = header, body = body } end
    frameRefs = {}
    function SecureHandlerSetFrameRef(frame, label, ref) frameRefs[frame] = frameRefs[frame] or {}; frameRefs[frame][label] = ref end
    -- Cooldowns by action slot; isActive and isOnGCD are never secret.
    cooldowns = {}
    C_ActionBar = { GetActionCooldown = function(action) return cooldowns[action] or { isActive = false, isOnGCD = false } end }
    -- Blizzard's spell alerts: a frame on the button while its spell procs.
    ActionButtonSpellAlertManager = { activeAlerts = {} }
    function ActionButtonSpellAlertManager:ShowAlert(button)
        button.SpellActivationAlert = button.SpellActivationAlert or CreateFrame('Frame', nil, button)
        button.SpellActivationAlert:Show(); self.activeAlerts[button] = 1
    end
    function ActionButtonSpellAlertManager:HideAlert(button) if button.SpellActivationAlert then button.SpellActivationAlert:Hide() end self.activeAlerts[button] = nil end
    function SecureCmdOptionParse(text) if text:find('bogus', 1, true) then error('Unknown macro option') end return 'show' end
    local create = CreateFrame
    function CreateFrame(kind, name, parent, template)
        local f = create(kind, name, parent, template)
        if template == 'SecureHandlerStateTemplate' then f.secure = true end
        return f
    end
    -- Key bindings: one command per key.
    bindings, saves, loads = {}, 0, 0
    function GetBindingKey(command)
        local keys = {}
        for key, bound in pairs(bindings) do if bound == command then keys[#keys + 1] = key end end
        table.sort(keys)
        return unpack(keys)
    end
    function SetBinding(key, command) assert(not InCombatLockdown(), 'binding in combat'); if key == 'PRINTSCREEN' then return false end bindings[key] = command; return true end
    function GetBindingText(key) return key end
    function GetCurrentBindingSet() return 2 end
    function SaveBindings() saves = saves + 1 end
    function LoadBindings() loads = loads + 1; bindings = { ['1'] = 'ACTIONBUTTON1' } end
    function IsAltKeyDown() return false end
    function IsControlKeyDown() return false end
    function IsShiftKeyDown() return testShift == true end

    hotkeyTexts = {}
    -- Blizzard's bars and buttons: each button sits on a container of its bar.
    local function Button(name, bar, index, spell)
        local container = CreateFrame('Frame', nil, bar)
        local b = CreateFrame('Button', name, container)
        b.secure, b.bar, b.container, b.index = true, bar, container, index
        b:SetSize(45, 45); b:SetPoint('CENTER')
        b.icon = b:CreateTexture(nil, 'BACKGROUND')
        if spell then b.icon:SetTexture('Interface/Icons/Spell' .. index) else b.icon:Hide() end
        b.IconMask = b:CreateMaskTexture(); b.icon:AddMaskTexture(b.IconMask)
        for _, key in ipairs({ 'SlotBackground', 'SlotArt', 'NormalTexture', 'PushedTexture', 'HighlightTexture', 'CheckedTexture',
            'Flash', 'Border', 'NewActionTexture', 'SpellHighlightTexture' }) do b[key] = b:CreateTexture(nil, 'OVERLAY') end
        b.NormalTexture:SetAtlas('UI-HUD-ActionBar-IconFrame')
        b.cooldown = CreateFrame('Cooldown', nil, b)
        b.TextOverlayContainer = CreateFrame('Frame', nil, b)
        b.HotKey = b.TextOverlayContainer:CreateFontString(nil, 'OVERLAY')
        b.Count = b.TextOverlayContainer:CreateFontString(nil, 'OVERLAY')
        b.Name = b:CreateFontString(nil, 'OVERLAY')
        function b:UpdateHotkeys() self.HotKey:SetSize(37, 10); self.HotKey:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -4, -5); self.HotKey:SetText(hotkeyTexts[name] or tostring(index)) end
        function b:UpdateButtonArt() self.NormalTexture:SetAtlas('UI-HUD-ActionBar-IconFrame'); self.NormalTexture:SetAlpha(1) end
        b:UpdateHotkeys()
        return b
    end
    local function Bar(name, prefix, count, spells)
        local bar = CreateFrame('Frame', name, UIParent)
        for i = 1, count do Button(prefix .. i, bar, i, i <= (spells or 0)) end
        return bar
    end
    Bar('MainActionBar', 'ActionButton', 12, 6)
    for _, name in ipairs({ 'MultiBarBottomLeft', 'MultiBarBottomRight', 'MultiBarRight', 'MultiBarLeft', 'MultiBar5', 'MultiBar6', 'MultiBar7' }) do
        Bar(name, name .. 'Button', 12)
    end
    Bar('PetActionBar', 'PetActionButton', 10)
    Bar('StanceBar', 'StanceButton', 10)
    OverrideActionBar = CreateFrame('Frame', 'OverrideActionBar', UIParent); OverrideActionBar:Hide()
