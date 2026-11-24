-- The Bar Style (ModeCDM BarStyle.lua, BarStyleOptions.lua): a new profile
-- follows it everywhere, a change reaches every bar that follows, editing a
-- followed value makes that group the bar's own, following again, the
-- resource bars and the Cast Bar, presets, new bars, reset, Copy Look To,
-- refusals, and the version 11 -> 12 step (border and text take the Bar
-- Style, a None border stays off, other groups follow only where they match).
-- Simulated client; not WoW rendering, security or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/cooldown_manager_stubs.lua")

local world = H.Load({ before = STUBS .. "\nMakeViewers()" })
world.run([==[
    local M, Tone, Same = addon.CooldownManager, addon.Style.Tone, addon.Style.SameColor
    local bs = M.db.barStyle
    -- The owner's Bar Style (November 24, 2026).
    assert(bs.largeWidth == 38 and bs.largeHeight == 30 and bs.smallWidth == 32 and bs.smallHeight == 26 and bs.spacing == -1, 'sizes and spacing')
    assert(bs.edgeStyle == 'obsidian' and bs.edgeMetal == 'gunmetal' and bs.outline and bs.procGlow == 'mode' and Same(bs.procColor, Tone.brand)
        and Same(bs.cooldownColor, Tone.cooldown), 'Mode-Border in Gunmetal, amber outlined numbers, gold Mode Glow procs')
    -- A new profile follows it everywhere.
    for _, id in ipairs({ 'essential', 'utility', 'buffIcon' }) do
        for _, group in ipairs(M:StyleGroups(id)) do assert(M:Follows(id, group), id .. ' follows ' .. group) end
    end
    assert(M:Follows('buffBar', 'fill') and M:Follows('buffBar', 'size') and not M:Follows('buffBar', 'cooldown'), 'Tracked Bars: their own groups')
    local ultra = M.PresetBar(M.db, 'ultra').id
    assert(not M:Follows(ultra, 'size') and M:Follows(ultra, 'text') and M.db[ultra].width == 54, 'a default bar keeps its own size')
    assert(M.db[ultra].cooldownSize == 22 and M.db[ultra].countSize == 18 and M.db.buffIcon.cooldownSize == 12, 'text scales with the icon')
    assert(M.db.resources.power.follow.border and M.db.castBar.follow.text and M.db.castBar.outline and M.db.castBar.edgeMetal == 'gunmetal', 'player bars too')

    addon:SetModuleEnabled('cooldownManager', true)
    -- A change reaches every bar that follows it.
    assert(M:SetBarStyle('largeHeight', 32) and M.db.essential.height == 32 and M.db.utility.height == 32 and M.db.buffIcon.height == 26, 'a size')
    assert(M.db.essential.cooldownSize == 14, 'the numbers keep their size at the new reference height')
    assert(M:SetBarStyle('edgeMetal', 'silver') and M.db[M.PresetBar(M.db, 'defensives').id].edgeMetal == 'silver'
        and M.db.resources.power.edgeMetal == 'silver' and M.db.castBar.edgeMetal == 'silver', 'a metal, to every border that follows')
    -- Editing a followed value makes that group the bar's own.
    assert(M:SetOption('essential', 'edgeSize', 2) and not M:Follows('essential', 'border') and M:Follows('essential', 'text'), 'Border is Custom')
    assert(M:SetBarStyle('edgeSize', 1) and M.db.essential.edgeSize == 2 and M.db.utility.edgeSize == 1, 'a Custom group keeps its own')
    assert(M:CustomGroups('essential') == 1, 'one group custom')
    assert(M:FollowGroup('essential', 'border', true) and M.db.essential.edgeSize == 1 and M.db.essential.edgeMetal == 'silver', 'back to the Bar Style')
    assert(not M:FollowGroup('buffBar', 'cooldown', true), 'only a group the bar has')
    -- A size of its own; the text follows the new height.
    assert(M:SetOption('essential', 'height', 40) and not M:Follows('essential', 'size') and M.db.essential.cooldownSize == 18, 'numbers scale to 40 tall')
    assert(M:UseBarStyle('essential') and M.db.essential.height == 32 and M:CustomGroups('essential') == 0, 'Use Bar Style: every group again')
    -- The resource bars and the Cast Bar.
    assert(M:SetResourceOption('power', 'outline', false) and not M:PlayerFollows('power', 'text') and M:PlayerFollows('power', 'border'))
    assert(M:FollowPlayerGroup('power', 'text', true) and M.db.resources.power.outline, 'its text back to the Bar Style')
    assert(M:SetCastOption('edgeSize', 2) and not M:PlayerFollows('cast', 'border') and M:ResetCast() and M:PlayerFollows('cast', 'border'), 'reset follows again')
    -- Presets.
    assert(M:ApplyBarStylePreset('compact') and M.db.barStyle.largeHeight == 26 and M.db.essential.height == 26 and M:BarStylePreset() == 'compact')
    assert(M:ApplyBarStylePreset('mode') and M.db.essential.height == 30 and M.db.essential.edgeMetal == 'gunmetal' and M:BarStylePreset() == 'mode')
    -- A new bar follows; Reset to Defaults goes back to the Bar Style.
    local id = M:AddCustomBar('buff')
    assert(M:Follows(id, 'size') and M.db[id].width == 32 and M.db[id].height == 26 and M.db[id].spacing == -1, 'a new Buff Bar: Small, in the Bar Style')
    assert(M:SetOption(id, 'edgeSize', 2) and M:ResetViewer(id) and M:Follows(id, 'border') and M.db[id].edgeSize == 1, 'reset')
    -- Copy Look To keeps the target's own size.
    assert(M:SetOption('utility', 'width', 50) and M:CopyStyleTo('essential', { utility = true }) and M.db.utility.width == 50 and not M:Follows('utility', 'size'))
    assert(M:UseBarStyleEverywhere() and M.db.utility.width == 38 and M:CustomGroups('essential') == 0, 'every bar back to the Bar Style')
    -- Refusals.
    assert(not M:SetBarStyle('largeWidth', 500) and not M:SetBarStyle('edgeStyle', 'bogus') and not M:SetBarStyle('nope', 1), 'bad values refused')
    assert(M.db.barStyle.largeWidth == 38, 'nothing kept from a refused change')
]==], "bar style")

