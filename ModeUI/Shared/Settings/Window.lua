local _, addon = ...
local W, T = addon.ConfigWidgets, addon.InterfaceTheme
local WINDOW_WIDTH, WINDOW_HEIGHT = 1120, 760
local SIDEBAR_WIDTH, HEADER_HEIGHT = 240, 56
-- Reserve the reload control as well as Preview/Edit/Close for safe dragging.
local HEADER_RESERVED = 360 + 24 + 16

local InCombat = addon.InCombat
-- An open window shows a module's new on/off state at once.
addon.RegisterMessage("ModeUI.SettingsWindow", addon.Messages.MODULE_TOGGLED, function()
    if addon.RefreshConfig then addon:RefreshConfig() end
end)
function addon:RecoverWindowPosition()
    local window=self.configWindow
    if not window or InCombat() then return false end
    local ratio=window:GetEffectiveScale()/UIParent:GetEffectiveScale()
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    local w,h=window:GetWidth()*ratio,window:GetHeight()*ratio
    local keep=math.min(40,width/4,height/4)
    -- Retain a draggable header fragment, not the full window rectangle.
    local minX=-width/2-w/2+(window.headerReserved or HEADER_RESERVED)*ratio+keep
    local maxX=width/2+w/2-keep
    local minY=-height/2-h/2+keep
    local maxY=height/2-h/2+HEADER_HEIGHT*ratio-keep
    self.root.window.x=math.max(minX,math.min(maxX,self.root.window.x))
    self.root.window.y=math.max(minY,math.min(maxY,self.root.window.y))
    return true
end
function addon:ResetConfigWindowPosition()
    if InCombat() then print("ModeUI: reset the configuration window outside combat.");return false end
    self:FinishWindowInteraction()
    self.root.window.x,self.root.window.y=0,0
    if not self.configWindow then self:CreateConfig() end
    self:UpdateWindowBounds();self.configWindow:Show();return true
end

function addon:FinishWindowInteraction()
    local window = self.configWindow
    if not window or not window.moving then return end
    window:StopMovingOrSizing()
    window.moving = false
    local ratio = window:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = window:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if x and y and parentX and parentY then
        self.root.window.x, self.root.window.y = x * ratio - parentX, y * ratio - parentY
    end
    if InCombat() then
        addon.Defer:Queue("settings:bounds", function() addon:UpdateWindowBounds() end)
    else
        self:RecoverWindowPosition()
        window:ClearAllPoints()
        window:SetPoint("CENTER", UIParent, "CENTER", self.root.window.x / ratio, self.root.window.y / ratio)
    end
end

function addon:UpdateWindowBounds(initial)
    local window = self.configWindow
    if not window then return end
    if InCombat() and not initial then addon.Defer:Queue("settings:bounds", function() addon:UpdateWindowBounds() end); return end
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    -- Legacy saved dimensions are intentionally ignored and left untouched.
    local scale = math.min(1, math.max(1, width - 32) / WINDOW_WIDTH, math.max(1, height - 32) / WINDOW_HEIGHT)
    window:SetScale(scale)
    window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    if not InCombat() then self:RecoverWindowPosition() end
    window:ClearAllPoints()
    window:SetPoint("CENTER", UIParent, "CENTER", self.root.window.x / scale, self.root.window.y / scale)
end

local function GenericPage(parent, module)
    local page = W.Page(parent)
    page:Finish()
    return page
end

