-- Resource Bars in the Cooldown Manager (/mcdm): defaults, Edit Mode stand-ins
-- with Match Width, the Mode edge and bar textures, power, health and
-- Alternate Mana fills with secret values, combo point boxes, texts, colors,
-- forms, visibility, the window's Resource Bars list and page, the preview,
-- settings checks, reset, switching off, persistence and bad saved data.
-- Simulated client; not WoW rendering, security or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/cooldown_manager_stubs.lua") .. [[
    MakeViewers()
    -- Smooth passes the client's interpolation to SetValue; record it.
    Enum = Enum or {}
    Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }
    local methods = getmetatable(UIParent).__index
    local setValue = methods.SetValue
    function methods:SetValue(v, ease, ...) self.ease = ease; return setValue(self, v, ease, ...) end
]]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, PM, Kit, Power = addon.CooldownManager, addon.PositionManager, addon.Kit, addon.Domain.Power
    local db = M.db.resources
    assert(M.db.version == M.VERSION, 'resource bars need no settings version of their own')
    assert(db.power.show and db.combo.show and db.mana.show and not db.health.show, 'Health starts off')
    assert(db.power.border == 'mode' and db.power.barTexture == 'media:Mode Gradient' and db.power.barBackground == 'media:Mode BG' and db.power.fontMedia == 'Mode', 'the Mode look')
    assert(db.power.barBackgroundOpacity == 60 and db.power.borderColor == nil and not db.power.outline, 'Slate at 60%; one edge color; no outline')
    assert(db.power.matchWidth and db.power.colorMode == 'power' and db.power.text == 'current' and db.combo.text == 'none')
    assert(ModeUIResourcePower == nil, 'nothing built while the module is off')

    addon:SetModuleEnabled('cooldownManager', true)
    local power, combo, mana, health = M.resourceFrames.power, M.resourceFrames.combo, M.resourceFrames.mana, M.resourceFrames.health
    assert(ModeUIResourcePower and ModeUIResourceCombo and ModeUIResourceMana and ModeUIResourceHealth, 'a stand-in per bar')
    assert(PM:GetPosition('cooldownManagerResourcePower').target == 'cooldownManagerUtility', 'Power under Utility')
    assert(PM:GetPosition('cooldownManagerResourceCombo').target == 'cooldownManagerResourcePower', 'Combo Points under Power')
    -- Match Width: Utility's line is 12 icons of 32 with their 2px edges, 2px between.
    assert(ModeUIResourcePower.width == 454 and ModeUIResourcePower.height == 18, 'Power matches the cooldowns above it; its edges inside the stand-in')
    assert(PM:GetSizeMatch('cooldownManagerResourcePower', 'width'), "Edit Mode's Match Width is on")
    assert(power:IsShown() and not ModeUIResourcePower:IsShown(), 'bar shown on its hidden stand-in')

    -- Power: the frameThin edge outside the box, Mode Gradient over Mode BG, no masks.
    local box = power.boxes[1]
    local bar = box.bar
    assert(box.edge.preset == 'frameThin' and box.edge.holder:IsShown() and box.edge.holder.frameLevel > box:GetFrameLevel(), 'the Mode edge')
    assert(Point(box)[4] == 2 and Point(box)[5] == -2 and box.width == 450 and box.height == 14, 'the box inside the edge reach')
    assert(bar.points[1][4] == 0 and bar.points[2][4] == 0, 'the bar fills its box')
    local fill = bar:GetStatusBarTexture()
    assert(not (fill.masks and #fill.masks > 0) and not (bar.bg.masks and #bar.bg.masks > 0), 'no masks')
    assert(bar.sheen:IsShown() and bar.bg.vertexColor[1] == addon.Style.Tone.slate[1] and bar.bg.vertexColor[4] == 0.6, 'Mode Gradient lift; Slate at 60%')
    -- Energy 50 of 100 (units.player), in the energy color, with the current value.
    assert(bar.low == 0 and bar.high == 100 and bar.value == 50 and bar.ease == 1, 'filled, smoothly')
    local energy = Power.colors.ENERGY
    assert(bar.statusBarColor[1] == energy[1] and bar.statusBarColor[4] == 1, 'Power Type color')
    assert(power.text.text == '50' and power.text:IsShown(), 'Current text')
    assert(bar.fillEdge and bar.fillEdge:IsShown(), 'Fill End Line')

    -- Secret power: values go only to the bar and the text setters.
    units.player.power = Secret('p'); units.player.powerMax = Secret('pm')
    FireEvent('UNIT_POWER_FREQUENT', 'player')
    assert(issecretvalue(bar.value) and issecretvalue(bar.high), 'secret values reach the bar')
    assert(M:SetResourceOption('power', 'text', 'currentMax') and power.text.text.formatted == '%s / %s', 'Current / Max with secrets')
    assert(M:SetResourceOption('power', 'text', 'percent') and power.text.text.formatted == '%.0f%%', 'Percent through the curve')
    assert(M:SetResourceOption('power', 'text', 'both') and power.text.text.formatted == '%s · %.0f%%')
    units.player.power, units.player.powerMax = 50, 100
    assert(M:SetResourceOption('power', 'text', 'currentMax') and power.text.text == '50 / 100')
    assert(M:SetResourceOption('power', 'text', 'none') and not power.text:IsShown())
    assert(M:SetResourceOption('power', 'text', 'current'))

    -- Combo Points: a Rogue's five boxes, each lit by the count without comparing it.
    assert(combo:IsShown() and combo.count == 5 and ModeUIResourceCombo.width == 454, 'five points, matched to Power')
    for i = 1, 5 do assert(combo.boxes[i].bar.low == i - 1 and combo.boxes[i].bar.high == i) end
    local last = combo.boxes[5]
    assert(Point(combo.boxes[1])[4] == 2 and Point(last)[4] + last.width + 2 == 454, 'the boxes and their edges fill the width exactly')
    assert(Point(combo.boxes[2])[4] - (Point(combo.boxes[1])[4] + combo.boxes[1].width) == 6, 'Spacing apart between the shadows')
    comboPoints = Secret('cp'); FireEvent('PLAYER_TARGET_CHANGED')
    assert(issecretvalue(combo.boxes[3].bar.value), 'a secret count lights the boxes')
    comboPoints = 3; FireEvent('COMBO_TARGET_CHANGED')
    assert(combo.boxes[1].bar.value == 3 and combo.boxes[5].bar.value == 3)
    assert(combo.boxes[1].bar.statusBarColor[1] == addon.Style.Tone.reaction.hostile[1], 'combo points in the hostile red')
    assert(M:SetResourceOption('combo', 'text', 'current') and combo.text.text == '3', 'Count text')
    assert(not M:SetResourceOption('combo', 'text', 'percent') and not M:SetResourceOption('combo', 'colorMode', 'power'), 'combo offers its own choices')
    assert(M:SetResourceOption('combo', 'spacing', 0) and Point(combo.boxes[2])[4] == Point(combo.boxes[1])[4] + combo.boxes[1].width + 4, 'edges touching')

    -- Alternate Mana: only a Druid whose shown power isn't mana.
    assert(not mana:IsShown(), 'a Rogue has no alternate mana')
    units.player.class = 'DRUID'; units.player.token = 'ENERGY'
    FireEvent('UPDATE_SHAPESHIFT_FORM')
    assert(mana:IsShown() and combo:IsShown(), 'Cat Form: mana and combo points')
    assert(mana.boxes[1].bar.statusBarColor[3] == Power.colors.MANA[3], 'mana blue')
    units.player.token = 'RAGE'; FireEvent('UNIT_DISPLAYPOWER', 'player')
    assert(mana:IsShown() and not combo:IsShown(), 'Bear Form: mana, no combo points')
    assert(power.boxes[1].bar.statusBarColor[1] == Power.colors.RAGE[1], 'Power follows the form')
    units.player.token = 'MANA'; FireEvent('UNIT_DISPLAYPOWER', 'player')
    assert(not mana:IsShown() and not combo:IsShown(), 'caster form: Power shows the mana')
    units.player.class = 'ROGUE'; units.player.token = 'ENERGY'; FireEvent('UNIT_DISPLAYPOWER', 'player')

    -- Health: off by default; secret health and percent text.
    assert(not health:IsShown() and M:SetResourceOption('health', 'show', true) and health:IsShown())
    units.player.health = Secret('hp'); FireEvent('UNIT_HEALTH', 'player')
    assert(issecretvalue(health.boxes[1].bar.value) and health.text.text.formatted == '%.0f%%', 'secret health, percent text')
    units.player.health = 900
    assert(M:SetResourceOption('health', 'colorMode', 'custom') and M:SetResourceOption('health', 'barColor', { 1, 0, 0 }))
    assert(health.boxes[1].bar.statusBarColor[1] == 1 and health.boxes[1].bar.statusBarColor[2] == 0, 'custom color')
    -- Class: the class color comes keyed (.r, .g, .b) and is painted by index.
    local rogue = addon.Domain.UnitColor.PlayerClass('player')
    assert(M:SetResourceOption('health', 'colorMode', 'class'))
    assert(health.boxes[1].bar.statusBarColor[1] == rogue.r and health.boxes[1].bar.statusBarColor[3] == rogue.b, 'class color')
    assert(M:SetResourceOption('health', 'colorMode', 'custom'))

    -- Settings: own width without Match Width, checked values, border off, reverse fill.
    assert(M:SetResourceOption('power', 'matchWidth', false) and ModeUIResourcePower.width == 300, 'Width while Match Width is off')
    assert(not M:SetResourceOption('power', 'height', 100) and not M:SetResourceOption('power', 'visibility', 'sometimes'), 'bad values refused')
    assert(not M:SetResourceOption('power', 'unknown', 1))
    assert(M:SetResourceOption('power', 'border', 'none') and not box.edge.holder:IsShown() and Point(box)[4] == 0 and ModeUIResourcePower.height == 14, 'no border, no reach')
    assert(M:SetResourceOption('power', 'reverse', true) and bar.reverseFill == true)
    assert(M:SetResourceOption('power', 'smooth', false)); FireEvent('UNIT_POWER_FREQUENT', 'player'); assert(bar.ease == nil, 'Smooth off snaps')
    assert(M:SetResourceOption('power', 'textAnchor', 'LEFT') and Point(power.text)[1] == 'LEFT' and Point(power.text)[4] == 4)
    assert(M:SetResourceOption('power', 'textSize', 14) and power.text.font[2] == 14)

    -- Visibility.
    assert(M:SetResourceOption('power', 'visibility', 'combat') and power.alpha == 0, 'In Combat')
    testCombat = true; FireEvent('PLAYER_REGEN_DISABLED'); assert(power.alpha == 1)
    testCombat = false; FireEvent('PLAYER_REGEN_ENABLED'); assert(power.alpha == 0)
    assert(M:SetResourceOption('power', 'visibility', 'mouseover') and M:SetResourceOption('power', 'fadeOpacity', 20) and power.alpha == 0.2)
    power.mouseOver = true; Advance(0.2); assert(power.alpha == 1, 'Mouseover')
    power.mouseOver = false; Advance(0.2); assert(power.alpha == 0.2)
    assert(M:SetResourceOption('power', 'visibility', 'always') and M:SetResourceOption('power', 'opacity', 50) and power.alpha == 0.5)

    -- Edit Mode: each bar that's on shows its stand-in, labeled.
    assert(addon:SetEditMode(true) and ModeUIResourcePower:IsShown() and ModeUIResourceHealth:IsShown())
    assert(PM:Element('cooldownManagerResourcePower').label == 'Power' and PM:Element('cooldownManagerResourceMana').label == 'Alternate Mana', 'Edit Mode names each bar')
    assert(addon:SetEditMode(false) and not ModeUIResourcePower:IsShown())

    -- Reset keeps Show Bar and the size.
    assert(M:ResetResource('power') and db.power.border == 'mode' and db.power.visibility == 'always' and db.power.opacity == 100)
    assert(db.power.matchWidth == false and db.power.show, 'size and show stay')
    assert(M:SetResourceOption('power', 'matchWidth', true) and ModeUIResourcePower.width == 454)

    -- The window: Resource Bars in the list, their own page and preview.
    SlashCmdList.MODEUICDM()
    local window = ModeUICooldownManagerWindow
    assert(window.resourceCaption:IsShown() and window.rows[5].label.text == 'Power' and window.rows[8].label.text == 'Health')
    assert(window.rows[6].label.text == 'Combo Points' and window.rows[7].label.text == 'Alternate Mana')
    assert(M.resourcePage == nil, 'resource page built on first use')
    window.rows[6].scripts.OnClick(window.rows[6])
    local page = M.resourcePage
    assert(page and page:IsShown() and not M.page:IsShown() and window.rows[6].selected and not window.rows[1].selected, 'Combo Points page')
    local view = M.resourcePreview
    assert(view.bar.count == 5 and view.bar.boxes[3].bar.value == 3 and view.bar:IsShown(), 'preview: five points, three lit')
    assert(page.resourceStatus.text == 'Shows now. Move it in Edit Mode.', 'a Rogue has combo points')
    window.rows[5].scripts.OnClick(window.rows[5])
    assert(M:ResourceEditing() == 'power' and view.bar.count == 1 and view.bar.boxes[1].bar.value == 65 and view.bar.text.text == '13.2K', 'preview: Power, sample values')
    assert(M:SetResourceOption('power', 'text', 'percent') and view.bar.text.text == '65%', 'the preview follows the settings')
    assert(page.resourceStatus.text == 'Shows now. Move it in Edit Mode.')
    window.rows[1].scripts.OnClick(window.rows[1])
    assert(M.page:IsShown() and not page:IsShown() and M.selectedResource == nil, 'back to the cooldown page')
    M:OpenSettings('cooldownManagerResourceMana')
    assert(page:IsShown() and M.selectedResource == 'mana', "Edit Mode's Open Module Settings opens the bar")
    window:Hide()

    -- Off: the bars hide and the events stop.
    addon:SetModuleEnabled('cooldownManager', false)
    assert(not power:IsShown() and not combo:IsShown() and M.resourceEvents.on == false)
    addon:SetModuleEnabled('cooldownManager', true)
    assert(power:IsShown())
    assert(M:SetResourceOption('combo', 'height', 12))
    -- In combat: bars keep updating and follow a form change; settings wait.
    testCombat, testLockdown = true, true; FireEvent('PLAYER_REGEN_DISABLED')
    units.player.token = 'RAGE'; FireEvent('UNIT_DISPLAYPOWER', 'player')
    assert(power.boxes[1].bar.statusBarColor[1] == Power.colors.RAGE[1] and ModeUIResourcePower.width == 454, 'a form change in combat')
    units.player.power = 70; FireEvent('UNIT_POWER_FREQUENT', 'player'); assert(power.boxes[1].bar.value == 70)
    assert(not M:SetResourceOption('power', 'height', 16), 'settings change only outside combat')
    testCombat, testLockdown = false, false; FireEvent('PLAYER_REGEN_ENABLED')
    units.player.token, units.player.power = 'ENERGY', 50; FireEvent('UNIT_DISPLAYPOWER', 'player')
    -- A viewer can attach to a resource bar.
    assert(PM:SetAnchor('cooldownManagerBuffBar', 'cooldownManagerResourcePower', 'right'))
    assert(Point(ModeUICooldownBuffBar)[2] == ModeUIResourcePower)
]==], "resource bars")