-- Version 11 -> 12 on an existing profile: the border and text take the Bar
-- Style; a None border stays off; everything else follows only where it
-- already matches, so nothing else changes on screen.
local saved = world.saved()
local db = saved.profiles.Default.modules.cooldownManager
db.version, db.barStyle = 11, nil
local function Strip(style) if type(style) == "table" then style.follow = nil end end
for _, value in pairs(db) do Strip(value) end
for _, style in pairs(db.resources) do Strip(style) end
local E, U = db.essential, db.utility
E.width, E.height, E.spacing, E.edgeStyle, E.edgeMetal, E.outline, E.cooldownSize = 40, 34, 2, 'obsidianEmpty', 'default', false, 13
E.cooldownColor = { 1, 57 / 255, 72 / 255 }
U.border, U.width, U.height = 'none', 38, 30
db.resources.health.border = 'none'
H.Load({ before = STUBS .. "\nMakeViewers()", saved = saved }).run([==[
    local M, Tone, Same = addon.CooldownManager, addon.Style.Tone, addon.Style.SameColor
    local E, U = M.db.essential, M.db.utility
    assert(M.db.version == 12 and M.db.barStyle.edgeMetal == 'gunmetal', 'version 12, the Bar Style')
    assert(E.follow.border and E.edgeStyle == 'obsidian' and E.edgeMetal == 'gunmetal', 'the border takes the Bar Style')
    assert(E.follow.text and E.outline and Same(E.cooldownColor, Tone.cooldown) and E.cooldownSize == 16, 'the text too, scaled to 34 tall')
    assert(not E.follow.size and E.width == 40 and E.height == 34 and E.spacing == 2, 'its own size stays')
    assert(E.follow.background and E.follow.cooldown, 'matching groups follow')
    assert(not U.follow.border and U.border == 'none', 'a border set to None stays off')
    assert(U.follow.size and U.width == 38, 'a size that matches the Bar Style follows it')
    local health, power = M.db.resources.health, M.db.resources.power
    assert(not health.follow.border and health.border == 'none' and power.follow.border and power.follow.text and power.outline, 'player bars')
]==], "version 12")

-- Bad Bar Style data stops startup rather than being reset.
local function Refused(change, label)
    local bad = world.saved()
    change(bad.profiles.Default.modules.cooldownManager)
    assert(not pcall(H.Load, { before = STUBS, saved = bad }), "invalid Bar Style settings are refused: " .. label)
end
Refused(function(cdm) cdm.barStyle.largeWidth = 400 end, "a size")
Refused(function(cdm) cdm.barStyle.edgeMetal = "bronze" end, "a metal")
Refused(function(cdm) cdm.barStyle = "plain" end, "the table")
Refused(function(cdm) cdm.essential.follow = { bogus = true } end, "a follow group")
Refused(function(cdm) cdm.buffBar.follow = { cooldown = true } end, "a group Tracked Bars don't have")
Refused(function(cdm) cdm.essential.follow = { border = "yes" } end, "a follow value")
print("cdm bar style: ok")