function addon:CreateConfig()
    local mode = T.id == "mode"
    local sidebarWidth=SIDEBAR_WIDTH
    local window = CreateFrame("Frame", "ModeUIConfigWindow", UIParent)
    window:Hide()
    self.configWindow = window
    window.sidebarWidth=sidebarWidth
    window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:SetClampedToScreen(false)
    window:EnableMouse(true)
    -- Flat app shell: a canvas, a full-height sidebar column and one hairline frame.
    window.canvas = W.Fill(window, T.background, "BACKGROUND")
    if mode then window.canvasSheen=W.ModeSheen(window) end
    window.border = W.Outline(window, T.lineStrong, "OVERLAY")
    if mode then window.border:SetShown(false) end
    -- Sublevel 1 keeps the column above the canvas within the same draw layer.
    local column = window:CreateTexture(nil, "BACKGROUND", nil, 1)
    W.Paint(column, T.sidebar)
    column:SetPoint("TOPLEFT", 1, -1); column:SetPoint("BOTTOMLEFT", 1, 1)
    column:SetWidth(sidebarWidth)
    if mode then
        column.modeAsset="ModeSurface";W.Paint(column,T.sidebar)
        column:ClearAllPoints();column:SetPoint("TOPLEFT",8,-8);column:SetPoint("BOTTOMLEFT",8,8)
        column:SetWidth(sidebarWidth-8)
    end
    local columnEdge = W.Fill(window, T.line, "BORDER")
    columnEdge:ClearAllPoints(); columnEdge:SetPoint("TOPLEFT", sidebarWidth + 1, -1)
    columnEdge:SetPoint("BOTTOMLEFT", sidebarWidth + 1, 1); columnEdge:SetWidth(1)
    if mode then columnEdge:Hide() end
    window.columnEdge=columnEdge
    window.sidebarColumn = column
    -- Blizzard theme: the stock dialog box replaces the canvas and hairline
    -- frame; the sidebar column and its edge sit inside the dialog border.
    if T.blizzardArt and W.BlizzardBackdrop(window, "dialog") then
        -- The stock dialog stone is partly transparent, so it sits on an
        -- opaque canvas held inside the border.
        window.border:SetShown(false)
        local canvas = window.canvas
        canvas:ClearAllPoints()
        canvas:SetPoint("TOPLEFT", 11, -12); canvas:SetPoint("BOTTOMRIGHT", -12, 11)
        W.Paint(canvas, T.background, 1)
        if canvas.SetDrawLayer then canvas:SetDrawLayer("BACKGROUND", -2) end
        local stone = window:CreateTexture(nil, "BACKGROUND", nil, -1)
        stone:SetAllPoints(canvas)
        if stone.SetHorizTile and stone:SetTexture(W.BlizzardArt.dialogBackground, "REPEAT", "REPEAT") ~= false then
            stone:SetHorizTile(true); stone:SetVertTile(true)
        else stone:Hide() end
        window.blizzardStone = stone
        column:ClearAllPoints()
        column:SetPoint("TOPLEFT", 11, -12); column:SetPoint("BOTTOMLEFT", 11, 11)
        column:SetWidth(SIDEBAR_WIDTH - 10)
        columnEdge:ClearAllPoints(); columnEdge:SetPoint("TOPLEFT", SIDEBAR_WIDTH + 1, -12)
        columnEdge:SetPoint("BOTTOMLEFT", SIDEBAR_WIDTH + 1, 11); columnEdge:SetWidth(1)
    end

    -- The stock dialog border is about 12px deep; Blizzard content keeps a
    -- clear margin inside it instead of sitting on its inner edge.
    local edge = window.blizzardBackdrop and 8 or 0

    -- A non-interactive header owns disjoint drag and button regions.
    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER_HEIGHT)
    header:SetFrameLevel(window:GetFrameLevel() + 10)
    header:EnableMouse(false)
    window.headerArt = W.Fill(header, T.line, "BORDER")
    window.headerArt:ClearAllPoints()
    window.headerArt:SetPoint("BOTTOMLEFT", sidebarWidth + 2, 0); window.headerArt:SetPoint("BOTTOMRIGHT", -1, 0)
    window.headerArt:SetHeight(1)
    if mode then window.headerArt:Hide() end
    window.title = W.Heading(header, "ModeUI", T.fontSize.section, 20 + edge, -21, sidebarWidth - 24 - edge, mode and T.heading or T.text)
    if mode then
        window.title:SetTextColor(unpack(T.primary))
        local logo=header:CreateTexture(nil,"ARTWORK")
        logo:SetPoint("LEFT",14,0);logo:SetSize(38,38)
        addon.Media:ApplyTexture(logo,"ModeLogo")
        window.brandLogo=logo
        window.title:ClearAllPoints();window.title:SetPoint("LEFT",logo,"RIGHT",8,0)
        window.title:SetWidth(sidebarWidth-72)
    end
    window.title:SetWordWrap(false)
    local controls = CreateFrame("Frame", nil, header)
    controls:SetPoint("TOPRIGHT", -16 - edge, -14 - edge / 2)
    controls:SetSize(360, 28)
    window.headerReserved=HEADER_RESERVED
    controls:SetFrameLevel(header:GetFrameLevel() + 1)
    controls:EnableMouse(false)
    function self:UpdateConfigTitle(id)
        -- The brand stays fixed; the page header below names the current page.
        window.title:SetText("ModeUI")
    end
    local drag = CreateFrame("Frame", nil, header)
    drag:SetPoint("TOPLEFT")
    drag:SetPoint("BOTTOMRIGHT", controls, "BOTTOMLEFT", -16, -14)
    drag:SetFrameLevel(header:GetFrameLevel() + 1)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        if InCombat() then return end
        window.moving = true
        window:StartMoving()
    end)
    drag:SetScript("OnDragStop", function() self:FinishWindowInteraction() end)
    window.header, window.headerBar, window.headerControls = drag, header, controls
    local function HeaderButton(label, width)
        local button = W.Button(controls, label, width, 28, "secondary")
        button:SetFrameLevel(controls:GetFrameLevel() + 1)
        button:EnableMouse(true)
        button:RegisterForClicks("LeftButtonUp")
        return button
    end
    local close = HeaderButton("X", 28)
    close:SetPoint("RIGHT")
    close:SetScript("OnClick", function() window:Hide() end)
    local edit = HeaderButton("Edit Mode", 92)
    edit:SetPoint("RIGHT", close, "LEFT", -16, 0)
    edit:SetScript("OnClick", function() self:SetEditMode(not self.editMode) end)
    local preview = HeaderButton("Preview", 80)
    preview:SetPoint("RIGHT", edit, "LEFT", -8, 0)
    preview:SetScript("OnClick", function() self:SetPreviewMode(not self.previewMode) end)
    local reload = HeaderButton("Reload", 72)
    reload:SetPoint("RIGHT", preview, "LEFT", -8, 0)
    reload:SetScript("OnClick", function()
        local _,reason=self.ReloadManager:Reload()
        print("ModeUI: "..reason)
    end)
    window.reloadButton=reload
    window.previewButton, window.editButton, window.closeButton = preview, edit, close

    local sidebar = CreateFrame("Frame", nil, window)
    sidebar:SetPoint("TOPLEFT", 12 + edge, -HEADER_HEIGHT - 4)
    sidebar:SetPoint("BOTTOMLEFT", 12 + edge, 12 + edge)
    sidebar:SetWidth(sidebarWidth - 22 - edge)
    local navigation = W.Page(sidebar, 0)
    navigation:ClearAllPoints()
    navigation:SetPoint("TOPLEFT", 0, mode and 0 or -44)
    navigation:SetPoint("BOTTOMRIGHT")

    local body = CreateFrame("Frame", nil, window)
    local contentGap=mode and 24 or 30
    body:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", contentGap, -16)
    window.contentLeft=sidebarWidth-10+contentGap
    body:SetPoint("BOTTOMRIGHT", -28, 16 + edge)
    if mode then
        window.bodySurface=W.Fill(body,T.pageBackground,"BACKGROUND",-12)
        window.bodyDetail=W.ModePageDetail(body,-12)
        window.bodySheen=W.ModeSheen(body,-12)
    end
    local moduleHeader = W.ModuleHeader(body)
    window.moduleHeader = moduleHeader
    local pageHost = CreateFrame("Frame", nil, body)
    pageHost:SetPoint("TOPLEFT", 0, -W.PAGE_HEADER_HEIGHT)
    pageHost:SetPoint("BOTTOMRIGHT")
    local pages, navigationButtons = {}, {}
    local categoryNavigation = self:CreateCategoryNavigation(body, navigationButtons)
    window.categoryNavigation = categoryNavigation
    -- ModeUI opens on its first module (Interface > Unit Frames).
    local selected = self.moduleOrder[1]
    local RefreshSidebar
    -- Session-local disclosure state: mode categories start expanded on reload.
    local collapsed = {}
    window.collapsedCategories = collapsed

    function self:RefreshConfig()
        moduleHeader:Refresh()
        preview:SetSelected(self.previewMode)
        edit:SetSelected(self.editMode)
        self.ReloadManager:Refresh()
        for id, button in pairs(navigationButtons) do
            local selectedModule = self.modules[selected]
            button:SetSelected(id == selected or (self.categories[id] ~= nil and selectedModule and selectedModule.category == id) or false)
            if button.status then
                local enabled = self.modules[id].enabled
                button.status:SetText(enabled and "On" or "Off")
                button.status:SetTextColor(unpack(W.StateColor(enabled)))
            end
            if button.RefreshModuleState then button:RefreshModuleState() end
        end
        for _, page in pairs(pages) do page:Refresh() end
    end
    function self:EnsureConfigPage(id)
        if not pages[id] then
            local module = self.modules[id]
            pageHost.modeMediaScope=module and id or nil
            if module.CreateConfigPage then pages[id] = module:CreateConfigPage(pageHost)
            else pages[id] = GenericPage(pageHost, module) end
            if W.ApplyModeModuleLayout and module then W.ApplyModeModuleLayout(pages[id],id) end
            pages[id].modeMediaScope=pageHost.modeMediaScope
            pageHost.modeMediaScope=nil
            pages[id]:Hide()
        end
        return pages[id]
    end
    local function Select(id, preserveDisclosure)
        if addon.FrameAnchors and selected~=id then addon.FrameAnchors:Stop() end
        if selected~=id and addon.PreviewStates then addon.PreviewStates:Stop(selected) end
        local category = self.categories[id]
        if category then id = category.selectedModule or category.modules[1] end
        local module = self.modules[id]
        category = module and module.category and self.categories[module.category] or nil
        if category then category.selectedModule = id end
        if self.CloseSettingsSearch then self:CloseSettingsSearch() end
        if selected ~= id and self.CloseTimerColorPicker then self:CloseTimerColorPicker() end
        if selected ~= id and self.CloseFontDropdown then self:CloseFontDropdown() end
        if selected ~= id then self:CloseModulePreview() end
        for _, page in pairs(pages) do page:Hide() end
        selected = id
        self:UpdateConfigTitle(id)
        window.selectedPage = id
        window.selectedCategory = category and category.id or nil
        categoryNavigation:SetCategory(not mode and category or nil, id)
        if mode and category and not preserveDisclosure then collapsed[category.id] = nil end
        if RefreshSidebar then RefreshSidebar(category, id) end
        -- Category tabs, when present, sit above the page header.
        local top = not mode and category and 44 or 0
        moduleHeader:ClearAllPoints()
        moduleHeader:SetPoint("TOPLEFT", 0, -top)
        moduleHeader:SetPoint("TOPRIGHT", 0, -top)
        pageHost:ClearAllPoints()
        pageHost:SetPoint("TOPLEFT", 0, -top - W.PAGE_HEADER_HEIGHT)
        pageHost:SetPoint("BOTTOMRIGHT", 0, 0)
        moduleHeader:SetModule(module)
        self:EnsureConfigPage(id)
        if not pages[id].UpdatePreviewLayout then
            pages[id]:ClearAllPoints();pages[id]:SetPoint("TOPLEFT");pages[id]:SetPoint("BOTTOMRIGHT")
        end
        if pages[id].SelectSectionTab then pages[id]:SelectSectionTab(1) end
        pages[id]:Show()
        pages[id]:Layout()
        self:RefreshConfig()
    end
    function self:SelectConfigPage(id)
        assert(self.modules[id] or (self.categories[id] and #self.categories[id].modules > 0), "ModeUI: unknown settings page.")
        Select(id)
    end
    RefreshSidebar = self:BuildConfigSidebar({ window = window, sidebar = sidebar, navigation = navigation,
        navigationButtons = navigationButtons, collapsed = collapsed, mode = mode, edge = edge,
        sidebarWidth = sidebarWidth, Select = Select, Selected = function() return selected end })
    navigation:Finish()
    window.navigation = navigation
    window.navigationButtons, window.pages = navigationButtons, pages
    self:CreateSettingsSearch(sidebar)
    window:RegisterEvent("UI_SCALE_CHANGED")
    window:RegisterEvent("DISPLAY_SIZE_CHANGED")
    window:SetScript("OnEvent", function()
        self:FinishWindowInteraction(); self:UpdateWindowBounds()
        self:UpdateModulePreviewBounds()
        if self.EditMode then self.EditMode:ViewportChanged() end
    end)
    window:SetScript("OnShow", function()
        if self.ReloadManager.prompt then self.ReloadManager.prompt:Hide() end
        self:UpdateWindowBounds(); Select(selected, true)
        -- Fills in labels left blank by a font still loading on a fresh launch.
        addon.Media:ScheduleTextRedraw()
    end)
    window:SetScript("OnHide", function()
        if self.FrameAnchors then self.FrameAnchors:Stop() end
        if self.PreviewStates then self.PreviewStates:StopAll() end
        self:FinishWindowInteraction()
        if self.CloseTimerColorPicker then self:CloseTimerColorPicker() end
        if self.CloseFontDropdown then self:CloseFontDropdown() end
        self:CloseModulePreview()
        if self.CloseSettingsSearch then self:CloseSettingsSearch() end
        if window.editSuspended then return end
        self:ResetDisplayModes()
        self:NotifyConfigClosed()
    end)
    self:UpdateWindowBounds(true)
end

function addon:NotifyConfigClosed()
    for _, module in pairs(self.modules) do
        if module.OnConfigClosed then module:OnConfigClosed() end
    end
    self.ReloadManager:OnWindowClosed()
end

function addon:ToggleConfig()
    if self.editMode then self:SetEditMode(false); return end
    if not self.configWindow then self:CreateConfig() end
    self.configWindow:SetShown(not self.configWindow:IsShown())
end