-- Saved: the settings come back; a profile from before resource bars takes their defaults.
local saved = world.saved()
local restored = H.Load({ before = STUBS, saved = saved })
restored.run([==[
    local db = addon.CooldownManager.db.resources
    assert(db.health.show and db.combo.height == 12 and db.combo.text == 'current' and db.health.colorMode == 'custom', 'kept')
    assert(Point(ModeUICooldownBuffBar)[2] == ModeUIResourcePower, 'a viewer attached to a resource bar finds it after a reload')
]==], "restore")
local before = restored.saved()
before.profiles.Default.modules.cooldownManager.resources = nil
H.Load({ before = STUBS, saved = before }).run([==[
    local db = addon.CooldownManager.db.resources
    assert(db.power.show and not db.health.show and db.combo.height == 10, 'defaults for an older profile')
]==], "older profile")

-- Bad saved data stops startup rather than being reset.
local function Refused(change, label)
    local data = restored.saved()
    change(data.profiles.Default.modules.cooldownManager.resources)
    assert(not pcall(H.Load, { before = STUBS, saved = data }), "invalid resource bar settings are refused: " .. label)
end
Refused(function(db) db.power.height = 400 end, "height")
Refused(function(db) db.combo.text = "percent" end, "combo text")
Refused(function(db) db.health.colorMode = "power" end, "health color mode")
Refused(function(db) db.mana.barColor = { 2, 0, 0 } end, "color")
Refused(function(db) db.power.visibility = "never" end, "visibility")

print("resource bars: all checks passed")
