-- Windows: Blizzard windows (stubbed with Forever's template keys) skinned in
-- the Mode look: faded art, fill, rim and title strip, title font, close
-- button, inset, tabs and their selection, buttons, fields, side tabs and
-- scroll bars; load-on-demand windows, secure windows in combat, per-window
-- switches, settings, validation, reload and persistence.
-- Simulated client; not WoW rendering or taint.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")
local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua") .. H.Read(H.root .. "tests/skin_stubs.lua") .. [==[
    local NINE = { 'TopLeftCorner', 'TopRightCorner', 'BottomLeftCorner', 'BottomRightCorner', 'TopEdge', 'BottomEdge', 'LeftEdge', 'RightEdge', 'Center' }
    local function Textures(owner, keys) for _, key in ipairs(keys) do owner[key] = owner:CreateTexture(nil, 'BORDER') end end
    local function States(button)
        button.normal = button:CreateTexture(nil, 'ARTWORK')
        function button:GetNormalTexture() return self.normal end
    end
    -- A PortraitFrameTemplate / ButtonFrameTemplate window with its controls.
    function MakeWindow(name, parent)
        local frame = CreateFrame('Frame', name, parent or UIParent)
        frame:SetSize(400, 500)
        frame.NineSlice = CreateFrame('Frame', nil, frame); Textures(frame.NineSlice, NINE)
        Textures(frame, { 'Bg', 'TopTileStreaks' })
        frame.PortraitContainer = CreateFrame('Frame', nil, frame)
        frame.TitleContainer = CreateFrame('Frame', nil, frame)
        frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString()
        frame.CloseButton = CreateFrame('Button', name .. 'CloseButton', frame); States(frame.CloseButton)
        frame.Inset = CreateFrame('Frame', name .. 'Inset', frame)
        frame.Inset.NineSlice = CreateFrame('Frame', nil, frame.Inset); Textures(frame.Inset.NineSlice, NINE)
        Textures(frame.Inset, { 'Bg' })
        for i = 1, 2 do
            local tab = CreateFrame('Button', name .. 'Tab' .. i, frame)
            Textures(tab, { 'Left', 'Middle', 'Right', 'LeftActive', 'MiddleActive', 'RightActive', 'LeftHighlight', 'MiddleHighlight', 'RightHighlight' })
            tab.Text = tab:CreateFontString()
            tab.centerX, tab.centerY = 500, 100
            local active = i == 1
            tab.LeftActive:SetShown(active); tab.MiddleActive:SetShown(active)
        end
        local button = CreateFrame('Button', nil, frame.Inset)
        Textures(button, { 'Left', 'Middle', 'Right' }); button.Text = button:CreateFontString(); States(button)
        frame.testButton = button
        local edit = CreateFrame('EditBox', nil, frame); Textures(edit, { 'Left', 'Middle', 'Right' }); frame.testField = edit
        local bar = CreateFrame('Frame', nil, frame)
        bar.Track = CreateFrame('Frame', nil, bar); Textures(bar.Track, { 'Begin', 'Middle', 'End' })
        bar.Track.Thumb = CreateFrame('Frame', nil, bar.Track); Textures(bar.Track.Thumb, { 'Begin', 'Middle', 'End' })
        bar.Back, bar.Forward = CreateFrame('Button', nil, bar), CreateFrame('Button', nil, bar)
        bar.Back.Texture = bar.Back:CreateTexture(); States(bar.Back); States(bar.Forward)
        frame.testBar = bar
        local side = CreateFrame('Button', nil, frame)
        Textures(side, { 'Background', 'Icon', 'SelectedTexture', 'HighlightTexture' })
        function side:SetChecked(value) self.checked = value end
        function side:GetChecked() return self.checked end
        frame.testSide = side
        return frame
    end
    MakeWindow('FriendsFrame')
    MakeWindow('MerchantFrame')
    WorldMapFrame = CreateFrame('Frame', 'WorldMapFrame', UIParent)
    WorldMapFrame.BorderFrame = MakeWindow('ModeTestWorldMapBorder', WorldMapFrame)
    -- Blizzard's tab picker: shows the active art.
    function PanelTemplates_SelectTab(tab) tab.LeftActive:Show(); tab.MiddleActive:Show() end
    function PanelTemplates_DeselectTab(tab) tab.LeftActive:Hide(); tab.MiddleActive:Hide() end
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, Skin, C = addon.Windows, addon.Skin, addon.Skin.colors
    assert(M and addon.modules.windows == M and not M.enabled, 'registered, off by default')
    assert(M.db.windows.social and M.db.windows.collections and M.db.backgroundOpacity == 94)
    assert(Skin.parts[FriendsFrame] == nil, 'nothing skinned while off')

    addon:SetModuleEnabled('windows', true)
    -- Frame: art faded, Mode fill and rim, title strip, Expressway title.
    assert(FriendsFrame.NineSlice.TopEdge.alpha == 0 and FriendsFrame.NineSlice.Center.alpha == 0 and FriendsFrame.Bg.alpha == 0)
    assert(FriendsFrame.PortraitContainer.alpha == 0 and FriendsFrame.TopTileStreaks.alpha == 0, 'portrait and streaks faded')
    local parts = Skin.parts[FriendsFrame]
    assert(parts.fill.vertexColor[4] == 0.94 and parts.rim[1].vertexColor[1] == addon.Kit.onyx.border[1])
    assert(parts.strip:IsShown() and parts.strip:GetHeight() == 22 and parts.divider:GetHeight() == 1, 'title strip and divider')
    local title = FriendsFrame.TitleContainer.TitleText
    assert(title.font[1] == addon.Kit.FontPath(M.db, 'windows') and title.font[2] == 13 and title.color[1] == C.heading[1])
    -- Close: field with a cross, 18 px, inside the top-right corner.
    local close = Skin.parts[FriendsFrameCloseButton]
    assert(FriendsFrameCloseButton.normal.alpha == 0 and close.icon.texture:find('Close') and FriendsFrameCloseButton:GetWidth() == 18)
    local p = Point(FriendsFrameCloseButton); assert(p[1] == 'TOPRIGHT' and p[4] == -3 and p[5] == -3)
    FriendsFrameCloseButton.scripts.OnEnter(FriendsFrameCloseButton)
    assert(close.icon.vertexColor[2] == 240 / 255, 'cyan cross on hover')
    -- Inset, tabs, buttons, fields, side tab and scroll bar.
    assert(FriendsFrame.Inset.Bg.alpha == 0 and FriendsFrame.Inset.NineSlice.Center.alpha == 0 and Skin.parts[FriendsFrame.Inset].fill)
    local t1, t2 = Skin.parts[FriendsFrameTab1], Skin.parts[FriendsFrameTab2]
    assert(FriendsFrameTab1.Left.alpha == 0 and FriendsFrameTab1.LeftActive.alpha == 0)
    assert(t1.bar:IsShown() and not t2.bar:IsShown() and t1.fill.vertexColor[1] == C.selected[1], 'selected tab: lighter, cyan bar')
    PanelTemplates_DeselectTab(FriendsFrameTab1); PanelTemplates_SelectTab(FriendsFrameTab2)
    assert(t2.bar:IsShown() and not t1.bar:IsShown() and FriendsFrameTab2.Text.color[1] == C.heading[1], 'follows Blizzard picking a tab')
    assert(Point(t2.bar)[1] == 'TOPLEFT', 'tabs under the window: bar on the window side')
    local button = FriendsFrame.testButton
    assert(button.Left.alpha == 0 and Skin.parts[button].fill, 'button field')
    button.scripts.OnEnter(button); assert(Skin.parts[button].rim[1].vertexColor[2] == 240 / 255, 'cyan rim on hover')
    assert(FriendsFrame.testField.Middle.alpha == 0 and Skin.parts[FriendsFrame.testField].box, 'edit field')
    local bar = FriendsFrame.testBar
    assert(bar.Track.Middle.alpha == 0 and bar.Track.Thumb.Begin.alpha == 0 and bar.Back.Texture.alpha == 0 and Skin.parts[bar].thumb:GetWidth() == 4)
    local side = FriendsFrame.testSide
    assert(side.Background.alpha == 0 and side.SelectedTexture.alpha == 0)
    side:SetChecked(true); assert(Skin.parts[side].rim[1].vertexColor[2] == 240 / 255, 'checked side tab: cyan rim')
    -- The World Map draws under its border frame: rim and strip, no fill.
    assert(Skin.parts[WorldMapFrame.BorderFrame].fill.vertexColor[4] == 0, 'World Map keeps its map visible')

    -- Load-on-demand: a secure window loaded in combat waits for the end of it.
    testCombat = true
    local journal = MakeWindow('CollectionsJournal'); journal.protected = true
    FireEvent('ADDON_LOADED', 'Blizzard_Collections')
    assert(Skin.parts[CollectionsJournal] == nil, 'secure window waits for combat to end')
    testCombat = false
    FireEvent('PLAYER_REGEN_ENABLED')
    assert(Skin.parts[CollectionsJournal].fill and CollectionsJournal.NineSlice.TopEdge.alpha == 0, 'skinned after combat')
    -- A new control made later is skinned the next time the window shows.
    local late = CreateFrame('Button', nil, FriendsFrame)
    late.Left, late.Middle, late.Right = late:CreateTexture(), late:CreateTexture(), late:CreateTexture()
    late.Text = late:CreateFontString()
    FriendsFrame:Hide(); FriendsFrame:Show()
    assert(late.Left.alpha == 0 and Skin.parts[late].fill, 'reskinned on show')

    -- Settings: validated on a copy; look changes repaint at once.
    assert(not M:SetOption('backgroundOpacity', 140) and not M:SetOption('windows', {}) and not M:SetOption('nope', true))
    assert(M:SetOption('backgroundOpacity', 60) and parts.fill.vertexColor[4] == 0.6)
    assert(M:SetOption('titleBar', false) and not parts.strip:IsShown())
    assert(M:SetOption('titleSize', 15) and title.font[2] == 15)
    assert(M:SetOption('border', false) and not parts.rim[1]:IsShown())
    assert(M:SetOption('buttons', false) and addon.ReloadManager.requests.windows, 'turning a control off asks for a reload')
    addon.ReloadManager:Clear('windows')
    -- A window switched off is left alone from then on.
    assert(M:SetWindow('merchant', false) and addon.ReloadManager.requests.windows)
    local merchantFill = Skin.parts[MerchantFrame].fill.vertexColor[4]
    M:SetOption('backgroundOpacity', 30)
    assert(Skin.parts[MerchantFrame].fill.vertexColor[4] == 30 / 100, 'repainted, not reskinned, until reload')
    assert(not M:SetWindow('nope', true))
    M:ResetToDefaults(); assert(M.db.backgroundOpacity == 94 and M.db.windows.merchant == false, 'reset keeps the window switches')

    SlashCmdList.MODEUI()
    local window = addon.configWindow
    assert(window.pages.windows == nil)
    addon:SelectConfigPage('windows')
    local page = window.pages.windows
    assert(page and page:IsShown() and page.windowToggles and #page.windowToggles == #M.registry and window.moduleHeader.title:GetText() == 'Windows')
    window:Hide()

    addon:SetModuleEnabled('windows', false)
    assert(addon.ReloadManager.requests.windows, 'off asks for a reload')
]==], "windows")

local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([==[
    local M = addon.Windows
    assert(not M.enabled and M.db.windows.merchant == false and M.db.windows.social, 'switches persist')
    assert(addon.Skin.parts[FriendsFrame] == nil, 'nothing skinned while off')
]==], "windows_restore")
print("windows: all checks passed")
