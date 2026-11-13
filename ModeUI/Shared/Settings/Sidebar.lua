local _, addon = ...
local W, T = addon.ConfigWidgets, addon.InterfaceTheme

-- The settings sidebar: category headings, the modules nested under them and,
-- in the Mode theme, collapsing a category. Captions are small uppercase
-- faint text; module rows are 30 px, the chosen one filled with an accent bar
-- on its left edge. Built once by addon:CreateConfig.
-- ctx: window, sidebar, navigation, navigationButtons, collapsed, mode, edge,
-- sidebarWidth, Select(id) and Selected() from the window.
-- Returns RefreshSidebar(category, id).
function addon:BuildConfigSidebar(ctx)
    local window, sidebar, navigation = ctx.window, ctx.sidebar, ctx.navigation
    local navigationButtons, collapsed = ctx.navigationButtons, ctx.collapsed
    local mode, edge, sidebarWidth, Select = ctx.mode, ctx.edge, ctx.sidebarWidth, ctx.Select
    local RefreshSidebar
    local function AddNavigation(id, label, developer)
        local isHeading = mode and self.categories[id] ~= nil
        local button = W.Button(developer and sidebar or navigation.content, isHeading and label:upper() or label,
            developer and sidebarWidth - 22 - edge or 184, isHeading and 28 or 30, isHeading and "categoryHeading" or "tab")
        button.categoryID = isHeading and id or nil
        if developer then button:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 0, 0)
        else button:SetPoint("TOPLEFT", 0, -navigation.cursor) end
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", 12, 0)
        button.label:SetPoint("RIGHT", -54, 0)
        button.label:SetJustifyH("LEFT")
        if mode then
            button.modeLeftAligned=true
            button.label:ClearAllPoints()
            button.label:SetPoint("LEFT", 10, 0)
            button.label:SetPoint("RIGHT", -10, 0)
            button.label:SetWordWrap(false)
            addon.Media:BindInterfaceFont(button.label, GameFontHighlight, isHeading and T.fontSize.group or T.fontSize.body, nil, isHeading and "heading" or nil)
            if isHeading then button.gapBefore, button.gapAfter = 12, 2 end
        end
        button:SetScript("OnClick", function()
            if isHeading then
                collapsed[id] = not collapsed[id]
                RefreshSidebar(self.categories[window.selectedCategory], ctx.Selected())
            else Select(id) end
        end)
        if self.modules[id] and not self.modules[id].developer then
            button.status = W.Label(button, "", nil, 0, 0, 24, T.muted)
            button.status:ClearAllPoints()
            button.status:SetPoint("RIGHT", -10, 0)
            button.status:SetJustifyH("RIGHT")
            addon.Media:BindInterfaceFont(button.status, GameFontHighlight, T.fontSize.small)
        end
        navigationButtons[id] = button
        if not developer then
            navigation.rows[#navigation.rows + 1] = button
            navigation.cursor = navigation.cursor + 36
        else
            navigation:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, 12)
            local line = W.Fill(sidebar, T.line, "ARTWORK")
            line:ClearAllPoints(); line:SetPoint("BOTTOMLEFT", 0, 40); line:SetPoint("BOTTOMRIGHT", 0, 40); line:SetHeight(1)
        end
    end
    local sidebarRoots = {}
    for _, id in ipairs(self.categoryOrder) do
        if #self.categories[id].modules > 0 then AddNavigation(id, self.categories[id].title) end
    end
    for _, id in ipairs(self.moduleOrder) do
        if not self.modules[id].developer and not self.modules[id].category then AddNavigation(id, self.modules[id].title) end
    end
    for _, id in ipairs(self.moduleOrder) do
        if self.modules[id].developer then AddNavigation(id, self.modules[id].title, true) end
    end
    for _,row in ipairs(navigation.rows) do sidebarRoots[#sidebarRoots+1]=row end
    local nested = {}
    window.sidebarModuleButtons = nested
    local function NestedButton(id)
        if nested[id] then return nested[id] end
        local module=addon.modules[id]
        local title = module.tabTitle or module.title
        local button=W.Button(navigation.content,mode and ("· " .. title) or title,184,mode and 30 or 28,"tab")
        button.gapAfter=2
        button.modeLeftAligned=mode
        button.atelierNested=true
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT",mode and 16 or 24,0)
        if module.classIcon then
            button.classIcon=button:CreateTexture(nil,"ARTWORK");button.classIcon:SetPoint("LEFT",24,0);button.classIcon:SetSize(18,18);button.classIcon:SetTexture(module.classIcon)
            button.label:ClearAllPoints();button.label:SetPoint("LEFT",48,0)
        end
        button.label:SetPoint("RIGHT",-10,0)
        button.label:SetJustifyH("LEFT")
        if mode then button.label:SetWordWrap(false) end
        addon.Media:BindInterfaceFont(button.label,GameFontHighlight,mode and T.fontSize.body or T.fontSize.small)
        if mode and module.classIcon then
            -- Keep class identity while giving every child the same dot prefix.
            button.classIcon:ClearAllPoints();button.classIcon:SetPoint("RIGHT",-8,0)
            button.label:ClearAllPoints();button.label:SetPoint("LEFT",16,0);button.label:SetPoint("RIGHT",-32,0)
        end
        if mode then
            -- Measure against a separate unbounded label: the visible label's
            -- anchors must stay intact, and truncation must not hide its width.
            local probe=navigation.fontProbe
            if not probe then
                probe=navigation:CreateFontString(nil,"OVERLAY","GameFontHighlight")
                probe:Hide();probe:SetWidth(0);probe:SetWordWrap(false);navigation.fontProbe=probe
            end
            function button:FitNavigationText()
                addon.Media:BindInterfaceFont(probe,GameFontHighlight,T.fontSize.body)
                probe:SetText(self.label:GetText())
                local measured=probe:GetStringWidth()
                local available=math.max(1,self:GetWidth()-(module.classIcon and 48 or 26))
                local size=T.fontSize.body
                if not (issecretvalue and issecretvalue(measured)) and type(measured)=="number" and measured>available and measured<math.huge then
                    size=math.max(1,math.floor(size*available/measured*4)/4)
                end
                addon.Media:BindInterfaceFont(self.label,GameFontHighlight,size)
                W.AlignTextLine(self,self.selectionEdge)
            end
            button:HookScript("OnSizeChanged",function(owner) owner:FitNavigationText() end)
            addon.Media:RegisterFontListener(button,function(owner) owner:FitNavigationText() end)
        end
        button:SetScript("OnClick",function() Select(id) end)
        nested[id]=button
        return button
    end
    RefreshSidebar=function(category,id)
        for _,button in pairs(nested) do button:Hide() end
        navigation.rows={}
        for _,root in ipairs(sidebarRoots) do
            navigation.rows[#navigation.rows+1]=root
            local group = mode and root.categoryID and self.categories[root.categoryID] or nil
            local expanded = mode and group and not collapsed[group.id]
            if mode and group then root.expanded = expanded == true end
            if expanded or (not mode and category and root==navigationButtons[category.id]) then
                for _,moduleID in ipairs((group or category).modules) do
                    local button=NestedButton(moduleID)
                    button:SetSelected(moduleID==id)
                    navigation.rows[#navigation.rows+1]=button
                end
            end
        end
        navigation:Layout()
        if mode then for _,button in pairs(nested) do if button:IsShown() then button:FitNavigationText() end end end
        -- Reveal the clicked/search-routed module in the same existing scroll view.
        local button=nested[id]
        if button and category and (not mode or not collapsed[category.id]) then
            local offset=button.offset or 0
            local value=navigation.scrollbar:GetValue()
            local visible=navigation.scroll:GetHeight()
            if offset<value then navigation.scrollbar:SetValue(offset)
            elseif offset+button:GetHeight()>value+visible then navigation.scrollbar:SetValue(offset+button:GetHeight()-visible) end
        end
    end
    return RefreshSidebar
end
