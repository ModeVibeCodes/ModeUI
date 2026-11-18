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
    assert(db.power.matchWidth and db.power.colorMode == 'power' and db.power.text == 'current' and db.combo.text == 'current', 'the combo point count')
    assert(db.power.textShow and db.combo.textShow and not db.mana.textShow and db.power.textAnchor == nil, 'Show Text; always in the middle')
    assert(db.power.height == 16 and db.combo.height == 10 and db.mana.height == 8 and db.health.height == 14, 'version 7 heights')
    assert(not db.power.marksShow and #db.power.marks == 1 and db.power.marks[1].value == 0, 'Tick Marks off, one tick')
    assert(db.power.barMode == 'dark' and db.power.darkText == 'power' and db.combo.layout == 'grouped' and M.db.resourceLayout == 'separate', 'Dark, grouped points, Separate Resources')
    assert(ModeUIResourcePower == nil, 'nothing built while the module is off')

    addon:SetModuleEnabled('cooldownManager', true)
    local power, combo, mana, health = M.resourceFrames.power, M.resourceFrames.combo, M.resourceFrames.mana, M.resourceFrames.health
    assert(ModeUIResourcePower and ModeUIResourceCombo and ModeUIResourceMana and ModeUIResourceHealth, 'a stand-in per bar')
    assert(ModeUIResourcePower.height == 20 and ModeUIResourceCombo.height == 14 and ModeUIResourceMana.height == 14, '16, 10 and 8 (drawn at the 10px floor) in their edges')
    -- The geometry checks below use 10px Power and 6px strips.
    assert(M:SetResourceOption('power', 'height', 10) and M:SetResourceOption('combo', 'height', 6) and M:SetResourceOption('mana', 'height', 6))
    assert(PM:GetPosition('cooldownManagerResourcePower').target == 'cooldownManagerUtility', 'Power under Utility')
    assert(PM:GetPosition('cooldownManagerResourceCombo').target == 'cooldownManagerResourcePower', 'Combo Points under Power')
    -- Match Width: Utility's line is 12 icons of 32 with their 2px edges, 2px between.
    assert(ModeUIResourcePower.width == 454 and ModeUIResourcePower.height == 14, 'Power matches the cooldowns above it; its edges inside the stand-in')
    assert(PM:GetSizeMatch('cooldownManagerResourcePower', 'width'), "Edit Mode's Match Width is on")
    assert(power:IsShown() and not ModeUIResourcePower:IsShown(), 'bar shown on its hidden stand-in')

    -- Power: the frameThin edge outside the box, Mode Gradient over Mode BG, no masks.
    local box = power.boxes[1]
    local bar = box.bar
    assert(box.edge.preset == 'frameThin' and box.edge.holder:IsShown() and box.edge.holder.frameLevel > box:GetFrameLevel(), 'the Mode edge')
    assert(Point(box)[4] == 2 and Point(box)[5] == -2 and box.width == 450 and box.height == 10, 'the box inside the edge reach')
    assert(bar.points[1][4] == 0 and bar.points[2][4] == 0, 'the bar fills its box')
    local fill = bar:GetStatusBarTexture()
    assert(not (fill.masks and #fill.masks > 0) and not (bar.bg.masks and #bar.bg.masks > 0), 'no masks')
    assert(bar.sheen:IsShown() and bar.bg.vertexColor[1] == addon.Style.Tone.slate[1] and bar.bg.vertexColor[4] == 0.6, 'Mode Gradient lift; Slate at 60%')
    -- Energy 50 of 100 (units.player), in the energy color, with the current value.
    assert(bar.low == 0 and bar.high == 100 and bar.value == 50 and bar.ease == 1, 'filled, smoothly')
    local energy, Tone = Power.colors.ENERGY, addon.Style.Tone
    -- Dark mode (the default): the fill in darkFill, the text in the power's color.
    assert(bar.statusBarColor[1] == Tone.darkFill[1] and bar.statusBarColor[4] == 1, 'Dark: the dark fill')
    assert(power.text.color[1] == energy[1] and power.text.color[2] == energy[2], 'Dark: the text in Power Type')
    assert(M:SetResourceOption('power', 'darkText', 'class'))
    local class = addon.Domain.UnitColor.PlayerClass('player')
    assert(power.text.color[1] == class.r and power.text.color[3] == class.b, 'Dark: the text in your class color')
    assert(M:SetResourceOption('power', 'darkText', 'custom') and M:SetResourceOption('power', 'darkTextColor', { 0, 1, 0 }) and power.text.color[2] == 1, 'Dark: custom text')
    for _, id in ipairs(M.resources) do assert(M:SetResourceOption(id, 'barMode', 'color')) end
    assert(bar.statusBarColor[1] == energy[1] and bar.statusBarColor[4] == 1, 'Power Type color')
    assert(power.text.color[1] == Tone.textBright[1], 'Color mode: Text Color')
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
    assert(not M:SetResourceOption('power', 'text', 'none'), 'no None format: Show Text')
    assert(M:SetResourceOption('power', 'textShow', false) and not power.text:IsShown() and M:SetResourceOption('power', 'textShow', true) and power.text:IsShown())
    assert(M:SetResourceOption('power', 'text', 'current'))
    assert(Point(power.text)[1] == 'CENTER' and Point(power.text)[3] == 'CENTER' and Point(power.text)[4] == 0, 'the text in the middle')

    -- Whole pixels: a stand-in between pixels nudges its bar onto the grid.
    local px, mover = Kit.PixelSize(power), ModeUIResourcePower
    local cx, cy = mover:GetCenter()
    mover.centerX, mover.centerY = cx + 0.3 * px, cy + 0.6 * px
    M:LayoutResource('power')
    local function Whole(v) return math.abs(v / px - math.floor(v / px + 0.5)) < 1e-6 end
    assert(Whole(power:GetLeft()) and Whole(power:GetBottom()) and power.snapX ~= 0, 'the bar on whole pixels')
    mover.centerX, mover.centerY = cx, cy
    M:LayoutResource('power')
    assert(math.abs(power.snapX) < 1e-9 and Point(power)[2] == mover, 'back on the stand-in')

    -- Combo Points: a Rogue's five points, each lit by the count without comparing it.
    assert(combo:IsShown() and combo.count == 5 and ModeUIResourceCombo.width == 454, 'five points, matched to Power')
    -- Grouped (the default): one edge round the points, a line between them, no edge on a point.
    assert(combo.outer.edge.holder:IsShown() and not combo.boxes[1].edge.holder:IsShown(), 'one border round the points')
    assert(combo.boxes[1].height == 10 and ModeUIResourceCombo.height == 14, 'Mode-Round floor: 6px drawn at 10')
    local line = combo.dividers[1]
    assert(line:IsShown() and line.width == 1 and Point(line)[4] == Point(combo.boxes[1])[4] + combo.boxes[1].width
        and Point(combo.boxes[2])[4] == Point(line)[4] + 1, 'a 1px line between points')
    assert(line.vertexColor[1] == 0 and combo.dividers[4]:IsShown() and combo.dividers[5] == nil, 'black lines, four between five points')
    assert(M:SetResourceOption('combo', 'dividerColor', { 1, 0, 0 }) and M:SetResourceOption('combo', 'dividerWidth', 2), 'Divider Color and Width')
    assert(line.vertexColor[1] == 1 and line.width == 2, 'the lines follow')
    assert(Point(combo.boxes[5])[4] + combo.boxes[5].width == 452, 'the last point ends at the edge')
    assert(M:SetResourceOption('combo', 'layout', 'separated') and combo.boxes[1].edge.holder:IsShown() and not combo.outer.edge.holder:IsShown()
        and not line:IsShown(), 'Separated: a border per point')
    for i = 1, 5 do assert(combo.boxes[i].bar.low == i - 1 and combo.boxes[i].bar.high == i) end
    local last = combo.boxes[5]
    assert(Point(combo.boxes[1])[4] == 2 and Point(last)[4] + last.width + 2 == 454, 'the boxes and their edges fill the width exactly')
    assert(Point(combo.boxes[2])[4] - (Point(combo.boxes[1])[4] + combo.boxes[1].width) == 6, 'Spacing apart between the shadows')
    comboPoints = Secret('cp'); FireEvent('PLAYER_TARGET_CHANGED')
    assert(issecretvalue(combo.boxes[3].bar.value), 'a secret count lights the boxes')
    comboPoints = 3; FireEvent('COMBO_TARGET_CHANGED')
    assert(combo.boxes[1].bar.value == 3 and combo.boxes[5].bar.value == 3)
    assert(combo.boxes[1].bar.statusBarColor[1] == addon.Style.Tone.reaction.hostile[1], 'combo points in the hostile red')
    assert(combo.text.text == '3' and Point(combo.text)[1] == 'CENTER', 'Count text in the middle')
    -- Full Color: a layer per point spanning max - 1 to max, lit only at the maximum.
    assert(M:SetResourceOption('combo', 'fullShow', true) and combo.boxes[1].full:IsShown())
    assert(combo.boxes[1].full.low == 4 and combo.boxes[1].full.high == 5 and combo.boxes[1].full.value == 3, 'not full at 3')
    comboPoints = 5; FireEvent('COMBO_TARGET_CHANGED'); assert(combo.boxes[2].full.value == 5, 'full at 5')
    comboPoints = Secret('cp'); FireEvent('COMBO_TARGET_CHANGED'); assert(issecretvalue(combo.boxes[2].full.value), 'a secret count reaches the layer')
    comboPoints = 3; FireEvent('COMBO_TARGET_CHANGED')
    assert(M:SetResourceOption('combo', 'fullShow', false) and not combo.boxes[1].full:IsShown())
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

    -- Border Style and Rim Color (owner, November 17, 2026): each bar its
    -- own, Mode-Round in Gunmetal; a style's floor keeps its corners whole.
    for _, id in ipairs(M.resources) do assert(db[id].edgeStyle == 'round' and db[id].edgeMetal == 'gunmetal' and db[id].rimColor == 'metal', id .. ' in Mode-Round, Gunmetal') end
    assert(box.edge.styleId == 'round' and box.edge:Metal() == Tone.metal.gunmetal, 'Mode-Round, Gunmetal')
    assert(M:SetResourceOption('power', 'edgeStyle', 'blizz') and M:SetResourceRim('power', 'steel') and box.edge.styleId == 'blizz'
        and box.edge:Metal() == Tone.metal.steel and M:ResourceRim('power') == 'steel', 'Mode-Blizz in Steel')
    assert(Point(box)[4] == 2 and Point(box)[5] == -2 and box.width == 450 and box.height == 10 and ModeUIResourcePower.height == 14, 'same box, same reach')
    assert(M:SetResourceOption('power', 'height', 4) and box.height == 6 and ModeUIResourcePower.height == 10, 'Mode-Blizz floor: 6px')
    assert(M:SetResourceOption('power', 'edgeStyle', 'round') and box.height == 10 and db.power.height == 4, 'Mode-Round floor: 10px; the saved height stays')
    assert(M:SetResourceOption('power', 'height', 10) and M:SetResourceOption('power', 'edgeStyle', 'blizz'))
    -- Rim Color: Bar Color and Custom paint the edge flat; a metal brings the light back.
    assert(M:SetResourceRim('power', 'bar') and box.edge.tint and box.edge.tint[1] == energy[1], 'Bar Color rim')
    assert(M:SetResourceRim('power', 'custom') and M:SetResourceOption('power', 'rimCustom', { 0, 0, 1 }) and box.edge.tint[3] == 1, 'Custom rim')
    assert(M:SetResourceRim('power', 'default') and box.edge.tint == nil and db.power.edgeMetal == 'default' and box.edge:Metal() == Tone.metal.silver, 'Default Metal: the style own')
    assert(not M:SetResourceRim('power', 'gold'), 'unknown rims are refused')
    assert(combo.boxes[1].edge.styleId == 'round', 'other bars keep their own')
    -- Tick Marks: a line at 40 Energy, placed from the readable maximum; hidden on another power.
    assert(power.marks == nil, 'no ticks while Show Tick Marks is off')
    assert(M:SetResourceMark('power', 1, 'value', 40) and M:SetResourceMark('power', 1, 'power', 'ENERGY') and power.marks == nil)
    assert(M:SetResourceOption('power', 'marksShow', true), 'Show Tick Marks')
    local mark = power.marks[1]
    assert(mark:IsShown() and Point(mark)[2] == box.bar and Point(mark)[4] == 180 and mark.width == 1, 'at 40 of 100 on a 450px bar')
    assert(M:SetResourceOption('power', 'markColor', { 1, 0, 0 }) and M:SetResourceOption('power', 'markWidth', 2) and power.marks[1].width == 2
        and power.marks[1].vertexColor[1] == 1 and Point(power.marks[1])[4] == 179, 'Tick Color and Width')
    units.player.powerMax = Secret('pm'); FireEvent('UNIT_MAXPOWER', 'player')
    assert(power.marks[1]:IsShown() and Point(power.marks[1])[4] == 179, 'a secret maximum keeps the last readable one')
    units.player.powerMax = 100
    units.player.token = 'RAGE'; FireEvent('UNIT_DISPLAYPOWER', 'player')
    assert(not power.marks[1]:IsShown(), 'an Energy tick hides on Rage')
    units.player.token = 'ENERGY'; FireEvent('UNIT_DISPLAYPOWER', 'player')
    assert(power.marks[1]:IsShown(), 'and comes back')
    assert(not M:SetResourceMark('power', 1, 'value', 200000) and not M:SetResourceMark('power', 1, 'power', 'RUNES'), 'bad ticks refused')
    -- Add Tick Mark: more ticks on this bar only, up to five; Remove; the first stays.
    assert(M:AddResourceMark('power') and #db.power.marks == 2 and db.power.marks[2].power == 'ENERGY', 'a new tick on the last power type')
    assert(M:SetResourceMark('power', 2, 'value', 60) and power.marks[2]:IsShown() and Point(power.marks[2])[4] == 269, 'at 60')
    for _ = 3, M.MARK_MAX do assert(M:AddResourceMark('power')) end
    assert(#db.power.marks == 5 and not M:AddResourceMark('power'), 'five at most')
    assert(M:RemoveResourceMark('power', 5) and M:RemoveResourceMark('power', 4) and M:RemoveResourceMark('power', 3), 'Remove')
    assert(M:RemoveResourceMark('power', 1) and #db.power.marks == 1 and db.power.marks[1].value == 60 and not power.marks[2]:IsShown(), 'the rest move up')
    assert(not M:RemoveResourceMark('power', 1), 'one tick always stays')
    assert(M:SetResourceOption('power', 'marksShow', false) and not power.marks[1]:IsShown() and M:SetResourceOption('power', 'marksShow', true))
    assert(M:SetResourceMark('power', 1, 'value', 0) and not power.marks[1]:IsShown(), '0 hides a tick')
    assert(combo.marks == nil and db.combo.marks == nil, 'no ticks on combo points')
    assert(not M:SetResourceOption('power', 'edgeStyle', 'nope') and not M:SetResourceOption('power', 'edgeMetal', 'gold'), 'unknown styles and metals are refused')
    -- Settings: own width without Match Width, checked values, border off, reverse fill.
    assert(M:SetResourceOption('power', 'matchWidth', false) and ModeUIResourcePower.width == 300, 'Width while Match Width is off')
    assert(not M:SetResourceOption('power', 'height', 100) and not M:SetResourceOption('power', 'visibility', 'sometimes'), 'bad values refused')
    assert(not M:SetResourceOption('power', 'unknown', 1))
    assert(M:SetResourceOption('power', 'border', 'none') and not box.edge.holder:IsShown() and Point(box)[4] == 0 and ModeUIResourcePower.height == 10, 'no border, no reach')
    assert(db.power.edgeStyle == 'blizz', 'None keeps the Border Style')
    assert(M:SetResourceOption('power', 'reverse', true) and bar.reverseFill == true)
    assert(M:SetResourceOption('power', 'smooth', false)); FireEvent('UNIT_POWER_FREQUENT', 'player'); assert(bar.ease == nil, 'Smooth off snaps')
    assert(not M:SetResourceOption('power', 'textAnchor', 'LEFT') and Point(power.text)[1] == 'CENTER', 'no Anchor: always in the middle')
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
    assert(db.power.edgeStyle == 'round' and db.power.edgeMetal == 'gunmetal' and box.edge.styleId == 'round' and box.edge:Metal() == Tone.metal.gunmetal, 'Reset: Mode-Round, Gunmetal again')
    assert(db.power.barMode == 'dark' and M:SetResourceOption('power', 'barMode', 'color'), 'Reset: Dark again')
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
    -- Tick Marks on the page: a text field per tick, Add Tick Mark; each bar's own.
    assert(M:SetResourceOption('power', 'marksShow', true) and M:SetResourceMark('power', 1, 'value', 40) and view.bar.marks[1]:IsShown(), 'the preview shows Power ticks')
    local input = page.resourceMarkInputs[1]
    input:SetText('55'); input.scripts.OnEnterPressed(input)
    assert(db.power.marks[1].value == 55, 'the tick value typed in')
    page.resourceAddMarkButton.scripts.OnClick(page.resourceAddMarkButton)
    assert(#db.power.marks == 2 and page.resourceMarkRemove[2], 'Add Tick Mark')
    page.resourceMarkRemove[2].scripts.OnClick(page.resourceMarkRemove[2])
    assert(#db.power.marks == 1, 'Remove')
    window.rows[6].scripts.OnClick(window.rows[6])
    assert(not view.bar.marks[1]:IsShown(), "Combo Points' preview shows no Power tick")
    window.rows[5].scripts.OnClick(window.rows[5])
    -- Border Style and Rim Color: in Border on the Look tab, while the border shows.
    local borderGroup, rows = nil, {}
    for _, row in ipairs(page.rows) do
        if row.settingsGroupTitle == 'Border' and row.section.title == 'Look' then borderGroup = row
        elseif borderGroup and row.card == borderGroup.card and row.visibleWhen then rows[#rows + 1] = row end
    end
    local function Hidden() for _, row in ipairs(rows) do if not row.visibleWhen() then return true end end return false end
    assert(page.resourceBorderStylePicker and page.resourceRimPicker and #rows > 0, 'Border Style and Rim Color in Border')
    assert(M:SetResourceOption('power', 'border', 'none') and Hidden() and M:SetResourceOption('power', 'border', 'mode'), 'hidden with Border None')
    assert(M:SetResourceOption('power', 'edgeStyle', 'thin') and view.bar.boxes[1].edge.styleId == 'thin' and M:SetResourceOption('power', 'edgeStyle', 'blizz'), 'the preview follows the style')
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
    assert(M:SetResourceOption('combo', 'height', 12) and M:SetResourceOption('combo', 'edgeStyle', 'thin') and combo.boxes[1].edge.styleId == 'thin')
    -- In combat: bars keep updating and follow a form change; settings wait.
    testCombat, testLockdown = true, true; FireEvent('PLAYER_REGEN_DISABLED')
    units.player.token = 'RAGE'; FireEvent('UNIT_DISPLAYPOWER', 'player')
    assert(power.boxes[1].bar.statusBarColor[1] == Power.colors.RAGE[1] and ModeUIResourcePower.width == 454, 'a form change in combat')
    units.player.power = 70; FireEvent('UNIT_POWER_FREQUENT', 'player'); assert(power.boxes[1].bar.value == 70)
    assert(not M:SetResourceOption('power', 'height', 16), 'settings change only outside combat')
    testCombat, testLockdown = false, false; FireEvent('PLAYER_REGEN_ENABLED')
    units.player.token, units.player.power = 'ENERGY', 50; FireEvent('UNIT_DISPLAYPOWER', 'player')
    -- Group Resources: Power, Combo Points and Alternate Mana in one border on
    -- Power's stand-in, a 1px black line between them; each keeps its own look.
    assert(M:SetResourceOption('combo', 'height', 6) and M:SetResourceOption('combo', 'edgeStyle', 'round'))
    units.player.class = 'DRUID'; units.player.token = 'ENERGY'; FireEvent('UPDATE_SHAPESHIFT_FORM')
    assert(M:SetResourceLayout('grouped') and M.db.resourceLayout == 'grouped')
    local block = power.block
    -- 10 (Power) + 1 + 6 (Combo Points) + 1 + 6 (Alternate Mana), with the 2px reach each way.
    assert(block and block:IsShown() and block.edge.holder:IsShown() and block.width == 450 and block.height == 24, 'one block')
    assert(ModeUIResourcePower.height == 28 and ModeUIResourcePower.width == 454, 'the stand-in holds the block')
    assert(not power.boxes[1].edge.holder:IsShown() and not combo.outer.edge.holder:IsShown() and not mana.boxes[1].edge.holder:IsShown(), 'no edges inside')
    assert(Point(combo)[2] == block and Point(combo)[5] == -11 and Point(mana)[5] == -18, 'stacked under 1px lines')
    assert(block.lines[1]:IsShown() and Point(block.lines[1])[5] == -10 and block.lines[2]:IsShown(), 'the lines')
    assert(combo.boxes[1].height == 6 and mana.boxes[1].height == 6, 'no floor inside the block')
    assert(ModeUIResourceCombo.height == ModeUIResourceCombo.px or ModeUIResourceCombo.height == 1, "Combo Points' stand-in folds")
    assert(Point(combo.text)[2] == combo and Point(combo.text)[1] == 'CENTER', 'each text in the middle of its own strip')
    assert(addon:SetEditMode(true) and ModeUIResourcePower:IsShown() and not ModeUIResourceCombo:IsShown() and not ModeUIResourceMana:IsShown(), 'one stand-in in Edit Mode')
    assert(addon:SetEditMode(false))
    assert(M:ResourceStatus('combo'):find('Grouped') ~= nil, 'the page says so')
    -- Bear Form: no combo points, the block closes up.
    units.player.token = 'RAGE'; FireEvent('UNIT_DISPLAYPOWER', 'player')
    assert(not combo:IsShown() and block.height == 17 and Point(mana)[5] == -11 and not block.lines[2]:IsShown(), 'Bear Form: Power and mana')
    -- Alternate Mana off: Power alone, raised to the Mode-Round floor... Power is in Mode-Blizz here (6px floor).
    assert(M:SetResourceOption('mana', 'show', false) and block.height == 10 and not block.lines[1]:IsShown())
    assert(M:SetResourceOption('power', 'edgeStyle', 'round') and block.height == 10, 'the block keeps the floor')
    assert(M:SetResourceOption('power', 'height', 6) and block.height == 10 and power.boxes[1].height == 10, 'Power grows to the floor')
    assert(M:SetResourceOption('power', 'height', 10) and M:SetResourceOption('mana', 'show', true))
    -- Power off: the others stand apart on their own stand-ins again.
    assert(M:SetResourceOption('power', 'show', false) and not power:IsShown() and Point(mana)[2] == ModeUIResourceMana
        and mana.boxes[1].edge.holder:IsShown() and ModeUIResourceMana.height == 14, 'Power off breaks the block up')
    assert(M:SetResourceOption('power', 'show', true) and Point(mana)[2] == block and block:IsShown(), 'and Power on joins it again')
    -- Rim Color on Power tints the block.
    assert(M:SetResourceRim('power', 'custom') and block.edge.tint ~= nil and M:SetResourceRim('power', 'default') and block.edge.tint == nil, 'the block takes Power rim')
    -- Back to Separate Resources: each bar on its own stand-in again.
    assert(M:SetResourceLayout('separate') and not block:IsShown() and Point(mana)[2] == ModeUIResourceMana and power.boxes[1].edge.holder:IsShown())
    assert(ModeUIResourcePower.height == 14 and ModeUIResourceMana.height == 14, 'own sizes again')
    units.player.class = 'ROGUE'; units.player.token = 'ENERGY'; FireEvent('UNIT_DISPLAYPOWER', 'player')
    assert(not M:SetResourceLayout('stacked'), 'unknown layouts refused')
    assert(M:SetResourceOption('combo', 'height', 12) and M:SetResourceOption('combo', 'edgeStyle', 'thin'))
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
    assert(db.combo.edgeStyle == 'thin' and addon.CooldownManager.resourceFrames.combo.boxes[1].edge.styleId == 'thin', 'Border Style kept')
    assert(Point(ModeUICooldownBuffBar)[2] == ModeUIResourcePower, 'a viewer attached to a resource bar finds it after a reload')
]==], "restore")
local before = restored.saved()
before.profiles.Default.modules.cooldownManager.resources = nil
H.Load({ before = STUBS, saved = before }).run([==[
    local db = addon.CooldownManager.db.resources
    assert(db.power.show and not db.health.show and db.combo.height == 10, 'defaults for an older profile')
]==], "older profile")

-- Saved bars from before Border Style and Border Metal take their defaults; nothing else changes.
local noEdge = restored.saved()
for _, style in pairs(noEdge.profiles.Default.modules.cooldownManager.resources) do style.edgeStyle, style.edgeMetal = nil, nil end
H.Load({ before = STUBS, saved = noEdge }).run([==[
    local db = addon.CooldownManager.db.resources
    assert(db.combo.height == 12 and db.health.show, 'nothing reset')
    for _, id in ipairs(addon.CooldownManager.resources) do assert(db[id].edgeStyle == 'round' and db[id].edgeMetal == 'gunmetal', id .. ' takes the default border') end
]==], "fill border style")

-- Version 5 -> 6 -> 7: values still at version 5's defaults move (Mode-Round,
-- Gunmetal, the count on); values the player chose stay; Separate Resources,
-- so no bar moves.
local five = restored.saved()
local cdm5 = five.profiles.Default.modules.cooldownManager
cdm5.version, cdm5.resourceLayout = 5, nil
for _, style in pairs(cdm5.resources) do
    style.barMode, style.darkText, style.darkTextColor, style.rimColor, style.rimCustom = nil, nil, nil, nil, nil
    style.marks, style.markColor, style.markWidth, style.layout, style.dividerWidth, style.dividerColor, style.fullShow, style.fullColor = nil, nil, nil, nil, nil, nil, nil, nil
    style.edgeStyle, style.edgeMetal = 'blizz', 'default'
    style.textShow, style.marksShow = nil, nil
end
cdm5.resources.power.height, cdm5.resources.mana.height, cdm5.resources.combo.height = 14, 8, 12
cdm5.resources.combo.text, cdm5.resources.combo.textAnchor = 'none', 'CENTER'
cdm5.resources.health.edgeMetal = 'steel'
H.Load({ before = STUBS, saved = five }).run([==[
    local M = addon.CooldownManager
    local db = M.db.resources
    assert(M.db.version == 8 and M.db.resourceLayout == 'separate', 'version 8, Separate Resources')
    assert(db.power.height == 16 and db.mana.height == 8 and db.combo.height == 12, 'default heights move; a chosen one stays')
    assert(db.power.edgeStyle == 'round' and db.power.edgeMetal == 'gunmetal' and db.health.edgeMetal == 'steel', 'Mode-Round in Gunmetal; a chosen metal stays')
    assert(db.combo.text == 'current' and db.combo.textShow and db.combo.textAnchor == nil and db.combo.layout == 'grouped', 'the count on, grouped points')
    assert(db.power.barMode == 'dark' and db.power.rimColor == 'metal' and #db.power.marks == 1 and not db.power.marksShow, 'new settings from their defaults')
]==], "version 6")

-- Version 6 -> 7 (owner's first in-game look): heights still at version 6's
-- defaults take 16/10/8; None becomes Show Text off; the anchor goes; the
-- tick slots become a list of the ticks in use, shown when one was.
local six = restored.saved()
local cdm6 = six.profiles.Default.modules.cooldownManager
cdm6.version = 6
local r6 = cdm6.resources
for _, style in pairs(r6) do style.textShow, style.marksShow, style.textAnchor = nil, nil, 'CENTER' end
r6.power.height, r6.combo.height, r6.mana.height = 10, 6, 7
r6.mana.text, r6.combo.textAnchor = 'none', 'LEFT'
r6.power.marks = { { value = 0, power = 'any' }, { value = 40, power = 'ENERGY' }, { value = 0, power = 'RAGE' } }
r6.mana.marks = { { value = 0, power = 'MANA' }, { value = 0, power = 'any' }, { value = 0, power = 'any' } }
H.Load({ before = STUBS, saved = six }).run([==[
    local M = addon.CooldownManager
    local db = M.db.resources
    assert(M.db.version == 8, 'version 8')
    assert(db.power.height == 16 and db.combo.height == 10 and db.mana.height == 7, 'version 6 heights move; a chosen one stays')
    assert(db.mana.textShow == false and db.mana.text == 'current' and db.power.textShow and db.combo.textShow, 'None becomes Show Text off')
    assert(db.combo.textAnchor == nil and db.power.textAnchor == nil, 'the anchor goes: always in the middle')
    assert(db.power.marksShow and #db.power.marks == 1 and db.power.marks[1].value == 40 and db.power.marks[1].power == 'ENERGY', 'the tick in use stays, shown')
    assert(db.mana.marksShow == false and #db.mana.marks == 1 and db.mana.marks[1].power == 'MANA', 'none in use: the first, off')
]==], "version 7")

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
Refused(function(db) db.power.edgeStyle = "nope" end, "a Border Style")
Refused(function(db) db.combo.edgeMetal = "gold" end, "a Border Metal")
Refused(function(db) db.power.barMode = "light" end, "a Bar Mode")
Refused(function(db) db.power.rimColor = "gold" end, "a Rim Color")
Refused(function(db) db.power.marks = {} end, "no ticks")
Refused(function(db) for i = 1, 6 do db.power.marks[i] = { value = 10 * i, power = "any" } end end, "more than five ticks")
Refused(function(db) db.power.marks[1].value = -1 end, "a tick value")
Refused(function(db) db.power.marksShow = "yes" end, "Show Tick Marks")
Refused(function(db) db.power.text = "none" end, "the None format")
Refused(function(db) db.combo.layout = "stacked" end, "a combo layout")
Refused(function(db) db.combo.dividerWidth = 5 end, "a divider width")

print("resource bars: all checks passed")
