local _, addon = ...
local W, T = addon.ConfigWidgets, addon.InterfaceTheme
-- Settings are grouped on cards (docs/DESIGN_LANGUAGE.md, "Settings window"):
-- a Mode Matte face in Graphite raised inside the `card` border, with an
-- uppercase Ivory title (page:Group). Rows added outside a titled group share
-- an untitled card. Standard rows put 28 px controls on a 36 px pitch.
local CARD_PADDING, CARD_GAP = 12, 10
-- A card title row fits the 11px uppercase title (T.fontSize.card).
local CARD_TITLE = 22
local ROW_HEIGHT, ROW_INSET, LEGACY_ROW_HEIGHT = 36, 4, 48
-- Standard rows stack their label above the control (owner's Layout tab
-- design, November 13, 2026); a slider's value sits at the right of the label
-- line. Two pairable rows in a row (sliders, dropdowns) share one line.
local STACK_LABEL, STACK_HEIGHT, PAIR_GAP = 22, 58, 24
-- A card's border reaches 2px outside it; the scroll view keeps that room.
local EDGE_ROOM = 3

-- Notes are tips only (docs/DESIGN_LANGUAGE.md, "Settings window"): a
-- module's descriptive note (W.Note) stays hidden; W.Tip keeps the few that
-- say how to use a feature, a game option it needs, a conflict, or why a tab
-- is empty. Both take the note's label and return it.
local function NoteRow(label)
    local host = label and label.GetParent and label:GetParent()
    return host and (host.row or (host.settingsHost and host))
end
function W.Note(label)
    local row = NoteRow(label)
    if row and not row.settingsTip then row.settingsQuiet = true end
    return label
end
function W.Tip(label)
    local row = NoteRow(label)
    if row then row.settingsTip, row.settingsQuiet = true, nil end
    return label
end

