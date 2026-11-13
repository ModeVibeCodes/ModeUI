local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets

-- A compass of anchor buttons around a small plate: click where something
-- should sit. Each button shows a dot on the side it stands for, and the
-- chosen anchor's name is written beside the compass.
local GRID = { { "TOPLEFT", "TOP", "TOPRIGHT" }, { "LEFT", false, "RIGHT" }, { "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" } }
local CELL_WIDTH, CELL_HEIGHT, GAP = 34, 20, 4
W.ANCHOR_PICKER_HEIGHT = 3 * CELL_HEIGHT + 2 * GAP

-- getter() returns the anchor; setter(anchor) picks one; labels names them.
-- Returns the buttons keyed by anchor and a refresher.
function W.AnchorPicker(parent, getter, setter, labels)
    local buttons = {}
    for row, line in ipairs(GRID) do
        for column, point in ipairs(line) do
            local x, y = (column - 1) * (CELL_WIDTH + GAP), -(row - 1) * (CELL_HEIGHT + GAP)
            if point then
                local button = W.Button(parent, "", CELL_WIDTH, CELL_HEIGHT, "choice")
                button:SetPoint("TOPLEFT", x, y)
                button:SetScript("OnClick", function() setter(point) end)
                button.anchorPoint = point
                local dot = button:CreateTexture(nil, "OVERLAY")
                W.Paint(dot, T.text)
                dot:SetSize(6, 4)
                dot:SetPoint(point, button, point, (point:find("LEFT") and 4) or (point:find("RIGHT") and -4) or 0,
                    (point:find("TOP") and -4) or (point:find("BOTTOM") and 4) or 0)
                button.dot = dot
                buttons[point] = button
            else
                -- The plate the anchors surround.
                local plate = parent:CreateTexture(nil, "ARTWORK")
                W.Paint(plate, T.lineStrong or T.line)
                plate:SetSize(CELL_WIDTH, 8)
                plate:SetPoint("TOPLEFT", x, y - (CELL_HEIGHT - 8) / 2)
                buttons.plate = plate
            end
        end
    end
    local label = W.Label(parent, "", nil, 3 * (CELL_WIDTH + GAP) + 6, -(CELL_HEIGHT + GAP) - 3, 140, T.muted)
    local function Refresh()
        local value = getter()
        for _, line in ipairs(GRID) do
            for _, point in ipairs(line) do
                if point then buttons[point]:SetSelected(point == value) end
            end
        end
        label:SetText(labels and labels[value] or tostring(value))
    end
    buttons.label = label
    return buttons, Refresh
end
