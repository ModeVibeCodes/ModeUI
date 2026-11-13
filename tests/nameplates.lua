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
    -- Auras: the stub applies filter strings the way the game does.
    local TOKENS = { PLAYER = 'player', RAID = 'raid', CROWD_CONTROL = 'cc', DISPELLABLE = 'dispellable', IMPORTANT = 'important' }
    function MatchesFilter(aura, filter)
        for part in filter:gmatch('[^|]+') do
            local token = part
            local negated = token:sub(1, 1) == '!'
            if negated then
                if testRejectNegation then error('Unknown aura filter component') end
                token = token:sub(2)
            end
            if token == 'HARMFUL' then if not aura.harmful then return false end
            elseif token == 'HELPFUL' then if aura.harmful then return false end
            elseif TOKENS[token] then if (aura[TOKENS[token]] == true) == negated then return false end end
        end
        return true
    end
    auraQueries = {}
    C_UnitAuras = {
        GetUnitAuras = function(unit, filter, max)
            auraQueries[#auraQueries + 1] = filter
            local list = {}
            for _, aura in ipairs(units[unit] and units[unit].auras or {}) do
                if MatchesFilter(aura, filter) and #list < max then list[#list + 1] = aura end
            end
            return list
        end,
        GetAuraApplicationDisplayCount = function(unit, id, minimum)
            for _, aura in ipairs(units[unit].auras) do
                if aura.auraInstanceID == id then
                    if issecretvalue(aura.applications) then return Secret('count') end
                    return (aura.applications or 0) >= minimum and tostring(aura.applications) or ''
                end
            end
            return ''
        end,
        GetAuraDuration = function(unit, id) if testDurationObjects then return { duration = id } end error('no duration objects') end,
    }
    function methods:SetCooldownFromDurationObject(object) self.durationObject = object end
    function methods:SetReverse(value) self.reverse = value end
    function methods:SetHideCountdownNumbers(value) self.hideNumbers = value end
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
    assert(M.db.version == 6 and M.db.enemy.width == 140 and M.db.friendly.width == 120, 'separate defaults per kind')
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

    -- Colors: the true hostile reaction color; threat wins when known.
    local hostile = P.hostile
    assert(plate.health.statusBarColor[1] == hostile[1] and plate.health.statusBarColor[4] == 1, 'true hostile color, opaque bar')
    assert(M.db.enemy.softness == nil and M.db.enemy.healthOpacity == 100 and M.db.enemy.backgroundOpacity == 55, 'opacity defaults')
    assert(math.abs(plate.health.bg.vertexColor[4] - 0.55) < 1e-9, 'see-through background by default')
    assert(M:SetOption('enemy', 'healthOpacity', 60) and math.abs(plate.health.statusBarColor[4] - 0.6) < 1e-9, 'Health Opacity fades the bar')
    assert(plate.health.statusBarColor[1] == hostile[1], 'fading keeps the color')
    assert(M:SetOption('enemy', 'backgroundOpacity', 20) and math.abs(plate.health.bg.vertexColor[4] - 0.2) < 1e-9, 'Background Opacity')
    assert(not M:SetOption('enemy', 'healthOpacity', 5) and not M:SetOption('enemy', 'backgroundOpacity', 120), 'opacity ranges')
    assert(not M:SetOption('enemy', 'softness', 30), 'Color Softness is gone')
    assert(M:SetOption('enemy', 'healthOpacity', 100) and M:SetOption('enemy', 'backgroundOpacity', 55))
    -- The rim and gap sit in four clipped bands around the bar, never behind it.
    local box = plate.healthBox
    assert(#box.bands == 4 and #box.rims == 4 and #box.gaps == 4 and #box.outlines == 4, 'four bands')
    for i, band in ipairs(box.bands) do
        assert(band.clipsChildren == true and box.rims[i]:GetParent() == band.layer, 'band ' .. i .. ' clips its copy')
        assert(box.rims[i].vertexColor[4] == 1 and box.gaps[i].vertexColor[4] == 1, 'solid rim and gap')
    end
    assert(box.bar:GetFrameLevel() > box.bands[1]:GetFrameLevel(), 'bar above the bands')
    assert(plate.castBox.bands == nil and plate.cast.bg.vertexColor[4] == 1, 'cast box keeps a solid background')
    -- The indicator reads level, classification and quest from the unit.
    assert(not plate.indicator:IsShown() and plate.indicatorWidth == 0, 'nothing known, nothing shown')
    local questUnits = {}
    function UnitLevel(u) return units[u] and units[u].level end
    function UnitClassification(u) return units[u] and units[u].classification end
    function UnitIsQuestBoss() return false end
    C_QuestLog = C_QuestLog or {}
    function C_QuestLog.UnitIsRelatedToActiveQuest(u) return questUnits[u] == true end
    units.nameplate1.level, units.nameplate1.classification = 61, 'rareelite'
    FireEvent('UNIT_LEVEL', 'nameplate1')
    assert(plate.indicator.level.text == '61' and plate.indicator.classification.atlas == 'nameplates-icon-elite-silver', 'level and rare elite')
    assert(not plate.indicator.quest:IsShown(), 'not a quest unit')
    questUnits.nameplate1 = true; FireEvent('QUEST_LOG_UPDATE')
    assert(plate.indicator.quest:IsShown(), 'quest unit after the quest log updates')
    units.nameplate1.level = Secret('level'); FireEvent('UNIT_LEVEL', 'nameplate1')
    assert(plate.indicator.level.text == '' and not plate.indicator.level:IsShown(), 'secret level hidden')
    units.nameplate1.level = -1; units.nameplate1.classification = 'worldboss'; FireEvent('UNIT_CLASSIFICATION_CHANGED', 'nameplate1')
    assert(plate.indicator.level.text == '??' and plate.indicator.classification.atlas == 'nameplates-icon-elite-gold', 'boss')
    questUnits.nameplate1, units.nameplate1.level, units.nameplate1.classification = nil, nil, nil
    FireEvent('QUEST_LOG_UPDATE')
    assert(not plate.indicator:IsShown(), 'cleared')
    units.nameplate1.threat = 3; FireEvent('UNIT_THREAT_SITUATION_UPDATE', 'nameplate1')
    assert(plate.health.statusBarColor[1] == M.threatPalette.aggro[1], 'aggro is red')
    -- Each threat status has its own color setting.
    assert(M:SetOption('enemy', 'threatAggroColor', { 0.1, 0.9, 0.2 }) and plate.health.statusBarColor[2] == 0.9, 'custom aggro color')
    assert(M:SetOption('enemy', 'threatLosingColor', { 0.9, 0.9, 0.1 }))
    assert(M:SetOption('enemy', 'threatPullingColor', { 0.2, 0.3, 0.95 }))
    units.nameplate1.threat = 2; FireEvent('UNIT_THREAT_SITUATION_UPDATE', 'nameplate1')
    assert(plate.health.statusBarColor[3] == 0.1 and plate.health.statusBarColor[1] == 0.9, 'losing aggro color')
    units.nameplate1.threat = 1; FireEvent('UNIT_THREAT_SITUATION_UPDATE', 'nameplate1')
    assert(plate.health.statusBarColor[3] == 0.95, 'close to pulling color')
    units.nameplate1.threat = 0; FireEvent('UNIT_THREAT_SITUATION_UPDATE', 'nameplate1')
    assert(plate.health.statusBarColor[1] == hostile[1], 'no threat: reaction color')
    assert(not M:SetOption('enemy', 'threatAggroColor', { 2, 0, 0 }), 'invalid threat color refused')
    assert(M:SetOption('enemy', 'threatAggroColor', M.threatPalette.aggro) and M:SetOption('enemy', 'threatLosingColor', M.threatPalette.warning)
        and M:SetOption('enemy', 'threatPullingColor', M.threatPalette.warning))
    units.nameplate1.threat = Secret('threat'); FireEvent('UNIT_THREAT_SITUATION_UPDATE', 'nameplate1')
    assert(math.abs(plate.health.statusBarColor[1] - hostile[1]) < 1e-6, 'secret threat falls back to reaction')

    -- Friendly plates use their own settings.
    local player = AddPlate('nameplate2', Friendly({ isPlayer = true, class = 'MAGE' }))
    local p2 = M.byUnit.nameplate2
    assert(p2.kind == 'friendly' and math.abs(p2.width - 120) < 1, 'friendly plate, friendly width')
    assert(not p2.healthText:IsShown() and plate.healthText:IsShown(), 'health text per kind')
    local expected = addon.Domain.UnitColor.Class('MAGE')
    assert(p2.health.statusBarColor[1] == expected.r and p2.health.statusBarColor[3] == expected.b, 'true class color')
    assert(M:SetOption('friendly', 'healthColorMode', 'reactionOnly'))
    assert(p2.health.statusBarColor[2] == P.green[2], 'reaction only: friendly green')
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
    assert(plate.castTimer.text == '2.0', 'timer from public cast times: ' .. tostring(plate.castTimer.text))
    Advance(1)
    assert(plate.cast.value == 101000, 'the bar follows the clock')
    assert(plate.castTimer.text == '1.0', 'timer counts down')
    units.nameplate1.cast = { name = Secret('n'), text = Secret('t'), icon = Secret('i'), start = Secret('s'), stop = Secret('e'), locked = Secret('l') }
    FireEvent('UNIT_SPELLCAST_NOT_INTERRUPTIBLE', 'nameplate1')
    assert(issecretvalue(plate.cast.low) and issecretvalue(plate.castText.text) and issecretvalue(plate.castIcon.texture))
    local fromBool = plate.cast:GetStatusBarTexture().colorFromBoolean
    assert(fromBool and issecretvalue(fromBool[1]) and fromBool[2].r == enemy.castLockedColor[1], 'secret interruptibility')
    assert(plate.castTimer.text == '', 'secret times and no duration object: empty timer')
    local remaining = Secret('remaining')
    function UnitCastingDuration() return { GetRemainingDuration = function() return remaining end } end
    FireEvent('UNIT_SPELLCAST_DELAYED', 'nameplate1')
    assert(type(plate.castTimer.text) == 'table' and plate.castTimer.text.secret, 'secret remaining time formatted natively')
    UnitCastingDuration = nil
    units.nameplate1.cast = nil
    units.nameplate1.channel = { name = 'Drain', text = 'Drain', icon = 1, start = 101000, stop = 104000, locked = true }
    FireEvent('UNIT_SPELLCAST_CHANNEL_START', 'nameplate1')
    assert(plate.casting == 'channel' and plate.cast.reverseFill == true, 'channels drain')
    assert(plate.cast.bg.vertexColor[1] == enemy.castLockedColor[1], 'locked channel color behind the bar')
    units.nameplate1.channel = nil; FireEvent('UNIT_SPELLCAST_CHANNEL_STOP', 'nameplate1')
    assert(not plate.castBox:IsShown() and plate.casting == nil and plate.cast.scripts.OnUpdate == nil, 'cast bar stops')

    -- Every bar is Mode Gradient; health and cast boxes share the same rounded rims.
    local rim, gapTexture = addon.Media:GetTexture('NameplateRim'), addon.Media:GetTexture('NameplateGap')
    assert(plate.health.statusBarTexture == Kit.FLAT and plate.health.sheen:IsShown() and plate.health.sheen.gradient, 'Mode Gradient health')
    assert(plate.cast.statusBarTexture == Kit.FLAT and plate.cast.sheen:IsShown(), 'Mode Gradient cast bar')
    assert(plate.healthBox.rim.texture == rim and plate.healthBox.gap.texture == gapTexture, 'rounded health box')
    assert(plate.castBox.rim.texture == rim and plate.castBox.gap.texture == gapTexture, 'cast box rounded like the health box')
    assert(plate.healthBox.rim.vertexColor[1] == Kit.onyx.border[1] and Kit.onyx.border[1] < 0.2, 'near-black rim')
    assert(not M:SetOption('enemy', 'texture', 'flat'), 'the old texture key is gone')
    -- Foreground and background textures, for the health and cast bars.
    assert(M.db.enemy.foregroundTexture == 'mode' and M.db.enemy.backgroundTexture == 'flat', 'texture defaults')
    assert(M:SetOption('enemy', 'foregroundTexture', 'flat') and plate.health.statusBarTexture == Kit.FLAT and not plate.health.sheen:IsShown(), 'flat foreground')
    assert(plate.cast.statusBarTexture == Kit.FLAT and not plate.cast.sheen:IsShown(), 'cast bar follows')
    assert(M:SetOption('enemy', 'foregroundTexture', 'media:Missing') and plate.health.sheen:IsShown(), 'missing media draws Mode Gradient')
    assert(M:SetOption('enemy', 'backgroundTexture', 'media:Missing') and plate.health.bg.texture == Kit.FLAT, 'missing media draws flat')
    assert(not M:SetOption('enemy', 'foregroundTexture', 'rainbow') and not M:SetOption('enemy', 'backgroundTexture', 'mode'), 'bad textures refused')
    local labels = {}
    for _, choice in ipairs(M.TextureChoices(true)) do labels[#labels + 1] = choice.id end
    assert(labels[1] == 'mode' and labels[2] == 'flat' and M.TextureChoices(false)[1].id == 'flat', 'texture choices')
    assert(M:SetOption('enemy', 'foregroundTexture', 'mode') and M:SetOption('enemy', 'backgroundTexture', 'flat'))
    assert(M:SetOption('enemy', 'castHeight', 4) and plate.castBox.rim.texture == rim, 'small cast bars stay rounded')
    assert(M:SetOption('enemy', 'castHeight', 8))

    -- Auras: three groups (crowd control, debuffs, buffs), each anchored on its own.
    local SNARE = { auraInstanceID = 11, icon = 'snare', harmful = true, cc = true, duration = 6, expirationTime = 105 }
    local DOT = { auraInstanceID = 12, icon = 'dot', harmful = true, player = true, applications = 3, duration = 18, expirationTime = 110 }
    local OTHER = { auraInstanceID = 13, icon = 'other', harmful = true, dispellable = true, duration = 0, expirationTime = 0 }
    local SHIELD = { auraInstanceID = 14, icon = 'shield', harmful = false, dispellable = true, duration = 15, expirationTime = 112 }
    local SECRET = { auraInstanceID = 15, icon = Secret('icon'), harmful = true, player = true, applications = Secret('n'), duration = Secret('d'), expirationTime = Secret('e') }
    units.nameplate1.auras = { SHIELD, OTHER, DOT, SNARE }
    FireEvent('UNIT_AURA', 'nameplate1')
    local A = plate.auraIcons
    assert(plate.auraShown.crowdControl == 1 and A.crowdControl[1].icon.texture == 'snare', 'crowd control group')
    assert(plate.auraShown.debuffs == 1 and A.debuffs[1].icon.texture == 'dot', 'your debuffs only')
    assert(plate.auraShown.buffs == 1 and A.buffs[1].icon.texture == 'shield', 'dispellable buffs')
    assert(plate.auraCount == 3)
    assert(A.debuffs[1].count.text == '3' and A.crowdControl[1].count.text == '', 'stack count from the game')
    assert(A.debuffs[1].cooldown.cooldownStart == 92 and A.debuffs[1].cooldown.cooldownDuration == 18 and A.debuffs[1].cooldown:IsShown())
    local negated = false
    for _, query in ipairs(auraQueries) do if query == 'HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL' then negated = true end end
    assert(negated, 'debuffs leave crowd control to its own group')
    -- Default anchors: crowd control Left (past the raid marker), debuffs Top, buffs Right.
    -- Icons are cropped (4px wider than tall) and placed by their corner on
    -- whole pixels from the health bar's bottom left (180 x 16 here).
    local function Corner(icon) local at = Point(icon); assert(at[1] == 'BOTTOMLEFT' and at[2] == plate.healthBox and at[3] == 'BOTTOMLEFT'); return at[4], at[5] end
    assert(math.abs(A.crowdControl[1].width - 24) < 1 and math.abs(A.crowdControl[1].height - 20) < 1, 'cropped 24 x 20')
    local x, y = Corner(A.crowdControl[1]); assert(x == -45 and y == -2, 'crowd control left of the marker: ' .. x .. ',' .. y)
    x, y = Corner(A.debuffs[1]); assert(x == 80 and y == 32, 'debuffs centered above the name: ' .. x .. ',' .. y)
    x, y = Corner(A.buffs[1]); assert(x == 182 and y == 1, 'buffs right of the bar: ' .. x .. ',' .. y)
    -- Target arrows sit outside the side aura rows (and the marker).
    assert(plate.auraExtent.LEFT == 47 and plate.auraExtent.RIGHT == 22, 'aura rows reach past the bar')
    -- Moving one group: anchor, offsets, size and count, all validated.
    assert(M:SetOption('enemy', 'anchor', 'BOTTOMRIGHT', 'debuffs'))
    x, y = Corner(A.debuffs[1]); assert(x == 160 and y == -42, 'bottom right, under the cast bar (and its target line): ' .. x .. ',' .. y)
    assert(M:SetOption('enemy', 'x', 5, 'debuffs') and select(1, Corner(A.debuffs[1])) == 165, 'offset X')
    assert(M:SetOption('enemy', 'y', -3, 'debuffs') and select(2, Corner(A.debuffs[1])) == -45, 'offset Y')
    assert(not M:SetOption('enemy', 'anchor', 'MIDDLE', 'debuffs') and not M:SetOption('enemy', 'x', 99, 'debuffs'), 'refused')
    assert(not M:SetOption('enemy', 'grow', 'sideways', 'debuffs'), 'unknown grow refused')
    assert(not M:SetOption('enemy', 'debuffs', {}) and not M:SetOption('enemy', 'filter', 'all', 'crowdControl'), 'one setting at a time')
    assert(M.db.friendly.debuffs.anchor == 'TOP', 'the other kind is untouched')
    -- Groups on the same anchor continue as one row in the first group's direction.
    assert(M:SetOption('enemy', 'anchor', 'TOP', 'debuffs') and M:SetOption('enemy', 'x', 0, 'debuffs') and M:SetOption('enemy', 'y', 0, 'debuffs'))
    assert(M:SetOption('enemy', 'anchor', 'TOP', 'buffs'))
    local dx, dy = Corner(A.debuffs[1]); local bx, by = Corner(A.buffs[1])
    assert(dx == 70 and dy == 32 and bx == 92 and by == 32, 'one centered row: ' .. dx .. ',' .. dy .. ' ' .. bx .. ',' .. by)
    assert(M:SetOption('enemy', 'anchor', 'RIGHT', 'buffs'))
    -- Grow directions.
    assert(M:SetOption('enemy', 'filter', 'all', 'debuffs') and M:SetOption('enemy', 'anchor', 'TOPLEFT', 'debuffs'))
    assert(M:SetOption('enemy', 'grow', 'right', 'debuffs'))
    local x1, y1 = Corner(A.debuffs[1]); local x2, y2 = Corner(A.debuffs[2])
    assert(x1 == 0 and x2 == 22 and y1 == y2, 'grow right from the left edge')
    assert(M:SetOption('enemy', 'grow', 'left', 'debuffs'))
    x1, y1 = Corner(A.debuffs[1]); x2, y2 = Corner(A.debuffs[2])
    assert(x1 == 0 and x2 == -22 and y1 == y2, 'grow left')
    assert(M:SetOption('enemy', 'grow', 'up', 'debuffs'))
    x1, y1 = Corner(A.debuffs[1]); x2, y2 = Corner(A.debuffs[2])
    assert(x1 == x2 and y2 == y1 + 18, 'grow up')
    assert(M:SetOption('enemy', 'grow', 'down', 'debuffs'))
    x1, y1 = Corner(A.debuffs[1]); x2, y2 = Corner(A.debuffs[2])
    assert(x1 == x2 and y2 == y1 - 18, 'grow down')
    assert(M:SetOption('enemy', 'anchor', 'TOP', 'debuffs') and M:SetOption('enemy', 'grow', 'center', 'debuffs'))
    assert(M:SetOption('enemy', 'filter', 'mine', 'debuffs'))
    -- Square icons and border colors by dispel type.
    assert(M:SetOption('enemy', 'auraShape', 'square') and math.abs(A.buffs[1].height - 18) < 1, 'square icons')
    assert(M:SetOption('enemy', 'auraShape', 'cropped'))
    local savedAuras = units.nameplate1.auras
    units.nameplate1.auras = { { auraInstanceID = 21, icon = 'poison', harmful = true, player = true, dispelName = 'Poison', duration = 5, expirationTime = 103 },
        { auraInstanceID = 22, icon = 'hidden', harmful = true, player = true, dispelName = Secret('type'), duration = 5, expirationTime = 103 } }
    FireEvent('UNIT_AURA', 'nameplate1')
    assert(A.debuffs[1].rim.vertexColor[1] == M.db.enemy.auraPoisonColor[1], 'Poison rim from the public dispel type')
    assert(A.debuffs[2].rim.vertexColor[1] == Kit.onyx.border[1], 'a secret dispel type keeps the Mode rim')
    units.nameplate1.auras = savedAuras; FireEvent('UNIT_AURA', 'nameplate1')
    assert(M:SetOption('enemy', 'size', 30, 'debuffs') and math.abs(A.debuffs[1].width - 30) < 1, 'icon size per group')
    assert(M:SetOption('enemy', 'size', 20, 'debuffs'))
    assert(M:SetOption('enemy', 'filter', 'all', 'debuffs') and plate.auraShown.debuffs == 2)
    assert(A.debuffs[1].icon.texture == 'other' and A.debuffs[2].icon.texture == 'dot', 'all debuffs, in the order the game returns them')
    assert(M:SetOption('enemy', 'max', 1, 'debuffs') and plate.auraShown.debuffs == 1 and not A.debuffs[2]:IsShown(), 'most shown')
    assert(M:SetOption('enemy', 'max', 6, 'debuffs'))
    assert(M:SetOption('enemy', 'show', false, 'crowdControl') and plate.auraShown.crowdControl == 0)
    assert(plate.auraShown.debuffs == 3, 'without its own group, crowd control is a debuff again')
    assert(not A.debuffs[1].cooldown:IsShown(), 'permanent aura: no swipe')
    assert(M:SetOption('enemy', 'auraTimer', false) and not A.debuffs[2].cooldown:IsShown())
    assert(M:SetOption('enemy', 'auraCount', false) and A.debuffs[2].count.text == '')
    assert(M:SetOption('enemy', 'auraTimer', true) and M:SetOption('enemy', 'auraCount', true))
    assert(M:SetOption('enemy', 'show', true, 'crowdControl') and M:SetOption('enemy', 'filter', 'mine', 'debuffs'))
    -- Secret auras: icon and count go only to SetTexture and SetText; no swipe from secret times.
    units.nameplate1.auras = { SECRET }; FireEvent('UNIT_AURA', 'nameplate1')
    assert(plate.auraShown.debuffs == 1 and issecretvalue(A.debuffs[1].icon.texture) and issecretvalue(A.debuffs[1].count.text))
    assert(not A.debuffs[1].cooldown:IsShown(), 'no swipe from secret times without a duration object')
    testDurationObjects = true; FireEvent('UNIT_AURA', 'nameplate1')
    assert(A.debuffs[1].cooldown.durationObject and A.debuffs[1].cooldown:IsShown(), 'duration object drawn natively')
    testDurationObjects = nil
    -- A client that rejects the negation still shows debuffs.
    testRejectNegation = true; units.nameplate1.auras = { DOT }; FireEvent('UNIT_AURA', 'nameplate1')
    assert(plate.auraShown.debuffs == 1 and A.debuffs[1].icon.texture == 'dot', 'negation retried without it')
    testRejectNegation = nil
    assert(M:SetOption('enemy', 'showAuras', false) and plate.auraCount == 0 and not A.debuffs[1]:IsShown(), 'auras off')
    assert(M:SetOption('enemy', 'showAuras', true))
    units.nameplate1.auras = nil; FireEvent('UNIT_AURA', 'nameplate1')
    assert(plate.auraCount == 0)

    -- Pickups and other objects keep a plate but show no health text; only
    -- players are ever "Offline" (the game reports objects as not connected).
    function UnitIsGameObject(u) return units[u] and units[u].object == true end
    local pickup = AddPlate('nameplate7', Friendly({ name = 'Rocket Car Rubble', connected = false, object = true, health = 0, max = 0 }))
    assert(M.byUnit.nameplate7 and pickup.UnitFrame:GetAlpha() == 0, 'objects keep a plate')
    assert(M:SetOption('friendly', 'healthText', 'percent'))
    assert(M.byUnit.nameplate7.healthText.text == '', 'no Offline or other text on an object')
    units.nameplate7.object = false; FireEvent('UNIT_HEALTH', 'nameplate7')
    assert(M.byUnit.nameplate7.healthText.text ~= 'Offline', 'an NPC is never Offline')
    units.nameplate7.isPlayer = true; FireEvent('UNIT_HEALTH', 'nameplate7')
    assert(M.byUnit.nameplate7.healthText.text == 'Offline', 'a disconnected player is Offline')
    assert(M:SetOption('friendly', 'healthText', 'none'))
    RemovePlate('nameplate7')

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

    -- The settings preview shows one sample at a time: the kind being edited.
    SlashCmdList.MODEUI()
    addon:SelectConfigPage('nameplates')
    local page = addon.configWindow.pages.nameplates
    local view = page.configPreview
    assert(view and page.previewArea:IsShown() and not page.testDisplayButton:IsShown(), 'preview without a screen test')
    local sample, friend = view.plates.enemy, view.plates.friendly
    assert(sample:IsShown() and not friend:IsShown() and sample:GetParent() == view.frame, 'only the enemy sample while editing Enemy')
    local at = Point(sample)
    assert(at[1] == 'TOPLEFT' and at[2] == view.frame and at[3] == 'TOP' and at[4] == -90, 'centered on whole pixels')
    assert(math.abs(sample.width - 180) < 1, 'sample size follows the kind')
    assert(sample.name.text == 'Enemy Nameplate' and sample.healthText.text == '72%' and sample.health.value == 72)
    assert(sample.raidIcon:IsShown() and sample.raidIcon.spriteCell[1] == 8, 'skull marker sample')
    assert(sample.targeted and sample.healthBox.rim.vertexColor[3] == P.accent[3], 'sample target rim')
    assert(sample.castBox:IsShown() and sample.cast.value == 0.6 and sample.castText.text == 'Shadow Bolt')
    local function Shown(p, group)
        local n = 0
        for _, icon in ipairs(p.auraIcons[group]) do if icon:IsShown() then n = n + 1 end end
        return n
    end
    assert(Shown(sample, 'crowdControl') == 1 and Shown(sample, 'debuffs') == 1 and Shown(sample, 'buffs') == 1, 'enemy sample auras')
    assert(sample.auraIcons.debuffs[1].rim.vertexColor[1] == M.db.enemy.auraMagicColor[1], 'Magic rim by type')
    assert(M:SetOption('enemy', 'auraBorder', 'mode') and sample.auraIcons.debuffs[1].rim.vertexColor[1] == Kit.onyx.border[1], 'Mode rim')
    assert(M:SetOption('enemy', 'auraBorder', 'type'))
    -- Switching Editing switches the sample.
    page.SetEditing('friendly')
    assert(friend:IsShown() and not sample:IsShown() and math.abs(friend.width - 120) < 1, 'friendly sample while editing Friendly')
    assert(Shown(friend, 'debuffs') == 1 and Shown(friend, 'buffs') == 0 and Shown(friend, 'crowdControl') == 0, 'friendly sample auras')
    assert(friend.auraIcons.debuffs[1].rim.vertexColor[1] == M.db.friendly.auraDiseaseColor[1], 'Disease rim')
    assert(M:SetOption('friendly', 'show', true, 'buffs') and Shown(friend, 'buffs') == 1, 'preview follows each group')
    -- Name Only: just the class-colored name.
    assert(M:SetOption('friendly', 'display', 'name'))
    assert(not friend.healthBox:IsShown() and not friend.castBox:IsShown() and friend.name:IsShown() and not friend.healthText:IsShown(), 'name only')
    local mage = addon.Domain.UnitColor.Class('MAGE')
    assert(friend.name.color[1] == mage.r and friend.name.color[3] == mage.b, 'true class-colored name')
    assert(M:SetOption('friendly', 'display', 'plate') and friend.healthBox:IsShown())
    assert(M:SetOption('friendly', 'show', false) and not friend:IsShown() and view.captions.friendly.text:find("Blizzard", 1, true))
    assert(M:SetOption('friendly', 'show', true) and friend:IsShown())
    page.SetEditing('enemy')
    -- Settings follow into the sample.
    assert(M:SetOption('enemy', 'healthText', 'both') and sample.healthText.text == '8,640 · 72%', 'preview follows settings')
    -- Target styles.
    assert(M:SetOption('enemy', 'targetStyle', 'glow') and sample.targetGlow:IsShown() and sample.healthBox.rim.vertexColor[1] == Kit.onyx.border[1], 'glow')
    assert(M:SetOption('enemy', 'targetStyle', 'arrows') and sample.arrows.left:IsShown() and sample.arrows.right:IsShown() and not sample.targetGlow:IsShown(), 'arrows')
    assert(sample.arrows.right.texCoord[1] == 1, 'right arrow mirrored')
    local leftArrow, rightArrow = Point(sample.arrows.left), Point(sample.arrows.right)
    assert(-leftArrow[4] >= sample.auraExtent.LEFT + M.db.enemy.targetArrowGap and sample.auraExtent.LEFT > 0, 'left arrow outside the crowd control row')
    assert(rightArrow[4] >= sample.auraExtent.RIGHT + M.db.enemy.targetArrowGap and sample.auraExtent.RIGHT > 0, 'right arrow outside the buffs row')
    assert(M:SetOption('enemy', 'targetArrowGap', 60) and M:SetOption('enemy', 'targetArrowSize', 48) and M:SetOption('enemy', 'targetArrowGap', 4)
        and M:SetOption('enemy', 'targetArrowSize', 12), 'wider arrow ranges')
    assert(M:SetOption('enemy', 'targetStyle', 'borderArrows') and sample.arrows.left:IsShown() and sample.healthBox.rim.vertexColor[3] == P.accent[3])
    assert(M:SetOption('enemy', 'targetThickness', 3) and sample.targetOutline:IsShown() and Point(sample.targetOutline)[4] == -2, '3px border')
    assert(M:SetOption('enemy', 'targetStyle', 'none') and not sample.targeted and not sample.arrows.left:IsShown())
    assert(M:SetOption('enemy', 'targetStyle', 'border') and M:SetOption('enemy', 'targetThickness', 1))
    -- Element placement: name, health text, raid marker, cast bar.
    assert(M:SetOption('enemy', 'nameAnchor', 'CENTER') and Point(sample.name)[2] == sample.health and Point(sample.name)[1] == 'CENTER', 'name inside the bar')
    assert(M:SetOption('enemy', 'nameAnchor', 'BOTTOMLEFT') and Point(sample.name)[1] == 'TOPLEFT' and Point(sample.name)[3] == 'BOTTOMLEFT')
    assert(M:SetOption('enemy', 'nameAnchor', 'TOP') and M:SetOption('enemy', 'nameX', 4) and Point(sample.name)[4] == 4, 'name offset')
    assert(M:SetOption('enemy', 'nameX', 0))
    assert(M:SetOption('enemy', 'healthTextAnchor', 'LEFT') and Point(sample.healthText)[1] == 'LEFT' and Point(sample.healthText)[4] == 2)
    assert(M:SetOption('enemy', 'raidAnchor', 'TOPRIGHT') and Point(sample.raidIcon)[1] == 'BOTTOMRIGHT' and Point(sample.raidIcon)[3] == 'TOPRIGHT')
    assert(M:SetOption('enemy', 'raidSize', 24) and math.abs(sample.raidIcon.width - 24) < 1)
    assert(M:SetOption('enemy', 'raidAnchor', 'LEFT') and M:SetOption('enemy', 'raidSize', 16) and M:SetOption('enemy', 'healthTextAnchor', 'RIGHT'))
    assert(M:SetOption('enemy', 'castAnchor', 'TOP') and Point(sample.castBox)[1] == 'BOTTOMLEFT' and Point(sample.castBox)[3] == 'TOPLEFT', 'cast bar above')
    assert(Point(sample.name)[5] == 2 + sample.castBarHeight + 2 + M:CastTargetHeight(sample), 'name moves above the cast bar and its target line')
    assert(Point(sample.castTarget)[1] == 'BOTTOM' and Point(sample.castTarget)[3] == 'TOP', 'target line above an upper cast bar')
    assert(M:SetOption('enemy', 'castAnchor', 'BOTTOM') and M:SetOption('enemy', 'castY', -3) and Point(sample.castBox)[5] == -5)
    assert(M:SetOption('enemy', 'castY', 0))
    -- Cast bar content: icon side, spell name, target line and timer.
    assert(sample.castTarget.text == 'Mode' and sample.castTarget:IsShown(), 'cast target in the sample')
    local paladin = addon.Domain.UnitColor.Class('PALADIN')
    assert(sample.castTarget.color[1] == paladin.r, 'target in its class color')
    assert(sample.castTimer:IsShown() and sample.castTimer.text == '1.0', 'timer shows seconds left: ' .. tostring(sample.castTimer.text))
    assert(Point(sample.castText)[1] == 'LEFT' and Point(sample.castIcon)[1] == 'TOPLEFT', 'icon on the left')
    assert(M:SetOption('enemy', 'castIcon', 'RIGHT') and Point(sample.castIcon)[1] == 'TOPRIGHT' and sample.castIcon:IsShown(), 'icon on the right')
    assert(M:SetOption('enemy', 'castIcon', 'none') and not sample.castIcon:IsShown() and Point(sample.cast)[2] == sample.castBox, 'icon hidden')
    assert(M:SetOption('enemy', 'castShowTimer', false) and not sample.castTimer:IsShown(), 'timer off')
    assert(M:SetOption('enemy', 'castShowTarget', false) and not sample.castTarget:IsShown() and M:CastTargetHeight(sample) == 0, 'target off')
    assert(M:SetOption('enemy', 'castShowText', false) and not sample.castText:IsShown(), 'spell name off')
    assert(not M:SetOption('enemy', 'castIcon', 'TOP'), 'bad icon side refused')
    assert(M:SetOption('enemy', 'castIcon', 'LEFT') and M:SetOption('enemy', 'castShowTimer', true)
        and M:SetOption('enemy', 'castShowTarget', true) and M:SetOption('enemy', 'castShowText', true))
    -- Animated loops the cast.
    assert(addon.PreviewStates:SetPreviewMode('nameplates', 'animated'))
    assert(sample.cast.value == 0, 'animation starts at the beginning of the cast')
    Advance(0.5)
    assert(sample.cast.value > 0 and sample.cast.value < 1, 'the sample cast moves')
    assert(addon.PreviewStates:SetPreviewMode('nameplates', 'static') and sample.cast.value == 0.6)
    -- Tabs, cards and the Editing switch.
    local sections = {}
    for _, section in ipairs(page.sections) do sections[#sections + 1] = section.title end
    assert(table.concat(sections, ',') == 'Nameplates,Text,Cast Bar,Auras,Target,Indicators', table.concat(sections, ','))
    assert(#page.cards > 5 and page.cards[1].frame:IsShown(), 'settings sit on cards')
    local switch = page.nameplateEditButtons[1]
    switch[2].scripts.OnClick(switch[2])
    assert(page.nameplateEditing() == 'friendly' and page.nameplateEditButtons[3][2].selected, 'one switch across tabs')
    local editingRow = switch[1]:GetParent().row
    assert(Point(editingRow.settingsLabel)[1] == 'LEFT', 'the Editing label is centered with its pills')
    -- Clicking a part of the sample jumps to its settings.
    local hits = view.targets.friendly
    hits.cast.scripts.OnEnter(hits.cast)
    assert(hits.cast.jumpHighlight:IsShown(), 'parts light up under the mouse')
    hits.cast.scripts.OnLeave(hits.cast)
    hits.cast.scripts.OnMouseUp(hits.cast, 'LeftButton')
    assert(page.nameplateEditing() == 'friendly' and page.selectedSection.title == 'Cast Bar', 'cast bar click opens Cast Bar')
    page.SetEditing('enemy')
    view.targets.enemy.name.scripts.OnMouseUp(view.targets.enemy.name, 'LeftButton')
    assert(page.nameplateEditing() == 'enemy' and page.selectedSection.title == 'Text', 'name click opens Text')
    -- Text inside the bar takes clicks only where it is written, so the bar
    -- beside it opens the health settings.
    local textHit = view.targets.enemy.healthText
    assert(textHit.width < sample.health:GetWidth() and Point(textHit)[1] == 'RIGHT', 'health text hit fits the text')
    view.targets.enemy.health.scripts.OnMouseUp(view.targets.enemy.health, 'LeftButton')
    assert(page.selectedSection.title == 'Nameplates', 'health click opens Nameplates')
    view.targets.enemy.markers.scripts.OnMouseUp(view.targets.enemy.markers, 'LeftButton')
    assert(page.selectedSection.title == 'Indicators', 'marker click opens Indicators')
    -- The indicator: quest icon, classification icon and level, side by side.
    local ind = sample.indicator
    assert(ind:IsShown() and ind.quest:IsShown() and ind.quest.atlas == M.QUEST_ATLAS, 'quest icon')
    assert(ind.classification.atlas == 'nameplates-icon-elite-gold' and ind.level.text == '62', 'elite icon and level')
    assert(Point(ind.classification)[4] == ind.quest.width + 2 and sample.indicatorWidth > 2 * M.db.enemy.indicatorSize, 'laid out left to right')
    -- On the left it sits past the raid marker, and crowd control past both.
    assert(Point(ind)[1] == 'RIGHT' and Point(ind)[4] == -3 - (sample.markSize + 3), 'indicator past the marker')
    assert(M:SideRoom(sample, 'LEFT') == sample.markSize + 3 + sample.indicatorWidth + 3, 'side room counts the indicator')
    assert(M:SetOption('enemy', 'indicatorQuest', false) and not ind.quest:IsShown() and Point(ind.classification)[4] == 0, 'quest off')
    assert(M:SetOption('enemy', 'indicatorAnchor', 'TOPRIGHT') and Point(ind)[1] == 'BOTTOMRIGHT', 'indicator anchor')
    assert(M:SideRoom(sample, 'LEFT') == sample.markSize + 3, 'no side room when moved')
    assert(M:SetOption('enemy', 'showIndicator', false) and not ind:IsShown() and sample.indicatorWidth == 0, 'indicator off')
    assert(not M:SetOption('enemy', 'indicatorSize', 99) and not M:SetOption('enemy', 'indicatorAnchor', 'MIDDLE'), 'refused')
    assert(M:SetOption('enemy', 'showIndicator', true) and M:SetOption('enemy', 'indicatorQuest', true) and M:SetOption('enemy', 'indicatorAnchor', 'LEFT'))
    assert(M.db.friendly.showIndicator == false, 'friendly plates start without the indicator')
    view.targets.enemy.indicator.scripts.OnMouseUp(view.targets.enemy.indicator, 'LeftButton')
    assert(page.selectedSection.title == 'Indicators', 'indicator click opens Indicators')
    local buffIcon = sample.auraIcons.buffs[1]
    buffIcon.scripts.OnMouseUp(buffIcon, 'LeftButton')
    assert(page.selectedSection.title == 'Auras' and page.nameplateAuraGroup() == 'buffs', 'aura click opens its group')
    assert(page.auraAnchorButtons.RIGHT.selected and not page.auraAnchorButtons.TOP.selected, 'the anchor picker shows the group')
    page.auraAnchorButtons.BOTTOMLEFT.scripts.OnClick(page.auraAnchorButtons.BOTTOMLEFT)
    assert(M.db.enemy.buffs.anchor == 'BOTTOMLEFT' and page.auraAnchorButtons.BOTTOMLEFT.selected, 'picking an anchor')
    assert(M:SetOption('enemy', 'anchor', 'RIGHT', 'buffs'))
    assert(page.nameAnchorButtons.CENTER, 'text anchors include the middle')
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
    assert(db.version == 6 and db.width == nil and db.texture == nil and db.enabled == true, 'flat keys moved')
    for _, kind in ipairs({ 'enemy', 'friendly' }) do
        local style = db[kind]
        assert(style.width == 200 and style.healthColorMode == 'onyx' and style.texture == nil and style.outline == true, kind)
        assert(style.show == true and style.showRaidIcon == false and style.healthText == 'current', kind)
    end
    assert(addon.modules.nameplates.enabled, 'module state kept')
]==], "nameplates_v1")

-- Version 2 settings lose the texture choice and gain aura defaults.
local v2 = world.saved()
local np = v2.profiles.Default.modules.nameplates
np.version = 2
for _, kind in ipairs({ 'enemy', 'friendly' }) do
    np[kind].texture = 'satin'
    for key in pairs(np[kind]) do
        if key:find('^aura') or key == 'showAuras' or key == 'crowdControl' or key == 'debuffs' or key == 'buffs' then np[kind][key] = nil end
    end
end
H.Load({ before = STUBS, saved = v2 }).run([==[
    local db = addon.Nameplates.db
    assert(db.version == 6 and db.enemy.texture == nil and db.friendly.texture == nil, 'texture retired')
    assert(db.enemy.showAuras and db.enemy.debuffs.filter == 'mine' and db.friendly.debuffs.filter == 'dispellable', 'aura defaults')
    assert(db.enemy.width == 180, 'other settings kept')
]==], "nameplates_v2")

-- Version 3's single aura row becomes three groups placed where it was.
local v3 = world.saved()
np = v3.profiles.Default.modules.nameplates
np.version = 3
local old = np.enemy
old.crowdControl, old.debuffs, old.buffs = nil, nil, nil
old.auraCrowdControl, old.auraDebuffs, old.auraBuffs = true, 'all', 'none'
old.auraPosition, old.auraAlign, old.auraSize, old.auraMax = 'below', 'right', 22, 5
H.Load({ before = STUBS, saved = v3 }).run([==[
    local style = addon.Nameplates.db.enemy
    assert(addon.Nameplates.db.version == 6 and style.auraPosition == nil and style.auraDebuffs == nil and style.auraSize == nil, 'old keys gone')
    for _, group in ipairs({ 'crowdControl', 'debuffs', 'buffs' }) do
        assert(style[group].anchor == 'BOTTOMRIGHT' and style[group].size == 22 and style[group].max == 5, group .. ' where the row was')
        assert(style[group].grow == 'left', group .. ' grows the way its anchor did')
    end
    assert(style.crowdControl.show and style.debuffs.show and style.debuffs.filter == 'all', 'choices kept')
    assert(not style.buffs.show and style.buffs.filter == 'dispellable', 'None becomes hidden')
]==], "nameplates_v3")

-- Version 4: the target highlight switch becomes a target style, and groups gain grow directions.
local v4 = world.saved()
np = v4.profiles.Default.modules.nameplates
np.version = 4
np.enemy.targetHighlight, np.friendly.targetHighlight = false, true
np.enemy.targetStyle, np.friendly.targetStyle = nil, nil
for _, kind in ipairs({ 'enemy', 'friendly' }) do
    for _, group in ipairs({ 'crowdControl', 'debuffs', 'buffs' }) do np[kind][group].grow = nil end
end
np.enemy.debuffs.anchor = 'TOPRIGHT'
H.Load({ before = STUBS, saved = v4 }).run([==[
    local db = addon.Nameplates.db
    assert(db.version == 6 and db.enemy.targetHighlight == nil and db.enemy.targetStyle == 'none' and db.friendly.targetStyle == 'border')
    assert(db.enemy.debuffs.grow == 'left' and db.enemy.crowdControl.grow == 'left' and db.enemy.buffs.grow == 'right', 'grow from anchors')
    assert(db.enemy.display == 'plate' and db.enemy.nameAnchor == 'TOP' and db.enemy.raidSize == 16, 'new settings take defaults')
]==], "nameplates_v4")

-- Version 5: Color Softness is retired and the opacities take defaults.
local v5 = world.saved()
np = v5.profiles.Default.modules.nameplates
np.version = 5
np.enemy.softness, np.friendly.softness = 30, 0
np.enemy.healthOpacity, np.enemy.backgroundOpacity = nil, nil
np.friendly.healthOpacity, np.friendly.backgroundOpacity = nil, nil
H.Load({ before = STUBS, saved = v5 }).run([==[
    local db = addon.Nameplates.db
    assert(db.version == 6 and db.enemy.softness == nil and db.friendly.softness == nil, 'softness removed')
    assert(db.enemy.healthOpacity == 100 and db.enemy.backgroundOpacity == 55 and db.friendly.backgroundOpacity == 55, 'opacity defaults')
    assert(db.enemy.width == 180, 'other settings kept')
]==], "nameplates_v5")

-- Invalid saved settings stop validation instead of being reset.
local broken = world.saved()
broken.profiles.Default.modules.nameplates.enemy.width = 'wide'
local ok = pcall(H.Load, { before = STUBS, saved = broken })
assert(not ok, 'invalid nameplate settings are refused, not reset')
print("nameplates: all checks passed")
