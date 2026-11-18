local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The Cooldown Manager's own window, opened with /mcdm (or Edit Mode's Open
-- Module Settings) and built the first time it opens. ModeUI's Mode look on
-- the shared settings widgets: a header with the title and Open CDM (Blizzard's
-- Cooldown Settings), Edit Mode and close; a list of bars on the left
-- (Spells and Abilities: Blizzard's four viewers; Cooldown Bars and Buff
-- Bars: your custom bars, each heading with + to add one and each bar with
-- - to delete it after a confirmation; then Resource Bars); on the right the
-- page header with the module's
-- on/off switch, and the settings of the bar chosen in the list: the
-- cooldown page (Settings.lua) or the resource bar page
-- (ResourceSettings.lua). Edit Mode hides it and brings it back afterward
-- (addon:RegisterSettingsWindow).
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
    self.selectedResource, self.selectedCast = nil, nil
    if self.page and self.page.SetEditing then self.page.SetEditing(id) end
    if self.window then self:ShowSelectedPage(); self:RefreshList() end
    return true
end
-- Shows a resource bar's settings.
function M:SelectResource(id)
    if not self:IsResource(id) then return false end
    self.selectedResource, self.selectedCast = id, nil
    if self.window then self:ShowSelectedPage(); self:RefreshList() end
    return true
end
-- Shows the Cast Bar's settings.
function M:SelectCast()
    self.selectedCast, self.selectedResource = true, nil
    if self.window then self:ShowSelectedPage(); self:RefreshList() end
    return true
end

-- One page shows at a time: the Cast Bar page or the resource bar page while
-- one is chosen (each built the first time), else the cooldown page.
function M:ShowSelectedPage()
    local window = self.window
    if not window then return end
    if self.castPage then self.castPage:SetShown(self.selectedCast == true) end
    if self.selectedCast then
        if not self.castPage then
            local page = self:CreateCastPage(window.pageHost)
            if W.ApplyModeModuleLayout then W.ApplyModeModuleLayout(page, self.id) end
            page.modeMediaScope = self.id
            if page.SelectSectionTab then page:SelectSectionTab(1) end
        end
        if self.page then self.page:Hide() end
        if self.resourcePage then self.resourcePage:Hide() end
        self.castPage:Show(); self.castPage:Refresh(); self.castPage:Layout()
    elseif self:IsResource(self.selectedResource) then
        if not self.resourcePage then
            local page = self:CreateResourcePage(window.pageHost)
            if W.ApplyModeModuleLayout then W.ApplyModeModuleLayout(page, self.id) end
            page.modeMediaScope = self.id
            if page.SelectSectionTab then page:SelectSectionTab(1) end
        end
        if self.page then self.page:Hide() end
        self.resourcePage:Show()
        self.resourcePage.SetEditing(self.selectedResource)
    else
        if self.resourcePage then self.resourcePage:Hide() end
        if self.page then self.page:Show() end
    end
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
    window.blizzardCaption, window.resourceCaption = Caption(L["Spells and Abilities"]), Caption(L["Resource Bars"])
    window.cooldownCaption, window.buffCaption = Caption(L["Cooldown Bars"]), Caption(L["Buff Bars"])
    -- + on the right of a custom heading adds a bar of that kind.
    local function Add(caption, kind)
        local button = W.Button(list, "+", 22, 20, "quiet")
        button:SetPoint("RIGHT", caption, "RIGHT", 0, 0)
        button:SetScript("OnClick", function() local id = M:AddCustomBar(kind); if id then M:SelectBar(id) end end)
        return button
    end
    window.addCooldown, window.addBuff = Add(window.cooldownCaption, "cooldown"), Add(window.buffCaption, "buff")

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
        M.page:Show(); M:ShowSelectedPage(); M:RefreshWindow()
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

-- Asks before deleting a custom bar; its spells go back to their viewers.
function M:ConfirmDelete(id)
    local bar = self:Custom(id)
    if not bar then return false end
    return W.Confirm(string.format(L["Delete %s?"], bar.name),
        L["Its spells go back to their Blizzard viewers, and its settings and place are forgotten. This can't be undone."],
        L["Delete Bar"], function() if M:DeleteCustomBar(id) and M.selectedBar == id then M:SelectBar("essential") end end)
end