-- The same responsive scrolling and row layout is used on every page.
function W.Page(parent, minimumWidth)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 0, -36)
    page:SetPoint("BOTTOMRIGHT")
    page.rows, page.refreshers, page.sections, page.searchEntries, page.cursor = {}, {}, {}, {}, 0
    page.cards = {}
    page.minimumWidth = minimumWidth
    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(400, 1)
    scroll:SetScrollChild(content)
    page.content, page.scroll = content, scroll
    page.settingsScroll = scroll
    page.contentInset=T.id=="mode" and minimumWidth~=0 and 12 or 0

    local bar = CreateFrame("Slider", nil, page)
    bar:SetPoint("TOPRIGHT", -4, -4)
    bar:SetPoint("BOTTOMRIGHT", -4, 4)
    bar:SetWidth(4)
    bar:SetOrientation("VERTICAL")
    bar:SetValueStep(24)
    W.ScrollThumb(bar, 40)
    bar:SetScript("OnValueChanged", function(_, value)
        if page.lastScrollValue~=value and addon.CloseFontDropdown then addon:CloseFontDropdown() end
        page.lastScrollValue=value;scroll:SetVerticalScroll(value);W.SnapSettings()
    end)
    page.scrollbar = bar
    local function Wheel(_,delta) bar:SetValue(bar:GetValue()-delta*42) end
    scroll:SetScript("OnMouseWheel",Wheel)
    content:EnableMouseWheel(true);content:SetScript("OnMouseWheel",Wheel)
    page:EnableMouseWheel(true);page:SetScript("OnMouseWheel",Wheel)
    function page:Layout()
        W.SnapSettings()
        local width = math.max(minimumWidth or 320, scroll:GetWidth() - 4)
        content:SetWidth(width)
        local leftInset=self.contentInset+(self.layoutInsetLeft or 0)
        width=math.max(1,width-leftInset-self.contentInset)
        -- Room above the first card for its border (gap and rim sit outside it).
        local cursor = self.layoutTopInset or EDGE_ROOM
        if self.cardColumns then
            cursor = W.LayoutCardGrid(self, width, leftInset, CARD_PADDING, CARD_GAP, cursor)
            self.cursor = cursor
            content:SetHeight(math.max(cursor + 12, self.layoutMinHeight or 0))
            local maximum = math.max(0, content:GetHeight() - scroll:GetHeight())
            bar:SetMinMaxValues(0, maximum); bar:SetValue(math.min(bar:GetValue(), maximum)); bar:SetShown(maximum > 0)
            return
        end
        local footers={}
        local function Visible(row)
            local show = row.sectionHeader or not row.section or row.section.expanded
            if self.sectionTabs then show = not row.sectionHeader and (not row.section or row.section == self.selectedSection) and (not row.section or row.section.expanded) end
            if self.ModeRowVisible then show=self:ModeRowVisible(row,show) end
            if row.settingsQuiet then show=false end
            if row.visibleWhen then show=show and row.visibleWhen() end
            return show and true or false
        end
        local function Prepare(row,footer,innerWidth)
            if not footer and row.settingsFooterMoved and row.settingsFooterRestore then
                row.settingsFooterRestore();row.settingsFooterMoved=false
            end
            local rowWidth=footer and math.max(1,content:GetWidth()-self.contentInset*2) or innerWidth or width
            local show = Visible(row)
            -- Rows on show fit their room as on tiles (PageGrid.lua): text wraps, a side label stacks.
            if footer or not show then row:SetWidth(rowWidth); if row.layoutChildren then row:layoutChildren(rowWidth) end
            else W.FitSettingsRow(row,rowWidth) end
            if footer then
                row.settingsFooterMoved=true
                local note=row.settingsFooterNote
                if note:GetParent()~=row then note:SetParent(row) end
                local title=row.settingsLabel
                local titled=title and row.settingsTitle and row.settingsTitle~=""
                if titled then
                    title:Show();title:ClearAllPoints();title:SetPoint("TOPLEFT",0,0);title:SetWidth(rowWidth)
                    title:SetTextColor(unpack(T.muted))
                end
                note:ClearAllPoints();note:SetPoint("TOPLEFT",0,titled and -20 or 0);note:SetWidth(math.max(1,rowWidth-8));note:SetWordWrap(true)
                note:SetTextColor(unpack(T.muted))
                local height=note:GetStringHeight()
                if (issecretvalue and issecretvalue(height)) or type(height)~="number" or height~=height or height<0 or height==math.huge then height=32 end
                row:SetHeight(math.max(14,height)+(titled and 20 or 0)+12)
                if row.divider then row.divider:Hide() end
            end
            row:SetShown(show)
            return show
        end
        -- Rows of one card sit inside it with padding; cards are separated by a
        -- gap and only drawn while at least one of their rows shows.
        local px = addon.Kit.PixelSize(content)
        local function Snap(value) return math.floor(value / px + 0.5) * px end
        local openCard
        -- A pairable stacked row waiting for a partner on its line: { row, top }.
        local half
        local inner = width - 2 * CARD_PADDING
        local halfWidth = Snap((inner - PAIR_GAP) / 2)
        local function FlushHalf()
            if half then cursor = Snap(half.top + half.row:GetHeight()); half = nil end
        end
        local function CloseCard()
            FlushHalf()
            if openCard then openCard.bottom = cursor; cursor = cursor + CARD_PADDING; openCard = nil end
        end
        for _, card in ipairs(self.cards) do card.top, card.bottom = nil, nil end
        for index, row in ipairs(self.rows) do
            if self.modeFooterLayout and row.settingsFooterNote and (not row.settingsFooterInlineWhen or not row.settingsFooterInlineWhen()) then footers[#footers+1]=row
            elseif row.card then
                -- Pairs: this row and the next visible one, both pairable, same card.
                -- (hidden rows between them are skipped; any other shown row ends the search).
                local pairNext
                if row.stacked and row.pairable and not half then
                    for j = index + 1, #self.rows do
                        local nextRow = self.rows[j]
                        if nextRow.card ~= row.card then break end
                        if Visible(nextRow) then pairNext = nextRow.stacked and nextRow.pairable or false; break end
                    end
                end
                local paired = half ~= nil and row.stacked and row.pairable
                local rowWidth = (paired or pairNext) and halfWidth or inner
                if Prepare(row,false,rowWidth) then
                    if row.card ~= openCard then
                        local wasCard = openCard ~= nil
                        CloseCard(); paired = false
                        cursor = Snap(cursor + ((wasCard or cursor > EDGE_ROOM) and CARD_GAP or 0))
                        openCard = row.card; openCard.top = cursor; cursor = cursor + CARD_PADDING
                        if row.divider then row.divider:Hide() end
                    elseif not paired then FlushHalf() end
                    row:ClearAllPoints()
                    if paired then
                        row:SetPoint("TOPLEFT", leftInset + CARD_PADDING + halfWidth + PAIR_GAP, -half.top)
                        row.offset = half.top
                        cursor = Snap(half.top + math.max(half.row:GetHeight(), row:GetHeight())); half = nil
                    else
                        row:SetPoint("TOPLEFT", leftInset + CARD_PADDING, -cursor)
                        row.offset = cursor
                        if pairNext then half = { row = row, top = cursor } else cursor = Snap(cursor + row:GetHeight()) end
                    end
                end
            elseif Prepare(row,false) then
                CloseCard()
                cursor = cursor + (row.gapBefore or 0)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", leftInset, -cursor)
                row.offset = cursor
                cursor = cursor + row:GetHeight() + (row.gapAfter or 4)
            end
        end
        CloseCard()
        for _, card in ipairs(self.cards) do
            local shown = card.top ~= nil
            card.frame:SetShown(shown)
            if shown then
                card.frame:ClearAllPoints()
                card.frame:SetPoint("TOPLEFT", leftInset, -card.top)
                card.frame:SetSize(width, card.bottom - card.top + CARD_PADDING)
            end
        end
        local visibleFooters,footerHeight={},0
        for _,row in ipairs(footers) do
            if Prepare(row,true) then visibleFooters[#visibleFooters+1]=row;footerHeight=footerHeight+row:GetHeight()+8 end
        end
        if #visibleFooters>0 then
            -- Short pages rest their notes at the bottom; long pages scroll
            -- naturally past controls. Never overlay fields or the toggle gutter.
            cursor=math.max(cursor+12,self.layoutMinHeight or 0,scroll:GetHeight()-footerHeight-12)
            for _,row in ipairs(visibleFooters) do
                row:ClearAllPoints();row:SetPoint("TOPLEFT",self.contentInset,-cursor);row.offset=cursor
                cursor=cursor+row:GetHeight()+8
            end
        end
        self.cursor = cursor
        content:SetHeight(math.max(cursor + 12,self.layoutMinHeight or 0))
        local maximum = math.max(0, content:GetHeight() - scroll:GetHeight())
        bar:SetMinMaxValues(0, maximum)
        bar:SetValue(math.min(bar:GetValue(), maximum))
        bar:SetShown(maximum > 0)
    end
    scroll:SetScript("OnSizeChanged", function() page:Layout() end)
    -- One failing control reports its error without leaving the rest blank.
    function page:Refresh()
        for _, refresh in ipairs(self.refreshers) do
            local ok, message = pcall(refresh)
            if not ok then geterrorhandler()(message) end
        end
        -- Wrapped text a refresher changed takes its new height.
        if self:IsShown() and W.SettingsTextChanged(self) then self:Layout() end
    end
    function page:FooterNote(note,inlineWhen)
        local row=note:GetParent().row
        assert(row,"ModeUI: footer notes must belong to a settings row.")
        row.settingsFooterNote=note
        row.settingsFooterInlineWhen=inlineWhen
        W.Note(note)
        if inlineWhen then
            local function Points(region)
                local out={};for i=1,region:GetNumPoints() do out[i]={region:GetPoint(i)} end;return out
            end
            local host,height,noteWidth=note:GetParent(),row:GetHeight(),note:GetWidth()
            local notePoints,labelPoints=Points(note),Points(row.settingsLabel)
            local labelWidth=row.settingsLabel:GetWidth()
            row.settingsFooterRestore=function()
                note:SetParent(host);note:ClearAllPoints();note:SetWidth(noteWidth)
                for _,point in ipairs(notePoints) do note:SetPoint(unpack(point)) end
                local label=row.settingsLabel;label:ClearAllPoints();label:SetWidth(labelWidth);label:SetTextColor(unpack(T.text))
                for _,point in ipairs(labelPoints) do label:SetPoint(unpack(point)) end
                row:SetHeight(height)
            end
        end
    end
    function page:SetSectionExpanded(section, expanded)
        section.expanded = expanded
        if expanded and self.sectionTabs then self:SelectSectionTab(section) end
        if section.button then section.button.label:SetText(expanded and "Collapse" or "Expand") end
        self:Layout()
        if addon.CloseTimerColorPicker then addon:CloseTimerColorPicker() end
        if addon.CloseFontDropdown then addon:CloseFontDropdown() end
    end
    function page:Reveal(entry)
        if entry.onReveal then entry.onReveal() end
        if entry.section then self:SetSectionExpanded(entry.section, true) end
        self:Layout()
        local row = entry.row
        if row and row:IsShown() then
            bar:SetValue(math.max(0, (row.offset or 0) - 8))
            if not row.searchHighlight then row.searchHighlight = W.Fill(row, T.primary, "OVERLAY", 1, 0.08) end
            row.searchHighlight:Show()
            row.searchEpoch = (row.searchEpoch or 0) + 1
            local epoch = row.searchEpoch
            C_Timer.After(1.5, function()
                if row.searchEpoch == epoch then row.searchHighlight:Hide() end
            end)
        end
    end
    function page:Section(title, description, collapsible)
        -- Modern separates sections with more air than rows, so each group
        -- reads as one block; Blizzard keeps its tighter stock rhythm.
        local sectionGap = T.blizzardArt and 24 or 32
        if self.cursor > 0 then self.cursor = self.cursor + sectionGap end
        local header = CreateFrame("Frame", nil, content)
        header:SetPoint("TOPLEFT", 0, -self.cursor)
        header:SetSize(400, description and 62 or 36)
        self.rows[#self.rows + 1] = header
        local section = { title = title, expanded = true, header = header }
        self.sections[#self.sections + 1] = section
        self.activeSection = section
        self.activeGroup = nil
        self.activeCard = nil
        header.section, header.sectionHeader = section, true
        header.gapBefore = #self.sections > 1 and sectionGap or 0
        self.searchEntries[#self.searchEntries + 1] = { label = title, section = section, row = header, kind = "section" }
        -- Plain heading on the canvas, above the cards of its rows.
        local heading = W.Heading(header, title, T.fontSize.section, 0, -8, 360, T.text)
        heading:SetPoint("TOPRIGHT", -92, -8)
        header.heading = heading
        if collapsible ~= false then
            section.button = W.Button(header, "Collapse", 76, 24, "secondary")
            section.button:SetPoint("TOPRIGHT", 0, -4)
            section.button:SetScript("OnClick", function() self:SetSectionExpanded(section, not section.expanded) end)
        end
        if description then
            local note = W.Label(header, description, nil, 0, -34, 360, T.muted)
            note:SetPoint("TOPRIGHT", -8, -34)
        end
        self.cursor = self.cursor + header:GetHeight()
        return section
    end
    -- height: nil or the old standard 48 is a standard 36 px row; other
    -- heights (notes, pickers, editors) are kept.
    -- plain: keep the label beside the control (toggle grids and columns lay
    -- out their own cells).
    function page:Row(title, height, keywords, plain)
        if height == nil or height == LEGACY_ROW_HEIGHT then height = ROW_HEIGHT end
        local stacked = height == ROW_HEIGHT and not plain
        if stacked then height = STACK_HEIGHT end
        local row = CreateFrame("Frame", nil, content)
        row:SetPoint("TOPLEFT", 0, -self.cursor)
        row:SetSize(400, height)
        local label = W.Label(row, title, nil, 0, -17, 172)
        label:SetWordWrap(true)
        local controls = CreateFrame("Frame", nil, row)
        if stacked then
            controls:SetPoint("TOPLEFT", 0, -STACK_LABEL)
            controls:SetPoint("BOTTOMRIGHT", 0, ROW_INSET)
            -- Where a slider puts its value: the right end of the label line.
            controls.valueAnchor = CreateFrame("Frame", nil, row)
            controls.valueAnchor:SetPoint("TOPRIGHT", 0, 0); controls.valueAnchor:SetSize(72, STACK_LABEL - 2)
            row.stacked = true
            function row:layoutChildren(width) label:SetWidth(math.max(40, width - 76)) end
        else
            controls:SetPoint("TOPLEFT", 184, -ROW_INSET)
            controls:SetPoint("BOTTOMRIGHT", -14, ROW_INSET)
            row.sideLabel = not plain
        end
        self.rows[#self.rows + 1] = row
        row.section = self.activeSection
        row.gapAfter = 0
        -- A module's Status line is internal reading, not a setting: hidden.
        if title == "Status" then row.settingsQuiet = true end
        row.card = self:ActiveCard()
        row:SetFrameLevel(content:GetFrameLevel() + 2)
        -- Labels sit over a stacked control, or on the row's middle beside it.
        label:ClearAllPoints()
        if stacked then
            label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2); label:SetHeight(STACK_LABEL - 4)
            label:SetWordWrap(false); label:SetTextColor(unpack(T.secondary))
        else label:SetPoint("LEFT", row, "LEFT", 0, 0) end
        if label.SetJustifyV then label:SetJustifyV("MIDDLE") end
        self.searchEntries[#self.searchEntries + 1] = { label = title, keywords = keywords, section = self.activeSection, row = row, kind = "setting" }
        controls.row, controls.rowLabel = row, label
        row.settingsHost,row.settingsLabel,row.settingsTitle,row.settingsGroup=controls,label,title,self.activeGroup
        row.modeFeature,row.modePanel=self.activeModeFeature,self.activeModePanel
        self.cursor = self.cursor + height + 4
        return controls
    end
    -- A card: a Mode Matte face (its base, no bar sheen) in the card color
    -- inside the `card` border.
    function page:NewCard(title)
        local frame = CreateFrame("Frame", nil, content)
        frame:SetFrameLevel(content:GetFrameLevel() + 1)
        local fill = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        fill:SetAllPoints()
        addon.Style.ApplyAsset(fill, "FGBase")
        fill:SetVertexColor(unpack(T.card))
        local edge = addon.Style.Edge(frame, "card")
        local card = { frame = frame, rim = edge.rimTexture, fill = fill, edge = edge, title = title }
        self.cards[#self.cards + 1] = card
        self.activeCard = card
        return card
    end
    function page:ActiveCard() return self.activeCard or self:NewCard() end
    -- Starts a card titled in large uppercase accent text (T.fontSize.card).
    function page:Group(title)
        local card = self:NewCard(title)
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(400, CARD_TITLE)
        row:SetFrameLevel(content:GetFrameLevel() + 2)
        row.section, row.gapBefore, row.gapAfter, row.card, row.cardTitle = self.activeSection, 0, 0, card, true
        row.subsectionHeading=W.Heading(row, title:upper(), T.fontSize.card, 0, -2, 360)
        row.subsectionHeading:SetTextColor(unpack(T.primary))
        row.settingsGroupTitle=title;self.activeGroup=title
        row.modeFeature,row.modePanel=self.activeModeFeature,self.activeModePanel
        self.rows[#self.rows + 1] = row
        self.cursor = self.cursor + CARD_TITLE
    end
    W.PageControls(page, ROW_HEIGHT)
    W.TabControls(page)
    function page:Finish()
        content:SetHeight(self.cursor + 12)
        self:Layout()
        self:Refresh()
    end
    return page
end

