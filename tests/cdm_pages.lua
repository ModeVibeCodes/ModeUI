-- ModeCDM's window after the November 24, 2026 rework: it opens on Home; the
-- Bar Style page; a bar's one scrolling page with its section index, Bar
-- Style chips, More options folds and spell list; the Layout view (Stage)
-- and the Bar view; Test on Screen; the show rules (mounted, vehicle, group,
-- instance, Dim Instead of Hide).
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

    -- The Bar Style page: the Layout view of every bar, its presets.
    window.rows[2].scripts.OnClick(window.rows[2])
    local style = M.stylePage
    assert(style and style:IsShown() and not home:IsShown() and M:EditingValue() == 'style', 'the Bar Style page')
    assert(M.stylePreview.stage and M.stylePreview.stage:IsShown() and M.stylePreview.stage.bars >= 5, 'every bar in place')
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
    -- The Layout view: every bar, this one outlined; a click edits another.
    local stage = M.previewView.stage
    assert(M.previewMode == 'layout' and stage:IsShown() and stage.outline[1]:IsShown(), 'the bar being edited is outlined')
    local target
    for _, hit in ipairs(stage.hits) do if hit:IsShown() and hit.item.id == 'utility' then target = hit end end
    assert(target, 'Utility on the stage')
    target.scripts.OnClick(target)
    assert(page.viewerEditing() == 'utility' and M.selectedBar == 'utility', 'clicking a bar edits it')
    page.barViewButton.scripts.OnClick(page.barViewButton)
    assert(not stage:IsShown() and M.previewView.icons[1]:IsShown(), 'the Bar view: this bar alone')
    page.layoutViewButton.scripts.OnClick(page.layoutViewButton)
    assert(stage:IsShown(), 'and the Layout view again')

    -- Test on Screen: samples on the real bars; combat stops it.
    window.testButton.scripts.OnClick(window.testButton)
    assert(M.testDisplay and M.testSamples.essential[1]:IsShown() and M.testSamples.essential[1]:GetParent() == M.testHost, 'samples in place')
    assert(window.testButton.selected, 'the button shows it is on')
    testCombat = true; FireEvent('PLAYER_REGEN_DISABLED')
    assert(not M.testDisplay and not M.testHost:IsShown(), 'combat stops it')
    testCombat = false; FireEvent('PLAYER_REGEN_ENABLED')
    assert(not M:SetTestDisplay(false) and not M.testDisplay)

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
