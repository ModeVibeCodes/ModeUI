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
    function Hostile(extra)
        local unit = { exists = true, health = Secret('hp'), max = Secret('max'), name = Secret('name'), reaction = 2, connected = true }
        for k, v in pairs(extra or {}) do unit[k] = v end
        return unit
    end
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, Kit = addon.Nameplates, addon.Kit
    assert(M and addon.modules.nameplates == M and M.category == 'interface' and not M.enabled, 'registered, off by default')
    assert(M.db.version == 1 and M.db.width == 140 and M.db.healthColorMode == 'reaction', 'defaults')
    assert(not addon.Events:IsOn(M, 'NAME_PLATE_UNIT_ADDED'), 'no events while off')

    -- A plate already on screen is picked up when the module is switched on.
    local first = AddPlate('nameplate1', Hostile())
    assert(first.UnitFrame:GetAlpha() == 1 and next(M.byUnit) == nil, 'nothing happens while off')
    addon:SetModuleEnabled('nameplates', true)
    local plate = M.byUnit.nameplate1
    assert(plate and plate:IsShown() and plate:GetParent() == first, 'attached to the game nameplate')
    assert(first.UnitFrame:GetAlpha() == 0, "Blizzard's art is faded")
    first.UnitFrame:SetAlpha(1)
    assert(first.UnitFrame:GetAlpha() == 0, 'kept faded when Blizzard resets the alpha')

    -- Secret health and names reach only the widgets that accept them.
    assert(issecretvalue(plate.health.value) and issecretvalue(plate.health.high), 'secret health on the bar')
    assert(type(plate.healthText.text) == 'table' and issecretvalue(plate.healthText.text.secret), 'secret percent formatted natively')
    assert(issecretvalue(plate.name.text) and issecretvalue(plate.name.lift.text), 'secret name on text and lift')

    -- Colors: hostile reaction, softened; threat wins when known.
    local P = Kit.palette
    local hostile = Kit.Lighten(P.hostile, M.db.softness / 100)
    assert(math.abs(plate.health.statusBarColor[1] - hostile[1]) < 1e-6, 'softened hostile color')
    units.nameplate1.threat = 3; FireEvent('UNIT_THREAT_SITUATION_UPDATE', 'nameplate1')
    assert(plate.health.statusBarColor[1] == M.threatPalette.aggro[1], 'aggro is red')
    units.nameplate1.threat = Secret('threat'); FireEvent('UNIT_THREAT_SITUATION_UPDATE', 'nameplate1')
    assert(math.abs(plate.health.statusBarColor[1] - hostile[1]) < 1e-6, 'secret threat falls back to reaction')

    -- Players use their class color in Reaction and Class mode only.
    local player = AddPlate('nameplate2', Hostile({ isPlayer = true, class = 'MAGE', reaction = 5 }))
    local p2 = M.byUnit.nameplate2
    local expected = addon.Domain.UnitColor.Class('MAGE')
    assert(math.abs(p2.health.statusBarColor[1] - Kit.Lighten({ expected.r, expected.g, expected.b }, 0.3)[1]) < 1e-6, 'class color')
    assert(M:SetOption('healthColorMode', 'reactionOnly'))
    assert(math.abs(p2.health.statusBarColor[2] - Kit.Lighten(P.green, 0.3)[2]) < 1e-6, 'reaction only: friendly green')
    assert(not M:SetOption('healthColorMode', 'rainbow') and M.db.healthColorMode == 'reactionOnly', 'unknown choices refused')

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
    units.nameplate1.cast = { name = 'Fireball', text = 'Fireball', icon = 135812, start = 100000, stop = 102000, locked = false }
    FireEvent('UNIT_SPELLCAST_START', 'nameplate1')
    assert(plate.castBox:IsShown() and plate.casting == 'cast' and plate.cast.low == 100000 and plate.cast.high == 102000)
    assert(plate.cast.value == 100000 and plate.castText.text == 'Fireball' and plate.castIcon.texture == 135812)
    assert(plate.cast:GetStatusBarTexture().vertexColor[1] == M.db.castColor[1], 'interruptible color')
    Advance(1)
    assert(plate.cast.value == 101000, 'the bar follows the clock')
    units.nameplate1.cast = { name = Secret('n'), text = Secret('t'), icon = Secret('i'), start = Secret('s'), stop = Secret('e'), locked = Secret('l') }
    FireEvent('UNIT_SPELLCAST_NOT_INTERRUPTIBLE', 'nameplate1')
    assert(issecretvalue(plate.cast.low) and issecretvalue(plate.castText.text) and issecretvalue(plate.castIcon.texture))
    local fromBool = plate.cast:GetStatusBarTexture().colorFromBoolean
    assert(fromBool and issecretvalue(fromBool[1]) and fromBool[2].r == M.db.castLockedColor[1], 'secret interruptibility')
    units.nameplate1.cast = nil
    units.nameplate1.channel = { name = 'Drain', text = 'Drain', icon = 1, start = 101000, stop = 104000, locked = true }
    FireEvent('UNIT_SPELLCAST_CHANNEL_START', 'nameplate1')
    assert(plate.casting == 'channel' and plate.cast.reverseFill == true, 'channels drain')
    assert(plate.cast.bg.vertexColor[1] == M.db.castLockedColor[1], 'locked channel color behind the bar')
    units.nameplate1.channel = nil; FireEvent('UNIT_SPELLCAST_CHANNEL_STOP', 'nameplate1')
    assert(not plate.castBox:IsShown() and plate.casting == nil and plate.cast.scripts.OnUpdate == nil, 'cast bar stops')

    -- The personal resource display and widget-only plates stay Blizzard's.
    -- The game returns the personal plate for "player" as well as its own token.
    units.nameplate3 = Hostile({ reaction = 5 })
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

    -- Settings: validated, outside combat only, and they relayout live plates.
    assert(not M:SetOption('width', 500) and M.db.width == 140)
    assert(M:SetOption('width', 200) and math.abs(plate.width - 200) < 1)
    testCombat = true
    assert(not M:SetOption('width', 150) and M.db.width == 200, 'no settings changes in combat')
    testCombat = false
    assert(M:SetOption('showCastBar', false))
    units.nameplate1.cast = { name = 'X', text = 'X', icon = 1, start = 1, stop = 2, locked = false }
    FireEvent('UNIT_SPELLCAST_START', 'nameplate1')
    assert(not plate.castBox:IsShown(), 'cast bar off')
    units.nameplate1.cast = nil

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
    assert(not M.enabled and M.db.width == 200 and M.db.showCastBar == false and M.db.healthColorMode == 'reactionOnly', 'settings persist')
    addon:SetModuleEnabled('nameplates', true)
    assert(M:ResetSettings() and M.db.width == 140 and M.db.enabled == true, 'reset keeps the module on')
]==], "nameplates_restore")

-- Invalid saved settings stop validation instead of being reset.
local broken = world.saved()
broken.profiles.Default.modules.nameplates.width = 'wide'
local ok = pcall(H.Load, { before = STUBS, saved = broken })
assert(not ok, 'invalid nameplate settings are refused, not reset')
print("nameplates: all checks passed")
