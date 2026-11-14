-- Cooldown Manager: hooking Blizzard's viewers, placing their icons on ModeUI
-- holders (lines, centering, hidden spells, inactive buffs, secret shown
-- states), the icon and bar skins, the swipe kept after Blizzard's refresh,
-- texts, proc and ready glows, per-spell switches, visibility, Edit Mode,
-- the settings page with its preview and spell menu, copy and reset,
-- switching off, late loading, persistence and the no-writes rule on
-- Blizzard's frames. Simulated client; not WoW rendering, security or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/cooldown_manager_stubs.lua")

local world = H.Load({ before = STUBS .. "\nMakeViewers()" })
world.run([==[
    local M, PM, Kit = addon.CooldownManager, addon.PositionManager, addon.Kit
    local essential, utility, buffs, bars = EssentialCooldownViewer, UtilityCooldownViewer, BuffIconCooldownViewer, BuffBarCooldownViewer
    assert(M and not M.enabled and not M.built and M.category == 'interface', 'registered under Interface, off by default')
    local first = ItemsOf(essential)[1]
    assert(first.Icon.mask ~= nil and Point(first)[2] == essential, "Blizzard's icons untouched while off")
    for _, viewer in ipairs(M.viewers) do
        local style = M.db[viewer]
        assert(style.border == 'rounded' and style.borderSize == 2 and style.backgroundOpacity == 75 and style.show, viewer .. ' defaults')
    end
    assert(M.db.essential.width == 42 and M.db.essential.height == 36 and M.db.buffBar.width == 220 and M.db.buffBar.perLine == 1)
    assert(M.db.buffIcon.start == 'BOTTOMLEFT' and M.db.essential.start == 'TOPLEFT' and M.db.essential.center, 'buffs grow upward; rows centered')

    addon:SetModuleEnabled('cooldownManager', true)
    assert(M.built and ModeUICooldownEssential and ModeUICooldownBuffBar, 'a stand-in per viewer')
    assert(PM:GetPosition('cooldownManagerUtility').target == 'cooldownManagerEssential', 'Utility sits under Essential')
    assert(PM:GetPosition('cooldownManagerBuffIcon').placement == 'above', 'Tracked Buffs on top')
    local holder = M.holders.essential
    local items = ItemsOf(essential)
    -- Five icons in one centered row of 42x36, 2px apart, on ModeUI's holder.
    assert(ModeUICooldownEssential.width == 5 * 42 + 4 * 2 and ModeUICooldownEssential.height == 36, 'stand-in fits the icons')
    local p = Point(items[2])
    assert(p[1] == 'TOPLEFT' and p[2] == holder and p[4] == 44 and p[5] == 0, 'second icon one step right, on the holder')
    assert(items[1].width == 42 and items[1].height == 36 and items[1].scale == 1, "ModeUI's size; Blizzard's Icon Size scale undone")
    assert(#ItemsOf(essential) == 5, 'only tracked spells')

    -- Skin: Blizzard's mask and frame art off, the Mode slot on, icon cropped.
    local icon = items[1].Icon
    assert(icon.mask == nil and items[1].overlay.alpha == 0, 'round mask removed, frame art faded')
    local art = M.dress[items[1]].art
    assert(art and art.edges[1].vertexColor[1] == M.BORDER_COLOR[1] and art.fill.vertexColor[4] == 0.75, 'border and 75% background')
    assert(icon.points[1][4] == 3 and icon.points[2][4] == -3, 'icon a pixel inside the 2px border')
    local span = 0.84 * 30 / 36
    assert(math.abs(icon.texCoord[3] - (0.5 - span / 2)) < 1e-9 and icon.texCoord[1] == 0.08, 'cropped, not stretched')
    assert(items[1].Cooldown.swipeTexture == Kit.FLAT and items[1].Cooldown.points[1][4] == 3, 'flat swipe inside the border')
    assert(items[1].OutOfRange.texture == Kit.FLAT and items[1].OutOfRange.alpha == 1, 'out of range: a flat shade inside the border')
    -- Blizzard sets its swipe and edge on each refresh; ModeUI's come back.
    items[1]:RefreshSpellCooldownInfo()
    assert(items[1].Cooldown.drawEdge == false and items[1].Cooldown.swipeColor[4] == 0.7, 'edge off, 70% swipe after the refresh')
    assert(M:SetOption('essential', 'swipeColor', { 1, 0, 0 }))
    items[1]:RefreshSpellCooldownInfo()
    assert(items[1].Cooldown.swipeColor[1] == 1, 'Swipe Color')
    items[2].cooldownSwipeColor = CooldownViewerConstants.ITEM_AURA_COLOR
    items[2]:RefreshSpellCooldownInfo()
    assert(items[2].Cooldown.swipeColor[2] == 0.8, "an active aura keeps Blizzard's gold swipe")
    assert(M:SetOption('essential', 'showFlash', false) and items[1].CooldownFlash.alpha == 0, 'Ready Flash off')

    -- Text: cooldown numbers amber in the middle, the count in the corner.
    local countdown = items[1].Cooldown.countdown
    assert(countdown and countdown.font[2] == 15 and countdown.color[2] == M.COOLDOWN_COLOR[2] and Point(countdown)[1] == 'CENTER', 'cooldown numbers')
    local count = items[1].ChargeCount.Current
    p = Point(count)
    assert(count.font[2] == 12 and p[1] == 'BOTTOMRIGHT' and p[4] == -4 and p[5] == 4, 'count tucked into the corner')
    assert(items[1].ChargeCount.frameLevel > items[1]:GetFrameLevel(), 'counts above the swipe')
    assert(M:SetOption('essential', 'countShow', false) and count.alpha == 0, 'a text hides by fading')

    -- Lines: three per line, the short second line centered.
    assert(M:SetOption('essential', 'perLine', 3))
    assert(ModeUICooldownEssential.width == 3 * 42 + 2 * 2 and ModeUICooldownEssential.height == 2 * 36 + 2, 'two lines of three')
    p = Point(items[4]); assert(p[4] == 22 and p[5] == -38, 'short line moved half a step to the middle')
    assert(M:SetOption('essential', 'center', false))
    p = Point(items[4]); assert(p[4] == 0 and p[5] == -38, 'Center Lines off: from the corner')
    -- Blizzard lays the viewer out again: ModeUI's places come straight back.
    essential:RefreshLayout()
    items = ItemsOf(essential)
    p = Point(items[2]); assert(p[2] == holder and p[4] == 44, "Blizzard's grid undone after its layout")

    -- Spells: one hidden, the rest close up; it takes no mouse.
    assert(M:SetSpellSwitch('essential', '102', 'hide', true) and M.db.essential.spells['102'].hide == true)
    assert(items[2].alpha == 0 and items[2].motion == false and Point(items[2])[1] == 'CENTER', 'hidden spell waits unseen')
    p = Point(items[3]); assert(p[4] == 44 and p[5] == 0, 'the next spell takes its place')
    assert(M:HiddenCount('essential') == 1)
    assert(M:SetSpellSwitch('essential', '102', 'hide', false) and M.db.essential.spells['102'] == nil and items[2].alpha == 1, 'shown again')
    assert(not M:SetSpellSwitch('essential', '102', 'bogus', true), 'unknown switches refused')

    -- Procs: Mode Glow over the icon, Blizzard's alert faded; per spell off.
    ActionButtonSpellAlertManager:ShowAlert(items[1])
    local proc = M.glows[items[1]].proc
    assert(proc:IsShown() and items[1].SpellActivationAlert.alpha == 0, "Mode Glow shows, Blizzard's alert hides")
    assert(M:SetSpellSwitch('essential', '101', 'proc', false) and not proc:IsShown(), 'proc glow off for this spell')
    assert(M:SetSpellSwitch('essential', '101', 'proc', true) and proc:IsShown())
    assert(M:SetOption('essential', 'procGlow', 'blizzard') and not proc:IsShown() and items[1].SpellActivationAlert.alpha == 1, 'Blizzard style')
    assert(M:SetOption('essential', 'procGlow', 'mode'))
    ActionButtonSpellAlertManager:HideAlert(items[1]); assert(not proc:IsShown(), 'ends with the proc')

    -- Ready: a real cooldown ending lights the icon for Glow Time.
    assert(M:SetOption('essential', 'readyGlow', true))
    local after, timers = C_Timer.After, {}
    C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
    cooling[5003] = true; FireEvent('SPELL_UPDATE_COOLDOWN')
    cooling[5003] = false; FireEvent('SPELL_UPDATE_COOLDOWN')
    local ready = M.glows[items[3]] and M.glows[items[3]].ready
    assert(ready and ready:IsShown(), 'ready glow when the cooldown ends')
    for _, fn in ipairs(timers) do fn() end
    C_Timer.After = after
    assert(not ready:IsShown(), 'gone after Glow Time')
    assert(M:SetSpellSwitch('essential', '103', 'ready', false))
    cooling[5003] = true; FireEvent('SPELL_UPDATE_COOLDOWN'); cooling[5003] = false; FireEvent('SPELL_UPDATE_COOLDOWN')
    assert(not ready:IsShown(), 'ready glow off for this spell')

    -- Tracked Buffs: an inactive buff leaves no gap; a secret shown state counts as shown.
    local buffItems = ItemsOf(buffs)
    assert(Point(buffItems[1])[1] == 'BOTTOMLEFT' and Point(buffItems[2])[4] == 37, 'buffs from the bottom left')
    assert(buffItems[1].DebuffBorder.alpha == 0, 'debuff border off by default')
    buffItems[1].activeState = false; buffItems[1]:UpdateShownState()
    assert(M.placedCount.buffIcon == 1 and Point(buffItems[2])[4] == 0, 'the active buff closes the gap')
    buffItems[1].secretShown = true; buffItems[1]:UpdateShownState()
    assert(M.placedCount.buffIcon == 2, 'a secret shown state keeps its place')
    buffItems[1].secretShown = nil; buffItems[1].activeState = true; buffItems[1]:UpdateShownState()

    -- Tracked Bars: the icon in the Mode slot, the bar in its box beside it.
    local bar = ItemsOf(bars)[1]
    assert(bar.width == 220 and bar.height == 22 and bar.Icon.width == 22 and Point(bar.Icon)[1] == 'LEFT', 'icon as tall as the bar')
    local box = M.dress[bar].box
    p = Point(box); assert(p[1] == 'TOPLEFT' and p[4] == 24, 'box beside the icon, 2px apart')
    p = Point(bar.Bar); assert(p[2] == box and p[4] == 2 and p[5] == -2, 'bar inside the border')
    assert(bar.Bar.statusBarTexture == Kit.FLAT and bar.Bar.statusBarColor[3] == M.BAR_COLOR[3], 'Mode Gradient in Bar Color')
    assert(bar.Bar.BarBG.alpha == 0 and bar.Bar.Pip.alpha == 0 and bar.Icon.Icon.mask == nil, "Blizzard's bar art faded")
    assert(bar.Bar.Name.font[2] == 11 and Point(bar.Bar.Name)[1] == 'LEFT' and Point(bar.Bar.Duration)[1] == 'RIGHT', 'name and time inside the bar')
    assert(M:SetOption('buffBar', 'iconSide', 'right') and Point(bar.Icon)[1] == 'RIGHT' and Point(box)[4] == 0, 'Icon Side right')
    bar:SetBarContent('name')
    p = Point(box); assert(p[4] == 0 and Point(box, 2)[4] == 0, 'no icon: the bar takes the width')
    bar:SetBarContent('both')
    assert(M:SetOption('buffBar', 'barTexture', 'flat') and bar.Bar.statusBarTexture == Kit.FLAT)

    -- Settings are checked: icons stay small, bars may be long; none in combat.
    assert(not M:SetOption('essential', 'width', 200) and M.db.essential.width == 42, 'icon width range')
    assert(M:SetOption('buffBar', 'width', 300) and bar.width == 300, 'bar width')
    assert(not M:SetOption('essential', 'border', 'thick') and not M:SetOption('essential', 'nope', 1))
    assert(not M:SetOption('buffBar', 'barBackground', 'mode'), 'Mode Gradient is a foreground only')

    -- Visibility: alpha on the icons; Blizzard's viewer is never touched.
    assert(M:SetOption('utility', 'visibility', 'combat') and ItemsOf(utility)[1].alpha == 0, 'In Combat: hidden out of combat')
    testCombat = true; FireEvent('PLAYER_REGEN_DISABLED')
    assert(ItemsOf(utility)[1].alpha == 1, 'shown in combat')
    assert(not M:SetOption('utility', 'opacity', 50), 'no changes in combat')
    testCombat = false; FireEvent('PLAYER_REGEN_ENABLED')
    assert(M:SetOption('utility', 'visibility', 'mouseover') and ItemsOf(utility)[1].alpha == 0, 'Mouseover: faded')
    M.holders.utility.mouseOver = true; Advance(0.2)
    assert(ItemsOf(utility)[1].alpha == 1, 'shows under the mouse')
    M.holders.utility.mouseOver = false; Advance(0.2); assert(ItemsOf(utility)[1].alpha == 0)
    assert(M:SetOption('utility', 'visibility', 'always') and M:SetOption('utility', 'opacity', 50) and ItemsOf(utility)[1].alpha == 0.5, 'Opacity')
    assert(M:SetOption('utility', 'show', false) and ItemsOf(utility)[1].alpha == 0, 'Show Viewer off')
    assert(utility.alpha == nil and not utility.hidden, "Blizzard's viewer frame left alone")
    assert(M:SetOption('utility', 'show', true))

    -- Edit Mode: each viewer that's on shows its stand-in.
    assert(addon:SetEditMode(true) and ModeUICooldownEssential:IsShown() and ModeUICooldownBuffBar:IsShown())
    assert(addon:SetEditMode(false) and not ModeUICooldownEssential:IsShown())

    -- The settings page: Editing, the preview of your spells, the spell menu.
    SlashCmdList.MODEUI()
    addon:SelectConfigPage('cooldownManager')
    local page = M.page
    assert(page and page:IsShown() and page.statusLabel.text:find('On.', 1, true), 'page and status')
    local view = M.previewView
    assert(#view.icons == 5 and view.icons[1].key == '101' and view.icons[1].Icon.texture == 'icon:5001', 'preview: your spells, by cooldown ID')
    assert(M:SetSpellSwitch('essential', '104', 'hide', true))
    assert(view.icons[4].alpha == 0.3 and view.caption.text:find('1 hidden', 1, true), 'hidden spells show faded in the preview')
    view.icons[4].scripts.OnMouseUp(view.icons[4], 'LeftButton')
    local menu = M.spellMenu
    assert(menu:IsShown() and menu.key == '104' and menu.title.text == 'Spell 5004', 'spell menu for the clicked spell')
    menu.showBox.scripts.OnClick(menu.showBox)
    assert(M.db.essential.spells['104'] == nil, 'Show in This Viewer brings it back')
    menu.copy.scripts.OnClick(menu.copy)
    assert(M:SetSpellSwitch('essential', '101', 'ready', false))
    menu.key = '101'; menu.copy.scripts.OnClick(menu.copy); menu.key = '105'
    menu.paste.scripts.OnClick(menu.paste)
    assert(M.db.essential.spells['105'].ready == false, 'Paste copies the switches')
    menu.apply.scripts.OnClick(menu.apply)
    assert(M.db.essential.spells['102'].ready == false and M.db.essential.spells['104'].ready == false, 'Apply to Viewer')
    assert(M:ResetSpells('essential') and next(M.db.essential.spells) == nil, 'Reset All Spells')
    menu:Hide()
    page.SetEditing('buffBar')
    assert(page.viewerEditing() == 'buffBar' and page.textPart() == 'name', 'bars start on the Name text')
    assert(#view.bars == 2 and view.bars[1]:IsShown() and not view.icons[1]:IsShown(), 'bars preview')
    page.SetEditing('essential')
    assert(page.textPart() == 'cooldown')

    -- Copy and reset.
    assert(M:SetOption('essential', 'border', 'square') and M:CopyStyleToAll('essential'))
    assert(M.db.buffBar.border == 'square' and M.db.buffBar.width == 300 and M.db.buffBar.perLine == 1, 'look copied, shape kept')
    assert(M:ResetViewer('buffBar') and M.db.buffBar.border == 'rounded' and M.db.buffBar.width == 300, 'reset keeps its size')

    -- Nothing was written on Blizzard's frames from ModeUI's files.
    assert(#blizzardWrites == 0, 'wrote to Blizzard frames: ' .. table.concat(blizzardWrites, ', '))

    -- Switching off: icons back to full, glows off, a reload for the look.
    assert(M:SetOption('essential', 'opacity', 60) and M:SetSpellSwitch('essential', '105', 'hide', true))
    assert(ItemsOf(essential)[5].alpha == 0)
    addon:SetModuleEnabled('cooldownManager', false)
    assert(ItemsOf(essential)[1].alpha == 1 and addon.ReloadManager:IsPending(), 'full icons; reload offered for the look')
    assert(ItemsOf(essential)[5].alpha == 1 and ItemsOf(essential)[5].motion == true, 'a hidden spell shows again while off')
    essential:RefreshLayout()
    assert(Point(ItemsOf(essential)[2])[2] == essential, "Blizzard's own layout again")
    addon:SetModuleEnabled('cooldownManager', true)
    assert(Point(ItemsOf(essential)[2])[2] == holder and not addon.ReloadManager:IsPending(), 'back on without a reload')
    assert(#blizzardWrites == 0, 'wrote to Blizzard frames: ' .. table.concat(blizzardWrites, ', '))
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
    cvarOn = false
    assert(M:Status():find('Cooldown Manager', 1, true), 'tells you to turn the game option on')
]==], "late load")

local restored = H.Load({ before = STUBS .. "\nMakeViewers()", saved = world.saved() })
restored.run([==[
    local M = addon.CooldownManager
    assert(M.enabled and M.db.essential.perLine == 3 and M.db.buffBar.width == 300 and M.db.essential.border == 'square', 'settings persist')
    assert(Point(ItemsOf(EssentialCooldownViewer)[1])[2] == M.holders.essential)
]==], "restore")

-- Bad saved data stops startup rather than being reset.
for _, bad in ipairs({ { "width", 500 }, { "spells", { ["abc"] = { hide = true } } }, { "spells", { ["12"] = { proc = true } } } }) do
    local saved = restored.saved()
    saved.profiles.Default.modules.cooldownManager.essential[bad[1]] = bad[2]
    local ok = pcall(H.Load, { before = STUBS, saved = saved })
    assert(not ok, "invalid cooldown manager settings are refused: " .. bad[1])
end

print("cooldown manager: all checks passed")
