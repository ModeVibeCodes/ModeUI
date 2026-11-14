-- Cooldown Manager: a standalone module with its own window (/mcdm), hooking
-- Blizzard's viewers, Growth and New Lines, the icon and bar skins, the
-- swipe and gray kept after Blizzard's refresh, texts, proc, active, off
-- cooldown and buff glows, per-spell switches, custom bars (adding through
-- the + slot's list, order, moving, deleting), visibility, Edit Mode and its
-- way back to the window, copy and reset, switching off, late loading, the
-- version 1 migration, persistence and the no-writes rule on Blizzard's
-- frames. Simulated client; not WoW rendering, security or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/cooldown_manager_stubs.lua")

local world = H.Load({ before = STUBS .. "\nMakeViewers()" })
world.run([==[
    local M, PM, Kit = addon.CooldownManager, addon.PositionManager, addon.Kit
    local essential, utility, buffs, bars = EssentialCooldownViewer, UtilityCooldownViewer, BuffIconCooldownViewer, BuffBarCooldownViewer
    assert(M and not M.enabled and not M.built and M.standalone and M.category == nil, 'standalone, off by default')
    local first = ItemsOf(essential)[1]
    assert(first.Icon.mask ~= nil and Point(first)[2] == essential, "Blizzard's icons untouched while off")
    assert(M.db.version == 3 and M.db.essential.border == 'mode' and #M.db.customBars == 0 and M.db.essential.grow == 'centerH' and M.db.buffIcon.lineGrowth == 'up')
    assert(M.db.essential.desaturate and M.db.essential.procGlow == 'mode' and M.db.essential.activeGlow == 'none', 'gray on cooldown by default')

    addon:SetModuleEnabled('cooldownManager', true)
    assert(M.built and ModeUICooldownEssential and ModeUICooldownBuffBar, 'a stand-in per viewer')
    assert(PM:GetPosition('cooldownManagerUtility').target == 'cooldownManagerEssential', 'Utility sits under Essential')
    local holder = M.holders.essential
    local items = ItemsOf(essential)
    -- One line of 12 slots (42x36, 2px apart); five icons centered in it.
    assert(ModeUICooldownEssential.width == 12 * 42 + 11 * 2 and ModeUICooldownEssential.height == 36, 'stand-in is one full line')
    local p = Point(items[1])
    assert(p[1] == 'TOPLEFT' and p[2] == holder and p[4] == 154 and p[5] == 0, 'centered: seven empty slots split either side')
    assert(Point(items[2])[4] == 198 and items[1].width == 42 and items[1].scale == 1)

    -- Skin.
    local icon = items[1].Icon
    assert(icon.mask == nil and items[1].overlay.alpha == 0, 'round mask removed, frame art faded')
    -- The ModeUI border: a 2px rim with round corners above the icon, which
    -- starts at its inner edge; the slot's own edges hide.
    local dress = M.dress[items[1]]
    local rim = dress.modeBorder
    assert(rim and rim.edge:IsShown() and rim.strips.TOP.vertexColor[1] == Kit.BORDER_COLOR[1] and rim.radius == 4, 'ModeUI border')
    assert(rim.edge.frameLevel > items[1]:GetFrameLevel() and not dress.art.edges[1]:IsShown(), 'rim above the icon; no slot edges')
    assert(dress.art.fill.vertexColor[4] == 0.75 and dress.art.fill.points[1][4] == 2 and icon.points[1][4] == 2, 'background and icon inside the rim')
    assert(items[1].Cooldown.points[1][4] == 2, 'swipe inside the rim')
    -- Out of range: Blizzard's shade stays faded (no red block); its red tint on the icon stays.
    assert(items[1].OutOfRange.alpha == 0 and items[1].OutOfRange.atlas == 'UI-CooldownManager-OORshadow', "Blizzard's shade faded, not repainted")
    items[1].spellOutOfRange = true; items[1]:RefreshIconColor()
    assert(items[1].OutOfRange.alpha == 0 and items[1].Icon.vertexColor[2] == 0.15, 'out of range: the red tint only')
    assert(M:SetOption('essential', 'rangeTint', false)); items[1]:RefreshIconColor()
    assert(items[1].Icon.vertexColor[2] == 1, 'Out of Range Tint off: full color')
    assert(M:SetOption('essential', 'rangeTint', true)); items[1].spellOutOfRange = nil; items[1]:RefreshIconColor()
    -- Rounded keeps the slot's own rim.
    assert(M:SetOption('essential', 'border', 'rounded') and dress.art.edges[1]:IsShown() and not rim.edge:IsShown() and icon.points[1][4] == 3)
    assert(M:SetOption('essential', 'border', 'mode'))
    items[1]:RefreshSpellCooldownInfo()
    assert(items[1].Cooldown.drawEdge == false and items[1].Cooldown.swipeColor[4] == 0.7, 'edge off, 70% swipe after the refresh')
    local count = items[1].ChargeCount.Current
    assert(count.font[2] == 12 and Point(count)[1] == 'BOTTOMRIGHT' and Point(count)[4] == -3, 'count in the corner')

    -- Growth and New Lines.
    local function At(item) local q = Point(item); return q[4], q[5] end
    assert(M:SetOption('essential', 'grow', 'right')); local x = At(items[2]); assert(x == 44, 'Horizontal Right')
    assert(M:SetOption('essential', 'grow', 'left')); x = At(items[1]); assert(x == 526 - 42 and At(items[2]) == 440, 'Horizontal Left')
    assert(M:SetOption('essential', 'grow', 'down') and M.db.essential.lineGrowth == 'right', 'columns: New Lines turns Right')
    assert(ModeUICooldownEssential.width == 42 and ModeUICooldownEssential.height == 12 * 36 + 11 * 2)
    local _, y = At(items[2]); assert(y == -38, 'Vertical Down')
    assert(M:SetOption('essential', 'grow', 'up')); _, y = At(items[1]); assert(y == -(454 - 36), 'Vertical Up')
    assert(M:SetOption('essential', 'grow', 'centerV')); _, y = At(items[1]); assert(y == -133, 'Centered Vertical')
    assert(not M:SetOption('essential', 'lineGrowth', 'up'), 'columns add lines right or left')
    assert(M:SetOption('essential', 'grow', 'down') and M:SetOption('essential', 'perLine', 3))
    x, y = At(items[4]); assert(x == 44 and y == 0, 'second column to the right')
    assert(M:SetOption('essential', 'lineGrowth', 'left')); x = At(items[4]); assert(x == -44, 'New Lines: Left')
    assert(M:SetOption('essential', 'grow', 'centerH') and M.db.essential.lineGrowth == 'down')
    x, y = At(items[4]); assert(x == 22 and y == -38, 'short second line centered under the first')
    assert(M:SetOption('essential', 'lineGrowth', 'up')); _, y = At(items[4]); assert(y == 38, 'New Lines: Up')
    assert(M:SetOption('essential', 'lineGrowth', 'down') and M:SetOption('essential', 'perLine', 12))
    essential:RefreshLayout(); items = ItemsOf(essential)
    assert(Point(items[2])[2] == holder and Point(items[2])[4] == 198, "Blizzard's grid undone after its layout")

    -- Desaturate on Cooldown: gray on a real cooldown, kept after Blizzard's refresh.
    cooling[5001] = true; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(items[1].Icon.desaturated == true and items[2].Icon.desaturated == false, 'gray while cooling')
    items[1]:RefreshIconDesaturation()
    assert(items[1].Icon.desaturated == true, "kept after Blizzard's own gray")
    items[1].cooldownSwipeColor = CooldownViewerConstants.ITEM_AURA_COLOR; items[1]:RefreshSpellCooldownInfo()
    assert(items[1].Icon.desaturated == false, 'full color while its effect is up')
    items[1].cooldownSwipeColor = CooldownViewerConstants.ITEM_COOLDOWN_COLOR; items[1]:RefreshSpellCooldownInfo()
    assert(M:SetOption('essential', 'desaturate', false) and items[1].Icon.desaturated == false, 'off: full color')
    assert(M:SetOption('essential', 'desaturate', true) and items[1].Icon.desaturated == true)
    cooling[5001] = false; FireEvent('SPELL_UPDATE_COOLDOWN'); assert(items[1].Icon.desaturated == false, 'color back when ready')

    -- Glows: proc over active; active from the gold swipe; per spell off.
    assert(M:SetOption('essential', 'activeGlow', 'border'))
    items[2].cooldownSwipeColor = CooldownViewerConstants.ITEM_AURA_COLOR; items[2]:RefreshSpellCooldownInfo()
    local set = M.glows[items[2]]
    assert(set.active and set.active:IsShown(), 'active glow while the effect is up')
    ActionButtonSpellAlertManager:ShowAlert(items[2])
    assert(set.proc:IsShown() and not set.active:IsShown() and items[2].SpellActivationAlert.alpha == 0, 'proc wins; Blizzard alert faded')
    ActionButtonSpellAlertManager:HideAlert(items[2]); assert(set.active:IsShown() and not set.proc:IsShown())
    assert(M:SetSpellSwitch('essential', '102', 'active', false) and not set.active:IsShown(), 'active glow off for this spell')
    assert(M:SetSpellSwitch('essential', '102', 'active', true) and set.active:IsShown())
    items[2].cooldownSwipeColor = CooldownViewerConstants.ITEM_COOLDOWN_COLOR; items[2]:RefreshSpellCooldownInfo()
    assert(not set.active:IsShown(), 'ends with the effect')
    assert(M:SetOption('essential', 'procGlow', 'blizzard')); ActionButtonSpellAlertManager:ShowAlert(items[1])
    assert(items[1].SpellActivationAlert.alpha == 1, 'Blizzard style'); ActionButtonSpellAlertManager:HideAlert(items[1])
    assert(M:SetOption('essential', 'procGlow', 'mode'))
    -- Off cooldown: While Ready, then a flash for Glow Time.
    assert(M:SetOption('essential', 'readyGlow', 'mode') and M:SetOption('essential', 'readyMode', 'always'))
    assert(M.glows[items[3]].ready:IsShown(), 'lit while ready')
    cooling[5003] = true; FireEvent('SPELL_UPDATE_COOLDOWN'); assert(not M.glows[items[3]].ready:IsShown(), 'not while cooling')
    assert(M:SetOption('essential', 'readyMode', 'flash'))
    local after, timers = C_Timer.After, {}
    C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
    cooling[5003] = false; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(M.glows[items[3]].ready:IsShown(), 'flash when the cooldown ends')
    for _, fn in ipairs(timers) do fn() end
    C_Timer.After = after
    assert(not M.glows[items[3]].ready:IsShown(), 'gone after Glow Time')
    assert(M:SetOption('essential', 'readyGlow', 'none'))
    -- Buff glow: follows the buff's active state, secret or not.
    local buffItems = ItemsOf(buffs)
    assert(M:SetOption('buffIcon', 'buffGlow', 'mode'))
    buffItems[1]:SetIsActive(true)
    local buffGlow = M.glows[buffItems[1]].buff
    assert(buffGlow:IsShown() and buffGlow.soft.alpha == 1, 'buff glow while up')
    buffItems[1]:SetIsActive(false); assert(buffGlow.soft.alpha == 0, 'faded while down')
    buffItems[1]:SetIsActive(Secret('active'))
    assert(issecretvalue(buffGlow.soft.alphaFromBoolean) and issecretvalue(buffGlow.edges[1].alphaFromBoolean), 'secret state passed to SetAlphaFromBoolean')
    assert(M:SetSpellSwitch('buffIcon', '301', 'buff', false) and not buffGlow:IsShown(), 'buff glow off for this buff')
    assert(M:SetSpellSwitch('buffIcon', '301', 'buff', true) and M:SetOption('buffIcon', 'buffGlow', 'none') and not buffGlow:IsShown())
    buffItems[1]:SetIsActive(true)

    -- Tracked Buffs close gaps; a secret shown state keeps its place.
    buffItems[1].activeState = false; buffItems[1]:UpdateShownState()
    assert(M.placedCount.buffIcon == 1 and Point(buffItems[2])[4] == 204, 'the active buff takes the middle')
    buffItems[1].secretShown = true; buffItems[1]:UpdateShownState()
    assert(M.placedCount.buffIcon == 2, 'a secret shown state keeps its place')
    buffItems[1].secretShown = nil; buffItems[1].activeState = true; buffItems[1]:UpdateShownState()

    -- Tracked Bars.
    local bar = ItemsOf(bars)[1]
    assert(bar.width == 220 and bar.Icon.width == 22 and Point(M.dress[bar].box)[4] == 24, 'icon square, bar box beside it')
    assert(bar.Bar.statusBarTexture == Kit.FLAT and bar.Bar.BarBG.alpha == 0, 'Mode Gradient')
    assert(M.dress[bar].iconBorder.modeBorder.edge:IsShown() and M.dress[bar].boxBorder.modeBorder.edge:IsShown(), 'ModeUI border on the icon and the bar')
    assert(not M.dress[bar].rim[1]:IsShown() and Point(bar.Bar)[4] == 2, 'no slot rim; the bar inside the ModeUI rim')
    assert(Point(ItemsOf(bars)[2])[5] == 24, 'Tracked Bars add lines upward')

    -- Custom bars: Blizzard's own icons move onto them.
    local c1 = M:AddCustomBar('cooldown')
    assert(c1 == 'custom1' and M:Custom(c1).name == 'Cooldown Bar 1' and ModeUICooldownCustom1 and M.db.custom1.perLine == 8, 'a new Cooldown Bar')
    assert(PM:GetPosition('cooldownManagerCustom1').target == 'screen', 'placed in Edit Mode like the viewers')
    local byKey = {}
    for _, viewer in ipairs({ essential, utility, buffs }) do for _, item in ipairs(ItemsOf(viewer)) do byKey[item:GetCooldownID()] = item end end
    assert(M:AddEntry(c1, '102') and M:AddEntry(c1, '201'))
    assert(Point(byKey[102])[2] == M.holders.custom1 and Point(byKey[201])[2] == M.holders.custom1, 'icons move onto the custom bar')
    assert(M.placedCount.essential == 4 and M.placedCount.utility == 1, 'their viewers close up')
    assert(Point(byKey[102])[4] == 132 and Point(byKey[201])[4] == 176, 'in the order added, centered')
    assert(M:MoveEntry(c1, '201', -1) and Point(byKey[201])[4] == 132, 'Earlier')
    assert(not M:AddEntry(c1, '301'), 'a Cooldown Bar takes no buffs')
    local c2 = M:AddCustomBar('buff')
    assert(c2 == 'custom2' and M:Custom(c2).name == 'Buff Bar 1' and M:AddEntry(c2, '301') and not M:AddEntry(c2, '101'))
    assert(Point(byKey[301])[2] == M.holders.custom2, 'a buff on a Buff Bar')
    local c3 = M:AddCustomBar('cooldown')
    assert(M:Custom(c3).name == 'Cooldown Bar 2' and M:AddEntry(c3, '102'))
    assert(#M:Custom(c1).entries == 1 and Point(byKey[102])[2] == M.holders.custom3, 'a spell moves between custom bars')
    assert(M:SetSpellSwitch(c3, '102', 'hide', true) and byKey[102].alpha == 0, 'hidden on its custom bar')
    assert(M:RenameCustomBar(c3, '  Burst ') and M:Label(c3) == 'Burst' and not M:RenameCustomBar(c3, ''))
    assert(PM:Element('cooldownManagerCustom3').label == 'Burst', 'Edit Mode handle renamed')
    assert(M:SetOption(c3, 'activeGlow', 'mode') and M.db.custom3.activeGlow == 'mode', 'custom bars have every setting')
    assert(M:RemoveEntry(c1, '201') and Point(byKey[201])[2] == M.holders.utility, 'Remove from Bar sends it back')
    assert(M:DeleteCustomBar(c3) and Point(byKey[102])[2] == holder and byKey[102].alpha == 1, 'deleting gives the spells back')
    assert(addon.db.positions.cooldownManagerCustom3 == nil and not ModeUICooldownCustom3:IsShown() and M.db.custom3 == nil)

    -- Custom spells by ID: ModeUI's own icon on a Cooldown Bar.
    assert(not M:AddCustomSpell(c1, 'abc') and not M:AddCustomSpell(c1, '950000'), 'not a spell ID; no such spell')
    local ok, sid = M:AddCustomSpell(c1, ' 9001 ')
    assert(ok and sid == 9001 and M:Custom(c1).entries[1] == 's9001', 'added as s9001')
    assert(not M:AddCustomSpell(c1, '9001') and not M:AddCustomSpell(c2, '9001'), 'once per bar; not on a Buff Bar')
    local own = M.spellIcons[c1].s9001
    assert(own:IsShown() and Point(own)[2] == M.holders.custom1 and M.placedCount.custom1 == 1, 'its own icon, on the bar')
    assert(own.Icon.texture == 'icon:9001' and M.dress[own].modeBorder.edge:IsShown() and own.Icon.points[1][4] == 2, 'skinned like the rest')
    assert(own.Cooldown.durationObject.duration == 'cd:9001', 'cooldown from its duration object')
    assert(own.Cooldown.countdown.font[2] == 15, 'the cooldown numbers styled')
    cooling[9001] = true; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(own.Icon.desaturated == true, 'gray while cooling')
    assert(M:SetOption(c1, 'readyGlow', 'mode') and M:SetOption(c1, 'readyMode', 'always') and not (M.glows[own] and M.glows[own].ready:IsShown()))
    cooling[9001] = false; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(own.Icon.desaturated == false and M.glows[own].ready:IsShown(), 'ready: color and the While Ready glow')
    assert(M:SetOption(c1, 'readyGlow', 'none'))
    spellUsable[9001] = { false, true }; FireEvent('SPELL_UPDATE_USABLE')
    assert(own.Icon.vertexColor[3] == 1 and own.Icon.vertexColor[1] == 0.5, 'short of power: blue tint')
    spellUsable[9001] = nil; FireEvent('SPELL_UPDATE_USABLE'); assert(own.Icon.vertexColor[1] == 1)
    FireEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW', 9001)
    assert(M.glows[own].proc:IsShown(), 'procs light it'); FireEvent('SPELL_ACTIVATION_OVERLAY_GLOW_HIDE', 9001)
    assert(not M.glows[own].proc:IsShown())
    -- Charges: the recharge, and the count (secret) straight to the text.
    spellCharges[9002] = { current = Secret('charges'), max = 2, active = true }
    assert(M:AddCustomSpell(c1, '9002'))
    local charged = M.spellIcons[c1].s9002
    assert(charged.Cooldown.durationObject.duration == 'charge:9002' and issecretvalue(charged.ChargeCount.Current.text), 'recharge and charges')
    assert(Point(charged)[4] > Point(own)[4], 'in the order added')
    -- Unknown spells hide; hidden spells wait unseen; removed ones go.
    knownSpells[9002] = false; FireEvent('SPELLS_CHANGED')
    assert(not charged:IsShown() and M.placedCount.custom1 == 1, 'a spell you do not know is not shown')
    knownSpells[9002] = nil; FireEvent('SPELLS_CHANGED'); assert(charged:IsShown())
    assert(M:SetSpellSwitch(c1, 's9002', 'hide', true) and charged.alpha == 0 and M.placedCount.custom1 == 1)
    assert(M:RemoveEntry(c1, 's9002') and not charged:IsShown() and M.spellIcons[c1].s9002 == nil, 'Remove from Bar')
    own.scripts.OnEnter(own); assert(GameTooltip.spell == 9001, 'its tooltip')

    -- Visibility.
    assert(M:SetOption('utility', 'visibility', 'combat') and ItemsOf(utility)[1].alpha == 0, 'In Combat')
    testCombat = true; FireEvent('PLAYER_REGEN_DISABLED'); assert(ItemsOf(utility)[1].alpha == 1)
    testCombat = false; FireEvent('PLAYER_REGEN_ENABLED')
    assert(M:SetOption('utility', 'visibility', 'always') and utility.alpha == nil, "Blizzard's viewer frame left alone")

    -- The window: /mcdm, the bar list, the + slot's list, Open CDM.
    assert(M.window == nil, 'built on first open')
    SlashCmdList.MODEUICDM()
    local window = ModeUICooldownManagerWindow
    assert(window:IsShown() and window.title.text == 'Cooldown Manager' and window.moduleHeader.toggle:IsShown(), 'own window, own switch')
    assert(window.rows[9]:IsShown() and window.rows[9].label.text == 'Cooldown Bar 1' and window.rows[10].label.text == 'Buff Bar 1', 'custom bars listed')
    window.rows[10].scripts.OnClick(window.rows[10])
    local page, view = M.page, M.previewView
    assert(page.viewerEditing() == c2 and view.icons[1].key == '301' and view.plus:IsShown(), 'a custom bar: its spells, then +')
    view.plus.scripts.OnMouseUp(view.plus, 'LeftButton')
    local picker = M.picker
    assert(picker:IsShown() and picker.buttons[1]:IsShown() and picker.buttons[1].key == '302' and not picker.buttons[2], 'tracked buffs not on it yet')
    picker.buttons[1].scripts.OnClick(picker.buttons[1])
    assert(M:Custom(c2).entries[2] == '302' and picker.empty:IsShown(), 'added; nothing left')
    picker:Hide()
    view.icons[1].scripts.OnMouseUp(view.icons[1], 'LeftButton')
    local menu = M.spellMenu
    assert(menu:IsShown() and menu.remove:IsShown() and not menu.earlier.enabled and menu.glowBoxes.buff:IsShown() and not menu.glowBoxes.proc:IsShown())
    menu.later.scripts.OnClick(menu.later)
    assert(M:Custom(c2).entries[1] == '302', 'Later')
    menu:Hide()
    M:SelectBar(c1)
    view.plus.scripts.OnMouseUp(view.plus, 'LeftButton')
    assert(picker.buttons[7] and picker.buttons[7]:IsShown() and picker.buttons[8] == nil, 'all seven cooldowns from Essential and Utility')
    assert(picker.byId:IsShown(), 'Spell ID on a Cooldown Bar')
    picker.idInput:SetText('9003'); picker.idAdd.scripts.OnClick(picker.idAdd)
    assert(M:Custom(c1).entries[2] == 's9003' and picker.idResult.text == 'Added Spell 9003.' and picker.idInput:GetText() == '', 'added from the list')
    picker.idInput:SetText('950000'); picker.idAdd.scripts.OnClick(picker.idAdd)
    assert(picker.idResult.text == 'No spell has that ID.', 'says why not')
    assert(view.icons[1].key == 's9001' and view.icons[1].Icon.texture == 'icon:9001', 'custom spells in the preview')
    picker:Hide()
    M:SelectBar('essential')
    view.plus.scripts.OnMouseUp(view.plus, 'LeftButton')
    assert(cdmToggles == 1, "a viewer's + opens Blizzard's Cooldown Manager")
    window.cdmButton.scripts.OnClick(window.cdmButton); assert(cdmToggles == 2, 'Open CDM')
    -- Edit Mode steps the window aside and brings it back, not ModeUI's.
    window.editButton.scripts.OnClick(window.editButton)
    assert(addon.editMode and not window:IsShown() and ModeUICooldownCustom1:IsShown(), 'Edit Mode with the custom bar')
    addon:SetEditMode(false)
    assert(window:IsShown() and not ModeUIConfigWindow:IsShown(), 'back to the Cooldown Manager window')
    window:Hide(); M:OpenSettings('cooldownManagerUtility')
    assert(window:IsShown() and M.selectedBar == 'utility' and page.viewerEditing() == 'utility', 'Open Module Settings lands on the bar')

    -- Copy and reset, then the no-writes rule.
    assert(M:SetOption('essential', 'border', 'square') and M:CopyStyleToAll('essential'))
    assert(M.db.custom1.border == 'square' and M.db.buffBar.width == 220, 'look copied to every bar, shape kept')
    assert(M:ResetViewer(c1) and M.db.custom1.border == 'mode')
    assert(#blizzardWrites == 0, 'wrote to Blizzard frames: ' .. table.concat(blizzardWrites, ', '))

    -- Switching off: icons back at full, a reload for the look.
    assert(M:SetSpellSwitch('essential', '105', 'hide', true))
    addon:SetModuleEnabled('cooldownManager', false)
    assert(ItemsOf(essential)[5].alpha == 1 and addon.ReloadManager:IsPending(), 'full icons; reload offered')
    assert(not M.spellIcons.custom1.s9001:IsShown(), "ModeUI's own icons hide while off")
    addon:SetModuleEnabled('cooldownManager', true)
    assert(Point(ItemsOf(essential)[1])[2] == holder and #blizzardWrites == 0)
]==], "cooldown manager")

-- Blizzard's Cooldown Manager loading after ModeUI: hooked when it does.
H.Load({ before = STUBS }).run([==[
    local M = addon.CooldownManager
    addon:SetModuleEnabled('cooldownManager', true)
    assert(M.active and M:GameState() == 'missing' and M:Status():find("isn't loaded", 1, true))
    MakeViewers()
    FireEvent('ADDON_LOADED', 'Blizzard_CooldownViewer')
    local items = ItemsOf(EssentialCooldownViewer)
    assert(Point(items[1])[2] == M.holders.essential and items[1].Icon.mask == nil, 'hooked and skinned once loaded')
]==], "late load")

local restored = H.Load({ before = STUBS .. "\nMakeViewers()", saved = world.saved() })
restored.run([==[
    local M = addon.CooldownManager
    assert(M.enabled and M.db.essential.border == 'square' and #M.db.customBars == 2 and M.db.nextCustom == 4, 'settings persist')
    local buff = ItemsOf(BuffIconCooldownViewer)[2]
    assert(Point(buff)[2] == M.holders.custom2, 'custom bars hold their spells after a reload')
    assert(M.spellIcons.custom1.s9001:IsShown() and M.spellIcons.custom1.s9003, 'custom spells too')
]==], "restore")

-- Version 1: Lines, First Icon and Center Lines; the ready glow switch.
local v1 = restored.saved()
v1.profiles.Default.modules.cooldownManager = { enabled = true, version = 1,
    essential = { orientation = "horizontal", start = "TOPRIGHT", center = false, readyGlow = true, readyStyle = "border" },
    utility = { orientation = "vertical", start = "BOTTOMRIGHT", center = false },
    buffIcon = { orientation = "horizontal", start = "BOTTOMLEFT", center = true, readyGlow = false, readyStyle = "glow" } }
H.Load({ before = STUBS .. "\nMakeViewers()", saved = v1 }).run([==[
    local db = addon.CooldownManager.db
    assert(db.version == 3 and db.essential.border == 'mode' and db.essential.borderColor[1] == addon.Kit.BORDER_COLOR[1], 'v1 also takes the ModeUI border')
    assert(db.essential.grow == 'left' and db.essential.lineGrowth == 'down', 'right-aligned rows grow left')
    assert(db.essential.readyGlow == 'border' and db.essential.readyMode == 'flash' and db.essential.readyStyle == nil, 'ready glow kept as a flash')
    assert(db.essential.orientation == nil and db.essential.desaturate == true and #db.customBars == 0)
    assert(db.utility.grow == 'up' and db.utility.lineGrowth == 'left', 'columns from the bottom right')
    assert(db.buffIcon.grow == 'centerH' and db.buffIcon.lineGrowth == 'up' and db.buffIcon.readyGlow == 'none')
]==], "migrate v1")

-- Version 2: a Rounded border in the old #101010 becomes the ModeUI border;
-- Square stays.
local v2 = restored.saved()
local old = v2.profiles.Default.modules.cooldownManager
old.version = 2
old.essential.border, old.essential.borderColor = "rounded", { 16 / 255, 16 / 255, 16 / 255 }
old.utility.border, old.utility.borderColor = "square", { 1, 0, 0 }
old.custom1.border = "rounded"
H.Load({ before = STUBS .. "\nMakeViewers()", saved = v2 }).run([==[
    local db, Kit = addon.CooldownManager.db, addon.Kit
    assert(db.version == 3 and db.essential.border == 'mode' and db.essential.borderColor[1] == Kit.BORDER_COLOR[1], 'old default to the ModeUI border')
    assert(db.utility.border == 'square' and db.utility.borderColor[1] == 1, 'a chosen Square border and color stay')
    assert(db.custom1.border == 'mode', 'custom bars too')
]==], "migrate v2")

-- Bad saved data stops startup rather than being reset.
local function Refused(change, label)
    local saved = restored.saved()
    change(saved.profiles.Default.modules.cooldownManager)
    assert(not pcall(H.Load, { before = STUBS, saved = saved }), "invalid cooldown manager settings are refused: " .. label)
end
Refused(function(db) db.essential.width = 500 end, "width")
Refused(function(db) db.essential.spells = { abc = { hide = true } } end, "spell key")
Refused(function(db) db.essential.grow = "centerV"; db.essential.lineGrowth = "down" end, "line growth")
Refused(function(db) db.customBars[1].kind = "aura" end, "custom kind")
Refused(function(db) db.customBars[2].id = db.customBars[1].id end, "custom id")
Refused(function(db) db.customBars[1].entries = { "12", "12" } end, "custom entries")
Refused(function(db) db.customBars[2].entries = { "s9001" } end, "a spell by ID on a Buff Bar")
Refused(function(db) db.customBars[1].entries = { "x9001" } end, "a bad spell key")

print("cooldown manager: all checks passed")
