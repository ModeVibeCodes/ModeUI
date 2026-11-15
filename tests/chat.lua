-- Chat: Blizzard's chat windows (stubbed with Forever's keys and names)
-- skinned in the Mode look: hidden art, the panel and its box, the edit box,
-- glass tabs and their pinned alpha, the button compartment, the tab fade,
-- the idle fade, whispers, settings, validation, reload and persistence.
-- Simulated client; not WoW rendering, mouse or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/skin_stubs.lua") .. [==[
    local methods = getmetatable(UIParent).__index
    CHAT_FRAME_TEXTURES = { 'Background', 'TopLeftTexture', 'BottomLeftTexture', 'TopRightTexture', 'BottomRightTexture',
        'LeftTexture', 'RightTexture', 'BottomTexture', 'TopTexture', 'ButtonFrameBackground' }
    Constants = { ChatFrameConstants = { MaxChatWindows = 2 } }
    GENERAL_CHAT_DOCK = CreateFrame('Frame', 'GeneralDockManager', UIParent)
    GENERAL_CHAT_DOCK.overflowButton = CreateFrame('Button', nil, GENERAL_CHAT_DOCK)
    GENERAL_CHAT_DOCK.overflowButton.list = CreateFrame('Frame', nil, GENERAL_CHAT_DOCK.overflowButton)
    GENERAL_CHAT_DOCK.overflowButton.list:Hide()
    alerting = {}
    ChatFrameUtil = { IsTabAlerting = function(tab) return alerting[tab] == true end }
    function FCFDock_GetSelectedWindow(dock) return dock.selected end
    -- Blizzard's own fades and calls, so the hooks have something to follow.
    function FCF_OpenTemporaryWindow() end
    function FloatingChatFrame_UpdateBackgroundAnchors(frame)
        frame.Background:ClearAllPoints(); frame.Background:SetPoint('TOPLEFT', frame, 'TOPLEFT', -2, 3)
    end
    function FCFTab_UpdateColors(tab, selected) tab.Text:SetTextColor(1, 0.82, 0) end
    function FCFDock_SelectWindow(dock, frame) dock.selected = frame end
    function FCF_SetChatWindowFontSize(_, frame, size) local path, _, flags = frame:GetFont(); frame:SetFont(path, size, flags) end
    -- Blizzard sizing a tab to its text (SharedUIPanelTemplates).
    function PanelTemplates_TabResize(tab, padding)
        tab.Text:SetWidth(0)
        local width = tab.Text:GetStringWidth()
        tab.Text:SetWidth(width); tab:SetWidth(width + 20 + (padding or 0))
    end
    function FCF_UpdateScrollbarAnchors(frame) frame.ScrollBar:ClearAllPoints(); frame.ScrollBar:SetPoint('TOPLEFT', frame, 'TOPRIGHT', 0, 0) end
    for index = 1, 2 do
        local name = 'ChatFrame' .. index
        local frame = CreateFrame('Frame', name, UIParent)
        frame:SetFont('Fonts/ARIALN.TTF', 14, '')
        frame:SetSize(430, 120)
        for _, suffix in ipairs(CHAT_FRAME_TEXTURES) do
            local texture = frame:CreateTexture(nil, 'BACKGROUND'); _G[name .. suffix] = texture
        end
        frame.Background = _G[name .. 'Background']
        frame.isDocked = true
        frame.atBottom = true
        function frame:AtBottom() return self.atBottom end
        -- MinimalScrollBar: track and thumb pieces, two steppers.
        local bar = CreateFrame('Frame', nil, frame)
        bar.Track = CreateFrame('Frame', nil, bar)
        bar.Track.Begin, bar.Track.Middle, bar.Track.End = bar.Track:CreateTexture(), bar.Track:CreateTexture(), bar.Track:CreateTexture()
        bar.Track.Thumb = CreateFrame('Frame', nil, bar.Track)
        bar.Track.Thumb.Begin, bar.Track.Thumb.Middle = bar.Track.Thumb:CreateTexture(), bar.Track.Thumb:CreateTexture()
        bar.Back, bar.Forward = CreateFrame('Button', nil, bar), CreateFrame('Button', nil, bar)
        bar.Back.Texture, bar.Forward.Texture = bar.Back:CreateTexture(), bar.Forward:CreateTexture()
        frame.ScrollBar = bar
        frame.isStaticDocked = true
        frame.ScrollToBottomButton = CreateFrame('Button', nil, frame)
        local scroll = frame.ScrollToBottomButton
        scroll.normal = scroll:CreateTexture(nil, 'ARTWORK')
        function scroll:GetNormalTexture() return self.normal end
        scroll.Flash = scroll:CreateTexture(nil, 'OVERLAY')
        local edit = CreateFrame('EditBox', name .. 'EditBox', frame)
        frame.editBox = edit
        _G[name .. 'EditBoxLeft'] = edit:CreateTexture(nil, 'BACKGROUND')
        edit.focusLeft, edit.focusMid, edit.focusRight = edit:CreateTexture(), edit:CreateTexture(), edit:CreateTexture()
        edit.header = edit:CreateFontString(nil, nil, 'ChatFontNormal')
        local tab = CreateFrame('Button', name .. 'Tab', GENERAL_CHAT_DOCK)
        tab:SetID(index)
        for _, key in ipairs({ 'Left', 'Middle', 'Right', 'ActiveLeft', 'ActiveMiddle', 'ActiveRight',
            'HighlightLeft', 'HighlightMiddle', 'HighlightRight' }) do tab[key] = tab:CreateTexture(nil, 'BACKGROUND') end
        tab.Text = tab:CreateFontString(nil, nil, 'GameFontNormalSmall'); tab.Text:SetText(index == 1 and 'General' or 'Combat Log')
        tab.glow = tab:CreateTexture(nil, 'BACKGROUND')
    end
    GENERAL_CHAT_DOCK.selected = ChatFrame1
    CHAT_FRAMES = { 'ChatFrame1', 'ChatFrame2' }
    ChatFrame1Tab:SetAlpha(0.4)
    local buttonFrame = CreateFrame('Frame', 'ChatFrame1ButtonFrame', ChatFrame1)
    for _, name in ipairs({ 'ChatFrameMenuButton', 'ChatFrameChannelButton' }) do
        local button = CreateFrame('Button', name, buttonFrame)
        button.normal = button:CreateTexture(nil, 'ARTWORK')
        function button:GetNormalTexture() return self.normal end
    end
    function ChatFrameMenuButton:IsMenuOpen() return menuOpen == true end
    -- Voice chat hides its deafen button until a voice channel is active.
    CreateFrame('Button', 'ChatFrameToggleVoiceDeafenButton', UIParent):Hide()
    ChatAlertFrame = CreateFrame('Frame', 'ChatAlertFrame', UIParent)
    -- The alert column places its alerts (Friends among them) again on updates.
    function ChatAlertFrame:UpdateAnchors() QuickJoinToastButton:ClearAllPoints(); QuickJoinToastButton:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', 0, 0) end
    -- The friends button (QuickJoinToastButton): its own art, the online count.
    local friends = CreateFrame('Button', 'QuickJoinToastButton', UIParent)
    for _, key in ipairs({ 'FriendsButton', 'QueueButton', 'FlashingLayer' }) do friends[key] = friends:CreateTexture(nil, 'BACKGROUND') end
    friends.FriendCount = friends:CreateFontString(nil, nil, 'GameFontNormalSmall'); friends.FriendCount:SetText('5')
    friends.QueueCount = friends:CreateFontString(nil, nil, 'GameFontNormalSmall')
    C_VoiceChat = { GetActiveChannelID = function() return voiceChannel end }
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, Skin, Kit, C = addon.Chat, addon.Skin, addon.Kit, addon.Skin.colors
    assert(M and addon.modules.chat == M and not M.enabled, 'registered, off by default')
    assert(M.db.fontMedia == 'Expressway' and M.db.idleOpacity == 40 and M.db.buttons == 'compartment')
    assert(M.db.backgroundColor[1] == Kit.onyx.health[1] and M.db.backgroundOpacity == 60, 'health color, 60%')
    assert(M.db.border == nil and M.db.borderSize == nil and M.db.borderColor == nil, 'the border has no settings')
    assert(M.db.tabHeight == 24 and M.db.editPosition == 'bottom' and M.db.scrollBar)
    assert(ChatFrame1Background:IsShown() and Skin.parts[ChatFrame1] == nil, 'nothing changes while off')

    addon:SetModuleEnabled('chat', true)
    -- Window: Blizzard's art hidden (and kept hidden), the box around the text.
    assert(not ChatFrame1Background:IsShown() and not ChatFrame2TopTexture:IsShown())
    ChatFrame1TopTexture:Show(); assert(not ChatFrame1TopTexture:IsShown(), 'Blizzard showing its art is undone')
    local panel = Skin.parts[ChatFrame1]
    local fill, border = panel and panel.fill, panel and panel.border
    assert(fill and fill.middle.vertexColor[4] == 0.6 and fill.top.vertexColor[1] == Kit.onyx.health[1], 'the health color fill')
    -- ModeUI's standard border, as on the damage meter windows: the 2px rim
    -- with round corners as deep as a bar the edit band's height rounds (24 + 2 * 2).
    assert(border.edge:IsShown() and border.strips.TOP.vertexColor[1] == Kit.BORDER_COLOR[1] and border.strips.TOP.height == 2, 'the standard rim, 2px')
    assert(border.radius == Kit.CapDepth(28, 1) and border.radius == 7 and border.corners.TOPLEFT.cap.width == 7, 'round corners')
    assert(Point(border.strips.TOP)[2] == ChatFrame1Background and Point(border.strips.TOP)[4] == 7, 'border on the box')
    assert(border.edge:GetParent() == ChatFrame1 and border.edge:GetFrameLevel() == ChatFrame1:GetFrameLevel() + 2 and not border.edge.mouse,
        'on its own frame above the window, which the idle fade dims with it')
    -- Content takes only the corners it reaches: a texture holds at most 3
    -- masks (the stubs error on a 4th, as the client does).
    local function Masks(region, ...)
        local n = 0
        for _ in pairs(region.capMasks or {}) do n = n + 1 end
        if n ~= select('#', ...) then return false end
        for i = 1, select('#', ...) do if not region.capMasks[select(i, ...)] then return false end end
        return true
    end
    local m = border.masks
    assert(Masks(fill.top, m.TOPLEFT, m.TOPRIGHT) and Masks(fill.middle) and Masks(fill.bottom, m.BOTTOMLEFT, m.BOTTOMRIGHT), 'background in three bands')
    assert(Point(fill.top)[2] == ChatFrame1Background and Point(fill.top)[4] == 1 and fill.top.height == 6, 'background 1px under the rim')
    local p = Point(ChatFrame1Background)
    -- Text Inset 6 + the 2px border; the edit box (24) inside at the bottom;
    -- the scroll bar's 10px gutter at the right.
    assert(p[1] == 'TOPLEFT' and p[2] == ChatFrame1 and p[4] == -8 and p[5] == 8, 'box around the messages')
    local q = Point(ChatFrame1Background, 2)
    assert(q[1] == 'BOTTOMRIGHT' and q[4] == 18 and q[5] == -32, 'room for the edit box and the scroll bar')
    FloatingChatFrame_UpdateBackgroundAnchors(ChatFrame1)
    p = Point(ChatFrame1Background); assert(p[4] == -8, 'Blizzard re-anchoring the box is followed')
    -- Edit box: joined to the window inside its border, on a darker band.
    local band = Point(panel.band)
    assert(panel.band:IsShown() and band[1] == 'BOTTOMLEFT' and band[2] == ChatFrame1Background and band[4] == 2 and band[5] == 2)
    assert(panel.band:GetHeight() == 24 and Point(ChatFrame1EditBox)[2] == panel.band, 'edit box on the band')
    assert(Masks(panel.band, m.BOTTOMLEFT, m.BOTTOMRIGHT) and Masks(panel.bandLine), 'the band rounds with the bottom corners')
    assert(ChatFrame1EditBoxLeft.alpha == 0 and ChatFrame1EditBox.focusMid.alpha == 0, 'edit box art faded')
    ChatFrame1EditBox:SetFocus(); ChatFrame1EditBox.scripts.OnEditFocusGained(ChatFrame1EditBox)
    assert(panel.bandLine.vertexColor[2] == 240 / 255, 'the divider turns cyan while typing')
    ChatFrame1EditBox:ClearFocus()
    assert(panel.bandLine.vertexColor[2] ~= 240 / 255, 'field rim again')
    -- Font: the chat face, each window's own size kept.
    local path, size = ChatFrame1:GetFont()
    assert(path == Kit.FontPath(M.db, 'chat') and size == 14, 'chat face, window size kept')
    -- Scroll bar: skinned and in the gutter; Scroll to Bottom's flash hidden.
    local bar = ChatFrame1.ScrollBar
    assert(bar.Track.Middle.alpha == 0 and bar.Back.Texture.alpha == 0 and Skin.parts[bar].thumb, 'slim Mode track and thumb')
    assert(Point(bar)[1] == 'TOPRIGHT' and Point(bar)[2] == ChatFrame1Background and Point(bar)[4] == -3 and Point(bar)[5] == -7, 'below the round corner')
    FCF_UpdateScrollbarAnchors(ChatFrame1); assert(Point(bar)[2] == ChatFrame1Background, 'Blizzard re-anchoring it is followed')
    local flash = ChatFrame1.ScrollToBottomButton.Flash
    flash:Show(); assert(not flash:IsShown(), 'no flashing arrow')

    -- Tabs: art faded, glass panes on the border, the selected one raised.
    assert(ChatFrame1Tab.Left.alpha == 0 and ChatFrame1Tab.ActiveMiddle.alpha == 0 and ChatFrame1Tab.HighlightRight.alpha == 0)
    local t1, t2 = Skin.parts[ChatFrame1Tab], Skin.parts[ChatFrame2Tab]
    assert(t1.glass.texture:find('Glass') and t1.glass:GetHeight() == 24 and t2.glass:GetHeight() == 21, 'selected full, others tucked 3px')
    assert(t1.glint.texture:find('Sheen') and t1.glint.blendMode == 'ADD' and t1.glint:IsShown(), 'a diagonal glint')
    assert(t1.bar:IsShown() and not t2.bar:IsShown(), 'cyan bar on the selected tab only')
    assert(Point(ChatFrame1Tab.Text)[2] == t1.glass, 'text on the pane\'s middle')
    -- Tab width: sized to the text in the Mode face (7 letters at 13).
    assert(ChatFrame1Tab:GetWidth() == math.ceil(7 * 13 * 0.6) + 20, 'General fits')
    ChatFrame1Tab.Text:SetFont('Fonts/FRIZQT__.TTF', 9, ''); PanelTemplates_TabResize(ChatFrame1Tab, 0)
    ChatFrame1Tab.Text:SetFont(Kit.FontPath(M.db, 'chat'), 13, ''); PanelTemplates_TabResize(ChatFrame1Tab, 0)
    assert(ChatFrame1Tab:GetWidth() == math.ceil(7 * 13 * 0.6) + 20, 'Blizzard\'s resize is followed')
    ChatFrame2.chatType = 'WHISPER'
    assert(not M:SizeTab(ChatFrame2Tab), 'whisper tabs are never measured'); ChatFrame2.chatType = nil
    FCFTab_UpdateColors(ChatFrame2Tab, false)
    assert(ChatFrame2Tab.Text.color[1] == 196 / 255, 'Mode label gray after Blizzard colors the text')
    FCFDock_SelectWindow(GENERAL_CHAT_DOCK, ChatFrame2)
    FCFTab_UpdateColors(ChatFrame2Tab, true); FCFTab_UpdateColors(ChatFrame1Tab, false)
    assert(t2.bar:IsShown() and ChatFrame2Tab.Text.color[1] == 242 / 255 and t2.glass:GetHeight() == 24 and t1.glass:GetHeight() == 21,
        'picked tab: raised, white text and the bar')
    FCFDock_SelectWindow(GENERAL_CHAT_DOCK, ChatFrame1); FCFTab_UpdateColors(ChatFrame1Tab, true); FCFTab_UpdateColors(ChatFrame2Tab, false)

    -- Compartment: Blizzard's buttons moved in, glyphs drawn, hidden voice skipped.
    local box = ModeUIChatButtons
    assert(box and ChatFrameMenuButton:GetParent() == box and ChatFrameChannelButton:GetParent() == box)
    assert(ChatFrameMenuButton.normal.alpha == 0 and Skin.parts[ChatFrameMenuButton].glyph, 'glyph instead of Blizzard art')
    assert(box:GetWidth() == 1 + 34 + 1 + 22 + 1 + 22 + 1 and box:GetHeight() == 20, 'Friends, Channels and the menu, dividers, a rim')
    -- Friends: in the compartment, first, its art hidden for good, a glyph and its count.
    local friends = QuickJoinToastButton
    assert(friends:GetParent() == box and Point(friends)[4] == 1, 'Friends grouped with the other buttons, first')
    assert(not friends.FriendsButton:IsShown() and Skin.parts[friends].glyph.texture:find('Friends'), 'a Mode glyph instead of its art')
    friends.FriendsButton:Show(); assert(not friends.FriendsButton:IsShown(), 'its toast animations can\'t bring the art back')
    assert(Point(friends.FriendCount)[1] == 'RIGHT' and friends.FriendCount.color[1] == C.label[1], 'the online count beside the glyph')
    ChatAlertFrame:UpdateAnchors()
    assert(Point(friends)[2] == box, 'put back when Blizzard\'s alert column places it again')
    ChatFrameToggleVoiceDeafenButton:Show()
    assert(box:GetWidth() == 1 + 34 + 1 + 22 + 1 + 22 + 1 + 22 + 1, 'voice button joins the row when shown')
    ChatFrameToggleVoiceDeafenButton:Hide()
    assert(Point(ChatAlertFrame)[2] == box, 'Social and Text to Speech stack above the compartment')

    -- Tab fade: Blizzard's SetAlpha is answered with ModeUI's value.
    Advance(0.1)
    ChatFrame1Tab:SetAlpha(0.4)
    assert(ChatFrame1Tab.alpha == 1 and math.abs(ChatFrame2Tab.alpha - 0.55) < 1e-6, 'not idle: selected full, others 55%')
    assert(bar.alpha == 0, 'the scroll bar waits for the mouse')
    ChatFrame1.mouseOver = true
    for _ = 1, 10 do Advance(0.1) end
    assert(bar.alpha == 1 and box.alpha == 1, 'mouse over: the scroll bar shows')
    alerting[ChatFrame2Tab] = true; ChatFrame2Tab:SetAlpha(0.2)
    assert(ChatFrame2Tab.alpha == 1, 'a flashing whisper tab shows'); alerting[ChatFrame2Tab] = nil
    ChatFrame1.mouseOver = false

    -- Idle: 8 seconds without use, then the window to 40% and tabs to Tabs When Idle.
    for _ = 1, 30 do Advance(0.1) end
    assert(ChatFrame1.alpha == 1 and ChatFrame1Tab.alpha == 1, 'still within Idle Delay')
    for _ = 1, 80 do Advance(0.1) end
    assert(math.abs(ChatFrame1.alpha - 0.4) < 1e-6 and ChatFrame1Tab.alpha == 0 and box.alpha == 0, 'idle: 40%, tabs hidden')
    assert(M:SetOption('awayTabOpacity', 100))
    for _ = 1, 3 do Advance(0.1) end
    assert(ChatFrame1Tab.alpha == 1 and math.abs(ChatFrame2Tab.alpha - 0.55) < 1e-6 and box.alpha == 1, 'Tabs When Idle 100: always shown')
    M:SetOption('awayTabOpacity', 0)
    FireEvent('CHAT_MSG_WHISPER')
    for _ = 1, 3 do Advance(0.1) end
    assert(ChatFrame1.alpha == 1 and ChatFrame1Tab.alpha == 1, 'a whisper wakes the chat')
    for _ = 1, 100 do Advance(0.1) end
    menuOpen = true; for _ = 1, 3 do Advance(0.1) end
    assert(ChatFrame1.alpha == 1, 'the chat menu open counts as use'); menuOpen = false
    ChatFrame1EditBox:SetFocus(); for _ = 1, 100 do Advance(0.1) end
    assert(ChatFrame1.alpha == 1, 'typing keeps it up'); ChatFrame1EditBox:ClearFocus()
    -- Scroll to Bottom shows while scrolled up.
    ChatFrame1.atBottom = false; Advance(0.1)
    assert(ChatFrame1.ScrollToBottomButton.alpha == 1)
    ChatFrame1.atBottom = true; Advance(0.1)
    assert(ChatFrame1.ScrollToBottomButton.alpha == 0)

    -- Settings: checked on a copy; live repaint.
    assert(not M:SetOption('idleOpacity', 140) and not M:SetOption('buttons', 'left') and not M:SetOption('nope', 1))
    assert(not M:SetOption('editPosition', 'left') and not M:SetOption('tabHeight', 60) and not M:SetOption('borderSize', 0))
    assert(M:SetOption('backgroundOpacity', 50) and panel.fill.middle.vertexColor[4] == 0.5 and panel.fill.bottom.vertexColor[4] == 0.5)
    assert(not M:SetOption('border', false) and not M:SetOption('borderColor', { 1, 0, 0 }) and border.edge:IsShown(), 'the border is locked')
    assert(M:SetOption('editPosition', 'top') and Point(ChatFrame1Background)[5] == 8 + 24 and Point(panel.band)[1] == 'TOPLEFT', 'edit box at the top')
    assert(Masks(panel.band, m.TOPLEFT, m.TOPRIGHT) and Masks(fill.top, m.TOPLEFT, m.TOPRIGHT), 'the band rounds with the top corners')
    assert(Point(bar)[5] == -(2 + 24 + 4), 'the scroll bar under the band')
    assert(M:SetOption('editPosition', 'below') and not panel.band:IsShown(), 'Below: its own field')
    local e = Point(ChatFrame1EditBox)
    local field = Skin.parts[ChatFrame1EditBox]
    assert(e[1] == 'TOPLEFT' and e[2] == ChatFrame1Background and e[5] == -4 and field.border.edge:IsShown())
    -- The field is a bar: the standard bar border, rounded ends, the field rounded under the rim.
    assert(field.border.ring.top.vertexColor[1] == Kit.BORDER_COLOR[1] and field.border.depth == Kit.CapDepth(24, 1), 'a bar border')
    assert(Masks(field.fill, field.border.masks.LEFT, field.border.masks.RIGHT), 'the field rounds with it')
    ChatFrame1EditBox:SetFocus(); ChatFrame1EditBox.scripts.OnEditFocusGained(ChatFrame1EditBox)
    assert(field.border.ring.top.vertexColor[2] == 240 / 255, 'cyan while typing')
    ChatFrame1EditBox:ClearFocus(); ChatFrame1EditBox.scripts.OnEditFocusLost(ChatFrame1EditBox)
    assert(field.border.ring.top.vertexColor[1] == Kit.BORDER_COLOR[1], 'the standard rim again')
    local s = Point(ChatFrame1.ScrollToBottomButton)
    assert(s[4] == -4 and s[5] == 5, 'Scroll to Bottom clear of the round corner')
    assert(M:SetOption('editHeight', 18) and border.radius == Kit.CapDepth(22, 1), 'corners follow Edit Box Height')
    M:SetOption('editHeight', 24)
    M:SetOption('editPosition', 'bottom')
    assert(not field.border.edge:IsShown() and Masks(panel.band, m.BOTTOMLEFT, m.BOTTOMRIGHT), 'inside again: no field border')
    assert(M:SetOption('tabHeight', 28)); assert(t1.glass:GetHeight() == 28, 'h1 ' .. tostring(t1.glass:GetHeight()))
    assert(M:SetOption('tuckDepth', 0)); assert(t2.glass:GetHeight() == 28, 'h2 ' .. tostring(t2.glass:GetHeight()))
    assert(M:SetOption('buttons', 'hidden') and not box:IsShown())
    assert(M:SetOption('buttons', 'compartment') and box:IsShown())
    assert(M:SetOption('glassTabs', false) and t1.glass.texture == Kit.FLAT and not t1.glint:IsShown() and t1.sheen == nil and t1.line == nil)
    assert(M:SetOption('scrollBar', false)); bar:Show(); assert(not bar:IsShown() and bar.alpha == 0, 'Scroll Bar off')
    assert(Point(ChatFrame1Background, 2)[4] == 8, 'no gutter without the scroll bar')
    assert(M:SetOption('scrollBar', true)); bar:Show(); assert(bar:IsShown(), 'Scroll Bar on')
    assert(M:SetOption('idleFade', false)); for _ = 1, 120 do Advance(0.1) end
    assert(ChatFrame1.alpha == 1, 'no idle fade when off')
    M:ResetToDefaults(); assert(M.db.glassTabs and M.db.idleFade and M.db.backgroundOpacity == 60 and M.db.tuckDepth == 3)

    -- The page exists only once the window opens it; tabs pinned above the cards.
    SlashCmdList.MODEUI()
    local window = addon.configWindow
    assert(window.pages.chat == nil)
    addon:SelectConfigPage('chat')
    local page = window.pages.chat
    assert(page and page:IsShown() and page.idleOpacitySlider and page.tabStylePills and page.editPills and page.tuckSlider)
    assert(page.tabContentTop and window.moduleHeader.title:GetText() == 'Chat', 'section tabs pinned, never over a card')
    page.tabStylePills[2].scripts.OnClick(page.tabStylePills[2]); assert(M.db.glassTabs == false, 'Solid')
    page.tabStylePills[1].scripts.OnClick(page.tabStylePills[1]); assert(M.db.glassTabs == true, 'Glass')
    window:Hide()
    M:SetOption('idleDelay', 12)

    addon:SetModuleEnabled('chat', false)
    assert(addon.ReloadManager.requests.chat, 'off asks for a reload to bring back Blizzard\'s look')
    assert(ChatFrame1.alpha == 1, 'fades stop')
    ChatFrame1Tab:SetAlpha(0.4); assert(ChatFrame1Tab.alpha == 0.4, 'Blizzard owns tab alpha again')

    -- Version 1 settings: values still at version 1's defaults follow; picks stay.
    local old = { version = 1, backgroundColor = { 11 / 255, 11 / 255, 13 / 255 }, backgroundOpacity = 72,
        borderColor = { Kit.onyx.border[1], Kit.onyx.border[2], Kit.onyx.border[3] }, scrollBar = false, idleOpacity = 30 }
    M.Initialize(old)
    assert(old.version == 5 and old.backgroundColor[1] == Kit.onyx.health[1] and old.backgroundOpacity == 60 and old.scrollBar)
    assert(old.borderColor == nil and old.idleOpacity == 30 and old.tabHeight == 24)
    local picked = { version = 1, backgroundColor = { 1, 0, 0 }, backgroundOpacity = 80 }
    M.Initialize(picked); assert(picked.backgroundColor[1] == 1 and picked.backgroundOpacity == 80, 'picked values stay')
    local two = { version = 2, backgroundColor = { Kit.onyx.slate[1], Kit.onyx.slate[2], Kit.onyx.slate[3] } }
    M.Initialize(two); assert(two.version == 5 and two.backgroundColor[1] == Kit.onyx.health[1], 'version 2 Mode Slate follows')
    -- Version 3 -> 4: the standard border has no settings, so they go; the rest stays.
    local three = { version = 3, border = false, borderSize = 3, borderColor = { 1, 0, 0 }, backgroundOpacity = 35 }
    M.Initialize(three)
    assert(three.version == 5 and three.border == nil and three.borderSize == nil and three.borderColor == nil and three.backgroundOpacity == 35)
    -- Version 4 -> 5: a fill still at the old health color (#1C1E21) takes #131212.
    local four = { version = 4, backgroundColor = { 28 / 255, 30 / 255, 33 / 255 } }
    M.Initialize(four); assert(four.version == 5 and four.backgroundColor[1] == Kit.onyx.health[1], 'the old health color follows')
    local mine = { version = 4, backgroundColor = { 0, 0, 1 } }
    M.Initialize(mine); assert(mine.backgroundColor[3] == 1, 'a picked fill stays')
]==], "chat")

local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([==[
    local M = addon.Chat
    assert(not M.enabled and M.db.idleDelay == 12 and addon.Skin.parts[ChatFrame1] == nil, 'settings persist; nothing skinned while off')
]==], "chat_restore")
print("chat: all checks passed")
