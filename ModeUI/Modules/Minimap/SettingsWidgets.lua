local _, addon = ...
local M, W, T, L = addon.Minimap, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The Minimap page's own controls, on the shared widgets: segmented choices
-- sized to their cell, a switch under a column label, color swatches, and a
-- Blizzard button row (switch and corner picker). Defined here, built only
-- when the page is opened.
local SWATCH, SWATCH_GAP = 26, 6
local CORNER_LABELS = { TOPLEFT = "Top Left", TOPRIGHT = "Top Right", BOTTOMLEFT = "Bottom Left", BOTTOMRIGHT = "Bottom Right" }
local ROW_HEIGHT = 36

M.SettingsUI = {}
local UI = M.SettingsUI

-- A choice list from Init's M.choices, each segment `width` wide.
function UI.Segments(page, host, key, width, set)
    local choices = {}
    for _, item in ipairs(M.choices[key]) do choices[#choices + 1] = { label = L[item.label], value = item.id, width = width } end
    local buttons, refresh = W.Exclusive(host, choices, function() return M.db[key] end,
        set or function(value) M:SetOption(key, value) end)
    page.refreshers[#page.refreshers + 1] = refresh
    return buttons
end

-- A switch at the left of a column cell, under the cell's label.
function UI.Switch(page, host, key)
    local toggle = W.Button(host, "", 28, 28, "checkbox")
    toggle:SetPoint("LEFT", 0, 0)
    toggle:SetScript("OnClick", function() M:SetOption(key, not M.db[key]); page:Refresh() end)
    page.refreshers[#page.refreshers + 1] = function() toggle:SetSelected(M.db[key] == true) end
    return toggle
end

-- Border Color: a swatch per choice; the chosen one has a light ring.
function UI.Swatches(page, host)
    local swatches = {}
    for index, item in ipairs(M.choices.borderColor) do
        local button = CreateFrame("Button", nil, host)
        button:SetSize(SWATCH, SWATCH)
        button:SetPoint("LEFT", host, "LEFT", (index - 1) * (SWATCH + SWATCH_GAP), 0)
        button.ring = W.Shape(button, "ModeFlat", "BACKGROUND")
        button.ring:SetPoint("TOPLEFT", -2, 2); button.ring:SetPoint("BOTTOMRIGHT", 2, -2)
        button.color = W.Shape(button, "ModeFlat", "ARTWORK")
        button.color:SetAllPoints()
        button.id = item.id
        button:SetScript("OnClick", function() M:SetOption("borderColor", item.id); page:Refresh() end)
        button:SetScript("OnEnter", function(self)
            if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(L[item.label]); GameTooltip:Show() end
        end)
        button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        swatches[index] = button
    end
    page.refreshers[#page.refreshers + 1] = function()
        local chosen = M.db.borderColor
        for _, button in ipairs(swatches) do
            local color = button.id == "class" and M.BorderColorFor("class") or M.BORDER_COLORS[button.id]
            button.color:SetVertexColor(color[1], color[2], color[3], 1)
            local ring = button.id == chosen and T.text or T.rim
            button.ring:SetVertexColor(ring[1], ring[2], ring[3], button.id == chosen and 1 or 0.6)
        end
    end
    return swatches
end

-- The corner picker: the four corners by name (side by side when they fit,
-- else a dropdown, as every Mode segmented control).
function UI.CornerPicker(page, host, name)
    local choices = {}
    for _, corner in ipairs(M.CORNERS) do choices[#choices + 1] = { label = L[CORNER_LABELS[corner]], value = corner, width = 96 } end
    local buttons, refresh = W.Exclusive(host, choices, function() return M.db.buttons[name].corner end,
        function(value) M:SetButton(name, "corner", value); page:Refresh() end)
    page.refreshers[#page.refreshers + 1] = refresh
    return buttons
end

-- A Blizzard button: its switch and label at the left, the corner picker at
-- the right, on one line.
function UI.ButtonRow(page, name)
    local controls = page:Row("", ROW_HEIGHT, nil, true)
    local row = controls.row
    controls.rowLabel:Hide()
    controls:ClearAllPoints(); controls:SetAllPoints(row)
    table.remove(page.searchEntries)
    local label = L[M.BUTTON_LABELS[name]]
    page.searchEntries[#page.searchEntries + 1] = { label = label, section = page.activeSection, row = row, kind = "setting" }
    local left = CreateFrame("Button", nil, controls)
    left:RegisterForClicks("LeftButtonUp")
    local toggle = W.Button(left, "", 28, 28, "checkbox")
    toggle:SetPoint("LEFT", 0, 0)
    local text = W.Label(left, label, nil, 0, 0, 160)
    text:ClearAllPoints(); text:SetPoint("LEFT", toggle, "RIGHT", 10, 0)
    local function Click() M:SetButton(name, "shown", not M.db.buttons[name].shown); page:Refresh() end
    left:SetScript("OnClick", Click); toggle:SetScript("OnClick", Click)
    page.refreshers[#page.refreshers + 1] = function() toggle:SetSelected(M.db.buttons[name].shown) end
    local right = CreateFrame("Frame", nil, controls)
    right.row, right.rowLabel = row, text
    local picker = UI.CornerPicker(page, right, name)
    function row:layoutChildren(width)
        local half = (width - 24) / 2
        left:ClearAllPoints(); left:SetPoint("TOPLEFT", 0, 0); left:SetSize(half, ROW_HEIGHT)
        right:ClearAllPoints(); right:SetPoint("TOPLEFT", half + 24, 0); right:SetSize(half, ROW_HEIGHT)
        text:SetWidth(math.max(40, half - 46))
    end
    return { toggle = toggle, picker = picker, row = row }
end
