-- Tooltip: Blizzard's tooltips (stubbed with Forever's keys) in the Mode
-- look: the NineSlice faded, the Mode window, quality and class rims,
-- line fonts, the health bar; placement at the Edit Mode anchor or the
-- cursor; Hide in Combat with Shift; settings, the page, validation, reload
-- and persistence. Simulated client; not WoW rendering, mouse or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/skin_stubs.lua") .. [==[
    local NINE = { 'TopLeftCorner', 'TopRightCorner', 'BottomLeftCorner', 'BottomRightCorner', 'TopEdge', 'BottomEdge', 'LeftEdge', 'RightEdge', 'Center' }
    -- A GameTooltipTemplate tooltip: NineSlice, overlays, lines, a status bar.
    local function MakeTooltip(name)
        local tooltip = CreateFrame('Frame', name, UIParent)
        tooltip.NineSlice = CreateFrame('Frame', nil, tooltip)
        for _, key in ipairs(NINE) do tooltip.NineSlice[key] = tooltip.NineSlice:CreateTexture(nil, 'BORDER') end
        tooltip.TopOverlay, tooltip.BottomOverlay = tooltip:CreateTexture(nil, 'OVERLAY'), tooltip:CreateTexture(nil, 'OVERLAY')
        for i = 1, 3 do
            local left = tooltip:CreateFontString(); left:SetFont('Fonts/FRIZQT__.TTF', i == 1 and 14 or 12, '')
            local right = tooltip:CreateFontString(); right:SetFont('Fonts/FRIZQT__.TTF', 12, '')
            _G[name .. 'TextLeft' .. i], _G[name .. 'TextRight' .. i] = left, right
        end
        function tooltip:GetItem() return self.item and 'Sword', self.item and 'item:1', self.item end
        function tooltip:GetUnit() return self.unitName, self.unit end
        function tooltip:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
        function tooltip:SetMinimumWidth(width) self.minWidth = width end
        function tooltip:SetPadding(...) self.padding = { ... } end
        function tooltip:GetPrimaryTooltipData() return self.data end
        tooltip:Hide()
        return tooltip
    end
    GameTooltip = nil -- the unit frame stubs' bare stand-in
    MakeTooltip('GameTooltip'); MakeTooltip('ItemRefTooltip'); MakeTooltip('ShoppingTooltip1')
    local bar = CreateFrame('StatusBar', 'GameTooltipStatusBar', GameTooltip)
    GameTooltip.StatusBar = bar
    function bar:SetStatusBarColor(...) self.barColor = { ... } end
    function bar:GetStatusBarTexture() return self.statusBarTexture end
    -- Blizzard places the main tooltip, then fills it.
    function GameTooltip_SetDefaultAnchor(tooltip, parent)
        tooltip:SetOwner(parent, 'ANCHOR_NONE'); tooltip:ClearAllPoints(); tooltip:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', -9, 85)
    end
    postCalls = {}
    TooltipDataProcessor = { AllTypes = 'ALL', AddTooltipPostCall = function(kind, fn) postCalls[#postCalls + 1] = fn end }
    C_Item = { GetItemQualityByID = function(id) return id == 7 and 4 or nil end,
        GetItemQualityColor = function(q) return 0.64, 0.21, 0.93 end }
    function UnitIsPlayer(unit) return unit == 'mouseover' end
    function UnitClass(unit) return 'Mage', 'MAGE' end
    reaction, tapped, level = 2, false, 40
    function UnitReaction() return reaction end
    function UnitIsTapDenied() return tapped end
    function UnitLevel(unit) return unit == 'player' and 33 or level end
    LEVEL = 'Level'
    Enum = Enum or {}
    Enum.TooltipDataLineType = { None = 0, QuestObjective = 8, QuestTitle = 17, QuestPlayer = 18 }
    RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    shift = false
    function IsShiftKeyDown() return shift end
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, Skin, Kit = addon.Tooltip, addon.Skin, addon.Kit
    local Tone = addon.Style.Tone
    local G = Tone.graphite
    assert(M and addon.modules.tooltip == M and not M.enabled, 'registered, off by default')
    assert(M.db.position == 'anchor' and M.db.border and not M.db.hideInCombat and M.db.fontMedia == 'Mode', 'the Mode typeface')
    assert(M.db.borderSize == nil and M.db.borderColor == nil and M.db.rounded == nil and M.db.gradient == nil, 'the edge has no shape or color settings')
    assert(M.db.qualityBorder and not M.db.classBorder, 'quality borders on, class borders off')
    assert(M.db.backgroundColor[1] == G.panel[1], 'Graphite panel')
    assert(M.db.hostileColor[1] == Tone.reaction.hostile[1] and M.db.questColor[1] == Tone.quest[1], 'the gameplay tones')
    assert(Skin.parts[GameTooltip] == nil, 'nothing skinned while off')

    addon:SetModuleEnabled('tooltip', true)
    -- Look: Blizzard's NineSlice faded; a Mode window: Mode Panel in
    -- Graphite at 92% with its lift, the `window` edge inside it above the
    -- lines, no soft drop under a see-through tooltip.
    local parts = Skin.parts[GameTooltip]
    assert(GameTooltip.NineSlice.alpha == 0 and GameTooltip.TopOverlay.alpha == 0, 'Blizzard\'s border and background faded')
    assert(parts.faceKey == 'Panel' and parts.face.vertexColor[1] == G.panel[1] and parts.face.vertexColor[4] == 0.92 and parts.lift, 'Mode Panel at 92%')
    assert(parts.modeEdge.preset == 'window' and parts.modeEdge.holder:IsShown() and Point(parts.edgeFrame)[4] == 3, 'the window edge inside it')
    assert(parts.edgeFrame:GetFrameLevel() > GameTooltip:GetFrameLevel() and not parts.modeEdge.below:IsShown(), 'above the lines; no drop')
    assert(parts.modeEdge.tint == nil, 'the edge\'s steel for plain content')
    assert(GameTooltip.clamped == true and GameTooltip.clampInsets[1] == 0, 'kept on the screen, edge and all')
    assert(Skin.parts[ItemRefTooltip].modeEdge and Skin.parts[ShoppingTooltip1].modeEdge, 'item links and comparisons too')
    local path = Kit.FontPath(M.db, 'tooltip')
    assert(GameTooltipTextLeft1.font[1] == addon.Style.Weighted(path, 'semibold') and GameTooltipTextLeft1.font[2] == 14, 'the header line in SemiBold')
    assert(GameTooltipTextLeft2.font[1] == path and GameTooltipTextLeft2.font[2] == 12, 'lines in the Mode face')
    local mp = Skin.parts[ModeUITooltipMover]
    assert(mp.modeEdge.preset == 'control' and mp.modeEdge.highlight[1] == Tone.ivory[1], 'the Edit Mode stand-in: a Mode control lit Ivory')
    -- No health bar.
    GameTooltipStatusBar:Show(); assert(not GameTooltipStatusBar:IsShown(), 'the health bar is gone')

    -- Placement: Blizzard's default spot becomes the Edit Mode anchor.
    local mover = ModeUITooltipMover
    local element = addon.PositionManager:Element('modeTooltip')
    assert(mover and element, 'an Edit Mode element')
    assert(element.allowedTargets.selected and element.allowedTargets.player, 'attachable to elements and picked frames')
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    local p = Point(GameTooltip); assert(p[1] == 'BOTTOMRIGHT' and p[2] == mover and p[3] == 'BOTTOMRIGHT', 'at the anchor')
    assert(M:SetOption('anchorPoint', 'TOPLEFT'))
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent); assert(Point(GameTooltip)[1] == 'TOPLEFT', 'grows from Anchor Point')
    assert(M:SetOption('position', 'cursor'))
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent); assert(GameTooltip.anchor == 'ANCHOR_CURSOR', 'or the cursor')
    M:SetOption('position', 'anchor')
    GameTooltip_SetDefaultAnchor(ItemRefTooltip, UIParent); assert(Point(ItemRefTooltip)[2] == UIParent, 'only the main tooltip is placed')
    addon:SetEditMode(true); assert(mover:IsShown(), 'the anchor shows in Edit Mode')
    addon:SetEditMode(false); assert(not mover:IsShown())

    -- Rims by content: quality, class, else the edge's steel.
    local rim = parts.modeEdge.rimTexture
    GameTooltip.item = 7; GameTooltip:Show()
    assert(parts.modeEdge.tint[1] == 0.64 and rim.vertexColor[1] == 0.64, 'Epic item: the rim in its quality')
    GameTooltip:Hide(); GameTooltip.item = nil; GameTooltip.unit = 'mouseover'; GameTooltip:Show()
    assert(parts.modeEdge.tint == nil, 'a player: the steel while Class Border is off')
    GameTooltip:Hide(); assert(M:SetOption('classBorder', true)); GameTooltip:Show()
    assert(parts.modeEdge.tint[1] == 0.25, 'a mage: class rim')
    GameTooltip:Hide(); GameTooltip.unit = { secret = true }; GameTooltip:Show()
    assert(parts.modeEdge.tint == nil, 'a secret unit keeps the steel')
    GameTooltip:Hide()

    -- Text colors: a player's name and class line, the level number.
    local function Lines(...) local texts = { ... }; for i = 1, 3 do _G['GameTooltipTextLeft' .. i]:SetText(texts[i]); _G['GameTooltipTextLeft' .. i]:SetTextColor(1, 1, 1) end end
    GameTooltip.unit = 'mouseover'
    Lines('Peyton', 'Level 30 Orc (Player)', 'Mage')
    postCalls[1](GameTooltip, { lines = {} })
    assert(GameTooltipTextLeft1.color[1] == 0.25, 'player name: class color')
    assert(GameTooltipTextLeft3.color[1] == 0.25, 'class line: class color')
    assert(GameTooltipTextLeft2.text:find('|cff', 1, true) and GameTooltipTextLeft2.text:find('30|r', 1, true), 'only the level number colored')
    -- An NPC: name by reaction; tapped is gray.
    GameTooltip.unit = 'target'
    Lines('Defias Thug', 'Level 40 Humanoid', '')
    postCalls[1](GameTooltip, { lines = {} })
    assert(GameTooltipTextLeft1.color[1] == M.db.hostileColor[1], 'hostile NPC')
    reaction = 4; postCalls[1](GameTooltip, { lines = {} }); assert(GameTooltipTextLeft1.color[1] == M.db.neutralColor[1], 'neutral')
    reaction = 5; postCalls[1](GameTooltip, { lines = {} }); assert(GameTooltipTextLeft1.color[1] == M.db.friendlyColor[1], 'friendly')
    tapped = true; postCalls[1](GameTooltip, { lines = {} }); assert(GameTooltipTextLeft1.color[1] == Tone.reaction.tapped[1], 'tapped: gray')
    tapped, reaction = false, 2
    -- Quest lines.
    Lines('Defias Thug', 'Red Linen Goods', ' - Red Linen Bandana: 3/6')
    postCalls[1](GameTooltip, { lines = { { type = 0, leftText = 'Defias Thug' }, { type = 17, leftText = 'Red Linen Goods' },
        { type = 8, leftText = ' - Red Linen Bandana: 3/6' } } })
    assert(GameTooltipTextLeft2.color[1] == M.db.questColor[1] and GameTooltipTextLeft3.color[1] == M.db.questColor[1], 'quest lines')
    -- Custom and Blizzard modes.
    assert(M:SetOption('npcNameColor', 'custom') and M:SetOption('npcNameCustom', { 0, 0, 1 }))
    postCalls[1](GameTooltip, { lines = {} }); assert(GameTooltipTextLeft1.color[3] == 1 and GameTooltipTextLeft1.color[1] == 0, 'custom NPC name')
    assert(M:SetOption('npcNameColor', 'blizzard'))
    GameTooltipTextLeft1:SetTextColor(1, 0.82, 0); postCalls[1](GameTooltip, { lines = {} })
    assert(GameTooltipTextLeft1.color[2] == 0.82, 'Blizzard\'s color kept')
    assert(not M:SetOption('levelColor', 'rainbow') and not M:SetOption('hostileColor', { 2, 0, 0 }))
    GameTooltip.unit = nil
    -- Size: Minimum Width and Padding, set as it fills.
    assert(M:SetOption('minWidth', 200) and M:SetOption('padding', 6))
    postCalls[1](GameTooltip, { lines = {} })
    assert(GameTooltip.minWidth == 200 and GameTooltip.padding[1] == 6, 'Minimum Width and Padding')
    assert(not M:SetOption('minWidth', 900))
    -- A line Blizzard sets back to its own font is in the Mode face again on show.
    GameTooltipTextLeft3:SetFont('Fonts/FRIZQT__.TTF', 12, ''); GameTooltip:Show()
    assert(GameTooltipTextLeft3.font[1] == path, 'fonts again on show'); GameTooltip:Hide()

    -- Hide in Combat, Shift shows it.
    assert(M:SetOption('hideInCombat', true))
    testCombat = true
    GameTooltip:Show(); assert(not GameTooltip:IsShown(), 'hidden in combat')
    shift = true; GameTooltip:Show(); assert(GameTooltip:IsShown(), 'Shift shows it')
    shift = false; FireEvent('PLAYER_REGEN_DISABLED'); assert(not GameTooltip:IsShown(), 'hidden as combat starts')
    ItemRefTooltip:Show(); assert(ItemRefTooltip:IsShown(), 'a clicked item link still opens')
    testCombat = false
    GameTooltip:Show(); assert(GameTooltip:IsShown(), 'out of combat it shows')
    GameTooltip:Hide()

    -- Settings: checked on a copy; live repaint.
    assert(not M:SetOption('borderSize', 2) and not M:SetOption('rounded', false) and not M:SetOption('position', 'left') and not M:SetOption('nope', 1))
    assert(M:SetOption('backgroundOpacity', 50) and parts.face.vertexColor[4] == 0.5)
    assert(M:SetOption('backgroundOpacity', 100) and parts.modeEdge.below:IsShown(), 'an opaque tooltip has its soft drop')
    assert(M:SetOption('textSize', 14) and GameTooltipTextLeft2.font[2] == 14)
    assert(M:SetOption('scale', 120) and GameTooltip.scale == 1.2)
    assert(M:SetOption('border', false) and not parts.modeEdge.holder:IsShown() and not parts.modeEdge.below:IsShown(), 'Border off: no edge')
    assert(Point(parts.face)[4] == 0, 'the face to the tooltip\'s sides without it')
    M:ResetToDefaults(); assert(M.db.backgroundOpacity == 92 and M.db.border and M.db.npcNameColor == 'reaction')

    SlashCmdList.MODEUI()
    local window = addon.configWindow
    assert(window.pages.tooltip == nil)
    addon:SelectConfigPage('tooltip')
    local page = window.pages.tooltip
    assert(page and page:IsShown() and page.tabContentTop and page.positionPills and page.combatToggles and window.moduleHeader.title:GetText() == 'Tooltip')
    assert(page.playerNamePills and page.npcNamePills and page.levelPills and page.classTextPills and page.questToggles and page.minWidthSlider)
    window:Hide()
    M:SetOption('anchorPoint', 'TOP')

    addon:SetModuleEnabled('tooltip', false)
    assert(addon.ReloadManager.requests.tooltip, 'off asks for a reload')
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent); assert(Point(GameTooltip)[2] == UIParent, 'Blizzard places it again')

    -- Version 1: a fill still at #0B0B0D takes the health color; the health bar settings go.
    local old = { version = 1, backgroundColor = { 11 / 255, 11 / 255, 13 / 255 }, healthBar = true, healthHeight = 6, healthColor = { 0, 1, 0 } }
    M.Initialize(old)
    assert(old.version == 5 and old.backgroundColor[1] == G.panel[1] and old.healthBar == nil and old.healthColor == nil)
    assert(old.classBorder == false and old.borderSize == nil, 'version 2 defaults: no class color; the size went with version 5')
    -- Version 3 -> 4: a fill still at the old health color (#1C1E21) takes #131212 (then Graphite).
    local three = { version = 3, backgroundColor = { 28 / 255, 30 / 255, 33 / 255 } }
    M.Initialize(three); assert(three.version == 5 and three.backgroundColor[1] == G.panel[1], 'the old health color follows')
    local mine = { version = 3, backgroundColor = { 0, 0, 1 } }
    M.Initialize(mine); assert(mine.backgroundColor[3] == 1, 'a picked fill stays')
    -- Version 4 -> 5 (Phase 7): the border's shape and color settings go;
    -- the fill, reactions and Expressway still at version 4's defaults follow.
    local four = { version = 4, backgroundColor = { 19 / 255, 18 / 255, 18 / 255 }, rounded = false, gradient = true,
        borderColor = { 1, 0, 0 }, borderSize = 3, fontMedia = 'Expressway', hostileColor = { 224 / 255, 102 / 255, 102 / 255 },
        neutralColor = { 1, 209 / 255, 64 / 255 }, friendlyColor = { 0, 0, 1 } }
    M.Initialize(four)
    assert(four.version == 5 and four.rounded == nil and four.gradient == nil and four.borderColor == nil and four.borderSize == nil, 'shape and color settings gone')
    assert(four.backgroundColor[1] == G.panel[1] and four.fontMedia == 'Mode', 'Graphite and the Mode typeface')
    assert(four.hostileColor[1] == Tone.reaction.hostile[1] and four.neutralColor[1] == Tone.reaction.neutral[1], 'the gameplay tones')
    assert(four.friendlyColor[3] == 1, 'a picked reaction color stays')
]==], "tooltip")

local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([==[
    local M = addon.Tooltip
    assert(not M.enabled and M.db.anchorPoint == 'TOP' and addon.Skin.parts[GameTooltip] == nil, 'settings persist; nothing skinned while off')
]==], "tooltip_restore")
print("tooltip: all checks passed")
