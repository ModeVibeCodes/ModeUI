-- Windows: Blizzard windows (stubbed with Forever's template keys) skinned in
-- the Mode look: faded art, fill, the 2px border on its own layer, title
-- strip, title font, close and maximize/minimize buttons, insets (field under
-- the content), tabs, buttons, fields, dropdowns and their menus, side tabs,
-- right side tabs, scroll bars, list rows and window text; the Guild window's
-- portrait overlay, filigree and roster; load-on-demand windows, secure
-- windows in combat, Window Style, per-window switches, looks and scale; the
-- Character window's stats display, rarity borders and enchant text;
-- settings, the page, validation, migration, reload and persistence.
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
        frame.Inset.note = frame.Inset:CreateFontString(); frame.Inset.note:SetFont('Fonts/FRIZQT__.TTF', 11, 'OUTLINE')
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
        bar.Background = bar:CreateTexture(nil, 'BACKGROUND')
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

    -- Guild and Communities: ButtonFrameTemplateMinimizable plus its own parts.
    local guild = MakeWindow('CommunitiesFrame')
    guild.PortraitOverlay = CreateFrame('Frame', nil, guild); Textures(guild.PortraitOverlay, { 'Portrait', 'TabardEmblem' })
    local holder = CreateFrame('Frame', nil, guild)
    holder.MaximizeButton, holder.MinimizeButton = CreateFrame('Button', nil, holder), CreateFrame('Button', nil, holder)
    States(holder.MaximizeButton); States(holder.MinimizeButton)
    guild.MaximizeMinimizeFrame = holder
    -- WowStyle1DropdownTemplate, with the callback registry's two events.
    DropdownButtonMixin = { Event = { OnMenuOpen = 'OnMenuOpen', OnMenuClose = 'OnMenuClose' } }
    local dropdown = CreateFrame('DropdownButton', nil, guild)
    Textures(dropdown, { 'Background', 'Arrow' }); dropdown.Text = dropdown:CreateFontString()
    dropdown.callbacks = {}
    function dropdown:RegisterCallback(event, fn, owner) self.callbacks[event] = { fn = fn, owner = owner } end
    function dropdown:IsMenuOpen() return self.menu ~= nil end
    guild.StreamDropdown = dropdown
    -- The club list: blue menu background, gold filigree.
    local list = CreateFrame('Frame', nil, guild)
    Textures(list, { 'Bg', 'TopFiligree', 'BottomFiligree' })
    list.FilligreeOverlay = CreateFrame('Frame', nil, list); Textures(list.FilligreeOverlay, { 'TopBar', 'LeftBar' })
    guild.CommunitiesList = list
    -- The roster: an inset raised over its rows, and a ScrollBox of rows.
    local members = CreateFrame('Frame', nil, guild)
    members.InsetFrame = CreateFrame('Frame', nil, members)
    members.InsetFrame.NineSlice = CreateFrame('Frame', nil, members.InsetFrame); Textures(members.InsetFrame.NineSlice, NINE)
    Textures(members.InsetFrame, { 'Bg' }); members.InsetFrame:SetFrameLevel(100)
    local box = CreateFrame('Frame', nil, members)
    box.rows = {}
    function box:RegisterCallback() end
    function box:GetFrames() return self.rows end
    function box:ForEachFrame(fn) for _, row in ipairs(self.rows) do fn(row) end end
    function MakeRow()
        local row = CreateFrame('Button', nil, box)
        States(row)
        row.Name = row:CreateFontString(); row.Name:SetFont('Fonts/ARIALN.TTF', 12, '')
        box.rows[#box.rows + 1] = row
        return row
    end
    MakeRow()
    members.ScrollBox = box
    guild.MemberList = members
    ScrollUtil = { AddInitializedFrameCallback = function(scrollBox, callback, owner) scrollBox.initialized = { callback, owner } end }
    -- RightSideTabTemplate: an unnamed tab texture, the icon, a checked texture.
    local chatTab = CreateFrame('CheckButton', nil, guild)
    chatTab.art = chatTab:CreateTexture(nil, 'BORDER'); Textures(chatTab, { 'Icon' })
    chatTab.checked = chatTab:CreateTexture(nil, 'ARTWORK')
    function chatTab:GetCheckedTexture() return self.checked end
    function chatTab:SetChecked(value) self.isChecked = value end
    function chatTab:GetChecked() return self.isChecked end
    guild.ChatTab = chatTab
    -- The Guild chat's edit box (Left/Right/Mid) and a dropdown that answers "Button".
    local chatEdit = CreateFrame('EditBox', nil, guild); Textures(chatEdit, { 'Left', 'Right', 'Mid' }); guild.ChatEditBox = chatEdit
    local listDropdown = CreateFrame('Button', nil, guild); Textures(listDropdown, { 'Background', 'Arrow' })
    listDropdown.Text = listDropdown:CreateFontString(); function listDropdown:SetupMenu() end
    guild.ListDropdown = listDropdown

    -- The Character window: panes, the paper doll, the model, three slots.
    local character = MakeWindow('CharacterFrame')
    character.LeftPaneHost = CreateFrame('Frame', nil, character); Textures(character.LeftPaneHost, { 'Background' })
    character.RightPaneHost = CreateFrame('Frame', nil, character)
    character.RightPaneHost.art = character.RightPaneHost:CreateTexture(nil, 'BACKGROUND')
    local divider = CreateFrame('Frame', nil, character.RightPaneHost); divider.art = divider:CreateTexture(nil, 'OVERLAY')
    CharacterStatsPaneScrollBox = CreateFrame('Frame', 'CharacterStatsPaneScrollBox', character.RightPaneHost)
    Textures(CharacterStatsPaneScrollBox, { 'ClassBackground', 'Border' })
    local statBox = CreateFrame('Frame', nil, CharacterStatsPaneScrollBox)
    statBox.rows = {}
    function statBox:RegisterCallback() end
    function statBox:GetFrames() return self.rows end
    function statBox:ForEachFrame(fn) for _, row in ipairs(self.rows) do fn(row) end end
    local header = CreateFrame('Frame', nil, statBox); Textures(header, { 'Background' }); header.Title = header:CreateFontString()
    local statRow = CreateFrame('Frame', nil, statBox); Textures(statRow, { 'Background' })
    statRow.Label, statRow.Value = statRow:CreateFontString(), statRow:CreateFontString()
    statBox.rows = { header, statRow }
    CharacterStatsPaneScrollBox.ScrollBox = statBox
    character.RightPaneToggleButton = CreateFrame('Button', nil, character); States(character.RightPaneToggleButton)
    PaperDollFrame = CreateFrame('Frame', 'PaperDollFrame', character)
    PaperDollFrame.TopBackgroundStripHost = CreateFrame('Frame', nil, PaperDollFrame)
    Textures(PaperDollFrame.TopBackgroundStripHost, { 'TopBackgroundStrip', 'TopBackgroundStripBottomEdge' })
    CharacterModelScene = CreateFrame('Frame', 'CharacterModelScene', PaperDollFrame)
    for _, slot in ipairs({ { 'Head', 1 }, { 'Wrist', 9 }, { 'Hands', 10 }, { 'MainHand', 16 } }) do
        local button = CreateFrame('Button', 'Character' .. slot[1] .. 'Slot', PaperDollFrame)
        button:SetID(slot[2]); button:SetSize(37, 37)
        button.IconBorder = button:CreateTexture(nil, 'OVERLAY')
        button.BorderFrame = CreateFrame('Frame', nil, button); Textures(button.BorderFrame, { 'Art' })
    end
    -- What the player wears and how strong they are.
    stats = { 50, 120, 80, 30, 40 }
    function UnitStat(_, index) return stats[index], stats[index] end
    armor = 900
    function UnitArmor() return armor, armor end
    function GetCritChance() return 12.5 end
    function GetMeleeHaste() return 3 end
    function GetHitModifier() return 1 end
    function GetCombatRatingBonus() return 2 end
    CR_HIT_MELEE = 6
    quality = { [1] = 4, [10] = 1, [16] = 3 }
    function GetInventoryItemQuality(_, slot) return quality[slot] end
    C_Item = { GetItemQualityColor = function(q) return q / 10, 0.2, 0.9 end,
        GetWeaponEnchantInfo = function(slot) return { hasEnchant = slot == 0, enchantType = 2 } end }
    Enum = Enum or {}
    Enum.TooltipDataLineType = { None = 0, ItemEnchantmentPermanent = 15 }
    ENCHANTED_TOOLTIP_LINE = 'Enchanted: %s'
    tooltips = {
        [1] = { { type = 0, leftText = 'Helm' }, { type = 15, leftText = '|cff00ff00Enchanted: +8 Stamina|r' } },
        [10] = { { type = 0, leftText = 'Gloves' } },
        [16] = { { type = 0, leftText = 'Sword' }, { type = 0, leftText = 'Instant Poison VI (30 min)' } },
    }
    C_TooltipInfo = { GetInventoryItem = function(_, slot) return { lines = tooltips[slot] or {} } end }
]==]

