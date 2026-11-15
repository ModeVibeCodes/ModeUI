local _, addon = ...
local W, T = addon.ConfigWidgets, addon.InterfaceTheme
-- Edit Mode's element panel: a small popup under the Edit Mode strip
-- (EditMode.lua) for the selected element. Its name and a small Settings
-- button (the module's page), then Position (X and Y), Snap To (what it hangs
-- from, Anchor To..., its side, Reset Offset) and Match Size (Match Width and
-- Match Height: click one, then the element whose width or height to take;
-- click it again to stop matching). Drag its title to move it.
local WIDTH, HEIGHT, PAD = 296, 300, 14
addon.EDIT_PANEL_SIZE = { WIDTH, HEIGHT }
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

-- Builds the panel; `controls` (the strip) gets every control by name, so
-- callers find them on addon.editWindow as before.
function addon:CreateEditPanel(strip, controls)
    local E, PM, P, A = self.EditMode, self.PositionManager, self.Positioning, self.EditAnchor
    local panel = CreateFrame("Frame", "ModeUIEditPanel", UIParent)
    panel:Hide(); panel:SetSize(WIDTH, HEIGHT)
    panel:SetPoint("TOP", strip, "BOTTOM", 0, -8)
    panel:SetFrameStrata("DIALOG"); panel:SetFrameLevel(80)
    panel:SetMovable(true); panel:SetClampedToScreen(true); panel:EnableMouse(true)
    W.Texture(panel, "Window"); W.Texture(panel, "BorderSilver", "BORDER")
    self.editPanel = panel
    local drag = CreateFrame("Frame", nil, panel)
    drag:SetPoint("TOPLEFT", 6, -6); drag:SetPoint("TOPRIGHT", -92, -6); drag:SetHeight(30)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() if not Combat() then panel:StartMoving() end end)
    drag:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
    local selected = W.Heading(panel, "", T.fontSize.section, PAD, -14, WIDTH - 2 * PAD - 84, T.text)
    selected:SetWordWrap(false)
    local settings = W.Button(panel, "Settings", 76, 22, "secondary")
    settings:SetPoint("TOPRIGHT", -PAD + 2, -10)
    settings:SetScript("OnClick", function() self:OpenEditedElementSettings() end)

    -- Position: X and Y, each a slider with its number.
    local refreshing
    Caption(panel, "POSITION", -44)
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
        W.Label(panel, axis:upper(), nil, PAD, top - 8, 14, T.secondary)
        local holder = CreateFrame("Frame", nil, panel)
        holder:SetPoint("TOPLEFT", PAD + 18, top); holder:SetSize(WIDTH - 2 * PAD - 18, 30)
        local low, high = Limits()
        local function Set(value) if not refreshing then E:SetCoordinate(axis, value) end end
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
    local xInput, xSlider, refreshX = Coordinate("x", -58)
    local yInput, ySlider, refreshY = Coordinate("y", -92)

    -- Snap To: what it hangs from and on which side.
    Caption(panel, "SNAP TO", -132)
    local function Position()
        local element = E:Selected()
        return element and PM:GetPosition(element.id)
    end
    local targets = Dropdown(panel, 156, function()
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
    targets:SetPoint("TOPLEFT", PAD, -148)
    local anchorTo = W.Button(panel, "Anchor To...", WIDTH - 2 * PAD - 162, 24, "secondary")
    anchorTo:SetPoint("TOPLEFT", PAD + 162, -148)
    anchorTo:SetScript("OnClick", function()
        local element = E:Selected()
        if A:Active() and not A:Matching() then A:Stop() elseif element then A:Start(element.id) end
        self:RefreshEditWindow()
    end)
    local placements = Dropdown(panel, 156, function() return P.placements end, function()
        local p = Position()
        local placement = P:Placement(p and p.placement)
        return placement.id, placement.label
    end, function(id) E:SetPlacement(id) end)
    placements:SetPoint("TOPLEFT", PAD, -178)
    local reset = W.Button(panel, "Reset Offset", WIDTH - 2 * PAD - 162, 24, "secondary")
    reset:SetPoint("TOPLEFT", PAD + 162, -178)
    reset:SetScript("OnClick", function() E:ResetOffset() end)

    -- Match Size: each axis follows an element picked for it.
    Caption(panel, "MATCH SIZE", -216)
    local half = math.floor((WIDTH - 2 * PAD - 6) / 2)
    local function Match(axis, x)
        local button = W.Button(panel, "", half, 24, "secondary")
        button:SetPoint("TOPLEFT", x, -232)
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
    local matchWidth, matchHeight = Match("width", PAD), Match("height", PAD + half + 6)
    local matched = W.Label(panel, "", nil, PAD, -264, WIDTH - 2 * PAD, T.muted)
    matched:SetWordWrap(true)

    local function MatchText(element, axis)
        if not element or not PM:GetSizeMatch(element.id, axis) then return "off" end
        local target = PM:GetSizeMatchTarget(element.id, axis)
        return target and A:TargetLabel(target) or "nothing yet"
    end
    function panel:Refresh()
        if refreshing then return end
        refreshing = true
        local element = E:Selected()
        selected:SetText(element and (element.label or element.module.title) or "No enabled movable element")
        settings:SetEnabled(element ~= nil and addon.modules[element.module.id] ~= nil)
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
        refreshing = false
    end
    panel:SetScript("OnHide", function() targets.menu:Hide(); placements.menu:Hide(); panel:StopMovingOrSizing() end)

    controls.xInput, controls.yInput, controls.xSlider, controls.ySlider = xInput, yInput, xSlider, ySlider
    controls.targetDropdown, controls.placementDropdown, controls.resetOffset = targets, placements, reset
    controls.anchorToButton, controls.matchWidthButton, controls.matchHeightButton = anchorTo, matchWidth, matchHeight
    controls.matchedLabel, controls.settingsButton, controls.selectedLabel, controls.panel = matched, settings, selected, panel
    return panel
end
