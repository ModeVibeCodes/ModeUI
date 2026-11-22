local _, addon = ...

-- In Place settings (docs/DESIGN_LANGUAGE.md, "Edit Mode"): the Edit Mode
-- panel's Settings tab is the selected element's module page, the same page
-- object the settings window shows (that window is hidden while Edit Mode is
-- open). It's borrowed into the panel at the panel's width, one card per row
-- and without its preview (the element on screen is the preview), scoped to
-- the selected element (module:OpenElementSettings), and goes back to the
-- window when the panel picks another module or Edit Mode closes. One page,
-- so every setting is reachable in both places and nothing is built twice.
local P = {}
addon.EditPage = P
-- The narrowest a borrowed page lays out (the panel's scroll view is wider).
local PANEL_MINIMUM = 320

function P:Page() return self.page end

-- Shows `module`'s page in `host`, scoped to `elementId`. Returns the page, or
-- nil for a module without a page in the settings window (a standalone one).
function P:Borrow(module, host, elementId)
    if self.page and self.module == module and self.host == host then
        if self.elementId ~= elementId then self:Scope(elementId) end
        return self.page
    end
    self:Return()
    if not module or module.standalone or not module.CreateConfigPage then return nil end
    if not addon.configWindow then addon:CreateConfig() end
    local page = addon:EnsureConfigPage(module.id)
    if not page then return nil end
    self.saved = { parent = page:GetParent(), minimumWidth = page.minimumWidth, cardColumns = page.cardColumns,
        autoColumns = page.autoColumns, level = page:GetFrameLevel() }
    page.inEditPanel = true
    page.minimumWidth, page.cardColumns, page.autoColumns = PANEL_MINIMUM, 1, false
    page:SetParent(host)
    -- Above the panel's face (its cards and controls move up with it).
    page:SetFrameLevel(host:GetFrameLevel() + 1)
    page:ClearAllPoints(); page:SetPoint("TOPLEFT"); page:SetPoint("BOTTOMRIGHT")
    self.module, self.page, self.host = module, page, host
    page:Show()
    if page.UpdatePreviewLayout then page:UpdatePreviewLayout() end
    self:Scope(elementId)
    page:Refresh(); page:Layout()
    return page
end

-- The module page edits the selected element (its bar, frame or window).
function P:Scope(elementId)
    self.elementId = elementId
    local module = self.module
    if not module or not elementId or not module.OpenElementSettings then return end
    local ok, message = pcall(module.OpenElementSettings, module, elementId)
    if not ok then print("ModeUI: element settings failed: " .. tostring(message)) end
end

-- Gives the page back to the settings window as it was.
function P:Return()
    local page, saved, module = self.page, self.saved, self.module
    if not page then return end
    self.module, self.page, self.host, self.saved, self.elementId = nil, nil, nil, nil, nil
    page.inEditPanel = nil
    page.minimumWidth, page.cardColumns, page.autoColumns = saved.minimumWidth, saved.cardColumns, saved.autoColumns
    page:Hide()
    page:SetParent(saved.parent)
    page:SetFrameLevel(saved.level)
    page:ClearAllPoints(); page:SetPoint("TOPLEFT"); page:SetPoint("BOTTOMRIGHT")
    if page.UpdatePreviewLayout then page:UpdatePreviewLayout() end
    -- The window's open page comes back with it.
    local window = addon.configWindow
    if window and window.selectedPage == module.id then
        page:Show()
        if page.UpdatePreviewLayout then page:UpdatePreviewLayout() end
        page:Layout()
    end
end
