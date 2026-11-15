local _, addon = ...
local W, T = addon.ConfigWidgets, addon.InterfaceTheme
-- Edit Mode's strip: a slim bar across the top of the screen with the
-- screen-wide switches (Highlights, Center Lines, Grid) and Exit; drag it to
-- move it. The selected element's settings sit in the panel under it
-- (EditPanel.lua). The window's key handling nudges the selected element.
local STRIP_HEIGHT, PAD = 44, 12
local ARROWS = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
local Combat = addon.InCombat

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
    local title = W.Heading(window, "ModeUI Edit Mode", T.fontSize.section, PAD + 2, -15, 130, T.text)
    title:SetWordWrap(false)
    -- Switches: a button each, lit while on.
    local x = PAD + 140
    local function Switch(text, width, get, set)
        local button = W.Button(window, text, width, 26, "secondary")
        button:SetPoint("LEFT", x, 0)
        x = x + width + 6
        button:SetScript("OnClick", function() set(not get()); self:RefreshEditWindow() end)
        return button
    end
    local highlights = Switch("Highlights", 96, function() return E.highlights end, function(on) E:SetHighlights(on) end)
    -- Center Lines and Grid draw on the screen behind the elements (PositionGrid.lua).
    local centerLines = Switch("Center Lines", 108, function() return E.centerLines end, function(on) E:SetCenterLines(on) end)
    local grid = Switch("Grid", 60, function() return E.grid end, function(on) E:SetGrid(on) end)
    local exit = W.Button(window, "Exit", 72, 26, "primary")
    exit:SetPoint("LEFT", x + 18, 0)
    exit:SetScript("OnClick", function() self:SetEditMode(false) end)
    window:SetWidth(x + 18 + 72 + PAD)
    local panel = self:CreateEditPanel(window, window)
    function self:RefreshEditWindow()
        local element = E:Selected()
        panel:SetShown(window:IsShown() and element ~= nil)
        panel:Refresh()
        highlights:SetSelected(E.highlights)
        centerLines:SetSelected(E.centerLines); grid:SetSelected(E.grid)
    end
    -- Clearing focus runs the numeric input's normal apply.
    function self:CommitEditInputs() window.xInput:ClearFocus(); window.yInput:ClearFocus() end
    window.exitButton, window.highlightButton = exit, highlights
    window.centerLinesButton, window.gridButton = centerLines, grid
    window:EnableKeyboard(true)
    window:SetPropagateKeyboardInput(true)
    window:SetScript("OnKeyDown", function(_, key)
        if Combat() then return end
        -- Arrow keys nudge the selected element one pixel (ten with Shift).
        local step = ARROWS[key]
        local element = step and E:Selected()
        window:SetPropagateKeyboardInput(key ~= "ESCAPE" and not element)
        if key == "ESCAPE" then self:SetEditMode(false)
        elseif element then
            local size = IsShiftKeyDown and IsShiftKeyDown() and 10 or 1
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
    self.configWindow.editSuspended = true
    self.configWindow:Hide()
    self:UpdateEditWindowBounds()
    self.editWindow:Show()
    self.Positioning:Refresh()
    self.EditMode:RefreshElements()
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
