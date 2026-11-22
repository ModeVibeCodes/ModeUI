local _, addon = ...
local W, T = addon.ConfigWidgets, addon.InterfaceTheme
-- Edit Mode's element panel (docs/DESIGN_LANGUAGE.md, "Edit Mode"): it docks
-- beside the selected element, on the side with more room and never over it
-- (Pin keeps it at the screen's right edge instead; a panel you drag stays
-- where you put it until you pick another module's element). Header: the
-- element's name and module, Pin, and close (clears the selection). Two tabs:
-- **Settings**, the module's own page scoped to the element (EditPage.lua),
-- and **Place**: Position (X and Y), Snap To (what it hangs from, Anchor To…,
-- its side, Reset Offset) and Match Size (Match Width and Match Height: click
-- one, then the element whose width or height to take; again to stop).
-- Open Page leaves Edit Mode for the module's page in the settings window.
local WIDTH, HEIGHT, PAD, TOP = 432, 560, 14, 82
addon.EDIT_PANEL_SIZE = { WIDTH, HEIGHT }
local GAP = 16 -- between the element and the docked panel
local Combat = addon.InCombat

-- Small owned dropdown; options are rebuilt on open, never polled.
local function Dropdown(parent, width, choices, getter, setter)
    local button = W.Button(parent, "", width, 24, "dropdown")
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
        if Combat() then return end
        if parent.anchorMenu and parent.anchorMenu ~= menu then parent.anchorMenu:Hide() end
        parent.anchorMenu = menu
        menu:SetShown(not menu:IsShown()); button:Refresh()
    end)
    button.menu, button.rows = menu, rows
    return button
end

-- A small uppercase caption above a group of controls.
local function Caption(parent, text, y)
    local label = W.Label(parent, text, nil, PAD, y, WIDTH - 2 * PAD, T.secondary)
    addon.Media:BindInterfaceFont(label, GameFontHighlight, T.fontSize.group, nil, "heading")
    return label
end

-- Opens the selected element's module settings (its page, or a standalone
-- module's own window), leaving Edit Mode.
function addon:OpenEditedElementSettings()
    if Combat() then print("ModeUI: open element settings outside combat."); return end
    local element = self.EditMode:Selected()
    if not element or not self.modules[element.module.id] then return end
    local id, module, elementId = element.module.id, element.module, element.id
    self:SetEditMode(false)
    if module.standalone then
        if module.OpenSettings then module:OpenSettings(elementId) end
        return
    end
    self:SelectConfigPage(id)
    if module.OpenElementSettings then module:OpenElementSettings(elementId) end
end

