local _, addon = ...
local W, T = addon.ConfigWidgets, addon.InterfaceTheme

local function View(module, parent, context)
    local view = module:CreateConfigPreview(parent,context)
    addon.PreviewStates:RegisterView(module.id,view)
    addon.Media:RegisterFontListener(view, function(display) display:Refresh() end)
    if module.usesBorders then addon.Media:RegisterBorderListener(view, function(display) display:Refresh() end) end
    parent.previewViews = parent.previewViews or {}
    parent.previewViews[#parent.previewViews + 1] = view
    parent:SetScript("OnSizeChanged", function()
        for _, display in ipairs(parent.previewViews) do if display.frame:IsShown() then display:Refresh() end end
    end)
    return view
end

-- The module preview. On a sidebar page it is a fixed header/body above the
-- section tabs and scrolling settings; in split view (the window passes its
-- preview pane as the page host's modeSplitPane) it fills the live preview
-- pane beside the settings column, under a "Live preview" title.
function W.Preview(page, module, options)
    if not module.CreateConfigPreview then return end
    local pane = page:GetParent() and page:GetParent().modeSplitPane
    page:ClearAllPoints();page:SetPoint("TOPLEFT");page:SetPoint("BOTTOMRIGHT")
    local area=CreateFrame("Frame",nil,pane or page)
    local paneTitle
    if pane then
        page.previewSplit = true
        area:SetPoint("TOPLEFT", pane, "TOPLEFT", 14, -14); area:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -14, 14)
        area:Hide()
        page:HookScript("OnShow", function() area:Show() end)
        page:HookScript("OnHide", function() area:Hide() end)
        paneTitle = W.Label(area, "LIVE PREVIEW", nil, 0, -10, 100, T.secondary)
        addon.Media:BindInterfaceFont(paneTitle, GameFontHighlight, T.fontSize.card, nil, "heading")
        page.previewPaneTitle = paneTitle
    else
        area:SetPoint("TOPLEFT"); area:SetPoint("TOPRIGHT",-24,0)
    end
    local height=(options and (options.contentHeight or options.squareSize)) or 136
    local headerHeight=46
    area:SetHeight(height)
    local body=CreateFrame("Frame",nil,area)
    body:SetPoint("TOPLEFT",0,-headerHeight); body:SetPoint("BOTTOMRIGHT")
    local title=W.Label(area,"Preview",nil,0,0,1,T.secondary);title:Hide()
    page.previewTitle=title
    local collapse=W.Button(area,"Collapse",78,24,"secondary")
    local test=W.Button(area,"Test on Screen",100,24,"choice")
    local static=W.Button(area,"Static",64,24,"choice")
    local animated=W.Button(area,"Animated",78,24,"choice")
    animated:SetShown(addon.PreviewStates:CanAnimate(module.id) and true or false)
    -- Only modules that can draw on screen outside the window offer the test.
    test:SetShown(module.SetTestDisplay ~= nil)
    local function Mode(mode)
        addon.PreviewStates:SetPreviewMode(module.id,mode)
        page:UpdatePreviewLayout()
    end
    static:SetScript("OnClick",function() Mode("static") end)
    animated:SetScript("OnClick",function() Mode("animated") end)
    page.staticPreviewButton,page.animatedPreviewButton=static,animated
    local viewport=CreateFrame("Frame",nil,body)
    viewport:SetPoint("TOPLEFT",12,-2); viewport:SetPoint("BOTTOMRIGHT",-12,10)
    local display=View(module,viewport,"embedded")
    page.previewArea,page.previewBody,page.previewViewport=area,body,viewport
    page.testDisplayButton,page.previewCollapseButton=test,collapse
    page.configPreview,page.previewExpandedHeight=display,height
    page.previewContextButtons={}
    function page:UpdatePreviewLayout()
        if self.updatingPreview then return end
        self.updatingPreview=true
        -- Keep the top right clear (previewReserveRight: a page's own control
        -- there). Wrap only on narrow layouts. previewHeaderButtons are the
        -- page's own buttons, placed after the standard ones.
        local available=math.max(180,area:GetWidth()-(self.previewReserveRight or 90))
        local x,y=pane and 104 or 0,-6
        local buttons={static,animated,test,collapse}
        for _,button in ipairs(self.previewHeaderButtons or {}) do buttons[#buttons+1]=button end
        for _,button in ipairs(buttons) do
            if button==collapse and pane then button:Hide()
            elseif (button~=animated or addon.PreviewStates:CanAnimate(module.id)) and (button~=test or module.SetTestDisplay) then
                button:SetWidth(math.max(button:GetWidth(),math.ceil(button.label:GetStringWidth())+12))
                if x>(pane and 104 or 0) and x+button:GetWidth()>available then x,y=pane and 104 or 0,y-30 end
                button:ClearAllPoints();button:SetPoint("TOPLEFT",x,y);x=x+button:GetWidth()+4
            end
        end
        headerHeight=math.max(46,-y+30)
        if #self.previewContextButtons>0 then
            x=0;y=y-30
            for _,button in ipairs(self.previewContextButtons) do
                button:SetSize(math.max(104,math.ceil(button.label:GetStringWidth())+12),24)
                button:ClearAllPoints();button:SetPoint("TOPLEFT",area,"TOPLEFT",x,y);x=x+button:GetWidth()+4
            end
            title:ClearAllPoints();title:SetPoint("TOPLEFT",x+4,y-5);title:SetWidth(math.max(80,available-x-8));title:Show()
            headerHeight=headerHeight+30
        end
        body:ClearAllPoints();body:SetPoint("TOPLEFT",0,-headerHeight);body:SetPoint("BOTTOMRIGHT")
        local external=module.testing
        local collapsed=external or (not pane and (self.previewSectionCollapsed or self.previewManualCollapsed)) or false
        self.previewCollapsed=collapsed and true or false
        if module.GetPreviewSize then
            local width,bodyHeight=module:GetPreviewSize(display)
            viewport:ClearAllPoints();viewport:SetPoint("TOP",body,"TOP",0,-6)
            viewport:SetSize(math.min(width,math.max(80,area:GetWidth()-24)),bodyHeight)
            self.previewExpandedHeight=headerHeight+bodyHeight+6
        end
        local h=collapsed and headerHeight or math.max(headerHeight+32,self.previewExpandedHeight)
        if pane then h=0 else area:SetHeight(h) end
        body:SetShown(not collapsed)
        collapse.label:SetText(collapsed and "Expand" or "Collapse")
        collapse:SetEnabled(not self.previewSectionCollapsed)
        static:SetSelected(addon.PreviewStates:PreviewMode(module.id)=="static")
        animated:SetSelected(addon.PreviewStates:PreviewMode(module.id)=="animated")
        local safe=not (InCombatLockdown() or UnitAffectingCombat("player"))
        static:SetEnabled(safe);animated:SetEnabled(safe)
        test:SetSelected(module.testing==true)
        local permitted=module.SetTestDisplay and module.active and not (InCombatLockdown() or UnitAffectingCombat("player") or addon.editMode or addon.previewMode)
        if module.CanTestDisplay then permitted=module:CanTestDisplay() end
        test:SetEnabled(module.testing==true or permitted==true)
        local top=pane and 0 or h+12
        if self.sectionTabs then
            local tabsTop=pane and 0 or h+6
            self.sectionTabs:ClearAllPoints(); self.sectionTabs:SetPoint("TOPLEFT",0,-tabsTop)
            self.sectionTabs:SetPoint("TOPRIGHT",-24,-tabsTop)
            top=tabsTop+self.sectionTabs:GetHeight()+12
        end
        if self.LayoutSectionPanel then top=self:LayoutSectionPanel(top) end
        self.scroll:ClearAllPoints(); self.scroll:SetPoint("TOPLEFT",0,-top); self.scroll:SetPoint("BOTTOMRIGHT",-24,0)
        self.scrollbar:ClearAllPoints(); self.scrollbar:SetPoint("TOPRIGHT",-4,-top-4); self.scrollbar:SetPoint("BOTTOMRIGHT",-4,4)
        self:Layout()
        addon.PreviewStates:UpdateDriver()
        self.updatingPreview=false
    end
    function page:AddPreviewContext(button)
        self.previewContextButtons[#self.previewContextButtons+1]=button
        self:UpdatePreviewLayout()
    end
    collapse:SetScript("OnClick",function()
        if page.previewSectionCollapsed then return end
        if page.previewCollapsed then
            page.previewManualCollapsed=false
            addon:SetModulePreviewLocation(module,"embedded")
        else page.previewManualCollapsed=true end
        page:UpdatePreviewLayout()
    end)
    test:SetScript("OnClick",function()
        addon:SetModulePreviewLocation(module,module.testing and "embedded" or "screen")
    end)
    page.refreshers[#page.refreshers+1]=function()
        display:Refresh()
        page:UpdatePreviewLayout()
    end
    page:UpdatePreviewLayout()
    area:SetScript("OnSizeChanged",function() page:UpdatePreviewLayout() end)
    return display
end

function addon:RefreshModulePreviewLayout()
    if not self.configWindow then return end
    for _,page in pairs(self.configWindow.pages) do if page.UpdatePreviewLayout then page:UpdatePreviewLayout() end end
end

-- Change only presentation location. Mode and elapsed phase belong to PreviewStates.
function addon:SetModulePreviewLocation(module,location)
    if not module or not module.CreateConfigPreview or (location~="embedded" and location~="screen") then return false end
    if InCombatLockdown() or UnitAffectingCombat("player") then return false end
    if location=="screen" then
        if not module.SetTestDisplay or not module:SetTestDisplay(true) then return false end
    elseif module.testing then module:SetTestDisplay(false) end
    self:RefreshModulePreviewLayout()
    return true
end
