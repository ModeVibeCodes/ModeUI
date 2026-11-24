-- ModeCDM's Swing Timer (SwingInit.lua, SwingTimer.lua, SwingSettings.lua;
-- Forever only): built only where the client has C_SwingTimer; a swing fills
-- its lane over the swing's duration; the off-hand lane while it swings; the
-- out-of-range tint; the list row, page and Bar Style follow; Edit Mode's
-- sample; refusals; and nothing at all on a client without the API.
-- Simulated client; not WoW rendering, security or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local BASE = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/cooldown_manager_stubs.lua")
local SWING = [[
    rangeChecks = {}
    C_SwingTimer = {
        EnableRangeCheck = function(kind, on) rangeChecks[kind] = on end,
        IsTargetWithinSwingRange = function() return true end,
    }
]]

local world = H.Load({ before = BASE .. SWING .. "\nMakeViewers()" })
world.run([==[
    local M, Tone, Same = addon.CooldownManager, addon.Style.Tone, addon.Style.SameColor
    assert(M.caps.swingTimer and M.db.swing and M.db.swing.follow.border and M.db.swing.follow.text, 'the client has it; it follows the Bar Style')
    addon:SetModuleEnabled('cooldownManager', true)
    local frame, mover = M.swingFrame, ModeUISwingTimer
    assert(frame and mover and addon.PositionManager:GetPosition('cooldownManagerSwingTimer').target == 'cooldownManagerResourceHealth', 'built, under the resource bars')
    assert(rangeChecks[0] == true and rangeChecks[2] == true, 'range checks on for the main hand and ranged')
    assert(frame:GetAlpha() == 0, 'nothing while not swinging')
    -- A main-hand swing fills its lane over its duration.
    FireEvent('PLAYER_SWING', 2, 0)
    assert(frame:GetAlpha() == 1 and M:SwingLanes() == 1, 'shows while swinging; one lane')
    Advance(1)
    assert(math.abs(frame.lanes[1].bar.value - 0.5) < 0.01, 'half way after one of two seconds')
    -- /mcdm check reports it for the in-game look.
    assert(M:CapsReport()[2]:find("a plain number", 1, true), "the report says the duration was readable")
    SlashCmdList.MODEUICDM("check")
    -- The off hand gets its own lane.
    FireEvent('PLAYER_SWING', 1.5, 1)
    assert(M:SwingLanes() == 2 and frame.lanes[2]:IsShown() and mover:GetHeight() > frame.lanes[1]:GetHeight() * 2, 'two lanes')
    -- Out of range: the fill turns Rosewood.
    FireEvent('PLAYER_SWING_RANGE_UPDATE', 0, false, true)
    Advance(0.1)
    local fill = frame.lanes[1].bar:GetStatusBarTexture()
    assert(fill.vertexColor and math.abs(fill.vertexColor[1] - Tone.rosewood[1]) < 0.01, 'out of range')
    FireEvent('PLAYER_SWING_RANGE_UPDATE', 0, true, true)
    -- A duration that isn't a plain number leaves the lane full.
    FireEvent('PLAYER_SWING', nil, 0); Advance(0.1)
    assert(frame.lanes[1].bar.value == 1, 'no duration: full')
    Advance(10)
    assert(frame:GetAlpha() == 0, 'fades once the swings stop')
    -- Edit Mode: the stand-in with a sample.
    assert(addon:SetEditMode(true) and mover:IsShown() and M.swingSample and frame:GetAlpha() == 1, 'a sample in Edit Mode')
    assert(addon:SetEditMode(false) and not mover:IsShown() and not M.swingSample)
    -- Settings: a border value makes it its own; the Bar Style brings it back.
    assert(M:SetSwingOption('edgeSize', 2) and not M:PlayerFollows('swing', 'border'))
    assert(M:FollowPlayerGroup('swing', 'border', true) and M.db.swing.edgeSize == 1, 'back on the Bar Style')
    assert(M:SetSwingOption('timerShow', true) and M:SetSwingOption('offHand', false) and not M:SetSwingOption('height', 99), 'its own settings; a bad one refused')
    assert(M:SetSwingOption('show', false) and M:ResetSwing() and not M.db.swing.show and M.db.swing.timerShow == false, 'reset keeps Show Bar')
    assert(M:SetSwingOption('show', true))
    -- The window: Swing Timer under Player Bars, its page.
    SlashCmdList.MODEUICDM()
    local window = ModeUICooldownManagerWindow
    local row
    for _, r in ipairs(window.rows) do if r:IsShown() and r.kind == 'swing' then row = r end end
    assert(row and row.label.text == 'Swing Timer', 'listed under Player Bars')
    row.scripts.OnClick(row)
    local page = M.swingPage
    assert(page and page:IsShown() and M:EditingValue() == 'swing' and page.swingToggles and page.styleChips.border, 'its page')
    assert(#page.indexButtons == 4 and page.indexButtons[1].label.text == 'Layout', 'one scroll with an index')
    window:Hide()
]==], "swing timer")

-- Bad data stops startup rather than being reset.
local function Refused(change, label)
    local saved = world.saved()
    change(saved.profiles.Default.modules.cooldownManager)
    assert(not pcall(H.Load, { before = BASE .. SWING, saved = saved }), "invalid swing timer settings are refused: " .. label)
end
Refused(function(db) db.swing.height = 99 end, "height")
Refused(function(db) db.swing.barColorMode = "rainbow" end, "a choice")
Refused(function(db) db.swing.follow = { size = true } end, "a follow group")

-- A client without the API: the settings stay, nothing is built or listed.
H.Load({ before = BASE .. "\nMakeViewers()", saved = world.saved() }).run([==[
    local M = addon.CooldownManager
    assert(not M.caps.swingTimer and M.db.swing ~= nil, 'settings kept')
    addon:SetModuleEnabled('cooldownManager', true)
    assert(M.swingFrame == nil and ModeUISwingTimer == nil and not M:SelectSwing(), 'nothing built, nothing to pick')
    SlashCmdList.MODEUICDM()
    for _, row in ipairs(ModeUICooldownManagerWindow.rows) do assert(not (row:IsShown() and row.kind == 'swing'), 'not listed') end
]==], "no swing timer")
print("cdm swing: ok")
