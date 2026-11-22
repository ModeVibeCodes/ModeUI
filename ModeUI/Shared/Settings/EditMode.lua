local _, addon = ...
local W, T = addon.ConfigWidgets, addon.InterfaceTheme
-- Edit Mode's top bar (docs/DESIGN_LANGUAGE.md, "Edit Mode"): a slim bar
-- across the top of the screen with Elements (every element you can pick,
-- including ones hidden behind others), Names (Inside, Fit, On Hover, Off, or
-- Hide All for no outlines either) and Focus (Off, Dim, Strong), the
-- screen-wide switches (Center Lines, Grid and its spacing), Undo, Redo and Done; drag
-- it to move it. The selected element's panel docks beside it
-- (EditPanel.lua). Keys: arrows nudge one pixel (ten with Shift), Tab and
-- Shift-Tab step through the elements, Ctrl-Z undoes and Ctrl-Y (or
-- Ctrl-Shift-Z) redoes, Esc clears the selection and a second Esc closes.
local STRIP_HEIGHT, PAD = 44, 12
local ARROWS = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
local GRID_SIZES = { 16, 24, 32, 48, 64, 96 }
local Combat = addon.InCombat

-- The elements you can pick now, in registration order.
function addon:EditElements()
    local PM, list = self.PositionManager, {}
    for _, id in ipairs(PM.order) do
        local element = PM.elements[id]
        if element and element.editMode and element.module.enabled then list[#list + 1] = element end
    end
    return list
end

-- Tab and Shift-Tab: the next (or previous) element after the selected one.
function addon:StepEditSelection(direction)
    local list, current = self:EditElements(), self.EditMode:Selected()
    if #list == 0 then return false end
    local index = 0
    for i, element in ipairs(list) do if element == current then index = i end end
    index = index == 0 and (direction > 0 and 1 or #list) or ((index - 1 + direction) % #list) + 1
    return self.EditMode:Select(list[index].id)
end

-- Keeps the strip and the panel inside the screen at any UI scale.
function addon:UpdateEditWindowBounds()
    local window = self.editWindow
    if not window or Combat() then return end
    local panel = addon.EDIT_PANEL_SIZE
    local scale = math.max(0.1, math.min(1, (UIParent:GetWidth() - 24) / window:GetWidth(),
        (UIParent:GetHeight() - 24) / (STRIP_HEIGHT + 8 + panel[2])))
    window:SetScale(scale)
    if self.editPanel then self.editPanel:SetScale(scale) end
end

function addon:CreateEditWindow()
    local E = self.EditMode
    local window = CreateFrame("Frame", "ModeUIEditWindow", UIParent)
    window:Hide()
    self.editWindow = window
    window:SetHeight(STRIP_HEIGHT)
    window:SetPoint("TOP", UIParent, "TOP", 0, -12)
    window:SetFrameStrata("DIALOG")
    window:SetFrameLevel(80)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    W.Texture(window, "Window")
    W.Texture(window, "BorderSilver", "BORDER")
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function()
        if Combat() then return end
        window.moving = true; window:StartMoving()
    end)
    window:SetScript("OnDragStop", function() window:StopMovingOrSizing(); window.moving = false end)
    local title = W.Heading(window, "Edit Mode", T.fontSize.section, PAD + 2, -15, 90, T.text)
    title:SetWordWrap(false)
    local x = PAD + 96
    local function Place(button, width, gap)
        button:SetPoint("LEFT", x, 0); x = x + width + (gap or 6)
        return button
    end
    -- Elements: a menu of every element you can pick.
    local elements = Place(W.Button(window, "Elements", 90, 26, "secondary"), 90, 14)
    elements:SetScript("OnClick", function(button)
        local items = {}
        for _, element in ipairs(self:EditElements()) do
            local name = element.label or element.module.title
            items[#items + 1] = { label = name ~= element.module.title and (name .. "  ·  " .. element.module.title) or name, id = element.id }
        end
        local menu = button.actionMenu or W.ActionMenu(button, 300)
        menu:Open(items, function(item) E:Select(item.id) end)
    end)
    -- Switches: a button each, lit while on.
    local function Switch(text, width, get, set, gap)
        local button = Place(W.Button(window, text, width, 26, "secondary"), width, gap)
        button:SetScript("OnClick", function() set(not get()); self:RefreshEditWindow() end)
        return button
    end
    -- Names and Focus: saved choices (Placement/EditMode.lua); Hide All is the
    -- old Highlights switch (no outlines or names), for this session only.
    local function Choices(list, extra)
        local items = {}
        for _, choice in ipairs(list) do items[#items + 1] = { id = choice.id, label = choice.label } end
        if extra then items[#items + 1] = extra end
        return items
    end
    local namesHost = CreateFrame("Frame", nil, window); namesHost:SetSize(150, 26); Place(namesHost, 150)
    local names = W.Select(namesHost, 150, function() return Choices(E.NAMES, { id = "hidden", label = "Hide All" }) end, function()
        local id = E.highlights and E:Names() or "hidden"
        return id, "Names: " .. (E.highlights and E:ChoiceLabel(E.NAMES, id) or "Hide All")
    end, function(id)
        if id == "hidden" then E:SetHighlights(false)
        else E.highlights = true; E:SetNames(id) end
        self:RefreshEditWindow()
    end)
    local focusHost = CreateFrame("Frame", nil, window); focusHost:SetSize(128, 26); Place(focusHost, 128, 14)
    local focus = W.Select(focusHost, 128, function() return Choices(E.FOCUS) end, function()
        return E:Focus(), "Focus: " .. E:ChoiceLabel(E.FOCUS, E:Focus())
    end, function(id) E:SetFocus(id); self:RefreshEditWindow() end)
    -- Center Lines and Grid draw on the screen behind the elements (PositionGrid.lua).
    local centerLines = Switch("Center Lines", 108, function() return E.centerLines end, function(on) E:SetCenterLines(on) end)
    local grid = Switch("Grid", 60, function() return E.grid end, function(on) E:SetGrid(on) end, 4)
    local sizes = {}
    for _, size in ipairs(GRID_SIZES) do sizes[#sizes + 1] = { id = size, label = size .. " px" } end
    local gridHost = CreateFrame("Frame", nil, window); gridHost:SetSize(72, 26); Place(gridHost, 72, 14)
    local gridSize = W.Select(gridHost, 72, sizes, function()
        return self.PositionManager.GRID_SPACING, self.PositionManager.GRID_SPACING .. " px"
    end, function(size) E:SetGridSpacing(size); self:RefreshEditWindow() end)
    local undo = Place(W.Button(window, "Undo", 60, 26, "secondary"), 60)
    undo:SetScript("OnClick", function() E.history:Undo() end)
    local redo = Place(W.Button(window, "Redo", 60, 26, "secondary"), 60, 18)
    redo:SetScript("OnClick", function() E.history:Redo() end)
    local exit = Place(W.Button(window, "Done", 72, 26, "primary"), 72, 0)
    -- While Anchor To or Match waits for a click it cancels that instead.
    exit:SetScript("OnClick", function()
        if self.EditAnchor:Active() then self.EditAnchor:Stop() else self:SetEditMode(false) end
    end)
    window:SetWidth(x + PAD)
    local panel = self:CreateEditPanel(window, window)
    function self:RefreshEditWindow()
        local element = E:Selected()
        -- Out of the way while Anchor To or Match waits for a click on screen.
        local picking = self.EditAnchor:Active() and true or false
        panel:SetShown(window:IsShown() and element ~= nil and not picking)
        exit.label:SetText(picking and "Cancel" or "Done")
        panel:Refresh()
        names:Refresh(); focus:Refresh()
        centerLines:SetSelected(E.centerLines); grid:SetSelected(E.grid)
        gridSize:Refresh(); gridSize:SetEnabled(E.grid)
        undo:SetEnabled(E.history:CanUndo()); redo:SetEnabled(E.history:CanRedo())
    end
    -- Clearing focus runs the numeric input's normal apply.
    function self:CommitEditInputs() window.xInput:ClearFocus(); window.yInput:ClearFocus() end
    window.exitButton, window.namesSelect, window.focusSelect = exit, names, focus
    window.centerLinesButton, window.gridButton = centerLines, grid
    window.elementsButton, window.gridSizeSelect, window.undoButton, window.redoButton = elements, gridSize, undo, redo
    window:EnableKeyboard(true)
    window:SetPropagateKeyboardInput(true)
    window:SetScript("OnKeyDown", function(_, key)
        if Combat() then return end
        local shift = IsShiftKeyDown and IsShiftKeyDown() or false
        local control = IsControlKeyDown and IsControlKeyDown() or false
        local step = ARROWS[key]
        local element = E:Selected()
        local handled = key == "ESCAPE" or key == "TAB" or (step and element ~= nil) or (control and (key == "Z" or key == "Y"))
        window:SetPropagateKeyboardInput(not handled)
        if key == "ESCAPE" then
            -- First Esc lets go of the element; the next one closes Edit Mode.
            if element then self.PositionManager:ClearSelection() else self:SetEditMode(false) end
        elseif key == "TAB" then self:StepEditSelection(shift and -1 or 1)
        elseif control and key == "Z" then if shift then E.history:Redo() else E.history:Undo() end
        elseif control and key == "Y" then E.history:Redo()
        elseif step and element then
            -- Arrow keys nudge the selected element one pixel (ten with Shift).
            local size = shift and 10 or 1
            self.PositionManager:Nudge(element.id, step[1] * size, step[2] * size)
        end
    end)
    window:SetScript("OnShow", function() self:RefreshEditWindow() end)
    window:SetScript("OnHide", function()
        panel:Hide()
        self.EditAnchor:Finish()
        window:StopMovingOrSizing(); window.moving = false
        if self.editMode and not window.ending then self:SetEditMode(false) end
    end)
end

-- Settings windows of standalone modules (addon:RegisterSettingsWindow):
-- one that's open when Edit Mode starts steps aside and comes back after it,
-- instead of ModeUI's own window.
addon.settingsWindows = {}
function addon:RegisterSettingsWindow(window)
    assert(type(window) == "table" and window.Hide and window.Show, "ModeUI: settings window required.")
    self.settingsWindows[#self.settingsWindows + 1] = window
end

function addon:BeginEditWorkspace()
    self.editReturnWindow = nil
    self.editConfigWasShown = self.configWindow ~= nil and self.configWindow:IsShown()
    for _, other in ipairs(self.settingsWindows) do
        if other:IsShown() then
            self.editReturnWindow = other
            other.editSuspended = true
            other:Hide()
        end
    end
    if not self.configWindow then self:CreateConfig() end
    self:FinishWindowInteraction()
    if not self.editWindow then self:CreateEditWindow() end
    -- Opened from a module's page: that module's first element is selected.
    local page = self.configWindow.selectedPage
    self.configWindow.editSuspended = true
    self.configWindow:Hide()
    self:UpdateEditWindowBounds()
    self.editWindow:Show()
    self.Positioning:Refresh()
    self.EditMode:RefreshElements()
    if self.editConfigWasShown and self.modules[page] then
        for _, element in ipairs(self:EditElements()) do
            if element.module.id == page then self.EditMode:Select(element.id); break end
        end
    end
    self.EditMode.history:Begin()
    self:RefreshEditWindow()
end

function addon:FinishEditWorkspace()
    local window = self.editWindow
    if not window then return end
    window.ending = true
    window:Hide()
    window.ending = false
    self.configWindow.editSuspended = false
    local other = self.editReturnWindow
    if other then
        self.editReturnWindow = nil
        other.editSuspended = false
        if not (InCombatLockdown() or UnitAffectingCombat("player")) then
            other:Show()
            -- ModeUI's window comes back too if it was open as well.
            if self.editConfigWasShown then self.configWindow:Show() end
        end
        return
    end
    -- Never put the settings window over a pull; suspending skipped its close cleanup.
    if InCombatLockdown() or UnitAffectingCombat("player") then
        self:NotifyConfigClosed()
    else
        self.configWindow:Show()
    end
end
