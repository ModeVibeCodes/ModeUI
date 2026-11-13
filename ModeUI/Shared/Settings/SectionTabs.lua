local _, addon = ...
local W, T = addon.ConfigWidgets, addon.InterfaceTheme

-- Text tabs, 34 px tall, on one hairline: the chosen tab is in the text color
-- with a 2 px accent underline, the others muted.
local TAB_HEIGHT, TAB_PADDING, TAB_GAP = 34, 14, 4

-- Session-only presentation of existing section/row metadata, also used by search.
function W.SectionTabs(page, order)
    if page.sectionTabs or #page.sections < 2 then return end
    local sections = {}
    if order then
        for _, title in ipairs(order) do
            for _, section in ipairs(page.sections) do if section.title == title then sections[#sections+1] = section end end
        end
    else for _, section in ipairs(page.sections) do sections[#sections+1] = section end end
    assert(#sections == #page.sections, "ModeUI: settings tabs must include every section.")
    local strip = CreateFrame("Frame", nil, page)
    strip:SetHeight(TAB_HEIGHT + 1)
    strip:SetPoint("TOPLEFT"); strip:SetPoint("TOPRIGHT", -24, 0)
    -- The tabs rest on one hairline across the strip.
    strip.baseline = W.Shape(strip, nil, "BACKGROUND")
    strip.baseline:SetVertexColor(unpack(T.line))
    strip.baseline:SetPoint("BOTTOMLEFT", 0, 0); strip.baseline:SetPoint("BOTTOMRIGHT", 0, 0)
    strip.baseline:SetHeight(1)
    local viewport = CreateFrame("ScrollFrame", nil, strip)
    viewport:SetPoint("TOPLEFT", 0, 0); viewport:SetPoint("BOTTOMRIGHT", 0, 0)
    local content = CreateFrame("Frame", nil, viewport); content:SetSize(1, TAB_HEIGHT + 1); viewport:SetScrollChild(content)
    local left = W.Button(strip, "<", 26, 28, "secondary"); left:SetPoint("LEFT")
    local right = W.Button(strip, ">", 26, 28, "secondary"); right:SetPoint("RIGHT")
    strip.buttons, strip.sections, strip.viewport = {}, sections, viewport
    strip.previousButton, strip.nextButton = left, right
    left:Hide(); right:Hide() -- overflow remains mouse-wheel/automatic, without visible indicators
    local offset = 0
    function strip:Scroll(value)
        offset = math.max(0, math.min(self.maximum or 0, value))
        viewport:SetHorizontalScroll(offset)
        left:SetEnabled(offset > 0); right:SetEnabled(offset < (self.maximum or 0))
    end
    function strip:Layout()
        local x = 0
        for i, section in ipairs(sections) do
            local button = self.buttons[i]
            button.label:SetWidth(0)
            local measured = button.label:GetStringWidth()
            if (issecretvalue and issecretvalue(measured)) or type(measured) ~= "number" or measured~=measured or measured<0 or measured==math.huge then measured = #section.title * 8 end
            local width = math.max(64, math.ceil(measured) + 2 * TAB_PADDING)
            button:ClearAllPoints(); button:SetPoint("TOPLEFT", x, 0); button:SetSize(width, TAB_HEIGHT)
            button.label:SetWidth(width - 2 * TAB_PADDING + 4); button.label:SetWordWrap(false)
            W.AlignTextLine(button, button.underline)
            button.tabX, button.tabWidth = x, width
            x = x + width + TAB_GAP
        end
        content:SetWidth(x)
        self.maximum = math.max(0, x - viewport:GetWidth())
        self:Scroll(offset)
        for i,section in ipairs(sections) do
            if page.selectedSection==section then
                local button=self.buttons[i]
                if button.tabX<offset then self:Scroll(button.tabX)
                elseif button.tabX+button.tabWidth>offset+viewport:GetWidth() then self:Scroll(button.tabX+button.tabWidth-viewport:GetWidth()) end
            end
        end
    end
    function page:SelectSectionTab(section)
        if type(section) == "number" then section = sections[section] end
        if not section then return end
        self.selectedSection = section; section.expanded = true
        for i, item in ipairs(sections) do
            local active = item == section
            strip.buttons[i]:SetSelected(active); strip.buttons[i].underline:SetShown(active)
            if active then
                local button = strip.buttons[i]
                if button.tabX and button.tabX < offset then strip:Scroll(button.tabX)
                elseif button.tabX and button.tabX + button.tabWidth > offset + viewport:GetWidth() then
                    strip:Scroll(button.tabX + button.tabWidth - viewport:GetWidth())
                end
            end
        end
        self.scrollbar:SetValue(0)
        if self.OnSectionTabChanged then self:OnSectionTabChanged(section) end
        self:Layout()
        if addon.CloseTimerColorPicker then addon:CloseTimerColorPicker() end
        if addon.CloseFontDropdown then addon:CloseFontDropdown() end
    end
    for i, section in ipairs(sections) do
        local button = W.Button(content, section.title, 100, TAB_HEIGHT, "underline")
        button.underline = button.selectionEdge
        button.underline:Hide()
        button:SetScript("OnClick", function() page:SelectSectionTab(section) end)
        strip.buttons[i] = button
    end
    left:SetScript("OnClick", function() strip:Scroll(offset - 160) end)
    right:SetScript("OnClick", function() strip:Scroll(offset + 160) end)
    viewport:EnableMouseWheel(true); viewport:SetScript("OnMouseWheel", function(_, delta) strip:Scroll(offset - delta * 100) end)
    strip:SetScript("OnSizeChanged", function() strip:Layout() end)
    page.sectionTabs = strip
    addon.Media:RegisterFontListener(strip, function(owner) owner:Layout() end)
    strip:Layout()
    page:SelectSectionTab(1)
    if page.UpdatePreviewLayout then page:UpdatePreviewLayout() end
end

-- Section tabs pinned above the page's scroll area. Pages
-- without a Preview layer use this to reserve the tab strip's height.
function W.PinnedSectionTabs(page)
    W.SectionTabs(page)
    if not page.sectionTabs then return end
    page.sectionTabs:ClearAllPoints(); page.sectionTabs:SetPoint("TOPLEFT"); page.sectionTabs:SetPoint("TOPRIGHT", -24, 0)
    local top = page.sectionTabs:GetHeight() + 12
    page.scroll:ClearAllPoints(); page.scroll:SetPoint("TOPLEFT", 0, -top); page.scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    page.scrollbar:ClearAllPoints(); page.scrollbar:SetPoint("TOPRIGHT", -4, -top - 4); page.scrollbar:SetPoint("BOTTOMRIGHT", -4, 4)
    page.tabContentTop = top
end
