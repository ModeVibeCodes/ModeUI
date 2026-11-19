-- Action Bars: moving Blizzard's buttons onto ModeUI bars, layout, the
-- 40x34 Mode skin (the frame edge, the Button face), text styling and its hooks, show conditions,
-- mouseover fading, Edit Mode (highlight, anchoring, guides, nudging),
-- Keybind Mode, the settings page and its live preview, combat deferral,
-- switching off, migration and persistence. Simulated client; not WoW
-- rendering, security or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/action_bar_stubs.lua")

local world = H.Load({ before = STUBS })
world.run([==[
    local M, PM, Kit = addon.ActionBars, addon.PositionManager, addon.Kit
    assert(M and not M.enabled and not M.built, 'Action Bars start off and build nothing')
    assert(ActionButton1:GetParent() == ActionButton1.container, 'Blizzard keeps its buttons while off')
    for _, bar in ipairs(M.bars) do
        local style = M.db[bar]
        local size = bar == 'micro' and { 32, 40 } or bar == 'bags' and { 36, 36 } or { 40, 34 }
        assert(style.width == size[1] and style.height == size[2] and style.backgroundOpacity == 100, bar .. ' buttons sized for their kind on a full face')
        assert(math.floor(style.cooldownColor[1] * 255 + 0.5) == 255 and math.floor(style.cooldownColor[2] * 255 + 0.5) == 177
            and math.floor(style.cooldownColor[3] * 255 + 0.5) == 47, 'cooldown numbers are #FFB12F')
        local function Hex(c) return string.format('%02X%02X%02X', math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
        assert(Hex(style.backgroundColor) == '0E0E0E' and Hex(style.macroColor) == '69A5B9', 'Mono panel face and macro colors')
        assert(style.border == 'mode' and style.borderSize == nil and style.borderColor == nil and style.spacing == 4, 'the Mode edge, 4px apart')
        assert(style.procGlow == 'border' and Hex(style.procColor) == 'B4CDB6' and Hex(style.readyColor) == 'EFE6D2' and style.readyGlow, 'Celadon proc rim, Ivory ready glow')
        assert(style.fontMedia == 'Mode' and not style.outline and style.cooldownOpacity == 100, 'Geist, one shadow')
        assert(style.paging == (bar == 'bar1'), 'bar 1 pages; the others start fixed')
    end
    assert(M.db.bar1.show and not M.db.bar6.show and M.db.bar4.orientation == 'vertical' and M.db.pet.buttons == 10)

    addon:SetModuleEnabled('actionBars', true)
    local bar1 = ModeUIActionBar1
    assert(M.built and bar1 and bar1.secure, 'a secure bar per bar')
    assert(MainActionBar:GetParent() == M.hider and PetActionBar:GetParent() == M.hider and StanceBar:GetParent() == M.hider, 'bars with art are hidden')
    assert(MultiBarBottomLeft:GetParent() == UIParent, 'art-less Blizzard bars are left alone')
    assert(ActionButton1:GetParent() == bar1 and ActionButton1.bar == MainActionBar, 'buttons move but keep their Blizzard bar for paging')
    assert(ActionButton1.width == 40 and ActionButton1.height == 34, 'buttons are 40 by 34')
    -- Each button's edge reaches 3px past it (2px rim, 1px shadow); 4px between shadows.
    assert(M.EDGE_REACH == 3 and bar1.width == 12 * 50 - 4 and bar1.height == 40, '12 buttons with room for their edges')
    local p = Point(ActionButton2)
    assert(p[1] == 'TOPLEFT' and p[2] == bar1 and p[4] == 53 and p[5] == -3, 'second button one step right, inside its edge')
    assert(ModeUIActionBar4.width == 46 and ModeUIActionBar4.height == 12 * 44 - 4, 'bar 4 stands upright')
    -- Bars stack on bar 1 by default; every secure bar is pinned to the screen.
    assert(PM:GetPosition('actionBarsBar2').target == 'actionBarsBar1' and PM:GetPosition('actionBarsStance').target == 'actionBarsPet')
    local mover1, mover2 = ModeUIActionBar1Mover, ModeUIActionBar2Mover
    assert(Point(mover2)[2] == mover1 and Point(mover2)[1] == 'BOTTOM' and Point(mover2)[3] == 'TOP', 'bar 2 sits on bar 1')
    p = Point(ModeUIActionBar2)
    assert(p[1] == 'BOTTOMLEFT' and p[2] == UIParent and p[3] == 'BOTTOMLEFT', 'the secure bar hangs from the screen only')

    -- Skin: the frame edge outside the button, the Mode Button face, the icon filling it, cropped.
    local S, Tone = addon.Style, addon.Style.Tone
    local art = M.art[ActionButton1]
    assert(art.edge.preset == 'frame' and art.edge.holder:IsShown() and art.edge.host == ActionButton1, 'the frame edge')
    assert(art.face.texture == S.AssetPath('Button') and art.face.vertexColor[1] == Tone.mono.panel[1] and art.face.vertexColor[4] == 1, 'Mode Button face in Mono panel')
    local icon = ActionButton1.icon
    assert(icon.mask == nil, 'Blizzard icon mask removed')
    assert(icon.points[1][4] == 0 and icon.points[2][4] == 0, 'the icon fills the button')
    local span = 0.84 * 34 / 40
    assert(math.abs(icon.texCoord[3] - (0.5 - span / 2)) < 1e-9 and icon.texCoord[1] == 0.08, 'icon cropped, not stretched')
    assert(ActionButton1.NormalTexture.alpha == 0 and ActionButton1.SlotArt.alpha == 0, 'Blizzard frame art faded')
    ActionButton1:UpdateButtonArt()
    assert(ActionButton1.NormalTexture.alpha == 0, 'faded again after Blizzard redraws its art')
    assert(ActionButton1.HighlightTexture.alpha == 0 and ActionButton1.CheckedTexture.vertexColor[1] == Tone.ivory[1], 'hover is the edge line; checked Ivory')
    -- Hover lights the edge's outer line Ivory.
    ActionButton1.scripts.OnEnter(ActionButton1)
    assert(art.edge.highlight and art.edge.highlight[1] == Tone.ivory[1], 'Ivory line on hover')
    ActionButton1.scripts.OnLeave(ActionButton1)
    assert(art.edge.highlight == nil, 'gone on leave')
    local slot = M.slots.bar1[12]
    local slotArt = M.art[slot]
    assert(slot:IsShown() and slotArt.face.vertexColor[4] == 1 and slotArt.edge.holder:IsShown(), 'empty slot: the face in its edge')
    assert(M:SetOption('bar1', 'backgroundOpacity', 60) and slotArt.face.vertexColor[4] == 0.6, 'Background Opacity')
    assert(M:SetOption('bar1', 'backgroundColor', { 0, 0, 1 }) and slotArt.face.vertexColor[3] == 1, 'Background Color')
    assert(not M:SetOption('bar1', 'borderSize', 1) and not M:SetOption('bar1', 'border', 'rounded'), 'Border Size retired; Mode or None')
    assert(M:SetOption('bar1', 'border', 'none') and not art.edge.holder:IsShown() and bar1.width == 12 * 44 - 4, 'None: no edge, no room for it')
    assert(M:ResetBar('bar1') and M.db.bar1.border == 'mode' and M.db.bar1.backgroundOpacity == 100 and art.edge.holder:IsShown())
    -- Border Style and Border Metal (owner, November 17, 2026): every bar in
    -- Mode-Blizz in its own metal; any style keeps the layout; per bar.
    for _, bar in ipairs(M.bars) do assert(M.db[bar].edgeStyle == 'blizz' and M.db[bar].edgeMetal == 'default', bar .. ' in Mode-Blizz') end
    local art2 = M.art[MultiBarBottomLeftButton1]
    assert(art.edge.styleId == 'blizz' and art.edge:Metal() == Tone.metal.silver and slotArt.edge.styleId == 'blizz', 'buttons and slots in Mode-Blizz, Silver')
    local wide, tall, step = bar1.width, bar1.height, Point(ActionButton2)[4]
    assert(M:SetOption('bar1', 'edgeStyle', 'round') and art.edge.styleId == 'round' and slotArt.edge.styleId == 'round', 'Mode-Round')
    assert(bar1.width == wide and bar1.height == tall and Point(ActionButton2)[4] == step and art.edge:Outset() == 3, 'same layout, same reach')
    assert(art2.edge.styleId == 'blizz', 'other bars keep their own')
    assert(M:SetOption('bar1', 'edgeMetal', 'gunmetal') and art.edge:Metal() == Tone.metal.gunmetal and slotArt.edge:Metal() == Tone.metal.gunmetal, 'Gunmetal')
    assert(not M:SetOption('bar1', 'edgeStyle', 'nope') and not M:SetOption('bar1', 'edgeMetal', 'gold') and not M:SetOption('bar1', 'edgeStyle', 'none'), 'unknown styles and metals are refused')
    assert(M.db.bar1.edgeStyle == 'round' and M.db.bar1.edgeMetal == 'gunmetal')
    assert(M:SetOption('bar1', 'border', 'none') and not art.edge.holder:IsShown() and bar1.width == 12 * 44 - 4, 'None still hides the edge')
    assert(M:ResetBar('bar1') and art.edge.styleId == 'blizz' and art.edge:Metal() == Tone.metal.silver and art.edge.holder:IsShown())

    -- Text: font, tucked into its corner, keybind color kept unless out of range.
    local hotkey = ActionButton1.HotKey
    assert(hotkey.font[2] == 10 and hotkey.font[3] ~= 'OUTLINE' and hotkey.font[1]:find('Geist%-Bold'), 'keybind: Geist Bold 10, no outline')
    assert(ActionButton1.Count.font[2] == 11 and ActionButton1.Count.font[1]:find('Geist%-Bold'), 'count: Geist Bold 11')
    -- Short Keybinds: one-letter modifiers with no hyphen.
    assert(M.ShortKey('s-E') == 'sE' and M.ShortKey('SHIFT-E') == 'sE' and M.ShortKey('s-c-1') == 'sc1', 'modifiers shortened')
    assert(M.ShortKey('Mouse Button 4') == 'M4' and M.ShortKey('a-Mouse Button 4') == 'aM4' and M.ShortKey('BUTTON3') == 'M3')
    assert(M.ShortKey('Q') == 'Q' and M.ShortKey('Num Pad 5') == 'N5' and M.ShortKey('Mouse Wheel Up') == 'WU')
    hotkeyTexts.ActionButton5 = 's-E'; ActionButton5:UpdateHotkeys()
    assert(ActionButton5.HotKey.text == 'sE', "Blizzard's keybind text shortened")
    assert(M:SetOption('bar1', 'hotkeyShort', false) and ActionButton5.HotKey.text == 's-E', "off: Blizzard's own text")
    assert(M:SetOption('bar1', 'hotkeyShort', true) and ActionButton5.HotKey.text == 'sE')
    local at = Point(hotkey)
    assert(at[1] == 'TOPRIGHT' and at[4] == -2 and at[5] == -2 and hotkey.justifyV == 'TOP', 'keybind 2px in from the top-right corner')
    ActionButton1:UpdateHotkeys()
    at = Point(hotkey)
    assert(#hotkey.points == 1 and at[4] == -2, 'Blizzard re-placing the keybind is undone')
    hotkey:SetVertexColor(0.6, 0.6, 0.6)
    assert(hotkey.vertexColor[1] == M.db.bar1.hotkeyColor[1], 'keybind color kept')
    -- Out of range (Blizzard's red keybind): a Rosewood keybind and icon.
    hotkey:SetVertexColor(1, 0.125, 0.125)
    assert(hotkey.vertexColor[1] == Tone.rosewood[1] and ActionButton1.icon.vertexColor[1] == Tone.rosewood[1], 'out of range: Rosewood')
    hotkey:SetVertexColor(0.6, 0.6, 0.6)
    assert(hotkey.vertexColor[1] == M.db.bar1.hotkeyColor[1] and ActionButton1.icon.vertexColor[1] == 1, 'in range again: full color')
    -- Blizzard's usable colors become the Mode tints.
    ActionButton1.icon:SetVertexColor(0.5, 0.5, 1)
    assert(ActionButton1.icon.vertexColor[3] == M.POWER_TINT[3] and ActionButton1.icon.vertexColor[1] == M.POWER_TINT[1], 'not enough power: the power tint')
    ActionButton1.icon:SetVertexColor(0.4, 0.4, 0.4)
    assert(ActionButton1.icon.vertexColor[1] == Tone.graphite.muted[1], 'unusable: Graphite muted')
    ActionButton1.icon:SetVertexColor(1, 1, 1)
    assert(ActionButton1.icon.vertexColor[1] == 1)
    assert(ActionButton1.Name.alpha == 0, 'macro names hidden by default')
    local countdown = ActionButton1.cooldown.countdown
    assert(countdown.font[2] == 13 and countdown.color[2] == Tone.cooldown[2], 'cooldown numbers: Geist Bold 13 in the cooldown color')

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
    assert(M:SetOption('bar2', 'perLine', 3) and ModeUIActionBar2.width == 3 * 50 - 4 and ModeUIActionBar2.height == 2 * 44 - 4, 'two rows of three')
    assert(M:SetOption('bar2', 'start', 'BOTTOMRIGHT'))
    p = Point(MultiBarBottomLeftButton4)
    assert(p[1] == 'BOTTOMRIGHT' and p[4] == -3 and p[5] == 3 + 44, 'fourth button starts the second row up from the corner')

    -- Show: Always, Mouseover, Hidden and the rest.
    assert(drivers[bar1].modevis == '[petbattle] hide; show', 'always, except pet battles')
    assert(drivers[ModeUIActionBar6].modevis == 'hide', 'hidden bar')
    assert(drivers[ModeUIPetBar].modevis:find('[nopet] hide; show', 1, true), 'pet bar needs a pet')
    assert(drivers[ModeUIStanceBar].modevis == 'hide', 'no stances, no stance bar')
    testForms = 3; FireEvent('UPDATE_SHAPESHIFT_FORMS')
    assert(drivers[ModeUIStanceBar].modevis:find('show') and ModeUIStanceBar.width == 3 * 50 - 4, 'stance bar fits the stances')
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
    assert(mover1:IsShown() and mover1.width == bar1.width and not mover1.label, 'the box carries no name')
    local handle = element.decoration and element.decoration.handle
    assert(handle and Point(handle)[1] == 'BOTTOM' and Point(handle)[3] == 'TOP', 'the handle sits centered above the bar')
    assert(element.decoration.label.text == 'Action Bar 1' and element.decoration.label.color[2] == 1, 'named in volt green')
    assert(mover1.fill.vertexColor[3] == Kit.palette.accent[3], 'highlighted')
    assert(not M.slots.bar1[1] or not ModeUIActionBar1Mover.slots[1]:IsShown(), 'the real bar shows under its highlight')
    assert(not ModeUIActionBar6Mover:IsShown() and not PM.elements.actionBarsBar6.editMode, 'hidden bars are not movable')
    local targets = {}
    for _, target in ipairs(PM:GetAllowedTargets('actionBarsBar3')) do targets[target.id] = true end
    assert(targets.actionBarsBar1 and targets.actionBarsBar4 and targets.actionBarsBar5 and not targets.actionBarsBar3, 'anchors to any other bar')
    assert(not targets.actionBarsPet and not targets.actionBarsStance, 'but not to the pet and stance bars stacked on it')
    -- Bar 2 hangs from bar 1, so bar 1 can't hang from bar 2 (a loop).
    targets = {}
    for _, target in ipairs(PM:GetAllowedTargets('actionBarsBar1')) do targets[target.id] = true end
    assert(targets.actionBarsBar4 and not targets.actionBarsBar2 and not targets.actionBarsBar3 and not targets.actionBarsBar1, 'never in a loop')
    assert(select(2, PM:SetPosition('actionBarsBar1', { target = 'actionBarsBar3', placement = 'above', x = 0, y = 0 })) == 'anchor-loop')
    assert(PM:SetPosition('actionBarsBar1', { target = 'screen', placement = 'center', point = 'BOTTOM', relativePoint = 'BOTTOM', x = 0, y = 80 }))
    p = Point(bar1)
    assert(p[1] == 'BOTTOMLEFT' and p[2] == UIParent and p[5] == mover1:GetBottom() - UIParent:GetBottom(), 'the bar follows its stand-in')
    -- The mock doesn't chain anchors as the client does; re-anchor bar 2's stand-in.
    PM:ApplyPosition('actionBarsBar2', true); M:SyncAll()
    local before = Point(ModeUIActionBar2)[5]
    assert(before == 80 + 40 + 4, 'bar 2 sits 4px over bar 1')
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
    -- The selected element shows its X and Y from the screen's center.
    addon.EditMode:Select('actionBarsBar1')
    local coords = element.decoration.coords
    assert(coords:IsShown() and Point(coords)[1] == 'RIGHT' and Point(coords)[3] == 'LEFT', 'X and Y left of the name')
    coords.scripts.OnUpdate(coords, 1)
    local sx, sy = UIParent:GetCenter()
    local mx, my = mover1:GetCenter()
    assert(coords.text:GetText() == ('X ' .. math.floor(mx - sx + 0.5) .. '   Y ' .. math.floor(my - sy + 0.5)), 'from the screen center')
    assert(not PM.elements.actionBarsBar2.decoration.coords:IsShown(), 'only on the selected element')
    -- Center Lines (on) and Grid (off) in the Edit Mode window.
    local window, E = addon.editWindow, addon.EditMode
    assert(PM.grid and PM.grid.frame:IsShown() and PM.grid.centerX:IsShown() and PM.grid.centerY:IsShown(), 'center lines by default')
    assert(window.centerLinesButton.selected and not window.gridButton.selected and not (PM.grid.lines[1] and PM.grid.lines[1]:IsShown()))
    window.gridButton.scripts.OnClick(window.gridButton)
    assert(E.grid and window.gridButton.selected and #PM.grid.lines == 2 * (math.floor(640 / 32) + math.floor(400 / 32)), 'Grid draws lines out from the center')
    window.centerLinesButton.scripts.OnClick(window.centerLinesButton)
    assert(not E.centerLines and not PM.grid.centerX:IsShown() and PM.grid.frame:IsShown(), 'Center Lines off, grid still on')
    window.gridButton.scripts.OnClick(window.gridButton)
    assert(not PM.grid.frame:IsShown(), 'both off')
    window.centerLinesButton.scripts.OnClick(window.centerLinesButton)
    assert(PM.grid.frame:IsShown() and PM.grid.centerX:IsShown())
    -- Anchor To: every stand-in keeps the mouse (no dragging), so a click picks
    -- it and never reaches a button under it.
    local A = addon.EditAnchor
    assert(A:Start('actionBarsBar4') and PM.picking)
    assert(mover1:IsMouseEnabled() and not PM:CanDrag(element), 'the bar takes the click, but does not drag')
    assert(element.decoration.handle:IsMouseEnabled(), 'its name handle takes the click too')
    assert(not PM:StartDragging('actionBarsBar1'), 'no dragging while picking')
    A:Stop()
    -- Pointing Action Bar 1 at bar 2 (which sits on it) says why it can't.
    local cursor = GetCursorPosition
    local bx, by = ModeUIActionBar2Mover:GetCenter()
    GetCursorPosition = function() return bx, by end
    assert(A:Start('actionBarsBar1'))
    A:Track()
    assert(not A.overlay.outline:IsShown() and A.overlay.text.text:find('Action Bar 2 already hangs from Action Bar 1', 1, true), 'a loop is explained')
    A.overlay.scripts.OnEvent(A.overlay, 'GLOBAL_MOUSE_DOWN', 'LeftButton')
    assert(A:Active() and PM:GetPosition('actionBarsBar1').target == 'screen', 'and not picked')
    A:Stop()
    -- Action Bar 4 picks Action Bar 1 (listed before or after, either works).
    bx, by = mover1:GetCenter()
    local before4 = PM:GetPosition('actionBarsBar4')
    assert(A:Start('actionBarsBar4')); A:Track()
    assert(A.overlay.outline:IsShown() and A.overlay.text.text:find('to Action Bar 1', 1, true))
    A.overlay.scripts.OnEvent(A.overlay, 'GLOBAL_MOUSE_DOWN', 'LeftButton')
    assert(not A:Active() and PM:GetPosition('actionBarsBar4').target == 'actionBarsBar1', 'anchored to the clicked bar')
    A:CloseSides(); assert(PM:SetPosition('actionBarsBar4', before4))
    GetCursorPosition = cursor
    assert(not PM.picking and mover1:IsMouseEnabled() and PM:CanDrag(element), 'back to dragging')
    -- Stacks stay on the screen: Action Bar 1 at the top edge turns the bars
    -- stacked above it to grow downward, each one under the last.
    local stack = { 'actionBarsBar2', 'actionBarsBar3', 'actionBarsPet', 'actionBarsStance' }
    local kept1 = PM:GetPosition('actionBarsBar1')
    assert(PM:SetPosition('actionBarsBar1', { target = 'screen', placement = 'above', x = 0, y = 0 }))
    for _, id in ipairs(stack) do
        local position = PM:GetPosition(id)
        assert(position.placement == 'below' and position.y == -4, id .. ' flips below, its gap kept')
    end
    local _, top1 = mover1:GetCenter()
    local _, top2 = ModeUIActionBar2Mover:GetCenter()
    local _, top3 = ModeUIActionBar3Mover:GetCenter()
    assert(top2 < top1 and top3 < top2, 'each bar under the last, none piled up')
    assert(PM:SetPosition('actionBarsBar1', { target = 'screen', placement = 'below', x = 0, y = 0 }))
    for _, id in ipairs(stack) do assert(PM:GetPosition(id).placement == 'above' and PM:GetPosition(id).y == 4, id .. ' back above at the bottom') end
    assert(PM:SetPosition('actionBarsBar1', kept1) and PM:GetPosition('actionBarsBar2').placement == 'above', 'a side that fits is kept')
    -- A side with room is kept: Action Bar 5 stays Left of Action Bar 4.
    assert(PM:GetPosition('actionBarsBar5').placement == 'left')
    -- Blizzard's counts and keybinds can be secret; the preview copies them as they are.
    ActionButton3.Count:SetText(Secret('charges')); ActionButton4.HotKey:SetText(Secret('key'))
    addon.EditMode:Select('actionBarsPet')
    addon.editWindow.settingsButton.scripts.OnClick(addon.editWindow.settingsButton)
    local page = addon.configWindow.pages.actionBars
    assert(not addon.editMode and page and page:IsShown() and page.barEditing() == 'pet', 'Open Module Settings opens the selected bar')

    -- Settings page and preview: the player's own bar.
    local sections = {}
    for _, section in ipairs(page.sections) do sections[#sections + 1] = section.title end
    assert(table.concat(sections, ',') == 'Bar,Buttons,Text,Glows,Visibility,Copy & Apply', 'six tabs')
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
    assert(first:IsShown() and first.width == 40 and first.height == 34 and M.art[first].edge.preset == 'frame', 'preview of the edited bar, in its edge')
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
    -- (Mode Glow for these checks; Border is the default.)
    assert(M:SetOption('bar1', 'procGlow', 'mode'))
    preview = M.glows[first]
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
    assert(M.db.bar1.readyStyle == 'border' and preview.proc:IsShown() and M.art[first].edge.tint == M.db.bar1.procColor and not preview.ready:IsShown(), 'two borders: the proc rim wins')
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

    -- Proc glows: Border by default (the edge's rim in Celadon), with Blizzard's alert faded.
    assert(M:SetOption('bar1', 'procGlow', 'border'))
    ActionButtonSpellAlertManager:ShowAlert(ActionButton2)
    local proc, edge2 = M.glows[ActionButton2].proc, M.art[ActionButton2].edge
    assert(proc:IsShown() and not proc.soft:IsShown() and not proc.edges[1]:IsShown() and edge2.tint == M.db.bar1.procColor, 'the Celadon rim')
    assert(ActionButton2.SpellActivationAlert:GetAlpha() == 0, "Blizzard's alert faded")
    assert(M:SetOption('bar1', 'procGlow', 'mode') and proc.soft:IsShown() and edge2.tint == nil, 'Mode Glow: a soft glow, the metal rim')
    assert(M:SetOption('bar1', 'procGlow', 'border') and M:SetOption('bar1', 'procColor', { 0, 1, 0 }) and edge2.tint[2] == 1, 'proc color')
    assert(M:SetOption('bar1', 'edgeStyle', 'thin') and edge2.styleId == 'thin' and edge2.tint[2] == 1 and M:SetOption('bar1', 'edgeStyle', 'blizz'), 'a proc rim survives a style change')
    assert(M:SetOption('bar1', 'procGlow', 'blizzard') and not proc:IsShown() and ActionButton2.SpellActivationAlert:GetAlpha() == 1, 'Blizzard style')
    assert(M:SetOption('bar1', 'procGlow', 'none') and not proc:IsShown() and ActionButton2.SpellActivationAlert:GetAlpha() == 0, 'None')
    assert(M:SetOption('bar1', 'procGlow', 'mode') and proc:IsShown())
    ActionButtonSpellAlertManager:HideAlert(ActionButton2)
    assert(not proc:IsShown() and edge2.tint == nil, 'the glow ends with the proc')
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
    assert(ready and ready:IsShown() and ready.soft.vertexColor[3] == Tone.ivory[3], 'Ivory ready glow when the cooldown ends')
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

    -- Copy & Apply, its own tab: tick bars, then apply this bar's look to them.
    local copyTab
    for _, section in ipairs(page.sections) do if section.title == 'Copy & Apply' then copyTab = section end end
    assert(copyTab and page.sections[#page.sections] == copyTab, 'Copy & Apply is the last tab')
    local pick = page.applyTargetSelect
    -- Clicks the pick list's row for a bar; the menu stays open.
    local function Pick(bar)
        if not pick.menu:IsShown() then pick.scripts.OnClick(pick) end
        for _, row in ipairs(pick.rows) do
            if row:IsShown() and row.choice.id == bar then
                if row.choice.disabled then return 'disabled' end
                row.scripts.OnClick(row); return true
            end
        end
    end
    for _, row in ipairs(page.rows) do
        if row.settingsGroupTitle == 'Apply To' or row.settingsGroupTitle == 'Copy From' or row.settingsGroupTitle == 'Reset' then
            assert(row.section == copyTab, 'copy, apply and reset sit on the Copy & Apply tab')
        end
        assert(row.settingsGroupTitle ~= 'Apply Style' and row.settingsGroupTitle ~= 'This Bar', 'the Bar tab no longer holds them')
    end
    assert(page.applySource.label.text == 'Action Bar 1', 'Copy From shows the bar in Editing')
    assert(M:SetOption('bar1', 'backgroundOpacity', 35))
    assert(pick.label.text == 'Choose bars', 'nothing picked yet')
    assert(Pick('bar3') and Pick('bar5') and Pick('bar1') == 'disabled', 'the source cannot be picked')
    assert(pick.menu:IsShown(), 'the pick list stays open for more picks')
    local marks = {}
    for _, row in ipairs(pick.rows) do if row:IsShown() then marks[row.choice.id] = row.checkMark:IsShown() end end
    assert(marks.bar3 and marks.bar5 and not marks.bar4 and not marks.bar1, 'picked bars show a check')
    assert(pick.label.text == '2 bars selected', 'the field counts the picks')
    pick.menu:Hide()
    assert(page.applyTargets.bar3 and page.applyTargets.bar5 and not page.applyTargets.bar1, 'the edited bar is skipped')
    page.applyButton.scripts.OnClick(page.applyButton)
    assert(M.db.bar3.backgroundOpacity == 35 and M.db.bar5.backgroundOpacity == 35 and M.db.bar4.backgroundOpacity == 100, 'applied to the ticked bars only')
    assert(M.db.bar5.orientation == 'vertical' and page.applyResult.text == 'Applied to 2 bars.', 'shape kept; result shown')
    assert(M.db.bar3.paging == false and M.db.bar3.pageConditions:find('mod:shift', 1, true), 'paging stays per bar')
    Pick('bar3'); assert(pick.label.text == 'Action Bar 5', 'one pick shows its name'); Pick('bar5'); pick.menu:Hide()
    page.applyButton.scripts.OnClick(page.applyButton)
    assert(page.applyResult.text == 'Choose bars first.', 'nothing ticked')
    page.applyAllButton.scripts.OnClick(page.applyAllButton)
    assert(M.db.bar4.backgroundOpacity == 35 and M.db.pet.backgroundOpacity == 35 and page.applyResult.text == 'Applied to 11 bars.', 'Apply to All Bars')
    for _, bar in ipairs(M.bars) do assert(M:SetOption(bar, 'backgroundOpacity', 100)) end

    -- Opacity drags set alpha only: no rebuild of the bars or the page per step.
    local applies, apply = 0, M.Apply
    M.Apply = function(...) applies = applies + 1; return apply(...) end
    assert(M:SetOption('bar1', 'opacity', 55) and M.db.bar1.opacity == 55 and applies == 0, 'opacity skips the rebuild')
    assert(math.abs(M.headers.bar1:GetAlpha() - 0.55) < 0.001 and math.abs(M.previewView.bar:GetAlpha() - 0.55) < 0.001, 'bar and preview fade at once')
    assert(not M:SetOption('bar1', 'opacity', 5) and not M:SetOption('bar1', 'opacity', 52.5) and not M:SetOption('bar1', 'fadeOpacity', 'x'), 'out-of-range opacity refused')
    assert(M:SetOption('bar1', 'fadeOpacity', 20) and applies == 0 and M.db.bar1.fadeOpacity == 20)
    M.Apply = apply
    assert(M:SetOption('bar1', 'opacity', 100) and M:SetOption('bar1', 'fadeOpacity', 0))

    -- On Cooldown sits on the Buttons tab: a line about cooldowns, then the choices.
    local pills = page.cooldownColorPills
    local cooldownRow
    for _, row in ipairs(page.rows) do if row.settingsGroupTitle == 'On Cooldown' then cooldownRow = row end end
    assert(cooldownRow and cooldownRow.section.title == 'Buttons', 'On Cooldown is on the Buttons tab')
    pills[2].scripts.OnClick(pills[2])
    assert(M.db.bar1.cooldownDesaturate == false, 'Full Color keeps the icon as it is')
    pills[1].scripts.OnClick(pills[1])
    assert(M.db.bar1.cooldownDesaturate == true, 'Desaturate turns it gray')
    -- Border Style and Border Metal sit in Border on the Buttons tab, while the border shows.
    local borderGroup, pickerRow
    for _, row in ipairs(page.rows) do
        if row.settingsGroupTitle == 'Border' and row.section.title == 'Buttons' then borderGroup = row
        elseif borderGroup and not pickerRow and row.card == borderGroup.card and row.visibleWhen then pickerRow = row end
    end
    assert(page.borderStylePicker and page.borderMetalPicker and pickerRow and pickerRow.visibleWhen(), 'Border Style and Border Metal in Border')
    assert(M:SetOption('bar1', 'border', 'none') and not pickerRow.visibleWhen() and M:SetOption('bar1', 'border', 'mode') and pickerRow.visibleWhen(), 'hidden with Border None')

    -- Copy and reset.
    assert(M:SetOption('bar1', 'border', 'none') and M:SetOption('bar1', 'edgeStyle', 'round') and M:CopyStyleToAll('bar1'))
    assert(M.db.bar5.edgeStyle == 'round', 'Border Style copies with the look')
    assert(M.db.bar5.border == 'none' and M.db.bar5.width == 30 and M.db.bar5.orientation == 'vertical' and M.db.pet.buttons == 10, 'look copied, shape kept')
    assert(M:ResetBar('bar5') and M.db.bar5.width == 40 and M.db.bar5.border == 'mode' and M.db.bar5.edgeStyle == 'blizz')

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
    assert(M.enabled and M.db.bar1.width == 30 and M.db.bar2.buttons == 6 and M.db.bar3.border == 'none', 'settings persist')
    assert(addon.PositionManager:GetPosition('actionBarsBar1').y == 81, 'position persists')
    assert(ActionButton1:GetParent() == ModeUIActionBar1 and ActionButton1.width == 30)
    assert(M.db.bar1.edgeStyle == 'round' and M.db.bar3.edgeStyle == 'round' and M.art[ActionButton1].edge.styleId == 'round', 'Border Style persists')
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
    local Tone = addon.Style.Tone
    assert(M.db.bar1.macroColor[3] == M.MACRO_COLOR[3] and M.db.bar1.spacing == 4, 'version 2 defaults move, then the Mode 4px')
    assert(M.db.bar1.borderSize == nil and M.db.bar1.borderColor == nil, 'Border Size and Color retire')
    assert(addon.Style.SameColor(M.db.bar1.backgroundColor, Tone.mono.panel), 'the old background takes Mono panel')
    assert(M.db.bar2.spacing == 6, 'chosen spacing stays')
    assert(M.db.version == 6 and M.db.bar1.height == 34 and M.db.bar1.width == 30 and M.db.bar5.height == 40, 'default size moves; a chosen one stays')
    assert(M.db.bar1.cooldownColor[2] == M.COOLDOWN_COLOR[2] and M.db.bar1.backgroundOpacity == 100 and M.db.bar3.backgroundOpacity == 100, '75% (version 4) becomes the full face')
    assert(M.db.bar1.hotkeySize == 10 and M.db.bar1.cooldownDesaturate and M.db.bar1.hotkeyShort, 'keybinds 2px smaller (version 5), then Geist 10')
    assert(M.db.bar3.visibility == 'mouseover' and M.db.bar3.fade == nil and M.db.bar4.visibility == 'combat', 'fading becomes Mouseover')
    assert(PM:GetPosition('actionBarsBar2').target == 'actionBarsBar1', 'a default place stacks on bar 1')
    assert(PM:GetPosition('actionBarsBar3').target == 'screen' and PM:GetPosition('actionBarsBar3').x == 30, 'a moved bar stays put')
]==], "migrate v1")

-- Version 5 -> 6: values at version 5's defaults take the Mode ones; picked values stay.
local v5 = restored.saved()
local ab = v5.profiles.Default.modules.actionBars
ab.version = 5
ab.bar1.width, ab.bar1.height, ab.bar1.spacing, ab.bar1.border, ab.bar1.borderSize, ab.bar1.borderColor = 42, 36, 1, 'rounded', 2, { 16 / 255, 16 / 255, 16 / 255 }
ab.bar1.backgroundColor, ab.bar1.backgroundOpacity, ab.bar1.fontMedia, ab.bar1.outline = { 4 / 255, 4 / 255, 4 / 255 }, 75, 'Expressway', true
ab.bar1.procGlow, ab.bar1.procColor, ab.bar1.readyColor = 'mode', { 1, 210 / 255, 90 / 255 }, { 0.1, 0.8, 0.8 }
ab.bar1.hotkeySize, ab.bar1.countSize, ab.bar1.cooldownSize = 9, 12, 14
ab.bar2.width, ab.bar2.border, ab.bar2.procGlow, ab.bar2.backgroundOpacity, ab.bar2.hotkeySize = 50, 'none', 'blizzard', 40, 12
ab.micro.width, ab.micro.height = 32, 36
H.Load({ before = STUBS, saved = v5 }).run([==[
    local M, Tone, Same = addon.ActionBars, addon.Style.Tone, addon.Style.SameColor
    local a, b = M.db.bar1, M.db.bar2
    assert(M.db.version == 6 and a.width == 40 and a.height == 34 and a.spacing == 4 and a.border == 'mode' and a.borderSize == nil and a.borderColor == nil, 'v5 -> v6 shape and edge')
    assert(Same(a.backgroundColor, Tone.mono.panel) and a.backgroundOpacity == 100 and a.fontMedia == 'Mode' and a.outline == false, 'face and font')
    assert(a.procGlow == 'border' and Same(a.procColor, Tone.celadon) and a.readyColor[1] == 0.1, 'Celadon rim; a picked ready color stays')
    assert(a.hotkeySize == 10 and a.countSize == 11 and a.cooldownSize == 13, 'text sizes')
    assert(b.width == 50 and b.border == 'none' and b.procGlow == 'blizzard' and b.backgroundOpacity == 40 and b.hotkeySize == 12, 'picked values stay')
    assert(M.db.micro.width == 32 and M.db.micro.height == 36, 'the micro menu keeps its size (not an action button)')
]==], "migrate v5")

-- A saved version 6 profile from before Border Style and Border Metal takes
-- their defaults; nothing else changes.
local noEdge = restored.saved()
for _, style in pairs(noEdge.profiles.Default.modules.actionBars) do
    if type(style) == "table" then style.edgeStyle, style.edgeMetal = nil, nil end
end
H.Load({ before = STUBS, saved = noEdge }).run([==[
    local M = addon.ActionBars
    assert(M.db.version == 6 and M.db.bar1.width == 30 and M.db.bar3.border == 'none', 'nothing reset')
    for _, bar in ipairs(M.bars) do assert(M.db[bar].edgeStyle == 'blizz' and M.db[bar].edgeMetal == 'default', bar .. ' takes the default border') end
    assert(M.art[ActionButton1].edge.styleId == 'blizz')
]==], "fill border style")
local badEdge = restored.saved()
badEdge.profiles.Default.modules.actionBars.bar2.edgeStyle = "nope"
assert(not pcall(H.Load, { before = STUBS, saved = badEdge }), "an unknown saved Border Style is refused")

-- Bad saved data stops startup rather than being reset.
local saved = restored.saved()
saved.profiles.Default.modules.actionBars.bar1.width = "wide"
local ok = pcall(H.Load, { before = STUBS, saved = saved })
assert(not ok, "invalid action bar settings are refused")

-- The Mode-Default layout (Layouts.lua): a centered 2 x 2 grid on the bottom
-- edge, pet and stance bars on it, the micro menu top left; the same at 1080
-- and 1440.
H.Load({ before = STUBS }).run([==[
    local M = addon.ActionBars
    for _, variant in ipairs({ '1080', '1440' }) do
        local profile = assert(addon.Layouts:Build('mode-default', variant))
        local db, pos, id = profile.modules.actionBars, profile.positions, M.elementIds
        assert(db.enabled == true)
        for _, bar in ipairs({ 'bar1', 'bar2', 'bar3', 'bar4' }) do
            local s = db[bar]
            assert(s.show and s.width == 28 and s.height == 24 and s.spacing == 2 and s.buttons == 12 and s.perLine == 12
                and s.orientation == 'horizontal' and s.start == 'TOPLEFT' and s.edgeStyle == 'blizz', bar)
            local g = M.Geometry(s, 12, 1)
            assert(g.width == 430 and g.height == 30, bar .. ' is 430 x 30')
        end
        assert(not db.bar5.show and not db.bar6.show and not db.bar7.show and not db.bar8.show)
        for _, bar in ipairs({ 'pet', 'stance' }) do
            local s = db[bar]
            assert(s.show and s.width == 30 and s.height == 24 and s.spacing == 2 and s.perLine == 10 and s.buttons == 10, bar)
        end
        assert(db.pet.start == 'TOPLEFT' and db.stance.start == 'TOPRIGHT')
        local pet = M.Geometry(db.pet, 10, 1)
        assert(pet.width == 378 and pet.height == 30)
        -- The micro menu in one row of 16 and the bag bar, 28 x 22, on Mouseover (owner's tuning, November 18, 2026).
        local micro, bags = db.micro, db.bags
        assert(micro.perLine == 16 and micro.width == 28 and micro.height == 22 and micro.spacing == 4 and micro.start == 'TOPLEFT')
        assert(micro.visibility == 'mouseover' and bags.visibility == 'mouseover' and bags.width == 28 and bags.height == 22)
        local g = M.Geometry(micro, 16, 1)
        assert(g.width == 16 * 34 + 15 * 4 and g.height == 28 and g.points[16][3] == g.points[1][3], 'one row of 16')
        local function Is(element, target, point, rel, x, y)
            local p = pos[element]
            assert(p and p.target == target and p.point == point and p.relativePoint == rel and p.x == x and p.y == y, element)
        end
        Is(id.bar1, 'screen', 'BOTTOMRIGHT', 'BOTTOM', -4, 8)
        Is(id.bar2, id.bar1, 'LEFT', 'RIGHT', 8, 0)
        Is(id.bar3, id.bar1, 'BOTTOM', 'TOP', 0, 4)
        Is(id.bar4, id.bar2, 'BOTTOM', 'TOP', 0, 4)
        Is(id.pet, id.bar3, 'BOTTOMLEFT', 'TOPLEFT', 0, 4)
        Is(id.stance, id.bar4, 'BOTTOMRIGHT', 'TOPRIGHT', 0, 4)
        Is(id.micro, 'screen', 'TOPLEFT', 'TOPLEFT', 8, -8)
        Is(id.bags, id.micro, 'TOPLEFT', 'TOPRIGHT', 8, 0)
    end
]==], "mode-default layout")

print("action bars: all checks passed")
