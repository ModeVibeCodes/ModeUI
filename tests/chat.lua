-- Chat: Blizzard's chat windows (stubbed with Forever's keys and names)
-- skinned in the Mode design language: hidden art, the Mode window on its
-- box, the edit box, Mode tabs and their pinned alpha, the button compartment, the tab fade,
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
    local M, Skin, Kit, C = addon.Chat, addon.Skin, addon.Kit, addon.Skin.mode
    local Tone = addon.Style.Tone
    local G = Tone.graphite
    assert(M and addon.modules.chat == M and not M.enabled, 'registered, off by default')
    assert(M.db.fontMedia == 'Mode' and M.db.idleOpacity == 40 and M.db.buttons == 'compartment', 'the Mode typeface')
    assert(M.db.backgroundColor[1] == G.panel[1] and M.db.backgroundOpacity == 60, 'Graphite panel, 60%')
    assert(M.db.border == nil and M.db.borderSize == nil and M.db.borderColor == nil, 'the border has no settings')
    assert(M.db.tabHeight == 24 and M.db.editPosition == 'bottom' and M.db.scrollBar)
    assert(ChatFrame1Background:IsShown() and Skin.parts[ChatFrame1] == nil, 'nothing changes while off')

    addon:SetModuleEnabled('chat', true)
    -- Window: Blizzard's art hidden (and kept hidden), the box around the text.
    assert(not ChatFrame1Background:IsShown() and not ChatFrame2TopTexture:IsShown())
    ChatFrame1TopTexture:Show(); assert(not ChatFrame1TopTexture:IsShown(), 'Blizzard showing its art is undone')
    local panel = Skin.parts[ChatFrame1]
    -- The Mode window: Mode Panel in Graphite at Background Opacity, the
    -- `window` edge inside the box on its own frame above the window (the idle
    -- fade dims it with the window); no masks, no soft drop under a
    -- see-through fill.
    assert(panel.faceKey == 'Panel' and panel.face.vertexColor[1] == G.panel[1] and panel.face.vertexColor[4] == 0.6, 'Mode Panel at 60%')
    assert(panel.lift and panel.lift.texture:find('PanelLift', 1, true) and panel.lift.vertexColor[4] == 0.6, 'its lift at the same alpha')
    assert(Point(panel.face)[2] == ChatFrame1Background, 'the face on the box')
    assert(panel.modeEdge.preset == 'window' and panel.modeEdge.holder:IsShown(), 'the window edge')
    local e = Point(panel.edgeFrame)
    assert(e[2] == ChatFrame1Background and e[4] == 3 and e[5] == -3, 'the edge inside the box')
    assert(panel.edgeFrame:GetParent() == ChatFrame1 and panel.edgeFrame:GetFrameLevel() > ChatFrame1:GetFrameLevel(), 'above the window')
    assert(not panel.modeEdge.below:IsShown(), 'no drop under a see-through window')
    local p = Point(ChatFrame1Background)
    -- Text Inset 6 + the window edge's 3px; the edit box (24) inside at the
    -- bottom; the scroll bar's 10px gutter at the right.
    assert(p[1] == 'TOPLEFT' and p[2] == ChatFrame1 and p[4] == -9 and p[5] == 9, 'box around the messages')
    local q = Point(ChatFrame1Background, 2)
    assert(q[1] == 'BOTTOMRIGHT' and q[4] == 19 and q[5] == -33, 'room for the edit box and the scroll bar')
    FloatingChatFrame_UpdateBackgroundAnchors(ChatFrame1)
    p = Point(ChatFrame1Background); assert(p[4] == -9, 'Blizzard re-anchoring the box is followed')
    -- Edit box: joined to the window inside its edge, on a darker Graphite band.
    local band = Point(panel.band)
    assert(panel.band:IsShown() and band[1] == 'BOTTOMLEFT' and band[2] == ChatFrame1Background and band[4] == 3 and band[5] == 3)
    assert(panel.band:GetHeight() == 24 and Point(ChatFrame1EditBox)[2] == panel.band, 'edit box on the band')
    assert(panel.band.vertexColor[1] == G.base[1] and math.abs(panel.band.vertexColor[4] - 0.75) < 1e-6, 'Graphite base, a little darker')
    assert(ChatFrame1EditBoxLeft.alpha == 0 and ChatFrame1EditBox.focusMid.alpha == 0, 'edit box art faded')
    assert(panel.bandLine.vertexColor[1] == G.line[1], 'a Graphite divider')
    ChatFrame1EditBox:SetFocus(); ChatFrame1EditBox.scripts.OnEditFocusGained(ChatFrame1EditBox)
    assert(panel.bandLine.vertexColor[1] == Tone.ivory[1], 'the divider turns Ivory while typing')
    ChatFrame1EditBox:ClearFocus(); ChatFrame1EditBox.scripts.OnEditFocusLost(ChatFrame1EditBox)
    assert(panel.bandLine.vertexColor[1] == G.line[1], 'Graphite again')
    -- Font: the chat face, each window's own size kept.
    local path, size = ChatFrame1:GetFont()
    assert(path == Kit.FontPath(M.db, 'chat') and size == 14, 'chat face, window size kept')
    -- Scroll bar: skinned and in the gutter; Scroll to Bottom's flash hidden.
    local bar = ChatFrame1.ScrollBar
    assert(bar.Track.Middle.alpha == 0 and bar.Back.Texture.alpha == 0 and Skin.parts[bar].thumb, 'slim Mode track and thumb')
    assert(Point(bar)[1] == 'TOPRIGHT' and Point(bar)[2] == ChatFrame1Background and Point(bar)[4] == -4 and Point(bar)[5] == -7, 'below the round corner')
    FCF_UpdateScrollbarAnchors(ChatFrame1); assert(Point(bar)[2] == ChatFrame1Background, 'Blizzard re-anchoring it is followed')
    local flash = ChatFrame1.ScrollToBottomButton.Flash
    flash:Show(); assert(not flash:IsShown(), 'no flashing arrow')
    local scroll = Skin.parts[ChatFrame1.ScrollToBottomButton]
    assert(scroll.faceKey == 'Button' and scroll.modeEdge.preset == 'control' and scroll.icon.vertexColor[1] == G.secondary[1], 'a Mode control')
    ChatFrame1.ScrollToBottomButton.scripts.OnEnter(ChatFrame1.ScrollToBottomButton)
    assert(scroll.icon.vertexColor[1] == Tone.ivory[1] and scroll.modeEdge.highlight[1] == Tone.ivory[1], 'Ivory on hover')
    ChatFrame1.ScrollToBottomButton.scripts.OnLeave(ChatFrame1.ScrollToBottomButton)
    assert(scroll.modeEdge.highlight == nil, 'plain again')

    -- Tabs: art faded, Mode panes on the edge, the selected one raised and Ivory.
    assert(ChatFrame1Tab.Left.alpha == 0 and ChatFrame1Tab.ActiveMiddle.alpha == 0 and ChatFrame1Tab.HighlightRight.alpha == 0)
    local t1, t2 = Skin.parts[ChatFrame1Tab], Skin.parts[ChatFrame2Tab]
    assert(t1.pane:GetHeight() == 24 and t2.pane:GetHeight() == 21, 'selected full, others tucked 3px')
    assert(t1.faceKey == 'Glass' and t1.face.vertexColor[4] == 0.75 and t1.lift:IsShown(), 'Glass: Mode Glass, see-through')
    assert(t1.face.vertexColor[1] == G.track[1] and t2.face.vertexColor[1] == G.raised[1], 'the selected tab in the chosen tone')
    assert(t1.modeEdge.preset == 'control' and t1.modeEdge.highlight[1] == Tone.ivory[1] and t2.modeEdge.highlight == nil, 'Ivory line on the selected tab only')
    assert(Point(t1.edgeFrame)[2] == t1.pane and Point(t1.edgeFrame)[4] == 2, 'the edge inside the pane')
    local tf = Point(t1.face)
    assert(tf[2] == t1.pane and tf[4] == 2 and tf[5] == -2 and Point(t1.lift)[4] == 2, 'the face stops under the rim: no square corners past the round ones')
    assert(Point(ChatFrame1Tab.Text)[2] == t1.pane, 'text on the pane\'s middle')
    -- Tab width: sized to the text in the Mode face (7 letters at 13).
    assert(ChatFrame1Tab:GetWidth() == math.ceil(7 * 13 * 0.6) + 20, 'General fits')
    ChatFrame1Tab.Text:SetFont('Fonts/FRIZQT__.TTF', 9, ''); PanelTemplates_TabResize(ChatFrame1Tab, 0)
    ChatFrame1Tab.Text:SetFont(Kit.FontPath(M.db, 'chat'), 13, ''); PanelTemplates_TabResize(ChatFrame1Tab, 0)
    assert(ChatFrame1Tab:GetWidth() == math.ceil(7 * 13 * 0.6) + 20, 'Blizzard\'s resize is followed')
    ChatFrame2.chatType = 'WHISPER'
    assert(not M:SizeTab(ChatFrame2Tab), 'whisper tabs are never measured'); ChatFrame2.chatType = nil
    FCFTab_UpdateColors(ChatFrame2Tab, false)
    assert(ChatFrame2Tab.Text.color[1] == G.secondary[1], 'Graphite secondary after Blizzard colors the text')
    FCFDock_SelectWindow(GENERAL_CHAT_DOCK, ChatFrame2)
    FCFTab_UpdateColors(ChatFrame2Tab, true); FCFTab_UpdateColors(ChatFrame1Tab, false)
    assert(t2.modeEdge.highlight and ChatFrame2Tab.Text.color[1] == Tone.ivory[1] and t2.pane:GetHeight() == 24 and t1.pane:GetHeight() == 21,
        'picked tab: raised, Ivory text and line')
    FCFDock_SelectWindow(GENERAL_CHAT_DOCK, ChatFrame1); FCFTab_UpdateColors(ChatFrame1Tab, true); FCFTab_UpdateColors(ChatFrame2Tab, false)

    -- Compartment: Blizzard's buttons moved in, glyphs drawn, hidden voice skipped.
    local box = ModeUIChatButtons
    assert(box and ChatFrameMenuButton:GetParent() == box and ChatFrameChannelButton:GetParent() == box)
    assert(ChatFrameMenuButton.normal.alpha == 0 and Skin.parts[ChatFrameMenuButton].glyph, 'glyph instead of Blizzard art')
    -- The cells inside the 2px control edge, one-pixel dividers between them.
    assert(box:GetWidth() == 2 + 34 + 1 + 22 + 1 + 22 + 2 and box:GetHeight() == 22, 'Friends, Channels and the menu, dividers, the edge')
    local bp = Skin.parts[box]
    assert(bp.modeEdge.preset == 'control' and bp.faceKey == 'Solid' and bp.face.vertexColor[1] == G.base[1], 'a Mode control')
    assert(box.dividers[1].vertexColor[1] == G.line[1], 'Graphite dividers')
    -- Friends: in the compartment, first, its art hidden for good, a glyph and its count.
    local friends = QuickJoinToastButton
    assert(friends:GetParent() == box and Point(friends)[4] == 2, 'Friends grouped with the other buttons, first')
    assert(not friends.FriendsButton:IsShown() and Skin.parts[friends].glyph.texture:find('Friends'), 'a Mode glyph instead of its art')
    friends.FriendsButton:Show(); assert(not friends.FriendsButton:IsShown(), 'its toast animations can\'t bring the art back')
    assert(Point(friends.FriendCount)[1] == 'RIGHT' and friends.FriendCount.color[1] == C.label[1], 'the online count beside the glyph')
    ChatAlertFrame:UpdateAnchors()
    assert(Point(friends)[2] == box, 'put back when Blizzard\'s alert column places it again')
    ChatFrameToggleVoiceDeafenButton:Show()
    assert(box:GetWidth() == 2 + 34 + 1 + 22 + 1 + 22 + 1 + 22 + 2, 'voice button joins the row when shown')
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
    assert(M:SetOption('backgroundOpacity', 50) and panel.face.vertexColor[4] == 0.5 and not panel.modeEdge.below:IsShown())
    assert(M:SetOption('backgroundOpacity', 100) and panel.modeEdge.below:IsShown(), 'an opaque window has its soft drop')
    M:SetOption('backgroundOpacity', 50)
    assert(not M:SetOption('border', false) and not M:SetOption('borderColor', { 1, 0, 0 }) and panel.modeEdge.holder:IsShown(), 'the edge is locked')
    assert(M:SetOption('editPosition', 'top') and Point(ChatFrame1Background)[5] == 9 + 24 and Point(panel.band)[1] == 'TOPLEFT', 'edit box at the top')
    assert(Point(panel.band)[5] == -3 and Point(panel.bandLine)[1] == 'BOTTOMLEFT', 'the band inside the top edge, its divider under it')
    assert(Point(bar)[5] == -(3 + 24 + 4), 'the scroll bar under the band')
    assert(M:SetOption('editPosition', 'below') and not panel.band:IsShown(), 'Below: its own field')
    local ep = Point(ChatFrame1EditBox)
    local field = Skin.parts[ChatFrame1EditBox]
    assert(ep[1] == 'TOPLEFT' and ep[2] == ChatFrame1Background and ep[5] == -4 and field.modeEdge.holder:IsShown())
    -- A Mode field: Graphite base in the `control` edge inside it.
    assert(field.faceKey == 'Solid' and field.face.vertexColor[1] == G.base[1] and field.face.vertexColor[4] == 1, 'a Mode field')
    assert(field.modeEdge.preset == 'control' and Point(field.edgeFrame)[4] == 2, 'the control edge inside it')
    ChatFrame1EditBox:SetFocus(); ChatFrame1EditBox.scripts.OnEditFocusGained(ChatFrame1EditBox)
    assert(field.modeEdge.highlight[1] == Tone.ivory[1], 'Ivory while typing')
    ChatFrame1EditBox:ClearFocus(); ChatFrame1EditBox.scripts.OnEditFocusLost(ChatFrame1EditBox)
    assert(field.modeEdge.highlight == nil, 'plain again')
    local s = Point(ChatFrame1.ScrollToBottomButton)
    assert(s[4] == -7 and s[5] == 7, 'Scroll to Bottom clear of the round corner')
    M:SetOption('editPosition', 'bottom')
    assert(not field.modeEdge.holder:IsShown() and field.face.vertexColor[4] == 0 and panel.band:IsShown(), 'inside again: no field edge')
    assert(M:SetOption('tabHeight', 28)); assert(t1.pane:GetHeight() == 28, 'h1 ' .. tostring(t1.pane:GetHeight()))
    assert(M:SetOption('tuckDepth', 0)); assert(t2.pane:GetHeight() == 28, 'h2 ' .. tostring(t2.pane:GetHeight()))
    assert(M:SetOption('buttons', 'hidden') and not box:IsShown())
    assert(M:SetOption('buttons', 'compartment') and box:IsShown())
    assert(M:SetOption('glassTabs', false) and t1.faceKey == 'Button' and t1.face.vertexColor[4] == 1, 'Solid: the Mode Button face')
    assert(M:SetOption('scrollBar', false)); bar:Show(); assert(not bar:IsShown() and bar.alpha == 0, 'Scroll Bar off')
    assert(Point(ChatFrame1Background, 2)[4] == 9, 'no gutter without the scroll bar')
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
    assert(old.version == 6 and old.backgroundColor[1] == G.panel[1] and old.backgroundOpacity == 60 and old.scrollBar)
    assert(old.borderColor == nil and old.idleOpacity == 30 and old.tabHeight == 24 and old.fontMedia == 'Mode')
    local picked = { version = 1, backgroundColor = { 1, 0, 0 }, backgroundOpacity = 80 }
    M.Initialize(picked); assert(picked.backgroundColor[1] == 1 and picked.backgroundOpacity == 80, 'picked values stay')
    local two = { version = 2, backgroundColor = { Kit.onyx.slate[1], Kit.onyx.slate[2], Kit.onyx.slate[3] } }
    M.Initialize(two); assert(two.version == 6 and two.backgroundColor[1] == G.panel[1], 'version 2 Mode Slate follows')
    -- Version 3 -> 4: the standard border has no settings, so they go; the rest stays.
    local three = { version = 3, border = false, borderSize = 3, borderColor = { 1, 0, 0 }, backgroundOpacity = 35 }
    M.Initialize(three)
    assert(three.version == 6 and three.border == nil and three.borderSize == nil and three.borderColor == nil and three.backgroundOpacity == 35)
    -- Version 4 -> 5: a fill still at the old health color (#1C1E21) follows on to Graphite.
    local four = { version = 4, backgroundColor = { 28 / 255, 30 / 255, 33 / 255 } }
    M.Initialize(four); assert(four.version == 6 and four.backgroundColor[1] == G.panel[1], 'the old health color follows')
    local mine = { version = 4, backgroundColor = { 0, 0, 1 } }
    M.Initialize(mine); assert(mine.backgroundColor[3] == 1, 'a picked fill stays')
    -- Version 5 -> 6: the Mode design language. #131212 takes Graphite panel,
    -- Expressway the Mode typeface; picked values stay.
    local five = { version = 5, backgroundColor = { Kit.onyx.health[1], Kit.onyx.health[2], Kit.onyx.health[3] }, fontMedia = 'Expressway' }
    M.Initialize(five); assert(five.version == 6 and five.backgroundColor[1] == G.panel[1] and five.fontMedia == 'Mode', 'Phase 7 defaults follow')
    local own = { version = 5, backgroundColor = { 0, 1, 0 }, fontMedia = 'Mode Geist' }
    M.Initialize(own); assert(own.backgroundColor[2] == 1 and own.fontMedia == 'Mode Geist', 'picked face and fill stay')
]==], "chat")

local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([==[
    local M = addon.Chat
    assert(not M.enabled and M.db.idleDelay == 12 and addon.Skin.parts[ChatFrame1] == nil, 'settings persist; nothing skinned while off')
]==], "chat_restore")
print("chat: all checks passed")
