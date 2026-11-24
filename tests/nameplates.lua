-- Nameplates: attaching to game nameplates, fading Blizzard's art, health,
-- colors, threat, raid markers, target highlight, cast bars with secret values,
-- settings and persistence. Simulated client; not WoW rendering or security.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. [==[
    local methods = getmetatable(UIParent).__index
    function methods:SetSpriteSheetCell(index, rows, columns) self.spriteCell = { index, rows, columns } end
    -- Animation groups: records what a flipbook is set to and whether it plays.
    function methods:CreateAnimationGroup()
        local group = { anims = {} }
        function group:CreateAnimation(kind)
            local anim = { kind = kind }
            setmetatable(anim, { __index = function(_, key) return function(self, ...) self[key .. 'Args'] = { ... } end end })
            self.anims[#self.anims + 1] = anim
            return anim
        end
        function group:SetLooping(mode) self.looping = mode end
        function group:Play() self.playing = true end
        function group:Stop() self.playing = false end
        function group:IsPlaying() return self.playing == true end
        return group
    end
    function methods:SetVertexColorFromBoolean(value, ifTrue, ifFalse) self.colorFromBoolean = { value, ifTrue, ifFalse } end
    function methods:SetReverseFill(value) assert(type(value) == "boolean", "Usage: self:SetReverseFill(isReverseFill)"); self.reverseFill = value end

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
    -- Puts both kinds back on version 11's layout (Indicators First, the name
    -- above the bar, the marker and indicators beside it, crowd control left,
    -- debuffs centered on top), so the checks written for it keep guarding it.
    function UseV11(M, only)
        for _, kind in ipairs(M.kinds) do if not only or only == kind then
            local style = M.db[kind]
            for key, value in pairs(M.V11[kind]) do style[key] = value end
            style.castColor, style.castLockedColor = addon.ProfileCodec.Copy(addon.Kit.palette.neutral), addon.ProfileCodec.Copy(addon.Kit.palette.tapped)
            style.nameOnBorder, style.auraOrder, style.comboFollowCast = false, 'indicators', false
            style.levelInside, style.classificationInside, style.raidAnchor, style.nameAnchor, style.nameY = false, false, 'LEFT', 'TOP', 0
            style.nameColorMode = 'class'
            if kind == 'enemy' then
                style.crowdControl.anchor, style.crowdControl.grow, style.crowdControl.size = 'LEFT', 'left', 24
                style.debuffs.anchor, style.debuffs.grow, style.debuffs.size, style.debuffs.max, style.debuffs.attach = 'TOP', 'center', 20, 6, false
                style.buffs.size = 18
            end
        end end
    end
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, Kit = addon.Nameplates, addon.Kit
    local P = Kit.palette
    assert(M and addon.modules.nameplates == M and M.category == 'frames' and not M.enabled, 'registered under Frames, off by default')
    assert(M.db.version == 14 and M.db.enemy.width == 156 and M.db.enemy.healthHeight == 16 and M.db.friendly.width == 120, 'separate defaults per kind')
    -- The owner's baseline (November 23, 2026): the name on the top border at
    -- the top left, your debuffs on the same line top right, crowd control above,
    -- buffs right, quest left, the marker, level and elite inside, arrows.
    local E, F = M.db.enemy, M.db.friendly
    assert(E.nameOnBorder and E.nameAnchor == 'TOPLEFT' and E.nameY == -3 and E.nameFontSize == 14, 'name on the border')
    assert(E.debuffs.anchor == 'TOPRIGHT' and E.debuffs.grow == 'left' and E.debuffs.attach and E.debuffs.max == 4 and E.debuffs.size == 24, 'your debuffs on the border line')
    assert(E.crowdControl.anchor == 'TOP' and E.crowdControl.grow == 'center' and E.crowdControl.size == 35 and E.buffs.anchor == 'RIGHT' and E.buffs.size == 22)
    assert(E.questAnchor == 'LEFT' and E.questSize == 18 and E.raidAnchor == 'CENTER' and E.levelInside and E.classificationInside, 'indicators')
    assert(E.targetStyle == 'arrows' and E.auraOrder == 'auras' and E.auraShape == 'mode' and E.auraSpacing == 1 and E.comboFollowCast, 'arrows, auras first')
    assert(E.castHeight == 12 and E.castY == -1 and E.castTargetAnchor == 'RIGHT', 'cast bar')
    assert(F.display == 'name' and not F.showAuras and F.nameFontSize == 13, 'friendly plates: names only')
    -- Readable text (owner, November 24, 2026): outlined slug text a size
    -- larger, enemy names in the text color; the halos wait, off.
    for _, S in ipairs({ E, F }) do
        assert(S.outline == true and S.slug and S.shadow and not S.liftedShadow, 'outlined slug text over the crisp shadow')
        assert(not S.nameTextGlow and not S.healthTextGlow and S.nameTextGlowColor == 'ink' and S.healthTextGlowStrength == 60, 'halos off, Ink when on')
    end
    assert(E.healthFontSize == 12 and E.castFontSize == 11 and E.levelSize == 11, 'a size larger')
    assert(E.nameColorMode == 'text' and F.nameColorMode == 'class' and M.db.fixedScale == nil, 'enemy names in the text color; the game scales plates')
    UseV11(M)
    -- The Mode-Obsidian look (the theme part runs on every profile): Mode-FG
    -- on Mode-BG at 85%, Mode-FG casts, the focus in the Glow, Gradient names,
    -- health text by health, Urbanist.
    assert(M.db.enemy.foregroundTexture == 'media:Mode-FG' and M.db.enemy.backgroundTexture == 'media:Mode-BG' and M.db.enemy.castTexture == 'media:Mode-FG')
    assert(M.db.enemy.focusStyle == 'glow' and M.db.friendly.focusStyle == 'glow' and M.db.friendly.backgroundTexture == 'media:Mode-BG', 'the focus in the Glow, per kind')
    assert(M.db.enemy.nameColorMode == 'class' and M.db.enemy.healthTextColor == 'health' and M.db.enemy.fontMedia == '' and not M.db.enemy.liftedShadow)
    assert(M.db.enemy.targetColor[1] == addon.Style.Tone.ivory[1] and M.db.enemy.focusColor[1] == addon.Style.Tone.rosewood[1], 'Ivory target, Rosewood focus')
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
    assert(M.db.enemy.softness == nil and M.db.enemy.healthOpacity == 100 and M.db.enemy.backgroundOpacity == 85, 'opacity defaults: see-through empty bars')
    assert(math.abs(plate.health.bg.vertexColor[4] - 0.85) < 1e-9, 'Slate at 85%')
    -- Outlined text: the slug outline font, and no halo by default.
    assert(plate.name.font[3] == 'OUTLINE' and plate.healthText.font[3] == 'OUTLINE' and plate.healthText.shadowColor[4] == 1, 'outlined, with its shadow')
    assert(plate.name.halo == nil and plate.healthText.halo == nil, 'no halo copies until a glow is switched on')
    -- The halo: eight copies 1px round the text in Ink, in place of its shadows.
    assert(M:SetOption('enemy', 'healthTextGlow', true) and M:SetOption('enemy', 'nameTextGlow', true))
    local hg, ng = plate.healthText.halo, plate.name.halo
    assert(M.db.enemy.healthTextGlow and hg and hg.on and hg.mode == 'ink' and #hg == 8 and hg[1]:IsShown(), 'health numbers wear the halo')
    assert(ng and ng.on and ng.mode == 'ink' and ng[1]:IsShown() and ng[1]:GetParent() == plate.nameHolder, 'the name too, inside its holder')
    assert(math.abs(hg[1]:GetAlpha() - 0.6) < 1e-9 and plate.healthText.shadowColor[4] == 0 and not plate.healthText.lift:IsShown(), 'the halo replaces the shadows')
    assert(issecretvalue(ng[1].text), 'secret names reach the halo copies too')
    assert(M:SetOption('enemy', 'healthTextGlow', false) and not hg[1]:IsShown() and plate.healthText.shadowColor[4] == 1, 'off: the shadow is back')
    assert(M:SetOption('enemy', 'healthTextGlow', true) and hg[1]:IsShown())
    assert(M:SetOption('enemy', 'nameTextGlowColor', 'match') and ng.mode == 'match' and M:SetOption('enemy', 'nameTextGlowColor', 'ink'))
    assert(not M:SetOption('enemy', 'nameTextGlowColor', 'neon') and not M:SetOption('enemy', 'nameTextGlowStrength', 0), 'halo choices and range')
    assert(M:SetOption('enemy', 'healthTextGlow', false) and M:SetOption('enemy', 'nameTextGlow', false) and not ng[1]:IsShown())
    assert(M.SetFixedScale == nil and not plate:IsIgnoringParentScale(), 'plates scale with the game')
    assert(M:SetOption('enemy', 'healthOpacity', 60) and math.abs(plate.health.statusBarColor[4] - 0.6) < 1e-9, 'Health Opacity fades the bar')
    assert(plate.health.statusBarColor[1] == hostile[1], 'fading keeps the color')
    assert(M:SetOption('enemy', 'backgroundOpacity', 20) and math.abs(plate.health.bg.vertexColor[4] - 0.2) < 1e-9, 'Background Opacity')
    assert(not M:SetOption('enemy', 'healthOpacity', 5) and not M:SetOption('enemy', 'backgroundOpacity', 120), 'opacity ranges')
    assert(not M:SetOption('enemy', 'softness', 30), 'Color Softness is gone')
    assert(M:SetOption('enemy', 'healthOpacity', 100) and M:SetOption('enemy', 'backgroundOpacity', 60))
    -- The bar inside the frameThin edge: the rim art sits outside the bar, nothing behind it.
    local box = plate.healthBox
    assert(box.edge.preset == 'frameThin' and box.edge.host == box.inner and box.rims == nil and box.bands == nil, 'the frameThin edge')
    assert(box.edge.pieces and #box.edge.parts[1] == 8 and plate.castBox.edge.pieces, 'health and cast edges in pieces (owner, November 18, 2026)')
    assert(box.edge.holder:GetFrameLevel() > box.bar:GetFrameLevel(), 'edge over the bar')
    -- Layers (owner, November 23, 2026): text, markers and indicators sit well
    -- above both rims, never tied with one; auras above them.
    local rims = math.max(box.edge.holder:GetFrameLevel(), plate.castBox.edge.holder:GetFrameLevel())
    assert(plate.textLayer:GetFrameLevel() > rims and plate.auraLayer:GetFrameLevel() > plate.textLayer:GetFrameLevel(), 'text and auras above every rim')
    assert(plate.healthBox:GetFrameLevel() == plate.castBox:GetFrameLevel(), 'both boxes on one level')
    assert(math.abs(box:GetHeight() - (M.db.enemy.healthHeight + 2)) < 1e-9 and Point(box.inner)[4] == 1, 'the bar one rim inside the box')
    assert(plate.castBox.edge.preset == 'frameThin' and plate.cast.bg.vertexColor[4] == 1, 'cast box keeps a solid background')
    assert(plate.comet and plate.comet.head and plate.comet.trail, 'the Comet spark on the cast bar')
    -- Border Style and Border Metal (owner, November 17, 2026): Mode-Border in
    -- its own metal by default, per kind, health and cast bar together; any
    -- style keeps the box's size; an old id (Mode-Blizz) draws as Mode-Border.
    local Metal = addon.Style.Tone.metal
    assert(M.db.enemy.edgeStyle == 'obsidian' and M.db.enemy.edgeMetal == 'default' and M.db.friendly.edgeStyle == 'obsidian'
        and M.db.friendly.edgeMetal == 'default', 'Mode-Border, the style\'s metal')
    assert(box.edge.styleId == 'obsidian' and box.edge:Metal() == Metal.obsidian and plate.castBox.edge.styleId == 'obsidian', 'plates in Mode-Border')
    local boxWidth, boxHeight, castHeight = box:GetWidth(), box:GetHeight(), plate.castBox:GetHeight()
    assert(M:SetOption('enemy', 'edgeStyle', 'obsidianEmpty') and box.edge.styleId == 'obsidianEmpty' and plate.castBox.edge.styleId == 'obsidianEmpty', 'Mode-Empty')
    assert(box:GetWidth() == boxWidth and box:GetHeight() == boxHeight and plate.castBox:GetHeight() == castHeight, 'same size')
    assert(M:SetOption('enemy', 'edgeStyle', 'blizz') and box.edge.styleId == 'obsidian', 'an old id draws as Mode-Border')
    assert(M:SetOption('enemy', 'edgeMetal', 'gunmetal') and box.edge:Metal() == Metal.gunmetal and plate.castBox.edge:Metal() == Metal.gunmetal, 'Gunmetal')
    assert(M.db.friendly.edgeStyle == 'obsidian' and M.db.friendly.edgeMetal == 'default', 'per kind')
    assert(not M:SetOption('enemy', 'edgeStyle', 'nope') and not M:SetOption('enemy', 'edgeMetal', 'gold') and M.db.enemy.edgeStyle == 'blizz', 'unknown styles are refused')
    assert(M:SetOption('enemy', 'edgeStyle', 'obsidian') and M:SetOption('enemy', 'edgeMetal', 'default') and box.edge.styleId == 'obsidian'
        and box.edge:Metal() == Metal.obsidian)
    -- The indicator reads level, classification and quest from the unit.
    local P1 = plate.indicatorParts
    assert(not P1.level:IsShown() and not P1.quest:IsShown() and M:IndicatorRoom(plate, 'LEFT') == 0, 'nothing known, nothing shown')
    local questUnits = {}
    function UnitLevel(u) return units[u] and units[u].level end
    function UnitClassification(u) return units[u] and units[u].classification end
    function UnitIsQuestBoss() return false end
    C_QuestLog = C_QuestLog or {}
    function C_QuestLog.UnitIsRelatedToActiveQuest(u) return questUnits[u] == true end
    units.nameplate1.level, units.nameplate1.classification = 61, 'rareelite'
    FireEvent('UNIT_LEVEL', 'nameplate1')
    assert(P1.level.text == '61' and P1.classification.atlas == 'nameplates-icon-elite-silver', 'level and rare elite')
    assert(not P1.quest:IsShown(), 'not a quest unit')
    questUnits.nameplate1 = true; FireEvent('QUEST_LOG_UPDATE')
    assert(P1.quest:IsShown(), 'quest unit after the quest log updates')
    units.nameplate1.level = Secret('level'); FireEvent('UNIT_LEVEL', 'nameplate1')
    assert(not P1.level:IsShown(), 'secret level hidden')
    units.nameplate1.level = -1; units.nameplate1.classification = 'worldboss'; FireEvent('UNIT_CLASSIFICATION_CHANGED', 'nameplate1')
    assert(P1.level.text == '??' and P1.classification.atlas == 'nameplates-icon-elite-gold', 'boss')
    questUnits.nameplate1, units.nameplate1.level, units.nameplate1.classification = nil, nil, nil
    FireEvent('QUEST_LOG_UPDATE')
    assert(not P1.level:IsShown() and not P1.quest:IsShown() and not P1.classification:IsShown(), 'cleared')
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
    assert(M.db.friendly.display == 'name', 'reset: the baseline (names only)'); UseV11(M, 'friendly')
    assert(M:SetOption('friendly', 'show', true))
    p2 = M.byUnit.nameplate2

    -- Target highlight compares nameplate frames, never secret units.
    nameplates.target = player; FireEvent('PLAYER_TARGET_CHANGED')
    assert(p2.targeted and p2.healthBox.edge.highlight == M:Style(p2).targetColor and not plate.targeted, 'target: the outer line in Ivory')
    assert(p2.castBox.edge.highlight == M:Style(p2).targetColor and p2.healthBox.edge.tint == nil, 'the cast box too; the rim stays metal')
    nameplates.target = nil; FireEvent('PLAYER_TARGET_CHANGED')
    assert(not p2.targeted and p2.healthBox.edge.highlight == nil)

    -- Combo points (Rogue fixture) live on the target, so they follow its plate:
    -- five sockets, the possibly secret count straight to each socket's SetValue.
    local cp = plate.combo
    assert(not cp:IsShown() and cp.count == 0 and M.comboPlate == nil, 'no target, no combo points')
    assert(M.comboEvents.unitEvents.UNIT_POWER_FREQUENT[1] == 'player' and not addon.Events:IsOn(M, 'UNIT_POWER_FREQUENT'), 'player power, unit-filtered')
    comboPoints = 2; nameplates.target = first; FireEvent('PLAYER_TARGET_CHANGED')
    assert(cp:IsShown() and cp.count == 5 and cp.sockets[5]:IsShown() and not cp.sockets[6]:IsShown() and M.comboPlate == plate, 'five sockets on the target')
    assert(cp.sockets[3].bar.low == 2 and cp.sockets[3].bar.high == 3 and cp.sockets[2].bar.value == 2, 'one bar per point')
    assert(cp.sockets[1].bar.statusBarColor[1] == 240 / 255 and cp.sockets[1].rim.vertexColor[1] == Kit.BORDER_COLOR[1], 'lit color, ModeUI rim')
    assert(not p2.combo:IsShown(), 'only on the target plate')
    comboPoints = 4; FireEvent('UNIT_POWER_FREQUENT', 'player')
    assert(cp.sockets[5].bar.value == 4, 'a power tick refills')
    comboPoints = Secret('cp'); FireEvent('COMBO_TARGET_CHANGED')
    assert(issecretvalue(cp.sockets[1].bar.value) and issecretvalue(cp.sockets[5].bar.value), 'secret count straight to SetValue')
    comboPoints = 3; FireEvent('COMBO_TARGET_CHANGED')
    -- Below the plate by default, past the cast bar.
    -- Combo points join the Bottom stack: its row sits past the cast bar.
    local row = plate.stackRows.BOTTOM
    local at = Point(row)
    assert(Point(cp)[2] == row and at[1] == 'TOP' and at[2] == plate.healthBox and at[3] == 'BOTTOM' and at[5] == -2 - plate.below, 'below, past the cast bar')
    assert(math.abs(cp.width - (5 * 8 + 4 * 2)) < 1 and math.abs(cp.sockets[1].width - 8) < 1, 'row of 8px sockets, 2px apart')
    -- Beside the bar (Indicators First here): the Right row starts 3px from the
    -- bar, the buffs row past it, and the arrows past the buffs row's edge mark.
    assert(M:SetOption('enemy', 'comboAnchor', 'RIGHT') and M.byUnit.nameplate1 == plate and cp:IsShown())
    row = plate.stackRows.RIGHT; at = Point(row)
    assert(Point(cp)[2] == row and at[1] == 'LEFT' and at[2] == plate.healthBox and at[3] == 'RIGHT' and at[4] == 3, 'beside the bar')
    assert(M:SideRoom(plate, 'RIGHT') == cp.width + 3 and plate.rowRoom.RIGHT == cp.width + 3, 'the buffs row starts past it')
    assert(M:SetOption('enemy', 'targetStyle', 'arrows'))
    local arrow = Point(plate.arrowFrames.right)
    assert(arrow[1] == 'LEFT' and arrow[2] == plate.auraEnds.RIGHT and arrow[3] == 'LEFT' and arrow[4] == M.db.enemy.targetArrowGap, 'arrows past the outermost row')
    -- Auras First: the buffs row hugs the bar and the points follow its last icon; the arrows follow the points.
    assert(M:SetOption('enemy', 'auraOrder', 'auras'))
    row = plate.stackRows.RIGHT; at = Point(row)
    assert(at[1] == 'LEFT' and at[2] == plate.auraEnds.RIGHT and at[3] == 'LEFT' and at[4] == 2, 'points follow the buffs row')
    arrow = Point(plate.arrowFrames.right)
    assert(arrow[2] == row and arrow[3] == 'RIGHT', 'arrows follow the points')
    assert(M:SetOption('enemy', 'auraOrder', 'indicators'))
    assert(M:SetOption('enemy', 'targetStyle', 'border') and M:SetOption('enemy', 'comboAnchor', 'BOTTOM') and plate.rowSize.RIGHT == nil)
    -- Sizes snap to whole even pixels; settings are validated.
    assert(M:SetOption('enemy', 'comboSize', 7) and math.abs(cp.sockets[1].width - 8) < 1, 'even sizes')
    assert(M:SetOption('enemy', 'comboSize', 12) and math.abs(cp.sockets[1].width - 12) < 1 and M:SetOption('enemy', 'comboSize', 8))
    assert(not M:SetOption('enemy', 'comboSize', 40) and not M:SetOption('enemy', 'comboAnchor', 'SIDEWAYS')
        and not M:SetOption('enemy', 'comboActiveColor', { 2, 0, 0 }), 'validated')
    assert(M:SetOption('enemy', 'showCombo', false) and not cp:IsShown() and M.comboPlate == nil, 'off')
    assert(M:SetOption('enemy', 'showCombo', true) and cp:IsShown())
    -- A Druid has them only in Cat Form (Energy); a class without them shows none.
    units.player.class, units.player.token = 'DRUID', 'MANA'; FireEvent('UNIT_DISPLAYPOWER', 'player')
    assert(not cp:IsShown(), 'Druid out of Cat Form')
    units.player.token = 'ENERGY'; FireEvent('UNIT_DISPLAYPOWER', 'player')
    assert(cp:IsShown(), 'Druid in Cat Form')
    units.player.class = 'MAGE'; FireEvent('UNIT_MAXPOWER', 'player')
    assert(not cp:IsShown() and M.comboPlate == nil, 'no combo points for a Mage')
    units.player.class = 'ROGUE'; FireEvent('UNIT_MAXPOWER', 'player')
    -- They follow the target; friendly plates show none by default.
    nameplates.target = player; FireEvent('PLAYER_TARGET_CHANGED')
    assert(not cp:IsShown() and not p2.combo:IsShown() and M.comboPlate == nil, 'friendly target: none by default')
    nameplates.target = first; FireEvent('PLAYER_TARGET_CHANGED'); assert(cp:IsShown())
    nameplates.target = nil; FireEvent('PLAYER_TARGET_CHANGED')
    assert(not cp:IsShown() and M.comboPlate == nil, 'cleared with the target')

    -- Focus: found like the target; a border, glow or stripes, its own texture, fading the others.
    local rose = M.db.enemy.focusColor
    -- The Glow by default (Mode-Obsidian); the border first here.
    assert(M.db.enemy.focusStyle == 'glow' and M:SetOption('enemy', 'focusStyle', 'border'))
    nameplates.focus = first; FireEvent('PLAYER_FOCUS_CHANGED')
    assert(plate.focused and not p2.focused and plate.healthBox.edge.highlight == rose, 'focus border')
    assert(p2:GetAlpha() == 1, 'others stay at 100% by default')
    nameplates.target = first; FireEvent('PLAYER_TARGET_CHANGED')
    assert(plate.healthBox.edge.highlight == M.db.enemy.targetColor, 'the target border wins')
    nameplates.target = nil; FireEvent('PLAYER_TARGET_CHANGED')
    assert(plate.healthBox.edge.highlight == rose, 'focus border back')
    assert(M:SetOption('enemy', 'focusStyle', 'stripes') and plate.focusStripes:IsShown() and math.abs(plate.focusStripes.vertexColor[4] - 0.4) < 1e-9, 'stripes')
    assert(plate.healthBox.edge.highlight == nil and plate.focusStripes.texture == addon.Media:GetTexture('NameplateStripes'), 'stripes only')
    assert(M:SetOption('enemy', 'focusStyle', 'glow') and plate.focusGlow:IsShown() and not plate.focusStripes:IsShown(), 'glow')
    assert(M:SetOption('friendly', 'focusFadeOthers', 50) and p2:GetAlpha() == 0.5, 'other plates fade')
    assert(M:SetOption('enemy', 'focusTexture', 'flat') and plate.health.statusBarTexture == Kit.FLAT, 'focus texture')
    nameplates.focus = nil; FireEvent('PLAYER_FOCUS_CHANGED')
    assert(not plate.focused and plate.healthTexture == M.db.enemy.foregroundTexture and p2:GetAlpha() == 1 and not plate.focusGlow:IsShown(), 'focus cleared')
    assert(not M:SetOption('enemy', 'focusStyle', 'pulse') and not M:SetOption('enemy', 'focusTexture', 'rainbow'), 'refused')
    for _, key in ipairs({ 'focusStyle', 'focusTexture' }) do assert(M:SetOption('enemy', key, M.styleDefaults.enemy[key])) end
    assert(M:SetOption('friendly', 'focusFadeOthers', 100))

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
    assert(plate.castText.text == '' and plate.castTimer.text == '' and plate.castTarget.text == '', 'cast texts cleared when the cast ends')

    -- An interrupt holds the bar (full, Interrupted color and text) through the
    -- stop event that follows, then it fades out and clears, as Blizzard's does.
    local now = GetTime() * 1000
    units.nameplate1.cast = { name = 'Fireball', text = 'Fireball', icon = 135812, start = now, stop = now + 2000, locked = false }
    FireEvent('UNIT_SPELLCAST_START', 'nameplate1')
    FireEvent('UNIT_SPELLCAST_INTERRUPTED', 'nameplate1', 'cast-guid', 133, 'Player-1-0001')
    units.nameplate1.cast = nil; FireEvent('UNIT_SPELLCAST_STOP', 'nameplate1', 'cast-guid', 133)
    assert(plate.castBox:IsShown() and plate.casting == 'held' and plate.cast.low == 0 and plate.cast.high == 1 and plate.cast.value == 1, 'held full')
    assert(plate.castText.text == 'Interrupted' and plate.castTimer.text == '' and plate.castTarget.text == '', 'Interrupted, no timer')
    assert(plate.cast:GetStatusBarTexture().vertexColor[1] == enemy.castInterruptedColor[1] and plate.cast.reverseFill == false, 'Interrupted color')
    FireEvent('UNIT_TARGET', 'nameplate1')
    assert(plate.castTarget.text == '', 'no target line on a held bar')
    Advance(1.15)
    assert(plate.castBox:IsShown() and math.abs(plate.castBox:GetAlpha() - 0.5) < 1e-6 and math.abs(plate.castText:GetAlpha() - 0.5) < 1e-6, 'fades')
    Advance(0.2)
    assert(not plate.castBox:IsShown() and plate.casting == nil and plate.castBox:GetAlpha() == 1 and plate.castText.text == '', 'hold ends')
    -- A channel's interrupt comes on its stop event; a new cast replaces a hold.
    now = GetTime() * 1000
    units.nameplate1.channel = { name = 'Drain', text = 'Drain', icon = 1, start = now, stop = now + 3000, locked = false }
    FireEvent('UNIT_SPELLCAST_CHANNEL_START', 'nameplate1')
    units.nameplate1.channel = nil; FireEvent('UNIT_SPELLCAST_CHANNEL_STOP', 'nameplate1', 'guid', 5, Secret('interrupter'))
    assert(plate.casting == 'held' and plate.castBox:IsShown(), 'secret interruptedBy still holds')
    units.nameplate1.cast = { name = 'Fireball', text = 'Fireball', icon = 135812, start = now, stop = now + 2000, locked = false }
    FireEvent('UNIT_SPELLCAST_START', 'nameplate1')
    assert(plate.casting == 'cast' and plate.castText.text == 'Fireball' and plate.castBox:GetAlpha() == 1, 'a new cast replaces the hold')
    units.nameplate1.cast = nil; FireEvent('UNIT_SPELLCAST_STOP', 'nameplate1', 'guid', 133)
    assert(not plate.castBox:IsShown() and plate.casting == nil, 'a cast that ends without an interrupt clears at once')
    units.nameplate1.channel = { name = 'Drain', text = 'Drain', icon = 1, start = now, stop = now + 3000, locked = false }
    FireEvent('UNIT_SPELLCAST_CHANNEL_START', 'nameplate1')
    units.nameplate1.channel = nil; FireEvent('UNIT_SPELLCAST_CHANNEL_STOP', 'nameplate1', 'guid', 5, nil)
    assert(not plate.castBox:IsShown(), 'a channel that runs out clears at once')

    -- Soft-target icon: the game's cursor art for the soft target's plate, on
    -- the CVars Blizzard reads, found by nameplate frame; drawn above the plate.
    local cvars = { SoftTargetNameplateSize = '19', SoftTargetIconEnemy = '1', SoftTargetIconFriend = '0', SoftTargetIconInteract = '1' }
    C_CVar = { GetCVar = function(name) return cvars[name] end, SetCVar = function(name, value) cvars[name] = value end }
    local cursor = { nameplate1 = true }
    function SetUnitCursorTexture(texture, unit, ...) texture.cursorUnit, texture.cursorArgs = unit, { ... }; return cursor[unit] end
    local icon = plate.softTarget
    assert(icon and not icon:IsShown(), 'no icon without a soft target')
    nameplates.softenemy = nameplates.nameplate1; FireEvent('PLAYER_SOFT_ENEMY_CHANGED')
    -- No combat icon by default (owner, November 23, 2026); Show Combat Icons adds the sword.
    assert(not M.db.enemy.softTargetCombat and not icon:IsShown(), 'no sword on the soft enemy by default')
    assert(M:SetOption('enemy', 'softTargetCombat', true)); icon = M.byUnit.nameplate1.softTarget
    assert(icon:IsShown() and icon.cursorUnit == 'nameplate1' and icon.cursorArgs[3] == true, 'icon on the soft enemy, art from the game')
    local at = Point(icon)
    assert(at[1] == 'BOTTOM' and at[2] == plate.healthBox and at[3] == 'TOP' and at[5] > plate.above, 'above the plate and its top rows')
    cursor.nameplate1 = Secret('cursor'); FireEvent('PLAYER_SOFT_ENEMY_CHANGED')
    assert(not icon:IsShown(), 'a secret answer hides it')
    cursor.nameplate1 = true
    cvars.SoftTargetIconEnemy = '0'; FireEvent('CVAR_UPDATE', 'softTargetIconEnemy', '0')
    assert(not icon:IsShown(), "the game's enemy icon setting turns it off")
    nameplates.softenemy, nameplates.softinteract = nil, nameplates.nameplate1; FireEvent('PLAYER_SOFT_INTERACT_CHANGED')
    assert(icon:IsShown(), 'interact icon on')
    cvars.SoftTargetNameplateSize = '0'; FireEvent('CVAR_UPDATE', 'SoftTargetNameplateSize', '0')
    assert(not icon:IsShown(), 'icon size 0 turns every icon off')
    cvars.SoftTargetNameplateSize = '19'; FireEvent('CVAR_UPDATE', 'SoftTargetNameplateSize', '19')
    assert(icon:IsShown(), 'back on')
    assert(M:SetOption('enemy', 'showSoftTarget', false) and not M.byUnit.nameplate1.softTarget:IsShown(), 'Show Soft Target Icon off')
    assert(M:SetOption('enemy', 'showSoftTarget', true) and M.byUnit.nameplate1.softTarget:IsShown(), 'and on')
    local before = Point(icon)[5]
    assert(M:SetOption('enemy', 'softTargetY', 6) and Point(icon)[5] == before + 6, 'Offset Y moves it')
    assert(M:SetOption('enemy', 'softTargetSize', 30) and icon:GetWidth() == 30, 'Size')
    assert(not M:SetOption('enemy', 'softTargetSize', 60), 'size range')
    M:SetOption('enemy', 'softTargetY', 0); M:SetOption('enemy', 'softTargetSize', 20)
    nameplates.softinteract = nil; FireEvent('PLAYER_SOFT_INTERACT_CHANGED')
    assert(not icon:IsShown(), 'gone when the soft target moves on')
    cvars.SoftTargetIconEnemy = '1'
    assert(M:SetOption('enemy', 'softTargetCombat', false))
    -- Hide Blizzard's Combat Icon: the game's enemy and friend icon CVars go to 0
    -- and come back as they were; the loot icon CVar is left alone.
    cvars.SoftTargetIconFriend = '1'
    assert(M.db.hideBlizzardCombatIcon == false and M:SetHideBlizzardCombatIcon(true))
    assert(cvars.SoftTargetIconEnemy == '0' and cvars.SoftTargetIconFriend == '0' and cvars.SoftTargetIconInteract == '1', 'combat icons off')
    assert(M.db.savedIconCVars.SoftTargetIconEnemy == '1', 'old values remembered')
    addon:SetModuleEnabled('nameplates', false)
    assert(cvars.SoftTargetIconEnemy == '1' and cvars.SoftTargetIconFriend == '1' and M.db.savedIconCVars == nil, 'restored while the module is off')
    addon:SetModuleEnabled('nameplates', true); plate = M.byUnit.nameplate1
    assert(cvars.SoftTargetIconEnemy == '0', 'applied again')
    assert(M:SetHideBlizzardCombatIcon(false) and cvars.SoftTargetIconEnemy == '1' and M.db.savedIconCVars == nil, 'turned off: restored')
    assert(not M:SetHideBlizzardCombatIcon('yes'), 'validated')
    cvars.SoftTargetIconFriend = '0'

    -- Health and cast boxes share the frameThin edge.
    assert(plate.healthBox.edge.preset == plate.castBox.edge.preset and plate.healthBox.edge.rim == 1, 'one edge for both boxes')
    assert(not M:SetOption('enemy', 'texture', 'flat'), 'the old texture key is gone')
    -- One Text Shadow choice drives both shadow keys.
    assert(Kit.ShadowMode({ shadow = true, liftedShadow = true }) == 'lifted' and Kit.ShadowMode({ shadow = true }) == 'crisp'
        and Kit.ShadowMode({ shadow = false, liftedShadow = true }) == 'none', 'shadow modes')
    local s1, l1 = Kit.ShadowKeys('crisp'); local s2, l2 = Kit.ShadowKeys('none')
    assert(s1 == true and l1 == false and s2 == false and l2 == false, 'shadow keys')
    -- Slug text: one font object per face, size and outline from the XML template.
    assert(M.db.enemy.slug == true, 'slug text on by default')
    assert(Kit.SlugFont('Fonts/Test.ttf', 10, '') == nil, 'no template, no slug font')
    local made = {}
    ModeUISlugFont, ModeUISlugFontOutline = { slug = true }, { slug = true, outline = true }
    function CreateFont(name)
        local font = { name = name }
        function font:CopyFontObject(source) self.copied = source end
        function font:SetFont(path, size, flags) self.font = { path, size, flags } end
        function font:GetFont() return self.font and self.font[1] end
        made[#made + 1] = font
        return font
    end
    local slug = Kit.SlugFont('Fonts/Test.ttf', 11, 'OUTLINE')
    assert(slug and slug.copied == ModeUISlugFontOutline and slug.font[2] == 11, 'copied from the outline template')
    assert(Kit.SlugFont('Fonts/Test.ttf', 11, 'OUTLINE') == slug and #made == 1, 'cached')
    local probe = plate.name
    local applied
    local setFontObject = probe.SetFontObject
    probe.SetFontObject = function(_, font) applied = font end
    Kit.Font(probe, { slug = true, outline = false, shadow = true, textColor = { 1, 1, 1 } }, 12, 'Fonts/Test.ttf', 1)
    assert(applied and applied.copied == ModeUISlugFont and applied.font[2] == 12, 'slug text uses the slug font')
    probe.SetFontObject = setFontObject
    CreateFont, ModeUISlugFont, ModeUISlugFontOutline = nil, nil, nil
    assert(M:SetOption('enemy', 'slug', false) and M:SetOption('enemy', 'slug', true))
    -- Foreground and background textures, for the health and cast bars.
    assert(M.db.enemy.foregroundTexture == 'media:Mode-FG' and M.db.enemy.backgroundTexture == 'media:Mode-BG', 'texture defaults')
    assert(M:SetOption('enemy', 'foregroundTexture', 'flat') and plate.health.statusBarTexture == Kit.FLAT and not plate.health.sheen:IsShown(), 'flat foreground')
    assert(M:SetOption('enemy', 'castTexture', 'flat') and plate.cast.statusBarTexture == Kit.FLAT, 'the cast bar has its own texture')
    assert(not M:SetOption('enemy', 'castTexture', 'slate'), 'slate is a background only')
    assert(M:SetOption('enemy', 'foregroundTexture', 'media:Missing') and plate.health.sheen:IsShown(), 'missing media draws Mode Gradient')
    assert(M:SetOption('enemy', 'backgroundTexture', 'media:Missing') and plate.health.bg.texture == Kit.FLAT, 'missing media draws flat')
    assert(not M:SetOption('enemy', 'foregroundTexture', 'rainbow') and not M:SetOption('enemy', 'backgroundTexture', 'mode'), 'bad textures refused')
    local labels = {}
    for _, choice in ipairs(M.TextureChoices(true)) do labels[#labels + 1] = choice.id end
    local backgrounds = M.TextureChoices(false)
    assert(labels[1] == 'flat' and backgrounds[1].id == 'slate' and backgrounds[2].id == 'slateHatch' and backgrounds[3].id == 'flat', 'texture choices')
    -- Mode Slate: flat, tinted the slate gray; the hatch tiles per pixel.
    assert(M:SetOption('enemy', 'backgroundTexture', 'slate') and plate.health.bg.texture == Kit.FLAT and plate.health.bg.vertexColor[1] == Kit.onyx.slate[1])
    assert(M:SetOption('enemy', 'backgroundTexture', 'slateHatch') and plate.health.bg.texture == addon.Media:GetTexture('ModeSlateHatch'))
    assert(not M:SetOption('enemy', 'foregroundTexture', 'slate'), 'slate is a background only')
    assert(M:SetOption('enemy', 'foregroundTexture', 'media:Mode-FG') and M:SetOption('enemy', 'backgroundTexture', 'media:Mode-BG')
        and M:SetOption('enemy', 'castTexture', 'media:Mode-FG'))
    assert(M:SetOption('enemy', 'castHeight', 4) and math.abs(plate.castBox:GetHeight() - 6) < 1e-9, 'small cast bars keep their rim')
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
    -- In combat the game marks the list's contents secret (issecrettable is
    -- true); its auras must still show, with secret icons passed straight on.
    issecrettable = function(value) return type(value) == 'table' end
    local CHEAP_SHOT = { auraInstanceID = 16, icon = Secret('cheap'), harmful = true, cc = true, duration = Secret('d'), expirationTime = Secret('e') }
    units.nameplate1.auras = { SHIELD, DOT, CHEAP_SHOT }
    FireEvent('UNIT_AURA', 'nameplate1')
    assert(plate.auraShown.crowdControl == 1 and issecretvalue(A.crowdControl[1].icon.texture), 'crowd control with secret data shows')
    assert(plate.auraShown.debuffs == 1 and plate.auraShown.buffs == 1, 'debuffs and buffs show while the list is secret')
    issecrettable = nil
    units.nameplate1.auras = { SHIELD, OTHER, DOT, SNARE }
    FireEvent('UNIT_AURA', 'nameplate1')
    -- Default anchors: crowd control Left (past the raid marker), debuffs Top, buffs Right.
    -- Icons are cropped (4px wider than tall) and placed by their corner on
    -- whole pixels from the health bar's bottom left (180 x 16 here).
    local function Corner(icon) local at = Point(icon); assert(at[1] == 'BOTTOMLEFT' and at[2] == plate.healthBox and at[3] == 'BOTTOMLEFT'); return at[4], at[5] end
    assert(math.abs(A.crowdControl[1].width - 24) < 1 and math.abs(A.crowdControl[1].height - 18) < 1, 'cropped 24 x 18')
    -- The frameThin edge: the art one rim (1px) inside the icon; the rim art
    -- covers its corners, nothing is masked; Corners retired.
    local cc1 = A.crowdControl[1]
    assert(cc1.edge.preset == 'frameThin' and cc1.edge.rim == 1 and cc1.edge.host == cc1.inner and Point(cc1.inner)[4] == 1, '1px frameThin edge')
    assert(cc1.rim == cc1.edge.rimTexture and #(cc1.icon.masks or {}) == 0 and not M:SetOption('enemy', 'auraCorners', 'rounded'))
    -- Crowd control: Blizzard's GCD flash, looping, in the rim color; other groups none.
    assert(cc1.flash:IsShown() and cc1.flash.atlas == Kit.GCD_FLASH_ATLAS and cc1.flashAnim:IsPlaying(), 'GCD flash plays')
    assert(cc1.flashAnim.looping == 'REPEAT' and cc1.flashAnim.anims[1].kind == 'FlipBook' and cc1.flashAnim.anims[1].SetFlipBookFramesArgs[1] == 22, 'flipbook 22 frames')
    assert(math.abs(cc1.flash.vertexColor[4] - Kit.AURA_FLASH_ALPHA) < 1e-9 and not cc1.glow:IsShown(), 'toned down, no soft halo')
    assert(not A.debuffs[1].flash:IsShown(), 'crowd control only')
    assert(M:SetOption('enemy', 'auraGlowStyle', 'soft') and cc1.glow:IsShown() and not cc1.flash:IsShown() and not cc1.flashAnim:IsPlaying(), 'soft glow')
    assert(math.abs(cc1.glow.vertexColor[4] - 0.4) < 1e-9, 'softer halo')
    assert(M:SetOption('enemy', 'auraGlowStyle', 'gcd'))
    assert(M:SetOption('enemy', 'auraCCGlow', false) and not cc1.glow:IsShown() and not cc1.flash:IsShown(), 'glow off')
    -- Timer text in the action bar cooldown color.
    assert(cc1.timer.color[1] == P.cooldown[1] and cc1.timer.color[2] == P.cooldown[2], 'cooldown text color')
    assert(M:SetOption('enemy', 'auraBorderSize', 2) and cc1.edge.rim == 2 and Point(cc1.inner)[4] == 2, '2px rim')
    assert(not M:SetOption('enemy', 'auraBorderSize', 3), 'border size 1 or 2')
    assert(M:SetOption('enemy', 'auraCCGlow', true) and M:SetOption('enemy', 'auraBorderSize', 1) and cc1.flash:IsShown())
    -- No raid mark is set, so nothing sits between the bar and the crowd control row.
    local x, y = Corner(A.crowdControl[1]); assert(x == -26 and y == -2, 'crowd control beside the bar: ' .. x .. ',' .. y)
    x, y = Corner(A.debuffs[1]); assert(x == 80 and y == 30, 'debuffs centered above the name: ' .. x .. ',' .. y)
    x, y = Corner(A.buffs[1]); assert(x == 182 and y == 1, 'buffs right of the bar: ' .. x .. ',' .. y)
    -- Each side row's edge mark sits on its last icon's outer edge (what follows the row anchors to it).
    local endL, endR = Point(plate.auraEnds.LEFT), Point(plate.auraEnds.RIGHT)
    assert(endL[1] == 'RIGHT' and endL[2] == plate.healthBox and endL[4] == -26 and endR[1] == 'LEFT' and endR[4] == 182 + A.buffs[1].width, 'edge marks on the rows')
    -- Moving one group: anchor, offsets, size and count, all validated.
    assert(M:SetOption('enemy', 'anchor', 'BOTTOMRIGHT', 'debuffs'))
    -- Still growing from the center: centered on the bar's bottom right corner.
    x, y = Corner(A.debuffs[1]); assert(x == 170 and y == -39, 'bottom right, under the cast bar (and its target line): ' .. x .. ',' .. y)
    assert(M:SetOption('enemy', 'x', 5, 'debuffs') and select(1, Corner(A.debuffs[1])) == 175, 'offset X')
    assert(M:SetOption('enemy', 'y', -3, 'debuffs') and select(2, Corner(A.debuffs[1])) == -42, 'offset Y')
    assert(not M:SetOption('enemy', 'anchor', 'MIDDLE', 'debuffs') and not M:SetOption('enemy', 'x', 99, 'debuffs'), 'refused')
    assert(not M:SetOption('enemy', 'grow', 'sideways', 'debuffs'), 'unknown grow refused')
    assert(not M:SetOption('enemy', 'debuffs', {}) and not M:SetOption('enemy', 'filter', 'all', 'crowdControl'), 'one setting at a time')
    assert(M.db.friendly.debuffs.anchor == 'TOP', 'the other kind is untouched')
    -- Groups on the same anchor continue as one row in the first group's direction.
    assert(M:SetOption('enemy', 'anchor', 'TOP', 'debuffs') and M:SetOption('enemy', 'x', 0, 'debuffs') and M:SetOption('enemy', 'y', 0, 'debuffs'))
    -- Sit on Health Bar: the group hugs the bar's top edge and the name moves past it.
    local nameY, boxHeight = Point(plate.name)[5], plate.healthBox:GetHeight()
    assert(M.db.enemy.debuffs.attach == false, 'groups start off the bar')
    assert(M:SetOption('enemy', 'attach', true, 'debuffs'))
    x, y = Corner(A.debuffs[1]); assert(y == boxHeight + 2, 'debuffs sit on the bar: ' .. y)
    assert(Point(plate.name)[5] == nameY + A.debuffs[1].height + 2, 'name moves past the aura band')
    assert(M:SetOption('enemy', 'anchor', 'LEFT', 'debuffs') and Point(plate.name)[5] == nameY, 'side anchors take no band')
    assert(M:SetOption('enemy', 'anchor', 'TOP', 'debuffs') and M:SetOption('enemy', 'attach', false, 'debuffs') and Point(plate.name)[5] == nameY)
    assert(M:SetOption('enemy', 'anchor', 'TOP', 'buffs'))
    local dx, dy = Corner(A.debuffs[1]); local bx, by = Corner(A.buffs[1])
    assert(dx == 70 and dy == 30 and bx == 92 and by == 30, 'one centered row: ' .. dx .. ',' .. dy .. ' ' .. bx .. ',' .. by)
    assert(M:SetOption('enemy', 'anchor', 'RIGHT', 'buffs'))
    -- Grow directions.
    assert(M:SetOption('enemy', 'filter', 'all', 'debuffs') and M:SetOption('enemy', 'anchor', 'TOPLEFT', 'debuffs'))
    assert(M:SetOption('enemy', 'grow', 'right', 'debuffs'))
    local x1, y1 = Corner(A.debuffs[1]); local x2, y2 = Corner(A.debuffs[2])
    assert(x1 == 0 and x2 == 22 and y1 == y2, 'grow right from the left edge')
    assert(M:SetOption('enemy', 'grow', 'left', 'debuffs'))
    x1, y1 = Corner(A.debuffs[1]); x2, y2 = Corner(A.debuffs[2])
    -- Growing left from Top Left: the row's right end sits on the bar's left edge (as the container draws it).
    assert(x1 == -20 and x2 == -42 and y1 == y2, 'grow left: ' .. x1 .. ',' .. x2)
    assert(M:SetOption('enemy', 'grow', 'up', 'debuffs'))
    x1, y1 = Corner(A.debuffs[1]); x2, y2 = Corner(A.debuffs[2])
    assert(x1 == x2 and y2 == y1 + 16, 'grow up')
    assert(M:SetOption('enemy', 'grow', 'down', 'debuffs'))
    x1, y1 = Corner(A.debuffs[1]); x2, y2 = Corner(A.debuffs[2])
    assert(x1 == x2 and y2 == y1 - 16, 'grow down')
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
    assert(A.debuffs[2].rim.vertexColor[1] == M.db.enemy.auraNoTypeColor[1], 'a secret dispel type keeps the no-type rim')
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
    assert(page.borderStyleSelect and page.borderMetalSelect, 'Border and Border Metal on the Border tab')
    local sample, friend = view.plates.enemy, view.plates.friendly
    assert(sample:IsShown() and not friend:IsShown() and sample:GetParent() == view.stage, 'only the enemy sample while editing Enemy')
    -- The magnified previewer (owner, November 23, 2026): the bar stays in the
    -- middle across (an anchor change never slides it sideways), its full reach
    -- centered up and down; a fixed height; a 1:1 strip of other states.
    local at = Point(sample)
    assert(at[1] == 'CENTER' and at[2] == view.stage and at[3] == 'CENTER' and at[4] == 0, 'the bar pinned across')
    local _, height = M:GetPreviewSize(view)
    assert(height == 230 and view.zoom and view.zoom >= 1 and view.zoom <= M.PREVIEW_ZOOM, 'a fixed height; zoomed')
    local before = Point(sample)[4]
    assert(M:SetOption('enemy', 'anchor', 'RIGHT', 'crowdControl') and Point(sample)[4] == before, 'moving a group does not slide the plate')
    assert(M:SetOption('enemy', 'anchor', 'LEFT', 'crowdControl') and M:SetOption('enemy', 'grow', 'left', 'crowdControl'))
    assert(view.strip == nil, 'one plate (owner, November 23, 2026): other states come from the chips')
    assert(math.abs(sample.width - 180) < 1, 'sample size follows the kind')
    assert(sample.name.text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '') == 'Scarlet Crusader' and sample.healthText.text == '72%' and sample.health.value == 72)
    assert(sample.raidIcon:IsShown() and sample.raidIcon.spriteCell[1] == 8, 'skull marker sample')
    assert(sample.softTarget:IsShown() and sample.softTarget.texture:find('Interact', 1, true), 'loot icon sample')
    assert(sample.targeted and sample.healthBox.edge.highlight == M.db.enemy.targetColor, 'sample target line')
    assert(sample.castBox:IsShown() and sample.cast.value == 0.6 and sample.castText.text == 'Holy Smite')
    -- State chips: the cast, the target and the auras.
    local function Chip(key, value) for _, chip in ipairs(view.chips) do if chip.stateKey == key and chip.stateValue == value then return chip end end end
    Chip('cast', 'locked'):GetScript('OnClick')()
    assert(sample.cast:GetStatusBarTexture().vertexColor[1] == M.db.enemy.castLockedColor[1], "Can't Interrupt: the not-interruptible color")
    Chip('cast', 'none'):GetScript('OnClick')(); assert(not sample.castBox:IsShown(), 'No Cast')
    Chip('cast', 'interrupted'):GetScript('OnClick')(); assert(sample.castBox:IsShown() and sample.cast.value == 1, 'Interrupted')
    Chip('cast', 'cast'):GetScript('OnClick')()
    Chip('highlight', 'none'):GetScript('OnClick')(); assert(not sample.targeted and not sample.focused, 'Neither')
    Chip('highlight', 'focus'):GetScript('OnClick')(); assert(sample.focused and not sample.targeted, 'Focus')
    Chip('highlight', 'target'):GetScript('OnClick')(); assert(sample.targeted and not sample.focused, 'Target')
    assert(not Chip('sample', 'npc'):IsShown(), 'the Player and NPC chips show for friendly plates only')
    local function Shown(p, group)
        local n = 0
        for _, icon in ipairs(p.auraIcons[group]) do if icon:IsShown() then n = n + 1 end end
        return n
    end
    assert(Shown(sample, 'crowdControl') == 1 and Shown(sample, 'debuffs') == 2 and Shown(sample, 'buffs') == 1, 'enemy sample auras')
    Chip('auras', 'full'):GetScript('OnClick')()
    assert(Shown(sample, 'debuffs') == M.db.enemy.debuffs.max and Shown(sample, 'buffs') == M.db.enemy.buffs.max, 'Full: every group at Most Shown')
    Chip('auras', 'none'):GetScript('OnClick')(); assert(Shown(sample, 'debuffs') == 0, 'No Auras')
    Chip('auras', 'some'):GetScript('OnClick')()
    assert(sample.auraIcons.debuffs[1].rim.vertexColor[1] == M.db.enemy.auraMagicColor[1], 'Magic rim by type')
    assert(M:SetOption('enemy', 'auraBorder', 'mode') and sample.auraIcons.debuffs[1].edge.tint == nil, 'Mode: the Gunmetal metal')
    assert(M:SetOption('enemy', 'auraBorder', 'type'))
    -- Switching Editing switches the sample.
    page.SetEditing('friendly')
    assert(friend:IsShown() and not sample:IsShown() and math.abs(friend.width - 120) < 1, 'friendly sample while editing Friendly')
    local npc = Chip('sample', 'npc'); assert(npc:IsShown(), 'Player and NPC chips for friendly plates')
    npc:GetScript('OnClick')(); assert(view.caption.text:find('Friendly NPC', 1, true), 'the NPC sample')
    Chip('sample', 'player'):GetScript('OnClick')()
    assert(Shown(friend, 'debuffs') == 1 and Shown(friend, 'buffs') == 0 and Shown(friend, 'crowdControl') == 0, 'friendly sample auras')
    assert(friend.auraIcons.debuffs[1].rim.vertexColor[1] == M.db.friendly.auraDiseaseColor[1], 'Disease rim')
    assert(M:SetOption('friendly', 'show', true, 'buffs') and Shown(friend, 'buffs') == 1, 'preview follows each group')
    -- Name Only: just the class-colored name.
    assert(M:SetOption('friendly', 'display', 'name'))
    assert(not friend.healthBox:IsShown() and not friend.castBox:IsShown() and friend.name:IsShown() and not friend.healthText:IsShown(), 'name only')
    local mage = addon.Domain.UnitColor.Class('MAGE')
    assert(friend.name.color[1] == mage.r and friend.name.color[3] == mage.b, 'true class-colored name')
    assert(M:SetOption('friendly', 'display', 'plate') and friend.healthBox:IsShown())
    assert(M:SetOption('friendly', 'show', false) and not friend:IsShown() and view.caption.text:find("Blizzard", 1, true))
    assert(M:SetOption('friendly', 'show', true) and friend:IsShown())
    page.SetEditing('enemy')
    -- Settings follow into the sample.
    assert(M:SetOption('enemy', 'healthText', 'both') and sample.healthText.text == '8,640 · 72%', 'preview follows settings')
    -- Target styles.
    assert(M:SetOption('enemy', 'targetStyle', 'glow') and sample.targetGlow:IsShown() and sample.healthBox.edge.highlight == nil, 'glow')
    assert(M:SetOption('enemy', 'targetStyle', 'arrows') and sample.arrows.left:IsShown() and sample.arrows.right:IsShown() and not sample.targetGlow:IsShown(), 'arrows')
    assert(sample.arrows.right.texCoord[1] == 1, 'right arrow mirrored')
    -- The arrows are the outermost parts: past the crowd control and buffs rows' edge marks.
    local leftArrow, rightArrow = Point(sample.arrowFrames.left), Point(sample.arrowFrames.right)
    assert(leftArrow[2] == sample.auraEnds.LEFT and leftArrow[4] == -M.db.enemy.targetArrowGap, 'left arrow outside the crowd control row')
    assert(rightArrow[2] == sample.auraEnds.RIGHT and rightArrow[4] == M.db.enemy.targetArrowGap, 'right arrow outside the buffs row')
    assert(M:SetOption('enemy', 'targetArrowGap', 60) and M:SetOption('enemy', 'targetArrowSize', 48) and M:SetOption('enemy', 'targetArrowGap', 4)
        and M:SetOption('enemy', 'targetArrowSize', 12), 'wider arrow ranges')
    assert(M:SetOption('enemy', 'targetStyle', 'borderArrows') and sample.arrows.left:IsShown() and sample.healthBox.edge.highlight == M.db.enemy.targetColor)
    assert(M:SetOption('enemy', 'targetThickness', 3) and sample.healthBox.edge.tint == M.db.enemy.targetColor, 'a thicker border tints the rim too')
    assert(M:SetOption('enemy', 'targetStyle', 'none') and not sample.targeted and not sample.arrows.left:IsShown())
    assert(M:SetOption('enemy', 'targetStyle', 'border') and M:SetOption('enemy', 'targetThickness', 1))
    -- Element placement: name, health text, raid marker, cast bar.
    assert(M:SetOption('enemy', 'nameAnchor', 'CENTER') and Point(sample.name)[2] == sample.health and Point(sample.name)[1] == 'CENTER', 'name inside the bar')
    assert(M:SetOption('enemy', 'nameAnchor', 'BOTTOMLEFT') and Point(sample.name)[1] == 'TOPLEFT' and Point(sample.name)[3] == 'BOTTOMLEFT')
    assert(M:SetOption('enemy', 'nameAnchor', 'TOP') and M:SetOption('enemy', 'nameX', 4) and Point(sample.name)[4] == 4, 'name offset')
    assert(M:SetOption('enemy', 'nameX', 0))
    assert(M:SetOption('enemy', 'healthTextAnchor', 'LEFT') and Point(sample.healthText)[1] == 'LEFT' and Point(sample.healthText)[4] == 2)
    -- The marker joins the Top Right stack: its row sits past the top band, from the right edge.
    assert(M:SetOption('enemy', 'raidAnchor', 'TOPRIGHT') and Point(sample.raidIcon)[2] == sample.stackRows.TOPRIGHT and Point(sample.raidIcon)[1] == 'RIGHT')
    assert(Point(sample.stackRows.TOPRIGHT)[1] == 'BOTTOMRIGHT' and Point(sample.stackRows.TOPRIGHT)[3] == 'TOPRIGHT')
    assert(M:SetOption('enemy', 'raidSize', 24) and math.abs(sample.raidIcon.width - 24) < 1)
    assert(M:SetOption('enemy', 'raidAnchor', 'LEFT') and M:SetOption('enemy', 'raidSize', 16) and M:SetOption('enemy', 'healthTextAnchor', 'RIGHT'))
    assert(M:SetOption('enemy', 'castAnchor', 'TOP') and Point(sample.castBox)[1] == 'BOTTOMLEFT' and Point(sample.castBox)[3] == 'TOPLEFT', 'cast bar above')
    local near, far = M:CastTextRoom(sample)
    assert(near > 0 and far == 0, 'the target line sits between the bars when the cast bar is above')
    assert(Point(sample.name)[5] == 2 + sample.castBarHeight + 2 + near, 'name moves above the cast bar and its target line')
    assert(Point(sample.castTarget)[1] == 'TOP' and Point(sample.castTarget)[3] == 'BOTTOM', 'target line under the upper cast bar')
    assert(Point(sample.castBox)[5] == 2 + near + M.db.enemy.castY, 'the cast bar moves up past the target line')
    assert(M:SetOption('enemy', 'castAnchor', 'BOTTOM') and M:SetOption('enemy', 'castY', -3) and Point(sample.castBox)[5] == -5)
    assert(M:SetOption('enemy', 'castY', M.styleDefaults.enemy.castY))
    -- Cast bar content: icon side, spell name, target line and timer.
    assert(sample.castTarget.text == 'Mode' and sample.castTarget:IsShown(), 'cast target in the sample')
    local paladin = addon.Domain.UnitColor.Class('PALADIN')
    assert(sample.castTarget.color[1] == paladin.r, 'target in its class color')
    assert(sample.castTimer:IsShown() and sample.castTimer.text == '1.0', 'timer shows seconds left: ' .. tostring(sample.castTimer.text))
    assert(Point(sample.castText)[1] == 'LEFT' and Point(sample.castIcon)[1] == 'TOPLEFT', 'icon on the left')
    -- Spell name left, timer right: the timer sizes itself to its text and the
    -- name stops 4px short of it (each anchored to the next, nothing measured).
    local shared = Point(sample.castText, 2)
    assert(shared[1] == 'RIGHT' and shared[2] == sample.castTimer and shared[3] == 'LEFT' and shared[4] == -4, 'spell name stops at the timer')
    assert(sample.castTimer.width == 0, 'the timer sizes itself')
    -- Cast Target inside on the right (owner, November 23, 2026): just left of
    -- the timer, and the spell name stops at the target.
    assert(M:SetOption('enemy', 'castTargetAnchor', 'RIGHT'))
    local target = Point(sample.castTarget)
    assert(target[1] == 'RIGHT' and target[2] == sample.castTimer and target[3] == 'LEFT' and target[4] == -4, 'target left of the timer')
    shared = Point(sample.castText, 2)
    assert(shared[2] == sample.castTarget and shared[3] == 'LEFT', 'spell name stops at the target')
    assert(M:SetOption('enemy', 'castTargetAnchor', 'BOTTOM'))
    assert(M:SetOption('enemy', 'castIcon', 'RIGHT') and Point(sample.castIcon)[1] == 'TOPRIGHT' and sample.castIcon:IsShown(), 'icon on the right')
    assert(M:SetOption('enemy', 'castIcon', 'none') and not sample.castIcon:IsShown() and Point(sample.cast)[2] == sample.castBox, 'icon hidden')
    assert(M:SetOption('enemy', 'castShowTimer', false) and not sample.castTimer:IsShown(), 'timer off')
    assert(M:SetOption('enemy', 'castShowTarget', false) and not sample.castTarget:IsShown() and select(2, M:CastTextRoom(sample)) == 0, 'target off')
    assert(M:SetOption('enemy', 'castShowText', false) and not sample.castText:IsShown(), 'spell name off')
    assert(not M:SetOption('enemy', 'castIcon', 'TOP'), 'bad icon side refused')
    -- Positions: icon outside the box, and each text by anchor and offset.
    assert(M:SetOption('enemy', 'castIcon', 'OUTLEFT') and Point(sample.castIcon)[1] == 'RIGHT' and Point(sample.castIcon)[3] == 'LEFT', 'icon outside left')
    assert(math.abs(sample.castIcon.width - sample.castBox:GetHeight()) < 1 and sample.castIcon:IsShown(), 'outside icon as tall as the box')
    assert(M:SetOption('enemy', 'castIconY', 2) and Point(sample.castIcon)[5] == 2, 'icon offset')
    assert(M:SetOption('enemy', 'castShowText', true) and M:SetOption('enemy', 'castTextAnchor', 'BOTTOMRIGHT'), 'spell name below')
    assert(Point(sample.castText)[1] == 'TOPRIGHT' and Point(sample.castText)[2] == sample.castBox, 'spell name outside, under the bar')
    assert(select(2, M:CastTextRoom(sample)) > 0, 'a far line is reserved')
    assert(M:SetOption('enemy', 'castTimerAnchor', 'CENTER') and Point(sample.castTimer)[1] == 'CENTER', 'timer centered inside')
    assert(M:SetOption('enemy', 'castTextX', 3) and Point(sample.castText)[4] == 3, 'text offset')
    assert(not M:SetOption('enemy', 'castTimerAnchor', 'MIDDLE'), 'bad anchor refused')
    for _, key in ipairs({ 'castIconY', 'castTextAnchor', 'castTimerAnchor', 'castTextX' }) do
        assert(M:SetOption('enemy', key, M.styleDefaults.enemy[key]))
    end
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
    assert(table.concat(sections, ',') == 'General,Fill,Border,Glow,Text,Auras,Behavior', table.concat(sections, ','))
    assert(page.standardTabs and #page.cards > 5 and page.cards[1].frame:IsShown(), 'settings sit on cards in the standard tabs')
    -- Each part's cards, named for it, in the tab for their aspect.
    local cards = {}
    for _, row in ipairs(page.rows) do
        if row.settingsGroupTitle then cards[#cards + 1] = row.section.title .. ':' .. row.settingsGroupTitle end
    end
    assert(table.concat(cards, ',') == 'General:Show,General:Size,General:Cast Bar,General:Combo Points,General:Indicators,'
        .. 'General:Raid Marker,General:Soft Target Icon,Fill:Health Bar,Fill:Cast Bar,Fill:Combo Points,Fill:Focus,'
        .. 'Border:Border,Border:Aura Borders,Border:Target,Border:Aura Border Colors,Glow:Focus,Glow:Crowd Control,Glow:Name Text,Glow:Health Text,'
        .. 'Text:Text Style,Text:Name Text,Text:Health Text,Text:Cast Bar Text,Auras:Groups,Auras:Icons,Auras:Timer,Auras:Stacks,'
        .. 'Behavior:Focus', table.concat(cards, ','))
    -- On the Glow tab (the focus highlight) the sample shows itself as the focus, not the target.
    local selected = page.selectedSection
    -- The focus defaults to the Glow (Mode-Obsidian); the sample shows the Border style here.
    assert(M.styleDefaults.enemy.focusStyle == 'glow' and M:SetOption('enemy', 'focusStyle', 'border'))
    page:SelectSectionTab(4)
    assert(page.selectedSection.title == 'Glow' and sample.focused and not sample.targeted, 'focus sample')
    assert(sample.healthBox.edge.highlight == M.db.enemy.focusColor, 'focus border in the sample')
    page:SelectSectionTab(selected)
    assert(not sample.focused and sample.targeted, 'target sample again')
    -- One Editing switch, above every tab.
    local switch = page.nameplateEditButtons[1]
    assert(#page.nameplateEditButtons == 1, 'one Editing switch')
    switch[2].scripts.OnClick(switch[2])
    assert(page.nameplateEditing() == 'friendly' and switch[2].selected, 'the switch picks the kind')
    local editingRow = switch[1]:GetParent().row
    assert(editingRow.section == nil and editingRow:IsShown(), 'the Editing switch sits above every tab')
    page:SelectSectionTab(5)
    assert(editingRow:IsShown(), 'and stays on another tab')
    page:SelectSectionTab(selected)
    assert(Point(editingRow.settingsLabel)[1] == 'TOPLEFT' and editingRow.stacked and Point(switch[1]:GetParent())[1] == 'LEFT', 'the Editing label sits above its pills')
    -- Clicking a part of the sample jumps to its settings.
    local hits = view.targets.friendly
    hits.cast.scripts.OnEnter(hits.cast)
    assert(hits.cast.jumpHighlight:IsShown(), 'parts light up under the mouse')
    hits.cast.scripts.OnLeave(hits.cast)
    hits.cast.scripts.OnMouseUp(hits.cast, 'LeftButton')
    assert(page.nameplateEditing() == 'friendly' and page.selectedSection.title == 'General'
        and page.jumpTargets.cast.row.settingsGroup == 'Cast Bar', 'cast bar click opens its card on General')
    page.SetEditing('enemy')
    view.targets.enemy.name.scripts.OnMouseUp(view.targets.enemy.name, 'LeftButton')
    assert(page.nameplateEditing() == 'enemy' and page.selectedSection.title == 'Text'
        and page.jumpTargets.name.row.settingsGroup == 'Name Text', 'name click opens Name Text')
    -- Text inside the bar takes clicks only where it is written, so the bar
    -- beside it opens the health settings.
    local textHit = view.targets.enemy.healthText
    assert(textHit.width < sample.health:GetWidth() and Point(textHit)[1] == 'RIGHT', 'health text hit fits the text')
    view.targets.enemy.health.scripts.OnMouseUp(view.targets.enemy.health, 'LeftButton')
    assert(page.selectedSection.title == 'Fill' and page.jumpTargets.health.row.settingsGroup == 'Health Bar', 'health click opens Fill')
    view.targets.enemy.markers.scripts.OnMouseUp(view.targets.enemy.markers, 'LeftButton')
    assert(page.selectedSection.title == 'General' and page.jumpTargets.markers.row.settingsGroup == 'Raid Marker', 'marker click opens General')
    page:SelectSectionTab(5)
    view.targets.enemy.softTarget.scripts.OnMouseUp(view.targets.enemy.softTarget, 'LeftButton')
    assert(page.selectedSection.title == 'General' and page.jumpTargets.softTarget.row.settingsGroup == 'Soft Target Icon', 'soft-target icon click opens General')
    -- Combo points: the enemy sample shows every socket with a few lit; a click opens its card on General.
    assert(sample.combo:IsShown() and sample.combo.count == 5 and sample.combo.sockets[5].bar.value == M.COMBO_SAMPLE, 'sample combo points')
    assert(page.comboNote:GetText():find('Combo Points', 1, true), 'names your class\'s combo points')
    page:SelectSectionTab(5)
    view.targets.enemy.combo.scripts.OnMouseUp(view.targets.enemy.combo, 'LeftButton')
    assert(page.selectedSection.title == 'General' and page.jumpTargets.combo.row.settingsGroup == 'Combo Points', 'combo click opens General')
    assert(M:SetOption('enemy', 'showCombo', false) and not sample.combo:IsShown() and M:SetOption('enemy', 'showCombo', true))
    -- Indicators: quest, classification and level, each placed on its own;
    -- those sharing an anchor line up in one row.
    local parts = sample.indicatorParts
    assert(parts.quest:IsShown() and parts.quest.atlas == M.QUEST_ATLAS, 'quest icon')
    assert(parts.classification.atlas == 'nameplates-icon-elite-gold' and parts.level.text == '62', 'elite icon and level')
    -- The marker and the indicators on the left share one row, from the bar
    -- outward: the marker, quest, elite and rare, level, each 2px apart.
    local row = sample.stackRows.LEFT
    assert(Point(parts.quest)[2] == row and Point(sample.raidIcon)[2] == row, 'one row on the left')
    assert(Point(sample.raidIcon)[4] == 0 and Point(parts.quest)[4] == -(sample.markSize + 2), 'the marker nearest the bar')
    assert(Point(parts.classification)[4] == -(sample.markSize + 2 + parts.quest.width + 2), 'then quest, then elite')
    assert(Point(row)[1] == 'RIGHT' and Point(row)[2] == sample.healthBox and Point(row)[4] == -3, 'the row 3px from the bar')
    assert(M:SideRoom(sample, 'LEFT') == sample.rowSize.LEFT[1] + 3, 'crowd control starts past the row (Indicators First)')
    assert(M:SetOption('enemy', 'indicatorQuest', false) and not parts.quest:IsShown() and Point(parts.classification)[4] == -(sample.markSize + 2), 'quest off: the rest close up')
    -- Each indicator has its own anchor, size and offsets.
    assert(M:SetOption('enemy', 'levelAnchor', 'TOPRIGHT') and Point(parts.level)[2] == sample.stackRows.TOPRIGHT, 'level on its own anchor')
    assert(Point(sample.stackRows.TOPRIGHT)[1] == 'BOTTOMRIGHT' and Point(parts.classification)[2] == row, 'classification stays left')
    assert(M:SetOption('enemy', 'classificationSize', 20) and math.abs(parts.classification.width - 20) < 1, 'classification size')
    assert(M:SetOption('enemy', 'levelX', 4) and Point(parts.level)[4] == 4, 'level offset')
    assert(M:SetOption('enemy', 'levelSize', 12), 'level text size')
    assert(not M:SetOption('enemy', 'questSize', 99) and not M:SetOption('enemy', 'levelAnchor', 'MIDDLE'), 'refused')
    assert(M:SetOption('enemy', 'showIndicator', false) and not parts.level:IsShown() and not parts.classification:IsShown(), 'all off')
    assert(M:IndicatorRoom(sample, 'LEFT') == sample.markSize + 3, 'only the marker left beside the bar')
    assert(M:SetOption('enemy', 'showIndicator', true))
    -- Inside the Bar: Left indicators go inside the bar, the level leftmost, and
    -- text inside on that side starts past them.
    assert(M:SetOption('enemy', 'levelAnchor', 'LEFT') and M:SetOption('enemy', 'levelX', 0))
    assert(M:SetOption('enemy', 'levelInside', true) and M:SetOption('enemy', 'classificationInside', true))
    local inside = sample.stackRows['IN-LEFT']
    assert(Point(parts.level)[2] == inside and Point(parts.level)[4] == 0 and Point(parts.classification)[4] == sample.indicatorSizes.level[1] + 2, 'level, then elite, inside on the left')
    assert(Point(inside)[1] == 'LEFT' and Point(inside)[2] == sample.health and Point(inside)[4] == 2, 'inside the bar')
    assert(M:SetOption('enemy', 'healthTextAnchor', 'LEFT') and Point(sample.healthText)[4] == 2 + sample.insideRoom.LEFT and sample.insideRoom.LEFT > 0, 'text past them')
    assert(M:SetOption('enemy', 'healthTextAnchor', 'RIGHT') and M:SetOption('enemy', 'levelInside', false) and M:SetOption('enemy', 'classificationInside', false))
    assert(M:SetOption('enemy', 'showIndicator', false))
    for _, key in ipairs({ 'levelAnchor', 'classificationSize', 'levelX', 'levelSize' }) do
        assert(M:SetOption('enemy', key, M.styleDefaults.enemy[key]))
    end
    assert(M:SetOption('enemy', 'showIndicator', true) and M:SetOption('enemy', 'indicatorQuest', true))
    assert(M.db.friendly.showIndicator == false, 'friendly plates start without indicators')
    page:SelectSectionTab(5)
    view.targets.enemy.classification.scripts.OnMouseUp(view.targets.enemy.classification, 'LeftButton')
    assert(page.selectedSection.title == 'General' and page.nameplateIndicatorPart() == 'classification', 'click opens that indicator')
    view.targets.enemy.level.scripts.OnMouseUp(view.targets.enemy.level, 'LeftButton')
    assert(page.nameplateIndicatorPart() == 'level', 'level click selects Level')
    local buffIcon = sample.auraIcons.buffs[1]
    buffIcon.scripts.OnMouseUp(buffIcon, 'LeftButton')
    assert(page.selectedSection.title == 'Auras' and page.nameplateAuraGroup() == 'buffs', 'aura click opens its group')
    assert(page.auraAnchorButtons.RIGHT.selected and not page.auraAnchorButtons.TOP.selected, 'the anchor picker shows the group')
    page.auraAnchorButtons.BOTTOMLEFT.scripts.OnClick(page.auraAnchorButtons.BOTTOMLEFT)
    assert(M.db.enemy.buffs.anchor == 'BOTTOMLEFT' and page.auraAnchorButtons.BOTTOMLEFT.selected, 'picking an anchor')
    assert(M:SetOption('enemy', 'anchor', 'RIGHT', 'buffs'))
    assert(page.nameAnchorButtons.CENTER, 'text anchors include the middle')
    -- Copy To… and Reset… in the footer replace the page's own buttons.
    local window = addon.configWindow
    assert(page.copyButton == nil and page.resetButton == nil, 'no copy or reset buttons on the page')
    assert(window.copyButton:IsShown() and window.resetButton:IsShown(), 'Copy To… and Reset… in the footer')
    page.SetEditing('enemy')
    local copy = addon:ConfigActionItems('copy', M)
    assert(#copy == 1 and copy[1].label == 'Enemy style to Friendly plates' and copy[1].prompt, 'copy the kind being edited')
    assert(M:SetOption('enemy', 'width', 150) and M:SetOption('friendly', 'show', false))
    copy[1].run()
    assert(M.db.friendly.width == 150 and M.db.friendly.show == false and M.db.friendly.healthColorMode == M.db.enemy.healthColorMode,
        'the look copies; Use ModeUI Plates stays')
    assert(M:SetOption('friendly', 'show', true))
    page.SetEditing('friendly')
    copy = addon:ConfigActionItems('copy', M)
    assert(copy[1].label == 'Friendly style to Enemy plates', 'read when the menu opens')
    page.SetEditing('enemy')
    local reset = addon:ConfigActionItems('reset', M)
    assert(#reset == 3 and reset[1].label == 'Enemy plates' and reset[2].label == 'Friendly plates' and reset[3].label == 'All of Nameplates')
    reset[2].run()
    assert(M.db.friendly.width == M.styleDefaults.friendly.width and M.db.enemy.width == 150 and M.db.friendly.show == true, 'one kind resets')
    reset[3].run()
    assert(M.db.enemy.width == M.styleDefaults.enemy.width and M.db.enemy.healthText == M.styleDefaults.enemy.healthText and M.db.friendly.show == true,
        'both kinds reset')
    assert(M:SetOption('enemy', 'width', 180) and M:SetOption('enemy', 'healthText', 'both'))
    window:Hide()

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
    assert(db.version == 14 and db.width == nil and db.texture == nil and db.enabled == true, 'flat keys moved')
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
    assert(db.version == 14 and db.enemy.texture == nil and db.friendly.texture == nil, 'texture retired')
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
    assert(addon.Nameplates.db.version == 14 and style.auraPosition == nil and style.auraDebuffs == nil and style.auraSize == nil, 'old keys gone')
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
    assert(db.version == 14 and db.enemy.targetHighlight == nil and db.enemy.targetStyle == 'none' and db.friendly.targetStyle == 'border')
    assert(db.enemy.debuffs.grow == 'left' and db.enemy.buffs.grow == 'right', 'grow from anchors')
    -- Then version 12: crowd control, still at version 11's Left (growing left),
    -- moves above; the name and the marker at version 11's defaults take the baseline.
    assert(db.enemy.crowdControl.anchor == 'TOP' and db.enemy.crowdControl.grow == 'center', 'crowd control at the old default moves')
    assert(db.enemy.display == 'plate' and db.enemy.raidSize == 14, 'version 12 baseline')
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
    assert(db.version == 14 and db.enemy.softness == nil and db.friendly.softness == nil, 'softness removed')
    assert(db.enemy.healthOpacity == 100 and db.enemy.backgroundOpacity == 85 and db.friendly.backgroundOpacity == 85, 'opacity defaults (Mode-Obsidian: 85)')
    assert(db.enemy.width == 180, 'other settings kept')
]==], "nameplates_v5")

-- Version 6: the one indicator's place and sizes go to every indicator.
local v6 = world.saved()
np = v6.profiles.Default.modules.nameplates
np.version = 6
for _, key in ipairs({ 'quest', 'classification', 'level' }) do
    np.enemy[key .. 'Anchor'], np.enemy[key .. 'X'], np.enemy[key .. 'Y'], np.enemy[key .. 'Size'] = nil, nil, nil, nil
end
np.enemy.indicatorAnchor, np.enemy.indicatorX, np.enemy.indicatorY, np.enemy.indicatorSize, np.enemy.indicatorFontSize = 'TOPLEFT', 3, -2, 18, 11
H.Load({ before = STUBS, saved = v6 }).run([==[
    local e = addon.Nameplates.db.enemy
    assert(addon.Nameplates.db.version == 14 and e.indicatorAnchor == nil and e.indicatorFontSize == nil, 'old keys gone')
    assert(e.questAnchor == 'TOPLEFT' and e.levelAnchor == 'TOPLEFT' and e.classificationX == 3 and e.levelY == -2, 'place carried over')
    assert(e.questSize == 18 and e.classificationSize == 18 and e.levelSize == 11, 'sizes carried over')
]==], "nameplates_v6")

-- 12.1 aura containers: when the client has CustomAuraContainerTemplate, the
-- game reads auras in secure code and fills buttons ModeUI styled once.
local CONTAINERS = STUBS .. [==[
    C_XMLUtil = { GetTemplateInfo = function(name) if name == 'CustomAuraContainerTemplate' or name == 'DisableUntrustedLayoutScriptsTemplate' then return {} end end }
    Enum = Enum or {}
    Enum.CustomAuraButtonDispelTypeTextureStyle = { PreserveAsset = 3 }
    Enum.LuaCurveType = { Linear = 0, Step = 1 }
    C_CurveUtil = { CreateColorCurve = function()
        local curve = { points = {} }
        function curve:SetType(t) self.type = t end
        function curve:AddPoint(x, color) self.points[x] = color end
        return curve
    end }
    C_StringUtil = { CreateNumericRuleFormatter = function()
        local f = { breakpoints = {} }
        function f:AddBreakpoint(b) self.breakpoints[#self.breakpoints + 1] = b end
        return f
    end }
    containers = {}
    -- The forbidden aspect UntrustedLayoutScriptExecution, as the game applies
    -- it: an aura container carries it, and anything anchored to a frame that
    -- carries it must carry it already (made from the template, or created
    -- inside a frame that was); it is never inherited through SetPoint.
    local methods = getmetatable(UIParent).__index
    local setPoint = methods.SetPoint
    local function Carries(region)
        for _ = 1, 4 do
            if not region then return false end
            if region.forbidden or region.template == 'DisableUntrustedLayoutScriptsTemplate' then return true end
            region = region.parent
        end
        return false
    end
    function methods:SetPoint(point, relative, ...)
        if type(relative) == 'table' and Carries(relative) and relative ~= self.parent and not Carries(self) then
            error('Anchoring disallowed as dependent object would inherit forbidden aspects: UntrustedLayoutScriptExecution')
        end
        return setPoint(self, point, relative, ...)
    end
    local createFrame = CreateFrame
    function CreateFrame(kind, name, parent, template)
        if kind ~= 'AuraContainer' then local f = createFrame(kind, name, parent, template); f.template = template; return f end
        local c = createFrame('Frame', name, parent)
        c.template, c.groups, c.order, c.calls = template, {}, {}, {}
        c.forbidden = true
        function c:AddAuraGroup(key, filter, options)
            assert(not self.groups[key], 'groups are added once')
            self.groups[key] = { filter = filter, options = options, enabled = true, max = options.maxFrameCount }
            self.order[#self.order + 1] = key
            local button = createFrame('Frame', nil, self)
            function button:SetIcon(t) self.iconRegion = t end
            function button:SetDurationCooldown(cd) self.cooldownRegion = cd end
            function button:SetApplicationCount(fs) self.countRegion = fs end
            function button:AddDispelTypeTexture(t, o)
                -- As Blizzard's AddDisplayElement: a list; the same texture twice is an error.
                self.dispelTextures = self.dispelTextures or {}
                for _, held in ipairs(self.dispelTextures) do assert(held ~= t, 'Display element has already been added.') end
                self.dispelTextures[#self.dispelTextures + 1] = t; self.dispelOptions = o
            end
            function button:SetDurationText(fs, o) self.timerRegion, self.timerOptions = fs, o end
            options.initializeFrame(button)
            self.groups[key].button = button
        end
        function c:SetAuraGroupFilterString(key, f) self.groups[key].filter = f end
        function c:SetAuraGroupMaxFrameCount(key, n) self.groups[key].max = n end
        function c:SetAuraGroupLayout(key, l) self.groups[key].layout = l end
        function c:SetAuraGroupEnabled(key, on) self.groups[key].enabled = on end
        function c:SetEnabled(on) self.enabled = on end
        function c:SetUnit(unit) self.unit = unit end
        function c:UpdateAllAuras() self.updates = (self.updates or 0) + 1 end
        function c:SetFlowLayoutAnchorPoint(p) self.flowAnchor = p end
        function c:SetFlowLayoutAxis(a) self.axis = a end
        function c:SetFlowLayoutGrowthDirection(h, v) self.growth = { h, v } end
        containers[#containers + 1] = c
        return c
    end
]==]
local withContainers = H.Load({ before = CONTAINERS })
withContainers.run([==[
    local M = addon.Nameplates
    addon:SetModuleEnabled('nameplates', true)
    AddPlate('nameplate1', Hostile())
    local plate = M.byUnit.nameplate1
    assert(M:UsesAuraContainers(), 'the template is found')
    local C = plate.auraContainers
    -- The baseline's rows: crowd control on Top, your debuffs on the border line
    -- top right (their own container), buffs Right; one container each.
    local D = C['TOPRIGHT:border']
    assert(C.TOP and D and C.RIGHT and D.template == 'CustomAuraContainerTemplate', 'one container per row')
    assert(C.TOP.enabled and C.TOP.unit == 'nameplate1' and C.TOP:IsShown() and C.TOP.updates >= 1, 'pointed at the unit')
    assert(C.TOP.groups.crowdControl.filter == 'HARMFUL|CROWD_CONTROL|INCLUDE_NAME_PLATE_ONLY', 'crowd control filter')
    assert(D.groups.debuffs.filter == 'HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL' and D.groups.debuffs.max == 4, 'your debuffs')
    assert(C.RIGHT.groups.buffs.filter == 'HELPFUL|DISPELLABLE' and C.RIGHT.groups.buffs.max == 3, 'dispellable buffs')
    -- Buttons are styled in the Mode look and registered for the game to fill.
    local button = D.groups.debuffs.button
    assert(button.iconRegion == button.icon and button.cooldownRegion == button.cooldown and button.countRegion == button.count, 'regions registered')
    -- Rims by type through a step curve on the dispel type IDs, which also colors secret types.
    local curve = button.dispelOptions.customDispelColorCurve
    local e = M.db.enemy
    assert(button.dispelTextures[1] == button.rim and #button.dispelTextures == 8 and curve and curve.type == Enum.LuaCurveType.Step, 'rim by dispel type through a curve, all eight pieces')
    assert(curve.points[1].r == e.auraMagicColor[1] and curve.points[2].r == e.auraCurseColor[1] and curve.points[9].r == e.auraEnrageColor[1], 'type IDs')
    assert(curve.points[11].r == e.auraBleedColor[1] and curve.points[0].r == e.auraNoTypeColor[1], 'bleed and no type')
    assert(button.dispelOptions.showWithoutDispelType and button.dispelOptions.showWhenHelpful, 'every aura gets a rim')
    -- Crowd control without a type is #FF5948 by default.
    local cc = C.TOP.groups.crowdControl.button.dispelOptions.customDispelColorCurve
    assert(cc.points[0].r == e.auraCCNoTypeColor[1] and e.auraCCNoTypeColor[1] == 1 and math.abs(e.auraCCNoTypeColor[2] - 89 / 255) < 1e-9 and math.abs(e.auraCCNoTypeColor[3] - 72 / 255) < 1e-9, '#FF5948 crowd control without a type')
    -- Swipe and time text are registered for the game to drive.
    assert(button.timerRegion == button.timer and button.timerOptions.textFormatter.breakpoints[1].format == '%d', 'time text')
    assert(not button.timer.lift:IsShown(), 'no lifted copy on game-driven text')
    assert(math.abs(button.width - 24) < 1 and math.abs(button.height - 20) < 1, 'Mode shape: 24 x 20')
    local ccButton = C.TOP.groups.crowdControl.button
    assert(ccButton.flash:IsShown() and ccButton.flashAnim:IsPlaying() and not button.flash:IsShown(), 'containers: crowd control GCD flash')
    assert(button.timer.color[1] == M.db.enemy.auraTimerColor[1], 'containers: cooldown text color')
    -- Placement. Your debuffs: by the container's bottom right on the bar's top
    -- right, 2px up, growing left. Crowd control: by its own middle (so it stays
    -- centered as it resizes), past the border line. Buffs: beside the bar.
    local d = Point(D)
    assert(d[1] == 'BOTTOMRIGHT' and d[2] == plate.healthBox and d[3] == 'TOPRIGHT' and d[5] == 2 and D.flowAnchor == 'BOTTOMRIGHT', 'debuffs on the border line')
    local t = Point(C.TOP)
    assert(t[1] == 'BOTTOM' and t[3] == 'TOP' and C.TOP.flowAnchor == 'BOTTOMLEFT' and t[5] == 2 + plate.above, 'crowd control centered above')
    assert(t[4] == 0.5, 'a half-pixel nudge keeps the centered row on whole pixels: ' .. tostring(t[4]))
    assert(Point(C.RIGHT)[1] == 'LEFT' and Point(C.RIGHT)[3] == 'RIGHT' and Point(C.RIGHT)[4] == 2, 'buffs beside the bar')
    -- Edge marks follow each container (made from Blizzard's template for frames
    -- anchored to one); whatever follows a row anchors to its mark.
    local mark = plate.auraEnds.RIGHT
    assert(mark.template == 'DisableUntrustedLayoutScriptsTemplate' and Point(mark)[1] == 'LEFT' and Point(mark)[2] == C.RIGHT and Point(mark)[3] == 'RIGHT', 'buffs edge mark')
    assert(Point(plate.auraEnds.TOP)[2] == C.TOP and Point(plate.auraEnds.TOP)[3] == 'TOP', 'crowd control edge mark')
    assert(Point(plate.arrowFrames.right)[2] == mark, 'the right arrow follows the buffs')
    -- The name on the border stops at the debuffs' left edge: the game shortens it as they come.
    local stop = plate.nameStops['TOPRIGHT:border|LEFT']
    assert(Point(stop)[1] == 'BOTTOMRIGHT' and Point(stop)[2] == D and Point(stop)[3] == 'BOTTOMLEFT', 'name stop on the debuffs')
    local name2 = Point(plate.name, 2)
    assert(name2[1] == 'BOTTOMRIGHT' and name2[2] == stop and name2[4] == -3, 'the name stops 3px short of the debuffs')
    -- Settings change through setters; look changes make a new container.
    local top = D
    assert(M:SetOption('enemy', 'max', 3, 'debuffs') and plate.auraContainers['TOPRIGHT:border'] == top and top.groups.debuffs.max == 3, 'max through setters')
    assert(M:SetOption('enemy', 'show', false, 'debuffs') and not top.enabled and not top:IsShown(), 'a hidden group stops its container')
    assert(M:SetOption('enemy', 'show', true, 'debuffs') and top.enabled)
    assert(M:SetOption('enemy', 'auraTimer', false) and plate.auraContainers['TOPRIGHT:border'] ~= top and not top.enabled, 'look change: new container, old one stopped')
    assert(M:SetOption('enemy', 'auraTimerText', false) and plate.auraContainers['TOPRIGHT:border'].groups.debuffs.button.timerRegion == nil, 'time text off')
    local before = plate.auraContainers.TOP
    assert(M:SetOption('enemy', 'auraCCNoTypeColor', { 0.2, 0.4, 0.9 }) and plate.auraContainers.TOP ~= before, 'color change rebuilds')
    assert(plate.auraContainers.TOP.groups.crowdControl.button.dispelOptions.customDispelColorCurve.points[0].b == 0.9, 'custom no-type color')
    -- Removing the unit stops every container.
    RemovePlate('nameplate1')
    for _, container in pairs(plate.auraContainers) do assert(not container.enabled, 'stopped on removal') end
]==], "nameplates_containers")

-- Version 7: the old orange no-type crowd control default becomes #FF5948; a picked color stays.
local v7 = world.saved()
np = v7.profiles.Default.modules.nameplates
np.version = 7
np.enemy.auraCCNoTypeColor = { 1, 140 / 255, 40 / 255 }
np.friendly.auraCCNoTypeColor = { 0.2, 0.4, 0.9 }
H.Load({ before = STUBS, saved = v7 }).run([==[
    local db = addon.Nameplates.db
    assert(db.version == 14 and math.abs(db.enemy.auraCCNoTypeColor[2] - 89 / 255) < 1e-9, 'old default follows the new one')
    assert(db.friendly.auraCCNoTypeColor[3] == 0.9, 'a picked color stays')
]==], "nameplates_v7")

-- Version 8 -> 9: values at the version 8 defaults take the Mode ones, per
-- kind; the player's own choices stay.
local v8 = world.saved()
np = v8.profiles.Default.modules.nameplates
np.version = 8
for _, kind in ipairs({ 'enemy', 'friendly' }) do
    local s = np[kind]
    s.foregroundTexture, s.backgroundTexture, s.backgroundOpacity, s.nameColorMode, s.fontMedia, s.liftedShadow = 'mode', 'flat', 55, 'text', 'Expressway', true
    s.castTexture, s.healthTextColor = nil, nil
    s.targetColor, s.focusColor = { 216 / 255, 196 / 255, 150 / 255 }, { 1, 181 / 255, 71 / 255 }
end
np.friendly.backgroundOpacity, np.friendly.nameColorMode = 40, 'class'
H.Load({ before = STUBS, saved = v8 }).run([==[
    local db, Tone, P = addon.Nameplates.db, addon.Style.Tone, addon.Kit.palette
    local e, f = db.enemy, db.friendly
    assert(db.version == 14 and e.foregroundTexture == 'media:Mode-FG' and e.backgroundTexture == 'media:Mode-BG' and e.backgroundOpacity == 85)
    assert(e.nameColorMode == 'text' and e.fontMedia == 'Mode' and e.liftedShadow == false and e.castTexture == 'media:Mode-FG')
    assert(e.healthTextColor == 'health' and e.focusColor[1] == Tone.rosewood[1], 'old focus amber takes Rosewood')
    assert(f.backgroundOpacity == 40 and f.nameColorMode == 'class', 'picked values stay')
]==], "nameplates_v8")

-- Version 9 -> 10: auras wear the frameThin edge. Border Size 2 (the old
-- default) takes 1 and 3 takes 2; Corners retire; the old no-type rim takes Gunmetal.
local v9 = world.saved()
np = v9.profiles.Default.modules.nameplates
np.version = 9
np.enemy.auraBorderSize, np.enemy.auraCorners, np.enemy.auraNoTypeColor = 2, 'rounded', { 37 / 255, 40 / 255, 44 / 255 }
np.friendly.auraBorderSize, np.friendly.auraCorners, np.friendly.auraNoTypeColor = 3, 'sharp', { 0.5, 0.1, 0.1 }
H.Load({ before = STUBS, saved = v9 }).run([==[
    local db = addon.Nameplates.db
    assert(db.version == 14 and db.enemy.auraBorderSize == 1 and db.friendly.auraBorderSize == 2, 'sizes move')
    assert(db.enemy.auraCorners == nil and db.friendly.auraCorners == nil, 'Corners retired')
    assert(addon.Style.SameColor(db.enemy.auraNoTypeColor, addon.Style.Tone.gunmetal.mid) and db.friendly.auraNoTypeColor[1] == 0.5, 'old rim moves, picked stays')
]==], "nameplates_v9")

-- Version 10 -> 11: solid empty bars (100) take the see-through 60; picked values stay.
local v10 = world.saved()
np = v10.profiles.Default.modules.nameplates
np.version, np.enemy.backgroundOpacity, np.friendly.backgroundOpacity = 10, 100, 45
np.enemy.edgeStyle, np.enemy.edgeMetal, np.friendly.edgeStyle, np.friendly.edgeMetal = nil, nil, nil, nil
H.Load({ before = STUBS, saved = v10 }).run([==[
    local db = addon.Nameplates.db
    assert(db.version == 14 and db.enemy.backgroundOpacity == 60 and db.friendly.backgroundOpacity == 45, '100 becomes 60')
    assert(db.enemy.edgeStyle == 'obsidian' and db.friendly.edgeMetal == 'default', 'the border keys arrive with their defaults')
]==], "nameplates_v10")

-- Version 11 -> 12, the nameplates pass (owner, November 23, 2026): values
-- still at version 11's defaults take the baseline; picked values stay, and a
-- customized plate keeps its look (Indicators First, its name off the border).
local function V11Profile(edit)
    local saved = world.saved()
    local np = saved.profiles.Default.modules.nameplates
    np.version = 11
    local e, f = np.enemy, np.friendly
    e.width, e.healthHeight, e.castY, e.healthFontSize, e.nameFontSize, e.castFontSize = 140, 12, -2, 9, 10, 9
    e.nameAnchor, e.nameX, e.nameY, e.raidAnchor, e.raidX, e.raidY, e.raidSize = 'TOP', 0, 0, 'LEFT', 0, 0, 16
    e.castTargetAnchor, e.questSize, e.levelSize, e.targetStyle, e.targetArrowSize, e.targetArrowGap = 'BOTTOM', 14, 9, 'border', 12, 4
    e.levelAnchor, e.levelX, e.levelY, e.classificationAnchor, e.classificationX, e.classificationY = 'LEFT', 0, 0, 'LEFT', 0, 0
    e.softTargetSize, e.auraSpacing, e.auraShape, e.comboAnchor = 20, 2, 'cropped', 'BOTTOM'
    e.castColor, e.castLockedColor = { 0xE8 / 255, 0xB0 / 255, 0x4B / 255 }, { 0x8C / 255, 0x8C / 255, 0x8C / 255 }
    e.crowdControl = { show = true, anchor = 'LEFT', grow = 'left', x = 0, y = 0, size = 24, max = 2, attach = false }
    e.debuffs = { show = true, filter = 'mine', anchor = 'TOP', grow = 'center', x = 0, y = 0, size = 20, max = 6, attach = false }
    e.buffs = { show = true, filter = 'dispellable', anchor = 'RIGHT', grow = 'right', x = 0, y = 0, size = 18, max = 3, attach = false }
    f.display, f.showAuras, f.nameFontSize, f.auraSpacing, f.auraShape = 'plate', true, 10, 2, 'cropped'
    for _, s in ipairs({ e, f }) do
        s.nameOnBorder, s.auraOrder, s.comboFollowCast, s.levelInside, s.classificationInside = nil, nil, nil, nil, nil
        s.questInside, s.raidInside, s.castChannelColor, s.softTargetCombat = nil, nil, nil, nil
    end
    if edit then edit(e, f) end
    return saved
end
H.Load({ before = STUBS, saved = V11Profile() }).run([==[
    local db, M = addon.Nameplates.db, addon.Nameplates
    local e, f = db.enemy, db.friendly
    assert(db.version == 14 and e.width == 156 and e.healthHeight == 16 and e.castY == -1, 'version 11 defaults take the baseline')
    assert(e.nameAnchor == 'TOPLEFT' and e.nameY == -3 and e.nameOnBorder and e.raidAnchor == 'CENTER' and e.levelInside and e.classificationInside, 'name, marker, indicators')
    assert(e.crowdControl.anchor == 'TOP' and e.crowdControl.grow == 'center' and e.crowdControl.size == 35, 'crowd control above')
    assert(e.debuffs.anchor == 'TOPRIGHT' and e.debuffs.attach and e.debuffs.max == 4 and e.buffs.size == 22, 'your debuffs on the border line')
    assert(e.auraOrder == 'auras' and e.comboFollowCast and e.auraShape == 'mode' and e.auraSpacing == 1 and e.targetStyle == 'arrows', 'auras first, arrows')
    assert(addon.Style.SameColor(e.castColor, addon.Style.Tone.cast.casting) and addon.Style.SameColor(e.castLockedColor, addon.Style.Tone.cast.shielded), 'cast colors')
    assert(f.display == 'name' and not f.showAuras and f.nameFontSize == 13, 'friendly plates: names only')
]==], "nameplates_v11")
H.Load({ before = STUBS, saved = V11Profile(function(e)
    e.nameAnchor, e.width, e.crowdControl.anchor, e.comboAnchor = 'BOTTOM', 170, 'RIGHT', 'TOP'
    e.castColor = { 0.1, 0.2, 0.3 }
end) }).run([==[
    local e = addon.Nameplates.db.enemy
    assert(e.width == 170 and e.nameAnchor == 'BOTTOM' and not e.nameOnBorder, 'a picked name place stays off the border')
    assert(e.crowdControl.anchor == 'RIGHT' and e.auraOrder == 'indicators' and not e.comboFollowCast, 'a customized plate keeps its order')
    assert(addon.Style.SameColor(e.castColor, { 0.1, 0.2, 0.3 }), 'a picked cast color stays')
]==], "nameplates_v11_custom")

-- Combo points set to Move Up While Not Casting sit under the health bar
-- until a cast shows, then under the cast bar.
H.Load({ before = STUBS }).run([==[
    local M = addon.Nameplates
    addon:SetModuleEnabled('nameplates', true)
    comboPoints = 2
    local first = AddPlate('nameplate1', Hostile())
    nameplates.target = first; FireEvent('PLAYER_TARGET_CHANGED')
    local plate = M.byUnit.nameplate1
    local row = plate.stackRows.BOTTOM
    assert(M.db.enemy.comboFollowCast and plate.combo:IsShown() and Point(plate.combo)[2] == row, 'points in the Bottom stack')
    assert(Point(row)[5] == -2 - plate.belowNoCast and plate.belowNoCast < plate.below, 'under the health bar while nothing is cast')
    units.nameplate1.cast = { name = 'Fireball', text = 'Fireball', icon = 1, start = 100000, stop = 102000, locked = false }
    FireEvent('UNIT_SPELLCAST_START', 'nameplate1')
    assert(plate.castBox:IsShown() and Point(row)[5] == -2 - plate.below, 'under the cast bar while casting')
    units.nameplate1.cast = nil; FireEvent('UNIT_SPELLCAST_STOP', 'nameplate1')
    assert(not plate.castBox:IsShown() and Point(row)[5] == -2 - plate.belowNoCast, 'back up when the cast ends')
    -- Centered on the plate.
    assert(Point(row)[1] == 'TOP' and Point(row)[3] == 'BOTTOM' and Point(row)[4] == 0, 'centered')
]==], "nameplates_combo_follow")

-- Invalid saved settings stop validation instead of being reset.
local broken = world.saved()
broken.profiles.Default.modules.nameplates.enemy.width = 'wide'
local ok = pcall(H.Load, { before = STUBS, saved = broken })
assert(not ok, 'invalid nameplate settings are refused, not reset')
-- The Mode-DPS/TANK layout's part: aura icons 1px apart (owner, November 18, 2026).
H.Load({ before = STUBS }).run([==[
    for _, variant in ipairs({ '1080', '1440' }) do
        local profile = assert(addon.Layouts:Build('mode-default', variant))
        local db = profile.modules.nameplates
        assert(db.enabled == true and db.enemy.auraSpacing == 1 and db.friendly.auraSpacing == 1, 'nameplate auras 1px apart')
    end
]==], "nameplates_layout")
print("nameplates: all checks passed")

-- Version 12 -> 13, readable text (owner, November 24, 2026): enemy names
-- still in Class or Reaction take the text color; a picked color stays; the
-- halo keys fill in (then off, from version 14).
local function V12Profile(enemyColor)
    local saved = world.saved()
    local np = saved.profiles.Default.modules.nameplates
    np.version = 12
    np.enemy.nameColorMode, np.friendly.nameColorMode = enemyColor, 'class'
    for _, s in ipairs({ np.enemy, np.friendly }) do
        s.nameTextGlow, s.nameTextGlowColor, s.nameTextGlowStrength, s.healthTextGlowColor, s.healthTextGlowStrength = nil, nil, nil, nil, nil
    end
    np.enemy.healthTextGlow = false
    return saved
end
H.Load({ before = STUBS, saved = V12Profile('class') }).run([==[
    local db = addon.Nameplates.db
    assert(db.version == 14 and db.enemy.nameColorMode == 'text' and db.friendly.nameColorMode == 'class', 'enemy names take the text color')
    assert(db.enemy.nameTextGlow == false and db.enemy.nameTextGlowColor == 'ink' and db.friendly.healthTextGlowStrength == 60 and db.fixedScale == nil, 'new keys fill in')
    assert(db.enemy.healthTextGlow == false, 'a switched-off health glow stays off')
]==], "nameplates_v12")
H.Load({ before = STUBS, saved = V12Profile('gradient') }).run([==[
    assert(addon.Nameplates.db.enemy.nameColorMode == 'gradient', 'a picked name color stays')
]==], "nameplates_v12_picked")

-- Version 13 -> 14 (owner, November 24, 2026): outlined slug text a size
-- larger instead of the halos; Same Size at Any Distance is gone. Values
-- still at version 13's defaults move; picked ones stay.
local function V13Profile()
    local saved = world.saved()
    local np = saved.profiles.Default.modules.nameplates
    np.version, np.fixedScale = 13, true
    local e, f = np.enemy, np.friendly
    e.nameFontSize, e.healthFontSize, e.castFontSize, e.levelSize = 13, 11, 9, 10
    f.nameFontSize = 12
    for _, s in ipairs({ e, f }) do s.outline, s.nameTextGlow, s.healthTextGlow = false, true, true end
    f.healthTextGlow = false
    return saved
end
H.Load({ before = STUBS, saved = V13Profile() }).run([==[
    local db = addon.Nameplates.db
    local e, f = db.enemy, db.friendly
    assert(db.version == 14 and db.fixedScale == nil, 'Same Size at Any Distance is gone')
    assert(e.nameFontSize == 14 and e.healthFontSize == 12 and e.levelSize == 11 and f.nameFontSize == 13, 'a size larger')
    assert(e.castFontSize == 9, 'a picked size stays')
    assert(e.outline and f.outline and not e.nameTextGlow and not e.healthTextGlow and not f.nameTextGlow, 'outlined, halos off')
]==], "nameplates_v13")
