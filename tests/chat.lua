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
        frame.ScrollBar = CreateFrame('Frame', nil, frame)
        frame.ScrollToBottomButton = CreateFrame('Button', nil, frame)
        local scroll = frame.ScrollToBottomButton
        scroll.normal = scroll:CreateTexture(nil, 'ARTWORK')
        function scroll:GetNormalTexture() return self.normal end
        scroll.Flash = scroll:CreateTexture(nil, 'OVERLAY')
        local edit = CreateFrame('EditBox', name .. 'EditBox', frame)
        frame.editBox = edit
        _G[name .. 'EditBoxLeft'] = edit:CreateTexture(nil, 'BACKGROUND')
        edit.focusLeft, edit.focusMid, edit.focusRight = edit:CreateTexture(), edit:CreateTexture(), edit:CreateTexture()
        edit.header = edit:CreateFontString()
        local tab = CreateFrame('Button', name .. 'Tab', GENERAL_CHAT_DOCK)
        tab:SetID(index)
        for _, key in ipairs({ 'Left', 'Middle', 'Right', 'ActiveLeft', 'ActiveMiddle', 'ActiveRight',
            'HighlightLeft', 'HighlightMiddle', 'HighlightRight' }) do tab[key] = tab:CreateTexture(nil, 'BACKGROUND') end
        tab.Text = tab:CreateFontString()
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
    C_VoiceChat = { GetActiveChannelID = function() return voiceChannel end }
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, Skin = addon.Chat, addon.Skin
    assert(M and addon.modules.chat == M and not M.enabled, 'registered, off by default')
    assert(M.db.fontMedia == 'Expressway' and M.db.idleOpacity == 40 and M.db.buttons == 'compartment')
    assert(ChatFrame1Background:IsShown() and Skin.parts[ChatFrame1] == nil, 'nothing changes while off')

    addon:SetModuleEnabled('chat', true)
    -- Window: Blizzard's art hidden (and kept hidden), the box at Text Inset.
    assert(not ChatFrame1Background:IsShown() and not ChatFrame2TopTexture:IsShown())
    ChatFrame1TopTexture:Show(); assert(not ChatFrame1TopTexture:IsShown(), 'Blizzard showing its art is undone')
    local panel = Skin.parts[ChatFrame1]
    assert(panel and panel.fill and #panel.rim == 4, 'Mode fill and rim on the window')
    assert(panel.fill.vertexColor[4] == 0.72, 'Background Opacity')
    local p = Point(ChatFrame1Background)
    assert(p[1] == 'TOPLEFT' and p[2] == ChatFrame1 and p[4] == -6 and p[5] == 6, 'box Text Inset around the messages')
    FloatingChatFrame_UpdateBackgroundAnchors(ChatFrame1)
    p = Point(ChatFrame1Background); assert(p[4] == -6, 'Blizzard re-anchoring the box is followed')
    -- Edit box: below the box, a field whose rim turns cyan with focus.
    local e = Point(ChatFrame1EditBox)
    assert(e[1] == 'TOPLEFT' and e[2] == ChatFrame1Background and e[5] == -4 and ChatFrame1EditBox:GetHeight() == 24)
    assert(ChatFrame1EditBoxLeft.alpha == 0 and ChatFrame1EditBox.focusMid.alpha == 0, 'edit box art faded')
    local edit = Skin.parts[ChatFrame1EditBox]
    ChatFrame1EditBox:SetFocus(); ChatFrame1EditBox.scripts.OnEditFocusGained(ChatFrame1EditBox)
    assert(edit.rim[1].vertexColor[2] == 240 / 255, 'cyan rim while typing')
    ChatFrame1EditBox:ClearFocus()
    assert(edit.rim[1].vertexColor[2] ~= 240 / 255, 'field rim again')
    -- Font: the chat face, each window's own size kept.
    local path, size = ChatFrame1:GetFont()
    assert(path == addon.Kit.FontPath(M.db, 'chat') and size == 14, 'chat face, window size kept')
    assert(not ChatFrame1.ScrollBar:IsShown(), 'scroll bar hidden by default')
    ChatFrame1.ScrollBar:Show(); assert(not ChatFrame1.ScrollBar:IsShown())

    -- Tabs: art faded, glass pane, cyan bar on the selected tab, Mode text colors.
    assert(ChatFrame1Tab.Left.alpha == 0 and ChatFrame1Tab.ActiveMiddle.alpha == 0 and ChatFrame1Tab.HighlightRight.alpha == 0)
    local t1, t2 = Skin.parts[ChatFrame1Tab], Skin.parts[ChatFrame2Tab]
    assert(t1.glass.texture:find('Glass') and t1.glass:GetHeight() == 22, 'glass pane, Tab Height tall')
    assert(t1.bar:IsShown() and not t2.bar:IsShown(), 'cyan bar on the selected tab only')
    FCFTab_UpdateColors(ChatFrame2Tab, false)
    assert(ChatFrame2Tab.Text.color[1] == 196 / 255, 'Mode label gray after Blizzard colors the text')
    FCFDock_SelectWindow(GENERAL_CHAT_DOCK, ChatFrame2)
    FCFTab_UpdateColors(ChatFrame2Tab, true)
    assert(t2.bar:IsShown() and ChatFrame2Tab.Text.color[1] == 242 / 255, 'picked tab: white text and the bar')
    FCFDock_SelectWindow(GENERAL_CHAT_DOCK, ChatFrame1); FCFTab_UpdateColors(ChatFrame1Tab, true); FCFTab_UpdateColors(ChatFrame2Tab, false)

    -- Compartment: Blizzard's buttons moved in, glyphs drawn, hidden voice skipped.
    local box = ModeUIChatButtons
    assert(box and ChatFrameMenuButton:GetParent() == box and ChatFrameChannelButton:GetParent() == box)
    assert(ChatFrameMenuButton.normal.alpha == 0 and Skin.parts[ChatFrameMenuButton].glyph, 'glyph instead of Blizzard art')
    assert(box:GetWidth() == 1 + 22 + 1 + 22 + 1 and box:GetHeight() == 20, 'two cells, a divider, a rim')
    ChatFrameToggleVoiceDeafenButton:Show()
    assert(box:GetWidth() == 1 + 22 + 1 + 22 + 1 + 22 + 1, 'voice button joins the row when shown')
    ChatFrameToggleVoiceDeafenButton:Hide()
    assert(Point(ChatAlertFrame)[2] == box, 'Social and Text to Speech stack above the compartment')

    -- Tab fade: Blizzard's SetAlpha is answered with ModeUI's value.
    Advance(0.1)
    ChatFrame1Tab:SetAlpha(0.4)
    assert(ChatFrame1Tab.alpha == 0, 'away: Tabs When Away (0%)')
    ChatFrame1.mouseOver = true
    for _ = 1, 10 do Advance(0.1) end
    assert(ChatFrame1Tab.alpha == 1 and math.abs(ChatFrame2Tab.alpha - 0.55) < 1e-6, 'in use: selected full, others 55%')
    assert(box.alpha == 1)
    alerting[ChatFrame2Tab] = true; ChatFrame2Tab:SetAlpha(0.2)
    assert(ChatFrame2Tab.alpha == 1, 'a flashing whisper tab shows'); alerting[ChatFrame2Tab] = nil
    ChatFrame1.mouseOver = false

    -- Idle fade: 8 seconds without use, then down to 40%.
    for _ = 1, 30 do Advance(0.1) end
    assert(ChatFrame1.alpha == 1, 'still within Idle Delay')
    for _ = 1, 80 do Advance(0.1) end
    assert(math.abs(ChatFrame1.alpha - 0.4) < 1e-6 and ChatFrame1Tab.alpha == 0, 'idle: 40%, tabs away')
    FireEvent('CHAT_MSG_WHISPER')
    for _ = 1, 3 do Advance(0.1) end
    assert(ChatFrame1.alpha == 1, 'a whisper wakes the chat')
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
    assert(M:SetOption('backgroundOpacity', 50) and panel.fill.vertexColor[4] == 0.5)
    assert(M:SetOption('buttons', 'hidden') and not box:IsShown())
    assert(M:SetOption('buttons', 'compartment') and box:IsShown())
    assert(M:SetOption('glassTabs', false) and t1.glass.texture == addon.Kit.FLAT and not t1.sheen:IsShown())
    assert(M:SetOption('scrollBar', true)); ChatFrame1.ScrollBar:Show(); assert(ChatFrame1.ScrollBar:IsShown(), 'Scroll Bar on')
    assert(M:SetOption('idleFade', false)); for _ = 1, 120 do Advance(0.1) end
    assert(ChatFrame1.alpha == 1, 'no idle fade when off')
    M:ResetToDefaults(); assert(M.db.glassTabs and M.db.idleFade and M.db.backgroundOpacity == 72)

    -- The page exists only once the window opens it.
    SlashCmdList.MODEUI()
    local window = addon.configWindow
    assert(window.pages.chat == nil)
    addon:SelectConfigPage('chat')
    local page = window.pages.chat
    assert(page and page:IsShown() and page.idleOpacitySlider and page.glassToggles and window.moduleHeader.title:GetText() == 'Chat')
    window:Hide()
    M:SetOption('idleDelay', 12)

    addon:SetModuleEnabled('chat', false)
    assert(addon.ReloadManager.requests.chat, 'off asks for a reload to bring back Blizzard\'s look')
    assert(ChatFrame1.alpha == 1, 'fades stop')
    ChatFrame1Tab:SetAlpha(0.4); assert(ChatFrame1Tab.alpha == 0.4, 'Blizzard owns tab alpha again')
]==], "chat")

local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([==[
    local M = addon.Chat
    assert(not M.enabled and M.db.idleDelay == 12 and addon.Skin.parts[ChatFrame1] == nil, 'settings persist; nothing skinned while off')
]==], "chat_restore")
print("chat: all checks passed")
