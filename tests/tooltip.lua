-- Tooltip: Blizzard's tooltips (stubbed with Forever's keys) in the Mode
-- look: the NineSlice faded, fill and border, quality and class borders,
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
    RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    shift = false
    function IsShiftKeyDown() return shift end
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, Skin, Kit = addon.Tooltip, addon.Skin, addon.Kit
    assert(M and addon.modules.tooltip == M and not M.enabled, 'registered, off by default')
    assert(M.db.position == 'anchor' and M.db.borderSize == 2 and not M.db.hideInCombat)
    assert(Skin.parts[GameTooltip] == nil, 'nothing skinned while off')

    addon:SetModuleEnabled('tooltip', true)
    -- Look: Blizzard's NineSlice faded, fill and border.
    local parts = Skin.parts[GameTooltip]
    assert(GameTooltip.NineSlice.alpha == 0 and GameTooltip.TopOverlay.alpha == 0, 'Blizzard\'s border and background faded')
    assert(parts.fill.vertexColor[4] == 0.92 and parts.edge and parts.edgeRim[1].vertexColor[1] == Kit.onyx.frameRim[1], 'Onyx fill, crisp border')
    assert(Skin.parts[ItemRefTooltip].fill and Skin.parts[ShoppingTooltip1].fill, 'item links and comparisons too')
    local path = Kit.FontPath(M.db, 'tooltip')
    assert(GameTooltipTextLeft1.font[1] == path and GameTooltipTextLeft1.font[2] == 14 and GameTooltipTextLeft2.font[2] == 12, 'lines in the Mode face')
    -- Health bar: flat, Health Color, under the tooltip.
    local health = Skin.parts[GameTooltipStatusBar]
    assert(GameTooltipStatusBar.statusBarTexture == Kit.FLAT and GameTooltipStatusBar.barColor[1] == Kit.palette.green[1])
    assert(Point(GameTooltipStatusBar)[2] == GameTooltip and Point(GameTooltipStatusBar)[3] == 'BOTTOMLEFT' and GameTooltipStatusBar:GetHeight() == 6)
    GameTooltipStatusBar.barColor = { 0, 1, 0 }; GameTooltipStatusBar.scripts.OnValueChanged(GameTooltipStatusBar)
    assert(GameTooltipStatusBar.barColor[1] == Kit.palette.green[1], 'Blizzard\'s green on each value change is answered')

    -- Placement: Blizzard's default spot becomes the Edit Mode anchor.
    local mover = ModeUITooltipMover
    assert(mover and addon.PositionManager:Element('modeTooltip'), 'an Edit Mode element')
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

    -- Borders by content: quality, class, else the rim color.
    GameTooltip.item = 7; GameTooltip:Show()
    assert(parts.edgeRim[1].vertexColor[1] == 0.64, 'Epic item: quality border')
    GameTooltip:Hide(); GameTooltip.item = nil; GameTooltip.unit = 'mouseover'; GameTooltip:Show()
    assert(parts.edgeRim[1].vertexColor[1] == 0.25, 'a mage: class border')
    GameTooltip:Hide(); GameTooltip.unit = { secret = true }; GameTooltip:Show()
    assert(parts.edgeRim[1].vertexColor[1] == Kit.onyx.frameRim[1], 'a secret unit keeps the rim color')
    GameTooltip:Hide(); GameTooltip.unit = nil
    -- A line Blizzard sets back to its own font is in the Mode face again on show.
    GameTooltipTextLeft3:SetFont('Fonts/FRIZQT__.TTF', 12, ''); GameTooltip:Show()
    assert(GameTooltipTextLeft3.font[1] == path, 'fonts again on show'); GameTooltip:Hide()
    GameTooltipTextLeft2:SetFont('Fonts/FRIZQT__.TTF', 12, ''); postCalls[1](GameTooltip)
    assert(GameTooltipTextLeft2.font[1] == path, 'and before a data tooltip shows')

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
    assert(not M:SetOption('borderSize', 9) and not M:SetOption('position', 'left') and not M:SetOption('nope', 1))
    assert(M:SetOption('backgroundOpacity', 50) and parts.fill.vertexColor[4] == 0.5)
    assert(M:SetOption('textSize', 14) and GameTooltipTextLeft2.font[2] == 14)
    assert(M:SetOption('scale', 120) and GameTooltip.scale == 1.2)
    assert(M:SetOption('border', false) and not parts.edgeRim[1]:IsShown())
    assert(M:SetOption('healthBar', false)); GameTooltipStatusBar:Show(); assert(not GameTooltipStatusBar:IsShown(), 'Health Bar off')
    M:ResetToDefaults(); assert(M.db.backgroundOpacity == 92 and M.db.border and M.db.healthBar)

    SlashCmdList.MODEUI()
    local window = addon.configWindow
    assert(window.pages.tooltip == nil)
    addon:SelectConfigPage('tooltip')
    local page = window.pages.tooltip
    assert(page and page:IsShown() and page.tabContentTop and page.positionPills and page.combatToggles and window.moduleHeader.title:GetText() == 'Tooltip')
    window:Hide()
    M:SetOption('anchorPoint', 'TOP')

    addon:SetModuleEnabled('tooltip', false)
    assert(addon.ReloadManager.requests.tooltip, 'off asks for a reload')
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent); assert(Point(GameTooltip)[2] == UIParent, 'Blizzard places it again')
]==], "tooltip")

local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([==[
    local M = addon.Tooltip
    assert(not M.enabled and M.db.anchorPoint == 'TOP' and addon.Skin.parts[GameTooltip] == nil, 'settings persist; nothing skinned while off')
]==], "tooltip_restore")
print("tooltip: all checks passed")
