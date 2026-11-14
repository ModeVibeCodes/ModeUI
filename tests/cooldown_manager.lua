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
    assert(M.db.essential.width == 42 and M.db.essential.height == 34 and M.db.utility.width == 36 and M.db.utility.height == 28, 'icons 8px wider than tall')
    assert(M.db.version == 4 and M.db.essential.border == 'mode' and #M.db.customBars == 0 and M.db.essential.grow == 'centerH' and M.db.buffIcon.lineGrowth == 'up')
    assert(M.db.essential.desaturate and not M.db.essential.auraSwipe and next(M.db.essential.spells) == nil, 'gray on cooldown; glows off on every spell')
    assert(M.db.essential.procGlow == 'blizzard' and M.db.essential.readyGlow == 'pixel', 'looks a glow starts with')

    addon:SetModuleEnabled('cooldownManager', true)
    assert(M.built and ModeUICooldownEssential and ModeUICooldownBuffBar, 'a stand-in per viewer')
    assert(PM:GetPosition('cooldownManagerUtility').target == 'cooldownManagerEssential', 'Utility sits under Essential')
    local holder = M.holders.essential
    local items = ItemsOf(essential)
    -- One line of 12 slots (42x36, 2px apart); five icons centered in it.
    assert(ModeUICooldownEssential.width == 12 * 42 + 11 * 2 and ModeUICooldownEssential.height == 34, 'stand-in is one full line')
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
    assert(ModeUICooldownEssential.width == 42 and ModeUICooldownEssential.height == 12 * 34 + 11 * 2)
    local _, y = At(items[2]); assert(y == -36, 'Vertical Down')
    assert(M:SetOption('essential', 'grow', 'up')); _, y = At(items[1]); assert(y == -(430 - 34), 'Vertical Up')
    assert(M:SetOption('essential', 'grow', 'centerV')); _, y = At(items[1]); assert(y == -126, 'Centered Vertical')
    assert(not M:SetOption('essential', 'lineGrowth', 'up'), 'columns add lines right or left')
    assert(M:SetOption('essential', 'grow', 'down') and M:SetOption('essential', 'perLine', 3))
    x, y = At(items[4]); assert(x == 44 and y == 0, 'second column to the right')
    assert(M:SetOption('essential', 'lineGrowth', 'left')); x = At(items[4]); assert(x == -44, 'New Lines: Left')
    assert(M:SetOption('essential', 'grow', 'centerH') and M.db.essential.lineGrowth == 'down')
    x, y = At(items[4]); assert(x == 22 and y == -36, 'short second line centered under the first')
    assert(M:SetOption('essential', 'lineGrowth', 'up')); _, y = At(items[4]); assert(y == 36, 'New Lines: Up')
    assert(M:SetOption('essential', 'lineGrowth', 'down') and M:SetOption('essential', 'perLine', 12))
    essential:RefreshLayout(); items = ItemsOf(essential)
    assert(Point(items[2])[2] == holder and Point(items[2])[4] == 198, "Blizzard's grid undone after its layout")

    -- Desaturate on Cooldown: gray on a real cooldown, kept after Blizzard's refresh.
    cooling[5001] = true; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(items[1].Icon.desaturated == true and items[2].Icon.desaturated == false, 'gray while cooling')
    items[1]:RefreshIconDesaturation()
    assert(items[1].Icon.desaturated == true, "kept after Blizzard's own gray")
    items[1].cooldownSwipeColor = CooldownViewerConstants.ITEM_AURA_COLOR; items[1]:RefreshSpellCooldownInfo()
    assert(items[1].Icon.desaturated == true, 'still gray while its effect is up: no full-color active swipe')
    items[1].cooldownSwipeColor = CooldownViewerConstants.ITEM_COOLDOWN_COLOR; items[1]:RefreshSpellCooldownInfo()
    assert(M:SetOption('essential', 'desaturate', false) and items[1].Icon.desaturated == false, 'off: full color')
    assert(M:SetOption('essential', 'desaturate', true) and items[1].Icon.desaturated == true)
    cooling[5001] = false; FireEvent('SPELL_UPDATE_COOLDOWN'); assert(items[1].Icon.desaturated == false, 'color back when ready')
    -- A cooldown running out sends no event, and Blizzard's own refresh as
    -- it ends can still find it cooling: the ticker asks again.
    cooling[5001] = true; FireEvent('SPELL_UPDATE_COOLDOWN')
    local ticker = M.coolingTicker
    assert(items[1].Icon.desaturated == true and ticker:IsShown() and M.watching[items[1]], 'watched while cooling')
    ticker.scripts.OnUpdate(ticker, 0.25)
    assert(items[1].Icon.desaturated == true and ticker:IsShown(), 'still cooling: still gray')
    items[1]:RefreshIconDesaturation()
    cooling[5001] = false
    ticker.scripts.OnUpdate(ticker, 0.1)
    assert(items[1].Icon.desaturated == true, 'asks every 0.2 seconds, not every frame')
    ticker.scripts.OnUpdate(ticker, 0.15)
    assert(items[1].Icon.desaturated == false and not M.watching[items[1]], 'ended with no event: color back')
    ticker.scripts.OnUpdate(ticker, 0.25)
    assert(not ticker:IsShown(), 'nothing left to watch: the ticker stops')

    -- Active spells: no gold full-color swipe by default; the spell's own
    -- cooldown, gray, straight away.
    cooling[5002] = true
    items[2].cooldownSwipeColor = CooldownViewerConstants.ITEM_AURA_COLOR; items[2]:RefreshSpellCooldownInfo()
    assert(items[2].Cooldown.durationObject.duration == 'cd:5002' and items[2].Cooldown.auraTime == false, "the spell's cooldown, not the effect's time")
    assert(items[2].Icon.desaturated == true and items[2].Cooldown.swipeColor[1] == M.db.essential.swipeColor[1], 'gray, in the swipe color')
    assert(M:SetOption('essential', 'auraSwipe', true)); items[2]:RefreshSpellCooldownInfo()
    assert(items[2].Icon.desaturated == false and items[2].Cooldown.swipeColor[2] == 0.8, "Show Aura Time: Blizzard's gold swipe in full color")
    assert(M:SetOption('essential', 'auraSwipe', false))

    -- Glows: off on every spell until switched on; each with its own look.
    ActionButtonSpellAlertManager:ShowAlert(items[2])
    assert(not (M.glows[items[2]] and M.glows[items[2]].proc and M.glows[items[2]].proc:IsShown()) and items[2].SpellActivationAlert.alpha == 0, 'no glow until switched on')
    assert(M:SetSpellSwitch('essential', '102', 'proc', true))
    local look = M.db.essential.spells['102'].proc
    assert(look.style == 'blizzard' and look.lines == 8 and look.thickness == 2, "switched on with the bar's look")
    local set = M.glows[items[2]]
    assert(set.proc:IsShown() and set.proc.flipbook:IsShown() and set.proc.flipbook.atlas == 'UI-HUD-ActionBar-Proc-Loop-Flipbook', "Blizzard: the game's proc loop art")
    assert(M:SetSpellSwitch('essential', '102', 'active', true) and set.active and not set.active:IsShown(), 'proc wins over active')
    ActionButtonSpellAlertManager:HideAlert(items[2]); assert(set.active:IsShown() and not set.proc:IsShown(), 'active glow while the effect is up')
    assert(M:SetSpellGlow('essential', '102', 'active', 'style', 'pixel') and set.active.pixels and set.active.pixels[1]:IsShown(), 'Pixel: marching lines')
    assert(M:SetSpellGlow('essential', '102', 'active', 'lines', 4) and set.active.pixelLines == 4 and not set.active.pixels[9]:IsShown())
    assert(M:SetSpellGlow('essential', '102', 'active', 'style', 'gcd') and set.active.flipbook.atlas == 'UI-HUD-ActionBar-Proc-Loop-Flipbook', 'GCD art missing on this client: the proc art')
    assert(not set.active.pixels[1]:IsShown(), 'the pixel lines put away')
    assert(not M:SetSpellGlow('essential', '102', 'active', 'style', 'sparkles'), 'unknown looks refused')
    assert(M:SetSpellSwitch('essential', '102', 'active', false) and not set.active:IsShown() and M.db.essential.spells['102'].active == nil, 'switched off')
    items[2].cooldownSwipeColor = CooldownViewerConstants.ITEM_COOLDOWN_COLOR; items[2]:RefreshSpellCooldownInfo()
    cooling[5002] = false; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(M:SetSpellSwitch('essential', '102', 'proc', false) and M.db.essential.spells['102'] == nil, 'an empty entry is not kept')
    -- Off cooldown: While Ready, then a flash for its own Glow Time.
    assert(M:SetSpellSwitch('essential', '103', 'ready', true) and M:SetSpellGlow('essential', '103', 'ready', 'mode', 'always'))
    assert(M.glows[items[3]].ready:IsShown(), 'lit while ready')
    cooling[5003] = true; FireEvent('SPELL_UPDATE_COOLDOWN'); assert(not M.glows[items[3]].ready:IsShown(), 'not while cooling')
    assert(M:SetSpellGlow('essential', '103', 'ready', 'mode', 'flash') and M:SetSpellGlow('essential', '103', 'ready', 'duration', 3))
    local after, timers = C_Timer.After, {}
    C_Timer.After = function(seconds, fn) timers[#timers + 1] = { seconds, fn } end
    cooling[5003] = false; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(M.glows[items[3]].ready:IsShown(), 'flash when the cooldown ends')
    for _, timer in ipairs(timers) do if timer[1] == 3 then timer[2]() end end
    C_Timer.After = after
    assert(not M.glows[items[3]].ready:IsShown(), 'gone after its Glow Time')
    assert(M:SetSpellSwitch('essential', '103', 'ready', false))
    -- Buff glow: follows the buff's active state, secret or not.
    local buffItems = ItemsOf(buffs)
    assert(M:SetSpellSwitch('buffIcon', '301', 'buff', true))
    buffItems[1]:SetIsActive(true)
    local buffGlow = M.glows[buffItems[1]].buff
    assert(buffGlow:IsShown() and buffGlow.soft.alpha == 1, 'buff glow while up')
    buffItems[1]:SetIsActive(false); assert(buffGlow.soft.alpha == 0, 'faded while down')
    buffItems[1]:SetIsActive(Secret('active'))
    assert(issecretvalue(buffGlow.soft.alphaFromBoolean) and issecretvalue(buffGlow.edges[1].alphaFromBoolean), 'secret state passed to SetAlphaFromBoolean')
    assert(M:SetSpellSwitch('buffIcon', '301', 'buff', false) and not buffGlow:IsShown(), 'buff glow off for this buff')
    buffItems[1]:SetIsActive(true)

    -- Tracked Buffs close gaps; a secret shown state keeps its place.
    buffItems[1].activeState = false; buffItems[1]:UpdateShownState()
    assert(M.placedCount.buffIcon == 1 and Point(buffItems[2])[4] == 209, 'the active buff takes the middle')
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
    assert(M.placedCount.essential == 4 and M.placedCount.utility == 2, 'their viewers close up (Utility keeps Berserking)')
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
    -- Anchoring: any ModeUI element and the custom bars, 1px off the side.
    local E = PM:Element('cooldownManagerEssential')
    assert(E.allowedTargets.actionBarsBar1 and E.allowedTargets.cooldownManagerCustom3, 'other ModeUI elements and custom bars as targets')
    assert(Point(ModeUICooldownUtility)[2] == ModeUICooldownEssential and Point(ModeUICooldownUtility)[5] == -1, 'Utility 1px under Essential')
    assert(PM:AnchorTo('cooldownManagerCustom1', 'cooldownManagerCustom3', 'below'))
    local hang = Point(ModeUICooldownCustom1)
    assert(hang[2] == ModeUICooldownCustom3 and hang[5] == -1, 'anchored with the 1px gap')
    assert(addon:SetEditMode(true) and PM:Nudge('cooldownManagerCustom1', 0, -2) and Point(ModeUICooldownCustom1)[5] == -3, 'nudged from there')
    assert(addon:SetEditMode(false)); ModeUIConfigWindow:Hide()
    -- Match Width: the icons resize to fill the parent's width, pixel perfect.
    assert(M:SetOption(c1, 'perLine', 5) and ModeUICooldownCustom1.width == 5 * 42 + 4 * 2)
    assert(PM:CanMatchSize('cooldownManagerCustom1', 'width') and PM:SetSizeMatchValue('cooldownManagerCustom1', 'width', true) and M.db.custom1.matchWidth)
    PM:RefreshAnchorSize('cooldownManagerCustom1')
    assert(ModeUICooldownCustom1.width == ModeUICooldownCustom3.width, 'width matched')
    assert(byKey[201].width == 68 and Point(byKey[201])[4] == 141, 'icons split the width on whole pixels')
    assert(M:SetOption(c3, 'perLine', 6)); PM:RefreshAnchorSize('cooldownManagerCustom1')
    assert(ModeUICooldownCustom1.width == ModeUICooldownCustom3.width and ModeUICooldownCustom3.width == 6 * 42 + 5 * 2, 'follows the parent')
    assert(PM:SetSizeMatchValue('cooldownManagerCustom1', 'width', false) and ModeUICooldownCustom1.width == 5 * 42 + 4 * 2)
    assert(M:SetOption(c1, 'perLine', 8))
    assert(M:RemoveEntry(c1, '201') and Point(byKey[201])[2] == M.holders.utility, 'Remove from Bar sends it back')
    assert(M:DeleteCustomBar(c3) and Point(byKey[102])[2] == holder and byKey[102].alpha == 1, 'deleting gives the spells back')
    assert(addon.db.positions.cooldownManagerCustom3 == nil and not ModeUICooldownCustom3:IsShown() and M.db.custom3 == nil)
    assert(PM:GetPosition('cooldownManagerCustom1').target == 'screen' and not E.allowedTargets.cooldownManagerCustom3, 'what hung from it moves to the screen')

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
    assert(M:SetSpellSwitch(c1, 's9001', 'ready', true) and M:SetSpellGlow(c1, 's9001', 'ready', 'mode', 'always') and not (M.glows[own] and M.glows[own].ready and M.glows[own].ready:IsShown()))
    cooling[9001] = false; M.coolingTicker.scripts.OnUpdate(M.coolingTicker, 0.25)
    assert(own.Icon.desaturated == false, "a custom spell's icon gets its color back with no event too")
    FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(own.Icon.desaturated == false and M.glows[own].ready:IsShown(), 'ready: color and the While Ready glow')
    assert(M:SetSpellSwitch(c1, 's9001', 'proc', true))
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
    -- The list: Spells and Abilities, Cooldown Bars, Buff Bars, then Resource Bars.
    assert(window.blizzardCaption.text == 'SPELLS AND ABILITIES' and window.cooldownCaption.text == 'COOLDOWN BARS' and window.buffCaption.text == 'BUFF BARS')
    assert(window.rows[5]:IsShown() and window.rows[5].label.text == 'Cooldown Bar 1' and window.rows[6].label.text == 'Buff Bar 1', 'custom bars under their headings')
    assert(window.rows[7].resource and Point(window.resourceCaption)[5] < Point(window.rows[6])[5], 'Resource Bars after the custom bars')
    assert(window.rows[5].delete:IsShown() and not window.rows[1].delete:IsShown(), '- on custom bars only')
    -- + adds a bar under its heading; - asks first.
    window.addCooldown.scripts.OnClick(window.addCooldown)
    local added = M.selectedBar
    assert(M:Custom(added) and M:Custom(added).kind == 'cooldown' and window.rows[6].barId == added, 'a new Cooldown Bar, listed with the others')
    window.rows[6].delete.scripts.OnClick(window.rows[6].delete)
    local confirm = addon.ConfigWidgets.confirmFrame
    assert(confirm:IsShown() and M:Custom(added), 'asks before deleting')
    confirm.cancel.scripts.OnClick(confirm.cancel)
    assert(not confirm:IsShown() and M:Custom(added), 'Cancel keeps it')
    window.rows[6].delete.scripts.OnClick(window.rows[6].delete); confirm.accept.scripts.OnClick(confirm.accept)
    assert(not M:Custom(added) and M.selectedBar == 'essential', 'deleted after Delete Bar')
    -- Editing at the top right of the preview.
    assert(M.page.editingSelect and M.page.editingLabel.text == 'Editing')
    M:SelectEditing('utility'); assert(M.page.viewerEditing() == 'utility', 'Editing picks the bar')
    window.rows[6].scripts.OnClick(window.rows[6])
    local page, view = M.page, M.previewView
    assert(page.viewerEditing() == c2 and view.icons[1].key == '301' and view.plus:IsShown(), 'a custom bar: its spells, then +')
    view.plus.scripts.OnMouseUp(view.plus, 'LeftButton')
    local picker = M.picker
    assert(picker:IsShown() and picker.buttons[1]:IsShown() and picker.buttons[1].key == '302', 'tracked buffs not on it yet')
    assert(picker.headings[2]:IsShown() and picker.buttons[2].key == '303' and picker.buttons[2].icon.desaturated, 'a class buff not in Blizzard CDM: grayed')
    assert(picker.buttons[2].where:find('Not in Blizzard CDM', 1, true) and not picker.buttons[3], 'says so; nothing else')
    assert(not picker.headings[3]:IsShown() and not picker.spellRow:IsShown() and not picker.itemRow:IsShown(), 'no items or IDs on a Buff Bar')
    picker.buttons[2].scripts.OnClick(picker.buttons[2])
    assert(#M:Custom(c2).entries == 1, 'an untracked buff cannot be added')
    picker.buttons[1].scripts.OnClick(picker.buttons[1])
    assert(M:Custom(c2).entries[2] == '302' and picker.empty:IsShown(), 'added; nothing tracked left')
    picker:Hide()
    view.icons[1].scripts.OnMouseUp(view.icons[1], 'LeftButton')
    local menu = M.spellMenu
    assert(menu:IsShown() and menu.remove:IsShown() and not menu.earlier.enabled and menu.glowBoxes.buff:IsShown() and not menu.glowBoxes.proc:IsShown())
    assert(not menu.glowBoxes.buff.selected and menu.glowBoxes.buff.more:IsShown(), 'off by default, with its > button')
    -- The > opens the glow's popout beside the menu.
    menu.glowBoxes.buff.more.scripts.OnClick(menu.glowBoxes.buff.more)
    local popout = M.glowPopout
    assert(popout:IsShown() and popout.kind == 'buff' and popout.title.text == 'Buff Glow' and view.glowKind == 'buff', 'buff glow popout')
    assert(popout.styleRow:IsShown() and popout.colorRow:IsShown() and not popout.whenRow:IsShown() and not popout.linesRow:IsShown())
    popout.styleButtons[3].scripts.OnClick(popout.styleButtons[3])
    assert(M.db.custom2.spells['301'].buff.style == 'pixel' and menu.glowBoxes.buff.selected, 'choosing a look switches the glow on')
    assert(popout.linesRow:IsShown() and popout.thicknessRow:IsShown() and not popout.pulseRow:IsShown(), 'Pixel shows its lines and thickness')
    popout.swatch.scripts.OnClick(popout.swatch)
    ColorPickerFrame.r, ColorPickerFrame.g, ColorPickerFrame.b = 1, 0, 0; ColorPickerFrame.swatchFunc()
    assert(M.db.custom2.spells['301'].buff.color[1] == 1 and M.db.custom2.spells['301'].buff.color[2] == 0, "Blizzard's color picker sets its color")
    popout.onBox.scripts.OnClick(popout.onBox)
    assert(M.db.custom2.spells['301'] == nil, 'Glow On off')
    popout.close.scripts.OnClick(popout.close)
    assert(not popout:IsShown() and view.glowKind == nil)
    menu.later.scripts.OnClick(menu.later)
    assert(M:Custom(c2).entries[1] == '302', 'Later')
    menu:Hide()
    M:SelectBar(c1)
    view.plus.scripts.OnMouseUp(view.plus, 'LeftButton')
    assert(picker.buttons[7]:IsShown() and picker.buttons[7].key == '202', 'all seven tracked cooldowns from Essential and Utility')
    local unknown = picker.buttons[8]
    assert(unknown.key == 's5006' and unknown.icon.desaturated and unknown.where:find('not learned', 1, true), 'an unlearned class spell, grayed')
    assert(picker.buttons[9].key == 's26297' and picker.buttons[9].where:find('Not in Blizzard CDM', 1, true) and picker.buttons[9].add ~= nil, 'your racial, for a bar that does not show it')
    assert(picker.buttons[10].key == 'i5512' and picker.buttons[11].key == 'i191380' and not (picker.buttons[12] and picker.buttons[12]:IsShown()), 'usable items in your bags (no cloth)')
    assert(picker.headings[3]:IsShown() and picker.spellRow:IsShown() and picker.itemRow:IsShown(), 'Spell ID and Item ID on a Cooldown Bar')
    unknown.scripts.OnClick(unknown)
    assert(M:Custom(c1).entries[#M:Custom(c1).entries] == 's5006', 'added as a custom spell')
    assert(picker.buttons[8].key == 's26297', 'gone from the list')
    knownSpells[7676] = false
    picker.idInput:SetText('7676'); picker.idAdd.scripts.OnClick(picker.idAdd)
    assert(picker.idResult.text:find("know that spell", 1, true), 'a spell you do not know is refused, pointing at Item ID')
    picker.itemRow.input:SetText('7676'); picker.itemRow.add.scripts.OnClick(picker.itemRow.add)
    assert(M:Custom(c1).entries[#M:Custom(c1).entries] == 'i7676' and picker.idResult.text == 'Added Thistle Tea.', 'the item instead')
    picker.itemRow.input:SetText('2589'); picker.itemRow.add.scripts.OnClick(picker.itemRow.add)
    assert(picker.idResult.text == 'That item has no Use: effect.')
    picker.itemRow.input:SetText('999'); picker.itemRow.add.scripts.OnClick(picker.itemRow.add)
    assert(picker.idResult.text == 'No item has that ID.')
    picker.buttons[9].scripts.OnClick(picker.buttons[9])
    assert(M:Custom(c1).entries[#M:Custom(c1).entries] == 'i5512', 'an item from your bags')
    -- An item's icon: picture, count, cooldown, gray with none left.
    local stone = M.spellIcons[c1].i5512
    assert(stone:IsShown() and stone.Icon.texture == 'item:5512' and stone.ChargeCount.Current.text == '1', 'its picture and count')
    itemCooldowns[5512] = { 100, 120 }; FireEvent('BAG_UPDATE_COOLDOWN')
    assert(stone.Cooldown.cooldownStart == 100 and stone.Cooldown.cooldownDuration == 120 and stone.Icon.desaturated == true, 'its cooldown, gray')
    assert(M:SetSpellSwitch(c1, 'i5512', 'ready', true) and M:SetSpellGlow(c1, 'i5512', 'ready', 'mode', 'always'))
    assert(not (M.glows[stone] and M.glows[stone].ready and M.glows[stone].ready:IsShown()), 'While Ready: not while cooling')
    itemCooldowns[5512] = nil; FireEvent('BAG_UPDATE_COOLDOWN')
    assert(stone.Icon.desaturated == false and M.glows[stone].ready:IsShown(), 'ready again: color and its glow')
    itemCounts[5512] = 0; FireEvent('BAG_UPDATE_DELAYED')
    assert(stone:IsShown() and stone.ChargeCount.Current.text == '0' and stone.Icon.desaturated == true, 'none left: kept, gray, 0')
    itemCounts[5512] = 1; FireEvent('BAG_UPDATE_DELAYED')
    stone.scripts.OnEnter(stone); assert(GameTooltip.item == 5512, 'item tooltip')
    assert(M:SpellLabel('i5512') == 'Healthstone')
    assert(M:RemoveEntry(c1, 'i7676') and M:RemoveEntry(c1, 'i5512') and M:RemoveEntry(c1, 's5006'))
    picker.idInput:SetText('9003'); picker.idAdd.scripts.OnClick(picker.idAdd)
    assert(M:Custom(c1).entries[2] == 's9003' and picker.idResult.text == 'Added Spell 9003.' and picker.idInput:GetText() == '', 'added from the list')
    picker.idInput:SetText('950000'); picker.idAdd.scripts.OnClick(picker.idAdd)
    assert(picker.idResult.text == 'No spell has that ID.', 'says why not')
    assert(view.icons[1].key == 's9001' and view.icons[1].Icon.texture == 'icon:9001', 'custom spells in the preview')
    picker:Hide()
    -- Essential and Utility take spells through their + too.
    M:SelectBar('essential')
    view.plus.scripts.OnMouseUp(view.plus, 'LeftButton')
    local function Find(key)
        for _, button in ipairs(picker.buttons) do if button:IsShown() and button.key == key then return button end end
    end
    assert(picker:IsShown() and picker.title.text == 'Add to Essential Cooldowns' and cdmToggles == 0, "Essential's + lists what it can take")
    assert(Find('202') and not Find('101') and picker.spellRow:IsShown() and picker.itemRow:IsShown(), 'Utility spells; Spell ID and Item ID')
    Find('202').scripts.OnClick(Find('202'))
    local util = ItemsOf(utility)
    local moved = util[1].cooldownID == 202 and util[1] or util[2]
    assert(M.db.extras.essential[1] == '202' and Point(moved)[2] == holder, 'a Utility spell moves to Essential')
    assert(view.icons[1].key == '101' and view.icons[6].key == '202', 'its own spells first, then what it took')
    picker.itemRow.input:SetText('5512'); picker.itemRow.add.scripts.OnClick(picker.itemRow.add)
    assert(M.db.extras.essential[2] == 'i5512' and M.spellIcons.essential.i5512:IsShown(), 'an item on Essential')
    picker:Hide()
    assert(M:RemoveEntry('essential', '104') and M:SpellSwitch('essential', '104', 'hide') and #M.db.extras.essential == 2, "removing its own spell hides it")
    view.plus.scripts.OnMouseUp(view.plus, 'LeftButton')
    local back = Find('104')
    assert(back and back.where:find('removed from this bar', 1, true), 'listed to bring back')
    back.scripts.OnClick(back)
    assert(not M:SpellSwitch('essential', '104', 'hide'), 'shows again')
    picker:Hide()
    assert(M:RemoveEntry('essential', '202') and Point(moved)[2] == M.holders.utility, 'back to Utility')
    assert(M:RemoveEntry('essential', 'i5512') and #M.db.extras.essential == 0 and not M.spellIcons.essential.i5512)
    -- A spell's own text look from its menu's Text row.
    view.icons[1].scripts.OnMouseUp(view.icons[1], 'LeftButton')
    assert(menu:IsShown() and menu.textRows.cooldown.more:IsShown() and menu.textRows.count.more:IsShown() and not menu.textRows.name.more:IsShown())
    assert(menu.remove:IsShown() and menu.earlier:IsShown() and not menu.earlier.enabled and menu.later.enabled, "Remove from Bar and order on Essential")
    menu.textRows.count.more.scripts.OnClick(menu.textRows.count.more)
    local text = M.textPopout
    assert(text:IsShown() and text.part == 'count' and text.title.text == 'Count Text' and view.textPart == 'count' and not text.reset.enabled)
    assert(view.icons[1].ChargeCount.Current.text == '2', 'the count shows on the spell')
    text.outlineButtons[3].scripts.OnClick(text.outlineButtons[3])
    local own = M.db.essential.spells['101'].text.count
    assert(own.outline == 'thick' and own.size == 12 and own.anchor == 'BOTTOMRIGHT', "starts from the bar's look")
    local live = ItemsOf(essential)[1].ChargeCount.Current
    assert(live.font[3] == 'THICKOUTLINE', 'thick outline on the real icon')
    text.anchorButtons.TOPLEFT.scripts.OnClick(text.anchorButtons.TOPLEFT)
    assert(Point(live)[1] == 'TOPLEFT' and M:SetSpellText('essential', '101', 'count', 'size', 16) and live.font[2] == 16, 'its place and size')
    assert(ItemsOf(essential)[2].ChargeCount.Current.font[2] == 12, 'the other spells keep the bar look')
    assert(menu.textRows.count.label.text:find('own look', 1, true) and text.reset.enabled)
    text.showBox.scripts.OnClick(text.showBox); assert(live.alpha == 0, 'Show This Text off')
    assert(not M:SetSpellText('essential', '101', 'count', 'outline', 'double'), 'refused: not an outline')
    assert(not M:SetSpellText('essential', '101', 'count', 'spin', 1) and not M:SetSpellText('essential', '101', 'name', 'size', 14), 'refused: no such field; icons have no name text')
    menu.glowBoxes.proc.more.scripts.OnClick(menu.glowBoxes.proc.more)
    assert(not text:IsShown() and M.glowPopout:IsShown(), 'one popout at a time')
    menu.textRows.count.more.scripts.OnClick(menu.textRows.count.more)
    assert(text:IsShown() and not M.glowPopout:IsShown())
    text.reset.scripts.OnClick(text.reset)
    assert(M.db.essential.spells['101'] == nil and live.font[2] == 12 and live.font[3] == 'OUTLINE' and live.alpha == 1, "Use Bar's Look")
    menu:Hide(); assert(not text:IsShown())
    -- Dragging a spell in the preview moves it on the bar.
    local function Live(id) for _, item in ipairs(ItemsOf(essential)) do if item.cooldownID == id then return item end end end
    local thirdX = Point(Live(103))[4]
    local s1, s3 = view.icons[1], view.icons[3]
    assert(s1.key == '101' and s3.key == '103')
    s1.scripts.OnMouseDown(s1, 'LeftButton'); s1.scripts.OnDragStart(s1)
    assert(view.ghost:IsShown() and s1.alpha == 0.3 and view.frame.scripts.OnUpdate, 'a copy of the icon follows the cursor')
    s3.mouseOver = true; view.frame.scripts.OnUpdate(view.frame)
    assert(s3.highlight:IsShown() and not s1.highlight:IsShown(), 'the slot under the cursor lights up')
    s1.scripts.OnDragStop(s1); s3.mouseOver = false
    s1.scripts.OnMouseUp(s1, 'LeftButton')
    assert(not menu:IsShown() and not view.ghost:IsShown() and not view.frame.scripts.OnUpdate, 'a drag is not a click; nothing left running')
    assert(M.db.order.essential[1] == '102' and M.db.order.essential[3] == '101', 'the order is saved')
    assert(view.icons[3].key == '101' and Point(Live(101))[4] == thirdX, 'the preview and the bar follow')
    s1 = view.icons[1]; s1.scripts.OnMouseDown(s1, 'LeftButton'); s1.scripts.OnDragStart(s1); s1.scripts.OnDragStop(s1)
    assert(M.db.order.essential[1] == '102', 'let go off any other slot: it stays')
    essential:RefreshLayout()
    assert(Point(Live(101))[4] == thirdX, "kept after Blizzard's own layout")
    view.icons[3].scripts.OnMouseDown(view.icons[3], 'LeftButton'); view.icons[3].scripts.OnMouseUp(view.icons[3], 'LeftButton')
    assert(menu:IsShown() and menu.key == '101', 'a click still opens the menu')
    menu.later.scripts.OnClick(menu.later)
    assert(M.db.order.essential[4] == '101', 'Later')
    menu:Hide()
    assert(M:MoveSpell('essential', '101', 1) and view.icons[1].key == '101' and not M:MoveSpell('essential', '101', 9), 'back first; no ninth place')
    -- Racials show on their own, on Utility by default.
    local berserk = M.spellIcons.utility.s26297
    assert(M.db.racials == 'utility' and berserk and berserk:IsShown() and Point(berserk)[2] == M.holders.utility, 'Berserking on Utility')
    assert(M:Entries('utility')[#M:Entries('utility')] == 's26297' and #M.db.extras.utility == 0, 'listed, not saved')
    assert(not M.spellIcons.utility.s20594 and not M.spellIcons.utility.s28730, "other races' racials stay off")
    M:SelectBar('utility')
    assert(page.racialsSelect and view.icons[#M:SpellOrder('utility')].key == 's26297', 'Racial Abilities on the Bar tab; in the preview')
    assert(M:RemoveEntry('utility', 's26297') and M:SpellSwitch('utility', 's26297', 'hide') and berserk.alpha == 0, 'Remove from Bar hides it')
    assert(M:SetSpellSwitch('utility', 's26297', 'hide', false))
    assert(M:SetRacials('essential') and M.spellIcons.essential.s26297:IsShown() and not M.spellIcons.utility.s26297, 'moved to Essential')
    assert(not M:SetRacials('buffIcon') and M.db.racials == 'essential', 'not on Tracked Buffs')
    local temp = M:AddCustomBar('cooldown')
    assert(M:SetRacials(temp) and M.spellIcons[temp].s26297 and M:DeleteCustomBar(temp) and M.db.racials == 'utility', 'a deleted bar gives them back to Utility')
    assert(M:SetRacials('none') and not M.spellIcons.utility.s26297 and not M.spellIcons.essential.s26297, 'Off')
    assert(M:SetRacials('utility'))
    M:SelectBar('essential')
    M:SelectBar('buffIcon')
    view.plus.scripts.OnMouseUp(view.plus, 'LeftButton')
    assert(cdmToggles == 1, "Tracked Buffs' + opens Blizzard's Cooldown Manager")
    M:SelectBar('essential')
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
    assert(M.enabled and M.db.essential.border == 'square' and #M.db.customBars == 2 and M.db.nextCustom == 6 and M.db.racials == 'utility', 'settings persist')
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
    assert(db.version == 4 and db.essential.border == 'mode' and db.essential.borderColor[1] == addon.Kit.BORDER_COLOR[1], 'v1 also takes the ModeUI border')
    assert(db.essential.grow == 'left' and db.essential.lineGrowth == 'down', 'right-aligned rows grow left')
    assert(db.essential.readyGlow == 'border' and db.essential.readyMode == 'flash' and db.essential.readyStyle == nil, 'ready glow look kept, as a flash')
    assert(db.essential.orientation == nil and db.essential.desaturate == true and #db.customBars == 0)
    assert(db.utility.grow == 'up' and db.utility.lineGrowth == 'left', 'columns from the bottom right')
    assert(db.buffIcon.grow == 'centerH' and db.buffIcon.lineGrowth == 'up' and db.buffIcon.readyGlow == 'mode', 'None is no longer a look')
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
    assert(db.version == 4 and db.essential.border == 'mode' and db.essential.borderColor[1] == Kit.BORDER_COLOR[1], 'old default to the ModeUI border')
    assert(db.utility.border == 'square' and db.utility.borderColor[1] == 1, 'a chosen Square border and color stay')
    assert(db.custom1.border == 'mode', 'custom bars too')
]==], "migrate v2")

-- Version 3: default sizes move to 42 by 34 and 36 by 28; Utility's default
-- place, 4 units under Essential, sits against it now (the 1px gap is built in).
local v3 = restored.saved()
local before = v3.profiles.Default.modules.cooldownManager
before.version = 3
before.essential.width, before.essential.height = 42, 36
before.utility.width, before.utility.height = 40, 30
before.custom2.width, before.custom2.height = 35, 30
v3.profiles.Default.positions.cooldownManagerUtility = { target = "cooldownManagerEssential", placement = "below", x = 0, y = -4 }
H.Load({ before = STUBS .. "\nMakeViewers()", saved = v3 }).run([==[
    local M, PM = addon.CooldownManager, addon.PositionManager
    local db = M.db
    assert(db.version == 4 and db.essential.width == 42 and db.essential.height == 34 and db.custom2.width == 36 and db.custom2.height == 28, 'default sizes move')
    assert(db.utility.width == 40 and db.utility.height == 30 and db.movePlaces == nil, 'a chosen size stays')
    assert(PM:GetPosition('cooldownManagerUtility').y == 0 and Point(ModeUICooldownUtility)[5] == -1, 'Utility 1px under Essential')
]==], "migrate v3")

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
Refused(function(db) db.customBars[2].entries = { "i5512" } end, "an item on a Buff Bar")
Refused(function(db) db.extras.buffIcon = { "302" } end, "spells taken by Tracked Buffs")
Refused(function(db) db.order = { essential = { "101", "101" } } end, "a spell twice in an order")
Refused(function(db) db.order = { custom9 = { "101" } } end, "an order for no viewer")
Refused(function(db) db.racials = "buffIcon" end, "racials on Tracked Buffs")
Refused(function(db) db.extras.essential = { "s9001", "s9001" } end, "Essential's spells twice")
local function Text(look) return { ["101"] = { text = { count = look } } } end
local function Copy(t) local c = {}; for k, v in pairs(t) do c[k] = type(v) == "table" and Copy(v) or v end; return c end
local good = { show = true, size = 12, anchor = "TOP", x = 0, y = 0, color = { 1, 1, 1 }, font = "game", fontMedia = "Expressway", outline = "thick", shadow = true }
-- A spell's own text and Essential's own spells load back.
do
    local saved = restored.saved()
    local db = saved.profiles.Default.modules.cooldownManager
    db.essential.spells = Text(Copy(good)); db.extras.essential = { "202", "s9001", "i5512" }
    local back = H.Load({ before = STUBS .. "\nMakeViewers()", saved = saved })
    back.run([==[
        local M = addon.CooldownManager
        assert(M.db.essential.spells['101'].text.count.outline == 'thick' and M.db.extras.essential[3] == 'i5512', 'kept')
        assert(ItemsOf(EssentialCooldownViewer)[1].ChargeCount.Current.font[3] == 'THICKOUTLINE', 'drawn with its own look')
        assert(Point(ItemsOf(UtilityCooldownViewer)[2])[2] == M.holders.essential, 'Utility spell on Essential after a reload')
    ]==], "cooldown manager reload")
end
Refused(function(db) local look = Copy(good); look.outline = "double"; db.essential.spells = Text(look) end, "a text outline")
Refused(function(db) local look = Copy(good); look.size = 90; db.essential.spells = Text(look) end, "a text size")
Refused(function(db) db.essential.spells = { ["101"] = { text = { bogus = good } } } end, "a text part")

print("cooldown manager: all checks passed")