-- The Place tab's controls in `view`; every control goes on `controls` by name.
local function BuildPlace(self, view, controls)
    local E, PM, P, A = self.EditMode, self.PositionManager, self.Positioning, self.EditAnchor
    local state = { refreshing = false }
    Caption(view, "POSITION", -6)
    local function Coordinate(axis, top)
        local function Get()
            local element = E:Selected()
            if not element then return 0 end
            local px, py = PM:GetOffsets(element.id)
            return axis == "x" and px or py
        end
        local function Limits()
            local element = E:Selected()
            if not element then return 0, 0 end
            local lx, hx, ly, hy = E:CoordinateBounds(element)
            if axis == "x" then return lx, hx end
            return ly, hy
        end
        W.Label(view, axis:upper(), nil, PAD, top - 8, 14, T.secondary)
        local holder = CreateFrame("Frame", nil, view)
        holder:SetPoint("TOPLEFT", PAD + 18, top); holder:SetSize(WIDTH - 2 * PAD - 18, 30)
        local low, high = Limits()
        local function Set(value) if not state.refreshing then E:SetCoordinate(axis, value) end end
        local refresh = W.Slider(holder, low, high, 5, Get, Set, "", {
            minimum = function() local l = Limits(); return l end,
            maximum = function() local _, h = Limits(); return h end,
        })
        local input, slider = holder.numericInput, holder.slider
        input:SetWidth(64)
        slider:SetPoint("RIGHT", -74, 0)
        return input, slider, function()
            local l, h = Limits()
            slider:SetMinMaxValues(l, h)
            refresh()
        end
    end
    local xInput, xSlider, refreshX = Coordinate("x", -22)
    local yInput, ySlider, refreshY = Coordinate("y", -56)

    Caption(view, "SNAP TO", -100)
    local function Position()
        local element = E:Selected()
        return element and PM:GetPosition(element.id)
    end
    local half = math.floor((WIDTH - 2 * PAD - 8) / 2)
    local targets = Dropdown(view, half, function()
        local element = E:Selected()
        return PM:GetAllowedTargets(element and element.id)
    end, function()
        local position = Position()
        local id = position and position.target or "screen"
        if addon.FrameAnchors:ValidID(id) then return id, id:sub(7) .. (P:Resolve(id) and "" or " (unavailable)") end
        for _, target in ipairs(P.targets) do
            if target.id == id then return id, target.label .. (P:Resolve(id) and "" or " (unavailable)") end
        end
        return id, "Saved target unavailable"
    end, function(id) E:SetTarget(id) end)
    targets:SetPoint("TOPLEFT", PAD, -118)
    local anchorTo = W.Button(view, "Anchor To...", half, 24, "secondary")
    anchorTo:SetPoint("TOPLEFT", PAD + half + 8, -118)
    anchorTo:SetScript("OnClick", function()
        local element = E:Selected()
        if A:Active() and not A:Matching() then A:Stop() elseif element then A:Start(element.id) end
        self:RefreshEditWindow()
    end)
    local placements = Dropdown(view, half, function() return P.placements end, function()
        local p = Position()
        local placement = P:Placement(p and p.placement)
        return placement.id, placement.label
    end, function(id) E:SetPlacement(id) end)
    placements:SetPoint("TOPLEFT", PAD, -150)
    local reset = W.Button(view, "Reset Offset", half, 24, "secondary")
    reset:SetPoint("TOPLEFT", PAD + half + 8, -150)
    reset:SetScript("OnClick", function() E:ResetOffset() end)

    Caption(view, "MATCH SIZE", -194)
    local function Match(axis, x)
        local button = W.Button(view, "", half, 24, "secondary")
        button:SetPoint("TOPLEFT", x, -212)
        button:SetScript("OnClick", function()
            local element = E:Selected()
            if not element then return end
            if A:Matching() == axis then A:Stop()
            elseif PM:GetSizeMatch(element.id, axis) then PM:SetSizeMatchValue(element.id, axis, false)
            else A:Start(element.id, axis) end
            self:RefreshEditWindow()
        end)
        return button
    end
    local matchWidth, matchHeight = Match("width", PAD), Match("height", PAD + half + 8)
    local matched = W.Label(view, "", nil, PAD, -246, WIDTH - 2 * PAD, T.muted)
    matched:SetWordWrap(true)
    local function MatchText(element, axis)
        if not element or not PM:GetSizeMatch(element.id, axis) then return "off" end
        local target = PM:GetSizeMatchTarget(element.id, axis)
        return target and A:TargetLabel(target) or "nothing yet"
    end
    function state.Refresh()
        state.refreshing = true
        local element = E:Selected()
        local anchoring = element ~= nil and element.supportsAnchoring == true
        local available = element ~= nil and (not anchoring or P:Resolve(element.position.target or "screen") ~= nil)
        xInput:SetEnabled(available); yInput:SetEnabled(available)
        xSlider:SetEnabled(available); ySlider:SetEnabled(available)
        refreshX(); refreshY()
        targets:SetEnabled(anchoring); placements:SetEnabled(anchoring and available); reset:SetEnabled(anchoring and available)
        local picking, axisPick = A:Active(), A:Matching()
        anchorTo:SetEnabled((picking and not axisPick) or A:CanPick(element))
        anchorTo:SetSelected(picking and not axisPick)
        anchorTo.label:SetText(picking and not axisPick and "Cancel" or "Anchor To...")
        for axis, button in pairs({ width = matchWidth, height = matchHeight }) do
            local can = element ~= nil and PM:CanMatchSize(element.id, axis)
            local on = can and PM:GetSizeMatch(element.id, axis)
            button:SetEnabled(can or axisPick == axis)
            button:SetSelected(on or axisPick == axis)
            button.label:SetText(axisPick == axis and "Cancel" or (axis == "width" and "Match Width" or "Match Height"))
        end
        matched:SetText(element and ("Width: " .. MatchText(element, "width") .. "\nHeight: " .. MatchText(element, "height")) or "")
        targets:Refresh(); placements:Refresh()
        state.refreshing = false
    end
    function state.Hide() targets.menu:Hide(); placements.menu:Hide() end
    controls.xInput, controls.yInput, controls.xSlider, controls.ySlider = xInput, yInput, xSlider, ySlider
    controls.targetDropdown, controls.placementDropdown, controls.resetOffset = targets, placements, reset
    controls.anchorToButton, controls.matchWidthButton, controls.matchHeightButton = anchorTo, matchWidth, matchHeight
    controls.matchedLabel = matched
    return state
end

