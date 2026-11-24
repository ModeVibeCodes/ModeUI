-- Cooldown Manager: what you track in Blizzard's Cooldown Manager, read
-- from its Cooldown Settings (Domain.Cooldowns.Layout, Tracking.lua):
-- Blizzard's cache only while up to date, else worked out from the game's
-- sets and your layout for this spec, never rebuilt by ModeUI; the preview
-- filling each viewer from it while Blizzard's viewer has no frames (every
-- tracked buff on Tracked Buffs), in full color; the + slot's list counting
-- it as tracked (information only without a frame); and the NOT TRACKED
-- warning in tooltips and the spell menu.
-- Simulated client; not WoW rendering, security or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/cooldown_manager_stubs.lua")

local world = H.Load({ before = STUBS .. "\nMakeViewers()" })
world.run([==[
    local WARNING = "Not tracked by Blizzard's Cooldown Manager. Track it there to show it."
    local CD, M = addon.Domain.Cooldowns, addon.CooldownManager
    local function Has(lines, text)
        for _, line in ipairs(lines) do if line:find(text, 1, true) then return true end end
        return false
    end

    -- No data provider: the game's sets, without what's hidden by default.
    local layout = CD.Layout()
    assert(#layout.Essential == 5 and layout.Essential[1] == 101 and layout.category[106] == nil, 'Essential, without 106 (hidden by default)')
    assert(#layout.TrackedBuff == 2 and layout.category[303] == nil and layout.category[401] == 'TrackedBar', 'buffs and bars')

    -- Your layout for this spec: 302 first, 303 tracked, 202 Not Displayed.
    local tag = 'warrior-1'
    CooldownViewerUtil = { GetCurrentClassAndSpecTag = function() return tag end }
    local mine = { classAndSpecTag = 'warrior-1', orderedCooldownIDs = { 302, 999, 301, 303 },
        cooldownInfo = { [303] = { category = 2 }, [202] = { category = -1 } } }
    local manager = { IsLoaded = function() return true end, GetActiveLayout = function(_, mode) assert(mode == nil, 'never asks to create one'); return mine end }
    local provider = { IsDirty = function() return true end, GetDisplayData = function() error('the cache is never read while out of date') end,
        GetOrderedCooldownIDsForCategory = function() error('ModeUI never makes Blizzard rebuild') end,
        GetOrderedCooldownIDs = function() error('ModeUI never makes Blizzard rebuild') end }
    CooldownViewerSettings.GetDataProvider = function() return provider end
    CooldownViewerSettings.GetLayoutManager = function() return manager end
    layout = CD.Layout()
    assert(layout.TrackedBuff[1] == 302 and layout.TrackedBuff[2] == 301 and layout.TrackedBuff[3] == 303 and #layout.TrackedBuff == 3,
        'your order and your move; an ID the game no longer has is dropped')
    assert(layout.category[202] == nil and #layout.Utility == 1 and layout.Essential[5] == 105, 'Not Displayed leaves its viewer')
    tag = 'warrior-2'
    layout = CD.Layout()
    assert(layout.category[303] == nil and layout.category[202] == 'Utility', "another spec's layout is ignored")
    tag = 'warrior-1'

    -- Up to date: Blizzard's own cache, learned spells only in the lists.
    local cache = { orderedCooldownIDs = { 401, 101, 302 }, cooldownInfoByID = { [401] = { category = 3, isKnown = true },
        [101] = { category = 0, isKnown = false }, [302] = { category = -2, isKnown = true } } }
    provider.IsDirty = function() return false end
    provider.GetDisplayData = function() return cache end
    layout = CD.Layout()
    assert(layout.TrackedBar[1] == 401 and #layout.Essential == 0 and layout.category[101] == 'Essential' and layout.category[302] == nil, 'the cache')
    provider.IsDirty = function() return true end
    provider.GetDisplayData = function() error('the cache is never read while out of date') end

    -- Blizzard's Tracked Buffs viewer hidden: no frames, yet the preview
    -- shows every buff your setup tracks, in full color.
    addon:SetModuleEnabled('cooldownManager', true)
    SlashCmdList.MODEUICDM()
    -- The Bar view: this bar alone, its spells to point at.
    M.previewMode = "bar"
    BuffIconCooldownViewer.itemFramePool:ReleaseAll()
    M:SelectBar('buffIcon')
    local view = M.previewView
    local keys = {}
    for i = 1, 3 do keys[i] = view.icons[i]:IsShown() and view.icons[i].key end
    assert(keys[1] == '302' and keys[2] == '301' and keys[3] == '303', 'Tracked Buffs from your setup, in your order')
    assert(not view.icons[1].Icon.desaturated and view.icons[1]:GetAlpha() == 1, 'in full color')
    assert(view.caption.text:find("3 off screen while Blizzard's viewer is hidden", 1, true), 'the caption says why they are off screen')
    view.icons[1].scripts.OnEnter(view.icons[1])
    assert(tooltipLines[1] == 'Spell 7002' and not Has(tooltipLines, WARNING), 'a tracked buff: no warning')

    -- The + slot on a Buff Bar: tracked buffs with no frame are in color,
    -- information only; an untracked one warns in its tooltip.
    local buffBar = M.PresetBar(M.db, 'emphasized').id
    M:SelectBar(buffBar)
    view.plus.scripts.OnMouseUp(view.plus, 'LeftButton')
    local picker = M.picker
    local function Find(key)
        for _, button in ipairs(picker.buttons) do if button:IsShown() and button.key == key then return button end end
    end
    local framed = Find('302')
    assert(framed and not framed.icon.desaturated and framed.add == nil and framed.where:find('in Blizzard CDM', 1, true), 'tracked, no frame: color, information')
    framed.scripts.OnClick(framed)
    assert(#M:Custom(buffBar).entries == 0, 'nothing added')
    -- Hidden by default, and no longer moved to Tracked Buffs in your layout.
    mine.cooldownInfo[303] = nil
    M:RefreshPicker()
    local untracked = Find('303')
    assert(untracked and untracked.icon.desaturated and untracked.untracked, 'not tracked: grayed')
    untracked.scripts.OnEnter(untracked)
    assert(tooltipLines[1] == 'Spell 7003' and Has(tooltipLines, WARNING), 'its tooltip warns')
    untracked.scripts.OnLeave(untracked)
    picker:Hide()

    -- A spell on a bar that Blizzard's CDM stopped tracking: the warning in
    -- its tooltip and at the top of its spell menu; tracked ones have none.
    BuffIconCooldownViewer:RefreshLayout()
    assert(M:AddEntry(buffBar, '301'), 'a tracked buff on the bar')
    -- Not Displayed in Blizzard's settings: its viewer lets the frame go.
    mine.cooldownInfo[301] = { category = -2 }
    BuffIconCooldownViewer.ids = { 302 }; BuffIconCooldownViewer:RefreshLayout()
    M:SelectBar(buffBar)
    local sample = view.icons[1]
    assert(sample.key == '301' and sample.Icon.desaturated, 'not tracked now: grayed')
    sample.scripts.OnEnter(sample)
    assert(Has(tooltipLines, WARNING), 'the preview tooltip warns')
    sample.scripts.OnMouseUp(sample, 'LeftButton')
    local menu = M.spellMenu
    assert(menu:IsShown() and menu.warning:IsShown() and menu.warning.text:find(WARNING, 1, true), 'the spell menu warns')
    menu:Hide()
    mine.cooldownInfo[301] = nil
    M:SelectBar(buffBar)
    view.icons[1].scripts.OnMouseUp(view.icons[1], 'LeftButton')
    assert(menu:IsShown() and not menu.warning:IsShown(), 'tracked again: no warning')
    menu:Hide()
]==], "cooldown tracking")

print("cooldown tracking: all checks passed")
