local _, addon = ...
local W, T = addon.ConfigWidgets, addon.InterfaceTheme

-- Multi-cell rows for a settings page (W.Page): labeled columns and toggle
-- grids. Both keep their own cell layout (plain rows, not stacked).
local CELL_MIN = 120
function W.PageControls(page, ROW_HEIGHT)
    local self = page
    -- One row of labeled cells side by side (sliders, choices, colors). Returns
    -- a control host per title; each host is laid out under its own label.
    function self:Columns(titles, height)
        local controls = self:Row("", height or 60, nil, true)
        local row = controls.row
        controls.rowLabel:Hide()
        controls:ClearAllPoints(); controls:SetAllPoints(row)
        table.remove(self.searchEntries) -- replace the empty row metadata
        local cells, hosts = {}, {}
        for i, title in ipairs(titles) do
            local cell = CreateFrame("Frame", nil, controls)
            cell.label = W.Label(cell, title, nil, 0, -2, 200, T.secondary)
            local host = CreateFrame("Frame", nil, cell)
            host:SetPoint("TOPLEFT", 0, -24); host:SetPoint("BOTTOMRIGHT", 0, 8)
            host.row, host.rowLabel = row, cell.label
            host.valueAnchor = CreateFrame("Frame", nil, cell)
            host.valueAnchor:SetPoint("TOPRIGHT", 0, 0); host.valueAnchor:SetSize(72, 20)
            cells[i], hosts[i] = cell, host
            self.searchEntries[#self.searchEntries + 1] = { label = title, section = self.activeSection, row = row, kind = "setting" }
        end
        -- Cells share a line; when a line can't give each one CELL_MIN, they
        -- wrap onto more lines (docs/DESIGN_LANGUAGE.md, "Settings window").
        local lineHeight = row:GetHeight()
        function row:layoutChildren(width)
            local gap = 24
            local perLine = math.max(1, math.min(#cells, math.floor((width + gap) / (CELL_MIN + gap))))
            local cellWidth = (width - gap * (perLine - 1)) / perLine
            for i, cell in ipairs(cells) do
                local column, line = (i - 1) % perLine, math.floor((i - 1) / perLine)
                cell:ClearAllPoints(); cell:SetPoint("TOPLEFT", column * (cellWidth + gap), -line * lineHeight)
                cell:SetSize(cellWidth, lineHeight); cell.label:SetWidth(cellWidth)
            end
            self:SetHeight(lineHeight * math.ceil(#cells / perLine))
        end
        row.settingsColumns, row.settingsTitles = cells, titles
        return hosts
    end
    -- Things to pick several of (windows, bars), as buttons that stay lit while
    -- chosen; they wrap to as many per line as fit. items: { label, get, set }.
    function self:ChoiceGrid(items, options)
        local controls = self:Row("", ROW_HEIGHT, nil, true)
        local row = controls.row
        controls.rowLabel:Hide()
        controls:ClearAllPoints(); controls:SetAllPoints(row)
        table.remove(self.searchEntries)
        local buttons = {}
        for i, item in ipairs(items) do
            local button = W.Button(controls, item.label, 120, 26, "choice")
            button:SetScript("OnClick", function() item.set(not item.get()); self:Refresh() end)
            self.refreshers[#self.refreshers + 1] = function() button:SetSelected(item.get() == true) end
            self.searchEntries[#self.searchEntries + 1] = { label = item.label, section = self.activeSection, row = row, kind = "setting" }
            buttons[i] = button
        end
        local minimum, gap, height = options and options.minimumWidth or 110, 6, 26
        function row:layoutChildren(width)
            local perLine = math.max(1, math.min(#buttons, math.floor((width + gap) / (minimum + gap))))
            local cellWidth = math.floor((width - gap * (perLine - 1)) / perLine)
            for i, button in ipairs(buttons) do
                local column, line = (i - 1) % perLine, math.floor((i - 1) / perLine)
                button:ClearAllPoints(); button:SetPoint("TOPLEFT", column * (cellWidth + gap), -4 - line * (height + gap))
                button:SetWidth(cellWidth)
            end
            self:SetHeight(8 + math.ceil(#buttons / perLine) * (height + gap) - gap)
        end
        row.settingsChoices = buttons
        return buttons
    end
    -- Full-cell click targets and per-setting search entries; wraps to 1-3
    -- columns. Each cell is a switch with its label 10 px to the right.
    function self:ToggleGrid(items, options)
        local controls = self:Row("", ROW_HEIGHT, nil, true)
        local row = controls.row
        controls.rowLabel:Hide()
        controls:ClearAllPoints(); controls:SetAllPoints(row)
        local cells = {}
        table.remove(self.searchEntries) -- replace the empty row metadata
        for i, item in ipairs(items) do
            local cell = CreateFrame("Button", nil, controls)
            cell:EnableMouse(true); cell:RegisterForClicks("LeftButtonUp")
            local toggle = W.Button(cell, "", 28, 28, "checkbox")
            toggle:SetPoint("LEFT", 0, 0)
            local label = W.Label(cell, item.label, nil, 0, 0, 120)
            label:ClearAllPoints(); label:SetPoint("LEFT", toggle, "RIGHT", 10, 0)
            label:SetWordWrap(true)
            local function Click() item.set(not item.get()); self:Refresh() end
            cell:SetScript("OnClick", Click); toggle:SetScript("OnClick", Click)
            -- The whole cell is the hit target, so hovering it lights the box too.
            cell:HookScript("OnEnter", function() toggle.hovered = true; toggle:RefreshAppearance() end)
            cell:HookScript("OnLeave", function() toggle.hovered = false; toggle:RefreshAppearance() end)
            self.refreshers[#self.refreshers + 1] = function() toggle:SetSelected(item.get()) end
            self.searchEntries[#self.searchEntries + 1] = {label=item.label,section=self.activeSection,row=row,kind="setting"}
            cells[i] = {frame=cell,button=toggle,label=label}
        end
        function row:layoutChildren(width)
            local columns = math.max(1, math.min(options and options.maxColumns or 3, #items, math.floor(width / (options and options.minimumCellWidth or 180))))
            local cellWidth = width / columns
            self:SetHeight(math.ceil(#items / columns) * ROW_HEIGHT)
            for i, cell in ipairs(cells) do
                cell.frame:ClearAllPoints(); cell.frame:SetSize(cellWidth, ROW_HEIGHT)
                cell.frame:SetPoint("TOPLEFT", ((i-1)%columns)*cellWidth, -math.floor((i-1)/columns)*ROW_HEIGHT)
                cell.label:SetWidth(cellWidth-78)
            end
        end
        self.toggleGrids = self.toggleGrids or {}; self.toggleGrids[#self.toggleGrids+1] = cells
        row.settingsToggles=cells
        return cells
    end
end
