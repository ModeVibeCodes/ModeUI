local _, addon = ...
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The Cooldown Manager's own window, opened with /mcdm (or Edit Mode's Open
-- Module Settings) and built the first time it opens. ModeUI's Mode look on
-- the shared settings widgets: a header with the title and Open CDM (Blizzard's
-- Cooldown Settings), Edit Mode and close; a list of bars on the left
-- (Blizzard's four viewers, then your custom bars and buttons to add more);
-- on the right the page header with the module's on/off switch, and the
-- settings of the bar chosen in the list. Edit Mode hides it and brings it
-- back afterward (addon:RegisterSettingsWindow).
local WIDTH, HEIGHT, LIST_WIDTH, HEADER_HEIGHT, ROW = 1060, 740, 220, 56, 32

function M:ToggleWindow()
    if addon.editMode then addon:SetEditMode(false) end
    if self.window and self.window:IsShown() then self.window:Hide() else self:OpenWindow() end
end
function M:OpenWindow()
    if not addon.initialized then return false end
    if addon.editMode then addon:SetEditMode(false) end
    if not self.window then self:CreateWindow() end
    self.window:Show()
    return true
end

-- Shows a bar's settings (a viewer or a custom bar).
function M:SelectBar(id)
    if not self:HasBar(id) then return false end
    self.selectedBar = id
    if self.page and self.page.SetEditing then self.page.SetEditing(id) end
    if self.window then self:RefreshList() end
    return true
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
    local column = window:CreateTexture(nil, "BACKGROUND", nil, 1)
    column.modeAsset = "ModeSurface"; W.Paint(column, T.sidebar)
    column:SetPoint("TOPLEFT", 8, -8); column:SetPoint("BOTTOMLEFT", 8, 8); column:SetWidth(LIST_WIDTH - 8)

    -- Header: the title, then Open CDM, Edit Mode and close on the right; the
    -- rest of it drags the window.
    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(HEADER_HEIGHT)
    header:SetFrameLevel(window:GetFrameLevel() + 10)
    window.title = W.Heading(header, L["Cooldown Manager"], T.fontSize.brand, 22, -18, LIST_WIDTH + 200, T.primary)
    window.title:SetTextColor(unpack(T.primary)); window.title:SetWordWrap(false)
    local controls = CreateFrame("Frame", nil, header)
    controls:SetPoint("TOPRIGHT", -16, -14); controls:SetSize(320, 28)
    controls:SetFrameLevel(header:GetFrameLevel() + 1)
    window.closeButton = HeaderButton(controls, "X", 28, "quiet")
    window.closeButton:SetPoint("RIGHT")
    window.closeButton:SetScript("OnClick", function() window:Hide() end)
    window.editButton = HeaderButton(controls, "Edit Mode", 92)
    window.editButton:SetPoint("RIGHT", window.closeButton, "LEFT", -16, 0)
    window.editButton:SetScript("OnClick", function() addon:SetEditMode(not addon.editMode) end)
    window.cdmButton = HeaderButton(controls, "Open CDM", 96, "primary")
    window.cdmButton:SetPoint("RIGHT", window.editButton, "LEFT", -8, 0)
    window.cdmButton:SetScript("OnClick", function() M:OpenCooldownSettings() end)
    local drag = CreateFrame("Frame", nil, header)
    drag:SetPoint("TOPLEFT"); drag:SetPoint("BOTTOMRIGHT", controls, "BOTTOMLEFT", -16, -14)
    drag:SetFrameLevel(header:GetFrameLevel() + 1)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() if not addon.InCombat() then window:StartMoving() end end)
    drag:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    window.header = drag

    -- The bar list.
    local list = CreateFrame("Frame", nil, window)
    list:SetPoint("TOPLEFT", 16, -HEADER_HEIGHT - 6); list:SetPoint("BOTTOMLEFT", 16, 16); list:SetWidth(LIST_WIDTH - 24)
    window.list, window.rows = list, {}
    local function Caption(text)
        local label = W.Label(list, text:upper(), nil, 0, 0, LIST_WIDTH - 24, T.faint or T.muted)
        addon.Media:BindInterfaceFont(label, GameFontHighlight, T.fontSize.group, nil, "heading")
        return label
    end
    window.blizzardCaption, window.customCaption = Caption(L["Blizzard"]), Caption(L["Custom Bars"])
    window.addCooldown = W.Button(list, L["+ Cooldown Bar"], LIST_WIDTH - 24, 28, "secondary")
    window.addCooldown:SetScript("OnClick", function() local id = M:AddCustomBar("cooldown"); if id then M:SelectBar(id) end end)
    window.addBuff = W.Button(list, L["+ Buff Bar"], LIST_WIDTH - 24, 28, "secondary")
    window.addBuff:SetScript("OnClick", function() local id = M:AddCustomBar("buff"); if id then M:SelectBar(id) end end)

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
        if not M.page then
            local page = M:CreateConfigPage(host)
            if W.ApplyModeModuleLayout then W.ApplyModeModuleLayout(page, M.id) end
            page.modeMediaScope = M.id
        end
        if not M:HasBar(M.selectedBar or "") then M.selectedBar = "essential" end
        M.page.SetEditing(M.selectedBar)
        if M.page.SelectSectionTab then M.page:SelectSectionTab(1) end
        M.page:Show(); M:RefreshWindow()
        addon.Media:ScheduleTextRedraw()
    end)
    window:SetScript("OnHide", function()
        window:StopMovingOrSizing()
        if M.spellMenu then M.spellMenu:Hide() end
        if M.picker then M.picker:Hide() end
        if addon.CloseTimerColorPicker then addon:CloseTimerColorPicker() end
        if addon.CloseFontDropdown then addon:CloseFontDropdown() end
        if window.editSuspended then return end
        if addon.PreviewStates then addon.PreviewStates:Stop(M.id) end
        addon.ReloadManager:OnWindowClosed()
    end)
    window:RegisterEvent("UI_SCALE_CHANGED"); window:RegisterEvent("DISPLAY_SIZE_CHANGED")
    window:SetScript("OnEvent", function() Scale(window); W.RefreshPixelInsets() end)
    addon:RegisterSettingsWindow(window)
