-- ModeCDM's window after the November 24, 2026 rework: it opens on Home; the
-- Bar Style page; a bar's one scrolling page with its section index, Bar
-- Style chips, More options folds and spell list; previews of only what a
-- page edits (the Bar Style's samples, the bar alone with its + slot);
-- + Add Spell; Test on Screen and every way to stop it; the show rules
-- (mounted, vehicle, group, instance, Dim Instead of Hide).
-- Simulated client; not WoW rendering, security or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/cooldown_manager_stubs.lua") .. [[
    testMounted, testGrouped = false, false
    IsMounted = function() return testMounted end
    IsInGroup = function() return testGrouped end
    UnitInVehicle = function() return false end
    IsInInstance = function() return false, "none" end
]]

local world = H.Load({ before = STUBS .. "\nMakeViewers()" })
world.run([==[
    local M = addon.CooldownManager
    addon:SetModuleEnabled('cooldownManager', true)
    SlashCmdList.MODEUICDM()
    local window = ModeUICooldownManagerWindow

    -- Home: the status, the Bar Style and its presets, the bars, Racial Abilities.
    local home = M.homePage
    assert(home and home:IsShown() and M:EditingValue() == 'home' and window.rows[1].selected, 'opens on Home')
    assert(home.homeStatus.text ~= '' and home.racialsSelect and home.homeTrackedButton, 'status, Racial Abilities, Tracked Spells')
    assert(home.homeCounts.text:find('have a look of their own', 1, true) and not home.homeUseEverywhere:IsEnabled(), 'every bar follows the Bar Style')
    assert(window.cdmButton.label.text == 'Tracked Spells' and window.testButton:IsEnabled(), 'the header')

    assert(home.homeScreen and home.homeScreen.text ~= '', 'the Screen line')
    -- 1440p: pixel perfect at 53.33%; at 64% it isn't, and says what is.
    local oldUtil, oldSize = PixelUtil, GetPhysicalScreenSize
    PixelUtil = { GetPixelToUIUnitFactor = function() return 768 / 1440 end }
    GetPhysicalScreenSize = function() return 2560, 1440 end
    UIParent:SetScale(768 / 1440)
    assert(M:ScreenStatus():find('2560 x 1440 at UI scale 53.33%: pixel perfect', 1, true), '1440p, pixel perfect')
    UIParent:SetScale(0.64)
    assert(M:ScreenStatus():find('UI scale 64.00% (pixel perfect here is 53.33%)', 1, true), '1440p at 64%')
    UIParent:SetScale(768 / 1080)
    assert(M:ScreenStatus():find('UI scale 71.11%: the 1080p size', 1, true), "1440p at ModeUI's 1080p Size")
    PixelUtil = { GetPixelToUIUnitFactor = function() return 768 / 1080 end }
    GetPhysicalScreenSize = function() return 1920, 1080 end
    UIParent:SetScale(768 / 1080)
    assert(M:ScreenStatus():find('1920 x 1080 at UI scale 71.11%: pixel perfect', 1, true), '1080p, pixel perfect')
    PixelUtil, GetPhysicalScreenSize = oldUtil, oldSize
    UIParent:SetScale(1)

    -- The Bar Style page: the Bar Style on sample icons and a bar, its presets.
    window.rows[2].scripts.OnClick(window.rows[2])
    local style = M.stylePage
    assert(style and style:IsShown() and not home:IsShown() and M:EditingValue() == 'style', 'the Bar Style page')
    local lines = M.stylePreview.lines
    assert(#lines == 3 and lines[1].samples[6]:IsShown() and lines[2].samples[6]:IsShown() and lines[3].samples[1]:IsShown(), 'Large, Small and a bar')
    assert(lines[1].samples[1].width == 38 and lines[1].samples[1].height == 30 and lines[2].samples[1].height == 26, 'at the Bar Style sizes')
    assert(M:SetBarStyle('largeHeight', 32) and lines[1].samples[1].height == 32, 'a change shows at once')
    assert(M:SetBarStyle('largeHeight', 30))
    assert(#style.indexButtons == 8 and style.indexButtons[1].label.text == 'Presets', 'its section index')
    style.presetButtons[2].scripts.OnClick(style.presetButtons[2])
    assert(M:BarStylePreset() == 'compact' and M.db.essential.height == 26, 'a preset from the page')
    assert(M:ApplyBarStylePreset('mode') and M.db.essential.height == 30)

    -- A bar's page: one scroll, its section index.
    window.rows[3].scripts.OnClick(window.rows[3])
    local page = M.page
    assert(page:IsShown() and page.viewerEditing() == 'essential' and #page.indexButtons == 5, 'Layout, Look, Text, Spells & Glows, Show')
    assert(page.indexButtons[4].label.text == 'Spells & Glows' and page.sectionTabs == nil, 'sections in one scroll, no tabs')
    page.indexButtons[2].scripts.OnClick(page.indexButtons[2])
    assert(page.indexButtons[2].selected and not page.indexButtons[1].selected, 'the index jumps to Look')
    -- The Bar Style chip: Border follows; the chip makes it the bar's own, showing its controls.
    local chip = page.styleChips.border
    local function PickerRow()
        for _, row in ipairs(page.rows) do if row.settingsTitles and row.settingsTitles[1] == 'Border Style' then return row end end
    end
    assert(chip.label.text:find('Bar Style', 1, true) and not PickerRow().visibleWhen(), 'following: the Bar Style sets the border')
    chip.scripts.OnClick(chip)
    assert(not M:Follows('essential', 'border') and chip.label.text:find('Custom', 1, true) and PickerRow().visibleWhen(), 'Custom: its controls show')
    assert(page.useStyleButton:IsShown() and page.useStyleButton.label.text == 'Use Bar Style (1)', 'Use Bar Style in the preview corner')
    page.useStyleButton.scripts.OnClick(page.useStyleButton)
    assert(M:Follows('essential', 'border') and not page.useStyleButton:IsShown(), 'back on the Bar Style')
    -- More options: the rarely changed ones fold away.
    local more = page.moreButtons.cooldown
    local function EdgeRow()
        for _, row in ipairs(page.rows) do
            for _, cell in ipairs(row.toggleCells or {}) do if cell.label and cell.label.text == 'Swipe Edge' then return row end end
        end
        return page.cooldownToggles and page.cooldownToggles.row
    end
    assert(more.label.text:find('More options', 1, true) and not page.moreOpen.cooldown, 'folded')
    more.scripts.OnClick(more)
    assert(page.moreOpen.cooldown and more.label.text == 'Fewer options', 'open')
    more.scripts.OnClick(more)
    -- The spell list: a row per spell; Show hides one here.
    local list = page.spellList
    local entries = M:PreviewEntries('essential')
    assert(list.count == #entries and list.lines[1]:IsShown() and list.lines[1].key == entries[1].key, 'a row per spell, in order')
    local line = list.lines[1]
    line.show.scripts.OnClick(line.show)
    assert(M:SpellSwitch('essential', entries[1].key, 'hide'), 'Show off hides it on this bar')
    list.lines[1].show.scripts.OnClick(list.lines[1].show)
    assert(not M:SpellSwitch('essential', entries[1].key, 'hide'), 'and back')
    local proc = list.lines[1].glows[1]
    assert(proc:IsShown() and proc.kind == 'proc', 'a switch per glow the bar has')
    proc.scripts.OnClick(proc)
    assert(M:SpellSwitch('essential', entries[1].key, 'proc') and M:SpellGlow('essential', entries[1].key, 'proc').style == 'mode', 'the glow on, in the Starting Glow Look')
    -- The preview: this bar alone, its spells then the + slot.
    local view = M.previewView
    assert(page.layoutViewButton == nil and view.stage == nil, 'no view of every bar')
    assert(view.icons[1]:IsShown() and view.icons[1].key == entries[1].key and view.plus:IsShown(), 'this bar alone, with +')
    -- + Add Spell opens the same list as the + slot.
    local add = page.addSpellButton
    assert(add.label.text == '+ Add Spell' and add:IsEnabled(), '+ Add Spell on Spells & Glows')
    add.scripts.OnClick(add)
    assert(M.picker and M.picker:IsShown() and M.picker.barId == 'essential' and M.picker.opener == add, 'the list, from the button')
    add.scripts.OnClick(add)
    assert(not M.picker:IsShown(), 'a second click closes it')
    view.plus.scripts.OnMouseUp(view.plus, 'LeftButton')
    assert(M.picker:IsShown() and M.picker.opener == view.plus, 'and from the + slot')
    M.picker:Hide()
    M:SelectBar('buffIcon')
    assert(add.label.text == '+ Add in Tracked Spells', 'Tracked Buffs: Blizzard decides')
    M:SelectBar('essential')

    -- Test on Screen: samples on the real bars; the button says Stop Test;
    -- the bar on screen stops it; combat stops it.
    window.testButton.scripts.OnClick(window.testButton)
    assert(M.testDisplay and M.testSamples.essential[1]:IsShown() and M.testSamples.essential[1]:GetParent() == M.testHost, 'samples in place')
    assert(window.testButton.selected and window.testButton.label.text == 'Stop Test', 'the button shows it is on, and stops it')
    assert(M.testBanner:IsShown() and M.testBanner.stop.label.text == 'Stop Test', 'a Stop Test bar on screen')
    assert(page.testDisplayButton.selected and page.testDisplayButton.label.text == 'Stop Test' and view.icons[1]:IsShown(), 'the preview button too; the preview stays')
    M.testBanner.stop.scripts.OnClick(M.testBanner.stop)
    assert(not M.testDisplay and not M.testHost:IsShown() and window.testButton.label.text == 'Test on Screen', 'Stop Test stops it')
    -- Started from another page's preview (a proxy of the module), the
    -- module still holds it: closing the window stops it.
    M:SelectCast()
    M.castPage.testDisplayButton.scripts.OnClick(M.castPage.testDisplayButton)
    assert(M.testDisplay and M.testing and M.castPage.testDisplayButton.selected, 'the Cast Bar preview button')
    window:Hide()
    assert(not M.testDisplay and not M.testing and not M.testHost:IsShown(), 'closing the window stops it')
    SlashCmdList.MODEUICDM(); M:SelectBar('essential')
    -- Switching the module off stops it.
    M:SetTestDisplay(true)
    addon:SetModuleEnabled('cooldownManager', false)
    assert(not M.testDisplay and not M.testHost:IsShown(), 'the module off stops it')
    addon:SetModuleEnabled('cooldownManager', true)
    window.testButton.scripts.OnClick(window.testButton)
    assert(M.testDisplay, 'on again')
    testCombat = true; FireEvent('PLAYER_REGEN_DISABLED')
    assert(not M.testDisplay and not M.testHost:IsShown(), 'combat stops it')
    testCombat = false; FireEvent('PLAYER_REGEN_ENABLED')
    assert(not M:SetTestDisplay(false) and not M.testDisplay)

    -- Every UI scale: a negative Spacing counts physical pixels (one shared
    -- shadow pixel at -1), sizes round to whole pixels.
    for _, px in ipairs({ 1, 768 / 1440, 768 / 1080, 0.8 }) do
        local g = M.Geometry({ width = 38, height = 30, spacing = -1, perLine = 2, grow = 'right', lineGrowth = 'down', border = 'mode', edgeSize = 1 }, 2, px)
        local step = g.points[2][2] - g.points[1][2]
        assert(math.abs(step - (g.sizes[1][1] + 2 * g.reach - px)) < 1e-6, 'one shared shadow pixel at ' .. px)
        assert(math.abs(g.w / px - math.floor(g.w / px + 0.5)) < 1e-6, 'whole pixels at ' .. px)
    end
    -- The icons' holder sits on whole pixels when its stand-in doesn't.
    local holder, mover = M.holders.essential, _G[M.FrameName('essential')]
    local cx, cy = mover:GetCenter()
    mover.centerX, mover.centerY = cx + 0.3, cy + 0.6
    M:LayoutViewer('essential')
    local function Whole(v) return math.abs(v - math.floor(v + 0.5)) < 1e-6 end
    assert(Whole(holder:GetLeft()) and Whole(holder:GetBottom()) and holder.snapX ~= 0, 'the holder on whole pixels')
    mover.centerX, mover.centerY = cx, cy
    M:LayoutViewer('essential')
    assert(math.abs(holder.snapX) < 1e-9, 'back on the stand-in')

    -- Show rules: hidden while mounted; outside a group; Dim Instead of Hide.
    local item = ItemsOf(EssentialCooldownViewer)[1]
    assert(M:SetOption('essential', 'hideMounted', true))
    testMounted = true; FireEvent('PLAYER_MOUNT_DISPLAY_CHANGED')
    assert(item.alpha == 0, 'hidden while mounted')
    assert(M:SetOption('essential', 'fadeOpacity', 30) and M:SetOption('essential', 'dim', true) and math.abs(item.alpha - 0.3) < 0.001, 'dimmed instead')
    testMounted = false; FireEvent('PLAYER_MOUNT_DISPLAY_CHANGED')
    assert(item.alpha == 1, 'back on the ground')
    assert(M:SetOption('essential', 'onlyInGroup', true) and math.abs(item.alpha - 0.3) < 0.001, 'alone: dimmed')
    testGrouped = true; FireEvent('GROUP_ROSTER_UPDATE')
    assert(item.alpha == 1, 'in a group')
    assert(page.showRuleToggles, 'the rules on the Show section')
    -- The Cast Bar has Show When too.
    assert(M:SetCastOption("visibility", "combat") and M:CastAlpha() == 0, "the Cast Bar: in combat only")
    assert(M:SetCastOption("visibility", "always") and M:CastAlpha() == 1)
    -- Copy Look To leaves the show rules alone.
    assert(M:CopyStyleTo('essential', { utility = true }) and not M.db.utility.onlyInGroup, 'show rules are the bar its own')
    window:Hide()
    assert(not M.testDisplay and M.selectedView == nil, 'closing resets to Home next time')
]==], "cdm pages")
print("cdm pages: ok")
