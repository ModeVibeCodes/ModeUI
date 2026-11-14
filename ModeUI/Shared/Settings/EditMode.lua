local _, addon = ...
local W, T = addon.ConfigWidgets, addon.InterfaceTheme
local HEIGHT = 510
local ARROWS = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }

-- Small owned dropdown; options are rebuilt on open, never polled.
local function Dropdown(parent, width, choices, getter, setter)
    local button = W.Button(parent, "", width, 28)
    W.DropdownLabel(button)
    local menu = CreateFrame("Frame", nil, button)
    menu:Hide()
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -4)
    menu:SetWidth(width)
    menu:SetFrameStrata("TOOLTIP")
    menu:SetFrameLevel(button:GetFrameLevel() + 30)
    menu:SetClampedToScreen(true)
    W.Texture(menu, "Window")
    local rows = {}
    function button:Refresh()
        local id, text = getter()
        self.label:SetText(text)
        if not menu:IsShown() then return end
        local items = choices()
        menu:SetHeight(12 + #items * 30)
        for index, item in ipairs(items) do
            local row = rows[index]
            if not row then
                row = W.Button(menu, "", width - 12, 28, "tab")
                row:SetPoint("TOPLEFT", 6, -6 - (index - 1) * 30)
                rows[index] = row
                row:SetScript("OnClick", function() menu:Hide(); setter(row.choice.id); self:Refresh() end)
            end
            row.choice = item
            row.label:SetText(item.label)
            row:SetSelected(item.id == id)
            row:Show()
        end
        for index = #items + 1, #rows do rows[index]:Hide() end
    end
    button:SetScript("OnClick", function()
        if InCombatLockdown() or UnitAffectingCombat("player") then return end
        if parent.anchorMenu and parent.anchorMenu ~= menu then parent.anchorMenu:Hide() end
        parent.anchorMenu = menu
        menu:SetShown(not menu:IsShown()); button:Refresh()
    end)
    button.menu, button.rows = menu, rows
    return button
end

function addon:UpdateEditWindowBounds()
    local window = self.editWindow
    if not window or InCombatLockdown() or UnitAffectingCombat("player") then return end
    window:SetScale(math.max(0.1, math.min(1, (UIParent:GetWidth() - 24) / 340, (UIParent:GetHeight() - 24) / HEIGHT)))
end

function addon:CreateEditWindow()
    local E = self.EditMode
    local window = CreateFrame("Frame", "ModeUIEditWindow", UIParent)
    window:Hide()
    self.editWindow = window
    window:SetSize(340, HEIGHT)
    window:SetPoint("TOP", UIParent, "TOP", 0, -48)
    window:SetFrameStrata("DIALOG")
    window:SetFrameLevel(80)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    W.Texture(window, "Window")
    W.Texture(window, "BorderSilver", "BORDER")
    local drag = CreateFrame("Frame", nil, window)
    drag:SetPoint("TOPLEFT", 8, -8)
    drag:SetPoint("TOPRIGHT", -8, -8)
    drag:SetHeight(36)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        if InCombatLockdown() or UnitAffectingCombat("player") then return end
        window.moving = true; window:StartMoving()
    end)
    drag:SetScript("OnDragStop", function() window:StopMovingOrSizing(); window.moving = false end)
    W.Heading(drag, "ModeUI Edit Mode", T.fontSize.section, 12, -8, 280, T.text)
    local selected = W.Label(window, "", nil, 20, -52, 300, T.secondary)
    local refreshing
    W.Label(window, "X Position", nil, 20, -80, 300)
    W.Label(window, "Y Position", nil, 20, -138, 300)
    local function Coordinate(axis, top)
        local function Get()
            local element = E:Selected()
            if not element then return 0 end
            local px, py = self.PositionManager:GetOffsets(element.id)
            return axis == "x" and px or py
        end
        local function Limits()
            local element = E:Selected()
            if not element then return 0, 0 end
            local lx, hx, ly, hy = E:CoordinateBounds(element)
            if axis == "x" then return lx, hx end
            return ly, hy
        end
        local holder = CreateFrame("Frame", nil, window)
        holder:SetPoint("TOPLEFT", 20, top)
        holder:SetSize(300, 30)
        local low, high = Limits()
        local function Set(value) if not refreshing then E:SetCoordinate(axis, value) end end
        local refresh = W.Slider(holder, low, high, 5, Get, Set, "", {
            minimum = function() local l = Limits(); return l end,
            maximum = function() local _, h = Limits(); return h end,
        })
        local input, slider = holder.numericInput, holder.slider
        input:SetWidth(88)
        slider:SetPoint("RIGHT", -100, 0)
        return input, slider, function()
            local l, h = Limits()
            slider:SetMinMaxValues(l, h)
            refresh()
        end
    end
    local xInput, xSlider, refreshX = Coordinate("x", -104)
    local yInput, ySlider, refreshY = Coordinate("y", -162)
    W.Heading(window, "Snap To UI Element", T.fontSize.section, 20, -204, 300, T.text)
    local P = self.Positioning
    local function Position()
        local element = E:Selected()
        return element and self.PositionManager:GetPosition(element.id)
    end
    local targets = Dropdown(window, 188, function()
        local element = E:Selected()
        return self.PositionManager:GetAllowedTargets(element and element.id)
    end, function()
        local position = Position()
        local id = position and position.target or "screen"
        if addon.FrameAnchors:ValidID(id) then return id,id:sub(7)..(P:Resolve(id) and "" or " (unavailable)") end
        for _, target in ipairs(P.targets) do
            if target.id == id then return id, target.label .. (P:Resolve(id) and "" or " (unavailable)") end
        end
        return id, "Saved target unavailable"
    end, function(id) E:SetTarget(id) end)
    targets:SetPoint("TOPLEFT", 20, -228)
    -- Anchor To: click it, then click the element to hang from (EditAnchor.lua).
    local anchorTo = W.Button(window, "Anchor To...", 104, 28, "secondary")
    anchorTo:SetPoint("TOPLEFT", 216, -228)
    anchorTo:SetScript("OnClick", function()
        local A, element = self.EditAnchor, E:Selected()
        if A:Active() then A:Stop() elseif element then A:Start(element.id) end
        self:RefreshEditWindow()
    end)
    local placements = Dropdown(window, 188, function() return P.placements end, function()
        local p = Position()
        local placement = P:Placement(p and p.placement)
        return placement.id, placement.label
    end, function(id) E:SetPlacement(id) end)
    placements:SetPoint("TOPLEFT", 20, -266)
    local reset = W.Button(window, "Reset Offset", 104, 30, "secondary")
    reset:SetPoint("TOPLEFT", 216, -266)
    reset:SetScript("OnClick", function() E:ResetOffset() end)
    local highlights = W.Button(window, "", 30, 30, "checkbox")
    -- Match Width / Match Height: offered by modules that can size an element
    -- to what it's anchored on (PositionManager:SetSizeMatch).
    local function Match(axis, x, text)
        local box = W.Button(window, "", 30, 30, "checkbox")
        box:SetPoint("TOPLEFT", x, -306)
        box:SetScript("OnClick", function()
            local element = E:Selected()
            if element then self.PositionManager:SetSizeMatchValue(element.id, axis, not self.PositionManager:GetSizeMatch(element.id, axis)) end
            self:RefreshEditWindow()
        end)
        box.text = W.Label(window, text, nil, x + 40, -313, 110)
        return box
    end
    local matchWidth, matchHeight = Match("width", 20, "Match Width"), Match("height", 176, "Match Height")
    highlights:SetPoint("TOPLEFT", 20, -348)
    highlights:SetScript("OnClick", function() E:SetHighlights(not E.highlights) end)
    W.Label(window, "Show Highlights", nil, 60, -355, 220)
    -- Center Lines and Grid draw on the screen behind the elements (PositionGrid.lua).
    local function ScreenToggle(x, text, get, set)
        local box = W.Button(window, "", 30, 30, "checkbox")
        box:SetPoint("TOPLEFT", x, -386)
        box:SetScript("OnClick", function() set(not get()); self:RefreshEditWindow() end)
        box.text = W.Label(window, text, nil, x + 40, -393, 110)
        return box
    end
    local centerLines = ScreenToggle(20, "Center Lines", function() return E.centerLines end, function(on) E:SetCenterLines(on) end)
    local grid = ScreenToggle(176, "Grid", function() return E.grid end, function(on) E:SetGrid(on) end)
    local settings = W.Button(window, "Open Module Settings", 300, 30)
    settings:SetPoint("TOPLEFT", 20, -424)
    settings:SetScript("OnClick", function()
        if InCombatLockdown() or UnitAffectingCombat("player") then
            print("ModeUI: open element settings outside combat.")
            return
        end
        local element = E:Selected()
        if not element or not self.modules[element.module.id] then return end
        local id, module, elementId = element.module.id, element.module, element.id
        self:SetEditMode(false)
        -- A standalone module opens its own window on the chosen element.
        if module.standalone then
            if module.OpenSettings then module:OpenSettings(elementId) end
            return
        end
        self:SelectConfigPage(id)
        -- A module with several elements can open its page on the chosen one.
        if module.OpenElementSettings then module:OpenElementSettings(elementId) end
    end)
    local exit = W.Button(window, "Exit", 300, 32)
    exit:SetPoint("TOPLEFT", 20, -462)
    exit:SetSelected(true)
    exit:SetScript("OnClick", function() self:SetEditMode(false) end)
    function self:RefreshEditWindow()
        if refreshing then return end
        refreshing = true
        local element = E:Selected()
        selected:SetText(element and (element.label or element.module.title) or "No enabled movable element")
        settings:SetEnabled(element ~= nil and self.modules[element.module.id] ~= nil)
        local anchoring = element ~= nil and element.supportsAnchoring == true
        local available = element ~= nil and (not anchoring or P:Resolve(element.position.target or "screen") ~= nil)
        xInput:SetEnabled(available)
        yInput:SetEnabled(available)
        xSlider:SetEnabled(available); ySlider:SetEnabled(available)
        refreshX(); refreshY()
        targets:SetEnabled(anchoring); placements:SetEnabled(anchoring and available); reset:SetEnabled(anchoring and available)
        for axis, box in pairs({ width = matchWidth, height = matchHeight }) do
            local can = element ~= nil and self.PositionManager:CanMatchSize(element.id, axis)
            box:SetEnabled(can); box:SetSelected(can and self.PositionManager:GetSizeMatch(element.id, axis))
            box.text:SetAlpha(can and 1 or 0.45)
        end
        local picking = self.EditAnchor:Active()
        anchorTo:SetEnabled(picking or self.EditAnchor:CanPick(element))
        anchorTo:SetSelected(picking)
        anchorTo.label:SetText(picking and "Cancel" or "Anchor To...")
        targets:Refresh(); placements:Refresh()
        highlights:SetSelected(E.highlights)
        centerLines:SetSelected(E.centerLines); grid:SetSelected(E.grid)
        refreshing = false
    end
    -- Clearing focus runs the numeric input's normal apply.
    function self:CommitEditInputs() xInput:ClearFocus(); yInput:ClearFocus() end
    window.xInput, window.yInput = xInput, yInput
    window.xSlider, window.ySlider = xSlider, ySlider
    window.targetDropdown, window.placementDropdown, window.resetOffset = targets, placements, reset
    window.anchorToButton = anchorTo
    window.matchWidthButton, window.matchHeightButton = matchWidth, matchHeight
    window.settingsButton, window.exitButton, window.highlightButton = settings, exit, highlights
    window.centerLinesButton, window.gridButton = centerLines, grid
    window.selectedLabel = selected
    window:EnableKeyboard(true)
    window:SetPropagateKeyboardInput(true)
    window:SetScript("OnKeyDown", function(_, key)
        if InCombatLockdown() or UnitAffectingCombat("player") then return end
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
    window:SetScript("OnHide", function()
        targets.menu:Hide(); placements.menu:Hide()
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
