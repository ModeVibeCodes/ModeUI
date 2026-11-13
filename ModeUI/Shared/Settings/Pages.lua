local _, addon = ...
local W, T = addon.ConfigWidgets, addon.InterfaceTheme
-- Settings are grouped on cards: soft-bordered ModeFlat panels with an accent
-- title (page:Group). Rows added outside a titled group share an untitled card.
local CARD_PADDING, CARD_GAP = 12, 12

-- The same responsive scrolling and row layout is used on every page.
function W.Page(parent, minimumWidth)
    local page = CreateFrame("Frame", nil, parent)
    page.modePillSections=T.id=="mode" and parent.modeMediaScope~=nil
    page:SetPoint("TOPLEFT", 0, -36)
    page:SetPoint("BOTTOMRIGHT")
    page.rows, page.refreshers, page.sections, page.searchEntries, page.cursor = {}, {}, {}, {}, 0
    page.cards = {}
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
        page.lastScrollValue=value;scroll:SetVerticalScroll(value)
    end)
    page.scrollbar = bar
    local function Wheel(_,delta) bar:SetValue(bar:GetValue()-delta*42) end
    scroll:SetScript("OnMouseWheel",Wheel)
    content:EnableMouseWheel(true);content:SetScript("OnMouseWheel",Wheel)
    page:EnableMouseWheel(true);page:SetScript("OnMouseWheel",Wheel)
    function page:Layout()
        local width = math.max(minimumWidth or 320, scroll:GetWidth() - 4)
        content:SetWidth(width)
        local leftInset=self.contentInset+(self.layoutInsetLeft or 0)
        width=math.max(1,width-leftInset-self.contentInset)
        local cursor = self.layoutTopInset or 0
        local footers={}
        local function Prepare(row,footer,innerWidth)
            if not footer and row.settingsFooterMoved and row.settingsFooterRestore then
                row.settingsFooterRestore();row.settingsFooterMoved=false
            end
            local rowWidth=footer and math.max(1,content:GetWidth()-self.contentInset*2) or innerWidth or width
            row:SetWidth(rowWidth)
            if row.layoutChildren then row:layoutChildren(rowWidth) end
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
            local show = row.sectionHeader or not row.section or row.section.expanded
            if self.sectionTabs then show = not row.sectionHeader and (not row.section or row.section == self.selectedSection) and (not row.section or row.section.expanded) end
            if self.ModeRowVisible then show=self:ModeRowVisible(row,show) end
            if row.visibleWhen then show=show and row.visibleWhen() end
            row:SetShown(show)
            return show
        end
        -- Rows of one card sit inside it with padding; cards are separated by a
        -- gap and only drawn while at least one of their rows shows.
        local px = addon.Kit.PixelSize(content)
        local function Snap(value) return math.floor(value / px + 0.5) * px end
        local openCard
        local function CloseCard()
            if openCard then openCard.bottom = cursor; cursor = cursor + CARD_PADDING; openCard = nil end
        end
        for _, card in ipairs(self.cards) do card.top, card.bottom = nil, nil end
        for _, row in ipairs(self.rows) do
            if self.modeFooterLayout and row.settingsFooterNote and (not row.settingsFooterInlineWhen or not row.settingsFooterInlineWhen()) then footers[#footers+1]=row
            elseif row.card then
                if row.card ~= openCard and Prepare(row,false,width-2*CARD_PADDING) then
                    local wasCard = openCard ~= nil
                    CloseCard()
                    cursor = Snap(cursor + (wasCard and CARD_GAP - CARD_PADDING or (cursor > 0 and CARD_GAP or 0)))
                    openCard = row.card; openCard.top = cursor; cursor = cursor + CARD_PADDING
                    if row.divider then row.divider:Hide() end
                    row:ClearAllPoints(); row:SetPoint("TOPLEFT", leftInset + CARD_PADDING, -cursor)
                    row.offset = cursor; cursor = Snap(cursor + row:GetHeight())
                elseif row.card == openCard and Prepare(row,false,width-2*CARD_PADDING) then
                    if row.divider then row.divider:Show() end
                    row:ClearAllPoints(); row:SetPoint("TOPLEFT", leftInset + CARD_PADDING, -cursor)
                    row.offset = cursor; cursor = Snap(cursor + row:GetHeight())
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
                addon.Kit.Inset(card.fill, card.frame, px)
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
    function page:Refresh()
        for _, refresh in ipairs(self.refreshers) do refresh() end
    end
    function page:FooterNote(note,inlineWhen)
        local row=note:GetParent().row
        assert(row,"ModeUI: footer notes must belong to a settings row.")
        row.settingsFooterNote=note
        row.settingsFooterInlineWhen=inlineWhen
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
        -- Plain heading on the canvas; rows below carry their own dividers.
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
    function page:Row(title, height, keywords)
        height = height or 52
        local row = CreateFrame("Frame", nil, content)
        row:SetPoint("TOPLEFT", 0, -self.cursor)
        row:SetSize(400, height)
        -- Rows sit directly on the canvas, separated by a single top hairline.
        row.divider = W.Fill(row, T.line, "BORDER")
        row.divider:ClearAllPoints(); row.divider:SetPoint("TOPLEFT"); row.divider:SetPoint("TOPRIGHT")
        row.divider:SetHeight(1)
        local label = W.Label(row, title, nil, 0, -17, 172)
        label:SetWordWrap(true)
        local controls = CreateFrame("Frame", nil, row)
        controls:SetPoint("TOPLEFT", 184, -10)
        controls:SetPoint("BOTTOMRIGHT", -14, 10)
        self.rows[#self.rows + 1] = row
        row.section = self.activeSection
        row.gapAfter = 0
        row.card = self:ActiveCard()
        row:SetFrameLevel(content:GetFrameLevel() + 2)
        -- Labels sit on the row's middle, level with the controls beside them.
        label:ClearAllPoints(); label:SetPoint("LEFT", row, "LEFT", 0, 0)
        if label.SetJustifyV then label:SetJustifyV("MIDDLE") end
        self.searchEntries[#self.searchEntries + 1] = { label = title, keywords = keywords, section = self.activeSection, row = row, kind = "setting" }
        controls.row, controls.rowLabel = row, label
        row.settingsHost,row.settingsLabel,row.settingsTitle,row.settingsGroup=controls,label,title,self.activeGroup
        row.modeFeature,row.modePanel=self.activeModeFeature,self.activeModePanel
        self.cursor = self.cursor + height + 4
        return controls
    end
    -- A card: a soft rim (ModeFlat in cardBorder) with the card fill one pixel inside.
    function page:NewCard(title)
        local frame = CreateFrame("Frame", nil, content)
        frame:SetFrameLevel(content:GetFrameLevel() + 1)
        local rim, fill = frame:CreateTexture(nil, "BACKGROUND", nil, 0), frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        for _, texture in ipairs({ rim, fill }) do
            if not addon.Media:ApplyTexture(texture, "ModeFlat") then texture:SetTexture(addon.Kit.FLAT) end
        end
        rim:SetAllPoints(); rim:SetVertexColor(unpack(T.cardBorder)); fill:SetVertexColor(unpack(T.card))
        local card = { frame = frame, rim = rim, fill = fill, title = title }
        self.cards[#self.cards + 1] = card
        self.activeCard = card
        return card
    end
    function page:ActiveCard() return self.activeCard or self:NewCard() end
    -- Starts a card titled in the accent color.
    function page:Group(title)
        local card = self:NewCard(title)
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(400, 28)
        row:SetFrameLevel(content:GetFrameLevel() + 2)
        row.section, row.gapBefore, row.gapAfter, row.card, row.cardTitle = self.activeSection, 0, 0, card, true
        local heading=title:gsub("(%a)([%w]*)",function(first,rest) return first:upper()..rest end)
        row.subsectionHeading=W.Heading(row, heading, T.fontSize.group, 0, -4, 360, T.primary)
        row.settingsGroupTitle=title;self.activeGroup=title
        row.modeFeature,row.modePanel=self.activeModeFeature,self.activeModePanel
        self.rows[#self.rows + 1] = row
        self.cursor = self.cursor + 28
    end
    -- One row of labeled cells side by side (sliders, choices, colors). Returns
    -- a control host per title; each host is laid out under its own label.
    function page:Columns(titles, height)
        local controls = self:Row("", height or 60)
        local row = controls.row
        controls.rowLabel:Hide()
        controls:ClearAllPoints(); controls:SetAllPoints(row)
        table.remove(self.searchEntries) -- replace the empty row metadata
        local cells, hosts = {}, {}
        for i, title in ipairs(titles) do
            local cell = CreateFrame("Frame", nil, controls)
            cell.label = W.Label(cell, title, nil, 0, -8, 200, T.secondary)
            local host = CreateFrame("Frame", nil, cell)
            host:SetPoint("TOPLEFT", 0, -28); host:SetPoint("BOTTOMRIGHT", 0, 6)
            host.row, host.rowLabel = row, cell.label
            cells[i], hosts[i] = cell, host
            self.searchEntries[#self.searchEntries + 1] = { label = title, section = self.activeSection, row = row, kind = "setting" }
        end
        function row:layoutChildren(width)
            local gap = 24
            local cellWidth = (width - gap * (#cells - 1)) / #cells
            for i, cell in ipairs(cells) do
                cell:ClearAllPoints(); cell:SetPoint("TOPLEFT", (i - 1) * (cellWidth + gap), 0)
                cell:SetSize(cellWidth, self:GetHeight()); cell.label:SetWidth(cellWidth)
            end
        end
        row.settingsColumns, row.settingsTitles = cells, titles
        return hosts
    end
    -- Full-cell click targets and per-setting search entries; wraps to 1-3 columns.
    function page:ToggleGrid(items, options)
        local controls = self:Row("", 38)
        local row = controls.row
        controls.rowLabel:Hide()
        controls:ClearAllPoints(); controls:SetAllPoints(row)
        local cells = {}
        table.remove(self.searchEntries) -- replace the empty row metadata
        for i, item in ipairs(items) do
            local cell = CreateFrame("Button", nil, controls)
            cell:EnableMouse(true); cell:RegisterForClicks("LeftButtonUp")
            local toggle = W.Button(cell, "", 30, 30, "checkbox")
            toggle:SetPoint("TOPLEFT", -7, -6)
            local label = W.Label(cell, item.label, nil, 28, -13, 120)
            label:SetWordWrap(true)
            local function Click() item.set(not item.get()); self:Refresh() end
            cell:SetScript("OnClick", Click); toggle:SetScript("OnClick", Click)
            -- The whole cell is the hit target, so hovering it lights the box too.
            cell:HookScript("OnEnter", function() toggle.hovered = true; toggle:RefreshAppearance() end)
            cell:HookScript("OnLeave", function() toggle.hovered = false; toggle:RefreshAppearance() end)
            self.refreshers[#self.refreshers + 1] = function() toggle:SetSelected(item.get()) end
            self.searchEntries[#self.searchEntries + 1] = {label=item.label,section=self.activeSection,row=row,kind="setting"}
            cells[i] = {frame=cell,button=toggle,label=label}
        end
        function row:layoutChildren(width)
            local columns = math.max(1, math.min(options and options.maxColumns or 3, #items, math.floor(width / (options and options.minimumCellWidth or 180))))
            local cellWidth = width / columns
            self:SetHeight(math.ceil(#items / columns) * 42)
            for i, cell in ipairs(cells) do
                cell.frame:ClearAllPoints(); cell.frame:SetSize(cellWidth, 42)
                cell.frame:SetPoint("TOPLEFT", ((i-1)%columns)*cellWidth, -math.floor((i-1)/columns)*42)
                cell.label:SetWidth(cellWidth-36)
            end
        end
        self.toggleGrids = self.toggleGrids or {}; self.toggleGrids[#self.toggleGrids+1] = cells
        row.settingsToggles=cells
        return cells
    end
    function page:Finish()
        content:SetHeight(self.cursor + 12)
        self:Layout()
        self:Refresh()
    end
    return page
end

