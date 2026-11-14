local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets

-- Four arrow buttons that move something one pixel at a time (owner,
-- November 13, 2026: nudge auras, texts and icons into perfect alignment).
-- The arrows are the dropdown chevron, turned, as on Edit Mode's nudges.
-- getX/getY return the offsets; setX/setY store them; range = { min, max }
-- keeps them inside what the settings accept. Returns the buttons (left, up,
-- down, right), left to right from the host's left edge.
local NUDGES = { { -1, 0, -math.pi / 2 }, { 0, 1, math.pi }, { 0, -1, 0 }, { 1, 0, math.pi / 2 } }
W.NUDGE_SIZE = 24

function W.Nudge(parent, getX, getY, setX, setY, range)
    local buttons = {}
    for i, nudge in ipairs(NUDGES) do
        local button = W.Button(parent, "", W.NUDGE_SIZE, W.NUDGE_SIZE, "secondary")
        button:SetPoint("LEFT", parent, "LEFT", (i - 1) * (W.NUDGE_SIZE + 4), 0)
        local arrow = button:CreateTexture(nil, "OVERLAY")
        arrow:SetPoint("CENTER", button, "CENTER", 0, 0); arrow:SetSize(14, 14)
        addon.Media:ApplyTexture(arrow, "ModeChevron")
        arrow:SetVertexColor(T.text[1], T.text[2], T.text[3], 1)
        if arrow.SetRotation then arrow:SetRotation(nudge[3]) end
        button.arrow, button.nudge = arrow, nudge
        button:SetScript("OnClick", function()
            local function Step(get, set, d)
                if d == 0 then return end
                local value = get() + d
                if range and (value < range[1] or value > range[2]) then return end
                set(value)
            end
            Step(getX, setX, nudge[1]); Step(getY, setY, nudge[2])
        end)
        buttons[i] = button
    end
    return buttons
end
