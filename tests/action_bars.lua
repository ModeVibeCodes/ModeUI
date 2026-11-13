-- Action Bars: moving Blizzard's buttons onto ModeUI bars, layout, the
-- 42x38 skin, text styling and its hooks, show conditions, fading, Edit
-- Mode, the settings page and preview, combat deferral, switching off and
-- persistence. Simulated client; not WoW rendering, security or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. [==[
    local methods = getmetatable(UIParent).__index
    local setParent = methods.SetParent
    function methods:SetParent(parent)
        assert(not (self.secure and InCombatLockdown()), 'SetParent on secure frame in combat')
        return setParent(self, parent)
    end
    function methods:IsMouseOver() return self.mouseOver == true end
    function methods:RemoveMaskTexture(mask) assert(self.mask == mask, 'removes its own mask'); self.mask = nil end
    function methods:GetCountdownFontString()
        self.countdown = self.countdown or self:CreateFontString(nil, 'OVERLAY')
        return self.countdown
    end
    RED_FONT_COLOR = { GetRGB = function() return 1, 0.125, 0.125 end }
    testForms = 0
    function GetNumShapeshiftForms() return testForms end
    -- Secure handlers record what was asked of them.
    drivers, wraps = {}, {}
    function RegisterStateDriver(frame, state, values)
        assert(not InCombatLockdown(), 'state driver in combat'); drivers[frame] = drivers[frame] or {}; drivers[frame][state] = values
    end
    function UnregisterStateDriver(frame, state) if drivers[frame] then drivers[frame][state] = nil end end
    function SecureHandlerWrapScript(frame, script, header, body) wraps[#wraps + 1] = { frame = frame, script = script, header = header, body = body } end
    function SecureCmdOptionParse(text) if text:find('bogus', 1, true) then error('Unknown macro option') end return 'show' end
    local create = CreateFrame
    function CreateFrame(kind, name, parent, template)
        local f = create(kind, name, parent, template)
        if template == 'SecureHandlerStateTemplate' then f.secure = true end
        return f
    end

    -- Blizzard's bars and buttons: each button sits on a container of its bar.
    local function Button(name, bar, index)
        local container = CreateFrame('Frame', nil, bar)
        local b = CreateFrame('Button', name, container)
        b.secure, b.bar, b.container, b.index = true, bar, container, index
        b:SetSize(45, 45); b:SetPoint('CENTER')
        b.icon = b:CreateTexture(nil, 'BACKGROUND')
        b.IconMask = b:CreateMaskTexture(); b.icon:AddMaskTexture(b.IconMask)
        for _, key in ipairs({ 'SlotBackground', 'SlotArt', 'NormalTexture', 'PushedTexture', 'HighlightTexture', 'CheckedTexture',
            'Flash', 'Border', 'NewActionTexture', 'SpellHighlightTexture' }) do b[key] = b:CreateTexture(nil, 'OVERLAY') end
        b.NormalTexture:SetAtlas('UI-HUD-ActionBar-IconFrame')
        b.cooldown = CreateFrame('Cooldown', nil, b)
        b.TextOverlayContainer = CreateFrame('Frame', nil, b)
        b.HotKey = b.TextOverlayContainer:CreateFontString(nil, 'OVERLAY')
        b.Count = b.TextOverlayContainer:CreateFontString(nil, 'OVERLAY')
        b.Name = b:CreateFontString(nil, 'OVERLAY')
        function b:UpdateHotkeys() self.HotKey:SetSize(37, 10); self.HotKey:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -4, -5); self.HotKey:SetText(tostring(index)) end
        function b:UpdateButtonArt() self.NormalTexture:SetAtlas('UI-HUD-ActionBar-IconFrame'); self.NormalTexture:SetAlpha(1) end
        b:UpdateHotkeys()
        return b
    end
    local function Bar(name, prefix, count)
        local bar = CreateFrame('Frame', name, UIParent)
        for i = 1, count do Button(prefix .. i, bar, i) end
        return bar
    end
    Bar('MainActionBar', 'ActionButton', 12)
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
        assert(style.width == 42 and style.height == 38, bar .. ' buttons are 42 by 38')
    end
    assert(M.db.bar1.show and not M.db.bar6.show and M.db.bar4.orientation == 'vertical' and M.db.pet.buttons == 10)

    addon:SetModuleEnabled('actionBars', true)
    local bar1 = ModeUIActionBar1
    assert(M.built and bar1 and bar1.secure, 'a secure bar per bar')
    assert(MainActionBar:GetParent() == M.hider and PetActionBar:GetParent() == M.hider and StanceBar:GetParent() == M.hider, 'bars with art are hidden')
    assert(MultiBarBottomLeft:GetParent() == UIParent, 'art-less Blizzard bars are left alone')
    assert(ActionButton1:GetParent() == bar1 and ActionButton1.bar == MainActionBar, 'buttons move but keep their Blizzard bar for paging')
    assert(ActionButton1.width == 42 and ActionButton1.height == 38, 'buttons are 42 by 38')
    assert(bar1.width == 526 and bar1.height == 38, '12 buttons, 2px apart')
    local p = Point(ActionButton2)
    assert(p[1] == 'TOPLEFT' and p[2] == bar1 and p[4] == 44 and p[5] == 0, 'second button one step right')
    assert(Point(ModeUIActionBar4)[1] == 'RIGHT', 'bar 4 sits on the right edge')
    assert(ModeUIActionBar4.width == 42 and ModeUIActionBar4.height == 12 * 38 + 11 * 2, 'bar 4 stands upright')

    -- Skin: rim and gap, icon inset 2px and cropped to 38x34, Blizzard's frame faded.
    local art = M.art[ActionButton1]
    assert(art.rim:IsShown() and art.rim.vertexColor[1] == Kit.onyx.border[1] and art.gap.vertexColor[1] == 0, 'rim and black gap')
    local icon = ActionButton1.icon
    assert(icon.mask == nil, 'Blizzard icon mask removed')
    assert(icon.points[1][4] == 2 and icon.points[2][4] == -2, 'icon inside the rim')
    local span = 0.84 * 34 / 38
    assert(math.abs(icon.texCoord[3] - (0.5 - span / 2)) < 1e-9 and icon.texCoord[1] == 0.08, 'icon cropped, not stretched')
    assert(ActionButton1.NormalTexture.alpha == 0 and ActionButton1.SlotArt.alpha == 0, 'Blizzard frame art faded')
    ActionButton1:UpdateButtonArt()
    assert(ActionButton1.NormalTexture.alpha == 0, 'faded again after Blizzard redraws its art')
    assert(ActionButton1.HighlightTexture.texture == Kit.FLAT, 'flat Mode highlight')

    -- Text: font, place inside the icon, keybind color kept unless out of range.
    local hotkey = ActionButton1.HotKey
    assert(hotkey.font[2] == 11 and hotkey.font[3] == 'OUTLINE', 'keybind 11 with outline')
    local at = Point(hotkey)
    assert(at[1] == 'TOPRIGHT' and at[4] == -4 and at[5] == -4, 'keybind tucked into the corner')
    ActionButton1:UpdateHotkeys()
    at = Point(hotkey)
    assert(#hotkey.points == 1 and at[4] == -4, 'Blizzard re-placing the keybind is undone')
    hotkey:SetVertexColor(0.6, 0.6, 0.6)
    assert(hotkey.vertexColor[1] == M.db.bar1.hotkeyColor[1], 'keybind color kept')
    hotkey:SetVertexColor(1, 0.125, 0.125)
    assert(hotkey.vertexColor[2] == 0.125, 'out of range stays red')
    assert(ActionButton1.Name.alpha == 0, 'macro names hidden by default')
    assert(ActionButton1.cooldown.countdown.font[2] == 14, 'cooldown numbers styled')

    -- Lifted shadow: a copy that follows Blizzard's text, even when secret.
    assert(M:SetOption('bar1', 'liftedShadow', true))
    local lift = M.lifts[ActionButton1.Count]
    assert(lift and lift:IsShown(), 'lift made on first use')
    ActionButton1.Count:SetText(Secret('charges'))
    assert(issecretvalue(lift.text), 'secret count copied straight to the lift')
    ActionButton1.Count:Hide(); assert(not lift:IsShown(), 'lift hides with its text')
    ActionButton1.Count:Show(); assert(lift:IsShown())
    assert(M:SetOption('bar1', 'liftedShadow', false) and not lift:IsShown(), 'lift off with Crisp')

    -- Fewer buttons: the rest wait on the hidden frame, not on Blizzard's bar.
    assert(M:SetOption('bar2', 'buttons', 6))
    assert(MultiBarBottomLeftButton6:GetParent() == ModeUIActionBar2 and MultiBarBottomLeftButton7:GetParent() == M.hider)
    assert(not M:SetOption('pet', 'buttons', 12) and M.db.pet.buttons == 10, 'pet bar holds ten')
    assert(M:SetOption('bar2', 'perLine', 3) and ModeUIActionBar2.width == 3 * 42 + 4 and ModeUIActionBar2.height == 2 * 38 + 2, 'two rows of three')
    assert(M:SetOption('bar2', 'start', 'BOTTOMRIGHT'))
    p = Point(MultiBarBottomLeftButton4)
    assert(p[1] == 'BOTTOMRIGHT' and p[4] == 0 and p[5] == 40, 'fourth button starts the second row up from the corner')

    -- Show conditions.
    assert(drivers[bar1].modevis == '[petbattle] hide; show', 'always, except pet battles')
    assert(drivers[ModeUIActionBar6].modevis == 'hide', 'hidden bar')
    assert(drivers[ModeUIPetBar].modevis:find('[nopet] hide; show', 1, true), 'pet bar needs a pet')
    assert(drivers[ModeUIStanceBar].modevis == 'hide', 'no stances, no stance bar')
    testForms = 3; FireEvent('UPDATE_SHAPESHIFT_FORMS')
    assert(drivers[ModeUIStanceBar].modevis:find('show') and ModeUIStanceBar.width == 3 * 42 + 2 * 2, 'stance bar fits the stances')
    assert(StanceButton4:GetParent() == M.hider)
    assert(M:SetOption('bar1', 'visibility', 'combat') and drivers[bar1].modevis == '[petbattle] hide; [combat] show; hide')
    assert(M:SetOption('bar1', 'visibility', 'custom') and drivers[bar1].modevis == '[petbattle] hide; [combat] show; hide')
    assert(M:SetOption('bar1', 'customVisibility', '[bogus] show; hide') and drivers[bar1].modevis == '[petbattle] hide; show', 'unreadable conditions show the bar')
    assert(not M:SetOption('bar1', 'customVisibility', 'a\nb'), 'one line only')
    assert(M:SetOption('bar1', 'visibility', 'always'))
    assert(bar1.attributes['_onstate-modevis']:find('modeoverride', 1, true), 'state handler honors the vehicle bar')
    assert(#wraps == 2 and wraps[1].frame == OverrideActionBar and wraps[1].header == bar1 and wraps[2].script == 'OnHide', 'bar 1 watches the vehicle bar')

    -- Fading.
    assert(M:SetOption('bar3', 'fade', true) and ModeUIActionBar3:GetAlpha() == 0, 'faded until mouseover')
    ModeUIActionBar3:Show(); ModeUIActionBar3.mouseOver = true; Advance(0.2)
    assert(ModeUIActionBar3:GetAlpha() == 1, 'shows under the mouse')
    ModeUIActionBar3.mouseOver = false; Advance(0.2); assert(ModeUIActionBar3:GetAlpha() == 0)
    FireEvent('ACTIONBAR_SHOWGRID'); assert(ModeUIActionBar3:GetAlpha() == 1, 'dragging a spell shows it')
    FireEvent('ACTIONBAR_HIDEGRID'); assert(ModeUIActionBar3:GetAlpha() == 0)
    assert(M:SetOption('bar3', 'opacity', 50) and M:SetOption('bar3', 'fade', false) and ModeUIActionBar3:GetAlpha() == 0.5, 'plain opacity')

    -- Combat: no settings changes; layout work waits for the end of combat.
    testCombat, testLockdown = true, true
    assert(not M:SetOption('bar1', 'width', 50), 'no changes in combat')
    ActionButton1:UpdateHotkeys()
    assert(#ActionButton1.HotKey.points == 2 and addon.Defer:IsQueued('actionBars:refresh'), 'keybind re-placing waits for combat to end')
    testCombat, testLockdown = false, false
    FireEvent('PLAYER_REGEN_ENABLED')
    assert(not addon.Defer:IsQueued('actionBars:refresh') and #ActionButton1.HotKey.points == 1, 'placed after combat')

    -- Edit Mode: one movable stand-in per shown bar, named for it.
    local element = PM.elements.actionBarsBar1
    assert(element and element.label == 'Action Bar 1' and PM.elements.actionBarsPet and PM.elements.actionBarsStance)
    assert(addon:SetEditMode(true))
    local ghost = ModeUIActionBar1Mover
    assert(ghost:IsShown() and ghost.width == bar1.width and ghost.label.text == 'Action Bar 1', 'stand-in matches the bar')
    assert(not ModeUIActionBar6Mover:IsShown() and not PM.elements.actionBarsBar6.editMode, 'hidden bars are not movable')
    assert(PM:SetPosition('actionBarsBar1', { target = 'screen', placement = 'center', point = 'BOTTOM', relativePoint = 'BOTTOM', x = 0, y = 80 }))
    p = Point(bar1)
    assert(p[1] == 'BOTTOM' and p[3] == 'BOTTOM' and p[5] == 80, 'the bar follows its stand-in')
    addon.EditMode:Select('actionBarsPet')
    addon.editWindow.settingsButton.scripts.OnClick(addon.editWindow.settingsButton)
    local page = addon.configWindow.pages.actionBars
    assert(not addon.editMode and page and page:IsShown() and page.barEditing() == 'pet', 'Open Module Settings opens the selected bar')

    -- Settings page and preview.
    local sections = {}
    for _, section in ipairs(page.sections) do sections[#sections + 1] = section.title end
    assert(table.concat(sections, ',') == 'Bar,Buttons,Text,Visibility', 'four tabs')
    assert(page.buttonsSlider.high == 10, 'pet bar slider stops at ten')
    page.SetEditing('bar1')
    assert(page.buttonsSlider.high == 12)
    local view = page.configPreview
    local first = view.buttons[1]
    assert(first:IsShown() and first.width == 42 and first.height == 38 and first.HotKey.text == '1', 'preview of the edited bar')
    assert(view.buttons[2].cooldownText.text == '5' and view.buttons[3].Count.text == '3', 'sample cooldown and count')
    first.hits.hotkey.scripts.OnMouseUp(first.hits.hotkey, 'LeftButton')
    assert(page.selectedSection.title == 'Text' and page.textPart() == 'hotkey', 'keybind click opens Text')
    view.buttons[3].hits.count.scripts.OnMouseUp(view.buttons[3].hits.count, 'LeftButton')
    assert(page.textPart() == 'count' and page.textAnchorButtons.BOTTOMRIGHT.selected, 'count click picks Count')
    page.textAnchorButtons.TOPLEFT.scripts.OnClick(page.textAnchorButtons.TOPLEFT)
    assert(M.db.bar1.countAnchor == 'TOPLEFT' and Point(ActionButton1.Count)[1] == 'TOPLEFT', 'anchor picker moves the count')
    first.scripts.OnMouseUp(first, 'LeftButton')
    assert(page.selectedSection.title == 'Bar', 'button click opens Bar')
    assert(M:SetOption('bar1', 'width', 30) and first.width == 30 and ActionButton1.width == 30, 'preview and bar follow the size')

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
    addon:SetModuleEnabled('actionBars', true)
    assert(ActionButton1:GetParent() == bar1 and not addon.ReloadManager:IsPending(), 'back on without a reload')
]==], "action bars")

local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([==[
    local M = addon.ActionBars
    assert(M.enabled and M.db.bar1.width == 30 and M.db.bar2.buttons == 6 and M.db.bar3.border == 'square', 'settings persist')
    local p = Point(ModeUIActionBar1)
    assert(p[1] == 'BOTTOM' and p[5] == 80, 'position persists')
    assert(ActionButton1:GetParent() == ModeUIActionBar1 and ActionButton1.width == 30)
]==], "restore")

-- Bad saved data stops startup rather than being reset.
local saved = restored.saved()
saved.profiles.Default.modules.actionBars.bar1.width = "wide"
local ok = pcall(H.Load, { before = STUBS, saved = saved })
assert(not ok, "invalid action bar settings are refused")

print("action bars: all checks passed")