end

-- One row per bar: Blizzard's viewers, then the custom bars, then the add
-- buttons (gone once there are MAX_CUSTOM). Off bars say so.
function M:RefreshList()
    local window = self.window
    if not window then return end
    local list, rows, y = window.list, window.rows, 0
    local function Row(index, id)
        local row = rows[index]
        if not row then
            row = W.Button(list, "", LIST_WIDTH - 24, 30, "tab")
            row.label:ClearAllPoints(); row.label:SetPoint("LEFT", 10, 0); row.label:SetPoint("RIGHT", -40, 0)
            row.label:SetJustifyH("LEFT"); row.label:SetWordWrap(false)
            row.status = W.Label(row, "", nil, 0, 0, 34, T.muted)
            row.status:ClearAllPoints(); row.status:SetPoint("RIGHT", -10, 0); row.status:SetJustifyH("RIGHT")
            row:SetScript("OnClick", function() M:SelectBar(row.barId) end)
            rows[index] = row
        end
        row.barId = id
        row.label:SetText(self:Label(id))
        row.status:SetText(self.db[id].show and "" or L["Off"])
        row:SetSelected(id == self.selectedBar)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:Show()
        y = y + ROW
    end
    local function Place(region, height)
        region:ClearAllPoints(); region:SetPoint("TOPLEFT", 0, -y); region:Show()
        y = y + height
    end
    local index = 0
    Place(window.blizzardCaption, 24)
    for _, viewer in ipairs(self.viewers) do index = index + 1; Row(index, viewer) end
    y = y + 12
    Place(window.customCaption, 24)
    for _, bar in ipairs(self.db.customBars) do index = index + 1; Row(index, bar.id) end
    for i = index + 1, #rows do rows[i]:Hide() end
    local room = #self.db.customBars < self.MAX_CUSTOM
    window.addCooldown:SetShown(room); window.addBuff:SetShown(room)
    if room then
        y = y + 4
        Place(window.addCooldown, 34); Place(window.addBuff, 34)
    end
    local configurable = self:CanConfigure()
    window.addCooldown:SetEnabled(configurable); window.addBuff:SetEnabled(configurable)
end

function M:RefreshWindow()
    local window = self.window
    if not window then return end
    window.moduleHeader:Refresh()
    window.editButton:SetSelected(addon.editMode == true)
    window.cdmButton:SetEnabled(self:CanOpenCooldownSettings())
    self:RefreshList()
    if self.page and self.page:IsShown() then self.page:Refresh(); self.page:Layout() end
end
