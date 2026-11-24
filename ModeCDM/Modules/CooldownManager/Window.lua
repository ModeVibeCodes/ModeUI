local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The Cooldown Manager's own window, opened with /mcdm (or Edit Mode's Open
-- Module Settings) and built the first time it opens. ModeUI's Mode look on
-- the shared settings widgets: a header with the title, Tracked Spells
-- (Blizzard's Cooldown Settings), Test on Screen, Edit Mode and close; the
-- list on the left (WindowList.lua: Home, Bar Style, then Cooldowns, Buffs
-- and Player Bars, owner, November 24, 2026); on the right the page header
-- with the module's on/off switch and the page chosen in the list: Home
-- (HomePage.lua), the Bar Style (StylePage.lua), a bar (Settings.lua), a
-- resource bar (ResourceSettings.lua) or the Cast Bar (CastSettings.lua).
-- Edit Mode hides it and brings it back afterward (addon:RegisterSettingsWindow).
local WIDTH, HEIGHT, LIST_WIDTH, HEADER_HEIGHT = 1060, 740, 220, 56
M.WINDOW_HEIGHT, M.WINDOW_LIST_WIDTH, M.WINDOW_HEADER_HEIGHT = HEIGHT, LIST_WIDTH, HEADER_HEIGHT

function M:ToggleWindow()
    if addon.editMode then addon:SetEditMode(false) end
    if self.window and self.window:IsShown() then self.window:Hide() else self:OpenWindow() end
end
-- Opens on Home (owner's default, November 24, 2026) unless a page was chosen
-- to open on (Edit Mode's Open Module Settings).
function M:OpenWindow()
    if not addon.initialized then return false end
    if addon.editMode then addon:SetEditMode(false) end
    if not self.window then self:CreateWindow() end
    self.window:Show()
    return true
end

-- What the window shows: "home", "style", "cast", a resource or a bar.
function M:SelectedPage()
    if self.selectedView then return self.selectedView end
    if self.selectedCast then return "cast" end
    if self:IsResource(self.selectedResource) then return "resource" end
    return "bar"
end
local function Pick(self, view, bar, resource, cast)
    self.selectedView, self.selectedResource, self.selectedCast = view, resource, cast
    if bar then self.selectedBar = bar end
    if self.window then self:ShowSelectedPage(); self:RefreshList() end
    return true
end
function M:SelectHome() return Pick(self, "home") end
function M:SelectStyle() return Pick(self, "style") end
-- A bar's settings (a viewer or a custom bar).
function M:SelectBar(id)
    if not self:HasBar(id) then return false end
    if self.page and self.page.SetEditing then self.page.SetEditing(id) end
    return Pick(self, nil, id)
end
function M:SelectResource(id)
    if not self:IsResource(id) then return false end
    return Pick(self, nil, nil, id)
end
function M:SelectCast() return Pick(self, nil, nil, nil, true) end
-- Any page by its list value: "home", "style", "cast", "resource:<id>" or a bar.
function M:SelectEditing(value)
    if value == "home" then return self:SelectHome() end
    if value == "style" then return self:SelectStyle() end
    if value == "cast" then return self:SelectCast() end
    local resource = type(value) == "string" and value:match("^resource:(.+)$")
    if resource then return self:SelectResource(resource) end
    return self:SelectBar(value)
end

-- The page shown now as a list value, and its name.
function M:EditingValue()
    local which = self:SelectedPage()
    if which == "home" then return "home", L["Home"] end
    if which == "style" then return "style", L["Bar Style"] end
    if which == "cast" then return "cast", L[self.CAST_LABEL] end
    if which == "resource" then return "resource:" .. self.selectedResource, self:ResourceLabel(self.selectedResource) end
    local id = self.selectedBar or "essential"
    return id, self:Label(id)
end

-- One page shows at a time; each is built the first time it's chosen.
local BUILDERS = { home = "CreateHomePage", style = "CreateStylePage", resource = "CreateResourcePage", cast = "CreateCastPage" }
local FIELDS = { home = "homePage", style = "stylePage", bar = "page", resource = "resourcePage", cast = "castPage" }
function M:ShowSelectedPage()
    local window = self.window
    if not window then return end
    local which = self:SelectedPage()
    if not self[FIELDS[which]] and BUILDERS[which] then
        local page = self[BUILDERS[which]](self, window.pageHost)
        if W.ApplyModeModuleLayout then W.ApplyModeModuleLayout(page, self.id) end
        page.modeMediaScope = self.id
    end
    for kind, field in pairs(FIELDS) do
        local page = self[field]
        if page and kind ~= which then page:Hide() end
    end
    local page = self[FIELDS[which]]
    if not page then return end
    page:Show()
    if which == "bar" and page.SetEditing then page.SetEditing(self.selectedBar or "essential")
    elseif which == "resource" then page.SetEditing(self.selectedResource)
    else page:Refresh(); page:Layout() end
end

local function Scale(window)
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    window:SetScale(math.min(1, math.max(1, width - 32) / WIDTH, math.max(1, height - 32) / HEIGHT))
end

local function HeaderButton(parent, label, width, style)
    local button = W.Button(parent, L[label], width, 28, style or "secondary")
    button:SetFrameLevel(parent:GetFrameLevel() + 1)
    button:RegisterForClicks("LeftButtonUp")
    return button
end

function M:CreateWindow()
    local window = CreateFrame("Frame", "ModeUICooldownManagerWindow", UIParent)
    window:Hide()
    self.window = window
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true); window:SetClampedToScreen(true); window:EnableMouse(true)
    window.canvas = W.Fill(window, T.background, "BACKGROUND")
    if T.id == "mode" then window.canvasSheen = W.ModeSheen(window) end
    local column = W.Fill(window, T.sidebar, "BACKGROUND")
    column:SetDrawLayer("BACKGROUND", 1); column:ClearAllPoints()
    column:SetPoint("TOPLEFT", 8, -8); column:SetPoint("BOTTOMLEFT", 8, 8); column:SetWidth(LIST_WIDTH - 8)

    -- Header: the title, then Tracked Spells, Test on Screen, Edit Mode and
    -- close on the right; the rest of it drags the window.
    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(HEADER_HEIGHT)
    header:SetFrameLevel(window:GetFrameLevel() + 10)
    window.title = W.Heading(header, L["Cooldown Manager"], T.fontSize.brand, 22, -18, LIST_WIDTH + 200, T.primary)
    window.title:SetTextColor(unpack(T.primary)); window.title:SetWordWrap(false)
    local controls = CreateFrame("Frame", nil, header)
    controls:SetPoint("TOPRIGHT", -16, -14); controls:SetSize(460, 28)
    controls:SetFrameLevel(header:GetFrameLevel() + 1)
    window.closeButton = HeaderButton(controls, "X", 28, "quiet")
    window.closeButton:SetPoint("RIGHT")
    window.closeButton:SetScript("OnClick", function() window:Hide() end)
    window.editButton = HeaderButton(controls, "Edit Mode", 92)
    window.editButton:SetPoint("RIGHT", window.closeButton, "LEFT", -16, 0)
    window.editButton:SetScript("OnClick", function() addon:SetEditMode(not addon.editMode) end)
    window.testButton = HeaderButton(controls, "Test on Screen", 120)
    window.testButton:SetPoint("RIGHT", window.editButton, "LEFT", -8, 0)
    window.testButton:SetScript("OnClick", function() M:SetTestDisplay(not M.testDisplay) end)
    window.cdmButton = HeaderButton(controls, "Tracked Spells", 120, "primary")
    window.cdmButton:SetPoint("RIGHT", window.testButton, "LEFT", -8, 0)
    window.cdmButton:SetScript("OnClick", function() M:OpenCooldownSettings() end)
    local drag = CreateFrame("Frame", nil, header)
    drag:SetPoint("TOPLEFT"); drag:SetPoint("BOTTOMRIGHT", controls, "BOTTOMLEFT", -16, -14)
    drag:SetFrameLevel(header:GetFrameLevel() + 1)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() if not addon.InCombat() then window:StartMoving() end end)
    drag:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    window.header = drag

    self:BuildWindowList(window)

    -- The body: the page header (title and on/off switch), then the page.
    local body = CreateFrame("Frame", nil, window)
    body:SetPoint("TOPLEFT", LIST_WIDTH + 24, -HEADER_HEIGHT - 6); body:SetPoint("BOTTOMRIGHT", -28, 16)
    if T.id == "mode" then
        window.bodySurface = W.Fill(body, T.pageBackground, "BACKGROUND", -12)
        window.bodySheen = W.ModeSheen(body, -12)
    end
    window.moduleHeader = W.ModuleHeader(body)
    window.moduleHeader:SetModule(M)
    local host = CreateFrame("Frame", nil, body)
    host:SetPoint("TOPLEFT", 0, -W.PAGE_HEADER_HEIGHT); host:SetPoint("BOTTOMRIGHT")
    -- Media choices made for this module apply to its page.
    host.modeMediaScope = M.id
    window.pageHost = host

    window:SetScript("OnShow", function()
        Scale(window); W.RefreshPixelInsets()
        -- The bar page is always there: previews and menus draw through it.
        if not M.page then
            local page = M:CreateConfigPage(host)
            if W.ApplyModeModuleLayout then W.ApplyModeModuleLayout(page, M.id) end
            page.modeMediaScope = M.id
            page:Hide()
        end
        if not M:HasBar(M.selectedBar or "") then M.selectedBar = "essential" end
        if M.openOnPage then M.selectedView, M.openOnPage = nil, nil
        elseif not M.selectedView and not M.selectedCast and not M:IsResource(M.selectedResource) and not M.keepPage then M.selectedView = "home" end
        M:ShowSelectedPage(); M:RefreshWindow()
        addon.Media:ScheduleTextRedraw()
    end)
    window:SetScript("OnHide", function()
        window:StopMovingOrSizing()
        if M.spellMenu then M.spellMenu:Hide() end
        if M.picker then M.picker:Hide() end
        if M.testDisplay then M:SetTestDisplay(false) end
        if addon.CloseTimerColorPicker then addon:CloseTimerColorPicker() end
        if addon.CloseFontDropdown then addon:CloseFontDropdown() end
        if window.editSuspended then return end
        if addon.PreviewStates then addon.PreviewStates:Stop(M.id) end
        addon.ReloadManager:OnWindowClosed()
        -- Next time it opens on Home again.
        M.selectedView, M.selectedCast, M.selectedResource = nil, nil, nil
    end)
    window:RegisterEvent("UI_SCALE_CHANGED"); window:RegisterEvent("DISPLAY_SIZE_CHANGED")
    window:SetScript("OnEvent", function() Scale(window); W.RefreshPixelInsets() end)
    addon:RegisterSettingsWindow(window)
end

-- Asks before deleting a custom bar; its spells go back to their viewers.
function M:ConfirmDelete(id)
    local bar = self:Custom(id)
    if not bar then return false end
    return W.Confirm(string.format(L["Delete %s?"], bar.name),
        L["Its spells go back to their Blizzard viewers, and its settings and place are forgotten. This can't be undone."],
        L["Delete Bar"], function() if M:DeleteCustomBar(id) and M.selectedBar == id then M:SelectBar("essential") end end)
end

function M:RefreshWindow()
    local window = self.window
    if not window then return end
    window.moduleHeader:Refresh()
    window.editButton:SetSelected(addon.editMode == true)
    window.cdmButton:SetEnabled(self:CanOpenCooldownSettings())
    window.testButton:SetEnabled(self:CanTestDisplay())
    window.testButton:SetSelected(self.testDisplay == true)
    self:RefreshList()
    for _, field in pairs(FIELDS) do
        local page = self[field]
        if page and page:IsShown() then page:Refresh(); page:Layout() end
    end
end