local world = H.Load({ before = STUBS })
world.run([==[
    local M, Skin, C, Kit = addon.Windows, addon.Skin, addon.Skin.colors, addon.Kit
    assert(M and addon.modules.windows == M and not M.enabled, 'registered, off by default')
    assert(M.db.windows.social and M.db.windows.collections and M.db.backgroundOpacity == 94 and M.db.style == 'modeui')
    assert(M.db.borderSize == 2 and M.db.borderColor[1] == Kit.onyx.frameRim[1] and M.db.looks.social.scale == 100)
    assert(Skin.parts[FriendsFrame] == nil, 'nothing skinned while off')

    addon:SetModuleEnabled('windows', true)
    -- Frame: art faded, Mode fill, a 2px border above the window, title strip.
    assert(FriendsFrame.NineSlice.TopEdge.alpha == 0 and FriendsFrame.NineSlice.Center.alpha == 0 and FriendsFrame.Bg.alpha == 0)
    assert(FriendsFrame.PortraitContainer.alpha == 0 and FriendsFrame.TopTileStreaks.alpha == 0, 'portrait and streaks faded')
    local parts = Skin.parts[FriendsFrame]
    assert(parts.fill.vertexColor[4] == 0.94 and not parts.rim[1]:IsShown(), 'fill to the edge; the thin panel rim unused')
    assert(parts.edge and parts.edgeRim[1]:IsShown() and parts.edgeRim[1].vertexColor[1] == Kit.onyx.frameRim[1], 'border in the rim color')
    assert(parts.edge:GetFrameLevel() == FriendsFrame:GetFrameLevel() + 520, 'border above the window\'s children')
    assert(Point(parts.edgeRim[1])[5] == 0 and Point(parts.edgeRim[1], 2)[5] == -2, 'two pixels thick')
    assert(parts.strip:IsShown() and parts.strip:GetHeight() == 22 and parts.divider:GetHeight() == 1, 'title strip and divider')
    local s = Point(parts.strip); assert(s[4] == 2 and s[5] == -2, 'strip inside the border')
    local title = FriendsFrame.TitleContainer.TitleText
    local path = Kit.FontPath(M.db, 'windows')
    assert(title.font[1] == path and title.font[2] == 13 and title.color[1] == C.heading[1])
    -- Window Text: every text in the face, at its own size and outline.
    local note = FriendsFrame.Inset.note
    assert(note.font[1] == path and note.font[2] == 11 and note.font[3] == 'OUTLINE', 'window text in the Mode face, game size kept')
    -- Close: field with a cross, 18 px, inside the border's corner.
    local close = Skin.parts[FriendsFrameCloseButton]
    assert(FriendsFrameCloseButton.normal.alpha == 0 and close.icon.texture:find('Close') and FriendsFrameCloseButton:GetWidth() == 18)
    local p = Point(FriendsFrameCloseButton); assert(p[1] == 'TOPRIGHT' and p[4] == -4 and p[5] == -4)
    FriendsFrameCloseButton.scripts.OnEnter(FriendsFrameCloseButton)
    assert(close.icon.vertexColor[2] == 240 / 255, 'cyan cross on hover')
    -- Inset: its field sits on its parent, under the content; only the rim on it.
    local inset = Skin.parts[FriendsFrame.Inset]
    assert(FriendsFrame.Inset.Bg.alpha == 0 and FriendsFrame.Inset.NineSlice.Center.alpha == 0 and inset.fill)
    assert(inset.fill.parent == FriendsFrame and inset.rim[1].parent == FriendsFrame.Inset, 'inset field under the content')
    -- Tabs, buttons, fields, side tab and scroll bar.
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
    assert(bar.Background.alpha == 0, 'a scroll bar\'s marble background goes')
    local side = FriendsFrame.testSide
    assert(side.Background.alpha == 0 and side.SelectedTexture.alpha == 0)
    side:SetChecked(true); assert(Skin.parts[side].rim[1].vertexColor[2] == 240 / 255, 'checked side tab: cyan rim')
    -- The World Map draws under its border frame: border and strip, no fill.
    assert(Skin.parts[WorldMapFrame.BorderFrame].fill.vertexColor[4] == 0, 'World Map keeps its map visible')

    -- Guild and Communities.
    local guild = CommunitiesFrame
    assert(guild.PortraitOverlay.Portrait.alpha == 0 and guild.PortraitOverlay.TabardEmblem.alpha == 0, 'portrait overlay faded')
    local holder = guild.MaximizeMinimizeFrame
    local maximize, minimize = Skin.parts[holder.MaximizeButton], Skin.parts[holder.MinimizeButton]
    assert(holder.MinimizeButton.normal.alpha == 0 and minimize.icon.texture:find('Minimize') and maximize.icon.texture:find('Maximize'))
    assert(holder.MinimizeButton:GetWidth() == 18 and Point(holder)[1] == 'RIGHT' and Point(holder)[2] == CommunitiesFrameCloseButton
        and Point(holder)[4] == -2, 'beside the close button, the same size')
    holder.MinimizeButton.scripts.OnEnter(holder.MinimizeButton)
    assert(minimize.icon.vertexColor[2] == 240 / 255, 'cyan glyph on hover')
    local list = guild.CommunitiesList
    assert(list.Bg.alpha == 0 and list.TopFiligree.alpha == 0 and list.FilligreeOverlay.TopBar.alpha == 0, 'blue menu and filigree faded')
    local roster = guild.MemberList
    local rosterInset = Skin.parts[roster.InsetFrame]
    assert(rosterInset.fill.parent == roster and roster.InsetFrame.Bg.alpha == 0, 'the roster\'s raised inset draws nothing over its rows')
    local row = roster.ScrollBox.rows[1]
    assert(row.normal.alpha == 0 and row.Name.font[1] == path and row.Name.font[2] == 12, 'rows: strip faded, Mode face')
    local late = MakeRow()
    roster.ScrollBox.initialized[1](roster.ScrollBox.initialized[2], late)
    assert(late.normal.alpha == 0 and late.Name.font[1] == path, 'rows Blizzard fills later as well')
    local tab = guild.ChatTab
    assert(tab.art.alpha == 0 and tab.checked.alpha == 0 and tab.Icon.alpha ~= 0 and tab.Icon.texCoord[1] == 0.08, 'right side tab')
    tab:SetChecked(true); assert(Skin.parts[tab].rim[1].vertexColor[2] == 240 / 255, 'checked: cyan rim')
    -- The stream dropdown and its menu.
    local dropdown = guild.StreamDropdown
    local dd = Skin.parts[dropdown]
    assert(dropdown.Background.alpha == 0 and dropdown.Arrow.alpha == 0 and dd.chevron.texture:find('Chevron'), 'dropdown field')
    assert(dropdown.Text.font[1] == path)
    local menu = CreateFrame('Frame', nil, UIParent)
    local background = menu:CreateTexture(nil, 'ARTWORK'); background:SetAtlas('common-dropdown-bg')
    dropdown.menu = menu
    dropdown.callbacks.OnMenuOpen.fn(dropdown.callbacks.OnMenuOpen.owner, dropdown)
    assert(background.alpha == 0, 'Blizzard\'s menu background faded')
    local panel = select(1, menu:GetChildren())
    assert(panel and panel:IsShown() and Skin.parts[panel].fill, 'a Mode panel lent to the menu')
    assert(dd.rim[1].vertexColor[2] == 240 / 255, 'open dropdown: cyan rim')
    dropdown.menu = nil
    dropdown.callbacks.OnMenuClose.fn(dropdown.callbacks.OnMenuClose.owner, dropdown, menu)
    assert(not panel:IsShown() and panel:GetParent() == UIParent, 'taken back when the menu closes')

    assert(guild.ChatEditBox.Mid.alpha == 0 and Skin.parts[guild.ChatEditBox].box, 'the Guild chat box: a field')
    assert(guild.ListDropdown.Arrow.alpha == 0 and Skin.parts[guild.ListDropdown].chevron, 'a dropdown that answers Button')
    -- Character window: the stats pane in Onyx.
    local right = CharacterFrame.RightPaneHost
    assert(right.art.alpha == 0 and CharacterStatsPaneScrollBox.ClassBackground.alpha == 0 and CharacterStatsPaneScrollBox.Border.alpha == 0)
    assert(Skin.parts[right].field and Skin.parts[right].divider:GetWidth() == 1, 'an Onyx field and a divider')
    local header, statRow = unpack(CharacterStatsPaneScrollBox.ScrollBox.rows)
    assert(header.Background.alpha == 0 and Skin.parts[header].fill and header.Title.color[1] == C.heading[1], 'category: Onyx strip')
    assert(statRow.Background.desaturated and statRow.Background.vertexColor[4] == 0.35 and statRow.Label.color[1] == C.label[1], 'rows: gray stripe')
    local strip = PaperDollFrame.TopBackgroundStripHost
    assert(strip.TopBackgroundStrip.alpha == 0 and Skin.parts[strip].divider, 'the rock strip goes')
    assert(Skin.parts[CharacterFrame.RightPaneToggleButton].icon.texture:find('Chevron'), 'pane button glyph')

    -- Load-on-demand: a secure window loaded in combat waits for the end of it.
    testCombat = true
    local journal = MakeWindow('CollectionsJournal'); journal.protected = true
    FireEvent('ADDON_LOADED', 'Blizzard_Collections')
    assert(Skin.parts[CollectionsJournal] == nil, 'secure window waits for combat to end')
    testCombat = false
    FireEvent('PLAYER_REGEN_ENABLED')
    assert(Skin.parts[CollectionsJournal].fill and CollectionsJournal.NineSlice.TopEdge.alpha == 0, 'skinned after combat')
    -- A new control made later is skinned the next time the window shows.
    local lateButton = CreateFrame('Button', nil, FriendsFrame)
    lateButton.Left, lateButton.Middle, lateButton.Right = lateButton:CreateTexture(), lateButton:CreateTexture(), lateButton:CreateTexture()
    lateButton.Text = lateButton:CreateFontString()
    FriendsFrame:Hide(); FriendsFrame:Show()
    assert(lateButton.Left.alpha == 0 and Skin.parts[lateButton].fill, 'reskinned on show')

    -- Character window: stats display.
    local statsFrame = ModeUICharacterStats
    assert(statsFrame and statsFrame:IsShown() and statsFrame:GetParent() == PaperDollFrame)
    local area = M.statsArea
    assert(area and Point(area)[2] == CharacterHeadSlot and Point(area, 2)[2] == CharacterHandsSlot and Point(area, 3)[2] == CharacterWristSlot,
        'the model area: between the slot columns, above the weapons')
    local a = Point(statsFrame); assert(a[1] == 'TOPLEFT' and a[2] == area and a[4] == 8 and a[5] == -8, 'at Stats Anchor of the area')
    local lines = statsFrame.lines
    assert(lines[1].label.text == 'Agility' and lines[1].value.text == '120' and lines[1].label.color[1] == M.STAT_COLORS.agility[1],
        'Main Stat: the highest, in its attribute\'s color')
    assert(lines[2].label.color[1] == M.STAT_COLORS.stamina[1] and lines[2].value.color[1] == C.heading[1], 'stat colors; values white')
    assert(M:SetStatColor('agility', { 0, 1, 0 }) and lines[1].label.color[2] == 1, 'Stat Colors')
    assert(not M:SetStatColor('mainStat', { 0, 1, 0 }) and not M:SetStatColor('agility', { 2, 0, 0 }))
    assert(lines[2].label.text == 'Stamina' and lines[2].value.text == '80')
    assert(lines[3].label.text == 'Armor' and lines[3].value.text == '900')
    assert(lines[4].value.text == '12.50%' and lines[5].value.text == '3.00%' and lines[6].value.text == '3.00%', 'crit, hit (+rating), haste')
    assert(lines[1].label.font[1] == path and lines[1].label.font[2] == 12)
    armor = { secret = true }
    assert(M:SetStat('spellPower', true) and M:SetStat('stamina', false))
    assert(lines[2].label.text == 'Armor' and lines[2].value.text == '-', 'a secret value shows a dash')
    local spell = lines[3]; assert(spell.label.text == 'Spell Power' and spell.value.text == '-', 'a missing function shows a dash')
    armor = 900
    assert(M:SetOption('charStatsAnchor', 'BOTTOMRIGHT') and M:SetOption('charStatsX', -4))
    a = Point(statsFrame); assert(a[1] == 'BOTTOMRIGHT' and a[4] == -4)
    -- Never past the area: offsets clamped, width no wider than the area.
    area:SetWidth(200); area:SetHeight(100)
    assert(M:SetOption('charStatsX', -300) and Point(statsFrame)[4] == -50 and statsFrame:GetWidth() == 150, 'kept inside the area')
    assert(M:SetOption('charStatsX', 40) and Point(statsFrame)[4] == 0, 'never past the right column')
    area:SetWidth(120); M:CharacterRefresh(); assert(statsFrame:GetWidth() == 120, 'as wide as the area at most')
    area.width, area.height = nil, nil
    assert(M.SummarizeEnchant('Lesser Strength and Agility') == 'Lesser Strength & Agility')
    assert(M.ShortStat('+3 Strength and Agility') == '+3 Str & Agi', '"and" reads "&"')
    assert(not M:SetOption('charStatsAnchor', 'MIDDLE') and not M:SetOption('charStatsX', 900))
    assert(M:SetOption('charStats', false) and not statsFrame:IsShown())
    assert(M:SetOption('charStats', true) and statsFrame:IsShown())
    -- Rarity borders and enchant text.
    local head, hands, weapon = M.slotParts[CharacterHeadSlot], M.slotParts[CharacterHandsSlot], M.slotParts[CharacterMainHandSlot]
    assert(head.rim[1]:IsShown() and head.rim[1].vertexColor[1] == 0.4 and head.rim[1].vertexColor[3] == 0.9, 'Epic: quality color')
    assert(hands.rim[1].vertexColor[1] == M.db.borderColor[1], 'Common: the rim color')
    assert(CharacterHeadSlot.IconBorder.alpha == 0 and CharacterHeadSlot.BorderFrame.Art.alpha == 0, 'Blizzard\'s rings faded')
    assert(head.name:IsShown() and head.name.text == '+8 Sta' and not head.stat:IsShown(), 'a stat enchant: one short line')
    local n = Point(head.name); assert(n[1] == 'LEFT' and n[2] == CharacterHeadSlot and n[3] == 'RIGHT' and n[4] == 6, 'left column: text to the right')
    assert(head.name.color[2] == 240 / 255 and head.name.font[2] == 10)
    assert(not hands.name:IsShown(), 'no enchant, no text')
    assert(weapon.name.text == 'Instant Poison VI' and weapon.stat.text == 'Nature damage proc', 'a poison and what it does')
    assert(weapon.name.color[1] == Kit.palette.green[1], 'temporary enhancements in green')
    assert(Point(weapon.stat)[1] == 'BOTTOM' and Point(weapon.stat)[3] == 'TOP' and Point(weapon.name)[2] == weapon.stat, 'weapons: above the slot')
    tooltips[16][3] = { type = 15, leftText = 'Enchanted: Crusader' }
    M:CharacterRefresh()
    assert(weapon.name.text == 'Crusader' and weapon.stat.text == '+100 Str proc, heals' and weapon.name.color[2] == 240 / 255,
        'a permanent enchant comes first, with its stat')
    local name, stat = M.SummarizeEnchant('Sharpened (+8 Damage)'); assert(name == 'Sharpened' and stat == '+8 Dmg')
    assert(M:SetOption('charBorders', false) and not head.rim[1]:IsShown() and CharacterHeadSlot.IconBorder.alpha == 1)
    assert(M:SetOption('charEnchants', false) and not weapon.name:IsShown())
    M:SetOption('charBorders', true); M:SetOption('charEnchants', true)

    -- Settings: validated on a copy; look changes repaint at once.
    assert(not M:SetOption('backgroundOpacity', 140) and not M:SetOption('windows', {}) and not M:SetOption('looks', {}))
    assert(not M:SetOption('nope', true) and not M:SetOption('style', 'retro') and not M:SetOption('borderSize', 9))
    assert(M:SetOption('backgroundOpacity', 60) and parts.fill.vertexColor[4] == 0.6)
    assert(M:SetOption('borderSize', 3) and Point(parts.edgeRim[1], 2)[5] == -3, 'Border Size')
    assert(M:SetOption('titleBar', false) and not parts.strip:IsShown())
    assert(M:SetOption('titleSize', 15) and title.font[2] == 15)
    assert(M:SetOption('border', false) and not parts.edgeRim[1]:IsShown())
    assert(M:SetOption('buttons', false) and addon.ReloadManager.requests.windows, 'turning a control off asks for a reload')
    addon.ReloadManager:Clear('windows')
    -- A window's own look and scale.
    assert(M:SetLook('social', 'custom', true) and M:SetLook('social', 'backgroundOpacity', 40) and M:SetLook('social', 'border', true))
    assert(parts.fill.vertexColor[4] == 0.4 and parts.edgeRim[1]:IsShown(), 'its own look wins')
    assert(Skin.parts[MerchantFrame].fill.vertexColor[4] == 0.6, 'others keep the Look tab\'s')
    assert(M:SetLook('social', 'scale', 120) and FriendsFrame.scale == 1.2, 'Scale')
    assert(not M:SetLook('social', 'scale', 300) and not M:SetLook('social', 'nope', 1) and not M:SetLook('nope', 'scale', 100))
    assert(not M:SetLook('worldMap', 'scale', 'big'))
    -- A window switched off is left alone from then on.
    assert(M:SetWindow('merchant', false) and addon.ReloadManager.requests.windows)
    M:SetOption('backgroundOpacity', 30)
    assert(Skin.parts[MerchantFrame].fill.vertexColor[4] == 30 / 100, 'repainted, not reskinned, until reload')
    assert(not M:SetWindow('nope', true))
    -- Window Style Blizzard: nothing new is skinned; ModeUI brings it back.
    addon.ReloadManager:Clear('windows')
    assert(M:SetOption('style', 'blizzard') and addon.ReloadManager.requests.windows, 'Blizzard asks for a reload')
    local mail = MakeWindow('MailFrame')
    FireEvent('ADDON_LOADED', 'nothing'); M:SkinAll()
    assert(Skin.parts[MailFrame] == nil or Skin.parts[MailFrame].fill == nil, 'Blizzard style: left alone')
    assert(M:SetOption('style', 'modeui') and Skin.parts[MailFrame].fill, 'ModeUI again: skinned')
    M:ResetToDefaults()
    assert(M.db.backgroundOpacity == 94 and M.db.windows.merchant == false and M.db.looks.social.scale == 120, 'reset keeps switches and looks')

    -- The page: pinned tabs, every window collapsed, expanding shows its settings.
    SlashCmdList.MODEUI()
    local window = addon.configWindow
    assert(window.pages.windows == nil)
    addon:SelectConfigPage('windows')
    local page = window.pages.windows
    assert(page and page:IsShown() and window.moduleHeader.title:GetText() == 'Windows' and page.tabContentTop, 'tabs pinned above the cards')
    local count = 0; for _ in pairs(page.windowRows) do count = count + 1 end
    assert(count == #M.registry and next(page.expandedWindows) == nil, 'one row per window, all collapsed')
    page:SelectSectionTab(2)
    local socialRow = page.windowRows.social
    local scaleRow = page.windowLooks.social.scale
    assert(socialRow.toggle:IsVisible() and not scaleRow:IsVisible(), 'collapsed: no settings')
    assert(socialRow.chevron.rotation == math.pi / 2, 'the chevron points right while collapsed')
    socialRow.expand.scripts.OnClick(socialRow.expand)
    assert(page.expandedWindows.social and scaleRow:IsVisible() and socialRow.chevron.rotation == 0, 'expanded: Scale and its look')
    assert(not page.windowLooks.merchant.scale:IsVisible(), 'others stay collapsed')
    page:SelectSectionTab(3)
    assert(page.statsAnchorButtons and page.nudgeButtons.Up and page.characterStylePills)
    local y = M.db.charStatsY
    page.nudgeButtons.Up.scripts.OnClick(page.nudgeButtons.Up)
    assert(M.db.charStatsY == y + 1, 'nudge: one pixel')
    window:Hide()

    addon:SetModuleEnabled('windows', false)
    assert(addon.ReloadManager.requests.windows, 'off asks for a reload')
    assert(not statsFrame:IsShown(), 'the stats display goes with the module')

    -- Version 1 settings: an untouched border color follows; picks stay.
    local old = { version = 1, borderColor = { Kit.onyx.border[1], Kit.onyx.border[2], Kit.onyx.border[3] },
        windows = { social = false }, backgroundOpacity = 80 }
    M.Initialize(old)
    assert(old.version == 2 and old.borderColor[1] == Kit.onyx.frameRim[1] and old.windows.social == false and old.backgroundOpacity == 80)
    assert(old.looks.social.scale == 100 and old.style == 'modeui' and old.charStatList.mainStat, 'new settings filled in')
    local picked = { version = 1, borderColor = { 1, 0, 0 } }
    M.Initialize(picked); assert(picked.borderColor[1] == 1, 'a picked color stays')
]==], "windows")

local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([==[
    local M = addon.Windows
    assert(not M.enabled and M.db.windows.merchant == false and M.db.windows.social, 'switches persist')
    assert(M.db.looks.social.scale == 120 and M.db.looks.social.custom and M.db.charStatsAnchor == 'BOTTOMRIGHT', 'looks and character settings persist')
    assert(addon.Skin.parts[FriendsFrame] == nil, 'nothing skinned while off')
]==], "windows_restore")
print("windows: all checks passed")
