-- Action Bars: moving Blizzard's buttons onto ModeUI bars, layout, the
-- 42x36 skin and background, text styling and its hooks, show conditions,
-- mouseover fading, Edit Mode (highlight, anchoring, guides, nudging),
-- Keybind Mode, the settings page and its live preview, combat deferral,
-- switching off, migration and persistence. Simulated client; not WoW
-- rendering, security or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. [==[
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
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, PM, Kit = addon.ActionBars, addon.PositionManager, addon.Kit
    assert(M and not M.enabled and not M.built, 'Action Bars start off and build nothing')
    assert(ActionButton1:GetParent() == ActionButton1.container, 'Blizzard keeps its buttons while off')
    for _, bar in ipairs(M.bars) do
        local style = M.db[bar]
        assert(style.width == 42 and style.height == 36 and style.backgroundOpacity == 75, bar .. ' buttons are 42 by 36 on a 75% background')
        assert(math.floor(style.cooldownColor[1] * 255 + 0.5) == 255 and math.floor(style.cooldownColor[2] * 255 + 0.5) == 177
            and math.floor(style.cooldownColor[3] * 255 + 0.5) == 47, 'cooldown numbers are #FFB12F')
        local function Hex(c) return string.format('%02X%02X%02X', math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
        assert(Hex(style.borderColor) == '101010' and Hex(style.backgroundColor) == '040404' and Hex(style.macroColor) == '69A5B9', 'border, background and macro colors')
        assert(style.borderSize == 2 and style.spacing == 1, '2px border, 1px apart')
        assert(style.procGlow == 'mode' and style.readyGlow and style.cooldownOpacity == 100, 'Mode proc glow, ready glow on, icons kept')
        assert(style.paging == (bar == 'bar1'), 'bar 1 pages; the others start fixed')
    end
    assert(M.db.bar1.show and not M.db.bar6.show and M.db.bar4.orientation == 'vertical' and M.db.pet.buttons == 10)

    addon:SetModuleEnabled('actionBars', true)
    local bar1 = ModeUIActionBar1
    assert(M.built and bar1 and bar1.secure, 'a secure bar per bar')
    assert(MainActionBar:GetParent() == M.hider and PetActionBar:GetParent() == M.hider and StanceBar:GetParent() == M.hider, 'bars with art are hidden')
    assert(MultiBarBottomLeft:GetParent() == UIParent, 'art-less Blizzard bars are left alone')
    assert(ActionButton1:GetParent() == bar1 and ActionButton1.bar == MainActionBar, 'buttons move but keep their Blizzard bar for paging')
    assert(ActionButton1.width == 42 and ActionButton1.height == 36, 'buttons are 42 by 36')
    assert(bar1.width == 516 and bar1.height == 36, '12 buttons, 1px apart, even width')
    local p = Point(ActionButton2)
    assert(p[1] == 'TOPLEFT' and p[2] == bar1 and p[4] == 43 and p[5] == 0, 'second button one step right')
    assert(ModeUIActionBar4.width == 42 and ModeUIActionBar4.height == 12 * 36 + 11 + 1, 'bar 4 stands upright')
    -- Bars stack on bar 1 by default; every secure bar is pinned to the screen.
    assert(PM:GetPosition('actionBarsBar2').target == 'actionBarsBar1' and PM:GetPosition('actionBarsStance').target == 'actionBarsPet')
    local mover1, mover2 = ModeUIActionBar1Mover, ModeUIActionBar2Mover
    assert(Point(mover2)[2] == mover1 and Point(mover2)[1] == 'BOTTOM' and Point(mover2)[3] == 'TOP', 'bar 2 sits on bar 1')
    p = Point(ModeUIActionBar2)
    assert(p[1] == 'BOTTOMLEFT' and p[2] == UIParent and p[3] == 'BOTTOMLEFT', 'the secure bar hangs from the screen only')

    -- Skin: a hollow 2px border, the background inside, icon inset 3px and cropped to 36x30.
    local art = M.art[ActionButton1]
    local top, left = art.edges[1], art.edges[3]
    assert(top:IsShown() and top.vertexColor[1] == M.BORDER_COLOR[1] and #art.edges == 4, 'border in its own color')
    assert(top.points[1][4] == 1 and top.points[2][5] == -2 and left.points[2][4] == 2, '2px edges, corners left out (rounded)')
    assert(art.fill.vertexColor[1] == M.BACKGROUND_COLOR[1] and art.fill.vertexColor[4] == 0.75 and art.fill.points[1][4] == 2, 'the background at Background Opacity on every button')
    assert(art.grain.texture:find('ActionBars/Slot', 1, true) and art.grain.blendMode == 'ADD', 'slot texture lightens the background')
    local icon = ActionButton1.icon
    assert(icon.mask == nil, 'Blizzard icon mask removed')
    assert(icon.points[1][4] == 3 and icon.points[2][4] == -3, 'icon a pixel inside the border')
    local span = 0.84 * 30 / 36
    assert(math.abs(icon.texCoord[3] - (0.5 - span / 2)) < 1e-9 and icon.texCoord[1] == 0.08, 'icon cropped, not stretched')
    assert(ActionButton1.NormalTexture.alpha == 0 and ActionButton1.SlotArt.alpha == 0, 'Blizzard frame art faded')
    ActionButton1:UpdateButtonArt()
    assert(ActionButton1.NormalTexture.alpha == 0, 'faded again after Blizzard redraws its art')
    assert(ActionButton1.HighlightTexture.texture == Kit.FLAT, 'flat Mode highlight')
    local slot = M.slots.bar1[12]
    local slotArt = M.art[slot]
    assert(slot:IsShown() and slotArt.fill.vertexColor[4] == 0.75 and slotArt.edges[1].vertexColor[4] == 1, 'empty slot: solid border, see-through inside')
    assert(M:SetOption('bar1', 'backgroundOpacity', 60) and slotArt.fill.vertexColor[4] == 0.6 and slotArt.grain.vertexColor[4] == 0.6, 'Background Opacity')
    -- The border color never colors the background, and each has its own setting.
    assert(M:SetOption('bar1', 'borderColor', { 1, 0, 0 }) and slotArt.fill.vertexColor[1] == M.BACKGROUND_COLOR[1] and slotArt.edges[2].vertexColor[1] == 1)
    assert(M:SetOption('bar1', 'backgroundColor', { 0, 0, 1 }) and slotArt.fill.vertexColor[3] == 1 and slotArt.edges[2].vertexColor[3] == 0)
    assert(M:SetOption('bar1', 'borderSize', 1) and ActionButton1.icon.points[1][4] == 2, 'Border Size moves the icon in or out')
    assert(M:ResetBar('bar1') and M.db.bar1.borderSize == 2 and M.db.bar1.backgroundOpacity == 75)

    -- Text: font, tucked into its corner, keybind color kept unless out of range.
    local hotkey = ActionButton1.HotKey
    assert(hotkey.font[2] == 9 and hotkey.font[3] == 'OUTLINE', 'keybind 9 with outline')
    -- Short Keybinds: one-letter modifiers with no hyphen.
    assert(M.ShortKey('s-E') == 'sE' and M.ShortKey('SHIFT-E') == 'sE' and M.ShortKey('s-c-1') == 'sc1', 'modifiers shortened')
    assert(M.ShortKey('Mouse Button 4') == 'M4' and M.ShortKey('a-Mouse Button 4') == 'aM4' and M.ShortKey('BUTTON3') == 'M3')
    assert(M.ShortKey('Q') == 'Q' and M.ShortKey('Num Pad 5') == 'N5' and M.ShortKey('Mouse Wheel Up') == 'WU')
    hotkeyTexts.ActionButton5 = 's-E'; ActionButton5:UpdateHotkeys()
    assert(ActionButton5.HotKey.text == 'sE', "Blizzard's keybind text shortened")
    assert(M:SetOption('bar1', 'hotkeyShort', false) and ActionButton5.HotKey.text == 's-E', "off: Blizzard's own text")
    assert(M:SetOption('bar1', 'hotkeyShort', true) and ActionButton5.HotKey.text == 'sE')
    local at = Point(hotkey)
    assert(at[1] == 'TOPRIGHT' and at[4] == -4 and at[5] == -4 and hotkey.justifyV == 'TOP', 'keybind right in the top-right corner')
    ActionButton1:UpdateHotkeys()
    at = Point(hotkey)
    assert(#hotkey.points == 1 and at[4] == -4, 'Blizzard re-placing the keybind is undone')
    hotkey:SetVertexColor(0.6, 0.6, 0.6)
    assert(hotkey.vertexColor[1] == M.db.bar1.hotkeyColor[1], 'keybind color kept')
    hotkey:SetVertexColor(1, 0.125, 0.125)
    assert(hotkey.vertexColor[2] == 0.125, 'out of range stays red')
    assert(ActionButton1.Name.alpha == 0, 'macro names hidden by default')
    local countdown = ActionButton1.cooldown.countdown
    assert(countdown.font[2] == 14 and countdown.color[2] == M.COOLDOWN_COLOR[2], 'amber cooldown numbers')

    -- Lifted shadow: a copy that follows Blizzard's text, even when secret.
    assert(M:SetOption('bar1', 'liftedShadow', true))
    local lift = M.lifts[ActionButton1.Count]
    assert(lift and lift:IsShown(), 'lift made on first use')
    ActionButton1.Count:SetText(Secret('charges'))
    assert(issecretvalue(lift.text), 'secret count copied straight to the lift')
    ActionButton1.Count:Hide(); assert(not lift:IsShown(), 'lift hides with its text')
    ActionButton1.Count:Show(); assert(lift:IsShown())
    assert(M:SetOption('bar1', 'liftedShadow', false) and not lift:IsShown(), 'lift off with Crisp')
    ActionButton1.Count:SetText('')

    -- Fewer buttons: the rest wait on the hidden frame, not on Blizzard's bar.
    assert(M:SetOption('bar2', 'buttons', 6))
    assert(MultiBarBottomLeftButton6:GetParent() == ModeUIActionBar2 and MultiBarBottomLeftButton7:GetParent() == M.hider)
    assert(not M:SetOption('pet', 'buttons', 12) and M.db.pet.buttons == 10, 'pet bar holds ten')
    assert(M:SetOption('bar2', 'perLine', 3) and ModeUIActionBar2.width == 3 * 42 + 2 and ModeUIActionBar2.height == 2 * 36 + 2, 'two rows of three (1px apart, even height)')
    assert(M:SetOption('bar2', 'start', 'BOTTOMRIGHT'))
    p = Point(MultiBarBottomLeftButton4)
    assert(p[1] == 'BOTTOMRIGHT' and p[4] == 0 and p[5] == 37, 'fourth button starts the second row up from the corner')

    -- Show: Always, Mouseover, Hidden and the rest.
    assert(drivers[bar1].modevis == '[petbattle] hide; show', 'always, except pet battles')
    assert(drivers[ModeUIActionBar6].modevis == 'hide', 'hidden bar')
    assert(drivers[ModeUIPetBar].modevis:find('[nopet] hide; show', 1, true), 'pet bar needs a pet')
    assert(drivers[ModeUIStanceBar].modevis == 'hide', 'no stances, no stance bar')
    testForms = 3; FireEvent('UPDATE_SHAPESHIFT_FORMS')
    assert(drivers[ModeUIStanceBar].modevis:find('show') and ModeUIStanceBar.width == 3 * 42 + 2, 'stance bar fits the stances')
    assert(StanceButton4:GetParent() == M.hider)
    assert(M:SetOption('bar1', 'visibility', 'hidden') and drivers[bar1].modevis == '[petbattle] hide; hide', 'Hidden')
    assert(M:SetOption('bar1', 'visibility', 'combat') and drivers[bar1].modevis == '[petbattle] hide; [combat] show; hide')
    assert(M:SetOption('bar1', 'visibility', 'custom') and drivers[bar1].modevis == '[petbattle] hide; [combat] show; hide')
    assert(M:SetOption('bar1', 'customVisibility', '[bogus] show; hide') and drivers[bar1].modevis == '[petbattle] hide; show', 'unreadable conditions show the bar')
    assert(not M:SetOption('bar1', 'customVisibility', 'a\nb'), 'one line only')
    assert(M:SetOption('bar1', 'visibility', 'always'))
    assert(bar1.attributes['_onstate-modevis']:find('modeoverride', 1, true), 'state handler honors the vehicle bar')
    assert(#wraps == 2 and wraps[1].frame == OverrideActionBar and wraps[1].header == bar1 and wraps[2].script == 'OnHide', 'bar 1 watches the vehicle bar')

    -- Mouseover: faded until the mouse is over the bar.
    assert(M:SetOption('bar3', 'visibility', 'mouseover') and ModeUIActionBar3:GetAlpha() == 0, 'faded until mouseover')
    assert(drivers[ModeUIActionBar3].modevis == '[petbattle] hide; show', 'shown, just faded')
    ModeUIActionBar3:Show(); ModeUIActionBar3.mouseOver = true; Advance(0.2)
    assert(ModeUIActionBar3:GetAlpha() == 1, 'shows under the mouse')
    ModeUIActionBar3.mouseOver = false; Advance(0.2); assert(ModeUIActionBar3:GetAlpha() == 0)
    FireEvent('ACTIONBAR_SHOWGRID'); assert(ModeUIActionBar3:GetAlpha() == 1, 'dragging a spell shows it')
    FireEvent('ACTIONBAR_HIDEGRID'); assert(ModeUIActionBar3:GetAlpha() == 0)
    assert(M:SetOption('bar3', 'opacity', 50) and M:SetOption('bar3', 'visibility', 'always') and ModeUIActionBar3:GetAlpha() == 0.5, 'plain opacity')

    -- Combat: no settings changes; layout work waits for the end of combat.
    testCombat, testLockdown = true, true
    assert(not M:SetOption('bar1', 'width', 50), 'no changes in combat')
    ActionButton1:UpdateHotkeys()
    assert(#ActionButton1.HotKey.points == 2 and addon.Defer:IsQueued('actionBars:refresh'), 'keybind re-placing waits for combat to end')
    assert(not M:SetKeybindMode(true), 'no Keybind Mode in combat')
    testCombat, testLockdown = false, false
    FireEvent('PLAYER_REGEN_ENABLED')
    assert(not addon.Defer:IsQueued('actionBars:refresh') and #ActionButton1.HotKey.points == 1, 'placed after combat')

    -- Keybind Mode: /kb shows every bar with a catcher on each place.
    assert(M:SetOption('bar1', 'visibility', 'hidden'))
    SlashCmdList.MODEUIKEYBIND()
    assert(M.binding and ModeUIKeybindPanel:IsShown() and drivers[bar1].modevis == 'show', 'Keybind Mode shows hidden bars')
    local catcher = M.catchers.bar1[3]
    assert(catcher:IsShown() and catcher.command == 'ACTIONBUTTON3' and M.catchers.pet[1].command == 'BONUSACTIONBUTTON1')
    assert(M.catchers.bar2[1].command == 'MULTIACTIONBAR1BUTTON1' and M.catchers.bar4[1].command == 'MULTIACTIONBAR3BUTTON1')
    assert(M.slots.bar3[12]:IsShown(), 'every slot shows so empty places can be bound')
    local panel = ModeUIKeybindPanel
    panel.scripts.OnKeyDown(panel, 'Q'); assert(next(bindings) == nil, 'keys away from a button are not bound')
    catcher.scripts.OnEnter(catcher)
    testShift = true; panel.scripts.OnKeyDown(panel, 'Q'); testShift = false
    assert(bindings['SHIFT-Q'] == 'ACTIONBUTTON3' and catcher.key.text == 'sQ', 'hover and press binds, with modifiers (shown short)')
    assert(not panel.propagate, 'the key does not reach the game')
    panel.scripts.OnKeyDown(panel, 'LSHIFT'); assert(bindings['LSHIFT'] == nil, 'a modifier alone does nothing')
    catcher.scripts.OnMouseDown(catcher, 'MiddleButton'); assert(bindings['MiddleButton'] == 'ACTIONBUTTON3' and bindings['SHIFT-Q'] == nil, 'one key per button')
    catcher.scripts.OnMouseWheel(catcher, 1); assert(bindings.MOUSEWHEELUP == 'ACTIONBUTTON3')
    panel.scripts.OnKeyDown(panel, 'ESCAPE'); assert(bindings.MOUSEWHEELUP == nil and catcher.key.text == '', 'Escape on a button clears it')
    catcher.scripts.OnMouseDown(catcher, 'LeftButton'); assert(next(bindings) == nil, 'left click binds nothing')
    catcher.scripts.OnEnter(catcher); panel.scripts.OnKeyDown(panel, '4')
    catcher.scripts.OnLeave(catcher)
    panel.saveButton.scripts.OnClick(panel.saveButton)
    assert(not M.binding and saves == 1 and not panel:IsShown() and not catcher:IsShown() and bindings['4'] == 'ACTIONBUTTON3', 'Save keeps the bindings')
    assert(drivers[bar1].modevis == '[petbattle] hide; hide', 'bars go back to their own show setting')
    M:ToggleKeybindMode(); M.catchers.bar1[1].scripts.OnEnter(M.catchers.bar1[1]); panel.scripts.OnKeyDown(panel, '5')
    panel.discardButton.scripts.OnClick(panel.discardButton)
    assert(loads == 1 and bindings['5'] == nil, 'Discard puts the bindings back')
    M:ToggleKeybindMode(); FireEvent('PLAYER_REGEN_DISABLED')
    assert(not M.binding, 'combat leaves Keybind Mode')
    assert(M:SetOption('bar1', 'visibility', 'always'))

    -- Edit Mode: each shown bar shows, highlighted and named, and follows its stand-in.
    local element = PM.elements.actionBarsBar1
    assert(element and element.label == 'Action Bar 1' and PM.elements.actionBarsPet and PM.elements.actionBarsStance)
    assert(addon:SetEditMode(true))
    assert(mover1:IsShown() and mover1.width == bar1.width and mover1.label.text == 'Action Bar 1' and Point(mover1.label)[1] == 'CENTER', 'named in the middle')
    assert(mover1.fill.vertexColor[3] == Kit.palette.accent[3], 'highlighted')
    assert(not M.slots.bar1[1] or not ModeUIActionBar1Mover.slots[1]:IsShown(), 'the real bar shows under its highlight')
    assert(not ModeUIActionBar6Mover:IsShown() and not PM.elements.actionBarsBar6.editMode, 'hidden bars are not movable')
    local targets = {}
    for _, target in ipairs(PM:GetAllowedTargets('actionBarsBar3')) do targets[target.id] = true end
    assert(targets.actionBarsBar1 and targets.actionBarsBar2 and not targets.actionBarsBar3 and not targets.actionBarsBar4, 'anchors to earlier bars only')
    assert(PM:SetPosition('actionBarsBar1', { target = 'screen', placement = 'center', point = 'BOTTOM', relativePoint = 'BOTTOM', x = 0, y = 80 }))
    p = Point(bar1)
    assert(p[1] == 'BOTTOMLEFT' and p[2] == UIParent and p[5] == mover1:GetBottom() - UIParent:GetBottom(), 'the bar follows its stand-in')
    -- The mock doesn't chain anchors as the client does; re-anchor bar 2's stand-in.
    PM:ApplyPosition('actionBarsBar2', true); M:SyncAll()
    local before = Point(ModeUIActionBar2)[5]
    assert(before == 80 + 36 + 4, 'bar 2 sits 4px over bar 1')
    assert(PM:Nudge('actionBarsBar1', 0, 1) and PM:GetPosition('actionBarsBar1').y == 81, 'nudge one pixel')
    -- The mock doesn't chain anchors as the client does; re-anchor bar 2's stand-in.
    PM:ApplyPosition('actionBarsBar2', true); M:SyncAll()
    assert(Point(ModeUIActionBar2)[5] == before + 1, 'bars stacked on it move too')
    local decoration = element.decoration
    assert(decoration and #decoration.nudges == 4, 'nudge arrows on the element')
    addon.EditMode:Select('actionBarsBar1')
    assert(decoration.nudges[1]:IsShown(), 'shown on the selected element')
    decoration.nudges[1].scripts.OnClick(decoration.nudges[1])
    assert(PM:GetPosition('actionBarsBar1').x == -1, 'left arrow moves one pixel left')
    addon.editWindow.scripts.OnKeyDown(addon.editWindow, 'RIGHT')
    assert(PM:GetPosition('actionBarsBar1').x == 0 and not addon.editWindow.propagate, 'arrow keys nudge too')
    -- Dragging: the bar follows live; near 0 a guide shows and the drop snaps.
    assert(PM:StartDragging('actionBarsBar1'))
    mover1.centerX = mover1.centerX + 5; M.follower.scripts.OnUpdate(M.follower)
    assert(Point(bar1)[4] == mover1:GetLeft() - UIParent:GetLeft(), 'the bar follows while dragging')
    element.dragUpdate()
    assert(PM.guides and PM.guides.x:IsShown(), 'center guide near an X of 0')
    assert(PM:StopDragging('actionBarsBar1') and PM:GetPosition('actionBarsBar1').x == 0 and not PM.guides.frame:IsShown(), 'snapped to 0')
    -- Blizzard's counts and keybinds can be secret; the preview copies them as they are.
    ActionButton3.Count:SetText(Secret('charges')); ActionButton4.HotKey:SetText(Secret('key'))
    addon.EditMode:Select('actionBarsPet')
    addon.editWindow.settingsButton.scripts.OnClick(addon.editWindow.settingsButton)
    local page = addon.configWindow.pages.actionBars
    assert(not addon.editMode and page and page:IsShown() and page.barEditing() == 'pet', 'Open Module Settings opens the selected bar')

    -- Settings page and preview: the player's own bar.
    local sections = {}
    for _, section in ipairs(page.sections) do sections[#sections + 1] = section.title end
    assert(table.concat(sections, ',') == 'Bar,Buttons,Text,Glows,Visibility', 'five tabs')
    assert(page.buttonsSlider.high == 10, 'pet bar slider stops at ten')
    page.SetEditing('bar1')
    assert(page.buttonsSlider.high == 12)
    local view = page.configPreview
    for i = 1, 12 do assert(view.buttons[i] and view.buttons[i]:IsShown(), 'every button drawn, secret texts and all') end
    assert(issecretvalue(view.buttons[3].Count.text) and issecretvalue(view.buttons[4].HotKey.text), 'secret texts shown as they are')
    assert(page.barSelect.label.text == 'Action Bar 1' and page.barSelect:GetParent():GetParent() == page.previewArea, 'Editing sits in the preview header')
    local corner = Point(page.barSelect:GetParent())
    assert(corner[1] == 'TOPRIGHT' and corner[2] == page.previewArea, 'at its top right')
    assert(page.previewHeaderButtons[1] == page.keybindHeaderButton and page.previewReserveRight > 0, 'header buttons keep clear of it')
    local editRows = 0
    for _, row in ipairs(page.rows) do if row.settingsTitle == 'Editing' then editRows = editRows + 1 end end
    assert(editRows == 0, 'no Editing rows in the tabs')
    local first = view.buttons[1]
    assert(first:IsShown() and first.width == 42 and first.height == 36, 'preview of the edited bar')
    assert(first.icon.texture == 'Interface/Icons/Spell1' and first.HotKey.text == '1', 'your own spell and keybind')
    assert(not view.buttons[8].icon:IsShown() and view.buttons[8].HotKey.text == '', 'an empty place stays empty')
    ActionButton2.Count:SetText('3'); ActionButton2.cooldown.realStart, ActionButton2.cooldown.realDuration = GetTime() - 2, 10
    FireEvent('ACTIONBAR_UPDATE_COOLDOWN')
    assert(view.buttons[2].Count.text == '3' and view.buttons[2].cooldownText.text == '8', 'counts and running cooldowns')
    first.hits.hotkey.scripts.OnMouseUp(first.hits.hotkey, 'LeftButton')
    assert(page.selectedSection.title == 'Text' and page.textPart() == 'hotkey', 'keybind click opens Text')
    view.buttons[2].hits.count.scripts.OnMouseUp(view.buttons[2].hits.count, 'LeftButton')
    assert(page.textPart() == 'count' and page.textAnchorButtons.BOTTOMRIGHT.selected, 'count click picks Count')
    page.textAnchorButtons.TOPLEFT.scripts.OnClick(page.textAnchorButtons.TOPLEFT)
    assert(M.db.bar1.countAnchor == 'TOPLEFT' and Point(ActionButton1.Count)[1] == 'TOPLEFT', 'anchor picker moves the count')
    page.SetTextPart('cooldown')
    assert(first.cooldownText.text ~= '', 'a sample cooldown while editing the cooldown text')
    first.scripts.OnMouseUp(first, 'LeftButton')
    assert(page.selectedSection.title == 'Bar', 'button click opens Bar')
    -- The glow menu opens to the left of the clicked button, which previews its glow.
    local menu = ModeUIActionBarGlowMenu
    assert(menu:IsShown() and menu.index == 1 and view.glowIndex == 1 and menu.title.text == 'Action Bar 1, button 1', 'glow menu for button 1')
    local at = Point(menu)
    assert(at[1] == 'RIGHT' and at[2] == first and at[3] == 'LEFT', 'left of the button')
    local preview = M.glows[first]
    -- One glow at a time: the proc glow wins over the ready glow of the same kind.
    assert(preview and preview.proc:IsShown() and preview.ready.wanted and not preview.ready:IsShown(), 'one glow at a time')
    assert(menu.procBox.selected and menu.readyBox.selected and menu.grayBox.selected)
    menu.procBox.scripts.OnClick(menu.procBox)
    assert(M.db.bar1.buttonGlows['1'].proc == false and not menu.procBox.selected and not preview.proc:IsShown(), 'switching the proc glow off here')
    assert(preview.ready:IsShown(), 'the ready glow shows once the proc glow is off')
    menu.procBox.scripts.OnClick(menu.procBox)
    assert(M.db.bar1.buttonGlows['1'] == nil and preview.proc:IsShown() and not preview.ready:IsShown())
    -- A glow wins over a border.
    menu.procButtons[2].scripts.OnClick(menu.procButtons[2])
    assert(M.db.bar1.procGlow == 'border' and preview.ready:IsShown() and not preview.proc:IsShown(), 'a ready glow overrides a proc border')
    menu.readyButtons[2].scripts.OnClick(menu.readyButtons[2])
    assert(M.db.bar1.readyStyle == 'border' and preview.proc:IsShown() and preview.proc.edges[1]:IsShown() and not preview.ready:IsShown(), 'two borders: the proc wins')
    menu.readyButtons[1].scripts.OnClick(menu.readyButtons[1])
    menu.procButtons[1].scripts.OnClick(menu.procButtons[1])
    -- Desaturate on Cooldown for this button.
    menu.grayBox.scripts.OnClick(menu.grayBox)
    assert(M.db.bar1.buttonGlows['1'].gray == false and not menu.grayBox.selected, 'this button keeps its color')
    ActionButton1.action = 1
    cooldowns[1] = { isActive = true, isOnGCD = false }; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(ActionButton1.icon.desaturated ~= true, 'no gray on a button switched off')
    cooldowns[1] = nil; FireEvent('SPELL_UPDATE_COOLDOWN')
    -- Copy, Paste and Apply to Bar.
    assert(not menu.paste:IsEnabled(), 'nothing to paste yet')
    menu.copy.scripts.OnClick(menu.copy)
    assert(menu.paste:IsEnabled())
    view.buttons[4].scripts.OnMouseUp(view.buttons[4], 'LeftButton')
    assert(menu:IsShown() and menu.index == 4 and menu.button == view.buttons[4], 'the menu follows the clicked button')
    menu.paste.scripts.OnClick(menu.paste)
    assert(M.db.bar1.buttonGlows['4'].gray == false and not menu.grayBox.selected, 'pasted onto button 4')
    menu.apply.scripts.OnClick(menu.apply)
    assert(M.db.bar1.buttonGlows['12'].gray == false and M.db.bar1.buttonGlows['1'].gray == false, 'applied to the whole bar')
    menu.grayBox.scripts.OnClick(menu.grayBox); menu.apply.scripts.OnClick(menu.apply)
    assert(next(M.db.bar1.buttonGlows) == nil, 'and back: nothing stored')
    -- It stays open while the page scrolls; a click elsewhere or X closes it.
    page.scrollbar.scripts.OnValueChanged(page.scrollbar, 40)
    assert(menu:IsShown(), 'scrolling keeps it open')
    menu.mouseOver = true; FireEvent('GLOBAL_MOUSE_DOWN', 'LeftButton')
    assert(menu:IsShown(), 'clicks inside keep it open')
    menu.mouseOver = false; FireEvent('GLOBAL_MOUSE_DOWN', 'LeftButton')
    assert(not menu:IsShown() and view.glowIndex == nil, 'a click elsewhere closes it')
    first.scripts.OnMouseUp(first, 'LeftButton')
    menu.close.scripts.OnClick(menu.close)
    assert(not menu:IsShown(), 'X closes it')
    first.scripts.OnMouseUp(first, 'LeftButton')
    menu.more.scripts.OnClick(menu.more)
    assert(not menu:IsShown() and page.selectedSection.title == 'Glows' and not preview.proc:IsShown(), 'All Glow Settings opens Glows')
    first.scripts.OnMouseUp(first, 'LeftButton'); page.SetEditing('bar2')
    assert(not menu:IsShown(), 'switching bars closes the menu'); page.SetEditing('bar1')
    assert(M:SetOption('bar1', 'width', 30) and first.width == 30 and ActionButton1.width == 30, 'preview and bar follow the size')
    assert(page.keybindButton and page.keybindHeaderButton and page.keybindHeaderButton:GetParent() == page.previewArea, 'Keybind Mode on the Bar tab and in the preview header')
    page.keybindHeaderButton.scripts.OnClick(page.keybindHeaderButton)
    assert(M.binding and not addon.configWindow:IsShown(), 'the header button starts Keybind Mode')
    M:SetKeybindMode(false); addon.configWindow:Show()
    -- Name tags on the bars while this page is open; the edited bar's is cyan.
    local tag1, tag2 = ModeUIActionBar1Tag, ModeUIActionBar2Tag
    assert(tag1:IsShown() and tag2:IsShown() and tag1.text.text == 'Action Bar 1' and Point(tag1)[2] == bar1, 'each bar is named on screen')
    assert(tag1.text.color[3] == Kit.palette.accent[3] and tag2.text.color[3] ~= Kit.palette.accent[3], 'the edited bar stands out')
    assert(not (ModeUIActionBar6Tag and ModeUIActionBar6Tag:IsShown()), 'no tag for a bar that is off screen')
    tag2.scripts.OnClick(tag2)
    assert(page.barEditing() == 'bar2' and tag2.text.color[3] == Kit.palette.accent[3], 'clicking a tag edits that bar')
    addon:SelectConfigPage('nameplates'); assert(not tag1:IsShown(), 'tags go when the page closes')
    addon:SelectConfigPage('actionBars'); assert(tag1:IsShown(), 'and come back with it')
    addon.configWindow:Hide(); assert(not tag1:IsShown(), 'and go with the window')
    addon.configWindow:Show(); page.SetEditing('bar1')

    -- Paging: Action Bar 1 follows the game's paging; others page when switched on.
    assert(frameRefs[bar1].button1 == ActionButton1 and frameRefs[ModeUIActionBar2].button12 == MultiBarBottomLeftButton12, 'the paging snippet reaches each button')
    assert(not frameRefs[ModeUIPetBar], 'the pet bar does not page')
    assert(bar1.attributes['_onstate-modepage']:find('actionpage', 1, true))
    assert(drivers[bar1].modepage == nil and bar1.attributes['state-modepage'] == 'none', "bar 1 follows the game's own paging")
    assert(M:SetOption('bar1', 'paging', false) and drivers[bar1].modepage == '1', 'Page Switching off: page 1')
    assert(M:SetOption('bar1', 'paging', true) and drivers[bar1].modepage == nil)
    assert(M:SetOption('bar1', 'pageConditions', '[bonusbar:1] 7;') and drivers[bar1].modepage == '[bonusbar:1] 7; none', 'own conditions, own page when none match')
    assert(M:SetOption('bar1', 'pageConditions', '') and drivers[bar1].modepage == nil)
    assert(drivers[ModeUIActionBar2].modepage == nil, 'other bars keep their page')
    assert(M:SetOption('bar2', 'paging', true) and drivers[ModeUIActionBar2].modepage == '[mod:shift] 2; [mod:ctrl] 3; [mod:alt] 4; none')
    assert(M:SetOption('bar2', 'pageConditions', '[bogus] 3') and drivers[ModeUIActionBar2].modepage == nil, 'unreadable conditions keep the own page')
    assert(M:SetOption('bar2', 'paging', false))

    -- Proc glows: Mode Glow by default, with Blizzard's alert faded.
    ActionButtonSpellAlertManager:ShowAlert(ActionButton2)
    local proc = M.glows[ActionButton2].proc
    assert(proc:IsShown() and proc.soft:IsShown() and proc.soft.vertexColor[1] == M.PROC_COLOR[1], 'gold Mode glow')
    assert(ActionButton2.SpellActivationAlert:GetAlpha() == 0, "Blizzard's alert faded")
    assert(M:SetOption('bar1', 'procGlow', 'border') and not proc.soft:IsShown() and proc.edges[1]:IsShown(), 'Border style')
    assert(M:SetOption('bar1', 'procColor', { 0, 1, 0 }) and proc.edges[1].vertexColor[2] == 1, 'proc color')
    assert(M:SetOption('bar1', 'procGlow', 'blizzard') and not proc:IsShown() and ActionButton2.SpellActivationAlert:GetAlpha() == 1, 'Blizzard style')
    assert(M:SetOption('bar1', 'procGlow', 'none') and not proc:IsShown() and ActionButton2.SpellActivationAlert:GetAlpha() == 0, 'None')
    assert(M:SetOption('bar1', 'procGlow', 'mode') and proc:IsShown())
    ActionButtonSpellAlertManager:HideAlert(ActionButton2)
    assert(not proc:IsShown(), 'the glow ends with the proc')
    -- Per-button switches.
    assert(M:SetButtonGlow('bar1', 2, 'proc', false) and M.db.bar1.buttonGlows['2'].proc == false)
    ActionButtonSpellAlertManager:ShowAlert(ActionButton2)
    assert(not proc:IsShown() and ActionButton2.SpellActivationAlert:GetAlpha() == 0, 'no proc glow on a button switched off')
    ActionButtonSpellAlertManager:HideAlert(ActionButton2)
    assert(M:SetButtonGlow('bar1', 2, 'proc', true) and M.db.bar1.buttonGlows['2'] == nil, 'on again: nothing stored')
    assert(not M:SetOption('bar1', 'buttonGlows', { ['13'] = { proc = false } }), 'places stay on the bar')

    -- Cooldowns: a real cooldown ending lights the ready glow; the GCD doesn't.
    local timers = {}
    local after = C_Timer.After
    C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
    ActionButton3.action = 3; ActionButton4.action = 4
    assert(M:SetOption('bar1', 'cooldownOpacity', 40))
    cooldowns[3] = { isActive = true, isOnGCD = false }; cooldowns[4] = { isActive = true, isOnGCD = true }
    FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(ActionButton3.icon:GetAlpha() == 0.4 and ActionButton4.icon:GetAlpha() == 1, 'Icon Opacity on a real cooldown only')
    cooldowns[3], cooldowns[4] = nil, nil
    FireEvent('SPELL_UPDATE_COOLDOWN')
    local ready = M.glows[ActionButton3] and M.glows[ActionButton3].ready
    assert(ready and ready:IsShown() and ready.soft.vertexColor[3] == M.READY_COLOR[3], 'ready glow when the cooldown ends')
    assert(not (M.glows[ActionButton4] and M.glows[ActionButton4].ready), 'nothing after the global cooldown')
    assert(ActionButton3.icon:GetAlpha() == 1, 'full icon when ready')
    for _, fn in ipairs(timers) do fn() end; assert(not ready:IsShown(), 'the glow lasts Glow Time')
    assert(M:SetOption('bar1', 'readyGlow', false))
    cooldowns[3] = { isActive = true, isOnGCD = false }; FireEvent('SPELL_UPDATE_COOLDOWN'); cooldowns[3] = nil; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(not ready:IsShown(), 'Glow When Ready off')
    assert(M:SetOption('bar1', 'readyGlow', true) and M:SetButtonGlow('bar1', 3, 'ready', false))
    cooldowns[3] = { isActive = true, isOnGCD = false }; FireEvent('SPELL_UPDATE_COOLDOWN'); cooldowns[3] = nil; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(not ready:IsShown(), 'no ready glow on a button switched off')
    assert(M:SetButtonGlow('bar1', 3, 'ready', true))
    -- Desaturate Icon (on by default): gray while a real cooldown runs, even
    -- if Blizzard clears it; full color when ready.
    cooldowns[3] = { isActive = true, isOnGCD = false }; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(ActionButton3.icon.desaturated == true, 'gray on cooldown')
    ActionButton3.icon:SetDesaturated(false)
    assert(ActionButton3.icon.desaturated == true, 'kept gray when Blizzard clears it')
    cooldowns[3] = nil; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(ActionButton3.icon.desaturated == false, 'full color when ready')
    assert(M:SetOption('bar1', 'cooldownDesaturate', false))
    cooldowns[3] = { isActive = true, isOnGCD = false }; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(ActionButton3.icon.desaturated == false, 'Desaturate Icon off keeps full color')
    cooldowns[3] = nil; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(M:SetOption('bar1', 'cooldownDesaturate', true))
    for _, fn in ipairs(timers) do fn() end
    C_Timer.After = after
    assert(M:SetOption('bar1', 'readyGlow', true) and M:SetOption('bar1', 'cooldownOpacity', 100))

    -- The Editing list marks bars that are off or hidden, and offers Turn On.
    page.barSelect.scripts.OnClick(page.barSelect)
    local labels = {}
    for _, row in ipairs(page.barSelect.rows) do if row:IsShown() then labels[row.choice.id] = row.label.text end end
    page.barSelect.menu:Hide()
    assert(labels.bar1 == 'Action Bar 1' and labels.bar6:find('Action Bar 6', 1, true) and labels.bar6:find('Off', 1, true), 'off bars are marked')
    assert(not page.turnOnButton:IsShown(), 'no Turn On for a bar that shows')
    page.SetEditing('bar6')
    assert(page.turnOnButton:IsShown() and page.barSelect.label.text:find('Off', 1, true), 'Turn On for an off bar')
    page.turnOnButton.scripts.OnClick(page.turnOnButton)
    assert(M.db.bar6.show and not page.turnOnButton:IsShown() and page.barSelect.label.text == 'Action Bar 6', 'Turn On shows the bar')
    assert(M:SetOption('bar6', 'visibility', 'hidden') and page.turnOnButton:IsShown() and page.barSelect.label.text:find('Hidden', 1, true), 'hidden bars are marked too')
    page.turnOnButton.scripts.OnClick(page.turnOnButton)
    assert(M.db.bar6.visibility == 'always', 'Turn On brings a hidden bar back to Always')
    assert(M:SetOption('bar6', 'show', false))
    page.SetEditing('bar1')

    -- Apply Style: tick bars, then apply this bar's look to them.
    assert(M:SetOption('bar1', 'borderSize', 3))
    local cells = page.applyToggles
    cells[3].frame.scripts.OnClick(cells[3].frame); cells[5].frame.scripts.OnClick(cells[5].frame)
    cells[1].frame.scripts.OnClick(cells[1].frame)
    assert(page.applyTargets.bar3 and page.applyTargets.bar5 and not page.applyTargets.bar1, 'the edited bar is skipped')
    page.applyButton.scripts.OnClick(page.applyButton)
    assert(M.db.bar3.borderSize == 3 and M.db.bar5.borderSize == 3 and M.db.bar4.borderSize == 2, 'applied to the ticked bars only')
    assert(M.db.bar5.orientation == 'vertical' and page.applyResult.text == 'Applied to 2 bars.', 'shape kept; result shown')
    assert(M.db.bar3.paging == false and M.db.bar3.pageConditions:find('mod:shift', 1, true), 'paging stays per bar')
    cells[3].frame.scripts.OnClick(cells[3].frame); cells[5].frame.scripts.OnClick(cells[5].frame)
    page.applyButton.scripts.OnClick(page.applyButton)
    assert(page.applyResult.text == 'Choose bars first.', 'nothing ticked')
    page.applyAllButton.scripts.OnClick(page.applyAllButton)
    assert(M.db.bar4.borderSize == 3 and M.db.pet.borderSize == 3 and page.applyResult.text == 'Applied to 9 bars.', 'Apply to All Bars')
    for _, bar in ipairs(M.bars) do assert(M:SetOption(bar, 'borderSize', 2)) end

    -- Copy and reset.
    assert(M:SetOption('bar1', 'border', 'square') and M:CopyStyleToAll('bar1'))
    assert(M.db.bar5.border == 'square' and M.db.bar5.width == 30 and M.db.bar5.orientation == 'vertical' and M.db.pet.buttons == 10, 'look copied, shape kept')
    assert(M:ResetBar('bar5') and M.db.bar5.width == 42 and M.db.bar5.border == 'rounded')

    -- Switching off gives everything back; the look returns on reload.
    bar1:SetAttribute('modeshown', 'show') -- as the state handler would
    addon:SetModuleEnabled('actionBars', false)
    assert(ActionButton1:GetParent() == ActionButton1.container and ActionButton1.width == 45 and Point(ActionButton1)[1] == 'CENTER', 'buttons go home')
    assert(MainActionBar:GetParent() == UIParent and not bar1:IsShown() and drivers[bar1].modevis == nil, 'Blizzard bars are back')
    assert(bar1.attributes.modeshown == nil, 'leaving a vehicle cannot show the emptied bar')
    assert(addon.ReloadManager:IsPending(), 'reload offered for the button art')
    assert(not M:SetKeybindMode(true), 'Keybind Mode needs the module on')
    addon:SetModuleEnabled('actionBars', true)
    assert(ActionButton1:GetParent() == bar1 and not addon.ReloadManager:IsPending(), 'back on without a reload')
]==], "action bars")

local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([==[
    local M = addon.ActionBars
    assert(M.enabled and M.db.bar1.width == 30 and M.db.bar2.buttons == 6 and M.db.bar3.border == 'square', 'settings persist')
    assert(addon.PositionManager:GetPosition('actionBarsBar1').y == 81, 'position persists')
    assert(ActionButton1:GetParent() == ModeUIActionBar1 and ActionButton1.width == 30)
]==], "restore")

-- Version 1: 42x38 buttons, white cooldown numbers, Fade Until Mouseover and
-- separate places. Values still at version 1's defaults move to version 2's.
local v1 = restored.saved()
local profile = v1.profiles.Default
local old = profile.modules.actionBars
old.version = 1
for _, bar in ipairs({ "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8", "pet", "stance" }) do
    old[bar].height, old[bar].cooldownColor, old[bar].backgroundOpacity, old[bar].hotkeySize = 38, { 1, 1, 1 }, nil, 11
end
old.bar3.fade, old.bar3.visibility, old.bar4.fade, old.bar4.visibility, old.bar5.height = true, "always", true, "combat", 40
-- Version 2's look: the Onyx rim color, muted macro names, 2px spacing.
local onyxRim, muted = { 37 / 255, 40 / 255, 44 / 255 }, { 185 / 255, 185 / 255, 185 / 255 }
old.bar1.borderColor, old.bar1.macroColor, old.bar1.spacing, old.bar1.borderSize, old.bar1.backgroundColor = onyxRim, muted, 2, nil, nil
old.bar2.borderColor, old.bar2.spacing = { 1, 0, 0 }, 6
profile.positions.actionBarsBar2 = { target = "screen", placement = "center", point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 58 }
profile.positions.actionBarsBar3 = { target = "screen", placement = "center", point = "BOTTOM", relativePoint = "BOTTOM", x = 30, y = 100 }
H.Load({ before = STUBS, saved = v1 }).run([==[
    local M, PM = addon.ActionBars, addon.PositionManager
    assert(M.db.bar1.borderColor[1] == M.BORDER_COLOR[1] and M.db.bar1.macroColor[3] == M.MACRO_COLOR[3] and M.db.bar1.spacing == 1, 'version 2 defaults move')
    assert(M.db.bar1.borderSize == 2 and M.db.bar1.backgroundColor[1] == M.BACKGROUND_COLOR[1], 'new settings take their defaults')
    assert(M.db.bar2.borderColor[1] == M.BORDER_COLOR[1] and M.db.bar2.spacing == 6, 'version 4 sets every border; chosen spacing stays')
    assert(M.db.version == 5 and M.db.bar1.height == 36 and M.db.bar5.height == 40, 'default height moves; a chosen one stays')
    assert(M.db.bar1.cooldownColor[2] == M.COOLDOWN_COLOR[2] and M.db.bar1.backgroundOpacity == 75 and M.db.bar3.backgroundOpacity == 75, 'version 4 sets 75% on every bar')
    assert(M.db.bar1.hotkeySize == 9 and M.db.bar1.cooldownDesaturate and M.db.bar1.hotkeyShort, 'version 5: keybinds 2px smaller')
    assert(M.db.bar3.visibility == 'mouseover' and M.db.bar3.fade == nil and M.db.bar4.visibility == 'combat', 'fading becomes Mouseover')
    assert(PM:GetPosition('actionBarsBar2').target == 'actionBarsBar1', 'a default place stacks on bar 1')
    assert(PM:GetPosition('actionBarsBar3').target == 'screen' and PM:GetPosition('actionBarsBar3').x == 30, 'a moved bar stays put')
]==], "migrate v1")

-- Bad saved data stops startup rather than being reset.
local saved = restored.saved()
saved.profiles.Default.modules.actionBars.bar1.width = "wide"
local ok = pcall(H.Load, { before = STUBS, saved = saved })
assert(not ok, "invalid action bar settings are refused")

print("action bars: all checks passed")