-- The list: Spells and Abilities (Blizzard's viewers), Cooldown Bars and
-- Buff Bars (your custom bars, + on each heading, - on each bar), then
-- Resource Bars. Off bars say so. A long list packs its rows closer.
function M:RefreshList()
    local window = self.window
    if not window then return end
    local list, rows, y = window.list, window.rows, 0
    local room = #self.db.customBars < self.MAX_CUSTOM
    local count = #self.viewers + #self.resources + #self.db.customBars + 1
    local fixed = 4 * 24 + 3 * 12
    -- 22 at the least: fifteen custom bars (MAX_CUSTOM) still fit the list.
    local step = math.max(22, math.min(ROW, math.floor((HEIGHT - HEADER_HEIGHT - 22 - fixed) / count)))
    local function Row(index, id, resource)
        local row = rows[index]
        if not row then
            row = W.Button(list, "", LIST_WIDTH - 24, 30, "tab")
            row.label:ClearAllPoints(); row.label:SetPoint("LEFT", 10, 0); row.label:SetPoint("RIGHT", -62, 0)
            row.label:SetJustifyH("LEFT"); row.label:SetWordWrap(false)
            row.status = W.Label(row, "", nil, 0, 0, 34, T.muted)
            row.status:SetJustifyH("RIGHT")
            row:SetScript("OnClick", function()
                if row.resource == "cast" then M:SelectCast()
                elseif row.resource then M:SelectResource(row.barId) else M:SelectBar(row.barId) end
            end)
            -- - deletes a custom bar, after asking.
            row.delete = W.Button(row, "-", 22, 20, "quiet")
            row.delete:SetPoint("RIGHT", -4, 0)
            row.delete:SetScript("OnClick", function() M:ConfirmDelete(row.barId) end)
            rows[index] = row
        end
        row.barId, row.resource = id, resource
        -- `resource`: true for a resource bar, "cast" for the Cast Bar.
        local cast = resource == "cast"
        local style = (cast and self.db.castBar) or (resource and self.db.resources[id]) or self.db[id]
        local custom = not resource and self:IsCustom(id)
        row.label:SetText((cast and L[self.CAST_LABEL]) or (resource and self:ResourceLabel(id)) or self:Label(id))
        row.status:SetText(style.show and "" or L["Off"])
        row.status:ClearAllPoints(); row.status:SetPoint("RIGHT", custom and -30 or -10, 0)
        row.delete:SetShown(custom); row.delete:SetEnabled(self:CanConfigure())
        if cast then row:SetSelected(self.selectedCast == true)
        elseif resource then row:SetSelected(not self.selectedCast and id == self.selectedResource)
        else row:SetSelected(not self.selectedCast and not self:IsResource(self.selectedResource) and id == self.selectedBar) end
        row:SetHeight(step - 2)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:Show()
        y = y + step
    end
    local function Place(region, height)
        region:ClearAllPoints(); region:SetPoint("TOPLEFT", 0, -y); region:Show()
        y = y + height
    end
    local index = 0
    Place(window.blizzardCaption, 24)
    for _, viewer in ipairs(self.viewers) do index = index + 1; Row(index, viewer) end
    for _, kind in ipairs({ "cooldown", "buff" }) do
        y = y + 12
        Place(kind == "cooldown" and window.cooldownCaption or window.buffCaption, 24)
        for _, bar in ipairs(self.db.customBars) do
            if bar.kind == kind then index = index + 1; Row(index, bar.id) end
        end
    end
    y = y + 12
    Place(window.resourceCaption, 24)
    for _, id in ipairs(self.resources) do index = index + 1; Row(index, id, true) end
    index = index + 1; Row(index, "cast", "cast")
    for i = index + 1, #rows do rows[i]:Hide() end
    local add = room and self:CanConfigure()
    window.addCooldown:SetEnabled(add); window.addBuff:SetEnabled(add)
end

-- Editing, at the top right of a page's preview (like Action Bars): every
-- bar and resource bar in one list, and the one shown now.
function M:EditingChoices()
    local list = {}
    for _, id in ipairs(self:BarIds()) do list[#list + 1] = { id = id, label = self:Label(id) } end
    for _, id in ipairs(self.resources) do list[#list + 1] = { id = "resource:" .. id, label = self:ResourceLabel(id) } end
    list[#list + 1] = { id = "cast", label = L[self.CAST_LABEL] }
    return list
end
function M:EditingValue()
    if self.selectedCast then return "cast", L[self.CAST_LABEL] end
    if self:IsResource(self.selectedResource) then return "resource:" .. self.selectedResource, self:ResourceLabel(self.selectedResource) end
    local id = self.selectedBar or "essential"
    return id, self:Label(id)
end
function M:SelectEditing(value)
    if value == "cast" then return self:SelectCast() end
    local resource = type(value) == "string" and value:match("^resource:(.+)$")
    if resource then return self:SelectResource(resource) end
    return self:SelectBar(value)
end
function M:AddEditingCorner(page)
    if not page.previewArea then return end
    local corner = CreateFrame("Frame", nil, page.previewArea)
    corner:SetPoint("TOPRIGHT", page.previewArea, "TOPRIGHT", 0, -4); corner:SetSize(300, 28)
    local select = W.Select(corner, 210, function() return M:EditingChoices() end,
        function() return M:EditingValue() end, function(value) M:SelectEditing(value) end)
    select:ClearAllPoints(); select:SetPoint("RIGHT", 0, 0)
    local label = W.Label(corner, L["Editing"], nil, 0, 0, 60, T.muted)
    label:ClearAllPoints(); label:SetPoint("RIGHT", select, "LEFT", -8, 0); label:SetJustifyH("RIGHT")
    page.refreshers[#page.refreshers + 1] = function() select:Refresh() end
    page.editingSelect, page.editingLabel = select, label
    page.previewReserveRight = 312
    page:UpdatePreviewLayout()
end

function M:RefreshWindow()
    local window = self.window
    if not window then return end
    window.moduleHeader:Refresh()
    window.editButton:SetSelected(addon.editMode == true)
    window.cdmButton:SetEnabled(self:CanOpenCooldownSettings())
    self:RefreshList()
    if self.page and self.page:IsShown() then self.page:Refresh(); self.page:Layout() end
    if self.resourcePage and self.resourcePage:IsShown() then self.resourcePage:Refresh(); self.resourcePage:Layout() end
    if self.castPage and self.castPage:IsShown() then self.castPage:Refresh(); self.castPage:Layout() end
end
