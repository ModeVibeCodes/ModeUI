-- Minimap: Blizzard's minimap (stubbed with Forever's frame tree and keys)
-- as a rounded rectangle: the holder, mask and hit rectangle, Blizzard's art
-- hidden, the round mask put back by Blizzard and set again, the border,
-- button tiles and their corners, the group-finder eye, zone, clock and
-- coordinates in all three layouts, the addon button box, corner pings, Zoom
-- Out After, opacity, Edit Mode, settings, the page, validation, reload and
-- persistence, and every mask file on disk. Simulated client; not WoW
-- rendering, mouse or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")

-- Every size, difference and corner choice has its mask.
do
    local missing = {}
    for size = 140, 280, 4 do
        for _, difference in ipairs({ 0, 8, 16 }) do
            for _, radius in ipairs({ 0, 4, 8, 12 }) do
                local path = string.format("%sModeUI/Media/Textures/Minimap/Mask-%d-%d-%d.tga", H.root, size, difference, radius)
                local file = io.open(path, "rb")
                if file then
                    local header = file:read(18); file:close()
                    assert(header:byte(3) == 10 and header:byte(13) + header:byte(14) * 256 == 256, "RLE 256x256: " .. path)
                else missing[#missing + 1] = path end
            end
        end
    end
    assert(#missing == 0, "missing masks: " .. table.concat(missing, ", "))
end

local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/skin_stubs.lua") .. [==[
    local methods = getmetatable(UIParent).__index
    function methods:GetSize() return self:GetWidth(), self:GetHeight() end
    function methods:GetTexture() return self.texture end
    function methods:GetTextureFileID() return self.fileID end
    function methods:SetHitRectInsets(...) self.hitInsets = { ... } end
    local enableWheel = methods.EnableMouseWheel
    function methods:EnableMouseWheel(on) self.wheel = on; return enableWheel(self, on) end
    -- Forever's minimap, trimmed to what ModeUI touches.
    MinimapCluster = CreateFrame('Frame', 'MinimapCluster', UIParent)
    MinimapCluster.MinimapContainer = CreateFrame('Frame', nil, MinimapCluster)
    Minimap = CreateFrame('Frame', 'Minimap', MinimapCluster.MinimapContainer)
    Minimap:SetSize(198, 198); Minimap:SetPoint('CENTER')
    function Minimap:SetMaskTexture(path) self.mask = path end
    function Minimap:GetZoom() return self.zoom or 0 end
    function Minimap:SetZoom(zoom) self.zoom = zoom; self.zoomWrites = (self.zoomWrites or 0) + 1 end
    function Minimap:PingLocation(x, y) self.ping = { x, y } end
    for _, name in ipairs({ 'SetArchBlobRingScalar', 'SetArchBlobRingAlpha', 'SetQuestBlobRingScalar', 'SetQuestBlobRingAlpha',
        'SetTaskBlobRingScalar', 'SetTaskBlobRingAlpha' }) do
        Minimap[name] = function(self, value) self.rings = self.rings or {}; self.rings[name] = value end
    end
    blizzardPings = 0
    Minimap:SetScript('OnMouseUp', function() blizzardPings = blizzardPings + 1 end)
    Minimap:SetScript('OnMouseWheel', function() end)
    Minimap.ZoomIn = CreateFrame('Button', nil, Minimap)
    Minimap.ZoomOut = CreateFrame('Button', nil, Minimap)
    Minimap.ZoomHitArea = CreateFrame('Frame', nil, Minimap)
    MinimapBackdrop = CreateFrame('Frame', 'MinimapBackdrop', Minimap)
    ExpansionLandingPageMinimapButton = CreateFrame('Button', 'ExpansionLandingPageMinimapButton', MinimapBackdrop)
    ExpansionLandingPageMinimapButton:SetSize(53, 53); ExpansionLandingPageMinimapButton:Hide()
    MinimapCluster.Tracking = CreateFrame('Frame', nil, MinimapCluster); MinimapCluster.Tracking:SetSize(17, 17)
    MinimapCluster.IndicatorFrame = CreateFrame('Frame', nil, MinimapCluster); MinimapCluster.IndicatorFrame:SetSize(32, 24)
    MinimapCluster.IndicatorFrame.MailFrame = CreateFrame('Frame', nil, MinimapCluster.IndicatorFrame)
    MinimapCluster.IndicatorFrame.MailFrame:Hide()
    MinimapCluster.ZoneTextButton = CreateFrame('Button', nil, MinimapCluster)
    GameTimeFrame = CreateFrame('Button', 'GameTimeFrame', MinimapCluster); GameTimeFrame:SetSize(23, 23)
    AddonCompartmentFrame = CreateFrame('Button', 'AddonCompartmentFrame', MinimapCluster); AddonCompartmentFrame:SetSize(23, 22)
    function MinimapCluster:UpdateMinimapConfig() Minimap:SetMaskTexture('ui-hud-minimap-frame-generic-mask') end
    QueueStatusButton = CreateFrame('Button', 'QueueStatusButton', UIParent); QueueStatusButton:SetSize(45, 45); QueueStatusButton:Hide()
    -- Another addon's LibDBIcon button and a map pin on the minimap.
    local icon = CreateFrame('Button', 'LibDBIcon10_Test', Minimap)
    icon:SetSize(31, 31); icon:SetScript('OnClick', function() end); icon.icon = icon:CreateTexture()
    roundBorder = icon:CreateTexture(); roundBorder.fileID = 136430
    local pin = CreateFrame('Button', 'HandyNotesPin1', Minimap)
    pin:SetSize(16, 16); pin:SetScript('OnClick', function() end)
    blizzardNames = { GameTimeFrame = true, AddonCompartmentFrame = true, ExpansionLandingPageMinimapButton = true }
    function issecurevariable(name) return blizzardNames[name] == true end
    function GetMinimapZoneText() return 'Northshire Valley' end
    pvp = 'friendly'
    C_PvP = { GetZonePVPInfo = function() return pvp end }
    C_Map = { GetBestMapForUnit = function() return 1429 end,
        GetPlayerMapPosition = function() return { GetXY = function() return 0.426, 0.651 end } end }
    function date(pattern) return pattern == '%H:%M' and '21:47' or '09:47 PM' end
    cursor = { 0, 0 }
    function GetCursorPosition() return cursor[1], cursor[2] end
    timers = {}
    C_Timer.NewTimer = function(delay, fn)
        local timer = { delay = delay, fn = fn }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, Kit = addon.Minimap, addon.Kit
    local function Point(frame) return frame.points and frame.points[#frame.points] end
    assert(M and addon.modules.minimap == M and not M.enabled, 'registered, off by default')
    assert(M.db.size == 200 and M.db.difference == 16 and M.db.corners == 'medium', 'the approved shape')
    assert(M.db.border == 'bold' and M.db.buttonBorder == 'thin' and M.db.textLayout == 'map', 'the approved borders and text')
    assert(Minimap:GetParent() == MinimapCluster.MinimapContainer and M.holder == nil, 'nothing moved while off')

    addon:SetModuleEnabled('minimap', true)
    -- Shape: the square Minimap on the map frame, cropped by the mask.
    assert(Minimap:GetParent() == M.map and ModeUIMinimapMap == M.map, 'on the map frame')
    assert(Minimap:GetWidth() == 200 and Minimap:GetHeight() == 200, 'the game draws it square')
    assert(M.map:GetWidth() == 200 and M.map:GetHeight() == 184, '16 px wider than tall')
    local p = Point(Minimap)
    assert(p[1] == 'TOPLEFT' and p[2] == M.map and p[5] == 8, 'half the difference above the map frame')
    assert(Minimap.mask:find('Minimap\\Mask%-200%-16%-8$'), 'the 200 x 184 mask with 8 px corners')
    assert(Minimap.hitInsets[3] == 8 and Minimap.hitInsets[4] == 8 and Minimap.hitInsets[1] == 0, 'clicks only on the visible map')
    assert(Minimap.rings.SetQuestBlobRingScalar == 0 and Minimap.rings.SetArchBlobRingAlpha == 0, 'no round quest rings')
    -- Blizzard's art waits under a hidden frame; the cluster is hidden.
    assert(not MinimapCluster:IsShown(), 'the cluster (zone text, day and night ring, coordinates) hidden')
    MinimapCluster:Show(); assert(not MinimapCluster:IsShown(), 'and stays hidden')
    assert(not MinimapBackdrop:IsVisible() and not Minimap.ZoomIn:IsVisible() and not Minimap.ZoomHitArea:IsVisible(), 'round art and zoom buttons')
    -- Blizzard puts its round mask back; ModeUI sets its own again.
    MinimapCluster:UpdateMinimapConfig()
    assert(Minimap.mask:find('Mask%-200%-16%-8$'), 'mask set again after Blizzard\'s')
    -- Blizzard re-anchors the minimap; it comes back.
    Minimap:ClearAllPoints(); Minimap:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    assert(Point(Minimap)[2] == M.map and Minimap:GetParent() == M.map, 'kept on the map frame')
    Minimap:SetParent(UIParent); assert(Minimap:GetParent() == M.map, 'reparenting is undone')
    -- The border: Bold (3 px) in the Mode rim, above the map.
    assert(M.border.strips.TOP.height == 3 and M.border.strips.TOP.vertexColor[1] == Kit.BORDER_COLOR[1], 'Bold Mode rim')
    assert(M.border.edge:GetFrameLevel() > Minimap:GetFrameLevel(), 'border above the map')
    assert(M.border.corners.TOPLEFT.cap:IsShown(), 'rounded corners')

    -- Tiles: tracking top left, calendar top right, mail only with mail.
    local tiles = M.tiles
    assert(MinimapCluster.Tracking:GetParent() == tiles.tracking and GameTimeFrame:GetParent() == tiles.calendar, 'Blizzard\'s buttons on tiles')
    assert(tiles.tracking:IsShown() and Point(tiles.tracking)[1] == 'TOPLEFT' and tiles.calendar:IsShown() and Point(tiles.calendar)[1] == 'TOPRIGHT')
    assert(not tiles.mail:IsShown(), 'no mail, no tile')
    MinimapCluster.IndicatorFrame.MailFrame:Show(); assert(tiles.mail:IsShown() and Point(tiles.mail)[1] == 'BOTTOMRIGHT', 'new mail')
    assert(not tiles.expansion:IsShown() and ExpansionLandingPageMinimapButton:GetParent() == tiles.expansion, 'expansion button off by default')
    assert(tiles.tracking.border.strips.TOP.height == 1, 'Thin borders on tiles')
    assert(M:SetButton('mail', 'corner', 'TOPLEFT') and Point(tiles.mail)[1] == 'TOPLEFT' and Point(tiles.mail)[5] == -(5 + 20 + 4), 'stacked under tracking')
    assert(not M:SetButton('mail', 'corner', 'MIDDLE') and M:SetButton('mail', 'corner', 'BOTTOMRIGHT'))
    assert(M:SetButton('calendar', 'shown', false) and not tiles.calendar:IsShown())
    M:SetButton('calendar', 'shown', true)
    -- The eye: a tile of its own, bottom left of the map, Blizzard's button on it.
    assert(QueueStatusButton:GetParent() == M.queueTile and not M.queueTile:IsShown(), 'no queue, no eye')
    QueueStatusButton:Show(); assert(M.queueTile:IsShown(), 'queued: the eye shows')
    QueueStatusButton:ClearAllPoints(); QueueStatusButton:SetPoint('CENTER', Minimap, 'CENTER', -68, -68)
    assert(Point(QueueStatusButton)[2] == M.queueTile, 'Blizzard\'s default spot no longer applies')
    local queue = addon.db.positions.modeMinimapQueue
    assert(queue.target == 'modeMinimapMap' and queue.point == 'BOTTOMLEFT', 'bottom left of the map, in Edit Mode')

    -- Text: clock above zone at the bottom, coordinates at the top.
    local t = M.texts
    assert(t.zone.text == 'Northshire Valley' and t.zone.color[1] == Kit.palette.green[1], 'friendly zone in Mode green')
    assert(t.clock.text:match('^%d%d:%d%d$'), '24 hour clock')
    assert(t.coords.text == '42.6, 65.1', 'coordinates')
    assert(Point(t.zone)[1] == 'BOTTOM' and Point(t.clock)[5] > Point(t.zone)[5] and Point(t.coords)[1] == 'TOP', 'clock above zone')
    pvp = 'hostile'; FireEvent('ZONE_CHANGED_NEW_AREA'); assert(t.zone.color[1] == Kit.palette.hostile[1], 'hostile zone')
    assert(M:SetOption('zoneColor', 'white') and t.zone.color[1] == M.WHITE[1])
    assert(M:SetOption('clockFormat', '12') and t.clock.text:match('[AP]M$'))
    assert(M:SetOption('textLayout', 'bar') and M.bar:IsShown() and not t.zone:IsShown(), 'Bar Below')
    assert(M.mover:GetHeight() == 184 + 1 + 22 and M.barTexts.zone:IsShown(), 'the bar 1 px under the map')
    assert(M:SetOption('textLayout', 'hover') and not M.bar:IsShown())
    M.holder.mouseOver = false; Advance(0.2); assert(t.zone.alpha == 0, 'hidden until hovered')
    M.holder.mouseOver = true; Advance(0.2); assert(t.zone.alpha == 1, 'shown while hovered')
    M:SetOption('textLayout', 'map'); M:SetOption('zoneColor', 'pvp'); M:SetOption('clockFormat', '24')
    assert(M:SetOption('coords', false) and not t.coords:IsShown())
    M:SetOption('coords', true)

    -- Addon buttons: LibDBIcon's in the box, the pin left alone.
    assert(LibDBIcon10_Test:GetParent() == M.cells[LibDBIcon10_Test] and roundBorder.alpha == 0, 'collected, round art faded')
    assert(M.cells[HandyNotesPin1] == nil and HandyNotesPin1:GetParent() == Minimap, 'map pins stay on the map')
    assert(AddonCompartmentFrame:GetParent() == M.cells[AddonCompartmentFrame], 'Blizzard\'s addon menu (ModeUI\'s entry) first')
    assert(M.container:GetWidth() == 200 and M.container:IsShown(), 'matches the minimap\'s width')
    local buttons = addon.db.positions.modeMinimapButtons
    assert(buttons.target == 'modeMinimap' and buttons.placement == 'below', 'under the map, in Edit Mode')
    assert(M:SetOption('addonButtons', 'mouseover'))
    M.container.mouseOver = false; Advance(0.2); assert(M.container.alpha == 0, 'Mouseover: hidden')
    M.container.mouseOver = true; Advance(0.2); assert(M.container.alpha == 1, 'shown while hovered')
    assert(M:SetOption('addonButtons', 'hidden') and not M.container:IsShown())
    assert(M:SetOption('matchWidth', false) and M:SetOption('addonButtons', 'always') and M.container:GetWidth() < 200, 'just as wide as its buttons')
    M:SetOption('matchWidth', true)

    -- Pings in the corners, outside Blizzard's circle.
    local cx, cy = Minimap:GetCenter()
    cursor = { cx + 95, cy + 85 }; Minimap.scripts.OnMouseUp(Minimap, 'LeftButton')
    assert(Minimap.ping and Minimap.ping[1] == 95 and blizzardPings == 1, 'a corner pings')
    Minimap.ping = nil; cursor = { cx + 10, cy + 10 }; Minimap.scripts.OnMouseUp(Minimap, 'LeftButton')
    assert(Minimap.ping == nil, 'inside the circle Blizzard pings')
    -- Zoom Out After 10 s.
    Minimap.zoom = 3; Minimap.scripts.OnMouseWheel(Minimap, 1)
    local timer = timers[#timers]; assert(timer.delay == 10); timer.fn(); assert(Minimap.zoom == 0, 'zoomed back out')
    assert(M:SetOption('wheelZoom', false) and Minimap.wheel == false)
    M:SetOption('wheelZoom', true)
    -- Opacity, and Combat Opacity while fighting.
    assert(M:SetOption('opacity', 60) and M.holder.alpha == 0.6)
    M:SetOption('combatOpacity', 40); M:OnCombatStateChanged(true); assert(M.holder.alpha == 0.4, 'combat opacity')
    M:OnCombatStateChanged(false); M:SetOption('opacity', 100)

    -- Shape settings: masks follow; bad values are refused.
    assert(M:SetOption('size', 220) and Minimap.mask:find('Mask%-220%-16%-8$') and M.map:GetHeight() == 204)
    assert(M:SetOption('difference', 0) and Minimap.mask:find('Mask%-220%-0%-8$') and Minimap.hitInsets[3] == 0)
    assert(M:SetOption('corners', 'square') and Minimap.mask:find('Mask%-220%-0%-0$') and not M.border.corners.TOPLEFT.cap:IsShown())
    assert(not M:SetOption('size', 222) and not M:SetOption('size', 300) and not M:SetOption('difference', 4) and not M:SetOption('corners', 'round'))
    assert(M:SetOption('border', 'thin') and M.border.strips.TOP.height == 1)
    assert(M:SetOption('borderColor', 'accent') and M.border.strips.TOP.vertexColor[3] == Kit.palette.accent[3])
    M:SetOption('size', 200); M:SetOption('difference', 16); M:SetOption('corners', 'medium'); M:SetOption('border', 'bold')
    M:SetOption('borderColor', 'rim')

    -- Edit Mode: three stand-ins; the eye shows to be moved.
    QueueStatusButton:Hide()
    addon:SetEditMode(true)
    assert(M.mover:IsShown() and M.queueMover:IsShown() and M.buttonsMover:IsShown() and M.queueTile:IsShown())
    addon:SetEditMode(false)
    assert(not M.mover:IsShown() and not M.queueTile:IsShown())

    -- The page: four tabs, built when opened.
    SlashCmdList.MODEUI()
    local window = addon.configWindow
    assert(window.pages.minimap == nil)
    addon:SelectConfigPage('minimap')
    local page = window.pages.minimap
    assert(page and page:IsShown() and window.moduleHeader.title:GetText() == 'Minimap')
    local tabs = {}
    for _, section in ipairs(page.sections) do tabs[#tabs + 1] = section.title end
    assert(table.concat(tabs, ',') == 'Shape,Text,Buttons,Behavior', 'four tabs')
    assert(page.sizeSlider and #page.differenceButtons == 3 and #page.cornerButtons == 4 and #page.borderButtons == 4)
    assert(#page.swatches == 6 and page.textToggles and page.buttonRows.mail and page.matchWidthToggle and page.zoomResetButtons)
    page.differenceButtons[2]:GetScript('OnClick')(); assert(M.db.difference == 8 and Minimap.mask:find('Mask%-200%-8%-8$'))
    page.buttonRows.mail.picker[1]:GetScript('OnClick')(); assert(M.db.buttons.mail.corner == 'TOPLEFT')
    page.swatches[2]:GetScript('OnClick')(); assert(M.db.borderColor == 'onyx')
    window:Hide()

    addon:SetModuleEnabled('minimap', false)
    assert(addon.ReloadManager.requests.minimap, 'off asks for a reload')

    -- Validation never resets: bad data errors.
    assert(not pcall(M.Initialize, { version = 1, corners = 'round' }))
    assert(not pcall(M.Initialize, { version = 1, buttons = { mail = { shown = true, corner = 'LEFT' } } }))
    assert(not pcall(M.Initialize, { version = 2 }))
]==], "minimap")

local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([==[
    local M = addon.Minimap
    assert(not M.enabled and M.db.difference == 8 and M.db.buttons.mail.corner == 'TOPLEFT' and M.db.borderColor == 'onyx', 'settings persist')
    assert(Minimap:GetParent() == MinimapCluster.MinimapContainer, 'nothing moved while off')
]==], "minimap_restore")
print("minimap: all checks passed")