-- Builds the panel; `controls` (the top bar) gets every control by name, so
-- callers find them on addon.editWindow as before.
function addon:CreateEditPanel(strip, controls)
    local E, P = self.EditMode, self.Positioning
    local panel = CreateFrame("Frame", "ModeUIEditPanel", UIParent)
    panel:Hide(); panel:SetSize(WIDTH, HEIGHT)
    panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -72)
    panel:SetFrameStrata("DIALOG"); panel:SetFrameLevel(80)
    panel:SetMovable(true); panel:SetClampedToScreen(true); panel:EnableMouse(true)
    W.Texture(panel, "Window"); W.Texture(panel, "BorderSilver", "BORDER")
    self.editPanel = panel
    local drag = CreateFrame("Frame", nil, panel)
    drag:SetPoint("TOPLEFT", 6, -6); drag:SetPoint("TOPRIGHT", -110, -6); drag:SetHeight(34)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() if not Combat() then panel:StartMoving() end end)
    drag:SetScript("OnDragStop", function() panel:StopMovingOrSizing(); panel.userMoved = panel.dockedModule end)
    local selected = W.Heading(panel, "", T.fontSize.section, PAD, -12, WIDTH - 2 * PAD - 110, T.text)
    selected:SetWordWrap(false)
    local owner = W.Label(panel, "", nil, PAD, -32, WIDTH - 2 * PAD - 110, T.muted)
    owner:SetWordWrap(false)
    local close = W.Button(panel, "×", 26, 24, "secondary"); close:SetPoint("TOPRIGHT", -PAD + 4, -10)
    close:SetScript("OnClick", function() self.PositionManager:ClearSelection() end)
    local pin = W.Button(panel, "Pin", 52, 24, "secondary"); pin:SetPoint("RIGHT", close, "LEFT", -6, 0)
    pin:SetScript("OnClick", function() panel.pinned = not panel.pinned; panel.dockedFor = nil; self:RefreshEditWindow() end)

    -- Settings and Place, and Open Page at the right.
    local function Tab(text, x)
        local button = W.Button(panel, text, 92, 26, "choice"); button:SetPoint("TOPLEFT", x, -50)
        return button
    end
    local settingsTab, placeTab = Tab("Settings", PAD), Tab("Place", PAD + 96)
    local settings = W.Button(panel, "Open Page", 92, 26, "secondary")
    settings:SetPoint("TOPRIGHT", -PAD + 2, -50)
    settings:SetScript("OnClick", function() self:OpenEditedElementSettings() end)
    local divider = W.Fill(panel, T.line, "BORDER")
    divider:ClearAllPoints(); divider:SetPoint("TOPLEFT", 8, -TOP + 2); divider:SetPoint("TOPRIGHT", -8, -TOP + 2); divider:SetHeight(1)
    local host = CreateFrame("Frame", nil, panel)
    host:SetPoint("TOPLEFT", 6, -TOP - 6); host:SetPoint("BOTTOMRIGHT", -2, 8)
    local place = CreateFrame("Frame", nil, panel)
    place:SetPoint("TOPLEFT", 0, -TOP - 4); place:SetPoint("BOTTOMRIGHT", 0, 8)
    local none = W.Label(host, "", nil, 8, -8, WIDTH - 2 * PAD, T.muted); none:SetWordWrap(true)
    local placeState = BuildPlace(self, place, controls)
    panel.view = "settings"
    settingsTab:SetScript("OnClick", function() panel.view = "settings"; self:RefreshEditWindow() end)
    placeTab:SetScript("OnClick", function() panel.view = "place"; self:RefreshEditWindow() end)

    -- Docks the panel beside the element: the side with more room, top edges
    -- level (kept on screen); pinned, at the screen's right edge.
    function panel:Dock(element)
        if self.pinned then
            self:ClearAllPoints(); self:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -72); return
        end
        if self.userMoved and self.userMoved == element.module.id then return end
        self.userMoved = nil
        local x, y, w, h = P:Geometry(element.frame)
        local scale = self:GetScale() > 0 and self:GetScale() or 1
        if not x then self:ClearAllPoints(); self:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -72); return end
        local width, height = WIDTH * scale, HEIGHT * scale
        local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
        local rightRoom, leftRoom = screenW - (x + w / 2), x - w / 2
        local left
        if rightRoom >= width + GAP or rightRoom >= leftRoom then left = x + w / 2 + GAP else left = x - w / 2 - GAP - width end
        left = math.max(8, math.min(screenW - width - 8, left))
        local top = math.max(height + 8, math.min(screenH - 64, y + h / 2))
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / scale, top / scale)
    end

    function panel:Refresh()
        if placeState.refreshing then return end
        local element = E:Selected()
        selected:SetText(element and (element.label or element.module.title) or "No enabled movable element")
        owner:SetText(element and element.module.title or "")
        settings:SetEnabled(element ~= nil and addon.modules[element.module.id] ~= nil)
        pin:SetSelected(self.pinned == true)
        local page
        if element and self:IsShown() then
            page = addon.EditPage:Borrow(element.module, host, element.id)
            if self.dockedFor ~= element.id then self.dockedModule = element.module.id; self:Dock(element); self.dockedFor = element.id end
        end
        local view = page and self.view or "place"
        settingsTab:SetEnabled(page ~= nil)
        settingsTab:SetSelected(view == "settings"); placeTab:SetSelected(view == "place")
        host:SetShown(view == "settings"); place:SetShown(view == "place")
        none:SetShown(page == nil)
        none:SetText(element and element.module.standalone and "Open Page opens this module's own settings window." or "")
        if page and view == "settings" and not page:IsShown() then page:Show(); page:Layout()
        elseif page and view ~= "settings" then page:Hide() end
        placeState.Refresh()
    end
    panel:SetScript("OnHide", function()
        placeState.Hide(); panel:StopMovingOrSizing()
        addon.EditPage:Return()
        panel.dockedFor = nil
    end)
    controls.settingsButton, controls.selectedLabel, controls.panel = settings, selected, panel
    controls.settingsTab, controls.placeTab, controls.pinButton, controls.closeButton = settingsTab, placeTab, pin, close
    controls.settingsHost, controls.ownerLabel = host, owner
    return panel
end
