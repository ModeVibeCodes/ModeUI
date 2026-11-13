-- Nameplates: attaching to game nameplates, fading Blizzard's art, health,
-- colors, threat, raid markers, target highlight, cast bars with secret values,
-- settings and persistence. Simulated client; not WoW rendering or security.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. [==[
    local methods = getmetatable(UIParent).__index
    function methods:SetSpriteSheetCell(index, rows, columns) self.spriteCell = { index, rows, columns } end
    function methods:SetVertexColorFromBoolean(value, ifTrue, ifFalse) self.colorFromBoolean = { value, ifTrue, ifFalse } end
    function methods:SetReverseFill(value) self.reverseFill = value end

    -- Game nameplates: Blizzard acquires a pooled unit frame for each unit.
    nameplates = {}
    local pool, free = {}, {}
    local function NamePlate()
        local recycled = table.remove(free)
        if recycled then return recycled end
        local plate = CreateFrame('Frame', nil, UIParent)
        function plate:AcquireUnitFrame()
            self.UnitFrame = table.remove(pool) or CreateFrame('Button', nil, self)
            self.UnitFrame:SetAlpha(1)
        end
        function plate:ReleaseUnitFrame() pool[#pool + 1] = self.UnitFrame; self.UnitFrame = nil end
        return plate
    end
    C_NamePlate = { GetNamePlateForUnit = function(unit) return nameplates[unit] end }
    function AddPlate(unit, data, blizzardFirst)
        units[unit] = data
        local plate = nameplates[unit] or NamePlate()
        nameplates[unit] = plate
        if blizzardFirst ~= false then plate:AcquireUnitFrame() end
        FireEvent('NAME_PLATE_UNIT_ADDED', unit)
        if blizzardFirst == false then plate:AcquireUnitFrame() end
        return plate
    end
    function RemovePlate(unit)
        local plate = nameplates[unit]
        plate:ReleaseUnitFrame()
        FireEvent('NAME_PLATE_UNIT_REMOVED', unit)
        nameplates[unit], units[unit] = nil, nil
        free[#free + 1] = plate
    end
    function UnitCastingInfo(u) local c = units[u] and units[u].cast; if c then return c.name, c.text, c.icon, c.start, c.stop, false, 'id', c.locked, 1 end end
    function UnitChannelInfo(u) local c = units[u] and units[u].channel; if c then return c.name, c.text, c.icon, c.start, c.stop, false, c.locked, 1 end end
    function GetRaidTargetIndex(u) return units[u] and units[u].raid end
    function UnitThreatSituation(_, u) return units[u] and units[u].threat end
    function UnitNameplateShowsWidgetsOnly(u) return units[u] and units[u].widgetsOnly == true end
    function UnitCanAttack(_, u) return units[u] and units[u].canAttack == true end
    function Hostile(extra)
        local unit = { exists = true, health = Secret('hp'), max = Secret('max'), name = Secret('name'), reaction = 2,
            connected = true, canAttack = true }
        for k, v in pairs(extra or {}) do unit[k] = v end
        return unit
    end
    function Friendly(extra)
        local unit = Hostile({ reaction = 5, canAttack = false })
        for k, v in pairs(extra or {}) do unit[k] = v end
        return unit
    end
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, Kit = addon.Nameplates, addon.Kit
    local P = Kit.palette
    assert(M and addon.modules.nameplates == M and M.category == 'interface' and not M.enabled, 'registered, off by default')
    assert(M.db.version == 2 and M.db.enemy.width == 140 and M.db.friendly.width == 120, 'separate defaults per kind')
    assert(M.db.enemy.threatColors and not M.db.friendly.threatColors and M.db.friendly.healthText == 'none')
    assert(not addon.Events:IsOn(M, 'NAME_PLATE_UNIT_ADDED'), 'no events while off')

    -- A plate already on screen is picked up when the module is switched on.
    local first = AddPlate('nameplate1', Hostile())
    assert(first.UnitFrame:GetAlpha() == 1 and next(M.byUnit) == nil, 'nothing happens while off')
    addon:SetModuleEnabled('nameplates', true)
    local plate = M.byUnit.nameplate1
    assert(plate and plate:IsShown() and plate:GetParent() == first and plate.kind == 'enemy', 'enemy plate attached')
    assert(first.UnitFrame:GetAlpha() == 0, "Blizzard's art is faded")
    first.UnitFrame:SetAlpha(1)
    assert(first.UnitFrame:GetAlpha() == 0, 'kept faded when Blizzard resets the alpha')

    -- Secret health and names reach only the widgets that accept them.
    assert(issecretvalue(plate.health.value) and issecretvalue(plate.health.high), 'secret health on the bar')
    assert(type(plate.healthText.text) == 'table' and issecretvalue(plate.healthText.text.secret), 'secret percent formatted natively')
    assert(issecretvalue(plate.name.text) and issecretvalue(plate.name.lift.text), 'secret name on text and lift')

    -- Colors: hostile reaction, softened; threat wins when known.
    local hostile = Kit.Lighten(P.hostile, M.db.enemy.softness / 100)
    assert(math.abs(plate.health.statusBarColor[1] - hostile[1]) < 1e-6, 'softened hostile color')
    units.nameplate1.threat = 3; FireEvent('UNIT_THREAT_SITUATION_UPDATE', 'nameplate1')
    assert(plate.health.statusBarColor[1] == M.threatPalette.aggro[1], 'aggro is red')
    units.nameplate1.threat = Secret('threat'); FireEvent('UNIT_THREAT_SITUATION_UPDATE', 'nameplate1')
    assert(math.abs(plate.health.statusBarColor[1] - hostile[1]) < 1e-6, 'secret threat falls back to reaction')

    -- Friendly plates use their own settings.
    local player = AddPlate('nameplate2', Friendly({ isPlayer = true, class = 'MAGE' }))
    local p2 = M.byUnit.nameplate2
    assert(p2.kind == 'friendly' and math.abs(p2.width - 120) < 1, 'friendly plate, friendly width')
    assert(not p2.healthText:IsShown() and plate.healthText:IsShown(), 'health text per kind')
    local expected = addon.Domain.UnitColor.Class('MAGE')
    assert(math.abs(p2.health.statusBarColor[1] - Kit.Lighten({ expected.r, expected.g, expected.b }, 0.3)[1]) < 1e-6, 'class color')
    assert(M:SetOption('friendly', 'healthColorMode', 'reactionOnly'))
    assert(math.abs(p2.health.statusBarColor[2] - Kit.Lighten(P.green, 0.3)[2]) < 1e-6, 'reaction only: friendly green')
    assert(M.db.enemy.healthColorMode == 'reaction', 'enemy settings untouched')
    assert(not M:SetOption('friendly', 'healthColorMode', 'rainbow') and not M:SetOption('neutral', 'width', 100), 'refused')
    assert(M:SetOption('enemy', 'width', 180) and math.abs(plate.width - 180) < 1 and math.abs(p2.width - 120) < 1)

    -- A kind switched off goes back to Blizzard; on again re-attaches.
    assert(M:SetOption('friendly', 'show', false))
    assert(M.byUnit.nameplate2 == nil and player.UnitFrame:GetAlpha() == 1 and M.byUnit.nameplate1 == plate)
    assert(M:SetOption('friendly', 'show', true) and M.byUnit.nameplate2 and player.UnitFrame:GetAlpha() == 0)
    p2 = M.byUnit.nameplate2

    -- A unit that turns hostile switches to the enemy settings.
    units.nameplate2.canAttack = true; FireEvent('UNIT_FACTION', 'nameplate2')
    assert(M.byUnit.nameplate2.kind == 'enemy' and math.abs(M.byUnit.nameplate2.width - 180) < 1)
    units.nameplate2.canAttack = false; FireEvent('UNIT_FACTION', 'nameplate2')
    p2 = M.byUnit.nameplate2
    assert(p2.kind == 'friendly')

    -- Copy Style copies the look but not whether the kind is shown.
    assert(M:SetOption('friendly', 'show', false) and M:CopyStyle('enemy', 'friendly'))
    assert(M.db.friendly.width == 180 and M.db.friendly.show == false and M.db.friendly.healthColorMode == 'reaction')
    assert(M:ResetSettings('friendly') and M.db.friendly.width == 120 and M.db.friendly.show == false, 'reset keeps show')
    assert(M:SetOption('friendly', 'show', true))
    p2 = M.byUnit.nameplate2

    -- Target highlight compares nameplate frames, never secret units.
    nameplates.target = player; FireEvent('PLAYER_TARGET_CHANGED')
    assert(p2.targeted and p2.healthBox.rim.vertexColor[3] == P.accent[3] and not plate.targeted, 'target rim')
    nameplates.target = nil; FireEvent('PLAYER_TARGET_CHANGED')
    assert(not p2.targeted and p2.healthBox.rim.vertexColor[1] == Kit.onyx.border[1])

    -- Raid markers: a secret index goes only to SetSpriteSheetCell.
    units.nameplate1.raid = Secret('raid'); FireEvent('RAID_TARGET_UPDATE')
    assert(plate.raidIcon:IsShown() and issecretvalue(plate.raidIcon.spriteCell[1]) and plate.raidIcon.spriteCell[2] == 4)
    units.nameplate1.raid = nil; FireEvent('RAID_TARGET_UPDATE')
    assert(not plate.raidIcon:IsShown(), 'no marker, no icon')

    -- Casts: public times fill as time passes; secret interruptibility picks a color natively.
    local enemy = M.db.enemy
    units.nameplate1.cast = { name = 'Fireball', text = 'Fireball', icon = 135812, start = 100000, stop = 102000, locked = false }
    FireEvent('UNIT_SPELLCAST_START', 'nameplate1')
    assert(plate.castBox:IsShown() and plate.casting == 'cast' and plate.cast.low == 100000 and plate.cast.high == 102000)
    assert(plate.cast.value == 100000 and plate.castText.text == 'Fireball' and plate.castIcon.texture == 135812)
    assert(plate.cast:GetStatusBarTexture().vertexColor[1] == enemy.castColor[1], 'interruptible color')
    Advance(1)
    assert(plate.cast.value == 101000, 'the bar follows the clock')
    units.nameplate1.cast = { name = Secret('n'), text = Secret('t'), icon = Secret('i'), start = Secret('s'), stop = Secret('e'), locked = Secret('l') }
    FireEvent('UNIT_SPELLCAST_NOT_INTERRUPTIBLE', 'nameplate1')
    assert(issecretvalue(plate.cast.low) and issecretvalue(plate.castText.text) and issecretvalue(plate.castIcon.texture))
    local fromBool = plate.cast:GetStatusBarTexture().colorFromBoolean
    assert(fromBool and issecretvalue(fromBool[1]) and fromBool[2].r == enemy.castLockedColor[1], 'secret interruptibility')
    units.nameplate1.cast = nil
    units.nameplate1.channel = { name = 'Drain', text = 'Drain', icon = 1, start = 101000, stop = 104000, locked = true }
    FireEvent('UNIT_SPELLCAST_CHANNEL_START', 'nameplate1')
    assert(plate.casting == 'channel' and plate.cast.reverseFill == true, 'channels drain')
    assert(plate.cast.bg.vertexColor[1] == enemy.castLockedColor[1], 'locked channel color behind the bar')
    units.nameplate1.channel = nil; FireEvent('UNIT_SPELLCAST_CHANNEL_STOP', 'nameplate1')
    assert(not plate.castBox:IsShown() and plate.casting == nil and plate.cast.scripts.OnUpdate == nil, 'cast bar stops')

    -- The personal resource display and widget-only plates stay Blizzard's.
    units.nameplate3 = Friendly()
    local personal = CreateFrame('Frame', nil, UIParent)
    personal.UnitFrame = CreateFrame('Button', nil, personal); personal.UnitFrame:SetAlpha(1)
    nameplates.nameplate3, nameplates.player = personal, personal
    FireEvent('NAME_PLATE_UNIT_ADDED', 'nameplate3')
    assert(M.byUnit.nameplate3 == nil and personal.UnitFrame:GetAlpha() == 1, 'personal plate untouched')
    nameplates.player = nil
    local widgets = AddPlate('nameplate4', Hostile({ widgetsOnly = true }))
    assert(M.byUnit.nameplate4 == nil and widgets.UnitFrame:GetAlpha() == 1, 'widget-only plate untouched')

    -- Blizzard may acquire its frame after our handler runs.
    local late = AddPlate('nameplate5', Hostile(), false)
    assert(M.byUnit.nameplate5 and late.UnitFrame:GetAlpha() == 0, 'faded once acquired')

    -- A removed unit gives the pooled frame back at full alpha.
    local pooled = first.UnitFrame
    RemovePlate('nameplate1')
    assert(not plate:IsShown() and M.byUnit.nameplate1 == nil and pooled:GetAlpha() == 1, 'restored on removal')
    pooled:SetAlpha(0.5); assert(pooled:GetAlpha() == 0.5, 'no longer forced to 0')
    local again = AddPlate('nameplate1', Hostile())
    assert(M.byUnit.nameplate1 == plate and again.UnitFrame == pooled and pooled:GetAlpha() == 0, 'plates are reused')

    -- Settings change outside combat only.
    testCombat = true
    assert(not M:SetOption('enemy', 'width', 150) and enemy.width == 180, 'no settings changes in combat')
    testCombat = false
    assert(M:SetOption('enemy', 'showCastBar', false))
    units.nameplate1.cast = { name = 'X', text = 'X', icon = 1, start = 1, stop = 2, locked = false }
    FireEvent('UNIT_SPELLCAST_START', 'nameplate1')
    assert(not plate.castBox:IsShown(), 'cast bar off')
    units.nameplate1.cast = nil
    assert(M:SetOption('enemy', 'showCastBar', true))

    -- The settings preview draws both kinds with the plate code, live.
    SlashCmdList.MODEUI()
    addon:SelectConfigPage('nameplates')
    local page = addon.configWindow.pages.nameplates
    local view = page.configPreview
    assert(view and page.previewArea:IsShown() and not page.testDisplayButton:IsShown(), 'preview without a screen test')
    local sample, friend = view.plates.enemy, view.plates.friendly
    assert(sample:IsShown() and friend:IsShown() and sample:GetParent() == view.frame)
    assert(math.abs(sample.width - 180) < 1 and math.abs(friend.width - 120) < 1, 'sample sizes follow each kind')
    assert(sample.name.text == 'Enemy Nameplate' and sample.healthText.text == '72%' and sample.health.value == 72)
    assert(not friend.healthText:IsShown(), 'friendly sample hides health text like the setting')
    assert(sample.raidIcon:IsShown() and sample.raidIcon.spriteCell[1] == 8, 'skull marker sample')
    assert(sample.targeted and sample.healthBox.rim.vertexColor[3] == P.accent[3], 'sample target rim')
    assert(sample.castBox:IsShown() and sample.cast.value == 0.6 and sample.castText.text == 'Shadow Bolt')
    assert(M:SetOption('enemy', 'healthText', 'both') and sample.healthText.text == '8,640 · 72%', 'preview follows settings')
    assert(M:SetOption('enemy', 'targetHighlight', false) and not sample.targeted)
    assert(M:SetOption('friendly', 'show', false) and not friend:IsShown() and view.captions.friendly.text:find("Blizzard", 1, true))
    assert(M:SetOption('friendly', 'show', true) and friend:IsShown())
    -- Animated loops the cast.
    assert(addon.PreviewStates:SetPreviewMode('nameplates', 'animated'))
    assert(sample.cast.value == 0, 'animation starts at the beginning of the cast')
    Advance(0.5)
    assert(sample.cast.value > 0 and sample.cast.value < 1, 'the sample cast moves')
    assert(addon.PreviewStates:SetPreviewMode('nameplates', 'static') and sample.cast.value == 0.6)
    -- Editing switch: one choice across tabs.
    local switch = page.nameplateEditButtons[1]
    switch[2].scripts.OnClick(switch[2])
    assert(page.nameplateEditing() == 'friendly' and page.nameplateEditButtons[3][2].selected, 'one switch across tabs')
    addon.configWindow:Hide()

    -- Switching off restores every Blizzard plate and releases the events.
    addon:SetModuleEnabled('nameplates', false)
    assert(next(M.byUnit) == nil and again.UnitFrame:GetAlpha() == 1 and late.UnitFrame:GetAlpha() == 1)
    assert(not addon.Events:IsOn(M, 'NAME_PLATE_UNIT_ADDED') and not addon.Events:IsOn(M, 'UNIT_HEALTH'))
    AddPlate('nameplate6', Hostile())
    assert(M.byUnit.nameplate6 == nil, 'nothing attaches while off')
]==], "nameplates")

local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([==[
    local M = addon.Nameplates
    assert(not M.enabled and M.db.enemy.width == 180 and M.db.enemy.healthText == 'both', 'settings persist')
    assert(M.db.friendly.healthColorMode == 'reaction' and M.db.friendly.show == true)
]==], "nameplates_restore")

-- Version 1 settings (one set for every plate) become both kinds' settings.
local v1 = world.saved()
v1.profiles.Default.modules.nameplates = { enabled = true, version = 1, width = 200, healthHeight = 14, castHeight = 8,
    healthColorMode = 'onyx', softness = 30, healthColor = { 0.5, 0.8, 0.6 }, threatColors = false, healthText = 'current',
    healthFontSize = 9, showName = true, nameFontSize = 10, showCastBar = true, castFontSize = 8,
    castColor = { 0.9, 0.7, 0.3 }, castLockedColor = { 0.5, 0.5, 0.5 }, showRaidIcon = false, targetHighlight = true,
    texture = 'flat', font = 'game', fontMedia = 'Expressway', outline = true, shadow = true, liftedShadow = true,
    textColor = { 0.8, 0.8, 0.8 } }
local migrated = H.Load({ before = STUBS, saved = v1 })
migrated.run([==[
    local db = addon.Nameplates.db
    assert(db.version == 2 and db.width == nil and db.enabled == true, 'flat keys moved')
    for _, kind in ipairs({ 'enemy', 'friendly' }) do
        local style = db[kind]
        assert(style.width == 200 and style.healthColorMode == 'onyx' and style.texture == 'flat' and style.outline == true, kind)
        assert(style.show == true and style.showRaidIcon == false and style.healthText == 'current', kind)
    end
    assert(addon.modules.nameplates.enabled, 'module state kept')
]==], "nameplates_v1")

-- Invalid saved settings stop validation instead of being reset.
local broken = world.saved()
broken.profiles.Default.modules.nameplates.enemy.width = 'wide'
local ok = pcall(H.Load, { before = STUBS, saved = broken })
assert(not ok, 'invalid nameplate settings are refused, not reset')
print("nameplates: all checks passed")
