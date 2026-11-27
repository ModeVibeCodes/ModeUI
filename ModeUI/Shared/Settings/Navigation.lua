local _, addon = ...
-- Which page the settings window shows, and in which shape
-- (docs/DESIGN_LANGUAGE.md, "Settings window"): "home" is the main panel (full
-- sidebar, General page); a module with layout = "split" and a tall preview gets
-- the icon rail, the 432px settings column and the live preview beside it;
-- layout = "strip" (a small preview) keeps the rail with the preview across the
-- top and cards below; any other module keeps the sidebar and the whole page.
-- Pages are built the first time they open.
local W, T = addon.ConfigWidgets, addon.InterfaceTheme
-- The window's measurements, from the artifact.
W.SETTINGS_SIZES = { width = 1000, height = 660, header = 40, footer = 40, sidebar = 184, rail = 48, column = 432, pad = 14 }
local S = W.SETTINGS_SIZES

-- The shape a page opens in: "home", "split", "strip" or "page".
function addon:ConfigLayout(id)
    if id == "home" then return "home" end
    local module = self.modules[id]
    if module and (module.layout == "split" or module.layout == "strip") and module.CreateConfigPreview then return module.layout end
    return "page"
end
-- Room a page needs beside its content in the split column: padding and the scroll bar.
local COLUMN_CHROME = 44

function addon:BuildConfigNavigation(window)
    local pages = {}
    window.pages = pages
    window.selectedPage = "home"
    local body, column, pane = window.body, window.column, window.previewPane
    local moduleHeader, pageHost = window.moduleHeader, window.pageHost
    self:BuildConfigSidebar(window)

    local function Arrange(layout, page)
        local split = layout == "split"
        local railed = split or layout == "strip"
        window.layout = layout
        window.sidebar:SetShown(not railed); window.rail:SetShown(railed)
        body:ClearAllPoints()
        body:SetPoint("TOPLEFT", railed and window.rail or window.sidebar, "TOPRIGHT", 0, 0)
        body:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, S.footer)
        column:ClearAllPoints()
        column:SetPoint("TOPLEFT"); column:SetPoint("BOTTOMLEFT")
        -- 432px, or wider for a page that still needs more (pages not yet rebuilt).
        if split then column:SetWidth(math.max(S.column, (page and page.minimumWidth or 0) + COLUMN_CHROME))
        else column:SetPoint("BOTTOMRIGHT") end
        column.line:SetShown(split)
        pane:SetShown(split)
        moduleHeader:ClearAllPoints()
        moduleHeader:SetPoint("TOPLEFT", S.pad, -S.pad); moduleHeader:SetPoint("TOPRIGHT", -S.pad, -S.pad)
        pageHost:ClearAllPoints()
        pageHost:SetPoint("TOPLEFT", S.pad, -S.pad - W.PAGE_HEADER_HEIGHT)
        pageHost:SetPoint("BOTTOMRIGHT", split and -2 or -S.pad + 10, S.pad / 2)
    end

    function self:UpdateConfigTitle(id)
        local module = self.modules[id]
        local inside = id ~= "home"
        window.backButton:SetShown(inside)
        window.crumb:SetShown(inside); window.crumbTitle:SetShown(inside)
        window.crumbTitle:SetText(module and (module.tabTitle or module.title) or "")
    end

    function self:RefreshConfig()
        moduleHeader:Refresh()
        window.previewButton:SetSelected(self.previewMode)
        window.editButton:SetSelected(self.editMode)
        self.ReloadManager:Refresh()
        if window.RefreshNavigation then window:RefreshNavigation() end
        if window.profileSelect then window.profileSelect:Refresh() end
        local module = self.modules[window.selectedPage]
        local reset = module ~= nil and (module.ResetToDefaults ~= nil or module.ResetScopes ~= nil)
        local copy = module ~= nil and module.CopyActions ~= nil
        window.resetButton:SetShown(reset); window.copyButton:SetShown(copy)
        -- Done, then Reset…, Copy To… and Edit Mode, each beside the last shown.
        local last = reset and window.resetButton or window.doneButton
        window.copyButton:ClearAllPoints(); window.copyButton:SetPoint("RIGHT", last, "LEFT", -8, 0)
        if copy then last = window.copyButton end
        window.editButton:ClearAllPoints()
        window.editButton:SetPoint("RIGHT", last, "LEFT", -8, 0)
        -- Only the page on show (in the window or borrowed by Edit Mode's
        -- panel); a hidden one refreshes when Select shows it again.
        for _, page in pairs(pages) do if page:IsShown() then page:Refresh() end end
    end

    function self:EnsureConfigPage(id)
        if not pages[id] then
            if id == "home" then
                pages[id] = self:CreateConfigHome(pageHost)
            else
                local module = self.modules[id]
                pageHost.modeMediaScope = module and id or nil
                pageHost.modeSplitPane = self:ConfigLayout(id) == "split" and pane or nil
                if module.CreateConfigPage then pages[id] = module:CreateConfigPage(pageHost)
                else local page = W.Page(pageHost); page:Finish(); pages[id] = page end
                if W.ApplyModeModuleLayout and module then W.ApplyModeModuleLayout(pages[id], id) end
                pages[id].modeMediaScope = pageHost.modeMediaScope
                pageHost.modeMediaScope, pageHost.modeSplitPane = nil, nil
            end
            pages[id]:Hide()
        end
        return pages[id]
    end

    local function Select(id)
        local previous = window.selectedPage
        if id ~= "home" and self.categories[id] then id = self.categories[id].modules[1] end
        if addon.FrameAnchors and previous ~= id then addon.FrameAnchors:Stop() end
        if previous ~= id and addon.PreviewStates and previous ~= "home" then addon.PreviewStates:Stop(previous) end
        if self.CloseSettingsSearch then self:CloseSettingsSearch() end
        if previous ~= id and self.CloseTimerColorPicker then self:CloseTimerColorPicker() end
        if previous ~= id and self.CloseFontDropdown then self:CloseFontDropdown() end
        for _, page in pairs(pages) do page:Hide() end
        local module = self.modules[id]
        window.selectedPage = id
        window.selectedCategory = module and module.category or nil
        local layout = self:ConfigLayout(id)
        local page = self:EnsureConfigPage(id)
        -- Pages not yet rebuilt into small cards show their cards as tiles,
        -- two across, outside the split column.
        if page.autoColumns or (page.cardColumns == nil and id ~= "home" and (page.sectionTabs or #page.sections == 0)) then
            page.autoColumns = true
            page.cardColumns = layout ~= "split" and 2 or nil
        end
        Arrange(layout, page)
        self:UpdateConfigTitle(id)
        moduleHeader:SetModule(module)
        if not page.UpdatePreviewLayout then
            page:ClearAllPoints(); page:SetPoint("TOPLEFT"); page:SetPoint("BOTTOMRIGHT")
        end
        if page.SelectSectionTab then page:SelectSectionTab(1) end
        page:Show()
        if page.UpdatePreviewLayout then page:UpdatePreviewLayout() end
        page:Layout()
        self:RefreshConfig()
    end
    function self:SelectConfigPage(id)
        assert(id == "home" or self.modules[id] or (self.categories[id] and #self.categories[id].modules > 0),
            "ModeUI: unknown settings page.")
        Select(id)
    end
end
